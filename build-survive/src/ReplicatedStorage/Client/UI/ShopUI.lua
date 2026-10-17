-- Окно магазина: вкладки и фильтры, сетка карточек с редкостью и ценой,
-- справа — подробности о выбранном блоке с вращающимся 3D-превью и большой кнопкой.
-- Вкладки «Дома» и «Бункеры» продают готовые постройки (Shared/Prefabs). Их 3D-превью собирается
-- только для выбранной постройки и по частям (без подвисаний), а установка на участок — после
-- подтверждения: в нём сказано, что будет убрано и что всё отменяется по Ctrl+Z.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Blocks = require(Shared.Blocks)
local BlockFactory = require(Shared.BlockFactory)
local Grid = require(Shared.Grid)
local Serializer = require(Shared.Serializer)
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
local plural = Util.plural
local ShopUI = {}

-- Готовая постройка из Shared/Prefabs (её создаёт tools/gen_prefabs.py)
type Prefab = {
	key: string,
	kind: string, -- "house" | "bunker"
	tier: number,
	name: string,
	icon: string,
	price: number,
	desc: string,
	features: { string },
	blocks: number,
	guards: number,
	aa: number,
	shields: number,
	medkits: number,
	data: string,
}

local Prefabs = require(Shared.Prefabs) :: { Prefab }

type Card = {
	kind: string, -- "mat" | "item" | "house" | "bunker"
	def: any,      -- материал, особый блок или готовая постройка
	spec: any,     -- спецификация блока для превью (у построек — nil)
	button: TextButton,
	coin: Frame,
	price: TextLabel,
	badge: TextLabel,
}

type Stat = { row: Frame, value: TextLabel, fill: Frame }

-- Коробка в координатах участка
type Box = { lo: Vector3, hi: Vector3 }

-- Разобранная постройка: блоки для превью, габариты и зона, которую она освобождает на участке
type PrefabData = { specs: { any }, count: number, lo: Vector3, hi: Vector3, zone: Box? }

-- Редкость по цене: до какой цены включительно, название, цвет.
-- У готовых построек редкость — их уровень (1–5).
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
local RED_OFF = Color3.fromRGB(138, 44, 50)  -- выключенная кнопка «Купить» у построек
local GRASS = Color3.fromRGB(96, 150, 72)    -- полупрозрачная земля в превью бункера
local FLOOR = Color3.fromRGB(164, 166, 164)  -- плита пола в превью дома

local EPS = 0.01
local MARGIN = 1     -- как на сервере (PrefabShop): зона замены шире постройки на 1 стад по X и Z
local KIOSK_LO = 24  -- вход бункера — в углу участка: x, z от 24 до 32
local BATCH = 80     -- сколько блоков превью собирать за кадр

local player = Players.LocalPlayer

local cards: { Card } = {}
local tab = "mat" -- "mat" | "item" | "house" | "bunker"
local filter = "all" -- "all" | "own" | "buy"
local selected: { [string]: Card } = {} -- выбранная карточка на каждой вкладке
local shown: Card? = nil -- карточка, которая сейчас в панели подробностей
local busy = false
local parsed: { [string]: PrefabData } = {}

-- шапка и левая часть
local goldLabel: TextLabel
local countLabel: TextLabel
local countFill: Frame
local hintLabel: TextLabel
local grid: ScrollingFrame
local prefabGrid: ScrollingFrame
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
local previewSpin: RBXScriptConnection? = nil
local previewToken = 0
local flash: Frame
local kindTag: TextLabel
local ownBadge: TextLabel
local nameLabel: TextLabel
local rarityLabel: TextLabel
local descLabel: TextLabel
local info: Frame
local chipsRow: Frame
local stats: { [string]: Stat } = {}
local prefabPanel: ScrollingFrame
local prefabDesc: TextLabel
local prefabStatsRow: Frame
local prefabFeatures: Frame
local afterLabel: TextLabel
local actButton: TextButton
local actLabel: TextLabel
local actCoin: Frame
local actPrice: TextLabel

-- подтверждение установки постройки
local confirmBox: TextButton
local confirmScale: UIScale
local confirmTitle: TextLabel
local confirmText: TextLabel
local confirmYes: TextButton
local confirmFor: Card? = nil

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

-- Уровень постройки 1–5 → название и цвет редкости
local function tierOf(tier: number?): (string, Color3, number)
	local i = math.clamp(math.floor(tonumber(tier) or 1), 1, #RARITY)
	return RARITY[i].name, RARITY[i].color, i
end

local function isPrefab(c: Card): boolean
	return c.kind == "house" or c.kind == "bunker"
end

local function isPrefabTab(): boolean
	return tab == "house" or tab == "bunker"
end

local function owns(c: Card): boolean
	if isPrefab(c) then
		return State.prefabs[c.def.key] == true
	end
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

local function colored(text: string, color: Color3): string
	return string.format('<font color="#%s">%s</font>', color:ToHex(), text)
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

-- Главное о постройке: блоки, охрана, ПВО, щит, аптечки. long — со словами («2 охранника»).
local function prefabStats(p: Prefab, long: boolean): { string }
	local function stat(icon: string, n: number, one: string, few: string, many: string): string
		if long then
			return icon .. " " .. fmt(n) .. " " .. plural(n, one, few, many)
		end
		return icon .. " " .. fmt(n)
	end
	local out = { stat("🧱", p.blocks or 0, "блок", "блока", "блоков") }
	if (p.guards or 0) > 0 then
		table.insert(out, stat("🛡", p.guards, "охранник", "охранника", "охранников"))
	end
	if (p.aa or 0) > 0 then
		table.insert(out, stat("🎯", p.aa, "турель ПВО", "турели ПВО", "турелей ПВО"))
	end
	if (p.shields or 0) > 0 then
		table.insert(out, stat("🔵", p.shields, "щит", "щита", "щитов"))
	end
	if (p.medkits or 0) > 0 then
		table.insert(out, stat("✚", p.medkits, "аптечка", "аптечки", "аптечек"))
	end
	return out
end

-- Плашка-«чип» с текстом (особенности блока, характеристики постройки)
local function chip(text: string, color: Color3, order: number, parent: Instance?)
	local l = Lib.label(text, 13, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = color,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Panel3,
		LayoutOrder = order,
		Parent = parent or chipsRow,
	})
	Lib.corner(13).Parent = l
	Lib.padding(10, 0).Parent = l
end

local function clearLabels(parent: Instance)
	for _, ch in parent:GetChildren() do
		if ch:IsA("TextLabel") then
			ch:Destroy()
		end
	end
end

local function setStat(key: string, value: number, text: string)
	local s = stats[key]
	s.value.Text = text
	s.fill.Size = UDim2.fromScale(0, 1)
	Lib.tween(s.fill, 0.45, { Size = UDim2.fromScale(math.clamp(value, 0.03, 1), 1) })
end

-- ГОТОВЫЕ ПОСТРОЙКИ: ГАБАРИТЫ И ЗОНА ЗАМЕНЫ ----------------------------------------
local function boxOf(pos: Vector3, size: Vector3, rot: number): Box
	local e = Grid.extents(size, rot)
	return { lo = pos - e / 2, hi = pos + e / 2 }
end

-- Коробки пересекаются по объёму (касание гранями не считается)
local function intersects(a: Box, b: Box): boolean
	return a.lo.X < b.hi.X - EPS and b.lo.X < a.hi.X - EPS
		and a.lo.Y < b.hi.Y - EPS and b.lo.Y < a.hi.Y - EPS
		and a.lo.Z < b.hi.Z - EPS and b.lo.Z < a.hi.Z - EPS
end

local function grow(b: Box, d: number): Box
	local v = Vector3.new(d, 0, d)
	return { lo = b.lo - v, hi = b.hi + v }
end

-- Разобрать постройку один раз: блоки, габариты и зона замены (правила — как в Server/PrefabShop)
local function prefabDataOf(p: Prefab): PrefabData
	local cached = parsed[p.key]
	if cached then
		return cached
	end
	local all = Serializer.decode(p.data)
	local specs = {}
	local lo: Vector3?, hi: Vector3? = nil, nil
	local sLo: Vector3?, sHi: Vector3? = nil, nil -- наземная часть (вход бункера)
	for _, spec in all do
		if Blocks.def(spec) then
			table.insert(specs, spec)
		end
		local b = boxOf(spec.pos, spec.size, spec.rot)
		lo = if lo then lo:Min(b.lo) else b.lo
		hi = if hi then hi:Max(b.hi) else b.hi
		if b.lo.Y >= -EPS then
			sLo = if sLo then sLo:Min(b.lo) else b.lo
			sHi = if sHi then sHi:Max(b.hi) else b.hi
		end
	end
	local zone: Box? = nil
	if p.kind == "bunker" then
		if sLo and sHi then
			local edge = Config.PlotSize.X / 2
			zone = grow({
				lo = Vector3.new(math.min(KIOSK_LO, sLo.X), 0, math.min(KIOSK_LO, sLo.Z)),
				hi = Vector3.new(math.max(edge, sHi.X), sHi.Y, math.max(edge, sHi.Z)),
			}, MARGIN)
		end
	elseif lo and hi then
		zone = grow({ lo = lo, hi = hi }, MARGIN)
	end
	local result: PrefabData = {
		specs = specs,
		count = #all,
		lo = lo or Vector3.zero,
		hi = hi or Vector3.zero,
		zone = zone,
	}
	parsed[p.key] = result
	return result
end

-- Папка блоков моего участка
local function myBlocks(): Instance?
	local idx = player:GetAttribute("Plot")
	local plots = workspace:FindFirstChild("Plots")
	local model = idx and plots and plots:FindFirstChild("Plot" .. tostring(idx))
	return model and model:FindFirstChild("Blocks")
end

-- Сколько моих блоков уберёт установка и сколько блоков станет на участке (nil — участка нет)
local function estimate(p: Prefab): (number?, number)
	local folder = myBlocks()
	if not folder then
		return nil, 0
	end
	local pd = prefabDataOf(p)
	local bunker = p.kind == "bunker"
	local removed, total = 0, 0
	for _, b in folder:GetChildren() do
		total += 1
		local pos, size = b:GetAttribute("Local"), b:GetAttribute("BlockSize")
		if typeof(pos) == "Vector3" and typeof(size) == "Vector3" then
			local box = boxOf(pos, size, tonumber(b:GetAttribute("Rot")) or 1)
			if (bunker and box.lo.Y < -EPS) or (pd.zone and intersects(box, pd.zone)) then
				removed += 1
			end
		end
	end
	return removed, total - removed + pd.count
end

-- 3D-ПРЕВЬЮ -----------------------------------------------------------------------
-- Убрать превью (и прервать сборку недостроенного превью постройки)
local function clearPreview()
	previewToken += 1
	if previewSpin then
		previewSpin:Disconnect()
		previewSpin = nil
	end
	if previewVp then
		previewVp:Destroy()
		previewVp = nil
	end
end

-- Вращающееся превью готовой постройки. Камера наводится на габариты постройки,
-- блоки добавляются по BATCH за кадр. У дома снизу плита пола, у бункера — полупрозрачная
-- земля на уровне пола: сквозь неё видно подземную часть.
local function buildPrefabPreview(p: Prefab)
	local pd = prefabDataOf(p)
	local bunker = p.kind == "bunker"
	local vp = new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(150, 155, 170),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1.4, -0.6),
		ZIndex = 2,
		Parent = previewBox,
	})
	previewVp = vp
	local model = new("Model", { Parent = vp })

	-- земля: верх чуть выше пола, чтобы не мерцать с крышей бункера на уровне пола
	local pad = 4
	local lo = pd.lo:Min(Vector3.new(pd.lo.X - pad, -0.35, pd.lo.Z - pad))
	local hi = pd.hi:Max(Vector3.new(pd.hi.X + pad, 0.05, pd.hi.Z + pad))
	new("Part", {
		Anchored = true,
		CastShadow = false,
		Material = Enum.Material.SmoothPlastic,
		Color = if bunker then GRASS else FLOOR,
		Transparency = if bunker then 0.55 else 0,
		Size = Vector3.new(hi.X - lo.X, 0.4, hi.Z - lo.Z),
		CFrame = CFrame.new((lo.X + hi.X) / 2, -0.15, (lo.Z + hi.Z) / 2),
		Parent = model,
	})

	local cam = new("Camera", { FieldOfView = 30, Parent = vp })
	vp.CurrentCamera = cam
	local center = (lo + hi) / 2
	local dist = (hi - lo).Magnitude * 1.5 + 2
	local lift = if bunker then 0.42 else 0.55 -- бункер — чуть сбоку, чтобы было видно глубину
	local angle = math.rad(35)
	local function aim()
		local offset = Vector3.new(math.sin(angle), lift, math.cos(angle)).Unit * dist
		cam.CFrame = CFrame.lookAt(center + offset, center)
	end
	aim()
	previewSpin = RunService.RenderStepped:Connect(function(dt)
		if State.modal == "shop" then
			angle += dt * 0.5
			aim()
		end
	end)

	local token = previewToken
	task.spawn(function()
		for i, spec in pd.specs do
			if token ~= previewToken then
				return -- выбрали другую карточку или закрыли магазин
			end
			local part = BlockFactory.build(spec, Grid.worldCFrame(CFrame.identity, spec.pos, spec.rot), { preview = true })
			part.Parent = model
			if i % BATCH == 0 then
				task.wait()
			end
		end
	end)
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
		c.price.Text = if isPrefab(c) then "✔ Куплено" else "✔ Есть"
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

local function hideConfirm()
	confirmFor = nil
	confirmBox.Visible = false
end

-- Постройка в панели подробностей: превью, уровень, описание, характеристики, что внутри
local function showPrefab(c: Card, rname: string, rc: Color3, tier: number)
	local p: Prefab = c.def
	local bunker = p.kind == "bunker"
	buildPrefabPreview(p)
	kindTag.Text = if bunker then "🛡 БУНКЕР" else "🏠 ДОМ"
	nameLabel.Text = (p.icon or "") .. " " .. p.name
	rarityLabel.Text = string.rep("★", tier) .. "  Уровень " .. tier .. " · " .. rname .. (if bunker then " бункер" else " дом")
	rarityLabel.TextColor3 = rc

	info.Visible = false
	descLabel.Visible = false
	prefabPanel.Visible = true
	prefabPanel.CanvasPosition = Vector2.zero
	prefabDesc.Text = p.desc or ""
	clearLabels(prefabStatsRow)
	local list = prefabStats(p, true)
	if bunker then
		local depth = math.floor(-prefabDataOf(p).lo.Y + 0.5)
		if depth > 0 then
			table.insert(list, "⛏ Глубина " .. depth .. " " .. plural(depth, "стад", "стада", "стадов"))
		end
	end
	for i, s in list do
		chip(s, Theme.Text, i, prefabStatsRow)
	end
	clearLabels(prefabFeatures)
	local feats: { string } = p.features or {}
	for i, f in feats do
		Lib.label("• " .. f, 14, {
			FontFace = Theme.FontMedium,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = i,
			Parent = prefabFeatures,
		})
	end
end

-- Показать карточку в панели подробностей (превью, название, шкалы, особенности)
local function showDetails(c: Card?)
	shown = c
	clearPreview()
	hideConfirm()
	detailBody.Visible = c ~= nil
	detailEmpty.Visible = c == nil
	if not c then
		if filter == "buy" then
			detailEmpty.Text = "🎉 Всё уже куплено!\nВыбери фильтр «Все»"
		else
			detailEmpty.Text = if isPrefabTab() then "Выбери постройку слева" else "Выбери блок слева"
		end
		return
	end
	local def = c.def
	local rname, rc, tier
	if isPrefab(c) then
		rname, rc, tier = tierOf(def.tier)
	else
		rname, rc, tier = rarityOf(def.price)
	end
	previewGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rc:Lerp(Theme.Bg, 0.5)),
		ColorSequenceKeypoint.new(0.5, rc:Lerp(Theme.Bg, 0.28)),
		ColorSequenceKeypoint.new(1, rc:Lerp(Theme.Bg, 0.86)),
	})
	previewLine.BackgroundColor3 = rc
	if isPrefab(c) then
		showPrefab(c, rname, rc, tier)
		return
	end

	local spec = c.spec
	local vp = Lib.viewport(function()
		return BlockFactory.build(spec, CFrame.identity, { preview = true })
	end, { ZIndex = 2 }, true)
	vp.Parent = previewBox
	previewVp = vp

	info.Visible = true
	descLabel.Visible = true
	prefabPanel.Visible = false
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

	clearLabels(chipsRow)
	local list = features(c)
	if #list == 0 then
		chip("Без особых свойств", Theme.Muted, 1)
	end
	for i, f in list do
		chip(f, Theme.Text, i)
	end
end

-- Кнопка постройки: «КУПИТЬ — N» (красная и выключенная, если золота мало) или «ПОСТАВИТЬ НА УЧАСТОК»
local function updatePrefabButton(c: Card)
	local p: Prefab = c.def
	local own = owns(c)
	ownBadge.Visible = own
	ownBadge.Text = "✔ КУПЛЕНО"
	actButton.Active = true
	actLabel.TextSize = 24
	actPrice.Text = fmt(p.price)
	if own then
		actLabel.Text = "📍 ПОСТАВИТЬ НА УЧАСТОК"
		actLabel.TextSize = 21
		actLabel.TextColor3 = Theme.Text
		actCoin.Visible = false
		actPrice.Visible = false
		Lib.setButtonColor(actButton, Theme.Accent2)
		afterLabel.Text = if p.kind == "bunker"
			then "Займёт подземелье и угол участка • Ctrl+Z — отменить"
			else "Встанет в центр участка • Ctrl+Z — отменить"
	elseif State.gold >= p.price then
		actLabel.Text = "КУПИТЬ —"
		actLabel.TextColor3 = Theme.Text
		actCoin.Visible = true
		actPrice.Visible = true
		actPrice.TextColor3 = Theme.Text
		Lib.setButtonColor(actButton, Theme.Good)
		afterLabel.Text = "После покупки останется " .. fmt(State.gold - p.price)
	else
		actLabel.Text = "КУПИТЬ —"
		actLabel.TextColor3 = Color3.fromRGB(255, 196, 196)
		actCoin.Visible = true
		actPrice.Visible = true
		actPrice.TextColor3 = Color3.fromRGB(255, 196, 196)
		Lib.setButtonColor(actButton, RED_OFF)
		actButton.Active = false
		afterLabel.Text = "Не хватает " .. fmt(p.price - State.gold) .. " — заработай золото в осаде 💣"
	end
end

-- Кнопка и значок «куплено» зависят от золота, поэтому обновляются при каждом refresh
local function updateDetails()
	local c = shown
	if not c then
		return
	end
	if isPrefab(c) then
		updatePrefabButton(c)
		return
	end
	local def = c.def
	local own = owns(c)
	actButton.Active = true
	actLabel.TextSize = 24
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
	local prefabTab = isPrefabTab()
	grid.Visible = not prefabTab
	prefabGrid.Visible = prefabTab
	hintLabel.Text = if prefabTab
		then "Готовая постройка ставится на участок целиком"
		else "Нажми на блок — подробности справа"

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

-- Окно подтверждения: что уберётся с участка, хватит ли лимита блоков, как отменить
local function showConfirm(c: Card)
	local p: Prefab = c.def
	local bunker = p.kind == "bunker"
	local removed, total = estimate(p)
	local lines = {}
	if bunker then
		table.insert(lines, "Бункер займёт подземелье участка, а вход встанет в дальнем углу. "
			.. "Земля будет выкопана по форме бункера, а ямы, выкопанные раньше, засыплются.")
	else
		table.insert(lines, "Дом встанет в центр участка.")
	end
	local ok = removed ~= nil
	if not removed then
		table.insert(lines, colored("⚠ У тебя нет участка — ставить некуда.", Theme.Bad))
	elseif removed > 0 then
		local what = if bunker then "Всё, что построено под полом, и блоки на месте входа" else "Твои блоки на месте дома"
		table.insert(lines, what .. " будут убраны: <b>" .. fmt(removed) .. " " .. plural(removed, "блок", "блока", "блоков") .. "</b>.")
	else
		table.insert(lines, colored("Твои блоки не пострадают — место свободно.", Theme.Good))
	end
	if removed then
		if total > Config.MaxBlocks then
			ok = false
			table.insert(lines, colored(string.format("⚠ Не хватит лимита: получится %s из %s блоков. Убери лишние блоки.",
				fmt(total), fmt(Config.MaxBlocks)), Theme.Bad))
		else
			table.insert(lines, string.format("Блоков на участке станет: %s из %s.", fmt(total), fmt(Config.MaxBlocks)))
		end
	end
	if State.inSiege() or State.launched then
		ok = false
		table.insert(lines, colored("⚠ Сейчас идёт осада или испытание — поставить можно после.", Theme.Bad))
	end
	table.insert(lines, colored("Передумаешь — Ctrl+Z (или кнопка «↶ Отмена») вернёт всё как было.", Theme.Accent))

	confirmFor = c
	confirmTitle.Text = "Поставить «" .. p.name .. "»?"
	confirmText.Text = table.concat(lines, "\n\n")
	confirmYes.Active = ok
	Lib.setButtonColor(confirmYes, if ok then Theme.Good else GREY)
	confirmBox.Visible = true
	confirmScale.Scale = 0.92
	Lib.tween(confirmScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Подтвердили установку: просим сервер поставить постройку
local function placeConfirmed()
	local c = confirmFor
	if not c or busy then
		return
	end
	local p: Prefab = c.def
	busy = true -- защита от двойного клика, пока ждём ответ сервера
	confirmYes.Text = "⏳ Ставим…"
	local called, ok, msg = pcall(function()
		return Net.func("PlacePrefab"):InvokeServer(p.key)
	end)
	busy = false
	confirmYes.Text = "✔ Поставить"
	if not called then
		ok, msg = false, nil
	end
	hideConfirm()
	if ok then
		SoundPlayer.play("Place", { speed = 0.7, volume = 1.6 })
		HUD.toast(msg or ("Постройка «" .. p.name .. "» на участке"), "success")
		-- закрываем магазин, чтобы было видно постройку (если игрок не открыл другое окно, пока ждали)
		if State.modal == "shop" then
			HUD.closeModal()
		end
	else
		HUD.toast(msg or "Не удалось поставить постройку", "error")
	end
end

-- Большая кнопка у постройки: купить или открыть подтверждение установки
local function prefabAction(c: Card)
	local p: Prefab = c.def
	if owns(c) then
		showConfirm(c)
		return
	end
	if State.gold < p.price then
		HUD.toast("Не хватает " .. fmt(p.price - State.gold) .. " золота — заработай его в осаде!", "error")
		return
	end
	busy = true
	local called, ok, msg = pcall(function()
		return Net.func("BuyPrefab"):InvokeServer(p.key)
	end)
	busy = false
	if not called then
		ok, msg = false, nil
	end
	if ok then
		SoundPlayer.play("Purchase")
		HUD.toast(msg or ("Куплено: " .. p.name), "success")
		celebrate(c)
	elseif msg then
		HUD.toast(msg, "error")
	end
	refresh()
end

-- Большая кнопка: купить или выбрать для стройки
local function onAction()
	local c = shown
	if not c or busy then
		return
	end
	if isPrefab(c) then
		prefabAction(c)
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

-- Общие части карточки: фон превью цвета редкости, значок-замок, ценник
local function cardArt(button: TextButton, rc: Color3, height: number): Frame
	local art = new("Frame", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, height),
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
	return art
end

local function cardBadge(art: Frame): TextLabel
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
	return badge
end

-- ценник: монета + цена, или «✔ Есть» / «Бесплатно»
local function cardPrice(button: TextButton): (Frame, TextLabel)
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
	return coin, price
end

-- Карточка блока в сетке: превью на фоне цвета редкости, название, ценник
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
	local art = cardArt(button, rc, 100)
	local spec = previewSpec(kind, def)
	local vp = Lib.viewport(function()
		return BlockFactory.build(spec, CFrame.identity, { preview = true })
	end)
	vp.Parent = art
	local badge = cardBadge(art)
	Lib.label(def.name, 15, {
		FontFace = Theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		LineHeight = 0.95,
		Position = UDim2.fromOffset(6, 108),
		Size = UDim2.new(1, -12, 0, 36),
		Parent = button,
	})
	local coin, price = cardPrice(button)
	card = { kind = kind, def = def, spec = spec, button = button, coin = coin, price = price, badge = badge }
	table.insert(cards, card)
end

-- Карточка готовой постройки: большой значок вместо 3D (превью — только у выбранной),
-- звёзды уровня, название, главное о постройке, ценник
local function makePrefabCard(p: Prefab, order: number)
	local _, rc, tier = tierOf(p.tier)
	local card: Card
	local button = Lib.button("", {
		Size = UDim2.fromOffset(200, 232),
		BackgroundColor3 = Theme.Panel2,
		LayoutOrder = order,
		Parent = prefabGrid,
	}, function()
		selected[tab] = card
		refresh()
	end)
	local art = cardArt(button, rc, 108)
	Lib.label(p.icon or "🏠", 58, {
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = art,
	})
	local stars = Lib.label(string.rep("★", tier), 13, {
		FontFace = Theme.FontHeavy,
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.fromOffset(0, 24),
		TextWrapped = false,
		TextColor3 = rc,
		BackgroundTransparency = 0.3,
		BackgroundColor3 = Theme.Bg,
		ZIndex = 2,
		Parent = art,
	})
	Lib.corner(12).Parent = stars
	Lib.padding(8, 0).Parent = stars
	local badge = cardBadge(art)
	Lib.label(p.name, 17, {
		FontFace = Theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(8, 118),
		Size = UDim2.new(1, -16, 0, 22),
		Parent = button,
	})
	Lib.label(table.concat(prefabStats(p, false), "   "), 14, {
		TextColor3 = Theme.Sub,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(8, 144),
		Size = UDim2.new(1, -16, 0, 40),
		Parent = button,
	})
	local coin, price = cardPrice(button)
	card = { kind = p.kind, def = p, spec = nil, button = button, coin = coin, price = price, badge = badge }
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

-- Сетка карточек с прокруткой (cell — размер карточки)
local function cardGrid(parent: Instance, cell: Vector2): ScrollingFrame
	return new("ScrollingFrame", {
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
		Parent = parent,
	}, {
		Lib.corner(12),
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(cell.X, cell.Y),
			CellPadding = UDim2.fromOffset(12, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }),
	})
end

local function countKind(kind: string): number
	local n = 0
	for _, p in Prefabs do
		if p.kind == kind then
			n += 1
		end
	end
	return n
end

-- Левая часть: вкладки, фильтры, счётчик, сетка карточек
local function buildLeft(body: Frame)
	local left = new("Frame", { Size = UDim2.new(0, 644, 1, 0), BackgroundTransparency = 1, Parent = body })
	local tabs = {
		{ "mat", "🧱 Материалы (" .. #Blocks.Materials .. ")", 160 },
		{ "item", "✨ Особые блоки (" .. #Blocks.Items .. ")", 176 },
		{ "house", "🏠 Дома (" .. countKind("house") .. ")", 128 },
		{ "bunker", "🛡 Бункеры (" .. countKind("bunker") .. ")", 150 },
	}
	local x = 0
	for _, t in tabs do
		tabButtons[t[1]] = Lib.button(t[2], {
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(t[3], 42),
			TextSize = 15,
			Parent = left,
		}, function()
			if tab ~= t[1] then
				tab = t[1]
				grid.CanvasPosition = Vector2.zero
				prefabGrid.CanvasPosition = Vector2.zero
				refresh()
			end
		end)
		x += t[3] + 10
	end

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
			prefabGrid.CanvasPosition = Vector2.zero
			refresh()
		end)
		local corner = b:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0, 17)
		end
		chipButtons[f[1]] = b
	end
	hintLabel = Lib.label("", 13, {
		TextColor3 = Theme.Muted,
		Position = UDim2.fromOffset(286, 54),
		Size = UDim2.new(1, -286 - 192, 0, 34),
		Parent = left,
	})
	-- счётчик купленного на вкладке
	countLabel = Lib.label("", 15, {
		RichText = true,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 52),
		Size = UDim2.fromOffset(180, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Sub,
		TextWrapped = false,
		Parent = left,
	})
	local track, fill = Lib.bar(Theme.Good, 8)
	track.AnchorPoint = Vector2.new(1, 0)
	track.Position = UDim2.new(1, 0, 0, 78)
	track.Size = UDim2.fromOffset(180, 8)
	track.Parent = left
	countFill = fill

	grid = cardGrid(left, Vector2.new(146, 182))
	prefabGrid = cardGrid(left, Vector2.new(200, 232))
	prefabGrid.Visible = false
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

-- Подробности о постройке: описание, характеристики, список «что внутри» (с прокруткой)
local function buildPrefabPanel()
	prefabPanel = new("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 288),
		Size = UDim2.new(1, -24, 0, 206),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Accent,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = detailBody,
	}, { Lib.list(Enum.FillDirection.Vertical, 10) })
	prefabDesc = Lib.label("", 15, {
		FontFace = Theme.FontMedium,
		TextColor3 = Theme.Sub,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -10, 0, 0),
		LayoutOrder = 1,
		Parent = prefabPanel,
	})
	prefabStatsRow = new("Frame", {
		Size = UDim2.new(1, -10, 0, 26),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = prefabPanel,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	prefabFeatures = new("Frame", {
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = prefabPanel,
	}, { Lib.list(Enum.FillDirection.Vertical, 3) })
end

-- Подтверждение установки постройки: поверх нижней части панели подробностей (превью остаётся видно)
local function buildConfirm()
	confirmBox = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(8, 226),
		Size = UDim2.new(1, -16, 1, -234),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
		Parent = detailBody,
	}, { Lib.corner(12), Lib.stroke(Theme.Accent, 2, 0.25) })
	confirmScale = new("UIScale", { Parent = confirmBox })
	confirmTitle = Lib.label("", 21, {
		FontFace = Theme.FontHeavy,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 28),
		Parent = confirmBox,
	})
	confirmText = Lib.label("", 14, {
		RichText = true,
		FontFace = Theme.FontMedium,
		TextColor3 = Theme.Sub,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(16, 46),
		Size = UDim2.new(1, -32, 1, -124),
		Parent = confirmBox,
	})
	confirmYes = Lib.button("✔ Поставить", {
		Position = UDim2.new(0, 14, 1, -70),
		Size = UDim2.new(0.6, -20, 0, 56),
		BackgroundColor3 = Theme.Good,
		TextSize = 20,
		Parent = confirmBox,
	}, placeConfirmed)
	Lib.button("Назад", {
		Position = UDim2.new(0.6, 0, 1, -70),
		Size = UDim2.new(0.4, -14, 0, 56),
		BackgroundColor3 = Theme.Panel3,
		TextSize = 20,
		Parent = confirmBox,
	}, hideConfirm)
end

-- Правая часть: подробности о выбранном блоке или постройке
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

	-- шкалы и особенности (у блоков)
	info = new("Frame", {
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
	-- описание, характеристики и состав (у построек)
	buildPrefabPanel()

	-- большая кнопка внизу: «КУПИТЬ за N» / «Не хватает N» / «СТРОИТЬ ЭТИМ» / «ПОСТАВИТЬ НА УЧАСТОК»
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

	-- подтверждение — последним, поверх остального
	buildConfirm()
end

-- Магазин закрыли: тяжёлое превью постройки не держим (после анимации закрытия)
local function onClose()
	hideConfirm()
	task.delay(0.2, function()
		local c = shown
		if State.modal ~= "shop" and c and isPrefab(c) then
			clearPreview()
			shown = nil
		end
	end)
end

function ShopUI.init()
	local shade, body = Lib.modal(HUD.gui(), "🛒 МАГАЗИН", Vector2.new(1080, 680), function()
		HUD.closeModal()
	end)
	buildGoldPill(body.Parent :: Instance)
	buildLeft(body)
	buildDetail(body)
	-- карточки: в каждой вкладке от дешёвых к дорогим (постройки — по уровню, как в Prefabs)
	for i, m in sortedByPrice(Blocks.Materials) do
		makeCard("mat", m, i)
	end
	for i, it in sortedByPrice(Blocks.Items) do
		makeCard("item", it, 100 + i)
	end
	for i, p in Prefabs do
		if p.kind == "house" or p.kind == "bunker" then
			makePrefabCard(p, i)
		end
	end
	HUD.registerModal("shop", shade, refresh, onClose)
	State.changed:Connect(function(key)
		if key == "gold" or key == "unlocked" or key == "prefabs" then
			if State.modal == "shop" then
				refresh()
			end
		end
	end)
end

return ShopUI
