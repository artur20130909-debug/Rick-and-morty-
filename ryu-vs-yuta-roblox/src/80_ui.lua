----------------------------------------------------------------------
-- ИНТЕРФЕЙС: старт, конец, вспышки, кадры-удары, линии скорости, виньетка
----------------------------------------------------------------------

local ui = {}

local function uiText(parent, class, props)
	local t = Instance.new(class)
	t.BackgroundTransparency = 1
	t.BorderSizePixel = 0
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = C.white
	t.TextScaled = true
	for k, v in pairs(props) do
		t[k] = v
	end
	t.Parent = parent
	return t
end

local function button(parent, text, x, y, color)
	local b = uiText(parent, "TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(0.22, 0.085),
		Text = text, BackgroundTransparency = 0, BackgroundColor3 = color, ZIndex = 21, AutoButtonColor = true,
	})
	corner(b, 0.25)
	return b
end

-- белая клякса на чёрном (кадр-удар), cx/cy — центр, s — размер
local function buildImpact(parent, cx, cy, s, withLines)
	local f = uiFrame(parent, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RGB(4, 4, 6), ZIndex = 15, Visible = false })
	local r = Random.new(3)
	for i = 1, 5 do
		local d = s * r:NextNumber(0.35, 0.7)
		local blob = uiFrame(f, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(cx + r:NextNumber(-0.06, 0.06) * s, cy + r:NextNumber(-0.08, 0.08) * s),
			Size = UDim2.fromScale(d * 0.5625, d), BackgroundColor3 = C.white, ZIndex = 16,
		})
		corner(blob, 0.5)
	end
	for i = 1, 26 do
		local a = (i / 26) * 360 + r:NextNumber(-6, 6)
		local L = s * r:NextNumber(0.25, 0.6)
		local dx, dy = cos(rad(a)) * L * 0.5 * 0.5625, sin(rad(a)) * L * 0.5
		uiFrame(f, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(cx + dx * 1.2, cy + dy * 1.2),
			Size = UDim2.fromScale(L * 0.5625, r:NextNumber(0.008, 0.02)),
			Rotation = a, BackgroundColor3 = C.white, ZIndex = 16,
		})
	end
	if withLines then
		for _, a in ipairs({ -28, 24 }) do
			uiFrame(f, {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cx, cy),
				Size = UDim2.fromScale(1.4, 0.006), Rotation = a, BackgroundColor3 = RGB(255, 236, 70), ZIndex = 17,
			})
		end
	end
	return f
end

local function buildUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RyuVsYutaUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	ui.gui = gui

	-- засветка окон в кадре с глазами
	ui.washTop = uiFrame(gui, { Position = UDim2.fromScale(0, 0.009), Size = UDim2.fromScale(1, 0.4655), BackgroundColor3 = C.white, BackgroundTransparency = 1, ZIndex = 4 })
	gradient(ui.washTop, { RGB(240, 180, 255), C.white }, { 0, 0.2, 1 }, 0)
	ui.washBottom = uiFrame(gui, { Position = UDim2.fromScale(0, 0.5255), Size = UDim2.fromScale(1, 0.4655), BackgroundColor3 = C.white, BackgroundTransparency = 1, ZIndex = 4 })
	gradient(ui.washBottom, { RGB(165, 235, 255), C.white }, { 0, 0.2, 1 }, 180)

	-- линии скорости из центра
	ui.speed = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Visible = false })
	ui.speedLines = {}
	for i = 1, 56 do
		local l = uiFrame(ui.speed, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.white, BackgroundTransparency = 0.2, ZIndex = 5 })
		ui.speedLines[i] = { f = l, a = rr(0, 360), r = rr(0.1, 0.9), len = rr(0.15, 0.4), sp = rr(1.2, 2.4), w = rr(0.002, 0.006) }
	end

	-- виньетка
	ui.vignette = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6, Visible = false })
	for _, v in ipairs({
		{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.22), 90 },
		{ UDim2.fromScale(0, 0.78), UDim2.fromScale(1, 0.22), 270 },
		{ UDim2.fromScale(0, 0), UDim2.fromScale(0.16, 1), 0 },
		{ UDim2.fromScale(0.84, 0), UDim2.fromScale(0.16, 1), 180 },
	}) do
		local e = uiFrame(ui.vignette, { Position = v[1], Size = v[2], BackgroundColor3 = C.black, BackgroundTransparency = 0, ZIndex = 6 })
		gradient(e, { C.black, C.black }, { 0.45, 1 }, v[3])
	end

	-- дымка поверх кадра: сверху почти прозрачная, у земли плотнее (как пелена тумана в аниме)
	ui.haze = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BackgroundTransparency = 1, ZIndex = 3 })
	ui.hazeGrad = gradient(ui.haze, { C.white, C.white }, { 0.8, 0.5 }, 90)
	ui.tint = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BackgroundTransparency = 1, ZIndex = 7 })
	ui.flash = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BackgroundTransparency = 1, ZIndex = 8 })
	ui.flashGrad = gradient(ui.flash, { C.white, C.white }, nil, 0)
	ui.impact1 = buildImpact(gui, 0.5, 0.5, 1.0, true)
	ui.impact2 = buildImpact(gui, 0.62, 0.45, 0.35, false)
	ui.black = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.black, BackgroundTransparency = 1, ZIndex = 18 })
	-- субтитры как в клипе: белые буквы с тёмной обводкой внизу кадра
	ui.sub = uiText(gui, "TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.93), Size = UDim2.fromScale(0.8, 0.052),
		Text = "", Font = Enum.Font.GothamBold, ZIndex = 17, Visible = false,
	})
	local subStroke = Instance.new("UIStroke")
	subStroke.Color = RGB(10, 10, 20)
	subStroke.Thickness = 2.5
	subStroke.Parent = ui.sub

	-- стартовый экран
	ui.start = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RGB(8, 8, 14), ZIndex = 20 })
	uiText(ui.start, "TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromScale(0.8, 0.15),
		Text = 'РЮ <font color="#ff4fc0">vs</font> ЮТА', RichText = true, ZIndex = 21,
	})
	uiText(ui.start, "TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.43), Size = UDim2.fromScale(0.7, 0.045),
		Text = "фан-анимация по «Магической битве»", Font = Enum.Font.GothamBold, TextColor3 = RGB(170, 220, 255), ZIndex = 21,
	})
	ui.btnAll = button(ui.start, "▶ СТАРТ: ВСЕ ЧАСТИ ПОДРЯД", 0.5, 0.58, RGB(255, 60, 170))
	ui.btnAll.Size = UDim2.fromScale(0.4, 0.09)
	ui.btn1 = button(ui.start, "Часть 1", 0.29, 0.7, RGB(60, 70, 120))
	ui.btn2 = button(ui.start, "Часть 2", 0.43, 0.7, RGB(60, 70, 120))
	ui.btn3 = button(ui.start, "Часть 3", 0.57, 0.7, RGB(60, 70, 120))
	ui.btn4 = button(ui.start, "Часть 4", 0.71, 0.7, RGB(60, 70, 120))
	for _, b in ipairs({ ui.btn1, ui.btn2, ui.btn3, ui.btn4 }) do
		b.Size = UDim2.fromScale(0.12, 0.06)
	end
	uiText(ui.start, "TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.fromScale(0.86, 0.034),
		Text = "Сначала включи запись экрана · ПРОБЕЛ — всё подряд · 1, 2, 3, 4 — одна часть · R — повтор · графика 10",
		Font = Enum.Font.GothamBold, TextColor3 = RGB(150, 150, 170), ZIndex = 21,
	})

	-- экран после конца
	ui.endScreen = uiFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20, Visible = false })
	ui.endText = uiText(ui.endScreen, "TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromScale(0.6, 0.07), Text = "Конец", ZIndex = 21,
	})
	ui.again = button(ui.endScreen, "↻ ЕЩЁ РАЗ (R)", 0.38, 0.56, RGB(255, 60, 170))
	ui.other = button(ui.endScreen, "▶ ВСЁ ПОДРЯД", 0.62, 0.56, RGB(40, 170, 255))
end

-- линии скорости: k — сила (0..1), t — время
local function updateSpeedLines(k, t)
	ui.speed.Visible = k > 0.01
	if k <= 0.01 then
		return
	end
	for _, l in ipairs(ui.speedLines) do
		local r = (l.r + t * l.sp) % 1
		local a = rad(l.a)
		local mid = 0.15 + r * 0.75
		l.f.Position = UDim2.fromScale(0.5 + cos(a) * mid * 0.5625, 0.5 + sin(a) * mid)
		l.f.Size = UDim2.fromScale(l.len * 0.5625 * (0.5 + r), l.w)
		l.f.Rotation = l.a
		l.f.BackgroundTransparency = 1 - k * (0.2 + 0.8 * r)
	end
end
