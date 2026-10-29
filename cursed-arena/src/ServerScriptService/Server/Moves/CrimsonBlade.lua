-- Алый Клинок: летящие разрезы, контрстойка, пролёт сквозь врагов, подброс; «Кровавая Луна» и Сад Клинков.
local Characters = require(game:GetService("ReplicatedStorage").Shared.Characters)
local DEF = Characters.get("CrimsonBlade")
local CRIMSON, WHITE = DEF.Color, DEF.Accent

local M = {}

-- веер летящих разрезов
local function cuts(K, f, aim, def, p)
	local dir = K.dir(f, aim)
	local tok = K.start(f, def.Id, 0.5 + 0.08 * p.count, 6)
	K.anim(f, "m1_s2")
	if not K.wait(f, tok, 0.13) then return end
	K.sound("Slash", f.root.Position)
	for i = 1, p.count do
		local ang = 0
		if p.count > 1 then ang = -p.spread / 2 + p.spread * (i - 1) / (p.count - 1) end
		local d = CFrame.Angles(0, math.rad(ang), 0):VectorToWorldSpace(dir)
		K.projectile(f, {
			from = f.root.Position + d * 2.5 + Vector3.new(0, 0.3, 0), dir = d, speed = 125, range = p.range, radius = 3, pierce = 3,
			kind = "slash", color = CRIMSON, size = p.size,
			info = function(t)
				return { damage = p.dmg, stun = 0.85, fx = "slash", knockback = d * 30 + Vector3.new(0, 10, 0), kbTime = 0.12, hitstop = 0.04 }
			end,
		})
	end
	K.wait(f, tok, 0.25)
	K.finish(f, tok)
end

function M.WindCut(K, f, aim, def)
	cuts(K, f, aim, def, { count = 1, spread = 0, dmg = 11, range = 85, size = 6 })
end

function M.BladeFan(K, f, aim, def)
	cuts(K, f, aim, def, { count = 5, spread = 52, dmg = 9, range = 75, size = 5 })
end

-- контрстойка
function M.Counter(K, f, aim, def)
	local C = K.Combat
	local tok = K.start(f, def.Id, 1.05, 0)
	K.anim(f, "counter_stance")
	K.fx("Glint", { m = f.model, c = WHITE })
	local triggered = false
	f.counter = function(attacker, info)
		if not K.valid(f, tok) then return false end
		triggered = true
		task.spawn(function()
			K.busy(f, 0.8, 0)
			K.iframes(f, 0.6)
			K.fx("Text", { p = f.root.Position + Vector3.new(0, 4, 0), text = "КОНТРАТАКА!", c = CRIMSON })
			local from = f.root.Position
			local behind = attacker.root.Position - attacker.root.CFrame.LookVector * 3.6
			behind = K.safePoint(attacker.root.Position, behind)
			K.teleport(f, behind, attacker.root.Position - behind)
			K.fx("Blink", { a = from, b = behind, c = CRIMSON })
			K.anim(f, "slash_through")
			K.fx("SlashArc", { cf = f.root.CFrame, c = CRIMSON, r = 7, w = 1.4 })
			C.hit(f, attacker, { damage = 15, stun = 1.2, unblockable = true, heavy = true, fx = "slashHeavy", knockback = K.knock(f, attacker, 62, 34),
				ragdoll = 1.4, kbTime = 0.2, hitstop = 0.12, shake = 1 })
			task.wait(0.45)
			K.finish(f, tok)
		end)
		return true
	end
	if not K.wait(f, tok, 0.95) then
		f.counter = nil
		return
	end
	if not triggered then
		f.counter = nil
		K.stopAnim(f)
		K.finish(f, tok)
	end
end

-- пролёт сквозь врагов, затем порезы
function M.BladeFlurry(K, f, aim, def)
	local C, F = K.Combat, K.Fighters
	local dir = K.dir(f, aim)
	local tok = K.start(f, def.Id, 1.2, 0)
	K.anim(f, "slash_through")
	K.iframes(f, 0.4)
	K.fx("Trail", { m = f.model, c = CRIMSON, t = 0.4, k = "blade" })
	local start = f.root.Position
	local passed = {}
	K.dash(f, tok, dir, 112, 0.3, { contact = 4, stop = false, onContact = function(t)
		passed[#passed + 1] = t
		C.hit(f, t, { damage = 2, stun = 1.3, fx = "slash", knockback = Vector3.zero, kbTime = 0.01, noCombo = true })
	end })
	K.fx("Lines", { a = start, b = f.root.Position, c = CRIMSON })
	if #passed == 0 then
		K.finish(f, tok)
		return
	end
	if not K.wait(f, tok, 0.28) then return end
	for _ = 1, 4 do
		for _, t in ipairs(passed) do
			if F.alive(t) then
				K.fx("SlashMark", { p = t.root.Position, c = CRIMSON })
				C.hit(f, t, { damage = 3, stun = 0.7, fx = "slash", knockback = Vector3.zero, kbTime = 0.01 })
			end
		end
		task.wait(0.09)
	end
	for _, t in ipairs(passed) do
		if F.alive(t) then
			C.hit(f, t, { damage = 4, stun = 0.9, heavy = true, fx = "slashHeavy", knockback = K.knock(f, t, 46, 30), ragdoll = 1, kbTime = 0.15, hitstop = 0.06 })
		end
	end
	K.wait(f, tok, 0.2)
	K.finish(f, tok)
end

-- подброс и удар сверху
function M.RisingSlash(K, f, aim, def)
	local C, F = K.Combat, K.Fighters
	local dir = K.dir(f, aim)
	local tok = K.start(f, def.Id, 1.4, 0)
	K.anim(f, "rising_slash")
	if not K.wait(f, tok, 0.19) then return end
	local res = K.boxFront(f, dir, 7, 7, 8, { damage = 8, stun = 1.5, fx = "slash", knockback = Vector3.new(0, 72, 0) + dir * 6, kbTime = 0.25, hitstop = 0.06 }, {})
	K.fx("SlashArc", { cf = CFrame.lookAt(f.root.Position + dir * 3, f.root.Position + dir * 4) * CFrame.Angles(0, 0, math.rad(90)), c = CRIMSON, r = 6, w = 1.2 })
	local t = K.firstHit(res)
	if not t then
		K.wait(f, tok, 0.3)
		K.finish(f, tok)
		return
	end
	K.setVel(f, Vector3.new(0, 78, 0) + dir * 4)
	if not K.wait(f, tok, 0.3) then K.stopVel(f) return end
	K.stopVel(f)
	K.anim(f, "overhead")
	if not K.wait(f, tok, 0.12) then return end
	if F.alive(t) then
		C.hit(f, t, { damage = 10, stun = 1.2, heavy = true, fx = "slashHeavy", knockback = Vector3.new(0, -115, 0) + dir * 10, ragdoll = 1.5, kbTime = 0.18,
			shake = 1, hitstop = 0.1 })
		K.fx("SlashArc", { cf = f.root.CFrame * CFrame.new(0, -1, -3) * CFrame.Angles(0, 0, math.rad(90)), c = CRIMSON, r = 6, w = 1.4 })
	end
	K.setVel(f, Vector3.new(0, -85, 0))
	K.wait(f, tok, 0.22)
	K.stopVel(f)
	if F.alive(t) then K.fx("Crater", { p = K.ground(t.root.Position), r = 7, c = CRIMSON }) end
	K.finish(f, tok)
end

-- мгновенный разрез насквозь
function M.InstantCut(K, f, aim, def)
	local C = K.Combat
	local tok = K.start(f, def.Id, 0.9, 0)
	local t = K.target(f, aim, 55, 0.35)
	local from = f.root.Position
	local dir = K.dir(f, aim)
	if t then dir = K.Util.flat(t.root.Position - from, dir) end
	local dest
	if t then
		dest = K.safePoint(t.root.Position, t.root.Position + dir * 6)
	else
		dest = K.safePoint(from, from + dir * 30)
	end
	K.fx("Afterimage", { m = f.model, c = CRIMSON })
	K.teleport(f, dest, dir)
	K.anim(f, "slash_through")
	K.fx("Lines", { a = from, b = dest, c = CRIMSON, w = 1.2 })
	K.sound("SlashHeavy", dest)
	K.segmentHit(f, from, dest, 4, function(x)
		return { damage = 12, stun = 1.1, heavy = true, fx = "slashHeavy", knockback = dir * 30 + Vector3.new(0, 26, 0), ragdoll = 1, kbTime = 0.15, hitstop = 0.1 }
	end, {})
	K.wait(f, tok, 0.35)
	K.finish(f, tok)
end

-- буря порезов вокруг
function M.ThousandCuts(K, f, aim, def)
	local C, H = K.Combat, K.Hitbox
	local tok = K.start(f, def.Id, 1.6, 0)
	K.armor(f, 1.2)
	K.anim(f, "spin_loop")
	local center = f.root.Position
	K.fx("Ring", { p = K.ground(center), c = CRIMSON, r = 14, t = 1.1 })
	for i = 1, 10 do
		if not K.wait(f, tok, 0.1) then return end
		for _, t in ipairs(H.radius(f.root.Position, 14, { [f] = true })) do
			K.fx("SlashMark", { p = t.root.Position, c = CRIMSON })
			C.hit(f, t, { damage = 1.7, stun = 0.5, fx = "slash", knockback = Vector3.zero, kbTime = 0.01, noCombo = i % 2 == 0 })
		end
	end
	K.radiusHit(f, f.root.Position, 14, function(t)
		return { damage = 6, stun = 1, heavy = true, fx = "slashHeavy", knockback = K.knock(f, t, 70, 30), ragdoll = 1.3, kbTime = 0.2, shake = 1 }
	end, {})
	K.fx("Burst", { p = f.root.Position, c = CRIMSON, r = 12, k = "slash" })
	K.wait(f, tok, 0.25)
	K.finish(f, tok)
end

-- территория: Сад Клинков
function M.BladeGarden(K, f, aim, def)
	local C = K.Combat
	local tok = K.start(f, def.Id, 1.7, 0)
	K.iframes(f, 1.6)
	K.anim(f, "sign")
	K.fx("Ult", { m = f.model, text = def.Name, c = CRIMSON, c2 = WHITE, domain = true })
	if not K.wait(f, tok, 1.15) then return end
	K.Domains.open(f, {
		style = "blade", name = def.Name, radius = 40, duration = 8, tick = 0.4, slow = 0.55,
		onTick = function(d, victims)
			for _, v in ipairs(victims) do
				K.fx("SlashMark", { p = v.root.Position, c = CRIMSON, big = true })
				C.hit(f, v, { damage = 3, stun = 0.35, trueDamage = true, fx = "slash", knockback = Vector3.zero, kbTime = 0.01 })
			end
		end,
	})
	K.wait(f, tok, 0.4)
	K.finish(f, tok)
end

return M
