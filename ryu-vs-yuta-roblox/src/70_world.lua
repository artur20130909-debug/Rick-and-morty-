----------------------------------------------------------------------
-- МИР: ночной город (часть 1), поле с кратером (часть 2), «диорама» глаз
----------------------------------------------------------------------

-- Всё стоит далеко от (0, 0, 0): не мешает Baseplate и точке появления
local FIELD = V3(3000, 0, 9000) -- поле боя
local CLASH_POINT = FIELD + V3(0, 16, 0)
local CITY_CAM = FIELD + V3(-62, 50, -122) -- камера общего плана
local CRATER = FIELD + V3(24, 0, -14)
local GROUND = RGB(66, 112, 222)
local STAGE = {
	eyes = V3(0, 2600, -6000),
	yuta1 = V3(4000, 400, 0),
	ryu1 = V3(-4000, 400, 0),
	vortex = V3(-6000, 400, 0),
	laugh = V3(-3000, 400, 5000),
	yuta2 = V3(5000, 400, 5000),
	zoom = V3(6000, 400, -3000),
}

-- Поле боя по кадрам аниме: ярко-синий асфальт в трещинах, оранжевая разметка,
-- тёмный кратер, персиковая пыль, белые клубы дыма и светлый город вдали
local function buildBattlefield(parent)
	local f = Instance.new("Folder")
	f.Name = "Battlefield"
	f.Parent = parent
	local r = Random.new(11)
	local function n(a, b)
		return r:NextNumber(a, b)
	end
	local function at(x, y, z)
		return FIELD + V3(x, y, z)
	end
	newPart(f, V3(3000, 2, 3000), GROUND, CF(at(0, -1, 0)))
	-- пятна тона на асфальте
	for _ = 1, 45 do
		local c = GROUND:Lerp(pick({ RGB(40, 80, 190), RGB(95, 140, 235), RGB(55, 95, 205) }), n(0.3, 0.7))
		newPart(f, V3(n(20, 60), 0.04, n(15, 45)), c, CF(at(n(-220, 220), 0.02, n(-220, 220))) * ANG(0, n(0, 6.28), 0))
	end
	-- трещины: сеть по всему полю и лучи от кратера
	local crack = RGB(22, 34, 92)
	local cracks = Instance.new("Model")
	cracks.Name = "Cracks"
	cracks.Parent = f
	local function crackLine(p, a, steps, wmax)
		for _ = 1, steps do
			a = a + n(-0.7, 0.7)
			local L = n(3, 10)
			local q = p + V3(cos(a) * L, 0, sin(a) * L)
			newPart(cracks, V3(n(0.18, wmax), 0.06, (q - p).Magnitude + 0.2), crack, CFrame.lookAt((p + q) / 2, q))
			if r:NextNumber() < 0.25 then
				local a2 = a + n(-1.4, 1.4)
				local L2 = n(2, 5)
				local q2 = q + V3(cos(a2) * L2, 0, sin(a2) * L2)
				newPart(cracks, V3(n(0.12, 0.3), 0.06, (q2 - q).Magnitude + 0.1), crack, CFrame.lookAt((q + q2) / 2, q2))
			end
			p = q
		end
	end
	for _ = 1, 110 do
		crackLine(at(n(-200, 200), 0.05, n(-200, 200)), n(0, 6.28), r:NextInteger(3, 7), 0.5)
	end
	for i = 1, 34 do
		local a = i / 34 * math.pi * 2
		crackLine(CRATER + V3(cos(a) * 19, 0.05, sin(a) * 13), a, r:NextInteger(5, 9), 0.7)
	end
	-- оранжевая разметка: двойные линии сеткой, местами стёрта
	local paint = RGB(238, 156, 86)
	local function lane(p0, dir, len)
		local side = dir:Cross(V3(0, 1, 0)).Unit
		local t = 0
		while t < len do
			local seg = n(12, 30)
			if r:NextNumber() > 0.2 then
				for _, o in ipairs({ -0.7, 0.7 }) do
					local a0 = p0 + dir * t + side * o
					local a1 = p0 + dir * math.min(len, t + seg) + side * o
					local mid = (a0 + a1) / 2
					if (V3(mid.X, 0, mid.Z) - V3(CRATER.X, 0, CRATER.Z)).Magnitude > 22 then
						newPart(f, V3(0.45, 0.07, (a1 - a0).Magnitude), paint, CFrame.lookAt(mid, a1))
					end
				end
			end
			t = t + seg + n(1, 6)
		end
	end
	for _, z in ipairs({ -70, -30, 30, 70 }) do
		lane(at(-220, 0.06, z), V3(1, 0, 0), 440)
	end
	for _, x in ipairs({ -80, -40, 40, 80 }) do
		lane(at(x, 0.06, -220), V3(0, 0, 1), 440)
	end
	-- кратер: тёмная яма с рваным краем из плит
	newPart(f, V3(0.2, 40, 27), RGB(26, 32, 70), CF(CRATER + V3(0, 0.04, 0)) * ANG(0, 0, rad(90)), { shape = "cyl" })
	newPart(f, V3(0.2, 28, 18), RGB(12, 14, 34), CF(CRATER + V3(0, 0.07, 0)) * ANG(0, 0, rad(90)), { shape = "cyl" })
	local slabs = Instance.new("Model")
	slabs.Name = "Slabs"
	slabs.Parent = f
	outline(slabs, nil, 1, RGB(16, 22, 60))
	for i = 1, 30 do
		local a = i / 30 * math.pi * 2 + n(-0.08, 0.08)
		local pos = CRATER + V3(cos(a) * 20, 0, sin(a) * 13.5)
		local s = V3(n(4, 8), n(0.8, 1.6), n(2.5, 5))
		newPart(slabs, s, GROUND:Lerp(RGB(30, 50, 140), n(0.2, 0.6)), CF(pos + V3(0, 0.4, 0)) * ANG(0, -a, 0) * ANG(rad(n(-25, -8)), 0, rad(n(-10, 10))), { wedge = (i % 4 == 0) })
	end
	for _ = 1, 26 do
		local pos = CRATER + V3(n(-14, 14), 0.3, n(-9, 9))
		newPart(slabs, V3(n(1, 3.5), n(0.6, 2), n(1, 3.5)), RGB(30, 36, 70), CF(pos) * ANG(n(-1, 1), n(0, 6), n(-1, 1)))
	end
	-- вздыбленные плиты по полю
	for _ = 1, 26 do
		local pos = at(n(-180, 180), 0, n(-180, 180))
		if (pos - CRATER).Magnitude > 30 and (pos - FIELD).Magnitude > 18 then
			local s = V3(n(8, 22), n(1, 2), n(6, 14))
			newPart(slabs, s, GROUND:Lerp(RGB(110, 150, 240), n(0, 0.4)), CF(pos + V3(0, s.Y * 0.3, 0)) * ANG(rad(n(-14, 14)), n(0, 6.28), rad(n(-14, 14))))
		end
	end
	-- персиковая пыль вдали
	for i = 1, 40 do
		local a = i / 40 * math.pi * 2
		local rad0 = n(235, 270)
		newPart(f, V3(n(45, 70), 0.08, n(18, 34)), RGB(244, 208, 170):Lerp(RGB(230, 186, 150), n(0, 1)), CF(at(cos(a) * rad0, 0.03, sin(a) * rad0)) * ANG(0, -a, 0))
	end
	-- светлый город вдали
	for i = 1, 70 do
		local a = i / 70 * math.pi * 2 + n(-0.03, 0.03)
		local d = n(330, 560)
		local w, dd, h = n(26, 60), n(24, 50), n(30, 130)
		local pos = at(cos(a) * d, h / 2, sin(a) * d)
		local col = RGB(r:NextInteger(150, 186), r:NextInteger(166, 196), r:NextInteger(196, 222))
		local cf = CFrame.lookAt(pos, V3(FIELD.X, pos.Y, FIELD.Z))
		newPart(f, V3(w, h, dd), col, cf, { material = Enum.Material.Concrete })
		local win = col:Lerp(RGB(90, 110, 160), 0.45)
		for row = 1, floor(h / 9) do
			newPart(f, V3(w * 0.86, 1.4, 0.2), win, cf * CF(0, -h / 2 + row * 9 - 2, -dd / 2 - 0.1))
		end
	end
	-- тёмный завал справа (как на кадре с разломом)
	for _ = 1, 26 do
		local pos = at(n(200, 300), 0, n(60, 220))
		local s = V3(n(20, 50), n(14, 50), n(20, 50))
		newPart(f, s, RGB(26, 34, 70), CF(pos + V3(0, s.Y * 0.35, 0)) * ANG(n(-0.5, 0.5), n(0, 6), n(-0.5, 0.5)), { wedge = true })
	end
	-- белый дым на заднем плане: мягкие текстурные клубы (без шаров и кругов),
	-- светлые сверху и сиреневые снизу, медленно вращаются
	local anchor = newPart(f, V3(0.2, 0.2, 0.2), C.white, CF(), { alpha = 1 })
	anchor.Name = "SmokeAnchor"
	for i = 1, 30 do
		local a = i / 30 * math.pi * 2 + n(-0.1, 0.1)
		local d = n(170, 290)
		local base = at(cos(a) * d, n(8, 22), sin(a) * d)
		for j = 1, 7 do
			local shade = j > 5
			local s = shade and n(34, 52) or n(30, 58)
			local p0 = base + V3(n(-26, 26), shade and n(-8, 0) or n(-2, 14), n(-26, 26))
			newSprite(sprites.static, anchor, TEX.smoke, p0, s, shade and RGB(200, 206, 238) or RGB(246, 248, 255),
				shade and 0.5 or n(0.55, 0.8), { spin = n(-0.03, 0.03) })
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
	-- детали с метками запоминаем, чтобы двигать их в кадре (напряжение перед выстрелом)
	local function tagMaker(store)
		return function(size, color, cf, o)
			local p = newPart(f, size, color, cf, o)
			if o and o.tag then
				store[o.tag] = store[o.tag] or {}
				table.insert(store[o.tag], { p = p, cf = cf, size = size, alpha = o.alpha or 0 })
			end
			return p
		end
	end
	local tagsY, tagsR = {}, {}
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
	local cvY = Canvas.new(tagMaker(tagsY), CF(topC + V3(-8, -1.8, 0)), k, EYES.d)
	local skinY = C.skinYuta
	cvY:rect(0, 0.06, 1.25, 0.62, skinY, 0)
	cvY:poly({ { 0.36, 0.33 }, { 0.625, 0.33 }, { 0.625, -0.27 }, { 0.5, -0.27 }, { 0.47, -0.05 }, { 0.42, 0.12 } }, skinY:Lerp(RGB(150, 110, 150), 0.32), 0.5)
	cvY:rect(-0.6, 0.06, 0.05, 0.62, skinY:Lerp(RGB(150, 110, 150), 0.25), 0.5)
	Face.yuta(cvY, skinY, { look = -0.03, angry = 0.55, mouth = "neutral", bangs = true, stress = true })
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
	local cvR = Canvas.new(tagMaker(tagsR), CF(botC + V3(8, -0.6, 0)), k, EYES.d)
	local skinR = C.skinRyu
	cvR:rect(0, -0.07, 1.25, 0.66, skinR, 0)
	cvR:poly({ { -0.625, 0.28 }, { -0.42, 0.28 }, { -0.47, 0.1 }, { -0.5, -0.1 }, { -0.44, -0.3 }, { -0.625, -0.3 } }, skinR:Lerp(RGB(140, 90, 120), 0.3), 0.5)
	Face.ryu(cvR, skinR, { look = 0.035, closeup = true, stress = true })
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

	-- Напряжение t (0..1): веки опускаются, брови сходятся, зрачки сужаются,
	-- блики гаснут, радужки дрожат, проступают штрихи напряжения и вена.
	local faces = {
		{ tags = tagsY, frame = cvY.frame, brow = { -0.47, 0.232 }, drop = 0.032, browA = 9 },
		{ tags = tagsR, frame = cvR.frame, brow = { -0.48, 0.165 }, drop = 0.026, browA = 7 },
	}
	local function move(list, fn)
		if not list then
			return
		end
		for _, e in ipairs(list) do
			e.p.CFrame = fn(e.cf)
		end
	end
	function EYES.tension(t, time)
		for fi, fc in ipairs(faces) do
			for _, S in ipairs({ "L", "R" }) do
				local sgn = (S == "L") and 1 or -1
				local down = CF(0, -fc.drop * t * k, 0)
				move(fc.tags["lid" .. S], function(cf)
					return down * cf
				end)
				local up = CF(0, 0.012 * t * k, 0)
				move(fc.tags["low" .. S], function(cf)
					return up * cf
				end)
				local bx = fc.brow[1] * sgn
				local pivot = fc.frame * CF(-bx * k, fc.brow[2] * k, 0)
				local rot = pivot * ANG(0, 0, sgn * rad(fc.browA) * t) * pivot:Inverse()
				local bdown = CF(0, -0.012 * t * k, 0)
				move(fc.tags["brow" .. S], function(cf)
					return bdown * rot * cf
				end)
				local j = 0.006 * k * clamp01((t - 0.3) / 0.7)
				local jit = CF(noise(time * 9, fi * 3 + sgn) * j, noise(time * 9, fi * 5 - sgn) * j, 0)
				move(fc.tags["iris" .. S], function(cf)
					return jit * cf
				end)
				for _, e in ipairs(fc.tags["pupil" .. S] or {}) do
					local sc = 1 - 0.38 * t
					e.p.Size = V3(e.size.X * sc, e.size.Y * sc, e.size.Z)
					e.p.CFrame = jit * e.cf
				end
				for _, e in ipairs(fc.tags["hi" .. S] or {}) do
					e.p.Transparency = clamp01((t - 0.55) * 4)
					e.p.CFrame = jit * e.cf
				end
			end
			for _, e in ipairs(fc.tags.stress or {}) do
				e.p.Transparency = 1 - clamp01((t - 0.45) * 3)
			end
		end
	end
	EYES.tension(0, 0)
	return f
end
