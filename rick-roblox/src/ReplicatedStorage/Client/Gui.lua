-- Кирпичики интерфейса: экраны, шрифты, рамки, обводки, градиенты, кнопки «как в мультике», логотип.
-- Вёрстка ведётся в пикселях для экрана 1280×720, а UIScale подгоняет её под любой экран (и телефон).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local G = {}
local Audio, Config

-- шрифты (с запасным вариантом, если семейства нет)
local function font(family, weight, fallback)
	local ok, f = pcall(function() return Font.new("rbxasset://fonts/families/" .. family .. ".json", weight) end)
	if ok and f then return f end
	return Font.fromEnum(fallback)
end
G.Fonts = {}

function G.init(ctx)
	Audio, Config = ctx.Audio, ctx.Config
	G.Fonts.Title = font("Nunito", Enum.FontWeight.Heavy, Enum.Font.GothamBlack)
	G.Fonts.Bold = font("Nunito", Enum.FontWeight.ExtraBold, Enum.Font.GothamBold)
	G.Fonts.Body = font("Montserrat", Enum.FontWeight.SemiBold, Enum.Font.GothamMedium)
	G.Fonts.BodyBold = font("Montserrat", Enum.FontWeight.Bold, Enum.Font.GothamBold)
	G.Fonts.Wide = font("Montserrat", Enum.FontWeight.ExtraBold, Enum.Font.GothamBlack)
	G.Fonts.Mono = Font.fromEnum(Enum.Font.Code)
	G.Fonts.Hand = font("AmaticSC", Enum.FontWeight.Bold, Enum.Font.AmaticSC)
end

function G.playerGui() return Players.LocalPlayer:WaitForChild("PlayerGui") end

-- экран: ScreenGui + корневая рамка 1280×720 по центру с масштабом под экран
function G.screen(name, order)
	local sg = Instance.new("ScreenGui")
	sg.Name = name
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = order or 0
	sg.Parent = G.playerGui()
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(1280, 720)
	root.BackgroundTransparency = 1
	root.Parent = sg
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local function fit()
		local cam = workspace.CurrentCamera
		local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
		local s = math.min(vs.X / 1280, vs.Y / 720)
		scale.Scale = math.clamp(s, 0.55, 2)
		-- корень растягиваем на весь экран в «дизайнерских» пикселях
		root.Size = UDim2.fromOffset(vs.X / scale.Scale, vs.Y / scale.Scale)
	end
	fit()
	local cam = workspace.CurrentCamera
	if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
	return sg, root
end

function G.frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	for k, v in pairs(props or {}) do f[k] = v end
	f.Parent = parent
	return f
end

function G.label(parent, text, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text or ""
	l.TextColor3 = Color3.new(1, 1, 1)
	l.FontFace = G.Fonts.Body or Font.fromEnum(Enum.Font.GothamMedium)
	l.TextSize = 22
	for k, v in pairs(props or {}) do l[k] = v end
	l.Parent = parent
	return l
end

function G.corner(obj, r)
	local c = Instance.new("UICorner")
	if typeof(r) == "UDim" then c.CornerRadius = r else c.CornerRadius = UDim.new(0, r or 12) end
	c.Parent = obj
	return c
end

function G.stroke(obj, color, thickness, transparency, mode)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.new(0, 0, 0)
	s.Thickness = thickness or 2
	s.Transparency = transparency or 0
	s.LineJoinMode = Enum.LineJoinMode.Round
	if mode then s.ApplyStrokeMode = mode end
	s.Parent = obj
	return s
end

-- градиент: colors = { Color3, ... } равномерно; rotation в градусах
function G.gradient(obj, colors, rotation, transparency)
	local g = Instance.new("UIGradient")
	local kps = {}
	for i, c in ipairs(colors) do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), c))
	end
	g.Color = ColorSequence.new(kps)
	g.Rotation = rotation or 90
	if transparency then g.Transparency = transparency end
	g.Parent = obj
	return g
end

function G.pad(obj, l, t, r, b)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, l or 0)
	p.PaddingTop = UDim.new(0, t or l or 0)
	p.PaddingRight = UDim.new(0, r or l or 0)
	p.PaddingBottom = UDim.new(0, b or t or l or 0)
	p.Parent = obj
	return p
end

function G.list(obj, dir, pad, halign, valign)
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, pad or 8)
	l.HorizontalAlignment = halign or Enum.HorizontalAlignment.Center
	l.VerticalAlignment = valign or Enum.VerticalAlignment.Top
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = obj
	return l
end

function G.tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Логотип «РИК И МОРТИ»: тень + толстая тёмная обводка + салатовая обводка + голубой градиент
function G.logo(parent, text, size, pos)
	local holder = G.frame(parent, { Name = "Logo", BackgroundTransparency = 1, Size = UDim2.fromOffset(1000, size * 1.25),
		AnchorPoint = Vector2.new(0.5, 0), Position = pos or UDim2.new(0.5, 0, 0, 40) })
	local function layer(name, color, strokeColor, strokeT, offset, z)
		local l = G.label(holder, text, { Name = name, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, offset),
			FontFace = G.Fonts.Title, TextSize = size, TextColor3 = color, ZIndex = z })
		if strokeColor then
			local s = G.stroke(l, strokeColor, strokeT)
			s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		end
		return l
	end
	layer("Shadow", Config.Colors.UiDark, Config.Colors.UiDark, size * 0.13, size * 0.09, 1)
	local outer = layer("Outer", Config.Colors.UiDark, Config.Colors.UiDark, size * 0.16, 0, 2)
	local mid = layer("Mid", Config.Colors.UiLime, Config.Colors.UiLime, size * 0.085, 0, 3)
	local top = layer("Fill", Color3.new(1, 1, 1), nil, 0, 0, 4)
	G.gradient(top, { Color3.fromRGB(150, 245, 255), Config.Colors.UiCyan, Color3.fromRGB(20, 155, 194) }, 90)
	local _1, _2 = outer, mid
	return holder
end

-- Кнопка в стиле меню «Портал»: салатовая (main), светлая (alt) или прозрачная (ghost)
-- opts: size, style, textSize, onClick, layoutOrder
function G.button(parent, text, opts)
	opts = opts or {}
	local style = opts.style or "main"
	local size = opts.size or Vector2.new(330, 64)
	local holder = G.frame(parent, { Name = opts.name or "Button", BackgroundTransparency = 1, Size = UDim2.fromOffset(size.X, size.Y + 6),
		LayoutOrder = opts.layoutOrder or 0 })
	local shadow = G.frame(holder, { Name = "Shadow", Size = UDim2.fromOffset(size.X, size.Y), Position = UDim2.fromOffset(0, 6),
		BackgroundColor3 = Config.Colors.UiDark })
	G.corner(shadow, UDim.new(0.5, 0))
	local b = Instance.new("TextButton")
	b.Name = "Button"
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(size.X, size.Y)
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.FontFace = G.Fonts.Title
	b.TextSize = opts.textSize or 30
	b.TextColor3 = style == "alt" and Color3.fromRGB(27, 46, 68) or Color3.fromRGB(16, 58, 16)
	b.Parent = holder
	G.corner(b, UDim.new(0.5, 0))
	local st = G.stroke(b, Config.Colors.UiDark, 4)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	if style == "main" then
		G.gradient(b, { Color3.fromRGB(217, 255, 122), Color3.fromRGB(143, 224, 58), Color3.fromRGB(91, 189, 34) }, 90)
	elseif style == "alt" then
		G.gradient(b, { Color3.fromRGB(240, 247, 255), Color3.fromRGB(185, 210, 238) }, 90)
	else
		b.BackgroundTransparency = 0.55
		b.BackgroundColor3 = Color3.fromRGB(10, 30, 16)
		b.TextColor3 = Color3.new(1, 1, 1)
		shadow.Visible = false
		st.Color = Config.Colors.UiLime
		st.Thickness = 2
	end
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local glow = G.stroke(holder, Config.Colors.UiLime, 0, 1)
	local _ = glow
	local arrow = G.label(holder, "▶", { Name = "Arrow", Size = UDim2.fromOffset(40, size.Y), Position = UDim2.fromOffset(-52, 0),
		FontFace = G.Fonts.Title, TextSize = 30, TextColor3 = Config.Colors.UiLime, TextTransparency = 1 })
	G.stroke(arrow, Config.Colors.UiDark, 3, 1).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	local hovered = false
	local function setHover(on)
		if hovered == on then return end
		hovered = on
		G.tween(scale, 0.18, { Scale = on and 1.07 or 1 }, Enum.EasingStyle.Back)
		G.tween(arrow, 0.18, { TextTransparency = on and 0 or 1, Position = UDim2.fromOffset(on and -50 or -62, 0) })
		local s = arrow:FindFirstChildOfClass("UIStroke")
		if s then G.tween(s, 0.18, { Transparency = on and 0 or 1 }) end
		if on and Audio then Audio.play("Hover", { volume = 0.35 }) end
	end
	b.MouseEnter:Connect(function() setHover(true) end)
	b.MouseLeave:Connect(function() setHover(false) end)
	b.SelectionGained:Connect(function() setHover(true) end)
	b.SelectionLost:Connect(function() setHover(false) end)
	b.MouseButton1Down:Connect(function() G.tween(scale, 0.08, { Scale = 0.96 }) end)
	b.MouseButton1Up:Connect(function() G.tween(scale, 0.12, { Scale = hovered and 1.07 or 1 }, Enum.EasingStyle.Back) end)
	b.Activated:Connect(function()
		if Audio then Audio.play("Click", { volume = 0.6 }) end
		if opts.onClick then opts.onClick() end
	end)
	return holder, b
end

-- Затемнённая подложка для окон (Modal — освобождает мышь в режиме от первого лица)
function G.modal(parent, name)
	local dim = Instance.new("TextButton")
	dim.Name = name or "Modal"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Modal = true
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(4, 10, 8)
	dim.BackgroundTransparency = 0.35
	dim.BorderSizePixel = 0
	dim.Parent = parent
	return dim
end

-- Панель-окно в стиле меню: тёмно-зелёная, салатовая рамка
function G.panel(parent, w, h, title)
	local p = G.frame(parent, { Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h), BackgroundColor3 = Color3.fromRGB(14, 34, 22), BackgroundTransparency = 0.04 })
	G.corner(p, 26)
	G.stroke(p, Config.Colors.UiLime, 3).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	G.gradient(p, { Color3.fromRGB(30, 62, 38), Color3.fromRGB(12, 28, 18) }, 90)
	if title then
		G.label(p, title, { Name = "Title", Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 16), FontFace = G.Fonts.Title,
			TextSize = 40, TextColor3 = Config.Colors.UiLime })
	end
	local sc = Instance.new("UIScale")
	sc.Parent = p
	return p, sc
end

-- плавное появление/исчезание всех потомков-надписей (для заставок)
function G.isTouch()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

return G
