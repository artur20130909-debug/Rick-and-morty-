-- Окно магазина: вкладки и фильтры, сетка карточек с редкостью и ценой,
-- справа — подробности о выбранном блоке с вращающимся 3D-превью и большой кнопкой.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Blocks = require(Shared.Blocks)
local BlockFactory = require(Shared.BlockFactory)
local Util = require(Shared.Util)
local Net = require(Shared.Net)

local Client = script.Parent.Parent
local State = require(Client.State)
local SoundPlayer = require(Client.SoundPlayer)
local Theme = require(script.Parent.Theme)
local Lib = require(script.Parent.Lib)
local HUD = require(script.Parent.HUD)

local new = Lib.new
local fmt = Util.formatNumber
local ShopUI = {}

type Card = {
	kind: string,
	def: any,
	spec: any,
	button: TextButton,
	coin: Frame,
	price: TextLabel,
	badge: TextLabel,
}

type Stat = { row: Frame, value: TextLabel, fill: Frame }

-- Редкость по цене: до какой цены включительно, название, цвет
local RARITY = {
	{ max = 0, name = "Обычный", color = Theme.RarityCommon },
	{ max = 500, name = "Необычный", color = Theme.RarityUncommon },
	{ max = 2000, name = "Редкий", color = Theme.RarityRare },
	{ max = 6000, name = "Эпический", color = Theme.RarityEpic },
	{ max = math.huge, name = "Легендарный", color = Theme.RarityLegendary },
}

local MAX_HP = 2800 -- прочность самого крепкого материала (полная шкала)
local DARK = Color3.fromRGB(30, 22, 6)       -- тёмный текст на светлых плашках
local POOR = Color3.fromRGB(255, 112, 100)   -- цена, на которую не хватает золота
local GREY = Color3.fromRGB(84, 90, 108)     -- кнопка «Не хватает»

local cards: { Card } = {}
local tab = "mat"
local filter = "all" -- "all" | "own" | "buy"
local selected: { [string]: Card } = {} -- выбранная карточка на каждой вкладке
local shown: Card? = nil -- карточка, которая сейчас в панели подробностей
local busy = false

-- шапка и левая часть
local goldLabel: TextLabel
local countLabel: TextLabel
local countFill: Frame
local grid: ScrollingFrame
local emptyLabel: TextLabel
local tabButtons: { [string]: TextButton } = {}
local chipButtons: { [string]: TextButton } = {}

-- панель подробностей
local detailBody: Frame
local detailEmpty: TextLabel
local previewBox: Frame
local previewGrad: UIGradient
local previewLine: Frame
local previewVp: ViewportFrame? = nil
local flash: Frame
local kindTag: TextLabel
local ownBadge: TextLabel
local nameLabel: TextLabel
local rarityLabel: TextLabel
local descLabel: TextLabel
local chipsRow: Frame
local stats: { [string]: Stat } = {}
local afterLabel: TextLabel
local actButton: TextButton
local actLabel: TextLabel
local actCoin: Frame
local actPrice: TextLabel

-- ПОМОЩНИКИ ------------------------------------------------------------------------
local function rarityOf(price: number): (string, Color3, number)
	for i, r in RARITY do
		if price <= r.max then
			return r.name, r.color, i
		end
	end
	local last = RARITY[#RARITY]
	return last.name, last.color, #RARITY
end

local function owns(c: Card): boolean
	return State.isUnlocked(c.kind, c.def.id)
end

local function previewSpec(kind: string, def)
	if kind == "item" then
		return { mat = 0, shape = 1, item = def.id, size = def.size, rot = 1, color = def.color }
	end
	return { mat = def.id, shape = 1, item = 0, size = Vector3.new(2, 2, 2), rot = 1, color = def.color }
end

-- Копия списка, отсортированная по цене (дешёвые сверху)
local function sortedByPrice(list: { any }): { any }
	local out = table.clone(list)
	table.sort(out, function(a, b)
		if a.price ~= b.price then
			return a.price < b.price
		end
		return a.id < b.id
	end)
	return out
end

local function pct(v: number): string
	return math.floor(v * 100 + 0.5) .. "%"
end

-- Особенности блока короткими фразами
local function features(c: Card): { string }
	local def = c.def
	local out = {}
	if c.kind == "item" then
		local s = def.size
		table.insert(out, string.format("📐 Размер %d×%d×%d", s.X, s.Y, s.Z))
		if def.resizable then
			table.insert(out, "↔ Размер меняется")
		end
		if def.key == "AATurret" then
			table.insert(out, "🎯 Дальность " .. Blocks.AARange)
		elseif def.key == "Shield" then
			table.insert(out, "🔵 Купол R" .. Blocks.ShieldRadius)
			table.insert(out, "🛡 " .. fmt(Blocks.ShieldHp) .. " урона")
		elseif def.key == "Medkit" then
			table.insert(out, "✚ Радиус " .. Blocks.MedkitRange)
		elseif def.key == "TNT" then
			table.insert(out, "💥 Взрывается")
		elseif def.key == "Balloon" then
			table.insert(out, "🎈 Тянет вверх")
		end
		return out
	end
	if def.bulletMul < 1 then
		table.insert(out, "🛡 Пули почти не берут")
	end
	if def.explMul < 1 then
		table.insert(out, "💥 Гасит взрывы")
	end
	if def.laserMul < 1 then
		table.insert(out, "🔆 Отражает лазер")
	end
	if (def.regen or 0) > 0 then
		table.insert(out, "✚ Сам чинится")
	end
	if (def.density or 1) < 1 then
		table.insert(out, "🌊 Плавает")
	end
	return out
end

-- Плашка-«чип» с текстом в строке особенностей
local function chip(text: string, color: Color3, order: number)
	local l = Lib.label(text, 13, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = color,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Panel3,
		LayoutOrder = order,
		Parent = chipsRow,
	})
	Lib.corner(13).Parent = l
	Lib.padding(10, 0).Parent = l
end

local function setStat(key: string, value: number, text: string)
	local s = stats[key]
	s.value.Text = text
	s.fill.Size = UDim2.fromScale(0, 1)
	Lib.tween(s.fill, 0.45, { Size = UDim2.fromScale(math.clamp(value, 0.03, 1), 1) })
end

-- КАРТОЧКИ И ПОДРОБНОСТИ -----------------------------------------------------------
local function updateCard(c: Card, isSel: boolean)
	local def = c.def
	local own = owns(c)
	if def.price <= 0 then
		c.coin.Visible = false
		c.price.Text = "Бесплатно"
		c.price.TextColor3 = Theme.Sub
	elseif own then
		c.coin.Visible = false
		c.price.Text = "✔ Есть"
		c.price.TextColor3 = Theme.Good
	else
		c.coin.Visible = true
		c.price.Text = fmt(def.price)
		c.price.TextColor3 = if State.gold >= def.price then Theme.Gold else POOR
	end
	-- значок в углу превью: замок или галочка (у бесплатных — нет)
	c.badge.Visible = def.price > 0
	c.badge.Text = if own then "✔" else "🔒"
	c.badge.BackgroundColor3 = if own then Theme.Good else Theme.Bg
	c.badge.BackgroundTransparency = if own then 0 else 0.3
	Lib.setStroke(c.button, isSel)
	Lib.setButtonColor(c.button, if isSel then Theme.Panel3 else Theme.Panel2)
end

-- Показать блок в панели подробностей (превью, название, шкалы, особенности)
local function showDetails(c: Card?)
	shown = c
	if previewVp then
		previewVp:Destroy()
		previewVp = nil
	end
	detailBody.Visible = c ~= nil
	detailEmpty.Visible = c == nil
	if not c then
		detailEmpty.Text = if filter == "buy" then "🎉 Всё уже куплено!\nВыбери фильтр «Все»" else "Выбери блок слева"
		return
	end
	local def = c.def
	local rname, rc, tier = rarityOf(def.price)
	previewGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rc:Lerp(Theme.Bg, 0.5)),
		ColorSequenceKeypoint.new(0.5, rc:Lerp(Theme.Bg, 0.28)),
		ColorSequenceKeypoint.new(1, rc:Lerp(Theme.Bg, 0.86)),
	})
	previewLine.BackgroundColor3 = rc
	local spec = c.spec
	local vp = Lib.viewport(function()
		return BlockFactory.build(spec, CFrame.identity, { preview = true })
	end, { ZIndex = 2 }, true)
	vp.Parent = previewBox
	previewVp = vp

	kindTag.Text = if c.kind == "item" then "⚙ ОСОБЫЙ БЛОК" else "🧱 МАТЕРИАЛ"
	nameLabel.Text = def.name
	rarityLabel.Text = string.rep("★", tier) .. "  " .. rname .. (if c.kind == "item" then " особый блок" else " материал")
	rarityLabel.TextColor3 = rc
	descLabel.Text = def.desc or ""

	-- шкалы: у материалов три, у особых блоков только прочность
	local hp = Blocks.maxHp(spec, spec.size)
	setStat("hp", hp / MAX_HP, fmt(hp))
	local isMat = c.kind == "mat"
	stats.blast.row.Visible = isMat
	stats.nuke.row.Visible = isMat
	if isMat then
		setStat("blast", def.blast, pct(def.blast))
		setStat("nuke", def.nuke, pct(def.nuke))
	end

	for _, ch in chipsRow:GetChildren() do
		if ch:IsA("TextLabel") then
			ch:Destroy()
		end
	end
	local list = features(c)
	if #list == 0 then
		chip("Без особых свойств", Theme.Muted, 1)
	end
	for i, f in list do
		chip(f, Theme.Text, i)
	end
end

-- Кнопка и значок «куплено» зависят от золота, поэтому обновляются при каждом refresh
local function updateDetails()
	local c = shown
	if not c then
		return
	end
	local def = c.def
	local own = owns(c)
	ownBadge.Visible = own
	ownBadge.Text = if def.price <= 0 then "БЕСПЛАТНО" else "✔ КУПЛЕНО"
	if own then
		actLabel.Text = "🔨 СТРОИТЬ ЭТИМ"
		actLabel.TextColor3 = Theme.Text
		actCoin.Visible = false
		actPrice.Visible = false
		Lib.setButtonColor(actButton, Theme.Accent2)
		afterLabel.Text = "Выберет блок и закроет магазин"
	elseif State.gold >= def.price then
		actLabel.Text = "КУПИТЬ за"
		actLabel.TextColor3 = Theme.Text
		actCoin.Visible = true
		actPrice.Visible = true
		actPrice.Text = fmt(def.price)
		actPrice.TextColor3 = Theme.Text
		Lib.setButtonColor(actButton, Theme.Good)
		afterLabel.Text = "После покупки останется " .. fmt(State.gold - def.price)
	else
		actLabel.Text = "Не хватает"
		actLabel.TextColor3 = Theme.Sub
		actCoin.Visible = true
		actPrice.Visible = true
		actPrice.Text = fmt(def.price - State.gold)
		actPrice.TextColor3 = Theme.Sub
		Lib.setButtonColor(actButton, GREY)
		afterLabel.Text = "Заработай золото в осаде 💣"
	end
end

local function refresh()
	goldLabel.Text = fmt(State.gold)
	for k, b in tabButtons do
		Lib.setButtonColor(b, if k == tab then Theme.Accent2 else Theme.Panel2)
	end
	for k, b in chipButtons do
		local on = k == filter
		Lib.setButtonColor(b, if on then Theme.Accent else Theme.Panel2)
		b.TextColor3 = if on then DARK else Theme.Sub
	end

	-- видимость карточек по вкладке и фильтру, счётчик купленного
	local total, owned = 0, 0
	local first: Card? = nil
	local firstToBuy: Card? = nil
	for _, c in cards do
		local own = owns(c)
		local vis = c.kind == tab and (filter == "all" or (filter == "own") == own)
		c.button.Visible = vis
		if c.kind == tab then
			total += 1
			if own then
				owned += 1
			end
		end
		if vis then
			first = first or c
			if not own and not firstToBuy then
				firstToBuy = c
			end
		end
	end
	countLabel.Text = string.format('Куплено <font color="#%s">%d</font> / %d', Theme.Good:ToHex(), owned, total)
	countFill.Size = UDim2.fromScale(if total > 0 then owned / total else 0, 1)
	emptyLabel.Visible = first == nil
	emptyLabel.Text = if filter == "buy" then "🎉 Здесь всё уже куплено!" else "Здесь пока пусто"

	-- выбранная карточка должна быть видна; иначе — первая, которую можно купить
	local cur = selected[tab]
	-- только что купленную карточку оставляем выбранной, даже если фильтр её прячет
	if not (cur and (cur.button.Visible or cur == shown)) then
		cur = firstToBuy or first
		selected[tab] = cur :: any
	end
	for _, c in cards do
		updateCard(c, c == cur)
	end
	if cur ~= shown then
		showDetails(cur)
	end
	updateDetails()
end

-- Вспышка на превью и «прыжок» карточки после покупки
local function celebrate(c: Card)
	flash.BackgroundTransparency = 0.15
	Lib.tween(flash, 0.6, { BackgroundTransparency = 1 })
	local s = c.button:FindFirstChildOfClass("UIScale")
	if s then
		s.Scale = 1.15
		Lib.tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

-- Большая кнопка: купить или выбрать для стройки
local function onAction()
	local c = shown
	if not c or busy then
		return
	end
	local def = c.def
	if owns(c) then
		State.selectBlock(c.kind, def.id)
		HUD.closeModal()
		if State.tool ~= "build" then
			HUD.onTool:Fire("build")
		end
		return
	end
	if State.gold < def.price then
		HUD.toast("Не хватает " .. fmt(def.price - State.gold) .. " золота — заработай его в осаде!", "error")
		return
	end
	busy = true -- защита от двойного клика, пока ждём ответ сервера
	local called, ok, msg = pcall(function()
		return Net.func("Buy"):InvokeServer(c.kind, def.id)
	end)
	busy = false
	if not called then
		ok, msg = false, nil
	end
	if ok then
		SoundPlayer.play("Purchase")
		HUD.toast(msg or ("Куплено: " .. def.name), "success")
		State.selectBlock(c.kind, def.id)
		celebrate(c)
	elseif msg then
		HUD.toast(msg, "error")
	end
	refresh()
end

-- Карточка в сетке: превью на фоне цвета редкости, название, ценник
local function makeCard(kind: string, def, order: number)
	local _, rc = rarityOf(def.price)
	local card: Card
	local button = Lib.button("", {
		Size = UDim2.fromOffset(146, 182),
		BackgroundColor3 = Theme.Panel2,
		LayoutOrder = order,
		Parent = grid,
	}, function()
		selected[tab] = card
		refresh()
	end)
	local art = new("Frame", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, 100),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = button,
	}, { Lib.corner(10), Lib.gradient(rc:Lerp(Theme.Bg, 0.42), rc:Lerp(Theme.Bg, 0.82), 90) })
	-- светящаяся полоска редкости внизу превью
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, -24, 0, 3),
		BackgroundColor3 = rc,
		BorderSizePixel = 0,
		Parent = art,
	}, { Lib.corner(2) })
	local spec = previewSpec(kind, def)
	local vp = Lib.viewport(function()
		return BlockFactory.build(spec, CFrame.identity, { preview = true })
	end)
	vp.Parent = art
	local badge = Lib.label("", 13, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -5, 0, 5),
		Size = UDim2.fromOffset(24, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0.3,
		BackgroundColor3 = Theme.Bg,
		ZIndex = 2,
		Parent = art,
	})
	Lib.corner(12).Parent = badge
	Lib.label(def.name, 15, {
		FontFace = Theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		LineHeight = 0.95,
		Position = UDim2.fromOffset(6, 108),
		Size = UDim2.new(1, -12, 0, 36),
		Parent = button,
	})
	-- ценник: монета + цена, или «✔ Есть» / «Бесплатно»
	local row = new("Frame", {
		Position = UDim2.new(0, 8, 1, -34),
		Size = UDim2.new(1, -16, 0, 28),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = button,
	}, { Lib.corner(8), Lib.list(Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local coin = Lib.coin(18)
	coin.LayoutOrder = 1
	coin.Parent = row
	local price = Lib.label("", 16, {
		FontFace = Theme.FontHeavy,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextWrapped = false,
		TextColor3 = Theme.Gold,
		LayoutOrder = 2,
		Parent = row,
	})
	card = { kind = kind, def = def, spec = spec, button = button, coin = coin, price = price, badge = badge }
	table.insert(cards, card)
end

-- ПОСТРОЕНИЕ ОКНА ------------------------------------------------------------------
-- Монета и баланс в шапке окна, левее крестика
local function buildGoldPill(win: Instance)
	local pill = Lib.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -62, 0, 9),
		Size = UDim2.fromOffset(176, 40),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.25,
		ZIndex = 23,
		Parent = win,
	})
	local coin = Lib.coin(26)
	coin.Position = UDim2.fromOffset(8, 7)
	coin.Parent = pill
	goldLabel = Lib.label("0", 22, {
		FontFace = Theme.FontHeavy,
		TextColor3 = Theme.Gold,
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -50, 1, 0),
		Parent = pill,
	})
end

-- Левая часть: вкладки, счётчик, фильтры, сетка карточек
local function buildLeft(body: Frame)
	local left = new("Frame", { Size = UDim2.new(0, 644, 1, 0), BackgroundTransparency = 1, Parent = body })
	local tabs = {
		{ "mat", "🧱 Материалы (" .. #Blocks.Materials .. ")", 0, 206 },
		{ "item", "✨ Особые блоки (" .. #Blocks.Items .. ")", 216, 236 },
	}
	for _, t in tabs do
		tabButtons[t[1]] = Lib.button(t[2], {
			Position = UDim2.fromOffset(t[3], 0),
			Size = UDim2.fromOffset(t[4], 42),
			TextSize = 17,
			Parent = left,
		}, function()
			if tab ~= t[1] then
				tab = t[1]
				grid.CanvasPosition = Vector2.zero
				refresh()
			end
		end)
	end
	countLabel = Lib.label("", 15, {
		RichText = true,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(180, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Sub,
		TextWrapped = false,
		Parent = left,
	})
	local track, fill = Lib.bar(Theme.Good, 8)
	track.AnchorPoint = Vector2.new(1, 0)
	track.Position = UDim2.new(1, 0, 0, 28)
	track.Size = UDim2.fromOffset(180, 8)
	track.Parent = left
	countFill = fill

	local chips = {
		{ "all", "Все", 0, 80 },
		{ "own", "Есть", 88, 80 },
		{ "buy", "Купить", 176, 96 },
	}
	for _, f in chips do
		local b = Lib.button(f[2], {
			Position = UDim2.fromOffset(f[3], 54),
			Size = UDim2.fromOffset(f[4], 34),
			TextSize = 16,
			Parent = left,
		}, function()
			filter = f[1]
			grid.CanvasPosition = Vector2.zero
			refresh()
		end)
		local corner = b:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0, 17)
		end
		chipButtons[f[1]] = b
	end
	Lib.label("Нажми на блок — подробности справа", 14, {
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(284, 54),
		Size = UDim2.new(1, -284, 0, 34),
		Parent = left,
	})

	grid = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 1, -100),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Accent,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.Always,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = left,
	}, {
		Lib.corner(12),
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(146, 182),
			CellPadding = UDim2.fromOffset(12, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }),
	})
	emptyLabel = Lib.label("", 20, {
		FontFace = Theme.FontHeavy,
		TextColor3 = Theme.Sub,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 1, -100),
		Visible = false,
		ZIndex = 2,
		Parent = left,
	})
end

-- Строка со шкалой: название слева, значение справа, полоска снизу
local function statRow(parent: Instance, key: string, title: string, color: Color3, order: number)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	Lib.label(title, 14, { TextColor3 = Theme.Sub, Size = UDim2.new(1, -80, 0, 16), TextWrapped = false, Parent = row })
	local value = Lib.label("", 14, {
		FontFace = Theme.FontHeavy,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(80, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
	local track, fill = Lib.bar(color, 8)
	track.Position = UDim2.fromOffset(0, 21)
	track.Parent = row
	stats[key] = { row = row, value = value, fill = fill }
end

-- Правая часть: подробности о выбранном блоке
local function buildDetail(body: Frame)
	local detail = Lib.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 384, 1, 0),
		BackgroundColor3 = Theme.Panel,
		Parent = body,
	})
	detailEmpty = Lib.label("", 20, {
		FontFace = Theme.FontHeavy,
		TextColor3 = Theme.Sub,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -40, 1, 0),
		Visible = false,
		Parent = detail,
	})
	detailBody = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = detail })

	-- превью: фон-градиент цвета редкости, блик, тень, вращающийся блок
	previewGrad = Lib.gradient(Theme.Panel2, Theme.Bg, 90)
	previewBox = new("Frame", {
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(1, -28, 0, 206),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = detailBody,
	}, { Lib.corner(12), previewGrad })
	new("Frame", {
		Size = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = previewBox,
	}, { Lib.corner(12), new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.86, 1) }) })
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(160, 22),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.65,
		BorderSizePixel = 0,
		Parent = previewBox,
	}, { Lib.corner(11) })
	previewLine = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, -40, 0, 4),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = previewBox,
	}, { Lib.corner(2) })
	kindTag = Lib.label("", 12, {
		FontFace = Theme.FontHeavy,
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(0, 24),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0.35,
		BackgroundColor3 = Theme.Bg,
		ZIndex = 3,
		Parent = previewBox,
	})
	Lib.corner(12).Parent = kindTag
	Lib.padding(10, 0).Parent = kindTag
	ownBadge = Lib.label("", 12, {
		FontFace = Theme.FontHeavy,
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(0, 24),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(8, 40, 20),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Good,
		ZIndex = 3,
		Parent = previewBox,
	})
	Lib.corner(12).Parent = ownBadge
	Lib.padding(10, 0).Parent = ownBadge
	flash = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = previewBox,
	}, { Lib.corner(12) })

	-- название, редкость, описание
	nameLabel = Lib.label("", 28, {
		FontFace = Theme.FontHeavy,
		Position = UDim2.fromOffset(16, 228),
		Size = UDim2.new(1, -32, 0, 34),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = detailBody,
	})
	rarityLabel = Lib.label("", 16, {
		FontFace = Theme.FontHeavy,
		Position = UDim2.fromOffset(16, 262),
		Size = UDim2.new(1, -32, 0, 20),
		Parent = detailBody,
	})
	descLabel = Lib.label("", 15, {
		FontFace = Theme.FontMedium,
		TextColor3 = Theme.Sub,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(16, 288),
		Size = UDim2.new(1, -32, 0, 40),
		Parent = detailBody,
	})

	-- шкалы и особенности
	local info = new("Frame", {
		Position = UDim2.fromOffset(16, 334),
		Size = UDim2.new(1, -32, 0, 150),
		BackgroundTransparency = 1,
		Parent = detailBody,
	}, { Lib.list(Enum.FillDirection.Vertical, 8) })
	statRow(info, "hp", "❤ Прочность", Theme.Good, 1)
	statRow(info, "blast", "💥 Защита от взрывов", Theme.Accent2, 2)
	statRow(info, "nuke", "☢ Защита от радиации", Theme.Accent, 3)
	chipsRow = new("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = info,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- большая кнопка внизу: «КУПИТЬ за N» / «Не хватает N» / «СТРОИТЬ ЭТИМ»
	afterLabel = Lib.label("", 13, {
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 14, 1, -98),
		Size = UDim2.new(1, -28, 0, 18),
		Parent = detailBody,
	})
	actButton = Lib.button("", {
		Position = UDim2.new(0, 14, 1, -74),
		Size = UDim2.new(1, -28, 0, 60),
		BackgroundColor3 = Theme.Good,
		Parent = detailBody,
	}, onAction)
	new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 185)),
		Rotation = 90,
		Parent = actButton,
	})
	local actRow = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = actButton }, {
		Lib.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	actLabel = Lib.label("", 24, {
		FontFace = Theme.FontHeavy,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextWrapped = false,
		LayoutOrder = 1,
		Parent = actRow,
	})
	actCoin = Lib.coin(28)
	actCoin.LayoutOrder = 2
	actCoin.Parent = actRow
	actPrice = Lib.label("", 24, {
		FontFace = Theme.FontHeavy,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextWrapped = false,
		LayoutOrder = 3,
		Parent = actRow,
	})
	for _, l in { actLabel, actPrice } do
		new("UIStroke", { Thickness = 1.5, Color = Color3.new(0, 0, 0), Transparency = 0.6, Parent = l })
	end
end

function ShopUI.init()
	local shade, body = Lib.modal(HUD.gui(), "🛒 МАГАЗИН", Vector2.new(1080, 680), function()
		HUD.closeModal()
	end)
	buildGoldPill(body.Parent :: Instance)
	buildLeft(body)
	buildDetail(body)
	-- карточки: в каждой вкладке от дешёвых к дорогим
	for i, m in sortedByPrice(Blocks.Materials) do
		makeCard("mat", m, i)
	end
	for i, it in sortedByPrice(Blocks.Items) do
		makeCard("item", it, 100 + i)
	end
	HUD.registerModal("shop", shade, refresh)
	State.changed:Connect(function(key)
		if key == "gold" or key == "unlocked" then
			if State.modal == "shop" then
				refresh()
			end
		end
	end)
end

return ShopUI
