--[[
	Notifications — всплывающие сообщения под счётчиками.
	Notifications.Show(текст, вид) — вид: "info" | "success" | "warning" | "error" | "reward"
]]

local UI = script.Parent
local Kit = require(UI.Kit)
local Sounds = require(UI.Parent.Sounds)

local Notifications = {}

local container = nil
local order = 0

local KIND_COLORS = {
	info = Kit.Colors.Blue,
	success = Kit.Colors.Green,
	warning = Kit.Colors.Orange,
	error = Kit.Colors.Red,
	reward = Kit.Colors.Gold,
}

local KIND_ICONS = {
	info = "💬",
	success = "✅",
	warning = "⚠️",
	error = "❌",
	reward = "🎁",
}

function Notifications.Init(root)
	container = Kit.new("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 112),
		Size = UDim2.fromOffset(560, 260),
		ZIndex = 40,
		Parent = root,
	})
	Kit.new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		Parent = container,
	})
end

function Notifications.Show(text, kind)
	if not container then
		return
	end
	kind = KIND_COLORS[kind] and kind or "info"
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

	local color = KIND_COLORS[kind]
	local toast = Kit.new("Frame", {
		Name = "Toast",
		BackgroundColor3 = Kit.Colors.Panel,
		Size = UDim2.fromOffset(540, 48),
		LayoutOrder = order,
		ZIndex = 41,
		Parent = container,
	})
	Kit.Corner(toast, UDim.new(0, 16))
	local stroke = Kit.Stroke(toast, 3)
	local scale = Kit.new("UIScale", { Scale = 0.6, Parent = toast })

	local badge = Kit.new("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(4, 4),
		ZIndex = 42,
		Parent = toast,
	})
	Kit.Corner(badge, UDim.new(0.5, 0))
	Kit.Text({
		Text = KIND_ICONS[kind],
		Size = UDim2.fromScale(0.75, 0.75),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Stroke = false,
		ZIndex = 43,
		Parent = badge,
	})
	local label = Kit.Text({
		Text = text,
		Color = Kit.Colors.Ink,
		Stroke = false,
		Size = UDim2.new(1, -60, 1, -8),
		Position = UDim2.fromOffset(52, 4),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		ZIndex = 42,
		Parent = toast,
	})

	Kit.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	if kind == "error" then
		Sounds.Play("Error")
	end

	task.delay(3.5, function()
		if not toast.Parent then
			return
		end
		Kit.Tween(toast, 0.3, { BackgroundTransparency = 1 })
		Kit.Tween(label, 0.3, { TextTransparency = 1 })
		Kit.Tween(badge, 0.3, { BackgroundTransparency = 1 })
		Kit.Tween(stroke, 0.3, { Transparency = 1 })
		task.wait(0.3)
		toast:Destroy()
	end)
end

return Notifications
