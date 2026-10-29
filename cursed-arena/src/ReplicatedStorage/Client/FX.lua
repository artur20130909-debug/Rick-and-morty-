-- Визуальные эффекты на клиенте: из неоновых деталей, частиц, следов и света.
-- Всё живёт в workspace.LocalFX и обновляется одним циклом (FX.run).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Util = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))

local FX = {}

local folder = Instance.new("Folder")
folder.Name = "LocalFX"
folder.Parent = workspace
FX.folder = folder

FX.quality = 1 -- 0.5 на слабых устройствах (меньше частиц)

local TEX = {
	spark = "rbxasset://textures/particles/sparkles_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}
FX.TEX = TEX

local WHITE = Color3.new(1, 1, 1)
local rand = Util.rand

---------------------------------------------------------------- цикл обновления
local active = {}
function FX.run(dur, update, done)
	local e = { t0 = os.clock(), dur = math.max(dur, 1e-3), update = update, done = done }
	active[#active + 1] = e
	return e
end
function FX.stop(e)
	if e then e.dur = 0 end
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for i = #active, 1, -1 do
		local e = active[i]
		local a = (now - e.t0) / e.dur
		if a >= 1 then
			table.remove(active, i)
			pcall(e.update, 1, dt)
			if e.done then pcall(e.done) end
		else
			local ok, err = pcall(e.update, a, dt)
			if not ok then
				table.remove(active, i)
				warn("[FX] " .. tostring(err))
				if e.done then pcall(e.done) end
			end
		end
	end
end)

---------------------------------------------------------------- детали
function FX.part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "Parent" then p[k] = v end
	end
	p.Parent = props.Parent or folder
	return p
end

local function kill(...)
	for i = 1, select("#", ...) do
		local x = select(i, ...)
		if x then x:Destroy() end
	end
end
FX.kill = kill

local function easeOut(a, k) return 1 - (1 - a) ^ (k or 3) end

-- шар: растёт и тает
function FX.ball(pos, color, r0, r1, dur, t0, mat)
	t0 = t0 or 0.1
	local p = FX.part({ Shape = Enum.PartType.Ball, Color = color, Size = Vector3.one * r0 * 2, CFrame = CFrame.new(pos), Transparency = t0,
		Material = mat or Enum.Material.Neon })
	FX.run(dur, function(a)
		local r = r0 + (r1 - r0) * easeOut(a, 3)
		p.Size = Vector3.one * math.max(0.05, r * 2)
		p.Transparency = t0 + (1 - t0) * a ^ 0.9
	end, function() p:Destroy() end)
	return p
end

-- свет-вспышка
function FX.light(pos, color, range, brightness, dur)
	local p = FX.part({ Size = Vector3.one * 0.2, CFrame = CFrame.new(pos), Transparency = 1 })
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
	FX.run(dur, function(a) l.Brightness = brightness * (1 - a) ^ 2 end, function() p:Destroy() end)
end

-- кольцо (ударная волна) из сегментов: cf задаёт центр и плоскость (по умолчанию горизонт)
function FX.ring(pos, color, r0, r1, dur, opts)
	opts = opts or {}
	local n = opts.n or 28
	local w, h = opts.w or 0.7, opts.h or 0.35
	local cf = opts.cf or CFrame.new(pos)
	local segs = {}
	local t0 = opts.t0 or 0.05
	for i = 1, n do
		segs[i] = FX.part({ Color = color, Size = Vector3.new(w, h, 1), Transparency = t0, Material = opts.mat or Enum.Material.Neon })
	end
	FX.run(dur, function(a)
		local e = easeOut(a, opts.k or 2.5)
		local r = r0 + (r1 - r0) * e
		local seg = 2 * math.pi * math.max(r, 0.1) / n * 1.12
		local tr = t0 + (1 - t0) * a ^ 1.6
		local ww = w * (1 - a * 0.6)
		for i, s in ipairs(segs) do
			local ang = i / n * 2 * math.pi
			s.Size = Vector3.new(ww, h, seg)
			s.CFrame = cf * CFrame.Angles(0, ang, 0) * CFrame.new(r, 0, 0)
			s.Transparency = tr
		end
	end, function() for _, s in ipairs(segs) do s:Destroy() end end)
end

-- искры: летят из точки и падают
function FX.sparks(pos, color, n, speed, opts)
	opts = opts or {}
	n = math.max(1, math.floor(n * FX.quality + 0.5))
	local g = opts.g or 60
	local size = opts.size or 0.22
	for _ = 1, n do
		local dir
		if opts.dir then
			local sp = opts.spread or 0.6
			dir = (opts.dir + Vector3.new(rand(-sp, sp), rand(-sp, sp) + 0.2, rand(-sp, sp))).Unit
		else
			dir = Vector3.new(rand(-1, 1), rand(-0.2, 1), rand(-1, 1))
			if dir.Magnitude < 0.05 then dir = Vector3.yAxis end
			dir = dir.Unit
		end
		local v = dir * speed * rand(0.45, 1)
		local p = FX.part({ Color = opts.c2 and (math.random() < 0.5 and color or opts.c2) or color, Size = Vector3.one * size, CFrame = CFrame.new(pos) })
		local cur = pos
		local life = rand(opts.life or 0.25, (opts.life or 0.25) * 2)
		FX.run(life, function(a, dt)
			v = v + Vector3.new(0, -g, 0) * dt
			v = v * (1 - math.min(0.9, (opts.drag or 2) * dt))
			cur = cur + v * dt
			local L = math.clamp(v.Magnitude * 0.03, 1, 6)
			p.Size = Vector3.new(size, size, size * L) * (1 - a * 0.7)
			if v.Magnitude > 0.1 then p.CFrame = CFrame.lookAt(cur, cur + v) else p.CFrame = CFrame.new(cur) end
			p.Transparency = a ^ 1.5
		end, function() p:Destroy() end)
	end
end

-- частицы с текстурой (дым, огонь, блёстки)
local emitterHost
local function host()
	if emitterHost and emitterHost.Parent then return emitterHost end
	emitterHost = FX.part({ Size = Vector3.one * 0.1, Transparency = 1, CFrame = CFrame.new(0, -5000, 0), Name = "EmitterHost" })
	return emitterHost
end
function FX.emit(pos, opts)
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = host()
	att.WorldPosition = pos
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX[opts.tex or "spark"] or opts.tex
	e.Color = ColorSequence.new(opts.color or WHITE, opts.color2 or opts.color or WHITE)
	e.LightEmission = opts.light or 0.8
	e.LightInfluence = opts.lightInf or 0
	e.Size = opts.size or NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = opts.transp or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(opts.life or 0.4, (opts.life or 0.4) * 1.6)
	e.Speed = NumberRange.new(opts.speed or 12, (opts.speed or 12) * 1.8)
	e.SpreadAngle = Vector2.new(opts.spread or 180, opts.spread or 180)
	e.Drag = opts.drag or 3
	e.Acceleration = opts.accel or Vector3.zero
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Rotation = NumberRange.new(0, 360)
	e.Rate = 0
	e.EmissionDirection = Enum.NormalId.Top
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = att
	e:Emit(math.max(1, math.floor((opts.n or 12) * FX.quality + 0.5)))
	task.delay((opts.life or 0.4) * 1.8 + 0.1, function() att:Destroy() end)
	return e
end

-- луч-цилиндр от a к b (ядро + оболочка)
function FX.beam(a, b, color, width, dur, color2)
	local d = b - a
	local len = d.Magnitude
	if len < 0.1 then return end
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	local outer = FX.part({ Shape = Enum.PartType.Cylinder, Color = color, Size = Vector3.new(len, width, width), CFrame = cf, Transparency = 0.25 })
	local core = FX.part({ Shape = Enum.PartType.Cylinder, Color = color2 or WHITE, Size = Vector3.new(len, width * 0.45, width * 0.45), CFrame = cf, Transparency = 0 })
	FX.light(a + d * 0.15, color, 30, 6, dur)
	FX.run(dur, function(t)
		local grow = math.min(1, t * 8)
		local shrink = 1 - math.max(0, (t - 0.55) / 0.45)
		local k = grow * shrink
		local wob = 1 + math.sin(t * 60) * 0.06
		outer.Size = Vector3.new(len, width * k * wob, width * k * wob)
		core.Size = Vector3.new(len, width * 0.45 * k, width * 0.45 * k)
		outer.Transparency = 0.25 + 0.75 * (1 - shrink)
	end, function() kill(outer, core) end)
end

-- молния: ломаная линия
function FX.bolt(a, b, color, width, dur, color2)
	width = width or 0.4
	dur = dur or 0.22
	local d = b - a
	local len = d.Magnitude
	if len < 0.1 then return end
	local n = math.clamp(math.floor(len / 3.5), 3, 18)
	local pts = { a }
	local right = d:Cross(Vector3.yAxis)
	if right.Magnitude < 0.01 then right = Vector3.xAxis end
	right = right.Unit
	local up = right:Cross(d).Unit
	for i = 1, n - 1 do
		local t = i / n
		local amp = math.sin(t * math.pi) * math.min(3.5, len * 0.12)
		pts[#pts + 1] = a + d * t + right * rand(-amp, amp) + up * rand(-amp, amp)
	end
	pts[#pts + 1] = b
	local segs = {}
	for i = 1, #pts - 1 do
		local p0, p1 = pts[i], pts[i + 1]
		local L = (p1 - p0).Magnitude
		segs[#segs + 1] = FX.part({ Color = (i % 2 == 0 and color2) or color, Size = Vector3.new(width, width, L + width * 0.5),
			CFrame = CFrame.lookAt((p0 + p1) / 2, p1) })
	end
	FX.light((a + b) / 2, color, math.min(60, len), 5, dur)
	FX.run(dur, function(t)
		local flick = (math.floor(t * 30) % 2 == 0) and 0 or 0.5
		for _, s in ipairs(segs) do s.Transparency = math.clamp(t ^ 2 + flick * 0.5, 0, 1) end
	end, function() for _, s in ipairs(segs) do s:Destroy() end end)
end

-- дуга-разрез: cf — центр и плоскость (дуга в плоскости XZ этой системы), r — радиус
function FX.slash(cf, color, r, width, dur, span, color2)
	span = math.rad(span or 170)
	width = width or 1
	dur = dur or 0.28
	local n = 16
	local segs = {}
	for i = 1, n do
		segs[i] = FX.part({ Color = (color2 and i % 3 == 0) and color2 or color, Size = Vector3.new(0.1, 0.12, 1), Transparency = 1 })
	end
	local sweep = 0.35
	FX.run(dur, function(t)
		local shown = math.min(1, t / sweep)
		local fade = math.max(0, (t - sweep) / (1 - sweep))
		for i, s in ipairs(segs) do
			local f = (i - 0.5) / n
			if f <= shown then
				local ang = -span / 2 + span * f
				local thick = width * math.sin(f * math.pi) * (1 - fade * 0.5)
				local seg = 2 * r * math.sin(span / n / 2) * 1.15
				s.Size = Vector3.new(math.max(0.05, thick), 0.12, seg)
				s.CFrame = cf * CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, -r) * CFrame.Angles(0, math.rad(90), 0)
				s.Transparency = 0.05 + 0.95 * fade
			else
				s.Transparency = 1
			end
		end
	end, function() for _, s in ipairs(segs) do s:Destroy() end end)
end

-- крест-разрез (отметина)
function FX.slashMark(pos, color, size, dur)
	size = size or 6
	local cf = CFrame.new(pos) * CFrame.Angles(rand(0, 6.28), rand(0, 6.28), rand(0, 6.28))
	local a = FX.part({ Color = color, Size = Vector3.new(0.12, 0.12, size), CFrame = cf })
	local w = FX.part({ Color = WHITE, Size = Vector3.new(0.05, 0.05, size * 0.9), CFrame = cf })
	FX.run(dur or 0.25, function(t)
		local k = math.sin(math.min(1, t * 2) * math.pi / 2)
		a.Size = Vector3.new(0.18 * (1 - t), 0.18 * (1 - t), size * k)
		w.Size = Vector3.new(0.06, 0.06, size * 0.9 * k)
		a.Transparency = t ^ 2
		w.Transparency = t
	end, function() kill(a, w) end)
end

-- следы на руках и ногах
local LIMBS = { "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
function FX.trail(model, color, dur, limbs, width)
	local trails = {}
	for _, name in ipairs(limbs or LIMBS) do
		local part = model:FindFirstChild(name)
		if part then
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 0.6, 0)
			a0.Parent = part
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -1, 0)
			a1.Parent = part
			local tr = Instance.new("Trail")
			tr.Attachment0 = a0
			tr.Attachment1 = a1
			tr.Color = ColorSequence.new(color)
			tr.LightEmission = 1
			tr.Lifetime = 0.18
			tr.FaceCamera = true
			tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
			tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, width or 1), NumberSequenceKeypoint.new(1, 0) })
			tr.Parent = part
			trails[#trails + 1] = { tr, a0, a1 }
		end
	end
	task.delay(dur, function()
		for _, x in ipairs(trails) do x[1].Enabled = false end
		task.delay(0.3, function()
			for _, x in ipairs(trails) do kill(x[1], x[2], x[3]) end
		end)
	end)
end

-- призрачная копия тела (рывки, телепорты)
local BODY = { "Head", "Torso", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
function FX.afterimage(model, color, dur)
	dur = dur or 0.4
	local ghosts = {}
	for _, name in ipairs(BODY) do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			local g = FX.part({ Color = color, Size = name == "Head" and Vector3.new(1.2, 1.2, 1.2) or p.Size, CFrame = p.CFrame, Transparency = 0.35,
				Shape = name == "Head" and Enum.PartType.Ball or Enum.PartType.Block })
			ghosts[#ghosts + 1] = g
		end
	end
	FX.run(dur, function(t)
		for _, g in ipairs(ghosts) do g.Transparency = 0.35 + 0.65 * t end
	end, function() for _, g in ipairs(ghosts) do g:Destroy() end end)
end

-- кратер: камни по кругу, тёмное пятно, пыль
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function groundColor(pos)
	local map = workspace:FindFirstChild("Map")
	if not map then return Color3.fromRGB(110, 110, 110), Enum.Material.Slate end
	groundParams.FilterDescendantsInstances = { map }
	local r = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -10, 0), groundParams)
	if r and r.Instance then return r.Instance.Color, r.Material end
	return Color3.fromRGB(110, 110, 110), Enum.Material.Slate
end
FX.groundColor = groundColor

function FX.crater(pos, r, color, life)
	life = life or 5
	local gc, gm = groundColor(pos)
	if gm == Enum.Material.Grass or gm == Enum.Material.LeafyGrass then gm = Enum.Material.Ground end
	local rocks = {}
	local n = math.clamp(math.floor(r * 1.4), 8, 22)
	for i = 1, n do
		local ang = i / n * math.pi * 2 + rand(-0.15, 0.15)
		local dist = r * rand(0.75, 1.0)
		local s = r * rand(0.16, 0.3)
		local p = FX.part({ Color = gc:Lerp(Color3.new(0.25, 0.22, 0.2), rand(0.1, 0.4)), Material = gm, Size = Vector3.new(s * 1.3, s, s),
			CFrame = CFrame.new(pos + Vector3.new(math.cos(ang) * dist, -s * 0.9, math.sin(ang) * dist))
				* CFrame.Angles(0, -ang, 0) * CFrame.Angles(0, 0, math.rad(rand(25, 55))),
			Transparency = 0, CastShadow = true })
		rocks[#rocks + 1] = { p = p, up = s * 0.9 }
	end
	local scorch = FX.part({ Shape = Enum.PartType.Cylinder, Color = Color3.new(0.06, 0.05, 0.05), Material = Enum.Material.Slate,
		Size = Vector3.new(0.15, r * 1.6, r * 1.6), CFrame = CFrame.new(pos + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 0.2 })
	local glow = color and FX.part({ Shape = Enum.PartType.Cylinder, Color = color, Size = Vector3.new(0.12, r * 0.9, r * 0.9),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 0.2 })
	FX.run(0.18, function(t)
		for _, x in ipairs(rocks) do
			x.p.CFrame = x.p.CFrame + Vector3.new(0, x.up * (1 / 0.18) * (1 / 60), 0)
		end
	end)
	FX.emit(pos + Vector3.new(0, 1, 0), { tex = "smoke", color = gc:Lerp(Color3.new(0.8, 0.78, 0.74), 0.5), n = math.floor(10 + r), speed = r * 1.6,
		life = 0.9, size = NumberSequence.new({ NumberSequenceKeypoint.new(0, r * 0.25), NumberSequenceKeypoint.new(1, r * 0.6) }),
		transp = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }), light = 0, lightInf = 1, drag = 4,
		accel = Vector3.new(0, 4, 0) })
	FX.debris(pos, math.floor(6 + r * 0.6), gc, gm, r * 1.6)
	task.delay(life, function()
		FX.run(1, function(t)
			for _, x in ipairs(rocks) do x.p.Transparency = t end
			scorch.Transparency = 0.2 + 0.8 * t
			if glow then glow.Transparency = 0.2 + 0.8 * t end
		end, function()
			for _, x in ipairs(rocks) do x.p:Destroy() end
			kill(scorch, glow)
		end)
	end)
	if glow then
		FX.run(1.2, function(t) glow.Transparency = 0.2 + 0.8 * t end)
	end
end

-- обломки: летят с силой и катятся по земле
function FX.debris(pos, n, color, material, speed, sizeMul)
	n = math.max(1, math.floor(n * FX.quality + 0.5))
	for _ = 1, n do
		local s = rand(0.35, 1.1) * (sizeMul or 1)
		local p = FX.part({ Color = color, Material = material or Enum.Material.Slate, Size = Vector3.new(s, s * rand(0.6, 1), s * rand(0.6, 1)),
			CFrame = CFrame.new(pos + Vector3.new(rand(-1, 1), rand(0.5, 1.5), rand(-1, 1))), CastShadow = true })
		local v = Vector3.new(rand(-1, 1), rand(0.6, 1.4), rand(-1, 1)).Unit * (speed or 30) * rand(0.5, 1)
		local spin = Vector3.new(rand(-8, 8), rand(-8, 8), rand(-8, 8))
		local cur = p.CFrame
		local floorY = pos.Y
		FX.run(rand(1.4, 2.2), function(t, dt)
			v = v + Vector3.new(0, -110, 0) * dt
			local np = cur.Position + v * dt
			if np.Y < floorY + s / 2 then
				np = Vector3.new(np.X, floorY + s / 2, np.Z)
				v = Vector3.new(v.X * 0.6, -v.Y * 0.3, v.Z * 0.6)
				spin = spin * 0.6
			end
			cur = CFrame.new(np) * (cur - cur.Position) * CFrame.Angles(spin.X * dt, spin.Y * dt, spin.Z * dt)
			p.CFrame = cur
			if t > 0.7 then p.Transparency = (t - 0.7) / 0.3 end
		end, function() p:Destroy() end)
	end
end

-- круг-предупреждение на земле
function FX.warn(pos, r, color, dur)
	local disc = FX.part({ Shape = Enum.PartType.Cylinder, Color = color, Size = Vector3.new(0.1, r * 2, r * 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 0.75 })
	local edge = FX.part({ Shape = Enum.PartType.Cylinder, Color = color, Size = Vector3.new(0.14, r * 2, r * 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 0.9 })
	FX.run(dur, function(t)
		disc.Transparency = 0.82 - 0.12 * math.abs(math.sin(t * dur * 12))
		local k = math.max(0.05, t)
		edge.Size = Vector3.new(0.14, r * 2 * k, r * 2 * k)
		edge.Transparency = 0.45
	end, function() kill(disc, edge) end)
end

-- столб (огонь, тень)
function FX.pillar(pos, r, h, color, dur, color2)
	local outer = FX.part({ Shape = Enum.PartType.Cylinder, Color = color, Size = Vector3.new(0.1, r * 2, r * 2),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 0.2 })
	local core = FX.part({ Shape = Enum.PartType.Cylinder, Color = color2 or WHITE, Size = Vector3.new(0.1, r, r),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 0 })
	FX.light(pos + Vector3.new(0, 4, 0), color, r * 6, 6, dur)
	FX.run(dur, function(t)
		local grow = easeOut(math.min(1, t * 4), 3)
		local hh = h * grow
		local w = 1 - math.max(0, (t - 0.5) / 0.5)
		outer.Size = Vector3.new(hh, r * 2 * w, r * 2 * w)
		outer.CFrame = CFrame.new(pos + Vector3.new(0, hh / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		core.Size = Vector3.new(hh, r * w, r * w)
		core.CFrame = outer.CFrame
		outer.Transparency = 0.2 + 0.8 * (1 - w)
		core.Transparency = 1 - w
	end, function() kill(outer, core) end)
end

-- текст над точкой
function FX.text(pos, text, color, size, dur)
	local p = FX.part({ Size = Vector3.one * 0.1, Transparency = 1, CFrame = CFrame.new(pos) })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(300, 60)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 250
	bb.Parent = p
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Text = text
	l.TextColor3 = color or WHITE
	l.TextStrokeTransparency = 0.2
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
	l.TextScaled = true
	l.Parent = bb
	dur = dur or 0.9
	FX.run(dur, function(t)
		local pop = t < 0.15 and (0.6 + t / 0.15 * 0.5) or (1.1 - math.min(0.1, (t - 0.15)))
		bb.Size = UDim2.fromOffset(300 * (size or 1) * pop, 60 * (size or 1) * pop)
		bb.StudsOffsetWorldSpace = Vector3.new(0, t * 2.5, 0)
		l.TextTransparency = math.max(0, (t - 0.6) / 0.4)
		l.TextStrokeTransparency = 0.2 + 0.8 * math.max(0, (t - 0.6) / 0.4)
	end, function() p:Destroy() end)
end

-- вспышка экрана
function FX.screenFlash(gui, color, dur, alpha)
	if not gui then return end
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 1 - (alpha or 0.5)
	f.BorderSizePixel = 0
	f.ZIndex = 50
	f.Parent = gui
	FX.run(dur, function(t) f.BackgroundTransparency = 1 - (alpha or 0.5) * (1 - t) end, function() f:Destroy() end)
end

---------------------------------------------------------------- составные эффекты
-- удар в точку: вспышка + искры (+ кольцо, если тяжёлый)
function FX.impact(pos, color, heavy, color2)
	FX.ball(pos, color2 or WHITE, 0.4, heavy and 3.2 or 1.8, heavy and 0.22 or 0.15, 0.05)
	FX.ball(pos, color, 0.6, heavy and 4.5 or 2.6, heavy and 0.3 or 0.2, 0.35)
	FX.sparks(pos, color, heavy and 14 or 8, heavy and 55 or 38, { c2 = color2 or WHITE, size = heavy and 0.28 or 0.2, life = 0.18 })
	FX.light(pos, color, heavy and 22 or 12, heavy and 5 or 3, 0.2)
	if heavy then
		FX.ring(pos, color, 1, 7, 0.35, { cf = CFrame.lookAt(pos, workspace.CurrentCamera.CFrame.Position) * CFrame.Angles(math.rad(90), 0, 0), w = 0.5, h = 0.2, n = 22 })
	end
end

-- взрыв
function FX.explosion(pos, r, color, color2)
	FX.ball(pos, Color3.new(1, 1, 0.95), r * 0.15, r * 0.6, 0.18, 0)
	FX.ball(pos, color2 or color, r * 0.3, r * 0.95, 0.4, 0.15)
	FX.ball(pos, color, r * 0.4, r * 1.15, 0.6, 0.45)
	FX.ring(pos - Vector3.new(0, 2.5, 0), color, r * 0.3, r * 1.3, 0.5, { w = 1.2, h = 0.4 })
	FX.light(pos, color, r * 4, 8, 0.6)
	FX.sparks(pos, color2 or color, 18, r * 4, { size = 0.35, life = 0.35, g = 40, c2 = color })
	FX.emit(pos, { tex = "smoke", color = Color3.fromRGB(60, 55, 52), color2 = Color3.fromRGB(30, 28, 28), n = math.floor(8 + r * 0.6), speed = r * 1.2,
		life = 1.1, size = NumberSequence.new({ NumberSequenceKeypoint.new(0, r * 0.3), NumberSequenceKeypoint.new(1, r * 0.7) }),
		transp = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }), light = 0, lightInf = 1, drag = 3,
		accel = Vector3.new(0, 6, 0) })
end

-- водоворот (притяжение, колодец)
function FX.vortex(pos, r, color, dur, color2)
	local arms = {}
	local nArms, nSeg = 4, 9
	for i = 1, nArms do
		for j = 1, nSeg do
			arms[#arms + 1] = { p = FX.part({ Color = (j % 2 == 0 and color2) or color, Size = Vector3.new(0.4, 0.4, 1.6), Transparency = 0.2 }), i = i, j = j }
		end
	end
	local core = FX.part({ Shape = Enum.PartType.Ball, Color = Color3.new(0.02, 0.02, 0.05), Size = Vector3.one * 2, CFrame = CFrame.new(pos),
		Material = Enum.Material.SmoothPlastic })
	local halo = FX.part({ Shape = Enum.PartType.Ball, Color = color, Size = Vector3.one * 3, CFrame = CFrame.new(pos), Transparency = 0.5 })
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = r * 1.6
	l.Brightness = 4
	l.Parent = halo
	FX.run(dur, function(t)
		local spin = t * dur * 7
		local appear = math.min(1, t * 6)
		local vanish = 1 - math.max(0, (t - 0.85) / 0.15)
		for _, a in ipairs(arms) do
			local f = a.j / nSeg
			local ang = spin + a.i / nArms * math.pi * 2 + f * 2.4
			local rad = r * f * appear * vanish
			local p0 = pos + Vector3.new(math.cos(ang) * rad, math.sin(spin * 0.5 + f * 3) * 0.6, math.sin(ang) * rad)
			local tangent = Vector3.new(-math.sin(ang), 0, math.cos(ang))
			a.p.CFrame = CFrame.lookAt(p0, p0 + tangent)
			a.p.Size = Vector3.new(0.45, 0.45, 1.2 + f * 2.5)
			a.p.Transparency = 0.15 + 0.6 * (1 - f) + 0.25 * (1 - vanish)
		end
		local s = (2 + math.sin(t * dur * 20) * 0.3) * appear * vanish
		core.Size = Vector3.one * math.max(0.1, s)
		halo.Size = Vector3.one * math.max(0.1, s * 1.8)
	end, function()
		for _, a in ipairs(arms) do a.p:Destroy() end
		kill(core, halo)
	end)
	FX.emit(pos, { tex = "spark", color = color, n = 20, speed = -r * 1.5, life = 0.6, spread = 180 })
end

-- купол территории из панелей (видно и изнутри, и снаружи)
function FX.dome(center, r, style, dur)
	local colors = {
		void = { Color3.fromRGB(16, 14, 40), Color3.fromRGB(110, 70, 230), Color3.fromRGB(92, 214, 255) },
		blade = { Color3.fromRGB(30, 4, 8), Color3.fromRGB(230, 32, 56), Color3.fromRGB(255, 220, 220) },
		abyss = { Color3.fromRGB(8, 6, 14), Color3.fromRGB(110, 60, 200), Color3.fromRGB(60, 100, 255) },
	}
	local c = colors[style] or colors.void
	local model = Instance.new("Model")
	model.Name = "Dome"
	model.Parent = folder
	local panels = {}
	local rings, perRing = 7, 22
	for i = 0, rings - 1 do
		local lat0 = i / rings * math.pi / 2
		local lat1 = (i + 1) / rings * math.pi / 2
		local latM = (lat0 + lat1) / 2
		local ringR = math.cos(latM) * r
		local n = math.max(6, math.floor(perRing * math.cos(latM) + 0.5))
		for j = 0, n - 1 do
			local lon = (j + 0.5) / n * math.pi * 2
			local pos = center + Vector3.new(math.cos(lon) * ringR, math.sin(latM) * r, math.sin(lon) * ringR)
			local w = 2 * math.pi * ringR / n * 1.06
			local hgt = (lat1 - lat0) * r * 1.06
			local p = FX.part({ Color = (j + i) % 5 == 0 and c[2] or c[1], Material = Enum.Material.Glass, Size = Vector3.new(w, hgt, 0.4),
				CFrame = CFrame.lookAt(pos, center + Vector3.new(0, math.sin(latM) * r * 0.2, 0)) * CFrame.Angles(0, 0, 0),
				Transparency = 1, Parent = model })
			panels[#panels + 1] = { p = p, row = i, glow = (j + i) % 5 == 0 }
		end
	end
	-- светящийся обод у земли
	local rim = {}
	for k = 1, 36 do
		local ang = k / 36 * math.pi * 2
		local pos = center + Vector3.new(math.cos(ang) * r, 0.4, math.sin(ang) * r)
		rim[k] = FX.part({ Color = c[2], Size = Vector3.new(1.2, 0.8, 2 * math.pi * r / 36 * 1.1), CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(ang), 0, math.cos(ang))),
			Transparency = 0.2, Parent = model })
	end
	local floor = FX.part({ Shape = Enum.PartType.Cylinder, Color = c[1], Material = Enum.Material.Glass, Size = Vector3.new(0.2, r * 2, r * 2),
		CFrame = CFrame.new(center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 1, Parent = model })
	local build = 0.7
	FX.run(dur, function(t)
		local el = t * dur
		local shown = math.min(1, el / build)
		local closing = math.max(0, (el - (dur - 0.5)) / 0.5)
		for _, x in ipairs(panels) do
			local rowShown = shown * rings - x.row
			local base = x.glow and 0.35 or 0.25
			if rowShown <= 0 then x.p.Transparency = 1
			else x.p.Transparency = math.clamp(1 - math.min(1, rowShown) * (1 - base) + closing * (1 - base), base, 1) end
		end
		for _, p in ipairs(rim) do p.Transparency = 0.2 + 0.8 * closing end
		floor.Transparency = math.clamp(0.55 + (1 - shown) * 0.45 + closing * 0.45, 0.55, 1)
	end, function() model:Destroy() end)
	return model, c
end

return FX
