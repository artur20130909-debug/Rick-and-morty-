-- Призыватель Теней: псы, вороны, нырок в тень, пасть бездны; «Ночной Легион» и территория «Бездна».
local RunService = game:GetService("RunService")
local Characters = require(game:GetService("ReplicatedStorage").Shared.Characters)
local DEF = Characters.get("ShadowCaller")
local PURPLE, BLUE = DEF.Color, DEF.Accent
local BLACK = Color3.fromRGB(14, 10, 22)

local M = {}

-- теневой пёс из деталей (виден всем, двигает сервер)
local function makeHound(K, cf)
	local model = Instance.new("Model")
	model.Name = "ShadowHound"
	local function part(name, size, offset, color, mat)
		local p = K.Util.part({ Name = name, Size = size, CFrame = cf * offset, Color = color, Material = mat or Enum.Material.SmoothPlastic })
		p.Parent = model
		return p
	end
	local body = part("Body", Vector3.new(1.4, 1.3, 3.2), CFrame.new(0, 0, 0), BLACK)
	part("Head", Vector3.new(1.2, 1.1, 1.3), CFrame.new(0, 0.45, -2), BLACK)
	part("Snout", Vector3.new(0.8, 0.6, 0.9), CFrame.new(0, 0.2, -2.9), BLACK)
	part("EyeL", Vector3.new(0.22, 0.12, 0.1), CFrame.new(-0.3, 0.65, -2.66), PURPLE, Enum.Material.Neon)
	part("EyeR", Vector3.new(0.22, 0.12, 0.1), CFrame.new(0.3, 0.65, -2.66), PURPLE, Enum.Material.Neon)
	part("EarL", Vector3.new(0.25, 0.6, 0.3), CFrame.new(-0.4, 1.15, -1.8), BLACK)
	part("EarR", Vector3.new(0.25, 0.6, 0.3), CFrame.new(0.4, 1.15, -1.8), BLACK)
	part("Tail", Vector3.new(0.3, 0.3, 1.6), CFrame.new(0, 0.4, 2.1) * CFrame.Angles(math.rad(25), 0, 0), BLACK)
	for _, x in ipairs({ -0.5, 0.5 }) do
		for _, z in ipairs({ -1.1, 1.1 }) do part("Leg", Vector3.new(0.35, 1.2, 0.35), CFrame.new(x, -1, z), BLACK) end
	end
	part("Mane", Vector3.new(1.6, 1.2, 0.9), CFrame.new(0, 0.5, -1.2), PURPLE, Enum.Material.Neon).Transparency = 0.6
	model.PrimaryPart = body
	model.Parent = workspace:FindFirstChild("FX") or workspace
	return model
end

local function hound(K, f, start, target, dmg)
	local C, F, H = K.Combat, K.Fighters, K.Hitbox
	local model = makeHound(K, start)
	K.fx("Smoke", { p = start.Position, c = PURPLE, r = 3 })
	local pos = start.Position
	local dir = start.LookVector
	local t0 = os.clock()
	local bit = false
	while os.clock() - t0 < 2.6 and F.alive(f) do
		local dt = RunService.Heartbeat:Wait()
		local tgt = target
		if not tgt or not F.alive(tgt) then tgt = H.nearest(pos, 40, { [f] = true }) end
		if tgt then
			local d = tgt.root.Position - pos
			local flat = Vector3.new(d.X, 0, d.Z)
			if flat.Magnitude > 0.5 then dir = dir:Lerp(flat.Unit, math.min(1, dt * 8)).Unit end
			if d.Magnitude < 3.4 then
				C.hit(f, tgt, { damage = dmg, stun = 0.95, fx = "bite", knockback = dir * 26 + Vector3.new(0, 14, 0), kbTime = 0.15, hitstop = 0.05 })
				K.fx("Burst", { p = tgt.root.Position, c = PURPLE, r = 3, k = "shadow" })
				bit = true
				break
			end
		end
		pos = pos + dir * 58 * dt
		local g = K.Util.ground(pos + Vector3.new(0, 3, 0), 12)
		pos = Vector3.new(pos.X, g.Y + 1.7, pos.Z)
		local bob = math.sin((os.clock() - t0) * 22) * 0.25
		model:PivotTo(CFrame.lookAt(pos, pos + dir) * CFrame.new(0, bob, 0))
	end
	K.fx("Smoke", { p = pos, c = PURPLE, r = bit and 4 or 3 })
	model:Destroy()
end

local function hounds(K, f, aim, def, n, dmg)
	local tok = K.start(f, def.Id, 0.65, 6)
	K.anim(f, "summon")
	K.fx("ShadowPool", { p = K.ground(f.root.Position), r = 4.5, t = 0.9, c = PURPLE })
	K.sound("Shadow", f.root.Position)
	if not K.wait(f, tok, 0.32) then return end
	K.finish(f, tok)
	local target = K.target(f, aim, 55, 0.25)
	for i = 1, n do
		local side = (i % 2 == 1) and 1 or -1
		local row = math.floor((i - 1) / 2)
		local start = f.root.CFrame * CFrame.new(side * (2.2 + row * 1.5), -1.3, -1 + row * 2)
		task.spawn(hound, K, f, start, target, dmg)
	end
end

function M.Hounds(K, f, aim, def) hounds(K, f, aim, def, 2, 7) end
function M.HoundPack(K, f, aim, def) hounds(K, f, aim, def, 4, 6) end

-- стая воронов
function M.CrowSwarm(K, f, aim, def)
	local C, F = K.Combat, K.Fighters
	local dir = K.dir(f, aim)
	local tok = K.start(f, def.Id, 0.55, 5)
	K.anim(f, "throw")
	if not K.wait(f, tok, 0.18) then return end
	K.sound("Crow", f.root.Position)
	K.projectile(f, {
		from = f.root.Position + dir * 2 + Vector3.new(0, 1, 0), dir = dir, speed = 72, range = 75, radius = 5, pierce = 99,
		kind = "crows", color = PURPLE,
		onHit = function(t)
			t.blindEnd = math.max(t.blindEnd, K.now() + 1.6)
			task.spawn(function()
				for _ = 1, 3 do
					if F.alive(t) then C.hit(f, t, { damage = 3, stun = 0.65, fx = "shadow", knockback = dir * 4, kbTime = 0.06 }) end
					task.wait(0.1)
				end
			end)
			return true
		end,
	})
	K.wait(f, tok, 0.25)
	K.finish(f, tok)
end

-- нырок в тень: неуязвимость и скорость, выход — апперкот
function M.ShadowDive(K, f, aim, def, slot)
	local C = K.Combat
	local tok = K.start(f, def.Id, 1.8, 0)
	K.anim(f, "sink")
	K.fx("ShadowPool", { p = K.ground(f.root.Position), r = 3.5, t = 0.6, c = PURPLE })
	K.sound("Shadow", f.root.Position)
	if not K.wait(f, tok, 0.22) then return end
	local now = K.now()
	f.invisEnd = now + 1.5
	K.iframes(f, 1.5)
	K.busy(f, 1.6, 40)
	local emerged = false
	local function emerge()
		if emerged or not K.valid(f, tok) then return end
		emerged = true
		f.invisEnd = 0
		f.iframesEnd = K.now() + 0.25
		K.busy(f, 0.55, 0)
		K.anim(f, "emerge")
		local pos = f.root.Position
		K.fx("ShadowBurst", { p = K.ground(pos), r = 7, c = PURPLE, c2 = BLUE })
		K.sound("Bite", pos)
		K.radiusHit(f, pos, 7, function(t)
			return { damage = 10, stun = 1, heavy = true, fx = "shadow", knockback = Vector3.new(0, 64, 0) + C.away(f, t) * 10, ragdoll = 1.2, kbTime = 0.22, hitstop = 0.08, shake = 0.8 }
		end, {})
		K.after(0.45, function() K.finish(f, tok) end)
	end
	K.recast(f, slot, now + 0.25, now + 1.45, emerge)
	-- бот сам плывёт к цели
	if not f.player then
		local t = K.target(f, aim, 40, -1)
		if t then f.hum:MoveTo(t.root.Position) end
	end
	local t0 = os.clock()
	while os.clock() - t0 < 1.4 and not emerged do
		task.wait(0.1)
		if not K.valid(f, tok) then
			f.invisEnd = 0
			return
		end
		if not f.player then
			local t = K.Hitbox.nearest(f.root.Position, 4, { [f] = true })
			if t then
				f.recast = nil
				emerge()
			end
		end
	end
	if not emerged then
		f.recast = nil
		emerge()
	end
end

-- пасть бездны под врагом
function M.AbyssMaw(K, f, aim, def)
	local tok = K.start(f, def.Id, 0.7, 4)
	K.anim(f, "point")
	local point = K.aimPoint(f, aim, 50, 25)
	K.fx("ShadowPool", { p = point, r = 7, t = 1.0, c = PURPLE, warn = true })
	if not K.wait(f, tok, 0.4) then return end
	K.finish(f, tok)
	K.after(0.12, function()
		K.fx("Maw", { p = point, r = 7, c = PURPLE })
		K.sound("Bite", point)
		K.radiusHit(f, point, 7.5, { damage = 16, stun = 1.3, heavy = true, fx = "bite", knockback = Vector3.new(0, 66, 0), ragdoll = 1.4, kbTime = 0.2,
			shake = 1, hitstop = 0.1 }, {})
		K.breakAt(point, 6, 1)
	end)
end

-- огромный кулак тени
function M.ShadowGiant(K, f, aim, def)
	local dir = K.dir(f, aim)
	local tok = K.start(f, def.Id, 1.0, 2)
	K.anim(f, "punch_heavy")
	K.fx("GiantFist", { cf = CFrame.lookAt(f.root.Position, f.root.Position + dir), c = PURPLE, c2 = BLACK, len = 32, t = 0.6 })
	if not K.wait(f, tok, 0.3) then return end
	K.boxFront(f, dir, 12, 10, 32, function(t)
		return { damage = 18, stun = 1.2, heavy = true, fx = "shadow", knockback = dir * 92 + Vector3.new(0, 30, 0), ragdoll = 1.6, kbTime = 0.22,
			guardBreak = true, shake = 1.4, hitstop = 0.1 }
	end, {})
	for i = 1, 3 do K.breakAt(f.root.Position + dir * (i * 10), 6, 1.2) end
	K.shake(f.root.Position + dir * 10, 1.3, 80)
	K.wait(f, tok, 0.4)
	K.finish(f, tok)
end

-- цепи: сковать всех вокруг
function M.ShadowChains(K, f, aim, def)
	local C, H = K.Combat, K.Hitbox
	local tok = K.start(f, def.Id, 0.8, 0)
	K.anim(f, "summon")
	K.fx("ShadowPool", { p = K.ground(f.root.Position), r = 20, t = 0.8, c = PURPLE })
	if not K.wait(f, tok, 0.35) then return end
	for _, t in ipairs(H.radius(f.root.Position, 20, { [f] = true })) do
		local r = C.hit(f, t, { damage = 6, stun = 0.6, fx = "shadow", knockback = Vector3.zero, kbTime = 0.01 })
		if r == "hit" then
			t.rootEnd = math.max(t.rootEnd, K.now() + 2)
			K.fx("Chains", { m = t.model, a = K.ground(f.root.Position), t = 2, c = PURPLE })
		end
	end
	K.wait(f, tok, 0.3)
	K.finish(f, tok)
end

-- территория: Бездна
function M.Abyss(K, f, aim, def)
	local C = K.Combat
	local tok = K.start(f, def.Id, 1.7, 0)
	K.iframes(f, 1.6)
	K.anim(f, "sign")
	K.fx("Ult", { m = f.model, text = def.Name, c = PURPLE, c2 = BLUE, domain = true })
	if not K.wait(f, tok, 1.15) then return end
	K.Domains.open(f, {
		style = "abyss", name = def.Name, radius = 42, duration = 8, tick = 0.8, slow = 0.4,
		onTick = function(d, victims)
			for _, v in ipairs(victims) do
				K.fx("Maw", { p = K.ground(v.root.Position), r = 3.5, c = PURPLE, small = true })
				C.hit(f, v, { damage = 5, stun = 0.5, trueDamage = true, fx = "bite", knockback = Vector3.new(0, 10, 0), kbTime = 0.08 })
			end
		end,
	})
	K.wait(f, tok, 0.4)
	K.finish(f, tok)
end

return M
