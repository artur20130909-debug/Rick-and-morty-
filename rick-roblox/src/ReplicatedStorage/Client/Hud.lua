-- Игровой интерфейс: задание, субтитры и мысли Морти, подсказки, прицел, кнопка действия,
-- маркер цели, затемнение, кинорамка, веки (моргание), заставка главы, записка, кнопка паузы.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local Hud = {}
local G, U, Config, Settings, Audio
local root, overRoot
local fadeFrame, barTop, barBot, lidTop, lidBot, blur
local objFrame, objText, subFrame, subName, subText, toastFrame, toastText, cross, actionHolder
local subToken = 0

local SUB_SIZES = { 20, 25, 31 }

function Hud.init(ctx)
	G, U, Config, Settings, Audio = ctx.Gui, ctx.Util, ctx.Config, ctx.Settings, ctx.Audio
	local _, r = G.screen("Hud", 5)
	root = r
	local _, o = G.screen("Overlay", 50)
	overRoot = o

	-- задание (слева сверху)
	objFrame = G.frame(root, { Name = "Objective", Position = UDim2.fromOffset(24, 76), Size = UDim2.fromOffset(420, 70),
		BackgroundColor3 = Color3.fromRGB(10, 22, 14), BackgroundTransparency = 0.3, Visible = false })
	G.corner(objFrame, 14)
	G.stroke(objFrame, Config.Colors.UiLime, 1.5, 0.4).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	G.frame(objFrame, { Name = "Accent", Size = UDim2.new(0, 5, 1, -18), Position = UDim2.fromOffset(10, 9), BackgroundColor3 = Config.Colors.UiLime })
	G.label(objFrame, "ЗАДАНИЕ", { Name = "Head", Position = UDim2.fromOffset(26, 8), Size = UDim2.fromOffset(300, 18),
		FontFace = G.Fonts.Wide, TextSize = 14, TextColor3 = Config.Colors.UiLime, TextXAlignment = Enum.TextXAlignment.Left })
	objText = G.label(objFrame, "", { Name = "Text", Position = UDim2.fromOffset(26, 28), Size = UDim2.new(1, -36, 0, 34),
		FontFace = G.Fonts.BodyBold, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true })
	local check = G.label(objFrame, "✓", { Name = "Check", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(34, 34), FontFace = G.Fonts.Title, TextSize = 30, TextColor3 = Config.Colors.UiLime, TextTransparency = 1 })
	local _c = check

	-- субтитры (снизу)
	subFrame = G.frame(root, { Name = "Subtitle", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -54),
		Size = UDim2.fromOffset(860, 64), BackgroundColor3 = Color3.fromRGB(6, 10, 8), BackgroundTransparency = 1, Visible = false,
		AutomaticSize = Enum.AutomaticSize.Y })
	G.corner(subFrame, 18)
	G.pad(subFrame, 22, 12, 22, 14)
	local sl = G.list(subFrame, Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center)
	local _sl = sl
	subName = G.label(subFrame, "", { Name = "Name", Size = UDim2.new(1, 0, 0, 20), FontFace = G.Fonts.Wide, TextSize = 16,
		TextColor3 = Config.Colors.UiLime, LayoutOrder = 1 })
	subText = G.label(subFrame, "", { Name = "Text", Size = UDim2.new(1, 0, 0, 30), AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = G.Fonts.Body, TextSize = 25, TextWrapped = true, LayoutOrder = 2 })
	G.stroke(subText, Color3.new(0, 0, 0), 1.2, 0.3).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	-- всплывающая подсказка (сверху по центру)
	toastFrame = G.frame(root, { Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(560, 44), BackgroundColor3 = Color3.fromRGB(10, 22, 14), BackgroundTransparency = 0.25, Visible = false })
	G.corner(toastFrame, UDim.new(0.5, 0))
	G.stroke(toastFrame, Config.Colors.UiLime, 1.5, 0.3).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	toastText = G.label(toastFrame, "", { Size = UDim2.fromScale(1, 1), FontFace = G.Fonts.BodyBold, TextSize = 19 })

	-- прицел
	cross = G.frame(root, { Name = "Cross", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, Visible = false })
	G.corner(cross, UDim.new(0.5, 0))
	G.stroke(cross, Color3.new(0, 0, 0), 1, 0.5)

	-- кнопка действия (снизу по центру)
	actionHolder = G.frame(root, { Name = "Action", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -128),
		Size = UDim2.fromOffset(10, 58), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Visible = false })

	-- оверлей: кинорамка, веки, затемнение
	barTop = G.frame(overRoot, { Name = "BarTop", Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0) })
	barBot = G.frame(overRoot, { Name = "BarBot", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0) })
	local function lid(name, top)
		local f = G.frame(overRoot, { Name = name, Size = UDim2.new(1, 0, 0.62, 0), BackgroundColor3 = Color3.new(0, 0, 0),
			AnchorPoint = Vector2.new(0, top and 0 or 1), Position = UDim2.fromScale(0, top and 0 or 1), Visible = false })
		local edge = G.frame(f, { Name = "Edge", Size = UDim2.new(1, 0, 0.35, 0), BackgroundColor3 = Color3.new(0, 0, 0),
			AnchorPoint = Vector2.new(0, top and 0 or 1), Position = UDim2.fromScale(0, top and 1 or 0) })
		local tr = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		G.gradient(edge, { Color3.new(0, 0, 0), Color3.new(0, 0, 0) }, top and 90 or -90, tr)
		return f
	end
	lidTop = lid("LidTop", true)
	lidBot = lid("LidBot", false)
	fadeFrame = G.frame(overRoot, { Name = "Fade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0, ZIndex = 20 })

	blur = Instance.new("BlurEffect")
	blur.Name = "RM_Blur"
	blur.Size = 0
	blur.Parent = game:GetService("Lighting")

	Settings.Changed:Connect(function(k)
		if k == "Subtitles" then subText.TextSize = SUB_SIZES[Settings.get("Subtitles")] or 25 end
	end)
	subText.TextSize = SUB_SIZES[Settings.get("Subtitles")] or 25
end

---------------------------------------------------------------------------
-- затемнение, рамка, веки, размытие
---------------------------------------------------------------------------
function Hud.fade(alpha, t, color)
	if color then fadeFrame.BackgroundColor3 = color end
	local tw = G.tween(fadeFrame, t or 0.6, { BackgroundTransparency = 1 - alpha }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	return tw
end
function Hud.fadeWait(alpha, t, color)
	local tw = Hud.fade(alpha, t, color)
	U.wait(t or 0.6)
	return tw
end
function Hud.fadeSet(alpha, color)
	if color then fadeFrame.BackgroundColor3 = color end
	fadeFrame.BackgroundTransparency = 1 - alpha
end

function Hud.letterbox(on, t)
	local h = on and 74 or 0
	G.tween(barTop, t or 0.8, { Size = UDim2.new(1, 0, 0, h) }, Enum.EasingStyle.Quint)
	G.tween(barBot, t or 0.8, { Size = UDim2.new(1, 0, 0, h) }, Enum.EasingStyle.Quint)
end

-- веки: open 0 — глаза закрыты, 1 — открыты
function Hud.eyes(open, t, style)
	lidTop.Visible = true
	lidBot.Visible = true
	local y = 0.62 * (1 - open)
	local closedH = 0.62
	local _ = closedH
	G.tween(lidTop, t or 0.5, { Position = UDim2.fromScale(0, -0.62 * open) }, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	G.tween(lidBot, t or 0.5, { Position = UDim2.fromScale(0, 1 + 0.62 * open) }, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local _y = y
	if open >= 1 then
		task.delay((t or 0.5) + 0.05, function()
			if lidTop.Position.Y.Scale <= -0.6 then lidTop.Visible = false; lidBot.Visible = false end
		end)
	end
end
function Hud.eyesSet(open)
	lidTop.Visible = open < 1
	lidBot.Visible = open < 1
	lidTop.Position = UDim2.fromScale(0, -0.62 * open)
	lidBot.Position = UDim2.fromScale(0, 1 + 0.62 * open)
end

function Hud.blur(size, t)
	if t and t > 0 then G.tween(blur, t, { Size = size }) else blur.Size = size end
end

---------------------------------------------------------------------------
-- задание
---------------------------------------------------------------------------
local objToken = 0
function Hud.objective(text)
	objToken = objToken + 1
	local tok = objToken
	if not text then
		G.tween(objFrame, 0.3, { Position = UDim2.fromOffset(-460, 76) })
		task.delay(0.35, function() if objToken == tok then objFrame.Visible = false end end)
		return
	end
	objText.Text = text
	objFrame.Check.TextTransparency = 1
	objFrame.Visible = true
	objFrame.Position = UDim2.fromOffset(-460, 76)
	G.tween(objFrame, 0.55, { Position = UDim2.fromOffset(24, 76) }, Enum.EasingStyle.Back)
	Audio.play("Notify", { volume = 0.35 })
end
function Hud.objectiveDone()
	local tok = objToken
	G.tween(objFrame.Check, 0.25, { TextTransparency = 0 })
	Audio.play("AlarmOff", { volume = 0.3, speed = 1.4 })
	task.delay(1.1, function()
		if objToken == tok then Hud.objective(nil) end
	end)
end

---------------------------------------------------------------------------
-- субтитры: Hud.say(имя, текст, {thought = true, hold = секунды})
---------------------------------------------------------------------------
function Hud.say(name, text, opts)
	opts = opts or {}
	subToken = subToken + 1
	local tok = subToken
	subName.Text = name or ""
	subName.Visible = name ~= nil and name ~= ""
	if opts.thought then
		subText.FontFace = Font.new(G.Fonts.Body.Family, Enum.FontWeight.SemiBold, Enum.FontStyle.Italic)
		subText.TextColor3 = Color3.fromRGB(226, 240, 255)
	else
		subText.FontFace = G.Fonts.Body
		subText.TextColor3 = Color3.new(1, 1, 1)
	end
	subText.Text = text
	subText.MaxVisibleGraphemes = 0
	subFrame.Visible = true
	subFrame.BackgroundTransparency = 1
	G.tween(subFrame, 0.25, { BackgroundTransparency = 0.35 })
	if opts.thought then Audio.play("Thought", { volume = 0.25 }) end
	-- печать по буквам
	local n = utf8.len(text) or #text
	task.spawn(function()
		local shown = 0
		while shown < n and subToken == tok do
			shown = shown + 1
			subText.MaxVisibleGraphemes = shown
			task.wait(opts.speed or 0.028)
		end
		if subToken == tok then subText.MaxVisibleGraphemes = -1 end
	end)
	local hold = opts.hold or (1.6 + n * 0.055)
	task.delay(hold, function()
		if subToken == tok then Hud.hideSay() end
	end)
	return hold
end
function Hud.think(text, opts)
	opts = opts or {}
	opts.thought = true
	return Hud.say("МОРТИ (ДУМАЕТ)", text, opts)
end
-- сказать и подождать, пока прочитают
function Hud.thinkWait(text, extra)
	local hold = Hud.think(text)
	U.wait(hold + (extra or 0.2))
end
function Hud.hideSay()
	subToken = subToken + 1
	local tok = subToken
	G.tween(subFrame, 0.25, { BackgroundTransparency = 1 })
	task.delay(0.26, function() if subToken == tok then subFrame.Visible = false end end)
end

---------------------------------------------------------------------------
-- подсказка-тост
---------------------------------------------------------------------------
local toastToken = 0
function Hud.toast(text, t)
	toastToken = toastToken + 1
	local tok = toastToken
	toastText.Text = text
	toastFrame.Visible = true
	toastFrame.BackgroundTransparency = 1
	toastText.TextTransparency = 1
	G.tween(toastFrame, 0.3, { BackgroundTransparency = 0.25 })
	G.tween(toastText, 0.3, { TextTransparency = 0 })
	task.delay(t or 4, function()
		if toastToken ~= tok then return end
		G.tween(toastFrame, 0.4, { BackgroundTransparency = 1 })
		G.tween(toastText, 0.4, { TextTransparency = 1 })
		task.delay(0.45, function() if toastToken == tok then toastFrame.Visible = false end end)
	end)
end

---------------------------------------------------------------------------
-- прицел
---------------------------------------------------------------------------
function Hud.crosshair(on) cross.Visible = on end
function Hud.crossFocus(on)
	G.tween(cross, 0.15, { Size = on and UDim2.fromOffset(14, 14) or UDim2.fromOffset(6, 6),
		BackgroundTransparency = on and 0.6 or 0.25 })
end

---------------------------------------------------------------------------
-- кнопка действия: ждёт нажатия клавиши (или тапа). keys — { Enum.KeyCode... }
-- Возвращает объект с :wait() и :cancel()
---------------------------------------------------------------------------
local actionId = 0
function Hud.action(text, keys, opts)
	opts = opts or {}
	actionId = actionId + 1
	local id = "RM_Action" .. actionId
	for _, c in ipairs(actionHolder:GetChildren()) do c:Destroy() end
	local pressed = U.signal()
	local done = false
	local btn = Instance.new("TextButton")
	btn.Name = "Btn"
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.Size = UDim2.fromOffset(10, 58)
	btn.AutomaticSize = Enum.AutomaticSize.X
	btn.BackgroundColor3 = Color3.fromRGB(10, 26, 14)
	btn.BackgroundTransparency = 0.15
	btn.Parent = actionHolder
	G.corner(btn, UDim.new(0.5, 0))
	G.stroke(btn, Config.Colors.UiLime, 2.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	G.pad(btn, 10, 0, 26, 0)
	G.list(btn, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local keyName = opts.keyLabel or (keys[1] and keys[1].Name) or "E"
	if keyName == "Space" then keyName = "ПРОБЕЛ" end
	if G.isTouch() then keyName = "ТАП" end
	local cap = G.frame(btn, { Name = "Key", Size = UDim2.fromOffset(10, 40), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Config.Colors.UiLime, LayoutOrder = 1 })
	G.corner(cap, 10)
	G.pad(cap, 12, 0, 12, 0)
	G.label(cap, keyName, { Size = UDim2.fromOffset(10, 40), AutomaticSize = Enum.AutomaticSize.X, FontFace = G.Fonts.Title,
		TextSize = 22, TextColor3 = Config.Colors.UiDark })
	G.label(btn, text, { Name = "Text", Size = UDim2.fromOffset(10, 58), AutomaticSize = Enum.AutomaticSize.X, FontFace = G.Fonts.Bold,
		TextSize = 26, LayoutOrder = 2 })
	actionHolder.Visible = true
	local scale = Instance.new("UIScale")
	scale.Parent = actionHolder
	scale.Scale = 0.6
	G.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	-- лёгкая пульсация
	local pulse = task.spawn(function()
		while not done do
			G.tween(scale, 0.7, { Scale = 1.04 }, Enum.EasingStyle.Sine)
			task.wait(0.7)
			if done then break end
			G.tween(scale, 0.7, { Scale = 1 }, Enum.EasingStyle.Sine)
			task.wait(0.7)
		end
	end)
	local _p = pulse
	local function fire()
		if done or U.paused then return end
		pressed:Fire()
	end
	btn.Activated:Connect(fire)
	ContextActionService:BindAction(id, function(_, state)
		if state == Enum.UserInputState.Begin then fire() end
		return Enum.ContextActionResult.Sink
	end, false, unpack(keys))
	local h = {}
	function h:cancel()
		if done then return end
		done = true
		ContextActionService:UnbindAction(id)
		G.tween(scale, 0.15, { Scale = 0.7 })
		task.delay(0.16, function()
			if btn.Parent then btn:Destroy() end
			if #actionHolder:GetChildren() <= 1 then actionHolder.Visible = false end
		end)
	end
	function h:wait()
		pressed.Event:Wait()
		Audio.play("Click", { volume = 0.4 })
		return true
	end
	-- ждать одно нажатие и убрать кнопку
	function h:once()
		self:wait()
		self:cancel()
	end
	h.pressed = pressed
	return h
end

---------------------------------------------------------------------------
-- маркер цели (ромб над предметом, виден сквозь стены)
---------------------------------------------------------------------------
local marker
function Hud.marker(part)
	if marker then marker:Destroy(); marker = nil end
	if not part then return end
	local bb = Instance.new("BillboardGui")
	bb.Name = "RM_Marker"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(80, 70)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.LightInfluence = 0
	bb.Adornee = part
	bb.Parent = G.playerGui()
	local d = G.frame(bb, { Name = "Diamond", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(22, 22),
		Rotation = 45, BackgroundColor3 = Config.Colors.UiLime })
	G.stroke(d, Config.Colors.UiDark, 2.5)
	local dist = G.label(bb, "", { Name = "Dist", Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 24), FontFace = G.Fonts.BodyBold,
		TextSize = 18 })
	G.stroke(dist, Color3.new(0, 0, 0), 1.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	marker = bb
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not bb.Parent then conn:Disconnect() return end
		local cam = workspace.CurrentCamera
		local m = (cam.CFrame.Position - part.Position).Magnitude / 3.5
		dist.Text = string.format("%d м", math.floor(m + 0.5))
		local a = math.clamp((m - 1.5) / 3, 0, 1)
		d.BackgroundTransparency = 1 - a
		dist.TextTransparency = 1 - a
	end)
end

---------------------------------------------------------------------------
-- заставка главы на чёрном фоне
---------------------------------------------------------------------------
function Hud.chapterCard(title, sub)
	local f = G.frame(overRoot, { Name = "Card", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 30 })
	local t = G.label(f, title, { Size = UDim2.new(1, 0, 0, 80), Position = UDim2.new(0, 0, 0.5, -70), FontFace = G.Fonts.Title,
		TextSize = 64, TextColor3 = Config.Colors.UiLime, TextTransparency = 1, ZIndex = 31 })
	local s = G.label(f, sub or "", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0.5, 20), FontFace = G.Fonts.Wide,
		TextSize = 26, TextTransparency = 1, ZIndex = 31 })
	G.tween(t, 1.0, { TextTransparency = 0 })
	U.wait(0.6)
	G.tween(s, 1.0, { TextTransparency = 0 })
	U.wait(2.4)
	G.tween(t, 0.8, { TextTransparency = 1 })
	G.tween(s, 0.8, { TextTransparency = 1 })
	U.wait(0.9)
	f:Destroy()
end

---------------------------------------------------------------------------
-- записка от мамы
---------------------------------------------------------------------------
function Hud.note(text)
	local sg, r = G.screen("Note", 40)
	local dim = G.modal(r, "Dim")
	dim.BackgroundTransparency = 1
	G.tween(dim, 0.3, { BackgroundTransparency = 0.45 })
	local paper = G.frame(r, { Name = "Paper", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(520, 440),
		BackgroundColor3 = Color3.fromRGB(255, 247, 194), Rotation = -2 })
	G.corner(paper, 6)
	G.stroke(paper, Color3.fromRGB(190, 170, 110), 2)
	for i = 0, 9 do
		G.frame(paper, { Size = UDim2.new(1, -60, 0, 2), Position = UDim2.fromOffset(30, 96 + i * 32), BackgroundColor3 = Color3.fromRGB(170, 200, 230), BackgroundTransparency = 0.3 })
	end
	G.label(paper, text, { Size = UDim2.new(1, -60, 1, -110), Position = UDim2.fromOffset(30, 54), FontFace = G.Fonts.Hand, TextSize = 40,
		TextColor3 = Color3.fromRGB(40, 70, 150), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.05 })
	G.frame(paper, { Name = "Tape", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(120, 34),
		BackgroundColor3 = Color3.fromRGB(240, 240, 220), BackgroundTransparency = 0.25, Rotation = 4 })
	G.tween(paper, 0.4, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
	Audio.play("Paper", { volume = 0.6 })
	local closed = U.signal()
	local holder = G.button(r, "Понятно", { size = Vector2.new(240, 56), textSize = 26, onClick = function() closed:Fire() end })
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0.5, 250)
	local kc = "RM_NoteClose"
	ContextActionService:BindAction(kc, function(_, st)
		if st == Enum.UserInputState.Begin then closed:Fire() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.E, Enum.KeyCode.Space, Enum.KeyCode.Return)
	closed.Event:Wait()
	ContextActionService:UnbindAction(kc)
	Audio.play("Paper", { volume = 0.4, speed = 1.2 })
	sg:Destroy()
end

---------------------------------------------------------------------------
-- кнопка паузы (справа сверху)
---------------------------------------------------------------------------
function Hud.pauseButton(onClick)
	local b = Instance.new("TextButton")
	b.Name = "PauseBtn"
	b.AnchorPoint = Vector2.new(1, 0)
	b.Position = UDim2.new(1, -20, 0, 16)
	b.Size = UDim2.fromOffset(52, 44)
	b.BackgroundColor3 = Color3.fromRGB(10, 26, 14)
	b.BackgroundTransparency = 0.25
	b.Text = "II"
	b.FontFace = G.Fonts.Title
	b.TextSize = 24
	b.TextColor3 = Config.Colors.UiLime
	b.Visible = false
	b.Parent = root
	G.corner(b, 12)
	G.stroke(b, Config.Colors.UiLime, 1.5, 0.3).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	b.Activated:Connect(onClick)
	Hud.pauseBtn = b
	return b
end

function Hud.gameplay(on)
	Hud.crosshair(on)
	if Hud.pauseBtn then Hud.pauseBtn.Visible = on end
end

-- «ретро-экран» в пиксельном мире: строки развёртки и тёмная рамка по краям
local retro
function Hud.retro(on)
	if retro then retro:Destroy(); retro = nil end
	if not on then return end
	retro = G.frame(overRoot, { Name = "Retro", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 })
	for y = 0, 1440, 4 do
		G.frame(retro, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.82, ZIndex = 2 })
	end
	for _, side in ipairs({ { 0, 0, 1, 0.16, 90 }, { 0, 0.84, 1, 0.16, -90 }, { 0, 0, 0.12, 1, 0 }, { 0.88, 0, 0.12, 1, 180 } }) do
		local f = G.frame(retro, { Position = UDim2.fromScale(side[1], side[2]), Size = UDim2.fromScale(side[3], side[4]),
			BackgroundColor3 = Color3.fromRGB(6, 0, 14), ZIndex = 2 })
		G.gradient(f, { Color3.new(0, 0, 0), Color3.new(0, 0, 0) }, side[5], NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }))
	end
end

function Hud.root() return root end
function Hud.overlay() return overRoot end

local _ui, _pl = UserInputService, Players
return Hud
