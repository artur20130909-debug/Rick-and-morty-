----------------------------------------------------------------------
-- ОБЩЕЕ ДЛЯ ЧАСТЕЙ 3 и 4: «Гранитный залп» из причёски Рю, бег Юты, туман
----------------------------------------------------------------------

local SH = {}

-- кончик помпадура Рю в системе кости головы: отсюда бьёт его энергия
SH.TIP = V3(0, 1.95, -1.55)
SH.HAIR_GLOW = RGB(70, 225, 255)

-- волосы Рю подсвечиваются голубым, когда в причёске копится энергия
function SH.hairGlow(k)
	for _, p in ipairs(ryu.hair or {}) do
		p.Color = C.hairRyu:Lerp(SH.HAIR_GLOW, 0.5 * clamp01(k))
	end
end

-- Энергия в помпадуре: ядро-звезда, мягкий ореол, голубой свет на лице,
-- молнии от кончика причёски. level 0..1 задаёт силу; o.beam — луч вперёд.
function SH.granite(o)
	o = o or {}
	local tip = ryu:point("neck", SH.TIP)
	local core = FX.flare(tip, 1, C.cyan, { points = 10, alpha = 0.08, glowOp = 0.55 })
	local haze = FX.glow(tip, 6, RGB(90, 210, 255), 0.35)
	local lightPart = newPart(Shot.folder, V3(0.2, 0.2, 0.2), C.white, CF(tip), { alpha = 1 })
	local light = Instance.new("PointLight")
	light.Color = RGB(110, 225, 255)
	light.Range = 9
	light.Brightness = 0
	light.Shadows = false
	light.Parent = lightPart
	local bolts = {}
	for i = 1, o.bolts or 4 do
		bolts[i] = FX.bolt(i % 2 == 0 and RGB(210, 250, 255) or C.cyan, o.boltWidth or 0.05)
	end
	local beam = o.beam and FX.energyBeam(C.cyan, 1) or nil
	local obj = { level = o.level or 1, size = o.size or 1, beamLen = 0, beamW = 1, reach = o.reach or 4 }
	local tb = 0
	addUpdater(function(dt)
		local L = obj.level
		tip = ryu:point("neck", SH.TIP)
		local head = ryu.bones.neck.world
		local fwd = obj.dir or (head.LookVector + head.UpVector * 0.35).Unit
		local pulse = 1 + 0.18 * sin(songT * 21) + 0.08 * sin(songT * 47)
		core.set(tip, obj.size * (0.4 + 0.6 * L) * pulse, L > 0.02 and 1 or 0)
		haze.pos = tip + fwd * 0.4
		haze.size = obj.size * (2 + 3 * L) * pulse
		haze.k = clamp01(L * 1.2) * 0.7
		lightPart.CFrame = CF(tip + fwd * 0.6)
		light.Brightness = 4 * L
		SH.hairGlow(L)
		tb = tb - dt
		if tb <= 0 then
			tb = 0.055
			for i, b in ipairs(bolts) do
				local on = L > 0.15 and (i <= 2 or rng:NextNumber() < L)
				b.show(on)
				if on then
					-- молнии бьют вперёд, вверх и в стороны, но не вниз по лицу
					local up = head.UpVector
					local d = fwd * rr(0.4, 1.2) + up * rr(0.2, 0.9) + randUnit() * 0.8
					if d:Dot(up) < 0.1 then
						d = d + up * (0.1 - d:Dot(up) + 0.3)
					end
					d = d.Unit
					b.strike(tip, tip + d * obj.reach * rr(0.5, 1.1) * (0.5 + L), 0.35 * obj.size)
				end
			end
		end
		if beam then
			if obj.beamLen > 0.5 then
				beam.set(tip + fwd * 0.3, tip + fwd * obj.beamLen, obj.beamW)
			else
				beam.set(tip, tip, 0.01)
			end
		end
		return true
	end)
	return obj
end

-- кровь на левом плече Юты (с середины части 3 и в части 4)
function SH.yutaBlood(on)
	for _, p in ipairs(yuta.tags.sblood or {}) do
		p.Transparency = on and 0 or 1
	end
end

-- Бег: ноги и руки ходят навстречу друг другу, корпус наклонён вперёд.
function SH.runCycle(rig, freq, amp)
	freq = freq or 15
	amp = amp or 55
	rig.bones.rLeg.wob = function(t)
		return ANG(rad(amp * sin(t * freq)), 0, 0)
	end
	rig.bones.lLeg.wob = function(t)
		return ANG(rad(-amp * sin(t * freq)), 0, 0)
	end
	rig.bones.rArm.wob = function(t)
		return ANG(rad(-amp * 1.1 * sin(t * freq)), 0, 0)
	end
	rig.bones.lArm.wob = function(t)
		return ANG(rad(amp * 1.1 * sin(t * freq)), 0, 0)
	end
end

-- поставить бегущего в точку pos лицом по dir, с подпрыгиванием шага
function SH.placeRunner(rig, pos, dir, freq)
	local flat = V3(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.01 then
		flat = V3(0, 0, -1)
	end
	rig:place(CFrame.lookAt(pos, pos + flat.Unit) * CF(0, abs(sin(songT * (freq or 15))) * 0.3, 0))
end

-- розовые искры, летящие сквозь туман (как в аниме: короткие яркие штрихи)
function SH.pinkSparks(cam, dt, state, rate, dir, near)
	state.t = (state.t or 0) - dt
	while state.t <= 0 do
		state.t = state.t + rate
		local from
		if near then
			-- совсем рядом с камерой: искры летят прямо по лицу героя
			local z = rr(near[1], near[2])
			from = cam * V3(rr(-1.1, 0.4) * z, rr(-0.45, 0.45) * z, -z)
			FX.streak(from, dir, rr(0.5, 1.3), rr(9, 16), rr(0.3, 0.5), pick({ C.pink, C.pinkHot, RGB(255, 80, 210) }), rr(0.03, 0.07), 3)
		else
			from = cam * V3(rr(-26, 22), rr(-9, 9), -rr(12, 40))
			FX.streak(from, dir, rr(1.8, 4.5), rr(30, 60), rr(0.35, 0.6), pick({ C.pink, C.pinkHot, RGB(255, 80, 210) }), rr(0.12, 0.3), 3)
		end
	end
end
