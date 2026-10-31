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
