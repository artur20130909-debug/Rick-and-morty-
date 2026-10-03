-- Строит карту при запуске: лобби на летающем острове (с порталом на арену) и арену.
-- Если в Workspace уже есть папка "Map" (например, ты сохранил карту и что-то поменял руками) — ничего не строится заново.
local Lighting = game:GetService("Lighting")

local Map = {}
Map.LOBBY = Vector3.new(0, 140, 320)   -- центр лобби (верх травы)
Map.ARENA = Vector3.new(0, 0, 0)       -- центр арены (верх травы)
Map.VOID_Y = -70                       -- ниже этой высоты игрок «падает в пустоту»
Map.ArenaSpawns = {}

local rng = Random.new(1337)

local function make(class, props)
	local p = Instance.new(class)
	if p:IsA("BasePart") then
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
	end
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end
Map.make = make

local GRASS = Color3.fromRGB(96, 170, 70)
local GRASS2 = Color3.fromRGB(78, 150, 58)
local DIRT = Color3.fromRGB(120, 84, 52)
local ROCK = Color3.fromRGB(110, 105, 112)
local ROCK2 = Color3.fromRGB(88, 84, 92)

-- вертикальный цилиндр: center — центр, диаметр d, высота h
local function cyl(parent, center, d, h, color, material, name)
	return make("Part", {
		Name = name or "Cyl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, d, d),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = parent,
	})
end
local function ball(parent, center, d, color, material, name)
	return make("Part", { Name = name or "Ball", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), CFrame = CFrame.new(center),
		Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = parent })
end
local function block(parent, cf, size, color, material, name)
	return make("Part", { Name = name or "Block", Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = parent })
end

-- летающий остров: трава сверху, земля, каменные слои книзу, «сосульки» камней
local function island(parent, top, radius)
	cyl(parent, top - Vector3.new(0, 2, 0), radius * 2, 4, GRASS, Enum.Material.Grass, "Grass")
	cyl(parent, top - Vector3.new(0, 6, 0), radius * 2 - 2, 4, DIRT, Enum.Material.Ground, "Dirt")
	local y = top.Y - 8
	for i = 1, 6 do
		local r = radius * (1 - i * 0.14)
		if r < 4 then break end
		cyl(parent, Vector3.new(top.X, y - 5, top.Z), r * 2, 10, (i % 2 == 0) and ROCK or ROCK2, Enum.Material.Slate, "Rock")
		y = y - 10
	end
	for i = 1, math.floor(radius / 3) do
		local a = rng:NextNumber() * math.pi * 2
		local d = rng:NextNumber() * radius * 0.85
		local depth = 10 + (1 - d / radius) * 45 * rng:NextNumber()
		ball(parent, Vector3.new(top.X + math.cos(a) * d, top.Y - 8 - depth * 0.6, top.Z + math.sin(a) * d), 6 + rng:NextNumber() * 10, ROCK2, Enum.Material.Slate, "RockChunk")
	end
	-- кочки и кустики травы на краях
	for i = 1, math.floor(radius / 2) do
		local a = rng:NextNumber() * math.pi * 2
		local d = radius * (0.75 + rng:NextNumber() * 0.2)
		ball(parent, Vector3.new(top.X + math.cos(a) * d, top.Y - 0.6, top.Z + math.sin(a) * d), 3 + rng:NextNumber() * 3, GRASS2, Enum.Material.Grass, "Bush")
	end
end

local function tree(parent, base, s)
	s = s or 1
	cyl(parent, base + Vector3.new(0, 6 * s, 0), 2.2 * s, 12 * s, Color3.fromRGB(105, 70, 42), Enum.Material.Wood, "Trunk")
	local leaf = { Color3.fromRGB(62, 150, 62), Color3.fromRGB(80, 172, 70), Color3.fromRGB(52, 128, 56) }
	ball(parent, base + Vector3.new(0, 14 * s, 0), 11 * s, leaf[1], Enum.Material.Grass, "Leaves")
	ball(parent, base + Vector3.new(3.5 * s, 12.5 * s, 1 * s), 8 * s, leaf[2], Enum.Material.Grass, "Leaves")
	ball(parent, base + Vector3.new(-3 * s, 13 * s, -2 * s), 8 * s, leaf[3], Enum.Material.Grass, "Leaves")
	ball(parent, base + Vector3.new(0.5 * s, 17.5 * s, 0), 7 * s, leaf[2], Enum.Material.Grass, "Leaves")
end

local function rock(parent, base, s)
	local p = block(parent, CFrame.new(base + Vector3.new(0, 1.5 * s, 0)) * CFrame.Angles(rng:NextNumber() * 0.6, rng:NextNumber() * 6, rng:NextNumber() * 0.6),
		Vector3.new(4, 3, 3.5) * s, ROCK, Enum.Material.Slate, "Stone")
	return p
end

local function crystal(parent, base, h, color)
	local p = block(parent, CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber() * 0.4 - 0.2, rng:NextNumber() * 6, rng:NextNumber() * 0.4 - 0.2),
		Vector3.new(h * 0.28, h, h * 0.28), color, Enum.Material.Neon, "Crystal")
	make("PointLight", { Color = color, Range = 14, Brightness = 1.5, Parent = p })
	return p
end

local function lamp(parent, base, color)
	cyl(parent, base + Vector3.new(0, 4, 0), 0.8, 8, Color3.fromRGB(60, 60, 70), Enum.Material.Metal, "LampPost")
	local b = ball(parent, base + Vector3.new(0, 8.6, 0), 1.8, color, Enum.Material.Neon, "LampLight")
	make("PointLight", { Color = color, Range = 18, Brightness = 2, Parent = b })
end

local function sign(parent, pos, text, color, size)
	local anchor = make("Part", { Name = "SignAnchor", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CanQuery = false, CFrame = CFrame.new(pos), Parent = parent })
	local bb = make("BillboardGui", { Size = UDim2.new(0, size or 400, 0, (size or 400) / 4), AlwaysOnTop = false, LightInfluence = 0, MaxDistance = 250, Parent = anchor })
	make("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = text, TextColor3 = color, TextScaled = true,
		Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(20, 15, 35), Parent = bb })
	return anchor
end

local function buildLighting()
	Lighting.ClockTime = 15.2
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(70, 70, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 150)
	Lighting.GlobalShadows = true
	make("Atmosphere", { Density = 0.28, Offset = 0.15, Color = Color3.fromRGB(200, 210, 255), Decay = Color3.fromRGB(110, 120, 170), Glare = 0.4, Haze = 1.4, Parent = Lighting })
	make("BloomEffect", { Intensity = 0.6, Size = 26, Threshold = 1.6, Parent = Lighting })
	make("ColorCorrectionEffect", { Saturation = 0.15, Contrast = 0.06, Parent = Lighting })
	make("SunRaysEffect", { Intensity = 0.07, Spread = 0.6, Parent = Lighting })
end

local function buildLobby(root)
	local lobby = make("Model", { Name = "Lobby", Parent = root })
	local L = Map.LOBBY
	island(lobby, L, 52)
	-- площадь из плитки и дорожка к порталу
	cyl(lobby, L + Vector3.new(0, 0.15, 0), 40, 0.3, Color3.fromRGB(205, 205, 215), Enum.Material.Slate, "Plaza")
	cyl(lobby, L + Vector3.new(0, 0.2, 0), 30, 0.3, Color3.fromRGB(170, 170, 185), Enum.Material.Slate, "PlazaInner")
	block(lobby, CFrame.new(L + Vector3.new(0, 0.15, -32)), Vector3.new(10, 0.3, 26), Color3.fromRGB(190, 190, 200), Enum.Material.Slate, "Path")
	-- точка появления
	make("SpawnLocation", { Name = "LobbySpawn", Size = Vector3.new(12, 1, 12), CFrame = CFrame.new(L + Vector3.new(0, 0.6, 10)), Neutral = true, Duration = 0,
		AllowTeamChangeOnTouch = false, Color = Color3.fromRGB(120, 90, 255), Material = Enum.Material.Neon, Transparency = 0.35, Parent = lobby })
	-- кристалл удачи в центре
	cyl(lobby, L + Vector3.new(0, 1.5, 0), 9, 3, Color3.fromRGB(70, 65, 90), Enum.Material.Marble, "Pedestal")
	local cr = block(lobby, CFrame.new(L + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(45)) * CFrame.Angles(math.rad(45), 0, 0),
		Vector3.new(5, 5, 5), Color3.fromRGB(170, 110, 255), Enum.Material.Neon, "LuckCrystal")
	make("PointLight", { Color = Color3.fromRGB(170, 110, 255), Range = 30, Brightness = 3, Parent = cr })
	sign(lobby, L + Vector3.new(0, 17, 0), "СТИХИЙНЫЕ БИТВЫ RNG", Color3.fromRGB(255, 220, 90), 520)
	-- портал на арену (кольцо + светящийся диск, который телепортирует)
	local pc = L + Vector3.new(0, 0, -44)
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local p = block(lobby, CFrame.new(pc + Vector3.new(math.cos(a) * 9.5, 10 + math.sin(a) * 9.5, 0)) * CFrame.Angles(0, 0, a),
			Vector3.new(2.6, 2.6, 2.6), (i % 2 == 0) and Color3.fromRGB(150, 70, 255) or Color3.fromRGB(90, 40, 200), Enum.Material.Neon, "PortalRing")
		p.CanCollide = false
	end
	local disc = make("Part", { Name = "PortalTrigger", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 18, 18),
		CFrame = CFrame.new(pc + Vector3.new(0, 10, 0)) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(170, 100, 255),
		Material = Enum.Material.Neon, Transparency = 0.45, CanCollide = false, Parent = lobby })
	make("PointLight", { Color = Color3.fromRGB(170, 100, 255), Range = 40, Brightness = 4, Parent = disc })
	make("ParticleEmitter", { Color = ColorSequence.new(Color3.fromRGB(200, 150, 255)), LightEmission = 1, Rate = 40, Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.8, 0), Parent = disc })
	sign(lobby, pc + Vector3.new(0, 23, 0), "НА АРЕНУ!", Color3.fromRGB(200, 160, 255), 300)
	cyl(lobby, pc + Vector3.new(0, 0.25, 0), 16, 0.5, Color3.fromRGB(120, 70, 220), Enum.Material.Neon, "PortalPad")
	-- деревья, фонари, кристаллы
	for _, v in ipairs({ { -30, 18 }, { 32, 22 }, { -36, -14 }, { 38, -16 }, { 12, 40 }, { -16, 42 } }) do tree(lobby, L + Vector3.new(v[1], 0, v[2]), 0.9 + rng:NextNumber() * 0.3) end
	for i = 0, 7 do local a = i / 8 * math.pi * 2 + 0.2; lamp(lobby, L + Vector3.new(math.cos(a) * 22, 0, math.sin(a) * 22), Color3.fromRGB(255, 220, 140)) end
	for _, v in ipairs({ { -44, 6 }, { 44, 4 }, { -10, -46 }, { 22, 44 } }) do crystal(lobby, L + Vector3.new(v[1], 0, v[2]), 6 + rng:NextNumber() * 4, Color3.fromRGB(120, 200, 255)) end
	return lobby
end

local function buildArena(root)
	local arena = make("Model", { Name = "Arena", Parent = root })
	local A = Map.ARENA
	island(arena, A, 92)
	-- центральное плато и ступени к летающим площадкам
	cyl(arena, A + Vector3.new(0, 2, 0), 44, 4, GRASS2, Enum.Material.Grass, "Plateau")
	cyl(arena, A + Vector3.new(0, 4.1, 0), 18, 0.2, Color3.fromRGB(200, 190, 160), Enum.Material.Sandstone, "PlateauCircle")
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		cyl(arena, A + dir * 30 + Vector3.new(0, 4, 0), 7, 2, Color3.fromRGB(150, 145, 160), Enum.Material.Slate, "Step")
		cyl(arena, A + dir * 38 + Vector3.new(0, 8, 0), 7, 2, Color3.fromRGB(150, 145, 160), Enum.Material.Slate, "Step")
		local pl = cyl(arena, A + dir * 50 + Vector3.new(0, 12, 0), 18, 2.5, Color3.fromRGB(185, 180, 195), Enum.Material.Concrete, "FloatPlatform")
		cyl(arena, pl.Position - Vector3.new(0, 1.6, 0), 19, 0.6, Color3.fromRGB(255, 160, 60), Enum.Material.Neon, "PlatformGlow")
	end
	-- украшения
	for i = 1, 9 do
		local a = rng:NextNumber() * math.pi * 2
		local d = 30 + rng:NextNumber() * 50
		tree(arena, A + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), 0.8 + rng:NextNumber() * 0.4)
	end
	for i = 1, 14 do
		local a = rng:NextNumber() * math.pi * 2
		local d = 26 + rng:NextNumber() * 60
		rock(arena, A + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), 0.8 + rng:NextNumber() * 1.2)
	end
	for i = 1, 6 do
		local a = rng:NextNumber() * math.pi * 2
		local d = 60 + rng:NextNumber() * 25
		crystal(arena, A + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), 5 + rng:NextNumber() * 5, (i % 2 == 0) and Color3.fromRGB(255, 120, 200) or Color3.fromRGB(120, 220, 255))
	end
	-- точки появления на арене (по кругу)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		table.insert(Map.ArenaSpawns, A + Vector3.new(math.cos(a) * 62, 0, math.sin(a) * 62))
	end
	return arena
end

-- манекены для тренировки (можно сбивать, когда ты один на сервере)
function Map.makeDummy(parent, pos, n)
	local m = Instance.new("Model")
	m.Name = "Манекен" .. n
	local base = make("Part", { Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 5, 5), CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(90, 70, 50), Material = Enum.Material.Wood, Anchored = false, Parent = m })
	local body = make("Part", { Name = "Body", Size = Vector3.new(2.6, 3.2, 1.6), CFrame = CFrame.new(pos + Vector3.new(0, 3.6, 0)), Color = Color3.fromRGB(220, 190, 130),
		Material = Enum.Material.Fabric, Anchored = false, Parent = m })
	local head = make("Part", { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = CFrame.new(pos + Vector3.new(0, 6.3, 0)), Color = Color3.fromRGB(235, 205, 150),
		Material = Enum.Material.Fabric, Anchored = false, Parent = m })
	local pole = make("Part", { Name = "Pole", Size = Vector3.new(0.5, 2, 0.5), CFrame = CFrame.new(pos + Vector3.new(0, 1.6, 0)), Color = Color3.fromRGB(90, 70, 50), Material = Enum.Material.Wood, Anchored = false, Parent = m })
	local face = make("Decal", { Texture = "rbxasset://textures/face.png", Face = Enum.NormalId.Front, Parent = head })
	for _, p in ipairs({ body, head, pole }) do make("WeldConstraint", { Part0 = base, Part1 = p, Parent = base }) end
	m.PrimaryPart = body
	m:SetAttribute("Home", pos)
	m.Parent = parent
	for _, p in ipairs({ base, body, head, pole }) do pcall(function() p:SetNetworkOwner(nil) end) end
	return m
end

function Map.build()
	buildLighting()
	local existing = workspace:FindFirstChild("Map")
	if existing then
		-- карта уже сохранена в месте: только восстанавливаем точки появления арены
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			table.insert(Map.ArenaSpawns, Map.ARENA + Vector3.new(math.cos(a) * 62, 0, math.sin(a) * 62))
		end
		return existing
	end
	local root = Instance.new("Folder")
	root.Name = "Map"
	root.Parent = workspace
	buildLobby(root)
	buildArena(root)
	return root
end

return Map
