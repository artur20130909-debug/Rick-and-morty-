--[[
	Popups — летящие цифры «+N» при кликах, сборе монет и продаже.
	Слой лежит прямо в ScreenGui (без UIScale), поэтому координаты — обычные пиксели экрана.
]]

local Debris = game:GetService("Debris")

local UI = script.Parent
local Kit = require(UI.Kit)

local Popups = {}

local layer = nil
local active = 0
local MAX_ACTIVE = 40

function Popups.Init(screenGui)
	layer = Kit.new("Frame", {
		Name = "Popups",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = screenGui,
	})
end

-- position — Vector2 в пикселях ScreenGui; sizeMultiplier — размер текста (1 = обычный).
function Popups.Show(position, text, color, sizeMultiplier)
	if not layer or active >= MAX_ACTIVE then
		return
	end
	active += 1
	sizeMultiplier = sizeMultiplier or 1
	local textSize = math.floor(34 * Kit.Scale * sizeMultiplier)

	local label = Kit.Text({
		Text = text,
		Color = color or Kit.Colors.Yellow,
		Scaled = false,
		TextSize = textSize,
		StrokeThickness = math.max(2, math.floor(3 * Kit.Scale * sizeMultiplier)),
		Size = UDim2.fromOffset(textSize * 10, textSize * 1.4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(position.X, position.Y),
		ZIndex = 51,
		Parent = layer,
	})
	label.Rotation = math.random(-12, 12)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	local scale = Kit.new("UIScale", { Scale = 0.3, Parent = label })

	Kit.Tween(scale, 0.15, { Scale = 1.1 }, Enum.EasingStyle.Back)
	local rise = 70 * Kit.Scale * (0.8 + sizeMultiplier * 0.4)
	Kit.Tween(label, 0.9, {
		Position = UDim2.fromOffset(position.X + math.random(-20, 20), position.Y - rise),
		TextTransparency = 1,
		Rotation = label.Rotation * 0.3,
	}, Enum.EasingStyle.Quint)
	if stroke then
		Kit.Tween(stroke, 0.9, { Transparency = 1 }, Enum.EasingStyle.Quint)
	end

	task.delay(0.95, function()
		active -= 1
	end)
	Debris:AddItem(label, 1)
end

-- Цифра около кнопки (над её центром, со случайным смещением).
function Popups.AtGuiObject(guiObject, text, color, sizeMultiplier)
	local center = guiObject.AbsolutePosition + guiObject.AbsoluteSize / 2
	local spread = guiObject.AbsoluteSize.X * 0.5
	local position = center + Vector2.new(math.random(-100, 100) / 100 * spread, -guiObject.AbsoluteSize.Y * 0.6 + math.random(-15, 10))
	Popups.Show(position, text, color, sizeMultiplier)
end

-- Крупная надпись по центру экрана.
function Popups.Center(text, color, sizeMultiplier)
	if not layer then
		return
	end
	local size = layer.AbsoluteSize
	Popups.Show(Vector2.new(size.X / 2, size.Y * 0.42), text, color, sizeMultiplier or 1.8)
end

return Popups
