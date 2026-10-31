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
