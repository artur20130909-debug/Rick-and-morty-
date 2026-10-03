-- Сервер «Стихийных битв RNG»: карта, данные игроков, ролл (новая способность заменяет старую),
-- портал на арену, бой (урон + отбрасывание), способности стихий и персонаж Рю.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")

local Abilities = require(RS:WaitForChild("Abilities"))
local Map = require(script.Parent:WaitForChild("MapBuilder"))
local CFG = Abilities.Config

Players.CharacterAutoLoads = false   -- персонажи появляются, только когда карта готова
local mapRoot = Map.build()
local portal = mapRoot:WaitForChild("Lobby"):WaitForChild("PortalTrigger")

---------------------------------------------------------------- удалённые события
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(class, name) local r = Instance.new(class); r.Name = name; r.Parent = remotes; return r end
local RollFn = remote("RemoteFunction", "Roll")
local SummonFn = remote("RemoteFunction", "Summon")
local GetDataFn = remote("RemoteFunction", "GetData")
local BuyLuckFn = remote("RemoteFunction", "BuyLuck")
local UseEv = remote("RemoteEvent", "Use")
local AnnounceEv = remote("RemoteEvent", "Announce")
local DataEv = remote("RemoteEvent", "DataUpdate")
local ShakeEv = remote("RemoteEvent", "Shake")
local CineEv = remote("RemoteEvent", "Cinematic")
remotes.Parent = RS

---------------------------------------------------------------- данные (сохраняются в DataStore)
local store = nil
do
	local ok, err = pcall(function() store = DataStoreService:GetDataStore("ElementRNG_v2") end)
	if not ok then warn("[RNG] Сохранение недоступно (опубликуй место и включи API в настройках): " .. tostring(err)) end
end

local Data = {}       -- [player] = { coins, kills, rolls, equipped, best, luckUntil }
local LUCK_COST, LUCK_TIME = 50, 300

local function loadData(plr)
	local d = { coins = 0, kills = 0, rolls = 0, equipped = nil, best = nil, luckUntil = 0 }
	if store then
		local ok, saved = pcall(function() return store:GetAsync("u" .. plr.UserId) end)
		if ok and type(saved) == "table" then
			d.coins = tonumber(saved.coins) or 0
			d.kills = tonumber(saved.kills) or 0
			d.rolls = tonumber(saved.rolls) or 0
			if type(saved.equipped) == "string" and Abilities.ById[saved.equipped] then d.equipped = saved.equipped end
			if type(saved.best) == "string" and Abilities.ById[saved.best] then d.best = saved.best end
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
		store:SetAsync("u" .. plr.UserId, { coins = d.coins, kills = d.kills, rolls = d.rolls, equipped = d.equipped, best = d.best })
	end)
	if not ok then warn("[RNG] Не удалось сохранить: " .. tostring(err)) end
end

local function pack(plr)
	local d = Data[plr]
	if not d then return nil end
	return { equipped = d.equipped, best = d.best, coins = d.coins, kills = d.kills, rolls = d.rolls,
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

local function addCoins(plr, n)
	local d = Data[plr]
	if not d then return end
	d.coins = d.coins + n
	syncStats(plr)
	pushData(plr)
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
	local s1, s2 = speed or 4, (speed or 4) * 2
	return Map.make("ParticleEmitter", { Color = ColorSequence.new(color), LightEmission = 0.8, Rate = rate or 60,
		Size = NumberSequence.new(size or 1.4, 0), Lifetime = NumberRange.new(life or 0.4, (life or 0.4) * 1.6),
		Speed = NumberRange.new(math.min(s1, s2), math.max(s1, s2)), SpreadAngle = Vector2.new(180, 180), Parent = parent })
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

-- всплывающая цифра урона / текст над целью
local function popText(pos, text, color, big)
	local anchor = fx({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(pos) })
	local bb = Map.make("BillboardGui", { Size = UDim2.new(0, big and 220 or 120, 0, big and 60 or 40), StudsOffset = Vector3.new(math.random() * 2 - 1, 2, 0),
		AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 120, Parent = anchor })
	local lbl = Map.make("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = text, TextColor3 = color, TextScaled = true,
		Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(20, 10, 20), Parent = bb })
	tween(bb, 0.9, { StudsOffset = bb.StudsOffset + Vector3.new(0, 3.5, 0) })
	task.delay(0.5, function() if lbl.Parent then tween(lbl, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 }) end end)
	Debris:AddItem(anchor, 1)
end

---------------------------------------------------------------- цели, урон и отбрасывание
local dummiesFolder = Instance.new("Folder")
dummiesFolder.Name = "Dummies"
dummiesFolder.Parent = mapRoot
for i = 1, 4 do
	local a = i / 4 * math.pi * 2
	Map.makeDummy(dummiesFolder, Map.ARENA + Vector3.new(math.cos(a) * 26, 3.2, math.sin(a) * 26), i)
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

local function flatUnit(v)
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 0.01 then return Vector3.new(0, 0, 0) end
	return f.Unit
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

-- множитель урона (десерт Рю: +20%)
local function dmgMult(attacker)
	local c = attacker and attacker.Character
	if c and (c:GetAttribute("BuffUntil") or 0) > os.clock() then return 1.2 end
	return 1
end

local function damage(t, attacker, dmg)
	if not dmg or dmg <= 0 or protected(t) then return end
	local total = math.floor(dmg * dmgMult(attacker) + 0.5)
	if t.hum then t.hum:TakeDamage(total) end
	popText(t.hrp.Position + Vector3.new(0, 2, 0), "-" .. total, dmgMult(attacker) > 1 and Color3.fromRGB(255, 140, 200) or Color3.fromRGB(255, 230, 120), total >= 30)
end

-- главный «удар»: урон + отбросить цель в направлении dir с силой power и подбросом up
local function knock(t, attacker, dir, power, up, dmg)
	if protected(t) then return false end
	lastHit[t.key] = { by = attacker, t = os.clock() }
	damage(t, attacker, dmg)
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

-- поза персонажа: клиенты плавно поворачивают суставы (все видят одно и то же)
local function setPose(char, pose, dur)
	if not char then return end
	char:SetAttribute("Pose", pose)
	local token = (char:GetAttribute("PoseToken") or 0) + 1
	char:SetAttribute("PoseToken", token)
	if dur then
		task.delay(dur, function()
			if char.Parent and char:GetAttribute("PoseToken") == token then char:SetAttribute("Pose", nil) end
		end)
	end
end

---------------------------------------------------------------- способности стихий
local Abil = {}

Abil.Slap = function(plr, hrp, dir, a)
	local center = hrp.Position + dir * 4
	setPose(plr.Character, "punchR", 0.25)
	burst(center, Color3.fromRGB(255, 235, 205), 5, 0.22)
	for _, t in ipairs(targetsNear(plr, center, 6.5)) do knock(t, plr, dir, 62, 26, a.damage) end
end

Abil.Fire = function(plr, hrp, dir, a)
	local orange = Color3.fromRGB(255, 120, 30)
	setPose(plr.Character, "punchR", 0.35)
	local ball = fx({ Shape = Enum.PartType.Ball, Size = Vector3.new(3.2, 3.2, 3.2), Color = orange, Material = Enum.Material.Neon })
	emitter(ball, Color3.fromRGB(255, 170, 60), 80, 2.2, 0.35, 3)
	light(ball, orange, 18)
	projectile(plr, hrp.Position + dir * 4 + Vector3.new(0, 1, 0), dir, 95, 1.1, 5, ball, function(pos)
		burst(pos, orange, 22, 0.45)
		burst(pos, Color3.fromRGB(255, 230, 120), 12, 0.3)
		for _, t in ipairs(targetsNear(plr, pos, 12)) do knock(t, plr, t.hrp.Position - pos + dir * 3, 78, 48, a.damage) end
	end)
end

Abil.Water = function(plr, hrp, dir, a)
	local blue = Color3.fromRGB(40, 150, 255)
	setPose(plr.Character, "push", 0.5)
	local base = hrp.Position - Vector3.new(0, 1, 0)
	local wave = fx({ Size = Vector3.new(14, 7, 3), Color = blue, Material = Enum.Material.Glass, Transparency = 0.25, CFrame = CFrame.lookAt(base + dir * 3, base + dir * 10) })
	emitter(wave, Color3.fromRGB(220, 240, 255), 90, 1.6, 0.4, 3)
	tween(wave, 0.5, { CFrame = CFrame.lookAt(base + dir * 32, base + dir * 40), Size = Vector3.new(22, 9, 3), Transparency = 1 }, Enum.EasingStyle.Linear)
	Debris:AddItem(wave, 0.55)
	for _, t in ipairs(targetsNear(plr, hrp.Position, 32)) do
		local to = flatUnit(t.hrp.Position - hrp.Position)
		local dist = (t.hrp.Position - hrp.Position).Magnitude
		if to:Dot(dir) > 0.45 then task.delay(dist / 64, function() knock(t, plr, dir, 95, 30, a.damage) end) end
	end
end

Abil.Earth = function(plr, hrp, dir, a)
	local brown = Color3.fromRGB(150, 100, 55)
	setPose(plr.Character, "slam", 0.5)
	local c = hrp.Position - Vector3.new(0, 3, 0)
	burst(c, brown, 30, 0.5, Enum.Material.Slate)
	for i = 1, 12 do
		local ang = i / 12 * math.pi * 2
		local r = 7 + (i % 3) * 3
		local s = 2.4 + math.random() * 2
		local start = CFrame.new(c + Vector3.new(math.cos(ang) * r, -2, math.sin(ang) * r)) * CFrame.Angles(math.random() * 3, math.random() * 3, 0)
		local rock = fx({ Size = Vector3.new(s, s * 1.4, s), Color = (i % 2 == 0) and brown or Color3.fromRGB(120, 115, 110), Material = Enum.Material.Slate, CFrame = start })
		tween(rock, 0.25, { CFrame = start + Vector3.new(0, 4 + math.random() * 2, 0) }, Enum.EasingStyle.Back)
		task.delay(0.7, function() if rock.Parent then tween(rock, 0.4, { Transparency = 1, CFrame = start }) end end)
		Debris:AddItem(rock, 1.2)
	end
	for _, t in ipairs(targetsNear(plr, hrp.Position, 18)) do knock(t, plr, t.hrp.Position - hrp.Position, 45, 88, a.damage) end
end

Abil.Wind = function(plr, hrp, dir, a)
	local col = Color3.fromRGB(200, 255, 235)
	setPose(plr.Character, "slide", 0.5)
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
				knock(t, plr, dir + flatUnit(t.hrp.Position - hrp.Position) * 0.6, 110, 55, a.damage)
			end
		end
	end)
end

Abil.Lightning = function(plr, hrp, dir, a)
	local yellow = Color3.fromRGB(255, 240, 90)
	setPose(plr.Character, "point", 0.6)
	local t = nearestTarget(plr, hrp.Position, dir, 55, 0.1) or nearestTarget(plr, hrp.Position, dir, 25, -1)
	local pos = t and t.hrp.Position or (hrp.Position + dir * 25)
	bolt(pos + Vector3.new(math.random() * 10 - 5, 70, math.random() * 10 - 5), pos, yellow)
	bolt(pos + Vector3.new(math.random() * 10 - 5, 70, math.random() * 10 - 5), pos, Color3.fromRGB(255, 255, 255))
	local b = burst(pos, yellow, 14, 0.35)
	light(b, yellow, 40)
	if t then
		knock(t, plr, t.hrp.Position - hrp.Position, 45, 40, a.damage)
		stun(t, 1.3)
		local sp = emitter(t.hrp, yellow, 40, 0.8, 0.3, 6)
		Debris:AddItem(sp, 1.3)
	end
end

Abil.Ice = function(plr, hrp, dir, a)
	local ice = Color3.fromRGB(160, 230, 255)
	setPose(plr.Character, "point", 0.4)
	local shard = fx({ Size = Vector3.new(1.2, 1.2, 4), Color = ice, Material = Enum.Material.Neon })
	emitter(shard, Color3.fromRGB(230, 250, 255), 50, 0.8, 0.3, 2)
	projectile(plr, hrp.Position + dir * 4 + Vector3.new(0, 1, 0), dir, 110, 1, 4.5, shard, function(pos, t)
		burst(pos, ice, 10, 0.35, Enum.Material.Ice)
		if not t or protected(t) then return end
		lastHit[t.key] = { by = plr, t = os.clock() }
		damage(t, plr, a.damage)
		local block = fx({ Size = Vector3.new(5, 7, 5), Color = ice, Material = Enum.Material.Ice, Transparency = 0.35, CFrame = CFrame.new(t.hrp.Position) })
		t.hrp.Anchored = true
		task.delay(2, function()
			if block.Parent then burst(block.Position, ice, 12, 0.3, Enum.Material.Ice); block:Destroy() end
			if t.hrp.Parent then t.hrp.Anchored = false; knock(t, plr, dir, 60, 32, 0) end
		end)
	end)
end

Abil.Shadow = function(plr, hrp, dir, a)
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
	setPose(char, "punchR", 0.35)
	task.delay(0.12, function()
		if not t.hrp.Parent then return end
		burst(t.hrp.Position, purple, 10, 0.3)
		knock(t, plr, -d, 125, 55, a.damage)
	end)
end

Abil.Gravity = function(plr, hrp, dir, a)
	local purple = Color3.fromRGB(160, 80, 255)
	setPose(plr.Character, "push", 1.8)
	local c = hrp.Position + dir * 20 + Vector3.new(0, 4, 0)
	local core = fx({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), Color = Color3.fromRGB(10, 0, 20), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(c) })
	local halo = fx({ Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Color = purple, Material = Enum.Material.ForceField, CFrame = CFrame.new(c) })
	light(core, purple, 40)
	emitter(halo, purple, 120, 1.2, 0.5, -10)
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
			for _, t in ipairs(targetsNear(plr, c, 24)) do knock(t, plr, t.hrp.Position - c, 140, 70, a.damage) end
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

Abil.Meteor = function(plr, hrp, dir, a)
	local red = Color3.fromRGB(255, 70, 40)
	setPose(plr.Character, "point", 1.2)
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
		for _, t in ipairs(targetsNear(plr, target, 26)) do knock(t, plr, t.hrp.Position - target, 165, 95, a.damage) end
	end)
end

---------------------------------------------------------------- РЮ (Рю Исигори, «Магическая битва»)
local RYU = Color3.fromRGB(150, 220, 255)

-- внешний вид: огромный чёрный кок-помпадур, лёгкая аура проклятой энергии
local function ryuLook(char, on)
	if not char then return end
	local old = char:FindFirstChild("RyuLook")
	if old then old:Destroy() end
	for _, acc in ipairs(char:GetChildren()) do
		if acc:IsA("Accessory") then
			local h = acc:FindFirstChild("Handle")
			if h and h:IsA("BasePart") then
				if on and acc.AccessoryType == Enum.AccessoryType.Hair then h.Transparency = 1; h:SetAttribute("RyuHid", true)
				elseif not on and h:GetAttribute("RyuHid") then h.Transparency = 0; h:SetAttribute("RyuHid", nil) end
			end
		end
	end
	local hrpA = char:FindFirstChild("HumanoidRootPart")
	local aura = hrpA and hrpA:FindFirstChild("RyuAura")
	if aura then aura:Destroy() end
	if not on then return end
	local head = char:FindFirstChild("Head")
	if not head then return end
	local look = Instance.new("Model")
	look.Name = "RyuLook"
	local black = Color3.fromRGB(18, 16, 22)
	local function hairPart(size, offset, rot)
		local p = Map.make("Part", { Name = "Hair", Size = size, Color = black, Material = Enum.Material.SmoothPlastic, Anchored = false, CanCollide = false,
			CanQuery = false, Massless = true, CastShadow = true, CFrame = head.CFrame * CFrame.new(offset) * rot, Parent = look })
		Map.make("WeldConstraint", { Part0 = head, Part1 = p, Parent = p })
		return p
	end
	-- основание причёски и длинный кок вперёд-вверх
	hairPart(Vector3.new(1.3, 0.5, 1.3), Vector3.new(0, 0.62, 0.05), CFrame.new())
	hairPart(Vector3.new(1.05, 0.9, 2.6), Vector3.new(0, 0.95, -0.85), CFrame.Angles(math.rad(22), 0, 0))
	hairPart(Vector3.new(0.85, 0.75, 1.4), Vector3.new(0, 1.35, -2.05), CFrame.Angles(math.rad(38), 0, 0))
	hairPart(Vector3.new(0.3, 0.9, 1.1), Vector3.new(0.62, 0.35, 0.15), CFrame.new())
	hairPart(Vector3.new(0.3, 0.9, 1.1), Vector3.new(-0.62, 0.35, 0.15), CFrame.new())
	look.Parent = char
	if hrpA then
		local e = emitter(hrpA, RYU, 10, 1.6, 0.8, 1)
		e.Name = "RyuAura"
		e.LightEmission = 0.4
		e.Transparency = NumberSequence.new(0.6, 1)
	end
end

local Ryu = {}

-- 1: Десерт — поесть, вылечиться и получить +20% урона на 10 секунд
Ryu.ryu1 = function(plr, char, hum, hrp)
	setPose(char, "eat", 1.1)
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	if hand then
		local cake = Map.make("Part", { Name = "Dessert", Size = Vector3.new(1.1, 0.7, 1.1), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(255, 190, 210),
			Material = Enum.Material.SmoothPlastic, Anchored = false, CanCollide = false, Massless = true, CFrame = hand.CFrame * CFrame.new(0, -0.6, -0.3) * CFrame.Angles(0, 0, math.rad(90)), Parent = char })
		Map.make("WeldConstraint", { Part0 = hand, Part1 = cake, Parent = cake })
		local berry = Map.make("Part", { Name = "Berry", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.4), Color = Color3.fromRGB(230, 30, 60), Anchored = false,
			CanCollide = false, Massless = true, CFrame = cake.CFrame * CFrame.new(0.45, 0, 0), Parent = char })
		Map.make("WeldConstraint", { Part0 = cake, Part1 = berry, Parent = berry })
		Debris:AddItem(cake, 1.1)
		Debris:AddItem(berry, 1.1)
	end
	task.delay(0.7, function()
		if hum.Health <= 0 then return end
		local heal = math.min(30, hum.MaxHealth - hum.Health)
		hum.Health = hum.Health + 30
		char:SetAttribute("BuffUntil", os.clock() + 10)
		popText(hrp.Position + Vector3.new(0, 3, 0), "+" .. math.floor(heal), Color3.fromRGB(120, 255, 140), true)
		popText(hrp.Position + Vector3.new(0, 1, 0), "УРОН +20%", Color3.fromRGB(255, 150, 210), false)
		burst(hrp.Position, Color3.fromRGB(255, 170, 210), 12, 0.4)
		local sp = emitter(hrp, Color3.fromRGB(255, 160, 210), 18, 0.9, 0.6, 2)
		sp.Name = "DessertBuff"
		Debris:AddItem(sp, 10)
	end)
end

-- 2: «Вот каков десерт!» — рывок; при попадании серия ударов в кинематографе и подброс
Ryu.ryu2 = function(plr, char, hum, hrp)
	local a = Abilities.RyuMoves[2]
	setPose(char, "slide", 0.6)
	local dir = flatUnit(hrp.CFrame.LookVector)
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(1e5, 0, 1e5)
	bv.Velocity = dir * 75
	bv.Parent = hrp
	local trail = emitter(hrp, Color3.fromRGB(255, 230, 200), 60, 1.2, 0.3, 2)
	local t0, caught = os.clock(), nil
	while os.clock() - t0 < 0.5 and not caught do
		for _, t in ipairs(targetsNear(plr, hrp.Position + dir * 3, 6)) do
			if not protected(t) then caught = t; break end
		end
		RunService.Heartbeat:Wait()
	end
	bv:Destroy()
	trail.Enabled = false
	Debris:AddItem(trail, 0.5)
	if not caught then setPose(char, nil); return end
	-- захват: оба замирают лицом друг к другу
	local t = caught
	lastHit[t.key] = { by = plr, t = os.clock() }
	local face = CFrame.lookAt(hrp.Position, Vector3.new(t.hrp.Position.X, hrp.Position.Y, t.hrp.Position.Z))
	hrp.Anchored = true
	hrp.CFrame = face
	t.hrp.Anchored = true
	t.hrp.CFrame = CFrame.lookAt(face.Position + face.LookVector * 4, face.Position)
	if t.char then setPose(t.char, "stagger") end
	local watchers = { plr }
	if t.plr then table.insert(watchers, t.plr) end
	for _, w in ipairs(watchers) do CineEv:FireClient(w, "combo", hrp, t.hrp, 2.6) end
	popText(hrp.Position + Vector3.new(0, 4, 0), "ВОТ КАКОВ ДЕСЕРТ!", Color3.fromRGB(255, 220, 140), true)
	local seq = { "punchR", "punchL", "punchR", "punchL", "kick" }
	for i, pose in ipairs(seq) do
		if not t.hrp.Parent or hum.Health <= 0 then break end
		setPose(char, pose)
		task.wait(0.28)
		local hitPos = t.hrp.Position + Vector3.new(0, 1, 0)
		burst(hitPos, Color3.fromRGB(255, 240, 220), 6 + i, 0.2)
		damage(t, plr, 4)
		for _, w in ipairs(watchers) do ShakeEv:FireClient(w, hitPos, 0.35) end
		if t.char then setPose(t.char, (i % 2 == 0) and "stagger" or "stagger2") end
	end
	setPose(char, "uppercut", 0.6)
	task.wait(0.15)
	hrp.Anchored = false
	if t.hrp.Parent then
		t.hrp.Anchored = false
		burst(t.hrp.Position, RYU, 16, 0.35)
		for _, w in ipairs(watchers) do ShakeEv:FireClient(w, t.hrp.Position, 0.8) end
		knock(t, plr, face.LookVector, 90, 110, 9)
		if t.char then setPose(t.char, nil) end
	end
end

-- 3 (G): УЛЬТА «Гранитный залп» — поза, заряд, песня, огромный луч
Ryu.ryu3 = function(plr, char, hum, hrp)
	local look = flatUnit(hrp.CFrame.LookVector)
	hrp.Anchored = true
	hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + look)
	setPose(char, "ultCharge")
	CineEv:FireClient(plr, "ult", hrp, nil, 3.4)
	AnnounceEv:FireAllClients("РЮ: «ГРАНИТНЫЙ ЗАЛП»!", RYU, true)
	-- реплика: в JJS Рю иногда кричит «Let's larp!»
	popText(hrp.Position + Vector3.new(0, 4.5, 0), (math.random() < 0.15) and "LET'S LARP!" or "ДО ПОСЛЕДНЕЙ КАПЛИ!", RYU, true)
	-- песня LARPZO: все слои из Abilities.Config.RyuSong играют одновременно (музыка + вокал)
	local old = hrp:FindFirstChild("RyuSong")
	while old do old:Destroy(); old = hrp:FindFirstChild("RyuSong") end
	for _, id in ipairs(CFG.RyuSong or {}) do
		if tostring(id) ~= "" then
			local snd = Map.make("Sound", { Name = "RyuSong", SoundId = "rbxassetid://" .. tostring(id), Volume = CFG.RyuSongVolume or 1,
				RollOffMaxDistance = 400, RollOffMinDistance = 40, Parent = hrp })
			snd:Play()
			task.delay(22, function() if snd.Parent then tween(snd, 2, { Volume = 0 }); Debris:AddItem(snd, 2.1) end end)
		end
	end
	-- заряд в ладонях и трещины земли
	local handPos = hrp.Position + look * 2.6 + Vector3.new(0, 0.6, 0)
	local orb = fx({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Color = Color3.fromRGB(230, 250, 255), Material = Enum.Material.Neon, CFrame = CFrame.new(handPos) })
	light(orb, RYU, 30)
	local charge = emitter(orb, RYU, 140, 1.2, 0.4, -8)
	tween(orb, 1.4, { Size = Vector3.new(4.5, 4.5, 4.5) })
	for i = 1, 8 do
		local ang = i / 8 * math.pi * 2
		local crack = fx({ Size = Vector3.new(0.6, 0.15, 6), Color = RYU, Material = Enum.Material.Neon,
			CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.9, 0) + Vector3.new(math.cos(ang), 0, math.sin(ang)) * 4) * CFrame.Angles(0, -ang + math.pi / 2, 0) })
		tween(crack, 1.4, { Size = Vector3.new(0.6, 0.15, 10), Transparency = 0.6 })
		Debris:AddItem(crack, 3.2)
	end
	task.wait(1.4)
	if hum.Health <= 0 then hrp.Anchored = false; orb:Destroy(); return end
	setPose(char, "ultFire")
	charge.Enabled = false
	-- луч
	local LEN, W = 170, 12
	local start = handPos
	local beamCF = CFrame.lookAt(start + look * (LEN / 2), start + look * LEN)
	local beam = fx({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(LEN, 1, 1), Color = Color3.fromRGB(235, 250, 255), Material = Enum.Material.Neon,
		CFrame = beamCF * CFrame.Angles(0, math.rad(90), 0) })
	local outer = fx({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(LEN, 2, 2), Color = RYU, Material = Enum.Material.ForceField, Transparency = 0,
		CFrame = beamCF * CFrame.Angles(0, math.rad(90), 0) })
	light(orb, RYU, 60)
	tween(beam, 0.18, { Size = Vector3.new(LEN, W * 0.55, W * 0.55) }, Enum.EasingStyle.Back)
	tween(outer, 0.18, { Size = Vector3.new(LEN, W, W) }, Enum.EasingStyle.Back)
	ShakeEv:FireAllClients(start, 1)
	local hitSet, t0 = {}, os.clock()
	while os.clock() - t0 < 1.3 do
		local pulse = 1 + math.sin(os.clock() * 40) * 0.06
		outer.Size = Vector3.new(LEN, W * pulse, W * pulse)
		for _, t in ipairs(allTargets(plr)) do
			if not hitSet[t.key] then
				local rel = t.hrp.Position - start
				local along = rel:Dot(look)
				local side = (rel - look * along).Magnitude
				if along > 0 and along < LEN and side < W * 0.6 then
					hitSet[t.key] = true
					knock(t, plr, look, 150, 45, 50)
					burst(t.hrp.Position, RYU, 18, 0.35)
				end
			end
		end
		RunService.Heartbeat:Wait()
	end
	tween(beam, 0.35, { Size = Vector3.new(LEN, 0.2, 0.2), Transparency = 1 })
	tween(outer, 0.35, { Size = Vector3.new(LEN, 0.4, 0.4), Transparency = 1 })
	tween(orb, 0.35, { Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 })
	Debris:AddItem(beam, 0.4); Debris:AddItem(outer, 0.4); Debris:AddItem(orb, 0.4)
	task.wait(0.4)
	hrp.Anchored = false
	setPose(char, nil)
end

---------------------------------------------------------------- использование: удар, способность, приёмы Рю
local lastUse = {}    -- [player] = { [вид] = время }
local busy = {}       -- игрок сейчас в приёме (захват, ульта) — нельзя начинать новый

UseEv.OnServerEvent:Connect(function(plr, kind, dir)
	local d = Data[plr]
	if not d or busy[plr] then return end
	local isRyu = (kind == "ryu1" or kind == "ryu2" or kind == "ryu3")
	-- стихии и удар — только на арене; приёмы Рю можно опробовать и в лобби (там некого задеть)
	if not isRyu and not plr:GetAttribute("InArena") then return end
	local c, hum, hrp = alive(plr)
	if not c or hrp.Anchored then return end
	local now = os.clock()
	lastUse[plr] = lastUse[plr] or {}
	local function ready(cd)
		if now - (lastUse[plr][kind] or 0) < cd - 0.15 then return false end
		lastUse[plr][kind] = now
		return true
	end
	if typeof(dir) ~= "Vector3" or dir.Magnitude ~= dir.Magnitude then dir = hrp.CFrame.LookVector end
	dir = flatUnit(dir)
	if dir.Magnitude < 0.5 then dir = flatUnit(hrp.CFrame.LookVector) end

	if isRyu then
		if d.equipped ~= "Ryu" then return end
		local move
		for _, m in ipairs(Abilities.RyuMoves) do if m.kind == kind then move = m end end
		if not move or not ready(move.cooldown) then return end
		c:SetAttribute("ProtectedUntil", 0)
		busy[plr] = (kind ~= "ryu1")
		task.spawn(function()
			local ok, err = pcall(Ryu[kind], plr, c, hum, hrp)
			if not ok then
				warn("[RNG] Ошибка приёма Рю " .. kind .. ": " .. tostring(err))
				if hrp.Parent then hrp.Anchored = false end
				setPose(c, nil)
			end
			busy[plr] = nil
		end)
		return
	end

	local a = Abilities.Slap
	if kind == "ability" then
		a = Abilities.ById[d.equipped or ""]
		if not a or a.character then return end
	elseif kind ~= "slap" then
		return
	end
	if not ready(a.cooldown) then return end
	c:SetAttribute("ProtectedUntil", 0)   -- кто атакует, тот теряет защиту появления
	local f = Abil[a.id]
	if f then
		local ok, err = pcall(f, plr, hrp, dir, a)
		if not ok then warn("[RNG] Ошибка способности " .. a.id .. ": " .. tostring(err)) end
	end
end)

---------------------------------------------------------------- ролл: новая способность ЗАМЕНЯЕТ старую
local rollOrder = Abilities.sortedByRarity()
local rng = Random.new()
local lastRoll = {}

local function setEquipped(plr, id)
	local d = Data[plr]
	d.equipped = id
	plr:SetAttribute("Equipped", id)
	ryuLook(plr.Character, id == "Ryu")
end

RollFn.OnServerInvoke = function(plr, confirmed)
	local d = Data[plr]
	if not d then return nil end
	-- если сейчас редкая способность — сначала спросить «точно крутить?»
	local cur = Abilities.ById[d.equipped or ""]
	if cur and cur.chance >= CFG.ConfirmChance and confirmed ~= true then
		return { needConfirm = true, current = cur.id }
	end
	local now = os.clock()
	if now - (lastRoll[plr] or 0) < 1.6 then return nil end
	lastRoll[plr] = now
	local luck = (d.luckUntil > now) and 2 or 1
	local res = rollOrder[#rollOrder]
	for _, a in ipairs(rollOrder) do
		if rng:NextNumber() < math.min(1, luck / a.chance) then res = a; break end
	end
	d.rolls = d.rolls + 1
	local reward = Abilities.Rarities[res.rarity].coins
	local bestA = Abilities.ById[d.best or ""]
	local newBest = (bestA == nil) or (res.chance > bestA.chance)
	if newBest then d.best = res.id end
	local prev = d.equipped
	setEquipped(plr, res.id)
	d.coins = d.coins + reward
	pushData(plr)          -- клиент придержит эти данные, пока крутится лента
	-- таблицу лидеров и объявление — когда лента у игрока уже остановилась
	task.delay(4.5, function() if plr.Parent then syncStats(plr) end end)
	task.delay(6.5, function()
		if res.chance >= 50 then
			AnnounceEv:FireAllClients(plr.DisplayName .. " выбил(а) «" .. res.name .. "» (1 к " .. res.chance .. ")!", res.color, true)
		end
		if res.chance >= 25 then
			local c, _, hrp = alive(plr)
			if c then
				burst(hrp.Position, res.color, 16 + math.min(res.chance, 1000) / 40, 0.6)
				local sp = emitter(hrp, res.color, 0, 1.2, 0.8, 10)
				sp:Emit(60)
				Debris:AddItem(sp, 1.5)
			end
		end
	end)
	return { id = res.id, coins = reward, newBest = newBest, prev = prev, luck = luck }
end

-- ТЕСТ: призвать Рю (кнопка в интерфейсе)
SummonFn.OnServerInvoke = function(plr, what)
	local d = Data[plr]
	if not d or what ~= "Ryu" then return false end
	setEquipped(plr, "Ryu")
	pushData(plr)
	AnnounceEv:FireAllClients(plr.DisplayName .. " призвал(а) РЮ!", RYU, true)
	return true
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
	local d = Data[plr]
	if d and d.equipped == "Ryu" then task.delay(1, function() ryuLook(char, true) end) end
	hum.Died:Connect(function()
		local lh = lastHit[plr]
		if lh and lh.by and lh.by.Parent and lh.by ~= plr and os.clock() - lh.t < 10 then
			local dk = Data[lh.by]
			if dk then
				dk.kills = dk.kills + 1
				addCoins(lh.by, CFG.KillCoins)
			end
			AnnounceEv:FireAllClients(lh.by.DisplayName .. " сбил(а) " .. plr.DisplayName .. "! +" .. CFG.KillCoins .. " монет", Color3.fromRGB(255, 140, 100), false)
		end
		lastHit[plr] = nil
		busy[plr] = nil
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
	plr.CharacterAppearanceLoaded:Connect(function(c)
		if Data[plr] and Data[plr].equipped == "Ryu" then ryuLook(c, true) end
	end)
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
	busy[plr] = nil
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
	local c = alive(plr)
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

---------------------------------------------------------------- пустота и манекены
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
				if lh and lh.by and lh.by.Parent then addCoins(lh.by, CFG.DummyCoins) end
				lastHit[m] = nil
				task.delay(3, function()
					local home = m:GetAttribute("Home")
					for _, part in ipairs(m:GetDescendants()) do
						if part:IsA("BasePart") then part.Anchored = false; part.AssemblyLinearVelocity = Vector3.new(); part.AssemblyAngularVelocity = Vector3.new() end
					end
					m:PivotTo(CFrame.new(home + Vector3.new(0, 3.6, 0)))
					m:SetAttribute("Down", false)
				end)
			end
		end
	end
end)

print("[RNG] Стихийные битвы RNG запущены")
