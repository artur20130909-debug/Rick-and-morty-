-- Пламенный Демон: шары, огненный рывок, столб, метеор; «Инферно» и Солнечная Вспышка.
local Characters = require(game:GetService("ReplicatedStorage").Shared.Characters)
local DEF = Characters.get("FlameDemon")
local ORANGE, YELLOW = DEF.Color, DEF.Accent
local RED = Color3.fromRGB(230, 50, 20)

local M = {}

local function explode(K, f, pos, r, dmg, burn)
	local C = K.Combat
	K.fx("Explosion", { p = pos, r = r, c = ORANGE, c2 = YELLOW, k = "fire" })
	K.sound("Explosion", pos)
	K.radiusHit(f, pos, r, function(t)
		local d = t.root.Position - pos
		local away = Vector3.new(d.X, 0, d.Z)
		away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 0)
		return { damage = dmg, stun = 0.9, heavy = dmg >= 12, fx = "fire", knockback = away * 45 + Vector3.new(0, 30, 0), ragdoll = dmg >= 12 and 1.1 or nil,
			kbTime = 0.18, hitstop = 0.05 }
	end, {})
	if burn then
		for _, t in ipairs(K.Hitbox.radius(pos, r, { [f] = true })) do C.burn(f, t, 2, burn) end
	end
	K.breakAt(pos, r * 0.7, 1)
end

local function fireball(K, f, from, dir, p)
	K.projectile(f, {
		from = from, dir = dir, speed = p.speed or 82, range = p.range or 80, radius = p.radius or 2, kind = "fireball", color = ORANGE, size = p.size or 2.2,
		onHit = function() return false end,
		onEnd = function(pos) explode(K, f, pos, p.blast or 9, p.dmg or 12, p.burn or 3) end,
	})
end

function M.Fireball(K, f, aim, def)
	local dir = K.dir(f, aim)
	local tok = K.start(f, def.Id, 0.55, 6)
	K.anim(f, "throw")
	K.fx("Charge", { m = f.model, c = ORANGE, t = 0.2, k = "fire", hand = "R" })
	if not K.wait(f, tok, 0.2) then return end
	K.sound("Fire", f.root.Position)
	fireball(K, f, f.root.Position + dir * 2.5 + Vector3.new(0, 0.8, 0), dir, {})
	K.wait(f, tok, 0.25)
	K.finish(f, tok)
end

function M.FireBarrage(K, f, aim, def)
	local tok = K.start(f, def.Id, 1.1, 5)
	for i = 1, 5 do
		K.anim(f, i % 2 == 1 and "jab_r" or "jab_l")
		local dir = K.dir(f, aim)
		local spread = (i - 3) * 4
		local d = CFrame.Angles(0, math.rad(spread), 0):VectorToWorldSpace(dir)
		K.sound("Fire", f.root.Position)
		fireball(K, f, f.root.Position + d * 2.5 + Vector3.new(0, 0.8, 0), d, { dmg = 8, blast = 6, burn = 2, size = 1.6, speed = 95 })
		if not K.wait(f, tok, 0.16) then return end
	end
	K.finish(f, tok)
end

-- огненный рывок: за ним горит дорожка
function M.FlameDash(K, f, aim, def)
	local C, H = K.Combat, K.Hitbox
	local dir = K.dir(f, aim)
	local tok = K.start(f, def.Id, 0.9, 0)
	K.anim(f, "rush")
	K.fx("Trail", { m = f.model, c = ORANGE, t = 0.45, k = "fire" })
	K.sound("Fire", f.root.Position)
	local a = f.root.Position
	K.dash(f, tok, dir, 100, 0.32, { contact = 3.6, stop = false, onContact = function(t)
		C.hit(f, t, { damage = 8, stun = 0.8, fx = "fire", knockback = K.knock(f, t, 40, 22), kbTime = 0.15, hitstop = 0.05 })
		C.burn(f, t, 2, 2.5)
	end })
	local b = f.root.Position
	local ga, gb = K.ground(a), K.ground(b)
	K.fx("FireTrail", { a = ga, b = gb, c = ORANGE, t = 2.2 })
	K.stopAnim(f)
	K.finish(f, tok)
	-- дорожка жжёт 2 секунды
	task.spawn(function()
		for _ = 1, 7 do
			task.wait(0.3)
			for _, t in ipairs(H.segment(ga + Vector3.new(0, 2.5, 0), gb + Vector3.new(0, 2.5, 0), 4, { [f] = true })) do
				C.burn(f, t, 2, 1.5)
			end
		end
	end)
end

-- столб пламени под врагом
function M.FlamePillar(K, f, aim, def)
	local C = K.Combat
	local tok = K.start(f, def.Id, 0.6, 4)
	K.anim(f, "point")
	local point = K.aimPoint(f, aim, 55, 25)
	K.fx("Warn", { p = point, r = 6, c = ORANGE, t = 0.6 })
	if not K.wait(f, tok, 0.3) then return end
	K.finish(f, tok)
	K.after(0.3, function()
		K.fx("Pillar", { p = point, r = 6, h = 40, c = ORANGE, c2 = YELLOW, t = 0.9, k = "fire" })
		K.sound("Fire", point)
		K.radiusHit(f, point, 6.5, function(t)
			C.burn(f, t, 2, 3)
			return { damage = 15, stun = 1.2, heavy = true, fx = "fire", knockback = Vector3.new(0, 75, 0), ragdoll = 1.3, kbTime = 0.22, hitstop = 0.08, shake = 0.8 }
		end, {})
	end)
end

-- метеор с неба
function M.Meteor(K, f, aim, def)
	local tok = K.start(f, def.Id, 0.8, 3)
	K.anim(f, "rise")
	local point = K.aimPoint(f, aim, 60, 30)
	K.fx("Meteor", { p = point, t = 1.2, r = 16, c = ORANGE, c2 = RED })
	K.fx("Warn", { p = point, r = 16, c = RED, t = 1.2 })
	if not K.wait(f, tok, 0.5) then return end
	K.stopAnim(f)
	K.finish(f, tok)
	K.after(0.7, function()
		K.fx("Crater", { p = point, r = 13, c = ORANGE })
		K.shake(point, 1.6, 120)
		explode(K, f, point, 16, 22, 3)
	end)
end

-- кольцо огня вокруг себя
function M.FireRing(K, f, aim, def)
	local C, H = K.Combat, K.Hitbox
	local tok = K.start(f, def.Id, 0.9, 0)
	K.anim(f, "stomp")
	if not K.wait(f, tok, 0.24) then return end
	local center = K.ground(f.root.Position)
	K.fx("FireRing", { p = center, r = 22, c = ORANGE, c2 = YELLOW, t = 0.55 })
	K.sound("Explosion", center)
	local hitSet = {}
	for step = 1, 5 do
		local r = 22 * step / 5
		for _, t in ipairs(H.radius(center + Vector3.new(0, 3, 0), r, { [f] = true })) do
			if not hitSet[t] then
				hitSet[t] = true
				C.hit(f, t, { damage = 14, stun = 1, heavy = true, fx = "fire", knockback = C.away(f, t) * 70 + Vector3.new(0, 30, 0), ragdoll = 1.2, kbTime = 0.2, hitstop = 0.06 })
				C.burn(f, t, 2, 3)
			end
		end
		task.wait(0.08)
	end
	K.breakAt(center, 16, 1)
	K.wait(f, tok, 0.25)
	K.finish(f, tok)
end

-- феникс: полёт сквозь врагов
function M.Phoenix(K, f, aim, def)
	local C = K.Combat
	local dir = K.dir(f, aim)
	local tok = K.start(f, def.Id, 1.0, 0)
	K.iframes(f, 0.5)
	K.anim(f, "fly")
	K.fx("Phoenix", { m = f.model, c = ORANGE, c2 = YELLOW, t = 0.5 })
	K.sound("Fire", f.root.Position)
	local start = f.root.Position
	K.dash(f, tok, dir, 105, 0.42, { contact = 4.5, stop = false, onContact = function(t)
		C.hit(f, t, { damage = 16, stun = 1, heavy = true, fx = "fire", knockback = dir * 60 + Vector3.new(0, 40, 0), ragdoll = 1.4, kbTime = 0.22, hitstop = 0.08, shake = 0.8 })
		C.burn(f, t, 2, 3)
	end })
	K.fx("FireTrail", { a = K.ground(start), b = K.ground(f.root.Position), c = ORANGE, t = 1.2 })
	K.stopAnim(f)
	K.wait(f, tok, 0.15)
	K.finish(f, tok)
end

-- ульта: маленькое солнце
function M.SolarFlare(K, f, aim, def)
	local F = K.Fighters
	local tok = K.start(f, def.Id, 3.2, 0)
	K.iframes(f, 3)
	K.armor(f, 3.2)
	K.fx("Ult", { m = f.model, text = def.Name, c = ORANGE, c2 = YELLOW })
	K.anim(f, "rise")
	K.setVel(f, Vector3.new(0, 55, 0))
	if not K.wait(f, tok, 0.45) then K.stopVel(f) return end
	K.setVel(f, Vector3.new(0, 0, 0))
	local point = K.aimPoint(f, aim, 60, 30)
	K.fx("Sun", { m = f.model, t = 1.6, r = 9, c = ORANGE, c2 = YELLOW })
	K.fx("Warn", { p = point, r = 32, c = RED, t = 1.9 })
	if not K.wait(f, tok, 1.6) then K.stopVel(f) return end
	K.anim(f, "throw")
	K.fx("SunFall", { a = f.root.Position + Vector3.new(0, 6, 0), b = point, t = 0.35, c = ORANGE, c2 = YELLOW })
	if not K.wait(f, tok, 0.35) then K.stopVel(f) return end
	K.stopVel(f)
	K.radiusHit(f, point, 32, function(t)
		local dist = (t.root.Position - point).Magnitude
		local k = 1 - math.clamp(dist / 32, 0, 1) * 0.55
		K.Combat.burn(f, t, 3, 4)
		return { damage = 32 * k, stun = 1.5, guardBreak = true, heavy = true, fx = "fire", knockback = K.knock(f, t, 115 * k, 65), ragdoll = 2, kbTime = 0.25,
			shake = 2, hitstop = 0.15 }
	end, {})
	K.fx("Explosion", { p = point, r = 32, c = ORANGE, c2 = YELLOW, k = "fire", big = true })
	K.fx("Crater", { p = point, r = 22, c = ORANGE })
	K.breakAt(point, 32, 2)
	K.shake(point, 2.8, 200)
	K.wait(f, tok, 0.5)
	K.finish(f, tok)
	if F.alive(f) then f.root.AssemblyLinearVelocity = Vector3.zero end
end

return M
