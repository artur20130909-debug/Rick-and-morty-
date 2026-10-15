--[[
	Popups — летящие цифры «+N» при кликах, сборе монет и продаже.
	Слой лежит прямо в ScreenGui (без UIScale), поэтому координаты — обычные пиксели экрана.
	Popups.Show(позиция, текст, цвет, размер, withCoin) — withCoin = true добавляет монетку слева.
]]

local Debris = game:GetService("Debris")

local UI = script.Parent
local Kit = require(UI.Kit)
local Icons = require(UI.Icons)

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
function Popups.Show(position, text, color, sizeMultiplier, withCoin)
	if not layer or active >= MAX_ACTIVE then
		return
	end
	active += 1
	sizeMultiplier = sizeMultiplier or 1
	local textSize = math.floor(36 * Kit.Scale * sizeMultiplier)

	local holder = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(position.X, position.Y),
		Size = UDim2.fromOffset(textSize * 8, textSize * 1.5),
		Rotation = math.random(-10, 10),
		ZIndex = 51,
		Parent = layer,
	})
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, math.floor(textSize * 0.15)),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = holder,
	})
	local coin = nil
	if withCoin then
		coin = Icons.Coin2D(holder, {
			Size = UDim2.fromOffset(textSize * 1.05, textSize * 1.05),
			ZIndex = 52,
			LayoutOrder = 1,
			StrokeThickness = math.max(1.5, 2.5 * Kit.Scale * sizeMultiplier),
		})
	end
	local label = Kit.Text({
		Text = text,
		Color = color or Kit.Colors.Yellow,
		Scaled = false,
		TextSize = textSize,
		StrokeThickness = math.max(2, math.floor(3.5 * Kit.Scale * sizeMultiplier)),
		Size = UDim2.fromOffset(textSize * 0.62 * utf8.len(text) + 8, textSize * 1.3),
		LayoutOrder = 2,
		ZIndex = 52,
		Parent = holder,
	})
	local stroke = label:FindFirstChildOfClass("UIStroke")
	local scale = Kit.new("UIScale", { Scale = 0.3, Parent = holder })

	Kit.Tween(scale, 0.18, { Scale = 1.12 }, Enum.EasingStyle.Back)
	local rise = 75 * Kit.Scale * (0.8 + sizeMultiplier * 0.4)
	Kit.Tween(holder, 0.95, {
		Position = UDim2.fromOffset(position.X + math.random(-24, 24), position.Y - rise),
		Rotation = holder.Rotation * 0.3,
	}, Enum.EasingStyle.Quint)
	task.delay(0.45, function()
		if label.Parent then
			Kit.Tween(label, 0.5, { TextTransparency = 1 })
			if stroke then
				Kit.Tween(stroke, 0.5, { Transparency = 1 })
			end
			if coin then
				Kit.Tween(scale, 0.5, { Scale = 0.6 })
			end
		end
	end)

	task.delay(1, function()
		active -= 1
	end)
	Debris:AddItem(holder, 1.05)
end

-- Цифра около кнопки (над её центром, со случайным смещением).
function Popups.AtGuiObject(guiObject, text, color, sizeMultiplier, withCoin)
	local center = guiObject.AbsolutePosition + guiObject.AbsoluteSize / 2
	local spread = guiObject.AbsoluteSize.X * 0.5
	local position = center + Vector2.new(math.random(-100, 100) / 100 * spread, -guiObject.AbsoluteSize.Y * 0.6 + math.random(-15, 10))
	Popups.Show(position, text, color, sizeMultiplier, withCoin)
end

-- Крупная надпись по центру экрана.
function Popups.Center(text, color, sizeMultiplier, withCoin)
	if not layer then
		return
	end
	local size = layer.AbsoluteSize
	Popups.Show(Vector2.new(size.X / 2, size.Y * 0.42), text, color, sizeMultiplier or 1.8, withCoin)
end

return Popups
