--[[
	ShopPanel — магазин: рюкзаки (по порядку, за монеты) и геймпасс «+2 слота питомцев».
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Backpacks = require(Shared.Config.Backpacks)
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)

local UI = script.Parent
local Kit = require(UI.Kit)
local Panels = require(UI.Panels)
local Notifications = require(UI.Notifications)
local State = require(UI.Parent.State)

local ShopPanel = {}

local function sectionTitle(parent, text, order)
	return Kit.Text({
		Text = text,
		Size = UDim2.new(1, -12, 0, 34),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 26,
		StrokeThickness = 2.5,
		LayoutOrder = order,
		ZIndex = 4,
		Parent = parent,
	})
end

local function makeRow(parent, order, icon, title, subtitle)
	local row = Kit.new("Frame", {
		Size = UDim2.new(1, -14, 0, 68),
		BackgroundColor3 = Kit.Colors.White,
		LayoutOrder = order,
		ZIndex = 4,
		Parent = parent,
	})
	Kit.Corner(row, UDim.new(0, 16))
	Kit.Stroke(row, 3)
	Kit.Text({
		Text = icon,
		Stroke = false,
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 5,
		Parent = row,
	})
	local titleLabel = Kit.Text({
		Text = title,
		Color = Kit.Colors.Ink,
		Stroke = false,
		Size = UDim2.new(1, -260, 0, 28),
		Position = UDim2.fromOffset(68, 7),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		ZIndex = 5,
		Parent = row,
	})
	local subtitleLabel = Kit.Text({
		Text = subtitle,
		Color = Kit.Colors.GreyDark,
		Stroke = false,
		Font = Kit.FontBold,
		Size = UDim2.new(1, -260, 0, 22),
		Position = UDim2.fromOffset(68, 37),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		ZIndex = 5,
		Parent = row,
	})
	return row, titleLabel, subtitleLabel
end

function ShopPanel.Create()
	local panel = Panels.Create("Shop", "🛒 МАГАЗИН", Vector2.new(640, 480), Kit.Colors.Yellow)

	local list = Kit.new("ScrollingFrame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Kit.Colors.Ink,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3,
		Parent = panel.Content,
	})
	Kit.new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = list,
	})
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), Parent = list })

	local busy = false
	local function buy(remote, ...)
		if busy then
			return
		end
		busy = true
		local ok, message = State.Invoke(remote, ...)
		busy = false
		if message then
			Notifications.Show(message, ok and "success" or "error")
		end
	end

	------------------------------------------------------------------ РЮКЗАКИ
	sectionTitle(list, "🎒 РЮКЗАКИ — сколько силы помещается", 1)
	local rows = {}
	for level, backpack in ipairs(Backpacks) do
		local row = makeRow(list, 10 + level, backpack.Icon, backpack.Name, "Вместимость: " .. Format.Number(backpack.Capacity) .. " силы")
		local button, label, gradient = Kit.Button({
			Size = UDim2.fromOffset(176, 48),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			MaxTextSize = 22,
			ZIndex = 5,
			Parent = row,
			OnClick = function()
				local current = State.Get("BackpackLevel", 1)
				if level == current + 1 then
					task.spawn(buy, Remotes.BuyBackpack, level)
				elseif level > current + 1 then
					Notifications.Show("Сначала купи предыдущий рюкзак", "info")
				end
			end,
		})
		rows[level] = { Button = button, Label = label, Gradient = gradient, Price = backpack.Price }
	end

	------------------------------------------------------------------ ГЕЙМПАСС
	sectionTitle(list, "⭐ ГЕЙМПАССЫ", 100)
	local passSubtitle = GameConfig.PetSlotsGamepassId == 0 and "Тестовый режим: выдаётся бесплатно"
		or ("Надевай " .. GameConfig.GamepassEquipSlots .. " питомцев вместо " .. GameConfig.BaseEquipSlots)
	local passRow = makeRow(list, 101, "🐾", "+2 слота питомцев", passSubtitle)
	local _, passLabel, passGradient = Kit.Button({
		Size = UDim2.fromOffset(176, 48),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		MaxTextSize = 22,
		ZIndex = 5,
		Parent = passRow,
		OnClick = function()
			if State.Get("PetSlotsPass", false) then
				Notifications.Show("Уже куплено ✔", "info")
			else
				task.spawn(buy, Remotes.BuyPetSlots)
			end
		end,
	})

	------------------------------------------------------------------ ОБНОВЛЕНИЕ
	local function refresh()
		local current = State.Get("BackpackLevel", 1)
		local coins = State.Get("Coins", 0)
		for level, row in pairs(rows) do
			if level < current then
				row.Label.Text = "✔ Было"
				Kit.SetButtonColor(row.Gradient, Kit.Colors.Grey)
			elseif level == current then
				row.Label.Text = "🎒 Надет"
				Kit.SetButtonColor(row.Gradient, Kit.Colors.Blue)
			elseif level == current + 1 then
				row.Label.Text = "🪙 " .. Format.Number(row.Price)
				Kit.SetButtonColor(row.Gradient, coins >= row.Price and Kit.Colors.Green or Kit.Colors.Orange)
			else
				row.Label.Text = "🔒 " .. Format.Number(row.Price)
				Kit.SetButtonColor(row.Gradient, Kit.Colors.Grey)
			end
		end

		if State.Get("PetSlotsPass", false) then
			passLabel.Text = "✔ Куплено"
			Kit.SetButtonColor(passGradient, Kit.Colors.Grey)
		else
			passLabel.Text = GameConfig.PetSlotsGamepassId == 0 and "🎁 Получить" or "💎 Купить"
			Kit.SetButtonColor(passGradient, Kit.Colors.Purple)
		end
	end

	State.Watch({ "BackpackLevel", "Coins", "PetSlotsPass" }, refresh)
end

return ShopPanel
