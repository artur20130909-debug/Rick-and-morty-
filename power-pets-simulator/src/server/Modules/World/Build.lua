--[[
	Build — помощники для строительства миров: детали, надписи, рельеф (Terrain),
	поиск высоты земли и расстановка декора без наложений.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)

local Build = {}

Build.HALF = 130 -- половина стороны игровой зоны: невидимые стены стоят на ±HALF
Build.VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- делает цилиндр вертикальным
Build.WHITE = Color3.new(1, 1, 1)
Build.INK = Color3.fromRGB(32, 26, 58)
Build.FONT = Font.new(Font.fromEnum(Enum.Font.Nunito).Family, Enum.FontWeight.Heavy)
Build.Format = Format

-- Главные точки каждого мира (относительно центра мира).
Build.LAYOUT = {
	Spawn = Vector3.new(0, 0, 70),
	Fountain = Vector3.new(-24, 0, 72),
	ShopStall = Vector3.new(26, 0, 74),
	WelcomeArch = Vector3.new(0, 0, 50),
	NextPortal = Vector3.new(0, 0, -112),
	BackPortal = Vector3.new(0, 0, 118),
	Sell = Vector3.new(-45, 0, 35),
	EggPlaza = Vector3.new(40, 0, 20),
}

-- Зоны, где нельзя ставить декор. Coins = true — монеты там появляться могут (тропинки).
Build.RESERVED = {
	{ Kind = "Rect", MinX = -10, MaxX = 10, MinZ = -128, MaxZ = 128, Coins = true },
	{ Kind = "Rect", MinX = -52, MaxX = 0, MinZ = 29, MaxZ = 41, Coins = true },
	{ Kind = "Rect", MinX = 0, MaxX = 44, MinZ = 14, MaxZ = 26, Coins = true },
	{ Kind = "Circle", X = 0, Z = 70, R = 38 },
	{ Kind = "Circle", X = -46, Z = 42, R = 22 },
	{ Kind = "Circle", X = 40, Z = 20, R = 25 },
	{ Kind = "Circle", X = 0, Z = -112, R = 18 },
	{ Kind = "Circle", X = 0, Z = 118, R = 16 },
}

------------------------------------------------------------------ ДЕТАЛИ

function Build.part(parent, props)
	local part = Instance.new(props.ClassName or "Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		if key ~= "ClassName" and key ~= "Mesh" and key ~= "Tags" then
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

function Build.folder(name, parent)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Build.model(name, parent)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Build.cylinderBetween(parent, a, b, diameter, color, material)
	local length = (b - a).Magnitude
	return Build.part(parent, {
		Name = "Cylinder",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, diameter, diameter),
		CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

-- Вертикальный цилиндр (диск), position — его центр.
function Build.disc(parent, position, diameter, height, color, props)
	local data = {
		Name = "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(position) * Build.VERTICAL,
		Color = color,
	}
	for key, value in pairs(props or {}) do
		data[key] = value
	end
	return Build.part(parent, data)
end

-- Двускатная крыша: конёк вдоль оси X системы cframe (cframe — центр основания крыши).
function Build.roof(parent, cframe, width, depth, height, color, material)
	for _, side in ipairs({ -1, 1 }) do
		Build.part(parent, {
			ClassName = "WedgePart",
			Name = "Roof",
			Size = Vector3.new(width, height, depth / 2),
			CFrame = cframe * CFrame.new(0, height / 2, side * depth / 4) * CFrame.Angles(0, side == 1 and math.pi or 0, 0),
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
		})
	end
end

function Build.light(part, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 12
	light.Brightness = brightness or 1
	light.Shadows = false
	light.Parent = part
	return light
end

------------------------------------------------------------------ НАДПИСИ

function Build.billboard(adornee, sizeStuds, offset, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Billboard"
	gui.Size = UDim2.new(sizeStuds.X, 0, sizeStuds.Y, 0)
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = maxDistance or 150
	gui.LightInfluence = 0
	gui.Parent = adornee
	return gui
end

function Build.line(parent, text, color, heightScale, order, name)
	local label = Instance.new("TextLabel")
	label.Name = name or ("Line" .. order)
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, heightScale)
	label.FontFace = Build.FONT
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.LayoutOrder = order
	local stroke = Instance.new("UIStroke")
	stroke.Color = Build.INK
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = parent
	return label
end

function Build.list(parent, padding)
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(padding or 0, 0)
	list.Parent = parent
	return list
end

-- Надпись на грани детали (вывески).
function Build.sign(part, face, text, textColor, backgroundColor)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = backgroundColor or Build.INK
	frame.BackgroundTransparency = backgroundColor and 0 or 1
	frame.Parent = gui
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.92, 0.8)
	label.Position = UDim2.fromScale(0.04, 0.1)
	label.FontFace = Build.FONT
	label.Text = text
	label.TextColor3 = textColor or Build.WHITE
	label.TextScaled = true
	label.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Build.INK
	stroke.Thickness = 6
	stroke.Parent = label
	return gui
end

------------------------------------------------------------------ РЕЛЬЕФ (TERRAIN)

function Build.terrainBlock(cframe, size, material)
	Workspace.Terrain:FillBlock(cframe, size, material)
end

function Build.terrainBall(center, radius, material)
	Workspace.Terrain:FillBall(center, radius, material)
end

function Build.terrainCylinder(cframe, height, radius, material)
	Workspace.Terrain:FillCylinder(cframe, height, radius, material)
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.IgnoreWater = false

-- Высота земли (Terrain) в точке мира; nil, если там пусто. Второе значение — материал.
function Build.groundAt(position, fallbackY)
	groundParams.FilterDescendantsInstances = { Workspace.Terrain }
	local origin = Vector3.new(position.X, position.Y + 120, position.Z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -260, 0), groundParams)
	if result then
		return result.Position.Y, result.Material
	end
	return fallbackY, nil
end

------------------------------------------------------------------ РАССТАНОВКА

function Build.isFree(ctx, x, z, radius, forCoin)
	local half = Build.HALF
	if math.abs(x) > half - 4 - radius or math.abs(z) > half - 4 - radius then
		return false
	end
	for _, zone in ipairs(Build.RESERVED) do
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
	for _, obstacle in ipairs(ctx.Obstacles) do
		local dx, dz = x - obstacle.X, z - obstacle.Z
		if dx * dx + dz * dz < (obstacle.R + radius) ^ 2 then
			return false
		end
	end
	return true
end

function Build.addObstacle(ctx, x, z, radius)
	table.insert(ctx.Obstacles, { X = x, Z = z, R = radius })
end

-- Ставит count объектов в свободные места игровой зоны. place(позиция на земле) -> радиус.
function Build.scatter(ctx, count, radius, place)
	local placed = 0
	local half = Build.HALF
	for _ = 1, count * 15 do
		if placed >= count then
			break
		end
		local x = ctx.Rng:NextNumber(-half, half)
		local z = ctx.Rng:NextNumber(-half, half)
		if Build.isFree(ctx, x, z, radius, false) then
			local groundY, material = Build.groundAt(ctx.Origin + Vector3.new(x, 0, z), ctx.Origin.Y)
			if material ~= Enum.Material.Water then
				local actualRadius = place(Vector3.new(ctx.Origin.X + x, groundY, ctx.Origin.Z + z)) or radius
				Build.addObstacle(ctx, x, z, actualRadius)
				placed += 1
			end
		end
	end
	return placed
end

-- Случайная точка за стенами (декор по краям мира).
function Build.borderPoint(rng, inner, outer)
	for _ = 1, 100 do
		local x = rng:NextNumber(-outer, outer)
		local z = rng:NextNumber(-outer, outer)
		if math.max(math.abs(x), math.abs(z)) >= inner then
			return x, z
		end
	end
	return inner, inner
end

return Build
