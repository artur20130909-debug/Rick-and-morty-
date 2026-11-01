-- Главное меню (вариант «Портал»), окно настроек, «Об игре» и меню паузы.
-- Фон меню — ночная комната Морти: Морти спит, посреди комнаты крутится портал.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Menu = {}
local ctx
local G, U, Config, Settings, Audio, Hud, Cine, World, Portal, B
local sg, root
local scene -- { portal, sleeper, conn }

---------------------------------------------------------------------------
-- Сцена меню: спящий Морти и портал
---------------------------------------------------------------------------
local function markers() return workspace.House:WaitForChild("Markers") end

local function buildSleeper(parent)
	local m = Instance.new("Model")
	m.Name = "RM_SleepingMorty"
	local head = markers():WaitForChild("BedHead").CFrame
	local P = B.kit(m, head)
	-- голова на подушке, повёрнута к стене, торчат волосы
	P.ball("Head", 1.25, 0, -0.1, 0.1, Config.Colors.Skin)
	P.ball("Hair", 1.35, -0.12, 0.08, 0.3, Config.Colors.MortyHair)
	P.ball("Tuft", 0.55, 0.15, 0.55, 0.45, Config.Colors.MortyHair)
	-- одеяло, под которым угадывается тело
	local function lump(name, size, x, y, z)
		local p = P.ball(name, 1, x, y, z, "#4A7AE0", Enum.Material.Fabric)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = size
		mesh.Parent = p
		return p
	end
	lump("Shoulders", Vector3.new(2.6, 0.9, 1.6), 0.1, -0.55, -1.2)
	lump("Body", Vector3.new(2.4, 0.8, 3.2), 0.2, -0.6, -2.9)
	lump("Knees", Vector3.new(1.3, 0.9, 1.4), 0.4, -0.45, -4.4)
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then p.CanCollide = false; p.CanQuery = false end
	end
	B.outline(m)
	m.Parent = parent
	return m
end

function Menu.sceneStart()
	if scene then return end
	scene = {}
	World.apply("night", 0)
	local mk = markers()
	local camCF = mk:WaitForChild("MenuCam").CFrame
	local pcf = mk:WaitForChild("PortalSpot").CFrame
	scene.sleeper = buildSleeper(workspace)
	ctx.Outline.add(scene.sleeper)
	scene.portal = Portal.new(pcf, 7.2, workspace)
	scene.portal:open(1.2)
	Cine.take(camCF, 62)
	Cine.breathe(0.6)
	-- лёгкий «дрейф» камеры
	local t0 = os.clock()
	scene.conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		Cine.setOffset(CFrame.new(math.sin(t * 0.21) * 0.35, math.sin(t * 0.17) * 0.18, 0) * CFrame.Angles(0, math.sin(t * 0.13) * 0.02, 0))
	end)
	Audio.music("MusicMenu", 2, 0.5)
end

function Menu.sceneStop()
	if not scene then return end
	if scene.conn then scene.conn:Disconnect() end
	Cine.setOffset(nil)
	if scene.portal then scene.portal:destroy() end
	if scene.sleeper then scene.sleeper:Destroy() end
	scene = nil
end

-- переход «в портал»: камера влетает в вихрь, вспышка
function Menu.enterPortal()
	if not scene then return end
	local p = scene.portal
	scene.conn:Disconnect()
	scene.conn = nil
	Cine.setOffset(nil)
	Audio.play("Whoosh", { volume = 0.9, speed = 0.85 })
	p:scaleTo(1.8, 1.4, Enum.EasingStyle.Quad)
	local target = p.cf * CFrame.new(0, 0, -0.5)
	local look = CFrame.lookAt(target.Position + p.cf.LookVector * 0.5, p.cf.Position)
	Cine.moveAsync(look, 1.6, "in", 95)
	U.wait(1.1)
	Hud.fadeWait(1, 0.5, Color3.fromRGB(200, 255, 150))
	Audio.stopMusic(1)
	Hud.fade(1, 0.6, Color3.new(0, 0, 0))
	U.wait(0.6)
end

---------------------------------------------------------------------------
-- Главное меню
---------------------------------------------------------------------------
local mainFrame, buttons
function Menu.show(onPlay)
	if mainFrame then mainFrame:Destroy() end
	mainFrame = G.frame(root, { Name = "Main", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	-- невидимая «модальная» кнопка: освобождает курсор, даже если камера до этого была от первого лица
	local free = G.modal(mainFrame, "FreeMouse")
	free.BackgroundTransparency = 1
	free.ZIndex = 0
	-- виньетка по краям, чтобы текст читался
	local vig = G.frame(mainFrame, { Name = "Vignette", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.2 })
	G.gradient(vig, { Color3.new(0, 0, 0), Color3.new(0, 0, 0) }, 90,
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.35, 0.9), NumberSequenceKeypoint.new(0.65, 0.9), NumberSequenceKeypoint.new(1, 0.2) }))
	local logo = G.logo(mainFrame, U.upper("Рик и Морти"), 104, UDim2.new(0.5, 0, 0, 34))
	local sub = G.label(mainFrame, Config.MenuSub or Config.Chapter, { Name = "Chapter", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 176),
		Size = UDim2.fromOffset(600, 34), FontFace = G.Fonts.Wide, TextSize = 24, TextColor3 = Color3.fromRGB(234, 255, 200) })
	G.stroke(sub, Config.Colors.UiDark, 3).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	local list = G.frame(mainFrame, { Name = "Buttons", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -76),
		Size = UDim2.fromOffset(420, 340), BackgroundTransparency = 1 })
	G.list(list, Enum.FillDirection.Vertical, 14, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
	buttons = {}
	local busy = false
	-- chapter: 1 — вся история с начала, 2 — сразу глава 2
	local function play(chapter)
		if busy then return end
		busy = true
		G.tween(mainFrame, 0.4, { Position = UDim2.fromOffset(0, 30) })
		for _, d in ipairs(mainFrame:GetDescendants()) do
			if d:IsA("TextLabel") or d:IsA("TextButton") then G.tween(d, 0.35, { TextTransparency = 1 }) end
			if d:IsA("GuiObject") then G.tween(d, 0.35, { BackgroundTransparency = 1 }) end
			if d:IsA("UIStroke") then G.tween(d, 0.35, { Transparency = 1 }) end
		end
		task.delay(0.4, function()
			mainFrame.Visible = false
			onPlay(chapter or 1)
		end)
	end
	local _, b1 = G.button(list, "ИГРАТЬ", { name = "Play", layoutOrder = 1, onClick = function() play(1) end })
	local _, b4 = G.button(list, "ГЛАВЫ", { name = "Chapters", layoutOrder = 2, style = "alt", onClick = function() Menu.chapters(play) end })
	local _, b2 = G.button(list, "НАСТРОЙКИ", { name = "Settings", layoutOrder = 3, onClick = function() Menu.settings() end })
	local _, b3 = G.button(list, "ОБ ИГРЕ", { name = "About", layoutOrder = 4, style = "alt", onClick = function() Menu.about() end })
	buttons = { b1, b4, b2, b3 }
	G.label(mainFrame, "фан-игра для друзей · сериал «Рик и Морти» принадлежит Adult Swim · v" .. Config.Version,
		{ Name = "Footer", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(900, 22),
			FontFace = G.Fonts.Body, TextSize = 15, TextColor3 = Color3.fromRGB(200, 220, 200), TextTransparency = 0.25 })
	-- появление
	logo.Position = UDim2.new(0.5, 0, 0, -160)
	G.tween(logo, 0.9, { Position = UDim2.new(0.5, 0, 0, 34) }, Enum.EasingStyle.Back)
	for i, b in ipairs(buttons) do
		local holder = b.Parent
		local sc = Instance.new("UIScale")
		sc.Scale = 0
		sc.Parent = holder
		task.delay(0.35 + i * 0.12, function() G.tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back) end)
	end
	-- «дыхание» логотипа
	task.spawn(function()
		local s = Instance.new("UIScale")
		s.Parent = logo
		while logo.Parent do
			G.tween(s, 1.6, { Scale = 1.025 }, Enum.EasingStyle.Sine)
			task.wait(1.6)
			if not logo.Parent then break end
			G.tween(s, 1.6, { Scale = 1 }, Enum.EasingStyle.Sine)
			task.wait(1.6)
		end
	end)
	-- Enter — играть
	ContextActionService:BindAction("RM_MenuEnter", function(_, st)
		if st == Enum.UserInputState.Begin and mainFrame.Visible and not Menu.modalOpen then play(1) end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)
	sg.Enabled = true
end

function Menu.hide()
	ContextActionService:UnbindAction("RM_MenuEnter")
	if mainFrame then mainFrame:Destroy(); mainFrame = nil end
end

---------------------------------------------------------------------------
-- Настройки (общие для меню и паузы)
---------------------------------------------------------------------------
Menu.modalOpen = false

local function slider(parent, order, label, key, min, max, fmt)
	local row = G.frame(parent, { Name = key, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = order })
	G.label(row, label, { Size = UDim2.new(0.42, 0, 1, 0), FontFace = G.Fonts.BodyBold, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left })
	local track = G.frame(row, { Name = "Track", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.45, 0, 0.5, 0), Size = UDim2.new(0.4, 0, 0, 10),
		BackgroundColor3 = Color3.fromRGB(6, 18, 10) })
	G.corner(track, UDim.new(0.5, 0))
	G.stroke(track, Config.Colors.UiLime, 1, 0.5)
	local fill = G.frame(track, { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Config.Colors.UiLime })
	G.corner(fill, UDim.new(0.5, 0))
	local knob = G.frame(track, { Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Color3.fromRGB(240, 255, 210) })
	G.corner(knob, UDim.new(0.5, 0))
	G.stroke(knob, Config.Colors.UiDark, 3)
	local value = G.label(row, "", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.13, 0, 1, 0),
		FontFace = G.Fonts.BodyBold, TextSize = 20, TextColor3 = Config.Colors.UiLime, TextXAlignment = Enum.TextXAlignment.Right })
	local function show(v)
		local a = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		value.Text = fmt(v)
	end
	show(Settings.get(key))
	local hit = Instance.new("TextButton")
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.new(1, 20, 0, 40)
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.fromScale(0.5, 0.5)
	hit.Parent = track
	local dragging = false
	local function setFromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		local v = min + (max - min) * a
		if max - min > 5 then v = math.floor(v + 0.5) else v = math.floor(v * 20 + 0.5) / 20 end
		Settings.set(key, v)
		show(v)
	end
	hit.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(io.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(io)
		if dragging and (io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch) then
			setFromX(io.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	return row, show
end

local function choice(parent, order, label, key, options)
	local row = G.frame(parent, { Name = key, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = order })
	G.label(row, label, { Size = UDim2.new(0.42, 0, 1, 0), FontFace = G.Fonts.BodyBold, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left })
	local box = G.frame(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0.55, 0, 0, 40), BackgroundTransparency = 1 })
	G.list(box, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local btns = {}
	local function refresh()
		local cur = Settings.get(key)
		for _, b in ipairs(btns) do
			local on = b.value == cur
			b.btn.BackgroundColor3 = on and Config.Colors.UiLime or Color3.fromRGB(6, 18, 10)
			b.btn.TextColor3 = on and Config.Colors.UiDark or Color3.fromRGB(220, 235, 220)
		end
	end
	for i, o in ipairs(options) do
		local b = Instance.new("TextButton")
		b.Name = "Opt" .. i
		b.AutoButtonColor = false
		b.Size = UDim2.fromOffset(o.w or 110, 38)
		b.Text = o.text
		b.FontFace = G.Fonts.Bold
		b.TextSize = 19
		b.LayoutOrder = i
		b.Parent = box
		G.corner(b, 10)
		G.stroke(b, Config.Colors.UiLime, 1.5, 0.3).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		b.Activated:Connect(function()
			Audio.play("Click", { volume = 0.5 })
			Settings.set(key, o.value)
			refresh()
		end)
		table.insert(btns, { btn = b, value = o.value })
	end
	refresh()
	return row, refresh
end

function Menu.settings(onClose)
	if Menu.modalOpen then return end
	Menu.modalOpen = true
	local layer = G.frame(root, { Name = "SettingsLayer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 })
	local dim = G.modal(layer, "Dim")
	dim.BackgroundTransparency = 1
	G.tween(dim, 0.25, { BackgroundTransparency = 0.4 })
	local panel, sc = G.panel(layer, 760, 640, "НАСТРОЙКИ")
	sc.Scale = 0.85
	G.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(44, 88)
	body.Size = UDim2.new(1, -88, 1, -184)
	body.CanvasSize = UDim2.fromOffset(0, 0)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollBarThickness = 6
	body.ScrollBarImageColor3 = Config.Colors.UiLime
	body.Parent = panel
	G.list(body, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)
	local pct = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end
	local refreshers = {}
	local _, r1 = slider(body, 1, "Музыка", "Music", 0, 1, pct)
	local _, r2 = slider(body, 2, "Звуки", "Sfx", 0, 1, pct)
	local _, r3 = slider(body, 3, "Чувствительность мыши", "Sensitivity", 0.2, 2, function(v) return string.format("%.2f", v) end)
	local _, r4 = slider(body, 4, "Поле зрения", "Fov", 60, 95, function(v) return tostring(math.floor(v)) .. "°" end)
	local onoff = { { text = "Вкл", value = true, w = 90 }, { text = "Выкл", value = false, w = 90 } }
	local _, r5 = choice(body, 5, "Покачивание камеры", "HeadBob", onoff)
	local _, r6 = choice(body, 6, "Контуры предметов", "Outlines", onoff)
	local _, r7 = choice(body, 7, "Эффекты", "Effects", { { text = "Низко", value = 1, w = 100 }, { text = "Средне", value = 2, w = 108 }, { text = "Высоко", value = 3, w = 108 } })
	local _, r8 = choice(body, 8, "Размер субтитров", "Subtitles", { { text = "S", value = 1, w = 60 }, { text = "M", value = 2, w = 60 }, { text = "L", value = 3, w = 60 } })
	local _, r9 = choice(body, 9, "Подсказки и маркер цели", "Hints", onoff)
	refreshers = { function() r1(Settings.get("Music")) end, function() r2(Settings.get("Sfx")) end, function() r3(Settings.get("Sensitivity")) end,
		function() r4(Settings.get("Fov")) end, r5, r6, r7, r8, r9 }
	local foot = G.frame(panel, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22), Size = UDim2.fromOffset(600, 66), BackgroundTransparency = 1 })
	G.list(foot, Enum.FillDirection.Horizontal, 18, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local closing = false
	local function close()
		if closing then return end
		closing = true
		G.tween(sc, 0.18, { Scale = 0.9 })
		G.tween(dim, 0.18, { BackgroundTransparency = 1 })
		task.delay(0.2, function()
			layer:Destroy()
			Menu.modalOpen = false
			if onClose then onClose() end
		end)
	end
	G.button(foot, "СБРОСИТЬ", { size = Vector2.new(230, 56), textSize = 24, style = "alt", layoutOrder = 1, onClick = function()
		Settings.reset()
		for _, f in ipairs(refreshers) do f() end
	end })
	G.button(foot, "ГОТОВО", { name = "Done", size = Vector2.new(230, 56), textSize = 24, layoutOrder = 2, onClick = close })
	Menu.closeSettings = close
end

-- выбор главы: карточки глав; onPick(номер)
function Menu.chapters(onPick)
	if Menu.modalOpen then return end
	Menu.modalOpen = true
	local layer = G.frame(root, { Name = "ChaptersLayer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 })
	local dim = G.modal(layer, "Dim")
	dim.BackgroundTransparency = 0.4
	local panel, sc = G.panel(layer, 760, 470, "ГЛАВЫ")
	sc.Scale = 0.85
	G.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	local function close()
		layer:Destroy()
		Menu.modalOpen = false
	end
	for i, ch in ipairs(Config.Chapters) do
		local y = 96 + (i - 1) * 120
		local holder = G.button(panel, ch.title, { name = "Chapter" .. ch.id, size = Vector2.new(560, 64), textSize = 28,
			style = (i == #Config.Chapters) and "main" or "alt",
			onClick = function()
				close()
				onPick(ch.id)
			end })
		holder.AnchorPoint = Vector2.new(0.5, 0)
		holder.Position = UDim2.new(0.5, 0, 0, y)
		G.label(panel, ch.text, { Name = "ChapterText" .. ch.id, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y + 74),
			Size = UDim2.fromOffset(640, 26), FontFace = G.Fonts.Body, TextSize = 19, TextColor3 = Color3.fromRGB(205, 230, 205) })
	end
	local back = G.button(panel, "НАЗАД", { name = "Back", size = Vector2.new(220, 52), textSize = 22, style = "ghost", onClick = close })
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.new(0.5, 0, 1, -20)
end

function Menu.about()
	if Menu.modalOpen then return end
	Menu.modalOpen = true
	local layer = G.frame(root, { Name = "AboutLayer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 })
	local dim = G.modal(layer, "Dim")
	dim.BackgroundTransparency = 0.4
	local panel, sc = G.panel(layer, 760, 560, "ОБ ИГРЕ")
	sc.Scale = 0.85
	G.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	local text = table.concat({
		"Фан-игра по мультсериалу «Рик и Морти» — для нас с друзьями.",
		"Глава 1 «Сбой»: обычное утро Морти. Или не совсем обычное…",
		"Глава 2 «Вторжение»: Пожиратели добрались до нашей вселенной.",
		"",
		"УПРАВЛЕНИЕ",
		"WASD — ходить  ·  Shift — бежать  ·  мышь — смотреть",
		"E — действие  ·  F — телефон  ·  P — пауза",
		"На телефоне: джойстик слева, нажимай на подсказки и кнопки.",
		"",
		"Сериал и персонажи принадлежат Adult Swim. Игра не официальная.",
	}, "\n")
	G.label(panel, text, { Position = UDim2.fromOffset(50, 92), Size = UDim2.new(1, -100, 1, -190), FontFace = G.Fonts.Body, TextSize = 21,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.2 })
	local holder = G.button(panel, "ЗАКРЫТЬ", { size = Vector2.new(240, 56), textSize = 24, onClick = function()
		layer:Destroy()
		Menu.modalOpen = false
	end })
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -22)
end

---------------------------------------------------------------------------
-- Пауза
---------------------------------------------------------------------------
local pauseLayer
function Menu.pause(onResume, onMainMenu)
	if pauseLayer then return end
	pauseLayer = G.frame(root, { Name = "PauseLayer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4 })
	local dim = G.modal(pauseLayer, "Dim")
	dim.BackgroundTransparency = 1
	G.tween(dim, 0.25, { BackgroundTransparency = 0.35 })
	local title = G.logo(pauseLayer, "ПАУЗА", 80, UDim2.new(0.5, 0, 0, 80))
	local _ = title
	local list = G.frame(pauseLayer, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(420, 260), BackgroundTransparency = 1 })
	G.list(list, Enum.FillDirection.Vertical, 14, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	G.button(list, "ПРОДОЛЖИТЬ", { name = "Resume", layoutOrder = 1, onClick = function() Menu.unpause(); onResume() end })
	G.button(list, "НАСТРОЙКИ", { name = "Settings", layoutOrder = 2, onClick = function() Menu.settings() end })
	G.button(list, "ГЛАВНОЕ МЕНЮ", { name = "MainMenu", layoutOrder = 3, style = "alt", onClick = function() Menu.unpause(); onMainMenu() end })
	sg.Enabled = true
end
function Menu.unpause()
	if pauseLayer then pauseLayer:Destroy(); pauseLayer = nil end
	if Menu.modalOpen and Menu.closeSettings then Menu.closeSettings() end
end
function Menu.isPaused() return pauseLayer ~= nil end

function Menu.init(c)
	ctx = c
	G, U, Config, Settings, Audio, Hud, Cine, World, Portal, B = c.Gui, c.Util, c.Config, c.Settings, c.Audio, c.Hud, c.Cine, c.World, c.Portal, c.Build
	local s, r = G.screen("Menu", 20)
	sg, root = s, r
end

local _p = Players
return Menu
