-- Строит карту при запуске: спавн, магазин Duo, башня, пляж, парк, зарядные станции.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("PhoneConfig"))

local Map = {}

local function make(className, props)
	local inst = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
Map.make = make

local function block(parent, name, size, cf, color, material, extra)
	local p = make("Part", {
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Anchored = true,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Parent = parent,
	})
	if extra then
		for k, v in pairs(extra) do
			p[k] = v
		end
	end
	return p
end
Map.block = block

local function sign(part, face, text, textColor, bgColor)
	local gui = make("SurfaceGui", {
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0,
		Parent = part,
	})
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = bgColor or Color3.new(1, 1, 1),
		BackgroundTransparency = bgColor and 0 or 1,
		Text = text,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = textColor or Color3.new(0, 0, 0),
		Parent = gui,
	})
	return gui
end
Map.sign = sign

local function tree(parent, pos, scale)
	scale = scale or 1
	local trunkH = 8 * scale
	block(parent, "Trunk", Vector3.new(1.6 * scale, trunkH, 1.6 * scale), CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)),
		Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	local leaves = block(parent, "Leaves", Vector3.new(9, 9, 9) * scale, CFrame.new(pos + Vector3.new(0, trunkH + 3 * scale, 0)),
		Color3.fromRGB(70, 160, 70), Enum.Material.Grass)
	leaves.Shape = Enum.PartType.Ball
end

-- Большая статуя телефона у магазина
local function phoneStatue(parent, cf)
	local model = make("Model", { Name = "DuoStatue", Parent = parent })
	local w, h, t = 8, 16, 1
	local body = Color3.fromRGB(190, 184, 172)
	block(model, "LeftBody", Vector3.new(w, h, t), cf * CFrame.new(-w / 2 - 0.25, 0, 0), body, Enum.Material.Metal)
	block(model, "RightBody", Vector3.new(w, h, t), cf * CFrame.new(w / 2 + 0.25, 0, 0), body, Enum.Material.Metal)
	local hinge = block(model, "Hinge", Vector3.new(h, 0.8, 0.8), cf * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(120, 120, 125), Enum.Material.Metal)
	hinge.Shape = Enum.PartType.Cylinder
	for i, side in ipairs({ -1, 1 }) do
		local scr = block(model, "Screen" .. i, Vector3.new(w - 0.6, h - 0.8, 0.1),
			cf * CFrame.new(side * (w / 2 + 0.25), 0, t / 2 + 0.05), Color3.fromRGB(20, 20, 30), Enum.Material.Neon)
		local gui = make("SurfaceGui", { Face = Enum.NormalId.Back, LightInfluence = 0,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 30, Parent = scr })
		local bg = make("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Parent = gui })
		make("UIGradient", { Rotation = 90, Color = ColorSequence.new(
			i == 1 and Color3.fromRGB(255, 120, 90) or Color3.fromRGB(40, 180, 230),
			i == 1 and Color3.fromRGB(120, 60, 200) or Color3.fromRGB(20, 40, 120)), Parent = bg })
		make("TextLabel", { Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.12), BackgroundTransparency = 1,
			Text = i == 1 and "iPhone" or "Duo", TextScaled = true, Font = Enum.Font.GothamBlack,
			TextColor3 = Color3.new(1, 1, 1), Parent = bg })
		make("TextLabel", { Size = UDim2.fromScale(1, 0.1), Position = UDim2.fromScale(0, 0.5), BackgroundTransparency = 1,
			Text = i == 1 and "Два экрана." or "Один телефон.", TextScaled = true, Font = Enum.Font.Gotham,
			TextColor3 = Color3.new(1, 1, 1), Parent = bg })
	end
	-- Камеры сзади
	local bump = block(model, "CameraBump", Vector3.new(3, 3, 0.4), cf * CFrame.new(-w / 2 - 0.25 - 1.5, h / 2 - 2.5, -t / 2 - 0.2),
		Color3.fromRGB(60, 60, 65), Enum.Material.Glass)
	for _, dy in ipairs({ 0.7, -0.7 }) do
		local lens = block(model, "Lens", Vector3.new(0.3, 1.1, 1.1),
			bump.CFrame * CFrame.new(0, dy, -0.3) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(15, 15, 25), Enum.Material.Glass)
		lens.Shape = Enum.PartType.Cylinder
	end
	return model
end

local function charger(parent, pos)
	local pad = block(parent, "Charger", Vector3.new(8, 0.4, 8), CFrame.new(pos), Color3.fromRGB(60, 230, 120), Enum.Material.Neon)
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.4, 9, 9)
	pad.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	local post = block(parent, "ChargerSign", Vector3.new(4, 2, 0.3), CFrame.new(pos + Vector3.new(0, 5, -4.4)),
		Color3.fromRGB(30, 30, 35), Enum.Material.SmoothPlastic)
	sign(post, Enum.NormalId.Back, "⚡ ЗАРЯДКА", Color3.fromRGB(90, 255, 140), Color3.fromRGB(30, 30, 35))
	sign(post, Enum.NormalId.Front, "⚡ ЗАРЯДКА", Color3.fromRGB(90, 255, 140), Color3.fromRGB(30, 30, 35))
	block(parent, "ChargerPole", Vector3.new(0.4, 4, 0.4), CFrame.new(pos + Vector3.new(0, 2, -4.4)), Color3.fromRGB(80, 80, 85), Enum.Material.Metal)
	make("PointLight", { Color = Color3.fromRGB(90, 255, 140), Range = 12, Brightness = 2, Parent = pad })
end

local function store(parent)
	local m = make("Model", { Name = "DuoStore", Parent = parent })
	local c = CFrame.new(0, 0, -80)
	local white = Color3.fromRGB(245, 245, 245)
	block(m, "Floor", Vector3.new(50, 1, 34), c * CFrame.new(0, 0.5, 0), Color3.fromRGB(225, 220, 210), Enum.Material.Marble)
	block(m, "Roof", Vector3.new(52, 1, 36), c * CFrame.new(0, 14.5, 0), white)
	block(m, "BackWall", Vector3.new(50, 14, 1), c * CFrame.new(0, 7.5, -16.5), white)
	block(m, "LeftWall", Vector3.new(1, 14, 34), c * CFrame.new(-24.5, 7.5, 0), white)
	block(m, "RightWall", Vector3.new(1, 14, 34), c * CFrame.new(24.5, 7.5, 0), white)
	-- Стеклянный фасад со входом посередине
	for _, x in ipairs({ -15.5, 15.5 }) do
		block(m, "Glass", Vector3.new(18, 13, 0.4), c * CFrame.new(x, 7.5, 16.8), Color3.fromRGB(180, 220, 255), Enum.Material.Glass,
			{ Transparency = 0.6 })
	end
	block(m, "GlassTop", Vector3.new(13, 4, 0.4), c * CFrame.new(0, 12, 16.8), Color3.fromRGB(180, 220, 255), Enum.Material.Glass,
		{ Transparency = 0.6 })
	local logo = block(m, "Logo", Vector3.new(20, 3, 0.4), c * CFrame.new(0, 17, 17), Color3.fromRGB(30, 30, 35))
	sign(logo, Enum.NormalId.Back, "  DUO STORE", Color3.new(1, 1, 1), Color3.fromRGB(30, 30, 35))
	block(m, "LogoPole", Vector3.new(1, 2.5, 0.4), c * CFrame.new(0, 15.3, 17), Color3.fromRGB(30, 30, 35))
	-- Столы с витринными телефонами
	local colors = Config.Colors
	local idx = 1
	for row = -1, 1, 2 do
		for col = -1, 1 do
			local tcf = c * CFrame.new(col * 13, 0, row * 6)
			block(m, "Table", Vector3.new(9, 0.4, 4), tcf * CFrame.new(0, 3.2, 0), Color3.fromRGB(205, 170, 120), Enum.Material.Wood)
			for _, lx in ipairs({ -4, 4 }) do
				block(m, "Leg", Vector3.new(0.4, 2.2, 3.4), tcf * CFrame.new(lx, 1.9, 0), Color3.fromRGB(230, 230, 230))
			end
			for k = -1, 1 do
				local col3 = colors[((idx - 1) % #colors) + 1].Color
				idx = idx + 1
				local base = tcf * CFrame.new(k * 2.6, 3.5, 0) * CFrame.Angles(math.rad(-80), 0, 0)
				block(m, "DemoL", Vector3.new(0.8, 1.6, 0.1), base * CFrame.new(-0.42, 0, 0), col3, Enum.Material.Metal)
				block(m, "DemoR", Vector3.new(0.8, 1.6, 0.1), base * CFrame.new(0.42, 0, 0), col3, Enum.Material.Metal)
				block(m, "DemoScreen", Vector3.new(1.55, 1.5, 0.02), base * CFrame.new(0, 0, 0.06), Color3.fromRGB(80, 140, 255), Enum.Material.Neon)
			end
		end
	end
	make("PointLight", { Range = 40, Brightness = 1.2, Parent = m:FindFirstChild("Roof") })
	return m
end

local function tower(parent)
	local m = make("Model", { Name = "Tower", Parent = parent })
	local base = Vector3.new(80, 0, 40)
	local h = 60
	block(m, "Core", Vector3.new(10, h, 10), CFrame.new(base + Vector3.new(0, h / 2, 0)), Color3.fromRGB(200, 200, 210), Enum.Material.Concrete)
	-- Круглая площадка наверху; с северной стороны (откуда приходит лестница) перил нет
	local top = block(m, "Top", Vector3.new(1, 26, 26), CFrame.new(base + Vector3.new(0, h + 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(90, 90, 100), Enum.Material.DiamondPlate)
	top.Shape = Enum.PartType.Cylinder
	for _, d in ipairs({ { 0, 12 }, { 12, 0 }, { -12, 0 } }) do
		local sx = d[1] == 0 and 16 or 0.5
		local sz = d[1] == 0 and 0.5 or 16
		block(m, "Rail", Vector3.new(sx, 3, sz), CFrame.new(base + Vector3.new(d[1], h + 2.5, d[2])), Color3.fromRGB(180, 220, 255),
			Enum.Material.Glass, { Transparency = 0.5 })
	end
	-- Спиральная лестница
	local steps = 60
	for i = 0, steps - 1 do
		local a = i / steps * math.pi * 6
		local y = (i + 1) * (h / steps)
		block(m, "Step", Vector3.new(4, 1, 6), CFrame.new(base + Vector3.new(0, y, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -16),
			Color3.fromRGB(150, 150, 160), Enum.Material.Metal)
	end
	local beacon = block(m, "Beacon", Vector3.new(2, 2, 2), CFrame.new(base + Vector3.new(0, h + 8, 0)), Color3.fromRGB(255, 80, 80), Enum.Material.Neon)
	beacon.Shape = Enum.PartType.Ball
	block(m, "Antenna", Vector3.new(0.4, 6, 0.4), CFrame.new(base + Vector3.new(0, h + 4, 0)), Color3.fromRGB(120, 120, 125), Enum.Material.Metal)
	make("PointLight", { Color = Color3.fromRGB(255, 80, 80), Range = 30, Brightness = 3, Parent = beacon })
	local s = block(m, "TowerSign", Vector3.new(10, 3, 0.4), CFrame.new(base + Vector3.new(0, 8, -5.2)), Color3.fromRGB(30, 30, 35))
	sign(s, Enum.NormalId.Front, "📶 ВЫШКА 5G", Color3.fromRGB(255, 220, 90), Color3.fromRGB(30, 30, 35))
end

local function beach(parent)
	local m = make("Model", { Name = "Beach", Parent = parent })
	block(m, "Sand", Vector3.new(70, 1, 60), CFrame.new(-100, 0.2, 70), Color3.fromRGB(235, 215, 160), Enum.Material.Sand)
	block(m, "Water", Vector3.new(60, 1, 60), CFrame.new(-150, 0.1, 70), Color3.fromRGB(60, 150, 220), Enum.Material.Glass,
		{ Transparency = 0.35, CanCollide = false })
	for i, x in ipairs({ -95, -110, -85 }) do
		local z = 55 + i * 9
		block(m, "Towel", Vector3.new(3, 0.1, 6), CFrame.new(x, 0.75, z), i % 2 == 0 and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(80, 170, 255),
			Enum.Material.Fabric)
		block(m, "UmbrellaPole", Vector3.new(0.3, 7, 0.3), CFrame.new(x + 2.5, 4, z), Color3.fromRGB(240, 240, 240))
		local top = block(m, "Umbrella", Vector3.new(1, 8, 8), CFrame.new(x + 2.5, 7.6, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(255, 200, 60), Enum.Material.Fabric)
		top.Shape = Enum.PartType.Cylinder
	end
	for _, p in ipairs({ Vector3.new(-120, 0.7, 45), Vector3.new(-78, 0.7, 95) }) do
		tree(m, p, 0.9)
	end
end

local function park(parent)
	local m = make("Model", { Name = "Park", Parent = parent })
	local rng = Random.new(7)
	for _ = 1, 14 do
		tree(m, Vector3.new(rng:NextNumber(40, 110), 0.5, rng:NextNumber(-80, -10)), rng:NextNumber(0.8, 1.3))
	end
	for i = 0, 2 do
		local cf = CFrame.new(60 + i * 10, 0, -35)
		block(m, "BenchSeat", Vector3.new(6, 0.4, 2), cf * CFrame.new(0, 1.8, 0), Color3.fromRGB(150, 100, 60), Enum.Material.Wood)
		block(m, "BenchBack", Vector3.new(6, 2, 0.3), cf * CFrame.new(0, 3, 0.9), Color3.fromRGB(150, 100, 60), Enum.Material.Wood)
		block(m, "BenchLegs", Vector3.new(5.6, 1.6, 1.6), cf * CFrame.new(0, 0.8, 0), Color3.fromRGB(60, 60, 60), Enum.Material.Metal,
			{ Transparency = 0 })
	end
end

local function roads(parent)
	local gray = Color3.fromRGB(70, 70, 75)
	block(parent, "Road1", Vector3.new(12, 0.2, 180), CFrame.new(0, 0.6, -10), gray, Enum.Material.Asphalt)
	block(parent, "Road2", Vector3.new(200, 0.2, 12), CFrame.new(-10, 0.6, 30), gray, Enum.Material.Asphalt)
	block(parent, "SpawnPlaza", Vector3.new(36, 0.3, 36), CFrame.new(0, 0.65, 0), Color3.fromRGB(215, 215, 220), Enum.Material.Slate)
end

function Map.build()
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = 12
	Lighting.Brightness = 2
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 140)
	Lighting.Ambient = Color3.fromRGB(60, 60, 70)

	local world = make("Folder", { Name = "DuoWorld", Parent = workspace })
	block(world, "Ground", Vector3.new(600, 1, 600), CFrame.new(0, 0, 0), Color3.fromRGB(100, 180, 90), Enum.Material.Grass)
	roads(world)

	local spawn = make("SpawnLocation", {
		Name = "Spawn",
		Size = Vector3.new(10, 1, 10),
		CFrame = CFrame.new(0, 1, 0),
		Anchored = true,
		Color = Color3.fromRGB(80, 140, 255),
		Material = Enum.Material.Neon,
		Duration = 0,
		Parent = world,
	})
	local welcome = block(world, "Welcome", Vector3.new(18, 5, 0.5), CFrame.new(0, 7, -14), Color3.fromRGB(30, 30, 35))
	sign(welcome, Enum.NormalId.Back, "📱 МОЙ iPHONE DUO\nОн уже у тебя в инвентаре!", Color3.new(1, 1, 1), Color3.fromRGB(30, 30, 35))
	block(world, "WelcomePole", Vector3.new(0.6, 5, 0.6), CFrame.new(0, 2.5, -14), Color3.fromRGB(80, 80, 85), Enum.Material.Metal)

	store(world)
	phoneStatue(world, CFrame.new(-34, 8.6, -50) * CFrame.Angles(0, math.rad(25), 0))
	tower(world)
	beach(world)
	park(world)
	for _, pos in ipairs(Config.Chargers) do
		charger(world, pos)
	end
	return spawn
end

return Map
