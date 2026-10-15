--[[
	WorldEffects — атмосфера миров (только у этого игрока):
	- освещение, дымка, небо, гравитация;
	- пост-эффекты («шейдеры» Roblox): Bloom, ColorCorrection, SunRays, DepthOfField;
	- объёмные облака (Terrain.Clouds) и цвет воды;
	- частицы вокруг камеры: светлячки в лесу, песок в пустыне, звёздная пыль в космосе;
	- крупная надпись с 3D-иконкой при входе в мир и смена музыки;
	- анимации декора: монеты крутятся, детали с тегами Spin/Bob вращаются и покачиваются;
	- таблички порталов показывают, сколько силы ещё нужно именно этому игроку.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local Format = require(Shared.Modules.Format)

local Client = script.Parent
local State = require(Client.State)
local Sounds = require(Client.Sounds)
local UI = Client:WaitForChild("UI")
local Kit = require(UI.Kit)
local Icons = require(UI.Icons)

local WorldEffects = {}

local atmosphere, sky, clouds = nil, nil, nil
local effects = {}
local ambientPart, ambientEmitter = nil, nil
local banner, bannerScale, bannerText, bannerIcon = nil, nil, nil, nil
local currentWorld = nil

local function getOrCreate(parent, className, name)
	local item = parent:FindFirstChild(name)
	if not item or not item:IsA(className) then
		item = Instance.new(className)
		item.Name = name
		item.Parent = parent
	end
	return item
end

------------------------------------------------------------------ ЧАСТИЦЫ ВОКРУГ КАМЕРЫ
local PARTICLES = {
	Fireflies = {
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(180, 255, 120)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.25), NumberSequenceKeypoint.new(1, 0) }),
		Rate = 14,
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(0.3, 1.2),
		LightEmission = 1,
		Acceleration = Vector3.new(0, 0.3, 0),
	},
	Sand = {
		Color = ColorSequence.new(Color3.fromRGB(255, 225, 170), Color3.fromRGB(230, 190, 120)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.35) }),
		Rate = 30,
		Lifetime = NumberRange.new(2, 4),
		Speed = NumberRange.new(4, 8),
		LightEmission = 0.2,
		Acceleration = Vector3.new(6, -0.5, 2),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1) }),
	},
	Stardust = {
		Color = ColorSequence.new(Color3.fromRGB(200, 220, 255), Color3.fromRGB(230, 160, 255)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 0) }),
		Rate = 22,
		Lifetime = NumberRange.new(3, 6),
		Speed = NumberRange.new(0.2, 0.8),
		LightEmission = 1,
		Acceleration = Vector3.new(0, 0.1, 0),
	},
}

local function setParticles(kind)
	local preset = PARTICLES[kind]
	if not preset then
		ambientEmitter.Enabled = false
		return
	end
	ambientEmitter.Enabled = true
	ambientEmitter.Color = preset.Color
	ambientEmitter.Size = preset.Size
	ambientEmitter.Rate = preset.Rate
	ambientEmitter.Lifetime = preset.Lifetime
	ambientEmitter.Speed = preset.Speed
	ambientEmitter.LightEmission = preset.LightEmission
	ambientEmitter.Acceleration = preset.Acceleration
	ambientEmitter.Transparency = preset.Transparency or NumberSequence.new(0.1)
end

------------------------------------------------------------------ МИР
local function tweenOrSet(instance, goal, duration)
	if duration <= 0 then
		for key, value in pairs(goal) do
			instance[key] = value
		end
	else
		Kit.Tween(instance, duration, goal, Enum.EasingStyle.Sine)
	end
end

local function applyWorld(worldId, instant)
	local world = Worlds[worldId]
	if not world then
		return
	end
	local settings = world.Lighting
	local duration = instant and 0 or 1.4

	tweenOrSet(Lighting, {
		ClockTime = settings.ClockTime,
		Brightness = settings.Brightness,
		Ambient = settings.Ambient,
		OutdoorAmbient = settings.OutdoorAmbient,
		ShadowSoftness = settings.ShadowSoftness or 0.2,
		ExposureCompensation = settings.ExposureCompensation or 0,
	}, duration)
	tweenOrSet(atmosphere, settings.Atmosphere, duration)
	if settings.Bloom then
		tweenOrSet(effects.Bloom, settings.Bloom, duration)
	end
	if settings.ColorCorrection then
		tweenOrSet(effects.ColorCorrection, settings.ColorCorrection, duration)
	end
	if settings.SunRays then
		tweenOrSet(effects.SunRays, settings.SunRays, duration)
	end
	if settings.DepthOfField then
		tweenOrSet(effects.DepthOfField, settings.DepthOfField, duration)
	end
	if settings.Clouds and clouds then
		clouds.Enabled = settings.Clouds.Enabled
		tweenOrSet(clouds, { Cover = settings.Clouds.Cover, Density = settings.Clouds.Density, Color = settings.Clouds.Color }, duration)
	end
	if settings.Water then
		local terrain = Workspace.Terrain
		terrain.WaterColor = settings.Water.Color
		terrain.WaterTransparency = settings.Water.Transparency
		terrain.WaterReflectance = settings.Water.Reflectance
		terrain.WaterWaveSize = settings.Water.WaveSize
		terrain.WaterWaveSpeed = settings.Water.WaveSpeed
	end
	sky.StarCount = settings.StarCount or 3000
	sky.CelestialBodiesShown = worldId ~= "Space"
	setParticles(settings.Particles)
	Workspace.Gravity = world.Gravity or 196.2
	Sounds.SetWorld(worldId)
end

local function showBanner(worldId)
	local world = Worlds[worldId]
	if not world or not banner then
		return
	end
	banner.Visible = true
	bannerText.Text = Format.Upper(world.Name)
	bannerText.TextColor3 = Kit.Lighten(world.Color, 0.3)
	bannerText.TextTransparency = 0
	local stroke = bannerText:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0
	end
	if bannerIcon then
		bannerIcon:Destroy()
	end
	bannerIcon = Icons.Create(banner, world.Icon, {
		Size = UDim2.fromOffset(120, 120),
		Position = UDim2.new(0.5, 0, 0, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 31,
		Animate = "Spin",
	})
	bannerScale.Scale = 0.3
	Kit.Tween(bannerScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	local shownName = bannerText.Text
	task.delay(2.2, function()
		if bannerText.Text ~= shownName then
			return
		end
		Kit.Tween(bannerText, 0.5, { TextTransparency = 1 })
		if stroke then
			Kit.Tween(stroke, 0.5, { Transparency = 1 })
		end
		Kit.Tween(bannerScale, 0.5, { Scale = 0.6 })
		task.delay(0.5, function()
			if bannerText.Text == shownName then
				banner.Visible = false
			end
		end)
	end)
end

------------------------------------------------------------------ АНИМАЦИИ ДЕКОРА
local animated = {} -- [part] = { Base = CFrame, Kind = "Coin" | "Spin" | "Bob", Speed, Seed }

-- Деталь или целая модель (модель вращается вокруг своего центра через PivotTo).
local function track(item, kind)
	if animated[item] or not (item:IsA("BasePart") or item:IsA("Model")) then
		return
	end
	local pivot = item:GetPivot()
	animated[item] = {
		Base = pivot,
		Kind = kind,
		IsModel = item:IsA("Model"),
		Speed = item:GetAttribute("SpinSpeed") or 1,
		Amplitude = item:GetAttribute("BobHeight") or 1.5,
		Seed = (pivot.Position.X + pivot.Position.Z) * 0.37,
	}
end

local function animate()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local t = os.clock()

	if ambientPart then
		ambientPart.CFrame = CFrame.new(cameraPosition + camera.CFrame.LookVector * 18)
	end

	for item, info in pairs(animated) do
		if not item.Parent then
			animated[item] = nil
		else
			local base = info.Base
			if (base.Position - cameraPosition).Magnitude < 320 then
				local target
				if info.Kind == "Coin" then
					local position = base.Position
					target = CFrame.new(position + Vector3.new(0, math.sin(t * 2 + info.Seed) * 0.45, 0)) * CFrame.Angles(0, t * 2.5 + info.Seed, 0)
				elseif info.Kind == "Spin" then
					target = base * CFrame.Angles(0, t * info.Speed, 0)
				else
					target = base + Vector3.new(0, math.sin(t * info.Speed + info.Seed) * info.Amplitude, 0)
				end
				if info.IsModel then
					item:PivotTo(target)
				else
					item.CFrame = target
				end
			end
		end
	end
end

local function watchTag(tag, kind)
	for _, part in ipairs(CollectionService:GetTagged(tag)) do
		track(part, kind)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
		track(part, kind)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(part)
		animated[part] = nil
	end)
end

------------------------------------------------------------------ ПОРТАЛЫ
local portals = {}

local function updatePortal(model)
	if model:GetAttribute("IsBack") then
		return
	end
	local status = model:FindFirstChild("Status", true)
	local targetId = model:GetAttribute("TargetWorld")
	local world = Worlds[targetId]
	if not status or not world then
		return
	end
	local total = State.Get("TotalStrength", 0)
	if State.UnlockedWorlds()[targetId] then
		status.Text = "Открыто — заходи!"
		status.TextColor3 = Color3.fromRGB(140, 255, 150)
	elseif total >= world.UnlockStrength then
		status.Text = "Можно открыть — заходи!"
		status.TextColor3 = Color3.fromRGB(255, 230, 100)
	else
		status.Text = string.format("Закрыто: %s / %s силы", Format.Number(total), Format.Number(world.UnlockStrength))
		status.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

local updateQueued = false
local function updateAllPortals()
	if updateQueued then
		return
	end
	updateQueued = true
	task.delay(0.3, function()
		updateQueued = false
		for model in pairs(portals) do
			if model.Parent then
				updatePortal(model)
			else
				portals[model] = nil
			end
		end
	end)
end

local function addPortal(model)
	portals[model] = true
	updatePortal(model)
	-- При StreamingEnabled табличка может подгрузиться позже самого портала.
	model.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "Status" then
			updatePortal(model)
		end
	end)
end

------------------------------------------------------------------ ЗАПУСК
function WorldEffects.Init(root)
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or getOrCreate(Lighting, "Atmosphere", "Atmosphere")
	sky = Lighting:FindFirstChildOfClass("Sky") or getOrCreate(Lighting, "Sky", "Sky")
	effects.Bloom = getOrCreate(Lighting, "BloomEffect", "PowerPetsBloom")
	effects.ColorCorrection = getOrCreate(Lighting, "ColorCorrectionEffect", "PowerPetsColor")
	effects.SunRays = getOrCreate(Lighting, "SunRaysEffect", "PowerPetsSunRays")
	effects.DepthOfField = getOrCreate(Lighting, "DepthOfFieldEffect", "PowerPetsDepth")
	pcall(function()
		Lighting.EnvironmentDiffuseScale = 1
		Lighting.EnvironmentSpecularScale = 1
		Lighting.PrioritizeLightingQuality = true
	end)
	pcall(function()
		clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or getOrCreate(Workspace.Terrain, "Clouds", "Clouds")
	end)

	-- Невидимая деталь у камеры, из которой летят частицы.
	ambientPart = Instance.new("Part")
	ambientPart.Name = "AmbientParticles"
	ambientPart.Anchored = true
	ambientPart.CanCollide = false
	ambientPart.CanQuery = false
	ambientPart.CanTouch = false
	ambientPart.Transparency = 1
	ambientPart.Size = Vector3.new(70, 24, 70)
	ambientPart.Parent = Workspace
	ambientEmitter = Instance.new("ParticleEmitter")
	ambientEmitter.SpreadAngle = Vector2.new(180, 180)
	ambientEmitter.Parent = ambientPart

	banner = Kit.new("Frame", {
		Name = "WorldBanner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(700, 90),
		Visible = false,
		ZIndex = 30,
		Parent = root,
	})
	bannerScale = Kit.new("UIScale", { Parent = banner })
	bannerText = Kit.Text({
		Name = "Title",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		MaxTextSize = 84,
		StrokeThickness = 6,
		ZIndex = 31,
		Parent = banner,
	})

	State.Watch("World", function()
		local worldId = State.Get("World", "Forest")
		if worldId == currentWorld then
			return
		end
		local first = currentWorld == nil
		currentWorld = worldId
		applyWorld(worldId, first)
		if State.IsLoaded() or not first then
			showBanner(worldId)
		end
	end)
	-- Приветственная надпись, когда данные загрузились.
	State.Watch("DataLoaded", function()
		if State.IsLoaded() then
			showBanner(State.Get("World", "Forest"))
		end
	end)

	watchTag("Coin", "Coin")
	watchTag("Spin", "Spin")
	watchTag("Bob", "Bob")
	RunService.RenderStepped:Connect(animate)

	for _, portal in ipairs(CollectionService:GetTagged("Portal")) do
		addPortal(portal)
	end
	CollectionService:GetInstanceAddedSignal("Portal"):Connect(addPortal)
	CollectionService:GetInstanceRemovedSignal("Portal"):Connect(function(model)
		portals[model] = nil
	end)
	State.Watch({ "TotalStrength", "UnlockedWorlds" }, updateAllPortals)
end

return WorldEffects
