-- Меню: выбор персонажа (3D-превью, приёмы, пробуждение), настройки, управление.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = ReplicatedStorage:WaitForChild("Client")
local Config = require(Shared.Config)
local Characters = require(Shared.Characters)
local Costumes = require(Shared.Costumes)
local Poses = require(Shared.Poses)
local Rig = require(Shared.Rig)
local Theme = require(Client.Theme)
local Hud = require(Client.Hud)
local FX = require(Client.FX)
local CameraFX = require(Client.CameraFX)
local SoundFX = require(Client.SoundFX)

local Menu = {}
Menu.isOpen = false
Menu.onOpen = nil       -- function(open)
Menu.current = nil      -- выбранный (подтверждённый сервером) персонаж
Menu.viewing = nil      -- персонаж в карточке подробностей

local player = Players.LocalPlayer
local Action = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Action")
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local ui = {}
Menu.ui = ui

local function tween(inst, t, props, style)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

---------------------------------------------------------------- 3D-превью персонажа
local function stanceVals(def)
	local name = Poses.StanceOf[def.M1Style] or "fists"
	return Poses.BaseVals[name] or Poses.BaseVals.stand
end

-- готовая модель персонажа в боевой стойке (позу «запекаем» в C0 — так она видна в ViewportFrame)
function Menu.makeModel(charId)
	local rig = ReplicatedStorage:FindFirstChild("PreviewRig")
	if not rig then return nil end
	local m = rig:Clone()
	local def = Characters.get(charId)
	Costumes.apply(m, charId)
	if charId == "CrimsonBlade" then Costumes.sword(m, def.Color) end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	local motors, rot0 = Rig.find(m)
	Rig.apply(motors, rot0, stanceVals(def))
	for _, mo in pairs(motors) do
		mo.C0 = mo.C0 * mo.Transform
		mo.Transform = CFrame.new()
	end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = p.Name == "HumanoidRootPart"
			p.CanCollide = false
		end
	end
	return m
end

local function viewport(parent, props, charId, camDist, yaw)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Preview"
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(150, 150, 165)
	vp.LightColor = Color3.fromRGB(255, 246, 236)
	vp.LightDirection = Vector3.new(-0.6, -1, -0.7)
	Theme.apply(vp, props)
	local wm = Instance.new("WorldModel")
	wm.Parent = vp
	local m = Menu.makeModel(charId)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	if m then
		m:PivotTo(CFrame.new(0, 3, 0) * CFrame.Angles(0, math.pi + (yaw or 0.45), 0))
		m.Parent = wm
	end
	local d = camDist or 11
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 3.3, d), Vector3.new(0, 2.75, 0))
	vp.Parent = parent
	return vp, m, wm
end

---------------------------------------------------------------- построение
local function sectionTitle(parent, text, pos)
	local l = Theme.label({ Name = "Title", Text = text, Position = pos, Size = UDim2.fromOffset(600, 34), FontFace = Theme.BlackItalic,
		TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent })
	Theme.textStroke(l, 1.5)
	return l
end

local function pill(parent, text, color, pos, w)
	local p = Theme.label({ Name = "Pill", Text = text, Position = pos, Size = UDim2.fromOffset(w or 90, 20), BackgroundTransparency = 0.1,
		BackgroundColor3 = color, TextColor3 = WHITE, FontFace = Theme.Black, TextSize = 11, Parent = parent })
	Theme.corner(p, 10)
	return p
end

local DIFF_COLOR = { ["Легко"] = Color3.fromRGB(70, 180, 100), ["Средне"] = Color3.fromRGB(210, 150, 40), ["Сложно"] = Color3.fromRGB(210, 60, 60) }

local function buildCard(parent, charId, index)
	local def = Characters.get(charId)
	local col = (index - 1) % 3
	local row = math.floor((index - 1) / 3)
	local card = Theme.button({ Name = charId, AutoButtonColor = false, Size = UDim2.fromOffset(196, 254),
		Position = UDim2.fromOffset(col * 210, row * 268), BackgroundColor3 = Theme.Panel, ClipsDescendants = true, Parent = parent })
	Theme.corner(card, 8)
	local stroke = Theme.stroke(card, Theme.Line, 1.5, 0.2)
	Theme.gradient(card, Theme.shade(def.Dark, 0.1), Color3.fromRGB(12, 12, 18), 90)
	-- фон-полоса цвета персонажа
	local band = Theme.frame({ Name = "Band", Position = UDim2.fromOffset(-30, 70), Size = UDim2.fromOffset(260, 60), Rotation = -14,
		BackgroundColor3 = def.Color, BackgroundTransparency = 0.55, Parent = card })
	Theme.gradient(band, def.Color, def.Accent, 0, 0.2, 0.7)
	local vp = viewport(card, { Size = UDim2.fromOffset(196, 186), Position = UDim2.fromOffset(0, 4), ZIndex = 2 }, charId, 11.5, 0.5)
	local shade = Theme.frame({ Name = "Shade", Position = UDim2.new(0, 0, 1, -74), Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.35, ZIndex = 3, Parent = card })
	Theme.gradient(shade, BLACK, BLACK, 90, 1, 0.1)
	local name = Theme.label({ Name = "CharName", Text = string.upper(def.Name), Position = UDim2.new(0, 10, 1, -58), Size = UDim2.new(1, -16, 0, 24),
		FontFace = Theme.BlackItalic, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = card })
	Theme.textStroke(name, 1.5)
	Theme.label({ Name = "CharTitle", Text = def.Title, Position = UDim2.new(0, 11, 1, -33), Size = UDim2.new(1, -100, 0, 18),
		FontFace = Theme.Medium, TextSize = 13, TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = card })
	local diff = pill(card, string.upper(def.Difficulty), DIFF_COLOR[def.Difficulty] or Theme.Line, UDim2.new(1, -82, 1, -33), 72)
	diff.ZIndex = 4
	local badge = pill(card, "ВЫ ЗА НЕГО", def.Color, UDim2.fromOffset(8, 8), 92)
	badge.ZIndex = 5
	badge.Visible = false
	local accent = Theme.frame({ Name = "Accent", Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = def.Color, ZIndex = 5, Parent = card })
	card.MouseEnter:Connect(function()
		if Menu.viewing ~= charId then stroke.Color = Theme.shade(def.Color, 0.2) stroke.Transparency = 0.4 end
	end)
	card.MouseLeave:Connect(function()
		if Menu.viewing ~= charId then stroke.Color = Theme.Line stroke.Transparency = 0.2 end
	end)
	card.Activated:Connect(function()
		SoundFX.play("Click")
		Menu.view(charId)
	end)
	return { card = card, stroke = stroke, badge = badge, vp = vp, accent = accent }
end

local function moveRow(parent, y, key, m, color)
	local r = Theme.frame({ Name = "Move" .. key, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = Theme.Panel2,
		BackgroundTransparency = 0.25, Parent = parent })
	Theme.corner(r, 5)
	local k = Theme.label({ Name = "Key", Text = key, Position = UDim2.fromOffset(6, 11), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 0,
		BackgroundColor3 = m.Ultimate and Theme.Gold or color, TextColor3 = m.Ultimate and BLACK or WHITE, FontFace = Theme.Black, TextSize = 12, Parent = r })
	Theme.corner(k, 4)
	local name = Theme.label({ Name = "MoveName", Text = string.upper(m.Name), Position = UDim2.fromOffset(34, 3), Size = UDim2.new(1, -90, 0, 18),
		FontFace = Theme.Black, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = r })
	local cd = Theme.label({ Name = "Cooldown", Text = m.Ultimate and (m.Domain and "ТЕРРИТОРИЯ" or "УЛЬТА") or (tostring(m.Cooldown) .. " с"),
		Position = UDim2.new(1, -92, 0, 3), Size = UDim2.fromOffset(84, 18), FontFace = Theme.Bold, TextSize = 11,
		TextColor3 = m.Ultimate and Theme.Gold or Theme.Dim, TextXAlignment = Enum.TextXAlignment.Right, Parent = r })
	local desc = Theme.label({ Name = "Desc", Text = m.Desc, Position = UDim2.fromOffset(34, 20), Size = UDim2.new(1, -40, 0, 20),
		FontFace = Theme.Medium, TextSize = 11, TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, Parent = r })
	return { frame = r, key = k, name = name, cd = cd, desc = desc }
end

local function buildDetails(parent)
	local d = Theme.frame({ Name = "Details", Position = UDim2.fromOffset(640, 0), Size = UDim2.fromOffset(330, 640), BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.12, ClipsDescendants = true, Parent = parent })
	Theme.corner(d, 8)
	ui.detStroke = Theme.stroke(d, Theme.Line, 1.5, 0.2)
	ui.detGrad = Theme.gradient(d, Theme.Panel2, Theme.Panel, 90)
	ui.details = d
	ui.detBand = Theme.frame({ Name = "Band", Position = UDim2.fromOffset(-40, 60), Size = UDim2.fromOffset(420, 90), Rotation = -12,
		BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.5, Parent = d })
	ui.detBandGrad = Theme.gradient(ui.detBand, Theme.Accent, Theme.Gold, 0, 0.2, 0.75)
	ui.detView = Theme.frame({ Name = "View", BackgroundTransparency = 1, Size = UDim2.fromOffset(330, 214), Parent = d })
	ui.detName = Theme.label({ Name = "CharName", Text = "", Position = UDim2.fromOffset(16, 206), Size = UDim2.fromOffset(300, 32),
		FontFace = Theme.BlackItalic, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, Parent = d })
	Theme.textStroke(ui.detName, 1.5)
	ui.detTitle = Theme.label({ Name = "CharTitle", Text = "", Position = UDim2.fromOffset(17, 236), Size = UDim2.fromOffset(200, 18),
		FontFace = Theme.Bold, TextSize = 13, TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Left, Parent = d })
	ui.detDiff = pill(d, "", Theme.Line, UDim2.fromOffset(232, 236), 82)
	ui.detDesc = Theme.label({ Name = "Desc", Text = "", Position = UDim2.fromOffset(16, 258), Size = UDim2.fromOffset(300, 46),
		FontFace = Theme.Medium, TextSize = 12, TextColor3 = Color3.fromRGB(215, 216, 226), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = d })
	ui.detMoves = Theme.frame({ Name = "Moves", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 306), Size = UDim2.fromOffset(306, 186), Parent = d })
	ui.detAwk = Theme.label({ Name = "Awakening", Text = "", Position = UDim2.fromOffset(16, 496), Size = UDim2.fromOffset(300, 18),
		FontFace = Theme.BlackItalic, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = d })
	ui.detAwkList = Theme.label({ Name = "AwakeningMoves", Text = "", Position = UDim2.fromOffset(16, 515), Size = UDim2.fromOffset(300, 48),
		FontFace = Theme.Medium, TextSize = 11, TextColor3 = Theme.Dim, TextWrapped = true, RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = d })
	ui.selectBtn = Theme.button({ Name = "Select", Text = "ВЫБРАТЬ", Position = UDim2.fromOffset(12, 576), Size = UDim2.fromOffset(306, 52),
		BackgroundColor3 = Theme.Accent, TextSize = 22, FontFace = Theme.BlackItalic, Parent = d })
	Theme.corner(ui.selectBtn, 6)
	ui.selectGrad = Theme.gradient(ui.selectBtn, WHITE, Color3.fromRGB(200, 200, 200), 90)
	Theme.textStroke(ui.selectBtn, 1.5)
	ui.selectBtn.Activated:Connect(function()
		local id = Menu.viewing
		if not id then return end
		SoundFX.play("Select")
		if id == Menu.current then
			Menu.close()
			return
		end
		ui.selectBtn.Text = "…"
		Action:FireServer("Select", id)
	end)
end

local function buildCharacters(page)
	sectionTitle(page, "ВЫБОР ПЕРСОНАЖА", UDim2.fromOffset(0, 0))
	Theme.label({ Name = "Hint", Text = "Нажми на бойца, чтобы увидеть приёмы. Сменить можно вне боя.", Position = UDim2.fromOffset(2, 34),
		Size = UDim2.fromOffset(620, 18), FontFace = Theme.Medium, TextSize = 13, TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Left, Parent = page })
	local grid = Theme.frame({ Name = "Grid", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 64), Size = UDim2.fromOffset(616, 522), Parent = page })
	ui.cards = {}
	for i, id in ipairs(Characters.List) do ui.cards[id] = buildCard(grid, id, i) end
	local holder = Theme.frame({ Name = "DetailsHolder", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(970, 640), Parent = page })
	buildDetails(holder)
end

-- переключатели настроек
local function settingRow(parent, y, title, sub)
	local r = Theme.frame({ Name = "Row", Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(640, 58), BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.15, Parent = parent })
	Theme.corner(r, 6)
	Theme.stroke(r, Theme.Line, 1.2, 0.4)
	Theme.label({ Name = "Name", Text = title, Position = UDim2.fromOffset(16, sub and 8 or 0), Size = UDim2.fromOffset(330, sub and 22 or 58),
		FontFace = Theme.Black, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Parent = r })
	if sub then
		Theme.label({ Name = "Sub", Text = sub, Position = UDim2.fromOffset(16, 30), Size = UDim2.fromOffset(330, 18), FontFace = Theme.Medium,
			TextSize = 12, TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Left, Parent = r })
	end
	return r
end

local function segmented(parent, options, onPick)
	local n = #options
	local w = 90
	local holder = Theme.frame({ Name = "Segmented", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(n * w + (n - 1) * 4, 34), Parent = parent })
	local btns = {}
	local function set(i)
		for j, b in ipairs(btns) do
			b.BackgroundColor3 = j == i and Theme.Accent or Theme.Panel2
			b.TextColor3 = j == i and WHITE or Theme.Dim
		end
	end
	for i, text in ipairs(options) do
		local b = Theme.button({ Name = "Opt" .. i, Text = text, Position = UDim2.fromOffset((i - 1) * (w + 4), 0), Size = UDim2.fromOffset(w, 34),
			TextSize = 13, Parent = holder })
		Theme.corner(b, 5)
		b.Activated:Connect(function()
			SoundFX.play("Click")
			set(i)
			onPick(i)
		end)
		btns[i] = b
	end
	return set
end

local function stepper(parent, fmt, onStep)
	local holder = Theme.frame({ Name = "Stepper", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(180, 34), Parent = parent })
	local minus = Theme.button({ Name = "Minus", Text = "−", Size = UDim2.fromOffset(40, 34), TextSize = 22, Parent = holder })
	Theme.corner(minus, 5)
	local value = Theme.label({ Name = "Value", Text = "", Position = UDim2.fromOffset(44, 0), Size = UDim2.fromOffset(92, 34), BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Panel2, FontFace = Theme.Black, TextSize = 16, Parent = holder })
	Theme.corner(value, 5)
	local plus = Theme.button({ Name = "Plus", Text = "+", Position = UDim2.fromOffset(140, 0), Size = UDim2.fromOffset(40, 34), TextSize = 22, Parent = holder })
	Theme.corner(plus, 5)
	minus.Activated:Connect(function() SoundFX.play("Click") onStep(-1) end)
	plus.Activated:Connect(function() SoundFX.play("Click") onStep(1) end)
	return function(v) value.Text = string.format(fmt, v) end
end

local function buildSettings(page)
	sectionTitle(page, "НАСТРОЙКИ", UDim2.fromOffset(0, 0))
	local y = 56
	-- боты (общие для сервера)
	local r = settingRow(page, y, "Боты на арене", "Общая настройка сервера: 0–" .. Config.Bots.Max)
	local botN = ReplicatedStorage:GetAttribute("BotCount") or Config.Bots.Default
	local setBots
	setBots = stepper(r, "%d", function(d)
		botN = math.clamp(botN + d, 0, Config.Bots.Max)
		setBots(botN)
		Action:FireServer("Bots", botN, nil)
	end)
	setBots(botN)
	ui.setBots = function(n) botN = n setBots(n) end
	y = y + 66
	r = settingRow(page, y, "Сложность ботов", "Как быстро боты реагируют и ставят блок")
	local names = {}
	for i, d in ipairs(Config.Bots.Difficulty) do names[i] = d.Name end
	ui.setLevel = segmented(r, names, function(i) Action:FireServer("Bots", nil, i) end)
	ui.setLevel(ReplicatedStorage:GetAttribute("BotLevel") or Config.Bots.DefaultDifficulty)
	y = y + 66
	r = settingRow(page, y, "Тряска камеры", "Встряска экрана от сильных ударов")
	local setShake = segmented(r, { "Вкл", "Выкл" }, function(i) CameraFX.enabled = i == 1 end)
	setShake(1)
	y = y + 66
	r = settingRow(page, y, "Качество эффектов", "Ниже — больше кадров в секунду на слабых устройствах")
	local setQ = segmented(r, { "Низкое", "Среднее", "Высокое" }, function(i) FX.quality = ({ 0.45, 0.75, 1 })[i] end)
	setQ(UserInputService.TouchEnabled and 2 or 3)
	y = y + 66
	r = settingRow(page, y, "Цифры урона", "Показывать урон над противником")
	local setDmg = segmented(r, { "Вкл", "Выкл" }, function(i) Hud.showDamage = i == 1 end)
	setDmg(1)
	y = y + 66
	r = settingRow(page, y, "Громкость эффектов", nil)
	local vol = 100
	local setVol
	setVol = stepper(r, "%d%%", function(d)
		vol = math.clamp(vol + d * 10, 0, 150)
		SoundFX.volume = vol / 100
		setVol(vol)
	end)
	setVol(vol)
	y = y + 66
	local resp = Theme.button({ Name = "Respawn", Text = "ВОЗРОДИТЬСЯ (если застрял)", Position = UDim2.fromOffset(0, y + 6), Size = UDim2.fromOffset(320, 42),
		TextSize = 15, BackgroundColor3 = Theme.Panel2, Parent = page })
	Theme.corner(resp, 6)
	Theme.stroke(resp, Theme.Line, 1.2, 0.3)
	resp.Activated:Connect(function()
		SoundFX.play("Click")
		Action:FireServer("Respawn")
		Menu.close()
	end)
end

local CONTROLS = {
	{ "ЛКМ", "Удар. Зажми — серия из четырёх ударов" },
	{ "Пробел + 4-й", "Апперкот: подбрасывает врага" },
	{ "4-й в прыжке", "Удар вниз: впечатывает в землю" },
	{ "F", "Блок (держи). Нажми прямо перед ударом — парирование" },
	{ "Q", "Рывок вперёд или назад (W/S)" },
	{ "A/D + Q", "Уворот вбок — уходит от обычных ударов" },
	{ "1 2 3 4", "Приёмы персонажа" },
	{ "G", "Пробуждение, когда шкала заполнена: новые приёмы и ульта" },
	{ "Shift", "Фиксация камеры (как в боевых играх)" },
	{ "M", "Меню · H — подсказки" },
}
local TIPS = {
	"Шкала пробуждения копится, когда вы наносите и получаете урон.",
	"Блок выдерживает около девяти ударов, потом пробивается.",
	"Территория (ульта трёх бойцов) запрещает врагам внутри применять приёмы.",
	"Кулак Бури: нажми клавишу приёма ещё раз во время вспышки — Резонанс.",
	"Телефон: приёмы — нажатие на ячейку, пробуждение — на шкалу.",
	"Геймпад: R2 удар, L2 блок, B рывок, X/Y/R1/L1 приёмы, крестовина ↑ — пробуждение.",
}
local function buildControls(page)
	sectionTitle(page, "УПРАВЛЕНИЕ", UDim2.fromOffset(0, 0))
	for i, row in ipairs(CONTROLS) do
		local y = 56 + (i - 1) * 40
		local k = Theme.label({ Name = "Key" .. i, Text = row[1], Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(130, 32), BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(232, 232, 238), TextColor3 = BLACK, FontFace = Theme.Black, TextSize = 14, Parent = page })
		Theme.corner(k, 5)
		Theme.label({ Name = "Text" .. i, Text = row[2], Position = UDim2.fromOffset(146, y), Size = UDim2.fromOffset(480, 32), FontFace = Theme.Bold,
			TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Parent = page })
	end
	local tips = Theme.frame({ Name = "Tips", Position = UDim2.fromOffset(660, 56), Size = UDim2.fromOffset(310, 392), BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.15, Parent = page })
	Theme.corner(tips, 8)
	Theme.stroke(tips, Theme.Line, 1.2, 0.3)
	Theme.label({ Name = "Head", Text = "СОВЕТЫ", Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(280, 24), FontFace = Theme.BlackItalic,
		TextSize = 18, TextColor3 = Theme.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = tips })
	for i, t in ipairs(TIPS) do
		Theme.label({ Name = "Tip" .. i, Text = "•  " .. t, Position = UDim2.fromOffset(16, 40 + (i - 1) * 58), Size = UDim2.fromOffset(282, 54),
			FontFace = Theme.Medium, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(215, 216, 226), Parent = tips })
	end
end

local TABS = { { "chars", "ПЕРСОНАЖИ" }, { "settings", "НАСТРОЙКИ" }, { "controls", "УПРАВЛЕНИЕ" } }

function Menu.init(gui)
	ui.gui = gui
	local root = Hud.makeRoot(gui, "Menu")
	ui.root = root
	root.Visible = false
	-- фон
	local bg = Theme.frame({ Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 6, 10), BackgroundTransparency = 0.12, Parent = root })
	Theme.gradient(bg, Color3.fromRGB(30, 10, 14), Color3.fromRGB(6, 6, 12), 25)
	ui.bg = bg
	for i = 1, 3 do
		Theme.frame({ Name = "Slash" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.18 + i * 0.07, 0, 0.5, 0),
			Size = UDim2.new(0, 34 + i * 10, 1.6, 0), Rotation = 18, BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.86 + i * 0.03, Parent = bg })
	end
	-- левая колонка
	local left = Theme.frame({ Name = "Left", BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 44), Size = UDim2.fromOffset(300, 690), Parent = root })
	local l1 = Theme.label({ Name = "Logo1", Text = "CURSED", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(300, 64), FontFace = Theme.BlackItalic,
		TextSize = 62, TextXAlignment = Enum.TextXAlignment.Left, Parent = left })
	Theme.textStroke(l1, 2)
	local l2 = Theme.label({ Name = "Logo2", Text = "ARENA", Position = UDim2.fromOffset(28, 54), Size = UDim2.fromOffset(300, 64), FontFace = Theme.BlackItalic,
		TextSize = 62, TextXAlignment = Enum.TextXAlignment.Left, Parent = left })
	Theme.gradient(l2, Theme.Accent, Theme.Gold, 0)
	Theme.textStroke(l2, 2)
	Theme.label({ Name = "Subtitle", Text = string.upper(Config.Subtitle), Position = UDim2.fromOffset(32, 118), Size = UDim2.fromOffset(268, 20),
		FontFace = Theme.Black, TextSize = 14, TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Left, Parent = left })
	ui.tabs = {}
	for i, t in ipairs(TABS) do
		local b = Theme.button({ Name = "Tab_" .. t[1], Text = t[2], Position = UDim2.fromOffset(0, 172 + (i - 1) * 54), Size = UDim2.fromOffset(280, 46),
			TextSize = 18, FontFace = Theme.BlackItalic, BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.2,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = left })
		Theme.corner(b, 6)
		Theme.padding(b, 18)
		local bar = Theme.frame({ Name = "Bar", Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = Theme.Accent, Visible = false, Parent = b })
		b.Activated:Connect(function()
			SoundFX.play("Click")
			Menu.tab(t[1])
		end)
		ui.tabs[t[1]] = { btn = b, bar = bar }
	end
	local play = Theme.button({ Name = "Play", Text = "В БОЙ", Position = UDim2.fromOffset(0, 560), Size = UDim2.fromOffset(280, 64),
		TextSize = 30, FontFace = Theme.BlackItalic, BackgroundColor3 = WHITE, Parent = left })
	Theme.corner(play, 6)
	Theme.gradient(play, Theme.Accent, Color3.fromRGB(200, 40, 60), 0)
	Theme.textStroke(play, 2)
	play.Activated:Connect(function()
		SoundFX.play("Select")
		Menu.close()
	end)
	ui.play = play
	Theme.label({ Name = "Version", Text = "версия " .. Config.Version .. "  ·  оригинальная игра в жанре battlegrounds", Position = UDim2.fromOffset(0, 640),
		Size = UDim2.fromOffset(300, 16), FontFace = Theme.Medium, TextSize = 11, TextColor3 = Color3.fromRGB(110, 110, 125),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = left })
	-- страницы
	local content = Theme.frame({ Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(370, 44), Size = UDim2.fromOffset(970, 690), Parent = root })
	ui.pages = {}
	for _, t in ipairs(TABS) do
		ui.pages[t[1]] = Theme.frame({ Name = "Page_" .. t[1], BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = content })
	end
	buildCharacters(ui.pages.chars)
	buildSettings(ui.pages.settings)
	buildControls(ui.pages.controls)
	Menu.current = player:GetAttribute("CharId") or Characters.Default
	Menu.view(Menu.current)
	Menu.tab("chars")
	-- крутим превью в карточке подробностей
	RunService.RenderStepped:Connect(function()
		if not Menu.isOpen or not ui.detModel or not ui.detModel.Parent then return end
		local t = os.clock()
		ui.detModel:PivotTo(CFrame.new(0, 3, 0) * CFrame.Angles(0, math.pi + 0.5 + math.sin(t * 0.7) * 0.6, 0))
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Config.Keys.Menu or input.KeyCode == Enum.KeyCode.ButtonSelect then
			if Menu.isOpen then Menu.close() else Menu.open() end
		end
	end)
end

function Menu.tab(name)
	for id, t in pairs(ui.tabs) do
		local on = id == name
		t.bar.Visible = on
		t.btn.BackgroundColor3 = on and Theme.Panel2 or Theme.Panel
		t.btn.BackgroundTransparency = on and 0.05 or 0.25
		t.btn.TextColor3 = on and WHITE or Theme.Dim
		ui.pages[id].Visible = on
	end
	Menu.activeTab = name
end

-- показать персонажа в карточке подробностей
function Menu.view(charId)
	if not Characters.valid(charId) then return end
	Menu.viewing = charId
	local def = Characters.get(charId)
	for id, c in pairs(ui.cards) do
		local on = id == charId
		c.stroke.Color = on and def.Color or Theme.Line
		c.stroke.Thickness = on and 3 or 1.5
		c.stroke.Transparency = on and 0 or 0.2
		c.badge.Visible = id == Menu.current
	end
	ui.detStroke.Color = def.Color
	ui.detBand.BackgroundColor3 = def.Color
	ui.detBandGrad.Color = ColorSequence.new(def.Color, def.Accent)
	ui.detGrad.Color = ColorSequence.new(Theme.shade(def.Dark, 0.12), Theme.Panel)
	ui.detName.Text = string.upper(def.Name)
	ui.detTitle.Text = def.Title
	ui.detDiff.Text = string.upper(def.Difficulty)
	ui.detDiff.BackgroundColor3 = DIFF_COLOR[def.Difficulty] or Theme.Line
	ui.detDesc.Text = def.Desc
	for _, c in ipairs(ui.detMoves:GetChildren()) do c:Destroy() end
	for i, m in ipairs(def.Moves) do moveRow(ui.detMoves, (i - 1) * 46, tostring(i), m, def.Color) end
	ui.detAwk.Text = "ПРОБУЖДЕНИЕ: " .. def.Awakening.Name
	ui.detAwk.TextColor3 = def.Accent:Lerp(WHITE, 0.2)
	local parts = {}
	for i, m in ipairs(def.Awakening.Moves) do
		local n = m.Name
		if m.Ultimate then n = '<font color="#FFD65C">' .. n .. "</font>" end
		parts[#parts + 1] = i .. " " .. n
	end
	ui.detAwkList.Text = table.concat(parts, "  ·  ")
	-- большое превью
	for _, c in ipairs(ui.detView:GetChildren()) do c:Destroy() end
	local _, m = viewport(ui.detView, { Size = UDim2.fromScale(1, 1) }, charId, 10.5, 0.5)
	ui.detModel = m
	if charId == Menu.current then
		ui.selectBtn.Text = "ВЫБРАН — В БОЙ"
		ui.selectBtn.BackgroundColor3 = Theme.Good
	else
		ui.selectBtn.Text = "ВЫБРАТЬ"
		ui.selectBtn.BackgroundColor3 = def.Color
	end
end

-- ответ сервера на выбор
function Menu.selected(charId, ok)
	if ok then
		Menu.current = charId
		Hud.notify("Теперь вы — " .. Characters.get(charId).Name, "good")
		SoundFX.play("Ready")
		Menu.view(charId)
		task.delay(0.35, function() if Menu.isOpen then Menu.close() end end)
	else
		Menu.view(Menu.viewing or charId)
	end
end

function Menu.botsConfig(d)
	if d.n and ui.setBots then ui.setBots(d.n) end
	if d.l and ui.setLevel then ui.setLevel(d.l) end
end

local blur
function Menu.open(tab)
	if tab then Menu.tab(tab) end
	if Menu.isOpen then return end
	Menu.isOpen = true
	ui.root.Visible = true
	ui.bg.BackgroundTransparency = 0.6
	tween(ui.bg, 0.25, { BackgroundTransparency = 0.12 })
	local cam = workspace.CurrentCamera
	if cam then
		blur = blur or Instance.new("BlurEffect")
		blur.Size = 0
		blur.Parent = cam
		tween(blur, 0.25, { Size = 14 })
	end
	Menu.view(Menu.viewing or Menu.current)
	if Menu.onOpen then Menu.onOpen(true) end
end

function Menu.close()
	if not Menu.isOpen then return end
	Menu.isOpen = false
	ui.root.Visible = false
	if blur then blur.Parent = nil end
	if Menu.onOpen then Menu.onOpen(false) end
end

return Menu
