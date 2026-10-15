--[[
	PetsPanel — инвентарь питомцев.
	Слева сетка карточек с 3D-портретами питомцев (рисуются только видимые — так быстрее),
	справа большое 3D-превью выбранного и кнопки: Экипировать / Снять, В золото (5 одинаковых → 1 золотой),
	Удалить (с подтверждением). В шапке — «Экипировать лучших».
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Pets = require(Shared.Config.Pets)
local Rarities = require(Shared.Config.Rarities)
local Formulas = require(Shared.Modules.Formulas)
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)

local UI = script.Parent
local Kit = require(UI.Kit)
local Icons = require(UI.Icons)
local Panels = require(UI.Panels)
local Notifications = require(UI.Notifications)
local State = require(UI.Parent.State)
local Sounds = require(UI.Parent.Sounds)

local PetsPanel = {}

local selectedUid = nil
local selectFromOutside = nil

local CARD_SIZE = Vector2.new(92, 112)
local MAX_VIEWS = 45

function PetsPanel.Select(uid)
	selectedUid = uid
	if selectFromOutside then
		selectFromOutside()
	end
end

function PetsPanel.Create()
	local panel = Panels.Create("Pets", "ПИТОМЦЫ", Vector2.new(860, 510), Kit.Colors.Green, "Paw")
	local content = panel.Content

	local busy = false
	local function act(action, uid, quietSuccess)
		if busy then
			return false
		end
		busy = true
		local ok, message = State.Invoke(Remotes.PetAction, action, uid)
		busy = false
		if message and (not ok or not quietSuccess) then
			Notifications.Show(message, ok and "success" or "error")
		end
		return ok
	end

	Kit.Button({
		Name = "EquipBest",
		Text = "Экипировать лучших",
		Size = UDim2.fromOffset(270, 50),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -54, 0.5, 0),
		Color = Kit.Colors.Yellow,
		Icon = "Star",
		MaxTextSize = 20,
		ZIndex = 9,
		Parent = panel.Header,
		OnClick = function()
			task.spawn(act, "EquipBest", nil, false)
		end,
	})

	------------------------------------------------------------------ ИНФО-ПОЛОСА
	local infoBar = Kit.new("Frame", {
		Name = "InfoBar",
		Size = UDim2.new(1, -306, 0, 38),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.1,
		ZIndex = 6,
		Parent = content,
	})
	Kit.Corner(infoBar, UDim.new(0.5, 0))
	local countLabel = Kit.Text({
		Text = "",
		Size = UDim2.new(0.34, 0, 1, -8),
		Position = UDim2.new(0, 14, 0, 4),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 19,
		ZIndex = 7,
		Parent = infoBar,
	})
	local slotsHolder = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.34, 0, 1, -12),
		Position = UDim2.new(0.34, 0, 0, 6),
		ZIndex = 7,
		Parent = infoBar,
	})
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 5),
		Parent = slotsHolder,
	})
	local bonusLabel = Kit.Text({
		Text = "",
		Color = Kit.Colors.Yellow,
		Size = UDim2.new(0.3, -12, 1, -8),
		Position = UDim2.new(0.7, 0, 0, 4),
		XAlign = Enum.TextXAlignment.Right,
		MaxTextSize = 19,
		ZIndex = 7,
		Parent = infoBar,
	})

	------------------------------------------------------------------ СЕТКА
	local grid = Kit.new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, -306, 1, -46),
		BackgroundColor3 = Kit.Colors.PanelDeep,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Kit.Colors.Ink,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 5,
		Parent = content,
	})
	Kit.Corner(grid, UDim.new(0, 18))
	Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 14),
		Parent = grid,
	})
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local empty = Kit.new("Frame", {
		Name = "Empty",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -306, 1, -46),
		Position = UDim2.fromOffset(0, 46),
		Visible = false,
		ZIndex = 7,
		Parent = content,
	})
	Icons.Create(empty, "Egg", { Size = UDim2.fromOffset(120, 120), Position = UDim2.new(0.5, 0, 0.32, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8, Animate = "Swing" })
	Kit.Text({
		Text = "Пока пусто! Подойди к яйцу и открой его за монеты",
		Color = Kit.Colors.GreyDark,
		Stroke = false,
		Size = UDim2.new(1, -40, 0, 60),
		Position = UDim2.new(0, 20, 0.58, 0),
		MaxTextSize = 24,
		ZIndex = 8,
		Parent = empty,
	})

	------------------------------------------------------------------ ПРАВАЯ ЧАСТЬ
	local details = Kit.new("Frame", {
		Name = "Details",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 294, 1, 0),
		BackgroundColor3 = Kit.Colors.PanelDeep,
		BackgroundTransparency = 0.35,
		ZIndex = 5,
		Parent = content,
	})
	Kit.Corner(details, UDim.new(0, 20))

	local stage = Kit.new("Frame", {
		Name = "Stage",
		Size = UDim2.new(1, -16, 0, 150),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 6,
		Parent = details,
	})
	Kit.Corner(stage, UDim.new(0, 16))
	Kit.Stroke(stage, 3)
	local stageGradient = Kit.Gradient(stage, Color3.new(1, 1, 1), Color3.new(0.8, 0.8, 0.8))
	local previewHolder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = stage })
	local preview = nil

	local nameLabel = Kit.Text({ Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 162), MaxTextSize = 25, StrokeThickness = 3, ZIndex = 6, Parent = details })
	local rarityPill = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 194),
		Size = UDim2.fromOffset(170, 26),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 6,
		Parent = details,
	})
	Kit.Corner(rarityPill, UDim.new(0.5, 0))
	Kit.Stroke(rarityPill, 2.5)
	local rarityLabel = Kit.Text({ Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromOffset(5, 2), MaxTextSize = 18, ZIndex = 7, Parent = rarityPill })
	local multiplierLabel = Kit.Text({ Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 222), MaxTextSize = 22, Color = Kit.Colors.Yellow, StrokeThickness = 2.5, ZIndex = 6, Parent = details })
	local hint = Kit.Text({
		Text = "Выбери питомца в списке",
		Color = Kit.Colors.GreyDark,
		Stroke = false,
		Size = UDim2.new(1, -24, 0, 80),
		Position = UDim2.fromOffset(12, 160),
		MaxTextSize = 22,
		ZIndex = 6,
		Parent = details,
	})

	local deleteArmed = false
	local deleteArmedAt = 0
	local refreshDetails -- объявлена ниже

	local equipButton, equipLabel, equipGradient = Kit.Button({
		Name = "Equip",
		Size = UDim2.new(1, -16, 0, 50),
		Position = UDim2.fromOffset(8, 254),
		Color = Kit.Colors.Green,
		Icon = "Check",
		IconScale = 0.66,
		MaxTextSize = 22,
		ZIndex = 6,
		Parent = details,
		OnClick = function()
			local pet = selectedUid and State.FindPet(selectedUid)
			if pet then
				task.spawn(act, pet.Equipped and "Unequip" or "Equip", pet.Uid, true)
			end
		end,
	})
	local equipIconHolder = equipButton.Face:FindFirstChild("IconHolder")
	local unequipIcon = Icons.Create(equipIconHolder, "Cross", { Size = UDim2.fromScale(1, 1), ZIndex = 8 })
	unequipIcon.Visible = false
	local equipIcon = equipIconHolder:FindFirstChildWhichIsA("ViewportFrame")

	local mergeButton, mergeLabel, mergeGradient = Kit.Button({
		Name = "Merge",
		Size = UDim2.new(1, -16, 0, 50),
		Position = UDim2.fromOffset(8, 310),
		Color = Kit.Colors.Gold,
		Icon = "Sparkle",
		IconScale = 0.66,
		MaxTextSize = 21,
		ZIndex = 6,
		Parent = details,
		OnClick = function()
			local pet = selectedUid and State.FindPet(selectedUid)
			if pet then
				task.spawn(act, "Merge", pet.Uid, false)
			end
		end,
	})

	local deleteButton, deleteLabel, deleteGradient = Kit.Button({
		Name = "Delete",
		Size = UDim2.new(1, -16, 0, 50),
		Position = UDim2.fromOffset(8, 366),
		Color = Kit.Colors.Red,
		Icon = "Trash",
		IconScale = 0.66,
		MaxTextSize = 22,
		ZIndex = 6,
		Parent = details,
		OnClick = function()
			local pet = selectedUid and State.FindPet(selectedUid)
			if not pet then
				return
			end
			if not deleteArmed then
				-- Первое нажатие — просим подтвердить.
				deleteArmed = true
				deleteArmedAt = os.clock()
				refreshDetails()
				task.delay(3, function()
					if deleteArmed and os.clock() - deleteArmedAt >= 2.9 then
						deleteArmed = false
						refreshDetails()
					end
				end)
			else
				deleteArmed = false
				task.spawn(act, "Delete", pet.Uid, false)
			end
		end,
	})

	------------------------------------------------------------------ КАРТОЧКИ
	local cards = {} -- [uid] = { Card, Stroke, Scale, Golden, Pet, View }
	local viewCount = 0

	local function highlightSelection()
		for uid, item in pairs(cards) do
			local selected = uid == selectedUid
			item.Stroke.Color = selected and Kit.Colors.White or (item.Golden and Kit.Colors.Gold or Kit.Colors.Ink)
			item.Stroke.Thickness = selected and 5 or (item.Golden and 4.5 or 3)
			item.Scale.Scale = selected and 1.06 or 1
		end
	end

	-- Создаёт 3D-портреты только для карточек в видимой части списка.
	local function updateViews()
		local top = grid.AbsolutePosition.Y - CARD_SIZE.Y * 2
		local bottom = grid.AbsolutePosition.Y + grid.AbsoluteSize.Y + CARD_SIZE.Y * 2
		for _, item in pairs(cards) do
			local y = item.Card.AbsolutePosition.Y
			local visible = y + item.Card.AbsoluteSize.Y >= top and y <= bottom
			if visible and not item.View and viewCount < MAX_VIEWS then
				local _, view = Icons.Pet(item.Card, item.Pet.Id, item.Pet.Golden, {
					Size = UDim2.new(1, -6, 0.7, 0),
					Position = UDim2.fromOffset(3, 4),
					ZIndex = 5,
					Outline = 0.1,
				})
				item.View = view
				viewCount += 1
			elseif not visible and item.View then
				item.View:Destroy()
				item.View = nil
				viewCount -= 1
			end
		end
	end

	local viewsQueued = false
	local function queueUpdateViews()
		if viewsQueued then
			return
		end
		viewsQueued = true
		task.defer(function()
			viewsQueued = false
			updateViews()
		end)
	end
	grid:GetPropertyChangedSignal("CanvasPosition"):Connect(queueUpdateViews)

	local function makeCard(pet, order)
		local config = Pets[pet.Id]
		local rarity = Rarities[config.Rarity]
		local card = Kit.new("TextButton", {
			Name = "Pet" .. pet.Uid,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = order,
			ZIndex = 4,
			Parent = grid,
		})
		Kit.Corner(card, UDim.new(0, 16))
		local stroke = Kit.Stroke(card, pet.Golden and 4.5 or 3, pet.Golden and Kit.Colors.Gold or Kit.Colors.Ink)
		local topColor = pet.Golden and Color3.fromRGB(255, 240, 150) or Kit.Lighten(rarity.Color, 0.45)
		local bottomColor = pet.Golden and Color3.fromRGB(255, 170, 30) or Kit.Darken(rarity.Color, 0.1)
		Kit.Gradient(card, topColor, bottomColor)
		local scale = Kit.new("UIScale", { Parent = card })

		Kit.Text({
			Text = Format.Multiplier(Formulas.PetMultiplier(pet.Id, pet.Golden)),
			Size = UDim2.new(1, -6, 0.24, 0),
			Position = UDim2.new(0, 3, 0.74, 0),
			MaxTextSize = 20,
			StrokeThickness = 2.5,
			ZIndex = 6,
			Parent = card,
		})
		if pet.Equipped then
			local badge = Kit.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -8, 0, 8),
				Size = UDim2.fromOffset(28, 28),
				BackgroundColor3 = Kit.Colors.Green,
				ZIndex = 7,
				Parent = card,
			})
			Kit.Corner(badge, UDim.new(0.5, 0))
			Kit.Stroke(badge, 2.5)
			Icons.Glyph(badge, "Check", { Size = UDim2.fromScale(0.7, 0.7), ZIndex = 8 })
		end
		if pet.Golden then
			Kit.Shimmer(card, 2.4, 6)
			local goldBadge = Kit.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(28, 18),
				BackgroundColor3 = Kit.Colors.Gold,
				ZIndex = 7,
				Parent = card,
			})
			Kit.Corner(goldBadge, UDim.new(0.5, 0))
			Kit.Stroke(goldBadge, 2)
			Kit.Text({ Text = "G", Size = UDim2.fromScale(0.8, 0.9), Position = UDim2.fromScale(0.1, 0.05), ZIndex = 8, Parent = goldBadge })
		end

		card.Activated:Connect(function()
			Sounds.Play("Button")
			selectedUid = pet.Uid
			deleteArmed = false
			highlightSelection()
			refreshDetails()
		end)

		cards[pet.Uid] = { Card = card, Stroke = stroke, Scale = scale, Golden = pet.Golden, Pet = pet, View = nil }
	end

	local function sortedInventory()
		local list = table.clone(State.Inventory)
		table.sort(list, function(a, b)
			if a.Equipped ~= b.Equipped then
				return a.Equipped
			end
			local ma, mb = Formulas.PetMultiplier(a.Id, a.Golden), Formulas.PetMultiplier(b.Id, b.Golden)
			if ma ~= mb then
				return ma > mb
			end
			return a.Uid < b.Uid
		end)
		return list
	end

	local shownKey = nil
	refreshDetails = function()
		local pet = selectedUid and State.FindPet(selectedUid)
		local hasPet = pet ~= nil
		for _, object in ipairs({ equipButton, mergeButton, deleteButton, nameLabel, rarityPill, multiplierLabel, stage }) do
			object.Visible = hasPet
		end
		hint.Visible = not hasPet
		if not pet then
			shownKey = nil
			if preview then
				preview:Destroy()
				preview = nil
			end
			return
		end

		local config = Pets[pet.Id]
		local rarity = Rarities[config.Rarity]
		local key = pet.Id .. (pet.Golden and ":1" or ":0")
		if shownKey ~= key then
			shownKey = key
			if preview then
				preview:Destroy()
			end
			local _, view = Icons.Pet(previewHolder, pet.Id, pet.Golden, { Size = UDim2.fromScale(1, 1), ZIndex = 8, Animate = "Swing" })
			preview = view
		end
		local tint = pet.Golden and Kit.Colors.Gold or rarity.Color
		stageGradient.Color = ColorSequence.new(Kit.Lighten(tint, 0.7), Kit.Lighten(tint, 0.25))

		nameLabel.Text = (pet.Golden and "Золотой " or "") .. config.Name
		nameLabel.TextColor3 = pet.Golden and Kit.Colors.Gold or Kit.Colors.White
		rarityLabel.Text = Format.Upper(rarity.Name)
		rarityPill.BackgroundColor3 = rarity.Color
		multiplierLabel.Text = Format.Multiplier(Formulas.PetMultiplier(pet.Id, pet.Golden)) .. " к силе за клик"

		if pet.Equipped then
			equipLabel.Text = "Снять"
			Kit.SetButtonColor(equipGradient, Kit.Colors.Orange)
		else
			equipLabel.Text = "Экипировать"
			Kit.SetButtonColor(equipGradient, Kit.Colors.Green)
		end
		if equipIcon then
			equipIcon.Visible = not pet.Equipped
		end
		unequipIcon.Visible = pet.Equipped

		local need = GameConfig.GoldenMergeCount
		if pet.Golden then
			mergeLabel.Text = "Уже золотой"
			Kit.SetButtonColor(mergeGradient, Kit.Colors.Grey)
		else
			local same = 0
			for _, other in ipairs(State.Inventory) do
				if other.Id == pet.Id and not other.Golden then
					same += 1
				end
			end
			mergeLabel.Text = string.format("В золото (%d/%d)", math.min(same, need), need)
			Kit.SetButtonColor(mergeGradient, same >= need and Kit.Colors.Gold or Kit.Colors.Grey)
		end

		if deleteArmed then
			deleteLabel.Text = "Точно удалить?"
			Kit.SetButtonColor(deleteGradient, Kit.Colors.RedDark, Color3.fromRGB(140, 20, 30))
		else
			deleteLabel.Text = "Удалить"
			Kit.SetButtonColor(deleteGradient, Kit.Colors.Red)
		end
	end

	local function refreshInfo()
		countLabel.Text = string.format("Питомцы: %d/%d", #State.Inventory, GameConfig.MaxPets)
		bonusLabel.Text = "Бонус " .. Format.Multiplier(State.Get("PetMultiplier", 1))
		local maxEquipped = State.Get("MaxEquipped", GameConfig.BaseEquipSlots)
		local equipped = State.EquippedCount()
		for _, child in ipairs(slotsHolder:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for index = 1, maxEquipped do
			local slot = Kit.new("Frame", {
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = index <= equipped and Kit.Colors.Green or Kit.Colors.GreyDark,
				LayoutOrder = index,
				ZIndex = 8,
				Parent = slotsHolder,
			})
			Kit.Corner(slot, UDim.new(0.5, 0))
			Kit.Stroke(slot, 2, Color3.new(1, 1, 1))
		end
	end

	local dirty = true
	local function rebuild()
		dirty = false
		for _, item in pairs(cards) do
			if item.View then
				item.View:Destroy()
			end
			item.Card:Destroy()
		end
		cards = {}
		viewCount = 0
		local list = sortedInventory()
		for index, pet in ipairs(list) do
			makeCard(pet, index)
		end
		empty.Visible = #list == 0
		if selectedUid and not State.FindPet(selectedUid) then
			selectedUid = nil
			deleteArmed = false
		end
		if not selectedUid and list[1] then
			selectedUid = list[1].Uid
		end
		highlightSelection()
		refreshDetails()
		refreshInfo()
		task.defer(updateViews)
	end

	State.OnInventory(function()
		if panel.Frame.Visible then
			rebuild()
		else
			dirty = true
			refreshInfo()
		end
	end)
	State.Watch({ "MaxEquipped", "PetMultiplier" }, refreshInfo)

	panel.OnOpen = function()
		if dirty then
			rebuild()
		else
			refreshDetails()
			queueUpdateViews()
		end
	end

	selectFromOutside = function()
		deleteArmed = false
		if panel.Frame.Visible then
			highlightSelection()
			refreshDetails()
		end
	end
end

return PetsPanel
