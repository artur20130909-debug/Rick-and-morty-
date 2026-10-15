--[[
	Props — декор для миров, собранный из деталей.
	Каждая функция получает parent, позицию на земле, генератор случайных чисел (rng)
	и цвета, и возвращает радиус занятого места (чтобы декор не налезал друг на друга).
]]

local CollectionService = game:GetService("CollectionService")

local Build = require(script.Parent.Build)

local Props = {}

local part = Build.part
local VERTICAL = Build.VERTICAL
local WHITE = Build.WHITE

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

local function vary(color, rng, amount)
	amount = amount or 0.08
	local shift = rng:NextNumber(-amount, amount)
	if shift > 0 then
		return color:Lerp(WHITE, shift)
	end
	return color:Lerp(Color3.new(0, 0, 0), -shift)
end

------------------------------------------------------------------ ЛЕС

-- Пышное дерево из нескольких крон.
function Props.oak(parent, position, rng, palette, scale)
	scale = scale or 1
	local height = rng:NextNumber(8, 12) * scale
	local width = rng:NextNumber(1.8, 2.4) * scale
	local trunkColor = palette.Trunk
	part(parent, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, width, width),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2 - 0.5, 0)) * VERTICAL,
		Color = trunkColor,
		Material = Enum.Material.Wood,
	})
	-- корни
	for i = 1, 3 do
		local angle = i / 3 * math.pi * 2 + rng:NextNumber(0, 1)
		Build.cylinderBetween(
			parent,
			position + Vector3.new(0, 1.6 * scale, 0),
			position + Vector3.new(math.cos(angle) * 2.2 * scale, -0.2, math.sin(angle) * 2.2 * scale),
			0.8 * scale,
			trunkColor,
			Enum.Material.Wood
		)
	end
	-- ветка
	local branchAngle = rng:NextNumber(0, math.pi * 2)
	Build.cylinderBetween(
		parent,
		position + Vector3.new(0, height * 0.6, 0),
		position + Vector3.new(math.cos(branchAngle) * 3 * scale, height * 0.82, math.sin(branchAngle) * 3 * scale),
		0.7 * scale,
		trunkColor,
		Enum.Material.Wood
	)
	local leaves = pick(rng, palette.Leaves)
	local size = rng:NextNumber(8, 11) * scale
	local top = position + Vector3.new(0, height, 0)
	local clusters = {
		{ Vector3.new(0, size * 0.25, 0), 1 },
		{ Vector3.new(size * 0.38, size * 0.05, size * 0.1), 0.72 },
		{ Vector3.new(-size * 0.35, 0, -size * 0.18), 0.7 },
		{ Vector3.new(0.1 * size, size * 0.55, -0.15 * size), 0.62 },
		{ Vector3.new(-0.15 * size, -0.05 * size, size * 0.35), 0.6 },
	}
	for index, cluster in ipairs(clusters) do
		local color = index % 2 == 0 and leaves:Lerp(WHITE, 0.08) or leaves:Lerp(Color3.new(0, 0, 0), 0.04 * index)
		part(parent, {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size * cluster[2],
			CFrame = CFrame.new(top + cluster[1]),
			Color = color,
			Material = Enum.Material.Grass,
		})
	end
	-- яблочки
	if rng:NextNumber() < 0.5 then
		for _ = 1, 4 do
			local direction = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 0.6), rng:NextNumber(-1, 1)).Unit
			part(parent, {
				Name = "Fruit",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.8 * scale,
				CFrame = CFrame.new(top + Vector3.new(0, size * 0.2, 0) + direction * size * 0.48),
				Color = rgb(255, 70, 80),
				CanCollide = false,
			})
		end
	end
	return size * 0.5
end

-- Ёлка из сплюснутых ярусов.
function Props.pine(parent, position, rng, palette, scale)
	scale = scale or 1
	local trunkHeight = 4 * scale
	part(parent, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(trunkHeight + 2, 1.6 * scale, 1.6 * scale),
		CFrame = CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)) * VERTICAL,
		Color = palette.Trunk:Lerp(Color3.new(0, 0, 0), 0.15),
		Material = Enum.Material.Wood,
	})
	local green = palette.Pine or rgb(40, 130, 80)
	local tiers = { { 11, 4.2 }, { 8.6, 3.8 }, { 6.2, 3.4 }, { 3.8, 3 } }
	local y = trunkHeight
	local spin = rng:NextNumber(0, math.pi)
	for index, tier in ipairs(tiers) do
		local width = tier[1] * scale
		local height = tier[2] * scale
		part(parent, {
			Name = "PineTier",
			Size = Vector3.new(width, height, width),
			CFrame = CFrame.new(position + Vector3.new(0, y + height * 0.35, 0)) * CFrame.Angles(0, spin + index, 0),
			Color = green:Lerp(WHITE, index * 0.05),
			Material = Enum.Material.Grass,
			Mesh = Enum.MeshType.Sphere,
		})
		y += height * 0.62
	end
	part(parent, {
		Name = "PineTop",
		Size = Vector3.new(1.6, 2.6, 1.6) * scale,
		CFrame = CFrame.new(position + Vector3.new(0, y + 1.1 * scale, 0)),
		Color = green:Lerp(WHITE, 0.25),
		Material = Enum.Material.Grass,
		Mesh = Enum.MeshType.Sphere,
	})
	return 5.5 * scale
end

-- Берёзка: белый ствол с полосками.
function Props.birch(parent, position, rng, palette, scale)
	scale = scale or 1
	local height = rng:NextNumber(10, 13) * scale
	part(parent, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.3 * scale, 1.3 * scale),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * VERTICAL,
		Color = rgb(245, 242, 235),
		Material = Enum.Material.SmoothPlastic,
	})
	for i = 1, 5 do
		part(parent, {
			Name = "Stripe",
			Size = Vector3.new(0.5, 0.35, 1.36) * scale,
			CFrame = CFrame.new(position + Vector3.new(0, i * height / 6, 0)) * CFrame.Angles(0, i * 1.3, 0) * CFrame.new(0.45 * scale, 0, 0),
			Color = rgb(40, 40, 45),
			CanCollide = false,
		})
	end
	local leaves = palette.Birch or rgb(150, 220, 90)
	for i = 1, 3 do
		local size = rng:NextNumber(5, 7) * scale
		part(parent, {
			Name = "Leaves",
			Size = Vector3.new(size, size * 1.3, size),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-1.5, 1.5) * scale, height - 1 + i * 1.6 * scale, rng:NextNumber(-1.5, 1.5) * scale)),
			Color = leaves:Lerp(WHITE, i * 0.05),
			Material = Enum.Material.Grass,
			Mesh = Enum.MeshType.Sphere,
		})
	end
	return 3.5 * scale
end

function Props.bush(parent, position, rng, palette)
	local size = rng:NextNumber(3.5, 5.5)
	local color = pick(rng, palette.Leaves)
	for i = 1, 3 do
		local offset = Vector3.new(rng:NextNumber(-1, 1) * size * 0.35, 0, rng:NextNumber(-1, 1) * size * 0.35)
		part(parent, {
			Name = "Bush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size * (1 - i * 0.15),
			CFrame = CFrame.new(position + offset + Vector3.new(0, size * 0.22, 0)),
			Color = color:Lerp(WHITE, i * 0.05),
			Material = Enum.Material.Grass,
		})
	end
	if rng:NextNumber() < 0.6 then
		local berry = pick(rng, { rgb(255, 70, 90), rgb(120, 90, 255), rgb(255, 160, 40) })
		for _ = 1, 5 do
			local angle = rng:NextNumber(0, math.pi * 2)
			part(parent, {
				Name = "Berry",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.55,
				CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * size * 0.45, size * rng:NextNumber(0.3, 0.6), math.sin(angle) * size * 0.45)),
				Color = berry,
				CanCollide = false,
			})
		end
	end
	return size * 0.6
end

-- Полянка цветов.
function Props.flowers(parent, position, rng, palette, count)
	local color = pick(rng, palette.Flowers)
	for _ = 1, count or 7 do
		local offset = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		local height = rng:NextNumber(0.9, 1.6)
		local base = position + offset
		part(parent, {
			Name = "Stem",
			Size = Vector3.new(0.15, height, 0.15),
			CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)),
			Color = rgb(70, 150, 60),
			CanCollide = false,
			CastShadow = false,
		})
		part(parent, {
			Name = "Petals",
			Size = Vector3.new(1.1, 0.4, 1.1),
			CFrame = CFrame.new(base + Vector3.new(0, height, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			Color = vary(color, rng),
			Mesh = Enum.MeshType.Sphere,
			CanCollide = false,
			CastShadow = false,
		})
		part(parent, {
			Name = "Center",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.45,
			CFrame = CFrame.new(base + Vector3.new(0, height + 0.15, 0)),
			Color = rgb(255, 225, 80),
			CanCollide = false,
			CastShadow = false,
		})
	end
	return 3
end

function Props.rock(parent, position, rng, color, mossColor)
	local size = Vector3.new(rng:NextNumber(3, 6), rng:NextNumber(2, 3.5), rng:NextNumber(3, 5))
	local rotation = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	part(parent, {
		Name = "Rock",
		Size = size,
		CFrame = CFrame.new(position + Vector3.new(0, size.Y * 0.3, 0)) * rotation,
		Color = vary(color, rng),
		Material = Enum.Material.Slate,
		Mesh = Enum.MeshType.Sphere,
	})
	if mossColor then
		part(parent, {
			Name = "Moss",
			Size = Vector3.new(size.X * 0.8, size.Y * 0.35, size.Z * 0.8),
			CFrame = CFrame.new(position + Vector3.new(0, size.Y * 0.72, 0)) * rotation,
			Color = mossColor,
			Material = Enum.Material.Grass,
			Mesh = Enum.MeshType.Sphere,
			CanCollide = false,
		})
	end
	-- маленький камешек рядом
	part(parent, {
		Name = "Pebble",
		Size = size * 0.4,
		CFrame = CFrame.new(position + Vector3.new(size.X * 0.55, size.Y * 0.1, size.Z * 0.2)) * rotation,
		Color = vary(color, rng),
		Material = Enum.Material.Slate,
		Mesh = Enum.MeshType.Sphere,
	})
	return math.max(size.X, size.Z) * 0.6
end

function Props.mushroom(parent, position, rng, scale)
	scale = scale or 1
	local height = rng:NextNumber(3, 5.5) * scale
	local capSize = rng:NextNumber(4.5, 6.5) * scale
	part(parent, {
		Name = "Stem",
		Size = Vector3.new(1.6, height, 1.6) * Vector3.new(scale, 1, scale),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)),
		Color = rgb(250, 242, 225),
		Mesh = Enum.MeshType.Sphere,
	})
	local capColor = rng:NextNumber() < 0.65 and rgb(240, 60, 70) or pick(rng, { rgb(255, 160, 40), rgb(170, 110, 255) })
	local capCenter = position + Vector3.new(0, height, 0)
	part(parent, {
		Name = "Cap",
		Size = Vector3.new(capSize, capSize * 0.55, capSize),
		CFrame = CFrame.new(capCenter),
		Color = capColor,
		Mesh = Enum.MeshType.Sphere,
	})
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local radius = capSize * rng:NextNumber(0.18, 0.32)
		part(parent, {
			Name = "Dot",
			Size = Vector3.new(capSize * 0.17, capSize * 0.08, capSize * 0.17),
			CFrame = CFrame.new(capCenter + Vector3.new(math.cos(angle) * radius, capSize * 0.22, math.sin(angle) * radius)),
			Color = WHITE,
			Mesh = Enum.MeshType.Sphere,
			CanCollide = false,
		})
	end
	return capSize * 0.5
end

function Props.log(parent, position, rng, palette)
	local length = rng:NextNumber(6, 9)
	local yaw = rng:NextNumber(0, math.pi)
	local cframe = CFrame.new(position + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, yaw, 0)
	part(parent, {
		Name = "Log",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, 2, 2),
		CFrame = cframe,
		Color = palette.Trunk,
		Material = Enum.Material.Wood,
	})
	for _, side in ipairs({ -1, 1 }) do
		part(parent, {
			Name = "LogEnd",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 1.7, 1.7),
			CFrame = cframe * CFrame.new(side * length / 2, 0, 0),
			Color = rgb(225, 185, 130),
			Material = Enum.Material.WoodPlanks,
		})
	end
	part(parent, {
		Name = "LogMoss",
		Size = Vector3.new(length * 0.5, 0.5, 1.6),
		CFrame = cframe * CFrame.new(rng:NextNumber(-1, 1), 0.9, 0),
		Color = rgb(90, 170, 70),
		Material = Enum.Material.Grass,
		Mesh = Enum.MeshType.Sphere,
		CanCollide = false,
	})
	return length * 0.5
end

-- Фонарь на столбе (светится тёплым светом).
function Props.lantern(parent, position, color, height)
	height = height or 7
	part(parent, {
		Name = "LanternPost",
		Size = Vector3.new(0.6, height, 0.6),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)),
		Color = rgb(60, 50, 70),
		Material = Enum.Material.Metal,
	})
	part(parent, {
		Name = "LanternArm",
		Size = Vector3.new(1.8, 0.35, 0.35),
		CFrame = CFrame.new(position + Vector3.new(0.7, height - 0.3, 0)),
		Color = rgb(60, 50, 70),
		Material = Enum.Material.Metal,
	})
	local glass = part(parent, {
		Name = "LanternLight",
		Size = Vector3.new(1.1, 1.4, 1.1),
		CFrame = CFrame.new(position + Vector3.new(1.4, height - 1.2, 0)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
	})
	part(parent, {
		Name = "LanternCap",
		Size = Vector3.new(1.5, 0.4, 1.5),
		CFrame = CFrame.new(position + Vector3.new(1.4, height - 0.35, 0)),
		Color = rgb(60, 50, 70),
		Material = Enum.Material.Metal,
	})
	Build.light(glass, color, 18, 1.4)
	return 1.5
end

-- Заборчик между двумя точками.
function Props.fence(parent, from, to, color)
	local direction = to - from
	local length = direction.Magnitude
	local posts = math.max(1, math.floor(length / 5))
	for i = 0, posts do
		local point = from + direction * (i / posts)
		part(parent, {
			Name = "FencePost",
			Size = Vector3.new(0.7, 3, 0.7),
			CFrame = CFrame.new(point + Vector3.new(0, 1.5, 0)),
			Color = color,
			Material = Enum.Material.WoodPlanks,
		})
	end
	for _, y in ipairs({ 1.2, 2.3 }) do
		Build.cylinderBetween(parent, from + Vector3.new(0, y, 0), to + Vector3.new(0, y, 0), 0.35, color:Lerp(WHITE, 0.1), Enum.Material.WoodPlanks)
	end
end

function Props.bench(parent, position, yaw, color)
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	part(parent, { Name = "BenchSeat", Size = Vector3.new(5, 0.4, 1.6), CFrame = base * CFrame.new(0, 1.4, 0), Color = color, Material = Enum.Material.WoodPlanks })
	part(parent, { Name = "BenchBack", Size = Vector3.new(5, 1.2, 0.3), CFrame = base * CFrame.new(0, 2.3, 0.7), Color = color, Material = Enum.Material.WoodPlanks })
	for _, side in ipairs({ -1, 1 }) do
		part(parent, { Name = "BenchLeg", Size = Vector3.new(0.3, 1.4, 1.4), CFrame = base * CFrame.new(side * 2.1, 0.7, 0), Color = Color3.fromRGB(60, 50, 70), Material = Enum.Material.Metal })
	end
	return 3
end

-- Ветряная мельница с крутящимися лопастями (тег Spin крутит модель на клиенте).
function Props.windmill(parent, position, yaw, palette)
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	part(parent, { Name = "MillTower", Size = Vector3.new(9, 16, 9), CFrame = base * CFrame.new(0, 8, 0), Color = rgb(245, 235, 215), Material = Enum.Material.Brick })
	Build.roof(parent, base * CFrame.new(0, 16, 0), 10, 10, 5, rgb(200, 70, 60), Enum.Material.WoodPlanks)
	part(parent, { Name = "MillDoor", Size = Vector3.new(3, 5, 0.3), CFrame = base * CFrame.new(0, 2.5, -4.55), Color = palette.Trunk, Material = Enum.Material.WoodPlanks })
	part(parent, { Name = "MillWindow", Size = Vector3.new(2, 2, 0.3), CFrame = base * CFrame.new(0, 11, -4.55), Color = rgb(255, 220, 120), Material = Enum.Material.Neon })
	local blades = Build.model("MillBlades", parent)
	local hub = base * CFrame.new(0, 14, -5.6)
	part(blades, { Name = "Hub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 2, 2), CFrame = hub * CFrame.Angles(0, math.pi / 2, 0), Color = rgb(90, 70, 50), Material = Enum.Material.Wood })
	for i = 0, 3 do
		local arm = hub * CFrame.Angles(0, 0, i * math.pi / 2)
		part(blades, { Name = "BladeArm", Size = Vector3.new(0.5, 10, 0.4), CFrame = arm * CFrame.new(0, 5.5, 0), Color = rgb(120, 90, 60), Material = Enum.Material.Wood })
		part(blades, { Name = "BladeSail", Size = Vector3.new(2.6, 7, 0.2), CFrame = arm * CFrame.new(1.5, 6.5, 0.1), Color = rgb(250, 245, 235), Material = Enum.Material.Fabric })
	end
	-- Ось вращения лопастей — «вперёд» от мельницы.
	blades.WorldPivot = hub * CFrame.Angles(math.pi / 2, 0, 0)
	blades:SetAttribute("SpinSpeed", 0.8)
	CollectionService:AddTag(blades, "Spin")
	return 7
end

------------------------------------------------------------------ ПУСТЫНЯ

function Props.cactus(parent, position, rng, palette)
	local height = rng:NextNumber(6, 10)
	local width = 1.8
	local base = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local color = vary(palette.Cactus, rng, 0.06)
	part(parent, { Name = "Cactus", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, width, width), CFrame = base * CFrame.new(0, height / 2, 0) * VERTICAL, Color = color })
	part(parent, { Name = "Cactus", Shape = Enum.PartType.Ball, Size = Vector3.one * width, CFrame = base * CFrame.new(0, height, 0), Color = color })
	-- полоски-рёбра
	for i = 0, 3 do
		part(parent, {
			Name = "CactusRib",
			Size = Vector3.new(0.18, height - 0.5, 0.18),
			CFrame = base * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, height / 2, -width / 2),
			Color = color:Lerp(Color3.new(0, 0, 0), 0.15),
			CanCollide = false,
		})
	end
	for _, side in ipairs({ -1, 1 }) do
		if rng:NextNumber() < 0.75 then
			local armY = rng:NextNumber(height * 0.35, height * 0.6)
			local armHeight = rng:NextNumber(2, 3.5)
			part(parent, { Name = "Arm", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 1.2, 1.2), CFrame = base * CFrame.new(side * 1.5, armY, 0), Color = color })
			part(parent, { Name = "Arm", Shape = Enum.PartType.Cylinder, Size = Vector3.new(armHeight, 1.2, 1.2), CFrame = base * CFrame.new(side * 2.6, armY + armHeight / 2, 0) * VERTICAL, Color = color })
			part(parent, { Name = "Arm", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, CFrame = base * CFrame.new(side * 2.6, armY + armHeight, 0), Color = color })
		end
	end
	if rng:NextNumber() < 0.45 then
		part(parent, { Name = "CactusFlower", Shape = Enum.PartType.Ball, Size = Vector3.one * 1, CFrame = base * CFrame.new(0, height + 0.8, 0), Color = pick(rng, { rgb(255, 100, 160), rgb(255, 220, 70) }), CanCollide = false })
	end
	return 3
end

function Props.palm(parent, position, rng, palette)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local direction = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
	local lean = rng:NextNumber(0.4, 0.9)
	local previous = position
	for i = 1, 6 do
		local nextPoint = position + Vector3.new(0, i * 2.3, 0) + direction * (lean * i * i * 0.12)
		Build.cylinderBetween(parent, previous, nextPoint, 1.5 - i * 0.08, i % 2 == 0 and palette.PalmTrunk or palette.PalmTrunk:Lerp(WHITE, 0.12), Enum.Material.Wood)
		previous = nextPoint
	end
	for k = 1, 8 do
		local angle = (k / 8) * math.pi * 2
		local leafDirection = Vector3.new(math.cos(angle), -0.3, math.sin(angle)).Unit
		local center = previous + leafDirection * 3.2
		part(parent, {
			Name = "PalmLeaf",
			Size = Vector3.new(2, 0.35, 7),
			CFrame = CFrame.lookAt(center, center + leafDirection),
			Color = k % 2 == 0 and palette.PalmLeaves or palette.PalmLeaves:Lerp(WHITE, 0.12),
			Mesh = Enum.MeshType.Sphere,
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
	for k = 1, 3 do
		local angle = (k / 3) * math.pi * 2
		part(parent, { Name = "Coconut", Shape = Enum.PartType.Ball, Size = Vector3.one * 1, CFrame = CFrame.new(previous + Vector3.new(math.cos(angle) * 0.75, -0.8, math.sin(angle) * 0.75)), Color = rgb(110, 70, 40) })
	end
	return 2.5
end

function Props.pyramid(parent, position, baseSize, layers, palette)
	local layerHeight = baseSize / layers * 0.62
	for i = 0, layers - 1 do
		local size = baseSize * (1 - i / layers)
		part(parent, {
			Name = "Pyramid",
			Size = Vector3.new(size, layerHeight, size),
			CFrame = CFrame.new(position + Vector3.new(0, layerHeight * (i + 0.5), 0)),
			Color = palette.Sandstone[i % 2 + 1],
			Material = Enum.Material.Sandstone,
		})
	end
	-- золотая верхушка
	part(parent, {
		Name = "PyramidTop",
		Size = Vector3.new(baseSize / layers, layerHeight * 1.2, baseSize / layers),
		CFrame = CFrame.new(position + Vector3.new(0, layerHeight * (layers + 0.5), 0)),
		Color = Color3.fromRGB(255, 205, 60),
		Material = Enum.Material.Metal,
		Reflectance = 0.25,
	})
	return baseSize * 0.72
end

function Props.obelisk(parent, position, height, palette)
	part(parent, { Name = "ObeliskBase", Size = Vector3.new(5, 1.5, 5), CFrame = CFrame.new(position + Vector3.new(0, 0.75, 0)), Color = palette.Sandstone[2], Material = Enum.Material.Sandstone })
	part(parent, { Name = "Obelisk", Size = Vector3.new(2.6, height, 2.6), CFrame = CFrame.new(position + Vector3.new(0, 1.5 + height / 2, 0)), Color = palette.Sandstone[1], Material = Enum.Material.Sandstone })
	part(parent, { Name = "ObeliskTip", Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(position + Vector3.new(0, 1.5 + height + 0.6, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Metal })
	for i = 1, 4 do
		part(parent, {
			Name = "Glyph",
			Size = Vector3.new(1, 1, 0.1),
			CFrame = CFrame.new(position + Vector3.new(0, 2 + i * height / 5.5, -1.32)),
			Color = Color3.fromRGB(60, 110, 220),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	return 3
end

function Props.column(parent, position, rng, palette, broken)
	local height = broken and rng:NextNumber(4, 7) or 12
	part(parent, { Name = "ColumnBase", Size = Vector3.new(4, 1, 4), CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)), Color = palette.Sandstone[2], Material = Enum.Material.Sandstone })
	part(parent, { Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 2.6, 2.6), CFrame = CFrame.new(position + Vector3.new(0, 1 + height / 2, 0)) * VERTICAL, Color = palette.Sandstone[1], Material = Enum.Material.Sandstone })
	if not broken then
		part(parent, { Name = "ColumnTop", Size = Vector3.new(4, 1, 4), CFrame = CFrame.new(position + Vector3.new(0, 1.5 + height, 0)), Color = palette.Sandstone[2], Material = Enum.Material.Sandstone })
	end
	return 2.5
end

function Props.torch(parent, position)
	part(parent, { Name = "TorchPole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 0.6, 0.6), CFrame = CFrame.new(position + Vector3.new(0, 3, 0)) * VERTICAL, Color = Color3.fromRGB(110, 70, 40), Material = Enum.Material.Wood })
	local bowl = part(parent, { Name = "TorchBowl", Size = Vector3.new(1.6, 0.9, 1.6), CFrame = CFrame.new(position + Vector3.new(0, 6.2, 0)), Color = Color3.fromRGB(80, 60, 50), Material = Enum.Material.Metal, Mesh = Enum.MeshType.Sphere })
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 150, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 230, 90)
	fire.Parent = bowl
	Build.light(bowl, Color3.fromRGB(255, 170, 70), 18, 1.6)
	return 1.2
end

function Props.vase(parent, position, rng)
	local color = pick(rng, { Color3.fromRGB(200, 110, 70), Color3.fromRGB(80, 140, 200), Color3.fromRGB(220, 170, 90) })
	part(parent, { Name = "Vase", Size = Vector3.new(2.2, 2.6, 2.2), CFrame = CFrame.new(position + Vector3.new(0, 1.2, 0)), Color = color, Mesh = Enum.MeshType.Sphere })
	part(parent, { Name = "VaseNeck", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 1.1, 1.1), CFrame = CFrame.new(position + Vector3.new(0, 2.6, 0)) * VERTICAL, Color = color })
	part(parent, { Name = "VaseStripe", Size = Vector3.new(2.25, 0.3, 2.25), CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)), Color = Color3.fromRGB(255, 220, 120), Mesh = Enum.MeshType.Sphere, CanCollide = false })
	return 1.5
end

function Props.bones(parent, position, rng)
	local yaw = rng:NextNumber(0, math.pi)
	local base = CFrame.new(position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, yaw, 0)
	part(parent, { Name = "Skull", Size = Vector3.new(2.2, 1.8, 2.4), CFrame = base, Color = Color3.fromRGB(245, 240, 225), Mesh = Enum.MeshType.Sphere })
	for i = 1, 4 do
		part(parent, { Name = "Rib", Size = Vector3.new(0.35, 0.35, 3.2), CFrame = base * CFrame.new(-2 - i * 0.9, -0.2, 0) * CFrame.Angles(0, 0, math.rad(15)), Color = Color3.fromRGB(240, 235, 220), CanCollide = false })
	end
	return 3
end

------------------------------------------------------------------ КОСМОС

function Props.crystals(parent, position, rng, colors, withLight)
	local color = pick(rng, colors)
	local count = rng:NextInteger(3, 6)
	local tallest
	for _ = 1, count do
		local height = rng:NextNumber(3, 9)
		local width = height * 0.3
		local crystal = part(parent, {
			Name = "Crystal",
			Size = Vector3.new(width, height, width),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-1.8, 1.8), 0, rng:NextNumber(-1.8, 1.8)))
				* CFrame.Angles(math.rad(rng:NextNumber(-25, 25)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-25, 25)))
				* CFrame.new(0, height * 0.4, 0),
			Color = color,
			Material = Enum.Material.Glass,
			Transparency = 0.15,
			Reflectance = 0.2,
		})
		-- светящаяся сердцевина
		part(parent, {
			Name = "CrystalCore",
			Size = Vector3.new(width * 0.45, height * 0.85, width * 0.45),
			CFrame = crystal.CFrame,
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		if not tallest or crystal.Size.Y > tallest.Size.Y then
			tallest = crystal
		end
	end
	if withLight and tallest then
		Build.light(tallest, color, 16, 1.6)
	end
	return 3.5
end

function Props.alienPlant(parent, position, rng)
	local color = pick(rng, { Color3.fromRGB(110, 255, 200), Color3.fromRGB(255, 120, 230), Color3.fromRGB(150, 140, 255) })
	for i = 1, rng:NextInteger(3, 5) do
		local angle = i * 2.1
		local height = rng:NextNumber(2.5, 5)
		local tip = position + Vector3.new(math.cos(angle) * 1.2, height, math.sin(angle) * 1.2)
		Build.cylinderBetween(parent, position, tip, 0.3, Color3.fromRGB(60, 50, 110))
		local bulb = part(parent, { Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(0.8, 1.3), CFrame = CFrame.new(tip), Color = color, Material = Enum.Material.Neon, CanCollide = false })
		if i == 1 then
			Build.light(bulb, color, 10, 1)
		end
	end
	return 2
end

function Props.dome(parent, position, size)
	part(parent, { Name = "DomeRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, size + 1, size + 1), CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)) * VERTICAL, Color = Color3.fromRGB(200, 205, 225), Material = Enum.Material.Metal })
	part(parent, { Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0)), Color = Color3.fromRGB(160, 220, 255), Material = Enum.Material.Glass, Transparency = 0.45, Reflectance = 0.3 })
	local plant = part(parent, { Name = "DomeGarden", Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.4, CFrame = CFrame.new(position + Vector3.new(0, size * 0.1, 0)), Color = Color3.fromRGB(90, 220, 120), Material = Enum.Material.Grass })
	Build.light(plant, Color3.fromRGB(160, 255, 200), size, 1)
	part(parent, { Name = "DomeDoor", Size = Vector3.new(3, 3.5, 1.5), CFrame = CFrame.new(position + Vector3.new(0, 1.75, -size / 2)), Color = Color3.fromRGB(200, 205, 225), Material = Enum.Material.Metal })
	return size * 0.55
end

function Props.satellite(parent, position, yaw)
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	part(parent, { Name = "DishStand", Size = Vector3.new(1.5, 6, 1.5), CFrame = base * CFrame.new(0, 3, 0), Color = Color3.fromRGB(180, 185, 205), Material = Enum.Material.Metal })
	local dish = base * CFrame.new(0, 7, 0) * CFrame.Angles(math.rad(-50), 0, 0)
	part(parent, { Name = "Dish", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 9, 9), CFrame = dish * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(235, 238, 248), Material = Enum.Material.Metal })
	local tip = part(parent, { Name = "DishTip", Shape = Enum.PartType.Ball, Size = Vector3.one * 1, CFrame = dish * CFrame.new(0, 3, 0), Color = Color3.fromRGB(255, 80, 80), Material = Enum.Material.Neon })
	Build.cylinderBetween(parent, (dish * CFrame.new(0, 0.3, 0)).Position, tip.Position, 0.25, Color3.fromRGB(120, 125, 145))
	return 5
end

function Props.antenna(parent, position)
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		Build.cylinderBetween(parent, position + Vector3.new(math.cos(angle) * 2.5, 0, math.sin(angle) * 2.5), position + Vector3.new(0, 18, 0), 0.4, Color3.fromRGB(200, 205, 225), Enum.Material.Metal)
	end
	for y = 4, 16, 4 do
		part(parent, { Name = "AntennaRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 5 - y * 0.25, 5 - y * 0.25), CFrame = CFrame.new(position + Vector3.new(0, y, 0)) * VERTICAL, Color = Color3.fromRGB(150, 155, 180), Material = Enum.Material.Metal, CanCollide = false })
	end
	local beacon = part(parent, { Name = "Beacon", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = CFrame.new(position + Vector3.new(0, 18.6, 0)), Color = Color3.fromRGB(255, 60, 90), Material = Enum.Material.Neon })
	Build.light(beacon, Color3.fromRGB(255, 80, 100), 22, 2)
	return 3
end

function Props.rocket(parent, position)
	local body = Color3.fromRGB(240, 240, 250)
	local red = Color3.fromRGB(240, 70, 80)
	Build.disc(parent, position + Vector3.new(0, 0.3, 0), 12, 0.6, Color3.fromRGB(60, 55, 90), { Material = Enum.Material.Metal, Name = "LaunchPad" })
	part(parent, { Name = "RocketBody", Shape = Enum.PartType.Cylinder, Size = Vector3.new(16, 5.5, 5.5), CFrame = CFrame.new(position + Vector3.new(0, 10, 0)) * VERTICAL, Color = body })
	part(parent, { Name = "RocketStripe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 5.7, 5.7), CFrame = CFrame.new(position + Vector3.new(0, 7, 0)) * VERTICAL, Color = red })
	part(parent, { Name = "RocketNose", Size = Vector3.new(5.5, 7, 5.5), CFrame = CFrame.new(position + Vector3.new(0, 18, 0)), Color = red, Mesh = Enum.MeshType.Sphere })
	local window = part(parent, { Name = "RocketWindow", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = CFrame.new(position + Vector3.new(0, 13, -2.4)), Color = Color3.fromRGB(110, 230, 255), Material = Enum.Material.Neon })
	Build.light(window, Color3.fromRGB(110, 230, 255), 10, 1)
	for i = 1, 3 do
		local angle = (i / 3) * math.pi * 2
		part(parent, { Name = "RocketFin", Size = Vector3.new(0.6, 6, 3.2), CFrame = CFrame.new(position + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, 3.2), Color = red })
	end
	local flame = part(parent, { Name = "RocketFlame", Size = Vector3.new(3.2, 3.6, 3.2), CFrame = CFrame.new(position + Vector3.new(0, 1.8, 0)), Color = Color3.fromRGB(255, 160, 40), Material = Enum.Material.Neon, Mesh = Enum.MeshType.Sphere, CanCollide = false })
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 12
	fire.Color = Color3.fromRGB(255, 140, 40)
	fire.SecondaryColor = Color3.fromRGB(120, 200, 255)
	fire.Parent = flame
	return 7
end

-- Летающий астероид (покачивается на клиенте).
function Props.asteroid(parent, position, rng, color)
	local size = rng:NextNumber(4, 12)
	local rock = part(parent, {
		Name = "Asteroid",
		Size = Vector3.new(size, size * rng:NextNumber(0.7, 1), size * rng:NextNumber(0.8, 1.1)),
		CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
		Color = vary(color, rng, 0.1),
		Material = Enum.Material.Slate,
		Mesh = Enum.MeshType.Sphere,
		CanCollide = false,
	})
	rock:SetAttribute("SpinSpeed", rng:NextNumber(0.4, 1))
	rock:SetAttribute("BobHeight", rng:NextNumber(1, 3))
	CollectionService:AddTag(rock, "Bob")
	return size
end

return Props
