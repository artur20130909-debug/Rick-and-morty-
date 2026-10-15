--[[
	ShopPanel — магазин.
	Слева вкладки (Рюкзаки / Геймпассы) и кошелёк, справа карточки:
	- рюкзаки: 3D-рюкзак цвета уровня, вместимость с полоской, кнопка с ценой;
	  текущий подсвечен, следующий отмечен лентой «СЛЕДУЮЩИЙ» и бликом, дальние — под замком;
	- геймпасс «+2 слота питомцев»: большая карточка с короной.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Backpacks = require(Shared.Config.Backpacks)
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)

local UI = script.Parent
local Kit = require(UI.Kit)
local Icons = require(UI.Icons)
local Panels = require(UI.Panels)
local Notifications = require(UI.Notifications)
local State = require(UI.Parent.State)

local ShopPanel = {}

local MAX_CAPACITY_LOG = math.log10(Backpacks[#Backpacks].Capacity)

function ShopPanel.Create()
	local panel = Panels.Create("Shop", "МАГАЗИН", Vector2.new(800, 510), Kit.Colors.Yellow, "ShopBag")
	local content = panel.Content

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

	------------------------------------------------------------------ ВКЛАДКИ
	local tabs = Kit.new("Frame", {
		Name = "Tabs",
		BackgroundColor3 = Kit.Colors.PanelDeep,
		BackgroundTransparency = 0.3,
		Size = UDim2.new(0, 150, 1, 0),
		ZIndex = 5,
		Parent = content,
	})
	Kit.Corner(tabs, UDim.new(0, 20))

	local pages = {}
	local tabButtons = {}
	local function selectTab(name)
		for tabName, page in pairs(pages) do
			page.Visible = tabName == name
		end
		for tabName, info in pairs(tabButtons) do
			Kit.SetButtonColor(info.Gradient, tabName == name and info.Color or Kit.Colors.Grey)
		end
	end

	local tabList = {
		{ Name = "Backpacks", Text = "Рюкзаки", Icon = "Backpack", Color = Kit.Colors.Blue },
		{ Name = "Passes", Text = "Геймпассы", Icon = "Crown", Color = Kit.Colors.Purple },
	}
	for index, tab in ipairs(tabList) do
		local button, _, gradient = Kit.Button({
			Name = "Tab" .. tab.Name,
			Size = UDim2.new(1, -16, 0, 104),
			Position = UDim2.fromOffset(8, 8 + (index - 1) * 114),
			Color = tab.Color,
			Corner = UDim.new(0, 18),
			ZIndex = 6,
			Parent = tabs,
			OnClick = function()
				selectTab(tab.Name)
			end,
		})
		Icons.Create(button.Face, tab.Icon, {
			Size = UDim2.fromScale(0.62, 0.62),
			Position = UDim2.fromScale(0.5, 0.04),
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 9,
		})
		Kit.Text({ Text = tab.Text, Size = UDim2.new(1, -10, 0.28, 0), Position = UDim2.new(0, 5, 0.66, 0), MaxTextSize = 20, ZIndex = 10, Parent = button.Face })
		tabButtons[tab.Name] = { Gradient = gradient, Color = tab.Color }
	end

	-- Кошелёк.
	local wallet = Kit.new("Frame", {
		Name = "Wallet",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -16, 0, 74),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.15,
		ZIndex = 6,
		Parent = tabs,
	})
	Kit.Corner(wallet, UDim.new(0, 16))
	Kit.Text({ Text = "У тебя", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 6), MaxTextSize = 16, ZIndex = 7, Parent = wallet })
	Icons.Coin2D(wallet, { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(10, 34), ZIndex = 7 })
	local walletValue = Kit.Text({
		Text = "0",
		Color = Kit.Colors.Yellow,
		Size = UDim2.new(1, -50, 0, 30),
		Position = UDim2.fromOffset(44, 33),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 24,
		ZIndex = 7,
		Parent = wallet,
	})

	------------------------------------------------------------------ РЮКЗАКИ
	local backpacksPage = Kit.new("ScrollingFrame", {
		Name = "BackpacksPage",
		Position = UDim2.fromOffset(164, 0),
		Size = UDim2.new(1, -164, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Kit.Colors.Ink,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 5,
		Parent = content,
	})
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 10), Parent = backpacksPage })
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(180, 240),
		CellPadding = UDim2.fromOffset(12, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = backpacksPage,
	})
	pages.Backpacks = backpacksPage

	local cards = {}
	for level, backpack in ipairs(Backpacks) do
		local card = Kit.new("Frame", {
			Name = "Backpack" .. level,
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = level,
			ZIndex = 6,
			Parent = backpacksPage,
		})
		Kit.Corner(card, UDim.new(0, 20))
		local stroke = Kit.Stroke(card, 4)
		local gradient = Kit.Gradient(card, Kit.Lighten(backpack.Color, 0.55), Kit.Lighten(backpack.Color, 0.1))

		-- Номер уровня.
		local levelBadge = Kit.new("Frame", {
			Size = UDim2.fromOffset(34, 34),
			Position = UDim2.fromOffset(-8, -8),
			BackgroundColor3 = Kit.Colors.Ink,
			ZIndex = 9,
			Parent = card,
		})
		Kit.Corner(levelBadge, UDim.new(0.5, 0))
		Kit.Stroke(levelBadge, 2.5, Color3.new(1, 1, 1))
		Kit.Text({ Text = tostring(level), Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ZIndex = 10, Parent = levelBadge })

		local _, view = Icons.Create(card, "Backpack", {
			Size = UDim2.new(1, -30, 0, 104),
			Position = UDim2.fromOffset(15, 6),
			Color = backpack.Color,
			ZIndex = 7,
		})
		Kit.Text({
			Text = backpack.Name,
			Size = UDim2.new(1, -16, 0, 30),
			Position = UDim2.fromOffset(8, 110),
			MaxTextSize = 19,
			StrokeThickness = 2.5,
			ZIndex = 8,
			Parent = card,
		})
		-- Вместимость.
		local capacityBar, setCapacity = Kit.ProgressBar({
			Size = UDim2.new(1, -24, 0, 22),
			Position = UDim2.fromOffset(12, 144),
			Color = Kit.Colors.Orange,
			ZIndex = 8,
			Parent = card,
		})
		setCapacity(math.log10(backpack.Capacity) / MAX_CAPACITY_LOG, Kit.Colors.Orange)
		Kit.Text({
			Text = Format.Number(backpack.Capacity) .. " силы",
			Size = UDim2.new(1, -10, 1, 0),
			Position = UDim2.fromOffset(5, 0),
			MaxTextSize = 16,
			ZIndex = 12,
			Parent = capacityBar,
		})

		local button, label, buttonGradient = Kit.Button({
			Name = "Buy",
			Size = UDim2.new(1, -20, 0, 52),
			Position = UDim2.new(0, 10, 1, -62),
			Icon = "Coin",
			IconScale = 0.62,
			MaxTextSize = 22,
			ZIndex = 8,
			Parent = card,
			OnClick = function()
				local current = State.Get("BackpackLevel", 1)
				if level == current + 1 then
					task.spawn(buy, Remotes.BuyBackpack, level)
				elseif level > current + 1 then
					Notifications.Show("Сначала купи предыдущий рюкзак", "info")
				end
			end,
		})

		-- Лента «СЛЕДУЮЩИЙ».
		local ribbon = Kit.new("Frame", {
			Name = "Ribbon",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 8, 0, 8),
			Size = UDim2.fromOffset(104, 26),
			BackgroundColor3 = Kit.Colors.Red,
			Rotation = 12,
			Visible = false,
			ZIndex = 11,
			Parent = card,
		})
		Kit.Corner(ribbon, UDim.new(0, 8))
		Kit.Stroke(ribbon, 2.5)
		Kit.Text({ Text = "СЛЕДУЮЩИЙ", Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), MaxTextSize = 15, ZIndex = 12, Parent = ribbon })

		-- Затемнение и замок для недоступных.
		local lockOverlay = Kit.new("Frame", {
			Name = "Locked",
			BackgroundColor3 = Kit.Colors.Ink,
			BackgroundTransparency = 0.55,
			Size = UDim2.new(1, 0, 1, -68),
			Visible = false,
			ZIndex = 9,
			Parent = card,
		})
		Kit.Corner(lockOverlay, UDim.new(0, 20))
		Icons.Create(lockOverlay, "Lock", { Size = UDim2.fromOffset(70, 70), Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 10 })

		cards[level] = {
			Card = card,
			Stroke = stroke,
			Gradient = gradient,
			View = view,
			Button = button,
			Label = label,
			ButtonGradient = buttonGradient,
			Ribbon = ribbon,
			Lock = lockOverlay,
			Price = backpack.Price,
			Shimmer = nil,
		}
	end

	------------------------------------------------------------------ ГЕЙМПАССЫ
	local passesPage = Kit.new("Frame", {
		Name = "PassesPage",
		Position = UDim2.fromOffset(164, 0),
		Size = UDim2.new(1, -164, 1, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
		Parent = content,
	})
	pages.Passes = passesPage

	local passCard = Kit.new("Frame", {
		Name = "PetSlotsPass",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(6, 12),
		Size = UDim2.new(1, -12, 1, -24),
		ZIndex = 6,
		Parent = passesPage,
	})
	Kit.Corner(passCard, UDim.new(0, 26))
	Kit.Stroke(passCard, 5)
	Kit.Gradient(passCard, Color3.fromRGB(200, 150, 255), Color3.fromRGB(110, 60, 220))
	Kit.Dots(passCard, Color3.new(1, 1, 1), 0.85, 56, 6).Size = UDim2.new(1, -24, 1, -24)
	Kit.Shimmer(passCard, 3, 7)

	Icons.Create(passCard, "Crown", {
		Size = UDim2.fromOffset(190, 170),
		Position = UDim2.fromOffset(20, 30),
		ZIndex = 8,
		Animate = "Spin",
		Speed = 0.8,
	})
	Icons.Create(passCard, "Paw", {
		Size = UDim2.fromOffset(90, 90),
		Position = UDim2.fromOffset(150, 150),
		ZIndex = 9,
		Animate = "Bob",
	})
	Kit.Text({
		Text = "+2 СЛОТА ДЛЯ ПИТОМЦЕВ",
		Color = Kit.Colors.Yellow,
		Size = UDim2.new(1, -270, 0, 64),
		Position = UDim2.fromOffset(250, 30),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 34,
		StrokeThickness = 3.5,
		ZIndex = 8,
		Parent = passCard,
	})
	Kit.Text({
		Text = "Надевай " .. GameConfig.GamepassEquipSlots .. " питомцев вместо " .. GameConfig.BaseEquipSlots .. " — больше силы за каждый клик!",
		Size = UDim2.new(1, -270, 0, 70),
		Position = UDim2.fromOffset(250, 100),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		ZIndex = 8,
		Parent = passCard,
	})
	if GameConfig.PetSlotsGamepassId == 0 then
		Kit.Text({
			Text = "Тестовый режим: выдаётся бесплатно",
			Color = Color3.fromRGB(230, 220, 255),
			Font = Kit.FontBold,
			Size = UDim2.new(1, -270, 0, 26),
			Position = UDim2.fromOffset(250, 176),
			XAlign = Enum.TextXAlignment.Left,
			MaxTextSize = 17,
			ZIndex = 8,
			Parent = passCard,
		})
	end
	local _, passLabel, passGradient = Kit.Button({
		Name = "BuyPass",
		Size = UDim2.new(1, -60, 0, 70),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Color = Kit.Colors.Yellow,
		Icon = "Crown",
		MaxTextSize = 32,
		Depth = 7,
		ZIndex = 9,
		Parent = passCard,
		OnClick = function()
			if State.Get("PetSlotsPass", false) then
				Notifications.Show("Уже куплено", "info")
			else
				task.spawn(buy, Remotes.BuyPetSlots)
			end
		end,
	})

	------------------------------------------------------------------ ОБНОВЛЕНИЕ
	local function refresh()
		local current = State.Get("BackpackLevel", 1)
		local coins = State.Get("Coins", 0)
		walletValue.Text = Format.Number(coins)
		for level, card in pairs(cards) do
			local isNext = level == current + 1
			card.Ribbon.Visible = isNext
			card.Lock.Visible = level > current + 1
			card.Stroke.Color = level == current and Kit.Colors.Blue or (isNext and Kit.Colors.YellowDark or Kit.Colors.Ink)
			card.Stroke.Thickness = (level == current or isNext) and 6 or 4
			card.View.Animate = isNext and "Swing" or nil
			if isNext and not card.Shimmer then
				card.Shimmer = Kit.Shimmer(card.Card, 2.2, 7)
			elseif not isNext and card.Shimmer then
				card.Shimmer:Destroy()
				card.Shimmer = nil
			end
			Kit.SetButtonIcon(card.Button, level > current)
			if level < current then
				card.Label.Text = "КУПЛЕНО"
				Kit.SetButtonColor(card.ButtonGradient, Kit.Colors.Grey)
			elseif level == current then
				card.Label.Text = "НАДЕТ"
				Kit.SetButtonColor(card.ButtonGradient, Kit.Colors.Blue)
			elseif isNext then
				card.Label.Text = Format.Number(card.Price)
				Kit.SetButtonColor(card.ButtonGradient, coins >= card.Price and Kit.Colors.Green or Kit.Colors.Orange)
			else
				card.Label.Text = Format.Number(card.Price)
				Kit.SetButtonColor(card.ButtonGradient, Kit.Colors.Grey)
			end
		end

		if State.Get("PetSlotsPass", false) then
			passLabel.Text = "УЖЕ ТВОЁ"
			Kit.SetButtonColor(passGradient, Kit.Colors.Grey)
		else
			passLabel.Text = GameConfig.PetSlotsGamepassId == 0 and "ПОЛУЧИТЬ" or "КУПИТЬ"
			Kit.SetButtonColor(passGradient, Kit.Colors.Yellow)
		end
	end

	State.Watch({ "BackpackLevel", "Coins", "PetSlotsPass" }, refresh)
	selectTab("Backpacks")
	panel.OnOpen = function()
		-- Прокрутить к следующему рюкзаку.
		local current = State.Get("BackpackLevel", 1)
		local row = math.floor(math.max(0, current - 1) / 3)
		backpacksPage.CanvasPosition = Vector2.new(0, row * 256)
	end
end

return ShopPanel
