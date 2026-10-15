--[[
	PetsPanel — инвентарь питомцев.
	Слева сетка карточек, справа 3D-превью выбранного питомца и кнопки:
	Экипировать / Снять, В золото (5 одинаковых → 1 золотой), Удалить (с подтверждением).
	В шапке — «Экипировать лучших».
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
local Panels = require(UI.Panels)
local Notifications = require(UI.Notifications)
local PetViewport = require(UI.PetViewport)
local State = require(UI.Parent.State)
local Sounds = require(UI.Parent.Sounds)

local PetsPanel = {}

local selectedUid = nil
local selectFromOutside = nil

function PetsPanel.Select(uid)
	selectedUid = uid
	if selectFromOutside then
		selectFromOutside()
	end
end

function PetsPanel.Create()
	local panel = Panels.Create("Pets", "🐾 ПИТОМЦЫ", Vector2.new(820, 490), Kit.Colors.Green)
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
		Text = "⭐ Экипировать лучших",
		Size = UDim2.fromOffset(250, 42),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -62, 0.5, 0),
		Color = Kit.Colors.Yellow,
		MaxTextSize = 20,
		ZIndex = 5,
		Parent = panel.Header,
		OnClick = function()
			task.spawn(act, "EquipBest", nil, false)
		end,
	})

	local info = Kit.Text({
		Name = "Info",
		Text = "",
		Color = Kit.Colors.Ink,
		Stroke = false,
		Size = UDim2.new(1, -300, 0, 26),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 19,
		ZIndex = 4,
		Parent = content,
	})

	local grid = Kit.new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, -300, 1, -32),
		BackgroundColor3 = Kit.Colors.PanelDark,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Kit.Colors.Ink,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3,
		Parent = content,
	})
	Kit.Corner(grid, UDim.new(0, 16))
	Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 12),
		Parent = grid,
	})
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(86, 98),
		CellPadding = UDim2.fromOffset(7, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local empty = Kit.Text({
		Name = "Empty",
		Text = "Пока пусто!\nПодойди к яйцу 🥚 и открой его за монеты",
		Color = Kit.Colors.GreyDark,
		Stroke = false,
		Size = UDim2.new(1, -320, 0, 90),
		Position = UDim2.fromOffset(10, 150),
		MaxTextSize = 24,
		ZIndex = 6,
		Visible = false,
		Parent = content,
	})

	------------------------------------------------------------------ ПРАВАЯ ЧАСТЬ
	local details = Kit.new("Frame", {
		Name = "Details",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 288, 1, 0),
		BackgroundColor3 = Kit.Colors.PanelDark,
		ZIndex = 3,
		Parent = content,
	})
	Kit.Corner(details, UDim.new(0, 16))

	local view = PetViewport.new(details, {
		Size = UDim2.new(1, -16, 0, 140),
		Position = UDim2.fromOffset(8, 8),
		Corner = UDim.new(0, 14),
		ZIndex = 4,
	})
	local nameLabel = Kit.Text({ Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 152), MaxTextSize = 26, StrokeThickness = 2.5, ZIndex = 4, Parent = details })
	local rarityLabel = Kit.Text({ Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 182), MaxTextSize = 20, ZIndex = 4, Parent = details })
	local multiplierLabel = Kit.Text({ Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 204), MaxTextSize = 22, Color = Kit.Colors.Yellow, ZIndex = 4, Parent = details })
	local hint = Kit.Text({
		Text = "Выбери питомца в списке 👈",
		Color = Kit.Colors.GreyDark,
		Stroke = false,
		Size = UDim2.new(1, -24, 0, 80),
		Position = UDim2.fromOffset(12, 120),
		MaxTextSize = 22,
		ZIndex = 4,
		Parent = details,
	})

	local deleteArmed = false
	local deleteArmedAt = 0

	local equipButton, equipLabel, equipGradient
	local mergeButton, mergeLabel, mergeGradient
	local deleteButton, deleteLabel, deleteGradient
	local refreshDetails -- объявлена ниже

	equipButton, equipLabel, equipGradient = Kit.Button({
		Name = "Equip",
		Size = UDim2.new(1, -16, 0, 42),
		Position = UDim2.fromOffset(8, 236),
		Color = Kit.Colors.Green,
		MaxTextSize = 22,
		ZIndex = 4,
		Parent = details,
		OnClick = function()
			local pet = selectedUid and State.FindPet(selectedUid)
			if pet then
				task.spawn(act, pet.Equipped and "Unequip" or "Equip", pet.Uid, true)
			end
		end,
	})

	mergeButton, mergeLabel, mergeGradient = Kit.Button({
		Name = "Merge",
		Size = UDim2.new(1, -16, 0, 42),
		Position = UDim2.fromOffset(8, 284),
		Color = Kit.Colors.Gold,
		MaxTextSize = 21,
		ZIndex = 4,
		Parent = details,
		OnClick = function()
			local pet = selectedUid and State.FindPet(selectedUid)
			if pet then
				task.spawn(act, "Merge", pet.Uid, false)
			end
		end,
	})

	deleteButton, deleteLabel, deleteGradient = Kit.Button({
		Name = "Delete",
		Size = UDim2.new(1, -16, 0, 42),
		Position = UDim2.fromOffset(8, 332),
		Color = Kit.Colors.Red,
		MaxTextSize = 22,
		ZIndex = 4,
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
	local cards = {} -- [uid] = { Card, Stroke, Golden }

	local function highlightSelection()
		for uid, item in pairs(cards) do
			local selected = uid == selectedUid
			item.Stroke.Color = selected and Kit.Colors.White or (item.Golden and Kit.Colors.Gold or Kit.Colors.Ink)
			item.Stroke.Thickness = selected and 5 or (item.Golden and 4 or 3)
			item.Scale.Scale = selected and 1.06 or 1
		end
	end

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
		Kit.Corner(card, UDim.new(0, 14))
		local stroke = Kit.Stroke(card, pet.Golden and 4 or 3, pet.Golden and Kit.Colors.Gold or Kit.Colors.Ink)
		local topColor = pet.Golden and Kit.Colors.Gold or Kit.Lighten(rarity.Color, 0.2)
		Kit.Gradient(card, topColor, Kit.Darken(rarity.Color, 0.25))
		local scale = Kit.new("UIScale", { Parent = card })

		Kit.Text({
			Text = config.Icon,
			Stroke = false,
			Size = UDim2.new(1, 0, 0.58, 0),
			Position = UDim2.fromScale(0, 0.06),
			ZIndex = 5,
			Parent = card,
		})
		Kit.Text({
			Text = Format.Multiplier(Formulas.PetMultiplier(pet.Id, pet.Golden)),
			Size = UDim2.new(1, -6, 0.28, 0),
			Position = UDim2.new(0, 3, 0.68, 0),
			MaxTextSize = 20,
			ZIndex = 5,
			Parent = card,
		})
		if pet.Equipped then
			local badge = Kit.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -8, 0, 8),
				Size = UDim2.fromOffset(26, 26),
				BackgroundColor3 = Kit.Colors.Green,
				ZIndex = 6,
				Parent = card,
			})
			Kit.Corner(badge, UDim.new(0.5, 0))
			Kit.Stroke(badge, 2)
			Kit.Text({ Text = "✔", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ZIndex = 7, Parent = badge })
		end
		if pet.Golden then
			Kit.Text({
				Text = "⭐",
				Stroke = false,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(10, 10),
				Size = UDim2.fromOffset(26, 26),
				ZIndex = 6,
				Parent = card,
			})
		end

		card.Activated:Connect(function()
			Sounds.Play("Button")
			selectedUid = pet.Uid
			deleteArmed = false
			highlightSelection()
			refreshDetails()
		end)

		cards[pet.Uid] = { Card = card, Stroke = stroke, Scale = scale, Golden = pet.Golden }
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
		for _, object in ipairs({ equipButton, mergeButton, deleteButton, nameLabel, rarityLabel, multiplierLabel, view.Frame }) do
			object.Visible = hasPet
		end
		hint.Visible = not hasPet
		if not pet then
			shownKey = nil
			view:SetPet(nil)
			return
		end

		local config = Pets[pet.Id]
		local rarity = Rarities[config.Rarity]
		local key = pet.Id .. (pet.Golden and ":1" or ":0")
		if shownKey ~= key then
			shownKey = key
			view:SetPet(pet.Id, pet.Golden)
		end
		view.Frame.BackgroundColor3 = Kit.Lighten(pet.Golden and Kit.Colors.Gold or rarity.Color, 0.55)

		nameLabel.Text = config.Icon .. " " .. (pet.Golden and "Золотой " or "") .. config.Name
		nameLabel.TextColor3 = pet.Golden and Kit.Colors.Gold or Kit.Colors.White
		rarityLabel.Text = rarity.Name
		rarityLabel.TextColor3 = rarity.Color
		multiplierLabel.Text = Format.Multiplier(Formulas.PetMultiplier(pet.Id, pet.Golden)) .. " к силе за клик"

		if pet.Equipped then
			equipLabel.Text = "Снять"
			Kit.SetButtonColor(equipGradient, Kit.Colors.Orange)
		else
			equipLabel.Text = "Экипировать"
			Kit.SetButtonColor(equipGradient, Kit.Colors.Green)
		end

		local need = GameConfig.GoldenMergeCount
		if pet.Golden then
			mergeLabel.Text = "✨ Уже золотой"
			Kit.SetButtonColor(mergeGradient, Kit.Colors.Grey)
		else
			local same = 0
			for _, other in ipairs(State.Inventory) do
				if other.Id == pet.Id and not other.Golden then
					same += 1
				end
			end
			mergeLabel.Text = string.format("✨ В золото (%d/%d)", math.min(same, need), need)
			Kit.SetButtonColor(mergeGradient, same >= need and Kit.Colors.Gold or Kit.Colors.Grey)
		end

		if deleteArmed then
			deleteLabel.Text = "Точно удалить?"
			Kit.SetButtonColor(deleteGradient, Kit.Colors.RedDark, Color3.fromRGB(140, 20, 30))
		else
			deleteLabel.Text = "🗑 Удалить"
			Kit.SetButtonColor(deleteGradient, Kit.Colors.Red)
		end
	end

	local function refreshInfo()
		info.Text = string.format(
			"Питомцы: %d/%d   •   Надето: %d/%d   •   Бонус: %s",
			#State.Inventory,
			GameConfig.MaxPets,
			State.EquippedCount(),
			State.Get("MaxEquipped", GameConfig.BaseEquipSlots),
			Format.Multiplier(State.Get("PetMultiplier", 1))
		)
	end

	local dirty = true
	local function rebuild()
		dirty = false
		for _, item in pairs(cards) do
			item.Card:Destroy()
		end
		cards = {}
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
