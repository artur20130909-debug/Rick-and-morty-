--[[
	Notifications — всплывающие сообщения под счётчиками, с 3D-значком вида сообщения.
	Notifications.Show(текст, вид) — вид: "info" | "success" | "warning" | "error" | "reward"
]]

local UI = script.Parent
local Kit = require(UI.Kit)
local Icons = require(UI.Icons)
local Sounds = require(UI.Parent.Sounds)

local Notifications = {}

local container = nil
local order = 0

local KINDS = {
	info = { Color = Kit.Colors.Blue, Icon = "Exclamation", IconColor = Color3.fromRGB(255, 255, 255) },
	success = { Color = Kit.Colors.Green, Icon = "Check", IconColor = Color3.fromRGB(255, 255, 255) },
	warning = { Color = Kit.Colors.Orange, Icon = "Exclamation", IconColor = Color3.fromRGB(255, 240, 120) },
	error = { Color = Kit.Colors.Red, Icon = "Cross", IconColor = Color3.fromRGB(255, 255, 255) },
	reward = { Color = Kit.Colors.Gold, Icon = "Coin" },
}

function Notifications.Init(root)
	container = Kit.new("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 116),
		Size = UDim2.fromOffset(580, 260),
		ZIndex = 40,
		Parent = root,
	})
	Kit.new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
		Parent = container,
	})
end

function Notifications.Show(text, kind)
	if not container then
		return
	end
	local style = KINDS[kind] or KINDS.info
	order += 1

	-- Не больше 4 сообщений одновременно.
	local toasts = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = 1, #toasts - 3 do
		toasts[index]:Destroy()
	end

	local toast = Kit.new("Frame", {
		Name = "Toast",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(560, 52),
		LayoutOrder = order,
		ZIndex = 41,
		Parent = container,
	})
	Kit.Corner(toast, UDim.new(0.5, 0))
	local stroke = Kit.Stroke(toast, 3.5)
	local gradient = Kit.Gradient(toast, Kit.Colors.Panel, Kit.Lighten(style.Color, 0.6))
	local scale = Kit.new("UIScale", { Scale = 0.5, Parent = toast })

	local badge = Kit.new("Frame", {
		BackgroundColor3 = style.Color,
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.new(0, -10, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 42,
		Parent = toast,
	})
	Kit.Corner(badge, UDim.new(0.5, 0))
	Kit.Stroke(badge, 3.5)
	local icon = Icons.Create(badge, style.Icon, {
		Size = UDim2.fromScale(0.9, 0.9),
		Position = UDim2.fromScale(0.05, 0.05),
		ZIndex = 43,
		Color = style.IconColor,
	})
	local label = Kit.Text({
		Text = text,
		Color = Kit.Colors.Ink,
		Stroke = false,
		Size = UDim2.new(1, -78, 1, -10),
		Position = UDim2.fromOffset(62, 5),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		ZIndex = 42,
		Parent = toast,
	})

	Kit.Tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	if kind == "error" then
		Sounds.Play("Error")
	end

	task.delay(3.6, function()
		if not toast.Parent then
			return
		end
		Kit.Tween(toast, 0.3, { BackgroundTransparency = 1 })
		Kit.Tween(label, 0.3, { TextTransparency = 1 })
		Kit.Tween(badge, 0.3, { BackgroundTransparency = 1 })
		Kit.Tween(stroke, 0.3, { Transparency = 1 })
		Kit.Tween(scale, 0.3, { Scale = 0.8 })
		icon.Visible = false
		gradient.Enabled = false
		task.wait(0.3)
		toast:Destroy()
	end)
end

return Notifications
