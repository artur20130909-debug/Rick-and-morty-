--[[
	IconModels — собственные 3D-иконки игры, собранные из деталей (никаких картинок и эмодзи).
	Каждая иконка — модель с центром в (0, 0, 0), «лицом» к камере (камера смотрит из -Z).

	IconModels.Build(name, options) -> Model
	options.Color / options.Color2 — перекрасить иконку (рюкзаки разных уровней, яйца и т. п.)

	Список иконок: Coin, Star, Dumbbell, Rebirth, Paw, ShopBag, Globe, Backpack, Egg, Lock, Trash,
	Crown, Check, Cross, Exclamation, MoneyBag, Portal, Tree, Cactus, Rocket, Note, Sparkle, Gift.
]]

local IconModels = {}

local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(35, 30, 60)
local GOLD = Color3.fromRGB(255, 200, 45)
local GOLD_LIGHT = Color3.fromRGB(255, 230, 120)
local GOLD_DARK = Color3.fromRGB(225, 150, 20)
local METAL = Color3.fromRGB(110, 115, 135)
local METAL_LIGHT = Color3.fromRGB(190, 195, 210)

local HALF_PI = math.pi / 2

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function lighten(color, amount)
	return color:Lerp(WHITE, amount)
end

local function darken(color, amount)
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

------------------------------------------------------------------ ДЕТАЛИ

-- kind: "Block" | "Ball" | "Cylinder" | "Ellipsoid" | "Wedge"
local function add(model, kind, size, cframe, color, options)
	options = options or {}
	local part
	if kind == "Wedge" then
		part = Instance.new("WedgePart")
	else
		part = Instance.new("Part")
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if kind == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif kind == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif kind == "Ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = options.Material or Enum.Material.SmoothPlastic
	part.Reflectance = options.Reflectance or 0
	part.Transparency = options.Transparency or 0
	if options.NoOutline then
		part:SetAttribute("NoOutline", true)
	end
	part.Parent = model
	return part
end

-- Цилиндр, ось которого смотрит на камеру (монеты, диски).
local function discZ(model, center, diameter, depth, color, options)
	return add(model, "Cylinder", Vector3.new(depth, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, HALF_PI, 0), color, options)
end

-- Вертикальный цилиндр.
local function cylinderY(model, center, height, diameter, color, options)
	return add(model, "Cylinder", Vector3.new(height, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, 0, HALF_PI), color, options)
end

-- Равнобедренный треугольник в плоскости XY системы cframe: основание в начале координат, вершина вверх (+Y).
local function triangle(model, cframe, baseWidth, height, depth, color, options)
	local half = baseWidth / 2
	add(model, "Wedge", Vector3.new(depth, height, half), cframe * CFrame.new(half / 2, height / 2, 0) * CFrame.Angles(0, -HALF_PI, 0), color, options)
	add(model, "Wedge", Vector3.new(depth, height, half), cframe * CFrame.new(-half / 2, height / 2, 0) * CFrame.Angles(0, HALF_PI, 0), color, options)
end

-- Звезда в плоскости XY (лицом к камере).
local function star(model, center, points, outer, inner, depth, color, options)
	add(model, "Cylinder", Vector3.new(depth, inner * 2, inner * 2), center * CFrame.Angles(0, HALF_PI, 0), color, options)
	local baseDistance = inner * math.cos(math.pi / points)
	local halfBase = inner * math.sin(math.pi / points)
	for i = 0, points - 1 do
		local angle = i * (2 * math.pi / points)
		local spike = center * CFrame.Angles(0, 0, -angle) * CFrame.new(0, baseDistance - 0.02, 0)
		triangle(model, spike, halfBase * 2 + 0.04, outer - baseDistance, depth, color, options)
	end
end

-- Дуга из блоков в плоскости XY: от угла a до угла b (радианы, 0 = вверх, по часовой).
local function arc(model, center, radius, thickness, depth, fromAngle, toAngle, segments, color, options)
	local step = (toAngle - fromAngle) / segments
	local chord = 2 * radius * math.sin(math.abs(step) / 2) + thickness * 0.35
	for i = 0, segments - 1 do
		local angle = fromAngle + step * (i + 0.5)
		add(model, "Block", Vector3.new(chord, thickness, depth), center * CFrame.Angles(0, 0, -angle) * CFrame.new(0, radius, 0), color, options)
	end
end

------------------------------------------------------------------ ИКОНКИ

local Builders = {}

function Builders.Coin(model, options)
	local color = options.Color or GOLD
	discZ(model, Vector3.zero, 3, 0.5, darken(color, 0.12), { Reflectance = 0.1 })
	discZ(model, Vector3.new(0, 0, -0.08), 2.55, 0.5, color, { Reflectance = 0.15 })
	discZ(model, Vector3.new(0, 0, -0.14), 2.1, 0.5, lighten(color, 0.25))
	star(model, CFrame.new(0, -0.02, -0.42), 5, 0.78, 0.34, 0.12, darken(color, 0.1))
	add(model, "Ellipsoid", Vector3.new(0.6, 0.3, 0.1), CFrame.new(-0.62, 0.72, -0.43) * CFrame.Angles(0, 0, math.rad(35)), WHITE, { Transparency = 0.25, NoOutline = true })
	return { Yaw = math.rad(-18), Pitch = 0.1 }
end

function Builders.Star(model, options)
	local color = options.Color or GOLD
	star(model, CFrame.new(0, 0, 0), 5, 1.65, 0.72, 0.55, darken(color, 0.08))
	star(model, CFrame.new(0, 0.02, -0.2), 5, 1.2, 0.52, 0.3, lighten(color, 0.2))
	add(model, "Ellipsoid", Vector3.new(0.45, 0.22, 0.08), CFrame.new(-0.28, 0.42, -0.38) * CFrame.Angles(0, 0, math.rad(30)), WHITE, { Transparency = 0.2, NoOutline = true })
	return { Yaw = math.rad(-15), Pitch = 0.05 }
end

function Builders.Sparkle(model, options)
	local color = options.Color or GOLD_LIGHT
	star(model, CFrame.new(0, 0, 0), 4, 1.7, 0.45, 0.4, color, { Material = Enum.Material.Neon })
	star(model, CFrame.new(1.1, 1.1, -0.1), 4, 0.6, 0.16, 0.25, WHITE, { Material = Enum.Material.Neon })
	return { Yaw = 0, Pitch = 0 }
end

function Builders.Dumbbell(model, options)
	local plate = options.Color or rgb(255, 80, 80)
	local cf = CFrame.Angles(0, 0, math.rad(-20))
	add(model, "Cylinder", Vector3.new(3.6, 0.32, 0.32), cf, METAL_LIGHT, { Material = Enum.Material.Metal })
	for _, side in ipairs({ -1, 1 }) do
		add(model, "Cylinder", Vector3.new(0.42, 1.9, 1.9), cf * CFrame.new(side * 0.95, 0, 0), plate)
		add(model, "Cylinder", Vector3.new(0.36, 1.45, 1.45), cf * CFrame.new(side * 1.33, 0, 0), lighten(plate, 0.15))
		add(model, "Cylinder", Vector3.new(0.18, 0.55, 0.55), cf * CFrame.new(side * 1.66, 0, 0), METAL, { Material = Enum.Material.Metal })
		add(model, "Cylinder", Vector3.new(0.44, 0.7, 0.7), cf * CFrame.new(side * 0.95, 0, 0), METAL, { Material = Enum.Material.Metal })
	end
	-- рукоять с насечками
	for i = -2, 2 do
		add(model, "Cylinder", Vector3.new(0.1, 0.38, 0.38), cf * CFrame.new(i * 0.14, 0, 0), METAL, { Material = Enum.Material.Metal })
	end
	return { Yaw = math.rad(-30), Pitch = 0.35 }
end

function Builders.Rebirth(model, options)
	local color = options.Color or rgb(176, 108, 255)
	local light = lighten(color, 0.3)
	local center = CFrame.new()
	for _, offset in ipairs({ 0, math.pi }) do
		arc(model, center, 1.25, 0.42, 0.45, offset + math.rad(15), offset + math.rad(150), 9, color)
		-- наконечник стрелки по касательной
		local tipAngle = offset + math.rad(150)
		local tip = center * CFrame.Angles(0, 0, -tipAngle) * CFrame.new(0, 1.25, 0) * CFrame.Angles(0, 0, -HALF_PI)
		triangle(model, tip, 1.05, 0.7, 0.45, light)
	end
	add(model, "Ball", Vector3.one * 0.7, CFrame.new(0, 0, 0), light, { Material = Enum.Material.Neon })
	return { Yaw = math.rad(-12), Pitch = 0.1 }
end

function Builders.Paw(model, options)
	local pad = options.Color or rgb(255, 130, 175)
	local base = options.Color2 or WHITE
	add(model, "Ellipsoid", Vector3.new(2.2, 1.85, 0.6), CFrame.new(0, -0.5, 0.05), base)
	add(model, "Ellipsoid", Vector3.new(1.6, 1.3, 0.6), CFrame.new(0, -0.55, -0.12), pad)
	local toes = { { -1.05, 0.55, -20 }, { -0.4, 1.1, -6 }, { 0.4, 1.1, 6 }, { 1.05, 0.55, 20 } }
	for _, toe in ipairs(toes) do
		local cf = CFrame.new(toe[1], toe[2], 0.05) * CFrame.Angles(0, 0, math.rad(-toe[3]))
		add(model, "Ellipsoid", Vector3.new(0.8, 0.98, 0.55), cf, base)
		add(model, "Ellipsoid", Vector3.new(0.56, 0.72, 0.55), cf * CFrame.new(0, -0.02, -0.15), pad)
	end
	return { Yaw = math.rad(-12), Pitch = 0.05 }
end

function Builders.ShopBag(model, options)
	local color = options.Color or rgb(255, 160, 50)
	add(model, "Block", Vector3.new(2.3, 2.3, 1.1), CFrame.new(0, -0.35, 0), color)
	add(model, "Block", Vector3.new(2.36, 0.35, 1.16), CFrame.new(0, 0.62, 0), darken(color, 0.15))
	-- ручка
	arc(model, CFrame.new(0, 0.85, -0.1), 0.62, 0.18, 0.18, math.rad(-80), math.rad(80), 8, METAL_LIGHT)
	arc(model, CFrame.new(0, 0.85, 0.3), 0.62, 0.18, 0.18, math.rad(-80), math.rad(80), 8, METAL_LIGHT)
	-- звезда-эмблема
	star(model, CFrame.new(0, -0.4, -0.58), 5, 0.62, 0.27, 0.1, rgb(255, 245, 210))
	return { Yaw = math.rad(-25), Pitch = 0.2 }
end

function Builders.Globe(model, options)
	local ocean = options.Color or rgb(70, 160, 255)
	add(model, "Ball", Vector3.one * 2.8, CFrame.new(), ocean)
	local land = rgb(100, 210, 90)
	local lands = {
		{ Vector3.new(-0.55, 0.5, -1.1), Vector3.new(1.0, 0.8, 0.5) },
		{ Vector3.new(0.6, -0.35, -1.15), Vector3.new(0.9, 1.0, 0.5) },
		{ Vector3.new(-0.3, -0.75, -1.05), Vector3.new(0.6, 0.45, 0.5) },
		{ Vector3.new(0.85, 0.75, -0.8), Vector3.new(0.5, 0.4, 0.5) },
	}
	for _, item in ipairs(lands) do
		local position = item[1].Unit * 1.32
		add(model, "Ellipsoid", item[2], CFrame.lookAt(position, position * 2), land)
	end
	-- кольцо
	local ring = CFrame.Angles(math.rad(70), 0, math.rad(-20))
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local p = ring * Vector3.new(math.cos(angle) * 2.05, 0, math.sin(angle) * 2.05)
		add(model, "Ball", Vector3.one * 0.26, CFrame.new(p), GOLD, { NoOutline = true })
	end
	return { Yaw = math.rad(-20), Pitch = 0.15 }
end

function Builders.Backpack(model, options)
	local color = options.Color or rgb(90, 170, 255)
	local dark = darken(color, 0.22)
	add(model, "Block", Vector3.new(2.1, 2.2, 1.2), CFrame.new(0, -0.3, 0), color)
	add(model, "Ellipsoid", Vector3.new(2.1, 1.2, 1.2), CFrame.new(0, 0.8, 0), color)
	-- клапан
	add(model, "Ellipsoid", Vector3.new(2.0, 1.1, 0.4), CFrame.new(0, 0.62, -0.45), dark)
	-- карман
	add(model, "Block", Vector3.new(1.4, 0.95, 0.35), CFrame.new(0, -0.65, -0.68), lighten(color, 0.15))
	add(model, "Block", Vector3.new(1.42, 0.22, 0.38), CFrame.new(0, -0.24, -0.69), dark)
	add(model, "Ball", Vector3.one * 0.22, CFrame.new(0, -0.35, -0.88), GOLD)
	-- лямки по бокам
	for _, side in ipairs({ -1, 1 }) do
		add(model, "Block", Vector3.new(0.25, 2.2, 0.4), CFrame.new(side * 1.12, -0.2, 0.2), dark)
	end
	-- ручка
	arc(model, CFrame.new(0, 1.25, 0.1), 0.38, 0.15, 0.15, math.rad(-80), math.rad(80), 6, dark)
	return { Yaw = math.rad(-25), Pitch = 0.15 }
end

function Builders.Egg(model, options)
	local color = options.Color or rgb(150, 225, 110)
	local spot = options.Color2 or rgb(80, 165, 60)
	add(model, "Ellipsoid", Vector3.new(2.3, 2.95, 2.3), CFrame.new(), color)
	local spots = { { 25, 10, 0.55 }, { 100, -18, 0.45 }, { 160, 28, 0.5 }, { 220, -5, 0.4 }, { 300, 35, 0.48 }, { 60, 50, 0.35 }, { 260, -40, 0.4 } }
	for _, s in ipairs(spots) do
		local around, elevation = math.rad(s[1] + 90), math.rad(s[2])
		local offset = Vector3.new(math.cos(elevation) * math.cos(around) * 1.15, math.sin(elevation) * 1.47, math.cos(elevation) * math.sin(around) * 1.15)
		add(model, "Ball", Vector3.one * s[3], CFrame.new(offset * 0.94), spot)
	end
	add(model, "Ellipsoid", Vector3.new(0.4, 0.7, 0.2), CFrame.new(-0.5, 0.6, -0.95) * CFrame.Angles(0, 0, math.rad(20)), WHITE, { Transparency = 0.35, NoOutline = true })
	return { Yaw = 0, Pitch = 0.05 }
end

function Builders.Lock(model, options)
	local color = options.Color or GOLD
	arc(model, CFrame.new(0, 0.45, 0), 0.72, 0.3, 0.3, math.rad(-90), math.rad(90), 10, METAL_LIGHT, { Material = Enum.Material.Metal })
	for _, side in ipairs({ -1, 1 }) do
		add(model, "Block", Vector3.new(0.3, 0.55, 0.3), CFrame.new(side * 0.72, 0.25, 0), METAL_LIGHT, { Material = Enum.Material.Metal })
	end
	add(model, "Block", Vector3.new(2.0, 1.6, 0.8), CFrame.new(0, -0.55, 0), color, { Reflectance = 0.1 })
	add(model, "Block", Vector3.new(1.7, 1.3, 0.1), CFrame.new(0, -0.55, -0.42), lighten(color, 0.2))
	discZ(model, Vector3.new(0, -0.38, -0.5), 0.42, 0.1, INK)
	triangle(model, CFrame.new(0, -0.95, -0.5), 0.36, 0.55, 0.1, INK)
	return { Yaw = math.rad(-18), Pitch = 0.1 }
end

function Builders.Trash(model, options)
	local color = options.Color or rgb(255, 90, 90)
	cylinderY(model, Vector3.new(0, -0.3, 0), 2.2, 1.9, color)
	for i = 0, 3 do
		local angle = math.rad(-60 + i * 40)
		add(model, "Block", Vector3.new(0.14, 1.7, 0.1), CFrame.new(math.sin(angle) * 0.96, -0.3, -math.cos(angle) * 0.96) * CFrame.Angles(0, -angle, 0), darken(color, 0.25))
	end
	cylinderY(model, Vector3.new(0, 0.92, 0), 0.25, 2.2, darken(color, 0.15))
	add(model, "Block", Vector3.new(0.8, 0.2, 0.3), CFrame.new(0, 1.18, 0), METAL_LIGHT)
	return { Yaw = math.rad(-15), Pitch = 0.45 }
end

function Builders.Crown(model, options)
	local color = options.Color or GOLD
	cylinderY(model, Vector3.new(0, -0.5, 0), 0.75, 2.6, color, { Reflectance = 0.15 })
	cylinderY(model, Vector3.new(0, -0.82, 0), 0.22, 2.7, GOLD_DARK)
	for i = 0, 4 do
		local angle = i / 5 * math.pi * 2
		local position = Vector3.new(math.sin(angle) * 1.15, 0.15, -math.cos(angle) * 1.15)
		add(model, "Block", Vector3.new(0.75, 0.75, 0.3), CFrame.new(position) * CFrame.Angles(0, -angle, math.rad(45)), color, { Reflectance = 0.15 })
		add(model, "Ball", Vector3.one * 0.35, CFrame.new(position + Vector3.new(0, 0.6, 0)), GOLD_LIGHT)
	end
	local gems = { rgb(255, 60, 100), rgb(80, 200, 255), rgb(120, 255, 140) }
	for i, gem in ipairs(gems) do
		local angle = math.rad(-40 + (i - 1) * 40)
		add(model, "Ball", Vector3.one * 0.4, CFrame.new(math.sin(angle) * 1.3, -0.5, -math.cos(angle) * 1.3), gem, { Material = Enum.Material.Neon })
	end
	return { Yaw = 0, Pitch = 0.55 }
end

function Builders.Check(model, options)
	local color = options.Color or rgb(90, 220, 90)
	add(model, "Block", Vector3.new(0.6, 1.3, 0.5), CFrame.new(-0.55, -0.15, 0) * CFrame.Angles(0, 0, math.rad(40)), color)
	add(model, "Block", Vector3.new(0.6, 2.5, 0.5), CFrame.new(0.42, 0.35, 0) * CFrame.Angles(0, 0, math.rad(-35)), color)
	return { Yaw = math.rad(-12), Pitch = 0 }
end

function Builders.Cross(model, options)
	local color = options.Color or rgb(255, 80, 80)
	add(model, "Block", Vector3.new(0.6, 2.4, 0.5), CFrame.Angles(0, 0, math.rad(45)), color)
	add(model, "Block", Vector3.new(0.6, 2.4, 0.5), CFrame.Angles(0, 0, math.rad(-45)), color)
	return { Yaw = math.rad(-12), Pitch = 0 }
end

function Builders.Exclamation(model, options)
	local color = options.Color or rgb(255, 170, 40)
	add(model, "Ellipsoid", Vector3.new(0.75, 1.9, 0.6), CFrame.new(0, 0.4, 0), color)
	add(model, "Ball", Vector3.one * 0.7, CFrame.new(0, -1.15, 0), color)
	return { Yaw = math.rad(-12), Pitch = 0 }
end

function Builders.MoneyBag(model, options)
	local color = options.Color or rgb(120, 200, 90)
	add(model, "Ellipsoid", Vector3.new(2.4, 2.3, 2.2), CFrame.new(0, -0.35, 0), color)
	cylinderY(model, Vector3.new(0, 0.85, 0), 0.4, 0.7, darken(color, 0.1))
	cylinderY(model, Vector3.new(0, 0.92, 0), 0.18, 0.85, GOLD)
	for i = 0, 2 do
		local angle = math.rad(-40 + i * 40)
		add(model, "Ellipsoid", Vector3.new(0.45, 0.6, 0.35), CFrame.new(math.sin(angle) * 0.35, 1.25, -math.cos(angle) * 0.2) * CFrame.Angles(0, 0, -angle), color)
	end
	-- монета на мешке
	discZ(model, Vector3.new(0, -0.4, -1.1), 1.0, 0.18, GOLD)
	star(model, CFrame.new(0, -0.41, -1.21), 5, 0.32, 0.14, 0.06, GOLD_DARK)
	return { Yaw = math.rad(-15), Pitch = 0.1 }
end

function Builders.Portal(model, options)
	local color = options.Color or rgb(170, 110, 255)
	arc(model, CFrame.new(), 1.45, 0.38, 0.45, 0, math.pi * 2, 20, darken(color, 0.25))
	discZ(model, Vector3.new(0, 0, 0.05), 2.5, 0.2, color, { Material = Enum.Material.Neon, Transparency = 0.1 })
	arc(model, CFrame.new(0, 0, -0.15), 0.8, 0.14, 0.1, 0, math.rad(260), 10, WHITE, { Material = Enum.Material.Neon, NoOutline = true })
	return { Yaw = math.rad(-15), Pitch = 0 }
end

function Builders.Tree(model, options)
	local leaves = options.Color or rgb(90, 190, 80)
	cylinderY(model, Vector3.new(0, -1.0, 0), 1.3, 0.55, rgb(140, 95, 60))
	add(model, "Ball", Vector3.one * 1.9, CFrame.new(0, 0.05, 0), leaves)
	add(model, "Ball", Vector3.one * 1.35, CFrame.new(-0.75, -0.2, -0.2), darken(leaves, 0.08))
	add(model, "Ball", Vector3.one * 1.35, CFrame.new(0.75, -0.15, -0.15), lighten(leaves, 0.08))
	add(model, "Ball", Vector3.one * 1.2, CFrame.new(0.1, 0.85, -0.1), lighten(leaves, 0.15))
	add(model, "Ball", Vector3.one * 0.3, CFrame.new(-0.5, 0.3, -0.92), rgb(255, 80, 90))
	add(model, "Ball", Vector3.one * 0.3, CFrame.new(0.45, 0.65, -0.75), rgb(255, 80, 90))
	return { Yaw = math.rad(-10), Pitch = 0.1 }
end

function Builders.Cactus(model, options)
	local color = options.Color or rgb(90, 180, 80)
	cylinderY(model, Vector3.new(0, -0.1, 0), 2.6, 0.8, color)
	add(model, "Ball", Vector3.one * 0.8, CFrame.new(0, 1.2, 0), color)
	for _, item in ipairs({ { -1, -0.1, 0.8 }, { 1, 0.3, 0.6 } }) do
		local side, y, h = item[1], item[2], item[3]
		add(model, "Cylinder", Vector3.new(0.6, 0.5, 0.5), CFrame.new(side * 0.55, y, 0), color)
		cylinderY(model, Vector3.new(side * 0.8, y + h / 2, 0), h, 0.5, color)
		add(model, "Ball", Vector3.one * 0.5, CFrame.new(side * 0.8, y + h, 0), color)
	end
	add(model, "Ball", Vector3.one * 0.45, CFrame.new(0, 1.62, 0), rgb(255, 100, 170))
	-- горшок-песок
	cylinderY(model, Vector3.new(0, -1.45, 0), 0.4, 1.8, rgb(240, 200, 130))
	return { Yaw = math.rad(-15), Pitch = 0.15 }
end

function Builders.Rocket(model, options)
	local body = options.Color or rgb(240, 240, 250)
	local red = rgb(255, 80, 90)
	local tilt = CFrame.Angles(0, 0, math.rad(-35))
	add(model, "Cylinder", Vector3.new(2.2, 1.1, 1.1), tilt * CFrame.Angles(0, 0, HALF_PI), body)
	add(model, "Ellipsoid", Vector3.new(1.1, 1.3, 1.1), tilt * CFrame.new(0, 1.3, 0), red)
	add(model, "Ball", Vector3.one * 0.55, tilt * CFrame.new(0, 0.35, -0.45), rgb(110, 220, 255), { Material = Enum.Material.Neon })
	for i = 0, 2 do
		local angle = i / 3 * math.pi * 2
		add(model, "Block", Vector3.new(0.12, 0.8, 0.6), tilt * CFrame.new(0, -0.95, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, 0.7), red)
	end
	add(model, "Ellipsoid", Vector3.new(0.7, 1.0, 0.7), tilt * CFrame.new(0, -1.55, 0), rgb(255, 170, 50), { Material = Enum.Material.Neon })
	add(model, "Ellipsoid", Vector3.new(0.4, 0.6, 0.4), tilt * CFrame.new(0, -1.85, 0), rgb(255, 240, 150), { Material = Enum.Material.Neon, NoOutline = true })
	return { Yaw = math.rad(-20), Pitch = 0.1 }
end

function Builders.Note(model, options)
	local color = options.Color or rgb(120, 200, 255)
	add(model, "Ellipsoid", Vector3.new(0.9, 0.7, 0.5), CFrame.new(-0.75, -0.95, 0) * CFrame.Angles(0, 0, math.rad(20)), color)
	add(model, "Ellipsoid", Vector3.new(0.9, 0.7, 0.5), CFrame.new(0.85, -0.6, 0) * CFrame.Angles(0, 0, math.rad(20)), color)
	add(model, "Block", Vector3.new(0.18, 1.9, 0.18), CFrame.new(-0.4, 0.05, 0), color)
	add(model, "Block", Vector3.new(0.18, 1.9, 0.18), CFrame.new(1.2, 0.4, 0), color)
	add(model, "Block", Vector3.new(1.8, 0.4, 0.2), CFrame.new(0.4, 1.0, 0) * CFrame.Angles(0, 0, math.rad(12)), color)
	return { Yaw = math.rad(-12), Pitch = 0 }
end

function Builders.Gift(model, options)
	local color = options.Color or rgb(255, 90, 140)
	local ribbon = options.Color2 or GOLD
	add(model, "Block", Vector3.new(2.2, 1.7, 2.2), CFrame.new(0, -0.4, 0), color)
	add(model, "Block", Vector3.new(2.4, 0.5, 2.4), CFrame.new(0, 0.6, 0), lighten(color, 0.1))
	add(model, "Block", Vector3.new(0.45, 2.25, 2.45), CFrame.new(0, -0.15, 0), ribbon)
	add(model, "Block", Vector3.new(2.45, 2.25, 0.45), CFrame.new(0, -0.15, 0), ribbon)
	for _, side in ipairs({ -1, 1 }) do
		add(model, "Ellipsoid", Vector3.new(0.9, 0.6, 0.35), CFrame.new(side * 0.45, 1.05, 0) * CFrame.Angles(0, 0, side * math.rad(-30)), ribbon)
	end
	return { Yaw = math.rad(-30), Pitch = 0.3 }
end

-- Список имён (для проверок).
IconModels.Names = {}
for name in pairs(Builders) do
	table.insert(IconModels.Names, name)
end
table.sort(IconModels.Names)

function IconModels.Build(name, options)
	options = options or {}
	local builder = Builders[name]
	if not builder then
		warn("[IconModels] Нет иконки", name)
		builder = Builders.Star
	end
	local model = Instance.new("Model")
	model.Name = "Icon_" .. tostring(name)
	local root = add(model, "Block", Vector3.new(0.1, 0.1, 0.1), CFrame.identity, WHITE, { Transparency = 1, NoOutline = true })
	root.Name = "Root"
	model.PrimaryPart = root
	local view = builder(model, options) or {}
	return model, view
end

return IconModels
