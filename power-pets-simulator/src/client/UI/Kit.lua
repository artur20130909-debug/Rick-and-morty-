--[[
	Kit — мультяшный набор для интерфейса: цвета, шрифт, кнопки, надписи, масштабирование.

	Весь интерфейс рисуется в «дизайн-пикселях» на холсте 1000×560 и масштабируется под экран
	через UIScale, поэтому на телефоне кнопки остаются крупными, а на мониторе — не гигантскими.
]]

local TweenService = game:GetService("TweenService")

local Sounds = require(script.Parent.Parent:WaitForChild("Sounds"))

local Kit = {}

Kit.DesignSize = Vector2.new(1000, 560)
Kit.Scale = 1

Kit.Colors = {
	Ink = Color3.fromRGB(32, 26, 58),
	White = Color3.fromRGB(255, 255, 255),
	Panel = Color3.fromRGB(255, 250, 240),
	PanelDark = Color3.fromRGB(240, 229, 210),
	PanelDeep = Color3.fromRGB(226, 210, 186),
	Green = Color3.fromRGB(100, 225, 95),
	GreenDark = Color3.fromRGB(40, 165, 60),
	Blue = Color3.fromRGB(75, 180, 255),
	BlueDark = Color3.fromRGB(35, 110, 225),
	Yellow = Color3.fromRGB(255, 220, 65),
	YellowDark = Color3.fromRGB(255, 160, 25),
	Orange = Color3.fromRGB(255, 160, 50),
	OrangeDark = Color3.fromRGB(235, 100, 20),
	Purple = Color3.fromRGB(180, 112, 255),
	PurpleDark = Color3.fromRGB(110, 55, 215),
	Red = Color3.fromRGB(255, 88, 88),
	RedDark = Color3.fromRGB(200, 40, 55),
	Pink = Color3.fromRGB(255, 115, 185),
	Teal = Color3.fromRGB(60, 215, 200),
	Grey = Color3.fromRGB(184, 188, 204),
	GreyDark = Color3.fromRGB(120, 124, 145),
	Gold = Color3.fromRGB(255, 205, 50),
}

local function makeFont(weight)
	local ok, font = pcall(function()
		return Font.new(Font.fromEnum(Enum.Font.Nunito).Family, weight)
	end)
	if ok then
		return font
	end
	return Font.fromEnum(Enum.Font.GothamBold)
end

Kit.Font = makeFont(Enum.FontWeight.Heavy)
Kit.FontBold = makeFont(Enum.FontWeight.Bold)

-- Создаёт объект: Kit.new("Frame", { Size = …, Parent = … }, { дети })
function Kit.new(className, props, children)
	local instance = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Kit.Darken(color, amount)
	return color:Lerp(Color3.new(0, 0, 0), amount or 0.2)
end

function Kit.Lighten(color, amount)
	return color:Lerp(Color3.new(1, 1, 1), amount or 0.2)
end

function Kit.Tween(instance, duration, props, style, direction, repeatCount, reverses)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out, repeatCount or 0, reverses or false),
		props
	)
	tween:Play()
	return tween
end

function Kit.Corner(parent, radius)
	return Kit.new("UICorner", { CornerRadius = radius or UDim.new(0, 14), Parent = parent })
end

function Kit.Stroke(parent, thickness, color)
	return Kit.new("UIStroke", {
		Color = color or Kit.Colors.Ink,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function Kit.Gradient(parent, top, bottom, rotation)
	return Kit.new("UIGradient", {
		Color = ColorSequence.new(top, bottom or Kit.Darken(top, 0.2)),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

--[[ Надпись с обводкой.
	props: Text, Size, Position, AnchorPoint, Color, Font, Scaled (true), TextSize, MaxTextSize,
	       XAlign, YAlign, Stroke (false — без обводки), StrokeColor, StrokeThickness, ZIndex, Name, Parent, RichText
]]
function Kit.Text(props)
	local label = Kit.new("TextLabel", {
		Name = props.Name or "Text",
		BackgroundTransparency = 1,
		FontFace = props.Font or Kit.Font,
		Text = props.Text or "",
		TextColor3 = props.Color or Kit.Colors.White,
		TextScaled = props.Scaled ~= false,
		TextSize = props.TextSize or 24,
		TextWrapped = true,
		RichText = props.RichText == true,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		TextXAlignment = props.XAlign or Enum.TextXAlignment.Center,
		TextYAlignment = props.YAlign or Enum.TextYAlignment.Center,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
	if props.Stroke ~= false then
		Kit.new("UIStroke", {
			Color = props.StrokeColor or Kit.Colors.Ink,
			Thickness = props.StrokeThickness or 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			LineJoinMode = Enum.LineJoinMode.Round,
			Parent = label,
		})
	end
	if props.MaxTextSize then
		Kit.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize, MinTextSize = 6, Parent = label })
	end
	return label
end

local iconFactory = nil -- задаётся из Icons, чтобы не было кругового require
function Kit.SetIconFactory(factory)
	iconFactory = factory
end

--[[ Мультяшная объёмная кнопка: «лицо» с градиентом и бликом стоит на тёмном «основании»,
	при нажатии опускается вниз.
	props: Size, Position, AnchorPoint, Color, Color2, Text, MaxTextSize, Corner, StrokeThickness, Depth,
	       Icon (имя 3D-иконки или "Coin"), IconColor, IconScale, ZIndex, Name, LayoutOrder, Parent, OnClick,
	       Sound ("Button" по умолчанию, false — без звука)
	Возвращает button (принимает нажатия), label, gradient.
]]
function Kit.Button(props)
	local zIndex = props.ZIndex or 1
	local depth = props.Depth or 5
	local corner = props.Corner or UDim.new(0, 14)
	local color = props.Color or Kit.Colors.Green
	local button = Kit.new("TextButton", {
		Name = props.Name or "Button",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = zIndex,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	local scale = Kit.new("UIScale", { Parent = button })

	local base = Kit.new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Kit.Darken(props.Color2 or color, 0.35),
		Size = UDim2.new(1, 0, 1, -depth),
		Position = UDim2.fromOffset(0, depth),
		ZIndex = zIndex,
		Parent = button,
	})
	Kit.Corner(base, corner)
	Kit.Stroke(base, props.StrokeThickness or 3)

	local face = Kit.new("Frame", {
		Name = "Face",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 1, -depth),
		ZIndex = zIndex + 1,
		Parent = button,
	})
	Kit.Corner(face, corner)
	Kit.Stroke(face, props.StrokeThickness or 3)
	local gradient = Kit.Gradient(face, Kit.Lighten(color, 0.12), props.Color2 or Kit.Darken(color, 0.18))

	local shine = Kit.new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.72,
		Size = UDim2.new(1, -12, 0.42, -4),
		Position = UDim2.new(0, 6, 0, 4),
		ZIndex = zIndex + 1,
		Parent = face,
	})
	Kit.Corner(shine, corner)

	local labelX, labelWidth = 7, -14
	if props.Icon then
		local iconSize = props.IconScale or 0.78
		local holder = Kit.new("Frame", {
			Name = "IconHolder",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.new(iconSize, 0, iconSize, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ZIndex = zIndex + 2,
			Parent = face,
		})
		if props.Icon == "Coin" then
			if iconFactory then
				iconFactory.Coin2D(holder, { Size = UDim2.fromScale(1, 1), ZIndex = zIndex + 2 })
			end
		elseif iconFactory then
			iconFactory.Create(holder, props.Icon, { Size = UDim2.fromScale(1, 1), ZIndex = zIndex + 2, Color = props.IconColor })
		end
		local height = 1
		if props.Size and props.Size.Y.Offset > 0 then
			height = props.Size.Y.Offset - depth
		end
		labelX = math.floor(height * iconSize) + 10
		labelWidth = -labelX - 8
	end

	local label = Kit.Text({
		Text = props.Text or "",
		Size = UDim2.new(1, labelWidth, 1, -8),
		Position = UDim2.new(0, labelX, 0, 4),
		MaxTextSize = props.MaxTextSize or 30,
		StrokeThickness = props.TextStroke or 2.5,
		ZIndex = zIndex + 3,
		Parent = face,
	})

	local function press(down)
		face.Position = UDim2.fromOffset(0, down and math.floor(depth * 0.7) or 0)
	end
	button.MouseEnter:Connect(function()
		Kit.Tween(scale, 0.1, { Scale = 1.04 })
	end)
	button.MouseLeave:Connect(function()
		press(false)
		Kit.Tween(scale, 0.1, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		press(true)
		Kit.Tween(scale, 0.06, { Scale = 0.96 })
	end)
	button.MouseButton1Up:Connect(function()
		press(false)
		Kit.Tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	button.Activated:Connect(function()
		if props.Sound ~= false then
			Sounds.Play(props.Sound or "Button")
		end
		if props.OnClick then
			props.OnClick()
		end
	end)

	return button, label, gradient
end

-- Перекрасить кнопку (лицо и основание).
function Kit.SetButtonColor(gradient, color, color2)
	gradient.Color = ColorSequence.new(Kit.Lighten(color, 0.12), color2 or Kit.Darken(color, 0.18))
	local face = gradient.Parent
	local button = face and face.Parent
	local base = button and button:FindFirstChild("Shadow")
	if base then
		base.BackgroundColor3 = Kit.Darken(color2 or color, 0.35)
	end
end

-- Полоса прогресса. Возвращает рамку и функцию set(доля 0..1, цвет?).
function Kit.ProgressBar(props)
	local bar = Kit.new("Frame", {
		Name = props.Name or "Bar",
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.2,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	Kit.Corner(bar, UDim.new(0.5, 0))
	Kit.Stroke(bar, 2)
	local fill = Kit.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		ZIndex = (props.ZIndex or 1) + 1,
		Parent = bar,
	})
	Kit.Corner(fill, UDim.new(0.5, 0))
	local gradient = Kit.Gradient(fill, props.Color or Kit.Colors.Green)
	local gloss = Kit.new("Frame", {
		Name = "Gloss",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.6,
		Size = UDim2.new(1, -6, 0.35, 0),
		Position = UDim2.new(0, 3, 0.12, 0),
		ZIndex = (props.ZIndex or 1) + 2,
		Parent = fill,
	})
	Kit.Corner(gloss, UDim.new(0.5, 0))
	local function set(fraction, color)
		fraction = math.clamp(fraction, 0, 1)
		Kit.Tween(fill, 0.15, { Size = UDim2.fromScale(fraction, 1) })
		fill.Visible = fraction > 0.001
		if color then
			gradient.Color = ColorSequence.new(Kit.Lighten(color, 0.15), Kit.Darken(color, 0.15))
		end
	end
	return bar, set
end

-- Узор в горошек (для фона окон). Рамка обрезает кружки по краям.
function Kit.Dots(parent, color, transparency, spacing, zIndex)
	local holder = Kit.new("Frame", {
		Name = "Dots",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = zIndex or 1,
		Parent = parent,
	})
	spacing = spacing or 64
	for row = 0, 10 do
		for column = 0, 15 do
			local dot = Kit.new("Frame", {
				BackgroundColor3 = color,
				BackgroundTransparency = transparency or 0.85,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(column * spacing + (row % 2) * spacing / 2, row * spacing * 0.85),
				Size = UDim2.fromOffset(12, 12),
				ZIndex = zIndex or 1,
				Parent = holder,
			})
			Kit.Corner(dot, UDim.new(0.5, 0))
		end
	end
	return holder
end

-- Бегущий блик по объекту (для дорогих карточек и золотых питомцев).
function Kit.Shimmer(guiObject, period, zIndex)
	local overlay = Kit.new("Frame", {
		Name = "Shimmer",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = zIndex or (guiObject.ZIndex + 1),
		Parent = guiObject,
	})
	local corner = guiObject:FindFirstChildOfClass("UICorner")
	if corner then
		Kit.Corner(overlay, corner.CornerRadius)
	end
	local gradient = Kit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 25,
		Offset = Vector2.new(-1, 0),
		Parent = overlay,
	})
	Kit.Tween(gradient, period or 2.5, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1)
	return overlay
end

-- Короткое «подпрыгивание» объекта (через его UIScale).
function Kit.Pop(guiObject, amount)
	local scale = guiObject:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Kit.new("UIScale", { Parent = guiObject })
	end
	scale.Scale = amount or 1.15
	Kit.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Корневая рамка с UIScale: внутри неё всё задаётся в дизайн-пикселях.
function Kit.CreateScaledRoot(screenGui, name)
	local root = Kit.new("Frame", {
		Name = name or "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	local uiScale = Kit.new("UIScale", { Parent = root })
	local function update()
		local size = screenGui.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local scale = math.clamp(math.min(size.X / Kit.DesignSize.X, size.Y / Kit.DesignSize.Y), 0.45, 1.4)
		uiScale.Scale = scale
		root.Size = UDim2.fromOffset(size.X / scale, size.Y / scale)
		Kit.Scale = scale
	end
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()
	return root
end

return Kit
