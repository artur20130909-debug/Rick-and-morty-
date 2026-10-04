-- Матч: один дом и 1–4 игрока из кабинки лобби.
-- Фазы: loading → day (7:00–21:00) → alert (оповещение по ТВ) → night (до 7:00) → dawn → следующий день … → end.
-- Смерть: тело остаётся, игрок наблюдает; на рассвете или дефибриллятором — оживление.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Match = {}
local ctx, Config, Net, Sound, B
local matches = {}        -- [id] = матч
local byPlayer = {}       -- [Player] = матч
local usedSlots = {}      -- [слот] = id матча (каждый дом стоит в своём месте мира)
local nextId = 0

local M = {}
M.__index = M

local function charParts(plr)
	local char = plr.Character
	return char, char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end

local function insideBox(part, pos, pad)
	local l = part.CFrame:PointToObjectSpace(pos)
	local s = part.Size / 2
	pad = pad or 0
	return math.abs(l.X) <= s.X + pad and math.abs(l.Y) <= s.Y + pad and math.abs(l.Z) <= s.Z + pad
end

---------------------------------------------------------------- методы матча (их используют InmateAI и Items)
function M:isAlive(plr)
	return self.alive[plr] == true
end

function M:alivePlayers()
	local t = {}
	for _, p in ipairs(self.players) do
		if self.alive[p] then table.insert(t, p) end
	end
	return t
end

function M:toast(text, color)
	for _, p in ipairs(self.players) do
		if p.Parent then Net.event("Toast"):FireClient(p, text, color) end
	end
end

function M:fx(kind, a, b, c)
	for _, p in ipairs(self.players) do
		if p.Parent then Net.event("Fx"):FireClient(p, kind, a, b, c) end
	end
end

function M:fxTo(plr, kind, a, b, c)
	if plr and plr.Parent then Net.event("Fx"):FireClient(plr, kind, a, b, c) end
end

function M:isIndoors(pos)
	local box = self.house and self.house.interior
	return box ~= nil and insideBox(box, pos)
end

function M:roomAt(pos)
	for _, r in ipairs((self.house and self.house.rooms) or {}) do
		if insideBox(r, pos) then return r end
	end
	return nil
end

function M:setAttrs()
	local f = self.folder
	f:SetAttribute("Id", self.id)
	f:SetAttribute("Phase", self.phase)
	f:SetAttribute("Clock", self.clock)
	f:SetAttribute("Night", self.night)
	f:SetAttribute("Nights", self.nights)
	f:SetAttribute("Difficulty", self.diffKey)
	f:SetAttribute("Inmate", self.inmateKey or "")
	f:SetAttribute("Unknown", self.unknown == true)
	f:SetAttribute("Power", self.power ~= false)
	f:SetAttribute("PlayerCount", #self.players)
	f:SetAttribute("Sprinkler", self.sprinkler == true)
	f:SetAttribute("DirectiveCode", "")
	f:SetAttribute("DirectiveText", "")
	if self.house then f:SetAttribute("HouseName", self.house.model.Name) end
end

function M:setPhase(phase)
	self.phase = phase
	self.folder:SetAttribute("Phase", phase)
end

function M:damagePlayer(plr, amount, inm)
	if not self:isAlive(plr) then return end
	local _, _, hum = charParts(plr)
	if not hum then return end
	if hum.Health - amount <= 0 then
		self:killPlayer(plr, inm)
		return
	end
	hum:TakeDamage(amount)
	self:fxTo(plr, "hurt", amount)
end

-- смерть от заключённого: скример у жертвы, через 1.5 с персонаж падает
function M:killPlayer(plr, inm)
	if not self:isAlive(plr) or self.dying[plr] then return end
	self.dying[plr] = true
	self.alive[plr] = false
	ctx.HouseLogic.unhide(plr)
	local _, hrp = charParts(plr)
	if hrp then hrp.Anchored = true end
	self:fxTo(plr, "jumpscare", inm and inm.key or "", inm and inm.model)
	for _, p in ipairs(self.players) do
		if p ~= plr then self:fxTo(p, "sound", "Stinger") end
	end
	task.delay(1.5, function()
		self.dying[plr] = nil
		local _, r, hum = charParts(plr)
		if r then r.Anchored = false end
		if hum and hum.Health > 0 then hum.Health = 0 end
		if self.alive[plr] == false and plr:GetAttribute("Alive") ~= false then self:onDied(plr) end
	end)
end

-- персонаж умер (заключённый, падение и т.п.): тело, наблюдение, проверка «все мертвы»
function M:onDied(plr)
	if plr:GetAttribute("Alive") == false and not self.alive[plr] and self.bodies[plr] then return end
	self.alive[plr] = false
	plr:SetAttribute("Alive", false)
	plr:SetAttribute("Hidden", false)
	plr:SetAttribute("Flashlight", false)
	ctx.HouseLogic.unhide(plr)
	if self.bodies[plr] then return end
	local _, hrp = charParts(plr)
	local cf = hrp and hrp.CFrame or (self.house and self.house.spawns[1]) or CFrame.new()
	local marker = B.marker(self.house and self.house.model or workspace, "Body_" .. plr.UserId, Vector3.new(3, 2, 3), CFrame.new(cf.Position))
	local prompt = B.prompt(marker, "Prompt", "Оживить", plr.DisplayName, { HoldDuration = 1.5, KeyboardKeyCode = Enum.KeyCode.E, MaxActivationDistance = 10 })
	prompt.Triggered:Connect(function(by)
		if by == plr or not self:isAlive(by) then return end
		if ctx.Items.count(by, "defib") <= 0 then
			Net.event("Toast"):FireClient(by, "Нужен дефибриллятор (магазин в гараже)")
			return
		end
		ctx.Items.take(by, "defib")
		local _, r = charParts(by)
		if r then Sound.play("Defib", r, { Volume = 1 }) end
		Match.revive(self, plr, cf)
		self:toast(by.DisplayName .. " оживил(а) " .. plr.DisplayName .. "!", Color3.fromRGB(120, 255, 160))
	end)
	self.bodies[plr] = { player = plr, cf = cf, marker = marker }
	self:toast(plr.DisplayName .. " погиб(ла)…", Color3.fromRGB(255, 80, 80))
end

function M:onInmateKilled(inm, byPlayer)
	local i = table.find(self.inmates, inm)
	if i then table.remove(self.inmates, i) end
	if byPlayer and byPlayer.Parent and byPlayer:GetAttribute("MatchId") == self.id then
		byPlayer:SetAttribute("Money", (byPlayer:GetAttribute("Money") or 0) + Config.KillBounty)
		self:fxTo(byPlayer, "coin", Config.KillBounty)
		self.kills = (self.kills or 0) + 1
	end
	self:fx("killed", inm and inm.key or "")
	self:toast("Заключённый обезврежен!", Color3.fromRGB(120, 255, 160))
	if #self.inmates == 0 and self.phase == "night" then
		self.clock = math.max(self.clock, Config.Time.nightEnd - 0.6)   -- до рассвета остаётся чуть-чуть
	end
end

---------------------------------------------------------------- помощники
local function spawnAt(plr, cf)
	local char, hrp, hum = charParts(plr)
	if not char or not hum or hum.Health <= 0 then
		plr:LoadCharacter()
		char, hrp, hum = charParts(plr)
	end
	if char and hrp then
		hrp.Anchored = false
		char:PivotTo(cf + Vector3.new(0, 0.5, 0))
	end
	if hum then hum.Health = hum.MaxHealth end
end

function Match.revive(match, plr, cf)
	local body = match.bodies[plr]
	if body then
		if body.marker then body.marker:Destroy() end
		match.bodies[plr] = nil
	end
	match.alive[plr] = true
	match.dying[plr] = nil
	plr:SetAttribute("Alive", true)
	plr:SetAttribute("Hidden", false)
	plr:LoadCharacter()
	local char = plr.Character
	if char then char:PivotTo(cf + Vector3.new(0, 0.5, 0)) end
	plr.CameraMode = Enum.CameraMode.LockFirstPerson
	match:fxTo(plr, "revived")
end

function Match.nearestBody(match, pos, radius)
	local best, bd = nil, radius or 10
	for _, b in pairs(match.bodies) do
		local d = (b.cf.Position - pos).Magnitude
		if d < bd then best, bd = b, d end
	end
	return best
end

function Match.of(plr)
	return byPlayer[plr]
end

function Match.list()
	return matches
end

---------------------------------------------------------------- фазы
local function inmateInfo(key)
	if not key or not ctx.InmateAI then return nil end
	local ok, def = pcall(ctx.InmateAI.info, key)
	return ok and def or nil
end

local function startAlert(m)
	m:setPhase("alert")
	m.alertT = 0
	local key = nil
	if ctx.InmateAI then
		local ok, k = pcall(ctx.InmateAI.choose, m)
		if ok then key = k else warn("[AA] InmateAI.choose: " .. tostring(k)) end
	end
	m.inmateKey = key
	local def = inmateInfo(key)
	m.unknown = (def ~= nil and def.unknownAlert == true) or (m.diffKey ~= "easy" and math.random() < 0.12)
	local data = { duration = Config.Time.alertSeconds, night = m.night, nights = m.nights, unknown = m.unknown, directive = nil }
	if m.unknown or not def then
		data.lines = Config.AlertUnknown
		data.num, data.name, data.threat = "???", "НЕИЗВЕСТЕН", "Класс угрозы: неизвестен"
		data.tip = "Оставайтесь в помещении. Заприте двери."
		data.inmate = nil
	else
		data.lines = def.alert or {}
		data.num, data.name, data.threat, data.tip, data.inmate = def.num, def.name, def.class, def.tip, key
	end
	m.folder:SetAttribute("Inmate", key or "")
	m.folder:SetAttribute("Unknown", m.unknown == true)
	-- указание телеведущего (со 2-й ночи)
	m.directive = nil
	if m.night >= 2 and math.random() < Config.DirectiveChance then
		local pool = {}
		for _, d in ipairs(Config.Directives) do
			if not d.coop or #m.players > 1 then table.insert(pool, d) end
		end
		if #pool > 0 then m.directive = pool[math.random(1, #pool)] end
	end
	if m.directive then data.directive = { code = m.directive.code, text = m.directive.text } end
	m.folder:SetAttribute("DirectiveCode", m.directive and m.directive.code or "")
	m.folder:SetAttribute("DirectiveText", m.directive and m.directive.text or "")
	-- все к телевизору: смотрят трансляцию
	ctx.HouseLogic.unhideAll(m)
	local spots = m.house.alertSpots or {}
	for i, plr in ipairs(m:alivePlayers()) do
		local cf = spots[((i - 1) % math.max(1, #spots)) + 1] or m.house.spawns[1]
		local char, hrp = charParts(plr)
		if char and hrp then
			hrp.Anchored = false
			char:PivotTo(cf + Vector3.new(0, 0.5, 0))
			hrp.Anchored = true
		end
	end
	for _, plr in ipairs(m.players) do
		if plr.Parent then Net.event("Alert"):FireClient(plr, data) end
	end
end

local function startNight(m)
	m:setPhase("night")
	m.nightT = 0
	for _, plr in ipairs(m.players) do
		local _, hrp = charParts(plr)
		if hrp and not m.dying[plr] then hrp.Anchored = false end
	end
	local n = 1
	if (m.diff.endless and m.night > 6) or (m.diffKey == "hard" and m.night >= 8) then n = 2 end
	if ctx.InmateAI then
		local keys = { m.inmateKey }
		if n > 1 then
			local ok, k2 = pcall(ctx.InmateAI.choose, m)
			if ok and k2 then table.insert(keys, k2) end
		end
		for _, key in ipairs(keys) do
			if key then
				local ok, inm = pcall(ctx.InmateAI.spawn, m, key)
				if ok and inm then
					if not table.find(m.inmates, inm) then table.insert(m.inmates, inm) end
				elseif not ok then
					warn("[AA] Не удалось выпустить заключённого " .. tostring(key) .. ": " .. tostring(inm))
				end
			end
		end
	end
	m:toast("Ночь " .. m.night .. ". Доживи до 7:00!", Color3.fromRGB(255, 90, 80))
	m:fx("sound", "Stinger")
end

-- нарушает ли игрок указание телеведущего прямо сейчас
local function violating(m, plr, code)
	local _, hrp = charParts(plr)
	if not hrp then return false end
	if code == "stay_inside" then return not m:isIndoors(hrp.Position) end
	if code == "lights_on" then return m.power == false end
	if code == "no_hiding" then return plr:GetAttribute("Hidden") == true end
	if code == "no_flashlight" then return plr:GetAttribute("Flashlight") == true end
	if code == "upstairs" or code == "downstairs" then
		local r = m:roomAt(hrp.Position)
		local floor = r and r:GetAttribute("Floor") or 1
		if code == "upstairs" then return floor ~= 2 end
		return floor == 2
	end
	if code == "together" then
		local alone = true
		local others = 0
		for _, p in ipairs(m:alivePlayers()) do
			if p ~= plr then
				others = others + 1
				local _, r = charParts(p)
				if r and (r.Position - hrp.Position).Magnitude < 40 then alone = false end
			end
		end
		return others > 0 and alone
	end
	return false
end

-- за игроком пришёл Телеведущий
local function summonBroadcaster(m, plr)
	m.summoned = m.summoned or {}
	if m.summoned[plr] then return end
	m.summoned[plr] = true
	m:toast("ТЕЛЕВЕДУЩИЙ ПРИШЁЛ ЗА " .. string.upper(plr.DisplayName), Color3.fromRGB(255, 60, 60))
	local spawned = false
	if ctx.InmateAI and inmateInfo("Broadcaster") then
		local ok, inm = pcall(ctx.InmateAI.spawn, m, "Broadcaster")
		if ok and inm then
			inm.forcedTarget = plr
			if inm.model then inm.model:SetAttribute("TargetUserId", plr.UserId) end
			if not table.find(m.inmates, inm) then table.insert(m.inmates, inm) end
			spawned = true
		end
	end
	if not spawned then
		m:fxTo(plr, "sound", "Static")
		task.delay(2, function()
			if m:isAlive(plr) then m:killPlayer(plr, { key = "Broadcaster" }) end
		end)
	end
end

local function updateStatic(m, dt)
	local code = m.directive and m.directive.code
	for _, plr in ipairs(m:alivePlayers()) do
		local st = plr:GetAttribute("Static") or 0
		if code and m.nightT > 15 and violating(m, plr, code) then
			st = st + Config.StaticRise * dt
		else
			st = st - Config.StaticDecay * dt
		end
		st = math.clamp(st, 0, 100)
		plr:SetAttribute("Static", math.floor(st * 10 + 0.5) / 10)
		if st >= 100 then summonBroadcaster(m, plr) end
	end
end

local function startDawn(m)
	m:setPhase("dawn")
	m.dawnT = 0
	m.clock = Config.Time.nightEnd
	if ctx.InmateAI then pcall(ctx.InmateAI.despawnAll, m) end
	m.inmates = {}
	ctx.HouseLogic.unhideAll(m)
	ctx.HouseLogic.repairAll(m)
	local spawns = m.house.spawns
	for i, plr in ipairs(m.players) do
		plr:SetAttribute("Money", (plr:GetAttribute("Money") or 0) + Config.DawnBonus)
		plr:SetAttribute("Static", 0)
		if not m.alive[plr] then
			Match.revive(m, plr, spawns[((i - 1) % #spawns) + 1])
		else
			ctx.Data.addXp(plr, 15)
		end
	end
	m.directive = nil
	m.summoned = {}
	m.folder:SetAttribute("DirectiveCode", "")
	m.folder:SetAttribute("DirectiveText", "")
	m:fx("sound", "Dawn")
	m:toast("Рассвет! Ночь " .. m.night .. " позади. +$" .. Config.DawnBonus, Color3.fromRGB(255, 220, 140))
end

local function cleanup(m)
	if m.cleaned then return end
	m.cleaned = true
	if ctx.InmateAI then pcall(ctx.InmateAI.despawnAll, m) end
	pcall(ctx.HouseLogic.detach, m)
	for _, b in pairs(m.bodies) do if b.marker then b.marker:Destroy() end end
	for _, p in ipairs(m.props or {}) do if p.Parent then p:Destroy() end end
	if m.house then
		local ok, err = pcall(ctx.HouseMap.destroy, m.house)
		if not ok then
			warn("[AA] HouseMap.destroy: " .. tostring(err))
			if m.house.model then m.house.model:Destroy() end
		end
	end
	if m.folder then m.folder:Destroy() end
	matches[m.id] = nil
	if m.slot then usedSlots[m.slot] = nil end
	for _, p in ipairs(m.players) do
		if byPlayer[p] == m then byPlayer[p] = nil end
	end
end

-- конец матча: награды, экран итогов, через 8 с — обратно в лобби
function Match.finish(m, win, text)
	if m.phase == "end" then return end
	m:setPhase("end")
	if ctx.InmateAI then pcall(ctx.InmateAI.despawnAll, m) end
	local survived = win and m.night or (m.night - 1)
	for _, plr in ipairs(m.players) do
		if plr.Parent then
			local amber, xp
			if m.diff.endless then
				amber, xp = 12 * survived, 25 * survived
			elseif win then
				amber, xp = m.diff.amber, m.diff.xp
			else
				amber = math.floor(m.diff.amber * 0.12 * survived)
				xp = 10 + math.floor(m.diff.xp * 0.2 * survived)
			end
			ctx.Data.addAmber(plr, amber)
			ctx.Data.addXp(plr, xp)
			ctx.Data.addStats(plr, survived, win)
			ctx.Data.save(plr)
			Net.event("Scene"):FireClient(plr, "end", { win = win, nights = survived, amber = amber, xp = xp,
				text = text or (win and "Вы пережили все ночи!" or "Все погибли…") })
			m:fxTo(plr, "sound", win and "Win" or "Lose")
		end
	end
	task.delay(8, function()
		for _, plr in ipairs(m.players) do
			if plr.Parent and byPlayer[plr] == m then
				byPlayer[plr] = nil
				if ctx.Lobby then ctx.Lobby.sendToLobby(plr) end
			end
		end
		cleanup(m)
	end)
end

local function step(m, dt)
	local T = Config.Time
	if m.phase == "day" then
		m.clock = m.clock + (T.alertAt - T.dayStart) / m.diff.daySeconds * dt
		m.appleT = m.appleT + dt * (m.sprinkler and 2 or 1)
		if m.appleT >= Config.AppleGrowSeconds then
			m.appleT = 0
			ctx.HouseLogic.growApples(m)
		end
		if m.clock >= T.alertAt then
			m.clock = T.alertAt
			startAlert(m)
		end
	elseif m.phase == "alert" then
		m.alertT = m.alertT + dt
		if m.alertT >= T.alertSeconds then startNight(m) end
	elseif m.phase == "night" then
		m.clock = m.clock + (T.nightEnd - T.alertAt) / m.diff.nightSeconds * dt
		m.nightT = m.nightT + dt
		local anyDying = next(m.dying) ~= nil
		if #m:alivePlayers() == 0 and not anyDying then
			Match.finish(m, false, "Никто не дожил до утра. Ночь " .. m.night)
			return
		end
		updateStatic(m, dt)
		if m.clock >= T.nightEnd then startDawn(m) end
	elseif m.phase == "dawn" then
		m.dawnT = m.dawnT + dt
		if m.dawnT >= T.dawnSeconds then
			if not m.diff.endless and m.night >= m.nights then
				Match.finish(m, true)
				return
			end
			m.night = m.night + 1
			m.clock = T.dayStart
			m:setPhase("day")
			m.folder:SetAttribute("Night", m.night)
			m:toast("День " .. m.night .. " из " .. (m.diff.endless and "∞" or tostring(m.nights)) .. ". Готовься к ночи!", Color3.fromRGB(255, 220, 140))
		end
	end
	m.folder:SetAttribute("Clock", m.clock)
end

local function run(m)
	local t0 = os.clock()
	local house = ctx.HouseMap.build(m.origin, workspace.Houses, "House_" .. m.id)
	if not house or not house.model then error("HouseMap.build ничего не вернул") end
	m.house = house
	m.folder:SetAttribute("HouseName", house.model.Name)
	ctx.HouseLogic.attach(m)
	task.wait(math.max(0, Config.Time.loadingSeconds - (os.clock() - t0)))
	local spawns = house.spawns
	for i, plr in ipairs(m.players) do
		if plr.Parent then
			ctx.Items.giveStart(plr)
			m.alive[plr] = true
			plr:SetAttribute("Alive", true)
			plr:SetAttribute("Static", 0)
			plr:SetAttribute("Hidden", false)
			spawnAt(plr, spawns[((i - 1) % #spawns) + 1])
			plr.CameraMode = Enum.CameraMode.LockFirstPerson
			Net.event("Scene"):FireClient(plr, "house", { matchId = m.id, house = house.model })
		end
	end
	m.clock = Config.Time.dayStart
	m:setPhase("day")
	m:setAttrs()
	m:toast("День 1 из " .. (m.diff.endless and "∞" or tostring(m.nights)) .. ". Собирай яблоки, продавай их в гараже и готовься к 21:00.",
		Color3.fromRGB(255, 220, 140))
	local last = os.clock()
	while m.phase ~= "end" do
		task.wait(0.1)
		local now = os.clock()
		local dt = math.min(0.5, now - last)
		last = now
		if #m.players == 0 then break end
		local ok, err = pcall(step, m, dt)
		if not ok then
			m.stepErrors = (m.stepErrors or 0) + 1
			if m.stepErrors <= 3 then warn("[AA] Ошибка шага матча: " .. tostring(err)) end
		end
	end
	if #m.players == 0 then cleanup(m) end
end

function Match.start(players, diffKey)
	local list = {}
	for _, plr in ipairs(players) do
		if plr.Parent and not byPlayer[plr] and #list < Config.MaxPlayersPerHouse then table.insert(list, plr) end
	end
	if #list == 0 then return nil end
	local diff = Config.Difficulties[diffKey] or Config.Difficulties.normal
	nextId = nextId + 1
	local slot = 1
	while usedSlots[slot] do slot = slot + 1 end
	usedSlots[slot] = nextId
	local folder = Instance.new("Folder")
	folder.Name = "Match_" .. nextId
	folder.Parent = RS:WaitForChild("Matches")
	local m = setmetatable({
		id = nextId, slot = slot, folder = folder, origin = Vector3.new(3000 + 1200 * slot, 0, 0),
		diffKey = Config.Difficulties[diffKey] and diffKey or "normal", diff = diff,
		night = 1, nights = diff.endless and 9999 or diff.nights, phase = "loading", clock = Config.Time.dayStart,
		players = list, alive = {}, dying = {}, bodies = {}, inmates = {}, used = {}, props = {}, conns = {},
		power = true, sprinkler = false, appleT = 0, alertT = 0, nightT = 0, dawnT = 0, kills = 0,
	}, M)
	matches[m.id] = m
	m:setAttrs()
	for _, plr in ipairs(list) do
		byPlayer[plr] = m
		plr:SetAttribute("MatchId", m.id)
		Net.event("Scene"):FireClient(plr, "loading", { text = "Дом 1990 · " .. diff.name })
	end
	task.spawn(function()
		local ok, err = pcall(run, m)
		if not ok then
			warn("[AA] Матч " .. m.id .. " упал: " .. tostring(err))
			m:toast("Ошибка загрузки дома — возвращаемся в лобби", Color3.fromRGB(255, 80, 80))
			for _, plr in ipairs(m.players) do
				if plr.Parent and byPlayer[plr] == m then
					byPlayer[plr] = nil
					if ctx.Lobby then ctx.Lobby.sendToLobby(plr) end
				end
			end
			m.phase = "end"
			cleanup(m)
		end
	end)
	return m
end

---------------------------------------------------------------- игроки
local function onCharacter(plr, char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	hum.Died:Connect(function()
		local m = byPlayer[plr]
		if m and m.phase ~= "end" and m.phase ~= "loading" then
			m:onDied(plr)
		elseif not m then
			task.delay(2.5, function()
				if plr.Parent and not byPlayer[plr] and ctx.Lobby then ctx.Lobby.sendToLobby(plr) end
			end)
		end
	end)
end

function Match.init(c)
	ctx = c
	Config = c.Config
	Net = c.Net
	Sound = c.Sound
	B = c.Build
	local function hook(plr)
		plr.CharacterAdded:Connect(function(char) onCharacter(plr, char) end)
		if plr.Character then task.spawn(onCharacter, plr, plr.Character) end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do hook(p) end
	Players.PlayerRemoving:Connect(function(plr)
		local m = byPlayer[plr]
		if not m then return end
		byPlayer[plr] = nil
		local i = table.find(m.players, plr)
		if i then table.remove(m.players, i) end
		m.alive[plr] = nil
		m.dying[plr] = nil
		local b = m.bodies[plr]
		if b and b.marker then b.marker:Destroy() end
		m.bodies[plr] = nil
		m.folder:SetAttribute("PlayerCount", #m.players)
		if #m.players == 0 then
			m.phase = "end"
			cleanup(m)
		end
	end)
end

return Match
