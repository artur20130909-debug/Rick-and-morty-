-- Урон, блок, парирование, оглушение, отбрасывание, шкала пробуждения, убийства.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Characters = require(Shared.Characters)
local Fighters = require(script.Parent.Fighters)
local Ragdoll = require(script.Parent.Ragdoll)
local Net = require(script.Parent.Net)

local Combat = {}
Combat.onKill = {}  -- function(killer, victim)

local function now() return Util.now() end

-- множитель урона атакующего
function Combat.damageMult(f)
	if not f then return 1 end
	local m = f.dmgBuff or 1
	if f.awakened then m = m * Config.Awaken.DamageMult end
	return m
end

function Combat.setMeter(f, v)
	f.meter = math.clamp(v, 0, Config.Awaken.Max)
	local shown = math.floor(f.meter + 0.5)
	if f.attrs.Meter ~= shown then
		f.attrs.Meter = shown
		f.model:SetAttribute("Meter", shown)
	end
end

function Combat.addMeter(f, amount)
	if not f or f.awakened or f.kind == "dummy" then return end
	Combat.setMeter(f, f.meter + amount)
end

-- прервать текущий приём бойца
function Combat.cancelMove(f)
	f.moveToken = f.moveToken + 1
	f.moveId = nil
	f.counter = nil
	f.recast = nil
	Fighters.clearBusy(f)
	for _, c in ipairs(f.cleanup) do pcall(function() c:Destroy() end) end
	f.cleanup = {}
	Net.fx("AnimStop", { m = f.model })
end

function Combat.stun(f, t)
	if not f or t <= 0 then return end
	f.stunEnd = math.max(f.stunEnd, now() + t)
	f.blocking = false
end

-- отбросить: скорость vel (мировая) на время t
function Combat.knockback(f, vel, t)
	local root = f.root
	if not root or not root.Parent then return end
	local old = root:FindFirstChild("Knockback")
	if old then old:Destroy() end
	local att = root:FindFirstChild("KnockbackAtt")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "KnockbackAtt"
		att.Parent = root
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Knockback"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = 1e7
	lv.VectorVelocity = vel
	lv.Parent = root
	Debris:AddItem(lv, t or 0.18)
end

-- направление «от атакующего к цели» по горизонтали
function Combat.away(attacker, target)
	if not attacker then return Util.flat(target.root.CFrame.LookVector * -1) end
	return Util.flat(target.root.Position - attacker.root.Position, attacker.root.CFrame.LookVector)
end

function Combat.guardBreak(target, attacker)
	target.blocking = false
	target.blockHp = Config.Block.MaxDurability
	target.stunEnd = math.max(target.stunEnd, now() + Config.Block.GuardBreakStun)
	target.blockLockEnd = now() + Config.Block.GuardBreakStun + 0.3
	Combat.cancelMove(target)
	Net.fx("GuardBreak", { t = target.model, p = target.root.Position })
end

-- голый урон (без оглушения). Возвращает true, если цель умерла.
function Combat.damage(attacker, target, amount, silent)
	if not Fighters.alive(target) or amount <= 0 then return false end
	local hum = target.hum
	local t = now()
	hum.Health = math.max(0, hum.Health - amount)
	target.lastDamageTime = t
	if attacker and attacker ~= target then
		target.lastHitBy = attacker
		target.lastHitTime = t
		attacker.lastDealtTime = t
		Combat.addMeter(attacker, amount * Config.Awaken.PerDamageDealt)
	end
	Combat.addMeter(target, amount * Config.Awaken.PerDamageTaken)
	if not silent then
		Net.fx("Dmg", { t = target.model, d = amount, a = attacker and attacker.model })
	end
	if hum.Health <= 0 then
		Combat.die(target)
		return true
	end
	return false
end

-- основной удар по цели. info:
--   damage, stun, knockback (Vector3), kbTime, ragdoll, guardBreak, unblockable, parryable,
--   chip, blockCost, fx, heavy, pos, m1, trueDamage, cancel, noCombo, shake, hitstop
-- Возвращает: "hit" | "blocked" | "parried" | "evaded" | "immune" | "countered" | "killed" | nil
function Combat.hit(attacker, target, info)
	if not Fighters.alive(target) then return nil end
	if attacker == target then return nil end
	local t = now()
	if not info.trueDamage and t < target.iframesEnd then return "immune" end
	if info.m1 and t < target.evadeEnd then
		Net.fx("Evade", { t = target.model })
		return "evaded"
	end
	-- контрстойка цели
	if target.counter and attacker and not info.trueDamage then
		local c = target.counter
		target.counter = nil
		if c(attacker, info) then return "countered" end
	end
	local pos = info.pos or target.root.Position
	-- блок
	if target.blocking and attacker and not info.unblockable and not info.trueDamage then
		local toA = Util.flat(attacker.root.Position - target.root.Position, target.root.CFrame.LookVector)
		local front = target.root.CFrame.LookVector:Dot(toA) > Config.Block.FrontDot
		if front then
			if info.parryable ~= false and t - target.blockStart <= Config.Block.ParryWindow and not info.guardBreak then
				Combat.stun(attacker, Config.Block.ParryStun)
				Combat.cancelMove(attacker)
				Combat.knockback(attacker, Combat.away(target, attacker) * 18 + Vector3.new(0, 6, 0), 0.15)
				Net.fx("Parry", { t = target.model, a = attacker.model, p = pos })
				return "parried"
			end
			if info.guardBreak then
				Combat.guardBreak(target, attacker)
			else
				target.blockHp = target.blockHp - (info.blockCost or 1)
				local chip = info.chip
				if chip == nil then chip = info.m1 and 0 or Config.Block.ChipMult end
				if chip > 0 then Combat.damage(attacker, target, (info.damage or 0) * chip * Combat.damageMult(attacker), true) end
				Combat.knockback(target, Combat.away(attacker, target) * (info.heavy and 26 or 12), 0.1)
				Net.fx("Block", { t = target.model, p = pos, heavy = info.heavy })
				if target.blockHp <= 0 then Combat.guardBreak(target, attacker) end
				return "blocked"
			end
		end
	end
	-- урон
	local dmg = (info.damage or 0) * Combat.damageMult(attacker)
	if info.trueDamage then dmg = info.damage or 0 end
	target.blocking = false
	if info.stun and info.stun > 0 then Combat.stun(target, info.stun) end
	if info.cancel ~= false and t >= target.armorEnd then
		if target.moveId then Combat.cancelMove(target) end
	end
	local died = Combat.damage(attacker, target, dmg, true)
	if info.knockback and not (target.kind == "dummy" and info.knockback.Magnitude < 1) then
		Combat.knockback(target, info.knockback, info.kbTime)
	end
	if info.ragdoll and info.ragdoll > 0 then Ragdoll.start(target, info.ragdoll) end
	-- комбо атакующего
	if attacker and not info.noCombo then
		if t - attacker.comboLast > Config.ComboResetTime then attacker.combo = 0 end
		attacker.combo = attacker.combo + 1
		attacker.comboLast = t
		if attacker.player then Net.to(attacker.player, "Combo", { n = attacker.combo }) end
	end
	Net.fx("Hit", {
		t = target.model, a = attacker and attacker.model, p = pos, k = info.fx or "punch", d = math.floor(dmg * 10 + 0.5) / 10,
		heavy = info.heavy, s = info.shake, hs = info.hitstop, crit = info.crit,
	})
	if died then return "killed" end
	return "hit"
end

-- смерть: рэгдолл, засчитать убийство
function Combat.die(f)
	if f.dead then return end
	f.dead = true
	f.blocking = false
	f.counter = nil
	Combat.cancelMove(f)
	Ragdoll.start(f, 1e6)
	local t = now()
	local killer = f.lastHitBy
	if killer and (t - f.lastHitTime > 12 or killer == f) then killer = nil end
	Net.fx("Death", { m = f.model, p = f.root.Position })
	for _, fn in ipairs(Combat.onKill) do
		local ok, err = pcall(fn, killer, f)
		if not ok then warn("[Combat] onKill: " .. tostring(err)) end
	end
end

Fighters.onDied = function(f)
	if not f.dead then Combat.die(f) end
end

Fighters.onCombo = function(f)
	Net.to(f.player, "Combo", { n = 0 })
end

---------------------------------------------------------------- пробуждение
function Combat.canAwaken(f)
	return Fighters.alive(f) and not f.awakened and f.meter >= Config.Awaken.Max and Fighters.canAct(f) and f.kind ~= "dummy"
end

function Combat.awaken(f)
	if not Combat.canAwaken(f) then return false end
	local t = now()
	Combat.cancelMove(f)
	f.awakened = true
	f.ultUsed = false
	f.awakenStart = t
	f.awakenEnd = t + Config.Awaken.Invuln + Config.Awaken.Duration
	f.iframesEnd = math.max(f.iframesEnd, t + Config.Awaken.Invuln)
	Fighters.busy(f, Config.Awaken.Invuln, 0)
	f.cds = { 0, 0, 0, 0 }
	f.hum.Health = math.min(f.hum.MaxHealth, f.hum.Health + Config.Awaken.Heal)
	f.model:SetAttribute("Awakened", true)
	f.attrs.Awakened = true
	Combat.setMeter(f, Config.Awaken.Max)
	local def = Characters.get(f.charId)
	Net.fx("Awaken", { m = f.model, c = f.charId, name = def.Awakening.Name })
	Net.fx("Anim", { m = f.model, a = "awaken" })
	if f.player then Net.to(f.player, "Moveset", { awakened = true }) end
	return true
end

function Combat.endAwaken(f)
	if not f.awakened then return end
	f.awakened = false
	f.ultUsed = false
	f.cds = { 0, 0, 0, 0 }
	f.model:SetAttribute("Awakened", false)
	f.attrs.Awakened = false
	Combat.setMeter(f, 0)
	Net.fx("AwakenEnd", { m = f.model })
	if f.player then Net.to(f.player, "Moveset", { awakened = false }) end
end

-- таймеры (через Fighters.onExpire)
table.insert(Fighters.onExpire, function(f, t)
	Ragdoll.tick(f, t)
	if f.awakened then
		local total = Config.Awaken.Duration
		local left = f.awakenEnd - t
		if left <= 0 then
			Combat.endAwaken(f)
		else
			Combat.setMeter(f, Config.Awaken.Max * math.clamp(left / total, 0, 1))
		end
	end
	-- горение
	if t < f.burnEnd and f.burnTick and t >= f.burnTick then
		f.burnTick = t + 0.5
		Combat.damage(f.burnBy, f, f.burnDmg or 1)
	end
end)

-- поджечь: dmg раз в полсекунды, dur секунд
function Combat.burn(attacker, target, dps, dur)
	if not Fighters.alive(target) then return end
	local t = now()
	target.burnEnd = math.max(target.burnEnd, t + dur)
	target.burnTick = target.burnTick and math.min(target.burnTick, t + 0.5) or t + 0.5
	target.burnDmg = dps * 0.5
	target.burnBy = attacker
end

return Combat
