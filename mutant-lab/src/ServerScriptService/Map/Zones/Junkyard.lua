-- Зона 4. Свалка роботов: горы металлолома, сломанные роботы, гигантская голова робота,
-- кран с магнитом, старые машины, покрышки, бочки и лужи масла, искры.
local RS = game:GetService("ReplicatedStorage")
local B = require(RS.Shared.Build)
local P = require(script.Parent.Parent.Props)
local T = require(script.Parent.Parent.Terrain)

local Z = {}
local C, rgb = P.C, P.rgb
local M = Enum.Material

local JUNK_COLORS = { rgb(150, 82, 52), rgb(120, 124, 132), rgb(80, 110, 150), rgb(200, 170, 60), rgb(170, 62, 50), rgb(90, 96, 90) }
local JUNK_MATS = { M.CorrodedMetal, M.Metal, M.DiamondPlate, M.CorrodedMetal }
local ROBOT_COLORS = { rgb(90, 140, 200), rgb(230, 140, 50), rgb(160, 166, 176), rgb(200, 80, 80) }

local function sparks(parent)
	B.particles(parent, {
		Color = ColorSequence.new(rgb(255, 230, 120), rgb(255, 140, 40)), Size = NumberSequence.new(0.25, 0),
		Transparency = NumberSequence.new(0, 1), Lifetime = NumberRange.new(0.3, 0.7), Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(40, 40), Rate = 5, LightEmission = 1, Acceleration = Vector3.new(0, -30, 0),
		EmissionDirection = Enum.NormalId.Top,
	})
end

-- гора хлама с земляным холмом внутри
local function scrapPile(m, rng, pos, R)
	local g = B.model(m, "ScrapPile")
	T.ball(pos.X, pos.Y - R * 0.55, pos.Z, R * 0.95, M.Ground)
	local n = math.floor(R * 2.4)
	for _ = 1, n do
		local a, r = rng:angle(), R * math.sqrt(rng:next())
		local h = math.max(0.3, (R - r) * 0.55 + rng:range(0, 1.2))
		local p = pos + Vector3.new(math.cos(a) * r, h, math.sin(a) * r)
		local cf = CFrame.new(p) * CFrame.Angles(rng:range(-1.2, 1.2), rng:angle(), rng:range(-1.2, 1.2))
		local col, mat = rng:pick(JUNK_COLORS), rng:pick(JUNK_MATS)
		local kind = rng:int(1, 6)
		if kind == 1 then
			B.part(g, "Plate", Vector3.new(rng:range(3, 6), rng:range(0.3, 0.6), rng:range(2, 4)), cf, col, mat)
		elseif kind == 2 then
			B.part(g, "Beam", Vector3.new(0.8, 0.8, rng:range(4, 8)), cf, col, mat)
		elseif kind == 3 then
			B.cyl(g, "Pipe", rng:range(3, 6), rng:range(0.8, 1.6), cf, col, M.Metal)
		elseif kind == 4 then
			local s = rng:range(1.6, 3)
			B.part(g, "Box", Vector3.new(s, s, s), cf, col, mat)
		elseif kind == 5 then
			B.cyl(g, "Tire", 1.1, 3, cf, rgb(30, 30, 32), M.SmoothPlastic)
		else
			B.cyl(g, "Gear", 0.6, rng:range(2, 3.4), cf, rgb(150, 150, 140), M.Metal)
		end
	end
	return g
end

local function robot(m, rng, pos, yaw, s, pose)
	local g = B.model(m, "BrokenRobot")
	local col = rng:pick(ROBOT_COLORS)
	local o = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	g.WorldPivot = o -- поворачиваем робота вокруг точки между ступнями
	local legH = 4 * s
	-- ноги
	for _, x in ipairs({ -1.5 * s, 1.5 * s }) do
		B.part(g, "Leg", Vector3.new(1.6 * s, legH, 1.8 * s), o * CFrame.new(x, legH / 2, 0), C.metal, M.Metal)
		B.part(g, "Foot", Vector3.new(2 * s, 0.8 * s, 3 * s), o * CFrame.new(x, 0.4 * s, -0.4 * s), C.metalDark, M.Metal)
	end
	local bodyC = o * CFrame.new(0, legH + 3.5 * s, 0)
	B.part(g, "Body", Vector3.new(6 * s, 7 * s, 4 * s), bodyC, col, M.Metal)
	B.part(g, "Panel", Vector3.new(3.4 * s, 3 * s, 0.3 * s), bodyC * CFrame.new(0, 0.5 * s, -2.1 * s), C.metalDark, M.Metal)
	local light = B.ball(g, "ChestLight", 0.9 * s, bodyC * CFrame.new(-0.8 * s, 0.8 * s, -2.2 * s), rgb(255, 60, 60), M.Neon)
	B.tag(light, "Pulse", { Speed = 1 })
	-- голова: один глаз горит, другой разбит
	local headC = bodyC * CFrame.new(0, 5 * s, 0) * CFrame.Angles(0, 0, math.rad(rng:range(-20, 20)))
	B.part(g, "Head", Vector3.new(4 * s, 3.2 * s, 3.6 * s), headC, col, M.Metal)
	B.ball(g, "Eye", 1.1 * s, headC * CFrame.new(-0.9 * s, 0.2 * s, -1.75 * s), rgb(120, 230, 255), M.Neon)
	B.ball(g, "EyeBroken", 1.1 * s, headC * CFrame.new(0.9 * s, 0.2 * s, -1.75 * s), rgb(30, 30, 34), M.Glass)
	B.part(g, "Mouth", Vector3.new(2.4 * s, 0.4 * s, 0.2 * s), headC * CFrame.new(0, -0.9 * s, -1.85 * s), C.metalDark, M.Metal)
	B.vcyl(g, "Antenna", 2 * s, 0.25 * s, headC * CFrame.new(0.6 * s, 2.6 * s, 0) * CFrame.Angles(0, 0, 0.4), C.metalLight, M.Metal)
	B.ball(g, "AntennaTip", 0.6 * s, headC * CFrame.new(1.05 * s, 3.5 * s, 0), rgb(255, 200, 60), M.Neon)
	-- руки: одна висит, вторая оторвана (искрит)
	B.ball(g, "Shoulder", 1.8 * s, bodyC * CFrame.new(-3.6 * s, 2.4 * s, 0), C.metal, M.Metal)
	B.part(g, "Arm", Vector3.new(1.2 * s, 6 * s, 1.2 * s), bodyC * CFrame.new(-3.9 * s, -0.6 * s, 0) * CFrame.Angles(0, 0, math.rad(-8)), col, M.Metal)
	local stump = B.ball(g, "Stump", 1.6 * s, bodyC * CFrame.new(3.6 * s, 2.4 * s, 0), C.metalDark, M.Metal)
	sparks(stump)
	-- поза: «сидит», «лежит» или «стоит»
	if pose == "lying" then
		g:PivotTo(CFrame.new(pos + Vector3.new(0, 2 * s, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-88), 0, 0))
	elseif pose == "tilted" then
		g:PivotTo(o * CFrame.Angles(math.rad(12), 0, math.rad(15)))
	end
	-- оторванная рука рядом
	B.part(g, "LostArm", Vector3.new(1.2 * s, 6 * s, 1.2 * s), o * CFrame.new(7 * s, 0.6 * s, 2 * s) * CFrame.Angles(0, 0.5, math.rad(90)), col, M.Metal)
	return g
end

local function giantHead(m, pos, yaw)
	local g = B.model(m, "GiantRobotHead")
	local o = CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-14), 0, math.rad(9))
	B.part(g, "Head", Vector3.new(26, 20, 22), o * CFrame.new(0, 6, 0), rgb(120, 132, 146), M.CorrodedMetal)
	B.part(g, "Brow", Vector3.new(27, 2.4, 3), o * CFrame.new(0, 12, -10.6), rgb(90, 98, 110), M.Metal)
	for _, x in ipairs({ -6.5, 6.5 }) do
		B.cyl(g, "EyeRim", 1.2, 8.4, o * CFrame.new(x, 7.5, -11) * CFrame.Angles(0, math.rad(90), 0), rgb(70, 76, 86), M.Metal)
		local eye = B.cyl(g, "Eye", 1, 6.6, o * CFrame.new(x, 7.5, -11.3) * CFrame.Angles(0, math.rad(90), 0), rgb(255, 60, 50), M.Neon)
		B.light(eye, "SpotLight", { Range = 40, Brightness = 3, Angle = 50, Color = rgb(255, 80, 60), Face = Enum.NormalId.Right })
		B.tag(eye, "Pulse", { Speed = 0.6 })
	end
	for i = -4, 4 do
		B.part(g, "Grill", Vector3.new(1.2, 5, 0.6), o * CFrame.new(i * 2.2, 0, -11.2), rgb(60, 64, 72), M.Metal)
	end
	B.part(g, "EarL", Vector3.new(3, 8, 8), o * CFrame.new(-14, 6, 0), rgb(90, 98, 110), M.Metal)
	B.part(g, "EarR", Vector3.new(3, 8, 8), o * CFrame.new(14, 6, 0), rgb(90, 98, 110), M.Metal)
	B.between(g, "Antenna", (o * CFrame.new(4, 16, 2)).Position, (o * CFrame.new(10, 24, 6)).Position, 0.8, C.metalLight, M.Metal, true)
	B.between(g, "Antenna", (o * CFrame.new(10, 24, 6)).Position, (o * CFrame.new(16, 23, 4)).Position, 0.8, C.metalLight, M.Metal, true)
	local tip = B.ball(g, "Tip", 1.8, o * CFrame.new(16, 23, 4), rgb(255, 200, 60), M.Neon)
	sparks(tip)
	return g
end

local function car(m, rng, cf)
	local g = B.model(m, "OldCar")
	local col = rng:pick({ rgb(170, 70, 60), rgb(70, 120, 170), rgb(200, 180, 90), rgb(90, 150, 100), rgb(140, 140, 150) })
	B.part(g, "Body", Vector3.new(5, 2.6, 10), cf * CFrame.new(0, 2, 0), col, M.CorrodedMetal)
	B.part(g, "Cabin", Vector3.new(4.6, 2.2, 5), cf * CFrame.new(0, 4.4, 0.6), col, M.CorrodedMetal)
	B.part(g, "Windshield", Vector3.new(4.2, 1.8, 0.2), cf * CFrame.new(0, 4.4, -1.95), rgb(60, 80, 90), M.Glass, { Transparency = 0.3 })
	for _, x in ipairs({ -2.5, 2.5 }) do
		for _, z in ipairs({ -3.4, 3.4 }) do
			B.cyl(g, "Wheel", 1, 2.4, cf * CFrame.new(x, 1.2, z), rgb(28, 28, 30), M.SmoothPlastic)
		end
	end
	return g
end

local function crane(m, pos, yaw, L)
	local g = B.model(m, "Crane")
	local o = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local H, w = 42, 4
	local yel = rgb(235, 180, 40)
	B.part(g, "Footing", Vector3.new(w + 4, 1.5, w + 4), o * CFrame.new(0, 0.75, 0), C.concrete, M.Concrete)
	for _, x in ipairs({ -w / 2, w / 2 }) do
		for _, z in ipairs({ -w / 2, w / 2 }) do
			B.part(g, "Chord", Vector3.new(0.6, H, 0.6), o * CFrame.new(x, H / 2, z), yel, M.Metal)
		end
	end
	-- решётка
	for y = 3, H - 3, 6 do
		for _, side in ipairs({ { -w / 2, 0, true }, { w / 2, 0, true }, { 0, -w / 2, false }, { 0, w / 2, false } }) do
			local a, b
			if side[3] then
				a = o * Vector3.new(side[1], y, -w / 2)
				b = o * Vector3.new(side[1], y + 6, w / 2)
			else
				a = o * Vector3.new(-w / 2, y, side[2])
				b = o * Vector3.new(w / 2, y + 6, side[2])
			end
			B.between(g, "Brace", a, b, 0.35, yel, M.Metal)
		end
	end
	-- кабина, стрела, противовес, трос и магнит
	B.part(g, "Cab", Vector3.new(5, 4, 5), o * CFrame.new(0, H + 2, -1), yel, M.Metal)
	B.part(g, "CabWindow", Vector3.new(4.4, 2, 0.2), o * CFrame.new(0, H + 2.6, -3.55), rgb(120, 180, 220), M.Glass, { Transparency = 0.3 })
	local boomLen = 34
	for _, x in ipairs({ -1, 1 }) do
		B.part(g, "Boom", Vector3.new(0.6, 0.6, boomLen), o * CFrame.new(x, H + 4.6, -boomLen / 2 + 2), yel, M.Metal)
	end
	for k = 0, 10 do
		B.part(g, "BoomRung", Vector3.new(2.4, 0.4, 0.4), o * CFrame.new(0, H + 4.6, 2 - k * 3.2), yel, M.Metal)
	end
	B.part(g, "Counterweight", Vector3.new(4.5, 3.5, 5), o * CFrame.new(0, H + 3.6, 8), C.concrete, M.Concrete)
	local hookZ = -boomLen + 6
	local cableTop = H + 4.3
	local magnetY = L - pos.Y + 14
	local cable = cableTop - magnetY
	B.part(g, "Cable", Vector3.new(0.25, cable, 0.25), o * CFrame.new(0, magnetY + cable / 2, hookZ), C.metalDark, M.Metal, { CanCollide = false })
	B.vcyl(g, "Magnet", 1.6, 6, o * CFrame.new(0, magnetY, hookZ), rgb(40, 42, 48), M.Metal)
	B.vcyl(g, "MagnetTop", 0.4, 6.2, o * CFrame.new(0, magnetY + 0.9, hookZ), rgb(220, 50, 50), M.SmoothPlastic)
	local beacon = B.ball(g, "Beacon", 1, o * CFrame.new(0, H + 5, -1), rgb(255, 60, 40), M.Neon)
	B.light(beacon, "PointLight", { Range = 14, Brightness = 2, Color = rgb(255, 60, 40) })
	B.tag(beacon, "Pulse", { Speed = 2 })
	return g, (o * CFrame.new(0, 0, hookZ)).Position
end

function Z.build(ctx)
	local m, rng, occ, L = ctx.model, ctx.rng, ctx.occ, ctx.L
	local zone = ctx.zone
	local deco = B.model(m, "Decor")

	for _ = 1, 9 do
		T.patch(rng:range(ctx.x0, ctx.x1), rng:range(zone.z1, zone.z0), L, rng:range(8, 15), M.Asphalt)
	end
	for _ = 1, 5 do
		T.patch(rng:range(ctx.x0, ctx.x1), rng:range(zone.z1, zone.z0), L, rng:range(6, 10), M.Concrete)
	end
	-- дорога из ворот в ворота
	local road = { Vector3.new(0, L, zone.z0), Vector3.new(-18, L, zone.z0 - 60), Vector3.new(18, L, zone.z0 - 130), Vector3.new(0, L, zone.z1) }
	T.trail(road, L, 12, M.Asphalt)
	for i = 1, #road - 1 do occ:addLine(road[i], road[i + 1], 8) end

	-- гигантская голова — ориентир
	do
		local x, z = occ:find(rng, 30, ctx.x1 - 10, ctx.z0 - 20, ctx.z1 + 40, 20, 60)
		if x then
			T.ball(x, L - 8, z, 18, M.Ground)
			giantHead(deco, Vector3.new(x, L - 4, z), rng:range(-0.6, 0.6) + math.pi * 0.1)
			occ:add(x, z, 20)
		end
	end
	-- кран над горой машин
	do
		local x, z = occ:find(rng, ctx.x0 + 10, -30, ctx.z0, ctx.z1, 10, 60)
		if x then
			local yaw = rng:range(-0.5, 0.5) + math.pi
			local _, hook = crane(deco, Vector3.new(x, L, z), yaw, L)
			occ:add(x, z, 6)
			-- машины под магнитом
			for i = 0, 2 do
				car(deco, rng, CFrame.new(hook.X + rng:range(-1, 1), L + i * 3.6, hook.Z + rng:range(-1, 1)) * CFrame.Angles(0, rng:angle(), rng:range(-0.05, 0.05)))
			end
			occ:add(hook.X, hook.Z, 7)
		end
	end
	-- горы хлама
	for _ = 1, 10 do
		local R = rng:range(7, 11)
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, R + 1)
		if x then
			scrapPile(deco, rng, Vector3.new(x, L, z), R)
			occ:add(x, z, R)
		end
	end
	-- сломанные роботы
	local poses = { "sitting", "lying", "tilted", "sitting", "lying", "tilted" }
	for i = 1, 6 do
		local s = rng:range(0.8, 1.3)
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 7 * s)
		if x then
			robot(deco, rng, Vector3.new(x, L, z), rng:angle(), s, poses[i])
			occ:add(x, z, 7 * s)
		end
	end
	-- машины, покрышки, бочки, лужи масла
	for _ = 1, 6 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 7)
		if x then
			local yaw = rng:angle()
			car(deco, rng, CFrame.new(x, L, z) * CFrame.Angles(0, yaw, 0))
			if rng:chance(0.4) then
				car(deco, rng, CFrame.new(x, L + 3.6, z) * CFrame.Angles(0, yaw + rng:range(-0.4, 0.4), rng:range(-0.1, 0.1)))
			end
			occ:add(x, z, 6.5)
		end
	end
	for _ = 1, 9 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 3)
		if x then
			local g = B.model(deco, "Tires")
			for k = 0, rng:int(2, 5) do
				B.vcyl(g, "Tire", 1, 3.2, CFrame.new(x + rng:range(-0.3, 0.3), L + 0.5 + k, z + rng:range(-0.3, 0.3)), rgb(30, 30, 32), M.SmoothPlastic)
			end
			occ:add(x, z, 2.5)
		end
	end
	for _ = 1, 7 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 4)
		if x then
			for k = 1, rng:int(2, 4) do
				local a = k * 2.1
				P.barrel(deco, CFrame.new(x + math.cos(a) * 2, L, z + math.sin(a) * 2), rng:pick({ rgb(150, 80, 50), rgb(60, 110, 160), rgb(200, 170, 50) }), rng:chance(0.25))
			end
			B.vcyl(deco, "OilPuddle", 0.1, rng:range(4, 7), CFrame.new(x + 3, L + 0.05, z + 2), rgb(20, 20, 24), M.SmoothPlastic,
				{ Reflectance = 0.4, CanCollide = false })
			occ:add(x, z, 4)
		end
	end
	-- заборы из профнастила вдоль склонов
	for _, side in ipairs({ -1, 1 }) do
		local z = zone.z0 - 24
		while z > zone.z1 + 30 do
			if rng:chance(0.7) then
				local cf = CFrame.new(side * 100, L, z) * CFrame.Angles(0, math.rad(90 + rng:range(-8, 8)), math.rad(rng:range(-6, 6)))
				B.part(deco, "FencePanel", Vector3.new(6, 8, 0.3), cf * CFrame.new(0, 4, 0), rng:pick({ rgb(140, 150, 156), rgb(150, 90, 60), rgb(90, 120, 110) }), M.CorrodedMetal)
			end
			z = z - 6.5
		end
	end
	P.signpost(deco, CFrame.new(16, L, zone.z0 - 14) * CFrame.Angles(0, math.rad(-20), 0), "СВАЛКА РОБОТОВ", "Шестерёнки, батарейки, микросхемы", zone.accent, 14, 4)
	occ:add(16, zone.z0 - 14, 7)
end

return Z
