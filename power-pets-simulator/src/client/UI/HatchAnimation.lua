--[[
	HatchAnimation — открытие яйца по центру экрана:
	3D-яйцо выпрыгивает → трясётся всё сильнее → трескается (скорлупа разлетается) → вспышка →
	лучи цвета редкости и 3D-питомец. Для редких — конфетти.
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
local Icons = require(UI.Icons)
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

-- Осколки скорлупы разлетаются из центра слота.
local function burstShell(slotFrame, egg)
	for i = 1, 12 do
		local size = math.random(16, 30)
		local shard = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(size, size * 0.8),
			BackgroundColor3 = (i % 3 == 0) and egg.SpotColor or egg.Color,
			Rotation = math.random(0, 360),
			ZIndex = 9,
			Parent = slotFrame,
		})
		Kit.Corner(shard, UDim.new(0, 4))
		Kit.Stroke(shard, 2.5)
		local angle = (i / 12) * math.pi * 2 + math.random() * 0.4
		local distance = math.random(130, 210)
		Kit.Tween(shard, 0.7, {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.42, math.sin(angle) * distance + 60),
			Rotation = shard.Rotation + math.random(-260, 260),
			BackgroundTransparency = 1,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local stroke = shard:FindFirstChildOfClass("UIStroke")
		if stroke then
			Kit.Tween(stroke, 0.7, { Transparency = 1 })
		end
		Debris:AddItem(shard, 0.8)
	end
end

-- Конфетти для легендарных и мифических.
local function confetti()
	local size = root.AbsoluteSize / math.max(Kit.Scale, 0.01)
	local colors = { Kit.Colors.Yellow, Kit.Colors.Pink, Kit.Colors.Blue, Kit.Colors.Green, Kit.Colors.Purple, Kit.Colors.Orange }
	for _ = 1, 60 do
		local piece = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(math.random(0, math.floor(size.X)), -20),
			Size = UDim2.fromOffset(math.random(10, 18), math.random(6, 10)),
			BackgroundColor3 = colors[math.random(1, #colors)],
			Rotation = math.random(0, 360),
			ZIndex = 30,
			Parent = root,
		})
		local fall = math.random(18, 30) / 10
		Kit.Tween(piece, fall, {
			Position = UDim2.fromOffset(piece.Position.X.Offset + math.random(-120, 120), size.Y + 30),
			Rotation = piece.Rotation + math.random(-540, 540),
		}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		Debris:AddItem(piece, fall + 0.1)
	end
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
	for index = 1, 12 do
		local ray = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(40, 480),
			BackgroundColor3 = rarity.Color,
			BackgroundTransparency = 0.3,
			Rotation = index * 15,
			ZIndex = 2,
			Parent = rays,
		})
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.05),
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
		Size = UDim2.fromOffset(210, 210),
		BackgroundColor3 = rarity.Color,
		BackgroundTransparency = 0.35,
		ZIndex = 3,
		Parent = slot.Frame,
	})
	Kit.Corner(glow, UDim.new(0.5, 0))
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.9) }),
		Rotation = 90,
		Parent = glow,
	})

	local petFrame, view = Icons.Pet(slot.Frame, result.Id, false, {
		Size = UDim2.fromOffset(250, 250),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 5,
		Animate = "Swing",
	})
	slot.View = view
	local viewScale = Kit.new("UIScale", { Scale = 0.2, Parent = petFrame })
	Kit.Tween(viewScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)

	local nameLabel = Kit.Text({
		Text = config.Name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.77),
		Size = UDim2.fromOffset(320, 42),
		MaxTextSize = 38,
		StrokeThickness = 4,
		ZIndex = 6,
		Parent = slot.Frame,
	})
	local rarityPill = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.87),
		Size = UDim2.fromOffset(220, 34),
		BackgroundColor3 = rarity.Color,
		ZIndex = 6,
		Parent = slot.Frame,
	})
	Kit.Corner(rarityPill, UDim.new(0.5, 0))
	Kit.Stroke(rarityPill, 3)
	Kit.Text({
		Text = Format.Upper(rarity.Name),
		Size = UDim2.new(1, -10, 1, -6),
		Position = UDim2.fromOffset(5, 3),
		MaxTextSize = 24,
		StrokeThickness = 2.5,
		ZIndex = 7,
		Parent = rarityPill,
	})
	if config.Rarity == "Mythic" then
		rarityPill.BackgroundColor3 = Color3.new(1, 1, 1)
		slot.Rainbow = Kit.new("UIGradient", { Color = RAINBOW, Parent = rarityPill })
	end
	Kit.Text({
		Text = Format.Multiplier(config.Multiplier) .. " к силе",
		Color = Kit.Colors.Yellow,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.96),
		Size = UDim2.fromOffset(300, 30),
		MaxTextSize = 28,
		StrokeThickness = 3,
		ZIndex = 6,
		Parent = slot.Frame,
	})
	Kit.Pop(nameLabel, 1.4)
	Kit.Pop(rarityPill, 1.6)
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
		BackgroundColor3 = Color3.fromRGB(15, 8, 35),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = gui,
	})
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 0.15) }),
		Rotation = 90,
		Parent = dim,
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
	Kit.Tween(dim, 0.25, { BackgroundTransparency = 0.2 })

	local count = #results
	local spacing = math.min(280, (root.AbsoluteSize.X / math.max(Kit.Scale, 0.01) - 40) / count)
	local slots = {}
	for index, result in ipairs(results) do
		local frame = Kit.new("Frame", {
			Name = "Slot" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, (index - (count + 1) / 2) * spacing, 0.5, 0),
			Size = UDim2.fromOffset(270, 420),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = root,
		})
		local slotScale = Kit.new("UIScale", { Scale = count > 2 and 0.9 or 1, Parent = frame })
		local eggFrame, eggView = Icons.Create(frame, "Egg", {
			Size = UDim2.fromOffset(220, 250),
			Position = UDim2.fromScale(0.5, 0.42),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = egg.Color,
			Color2 = egg.SpotColor,
			ZIndex = 5,
			Outline = 0.12,
		})
		local eggScale = Kit.new("UIScale", { Scale = 0, Parent = eggFrame })
		slots[index] = { Frame = frame, Scale = slotScale, Egg = eggFrame, EggView = eggView, EggScale = eggScale, Result = result }
		Kit.Tween(eggScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	task.wait(0.45)

	-- Тряска.
	local shakeTime = 1.7
	local started = os.clock()
	local nextTick = 0
	while not skip do
		local elapsed = os.clock() - started
		if elapsed >= shakeTime then
			break
		end
		local progress = elapsed / shakeTime
		local angle = math.sin(elapsed * (12 + progress * 34)) * (0.08 + progress * 0.3)
		local hop = math.abs(math.sin(elapsed * 9)) * progress * 0.25
		for _, slot in ipairs(slots) do
			slot.EggView:SetTransform(CFrame.new(0, hop, 0) * CFrame.Angles(0, progress * 0.6, angle))
			slot.EggScale.Scale = 1 + progress * 0.15
		end
		if elapsed >= nextTick then
			Sounds.Play("EggShake", 1 + progress * 0.6)
			nextTick = elapsed + 0.36 - progress * 0.22
		end
		RunService.RenderStepped:Wait()
	end

	-- Трещина, осколки и вспышка.
	Sounds.Play("Hatch")
	for _, slot in ipairs(slots) do
		burstShell(slot.Frame, egg)
		slot.EggView:Destroy()
	end
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
		best = math.max(best, reveal(slot))
	end
	if best >= Rarities.Legendary.Order then
		Sounds.Play("Rare")
		confetti()
	elseif best >= Rarities.Epic.Order then
		Sounds.Play("Rare", 1.2)
	else
		Sounds.Play("Reveal")
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
				ray.Rotation = index * 15 + elapsed * 22
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
