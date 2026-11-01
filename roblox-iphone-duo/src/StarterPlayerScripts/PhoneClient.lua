-- Интерфейс телефона iPhone Duo. Два экрана: слева — приложения, справа — открытое приложение.
-- Телефон открывается, когда достаёшь его из инвентаря (клавиша 1). Клик по миру — открыть/свернуть.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("PhoneConfig"))
local remotes = ReplicatedStorage:WaitForChild("PhoneRemotes")
local actionEvent = remotes:WaitForChild("PhoneAction")
local notifyEvent = remotes:WaitForChild("PhoneNotify")

local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(20, 20, 26)
local BLUE = Color3.fromRGB(10, 132, 255)
local GREEN = Color3.fromRGB(48, 209, 88)
local RED = Color3.fromRGB(255, 69, 58)
local ORANGE = Color3.fromRGB(255, 159, 10)
local GRAY = Color3.fromRGB(72, 72, 80)

local function make(className, props)
	local inst = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(parent, r)
	local existing = parent:FindFirstChildOfClass("UICorner")
	if existing then
		existing.CornerRadius = UDim.new(0, r or 12)
		return existing
	end
	return make("UICorner", { CornerRadius = UDim.new(0, r or 12), Parent = parent })
end

local function label(parent, props)
	local l = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextColor3 = WHITE,
		TextSize = 16,
		TextWrapped = true,
		Parent = parent,
	})
	for k, v in pairs(props) do
		l[k] = v
	end
	return l
end

----------------------------------------------------------------------------------------------------
-- Звуки интерфейса
----------------------------------------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "PhoneGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 5,
	Parent = player:WaitForChild("PlayerGui"),
})

local function sound(id, vol, speed)
	return make("Sound", { SoundId = id, Volume = vol, PlaybackSpeed = speed or 1, Parent = gui })
end
local sClick = sound(Config.Sounds.Click, 0.25, 2)
local sNotify = sound(Config.Sounds.Notify, 0.5, 1.3)
local sShutter = sound(Config.Sounds.Shutter, 0.6, 1.6)
local sRing = sound(Config.Sounds.Ring, 0.6, 1.2)

local settings = { sounds = true, wallpaper = 1 }

local function play(s)
	if settings.sounds then
		s:Play()
	end
end

local function button(parent, text, size, pos, color, onClick)
	local b = make("TextButton", {
		Size = size,
		Position = pos or UDim2.new(),
		BackgroundColor3 = color or GRAY,
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = WHITE,
		TextWrapped = true,
		AutoButtonColor = true,
		Parent = parent,
	})
	corner(b, 12)
	b.Activated:Connect(function()
		play(sClick)
		onClick(b)
	end)
	return b
end

local function column(parent, top)
	local sf = make("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -(top or 0)),
		Position = UDim2.fromOffset(0, top or 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = WHITE,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	})
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = sf })
	make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10), Parent = sf })
	return sf
end

local function panel(parent, height, order)
	local f = make("Frame", { Size = UDim2.new(1, -8, 0, height), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55, LayoutOrder = order or 0, Parent = parent })
	corner(f, 14)
	return f
end

----------------------------------------------------------------------------------------------------
-- Помощники
----------------------------------------------------------------------------------------------------
local function clockText()
	local t = Lighting.ClockTime
	local h = math.floor(t)
	local m = math.floor((t - h) * 60)
	return string.format("%02d:%02d", h, m)
end

local function battery()
	return player:GetAttribute("Battery") or 100
end

local function nearestPlace()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return "Неизвестно"
	end
	local best, bestD = nil, math.huge
	for _, loc in ipairs(Config.Locations) do
		local d = (root.Position - loc.Position).Magnitude
		if d < bestD then
			best, bestD = loc, d
		end
	end
	if best and bestD < 60 then
		return best.Icon .. " " .. best.Name
	end
	return "🏙️ Где-то в городе"
end

----------------------------------------------------------------------------------------------------
-- Уведомления сверху экрана (видны и при свёрнутом телефоне)
----------------------------------------------------------------------------------------------------
local bannerHolder = make("Frame", {
	Size = UDim2.fromOffset(380, 400),
	Position = UDim2.new(0.5, 0, 0, 50),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	Parent = gui,
})
make("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = bannerHolder })

local function banner(icon, title, text, duration, buttons)
	local f = make("Frame", { Size = UDim2.fromOffset(370, buttons and 108 or 68), BackgroundColor3 = Color3.fromRGB(30, 30, 36),
		BackgroundTransparency = 0.08, Parent = bannerHolder })
	corner(f, 20)
	make("UIStroke", { Color = Color3.fromRGB(80, 80, 90), Thickness = 1, Parent = f })
	label(f, { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(12, 12), Text = icon, TextScaled = true })
	label(f, { Size = UDim2.new(1, -76, 0, 20), Position = UDim2.fromOffset(64, 10), Text = title, Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
	label(f, { Size = UDim2.new(1, -76, 0, 34), Position = UDim2.fromOffset(64, 30), Text = text, TextSize = 14,
		TextColor3 = Color3.fromRGB(210, 210, 215), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	local function close()
		if f.Parent then
			f:Destroy()
		end
	end
	if buttons then
		for i, b in ipairs(buttons) do
			button(f, b.text, UDim2.new(0.5, -18, 0, 32), UDim2.new((i - 1) * 0.5, 12, 0, 68), b.color, function()
				close()
				b.onClick()
			end)
		end
	end
	task.delay(duration or 4, function()
		if f.Parent and buttons and buttons.onTimeout then
			buttons.onTimeout()
		end
		close()
	end)
	return f
end

local function toast(text)
	banner("📱", "iPhone Duo", text, 4)
	play(sNotify)
end

----------------------------------------------------------------------------------------------------
-- Сам телефон на экране
----------------------------------------------------------------------------------------------------
local PHONE_W, PHONE_H = 600, 600
local SCREEN_W, SCREEN_H = 278, 572

local phone = make("Frame", {
	Name = "Phone",
	Size = UDim2.fromOffset(PHONE_W, PHONE_H),
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, PHONE_H + 40),
	BackgroundColor3 = Config.Colors[1].Color,
	Active = true,
	Visible = false,
	Parent = gui,
})
corner(phone, 40)
make("UIStroke", { Color = Color3.fromRGB(40, 40, 45), Thickness = 3, Parent = phone })
local uiScale = make("UIScale", { Parent = phone })

-- Петля посередине
local hinge = make("Frame", { Size = UDim2.fromOffset(10, PHONE_H - 40), Position = UDim2.fromOffset(PHONE_W / 2 - 5, 20),
	BackgroundColor3 = Color3.fromRGB(110, 110, 118), Parent = phone })
corner(hinge, 5)

local function makeScreen(x)
	local s = make("Frame", { Size = UDim2.fromOffset(SCREEN_W, SCREEN_H), Position = UDim2.fromOffset(x, 14),
		BackgroundColor3 = WHITE, ClipsDescendants = true, Active = true, Parent = phone })
	corner(s, 28)
	local grad = make("UIGradient", { Rotation = 90, Parent = s })
	return s, grad
end
local leftScreen, leftGrad = makeScreen(14)
local rightScreen, rightGrad = makeScreen(PHONE_W - 14 - SCREEN_W)

local function applyWallpaper()
	local w = Config.Wallpapers[settings.wallpaper] or Config.Wallpapers[1]
	leftGrad.Color = ColorSequence.new(w.A, w.B)
	rightGrad.Color = ColorSequence.new(w.B, w.A)
end
applyWallpaper()

-- Статус-бар: время слева, батарея справа (на двух экранах, как один длинный экран)
local timeLabel = label(leftScreen, { Size = UDim2.fromOffset(100, 24), Position = UDim2.fromOffset(22, 8), Text = "12:00",
	Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left })
label(leftScreen, { Size = UDim2.fromOffset(110, 24), Position = UDim2.new(1, -124, 0, 8), Text = "Duo 5G 📶", TextSize = 13,
	Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right })
local island = make("Frame", { Size = UDim2.fromOffset(84, 24), Position = UDim2.new(0.5, -42, 0, 8), BackgroundColor3 = Color3.new(0, 0, 0),
	Parent = rightScreen })
corner(island, 12)
local batteryLabel = label(rightScreen, { Size = UDim2.fromOffset(110, 24), Position = UDim2.new(1, -124, 0, 8), Text = "🔋 100%",
	Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right })

-- Сетка приложений (левый экран)
local grid = make("Frame", { Size = UDim2.new(1, -24, 1, -130), Position = UDim2.fromOffset(12, 48), BackgroundTransparency = 1,
	Parent = leftScreen })
make("UIGridLayout", { CellSize = UDim2.fromOffset(76, 90), CellPadding = UDim2.fromOffset(9, 6),
	HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })

-- Нижняя панель левого экрана
local dock = make("Frame", { Size = UDim2.new(1, -24, 0, 64), Position = UDim2.new(0, 12, 1, -76), BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.75, Parent = leftScreen })
corner(dock, 20)

-- Правый экран: заголовок и место для приложения
local header = make("Frame", { Size = UDim2.new(1, -24, 0, 36), Position = UDim2.fromOffset(12, 40), BackgroundTransparency = 1,
	Parent = rightScreen })
local titleLabel = label(header, { Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(44, 0), Text = "",
	Font = Enum.Font.GothamBlack, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left })
local appArea = make("Frame", { Size = UDim2.new(1, -20, 1, -96), Position = UDim2.fromOffset(10, 84), BackgroundTransparency = 1,
	ClipsDescendants = true, Parent = rightScreen })

-- Экран «телефон сел»
local function deadOverlay(screen)
	local f = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 50, Visible = false,
		Active = true, Parent = screen })
	label(f, { Size = UDim2.new(1, -30, 0, 140), Position = UDim2.new(0, 15, 0.5, -70), Text = "🪫\nТелефон разряжен\nВстань на зелёную зарядку ⚡",
		ZIndex = 51, TextSize = 18, Font = Enum.Font.GothamBold })
	return f
end
local deadLeft = deadOverlay(leftScreen)
local deadRight = deadOverlay(rightScreen)

-- Вспышка камеры на весь экран
local flashFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 100,
	Parent = gui })

-- Подсказка, когда телефон свёрнут
local hint = label(gui, { Size = UDim2.fromOffset(420, 36), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110),
	BackgroundTransparency = 0.35, BackgroundColor3 = Color3.new(0, 0, 0), Text = "📱 Нажми 1, чтобы достать iPhone Duo",
	Font = Enum.Font.GothamBold, TextSize = 16, Visible = false })
corner(hint, 18)

local function updateScale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	uiScale.Scale = math.clamp(math.min(vp.Y * 0.8 / PHONE_H, vp.X * 0.55 / PHONE_W), 0.35, 1)
	bannerHolder.Size = UDim2.fromOffset(math.min(380, vp.X - 20), 400)
end
updateScale()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

----------------------------------------------------------------------------------------------------
-- Приложения
----------------------------------------------------------------------------------------------------
local photos = {}
local messages = {}
local unread = 0
local currentApp = nil
local currentCleanup = nil
local currentRefresh = nil
local iconButtons = {}
local selfieConn = nil
local bestTap = 0

local apps -- список приложений, заполняется ниже
local openApp

local function setSelfie(on)
	local cam = workspace.CurrentCamera
	if selfieConn then
		selfieConn:Disconnect()
		selfieConn = nil
	end
	if on then
		cam.CameraType = Enum.CameraType.Scriptable
		selfieConn = RunService.RenderStepped:Connect(function()
			local head = player.Character and player.Character:FindFirstChild("Head")
			if not head then
				return
			end
			local cf = head.CFrame
			local eye = cf.Position + cf.LookVector * 5 + cf.RightVector * 1.6 + Vector3.new(0, 0.6, 0)
			cam.CFrame = CFrame.lookAt(eye, cf.Position + Vector3.new(0, 0.2, 0))
		end)
	else
		cam.CameraType = Enum.CameraType.Custom
	end
end

local function takePhoto(selfie)
	if battery() <= 0 then
		return
	end
	play(sShutter)
	flashFrame.BackgroundTransparency = 0
	TweenService:Create(flashFrame, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	actionEvent:FireServer("photo")
	table.insert(photos, { time = clockText(), place = nearestPlace(), selfie = selfie })
	toast("Фото сохранено в 🖼️ Галерею")
end

local function updateBadge()
	local b = iconButtons.chat
	local badge = b and b:FindFirstChild("Badge")
	if badge then
		badge.Visible = unread > 0
		badge.Text = tostring(unread)
	end
end

local appBuilders = {}

-- Главный экран справа: виджеты
local function buildHome(area)
	local col = column(area)
	local p1 = panel(col, 130, 1)
	local big = label(p1, { Size = UDim2.new(1, 0, 0, 70), Position = UDim2.fromOffset(0, 10), Text = clockText(),
		Font = Enum.Font.GothamBlack, TextSize = 60 })
	local place = label(p1, { Size = UDim2.new(1, -10, 0, 30), Position = UDim2.fromOffset(5, 88), Text = nearestPlace(), TextSize = 16 })
	local p2 = panel(col, 80, 2)
	local bat = label(p2, { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Text = "", TextSize = 18,
		Font = Enum.Font.GothamBold })
	local p3 = panel(col, 60, 3)
	local online = label(p3, { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Text = "", TextSize = 16 })
	local p4 = panel(col, 90, 4)
	label(p4, { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0),
		Text = "👈 Выбери приложение на левом экране.\nДва экрана — два дела сразу!", TextSize = 15 })
	local alive = true
	task.spawn(function()
		while alive do
			big.Text = clockText()
			place.Text = nearestPlace()
			local charging = player:GetAttribute("Charging")
			bat.Text = (charging and "⚡ Заряжается: " or "🔋 Заряд: ") .. math.floor(battery()) .. "%"
			online.Text = "👥 Игроков на сервере: " .. #Players:GetPlayers()
			task.wait(0.5)
		end
	end)
	return function()
		alive = false
	end
end

function appBuilders.camera(area)
	local selfie = false
	local view = make("Frame", { Size = UDim2.new(1, 0, 0, 260), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3,
		Parent = area })
	corner(view, 18)
	make("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 0.4, Parent = view })
	label(view, { Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, 60), Text = "📷", TextSize = 64 })
	local where = label(view, { Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0, 10, 1, -50), Text = nearestPlace(), TextSize = 15 })
	local mode = label(view, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 10), Text = "ФОТО", Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 214, 10), TextSize = 14 })
	local shutter = button(area, "", UDim2.fromOffset(78, 78), UDim2.new(0.5, -39, 0, 275), WHITE, function()
		takePhoto(selfie)
		where.Text = nearestPlace()
	end)
	corner(shutter, 39)
	make("UIStroke", { Color = Color3.fromRGB(200, 200, 200), Thickness = 4, Parent = shutter })
	local selfieBtn
	selfieBtn = button(area, "🤳 Селфи", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 368), GRAY, function()
		selfie = not selfie
		setSelfie(selfie)
		selfieBtn.Text = selfie and "↩️ Обычная камера" or "🤳 Селфи"
		mode.Text = selfie and "СЕЛФИ" or "ФОТО"
	end)
	return function()
		if selfie then
			setSelfie(false)
		end
	end
end

function appBuilders.gallery(area)
	local col = column(area)
	if #photos == 0 then
		local p = panel(col, 120, 1)
		label(p, { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Text = "Пока нет фото.\nОткрой 📷 Камеру и сделай снимок!" })
		return
	end
	for i = #photos, 1, -1 do
		local ph = photos[i]
		local p = panel(col, 64, #photos - i)
		label(p, { Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(7, 7), Text = ph.selfie and "🤳" or "🖼️", TextScaled = true })
		label(p, { Size = UDim2.new(1, -70, 0, 22), Position = UDim2.fromOffset(62, 8), Text = "Фото " .. i .. " · " .. ph.time,
			Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left })
		label(p, { Size = UDim2.new(1, -70, 0, 22), Position = UDim2.fromOffset(62, 32), Text = ph.place, TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 200, 205) })
	end
end

function appBuilders.flashlight(area)
	local big
	local function refresh()
		local on = player:GetAttribute("Flashlight") == true
		big.Text = on and "🔦\nВКЛ" or "🔦\nВЫКЛ"
		big.BackgroundColor3 = on and Color3.fromRGB(255, 214, 10) or GRAY
		big.TextColor3 = on and Color3.new(0, 0, 0) or WHITE
	end
	big = button(area, "", UDim2.fromOffset(170, 170), UDim2.new(0.5, -85, 0, 30), GRAY, function()
		actionEvent:FireServer("flashlight", not (player:GetAttribute("Flashlight") == true))
	end)
	big.TextSize = 30
	corner(big, 85)
	label(area, { Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 220), TextSize = 15,
		Text = "Ночью без фонарика темно!\nСвет видят все игроки.\nФонарик быстрее садит батарею." })
	refresh()
	local conn = player:GetAttributeChangedSignal("Flashlight"):Connect(refresh)
	return function()
		conn:Disconnect()
	end
end

function appBuilders.music(area)
	local col = column(area)
	local nowP = panel(col, 50, 0)
	local nowL = label(nowP, { Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), TextSize = 15 })
	local function refresh()
		local id = player:GetAttribute("MusicId") or ""
		if id == "" then
			nowL.Text = "⏸ Ничего не играет"
		else
			local name = "ID " .. id
			for _, t in ipairs(Config.Music) do
				if t.Id == id then
					name = t.Name
				end
			end
			nowL.Text = "🎶 Играет: " .. name
		end
	end
	for i, t in ipairs(Config.Music) do
		local b = button(col, "▶  " .. t.Name, UDim2.new(1, -8, 0, 44), nil, Color3.fromRGB(255, 45, 85), function()
			actionEvent:FireServer("music", t.Id)
		end)
		b.LayoutOrder = i
		b.TextXAlignment = Enum.TextXAlignment.Left
		make("UIPadding", { PaddingLeft = UDim.new(0, 14), Parent = b })
	end
	local boxP = panel(col, 96, 50)
	label(boxP, { Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 4), Text = "Свой трек (ID из Toolbox → Audio):", TextSize = 13 })
	local box = make("TextBox", { Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 28), BackgroundColor3 = WHITE,
		Text = "", PlaceholderText = "например 1848354536", TextColor3 = Color3.new(0, 0, 0), Font = Enum.Font.Gotham, TextSize = 15,
		ClearTextOnFocus = false, Parent = boxP })
	corner(box, 8)
	button(boxP, "▶ Играть", UDim2.new(1, -16, 0, 28), UDim2.fromOffset(8, 62), BLUE, function()
		actionEvent:FireServer("music", box.Text)
	end)
	local stop = button(col, "⏹  Стоп", UDim2.new(1, -8, 0, 44), nil, GRAY, function()
		actionEvent:FireServer("music", "")
	end)
	stop.LayoutOrder = 60
	refresh()
	local conn = player:GetAttributeChangedSignal("MusicId"):Connect(refresh)
	return function()
		conn:Disconnect()
	end
end

function appBuilders.chat(area)
	unread = 0
	updateBadge()
	local list = column(area)
	list.Size = UDim2.new(1, 0, 1, -50)
	local function refresh()
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		if #messages == 0 then
			local p = panel(list, 90, 1)
			label(p, { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0),
				Text = "Сообщений пока нет.\nНапиши что-нибудь — увидят все, у кого есть iPhone Duo!", TextSize = 14 })
			return
		end
		for i, m in ipairs(messages) do
			local mine = m.fromId == player.UserId
			local f = make("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
				LayoutOrder = i, Parent = list })
			local bubble = make("Frame", { Size = UDim2.new(0.85, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				Position = mine and UDim2.fromScale(0.15, 0) or UDim2.new(), BackgroundColor3 = mine and BLUE or Color3.fromRGB(58, 58, 64),
				Parent = f })
			corner(bubble, 14)
			make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6), Parent = bubble })
			make("UIListLayout", { Parent = bubble })
			label(bubble, { Size = UDim2.new(1, 0, 0, 16), Text = mine and "Ты" or m.from, TextSize = 12, Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(220, 220, 230) })
			label(bubble, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = m.text, TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left })
		end
		task.defer(function()
			list.CanvasPosition = Vector2.new(0, math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y))
		end)
	end
	local box = make("TextBox", { Size = UDim2.new(1, -54, 0, 40), Position = UDim2.new(0, 0, 1, -42), BackgroundColor3 = WHITE,
		Text = "", PlaceholderText = "Сообщение…", TextColor3 = Color3.new(0, 0, 0), Font = Enum.Font.Gotham, TextSize = 15,
		ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = area })
	corner(box, 20)
	make("UIPadding", { PaddingLeft = UDim.new(0, 12), Parent = box })
	local function send()
		if box.Text:match("%S") then
			actionEvent:FireServer("message", box.Text:sub(1, Config.MessageMaxLength))
			box.Text = ""
		end
	end
	local sendBtn = button(area, "➤", UDim2.fromOffset(46, 40), UDim2.new(1, -46, 1, -42), BLUE, send)
	corner(sendBtn, 20)
	box.FocusLost:Connect(function(enter)
		if enter then
			send()
		end
	end)
	currentRefresh = refresh
	refresh()
end

function appBuilders.call(area)
	local col = column(area)
	local others = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			table.insert(others, p)
		end
	end
	if #others == 0 then
		local p = panel(col, 110, 1)
		label(p, { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0),
			Text = "Ты один на сервере.\nПозови друзей — и звони им прямо в игре! 📞", TextSize = 15 })
		return
	end
	for i, p in ipairs(others) do
		local row = panel(col, 60, i)
		label(row, { Size = UDim2.new(1, -80, 1, 0), Position = UDim2.fromOffset(12, 0), Text = "👤 " .. p.DisplayName,
			Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
		local b = button(row, "📞", UDim2.fromOffset(48, 44), UDim2.new(1, -56, 0, 8), GREEN, function()
			actionEvent:FireServer("call", p.UserId)
		end)
		corner(b, 22)
	end
end

function appBuilders.map(area)
	local col = column(area)
	local here = panel(col, 46, 0)
	label(here, { Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Text = "Ты сейчас: " .. nearestPlace(), TextSize = 14 })
	for i, loc in ipairs(Config.Locations) do
		local b = button(col, loc.Icon .. "  " .. loc.Name, UDim2.new(1, -8, 0, 50), nil, Color3.fromRGB(52, 120, 246), function()
			actionEvent:FireServer("teleport", i)
		end)
		b.LayoutOrder = i
		b.TextXAlignment = Enum.TextXAlignment.Left
		make("UIPadding", { PaddingLeft = UDim.new(0, 14), Parent = b })
	end
	local note = panel(col, 40, 99)
	label(note, { Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Text = "Телепорт тратит 2% заряда", TextSize = 13 })
end

function appBuilders.turbo(area)
	local big = button(area, "🚀\nТУРБО", UDim2.fromOffset(170, 170), UDim2.new(0.5, -85, 0, 30), ORANGE, function()
		actionEvent:FireServer("turbo")
	end)
	big.TextSize = 28
	corner(big, 85)
	local info = label(area, { Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 220), TextSize = 15, Text = "" })
	local conn = RunService.Heartbeat:Connect(function()
		local left = (player:GetAttribute("TurboReadyAt") or 0) - workspace:GetServerTimeNow()
		if left > 0 then
			big.BackgroundColor3 = GRAY
			info.Text = "Перезарядка: " .. math.ceil(left) .. " с"
		else
			big.BackgroundColor3 = ORANGE
			info.Text = "Скорость ×" .. string.format("%.1f", Config.Turbo.Speed / 16) .. " на " .. Config.Turbo.Duration
				.. " секунд.\nСтоит " .. Config.Turbo.Cost .. "% заряда."
		end
	end)
	return function()
		conn:Disconnect()
	end
end

function appBuilders.calc(area)
	local display = "0"
	local acc, op, fresh = nil, nil, true
	local screen = label(area, { Size = UDim2.new(1, -10, 0, 70), Position = UDim2.fromOffset(5, 0), Text = "0", TextSize = 46,
		Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Right, TextScaled = false, TextTruncate = Enum.TextTruncate.AtEnd })
	local function fmt(n)
		if n == nil or n ~= n or n == math.huge or n == -math.huge then
			return "Ошибка"
		end
		return string.format("%.10g", n)
	end
	local function apply(a, o, b)
		if o == "+" then
			return a + b
		elseif o == "−" then
			return a - b
		elseif o == "×" then
			return a * b
		elseif o == "÷" then
			if b == 0 then
				return nil
			end
			return a / b
		end
		return b
	end
	local function press(k)
		if display == "Ошибка" and k ~= "C" then
			display, acc, op, fresh = "0", nil, nil, true
		end
		if k:match("^%d$") or k == "." then
			if fresh then
				display = (k == ".") and "0." or k
				fresh = false
			elseif #display < 12 then
				if k == "." and display:find("%.") then
					return
				end
				if display == "0" and k ~= "." then
					display = k
				else
					display = display .. k
				end
			end
		elseif k == "C" then
			display, acc, op, fresh = "0", nil, nil, true
		elseif k == "±" then
			display = fmt(-(tonumber(display) or 0))
		elseif k == "%" then
			display = fmt((tonumber(display) or 0) / 100)
		elseif k == "⌫" then
			if not fresh then
				display = display:sub(1, -2)
				if display == "" or display == "-" then
					display = "0"
				end
			end
		elseif k == "=" then
			if acc and op then
				display = fmt(apply(acc, op, tonumber(display) or 0))
				acc, op = nil, nil
			end
			fresh = true
		else -- + − × ÷
			if acc and op and not fresh then
				local r = apply(acc, op, tonumber(display) or 0)
				display = fmt(r)
				acc = r
			else
				acc = tonumber(display)
			end
			op = k
			fresh = true
		end
		screen.Text = display
	end
	local keys = {
		{ "C", "±", "%", "÷" },
		{ "7", "8", "9", "×" },
		{ "4", "5", "6", "−" },
		{ "1", "2", "3", "+" },
		{ "0", ".", "⌫", "=" },
	}
	local size = 56
	local gap = (SCREEN_W - 20 - size * 4) / 3
	for r, row in ipairs(keys) do
		for c, k in ipairs(row) do
			local color = GRAY
			if c == 4 then
				color = ORANGE
			elseif r == 1 then
				color = Color3.fromRGB(165, 165, 170)
			end
			local b = button(area, k, UDim2.fromOffset(size, size), UDim2.fromOffset((c - 1) * (size + gap), 80 + (r - 1) * (size + 8)), color,
				function()
					press(k)
				end)
			b.TextSize = 24
			corner(b, size / 2)
		end
	end
end

function appBuilders.game(area)
	local token = nil
	local score = 0
	local info = label(area, { Size = UDim2.new(1, 0, 0, 50), Text = "", TextSize = 16, Font = Enum.Font.GothamBold })
	local field = make("Frame", { Size = UDim2.new(1, 0, 1, -110), Position = UDim2.fromOffset(0, 54), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55, ClipsDescendants = true, Parent = area })
	corner(field, 16)
	local target = button(field, "🍎", UDim2.fromOffset(54, 54), UDim2.fromOffset(90, 90), Color3.fromRGB(255, 255, 255), function() end)
	target.BackgroundTransparency = 1
	target.TextSize = 40
	target.Visible = false
	local startBtn
	local function moveTarget()
		local w = field.AbsoluteSize.X / uiScale.Scale - 54
		local h = field.AbsoluteSize.Y / uiScale.Scale - 54
		target.Position = UDim2.fromOffset(math.random(0, math.max(1, math.floor(w))), math.random(0, math.max(1, math.floor(h))))
	end
	target.Activated:Connect(function()
		if token then
			score = score + 1
			moveTarget()
		end
	end)
	local function showIdle()
		info.Text = "Лови яблоки! Рекорд: " .. bestTap
		target.Visible = false
		startBtn.Visible = true
	end
	startBtn = button(area, "▶ Начать", UDim2.new(1, 0, 0, 46), UDim2.new(0, 0, 1, -48), GREEN, function()
		local my = {}
		token = my
		score = 0
		startBtn.Visible = false
		target.Visible = true
		moveTarget()
		task.spawn(function()
			local t0 = os.clock()
			while token == my do
				local left = Config.TapGameSeconds - (os.clock() - t0)
				if left <= 0 then
					break
				end
				info.Text = "🍎 " .. score .. "   ⏱ " .. math.ceil(left)
				task.wait(0.1)
			end
			if token == my then
				token = nil
				if score > bestTap then
					bestTap = score
					toast("🏆 Новый рекорд в Тап-тап: " .. score .. "!")
				end
				showIdle()
				info.Text = "Счёт: " .. score .. " · Рекорд: " .. bestTap
			end
		end)
	end)
	showIdle()
	return function()
		token = nil
	end
end

function appBuilders.color(area)
	local col = column(area)
	local rows = {}
	local function refresh()
		local cur = player:GetAttribute("PhoneColor") or 1
		for i, r in ipairs(rows) do
			r.Text = (i == cur and "✓  " or "     ") .. Config.Colors[i].Name
		end
	end
	for i, c in ipairs(Config.Colors) do
		local b = button(col, "", UDim2.new(1, -8, 0, 46), nil, Color3.fromRGB(40, 40, 46), function()
			actionEvent:FireServer("color", i)
		end)
		b.LayoutOrder = i
		b.TextXAlignment = Enum.TextXAlignment.Left
		make("UIPadding", { PaddingLeft = UDim.new(0, 52), Parent = b })
		local sw = make("Frame", { Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0, -42, 0.5, -15), BackgroundColor3 = c.Color, Parent = b })
		corner(sw, 15)
		make("UIStroke", { Color = WHITE, Thickness = 1, Parent = sw })
		rows[i] = b
	end
	refresh()
	local conn = player:GetAttributeChangedSignal("PhoneColor"):Connect(refresh)
	return function()
		conn:Disconnect()
	end
end

function appBuilders.settings(area)
	local col = column(area)
	local about = panel(col, 120, 1)
	label(about, { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), TextSize = 14,
		Text = "📱 iPhone Duo\nДва экрана · Двойная камера\nПамять: 1 ТБ · iOS Duo 1.0\nВладелец: " .. player.DisplayName })
	local wl = panel(col, 30, 2)
	label(wl, { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Text = "Обои:", Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left })
	wl.BackgroundTransparency = 1
	for i, w in ipairs(Config.Wallpapers) do
		local b = button(col, w.Name, UDim2.new(1, -8, 0, 40), nil, w.A, function()
			settings.wallpaper = i
			applyWallpaper()
		end)
		b.LayoutOrder = 2 + i
		make("UIGradient", { Color = ColorSequence.new(w.A, w.B), Parent = b })
		b.BackgroundColor3 = WHITE
	end
	local snd
	snd = button(col, "", UDim2.new(1, -8, 0, 44), nil, GRAY, function()
		settings.sounds = not settings.sounds
		snd.Text = settings.sounds and "🔔 Звуки: вкл" or "🔕 Звуки: выкл"
	end)
	snd.Text = settings.sounds and "🔔 Звуки: вкл" or "🔕 Звуки: выкл"
	snd.LayoutOrder = 50
	local help = panel(col, 130, 60)
	label(help, { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), TextSize = 13,
		Text = "Управление:\n1 — достать / убрать телефон\nКлик по миру — открыть / свернуть\n⚡ Зелёные площадки заряжают телефон" })
end

apps = {
	{ id = "camera", icon = "📷", name = "Камера", color = Color3.fromRGB(60, 60, 66) },
	{ id = "gallery", icon = "🖼️", name = "Галерея", color = Color3.fromRGB(255, 255, 255) },
	{ id = "flashlight", icon = "🔦", name = "Фонарик", color = Color3.fromRGB(255, 204, 0) },
	{ id = "music", icon = "🎵", name = "Музыка", color = Color3.fromRGB(255, 45, 85) },
	{ id = "chat", icon = "💬", name = "Сообщения", color = GREEN },
	{ id = "call", icon = "📞", name = "Звонки", color = Color3.fromRGB(52, 199, 89) },
	{ id = "map", icon = "🗺️", name = "Карта", color = Color3.fromRGB(90, 200, 250) },
	{ id = "turbo", icon = "🚀", name = "Турбо", color = ORANGE },
	{ id = "calc", icon = "🧮", name = "Калькулятор", color = Color3.fromRGB(40, 40, 40) },
	{ id = "game", icon = "🕹️", name = "Тап-тап", color = Color3.fromRGB(175, 82, 222) },
	{ id = "color", icon = "🎨", name = "Цвет", color = Color3.fromRGB(255, 120, 160) },
	{ id = "settings", icon = "⚙️", name = "Настройки", color = Color3.fromRGB(142, 142, 147) },
}

local homeButton
openApp = function(id)
	if currentCleanup then
		pcall(currentCleanup)
	end
	currentCleanup = nil
	currentRefresh = nil
	for _, c in ipairs(appArea:GetChildren()) do
		c:Destroy()
	end
	currentApp = id
	local info = nil
	for _, a in ipairs(apps) do
		if a.id == id then
			info = a
		end
	end
	if info then
		titleLabel.Text = info.name
		homeButton.Visible = true
		currentCleanup = appBuilders[id](appArea)
		actionEvent:FireServer("screen", info.icon, info.name)
	else
		currentApp = nil
		titleLabel.Text = "Duo"
		homeButton.Visible = false
		currentCleanup = buildHome(appArea)
		actionEvent:FireServer("screen", "📱", "Главный экран")
	end
	for aid, b in pairs(iconButtons) do
		local stroke = b:FindFirstChild("Selected")
		if stroke then
			stroke.Enabled = (aid == currentApp)
		end
	end
end

homeButton = button(header, "‹", UDim2.fromOffset(36, 36), UDim2.new(), Color3.fromRGB(0, 0, 0), function()
	openApp(nil)
end)
homeButton.BackgroundTransparency = 0.6
homeButton.TextSize = 28
corner(homeButton, 18)

for i, a in ipairs(apps) do
	local cell = make("Frame", { BackgroundTransparency = 1, LayoutOrder = i, Parent = grid })
	local b = make("TextButton", { Size = UDim2.fromOffset(60, 60), Position = UDim2.new(0.5, -30, 0, 0), BackgroundColor3 = a.color,
		Text = a.icon, TextSize = 32, Font = Enum.Font.GothamBold, TextColor3 = WHITE, AutoButtonColor = true, Parent = cell })
	corner(b, 15)
	make("UIStroke", { Name = "Selected", Color = WHITE, Thickness = 3, Enabled = false, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	label(cell, { Size = UDim2.new(1, 4, 0, 18), Position = UDim2.new(0, -2, 0, 64), Text = a.name, TextSize = 11, Font = Enum.Font.GothamMedium,
		TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	if a.id == "chat" then
		local badge = label(b, { Name = "Badge", Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -14, 0, -8), BackgroundTransparency = 0,
			BackgroundColor3 = RED, Text = "0", TextSize = 12, Font = Enum.Font.GothamBold, Visible = false, ZIndex = 3 })
		corner(badge, 11)
	end
	b.Activated:Connect(function()
		play(sClick)
		openApp(a.id)
	end)
	iconButtons[a.id] = b
end

-- Док: свернуть телефон и быстрые кнопки
local isOpen = false
local setOpen

local dockButtons = {
	{ "🏠", function() openApp(nil) end },
	{ "🔦", function() actionEvent:FireServer("flashlight", not (player:GetAttribute("Flashlight") == true)) end },
	{ "📷", function() openApp("camera") end },
	{ "⬇️", function() setOpen(false) end },
}
for i, d in ipairs(dockButtons) do
	local b = button(dock, d[1], UDim2.fromOffset(48, 48), UDim2.fromOffset(8 + (i - 1) * 61, 8), Color3.fromRGB(255, 255, 255), d[2])
	b.BackgroundTransparency = 0.5
	b.TextSize = 24
	corner(b, 14)
end

----------------------------------------------------------------------------------------------------
-- Открытие и закрытие, слежение за телефоном в руке
----------------------------------------------------------------------------------------------------
local equippedTool = nil
local activatedConn = nil

setOpen = function(open)
	isOpen = open
	if open then
		phone.Visible = true
		if not currentApp and #appArea:GetChildren() == 0 then
			openApp(nil)
		end
		TweenService:Create(phone, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.new(1, -16, 1, -16) }):Play()
	else
		if currentApp == "camera" then
			openApp(nil) -- выключает селфи-камеру
		end
		local tw = TweenService:Create(phone, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(1, -16, 1, PHONE_H + 40) })
		tw:Play()
		tw.Completed:Connect(function()
			if not isOpen then
				phone.Visible = false
			end
		end)
	end
	if equippedTool then
		hint.Text = "📱 Кликни, чтобы открыть iPhone Duo"
		hint.Visible = not open
	else
		hint.Text = "📱 Нажми 1, чтобы достать iPhone Duo"
		hint.Visible = true
	end
end

local function onEquipped(tool)
	equippedTool = tool
	if activatedConn then
		activatedConn:Disconnect()
	end
	activatedConn = tool.Activated:Connect(function()
		setOpen(not isOpen)
	end)
	setOpen(true)
end

local function onUnequipped()
	equippedTool = nil
	if activatedConn then
		activatedConn:Disconnect()
		activatedConn = nil
	end
	setSelfie(false)
	setOpen(false)
end

local function watchCharacter(char)
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") and c.Name == Config.ToolName then
			onEquipped(c)
		end
	end)
	char.ChildRemoved:Connect(function(c)
		if c == equippedTool then
			onUnequipped()
		end
	end)
	local hum = char:WaitForChild("Humanoid")
	hum.Died:Connect(function()
		setSelfie(false)
	end)
	local existing = char:FindFirstChild(Config.ToolName)
	if existing and existing:IsA("Tool") then
		onEquipped(existing)
	else
		onUnequipped()
	end
end

player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	task.spawn(watchCharacter, player.Character)
end

-- Цвет корпуса на экране совпадает с цветом телефона в руке
local function updateBodyColor()
	local entry = Config.Colors[player:GetAttribute("PhoneColor") or 1] or Config.Colors[1]
	phone.BackgroundColor3 = entry.Color
end
player:GetAttributeChangedSignal("PhoneColor"):Connect(updateBodyColor)
updateBodyColor()

-- Статус-бар и разряженный экран
RunService.Heartbeat:Connect(function()
	timeLabel.Text = clockText()
	local b = battery()
	local charging = player:GetAttribute("Charging") == true
	local icon = charging and "⚡" or (b <= 20 and "🪫" or "🔋")
	batteryLabel.Text = icon .. " " .. math.floor(b) .. "%"
	batteryLabel.TextColor3 = (b <= 20 and not charging) and RED or WHITE
	local dead = b <= 0
	if deadLeft.Visible ~= dead then
		deadLeft.Visible = dead
		deadRight.Visible = dead
		if dead and currentApp == "camera" then
			openApp(nil)
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- Сообщения от сервера
----------------------------------------------------------------------------------------------------
notifyEvent.OnClientEvent:Connect(function(kind, data)
	data = data or {}
	if kind == "toast" then
		toast(tostring(data.text or ""))
	elseif kind == "message" then
		table.insert(messages, { from = data.from, fromId = data.fromId, text = data.text })
		while #messages > 50 do
			table.remove(messages, 1)
		end
		if currentApp == "chat" and isOpen and currentRefresh then
			currentRefresh()
		elseif data.fromId ~= player.UserId then
			unread = unread + 1
			updateBadge()
			banner("💬", tostring(data.from), tostring(data.text), 5)
			play(sNotify)
		end
	elseif kind == "call" then
		play(sRing)
		local answered = false
		local btns = {
			{ text = "✅ Ответить", color = GREEN, onClick = function()
				answered = true
				actionEvent:FireServer("callAnswer", data.fromId, true)
				if equippedTool then
					setOpen(true)
					openApp("chat")
				else
					toast("Достань телефон (1) и открой 💬 Сообщения")
				end
			end },
			{ text = "❌ Сбросить", color = RED, onClick = function()
				answered = true
				actionEvent:FireServer("callAnswer", data.fromId, false)
			end },
		}
		btns.onTimeout = function()
			if not answered then
				actionEvent:FireServer("callAnswer", data.fromId, false)
			end
		end
		banner("📞", "Входящий звонок", tostring(data.from) .. " звонит тебе!", 10, btns)
	elseif kind == "callResult" then
		if data.accepted then
			toast("📞 " .. tostring(data.name) .. " ответил(а)! Пишите друг другу в 💬 Сообщениях")
		else
			toast("📵 " .. tostring(data.name) .. " не ответил(а)")
		end
	end
end)

-- На компьютере телефон можно открыть и клавишей P (если он в руке)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.P and equippedTool then
		setOpen(not isOpen)
	end
end)

hint.Visible = true
