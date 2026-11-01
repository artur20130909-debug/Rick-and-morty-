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
	rig:add("neck", V3(1.4, 0.64, 1.28), h, CF(0, 1.25, 0.08), { shape = "ball" })
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
