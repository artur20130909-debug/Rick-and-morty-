-- Повелитель Пустоты: притяжение, отторжение, скачок, луч; пробуждение «Безмерность» и территория.
local Characters = require(game:GetService("ReplicatedStorage").Shared.Characters)
local DEF = Characters.get("VoidLord")
local CYAN, VIOLET = DEF.Color, DEF.Accent

local M = {}

-- водоворот пустоты в точке: тянет и бьёт
local function vortex(K, f, pos, p)
	local C, F, H = K.Combat, K.Fighters, K.Hitbox
	K.fx("Vortex", { p = pos, c = CYAN, c2 = VIOLET, r = p.radius, t = p.dur, k = "void" })
	K.sound("Void", pos)
	local t0 = os.clock()
	local nextDmg = 0
	while os.clock() - t0 < p.dur do
		task.wait(0.1)
		if not F.alive(f) then break end
		local el = os.clock() - t0
		for _, t in ipairs(H.radius(pos, p.radius * 1.35, { [f] = true })) do
			local d = pos - t.root.Position
			local flat = Vector3.new(d.X, d.Y * 0.4, d.Z)
			if flat.Magnitude > 1.2 then
				C.knockback(t, flat.Unit * math.min(p.pull, flat.Magnitude * 7), 0.12)
			end
			C.stun(t, 0.35)
		end
		if el >= nextDmg then
			nextDmg = el + 0.25
			K.radiusHit(f, pos, p.radius, { damage = p.tick, stun = 0.35, fx = "void", noCombo = false, knockback = Vector3.zero, kbTime = 0.01 }, {})
		end
	end
	K.fx("Burst", { p = pos, c = VIOLET, r = p.radius * 0.8, k = "void" })
	K.radiusHit(f, pos, p.radius * 0.8, function(t)
		return { damage = p.pop, stun = 0.7, heavy = true, fx = "void", knockback = Vector3.new(0, 34, 0) + (t.root.Position - pos) * 2, ragdoll = 0.9, kbTime = 0.15 }
	end, {})
end

local function attract(K, f, aim, def, p)
	local dir = K.dir(f, aim)
	local tok = K.start(f, def.Id, 0.55, 6)
	K.anim(f, "cast_palm")
	K.fx("Charge", { m = f.model, c = CYAN, t = 0.18, k = "void" })
	if not K.wait(f, tok, 0.18) then return end
	K.finish(f, tok)
	local origin = f.root.Position + dir * 3 + Vector3.new(0, 0.5, 0)
	K.projectile(f, {
		from = origin, dir = dir, speed = p.speed, range = p.range, radius = 2.4, kind = "voidorb", color = CYAN, size = p.size,
		onHit = function() return false end,
		onEnd = function(pos) vortex(K, f, pos, p) end,
	})
end

function M.Attract(K, f, aim, def)
	attract(K, f, aim, def, { speed = 58, range = 45, radius = 12, dur = 1.4, pull = 42, tick = 1.6, pop = 5, size = 2 })
end

function M.GravityWell(K, f, aim, def)
	attract(K, f, aim, def, { speed = 50, range = 50, radius = 20, dur = 2.8, pull = 55, tick = 1.8, pop = 8, size = 3.2 })
end

-- отторжение: конус перед собой
function M.Repel(K, f, aim, def)
	local dir = K.dir(f, aim)
	local tok = K.start(f, def.Id, 0.8, 2)
	K.anim(f, "cast_both")
	K.fx("Charge", { m = f.model, c = VIOLET, t = 0.3, k = "void" })
	if not K.wait(f, tok, 0.3) then return end
	K.boxFront(f, dir, 12, 9, 16, function(t)
		return { damage = 10, stun = 1, heavy = true, fx = "void", knockback = K.knock(f, t, 108, 36), ragdoll = 1.6, kbTime = 0.25, shake = 1.2, hitstop = 0.08 }
	end, {})
	K.fx("Cone", { p = f.root.Position + dir * 2, d = dir, c = VIOLET, c2 = CYAN, len = 16, w = 12 })
	K.sound("Void", f.root.Position)
	K.breakAt(f.root.Position + dir * 9, 8, 1)
	K.shake(f.root.Position, 0.9, 60)
	K.wait(f, tok, 0.35)
	K.finish(f, tok)
end

-- сверхновая: взрыв во все стороны
function M.Supernova(K, f, aim, def)
	local tok = K.start(f, def.Id, 1.0, 0)
	K.armor(f, 0.7)
	K.anim(f, "awaken")
	K.fx("Charge", { m = f.model, c = VIOLET, t = 0.45, k = "void" })
	if not K.wait(f, tok, 0.45) then return end
	local pos = f.root.Position
	K.radiusHit(f, pos, 18, function(t)
		return { damage = 14, stun = 1.1, heavy = true, fx = "void", knockback = K.knock(f, t, 112, 40), ragdoll = 1.6, kbTime = 0.25, shake = 1.4, hitstop = 0.1 }
	end, {})
	K.fx("Explosion", { p = pos, r = 18, c = VIOLET, c2 = CYAN, k = "void" })
	K.breakAt(pos, 18, 1.5)
	K.shake(pos, 1.6, 90)
	K.wait(f, tok, 0.4)
	K.finish(f, tok)
end

-- скачок за спину
local function blinkTo(K, f, target, aim)
	local from = f.root.Position
	K.fx("Afterimage", { m = f.model, c = CYAN })
	K.sound("Teleport", from)
	if target then
		local behind = target.root.Position - target.root.CFrame.LookVector * 3.6
		behind = K.safePoint(target.root.Position, behind)
		K.teleport(f, behind, target.root.Position - behind)
		K.fx("Blink", { a = from, b = behind, c = CYAN })
		return true
	end
	local dest = K.safePoint(from, from + K.dir(f, aim) * 25)
	K.teleport(f, dest, K.dir(f, aim))
	K.fx("Blink", { a = from, b = dest, c = CYAN })
	return false
end

function M.Blink(K, f, aim, def)
	local C = K.Combat
	local tok = K.start(f, def.Id, 0.65, 0)
	local t = K.target(f, aim, 45, 0.3)
	if blinkTo(K, f, t, aim) then
		K.anim(f, "kick_front")
		if not K.wait(f, tok, 0.13) then return end
		C.hit(f, t, { damage = 7, stun = 1, fx = "void", knockback = K.knock(f, t, 40, 32), ragdoll = 0.9, kbTime = 0.15, hitstop = 0.06 })
	end
	K.wait(f, tok, 0.25)
	K.finish(f, tok)
end

function M.Distortion(K, f, aim, def)
	local C, F = K.Combat, K.Fighters
	local tok = K.start(f, def.Id, 1.6, 0)
	local t = K.target(f, aim, 50, 0.2)
	for i = 1, 3 do
		if t and not F.alive(t) then t = nil end
		if not blinkTo(K, f, t, aim) then break end
		K.anim(f, i == 3 and "kick_front" or (i % 2 == 1 and "m1_p1" or "m1_p2"))
		if not K.wait(f, tok, 0.12) then return end
		if i < 3 then
			C.hit(f, t, { damage = 5, stun = 1, fx = "void", knockback = Vector3.new(0, 14, 0), kbTime = 0.1, hitstop = 0.05 })
		else
			C.hit(f, t, { damage = 7, stun = 1, heavy = true, fx = "void", knockback = K.knock(f, t, 60, 55), ragdoll = 1.3, kbTime = 0.2, hitstop = 0.09, shake = 0.8 })
		end
		if not K.wait(f, tok, 0.16) then return end
	end
	K.finish(f, tok)
end

-- луч пустоты
function M.VoidBeam(K, f, aim, def)
	local tok = K.start(f, def.Id, 1.9, 2)
	K.anim(f, "charge")
	K.fx("Charge", { m = f.model, c = VIOLET, t = 0.8, k = "void", big = true })
	K.sound("Charge", nil, f.model)
	if not K.wait(f, tok, 0.8) then return end
	K.anim(f, "beam")
	local dir = K.dir(f, aim)
	local a = f.root.Position + dir * 2 + Vector3.new(0, 0.6, 0)
	local b = a + dir * 120
	K.fx("Beam", { a = a, b = b, c = VIOLET, c2 = CYAN, w = 6, t = 0.7, k = "void" })
	K.sound("Beam", a)
	K.shake(a, 1.2, 90)
	K.segmentHit(f, a, b, 7, function(t)
		return { damage = 22, stun = 1.2, heavy = true, fx = "void", knockback = dir * 78 + Vector3.new(0, 30, 0), ragdoll = 1.5, kbTime = 0.22,
			guardBreak = true, shake = 1.2, hitstop = 0.1 }
	end, {})
	for i = 1, 6 do K.breakAt(a + dir * (i * 20), 7, 1.5) end
	K.wait(f, tok, 0.6)
	K.finish(f, tok)
end

-- территория: Горизонт Событий
function M.EventHorizon(K, f, aim, def)
	local C = K.Combat
	local tok = K.start(f, def.Id, 1.7, 0)
	K.iframes(f, 1.6)
	K.anim(f, "sign")
	K.fx("Ult", { m = f.model, text = def.Name, c = VIOLET, c2 = CYAN, domain = true })
	if not K.wait(f, tok, 1.15) then return end
	K.Domains.open(f, {
		style = "void", name = def.Name, radius = 42, duration = 9, tick = 0.5, slow = 0.35,
		onTick = function(d, victims)
			for _, v in ipairs(victims) do
				C.hit(f, v, { damage = 3, stun = 0.4, trueDamage = true, fx = "void", knockback = Vector3.zero, kbTime = 0.01 })
			end
		end,
	})
	K.wait(f, tok, 0.4)
	K.finish(f, tok)
end

return M
