-- Кулак Бури: рывки, серии, отложенный удар, захват; пробуждение «Ярость Бури».
local Characters = require(game:GetService("ReplicatedStorage").Shared.Characters)
local DEF = Characters.get("StormFist")
local RED, GOLD = DEF.Color, DEF.Accent

local M = {}

-- рывок с серией и Резонансом (нажать клавишу ещё раз во время вспышки)
local function rush(K, f, aim, def, slot, p)
	local C, F = K.Combat, K.Fighters
	local dir = K.dir(f, aim)
	local tok = K.start(f, def.Id, 1.5, 0)
	K.anim(f, "rush")
	K.fx("Trail", { m = f.model, c = p.lightning and GOLD or RED, t = p.time + 0.1, k = p.lightning and "zap" or "wind" })
	K.sound("Dash", nil, f.model)
	local target = K.dash(f, tok, dir, p.speed, p.time, { contact = 3.4 })
	if not target then
		K.stopAnim(f)
		K.finish(f, tok)
		return
	end
	K.faceTarget(f, target)
	for i = 1, p.hits do
		if not F.alive(target) then break end
		K.anim(f, i % 2 == 1 and "jab_l" or "jab_r")
		C.hit(f, target, { damage = p.jab, stun = 0.85, fx = p.lightning and "zap" or "punch", knockback = K.knock(f, target, 4, 0), kbTime = 0.06, hitstop = 0.03 })
		if not K.wait(f, tok, 0.14) then return end
	end
	if not F.alive(target) then
		K.finish(f, tok)
		return
	end
	-- добивающий с окном Резонанса
	K.anim(f, "punch_heavy")
	local crit = false
	local now = K.now()
	K.recast(f, slot, now + 0.1, now + 0.34, function() crit = true end)
	K.fx("Cue", { m = f.model, t = 0.34, d = 0.1, c = GOLD })
	if not K.wait(f, tok, 0.3) then
		f.recast = nil
		return
	end
	f.recast = nil
	local res = C.hit(f, target, {
		damage = crit and p.crit or p.fin, stun = 1.1, heavy = true, fx = crit and "crit" or "heavy", crit = crit,
		knockback = K.knock(f, target, crit and 100 or 72, 28), ragdoll = 1.35, kbTime = 0.22,
		shake = crit and 1.5 or 0.8, hitstop = crit and 0.14 or 0.07,
	})
	if crit and (res == "hit" or res == "killed") then
		K.fx("Resonance", { m = target.model, p = target.root.Position, c = RED, c2 = GOLD })
		K.shake(target.root.Position, 1.6, 90)
		K.breakAt(target.root.Position, 6, 1)
	end
	K.wait(f, tok, 0.25)
	K.finish(f, tok)
end

function M.FistRush(K, f, aim, def, slot)
	rush(K, f, aim, def, slot, { speed = 95, time = 0.36, hits = 2, jab = 4, fin = 7, crit = 16 })
end

function M.ThunderRush(K, f, aim, def, slot)
	rush(K, f, aim, def, slot, { speed = 120, time = 0.42, hits = 3, jab = 4, fin = 8, crit = 18, lightning = true })
end

-- круговой пинок
local function whirl(K, f, aim, def, slot, p)
	local C = K.Combat
	local tok = K.start(f, def.Id, 0.55 + 0.2 * p.hits, 3)
	K.anim(f, p.hits > 2 and "spin_loop" or "spin_kick")
	K.sound("SwingHeavy", nil, f.model)
	if not K.wait(f, tok, 0.1) then return end
	local center = f.root.Position
	if p.pull then
		-- затянуть врагов в центр
		K.fx("Vortex", { p = K.ground(center), c = GOLD, r = p.radius + 6, t = 0.5, k = "wind" })
		for _, t in ipairs(K.Hitbox.radius(center, p.radius + 6, { [f] = true })) do
			local d = center - t.root.Position
			C.knockback(t, Vector3.new(d.X, 0, d.Z) * 4, 0.18)
			C.stun(t, 0.6)
		end
	end
	for i = 1, p.hits do
		center = f.root.Position
		K.fx("Ring", { p = K.ground(center), c = i == p.hits and RED or GOLD, r = p.radius, t = 0.3 })
		local last = i == p.hits
		K.radiusHit(f, center, p.radius, function(t)
			if last then
				return { damage = p.fin, stun = 1, heavy = true, fx = "heavy", knockback = K.knock(f, t, 48, 52), ragdoll = 1.2, kbTime = 0.2, hitstop = 0.06, shake = 0.7 }
			end
			return { damage = p.dmg, stun = 0.75, fx = "punch", knockback = Vector3.new(0, 6, 0), kbTime = 0.08 }
		end, {})
		if not last and not K.wait(f, tok, 0.18) then return end
	end
	K.fx("Burst", { p = f.root.Position, c = RED, r = p.radius * 0.8, k = "wind" })
	K.wait(f, tok, 0.25)
	K.finish(f, tok)
end

function M.WhirlKick(K, f, aim, def, slot)
	whirl(K, f, aim, def, slot, { radius = 9, hits = 2, dmg = 5, fin = 6 })
end

function M.Hurricane(K, f, aim, def, slot)
	whirl(K, f, aim, def, slot, { radius = 14, hits = 3, dmg = 4, fin = 8, pull = true })
end

-- удар с отложенной волной (вторая волна пробивает блок)
function M.DelayedImpact(K, f, aim, def, slot)
	local C, F = K.Combat, K.Fighters
	local dir = K.dir(f, aim)
	local tok = K.start(f, def.Id, 0.8, 2)
	K.anim(f, "punch_heavy")
	if not K.wait(f, tok, 0.27) then return end
	local res = K.boxFront(f, dir, 6, 6, 8, { damage = 6, stun = 1.15, heavy = true, fx = "heavy", knockback = dir * 4, kbTime = 0.08, hitstop = 0.06 }, {})
	K.fx("Burst", { p = f.root.Position + dir * 4.5, c = RED, r = 4, k = "punch" })
	local victims = {}
	for _, e in ipairs(res) do
		if e.r == "hit" or e.r == "blocked" then victims[#victims + 1] = e.f end
	end
	for _, v in ipairs(victims) do K.fx("Mark", { m = v.model, c = RED, t = 0.45 }) end
	if #victims > 0 then
		K.after(0.45, function()
			for _, v in ipairs(victims) do
				if F.alive(v) and F.alive(f) then
					K.fx("Shock", { p = v.root.Position, c = RED, c2 = GOLD, r = 8 })
					C.hit(f, v, { damage = 9, stun = 0.9, unblockable = true, heavy = true, fx = "crit2", knockback = K.knock(f, v, 70, 30),
						ragdoll = 1.4, kbTime = 0.2, shake = 1, hitstop = 0.08 })
				end
			end
		end)
	end
	K.wait(f, tok, 0.3)
	K.finish(f, tok)
end

-- захват в прыжке и бросок о землю
function M.Crusher(K, f, aim, def, slot)
	local C, F = K.Combat, K.Fighters
	local dir = K.dir(f, aim)
	local tok = K.start(f, def.Id, 1.0, 0)
	K.anim(f, "grab")
	local target = K.dash(f, tok, dir, 72, 0.3, { contact = 3.2, up = 16 })
	if not target then
		K.stopAnim(f)
		K.finish(f, tok)
		return
	end
	local r = C.hit(f, target, { damage = 3, stun = 2.2, unblockable = true, fx = "punch", hitstop = 0.05 })
	if r ~= "hit" then
		K.finish(f, tok)
		return
	end
	K.busy(f, 1.4, 0)
	K.iframes(f, 1.1)
	K.anim(f, "slam")
	K.hold(f, target, CFrame.new(0, 4.6, -1.2), 0.42, tok)
	if not K.valid(f, tok) or not F.alive(target) then
		K.finish(f, tok)
		return
	end
	local spot = K.ground(f.root.Position + dir * 4)
	target.root.CFrame = CFrame.new(spot + Vector3.new(0, 2.5, 0))
	C.hit(f, target, { damage = 16, stun = 1.2, unblockable = true, heavy = true, fx = "heavy", knockback = Vector3.new(0, 34, 0) + dir * 22,
		ragdoll = 1.7, kbTime = 0.15, shake = 1.3, hitstop = 0.11 })
	K.fx("Crater", { p = spot, r = 9, c = RED })
	K.breakAt(spot, 9, 1)
	K.shake(spot, 1.2, 70)
	K.wait(f, tok, 0.35)
	K.finish(f, tok)
end

-- град ударов
function M.ThousandFists(K, f, aim, def, slot)
	local dir = K.dir(f, aim)
	local tok = K.start(f, def.Id, 1.9, 2)
	K.armor(f, 1.5)
	K.anim(f, "barrage")
	for i = 1, 14 do
		if not K.wait(f, tok, 0.085) then return end
		K.boxFront(f, dir, 6, 6, 7, { damage = 1.4, stun = 0.55, fx = "punch", knockback = dir * 3, kbTime = 0.05, noCombo = i % 2 == 0 }, {})
		if i % 3 == 0 then K.fx("Burst", { p = f.root.Position + dir * 4 + Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, 0), c = GOLD, r = 2.5, k = "punch" }) end
	end
	K.anim(f, "punch_heavy")
	if not K.wait(f, tok, 0.27) then return end
	K.boxFront(f, dir, 7, 6, 8, function(t)
		return { damage = 8, stun = 1, heavy = true, fx = "heavy", knockback = K.knock(f, t, 88, 30), ragdoll = 1.3, kbTime = 0.22, shake = 1, hitstop = 0.09 }
	end, {})
	K.fx("Burst", { p = f.root.Position + dir * 5, c = RED, r = 6, k = "punch" })
	K.wait(f, tok, 0.3)
	K.finish(f, tok)
end

-- ульта: прыжок в небо и удар о землю
function M.HeavenStrike(K, f, aim, def, slot)
	local F = K.Fighters
	local tok = K.start(f, def.Id, 3.0, 0)
	K.iframes(f, 2.4)
	K.armor(f, 3)
	K.fx("Ult", { m = f.model, text = def.Name, c = RED, c2 = GOLD })
	K.anim(f, "crouch_leap")
	if not K.wait(f, tok, 0.22) then return end
	K.setVel(f, Vector3.new(0, 125, 0))
	K.fx("Trail", { m = f.model, c = RED, t = 0.6, k = "zap" })
	if not K.wait(f, tok, 0.42) then K.stopVel(f) return end
	K.setVel(f, Vector3.new(0, 0, 0))
	K.anim(f, "hover")
	local point = K.aimPoint(f, aim, 70, 30)
	K.fx("Warn", { p = point, r = 24, c = RED, t = 0.75 })
	if not K.wait(f, tok, 0.45) then K.stopVel(f) return end
	K.anim(f, "dive")
	local t0 = os.clock()
	while os.clock() - t0 < 0.9 do
		local d = point + Vector3.new(0, 3, 0) - f.root.Position
		if d.Magnitude < 6 then break end
		K.setVel(f, d.Unit * 230)
		task.wait()
		if not F.alive(f) then return end
	end
	K.stopVel(f)
	K.teleport(f, point + Vector3.new(0, 3, 0), K.dir(f, aim))
	K.anim(f, "land")
	K.radiusHit(f, point, 24, function(t)
		local dist = (t.root.Position - point).Magnitude
		local k = 1 - math.clamp(dist / 24, 0, 1) * 0.55
		return { damage = 30 * k, stun = 1.5, guardBreak = true, heavy = true, fx = "heavy", knockback = K.knock(f, t, 110 * k, 62),
			ragdoll = 2, kbTime = 0.25, shake = 2, hitstop = 0.15 }
	end, {})
	K.fx("Explosion", { p = point, r = 24, c = RED, c2 = GOLD })
	K.fx("Crater", { p = point, r = 18, c = RED })
	K.breakAt(point, 24, 2)
	K.shake(point, 2.6, 180)
	K.wait(f, tok, 0.6)
	K.finish(f, tok)
end

return M
