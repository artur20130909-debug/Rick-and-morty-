----------------------------------------------------------------------
-- ЧАСТЬ 3 (0:00–0:16)
----------------------------------------------------------------------

local P3 = {}
local RYU_POS = FIELD + V3(-30, 0, 30) -- где стоит Рю в части 3
local YUTA_POS = FIELD + V3(-20, 0, -40) -- где Юта

local function day3(o)
	o = o or {}
	setLook({
		clock = 13, brightness = o.brightness or 2.5, exposure = o.exposure or 0.15,
		ambient = o.ambient or RGB(155, 170, 205), outdoor = o.outdoor or RGB(165, 180, 215),
		fogColor = o.fogColor or RGB(205, 222, 250), fogStart = o.fogStart or 450, fogEnd = o.fogEnd or 2600,
		tint = o.tint or RGB(245, 250, 255), sat = o.sat or 0.3, contrast = o.contrast or 0.12, bright = o.bright or 0.03,
		bloom = o.bloom or 0.9, bloomSize = 40, bloomThreshold = 0.88, dof = o.dof,
		haze = o.haze, hazeColor = o.hazeColor, hazeDecay = o.hazeDecay, hazeSoft = o.hazeSoft, veil = o.veil,
	})
end

local function windStreaks(cam0, dt, state, rate, dir, col)
	state.t = (state.t or 0) - dt
	if state.t <= 0 then
		state.t = rate
		local from = cam0 * V3(rr(-8, 10), rr(-3, 8), -rr(8, 16))
		FX.streak(from, dir, rr(6, 12), rr(35, 55), 0.6, col or RGB(245, 250, 255), rr(0.15, 0.35), 1.5)
	end
end

-- 0.00–2.40: Рю спиной в розово-сиреневом тумане, на него летит розовый луч
function P3.approach()
	local f = beginShot(0)
	day3({ tint = RGB(255, 242, 252), sat = 0.2, bloom = 1.0, haze = 0.34, hazeColor = RGB(242, 220, 246), hazeDecay = RGB(196, 166, 228),
		veil = { RGB(244, 222, 246), 0.93, 0.74 } })
	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "smirk")
	ryu:place(CF(RYU_POS))
	ryu:pose(POSE.ryuBack, 0)
	ryu.bones.coat.wob = function(t)
		return ANG(rad(-8 - 4 * sin(t * 6)), 0, rad(2 * sin(t * 4)))
	end
	ryu:update(songT)
	local cam0 = CFrame.lookAt(RYU_POS + V3(-1.6, 3.0, 9), RYU_POS + V3(1, 3.4, -30))
	local cam1 = CFrame.lookAt(RYU_POS + V3(-1.4, 3.0, 8.2), RYU_POS + V3(1, 3.4, -30))
	camCF, camFOV = cam0, 55
	local far = RYU_POS + V3(40, 22, -52)
	local beam = FX.energyBeam(C.pink, 3.4, { solid = true })
	local head = FX.flare(far, 6, C.pinkHot, { points = 10, glowOp = 0.7 })
	-- мягкий туман: дальняя стена, полоса у земли и клубы по бокам от Рю
	FX.mist(CF(RYU_POS + V3(4, 8, -110)), V3(150, 18, 60), 26, RGB(252, 236, 250), 0.6,
		{ sizes = { 24, 44 }, shade = RGB(226, 204, 242), drift = V3(-1.6, 0.25, 0), seed = 31 })
	FX.mist(CF(RYU_POS + V3(-6, 2.5, -58)), V3(90, 5, 40), 22, RGB(248, 230, 250), 0.45,
		{ sizes = { 12, 22 }, shade = RGB(230, 206, 244), drift = V3(-1.2, 0.1, 0), seed = 32 })
	FX.mist(CF(RYU_POS + V3(0, 0.8, -12)), V3(40, 1.5, 14), 12, RGB(250, 236, 252), 0.4,
		{ sizes = { 6, 11 }, drift = V3(-1, 0, 0), seed = 33 })
	local wind = {}
	Shot.update = function(u, dt)
		camCF = cam0:Lerp(cam1, smooth(u / T3.RIGHT))
		shake = 0.1 + 0.2 * clamp01((u - 1.5) / 0.9)
		local prog = easeIn(clamp01(u / T3.RIGHT)) * 0.8
		local tip = far:Lerp(RYU_POS + V3(2, 3, -6), prog)
		beam.set(far, tip, 3 + prog * 4)
		head.set(tip, 6 + prog * 8)
		windStreaks(cam0, dt, wind, 0.08, (cam0.RightVector * -1).Unit, RGB(255, 240, 250))
	end
end

-- 2.40–4.00: «That's right!» — Рю смеётся, раскинув руки
function P3.right()
	local f = beginShot(T3.RIGHT)
	day3({ brightness = 2.6, dof = { 6.5, 5, 0.2 } })
	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "laugh")
	ryu:place(CF(RYU_POS) * ANG(0, rad(180), 0))
	ryu:pose(POSE.ryuArmsWide, 0)
	ryu.bones.coat.wob = function(t)
		return ANG(rad(-8 - 4 * sin(t * 6)), 0, 0)
	end
	ryu.bones.neck.wob = function(t)
		return ANG(rad(3 * sin(t * 16)), 0, 0)
	end
	ryu:update(songT)
	local chest = ryu:point("root", V3(0, 0.8, 0))
	local cam0 = CFrame.lookAt(chest + V3(1.2, -1.4, 7.2), chest + V3(0, 1.2, 0)) * ANG(0, 0, rad(4))
	local cam1 = cam0 * CF(0, 0.1, -0.5)
	camCF, camFOV = cam0, 52
	-- небо за спиной в длинных полосах ветра (далеко позади, не у лица)
	local acc = 0
	Shot.update = function(u, dt)
		camCF = cam0:Lerp(cam1, smooth(u / (T3.GOING - T3.RIGHT)))
		shake = 0.1
		if floor(u * 6) % 4 == 3 then
			showVariant(ryu.tags, "mouth_", "grin")
		else
			showVariant(ryu.tags, "mouth_", "laugh")
		end
		acc = acc + dt * 14
		while acc >= 1 do
			acc = acc - 1
			local from = cam0 * V3(rr(-30, 30), rr(4, 22), -rr(45, 70))
			FX.streak(from, (cam0.RightVector * -1 + cam0.UpVector * -0.45).Unit, rr(10, 22), rr(40, 70), 0.7,
				RGB(225, 236, 255), rr(0.25, 0.5), 0.8)
		end
	end
end

-- 4.00–6.40: «Let's keep going!» — смех; из кончика помпадура бьёт голубой луч
function P3.going()
	local f = beginShot(T3.GOING)
	day3({ brightness = 2.4, tint = RGB(238, 246, 255), dof = { 6, 5, 0.25 } })
	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "laugh")
	ryu:place(CF(RYU_POS) * ANG(0, rad(170), 0))
	ryu:pose(POSE.ryuHeadBack, 0)
	ryu.bones.coat.wob = function(t)
		return ANG(rad(-10 - 4 * sin(t * 6)), 0, 0)
	end
	ryu.bones.neck.wob = function(t)
		return ANG(rad(4 * sin(t * 17)), 0, 0)
	end
	ryu:update(songT)
	local chest = ryu:point("root", V3(0, 0.8, 0))
	local cam0 = CFrame.lookAt(chest + V3(-1.0, -1.0, 6.6), chest + V3(0, 1.4, 0)) * ANG(0, 0, rad(-12))
	local cam1 = cam0 * CF(0, 0.1, -0.6)
	camCF, camFOV = cam0, 52
	-- энергия копится в причёске и уходит лучом вверх-вправо, как в аниме
	local g = SH.granite({ level = 0.3, beam = true, bolts = 5, reach = 3.2, size = 1.1 })
	g.dir = (cam0.UpVector * 0.8 + cam0.RightVector * 0.55 + cam0.LookVector * 0.35).Unit
	local gold = FX.bolt(C.gold, 0.12)
	local goldFrom = cam0 * V3(-9, -6, -9)
	local goldTo = cam0 * V3(9, 1, -7)
	local tb = 0
	Shot.update = function(u, dt)
		camCF = cam0:Lerp(cam1, smooth(u / (T3.SMOKE - T3.GOING)))
		shake = 0.15 + 0.1 * clamp01(u - 0.3)
		if floor(u * 6) % 5 == 4 then
			showVariant(ryu.tags, "mouth_", "grin")
		else
			showVariant(ryu.tags, "mouth_", "laugh")
		end
		g.level = 0.4 + 0.6 * smooth(u / 0.45)
		g.beamLen = 70 * easeOut(clamp01((u - 0.1) / 0.45))
		g.beamW = 1.6 + 0.35 * sin(u * 26)
		tb = tb - dt
		if tb <= 0 then
			tb = 0.06
			gold.strike(goldFrom, goldTo, 0.5)
		end
	end
end

-- 6.40–6.70: серые клубы дыма, вдали розовая точка
function P3.smoke()
	local f = beginShot(T3.SMOKE)
	local base = RYU_POS + V3(0, 6, 0)
	local cam0 = CFrame.lookAt(base, base + V3(0, 0, -1))
	camCF, camFOV = cam0, 50
	day3({ brightness = 2.2, tint = RGB(235, 240, 255), sat = 0.1, veil = { RGB(186, 194, 218), 0.55, 0.35 } })
	local grey = { color = RGB(176, 188, 214), shade = RGB(130, 145, 185), op = 0.9, count = 5 }
	for _ = 1, 22 do
		FX.puff(cam0 * V3(rr(-30, 30), rr(-14, 14), -rr(25, 60)), rr(12, 22), 1.2, V3(rr(-4, 4), rr(-1, 1), 0), grey)
	end
	local dot = FX.flare(cam0 * V3(4, 2, -90), 1.5, C.pinkHot, { points = 8 })
	Shot.update = function(u)
		shake = 0.1
		dot.set(nil, 1.5 + u * 12)
	end
end

-- 6.70–7.20: розовый луч проносится сквозь обломки
function P3.blast()
	local f = beginShot(T3.BLAST)
	day3({ brightness = 2.4, tint = RGB(255, 240, 252), bloom = 1.3 })
	local base = RYU_POS + V3(-10, 5, 0)
	local cam0 = CFrame.lookAt(base, base + V3(0, 0, -1)) * ANG(0, 0, rad(-10))
	camCF, camFOV = cam0, 60
	local beam = FX.energyBeam(C.pink, 5)
	local from = cam0 * V3(-40, -3, -22)
	local to = cam0 * V3(40, 3, -18)
	local acc = 0
	Shot.update = function(u, dt)
		shake = 1.4
		Shot.blur = 4
		beam.set(from, from:Lerp(to, clamp01(u / 0.12)), 5 + sin(u * 40))
		acc = acc + 90 * dt
		while acc >= 1 do
			acc = acc - 1
			local p = from:Lerp(to, rr(0, 1)) + V3(rr(-4, 4), rr(-4, 4), rr(-2, 2))
			local d = (cam0.UpVector * rr(-1, 1) + cam0.LookVector * -rr(0.2, 1) + cam0.RightVector * rr(0.3, 1)).Unit
			FX.flyer(V3(0.15, rr(0.6, 2), rr(1, 3.5)), pick({ RGB(235, 242, 255), RGB(170, 200, 250), C.pinkHot }), p, d * rr(20, 45),
				{ wedge = true, neon = rng:NextNumber() < 0.3, life = rr(0.4, 0.8), spin = 8 })
		end
	end
end

-- 7.20–7.75: Юта бежит по синему асфальту (камера у ног), в конце розовый смаз
function P3.run()
	local f = beginShot(T3.RUN)
	day3({ brightness = 2.6, dof = { 5, 4, 0.2 } })
	yuta:show(true)
	yuta:pose({ root = { -18, 0, 0 } }, 0)
	local start = YUTA_POS + V3(-6, 0, 10)
	local dir = V3(1, 0, -1).Unit
	local run = 0
	yuta.bones.rLeg.wob = function(t)
		return ANG(rad(55 * sin(t * 15)), 0, 0)
	end
	yuta.bones.lLeg.wob = function(t)
		return ANG(rad(-55 * sin(t * 15)), 0, 0)
	end
	yuta.bones.rArm.wob = function(t)
		return ANG(rad(-60 * sin(t * 15)), 0, 0)
	end
	yuta.bones.lArm.wob = function(t)
		return ANG(rad(60 * sin(t * 15)), 0, 0)
	end
	Shot.update = function(u, dt)
		run = run + dt * 20
		local pos = start + dir * run
		yuta:place(CFrame.lookAt(pos, pos + dir) * CF(0, math.abs(sin(songT * 15)) * 0.25, 0))
		local foot = pos + V3(0, 1, 0)
		camCF = CFrame.lookAt(foot + dir * -2 + dir:Cross(V3(0, 1, 0)) * 4 + V3(0, 0.6, 0), foot + dir * 1.5)
		camFOV = 60
		shake = 0.4
		local streak = clamp01((u - 0.48) / 0.07)
		Shot.blur = streak * 14
		ui.tint.BackgroundColor3 = C.pinkHot
		ui.tint.BackgroundTransparency = 1 - streak * 0.5
	end
end

-- 7.75–9.40: вид сверху: розовый луч бьёт в кратер, Рю наверху в голубой ауре,
-- внизу слева Юта бежит к нему
function P3.top()
	local f = beginShot(T3.TOP)
	day3({ brightness = 2.6, bloom = 1.0 })
	local cam0 = CFrame.lookAt(CRATER + V3(-18, 70, 40), CRATER + V3(-4, 0, 0)) * ANG(0, 0, rad(-20))
	local cam1 = CFrame.lookAt(CRATER + V3(-16, 62, 36), CRATER + V3(-4, 0, 0)) * ANG(0, 0, rad(-24))
	camCF, camFOV = cam0, 55
	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "grin")
	local rp = CRATER + V3(-6, 0, -26)
	ryu:place(CFrame.lookAt(rp, CRATER))
	ryu:pose(POSE.ryuArmsWide, 0)
	ryu:update(songT)
	local g = SH.granite({ level = 0.8, bolts = 4, reach = 5, size = 2.2 })
	yuta:show(true)
	yuta:pose({ root = { -18, 0, 0 } }, 0)
	SH.runCycle(yuta, 15, 55)
	local y0 = CRATER + V3(-34, 0, 24)
	local ydir = (rp - y0).Unit
	local beam = FX.energyBeam(C.pink, 3.2)
	local from = CRATER + V3(-50, 2, 50)
	for _ = 1, 8 do
		FX.puff(CRATER + V3(rr(10, 40), rr(2, 6), rr(-20, 30)), rr(9, 15), rr(2.5, 3.5), V3(rr(0, 3), rr(1, 2), rr(-1, 1)))
	end
	local acc, dust = 0, 0
	Shot.update = function(u, dt)
		camCF = cam0:Lerp(cam1, smooth(u / (T3.REACH - T3.TOP)))
		shake = 0.3
		beam.set(from, CRATER + V3(-2, 1, 4), 3.2 + sin(u * 30) * 0.4)
		local yp = y0 + ydir * (u * 16)
		SH.placeRunner(yuta, yp, ydir)
		dust = dust - dt
		if dust <= 0 then
			dust = 0.14
			FX.puff(yp - ydir * 1.5 + V3(0, 0.6, 0), 2.2, 0.7, V3(0, 1.5, 0) - ydir * 2, { op = 0.45 })
		end
		acc = acc + 30 * dt
		while acc >= 1 do
			acc = acc - 1
			local d = (randUnit() + V3(0, 1, 0)).Unit
			FX.spark(CRATER + V3(-2, 1, 4), d * rr(15, 35), pick({ C.pinkHot, C.white }), rr(1, 3), rr(0.3, 0.6), 0.12)
		end
	end
end

-- 9.40–12.50: из-за плеча Рю: его рука тянется вперёд, а Юта бежит на него
-- издалека справа и быстро приближается; над головой Рю голубое свечение
function P3.reach()
	local f = beginShot(T3.REACH)
	day3({ brightness = 2.5, tint = RGB(236, 244, 255), dof = { 4, 3.5, 0.15 } })
	local toY = (YUTA_POS - RYU_POS) * V3(1, 0, 1)
	toY = toY.Unit
	local side = toY:Cross(V3(0, 1, 0)).Unit -- вправо от Рю, если смотреть на Юту
	ryu:show(true)
	ryu:place(CFrame.lookAt(RYU_POS, RYU_POS + toY))
	ryu:pose({ root = { -12, 0, 0 }, neck = { -5, 0, 0 }, rArm = { 80, 0, 22 }, lArm = { -20, 0, -20 }, rLeg = { -20, 0, 0 }, lLeg = { 20, 0, 0 } }, 0)
	ryu.bones.coat.wob = function(t)
		return ANG(rad(-12 - 4 * sin(t * 6)), 0, 0)
	end
	ryu:update(songT)
	local g = SH.granite({ level = 0.55, bolts = 3, reach = 3, size = 1.2 })
	yuta:show(true)
	yuta:pose({ root = { -20, 0, 0 } }, 0)
	SH.runCycle(yuta, 16, 60)
	-- Юта выбегает справа из-за края кадра и мчится к Рю
	local y0 = RYU_POS + toY * 78 + side * 30
	local y1 = RYU_POS + toY * 16 + side * 3
	local shoulder = ryu:point("root", V3(3.4, 0.6, 6.0))
	local look = (RYU_POS + toY * 45 + side * 10 + V3(0, 2, 0) - shoulder).Unit
	local cam0 = CFrame.lookAt(shoulder, shoulder + look * 30 + V3(0, -2, 0))
	local orbit = 0
	local bolts = { FX.bolt(C.gold, 0.1), FX.bolt(C.yellow, 0.08) }
	local tb, dust = 0, 0
	local wind = {}
	local runT0, runT1 = 0.9, T3.BUT - T3.REACH
	Shot.update = function(u, dt)
		orbit = orbit + dt * 0.06
		camCF = CF(shoulder) * ANG(0, -orbit, 0) * CF(-shoulder) * cam0 * CF(0, 0, 0.6 * u)
		camFOV = 58
		shake = 0.2
		local k = clamp01((u - runT0) / (runT1 - runT0))
		local yp = y0:Lerp(y1, k * (0.75 + 0.25 * k))
		SH.placeRunner(yuta, yp, y1 - y0, 16)
		yuta:show(u > runT0 - 0.05)
		dust = dust - dt
		if u > runT0 and dust <= 0 then
			dust = 0.1
			FX.puff(yp - (y1 - y0).Unit * 1.2 + V3(0, 0.5, 0), 2.4, 0.8, V3(0, 1.2, 0) + (y0 - y1).Unit * 3, { op = 0.5 })
		end
		tb = tb - dt
		if tb <= 0 then
			tb = 0.07
			-- жёлтые молнии стелются над землёй между ними
			local a = RYU_POS + toY * rr(18, 60) + side * rr(-14, 14) + V3(0, rr(0.5, 4), 0)
			for _, b in ipairs(bolts) do
				b.strike(a, a + (side * rr(-1, 1) + toY * rr(-0.6, 0.6)).Unit * rr(10, 24) + V3(0, rr(-1, 2), 0), 1.1)
			end
		end
		windStreaks(camCF, dt, wind, 0.08, (camCF.RightVector * -1).Unit)
	end
end

-- 12.50–13.90: «But...» — ухмылка, в кончике помпадура голубое сияние
function P3.but()
	local f = beginShot(T3.BUT)
	day3({ brightness = 2.3, tint = RGB(232, 244, 255), dof = { 5.2, 4, 0.3 } })
	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "smirk")
	ryu:place(CF(RYU_POS) * ANG(0, rad(140), 0))
	ryu:pose({ root = { -4, 0, 0 }, neck = { -6, 20, 0 }, rArm = { 30, 0, 30 }, lArm = { 10, 0, -10 } }, 0)
	ryu:update(songT)
	local head = ryu:point("neck", V3(0, 0.7, 0))
	local camPos = ryu:point("neck", V3(1.3, 0.1, -4.2))
	local cam0 = CFrame.lookAt(camPos, head + V3(0, -0.4, 0)) * ANG(0, 0, rad(6))
	local cam1 = cam0 * CF(0, 0, -0.4)
	camCF, camFOV = cam0, 50
	local g = SH.granite({ level = 0.5, bolts = 4, reach = 2.4, size = 0.8 })
	local gold = FX.bolt(C.gold, 0.06)
	local tb = 0
	Shot.update = function(u, dt)
		camCF = cam0:Lerp(cam1, smooth(u / (T3.BOOM - T3.BUT)))
		shake = 0.1
		if u > 0.7 then
			showVariant(ryu.tags, "mouth_", "grin")
		end
		g.level = 0.5 + 0.4 * smooth(u / 1.2)
		tb = tb - dt
		if tb <= 0 then
			tb = 0.07
			gold.strike(cam0 * V3(-4, -3, -5), cam0 * V3(1, -1.5, -5), 0.3)
		end
	end
end

-- 13.90–14.80: жёлто-розовый взрыв
function P3.boom()
	local f = beginShot(T3.BOOM)
	setLook({ clock = 13, brightness = 1.6, ambient = RGB(200, 170, 230), tint = RGB(255, 245, 250), sat = 0.45, contrast = 0.1, bloom = 1.4, bloomSize = 50 })
	local S0 = STAGE.zoom + V3(0, 0, 600)
	local cam0 = CFrame.lookAt(S0 + V3(0, 0, 32), S0)
	camCF, camFOV = cam0, 70
	FX.backdrop(CF(S0 + V3(0, 0, -150)) * ANG(0, math.pi, 0), 900, 600, { RGB(120, 60, 180), RGB(60, 40, 130), RGB(30, 20, 80) }, 30)
	local core = FX.flare(S0, 8, C.pinkHot, { points = 12 })
	local rays = FX.rays(S0, 30, { C.yellow, C.gold, C.pinkHot, C.white }, 20, 70, 3, { brightness = 3, colorStart = true, start = 4 })
	ryu:show(true)
	ryu:place(CFrame.lookAt(S0 + V3(10, -4, -8), S0 + V3(-10, -4, -8)))
	ryu:pose(POSE.ryuSide, 0)
	ryu:update(songT)
	Shot.update = function(u, dt)
		camCF = cam0 * CF(0, 0, -4 * u)
		shake = 1.4
		Shot.blur = 3
		core.set(nil, 8 * (1 + 0.5 * u))
		rays.update(u)
		if floor(u * 10) ~= floor((u - dt) * 10) then
			rays.reroll(0.4)
		end
		ryu:show(u < 0.12)
		for _ = 1, 2 do
			local d = (randUnit() * V3(1, 0.6, 0.3)).Unit
			FX.streak(S0 + d * 3, d, rr(12, 26), rr(90, 150), 0.4, pick({ C.yellow, C.gold, C.pinkHot }), rr(0.6, 1.4), 4)
		end
		local fl = math.max(0, 1 - abs(u - 0.35) * 6)
		ui.flash.BackgroundTransparency = 1 - fl * 0.6
	end
end

-- Сцена «its force is weak!» (14.80 части 3 → 0.73 части 4, одна непрерывная сцена):
-- Рю справа спиной тянет руку, из причёски бьют молнии; сквозь сиреневый туман
-- и розовые искры к нему бежит Юта. tau0 — с какого места сцены начинать.
-- путь Юты в этой сцене: tau — время сцены, возвращает точку и направление бега
function P3.weakPath(tau)
	local toY = ((YUTA_POS - RYU_POS) * V3(1, 0, 1)).Unit
	local side = toY:Cross(V3(0, 1, 0)).Unit
	local y0 = RYU_POS + toY * 46 - side * 5
	local y1 = RYU_POS + toY * 10
	return y0:Lerp(y1, clamp01(tau / 3.2)), (y1 - y0).Unit, toY, side
end

function P3.weakScene(t0, tau0)
	local f = beginShot(t0)
	Shot.scene = "weak"
	day3({ brightness = 2.0, tint = RGB(240, 236, 255), sat = 0.2, dof = { 9, 6, 0.25 },
		haze = 0.34, hazeColor = RGB(214, 206, 242), hazeDecay = RGB(160, 150, 220), veil = { RGB(204, 196, 240), 0.92, 0.72 } })
	local toY = ((YUTA_POS - RYU_POS) * V3(1, 0, 1)).Unit
	local side = toY:Cross(V3(0, 1, 0)).Unit
	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "grin")
	ryu:place(CFrame.lookAt(RYU_POS, RYU_POS + toY))
	ryu:pose(POSE.ryuReach, 0)
	ryu.bones.coat.wob = function(t)
		return ANG(rad(-10 - 4 * sin(t * 6)), 0, 0)
	end
	ryu:update(songT)
	local g = SH.granite({ level = 0.75, bolts = 5, reach = 5, size = 1.3 })
	yuta:show(true)
	SH.yutaBlood(true)
	yuta:pose({ root = { -20, 0, 0 } }, 0)
	SH.runCycle(yuta, 16, 60)
	-- камера за спиной Рю со стороны левого плеча: Рю справа, Юта вдали слева
	local eye = RYU_POS - side * 4.2 - toY * 7 + V3(0, 4.2, 0)
	local cam0 = CFrame.lookAt(eye, RYU_POS + toY * 40 - side * 6 + V3(0, 2.5, 0))
	camCF, camFOV = cam0, 55
	-- сиреневый туман: дальняя стена, слой между ними и низкая пелена у земли
	local face = CFrame.lookAt(V3(), toY)
	FX.mist(CF(RYU_POS + toY * 62 + V3(0, 7, 0)) * face, V3(110, 16, 50), 30, RGB(222, 214, 246), 0.6,
		{ sizes = { 22, 40 }, shade = RGB(196, 186, 236), drift = side * 1.2, seed = 41, t0 = tau0 })
	FX.mist(CF(RYU_POS + toY * 32 + V3(0, 3, 0)) * face, V3(70, 6, 36), 26, RGB(228, 220, 248), 0.5,
		{ sizes = { 12, 22 }, shade = RGB(204, 194, 240), drift = side * 1.0, seed = 42, t0 = tau0 })
	FX.mist(CF(RYU_POS + toY * 12 + V3(0, 0.8, 0)) * face, V3(36, 2, 18), 14, RGB(236, 230, 252), 0.45,
		{ sizes = { 7, 13 }, drift = side * 0.8, seed = 43, t0 = tau0 })
	local hand = ryu:point("rArm", V3(0, -1.6, 0))
	local hf = FX.flare(hand, 0.9, C.cyan, { points = 8, alpha = 0.2 })
	local hb = { FX.bolt(C.cyan, 0.05), FX.bolt(RGB(200, 255, 255), 0.04) }
	local sparks, tb, dust = {}, 0, 0
	local sparkDir = (side * 1 + toY * -0.35 + V3(0, 0.25, 0)).Unit
	Shot.update = function(u, dt)
		local tau = u + tau0
		camCF = cam0 * CF(0.3 * tau, 0, -0.5 * tau)
		shake = 0.2
		local yp, ydir = P3.weakPath(tau)
		SH.placeRunner(yuta, yp, ydir, 16)
		hf.set(hand, 0.9 * (1 + 0.25 * sin(tau * 18)))
		g.level = 0.75 + 0.15 * sin(tau * 9)
		tb = tb - dt
		if tb <= 0 then
			tb = 0.06
			hb[1].strike(hand, hand + toY * rr(3, 6) + V3(rr(-1, 1), rr(-1, 2), 0), 0.5)
			hb[2].strike(hand, hand + (toY + V3(0, 1, 0)).Unit * rr(2, 5), 0.4)
		end
		dust = dust - dt
		if dust <= 0 then
			dust = 0.11
			FX.puff(yp - ydir * 1.2 + V3(0, 0.5, 0), 2.6, 0.9, V3(0, 1.2, 0), { op = 0.4, color = RGB(236, 232, 252) })
		end
		SH.pinkSparks(camCF, dt, sparks, 0.018, sparkDir)
	end
end

-- 14.80–15.97: «its force is weak!»
function P3.weak()
	P3.weakScene(T3.WEAK, 0)
end

P3.shots = {
	{ 0, P3.approach }, { T3.RIGHT, P3.right }, { T3.GOING, P3.going }, { T3.SMOKE, P3.smoke }, { T3.BLAST, P3.blast },
	{ T3.RUN, P3.run }, { T3.TOP, P3.top }, { T3.REACH, P3.reach }, { T3.BUT, P3.but }, { T3.BOOM, P3.boom }, { T3.WEAK, P3.weak },
}
P3.fin = T3.FIN

-- субтитры части 3
P3.subs = {
	{ 2.50, 3.98, "That's right!", "Вот именно!" },
	{ 4.00, 6.30, "Let's keep going!", "Продолжаем!" },
	{ 9.85, 12.45, "That big thing can fire it on its own?!", "Эта громадина может стрелять сама?!" },
	{ 12.60, 13.85, "But...", "Но..." },
	{ 14.62, 15.97, "its force is weak!", "её сила слаба!" },
}
