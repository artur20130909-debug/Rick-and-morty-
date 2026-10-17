-- Админ-панель для тестов: F2 или кнопка «Админ» справа (их видят только админы — атрибут IsAdmin
-- ставит сервер). Вкладки: экономика, игрок, осада, оружие, постройка, мир, инфо.
-- Каждая кнопка — команда серверу (удалённый вызов Admin), ответ показывается уведомлением.
-- Права и аргументы сервер проверяет при каждом вызове (модуль Server/Admin).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Weapons = require(Shared.Weapons)
local Examples = require(Shared.Examples)
local Prefabs = require(Shared.Prefabs)
local Util = require(Shared.Util)
local Net = require(Shared.Net)

local Client = script.Parent.Parent
local State = require(Client.State)
local AdminTools = require(Client.AdminTools)
local Theme = require(script.Parent.Theme)
local Lib = require(script.Parent.Lib)
local HUD = require(script.Parent.HUD)

local new = Lib.new
local AdminUI = {}

local player = Players.LocalPlayer

type Page = { button: TextButton, frame: ScrollingFrame, order: number }

local TABS = {
	{ key = "economy", name = "💰 Экономика" },
	{ key = "player", name = "🧍 Игрок" },
	{ key = "siege", name = "💣 Осада" },
	{ key = "weapons", name = "🚀 Оружие" },
	{ key = "build", name = "🏠 Постройка" },
	{ key = "world", name = "🌍 Мир" },
	{ key = "info", name = "📊 Инфо" },
}

-- Пресеты: сервер принимает только эти значения (списки в Server/Admin)
local GOLD_STEPS = { 1000, 10000, 100000 }
local WALK_SPEEDS = { { 16, "🚶 Обычная" }, { 32, "🏃 ×2" }, { 64, "💨 ×4" }, { 120, "🚀 Ракета" } }
local JUMP_HEIGHTS = { { 7.2, "Обычный" }, { 20, "Высокий" }, { 50, "Супер" }, { 120, "До облаков" } }
local TIMES = {
	{ key = "morning", name = "🌅 Утро", clock = 7 },
	{ key = "day", name = "☀ День", clock = 13 },
	{ key = "sunset", name = "🌇 Закат", clock = 18.2 },
	{ key = "night", name = "🌙 Ночь", clock = 0 },
}
local TARGETS = {
	{ key = "me", name = "🙋 По мне" },
	{ key = "cursor", name = "🖱 Кликом по острову" },
	{ key = "block", name = "🎲 По случайному блоку" },
}
local MAX_WAVE = 30 -- как Siege.MaxAdminWave на сервере

local pages: { [string]: Page } = {}
local tab = "economy"
local refreshers: { () -> () } = {} -- подсветка кнопок: при открытии окна и после команд
local weaponTarget = "me"
local wave = 1
local difficulty = 2
local picking: ((Vector3) -> ())? = nil -- ждём клик по миру (цель выстрела, точка телепорта)
local statsLabel: TextLabel
local clientLabel: TextLabel
local statsToken = 0
local resetConfirm = false

local function refreshAll()
	for _, f in refreshers do
		f()
	end
end

-- КОМАНДЫ ---------------------------------------------------------------------------
-- Отправить команду. onResult — свой обработчик ответа, иначе ответ показывается уведомлением.
local function send(cmd: string, arg: any?, onResult: ((boolean, string?) -> ())?)
	task.spawn(function()
		local ok, success, msg = pcall(function()
			return Net.func("Admin"):InvokeServer(cmd, arg)
		end)
		if not ok then
			HUD.toast("Сервер не ответил", "error")
			return
		end
		local text = if typeof(msg) == "string" and msg ~= "" then msg else nil
		if onResult then
			onResult(success == true, text)
			return
		end
		if text then
			HUD.toast(text, if success == true then "success" else "error")
		end
		refreshAll()
	end)
end

-- ВЫБОР ТОЧКИ В МИРЕ ------------------------------------------------------------------
local function stopPicking()
	if picking then
		picking = nil
		HUD.setHint("")
	end
end

-- Закрыть панель и ждать клика по миру: точка попадания уйдёт в callback
local function startPicking(hint: string, callback: (Vector3) -> ())
	picking = callback
	HUD.closeModal()
	HUD.onTool:Fire(nil) -- снимаем инструмент, чтобы клик не поставил блок
	HUD.setHint(hint .. " • Esc — отмена")
end

local function pickAt(screen: Vector2, viewport: boolean)
	local callback = picking
	if not callback then
		return
	end
	local cam = workspace.CurrentCamera
	local ray = if viewport then cam:ViewportPointToRay(screen.X, screen.Y) else cam:ScreenPointToRay(screen.X, screen.Y)
	local exclude: { Instance } = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
	if not hit then
		HUD.toast("Туда не попасть — кликни по земле или постройке", "warning")
		return
	end
	stopPicking()
	callback(hit.Position)
end

-- ЭЛЕМЕНТЫ ----------------------------------------------------------------------------
local function setActive(b: GuiObject, on: boolean, color: Color3?)
	Lib.setButtonColor(b, if on then color or Theme.Accent2 else Theme.Panel2)
end

-- Блок на вкладке: заголовок, пояснение и сетка кнопок (columns в ряд, высота ячейки cell)
local function section(page: Page, title: string, note: string?, columns: number?, cell: number?): Frame
	page.order += 1
	local box = Lib.panel({
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Panel,
		LayoutOrder = page.order,
		Parent = page.frame,
	})
	local pad = Lib.padding(14, 12)
	pad.Parent = box
	local list = Lib.list(Enum.FillDirection.Vertical, 8)
	list.Parent = box
	Lib.label(title, 18, { FontFace = Theme.FontHeavy, LayoutOrder = 1, Parent = box })
	if note then
		Lib.label(note, 14, {
			TextColor3 = Theme.Sub,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = box,
		})
	end
	local cols = columns or 4
	return new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = box,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.new(1 / cols, -8 * (cols - 1) / cols, 0, cell or 44),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

-- Простая кнопка-команда
local function commandButton(grid: Frame, order: number, text: string, cmd: string, arg: any?, color: Color3?): TextButton
	return Lib.button(text, {
		TextSize = 16,
		TextWrapped = true,
		BackgroundColor3 = color or Theme.Panel2,
		LayoutOrder = order,
		Parent = grid,
	}, function()
		send(cmd, arg)
	end)
end

-- Кнопка с иконкой и подписью в две строки (оружие, постройки, примеры)
local function cardButton(grid: Frame, order: number, icon: string, title: string, sub: string?, onClick: () -> ()): TextButton
	local b = Lib.button("", { LayoutOrder = order, Parent = grid }, onClick)
	Lib.label(icon, 22, {
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 26),
		TextColor3 = Theme.Accent,
		Parent = b,
	})
	Lib.label(title, 14, {
		FontFace = Theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(4, 30),
		Size = UDim2.new(1, -8, 0, 18),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = b,
	})
	if sub then
		Lib.label(sub, 12, {
			TextColor3 = Theme.Sub,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(4, 48),
			Size = UDim2.new(1, -8, 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			Parent = b,
		})
	end
	return b
end

-- Переключатель по атрибуту игрока (бессмертие, полёт): подпись и цвет показывают состояние
local function toggleButton(grid: Frame, order: number, title: string, attribute: string, cmd: string)
	local b = Lib.button("", { TextSize = 16, LayoutOrder = order, Parent = grid }, function()
		send(cmd, player:GetAttribute(attribute) ~= true)
	end)
	local function refresh()
		local on = player:GetAttribute(attribute) == true
		b.Text = title .. (if on then ": ВКЛ" else ": ВЫКЛ")
		setActive(b, on, Theme.Good)
	end
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
	refresh()
end

-- ВКЛАДКИ ---------------------------------------------------------------------------
local function buildEconomy(page: Page)
	local gold = section(page, "Золото", "Золото сохраняется в профиле, как обычное.", 4)
	for i, n in GOLD_STEPS do
		commandButton(gold, i, "+" .. Util.formatNumber(n), "gold", n, Theme.Panel3)
	end
	commandButton(gold, 10, "Обнулить", "goldZero", nil, Theme.Bad)

	local shop = section(page, "Покупки", "Открыть бесплатно всё из магазина или вернуть как у нового игрока.", 3)
	commandButton(shop, 1, "🔓 Все материалы и блоки", "unlockAll")
	commandButton(shop, 2, "🏠 Все дома и бункеры", "unlockPrefabs")
	local reset: TextButton
	reset = Lib.button("♻ Сбросить покупки", { TextSize = 16, BackgroundColor3 = Theme.Panel2, LayoutOrder = 3, Parent = shop }, function()
		if not resetConfirm then
			-- опасная кнопка: второй клик подтверждает
			resetConfirm = true
			reset.Text = "Точно сбросить?"
			Lib.setButtonColor(reset, Theme.Bad)
			task.delay(3, function()
				if resetConfirm then
					resetConfirm = false
					reset.Text = "♻ Сбросить покупки"
					Lib.setButtonColor(reset, Theme.Panel2)
				end
			end)
			return
		end
		resetConfirm = false
		reset.Text = "♻ Сбросить покупки"
		Lib.setButtonColor(reset, Theme.Panel2)
		send("resetPurchases")
	end)
end

local function buildPlayer(page: Page)
	local modes = section(page, "Режимы", "Бессмертие — невидимое силовое поле, остаётся после смерти. "
		.. "Полёт: WASD, Пробел / E — вверх, Ctrl / Q — вниз, Shift — быстрее.", 3)
	toggleButton(modes, 1, "🛡 Бессмертие", "God", "god")
	toggleButton(modes, 2, "🕊 Полёт", "Fly", "fly")
	commandButton(modes, 3, "❤ Вылечить", "heal", nil, Theme.Panel3)

	local speed = section(page, "Скорость бега", nil, 4)
	for i, s in WALK_SPEEDS do
		local b = commandButton(speed, i, s[2] .. " (" .. s[1] .. ")", "speed", s[1])
		table.insert(refreshers, function()
			setActive(b, (player:GetAttribute("AdminWalk") or 16) == s[1])
		end)
	end

	local jump = section(page, "Прыжок", nil, 4)
	for i, j in JUMP_HEIGHTS do
		local b = commandButton(jump, i, j[2] .. " (" .. j[1] .. ")", "jump", j[1])
		table.insert(refreshers, function()
			setActive(b, (player:GetAttribute("AdminJump") or 7.2) == j[1])
		end)
	end

	local tp = section(page, "Телепорт", "«Дно котлована» — самая глубокая выкопанная яма, где можно встать.", 4)
	commandButton(tp, 1, "🏠 Мой участок", "tp", "plot")
	commandButton(tp, 2, "🏛 Лобби", "tp", "lobby")
	commandButton(tp, 3, "⛏ Дно котлована", "tp", "pit")
	Lib.button("🖱 Кликом по миру", { TextSize = 16, LayoutOrder = 4, Parent = tp }, function()
		startPicking("Кликни туда, куда перенестись", function(pos)
			send("tpPoint", pos)
		end)
	end)
end

local function buildSiege(page: Page)
	local start = section(page, "Выживание с любой волны",
		"Волны 1–12 открывают оружие по порядку, 11-я — ядерка, 12-я — лазер, дальше — тяжёлая артиллерия. "
		.. "Рекорды в такой осаде не засчитываются.", 5)
	-- «−5 −1 [Волна N] +1 +5»
	for i, d in { -5, -1, 0, 1, 5 } do
		if d == 0 then
			local waveLabel = Lib.label("", 20, {
				FontFace = Theme.FontHeavy,
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = i,
				Parent = start,
			})
			table.insert(refreshers, function()
				waveLabel.Text = "Волна " .. wave
			end)
		else
			Lib.button(if d > 0 then "+" .. d else "−" .. -d, { TextSize = 18, LayoutOrder = i, Parent = start }, function()
				wave = math.clamp(wave + d, 1, MAX_WAVE)
				refreshAll()
			end)
		end
	end

	local diffs = section(page, "Сложность", nil, #Config.Difficulties)
	for i, d in Config.Difficulties do
		local b = Lib.button(d.name, { TextSize = 16, LayoutOrder = i, Parent = diffs }, function()
			difficulty = i
			refreshAll()
		end)
		table.insert(refreshers, function()
			setActive(b, difficulty == i, d.color)
		end)
	end

	local control = section(page, "Управление осадой", "«Пропустить волну» засчитывает её как пройденную: награда — как за обычную волну.", 4)
	Lib.button("▶ Начать выживание", { TextSize = 16, BackgroundColor3 = Theme.Bad, LayoutOrder = 1, Parent = control }, function()
		send("siegeStart", { wave = wave, difficulty = difficulty }, function(ok, msg)
			if msg then
				HUD.toast(msg, if ok then "success" else "error")
			end
			if ok then
				HUD.closeModal()
			end
		end)
	end)
	commandButton(control, 2, "⏭ Пропустить волну", "skipWave")
	commandButton(control, 3, "■ Закончить осаду", "siegeEnd")
	commandButton(control, 4, "↺ Восстановить постройку", "restore", nil, Theme.Info)
end

local function buildWeapons(page: Page)
	local targets = section(page, "Цель", "Без осады первый выстрел сам включает полигон. "
		.. "«Кликом» — панель закроется, следующий клик по своему острову выберет точку.", 3)
	for i, t in TARGETS do
		local b = Lib.button(t.name, { TextSize = 16, LayoutOrder = i, Parent = targets }, function()
			weaponTarget = t.key
			refreshAll()
		end)
		table.insert(refreshers, function()
			setActive(b, weaponTarget == t.key)
		end)
	end

	-- выстрел удался — окно закрываем, чтобы было видно, что прилетело (F2 — открыть снова)
	local function fired(ok: boolean, msg: string?)
		if msg then
			HUD.toast(msg, if ok then "success" else "error")
		end
		if ok and State.modal == "admin" then
			HUD.closeModal()
		end
	end
	local grid = section(page, "Оружие — без перезарядки", "После выстрела окно закроется: F2 — открыть снова.", 4, 70)
	for i, w in Weapons.List do
		cardButton(grid, i, w.icon, w.name, "волна " .. w.wave, function()
			if weaponTarget == "cursor" then
				startPicking("🎯 Кликни по своему острову — туда прилетит «" .. w.name .. "»", function(pos)
					send("fire", { key = w.key, target = "aim", aim = pos }, fired)
				end)
			else
				send("fire", { key = w.key, target = weaponTarget }, fired)
			end
		end)
	end

	local range = section(page, "Полигон", nil, 2)
	commandButton(range, 1, "↺ Восстановить постройку", "restore", nil, Theme.Info)
	commandButton(range, 2, "✕ Выключить полигон", "siegeEnd", nil, Theme.Bad)
end

local function buildBuild(page: Page)
	local prefabs = section(page, "Готовые постройки — бесплатно",
		"Дом заменяет блоки на своём месте, бункер — всё под землёй. Отменить — Ctrl+Z.", 5, 70)
	for i, p in Prefabs do
		local kind = if p.kind == "bunker" then "Бункер" else "Дом"
		cardButton(prefabs, i, p.icon, p.name, kind .. " • ур. " .. p.tier, function()
			send("prefab", p.key)
		end)
	end

	local examples = section(page, "Примеры построек", nil, 4, 70)
	for i, ex in Examples do
		cardButton(examples, i, "📐", ex.name, nil, function()
			send("example", i)
		end)
	end

	local plot = section(page, "Участок", "Всё можно отменить: Ctrl+Z или кнопка «Отменить».", 4)
	commandButton(plot, 1, "🧹 Очистить участок", "clearPlot")
	commandButton(plot, 2, "⛏ Выкопать всё", "digAll")
	commandButton(plot, 3, "⛰ Засыпать всё", "fillAll")
	Lib.button("↶ Отменить", { TextSize = 16, BackgroundColor3 = Theme.Panel3, LayoutOrder = 4, Parent = plot }, function()
		HUD.onUndo:Fire()
	end)
end

local function buildWorld(page: Page)
	local times = section(page, "Время суток", "Меняется для всех игроков на сервере.", 4)
	for i, t in TIMES do
		local b = commandButton(times, i, t.name, "time", t.key)
		table.insert(refreshers, function()
			local diff = math.abs(Lighting.ClockTime - t.clock)
			setActive(b, math.min(diff, 24 - diff) < 0.3)
		end)
	end
end

local function buildInfo(page: Page)
	page.order += 1
	local box = Lib.panel({
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Panel,
		LayoutOrder = page.order,
		Parent = page.frame,
	})
	local pad = Lib.padding(16, 14)
	pad.Parent = box
	local list = Lib.list(Enum.FillDirection.Vertical, 10)
	list.Parent = box
	Lib.label("Сервер и участок", 18, { FontFace = Theme.FontHeavy, LayoutOrder = 1, Parent = box })
	statsLabel = Lib.label("…", 17, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LineHeight = 1.25,
		LayoutOrder = 2,
		Parent = box,
	})
	Lib.label("Этот компьютер", 18, { FontFace = Theme.FontHeavy, LayoutOrder = 3, Parent = box })
	clientLabel = Lib.label("…", 17, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LineHeight = 1.25,
		LayoutOrder = 4,
		Parent = box,
	})
	Lib.label("Обновляется каждую секунду, пока открыта эта вкладка.", 14, { TextColor3 = Theme.Sub, LayoutOrder = 5, Parent = box })
end

-- Статистика: раз в секунду, пока открыта вкладка «Инфо»
local function stopStats()
	statsToken += 1
end

local function startStats()
	statsToken += 1
	local token = statsToken
	task.spawn(function()
		local frames = 0
		local conn = RunService.RenderStepped:Connect(function()
			frames += 1
		end)
		local last = os.clock()
		while token == statsToken do
			send("stats", nil, function(ok, msg)
				if token == statsToken and msg then
					statsLabel.Text = msg
					statsLabel.TextColor3 = if ok then Theme.Text else Theme.Bad
				end
			end)
			task.wait(1)
			local now = os.clock()
			local fps = frames / math.max(now - last, 1e-3)
			frames, last = 0, now
			clientLabel.Text = string.format("Кадров в секунду: %d\nПинг: %d мс\nПолёт: %s",
				math.floor(fps + 0.5), math.floor(player:GetNetworkPing() * 1000 + 0.5), if AdminTools.isFlying() then "да" else "нет")
		end
		conn:Disconnect()
	end)
end

local function selectTab(key: string)
	tab = key
	for k, p in pages do
		p.frame.Visible = k == key
		setActive(p.button, k == key)
	end
	if key == "info" and State.modal == "admin" then
		startStats()
	else
		stopStats()
	end
end

-- ОКНО ------------------------------------------------------------------------------
local BUILDERS: { [string]: (Page) -> () } = {
	economy = buildEconomy,
	player = buildPlayer,
	siege = buildSiege,
	weapons = buildWeapons,
	build = buildBuild,
	world = buildWorld,
	info = buildInfo,
}

local function isAdmin(): boolean
	return player:GetAttribute("IsAdmin") == true
end

function AdminUI.init()
	AdminTools.init()
	local shade, body = Lib.modal(HUD.gui(), "🛡 АДМИН-ПАНЕЛЬ", Vector2.new(980, 660), function()
		HUD.closeModal()
	end)
	local tabRow = new("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Parent = body }, {
		Lib.list(Enum.FillDirection.Horizontal, 8),
	})
	local content = new("Frame", {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
		BackgroundTransparency = 1,
		Parent = body,
	})
	for i, t in TABS do
		local button = Lib.button(t.name, {
			Size = UDim2.new(1 / #TABS, -8 * (#TABS - 1) / #TABS, 1, 0),
			TextSize = 15,
			LayoutOrder = i,
			Parent = tabRow,
		}, function()
			if tab ~= t.key then
				selectTab(t.key)
			end
		end)
		local frame = new("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Sub,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			Parent = content,
		}, { Lib.list(Enum.FillDirection.Vertical, 12) })
		local page: Page = { button = button, frame = frame, order = 0 }
		pages[t.key] = page
		BUILDERS[t.key](page)
	end
	selectTab(tab)

	HUD.registerModal("admin", shade, function()
		stopPicking()
		refreshAll()
		selectTab(tab)
	end, function()
		stopStats()
	end)

	-- права пропали — окно закрываем, полёт выключит AdminTools
	local function onAdminChanged()
		State.set("isAdmin", isAdmin())
		if not isAdmin() then
			stopPicking()
			if State.modal == "admin" then
				HUD.closeModal()
			end
		end
	end
	player:GetAttributeChangedSignal("IsAdmin"):Connect(onAdminChanged)
	onAdminChanged()
	for _, attr in { "AdminWalk", "AdminJump" } do
		player:GetAttributeChangedSignal(attr):Connect(refreshAll)
	end
	Lighting:GetPropertyChangedSignal("TimeOfDay"):Connect(function()
		if State.modal == "admin" then
			refreshAll()
		end
	end)
	-- взял инструмент строительства — выбор точки отменяется
	State.changed:Connect(function(key, value)
		if key == "tool" and value ~= nil then
			stopPicking()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape and picking then
			stopPicking()
			return
		end
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F2 and isAdmin() then
			HUD.openModal("admin")
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and picking then
			pickAt(UserInputService:GetMouseLocation(), true)
		end
	end)
	-- на телефоне точку выбирают касанием
	UserInputService.TouchTap:Connect(function(positions, processed)
		local p = positions[1]
		if picking and p and not processed then
			pickAt(Vector2.new(p.X, p.Y), false)
		end
	end)
end

return AdminUI
