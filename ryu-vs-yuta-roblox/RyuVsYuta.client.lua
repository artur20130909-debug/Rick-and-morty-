--[[
	РЮ vs ЮТА — фан-анимация по «Магической битве» для Roblox
	Часть 1: первые 11 секунд клипа, тайминг совпадает кадр в кадр.

	КАК ЗАПУСТИТЬ
	  • Открой RyuVsYuta.rbxlx в Roblox Studio и нажми Play (F5).
	    Или вставь этот код в LocalScript: StarterPlayer → StarterPlayerScripts.
	  • Включи запись экрана (Win+Alt+R или OBS), потом нажми ПРОБЕЛ или «СТАРТ».
	  • R — посмотреть ещё раз.
	  • Звук: в CapCut наложи звук из оригинального клипа, тайминг совпадает.

	Настройки — в таблице CONFIG ниже.
]]

local CONFIG = {
	DUMMY_MODE = false, -- true: Рю и Юта — серые манекены без одежды
	AUTO_START = false, -- true: начать сразу после загрузки, без кнопки
	OUTLINES = true, -- чёрный контур, как в аниме
	SOUND_ID = "", -- свой звук, например "rbxassetid://1234567890"
}

-- Тайминг клипа, секунды
local T = {
	GLOW = 4.30, -- глаза засвечивает
	WHITE = 4.83, -- белая вспышка
	CLASH = 5.40, -- столкновение лучей
	CITY = 7.83, -- общий план города
	YUTA = 8.70, -- Юта и Рика
	RYU = 10.00, -- попадание по Рю
	FIN = 11.17, -- конец части 1
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local V3, CF, ANG, RGB = Vector3.new, CFrame.new, CFrame.Angles, Color3.fromRGB
local rad = math.rad
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
	return 1 - (1 - t) * (1 - t)
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

local C = {
	white = RGB(255, 255, 255),
	black = RGB(0, 0, 0),
	pink = RGB(255, 60, 185),
	pinkHot = RGB(255, 130, 225),
	magenta = RGB(200, 40, 170),
	cyan = RGB(60, 225, 255),
	cyanDeep = RGB(25, 140, 255),
	teal = RGB(70, 230, 205),
	yellow = RGB(255, 236, 140),
	gold = RGB(255, 205, 80),
	red = RGB(205, 55, 40),
	rock = RGB(48, 54, 52),
	rikaSkin = RGB(240, 236, 244),
	rikaInk = RGB(18, 14, 24),
	rikaMouth = RGB(48, 8, 26),
	tooth = RGB(252, 250, 244),
}

----------------------------------------------------------------------
-- ДЕТАЛИ
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

local function outline(model, fillColor, fillT)
	if not CONFIG.OUTLINES then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = fillColor or C.white
	h.FillTransparency = fillT or 1
	h.OutlineTransparency = 0
	h.OutlineColor = C.black
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
end

----------------------------------------------------------------------
-- СКЕЛЕТ: кости поворачиваются, детали едут за ними
----------------------------------------------------------------------

local Rig = {}
Rig.__index = Rig
local allRigs = {}

function Rig.new(name, parent)
	local self = setmetatable({}, Rig)
	self.model = Instance.new("Model")
	self.model.Name = name
	self.model.Parent = parent
	self.home = parent
	self.bones = {}
	self.list = {}
	self.root = CF()
	self.active = true
	return self
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
	}
	self.bones[name] = b
	table.insert(self.list, b)
	return b
end

function Rig:add(boneName, size, color, rel, o)
	local p = newPart(self.model, size, color, nil, o)
	table.insert(self.bones[boneName].parts, { p = p, rel = rel or CF() })
	return p
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
			b.rot = b.from:Lerp(b.to, easeOut(a))
			if a >= 1 then
				b.dur = 0
				b.rot = b.to
			end
		end
		local base = self.root
		if b.parent then
			base = b.parent.world
		end
		b.world = base * b.offset * b.rot
		for _, e in ipairs(b.parts) do
			e.p.CFrame = b.world * e.rel
		end
	end
end

function Rig:point(boneName, v)
	return self.bones[boneName].world * v
end

----------------------------------------------------------------------
-- ЛИЦА И ПРИЧЁСКИ (координаты от центра головы, лицо смотрит в -Z)
----------------------------------------------------------------------

local FZ = -0.63 -- плоскость лица: голова 1.25, перед на -0.625

local function addEye(add, x, y, p)
	local side = 1
	if x < 0 then
		side = -1
	end
	local rot = ANG(0, 0, -side * rad(p.tilt or 0))
	local w, h = p.w, p.h
	add(V3(w, h, 0.02), C.white, CF(x, y, FZ) * rot, { shape = "ball" })
	local ix, iy = x + (p.look or 0), y + (p.lookY or 0)
	local iw, ih = p.irisW, p.irisH
	add(V3(iw, ih, 0.02), p.iris, CF(ix, iy, FZ - 0.006), { shape = "ball" })
	add(V3(iw * 0.5, ih * 0.55, 0.02), RGB(14, 14, 26), CF(ix, iy, FZ - 0.012), { shape = "ball" })
	add(V3(0.04, 0.04, 0.02), C.white, CF(ix - iw * 0.2, iy + ih * 0.22, FZ - 0.018), { shape = "ball" })
	local cover = p.cover or 0
	if cover > 0 then
		-- кожа сверху глаза: делает прищур
		add(V3(w * 1.3, h * 0.7, 0.006), p.skin, CF(x, y + h * (0.5 - cover) + h * 0.35, FZ - 0.016) * rot)
	end
	local topY = y + h * (0.5 - cover)
	add(V3(w * 1.1, p.lidT or 0.045, 0.02), C.black, CF(x, topY, FZ - 0.024) * rot)
	add(V3(0.1, 0.03, 0.02), C.black, CF(x + side * w * 0.56, topY - 0.025, FZ - 0.024) * ANG(0, 0, -side * rad(28)))
	add(V3(w * 0.7, 0.014, 0.02), RGB(95, 60, 60), CF(x + side * w * 0.08, y - h * 0.48, FZ - 0.02) * rot)
	for k = 1, (p.bags or 0) do
		add(V3(w * 0.55, 0.012, 0.02), RGB(165, 120, 115), CF(x + side * w * 0.05, y - h * 0.62 - (k - 1) * 0.035, FZ - 0.02) * rot)
	end
end

local function addBrow(add, x, y, p)
	local side = 1
	if x < 0 then
		side = -1
	end
	add(V3(p.bw, p.bt, 0.02), C.black, CF(x + side * (p.bx or 0), y, FZ - 0.022) * ANG(0, 0, side * rad(p.angry or 10)))
end

local FACES = {}

function FACES.yuta(add, skin, mood)
	mood = mood or {}
	for _, s in ipairs({ 1, -1 }) do
		addEye(add, s * 0.27, 0.04, {
			w = 0.36, h = 0.21, iris = RGB(80, 150, 215), irisW = 0.15, irisH = 0.19,
			look = mood.look or 0, lookY = mood.lookY or 0.01, tilt = 6, lidT = 0.045,
			bags = 2, cover = mood.cover or 0.04, skin = skin,
		})
		addBrow(add, s * 0.27, 0.25, { bw = 0.34, bt = 0.036, angry = mood.angry or 8 })
	end
	add(V3(0.05, 0.016, 0.02), skin:Lerp(C.black, 0.35), CF(0.02, -0.15, FZ))
	if mood.mouth == "open" then
		add(V3(0.24, 0.13, 0.02), RGB(95, 25, 35), CF(0, -0.34, FZ), { shape = "ball" })
	else
		add(V3(0.2, 0.022, 0.02), RGB(95, 55, 55), CF(0, -0.34, FZ))
	end
end

function FACES.ryu(add, skin, mood)
	mood = mood or {}
	local line = skin:Lerp(RGB(90, 45, 35), 0.55)
	for _, s in ipairs({ 1, -1 }) do
		addEye(add, s * 0.27, 0.0, {
			w = 0.34, h = 0.17, iris = RGB(125, 120, 205), irisW = 0.13, irisH = 0.15,
			look = mood.look or 0, lookY = -0.01, tilt = 4, lidT = 0.05,
			cover = mood.cover or 0.3, skin = skin,
		})
		addBrow(add, s * 0.26, 0.2, { bw = 0.44, bt = 0.075, angry = mood.angry or 15, bx = 0.02 })
		add(V3(0.013, 0.17, 0.02), line, CF(s * 0.05, 0.21, FZ - 0.01) * ANG(0, 0, s * rad(10)))
		add(V3(0.013, 0.19, 0.02), line, CF(s * 0.17, -0.21, FZ - 0.01) * ANG(0, 0, -s * rad(22)))
	end
	add(V3(0.013, 0.13, 0.02), line, CF(0, 0.27, FZ - 0.01))
	add(V3(0.36, 0.013, 0.02), line, CF(0, 0.39, FZ - 0.01) * ANG(0, 0, rad(3)))
	add(V3(0.28, 0.013, 0.02), line, CF(0, 0.45, FZ - 0.01) * ANG(0, 0, rad(-2)))
	add(V3(0.06, 0.018, 0.02), line, CF(0.03, -0.14, FZ))
	if mood.mouth == "open" then
		add(V3(0.38, 0.22, 0.02), RGB(80, 18, 24), CF(0, -0.37, FZ), { shape = "ball" })
		add(V3(0.27, 0.045, 0.02), C.white, CF(0, -0.29, FZ - 0.006))
	else
		add(V3(0.26, 0.026, 0.02), RGB(95, 45, 40), CF(0, -0.36, FZ) * ANG(0, 0, rad(-4)))
	end
end

local HAIR = {}

function HAIR.yuta(add)
	local h = RGB(30, 42, 52)
	add(V3(1.36, 0.36, 1.36), h, CF(0, 0.67, 0.02))
	add(V3(1.36, 1.05, 0.3), h, CF(0, 0.2, 0.6))
	add(V3(0.16, 0.85, 1.24), h, CF(0.69, 0.2, 0.04))
	add(V3(0.16, 0.85, 1.24), h, CF(-0.69, 0.2, 0.04))
	-- чёлка: короткие пряди и две длинные, которые падают на глаза
	local strands = {
		{ -0.52, 0.42, 0.42, 14 }, { -0.36, 0.45, 0.36, -6 }, { -0.2, 0.43, 0.4, 9 },
		{ 0.0, 0.46, 0.34, -4 }, { 0.17, 0.42, 0.42, 10 }, { 0.36, 0.45, 0.36, -8 },
		{ 0.53, 0.42, 0.42, 6 },
		{ 0.1, 0.3, 0.66, -7 }, { 0.47, 0.28, 0.7, 5 }, { -0.42, 0.3, 0.62, 9 },
	}
	for _, s in ipairs(strands) do
		add(V3(0.15, s[3], 0.05), h, CF(s[1], s[2], -0.66) * ANG(0, 0, rad(s[4])), { shape = "ball" })
	end
end

function HAIR.ryu(add)
	local h = RGB(16, 16, 22)
	add(V3(1.38, 0.62, 1.38), h, CF(0, 0.62, 0.05), { shape = "ball" })
	add(V3(1.32, 0.5, 1.3), h, CF(0, 0.55, 0.06))
	-- помпадур
	add(V3(1.15, 0.78, 1.95), h, CF(0, 0.9, -0.52) * ANG(rad(12), 0, 0), { shape = "ball" })
	add(V3(1.0, 0.56, 0.62), h, CF(0, 1.02, -1.32) * ANG(rad(-20), 0, 0), { shape = "ball" })
	add(V3(0.13, 0.52, 1.0), h, CF(0.67, 0.36, 0.14))
	add(V3(0.13, 0.52, 1.0), h, CF(-0.67, 0.36, 0.14))
	add(V3(0.1, 0.46, 0.24), h, CF(0.67, -0.02, -0.08))
	add(V3(0.1, 0.46, 0.24), h, CF(-0.67, -0.02, -0.08))
	add(V3(1.32, 0.95, 0.26), h, CF(0, 0.25, 0.6))
end

----------------------------------------------------------------------
-- ПЕРСОНАЖИ
----------------------------------------------------------------------

local function buildR6(name, parent, look)
	local rig = Rig.new(name, parent)
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

local function headAdder(rig)
	return function(size, color, cf, o)
		return rig:add("neck", size, color, CF(0, 0.625, 0) * cf, o)
	end
end

local GREY = RGB(163, 162, 165)

local function buildYuta(parent, mood, bloody)
	local dummy = CONFIG.DUMMY_MODE
	local white = RGB(242, 242, 246)
	local look = {
		skin = RGB(246, 220, 198),
		shirt = white,
		sleeve = white,
		pants = RGB(232, 232, 238),
		shoes = RGB(30, 30, 36),
	}
	if dummy then
		look = { skin = GREY, shirt = GREY, sleeve = GREY, pants = GREY, shoes = GREY }
	end
	local rig = buildR6("Yuta", parent, look)
	local add = headAdder(rig)
	FACES.yuta(add, look.skin, mood)
	HAIR.yuta(add)
	if not dummy then
		local shade = RGB(200, 204, 218)
		rig:add("root", V3(1.32, 0.28, 1.1), white, CF(0, 1.1, 0)) -- высокий воротник
		rig:add("root", V3(1.34, 0.05, 1.12), shade, CF(0, 1.24, 0))
		rig:add("root", V3(0.03, 2.0, 0.02), shade, CF(0, -0.02, -0.51))
		rig:add("root", V3(0.17, 0.17, 0.05), RGB(225, 190, 90), CF(0.32, 0.8, -0.53), { shape = "ball" })
		rig:add("root", V3(2.03, 0.16, 1.03), RGB(40, 40, 48), CF(0, -0.86, 0))
		rig:add("root", V3(0.25, 4.3, 0.25), RGB(22, 22, 28), CF(0, -0.1, 0.64) * ANG(0, 0, rad(38))) -- чехол меча
		for _, a in ipairs({ "rArm", "lArm" }) do
			rig:add(a, V3(1.02, 0.05, 1.02), shade, CF(0, -0.55, 0))
			rig:add(a, V3(1.04, 0.14, 1.04), white, CF(0, -1.02, 0))
		end
		if bloody then
			local blood = RGB(165, 15, 30)
			rig:add("root", V3(0.7, 0.42, 0.08), blood, CF(-0.36, 1.06, -0.58), { shape = "ball" })
			rig:add("root", V3(0.3, 0.8, 0.06), blood, CF(-0.5, 0.6, -0.53), { shape = "ball" })
			rig:add("root", V3(0.16, 0.5, 0.06), blood, CF(-0.22, 0.55, -0.53), { shape = "ball" })
			rig:add("neck", V3(0.42, 0.3, 0.05), blood, CF(-0.36, 0.08, -0.632), { shape = "ball" })
			rig:add("neck", V3(0.06, 0.2, 0.03), blood, CF(-0.12, -0.42, -0.64), { shape = "ball" })
		end
	end
	outline(rig.model)
	return rig
end

local function buildRyu(parent, mood)
	local dummy = CONFIG.DUMMY_MODE
	local skin = RGB(236, 200, 168)
	local coat = RGB(36, 42, 64)
	local look = {
		skin = skin,
		shirt = skin, -- голый торс под плащом
		sleeve = coat,
		pants = RGB(28, 28, 34),
		shoes = RGB(52, 36, 28),
	}
	if dummy then
		look = { skin = GREY, shirt = GREY, sleeve = GREY, pants = GREY, shoes = GREY }
	end
	local rig = buildR6("Ryu", parent, look)
	local add = headAdder(rig)
	FACES.ryu(add, look.skin, mood)
	HAIR.ryu(add)
	if not dummy then
		local line = skin:Lerp(RGB(110, 60, 40), 0.6)
		local fur = RGB(238, 236, 230)
		-- грудь и пресс
		rig:add("root", V3(0.022, 1.25, 0.02), line, CF(0, -0.3, -0.51))
		for i = 0, 2 do
			rig:add("root", V3(0.62, 0.022, 0.02), line, CF(0, -0.15 - i * 0.3, -0.51))
		end
		rig:add("root", V3(0.5, 0.022, 0.02), line, CF(0.26, 0.32, -0.51) * ANG(0, 0, rad(-10)))
		rig:add("root", V3(0.5, 0.022, 0.02), line, CF(-0.26, 0.32, -0.51) * ANG(0, 0, rad(10)))
		-- плащ
		rig:add("root", V3(0.48, 2.04, 1.06), coat, CF(0.78, 0, 0))
		rig:add("root", V3(0.48, 2.04, 1.06), coat, CF(-0.78, 0, 0))
		rig:add("root", V3(2.06, 2.04, 0.12), coat, CF(0, 0, 0.5))
		rig:add("root", V3(2.1, 1.9, 0.12), coat, CF(0, -1.95, 0.54))
		rig:add("root", V3(0.12, 1.9, 1.0), coat, CF(1.06, -1.95, 0.05))
		rig:add("root", V3(0.12, 1.9, 1.0), coat, CF(-1.06, -1.95, 0.05))
		-- меховой воротник
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			local x, z = math.cos(a) * 0.95, math.sin(a) * 0.58
			if not (z < 0 and math.abs(x) < 0.45) then
				rig:add("root", V3(0.8, 0.55, 0.7), fur, CF(x, 1.05 + rr(-0.05, 0.08), z) * ANG(0, -a, rad(rr(-15, 15))), { shape = "ball" })
			end
		end
		rig:add("root", V3(1.1, 0.75, 1.1), fur, CF(1.05, 1.0, 0), { shape = "ball" })
		rig:add("root", V3(1.1, 0.75, 1.1), fur, CF(-1.05, 1.0, 0), { shape = "ball" })
		rig:add("root", V3(0.5, 1.4, 0.4), fur, CF(0.55, 0.35, -0.55) * ANG(0, 0, rad(-12)), { shape = "ball" })
		rig:add("root", V3(0.5, 1.4, 0.4), fur, CF(-0.55, 0.35, -0.55) * ANG(0, 0, rad(12)), { shape = "ball" })
	end
	outline(rig.model)
	return rig
end

-- Рика: белая, в чёрных полосах, с огромной пастью и длинными когтями
local RIKA_MOUTH = V3(0, 1.55, -2.7)

local function buildRika(parent)
	local rig = Rig.new("Rika", parent)
	local S, K = C.rikaSkin, C.rikaInk
	local function bone(n, p, x, y, z)
		rig:addBone(n, p, CF(x, y, z))
	end
	bone("root", nil, 0, 0, 0)
	bone("spine", "root", 0, 1.4, 0)
	bone("chest", "spine", 0, 2.6, 0)
	bone("neck", "chest", 0, 3.0, 0)
	bone("head", "neck", 0, 1.5, 0)
	for _, s in ipairs({ 1, -1 }) do
		local R = "R"
		if s < 0 then
			R = "L"
		end
		bone("sh" .. R, "chest", s * 3.4, 2.2, 0)
		bone("el" .. R, "sh" .. R, 0, -5.6, 0)
		bone("ha" .. R, "el" .. R, 0, -5.4, 0)
		bone("hip" .. R, "root", s * 1.5, -0.8, 0)
		bone("kn" .. R, "hip" .. R, 0, -4.6, 0)
		bone("ft" .. R, "kn" .. R, 0, -4.6, 0)
	end

	local function ell(b, sx, sy, sz, col, rel)
		return rig:add(b, V3(sx, sy, sz), col, rel, { shape = "ball" })
	end
	-- чёрная полоса вокруг эллипсоида-конечности (центр cy, длина L, толщина d)
	local function band(b, cy, L, d, y, tx, tz, w)
		local f = 1 - ((y - cy) / (L / 2)) ^ 2
		if f < 0.06 then
			f = 0.06
		end
		local dl = d * math.sqrt(f) * 1.1 + 0.06
		return ell(b, dl, w or 0.32, dl, K, CF(0, y, 0) * ANG(rad(tx or 0), 0, rad(tz or 0)))
	end

	-- таз, живот
	ell("root", 4.4, 3.0, 3.2, S, CF(0, -0.2, 0))
	band("root", -0.2, 3.0, 3.6, -0.6, 0, 8, 0.36)
	ell("spine", 3.3, 3.6, 2.7, S, CF(0, 1.2, 0))
	band("spine", 1.2, 3.6, 3.0, 0.5, 0, 12)
	band("spine", 1.2, 3.6, 3.0, 1.75, 0, -10)
	-- грудь и плечи
	ell("chest", 6.4, 4.8, 4.0, S, CF(0, 1.5, 0))
	ell("chest", 8.6, 2.4, 3.6, S, CF(0, 2.6, 0))
	ell("chest", 6.75, 0.36, 4.3, K, CF(0, 0.35, 0) * ANG(0, 0, rad(8)))
	ell("chest", 6.6, 0.34, 4.2, K, CF(0, 1.45, 0) * ANG(0, 0, rad(-7)))
	ell("chest", 0.36, 2.7, 3.9, K, CF(2.6, 2.45, 0) * ANG(0, 0, rad(22)))
	ell("chest", 0.36, 2.7, 3.9, K, CF(-2.6, 2.45, 0) * ANG(0, 0, rad(-22)))
	ell("chest", 1.6, 0.3, 0.3, K, CF(1.3, 2.0, -1.95) * ANG(0, 0, rad(-30)))
	ell("chest", 1.6, 0.3, 0.3, K, CF(-1.3, 2.0, -1.95) * ANG(0, 0, rad(30)))
	-- шея
	ell("neck", 2.0, 3.2, 2.0, S, CF(0, 0.8, 0))
	band("neck", 0.8, 3.2, 2.0, 0.5, 0, 10)
	band("neck", 0.8, 3.2, 2.0, 1.5, 0, -8)

	-- голова и пасть
	ell("head", 5.4, 5.8, 5.0, S, CF(0, 2.6, 0))
	ell("head", 4.3, 1.9, 1.2, C.rikaMouth, CF(0, 1.55, -1.95))
	for i = 0, 10 do
		local x = -1.75 + i * 0.35
		for _, row in ipairs({ { 2.05, 0.62 }, { 1.05, 0.55 } }) do
			local y = row[1]
			local f = 1 - (x / 2.15) ^ 2 - ((y - 1.55) / 0.95) ^ 2
			if f < 0 then
				f = 0
			end
			local z = -1.95 - 0.6 * math.sqrt(f) + 0.04
			rig:add("head", V3(0.27, row[2], 0.24), C.tooth, CF(x, y, z))
		end
	end
	-- глаза
	for _, s in ipairs({ 1, -1 }) do
		local turn = ANG(0, s * rad(-20), 0)
		ell("head", 1.6, 1.4, 0.5, K, CF(s * 1.15, 3.55, -2.0) * turn)
		ell("head", 1.3, 1.1, 0.4, C.white, CF(s * 1.15, 3.55, -2.12) * turn)
		ell("head", 0.32, 0.46, 0.2, K, CF(s * 1.08, 3.5, -2.32) * turn)
		ell("head", 1.7, 0.3, 0.4, K, CF(s * 1.25, 4.45, -1.9) * ANG(0, 0, s * rad(-14)) * turn)
	end
	-- полосы на лице
	ell("head", 0.3, 1.4, 0.3, K, CF(2.25, 2.2, -1.45) * ANG(0, 0, rad(-12)))
	ell("head", 0.3, 1.4, 0.3, K, CF(-2.25, 2.2, -1.45) * ANG(0, 0, rad(12)))
	-- длинные чёрные волосы
	local hairs = {
		{ 0, 5.2, 0.6, 165, 0, 9 }, { 1.2, 5.0, 0.4, 155, -15, 8 }, { -1.2, 5.0, 0.4, 155, 15, 8 },
		{ 2.0, 4.4, 0.6, 140, -35, 7 }, { -2.0, 4.4, 0.6, 140, 35, 7 },
		{ 0.7, 5.3, 1.4, 172, -5, 10 }, { -0.7, 5.3, 1.4, 172, 5, 10 },
		{ 1.6, 4.0, 1.6, 150, -50, 7 }, { -1.6, 4.0, 1.6, 150, 50, 7 },
		{ 2.4, 3.2, 0.9, 120, -70, 6 }, { -2.4, 3.2, 0.9, 120, 70, 6 },
		{ 0.4, 5.4, -0.6, 200, -10, 5 }, { -0.5, 5.4, -0.6, 200, 12, 5 },
	}
	for _, h in ipairs(hairs) do
		local L = h[6]
		rig:add("head", V3(1.1, L, 0.7), K, CF(h[1], h[2], h[3]) * ANG(rad(h[4]), 0, rad(h[5])) * CF(0, L / 2, 0), { shape = "ball" })
	end

	-- руки и ноги
	for _, s in ipairs({ 1, -1 }) do
		local R = "R"
		if s < 0 then
			R = "L"
		end
		ell("sh" .. R, 2.0, 6.2, 2.0, S, CF(0, -2.8, 0))
		band("sh" .. R, -2.8, 6.2, 2.0, -1.4, 0, s * 14)
		band("sh" .. R, -2.8, 6.2, 2.0, -3.1, 0, -s * 10)
		band("sh" .. R, -2.8, 6.2, 2.0, -4.6, 0, s * 16)
		ell("el" .. R, 1.7, 6.0, 1.7, S, CF(0, -2.7, 0))
		band("el" .. R, -2.7, 6.0, 1.7, -1.6, 0, -s * 12)
		band("el" .. R, -2.7, 6.0, 1.7, -3.4, 0, s * 15)
		band("el" .. R, -2.7, 6.0, 1.7, -4.8, 0, -s * 8)
		ell("ha" .. R, 2.6, 2.4, 1.1, S, CF(0, -1.0, 0))
		ell("ha" .. R, 2.5, 0.3, 1.2, K, CF(0, -0.4, 0) * ANG(0, 0, rad(s * 8)))
		for _, fx in ipairs({ -0.85, -0.3, 0.3, 0.85 }) do
			ell("ha" .. R, 0.42, 3.0, 0.46, S, CF(fx, -3.1, 0) * ANG(0, 0, rad(fx * 6)))
			ell("ha" .. R, 0.5, 0.22, 0.52, K, CF(fx * 1.02, -2.6, 0))
			ell("ha" .. R, 0.3, 1.0, 0.3, K, CF(fx * 1.06, -4.8, 0))
		end
		ell("ha" .. R, 0.46, 2.0, 0.5, S, CF(-s * 1.35, -1.4, -0.4) * ANG(rad(-20), 0, rad(-s * 25)))
		ell("hip" .. R, 2.5, 5.0, 2.5, S, CF(0, -2.3, 0))
		band("hip" .. R, -2.3, 5.0, 2.5, -1.2, 0, s * 12)
		band("hip" .. R, -2.3, 5.0, 2.5, -3.0, 0, -s * 10)
		ell("kn" .. R, 2.0, 5.0, 2.0, S, CF(0, -2.3, 0))
		band("kn" .. R, -2.3, 5.0, 2.0, -1.5, 0, -s * 12)
		band("kn" .. R, -2.3, 5.0, 2.0, -3.4, 0, s * 10)
		ell("ft" .. R, 2.2, 1.0, 3.6, S, CF(0, -0.2, -0.9))
		for _, tx in ipairs({ -0.6, 0, 0.6 }) do
			ell("ft" .. R, 0.32, 0.32, 1.1, K, CF(tx, -0.3, -2.9))
		end
	end
	-- лёгкая белая заливка: Рика светится белым даже ночью, как в аниме
	outline(rig.model, RGB(255, 245, 252), 0.78)
	return rig
end

-- позы: {x, y, z} в градусах. x+ = рука/нога вперёд, у корпуса x- = наклон вперёд
local POSE = {
	rikaCrouch = {
		spine = { -30, 0, 0 }, chest = { -26, 0, 0 }, neck = { 30, 0, 0 }, head = { 16, 0, 0 },
		shR = { 98, 0, 18 }, elR = { -12, 0, 0 }, haR = { 40, 0, 0 },
		shL = { 40, 0, -62 }, elL = { 78, 0, 0 }, haL = { -10, 0, 0 },
		hipR = { 84, 0, 16 }, knR = { -140, 0, 0 }, ftR = { 56, 0, 0 },
		hipL = { 84, 0, -16 }, knL = { -140, 0, 0 }, ftL = { 56, 0, 0 },
	},
	rikaReach = {
		spine = { -16, 0, 0 }, chest = { -16, 0, 0 }, neck = { 14, 24, 0 }, head = { 6, 26, 0 },
		shL = { 150, 0, 4 }, elL = { 4, 0, 0 }, haL = { -8, 0, 0 },
		shR = { 60, 0, 30 }, elR = { 50, 0, 0 }, haR = { -10, 0, 0 },
		hipR = { 18, 0, 6 }, knR = { -24, 0, 0 }, hipL = { -8, 0, -6 }, knL = { -16, 0, 0 },
	},
	yutaCast = {
		root = { -4, 0, 0 }, neck = { -8, 52, 0 },
		lArm = { 122, 0, 6 }, rArm = { -28, 0, 16 }, rLeg = { 10, 0, 0 }, lLeg = { -12, 0, 0 },
	},
	ryuHit = {
		root = { 12, -8, -6 }, neck = { 14, 12, 8 },
		rArm = { 30, 0, 72 }, lArm = { 70, 0, -28 }, rLeg = { -14, 0, 4 }, lLeg = { 12, 0, -4 },
	},
}

----------------------------------------------------------------------
-- ГОРОД (колония Сендай ночью)
----------------------------------------------------------------------

-- Город стоит далеко от (0, 0, 0), чтобы не пересекаться с Baseplate и точкой появления
local ORIGIN = V3(0, 0, 9000)
local CLASH_POINT = ORIGIN + V3(0, 16, 0)
local CITY_CAM_REL = V3(-62, 50, -122) -- камера общего плана: вдоль её взгляда дома ниже
local CITY_CAM = ORIGIN + CITY_CAM_REL

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
			if not (math.abs(cx) < 70 and math.abs(cz) < 95) then
				local w, d = n(18, 34), n(18, 34)
				local h = n(14, 64)
				if math.abs(cx) + math.abs(cz) < 300 then
					h = h * 1.4
				end
				-- дома между камерой общего плана и взрывом делаем ниже
				local rel = Vector2.new(cx, cz) - camXZ
				local along = rel:Dot(axis)
				local side = math.abs(rel.X * axis.Y - rel.Y * axis.X)
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
	-- руины в зоне боя
	for _ = 1, 40 do
		local pos = V3(n(-68, 68), 0, n(-92, 92))
		local s = V3(n(3, 12), n(1.5, 7), n(3, 12))
		newPart(f, s, RGB(52, 58, 60), at(pos.X, s.Y / 2 - 0.5, pos.Z) * ANG(n(-0.4, 0.4), n(0, 6.28), n(-0.4, 0.4)), { material = Enum.Material.Concrete })
	end
	for _ = 1, 18 do
		local pos = V3(n(-60, 60), n(2, 8), n(-85, 85))
		newPart(f, V3(0.5, 0.5, n(6, 16)), C.red, CF(ORIGIN + pos) * ANG(n(-1, 1), n(0, 6.28), n(-1, 1)))
	end
	return f
end

----------------------------------------------------------------------
-- ЭФФЕКТЫ
----------------------------------------------------------------------

local updaters = {}
local function addUpdater(fn)
	updaters[#updaters + 1] = fn
end

-- летящий кусок: скорость, вращение, гравитация, исчезает к концу жизни
local function flyer(parent, size, color, pos, vel, o)
	o = o or {}
	local p = newPart(parent, size, color, nil, o)
	local rot = ANG(rr(0, 6.28), rr(0, 6.28), rr(0, 6.28))
	local spinSpeed = o.spin or 6
	local spin = V3(rr(-1, 1), rr(-1, 1), rr(-1, 1)) * spinSpeed
	local life = o.life or 1.2
	local g = o.gravity or 0
	local a0 = o.alpha or 0
	local grow = o.grow or 0
	local age = 0
	p.CFrame = CF(pos) * rot
	addUpdater(function(dt)
		age = age + dt
		if age >= life or not p.Parent then
			p:Destroy()
			return false
		end
		vel = vel - V3(0, g * dt, 0)
		pos = pos + vel * dt
		rot = rot * ANG(spin.X * dt, spin.Y * dt, spin.Z * dt)
		p.CFrame = CF(pos) * rot
		if grow ~= 0 then
			p.Size = p.Size * (1 + grow * dt)
		end
		p.Transparency = lerp(a0, 1, clamp01((age - life * 0.6) / (life * 0.4)))
		return true
	end)
	return p
end

-- луч из трёх слоёв: белое ядро, цвет, ореол
local function makeBeam(parent, color, width)
	local layers = {
		{ p = newPart(parent, V3(1, 1, 1), color:Lerp(C.white, 0.78), nil, { neon = true, shape = "cyl" }), k = 0.42 },
		{ p = newPart(parent, V3(1, 1, 1), color, nil, { neon = true, shape = "cyl", alpha = 0.2 }), k = 1.0 },
		{ p = newPart(parent, V3(1, 1, 1), color, nil, { neon = true, shape = "cyl", alpha = 0.72 }), k = 1.9 },
	}
	local beam = { width = width }
	function beam.set(a, b, w)
		local len = (b - a).Magnitude
		if len < 0.05 then
			return
		end
		local cf = CFrame.lookAt((a + b) / 2, b) * ANG(0, rad(90), 0)
		for _, L in ipairs(layers) do
			local d = (w or beam.width) * L.k
			L.p.Size = V3(len, d, d)
			L.p.CFrame = cf
		end
	end
	function beam.hide()
		for _, L in ipairs(layers) do
			L.p.Transparency = 1
		end
	end
	return beam
end

-- аниме-звезда: острые лучи из центра, каждые доли секунды перерисовываются
local function starburst(parent, center, n, colors, minL, maxL, thick)
	local spikes = {}
	for i = 1, n do
		spikes[i] = newPart(parent, V3(1, 1, 1), colors[(i - 1) % #colors + 1], nil, { neon = true, shape = "ball", alpha = 0.05 })
	end
	local obj = { center = center, scale = 1, dirBias = nil }
	function obj.reroll()
		for _, s in ipairs(spikes) do
			local dir = V3(rr(-1, 1), rr(-1, 1), rr(-1, 1))
			if obj.dirBias then
				dir = dir + obj.dirBias
			end
			if dir.Magnitude < 0.05 then
				dir = V3(0, 1, 0)
			end
			dir = dir.Unit
			local L = rr(minL, maxL) * obj.scale
			local th = rr(thick * 0.35, thick) * obj.scale
			s.Size = V3(th, th, L)
			s.CFrame = CFrame.lookAt(obj.center + dir * L * 0.5, obj.center + dir * L)
		end
	end
	function obj.hide()
		for _, s in ipairs(spikes) do
			s.Transparency = 1
		end
	end
	obj.reroll()
	return obj
end

-- молния-зигзаг
local function lightning(parent, color, thick)
	local segs = {}
	local obj = {}
	function obj.strike(a, b, n, jag)
		for i = #segs + 1, n do
			segs[i] = newPart(parent, V3(1, 1, 1), color, nil, { neon = true })
		end
		local prev = a
		for i = 1, n do
			local pt = a:Lerp(b, i / n)
			if i < n then
				pt = pt + V3(rr(-1, 1), rr(-1, 1), rr(-1, 1)) * jag
			end
			local len = (pt - prev).Magnitude
			local s = segs[i]
			s.Size = V3(thick, thick, len + thick)
			s.CFrame = CFrame.lookAt((prev + pt) / 2, pt)
			s.Transparency = 0
			prev = pt
		end
		for i = n + 1, #segs do
			segs[i].Transparency = 1
		end
	end
	return obj
end

----------------------------------------------------------------------
-- СОСТОЯНИЕ
----------------------------------------------------------------------

local world = Instance.new("Folder")
world.Name = "RyuVsYuta"
world.Parent = workspace

local yuta, ryu, rika
local shotFolder = nil
local shot = nil
local songT = 0
local playing = false
local camCF, camFOV = CF(0, 2000, 0), 70
local shake = 0
local ui = {}
local fx = {}

local function setAmbient(a, o)
	Lighting.Ambient = a
	Lighting.OutdoorAmbient = o or a
end

local function grade(tint, sat, contrast, bright, bloom)
	fx.cc.TintColor = tint
	fx.cc.Saturation = sat
	fx.cc.Contrast = contrast
	fx.cc.Brightness = bright
	fx.bloom.Intensity = bloom
end

local function beginShot(t0)
	updaters = {}
	if shotFolder then
		shotFolder:Destroy()
	end
	shotFolder = Instance.new("Folder")
	shotFolder.Name = "Shot"
	shotFolder.Parent = world
	shake = 0
	shot = { t0 = t0, update = nil }
	for _, r in ipairs(allRigs) do
		r:show(false)
	end
	ui.split.Visible = false
	ui.flash.BackgroundTransparency = 1
	ui.flashGrad.Color = ColorSequence.new(C.white, C.white)
	ui.flashGrad.Rotation = 0
	ui.tint.BackgroundTransparency = 1
	fx.blur.Size = 0
	return shotFolder
end

----------------------------------------------------------------------
-- ИНТЕРФЕЙС
----------------------------------------------------------------------

local function uiFrame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

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

-- Панель с крупным планом глаз (ViewportFrame)
local function eyePanel(pos, size, sky, washColor, washRot, who)
	local panel = {}
	panel.sky = uiFrame(ui.split, { Position = pos, Size = size, BackgroundColor3 = C.white, ZIndex = 2, ClipsDescendants = true })
	gradient(panel.sky, sky, nil, 90)
	for i = 1, 5 do
		local cloud = uiFrame(panel.sky, {
			Position = UDim2.fromScale(rr(-0.1, 0.9), rr(-0.2, 0.7)),
			Size = UDim2.fromScale(rr(0.18, 0.4), rr(0.25, 0.5)),
			BackgroundColor3 = RGB(225, 230, 250),
			BackgroundTransparency = rr(0.72, 0.86),
			ZIndex = 2,
		})
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = cloud
	end
	local vp = Instance.new("ViewportFrame")
	vp.Position = pos
	vp.Size = size
	vp.BackgroundTransparency = 1
	vp.ZIndex = 3
	vp.Ambient = RGB(205, 195, 200)
	vp.LightColor = RGB(150, 140, 140)
	vp.LightDirection = V3(-0.4, -1, -0.5)
	vp.Parent = ui.split
	local cam = Instance.new("Camera")
	cam.FieldOfView = 20
	cam.Parent = vp
	vp.CurrentCamera = cam
	panel.vp, panel.cam = vp, cam
	panel.wash = uiFrame(ui.split, { Position = pos, Size = size, BackgroundColor3 = C.white, BackgroundTransparency = 1, ZIndex = 4 })
	gradient(panel.wash, { washColor, C.white }, { 0, 0.15, 1 }, washRot)

	-- бюст персонажа внутри панели: центр головы в (0, 0, 0)
	local rig
	if who == "yuta" then
		rig = buildYuta(vp, { look = 0.05, lookY = 0.015, angry = 7, cover = 0.12 }, false)
		rig:place(CF(0, -4.625, 0) * ANG(0, rad(-24), 0))
		rig:pose({ neck = { -4, 0, 3 } }, 0)
		panel.c0 = CFrame.lookAt(V3(0.34, 0.06, -2.35), V3(0.3, 0.05, 0))
		panel.c1 = CFrame.lookAt(V3(0.3, 0.06, -2.12), V3(0.27, 0.05, 0))
	else
		rig = buildRyu(vp, { look = -0.045, cover = 0.3, angry = 15 })
		rig:place(CF(0, -4.625, 0) * ANG(0, rad(24), 0))
		rig:pose({ neck = { -6, 0, -7 } }, 0)
		panel.c0 = CFrame.lookAt(V3(-0.34, 0.1, -2.35), V3(-0.3, 0.09, 0))
		panel.c1 = CFrame.lookAt(V3(-0.3, 0.1, -2.12), V3(-0.27, 0.09, 0))
	end
	rig:update(0)
	cam.CFrame = panel.c0
	return panel
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

	ui.split = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RGB(6, 6, 8), ZIndex = 1, Visible = false })
	ui.top = eyePanel(UDim2.fromScale(0.006, 0.012), UDim2.fromScale(0.988, 0.468),
		{ RGB(58, 78, 150), RGB(118, 136, 200) }, RGB(235, 175, 255), 0, "yuta")
	ui.bottom = eyePanel(UDim2.fromScale(0.006, 0.52), UDim2.fromScale(0.988, 0.468),
		{ RGB(70, 100, 175), RGB(150, 182, 228) }, RGB(160, 235, 255), 180, "ryu")
	-- рваная чёрная полоса между панелями
	for i = 1, 3 do
		uiFrame(ui.split, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.484 + i * 0.006),
			Size = UDim2.fromScale(1.05, 0.012),
			Rotation = rr(-0.35, 0.35),
			BackgroundColor3 = RGB(6, 6, 8),
			ZIndex = 5,
		})
	end

	ui.tint = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BackgroundTransparency = 1, ZIndex = 5 })
	ui.flash = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BackgroundTransparency = 1, ZIndex = 6 })
	ui.flashGrad = gradient(ui.flash, { C.white, C.white }, nil, 0)
	ui.black = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.black, BackgroundTransparency = 1, ZIndex = 7 })

	-- стартовый экран
	ui.start = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RGB(8, 8, 14), ZIndex = 10 })
	uiText(ui.start, "TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromScale(0.8, 0.16),
		Text = 'РЮ <font color="#ff4fc0">vs</font> ЮТА', RichText = true, ZIndex = 11,
	})
	uiText(ui.start, "TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromScale(0.7, 0.05),
		Text = "фан-анимация по «Магической битве» · часть 1", Font = Enum.Font.GothamBold,
		TextColor3 = RGB(170, 220, 255), ZIndex = 11,
	})
	ui.startBtn = uiText(ui.start, "TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(0.22, 0.09),
		Text = "▶ СТАРТ", BackgroundTransparency = 0, BackgroundColor3 = RGB(255, 60, 170), ZIndex = 11, AutoButtonColor = true,
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = ui.startBtn
	uiText(ui.start, "TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.fromScale(0.8, 0.035),
		Text = "Сначала включи запись экрана · ПРОБЕЛ — старт · R — повтор", Font = Enum.Font.GothamBold,
		TextColor3 = RGB(150, 150, 170), ZIndex = 11,
	})

	-- экран после конца
	ui.endScreen = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 10, Visible = false })
	uiText(ui.endScreen, "TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.6, 0.07),
		Text = "Часть 1 — конец", ZIndex = 11,
	})
	ui.againBtn = uiText(ui.endScreen, "TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.57), Size = UDim2.fromScale(0.22, 0.08),
		Text = "↻ ЕЩЁ РАЗ (R)", BackgroundTransparency = 0, BackgroundColor3 = RGB(40, 170, 255), ZIndex = 11, AutoButtonColor = true,
	})
	local corner2 = Instance.new("UICorner")
	corner2.CornerRadius = UDim.new(0.25, 0)
	corner2.Parent = ui.againBtn
end

----------------------------------------------------------------------
-- КАДРЫ
----------------------------------------------------------------------

-- 0:00–4:83 — глаза Юты и Рю в двух полосах
local function shotEyes()
	beginShot(0)
	ui.split.Visible = true
	ui.top.wash.BackgroundTransparency = 1
	ui.bottom.wash.BackgroundTransparency = 1
	camCF = CF(0, 2000, 0)
	local top, bot = ui.top, ui.bottom
	shot.update = function(u)
		local k = smooth(u / T.WHITE)
		local j = 0.0025 + 0.004 * clamp01((u - 3.4) / 1.2)
		top.cam.CFrame = top.c0:Lerp(top.c1, k) * CF(noise(u * 7, 1.1) * j, noise(u * 7, 2.2) * j, 0)
		bot.cam.CFrame = bot.c0:Lerp(bot.c1, k) * CF(noise(u * 7, 3.3) * j, noise(u * 7, 4.4) * j, 0)
		local g = easeIn(clamp01((u - T.GLOW) / (T.WHITE - T.GLOW)))
		top.wash.BackgroundTransparency = 1 - g * 0.9
		bot.wash.BackgroundTransparency = 1 - g * 0.9
		ui.flash.BackgroundTransparency = 1 - easeIn(clamp01((u - 4.6) / (T.WHITE - 4.6)))
	end
end

-- 4:83–7:83 — вспышка и столкновение лучей, Рика справа сверху
local function shotClash()
	local f = beginShot(T.WHITE)
	grade(RGB(232, 255, 244), 0.4, 0.18, 0.02, 1.3)
	setAmbient(RGB(95, 115, 112), RGB(85, 105, 108))
	ui.flashGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, RGB(110, 240, 180)),
		ColorSequenceKeypoint.new(0.5, C.white),
		ColorSequenceKeypoint.new(1, RGB(255, 140, 215)),
	})
	ui.flashGrad.Rotation = 15
	ui.flash.BackgroundTransparency = 0
	fx.blur.Size = 26

	local P = CLASH_POINT
	local cam0 = CFrame.lookAt(P + V3(-15, -7, -38), P + V3(1, 2, 0)) * ANG(0, 0, rad(-8))
	local cam1 = CFrame.lookAt(P + V3(-12, -6, -31), P + V3(1, 2.5, 0)) * ANG(0, 0, rad(-10))
	camCF, camFOV = cam0, 72

	-- Рика сидит на обломке справа сверху и бьёт лучом из пасти
	local rp = cam0 * V3(64, 24, -66)
	rika:show(true)
	rika:place(CFrame.lookAt(rp, V3(P.X, rp.Y, P.Z)))
	rika:pose(POSE.rikaCrouch, 0)
	rika:update(songT)
	newPart(f, V3(30, 80, 26), RGB(34, 40, 44), CF(rp.X, rp.Y - 4.6 - 40, rp.Z + 4) * ANG(0, rad(20), 0), { material = Enum.Material.Concrete })
	for i = 1, 4 do
		newPart(f, V3(0.6, 0.6, rr(8, 14)), C.red, CF(rp + V3(rr(-12, 12), -rr(5, 12), rr(-8, 8))) * ANG(rr(-1, 1), rr(0, 6), rr(-1, 1)))
	end

	local pink = makeBeam(f, C.pink, 2.2)
	local cyan = makeBeam(f, C.cyan, 2.8)
	local cyanFrom = cam0 * V3(-34, -19, -20)

	local core = newPart(f, V3(7, 7, 7), C.white, CF(P), { neon = true, shape = "ball" })
	local glow1 = newPart(f, V3(13, 13, 13), C.yellow, CF(P), { neon = true, shape = "ball", alpha = 0.4 })
	local glow2 = newPart(f, V3(26, 26, 26), RGB(255, 250, 225), CF(P), { neon = true, shape = "ball", alpha = 0.8 })
	local light = Instance.new("PointLight")
	light.Range = 70
	light.Brightness = 6
	light.Color = C.yellow
	light.Parent = core
	local burst = starburst(f, P, 18, { C.yellow, C.white, C.pinkHot, C.cyan, C.gold }, 8, 28, 1.2)
	local bolts = {
		lightning(f, RGB(230, 255, 255), 0.18),
		lightning(f, RGB(255, 250, 200), 0.14),
		lightning(f, RGB(200, 255, 255), 0.16),
		lightning(f, RGB(255, 255, 255), 0.12),
	}
	-- зелёный дым сзади слева, тёмный снизу справа
	local smokes = {}
	for i = 1, 8 do
		local pos = cam0 * V3(rr(-70, -10), rr(8, 40), -rr(55, 90))
		local s = rr(20, 38)
		smokes[#smokes + 1] = { p = newPart(f, V3(s, s * 0.8, s), RGB(35, rr(130, 175), 115), CF(pos), { shape = "ball", alpha = rr(0.4, 0.6) }), v = V3(rr(-2, 2), rr(1, 3), 0) }
	end
	for i = 1, 6 do
		local pos = cam0 * V3(rr(10, 60), rr(-30, -14), -rr(40, 70))
		local s = rr(16, 30)
		smokes[#smokes + 1] = { p = newPart(f, V3(s, s * 0.7, s), RGB(48, 72, 52), CF(pos), { shape = "ball", alpha = rr(0.25, 0.45) }), v = V3(rr(-1, 1), rr(0, 1), 0) }
	end

	local toCam = (cam0.Position - P).Unit
	local acc = { shard = 0, rock = 0, girder = 0, teal = 0, dark = 0 }
	local function spawn(kind)
		local dir = (toCam * 0.9 + V3(rr(-1, 1), rr(-0.7, 1), rr(-1, 1))).Unit
		if kind == "shard" then
			flyer(f, V3(0.15, rr(0.8, 2.8), rr(1.2, 4.5)), pick({ C.yellow, C.gold, RGB(255, 246, 205) }), P + dir * rr(2, 5), dir * rr(28, 62),
				{ neon = true, wedge = true, life = rr(0.55, 1.0), spin = 9 })
		elseif kind == "rock" then
			flyer(f, V3(rr(0.7, 2.6), rr(0.6, 2.2), rr(0.7, 2.6)), C.rock, P + dir * rr(3, 6), dir * rr(18, 40),
				{ material = Enum.Material.Slate, life = rr(0.9, 1.4), spin = 5, gravity = 18 })
		elseif kind == "girder" then
			flyer(f, V3(0.4, 0.4, rr(3, 9)), C.red, P + dir * rr(3, 6), dir * rr(14, 30), { life = rr(1, 1.6), spin = 4, gravity = 10 })
		elseif kind == "teal" then
			flyer(f, V3(0.12, rr(0.6, 1.8), rr(0.8, 2.6)), RGB(110, 245, 225), P + dir * rr(4, 10), dir * rr(22, 48),
				{ neon = true, wedge = true, life = 0.9, spin = 7 })
		else
			flyer(f, V3(0.1, rr(0.5, 1.4), rr(0.5, 1.6)), RGB(20, 40, 45), P + dir * rr(4, 10), dir * rr(20, 40),
				{ wedge = true, life = 0.9, spin = 7 })
		end
	end

	local tReroll, tBolt = 0, 0
	local tealBall = nil
	shot.update = function(u, dt)
		local k = smooth(u / (T.CITY - T.WHITE))
		camCF = cam0:Lerp(cam1, k)
		camFOV = lerp(72, 64, k)
		-- белая вспышка 4:83–5:40
		local w = T.CLASH - T.WHITE
		if u < w then
			ui.flash.BackgroundTransparency = lerp(0, 0.5, u / w)
			fx.blur.Size = lerp(26, 6, u / w)
			shake = 1.7
		else
			ui.flash.BackgroundTransparency = clamp01(0.5 + (u - w) * 3.5)
			fx.blur.Size = math.max(0, 6 - (u - w) * 30)
			shake = 0.8 + 0.25 * math.sin(u * 31)
		end
		-- лучи
		local mouth = rika:point("head", RIKA_MOUTH)
		pink.set(mouth, P, 2.1 + math.sin(u * 50) * 0.35)
		cyan.set(cyanFrom, P, 2.8 + math.sin(u * 43 + 1) * 0.45)
		-- пульсация ядра
		local pulse = 1 + math.sin(u * 40) * 0.12 + rr(-0.05, 0.05)
		core.Size = V3(7, 7, 7) * pulse
		glow1.Size = V3(13, 13, 13) * (pulse + 0.1)
		glow2.Size = V3(26, 26, 26) * (1 + math.sin(u * 23) * 0.08)
		tReroll = tReroll - dt
		if tReroll <= 0 then
			tReroll = 0.07
			burst.reroll()
		end
		tBolt = tBolt - dt
		if tBolt <= 0 then
			tBolt = 0.05
			for _, b in ipairs(bolts) do
				local dir = V3(rr(-1, 1), rr(-0.6, 1), rr(-1, 1)).Unit
				b.strike(P, P + dir * rr(16, 34), 9, 1.8)
			end
		end
		for _, s in ipairs(smokes) do
			s.p.CFrame = s.p.CFrame + s.v * dt
			s.p.Size = s.p.Size * (1 + 0.05 * dt)
		end
		-- обломки
		local late = u > 2.15
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
		-- финал кадра: бирюзовая волна заливает экран
		if late then
			local g = clamp01((u - 2.15) / (T.CITY - T.WHITE - 2.15))
			if not tealBall then
				tealBall = newPart(f, V3(1, 1, 1), C.teal, CF(P), { neon = true, shape = "ball", alpha = 0.5 })
			end
			local s = lerp(10, 46, easeOut(g))
			tealBall.Size = V3(s, s, s)
			tealBall.Transparency = lerp(0.75, 0.55, g)
			ui.tint.BackgroundColor3 = RGB(90, 235, 215)
			ui.tint.BackgroundTransparency = lerp(1, 0.5, g)
			shake = lerp(0.9, 1.7, g)
		end
	end
end

-- 7:83–8:70 — общий план ночного города: розовый и голубой взрыв
local function shotCity()
	local f = beginShot(T.CITY)
	grade(RGB(222, 236, 255), 0.25, 0.12, 0.02, 1.0)
	setAmbient(RGB(92, 118, 132), RGB(86, 112, 128))
	local P = CLASH_POINT + V3(0, -4, 0)
	local cam0 = CFrame.lookAt(CITY_CAM, P + V3(0, 26, 0))
	local cam1 = CFrame.lookAt(CITY_CAM + (P - CITY_CAM).Unit * 16, P + V3(0, 27, 0))
	camCF, camFOV = cam0, 46
	local right, up = cam0.RightVector, cam0.UpVector

	local clouds = {}
	local function cloud(col, side)
		local pos = P + right * side * rr(2, 30) + up * rr(-2, 46) + cam0.LookVector * rr(-12, 12)
		local s = rr(10, 28)
		clouds[#clouds + 1] = {
			p = newPart(f, V3(s, s * rr(0.8, 1.3), s), col, CF(pos), { neon = true, shape = "ball", alpha = rr(0.45, 0.75) }),
			v = up * rr(3, 9) + right * side * rr(1, 5),
		}
	end
	for _ = 1, 16 do
		cloud(pick({ C.pink, C.pinkHot, RGB(170, 80, 200) }), -1)
	end
	for _ = 1, 16 do
		cloud(pick({ C.cyan, C.teal, RGB(120, 230, 255) }), 1)
	end
	for i = 0, 5 do
		newPart(f, V3(16 - i, 22, 16 - i), RGB(215, 185, 245), CF(P + up * (16 + i * 14)), { neon = true, shape = "ball", alpha = 0.72 + i * 0.04 })
	end
	newPart(f, V3(20, 14, 20), C.white, CF(P + up * 4), { neon = true, shape = "ball", alpha = 0.1 })
	local light = Instance.new("PointLight")
	light.Range = 120
	light.Brightness = 4
	light.Color = RGB(230, 170, 255)
	light.Parent = newPart(f, V3(1, 1, 1), C.white, CF(P + up * 10), { alpha = 1 })

	-- куски-осколки
	for _ = 1, 230 do
		local side = 1
		if rng:NextNumber() < 0.5 then
			side = -1
		end
		local col = C.pinkHot
		if side > 0 then
			col = pick({ C.cyan, RGB(150, 245, 255) })
		end
		local dir = (right * side * rr(0.2, 1) + up * rr(0.1, 1.2) + cam0.LookVector * rr(-0.5, 0.5)).Unit
		flyer(f, V3(rr(1.2, 3.6), rr(0.8, 2.6), 0.15), col, P + up * rr(4, 34) + dir * rr(0, 14), dir * rr(8, 30),
			{ neon = true, life = rr(0.8, 1.2), spin = 3, gravity = 4 })
	end
	-- голубые полосы улетают вправо вверх
	for _ = 1, 9 do
		local pos = P + up * rr(10, 40) + right * rr(0, 20)
		local dir = (right * 1.0 + up * rr(0.4, 0.8)).Unit
		local p = newPart(f, V3(0.5, 0.5, rr(18, 34)), RGB(140, 245, 255), CFrame.lookAt(pos, pos + dir), { neon = true })
		local speed = rr(80, 140)
		addUpdater(function(dt)
			if not p.Parent then
				return false
			end
			p.CFrame = p.CFrame + dir * speed * dt
			return true
		end)
	end

	shot.update = function(u, dt)
		local k = u / (T.YUTA - T.CITY)
		camCF = cam0:Lerp(cam1, smooth(k))
		shake = 0.22
		for _, c in ipairs(clouds) do
			c.p.CFrame = c.p.CFrame + c.v * dt
			c.p.Size = c.p.Size * (1 + 0.25 * dt)
		end
	end
end

-- 8:70–10:00 — Юта вытягивает руку, огромная Рика за спиной, мимо летят голубые и жёлтые полосы
local function shotYuta()
	local f = beginShot(T.YUTA)
	grade(RGB(255, 232, 248), 0.25, 0.14, 0.03, 0.9)
	setAmbient(RGB(255, 215, 240), RGB(255, 205, 235))
	local base = V3(4000, 400, 0)
	local cam0 = CFrame.lookAt(base, base + V3(0, 0.08, -1))
	local cam1 = cam0 * CF(-0.3, 0.1, -0.6)
	camCF, camFOV = cam0, 52

	-- задник: розово-малиновое свечение
	newPart(f, V3(900, 600, 2), RGB(235, 140, 215), cam0 * CF(0, 0, -260))
	newPart(f, V3(70, 60, 30), RGB(255, 225, 245), cam0 * CF(20, 10, -120), { neon = true, shape = "ball", alpha = 0.75 })
	newPart(f, V3(120, 120, 40), RGB(255, 150, 225), cam0 * CF(-60, 35, -180), { neon = true, shape = "ball", alpha = 0.7 })
	newPart(f, V3(140, 110, 40), RGB(150, 30, 130), cam0 * CF(70, -50, -200), { neon = true, shape = "ball", alpha = 0.5 })

	yuta:show(true)
	yuta:place(cam0 * CF(1.1, -4.5, -8.0) * ANG(0, rad(112), 0))
	yuta:pose(POSE.yutaCast, 0)
	rika:show(true)
	rika:place(cam0 * CF(7.5, -8.5, -16) * ANG(0, rad(104), 0))
	rika:pose(POSE.rikaReach, 0)
	yuta:update(songT)
	rika:update(songT)

	-- розовый удар из ладони Юты (вверху слева)
	local hand = yuta:point("lArm", V3(0, -1.6, 0))
	local armDir = (hand - yuta:point("lArm", V3(0, 0, 0))).Unit
	local hit = hand + armDir * 2.2
	local core = newPart(f, V3(1.4, 1.4, 1.4), RGB(255, 235, 250), CF(hit), { neon = true, shape = "ball" })
	local glow = newPart(f, V3(3.4, 3.4, 3.4), C.pink, CF(hit), { neon = true, shape = "ball", alpha = 0.5 })
	local burst = starburst(f, hit, 14, { C.pinkHot, C.white, C.pink, RGB(255, 200, 240) }, 2, 8, 0.4)
	burst.dirBias = (armDir + V3(-0.3, 0.3, 0)) * 0.7

	-- полосы мимо камеры: сверху справа вниз влево
	local streaks = {}
	local sdir = (cam0.RightVector * -1 + cam0.UpVector * -0.5).Unit
	for i = 1, 6 do
		local col, wdt = C.cyan, rr(0.22, 0.4)
		if i % 3 == 0 then
			col, wdt = RGB(255, 222, 150), rr(0.18, 0.3)
		end
		local p = newPart(f, V3(wdt, wdt * 0.4, rr(8, 14)), col, nil, { neon = true })
		streaks[i] = { p = p, off = rr(-3, 3), depth = rr(4.6, 6.5), t = rr(0, 1), speed = rr(1.2, 2.2) }
	end

	shot.update = function(u, dt)
		local k = smooth(u / (T.RYU - T.YUTA))
		camCF = cam0:Lerp(cam1, k)
		shake = 0.16 + 0.08 * math.sin(u * 20)
		local pulse = 1 + math.sin(u * 37) * 0.15
		core.Size = V3(1.4, 1.4, 1.4) * pulse
		glow.Size = V3(3.4, 3.4, 3.4) * (pulse + 0.1)
		if math.floor(u * 14) ~= math.floor((u - dt) * 14) then
			burst.reroll()
		end
		local normal = (cam0.RightVector * 0.5 + cam0.UpVector * -1).Unit
		for _, s in ipairs(streaks) do
			s.t = s.t + dt * s.speed
			if s.t > 1 then
				s.t = s.t - 1
				s.off = rr(-3, 3)
			end
			local center = cam0 * V3(0, 0, -s.depth) + normal * s.off
			local pos = center + sdir * lerp(-12, 12, s.t)
			s.p.CFrame = CFrame.lookAt(pos, pos + sdir)
		end
	end
end

-- 10:00–11:17 — Рю отбрасывает голубым взрывом
local function shotRyu()
	local f = beginShot(T.RYU)
	grade(RGB(218, 236, 255), 0.35, 0.16, 0.02, 1.0)
	setAmbient(RGB(150, 185, 235), RGB(140, 175, 230))
	ui.flash.BackgroundTransparency = 0.3
	local base = V3(-4000, 400, 0)
	local cam0 = CFrame.lookAt(base, base + V3(0, 0.12, -1)) * ANG(0, 0, rad(6))
	local cam1 = cam0 * CF(0.2, 0.1, -0.7)
	camCF, camFOV = cam0, 56

	newPart(f, V3(900, 600, 2), RGB(18, 48, 120), cam0 * CF(0, 0, -260))
	newPart(f, V3(120, 90, 40), RGB(40, 110, 220), cam0 * CF(40, 30, -200), { neon = true, shape = "ball", alpha = 0.7 })

	ryu:show(true)
	ryu:place(cam0 * CF(-1.0, -3.7, -8.4) * ANG(0, rad(164), 0))
	ryu:pose(POSE.ryuHit, 0)
	ryu:update(songT)
	ryu:pose({ root = { 20, -8, -8 }, neck = { 24, 12, 10 }, rArm = { 46, 0, 82 }, lArm = { 86, 0, -36 }, rLeg = { -18, 0, 4 }, lLeg = { 16, 0, -4 } }, 1.17, songT)

	local face = ryu:point("neck", V3(0, 0.7, 0))
	local hit = face + cam0.RightVector * 1.7 + cam0.UpVector * 0.9 - cam0.LookVector * 0.4
	local core = newPart(f, V3(0.9, 0.9, 0.9), RGB(235, 255, 255), CF(hit), { neon = true, shape = "ball" })
	local glow = newPart(f, V3(2.2, 2.2, 2.2), C.cyan, CF(hit), { neon = true, shape = "ball", alpha = 0.45 })
	local glow2 = newPart(f, V3(4.2, 4.2, 4.2), C.cyanDeep, CF(hit), { neon = true, shape = "ball", alpha = 0.82 })
	local burst = starburst(f, hit, 16, { C.cyan, C.white, RGB(160, 240, 255), C.pinkHot }, 1.5, 6, 0.32)
	local toCam = (cam0.Position - hit).Unit

	local acc = { shard = 0, spark = 0, streak = 0 }
	shot.update = function(u, dt)
		local k = smooth(u / (T.FIN - T.RYU))
		camCF = cam0:Lerp(cam1, k)
		shake = lerp(1.0, 0.45, k)
		ui.flash.BackgroundTransparency = clamp01(0.3 + u * 6)
		local pulse = 1 + math.sin(u * 35) * 0.15 + u * 0.35
		core.Size = V3(0.9, 0.9, 0.9) * pulse
		glow.Size = V3(2.2, 2.2, 2.2) * (pulse + 0.15)
		glow2.Size = V3(4.2, 4.2, 4.2) * (1 + u * 0.45)
		if math.floor(u * 14) ~= math.floor((u - dt) * 14) then
			burst.scale = 1 + u * 0.4
			burst.reroll()
		end
		acc.shard = acc.shard + 60 * dt
		while acc.shard >= 1 do
			acc.shard = acc.shard - 1
			local dir = (toCam * 0.5 + cam0.RightVector * rr(-0.4, 1.2) + V3(rr(-1, 1), rr(-0.8, 1), rr(-1, 1))).Unit
			flyer(f, V3(0.06, rr(0.2, 0.6), rr(0.3, 0.9)), pick({ C.cyan, RGB(140, 240, 255), RGB(90, 210, 255) }), hit + dir * rr(0.4, 1.5), dir * rr(7, 16),
				{ neon = true, wedge = true, life = rr(0.5, 1.0), spin = 6 })
		end
		acc.spark = acc.spark + 40 * dt
		while acc.spark >= 1 do
			acc.spark = acc.spark - 1
			local pos = cam0 * V3(rr(-5, 0.5), rr(-3, 3), -rr(5, 8))
			flyer(f, V3(0.05, 0.05, rr(0.2, 0.5)), RGB(255, 90, 210), pos, cam0.UpVector * rr(-2, 2) + cam0.RightVector * rr(-1, 1),
				{ neon = true, life = rr(0.2, 0.45), spin = 0 })
		end
		acc.streak = acc.streak + 6 * dt
		while acc.streak >= 1 do
			acc.streak = acc.streak - 1
			local pos = cam0 * V3(rr(2, 5), rr(-2.5, 2), -rr(6, 8))
			local dir = (cam0.RightVector * -1 + cam0.UpVector * 0.35).Unit
			flyer(f, V3(0.16, 0.05, rr(2.5, 4.5)), RGB(255, 225, 140), pos, dir * 22, { neon = true, life = 0.35, spin = 0 })
		end
	end
end

----------------------------------------------------------------------
-- ЗАПУСК
----------------------------------------------------------------------

local savedCharCF = nil
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

local sound = nil
local function waitUntil(t)
	while playing and songT < t do
		RunService.RenderStepped:Wait()
	end
end

local function finish()
	ui.black.BackgroundTransparency = 0
	playing = false
	shot = nil
	updaters = {}
	if shotFolder then
		shotFolder:Destroy()
		shotFolder = nil
	end
	for _, r in ipairs(allRigs) do
		r:show(false)
	end
	fx.blur.Size = 0
	ui.split.Visible = false
	ui.endScreen.Visible = true
	camera.CameraType = Enum.CameraType.Custom
	releaseCharacter()
	setCoreUI(true)
end

local function play()
	if playing then
		return
	end
	ui.start.Visible = false
	ui.endScreen.Visible = false
	ui.black.BackgroundTransparency = 1
	setCoreUI(false)
	parkCharacter()
	songT = 0
	playing = true
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
	shotEyes()
	waitUntil(T.WHITE)
	shotClash()
	waitUntil(T.CITY)
	shotCity()
	waitUntil(T.YUTA)
	shotYuta()
	waitUntil(T.RYU)
	shotRyu()
	waitUntil(T.FIN)
	finish()
end

local function onFrame(dt)
	if not playing then
		return
	end
	if dt > 0.1 then
		dt = 0.1
	end
	songT = songT + dt
	if shot and shot.update then
		shot.update(songT - shot.t0, dt)
	end
	for _, r in ipairs(allRigs) do
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
	camera.CameraType = Enum.CameraType.Scriptable
	local s = CF()
	if shake > 0.001 then
		local k = songT * 24
		s = CF(noise(k, 0.31) * shake, noise(k, 7.7) * shake, 0) * ANG(0, 0, rad(noise(k, 3.3) * shake * 2.5))
	end
	camera.CFrame = camCF * s
	camera.FieldOfView = camFOV
end

local function setup()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.5
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.GlobalShadows = false
	Lighting.FogColor = RGB(16, 22, 44)
	Lighting.FogStart = 200
	Lighting.FogEnd = 1100
	Lighting.ExposureCompensation = 0
	for _, ch in ipairs(Lighting:GetChildren()) do
		if ch:IsA("Atmosphere") then
			ch.Parent = nil
		end
	end
	setAmbient(RGB(70, 80, 110), RGB(65, 78, 108))
	fx.cc = Instance.new("ColorCorrectionEffect")
	fx.cc.Parent = Lighting
	fx.bloom = Instance.new("BloomEffect")
	fx.bloom.Size = 32
	fx.bloom.Threshold = 0.85
	fx.bloom.Parent = Lighting
	fx.blur = Instance.new("BlurEffect")
	fx.blur.Size = 0
	fx.blur.Parent = Lighting
	grade(C.white, 0, 0, 0, 0.8)

	buildCity(world)
	yuta = buildYuta(world, { look = 0.04, angry = 14, cover = 0.1 }, true)
	ryu = buildRyu(world, { look = 0, cover = 0.05, angry = 26, mouth = "open" })
	rika = buildRika(world)
	allRigs = { yuta, ryu, rika }
	for _, r in ipairs(allRigs) do
		r:show(false)
	end

	buildUI()
	if CONFIG.SOUND_ID ~= "" then
		sound = Instance.new("Sound")
		sound.SoundId = CONFIG.SOUND_ID
		sound.Volume = 1
		sound.Parent = workspace
	end

	RunService.RenderStepped:Connect(onFrame)
	local function tryPlay()
		if not playing then
			task.spawn(play)
		end
	end
	ui.startBtn.Activated:Connect(tryPlay)
	ui.againBtn.Activated:Connect(tryPlay)
	UserInputService.InputBegan:Connect(function(input)
		-- не реагируем, пока игрок печатает в чате
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.R then
			tryPlay()
		end
	end)
	if CONFIG.AUTO_START then
		task.delay(1, tryPlay)
	end
end

setup()
