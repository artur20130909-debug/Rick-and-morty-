-- Дикие монстры в лесу: появление (днём редко и только до «Редкого», ночью часто и любые),
-- блуждание, погоня и испуг игроков ночью, ловля (держать E), приманки, монстр-подсказка для новичка.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local Monsters = require(Shared.Monsters)

local Wild = {}
local S
local wild = {}     -- model -> состояние
local count = 0
local rng = Random.new()
local scareCd = {}  -- player -> время
local MAP = Config.Map
local W = Config.Wild

local function toast(player, text, color) Net.event("Toast"):FireClient(player, text, color) end
local function now() return S.Cycle.now() end

local function hrpOf(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hum and hrp and hum.Health > 0 then return hrp end
	return nil
end

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- точка внутри кольца леса
local function clampForest(p)
	local f = flat(p)
	local r = f.Magnitude
	if r < 0.01 then return Vector3.new(MAP.ForestMin + 5, 0, 0) end
	local nr = math.clamp(r, MAP.ForestMin, MAP.ForestMax)
	return f.Unit * nr
end

local function randomForestPoint()
	local r = math.sqrt(rng:NextNumber(MAP.ForestMin ^ 2, MAP.ForestMax ^ 2))
	local a = rng:NextNumber(0, math.pi * 2)
	return Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

-- игрок в безопасности (у костра или на базе)
local function isSafe(pos)
	if flat(pos).Magnitude < MAP.SafeRadius + 2 then return true end
	return S.Bases.at(pos) ~= nil
end

function Wild.count() return count end

function Wild.remove(model)
	if wild[model] then
		wild[model] = nil
		count = count - 1
	end
	if model.Parent then model:Destroy() end
end

-- opts: pos, key, mut, luck, gold, blood, reserved(player), maxTier, life, idle, fromDrop
function Wild.spawn(opts)
	opts = opts or {}
	local key, mut = opts.key, opts.mut
	if not key then
		local maxTier = opts.maxTier or (S.Cycle.isNight() and #Config.Rarities or 3)
		local r = Util.rollRarity(rng, S.Cycle.luck() * (opts.luck or 1), maxTier)
		key = Util.rollMonster(rng, r.key).key
		mut = Util.rollMutation(rng, { event = S.Cycle.isNight() and S.Cycle.event() or "", gold = opts.gold, blood = opts.blood })
	end
	local def = Config.MonsterIndex[key]
	local r = Config.RarityIndex[def.rarity]
	local pos = opts.pos or randomForestPoint()
	local m, root = Monsters.build(key, mut)
	m.Name = "Wild_" .. key
	m:PivotTo(CFrame.new(pos.X, 0.15, pos.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	local line2 = r.tier > 1 and ("1 к " .. Util.num(r.chance)) or ""
	if opts.reserved then line2 = "🎯 для " .. opts.reserved.DisplayName end
	Monsters.label(m, line2, 90)
	local att = Instance.new("Attachment")
	att.Name = "PromptAtt"
	att.Position = Vector3.new(0, def.size * 0.5, 0)
	att.Parent = root
	local p = Instance.new("ProximityPrompt")
	p.Name = "CatchPrompt"
	p.ActionText = "Поймать"
	p.ObjectText = Util.fullName(key, mut) .. " · сеть " .. r.net .. "+"
	p.HoldDuration = r.hold
	p.MaxActivationDistance = 11
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Parent = att
	m:SetAttribute("Wild", true)
	m:SetAttribute("NeedNet", r.net)
	m.Parent = workspace.Wild
	local st = {
		model = m, root = root, key = key, mut = mut or "", rarity = r, pos = flat(pos), dir = Vector3.new(0, 0, -1),
		target = nil, speed = r.speed, born = now(), life = opts.life or rng:NextNumber(W.LifeMin, W.LifeMax),
		reserved = opts.reserved, reservedUntil = now() + W.ReserveSeconds, idle = opts.idle, phase = rng:NextNumber(0, 6),
		fromBait = opts.reserved ~= nil and not opts.idle,
	}
	wild[m] = st
	count = count + 1
	p.Triggered:Connect(function(player) Wild.catch(player, m) end)
	if r.tier >= Config.AnnounceTier and not opts.fromDrop then
		S.Cycle.announce(string.format("⚠ В лесу появился %s: %s!", string.upper(r.name), Util.fullName(key, mut)), r.color)
	end
	return m
end

function Wild.catch(player, m)
	local st = wild[m]
	if not st then return end
	local hrp = hrpOf(player)
	if not hrp or (flat(hrp.Position) - st.pos).Magnitude > 16 then return end
	if S.Carry.get(player) then
		toast(player, "Руки заняты — отнеси монстра на базу", Color3.fromRGB(255, 200, 90))
		return
	end
	local net = player:GetAttribute("Net") or 1
	if net < st.rarity.net then
		toast(player, "Нужна сеть " .. st.rarity.net .. " уровня! Купи её в Лавке Ловца у костра", Color3.fromRGB(255, 120, 90))
		return
	end
	if st.reserved and st.reserved ~= player and st.reserved.Parent and now() < st.reservedUntil then
		toast(player, "Это монстр из чужой приманки (ещё " .. math.ceil(st.reservedUntil - now()) .. " с)", Color3.fromRGB(255, 200, 90))
		return
	end
	local key, mut, pos = st.key, st.mut, st.pos
	Wild.remove(m)
	local ok = S.Carry.start(player, { k = key, m = mut }, { from = "wild" })
	if not ok then
		Wild.spawn({ pos = pos, key = key, mut = mut, fromDrop = true })
		return
	end
	Net.event("Fx"):FireClient(player, "caught", Util.fullName(key, mut), st.rarity.key)
end

---------------------------------------------------------------- приманки и подсказка новичку
function Wild.useBait(player, baitKey)
	local def = Config.BaitIndex[baitKey]
	local p = S.Data.get(player)
	if not def or not p or (p.baits[baitKey] or 0) <= 0 then return end
	local hrp = hrpOf(player)
	if not hrp then return end
	if isSafe(hrp.Position) then
		toast(player, "Приманку можно ставить только в лесу", Color3.fromRGB(255, 200, 90))
		return
	end
	p.baits[baitKey] = p.baits[baitKey] - 1
	S.Data.sync(player)
	local pos = flat(hrp.Position)
	local bait = Instance.new("Part")
	bait.Name = "Bait"
	bait.Shape = Enum.PartType.Ball
	bait.Size = Vector3.new(1.2, 1.2, 1.2)
	bait.Material = Enum.Material.Neon
	bait.Color = def.blood and Color3.fromRGB(220, 20, 40) or (def.gold and Color3.fromRGB(255, 210, 60) or Color3.fromRGB(255, 140, 80))
	bait.Anchored = true
	bait.CanCollide = false
	bait.CanQuery = false
	bait.CFrame = CFrame.new(pos + Vector3.new(0, 0.6, 0))
	bait.Parent = workspace.Wild
	toast(player, def.icon .. " " .. def.name .. ": кто-то идёт на запах...", Color3.fromRGB(255, 220, 140))
	task.delay(Config.BaitDelay, function()
		if bait.Parent then bait:Destroy() end
		local a = rng:NextNumber(0, math.pi * 2)
		local sp = pos + Vector3.new(math.cos(a), 0, math.sin(a)) * 7
		Wild.spawn({ pos = sp, luck = def.luck, gold = def.gold, blood = def.blood, reserved = player, maxTier = #Config.Rarities })
	end)
end

function Wild.spawnHelper(player)
	local rec = S.Bases.baseOf(player)
	if not rec then return end
	local pos = (rec.cf * CFrame.new(0, 0, -(Config.Map.BaseSize / 2 + 16))).Position
	Wild.spawn({ pos = pos, key = "slipper", mut = "", reserved = player, life = 600, idle = true, fromDrop = true })
	toast(player, "👋 Перед твоей базой — первый монстр! Подойди и держи E, чтобы поймать", Color3.fromRGB(120, 255, 140))
end

---------------------------------------------------------------- смена фаз
function Wild.onDay()
	for m, st in pairs(wild) do
		if st.rarity.nightOnly and not st.fromBait then
			Wild.remove(m)
		else
			st.life = math.min(st.life, now() - st.born + rng:NextNumber(20, 60))
		end
	end
end

function Wild.onNight() end

---------------------------------------------------------------- движение
local function nearestPlayer(pos, range)
	local best, bestD = nil, range
	for _, pl in ipairs(Players:GetPlayers()) do
		local hrp = hrpOf(pl)
		if hrp then
			local d = (flat(hrp.Position) - pos).Magnitude
			if d < bestD and not isSafe(hrp.Position) then best, bestD = pl, d end
		end
	end
	return best, bestD
end

local function step(st, dt, t)
	if st.idle then
		local bob = math.abs(math.sin(t * 3 + st.phase)) * 0.4
		st.root.CFrame = CFrame.lookAt(st.pos + Vector3.new(0, 0.15 + bob, 0), st.pos + st.dir + Vector3.new(0, 0.15 + bob, 0))
		return
	end
	local night = S.Cycle.isNight()
	local speed = st.speed
	local goal = st.target
	-- редкие ночью идут на игрока, мелкие убегают
	local pl, d = nearestPlayer(st.pos, night and 26 or 14)
	if pl then
		local hrp = hrpOf(pl)
		local pp = flat(hrp.Position)
		if night and st.rarity.tier >= 3 then
			goal = pp
			if pp.Magnitude > MAP.ForestMax + 20 then goal = pp.Unit * (MAP.ForestMax + 20) end
			speed = speed * 1.1
			if d < 3 then speed = 0 end
		else
			local away = st.pos - pp
			if away.Magnitude < 0.1 then away = st.dir end
			goal = clampForest(st.pos + away.Unit * 20)
			speed = speed * 1.2
		end
	elseif not goal or (goal - st.pos).Magnitude < 2 then
		st.target = clampForest(st.pos + Vector3.new(rng:NextNumber(-35, 35), 0, rng:NextNumber(-35, 35)))
		goal = st.target
	end
	local to = goal - st.pos
	if to.Magnitude > 0.1 and speed > 0 then
		st.dir = to.Unit
		local np = st.pos + st.dir * math.min(speed * dt, to.Magnitude)
		-- не заходить к костру
		if flat(np).Magnitude < MAP.SafeRadius + 4 then np = flat(np).Unit * (MAP.SafeRadius + 4) end
		st.pos = np
	end
	local hop = math.abs(math.sin(t * 7 + st.phase)) * (st.rarity.tier <= 2 and 0.7 or 0.25)
	local y = 0.15 + hop
	st.root.CFrame = CFrame.lookAt(st.pos + Vector3.new(0, y, 0), st.pos + st.dir + Vector3.new(0, y, 0))
end

-- испуг: монстр рядом ночью может напугать — оглушение и падение монстра с головы
local function scare(player, st)
	scareCd[player] = now() + W.ScareCooldown
	local hrp = hrpOf(player)
	S.Carry.stun(player, W.StunSeconds)
	if S.Carry.get(player) then S.Carry.drop(player, "wild", hrp and hrp.Position) end
	Net.event("Fx"):FireClient(player, "scare", st.key, st.rarity.key)
end

function Wild.init(s)
	S = s
	RunService.Heartbeat:Connect(function(dt)
		local t = now()
		for m, st in pairs(wild) do
			local ok, err = pcall(step, st, dt, t)
			if not ok then
				warn("[CN] Wild step: " .. tostring(err))
				Wild.remove(m)
			elseif t > st.born + st.life then
				Wild.remove(m)
			end
		end
	end)
	-- появление
	task.spawn(function()
		local acc = 0
		while true do
			task.wait(0.5)
			acc = acc + 0.5
			local ok, err = pcall(function()
				local night = S.Cycle.isNight()
				local interval = night and W.NightInterval or W.DayInterval
				local max = night and W.NightMax or W.DayMax
				if night and S.Cycle.event() == "fog" then max = max + W.FogBonus end
				if acc >= interval then
					acc = 0
					if count < max and #Players:GetPlayers() > 0 then
						-- чаще рядом с игроками в лесу
						local pos = nil
						local list = Players:GetPlayers()
						local pl = list[rng:NextInteger(1, #list)]
						local hrp = hrpOf(pl)
						if hrp and rng:NextNumber() < 0.7 then
							local a = rng:NextNumber(0, math.pi * 2)
							local cand = clampForest(flat(hrp.Position) + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(28, 60))
							if (cand - flat(hrp.Position)).Magnitude > 20 then pos = cand end
						end
						Wild.spawn({ pos = pos })
					end
				end
				-- испуг
				if night then
					for _, pl2 in ipairs(Players:GetPlayers()) do
						local h = hrpOf(pl2)
						if h and (scareCd[pl2] or 0) < now() and not isSafe(h.Position) then
							for _, st in pairs(wild) do
								if not st.idle and (flat(h.Position) - st.pos).Magnitude < W.ScareRange and rng:NextNumber() < st.rarity.scare * 0.5 then
									scare(pl2, st)
									break
								end
							end
						end
					end
				end
			end)
			if not ok then warn("[CN] Wild spawn: " .. tostring(err)) end
		end
	end)
	Players.PlayerRemoving:Connect(function(pl) scareCd[pl] = nil end)
end

return Wild
