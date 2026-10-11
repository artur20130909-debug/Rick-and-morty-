-- Лаборатории игроков: 6 участков дугой к югу от площади. На каждом — здание лаборатории,
-- загон для мутантов, свой котёл, площадка «занять лабораторию» и табличка владельца.
-- Логика (кто владеет) появится позже: она найдёт участки по атрибутам PlotId / Owner.
local RS = game:GetService("ReplicatedStorage")
local B = require(RS.Shared.Build)
local D = require(RS.Shared.MapData)
local Rng = require(RS.Shared.Rng)
local P = require(script.Parent.Props)

local Plots = {}
local C, rgb = P.C, P.rgb
local M = Enum.Material

local ACCENTS = { rgb(60, 220, 190), rgb(170, 90, 255), rgb(255, 150, 50), rgb(255, 90, 170), rgb(150, 230, 60), rgb(70, 160, 255) }
local BASE = 1.2 -- верх площадки участка

-- линия забора в локальных координатах участка
local function fenceLocal(m, cf, a, b, color)
	P.fence(m, cf * a, cf * b, 3.5, color, M.SmoothPlastic, 6)
end

local function labBuilding(m, cf, accent, rng)
	local bm = B.model(m, "LabBuilding")
	local w, d, h = 22, 18, 12
	local o = cf * CFrame.new(11, BASE, 11) -- центр пола здания
	local function wpt(x, z) return o * Vector3.new(x, 0, z) end
	local wallCol, wallMat = rgb(232, 236, 240), M.SmoothPlastic
	-- передняя стена с дверью и окнами
	B.wall(bm, "Front", wpt(-w / 2, -d / 2), wpt(w / 2, -d / 2), h, 1, wallCol, wallMat, {
		{ at = w / 2, w = 6, y0 = 0, y1 = 8 },
		{ at = 4, w = 4, y0 = 4, y1 = 8.5 },
		{ at = w - 4, w = 4, y0 = 4, y1 = 8.5 },
	})
	B.wall(bm, "Back", wpt(w / 2, d / 2), wpt(-w / 2, d / 2), h, 1, wallCol, wallMat)
	B.wall(bm, "Left", wpt(-w / 2, d / 2), wpt(-w / 2, -d / 2), h, 1, wallCol, wallMat, { { at = d / 2, w = 6, y0 = 4, y1 = 8.5 } })
	B.wall(bm, "Right", wpt(w / 2, -d / 2), wpt(w / 2, d / 2), h, 1, wallCol, wallMat, { { at = d / 2, w = 6, y0 = 4, y1 = 8.5 } })
	-- стёкла
	for _, x in ipairs({ -w / 2 + 4, w / 2 - 4 }) do
		B.part(bm, "Window", Vector3.new(4, 4.5, 0.3), o * CFrame.new(x, 6.25, -d / 2), rgb(170, 230, 255), M.Glass, { Transparency = 0.5 })
	end
	for _, x in ipairs({ -w / 2, w / 2 }) do
		B.part(bm, "Window", Vector3.new(0.3, 4.5, 6), o * CFrame.new(x, 6.25, 0), rgb(170, 230, 255), M.Glass, { Transparency = 0.5 })
	end
	B.part(bm, "Floor", Vector3.new(w, 0.3, d), o * CFrame.new(0, 0.15, 0), rgb(90, 96, 110), M.DiamondPlate)
	B.part(bm, "Roof", Vector3.new(w + 2, 1, d + 2), o * CFrame.new(0, h + 0.5, 0), rgb(60, 66, 78), M.Metal)
	B.part(bm, "Stripe", Vector3.new(w + 0.2, 0.6, d + 0.2), o * CFrame.new(0, 9.6, 0), accent, M.Neon)
	-- вывеска над дверью
	local sign = B.part(bm, "Sign", Vector3.new(12, 2.6, 0.5), o * CFrame.new(0, 10.4, -d / 2 - 0.8), rgb(30, 34, 44), M.SmoothPlastic)
	P.board(sign, Enum.NormalId.Front, "ЛАБОРАТОРИЯ", nil, accent, rgb(30, 34, 44))
	-- на крыше: тарелка антенны, трубы, бак
	local dishBase = o * CFrame.new(6, h + 1, 4)
	B.vcyl(bm, "DishPole", 3, 0.6, dishBase * CFrame.new(0, 1.5, 0), C.metal, M.Metal)
	B.ellipsoid(bm, "Dish", Vector3.new(5, 1.4, 5), dishBase * CFrame.new(0, 3.4, 0) * CFrame.Angles(math.rad(-35), math.rad(rng:range(-40, 40)), 0),
		C.metalLight, M.Metal)
	for i = 1, 2 do
		B.vcyl(bm, "Vent", 4, 1.4, o * CFrame.new(-7 + i * 2.4, h + 3, 5), C.metalDark, M.Metal)
	end
	P.tank(bm, (o * CFrame.new(-5, h + 1, -3)).Position, 4, 3, accent, false)
	-- внутри: стол и полки с колбами
	B.part(bm, "Desk", Vector3.new(8, 3, 3), o * CFrame.new(-5, 1.8, 6), rgb(200, 205, 215), M.SmoothPlastic)
	B.part(bm, "Shelf", Vector3.new(8, 6, 1.6), o * CFrame.new(5, 3.3, 7.8), C.woodDark, M.WoodPlanks)
	for i = 0, 4 do
		B.ball(bm, "Flask", 1, o * CFrame.new(2 + i * 1.5, 5.2, 7.6), rng:pick({ C.slime, C.labPurple, C.labTeal, rgb(255, 120, 80) }), M.Neon)
	end
	return bm
end

local function petPen(m, cf, accent)
	local pm = B.model(m, "PetPen")
	local o = cf * CFrame.new(-13, BASE, 11)
	B.part(pm, "Grass", Vector3.new(24, 0.3, 22), o * CFrame.new(0, 0.15, 0), rgb(100, 180, 80), M.Grass)
	local fc = rgb(245, 245, 245)
	fenceLocal(pm, o, Vector3.new(-12, 0, -11), Vector3.new(-3, 0, -11), fc)
	fenceLocal(pm, o, Vector3.new(3, 0, -11), Vector3.new(12, 0, -11), fc)
	fenceLocal(pm, o, Vector3.new(12, 0, -11), Vector3.new(12, 0, 11), fc)
	fenceLocal(pm, o, Vector3.new(12, 0, 11), Vector3.new(-12, 0, 11), fc)
	fenceLocal(pm, o, Vector3.new(-12, 0, 11), Vector3.new(-12, 0, -11), fc)
	-- миска, домик-капсула и игрушка
	B.vcyl(pm, "Bowl", 0.8, 3, o * CFrame.new(-6, 0.7, -6), accent, M.SmoothPlastic)
	B.vcyl(pm, "Food", 0.2, 2.4, o * CFrame.new(-6, 1.05, -6), C.slime, M.Neon)
	B.ellipsoid(pm, "PodHouse", Vector3.new(8, 6, 7), o * CFrame.new(5, 3, 5), rgb(235, 240, 245), M.SmoothPlastic)
	B.part(pm, "PodDoor", Vector3.new(3, 3.6, 0.4), o * CFrame.new(5, 1.9, 1.5), rgb(40, 44, 54), M.SmoothPlastic)
	B.ball(pm, "Ball", 1.8, o * CFrame.new(-2, 1.2, 4), rgb(255, 90, 90), M.SmoothPlastic)
	local area = B.marker(pm, "PetArea", Vector3.new(22, 6, 20), o * CFrame.new(0, 3, 0))
	B.attrs(area, { Role = "PetArea" })
	return pm
end

local function buildPlot(root, i, angle, rng)
	local accent = ACCENTS[(i - 1) % #ACCENTS + 1]
	local c = P.compass(angle) * D.Plots.radius
	local cf = P.facing(Vector3.new(c.X, 0, c.Z), Vector3.zero)
	local S = D.Plots.size
	local m = B.model(root, "Plot" .. i)
	B.attrs(m, { PlotId = i, Owner = 0 })
	m.WorldPivot = cf

	B.part(m, "Base", Vector3.new(S, BASE, S), cf * CFrame.new(0, BASE / 2, 0), rgb(176, 182, 188), M.Concrete)
	B.part(m, "Trim", Vector3.new(S + 0.6, 0.3, S + 0.6), cf * CFrame.new(0, 0.3, 0), accent, M.Neon)
	-- дорожка от входа к зданию
	B.part(m, "Walk", Vector3.new(6, 0.1, S / 2 + 2), cf * CFrame.new(11, BASE + 0.05, -S / 4 + 1), rgb(120, 126, 136), M.Slate)

	labBuilding(m, cf, accent, rng)
	petPen(m, cf, accent)

	-- забор по краю, проход спереди
	local h = S / 2
	local fc = rgb(70, 76, 88)
	P.fence(m, cf * Vector3.new(-h, BASE, -h), cf * Vector3.new(-8, BASE, -h), 3, fc, M.Metal, 6)
	P.fence(m, cf * Vector3.new(8, BASE, -h), cf * Vector3.new(h, BASE, -h), 3, fc, M.Metal, 6)
	P.fence(m, cf * Vector3.new(h, BASE, -h), cf * Vector3.new(h, BASE, h), 3, fc, M.Metal, 6)
	P.fence(m, cf * Vector3.new(h, BASE, h), cf * Vector3.new(-h, BASE, h), 3, fc, M.Metal, 6)
	P.fence(m, cf * Vector3.new(-h, BASE, h), cf * Vector3.new(-h, BASE, -h), 3, fc, M.Metal, 6)
	-- ворота с номером
	for _, x in ipairs({ -8, 8 }) do
		B.part(m, "GatePost", Vector3.new(1.6, 9, 1.6), cf * CFrame.new(x, BASE + 4.5, -h), C.metalDark, M.Metal)
		local orb = B.ball(m, "GateOrb", 1.8, cf * CFrame.new(x, BASE + 9.8, -h), accent, M.Neon)
		B.light(orb, "PointLight", { Range = 14, Brightness = 1.2, Color = accent })
	end
	local plate = B.part(m, "NumberPlate", Vector3.new(14, 2.4, 0.6), cf * CFrame.new(0, BASE + 8, -h), rgb(30, 34, 44), M.SmoothPlastic)
	P.board(plate, Enum.NormalId.Front, "ЛАБОРАТОРИЯ №" .. i, nil, accent, rgb(30, 34, 44))
	P.board(plate, Enum.NormalId.Back, "ЛАБОРАТОРИЯ №" .. i, nil, accent, rgb(30, 34, 44))

	-- площадка «занять» и табличка владельца
	local pad = B.vcyl(m, "ClaimPad", 0.3, 8, cf * CFrame.new(0, BASE + 0.15, -16), accent, M.Neon)
	B.attrs(pad, { Role = "ClaimPad" })
	B.ring(m, "ClaimRing", cf * CFrame.new(0, BASE + 0.2, -16), 4.6, 20, 0.4, 0.5, C.white, M.SmoothPlastic)
	local owner = P.signpost(m, cf * CFrame.new(0, BASE, -22) * CFrame.Angles(0, math.pi, 0), "СВОБОДНО", "Встань на круг, чтобы занять", accent, 12, 4)
	owner.Name = "OwnerSign"
	local spawnMk = B.marker(m, "PlotSpawn", Vector3.new(4, 1, 4), cf * CFrame.new(0, BASE + 3, -10) * CFrame.Angles(0, math.pi, 0))
	B.attrs(spawnMk, { Role = "PlotSpawn" })

	-- свой котёл
	local mixer = cf * CFrame.new(-13, BASE, -12)
	B.vcyl(m, "MixerStand", 1, 7.4, mixer * CFrame.new(0, 0.5, 0), C.metalDark, M.DiamondPlate)
	B.vcyl(m, "Mixer", 4, 6, mixer * CFrame.new(0, 3, 0), rgb(50, 56, 66), M.Metal)
	local goo = B.vcyl(m, "MixerGoo", 0.3, 5.2, mixer * CFrame.new(0, 4.9, 0), accent, M.Neon)
	B.light(goo, "PointLight", { Range = 12, Brightness = 1.4, Color = accent })
	B.particles(goo, {
		Color = ColorSequence.new(Color3.new(1, 1, 1)), Size = NumberSequence.new(0.5, 0.1),
		Transparency = NumberSequence.new(0.3, 1), Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(1, 3), Rate = 5,
	})
	local mst = B.marker(m, "PlotMixer", Vector3.new(10, 6, 10), mixer * CFrame.new(0, 3, 0))
	B.attrs(mst, { Station = "PlotMixer" })

	-- мелочи
	P.barrel(m, cf * CFrame.new(23, BASE, -2), rgb(230, 190, 40), true)
	P.barrel(m, cf * CFrame.new(20, BASE, -4.5), rgb(60, 140, 220), false)
	P.crate(m, cf * CFrame.new(22, BASE, -9) * CFrame.Angles(0, 0.3, 0), 4)
	P.crate(m, cf * CFrame.new(22, BASE + 4, -9) * CFrame.Angles(0, -0.2, 0), 3)
	P.lamp(m, (cf * CFrame.new(-23, BASE, -23)).Position, accent, 10)
	P.lamp(m, (cf * CFrame.new(23, BASE, -23)).Position, accent, 10)
	return m
end

function Plots.build(root)
	local folder = B.folder(root, "Plots")
	local rng = Rng.new(606)
	local n, spread = D.Plots.count, D.Plots.spread
	for i = 1, n do
		local a = 180 - spread / 2 + (i - 1) * spread / (n - 1)
		buildPlot(folder, i, a, rng)
	end
	-- кольцевая дорога и отводы к участкам
	local roads = B.model(folder, "Roads")
	local rr = 125
	P.arcPath(roads, Vector3.zero, rr, 180 - spread / 2 - 10, 180 + spread / 2 + 10, 12, 0.3, nil, nil, 5)
	for i = 1, n do
		local a = 180 - spread / 2 + (i - 1) * spread / (n - 1)
		local p0 = P.compass(a) * (rr + 5)
		local p1 = P.compass(a) * (D.Plots.radius - D.Plots.size / 2 - 0.5)
		P.path(roads, Vector3.new(p0.X, 0.3, p0.Z), Vector3.new(p1.X, 0.3, p1.Z), 10)
	end
	for k = 0, 9 do
		local a = 180 - spread / 2 - 6 + k * (spread + 12) / 9
		local p = P.compass(a) * (rr - 9)
		P.lamp(roads, Vector3.new(p.X, 0, p.Z), C.labTeal, 10)
	end
	return folder
end

return Plots
