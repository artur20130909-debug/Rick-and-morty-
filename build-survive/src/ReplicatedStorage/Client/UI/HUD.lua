-- Основной интерфейс: золото, меню справа, панель инструментов, подсказки, уведомления,
-- красная рамка при уроне, белая вспышка.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local Client = script.Parent.Parent
local State = require(Client.State)
local SoundPlayer = require(Client.SoundPlayer)
local Theme = require(script.Parent.Theme)
local Lib = require(script.Parent.Lib)

local new = Lib.new
local HUD = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local modals: { [string]: { shade: GuiObject, onOpen: (() -> ())?, onClose: (() -> ())? } } = {}
local toastHolder: Frame
local hotbarButtons: { [string]: TextButton } = {}
local menuButtons: { [string]: TextButton } = {}
local hintLabel: TextLabel
local goldLabel: TextLabel
local blocksLabel: TextLabel
local vignette: Frame
local flashFrame: Frame
local hotbar: Frame
local launchBar: Frame

HUD.onTool = State.newSignal()      -- (tool)
HUD.onUndo = State.newSignal()

function HUD.gui(): ScreenGui
	return gui
end

-- ОКНА ------------------------------------------------------------------------------
function HUD.registerModal(name: string, shade: GuiObject, onOpen: (() -> ())?, onClose: (() -> ())?)
	modals[name] = { shade = shade, onOpen = onOpen, onClose = onClose }
end

function HUD.openModal(name: string)
	if State.modal == name then
		HUD.closeModal()
		return
	end
	if State.modal then
		HUD.closeModal()
	end
	local m = modals[name]
	if not m then
		return
	end
	State.set("modal", name)
	if m.onOpen then
		m.onOpen()
	end
	Lib.showModal(m.shade, true)
end

function HUD.closeModal()
	local name = State.modal
	if not name then
		return
	end
	local m = modals[name]
	State.set("modal", nil)
	if m then
		Lib.showModal(m.shade, false)
		if m.onClose then
			m.onClose()
		end
	end
end

-- УВЕДОМЛЕНИЯ -----------------------------------------------------------------------
local KIND_COLORS = {
	info = Theme.Info,
	success = Theme.Good,
	warning = Theme.Accent,
	error = Theme.Bad,
	gold = Theme.Gold,
}

function HUD.toast(text: string, kind: string?)
	if not toastHolder then
		return
	end
	local color = KIND_COLORS[kind or "info"] or Theme.Info
	local t = Lib.panel({
		Size = UDim2.new(0, 0, 0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.12,
		LayoutOrder = -math.floor(os.clock() * 1000),
		Parent = toastHolder,
	})
	new("Frame", {
		Size = UDim2.new(0, 5, 1, -14),
		Position = UDim2.fromOffset(8, 7),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = t,
	}, { Lib.corner(3) })
	local l = Lib.label(text, 18, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Position = UDim2.fromOffset(22, 0),
		TextWrapped = false,
		Parent = t,
	})
	new("UIPadding", { PaddingRight = UDim.new(0, 36), Parent = t })
	local scale = new("UIScale", { Scale = 0.7, Parent = t })
	Lib.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	if kind == "error" then
		SoundPlayer.play("Error")
	end
	task.delay(3.6, function()
		Lib.tween(t, 0.35, { BackgroundTransparency = 1 })
		Lib.tween(l, 0.35, { TextTransparency = 1 })
		task.wait(0.4)
		t:Destroy()
	end)
	local children = toastHolder:GetChildren()
	local count = 0
	for _, c in children do
		if c:IsA("Frame") then
			count += 1
		end
	end
	if count > 5 then
		local oldest, order = nil, -math.huge
		for _, c in children do
			if c:IsA("Frame") and c.LayoutOrder > order then
				oldest, order = c, c.LayoutOrder
			end
		end
		if oldest then
			oldest:Destroy()
		end
	end
end

-- ЭФФЕКТЫ ЭКРАНА --------------------------------------------------------------------
function HUD.flash(color: Color3, strength: number, time: number)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 1 - math.clamp(strength, 0, 1)
	Lib.tween(flashFrame, time, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

function HUD.damage(amount: number)
	local a = math.clamp(amount / 40, 0.25, 1)
	for _, edge in vignette:GetChildren() do
		if edge:IsA("Frame") then
			edge.BackgroundTransparency = 1 - a * 0.85
			Lib.tween(edge, 0.9, { BackgroundTransparency = 1 })
		end
	end
end

function HUD.setHint(text: string)
	if hintLabel then
		hintLabel.Text = text
		hintLabel.Visible = text ~= ""
	end
end

function HUD.setHotbarVisible(v: boolean)
	hotbar.Visible = v
end

function HUD.setLaunchBar(v: boolean)
	launchBar.Visible = v
end

-- ПОСТРОЕНИЕ ------------------------------------------------------------------------
local TOOLS = {
	{ key = "build", icon = "🔨", name = "Строить", hotkey = "1" },
	{ key = "delete", icon = "🗑", name = "Удалить", hotkey = "2" },
	{ key = "paint", icon = "🎨", name = "Красить", hotkey = "3" },
	{ key = "pick", icon = "💧", name = "Пипетка", hotkey = "4" },
}

local MENU = {
	{ key = "shop", icon = "🛒", name = "Магазин", color = Color3.fromRGB(64, 170, 90) },
	{ key = "siege", icon = "💣", name = "Осада", color = Color3.fromRGB(214, 64, 52) },
	{ key = "launch", icon = "🚀", name = "Испытать", color = Color3.fromRGB(64, 120, 220) },
	{ key = "saves", icon = "💾", name = "Сохранить", color = Color3.fromRGB(120, 90, 210) },
	{ key = "settings", icon = "⚙", name = "Настройки", color = Color3.fromRGB(70, 78, 100) },
}

HUD.onMenu = State.newSignal() -- (key)

local function buildTopLeft()
	local holder = new("Frame", {
		Position = UDim2.fromOffset(16, 64),
		Size = UDim2.fromOffset(420, 52),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Lib.list(Enum.FillDirection.Horizontal, 10) })
	local goldPill = Lib.panel({ Size = UDim2.fromOffset(170, 48), BackgroundColor3 = Theme.Bg, LayoutOrder = 1, Parent = holder })
	local coin = Lib.coin(30)
	coin.Position = UDim2.fromOffset(10, 9)
	coin.Parent = goldPill
	goldLabel = Lib.label("0", 26, {
		FontFace = Theme.FontHeavy,
		Position = UDim2.fromOffset(48, 0),
		Size = UDim2.new(1, -56, 1, 0),
		TextColor3 = Theme.Gold,
		Parent = goldPill,
	})
	local blocksPill = Lib.panel({ Size = UDim2.fromOffset(170, 48), BackgroundColor3 = Theme.Bg, LayoutOrder = 2, Parent = holder })
	Lib.label("🧱", 24, { Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(32, 48), Parent = blocksPill })
	blocksLabel = Lib.label("0 / " .. Config.MaxBlocks, 20, {
		FontFace = Theme.FontHeavy,
		Position = UDim2.fromOffset(46, 0),
		Size = UDim2.new(1, -52, 1, 0),
		Parent = blocksPill,
	})
end

function HUD.setGold(amount: number, animate: boolean?)
	local old = tonumber((string.gsub(goldLabel.Text, "%s", ""))) or 0
	goldLabel.Text = Util.formatNumber(amount)
	if animate and amount > old then
		local plus = Lib.label("+" .. Util.formatNumber(amount - old), 22, {
			FontFace = Theme.FontHeavy,
			TextColor3 = Theme.Gold,
			Position = UDim2.fromOffset(60, 112),
			Size = UDim2.fromOffset(160, 30),
			Parent = gui,
		})
		new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(80, 50, 0), Parent = plus })
		Lib.tween(plus, 1.2, { Position = UDim2.fromOffset(60, 80), TextTransparency = 1 })
		task.delay(1.3, function()
			plus:Destroy()
		end)
		SoundPlayer.play("Coin")
	end
end

function HUD.setBlocks(n: number)
	blocksLabel.Text = string.format("%d / %d", n, Config.MaxBlocks)
	blocksLabel.TextColor3 = n >= Config.MaxBlocks and Theme.Bad or Theme.Text
end

local function buildMenu()
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(96, 5 * 104),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Lib.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Right) })
	for i, m in MENU do
		local b = Lib.button("", {
			Size = UDim2.fromOffset(92, 92),
			BackgroundColor3 = m.color,
			LayoutOrder = i,
			Parent = holder,
		}, function()
			HUD.onMenu:Fire(m.key)
		end)
		new("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 180)),
			Rotation = 90,
			Parent = b,
		})
		Lib.label(m.icon, 38, {
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(1, 0, 0, 46),
			Parent = b,
		})
		local l = Lib.label(m.name, 16, {
			FontFace = Theme.FontHeavy,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 0, 1, -30),
			Size = UDim2.new(1, 0, 0, 22),
			Parent = b,
		})
		new("UIStroke", { Thickness = 1.5, Color = Color3.new(0, 0, 0), Transparency = 0.5, Parent = l })
		menuButtons[m.key] = b
	end
end

function HUD.menuButton(key: string): TextButton?
	return menuButtons[key]
end

local function buildHotbar()
	hotbar = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(5 * 84 + 4 * 8 + 24, 100),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local bar = Lib.panel({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.2,
		Parent = hotbar,
	})
	local row = new("Frame", {
		Size = UDim2.new(1, -24, 1, -16),
		Position = UDim2.fromOffset(12, 8),
		BackgroundTransparency = 1,
		Parent = bar,
	}, { Lib.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	for i, t in TOOLS do
		local b = Lib.button("", { Size = UDim2.fromOffset(84, 84), LayoutOrder = i, Parent = row }, function()
			HUD.onTool:Fire(if State.tool == t.key then nil else t.key)
		end)
		Lib.label(t.icon, 32, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 40), Parent = b })
		Lib.label(t.name, 14, { FontFace = Theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -28), Size = UDim2.new(1, 0, 0, 20), Parent = b })
		Lib.label(t.hotkey, 13, { TextColor3 = Theme.Sub, Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(20, 16), Parent = b })
		hotbarButtons[t.key] = b
	end
	local undo = Lib.button("", { Size = UDim2.fromOffset(84, 84), LayoutOrder = 10, BackgroundColor3 = Theme.Panel3, Parent = row }, function()
		HUD.onUndo:Fire()
	end)
	Lib.label("↶", 34, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 42), Parent = undo })
	Lib.label("Отмена", 14, { FontFace = Theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -28), Size = UDim2.new(1, 0, 0, 20), Parent = undo })
	Lib.label("Z", 13, { TextColor3 = Theme.Sub, Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(20, 16), Parent = undo })

	hintLabel = Lib.label("", 17, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -124),
		Size = UDim2.fromOffset(900, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(235, 240, 255),
		Parent = gui,
	})
	new("UIStroke", { Thickness = 2, Transparency = 0.35, Parent = hintLabel })
end

function HUD.setTool(tool: string?)
	for key, b in hotbarButtons do
		local active = key == tool
		Lib.setButtonColor(b, active and Theme.Accent2 or Theme.Panel2)
		local stroke = b:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = active and Theme.Accent or Theme.Stroke
			stroke.Transparency = active and 0 or 0.82
			stroke.Thickness = active and 3 or 1.5
		end
	end
end

local function buildOverlays()
	vignette = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 50, Parent = gui })
	local edges = {
		{ UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0.75), 270 },
		{ UDim2.fromScale(0.2, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.2, 1), UDim2.fromScale(0.8, 0), 180 },
	}
	for _, e in edges do
		new("Frame", {
			Size = e[1],
			Position = e[2],
			BackgroundColor3 = Color3.fromRGB(200, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 50,
			Parent = vignette,
		}, {
			new("UIGradient", {
				Rotation = e[3],
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
			}),
		})
	end
	flashFrame = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 60,
		Parent = gui,
	})
	toastHolder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.fromOffset(700, 300),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = gui,
	}, { Lib.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center) })
end

local function buildLaunchBar()
	launchBar = Lib.panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(620, 96),
		BackgroundColor3 = Theme.Bg,
		Visible = false,
		Parent = gui,
	})
	Lib.label("🚀 ИСПЫТАНИЕ", 24, { FontFace = Theme.FontHeavy, Position = UDim2.fromOffset(20, 10), Size = UDim2.fromOffset(360, 30), TextColor3 = Theme.Info, Parent = launchBar })
	Lib.label("Сядь в кресло водителя: W/S — газ, A/D — поворот. Двигатели работают на W.", 15, {
		TextColor3 = Theme.Sub, Position = UDim2.fromOffset(20, 44), Size = UDim2.fromOffset(420, 44), Parent = launchBar,
	})
	local stop = Lib.button("■  СТОП", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(140, 60),
		BackgroundColor3 = Theme.Bad,
		TextSize = 22,
		Parent = launchBar,
	})
	stop.Activated:Connect(function()
		HUD.onMenu:Fire("launchStop")
	end)
end

function HUD.init()
	gui = new("ScreenGui", {
		Name = "BuildSurviveUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local scale = new("UIScale", { Parent = gui })
	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(vp.X / 1500, vp.Y / 900), 0.5, 1.25)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
	buildTopLeft()
	buildMenu()
	buildHotbar()
	buildLaunchBar()
	buildOverlays()
	HUD.setTool(nil)

	-- урон по игроку → красная рамка
	local function watch(char: Model)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		local last = hum.Health
		hum.HealthChanged:Connect(function(h)
			if h < last - 0.5 then
				HUD.damage(last - h)
			end
			last = h
		end)
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end

	-- Esc закрывает окно
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape and State.modal then
			HUD.closeModal()
		end
	end)
end

return HUD
