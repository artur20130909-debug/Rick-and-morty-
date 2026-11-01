-- Эффекты главы 2 (только у этого игрока, сами исчезают):
--   Fx.explosion(pos, opts) — взрыв: вспышка, огненный шар, ударная волна, дым, обломки, свет;
--   Fx.smokeColumn(pos, parent) — горящий дом вдали: огонь, столб дыма, мерцающий свет;
--   Fx.dust(cf, size, parent) — пыль и крошка с потолка (от удара);
--   Fx.animate(dur, f, done) — помощник: f(k, dt) каждый кадр, k = 0..1 (замирает на паузе).
local RunService = game:GetService("RunService")

local Fx = {}
local B, U, Audio

function Fx.init(ctx)
	B, U, Audio = ctx.Build, ctx.Util, ctx.Audio
end

local NOPHYS = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }

local function animate(dur, f, done)
	task.spawn(function()
		local el = 0
		while el < dur do
			local dt = RunService.Heartbeat:Wait()
			if not U.paused then
				el = math.min(dur, el + dt)
				f(el / dur, dt)
			end
		end
		if done then done() end
	end)
end
Fx.animate = animate

local function rnd(a, b) return a + math.random() * (b - a) end

-- взрыв; opts: size (радиус огненного шара, по умолчанию 8), parent, sound (false — тихо),
-- debris (число обломков), ground (высота земли — по ней катится ударная волна), volume
function Fx.explosion(pos, opts)
	opts = opts or {}
	local size = opts.size or 8
	local m = Instance.new("Model")
	m.Name = "RM_Explosion"
	m.Parent = opts.parent or workspace
	local groundY = opts.ground or (pos.Y - size * 0.4)
	-- источник звука и света
	local core = B.ball(m, "Core", size * 0.5, CFrame.new(pos), "#FFF8DC", Enum.Material.Neon, NOPHYS)
	local light = B.light(core, "PointLight", { Color = Color3.fromRGB(255, 170, 80), Brightness = 10, Range = math.min(60, size * 7), Shadows = false })
	if opts.sound ~= false then
		Audio.play("Explosion", { at = core, volume = opts.volume or 1, min = 20, max = 600 })
	end
	-- огненные шары
	local fire = {}
	local cols = { "#FFD45A", "#FF9A2E", "#FF6A1F", "#FFB347", "#FF7B2E", "#FFE08A" }
	for i = 1, 7 do
		local off = Vector3.new(rnd(-1, 1), rnd(-0.3, 1), rnd(-1, 1)) * size * 0.45
		local b = B.ball(m, "Fire", 1, CFrame.new(pos + off * 0.3), cols[(i - 1) % #cols + 1], Enum.Material.Neon, NOPHYS)
		table.insert(fire, { p = b, off = off, s = size * rnd(0.7, 1.15), rise = rnd(0.2, 0.7) })
	end
	-- ударная волна по земле
	local ring = B.vcyl(m, "Shock", 0.3, size, CFrame.new(pos.X, groundY + 0.2, pos.Z), "#FFE7B0", Enum.Material.Neon, NOPHYS)
	-- дым
	local smoke = {}
	for _ = 1, 9 do
		local off = Vector3.new(rnd(-1, 1), rnd(0, 0.8), rnd(-1, 1)) * size * 0.6
		local b = B.ball(m, "Smoke", 1, CFrame.new(pos + off), Color3.fromRGB(math.random(48, 70), math.random(42, 58), math.random(50, 66)), Enum.Material.SmoothPlastic, NOPHYS)
		b.Transparency = 1
		table.insert(smoke, { p = b, off = off, s = size * rnd(0.9, 1.5), rise = size * rnd(0.8, 1.6), delay = rnd(0.05, 0.35) })
	end
	-- обломки (летят по дуге)
	local debris = {}
	for _ = 1, opts.debris or 10 do
		local s = rnd(0.25, 0.8) * math.min(1.5, size / 6)
		local b = B.part(m, "Debris", Vector3.new(s, s * rnd(0.5, 1), s), CFrame.new(pos), (math.random() < 0.5) and "#3A3540" or "#5A4E46", nil, NOPHYS)
		local dir = Vector3.new(rnd(-1, 1), rnd(0.6, 1.4), rnd(-1, 1))
		table.insert(debris, { p = b, v = dir * size * rnd(1.6, 2.6), rot = Vector3.new(rnd(-9, 9), rnd(-9, 9), rnd(-9, 9)) })
	end
	local total = 3.6
	animate(total, function(k, _)
		local t = k * total
		-- вспышка: быстро растёт и гаснет
		local ck = math.clamp(t / 0.25, 0, 1)
		local cs = size * (0.5 + 1.6 * ck)
		core.Size = Vector3.new(cs, cs, cs)
		core.Transparency = math.clamp((t - 0.15) / 0.35, 0, 1)
		light.Brightness = 10 * math.max(0, 1 - t / 1.2)
		-- огонь: раздувается и поднимается, тускнеет
		for _, f in ipairs(fire) do
			local fk = math.clamp(t / 0.6, 0, 1)
			local e = 1 - (1 - fk) * (1 - fk)
			local s = f.s * (0.4 + 0.9 * e)
			f.p.Size = Vector3.new(s, s, s)
			f.p.CFrame = CFrame.new(pos + f.off * (0.3 + 0.9 * e) + Vector3.new(0, f.rise * size * t * 0.5, 0))
			f.p.Transparency = math.clamp((t - 0.35) / 0.9, 0, 1)
			if t > 0.4 then f.p.Color = f.p.Color:Lerp(Color3.fromRGB(120, 40, 20), 0.04) end
		end
		-- ударная волна
		local rk = math.clamp(t / 0.6, 0, 1)
		local rs = size * (1 + 4.5 * (1 - (1 - rk) * (1 - rk)))
		ring.Size = Vector3.new(0.3, rs, rs)
		ring.Transparency = 0.15 + 0.85 * rk
		-- дым: появляется после вспышки, растёт и уходит вверх
		for _, sm in ipairs(smoke) do
			local st = t - sm.delay
			if st > 0 then
				local sk = math.clamp(st / (total - sm.delay), 0, 1)
				local s = sm.s * (0.6 + 1.6 * sk)
				sm.p.Size = Vector3.new(s, s, s)
				sm.p.CFrame = CFrame.new(pos + sm.off + Vector3.new(0, sm.rise * sk, 0))
				sm.p.Transparency = math.clamp(0.15 + sk * 0.95, 0, 1)
			end
		end
		-- обломки по дуге
		for _, d in ipairs(debris) do
			if d.p.Parent then
				local p = pos + d.v * t + Vector3.new(0, -60 * t * t * 0.5, 0)
				if p.Y < groundY then p = Vector3.new(p.X, groundY + 0.2, p.Z) end
				d.p.CFrame = CFrame.new(p) * CFrame.Angles(d.rot.X * t, d.rot.Y * t, d.rot.Z * t)
				d.p.Transparency = math.clamp((t - 2.2) / 1.2, 0, 1)
			end
		end
	end, function() m:Destroy() end)
	return m
end

-- горящий дом вдали: огонь + столб дыма + мерцающий свет; вернуть деталь (уничтожить — убрать)
function Fx.smokeColumn(pos, parent, scale)
	scale = scale or 1
	local p = B.part(parent or workspace, "RM_Fire", Vector3.new(8, 2, 8) * scale, CFrame.new(pos), Color3.new(0, 0, 0), nil,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	local fire = Instance.new("ParticleEmitter")
	fire.Name = "Flames"
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 120)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 40, 20)) })
	fire.LightEmission = 1
	fire.LightInfluence = 0
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3 * scale), NumberSequenceKeypoint.new(1, 0.5 * scale) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	fire.Lifetime = NumberRange.new(0.6, 1.2)
	fire.Speed = NumberRange.new(6 * scale, 10 * scale)
	fire.SpreadAngle = Vector2.new(15, 15)
	fire.Rate = 40
	fire.EmissionDirection = Enum.NormalId.Top
	fire.Parent = p
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(58, 50, 58), Color3.fromRGB(30, 26, 32))
	smoke.LightInfluence = 0.4
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5 * scale), NumberSequenceKeypoint.new(1, 22 * scale) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.7, 0.5), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(6, 9)
	smoke.Speed = NumberRange.new(8 * scale, 12 * scale)
	smoke.Acceleration = Vector3.new(3, 1, 0)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.Rate = 9
	smoke.RotSpeed = NumberRange.new(-20, 20)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = p
	local light = B.light(p, "PointLight", { Color = Color3.fromRGB(255, 140, 60), Brightness = 3, Range = 40 * scale, Shadows = false })
	-- языки пламени и клубы дыма из деталей (видно и на низкой графике)
	local flames, puffs = {}, {}
	for i = 1, 9 do
		local off = Vector3.new(rnd(-5, 5), rnd(0, 1.5), rnd(-3, 3)) * scale
		local f = B.ball(p, "Flame", 2.5 * scale, CFrame.new(pos + off), (i % 3 == 0) and "#FF5A1F" or ((i % 2 == 0) and "#FF9A2E" or "#FFD45A"), Enum.Material.Neon, NOPHYS)
		table.insert(flames, { p = f, off = off, ph = rnd(0, 6) })
	end
	for i = 1, 7 do
		local b = B.ball(p, "Puff", 6 * scale, CFrame.new(pos), Color3.fromRGB(46, 40, 48), Enum.Material.SmoothPlastic, NOPHYS)
		b.Transparency = 0.35
		table.insert(puffs, { p = b, k = (i - 1) / 7, side = rnd(-1, 1) })
	end
	-- мерцание огня, дым поднимается и тает
	task.spawn(function()
		local t = 0
		while p.Parent do
			local dt = RunService.Heartbeat:Wait()
			t = t + dt
			light.Brightness = 2.4 + math.noise(t * 6, 1) * 2
			for _, f in ipairs(flames) do
				local s = (3.6 + math.sin(t * 9 + f.ph) * 1.0) * scale
				f.p.Size = Vector3.new(s, s * 1.4, s)
				f.p.CFrame = CFrame.new(pos + f.off + Vector3.new(0, math.abs(math.sin(t * 5 + f.ph)) * 2 * scale, 0))
			end
			for _, b in ipairs(puffs) do
				b.k = (b.k + dt / 9) % 1
				local s = (5 + b.k * 16) * scale
				b.p.Size = Vector3.new(s, s, s)
				b.p.CFrame = CFrame.new(pos + Vector3.new(b.side * 3 + b.k * 18, 3 + b.k * 40, b.k * 4) * scale)
				b.p.Transparency = 0.3 + b.k * 0.7
			end
		end
	end)
	return p
end

-- пыль с потолка: облачко частиц в коробке cf/size, сыплется вниз
function Fx.dust(cf, size, parent)
	local p = B.part(parent or workspace, "RM_Dust", size, cf, Color3.new(0, 0, 0), nil,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(205, 196, 180))
	pe.LightInfluence = 0.8
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.6) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(1.2, 2.2)
	pe.Speed = NumberRange.new(0.5, 2)
	pe.Acceleration = Vector3.new(0, -6, 0)
	pe.SpreadAngle = Vector2.new(30, 30)
	pe.Rate = 0
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.EmissionDirection = Enum.NormalId.Bottom
	pe.Parent = p
	pe:Emit(60)
	-- крошка: мелкие кусочки падают
	local bits = {}
	for _ = 1, 10 do
		local s = rnd(0.12, 0.3)
		local local0 = Vector3.new(rnd(-0.5, 0.5) * size.X, 0, rnd(-0.5, 0.5) * size.Z)
		local b = B.part(p, "Bit", Vector3.new(s, s, s), cf * CFrame.new(local0), "#BFB6A6", nil, NOPHYS)
		table.insert(bits, { p = b, from = (cf * CFrame.new(local0)).Position, delay = rnd(0, 0.4) })
	end
	animate(2.6, function(k)
		local t = k * 2.6
		for _, b in ipairs(bits) do
			local bt = math.max(0, t - b.delay)
			b.p.CFrame = CFrame.new(b.from + Vector3.new(0, -30 * bt * bt * 0.5, 0)) * CFrame.Angles(bt * 7, bt * 5, 0)
			if b.p.Position.Y < 0.1 then b.p.Transparency = 1 end
		end
	end, function() p:Destroy() end)
	return p
end

return Fx
