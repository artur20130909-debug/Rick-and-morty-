-- Громовержец: шаги молнии, цепная молния, громовой хлопок, рельсотрон; «Буря» и Небесный Суд.
local Characters = require(game:GetService("ReplicatedStorage").Shared.Characters)
local DEF = Characters.get("Thunderer")
local BLUE, YELLOW = DEF.Color, DEF.Accent

local M = {}

-- шаг молнии: почти мгновенный рывок, бьёт всех на пути
local function step(K, f, tok, dir, dist, dmg)
	local C = K.Combat
	local start = f.root.Position
	K.fx("Afterimage", { m = f.model, c = BLUE })
	K.dash(f, tok, dir, 230, dist / 230, { contact = 3.6, stop = false, onContact = function(t)
		C.hit(f, t, { damage = dmg, stun = 0.95, fx = "zap", knockback = dir * 8 + Vector3.new(0, 6, 0), kbTime = 0.08, hitstop = 0.05 })
	end })
	K.fx("Bolt", { a = start + Vector3.new(0, 0.5, 0), b = f.root.Position + Vector3.new(0, 0.5, 0), c = BLUE, c2 = YELLOW, w = 0.5 })
	K.sound("Zap", f.root.Position)
end

function M.FlashStep(K, f, aim, def)
	local tok = K.start(f, def.Id, 0.45, 0)
	K.anim(f, "rush")
	step(K, f, tok, K.dir(f, aim), 28, 7)
	K.stopAnim(f)
	K.wait(f, tok, 0.15)
	K.finish(f, tok)
end

function M.StormSteps(K, f, aim, def)
	local F = K.Fighters
	local tok = K.start(f, def.Id, 1.2, 0)
	K.anim(f, "rush")
	for i = 1, 3 do
		local t = K.target(f, aim, 40, 0)
		local dir = K.dir(f, aim)
		local dist = 24
		if t and F.alive(t) then
			local d = t.root.Position - f.root.Position
			dir = K.Util.flat(d, dir)
			dist = math.clamp(Vector3.new(d.X, 0, d.Z).Magnitude + 5, 8, 34)
		end
		step(K, f, tok, dir, dist, 6)
		if not K.wait(f, tok, 0.14) then return end
	end
	K.stopAnim(f)
	K.finish(f, tok)
end

-- цепная молния
function M.ChainLightning(K, f, aim, def)
	local C, F, H = K.Combat, K.Fighters, K.Hitbox
	local tok = K.start(f, def.Id, 0.6, 4)
	K.anim(f, "point")
	K.fx("Charge", { m = f.model, c = BLUE, t = 0.16, k = "zap", hand = "R" })
	if not K.wait(f, tok, 0.16) then return end
	local first = K.target(f, aim, 50, 0.4)
	local from = f.root.Position + K.dir(f, aim) * 2 + Vector3.new(0, 1, 0)
	if not first then
		K.fx("Bolt", { a = from, b = from + K.dir(f, aim) * 30, c = BLUE, c2 = YELLOW, w = 0.6 })
		K.sound("Zap", from)
		K.wait(f, tok, 0.2)
		K.finish(f, tok)
		return
	end
	local dmgs = { 10, 8, 6, 4 }
	local hit = { [f] = true }
	local cur = first
	local prev = from
	for i = 1, 4 do
		if not cur then break end
		hit[cur] = true
		K.fx("Bolt", { a = prev, b = cur.root.Position, c = BLUE, c2 = YELLOW, w = 0.7 })
		K.sound("Zap", cur.root.Position)
		C.hit(f, cur, { damage = dmgs[i], stun = 0.9, fx = "zap", knockback = Vector3.new(0, 8, 0), kbTime = 0.08, hitstop = 0.04 })
		prev = cur.root.Position
		local nxt = H.nearest(prev, 20, hit)
		cur = nxt
		task.wait(0.08)
		if not F.alive(f) then break end
	end
	K.wait(f, tok, 0.2)
	K.finish(f, tok)
end

-- хлопок: долгое оглушение вокруг
function M.ThunderClap(K, f, aim, def)
	local tok = K.start(f, def.Id, 0.8, 0)
	K.anim(f, "clap")
	if not K.wait(f, tok, 0.23) then return end
	local pos = f.root.Position
	K.fx("Shock", { p = pos, c = BLUE, c2 = YELLOW, r = 12, k = "zap" })
	K.sound("Thunder", pos)
	K.radiusHit(f, pos, 12, function(t)
		return { damage = 9, stun = 1.5, fx = "zap", knockback = K.knock(f, t, 22, 12), kbTime = 0.12, hitstop = 0.08, shake = 0.6 }
	end, {})
	K.wait(f, tok, 0.3)
	K.finish(f, tok)
end

-- рельсотрон
function M.Railgun(K, f, aim, def)
	local tok = K.start(f, def.Id, 1.5, 3)
	K.anim(f, "charge")
	K.fx("Charge", { m = f.model, c = BLUE, t = 0.6, k = "zap", big = true })
	K.sound("Charge", nil, f.model)
	if not K.wait(f, tok, 0.6) then return end
	K.anim(f, "point")
	local dir = K.dir(f, aim)
	local a = f.root.Position + dir * 2 + Vector3.new(0, 0.8, 0)
	local hitWall = K.Util.mapRay(a, dir * 140)
	local b = hitWall and hitWall.Position or (a + dir * 140)
	K.fx("Beam", { a = a, b = b, c = BLUE, c2 = YELLOW, w = 3.5, t = 0.45, k = "zap" })
	K.sound("Thunder", a)
	K.shake(a, 1, 70)
	K.segmentHit(f, a, b, 4.5, function(t)
		return { damage = 20, stun = 1.1, heavy = true, fx = "zap", knockback = dir * 72 + Vector3.new(0, 28, 0), ragdoll = 1.4, kbTime = 0.22,
			guardBreak = true, hitstop = 0.1, shake = 1 }
	end, {})
	K.breakAt(b, 6, 1.2)
	K.wait(f, tok, 0.4)
	K.finish(f, tok)
end

-- удар молнии с неба по всем вокруг
function M.Thunderbolt(K, f, aim, def)
	local C, H = K.Combat, K.Hitbox
	local tok = K.start(f, def.Id, 0.9, 0)
	K.anim(f, "rise")
	local targets = H.radius(f.root.Position, 35, { [f] = true })
	for _, t in ipairs(targets) do K.fx("Warn", { p = K.ground(t.root.Position), r = 5, c = YELLOW, t = 0.45 }) end
	if not K.wait(f, tok, 0.45) then return end
	for _, t in ipairs(targets) do
		local p = K.ground(t.root.Position)
		K.fx("Strike", { p = p, c = BLUE, c2 = YELLOW })
		K.sound("Thunder", p)
		C.hit(f, t, { damage = 14, stun = 1.1, heavy = true, fx = "zap", knockback = Vector3.new(0, 30, 0), ragdoll = 0.9, kbTime = 0.15, hitstop = 0.06 })
	end
	K.stopAnim(f)
	K.wait(f, tok, 0.3)
	K.finish(f, tok)
end

-- перегрузка: разряды вокруг
function M.Overload(K, f, aim, def)
	local tok = K.start(f, def.Id, 1.4, 0)
	K.armor(f, 1.2)
	K.anim(f, "awaken")
	for i = 1, 4 do
		if not K.wait(f, tok, 0.22) then return end
		local pos = f.root.Position
		K.fx("Shock", { p = pos, c = BLUE, c2 = YELLOW, r = 16, k = "zap" })
		K.sound("Zap", pos)
		K.radiusHit(f, pos, 16, function(t)
			if i == 4 then
				return { damage = 6, stun = 1, heavy = true, fx = "zap", knockback = K.knock(f, t, 70, 30), ragdoll = 1.2, kbTime = 0.2, hitstop = 0.08 }
			end
			return { damage = 4, stun = 0.7, fx = "zap", knockback = Vector3.new(0, 6, 0), kbTime = 0.06 }
		end, {})
	end
	K.wait(f, tok, 0.3)
	K.finish(f, tok)
end

-- ульта: гроза
function M.Judgment(K, f, aim, def)
	local C, F, H = K.Combat, K.Fighters, K.Hitbox
	local tok = K.start(f, def.Id, 4.2, 0)
	K.iframes(f, 4)
	K.armor(f, 4.2)
	K.fx("Ult", { m = f.model, text = def.Name, c = BLUE, c2 = YELLOW })
	K.anim(f, "rise")
	K.setVel(f, Vector3.new(0, 45, 0))
	if not K.wait(f, tok, 0.45) then K.stopVel(f) return end
	K.setVel(f, Vector3.new(0, 0, 0))
	K.fx("Storm", { p = f.root.Position, r = 60, t = 3.4 })
	for i = 1, 12 do
		local list = H.radius(f.root.Position, 60, { [f] = true })
		local t = list[math.random(1, math.max(1, #list))]
		local p
		if t then
			p = K.ground(t.root.Position + Vector3.new(math.random() * 4 - 2, 0, math.random() * 4 - 2))
		else
			p = K.ground(f.root.Position + Vector3.new(math.random(-40, 40), -20, math.random(-40, 40)))
		end
		K.fx("Warn", { p = p, r = 6, c = YELLOW, t = 0.22 })
		task.wait(0.12)
		K.fx("Strike", { p = p, c = BLUE, c2 = YELLOW })
		K.sound("Thunder", p)
		K.radiusHit(f, p, 6, { damage = 8, stun = 0.9, trueDamage = false, fx = "zap", knockback = Vector3.new(0, 24, 0), kbTime = 0.12, hitstop = 0.04 }, {})
		task.wait(0.13)
		if not K.valid(f, tok) then K.stopVel(f) return end
	end
	local point = K.aimPoint(f, aim, 70, 30)
	K.fx("Warn", { p = point, r = 12, c = YELLOW, t = 0.3 })
	task.wait(0.3)
	K.fx("Strike", { p = point, c = BLUE, c2 = YELLOW, big = true })
	K.fx("Explosion", { p = point, r = 12, c = BLUE, c2 = YELLOW, k = "zap" })
	K.sound("Thunder", point)
	K.shake(point, 2, 140)
	K.radiusHit(f, point, 12, function(t)
		return { damage = 20, stun = 1.4, guardBreak = true, heavy = true, fx = "zap", knockback = K.knock(f, t, 90, 50), ragdoll = 1.8, kbTime = 0.22, hitstop = 0.12, shake = 1.6 }
	end, {})
	K.breakAt(point, 12, 1.5)
	K.stopVel(f)
	K.wait(f, tok, 0.3)
	K.finish(f, tok)
	if F.alive(f) then f.root.AssemblyLinearVelocity = Vector3.zero end
end

return M
