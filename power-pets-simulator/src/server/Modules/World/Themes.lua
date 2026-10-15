--[[
	Themes — рельеф и декор каждого мира.
	Рельеф делается настоящим Terrain: трава (с травинками), вода с волнами, песок, камень,
	дорожки из земли и брусчатки, холмы, горы, озеро, оазис, летающий остров и кратеры.
	Декор — детали из Props.
]]

local Build = require(script.Parent.Build)
local Props = require(script.Parent.Props)

local Themes = {}

local M = Enum.Material
local HALF = Build.HALF

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

------------------------------------------------------------------ ОБЩЕЕ

-- Плоская земля: верх ровно на высоте центра мира.
local function groundPlate(ctx, size, material)
	Build.terrainBlock(CFrame.new(ctx.Origin + Vector3.new(0, -8, 0)), Vector3.new(size, 16, size), material)
end

-- Дорожки и площадки: заменяем верхний слой земли другим материалом.
local function paths(ctx, pathMaterial, plazaMaterial)
	local o = ctx.Origin
	local function strip(center, size, material)
		Build.terrainBlock(CFrame.new(o + center + Vector3.new(0, -2, 0)), size, material)
	end
	strip(Vector3.new(0, 0, 0), Vector3.new(10, 4, 236), pathMaterial)
	strip(Vector3.new(-24, 0, 35), Vector3.new(48, 4, 8), pathMaterial)
	strip(Vector3.new(21, 0, 20), Vector3.new(42, 4, 8), pathMaterial)
	local function plaza(center, radius)
		Build.terrainCylinder(CFrame.new(o + center + Vector3.new(0, -2, 0)), 4, radius, plazaMaterial)
	end
	plaza(Build.LAYOUT.Spawn, 32)
	plaza(Build.LAYOUT.EggPlaza, 23)
	plaza(Build.LAYOUT.Sell + Vector3.new(0, 0, 6), 18)
	plaza(Build.LAYOUT.NextPortal, 15)
	plaza(Build.LAYOUT.BackPortal, 15)
end

-- Водоём: песчаный берег, яма и вода.
local function pond(ctx, localCenter, radius, shoreMaterial)
	local center = ctx.Origin + localCenter
	Build.terrainCylinder(CFrame.new(center + Vector3.new(0, -2, 0)), 4, radius + 5, shoreMaterial)
	Build.terrainCylinder(CFrame.new(center + Vector3.new(0, -4, 0)), 8, radius, M.Air)
	Build.terrainCylinder(CFrame.new(center + Vector3.new(0, -5, 0)), 6, radius, M.Water)
	Build.terrainCylinder(CFrame.new(center + Vector3.new(0, -9, 0)), 2, radius, shoreMaterial)
	Build.addObstacle(ctx, localCenter.X, localCenter.Z, radius + 4)
end

local function placeAt(ctx, x, z)
	local y = Build.groundAt(ctx.Origin + Vector3.new(x, 0, z), ctx.Origin.Y)
	return Vector3.new(ctx.Origin.X + x, y, ctx.Origin.Z + z)
end

------------------------------------------------------------------ ЛЕС
function Themes.Forest(ctx)
	local rng, palette, decor, o = ctx.Rng, ctx.Palette, ctx.Decor, ctx.Origin

	groundPlate(ctx, 900, M.Grass)
	paths(ctx, M.Ground, M.Cobblestone)
	pond(ctx, Vector3.new(-72, 0, -58), 17, M.Sand)

	-- Пологие холмы внутри зоны.
	for _ = 1, 7 do
		local x, z = rng:NextNumber(-115, 115), rng:NextNumber(-115, 115)
		if Build.isFree(ctx, x, z, 12, false) then
			local radius = rng:NextNumber(10, 15)
			Build.terrainBall(o + Vector3.new(x, -radius + rng:NextNumber(2.5, 5), z), radius, M.Grass)
			Build.addObstacle(ctx, x, z, radius * 0.5)
		end
	end
	-- Холмы и горы вокруг.
	for _ = 1, 26 do
		local x, z = Build.borderPoint(rng, HALF + 25, HALF + 150)
		local radius = rng:NextNumber(25, 50)
		Build.terrainBall(o + Vector3.new(x, -radius * 0.45, z), radius, M.Grass)
	end
	for i = 1, 12 do
		local angle = i / 12 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local distance = rng:NextNumber(300, 360)
		local radius = rng:NextNumber(55, 85)
		local center = o + Vector3.new(math.cos(angle) * distance, -radius * 0.25, math.sin(angle) * distance)
		Build.terrainBall(center, radius, M.Rock)
		Build.terrainBall(center + Vector3.new(0, radius * 0.62, 0), radius * 0.45, M.Snow)
	end

	-- Водопад со скалы за озером.
	local cliff = o + Vector3.new(-95, 0, -168)
	Build.terrainBlock(CFrame.new(cliff + Vector3.new(0, 20, 0)), Vector3.new(70, 48, 24), M.Rock)
	Build.terrainBlock(CFrame.new(cliff + Vector3.new(0, 45, 0)), Vector3.new(74, 4, 28), M.Grass)
	Build.terrainCylinder(CFrame.new(cliff + Vector3.new(0, -3, 22)), 6, 16, M.Water)
	local fall = Build.part(decor, {
		Name = "Waterfall",
		Size = Vector3.new(10, 44, 1.5),
		CFrame = CFrame.new(cliff + Vector3.new(0, 22, 12.5)),
		Color = rgb(150, 220, 255),
		Material = M.Glass,
		Transparency = 0.25,
		Reflectance = 0.2,
		CanCollide = false,
	})
	local foam = Instance.new("ParticleEmitter")
	foam.Color = ColorSequence.new(rgb(255, 255, 255), rgb(190, 235, 255))
	foam.Rate = 60
	foam.Lifetime = NumberRange.new(1, 2)
	foam.Speed = NumberRange.new(4, 8)
	foam.SpreadAngle = Vector2.new(20, 20)
	foam.Acceleration = Vector3.new(0, -30, 0)
	foam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 2.5) })
	foam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	foam.EmissionDirection = Enum.NormalId.Front
	foam.Parent = fall

	-- Лилии на озере.
	for _ = 1, 7 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(3, 14)
		local at = o + Vector3.new(-72 + math.cos(angle) * distance, -1.85, -58 + math.sin(angle) * distance)
		Build.disc(decor, at, rng:NextNumber(2, 3.2), 0.15, rgb(80, 180, 70), { Name = "LilyPad", CanCollide = false })
		if rng:NextNumber() < 0.5 then
			Build.part(decor, { Name = "Lily", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.7, CFrame = CFrame.new(at + Vector3.new(0.4, 0.3, 0)), Color = rgb(255, 150, 200), CanCollide = false })
		end
	end

	-- Мельница — ориентир.
	local millAt = placeAt(ctx, 92, 92)
	Props.windmill(decor, millAt, math.rad(-135), palette)
	Build.addObstacle(ctx, 92, 92, 10)

	-- Фонари и заборчики вдоль главной тропинки.
	for z = -96, 104, 25 do
		Props.lantern(decor, o + Vector3.new(-8.5, 0, z), rgb(255, 210, 130))
	end
	Props.fence(decor, o + Vector3.new(7, 0, 0), o + Vector3.new(7, 0, 12), palette.Wood or rgb(170, 110, 60))
	Props.fence(decor, o + Vector3.new(7, 0, 28), o + Vector3.new(7, 0, 42), palette.Wood or rgb(170, 110, 60))
	Props.fence(decor, o + Vector3.new(-7, 0, -40), o + Vector3.new(-7, 0, -90), palette.Wood or rgb(170, 110, 60))
	Props.bench(decor, o + Vector3.new(-14, 0, -20), math.rad(90), palette.Wood or rgb(170, 110, 60))
	Props.bench(decor, o + Vector3.new(14, 0, -60), math.rad(-90), palette.Wood or rgb(170, 110, 60))

	-- Деревья, кусты, грибы, цветы, камни.
	Build.scatter(ctx, 14, 5.5, function(position)
		return Props.oak(decor, position, rng, palette)
	end)
	Build.scatter(ctx, 7, 4, function(position)
		return Props.birch(decor, position, rng, palette)
	end)
	Build.scatter(ctx, 7, 5.5, function(position)
		return Props.pine(decor, position, rng, palette)
	end)
	Build.scatter(ctx, 10, 3, function(position)
		return Props.mushroom(decor, position, rng)
	end)
	Build.scatter(ctx, 18, 3, function(position)
		return Props.bush(decor, position, rng, palette)
	end)
	Build.scatter(ctx, 9, 3, function(position)
		return Props.rock(decor, position, rng, palette.Rock, rgb(100, 180, 80))
	end)
	Build.scatter(ctx, 5, 4.5, function(position)
		return Props.log(decor, position, rng, palette)
	end)
	Build.scatter(ctx, 8, 3, function(position)
		Build.terrainBall(position + Vector3.new(0, -1, 0), rng:NextNumber(3, 5), M.Rock)
		return 5
	end)
	-- Цветы не мешают монетам, поэтому их не записываем в препятствия.
	for _ = 1, 24 do
		local x, z = rng:NextNumber(-HALF, HALF), rng:NextNumber(-HALF, HALF)
		if Build.isFree(ctx, x, z, 3, false) then
			Props.flowers(decor, placeAt(ctx, x, z), rng, palette, rng:NextInteger(5, 9))
		end
	end

	-- Густой лес по краям.
	for _ = 1, 48 do
		local x, z = Build.borderPoint(rng, HALF + 6, HALF + 70)
		local position = placeAt(ctx, x, z)
		if rng:NextNumber() < 0.65 then
			Props.pine(decor, position, rng, palette, rng:NextNumber(1.1, 1.7))
		else
			Props.oak(decor, position, rng, palette, rng:NextNumber(1.1, 1.5))
		end
	end
end

------------------------------------------------------------------ ПУСТЫНЯ
function Themes.Desert(ctx)
	local rng, palette, decor, o = ctx.Rng, ctx.Palette, ctx.Decor, ctx.Origin

	groundPlate(ctx, 900, M.Sand)
	paths(ctx, M.Sandstone, M.Limestone)

	-- Оазис: трава вокруг воды и пальмы.
	local oasis = Vector3.new(70, 0, -60)
	Build.terrainCylinder(CFrame.new(o + oasis + Vector3.new(0, -2, 0)), 4, 26, M.LeafyGrass)
	pond(ctx, oasis, 14, M.LeafyGrass)
	for k = 1, 6 do
		local angle = (k / 6) * math.pi * 2 + 0.3
		Props.palm(decor, placeAt(ctx, oasis.X + math.cos(angle) * 20, oasis.Z + math.sin(angle) * 20), rng, palette)
	end
	Build.addObstacle(ctx, oasis.X, oasis.Z, 25)

	-- Дюны внутри и вокруг.
	for _ = 1, 6 do
		local x, z = rng:NextNumber(-115, 115), rng:NextNumber(-115, 115)
		if Build.isFree(ctx, x, z, 14, false) then
			local radius = rng:NextNumber(12, 18)
			Build.terrainBall(o + Vector3.new(x, -radius + rng:NextNumber(3, 5.5), z), radius, M.Sand)
			Build.addObstacle(ctx, x, z, radius * 0.5)
		end
	end
	for _ = 1, 30 do
		local x, z = Build.borderPoint(rng, HALF + 20, HALF + 190)
		local radius = rng:NextNumber(30, 60)
		Build.terrainBall(o + Vector3.new(x, -radius * 0.55, z), radius, M.Sand)
	end
	-- Столовые горы из песчаника.
	local mesas = { Vector3.new(-230, 0, -40), Vector3.new(-170, 0, 210), Vector3.new(230, 0, 120), Vector3.new(260, 0, -220), Vector3.new(-60, 0, 300) }
	for _, mesa in ipairs(mesas) do
		local width = rng:NextNumber(50, 80)
		local height = rng:NextNumber(26, 40)
		Build.terrainBlock(CFrame.new(o + mesa + Vector3.new(0, height / 2 - 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Vector3.new(width, height, width * 0.7), M.Sandstone)
		Build.terrainBlock(CFrame.new(o + mesa + Vector3.new(0, height + 4, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Vector3.new(width * 0.6, 12, width * 0.45), M.Sandstone)
	end

	-- Пирамиды.
	Props.pyramid(decor, o + Vector3.new(-80, 0, -78), 30, 8, palette)
	Build.addObstacle(ctx, -80, -78, 22)
	Props.pyramid(decor, o + Vector3.new(-120, 0, -260), 120, 15, palette)
	Props.pyramid(decor, o + Vector3.new(80, 0, -300), 90, 12, palette)
	Props.pyramid(decor, o + Vector3.new(270, 0, -100), 100, 13, palette)

	-- Факелы и обелиски вдоль тропинки.
	for z = -96, 104, 25 do
		Props.torch(decor, o + Vector3.new(-8.5, 0, z))
	end
	Props.obelisk(decor, o + Vector3.new(14, 0, -90), 14, palette)
	Props.obelisk(decor, o + Vector3.new(-14, 0, -90), 14, palette)
	Props.obelisk(decor, o + Vector3.new(20, 0, 46), 10, palette)

	Build.scatter(ctx, 20, 3, function(position)
		return Props.cactus(decor, position, rng, palette)
	end)
	Build.scatter(ctx, 7, 3, function(position)
		return Props.column(decor, position, rng, palette, rng:NextNumber() < 0.6)
	end)
	Build.scatter(ctx, 9, 2, function(position)
		return Props.vase(decor, position, rng)
	end)
	Build.scatter(ctx, 5, 3, function(position)
		return Props.bones(decor, position, rng)
	end)
	Build.scatter(ctx, 10, 3, function(position)
		return Props.rock(decor, position, rng, palette.Rock)
	end)
	Build.scatter(ctx, 6, 3, function(position)
		Build.terrainBall(position + Vector3.new(0, -1, 0), rng:NextNumber(3, 5), M.Sandstone)
		return 5
	end)
	for _ = 1, 26 do
		local x, z = Build.borderPoint(rng, HALF + 5, HALF + 40)
		Props.cactus(decor, placeAt(ctx, x, z), rng, palette)
	end
end

------------------------------------------------------------------ КОСМОС
function Themes.Space(ctx)
	local rng, palette, decor, o = ctx.Rng, ctx.Palette, ctx.Decor, ctx.Origin

	-- Летающий остров: плоская верхушка и «морковка» камня снизу.
	Build.terrainCylinder(CFrame.new(o + Vector3.new(0, -4, 0)), 8, 190, M.Basalt)
	local layers = { { 175, -12 }, { 150, -22 }, { 120, -32 }, { 90, -42 }, { 60, -52 }, { 34, -62 }, { 14, -72 } }
	for _, layer in ipairs(layers) do
		Build.terrainCylinder(CFrame.new(o + Vector3.new(0, layer[2], 0)), 12, layer[1], M.Rock)
	end
	for _ = 1, 16 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(20, 130)
		local radius = rng:NextNumber(18, 34)
		Build.terrainBall(o + Vector3.new(math.cos(angle) * distance, -radius - rng:NextNumber(6, 30), math.sin(angle) * distance), radius, M.Slate)
	end
	-- Светящиеся жилы под островом.
	for _ = 1, 10 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(40, 150)
		Build.terrainBall(o + Vector3.new(math.cos(angle) * distance, -rng:NextNumber(10, 30), math.sin(angle) * distance), rng:NextNumber(5, 9), M.CrackedLava)
	end

	paths(ctx, M.Pavement, M.Glacier)

	-- Лунная пыль пятнами.
	for _ = 1, 10 do
		local x, z = rng:NextNumber(-120, 120), rng:NextNumber(-120, 120)
		if Build.isFree(ctx, x, z, 10, true) then
			Build.terrainCylinder(CFrame.new(o + Vector3.new(x, -1, z)), 2, rng:NextNumber(8, 14), M.Snow)
		end
	end
	-- Кратеры.
	Build.scatter(ctx, 11, 10, function(position)
		local radius = rng:NextNumber(7, 11)
		Build.terrainBall(position + Vector3.new(0, radius * 0.55, 0), radius, M.Air)
		if rng:NextNumber() < 0.5 then
			Build.terrainBall(position + Vector3.new(0, -radius * 0.3, 0), radius * 0.35, M.CrackedLava)
		end
		return radius + 2
	end)

	-- Неоновые полосы вдоль главной дорожки.
	for _, side in ipairs({ -1, 1 }) do
		Build.part(decor, {
			Name = "PathLight",
			Size = Vector3.new(0.6, 0.3, 230),
			CFrame = CFrame.new(o + Vector3.new(side * 5.6, 0.15, 0)),
			Color = palette.Lamp,
			Material = M.Neon,
			CanCollide = false,
		})
	end
	for z = -96, 104, 25 do
		Props.lantern(decor, o + Vector3.new(-8.5, 0, z), palette.Lamp, 8)
	end

	-- База: ракета, купола, антенна, тарелки.
	Props.rocket(decor, o + Vector3.new(-44, 0, 96))
	Props.dome(decor, o + Vector3.new(72, 0, 92), 18)
	Build.addObstacle(ctx, 72, 92, 12)
	Props.dome(decor, o + Vector3.new(98, 0, 64), 12)
	Build.addObstacle(ctx, 98, 64, 8)
	Props.antenna(decor, o + Vector3.new(-96, 0, 96))
	Build.addObstacle(ctx, -96, 96, 4)
	Props.satellite(decor, o + Vector3.new(-100, 0, -30), math.rad(40))
	Build.addObstacle(ctx, -100, -30, 6)
	Props.satellite(decor, o + Vector3.new(100, 0, -100), math.rad(-130))
	Build.addObstacle(ctx, 100, -100, 6)

	local lightCount = 0
	Build.scatter(ctx, 16, 3.5, function(position)
		lightCount += 1
		return Props.crystals(decor, position, rng, palette.Crystals, lightCount % 2 == 0)
	end)
	Build.scatter(ctx, 12, 2.5, function(position)
		return Props.alienPlant(decor, position, rng)
	end)
	Build.scatter(ctx, 8, 3, function(position)
		return Props.rock(decor, position, rng, palette.Rock)
	end)

	-- Кристаллы по краю острова.
	for _ = 1, 34 do
		local x, z = Build.borderPoint(rng, HALF + 5, HALF + 55)
		if x * x + z * z < 182 * 182 then
			Props.crystals(decor, placeAt(ctx, x, z), rng, palette.Crystals, false)
		end
	end

	-- Летающие астероиды.
	for _ = 1, 28 do
		local position = o + Vector3.new(rng:NextNumber(-240, 240), rng:NextNumber(30, 95), rng:NextNumber(-240, 240))
		Props.asteroid(decor, position, rng, palette.Rock)
	end

	-- Планеты на небе.
	local planets = {
		{ Vector3.new(-380, 140, -420), 220, true },
		{ Vector3.new(420, 90, -260), 120, false },
		{ Vector3.new(180, 220, 460), 160, true },
	}
	for i, planet in ipairs(planets) do
		local color = palette.Planets[(i - 1) % #palette.Planets + 1]
		local center = o + planet[1]
		Build.part(decor, { Name = "Planet", Shape = Enum.PartType.Ball, Size = Vector3.one * planet[2], CFrame = CFrame.new(center), Color = color, CanCollide = false, CastShadow = false })
		Build.part(decor, { Name = "PlanetGlow", Shape = Enum.PartType.Ball, Size = Vector3.one * planet[2] * 1.08, CFrame = CFrame.new(center), Color = color, Material = M.Neon, Transparency = 0.85, CanCollide = false, CastShadow = false })
		if planet[3] then
			Build.part(decor, {
				Name = "PlanetRing",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1, planet[2] * 1.8, planet[2] * 1.8),
				CFrame = CFrame.new(center) * Build.VERTICAL * CFrame.Angles(0, math.rad(18), math.rad(10)),
				Color = color:Lerp(Build.WHITE, 0.4),
				Material = M.Neon,
				Transparency = 0.45,
				CanCollide = false,
				CastShadow = false,
			})
		end
	end
end

return Themes
