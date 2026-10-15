--[[
	Structures — главные постройки каждого мира:
	точка появления, фонтан, лавка магазина, приветственная арка,
	домик продажи, подставки для яиц и порталы.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Eggs = require(Shared.Config.Eggs)
local Worlds = require(Shared.Config.Worlds)

local Build = require(script.Parent.Build)

local Structures = {}

local part = Build.part
local VERTICAL = Build.VERTICAL
local WHITE = Build.WHITE
local Format = Build.Format

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

------------------------------------------------------------------ ТОЧКА ПОЯВЛЕНИЯ
function Structures.spawn(ctx, isStart)
	local position = ctx.Origin + Build.LAYOUT.Spawn
	local model = Build.model("Spawn", ctx.Folder)
	local accent = ctx.Config.Color
	Build.disc(model, position + Vector3.new(0, 0.25, 0), 16, 0.5, ctx.Palette.Stone or rgb(200, 200, 210), { Name = "SpawnBase", Material = Enum.Material.Slate })
	Build.disc(model, position + Vector3.new(0, 0.4, 0), 13, 0.5, accent, { Name = "SpawnRing", Material = Enum.Material.Neon })
	if isStart then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "SpawnLocation"
		spawn.Anchored = true
		spawn.Shape = Enum.PartType.Cylinder
		spawn.Size = Vector3.new(0.8, 11, 11)
		spawn.CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0)) * VERTICAL
		spawn.Color = accent:Lerp(WHITE, 0.4)
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = model
	else
		Build.disc(model, position + Vector3.new(0, 0.6, 0), 11, 0.8, accent:Lerp(WHITE, 0.4), { Name = "SpawnPad" })
	end
	-- Светящиеся столбики по кругу.
	for i = 0, 5 do
		local angle = i / 6 * math.pi * 2
		local point = position + Vector3.new(math.cos(angle) * 9.5, 0, math.sin(angle) * 9.5)
		part(model, { Name = "SpawnPost", Size = Vector3.new(0.8, 2.4, 0.8), CFrame = CFrame.new(point + Vector3.new(0, 1.2, 0)), Color = ctx.Palette.Stone or rgb(200, 200, 210), Material = Enum.Material.Slate })
		local glow = part(model, { Name = "SpawnGlow", Shape = Enum.PartType.Ball, Size = Vector3.one * 1, CFrame = CFrame.new(point + Vector3.new(0, 2.7, 0)), Color = accent, Material = Enum.Material.Neon })
		if i % 2 == 0 then
			Build.light(glow, accent, 12, 1)
		end
	end
	return CFrame.new(position + Vector3.new(0, 4, 0))
end

------------------------------------------------------------------ ФОНТАН
function Structures.fountain(ctx)
	local position = ctx.Origin + Build.LAYOUT.Fountain
	local model = Build.model("Fountain", ctx.Folder)
	local stone = ctx.Palette.Stone or rgb(205, 205, 215)
	local water = ctx.Palette.FountainWater or rgb(80, 190, 255)
	Build.disc(model, position + Vector3.new(0, 0.8, 0), 16, 1.6, stone, { Name = "Basin", Material = Enum.Material.Slate })
	Build.disc(model, position + Vector3.new(0, 1.65, 0), 14, 0.3, water, { Name = "Water", Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.3, CanCollide = false })
	Build.disc(model, position + Vector3.new(0, 3, 0), 2, 4, stone, { Name = "Pillar", Material = Enum.Material.Slate })
	Build.disc(model, position + Vector3.new(0, 5.2, 0), 7, 0.8, stone, { Name = "Bowl", Material = Enum.Material.Slate })
	Build.disc(model, position + Vector3.new(0, 5.65, 0), 6, 0.2, water, { Name = "BowlWater", Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false })
	local jet = part(model, { Name = "Jet", Size = Vector3.new(1.2, 3, 1.2), CFrame = CFrame.new(position + Vector3.new(0, 7.2, 0)), Color = water, Material = Enum.Material.Neon, Transparency = 0.35, Mesh = Enum.MeshType.Sphere, CanCollide = false })
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(rgb(200, 240, 255), water)
	spray.LightEmission = 0.5
	spray.Rate = 40
	spray.Lifetime = NumberRange.new(1, 1.5)
	spray.Speed = NumberRange.new(8, 11)
	spray.SpreadAngle = Vector2.new(18, 18)
	spray.Acceleration = Vector3.new(0, -22, 0)
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.2) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = jet
	Build.light(jet, water, 14, 1)
	return position
end

------------------------------------------------------------------ ЛАВКА МАГАЗИНА
function Structures.shopStall(ctx)
	local position = ctx.Origin + Build.LAYOUT.ShopStall
	local model = Build.model("ShopStall", ctx.Folder)
	-- Лавка смотрит на точку появления.
	local base = CFrame.lookAt(position, ctx.Origin + Build.LAYOUT.Spawn * Vector3.new(1, 0, 1))
	local wood = ctx.Palette.Wood or rgb(170, 110, 60)
	local awningA = ctx.Palette.AwningA or rgb(255, 205, 60)
	local awningB = WHITE

	part(model, { Name = "Floor", Size = Vector3.new(14, 0.8, 9), CFrame = base * CFrame.new(0, 0.4, 0), Color = wood:Lerp(Color3.new(0, 0, 0), 0.2), Material = Enum.Material.WoodPlanks })
	local counter = part(model, { Name = "Counter", Size = Vector3.new(12, 3.4, 2.4), CFrame = base * CFrame.new(0, 2.5, -2.8), Color = wood, Material = Enum.Material.WoodPlanks })
	part(model, { Name = "CounterTop", Size = Vector3.new(12.6, 0.5, 3), CFrame = base * CFrame.new(0, 4.4, -2.8), Color = wood:Lerp(WHITE, 0.15), Material = Enum.Material.WoodPlanks })
	for _, x in ipairs({ -6, 6 }) do
		for _, z in ipairs({ -3.8, 3.8 }) do
			part(model, { Name = "Post", Size = Vector3.new(0.8, 10, 0.8), CFrame = base * CFrame.new(x, 5.4, z), Color = wood, Material = Enum.Material.Wood })
		end
	end
	-- Полосатый навес.
	for i = 0, 6 do
		part(model, {
			Name = "Awning",
			Size = Vector3.new(2, 0.5, 10),
			CFrame = base * CFrame.new(-6 + i * 2, 10.6, 0) * CFrame.Angles(math.rad(-14), 0, 0),
			Color = i % 2 == 0 and awningA or awningB,
		})
	end
	-- Вывеска.
	local signBoard = part(model, { Name = "SignBoard", Size = Vector3.new(10, 2.6, 0.5), CFrame = base * CFrame.new(0, 12.8, -4.2), Color = ctx.Palette.SignColor or rgb(255, 150, 50) })
	Build.sign(signBoard, Enum.NormalId.Front, "МАГАЗИН", WHITE, nil)
	-- Товары на прилавке: рюкзаки разных цветов.
	local colors = { rgb(90, 170, 255), rgb(255, 120, 80), rgb(120, 220, 110) }
	for i, color in ipairs(colors) do
		local at = base * CFrame.new(-4 + (i - 1) * 4, 5.9, -2.8)
		part(model, { Name = "BagBody", Size = Vector3.new(1.8, 2.2, 1.2), CFrame = at, Color = color })
		part(model, { Name = "BagTop", Size = Vector3.new(1.8, 1, 1.2), CFrame = at * CFrame.new(0, 1.1, 0), Color = color, Mesh = Enum.MeshType.Sphere })
		part(model, { Name = "BagPocket", Size = Vector3.new(1.2, 0.8, 0.3), CFrame = at * CFrame.new(0, -0.4, -0.65), Color = color:Lerp(WHITE, 0.25) })
	end
	local lamp = part(model, { Name = "StallLamp", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, CFrame = base * CFrame.new(0, 9.4, -1), Color = rgb(255, 230, 150), Material = Enum.Material.Neon })
	Build.light(lamp, rgb(255, 220, 150), 16, 1.2)

	-- Кнопка «Магазин»: клиент сам откроет окно магазина.
	local attachment = Instance.new("Attachment")
	attachment.Name = "PromptPoint"
	attachment.Position = Vector3.new(0, 1.5, -1.8)
	attachment.Parent = counter
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenShop"
	prompt.ActionText = "Магазин"
	prompt.ObjectText = "Рюкзаки и бонусы"
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("Icon", "ShopBag")
	prompt:SetAttribute("Color", awningA)
	prompt:SetAttribute("OpensPanel", "Shop")
	prompt.Parent = attachment
	return position
end

------------------------------------------------------------------ АРКА
function Structures.welcomeArch(ctx, title)
	local position = ctx.Origin + Build.LAYOUT.WelcomeArch
	local model = Build.model("WelcomeArch", ctx.Folder)
	local base = CFrame.new(position)
	local pillar = ctx.Palette.ArchColor or rgb(150, 100, 60)
	for _, side in ipairs({ -1, 1 }) do
		part(model, { Name = "ArchPillar", Size = Vector3.new(2.4, 14, 2.4), CFrame = base * CFrame.new(side * 9, 7, 0), Color = pillar, Material = Enum.Material.Wood })
		local ball = part(model, { Name = "ArchLamp", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = base * CFrame.new(side * 9, 15, 0), Color = ctx.Config.Color, Material = Enum.Material.Neon })
		Build.light(ball, ctx.Config.Color, 16, 1.2)
	end
	local beam = part(model, { Name = "ArchBeam", Size = Vector3.new(22, 3.6, 1.6), CFrame = base * CFrame.new(0, 12.6, 0), Color = ctx.Palette.SignColor or rgb(255, 150, 50) })
	-- Надпись с двух сторон.
	Build.sign(beam, Enum.NormalId.Front, title, WHITE, nil)
	Build.sign(beam, Enum.NormalId.Back, title, WHITE, nil)
	-- Гирлянда
	for i = 0, 10 do
		local x = -9 + i * 1.8
		local sag = math.sin(i / 10 * math.pi) * 1.4
		part(model, {
			Name = "Garland",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.6,
			CFrame = base * CFrame.new(x, 10.4 - sag, -0.9),
			Color = (i % 3 == 0) and rgb(255, 90, 90) or ((i % 3 == 1) and rgb(255, 220, 80) or rgb(110, 200, 255)),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
end

------------------------------------------------------------------ ДОМИК ПРОДАЖИ
function Structures.sellShop(ctx)
	local center = ctx.Origin + Build.LAYOUT.Sell
	local model = Build.model("SellZone", ctx.Folder)
	local wood = ctx.Palette.Wood or rgb(170, 110, 60)

	-- Круг продажи: светящийся диск с кольцом.
	Build.disc(model, center + Vector3.new(0, 0.15, 0), GameConfig.SellRadius * 2 + 4, 0.3, rgb(30, 110, 50), { Name = "SellRing", Material = Enum.Material.Slate })
	local pad = Build.disc(model, center + Vector3.new(0, 0.3, 0), GameConfig.SellRadius * 2, 0.3, rgb(90, 255, 120), {
		Name = "SellPad",
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	})
	Build.disc(model, center + Vector3.new(0, 0.35, 0), GameConfig.SellRadius * 1.2, 0.3, rgb(220, 255, 220), { Name = "SellPadInner", Material = Enum.Material.Neon, Transparency = 0.2, CanCollide = false })

	-- Кольцо из летающих монет (крутится на клиенте).
	local coinRing = Build.model("CoinRing", model)
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2
		part(coinRing, {
			Name = "RingCoin",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 2.2, 2.2),
			CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * 7, 4.5, math.sin(angle) * 7)) * CFrame.Angles(0, -angle, 0),
			Color = rgb(255, 205, 40),
			Reflectance = 0.25,
			CanCollide = false,
		})
	end
	coinRing.WorldPivot = CFrame.new(center + Vector3.new(0, 4.5, 0))
	coinRing:SetAttribute("SpinSpeed", 0.9)
	CollectionService:AddTag(coinRing, "Spin")

	-- Домик-банк позади круга.
	local house = CFrame.new(center + Vector3.new(0, 0, 16))
	part(model, { Name = "BankFloor", Size = Vector3.new(18, 1, 11), CFrame = house * CFrame.new(0, 0.5, 0), Color = rgb(200, 200, 210), Material = Enum.Material.Slate })
	part(model, { Name = "BankWalls", Size = Vector3.new(16, 9, 9), CFrame = house * CFrame.new(0, 5.5, 0.5), Color = ctx.Palette.BankWalls or rgb(255, 240, 210), Material = Enum.Material.Plaster })
	Build.roof(model, house * CFrame.new(0, 10, 0.5), 18, 11, 5, ctx.Palette.Roof or rgb(80, 170, 90), Enum.Material.WoodPlanks)
	part(model, { Name = "BankDoor", Size = Vector3.new(4, 6, 0.4), CFrame = house * CFrame.new(0, 4, -4.1), Color = wood, Material = Enum.Material.WoodPlanks })
	part(model, { Name = "DoorKnob", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, CFrame = house * CFrame.new(1.3, 4, -4.35), Color = rgb(255, 205, 60) })
	for _, side in ipairs({ -1, 1 }) do
		local window = part(model, { Name = "BankWindow", Size = Vector3.new(3, 3, 0.3), CFrame = house * CFrame.new(side * 5, 5.5, -4.05), Color = rgb(255, 225, 140), Material = Enum.Material.Neon })
		Build.light(window, rgb(255, 220, 150), 10, 0.8)
		part(model, { Name = "WindowFrame", Size = Vector3.new(3.6, 0.4, 0.5), CFrame = house * CFrame.new(side * 5, 3.8, -4.1), Color = wood, Material = Enum.Material.WoodPlanks })
	end
	local signBoard = part(model, { Name = "BankSign", Size = Vector3.new(12, 2.8, 0.5), CFrame = house * CFrame.new(0, 9.4, -4.4), Color = rgb(60, 190, 80) })
	Build.sign(signBoard, Enum.NormalId.Front, "ПРОДАЖА", WHITE, nil)
	-- Мешки и горки монет у входа.
	for _, offset in ipairs({ Vector3.new(-6, 0, -5.5), Vector3.new(6, 0, -5.5) }) do
		local at = house.Position + offset
		part(model, { Name = "MoneyBag", Size = Vector3.new(2.6, 2.6, 2.4), CFrame = CFrame.new(at + Vector3.new(0, 1.3, 0)), Color = rgb(190, 160, 110), Mesh = Enum.MeshType.Sphere })
		part(model, { Name = "BagTie", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.2, 1.2), CFrame = CFrame.new(at + Vector3.new(0, 2.7, 0)) * VERTICAL, Color = rgb(255, 205, 60) })
		for k = 0, 4 do
			part(model, { Name = "CoinPile", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.6, 1.6), CFrame = CFrame.new(at + Vector3.new(2, 0.2 + k * 0.32, 1)) * VERTICAL, Color = rgb(255, 205, 40), Reflectance = 0.2 })
		end
	end

	local gui = Build.billboard(pad, Vector2.new(16, 5), Vector3.new(0, 8.5, 0), 160)
	Build.list(gui)
	Build.line(gui, "ПРОДАЖА СИЛЫ", rgb(130, 255, 150), 0.55, 1)
	Build.line(gui, "Встань в круг: 1 сила = " .. ctx.Config.SellMultiplier .. " монет", WHITE, 0.4, 2)

	pad:SetAttribute("SellMultiplier", ctx.Config.SellMultiplier)
	CollectionService:AddTag(pad, "SellPad")
	return { Position = center, Radius = GameConfig.SellRadius }
end

------------------------------------------------------------------ ЯЙЦА
function Structures.eggStand(ctx, eggId)
	local egg = Eggs[eggId]
	local position = ctx.Origin + Vector3.new(egg.Position.X, 0, egg.Position.Z)
	local model = Build.model(eggId, ctx.Folder)
	local stone = ctx.Palette.Stone or rgb(205, 205, 215)

	Build.disc(model, position + Vector3.new(0, 0.5, 0), 12, 1, stone, { Name = "PedestalBase", Material = Enum.Material.Slate })
	Build.disc(model, position + Vector3.new(0, 1.4, 0), 10, 1, ctx.Palette.Stand, { Name = "Pedestal" })
	Build.disc(model, position + Vector3.new(0, 1.2, 0), 10.6, 0.4, egg.Color, { Name = "Trim", Material = Enum.Material.Neon })
	Build.disc(model, position + Vector3.new(0, 2.05, 0), 8, 0.3, egg.Color:Lerp(WHITE, 0.4), { Name = "Top", Material = Enum.Material.Neon, Transparency = 0.3 })

	-- Яйцо со пятнышками — отдельная модель, клиент её плавно покачивает (тег Bob).
	local eggModel = Build.model("EggModel", model)
	local eggPart = part(eggModel, {
		Name = "Egg",
		Size = Vector3.new(4.6, 5.8, 4.6),
		CFrame = CFrame.new(position + Vector3.new(0, 2.2 + 3.2, 0)),
		Color = egg.Color,
		Mesh = Enum.MeshType.Sphere,
	})
	local spots = { { 20, 10 }, { 95, -15 }, { 160, 25 }, { 230, -5 }, { 300, 30 }, { 60, 45 }, { 200, 50 }, { 330, -30 } }
	for _, spot in ipairs(spots) do
		local around, elevation = math.rad(spot[1]), math.rad(spot[2])
		local offset = Vector3.new(math.cos(elevation) * math.cos(around) * 2.3, math.sin(elevation) * 2.9, math.cos(elevation) * math.sin(around) * 2.3)
		part(eggModel, {
			Name = "Spot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.2,
			CFrame = CFrame.new(eggPart.Position + offset * 0.93),
			Color = egg.SpotColor,
			CanCollide = false,
		})
	end
	eggModel.PrimaryPart = eggPart
	Build.light(eggPart, egg.Color, 14, 1.2)

	-- Блёстки вокруг яйца.
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(egg.Color:Lerp(WHITE, 0.5), WHITE)
	sparkles.LightEmission = 1
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(1.2, 2)
	sparkles.Speed = NumberRange.new(0.5, 1.5)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Parent = eggPart

	-- Таблички с питомцами рисует клиент (client/UI/EggDisplays).
	eggPart:SetAttribute("EggId", eggId)
	eggModel:SetAttribute("BobHeight", 0.5)
	eggModel:SetAttribute("SpinSpeed", 1.6)
	CollectionService:AddTag(eggModel, "Bob")
	CollectionService:AddTag(eggPart, "EggStand")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return eggPart
end

------------------------------------------------------------------ ПОРТАЛЫ
function Structures.portal(ctx, localPosition, targetWorldId, isBack)
	local target = Worlds[targetWorldId]
	local position = ctx.Origin + localPosition
	-- Портал смотрит лицом к центру мира.
	local base = CFrame.lookAt(position, Vector3.new(ctx.Origin.X, position.Y, ctx.Origin.Z))
	local model = Build.model((isBack and "BackPortal_" or "Portal_") .. targetWorldId, ctx.Folder)
	local frameColor = ctx.Palette.PortalFrame
	local glow = target.Color

	part(model, { Name = "Step", Size = Vector3.new(26, 1.2, 8), CFrame = base * CFrame.new(0, 0.6, 0), Color = frameColor:Lerp(Build.INK, 0.25), Material = Enum.Material.Slate })
	part(model, { Name = "Step2", Size = Vector3.new(22, 0.8, 6), CFrame = base * CFrame.new(0, 1.4, 0), Color = frameColor, Material = Enum.Material.Slate })
	for _, side in ipairs({ -1, 1 }) do
		part(model, { Name = "Pillar", Size = Vector3.new(3.4, 20, 3.4), CFrame = base * CFrame.new(side * 10, 11.6, 0), Color = frameColor, Material = Enum.Material.Slate })
		part(model, { Name = "PillarCap", Size = Vector3.new(4.4, 1.4, 4.4), CFrame = base * CFrame.new(side * 10, 22.2, 0), Color = frameColor:Lerp(WHITE, 0.15), Material = Enum.Material.Slate })
		for k = 1, 3 do
			part(model, { Name = "Rune", Size = Vector3.new(0.2, 1.6, 1.6), CFrame = base * CFrame.new(side * 10 - side * 1.75, 4 + k * 4.5, 0) * CFrame.Angles(math.rad(45), 0, 0), Color = glow, Material = Enum.Material.Neon })
		end
		local gem = part(model, { Name = "Gem", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = base * CFrame.new(side * 10, 23.8, 0), Color = glow, Material = Enum.Material.Neon })
		Build.light(gem, glow, 16, 1.4)
	end
	local top = part(model, { Name = "Top", Size = Vector3.new(25, 3, 4), CFrame = base * CFrame.new(0, 24.5, 0), Color = frameColor, Material = Enum.Material.Slate })

	-- Вихрь: светящийся диск и вращающееся кольцо.
	local swirl = part(model, {
		Name = "Swirl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 15, 15),
		CFrame = base * CFrame.new(0, 11.5, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Color = glow,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
	})
	Build.light(swirl, glow, 24, 2)
	local ring = Build.model("PortalRing", model)
	local ringCenter = base * CFrame.new(0, 11.5, -0.6)
	for i = 0, 15 do
		local angle = i / 16 * math.pi * 2
		part(ring, {
			Name = "RingSegment",
			Size = Vector3.new(2.6, 0.7, 0.6),
			CFrame = ringCenter * CFrame.Angles(0, 0, angle) * CFrame.new(0, 7.8, 0),
			Color = (i % 2 == 0) and glow or glow:Lerp(WHITE, 0.5),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	ring.WorldPivot = ringCenter * CFrame.Angles(math.pi / 2, 0, 0)
	ring:SetAttribute("SpinSpeed", 1.2)
	CollectionService:AddTag(ring, "Spin")

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(glow, WHITE)
	particles.LightEmission = 1
	particles.Rate = 30
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Speed = NumberRange.new(1, 3)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	particles.Parent = swirl

	local touch = part(model, {
		Name = "Touch",
		Size = Vector3.new(15, 17, 3),
		CFrame = base * CFrame.new(0, 11, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})

	local gui = Build.billboard(top, Vector2.new(20, 6.5), Vector3.new(0, 5.5, 0), 240)
	Build.list(gui)
	local title = isBack and ("Назад: " .. target.Name) or Format.Upper(target.Name)
	Build.line(gui, title, target.Color:Lerp(WHITE, 0.35), 0.55, 1, "Title")
	local status = isBack and "Открыто" or ("Нужно " .. Format.Number(target.UnlockStrength) .. " силы")
	Build.line(gui, status, WHITE, 0.4, 2, "Status")

	model:SetAttribute("TargetWorld", targetWorldId)
	model:SetAttribute("IsBack", isBack)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(model, "Portal")
	return { Touch = touch, TargetWorld = targetWorldId }
end

return Structures
