-- Боты-соперники и тренировочные манекены.
-- Боты пользуются теми же действиями, что и игроки: M1, блок, рывки, приёмы, пробуждение.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Characters = require(Shared.Characters)
local Costumes = require(Shared.Costumes)
local Fighters = require(script.Parent.Fighters)
local Combat = require(script.Parent.Combat)
local Actions = require(script.Parent.Actions)
local Spawner = require(script.Parent.Spawner)
local MapService = require(script.Parent.MapService)
local Net = require(script.Parent.Net)

local Bots = {}
Bots.count = Config.Bots.Default
Bots.level = Config.Bots.DefaultDifficulty
Bots.list = {}     -- { f, name, charId, slot }
Bots.dummies = {}

local folder
local rng = Random.new()
local usedNames = {}

local function template()
	return game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
end

local function spawnPoint(i)
	local pts = MapService.markers("BotSpawn")
	if #pts == 0 then
		local spawns = {}
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("SpawnLocation") then spawns[#spawns + 1] = d.CFrame end
		end
		pts = spawns
	end
	if #pts == 0 then return CFrame.new(0, 5, 0) end
	local cf = pts[((i or rng:NextInteger(1, #pts)) - 1) % #pts + 1]
	return cf + Vector3.new(rng:NextNumber(-6, 6), 3, rng:NextNumber(-6, 6))
end

local function makeModel(name, charId, cf, costume)
	local tmpl = template()
	if not tmpl then return nil end
	local m = tmpl:Clone()
	m.Name = name
	Costumes.apply(m, costume or charId)
	local hum = m:FindFirstChildOfClass("Humanoid")
	hum.DisplayName = name
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	hum.NameDisplayDistance = 80
	m:SetAttribute("DisplayName", name)
	m:PivotTo(cf)
	m.Parent = folder
	pcall(function() m.HumanoidRootPart:SetNetworkOwner(nil) end)
	return m
end

local function pickName()
	for _, n in ipairs(Config.Bots.Names) do
		if not usedNames[n] then
			usedNames[n] = true
			return n
		end
	end
	return "Бот" .. rng:NextInteger(10, 99)
end

---------------------------------------------------------------- боты
local function spawnBot(b)
	local charId = Characters.List[rng:NextInteger(1, #Characters.List)]
	b.charId = charId
	local m = makeModel(b.name, charId, spawnPoint(b.slot), charId)
	if not m then return end
	local f = Fighters.new(m, "bot", nil, charId)
	b.f = f
	b.target = nil
	b.retarget = 0
	b.nextThink = 0
	b.blockUntil = 0
	b.strafe = rng:NextInteger(0, 1) == 0 and 1 or -1
	Spawner.setupWeapon(f)
	Net.fx("Swap", { m = m, c = charId })
end

local function addBot(slot)
	local b = { name = pickName(), slot = slot }
	Bots.list[#Bots.list + 1] = b
	spawnBot(b)
	return b
end

local function removeBot(b)
	usedNames[b.name] = nil
	b.removed = true
	if b.f and b.f.model.Parent then b.f.model:Destroy() end
	for i = #Bots.list, 1, -1 do
		if Bots.list[i] == b then table.remove(Bots.list, i) end
	end
end

function Bots.configure(count, level)
	if type(count) == "number" then Bots.count = math.clamp(math.floor(count), 0, Config.Bots.Max) end
	if type(level) == "number" then Bots.level = math.clamp(math.floor(level), 1, #Config.Bots.Difficulty) end
	while #Bots.list > Bots.count do removeBot(Bots.list[#Bots.list]) end
	while #Bots.list < Bots.count do addBot(#Bots.list + 1) end
	Net.fx("BotsConfig", { n = Bots.count, l = Bots.level })
	return Bots.count, Bots.level
end

-- выбрать цель: ближайший живой, игроки чуть «приятнее»
local function chooseTarget(b)
	local f = b.f
	local best, bestS
	for _, o in ipairs(Fighters.list) do
		if o ~= f and Fighters.alive(o) and o.kind ~= "dummy" then
			local d = (o.root.Position - f.root.Position).Magnitude
			local s = d * (o.kind == "player" and 0.75 or 1)
			if not bestS or s < bestS then best, bestS = o, s end
		end
	end
	return best
end

local function think(b, now)
	local f = b.f
	if not f or not Fighters.alive(f) then return end
	local lvl = Config.Bots.Difficulty[Bots.level]
	if now < b.nextThink then return end
	b.nextThink = now + lvl.React * rng:NextNumber(0.7, 1.3)
	local hum = f.hum
	if f.ragdolled or now < f.stunEnd then
		if f.blocking then Actions.block(f, false) end
		return
	end
	if not b.target or not Fighters.alive(b.target) or now > b.retarget then
		b.target = chooseTarget(b)
		b.retarget = now + rng:NextNumber(2, 4)
	end
	local t = b.target
	if not t then
		hum:MoveTo(f.root.Position)
		return
	end
	local myPos, tPos = f.root.Position, t.root.Position
	local delta = tPos - myPos
	local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local dir = Util.flat(delta, f.root.CFrame.LookVector)
	local aim = { dir = dir, pos = tPos }

	-- блок, если враг рядом бьёт
	if f.blocking then
		if now > b.blockUntil or dist > 12 then Actions.block(f, false) end
		return
	end
	local tAttacking = now < t.busyEnd and dist < 10
	if tAttacking and rng:NextNumber() < lvl.Block then
		hum:MoveTo(myPos)
		Actions.block(f, true)
		b.blockUntil = now + rng:NextNumber(0.4, 0.9)
		return
	end

	-- пробуждение
	if f.meter >= Config.Awaken.Max and not f.awakened and dist < 40 then
		if Actions.awaken(f) then return end
	end

	-- приёмы
	if rng:NextNumber() < lvl.MoveChance then
		local moves = Characters.moveset(f.charId, f.awakened)
		local order = { 1, 2, 3, 4 }
		Util.shuffle(order, rng)
		for _, slot in ipairs(order) do
			local mv = moves[slot]
			local ai = mv.AI or {}
			local range = ai.range or 10
			local okRange = dist <= range and (ai.kind ~= "melee" or dist <= 9) and (ai.kind ~= "aoe" or dist <= range)
			if ai.kind == "defense" then okRange = tAttacking end
			if mv.Ultimate and (not f.awakened or f.ultUsed) then okRange = false end
			if okRange and now >= f.cds[slot] then
				if Actions.move(f, slot, aim) then return end
			end
		end
	end

	-- низкое здоровье: отскок
	if hum.Health < 25 and dist < 8 and rng:NextNumber() < lvl.Dash then
		Actions.dash(f, "B", -dir)
		return
	end

	if dist > 6.5 then
		-- сближение
		local goal = tPos - dir * 3.2
		hum:MoveTo(goal)
		if dist > 18 and dist < 45 and rng:NextNumber() < lvl.Dash * 0.5 then
			Actions.dash(f, "F", dir)
		end
	else
		-- вплотную: бой
		if rng:NextNumber() < 0.25 then
			local side = f.root.CFrame.RightVector * b.strafe
			hum:MoveTo(myPos + side * 4 + dir * 0.5)
			if rng:NextNumber() < 0.15 then b.strafe = -b.strafe end
		else
			hum:MoveTo(myPos + dir * 0.6)
		end
		if rng:NextNumber() < lvl.Aggro then
			Actions.m1(f, aim, rng:NextNumber() < 0.25)
		end
		if rng:NextNumber() < lvl.Dash * 0.15 then
			Actions.dash(f, rng:NextInteger(0, 1) == 0 and "L" or "R")
		end
	end
end

---------------------------------------------------------------- манекены
local function spawnDummy(d)
	local m = makeModel("Манекен", "Dummy", d.cf + Vector3.new(0, 3, 0), "Dummy")
	if not m then return end
	local f = Fighters.new(m, "dummy", nil, "StormFist")
	f.iframesEnd = 0
	d.f = f
	m:SetAttribute("Char", "Dummy")
	m:SetAttribute("DisplayName", "Манекен")
end

function Bots.init()
	folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = workspace
	for _, cf in ipairs(MapService.markers("Dummy")) do
		local d = { cf = cf }
		Bots.dummies[#Bots.dummies + 1] = d
		spawnDummy(d)
	end
	Bots.configure(Bots.count, Bots.level)

	table.insert(Combat.onKill, function(killer, victim)
		for _, b in ipairs(Bots.list) do
			if b.f == victim then
				local model = victim.model
				task.delay(Config.Bots.RespawnTime, function()
					if b.removed then return end
					if model.Parent then model:Destroy() end
					spawnBot(b)
				end)
			end
		end
		for _, d in ipairs(Bots.dummies) do
			if d.f == victim then
				local model = victim.model
				task.delay(Config.Dummy.RespawnTime, function()
					if model.Parent then model:Destroy() end
					spawnDummy(d)
				end)
			end
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 0.05 then return end
		acc = 0
		local now = Util.now()
		for _, b in ipairs(Bots.list) do
			local ok, err = pcall(think, b, now)
			if not ok then warn("[Bots] " .. tostring(err)) end
		end
		-- манекены возвращаются на место
		for _, d in ipairs(Bots.dummies) do
			local f = d.f
			if f and Fighters.alive(f) and not f.ragdolled and now > f.stunEnd + 1.5 then
				local home = d.cf.Position + Vector3.new(0, 3, 0)
				if (f.root.Position - home).Magnitude > 4 then
					f.root.CFrame = CFrame.lookAt(home, home + d.cf.LookVector)
					f.root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end)
end

return Bots
