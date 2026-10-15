--[[
	Panels — окна (Питомцы, Магазин, Перерождение, Миры).
	Одновременно открыто только одно окно; нажатие мимо окна его закрывает.
]]

local UI = script.Parent
local Kit = require(UI.Kit)

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
		BackgroundColor3 = Color3.new(0, 0, 0),
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
	Frame   — само окно
	Header  — шапка (можно добавить свои кнопки)
	Content — место для содержимого
	OnOpen  — функция, которую можно задать: вызывается при каждом открытии
]]
function Panels.Create(name, title, size, color)
	local frame = Kit.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Kit.Colors.Panel,
		Visible = false,
		ZIndex = 2,
		Parent = layer,
	})
	Kit.Corner(frame, UDim.new(0, 24))
	Kit.Stroke(frame, 4)
	local scale = Kit.new("UIScale", { Parent = frame })

	local header = Kit.new("Frame", {
		Name = "Header",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 56),
		ZIndex = 3,
		Parent = frame,
	})
	Kit.Corner(header, UDim.new(0, 18))
	Kit.Stroke(header, 3)
	Kit.Gradient(header, color, Kit.Darken(color, 0.25))

	Kit.Text({
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, -90, 1, -10),
		Position = UDim2.fromOffset(16, 5),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 34,
		StrokeThickness = 3,
		ZIndex = 4,
		Parent = header,
	})

	Kit.Button({
		Name = "Close",
		Text = "✕",
		Size = UDim2.fromOffset(46, 46),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Color = Kit.Colors.Red,
		Corner = UDim.new(0.5, 0),
		ZIndex = 5,
		Parent = header,
		OnClick = function()
			Panels.Close()
		end,
	})

	local content = Kit.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 74),
		Size = UDim2.new(1, -32, 1, -88),
		ZIndex = 3,
		Parent = frame,
	})

	local panel = {
		Name = name,
		Frame = frame,
		Header = header,
		Content = content,
		Scale = scale,
		OnOpen = nil,
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
	end
	current = panel

	dim.Visible = true
	Kit.Tween(dim, 0.2, { BackgroundTransparency = 0.45 })
	panel.Frame.Visible = true
	panel.Scale.Scale = 0.7
	Kit.Tween(panel.Scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
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
	local tween = Kit.Tween(panel.Scale, 0.12, { Scale = 0.8 })
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
