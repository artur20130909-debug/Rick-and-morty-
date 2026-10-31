--[[
	РЮ vs ЮТА — фан-анимация по «Магической битве» для Roblox
	Часть 1 (11 с) и часть 2 (15 с). Тайминг совпадает с клипами кадр в кадр.

	КАК ЗАПУСТИТЬ
	  • Открой RyuVsYuta.rbxlx в Roblox Studio и нажми Play (F5).
	    Или вставь весь этот код в LocalScript: StarterPlayer → StarterPlayerScripts.
	  • Поставь графику на максимум (10): так неон, контуры и частицы выглядят лучше всего.
	  • Включи запись экрана, потом нажми 1 (часть 1) или 2 (часть 2). R — повторить.

	Этот файл собирается из папки src командой: python3 build_place.py
]]

local CONFIG = {
	PART = 0, -- 0: выбрать часть на стартовом экране; 1 или 2: сразу эта часть
	DUMMY_MODE = false, -- true: Рю и Юта — серые манекены без одежды
	OUTLINES = true, -- чёрный аниме-контур
	AUTO_START = false, -- true: начать сразу после загрузки
}

-- Тайминг части 1, секунды
local T1 = {
	GLOW = 4.30, -- глаза засвечивает
	WHITE = 4.83, -- белая вспышка
	CLASH = 5.40, -- столкновение лучей
	TEAL = 6.98, -- бирюзовая волна
	CITY = 7.83, -- общий план города
	YUTA = 8.70, -- Юта и Рика
	RYU = 10.00, -- удар по Рю
	FIN = 11.17,
}

-- Тайминг части 2, секунды
local T2 = {
	LAUGH = 3.20, -- Рю смеётся
	ZOOM = 7.90, -- радужный рывок
	IMPACT1 = 8.55, -- чёрный кадр удара
	BURST = 8.65, -- жёлтый взрыв
	BLUR = 9.00, -- смаз с силуэтом Юты
	YUTARIKA = 9.20, -- Юта и Рика
	YUTACLOSE = 9.55, -- Юта крупно, рука Рики
	WHITE = 10.15, -- белая вспышка
	IMPACT2 = 10.30, -- чёрный кадр удара
	MIST = 10.40, -- белые полосы
	WIDE = 10.75, -- кратер в тумане
	LOW = 13.03, -- Рю снизу
	FIN = 15.39,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local V3, CF, ANG, RGB = Vector3.new, CFrame.new, CFrame.Angles, Color3.fromRGB
local rad, sin, cos, abs, sqrt, floor = math.rad, math.sin, math.cos, math.abs, math.sqrt, math.floor
local rng = Random.new(20261031)

local function clamp01(x)
	if x < 0 then
		return 0
	elseif x > 1 then
		return 1
	end
	return x
end
local function lerp(a, b, t)
	return a + (b - a) * t
end
local function smooth(t)
	t = clamp01(t)
	return t * t * (3 - 2 * t)
end
local function easeOut(t)
	t = clamp01(t)
	return 1 - (1 - t) * (1 - t) * (1 - t)
end
local function easeIn(t)
	t = clamp01(t)
	return t * t
end
local function rr(a, b)
	return rng:NextNumber(a, b)
end
local function pick(list)
	return list[rng:NextInteger(1, #list)]
end
local function noise(x, y)
	return math.noise(x, y) * 2
end
local function randUnit()
	local v = V3(rr(-1, 1), rr(-1, 1), rr(-1, 1))
	if v.Magnitude < 0.05 then
		return V3(0, 1, 0)
	end
	return v.Unit
end
-- NumberSequence из пар {время, значение}
local function NS(list)
	local k = {}
	for i, p in ipairs(list) do
		k[i] = NumberSequenceKeypoint.new(p[1], p[2])
	end
	return NumberSequence.new(k)
end
-- ColorSequence из пар {время, цвет}
local function CS(list)
	local k = {}
	for i, p in ipairs(list) do
		k[i] = ColorSequenceKeypoint.new(p[1], p[2])
	end
	return ColorSequence.new(k)
end

local C = {
	white = RGB(255, 255, 255),
	black = RGB(0, 0, 0),
	ink = RGB(14, 12, 18),
	pink = RGB(255, 60, 185),
	pinkHot = RGB(255, 135, 225),
	magenta = RGB(205, 45, 175),
	cyan = RGB(60, 225, 255),
	cyanDeep = RGB(30, 140, 255),
	blue = RGB(40, 90, 255),
	teal = RGB(70, 230, 205),
	yellow = RGB(255, 236, 140),
	gold = RGB(255, 205, 80),
	orange = RGB(255, 150, 60),
	red = RGB(205, 55, 40),
	rock = RGB(46, 52, 52),
	blood = RGB(160, 14, 28),
	skinYuta = RGB(247, 222, 202),
	skinRyu = RGB(232, 196, 162),
	hairYuta = RGB(26, 38, 46),
	hairRyu = RGB(16, 16, 22),
	rika = RGB(242, 242, 248),
	rikaTail = RGB(22, 22, 30),
	gum = RGB(130, 28, 42),
	mouth = RGB(42, 6, 16),
	tooth = RGB(252, 250, 244),
}

-- встроенные текстуры Roblox (есть в любом клиенте)
local TEX = {
	spark = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
}

----------------------------------------------------------------------
-- ДЕТАЛИ, ТРЕУГОЛЬНИКИ, «ХОЛСТ» ДЛЯ РИСОВАНИЯ ДЕТАЛЯМИ
----------------------------------------------------------------------

-- o: neon, wedge, shape ("ball" = эллипсоид, "cyl" = цилиндр по оси X), alpha, material
local function newPart(parent, size, color, cf, o)
	o = o or {}
	local p = Instance.new(o.wedge and "WedgePart" or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.neon then
		p.Material = Enum.Material.Neon
	else
		p.Material = o.material or Enum.Material.SmoothPlastic
	end
	if o.shape == "ball" then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	elseif o.shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Size = size
	p.Color = color
	p.Transparency = o.alpha or 0
	if cf then
		p.CFrame = cf
	end
	p.Parent = parent
	return p
end

-- аниме-контур (и лёгкая заливка) для модели
local function outline(model, fillColor, fillT, lineColor)
	if not CONFIG.OUTLINES then
		return nil
	end
	local h = Instance.new("Highlight")
	h.FillColor = fillColor or C.white
	h.FillTransparency = fillT or 1
	h.OutlineColor = lineColor or C.ink
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	return h
end

-- Треугольник из двух клиньев (способ EgoMoose). Возвращает две CFrame и размеры.
local function triCFs(a, b, c)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local n = ac:Cross(ab)
	if n.Magnitude < 1e-10 or bc.Magnitude < 1e-6 then
		return nil
	end
	local right = n.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = abs(ab:Dot(up))
	if height < 1e-5 then
		return nil
	end
	return CFrame.fromMatrix((a + b) / 2, right, up, back), height, abs(ab:Dot(back)),
		CFrame.fromMatrix((a + c) / 2, -right, up, -back), abs(ac:Dot(back))
end

-- maker(size, color, cf, o) создаёт деталь; тут — треугольник толщиной thick
local function makeTri(maker, a, b, c, color, thick, o)
	local cf1, h, d1, cf2, d2 = triCFs(a, b, c)
	if not cf1 then
		return
	end
	local opts = { wedge = true, neon = o and o.neon, alpha = o and o.alpha, material = o and o.material, tag = o and o.tag }
	if d1 > 1e-4 then
		maker(V3(thick, h, d1), color, cf1, opts)
	end
	if d2 > 1e-4 then
		maker(V3(thick, h, d2), color, cf2, opts)
	end
end

-- Холст: рисуем плоские фигуры на плоскости frame. x вправо (для зрителя), y вверх,
-- слои растут к зрителю. k — масштаб, d — шаг между слоями.
local Canvas = {}
Canvas.__index = Canvas

function Canvas.new(maker, frame, k, d)
	return setmetatable({ maker = maker, frame = frame, k = k or 1, d = d or 0.003 }, Canvas)
end

-- плоскость смотрит на зрителя своей стороной -Z, поэтому «вправо для зрителя» = -X
function Canvas:local3(p, layer)
	return V3(-p[1] * self.k, p[2] * self.k, -(layer or 0) * self.d)
end

function Canvas:ellipse(x, y, rx, ry, color, layer, rot, o)
	o = o or {}
	local cf = self.frame * CF(-x * self.k, y * self.k, -(layer or 0) * self.d) * ANG(0, 0, -(rot or 0))
	return self.maker(V3(2 * rx * self.k, 2 * ry * self.k, self.d * 0.6), color, cf,
		{ shape = "ball", neon = o.neon, alpha = o.alpha, tag = o.tag })
end

function Canvas:rect(x, y, w, h, color, layer, rot, o)
	o = o or {}
	local cf = self.frame * CF(-x * self.k, y * self.k, -(layer or 0) * self.d) * ANG(0, 0, -(rot or 0))
	return self.maker(V3(w * self.k, h * self.k, self.d * 0.6), color, cf, { neon = o.neon, alpha = o.alpha, tag = o.tag })
end

function Canvas:tri(a, b, c, color, layer, o)
	local frame, maker = self.frame, self.maker
	makeTri(function(size, col, cf, opts)
		return maker(size, col, frame * cf, opts)
	end, self:local3(a, layer), self:local3(b, layer), self:local3(c, layer), color, self.d * 0.6, o)
end

-- выпуклый (или «звёздный») многоугольник: веер из центра
function Canvas:poly(pts, color, layer, o)
	local cx, cy = 0, 0
	for _, p in ipairs(pts) do
		cx, cy = cx + p[1], cy + p[2]
	end
	local c = { cx / #pts, cy / #pts }
	for i = 1, #pts do
		self:tri(c, pts[i], pts[i % #pts + 1], color, layer, o)
	end
end

-- полоса от кривой до горизонтали yEdge (маски над и под веками)
function Canvas:band(pts, yEdge, color, layer, o)
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		self:tri(a, b, { b[1], yEdge }, color, layer, o)
		self:tri(a, { b[1], yEdge }, { a[1], yEdge }, color, layer, o)
	end
end

-- штрих по точкам с меняющейся толщиной (сужается к концам)
function Canvas:stroke(pts, widths, color, layer, o)
	local n = #pts
	local L, R = {}, {}
	for i = 1, n do
		local p = pts[i]
		local a = pts[math.max(1, i - 1)]
		local b = pts[math.min(n, i + 1)]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local len = sqrt(dx * dx + dy * dy)
		if len < 1e-9 then
			len = 1e-9
		end
		local nx, ny = -dy / len, dx / len
		local w = widths
		if type(widths) == "table" then
			w = widths[i]
		end
		L[i] = { p[1] + nx * w / 2, p[2] + ny * w / 2 }
		R[i] = { p[1] - nx * w / 2, p[2] - ny * w / 2 }
	end
	for i = 1, n - 1 do
		self:tri(L[i], L[i + 1], R[i + 1], color, layer, o)
		self:tri(L[i], R[i + 1], R[i], color, layer, o)
	end
end

-- зеркально по x (для второго глаза)
local function mirror(pts)
	local out = {}
	for i, p in ipairs(pts) do
		out[i] = { -p[1], p[2] }
	end
	return out
end

----------------------------------------------------------------------
-- СКЕЛЕТ: кости поворачиваются плавно, детали едут за костями
----------------------------------------------------------------------

local Rig = {}
Rig.__index = Rig

-- outlineMode: "model" — один контур на всю модель; "groups" — свой контур у каждой группы
function Rig.new(name, parent, outlineMode, fill)
	local self = setmetatable({}, Rig)
	self.model = Instance.new("Model")
	self.model.Name = name
	self.model.Parent = parent
	self.home = parent
	self.bones = {}
	self.list = {}
	self.groups = {}
	self.root = CF()
	self.active = true
	self.outlineMode = outlineMode or "model"
	self.fill = fill
	if self.outlineMode == "model" then
		outline(self.model, fill and fill[1], fill and fill[2])
	end
	return self
end

function Rig:group(name)
	local g = self.groups[name]
	if g then
		return g
	end
	g = Instance.new("Model")
	g.Name = name
	g.Parent = self.model
	if self.outlineMode == "groups" then
		outline(g, self.fill and self.fill[1], self.fill and self.fill[2])
	end
	self.groups[name] = g
	return g
end

function Rig:addBone(name, parentName, offset)
	local b = {
		name = name,
		parent = parentName and self.bones[parentName] or nil,
		offset = offset or CF(),
		rot = CF(),
		from = CF(),
		to = CF(),
		t0 = 0,
		dur = 0,
		parts = {},
		world = CF(),
		wob = nil,
	}
	self.bones[name] = b
	table.insert(self.list, b)
	return b
end

function Rig:add(boneName, size, color, rel, o, groupName)
	local parent = self.model
	if groupName then
		parent = self:group(groupName)
	end
	local p = newPart(parent, size, color, nil, o)
	local e = { p = p, rel = rel or CF() }
	table.insert(self.bones[boneName].parts, e)
	return p, e
end

-- maker для Canvas/makeTri: детали в системе координат кости
function Rig:maker(boneName, groupName, tags)
	return function(size, color, cf, o)
		local p, e = self:add(boneName, size, color, cf, o, groupName)
		if tags and o and o.tag then
			tags[o.tag] = tags[o.tag] or {}
			table.insert(tags[o.tag], p)
		end
		return p
	end
end

-- pose = { кость = {x, y, z} в градусах }; кости без значения возвращаются в ноль
function Rig:pose(pose, dur, now)
	for _, b in ipairs(self.list) do
		local a = pose[b.name]
		local target = CF()
		if a then
			target = ANG(rad(a[1]), rad(a[2] or 0), rad(a[3] or 0))
		end
		b.from = b.rot
		b.to = target
		b.t0 = now or 0
		b.dur = dur or 0
		if b.dur <= 0 then
			b.rot = target
		end
	end
end

function Rig:place(cf)
	self.root = cf
end

function Rig:show(on)
	self.active = on
	if on then
		self.model.Parent = self.home
	else
		self.model.Parent = nil
	end
end

function Rig:update(now)
	for _, b in ipairs(self.list) do
		if b.dur > 0 then
			local a = clamp01((now - b.t0) / b.dur)
			b.rot = b.from:Lerp(b.to, smooth(a))
			if a >= 1 then
				b.dur = 0
				b.rot = b.to
			end
		end
		local base = self.root
		if b.parent then
			base = b.parent.world
		end
		local w = base * b.offset * b.rot
		if b.wob then
			w = w * b.wob(now)
		end
		b.world = w
		for _, e in ipairs(b.parts) do
			e.p.CFrame = w * e.rel
		end
	end
end

function Rig:point(boneName, v)
	return self.bones[boneName].world * v
end

-- показать один вариант из группы (например, рот: ухмылка / оскал / смех)
local function showVariant(tags, prefix, name)
	for tag, parts in pairs(tags) do
		if string.sub(tag, 1, #prefix) == prefix then
			local on = (tag == prefix .. name)
			for _, p in ipairs(parts) do
				if on then
					p.Transparency = 0
				else
					p.Transparency = 1
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- ЛИЦА: рисуем плоскими фигурами, как наклейку-лицо Roblox, только чище.
-- Координаты — для зрителя: x вправо, y вверх, лицо от -0.625 до 0.625.
----------------------------------------------------------------------

local Face = {}

-- глаз: spec задан для ЛЕВОГО (для зрителя) глаза, side = 1 отражает его вправо
local function drawEye(cv, spec, side, skin, look, lookY, lidDrop)
	local function M(pts)
		if side > 0 then
			return mirror(pts)
		end
		return pts
	end
	-- прищур: середина верхнего века опускается
	local function drop(pts)
		if not lidDrop or lidDrop == 0 then
			return pts
		end
		local out = {}
		for i, p in ipairs(pts) do
			local k = sin(math.pi * (i - 1) / (#pts - 1))
			out[i] = { p[1], p[2] - lidDrop * k }
		end
		return out
	end
	local cx, cy = spec.c[1] * (side > 0 and -1 or 1), spec.c[2]
	local rot = spec.rot * (side > 0 and -1 or 1)
	-- белок
	cv:ellipse(cx, cy, spec.rx, spec.ry, C.white, 1, rad(rot))
	-- радужка: одинаковый сдвиг взгляда для обоих глаз
	local I = spec.iris
	local ix, iy = cx + (look or 0), cy + (I.dy or 0) + (lookY or 0)
	cv:ellipse(ix, iy, I.rx, I.ry, I.shade, 2)
	cv:ellipse(ix, iy - I.ry * 0.12, I.rx * 0.86, I.ry * 0.8, I.color, 2.5)
	cv:ellipse(ix, iy - I.ry * 0.42, I.rx * 0.62, I.ry * 0.36, I.color:Lerp(C.white, 0.35), 3)
	cv:ellipse(ix, iy + I.ry * 0.04, I.rx * 0.4, I.ry * 0.42, I.pupil, 3.5)
	cv:ellipse(ix - I.rx * 0.32, iy + I.ry * 0.36, I.rx * 0.26, I.ry * 0.21, C.white, 4)
	cv:ellipse(ix + I.rx * 0.34, iy - I.ry * 0.3, I.rx * 0.12, I.ry * 0.1, C.white, 4)
	-- маски кожей: прячут белок и радужку за веками
	local lid = drop(M(spec.lid))
	cv:band(lid, cy + 0.2, skin, 5)
	local low = { M(spec.lid)[1] }
	for _, p in ipairs(M(spec.lower)) do
		low[#low + 1] = p
	end
	low[#low + 1] = M(spec.lid)[#spec.lid]
	cv:band(low, cy - 0.16, skin, 5)
	-- линии век, ресницы, мешки под глазами
	cv:stroke(lid, spec.lidW, spec.lidColor or C.ink, 6)
	if spec.flick then
		cv:stroke(M(spec.flick), spec.flickW, spec.lidColor or C.ink, 6)
	end
	cv:stroke(M(spec.lower), spec.lowerW, spec.lowerColor, 6)
	for _, bag in ipairs(spec.bags or {}) do
		cv:stroke(M(bag[1]), bag[2], bag[3], 6)
	end
end

local function drawBrow(cv, pts, widths, color, side)
	if side > 0 then
		pts = mirror(pts)
	end
	cv:stroke(pts, widths, color, 6.5)
end

local YUTA_EYE = {
	c = { -0.255, 0.02 }, rx = 0.165, ry = 0.1, rot = 3,
	iris = { rx = 0.066, ry = 0.086, color = RGB(64, 150, 205), shade = RGB(24, 70, 125), pupil = RGB(10, 18, 32), dy = -0.005 },
	lid = { { -0.095, 0.035 }, { -0.14, 0.088 }, { -0.205, 0.12 }, { -0.28, 0.128 }, { -0.35, 0.115 }, { -0.405, 0.085 }, { -0.44, 0.045 } },
	lidW = { 0.01, 0.026, 0.036, 0.04, 0.038, 0.03, 0.012 },
	flick = { { -0.39, 0.098 }, { -0.44, 0.092 }, { -0.48, 0.068 } },
	flickW = { 0.022, 0.016, 0.003 },
	lower = { { -0.15, -0.062 }, { -0.23, -0.078 }, { -0.31, -0.074 }, { -0.38, -0.05 } },
	lowerW = { 0.003, 0.011, 0.011, 0.003 },
	lowerColor = RGB(120, 72, 70),
	bags = {
		{ { { -0.17, -0.105 }, { -0.25, -0.121 }, { -0.33, -0.112 } }, { 0.002, 0.008, 0.002 }, RGB(178, 128, 122) },
		{ { { -0.2, -0.135 }, { -0.27, -0.146 }, { -0.32, -0.138 } }, { 0.002, 0.006, 0.002 }, RGB(186, 140, 132) },
	},
}

local RYU_EYE = {
	c = { -0.26, -0.005 }, rx = 0.16, ry = 0.078, rot = -4,
	iris = { rx = 0.054, ry = 0.066, color = RGB(150, 145, 195), shade = RGB(85, 75, 125), pupil = RGB(18, 14, 28), dy = 0 },
	lid = { { -0.1, 0.025 }, { -0.15, 0.06 }, { -0.22, 0.078 }, { -0.3, 0.08 }, { -0.37, 0.066 }, { -0.415, 0.042 }, { -0.44, 0.012 } },
	lidW = { 0.014, 0.036, 0.05, 0.052, 0.046, 0.032, 0.008 },
	flick = { { -0.405, 0.05 }, { -0.445, 0.04 }, { -0.47, 0.02 } },
	flickW = { 0.02, 0.014, 0.003 },
	lower = { { -0.15, -0.05 }, { -0.24, -0.068 }, { -0.33, -0.062 }, { -0.395, -0.038 } },
	lowerW = { 0.003, 0.013, 0.012, 0.003 },
	lowerColor = RGB(115, 70, 58),
	bags = {
		{ { { -0.17, -0.09 }, { -0.26, -0.106 }, { -0.35, -0.095 } }, { 0.002, 0.008, 0.002 }, RGB(160, 110, 90) },
	},
}

-- Юта. opt: look, lookY, angry (0..1), mouth ("neutral" | "grit"), blood, bangs
function Face.yuta(cv, skin, opt)
	opt = opt or {}
	local angry = opt.angry or 0.3
	for _, side in ipairs({ -1, 1 }) do
		drawEye(cv, YUTA_EYE, side, skin, opt.look, opt.lookY, opt.lidDrop)
		local inner = 0.205 - 0.03 * angry
		drawBrow(cv, { { -0.085, inner }, { -0.15, inner + 0.024 }, { -0.24, 0.248 }, { -0.33, 0.258 }, { -0.42, 0.25 }, { -0.47, 0.232 } },
			{ 0.026, 0.036, 0.04, 0.036, 0.024, 0.006 }, C.hairYuta, side)
	end
	local line = skin:Lerp(RGB(150, 80, 70), 0.45)
	cv:stroke({ { 0.005, -0.095 }, { 0.022, -0.15 }, { 0.006, -0.168 } }, { 0.003, 0.011, 0.004 }, line, 1)
	if opt.mouth == "grit" then
		cv:poly({ { -0.085, -0.322 }, { 0.085, -0.322 }, { 0.062, -0.348 }, { -0.062, -0.348 } }, RGB(70, 22, 28), 1)
		cv:poly({ { -0.07, -0.323 }, { 0.07, -0.323 }, { 0.064, -0.333 }, { -0.064, -0.333 } }, C.tooth, 2)
		cv:stroke({ { -0.1, -0.318 }, { 0, -0.322 }, { 0.1, -0.318 } }, { 0.004, 0.012, 0.004 }, RGB(90, 40, 40), 3)
	else
		cv:stroke({ { -0.085, -0.33 }, { 0, -0.336 }, { 0.085, -0.329 } }, { 0.004, 0.014, 0.004 }, RGB(150, 85, 85), 1)
	end
	if opt.blood then
		cv:stroke({ { 0.07, -0.338 }, { 0.088, -0.41 }, { 0.08, -0.5 }, { 0.09, -0.58 } }, { 0.012, 0.022, 0.014, 0.004 }, C.blood, 2)
		cv:ellipse(0.12, -0.45, 0.018, 0.024, C.blood, 2)
	end
	if opt.bangs ~= false then
		-- чёлка: острые пряди сверху
		cv:rect(0, 0.585, 1.25, 0.09, C.hairYuta, 8)
		local strands = {
			{ { -0.56, 0.6 }, { -0.53, 0.45 }, { -0.48, 0.3 } }, { 0.15, 0.11, 0.0 },
			{ { -0.4, 0.6 }, { -0.36, 0.44 }, { -0.3, 0.25 } }, { 0.17, 0.12, 0.0 },
			{ { -0.22, 0.6 }, { -0.2, 0.45 }, { -0.17, 0.21 } }, { 0.16, 0.11, 0.0 },
			{ { -0.05, 0.6 }, { -0.02, 0.42 }, { 0.03, 0.13 } }, { 0.15, 0.09, 0.0 },
			{ { 0.12, 0.6 }, { 0.14, 0.44 }, { 0.17, 0.27 } }, { 0.16, 0.11, 0.0 },
			{ { 0.28, 0.6 }, { 0.31, 0.42 }, { 0.36, 0.07 } }, { 0.16, 0.1, 0.0 },
			{ { 0.45, 0.6 }, { 0.47, 0.45 }, { 0.52, 0.28 } }, { 0.16, 0.12, 0.0 },
			{ { 0.57, 0.6 }, { 0.6, 0.4 }, { 0.62, 0.16 } }, { 0.1, 0.08, 0.0 },
		}
		for i = 1, #strands, 2 do
			cv:stroke(strands[i], strands[i + 1], C.hairYuta, 8)
		end
		cv:stroke({ { -0.03, 0.5 }, { 0.0, 0.36 }, { 0.02, 0.24 } }, { 0.02, 0.012, 0 }, RGB(70, 105, 118), 8.5)
		cv:stroke({ { 0.3, 0.5 }, { 0.32, 0.36 }, { 0.34, 0.2 } }, { 0.018, 0.01, 0 }, RGB(70, 105, 118), 8.5)
	end
end

-- Рю. Все рты рисуются сразу, видимый выбирается через showVariant(tags, "mouth_", имя)
function Face.ryu(cv, skin, opt)
	opt = opt or {}
	local line = skin:Lerp(RGB(95, 45, 30), 0.55)
	for _, side in ipairs({ -1, 1 }) do
		drawEye(cv, RYU_EYE, side, skin, opt.look, opt.lookY)
		drawBrow(cv, { { -0.06, 0.105 }, { -0.13, 0.14 }, { -0.22, 0.172 }, { -0.32, 0.188 }, { -0.42, 0.184 }, { -0.48, 0.165 } },
			{ 0.05, 0.075, 0.085, 0.078, 0.05, 0.012 }, C.ink, side)
		local s = side
		cv:stroke({ { -0.035 * s, 0.11 }, { -0.045 * s, 0.19 }, { -0.038 * s, 0.27 } }, { 0.003, 0.012, 0.003 }, line, 2)
		cv:stroke({ { -0.11 * s, -0.12 }, { -0.155 * s, -0.2 }, { -0.19 * s, -0.27 } }, { 0.002, 0.011, 0.003 }, line, 6)
		if not opt.closeup then
			cv:stroke({ { -0.2 * s, 0.31 }, { -0.12 * s, 0.322 } }, { 0.002, 0.004 }, line, 2)
		end
	end
	cv:stroke({ { 0, 0.12 }, { 0.003, 0.18 }, { 0, 0.24 } }, { 0.002, 0.009, 0.002 }, line, 2)
	cv:stroke({ { -0.055, 0.065 }, { 0, 0.075 }, { 0.055, 0.065 } }, { 0.002, 0.01, 0.002 }, line, 2)
	if not opt.closeup then
		cv:stroke({ { -0.3, 0.33 }, { -0.1, 0.345 }, { 0.1, 0.345 }, { 0.3, 0.33 } }, { 0.002, 0.01, 0.01, 0.002 }, line, 2)
		cv:stroke({ { -0.22, 0.405 }, { 0, 0.415 }, { 0.22, 0.405 } }, { 0.002, 0.009, 0.002 }, line, 2)
	end
	cv:stroke({ { 0.0, -0.04 }, { 0.022, -0.14 }, { 0.004, -0.165 } }, { 0.003, 0.012, 0.004 }, line, 2)
	cv:stroke({ { -0.045, -0.165 }, { -0.02, -0.172 } }, { 0.006, 0.003 }, line, 2)
	cv:stroke({ { 0.045, -0.165 }, { 0.02, -0.172 } }, { 0.006, 0.003 }, line, 2)

	if opt.closeup then
		return
	end
	local dark = RGB(90, 36, 34)
	-- ухмылка
	cv:stroke({ { -0.15, -0.33 }, { -0.06, -0.336 }, { 0.05, -0.33 }, { 0.13, -0.305 }, { 0.17, -0.28 } },
		{ 0.004, 0.016, 0.018, 0.014, 0.004 }, dark, 3, { tag = "mouth_smirk" })
	-- оскал с зубами
	cv:poly({ { -0.19, -0.285 }, { -0.1, -0.278 }, { 0, -0.275 }, { 0.1, -0.278 }, { 0.19, -0.285 },
		{ 0.15, -0.325 }, { 0.07, -0.345 }, { 0, -0.35 }, { -0.07, -0.345 }, { -0.15, -0.325 } }, C.tooth, 3, { tag = "mouth_grin" })
	cv:stroke({ { -0.2, -0.283 }, { -0.1, -0.276 }, { 0, -0.273 }, { 0.1, -0.276 }, { 0.2, -0.283 } },
		{ 0.004, 0.014, 0.016, 0.014, 0.004 }, dark, 4, { tag = "mouth_grin" })
	cv:stroke({ { -0.17, -0.315 }, { -0.08, -0.344 }, { 0, -0.352 }, { 0.08, -0.344 }, { 0.17, -0.315 } },
		{ 0.003, 0.01, 0.012, 0.01, 0.003 }, dark, 4, { tag = "mouth_grin" })
	cv:stroke({ { -0.17, -0.305 }, { 0, -0.312 }, { 0.17, -0.305 } }, { 0.003, 0.007, 0.003 }, RGB(130, 118, 118), 4, { tag = "mouth_grin" })
	for _, x in ipairs({ -0.12, -0.06, 0, 0.06, 0.12 }) do
		local h = 0.03 - abs(x) * 0.08
		cv:stroke({ { x, -0.279 }, { x, -0.279 - h } }, { 0.004, 0.003 }, RGB(150, 140, 140), 4, { tag = "mouth_grin" })
	end
	cv:stroke({ { 0.19, -0.284 }, { 0.215, -0.268 } }, { 0.008, 0.003 }, dark, 4, { tag = "mouth_grin" })
	cv:stroke({ { -0.19, -0.284 }, { -0.215, -0.268 } }, { 0.008, 0.003 }, dark, 4, { tag = "mouth_grin" })
	-- смех: открытый рот
	local laugh = { { -0.17, -0.27 }, { -0.08, -0.266 }, { 0.08, -0.266 }, { 0.17, -0.27 } }
	for i = 1, 7 do
		local a = math.pi * (i / 8)
		laugh[#laugh + 1] = { cos(a) * 0.16, -0.29 - sin(a) * 0.13 }
	end
	cv:poly(laugh, RGB(100, 22, 32), 3, { tag = "mouth_laugh" })
	cv:poly({ { -0.14, -0.271 }, { 0.14, -0.271 }, { 0.13, -0.303 }, { -0.13, -0.303 } }, C.tooth, 4, { tag = "mouth_laugh" })
	cv:ellipse(0, -0.385, 0.085, 0.04, RGB(195, 85, 95), 4, 0, { tag = "mouth_laugh" })
	local rim = {}
	for i = 1, #laugh do
		rim[i] = laugh[i]
	end
	rim[#rim + 1] = laugh[1]
	cv:stroke(rim, 0.012, dark, 4.5, { tag = "mouth_laugh" })
	-- бакенбарды и линия волос
	cv:rect(0, 0.6, 1.25, 0.06, C.hairRyu, 7)
	for _, s in ipairs({ -1, 1 }) do
		cv:stroke({ { 0.6 * s, 0.58 }, { 0.59 * s, 0.3 }, { 0.6 * s, 0.05 } }, { 0.06, 0.05, 0.0 }, C.hairRyu, 7)
	end
end

----------------------------------------------------------------------
-- ПЕРСОНАЖИ R6: Юта и Рю
----------------------------------------------------------------------

local GREY = RGB(163, 162, 165)

local function buildR6(name, parent, look)
	local rig = Rig.new(name, parent, "model")
	rig:addBone("root", nil, CF(0, 3, 0)) -- центр торса над ступнями
	rig:addBone("neck", "root", CF(0, 1, 0))
	rig:addBone("rArm", "root", CF(1.5, 0.5, 0))
	rig:addBone("lArm", "root", CF(-1.5, 0.5, 0))
	rig:addBone("rLeg", "root", CF(0.5, -1, 0))
	rig:addBone("lLeg", "root", CF(-0.5, -1, 0))
	rig:add("root", V3(2, 2, 1), look.shirt)
	rig:add("neck", V3(1.25, 1.25, 1.25), look.skin, CF(0, 0.625, 0))
	for _, a in ipairs({ "rArm", "lArm" }) do
		rig:add(a, V3(1, 1.6, 1), look.sleeve, CF(0, -0.3, 0))
		rig:add(a, V3(0.98, 0.4, 0.98), look.skin, CF(0, -1.3, 0))
	end
	for _, l in ipairs({ "rLeg", "lLeg" }) do
		rig:add(l, V3(1, 1.65, 1), look.pants, CF(0, -0.825, 0))
		rig:add(l, V3(1.02, 0.35, 1.06), look.shoes, CF(0, -1.825, -0.02))
	end
	return rig
end

-- холст на лице (плоскость перед головой) и на груди
local function faceCanvas(rig, tags)
	return Canvas.new(rig:maker("neck", nil, tags), CF(0, 0.625, -0.628), 1, 0.0022)
end
local function chestCanvas(rig)
	return Canvas.new(rig:maker("root"), CF(0, 0, -0.503), 1, 0.002)
end

-- колючий мех по эллипсу вокруг точки center (в системе кости)
local function furRing(rig, bone, center, rx, rz, count, len, o)
	o = o or {}
	local maker = rig:maker(bone)
	local up = o.up or 0.35
	for i = 1, count do
		local a = (i - 0.5) / count * math.pi * 2 + (o.phase or 0)
		local ca, sa = cos(a), sin(a)
		local open = o.openFront and sa < -0.5 and abs(ca) < o.openFront
		if not open then
			local base = center + V3(ca * rx, 0, sa * rz)
			local out = V3(ca, up, sa).Unit
			local tan = V3(-sa, 0, ca)
			local L = len * rr(0.75, 1.2)
			local w = o.width or 0.16
			local tip = base + out * L + V3(rr(-0.06, 0.06), rr(-0.05, 0.12), rr(-0.06, 0.06))
			local col = o.color or RGB(240, 240, 236)
			if i % 3 == 0 then
				col = o.shade or RGB(205, 206, 216)
			end
			makeTri(maker, base + tan * w, base - tan * w, tip, col, 0.05)
			makeTri(maker, base + V3(0, w, 0), base - V3(0, w * 0.6, 0), tip + V3(0, 0.05, 0), col, 0.05)
		end
	end
	if o.fluff then
		for i = 1, o.fluff do
			local a = (i - 0.5) / o.fluff * math.pi * 2
			local ca, sa = cos(a), sin(a)
			local open = o.openFront and sa < -0.5 and abs(ca) < o.openFront
			if not open then
				rig:add(bone, V3(0.62, 0.42, 0.62), o.color or RGB(240, 240, 236), CF(center + V3(ca * rx * 0.92, 0.02, sa * rz * 0.92)), { shape = "ball" })
			end
		end
	end
end

-- острые пряди 3D (для причёски Юты)
local function hairSpikes(rig, list, color)
	local maker = rig:maker("neck")
	for _, s in ipairs(list) do
		local base, dir, len, w = s[1], s[2].Unit, s[3], s[4]
		local side = dir:Cross(V3(0, 0, 1))
		if side.Magnitude < 0.1 then
			side = dir:Cross(V3(1, 0, 0))
		end
		side = side.Unit
		makeTri(maker, base + side * w, base - side * w, base + dir * len, color, 0.08)
		makeTri(maker, base + V3(0, 0, w), base - V3(0, 0, w), base + dir * len, color, 0.08)
	end
end

local function buildYuta(parent, faceOpt)
	local dummy = CONFIG.DUMMY_MODE
	local white = RGB(241, 242, 247)
	local look = { skin = C.skinYuta, shirt = white, sleeve = white, pants = RGB(24, 24, 30), shoes = RGB(16, 16, 20) }
	if dummy then
		look = { skin = GREY, shirt = GREY, sleeve = GREY, pants = GREY, shoes = GREY }
	end
	local rig = buildR6("Yuta", parent, look)
	local tags = {}
	Face.yuta(faceCanvas(rig, tags), look.skin, faceOpt)
	rig.tags = tags
	-- волосы: шапка, бока, затылок и острые пряди
	local h = C.hairYuta
	rig:add("neck", V3(1.38, 0.36, 1.38), h, CF(0, 1.32, 0.02))
	rig:add("neck", V3(1.38, 1.15, 0.32), h, CF(0, 0.78, 0.6))
	rig:add("neck", V3(0.17, 0.95, 1.28), h, CF(0.7, 0.86, 0.04))
	rig:add("neck", V3(0.17, 0.95, 1.28), h, CF(-0.7, 0.86, 0.04))
	hairSpikes(rig, {
		{ V3(0.3, 1.45, 0.3), V3(0.4, 0.9, 0.6), 0.55, 0.16 },
		{ V3(-0.3, 1.45, 0.3), V3(-0.4, 0.9, 0.6), 0.55, 0.16 },
		{ V3(0, 1.45, 0.45), V3(0, 0.6, 1), 0.6, 0.18 },
		{ V3(0.55, 1.1, 0.5), V3(0.8, 0.2, 0.8), 0.5, 0.15 },
		{ V3(-0.55, 1.1, 0.5), V3(-0.8, 0.2, 0.8), 0.5, 0.15 },
		{ V3(0.6, 0.6, 0.55), V3(0.6, -0.4, 0.8), 0.45, 0.14 },
		{ V3(-0.6, 0.6, 0.55), V3(-0.6, -0.4, 0.8), 0.45, 0.14 },
		{ V3(0, 0.4, 0.7), V3(0, -0.6, 1), 0.45, 0.16 },
		{ V3(0.45, 1.45, -0.2), V3(0.5, 1, -0.2), 0.4, 0.14 },
		{ V3(-0.45, 1.45, -0.2), V3(-0.5, 1, -0.2), 0.4, 0.14 },
	}, h)
	if not dummy then
		local shade = RGB(196, 200, 216)
		rig:add("root", V3(1.32, 0.3, 1.1), white, CF(0, 1.1, 0)) -- высокий воротник
		rig:add("root", V3(1.34, 0.05, 1.12), shade, CF(0, 1.26, 0))
		rig:add("root", V3(0.17, 0.17, 0.05), RGB(225, 190, 90), CF(0.33, 1.1, -0.57), { shape = "ball" })
		rig:add("root", V3(2.03, 0.15, 1.03), RGB(30, 30, 38), CF(0, -0.86, 0))
		rig:add("root", V3(0.26, 4.3, 0.26), RGB(22, 22, 28), CF(0, -0.1, 0.65) * ANG(0, 0, rad(38))) -- чехол меча
		local cv = chestCanvas(rig)
		cv:stroke({ { 0, 0.95 }, { 0.01, 0 }, { 0, -0.8 } }, 0.022, shade, 1)
		cv:stroke({ { -0.62, 0.3 }, { -0.55, -0.2 }, { -0.6, -0.7 } }, { 0.003, 0.014, 0.003 }, shade, 1)
		cv:stroke({ { 0.6, 0.4 }, { 0.52, -0.1 }, { 0.58, -0.6 } }, { 0.003, 0.014, 0.003 }, shade, 1)
		for _, a in ipairs({ "rArm", "lArm" }) do
			rig:add(a, V3(1.03, 0.05, 1.03), shade, CF(0, -0.6, 0))
			rig:add(a, V3(1.04, 0.13, 1.04), white, CF(0, -1.04, 0))
		end
	end
	return rig
end

local function buildRyu(parent, faceOpt)
	local dummy = CONFIG.DUMMY_MODE
	local coat = RGB(26, 28, 38)
	local look = { skin = C.skinRyu, shirt = C.skinRyu, sleeve = coat, pants = RGB(20, 20, 26), shoes = RGB(48, 34, 26) }
	if dummy then
		look = { skin = GREY, shirt = GREY, sleeve = GREY, pants = GREY, shoes = GREY }
	end
	local rig = buildR6("Ryu", parent, look)
	rig:addBone("coat", "root", CF(0, -1, 0))
	local tags = {}
	Face.ryu(faceCanvas(rig, tags), look.skin, faceOpt)
	rig.tags = tags
	showVariant(tags, "mouth_", (faceOpt and faceOpt.mouth) or "smirk")
	-- помпадур
	local h = C.hairRyu
	rig:add("neck", V3(1.4, 0.64, 1.4), h, CF(0, 1.25, 0.05), { shape = "ball" })
	rig:add("neck", V3(1.34, 0.5, 1.32), h, CF(0, 1.18, 0.06))
	rig:add("neck", V3(1.15, 0.8, 1.85), h, CF(0, 1.66, -0.42) * ANG(rad(18), 0, 0), { shape = "ball" })
	rig:add("neck", V3(1.0, 0.58, 0.62), h, CF(0, 1.86, -1.16) * ANG(rad(-20), 0, 0), { shape = "ball" })
	rig:add("neck", V3(1.34, 1.0, 0.28), h, CF(0, 0.9, 0.6))
	rig:add("neck", V3(0.13, 0.55, 1.05), h, CF(0.68, 1.0, 0.12))
	rig:add("neck", V3(0.13, 0.55, 1.05), h, CF(-0.68, 1.0, 0.12))
	local curl = rig:maker("neck")
	makeTri(curl, V3(0.2, 1.5, -1.1), V3(0.0, 1.5, -1.0), V3(0.35, 1.1, -0.95), h, 0.06)
	if not dummy then
		local fur, furShade = RGB(242, 242, 238), RGB(206, 207, 218)
		-- плащ
		rig:add("root", V3(0.48, 2.04, 1.06), coat, CF(0.78, 0, 0))
		rig:add("root", V3(0.48, 2.04, 1.06), coat, CF(-0.78, 0, 0))
		rig:add("root", V3(2.06, 2.04, 0.12), coat, CF(0, 0, 0.5))
		rig:add("coat", V3(2.1, 1.9, 0.12), coat, CF(0, -0.95, 0.54))
		rig:add("coat", V3(0.12, 1.9, 1.0), coat, CF(1.06, -0.95, 0.04))
		rig:add("coat", V3(0.12, 1.9, 1.0), coat, CF(-1.06, -0.95, 0.04))
		rig:add("coat", V3(0.5, 1.9, 0.12), coat, CF(0.8, -0.95, -0.54))
		rig:add("coat", V3(0.5, 1.9, 0.12), coat, CF(-0.8, -0.95, -0.54))
		-- грудь, пресс, жетоны
		local cv = chestCanvas(rig)
		local line = C.skinRyu:Lerp(RGB(105, 55, 35), 0.6)
		for _, s in ipairs({ -1, 1 }) do
			cv:stroke({ { -0.5 * s, 0.78 }, { -0.25 * s, 0.72 }, { -0.06 * s, 0.74 } }, { 0.004, 0.02, 0.004 }, line, 1)
			cv:stroke({ { -0.5 * s, 0.32 }, { -0.3 * s, 0.24 }, { -0.08 * s, 0.3 } }, { 0.004, 0.026, 0.006 }, line, 1)
			cv:stroke({ { -0.32 * s, -0.05 }, { -0.03 * s, -0.03 } }, { 0.004, 0.018 }, line, 1)
			cv:stroke({ { -0.3 * s, -0.35 }, { -0.03 * s, -0.33 } }, { 0.004, 0.018 }, line, 1)
			cv:stroke({ { -0.27 * s, -0.62 }, { -0.03 * s, -0.6 } }, { 0.004, 0.016 }, line, 1)
			cv:stroke({ { -0.48 * s, -0.1 }, { -0.43 * s, -0.5 }, { -0.34 * s, -0.86 } }, { 0.003, 0.016, 0.003 }, line, 1)
			for k = 0, 3 do
				cv:ellipse(-(0.18 + k * 0.08) * s, 0.62 - k * 0.012, 0.009, 0.009, line, 1)
			end
		end
		cv:stroke({ { 0, 0.7 }, { 0, 0.22 } }, { 0.004, 0.012 }, line, 1)
		cv:stroke({ { 0, 0.12 }, { 0, -0.86 } }, { 0.012, 0.004 }, line, 1)
		local chain = RGB(170, 172, 182)
		cv:stroke({ { -0.34, 0.98 }, { -0.12, 0.55 }, { 0, 0.3 } }, 0.014, chain, 2)
		cv:stroke({ { 0.34, 0.98 }, { 0.12, 0.55 }, { 0, 0.3 } }, 0.014, chain, 2)
		cv:rect(0.02, 0.15, 0.16, 0.25, RGB(60, 62, 70), 2.5, rad(8))
		cv:rect(0.02, 0.15, 0.13, 0.22, RGB(205, 210, 220), 3, rad(8))
		cv:stroke({ { -0.02, 0.2 }, { 0.05, 0.21 } }, 0.008, RGB(120, 124, 134), 3.5)
		cv:stroke({ { -0.02, 0.15 }, { 0.05, 0.16 } }, 0.008, RGB(120, 124, 134), 3.5)
		-- мех: воротник, манжеты, низ плаща
		furRing(rig, "root", V3(0, 1.0, 0), 1.08, 0.66, 30, 0.85, { up = 0.55, openFront = 0.42, fluff = 12, shade = furShade })
		furRing(rig, "root", V3(0, 1.18, 0.05), 0.82, 0.5, 18, 0.6, { up = 1.1, openFront = 0.35, shade = furShade, phase = 0.2 })
		for _, a in ipairs({ "rArm", "lArm" }) do
			furRing(rig, a, V3(0, -1.08, 0), 0.52, 0.52, 10, 0.38, { up = -0.25, shade = furShade, width = 0.12 })
		end
		furRing(rig, "coat", V3(0, -1.88, 0.06), 1.1, 0.6, 20, 0.42, { up = -0.7, openFront = 0.55, shade = furShade, width = 0.13 })
	end
	return rig
end

----------------------------------------------------------------------
-- РИКА (полная форма): голова-раковина с бороздами, огромная пасть с клыками,
-- волосы-щупальца, рёбра, длинные руки с когтями, чёрный хвост вместо ног
----------------------------------------------------------------------

local RIKA_MOUTH = V3(0, -1.5, -3.4) -- точка в пасти (в системе кости head)

-- CFrame, у которой ось +Y смотрит вдоль dir
local function alongY(pos, dir)
	local y = dir.Unit
	local x = y:Cross(V3(0, 0, 1))
	if x.Magnitude < 0.05 then
		x = y:Cross(V3(1, 0, 0))
	end
	x = x.Unit
	local z = x:Cross(y)
	return CFrame.fromMatrix(pos, x, y, z)
end

local function buildRika(parent)
	local rig = Rig.new("Rika", parent, "groups", { RGB(255, 255, 255), 0.84 })
	local S, K = C.rika, C.ink
	local function bone(n, p, cf)
		return rig:addBone(n, p, cf)
	end
	local function ell(b, size, col, rel, g)
		return rig:add(b, size, col, rel, { shape = "ball" }, g)
	end
	-- срез эллипсоида плоскостью x = x0: тонкая чёрная линия по поверхности
	local function lineX(b, center, size, x0, g)
		local f = 1 - (x0 / (size.X / 2)) ^ 2
		if f < 0.05 then
			return
		end
		local s = sqrt(f) * 1.025
		ell(b, V3(0.07, size.Y * s, size.Z * s), K, center * CF(x0, 0, 0), g)
	end
	local function lineZ(b, center, size, z0, g)
		local f = 1 - (z0 / (size.Z / 2)) ^ 2
		if f < 0.05 then
			return
		end
		local s = sqrt(f) * 1.03
		ell(b, V3(size.X * s, size.Y * s, 0.06), K, center * CF(0, 0, z0), g)
	end
	local function ringY(b, center, size, y0, tilt, g, w)
		local f = 1 - (y0 / (size.Y / 2)) ^ 2
		if f < 0.05 then
			return
		end
		local s = sqrt(f) * 1.04
		ell(b, V3(size.X * s + 0.06, w or 0.13, size.Z * s + 0.06), K, center * CF(0, y0, 0) * ANG(rad(tilt or 0), 0, 0), g)
	end

	bone("root", nil, CF())
	bone("spine", "root", CF(0, 1.4, 0))
	bone("chest", "spine", CF(0, 2.2, 0))
	bone("neck", "chest", CF(0, 3.4, -0.3))
	bone("head", "neck", CF(0, 2.0, -0.2))
	bone("jaw", "head", CF(0, -0.35, -1.0))

	-- ГОЛОВА: купол-раковина с бороздами, под ним огромная пасть
	local domeCF = CF(0, 1.5, -0.6) * ANG(rad(-30), 0, 0)
	local dome = V3(5.2, 4.6, 7.4)
	ell("head", dome, S, domeCF, "head")
	for _, x0 in ipairs({ -2.1, -1.55, -1.0, -0.5, 0, 0.5, 1.0, 1.55, 2.1 }) do
		lineX("head", domeCF, dome, x0, "head")
	end
	ringY("head", domeCF, dome, -0.85, 0, "head", 0.1)
	ell("head", V3(4.6, 1.6, 6.0), RGB(70, 66, 78), domeCF * CF(0, -1.7, -0.3), "head")
	-- щёки-стенки пасти
	for _, s2 in ipairs({ 1, -1 }) do
		ell("head", V3(1.1, 2.6, 2.8), S, CF(s2 * 2.05, -1.1, -1.9) * ANG(0, 0, rad(s2 * 8)), "head")
	end
	ell("head", V3(4.3, 1.0, 2.6), C.gum, CF(0, -0.72, -2.65), "head")
	ell("head", V3(3.6, 2.2, 1.8), C.mouth, CF(0, -1.45, -1.75), "head")
	local headMaker = rig:maker("head", "head")
	for i = 0, 11 do
		local x = -1.8 + i * (3.6 / 11)
		local z = -3.55 + 0.6 * (x / 1.8) ^ 2
		local L = rr(1.4, 2.0) * (1 - 0.25 * abs(x) / 1.8)
		local base = V3(x, -0.85, z)
		local tip = V3(x * 0.96, -0.85 - L, z + 0.18)
		makeTri(headMaker, base + V3(0.17, 0, 0), base - V3(0.17, 0, 0), tip, C.tooth, 0.13)
		makeTri(headMaker, base + V3(0, 0, 0.14), base - V3(0, 0, 0.14), tip, C.tooth, 0.13)
	end
	-- нижняя челюсть
	ell("jaw", V3(4.0, 1.0, 3.4), S, CF(0, -1.6, -1.1) * ANG(rad(10), 0, 0), "head")
	ringY("jaw", CF(0, -1.6, -1.1) * ANG(rad(10), 0, 0), V3(4.0, 1.0, 3.4), 0.1, 0, "head", 0.06)
	ell("jaw", V3(3.6, 0.6, 2.9), C.gum, CF(0, -1.12, -1.3), "head")
	local jawMaker = rig:maker("jaw", "head")
	for i = 0, 10 do
		local x = -1.7 + i * (3.4 / 10)
		local z = -2.6 + 0.55 * (x / 1.7) ^ 2
		local L = rr(1.1, 1.6) * (1 - 0.25 * abs(x) / 1.7)
		local base = V3(x, -1.05, z)
		local tip = V3(x * 0.95, -1.05 + L, z - 0.12)
		makeTri(jawMaker, base + V3(0.16, 0, 0), base - V3(0.16, 0, 0), tip, C.tooth, 0.13)
		makeTri(jawMaker, base + V3(0, 0, 0.12), base - V3(0, 0, 0.12), tip, C.tooth, 0.13)
	end

	-- ВОЛОСЫ-ЩУПАЛЬЦА: толстые, текут назад и вниз
	for k = 1, 14 do
		local phi = rad(-120 + (k - 1) * (240 / 13))
		local base = V3(sin(phi) * 2.3, 2.1 + 0.6 * cos(phi), 0.9 + 2.0 * cos(phi))
		local dir = V3(sin(phi) * 0.8, 0.45 + rr(-0.1, 0.2), cos(phi) * 0.9 + 0.9)
		local prev = "head"
		local lens = { 2.6, 2.5, 2.3, 2.1 }
		local widths = { 1.25, 1.08, 0.88, 0.66 }
		for j = 1, 4 do
			local name = "hair" .. k .. "_" .. j
			local off
			if j == 1 then
				off = alongY(base, dir)
			else
				off = CF(0, lens[j - 1], 0)
			end
			local b = bone(name, prev, off)
			local L, w = lens[j], widths[j]
			ell(name, V3(w, L * 1.35, w), S, CF(0, L / 2, 0), "hair")
			lineX(name, CF(0, L / 2, 0), V3(w, L * 1.35, w), w * 0.22, "hair")
			local ph = k * 0.9 + j * 0.55
			b.wob = function(t)
				return ANG(rad(22 + 8 * sin(t * 1.6 + ph)), 0, rad(8 * sin(t * 1.15 + ph * 1.3)))
			end
			prev = name
		end
	end

	-- ТЕЛО: шея, грудь с рёбрами, талия в чёрных пятнах
	ell("neck", V3(1.5, 3.2, 1.4), S, CF(0, 1.3, 0.2), "body")
	ell("neck", V3(0.9, 3.4, 0.9), S, CF(0.62, 1.3, 0.05) * ANG(0, 0, rad(-6)), "body")
	ell("neck", V3(0.9, 3.4, 0.9), S, CF(-0.62, 1.3, 0.05) * ANG(0, 0, rad(6)), "body")
	local chestCF, chest = CF(0, 1.3, 0), V3(5.6, 5.2, 3.4)
	ell("chest", chest, S, chestCF, "body")
	for k = 1, 6 do
		ringY("chest", chestCF, chest, -1.75 + k * 0.55, -14, "body", 0.13)
	end
	ell("chest", V3(0.18, 3.4, 0.18), K, CF(0, 1.5, -1.68), "body")
	for _, s in ipairs({ 1, -1 }) do
		ell("chest", V3(2.4, 0.42, 0.42), S, CF(s * 1.3, 3.6, -0.75) * ANG(0, 0, rad(s * 10)), "body")
		ell("chest", V3(2.3, 2.0, 2.3), S, CF(s * 2.8, 2.5, 0), "body")
	end
	local waistCF, waist = CF(0, 0.5, 0), V3(3.0, 3.6, 2.3)
	ell("spine", waist, S, waistCF, "body")
	for i = 1, 18 do
		local a = rr(0, math.pi * 2)
		local y = rr(-1.5, 0.1)
		local f = sqrt(math.max(0.05, 1 - (y / 1.7) ^ 2))
		local pos = V3(cos(a) * 1.5 * f, 0.5 + y, sin(a) * 1.15 * f)
		local sz = rr(0.18, 0.42)
		ell("spine", V3(sz, sz * 0.8, sz), K, CF(pos), "body")
	end

	-- ХВОСТ
	ell("root", V3(3.3, 2.4, 2.5), C.rikaTail, CF(0, -0.3, 0), "tail")
	local lens = { 2.4, 2.3, 2.2, 2.0, 1.9, 1.7, 1.5, 1.3, 1.1 }
	local widths = { 3.0, 2.7, 2.4, 2.1, 1.8, 1.5, 1.2, 0.9, 0.55 }
	local prev = "root"
	for i = 1, 9 do
		local name = "tail" .. i
		local off = CF(0, -1.0, 0)
		if i > 1 then
			off = CF(0, -lens[i - 1], 0)
		end
		local b = bone(name, prev, off)
		ell(name, V3(widths[i], lens[i] * 1.75, widths[i]), C.rikaTail, CF(0, -lens[i] / 2, 0), "tail")
		local ph = i * 0.6
		b.wob = function(t)
			return ANG(rad(7 * sin(t * 1.3 + ph)), 0, rad(11 * sin(t * 0.95 + ph * 1.2)))
		end
		prev = name
	end

	-- РУКИ И ПАЛЬЦЫ
	for _, s in ipairs({ 1, -1 }) do
		local R = "R"
		if s < 0 then
			R = "L"
		end
		local g = "arm" .. R
		bone("sh" .. R, "chest", CF(s * 2.9, 2.4, 0))
		bone("el" .. R, "sh" .. R, CF(0, -6.6, 0))
		bone("ha" .. R, "el" .. R, CF(0, -6.8, 0))
		local upCF, up = CF(0, -3.3, 0), V3(1.6, 7.1, 1.6)
		ell("sh" .. R, up, S, upCF, g)
		lineZ("sh" .. R, upCF, up, -0.22, g)
		ringY("sh" .. R, upCF, up, -1.6, 12, g, 0.08)
		ell("el" .. R, V3(1.3, 1.3, 1.3), S, CF(0, 0.1, 0), g)
		local foCF, fo = CF(0, -3.4, 0), V3(1.45, 7.2, 1.45)
		ell("el" .. R, fo, S, foCF, g)
		lineX("el" .. R, foCF, fo, 0.2 * s, g)
		ringY("el" .. R, foCF, fo, 2.2, -10, g, 0.08)
		ell("ha" .. R, V3(1.1, 1.1, 1.1), S, CF(0, -0.2, 0), g)
		ell("ha" .. R, V3(2.6, 3.0, 1.0), S, CF(0, -1.4, 0), g)
		ell("ha" .. R, V3(2.7, 0.14, 1.1), K, CF(0, -2.4, 0), g)
		local fx = { -1.05, -0.52, 0, 0.52, 1.05 }
		for i = 1, 5 do
			local fa, fb = "f" .. R .. i, "f" .. R .. i .. "b"
			local off = CF(fx[i] * s, -2.8, 0) * ANG(0, 0, rad(-fx[i] * s * 8))
			local L1, L2 = 2.6, 2.3
			if i == 1 then
				off = CF(-1.3 * s, -1.4, -0.4) * ANG(rad(-25), 0, rad(-s * 35))
				L1, L2 = 2.0, 1.8
			end
			local b1 = bone(fa, "ha" .. R, off)
			local b2 = bone(fb, fa, CF(0, -L1, 0))
			ell(fa, V3(0.48, L1, 0.48), S, CF(0, -L1 / 2, 0), g)
			ell(fa, V3(0.54, 0.12, 0.54), K, CF(0, -L1 + 0.05, 0), g)
			ell(fb, V3(0.42, L2, 0.42), S, CF(0, -L2 / 2, 0), g)
			ell(fb, V3(0.3, 1.9, 0.3), S, CF(0, -L2 - 0.75, -0.15) * ANG(rad(-14), 0, 0), g)
			local ph = i * 0.7 + s
			b1.wob = function(t)
				return ANG(rad(6 * sin(t * 2.1 + ph)), 0, 0)
			end
			b2.wob = function(t)
				return ANG(rad(8 * sin(t * 2.4 + ph)), 0, 0)
			end
		end
	end

	-- дыхание и пасть
	rig.bones.chest.wob = function(t)
		return ANG(rad(1.5 * sin(t * 2.2)), 0, 0)
	end
	rig.bones.jaw.wob = function(t)
		return ANG(rad(3 * sin(t * 7)), 0, 0)
	end
	rig.mouth = function()
		return rig:point("head", RIKA_MOUTH)
	end
	return rig
end

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

-- мягкое круглое свечение (12 вложенных кругов в BillboardGui)
function FX.glow(pos, size, color, strength, brightness)
	local holder = newPart(Shot.folder, V3(0.2, 0.2, 0.2), C.white, CF(pos), { alpha = 1 })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(size, size)
	bb.LightInfluence = 0
	bb.Brightness = brightness or 2
	bb.AlwaysOnTop = false
	bb.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	bb.Parent = holder
	local rings = {}
	local base = strength or 0.14
	for i = 1, 12 do
		local f = 1 - (i - 1) / 12
		local r = uiFrame(bb, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(f, f),
			BackgroundColor3 = color:Lerp(C.white, (1 - f) ^ 1.4),
			BackgroundTransparency = 1 - base,
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
			for _, r in ipairs(rings) do
				r.BackgroundTransparency = 1 - base * k
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

----------------------------------------------------------------------
-- МИР: ночной город (часть 1), поле с кратером (часть 2), «диорама» глаз
----------------------------------------------------------------------

-- Всё стоит далеко от (0, 0, 0): не мешает Baseplate и точке появления
local ORIGIN = V3(0, 0, 9000) -- город
local CLASH_POINT = ORIGIN + V3(0, 16, 0)
local CITY_CAM_REL = V3(-62, 50, -122) -- камера общего плана: вдоль её взгляда дома ниже
local CITY_CAM = ORIGIN + CITY_CAM_REL
local FIELD = V3(3000, 0, 9000) -- поле с кратером
local STAGE = {
	eyes = V3(0, 2600, -6000),
	yuta1 = V3(4000, 400, 0),
	ryu1 = V3(-4000, 400, 0),
	vortex = V3(-6000, 400, 0),
	laugh = V3(-3000, 400, 5000),
	yuta2 = V3(5000, 400, 5000),
	zoom = V3(6000, 400, -3000),
}

local function buildCity(parent)
	local f = Instance.new("Folder")
	f.Name = "City"
	f.Parent = parent
	local function at(x, y, z)
		return CF(ORIGIN.X + x, ORIGIN.Y + y, ORIGIN.Z + z)
	end
	newPart(f, V3(2400, 2, 2400), RGB(26, 30, 36), at(0, -0.95, 0), { material = Enum.Material.Asphalt })
	local r = Random.new(7)
	local function n(a, b)
		return r:NextNumber(a, b)
	end
	local camXZ = Vector2.new(CITY_CAM_REL.X, CITY_CAM_REL.Z)
	local axis = (Vector2.new(0, 0) - camXZ).Unit
	local span = (Vector2.new(0, 0) - camXZ).Magnitude
	for gx = -11, 11 do
		for gz = -11, 11 do
			local cx, cz = gx * 46 + n(-6, 6), gz * 46 + n(-6, 6)
			if not (abs(cx) < 70 and abs(cz) < 95) then
				local w, d = n(18, 34), n(18, 34)
				local h = n(14, 64)
				if abs(cx) + abs(cz) < 300 then
					h = h * 1.4
				end
				local rel = Vector2.new(cx, cz) - camXZ
				local along = rel:Dot(axis)
				local side = abs(rel.X * axis.Y - rel.Y * axis.X)
				if along > -40 and along < span and side < 45 then
					h = math.min(h, 22 + along * 0.06)
				end
				local col = RGB(r:NextInteger(36, 58), r:NextInteger(54, 76), r:NextInteger(60, 82))
				local cf = at(cx, h / 2, cz)
				newPart(f, V3(w, h, d), col, cf, { material = Enum.Material.Concrete })
				newPart(f, V3(w * 0.4, n(2, 5), d * 0.4), col:Lerp(C.black, 0.3), cf * CF(n(-3, 3), h / 2 + 1.5, n(-3, 3)))
				for _ = 1, r:NextInteger(2, 9) do
					local face = r:NextInteger(1, 4)
					local wy = n(-h / 2 + 3, h / 2 - 3)
					local lit = RGB(255, 214, 140)
					if r:NextNumber() < 0.35 then
						lit = RGB(170, 210, 255)
					end
					if face == 1 then
						newPart(f, V3(1.6, 1.1, 0.12), lit, cf * CF(n(-w / 2 + 2, w / 2 - 2), wy, -d / 2 - 0.05), { neon = true })
					elseif face == 2 then
						newPart(f, V3(1.6, 1.1, 0.12), lit, cf * CF(n(-w / 2 + 2, w / 2 - 2), wy, d / 2 + 0.05), { neon = true })
					elseif face == 3 then
						newPart(f, V3(0.12, 1.1, 1.6), lit, cf * CF(w / 2 + 0.05, wy, n(-d / 2 + 2, d / 2 - 2)), { neon = true })
					else
						newPart(f, V3(0.12, 1.1, 1.6), lit, cf * CF(-w / 2 - 0.05, wy, n(-d / 2 + 2, d / 2 - 2)), { neon = true })
					end
				end
			end
		end
	end
	-- не ставим обломки у камеры кадра столкновения
	local function nearCam(x, z)
		return (V3(x, 0, z) - V3(-14, 0, -35)).Magnitude < 24
	end
	for _ = 1, 40 do
		local pos = V3(n(-68, 68), 0, n(-92, 92))
		if nearCam(pos.X, pos.Z) then
			pos = V3(pos.X, 0, math.abs(pos.Z) + 10)
		end
		local s = V3(n(3, 12), n(1.5, 7), n(3, 12))
		newPart(f, s, RGB(52, 58, 60), at(pos.X, s.Y / 2 - 0.5, pos.Z) * ANG(n(-0.4, 0.4), n(0, 6.28), n(-0.4, 0.4)), { material = Enum.Material.Concrete })
	end
	for _ = 1, 18 do
		local pos = V3(n(-60, 60), n(2, 8), n(-85, 85))
		if nearCam(pos.X, pos.Z) then
			pos = V3(pos.X, pos.Y, math.abs(pos.Z) + 10)
		end
		newPart(f, V3(0.5, 0.5, n(6, 16)), C.red, CF(ORIGIN + pos) * ANG(n(-1, 1), n(0, 6.28), n(-1, 1)))
	end
	return f
end

-- поле после взрыва: светлая земля в трещинах, кратер с тёмными камнями
local function buildField(parent)
	local f = Instance.new("Folder")
	f.Name = "Field"
	f.Parent = parent
	local r = Random.new(11)
	local function n(a, b)
		return r:NextNumber(a, b)
	end
	local ground = RGB(186, 196, 214)
	newPart(f, V3(1600, 2, 1600), ground, CF(FIELD + V3(0, -1, 0)))
	local crater = FIELD + V3(24, 0, -14)
	newPart(f, V3(0.2, 70, 64), RGB(132, 142, 162), CF(crater + V3(0, 0.02, 0)) * ANG(0, 0, rad(90)), { shape = "cyl" })
	newPart(f, V3(0.2, 46, 42), RGB(98, 106, 124), CF(crater + V3(0, 0.05, 0)) * ANG(0, 0, rad(90)), { shape = "cyl" })
	local rocks = Instance.new("Model")
	rocks.Name = "Rocks"
	rocks.Parent = f
	outline(rocks, nil, 1, RGB(40, 44, 58))
	for i = 1, 70 do
		local a = n(0, math.pi * 2)
		local rad0 = n(8, 26)
		local pos = crater + V3(cos(a) * rad0 * 1.05, 0, sin(a) * rad0)
		if (pos - (FIELD + V3(2, 0, 16))).Magnitude < 16 then
			pos = crater + V3(cos(a) * 9, 0, -abs(sin(a)) * 12)
		end
		local s = V3(n(1.5, 6.5), n(1, 4.5), n(1.5, 6))
		local shade = n(0.85, 1.15)
		local col = RGB(floor(78 * shade), floor(86 * shade), floor(104 * shade))
		newPart(rocks, s, col, CF(pos + V3(0, s.Y * 0.3, 0)) * ANG(n(-0.6, 0.6), n(0, 6.28), n(-0.6, 0.6)), { wedge = (i % 3 == 0) })
	end
	-- трещины
	local crack = RGB(118, 126, 146)
	for i = 1, 26 do
		local a = n(0, math.pi * 2)
		local p = crater + V3(cos(a) * 33, 0.08, sin(a) * 30)
		for _ = 1, r:NextInteger(3, 6) do
			local a2 = a + n(-0.6, 0.6)
			local L = n(5, 14)
			local q = p + V3(cos(a2) * L, 0, sin(a2) * L)
			newPart(f, V3(n(0.15, 0.4), 0.06, (q - p).Magnitude), crack, CFrame.lookAt((p + q) / 2, q))
			p = q
		end
	end
	return f
end

-- Диорама для кадра с глазами: два «окна» в чёрной рамке, за ними плоские рисунки лиц.
-- Камера: STAGE.eyes + (0, 0, -122.5), смотрит на +Z, FOV 20 → видно 76.8 x 43.2.
local EYES = { k = 40, d = 0.06, camDist = 122.5 }

local function cloudSky(sg, colors)
	local f = uiFrame(sg, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white })
	gradient(f, colors, nil, 90)
	local r = Random.new(5)
	for _ = 1, 7 do
		local c = uiFrame(f, {
			Position = UDim2.fromScale(r:NextNumber(-0.15, 0.95), r:NextNumber(-0.2, 0.8)),
			Size = UDim2.fromScale(r:NextNumber(0.15, 0.35), r:NextNumber(0.2, 0.45)),
			BackgroundColor3 = RGB(228, 232, 250),
			BackgroundTransparency = r:NextNumber(0.7, 0.85),
		})
		corner(c, 0.5)
	end
end

local function buildEyes(parent)
	local f = Instance.new("Folder")
	f.Name = "EyesStage"
	f.Parent = parent
	local S0 = STAGE.eyes
	local k = EYES.k
	local function maker(size, color, cf, o)
		return newPart(f, size, color, cf, o)
	end
	local function sky(center, colors, h)
		local p = newPart(f, V3(110, h or 24, 0.2), C.black, CF(center))
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.LightInfluence = 0
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.CanvasSize = Vector2.new(1100, 240)
		sg.Parent = p
		cloudSky(sg, colors)
	end
	-- ВЕРХ: Юта (z = 0)
	local topC = S0 + V3(0, 11, 0)
	sky(topC + V3(0, 0, 1.2), { RGB(58, 78, 150), RGB(120, 138, 202) })
	local cvY = Canvas.new(maker, CF(topC + V3(-8, -1.8, 0)), k, EYES.d)
	local skinY = C.skinYuta
	cvY:rect(0, 0.06, 1.25, 0.62, skinY, 0)
	cvY:poly({ { 0.36, 0.33 }, { 0.625, 0.33 }, { 0.625, -0.27 }, { 0.5, -0.27 }, { 0.47, -0.05 }, { 0.42, 0.12 } }, skinY:Lerp(RGB(150, 110, 150), 0.32), 0.5)
	cvY:rect(-0.6, 0.06, 0.05, 0.62, skinY:Lerp(RGB(150, 110, 150), 0.25), 0.5)
	Face.yuta(cvY, skinY, { look = -0.03, angry = 0.55, mouth = "neutral", bangs = true })
	for _, s in ipairs({
		{ { { -0.66, 0.36 }, { -0.68, 0.15 }, { -0.64, -0.05 } }, { 0.12, 0.08, 0 } },
		{ { { -0.76, 0.36 }, { -0.8, 0.2 }, { -0.78, 0.04 } }, { 0.1, 0.06, 0 } },
		{ { { -0.62, 0.36 }, { -0.6, 0.2 }, { -0.56, 0.1 } }, { 0.09, 0.06, 0 } },
		{ { { 0.66, 0.36 }, { 0.68, 0.1 }, { 0.66, -0.2 } }, { 0.14, 0.1, 0 } },
	}) do
		cvY:stroke(s[1], s[2], C.hairYuta, 8)
	end
	-- НИЗ: Рю (ближе к камере на 1.5, поэтому закрывает всё, что Юта «свесил» вниз)
	local botC = S0 + V3(0, -11, -1.5)
	sky(botC + V3(0, -0.5, 0.6), { RGB(70, 100, 175), RGB(152, 184, 230) }, 21)
	local cvR = Canvas.new(maker, CF(botC + V3(8, -0.6, 0)), k, EYES.d)
	local skinR = C.skinRyu
	cvR:rect(0, -0.07, 1.25, 0.66, skinR, 0)
	cvR:poly({ { -0.625, 0.28 }, { -0.42, 0.28 }, { -0.47, 0.1 }, { -0.5, -0.1 }, { -0.44, -0.3 }, { -0.625, -0.3 } }, skinR:Lerp(RGB(140, 90, 120), 0.3), 0.5)
	Face.ryu(cvR, skinR, { look = 0.035, closeup = true })
	for _, s in ipairs({
		{ { { -0.64, 0.28 }, { -0.68, 0.1 }, { -0.64, -0.12 } }, { 0.11, 0.07, 0 } },
		{ { { -0.72, 0.28 }, { -0.76, 0.05 }, { -0.7, -0.2 } }, { 0.09, 0.06, 0 } },
	}) do
		cvR:stroke(s[1], s[2], C.hairRyu, 8)
	end
	-- ЧЁРНАЯ РАМКА с двумя окнами (ближе всего к камере)
	local fz = -3
	local black = RGB(6, 6, 8)
	newPart(f, V3(140, 20, 0.2), black, CF(S0 + V3(0, 21.2 + 10, fz)))
	newPart(f, V3(140, 20, 0.2), black, CF(S0 + V3(0, -21.2 - 10, fz)))
	newPart(f, V3(30, 80, 0.2), black, CF(S0 + V3(38 + 15, 0, fz)))
	newPart(f, V3(30, 80, 0.2), black, CF(S0 + V3(-38 - 15, 0, fz)))
	newPart(f, V3(140, 2.2, 0.2), black, CF(S0 + V3(0, 0, fz)))
	for i = 1, 4 do
		newPart(f, V3(140, rr(0.25, 0.6), 0.2), black, CF(S0 + V3(0, rr(-0.95, 0.95), fz - 0.05)) * ANG(0, 0, rad(rr(-0.4, 0.4))))
	end
	return f
end

----------------------------------------------------------------------
-- ИНТЕРФЕЙС: старт, конец, вспышки, кадры-удары, линии скорости, виньетка
----------------------------------------------------------------------

local ui = {}

local function uiText(parent, class, props)
	local t = Instance.new(class)
	t.BackgroundTransparency = 1
	t.BorderSizePixel = 0
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = C.white
	t.TextScaled = true
	for k, v in pairs(props) do
		t[k] = v
	end
	t.Parent = parent
	return t
end

local function button(parent, text, x, y, color)
	local b = uiText(parent, "TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(0.22, 0.085),
		Text = text, BackgroundTransparency = 0, BackgroundColor3 = color, ZIndex = 21, AutoButtonColor = true,
	})
	corner(b, 0.25)
	return b
end

-- белая клякса на чёрном (кадр-удар), cx/cy — центр, s — размер
local function buildImpact(parent, cx, cy, s, withLines)
	local f = uiFrame(parent, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RGB(4, 4, 6), ZIndex = 15, Visible = false })
	local r = Random.new(3)
	for i = 1, 5 do
		local d = s * r:NextNumber(0.35, 0.7)
		local blob = uiFrame(f, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(cx + r:NextNumber(-0.06, 0.06) * s, cy + r:NextNumber(-0.08, 0.08) * s),
			Size = UDim2.fromScale(d * 0.5625, d), BackgroundColor3 = C.white, ZIndex = 16,
		})
		corner(blob, 0.5)
	end
	for i = 1, 26 do
		local a = (i / 26) * 360 + r:NextNumber(-6, 6)
		local L = s * r:NextNumber(0.25, 0.6)
		local dx, dy = cos(rad(a)) * L * 0.5 * 0.5625, sin(rad(a)) * L * 0.5
		uiFrame(f, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(cx + dx * 1.2, cy + dy * 1.2),
			Size = UDim2.fromScale(L * 0.5625, r:NextNumber(0.008, 0.02)),
			Rotation = a, BackgroundColor3 = C.white, ZIndex = 16,
		})
	end
	if withLines then
		for _, a in ipairs({ -28, 24 }) do
			uiFrame(f, {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cx, cy),
				Size = UDim2.fromScale(1.4, 0.006), Rotation = a, BackgroundColor3 = RGB(255, 236, 70), ZIndex = 17,
			})
		end
	end
	return f
end

local function buildUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RyuVsYutaUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	ui.gui = gui

	-- засветка окон в кадре с глазами
	ui.washTop = uiFrame(gui, { Position = UDim2.fromScale(0, 0.009), Size = UDim2.fromScale(1, 0.4655), BackgroundColor3 = C.white, BackgroundTransparency = 1, ZIndex = 4 })
	gradient(ui.washTop, { RGB(240, 180, 255), C.white }, { 0, 0.2, 1 }, 0)
	ui.washBottom = uiFrame(gui, { Position = UDim2.fromScale(0, 0.5255), Size = UDim2.fromScale(1, 0.4655), BackgroundColor3 = C.white, BackgroundTransparency = 1, ZIndex = 4 })
	gradient(ui.washBottom, { RGB(165, 235, 255), C.white }, { 0, 0.2, 1 }, 180)

	-- линии скорости из центра
	ui.speed = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Visible = false })
	ui.speedLines = {}
	for i = 1, 56 do
		local l = uiFrame(ui.speed, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.white, BackgroundTransparency = 0.2, ZIndex = 5 })
		ui.speedLines[i] = { f = l, a = rr(0, 360), r = rr(0.1, 0.9), len = rr(0.15, 0.4), sp = rr(1.2, 2.4), w = rr(0.002, 0.006) }
	end

	-- виньетка
	ui.vignette = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6, Visible = false })
	for _, v in ipairs({
		{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.22), 90 },
		{ UDim2.fromScale(0, 0.78), UDim2.fromScale(1, 0.22), 270 },
		{ UDim2.fromScale(0, 0), UDim2.fromScale(0.16, 1), 0 },
		{ UDim2.fromScale(0.84, 0), UDim2.fromScale(0.16, 1), 180 },
	}) do
		local e = uiFrame(ui.vignette, { Position = v[1], Size = v[2], BackgroundColor3 = C.black, BackgroundTransparency = 0, ZIndex = 6 })
		gradient(e, { C.black, C.black }, { 0.45, 1 }, v[3])
	end

	ui.tint = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BackgroundTransparency = 1, ZIndex = 7 })
	ui.flash = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BackgroundTransparency = 1, ZIndex = 8 })
	ui.flashGrad = gradient(ui.flash, { C.white, C.white }, nil, 0)
	ui.impact1 = buildImpact(gui, 0.5, 0.5, 1.0, true)
	ui.impact2 = buildImpact(gui, 0.62, 0.45, 0.35, false)
	ui.black = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.black, BackgroundTransparency = 1, ZIndex = 18 })

	-- стартовый экран
	ui.start = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RGB(8, 8, 14), ZIndex = 20 })
	uiText(ui.start, "TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromScale(0.8, 0.15),
		Text = 'РЮ <font color="#ff4fc0">vs</font> ЮТА', RichText = true, ZIndex = 21,
	})
	uiText(ui.start, "TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.43), Size = UDim2.fromScale(0.7, 0.045),
		Text = "фан-анимация по «Магической битве»", Font = Enum.Font.GothamBold, TextColor3 = RGB(170, 220, 255), ZIndex = 21,
	})
	ui.btn1 = button(ui.start, "▶ ЧАСТЬ 1", 0.38, 0.6, RGB(255, 60, 170))
	ui.btn2 = button(ui.start, "▶ ЧАСТЬ 2", 0.62, 0.6, RGB(40, 170, 255))
	uiText(ui.start, "TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.fromScale(0.86, 0.034),
		Text = "Сначала включи запись экрана · клавиши 1 и 2 — старт · R — повтор · графику поставь на 10",
		Font = Enum.Font.GothamBold, TextColor3 = RGB(150, 150, 170), ZIndex = 21,
	})

	-- экран после конца
	ui.endScreen = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20, Visible = false })
	ui.endText = uiText(ui.endScreen, "TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromScale(0.6, 0.07), Text = "Конец", ZIndex = 21,
	})
	ui.again = button(ui.endScreen, "↻ ЕЩЁ РАЗ (R)", 0.38, 0.56, RGB(255, 60, 170))
	ui.other = button(ui.endScreen, "▶ ДРУГАЯ ЧАСТЬ", 0.62, 0.56, RGB(40, 170, 255))
end

-- линии скорости: k — сила (0..1), t — время
local function updateSpeedLines(k, t)
	ui.speed.Visible = k > 0.01
	if k <= 0.01 then
		return
	end
	for _, l in ipairs(ui.speedLines) do
		local r = (l.r + t * l.sp) % 1
		local a = rad(l.a)
		local mid = 0.15 + r * 0.75
		l.f.Position = UDim2.fromScale(0.5 + cos(a) * mid * 0.5625, 0.5 + sin(a) * mid)
		l.f.Size = UDim2.fromScale(l.len * 0.5625 * (0.5 + r), l.w)
		l.f.Rotation = l.a
		l.f.BackgroundTransparency = 1 - k * (0.2 + 0.8 * r)
	end
end

----------------------------------------------------------------------
-- СОСТОЯНИЕ И ОБЩЕЕ ДЛЯ КАДРОВ
----------------------------------------------------------------------

local world = Instance.new("Folder")
world.Name = "RyuVsYuta"
world.Parent = workspace

local yuta, ryu, rika
local rigs = {}
local songT = 0
local playing = false
local camCF, camFOV, shake = CF(0, 2000, 0), 70, 0
local fx = {}

-- позы: {x, y, z} в градусах. Руки и хвост висят вниз: x+ — вперёд.
local POSE = {
	rikaFire = {
		spine = { -25, 0, 0 }, chest = { -20, 0, 0 }, neck = { 20, 0, 0 }, head = { -5, 0, 0 }, jaw = { -32, 0, 0 },
		shR = { 75, 0, 25 }, elR = { 35, 0, 0 }, haR = { 20, 0, 0 },
		shL = { 40, 0, -55 }, elL = { 70, 0, 0 }, haL = { 10, 0, 0 },
		tail1 = { -18, 0, 0 }, tail2 = { -18, 0, 0 }, tail3 = { -18, 0, 6 }, tail4 = { -18, 0, 8 }, tail5 = { -18, 0, 8 },
		tail6 = { -18, 0, 4 }, tail7 = { -18, 0, 0 }, tail8 = { -18, 0, 0 }, tail9 = { -18, 0, 0 },
	},
	rikaLoom = {
		spine = { -15, 0, 0 }, chest = { -15, 0, 0 }, neck = { 15, 20, 0 }, head = { 5, 25, 0 }, jaw = { -35, 0, 0 },
		shL = { 140, 0, 5 }, elL = { 5, 0, 0 }, haL = { -10, 0, 0 },
		shR = { 50, 0, 35 }, elR = { 60, 0, 0 }, haR = { 10, 0, 0 },
		tail1 = { -15, 0, 0 }, tail2 = { -15, 0, 0 }, tail3 = { -15, 0, 5 }, tail4 = { -15, 0, 5 }, tail5 = { -15, 0, 5 },
		tail6 = { -15, 0, 0 }, tail7 = { -15, 0, 0 }, tail8 = { -15, 0, 0 }, tail9 = { -15, 0, 0 },
	},
	rikaHand = {
		spine = { -10, 0, 0 }, chest = { -10, 0, 0 }, neck = { 10, 0, 0 }, jaw = { -25, 0, 0 },
		shL = { 100, 0, 0 }, elL = { 40, 0, 0 }, haL = { 60, 0, 0 },
		fL1 = { 0, 0, -20 }, fL2 = { -10, 0, -8 }, fL3 = { -10, 0, 0 }, fL4 = { -10, 0, 8 }, fL5 = { -10, 0, 16 },
		shR = { 30, 0, 30 }, elR = { 40, 0, 0 },
	},
	yutaCast = {
		root = { -4, 0, 0 }, neck = { -8, 52, 0 },
		lArm = { 122, 0, 6 }, rArm = { -28, 0, 16 }, rLeg = { 10, 0, 0 }, lLeg = { -12, 0, 0 },
	},
	yutaOrb = {
		root = { -6, 0, 0 }, neck = { -6, 50, 0 },
		lArm = { 85, 0, 10 }, rArm = { 20, 0, 20 }, rLeg = { 8, 0, 0 }, lLeg = { -10, 0, 0 },
	},
	ryuHit = {
		root = { 10, -8, -6 }, neck = { 6, 12, 8 },
		rArm = { 30, 0, 72 }, lArm = { 70, 0, -28 }, rLeg = { -14, 0, 4 }, lLeg = { 12, 0, -4 },
	},
	ryuLaugh = {
		root = { 4, 0, 0 }, neck = { -4, -18, -4 },
		rArm = { 8, 0, 10 }, lArm = { 8, 0, -10 },
	},
	ryuStand = {
		root = { -4, 0, 0 }, neck = { -2, 0, 0 },
		rArm = { 25, 0, 8 }, lArm = { 18, 0, -10 }, rLeg = { -12, 0, 6 }, lLeg = { 14, 0, -6 },
	},
	ryuLow = {
		root = { 8, 0, 0 }, neck = { 10, -20, 6 },
		rArm = { 10, 0, 12 }, lArm = { 15, 0, -15 },
	},
}

local function setLook(o)
	Lighting.ClockTime = o.clock or 0
	Lighting.Brightness = o.brightness or 1.5
	Lighting.Ambient = o.ambient or RGB(70, 80, 110)
	Lighting.OutdoorAmbient = o.outdoor or o.ambient or RGB(70, 80, 110)
	Lighting.FogColor = o.fogColor or RGB(16, 22, 44)
	Lighting.FogStart = o.fogStart or 200
	Lighting.FogEnd = o.fogEnd or 1100
	Lighting.ExposureCompensation = o.exposure or 0
	fx.cc.TintColor = o.tint or C.white
	fx.cc.Saturation = o.sat or 0
	fx.cc.Contrast = o.contrast or 0
	fx.cc.Brightness = o.bright or 0
	fx.bloom.Intensity = o.bloom or 0.8
	fx.bloom.Size = o.bloomSize or 36
	fx.bloom.Threshold = o.bloomThreshold or 0.85
	if o.dof then
		fx.dof.Enabled = true
		fx.dof.FocusDistance = o.dof[1]
		fx.dof.InFocusRadius = o.dof[2]
		fx.dof.FarIntensity = o.dof[3]
		fx.dof.NearIntensity = o.dof[4] or 0
	else
		fx.dof.Enabled = false
	end
end

-- поставить риг так, чтобы кость boneName оказалась в точке/повороте want
local function placeBoneAt(rig, boneName, want)
	rig:place(CF())
	rig:update(songT)
	local rel = rig.bones[boneName].world
	rig:place(want * rel:Inverse())
	rig:update(songT)
end

local function beginShot(t0)
	updaters = {}
	if Shot.folder then
		Shot.folder:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "Shot"
	f.Parent = world
	Shot.folder = f
	Shot.anchor = newPart(f, V3(0.2, 0.2, 0.2), C.white, CF(), { alpha = 1 })
	Shot.debris = Instance.new("Model")
	Shot.debris.Name = "Debris"
	Shot.debris.Parent = f
	outline(Shot.debris, nil, 1)
	Shot.t0 = t0
	Shot.update = nil
	shake = 0
	for _, r in ipairs(rigs) do
		r:show(false)
		for _, name in ipairs({ "root", "neck", "coat" }) do
			if r.bones[name] and r ~= rika then
				r.bones[name].wob = nil
			end
		end
	end
	ui.flash.BackgroundTransparency = 1
	ui.flash.BackgroundColor3 = C.white
	ui.flashGrad.Color = ColorSequence.new(C.white, C.white)
	ui.flashGrad.Rotation = 0
	ui.tint.BackgroundTransparency = 1
	ui.washTop.BackgroundTransparency = 1
	ui.washBottom.BackgroundTransparency = 1
	ui.impact1.Visible = false
	ui.impact2.Visible = false
	ui.vignette.Visible = true
	ui.speed.Visible = false
	Shot.blur = 0
	return f
end

----------------------------------------------------------------------
-- ЧАСТЬ 1 (0:00–0:11)
----------------------------------------------------------------------

local P1 = {}

-- 0.00–4.83: глаза Юты (сверху) и Рю (снизу)
function P1.eyes()
	beginShot(0)
	setLook({ clock = 12, brightness = 0, ambient = C.white, outdoor = C.white, fogStart = 100000, fogEnd = 100001,
		bloom = 0.2, bloomThreshold = 0.97, sat = 0.06, contrast = 0.05 })
	ui.vignette.Visible = false
	local S0 = STAGE.eyes
	local cam0 = CFrame.lookAt(S0 + V3(0, 0, -EYES.camDist), S0)
	camCF, camFOV = cam0, 20
	Shot.update = function(u)
		local k = smooth(u / T1.WHITE)
		camFOV = lerp(20, 18.9, k)
		local j = 0.04 + 0.12 * clamp01((u - 3.4) / 1.2)
		camCF = cam0 * CF(noise(u * 6, 1.1) * j, noise(u * 6, 2.2) * j, 0)
		local g = easeIn(clamp01((u - T1.GLOW) / (T1.WHITE - T1.GLOW)))
		ui.washTop.BackgroundTransparency = 1 - g * 0.9
		ui.washBottom.BackgroundTransparency = 1 - g * 0.9
		ui.flash.BackgroundTransparency = 1 - easeIn(clamp01((u - 4.6) / (T1.WHITE - 4.6)))
	end
end

-- 4.83–7.83: вспышка и столкновение лучей; Рика справа сверху бьёт из пасти
function P1.clash()
	local f = beginShot(T1.WHITE)
	setLook({ clock = 0, brightness = 1.2, ambient = RGB(95, 115, 112), outdoor = RGB(85, 105, 108), tint = RGB(232, 255, 244),
		sat = 0.4, contrast = 0.18, bright = 0.02, bloom = 1.4, bloomSize = 40, bloomThreshold = 0.8,
		fogColor = RGB(14, 30, 34), fogStart = 120, fogEnd = 700 })
	ui.flashGrad.Color = CS({ { 0, RGB(110, 240, 180) }, { 0.5, C.white }, { 1, RGB(255, 140, 215) } })
	ui.flashGrad.Rotation = 15
	ui.flash.BackgroundTransparency = 0
	local P = CLASH_POINT
	local cam0 = CFrame.lookAt(P + V3(-15, -7, -38), P + V3(1, 2, 0)) * ANG(0, 0, rad(-8))
	local cam1 = CFrame.lookAt(P + V3(-12, -6, -31), P + V3(1, 2.5, 0)) * ANG(0, 0, rad(-10))
	camCF, camFOV = cam0, 72

	local rp = cam0 * V3(64, 24, -66)
	rika:show(true)
	rika:place(CFrame.lookAt(rp, V3(P.X, rp.Y, P.Z)))
	rika:pose(POSE.rikaFire, 0)
	rika:update(songT)
	newPart(f, V3(32, 80, 28), RGB(34, 40, 44), CF(rp.X, rp.Y - 14 - 40, rp.Z + 4) * ANG(0, rad(20), 0), { material = Enum.Material.Concrete })
	for _ = 1, 4 do
		newPart(f, V3(0.6, 0.6, rr(8, 14)), C.red, CF(rp + V3(rr(-12, 12), -rr(12, 20), rr(-8, 8))) * ANG(rr(-1, 1), rr(0, 6), rr(-1, 1)))
	end

	local pink = FX.energyBeam(C.pink, 2.2)
	local cyan = FX.energyBeam(C.cyan, 2.8)
	local cyanFrom = cam0 * V3(-34, -19, -20)
	local core = FX.glow(P, 26, C.yellow, 0.17, 3)
	local halo = FX.glow(P, 64, RGB(255, 240, 205), 0.06, 1.5)
	local rays = FX.rays(P, 22, { C.yellow, C.white, C.pinkHot, C.cyan, C.gold }, 10, 34, 1.6)
	FX.emitter(P, V3(3, 3, 3), {
		rate = 70, life = { 0.12, 0.25 }, speed = { 2, 6 }, sphere = true, brightness = 4,
		size = NS({ { 0, 9 }, { 1, 16 } }), alpha = NS({ { 0, 0.35 }, { 1, 1 } }), color = CS({ { 0, C.white }, { 1, C.yellow } }),
	})
	FX.sparks(P, { C.yellow, C.white }, 280, 70, 0.7)
	FX.smoke(cam0 * V3(-40, 22, -75), V3(50, 20, 20), CS({ { 0, RGB(40, 150, 115) }, { 1, RGB(30, 90, 80) } }), 6, 40, 3, 4, { burst = 12 })
	FX.smoke(cam0 * V3(35, -24, -60), V3(40, 10, 20), ColorSequence.new(RGB(46, 66, 52)), 5, 34, 3, 3, { burst = 8 })
	local bolts = { FX.bolt(C.cyan, 0.12), FX.bolt(C.yellow, 0.1), FX.bolt(RGB(230, 255, 255), 0.1), FX.bolt(C.white, 0.08) }

	local toCam = (cam0.Position - P).Unit
	local function spawn(kind)
		local dir = (toCam * 0.9 + V3(rr(-1, 1), rr(-0.7, 1), rr(-1, 1))).Unit
		if kind == "shard" then
			FX.flyer(V3(0.15, rr(0.8, 2.8), rr(1.2, 4.5)), pick({ C.yellow, C.gold, RGB(255, 246, 205) }), P + dir * rr(2, 5), dir * rr(28, 62),
				{ neon = true, wedge = true, life = rr(0.55, 1.0), spin = 9 })
		elseif kind == "rock" then
			FX.flyer(V3(rr(0.7, 2.6), rr(0.6, 2.2), rr(0.7, 2.6)), C.rock, P + dir * rr(3, 6), dir * rr(18, 40),
				{ material = Enum.Material.Slate, life = rr(0.9, 1.4), spin = 5, gravity = 18 })
		elseif kind == "girder" then
			local side = (cam0.RightVector * rr(-1, 1) + cam0.UpVector * rr(-0.3, 1)).Unit
			FX.flyer(V3(0.35, 0.35, rr(2.5, 6)), C.red, P + side * rr(3, 6), side * rr(14, 28), { life = rr(1, 1.6), spin = 4, gravity = 10 })
		elseif kind == "teal" then
			FX.flyer(V3(0.12, rr(0.6, 1.8), rr(0.8, 2.6)), RGB(120, 245, 228), P + dir * rr(4, 10), dir * rr(22, 48),
				{ neon = true, wedge = true, life = 0.9, spin = 7 })
		else
			FX.flyer(V3(0.1, rr(0.5, 1.4), rr(0.5, 1.6)), RGB(20, 40, 45), P + dir * rr(4, 10), dir * rr(20, 40), { wedge = true, life = 0.9, spin = 7 })
		end
	end

	local acc = { shard = 0, rock = 0, girder = 0, teal = 0, dark = 0 }
	local tBolt, tRing, tReroll = 0, 0, 0
	local teal = nil
	local w = T1.CLASH - T1.WHITE
	Shot.update = function(u, dt)
		local k = smooth(u / (T1.CITY - T1.WHITE))
		camCF = cam0:Lerp(cam1, k)
		camFOV = lerp(72, 64, k)
		if u < w then
			ui.flash.BackgroundTransparency = lerp(0, 0.5, u / w)
			Shot.blur = lerp(26, 6, u / w)
			shake = 1.7
		else
			ui.flash.BackgroundTransparency = clamp01(0.5 + (u - w) * 3.5)
			Shot.blur = math.max(0, 6 - (u - w) * 30)
			shake = 0.8 + 0.25 * sin(u * 31)
		end
		pink.set(rika.mouth(), P, 2.1 + sin(u * 50) * 0.3)
		cyan.set(cyanFrom, P, 2.8 + sin(u * 43 + 1) * 0.4)
		local pulse = 1 + sin(u * 40) * 0.12
		core.set(nil, 26 * pulse)
		halo.set(nil, 64 * (1 + sin(u * 23) * 0.08))
		rays.update(u)
		tReroll = tReroll - dt
		if tReroll <= 0 then
			tReroll = 0.12
			rays.reroll(0.25)
		end
		tBolt = tBolt - dt
		if tBolt <= 0 then
			tBolt = 0.05
			for _, b in ipairs(bolts) do
				b.strike(P, P + V3(rr(-1, 1), rr(-0.6, 1), rr(-1, 1)).Unit * rr(16, 34), 1.8)
			end
		end
		tRing = tRing - dt
		if tRing <= 0 then
			tRing = 0.3
			FX.ring(P, C.white, 6, 46, 0.45, 10)
		end
		local late = u > (T1.TEAL - T1.WHITE)
		local rates = { shard = 48, rock = 15, girder = 4, teal = 0, dark = 0 }
		if u < w then
			rates = { shard = 18, rock = 4, girder = 1, teal = 0, dark = 0 }
		elseif late then
			rates = { shard = 20, rock = 6, girder = 2, teal = 45, dark = 25 }
		end
		for kind, rate in pairs(rates) do
			acc[kind] = acc[kind] + rate * dt
			while acc[kind] >= 1 do
				acc[kind] = acc[kind] - 1
				spawn(kind)
			end
		end
		if late then
			local g = clamp01((u - (T1.TEAL - T1.WHITE)) / (T1.CITY - T1.TEAL))
			if not teal then
				teal = FX.glow(P, 20, C.teal, 0.12, 2)
			end
			teal.set(nil, lerp(20, 140, easeOut(g)), 0.6 + g)
			ui.tint.BackgroundColor3 = RGB(90, 235, 215)
			ui.tint.BackgroundTransparency = lerp(1, 0.5, g)
			shake = lerp(0.9, 1.7, g)
		end
	end
end

-- 7.83–8.70: общий план ночного города, розово-голубой взрыв
function P1.city()
	local f = beginShot(T1.CITY)
	setLook({ clock = 0, brightness = 1.2, ambient = RGB(92, 118, 132), outdoor = RGB(86, 112, 128), tint = RGB(222, 236, 255),
		sat = 0.28, contrast = 0.14, bright = 0.02, bloom = 1.1, bloomSize = 40, fogColor = RGB(16, 22, 44), fogStart = 160, fogEnd = 1100 })
	local P = CLASH_POINT + V3(0, -4, 0)
	local cam0 = CFrame.lookAt(CITY_CAM, P + V3(0, 26, 0))
	local cam1 = CFrame.lookAt(CITY_CAM + (P - CITY_CAM).Unit * 16, P + V3(0, 27, 0))
	camCF, camFOV = cam0, 46
	local right, up = cam0.RightVector, cam0.UpVector
	local pinkCS = CS({ { 0, RGB(255, 150, 230) }, { 1, RGB(170, 60, 200) } })
	local cyanCS = CS({ { 0, RGB(170, 250, 255) }, { 1, RGB(40, 170, 230) } })
	FX.smoke(P - right * 16 + up * 18, V3(26, 30, 14), pinkCS, 40, 48, 1.6, 12, { emission = 0.6, brightness = 2, burst = 30, alpha = NS({ { 0, 0.5 }, { 0.5, 0.35 }, { 1, 1 } }), spread = 80 })
	FX.smoke(P + right * 16 + up * 18, V3(26, 30, 14), cyanCS, 40, 48, 1.6, 12, { emission = 0.6, brightness = 2, burst = 30, alpha = NS({ { 0, 0.5 }, { 0.5, 0.35 }, { 1, 1 } }), spread = 80 })
	FX.smoke(P + up * 40, V3(14, 20, 14), ColorSequence.new(RGB(215, 190, 250)), 16, 40, 2, 22, { emission = 0.4, burst = 10, spread = 20 })
	local core = FX.glow(P + up * 8, 46, RGB(255, 235, 255), 0.16, 3)
	FX.glow(P - right * 14 + up * 22, 70, C.pink, 0.08, 2)
	FX.glow(P + right * 14 + up * 22, 70, C.cyan, 0.08, 2)
	FX.emitter(P + up * 20, V3(40, 40, 10), {
		rate = 60, life = { 0.6, 1.1 }, speed = { 4, 12 }, size = NS({ { 0, 1.2 }, { 1, 0 } }), brightness = 4,
		color = CS({ { 0, C.pinkHot }, { 0.5, C.white }, { 1, C.cyan } }), burst = 40,
	})
	for _ = 1, 170 do
		local side = 1
		if rng:NextNumber() < 0.5 then
			side = -1
		end
		local col = C.pinkHot
		if side > 0 then
			col = pick({ C.cyan, RGB(150, 245, 255) })
		end
		local dir = (right * side * rr(0.2, 1) + up * rr(0.1, 1.2) + cam0.LookVector * rr(-0.5, 0.5)).Unit
		FX.flyer(V3(rr(1.2, 3.6), rr(0.8, 2.6), 0.15), col, P + up * rr(4, 34) + dir * rr(0, 14), dir * rr(8, 30),
			{ neon = true, life = rr(0.8, 1.2), spin = 3, gravity = 4 })
	end
	local tStreak = 0
	Shot.update = function(u, dt)
		local k = u / (T1.YUTA - T1.CITY)
		camCF = cam0:Lerp(cam1, smooth(k))
		shake = 0.22
		core.set(nil, 46 * (1 + 0.1 * sin(u * 20)))
		tStreak = tStreak - dt
		if tStreak <= 0 then
			tStreak = 0.05
			local from = P + up * rr(10, 40) + right * rr(0, 20)
			FX.streak(from, (right + up * rr(0.4, 0.8)).Unit, rr(18, 34), rr(90, 150), 0.45, RGB(150, 245, 255), rr(0.4, 0.8), 4)
		end
	end
end

-- 8.70–10.00: Юта вытягивает руку, за спиной огромная Рика
function P1.yuta()
	local f = beginShot(T1.YUTA)
	setLook({ clock = 0, brightness = 1, ambient = RGB(255, 215, 240), outdoor = RGB(255, 205, 235), tint = RGB(255, 236, 250),
		sat = 0.25, contrast = 0.14, bright = 0.02, bloom = 1.0, dof = { 8.5, 6, 0.35 } })
	local base = STAGE.yuta1
	local cam0 = CFrame.lookAt(base, base + V3(0, 0.08, -1))
	local cam1 = cam0 * CF(-0.3, 0.1, -0.6)
	camCF, camFOV = cam0, 52
	FX.backdrop(cam0 * CF(0, 0, -240) * ANG(0, math.pi, 0), 900, 600, { RGB(255, 175, 232), RGB(205, 60, 170), RGB(120, 20, 110) }, 120)
	FX.glow(cam0 * V3(-60, 35, -180), 160, RGB(255, 190, 240), 0.08, 1.5)

	yuta:show(true)
	yuta:place(cam0 * CF(1.1, -4.5, -8.0) * ANG(0, rad(112), 0))
	yuta:pose(POSE.yutaCast, 0)
	rika:show(true)
	rika:place(cam0 * CF(8, -5.5, -17) * ANG(0, rad(105), 0))
	rika:pose(POSE.rikaLoom, 0)
	yuta:update(songT)
	rika:update(songT)

	local hand = yuta:point("lArm", V3(0, -1.6, 0))
	local armDir = (hand - yuta:point("lArm", V3(0, 0, 0))).Unit
	local hit = hand + armDir * 2.2
	local glow = FX.glow(hit, 4.5, C.pink, 0.16, 3)
	local rays = FX.rays(hit, 16, { C.pinkHot, C.white, C.pink }, 2, 8, 0.45, { bias = (armDir + V3(-0.3, 0.3, 0)) * 0.7 })
	FX.sparks(hit, { C.pinkHot, C.white }, 120, 22, 0.25)
	FX.emitter(cam0 * V3(0, 0, -12), V3(26, 16, 6), {
		rate = 30, life = { 1, 2 }, speed = { 0.5, 2 }, size = NS({ { 0, 0.25 }, { 0.5, 0.35 }, { 1, 0 } }), brightness = 3,
		color = ColorSequence.new(RGB(255, 190, 240)), burst = 30,
	})
	local sdir = (cam0.RightVector * -1 + cam0.UpVector * -0.5).Unit
	local tStreak, tRing = 0, 0
	Shot.update = function(u, dt)
		local k = smooth(u / (T1.RYU - T1.YUTA))
		camCF = cam0:Lerp(cam1, k)
		shake = 0.16 + 0.08 * sin(u * 20)
		glow.set(nil, 4.5 * (1 + sin(u * 37) * 0.15))
		rays.update(u)
		if floor(u * 9) ~= floor((u - dt) * 9) then
			rays.reroll(0.3)
		end
		tRing = tRing - dt
		if tRing <= 0 then
			tRing = 0.35
			FX.ring(hit, C.pinkHot, 1.5, 9, 0.4, 6)
		end
		tStreak = tStreak - dt
		if tStreak <= 0 then
			tStreak = 0.07
			local depth = rr(4.6, 6.5)
			local off = rr(-3.5, 3.5)
			local from = cam0 * V3(0, 0, -depth) + (cam0.RightVector * 0.5 + cam0.UpVector * -1).Unit * off - sdir * 14
			local col, wdt = C.cyan, rr(0.22, 0.42)
			if rng:NextNumber() < 0.35 then
				col, wdt = RGB(255, 222, 150), rr(0.16, 0.3)
			end
			FX.streak(from, sdir, rr(7, 12), rr(30, 45), 0.8, col, wdt, 4)
		end
	end
end

-- 10.00–11.17: Рю отбрасывает голубым взрывом
function P1.ryu()
	local f = beginShot(T1.RYU)
	setLook({ clock = 0, brightness = 1, ambient = RGB(150, 185, 235), outdoor = RGB(140, 175, 230), tint = RGB(218, 236, 255),
		sat = 0.35, contrast = 0.16, bright = 0.02, bloom = 1.1, dof = { 8.4, 5, 0.3 } })
	ui.flash.BackgroundTransparency = 0.3
	local base = STAGE.ryu1
	local cam0 = CFrame.lookAt(base, base + V3(0, 0.12, -1)) * ANG(0, 0, rad(6))
	local cam1 = cam0 * CF(0.2, 0.1, -0.7)
	camCF, camFOV = cam0, 56
	FX.backdrop(cam0 * CF(0, 0, -240) * ANG(0, math.pi, 0), 900, 600, { RGB(40, 90, 190), RGB(14, 36, 100), RGB(8, 18, 60) }, 70)

	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "grin")
	ryu:place(cam0 * CF(-1.0, -3.7, -8.4) * ANG(0, rad(164), 0))
	ryu:pose(POSE.ryuHit, 0)
	ryu:update(songT)
	ryu:pose({ root = { 16, -8, -8 }, neck = { 12, 12, 10 }, rArm = { 46, 0, 82 }, lArm = { 86, 0, -36 }, rLeg = { -18, 0, 4 }, lLeg = { 16, 0, -4 } }, 1.17, songT)

	local face = ryu:point("neck", V3(0, 0.7, 0))
	local hit = face + cam0.RightVector * 2.2 + cam0.UpVector * 1.0 - cam0.LookVector * 0.4
	local glow = FX.glow(hit, 3, C.cyan, 0.18, 4)
	local halo = FX.glow(hit, 10, C.cyanDeep, 0.07, 2)
	local rays = FX.rays(hit, 18, { C.cyan, C.white, RGB(160, 240, 255), C.pinkHot }, 1.5, 6.5, 0.32)
	FX.sparks(hit, { C.cyan, C.white }, 160, 18, 0.22)
	FX.emitter(cam0 * V3(-2.5, 0, -6.5), V3(5, 6, 2), {
		rate = 40, life = { 0.2, 0.45 }, speed = { 0.5, 2 }, size = NS({ { 0, 0.18 }, { 1, 0 } }), brightness = 4,
		color = ColorSequence.new(RGB(255, 90, 210)),
	})
	local toCam = (cam0.Position - hit).Unit
	local acc = { shard = 0, streak = 0 }
	Shot.update = function(u, dt)
		local k = smooth(u / (T1.FIN - T1.RYU))
		camCF = cam0:Lerp(cam1, k)
		shake = lerp(1.0, 0.45, k)
		ui.flash.BackgroundTransparency = clamp01(0.3 + u * 6)
		local pulse = 1 + sin(u * 35) * 0.15 + u * 0.35
		glow.set(nil, 3 * pulse)
		halo.set(nil, 10 * (1 + u * 0.45))
		rays.scale = 1 + u * 0.4
		rays.update(u)
		if floor(u * 10) ~= floor((u - dt) * 10) then
			rays.reroll(0.3)
		end
		acc.shard = acc.shard + 60 * dt
		while acc.shard >= 1 do
			acc.shard = acc.shard - 1
			local dir = (toCam * 0.5 + cam0.RightVector * rr(-0.4, 1.2) + V3(rr(-1, 1), rr(-0.8, 1), rr(-1, 1))).Unit
			FX.flyer(V3(0.06, rr(0.2, 0.6), rr(0.3, 0.9)), pick({ C.cyan, RGB(140, 240, 255), RGB(90, 210, 255) }), hit + dir * rr(0.4, 1.5), dir * rr(7, 16),
				{ neon = true, wedge = true, life = rr(0.5, 1.0), spin = 6 })
		end
		acc.streak = acc.streak + 6 * dt
		while acc.streak >= 1 do
			acc.streak = acc.streak - 1
			local pos = cam0 * V3(rr(2, 5), rr(-2.5, 2), -rr(6, 8))
			FX.streak(pos, (cam0.RightVector * -1 + cam0.UpVector * 0.35).Unit, rr(2.5, 4.5), 22, 0.35, RGB(255, 225, 140), 0.16, 4)
		end
	end
end

P1.shots = {
	{ 0, P1.eyes }, { T1.WHITE, P1.clash }, { T1.CITY, P1.city }, { T1.YUTA, P1.yuta }, { T1.RYU, P1.ryu },
}
P1.fin = T1.FIN

----------------------------------------------------------------------
-- ЧАСТЬ 2 (0:00–0:15)
----------------------------------------------------------------------

local P2 = {}
local RAINBOW = { C.pink, C.cyan, C.yellow, C.orange, C.blue, C.white, C.pinkHot }

-- радужный взрыв: лучи, цветной дым, осколки летят в камеру
local function rainbowBurst(P, cam0, scale)
	local rays = FX.rays(P, 40, RAINBOW, 18 * scale, 70 * scale, 2.4 * scale, { brightness = 2.5, colorStart = true, start = 5 })
	local core = FX.glow(P, 13 * scale, RGB(255, 225, 245), 0.16, 3)
	FX.smoke(P, V3(30, 30, 30) * scale, CS({ { 0, C.pinkHot }, { 0.5, RGB(120, 80, 255) }, { 1, C.cyan } }), 26, 40 * scale, 1.4, 16 * scale,
		{ emission = 0.5, brightness = 1.6, burst = 24, spread = 180, alpha = NS({ { 0, 0.6 }, { 0.4, 0.55 }, { 1, 1 } }) })
	FX.sparks(P, { C.yellow, C.pinkHot }, 160, 80 * scale, 0.7 * scale)
	local bolts = { FX.bolt(C.cyan, 0.15), FX.bolt(C.pinkHot, 0.15), FX.bolt(C.yellow, 0.12) }
	local toCam = (cam0.Position - P).Unit
	local obj = { rays = rays, core = core }
	local acc, tb = 0, 0
	function obj.update(u, dt, rate)
		rays.update(u)
		if floor(u * 8) ~= floor((u - dt) * 8) then
			rays.reroll(0.3)
		end
		core.set(nil, 13 * scale * (1 + 0.12 * sin(u * 30)))
		tb = tb - dt
		if tb <= 0 then
			tb = 0.06
			for _, b in ipairs(bolts) do
				b.strike(P, P + randUnit() * rr(20, 45) * scale, 2.5 * scale)
			end
		end
		acc = acc + (rate or 60) * dt
		while acc >= 1 do
			acc = acc - 1
			local dir = (toCam * 0.8 + randUnit()).Unit
			if rng:NextNumber() < 0.25 then
				FX.flyer(V3(0.15, rr(1, 3), rr(1.5, 4.5)) * scale, RGB(16, 16, 30), P + dir * rr(3, 8), dir * rr(40, 80) * scale,
					{ wedge = true, life = rr(0.6, 1), spin = 8 })
			else
				FX.flyer(V3(0.15, rr(1, 3), rr(1.5, 4.5)) * scale, pick(RAINBOW), P + dir * rr(3, 8), dir * rr(40, 90) * scale,
					{ neon = true, wedge = true, life = rr(0.5, 0.9), spin = 9 })
			end
		end
	end
	return obj
end

-- 0.00–3.20: внутри столкновения — радужный взрыв
function P2.vortex()
	beginShot(0)
	setLook({ clock = 0, brightness = 1, ambient = RGB(90, 90, 140), tint = RGB(245, 240, 255), sat = 0.5, contrast = 0.2,
		bloom = 1.5, bloomSize = 44, bloomThreshold = 0.8 })
	local S0 = STAGE.vortex
	local cam0 = CFrame.lookAt(S0 + V3(0, 0, 34), S0)
	camCF, camFOV = cam0, 75
	FX.backdrop(CF(S0 + V3(0, 0, -160)), 900, 600, { RGB(30, 40, 120), RGB(60, 20, 90), RGB(10, 10, 40) }, 45)
	local burst = rainbowBurst(S0, cam0, 1)
	local tStreak = 0
	Shot.update = function(u, dt)
		local k = smooth(u / T2.LAUGH)
		camCF = cam0 * CF(0, 0, -10 * k) * ANG(0, 0, rad(10 * sin(u * 1.3)))
		shake = 1.3 + 0.4 * sin(u * 9)
		burst.update(u, dt, 70)
		tStreak = tStreak - dt
		if tStreak <= 0 then
			tStreak = 0.03
			local d = randUnit()
			FX.streak(S0 + d * 4, d, rr(15, 30), rr(80, 140), 0.5, pick(RAINBOW), rr(0.5, 1.4), 4)
		end
		local fl = math.max(0, 1 - abs(u - 1.45) * 12) + math.max(0, 1 - abs(u - 2.05) * 12)
		ui.flash.BackgroundTransparency = 1 - clamp01(fl) * 0.55
		updateSpeedLines(0.35, u)
	end
end

-- 3.20–7.90: Рю смеётся, по нему бежит голубая энергия
function P2.laugh()
	local f = beginShot(T2.LAUGH)
	setLook({ clock = 0, brightness = 1, ambient = RGB(175, 200, 215), outdoor = RGB(170, 198, 215), tint = RGB(228, 246, 255),
		sat = 0.2, contrast = 0.16, bloom = 1.0, dof = { 5.8, 4, 0.45 } })
	local S0 = STAGE.laugh
	local cam0 = CFrame.lookAt(S0, S0 + V3(0, -0.02, -1))
	local cam1 = cam0 * CF(-0.12, 0.03, -0.7)
	camCF, camFOV = cam0, 40
	FX.backdrop(cam0 * CF(0, 0, -200) * ANG(0, math.pi, 0), 700, 500, { RGB(40, 110, 120), RGB(12, 40, 50), RGB(4, 14, 22) }, 60)
	for i = 1, 6 do
		FX.glow(cam0 * V3(rr(-60, 60), rr(-30, 40), -rr(120, 180)), rr(10, 26), pick({ C.cyan, RGB(90, 200, 255), RGB(140, 255, 230) }), 0.06, 1.5)
	end
	local light = newPart(f, V3(1, 1, 1), C.white, cam0 * CF(5, 1, -5), { alpha = 1 })
	local pl = Instance.new("PointLight")
	pl.Color = C.cyan
	pl.Brightness = 3
	pl.Range = 14
	pl.Parent = light

	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "smirk")
	ryu:place(cam0 * CF(0.45, -4.95, -5.8) * ANG(0, rad(158), 0))
	ryu:pose(POSE.ryuLaugh, 0)
	ryu:update(songT)
	local bob = 0
	ryu.bones.neck.wob = function(t)
		return ANG(rad(bob * 6 * sin(t * 18)), 0, rad(bob * 2 * sin(t * 9)))
	end
	ryu.bones.root.wob = function(t)
		return CF(0, bob * 0.04 * sin(t * 18), 0)
	end

	-- голубая энергия справа
	local side = cam0 * V3(2.9, -0.9, -6.0)
	FX.emitter(side, V3(1.5, 3, 1.5), {
		texture = TEX.fire, rate = 50, life = { 0.4, 0.8 }, speed = { 2, 5 }, spread = 25,
		size = NS({ { 0, 1.4 }, { 1, 0.2 } }), color = CS({ { 0, RGB(220, 255, 255) }, { 1, C.cyanDeep } }), brightness = 4, accel = V3(0, 3, 0),
	})
	local glow = FX.glow(side + V3(0, 0.8, 0), 6, C.cyan, 0.12, 3)
	local bolts = { FX.bolt(C.cyan, 0.05), FX.bolt(RGB(200, 255, 255), 0.04) }
	FX.emitter(cam0 * V3(1.5, 0, -6.8), V3(5, 4, 1), {
		rate = 40, life = { 0.4, 0.9 }, speed = { 0.5, 2 }, size = NS({ { 0, 0.12 }, { 1, 0 } }), brightness = 5,
		color = ColorSequence.new(RGB(170, 245, 255)),
	})
	-- голубые мазки через лицо
	local face = ryu:point("neck", V3(0, 0.55, -0.7))
	local strokes = {}
	for i = 1, 3 do
		local a0, a1 = FX.att(), FX.att()
		strokes[i] = { a0 = a0, a1 = a1, b = FX.beam(a0, a1, ColorSequence.new(RGB(90, 210, 255), C.cyan), 0.12, 0.04,
			{ brightness = 4, alpha = NS({ { 0, 0.6 }, { 0.3, 0.1 }, { 1, 0.9 } }) }), ph = rr(0, 6), y = rr(-0.5, 0.6) }
	end
	local schedule = { { 0, "smirk" }, { 0.8, "grin" }, { 1.2, "laugh" }, { 2.5, "grin" }, { 3.1, "smirk" }, { 3.8, "grin" } }
	local current = ""
	local tb = 0
	Shot.update = function(u, dt)
		local k = smooth(u / (T2.ZOOM - T2.LAUGH))
		camCF = cam0:Lerp(cam1, k) * CF(noise(u * 1.5, 7) * 0.05, noise(u * 1.5, 8) * 0.05, 0)
		shake = 0.06
		local m = "smirk"
		for _, s in ipairs(schedule) do
			if u >= s[1] then
				m = s[2]
			end
		end
		if m ~= current then
			current = m
			showVariant(ryu.tags, "mouth_", m)
		end
		local target = 0
		if m == "laugh" then
			target = 1
		end
		bob = lerp(bob, target, clamp01(dt * 8))
		glow.set(nil, 6 * (1 + 0.2 * sin(u * 14)))
		tb = tb - dt
		if tb <= 0 then
			tb = 0.07
			for _, b in ipairs(bolts) do
				b.strike(side + V3(0, rr(-1, 2), 0), side + V3(rr(-3, 1), rr(1, 4), rr(-1, 1)), 0.5)
			end
		end
		for i, s in ipairs(strokes) do
			local x = sin(u * 0.8 + s.ph) * 0.8
			local p0 = face + cam0.RightVector * (x - 1.2) + cam0.UpVector * s.y
			s.a0.Position = p0
			s.a1.Position = p0 + (cam0.RightVector * 2.2 + cam0.UpVector * (0.3 - i * 0.1))
		end
	end
end

-- 7.90–8.55: радужный рывок вперёд
function P2.zoom()
	beginShot(T2.ZOOM)
	setLook({ clock = 0, brightness = 1, ambient = RGB(100, 100, 150), tint = RGB(255, 245, 255), sat = 0.5, contrast = 0.15, bloom = 1.6, bloomSize = 50 })
	local S0 = STAGE.zoom
	local cam0 = CFrame.lookAt(S0 + V3(0, 0, 60), S0)
	camCF, camFOV = cam0, 80
	FX.backdrop(CF(S0 + V3(0, 0, -200)), 900, 600, { RGB(60, 30, 110), RGB(20, 20, 60) }, 90)
	local core = FX.glow(S0, 8, RGB(255, 240, 200), 0.16, 3)
	local zrays = FX.rays(S0, 34, RAINBOW, 30, 90, 3, { brightness = 2.5, colorStart = true, start = 6 })
	FX.smoke(S0, V3(40, 40, 40), CS({ { 0, C.pinkHot }, { 0.5, C.cyan }, { 1, C.yellow } }), 30, 60, 1.2, 20, { emission = 0.7, brightness = 2.5, burst = 30, spread = 180 })
	Shot.update = function(u, dt)
		camCF = cam0 * CF(0, 0, -50 * easeIn(u / (T2.IMPACT1 - T2.ZOOM))) * ANG(0, 0, rad(u * 25))
		camFOV = lerp(80, 95, u / 0.65)
		Shot.blur = 10
		shake = 1
		core.set(nil, 8 + u * 20)
		zrays.update(u)
		for _ = 1, 3 do
			local a = rr(0, math.pi * 2)
			local r = rr(4, 14)
			local from = S0 + V3(cos(a) * r, sin(a) * r, rr(-30, 0))
			FX.streak(from, V3(0, 0, 1), rr(10, 20), rr(120, 200), 0.35, pick(RAINBOW), rr(0.3, 0.9), 4)
		end
		updateSpeedLines(0.9, u * 2)
	end
end

-- 8.55–8.65 и 10.30–10.40: чёрный кадр с белой кляксой
local function impactShot(t0, key)
	return function()
		beginShot(t0)
		camCF = CF(0, 3000, 0)
		ui.vignette.Visible = false
		ui[key].Visible = true
	end
end
P2.impact1 = impactShot(T2.IMPACT1, "impact1")
P2.impact2 = impactShot(T2.IMPACT2, "impact2")

-- 8.65–9.20: жёлтый взрыв, потом смаз с силуэтом Юты
function P2.burst()
	beginShot(T2.BURST)
	setLook({ clock = 0, brightness = 1, ambient = RGB(255, 200, 220), tint = RGB(255, 245, 230), sat = 0.45, contrast = 0.12, bloom = 1.6, bloomSize = 50 })
	local S0 = STAGE.zoom + V3(0, 0, -500)
	local cam0 = CFrame.lookAt(S0 + V3(0, 0, 30), S0)
	camCF, camFOV = cam0, 70
	FX.backdrop(CF(S0 + V3(0, 0, -150)), 900, 600, { RGB(255, 120, 200), RGB(60, 160, 255), RGB(255, 220, 120) }, 30)
	local burst = rainbowBurst(S0, cam0, 0.8)
	local yellow = FX.glow(S0, 12, C.yellow, 0.18, 4)
	yuta:show(true)
	yuta:place(cam0 * CF(9, -4, -12) * ANG(0, rad(130), 0))
	yuta:pose(POSE.yutaOrb, 0)
	yuta:update(songT)
	Shot.update = function(u, dt)
		camCF = cam0 * CF(0, 0, -6 * u) * ANG(0, 0, rad(-6 * u))
		shake = 1.2
		burst.update(u, dt, 50)
		yellow.set(nil, 12 * (1 + 0.3 * sin(u * 25)))
		local blurPhase = clamp01((u - (T2.BLUR - T2.BURST)) / 0.08)
		Shot.blur = lerp(4, 22, blurPhase)
		yuta:show(blurPhase > 0)
		updateSpeedLines(0.5 * (1 - blurPhase), u)
	end
end

-- 9.20–9.55: Юта с голубым сгустком, над ним огромная Рика
function P2.yutaRika()
	local f = beginShot(T2.YUTARIKA)
	setLook({ clock = 0, brightness = 1, ambient = RGB(200, 190, 235), outdoor = RGB(190, 185, 230), tint = RGB(240, 235, 255),
		sat = 0.3, contrast = 0.15, bloom = 1.2, dof = { 9.5, 7, 0.3 } })
	local base = STAGE.yuta2
	local cam0 = CFrame.lookAt(base, base + V3(0, 0.1, -1))
	local cam1 = cam0 * CF(0.2, 0, -0.5)
	camCF, camFOV = cam0, 56
	FX.backdrop(cam0 * CF(0, 0, -240) * ANG(0, math.pi, 0), 900, 600, { RGB(150, 120, 210), RGB(70, 50, 130), RGB(30, 20, 70) }, 110)
	yuta:show(true)
	yuta:place(cam0 * CF(3.2, -4.9, -9.5) * ANG(0, rad(118), 0))
	yuta:pose(POSE.yutaOrb, 0)
	rika:show(true)
	rika:place(cam0 * CF(2.5, -6.5, -20) * ANG(0, rad(128), 0))
	rika:pose(POSE.rikaLoom, 0)
	yuta:update(songT)
	rika:update(songT)
	local hand = yuta:point("lArm", V3(0, -1.6, 0))
	local orb = hand + (cam0.RightVector * -2.2 + cam0.UpVector * 0.2)
	local glow = FX.glow(orb, 4.5, C.cyan, 0.2, 4)
	FX.glow(orb, 12, C.cyanDeep, 0.07, 2)
	local rays = FX.rays(orb, 14, { C.cyan, C.white, RGB(160, 240, 255) }, 1.5, 6, 0.35)
	FX.sparks(orb, { C.cyan, C.white }, 120, 16, 0.2)
	local tStreak = 0
	Shot.update = function(u, dt)
		camCF = cam0:Lerp(cam1, smooth(u / 0.35))
		shake = 0.3
		glow.set(nil, 4.5 * (1 + 0.2 * sin(u * 30)))
		rays.update(u)
		tStreak = tStreak - dt
		if tStreak <= 0 then
			tStreak = 0.05
			local from = cam0 * V3(rr(-14, 4), rr(-6, 8), -rr(8, 14))
			FX.streak(from, (cam0.RightVector * -1 + cam0.UpVector * rr(-0.3, 0.3)).Unit, rr(6, 12), rr(40, 60), 0.6,
				pick({ C.pinkHot, C.cyan, C.yellow }), rr(0.2, 0.5), 4)
		end
	end
end

-- 9.55–10.15: Юта крупно, рядом огромная рука Рики
function P2.yutaClose()
	local f = beginShot(T2.YUTACLOSE)
	setLook({ clock = 0, brightness = 1, ambient = RGB(170, 205, 240), outdoor = RGB(160, 200, 240), tint = RGB(225, 240, 255),
		sat = 0.25, contrast = 0.16, bloom = 1.1, dof = { 3.2, 2.2, 0.5 } })
	local base = STAGE.yuta2 + V3(0, 0, -300)
	local cam0 = CFrame.lookAt(base, base + V3(0, 0, -1))
	local cam1 = cam0 * CF(0.05, 0, -0.35)
	camCF, camFOV = cam0, 42
	FX.backdrop(cam0 * CF(0, 0, -200) * ANG(0, math.pi, 0), 700, 500, { RGB(90, 170, 255), RGB(30, 80, 190), RGB(10, 30, 90) }, 60)
	yuta:show(true)
	yuta:place(cam0 * CF(0.35, -4.55, -3.2) * ANG(0, rad(150), 0))
	yuta:pose({ root = { -2, 0, 0 }, neck = { -6, 22, 0 }, lArm = { 20, 0, -10 }, rArm = { 10, 0, 10 } }, 0)
	yuta:update(songT)
	rika:show(true)
	rika:pose(POSE.rikaHand, 0)
	local handAt = cam0 * CF(-2.3, -0.4, -5.6) * ANG(math.pi, 0, rad(-14))
	placeBoneAt(rika, "haL", handAt)
	local fireAt = cam0 * V3(-1.9, -0.6, -4)
	FX.emitter(fireAt, V3(1.4, 1.6, 1), {
		texture = TEX.fire, rate = 45, life = { 0.3, 0.6 }, speed = { 1.5, 4 }, spread = 30,
		size = NS({ { 0, 1.1 }, { 1, 0.1 } }), color = CS({ { 0, RGB(220, 255, 255) }, { 1, C.cyanDeep } }), brightness = 4, accel = V3(0, 2, 0),
	})
	local glow = FX.glow(fireAt, 4, C.cyan, 0.14, 3)
	Shot.update = function(u, dt)
		camCF = cam0:Lerp(cam1, smooth(u / (T2.WHITE - T2.YUTACLOSE)))
		shake = 0.12
		glow.set(nil, 4 * (1 + 0.2 * sin(u * 20)))
		local wf = clamp01((u - 0.45) / 0.15)
		ui.flash.BackgroundTransparency = 1 - wf
	end
end

-- 10.15–10.30: белый экран
function P2.white()
	beginShot(T2.WHITE)
	camCF = CF(0, 3000, 0)
	ui.flash.BackgroundTransparency = 0
	Shot.update = function()
		ui.flash.BackgroundTransparency = 0
	end
end

-- 10.40–13.03: кратер в тумане, Рю стоит сбоку (сначала белая дымка)
function P2.wide()
	local f = beginShot(T2.MIST)
	setLook({ clock = 14, brightness = 1.6, ambient = RGB(170, 180, 200), outdoor = RGB(180, 190, 212), fogColor = RGB(214, 224, 240),
		fogStart = 25, fogEnd = 320, tint = RGB(232, 240, 255), sat = -0.12, contrast = 0.05, bloom = 0.4 })
	local cam0 = CFrame.lookAt(FIELD + V3(2, 4.0, 16), FIELD + V3(8, 3.2, 0))
	local cam1 = CFrame.lookAt(FIELD + V3(1.8, 4.0, 15), FIELD + V3(8, 3.2, 0))
	camCF, camFOV = cam0, 50
	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "smirk")
	ryu:place(CF(FIELD) * ANG(0, rad(-90), 0))
	ryu:pose(POSE.ryuStand, 0)
	ryu.bones.coat.wob = function(t)
		return ANG(rad(-6 - 3 * sin(t * 5)), 0, 0)
	end
	local crater = FIELD + V3(24, 0, -14)
	FX.smoke(crater + V3(0, 6, 0), V3(50, 8, 40), CS({ { 0, RGB(235, 240, 250) }, { 1, RGB(200, 212, 232) } }), 14, 60, 4, 4,
		{ burst = 20, alpha = NS({ { 0, 0.85 }, { 0.3, 0.55 }, { 1, 1 } }), spread = 40 })
	FX.smoke(FIELD + V3(-6, 3, -14), V3(40, 4, 10), ColorSequence.new(RGB(225, 232, 245)), 4, 40, 4, 3,
		{ burst = 6, alpha = NS({ { 0, 0.9 }, { 0.3, 0.75 }, { 1, 1 } }), dir = Enum.NormalId.Left })
	local tStreak, tFlake = 0, 0
	Shot.update = function(u, dt)
		local k = smooth(u / (T2.LOW - T2.MIST))
		camCF = cam0:Lerp(cam1, k)
		shake = 0.08
		local m = clamp01((u - 0) / (T2.WIDE - T2.MIST))
		ui.flash.BackgroundColor3 = RGB(235, 242, 255)
		ui.flash.BackgroundTransparency = lerp(0.05, 1, easeOut(m))
		Shot.blur = lerp(16, 0, m)
		tStreak = tStreak - dt
		if tStreak <= 0 then
			tStreak = 0.09
			local from = FIELD + V3(rr(12, 26), rr(3, 9), rr(-4, 6))
			FX.streak(from, V3(-1, rr(-0.05, 0.12), rr(-0.1, 0.1)).Unit, rr(6, 12), rr(30, 45), 0.9, RGB(245, 250, 255), rr(0.25, 0.6), 1.5)
		end
		tFlake = tFlake - dt
		if tFlake <= 0 then
			tFlake = 0.06
			FX.flyer(V3(rr(0.4, 1.2), rr(0.3, 0.8), 0.08), RGB(250, 252, 255), crater + V3(rr(-20, 10), rr(2, 10), rr(-10, 10)),
				V3(-rr(20, 35), rr(-2, 4), rr(-3, 3)), { life = rr(0.8, 1.4), spin = 6 })
		end
	end
end

-- 13.03–15.39: Рю снизу, ухмылка, ветер и голубое пламя
function P2.low()
	local f = beginShot(T2.LOW)
	setLook({ clock = 14, brightness = 2, ambient = RGB(160, 170, 200), outdoor = RGB(170, 182, 210), fogColor = RGB(200, 215, 240),
		fogStart = 300, fogEnd = 3000, tint = RGB(232, 240, 255), sat = 0.05, contrast = 0.12, bloom = 0.7, dof = { 5.5, 4, 0.25 } })
	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "grin")
	ryu:place(CF(FIELD) * ANG(0, rad(180), 0))
	ryu:pose(POSE.ryuLow, 0)
	ryu.bones.coat.wob = function(t)
		return ANG(rad(-10 - 4 * sin(t * 6)), 0, rad(3 * sin(t * 4)))
	end
	ryu:update(songT)
	local chest = ryu:point("root", V3(0, 0.6, 0))
	local cam0 = CFrame.lookAt(chest + V3(-1.0, -1.3, 6.6), chest + V3(0, 1.7, 0)) * ANG(0, 0, rad(-8))
	local cam1 = cam0 * CF(0, 0.15, -0.5)
	camCF, camFOV = cam0, 55
	local flameAt = chest + V3(3.2, 0.5, -0.5)
	local flame, flameHolder = FX.emitter(flameAt, V3(2, 4, 1.5), {
		texture = TEX.fire, rate = 0, life = { 0.4, 0.8 }, speed = { 3, 7 }, spread = 30,
		size = NS({ { 0, 1.8 }, { 1, 0.2 } }), color = CS({ { 0, RGB(230, 255, 255) }, { 1, C.cyanDeep } }), brightness = 5, accel = V3(0, 4, 0),
	})
	local glow = FX.glow(flameAt, 1, C.cyan, 0.14, 3)
	local bolts = { FX.bolt(C.cyan, 0.06), FX.bolt(RGB(200, 255, 255), 0.05) }
	local tStreak, tb = 0, 0
	Shot.update = function(u, dt)
		camCF = cam0:Lerp(cam1, smooth(u / (T2.FIN - T2.LOW)))
		shake = 0.12
		local e = clamp01((u - 0.3) / 0.15) * (1 - clamp01((u - 1.25) / 0.2))
		flame.Rate = 60 * e
		glow.set(nil, 7 * e * (1 + 0.2 * sin(u * 16)))
		tb = tb - dt
		if tb <= 0 then
			tb = 0.08
			for _, b in ipairs(bolts) do
				b.show(e > 0.1)
				b.strike(flameAt + V3(0, rr(-2, 1), 0), flameAt + V3(rr(-2, 2), rr(2, 5), rr(-1, 1)), 0.6)
			end
		end
		local windy = clamp01((u - 1.35) / 0.2)
		tStreak = tStreak - dt
		if tStreak <= 0 then
			tStreak = lerp(0.07, 0.03, windy)
			local from = chest + cam0.RightVector * rr(4, 9) + cam0.UpVector * rr(-2, 7) - cam0.LookVector * rr(-2, 3)
			local col = RGB(240, 246, 255)
			if windy > 0.5 then
				col = RGB(205, 210, 222)
			end
			FX.streak(from, (cam0.RightVector * -1 + cam0.UpVector * -0.45).Unit, rr(5, 10), rr(30, 50), 0.6, col, rr(0.12, 0.3) * (1 + windy), 1.5)
		end
	end
end

P2.shots = {
	{ 0, P2.vortex }, { T2.LAUGH, P2.laugh }, { T2.ZOOM, P2.zoom }, { T2.IMPACT1, P2.impact1 },
	{ T2.BURST, P2.burst }, { T2.YUTARIKA, P2.yutaRika }, { T2.YUTACLOSE, P2.yutaClose }, { T2.WHITE, P2.white },
	{ T2.IMPACT2, P2.impact2 }, { T2.MIST, P2.wide }, { T2.LOW, P2.low },
}
P2.fin = T2.FIN

----------------------------------------------------------------------
-- ЗАПУСК
----------------------------------------------------------------------

local savedCharCF = nil
local currentPart = 1

local function parkCharacter()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		if not savedCharCF then
			savedCharCF = hrp.CFrame
		end
		hrp.Anchored = true
		char:PivotTo(CF(0, 3000, 3000))
	end
end

local function releaseCharacter()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and savedCharCF then
		char:PivotTo(savedCharCF)
		hrp.Anchored = false
	end
	savedCharCF = nil
end

local function setCoreUI(on)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, on)
	end)
	pcall(function()
		StarterGui:SetCore("TopbarEnabled", on)
	end)
end

local function waitUntil(t)
	while playing and songT < t do
		RunService.RenderStepped:Wait()
	end
end

local function finish(part)
	ui.black.BackgroundTransparency = 0
	playing = false
	Shot.update = nil
	updaters = {}
	if Shot.folder then
		Shot.folder:Destroy()
		Shot.folder = nil
	end
	for _, r in ipairs(rigs) do
		r:show(false)
	end
	fx.blur.Size = 0
	ui.speed.Visible = false
	ui.endText.Text = "Часть " .. part .. " — конец"
	ui.endScreen.Visible = true
	camera.CameraType = Enum.CameraType.Custom
	releaseCharacter()
	setCoreUI(true)
end

local function play(part)
	if playing then
		return
	end
	currentPart = part
	ui.start.Visible = false
	ui.endScreen.Visible = false
	ui.black.BackgroundTransparency = 1
	setCoreUI(false)
	parkCharacter()
	songT = 0
	playing = true
	local list = P1
	if part == 2 then
		list = P2
	end
	for _, s in ipairs(list.shots) do
		waitUntil(s[1])
		if not playing then
			return
		end
		s[2]()
	end
	waitUntil(list.fin)
	finish(part)
end

local function onFrame(dt)
	if not playing then
		return
	end
	if dt > 0.1 then
		dt = 0.1
	end
	songT = songT + dt
	if Shot.update then
		Shot.update(songT - Shot.t0, dt)
	end
	for _, r in ipairs(rigs) do
		if r.active then
			r:update(songT)
		end
	end
	local i = 1
	while i <= #updaters do
		if updaters[i](dt) == false then
			table.remove(updaters, i)
		else
			i = i + 1
		end
	end
	-- короткий смаз на стыке кадров
	local since = songT - Shot.t0
	local cut = 0
	if since < 0.12 then
		cut = 7 * (1 - since / 0.12)
	end
	fx.blur.Size = math.max(Shot.blur or 0, cut)
	-- плавная тряска: повороты камеры по шуму
	camera.CameraType = Enum.CameraType.Scriptable
	local s = CF()
	if shake > 0.001 then
		local k = songT * 16
		local nx = noise(k, 0.31) + 0.5 * noise(k * 2.3, 5.1)
		local ny = noise(k, 7.7) + 0.5 * noise(k * 2.3, 9.4)
		local nz = noise(k, 3.3)
		s = ANG(rad(nx * shake * 0.7), rad(ny * shake * 0.7), rad(nz * shake * 0.5))
	end
	camera.CFrame = camCF * s
	camera.FieldOfView = camFOV
end

local function setup()
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.GlobalShadows = false
	for _, ch in ipairs(Lighting:GetChildren()) do
		if ch:IsA("Atmosphere") then
			ch.Parent = nil
		end
	end
	fx.cc = Instance.new("ColorCorrectionEffect")
	fx.cc.Parent = Lighting
	fx.bloom = Instance.new("BloomEffect")
	fx.bloom.Parent = Lighting
	fx.blur = Instance.new("BlurEffect")
	fx.blur.Size = 0
	fx.blur.Parent = Lighting
	fx.dof = Instance.new("DepthOfFieldEffect")
	fx.dof.Enabled = false
	fx.dof.Parent = Lighting
	setLook({})

	buildUI()
	buildCity(world)
	buildField(world)
	buildEyes(world)
	yuta = buildYuta(world, { angry = 1.0, mouth = "grit", blood = true, look = 0.02, lidDrop = 0.035 })
	ryu = buildRyu(world, { mouth = "smirk" })
	rika = buildRika(world)
	rigs = { yuta, ryu, rika }
	for _, r in ipairs(rigs) do
		r:show(false)
	end

	RunService.RenderStepped:Connect(onFrame)
	local function start(part)
		if not playing then
			task.spawn(play, part)
		end
	end
	ui.btn1.Activated:Connect(function()
		start(1)
	end)
	ui.btn2.Activated:Connect(function()
		start(2)
	end)
	ui.again.Activated:Connect(function()
		start(currentPart)
	end)
	ui.other.Activated:Connect(function()
		start(3 - currentPart)
	end)
	UserInputService.InputBegan:Connect(function(input)
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.One then
			start(1)
		elseif input.KeyCode == Enum.KeyCode.Two then
			start(2)
		elseif input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.Space then
			start(currentPart)
		end
	end)
	if CONFIG.PART == 1 or CONFIG.PART == 2 then
		currentPart = CONFIG.PART
	end
	if CONFIG.AUTO_START then
		task.delay(1, function()
			start(currentPart)
		end)
	end
end

setup()
