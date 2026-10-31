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
