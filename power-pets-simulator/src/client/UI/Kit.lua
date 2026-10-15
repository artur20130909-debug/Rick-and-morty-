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
	Ink = Color3.fromRGB(35, 30, 60),
	White = Color3.fromRGB(255, 255, 255),
	Panel = Color3.fromRGB(255, 249, 236),
	PanelDark = Color3.fromRGB(242, 230, 208),
	Green = Color3.fromRGB(96, 220, 96),
	GreenDark = Color3.fromRGB(40, 165, 60),
	Blue = Color3.fromRGB(70, 175, 255),
	BlueDark = Color3.fromRGB(30, 110, 225),
	Yellow = Color3.fromRGB(255, 218, 60),
	YellowDark = Color3.fromRGB(255, 158, 20),
	Orange = Color3.fromRGB(255, 160, 50),
	OrangeDark = Color3.fromRGB(235, 100, 20),
	Purple = Color3.fromRGB(176, 108, 255),
	PurpleDark = Color3.fromRGB(110, 50, 215),
	Red = Color3.fromRGB(255, 86, 86),
	RedDark = Color3.fromRGB(200, 40, 55),
	Pink = Color3.fromRGB(255, 110, 180),
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

function Kit.Tween(instance, duration, props, style, direction)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
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

--[[ Мультяшная кнопка с градиентом, обводкой и «нажатием».
	props: Size, Position, AnchorPoint, Color, Color2, Text, MaxTextSize, Corner, StrokeThickness,
	       ZIndex, Name, LayoutOrder, Parent, OnClick, Sound ("Button" по умолчанию, false — без звука)
	Возвращает button, label, gradient.
]]
function Kit.Button(props)
	local zIndex = props.ZIndex or 1
	local button = Kit.new("TextButton", {
		Name = props.Name or "Button",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = zIndex,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	Kit.Corner(button, props.Corner or UDim.new(0, 14))
	Kit.Stroke(button, props.StrokeThickness or 3)
	local color = props.Color or Kit.Colors.Green
	local gradient = Kit.Gradient(button, color, props.Color2 or Kit.Darken(color, 0.22))
	local scale = Kit.new("UIScale", { Parent = button })

	-- Блик сверху.
	local shine = Kit.new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.75,
		Size = UDim2.new(1, -10, 0.4, -4),
		Position = UDim2.new(0, 5, 0, 4),
		ZIndex = zIndex,
		Parent = button,
	})
	Kit.Corner(shine, props.Corner or UDim.new(0, 12))

	local label = Kit.Text({
		Text = props.Text or "",
		Size = UDim2.new(1, -14, 1, -8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		MaxTextSize = props.MaxTextSize or 30,
		ZIndex = zIndex + 1,
		Parent = button,
	})

	button.MouseEnter:Connect(function()
		Kit.Tween(scale, 0.1, { Scale = 1.05 })
	end)
	button.MouseLeave:Connect(function()
		Kit.Tween(scale, 0.1, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		Kit.Tween(scale, 0.06, { Scale = 0.9 })
	end)
	button.MouseButton1Up:Connect(function()
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

function Kit.SetButtonColor(gradient, color, color2)
	gradient.Color = ColorSequence.new(color, color2 or Kit.Darken(color, 0.22))
end

-- Полоса прогресса. Возвращает рамку и функцию set(доля 0..1, цвет?).
function Kit.ProgressBar(props)
	local bar = Kit.new("Frame", {
		Name = props.Name or "Bar",
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.25,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	Kit.Corner(bar, UDim.new(0.5, 0))
	local fill = Kit.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		ZIndex = (props.ZIndex or 1) + 1,
		Parent = bar,
	})
	Kit.Corner(fill, UDim.new(0.5, 0))
	local gradient = Kit.Gradient(fill, props.Color or Kit.Colors.Green)
	local function set(fraction, color)
		fraction = math.clamp(fraction, 0, 1)
		Kit.Tween(fill, 0.15, { Size = UDim2.fromScale(fraction, 1) })
		fill.Visible = fraction > 0.001
		if color then
			gradient.Color = ColorSequence.new(color, Kit.Darken(color, 0.2))
		end
	end
	return bar, set
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
