--[[
	EggDisplays — табло над яйцами: название, цена и все питомцы яйца в 3D
	с шансом и множителем, подсвеченные цветом редкости. Строится только на клиенте.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Pets = require(Shared.Config.Pets)
local Rarities = require(Shared.Config.Rarities)
local Formulas = require(Shared.Modules.Formulas)
local Format = require(Shared.Modules.Format)

local UI = script.Parent
local Kit = require(UI.Kit)
local Icons = require(UI.Icons)

local EggDisplays = {}

local displays = {} -- [eggPart] = BillboardGui

local function build(eggPart, playerGui)
	local eggId = eggPart:GetAttribute("EggId")
	local egg = eggId and Eggs[eggId]
	if not egg or displays[eggPart] then
		return
	end

	local gui = Kit.new("BillboardGui", {
		Name = "EggDisplay_" .. eggId,
		Adornee = eggPart,
		Size = UDim2.new(15, 0, 10, 0),
		StudsOffsetWorldSpace = Vector3.new(0, 10.5, 0),
		MaxDistance = 75,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	local board = Kit.new("Frame", {
		Name = "Board",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	Kit.Corner(board, UDim.new(0.07, 0))
	Kit.new("UIStroke", { Color = Kit.Colors.Ink, Thickness = 4, Parent = board })
	Kit.Gradient(board, Color3.fromRGB(60, 45, 105), Color3.fromRGB(30, 22, 58))

	-- Шапка с названием и ценой.
	local title = Kit.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(0.94, 0, 0.2, 0),
		Position = UDim2.fromScale(0.03, 0.04),
		Parent = board,
	})
	Kit.Corner(title, UDim.new(0.3, 0))
	Kit.Gradient(title, Kit.Lighten(egg.Color, 0.2), Kit.Darken(egg.Color, 0.2))
	Kit.Text({
		Text = egg.Name,
		Size = UDim2.new(0.62, 0, 0.84, 0),
		Position = UDim2.fromScale(0.03, 0.08),
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		Parent = title,
	})
	Icons.Coin2D(title, { Size = UDim2.fromScale(0.13, 0.7), Position = UDim2.fromScale(0.66, 0.15), ZIndex = 2 })
	Kit.Text({
		Text = Format.Number(egg.Price),
		Color = Kit.Colors.Yellow,
		Size = UDim2.new(0.24, 0, 0.8, 0),
		Position = UDim2.fromScale(0.75, 0.1),
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		Parent = title,
	})

	-- Питомцы.
	local row = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.96, 0, 0.7, 0),
		Position = UDim2.fromScale(0.02, 0.27),
		Parent = board,
	})
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0.012, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local chances = Formulas.EggChances(eggId)
	local list = Formulas.EggPetsSorted(eggId)
	local width = (1 - 0.012 * (#list - 1)) / #list
	for index, petId in ipairs(list) do
		local pet = Pets[petId]
		local rarity = Rarities[pet.Rarity]
		local cell = Kit.new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new(width, 0, 1, 0),
			LayoutOrder = index,
			Parent = row,
		})
		Kit.Corner(cell, UDim.new(0.12, 0))
		Kit.new("UIStroke", { Color = Kit.Colors.Ink, Thickness = 3, Parent = cell })
		Kit.Gradient(cell, Kit.Lighten(rarity.Color, 0.45), Kit.Darken(rarity.Color, 0.15))
		Icons.Pet(cell, petId, false, {
			Size = UDim2.fromScale(1, 0.6),
			Position = UDim2.fromScale(0, 0.02),
			ZIndex = 2,
			Outline = 0.1,
		})
		Kit.Text({
			Text = Format.Percent(chances[petId]),
			Size = UDim2.fromScale(0.9, 0.2),
			Position = UDim2.fromScale(0.05, 0.6),
			StrokeThickness = 2.5,
			ZIndex = 3,
			Parent = cell,
		})
		Kit.Text({
			Text = Format.Multiplier(pet.Multiplier),
			Color = Kit.Colors.Yellow,
			Size = UDim2.fromScale(0.9, 0.17),
			Position = UDim2.fromScale(0.05, 0.8),
			StrokeThickness = 2,
			ZIndex = 3,
			Parent = cell,
		})
	end

	displays[eggPart] = gui
end

function EggDisplays.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, eggPart in ipairs(CollectionService:GetTagged("EggStand")) do
		build(eggPart, playerGui)
	end
	CollectionService:GetInstanceAddedSignal("EggStand"):Connect(function(eggPart)
		build(eggPart, playerGui)
	end)
	CollectionService:GetInstanceRemovedSignal("EggStand"):Connect(function(eggPart)
		local gui = displays[eggPart]
		if gui then
			gui:Destroy()
			displays[eggPart] = nil
		end
	end)
end

return EggDisplays
