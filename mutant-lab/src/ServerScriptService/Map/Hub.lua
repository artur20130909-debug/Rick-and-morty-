-- Центральная площадь «Лаб-Сити»: Великий Мутатор (котёл для смешивания), точка появления,
-- магазины по кругу, доски лидеров, арки-выходы на все четыре стороны, дорожки и фонари.
local RS = game:GetService("ReplicatedStorage")
local B = require(RS.Shared.Build)
local D = require(RS.Shared.MapData)
local Rng = require(RS.Shared.Rng)
local P = require(script.Parent.Props)

local Hub = {}
local C, rgb = P.C, P.rgb
local M = Enum.Material

local R = D.HUB_R
local FLOOR = 1 -- верх пола площади

local function polar(deg, r, y)
	local d = P.compass(deg) * r
	return Vector3.new(d.X, y or FLOOR, d.Z)
end

local function buildFloor(m)
	B.vcyl(m, "FloorOuter", 1, R * 2 + 4, CFrame.new(0, 0.5, 0), rgb(186, 192, 196), M.Concrete)
	B.vcyl(m, "FloorMid", 1.06, 124, CFrame.new(0, 0.53, 0), rgb(150, 160, 170), M.Pavement)
	B.vcyl(m, "FloorInner", 1.12, 70, CFrame.new(0, 0.56, 0), rgb(92, 100, 114), M.Slate)
	-- светящиеся кольца в полу
	B.ring(m, "NeonRing", CFrame.new(0, 1.07, 0), 61, 64, 0.12, 0.9, C.labTeal, M.Neon)
	B.ring(m, "NeonRing", CFrame.new(0, 1.13, 0), 34.5, 40, 0.12, 0.7, C.labPurple, M.Neon)
	-- лучи от ворот к центру
	for _, a in ipairs({ 0, 90, 180, 270 }) do
		local a0, a1 = polar(a, 36, 1.14), polar(a, R, 1.08)
		local flat = a1 - a0
		B.part(m, "NeonLine", Vector3.new(0.7, 0.1, flat.Magnitude), CFrame.lookAt((a0 + a1) / 2, a1), C.labTeal, M.Neon)
	end
	-- бордюр с проходами у ворот
	local function nearGate(a)
		for _, g in ipairs({ 0, 90, 180, 270, 360 }) do
			if math.abs(a - g) < 9 then return true end
		end
		return false
	end
	B.ring(m, "Curb", CFrame.new(0, 1.3, 0), R + 1.5, 72, 1.6, 2.4, C.stoneDark, M.Slate, nearGate)
	B.ring(m, "CurbTrim", CFrame.new(0, 2.15, 0), R + 1.5, 72, 0.2, 2.6, C.labTeal, M.Neon, nearGate)
end

---------------------------------------------------------------------------
-- Великий Мутатор
---------------------------------------------------------------------------
local function mutator(parent)
	local m = B.model(parent, "GreatMutator")
	B.vcyl(m, "Step1", 1.5, 42, CFrame.new(0, 0.75 + 0.5, 0), C.metalDark, M.DiamondPlate)
	B.vcyl(m, "Step2", 1.2, 35, CFrame.new(0, 2 + 0.6, 0), C.metal, M.DiamondPlate)
	B.ring(m, "StepGlow", CFrame.new(0, 2.05, 0), 20.6, 40, 0.15, 0.6, C.toxic, M.Neon)
	local top = 3.2
	-- котёл
	B.vcyl(m, "Cauldron", 9, 22, CFrame.new(0, top + 4.5, 0), rgb(46, 52, 62), M.Metal)
	B.vcyl(m, "Band", 1, 22.6, CFrame.new(0, top + 2, 0), C.metalLight, M.Metal)
	B.vcyl(m, "Band", 1, 22.6, CFrame.new(0, top + 6.5, 0), C.metalLight, M.Metal)
	B.ring(m, "Rim", CFrame.new(0, top + 9.3, 0), 11.2, 36, 1.2, 1.8, C.metalLight, M.Metal)
	for i = 0, 7 do
		local p = polar(i * 45 + 22.5, 11.2, top + 4.5)
		B.part(m, "Rivet", Vector3.new(1, 7, 0.6), P.facing(p, Vector3.zero), C.metalDark, M.Metal)
	end
	local goo = B.vcyl(m, "Goo", 0.6, 20.4, CFrame.new(0, top + 8.6, 0), C.slime, M.Neon)
	B.light(goo, "PointLight", { Range = 40, Brightness = 2.5, Color = C.slime })
	B.ball(m, "Dome", 21, CFrame.new(0, top + 8.6, 0), rgb(200, 255, 230), M.Glass, { Transparency = 0.78, CastShadow = false })
	local bub = B.marker(m, "Bubbles", Vector3.new(16, 0.5, 16), CFrame.new(0, top + 9, 0))
	B.particles(bub, {
		Color = ColorSequence.new(rgb(190, 255, 150)), Size = NumberSequence.new(1, 0.2),
		Transparency = NumberSequence.new(0.2, 1), Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(2, 5),
		Rate = 12, LightEmission = 1, EmissionDirection = Enum.NormalId.Top,
	})
	-- энергоядро над куполом
	local coreY = top + 26
	local core = B.ball(m, "Core", 4.5, CFrame.new(0, coreY, 0), C.labPurple, M.Neon, { CanCollide = false })
	B.light(core, "PointLight", { Range = 30, Brightness = 2, Color = C.labPurple })
	B.tag(core, "Bob", { Height = 1, Period = 4 })
	B.billboard(core, "ВЕЛИКИЙ МУТАТОР", rgb(220, 255, 210), 7, UDim2.fromOffset(420, 70), 260)
	local holo = B.ring(m, "HoloRing", CFrame.new(0, coreY, 0) * CFrame.Angles(math.rad(18), 0, 0), 7.5, 28, 0.3, 0.3, C.labTeal, M.Neon,
		nil, { CanCollide = false, CastShadow = false })
	holo.WorldPivot = CFrame.new(0, coreY, 0) * CFrame.Angles(math.rad(18), 0, 0)
	B.tag(holo, "Spin", { Speed = 40 })
	local holo2 = B.ring(m, "HoloRing", CFrame.new(0, coreY, 0) * CFrame.Angles(math.rad(-25), 0, math.rad(15)), 9.5, 32, 0.3, 0.3, C.labPurple, M.Neon,
		nil, { CanCollide = false, CastShadow = false })
	holo2.WorldPivot = CFrame.new(0, coreY, 0) * CFrame.Angles(math.rad(-25), 0, math.rad(15))
	B.tag(holo2, "Spin", { Speed = -28 })
	local coreAtt = Instance.new("Attachment")
	coreAtt.Parent = core
	-- катушки Теслы с молниями к ядру
	for i = 0, 3 do
		local base = polar(45 + i * 90, 16, top)
		B.vcyl(m, "CoilBase", 2, 3.6, CFrame.new(base + Vector3.new(0, 1, 0)), C.metalDark, M.Metal)
		B.vcyl(m, "Coil", 11, 1.6, CFrame.new(base + Vector3.new(0, 7.5, 0)), C.metalLight, M.Metal)
		for k = 1, 4 do
			B.vcyl(m, "CoilRing", 0.5, 3.2 - k * 0.3, CFrame.new(base + Vector3.new(0, 3 + k * 2.2, 0)), rgb(200, 120, 60), M.Metal)
		end
		local orb = B.ball(m, "CoilOrb", 3, CFrame.new(base + Vector3.new(0, 14, 0)), C.labPurple, M.Neon)
		B.light(orb, "PointLight", { Range = 14, Brightness = 1.5, Color = C.labPurple })
		B.tag(orb, "Pulse", { Speed = 3 })
		local a0 = Instance.new("Attachment")
		a0.Parent = orb
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = coreAtt
		beam.Color = ColorSequence.new(rgb(220, 170, 255))
		beam.LightEmission = 1
		beam.Width0, beam.Width1 = 0.35, 0.2
		beam.Segments = 12
		beam.CurveSize0, beam.CurveSize1 = 3, -2
		beam.Transparency = NumberSequence.new(0.1, 0.3)
		beam.Parent = orb
		B.tag(beam, "Zap")
		-- труба от котла к катушке
		P.pipe(m, polar(45 + i * 90, 11.4, top + 3), base + Vector3.new(0, 3, 0), 1.2, C.metal)
	end
	-- зона «подойди к котлу»
	local st = B.marker(m, "MixerStation", Vector3.new(30, 8, 30), CFrame.new(0, top + 4, 0))
	B.attrs(st, { Station = "Mixer" })
	return m
end

---------------------------------------------------------------------------
-- Магазины
---------------------------------------------------------------------------
local function icon(m, kind, cf, accent)
	if kind == "egg" then
		local e = B.ellipsoid(m, "Egg", Vector3.new(4, 5.2, 4), cf * CFrame.new(0, 2.6, 0), rgb(250, 240, 210), M.SmoothPlastic)
		B.tag(e, "Bob", { Height = 0.5, Period = 2.5 })
		for i = 1, 6 do
			local a = i * 60
			local d = P.compass(a)
			B.ball(m, "Spot", 0.9, cf * CFrame.new(d.X * 1.8, 2.2 + (i % 2) * 1.4, d.Z * 1.8), accent, M.Neon, { CanCollide = false })
		end
	elseif kind == "gear" then
		local g = B.model(m, "Gear")
		local c = cf * CFrame.new(0, 3, 0)
		B.cyl(g, "Hub", 1, 4, c, C.metalLight, M.Metal)
		for i = 0, 7 do
			B.part(g, "Tooth", Vector3.new(1, 1.2, 1.2), c * CFrame.Angles(math.rad(i * 45), 0, 0) * CFrame.new(0, 2.3, 0), C.metalLight, M.Metal)
		end
		B.cyl(g, "Axle", 1.2, 1.4, c, accent, M.Neon)
		g.WorldPivot = c
		B.tag(g, "Spin", { Speed = 45, Axis = "X" })
	elseif kind == "backpack" then
		B.part(m, "Pack", Vector3.new(3.4, 4.4, 2), cf * CFrame.new(0, 2.4, 0), rgb(220, 90, 60), M.Fabric)
		B.part(m, "Pocket", Vector3.new(2.6, 1.8, 0.6), cf * CFrame.new(0, 1.6, -1.2), rgb(240, 160, 60), M.Fabric)
		B.vcyl(m, "Roll", 3.6, 1.4, cf * CFrame.new(0, 5.1, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(110, 80, 50), M.Fabric)
	elseif kind == "potions" then
		for i, col in ipairs({ rgb(255, 80, 120), rgb(80, 200, 255), rgb(255, 220, 60) }) do
			local x = (i - 2) * 1.8
			local b = B.ball(m, "Flask", 1.6, cf * CFrame.new(x, 1, 0), col, M.Neon)
			B.vcyl(m, "Neck", 1, 0.6, cf * CFrame.new(x, 2.1, 0), rgb(220, 240, 255), M.Glass, { Transparency = 0.3 })
			if i == 2 then B.light(b, "PointLight", { Range = 8, Color = col }) end
		end
	elseif kind == "book" then
		local c = cf * CFrame.new(0, 1.2, 0)
		B.part(m, "PageL", Vector3.new(2.4, 0.4, 3.2), c * CFrame.new(-1.25, 0, 0) * CFrame.Angles(0, 0, math.rad(12)), rgb(245, 235, 210), M.SmoothPlastic)
		B.part(m, "PageR", Vector3.new(2.4, 0.4, 3.2), c * CFrame.new(1.25, 0, 0) * CFrame.Angles(0, 0, math.rad(-12)), rgb(245, 235, 210), M.SmoothPlastic)
		B.part(m, "Cover", Vector3.new(5.4, 0.2, 3.6), c * CFrame.new(0, -0.35, 0), rgb(120, 50, 160), M.Fabric)
		local glow = B.ball(m, "Magic", 0.8, c * CFrame.new(0, 1.6, 0), accent, M.Neon, { CanCollide = false })
		B.tag(glow, "Bob", { Height = 0.4, Period = 2 })
	elseif kind == "chest" then
		B.part(m, "Chest", Vector3.new(4, 2.4, 2.6), cf * CFrame.new(0, 1.2, 0), C.wood, M.WoodPlanks)
		B.cyl(m, "Lid", 4, 2.6, cf * CFrame.new(0, 2.4, 0), C.woodDark, M.WoodPlanks)
		B.part(m, "Trim", Vector3.new(0.5, 2.5, 2.7), cf * CFrame.new(0, 1.25, 0), rgb(255, 200, 60), M.Metal)
		local lock = B.part(m, "Lock", Vector3.new(0.8, 0.8, 0.3), cf * CFrame.new(0, 1.8, -1.4), rgb(255, 210, 70), M.Neon)
		B.light(lock, "PointLight", { Range = 8, Color = rgb(255, 210, 70) })
	end
end

-- киоск: cf — центр пола, лицо (−Z) к центру площади
local function kiosk(parent, cf, id, title, sub, accent, iconKind)
	local m = B.model(parent, "Shop_" .. id)
	B.attrs(m, { Station = id })
	B.part(m, "Floor", Vector3.new(16, 0.5, 12), cf * CFrame.new(0, 0.25, 0), rgb(60, 64, 74), M.DiamondPlate)
	B.part(m, "Back", Vector3.new(16, 10, 1), cf * CFrame.new(0, 5.5, 5.5), rgb(230, 232, 236), M.SmoothPlastic)
	B.part(m, "BackStripe", Vector3.new(16.1, 1, 1.1), cf * CFrame.new(0, 3, 5.5), accent, M.Neon)
	for _, x in ipairs({ -7.5, 7.5 }) do
		B.part(m, "Side", Vector3.new(1, 10, 6), cf * CFrame.new(x, 5.5, 2.5), rgb(230, 232, 236), M.SmoothPlastic)
		B.part(m, "Post", Vector3.new(1, 11, 1), cf * CFrame.new(x, 5.5, -5.5), C.metal, M.Metal)
	end
	B.part(m, "Counter", Vector3.new(13, 3.5, 2), cf * CFrame.new(0, 2.25, -3.6), accent, M.SmoothPlastic)
	B.part(m, "CounterTop", Vector3.new(13.6, 0.4, 2.6), cf * CFrame.new(0, 4.2, -3.6), rgb(245, 245, 250), M.Marble)
	B.part(m, "Roof", Vector3.new(17, 0.8, 13), cf * CFrame.new(0, 11.4, 0), rgb(50, 54, 64), M.Metal)
	-- полосатый навес
	for i = 0, 7 do
		local x = -7.4 + i * 2.1
		B.part(m, "Awning", Vector3.new(2.12, 0.3, 4.6), cf * CFrame.new(x, 10.6, -7.6) * CFrame.Angles(math.rad(22), 0, 0),
			i % 2 == 0 and accent or C.white, M.Fabric)
	end
	local sign = B.part(m, "SignBoard", Vector3.new(15, 3.6, 0.6), cf * CFrame.new(0, 13.7, -5.6), rgb(30, 34, 44), M.SmoothPlastic)
	B.part(m, "SignTrim", Vector3.new(15.4, 0.3, 0.8), cf * CFrame.new(0, 11.8, -5.6), accent, M.Neon)
	P.board(sign, Enum.NormalId.Front, title, sub, nil, rgb(30, 34, 44))
	icon(m, iconKind, cf * CFrame.new(0, 4.4, -3.6), accent)
	icon(m, iconKind, cf * CFrame.new(0, 15.6, -5.6), accent)
	local st = B.marker(m, "Station", Vector3.new(14, 6, 8), cf * CFrame.new(0, 3, -9))
	B.attrs(st, { Station = id })
	return m
end

local function leaderboard(parent, cf, stat, title, accent)
	local m = B.model(parent, "Leaderboard_" .. stat)
	B.attrs(m, { Stat = stat })
	for _, x in ipairs({ -7.5, 7.5 }) do
		B.part(m, "Post", Vector3.new(1.2, 22, 1.2), cf * CFrame.new(x, 11, 0.6), C.metalDark, M.Metal)
	end
	local board = B.part(m, "Board", Vector3.new(15, 18, 0.8), cf * CFrame.new(0, 12, 0), rgb(24, 28, 38), M.SmoothPlastic)
	B.part(m, "Frame", Vector3.new(15.6, 0.5, 1), cf * CFrame.new(0, 21.2, 0), accent, M.Neon)
	B.part(m, "Frame", Vector3.new(15.6, 0.5, 1), cf * CFrame.new(0, 2.8, 0), accent, M.Neon)
	local g = Instance.new("SurfaceGui")
	g.Name = "Board"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 25
	g.LightInfluence = 0
	g.Parent = board
	local head = Instance.new("TextLabel")
	head.Name = "Title"
	head.BackgroundTransparency = 1
	head.Size = UDim2.fromScale(1, 0.14)
	head.Text = title
	head.TextScaled = true
	head.Font = Enum.Font.GothamBlack
	head.TextColor3 = accent
	head.Parent = g
	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.05, 0.16)
	list.Size = UDim2.fromScale(0.9, 0.82)
	list.Parent = g
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 0.1)
		row.Text = i .. ".  ———"
		row.TextScaled = true
		row.Font = Enum.Font.GothamBold
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = i == 1 and rgb(255, 215, 80) or (i == 2 and rgb(220, 225, 235) or (i == 3 and rgb(230, 160, 100) or rgb(200, 210, 220)))
		row.Parent = list
	end
	return m
end

---------------------------------------------------------------------------
local function spawnPad(parent)
	local s = Instance.new("SpawnLocation")
	s.Name = "Spawn"
	s.Anchored = true
	s.Size = Vector3.new(14, 0.4, 14)
	s.CFrame = CFrame.new(0, FLOOR + 0.2, 42)
	s.Color = rgb(40, 46, 58)
	s.Material = M.DiamondPlate
	s.Duration = 0
	s.Neutral = true
	s.TopSurface = Enum.SurfaceType.Smooth
	s.BottomSurface = Enum.SurfaceType.Smooth
	s.Parent = parent
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 30
	g.Parent = s
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "MUTANT\nLAB"
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = C.slime
	t.Rotation = 180
	t.Parent = g
	B.ring(parent, "SpawnGlow", CFrame.new(0, FLOOR + 0.25, 42), 7.6, 24, 0.3, 0.6, C.slime, M.Neon)
	return s
end

local function outerPaths(m, deco)
	local y = 0.3
	-- на север к первой зоне, на восток к мосту, на запад к башне, на юг к лабораториям
	P.path(m, Vector3.new(0, y, -R - 2), Vector3.new(0, y, D.Zones[1].z0 + 4), 20)
	P.path(m, Vector3.new(R + 2, y, 0), Vector3.new(D.River.x - D.River.width / 2 - 8, y, 0), 16)
	P.path(m, Vector3.new(-R - 2, y, 0), Vector3.new(D.Rebirth.center.X + 20, y, 0), 16)
	P.path(m, Vector3.new(0, y, R + 2), Vector3.new(0, y, 128), 16)
	-- фонари вдоль дорожек
	for z = -R - 14, D.Zones[1].z0 + 20, -26 do
		P.lamp(deco, Vector3.new(-12, 0, z), C.labTeal)
		P.lamp(deco, Vector3.new(12, 0, z), C.labTeal)
	end
	for x = R + 14, D.River.x - 24, 28 do
		P.lamp(deco, Vector3.new(x, 0, -10), rgb(255, 120, 100))
		P.lamp(deco, Vector3.new(x, 0, 10), rgb(255, 120, 100))
	end
	for x = -R - 14, D.Rebirth.center.X + 26, -28 do
		P.lamp(deco, Vector3.new(x, 0, -10), C.labPurple)
		P.lamp(deco, Vector3.new(x, 0, 10), C.labPurple)
	end
end

function Hub.build(root)
	local m = B.model(root, "Hub")
	local deco = B.model(m, "Decor")
	buildFloor(m)
	mutator(m)
	spawnPad(m)

	-- ворота
	local gates = {
		{ 0, "ЗОНЫ", "Грибной лес и дальше", C.labPurple },
		{ 90, "АРЕНА БОССА", "Мировой босс каждый час", rgb(255, 90, 80) },
		{ 180, "ЛАБОРАТОРИИ", "Твоя лаборатория и мутанты", C.labTeal },
		{ 270, "БАШНЯ РЕБЁРТА", "Начни заново, стань сильнее", rgb(200, 120, 255) },
	}
	for _, g in ipairs(gates) do
		local pos = polar(g[1], R + 1.5, 0)
		P.arch(m, P.facing(pos, Vector3.zero), 22, 17, C.stoneDark, g[4], g[2], g[3])
	end

	-- магазины и доски лидеров
	local shops = {
		{ 30, "Incubator", "ИНКУБАТОР", "Яйца мутантов", rgb(255, 190, 70), "egg" },
		{ 60, "Upgrades", "УЛУЧШЕНИЯ", "Сила, скорость, удача", rgb(80, 200, 255), "gear" },
		{ 120, "Backpacks", "РЮКЗАКИ", "Больше ингредиентов", rgb(255, 110, 80), "backpack" },
		{ 240, "MutantBook", "КНИГА МУТАНТОВ", "Собери всех", rgb(190, 110, 255), "book" },
		{ 300, "DailyReward", "НАГРАДА ДНЯ", "Заходи каждый день", rgb(255, 210, 60), "chest" },
		{ 330, "Potions", "ЗЕЛЬЯ", "Ускорители на время", rgb(255, 90, 160), "potions" },
	}
	for _, s in ipairs(shops) do
		kiosk(m, P.facing(polar(s[1], 64, FLOOR), Vector3.new(0, FLOOR, 0)), s[2], s[3], s[4], s[5], s[6])
	end
	leaderboard(m, P.facing(polar(150, 66, FLOOR), Vector3.new(0, FLOOR, 0)), "Coins", "ТОП: МОНЕТЫ", rgb(255, 215, 80))
	leaderboard(m, P.facing(polar(210, 66, FLOOR), Vector3.new(0, FLOOR, 0)), "Rebirths", "ТОП: РЕБЁРТЫ", rgb(200, 130, 255))

	-- колбы с мутантами
	local liquids = { C.labTeal, C.labPurple, C.slime, rgb(255, 150, 60) }
	for i, a in ipairs({ 45, 135, 225, 315 }) do
		P.tank(deco, polar(a, 42, FLOOR), 9, 4.4, liquids[i], true)
	end
	-- фонари по кругу
	for a = 15, 345, 30 do
		local near = false
		for _, g in ipairs({ 0, 90, 180, 270, 360 }) do
			if math.abs(a - g) < 16 then near = true end
		end
		if not near then P.lamp(deco, polar(a, 76, FLOOR), C.labTeal, 11) end
	end
	-- скамейки у западных и восточных ворот, клумбы у северных и южных
	for _, a in ipairs({ 72, 108, 252, 288 }) do
		local p = polar(a, 52, FLOOR)
		P.bench(deco, P.facing(p, Vector3.new(0, FLOOR, 0)) * CFrame.Angles(0, math.pi, 0))
	end
	local rng = Rng.new(5)
	for _, a in ipairs({ 18, 162, 198, 342 }) do
		local p = polar(a, 50, FLOOR)
		B.vcyl(deco, "Planter", 1.4, 9, CFrame.new(p + Vector3.new(0, 0.7, 0)), C.stoneDark, M.Slate)
		B.vcyl(deco, "Soil", 0.3, 8, CFrame.new(p + Vector3.new(0, 1.45, 0)), rgb(80, 60, 45), M.Ground)
		P.flowers(deco, p + Vector3.new(0, 1.5, 0), rng, 14, { rgb(255, 90, 200), rgb(120, 255, 200), rgb(255, 230, 80), C.labPurple }, 3.3)
		P.tree(deco, p + Vector3.new(0, 1.5, 0), rng, 0.45)
	end

	outerPaths(m, deco)
	return m
end

return Hub
