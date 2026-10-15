--[[
	Panels — окна (Питомцы, Магазин, Перерождение, Миры).
	Одновременно открыто только одно окно; нажатие мимо окна его закрывает.
	Оформление: тень, градиентный фон в горошек, шапка-лента с 3D-иконкой, круглая кнопка закрытия.
]]

local UI = script.Parent
local Kit = require(UI.Kit)
local Icons = require(UI.Icons)

local Panels = {}

local layer = nil
local dim = nil
local registry = {}
local current = nil

function Panels.Init(root)
	layer = Kit.new("Frame", {
		Name = "PanelLayer",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = root,
	})
	dim = Kit.new("TextButton", {
		Name = "Dim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(20, 12, 40),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 1,
		Parent = layer,
	})
	dim.Activated:Connect(function()
		Panels.Close()
	end)
end

--[[ Создаёт окно. Возвращает таблицу:
	Frame   — окно целиком (его показывают/прячут)
	Header  — шапка (можно добавить свои кнопки)
	Content — место для содержимого
	OnOpen  — функция, которую можно задать: вызывается при каждом открытии
]]
function Panels.Create(name, title, size, color, iconName)
	local holder = Kit.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.54),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = layer,
	})
	local scale = Kit.new("UIScale", { Parent = holder })

	local shadow = Kit.new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Color3.fromRGB(10, 5, 25),
		BackgroundTransparency = 0.55,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 10),
		ZIndex = 2,
		Parent = holder,
	})
	Kit.Corner(shadow, UDim.new(0, 28))

	local body = Kit.new("Frame", {
		Name = "Body",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = holder,
	})
	Kit.Corner(body, UDim.new(0, 28))
	Kit.Stroke(body, 5)
	Kit.Gradient(body, Kit.Colors.Panel, Kit.Colors.PanelDark)
	local dots = Kit.Dots(body, Kit.Lighten(color, 0.2), 0.82, 64, 3)
	dots.Position = UDim2.fromOffset(14, 14)
	dots.Size = UDim2.new(1, -28, 1, -28)

	-- Шапка-лента.
	local header = Kit.new("Frame", {
		Name = "Header",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 58),
		ZIndex = 5,
		Parent = body,
	})
	Kit.Corner(header, UDim.new(0, 20))
	Kit.Stroke(header, 4)
	Kit.Gradient(header, Kit.Lighten(color, 0.15), Kit.Darken(color, 0.22))
	local gloss = Kit.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.75,
		Size = UDim2.new(1, -16, 0.42, 0),
		Position = UDim2.fromOffset(8, 4),
		ZIndex = 5,
		Parent = header,
	})
	Kit.Corner(gloss, UDim.new(0, 14))

	-- Большая иконка, выступающая за край шапки.
	local titleX = 18
	if iconName then
		local iconHolder = Kit.new("Frame", {
			Name = "TitleIcon",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -14, 0.5, -6),
			Size = UDim2.fromOffset(84, 84),
			ZIndex = 8,
			Parent = header,
		})
		Icons.Create(iconHolder, iconName, { Size = UDim2.fromScale(1, 1), ZIndex = 8, Animate = "Bob" })
		titleX = 78
	end

	Kit.Text({
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, -titleX - 70, 1, -12),
		Position = UDim2.fromOffset(titleX, 6),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 36,
		StrokeThickness = 3.5,
		ZIndex = 7,
		Parent = header,
	})

	local close = Kit.Button({
		Name = "Close",
		Size = UDim2.fromOffset(54, 58),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 14, 0, 0),
		Color = Kit.Colors.Red,
		Corner = UDim.new(0.5, 0),
		StrokeThickness = 3.5,
		ZIndex = 9,
		Parent = header,
		OnClick = function()
			Panels.Close()
		end,
	})
	Icons.Glyph(close.Face, "Close", { Size = UDim2.fromScale(0.5, 0.5), ZIndex = 13 })

	local content = Kit.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 80),
		Size = UDim2.new(1, -36, 1, -96),
		ZIndex = 5,
		Parent = body,
	})

	local panel = {
		Name = name,
		Frame = holder,
		Body = body,
		Header = header,
		Content = content,
		Scale = scale,
		OnOpen = nil,
		OnClose = nil,
	}
	registry[name] = panel
	return panel
end

function Panels.Open(name)
	local panel = registry[name]
	if not panel then
		return
	end
	if current and current ~= panel then
		current.Frame.Visible = false
		if current.OnClose then
			task.spawn(current.OnClose)
		end
	end
	current = panel

	dim.Visible = true
	Kit.Tween(dim, 0.2, { BackgroundTransparency = 0.4 })
	panel.Frame.Visible = true
	panel.Scale.Scale = 0.6
	Kit.Tween(panel.Scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	if panel.OnOpen then
		task.spawn(panel.OnOpen)
	end
end

function Panels.Close()
	local panel = current
	if not panel then
		return
	end
	current = nil
	if panel.OnClose then
		task.spawn(panel.OnClose)
	end
	local tween = Kit.Tween(panel.Scale, 0.14, { Scale = 0.75 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	tween.Completed:Once(function()
		if current ~= panel then
			panel.Frame.Visible = false
		end
	end)
	local dimTween = Kit.Tween(dim, 0.15, { BackgroundTransparency = 1 })
	dimTween.Completed:Once(function()
		if not current then
			dim.Visible = false
		end
	end)
end

function Panels.Toggle(name)
	if current and current.Name == name then
		Panels.Close()
	else
		Panels.Open(name)
	end
end

function Panels.IsOpen(name)
	return current ~= nil and current.Name == name
end

function Panels.AnyOpen()
	return current ~= nil
end

return Panels
