-- Строит карту при запуске: лобби на летающем острове (алтарь удачи, портал на арену) и арену-остров.
-- Если в Workspace уже есть папка "Map" (ты сохранил карту и поменял её руками) — заново ничего не строится.
-- Вращение колец, кристаллов и покачивание летающих камней делает клиент (атрибуты Spin / Bob) — плавно и без нагрузки на сеть.
local Lighting = game:GetService("Lighting")

local Map = {}
Map.LOBBY = Vector3.new(0, 140, 330)   -- центр лобби (верх травы)
Map.ARENA = Vector3.new(0, 0, 0)       -- центр арены (верх травы)
Map.VOID_Y = -70                       -- ниже этой высоты — пустота
Map.ArenaSpawns = {}

local rng = Random.new(1337)
local function rnd(a, b) return a + rng:NextNumber() * (b - a) end

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

local C = {
	grass = Color3.fromRGB(98, 172, 72), grass2 = Color3.fromRGB(80, 152, 60), grass3 = Color3.fromRGB(120, 190, 84),
	dirt = Color3.fromRGB(122, 86, 54), rock = Color3.fromRGB(112, 106, 116), rock2 = Color3.fromRGB(88, 84, 94), rock3 = Color3.fromRGB(140, 134, 142),
	stone = Color3.fromRGB(196, 192, 204), stone2 = Color3.fromRGB(160, 156, 172), stone3 = Color3.fromRGB(126, 122, 140),
	marble = Color3.fromRGB(236, 232, 240), wood = Color3.fromRGB(110, 72, 44), gold = Color3.fromRGB(255, 200, 70),
	purple = Color3.fromRGB(160, 90, 255), purple2 = Color3.fromRGB(100, 50, 210), cyan = Color3.fromRGB(110, 220, 255), water = Color3.fromRGB(90, 180, 255),
}

-- вертикальный цилиндр с центром center, диаметром d, высотой h
local function cyl(parent, center, d, h, color, material, name)
	return make("Part", { Name = name or "Cyl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, d, d),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = parent })
end
local function ball(parent, center, d, color, material, name)
	return make("Part", { Name = name or "Ball", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), CFrame = CFrame.new(center),
		Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = parent })
end
local function block(parent, cf, size, color, material, name)
	return make("Part", { Name = name or "Block", Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = parent })
end
local function deco(p) p.CanCollide = false; p.CanQuery = false; p.CastShadow = false; return p end
local function light(parent, color, range, br) return make("PointLight", { Color = color, Range = range or 16, Brightness = br or 2, Parent = parent }) end

-- кольцо из сегментов (вертикальное, в плоскости, смотрящей вдоль look) — модель с PrimaryPart в центре
local function ring(parent, center, look, radius, n, seg, color, name)
	local m = make("Model", { Name = name or "Ring", Parent = parent })
	local cf = CFrame.lookAt(center, center + look)
	local core = block(m, cf, Vector3.new(0.2, 0.2, 0.2), color, Enum.Material.Neon, "Core")
	core.Transparency = 1
	deco(core)
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local p = block(m, cf * CFrame.Angles(0, 0, a) * CFrame.new(radius, 0, 0), Vector3.new(seg, seg * 2.2, seg), color, Enum.Material.Neon, "Seg")
		deco(p)
	end
	m.PrimaryPart = core
	return m
end

-- летающий остров: трава, земляной край, каменные слои книзу, торчащие камни снизу
local function island(parent, top, radius, seed)
	local r2 = Random.new(seed or 7)
	cyl(parent, top - Vector3.new(0, 2, 0), radius * 2, 4, C.grass, Enum.Material.Grass, "Grass")
	cyl(parent, top - Vector3.new(0, 5.5, 0), radius * 2 + 1.2, 3, C.dirt, Enum.Material.Ground, "Dirt")
	local y = top.Y - 7
	for i = 1, 7 do
		local r = radius * (1 - i * 0.125)
		if r < 4 then break end
		cyl(parent, Vector3.new(top.X + r2:NextNumber() * 4 - 2, y - 5, top.Z + r2:NextNumber() * 4 - 2), r * 2, 10, (i % 2 == 0) and C.rock or C.rock2, Enum.Material.Slate, "Rock")
		y = y - 10
	end
	for i = 1, math.floor(radius / 2.5) do
		local a = r2:NextNumber() * math.pi * 2
		local d = r2:NextNumber() * radius * 0.9
		local depth = 8 + (1 - d / radius) * 60 * r2:NextNumber()
		local s = 5 + r2:NextNumber() * 9
		block(parent, CFrame.new(top.X + math.cos(a) * d, top.Y - 8 - depth * 0.7, top.Z + math.sin(a) * d) * CFrame.Angles(r2:NextNumber() * 3, r2:NextNumber() * 3, r2:NextNumber() * 3),
			Vector3.new(s, s * 1.6, s), (i % 3 == 0) and C.rock3 or C.rock2, Enum.Material.Slate, "Stalactite")
	end
	-- кромка: кочки травы и камешки
	for i = 1, math.floor(radius * 0.8) do
		local a = r2:NextNumber() * math.pi * 2
		local d = radius * (0.9 + r2:NextNumber() * 0.12)
		if i % 4 == 0 then
			block(parent, CFrame.new(top.X + math.cos(a) * d, top.Y - 0.5, top.Z + math.sin(a) * d) * CFrame.Angles(0, a, r2:NextNumber() * 0.4), Vector3.new(3, 2, 2.5), C.rock3, Enum.Material.Slate, "EdgeStone")
		else
			ball(parent, Vector3.new(top.X + math.cos(a) * d, top.Y - 0.8, top.Z + math.sin(a) * d), 2.6 + r2:NextNumber() * 2.6, (i % 2 == 0) and C.grass2 or C.grass3, Enum.Material.Grass, "Tuft")
		end
	end
end

local function tree(parent, base, s, kind)
	s = s or 1
	cyl(parent, base + Vector3.new(0, 5 * s, 0), 2.4 * s, 10 * s, C.wood, Enum.Material.Wood, "Trunk")
	cyl(parent, base + Vector3.new(0, 0.6 * s, 0), 3.6 * s, 1.2 * s, C.wood, Enum.Material.Wood, "Roots")
	local br = block(parent, CFrame.new(base + Vector3.new(1.6 * s, 8.5 * s, 0)) * CFrame.Angles(0, 0, math.rad(-40)), Vector3.new(1, 4.5, 1) * s, C.wood, Enum.Material.Wood, "Branch")
	br.CanCollide = false
	local cols = (kind == "pink") and { Color3.fromRGB(255, 160, 200), Color3.fromRGB(255, 190, 220), Color3.fromRGB(235, 130, 180) }
		or { Color3.fromRGB(62, 150, 62), Color3.fromRGB(84, 176, 72), Color3.fromRGB(52, 128, 56) }
	local blobs = { { 0, 13, 0, 11 }, { 3.6, 11.5, 1.2, 8 }, { -3.2, 12, -1.8, 8.5 }, { 0.6, 16.5, 0.4, 7.5 }, { -1.5, 10.5, 3, 6.5 }, { 2, 14.5, -3, 6.5 } }
	for i, b in ipairs(blobs) do
		local p = ball(parent, base + Vector3.new(b[1], b[2], b[3]) * s, b[4] * s, cols[(i % 3) + 1], Enum.Material.Grass, "Leaves")
		p.CanCollide = false
	end
	if kind == "pink" then
		local p = make("Part", { Name = "Petals", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CFrame = CFrame.new(base + Vector3.new(0, 12 * s, 0)), Parent = parent })
		make("ParticleEmitter", { Color = ColorSequence.new(Color3.fromRGB(255, 190, 220)), Rate = 4, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(0.5, 1.5),
			Acceleration = Vector3.new(0, -1.5, 0), Size = NumberSequence.new(0.35), SpreadAngle = Vector2.new(180, 180), RotSpeed = NumberRange.new(-90, 90), Parent = p })
	end
end

local function bush(parent, base, s)
	for i = 1, 3 do
		local p = ball(parent, base + Vector3.new(rnd(-1.4, 1.4), 1.2 + rnd(0, 0.8), rnd(-1.4, 1.4)) * s, rnd(2.6, 3.6) * s, (i % 2 == 0) and C.grass2 or C.grass3, Enum.Material.Grass, "Bush")
		p.CanCollide = false
	end
end

local FLOWER = { Color3.fromRGB(255, 110, 140), Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 120, 255), Color3.fromRGB(110, 190, 255) }
local function flowers(parent, center, radius, n)
	for i = 1, n do
		local a, d = rnd(0, math.pi * 2), math.sqrt(rng:NextNumber()) * radius
		local pos = center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		deco(cyl(parent, pos + Vector3.new(0, 0.4, 0), 0.15, 0.8, C.grass2, Enum.Material.Grass, "Stem"))
		deco(ball(parent, pos + Vector3.new(0, 0.95, 0), 0.65, FLOWER[(i % #FLOWER) + 1], Enum.Material.SmoothPlastic, "Flower"))
	end
end

local function rock(parent, base, s)
	block(parent, CFrame.new(base + Vector3.new(0, 1.2 * s, 0)) * CFrame.Angles(rnd(-0.3, 0.3), rnd(0, 6), rnd(-0.3, 0.3)), Vector3.new(4, 3, 3.4) * s, C.rock, Enum.Material.Slate, "Stone")
	block(parent, CFrame.new(base + Vector3.new(1.6 * s, 0.7 * s, 1 * s)) * CFrame.Angles(rnd(-0.3, 0.3), rnd(0, 6), 0), Vector3.new(2.2, 1.6, 2) * s, C.rock3, Enum.Material.Slate, "Stone")
end

local function crystal(parent, base, h, color)
	for i = 1, 3 do
		local hh = h * (i == 1 and 1 or rnd(0.45, 0.7))
		local off = (i == 1) and Vector3.new() or Vector3.new(rnd(-1.4, 1.4), 0, rnd(-1.4, 1.4)) * h * 0.25
		local p = block(parent, CFrame.new(base + off + Vector3.new(0, hh / 2 - 0.3, 0)) * CFrame.Angles(rnd(-0.35, 0.35), rnd(0, 6), rnd(-0.35, 0.35)),
			Vector3.new(hh * 0.3, hh, hh * 0.3), color, Enum.Material.Neon, "Crystal")
		if i == 1 then light(p, color, 16, 1.5) end
	end
end

local function lamp(parent, base, color)
	cyl(parent, base + Vector3.new(0, 0.4, 0), 1.8, 0.8, C.stone3, Enum.Material.Slate, "LampBase")
	cyl(parent, base + Vector3.new(0, 4.5, 0), 0.7, 8, Color3.fromRGB(55, 55, 66), Enum.Material.Metal, "LampPost")
	block(parent, CFrame.new(base + Vector3.new(0, 8.8, 0)), Vector3.new(2.2, 0.4, 2.2), Color3.fromRGB(55, 55, 66), Enum.Material.Metal, "LampCap")
	local b = deco(block(parent, CFrame.new(base + Vector3.new(0, 7.7, 0)), Vector3.new(1.5, 1.8, 1.5), color, Enum.Material.Neon, "LampLight"))
	light(b, color, 20, 1.8)
end

local function pillar(parent, base, h, broken)
	cyl(parent, base + Vector3.new(0, 0.6, 0), 4.4, 1.2, C.stone2, Enum.Material.Marble, "PillarBase")
	local hh = broken and h * rnd(0.35, 0.65) or h
	cyl(parent, base + Vector3.new(0, 1.2 + hh / 2, 0), 3, hh, C.marble, Enum.Material.Marble, "PillarShaft")
	if broken then
		block(parent, CFrame.new(base + Vector3.new(0, 1.2 + hh, 0)) * CFrame.Angles(rnd(-0.5, 0.5), rnd(0, 6), rnd(-0.5, 0.5)), Vector3.new(3, 1.4, 3), C.marble, Enum.Material.Marble, "PillarBreak")
	else
		cyl(parent, base + Vector3.new(0, 1.8 + hh, 0), 4.2, 1.2, C.stone2, Enum.Material.Marble, "PillarTop")
	end
end

local function waterfall(parent, edge, outward, h)
	local cf = CFrame.lookAt(edge, edge + outward)
	-- ручеёк к краю и падающая вода
	deco(block(parent, cf * CFrame.new(0, -0.3, 5), Vector3.new(4.5, 0.4, 10), C.water, Enum.Material.Glass, "Stream")).Transparency = 0.25
	local fall = deco(block(parent, cf * CFrame.new(0, -h / 2, -1.2), Vector3.new(4.5, h, 1.2), C.water, Enum.Material.Glass, "Waterfall"))
	fall.Transparency = 0.3
	local mist = deco(block(parent, cf * CFrame.new(0, -h, -1.2), Vector3.new(6, 1, 3), C.water, Enum.Material.SmoothPlastic, "Mist"))
	mist.Transparency = 1
	make("ParticleEmitter", { Color = ColorSequence.new(Color3.fromRGB(230, 245, 255)), LightEmission = 0.3, Rate = 25, Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(90, 90), Size = NumberSequence.new(2, 5), Transparency = NumberSequence.new(0.5, 1), Parent = mist })
	make("ParticleEmitter", { Color = ColorSequence.new(Color3.fromRGB(220, 240, 255)), Rate = 30, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(14, 18),
		EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(6, 6), Size = NumberSequence.new(0.6, 0.2), Transparency = NumberSequence.new(0.3, 1), Parent = fall })
end

-- маленький летающий островок с кристаллом (покачивается — атрибут Bob)
local function floatRock(parent, center, s, color)
	local m = make("Model", { Name = "FloatRock", Parent = parent })
	local top = cyl(m, center, 7 * s, 1.6 * s, C.grass, Enum.Material.Grass, "Top")
	cyl(m, center - Vector3.new(0, 1.8 * s, 0), 6 * s, 2 * s, C.dirt, Enum.Material.Ground, "Soil")
	cyl(m, center - Vector3.new(0, 4 * s, 0), 4.4 * s, 2.6 * s, C.rock2, Enum.Material.Slate, "Under")
	cyl(m, center - Vector3.new(0, 6.4 * s, 0), 2.4 * s, 2.4 * s, C.rock, Enum.Material.Slate, "Tip")
	if color then crystal(m, center + Vector3.new(0, 0.8 * s, 0), 4 * s, color) else bush(m, center + Vector3.new(0, 0.8 * s, 0), s * 0.8) end
	for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
	m.PrimaryPart = top
	m:SetAttribute("Bob", 1.5 + rng:NextNumber() * 1.5)
	return m
end

-- облака-«море» под островами
local function cloudSea(parent, center, radius, n, y)
	for i = 1, n do
		local a, d = rnd(0, math.pi * 2), rnd(radius * 0.3, radius)
		local p = deco(ball(parent, Vector3.new(center.X + math.cos(a) * d, y + rnd(-6, 6), center.Z + math.sin(a) * d), rnd(26, 46), Color3.fromRGB(245, 248, 255), Enum.Material.SmoothPlastic, "Cloud"))
		p.Transparency = 0.35
		p.Size = Vector3.new(p.Size.X * 1.6, p.Size.Y * 0.55, p.Size.Z * 1.2)
	end
end

local function sign(parent, pos, text, color, size)
	local anchor = deco(make("Part", { Name = "SignAnchor", Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(pos), Parent = parent }))
	local bb = make("BillboardGui", { Size = UDim2.new(0, size or 400, 0, (size or 400) / 4), LightInfluence = 0, MaxDistance = 260, Parent = anchor })
	make("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = text, TextColor3 = color, TextScaled = true,
		Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(20, 15, 35), Parent = bb })
	return anchor
end

local function buildLighting()
	Lighting.ClockTime = 15.4
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(80, 78, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 165)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	for _, c in ipairs(Lighting:GetChildren()) do if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Sky") then c:Destroy() end end
	make("Sky", { SunAngularSize = 14, MoonAngularSize = 9, StarCount = 3000, Parent = Lighting })
	make("Atmosphere", { Density = 0.3, Offset = 0.12, Color = Color3.fromRGB(205, 215, 255), Decay = Color3.fromRGB(120, 115, 190), Glare = 0.5, Haze = 1.6, Parent = Lighting })
	make("BloomEffect", { Intensity = 0.7, Size = 28, Threshold = 1.5, Parent = Lighting })
	make("ColorCorrectionEffect", { Saturation = 0.18, Contrast = 0.08, Brightness = 0.02, Parent = Lighting })
	make("SunRaysEffect", { Intensity = 0.08, Spread = 0.7, Parent = Lighting })
	make("DepthOfFieldEffect", { FarIntensity = 0.12, FocusDistance = 120, InFocusRadius = 120, NearIntensity = 0, Parent = Lighting })
	pcall(function()
		local cl = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		cl.Cover = 0.55
		cl.Density = 0.65
		cl.Color = Color3.fromRGB(255, 255, 255)
		cl.Parent = workspace.Terrain
	end)
end

---------------------------------------------------------------- ЛОББИ
local function buildLobby(root)
	local lobby = make("Model", { Name = "Lobby", Parent = root })
	local L = Map.LOBBY
	island(lobby, L, 56, 11)
	-- площадь: кольца плитки с неоновыми вставками
	local rings = { { 44, C.stone2 }, { 40, C.stone }, { 30, C.stone3 }, { 27, C.stone }, { 16, C.stone2 } }
	for i, r in ipairs(rings) do cyl(lobby, L + Vector3.new(0, 0.12 + i * 0.03, 0), r[1], 0.24, r[2], Enum.Material.Slate, "PlazaRing") end
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		deco(block(lobby, CFrame.new(L + Vector3.new(math.cos(a) * 17.5, 0.32, math.sin(a) * 17.5)) * CFrame.Angles(0, -a, 0), Vector3.new(1.2, 0.1, 5), C.purple, Enum.Material.Neon, "Rune"))
	end
	-- дорожки к порталу и к краям
	for _, d in ipairs({ Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1) }) do
		for k = 0, 4 do
			local pos = L + d * (24 + k * 5) + Vector3.new(0, 0.15, 0)
			block(lobby, CFrame.lookAt(pos, pos + d) * CFrame.Angles(0, rnd(-0.08, 0.08), 0), Vector3.new(7, 0.3, 4), (k % 2 == 0) and C.stone or C.stone2, Enum.Material.Slate, "PathStone")
		end
	end
	-- точка появления
	make("SpawnLocation", { Name = "LobbySpawn", Size = Vector3.new(10, 0.4, 10), CFrame = CFrame.new(L + Vector3.new(0, 0.45, 12)), Neutral = true, Duration = 0,
		AllowTeamChangeOnTouch = false, Color = C.purple2, Material = Enum.Material.Neon, Transparency = 0.5, Parent = lobby })
	-- алтарь удачи: ступени, пьедестал, кристалл и кольца
	cyl(lobby, L + Vector3.new(0, 0.6, 0), 13, 1.2, C.stone2, Enum.Material.Marble, "AltarStep1")
	cyl(lobby, L + Vector3.new(0, 1.6, 0), 9.5, 1, C.marble, Enum.Material.Marble, "AltarStep2")
	cyl(lobby, L + Vector3.new(0, 3, 0), 5, 2, C.stone3, Enum.Material.Marble, "AltarTop")
	local cr = block(lobby, CFrame.new(L + Vector3.new(0, 9, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Vector3.new(4.6, 4.6, 4.6), Color3.fromRGB(180, 120, 255), Enum.Material.Neon, "LuckCrystal")
	deco(cr)
	cr:SetAttribute("Spin", 0.9)
	cr:SetAttribute("Bob", 0.8)
	light(cr, Color3.fromRGB(180, 120, 255), 34, 3)
	local r1 = ring(lobby, L + Vector3.new(0, 9, 0), Vector3.new(0, 0, 1), 5.6, 28, 0.45, C.gold, "AltarRing1")
	r1:SetAttribute("Spin", 1.4)
	local r2 = ring(lobby, L + Vector3.new(0, 9, 0), Vector3.new(1, 0, 0), 6.6, 32, 0.4, C.cyan, "AltarRing2")
	r2:SetAttribute("Spin", -1)
	make("ParticleEmitter", { Color = ColorSequence.new(Color3.fromRGB(210, 170, 255)), LightEmission = 1, Rate = 14, Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.5, 0), Parent = cr })
	sign(lobby, L + Vector3.new(0, 19, 0), "СТИХИЙНЫЕ БИТВЫ RNG", Color3.fromRGB(255, 220, 90), 560)
	-- ограда по краю (с проходом к порталу)
	local n = 28
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		if dir.Z > -0.93 then
			local pos = L + dir * 50
			cyl(lobby, pos + Vector3.new(0, 1.6, 0), 1.6, 3.2, C.stone2, Enum.Material.Marble, "FencePost")
			deco(ball(lobby, pos + Vector3.new(0, 3.5, 0), 1.3, C.marble, Enum.Material.Marble, "FenceCap"))
			local a2 = (i + 1) / n * math.pi * 2
			local nxt = L + Vector3.new(math.cos(a2), 0, math.sin(a2)) * 50
			if Vector3.new(math.cos(a2), 0, math.sin(a2)).Z > -0.93 then
				block(lobby, CFrame.lookAt((pos + nxt) / 2 + Vector3.new(0, 2.4, 0), nxt + Vector3.new(0, 2.4, 0)), Vector3.new(0.6, 0.6, (nxt - pos).Magnitude), C.marble, Enum.Material.Marble, "FenceRail")
			end
		end
	end
	-- портал: каменная арка, два вращающихся кольца, вихрь
	local pc = L + Vector3.new(0, 0, -50)
	cyl(lobby, pc + Vector3.new(0, 0.3, 0), 20, 0.6, C.stone3, Enum.Material.Slate, "PortalBase")
	cyl(lobby, pc + Vector3.new(0, 0.62, 0), 16, 0.1, C.purple2, Enum.Material.Neon, "PortalPad")
	for _, sx in ipairs({ -1, 1 }) do
		block(lobby, CFrame.new(pc + Vector3.new(sx * 12, 10, 0)), Vector3.new(3.4, 20, 3.4), C.stone2, Enum.Material.Marble, "ArchPillar")
		block(lobby, CFrame.new(pc + Vector3.new(sx * 12, 0.9, 0)), Vector3.new(4.6, 1.8, 4.6), C.stone3, Enum.Material.Marble, "ArchFoot")
		deco(block(lobby, CFrame.new(pc + Vector3.new(sx * 12, 14, 1.75)), Vector3.new(1.2, 6, 0.2), C.purple, Enum.Material.Neon, "ArchRune"))
	end
	block(lobby, CFrame.new(pc + Vector3.new(0, 21, 0)), Vector3.new(29, 3, 4.4), C.stone2, Enum.Material.Marble, "ArchTop")
	block(lobby, CFrame.new(pc + Vector3.new(0, 23, 0)), Vector3.new(22, 1.4, 3.6), C.stone3, Enum.Material.Marble, "ArchCrown")
	local pr1 = ring(lobby, pc + Vector3.new(0, 10, 0), Vector3.new(0, 0, 1), 8.6, 30, 0.9, C.purple, "PortalRing1")
	pr1:SetAttribute("Spin", 0.8)
	local pr2 = ring(lobby, pc + Vector3.new(0, 10, 0), Vector3.new(0, 0, 1), 7.2, 24, 0.6, Color3.fromRGB(230, 180, 255), "PortalRing2")
	pr2:SetAttribute("Spin", -1.6)
	local disc = make("Part", { Name = "PortalTrigger", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 15, 15),
		CFrame = CFrame.new(pc + Vector3.new(0, 10, 0)) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(150, 80, 255),
		Material = Enum.Material.ForceField, Transparency = 0, CanCollide = false, CastShadow = false, Parent = lobby })
	light(disc, Color3.fromRGB(170, 100, 255), 44, 4)
	make("ParticleEmitter", { Color = ColorSequence.new(Color3.fromRGB(220, 170, 255), Color3.fromRGB(120, 60, 255)), LightEmission = 1, Rate = 60, Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(-6, -3), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.9, 0), Parent = disc })
	sign(lobby, pc + Vector3.new(0, 27, 0), "НА АРЕНУ!", Color3.fromRGB(215, 170, 255), 320)
	-- деревья, фонари, кристаллы, клумбы, водопады, летающие островки
	for _, v in ipairs({ { -36, 20, "green" }, { 38, 24, "pink" }, { -40, -16, "pink" }, { 40, -18, "green" }, { 14, 42, "green" }, { -18, 43, "pink" } }) do
		tree(lobby, L + Vector3.new(v[1], 0, v[2]), rnd(0.9, 1.15), v[3])
		bush(lobby, L + Vector3.new(v[1] + 4, 0, v[2] + 3), 1)
	end
	for i = 0, 7 do local a = i / 8 * math.pi * 2 + math.pi / 8; lamp(lobby, L + Vector3.new(math.cos(a) * 22.5, 0, math.sin(a) * 22.5), Color3.fromRGB(255, 220, 150)) end
	for _, v in ipairs({ { -46, 8 }, { 46, 6 }, { -26, -40 }, { 28, -40 }, { 30, 40 } }) do crystal(lobby, L + Vector3.new(v[1], 0, v[2]), rnd(5, 8), C.cyan) end
	for _, v in ipairs({ { -30, 32 }, { 30, -30 }, { -32, -30 }, { 34, 32 } }) do flowers(lobby, L + Vector3.new(v[1], 0, v[2]), 6, 14) end
	waterfall(lobby, L + Vector3.new(55, 0, 10), Vector3.new(1, 0, 0), 70)
	waterfall(lobby, L + Vector3.new(-40, 0, 38), Vector3.new(-0.7, 0, 0.7).Unit, 60)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + 0.4
		floatRock(lobby, L + Vector3.new(math.cos(a) * rnd(75, 95), rnd(-14, 14), math.sin(a) * rnd(75, 95)), rnd(1, 1.8), (i % 2 == 0) and C.cyan or nil)
	end
	cloudSea(lobby, L, 140, 22, L.Y - 70)
	return lobby
end

---------------------------------------------------------------- АРЕНА
local function buildArena(root)
	local arena = make("Model", { Name = "Arena", Parent = root })
	local A = Map.ARENA
	island(arena, A, 94, 23)
	-- центральная каменная арена с рунами и колоннами
	cyl(arena, A + Vector3.new(0, 1.5, 0), 48, 3, C.stone3, Enum.Material.Slate, "ArenaBase")
	cyl(arena, A + Vector3.new(0, 3.05, 0), 44, 0.1, C.stone, Enum.Material.Slate, "ArenaFloor")
	cyl(arena, A + Vector3.new(0, 3.12, 0), 30, 0.1, C.stone2, Enum.Material.Slate, "ArenaInner")
	cyl(arena, A + Vector3.new(0, 3.16, 0), 10, 0.1, C.stone3, Enum.Material.Slate, "ArenaCore")
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		deco(block(arena, CFrame.new(A + Vector3.new(math.cos(a) * 15.5, 3.2, math.sin(a) * 15.5)) * CFrame.Angles(0, -a, 0), Vector3.new(0.8, 0.08, 2.8), Color3.fromRGB(255, 160, 60), Enum.Material.Neon, "Rune"))
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + math.pi / 8
		pillar(arena, A + Vector3.new(math.cos(a) * 21, 3, math.sin(a) * 21), 12, i % 3 == 1)
	end
	-- ступени и летающие площадки
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		cyl(arena, A + dir * 31 + Vector3.new(0, 4.5, 0), 7, 2, C.stone2, Enum.Material.Slate, "Step")
		cyl(arena, A + dir * 39 + Vector3.new(0, 8.5, 0), 7, 2, C.stone2, Enum.Material.Slate, "Step")
		local pl = cyl(arena, A + dir * 51 + Vector3.new(0, 12, 0), 18, 2.5, C.stone, Enum.Material.Slate, "FloatPlatform")
		cyl(arena, pl.Position - Vector3.new(0, 2.2, 0), 15, 2, C.rock2, Enum.Material.Slate, "PlatformUnder")
		cyl(arena, pl.Position - Vector3.new(0, 4.2, 0), 9, 2, C.rock, Enum.Material.Slate, "PlatformUnder")
		deco(cyl(arena, pl.Position + Vector3.new(0, 1.3, 0), 16.5, 0.1, Color3.fromRGB(255, 160, 60), Enum.Material.Neon, "PlatformRim"))
		crystal(arena, pl.Position + dir * 5 + Vector3.new(0, 1.25, 0), 5, (i % 2 == 0) and Color3.fromRGB(255, 120, 200) or C.cyan)
	end
	-- дорожки от точек появления к центру
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		table.insert(Map.ArenaSpawns, A + dir * 66)
		cyl(arena, A + dir * 66 + Vector3.new(0, 0.12, 0), 7, 0.24, C.stone2, Enum.Material.Slate, "SpawnPad")
		deco(cyl(arena, A + dir * 66 + Vector3.new(0, 0.26, 0), 5, 0.05, C.purple, Enum.Material.Neon, "SpawnGlow"))
		if i % 2 == 0 then
			for k = 0, 6 do
				local pos = A + dir * (27 + k * 5.5) + Vector3.new(0, 0.12, 0)
				block(arena, CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, rnd(-0.1, 0.1), 0), Vector3.new(5, 0.24, 3.4), (k % 2 == 0) and C.stone or C.stone2, Enum.Material.Slate, "PathStone")
			end
		end
	end
	-- природа
	for i = 1, 12 do
		local a, d = rnd(0, math.pi * 2), rnd(32, 84)
		tree(arena, A + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), rnd(0.8, 1.2), (i % 3 == 0) and "pink" or "green")
	end
	for i = 1, 18 do
		local a, d = rnd(0, math.pi * 2), rnd(28, 86)
		if i % 2 == 0 then rock(arena, A + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), rnd(0.7, 1.4)) else bush(arena, A + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), rnd(0.8, 1.3)) end
	end
	for i = 1, 8 do
		local a, d = rnd(0, math.pi * 2), rnd(35, 80)
		flowers(arena, A + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), 5, 10)
	end
	for i = 1, 7 do
		local a, d = rnd(0, math.pi * 2), rnd(70, 88)
		crystal(arena, A + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), rnd(5, 9), (i % 2 == 0) and Color3.fromRGB(255, 120, 200) or C.cyan)
	end
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + 0.3
		waterfall(arena, A + Vector3.new(math.cos(a) * 93, 0, math.sin(a) * 93), Vector3.new(math.cos(a), 0, math.sin(a)), 80)
	end
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		floatRock(arena, A + Vector3.new(math.cos(a) * rnd(115, 140), rnd(-10, 25), math.sin(a) * rnd(115, 140)), rnd(1.2, 2.2), (i % 3 == 0) and Color3.fromRGB(255, 120, 200) or nil)
	end
	cloudSea(arena, A, 220, 34, -60)
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
	local arms = make("Part", { Name = "Arms", Size = Vector3.new(5.2, 0.6, 0.6), CFrame = CFrame.new(pos + Vector3.new(0, 4.6, 0)), Color = Color3.fromRGB(200, 170, 115), Material = Enum.Material.Fabric, Anchored = false, Parent = m })
	make("Decal", { Texture = "rbxasset://textures/face.png", Face = Enum.NormalId.Front, Parent = head })
	for _, p in ipairs({ body, head, pole, arms }) do make("WeldConstraint", { Part0 = base, Part1 = p, Parent = base }) end
	m.PrimaryPart = body
	m:SetAttribute("Home", pos)
	m.Parent = parent
	for _, p in ipairs({ base, body, head, pole, arms }) do pcall(function() p:SetNetworkOwner(nil) end) end
	return m
end

function Map.build()
	buildLighting()
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		Map.ArenaSpawns[i + 1] = Map.ARENA + Vector3.new(math.cos(a) * 66, 0, math.sin(a) * 66)
	end
	local existing = workspace:FindFirstChild("Map")
	if existing then return existing end
	local root = Instance.new("Folder")
	root.Name = "Map"
	root.Parent = workspace
	buildLobby(root)
	buildArena(root)
	-- buildArena добавляет точки появления повторно — оставляем только 10
	for i = #Map.ArenaSpawns, 11, -1 do table.remove(Map.ArenaSpawns, i) end
	return root
end

return Map
