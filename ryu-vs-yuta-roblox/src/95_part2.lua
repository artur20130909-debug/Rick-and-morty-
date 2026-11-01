----------------------------------------------------------------------
-- ЧАСТЬ 2 (0:00–0:15)
----------------------------------------------------------------------

local P2 = {}
local RAINBOW = { C.pink, C.cyan, C.yellow, C.orange, C.blue, C.white, C.pinkHot }

-- радужный взрыв: лучи, колючие вспышки, цветной дым, искры, осколки летят в камеру
local function rainbowBurst(P, cam0, scale)
	local rays = FX.rays(P, 40, RAINBOW, 18 * scale, 70 * scale, 2.4 * scale, { brightness = 2.5, colorStart = true, start = 5 })
	local core = FX.flare(P, 6 * scale, RGB(255, 235, 250), { points = 11 })
	local fills = {}
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2
		local off = (cam0.RightVector * cos(a) + cam0.UpVector * sin(a)) * rr(10, 18) * scale
		fills[i] = FX.flare(P + off, rr(8, 12) * scale, RAINBOW[i], { points = 7, alpha = 0.35, spin = rr(-0.8, 0.8) })
	end
	local bolts = { FX.bolt(C.cyan, 0.15), FX.bolt(C.pinkHot, 0.15), FX.bolt(C.yellow, 0.12) }
	local toCam = (cam0.Position - P).Unit
	local obj = { rays = rays, core = core }
	local acc, sp, pf, tb = 0, 0, 0, 0
	local cloudCols = {
		{ color = RGB(255, 205, 240), shade = RGB(236, 140, 210) },
		{ color = RGB(205, 248, 255), shade = RGB(120, 205, 245) },
		{ color = RGB(255, 245, 200), shade = RGB(240, 200, 120) },
	}
	function obj.update(u, dt, rate)
		rays.update(u)
		if floor(u * 8) ~= floor((u - dt) * 8) then
			rays.reroll(0.3)
		end
		core.set(nil, 6 * scale * (1 + 0.15 * sin(u * 30)))
		tb = tb - dt
		if tb <= 0 then
			tb = 0.06
			for _, b in ipairs(bolts) do
				b.strike(P, P + randUnit() * rr(20, 45) * scale, 2.5 * scale)
			end
		end
		sp = sp + 140 * dt
		while sp >= 1 do
			sp = sp - 1
			local d = randUnit()
			FX.spark(P + d * rr(1, 4), d * rr(50, 110) * scale, pick(RAINBOW), rr(2, 6) * scale, rr(0.25, 0.5), 0.14 * scale)
		end
		pf = pf + 8 * dt
		while pf >= 1 do
			pf = pf - 1
			local d = randUnit()
			if d:Dot(toCam) > -0.2 then
				d = (d - toCam * (d:Dot(toCam) + 0.6)).Unit
			end
			FX.puff(P + d * rr(12, 22) * scale, rr(6, 11) * scale, rr(1.2, 1.8), d * rr(6, 12) * scale, pick(cloudCols))
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
	setLook({ clock = 13, brightness = 1.5, ambient = RGB(150, 150, 200), tint = RGB(250, 245, 255), sat = 0.5, contrast = 0.15,
		bloom = 1.3, bloomSize = 44, bloomThreshold = 0.8 })
	local S0 = STAGE.vortex
	local cam0 = CFrame.lookAt(S0 + V3(0, 0, 34), S0)
	camCF, camFOV = cam0, 75
	FX.backdrop(CF(S0 + V3(0, 0, -160)) * ANG(0, math.pi, 0), 900, 600, { RGB(70, 90, 210), RGB(140, 60, 190), RGB(40, 40, 130) }, 45)
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
	setLook({ clock = 13, brightness = 1.4, ambient = RGB(190, 215, 230), outdoor = RGB(185, 212, 230), tint = RGB(235, 248, 255),
		sat = 0.22, contrast = 0.14, bright = 0.04, bloom = 1.0, dof = { 5.8, 4, 0.4 } })
	local S0 = STAGE.laugh
	local cam0 = CFrame.lookAt(S0, S0 + V3(0, -0.02, -1))
	local cam1 = cam0 * CF(-0.12, 0.03, -0.7)
	camCF, camFOV = cam0, 40
	FX.backdrop(cam0 * CF(0, 0, -200) * ANG(0, math.pi, 0), 700, 500, { RGB(110, 210, 225), RGB(40, 120, 150), RGB(20, 60, 90) }, 60)
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

	-- энергия Рю бьёт из кончика помпадура: свет уходит вверх-вправо, как в аниме
	local g = SH.granite({ level = 0.6, bolts = 4, reach = 2.6, size = 1.0, beam = true })
	g.dir = (cam0.UpVector * 0.85 + cam0.RightVector * 0.5 - cam0.LookVector * 0.1).Unit
	local schedule = { { 0, "smirk" }, { 0.8, "grin" }, { 1.2, "laugh" }, { 2.5, "grin" }, { 3.1, "smirk" }, { 3.8, "grin" } }
	local current = ""
	local tb, tw = 0, 0
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
		g.level = 0.6 + 0.4 * smooth(u / 1.2)
		g.beamLen = 40 * easeOut(clamp01((u - 0.3) / 0.6))
		g.beamW = 0.9 + 0.25 * sin(u * 24)
		tw = tw - dt
		if tw <= 0 then
			tw = 0.1
			FX.twinkle(cam0 * V3(rr(-4, 4), rr(-2, 3), -rr(6, 9)), rr(0.12, 0.25), RGB(170, 245, 255), rr(0.5, 0.9))
		end
	end
end

-- 7.90–8.55: радужный рывок вперёд
function P2.zoom()
	beginShot(T2.ZOOM)
	setLook({ clock = 13, brightness = 1.5, ambient = RGB(150, 150, 200), tint = RGB(255, 248, 255), sat = 0.5, contrast = 0.12, bloom = 1.4, bloomSize = 50 })
	local S0 = STAGE.zoom
	local cam0 = CFrame.lookAt(S0 + V3(0, 0, 60), S0)
	camCF, camFOV = cam0, 80
	FX.backdrop(CF(S0 + V3(0, 0, -200)) * ANG(0, math.pi, 0), 900, 600, { RGB(120, 70, 210), RGB(50, 60, 160) }, 90)
	local core = FX.flare(S0, 5, RGB(255, 240, 200), { points = 10 })
	local zrays = FX.rays(S0, 34, RAINBOW, 30, 90, 3, { brightness = 2.5, colorStart = true, start = 6 })
	Shot.update = function(u, dt)
		camCF = cam0 * CF(0, 0, -50 * easeIn(u / (T2.IMPACT1 - T2.ZOOM))) * ANG(0, 0, rad(u * 25))
		camFOV = lerp(80, 95, u / 0.65)
		Shot.blur = 9
		shake = 1
		core.set(nil, 5 + u * 14)
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
		ui[key].Visible = true
	end
end
P2.impact1 = impactShot(T2.IMPACT1, "impact1")
P2.impact2 = impactShot(T2.IMPACT2, "impact2")

-- 8.65–9.20: жёлтый взрыв, потом смаз с силуэтом Юты
function P2.burst()
	beginShot(T2.BURST)
	setLook({ clock = 13, brightness = 1.5, ambient = RGB(255, 210, 230), tint = RGB(255, 248, 235), sat = 0.45, contrast = 0.1, bloom = 1.4, bloomSize = 50 })
	local S0 = STAGE.zoom + V3(0, 0, -500)
	local cam0 = CFrame.lookAt(S0 + V3(0, 0, 30), S0)
	camCF, camFOV = cam0, 70
	FX.backdrop(CF(S0 + V3(0, 0, -150)) * ANG(0, math.pi, 0), 900, 600, { RGB(255, 150, 220), RGB(90, 180, 255), RGB(255, 225, 130) }, 30)
	local burst = rainbowBurst(S0, cam0, 0.8)
	local yellow = FX.flare(S0, 7, C.yellow, { points = 12 })
	yuta:show(true)
	yuta:place(cam0 * CF(9, -4, -12) * ANG(0, rad(130), 0))
	yuta:pose(POSE.yutaOrb, 0)
	yuta:update(songT)
	Shot.update = function(u, dt)
		camCF = cam0 * CF(0, 0, -6 * u) * ANG(0, 0, rad(-6 * u))
		shake = 1.2
		burst.update(u, dt, 50)
		yellow.set(nil, 7 * (1 + 0.3 * sin(u * 25)))
		local blurPhase = clamp01((u - (T2.BLUR - T2.BURST)) / 0.08)
		Shot.blur = lerp(3, 20, blurPhase)
		yuta:show(blurPhase > 0)
		updateSpeedLines(0.5 * (1 - blurPhase), u)
	end
end

-- 9.20–9.55: Юта с голубым сгустком, над ним огромная Рика
function P2.yutaRika()
	local f = beginShot(T2.YUTARIKA)
	setLook({ clock = 13, brightness = 1.5, ambient = RGB(215, 205, 245), outdoor = RGB(205, 200, 240), tint = RGB(245, 242, 255),
		sat = 0.3, contrast = 0.13, bloom = 1.1, dof = { 9.5, 7, 0.3 } })
	local base = STAGE.yuta2
	local cam0 = CFrame.lookAt(base, base + V3(0, 0.1, -1))
	local cam1 = cam0 * CF(0.2, 0, -0.5)
	camCF, camFOV = cam0, 56
	FX.backdrop(cam0 * CF(0, 0, -240) * ANG(0, math.pi, 0), 900, 600, { RGB(190, 170, 250), RGB(110, 90, 200), RGB(60, 50, 140) }, 110)
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
	local flare = FX.flare(orb, 2.2, C.cyan, { points = 10 })
	local rays = FX.rays(orb, 14, { C.cyan, C.white, RGB(160, 240, 255) }, 1.5, 6, 0.35)
	local tStreak, tSp = 0, 0
	Shot.update = function(u, dt)
		camCF = cam0:Lerp(cam1, smooth(u / 0.35))
		shake = 0.3
		flare.set(nil, 2.2 * (1 + 0.2 * sin(u * 30)))
		rays.update(u)
		tSp = tSp - dt
		if tSp <= 0 then
			tSp = 0.02
			local d = randUnit()
			FX.spark(orb, d * rr(10, 20), pick({ C.cyan, C.white }), rr(0.6, 1.2), rr(0.2, 0.35), 0.05)
		end
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
	setLook({ clock = 13, brightness = 1.5, ambient = RGB(190, 220, 250), outdoor = RGB(185, 215, 250), tint = RGB(232, 244, 255),
		sat = 0.25, contrast = 0.14, bloom = 1.0, dof = { 3.2, 2.2, 0.45 } })
	local base = STAGE.yuta2 + V3(0, 0, -300)
	local cam0 = CFrame.lookAt(base, base + V3(0, 0, -1))
	local cam1 = cam0 * CF(0.05, 0, -0.35)
	camCF, camFOV = cam0, 42
	FX.backdrop(cam0 * CF(0, 0, -200) * ANG(0, math.pi, 0), 700, 500, { RGB(150, 210, 255), RGB(60, 130, 235), RGB(30, 70, 170) }, 60)
	yuta:show(true)
	yuta:place(cam0 * CF(0.35, -4.55, -3.2) * ANG(0, rad(150), 0))
	yuta:pose({ root = { -2, 0, 0 }, neck = { -6, 22, 0 }, lArm = { 20, 0, -10 }, rArm = { 10, 0, 10 } }, 0)
	yuta:update(songT)
	rika:show(true)
	rika:pose(POSE.rikaHand, 0)
	local handAt = cam0 * CF(-2.3, -0.4, -5.6) * ANG(math.pi, 0, rad(-14))
	placeBoneAt(rika, "haL", handAt)
	local fireAt = cam0 * V3(-1.9, -0.9, -4)
	FX.flame(fireAt, 1.4, C.cyan, 8)
	local flare = FX.flare(fireAt + V3(0, 0.6, 0), 0.9, C.cyan, { points = 9, alpha = 0.2 })
	Shot.update = function(u, dt)
		camCF = cam0:Lerp(cam1, smooth(u / (T2.WHITE - T2.YUTACLOSE)))
		shake = 0.12
		flare.set(nil, 0.9 * (1 + 0.2 * sin(u * 20)))
		ui.flash.BackgroundTransparency = 1 - clamp01((u - 0.45) / 0.15)
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

-- 10.40–13.03: поле с кратером при ярком дне, Рю стоит сбоку, ветер несёт пыль
function P2.wide()
	local f = beginShot(T2.MIST)
	setLook({ clock = 13, brightness = 2.4, exposure = 0.15, ambient = RGB(150, 165, 200), outdoor = RGB(160, 176, 210),
		fogColor = RGB(200, 220, 250), fogStart = 450, fogEnd = 2600, tint = RGB(245, 250, 255), sat = 0.3, contrast = 0.12, bloom = 0.8 })
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
	-- пыль из кратера: мультяшные клубы, ветер несёт их влево
	for _ = 1, 12 do
		FX.puff(CRATER + V3(rr(-14, 14), rr(1, 6), rr(-9, 9)), rr(6, 11), rr(2.4, 3.2), V3(-rr(2, 5), rr(0.5, 2), rr(-1, 1)))
	end
	local tStreak, tFlake, tPuff = 0, 0, 0
	Shot.update = function(u, dt)
		local k = smooth(u / (T2.LOW - T2.MIST))
		camCF = cam0:Lerp(cam1, k)
		shake = 0.08
		local m = clamp01(u / (T2.WIDE - T2.MIST))
		ui.flash.BackgroundColor3 = RGB(235, 242, 255)
		ui.flash.BackgroundTransparency = lerp(0.05, 1, easeOut(m))
		Shot.blur = lerp(14, 0, m)
		tStreak = tStreak - dt
		if tStreak <= 0 then
			tStreak = 0.09
			local from = FIELD + V3(rr(12, 26), rr(3, 9), rr(-4, 6))
			FX.streak(from, V3(-1, rr(-0.05, 0.12), rr(-0.1, 0.1)).Unit, rr(6, 12), rr(30, 45), 0.9, RGB(250, 252, 255), rr(0.25, 0.6), 2)
		end
		tFlake = tFlake - dt
		if tFlake <= 0 then
			tFlake = 0.06
			FX.flyer(V3(rr(0.4, 1.2), rr(0.3, 0.8), 0.08), RGB(250, 252, 255), CRATER + V3(rr(-10, 10), rr(2, 10), rr(-8, 8)),
				V3(-rr(20, 35), rr(-2, 4), rr(-3, 3)), { life = rr(0.8, 1.4), spin = 6 })
		end
		tPuff = tPuff - dt
		if tPuff <= 0 then
			tPuff = 0.35
			FX.puff(CRATER + V3(rr(-12, 12), rr(1, 5), rr(-8, 8)), rr(5, 9), rr(2.2, 3), V3(-rr(2, 5), rr(0.5, 2), 0))
		end
	end
end

-- 13.03–15.39: Рю снизу, ухмылка, ветер и голубое пламя
function P2.low()
	local f = beginShot(T2.LOW)
	setLook({ clock = 13, brightness = 2.6, exposure = 0.2, ambient = RGB(170, 182, 212), outdoor = RGB(180, 192, 222), fogColor = RGB(200, 220, 250),
		fogStart = 600, fogEnd = 4000, tint = RGB(240, 246, 255), sat = 0.12, contrast = 0.12, bloom = 0.7, dof = { 5.5, 4, 0.2 } })
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
	local flameAt = chest + V3(3.2, -0.5, -0.5)
	local flame = FX.flame(flameAt, 2.4, C.cyan, 9)
	local flare = FX.flare(flameAt + V3(0, 1.2, 0), 1.4, C.cyan, { points = 9, alpha = 0.2 })
	local bolts = { FX.bolt(C.cyan, 0.06), FX.bolt(RGB(200, 255, 255), 0.05) }
	local tStreak, tb = 0, 0
	Shot.update = function(u, dt)
		camCF = cam0:Lerp(cam1, smooth(u / (T2.FIN - T2.LOW)))
		shake = 0.12
		local e = clamp01((u - 0.3) / 0.15) * (1 - clamp01((u - 1.25) / 0.2))
		flame.k = e
		flare.set(nil, 1.4 * e * (1 + 0.2 * sin(u * 16)))
		tb = tb - dt
		if tb <= 0 then
			tb = 0.08
			for _, b in ipairs(bolts) do
				b.show(e > 0.1)
				b.strike(flameAt + V3(0, rr(-1, 2), 0), flameAt + V3(rr(-2, 2), rr(2, 5), rr(-1, 1)), 0.6)
			end
		end
		local windy = clamp01((u - 1.35) / 0.2)
		tStreak = tStreak - dt
		if tStreak <= 0 then
			tStreak = lerp(0.07, 0.03, windy)
			local from = chest + cam0.RightVector * rr(4, 9) + cam0.UpVector * rr(-2, 7) - cam0.LookVector * rr(-2, 3)
			local col = RGB(245, 250, 255)
			if windy > 0.5 then
				col = RGB(215, 220, 232)
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

-- субтитры части 2: { начало, конец, английский как в клипе, русский }
P2.subs = {
	{ 3.95, 7.85, "That was seriously sweet, Okkotsu!", "Это было круто, Оккоцу!" },
}
