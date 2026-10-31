----------------------------------------------------------------------
-- ЧАСТЬ 1 (0:00–0:11)
----------------------------------------------------------------------

local P1 = {}

-- 0.00–4.83: глаза Юты (сверху) и Рю (снизу)
function P1.eyes()
	beginShot(0)
	setLook({ clock = 12, brightness = 0, ambient = C.white, outdoor = C.white, fogStart = 100000, fogEnd = 100001,
		bloom = 0.2, bloomThreshold = 0.97, sat = 0.06, contrast = 0.05 })
	ui.vignette.Visible = false
	local S0 = STAGE.eyes
	local cam0 = CFrame.lookAt(S0 + V3(0, 0, -EYES.camDist), S0)
	camCF, camFOV = cam0, 20
	Shot.update = function(u)
		local k = smooth(u / T1.WHITE)
		camFOV = lerp(20, 18.9, k)
		local j = 0.04 + 0.12 * clamp01((u - 3.4) / 1.2)
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
	setLook({ clock = 0, brightness = 1.2, ambient = RGB(95, 115, 112), outdoor = RGB(85, 105, 108), tint = RGB(232, 255, 244),
		sat = 0.4, contrast = 0.18, bright = 0.02, bloom = 1.4, bloomSize = 40, bloomThreshold = 0.8,
		fogColor = RGB(14, 30, 34), fogStart = 120, fogEnd = 700 })
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
	newPart(f, V3(32, 80, 28), RGB(34, 40, 44), CF(rp.X, rp.Y - 14 - 40, rp.Z + 4) * ANG(0, rad(20), 0), { material = Enum.Material.Concrete })
	for _ = 1, 4 do
		newPart(f, V3(0.6, 0.6, rr(8, 14)), C.red, CF(rp + V3(rr(-12, 12), -rr(12, 20), rr(-8, 8))) * ANG(rr(-1, 1), rr(0, 6), rr(-1, 1)))
	end

	local pink = FX.energyBeam(C.pink, 2.2)
	local cyan = FX.energyBeam(C.cyan, 2.8)
	local cyanFrom = cam0 * V3(-34, -19, -20)
	local core = FX.glow(P, 26, C.yellow, 0.17, 3)
	local halo = FX.glow(P, 64, RGB(255, 240, 205), 0.06, 1.5)
	local rays = FX.rays(P, 22, { C.yellow, C.white, C.pinkHot, C.cyan, C.gold }, 10, 34, 1.6)
	FX.emitter(P, V3(3, 3, 3), {
		rate = 70, life = { 0.12, 0.25 }, speed = { 2, 6 }, sphere = true, brightness = 4,
		size = NS({ { 0, 9 }, { 1, 16 } }), alpha = NS({ { 0, 0.35 }, { 1, 1 } }), color = CS({ { 0, C.white }, { 1, C.yellow } }),
	})
	FX.sparks(P, { C.yellow, C.white }, 280, 70, 0.7)
	FX.smoke(cam0 * V3(-40, 22, -75), V3(50, 20, 20), CS({ { 0, RGB(40, 150, 115) }, { 1, RGB(30, 90, 80) } }), 6, 40, 3, 4, { burst = 12 })
	FX.smoke(cam0 * V3(35, -24, -60), V3(40, 10, 20), ColorSequence.new(RGB(46, 66, 52)), 5, 34, 3, 3, { burst = 8 })
	local bolts = { FX.bolt(C.cyan, 0.12), FX.bolt(C.yellow, 0.1), FX.bolt(RGB(230, 255, 255), 0.1), FX.bolt(C.white, 0.08) }

	local toCam = (cam0.Position - P).Unit
	local function spawn(kind)
		local dir = (toCam * 0.9 + V3(rr(-1, 1), rr(-0.7, 1), rr(-1, 1))).Unit
		if kind == "shard" then
			FX.flyer(V3(0.15, rr(0.8, 2.8), rr(1.2, 4.5)), pick({ C.yellow, C.gold, RGB(255, 246, 205) }), P + dir * rr(2, 5), dir * rr(28, 62),
				{ neon = true, wedge = true, life = rr(0.55, 1.0), spin = 9 })
		elseif kind == "rock" then
			FX.flyer(V3(rr(0.7, 2.6), rr(0.6, 2.2), rr(0.7, 2.6)), C.rock, P + dir * rr(3, 6), dir * rr(18, 40),
				{ material = Enum.Material.Slate, life = rr(0.9, 1.4), spin = 5, gravity = 18 })
		elseif kind == "girder" then
			local side = (cam0.RightVector * rr(-1, 1) + cam0.UpVector * rr(-0.3, 1)).Unit
			FX.flyer(V3(0.35, 0.35, rr(2.5, 6)), C.red, P + side * rr(3, 6), side * rr(14, 28), { life = rr(1, 1.6), spin = 4, gravity = 10 })
		elseif kind == "teal" then
			FX.flyer(V3(0.12, rr(0.6, 1.8), rr(0.8, 2.6)), RGB(120, 245, 228), P + dir * rr(4, 10), dir * rr(22, 48),
				{ neon = true, wedge = true, life = 0.9, spin = 7 })
		else
			FX.flyer(V3(0.1, rr(0.5, 1.4), rr(0.5, 1.6)), RGB(20, 40, 45), P + dir * rr(4, 10), dir * rr(20, 40), { wedge = true, life = 0.9, spin = 7 })
		end
	end

	local acc = { shard = 0, rock = 0, girder = 0, teal = 0, dark = 0 }
	local tBolt, tRing, tReroll = 0, 0, 0
	local teal = nil
	local w = T1.CLASH - T1.WHITE
	Shot.update = function(u, dt)
		local k = smooth(u / (T1.CITY - T1.WHITE))
		camCF = cam0:Lerp(cam1, k)
		camFOV = lerp(72, 64, k)
		if u < w then
			ui.flash.BackgroundTransparency = lerp(0, 0.5, u / w)
			Shot.blur = lerp(26, 6, u / w)
			shake = 1.7
		else
			ui.flash.BackgroundTransparency = clamp01(0.5 + (u - w) * 3.5)
			Shot.blur = math.max(0, 6 - (u - w) * 30)
			shake = 0.8 + 0.25 * sin(u * 31)
		end
		pink.set(rika.mouth(), P, 2.1 + sin(u * 50) * 0.3)
		cyan.set(cyanFrom, P, 2.8 + sin(u * 43 + 1) * 0.4)
		local pulse = 1 + sin(u * 40) * 0.12
		core.set(nil, 26 * pulse)
		halo.set(nil, 64 * (1 + sin(u * 23) * 0.08))
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
				b.strike(P, P + V3(rr(-1, 1), rr(-0.6, 1), rr(-1, 1)).Unit * rr(16, 34), 1.8)
			end
		end
		tRing = tRing - dt
		if tRing <= 0 then
			tRing = 0.3
			FX.ring(P, C.white, 6, 46, 0.45, 10)
		end
		local late = u > (T1.TEAL - T1.WHITE)
		local rates = { shard = 48, rock = 15, girder = 4, teal = 0, dark = 0 }
		if u < w then
			rates = { shard = 18, rock = 4, girder = 1, teal = 0, dark = 0 }
		elseif late then
			rates = { shard = 20, rock = 6, girder = 2, teal = 45, dark = 25 }
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
				teal = FX.glow(P, 20, C.teal, 0.12, 2)
			end
			teal.set(nil, lerp(20, 140, easeOut(g)), 0.6 + g)
			ui.tint.BackgroundColor3 = RGB(90, 235, 215)
			ui.tint.BackgroundTransparency = lerp(1, 0.5, g)
			shake = lerp(0.9, 1.7, g)
		end
	end
end

-- 7.83–8.70: общий план ночного города, розово-голубой взрыв
function P1.city()
	local f = beginShot(T1.CITY)
	setLook({ clock = 0, brightness = 1.2, ambient = RGB(92, 118, 132), outdoor = RGB(86, 112, 128), tint = RGB(222, 236, 255),
		sat = 0.28, contrast = 0.14, bright = 0.02, bloom = 1.1, bloomSize = 40, fogColor = RGB(16, 22, 44), fogStart = 160, fogEnd = 1100 })
	local P = CLASH_POINT + V3(0, -4, 0)
	local cam0 = CFrame.lookAt(CITY_CAM, P + V3(0, 26, 0))
	local cam1 = CFrame.lookAt(CITY_CAM + (P - CITY_CAM).Unit * 16, P + V3(0, 27, 0))
	camCF, camFOV = cam0, 46
	local right, up = cam0.RightVector, cam0.UpVector
	local pinkCS = CS({ { 0, RGB(255, 150, 230) }, { 1, RGB(170, 60, 200) } })
	local cyanCS = CS({ { 0, RGB(170, 250, 255) }, { 1, RGB(40, 170, 230) } })
	FX.smoke(P - right * 16 + up * 18, V3(26, 30, 14), pinkCS, 40, 48, 1.6, 12, { emission = 0.6, brightness = 2, burst = 30, alpha = NS({ { 0, 0.5 }, { 0.5, 0.35 }, { 1, 1 } }), spread = 80 })
	FX.smoke(P + right * 16 + up * 18, V3(26, 30, 14), cyanCS, 40, 48, 1.6, 12, { emission = 0.6, brightness = 2, burst = 30, alpha = NS({ { 0, 0.5 }, { 0.5, 0.35 }, { 1, 1 } }), spread = 80 })
	FX.smoke(P + up * 40, V3(14, 20, 14), ColorSequence.new(RGB(215, 190, 250)), 16, 40, 2, 22, { emission = 0.4, burst = 10, spread = 20 })
	local core = FX.glow(P + up * 8, 46, RGB(255, 235, 255), 0.16, 3)
	FX.glow(P - right * 14 + up * 22, 70, C.pink, 0.08, 2)
	FX.glow(P + right * 14 + up * 22, 70, C.cyan, 0.08, 2)
	FX.emitter(P + up * 20, V3(40, 40, 10), {
		rate = 60, life = { 0.6, 1.1 }, speed = { 4, 12 }, size = NS({ { 0, 1.2 }, { 1, 0 } }), brightness = 4,
		color = CS({ { 0, C.pinkHot }, { 0.5, C.white }, { 1, C.cyan } }), burst = 40,
	})
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
	local tStreak = 0
	Shot.update = function(u, dt)
		local k = u / (T1.YUTA - T1.CITY)
		camCF = cam0:Lerp(cam1, smooth(k))
		shake = 0.22
		core.set(nil, 46 * (1 + 0.1 * sin(u * 20)))
		tStreak = tStreak - dt
		if tStreak <= 0 then
			tStreak = 0.05
			local from = P + up * rr(10, 40) + right * rr(0, 20)
			FX.streak(from, (right + up * rr(0.4, 0.8)).Unit, rr(18, 34), rr(90, 150), 0.45, RGB(150, 245, 255), rr(0.4, 0.8), 4)
		end
	end
end

-- 8.70–10.00: Юта вытягивает руку, за спиной огромная Рика
function P1.yuta()
	local f = beginShot(T1.YUTA)
	setLook({ clock = 0, brightness = 1, ambient = RGB(255, 215, 240), outdoor = RGB(255, 205, 235), tint = RGB(255, 236, 250),
		sat = 0.25, contrast = 0.14, bright = 0.02, bloom = 1.0, dof = { 8.5, 6, 0.35 } })
	local base = STAGE.yuta1
	local cam0 = CFrame.lookAt(base, base + V3(0, 0.08, -1))
	local cam1 = cam0 * CF(-0.3, 0.1, -0.6)
	camCF, camFOV = cam0, 52
	FX.backdrop(cam0 * CF(0, 0, -240) * ANG(0, math.pi, 0), 900, 600, { RGB(255, 175, 232), RGB(205, 60, 170), RGB(120, 20, 110) }, 120)
	FX.glow(cam0 * V3(-60, 35, -180), 160, RGB(255, 190, 240), 0.08, 1.5)

	yuta:show(true)
	yuta:place(cam0 * CF(1.1, -4.5, -8.0) * ANG(0, rad(112), 0))
	yuta:pose(POSE.yutaCast, 0)
	rika:show(true)
	rika:place(cam0 * CF(8, -5.5, -17) * ANG(0, rad(105), 0))
	rika:pose(POSE.rikaLoom, 0)
	yuta:update(songT)
	rika:update(songT)

	local hand = yuta:point("lArm", V3(0, -1.6, 0))
	local armDir = (hand - yuta:point("lArm", V3(0, 0, 0))).Unit
	local hit = hand + armDir * 2.2
	local glow = FX.glow(hit, 4.5, C.pink, 0.16, 3)
	local rays = FX.rays(hit, 16, { C.pinkHot, C.white, C.pink }, 2, 8, 0.45, { bias = (armDir + V3(-0.3, 0.3, 0)) * 0.7 })
	FX.sparks(hit, { C.pinkHot, C.white }, 120, 22, 0.25)
	FX.emitter(cam0 * V3(0, 0, -12), V3(26, 16, 6), {
		rate = 30, life = { 1, 2 }, speed = { 0.5, 2 }, size = NS({ { 0, 0.25 }, { 0.5, 0.35 }, { 1, 0 } }), brightness = 3,
		color = ColorSequence.new(RGB(255, 190, 240)), burst = 30,
	})
	local sdir = (cam0.RightVector * -1 + cam0.UpVector * -0.5).Unit
	local tStreak, tRing = 0, 0
	Shot.update = function(u, dt)
		local k = smooth(u / (T1.RYU - T1.YUTA))
		camCF = cam0:Lerp(cam1, k)
		shake = 0.16 + 0.08 * sin(u * 20)
		glow.set(nil, 4.5 * (1 + sin(u * 37) * 0.15))
		rays.update(u)
		if floor(u * 9) ~= floor((u - dt) * 9) then
			rays.reroll(0.3)
		end
		tRing = tRing - dt
		if tRing <= 0 then
			tRing = 0.35
			FX.ring(hit, C.pinkHot, 1.5, 9, 0.4, 6)
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
	setLook({ clock = 0, brightness = 1, ambient = RGB(150, 185, 235), outdoor = RGB(140, 175, 230), tint = RGB(218, 236, 255),
		sat = 0.35, contrast = 0.16, bright = 0.02, bloom = 1.1, dof = { 8.4, 5, 0.3 } })
	ui.flash.BackgroundTransparency = 0.3
	local base = STAGE.ryu1
	local cam0 = CFrame.lookAt(base, base + V3(0, 0.12, -1)) * ANG(0, 0, rad(6))
	local cam1 = cam0 * CF(0.2, 0.1, -0.7)
	camCF, camFOV = cam0, 56
	FX.backdrop(cam0 * CF(0, 0, -240) * ANG(0, math.pi, 0), 900, 600, { RGB(40, 90, 190), RGB(14, 36, 100), RGB(8, 18, 60) }, 70)

	ryu:show(true)
	showVariant(ryu.tags, "mouth_", "grin")
	ryu:place(cam0 * CF(-1.0, -3.7, -8.4) * ANG(0, rad(164), 0))
	ryu:pose(POSE.ryuHit, 0)
	ryu:update(songT)
	ryu:pose({ root = { 16, -8, -8 }, neck = { 12, 12, 10 }, rArm = { 46, 0, 82 }, lArm = { 86, 0, -36 }, rLeg = { -18, 0, 4 }, lLeg = { 16, 0, -4 } }, 1.17, songT)

	local face = ryu:point("neck", V3(0, 0.7, 0))
	local hit = face + cam0.RightVector * 2.2 + cam0.UpVector * 1.0 - cam0.LookVector * 0.4
	local glow = FX.glow(hit, 3, C.cyan, 0.18, 4)
	local halo = FX.glow(hit, 10, C.cyanDeep, 0.07, 2)
	local rays = FX.rays(hit, 18, { C.cyan, C.white, RGB(160, 240, 255), C.pinkHot }, 1.5, 6.5, 0.32)
	FX.sparks(hit, { C.cyan, C.white }, 160, 18, 0.22)
	FX.emitter(cam0 * V3(-2.5, 0, -6.5), V3(5, 6, 2), {
		rate = 40, life = { 0.2, 0.45 }, speed = { 0.5, 2 }, size = NS({ { 0, 0.18 }, { 1, 0 } }), brightness = 4,
		color = ColorSequence.new(RGB(255, 90, 210)),
	})
	local toCam = (cam0.Position - hit).Unit
	local acc = { shard = 0, streak = 0 }
	Shot.update = function(u, dt)
		local k = smooth(u / (T1.FIN - T1.RYU))
		camCF = cam0:Lerp(cam1, k)
		shake = lerp(1.0, 0.45, k)
		ui.flash.BackgroundTransparency = clamp01(0.3 + u * 6)
		local pulse = 1 + sin(u * 35) * 0.15 + u * 0.35
		glow.set(nil, 3 * pulse)
		halo.set(nil, 10 * (1 + u * 0.45))
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
