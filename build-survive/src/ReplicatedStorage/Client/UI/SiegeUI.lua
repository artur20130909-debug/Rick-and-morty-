-- Осада в интерфейсе: меню выбора режима, панель волны, полигон, предупреждения, итоги.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Weapons = require(Shared.Weapons)
local Util = require(Shared.Util)
local Net = require(Shared.Net)

local Client = script.Parent.Parent
local State = require(Client.State)
local SoundPlayer = require(Client.SoundPlayer)
local Theme = require(script.Parent.Theme)
local Lib = require(script.Parent.Lib)
local HUD = require(script.Parent.HUD)

local new = Lib.new
local SiegeUI = {}

local player = Players.LocalPlayer
local mode = "survival"
local difficulty = 2
local modeCards: { [string]: TextButton } = {}
local diffButtons: { TextButton } = {}
local recordLabel: TextLabel

local waveBar: Frame
local waveTitle: TextLabel
local waveSub: TextLabel
local waveFill: Frame
local bigText: TextLabel
local bigSub: TextLabel
local rangePanel: Frame
local weaponButtons: { [string]: TextButton } = {}
local targetBtn: TextButton
local warnBanner: Frame
local warnText: TextLabel
local resultBody: Frame

local waveEndsAt = 0
local waveDuration = 1
local warnUntil = 0

local function waveColor(i: number): Color3
	local t = (i - 1) / (#Weapons.List - 1)
	return Color3.fromRGB(80, 200, 110):Lerp(Color3.fromRGB(255, 190, 50), math.min(1, t * 2)):Lerp(Color3.fromRGB(235, 50, 50), math.max(0, t * 2 - 1))
end

-- МЕНЮ ------------------------------------------------------------------------------
local function refreshMenu()
	for k, b in modeCards do
		local on = k == mode
		local stroke = b:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = on and Theme.Accent or Theme.Stroke
			stroke.Transparency = on and 0 or 0.85
			stroke.Thickness = on and 3 or 1.5
		end
		Lib.setButtonColor(b, on and Theme.Panel3 or Theme.Panel2)
	end
	for i, b in diffButtons do
		local d = Config.Difficulties[i]
		Lib.setButtonColor(b, i == difficulty and d.color or Theme.Panel2)
		b.Visible = mode == "survival"
	end
	recordLabel.Text = string.format("Твой рекорд: волна %d  •  Пережито ядерок: %d", State.bestWave, State.stats.Nukes or 0)
end

local function buildMenu()
	local shade, body = Lib.modal(HUD.gui(), "💣 ОСАДА", Vector2.new(940, 620), function()
		HUD.closeModal()
	end)
	local left = new("Frame", { Size = UDim2.new(0.52, -10, 1, 0), BackgroundTransparency = 1, Parent = body }, { Lib.list(Enum.FillDirection.Vertical, 12) })
	local cardsInfo = {
		{ "survival", "🛡 ВЫЖИВАНИЕ", "Волна за волной: пули, мины, ракеты... На 11-й волне — ядерная бомба, на 12-й — орбитальный лазер. Чем дольше живёшь — тем больше золота." },
		{ "range", "🎯 ПОЛИГОН", "Выбирай любое оружие и стреляй по своей постройке сам. Проверь, выдержит ли бункер ядерный удар. Без награды." },
	}
	for i, c in cardsInfo do
		local b = Lib.button("", { Size = UDim2.new(1, 0, 0, 132), LayoutOrder = i, Parent = left }, function()
			mode = c[1]
			refreshMenu()
		end)
		Lib.label(c[2], 24, { FontFace = Theme.FontHeavy, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 30), Parent = b })
		Lib.label(c[3], 15, {
			TextColor3 = Theme.Sub,
			Position = UDim2.fromOffset(16, 46),
			Size = UDim2.new(1, -32, 0, 80),
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = b,
		})
		modeCards[c[1]] = b
	end
	Lib.label("Сложность", 18, { FontFace = Theme.FontHeavy, LayoutOrder = 3, Parent = left })
	local diffRow = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 4, Parent = left }, {
		Lib.list(Enum.FillDirection.Horizontal, 8),
	})
	for i, d in Config.Difficulties do
		diffButtons[i] = Lib.button(d.name, { Size = UDim2.new(0.25, -6, 1, 0), TextSize = 15, LayoutOrder = i, Parent = diffRow }, function()
			difficulty = i
			refreshMenu()
		end)
	end
	recordLabel = Lib.label("", 15, { TextColor3 = Theme.Sub, LayoutOrder = 5, Parent = left })
	local start = Lib.button("НАЧАТЬ ОСАДУ", {
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Theme.Bad,
		TextSize = 26,
		LayoutOrder = 6,
		Parent = left,
	})
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 170, 170)), Rotation = 90, Parent = start })
	start.Activated:Connect(function()
		SoundPlayer.play("Click")
		local ok, msg = Net.func("StartSiege"):InvokeServer(mode, difficulty)
		if ok then
			HUD.closeModal()
		elseif msg then
			HUD.toast(msg, "error")
		end
	end)

	-- список оружия
	local right = Lib.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.48, -10, 1, 0),
		BackgroundColor3 = Theme.Panel,
		Parent = body,
	})
	Lib.label("Что прилетит", 18, { FontFace = Theme.FontHeavy, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 24), Parent = right })
	local rows = new("Frame", { Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 1, -46), BackgroundTransparency = 1, Parent = right }, {
		Lib.list(Enum.FillDirection.Vertical, 3),
	})
	for i, w in Weapons.List do
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Theme.Panel2, BackgroundTransparency = 0.3, LayoutOrder = i, Parent = rows }, { Lib.corner(8) })
		new("Frame", { Size = UDim2.new(0, 5, 1, -10), Position = UDim2.fromOffset(5, 5), BackgroundColor3 = waveColor(i), BorderSizePixel = 0, Parent = row }, { Lib.corner(3) })
		Lib.label(w.icon, 20, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(28, 38), TextYAlignment = Enum.TextYAlignment.Center, Parent = row })
		Lib.label(w.name, 16, { FontFace = Theme.FontHeavy, Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -140, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, Parent = row })
		Lib.label("волна " .. w.wave, 14, {
			TextColor3 = waveColor(i),
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -96, 0, 0),
			Size = UDim2.fromOffset(86, 38),
			TextYAlignment = Enum.TextYAlignment.Center,
			Parent = row,
		})
	end
	HUD.registerModal("siege", shade, refreshMenu)
end

-- ПАНЕЛЬ ВОЛНЫ --------------------------------------------------------------------------
local function buildWaveBar()
	local gui = HUD.gui()
	waveBar = Lib.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(520, 92),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	})
	waveTitle = Lib.label("ВОЛНА 1", 30, {
		FontFace = Theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 34),
		Parent = waveBar,
	})
	waveSub = Lib.label("", 16, {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Accent,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 22),
		Parent = waveBar,
	})
	local track = new("Frame", {
		Position = UDim2.new(0, 20, 1, -22),
		Size = UDim2.new(1, -40, 0, 10),
		BackgroundColor3 = Theme.Panel2,
		BorderSizePixel = 0,
		Parent = waveBar,
	}, { Lib.corner(5) })
	waveFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = track }, {
		Lib.corner(5),
		Lib.gradient(Theme.Accent, Theme.Accent2, 0),
	})
	local giveUp = Lib.button("Сдаться", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 10, 0.5, 0),
		Size = UDim2.fromOffset(110, 44),
		BackgroundColor3 = Theme.Panel3,
		TextSize = 16,
		Parent = waveBar,
	})
	giveUp.Activated:Connect(function()
		Net.func("StopSiege"):InvokeServer()
	end)

	bigText = Lib.label("", 64, {
		FontFace = Theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(900, 80),
		Visible = false,
		Parent = gui,
	})
	new("UIStroke", { Thickness = 4, Color = Color3.fromRGB(40, 10, 0), Parent = bigText })
	bigSub = Lib.label("", 26, {
		FontFace = Theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.fromOffset(900, 40),
		TextColor3 = Theme.Accent,
		Visible = false,
		Parent = gui,
	})
	new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(20, 10, 0), Parent = bigSub })

	warnBanner = Lib.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 166),
		Size = UDim2.fromOffset(760, 64),
		BackgroundColor3 = Color3.fromRGB(150, 16, 16),
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	})
	warnText = Lib.label("", 26, {
		FontFace = Theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = warnBanner,
	})
end

local bigToken = 0
local function showBig(text: string, sub: string?, color: Color3?, time: number?)
	bigToken += 1
	local token = bigToken
	bigText.Text = text
	bigText.TextColor3 = color or Theme.Text
	bigText.Visible = true
	bigText.TextTransparency = 0
	bigSub.Text = sub or ""
	bigSub.Visible = sub ~= nil
	bigSub.TextTransparency = 0
	local scale = bigText:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = bigText })
	scale.Scale = 1.5
	Lib.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(time or 1.6, function()
		if token ~= bigToken then
			return
		end
		Lib.tween(bigText, 0.4, { TextTransparency = 1 })
		Lib.tween(bigSub, 0.4, { TextTransparency = 1 })
		task.wait(0.45)
		if token == bigToken then
			bigText.Visible = false
			bigSub.Visible = false
		end
	end)
end

function SiegeUI.warn(text: string, duration: number)
	warnText.Text = text
	warnBanner.Visible = true
	warnUntil = os.clock() + duration
end

-- ПОЛИГОН ---------------------------------------------------------------------------
local function refreshRange()
	for key, b in weaponButtons do
		Lib.setButtonColor(b, (State.rangeTarget == "click" and State.rangeWeapon == key) and Theme.Accent2 or Theme.Panel2)
	end
	targetBtn.Text = State.rangeTarget == "me" and "🎯 Цель: я" or "👆 Цель: клик"
end

local function fireRange(key: string, aim: Vector3?)
	task.spawn(function()
		local ok, msg = Net.func("FireRange"):InvokeServer(key, aim)
		if not ok and msg then
			HUD.toast(msg, "warning")
		end
	end)
end

local function buildRange()
	rangePanel = Lib.panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(880, 168),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = HUD.gui(),
	})
	local gridFrame = new("Frame", { Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -200, 1, -24), BackgroundTransparency = 1, Parent = rangePanel }, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(106, 66), CellPadding = UDim2.fromOffset(6, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, w in Weapons.List do
		local b = Lib.button("", { LayoutOrder = i, Parent = gridFrame }, function()
			if State.rangeTarget == "me" then
				fireRange(w.key, nil)
			else
				State.rangeWeapon = w.key
				refreshRange()
			end
		end)
		Lib.label(w.icon, 22, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 26), TextColor3 = waveColor(i), Parent = b })
		Lib.label(w.name, 12, {
			FontFace = Theme.FontHeavy,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(2, 30),
			Size = UDim2.new(1, -4, 0, 32),
			TextYAlignment = Enum.TextYAlignment.Center,
			Parent = b,
		})
		weaponButtons[w.key] = b
	end
	local side = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.new(0, 172, 1, -24), BackgroundTransparency = 1, Parent = rangePanel }, {
		Lib.list(Enum.FillDirection.Vertical, 8),
	})
	targetBtn = Lib.button("", { Size = UDim2.new(1, 0, 0, 40), TextSize = 16, LayoutOrder = 1, Parent = side }, function()
		State.rangeTarget = State.rangeTarget == "me" and "click" or "me"
		if State.rangeTarget == "click" then
			HUD.toast("Выбери оружие и кликни по постройке", "info")
		end
		refreshRange()
	end)
	Lib.button("↺ Восстановить", { Size = UDim2.new(1, 0, 0, 40), TextSize = 16, BackgroundColor3 = Theme.Info, LayoutOrder = 2, Parent = side }, function()
		task.spawn(function()
			local ok, msg = Net.func("Restore"):InvokeServer()
			if ok and msg then
				HUD.toast(msg, "success")
			end
		end)
	end)
	Lib.button("✕ Выйти", { Size = UDim2.new(1, 0, 0, 40), TextSize = 16, BackgroundColor3 = Theme.Bad, LayoutOrder = 3, Parent = side }, function()
		task.spawn(function()
			Net.func("StopSiege"):InvokeServer()
		end)
	end)
	refreshRange()

	-- выстрел кликом по миру
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not State.inSiege() or State.siege.mode ~= "range" or State.rangeTarget ~= "click" then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local ray
		if input.UserInputType == Enum.UserInputType.Touch then
			ray = workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y)
		else
			local m = UserInputService:GetMouseLocation()
			ray = workspace.CurrentCamera:ViewportPointToRay(m.X, m.Y)
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Instance }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
		if hit then
			fireRange(State.rangeWeapon, hit.Position)
		end
	end)
end

-- ИТОГИ -----------------------------------------------------------------------------
local function buildResults()
	local shade, body = Lib.modal(HUD.gui(), "ОСАДА ОКОНЧЕНА", Vector2.new(560, 460), function()
		HUD.closeModal()
	end)
	resultBody = body
	HUD.registerModal("results", shade)
end

local REASONS = {
	died = "Тебя уничтожили",
	fled = "Ты покинул остров",
	stop = "Ты сдался",
}

local function showResults(r)
	for _, c in resultBody:GetChildren() do
		if not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
	local holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = resultBody }, { Lib.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Center) })
	Lib.label(REASONS[r.reason] or "", 20, { TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = holder })
	if r.record then
		local badge = Lib.label("🏆 НОВЫЙ РЕКОРД!", 30, {
			FontFace = Theme.FontHeavy,
			TextColor3 = Theme.Gold,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 2,
			Parent = holder,
		})
		new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(80, 50, 0), Parent = badge })
	end
	local statsGrid = new("Frame", { Size = UDim2.new(1, 0, 0, 200), BackgroundTransparency = 1, LayoutOrder = 3, Parent = holder }, {
		new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 94), CellPadding = UDim2.fromOffset(12, 12) }),
	})
	local stats = {
		{ "Волн пережито", tostring(r.waves), Theme.Accent },
		{ "Заработано", "+" .. Util.formatNumber(r.gold), Theme.Gold },
		{ "Разрушено блоков", Util.formatNumber(r.blocksLost), Theme.Bad },
		{ "Время", Util.formatTime(r.time), Theme.Info },
	}
	for _, s in stats do
		local card = Lib.panel({ BackgroundColor3 = Theme.Panel2, Parent = statsGrid })
		Lib.label(s[1], 15, { TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 20), Parent = card })
		Lib.label(s[2], 34, { FontFace = Theme.FontHeavy, TextColor3 = s[3], TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 40), Parent = card })
	end
	Lib.label("Постройка сейчас восстановится. Улучши её в магазине и попробуй снова!", 15, {
		TextColor3 = Theme.Sub,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 4,
		Parent = holder,
	})
	Lib.button("OK", { Size = UDim2.fromOffset(200, 50), BackgroundColor3 = Theme.Good, TextSize = 22, LayoutOrder = 5, Parent = holder }, function()
		HUD.closeModal()
	end)
	HUD.openModal("results")
	SoundPlayer.play(r.waves >= 5 and "WaveClear" or "Defeat")
end

-- СОБЫТИЯ ---------------------------------------------------------------------------
local function onState(s)
	State.set("siege", s)
	local active = s.active
	local survival = active and s.mode == "survival"
	waveBar.Visible = survival
	rangePanel.Visible = active and s.mode == "range"
	HUD.setHotbarVisible(not active and not State.launched)
	if not active then
		warnBanner.Visible = false
		return
	end
	if s.phase == "countdown" then
		showBig(tostring(s.n), "Приготовься! Спрячься в своей постройке", Theme.Accent, 0.9)
		SoundPlayer.play("Warning")
		waveTitle.Text = "ПОДГОТОВКА"
		waveSub.Text = Config.Difficulties[s.difficulty].name .. " сложность"
		waveFill.Size = UDim2.fromScale(0, 1)
	elseif s.phase == "wave" then
		local w = Weapons.ByKey[s.headline]
		waveTitle.Text = "ВОЛНА " .. s.wave
		waveSub.Text = (s.newWeapon and "Новое: " or "") .. (w and (w.icon .. " " .. w.name) or "")
		waveEndsAt = os.clock() + s.duration
		waveDuration = s.duration
		local sub = s.newWeapon and ("Новое оружие: " .. w.name) or (w and w.name or nil)
		showBig("ВОЛНА " .. s.wave, sub, s.wave >= 10 and Theme.Bad or Theme.Text, 1.8)
		SoundPlayer.play("WaveStart")
	elseif s.phase == "cleared" then
		showBig("ВОЛНА ПРОЙДЕНА", "+" .. Util.formatNumber(s.reward) .. " золота", Theme.Good, 2.2)
		SoundPlayer.play("WaveClear")
		waveFill.Size = UDim2.fromScale(1, 1)
	elseif s.phase == "range" then
		HUD.toast("Полигон: стреляй по своей постройке. «Восстановить» — вернуть всё как было", "info")
	end
end

function SiegeUI.init()
	buildMenu()
	buildWaveBar()
	buildRange()
	buildResults()
	Net.event("SiegeState").OnClientEvent:Connect(onState)
	Net.event("SiegeResult").OnClientEvent:Connect(showResults)
	Net.event("Warning").OnClientEvent:Connect(function(data)
		if data.plot ~= player:GetAttribute("Plot") then
			return
		end
		if data.kind == "nuke" then
			SiegeUI.warn("☢ ЯДЕРНЫЙ УДАР! СПРЯЧЬСЯ ЗА ТОЛСТЫЕ СТЕНЫ!", data.t)
			SoundPlayer.play("Siren")
		end
	end)
	Net.event("LaserState").OnClientEvent:Connect(function(data)
		if data.phase == "charge" then
			local plotIndex = player:GetAttribute("Plot")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if plotIndex and root and (root.Position - data.p).Magnitude < 160 then
				SiegeUI.warn("☼ ОРБИТАЛЬНЫЙ ЛАЗЕР НАВОДИТСЯ НА ТЕБЯ — БЕГИ ПОД КРЫШУ!", data.t + 1)
				SoundPlayer.play("Alarm")
			end
		end
	end)
	-- полоска времени волны и мигание предупреждения
	game:GetService("RunService").RenderStepped:Connect(function()
		if waveBar.Visible and State.siege and State.siege.phase == "wave" then
			local left = waveEndsAt - os.clock()
			waveFill.Size = UDim2.fromScale(math.clamp(1 - left / waveDuration, 0, 1), 1)
		end
		if warnBanner.Visible then
			local left = warnUntil - os.clock()
			if left <= 0 then
				warnBanner.Visible = false
			else
				warnBanner.BackgroundTransparency = 0.05 + (math.sin(os.clock() * 10) + 1) * 0.2
			end
		end
	end)
end

return SiegeUI
