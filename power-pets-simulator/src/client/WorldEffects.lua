--[[
	WorldEffects — то, что игрок видит в мирах:
	- своё освещение, небо, дымка и гравитация для каждого мира (меняются только у этого игрока);
	- крупная надпись с названием мира при входе;
	- монеты крутятся и покачиваются;
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
local UI = Client:WaitForChild("UI")
local Kit = require(UI.Kit)

local WorldEffects = {}

local atmosphere = nil
local sky = nil
local banner = nil
local bannerScale = nil
local currentWorld = nil

------------------------------------------------------------------ ОСВЕЩЕНИЕ

local function applyWorld(worldId, instant)
	local world = Worlds[worldId]
	if not world then
		return
	end
	local settings = world.Lighting
	local duration = instant and 0 or 1.2

	local lightingGoal = {
		ClockTime = settings.ClockTime,
		Brightness = settings.Brightness,
		Ambient = settings.Ambient,
		OutdoorAmbient = settings.OutdoorAmbient,
	}
	local atmosphereGoal = {
		Density = settings.Atmosphere.Density,
		Offset = settings.Atmosphere.Offset,
		Color = settings.Atmosphere.Color,
		Decay = settings.Atmosphere.Decay,
		Glare = settings.Atmosphere.Glare,
		Haze = settings.Atmosphere.Haze,
	}
	if instant then
		for key, value in pairs(lightingGoal) do
			Lighting[key] = value
		end
		for key, value in pairs(atmosphereGoal) do
			atmosphere[key] = value
		end
	else
		Kit.Tween(Lighting, duration, lightingGoal, Enum.EasingStyle.Sine)
		Kit.Tween(atmosphere, duration, atmosphereGoal, Enum.EasingStyle.Sine)
	end
	sky.StarCount = settings.StarCount or 3000
	Workspace.Gravity = world.Gravity or 196.2
end

local function showBanner(worldId)
	local world = Worlds[worldId]
	if not world or not banner then
		return
	end
	banner.Text = world.Icon .. " " .. Format.Upper(world.Name)
	banner.TextColor3 = Kit.Lighten(world.Color, 0.3)
	banner.TextTransparency = 0
	banner.Visible = true
	local stroke = banner:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0
	end
	bannerScale.Scale = 0.4
	Kit.Tween(bannerScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2, function()
		if banner.Text ~= world.Icon .. " " .. Format.Upper(world.Name) then
			return
		end
		Kit.Tween(banner, 0.5, { TextTransparency = 1 })
		if stroke then
			Kit.Tween(stroke, 0.5, { Transparency = 1 })
		end
	end)
end

------------------------------------------------------------------ МОНЕТЫ

local coins = {} -- [part] = исходный CFrame

local function addCoin(part)
	if part:IsA("BasePart") then
		coins[part] = part.CFrame
	end
end

local function spinCoins()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local t = os.clock()
	for part, base in pairs(coins) do
		if part.Parent then
			local position = base.Position
			if (position - cameraPosition).Magnitude < 260 then
				part.CFrame = CFrame.new(position + Vector3.new(0, math.sin(t * 2 + position.X) * 0.4, 0))
					* CFrame.Angles(0, t * 2.5 + position.Z, 0)
			end
		else
			coins[part] = nil
		end
	end
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
		status.Text = "✅ Открыто — заходи!"
		status.TextColor3 = Color3.fromRGB(140, 255, 150)
	elseif total >= world.UnlockStrength then
		status.Text = "✨ Можно открыть — заходи!"
		status.TextColor3 = Color3.fromRGB(255, 230, 100)
	else
		status.Text = string.format("🔒 %s / %s ⭐ силы", Format.Number(total), Format.Number(world.UnlockStrength))
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
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Parent = Lighting
	end

	banner = Kit.Text({
		Name = "WorldBanner",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(700, 90),
		MaxTextSize = 80,
		StrokeThickness = 5,
		Visible = false,
		ZIndex = 30,
		Parent = root,
	})
	bannerScale = Kit.new("UIScale", { Parent = banner })

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

	for _, coin in ipairs(CollectionService:GetTagged("Coin")) do
		addCoin(coin)
	end
	CollectionService:GetInstanceAddedSignal("Coin"):Connect(addCoin)
	CollectionService:GetInstanceRemovedSignal("Coin"):Connect(function(part)
		coins[part] = nil
	end)
	RunService.RenderStepped:Connect(spinCoins)

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
