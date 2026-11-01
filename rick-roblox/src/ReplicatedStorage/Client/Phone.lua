-- Телефон Морти: 3D-телефон в руке перед камерой и его экран (SurfaceGui): блокировка,
-- рабочий стол, «ТикТок» с роликами, лаги и глитч (сбой). Всё нарисовано рамками GUI.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Phone = {}
Phone.__index = Phone
local Config, B, Audio, G, U, Outline

local W, H = 240, 500 -- холст экрана в пикселях

function Phone.init(ctx)
	Config, B, Audio, G, U, Outline = ctx.Config, ctx.Build, ctx.Audio, ctx.Gui, ctx.Util, ctx.Outline
end

local function frame(parent, x, y, w, h, color, props)
	local f = Instance.new("Frame")
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = B.color(color or "#000000")
	f.BorderSizePixel = 0
	if props then for k, v in pairs(props) do f[k] = v end end
	f.Parent = parent
	return f
end
local function text(parent, x, y, w, h, str, size, color, fnt, props)
	local l = Instance.new("TextLabel")
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, h)
	l.BackgroundTransparency = 1
	l.Text = str
	l.TextSize = size
	l.TextColor3 = B.color(color or "#ffffff")
	l.FontFace = fnt or G.Fonts.BodyBold
	l.TextXAlignment = Enum.TextXAlignment.Left
	if props then for k, v in pairs(props) do l[k] = v end end
	l.Parent = parent
	return l
end
local function round(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r or 8)
	c.Parent = obj
	return c
end

---------------------------------------------------------------------------
-- модель телефона и руки
---------------------------------------------------------------------------
function Phone.new()
	local self = setmetatable({}, Phone)
	local m = Instance.new("Model")
	m.Name = "RM_Phone"
	self.model = m
	local function p(name, size, color, mat, props)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = B.color(color)
		part.Material = mat or Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		if props then for k, v in pairs(props) do part[k] = v end end
		part.Parent = m
		return part
	end
	-- корпус в локальных координатах телефона (центр экрана — 0,0,0; экран смотрит в −Z)
	self.parts = {
		{ p("Body", Vector3.new(0.64, 1.3, 0.075), "#1C1D22"), CFrame.new(0, 0, 0.02) },
		{ p("Edge", Vector3.new(0.66, 1.28, 0.05), "#3A3C44", Enum.Material.Metal), CFrame.new(0, 0, 0.03) },
		{ p("Camera", Vector3.new(0.16, 0.16, 0.03), "#2B2C33"), CFrame.new(-0.18, 0.5, 0.07) },
		{ p("Palm", Vector3.new(0.5, 0.55, 0.22), Config.Colors.Skin), CFrame.new(0.1, -0.52, 0.19) * CFrame.Angles(0, 0, math.rad(-12)) },
		{ p("Thumb", Vector3.new(0.13, 0.36, 0.13), Config.Colors.Skin), CFrame.new(0.33, -0.18, -0.02) * CFrame.Angles(0, 0, math.rad(20)) },
		{ p("Fingers", Vector3.new(0.12, 0.6, 0.14), Config.Colors.Skin), CFrame.new(-0.35, -0.15, 0.05) },
		{ p("Sleeve", Vector3.new(0.6, 0.5, 0.5), Config.Colors.MortyShirt), CFrame.new(0.28, -1.05, 0.42) * CFrame.Angles(math.rad(-25), 0, math.rad(-18)) },
		{ p("Arm", Vector3.new(0.34, 0.8, 0.34), Config.Colors.Skin), CFrame.new(0.18, -0.85, 0.32) * CFrame.Angles(math.rad(-25), 0, math.rad(-14)) },
	}
	local screen = p("Screen", Vector3.new(0.585, 1.22, 0.01), "#000000", Enum.Material.SmoothPlastic)
	table.insert(self.parts, { screen, CFrame.new(0, 0, -0.022) })
	self.screen = screen
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Display"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(W, H)
	sg.LightInfluence = 0
	sg.Brightness = 1.25
	sg.ClipsDescendants = true
	sg.Parent = screen
	self.gui = sg
	self.canvas = frame(sg, 0, 0, W, H, "#000000", { Name = "Canvas", ClipsDescendants = true })
	self.offset = CFrame.new(0.3, -1.6, -1.2)
	self.target = self.offset
	self.alpha = 0
	self.t = 0
	self.shake = 0
	self.anims = {} -- функции анимации экрана (dt, t)
	m.Parent = workspace.CurrentCamera
	-- после камеры сценки (Camera + 2), чтобы телефон не отставал на кадр
	self.bind = "RM_Phone" .. tostring(math.random(1, 1e6))
	RunService:BindToRenderStep(self.bind, Enum.RenderPriority.Camera.Value + 5, function(dt) self:update(dt) end)
	return self
end

local SHOW_CF = CFrame.new(0.26, -0.14, -1.58) * CFrame.Angles(math.rad(10), math.rad(-9), math.rad(3))
local HIDE_CF = CFrame.new(0.35, -1.7, -1.1) * CFrame.Angles(math.rad(-30), math.rad(-8), math.rad(10))

function Phone:update(dt)
	if U.paused then return end
	self.t = self.t + dt
	local cam = workspace.CurrentCamera
	self.offset = self.offset:Lerp(self.target, 1 - math.exp(-7 * dt))
	local sway = CFrame.Angles(math.sin(self.t * 1.3) * 0.012, math.sin(self.t * 0.9) * 0.015, 0) * CFrame.new(0, math.sin(self.t * 1.7) * 0.008, 0)
	if self.shake > 0 then
		self.shake = math.max(0, self.shake - dt)
		local k = self.shake * 2
		sway = sway * CFrame.new(math.noise(self.t * 40, 1) * 0.03 * k, math.noise(self.t * 40, 2) * 0.03 * k, 0) * CFrame.Angles(0, 0, math.noise(self.t * 30, 3) * 0.06 * k)
	end
	local base = cam.CFrame * self.offset * sway
	for _, e in ipairs(self.parts) do
		e[1].CFrame = base * e[2]
	end
	for _, f in ipairs(self.anims) do f(dt, self.t) end
end

function Phone:raise()
	Audio.play("PhoneOut", { volume = 0.7 })
	self.offset = HIDE_CF
	self.target = SHOW_CF
end
function Phone:lower()
	self.target = HIDE_CF
end
function Phone:vibrate(t)
	self.shake = t or 0.6
	Audio.play("Vibrate", { volume = 0.8 })
end
function Phone:clear()
	self.anims = {}
	for _, c in ipairs(self.canvas:GetChildren()) do c:Destroy() end
end
function Phone:destroy()
	if self.bind then RunService:UnbindFromRenderStep(self.bind) end
	Audio.stop("tiktok")
	self.model:Destroy()
end

---------------------------------------------------------------------------
-- экраны
---------------------------------------------------------------------------
local function statusBar(parent, dark)
	local col = dark and "#111111" or "#ffffff"
	text(parent, 16, 6, 60, 18, "7:42", 13, col)
	text(parent, W - 80, 6, 64, 18, "▮▮▮  23%", 12, col, nil, { TextXAlignment = Enum.TextXAlignment.Right })
	local notch = frame(parent, W / 2 - 34, 6, 68, 18, "#000000")
	round(notch, UDim.new(0.5, 0))
end

local function wallpaper(parent)
	local wp = frame(parent, 0, 0, W, H, "#ffffff", { Name = "Wallpaper" })
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(125, 240, 90)), ColorSequenceKeypoint.new(0.45, Color3.fromRGB(42, 158, 58)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 30, 18)) })
	g.Rotation = 90
	g.Parent = wp
	-- «пятна» на обоях
	for i = 1, 5 do
		local c = frame(wp, (i * 53) % 200 - 20, 60 + (i * 97) % 380, 80 + i * 8, 80 + i * 8, "#ffffff", { BackgroundTransparency = 0.88 })
		round(c, UDim.new(0.5, 0))
	end
	return wp
end

function Phone:lockScreen()
	self:clear()
	local root = frame(self.canvas, 0, 0, W, H, "#000000", { Name = "Lock" })
	self.lock = root
	wallpaper(root)
	statusBar(root)
	text(root, 0, 64, W, 70, "7:42", 66, "#ffffff", G.Fonts.Wide, { TextXAlignment = Enum.TextXAlignment.Center })
	text(root, 0, 136, W, 20, "понедельник, 3 ноября", 14, "#ffffff", G.Fonts.Body, { TextXAlignment = Enum.TextXAlignment.Center })
	local function note(y, icon, iconCol, title, body)
		local n = frame(root, 12, y, W - 24, 58, "#ffffff", { BackgroundTransparency = 0.78 })
		round(n, 14)
		local ic = frame(n, 10, 12, 34, 34, iconCol)
		round(ic, 8)
		text(ic, 0, 0, 34, 34, icon, 18, "#ffffff", G.Fonts.Title, { TextXAlignment = Enum.TextXAlignment.Center })
		text(n, 54, 9, W - 90, 16, title, 13, "#ffffff", G.Fonts.BodyBold)
		text(n, 54, 26, W - 90, 26, body, 11, "#ffffff", G.Fonts.Body, { TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
		return n
	end
	note(190, "♪", "#111111", "ТикТок", "3 новых видео для тебя")
	note(256, "М", "#E8A53A", "Мама", "Хорошего дня в школе! ❤")
	text(root, 0, H - 52, W, 18, "проведи вверх", 12, "#ffffff", G.Fonts.Body, { TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 0.2 })
	frame(root, W / 2 - 50, H - 22, 100, 5, "#ffffff", { BackgroundTransparency = 0.1 })
	Audio.play("Notify", { volume = 0.4 })
end

-- разблокировка и запуск ТикТока
function Phone:openTikTok()
	Audio.play("Swipe", { volume = 0.5 })
	if self.lock then
		TweenService:Create(self.lock, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(0, -H) }):Play()
	end
	-- рабочий стол
	local home = frame(self.canvas, 0, 0, W, H, "#000000", { Name = "Home", ZIndex = 0 })
	wallpaper(home)
	statusBar(home)
	local apps = {
		{ "ТикТок", "#111111", "♪" }, { "Камера", "#3A3C44", "◉" }, { "Музыка", "#E2504A", "♫" }, { "Карты", "#4A90D0", "➤" },
		{ "Чат", "#3BB273", "✉" }, { "Игры", "#8E5BB5", "★" }, { "Погода", "#F2B33C", "☀" }, { "Фото", "#E07B39", "▣" },
	}
	local tik
	for i, a in ipairs(apps) do
		local cx = ((i - 1) % 4) * 56 + 14
		local cy = math.floor((i - 1) / 4) * 76 + 70
		local ic = frame(home, cx, cy, 46, 46, a[2])
		round(ic, 12)
		text(ic, 0, 0, 46, 46, a[3], 22, "#ffffff", G.Fonts.Title, { TextXAlignment = Enum.TextXAlignment.Center })
		text(home, cx - 6, cy + 50, 58, 14, a[1], 10, "#ffffff", G.Fonts.Body, { TextXAlignment = Enum.TextXAlignment.Center })
		if i == 1 then tik = ic end
	end
	U.wait(0.8)
	-- «нажатие» на ТикТок
	Audio.play("PhoneTap", { volume = 0.6 })
	local ring = frame(home, 14 - 6, 70 - 6, 58, 58, "#ffffff", { BackgroundTransparency = 0.5 })
	round(ring, 16)
	U.wait(0.25)
	-- заставка приложения
	local splash = frame(self.canvas, 0, 0, W, H, "#000000", { Name = "Splash" })
	splash.Size = UDim2.fromOffset(46, 46)
	splash.Position = UDim2.fromOffset(tik.Position.X.Offset, tik.Position.Y.Offset)
	TweenService:Create(splash, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(W, H), Position = UDim2.fromOffset(0, 0) }):Play()
	local logo = frame(splash, 0, 0, W, H, "#000000", { BackgroundTransparency = 1 })
	text(logo, 4, H / 2 - 64, W, 80, "♪", 72, "#25F4EE", G.Fonts.Title, { TextXAlignment = Enum.TextXAlignment.Center })
	text(logo, -4, H / 2 - 60, W, 80, "♪", 72, "#FE2C55", G.Fonts.Title, { TextXAlignment = Enum.TextXAlignment.Center })
	text(logo, 0, H / 2 - 62, W, 80, "♪", 72, "#ffffff", G.Fonts.Title, { TextXAlignment = Enum.TextXAlignment.Center })
	text(logo, 0, H / 2 + 20, W, 30, "ТикТок", 26, "#ffffff", G.Fonts.Title, { TextXAlignment = Enum.TextXAlignment.Center })
	U.wait(1.0)
	home:Destroy()
	if self.lock then self.lock:Destroy(); self.lock = nil end
	self.splash = splash
end

-- интерфейс ленты поверх ролика
local function feedChrome(parent, nick, caption, likes, song)
	text(parent, 0, 28, W, 20, "Подписки    |    Рекомендации", 13, "#ffffff", G.Fonts.BodyBold, { TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 0.1 })
	local side = frame(parent, W - 50, 200, 44, 240, "#000000", { BackgroundTransparency = 1 })
	local av = frame(side, 4, 0, 36, 36, "#F2D85A")
	round(av, UDim.new(0.5, 0))
	local function icon(y, sym, count)
		text(side, 0, y, 44, 30, sym, 26, "#ffffff", G.Fonts.Title, { TextXAlignment = Enum.TextXAlignment.Center })
		return text(side, 0, y + 28, 44, 14, count, 11, "#ffffff", G.Fonts.BodyBold, { TextXAlignment = Enum.TextXAlignment.Center })
	end
	local likeLabel = icon(52, "♥", likes)
	icon(106, "✎", "1 204")
	icon(160, "➦", "877")
	text(parent, 12, H - 112, W - 70, 18, nick, 15, "#ffffff", G.Fonts.Title)
	local cap = text(parent, 12, H - 92, W - 70, 40, caption, 12, "#ffffff", G.Fonts.Body, { TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	text(parent, 12, H - 48, W - 70, 16, "♫ " .. song, 11, "#ffffff", G.Fonts.Body)
	local barBg = frame(parent, 0, H - 26, W, 3, "#ffffff", { BackgroundTransparency = 0.7 })
	local bar = frame(barBg, 0, 0, 0, 3, "#ffffff")
	-- нижнее меню
	local nav = frame(parent, 0, H - 22, W, 22, "#000000")
	text(nav, 0, 2, W, 18, "Главная   Друзья   ＋   Входящие   Профиль", 10, "#ffffff", G.Fonts.Body, { TextXAlignment = Enum.TextXAlignment.Center })
	return { like = likeLabel, bar = bar, caption = cap }
end

-- ролик 1: кот танцует
function Phone:video1()
	if self.splash then self.splash:Destroy(); self.splash = nil end
	local v = frame(self.canvas, 0, 0, W, H, "#ffffff", { Name = "Video1", ClipsDescendants = true })
	local bg = Instance.new("UIGradient")
	bg.Rotation = 120
	bg.Parent = v
	local floorF = frame(v, 0, 330, W, 170, "#6A4A8A")
	local cat = frame(v, W / 2 - 60, 170, 120, 170, "#000000", { BackgroundTransparency = 1, Name = "Cat" })
	local body = frame(cat, 20, 70, 80, 90, "#F09A3A")
	round(body, 30)
	local head = frame(cat, 15, 0, 90, 80, "#F4A848")
	round(head, UDim.new(0.45, 0))
	local earL = frame(head, 8, -10, 26, 26, "#F4A848", { Rotation = 45 })
	local earR = frame(head, 56, -10, 26, 26, "#F4A848", { Rotation = 45 })
	local _e1, _e2 = earL, earR
	local eyeL = frame(head, 22, 28, 14, 18, "#1B1B22")
	local eyeR = frame(head, 54, 28, 14, 18, "#1B1B22")
	round(eyeL, UDim.new(0.5, 0))
	round(eyeR, UDim.new(0.5, 0))
	frame(head, 40, 50, 10, 6, "#E2504A")
	local glasses = frame(head, 16, 26, 58, 6, "#111111")
	local _g = glasses
	local pawL = frame(cat, -6, 86, 26, 18, "#F4A848")
	local pawR = frame(cat, 100, 86, 26, 18, "#F4A848")
	round(pawL, 8)
	round(pawR, 8)
	local cup = frame(cat, 96, 70, 22, 26, "#FFFFFF")
	round(cup, 4)
	local ui = feedChrome(v, "@кот_борис", "утренний вайб ☕ #котики #утро #понедельник", "48,2 тыс.", "оригинальный звук — кот_борис")
	self.video = v
	self.ui = ui
	self.song = Audio.loop("tiktok", "TikTokSong", { volume = 0.55 })
	local likes = 48200
	table.insert(self.anims, function(dt, t)
		local beat = t * 2.1 * math.pi
		cat.Position = UDim2.fromOffset(W / 2 - 60 + math.sin(beat / 2) * 18, 170 - math.abs(math.sin(beat)) * 22)
		cat.Rotation = math.sin(beat / 2) * 9
		pawL.Position = UDim2.fromOffset(-6, 86 - math.abs(math.sin(beat)) * 30)
		pawR.Position = UDim2.fromOffset(100, 86 - math.abs(math.cos(beat)) * 30)
		local h = (t * 0.08) % 1
		bg.Color = ColorSequence.new(Color3.fromHSV(h, 0.55, 1), Color3.fromHSV((h + 0.25) % 1, 0.65, 0.95))
		floorF.BackgroundColor3 = Color3.fromHSV((h + 0.5) % 1, 0.4, 0.55)
		ui.bar.Size = UDim2.fromOffset((t * 18) % W, 3)
		likes = likes + math.random(0, 3)
		ui.like.Text = string.format("%.1f тыс.", likes / 1000):gsub("%.", ",")
	end)
end

-- пролистать к ролику 2 (портал «своими руками»)
function Phone:swipeToVideo2()
	Audio.play("Swipe", { volume = 0.6 })
	Audio.stop("tiktok", 0.2)
	local old = self.video
	local v = frame(self.canvas, 0, H, W, H, "#0E1418", { Name = "Video2", ClipsDescendants = true })
	-- «гараж»: стена, верстак, лампа
	frame(v, 0, 0, W, 300, "#2A3138")
	frame(v, 0, 300, W, 200, "#1B2126")
	local bench = frame(v, 20, 270, 200, 24, "#6B4A2E")
	local _b = bench
	local lamp = frame(v, 100, 0, 40, 60, "#C9C2A0")
	local _l = lamp
	-- зарождающийся портал
	local por = frame(v, W / 2 - 10, 160, 20, 20, "#7CFF4A")
	round(por, UDim.new(0.5, 0))
	local pg = Instance.new("UIGradient")
	pg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 255, 170)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 230, 70)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 140, 40)) })
	pg.Parent = por
	local hand = frame(v, -40, 230, 90, 26, "#F1D2B0")
	round(hand, 10)
	local ui = feedChrome(v, "@наука_по_фактам", "Как открыть портал в другое измерение прямо в гараже 😱 #наука #лайфхак", "1,3 млн", "оригинальный звук — наука_по_фактам")
	TweenService:Create(v, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Position = UDim2.fromOffset(0, 0) }):Play()
	if old then
		TweenService:Create(old, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Position = UDim2.fromOffset(0, -H) }):Play()
		task.delay(0.45, function() old:Destroy() end)
	end
	self.anims = {}
	self.video = v
	self.ui = ui
	self.v2 = { por = por, pg = pg, hand = hand, t = 0, frozen = false }
	local st = self.v2
	table.insert(self.anims, function(dt)
		if st.frozen then return end
		st.t = st.t + dt
		local s = 20 + math.min(st.t, 4) * 22
		por.Size = UDim2.fromOffset(s, s)
		por.Position = UDim2.fromOffset(W / 2 - s / 2, 170 - s / 2)
		pg.Rotation = (pg.Rotation + dt * 160) % 360
		hand.Position = UDim2.fromOffset(-40 + math.sin(st.t * 3) * 10, 230)
		ui.bar.Size = UDim2.fromOffset(math.min(W, st.t * 22), 3)
	end)
	task.delay(0.4, function()
		self.song = Audio.loop("tiktok", "TikTokSong", { volume = 0.5, speed = 0.92 })
	end)
end

-- лаги: ролик замирает, крутится загрузка, звук заикается
function Phone:lag(seconds)
	local st = self.v2
	if not st then return end
	local spinner = frame(self.video, W / 2 - 22, H / 2 - 22, 44, 44, "#ffffff", { BackgroundTransparency = 1, Name = "Spinner" })
	local ring = Instance.new("UIStroke")
	ring.Thickness = 5
	ring.Color = Color3.new(1, 1, 1)
	ring.Parent = spinner
	round(spinner, UDim.new(0.5, 0))
	local sg = Instance.new("UIGradient")
	sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(0.51, 1), NumberSequenceKeypoint.new(1, 1) })
	sg.Parent = ring
	spinner.Visible = false
	local tEnd = self.t + (seconds or 4)
	local song = self.song
	table.insert(self.anims, function(dt, t)
		if t > tEnd then
			st.frozen = true
			spinner.Visible = true
			sg.Rotation = (sg.Rotation + dt * 400) % 360
			return
		end
		-- рывками: стоп-ход
		local phase = (t * 1.7) % 1
		st.frozen = phase > 0.45
		spinner.Visible = st.frozen
		sg.Rotation = (sg.Rotation + dt * 400) % 360
		if song and song.Parent then
			if st.frozen and song.IsPlaying then song:Pause()
			elseif not st.frozen and not song.IsPlaying then song:Resume() end
		end
		if st.frozen and math.random() < 0.08 then
			self.ui.bar.Size = UDim2.fromOffset(math.max(0, self.ui.bar.Size.X.Offset - 20), 3)
		end
	end)
end

-- глитч: разрывы, цветные полосы, шум, «портал» на весь экран, потом чёрный экран
function Phone:glitch(duration)
	duration = duration or 3
	Audio.stop("tiktok")
	Audio.play("Glitch", { volume = 0.9 })
	local layer = frame(self.canvas, 0, 0, W, H, "#000000", { BackgroundTransparency = 1, Name = "Glitch", ZIndex = 50 })
	local bars = {}
	for i = 1, 16 do
		local b = frame(layer, 0, 0, W, 10, "#000000", { ZIndex = 51 })
		table.insert(bars, b)
	end
	local noise = {}
	for i = 1, 40 do
		table.insert(noise, frame(layer, 0, 0, 8, 8, "#ffffff", { ZIndex = 52 }))
	end
	local flash = frame(layer, 0, 0, W, H, "#7CFF4A", { BackgroundTransparency = 1, ZIndex = 53 })
	local err = text(layer, 0, H / 2 - 20, W, 40, "ОШИБКА ВОСПРОИЗВЕДЕНИЯ", 16, "#ffffff", G.Fonts.Wide, { TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 54, TextTransparency = 1 })
	local swirl = frame(layer, W / 2, H / 2, 0, 0, "#7CFF4A", { ZIndex = 55, AnchorPoint = Vector2.new(0.5, 0.5) })
	round(swirl, UDim.new(0.5, 0))
	local sgr = Instance.new("UIGradient")
	sgr.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 255, 180)), ColorSequenceKeypoint.new(0.2, Color3.fromRGB(110, 230, 70)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(30, 140, 40)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(110, 230, 70)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(235, 255, 180)), ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 140, 40)) })
	sgr.Parent = swirl
	local caption = self.ui and self.ui.caption
	local orig = caption and caption.Text or ""
	local glyphs = { "▓", "░", "█", "#", "%", "@", "Ж", "Ψ", "¤", "∆" }
	local t0 = self.t
	self:vibrate(duration)
	table.insert(self.anims, function(dt, t)
		local k = math.clamp((t - t0) / duration, 0, 1)
		for i, b in ipairs(bars) do
			local on = math.random() < 0.25 + k * 0.5
			b.Visible = on
			if on then
				b.Position = UDim2.fromOffset(math.random(-40, 40) * k, math.random(0, H))
				b.Size = UDim2.fromOffset(W + 80, math.random(3, 22))
				local c = math.random(1, 4)
				b.BackgroundColor3 = (c == 1 and Color3.fromRGB(255, 40, 120)) or (c == 2 and Color3.fromRGB(40, 240, 255)) or (c == 3 and Color3.fromRGB(124, 255, 74)) or Color3.new(0, 0, 0)
				b.BackgroundTransparency = 0.2 + math.random() * 0.5
			end
		end
		for _, n in ipairs(noise) do
			n.Visible = math.random() < 0.3 + k * 0.6
			n.Position = UDim2.fromOffset(math.random(0, W), math.random(0, H))
			local s = math.random(2, 10)
			n.Size = UDim2.fromOffset(s * 2, s)
			n.BackgroundColor3 = math.random() < 0.5 and Color3.new(1, 1, 1) or Color3.fromRGB(124, 255, 74)
		end
		flash.BackgroundTransparency = math.random() < 0.12 + k * 0.2 and 0.4 or 1
		err.TextTransparency = (k > 0.3 and math.random() < 0.6) and 0 or 1
		err.Position = UDim2.fromOffset(math.random(-6, 6), H / 2 - 20 + math.random(-4, 4))
		if caption then
			local out = {}
			for _, c in utf8.codes(orig) do
				if math.random() < k * 0.8 then table.insert(out, glyphs[math.random(1, #glyphs)]) else table.insert(out, utf8.char(c)) end
			end
			caption.Text = table.concat(out)
		end
		-- в конце вихрь заполняет экран
		if k > 0.6 then
			local s = (k - 0.6) / 0.4 * (H * 1.6)
			swirl.Size = UDim2.fromOffset(s, s)
			sgr.Rotation = (sgr.Rotation + dt * 520) % 360
		end
	end)
	U.wait(duration)
	-- чёрный экран «нет сигнала»
	self.anims = {}
	self:clear()
	local dead = frame(self.canvas, 0, 0, W, H, "#000000", { Name = "Dead" })
	local nos = text(dead, 0, H / 2 - 30, W, 24, "НЕТ СИГНАЛА", 16, "#7CFF4A", G.Fonts.Wide, { TextXAlignment = Enum.TextXAlignment.Center })
	local dots = {}
	for i = 1, 30 do table.insert(dots, frame(dead, 0, 0, 3, 3, "#ffffff", { BackgroundTransparency = 0.6 })) end
	table.insert(self.anims, function(dt, t)
		nos.TextTransparency = math.random() < 0.15 and 0.8 or 0
		for _, d in ipairs(dots) do d.Position = UDim2.fromOffset(math.random(0, W), math.random(0, H)) end
	end)
end

return Phone
