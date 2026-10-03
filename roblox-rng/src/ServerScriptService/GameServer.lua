-- Сервер «Стихийных битв RNG»: карта, данные игроков, роллы, портал на арену, бой и способности.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")

local Abilities = require(RS:WaitForChild("Abilities"))
local Map = require(script.Parent:WaitForChild("MapBuilder"))

Players.CharacterAutoLoads = false   -- персонажи появляются, только когда карта готова
local mapRoot = Map.build()
local portal = mapRoot:WaitForChild("Lobby"):WaitForChild("PortalTrigger")
local luckCrystal = mapRoot.Lobby:FindFirstChild("LuckCrystal")

---------------------------------------------------------------- удалённые события
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(class, name) local r = Instance.new(class); r.Name = name; r.Parent = remotes; return r end
local RollFn = remote("RemoteFunction", "Roll")
local EquipFn = remote("RemoteFunction", "Equip")
local GetDataFn = remote("RemoteFunction", "GetData")
local BuyLuckFn = remote("RemoteFunction", "BuyLuck")
local UseEv = remote("RemoteEvent", "Use")
local AnnounceEv = remote("RemoteEvent", "Announce")
local DataEv = remote("RemoteEvent", "DataUpdate")
local ShakeEv = remote("RemoteEvent", "Shake")
remotes.Parent = RS

---------------------------------------------------------------- данные (сохраняются в DataStore)
local store = nil
do
	local ok, err = pcall(function() store = DataStoreService:GetDataStore("ElementRNG_v1") end)
	if not ok then warn("[RNG] Сохранение недоступно (опубликуй место и включи API в настройках): " .. tostring(err)) end
end

local Data = {}       -- [player] = { coins, kills, rolls, owned = {id = кол-во}, equipped, luckUntil }
local LUCK_COST, LUCK_TIME = 50, 300

local function loadData(plr)
	local d = { coins = 0, kills = 0, rolls = 0, owned = {}, equipped = nil, luckUntil = 0 }
	if store then
		local ok, saved = pcall(function() return store:GetAsync("u" .. plr.UserId) end)
		if ok and type(saved) == "table" then
			d.coins = tonumber(saved.coins) or 0
			d.kills = tonumber(saved.kills) or 0
			d.rolls = tonumber(saved.rolls) or 0
			if type(saved.owned) == "table" then
				for id, n in pairs(saved.owned) do if Abilities.ById[id] then d.owned[id] = tonumber(n) or 1 end end
			end
			if type(saved.equipped) == "string" and d.owned[saved.equipped] then d.equipped = saved.equipped end
		elseif not ok then
			warn("[RNG] Не удалось загрузить данные: " .. tostring(saved))
		end
	end
	return d
end

local function saveData(plr)
	local d = Data[plr]
	if not d or not store then return end
	local ok, err = pcall(function()
		store:SetAsync("u" .. plr.UserId, { coins = d.coins, kills = d.kills, rolls = d.rolls, owned = d.owned, equipped = d.equipped })
	end)
	if not ok then warn("[RNG] Не удалось сохранить: " .. tostring(err)) end
end

local function pack(plr)
	local d = Data[plr]
	if not d then return nil end
	return { owned = d.owned, equipped = d.equipped, coins = d.coins, kills = d.kills, rolls = d.rolls,
		luckLeft = math.max(0, d.luckUntil - os.clock()), luckCost = LUCK_COST }
end

local function syncStats(plr)
	local d, ls = Data[plr], plr:FindFirstChild("leaderstats")
	if not d or not ls then return end
	ls["Убийства"].Value = d.kills
	ls["Монеты"].Value = d.coins
	ls["Роллы"].Value = d.rolls
end

local function pushData(plr)
	local p = pack(plr)
	if p then DataEv:FireClient(plr, p) end
end

---------------------------------------------------------------- цели и отбрасывание
local dummiesFolder = Instance.new("Folder")
dummiesFolder.Name = "Dummies"
dummiesFolder.Parent = mapRoot
for i = 1, 4 do
	local a = i / 4 * math.pi * 2
	Map.makeDummy(dummiesFolder, Map.ARENA + Vector3.new(math.cos(a) * 22, 4.2, math.sin(a) * 22), i)
end

local lastHit = {}    -- [player или манекен] = { by = player, t = время }

local function alive(plr)
	local c = plr.Character
	if not c then return nil end
	local hum = c:FindFirstChildOfClass("Humanoid")
	local hrp = c:FindFirstChild("HumanoidRootPart")
	if hum and hrp and hum.Health > 0 then return c, hum, hrp end
	return nil
end

-- все, кого можно ударить: игроки на арене и манекены
local function allTargets(attacker)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= attacker and p:GetAttribute("InArena") then
			local c, hum, hrp = alive(p)
			if c then table.insert(list, { plr = p, char = c, hum = hum, hrp = hrp, key = p }) end
		end
	end
	for _, m in ipairs(dummiesFolder:GetChildren()) do
		if m.PrimaryPart and not m:GetAttribute("Down") then table.insert(list, { model = m, hrp = m.PrimaryPart, key = m }) end
	end
	return list
end

local function targetsNear(attacker, pos, radius)
	local out = {}
	for _, t in ipairs(allTargets(attacker)) do
		if (t.hrp.Position - pos).Magnitude <= radius then table.insert(out, t) end
	end
	return out
end

local function nearestTarget(attacker, pos, dir, range, minDot)
	local best, bestD = nil, math.huge
	for _, t in ipairs(allTargets(attacker)) do
		local to = t.hrp.Position - pos
		local flat = Vector3.new(to.X, 0, to.Z)
		local dist = flat.Magnitude
		if dist <= range and dist < bestD and (dist < 0.1 or flat.Unit:Dot(dir) >= minDot) then best, bestD = t, dist end
	end
	return best
end

local function protected(t)
	return t.char and (t.char:GetAttribute("ProtectedUntil") or 0) > os.clock()
end

local function flatUnit(v)
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 0.01 then return Vector3.new(0, 0, 0) end
	return f.Unit
end

-- главный «удар»: отбросить цель в направлении dir с силой power и подбросом up
local function knock(t, attacker, dir, power, up)
	if protected(t) then return false end
	lastHit[t.key] = { by = attacker, t = os.clock() }
	local v = flatUnit(dir) * power + Vector3.new(0, up, 0)
	if t.model then
		t.hrp.Anchored = false
		t.hrp.AssemblyLinearVelocity = v
		t.hrp.AssemblyAngularVelocity = Vector3.new(math.random() * 8 - 4, math.random() * 8 - 4, math.random() * 8 - 4)
	else
		local bv = Instance.new("BodyVelocity")
		bv.Name = "Knock"
		bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
		bv.P = 1e5
		bv.Velocity = v
		bv.Parent = t.hrp
		Debris:AddItem(bv, 0.22)
		t.hum.PlatformStand = true
		task.delay(1, function() if t.hum.Parent then t.hum.PlatformStand = false end end)
	end
	return true
end

local function stun(t, sec)
	if not t.hum or protected(t) then return end
	local hum = t.hum
	hum.WalkSpeed = 0
	hum.JumpHeight = 0
	task.delay(sec, function() if hum.Parent then hum.WalkSpeed = 16; hum.JumpHeight = 7.2 end end)
end

---------------------------------------------------------------- эффекты
local fxFolder = Instance.new("Folder")
fxFolder.Name = "FX"
fxFolder.Parent = workspace

local function fx(props)
	props.Anchored = true
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = false
	props.Parent = props.Parent or fxFolder
	return Map.make("Part", props)
end

local function tween(obj, t, goal, style)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function burst(pos, color, size, t, material)
	t = t or 0.4
	local s = fx({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), Color = color, Material = material or Enum.Material.Neon, CFrame = CFrame.new(pos), Transparency = 0.15 })
	tween(s, t, { Size = Vector3.new(size, size, size), Transparency = 1 })
	Debris:AddItem(s, t + 0.1)
	return s
end

local function emitter(parent, color, rate, size, life, speed)
	return Map.make("ParticleEmitter", { Color = ColorSequence.new(color), LightEmission = 0.8, Rate = rate or 60,
		Size = NumberSequence.new(size or 1.4, 0), Lifetime = NumberRange.new(life or 0.4, (life or 0.4) * 1.6),
		Speed = NumberRange.new(math.min(speed or 4, (speed or 4) * 2), math.max(speed or 4, (speed or 4) * 2)), SpreadAngle = Vector2.new(180, 180), Parent = parent })
end

local function light(parent, color, range)
	return Map.make("PointLight", { Color = color, Range = range or 16, Brightness = 3, Parent = parent })
end

local function smoke(pos, color)
	burst(pos, color or Color3.fromRGB(40, 20, 60), 9, 0.45, Enum.Material.SmoothPlastic)
	local p = fx({ Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(pos) })
	local e = emitter(p, color or Color3.fromRGB(70, 30, 100), 0, 3, 0.6, 6)
	e.LightEmission = 0.2
	e:Emit(30)
	Debris:AddItem(p, 1.2)
end

local function bolt(from, to, color)
	local pts = { from }
	for i = 1, 7 do
		local a = from:Lerp(to, i / 8)
		table.insert(pts, a + Vector3.new(math.random() * 6 - 3, 0, math.random() * 6 - 3))
	end
	table.insert(pts, to)
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local seg = fx({ Size = Vector3.new(0.7, 0.7, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = color, Material = Enum.Material.Neon })
		tween(seg, 0.3, { Transparency = 1, Size = Vector3.new(0.1, 0.1, (b - a).Magnitude) })
		Debris:AddItem(seg, 0.35)
	end
end

-- снаряд: летит по прямой, при попадании (или через life секунд) вызывает onHit(позиция, цель или nil)
local function projectile(attacker, startPos, dir, speed, life, radius, part, onHit)
	local pos, t0, done = startPos, os.clock(), false
	part.CFrame = CFrame.new(pos)
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if done then return end
		pos = pos + dir * speed * dt
		part.CFrame = CFrame.lookAt(pos, pos + dir)
		local hit = nil
		for _, t in ipairs(targetsNear(attacker, pos, radius)) do hit = t; break end
		if hit or os.clock() - t0 > life then
			done = true
			conn:Disconnect()
			part:Destroy()
			onHit(pos, hit)
		end
	end)
end

---------------------------------------------------------------- способности
local Abil = {}

Abil.Slap = function(plr, hrp, dir)
	local center = hrp.Position + dir * 4
	burst(center, Color3.fromRGB(255, 235, 205), 5, 0.22)
	for _, t in ipairs(targetsNear(plr, center, 6.5)) do knock(t, plr, dir, 62, 26) end
end

Abil.Fire = function(plr, hrp, dir)
	local orange = Color3.fromRGB(255, 120, 30)
	local ball = fx({ Shape = Enum.PartType.Ball, Size = Vector3.new(3.2, 3.2, 3.2), Color = orange, Material = Enum.Material.Neon })
	emitter(ball, Color3.fromRGB(255, 170, 60), 80, 2.2, 0.35, 3)
	light(ball, orange, 18)
	projectile(plr, hrp.Position + dir * 4 + Vector3.new(0, 1, 0), dir, 95, 1.1, 5, ball, function(pos)
		burst(pos, orange, 22, 0.45)
		burst(pos, Color3.fromRGB(255, 230, 120), 12, 0.3)
		for _, t in ipairs(targetsNear(plr, pos, 12)) do knock(t, plr, t.hrp.Position - pos + dir * 3, 78, 48) end
	end)
end

Abil.Water = function(plr, hrp, dir)
	local blue = Color3.fromRGB(40, 150, 255)
	local base = hrp.Position - Vector3.new(0, 1, 0)
	local wave = fx({ Size = Vector3.new(14, 7, 3), Color = blue, Material = Enum.Material.Glass, Transparency = 0.25, CFrame = CFrame.lookAt(base + dir * 3, base + dir * 10) })
	local foam = emitter(wave, Color3.fromRGB(220, 240, 255), 90, 1.6, 0.4, 3)
	tween(wave, 0.5, { CFrame = CFrame.lookAt(base + dir * 32, base + dir * 40), Size = Vector3.new(22, 9, 3), Transparency = 1 }, Enum.EasingStyle.Linear)
	Debris:AddItem(wave, 0.55)
	for _, t in ipairs(targetsNear(plr, hrp.Position, 32)) do
		local to = flatUnit(t.hrp.Position - hrp.Position)
		local dist = (t.hrp.Position - hrp.Position).Magnitude
		if to:Dot(dir) > 0.45 then task.delay(dist / 64, function() knock(t, plr, dir, 95, 30) end) end
	end
end

Abil.Earth = function(plr, hrp, dir)
	local brown = Color3.fromRGB(150, 100, 55)
	local c = hrp.Position - Vector3.new(0, 3, 0)
	burst(c, brown, 30, 0.5, Enum.Material.Slate)
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		local r = 7 + (i % 3) * 3
		local s = 2.4 + math.random() * 2
		local start = CFrame.new(c + Vector3.new(math.cos(a) * r, -2, math.sin(a) * r)) * CFrame.Angles(math.random() * 3, math.random() * 3, 0)
		local rock = fx({ Size = Vector3.new(s, s * 1.4, s), Color = (i % 2 == 0) and brown or Color3.fromRGB(120, 115, 110), Material = Enum.Material.Slate, CFrame = start })
		tween(rock, 0.25, { CFrame = start + Vector3.new(0, 4 + math.random() * 2, 0) }, Enum.EasingStyle.Back)
		task.delay(0.7, function() if rock.Parent then tween(rock, 0.4, { Transparency = 1, CFrame = start }) end end)
		Debris:AddItem(rock, 1.2)
	end
	for _, t in ipairs(targetsNear(plr, hrp.Position, 18)) do knock(t, plr, t.hrp.Position - hrp.Position, 45, 88) end
end

Abil.Wind = function(plr, hrp, dir)
	local col = Color3.fromRGB(200, 255, 235)
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(1e5, 2e4, 1e5)
	bv.Velocity = dir * 85 + Vector3.new(0, 6, 0)
	bv.Parent = hrp
	Debris:AddItem(bv, 0.3)
	local tor = fx({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 6, 6), Color = col, Material = Enum.Material.ForceField, Transparency = 0.1 })
	emitter(tor, col, 70, 1.2, 0.3, 8)
	local hitSet, t0 = {}, os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not hrp.Parent or os.clock() - t0 > 0.45 then
			conn:Disconnect()
			tween(tor, 0.25, { Transparency = 1, Size = Vector3.new(12, 10, 10) })
			Debris:AddItem(tor, 0.3)
			return
		end
		tor.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, (os.clock() - t0) * 25, 0) * CFrame.Angles(0, 0, math.rad(90))
		for _, t in ipairs(targetsNear(plr, hrp.Position, 9)) do
			if not hitSet[t.key] then
				hitSet[t.key] = true
				knock(t, plr, dir + flatUnit(t.hrp.Position - hrp.Position) * 0.6, 110, 55)
			end
		end
	end)
end

Abil.Lightning = function(plr, hrp, dir)
	local yellow = Color3.fromRGB(255, 240, 90)
	local t = nearestTarget(plr, hrp.Position, dir, 55, 0.1) or nearestTarget(plr, hrp.Position, dir, 25, -1)
	local pos = t and t.hrp.Position or (hrp.Position + dir * 25)
	bolt(pos + Vector3.new(math.random() * 10 - 5, 70, math.random() * 10 - 5), pos, yellow)
	bolt(pos + Vector3.new(math.random() * 10 - 5, 70, math.random() * 10 - 5), pos, Color3.fromRGB(255, 255, 255))
	local b = burst(pos, yellow, 14, 0.35)
	light(b, yellow, 40)
	if t then
		knock(t, plr, t.hrp.Position - hrp.Position, 45, 40)
		stun(t, 1.3)
		local sp = emitter(t.hrp, yellow, 40, 0.8, 0.3, 6)
		Debris:AddItem(sp, 1.3)
	end
end

Abil.Ice = function(plr, hrp, dir)
	local ice = Color3.fromRGB(160, 230, 255)
	local shard = fx({ Size = Vector3.new(1.2, 1.2, 4), Color = ice, Material = Enum.Material.Neon })
	emitter(shard, Color3.fromRGB(230, 250, 255), 50, 0.8, 0.3, 2)
	projectile(plr, hrp.Position + dir * 4 + Vector3.new(0, 1, 0), dir, 110, 1, 4.5, shard, function(pos, t)
		burst(pos, ice, 10, 0.35, Enum.Material.Ice)
		if not t or protected(t) then return end
		lastHit[t.key] = { by = plr, t = os.clock() }
		local block = fx({ Size = Vector3.new(5, 7, 5), Color = ice, Material = Enum.Material.Ice, Transparency = 0.35, CFrame = CFrame.new(t.hrp.Position) })
		t.hrp.Anchored = true
		task.delay(2, function()
			if block.Parent then burst(block.Position, ice, 12, 0.3, Enum.Material.Ice); block:Destroy() end
			if t.hrp.Parent then t.hrp.Anchored = false; knock(t, plr, dir, 60, 32) end
		end)
	end)
end

Abil.Shadow = function(plr, hrp, dir)
	local purple = Color3.fromRGB(120, 70, 175)
	local char = plr.Character
	smoke(hrp.Position, Color3.fromRGB(60, 25, 90))
	local t = nearestTarget(plr, hrp.Position, dir, 50, -1)
	if not t then
		local to = hrp.Position + dir * 18
		char:PivotTo(CFrame.lookAt(to, to + dir))
		smoke(to, Color3.fromRGB(60, 25, 90))
		return
	end
	local d = flatUnit(t.hrp.Position - hrp.Position)
	if d.Magnitude < 0.5 then d = dir end
	local behind = t.hrp.Position + d * 4 + Vector3.new(0, 0.5, 0)
	char:PivotTo(CFrame.lookAt(behind, Vector3.new(t.hrp.Position.X, behind.Y, t.hrp.Position.Z)))
	smoke(behind, Color3.fromRGB(60, 25, 90))
	task.delay(0.12, function()
		if not t.hrp.Parent then return end
		burst(t.hrp.Position, purple, 10, 0.3)
		knock(t, plr, -d, 125, 55)
	end)
end

Abil.Gravity = function(plr, hrp, dir)
	local purple = Color3.fromRGB(160, 80, 255)
	local c = hrp.Position + dir * 20 + Vector3.new(0, 4, 0)
	local core = fx({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), Color = Color3.fromRGB(10, 0, 20), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(c) })
	local halo = fx({ Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Color = purple, Material = Enum.Material.ForceField, CFrame = CFrame.new(c) })
	light(core, purple, 40)
	local pe = emitter(halo, purple, 120, 1.2, 0.5, -10)
	tween(core, 0.4, { Size = Vector3.new(7, 7, 7) })
	tween(halo, 0.4, { Size = Vector3.new(16, 16, 16) })
	local t0, pulls = os.clock(), {}
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if os.clock() - t0 > 1.8 then
			conn:Disconnect()
			for _, bv in pairs(pulls) do if bv.Parent then bv:Destroy() end end
			burst(c, purple, 46, 0.55)
			burst(c, Color3.fromRGB(255, 255, 255), 20, 0.3)
			core:Destroy(); halo:Destroy()
			ShakeEv:FireAllClients(c, 0.5)
			for _, t in ipairs(targetsNear(plr, c, 24)) do knock(t, plr, t.hrp.Position - c, 140, 70) end
			return
		end
		for _, t in ipairs(targetsNear(plr, c, 34)) do
			if not protected(t) then
				lastHit[t.key] = { by = plr, t = os.clock() }
				local v = (c - t.hrp.Position)
				if v.Magnitude > 0.5 then v = v.Unit * 40 end
				if t.model then
					t.hrp.AssemblyLinearVelocity = v
				else
					local bv = pulls[t.key]
					if not bv or not bv.Parent then
						bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(4e4, 4e4, 4e4); bv.Parent = t.hrp; pulls[t.key] = bv
						Debris:AddItem(bv, 2.2)
					end
					bv.Velocity = v
				end
			end
		end
	end)
end

Abil.Meteor = function(plr, hrp, dir)
	local red = Color3.fromRGB(255, 70, 40)
	local target = hrp.Position + dir * 28 - Vector3.new(0, 2.8, 0)
	local mark = fx({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 4, 4), CFrame = CFrame.new(target) * CFrame.Angles(0, 0, math.rad(90)), Color = red, Material = Enum.Material.Neon, Transparency = 0.4 })
	tween(mark, 1.1, { Size = Vector3.new(0.3, 48, 48), Transparency = 0.6 }, Enum.EasingStyle.Linear)
	local rock = fx({ Shape = Enum.PartType.Ball, Size = Vector3.new(11, 11, 11), Color = Color3.fromRGB(90, 40, 30), Material = Enum.Material.CrackedLava, CFrame = CFrame.new(target + Vector3.new(-45, 140, 0)) })
	emitter(rock, Color3.fromRGB(255, 150, 50), 120, 4, 0.6, 4)
	light(rock, red, 60)
	tween(rock, 1.1, { CFrame = CFrame.new(target) }, Enum.EasingStyle.Linear)
	task.delay(1.1, function()
		rock:Destroy(); mark:Destroy()
		burst(target, red, 60, 0.7)
		burst(target, Color3.fromRGB(255, 220, 120), 32, 0.45)
		ShakeEv:FireAllClients(target, 0.8)
		for _, t in ipairs(targetsNear(plr, target, 26)) do knock(t, plr, t.hrp.Position - target, 165, 95) end
	end)
end

---------------------------------------------------------------- использование: удар и способность
local lastUse = {}    -- [player] = { slap = время, ability = время }

UseEv.OnServerEvent:Connect(function(plr, kind, dir)
	local d = Data[plr]
	if not d or not plr:GetAttribute("InArena") then return end
	local c, hum, hrp = alive(plr)
	if not c or hrp.Anchored then return end
	local a = Abilities.Slap
	if kind == "ability" then
		a = Abilities.ById[d.equipped or ""]
		if not a then return end
	elseif kind ~= "slap" then
		return
	end
	local now = os.clock()
	lastUse[plr] = lastUse[plr] or {}
	if now - (lastUse[plr][kind] or 0) < a.cooldown - 0.15 then return end
	lastUse[plr][kind] = now
	c:SetAttribute("ProtectedUntil", 0)   -- кто атакует, тот теряет защиту появления
	if typeof(dir) ~= "Vector3" or dir.Magnitude ~= dir.Magnitude then dir = hrp.CFrame.LookVector end
	dir = flatUnit(dir)
	if dir.Magnitude < 0.5 then dir = flatUnit(hrp.CFrame.LookVector) end
	local f = Abil[a.id]
	if f then
		local ok, err = pcall(f, plr, hrp, dir)
		if not ok then warn("[RNG] Ошибка способности " .. a.id .. ": " .. tostring(err)) end
	end
end)

---------------------------------------------------------------- ролл
local rollOrder = Abilities.sortedByRarity()
local rng = Random.new()
local lastRoll = {}

RollFn.OnServerInvoke = function(plr)
	local d = Data[plr]
	if not d then return nil end
	local now = os.clock()
	if now - (lastRoll[plr] or 0) < 1.6 then return nil end
	lastRoll[plr] = now
	local luck = (d.luckUntil > now) and 2 or 1
	local res = rollOrder[#rollOrder]
	for _, a in ipairs(rollOrder) do
		if rng:NextNumber() < math.min(1, luck / a.chance) then res = a; break end
	end
	d.rolls = d.rolls + 1
	local isNew = d.owned[res.id] == nil
	d.owned[res.id] = (d.owned[res.id] or 0) + 1
	local cur = Abilities.ById[d.equipped or ""]
	local autoEquip = (cur == nil) or (res.chance > cur.chance)
	if autoEquip then
		d.equipped = res.id
		plr:SetAttribute("Equipped", res.id)
	end
	syncStats(plr)
	-- остальным игрокам — только про редкие выпадения (и после того, как у игрока докрутится ролл)
	task.delay(2.2, function()
		if res.chance >= 50 then
			AnnounceEv:FireAllClients(plr.DisplayName .. " выбил(а) «" .. res.name .. "» (1 к " .. res.chance .. ")!", res.color, true)
		end
		if plr.Parent then pushData(plr) end
	end)
	return { id = res.id, isNew = isNew, equipped = autoEquip, luck = luck }
end

EquipFn.OnServerInvoke = function(plr, id)
	local d = Data[plr]
	if d and type(id) == "string" and d.owned[id] and Abilities.ById[id] then
		d.equipped = id
		plr:SetAttribute("Equipped", id)
		pushData(plr)
		return true
	end
	return false
end

GetDataFn.OnServerInvoke = function(plr)
	return pack(plr)
end

BuyLuckFn.OnServerInvoke = function(plr)
	local d = Data[plr]
	if not d or d.coins < LUCK_COST then return false end
	d.coins = d.coins - LUCK_COST
	d.luckUntil = math.max(os.clock(), d.luckUntil) + LUCK_TIME
	syncStats(plr)
	pushData(plr)
	return true
end

---------------------------------------------------------------- игроки
local function onCharacter(plr, char)
	plr:SetAttribute("InArena", false)
	local hum = char:WaitForChild("Humanoid")
	hum.Died:Connect(function()
		local lh = lastHit[plr]
		if lh and lh.by and lh.by.Parent and lh.by ~= plr and os.clock() - lh.t < 10 then
			local d = Data[lh.by]
			if d then
				d.kills = d.kills + 1
				d.coins = d.coins + 10
				syncStats(lh.by)
				pushData(lh.by)
			end
			AnnounceEv:FireAllClients(lh.by.DisplayName .. " сбил(а) " .. plr.DisplayName .. "! +10 монет", Color3.fromRGB(255, 140, 100), false)
		end
		lastHit[plr] = nil
		plr:SetAttribute("InArena", false)
		task.delay(2.5, function() if plr.Parent then plr:LoadCharacter() end end)
	end)
end

local function onPlayer(plr)
	local d = loadData(plr)
	Data[plr] = d
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, n in ipairs({ "Убийства", "Монеты", "Роллы" }) do
		local v = Instance.new("IntValue"); v.Name = n; v.Parent = ls
	end
	ls.Parent = plr
	syncStats(plr)
	plr:SetAttribute("Equipped", d.equipped)
	plr:SetAttribute("InArena", false)
	plr.CharacterAdded:Connect(function(c) onCharacter(plr, c) end)
	plr:LoadCharacter()
	pushData(plr)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end

Players.PlayerRemoving:Connect(function(plr)
	saveData(plr)
	Data[plr] = nil
	lastHit[plr] = nil
	lastUse[plr] = nil
	lastRoll[plr] = nil
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do saveData(p) end
end)

task.spawn(function()
	while true do
		task.wait(90)
		for _, p in ipairs(Players:GetPlayers()) do task.spawn(saveData, p) end
	end
end)

---------------------------------------------------------------- портал на арену
local portalBusy = {}
portal.Touched:Connect(function(hit)
	local char = hit.Parent
	local plr = Players:GetPlayerFromCharacter(char)
	if not plr or portalBusy[plr] or plr:GetAttribute("InArena") then return end
	local c, hum, hrp = alive(plr)
	if not c then return end
	portalBusy[plr] = true
	local sp = Map.ArenaSpawns[math.random(1, #Map.ArenaSpawns)]
	c:PivotTo(CFrame.lookAt(sp + Vector3.new(0, 4, 0), Vector3.new(Map.ARENA.X, sp.Y + 4, Map.ARENA.Z)))
	plr:SetAttribute("InArena", true)
	c:SetAttribute("ProtectedUntil", os.clock() + 3)
	local ff = Instance.new("ForceField")
	ff.Parent = c
	Debris:AddItem(ff, 3)
	burst(sp + Vector3.new(0, 3, 0), Color3.fromRGB(170, 100, 255), 12, 0.4)
	task.delay(1, function() portalBusy[plr] = nil end)
end)

---------------------------------------------------------------- пустота, манекены, кристалл
task.spawn(function()
	while true do
		task.wait(0.3)
		for _, p in ipairs(Players:GetPlayers()) do
			local c, hum, hrp = alive(p)
			if c and hrp.Position.Y < Map.VOID_Y then hum.Health = 0 end
		end
		for _, m in ipairs(dummiesFolder:GetChildren()) do
			local root = m.PrimaryPart
			if root and not m:GetAttribute("Down") and root.Position.Y < Map.VOID_Y then
				m:SetAttribute("Down", true)
				local lh = lastHit[m]
				if lh and lh.by and lh.by.Parent and Data[lh.by] then
					Data[lh.by].coins = Data[lh.by].coins + 2
					syncStats(lh.by)
					pushData(lh.by)
				end
				lastHit[m] = nil
				task.delay(3, function()
					local home = m:GetAttribute("Home")
					for _, part in ipairs(m:GetDescendants()) do
						if part:IsA("BasePart") then part.AssemblyLinearVelocity = Vector3.new(); part.AssemblyAngularVelocity = Vector3.new() end
					end
					m:PivotTo(CFrame.new(home + Vector3.new(0, 3.6, 0)))
					m:SetAttribute("Down", false)
				end)
			end
		end
	end
end)

if luckCrystal then
	local base = luckCrystal.CFrame
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		luckCrystal.CFrame = CFrame.new(base.Position + Vector3.new(0, math.sin(t * 1.5) * 0.8, 0)) * CFrame.Angles(0, t * 0.8, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	end)
end

print("[RNG] Стихийные битвы RNG запущены")
