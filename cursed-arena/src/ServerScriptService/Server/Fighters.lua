-- Реестр бойцов (игроки, боты, манекены) и их состояние.
-- Каждый кадр: скорость и прыжок по состоянию, атрибуты для клиентов, лечение, таймеры.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Characters = require(Shared.Characters)
local Util = require(Shared.Util)

local Fighters = {}
Fighters.list = {}
Fighters.byModel = {}
Fighters.onDied = nil      -- ставит Combat
Fighters.onExpire = {}     -- ставят другие модули: function(f, now)

local nextId = 0

function Fighters.new(model, kind, player, charId)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return nil end
	local old = Fighters.byModel[model]
	if old then Fighters.remove(old) end
	nextId = nextId + 1
	local now = Util.now()
	local f = {
		id = nextId, model = model, hum = hum, root = root, player = player, kind = kind,
		charId = Characters.valid(charId) and charId or Characters.Default,
		awakened = false, awakenEnd = 0, ultUsed = false, meter = 0,
		stunEnd = 0, busyEnd = 0, busySpeed = nil, busyJump = false, ragdollEnd = 0, ragdolled = false,
		iframesEnd = now + (kind == "dummy" and 0 or Config.SpawnProtection), evadeEnd = 0, armorEnd = 0,
		blocking = false, blockStart = 0, blockHp = Config.Block.MaxDurability, blockLockEnd = 0,
		m1Index = 0, m1Last = -100, m1CdEnd = 0, m1BusyEnd = 0, m1Jump = true,
		cds = { 0, 0, 0, 0 }, dashCd = { F = 0, B = 0, L = 0, R = 0 },
		moveToken = 0, moveId = nil, cleanup = {},
		lastHitBy = nil, lastHitTime = -100, lastDamageTime = -100, lastDealtTime = -100,
		combo = 0, comboLast = -100,
		silenceEnd = 0, rootEnd = 0, slowMult = 1, slowEnd = 0, invisEnd = 0, burnEnd = 0, blindEnd = 0,
		dead = false, spawnTime = now, attrs = {}, counter = nil, recast = nil,
		dmgBuff = 1, dmgBuffEnd = 0,
	}
	f.def = Characters.get(f.charId)
	Fighters.byModel[model] = f
	table.insert(Fighters.list, f)
	model:SetAttribute("Fighter", true)
	model:SetAttribute("Char", f.charId)
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Meter", 0)
	model:SetAttribute("Awakened", false)
	hum.MaxHealth = Config.MaxHealth
	hum.Health = Config.MaxHealth
	hum.UseJumpPower = false
	hum.BreakJointsOnDeath = false
	hum.Died:Connect(function()
		if Fighters.onDied then Fighters.onDied(f) end
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then Fighters.remove(f) end
	end)
	Fighters.dirty = true
	return f
end

function Fighters.remove(f)
	if not f or f.removed then return end
	f.removed = true
	f.dead = true
	if Fighters.byModel[f.model] == f then Fighters.byModel[f.model] = nil end
	for i = #Fighters.list, 1, -1 do
		if Fighters.list[i] == f then table.remove(Fighters.list, i) end
	end
	for _, c in ipairs(f.cleanup) do pcall(function() c:Destroy() end) end
	f.cleanup = {}
	Fighters.dirty = true
end

function Fighters.get(model)
	return model and Fighters.byModel[model]
end

-- боец по любой детали внутри модели
function Fighters.fromPart(part)
	local a = part
	for _ = 1, 6 do
		if not a then return nil end
		local f = Fighters.byModel[a]
		if f then return f end
		a = a.Parent
	end
	return nil
end

function Fighters.ofPlayer(player)
	for _, f in ipairs(Fighters.list) do
		if f.player == player and not f.dead then return f end
	end
	return nil
end

function Fighters.alive(f)
	return f ~= nil and not f.dead and not f.removed and f.hum.Health > 0 and f.model.Parent ~= nil
end

function Fighters.isStunned(f, now)
	now = now or Util.now()
	return now < f.stunEnd or f.ragdolled or now < f.rootEnd
end

-- может ли боец начать действие (удар, приём, рывок)
function Fighters.canAct(f, now)
	now = now or Util.now()
	if not Fighters.alive(f) then return false end
	if now < f.stunEnd or f.ragdolled or now < f.rootEnd then return false end
	if now < f.busyEnd then return false end
	if f.blocking then return false end
	return true
end

-- занят приёмом: на время замедлен, атаки недоступны
function Fighters.busy(f, t, speed, canJump)
	local now = Util.now()
	f.busyEnd = math.max(f.busyEnd, now + t)
	f.busySpeed = speed
	f.busyJump = canJump and true or false
end

function Fighters.clearBusy(f)
	f.busyEnd = 0
	f.busySpeed = nil
	f.busyJump = false
end

local function setAttr(f, name, value)
	if f.attrs[name] ~= value then
		f.attrs[name] = value
		f.model:SetAttribute(name, value)
	end
end
Fighters.setAttr = setAttr

-- враги этого бойца (все остальные живые)
function Fighters.enemies(f)
	local out = {}
	for _, o in ipairs(Fighters.list) do
		if o ~= f and Fighters.alive(o) then out[#out + 1] = o end
	end
	return out
end

local regenAcc = 0
function Fighters.step(dt)
	local now = Util.now()
	regenAcc = regenAcc + dt
	local doRegen = regenAcc >= 0.25
	if doRegen then regenAcc = 0 end
	for i = #Fighters.list, 1, -1 do
		local f = Fighters.list[i]
		if f and not f.dead and f.model.Parent then
			local hum = f.hum
			local stunned = now < f.stunEnd
			local rooted = now < f.rootEnd
			local busy = now < f.busyEnd
			local speed, jump
			if f.ragdolled or rooted then
				speed, jump = 0, 0
			elseif stunned then
				speed, jump = Config.StunSpeed, 0
			elseif f.blocking then
				speed, jump = Config.Block.Speed, 0
			elseif busy then
				speed = f.busySpeed or Config.BusySpeed
				jump = f.busyJump and Config.JumpHeight or 0
			elseif now < f.m1BusyEnd then
				speed = Config.M1.BusySpeed
				jump = f.m1Jump and Config.JumpHeight or 0
			else
				speed, jump = Config.WalkSpeed, Config.JumpHeight
			end
			if f.awakened and speed > 0 then speed = speed * Config.Awaken.SpeedMult end
			if now < f.slowEnd then speed = speed * f.slowMult end
			if f.kind == "dummy" then speed, jump = 0, 0 end
			if hum.WalkSpeed ~= speed then hum.WalkSpeed = speed end
			if hum.JumpHeight ~= jump then hum.JumpHeight = jump end
			if f.dmgBuffEnd > 0 and now >= f.dmgBuffEnd then
				f.dmgBuff = 1
				f.dmgBuffEnd = 0
			end
			-- атрибуты для клиентов (анимации, интерфейс)
			setAttr(f, "Stunned", stunned and not f.ragdolled)
			setAttr(f, "Blocking", f.blocking)
			setAttr(f, "Busy", busy)
			setAttr(f, "Rooted", rooted)
			setAttr(f, "Silenced", now < f.silenceEnd)
			setAttr(f, "IFrames", now < f.iframesEnd)
			setAttr(f, "Invisible", now < f.invisEnd)
			setAttr(f, "Burning", now < f.burnEnd)
			setAttr(f, "Blind", now < f.blindEnd)
			setAttr(f, "GuardBroken", now < f.blockLockEnd and stunned)
			-- блок понемногу восстанавливается
			if not f.blocking and f.blockHp < Config.Block.MaxDurability then
				f.blockHp = math.min(Config.Block.MaxDurability, f.blockHp + Config.Block.RegenPerSecond * dt)
			end
			-- счётчик комбо гаснет
			if f.combo > 0 and now - f.comboLast > Config.ComboResetTime then
				f.combo = 0
				if f.player and Fighters.onCombo then Fighters.onCombo(f) end
			end
			-- лечение вне боя
			if doRegen and hum.Health < hum.MaxHealth and hum.Health > 0 then
				if f.kind == "dummy" then
					if now - f.lastDamageTime > Config.Dummy.HealDelay then hum.Health = hum.MaxHealth end
				elseif now - f.lastDamageTime > Config.RegenDelay then
					hum.Health = math.min(hum.MaxHealth, hum.Health + Config.RegenPerSecond * 0.25)
				end
			end
			-- падение с карты
			if f.root.Position.Y < Config.KillPlaneY then
				hum.Health = 0
			end
			for _, fn in ipairs(Fighters.onExpire) do fn(f, now) end
		end
	end
end

return Fighters
