-- Мебель и мелочи по комнатам. Предметы — Model с атрибутом Outline (контур как в мультике).
-- Подсказки «Осмотреть» с атрибутом Thought показывают мысль Морти (текст — Config.Text[Thought]).
-- Метки для сюжета (камера в кровати, стул на кухне и т.д.) — в папке House.Markers.
local Rooms = {}

local B, C
local FURN, LIGHTS, MARK

local Y1, Y2 = 0, 12

local function item(name, cf, outline)
	local m = B.model(FURN, name)
	if outline ~= false then B.outline(m) end
	return m, B.kit(m, cf)
end

local function inspect(part, thought, action, dist)
	local p = B.prompt(part, "Inspect", action or "Осмотреть", "", { MaxActivationDistance = dist or 6 })
	p:SetAttribute("Thought", thought)
	return p
end

local function mark(name, cf)
	return B.marker(MARK, name, Vector3.new(1, 1, 1), cf)
end

-- потолочный светильник: плафон + PointLight (включает клиент по сцене)
local function ceilingLamp(room, x, y, z, d, color)
	local lamp = B.vcyl(LIGHTS, "Lamp", 0.45, d or 2.6, CFrame.new(x, y - 0.25, z), "#FFF6E2", Enum.Material.SmoothPlastic, { CastShadow = false })
	B.vcyl(LIGHTS, "LampBase", 0.15, (d or 2.6) + 0.4, CFrame.new(x, y - 0.06, z), "#E9E2D2", nil, { CastShadow = false })
	B.attrs(lamp, { Room = room, Glow = true })
	B.light(lamp, "PointLight", { Color = color or Color3.fromRGB(255, 226, 186), Brightness = 1.2, Range = 22, Enabled = false, Shadows = true })
	return lamp
end

-- стул (классический деревянный): cf — центр на полу, смотрит в −Z
local function chair(name, cf, color)
	local m, P = item(name, cf)
	color = color or "#B3784A"
	P("Seat", 2.2, 0.3, 2.2, 0, 2.1, 0, color)
	for _, p in ipairs({ { -0.9, -0.9 }, { 0.9, -0.9 }, { -0.9, 0.9 }, { 0.9, 0.9 } }) do
		P("Leg", 0.25, 2.0, 0.25, p[1], 1.0, p[2], B.shade(color, 0.85))
	end
	P("Back", 2.2, 2.4, 0.25, 0, 3.4, 0.98, color)
	P("BackRail", 0.25, 2.4, 0.25, -0.98, 3.4, 0.98, B.shade(color, 0.85))
	P("BackRail", 0.25, 2.4, 0.25, 0.98, 3.4, 0.98, B.shade(color, 0.85))
	return m
end

-- растение в горшке
local function plant(name, cf, s)
	s = s or 1
	local m, P = item(name, cf)
	P.vcyl("Pot", 1.4 * s, 1.5 * s, 0, 0.7 * s, 0, "#C4673F")
	P.vcyl("Soil", 0.1, 1.3 * s, 0, 1.38 * s, 0, "#5A3A22")
	P.ball("Leaves", 2.2 * s, 0, 2.6 * s, 0, "#4F9A45")
	P.ball("Leaves", 1.6 * s, 0.6 * s, 3.4 * s, 0.2 * s, "#5DAE50")
	P.ball("Leaves", 1.5 * s, -0.6 * s, 3.2 * s, -0.3 * s, "#468C3E")
	return m
end

-- рамка с картинкой на стене: cf — центр, смотрит в −Z (картинка на передней грани)
local function picture(name, cf, w, h, draw)
	local m, P = item(name, cf)
	P("Frame", w + 0.3, h + 0.3, 0.15, 0, 0, 0, "#6B4A2E")
	local canvas = P("Canvas", w, h, 0.05, 0, 0, -0.08, "#F4EFE4")
	local g = B.surface(canvas, Enum.NormalId.Front, 40)
	draw(g)
	return m, canvas
end

-- рисунки для плакатов и фото (рисуем рамками GUI, без картинок)
local function drawSpace(g)
	B.rect(g, 0, 0, 1, 1, "#1B1046")
	for i = 1, 22 do
		local x, y = ((i * 37) % 97) / 100, ((i * 53) % 89) / 100
		B.rect(g, x, y, 0.015, 0.011, "#FFFFFF")
	end
	B.circle(g, 0.3, 0.27, 0.42, 0.3, "#FF8A3D")
	B.rect(g, 0.12, 0.4, 0.78, 0.04, "#FFD27A", { Rotation = -12 })
	B.text(g, 0.05, 0.8, 0.9, 0.13, "КОСМОС", "#FFFFFF")
end
local function drawDino(g)
	B.rect(g, 0, 0, 1, 1, "#F2C230")
	B.text(g, 0.05, 0.04, 0.9, 0.12, "ДИНО-ЭКСПО", "#1B1B1B")
	B.circle(g, 0.22, 0.42, 0.5, 0.25, "#2B7A3B")
	B.rect(g, 0.6, 0.22, 0.1, 0.32, "#2B7A3B")
	B.circle(g, 0.55, 0.16, 0.22, 0.14, "#2B7A3B")
	B.rect(g, 0.3, 0.62, 0.08, 0.2, "#2B7A3B")
	B.rect(g, 0.52, 0.62, 0.08, 0.2, "#2B7A3B")
	B.text(g, 0.1, 0.86, 0.8, 0.08, "МУЗЕЙ · СУББОТА", "#1B1B1B", Enum.Font.GothamBold)
end
local function drawBand(g)
	B.rect(g, 0, 0, 1, 1, "#D6324A")
	B.text(g, 0.06, 0.08, 0.88, 0.22, "ШЛЁП", "#111111")
	B.text(g, 0.06, 0.3, 0.88, 0.22, "ТАПКИ", "#111111")
	for i = 0, 4 do B.circle(g, 0.1 + i * 0.17, 0.66, 0.12, 0.09, "#FFE14A") end
	B.text(g, 0.1, 0.84, 0.8, 0.1, "ТУР 2026", "#FFFFFF", Enum.Font.GothamBold)
end
local function drawCalendar(g)
	B.rect(g, 0, 0, 1, 1, "#FFFFFF")
	B.rect(g, 0, 0, 1, 0.2, "#E2504A")
	B.text(g, 0.05, 0.03, 0.9, 0.14, "НОЯБРЬ", "#FFFFFF")
	for r = 0, 4 do
		for c = 0, 6 do
			local n = r * 7 + c - 4
			if n >= 1 and n <= 30 then
				B.text(g, 0.04 + c * 0.135, 0.25 + r * 0.14, 0.12, 0.1, tostring(n), n == 3 and "#E2504A" or "#333333", Enum.Font.GothamBold)
			end
		end
	end
	B.circle(g, 0.04 + 0 * 0.135 - 0.01, 0.25 + 1 * 0.14 - 0.02, 0.14, 0.14, "#E2504A", { BackgroundTransparency = 0.6 })
end
local function drawFamily(g)
	B.rect(g, 0, 0, 1, 1, "#9FD0F0")
	B.rect(g, 0, 0.7, 1, 0.3, "#7CC46A")
	local people = { { 0.1, "#B9C3CC", 0.62, "#9FB7C9" }, { 0.28, "#E9A06A", 0.55, "#F1D2B0" }, { 0.46, "#F2D85A", 0.5, "#F1D2B0" },
		{ 0.62, "#F08AB0", 0.52, "#F1D2B0" }, { 0.8, "#6D8F5A", 0.56, "#F1D2B0" } }
	for _, p in ipairs(people) do
		B.rect(g, p[1], p[3] + 0.12, 0.14, 0.35, p[2])
		B.circle(g, p[1] + 0.02, p[3] - 0.02, 0.1, 0.15, p[4])
	end
	B.rect(g, 0.1, 0.42, 0.14, 0.06, "#C9D6E2") -- седые волосы деда
	B.text(g, 0.55, 0.88, 0.42, 0.1, "Смиты", "#FFFFFF", Enum.Font.GothamBold)
end
local function drawLandscape(g)
	B.rect(g, 0, 0, 1, 1, "#F3B36B")
	B.circle(g, 0.6, 0.15, 0.25, 0.3, "#FFE48A")
	B.rect(g, 0, 0.55, 1, 0.45, "#5E8F6A")
	B.rect(g, 0, 0.75, 1, 0.25, "#3F6B52")
end

---------------------------------------------------------------------------
-- Комната Морти (x 36..56, z 20..40, пол y = 12)
---------------------------------------------------------------------------
local function mortyRoom()
	local y = Y2
	-- кровать: изголовье у северной стены
	local bed, P = item("Bed", CFrame.new(40.8, y, 35.55))
	local wood = "#8A5A36"
	for _, p in ipairs({ { -2.6, -3.8 }, { 2.6, -3.8 }, { -2.6, 3.8 }, { 2.6, 3.8 } }) do P("Leg", 0.4, 0.45, 0.4, p[1], 0.22, p[2], B.shade(wood, 0.8)) end
	P("Base", 5.6, 0.9, 8.0, 0, 0.88, 0, wood)
	P("Mattress", 5.3, 0.9, 7.6, 0, 1.75, -0.1, "#F5F3EE")
	P("Headboard", 5.9, 3.8, 0.4, 0, 1.9, 3.9, wood)
	P("HeadboardTop", 6.1, 0.3, 0.6, 0, 3.85, 3.9, B.shade(wood, 0.85))
	P("Footboard", 5.9, 1.9, 0.35, 0, 0.95, -3.95, wood)
	local blue = "#3F6FD0"
	P("Blanket", 5.5, 0.35, 5.4, 0.05, 2.36, -1.1, blue, Enum.Material.Fabric, nil, CFrame.Angles(0, 0, math.rad(1.5)))
	P("BlanketSide", 0.25, 1.15, 5.4, 2.78, 1.85, -1.1, blue, Enum.Material.Fabric)
	P("BlanketFold", 5.3, 0.45, 1.2, 0.2, 2.6, 1.95, "#5A86E0", Enum.Material.Fabric, nil, CFrame.Angles(math.rad(-8), math.rad(6), 0))
	P("Pillow", 3.6, 0.8, 1.6, -0.2, 2.6, 2.9, "#FFFFFF", Enum.Material.Fabric, nil, CFrame.Angles(math.rad(8), math.rad(-5), 0))
	inspect(bed.Mattress, "Bed", "Осмотреть", 7)
	mark("BedHead", CFrame.new(40.6, y + 3.35, 37.9))       -- голова на подушке
	mark("BedSit", CFrame.new(41.2, y + 4.6, 36.2))         -- сидя в кровати
	mark("StandSpot", CFrame.lookAt(Vector3.new(45.4, y + 3, 33.4), Vector3.new(55, y + 3, 30.5))) -- корень персонажа после подъёма

	-- тумбочка с будильником и лампой
	local ns, Q = item("Nightstand", CFrame.new(45.3, y, 38.4))
	Q("Body", 2.6, 2.3, 2.4, 0, 1.15, 0, "#A66D42")
	Q("Top", 2.8, 0.15, 2.6, 0, 2.37, 0, "#8C5733")
	Q("Drawer", 2.2, 0.8, 0.08, 0, 1.55, -1.22, "#B57A4C")
	Q.ball("Knob", 0.22, 0, 1.55, -1.3, "#E2C27A")
	local lampBase = Q.vcyl("LampBase", 0.15, 0.8, 0.7, 2.52, 0.45, "#3A3A44")
	Q.vcyl("LampStem", 1.1, 0.18, 0.7, 3.1, 0.45, "#3A3A44")
	local shade = Q.vcyl("LampShade", 0.9, 1.15, 0.7, 4.0, 0.45, "#FFF2C8", nil, { CastShadow = false })
	B.attrs(shade, { Room = "MortyNight", Glow = false })
	B.light(shade, "PointLight", { Color = Color3.fromRGB(255, 190, 120), Brightness = 0.9, Range = 12, Enabled = false })
	shade.Parent = LIGHTS
	local _ = lampBase
	-- будильник (электронный, красные цифры)
	local clock = B.model(FURN, "AlarmClock")
	B.outline(clock)
	local ccf = CFrame.new(44.7, y + 2.45, 38.0) * CFrame.Angles(0, math.rad(40), 0)
	local K = B.kit(clock, ccf)
	local body = K("Body", 1.5, 0.7, 0.7, 0, 0.35, 0, "#2B2B33")
	K("Top", 1.5, 0.08, 0.72, 0, 0.72, 0, "#3A3A44")
	K("Button", 0.5, 0.1, 0.3, 0.3, 0.78, 0.1, "#C23B3B")
	local face = K("Display", 1.2, 0.46, 0.04, 0, 0.36, -0.36, "#130606")
	local g = B.surface(face, Enum.NormalId.Front, 120, { LightInfluence = 0, Brightness = 2.5 })
	B.text(g, 0.05, 0.05, 0.9, 0.9, "7:30", "#FF3B30", Enum.Font.Code, { Name = "Digits" })
	clock.PrimaryPart = body
	mark("AlarmClock", ccf * CFrame.new(0, 0.4, 0))

	-- письменный стол у восточной стены (к югу от окна), компьютер, лава-лампа
	local desk, D = item("Desk", CFrame.new(54.1, y, 23.0))
	D("Top", 3.0, 0.3, 5.0, 0, 2.55, 0, "#B37A48")
	D("Side", 3.0, 2.4, 0.25, 0, 1.2, -2.35, "#9A663B")
	D("Side", 3.0, 2.4, 0.25, 0, 1.2, 2.35, "#9A663B")
	D("Back", 0.2, 1.6, 4.5, 1.35, 1.6, 0, "#9A663B")
	D("Drawers", 2.6, 1.6, 1.4, 0.1, 1.5, 1.45, "#A86F41")
	D("DrawerFront", 0.06, 0.6, 1.2, -1.21, 1.9, 1.45, "#BC8656")
	D("DrawerFront", 0.06, 0.6, 1.2, -1.21, 1.15, 1.45, "#BC8656")
	-- монитор (выпуклый, «из девяностых»)
	local mon = D("Monitor", 1.8, 1.6, 2.0, 0.45, 3.55, 0.1, "#E6E1D3")
	D("MonitorBack", 1.0, 1.1, 1.4, 1.35, 3.5, 0.1, "#D8D2C2")
	D("MonitorFoot", 1.0, 0.15, 1.2, 0.5, 2.78, 0.1, "#D8D2C2")
	local screen = D("Screen", 0.05, 1.2, 1.6, -0.47, 3.6, 0.1, "#13324F")
	local sg = B.surface(screen, Enum.NormalId.Left, 80, { LightInfluence = 0.3, Brightness = 1.3 })
	B.rect(sg, 0, 0, 1, 1, "#1E5A8C")
	B.rect(sg, 0, 0.86, 1, 0.14, "#2A2A33")
	B.rect(sg, 0.08, 0.12, 0.18, 0.2, "#F2D85A")
	B.rect(sg, 0.08, 0.42, 0.18, 0.2, "#7CC46A")
	B.text(sg, 0.32, 0.3, 0.6, 0.2, "ИГРЫ", "#FFFFFF")
	D("Keyboard", 0.9, 0.12, 2.2, -0.8, 2.76, 0.1, "#E6E1D3")
	D("Mouse", 0.45, 0.14, 0.3, -0.85, 2.77, -1.4, "#E6E1D3")
	inspect(mon, "Computer")
	-- лава-лампа (светится ночью)
	D.vcyl("LavaBase", 0.6, 0.6, 0.3, 2.98, -1.85, "#4A3B66")
	local lava = D.vcyl("Lava", 1.1, 0.48, 0.3, 3.82, -1.85, "#7DFF6A", Enum.Material.Neon, { Transparency = 0.25, CastShadow = false })
	D.vcyl("LavaCap", 0.3, 0.42, 0.3, 4.5, -1.85, "#4A3B66")
	B.attrs(lava, { Room = "MortyNight", Glow = true })
	B.light(lava, "PointLight", { Color = Color3.fromRGB(140, 255, 120), Brightness = 0.7, Range = 9, Enabled = false, Shadows = false })
	local _2 = desk
	chair("DeskChair", CFrame.new(51.3, y, 23.3) * CFrame.Angles(0, math.rad(-90), 0), "#D04B3A")

	-- комод у южной стены
	local dr, R = item("Dresser", CFrame.new(46.5, y, 21.45))
	R("Body", 5.0, 3.3, 2.1, 0, 1.65, 0, "#7E4F2E")
	R("Top", 5.2, 0.15, 2.3, 0, 3.37, 0, "#6B4226")
	for i = 0, 2 do
		R("Drawer", 4.5, 0.85, 0.08, 0, 0.6 + i * 1.0, 1.07, "#93603A")
		R.ball("Knob", 0.22, -1.2, 0.6 + i * 1.0, 1.13, "#E2C27A")
		R.ball("Knob", 0.22, 1.2, 0.6 + i * 1.0, 1.13, "#E2C27A")
	end
	R.vcyl("TrophyBase", 0.25, 0.7, -1.6, 3.57, 0, "#3A3A44")
	R.vcyl("Trophy", 0.9, 0.45, -1.6, 4.1, 0, "#E2B33C", Enum.Material.Metal)
	R.ball("Ball", 0.8, 0.9, 3.85, -0.1, "#D23B3B")
	R("Frame", 1.0, 1.2, 0.12, 1.9, 4.05, -0.4, "#6B4A2E", nil, nil, CFrame.Angles(math.rad(-10), 0, 0))
	local _3 = dr

	-- шкаф у южной стены (слева)
	local wr, W = item("Wardrobe", CFrame.new(41.5, y, 21.45))
	W("Body", 4.0, 7.6, 2.1, 0, 3.8, 0, "#8C5A36")
	W("Door", 1.9, 7.0, 0.08, -0.98, 3.8, 1.06, "#9C6840")
	W("Door", 1.9, 7.0, 0.08, 0.98, 3.8, 1.06, "#9C6840")
	W("Handle", 0.12, 0.9, 0.15, -0.15, 3.9, 1.14, "#E2C27A")
	W("Handle", 0.12, 0.9, 0.15, 0.15, 3.9, 1.14, "#E2C27A")
	W("Crown", 4.3, 0.3, 2.3, 0, 7.75, 0, "#6B4226")
	local _4 = wr

	-- книжная полка у западной стены
	local sh, S = item("Bookshelf", CFrame.new(37.0, y, 31.25))
	S("Side", 1.3, 6.4, 0.2, 0, 3.2, -2.65, "#A66D42")
	S("Side", 1.3, 6.4, 0.2, 0, 3.2, 2.65, "#A66D42")
	S("Back", 0.1, 6.4, 5.3, -0.6, 3.2, 0, "#8C5733")
	local cols = { "#D64545", "#3B8F5A", "#E2B13C", "#4467C4", "#8E5BB5", "#E07B39", "#2F9EA8" }
	for i = 0, 3 do
		local sy = 0.15 + i * 1.6
		S("Shelf", 1.3, 0.15, 5.1, 0, sy, 0, "#B57A4C")
		if i < 3 then
			local zc = -2.3
			local k = i * 3
			while zc < 2.1 do
				k = k + 1
				local bh = 1.0 + ((k * 7) % 4) * 0.12
				local bw = 0.3 + ((k * 5) % 3) * 0.08
				S("Book", 0.9, bh, bw, 0.05, sy + 0.08 + bh / 2, zc + bw / 2, cols[(k % #cols) + 1])
				zc = zc + bw + 0.04
				if k % 5 == 0 then zc = zc + 0.5 end
			end
		end
	end
	S.ball("Globe", 1.0, 0, 6.6 + 0.45, -1.4, "#4A90D0")
	S.vcyl("Rocket", 1.2, 0.35, 0, 6.6 + 0.6, 1.4, "#E8E8E8")
	S("Fin", 0.06, 0.4, 0.6, 0, 6.6 + 0.2, 1.4, "#D23B3B")
	local _5 = sh

	-- ковёр
	local rug = B.model(FURN, "Rug")
	B.part(rug, "Rug", Vector3.new(9, 0.06, 7), CFrame.new(47.5, y + 0.03, 30.5), "#6A8F5A", Enum.Material.Fabric)
	B.part(rug, "RugInner", Vector3.new(7.8, 0.065, 5.8), CFrame.new(47.5, y + 0.035, 30.5), "#7FA56C", Enum.Material.Fabric)

	-- плакаты и календарь
	local p1 = picture("PosterSpace", CFrame.new(40.8, y + 7.3, 39.55), 3.0, 4.2, drawSpace)
	local p2 = picture("PosterDino", CFrame.new(36.45, y + 7.6, 36.2) * CFrame.Angles(0, math.rad(-90), 0), 2.8, 3.8, drawDino)
	local p3 = picture("PosterBand", CFrame.new(46.5, y + 6.9, 20.45) * CFrame.Angles(0, math.rad(180), 0), 3.0, 4.0, drawBand)
	picture("Calendar", CFrame.new(55.55, y + 6.2, 37.4) * CFrame.Angles(0, math.rad(90), 0), 2.0, 2.4, drawCalendar)
	inspect(p1.Canvas, "Poster")
	local _6, _7 = p2, p3

	-- одежда на полу, рюкзак, кроссовки, корзина
	local cl, L = item("Clothes", CFrame.new(44.6, y, 29.8))
	L("Shirt", 1.9, 0.12, 1.6, 0, 0.06, 0, "#F2D240", Enum.Material.Fabric, nil, CFrame.Angles(0, math.rad(30), 0))
	L("Sleeve", 0.7, 0.1, 0.6, -1.1, 0.05, -0.5, "#F2D240", Enum.Material.Fabric, nil, CFrame.Angles(0, math.rad(50), 0))
	L("Jeans", 2.4, 0.14, 0.9, 4.6, 0.07, -3.6, "#3159A8", Enum.Material.Fabric, nil, CFrame.Angles(0, math.rad(-20), 0))
	L("Sock", 0.7, 0.1, 0.3, 1.8, 0.05, 1.6, "#FFFFFF", Enum.Material.Fabric, nil, CFrame.Angles(0, math.rad(70), 0))
	local _8 = cl
	local sn, N = item("Sneakers", CFrame.new(38.6, y, 27.2))
	for _, dz in ipairs({ -0.45, 0.45 }) do
		N("Sole", 1.3, 0.18, 0.55, 0, 0.09, dz, "#FFFFFF")
		N("Upper", 1.0, 0.45, 0.5, 0.1, 0.38, dz, "#E8E8E8")
		N("Stripe", 0.5, 0.2, 0.52, 0.1, 0.35, dz, "#D23B3B")
	end
	local _9 = sn
	local bp, Bk = item("Backpack", CFrame.new(51.4, y, 26.8) * CFrame.Angles(0, math.rad(-70), 0))
	local bag = Bk("Bag", 1.8, 2.2, 1.0, 0, 1.1, 0, "#2F8F8A", Enum.Material.Fabric)
	Bk("Pocket", 1.4, 0.9, 0.3, 0, 0.75, -0.6, "#287A76", Enum.Material.Fabric)
	Bk("Strap", 0.25, 1.8, 0.15, -0.5, 1.2, 0.55, "#1F5F5C")
	Bk("Strap", 0.25, 1.8, 0.15, 0.5, 1.2, 0.55, "#1F5F5C")
	inspect(bag, "Backpack")
	local _10 = bp
	local tb, Tb = item("TrashBin", CFrame.new(54.9, y, 26.3))
	Tb.vcyl("Bin", 1.4, 1.2, 0, 0.7, 0, "#8D96A3")
	Tb.ball("Paper", 0.45, 0.1, 1.45, 0.1, "#F3F0E8")
	Tb.ball("Paper", 0.4, -0.3, 0.2, -0.9, "#F3F0E8")
	local _11 = tb

	-- шторы у восточного окна и жалюзи у северного
	local cur = B.model(FURN, "Curtains")
	B.part(cur, "Rod", Vector3.new(0.2, 0.2, 10.4), CFrame.new(55.3, y + 9.6, 30.5), "#5B4A3A")
	B.part(cur, "Curtain", Vector3.new(0.25, 7.6, 1.4), CFrame.new(55.25, y + 5.6, 25.5), "#3D5AA8", Enum.Material.Fabric)
	B.part(cur, "Curtain", Vector3.new(0.25, 7.6, 1.4), CFrame.new(55.25, y + 5.6, 35.5), "#3D5AA8", Enum.Material.Fabric)
	local bl = B.model(FURN, "Blinds")
	for i = 0, 5 do
		B.part(bl, "Slat", Vector3.new(4.4, 0.06, 0.4), CFrame.new(50, y + 8.3 - i * 0.22, 39.35) * CFrame.Angles(math.rad(55), 0, 0), "#F7F5EE", nil, { CanCollide = false })
	end
	inspect(B.marker(FURN, "WindowSpot", Vector3.new(0.5, 4, 6), CFrame.new(55.4, y + 5, 30.5), { CanQuery = true }), "Window", "Посмотреть", 6)

	ceilingLamp("Morty", 46, y + 11, 30)
	-- метки для меню и сюжета
	mark("MenuCam", CFrame.lookAt(Vector3.new(38.4, y + 6.2, 22.8), Vector3.new(45.0, y + 3.4, 33.8)))
	mark("PortalSpot", CFrame.lookAt(Vector3.new(51.2, y + 4.7, 30.2), Vector3.new(38.4, y + 5.6, 22.8)))
	mark("MortyRoomCenter", CFrame.new(46, y + 3, 30))
	mark("MenuHide", CFrame.new(31, y + 3, 37))  -- где стоит персонаж, пока открыто меню (вне кадра)
end

---------------------------------------------------------------------------
-- Коридор 2 этажа и ванная
---------------------------------------------------------------------------
local function hallAndBath()
	local y = Y2
	local rg = B.model(FURN, "Runner")
	B.part(rg, "Runner", Vector3.new(4, 0.05, 15), CFrame.new(31, y + 0.03, 30.5), "#A33B3B", Enum.Material.Fabric)
	B.part(rg, "RunnerInner", Vector3.new(3.2, 0.055, 14.2), CFrame.new(31, y + 0.035, 30.5), "#C8574A", Enum.Material.Fabric)
	local fam = picture("FamilyPhoto", CFrame.new(35.6, y + 6, 33) * CFrame.Angles(0, math.rad(90), 0), 4.4, 3.0, drawFamily)
	inspect(fam.Canvas, "PhotoFamily")
	picture("Landscape", CFrame.new(22.4, y + 6, 28.2) * CFrame.Angles(0, math.rad(-90), 0), 2.6, 2.0, drawLandscape)
	picture("Landscape2", CFrame.new(35.6, y + 6, 16.6) * CFrame.Angles(0, math.rad(90), 0), 2.2, 2.8, drawLandscape)
	plant("HallPlant", CFrame.new(34.6, y, 38.6), 0.9)
	local ct, T = item("Console", CFrame.new(24.2, y, 38.9))
	T("Top", 3.4, 0.2, 1.3, 0, 2.6, 0, "#8C5733")
	T("Leg", 0.2, 2.5, 0.2, -1.5, 1.25, -0.5, "#6B4226")
	T("Leg", 0.2, 2.5, 0.2, 1.5, 1.25, -0.5, "#6B4226")
	T("Leg", 0.2, 2.5, 0.2, -1.5, 1.25, 0.5, "#6B4226")
	T("Leg", 0.2, 2.5, 0.2, 1.5, 1.25, 0.5, "#6B4226")
	T.vcyl("Vase", 1.0, 0.6, -0.8, 3.2, 0, "#4A90D0")
	local _ = ct
	ceilingLamp("Hall", 31, y + 11, 30)
	ceilingLamp("Hall", 32.2, y + 11, 8)

	-- ванная (x 0..22, z 26..40)
	local tub, U = item("Tub", CFrame.new(5.5, y, 37.6))
	U("Outer", 9.0, 2.3, 4.0, 0, 1.15, 0, "#FFFFFF")
	U("Water", 8.0, 0.1, 3.0, 0, 1.9, 0, "#BFE6F5", nil, { Transparency = 0.2 })
	U("Rim", 9.0, 0.2, 4.0, 0, 2.35, 0, "#F3F3F3")
	U("Faucet", 0.4, 0.4, 0.8, -4.0, 3.0, 1.2, "#C9CFD6", Enum.Material.Metal)
	U("Rod", 9.0, 0.15, 0.15, 0, 8.4, -1.9, "#C9CFD6", Enum.Material.Metal)
	U("CurtainB", 3.0, 6.0, 0.1, -3.0, 5.3, -1.9, "#6FB7D8", Enum.Material.Fabric)
	local _1 = tub
	local wc, V = item("Toilet", CFrame.new(15, y, 38.3))
	V("Base", 1.5, 1.4, 2.0, 0, 0.7, -0.2, "#FFFFFF")
	V("Seat", 1.7, 0.2, 2.1, 0, 1.5, -0.3, "#F3F3F3")
	V("Tank", 2.0, 2.0, 0.9, 0, 2.2, 0.95, "#FFFFFF")
	inspect(wc.Tank, "Toilet")
	local sk, K = item("Sink", CFrame.new(9, y, 27.0))
	K("Cabinet", 4.0, 2.8, 1.6, 0, 1.4, 0.15, "#E8E2D6")
	K("Basin", 3.0, 0.2, 1.2, 0, 2.95, 0.2, "#FFFFFF")
	K("Tap", 0.25, 0.6, 0.25, 0, 3.3, -0.4, "#C9CFD6", Enum.Material.Metal)
	local mirror = K("Mirror", 3.4, 3.6, 0.12, 0, 5.8, -0.6, "#CFE3EE", Enum.Material.Glass, { Reflectance = 0.35 })
	K("MirrorFrame", 3.7, 3.9, 0.08, 0, 5.8, -0.68, "#E8E2D6")
	inspect(mirror, "Mirror")
	local _2 = sk
	local mat2 = B.model(FURN, "BathMat")
	B.part(mat2, "Mat", Vector3.new(4, 0.05, 2.2), CFrame.new(6, y + 0.03, 34.6), "#6FB7D8", Enum.Material.Fabric)
	ceilingLamp("Bath", 11, y + 11, 33)
end

---------------------------------------------------------------------------
-- Кухня (x 36..56, z 14..40, пол y = 0) и кладовая
---------------------------------------------------------------------------
local CAB = "#C98B55"
local COUNTER = "#ECE6D8"

-- нижний шкаф со столешницей: from..to вдоль стены
local function counterRun(name, axis, fixed, from, to, facing)
	-- axis "z": шкафы вдоль восточной стены (x = fixed — задняя грань), facing = −1 (смотрят на −X)
	local m = B.model(FURN, name)
	B.outline(m)
	local len = to - from
	local mid = (from + to) / 2
	local depth = 2.45
	local cf
	if axis == "z" then cf = CFrame.new(fixed - depth / 2, 0, mid) * CFrame.Angles(0, math.rad(90), 0)
	else cf = CFrame.new(mid, 0, fixed - depth / 2) end
	-- в локальных координатах: X — вдоль, Z — вглубь (+Z к стене), фасад на −Z
	local P = B.kit(m, cf)
	P("Base", len, 3.1, depth - 0.15, 0, 1.6, 0.05, CAB)
	P("Kick", len, 0.4, depth - 0.45, 0, 0.2, 0.2, "#7A5333")
	P("Countertop", len + 0.1, 0.25, depth + 0.1, 0, 3.27, -0.02, COUNTER)
	-- дверцы
	local n = math.max(1, math.floor(len / 2.2))
	local dw = len / n
	for i = 0, n - 1 do
		local x = -len / 2 + dw * (i + 0.5)
		P("Door", dw - 0.2, 2.3, 0.08, x, 1.75, -depth / 2 + 0.02, B.shade(CAB, 1.08))
		P("Pull", 0.6, 0.12, 0.14, x, 2.6, -depth / 2 - 0.05, "#3A3A44", Enum.Material.Metal)
	end
	return m, P
end

local function upperRun(name, axis, fixed, from, to)
	local m = B.model(FURN, name)
	B.outline(m)
	local len = to - from
	local mid = (from + to) / 2
	local depth = 1.3
	local cf
	if axis == "z" then cf = CFrame.new(fixed - depth / 2, 0, mid) * CFrame.Angles(0, math.rad(90), 0)
	else cf = CFrame.new(mid, 0, fixed - depth / 2) end
	local P = B.kit(m, cf)
	P("Body", len, 3.0, depth, 0, 8.0, 0, CAB)
	local n = math.max(1, math.floor(len / 2.2))
	local dw = len / n
	for i = 0, n - 1 do
		local x = -len / 2 + dw * (i + 0.5)
		P("Door", dw - 0.2, 2.6, 0.08, x, 8.0, -depth / 2 - 0.02, B.shade(CAB, 1.08))
		P("Pull", 0.12, 0.6, 0.14, x + dw / 2 - 0.4, 7.2, -depth / 2 - 0.08, "#3A3A44", Enum.Material.Metal)
	end
	return m
end

local function kitchen()
	local y = Y1
	local east = 56 - 0.35
	local north = 40 - 0.35
	-- нижние шкафы вдоль восточной стены (с мойкой у окна и плитой)
	local _, E = counterRun("CountersEast", "z", east, 18.6, north - 2.45)
	local _1, Nn = counterRun("CountersNorth", "x", north, 36.4, 47.4)
	local _2 = Nn
	-- угловой кусок у северной стены (восточная часть)
	counterRun("CounterCorner", "x", north, 53.2, east)
	-- мойка (на восточной стене под окном, z = 30)
	local sink = B.model(FURN, "Sink")
	B.outline(sink)
	local S = B.kit(sink, CFrame.new(east - 1.25, y, 30) * CFrame.Angles(0, math.rad(90), 0))
	S("Basin", 3.2, 0.1, 1.6, 0, 3.32, 0, "#9AA3AE", Enum.Material.Metal)
	S("BasinRim", 3.4, 0.08, 1.8, 0, 3.4, 0, "#C9CFD6", Enum.Material.Metal)
	S("Faucet", 0.25, 1.2, 0.25, 0, 3.95, 0.8, "#C9CFD6", Enum.Material.Metal)
	S("Spout", 0.2, 0.2, 0.9, 0, 4.5, 0.4, "#C9CFD6", Enum.Material.Metal)
	S("DishRack", 1.6, 0.6, 1.2, 2.4, 3.7, 0.2, "#D6DCE3", Enum.Material.Metal)
	S.ball("Plate", 1.0, 2.4, 4.0, 0.2, "#FFFFFF", nil, nil)
	-- плита с духовкой (z 20..23)
	local st = B.model(FURN, "Stove")
	B.outline(st)
	local T = B.kit(st, CFrame.new(east - 1.25, y, 21.5) * CFrame.Angles(0, math.rad(90), 0))
	T("Body", 3.0, 3.3, 2.5, 0, 1.65, 0.05, "#EDEDED")
	T("Top", 3.0, 0.15, 2.5, 0, 3.37, 0.05, "#2B2B33")
	for _, p in ipairs({ { -0.7, -0.5 }, { 0.7, -0.5 }, { -0.7, 0.6 }, { 0.7, 0.6 } }) do
		T.vcyl("Burner", 0.06, 0.9, p[1], 3.47, p[2], "#111114")
	end
	T("OvenDoor", 2.6, 1.9, 0.08, 0, 1.45, -1.23, "#3A3A44", Enum.Material.Glass, { Transparency = 0.2 })
	T("OvenHandle", 2.0, 0.15, 0.2, 0, 2.55, -1.32, "#C9CFD6", Enum.Material.Metal)
	for i = -1, 2 do T.cyl("Knob", 0.15, 0.3, i * 0.6 - 0.3, 3.0, -1.3, "#2B2B33", nil, nil, CFrame.Angles(0, math.rad(90), 0)) end
	T("Hood", 3.2, 1.2, 1.6, 0, 8.6, 0.5, "#D6DCE3", Enum.Material.Metal)
	T("HoodPipe", 1.0, 1.6, 0.8, 0, 10.0, 0.8, "#D6DCE3", Enum.Material.Metal)
	-- верхние шкафы
	upperRun("UppersEastA", "z", east, 23.4, 26.2)
	upperRun("UppersEastB", "z", east, 34.0, north - 1.3)
	upperRun("UppersNorthA", "x", north, 36.4, 39.6)
	upperRun("UppersNorthB", "x", north, 44.4, 47.4)
	-- холодильник в юго-восточном углу
	local fr, F = item("Fridge", CFrame.new(54.15, y, 16.35) * CFrame.Angles(0, math.rad(90), 0))
	F("Body", 3.6, 8.4, 2.9, 0, 4.2, 0, "#F2F0EA")
	F("Split", 3.62, 0.08, 2.92, 0, 6.0, 0, "#C9C4B8")
	F("Handle", 0.15, 1.4, 0.2, -1.4, 7.0, -1.55, "#C9CFD6", Enum.Material.Metal)
	F("Handle", 0.15, 2.4, 0.2, -1.4, 4.4, -1.55, "#C9CFD6", Enum.Material.Metal)
	-- записка и магниты
	local note = F("Note", 1.1, 1.3, 0.04, 0.4, 5.2, -1.48, "#FFF7C2")
	local ng = B.surface(note, Enum.NormalId.Front, 60)
	B.text(ng, 0.08, 0.06, 0.84, 0.18, "Морти!", "#3355AA", Enum.Font.AmaticSC)
	for i = 0, 3 do B.rect(ng, 0.1, 0.32 + i * 0.15, 0.8 - (i % 2) * 0.2, 0.03, "#6A7DB8") end
	F.ball("Magnet", 0.3, 0.4, 5.85, -1.52, "#D23B3B")
	F.ball("Magnet", 0.25, -0.6, 7.0, -1.52, "#3B8F5A")
	F("Drawing", 1.0, 1.0, 0.04, -0.7, 4.4, -1.48, "#FFFFFF")
	local np = inspect(note, "Note", "Прочитать", 6)
	np:SetAttribute("NoteText", true)
	local _3 = fr
	mark("FridgeNote", note.CFrame)
	-- мелочи на столешницах
	local mw = B.model(FURN, "Microwave")
	B.outline(mw)
	local Mw = B.kit(mw, CFrame.new(38.6, y + 3.4, north - 1.3))
	Mw("Body", 2.6, 1.5, 1.7, 0, 0.75, 0, "#EDEDED")
	Mw("Window", 1.6, 1.0, 0.05, -0.3, 0.8, -0.86, "#2B2B33", Enum.Material.Glass, { Transparency = 0.2 })
	Mw("Panel", 0.6, 1.2, 0.05, 0.9, 0.8, -0.86, "#C9C4B8")
	local tst = B.model(FURN, "Toaster")
	B.outline(tst)
	local Ts = B.kit(tst, CFrame.new(east - 1.3, y + 3.4, 36.2) * CFrame.Angles(0, math.rad(90), 0))
	Ts("Body", 1.6, 1.0, 1.0, 0, 0.5, 0, "#C9CFD6", Enum.Material.Metal)
	Ts("Slot", 1.0, 0.05, 0.15, 0, 1.0, -0.2, "#2B2B33")
	Ts("Slot", 1.0, 0.05, 0.15, 0, 1.0, 0.2, "#2B2B33")
	local cm = B.model(FURN, "CoffeeMaker")
	B.outline(cm)
	local Cm = B.kit(cm, CFrame.new(45.6, y + 3.4, north - 1.2))
	Cm("Body", 1.2, 1.8, 1.2, 0, 0.9, 0.1, "#2B2B33")
	Cm.vcyl("Pot", 0.8, 0.8, 0, 0.45, -0.3, "#9C6B3D", Enum.Material.Glass, { Transparency = 0.3 })
	plant("SillPlant", CFrame.new(42, y + 4.6, 39.25), 0.45)
	local _4 = E

	-- обеденный стол и 4 стула
	local tbl, Tb = item("KitchenTable", CFrame.new(44, y, 27))
	Tb("Top", 7.0, 0.3, 5.0, 0, 3.05, 0, "#B98552")
	Tb("Apron", 6.4, 0.5, 4.4, 0, 2.65, 0, "#9C6B3D")
	for _, p in ipairs({ { -3.0, -2.0 }, { 3.0, -2.0 }, { -3.0, 2.0 }, { 3.0, 2.0 } }) do
		Tb("Leg", 0.4, 2.9, 0.4, p[1], 1.45, p[2], "#9C6B3D")
	end
	local _5 = tbl
	-- миска с фруктами
	local fb, Fb = item("FruitBowl", CFrame.new(45.6, y + 3.2, 26.2))
	Fb.vcyl("Bowl", 0.5, 1.6, 0, 0.25, 0, "#E8E2D6")
	Fb.ball("Apple", 0.6, -0.3, 0.6, 0.1, "#D23B3B")
	Fb.ball("Apple", 0.6, 0.3, 0.6, -0.15, "#7CC46A")
	Fb.ball("Orange", 0.65, 0.05, 0.85, 0.25, "#F09A2A")
	Fb("Banana", 1.2, 0.3, 0.35, 0, 0.75, -0.4, "#F2D85A", nil, nil, CFrame.Angles(0, 0, math.rad(15)))
	local _6 = fb
	-- стулья: место Морти — с запада, лицом на восток (к окну)
	chair("ChairMorty", CFrame.new(39.6, y, 27) * CFrame.Angles(0, math.rad(-90), 0), "#B3784A")
	chair("ChairE", CFrame.new(48.4, y, 27) * CFrame.Angles(0, math.rad(90), 0), "#B3784A")
	chair("ChairN", CFrame.new(44, y, 30.9), "#B3784A")
	chair("ChairS", CFrame.new(44, y, 23.1) * CFrame.Angles(0, math.rad(180), 0), "#B3784A")
	-- метки: где сидит Морти, куда смотрит камера, где ставить завтрак
	mark("SeatMorty", CFrame.lookAt(Vector3.new(39.75, y + 3.5, 27), Vector3.new(48, y + 3.5, 27)))
	mark("SeatCam", CFrame.lookAt(Vector3.new(39.6, y + 5.4, 27), Vector3.new(43.6, y + 3.0, 27)))
	mark("BowlSpot", CFrame.new(41.9, y + 3.2, 27))
	mark("BoxSpot", CFrame.new(43.5, y + 3.2, 29.2))
	mark("MilkSpot", CFrame.new(43.4, y + 3.2, 24.9))
	mark("KitchenGoal", CFrame.new(40.6, y + 3, 27))
	-- лампа над столом (подвесная)
	local pend = B.model(FURN, "Pendant")
	B.part(pend, "Cord", Vector3.new(0.1, 3.2, 0.1), CFrame.new(44, y + 9.4, 27), "#2B2B33")
	local shade = B.vcyl(LIGHTS, "Pendant", 1.0, 2.4, CFrame.new(44, y + 7.4, 27), "#E8C25A", nil, { CastShadow = false })
	B.attrs(shade, { Room = "Kitchen", Glow = false })
	B.light(shade, "SpotLight", { Color = Color3.fromRGB(255, 220, 170), Brightness = 2, Range = 16, Angle = 110, Face = Enum.NormalId.Bottom, Enabled = false })
	ceilingLamp("Kitchen", 50, y + 11, 22)

	-- кладовая: стиралка, сушилка, полки, свечение из-под двери в гараж
	local wm, Wm = item("Washer", CFrame.new(50.5, y, 1.8))
	Wm("Body", 2.8, 3.2, 2.7, 0, 1.6, 0, "#F2F0EA")
	Wm.cyl("Door", 0.1, 1.9, 0, 1.6, -1.36, "#7DA6C2", Enum.Material.Glass, { Transparency = 0.2 }, CFrame.Angles(0, math.rad(90), 0))
	Wm("Body2", 2.8, 3.2, 2.7, 3.0, 1.6, 0, "#F2F0EA")
	Wm.cyl("Door2", 0.1, 1.9, 3.0, 1.6, -1.36, "#3A3A44", Enum.Material.Glass, { Transparency = 0.2 }, CFrame.Angles(0, math.rad(90), 0))
	local _7 = wm
	local shelfM, Sh = item("Shelves", CFrame.new(38.0, y, 1.2))
	for i = 0, 3 do Sh("Shelf", 3.0, 0.15, 1.6, 0, 1 + i * 2, 0, "#B57A4C") end
	Sh("Side", 0.15, 7.2, 1.6, -1.5, 3.6, 0, "#9A663B")
	Sh("Side", 0.15, 7.2, 1.6, 1.5, 3.6, 0, "#9A663B")
	Sh("Box", 1.2, 0.9, 1.1, -0.6, 1.55, 0, "#C9A46B")
	Sh("Box", 1.0, 0.8, 1.0, 0.7, 3.5, 0, "#C9A46B")
	Sh("Paint", 0.7, 0.9, 0.7, -0.6, 5.5, 0, "#4A90D0")
	local _8 = shelfM
	local glow = B.part(FURN, "GarageGlow", Vector3.new(0.3, 0.12, 4.2), CFrame.new(55.55, y + 0.06, 7), "#7CFF4A", Enum.Material.Neon, { CastShadow = false, CanCollide = false })
	B.light(glow, "PointLight", { Color = Color3.fromRGB(120, 255, 80), Brightness = 1.6, Range = 7, Shadows = false })
	mark("GarageHum", CFrame.new(55, y + 3, 7))
	ceilingLamp("Mudroom", 46, y + 11, 7, 2.0)
end

---------------------------------------------------------------------------
-- Гостиная, прихожая, столовая (пол y = 0)
---------------------------------------------------------------------------
local function living()
	local y = Y1
	-- ТВ у западной стены
	local tv, V = item("TV", CFrame.new(1.4, y, 20) * CFrame.Angles(0, math.rad(-90), 0))
	V("Stand", 6.0, 2.0, 2.0, 0, 1.0, 0, "#6B4226")
	V("Body", 6.2, 3.6, 0.45, 0, 4.0, 0.3, "#1B1B22")
	local scr = V("Screen", 5.8, 3.2, 0.05, 0, 4.0, 0.05, "#0E1A24", nil, { Reflectance = 0.1 })
	inspect(scr, "Tv")
	local _ = tv
	-- диван спиной к прихожей, смотрит на ТВ (на запад)
	local couch, Co = item("Couch", CFrame.new(12.5, y, 20) * CFrame.Angles(0, math.rad(90), 0))
	local cc = "#B5654F"
	Co("Base", 9.4, 1.6, 3.6, 0, 0.9, 0, B.shade(cc, 0.9))
	Co("Back", 9.4, 2.6, 1.0, 0, 2.6, 1.3, cc)
	Co("ArmL", 0.9, 2.4, 3.6, -4.7, 1.6, 0, cc)
	Co("ArmR", 0.9, 2.4, 3.6, 4.7, 1.6, 0, cc)
	for i = -1, 1 do
		Co("Cushion", 2.85, 0.7, 2.6, i * 2.95, 2.0, -0.35, B.shade(cc, 1.08), Enum.Material.Fabric)
	end
	Co("Pillow", 1.4, 1.4, 0.5, -3.6, 2.9, 0.6, "#F2D85A", Enum.Material.Fabric, nil, CFrame.Angles(math.rad(-15), 0, math.rad(10)))
	local _1 = couch
	-- журнальный столик и ковёр
	local ctb, Ct = item("CoffeeTable", CFrame.new(7.2, y, 20))
	Ct("Top", 2.8, 0.25, 5.0, 0, 1.6, 0, "#8C5733")
	Ct("Shelf", 2.4, 0.15, 4.6, 0, 0.5, 0, "#8C5733")
	for _, p in ipairs({ { -1.2, -2.2 }, { 1.2, -2.2 }, { -1.2, 2.2 }, { 1.2, 2.2 } }) do Ct("Leg", 0.25, 1.5, 0.25, p[1], 0.75, p[2], "#6B4226") end
	Ct("Remote", 0.3, 0.1, 0.9, 0.4, 1.78, 0.6, "#2B2B33")
	Ct("Magazine", 1.2, 0.06, 1.6, -0.4, 1.76, -1.2, "#4A90D0", nil, nil, CFrame.Angles(0, math.rad(20), 0))
	local _2 = ctb
	local rug = B.model(FURN, "LivingRug")
	B.part(rug, "Rug", Vector3.new(9, 0.06, 11), CFrame.new(7.5, y + 0.03, 20), "#5C7FA6", Enum.Material.Fabric)
	B.part(rug, "RugInner", Vector3.new(7.6, 0.065, 9.6), CFrame.new(7.5, y + 0.035, 20), "#7096BC", Enum.Material.Fabric)
	-- кресло деда и торшер
	local ac, A = item("Armchair", CFrame.new(6, y, 6.5) * CFrame.Angles(0, math.rad(35), 0))
	A("Base", 3.6, 1.6, 3.4, 0, 0.9, 0, "#6E7F5C")
	A("Back", 3.6, 3.0, 0.9, 0, 2.6, 1.25, "#7C8F68")
	A("ArmL", 0.8, 2.2, 3.4, -1.8, 1.5, 0, "#7C8F68")
	A("ArmR", 0.8, 2.2, 3.4, 1.8, 1.5, 0, "#7C8F68")
	A("Cushion", 2.0, 0.6, 2.4, 0, 1.9, -0.3, "#8A9E74", Enum.Material.Fabric)
	local _3 = ac
	local fl, Fl = item("FloorLamp", CFrame.new(12.5, y, 13.2))
	Fl.vcyl("Base", 0.2, 1.4, 0, 0.1, 0, "#3A3A44")
	Fl.vcyl("Pole", 6.4, 0.2, 0, 3.3, 0, "#3A3A44")
	local fls = Fl.vcyl("Shade", 1.4, 1.8, 0, 7.0, 0, "#FFF2C8", nil, { CastShadow = false })
	B.attrs(fls, { Room = "Living", Glow = false })
	B.light(fls, "PointLight", { Color = Color3.fromRGB(255, 205, 140), Brightness = 0.8, Range = 14, Enabled = false })
	local _4 = fl
	-- книжный шкаф у северной стены
	local bs, Bs = item("LivingShelf", CFrame.new(7, y, 39.0))
	Bs("Body", 7.0, 7.0, 1.3, 0, 3.5, 0, "#8C5733")
	local cols = { "#D64545", "#3B8F5A", "#E2B13C", "#4467C4", "#8E5BB5" }
	for i = 0, 2 do
		local sy = 1.0 + i * 2.1
		for k = 0, 10 do
			Bs("Book", 0.45, 1.3, 0.9, -3 + k * 0.55, sy + 0.65, -0.2, cols[(k + i) % #cols + 1])
		end
	end
	local _5 = bs
	plant("LivingPlant", CFrame.new(20.5, y, 1.6), 1.1)
	plant("LivingPlant2", CFrame.new(1.6, y, 38.4), 1.0)
	picture("Painting", CFrame.new(11, y + 6.2, 0.45) * CFrame.Angles(0, math.rad(180), 0), 3.6, 2.6, drawLandscape)
	ceilingLamp("Living", 11, y + 11, 20)

	-- прихожая: вешалка, обувница, зеркало, часы
	local cr, Cr = item("CoatRack", CFrame.new(35, y, 2.2))
	Cr.vcyl("Pole", 6.5, 0.3, 0, 3.25, 0, "#6B4226")
	Cr.vcyl("Base", 0.3, 1.6, 0, 0.15, 0, "#6B4226")
	Cr("Coat", 1.3, 2.6, 0.8, 0.4, 4.6, 0, "#3B6FB0", Enum.Material.Fabric)
	Cr("Coat", 1.2, 2.4, 0.8, -0.3, 4.7, 0.4, "#B03B5A", Enum.Material.Fabric)
	local _6 = cr
	local sb, Sb = item("ShoeBench", CFrame.new(34.9, y, 15) * CFrame.Angles(0, math.rad(-90), 0))
	Sb("Bench", 5.0, 1.8, 1.8, 0, 0.9, 0, "#9C6B3D")
	Sb("Shoe", 0.9, 0.4, 0.4, -1.5, 2.0, 0, "#3A3A44")
	Sb("Shoe", 0.9, 0.4, 0.4, -0.4, 2.0, 0.2, "#E8E8E8")
	local _7 = sb
	local fmat = B.model(FURN, "DoorMat")
	B.part(fmat, "Mat", Vector3.new(4, 0.06, 2.6), CFrame.new(32, y + 0.03, 2), "#7A3E2E", Enum.Material.Fabric)
	local clock = B.model(FURN, "WallClock")
	B.outline(clock)
	local wc = B.cyl(clock, "Face", 0.2, 2.0, CFrame.new(35.55, y + 8.3, 16), "#FFFFFF")
	B.cyl(clock, "Rim", 0.15, 2.3, CFrame.new(35.6, y + 8.3, 16), "#2B2B33")
	B.part(clock, "Hand", Vector3.new(0.05, 0.75, 0.08), CFrame.new(35.43, y + 8.6, 16), "#111111")
	B.part(clock, "Hand", Vector3.new(0.05, 0.08, 0.6), CFrame.new(35.43, y + 8.3, 16.25) * CFrame.Angles(math.rad(-30), 0, 0), "#111111")
	local _8 = wc
	-- столовая: сервант и растение
	local cb, Cb = item("ChinaCabinet", CFrame.new(24.6, y, 38.7))
	Cb("Body", 4.2, 3.2, 1.8, 0, 1.6, 0, "#7E4F2E")
	Cb("Glass", 4.0, 3.6, 1.4, 0, 5.0, 0.1, "#BFE6FF", Enum.Material.Glass, { Transparency = 0.6 })
	Cb("Crown", 4.4, 0.3, 1.9, 0, 6.95, 0, "#6B4226")
	for i = 0, 2 do Cb.ball("Plate", 0.9, -1.3 + i * 1.3, 4.2, 0.4, "#F3F3F3") end
	local _9 = cb
	plant("DiningPlant", CFrame.new(34.8, y, 38.6), 1.2)
	picture("Painting2", CFrame.new(31, y + 6.5, 39.55), 3.0, 2.2, drawLandscape)
	ceilingLamp("Foyer", 32, y + 11, 8, 2.2)
	ceilingLamp("Dining", 29, y + 11, 30)
end

function Rooms.build(ctx, root)
	B, C = ctx.Build, ctx.Config
	FURN = B.folder(root, "Furniture")
	LIGHTS = B.folder(root, "Lights")
	MARK = B.folder(root, "Markers")
	mortyRoom()
	hallAndBath()
	kitchen()
	living()
end

return Rooms
