--[[
	Hud — постоянный интерфейс:
	- счётчики сверху: сила в рюкзаке (с полоской), монеты, накопленная сила, перерождения;
	- плашка текущего мира;
	- кнопки сбоку: Питомцы, Магазин, Перерождение, Миры;
	- большая кнопка «КЛИК!» внизу по центру (удобно большим пальцем на телефоне);
	- кнопка музыки.
	Все иконки — свои 3D-модели (UI/IconModels), без эмодзи.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local Backpacks = require(Shared.Config.Backpacks)
local Formulas = require(Shared.Modules.Formulas)
local Format = require(Shared.Modules.Format)

local UI = script.Parent
local Kit = require(UI.Kit)
local Icons = require(UI.Icons)
local Panels = require(UI.Panels)
local State = require(UI.Parent.State)
local Sounds = require(UI.Parent.Sounds)

local Hud = {}

local WORLD_ICONS = { Forest = "Tree", Desert = "Cactus", Space = "Rocket" }

local function makePill(parent, order, width, iconName, caption, color, iconColor)
	local frame = Kit.new("Frame", {
		Name = caption,
		Size = UDim2.fromOffset(width, 56),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	local body = Kit.new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, -18, 1, -8),
		Position = UDim2.fromOffset(18, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = frame,
	})
	Kit.Corner(body, UDim.new(0.5, 0))
	Kit.Stroke(body, 3.5)
	Kit.Gradient(body, Kit.Lighten(color, 0.1), Kit.Darken(color, 0.25))
	local gloss = Kit.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.72,
		Size = UDim2.new(1, -40, 0.38, 0),
		Position = UDim2.new(0, 30, 0, 3),
		Parent = body,
	})
	Kit.Corner(gloss, UDim.new(0.5, 0))

	-- Круглая подложка с 3D-иконкой, выступает влево за край плашки.
	local badge = Kit.new("Frame", {
		Name = "Badge",
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = frame,
	})
	Kit.Corner(badge, UDim.new(0.5, 0))
	Kit.Stroke(badge, 3.5)
	Kit.Gradient(badge, Color3.fromRGB(255, 255, 255), Kit.Lighten(color, 0.45))
	Icons.Create(badge, iconName, {
		Size = UDim2.fromScale(1.15, 1.15),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 4,
		Color = iconColor,
	})

	Kit.Text({
		Name = "Caption",
		Text = caption,
		Size = UDim2.new(1, -56, 0, 15),
		Position = UDim2.fromOffset(44, 4),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 13,
		StrokeThickness = 1.5,
		Parent = body,
	})
	local value = Kit.Text({
		Name = "Value",
		Text = "0",
		Size = UDim2.new(1, -56, 0, 28),
		Position = UDim2.fromOffset(44, 18),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 27,
		StrokeThickness = 2.5,
		Parent = body,
	})
	return frame, value, body
end

-- Прозрачная кнопка поверх элемента (например, нажать на счётчик и открыть окно).
local function makeClickable(guiObject, callback)
	local button = Kit.new("TextButton", {
		Name = "Hit",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Parent = guiObject,
	})
	button.Activated:Connect(function()
		Sounds.Play("Button")
		callback()
	end)
	return button
end

function Hud.Create(root)
	local hud = { MenuButtons = {}, Badges = {} }

	------------------------------------------------------------------ СЧЁТЧИКИ
	local top = Kit.new("Frame", {
		Name = "TopBar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(880, 60),
		Parent = root,
	})
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = top,
	})

	local strengthPill, strengthValue, strengthBody = makePill(top, 1, 300, "Dumbbell", "СИЛА В РЮКЗАКЕ", Kit.Colors.Orange)
	local bar, setBar = Kit.ProgressBar({
		Size = UDim2.new(1, -56, 0, 24),
		Position = UDim2.fromOffset(44, 21),
		Color = Kit.Colors.Green,
		ZIndex = 2,
		Parent = strengthBody,
	})
	strengthValue.Parent = bar
	strengthValue.Size = UDim2.new(1, -8, 1, 0)
	strengthValue.Position = UDim2.fromOffset(4, 0)
	strengthValue.TextXAlignment = Enum.TextXAlignment.Center
	strengthValue.ZIndex = 5
	makeClickable(strengthPill, function()
		Panels.Open("Shop")
	end)

	local _, coinsValue = makePill(top, 2, 190, "Coin", "МОНЕТЫ", Kit.Colors.Yellow)
	local _, totalValue = makePill(top, 3, 190, "Star", "ВСЕГО СИЛЫ", Kit.Colors.Purple)
	local rebirthPill, rebirthValue = makePill(top, 4, 150, "Rebirth", "ПЕРЕРОЖД.", Kit.Colors.Blue, Color3.fromRGB(150, 110, 255))
	makeClickable(rebirthPill, function()
		Panels.Open("Rebirth")
	end)

	-- Плашка мира.
	local worldChip = Kit.new("Frame", {
		Name = "WorldChip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 72),
		Size = UDim2.fromOffset(340, 36),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.25,
		Parent = root,
	})
	Kit.Corner(worldChip, UDim.new(0.5, 0))
	Kit.Stroke(worldChip, 2.5, Color3.fromRGB(255, 255, 255)).Transparency = 0.6
	local worldIconHolder = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(0, -6, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 3,
		Parent = worldChip,
	})
	local worldLabel = Kit.Text({
		Text = "",
		Size = UDim2.new(1, -56, 1, -8),
		Position = UDim2.fromOffset(44, 4),
		MaxTextSize = 21,
		Parent = worldChip,
	})
	makeClickable(worldChip, function()
		Panels.Open("Worlds")
	end)

	------------------------------------------------------------------ БОКОВОЕ МЕНЮ
	local side = Kit.new("Frame", {
		Name = "SideMenu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 26),
		Size = UDim2.fromOffset(100, 4 * 90 + 3 * 10),
		Parent = root,
	})
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = side,
	})
	local menu = {
		{ Name = "Pets", Icon = "Paw", Text = "Питомцы", Color = Kit.Colors.Green },
		{ Name = "Shop", Icon = "ShopBag", Text = "Магазин", Color = Kit.Colors.Yellow },
		{ Name = "Rebirth", Icon = "Rebirth", Text = "Перерожд.", Color = Kit.Colors.Purple, IconColor = Color3.fromRGB(255, 255, 255) },
		{ Name = "Worlds", Icon = "Globe", Text = "Миры", Color = Kit.Colors.Blue },
	}
	for index, item in ipairs(menu) do
		local button = Kit.Button({
			Name = item.Name,
			Size = UDim2.fromOffset(100, 90),
			Color = item.Color,
			Corner = UDim.new(0, 24),
			StrokeThickness = 3.5,
			Depth = 6,
			LayoutOrder = index,
			Parent = side,
			OnClick = function()
				Panels.Toggle(item.Name)
			end,
		})
		Icons.Create(button.Face, item.Icon, {
			Size = UDim2.new(0.86, 0, 0.7, 0),
			Position = UDim2.fromScale(0.5, 0.02),
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 5,
			Color = item.IconColor,
			Animate = "Swing",
		})
		Kit.Text({
			Text = item.Text,
			Size = UDim2.new(1, -8, 0.26, 0),
			Position = UDim2.new(0, 4, 0.7, 0),
			MaxTextSize = 16,
			ZIndex = 6,
			Parent = button.Face,
		})
		-- Красный кружок «!» — когда есть что сделать.
		local badge = Kit.new("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = Kit.Colors.Red,
			Visible = false,
			ZIndex = 9,
			Parent = button,
		})
		Kit.Corner(badge, UDim.new(0.5, 0))
		Kit.Stroke(badge, 2.5)
		Kit.Text({ Text = "!", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ZIndex = 10, Parent = badge })
		local badgeScale = Kit.new("UIScale", { Parent = badge })
		TweenService:Create(badgeScale, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.2 }):Play()
		hud.MenuButtons[item.Name] = button
		hud.Badges[item.Name] = badge
	end

	------------------------------------------------------------------ МУЗЫКА
	local musicButton = Kit.Button({
		Name = "Music",
		Size = UDim2.fromOffset(58, 62),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 72),
		Color = Kit.Colors.Teal,
		Corner = UDim.new(0.5, 0),
		Parent = root,
	})
	Icons.Create(musicButton.Face, "Note", { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.08), ZIndex = 5, Color = Color3.fromRGB(255, 255, 255) })
	local musicOff = Icons.Glyph(musicButton.Face, "Close", { Size = UDim2.fromScale(0.55, 0.55), ZIndex = 7, Color = Kit.Colors.Red })
	musicOff.Visible = not Sounds.IsMusicEnabled()
	musicButton.Activated:Connect(function()
		local enabled = Sounds.ToggleMusic()
		musicOff.Visible = not enabled
	end)

	------------------------------------------------------------------ КНОПКА КЛИКА
	local ring = Kit.new("Frame", {
		Name = "ClickRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = Kit.Colors.Yellow,
		BackgroundTransparency = 0.35,
		ZIndex = 0,
		Parent = root,
	})
	Kit.Corner(ring, UDim.new(0.5, 0))
	TweenService:Create(ring, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1), {
		Size = UDim2.fromOffset(196, 196),
		BackgroundTransparency = 1,
	}):Play()

	local clickButton = Kit.Button({
		Name = "ClickButton",
		Size = UDim2.fromOffset(156, 162),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Color = Kit.Colors.Yellow,
		Color2 = Kit.Colors.OrangeDark,
		Corner = UDim.new(0.5, 0),
		StrokeThickness = 5,
		Depth = 8,
		Sound = false,
		Parent = root,
	})
	local clickIconHolder = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.78, 0.62),
		Position = UDim2.fromScale(0.5, 0.38),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 5,
		Parent = clickButton.Face,
	})
	Icons.Create(clickIconHolder, "Dumbbell", { Size = UDim2.fromScale(1, 1), ZIndex = 5, Animate = "Bob" })
	Kit.Text({
		Text = "КЛИК!",
		Size = UDim2.fromScale(0.72, 0.22),
		Position = UDim2.fromScale(0.5, 0.78),
		AnchorPoint = Vector2.new(0.5, 0.5),
		MaxTextSize = 34,
		StrokeThickness = 3.5,
		ZIndex = 6,
		Parent = clickButton.Face,
	})

	local powerLabel = Kit.Text({
		Name = "PowerLabel",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -178),
		Size = UDim2.fromOffset(360, 28),
		MaxTextSize = 24,
		StrokeThickness = 3,
		Parent = root,
	})

	local fullLabel = Kit.Text({
		Name = "FullWarning",
		Text = "Рюкзак полон! Беги на продажу",
		Color = Color3.fromRGB(255, 130, 130),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -208),
		Size = UDim2.fromOffset(520, 38),
		MaxTextSize = 32,
		StrokeThickness = 3.5,
		Visible = false,
		Parent = root,
	})

	------------------------------------------------------------------ ОБНОВЛЕНИЕ
	local lastCoins, lastTotal = nil, nil

	State.Watch({ "Strength", "Capacity" }, function()
		local strength, capacity = State.Get("Strength", 0), State.Get("Capacity", 50)
		strengthValue.Text = Format.Number(strength) .. " / " .. Format.Number(capacity)
		local fraction = capacity > 0 and strength / capacity or 0
		local color = Kit.Colors.Green
		if fraction >= 1 then
			color = Kit.Colors.Red
		elseif fraction >= 0.75 then
			color = Kit.Colors.Orange
		end
		setBar(fraction, color)
		fullLabel.Visible = fraction >= 1
	end)

	State.Watch("Coins", function()
		local coins = State.Get("Coins", 0)
		coinsValue.Text = Format.Number(coins)
		if lastCoins and coins > lastCoins then
			Kit.Pop(coinsValue, 1.25)
		end
		lastCoins = coins
	end)

	State.Watch("TotalStrength", function()
		local total = State.Get("TotalStrength", 0)
		totalValue.Text = Format.Number(total)
		if lastTotal and total > lastTotal then
			Kit.Pop(totalValue, 1.12)
		end
		lastTotal = total
	end)

	State.Watch("Rebirths", function()
		rebirthValue.Text = Format.Number(State.Get("Rebirths", 0))
	end)

	State.Watch({ "ClickPower" }, function()
		powerLabel.Text = "+" .. Format.Number(State.Get("ClickPower", 1)) .. " силы за клик"
	end)

	local shownWorldIcon = nil
	State.Watch("World", function()
		local worldId = State.Get("World", "Forest")
		local world = Worlds[worldId] or Worlds.Forest
		worldLabel.Text = string.format("%s  •  продажа ×%s", Format.Upper(world.Name), Format.Number(world.SellMultiplier))
		worldLabel.TextColor3 = Kit.Lighten(world.Color, 0.35)
		if shownWorldIcon ~= worldId then
			shownWorldIcon = worldId
			worldIconHolder:ClearAllChildren()
			Icons.Create(worldIconHolder, WORLD_ICONS[worldId] or "Globe", { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
		end
	end)

	-- Значки «!» на кнопках.
	State.Watch({ "TotalStrength", "Rebirths" }, function()
		hud.Badges.Rebirth.Visible = State.Get("TotalStrength", 0) >= Formulas.RebirthCost(State.Get("Rebirths", 0))
	end)
	State.Watch({ "TotalStrength", "UnlockedWorlds" }, function()
		local unlocked = State.UnlockedWorlds()
		local canUnlock = false
		for _, worldId in ipairs(Worlds.Order) do
			if not unlocked[worldId] then
				canUnlock = State.Get("TotalStrength", 0) >= Worlds[worldId].UnlockStrength
				break
			end
		end
		hud.Badges.Worlds.Visible = canUnlock
	end)
	State.Watch({ "Coins", "BackpackLevel" }, function()
		local nextBackpack = Backpacks[State.Get("BackpackLevel", 1) + 1]
		hud.Badges.Shop.Visible = nextBackpack ~= nil and State.Get("Coins", 0) >= nextBackpack.Price
	end)

	------------------------------------------------------------------ API
	hud.ClickButton = clickButton

	function hud.Punch()
		Kit.Pop(clickIconHolder, 1.2)
	end

	function hud.FlashFull()
		fullLabel.Visible = true
		Kit.Pop(fullLabel, 1.2)
		Kit.Pop(bar, 1.12)
	end

	return hud
end

return Hud
