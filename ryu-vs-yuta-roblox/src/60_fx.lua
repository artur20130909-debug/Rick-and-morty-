----------------------------------------------------------------------
-- ЭФФЕКТЫ: лучи Beam, мягкие свечения, частицы, молнии, обломки с контуром
----------------------------------------------------------------------

local Shot = { folder = nil, anchor = nil, debris = nil, t0 = 0, update = nil, blur = 0 }
local updaters = {}
local function addUpdater(fn)
	updaters[#updaters + 1] = fn
end

local function uiFrame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function gradient(parent, colors, alphas, rotation)
	local g = Instance.new("UIGradient")
	local ck = {}
	for i, c in ipairs(colors) do
		ck[i] = ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c)
	end
	g.Color = ColorSequence.new(ck)
	if alphas then
		local nk = {}
		for i, a in ipairs(alphas) do
			nk[i] = NumberSequenceKeypoint.new((i - 1) / (#alphas - 1), a)
		end
		g.Transparency = NumberSequence.new(nk)
	end
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
end

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(r or 0.5, 0)
	c.Parent = parent
	return c
end

local FX = {}

function FX.att(pos)
	local a = Instance.new("Attachment")
	a.Position = pos or V3()
	a.Parent = Shot.anchor
	return a
end

function FX.beam(a0, a1, color, w0, w1, o)
	o = o or {}
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	if typeof(color) == "ColorSequence" then
		b.Color = color
	else
		b.Color = ColorSequence.new(color)
	end
	b.Width0 = w0
	b.Width1 = w1 or w0
	b.FaceCamera = true
	b.LightEmission = o.emission or 1
	b.LightInfluence = 0
	b.Brightness = o.brightness or 2
	b.Transparency = o.alpha or NumberSequence.new(0)
	b.Segments = o.segments or 1
	b.ZOffset = o.z or 0
	if o.texture then
		b.Texture = o.texture
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = o.texLen or 4
		b.TextureSpeed = o.texSpeed or 2
	end
	b.Parent = Shot.anchor
	return b
end

-- энергетический луч: белое ядро, цвет, мягкий ореол и бегущие искры
function FX.energyBeam(color, width)
	local a0, a1 = FX.att(), FX.att()
	local spec = {
		{ C.white, 0.3, 0, 8 },
		{ color:Lerp(C.white, 0.55), 0.62, 0.05, 5 },
		{ color, 1.25, 0.35, 3 },
		{ color, 2.4, 0.76, 2 },
		{ color, 4.4, 0.91, 1.5 },
	}
	local layers = {}
	for i, s in ipairs(spec) do
		layers[i] = { b = FX.beam(a0, a1, s[1], 1, 1, { alpha = NumberSequence.new(s[3]), brightness = s[4] }), k = s[2] }
	end
	layers[#layers + 1] = {
		b = FX.beam(a0, a1, color:Lerp(C.white, 0.7), 1, 1, { alpha = NumberSequence.new(0.3), brightness = 4, texture = TEX.spark, texLen = 5, texSpeed = 7 }),
		k = 1.1,
	}
	local obj = { width = width }
	function obj.set(from, to, w)
		a0.Position = from
		a1.Position = to
		w = w or obj.width
		for _, L in ipairs(layers) do
			L.b.Width0 = w * L.k
			L.b.Width1 = w * L.k
		end
	end
	return obj
end

-- Мягкое круглое свечение без «ступенек»: 28 тонких кругов, прозрачность каждого
-- подобрана так, что вместе они дают плавный спад яркости от центра к краю.
local GLOW_RINGS = 28
local function glowAlphas(A)
	if A > 0.97 then
		A = 0.97
	end
	local out = {}
	local prevT = 1
	for i = 1, GLOW_RINGS do
		local r = 1 - (i - 1) / GLOW_RINGS
		local T = 1 - A * (1 - r) ^ 2 -- пропускание внутри круга i
		if T < 0.03 then
			T = 0.03
		end
		local a = 1 - T / prevT
		if a < 0 then
			a = 0
		end
		out[i] = a
		prevT = T
	end
	-- самый внешний круг почти невидим, чтобы край был мягким
	out[1] = math.min(out[1], 0.01)
	return out
end

function FX.glow(pos, size, color, strength, brightness)
	local holder = newPart(Shot.folder, V3(0.2, 0.2, 0.2), C.white, CF(pos), { alpha = 1 })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(size, size)
	bb.LightInfluence = 0
	bb.Brightness = brightness or 2
	bb.AlwaysOnTop = false
	bb.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	bb.Parent = holder
	-- strength как раньше (прозрачность одного из 12 кругов) → яркость центра
	local A = 1 - (1 - (strength or 0.14)) ^ 12
	local alphas = glowAlphas(A)
	local rings = {}
	for i = 1, GLOW_RINGS do
		local f = 1 - (i - 1) / GLOW_RINGS
		local r = uiFrame(bb, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(f, f),
			BackgroundColor3 = color:Lerp(C.white, (1 - f) ^ 1.6),
			BackgroundTransparency = 1 - alphas[i],
			ZIndex = i,
		})
		corner(r, 0.5)
		rings[i] = r
	end
	local obj = { holder = holder, bb = bb }
	function obj.set(p, s, k)
		if p then
			holder.CFrame = CF(p)
		end
		if s then
			bb.Size = UDim2.fromScale(s, s)
		end
		if k then
			local al = glowAlphas(math.min(0.97, A * k))
			for i, r in ipairs(rings) do
				r.BackgroundTransparency = 1 - al[i]
			end
		end
	end
	return obj
end

-- сужающиеся лучи-вспышки из центра (аниме-звезда), двигаются плавно
function FX.rays(center, n, colors, minL, maxL, width, o)
	o = o or {}
	local c0 = FX.att(center)
	local rays = {}
	local fade = NS({ { 0, 0.05 }, { 0.65, 0.25 }, { 1, 1 } })
	for i = 1, n do
		local a1 = FX.att(center)
		local col = colors[(i - 1) % #colors + 1]
		local startCol = C.white
		if o.colorStart then
			startCol = col:Lerp(C.white, 0.25)
		end
		local s0 = c0
		if (o.start or 0) > 0 then
			s0 = FX.att(center)
		end
		local b = FX.beam(s0, a1, ColorSequence.new(startCol, col), width, 0, { alpha = fade, brightness = o.brightness or 4 })
		rays[i] = { a = a1, s = s0, b = b, dir = randUnit(), len = rr(minL, maxL), w = rr(0.45, 1) * width, ph = rr(0, 6.28), sp = rr(3, 9) }
	end
	local obj = { center = center, scale = 1, bias = o.bias, start = o.start or 0 }
	function obj.reroll(frac)
		for _, r in ipairs(rays) do
			if rng:NextNumber() < (frac or 0.3) then
				local d = randUnit()
				if obj.bias then
					d = (d + obj.bias)
					if d.Magnitude < 0.05 then
						d = obj.bias
					end
					d = d.Unit
				end
				r.dir = d
				r.len = rr(minL, maxL)
			end
		end
	end
	function obj.update(t)
		c0.Position = obj.center
		for _, r in ipairs(rays) do
			local L = r.len * obj.scale * (0.6 + 0.4 * sin(t * r.sp + r.ph))
			r.a.Position = obj.center + r.dir * L
			r.b.Width0 = r.w * obj.scale
			if obj.start > 0 then
				r.s.Position = obj.center + r.dir * obj.start * obj.scale
			end
		end
	end
	if obj.bias then
		obj.reroll(1)
	end
	obj.update(0)
	return obj
end

-- частицы на встроенных текстурах Roblox
function FX.emitter(pos, box, p)
	local holder = newPart(Shot.folder, box or V3(1, 1, 1), C.white, CF(pos), { alpha = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Texture = p.texture or TEX.spark
	e.Rate = p.rate or 0
	e.Lifetime = NumberRange.new(p.life[1], p.life[2])
	e.Speed = NumberRange.new(p.speed[1], p.speed[2])
	e.SpreadAngle = Vector2.new(p.spread or 180, p.spread or 180)
	e.Size = p.size
	e.Transparency = p.alpha or NS({ { 0, 0 }, { 1, 1 } })
	if typeof(p.color) == "ColorSequence" then
		e.Color = p.color
	else
		e.Color = ColorSequence.new(p.color or C.white)
	end
	e.LightEmission = p.emission or 1
	e.LightInfluence = 0
	e.Brightness = p.brightness or 2
	e.Drag = p.drag or 0
	e.Acceleration = p.accel or V3()
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-(p.rot or 40), p.rot or 40)
	e.ZOffset = p.z or 0
	if p.sphere then
		e.Shape = Enum.ParticleEmitterShape.Sphere
	else
		e.Shape = Enum.ParticleEmitterShape.Box
	end
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = p.dir or Enum.NormalId.Top
	e.LockedToPart = p.locked or false
	e.Parent = holder
	if p.burst then
		e:Emit(p.burst)
	end
	return e, holder
end

-- искры во все стороны
function FX.sparks(pos, colors, rate, speed, size)
	return FX.emitter(pos, V3(1, 1, 1), {
		rate = rate, life = { 0.25, 0.6 }, speed = { speed * 0.5, speed }, drag = 4,
		size = NS({ { 0, size or 0.5 }, { 1, 0 } }), alpha = NS({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }),
		color = CS({ { 0, colors[1] }, { 1, colors[2] or colors[1] } }), brightness = 4, rot = 0,
	})
end

-- мягкий дым
function FX.smoke(pos, box, color, rate, size, life, speed, o)
	o = o or {}
	return FX.emitter(pos, box, {
		texture = TEX.smoke, rate = rate, life = { life * 0.7, life }, speed = { speed * 0.4, speed },
		size = NS({ { 0, size * 0.55 }, { 1, size } }), alpha = o.alpha or NS({ { 0, 0.9 }, { 0.2, 0.45 }, { 1, 1 } }),
		color = color, emission = o.emission or 0, brightness = o.brightness or 1, rot = 25, spread = o.spread or 60,
		accel = o.accel, burst = o.burst, dir = o.dir,
	})
end

-- молния из лучей
function FX.bolt(color, width)
	local n = 8
	local pts, beams = {}, {}
	for i = 0, n do
		pts[i] = FX.att()
	end
	for i = 1, n do
		beams[#beams + 1] = FX.beam(pts[i - 1], pts[i], C.white, width, width, { brightness = 8 })
		beams[#beams + 1] = FX.beam(pts[i - 1], pts[i], color, width * 4, width * 4, { brightness = 3, alpha = NumberSequence.new(0.75) })
	end
	local obj = {}
	function obj.strike(a, b, jag)
		for i = 0, n do
			local p = a:Lerp(b, i / n)
			if i > 0 and i < n then
				p = p + randUnit() * jag
			end
			pts[i].Position = p
		end
	end
	function obj.show(on)
		for _, bm in ipairs(beams) do
			bm.Enabled = on
		end
	end
	return obj
end

-- кольцо-ударная волна (всегда смотрит в камеру)
function FX.ring(pos, color, size0, size1, life, thick)
	local holder = newPart(Shot.folder, V3(0.2, 0.2, 0.2), C.white, CF(pos), { alpha = 1 })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(size0, size0)
	bb.LightInfluence = 0
	bb.Brightness = 3
	bb.Parent = holder
	local f = uiFrame(bb, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	corner(f, 0.5)
	local st = Instance.new("UIStroke")
	st.Color = color
	st.Thickness = thick or 8
	st.Parent = f
	local age = 0
	addUpdater(function(dt)
		age = age + dt
		local k = age / life
		if k >= 1 then
			holder:Destroy()
			return false
		end
		local s = lerp(size0, size1, easeOut(k))
		bb.Size = UDim2.fromScale(s, s)
		st.Transparency = k
		st.Thickness = (thick or 8) * (1 - k * 0.7)
		return true
	end)
end

-- полоса, летящая по направлению dir (мягкие концы)
function FX.streak(from, dir, length, speed, life, color, width, brightness)
	local a0, a1 = FX.att(from), FX.att(from + dir * length)
	local b = FX.beam(a0, a1, color, width, width * 0.35, {
		alpha = NS({ { 0, 1 }, { 0.2, 0.05 }, { 0.75, 0.1 }, { 1, 1 } }), brightness = brightness or 3,
	})
	local age, pos = 0, from
	addUpdater(function(dt)
		age = age + dt
		if age >= life then
			b:Destroy()
			a0:Destroy()
			a1:Destroy()
			return false
		end
		pos = pos + dir * speed * dt
		a0.Position = pos
		a1.Position = pos + dir * length
		return true
	end)
end

-- летящий кусок: скорость, вращение, гравитация, исчезает к концу жизни
function FX.flyer(size, color, pos, vel, o)
	o = o or {}
	local p = newPart(o.parent or Shot.debris or Shot.folder, size, color, nil, o)
	local rot = ANG(rr(0, 6.28), rr(0, 6.28), rr(0, 6.28))
	local spin = V3(rr(-1, 1), rr(-1, 1), rr(-1, 1)) * (o.spin or 6)
	local life = o.life or 1.2
	local g = o.gravity or 0
	local drag = o.drag or 0
	local a0 = o.alpha or 0
	local age = 0
	p.CFrame = CF(pos) * rot
	addUpdater(function(dt)
		age = age + dt
		if age >= life or not p.Parent then
			p:Destroy()
			return false
		end
		vel = vel * (1 - math.min(0.9, drag * dt)) - V3(0, g * dt, 0)
		pos = pos + vel * dt
		rot = rot * ANG(spin.X * dt, spin.Y * dt, spin.Z * dt)
		p.CFrame = CF(pos) * rot
		p.Transparency = lerp(a0, 1, clamp01((age - life * 0.65) / (life * 0.35)))
		return true
	end)
	return p
end

-- задник с плавным градиентом (SurfaceGui на большой плите)
function FX.backdrop(cf, w, h, colors, rot)
	local p = newPart(Shot.folder, V3(w, h, 0.2), C.black, cf)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.Brightness = 1
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(1024, math.max(64, floor(1024 * h / w)))
	sg.Parent = p
	local f = uiFrame(sg, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white })
	gradient(f, colors, nil, rot or 90)
	return p, sg
end
