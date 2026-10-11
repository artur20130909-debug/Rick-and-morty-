-- Интерфейс игрока: Страх и доход, таймер дня/ночи, события, сообщения, объявления на весь сервер,
-- лавка (сети, приманки, клетки, Robux), панель приманок, «несёшь монстра», скример, тревога «крадут»,
-- админ-панель. Всё рисуется кодом; размеры подстраиваются под экран телефона.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)

local UI = {}
local player = Players.LocalPlayer
local state = RS:WaitForChild("State")
local Action = Net.event("Action")

local C = {
	bg = Color3.fromRGB(20, 16, 30), bg2 = Color3.fromRGB(36, 28, 56), accent = Color3.fromRGB(140, 90, 255),
	gold = Color3.fromRGB(255, 214, 74), text = Color3.new(1, 1, 1), dim = Color3.fromRGB(185, 175, 205),
	red = Color3.fromRGB(255, 80, 90), green = Color3.fromRGB(110, 255, 130), night = Color3.fromRGB(110, 140, 255),
}
local LEFT = Enum.TextXAlignment.Left
local RIGHT = Enum.TextXAlignment.Right

local gui, scareGui
local refs = {}
local scales = {}
local shopTab = "nets"
local shopData = nil

---------------------------------------------------------------- помощники
local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function corner(o, r) return make("UICorner", { CornerRadius = UDim.new(0, r or 12) }, o) end

local function stroke(o, color, th, tr)
	return make("UIStroke", { Color = color or C.accent, Thickness = th or 2, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end

local function label(parent, props)
	local t = make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextColor3 = C.text, TextScaled = true, Text = "", RichText = true }, parent)
	for k, v in pairs(props or {}) do t[k] = v end
	return t
end

local function panel(parent, props)
	local f = make("Frame", { BackgroundColor3 = C.bg, BackgroundTransparency = 0.12, BorderSizePixel = 0 }, parent)
	for k, v in pairs(props or {}) do f[k] = v end
	corner(f, 14)
	stroke(f, C.accent, 2, 0.2)
	return f
end

function UI.sound(key, volume)
	local id = Config.Sounds[key]
	if not id or id == "" then return end
	if tonumber(id) then id = "rbxassetid://" .. id end
	local s = make("Sound", { SoundId = id, Volume = volume or 0.6 }, SoundService)
	s:Play()
	task.delay(8, function() s:Destroy() end)
end

local function button(parent, text, color, props, onClick)
	local b = make("TextButton", { BackgroundColor3 = color or C.accent, Font = Enum.Font.GothamBlack, TextColor3 = C.text,
		TextScaled = true, Text = text, AutoButtonColor = true, BorderSizePixel = 0, RichText = true }, parent)
	corner(b, 10)
	stroke(b, Color3.new(0, 0, 0), 2, 0.55)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, b)
	for k, v in pairs(props or {}) do b[k] = v end
	if onClick then
		b.Activated:Connect(function()
			UI.sound("Click", 0.4)
			onClick()
		end)
	end
	return b
end

-- масштаб под размер экрана (телефоны меньше)
local function addScale(o)
	local s = make("UIScale", { Scale = 1 }, o)
	table.insert(scales, s)
	return s
end

local function updateScales()
	local cam = workspace.CurrentCamera
	local h = cam and cam.ViewportSize.Y or 720
	local w = cam and cam.ViewportSize.X or 1280
	local k = math.clamp(math.min(h / 760, w / 1100), 0.55, 1.2)
	for _, s in ipairs(scales) do s.Scale = k end
end

local function myBase()
	local idx = player:GetAttribute("BaseIndex")
	local bases = workspace:FindFirstChild("Bases")
	return idx and bases and bases:FindFirstChild("Base_" .. idx) or nil
end

local function now() return workspace:GetServerTimeNow() end

---------------------------------------------------------------- сообщения
function UI.toast(text, color)
	local list = refs.toasts
	if not list then return end
	local items = {}
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then table.insert(items, c) end
	end
	if #items >= 5 then items[1]:Destroy() end
	local f = make("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.bg, BackgroundTransparency = 0.25, BorderSizePixel = 0, LayoutOrder = math.floor(os.clock() * 100) }, list)
	corner(f, 8)
	local t = label(f, { Size = UDim2.new(1, -16, 1, -6), Position = UDim2.new(0, 8, 0, 3), Text = text, TextColor3 = color or C.text, Font = Enum.Font.GothamBold })
	task.delay(3.6, function()
		if not f.Parent then return end
		TweenService:Create(f, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.45)
		f:Destroy()
	end)
end

local announceQueue = {}
local announcing = false
local function runAnnounce()
	if announcing then return end
	announcing = true
	task.spawn(function()
		while #announceQueue > 0 do
			local a = table.remove(announceQueue, 1)
			local l = refs.announce
			l.Text = a.text
			l.TextColor3 = a.color or C.gold
			l.TextTransparency = 1
			l.TextStrokeTransparency = 1
			l.Visible = true
			TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 0, TextStrokeTransparency = 0 }):Play()
			task.wait(#announceQueue > 0 and 3 or 4.5)
			TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.wait(0.45)
			l.Visible = false
		end
		announcing = false
	end)
end

function UI.announce(text, color)
	table.insert(announceQueue, { text = text, color = color })
	if #announceQueue > 4 then table.remove(announceQueue, 1) end
	UI.sound("Whoosh", 0.5)
	runAnnounce()
end

-- летящая цифра у денег
local function cashFloat(amount)
	local m = refs.money
	if not m then return end
	local t = label(m, { Size = UDim2.new(0, 160, 0, 30), Position = UDim2.new(1, 10, 0, 10),
		Text = (amount >= 0 and "+" or "") .. Util.num(amount) .. " 💀", TextColor3 = amount >= 0 and C.green or C.red, TextXAlignment = LEFT, TextStrokeTransparency = 0.3 })
	TweenService:Create(t, TweenInfo.new(1.2), { Position = UDim2.new(1, 10, 0, -20), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.3, function() t:Destroy() end)
end

---------------------------------------------------------------- скример и тревога
local function jumpscare(key, rarityKey)
	local f = refs.scare
	local def = Config.MonsterIndex[key]
	local r = Config.RarityIndex[rarityKey or "common"] or Config.Rarities[1]
	refs.scareName.Text = def and string.upper(def.name) or "БУ!"
	refs.scareName.TextColor3 = r.color
	f.BackgroundTransparency = 0.05
	f.Visible = true
	refs.scareScale.Scale = 0.5
	TweenService:Create(refs.scareScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1.15 }):Play()
	UI.sound("Jumpscare", 1)
	UI.sound("Scream", 0.9)
	-- тряска камеры
	task.spawn(function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		for _ = 1, 14 do
			if hum then hum.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 1.6 end
			task.wait(0.03)
		end
		if hum then hum.CameraOffset = Vector3.new() end
	end)
	task.delay(0.55, function()
		TweenService:Create(f, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(refs.scareScale, TweenInfo.new(0.5), { Scale = 0.01 }):Play()
		task.wait(0.5)
		f.Visible = false
	end)
	UI.toast("😱 Тебя напугал монстр! Ты уронил добычу", C.red)
end

local function stolenAlert(name, thief)
	local l = refs.alert
	l.Text = "⚠ ВОР! " .. thief .. " утащил " .. name .. "!\nДогони и жми F — «Отобрать»"
	l.Visible = true
	for i = 1, 3 do
		task.delay((i - 1) * 0.35, function() UI.sound("Alarm", 0.8) end)
	end
	task.spawn(function()
		for i = 1, 10 do
			l.TextColor3 = (i % 2 == 0) and C.red or Color3.new(1, 1, 1)
			task.wait(0.3)
		end
		l.Visible = false
	end)
end

local function offlinePopup(earned, away)
	local f = panel(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 420, 0, 200), ZIndex = 20 })
	addScale(f)
	updateScales()
	local mins = math.floor(away / 60)
	local txt = mins >= 60 and (math.floor(mins / 60) .. " ч " .. (mins % 60) .. " мин") or (mins .. " мин")
	label(f, { Size = UDim2.new(1, -30, 0, 36), Position = UDim2.new(0, 15, 0, 14), Text = "🌙 Пока тебя не было (" .. txt .. ")", ZIndex = 21 })
	label(f, { Size = UDim2.new(1, -30, 0, 50), Position = UDim2.new(0, 15, 0, 56), Text = "монстры напугали людей на <font color=\"#ffd64a\">+" .. Util.num(earned) .. " 💀</font>", Font = Enum.Font.GothamBold, ZIndex = 21 })
	button(f, "Забрать!", C.accent, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(0, 200, 0, 50), ZIndex = 21 }, function()
		f:Destroy()
	end)
	UI.sound("Cash", 0.7)
end

---------------------------------------------------------------- лавка
local function clearContent()
	for _, c in ipairs(refs.shopList:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

local function row(order, title, desc, btnText, btnColor, onClick)
	local f = make("Frame", { Size = UDim2.new(1, -10, 0, 70), BackgroundColor3 = C.bg2, BorderSizePixel = 0, LayoutOrder = order }, refs.shopList)
	corner(f, 12)
	label(f, { Size = UDim2.new(1, -190, 0, 32), Position = UDim2.new(0, 12, 0, 6), Text = title, TextXAlignment = LEFT })
	label(f, { Size = UDim2.new(1, -190, 0, 22), Position = UDim2.new(0, 12, 0, 40), Text = desc or "", TextXAlignment = LEFT, TextColor3 = C.dim, Font = Enum.Font.GothamBold })
	local b = button(f, btnText, btnColor or C.accent, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 165, 0, 48) }, onClick)
	if not onClick then b.AutoButtonColor = false end
	return f, b
end

local function buy(what, key)
	Action:FireServer("buy", what, key)
	task.delay(0.35, function() UI.refreshShop(true) end)
end

local function promptProduct(kind, def)
	if not def.id or def.id == 0 then
		UI.toast("Товар ещё не настроен: впиши его ID в Config (см. README)", C.red)
		return
	end
	if kind == "product" then
		MarketplaceService:PromptProductPurchase(player, def.id)
	else
		MarketplaceService:PromptGamePassPurchase(player, def.id)
	end
end

local function rarityListUpTo(net)
	local names = {}
	for _, r in ipairs(Config.Rarities) do
		if r.net == net then table.insert(names, r.name) end
	end
	return table.concat(names, ", ")
end

local function renderShop()
	if not refs.shop.Visible then return end
	clearContent()
	local fear = player:GetAttribute("Fear") or 0
	local d = shopData or {}
	for name, b in pairs(refs.tabs) do
		b.BackgroundColor3 = (name == shopTab) and C.accent or C.bg2
	end
	if shopTab == "nets" then
		local net = player:GetAttribute("Net") or 1
		for i, n in ipairs(Config.Nets) do
			local desc = "Открывает: " .. rarityListUpTo(n.level)
			if n.level <= net then
				row(i, "🕸 " .. n.name, desc, "✓ Есть", Color3.fromRGB(60, 120, 70))
			elseif n.level == net + 1 then
				local can = fear >= n.price
				row(i, "🕸 " .. n.name, desc, Util.num(n.price) .. " 💀", can and C.accent or Color3.fromRGB(90, 70, 110), function() buy("net") end)
			else
				row(i, "🔒 " .. n.name, desc, Util.num(n.price) .. " 💀", Color3.fromRGB(60, 55, 70))
			end
		end
	elseif shopTab == "baits" then
		for i, b in ipairs(Config.Baits) do
			local left = d.left and d.left[b.key] or 0
			local have = player:GetAttribute("Bait_" .. b.key) or 0
			local extra = ""
			if b.gold then extra = ", золотые ×" .. b.gold end
			if b.blood then extra = ", кровавые мутации" end
			local desc = "Удача ×" .. b.luck .. extra .. " · в наличии: " .. left .. " · у тебя: " .. have
			if left > 0 then
				row(i, b.icon .. " " .. b.name, desc, Util.num(b.price) .. " 💀", fear >= b.price and C.accent or Color3.fromRGB(90, 70, 110), function() buy("bait", b.key) end)
			else
				row(i, b.icon .. " " .. b.name, desc, "Нет в наличии", Color3.fromRGB(60, 55, 70))
			end
		end
	elseif shopTab == "cages" then
		local cages = player:GetAttribute("Cages") or Config.StartCages
		local max = player:GetAttribute("MaxCages") or Config.MaxCages
		local nextPrice = Config.CagePrices[cages + 1]
		if cages < max and nextPrice then
			row(1, "🧺 Новая клетка", "Сейчас клеток: " .. cages .. " из " .. max, Util.num(nextPrice) .. " 💀", fear >= nextPrice and C.accent or Color3.fromRGB(90, 70, 110), function() buy("cage") end)
		else
			row(1, "🧺 Клетки", "Сейчас клеток: " .. cages .. " из " .. max, "Максимум", Color3.fromRGB(60, 55, 70))
		end
		row(2, "💡 Совет", "Клетку можно купить и прямо на базе (замок на пустой клетке)", "OK", C.bg)
	elseif shopTab == "robux" then
		local l = Config.Products.ServerLuck
		row(1, "🍀 " .. l.name, l.minutes .. " минут удача ×2 у всех игроков", "R$ " .. l.robux, Color3.fromRGB(40, 160, 80), function() promptProduct("product", l) end)
		local i = 2
		for _, key in ipairs({ "DoubleFear", "ExtraCages" }) do
			local p = Config.Passes[key]
			if player:GetAttribute("Pass" .. key) then
				row(i, "⭐ " .. p.name, "Уже куплено", "✓ Есть", Color3.fromRGB(60, 120, 70))
			else
				row(i, "⭐ " .. p.name, "Геймпасс навсегда", "R$ " .. p.robux, Color3.fromRGB(40, 160, 80), function() promptProduct("pass", p) end)
			end
			i = i + 1
		end
	end
end

function UI.refreshShop(fetch)
	if fetch then
		local ok, res = pcall(function() return Net.func("GetShop"):InvokeServer() end)
		if ok and type(res) == "table" then shopData = res end
	end
	renderShop()
end

function UI.openShop(tab)
	if tab then shopTab = tab end
	refs.shop.Visible = true
	UI.refreshShop(true)
end

local function buildShop()
	local shop = panel(gui, { Name = "Shop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0, 600, 0, 440), Visible = false, ZIndex = 5 })
	addScale(shop)
	refs.shop = shop
	label(shop, { Size = UDim2.new(0, 330, 0, 40), Position = UDim2.new(0, 16, 0, 10), Text = "🛒 ЛАВКА ЛОВЦА", TextXAlignment = LEFT, TextColor3 = C.gold })
	refs.restock = label(shop, { Size = UDim2.new(0, 190, 0, 22), Position = UDim2.new(1, -250, 0, 20), Text = "", TextXAlignment = RIGHT, TextColor3 = C.dim, Font = Enum.Font.GothamBold })
	button(shop, "✕", C.red, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.new(0, 44, 0, 44) }, function()
		shop.Visible = false
	end)
	refs.tabs = {}
	local tabs = { { "nets", "🕸 Сети" }, { "baits", "🍖 Приманки" }, { "cages", "🧺 Клетки" }, { "robux", "💎 Robux" } }
	for i, t in ipairs(tabs) do
		refs.tabs[t[1]] = button(shop, t[2], C.bg2, { Position = UDim2.new((i - 1) / 4, 12, 0, 62), Size = UDim2.new(0.25, -16, 0, 42) }, function()
			shopTab = t[1]
			renderShop()
		end)
	end
	local list = make("ScrollingFrame", { Position = UDim2.new(0, 12, 0, 114), Size = UDim2.new(1, -24, 1, -126), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, shop)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	refs.shopList = list
	-- перерисовка при смене денег/предметов
	for _, a in ipairs({ "Fear", "Net", "Cages", "MaxCages", "PassDoubleFear", "PassExtraCages" }) do
		player:GetAttributeChangedSignal(a):Connect(function()
			if shop.Visible and a ~= "Fear" then renderShop() end
		end)
	end
end

---------------------------------------------------------------- админ
local function buildAdmin()
	local f = panel(gui, { Name = "Admin", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -180, 0.5, 0), Size = UDim2.new(0, 220, 0, 470), Visible = false, ZIndex = 6 })
	addScale(f)
	label(f, { Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 0, 6), Text = "⚙ АДМИН", TextColor3 = C.gold })
	local holder = make("Frame", { Position = UDim2.new(0, 10, 0, 40), Size = UDim2.new(1, -20, 1, -50), BackgroundTransparency = 1 }, f)
	make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
	local cmds = {
		{ "☀ День", "day" }, { "🌙 Ночь", "night" }, { "🩸 Кровавая луна", "bloodmoon" }, { "👾 Глитч-ночь", "glitch" },
		{ "🌫 Туман", "fog" }, { "Спавн: Легендарный", "spawn legendary" }, { "Спавн: Мифический", "spawn mythic" },
		{ "Спавн: Секретный", "spawn secret" }, { "+10K Страха", "fear 10000" }, { "🍀 Удача ×2", "luck" }, { "🛒 Обновить лавку", "restock" },
	}
	for i, c in ipairs(cmds) do
		button(holder, c[1], C.bg2, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = i }, function()
			Action:FireServer("admin", c[2])
		end)
	end
	refs.admin = f
end

---------------------------------------------------------------- основной HUD
local function buildHud()
	gui = make("ScreenGui", { Name = "HUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

	-- деньги
	local money = panel(gui, { Name = "Money", Position = UDim2.new(0, 12, 0, 10), Size = UDim2.new(0, 270, 0, 128) })
	addScale(money)
	refs.money = money
	refs.fear = label(money, { Position = UDim2.new(0, 14, 0, 6), Size = UDim2.new(1, -28, 0, 42), Text = "💀 0", TextXAlignment = LEFT, TextColor3 = C.gold })
	refs.income = label(money, { Position = UDim2.new(0, 14, 0, 48), Size = UDim2.new(1, -28, 0, 22), Text = "", TextXAlignment = LEFT, TextColor3 = C.green, Font = Enum.Font.GothamBold })
	refs.stats = label(money, { Position = UDim2.new(0, 14, 0, 72), Size = UDim2.new(1, -28, 0, 20), Text = "", TextXAlignment = LEFT, TextColor3 = C.dim, Font = Enum.Font.GothamBold })
	refs.lock = label(money, { Position = UDim2.new(0, 14, 0, 96), Size = UDim2.new(1, -28, 0, 20), Text = "", TextXAlignment = LEFT, TextColor3 = C.dim, Font = Enum.Font.GothamBold })

	-- верх: фаза, событие, удача, сообщения
	local top = make("Frame", { Name = "Top", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(0, 480, 0, 300), BackgroundTransparency = 1 }, gui)
	addScale(top)
	local pill = panel(top, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 290, 0, 52) })
	pill:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 26)
	refs.pill = pill
	refs.phase = label(pill, { Size = UDim2.new(1, -24, 1, -12), Position = UDim2.new(0, 12, 0, 6), Text = "☀ ДЕНЬ" })
	refs.event = label(top, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.new(1, 0, 0, 24), Text = "", Font = Enum.Font.GothamBold, TextStrokeTransparency = 0.3 })
	refs.luck = label(top, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84), Size = UDim2.new(1, 0, 0, 22), Text = "", TextColor3 = C.green, Font = Enum.Font.GothamBold, TextStrokeTransparency = 0.3 })
	local toasts = make("Frame", { Position = UDim2.new(0, 40, 0, 112), Size = UDim2.new(1, -80, 0, 180), BackgroundTransparency = 1 }, top)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, toasts)
	refs.toasts = toasts

	-- объявление на весь сервер
	local ann = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.new(0, 900, 0, 64), BackgroundTransparency = 1 }, gui)
	addScale(ann)
	refs.announce = label(ann, { Size = UDim2.fromScale(1, 1), Visible = false, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.new(0, 0, 0) })

	-- тревога «крадут»
	local al = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.new(0, 760, 0, 90), BackgroundTransparency = 1 }, gui)
	addScale(al)
	refs.alert = label(al, { Size = UDim2.fromScale(1, 1), Visible = false, TextColor3 = C.red, TextStrokeTransparency = 0 })

	-- кнопки справа
	local right = make("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.45, 0), Size = UDim2.new(0, 160, 0, 200), BackgroundTransparency = 1 }, gui)
	addScale(right)
	make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }, right)
	button(right, "🛒 Лавка", C.accent, { Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 1 }, function()
		if refs.shop.Visible then refs.shop.Visible = false else UI.openShop() end
	end)
	button(right, "🍀 Удача ×2", Color3.fromRGB(40, 160, 80), { Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 2 }, function()
		promptProduct("product", Config.Products.ServerLuck)
	end)
	refs.adminBtn = button(right, "⚙ Админ", C.bg2, { Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 3, Visible = false }, function()
		refs.admin.Visible = not refs.admin.Visible
	end)

	-- низ: «несёшь» и приманки
	local bottom = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(0, 700, 0, 140), BackgroundTransparency = 1 }, gui)
	addScale(bottom)
	local carry = panel(bottom, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 620, 0, 46), Visible = false })
	refs.carry = carry
	refs.carryText = label(carry, { Size = UDim2.new(1, -20, 1, -10), Position = UDim2.new(0, 10, 0, 5), Text = "" })
	local bar = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 74), BackgroundTransparency = 1 }, bottom)
	make("UIListLayout", { Padding = UDim.new(0, 10), FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, bar)
	refs.baits = {}
	for i, b in ipairs(Config.Baits) do
		local btn = button(bar, b.icon, C.bg2, { Size = UDim2.new(0, 130, 1, 0), LayoutOrder = i, Visible = false }, function()
			Action:FireServer("useBait", b.key)
		end)
		refs.baits[b.key] = btn
	end
	refs.hint = label(bottom, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -80), Size = UDim2.new(1, 0, 0, 26), Text = "", Font = Enum.Font.GothamBold, TextColor3 = C.gold, TextStrokeTransparency = 0.3 })

	buildShop()
	buildAdmin()

	-- скример (поверх всего, включая верхнюю панель Roblox)
	scareGui = make("ScreenGui", { Name = "Scare", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20 }, player.PlayerGui)
	local sf = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(40, 0, 0), BackgroundTransparency = 1, Visible = false, BorderSizePixel = 0 }, scareGui)
	refs.scare = sf
	local face = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromScale(0.7, 0.7), BackgroundTransparency = 1 }, sf)
	make("UIAspectRatioConstraint", { AspectRatio = 1.3 }, face)
	refs.scareScale = make("UIScale", { Scale = 1 }, face)
	for _, x in ipairs({ 0.3, 0.7 }) do
		local eye = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.35), Size = UDim2.fromScale(0.22, 0.29), BackgroundColor3 = Color3.fromRGB(255, 250, 220), BorderSizePixel = 0 }, face)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, eye)
		local pupil = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromScale(0.35, 0.35), BackgroundColor3 = Color3.fromRGB(200, 0, 0), BorderSizePixel = 0 }, eye)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, pupil)
	end
	label(face, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromScale(0.75, 0.22), Text = "▼▼▼▼▼▼▼", TextColor3 = Color3.fromRGB(245, 245, 235) })
	refs.scareName = label(face, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.9), Size = UDim2.fromScale(1, 0.12), Text = "", TextStrokeTransparency = 0 })

	updateScales()
	local cam = workspace.CurrentCamera
	if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScales) end
end

---------------------------------------------------------------- обновление каждые 0.2 с
local function refresh()
	local t = now()
	local fear = player:GetAttribute("Fear") or 0
	refs.fear.Text = "💀 " .. Util.num(fear)
	local inc = player:GetAttribute("Income") or 0
	refs.income.Text = "+" .. Util.num(inc) .. " 💀/с" .. (player:GetAttribute("PassDoubleFear") and "  (×2)" or "")
	local base = myBase()
	local used = 0
	if base then
		for _, sm in ipairs(base.Slots:GetChildren()) do
			if sm:FindFirstChild("Monster") then used = used + 1 end
		end
	end
	refs.stats.Text = "🕸 Сеть " .. (player:GetAttribute("Net") or 1) .. "   🧺 " .. used .. "/" .. (player:GetAttribute("Cages") or 0)
	if base and base:GetAttribute("Locked") then
		refs.lock.Text = "🔒 База заперта · " .. Util.time((base:GetAttribute("LockEnds") or 0) - t)
		refs.lock.TextColor3 = C.green
	else
		refs.lock.Text = "🔓 Открыта — запри у входа"
		refs.lock.TextColor3 = C.dim
	end

	-- фаза
	local phase = state:GetAttribute("Phase")
	local left = (state:GetAttribute("PhaseEnds") or 0) - t
	local ev = Config.EventIndex[state:GetAttribute("Event") or ""]
	local pillStroke = refs.pill:FindFirstChildOfClass("UIStroke")
	if phase == "night" then
		refs.phase.Text = "🌙 НОЧЬ " .. Util.time(left)
		pillStroke.Color = ev and ev.color or C.night
		if ev then
			refs.event.Text = ev.name .. " · " .. ev.text
			refs.event.TextColor3 = ev.color
		else
			refs.event.Text = "Редкие монстры вышли на охоту"
			refs.event.TextColor3 = C.night
		end
	else
		refs.phase.Text = "☀ ДЕНЬ " .. Util.time(left)
		pillStroke.Color = C.gold
		refs.event.Text = "Днём только обычные, необычные и редкие"
		refs.event.TextColor3 = C.dim
	end
	local luckEnds = state:GetAttribute("LuckEnds") or 0
	if (state:GetAttribute("ServerLuck") or 1) > 1 and luckEnds > t then
		refs.luck.Text = "🍀 Удача сервера ×" .. state:GetAttribute("ServerLuck") .. " · " .. Util.time(luckEnds - t)
	else
		refs.luck.Text = ""
	end

	-- несёшь монстра
	local carrying = player:GetAttribute("Carrying") or ""
	refs.carry.Visible = carrying ~= ""
	if carrying ~= "" then
		local r = Config.RarityIndex[player:GetAttribute("CarryRarity") or ""] or Config.Rarities[1]
		refs.carryText.Text = "🎒 " .. carrying .. " — беги на свою базу 🏠"
		refs.carryText.TextColor3 = r.color
	end

	-- приманки
	for _, b in ipairs(Config.Baits) do
		local n = player:GetAttribute("Bait_" .. b.key) or 0
		local btn = refs.baits[b.key]
		btn.Visible = n > 0
		btn.Text = b.icon .. " ×" .. n
	end

	-- подсказка новичку
	local caught = player:GetAttribute("Caught") or 0
	if carrying ~= "" then
		refs.hint.Text = ""
	elseif caught == 0 then
		refs.hint.Text = "Подойди к монстру и держи E, чтобы поймать"
	elseif caught < 3 and (player:GetAttribute("Net") or 1) < 2 then
		refs.hint.Text = "Копи Страх и купи сеть получше в Лавке у костра 🔥"
	else
		refs.hint.Text = ""
	end

	if refs.shop.Visible then
		local ra = state:GetAttribute("RestockAt") or 0
		refs.restock.Text = "Обновление: " .. Util.time(ra - t)
	end
	refs.adminBtn.Visible = player:GetAttribute("IsAdmin") == true
end

---------------------------------------------------------------- запуск
function UI.init()
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
	buildHud()
	Net.event("Toast").OnClientEvent:Connect(function(text, color) UI.toast(text, color) end)
	Net.event("Announce").OnClientEvent:Connect(function(text, color) UI.announce(text, color) end)
	Net.event("Fx").OnClientEvent:Connect(function(kind, a, b)
		if kind == "openShop" then UI.openShop()
		elseif kind == "scare" then jumpscare(a, b)
		elseif kind == "stolen" then stolenAlert(a, b)
		elseif kind == "tackled" then
			UI.toast("😤 " .. tostring(b) .. " отобрал у тебя " .. tostring(a) .. "!", C.red)
			UI.sound("Alarm", 0.6)
		elseif kind == "caught" then
			local r = Config.RarityIndex[b or ""] or Config.Rarities[1]
			UI.toast("Поймал: " .. tostring(a) .. "! Неси на базу", r.color)
			UI.sound("Catch", 0.7)
		elseif kind == "delivered" then
			local r = Config.RarityIndex[b or ""] or Config.Rarities[1]
			UI.toast("🧺 " .. tostring(a) .. " теперь в твоей клетке!", r.color)
			UI.sound("Cash", 0.7)
		elseif kind == "cash" then
			cashFloat(tonumber(a) or 0)
			if (tonumber(a) or 0) > 0 then UI.sound("Cash", 0.5) end
		elseif kind == "offline" then offlinePopup(tonumber(a) or 0, tonumber(b) or 0)
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(refresh)
			if not ok then warn("[CN] UI: " .. tostring(err)) end
			task.wait(0.2)
		end
	end)
end

return UI
