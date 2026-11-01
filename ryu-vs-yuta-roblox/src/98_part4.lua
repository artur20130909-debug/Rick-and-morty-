----------------------------------------------------------------------
-- ЧАСТЬ 4 (17.1 с): Юта бежит сквозь туман, Рю копит энергию в причёске
-- и стреляет «Гранитным залпом» (Granite Blast)
----------------------------------------------------------------------

local P4 = {}
local P4STAGE = STAGE.zoom + V3(0, 0, 1400) -- пустая площадка для крупных планов

local function day4(o)
	o = o or {}
	day3(o)
end

-- 0.00–0.73: продолжение сцены «its force is weak!»
-- (если часть 4 запущена отдельно, сцена строится заново с того же места)
function P4.weak()
	if Shot.scene ~= "weak" then
		P3.weakScene(0, T3.FIN - T3.WEAK)
	end
end

-- 0.73–1.73: камера перед Ютой; он бежит прямо на нас сквозь туман и розовые искры
function P4.mist()
	local f = beginShot(T4.MIST)
	day4({ brightness = 2.0, tint = RGB(238, 234, 255), sat = 0.2, dof = { 12, 8, 0.3 },
		haze = 0.36, hazeColor = RGB(212, 204, 242), hazeDecay = RGB(160, 150, 220), veil = { RGB(204, 196, 240), 0.9, 0.68 } })
	local tau0 = T3.FIN - T3.WEAK + T4.MIST
	local yp0, ydir, toY, side = P3.weakPath(tau0)
	yuta:show(true)
	SH.yutaBlood(true)
	yuta:pose({ root = { -22, 0, 0 } }, 0)
	SH.runCycle(yuta, 16, 62)
	local eye = yp0 + ydir * 17 + V3(0, 2.2, 0) + side * 1.5
	local cam0 = CFrame.lookAt(eye, yp0 + V3(0, 2.6, 0))
	camCF, camFOV = cam0, 48
	FX.mist(CFrame.lookAt(yp0 + ydir * 6 + V3(0, 3, 0), yp0 + ydir * 30), V3(50, 9, 40), 30, RGB(220, 212, 246), 0.55,
		{ sizes = { 12, 24 }, shade = RGB(192, 182, 234), drift = side * 1.5, seed = 51 })
	FX.mist(CFrame.lookAt(yp0 + ydir * 14 + V3(0, 1, 0), yp0 + ydir * 30), V3(30, 2, 16), 14, RGB(232, 226, 250), 0.45,
		{ sizes = { 6, 11 }, drift = side * 1.2, seed = 53 })
	FX.mist(CFrame.lookAt(yp0 - ydir * 30 + V3(0, 6, 0), yp0), V3(90, 16, 40), 18, RGB(216, 208, 244), 0.6,
		{ sizes = { 24, 40 }, drift = side * 1.0, seed = 52 })
	local sparks, dust = {}, 0
	local sparkDir = (cam0.RightVector * 1 + cam0.UpVector * 0.3 - cam0.LookVector * 0.25).Unit
	Shot.update = function(u, dt)
		local yp = P3.weakPath(tau0 + u)
		SH.placeRunner(yuta, yp, ydir, 16)
		camCF = cam0 * CF(0, 0, 1.5 * u)
		shake = 0.25
		dust = dust - dt
		if dust <= 0 then
			dust = 0.1
			FX.puff(yp - ydir * 1.2 + V3(0, 0.5, 0), 2.4, 0.8, V3(0, 1.2, 0), { op = 0.4, color = RGB(236, 232, 252) })
		end
		SH.pinkSparks(camCF, dt, sparks, 0.012, sparkDir)
	end
end

-- 1.73–6.23: Юта крупно, снизу: бежит, взгляд вверх на Рю; кровь на плече,
-- сначала по лицу летят розовые искры
function P4.yuta()
	local f = beginShot(T4.YUTA)
	setLook({ clock = 13, brightness = 1.4, ambient = RGB(200, 210, 245), outdoor = RGB(200, 210, 245), tint = RGB(240, 244, 255),
		sat = 0.25, contrast = 0.1, bloom = 0.8, dof = { 4, 3, 0.4 } })
	local base = P4STAGE
	yuta:show(true)
	SH.yutaBlood(true)
	yuta:place(CF(base) * ANG(0, math.pi, 0))
	yuta:pose({ root = { -16, 0, 0 }, neck = { 12, 0, 0 } }, 0)
	SH.runCycle(yuta, 13, 40)
	yuta:update(songT)
	local face = yuta:point("neck", V3(0, 0.6, 0))
	local cam0 = CFrame.lookAt(face + V3(0.6, -1.9, 3.6), face + V3(0, 0.35, 0)) * ANG(0, 0, rad(-6))
	local cam1 = CFrame.lookAt(face + V3(0.3, -1.6, 3.0), face + V3(0, 0.35, 0)) * ANG(0, 0, rad(-3))
	camCF, camFOV = cam0, 42
	FX.backdrop(CFrame.lookAt(face - cam0.LookVector * -60, face) * CF(0, 10, 0), 300, 200,
		{ RGB(120, 150, 225), RGB(64, 92, 186), RGB(30, 44, 120) }, 200)
	local sparks, acc = {}, 0
	local dir = (cam0.RightVector * 1 + cam0.UpVector * 0.25).Unit
	Shot.update = function(u, dt)
		local k = smooth(u / (T4.LEAP - T4.YUTA))
		camCF = cam0:Lerp(cam1, k) * CF(0, 0.05 * sin(u * 13), 0)
		shake = 0.12
		yuta:place(CF(base + V3(0, abs(sin(songT * 13)) * 0.18, 0)) * ANG(0, math.pi, 0))
		-- розовые искры летят по лицу первые ~2 секунды
		if u < 1.9 then
			SH.pinkSparks(camCF, dt, sparks, 0.016, dir, { 1.5, 3.6 })
		end
		-- фон уносится назад: длинные светлые полосы скорости
		acc = acc + dt * 10
		while acc >= 1 do
			acc = acc - 1
			local from = cam0 * V3(rr(-14, 14), rr(-6, 9), -rr(14, 26))
			FX.streak(from, (cam0.UpVector * -1 + cam0.LookVector * 0.4).Unit, rr(6, 12), rr(40, 60), 0.5, RGB(190, 210, 255), rr(0.08, 0.16), 0.9)
		end
	end
end

-- 6.23–7.33: камера несётся за Ютой к далёкому Рю; Юта прыгает над камерой, летят обломки
function P4.leap()
	local f = beginShot(T4.LEAP)
	day4({ brightness = 2.2, tint = RGB(240, 246, 255), sat = 0.15, bloom = 1.0,
		haze = 0.32, hazeColor = RGB(232, 240, 255), hazeDecay = RGB(190, 210, 245), veil = { RGB(236, 244, 255), 0.86, 0.68 } })
	local toY = ((YUTA_POS - RYU_POS) * V3(1, 0, 1)).Unit
	local side = toY:Cross(V3(0, 1, 0)).Unit
	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "grin")
	ryu:place(CFrame.lookAt(RYU_POS, RYU_POS + toY))
	ryu:pose(POSE.ryuStand, 0)
	ryu:update(songT)
	local g = SH.granite({ level = 0.7, bolts = 3, reach = 4, size = 1.8 })
	yuta:show(true)
	SH.yutaBlood(true)
	SH.runCycle(yuta, 16, 60)
	local y0 = RYU_POS + toY * 34
	local run = -toY
	FX.mist(CFrame.lookAt(RYU_POS + toY * 10 + V3(0, 5, 0), RYU_POS - toY), V3(80, 12, 40), 18, RGB(246, 250, 255), 0.5,
		{ sizes = { 18, 34 }, shade = RGB(214, 226, 250), drift = side * 2, seed = 61 })
	local acc = 0
	local jumping = false
	yuta:pose({ root = { -22, 0, 0 } }, 0)
	Shot.update = function(u, dt)
		-- Юта: разбег и прыжок дугой вверх-вперёд
		local jump = clamp01((u - 0.3) / 0.8)
		local yp = y0 + run * (u * 14) + V3(0, sin(jump * math.pi) * 6, 0)
		if jump > 0 and not jumping then
			jumping = true
			yuta:pose({ root = { -35, 0, 0 }, rArm = { -60, 0, 30 }, lArm = { 110, 0, -20 }, rLeg = { 50, 0, 0 }, lLeg = { -30, 0, 0 } }, 0.15, songT)
			for _, b in ipairs({ "rLeg", "lLeg", "rArm", "lArm" }) do
				yuta.bones[b].wob = nil
			end
		end
		yuta:place(CFrame.lookAt(yp, yp + run))
		-- камера: низко за спиной, догоняет и проходит под прыгающим Ютой
		local cp = y0 - run * 16 + run * (u * 40) + V3(0, 1.6, 0) + side * 0.8
		camCF = CFrame.lookAt(cp, RYU_POS + V3(0, 3.5, 0))
		camFOV = 62
		shake = 0.35 + 0.4 * jump
		Shot.blur = 2 * jump
		acc = acc + dt * 30
		while acc >= 1 do
			acc = acc - 1
			local p = cp + run * rr(4, 20) + side * rr(-9, 9) + V3(0, rr(0, 6), 0)
			FX.flyer(V3(rr(0.3, 1.0), rr(0.2, 0.7), rr(0.4, 1.2)), pick({ RGB(28, 34, 66), RGB(44, 54, 96), RGB(18, 22, 44) }), p,
				(-run * rr(8, 20) + V3(rr(-4, 4), rr(2, 9), rr(-4, 4))), { life = rr(0.6, 1.0), spin = 6 })
		end
	end
end

-- 7.33–9.00: Рю снизу на фоне белого неба: из кончика помпадура во все стороны бьют молнии
function P4.charge()
	local f = beginShot(T4.CHARGE)
	setLook({ clock = 13, brightness = 1.5, ambient = RGB(220, 232, 255), outdoor = RGB(220, 232, 255), tint = RGB(240, 248, 255),
		sat = 0.2, contrast = 0.12, bloom = 1.0 })
	local base = P4STAGE + V3(200, 0, 0)
	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "grin")
	ryu:place(CF(base) * ANG(0, math.pi, 0))
	ryu:pose({ root = { 4, 0, 0 }, neck = { 8, 0, 0 }, rArm = { 15, 0, 25 }, lArm = { 15, 0, -25 }, rLeg = { 0, 0, 8 }, lLeg = { 0, 0, -8 } }, 0)
	ryu.bones.coat.wob = function(t)
		return ANG(rad(-10 - 5 * sin(t * 7)), 0, 0)
	end
	ryu:update(songT)
	local chest = ryu:point("root", V3(0, 1.0, 0))
	local cam0 = CFrame.lookAt(chest + V3(0.4, -3.2, 9.5), chest + V3(0, 1.8, 0))
	local cam1 = CFrame.lookAt(chest + V3(0.3, -2.0, 6.4), chest + V3(0, 2.0, 0))
	camCF, camFOV = cam0, 50
	FX.backdrop(CFrame.lookAt(chest - cam0.LookVector * -80, chest) * CF(0, 20, 0), 360, 260,
		{ RGB(250, 252, 255), RGB(200, 222, 252), RGB(130, 170, 236) }, 160)
	local g = SH.granite({ level = 0.5, bolts = 8, reach = 9, size = 1.5, boltWidth = 0.07 })
	local tw = 0
	Shot.update = function(u, dt)
		local k = smooth(u / (T4.FACE - T4.CHARGE))
		camCF = cam0:Lerp(cam1, k)
		shake = 0.15 + 0.3 * k
		g.level = 0.55 + 0.45 * k
		g.size = 1.5 + 0.8 * k
		tw = tw - dt
		if tw <= 0 then
			tw = 0.05
			local tip = ryu:point("neck", SH.TIP)
			FX.flyer(V3(0.08, rr(0.3, 0.8), rr(0.3, 0.9)), pick({ C.cyan, RGB(200, 250, 255) }), tip + randUnit() * 0.6,
				(randUnit() + V3(0, 0.6, 0)).Unit * rr(8, 16), { wedge = true, neon = true, life = rr(0.35, 0.6), spin = 10 })
		end
	end
end

-- 9.00–10.60: лицо Рю вплотную, ухмылка; вокруг кружат голубые осколки энергии
function P4.face()
	local f = beginShot(T4.FACE)
	setLook({ clock = 13, brightness = 1.4, ambient = RGB(200, 228, 255), outdoor = RGB(200, 228, 255), tint = RGB(236, 248, 255),
		sat = 0.25, contrast = 0.15, bloom = 1.0 })
	local base = P4STAGE + V3(400, 0, 0)
	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "grin")
	ryu:place(CF(base) * ANG(0, math.pi, 0))
	ryu:pose({ root = { 2, 0, 0 }, neck = { 4, 12, -6 }, rArm = { 15, 0, 25 }, lArm = { 15, 0, -25 } }, 0)
	ryu:update(songT)
	local face = ryu:point("neck", V3(0, 0.65, -0.6))
	local cam0 = CFrame.lookAt(face + V3(-0.5, -0.5, 3.0), face + V3(0, 0.25, 0)) * ANG(0, 0, rad(10))
	local cam1 = CFrame.lookAt(face + V3(-0.3, -0.4, 2.5), face + V3(0, 0.25, 0)) * ANG(0, 0, rad(14))
	camCF, camFOV = cam0, 52
	FX.backdrop(CFrame.lookAt(face - cam0.LookVector * -60, face), 300, 200,
		{ RGB(230, 246, 255), RGB(120, 200, 245), RGB(30, 90, 170) }, 120)
	local g = SH.granite({ level = 1, bolts = 5, reach = 4, size = 1.4 })
	local acc = 0
	Shot.update = function(u, dt)
		camCF = cam0:Lerp(cam1, smooth(u / (T4.SETTLE - T4.FACE)))
		shake = 0.35
		Shot.blur = 1
		-- осколки: голубые неоновые клинья летят вокруг лица
		acc = acc + dt * 34
		while acc >= 1 do
			acc = acc - 1
			local p = face + V3(rr(-2.2, 2.2), rr(0.4, 2.5), rr(-1.2, 0.6))
			FX.flyer(V3(0.06, rr(0.2, 0.7), rr(0.25, 0.9)), pick({ C.cyan, RGB(170, 245, 255), C.white }), p,
				(V3(rr(-1, 1), rr(-0.2, 1), rr(0, 0.6)).Unit * rr(4, 10)), { wedge = true, neon = true, life = rr(0.3, 0.6), spin = 12 })
		end
		local fl = 0.5 + 0.5 * sin(u * 23)
		ui.flash.BackgroundColor3 = RGB(200, 245, 255)
		ui.flash.BackgroundTransparency = 1 - 0.12 * fl
	end
end

-- 10.60–12.70: «I'll settle this.» — Рю хохочет, от причёски разлетаются полосы энергии
function P4.settle()
	local f = beginShot(T4.SETTLE)
	setLook({ clock = 13, brightness = 1.4, ambient = RGB(200, 228, 255), outdoor = RGB(200, 228, 255), tint = RGB(236, 248, 255),
		sat = 0.25, contrast = 0.15, bloom = 1.0 })
	local base = P4STAGE + V3(600, 0, 0)
	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "laugh")
	ryu:place(CF(base) * ANG(0, math.pi, 0))
	ryu:pose({ root = { 6, 0, 0 }, neck = { 16, -14, 8 }, rArm = { 20, 0, 40 }, lArm = { 20, 0, -40 } }, 0)
	ryu.bones.neck.wob = function(t)
		return ANG(rad(4 * sin(t * 18)), 0, 0)
	end
	ryu:update(songT)
	local face = ryu:point("neck", V3(0, 0.65, -0.6))
	local cam0 = CFrame.lookAt(face + V3(0.9, -0.8, 3.4), face + V3(0, 0.3, 0)) * ANG(0, 0, rad(-12))
	local cam1 = cam0 * CF(0, 0, -0.5)
	camCF, camFOV = cam0, 50
	FX.backdrop(CFrame.lookAt(face - cam0.LookVector * -60, face), 300, 200,
		{ RGB(220, 244, 255), RGB(90, 170, 240), RGB(20, 60, 150) }, 60)
	local g = SH.granite({ level = 1, bolts = 6, reach = 4.5, size = 1.6 })
	local acc = 0
	Shot.update = function(u, dt)
		camCF = cam0:Lerp(cam1, smooth(u / (T4.BURST - T4.SETTLE)))
		shake = 0.3
		if floor(u * 7) % 5 == 4 then
			showVariant(ryu.tags, "mouth_", "grin")
		else
			showVariant(ryu.tags, "mouth_", "laugh")
		end
		local tip = ryu:point("neck", SH.TIP)
		acc = acc + dt * 26
		while acc >= 1 do
			acc = acc - 1
			local d = (randUnit() * V3(1, 0.7, 0.4) + V3(0, 0.5, 0)).Unit
			FX.streak(tip + d * 0.5, d, rr(2, 5), rr(25, 45), 0.35, pick({ C.cyan, RGB(190, 250, 255) }), rr(0.08, 0.2), 4)
		end
	end
end

-- 12.70–13.67: «Granite Blast!» — вспышка из причёски, потом тёмный смаз по плащу
function P4.burst()
	local f = beginShot(T4.BURST)
	setLook({ clock = 13, brightness = 1.2, ambient = RGB(150, 190, 240), outdoor = RGB(150, 190, 240), tint = RGB(230, 244, 255),
		sat = 0.2, contrast = 0.2, bloom = 1.0 })
	local base = P4STAGE + V3(800, 0, 0)
	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "grin")
	ryu:place(CF(base) * ANG(0, math.pi, 0))
	ryu:pose({ root = { 6, 0, 0 }, neck = { 12, -10, 6 }, rArm = { 20, 0, 40 }, lArm = { 20, 0, -40 } }, 0)
	ryu:update(songT)
	local face = ryu:point("neck", V3(0, 0.65, -0.6))
	local cam0 = CFrame.lookAt(face + V3(0.4, -0.4, 3.0), face + V3(0, 0.4, 0)) * ANG(0, 0, rad(-8))
	camCF, camFOV = cam0, 52
	FX.backdrop(CFrame.lookAt(face - cam0.LookVector * -60, face), 300, 200, { RGB(60, 110, 190), RGB(20, 40, 100), RGB(6, 10, 30) }, 90)
	local g = SH.granite({ level = 1, bolts = 6, reach = 6, size = 2.2 })
	local tip = ryu:point("neck", SH.TIP)
	local rays = FX.rays(tip, 22, { C.cyan, C.white, RGB(150, 230, 255) }, 4, 16, 1.2, { brightness = 3, colorStart = true, start = 0.6 })
	local chest = ryu:point("root", V3(0, 0.6, -0.6))
	Shot.update = function(u, dt)
		rays.scale = u < 0.25 and clamp01(u / 0.12) or 0
		rays.update(u)
		if u < 0.25 then
			-- вспышка энергии прямо в объектив
			shake = 1.0
			g.size = 2.2 + 6 * u
			local fl = clamp01(u / 0.2)
			ui.flash.BackgroundColor3 = RGB(190, 245, 255)
			ui.flash.BackgroundTransparency = 1 - 0.75 * fl
		else
			-- тёмный смаз: камера проносится по меху и плащу Рю
			local k = clamp01((u - 0.25) / 0.72)
			g.level = 0
			ui.flash.BackgroundTransparency = 1
			ui.black.BackgroundTransparency = 0.35 + 0.25 * sin(k * math.pi)
			Shot.blur = 10
			shake = 0.6
			camCF = CFrame.lookAt(chest + V3(1.4 - 2.8 * k, 1.6 - 2.4 * k, 1.1), chest + V3(-0.5 + k, -0.5, -1))
			camFOV = 60
		end
	end
end

-- 13.67–15.47: «Granite Blast!» — Рю раскинул руки, в кончике причёски голубая звезда,
-- у ног клубится дым, за спиной стена разрушенного дома
function P4.pose()
	local f = beginShot(T4.POSE)
	ui.black.BackgroundTransparency = 1
	day4({ brightness = 2.2, tint = RGB(232, 242, 255), sat = 0.15, bloom = 1.0,
		haze = 0.26, hazeColor = RGB(214, 224, 248), hazeDecay = RGB(150, 170, 230), veil = { RGB(226, 234, 252), 0.92, 0.66 } })
	local toY = ((YUTA_POS - RYU_POS) * V3(1, 0, 1)).Unit
	local side = toY:Cross(V3(0, 1, 0)).Unit
	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "laugh")
	ryu:place(CFrame.lookAt(RYU_POS, RYU_POS + toY))
	ryu:pose({ root = { 10, 0, 0 }, neck = { 14, -6, 0 }, rArm = { 30, 0, 82 }, lArm = { 30, 0, -82 }, rLeg = { -10, 0, 10 }, lLeg = { 12, 0, -10 } }, 0)
	ryu.bones.coat.wob = function(t)
		return ANG(rad(-12 - 4 * sin(t * 6)), 0, rad(2 * sin(t * 5)))
	end
	ryu:update(songT)
	local g = SH.granite({ level = 1, bolts = 5, reach = 3.5, size = 2.0 })
	-- стена разрушенного дома за спиной
	local wallC = RGB(150, 166, 214)
	local back = RYU_POS - toY * 26
	for i = -2, 2 do
		local h = 18 + (i % 2) * 6 + rr(-2, 3)
		local w = newPart(f, V3(9.5, h, 2), wallC:Lerp(RGB(110, 126, 190), (i + 2) / 6), CFrame.lookAt(back + side * i * 10 + V3(0, h / 2, 0), RYU_POS + V3(0, h / 2, 0)))
		for row = 1, 3 do
			newPart(f, V3(7, 1.2, 0.2), RGB(70, 84, 140), w.CFrame * CF(0, -h / 2 + row * 5, -1.05))
		end
	end
	local chest = ryu:point("root", V3(0, 0.6, 0))
	local cam0 = CFrame.lookAt(chest + toY * 13 + side * 1.2 + V3(0, -1.2, 0), chest + V3(0, 1.0, 0))
	local cam1 = CFrame.lookAt(chest + toY * 16 + side * 2.2 + V3(0, -0.8, 0), chest + V3(0, 1.0, 0))
	camCF, camFOV = cam0, 50
	-- дым у ног и по бокам
	FX.mist(CFrame.lookAt(RYU_POS + V3(0, 1.5, 0), RYU_POS + toY), V3(44, 3, 26), 26, RGB(232, 238, 252), 0.6,
		{ sizes = { 7, 14 }, shade = RGB(196, 206, 240), drift = side * 1.4, seed = 71 })
	FX.mist(CFrame.lookAt(RYU_POS - toY * 12 + V3(0, 6, 0), RYU_POS + toY), V3(70, 12, 18), 14, RGB(226, 232, 250), 0.45,
		{ sizes = { 16, 28 }, drift = side * 1.0, seed = 72 })
	Shot.update = function(u, dt)
		camCF = cam0:Lerp(cam1, smooth(u / (T4.FLASH - T4.POSE)))
		shake = 0.15 + 0.25 * clamp01((u - 1.2) / 0.6)
		g.size = 2.0 + 0.6 * clamp01((u - 1.0) / 0.8)
		if floor(u * 6) % 4 == 3 then
			showVariant(ryu.tags, "mouth_", "grin")
		else
			showVariant(ryu.tags, "mouth_", "laugh")
		end
	end
end

-- 15.47–15.80: залп: чёрный кадр, белая звезда, разлёт и белая вспышка
function P4.flash()
	local f = beginShot(T4.FLASH)
	setLook({ clock = 0, brightness = 0, ambient = RGB(20, 24, 40), outdoor = RGB(20, 24, 40), bloom = 1.0 })
	local base = P4STAGE + V3(1000, 0, 0)
	local cam0 = CFrame.lookAt(base + V3(0, 0, 30), base)
	camCF, camFOV = cam0, 60
	FX.backdrop(CF(base + V3(0, 0, -60)) * ANG(0, math.pi, 0), 300, 200, { RGB(4, 6, 12), RGB(2, 2, 6), RGB(0, 0, 0) }, 90)
	local star = base + V3(-3, 0.5, 0)
	local core = FX.flare(star, 0.6, C.white, { points = 10 })
	local rays = FX.rays(star, 26, { C.white, RGB(200, 240, 255), C.cyan }, 6, 26, 1.4, { brightness = 4, colorStart = true, start = 1 })
	local done = false
	Shot.update = function(u, dt)
		shake = 0.6
		core.set(nil, 0.6 + 10 * clamp01((u - 0.08) / 0.12))
		rays.scale = clamp01((u - 0.1) / 0.12)
		rays.update(u)
		if u > 0.12 and not done then
			done = true
			for _ = 1, 18 do
				local d = (randUnit() * V3(1, 0.8, 0.2)).Unit
				FX.flyer(V3(rr(0.8, 2.2), rr(0.5, 1.6), rr(0.3, 1)), RGB(10, 12, 20), star + d * rr(2, 6), d * rr(30, 60),
					{ life = 0.4, spin = 8 })
			end
		end
		local w = clamp01((u - 0.2) / 0.08)
		ui.flash.BackgroundColor3 = C.white
		ui.flash.BackgroundTransparency = 1 - w
	end
end

-- 15.80–16.30: сверху: голубой залп из причёски Рю бьёт вдоль поля, летят обломки
function P4.top()
	local f = beginShot(T4.TOP)
	day4({ brightness = 2.4, tint = RGB(226, 240, 255), sat = 0.3, bloom = 1.0 })
	local rp = CRATER + V3(-10, 0, -20)
	local dir = V3(1, 0, -0.35).Unit
	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "laugh")
	ryu:place(CFrame.lookAt(rp, rp + dir))
	ryu:pose(POSE.ryuArmsWide, 0)
	ryu:update(songT)
	local g = SH.granite({ level = 1, bolts = 4, reach = 4, size = 2.4, beam = true })
	g.dir = (dir + V3(0, 0.08, 0)).Unit
	newPart(f, V3(16, 6, 30), RGB(24, 28, 52), CFrame.lookAt(rp - dir * 22 + V3(-14, 1, 8), rp) * ANG(0.2, 0.4, 0.1), { wedge = true })
	-- камера сверху, повернута так, что залп уходит вправо по кадру (как в аниме)
	local function topCam(h, back, ahead)
		local eye = rp - dir * back + V3(0, h, 0) + dir:Cross(V3(0, 1, 0)) * 10
		local look = (rp + dir * ahead - eye).Unit
		local right = (dir - look * dir:Dot(look)).Unit
		return CFrame.fromMatrix(eye, right, right:Cross(look))
	end
	local cam0 = topCam(46, 6, 14)
	local cam1 = topCam(42, 5, 16)
	camCF, camFOV = cam0, 55
	local acc = 0
	Shot.update = function(u, dt)
		camCF = cam0:Lerp(cam1, smooth(u / (T4.SIDE - T4.TOP)))
		shake = 1.2
		g.beamLen = 140 * easeOut(clamp01(u / 0.25))
		g.beamW = 5 + 2 * u + sin(u * 40) * 0.5
		acc = acc + dt * 70
		while acc >= 1 do
			acc = acc - 1
			local p = rp + dir * rr(5, 60) + V3(rr(-6, 6), rr(0, 3), rr(-6, 6))
			local white = rng:NextNumber() < 0.5
			FX.flyer(V3(rr(0.3, 1.4), rr(0.2, 0.6), rr(0.4, 1.6)), white and RGB(240, 248, 255) or RGB(30, 40, 80), p,
				(dir * rr(10, 30) + V3(rr(-8, 8), rr(6, 18), rr(-8, 8))), { wedge = white, life = rr(0.4, 0.7), spin = 7 })
		end
	end
end

-- 16.30–16.45: Рю сбоку в тени, голубой вихрь уходит вперёд
function P4.side()
	local f = beginShot(T4.SIDE)
	day4({ brightness = 1.2, ambient = RGB(70, 90, 150), outdoor = RGB(70, 90, 150), tint = RGB(170, 190, 240), sat = 0.2, bloom = 1.0 })
	local dir = V3(1, 0, -0.35).Unit
	local rp = CRATER + V3(-10, 0, -20)
	ryu:show(true)
	ryu:place(CFrame.lookAt(rp, rp + dir))
	ryu:pose(POSE.ryuStand, 0)
	ryu:update(songT)
	local g = SH.granite({ level = 1, bolts = 5, reach = 5, size = 2.4, beam = true })
	g.dir = dir
	g.beamLen = 80
	g.beamW = 4
	local cam0 = CFrame.lookAt(rp - dir * 4 + dir:Cross(V3(0, 1, 0)) * 7 + V3(0, 3.2, 0), rp + dir * 7 + V3(0, 3.6, 0))
	camCF, camFOV = cam0, 60
	Shot.update = function(u, dt)
		camCF = cam0 * CF(0.8 * u, 0, -2 * u)
		shake = 0.8
	end
end

-- 16.45–17.10: чёрный кадр со светом справа, затем гигантский голубой залп сносит обломки
function P4.sweep()
	local f = beginShot(T4.SWEEP)
	setLook({ clock = 0, brightness = 0, ambient = RGB(16, 20, 34), outdoor = RGB(16, 20, 34), bloom = 1.0 })
	local lit = false
	local dir = V3(1, 0, -0.35).Unit
	local rp = CRATER + V3(-10, 0, -20)
	local side = dir:Cross(V3(0, 1, 0)).Unit
	local eye = rp + dir * 34 - side * 36 + V3(0, 3.5, 0)
	local cam0 = CFrame.lookAt(eye, rp + dir * 40 + V3(0, 3, 0))
	camCF, camFOV = cam0, 66
	local beam = FX.energyBeam(C.cyan, 9)
	local from = rp + V3(0, 6, 0)
	local front = FX.glow(eye + cam0.LookVector * 30 + cam0.RightVector * 12, 40, C.white, 1, { brightness = 4 })
	local acc = 0
	Shot.update = function(u, dt)
		shake = 1.6
		Shot.blur = 3
		if u < 0.15 then
			-- тёмный кадр, справа надвигается белый свет залпа
			front.size = 30 + 160 * u
		else
			if not lit then
				lit = true
				day4({ brightness = 2.0, tint = RGB(220, 238, 255), sat = 0.3, bloom = 1.0 })
			end
			front.k = 0
			local k = clamp01((u - 0.15) / 0.3)
			beam.set(from, from + dir * (40 + 160 * k), 9 + 5 * k)
			ui.flash.BackgroundColor3 = RGB(160, 240, 255)
			ui.flash.BackgroundTransparency = 1 - 0.2 * k
			acc = acc + dt * 90
			while acc >= 1 do
				acc = acc - 1
				local p = rp + dir * rr(20, 70) + side * rr(-14, 14) + V3(0, rr(0, 8), 0)
				FX.flyer(V3(rr(0.6, 2.4), rr(0.4, 1.4), rr(0.6, 2.2)), pick({ RGB(26, 34, 70), RGB(60, 80, 140), RGB(230, 245, 255) }), p,
					(dir * rr(20, 50) + V3(rr(-6, 6), rr(4, 16), rr(-6, 6))), { life = rr(0.4, 0.8), spin = 8 })
			end
		end
	end
end

P4.shots = {
	{ 0, P4.weak }, { T4.MIST, P4.mist }, { T4.YUTA, P4.yuta }, { T4.LEAP, P4.leap }, { T4.CHARGE, P4.charge },
	{ T4.FACE, P4.face }, { T4.SETTLE, P4.settle }, { T4.BURST, P4.burst }, { T4.POSE, P4.pose }, { T4.FLASH, P4.flash },
	{ T4.TOP, P4.top }, { T4.SIDE, P4.side }, { T4.SWEEP, P4.sweep },
}
P4.fin = T4.FIN

-- субтитры части 4
P4.subs = {
	{ 0.00, 0.85, "its force is weak!", "её сила слаба!" },
	{ 2.40, 5.95, "After Domain Expansion and a meal with me,", "После расширения территории и боя со мной" },
	{ 5.98, 10.55, "even you couldn't have recovered that much.", "даже ты не смог бы столько восстановить." },
	{ 10.60, 12.45, "I'll settle this.", "Я с этим покончу." },
	{ 12.70, 15.45, "Granite Blast!", "Гранитный залп!" },
}
