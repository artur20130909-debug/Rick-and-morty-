-- Остальной остров: разбившаяся летающая тарелка с бороздой в земле, пирс с лодкой,
-- парящие островки в небе, деревья, камни и цветы между постройками.
local RS = game:GetService("ReplicatedStorage")
local B = require(RS.Shared.Build)
local D = require(RS.Shared.MapData)
local Rng = require(RS.Shared.Rng)
local P = require(script.Parent.Props)
local T = require(script.Parent.Terrain)

local Island = {}
local rgb = P.rgb
local M = Enum.Material

local function ufo(m, rng)
	local g = B.model(m, "CrashedUFO")
	local c = D.Ufo.center
	local yaw = math.rad(35)
	local base = CFrame.new(c) * CFrame.Angles(0, yaw, 0)
	-- борозда: тарелка прилетела с северо-запада и пропахала землю
	local trench = base * CFrame.new(0, -1.2, -34)
	T.slab(trench, Vector3.new(20, 5, 56), M.Air)
	T.slab(trench * CFrame.new(0, -2.5, 0), Vector3.new(22, 1.2, 58), M.Ground)
	T.ball(c.X, 12, c.Z, 16, M.Air)
	T.cyl(c.X, c.Z, -5, -3.6, 9, M.Ground)
	-- корпус
	local hull = base * CFrame.new(0, 1.5, 0) * CFrame.Angles(math.rad(13), 0, math.rad(-8))
	B.ellipsoid(g, "Saucer", Vector3.new(40, 8, 40), hull, rgb(170, 180, 190), M.Metal)
	B.ellipsoid(g, "Belly", Vector3.new(30, 6, 30), hull * CFrame.new(0, -2, 0), rgb(110, 116, 126), M.Metal)
	B.ring(g, "Rim", hull, 19.6, 30, 1, 1.6, rgb(130, 138, 150), M.Metal)
	local colors = { rgb(255, 80, 80), rgb(80, 255, 120), rgb(80, 180, 255), rgb(255, 220, 80) }
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local lamp = B.ball(g, "RimLight", 1.4, hull * CFrame.new(math.cos(a) * 19.8, 0.5, math.sin(a) * 19.8), colors[i % 4 + 1], M.Neon)
		B.tag(lamp, "Pulse", { Speed = 1 + (i % 3) * 0.5 })
	end
	B.ellipsoid(g, "Dome", Vector3.new(16, 10, 16), hull * CFrame.new(0, 3.4, 0), rgb(170, 255, 230), M.Glass, { Transparency = 0.45 })
	-- пилот внутри
	local seat = hull * CFrame.new(0, 3.6, 0)
	B.ellipsoid(g, "AlienBody", Vector3.new(2.2, 3, 2), seat, rgb(120, 220, 110), M.SmoothPlastic)
	B.ellipsoid(g, "AlienHead", Vector3.new(3, 3.4, 3), seat * CFrame.new(0, 2.8, 0), rgb(130, 230, 120), M.SmoothPlastic)
	for _, s in ipairs({ -1, 1 }) do
		B.ellipsoid(g, "AlienEye", Vector3.new(1, 1.4, 0.4), seat * CFrame.new(s * 0.7, 3, -1.35) * CFrame.Angles(0, 0, s * 0.4), Color3.new(0, 0, 0), M.Glass)
	end
	local glow = B.marker(g, "Glow", Vector3.new(1, 1, 1), hull * CFrame.new(0, 6, 0))
	B.light(glow, "PointLight", { Range = 26, Brightness = 1.5, Color = rgb(150, 255, 210) })
	-- опоры и обломки
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2 + 0.4
		local top = hull * Vector3.new(math.cos(a) * 12, -3, math.sin(a) * 12)
		B.between(g, "Leg", top, top + Vector3.new(math.cos(a + yaw) * 4, -3, math.sin(a + yaw) * 4), 0.9, rgb(130, 138, 150), M.Metal, true)
	end
	for _ = 1, 10 do
		local p = (trench * CFrame.new(rng:range(-12, 12), 0, rng:range(-26, 26))).Position
		B.part(g, "Debris", Vector3.new(rng:range(1.5, 4), 0.3, rng:range(1, 3)), CFrame.new(p.X, -2.9, p.Z) * CFrame.Angles(rng:range(-0.4, 0.4), rng:angle(), rng:range(-0.4, 0.4)),
			rgb(150, 160, 170), M.Metal)
	end
	local smoke = B.marker(g, "Smoke", Vector3.new(6, 1, 6), hull * CFrame.new(10, 2, 6))
	B.particles(smoke, {
		Color = ColorSequence.new(rgb(90, 90, 96), rgb(160, 160, 170)), Size = NumberSequence.new(3, 10),
		Transparency = NumberSequence.new(0.5, 1), Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(3, 6),
		Rate = 4, LightEmission = 0, LightInfluence = 1, RotSpeed = NumberRange.new(-20, 20), Rotation = NumberRange.new(0, 360),
		EmissionDirection = Enum.NormalId.Top,
	})
	local sparkMk = B.marker(g, "Sparks", Vector3.new(1, 1, 1), hull * CFrame.new(-14, 1, -8))
	B.particles(sparkMk, {
		Color = ColorSequence.new(rgb(140, 255, 255)), Size = NumberSequence.new(0.3, 0), Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(5, 10), SpreadAngle = Vector2.new(50, 50), Rate = 4,
		LightEmission = 1, Acceleration = Vector3.new(0, -25, 0),
	})
	P.signpost(g, base * CFrame.new(-18, 0, 20) * CFrame.Angles(0, math.rad(200), 0), "НЕ ТРОГАТЬ!", "Тарелка в ремонте", rgb(150, 255, 210), 11, 4)
	return g
end

local function pier(m, rng)
	local g = B.model(m, "Pier")
	local x, z0, z1 = 70, D.Island[1][4] - 8, D.Island[1][4] + 74
	local y = 1.6
	for z = z0, z1, 1.6 do
		B.part(g, "Plank", Vector3.new(8, 0.4, 1.4), CFrame.new(x + rng:range(-0.1, 0.1), y, z) * CFrame.Angles(0, math.rad(rng:range(-2, 2)), 0),
			rng:pick({ rgb(126, 96, 66), rgb(112, 84, 58), rgb(136, 104, 72) }), M.WoodPlanks)
	end
	for z = z0, z1, 8 do
		for _, dx in ipairs({ -3.6, 3.6 }) do
			B.part(g, "Pile", Vector3.new(0.9, 14, 0.9), CFrame.new(x + dx, y - 6.5, z), rgb(90, 70, 50), M.Wood)
		end
	end
	for _, dx in ipairs({ -3.6, 3.6 }) do
		P.lamp(g, Vector3.new(x + dx, y + 0.2, z1 - 1), rgb(255, 210, 120), 8)
	end
	-- лодка у конца пирса покачивается на волнах
	local boat = B.model(g, "Boat")
	local bc = CFrame.new(x + 9, D.SEA + 0.6, z1 - 10)
	B.part(boat, "Hull", Vector3.new(5, 2.4, 12), bc, rgb(220, 80, 70), M.WoodPlanks)
	B.wedge(boat, "Bow", Vector3.new(5, 2.4, 4), bc * CFrame.new(0, 0, -8) * CFrame.Angles(0, 0, math.pi), rgb(220, 80, 70), M.WoodPlanks)
	B.part(boat, "Trim", Vector3.new(5.2, 0.4, 12.2), bc * CFrame.new(0, 1.2, 0), rgb(245, 245, 245), M.WoodPlanks)
	B.part(boat, "Seat", Vector3.new(4.6, 0.4, 1.4), bc * CFrame.new(0, 0.8, 2), rgb(150, 110, 70), M.WoodPlanks)
	boat.WorldPivot = bc
	B.tag(boat, "Bob", { Height = 0.35, Period = 3.5 })
	return g
end

local function floatingIsland(m, rng, pos, s)
	local g = B.model(m, "FloatingIsland")
	B.vcyl(g, "Top", 3, 30 * s, CFrame.new(pos), rgb(100, 180, 90), M.Grass)
	local y = pos.Y - 1.5
	for i, d in ipairs({ 27, 20, 12, 5 }) do
		local h = 4 + i
		B.vcyl(g, "Rock", h, d * s, CFrame.new(pos.X + rng:range(-1, 1), y - h / 2, pos.Z + rng:range(-1, 1)), rgb(110 - i * 6, 104 - i * 6, 100 - i * 6), M.Slate)
		y = y - h
	end
	P.tree(g, pos + Vector3.new(rng:range(-4, 4), 1.5, rng:range(-4, 4)), rng, s, rng:pick(P.TreePalettes))
	for _ = 1, 3 do
		local a = rng:angle()
		P.crystal(g, pos + Vector3.new(math.cos(a) * 7 * s, -6, math.sin(a) * 7 * s), Vector3.new(math.cos(a) * 0.3, -1, math.sin(a) * 0.3),
			rng:range(3, 6), 1.4, rng:pick({ rgb(80, 230, 255), rgb(190, 110, 255) }))
	end
	local mist = B.marker(g, "Mist", Vector3.new(20 * s, 1, 20 * s), CFrame.new(pos.X, y, pos.Z))
	B.particles(mist, {
		Color = ColorSequence.new(rgb(240, 245, 255)), Size = NumberSequence.new(4, 8), Transparency = NumberSequence.new(0.7, 1),
		Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(1, 2), Rate = 2, LightInfluence = 1, LightEmission = 0,
		EmissionDirection = Enum.NormalId.Bottom,
	})
	g.WorldPivot = CFrame.new(pos)
	B.tag(g, "Bob", { Height = 2, Period = rng:range(8, 11) })
	return g
end

-- занятые места на центральном острове (деревья туда не ставим)
local function occupied()
	local occ = P.newOcc()
	occ:add(0, 0, D.HUB_R + 22)
	for i = 1, D.Plots.count do
		local a = 180 - D.Plots.spread / 2 + (i - 1) * D.Plots.spread / (D.Plots.count - 1)
		local p = P.compass(a) * D.Plots.radius
		occ:add(p.X, p.Z, D.Plots.size * 0.78)
	end
	for a = 110, 250, 6 do
		local p = P.compass(a) * 125
		occ:add(p.X, p.Z, 11)
	end
	occ:addLine(Vector3.new(0, 0, -80), Vector3.new(0, 0, D.Zones[1].z0), 18)
	occ:addLine(Vector3.new(80, 0, 0), Vector3.new(200, 0, 0), 16)
	occ:addLine(Vector3.new(-80, 0, 0), Vector3.new(-200, 0, 0), 16)
	occ:add(D.Rebirth.center.X, D.Rebirth.center.Z, 40)
	occ:add(D.Ufo.center.X, D.Ufo.center.Z, 32)
	occ:addLine(D.Ufo.center, D.Ufo.center + Vector3.new(math.sin(math.rad(35)) * -60, 0, math.cos(math.rad(35)) * -60), 16)
	occ:add(70, D.Island[1][4], 16)
	for _, s in ipairs({ { -300, -75 }, { -305, 105 }, { -95, 295 }, { 95, 295 } }) do occ:add(s[1], s[2], 24) end
	-- южная кромка первой зоны (хребет) и арка
	occ:addLine(Vector3.new(-160, 0, D.Zones[1].z0), Vector3.new(160, 0, D.Zones[1].z0), 22)
	return occ
end

function Island.build(root)
	local m = B.model(root, "Island")
	local rng = Rng.new(4242)
	ufo(m, rng)
	pier(m, rng)
	floatingIsland(m, rng, Vector3.new(520, 75, 110), 1)
	floatingIsland(m, rng, Vector3.new(-440, 85, -240), 0.8)
	floatingIsland(m, rng, Vector3.new(-470, 65, 330), 0.6)

	local occ = occupied()
	local deco = B.model(m, "Nature")
	local hub = D.Island[1]
	local function spot(r)
		-- центральный остров западнее реки или перешеек к первой зоне
		if rng:chance(0.8) then
			return occ:find(rng, hub[1] + 15, D.River.x - D.River.width / 2 - 12, hub[3] + 15, hub[4] - 15, r, 30)
		end
		return occ:find(rng, -160, 160, D.Zones[1].z0 + 10, hub[3] + 10, r, 30)
	end
	for _ = 1, 36 do
		local x, z = spot(7)
		if x then
			P.tree(deco, Vector3.new(x, 0, z), rng, rng:range(0.9, 1.4))
			occ:add(x, z, 6)
		end
	end
	for _ = 1, 18 do
		local x, z = spot(4)
		if x then
			P.rock(deco, Vector3.new(x, 0, z), rng:range(3, 7), rng)
			occ:add(x, z, 4)
		end
	end
	for _ = 1, 18 do
		local x, z = spot(4)
		if x then
			P.flowers(deco, Vector3.new(x, 0, z), rng, 12, { rgb(255, 120, 200), rgb(120, 220, 255), rgb(255, 230, 90), rgb(200, 130, 255) }, 4)
			occ:add(x, z, 4)
		end
	end
	return m
end

return Island
