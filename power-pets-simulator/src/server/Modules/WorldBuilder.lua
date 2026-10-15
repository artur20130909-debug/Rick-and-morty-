--[[
	WorldBuilder — строит все миры из деталей при запуске сервера (никаких .rbxm-файлов).

	В каждом мире (координаты относительно Origin мира):
		точка появления        (0, 0, 70)
		портал в следующий мир (0, 0, -112)
		портал назад           (0, 0, 118)
		точка продажи          (-45, 0, 35)
		яйца                   позиции из Eggs.lua (площадка около (40, 0, 20))
	Остальное место занимают декор и монеты.

	WorldBuilder.Build() -> { [worldId] = информация о мире } (см. конец buildWorld)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Worlds = require(Shared.Config.Worlds)
local Eggs = require(Shared.Config.Eggs)
local Pets = require(Shared.Config.Pets)
local Rarities = require(Shared.Config.Rarities)
local Formulas = require(Shared.Modules.Formulas)
local Format = require(Shared.Modules.Format)

local WorldBuilder = {}

local HALF = 130 -- половина стороны игровой зоны: невидимые стены стоят на ±HALF
local VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- делает цилиндр вертикальным
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(25, 20, 35)

local FONT = Font.new(Font.fromEnum(Enum.Font.Nunito).Family, Enum.FontWeight.Heavy)

local LAYOUT = {
	Spawn = Vector3.new(0, 0, 70),
	NextPortal = Vector3.new(0, 0, -112),
	BackPortal = Vector3.new(0, 0, 118),
	Sell = Vector3.new(-45, 0, 35),
	EggPlaza = Vector3.new(40, 0, 20),
}

-- Зоны, где нельзя ставить декор. Coins = true — монеты там появляться могут (тропинки).
local RESERVED = {
	{ Kind = "Rect", MinX = -10, MaxX = 10, MinZ = -128, MaxZ = 128, Coins = true },
	{ Kind = "Rect", MinX = -50, MaxX = 0, MinZ = 29, MaxZ = 41, Coins = true },
	{ Kind = "Rect", MinX = 0, MaxX = 42, MinZ = 14, MaxZ = 26, Coins = true },
	{ Kind = "Circle", X = -45, Z = 40, R = 18 },
	{ Kind = "Circle", X = 40, Z = 20, R = 23 },
	{ Kind = "Circle", X = 0, Z = 70, R = 12 },
	{ Kind = "Circle", X = 0, Z = -112, R = 16 },
	{ Kind = "Circle", X = 0, Z = 118, R = 14 },
}

------------------------------------------------------------------ ПОМОЩНИКИ

local function newPart(parent, props)
	local part = Instance.new(props.ClassName or "Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		if key ~= "ClassName" and key ~= "Mesh" then
			part[key] = value
		end
	end
	if props.Mesh then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = props.Mesh
		mesh.Parent = part
	end
	part.Parent = parent
	return part
end

local function newFolder(name, parent)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function cylinderBetween(parent, a, b, diameter, color, material)
	local length = (b - a).Magnitude
	return newPart(parent, {
		Name = "Cylinder",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, diameter, diameter),
		CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

local function disc(parent, position, diameter, height, color, props)
	local data = {
		Name = "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(position) * VERTICAL,
		Color = color,
	}
	for key, value in pairs(props or {}) do
		data[key] = value
	end
	return newPart(parent, data)
end

local function newBillboard(adornee, sizeStuds, offset, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Billboard"
	gui.Size = UDim2.new(sizeStuds.X, 0, sizeStuds.Y, 0)
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = maxDistance or 150
	gui.LightInfluence = 0
	gui.Parent = adornee
	return gui
end

local function addLine(parent, text, color, heightScale, order, name)
	local label = Instance.new("TextLabel")
	label.Name = name or ("Line" .. order)
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, heightScale)
	label.FontFace = FONT
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = INK
	label.LayoutOrder = order
	label.Parent = parent
	return label
end

local function addList(parent, padding)
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(padding or 0, 0)
	list.Parent = parent
	return list
end

-- Свободна ли точка (x, z) мира для декора (forCoin = для монеты).
local function isFree(x, z, radius, forCoin, obstacles)
	if math.abs(x) > HALF - 4 - radius or math.abs(z) > HALF - 4 - radius then
		return false
	end
	for _, zone in ipairs(RESERVED) do
		if not (forCoin and zone.Coins) then
			if zone.Kind == "Rect" then
				if x + radius > zone.MinX and x - radius < zone.MaxX and z + radius > zone.MinZ and z - radius < zone.MaxZ then
					return false
				end
			else
				local dx, dz = x - zone.X, z - zone.Z
				if dx * dx + dz * dz < (zone.R + radius) ^ 2 then
					return false
				end
			end
		end
	end
	for _, obstacle in ipairs(obstacles) do
		local dx, dz = x - obstacle.X, z - obstacle.Z
		if dx * dx + dz * dz < (obstacle.R + radius) ^ 2 then
			return false
		end
	end
	return true
end

-- Ставит count объектов в свободные места игровой зоны.
local function scatter(ctx, count, radius, place)
	local placed = 0
	for _ = 1, count * 15 do
		if placed >= count then
			break
		end
		local x = ctx.Rng:NextNumber(-HALF, HALF)
		local z = ctx.Rng:NextNumber(-HALF, HALF)
		if isFree(x, z, radius, false, ctx.Obstacles) then
			local actualRadius = place(ctx.Origin + Vector3.new(x, 0, z)) or radius
			table.insert(ctx.Obstacles, { X = x, Z = z, R = actualRadius })
			placed += 1
		end
	end
end

-- Случайная точка за стенами (декор по краям мира).
local function borderPoint(rng, inner, outer)
	for _ = 1, 100 do
		local x = rng:NextNumber(-outer, outer)
		local z = rng:NextNumber(-outer, outer)
		if math.max(math.abs(x), math.abs(z)) >= inner then
			return x, z
		end
	end
	return inner, inner
end

------------------------------------------------------------------ ДЕКОР: ЛЕС

local function tree(parent, position, rng, palette, scale)
	scale = scale or 1
	local height = rng:NextNumber(7, 11) * scale
	local width = rng:NextNumber(1.6, 2.2) * scale
	newPart(parent, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, width, width),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * VERTICAL,
		Color = palette.Trunk,
		Material = Enum.Material.Wood,
	})
	local leaves = palette.Leaves[rng:NextInteger(1, #palette.Leaves)]
	local size = rng:NextNumber(7, 10) * scale
	local top = position + Vector3.new(0, height, 0)
	newPart(parent, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(top + Vector3.new(0, size * 0.2, 0)), Color = leaves })
	newPart(parent, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.7, CFrame = CFrame.new(top + Vector3.new(size * 0.35, size * 0.45, size * 0.1)), Color = leaves:Lerp(WHITE, 0.08) })
	newPart(parent, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.65, CFrame = CFrame.new(top + Vector3.new(-size * 0.3, size * 0.35, -size * 0.2)), Color = leaves:Lerp(INK, 0.08) })
	return size * 0.5
end

local function bush(parent, position, rng, palette)
	local size = rng:NextNumber(3, 5)
	local color = palette.Leaves[rng:NextInteger(1, #palette.Leaves)]
	newPart(parent, { Name = "Bush", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(position + Vector3.new(0, size * 0.25, 0)), Color = color })
	newPart(parent, { Name = "Bush", Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.7, CFrame = CFrame.new(position + Vector3.new(size * 0.45, size * 0.15, 0)), Color = color:Lerp(WHITE, 0.1) })
	-- Ягодки.
	for i = 1, 3 do
		local angle = rng:NextNumber(0, math.pi * 2)
		newPart(parent, {
			Name = "Berry",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.6,
			CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * size * 0.42, size * 0.45 - i * 0.2, math.sin(angle) * size * 0.42)),
			Color = Color3.fromRGB(255, 70, 90),
			CanCollide = false,
		})
	end
	return size * 0.6
end

local function flower(parent, position, rng, palette)
	local height = rng:NextNumber(1, 1.8)
	newPart(parent, {
		Name = "Stem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 0.2, 0.2),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * VERTICAL,
		Color = Color3.fromRGB(60, 150, 60),
		CanCollide = false,
	})
	newPart(parent, {
		Name = "Petals",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.9,
		CFrame = CFrame.new(position + Vector3.new(0, height, 0)),
		Color = palette.Flowers[rng:NextInteger(1, #palette.Flowers)],
		CanCollide = false,
	})
	newPart(parent, {
		Name = "Center",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.4,
		CFrame = CFrame.new(position + Vector3.new(0, height + 0.15, -0.3)),
		Color = Color3.fromRGB(255, 230, 90),
		CanCollide = false,
	})
end

local function rock(parent, position, rng, color)
	local size = Vector3.new(rng:NextNumber(3, 6), rng:NextNumber(2, 3.5), rng:NextNumber(3, 5))
	newPart(parent, {
		Name = "Rock",
		Size = size,
		CFrame = CFrame.new(position + Vector3.new(0, size.Y * 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
		Color = color,
		Material = Enum.Material.Slate,
		Mesh = Enum.MeshType.Sphere,
	})
	return math.max(size.X, size.Z) * 0.5
end

local function mushroom(parent, position, rng)
	local height = rng:NextNumber(3, 5.5)
	local capSize = rng:NextNumber(4.5, 6.5)
	newPart(parent, {
		Name = "Stem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.5, 1.5),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * VERTICAL,
		Color = Color3.fromRGB(250, 240, 220),
	})
	local capColor = rng:NextNumber() < 0.7 and Color3.fromRGB(240, 60, 60) or Color3.fromRGB(255, 160, 40)
	local capCenter = position + Vector3.new(0, height + 0.3, 0)
	newPart(parent, {
		Name = "Cap",
		Size = Vector3.new(capSize, capSize * 0.5, capSize),
		CFrame = CFrame.new(capCenter),
		Color = capColor,
		Mesh = Enum.MeshType.Sphere,
	})
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local radius = capSize * 0.28
		newPart(parent, {
			Name = "Dot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * capSize * 0.16,
			CFrame = CFrame.new(capCenter + Vector3.new(math.cos(angle) * radius, capSize * 0.17, math.sin(angle) * radius)),
			Color = WHITE,
			CanCollide = false,
		})
	end
	return capSize * 0.5
end

local function pond(parent, position, rng, palette, radius)
	disc(parent, position + Vector3.new(0, 0.05, 0), radius * 2 + 3, 0.5, palette.Rock, { Material = Enum.Material.Slate, Name = "PondRim" })
	disc(parent, position + Vector3.new(0, 0.15, 0), radius * 2, 0.5, palette.Water, {
		Name = "Water",
		Transparency = 0.15,
		Reflectance = 0.25,
		CanCollide = false,
	})
	for _ = 1, 5 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(2, radius - 2)
		disc(parent, position + Vector3.new(math.cos(angle) * distance, 0.45, math.sin(angle) * distance), rng:NextNumber(1.8, 3), 0.1, Color3.fromRGB(70, 170, 70), {
			Name = "LilyPad",
			CanCollide = false,
		})
	end
end

local function decorateForest(ctx)
	local rng, palette, decor = ctx.Rng, ctx.Palette, ctx.Decor
	-- Пруд.
	local pondX, pondZ = -70, -55
	pond(decor, ctx.Origin + Vector3.new(pondX, 0, pondZ), rng, palette, 14)
	table.insert(ctx.Obstacles, { X = pondX, Z = pondZ, R = 16 })

	scatter(ctx, 22, 5, function(position)
		return tree(decor, position, rng, palette)
	end)
	scatter(ctx, 14, 3, function(position)
		return mushroom(decor, position, rng)
	end)
	scatter(ctx, 24, 2.5, function(position)
		return bush(decor, position, rng, palette)
	end)
	scatter(ctx, 12, 2.5, function(position)
		return rock(decor, position, rng, palette.Rock)
	end)
	-- Цветы не мешают монетам, поэтому их не записываем в препятствия.
	for _ = 1, 60 do
		local x, z = rng:NextNumber(-HALF, HALF), rng:NextNumber(-HALF, HALF)
		if isFree(x, z, 0.5, false, ctx.Obstacles) then
			flower(decor, ctx.Origin + Vector3.new(x, 0, z), rng, palette)
		end
	end
	-- Густой лес вокруг игровой зоны.
	for _ = 1, 90 do
		local x, z = borderPoint(rng, HALF + 5, HALF + 75)
		tree(decor, ctx.Origin + Vector3.new(x, 0, z), rng, palette, rng:NextNumber(1.1, 1.6))
	end
end

------------------------------------------------------------------ ДЕКОР: ПУСТЫНЯ

local function cactus(parent, position, rng, palette)
	local height = rng:NextNumber(6, 10)
	local width = 1.7
	local base = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local color = palette.Cactus
	newPart(parent, {
		Name = "Cactus",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, width, width),
		CFrame = base * CFrame.new(0, height / 2, 0) * VERTICAL,
		Color = color,
	})
	newPart(parent, { Name = "Cactus", Shape = Enum.PartType.Ball, Size = Vector3.one * width, CFrame = base * CFrame.new(0, height, 0), Color = color })
	for _, side in ipairs({ -1, 1 }) do
		if rng:NextNumber() < 0.75 then
			local armY = rng:NextNumber(height * 0.35, height * 0.6)
			local armHeight = rng:NextNumber(2, 3.5)
			newPart(parent, {
				Name = "Arm",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(2.2, 1.1, 1.1),
				CFrame = base * CFrame.new(side * 1.5, armY, 0),
				Color = color,
			})
			newPart(parent, {
				Name = "Arm",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(armHeight, 1.1, 1.1),
				CFrame = base * CFrame.new(side * 2.5, armY + armHeight / 2, 0) * VERTICAL,
				Color = color,
			})
			newPart(parent, {
				Name = "Arm",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 1.1,
				CFrame = base * CFrame.new(side * 2.5, armY + armHeight, 0),
				Color = color,
			})
		end
	end
	-- Цветок на макушке.
	if rng:NextNumber() < 0.4 then
		newPart(parent, {
			Name = "CactusFlower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9,
			CFrame = base * CFrame.new(0, height + 0.8, 0),
			Color = Color3.fromRGB(255, 100, 160),
			CanCollide = false,
		})
	end
	return 3
end

local function palm(parent, position, rng, palette)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local direction = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
	local lean = rng:NextNumber(0.4, 0.9)
	local previous = position
	for i = 1, 5 do
		local nextPoint = position + Vector3.new(0, i * 2.4, 0) + direction * (lean * i * i * 0.15)
		cylinderBetween(parent, previous, nextPoint, 1.4 - i * 0.08, palette.PalmTrunk, Enum.Material.Wood)
		previous = nextPoint
	end
	for k = 1, 7 do
		local angle = (k / 7) * math.pi * 2
		local leafDirection = Vector3.new(math.cos(angle), -0.35, math.sin(angle)).Unit
		local center = previous + leafDirection * 3
		newPart(parent, {
			Name = "PalmLeaf",
			Size = Vector3.new(1.8, 0.35, 6.5),
			CFrame = CFrame.lookAt(center, center + leafDirection),
			Color = palette.PalmLeaves,
			Mesh = Enum.MeshType.Sphere,
			CanCollide = false,
		})
	end
	for k = 1, 3 do
		local angle = (k / 3) * math.pi * 2
		newPart(parent, {
			Name = "Coconut",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9,
			CFrame = CFrame.new(previous + Vector3.new(math.cos(angle) * 0.7, -0.7, math.sin(angle) * 0.7)),
			Color = Color3.fromRGB(110, 70, 40),
		})
	end
	return 2.5
end

local function pyramid(parent, position, baseSize, layers, palette)
	local layerHeight = baseSize / layers * 0.6
	for i = 0, layers - 1 do
		local size = baseSize * (1 - i / layers)
		newPart(parent, {
			Name = "Pyramid",
			Size = Vector3.new(size, layerHeight, size),
			CFrame = CFrame.new(position + Vector3.new(0, layerHeight * (i + 0.5), 0)),
			Color = palette.Sandstone[i % 2 + 1],
			Material = Enum.Material.Sandstone,
		})
	end
end

local function decorateDesert(ctx)
	local rng, palette, decor = ctx.Rng, ctx.Palette, ctx.Decor
	-- Оазис с пальмами.
	local oasisX, oasisZ = 70, -60
	local oasis = ctx.Origin + Vector3.new(oasisX, 0, oasisZ)
	pond(decor, oasis, rng, { Rock = palette.Sandstone[2], Water = palette.Water }, 13)
	for k = 1, 4 do
		local angle = (k / 4) * math.pi * 2 + 0.4
		palm(decor, oasis + Vector3.new(math.cos(angle) * 17, 0, math.sin(angle) * 17), rng, palette)
	end
	table.insert(ctx.Obstacles, { X = oasisX, Z = oasisZ, R = 20 })

	-- Пирамида внутри зоны.
	local innerPyramid = ctx.Origin + Vector3.new(-75, 0, -70)
	pyramid(decor, innerPyramid, 30, 8, palette)
	table.insert(ctx.Obstacles, { X = -75, Z = -70, R = 22 })

	scatter(ctx, 26, 3, function(position)
		return cactus(decor, position, rng, palette)
	end)
	scatter(ctx, 14, 2.5, function(position)
		return rock(decor, position, rng, palette.Rock)
	end)

	-- Большие пирамиды и дюны на горизонте.
	pyramid(decor, ctx.Origin + Vector3.new(-120, 0, -250), 110, 14, palette)
	pyramid(decor, ctx.Origin + Vector3.new(70, 0, -290), 80, 11, palette)
	pyramid(decor, ctx.Origin + Vector3.new(250, 0, -140), 95, 12, palette)
	for _ = 1, 40 do
		local x, z = borderPoint(rng, HALF + 25, HALF + 160)
		local size = rng:NextNumber(30, 60)
		newPart(decor, {
			Name = "Dune",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			CFrame = CFrame.new(ctx.Origin + Vector3.new(x, -size * 0.34, z)),
			Color = palette.Dune,
			Material = Enum.Material.Sand,
		})
	end
	for _ = 1, 30 do
		local x, z = borderPoint(rng, HALF + 4, HALF + 30)
		cactus(decor, ctx.Origin + Vector3.new(x, 0, z), rng, palette)
	end
end

------------------------------------------------------------------ ДЕКОР: КОСМОС

local function crystalCluster(parent, position, rng, colors, withLight)
	local color = colors[rng:NextInteger(1, #colors)]
	local count = rng:NextInteger(3, 5)
	local tallest
	for _ = 1, count do
		local height = rng:NextNumber(3, 8)
		local width = height * 0.3
		local offset = Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
		local crystal = newPart(parent, {
			Name = "Crystal",
			Size = Vector3.new(width, height, width),
			CFrame = CFrame.new(position + offset)
				* CFrame.Angles(math.rad(rng:NextNumber(-25, 25)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-25, 25)))
				* CFrame.new(0, height * 0.4, 0),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		})
		if not tallest or crystal.Size.Y > tallest.Size.Y then
			tallest = crystal
		end
	end
	if withLight and tallest then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = tallest
	end
	return 3
end

local function crater(parent, position, rng, palette)
	local diameter = rng:NextNumber(9, 16)
	disc(parent, position + Vector3.new(0, 0.3, 0), diameter + 3, 1, palette.Rock:Lerp(WHITE, 0.15), { Material = Enum.Material.Slate, Name = "CraterRim" })
	disc(parent, position + Vector3.new(0, 0.15, 0), diameter, 1, palette.Ground:Lerp(INK, 0.35), { Material = Enum.Material.Slate, Name = "Crater" })
	return diameter * 0.5 + 1.5
end

local function lamp(parent, position, color)
	newPart(parent, {
		Name = "LampPost",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 0.5, 0.5),
		CFrame = CFrame.new(position + Vector3.new(0, 3, 0)) * VERTICAL,
		Color = Color3.fromRGB(50, 45, 80),
		Material = Enum.Material.Metal,
	})
	local bulb = newPart(parent, {
		Name = "LampBulb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.4,
		CFrame = CFrame.new(position + Vector3.new(0, 6.5, 0)),
		Color = color,
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 1.2
	light.Parent = bulb
end

local function rocket(parent, position)
	local body = Color3.fromRGB(240, 240, 250)
	local red = Color3.fromRGB(240, 70, 80)
	disc(parent, position + Vector3.new(0, 0.3, 0), 10, 0.6, Color3.fromRGB(60, 55, 90), { Material = Enum.Material.Metal, Name = "LaunchPad" })
	newPart(parent, {
		Name = "RocketBody",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(14, 5, 5),
		CFrame = CFrame.new(position + Vector3.new(0, 9, 0)) * VERTICAL,
		Color = body,
	})
	newPart(parent, { Name = "RocketNose", Size = Vector3.new(5, 6, 5), CFrame = CFrame.new(position + Vector3.new(0, 16, 0)), Color = red, Mesh = Enum.MeshType.Sphere })
	newPart(parent, {
		Name = "RocketWindow",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.8,
		CFrame = CFrame.new(position + Vector3.new(0, 11.5, -2.1)),
		Color = Color3.fromRGB(110, 230, 255),
		Material = Enum.Material.Neon,
	})
	for i = 1, 3 do
		local angle = (i / 3) * math.pi * 2
		newPart(parent, {
			Name = "RocketFin",
			Size = Vector3.new(0.6, 5, 3),
			CFrame = CFrame.new(position + Vector3.new(0, 4, 0)) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, 3),
			Color = red,
		})
	end
	newPart(parent, {
		Name = "RocketFlame",
		Size = Vector3.new(3, 3, 3),
		CFrame = CFrame.new(position + Vector3.new(0, 1.6, 0)),
		Color = Color3.fromRGB(255, 160, 40),
		Material = Enum.Material.Neon,
		Mesh = Enum.MeshType.Sphere,
		CanCollide = false,
	})
	return 6
end

local function decorateSpace(ctx)
	local rng, palette, decor, origin = ctx.Rng, ctx.Palette, ctx.Decor, ctx.Origin

	-- Камни под летающим островом.
	for _ = 1, 14 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(0, 150)
		local size = rng:NextNumber(40, 80)
		newPart(decor, {
			Name = "UnderRock",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			CFrame = CFrame.new(origin + Vector3.new(math.cos(angle) * distance, -size * 0.45 - rng:NextNumber(4, 20), math.sin(angle) * distance)),
			Color = palette.Rock:Lerp(INK, 0.3),
			Material = Enum.Material.Slate,
		})
	end

	-- Ракета у точки появления.
	rocket(decor, origin + Vector3.new(-25, 0, 85))
	table.insert(ctx.Obstacles, { X = -25, Z = 85, R = 7 })

	-- Фонари вдоль главной тропинки.
	for z = -95, 100, 28 do
		for _, side in ipairs({ -1, 1 }) do
			lamp(decor, origin + Vector3.new(side * 7.5, 0, z), palette.Lamp)
		end
	end

	local lightCount = 0
	scatter(ctx, 18, 3, function(position)
		lightCount += 1
		return crystalCluster(decor, position, rng, palette.Crystals, lightCount % 2 == 0)
	end)
	scatter(ctx, 12, 8, function(position)
		return crater(decor, position, rng, palette)
	end)
	scatter(ctx, 10, 2.5, function(position)
		return rock(decor, position, rng, palette.Rock)
	end)

	-- Кристаллы по краю острова.
	for _ = 1, 40 do
		local x, z = borderPoint(rng, HALF + 4, HALF + 50)
		if x * x + z * z < 190 * 190 then
			crystalCluster(decor, origin + Vector3.new(x, 0, z), rng, palette.Crystals, false)
		end
	end

	-- Летающие астероиды (сквозь них можно пройти).
	for _ = 1, 30 do
		local size = rng:NextNumber(4, 12)
		newPart(decor, {
			Name = "Asteroid",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			CFrame = CFrame.new(origin + Vector3.new(rng:NextNumber(-220, 220), rng:NextNumber(30, 90), rng:NextNumber(-220, 220))),
			Color = palette.Rock:Lerp(WHITE, rng:NextNumber(0, 0.2)),
			Material = Enum.Material.Slate,
			CanCollide = false,
		})
	end

	-- Планеты на небе.
	local planets = {
		{ Vector3.new(-380, 140, -420), 220, true },
		{ Vector3.new(420, 90, -260), 120, false },
		{ Vector3.new(180, 220, 460), 160, true },
	}
	for i, planet in ipairs(planets) do
		local color = palette.Planets[(i - 1) % #palette.Planets + 1]
		local center = origin + planet[1]
		newPart(decor, {
			Name = "Planet",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * planet[2],
			CFrame = CFrame.new(center),
			Color = color,
			CanCollide = false,
			CastShadow = false,
		})
		if planet[3] then
			newPart(decor, {
				Name = "PlanetRing",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1, planet[2] * 1.7, planet[2] * 1.7),
				CFrame = CFrame.new(center) * VERTICAL * CFrame.Angles(0, math.rad(18), math.rad(10)),
				Color = color:Lerp(WHITE, 0.4),
				Material = Enum.Material.Neon,
				Transparency = 0.4,
				CanCollide = false,
				CastShadow = false,
			})
		end
	end
end

------------------------------------------------------------------ ОБЪЕКТЫ МИРА

local function buildSellZone(ctx)
	local center = ctx.Origin + LAYOUT.Sell
	local model = Instance.new("Model")
	model.Name = "SellZone"

	disc(model, center + Vector3.new(0, 0.1, 0), GameConfig.SellRadius * 2 + 3, 0.4, Color3.fromRGB(40, 130, 60), { Name = "SellRing" })
	local pad = disc(model, center + Vector3.new(0, 0.2, 0), GameConfig.SellRadius * 2, 0.4, Color3.fromRGB(90, 255, 120), {
		Name = "SellPad",
		Material = Enum.Material.Neon,
		Transparency = 0.1,
	})

	-- Ларёк с полосатой крышей.
	local booth = center + Vector3.new(0, 0, 13)
	newPart(model, {
		Name = "Counter",
		Size = Vector3.new(12, 3.2, 3),
		CFrame = CFrame.new(booth + Vector3.new(0, 1.6, 0)),
		Color = Color3.fromRGB(170, 110, 60),
		Material = Enum.Material.WoodPlanks,
	})
	for _, side in ipairs({ -1, 1 }) do
		newPart(model, {
			Name = "Post",
			Size = Vector3.new(0.8, 9, 0.8),
			CFrame = CFrame.new(booth + Vector3.new(side * 5.8, 4.5, 1.2)),
			Color = Color3.fromRGB(140, 90, 50),
			Material = Enum.Material.Wood,
		})
	end
	for i = 0, 6 do
		newPart(model, {
			Name = "Awning",
			Size = Vector3.new(2, 0.6, 7),
			CFrame = CFrame.new(booth + Vector3.new(-6 + i * 2, 9.2, 0)) * CFrame.Angles(math.rad(-12), 0, 0),
			Color = i % 2 == 0 and Color3.fromRGB(255, 80, 90) or WHITE,
		})
	end
	-- Мешки с монетами на прилавке.
	for _, offset in ipairs({ -3.5, 0, 3.5 }) do
		newPart(model, {
			Name = "CoinBag",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.8,
			CFrame = CFrame.new(booth + Vector3.new(offset, 4, 0)),
			Color = Color3.fromRGB(255, 205, 40),
			Reflectance = 0.2,
		})
	end

	local gui = newBillboard(pad, Vector2.new(14, 5), Vector3.new(0, 7, 0), 160)
	addList(gui)
	addLine(gui, "💰 ПРОДАЖА СИЛЫ", Color3.fromRGB(120, 255, 140), 0.55, 1)
	addLine(gui, "Встань в круг: 1 сила = " .. ctx.Config.SellMultiplier .. " 🪙", WHITE, 0.4, 2)

	pad:SetAttribute("SellMultiplier", ctx.Config.SellMultiplier)
	CollectionService:AddTag(pad, "SellPad")
	model.Parent = ctx.Folder
	return { Position = center, Radius = GameConfig.SellRadius }
end

local function buildEggStand(ctx, eggId)
	local egg = Eggs[eggId]
	local position = ctx.Origin + Vector3.new(egg.Position.X, 0, egg.Position.Z)
	local model = Instance.new("Model")
	model.Name = eggId

	disc(model, position + Vector3.new(0, 0.8, 0), 9, 1.6, ctx.Palette.Stand, { Name = "Pedestal" })
	disc(model, position + Vector3.new(0, 1.1, 0), 9.6, 0.4, egg.Color, { Name = "Trim", Material = Enum.Material.Neon })

	local eggPart = newPart(model, {
		Name = "Egg",
		Size = Vector3.new(4.4, 5.6, 4.4),
		CFrame = CFrame.new(position + Vector3.new(0, 1.6 + 2.8, 0)),
		Color = egg.Color,
		Mesh = Enum.MeshType.Sphere,
	})
	local spots = {
		{ 20, 10 },
		{ 95, -15 },
		{ 160, 25 },
		{ 230, -5 },
		{ 300, 30 },
		{ 60, 45 },
		{ 200, 50 },
	}
	for _, spot in ipairs(spots) do
		local around, elevation = math.rad(spot[1]), math.rad(spot[2])
		local offset = Vector3.new(math.cos(elevation) * math.cos(around) * 2.2, math.sin(elevation) * 2.8, math.cos(elevation) * math.sin(around) * 2.2)
		newPart(model, {
			Name = "Spot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.15,
			CFrame = CFrame.new(eggPart.Position + offset * 0.93),
			Color = egg.SpotColor,
			CanCollide = false,
		})
	end
	local light = Instance.new("PointLight")
	light.Color = egg.Color
	light.Range = 12
	light.Brightness = 1
	light.Parent = eggPart

	-- Табличка с ценой и шансами.
	local gui = newBillboard(eggPart, Vector2.new(11, 10), Vector3.new(0, 9.5, 0), 90)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(30, 24, 50)
	frame.BackgroundTransparency = 0.3
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.08, 0)
	corner.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.04, 0)
	padding.PaddingBottom = UDim.new(0.04, 0)
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.Parent = frame
	addList(frame, 0.005)
	addLine(frame, "🥚 " .. egg.Name, WHITE, 0.17, 1)
	addLine(frame, "🪙 " .. Format.Number(egg.Price), Color3.fromRGB(255, 220, 60), 0.13, 2)
	local chances = Formulas.EggChances(eggId)
	for index, petId in ipairs(Formulas.EggPetsSorted(eggId)) do
		local pet = Pets[petId]
		local text = string.format("%s %s  %s  •  %s", pet.Icon, pet.Name, Format.Multiplier(pet.Multiplier), Format.Percent(chances[petId]))
		addLine(frame, text, Rarities[pet.Rarity].Color, 0.115, 2 + index)
	end

	eggPart:SetAttribute("EggId", eggId)
	CollectionService:AddTag(eggPart, "EggStand")
	model.Parent = ctx.Folder
	return eggPart
end

local function buildPortal(ctx, localPosition, targetWorldId, isBack)
	local target = Worlds[targetWorldId]
	local position = ctx.Origin + localPosition
	-- Портал смотрит лицом к центру мира.
	local base = CFrame.lookAt(position, Vector3.new(ctx.Origin.X, position.Y, ctx.Origin.Z))
	local model = Instance.new("Model")
	model.Name = (isBack and "BackPortal_" or "Portal_") .. targetWorldId
	local frameColor = ctx.Palette.PortalFrame

	newPart(model, { Name = "Step", Size = Vector3.new(22, 1, 6), CFrame = base * CFrame.new(0, 0.5, 0), Color = frameColor:Lerp(INK, 0.2), Material = Enum.Material.Slate })
	for _, side in ipairs({ -1, 1 }) do
		newPart(model, { Name = "Pillar", Size = Vector3.new(3, 18, 3), CFrame = base * CFrame.new(side * 8.5, 9.5, 0), Color = frameColor, Material = Enum.Material.Slate })
		newPart(model, {
			Name = "Gem",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.6,
			CFrame = base * CFrame.new(side * 8.5, 14, -1.6),
			Color = target.Color,
			Material = Enum.Material.Neon,
		})
	end
	local top = newPart(model, { Name = "Top", Size = Vector3.new(21, 3, 3.4), CFrame = base * CFrame.new(0, 19.5, 0), Color = frameColor, Material = Enum.Material.Slate })

	local swirl = newPart(model, {
		Name = "Swirl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 14, 14),
		CFrame = base * CFrame.new(0, 9.5, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Color = target.Color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
	})
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(target.Color, WHITE)
	particles.LightEmission = 1
	particles.Rate = 25
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Speed = NumberRange.new(1, 3)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	particles.Parent = swirl

	local touch = newPart(model, {
		Name = "Touch",
		Size = Vector3.new(14, 15, 3),
		CFrame = base * CFrame.new(0, 9, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})

	local gui = newBillboard(top, Vector2.new(18, 6), Vector3.new(0, 5, 0), 220)
	addList(gui)
	local title = isBack and ("↩ Назад: " .. target.Icon .. " " .. target.Name) or (target.Icon .. " " .. Format.Upper(target.Name))
	addLine(gui, title, target.Color:Lerp(WHITE, 0.3), 0.55, 1, "Title")
	local status = isBack and "Открыто" or ("🔒 Нужно " .. Format.Number(target.UnlockStrength) .. " ⭐ силы")
	addLine(gui, status, WHITE, 0.4, 2, "Status")

	model:SetAttribute("TargetWorld", targetWorldId)
	model:SetAttribute("IsBack", isBack)
	CollectionService:AddTag(model, "Portal")
	model.Parent = ctx.Folder
	return { Touch = touch, TargetWorld = targetWorldId }
end

------------------------------------------------------------------ МИР ЦЕЛИКОМ

local function buildWorld(worldId, rootFolder)
	local config = Worlds[worldId]
	local origin = config.Origin
	local palette = config.Palette
	local folder = newFolder(worldId, rootFolder)

	local ctx = {
		Id = worldId,
		Config = config,
		Origin = origin,
		Palette = palette,
		Folder = folder,
		Map = newFolder("Map", folder),
		Decor = newFolder("Decor", folder),
		Rng = Random.new(config.Seed or 1),
		Obstacles = {},
	}

	-- Земля.
	if config.Theme == "Space" then
		newPart(ctx.Map, {
			Name = "Island",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6, 400, 400),
			CFrame = CFrame.new(origin + Vector3.new(0, -3, 0)) * VERTICAL,
			Color = palette.Ground,
			Material = Enum.Material.Slate,
		})
	else
		newPart(ctx.Map, {
			Name = "Ground",
			Size = Vector3.new(900, 4, 900),
			CFrame = CFrame.new(origin + Vector3.new(0, -2, 0)),
			Color = palette.Ground,
			Material = config.Theme == "Desert" and Enum.Material.Sand or Enum.Material.Grass,
		})
	end

	-- Невидимые стены по краю игровой зоны.
	local walls = {
		{ Vector3.new(HALF + 1, 75, 0), Vector3.new(2, 150, HALF * 2 + 4) },
		{ Vector3.new(-HALF - 1, 75, 0), Vector3.new(2, 150, HALF * 2 + 4) },
		{ Vector3.new(0, 75, HALF + 1), Vector3.new(HALF * 2 + 4, 150, 2) },
		{ Vector3.new(0, 75, -HALF - 1), Vector3.new(HALF * 2 + 4, 150, 2) },
	}
	for _, wall in ipairs(walls) do
		newPart(ctx.Map, {
			Name = "Wall",
			Size = wall[2],
			CFrame = CFrame.new(origin + wall[1]),
			Transparency = 1,
			CastShadow = false,
			CanQuery = false,
		})
	end

	-- Тропинки.
	local function path(centerX, centerZ, sizeX, sizeZ)
		newPart(ctx.Map, {
			Name = "Path",
			Size = Vector3.new(sizeX, 0.2, sizeZ),
			CFrame = CFrame.new(origin + Vector3.new(centerX, 0.02, centerZ)),
			Color = palette.Path,
			CanCollide = false,
			CastShadow = false,
		})
	end
	path(0, 0, 10, 236)
	path(-23, 35, 46, 8)
	path(20, 20, 40, 8)
	disc(ctx.Map, origin + LAYOUT.EggPlaza + Vector3.new(0, 0.05, 0), 36, 0.2, palette.Path, { Name = "EggPlaza", CanCollide = false, CastShadow = false })

	-- Точка появления.
	local spawnPosition = origin + LAYOUT.Spawn
	if worldId == GameConfig.StartWorld then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "SpawnLocation"
		spawn.Anchored = true
		spawn.Size = Vector3.new(10, 1, 10)
		spawn.CFrame = CFrame.new(spawnPosition + Vector3.new(0, 0.5, 0))
		spawn.Color = config.Color
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = ctx.Map
	else
		newPart(ctx.Map, {
			Name = "SpawnPad",
			Size = Vector3.new(10, 1, 10),
			CFrame = CFrame.new(spawnPosition + Vector3.new(0, 0.5, 0)),
			Color = config.Color,
		})
	end

	local sell = buildSellZone(ctx)

	local eggStands = {}
	for _, eggId in ipairs(Eggs.Order) do
		if Eggs[eggId].World == worldId then
			eggStands[eggId] = buildEggStand(ctx, eggId)
		end
	end

	local portals = {}
	local nextWorld = Worlds.Order[config.Order + 1]
	local previousWorld = Worlds.Order[config.Order - 1]
	if nextWorld then
		table.insert(portals, buildPortal(ctx, LAYOUT.NextPortal, nextWorld, false))
	end
	if previousWorld then
		table.insert(portals, buildPortal(ctx, LAYOUT.BackPortal, previousWorld, true))
	end

	if config.Theme == "Forest" then
		decorateForest(ctx)
	elseif config.Theme == "Desert" then
		decorateDesert(ctx)
	elseif config.Theme == "Space" then
		decorateSpace(ctx)
	end

	local coinsFolder = newFolder("Coins", folder)

	return {
		Id = worldId,
		Folder = folder,
		Origin = origin,
		-- Игрок появляется над площадкой и смотрит на север (-Z), к центру мира.
		Spawn = CFrame.new(spawnPosition + Vector3.new(0, 4, 0)),
		Sell = sell,
		EggStands = eggStands,
		Portals = portals,
		CoinsFolder = coinsFolder,
		-- Случайное свободное место для монеты (координаты относительно центра мира).
		RandomCoinPoint = function(rng)
			for _ = 1, 40 do
				local x = rng:NextNumber(-HALF + 8, HALF - 8)
				local z = rng:NextNumber(-HALF + 8, HALF - 8)
				if isFree(x, z, 2, true, ctx.Obstacles) then
					return x, z
				end
			end
			return rng:NextNumber(-6, 6), rng:NextNumber(-60, 40)
		end,
	}
end

function WorldBuilder.Build()
	if GameConfig.RemoveTemplateBaseplate then
		local baseplate = Workspace:FindFirstChild("Baseplate")
		if baseplate and baseplate:IsA("BasePart") then
			baseplate:Destroy()
		end
		for _, item in ipairs(Workspace:GetDescendants()) do
			if item:IsA("SpawnLocation") then
				item:Destroy()
			end
		end
	end

	local old = Workspace:FindFirstChild("Worlds")
	if old then
		old:Destroy()
	end

	local rootFolder = Instance.new("Folder")
	rootFolder.Name = "Worlds"
	local result = {}
	for _, worldId in ipairs(Worlds.Order) do
		result[worldId] = buildWorld(worldId, rootFolder)
	end
	rootFolder.Parent = Workspace
	return result
end

return WorldBuilder
