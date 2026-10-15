--[[
	HatchAnimation — открытие яйца по центру экрана:
	яйцо выпрыгивает → трясётся всё сильнее → вспышка → лучи цвета редкости и 3D-питомец.
	Нажатие на экран ускоряет анимацию. Если яйца открываются быстрее, они встают в очередь.
]]

local Debris = game:GetService("Debris")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Pets = require(Shared.Config.Pets)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Modules.Format)

local UI = script.Parent
local Kit = require(UI.Kit)
local PetViewport = require(UI.PetViewport)
local Sounds = require(UI.Parent.Sounds)

local HatchAnimation = {}

local gui = nil
local root = nil
local queue = {}
local playing = false

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 120)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 230, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 110, 255)),
})

function HatchAnimation.Init(hatchGui)
	gui = hatchGui
	root = Kit.CreateScaledRoot(hatchGui, "Root")
	root.ZIndex = 5
end

local function makeEgg(parent, egg)
	local holder = Kit.new("Frame", {
		Name = "Egg",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(150, 190),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = parent,
	})
	local scale = Kit.new("UIScale", { Scale = 0, Parent = holder })
	local shell = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
		Parent = holder,
	})
	Kit.Corner(shell, UDim.new(0.5, 0))
	Kit.Stroke(shell, 5)
	Kit.Gradient(shell, Kit.Lighten(egg.Color, 0.3), Kit.Darken(egg.Color, 0.15))

	local spots = {
		{ 0.3, 0.3, 0.24 },
		{ 0.68, 0.4, 0.18 },
		{ 0.42, 0.64, 0.22 },
		{ 0.7, 0.74, 0.14 },
		{ 0.24, 0.52, 0.12 },
	}
	for _, spot in ipairs(spots) do
		local dot = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(spot[1], spot[2]),
			Size = UDim2.fromScale(spot[3], spot[3] * 150 / 190),
			BackgroundColor3 = egg.SpotColor,
			ZIndex = 6,
			Parent = shell,
		})
		Kit.Corner(dot, UDim.new(0.5, 0))
	end
	local shine = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.32, 0.2),
		Size = UDim2.fromScale(0.2, 0.14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.35,
		Rotation = -30,
		ZIndex = 7,
		Parent = shell,
	})
	Kit.Corner(shine, UDim.new(0.5, 0))
	return holder, scale
end

local function reveal(slot)
	local result = slot.Result
	local config = Pets[result.Id]
	local rarity = Rarities[config.Rarity]

	-- Лучи.
	local rays = Kit.new("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = slot.Frame,
	})
	slot.Rays = {}
	for index = 1, 10 do
		local ray = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(36, 440),
			BackgroundColor3 = rarity.Color,
			BackgroundTransparency = 0.35,
			Rotation = index * 18,
			ZIndex = 2,
			Parent = rays,
		})
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 90,
			Parent = ray,
		})
		table.insert(slot.Rays, ray)
	end

	local glow = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(190, 190),
		BackgroundColor3 = rarity.Color,
		BackgroundTransparency = 0.45,
		ZIndex = 3,
		Parent = slot.Frame,
	})
	Kit.Corner(glow, UDim.new(0.5, 0))

	local view = PetViewport.new(slot.Frame, {
		Size = UDim2.fromOffset(230, 230),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 4,
	})
	view:SetPet(result.Id, false)
	slot.View = view
	local viewScale = Kit.new("UIScale", { Scale = 0.2, Parent = view.Frame })
	Kit.Tween(viewScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	local nameLabel = Kit.Text({
		Text = config.Icon .. " " .. config.Name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.76),
		Size = UDim2.fromOffset(300, 38),
		MaxTextSize = 34,
		StrokeThickness = 3,
		ZIndex = 6,
		Parent = slot.Frame,
	})
	local rarityLabel = Kit.Text({
		Text = Format.Upper(rarity.Name),
		Color = rarity.Color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.86),
		Size = UDim2.fromOffset(300, 30),
		MaxTextSize = 28,
		StrokeThickness = 3,
		ZIndex = 6,
		Parent = slot.Frame,
	})
	if config.Rarity == "Mythic" then
		rarityLabel.TextColor3 = Color3.new(1, 1, 1)
		slot.Rainbow = Kit.new("UIGradient", { Color = RAINBOW, Parent = rarityLabel })
	end
	Kit.Text({
		Text = Format.Multiplier(config.Multiplier) .. " к силе",
		Color = Kit.Colors.Yellow,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromOffset(300, 28),
		MaxTextSize = 26,
		ZIndex = 6,
		Parent = slot.Frame,
	})
	Kit.Pop(nameLabel, 1.4)
	Kit.Pop(rarityLabel, 1.6)
	return rarity.Order
end

local function play(eggId, results)
	local egg = Eggs[eggId]
	if not egg or type(results) ~= "table" or #results == 0 then
		return
	end
	ProximityPromptService.Enabled = false

	local skip = false
	local dim = Kit.new("Frame", {
		Name = "Dim",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = gui,
	})
	local skipButton = Kit.new("TextButton", {
		Name = "Skip",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = gui,
	})
	skipButton.Activated:Connect(function()
		skip = true
	end)
	Kit.Tween(dim, 0.25, { BackgroundTransparency = 0.35 })

	local count = #results
	local spacing = math.min(270, (root.AbsoluteSize.X / math.max(Kit.Scale, 0.01) - 40) / count)
	local slots = {}
	for index, result in ipairs(results) do
		local frame = Kit.new("Frame", {
			Name = "Slot" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, (index - (count + 1) / 2) * spacing, 0.5, 0),
			Size = UDim2.fromOffset(260, 400),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = root,
		})
		local slotScale = Kit.new("UIScale", { Scale = count > 2 and 0.9 or 1, Parent = frame })
		local eggHolder, eggScale = makeEgg(frame, egg)
		slots[index] = { Frame = frame, Scale = slotScale, Egg = eggHolder, EggScale = eggScale, Result = result }
		Kit.Tween(eggScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	task.wait(0.4)

	-- Тряска.
	local shakeTime = 1.6
	local started = os.clock()
	local nextTick = 0
	while not skip do
		local elapsed = os.clock() - started
		if elapsed >= shakeTime then
			break
		end
		local progress = elapsed / shakeTime
		local angle = math.sin(elapsed * (14 + progress * 30)) * (5 + progress * 16)
		for _, slot in ipairs(slots) do
			slot.Egg.Rotation = angle
			slot.EggScale.Scale = 1 + progress * 0.18
		end
		if elapsed >= nextTick then
			Sounds.Play("EggShake", 1 + progress * 0.6)
			nextTick = elapsed + 0.36 - progress * 0.22
		end
		RunService.RenderStepped:Wait()
	end

	-- Вспышка.
	Sounds.Play("Hatch")
	local flash = Kit.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 40,
		Parent = gui,
	})
	Kit.Tween(flash, 0.6, { BackgroundTransparency = 1 })
	Debris:AddItem(flash, 0.7)

	local best = 0
	for _, slot in ipairs(slots) do
		slot.Egg:Destroy()
		best = math.max(best, reveal(slot))
	end
	if best >= Rarities.Legendary.Order then
		Sounds.Play("Rare")
	elseif best >= Rarities.Epic.Order then
		Sounds.Play("Rare", 1.2)
	end

	-- Показываем результат (нажатие закрывает раньше).
	skip = false
	local shown = os.clock()
	local showTime = best >= Rarities.Legendary.Order and 3.4 or 2.6
	while true do
		local elapsed = os.clock() - shown
		if elapsed >= showTime or (skip and elapsed > 0.5) then
			break
		end
		skip = skip and elapsed > 0.5
		for _, slot in ipairs(slots) do
			for index, ray in ipairs(slot.Rays or {}) do
				ray.Rotation = index * 18 + elapsed * 25
			end
			if slot.Rainbow then
				slot.Rainbow.Offset = Vector2.new(math.sin(elapsed * 3) * 0.5, 0)
			end
		end
		RunService.RenderStepped:Wait()
	end

	-- Исчезновение.
	Kit.Tween(dim, 0.25, { BackgroundTransparency = 1 })
	for _, slot in ipairs(slots) do
		Kit.Tween(slot.Scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end
	task.wait(0.27)
	for _, slot in ipairs(slots) do
		if slot.View then
			slot.View:Destroy()
		end
		slot.Frame:Destroy()
	end
	dim:Destroy()
	skipButton:Destroy()
	ProximityPromptService.Enabled = true
end

function HatchAnimation.Play(eggId, results)
	table.insert(queue, { eggId, results })
	if playing then
		return
	end
	playing = true
	task.spawn(function()
		while #queue > 0 do
			local item = table.remove(queue, 1)
			local ok, err = pcall(play, item[1], item[2])
			if not ok then
				warn("[HatchAnimation]", err)
				-- Убираем остатки анимации, чтобы затемнение не зависло на экране.
				for _, child in ipairs(gui:GetChildren()) do
					if child ~= root then
						child:Destroy()
					end
				end
				for _, child in ipairs(root:GetChildren()) do
					if not child:IsA("UIScale") then
						child:Destroy()
					end
				end
				ProximityPromptService.Enabled = true
			end
		end
		playing = false
	end)
end

function HatchAnimation.IsPlaying()
	return playing
end

return HatchAnimation
