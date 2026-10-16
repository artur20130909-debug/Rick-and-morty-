-- Маленькая библиотека для интерфейса: создание элементов, кнопки с анимацией, окна.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local SoundPlayer = require(script.Parent.Parent.SoundPlayer)

local Lib = {}

-- Создать экземпляр со свойствами и детьми. Parent ставится последним.
function Lib.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local new = Lib.new

function Lib.corner(r: number?): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, r or 14) })
end

function Lib.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return new("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.86,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Lib.padding(all: number, top: number?): UIPadding
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
		PaddingTop = UDim.new(0, top or all),
		PaddingBottom = UDim.new(0, top or all),
	})
end

function Lib.gradient(c0: Color3, c1: Color3, rotation: number?): UIGradient
	return new("UIGradient", { Color = ColorSequence.new(c0, c1), Rotation = rotation or 90 })
end

function Lib.list(dir: Enum.FillDirection?, pad: number?, halign: Enum.HorizontalAlignment?, valign: Enum.VerticalAlignment?): UIListLayout
	return new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, pad or 8),
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Lib.tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

function Lib.label(text: string, size: number, props: { [string]: any }?): TextLabel
	local p: { [string]: any } = {
		Text = text,
		TextSize = size,
		FontFace = Theme.Font,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, size + 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return new("TextLabel", p)
end

function Lib.panel(props: { [string]: any }?): Frame
	local p: { [string]: any } = {
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = Theme.PanelTransparency,
		BorderSizePixel = 0,
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return new("Frame", p, { Lib.corner(14), Lib.stroke() })
end

-- Кнопка с наведением, нажатием и звуком
function Lib.button(text: string, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local p: { [string]: any } = {
		Text = text,
		TextSize = 18,
		FontFace = Theme.FontHeavy,
		TextColor3 = Theme.Text,
		BackgroundColor3 = Theme.Panel2,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(140, 44),
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	local b = new("TextButton", p, { Lib.corner(12), Lib.stroke(nil, 1.5, 0.82) })
	local scale = new("UIScale", { Parent = b })
	local base = b.BackgroundColor3
	b:SetAttribute("BaseColor", base)
	b.MouseEnter:Connect(function()
		local c = b:GetAttribute("BaseColor") or base
		Lib.tween(b, 0.12, { BackgroundColor3 = c:Lerp(Color3.new(1, 1, 1), 0.12) })
		Lib.tween(scale, 0.12, { Scale = 1.04 })
		SoundPlayer.play("Hover")
	end)
	b.MouseLeave:Connect(function()
		Lib.tween(b, 0.15, { BackgroundColor3 = b:GetAttribute("BaseColor") or base })
		Lib.tween(scale, 0.15, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		Lib.tween(scale, 0.06, { Scale = 0.95 })
	end)
	b.MouseButton1Up:Connect(function()
		Lib.tween(scale, 0.1, { Scale = 1.04 })
	end)
	if onClick then
		b.Activated:Connect(function()
			SoundPlayer.play("Click")
			onClick()
		end)
	end
	return b
end

function Lib.setButtonColor(b: GuiObject, color: Color3)
	b:SetAttribute("BaseColor", color)
	Lib.tween(b, 0.15, { BackgroundColor3 = color })
end

-- Подсветка обводкой (выбранная карточка, активная кнопка)
function Lib.setStroke(obj: GuiObject, on: boolean, color: Color3?)
	local stroke = obj:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if on then color or Theme.Accent else Theme.Stroke
		stroke.Transparency = if on then 0 else 0.82
		stroke.Thickness = if on then 3 else 1.5
	end
end

-- Шкала: тёмная дорожка и цветная заливка (длина заливки — Size.X.Scale от 0 до 1)
function Lib.bar(color: Color3, height: number?): (Frame, Frame)
	local h = height or 8
	local track = new("Frame", {
		Size = UDim2.new(1, 0, 0, h),
		BackgroundColor3 = Theme.Bg,
		BorderSizePixel = 0,
	}, { Lib.corner(h / 2) })
	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = track,
	}, { Lib.corner(h / 2), Lib.gradient(Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 195), 90) })
	return track, fill
end

-- Модальное окно по центру экрана с заголовком и крестиком
function Lib.modal(parent: Instance, title: string, size: Vector2, onClose: (() -> ())?): (Frame, Frame)
	local shade = new("TextButton", {
		Name = "Shade",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
		Parent = parent,
	})
	local win = Lib.panel({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.04,
		ZIndex = 21,
		Parent = shade,
	})
	new("UIScale", { Name = "Pop", Parent = win })
	new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = Theme.Panel2,
		BorderSizePixel = 0,
		ZIndex = 21,
		Parent = win,
	}, {
		Lib.corner(14),
		Lib.gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 190), 90),
		Lib.label(title, 26, {
			FontFace = Theme.FontHeavy,
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -90, 1, 0),
			ZIndex = 22,
		}),
	})
	local close = Lib.button("✕", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 9),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Theme.Bad,
		TextSize = 20,
		ZIndex = 23,
		Parent = win,
	})
	close.Activated:Connect(function()
		if onClose then
			onClose()
		end
	end)
	local body = new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 1, -58),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = win,
	}, { Lib.padding(18) })
	return shade :: any, body
end

function Lib.showModal(shade: GuiObject, visible: boolean)
	local win = shade:FindFirstChild("Window") :: Frame
	local pop = win and win:FindFirstChild("Pop") :: UIScale
	if visible then
		shade.Visible = true
		shade.BackgroundTransparency = 1
		Lib.tween(shade, 0.2, { BackgroundTransparency = 0.45 })
		if pop then
			pop.Scale = 0.85
			Lib.tween(pop, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	else
		Lib.tween(shade, 0.15, { BackgroundTransparency = 1 })
		if pop then
			Lib.tween(pop, 0.15, { Scale = 0.9 })
		end
		task.delay(0.15, function()
			shade.Visible = false
		end)
	end
end

-- Превью блока в ViewportFrame (медленно вращается)
local spinning: { { cam: Camera, model: Model, angle: number, dist: number, center: Vector3 } } = {}
local spinConn: RBXScriptConnection? = nil

function Lib.viewport(build: () -> Instance, props: { [string]: any }?, spin: boolean?): ViewportFrame
	local p: { [string]: any } = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(150, 155, 170),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1.4, -0.6),
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	local vp = new("ViewportFrame", p)
	local model = new("Model", { Parent = vp })
	local inst = build()
	inst.Parent = model
	local cam = new("Camera", { FieldOfView = 30, Parent = vp })
	vp.CurrentCamera = cam
	local cf, size = model:GetBoundingBox()
	local dist = size.Magnitude * 1.65 + 1
	local entry = { cam = cam, model = model, angle = math.rad(35), dist = dist, center = cf.Position }
	local function place()
		local a = entry.angle
		local offset = Vector3.new(math.sin(a), 0.55, math.cos(a)).Unit * entry.dist
		cam.CFrame = CFrame.lookAt(entry.center + offset, entry.center)
	end
	place()
	if spin then
		table.insert(spinning, entry)
		if not spinConn then
			spinConn = RunService.RenderStepped:Connect(function(dt)
				for i = #spinning, 1, -1 do
					local e = spinning[i]
					if not e.cam.Parent then
						table.remove(spinning, i)
					else
						e.angle += dt * 0.6
						local off = Vector3.new(math.sin(e.angle), 0.55, math.cos(e.angle)).Unit * e.dist
						e.cam.CFrame = CFrame.lookAt(e.center + off, e.center)
					end
				end
			end)
		end
	end
	return vp
end

-- Монетка (рисуется рамками, без картинок)
function Lib.coin(size: number): Frame
	return new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.Gold,
		BorderSizePixel = 0,
	}, {
		Lib.corner(size),
		new("UIStroke", { Color = Color3.fromRGB(190, 120, 20), Thickness = math.max(1.5, size / 12) }),
		new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 170, 30)),
			Rotation = 45,
		}),
		new("TextLabel", {
			Text = "$",
			TextSize = size * 0.62,
			FontFace = Theme.FontHeavy,
			TextColor3 = Color3.fromRGB(160, 96, 10),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}),
	})
end

return Lib
