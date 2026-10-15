--[[
	WorldsPanel — список миров: открыт / можно открыть / сколько силы нужно.
	Отсюда можно телепортироваться в любой открытый мир.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)

local UI = script.Parent
local Kit = require(UI.Kit)
local Panels = require(UI.Panels)
local Notifications = require(UI.Notifications)
local State = require(UI.Parent.State)

local WorldsPanel = {}

function WorldsPanel.Create()
	local panel = Panels.Create("Worlds", "🌍 МИРЫ", Vector2.new(640, 440), Kit.Colors.Blue)
	local content = panel.Content

	Kit.new("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = content,
	})

	local busy = false
	local rows = {}

	for index, worldId in ipairs(Worlds.Order) do
		local world = Worlds[worldId]
		local row = Kit.new("Frame", {
			Size = UDim2.new(1, 0, 0, 98),
			BackgroundColor3 = Kit.Colors.White,
			LayoutOrder = index,
			ZIndex = 4,
			Parent = content,
		})
		Kit.Corner(row, UDim.new(0, 18))
		Kit.Stroke(row, 3)

		local swatch = Kit.new("Frame", {
			Size = UDim2.fromOffset(80, 80),
			Position = UDim2.new(0, 9, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 5,
			Parent = row,
		})
		Kit.Corner(swatch, UDim.new(0, 16))
		Kit.Stroke(swatch, 3)
		Kit.Gradient(swatch, Kit.Lighten(world.Color, 0.2), Kit.Darken(world.Color, 0.25))
		Kit.Text({
			Text = world.Icon,
			Stroke = false,
			Size = UDim2.fromScale(0.7, 0.7),
			Position = UDim2.fromScale(0.15, 0.15),
			ZIndex = 6,
			Parent = swatch,
		})

		Kit.Text({
			Text = world.Name,
			Color = Kit.Darken(world.Color, 0.3),
			StrokeColor = Kit.Colors.Ink,
			StrokeThickness = 1,
			Size = UDim2.new(1, -290, 0, 30),
			Position = UDim2.fromOffset(100, 6),
			XAlign = Enum.TextXAlignment.Left,
			MaxTextSize = 26,
			ZIndex = 5,
			Parent = row,
		})
		Kit.Text({
			Text = world.Description,
			Color = Kit.Colors.GreyDark,
			Stroke = false,
			Font = Kit.FontBold,
			Size = UDim2.new(1, -290, 0, 22),
			Position = UDim2.fromOffset(100, 38),
			XAlign = Enum.TextXAlignment.Left,
			MaxTextSize = 17,
			ZIndex = 5,
			Parent = row,
		})
		Kit.Text({
			Text = string.format("💰 продажа ×%s   •   🪙 монеты по %s", Format.Number(world.SellMultiplier), Format.Number(world.CoinValue)),
			Color = Kit.Colors.Ink,
			Stroke = false,
			Font = Kit.FontBold,
			Size = UDim2.new(1, -290, 0, 22),
			Position = UDim2.fromOffset(100, 64),
			XAlign = Enum.TextXAlignment.Left,
			MaxTextSize = 17,
			ZIndex = 5,
			Parent = row,
		})

		local _, label, gradient = Kit.Button({
			Size = UDim2.fromOffset(176, 56),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			MaxTextSize = 22,
			ZIndex = 5,
			Parent = row,
			OnClick = function()
				if busy then
					return
				end
				if State.Get("World", "Forest") == worldId then
					Panels.Close()
					return
				end
				busy = true
				task.spawn(function()
					local ok, message = State.Invoke(Remotes.Teleport, worldId)
					busy = false
					if ok then
						Panels.Close()
					elseif message then
						Notifications.Show(message, "error")
					end
				end)
			end,
		})
		rows[worldId] = { Label = label, Gradient = gradient }
	end

	local function refresh()
		local unlocked = State.UnlockedWorlds()
		local total = State.Get("TotalStrength", 0)
		local currentWorld = State.Get("World", "Forest")
		for _, worldId in ipairs(Worlds.Order) do
			local world = Worlds[worldId]
			local row = rows[worldId]
			if worldId == currentWorld then
				row.Label.Text = "📍 Ты здесь"
				Kit.SetButtonColor(row.Gradient, Kit.Colors.Grey)
			elseif unlocked[worldId] then
				row.Label.Text = "✈️ Телепорт"
				Kit.SetButtonColor(row.Gradient, Kit.Colors.Blue)
			elseif total >= world.UnlockStrength then
				row.Label.Text = "✨ Открыть!"
				Kit.SetButtonColor(row.Gradient, Kit.Colors.Green)
			else
				row.Label.Text = "🔒 " .. Format.Number(world.UnlockStrength) .. " ⭐"
				Kit.SetButtonColor(row.Gradient, Kit.Colors.Grey)
			end
		end
	end

	State.Watch({ "UnlockedWorlds", "TotalStrength", "World" }, refresh)
end

return WorldsPanel
