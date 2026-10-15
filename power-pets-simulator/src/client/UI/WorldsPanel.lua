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
local Icons = require(UI.Icons)
local Panels = require(UI.Panels)
local Notifications = require(UI.Notifications)
local State = require(UI.Parent.State)

local WorldsPanel = {}

function WorldsPanel.Create()
	local panel = Panels.Create("Worlds", "МИРЫ", Vector2.new(700, 500), Kit.Colors.Blue, "Globe")
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
			Name = worldId,
			Size = UDim2.new(1, 0, 0, 122),
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = index,
			ZIndex = 6,
			Parent = content,
		})
		Kit.Corner(row, UDim.new(0, 22))
		local stroke = Kit.Stroke(row, 4)
		Kit.Gradient(row, Kit.Lighten(world.Color, 0.7), Kit.Lighten(world.Color, 0.35), 0)

		local swatch = Kit.new("Frame", {
			Size = UDim2.fromOffset(104, 104),
			Position = UDim2.new(0, 9, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 7,
			Parent = row,
		})
		Kit.Corner(swatch, UDim.new(0, 20))
		Kit.Stroke(swatch, 3.5)
		Kit.Gradient(swatch, Kit.Lighten(world.Color, 0.25), Kit.Darken(world.Color, 0.25))
		local _, view = Icons.Create(swatch, world.Icon, { Size = UDim2.fromScale(1.05, 1.05), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8 })

		Kit.Text({
			Text = Format.Upper(world.Name),
			Color = Color3.new(1, 1, 1),
			StrokeThickness = 3,
			Size = UDim2.new(1, -330, 0, 34),
			Position = UDim2.fromOffset(124, 8),
			XAlign = Enum.TextXAlignment.Left,
			MaxTextSize = 30,
			ZIndex = 7,
			Parent = row,
		})
		Kit.Text({
			Text = world.Description,
			Color = Kit.Colors.Ink,
			Stroke = false,
			Font = Kit.FontBold,
			Size = UDim2.new(1, -330, 0, 40),
			Position = UDim2.fromOffset(124, 42),
			XAlign = Enum.TextXAlignment.Left,
			YAlign = Enum.TextYAlignment.Top,
			MaxTextSize = 17,
			ZIndex = 7,
			Parent = row,
		})
		-- Характеристики мира с монеткой.
		local stats = Kit.new("Frame", {
			BackgroundColor3 = Kit.Colors.Ink,
			BackgroundTransparency = 0.2,
			Size = UDim2.fromOffset(262, 28),
			Position = UDim2.fromOffset(124, 86),
			ZIndex = 7,
			Parent = row,
		})
		Kit.Corner(stats, UDim.new(0.5, 0))
		Icons.Coin2D(stats, { Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(6, 3), ZIndex = 8 })
		Kit.Text({
			Text = string.format("продажа ×%s  •  монета %s", Format.Number(world.SellMultiplier), Format.Number(world.CoinValue)),
			Size = UDim2.new(1, -40, 1, -6),
			Position = UDim2.fromOffset(34, 3),
			XAlign = Enum.TextXAlignment.Left,
			MaxTextSize = 16,
			ZIndex = 8,
			Parent = stats,
		})

		local button, label, gradient = Kit.Button({
			Name = "Go",
			Size = UDim2.fromOffset(190, 66),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Icon = "Portal",
			MaxTextSize = 22,
			Depth = 6,
			ZIndex = 7,
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
		local iconHolder = button.Face:FindFirstChild("IconHolder")
		local lockIcon = Icons.Create(iconHolder, "Lock", { Size = UDim2.fromScale(1, 1), ZIndex = 9 })
		rows[worldId] = {
			Button = button,
			Label = label,
			Gradient = gradient,
			Stroke = stroke,
			View = view,
			PortalIcon = iconHolder:FindFirstChildWhichIsA("ViewportFrame"),
			LockIcon = lockIcon,
		}
	end

	local function refresh()
		local unlocked = State.UnlockedWorlds()
		local total = State.Get("TotalStrength", 0)
		local currentWorld = State.Get("World", "Forest")
		for _, worldId in ipairs(Worlds.Order) do
			local world = Worlds[worldId]
			local row = rows[worldId]
			local locked = not unlocked[worldId] and total < world.UnlockStrength
			row.LockIcon.Visible = locked
			if row.PortalIcon then
				row.PortalIcon.Visible = not locked
			end
			row.Stroke.Color = worldId == currentWorld and Kit.Colors.Yellow or Kit.Colors.Ink
			row.Stroke.Thickness = worldId == currentWorld and 6 or 4
			row.View.Animate = worldId == currentWorld and "Swing" or nil
			Kit.SetButtonIcon(row.Button, worldId ~= currentWorld)
			if worldId == currentWorld then
				row.Label.Text = "Ты здесь"
				Kit.SetButtonColor(row.Gradient, Kit.Colors.Grey)
			elseif unlocked[worldId] then
				row.Label.Text = "Телепорт"
				Kit.SetButtonColor(row.Gradient, Kit.Colors.Blue)
			elseif not locked then
				row.Label.Text = "Открыть!"
				Kit.SetButtonColor(row.Gradient, Kit.Colors.Green)
			else
				row.Label.Text = Format.Number(world.UnlockStrength) .. " силы"
				Kit.SetButtonColor(row.Gradient, Kit.Colors.Grey)
			end
		end
	end

	State.Watch({ "UnlockedWorlds", "TotalStrength", "World" }, refresh)
end

return WorldsPanel
