----------------------------------------------------------------------
-- ЧАСТЬ 1 (0:00–0:11)
----------------------------------------------------------------------

local P1 = {}

-- яркий дневной свет поля боя (меняется по кадрам только оттенком)
local function dayLook(o)
	o = o or {}
	setLook({
		clock = 13, brightness = o.brightness or 2.4, exposure = o.exposure or 0.15,
		ambient = o.ambient or RGB(150, 165, 200), outdoor = o.outdoor or RGB(160, 176, 210),
		fogColor = RGB(200, 220, 250), fogStart = o.fogStart or 450, fogEnd = o.fogEnd or 2600,
		tint = o.tint or RGB(245, 250, 255), sat = o.sat or 0.3, contrast = o.contrast or 0.12, bright = o.bright or 0.03,
		bloom = o.bloom or 0.9, bloomSize = 40, bloomThreshold = o.threshold or 0.9, dof = o.dof,
	})
end

-- кадр с глазами: перед выстрелом оба напрягаются и сосредотачиваются
function P1.eyes()
	beginShot(0)
	setLook({ clock = 12, brightness = 0, ambient = C.white, outdoor = C.white, fogStart = 100000, fogEnd = 100001,
		bloom = 0.2, bloomThreshold = 0.97, sat = 0.08, contrast = 0.05 })
	local S0 = STAGE.eyes
	local cam0 = CFrame.lookAt(S0 + V3(0, 0, -EYES.camDist), S0)
	camCF, camFOV = cam0, 20
	EYES.tension(0, 0)
	Shot.update = function(u)
		local k = smooth(u / T1.WHITE)
		camFOV = lerp(20, 18.6, k)
		local tense = smooth((u - 1.3) / 2.7)
		EYES.tension(tense, songT)
		local j = 0.03 + 0.14 * tense
		camCF = cam0 * CF(noise(u * 6, 1.1) * j, noise(u * 6, 2.2) * j, 0)
		local g = easeIn(clamp01((u - T1.GLOW) / (T1.WHITE - T1.GLOW)))
		ui.washTop.BackgroundTransparency = 1 - g * 0.9
		ui.washBottom.BackgroundTransparency = 1 - g * 0.9
		ui.flash.BackgroundTransparency = 1 - easeIn(clamp01((u - 4.6) / (T1.WHITE - 4.6)))
	end
end

-- 4.83–7.83: вспышка и столкновение лучей; Рика справа сверху бьёт из пасти
function P1.clash()
	local f = beginShot(T1.WHITE)
	dayLook({ tint = RGB(238, 255, 250), sat = 0.35, bloom = 1.2, threshold = 0.85 })
	ui.flashGrad.Color = CS({ { 0, RGB(110, 240, 180) }, { 0.5, C.white }, { 1, RGB(255, 140, 215) } })
	ui.flashGrad.Rotation = 15
	ui.flash.BackgroundTransparency = 0
	local P = CLASH_POINT
	local cam0 = CFrame.lookAt(P + V3(-15, -7, -38), P + V3(1, 2, 0)) * ANG(0, 0, rad(-8))
	local cam1 = CFrame.lookAt(P + V3(-12, -6, -31), P + V3(1, 2.5, 0)) * ANG(0, 0, rad(-10))
	camCF, camFOV = cam0, 72

	local rp = cam0 * V3(64, 24, -66)
	rika:show(true)
	rika:place(CFrame.lookAt(rp, V3(P.X, rp.Y, P.Z)))
	rika:pose(POSE.rikaFire, 0)
	rika:update(songT)
	newPart(f, V3(32, 80, 28), GROUND:Lerp(RGB(30, 50, 130), 0.5), CF(rp.X, rp.Y - 14 - 40, rp.Z + 4) * ANG(0, rad(20), 0))

	local pink = FX.energyBeam(C.pink, 2.2)
	local cyan = FX.energyBeam(C.cyan, 2.8)
	local cyanFrom = cam0 * V3(-34, -19, -20)
	local core = FX.flare(P, 9, C.yellow, { points = 10 })
	local coreP = FX.flare(P + cam0.RightVector * 2, 6, C.pinkHot, { points = 7, alpha = 0.3, spin = -0.6 })
	local coreC = FX.flare(P - cam0.RightVector * 2, 6, C.cyan, { points = 7, alpha = 0.3, spin = 0.7 })
	local rays = FX.rays(P, 22, { C.yellow, C.white, C.pinkHot, C.cyan, C.gold }, 10, 34, 1.6)
	local bolts = { FX.bolt(C.cyan, 0.12), FX.bolt(C.yellow, 0.1), FX.bolt(RGB(230, 255, 255), 0.1), FX.bolt(C.white, 0.08) }
	-- клубы дыма вокруг столкновения (мультяшные, с контуром)
	for _ = 1, 10 do
		local d = randUnit()
		FX.puff(P + d * rr(10, 18) + V3(0, -4, 0), rr(7, 12), rr(2.5, 3.2), d * rr(1, 3) + V3(0, 1, 0))
	end

	local toCam = (cam0.Position - P).Unit
	local function spawn(kind)
		local dir = (toCam * 0.9 + V3(rr(-1, 1), rr(-0.7, 1), rr(-1, 1))).Unit
		if kind == "shard" then
			FX.flyer(V3(0.15, rr(0.8, 2.8), rr(1.2, 4.5)), pick({ C.yellow, C.gold, RGB(255, 246, 205) }), P + dir * rr(2, 5), dir * rr(28, 62),
				{ neon = true, wedge = true, life = rr(0.55, 1.0), spin = 9 })
		elseif kind == "rock" then
			FX.flyer(V3(rr(0.7, 2.6), rr(0.6, 2.2), rr(0.7, 2.6)), GROUND:Lerp(RGB(30, 40, 90), 0.5), P + dir * rr(3, 6), dir * rr(18, 40),
				{ life = rr(0.9, 1.4), spin = 5, gravity = 18 })
		elseif kind == "teal" then
			FX.flyer(V3(0.12, rr(0.6, 1.8), rr(0.8, 2.6)), RGB(120, 245, 228), P + dir * rr(4, 10), dir * rr(22, 48),
				{ neon = true, wedge = true, life = 0.9, spin = 7 })
		elseif kind == "spark" then
			local d = randUnit()
			FX.spark(P + d * rr(1, 3), d * rr(40, 90), pick({ C.yellow, C.white, C.pinkHot, C.cyan }), rr(2, 5), rr(0.25, 0.5), 0.14)
		elseif kind == "puff" then
			local d = (randUnit() + V3(0, 0.3, 0)).Unit
			FX.puff(P + d * rr(8, 14), rr(5, 9), rr(1.6, 2.4), d * rr(4, 9))
		end
	end

	local acc = { shard = 0, rock = 0, teal = 0, spark = 0, puff = 0 }
	local tBolt, tRing, tReroll = 0, 0, 0
	local teal = nil
	local w = T1.CLASH - T1.WHITE
	Shot.update = function(u, dt)
		local k = smooth(u / (T1.CITY - T1.WHITE))
		camCF = cam0:Lerp(cam1, k)
		camFOV = lerp(72, 64, k)
		if u < w then
			ui.flash.BackgroundTransparency = lerp(0, 0.5, u / w)
			Shot.blur = lerp(24, 5, u / w)
			shake = 1.7
		else
			ui.flash.BackgroundTransparency = clamp01(0.5 + (u - w) * 3.5)
			Shot.blur = math.max(0, 5 - (u - w) * 30)
			shake = 0.8 + 0.25 * sin(u * 31)
		end
		pink.set(rika.mouth(), P, 2.1 + sin(u * 50) * 0.3)
		cyan.set(cyanFrom, P, 2.8 + sin(u * 43 + 1) * 0.4)
		core.set(nil, 9 * (1 + sin(u * 40) * 0.12))
		rays.update(u)
		tReroll = tReroll - dt
		if tReroll <= 0 then
			tReroll = 0.12
			rays.reroll(0.25)
		end
		tBolt = tBolt - dt
		if tBolt <= 0 then
			tBolt = 0.05
			for _, b in ipairs(bolts) do
				b.strike(P, P + randUnit() * rr(16, 34), 1.8)
			end
		end
		tRing = tRing - dt
		if tRing <= 0 then
			tRing = 0.3
			FX.ring(P, C.white, 4, 30, 0.45, 0.7)
		end
		local late = u > (T1.TEAL - T1.WHITE)
		local rates = { shard = 40, rock = 12, teal = 0, spark = 120, puff = 5 }
		if u < w then
			rates = { shard = 16, rock = 4, teal = 0, spark = 60, puff = 2 }
		elseif late then
			rates = { shard = 18, rock = 6, teal = 45, spark = 90, puff = 6 }
		end
		for kind, rate in pairs(rates) do
			acc[kind] = acc[kind] + rate * dt
			while acc[kind] >= 1 do
				acc[kind] = acc[kind] - 1
				spawn(kind)
			end
		end
		if late then
			local g = clamp01((u - (T1.TEAL - T1.WHITE)) / (T1.CITY - T1.TEAL))
			if not teal then
				teal = FX.flare(P, 10, C.teal, { points = 12, alpha = 0.25 })
			end
			teal.set(nil, lerp(10, 60, easeOut(g)))
			ui.tint.BackgroundColor3 = RGB(110, 240, 220)
			ui.tint.BackgroundTransparency = lerp(1, 0.45, g)
			shake = lerp(0.9, 1.7, g)
		end
	end
end

-- 7.83–8.70: общий план: над полем встаёт розово-голубой взрыв
function P1.city()
	local f = beginShot(T1.CITY)
	dayLook({ tint = RGB(242, 246, 255), bloom = 1.0 })
	local P = CLASH_POINT + V3(0, -4, 0)
	local cam0 = CFrame.lookAt(CITY_CAM, P + V3(0, 26, 0))
	local cam1 = CFrame.lookAt(CITY_CAM + (P - CITY_CAM).Unit * 16, P + V3(0, 27, 0))
	camCF, camFOV = cam0, 46
	local right, up = cam0.RightVector, cam0.UpVector
	local pinkC = { color = RGB(255, 205, 240), shade = RGB(236, 140, 210) }
	local cyanC = { color = RGB(205, 248, 255), shade = RGB(120, 205, 245) }
	for i = 1, 24 do
		local side = (i % 2 == 0) and 1 or -1
		local pos = P + right * side * rr(4, 26) + up * rr(4, 40)
		FX.puff(pos, rr(9, 16), rr(1.4, 2.2), (right * side * rr(2, 6) + up * rr(6, 14)), side > 0 and cyanC or pinkC)
	end
	FX.flare(P + up * 10, 12, RGB(255, 240, 255), { points = 11 })
	FX.flare(P - right * 12 + up * 22, 9, C.pink, { points = 8, alpha = 0.3 })
	FX.flare(P + right * 12 + up * 22, 9, C.cyan, { points = 8, alpha = 0.3, spin = -0.5 })
	FX.rays(P + up * 12, 18, { C.pinkHot, C.white, C.cyan }, 18, 45, 2.2, { colorStart = true, start = 4 })
	for _ = 1, 170 do
		local side = 1
		if rng:NextNumber() < 0.5 then
			side = -1
		end
		local col = C.pinkHot
		if side > 0 then
			col = pick({ C.cyan, RGB(150, 245, 255) })
		end
		local dir = (right * side * rr(0.2, 1) + up * rr(0.1, 1.2) + cam0.LookVector * rr(-0.5, 0.5)).Unit
		FX.flyer(V3(rr(1.2, 3.6), rr(0.8, 2.6), 0.15), col, P + up * rr(4, 34) + dir * rr(0, 14), dir * rr(8, 30),
			{ neon = true, life = rr(0.8, 1.2), spin = 3, gravity = 4 })
	end
	local tStreak, tPuff = 0, 0
	Shot.update = function(u, dt)
		local k = u / (T1.YUTA - T1.CITY)
		camCF = cam0:Lerp(cam1, smooth(k))
		shake = 0.22
		tStreak = tStreak - dt
		if tStreak <= 0 then
			tStreak = 0.05
			local from = P + up * rr(10, 40) + right * rr(0, 20)
			FX.streak(from, (right + up * rr(0.4, 0.8)).Unit, rr(18, 34), rr(90, 150), 0.45, RGB(150, 245, 255), rr(0.4, 0.8), 4)
		end
		tPuff = tPuff - dt
		if tPuff <= 0 then
			tPuff = 0.06
			local side = (rng:NextNumber() < 0.5) and 1 or -1
			FX.puff(P + right * side * rr(4, 20) + up * rr(10, 30), rr(8, 13), rr(1.2, 1.8), up * rr(8, 14) + right * side * rr(2, 6), side > 0 and cyanC or pinkC)
		end
	end
end

-- 8.70–10.00: Юта вытягивает руку, за спиной огромная Рика
function P1.yuta()
	local f = beginShot(T1.YUTA)
	setLook({ clock = 13, brightness = 1.6, ambient = RGB(255, 225, 245), outdoor = RGB(255, 218, 242), tint = RGB(255, 242, 252),
		sat = 0.28, contrast = 0.12, bright = 0.05, bloom = 1.0, dof = { 8.5, 6, 0.3 } })
	local base = STAGE.yuta1
	local cam0 = CFrame.lookAt(base, base + V3(0, 0.08, -1))
	local cam1 = cam0 * CF(-0.3, 0.1, -0.6)
	camCF, camFOV = cam0, 52
	FX.backdrop(cam0 * CF(0, 0, -240) * ANG(0, math.pi, 0), 900, 600, { RGB(255, 210, 245), RGB(240, 110, 205), RGB(170, 50, 160) }, 120)

	yuta:show(true)
	yuta:place(cam0 * CF(1.1, -4.5, -8.0) * ANG(0, rad(112), 0))
	yuta:pose(POSE.yutaCast, 0)
	rika:show(true)
	rika:place(cam0 * CF(8, -5.5, -17) * ANG(0, rad(105), 0))
	rika:pose(POSE.rikaLoom, 0)
	yuta:update(songT)
	rika:update(songT)

	local hand = yuta:point("rArm", V3(0, -1.6, 0))
	local armDir = (hand - yuta:point("rArm", V3(0, 0, 0))).Unit
	local hit = hand + armDir * 2.2
	local flare = FX.flare(hit, 2.6, C.pink, { points = 9 })
	local rays = FX.rays(hit, 16, { C.pinkHot, C.white, C.pink }, 2, 8, 0.45, { bias = (armDir + V3(-0.3, 0.3, 0)) * 0.7 })
	local sdir = (cam0.RightVector * -1 + cam0.UpVector * -0.5).Unit
	local tStreak, tRing, tTw, tSp = 0, 0, 0, 0
	Shot.update = function(u, dt)
		local k = smooth(u / (T1.RYU - T1.YUTA))
		camCF = cam0:Lerp(cam1, k)
		shake = 0.16 + 0.08 * sin(u * 20)
		flare.set(nil, 2.6 * (1 + sin(u * 37) * 0.15))
		rays.update(u)
		if floor(u * 9) ~= floor((u - dt) * 9) then
			rays.reroll(0.3)
		end
		tRing = tRing - dt
		if tRing <= 0 then
			tRing = 0.35
			FX.ring(hit, C.pinkHot, 1, 6, 0.4, 0.2)
		end
		tSp = tSp - dt
		if tSp <= 0 then
			tSp = 0.02
			local d = (armDir + randUnit() * 0.9).Unit
			FX.spark(hit, d * rr(12, 26), pick({ C.pinkHot, C.white }), rr(0.6, 1.4), rr(0.2, 0.4), 0.05)
		end
		tTw = tTw - dt
		if tTw <= 0 then
			tTw = 0.12
			FX.twinkle(cam0 * V3(rr(-12, 12), rr(-6, 7), -rr(9, 16)), rr(0.25, 0.5), RGB(255, 200, 240), rr(0.6, 1.0))
		end
		tStreak = tStreak - dt
		if tStreak <= 0 then
			tStreak = 0.07
			local depth = rr(4.6, 6.5)
			local off = rr(-3.5, 3.5)
			local from = cam0 * V3(0, 0, -depth) + (cam0.RightVector * 0.5 + cam0.UpVector * -1).Unit * off - sdir * 14
			local col, wdt = C.cyan, rr(0.22, 0.42)
			if rng:NextNumber() < 0.35 then
				col, wdt = RGB(255, 222, 150), rr(0.16, 0.3)
			end
			FX.streak(from, sdir, rr(7, 12), rr(30, 45), 0.8, col, wdt, 4)
		end
	end
end

-- 10.00–11.17: Рю отбрасывает голубым взрывом
function P1.ryu()
	local f = beginShot(T1.RYU)
	setLook({ clock = 13, brightness = 1.6, ambient = RGB(175, 205, 245), outdoor = RGB(170, 200, 240), tint = RGB(232, 244, 255),
		sat = 0.3, contrast = 0.14, bright = 0.04, bloom = 1.0, dof = { 8.4, 5, 0.3 } })
	ui.flash.BackgroundTransparency = 0.3
	local base = STAGE.ryu1
	local cam0 = CFrame.lookAt(base, base + V3(0, 0.02, -1)) * ANG(0, 0, rad(6))
	local cam1 = cam0 * CF(0.2, 0.08, -0.7)
	camCF, camFOV = cam0, 56
	FX.backdrop(cam0 * CF(0, 0, -240) * ANG(0, math.pi, 0), 900, 600, { RGB(120, 190, 255), RGB(40, 100, 220), RGB(20, 50, 150) }, 70)

	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "grin")
	ryu:place(cam0 * CF(-1.0, -4.3, -8.4) * ANG(0, rad(164), 0))
	ryu:pose(POSE.ryuHit, 0)
	ryu:update(songT)
	ryu:pose({ root = { 16, -8, -8 }, neck = { 12, 12, 10 }, rArm = { 46, 0, 82 }, lArm = { 86, 0, -36 }, rLeg = { -18, 0, 4 }, lLeg = { 16, 0, -4 } }, 1.17, songT)

	local face = ryu:point("neck", V3(0, 0.7, 0))
	local hit = face + cam0.RightVector * 2.2 + cam0.UpVector * 1.0 - cam0.LookVector * 0.4
	local flare = FX.flare(hit, 1.6, C.cyan, { points = 10 })
	local rays = FX.rays(hit, 18, { C.cyan, C.white, RGB(160, 240, 255), C.pinkHot }, 1.5, 6.5, 0.32)
	local toCam = (cam0.Position - hit).Unit
	local acc = { shard = 0, streak = 0, spark = 0, tw = 0 }
	Shot.update = function(u, dt)
		local k = smooth(u / (T1.FIN - T1.RYU))
		camCF = cam0:Lerp(cam1, k)
		shake = lerp(1.0, 0.45, k)
		ui.flash.BackgroundTransparency = clamp01(0.3 + u * 6)
		flare.set(nil, 1.6 * (1 + sin(u * 35) * 0.15 + u * 0.35))
		rays.scale = 1 + u * 0.4
		rays.update(u)
		if floor(u * 10) ~= floor((u - dt) * 10) then
			rays.reroll(0.3)
		end
		acc.shard = acc.shard + 60 * dt
		while acc.shard >= 1 do
			acc.shard = acc.shard - 1
			local dir = (toCam * 0.5 + cam0.RightVector * rr(-0.4, 1.2) + V3(rr(-1, 1), rr(-0.8, 1), rr(-1, 1))).Unit
			FX.flyer(V3(0.06, rr(0.2, 0.6), rr(0.3, 0.9)), pick({ C.cyan, RGB(140, 240, 255), RGB(90, 210, 255) }), hit + dir * rr(0.4, 1.5), dir * rr(7, 16),
				{ neon = true, wedge = true, life = rr(0.5, 1.0), spin = 6 })
		end
		acc.spark = acc.spark + 50 * dt
		while acc.spark >= 1 do
			acc.spark = acc.spark - 1
			local d = randUnit()
			FX.spark(hit, d * rr(10, 22), pick({ C.cyan, C.white }), rr(0.5, 1.2), rr(0.2, 0.4), 0.04)
		end
		acc.tw = acc.tw + 14 * dt
		while acc.tw >= 1 do
			acc.tw = acc.tw - 1
			FX.twinkle(cam0 * V3(rr(-5, 1), rr(-3, 3), -rr(5, 8)), rr(0.1, 0.22), RGB(255, 100, 215), rr(0.25, 0.5))
		end
		acc.streak = acc.streak + 6 * dt
		while acc.streak >= 1 do
			acc.streak = acc.streak - 1
			local pos = cam0 * V3(rr(2, 5), rr(-2.5, 2), -rr(6, 8))
			FX.streak(pos, (cam0.RightVector * -1 + cam0.UpVector * 0.35).Unit, rr(2.5, 4.5), 22, 0.35, RGB(255, 225, 140), 0.16, 4)
		end
	end
end

P1.shots = {
	{ 0, P1.eyes }, { T1.WHITE, P1.clash }, { T1.CITY, P1.city }, { T1.YUTA, P1.yuta }, { T1.RYU, P1.ryu },
}
P1.fin = T1.FIN
