--[[
	Hud — постоянный интерфейс:
	- счётчики сверху: сила в рюкзаке (с полоской), монеты, накопленная сила, перерождения;
	- плашка текущего мира;
	- кнопки сбоку: Питомцы, Магазин, Перерождение, Миры;
	- большая кнопка «КЛИК!» внизу по центру (удобно большим пальцем на телефоне).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local Backpacks = require(Shared.Config.Backpacks)
local Formulas = require(Shared.Modules.Formulas)
local Format = require(Shared.Modules.Format)

local UI = script.Parent
local Kit = require(UI.Kit)
local Panels = require(UI.Panels)
local State = require(UI.Parent.State)

local Hud = {}

local function makePill(parent, order, width, icon, caption, color)
	local frame = Kit.new("Frame", {
		Name = caption,
		Size = UDim2.fromOffset(width, 58),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.Corner(frame, UDim.new(0.5, 0))
	Kit.Stroke(frame, 3)
	Kit.Gradient(frame, color, Kit.Darken(color, 0.25))

	local iconBg = Kit.new("Frame", {
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(0, 5, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.35,
		Parent = frame,
	})
	Kit.Corner(iconBg, UDim.new(0.5, 0))
	Kit.Text({
		Text = icon,
		Stroke = false,
		Size = UDim2.fromScale(0.78, 0.78),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = iconBg,
	})
	Kit.Text({
		Name = "Caption",
		Text = caption,
		Size = UDim2.new(1, -72, 0, 16),
		Position = UDim2.fromOffset(58, 4),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 14,
		StrokeThickness = 1.5,
		Parent = frame,
	})
	local value = Kit.Text({
		Name = "Value",
		Text = "0",
		Size = UDim2.new(1, -72, 0, 32),
		Position = UDim2.fromOffset(58, 20),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 28,
		StrokeThickness = 2.5,
		Parent = frame,
	})
	return frame, value
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
	button.Activated:Connect(callback)
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
		Size = UDim2.fromOffset(860, 62),
		Parent = root,
	})
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = top,
	})

	local strengthPill, strengthValue = makePill(top, 1, 290, "💪", "СИЛА В РЮКЗАКЕ", Kit.Colors.Orange)
	local bar, setBar = Kit.ProgressBar({
		Size = UDim2.new(1, -72, 0, 26),
		Position = UDim2.fromOffset(58, 24),
		Color = Kit.Colors.Green,
		ZIndex = 2,
		Parent = strengthPill,
	})
	strengthValue.Parent = bar
	strengthValue.Size = UDim2.new(1, -8, 1, 0)
	strengthValue.Position = UDim2.fromOffset(4, 0)
	strengthValue.TextXAlignment = Enum.TextXAlignment.Center
	strengthValue.ZIndex = 4
	makeClickable(strengthPill, function()
		Panels.Open("Shop")
	end)

	local _, coinsValue = makePill(top, 2, 190, "🪙", "МОНЕТЫ", Kit.Colors.Yellow)
	local _, totalValue = makePill(top, 3, 190, "⭐", "ВСЕГО СИЛЫ", Kit.Colors.Purple)
	local rebirthPill, rebirthValue = makePill(top, 4, 150, "🔁", "ПЕРЕРОЖД.", Kit.Colors.Blue)
	makeClickable(rebirthPill, function()
		Panels.Open("Rebirth")
	end)

	-- Плашка мира.
	local worldChip = Kit.new("Frame", {
		Name = "WorldChip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(330, 32),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.35,
		Parent = root,
	})
	Kit.Corner(worldChip, UDim.new(0.5, 0))
	local worldLabel = Kit.Text({
		Text = "",
		Size = UDim2.new(1, -16, 1, -6),
		Position = UDim2.fromOffset(8, 3),
		MaxTextSize = 22,
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
		Position = UDim2.new(0, 12, 0.5, 24),
		Size = UDim2.fromOffset(96, 4 * 86 + 3 * 10),
		Parent = root,
	})
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = side,
	})
	local menu = {
		{ Name = "Pets", Icon = "🐾", Text = "Питомцы", Color = Kit.Colors.Green },
		{ Name = "Shop", Icon = "🛒", Text = "Магазин", Color = Kit.Colors.Yellow },
		{ Name = "Rebirth", Icon = "🔁", Text = "Перерождение", Color = Kit.Colors.Purple },
		{ Name = "Worlds", Icon = "🌍", Text = "Миры", Color = Kit.Colors.Blue },
	}
	for index, item in ipairs(menu) do
		local button = Kit.Button({
			Name = item.Name,
			Size = UDim2.fromOffset(96, 86),
			Color = item.Color,
			Corner = UDim.new(0, 22),
			LayoutOrder = index,
			Parent = side,
			OnClick = function()
				Panels.Toggle(item.Name)
			end,
		})
		Kit.Text({
			Text = item.Icon,
			Stroke = false,
			Size = UDim2.new(1, 0, 0.56, 0),
			Position = UDim2.fromScale(0, 0.06),
			ZIndex = 3,
			Parent = button,
		})
		Kit.Text({
			Text = item.Text,
			Size = UDim2.new(1, -8, 0.26, 0),
			Position = UDim2.new(0, 4, 0.66, 0),
			MaxTextSize = 17,
			ZIndex = 3,
			Parent = button,
		})
		-- Красный кружок «!» — когда есть что сделать.
		local badge = Kit.new("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = Kit.Colors.Red,
			Visible = false,
			ZIndex = 6,
			Parent = button,
		})
		Kit.Corner(badge, UDim.new(0.5, 0))
		Kit.Stroke(badge, 2)
		Kit.Text({ Text = "!", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ZIndex = 7, Parent = badge })
		hud.MenuButtons[item.Name] = button
		hud.Badges[item.Name] = badge
	end

	------------------------------------------------------------------ КНОПКА КЛИКА
	local ring = Kit.new("Frame", {
		Name = "ClickRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -87),
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = Kit.Colors.Yellow,
		BackgroundTransparency = 0.4,
		ZIndex = 0,
		Parent = root,
	})
	Kit.Corner(ring, UDim.new(0.5, 0))
	Kit.new("UIScale", { Parent = ring })
	local ringTweenInfo = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1)
	game:GetService("TweenService"):Create(ring, ringTweenInfo, { Size = UDim2.fromOffset(190, 190), BackgroundTransparency = 1 }):Play()

	local clickButton = Kit.Button({
		Name = "ClickButton",
		Size = UDim2.fromOffset(150, 150),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Color = Kit.Colors.Yellow,
		Color2 = Kit.Colors.Orange,
		Corner = UDim.new(0.5, 0),
		StrokeThickness = 5,
		Sound = false,
		Parent = root,
	})
	local clickIcon = Kit.Text({
		Text = "💪",
		Stroke = false,
		Size = UDim2.fromScale(0.56, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 3,
		Parent = clickButton,
	})
	Kit.Text({
		Text = "КЛИК!",
		Size = UDim2.fromScale(0.72, 0.22),
		Position = UDim2.fromScale(0.5, 0.78),
		AnchorPoint = Vector2.new(0.5, 0.5),
		MaxTextSize = 32,
		StrokeThickness = 3,
		ZIndex = 3,
		Parent = clickButton,
	})

	local powerLabel = Kit.Text({
		Name = "PowerLabel",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.fromOffset(340, 28),
		MaxTextSize = 24,
		Parent = root,
	})

	local fullLabel = Kit.Text({
		Name = "FullWarning",
		Text = "🎒 Рюкзак полон! Беги на 💰 продажу",
		Color = Color3.fromRGB(255, 120, 120),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -200),
		Size = UDim2.fromOffset(520, 36),
		MaxTextSize = 30,
		StrokeThickness = 3,
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

	State.Watch("World", function()
		local world = Worlds[State.Get("World", "Forest")] or Worlds.Forest
		worldLabel.Text = string.format("%s %s  •  продажа ×%s", world.Icon, Format.Upper(world.Name), Format.Number(world.SellMultiplier))
		worldLabel.TextColor3 = Kit.Lighten(world.Color, 0.35)
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
		Kit.Pop(clickIcon, 1.25)
	end

	function hud.FlashFull()
		fullLabel.Visible = true
		Kit.Pop(fullLabel, 1.2)
		Kit.Pop(bar, 1.12)
	end

	return hud
end

return Hud
