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


-- энергетический луч: белое ядро, цвет, ореол; по нему бегут яркие штрихи
function FX.energyBeam(color, width)
	local a0, a1 = FX.att(), FX.att()
	local spec = {
		{ C.white, 0.3, 0, 8 },
		{ color:Lerp(C.white, 0.55), 0.62, 0.05, 5 },
		{ color, 1.25, 0.3, 3 },
		{ color, 2.3, 0.72, 2 },
	}
	local layers = {}
	for i, sp in ipairs(spec) do
		layers[i] = { b = FX.beam(a0, a1, sp[1], 1, 1, { alpha = NumberSequence.new(sp[3]), brightness = sp[4] }), k = sp[2] }
	end
	local obj = { width = width, from = V3(), to = V3() }
	function obj.set(from, to, w)
		a0.Position = from
		a1.Position = to
		obj.from, obj.to = from, to
		w = w or obj.width
		for _, L in ipairs(layers) do
			L.b.Width0 = w * L.k
			L.b.Width1 = w * L.k
		end
	end
	local acc = 0
	addUpdater(function(dt)
		acc = acc + dt * 22
		local d = obj.to - obj.from
		local L = d.Magnitude
		if L < 1 then
			return true
		end
		local dir = d / L
		while acc >= 1 do
			acc = acc - 1
			local side = dir:Cross(V3(0, 1, 0))
			if side.Magnitude < 0.1 then
				side = V3(1, 0, 0)
			end
			local off = side.Unit * rr(-0.35, 0.35) * obj.width + V3(0, rr(-0.35, 0.35) * obj.width, 0)
			FX.streak(obj.from + dir * rr(0, L * 0.3) + off, dir, rr(4, 9), rr(70, 120), L / 95, color:Lerp(C.white, 0.8), obj.width * rr(0.12, 0.25), 6)
		end
		return true
	end)
	return obj
end

-- Аниме-вспышка: колючая звезда из широких сужающихся лучей (без кругов).
-- Лучи смотрят в камеру, плавно дышат и медленно вращаются.
function FX.flare(pos, radius, color, o)
	o = o or {}
	local c0 = FX.att(pos)
	local spikes = {}
	local function layer(n, k, col, br, alpha)
		for i = 1, n do
			local a1 = FX.att(pos)
			local b = FX.beam(c0, a1, ColorSequence.new(C.white, col), 1, 0,
				{ brightness = br, alpha = NS({ { 0, alpha }, { 0.7, alpha + 0.15 }, { 1, 1 } }) })
			spikes[#spikes + 1] = { a = a1, b = b, ang = (i / n) * math.pi * 2 + rr(-0.2, 0.2), len = rr(0.75, 1.3) * k,
				w = rr(0.55, 0.85) * k, ph = rr(0, 6.28), sp = rr(2, 5), k = k }
		end
	end
	layer(o.points or 9, 1.0, color, 3, o.alpha or 0.1)
	layer(7, 0.55, color:Lerp(C.white, 0.6), 5, 0)
	local obj = { pos = pos, radius = radius, spin = o.spin or 0.4, visible = 1 }
	function obj.set(p, r, k)
		if p then
			obj.pos = p
		end
		if r then
			obj.radius = r
		end
		if k then
			obj.visible = k
		end
	end
	addUpdater(function()
		if not c0.Parent then
			return false
		end
		local t = songT
		local cp = camCF.Position
		local look = (obj.pos - cp)
		if look.Magnitude < 0.01 then
			return true
		end
		look = look.Unit
		local right = look:Cross(V3(0, 1, 0))
		if right.Magnitude < 0.05 then
			right = V3(1, 0, 0)
		end
		right = right.Unit
		local up = right:Cross(look).Unit
		c0.Position = obj.pos
		for _, sk in ipairs(spikes) do
			local a = sk.ang + t * obj.spin
			local L = obj.radius * sk.len * (0.8 + 0.2 * sin(t * sk.sp + sk.ph)) * obj.visible
			sk.a.Position = obj.pos + (right * cos(a) + up * sin(a)) * L
			sk.b.Width0 = obj.radius * sk.w * obj.visible
		end
		return true
	end)
	return obj
end

-- блик-звёздочка: четыре тонких луча крестом
function FX.twinkle(pos, size, color, life)
	local c0 = FX.att(pos)
	local arms = {}
	for i = 1, 4 do
		local a1 = FX.att(pos)
		arms[i] = { a = a1, b = FX.beam(c0, a1, ColorSequence.new(C.white, color), size * 0.18, 0, { brightness = 5 }) }
	end
	local age, ph = 0, rr(0, 6)
	addUpdater(function(dt)
		age = age + dt
		if life and age > life then
			c0:Destroy()
			for _, ar in ipairs(arms) do
				ar.a:Destroy()
				ar.b:Destroy()
			end
			return false
		end
		local k = 0.6 + 0.4 * sin(age * 9 + ph)
		if life then
			k = k * sin(math.pi * clamp01(age / life))
		end
		local cp = camCF.Position
		local look = (pos - cp).Unit
		local right = look:Cross(V3(0, 1, 0)).Unit
		local up = right:Cross(look).Unit
		local dirs = { right, -right, up, -up }
		for i, ar in ipairs(arms) do
			local L = size * k
			if i > 2 then
				L = L * 1.4
			end
			ar.a.Position = pos + dirs[i] * L
		end
		return true
	end)
end

-- искра-штрих: летит по скорости и сжимается к концу жизни
function FX.spark(pos, vel, color, len, life, width)
	local p = newPart(Shot.folder, V3(width or 0.12, width or 0.12, len), color, nil, { neon = true })
	local age = 0
	addUpdater(function(dt)
		age = age + dt
		if age >= life or not p.Parent then
			p:Destroy()
			return false
		end
		vel = vel * (1 - math.min(0.9, 2.5 * dt))
		pos = pos + vel * dt
		local k = 1 - age / life
		local L = len * k + 0.05
		local v = vel
		if v.Magnitude < 0.01 then
			v = V3(0, 1, 0)
		end
		p.Size = V3((width or 0.12) * (0.4 + 0.6 * k), (width or 0.12) * (0.4 + 0.6 * k), L)
		p.CFrame = CFrame.lookAt(pos, pos + v)
		return true
	end)
	return p
end

function FX.sparkBurst(pos, n, colors, speed, len, life)
	for _ = 1, n do
		local d = randUnit()
		FX.spark(pos + d * rr(0, 1), d * speed * rr(0.5, 1), pick(colors), len * rr(0.6, 1.3), life * rr(0.6, 1.2))
	end
end

-- Мультяшный дым: белые клубы с тенью снизу и контуром. Растут, плывут и «лопаются».
function FX.puff(pos, size, life, vel, o)
	o = o or {}
	local base = o.color or RGB(246, 248, 255)
	local shade = o.shade or RGB(196, 210, 238)
	local balls = {}
	for i = 1, (o.count or 5) do
		local off = V3(rr(-0.5, 0.5), rr(-0.25, 0.35), rr(-0.5, 0.5)) * size
		local s = size * rr(0.45, 0.75)
		local top = newPart(Shot.clouds, V3(s, s * 0.85, s), base, CF(pos + off), { shape = "ball" })
		local bot = newPart(Shot.clouds, V3(s * 0.92, s * 0.6, s * 0.92), shade, CF(pos + off - V3(0, s * 0.18, 0)), { shape = "ball" })
		balls[i] = { top = top, bot = bot, off = off, s = s }
	end
	local age = 0
	vel = vel or V3()
	addUpdater(function(dt)
		age = age + dt
		if age >= life then
			for _, b in ipairs(balls) do
				b.top:Destroy()
				b.bot:Destroy()
			end
			return false
		end
		local a = age / life
		local k
		if a < 0.3 then
			k = 0.35 + 0.65 * easeOut(a / 0.3)
		elseif a > 0.75 then
			k = 1 - easeIn((a - 0.75) / 0.25)
		else
			k = 1
		end
		k = math.max(k, 0.02)
		pos = pos + vel * dt
		for _, b in ipairs(balls) do
			local s = b.s * k * (1 + 0.25 * a)
			local c = pos + b.off * (1 + 0.4 * a)
			b.top.Size = V3(s, s * 0.85, s)
			b.top.CFrame = CF(c)
			b.bot.Size = V3(s * 0.92, s * 0.6, s * 0.92)
			b.bot.CFrame = CF(c - V3(0, s * 0.18, 0))
		end
		return true
	end)
end

-- аниме-пламя: языки из сужающихся лучей, колышутся вверх
function FX.flame(base, height, color, n)
	local tongues = {}
	for i = 1, (n or 7) do
		local a0, a1 = FX.att(base), FX.att(base)
		local b = FX.beam(a0, a1, ColorSequence.new(C.white, color), 1, 0,
			{ brightness = 5, alpha = NS({ { 0, 0.05 }, { 0.6, 0.2 }, { 1, 1 } }) })
		tongues[i] = { a0 = a0, a1 = a1, b = b, off = V3(rr(-1, 1), 0, rr(-1, 1)) * height * 0.22, h = rr(0.55, 1.1), ph = rr(0, 6), sp = rr(6, 11) }
	end
	local obj = { base = base, height = height, k = 1 }
	addUpdater(function()
		local t = songT
		for _, tg in ipairs(tongues) do
			local h = obj.height * tg.h * (0.7 + 0.3 * sin(t * tg.sp + tg.ph)) * obj.k
			local sway = V3(sin(t * 3 + tg.ph), 0, cos(t * 2.5 + tg.ph)) * h * 0.18
			tg.a0.Position = obj.base + tg.off
			tg.a1.Position = obj.base + tg.off + V3(0, h, 0) + sway
			tg.b.Width0 = obj.height * 0.35 * obj.k
			tg.b.Enabled = obj.k > 0.02
		end
		return true
	end)
	return obj
end

-- рваное кольцо ударной волны из лучей (в плоскости экрана)
function FX.ring(pos, color, r0, r1, life, width)
	local n = 22
	local pts = {}
	for i = 0, n do
		pts[i] = FX.att(pos)
	end
	local beams = {}
	for i = 1, n do
		beams[i] = FX.beam(pts[i - 1], pts[i], color, width or 0.6, width or 0.6, { brightness = 4 })
	end
	local jit = {}
	for i = 0, n - 1 do
		jit[i] = rr(0.85, 1.15)
	end
	jit[n] = jit[0]
	local age = 0
	addUpdater(function(dt)
		age = age + dt
		local k = age / life
		if k >= 1 then
			for _, b in ipairs(beams) do
				b:Destroy()
			end
			for i = 0, n do
				pts[i]:Destroy()
			end
			return false
		end
		local look = (pos - camCF.Position).Unit
		local right = look:Cross(V3(0, 1, 0)).Unit
		local up = right:Cross(look).Unit
		local r = lerp(r0, r1, easeOut(k))
		for i = 0, n do
			local a = i / n * math.pi * 2
			pts[i].Position = pos + (right * cos(a) + up * sin(a)) * r * jit[i]
		end
		local tr = NumberSequence.new(k)
		for _, b in ipairs(beams) do
			b.Transparency = tr
			b.Width0 = (width or 0.6) * (1 - k * 0.6)
			b.Width1 = b.Width0
		end
		return true
	end)
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
