-- Интерфейс игрока (клиент): HUD дома и лобби, тосты, экстренное оповещение (EAS), магазин,
-- киоски лобби (классы, досье, задания, коды), загрузка, итоги, смерть и наблюдение,
-- мини-игра концентрации в укрытии, свой вид ProximityPrompt, вывески кабинок и билборд лобби.
-- Всё строится кодом. Стиль — аналоговый хоррор 90-х: VHS-зерно, сканлайны, свечение ЭЛТ, янтарь.
-- Вёрстка: «эталонные» пиксели + UIScale под размер экрана (телефон и ПК).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local PPS = game:GetService("ProximityPromptService")
local CAS = game:GetService("ContextActionService")
local RS = game:GetService("ReplicatedStorage")

local UI = {}

local ctx, player, Config, Net, Sound
local pgui = nil
local started = false
local T = 0                 -- время интерфейса (секунды)

-- ===================== палитра и шрифты =====================
local COL = {
	amber = Color3.fromRGB(255, 176, 0),
	amber2 = Color3.fromRGB(255, 122, 0),
	amberDim = Color3.fromRGB(96, 66, 8),
	red = Color3.fromRGB(232, 38, 43),
	redDark = Color3.fromRGB(96, 6, 10),
	panel = Color3.fromRGB(12, 13, 18),
	panel2 = Color3.fromRGB(24, 26, 33),
	panel3 = Color3.fromRGB(34, 37, 46),
	line = Color3.fromRGB(255, 255, 255),
	txt = Color3.fromRGB(242, 242, 242),
	dim = Color3.fromRGB(154, 163, 178),
	ok = Color3.fromRGB(54, 209, 107),
	cyan = Color3.fromRGB(0, 230, 255),
	blue = Color3.fromRGB(70, 140, 255),
	black = Color3.new(0, 0, 0),
	white = Color3.new(1, 1, 1),
	paper = Color3.fromRGB(231, 223, 202),
	paper2 = Color3.fromRGB(214, 203, 176),
	ink = Color3.fromRGB(34, 31, 28),
	manila = Color3.fromRGB(188, 152, 92),
	stamp = Color3.fromRGB(190, 24, 30),
}

local F = {
	title = Enum.Font.GothamBlack,
	bold = Enum.Font.GothamBold,
	body = Enum.Font.GothamMedium,
	mono = Enum.Font.RobotoMono,
	code = Enum.Font.Code,
	cond = Enum.Font.Oswald,
	osd = Enum.Font.Arcade,
}

-- цвет кабинок по сложности
local DIFF_COL = {
	easy = Color3.fromRGB(54, 209, 107),
	normal = Color3.fromRGB(255, 176, 0),
	hard = Color3.fromRGB(232, 38, 43),
	endless = Color3.fromRGB(176, 92, 255),
}

-- ===================== надёжность =====================
local warned = {}
local function warnOnce(tag, err)
	if warned[tag] then return end
	warned[tag] = true
	warn("[AA] UI " .. tostring(tag) .. ": " .. tostring(err))
end

local function safe(tag, fn, a, b, c, d)
	local ok, err = pcall(fn, a, b, c, d)
	if not ok then warnOnce(tag, err) end
	return ok, err
end

-- ===================== конструктор экземпляров =====================
local TEXTCLS = { TextLabel = true, TextButton = true, TextBox = true }

local function mk(class, parent, props)
	local o = Instance.new(class)
	if TEXTCLS[class] then
		o.BorderSizePixel = 0
		o.BackgroundTransparency = 1
		o.TextColor3 = COL.txt
		o.Font = F.body
		o.TextSize = 16
		o.Text = ""
	elseif class == "Frame" or class == "ScrollingFrame" or class == "ImageLabel" or class == "ImageButton" or class == "ViewportFrame" then
		o.BorderSizePixel = 0
	end
	if class == "TextButton" or class == "ImageButton" then o.AutoButtonColor = false end
	if props then
		for k, v in pairs(props) do o[k] = v end
	end
	if parent then o.Parent = parent end
	return o
end

local function frame(parent, props)
	local f = mk("Frame", parent, { BackgroundColor3 = COL.panel })
	if props then for k, v in pairs(props) do f[k] = v end end
	return f
end

local function clear(parent, keep)
	for _, ch in ipairs(parent:GetChildren()) do
		if not (keep and keep[ch.ClassName]) then ch:Destroy() end
	end
end

local function corner(o, r) return mk("UICorner", o, { CornerRadius = UDim.new(0, r or 6) }) end
local function round(o) return mk("UICorner", o, { CornerRadius = UDim.new(1, 0) }) end

local function stroke(o, color, th, tr, contextual)
	local s = mk("UIStroke", nil, { Color = color or COL.line, Thickness = th or 1, Transparency = tr or 0 })
	if not contextual then s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end
	s.Parent = o
	return s
end

local function pad(o, t, r, b, l)
	return mk("UIPadding", o, { PaddingTop = UDim.new(0, t or 0), PaddingRight = UDim.new(0, r or t or 0),
		PaddingBottom = UDim.new(0, b or t or 0), PaddingLeft = UDim.new(0, l or r or t or 0) })
end

local function vlist(o, gap, halign)
	return mk("UIListLayout", o, { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = halign or Enum.HorizontalAlignment.Left })
end

local function hlist(o, gap, valign, halign)
	return mk("UIListLayout", o, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = valign or Enum.VerticalAlignment.Center,
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left })
end

-- вертикальный/горизонтальный градиент цвета и прозрачности
local function grad(o, c0, c1, rot, t0, t1)
	return mk("UIGradient", o, {
		Color = ColorSequence.new(c0 or COL.white, c1 or c0 or COL.white),
		Transparency = NumberSequence.new(t0 or 0, t1 or t0 or 0),
		Rotation = rot or 90,
	})
end

local function textMax(o, maxSize, minSize)
	return mk("UITextSizeConstraint", o, { MaxTextSize = maxSize or 24, MinTextSize = minSize or 8 })
end

local function label(parent, text, size, font, color, props)
	local l = mk("TextLabel", parent, { Text = text or "", TextSize = size or 16, Font = font or F.body, TextColor3 = color or COL.txt })
	if props then for k, v in pairs(props) do l[k] = v end end
	return l
end

local function setText(l, s)
	if l and l.Text ~= s then l.Text = s end
end

local function tween(o, t, props, style, dir)
	local ok, tw = pcall(function()
		local x = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
		x:Play()
		return x
	end)
	if ok then return tw end
	for k, v in pairs(props) do pcall(function() o[k] = v end) end
	return nil
end

local function clamp01(x)
	x = tonumber(x) or 0
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

local function playSound(key, props)
	if Sound and Sound.play then pcall(Sound.play, key, nil, props) end
end

-- символы строки UTF-8 (для печатной машинки и глитча)
local function chars(s)
	local out = {}
	for _, cp in utf8.codes(s) do table.insert(out, utf8.char(cp)) end
	return out
end

local function utf8sub(s, n)
	local cut = utf8.offset(s, n + 1)
	if not cut then return s end
	return string.sub(s, 1, cut - 1)
end

local function ulen(s)
	return utf8.len(s) or #s
end

-- ===================== масштаб под экран =====================
local VW, VH = 1280, 720
local fits = {}
local isTouch = false

local function viewport()
	local cam = workspace.CurrentCamera
	if cam then
		local v = cam.ViewportSize
		if v and v.X > 10 and v.Y > 10 then VW, VH = v.X, v.Y end
	end
	return VW, VH
end

-- масштаб HUD: 1 при 1280×720, на телефонах меньше (но не мельче 0.5), сенсор — чуть крупнее
local function hudScaleValue()
	local s = math.min(VW / 1280, VH / 720)
	if isTouch then s = s * 1.12 end
	return math.clamp(s, 0.5, 1.25)
end

local function applyFit(f)
	local s
	if f.w then
		s = math.min(VW * f.fill / f.w, VH * f.fill / f.h, f.max)
	else
		s = hudScaleValue() * f.mul
	end
	f.s.Scale = math.max(s, 0.3)
end

-- окно эталонного размера w×h, вписанное в экран
local function fitScale(o, w, h, maxS, fill)
	local f = { s = mk("UIScale", o), w = w, h = h, max = maxS or 1.2, fill = fill or 0.94 }
	table.insert(fits, f)
	applyFit(f)
	return f.s
end

-- блок HUD с общим масштабом
local function hudScale(o, mul)
	local f = { s = mk("UIScale", o), mul = mul or 1 }
	table.insert(fits, f)
	applyFit(f)
	return f.s
end

local lastVW, lastVH = 0, 0
local function refit(force)
	viewport()
	if not force and VW == lastVW and VH == lastVH then return end
	lastVW, lastVH = VW, VH
	local alive = {}
	for _, f in ipairs(fits) do
		if f.s.Parent then
			applyFit(f)
			table.insert(alive, f)
		end
	end
	fits = alive
end

-- ===================== экраны (ScreenGui) =====================
local guis = {}

local function screen(name, order, ignoreInset)
	local g = mk("ScreenGui", nil, { Name = name, ResetOnSpawn = false, DisplayOrder = order or 0,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	g.IgnoreGuiInset = ignoreInset ~= false
	g.Parent = pgui
	return g
end

-- ===================== VHS-декор: сканлайны, зерно, виньетка =====================
-- сканлайны: n тонких полос по высоте родителя
local function addScanlines(parent, n, tr, z)
	local box = frame(parent, { Name = "Scan", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z or 50, ClipsDescendants = true })
	for i = 0, n - 1 do
		frame(box, { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, i / n), BackgroundColor3 = COL.black, BackgroundTransparency = tr or 0.85, ZIndex = z or 50 })
	end
	return box
end

-- «снег»: набор точек, которые каждый кадр прыгают в случайные места
local function makeGrain(parent, n, z)
	local g = { box = frame(parent, { Name = "Grain", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z or 51, ClipsDescendants = true }), dots = {} }
	for i = 1, n do
		local d = frame(g.box, { Size = UDim2.fromOffset(2, 2), BackgroundColor3 = COL.white, BackgroundTransparency = 0.8, ZIndex = z or 51 })
		g.dots[i] = d
	end
	return g
end

local rng = Random.new()
local function stepGrain(g, alpha, big)
	if not g or not g.box.Visible then return end
	for _, d in ipairs(g.dots) do
		local w = rng:NextInteger(1, big or 3)
		d.Size = UDim2.fromOffset(w * rng:NextInteger(1, 4), w)
		d.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
		local v = rng:NextNumber()
		d.BackgroundColor3 = Color3.new(v, v, v)
		d.BackgroundTransparency = 1 - (alpha or 0.25) * rng:NextNumber()
	end
end

-- виньетка из четырёх краёв с градиентом
local function addVignette(parent, color, depth, tr, z)
	local box = frame(parent, { Name = "Vignette", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z or 1 })
	local d = depth or 0.22
	local function edge(size, pos, rot)
		local e = frame(box, { Size = size, Position = pos, BackgroundColor3 = color or COL.black, BackgroundTransparency = 0, ZIndex = z or 1 })
		grad(e, color or COL.black, color or COL.black, rot, tr or 0.15, 1)
		return e
	end
	edge(UDim2.fromScale(1, d), UDim2.fromScale(0, 0), 90)
	edge(UDim2.fromScale(1, d), UDim2.fromScale(0, 1 - d), 270)
	edge(UDim2.fromScale(d * 0.75, 1), UDim2.fromScale(0, 0), 0)
	edge(UDim2.fromScale(d * 0.75, 1), UDim2.fromScale(1 - d * 0.75, 0), 180)
	return box
end

-- текст с хроматическим сдвигом (красный/голубой слой позади)
local function chromaLabel(parent, text, size, font, color, props, offset)
	local holder = frame(parent, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	if props then for k, v in pairs(props) do holder[k] = v end end
	local o = offset or 2
	local z = holder.ZIndex
	local r = label(holder, text, size, font, COL.red, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(-o, 0), TextTransparency = 0.35, ZIndex = z })
	local c = label(holder, text, size, font, COL.cyan, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(o, 0), TextTransparency = 0.45, ZIndex = z })
	local m = label(holder, text, size, font, color or COL.white, { Size = UDim2.fromScale(1, 1), ZIndex = z + 1 })
	local layers = { r, c, m }
	local api = { holder = holder, main = m, layers = layers, off = o }
	function api.set(s)
		for _, l in ipairs(layers) do setText(l, s) end
	end
	function api.prop(k, v)
		for _, l in ipairs(layers) do l[k] = v end
	end
	function api.jitter(amount)
		local a = amount or o
		r.Position = UDim2.fromOffset(-a + rng:NextInteger(-1, 1), rng:NextInteger(-1, 1))
		c.Position = UDim2.fromOffset(a + rng:NextInteger(-1, 1), rng:NextInteger(-1, 1))
	end
	return api
end

-- ===================== кнопки =====================
local BTN = {
	amber = { bg = Color3.fromRGB(255, 176, 0), fg = Color3.fromRGB(26, 16, 0), line = Color3.fromRGB(255, 213, 106) },
	red = { bg = Color3.fromRGB(200, 22, 28), fg = COL.white, line = Color3.fromRGB(255, 138, 141) },
	green = { bg = Color3.fromRGB(31, 157, 76), fg = COL.white, line = Color3.fromRGB(143, 240, 178) },
	dark = { bg = Color3.fromRGB(43, 47, 58), fg = COL.txt, line = Color3.fromRGB(90, 96, 112) },
	ghost = { bg = Color3.fromRGB(28, 30, 38), fg = COL.dim, line = Color3.fromRGB(70, 74, 88) },
}

local function setEnabled(b, on)
	b:SetAttribute("Off", not on)
	b.BackgroundTransparency = on and 0 or 0.55
	b.TextTransparency = on and 0 or 0.45
end

local function setStyle(b, style)
	local st = BTN[style] or BTN.dark
	b.BackgroundColor3 = st.bg
	b.TextColor3 = st.fg
	local s = b:FindFirstChildOfClass("UIStroke")
	if s then s.Color = st.line end
	b:SetAttribute("Style", style)
end

local function button(parent, text, style, onClick, props)
	local b = mk("TextButton", parent, { Text = text or "", Font = F.title, TextSize = 15, BackgroundTransparency = 0,
		Size = UDim2.fromOffset(160, 40), Selectable = true })
	corner(b, 4)
	stroke(b, COL.line, 1, 0.2)
	grad(b, COL.white, Color3.fromRGB(185, 185, 185), 90)
	setStyle(b, style or "dark")
	if props then for k, v in pairs(props) do b[k] = v end end
	local sc = mk("UIScale", b)
	b.MouseEnter:Connect(function()
		if not b:GetAttribute("Off") then tween(sc, 0.08, { Scale = 1.04 }) end
	end)
	b.MouseLeave:Connect(function() tween(sc, 0.1, { Scale = 1 }) end)
	b.Activated:Connect(function()
		if b:GetAttribute("Off") then return end
		playSound("UiClick", { Volume = 0.35 })
		sc.Scale = 0.95
		tween(sc, 0.12, { Scale = 1 })
		if onClick then
			task.spawn(function() safe("button", onClick, b) end)
		end
	end)
	return b
end

-- ===================== состояние =====================
local scene = "lobby"
local sceneData = {}
local openModals = {}       -- name -> { root, onClose }
local selectedKey = ""
local stamina, battery = 1, 1
local flashlightOn = false
local crosshairOn = true
local hiddenIn = nil
local deathText = nil
local spectating = nil
local updateMouse          -- объявлена ниже (модальные окна)
local MODAL_NAMES = { Shop = true, Classes = true, Dossier = true, Dossiers = true, Quests = true, Codes = true }

-- разделы интерфейса (каждый — свой набор функций ниже)
local Vhs, Hud, LobbyHud, Toasts, Eas, Loading, EndScr, Death, Qte, Prompts, Signs, Flash = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
local Screens = {}          -- модальные окна: name -> function(shell, arg)

-- ===================== данные матча и игрока =====================
local cachedId, cachedFolder = nil, nil
local function matchFolder()
	local id = player and player:GetAttribute("MatchId") or 0
	if not id or id == 0 then return nil end
	if cachedId == id and cachedFolder and cachedFolder.Parent then return cachedFolder end
	local ms = RS:FindFirstChild("Matches")
	local f = ms and ms:FindFirstChild("Match_" .. tostring(id))
	cachedId, cachedFolder = id, f
	return f
end

local function mattr(name, default)
	local f = matchFolder()
	local v = f and f:GetAttribute(name)
	if v == nil then return default end
	return v
end

local function pattr(name, default)
	local v = player and player:GetAttribute(name)
	if v == nil then return default end
	return v
end

local function inventory()
	local inv = player and player:FindFirstChild("Inventory")
	local out = {}
	if inv then
		for _, v in ipairs(inv:GetChildren()) do
			if v:IsA("IntValue") or v:IsA("NumberValue") then out[v.Name] = v.Value end
		end
	end
	return out
end

local function diffDef()
	local key = mattr("Difficulty", "normal")
	return (Config.Difficulties and Config.Difficulties[key]) or (Config.Difficulties and Config.Difficulties.normal) or {}, key
end

local function fmtClock(c)
	c = tonumber(c) or 7
	local h = math.floor(c) % 24
	local m = math.floor((c % 1) * 60)
	return string.format("%02d:%02d", h, m)
end

local function sortedKeys(t)
	local keys = {}
	for k in pairs(t or {}) do table.insert(keys, k) end
	table.sort(keys, function(a, b)
		local oa, ob = (t[a].order or 99), (t[b].order or 99)
		if oa == ob then return a < b end
		return oa < ob
	end)
	return keys
end

-- модуль заключённого из ReplicatedStorage.Inmates (может отсутствовать)
local inmateCache = {}
local function inmateDef(key)
	if not key or key == "" then return nil end
	if inmateCache[key] ~= nil then return inmateCache[key] or nil end
	local folder = RS:FindFirstChild("Inmates")
	local ms = folder and folder:FindFirstChild(key)
	local def = false
	if ms and ms:IsA("ModuleScript") then
		local ok, res = pcall(require, ms)
		if ok and type(res) == "table" then def = res else warnOnce("inmate " .. key, res) end
	end
	inmateCache[key] = def
	return def or nil
end

local function allInmates()
	local list = {}
	local folder = RS:FindFirstChild("Inmates")
	if not folder then return list end
	for _, ms in ipairs(folder:GetChildren()) do
		if ms:IsA("ModuleScript") then
			local def = inmateDef(ms.Name)
			if def then table.insert(list, { key = ms.Name, def = def }) end
		end
	end
	table.sort(list, function(a, b)
		local na, nb = tonumber(a.def.num) or 999, tonumber(b.def.num) or 999
		if na == nb then return a.key < b.key end
		return na < nb
	end)
	return list
end

local function remoteFunc(name)
	local ok, f = pcall(Net.func, name)
	if ok then return f end
	return nil
end

local function invoke(name, a, b)
	local f = remoteFunc(name)
	if not f then return nil end
	local ok, res = pcall(function() return f:InvokeServer(a, b) end)
	if not ok then
		warnOnce("invoke " .. name, res)
		return nil
	end
	return res
end

-- ===================== общий VHS-слой поверх мира =====================
-- тонкие сканлайны, зерно, виньетка, «полоса трекинга», которая медленно ползёт вниз
function Vhs.build()
	local g = guis.vhs
	Vhs.root = frame(g, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	addVignette(Vhs.root, COL.black, 0.2, 0.35, 1)
	Vhs.scan = addScanlines(Vhs.root, 180, 0.94, 2)
	Vhs.grain = makeGrain(Vhs.root, 36, 3)
	Vhs.band = frame(Vhs.root, { Size = UDim2.fromScale(1, 0.07), BackgroundColor3 = COL.white, ZIndex = 4 })
	mk("UIGradient", Vhs.band, { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.95), NumberSequenceKeypoint.new(1, 1) }) })
	Vhs.tint = frame(Vhs.root, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 190, 120), BackgroundTransparency = 0.985, ZIndex = 5 })
	Vhs.acc = 0
end

function Vhs.step(dt)
	if not Vhs.root then return end
	Vhs.acc = Vhs.acc + dt
	if Vhs.acc > 1 / 24 then
		Vhs.acc = 0
		stepGrain(Vhs.grain, 0.12)
	end
	local y = (T / 7) % 1.2 - 0.1
	Vhs.band.Position = UDim2.fromScale(0, y)
	Vhs.tint.BackgroundTransparency = 0.982 + 0.008 * math.sin(T * 31)
end

-- ===================== тосты =====================
function Toasts.build()
	local box = frame(guis.toast, { Name = "Toasts", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(700, 300), BackgroundTransparency = 1 })
	hudScale(box)
	vlist(box, 6, Enum.HorizontalAlignment.Center)
	Toasts.box = box
	Toasts.items = {}
	Toasts.n = 0
	Toasts.last, Toasts.lastT = "", -10
end

local TextService = nil
local function textWidth(text, size, font, maxW)
	if TextService == nil then
		local ok, s = pcall(function() return game:GetService("TextService") end)
		TextService = ok and s or false
	end
	if TextService then
		local ok, v = pcall(function() return TextService:GetTextSize(text, size, font, Vector2.new(maxW or 2000, 1000)) end)
		if ok and v then return v.X, v.Y end
	end
	local n = ulen(text)
	return math.min(n * size * 0.58, maxW or 2000), size + 4
end

function Toasts.push(text, color)
	if text == "" then return end
	-- одно и то же сообщение дважды подряд (двойная подписка) — не показываем
	if text == Toasts.last and T - Toasts.lastT < 0.3 then return end
	Toasts.last, Toasts.lastT = text, T
	local accent = COL.amber
	if typeof(color) == "Color3" then accent = color end
	Toasts.n = Toasts.n + 1
	local w, h = textWidth(text, 17, F.bold, 600)
	local item = frame(Toasts.box, { Size = UDim2.fromOffset(w + 46, math.max(40, h + 18)), BackgroundColor3 = Color3.fromRGB(10, 11, 15),
		BackgroundTransparency = 0.08, LayoutOrder = Toasts.n, ClipsDescendants = true })
	corner(item, 4)
	local st = stroke(item, accent, 1.5, 0.25)
	frame(item, { Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = accent })
	local glow = frame(item, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = accent, BackgroundTransparency = 0.88 })
	grad(glow, COL.white, COL.white, 0, 0.2, 1)
	local l = label(item, text, 17, F.bold, COL.txt, { Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(20, 0),
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
	stroke(l, COL.black, 1, 0.4, true)
	table.insert(Toasts.items, item)
	while #Toasts.items > 5 do
		local old = table.remove(Toasts.items, 1)
		old:Destroy()
	end
	local sc = mk("UIScale", item, { Scale = 0.85 })
	tween(sc, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(3.4, function()
		if not item.Parent then return end
		tween(item, 0.5, { BackgroundTransparency = 1 })
		tween(glow, 0.5, { BackgroundTransparency = 1 })
		tween(l, 0.5, { TextTransparency = 1 })
		tween(st, 0.5, { Transparency = 1 })
		task.delay(0.55, function()
			for i, it in ipairs(Toasts.items) do
				if it == item then table.remove(Toasts.items, i) break end
			end
			item:Destroy()
		end)
	end)
end

-- ===================== вспышки и скример-оверлей =====================
function Flash.build()
	local g = guis.fx
	Flash.plate = frame(g, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = COL.white, BackgroundTransparency = 1, ZIndex = 1 })
	local js = frame(g, { Size = UDim2.fromScale(1.1, 1.1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = COL.red, BackgroundTransparency = 1, ZIndex = 2, Visible = false })
	Flash.js = js
	Flash.jsVig = addVignette(js, Color3.fromRGB(60, 0, 0), 0.35, 0, 3)
	Flash.jsGrain = makeGrain(js, 90, 4)
	Flash.jsScan = addScanlines(js, 90, 0.6, 5)
	Flash.jsUntil = 0
	Flash.jsLen = 1
end

function Flash.flash(color, t0, seconds)
	local p = Flash.plate
	if not p then return end
	p.BackgroundColor3 = typeof(color) == "Color3" and color or COL.white
	p.BackgroundTransparency = clamp01(t0 or 0.2)
	tween(p, math.max(0.05, tonumber(seconds) or 0.4), { BackgroundTransparency = 1 })
end

function Flash.jumpscare(color, seconds)
	local js = Flash.js
	if not js then return end
	local len = math.max(0.2, tonumber(seconds) or 1.2)
	js.BackgroundColor3 = typeof(color) == "Color3" and color or COL.red
	js.Visible = true
	Flash.jsUntil = T + len
	Flash.jsLen = len
end

function Flash.step(dt)
	local js = Flash.js
	if not js or not js.Visible then return end
	local left = Flash.jsUntil - T
	if left <= 0 then
		js.Visible = false
		return
	end
	local k = left / Flash.jsLen
	-- красная пульсация, тряска и крупный «снег»
	js.BackgroundTransparency = 0.25 + 0.5 * (1 - k) + 0.2 * rng:NextNumber()
	js.Position = UDim2.new(0.5, rng:NextInteger(-14, 14), 0.5, rng:NextInteger(-10, 10))
	stepGrain(Flash.jsGrain, 0.9 * k + 0.1, 6)
end

-- ===================== HUD дома =====================
local PHASE_NAME = { loading = "ЗАГРУЗКА", day = "ДЕНЬ", alert = "ОПОВЕЩЕНИЕ", night = "НОЧЬ", dawn = "РАССВЕТ", ["end"] = "КОНЕЦ" }

-- полоска с подписью: возвращает { fill, value, box }
local function makeBar(parent, caption, color, order)
	local box = frame(parent, { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = order or 0 })
	local cap = label(box, caption, 11, F.mono, COL.dim, { Size = UDim2.new(0.6, 0, 0, 12), TextXAlignment = Enum.TextXAlignment.Left })
	local val = label(box, "", 11, F.mono, COL.txt, { Size = UDim2.new(0.4, 0, 0, 12), Position = UDim2.fromScale(0.6, 0), TextXAlignment = Enum.TextXAlignment.Right })
	local track = frame(box, { Size = UDim2.new(1, 0, 0, 9), Position = UDim2.fromOffset(0, 15), BackgroundColor3 = COL.black, BackgroundTransparency = 0.35 })
	corner(track, 2)
	stroke(track, COL.line, 1, 0.82)
	local fill = frame(track, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color })
	corner(fill, 2)
	grad(fill, COL.white, Color3.fromRGB(170, 170, 170), 90)
	-- деления, как на старом приборе
	for i = 1, 9 do
		frame(track, { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(i / 10, 0), BackgroundColor3 = COL.black, BackgroundTransparency = 0.5, ZIndex = 2 })
	end
	return { fill = fill, value = val, cap = cap, box = box, shown = 1 }
end

local function setBar(bar, frac, dt, color)
	frac = clamp01(frac)
	bar.shown = bar.shown + (frac - bar.shown) * math.min(1, (dt or 0.016) * 10)
	bar.fill.Size = UDim2.fromScale(bar.shown, 1)
	if color then bar.fill.BackgroundColor3 = color end
end

function Hud.build()
	local g = guis.hud
	Hud.root = frame(g, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })

	-- красная виньетка при низком здоровье (под всем остальным)
	Hud.lowVig = addVignette(Hud.root, Color3.fromRGB(150, 0, 0), 0.3, 0, 0)
	Hud.lowVig.Visible = false
	-- помехи: зерно и полосы поверх экрана
	Hud.staticFx = frame(Hud.root, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 120, 120), BackgroundTransparency = 1, Visible = false })
	Hud.staticGrain = makeGrain(Hud.staticFx, 70, 2)
	addScanlines(Hud.staticFx, 70, 0.75, 3)
	-- укрытие: тёмные края
	Hud.hideVig = addVignette(Hud.root, COL.black, 0.32, 0, 0)
	Hud.hideVig.Visible = false
	Hud.hideTxt = label(Hud.root, "В УКРЫТИИ · НЕ ШУМИ", 14, F.mono, COL.dim, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.fromOffset(400, 20), Visible = false })

	-- часы: ЖК-табло
	local clock = frame(Hud.root, { Name = "Clock", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(236, 92), BackgroundTransparency = 1 })
	hudScale(clock)
	local lcd = frame(clock, { Size = UDim2.fromOffset(236, 58), BackgroundColor3 = Color3.fromRGB(14, 10, 4), BackgroundTransparency = 0.12 })
	corner(lcd, 5)
	stroke(lcd, COL.amber, 1.5, 0.45)
	grad(lcd, Color3.fromRGB(255, 220, 160), COL.white, 90, 0, 0)
	label(lcd, "88:88", 44, F.code, COL.amberDim, { Size = UDim2.fromScale(1, 1), TextTransparency = 0.55 })
	Hud.time = label(lcd, "07:00", 44, F.code, COL.amber, { Size = UDim2.fromScale(1, 1) })
	stroke(Hud.time, COL.amber2, 3, 0.7, true)
	Hud.ampm = label(lcd, "", 10, F.mono, COL.amber, { Size = UDim2.fromOffset(30, 12), Position = UDim2.new(1, -34, 0, 6), TextXAlignment = Enum.TextXAlignment.Right })
	addScanlines(lcd, 18, 0.7, 5)
	local row = frame(clock, { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 62), BackgroundTransparency = 1 })
	hlist(row, 6, Enum.VerticalAlignment.Center, Enum.HorizontalAlignment.Center)
	local nightChip = frame(row, { Size = UDim2.fromOffset(112, 24), BackgroundColor3 = COL.black, BackgroundTransparency = 0.35, LayoutOrder = 1 })
	corner(nightChip, 3)
	Hud.nightStroke = stroke(nightChip, COL.line, 1, 0.75)
	Hud.night = label(nightChip, "НОЧЬ 1/7", 15, F.title, COL.txt, { Size = UDim2.fromScale(1, 1) })
	local phaseChip = frame(row, { Size = UDim2.fromOffset(112, 24), BackgroundColor3 = COL.black, BackgroundTransparency = 0.35, LayoutOrder = 2 })
	corner(phaseChip, 3)
	Hud.phaseChip = phaseChip
	Hud.phase = label(phaseChip, "ДЕНЬ", 13, F.mono, COL.amber, { Size = UDim2.fromScale(1, 1) })
	Hud.power = label(clock, "⚡ НЕТ СВЕТА", 13, F.title, COL.red, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 92), Visible = false })

	-- кошелёк (справа сверху, под системной панелью Roblox)
	local wallet = frame(Hud.root, { Name = "Wallet", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 58),
		Size = UDim2.fromOffset(300, 34), BackgroundTransparency = 1 })
	hudScale(wallet)
	hlist(wallet, 6, Enum.VerticalAlignment.Center, Enum.HorizontalAlignment.Right)
	local function chip(order, color)
		local c = frame(wallet, { Size = UDim2.fromOffset(104, 32), BackgroundColor3 = COL.black, BackgroundTransparency = 0.3, LayoutOrder = order })
		corner(c, 4)
		stroke(c, color, 1, 0.5)
		local l = label(c, "", 17, F.title, color, { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0) })
		return l, c
	end
	Hud.money, Hud.moneyChip = chip(1, COL.amber)
	Hud.apples, Hud.applesChip = chip(2, COL.txt)

	-- сводка оповещения (ночью)
	local ab = frame(Hud.root, { Name = "AlertBox", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 100),
		Size = UDim2.fromOffset(300, 110), BackgroundColor3 = Color3.fromRGB(16, 0, 0), BackgroundTransparency = 0.25, Visible = false })
	hudScale(ab)
	corner(ab, 4)
	stroke(ab, Color3.fromRGB(196, 18, 26), 1.5, 0.2)
	pad(ab, 8, 10, 8, 10)
	vlist(ab, 3)
	mk("UISizeConstraint", ab, { MaxSize = Vector2.new(300, 220) })
	ab.AutomaticSize = Enum.AutomaticSize.Y
	ab.Size = UDim2.fromOffset(300, 0)
	Hud.alertBox = ab
	Hud.alertTitle = label(ab, "", 14, F.title, Color3.fromRGB(255, 90, 90), { Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1 })
	Hud.alertTip = label(ab, "", 12, F.bold, COL.txt, { Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 })
	Hud.alertDir = label(ab, "", 12, F.bold, COL.amber, { Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 })

	-- здоровье, выносливость, батарея (слева снизу)
	local vit = frame(Hud.root, { Name = "Vitals", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(260, 118), BackgroundColor3 = COL.black, BackgroundTransparency = 0.45 })
	hudScale(vit)
	corner(vit, 5)
	stroke(vit, COL.line, 1, 0.85)
	pad(vit, 8, 10, 8, 10)
	vlist(vit, 4)
	Hud.hp = makeBar(vit, "❤ ЗДОРОВЬЕ", COL.ok, 1)
	Hud.st = makeBar(vit, "≫ ВЫНОСЛИВОСТЬ", COL.white, 2)
	Hud.bt = makeBar(vit, "🔦 БАТАРЕЯ", Color3.fromRGB(255, 216, 96), 3)
	Hud.vitals = vit

	-- помехи (появляются только при Static > 0)
	local sm = frame(Hud.root, { Name = "Static", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(260, 30), BackgroundColor3 = COL.black, BackgroundTransparency = 0.35, Visible = false })
	hudScale(sm)
	corner(sm, 4)
	Hud.staticStroke = stroke(sm, COL.line, 1, 0.6)
	pad(sm, 2, 8, 2, 8)
	Hud.staticBar = makeBar(sm, "📺 ПОМЕХИ", Color3.fromRGB(200, 200, 200), 1)
	Hud.staticMeter = sm

	-- хотбар
	local hb = frame(Hud.root, { Name = "Hotbar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(620, 66), BackgroundTransparency = 1 })
	hudScale(hb)
	hlist(hb, 6, Enum.VerticalAlignment.Bottom, Enum.HorizontalAlignment.Center)
	Hud.hotbar = hb
	Hud.slots = {}
	Hud.sig = ""
	Hud.itemName = label(Hud.root, "", 16, F.title, COL.amber, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -84),
		Size = UDim2.fromOffset(400, 22), TextTransparency = 1 })
	hudScale(Hud.itemName)
	stroke(Hud.itemName, COL.black, 1.5, 0.3, true)

	-- прицел
	Hud.cross = frame(Hud.root, { Name = "Cross", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(6, 6), BackgroundColor3 = COL.white, BackgroundTransparency = 0.1 })
	round(Hud.cross)
	stroke(Hud.cross, COL.black, 1.5, 0.45)

	Hud.textT = 0
	Hud.alertInfo = nil
end

function Hud.onEnter(data)
	Hud.alertInfo = nil
	Hud.sig = ""
	selectedKey = pattr("Equipped", "") or ""
end

-- ключи предметов для хотбара: по порядку магазина, патроны показываем на дробовике
function Hud.slotKeys()
	local inv = inventory()
	local keys = {}
	for _, k in ipairs(sortedKeys(Config.Items)) do
		local it = Config.Items[k]
		if k ~= "shells" and not it.farm and (inv[k] or 0) > 0 then table.insert(keys, k) end
	end
	-- предметы, которых нет в Config.Items, — в конец
	for k, n in pairs(inv) do
		if not Config.Items[k] and n > 0 then table.insert(keys, k) end
	end
	while #keys > 9 do table.remove(keys) end
	return keys, inv
end

local function equipItem(key)
	local target = key
	if selectedKey == key then target = "" end
	local C = ctx and ctx.Controls
	if C and type(C.equip) == "function" then
		safe("controls equip", C.equip, target)
		return
	end
	pcall(function() Net.event("Action"):FireServer("equip", target) end)
	UI.setSelected(target)
end

function Hud.rebuildHotbar(keys, inv)
	for _, s in pairs(Hud.slots) do s.frame:Destroy() end
	Hud.slots = {}
	for i, k in ipairs(keys) do
		local it = Config.Items[k] or {}
		local f = mk("TextButton", Hud.hotbar, { Size = UDim2.fromOffset(62, 62), BackgroundColor3 = Color3.fromRGB(18, 20, 25),
			BackgroundTransparency = 0.25, LayoutOrder = i, Text = "" })
		corner(f, 5)
		local st = stroke(f, COL.line, 1.5, 0.75)
		grad(f, COL.white, Color3.fromRGB(150, 150, 160), 90)
		label(f, it.icon or "❔", 30, F.body, COL.white, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, -2) })
		label(f, tostring(i), 11, F.mono, COL.dim, { Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(4, 2), TextXAlignment = Enum.TextXAlignment.Left })
		local n = inv[k] or 0
		local cnt = ""
		if k == "shotgun" then cnt = tostring(inv.shells or 0) .. "🧨" elseif n > 1 then cnt = "×" .. tostring(n) end
		local cl = label(f, cnt, 13, F.title, COL.txt, { Size = UDim2.fromOffset(52, 14), Position = UDim2.new(1, -56, 1, -17), TextXAlignment = Enum.TextXAlignment.Right })
		stroke(cl, COL.black, 1, 0.3, true)
		local sc = mk("UIScale", f)
		f.Activated:Connect(function() equipItem(k) end)
		Hud.slots[k] = { frame = f, stroke = st, scale = sc }
	end
	Hud.markSelected()
end

function Hud.markSelected()
	for k, s in pairs(Hud.slots or {}) do
		local on = (k == selectedKey)
		s.stroke.Color = on and COL.amber or COL.line
		s.stroke.Transparency = on and 0 or 0.75
		s.stroke.Thickness = on and 2.5 or 1.5
		s.frame.BackgroundColor3 = on and Color3.fromRGB(60, 44, 8) or Color3.fromRGB(18, 20, 25)
		tween(s.scale, 0.12, { Scale = on and 1.08 or 1 })
	end
	if Hud.itemName then
		local it = Config.Items and Config.Items[selectedKey]
		if it then
			Hud.itemName.Text = it.name
			Hud.itemName.TextTransparency = 0
			Hud.nameT = T
		else
			Hud.itemName.TextTransparency = 1
		end
	end
end

function Hud.setAlertInfo(info)
	Hud.alertInfo = info
end

function Hud.step(dt)
	local phase = mattr("Phase", "day")
	local alive = pattr("Alive", true)
	local hidden = pattr("Hidden", false) or hiddenIn ~= nil

	-- здоровье с персонажа
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local hpFrac, hp = 1, 100
	if hum and hum.MaxHealth > 0 then
		hp = math.max(0, hum.Health)
		hpFrac = hp / hum.MaxHealth
	end
	local hpCol = COL.ok
	if hpFrac < 0.35 then hpCol = COL.red elseif hpFrac < 0.65 then hpCol = COL.amber end
	setBar(Hud.hp, hpFrac, dt, hpCol)
	setBar(Hud.st, stamina, dt, stamina < 0.25 and COL.red or COL.white)
	setBar(Hud.bt, battery, dt, flashlightOn and Color3.fromRGB(255, 216, 96) or Color3.fromRGB(140, 120, 60))
	Hud.vitals.Visible = alive

	-- низкое здоровье: пульсирующая красная виньетка
	local low = alive and hpFrac < 0.35
	Hud.lowVig.Visible = low
	if low then
		local pulse = 0.5 + 0.5 * math.sin(T * (4 + (1 - hpFrac) * 6))
		for _, e in ipairs(Hud.lowVig:GetChildren()) do
			local gr = e:FindFirstChildOfClass("UIGradient")
			if gr then gr.Transparency = NumberSequence.new(0.1 + 0.35 * pulse + hpFrac, 1) end
		end
	end

	-- помехи
	local stat = tonumber(pattr("Static", 0)) or 0
	Hud.staticMeter.Visible = alive and stat > 0
	if stat > 0 then
		local hot = stat >= 70
		local flick = hot and (math.floor(T * 6) % 2 == 0)
		setBar(Hud.staticBar, stat / 100, dt, hot and COL.red or Color3.fromRGB(200, 200, 200))
		Hud.staticStroke.Color = flick and COL.red or COL.line
	end
	local sfx = math.max(0, (stat - 30) / 100)
	Hud.staticFx.Visible = alive and sfx > 0
	if sfx > 0 then
		Hud.staticFx.BackgroundTransparency = 1 - sfx * 0.25 * rng:NextNumber()
		stepGrain(Hud.staticGrain, math.min(0.9, sfx * 1.6), 5)
	end

	-- укрытие
	Hud.hideVig.Visible = hidden
	Hud.hideTxt.Visible = hidden

	-- прицел
	local promptOn = Prompts.current ~= nil
	Hud.cross.Visible = crosshairOn and alive and not hidden and not UI.anyModal()
	local cs = promptOn and 10 or 6
	Hud.cross.Size = UDim2.fromOffset(cs, cs)
	Hud.cross.BackgroundColor3 = promptOn and COL.amber or COL.white

	-- подпись предмета гаснет через 1.5 с
	if Hud.nameT and T - Hud.nameT > 1.5 and Hud.itemName.TextTransparency < 1 then
		Hud.itemName.TextTransparency = math.min(1, Hud.itemName.TextTransparency + dt * 2)
	end

	-- тексты обновляем 8 раз в секунду
	Hud.textT = Hud.textT + dt
	if Hud.textT < 0.125 then return end
	Hud.textT = 0

	local clock = mattr("Clock", 7)
	local s = fmtClock(clock)
	if math.floor(T * 2) % 2 == 1 then s = string.gsub(s, ":", " ") end
	setText(Hud.time, s)
	local night = mattr("Night", 1)
	local nights = mattr("Nights", 7)
	local d = diffDef()
	local nt = "НОЧЬ " .. tostring(night)
	if not d.endless and nights and nights < 1000 then nt = nt .. "/" .. tostring(nights) end
	setText(Hud.night, nt)
	local isNight = (phase == "night" or phase == "alert")
	Hud.night.TextColor3 = isNight and Color3.fromRGB(255, 74, 74) or COL.txt
	Hud.nightStroke.Color = isNight and COL.red or COL.line
	setText(Hud.phase, PHASE_NAME[phase] or string.upper(tostring(phase)))
	Hud.phase.TextColor3 = isNight and Color3.fromRGB(255, 110, 110) or COL.amber
	Hud.power.Visible = mattr("Power", true) == false

	setText(Hud.money, "$ " .. tostring(pattr("Money", 0)))
	setText(Hud.apples, "🍎 " .. tostring(pattr("Apples", 0)) .. "/" .. tostring(Config.MaxApplesCarried or 14))

	-- сводка оповещения: в фазе ночи, пока не рассвело
	local info = Hud.alertInfo
	if info and (phase == "day" or phase == "dawn") then Hud.alertInfo = nil info = nil end
	Hud.alertBox.Visible = info ~= nil and (phase == "night" or phase == "alert") and not Eas.visible
	if info then
		setText(Hud.alertTitle, info.title)
		setText(Hud.alertTip, info.tip)
		local dt2 = mattr("DirectiveText", "")
		if info.directive and info.directive ~= "" then dt2 = info.directive end
		setText(Hud.alertDir, (dt2 ~= "" and ("📺 ДИРЕКТИВА: " .. dt2)) or "")
		Hud.alertDir.Visible = dt2 ~= ""
	end

	-- хотбар: пересобираем при изменении инвентаря
	local keys, inv = Hud.slotKeys()
	local sig = {}
	for _, k in ipairs(keys) do table.insert(sig, k .. "=" .. tostring(inv[k])) end
	local sigs = table.concat(sig, ",") .. "|" .. tostring(inv.shells or 0)
	if sigs ~= Hud.sig then
		Hud.sig = sigs
		Hud.rebuildHotbar(keys, inv)
	end
	local eq = pattr("Equipped", nil)
	if eq ~= nil and eq ~= Hud.lastEq then
		Hud.lastEq = eq
		if eq ~= selectedKey then
			selectedKey = eq
			Hud.markSelected()
		end
	end
end

-- @@LOBBYHUD@@
function LobbyHud.build() end
function LobbyHud.onEnter() end
function LobbyHud.step(dt) end

-- @@SIGNS@@
function Signs.init() end
function Signs.step(dt) end

-- ===================== экстренное оповещение (EAS) =====================
-- Вступление: настроечная таблица и тон. Затем мигающая шапка, эмблема, карточка заключённого,
-- печатная машинка с текстом, совет, бегущая строка, полоса времени. Поверх — VHS: сканлайны,
-- зерно, мерцание, разрывы строк и цветовой сдвиг.
Eas.visible = false
local GLITCH = chars("#%&@$?!░▒▓█<>/\\=+*")
local SMPTE = { Color3.fromRGB(192, 192, 192), Color3.fromRGB(192, 192, 0), Color3.fromRGB(0, 192, 192), Color3.fromRGB(0, 192, 0),
	Color3.fromRGB(192, 0, 192), Color3.fromRGB(192, 0, 0), Color3.fromRGB(0, 0, 192) }

local function spaced(s)
	return table.concat(chars(s), " ")
end

function Eas.build()
	local g = guis.eas
	g.Enabled = false
	local root = frame(g, { Name = "EAS", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(3, 4, 8), Active = true })
	Eas.root = root
	grad(root, Color3.fromRGB(30, 34, 60), COL.black, 90)

	-- сцена 1280×720, вписанная в экран
	local st = frame(root, { Name = "Stage", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1280, 720), BackgroundTransparency = 1 })
	fitScale(st, 1280, 720, 2.2, 1)
	Eas.stage = st

	-- шапка
	local hdr = frame(st, { Name = "Header", Size = UDim2.fromOffset(1280, 118), BackgroundColor3 = Color3.fromRGB(196, 18, 26) })
	grad(hdr, COL.white, Color3.fromRGB(150, 150, 150), 90)
	Eas.hdr = hdr
	Eas.hdrTitle = chromaLabel(hdr, "⚠ ЭКСТРЕННОЕ ОПОВЕЩЕНИЕ ⚠", 54, F.title, COL.white,
		{ Size = UDim2.fromOffset(1280, 70), Position = UDim2.fromOffset(0, 10) }, 3)
	Eas.hdrSub = label(hdr, spaced("EMERGENCY ALERT SYSTEM"), 22, F.code, COL.white, { Size = UDim2.fromOffset(1280, 28), Position = UDim2.fromOffset(0, 80) })
	frame(st, { Size = UDim2.fromOffset(1280, 4), Position = UDim2.fromOffset(0, 118), BackgroundColor3 = COL.amber })

	-- эмблема
	local em = frame(st, { Name = "Emblem", Size = UDim2.fromOffset(250, 250), Position = UDim2.fromOffset(60, 146), BackgroundTransparency = 1 })
	Eas.emblem = em
	local logo = Config.Images and Config.Images.EasLogo or ""
	if logo ~= "" then
		local url = tostring(logo)
		if tonumber(logo) then url = "rbxassetid://" .. tostring(logo) end
		mk("ImageLabel", em, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = url, ScaleType = Enum.ScaleType.Fit })
	else
		local disc = frame(em, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 12, 24) })
		round(disc)
		stroke(disc, COL.amber, 6, 0)
		grad(disc, Color3.fromRGB(60, 70, 120), COL.black, 90)
		local inner = frame(em, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.7), BackgroundColor3 = Color3.fromRGB(150, 10, 16) })
		round(inner)
		stroke(inner, COL.white, 3, 0.1)
		grad(inner, Color3.fromRGB(255, 120, 120), COL.white, 90)
		-- треугольник гражданской обороны из трёх «лучей»
		for i = 0, 2 do
			frame(inner, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 8, 0.42, 0),
				BackgroundColor3 = COL.amber, Rotation = i * 120, BackgroundTransparency = 0.25 })
		end
		local eas = label(inner, "EAS", 58, F.title, COL.white, { Size = UDim2.fromScale(1, 1) })
		stroke(eas, COL.black, 3, 0.2, true)
		label(em, "CIVIL DEFENSE", 13, F.code, COL.amber, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 0, 22) })
		label(em, "ASHGROVE", 13, F.code, COL.amber, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -38) })
	end
	-- вращающиеся риски вокруг эмблемы
	Eas.ticks = {}
	for i = 1, 24 do
		local t = frame(em, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(4, 12), BackgroundColor3 = COL.amber, BackgroundTransparency = 0.3 })
		Eas.ticks[i] = t
	end

	-- карточка заключённого
	local card0 = frame(st, { Name = "Inmate", Size = UDim2.fromOffset(300, 236), Position = UDim2.fromOffset(36, 404), BackgroundColor3 = Color3.fromRGB(8, 8, 12), BackgroundTransparency = 0.1 })
	corner(card0, 4)
	Eas.cardStroke = stroke(card0, COL.red, 2, 0)
	frame(card0, { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = COL.red })
	label(card0, "РАЗЫСКИВАЕТСЯ · WANTED", 16, F.title, COL.white, { Size = UDim2.new(1, 0, 0, 30) })
	Eas.num = label(card0, "№ 102", 40, F.code, COL.amber, { Size = UDim2.new(1, -20, 0, 46), Position = UDim2.fromOffset(10, 34), TextXAlignment = Enum.TextXAlignment.Left })
	stroke(Eas.num, COL.amber2, 2, 0.7, true)
	Eas.name = chromaLabel(card0, "ГЛАДИС", 38, F.title, COL.white, { Size = UDim2.new(1, -20, 0, 46), Position = UDim2.fromOffset(10, 80) }, 2)
	Eas.name.prop("TextXAlignment", Enum.TextXAlignment.Left)
	Eas.name.prop("TextScaled", true)
	for _, l in ipairs(Eas.name.layers) do textMax(l, 38, 14) end
	Eas.en = label(card0, "GLADYS", 16, F.code, COL.dim, { Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 128), TextXAlignment = Enum.TextXAlignment.Left })
	Eas.cls = label(card0, "", 15, F.bold, Color3.fromRGB(255, 120, 120), { Size = UDim2.new(1, -20, 0, 76), Position = UDim2.fromOffset(10, 152),
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true })

	-- текст оповещения (печатная машинка)
	local box = frame(st, { Name = "Crawl", Size = UDim2.fromOffset(880, 352), Position = UDim2.fromOffset(364, 146), BackgroundColor3 = Color3.fromRGB(4, 6, 14), BackgroundTransparency = 0.15 })
	corner(box, 4)
	stroke(box, COL.line, 1, 0.8)
	pad(box, 16, 20, 16, 20)
	Eas.crawl = label(box, "", 23, F.mono, COL.txt, { Size = UDim2.fromScale(1, 1), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.15 })
	textMax(Eas.crawl, 23, 10)
	Eas.crawl.TextScaled = true
	stroke(Eas.crawl, Color3.fromRGB(120, 160, 255), 2, 0.85, true)

	-- что делать
	local tip = frame(st, { Name = "Tip", Size = UDim2.fromOffset(880, 100), Position = UDim2.fromOffset(364, 510), BackgroundColor3 = Color3.fromRGB(30, 20, 0), BackgroundTransparency = 0.1 })
	corner(tip, 4)
	stroke(tip, COL.amber, 2, 0)
	frame(tip, { Size = UDim2.new(0, 160, 1, 0), BackgroundColor3 = COL.amber })
	label(tip, "ЧТО\nДЕЛАТЬ", 26, F.title, COL.black, { Size = UDim2.new(0, 160, 1, 0) })
	Eas.tip = label(tip, "", 22, F.bold, COL.amber, { Size = UDim2.new(1, -190, 0, 54), Position = UDim2.fromOffset(176, 8), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextScaled = true })
	textMax(Eas.tip, 22, 10)
	Eas.dir = label(tip, "", 17, F.bold, Color3.fromRGB(255, 96, 96), { Size = UDim2.new(1, -190, 0, 30), Position = UDim2.fromOffset(176, 64), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
	textMax(Eas.dir, 17, 9)

	-- бегущая строка и полоса времени
	local tick0 = frame(st, { Name = "Ticker", Size = UDim2.fromOffset(1280, 34), Position = UDim2.fromOffset(0, 646), BackgroundColor3 = Color3.fromRGB(150, 8, 14), ClipsDescendants = true })
	Eas.ticker = label(tick0, "", 20, F.title, COL.white, { Size = UDim2.fromOffset(4000, 34), TextXAlignment = Enum.TextXAlignment.Left })
	local bar = frame(st, { Name = "Bar", Size = UDim2.fromOffset(1280, 40), Position = UDim2.fromOffset(0, 680), BackgroundColor3 = Color3.fromRGB(70, 48, 0) })
	Eas.fill = frame(bar, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = COL.amber })
	grad(Eas.fill, COL.white, Color3.fromRGB(200, 200, 200), 90)
	label(bar, "STAY INSIDE · ASHGROVE ASYLUM", 17, F.title, COL.black, { Size = UDim2.new(0.6, -20, 1, 0), Position = UDim2.fromOffset(20, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 })
	Eas.left = label(bar, "", 17, F.title, COL.black, { Size = UDim2.new(0.4, -20, 1, 0), Position = UDim2.fromScale(0.6, 0), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 2 })

	-- экранное меню видеомагнитофона
	Eas.osdPlay = label(st, "▶ PLAY", 26, F.osd, COL.white, { Size = UDim2.fromOffset(200, 30), Position = UDim2.fromOffset(24, 128), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 20 })
	stroke(Eas.osdPlay, COL.black, 2, 0.3, true)
	Eas.osdTime = label(st, "", 22, F.osd, COL.white, { Size = UDim2.fromOffset(520, 26), Position = UDim2.fromOffset(736, 616), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 20 })
	stroke(Eas.osdTime, COL.black, 2, 0.3, true)

	-- настроечная таблица (первые секунды)
	local bars = frame(root, { Name = "Bars", Size = UDim2.fromScale(1, 1), BackgroundColor3 = COL.black, ZIndex = 30 })
	for i, c in ipairs(SMPTE) do
		frame(bars, { Size = UDim2.fromScale(1 / 7, 0.72), Position = UDim2.fromScale((i - 1) / 7, 0), BackgroundColor3 = c, ZIndex = 30 })
	end
	for i = 1, 7 do
		local c = SMPTE[8 - i]
		if i % 2 == 0 then c = COL.black end
		frame(bars, { Size = UDim2.fromScale(1 / 7, 0.08), Position = UDim2.fromScale((i - 1) / 7, 0.72), BackgroundColor3 = c, ZIndex = 30 })
	end
	frame(bars, { Size = UDim2.fromScale(1, 0.2), Position = UDim2.fromScale(0, 0.8), BackgroundColor3 = Color3.fromRGB(12, 12, 16), ZIndex = 30 })
	local sb = label(bars, "ВНИМАНИЕ · ВНИМАНИЕ · ВНИМАНИЕ", 30, F.title, COL.white, { Size = UDim2.fromScale(1, 0.2), Position = UDim2.fromScale(0, 0.8), ZIndex = 31, TextScaled = true })
	textMax(sb, 34, 10)
	Eas.bars = bars

	-- VHS поверх всего
	Eas.scan = addScanlines(root, 200, 0.82, 40)
	Eas.grain = makeGrain(root, 60, 41)
	Eas.roll = frame(root, { Size = UDim2.fromScale(1, 0.12), BackgroundColor3 = COL.white, ZIndex = 42 })
	mk("UIGradient", Eas.roll, { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 1) }) })
	Eas.tear = frame(root, { Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = COL.white, BackgroundTransparency = 0.7, ZIndex = 43, Visible = false })
	Eas.flick = frame(root, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = COL.white, BackgroundTransparency = 1, ZIndex = 44 })
	addVignette(root, COL.black, 0.16, 0.2, 39)

	-- скрыть (освобождает мышь)
	local hideBtn = button(root, "СКРЫТЬ ✕", "ghost", function() Eas.hide() end, { AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 60), Size = UDim2.fromOffset(120, 34), TextSize = 13, ZIndex = 50, Modal = true })
	hudScale(hideBtn)
	Eas.hideBtn = hideBtn
end

function Eas.show(data)
	if not Eas.root then return end
	-- то же оповещение второй раз (двойная подписка) — пропускаем
	if Eas.visible and Eas.data == data then return end
	Eas.data = data
	local def = inmateDef(data.inmate)
	local unknown = data.unknown and true or false
	Eas.unknown = unknown

	-- текст
	local lines = {}
	local src = data.lines
	if (not src or #src == 0) and unknown then src = Config.AlertUnknown end
	if (not src or #src == 0) and def and def.alert then src = def.alert end
	local head = Config.AlertHead or ""
	if head ~= "" and not (src and src[1] == head) then table.insert(lines, head) end
	for _, l in ipairs(src or {}) do table.insert(lines, tostring(l)) end
	Eas.full = table.concat(lines, "\n\n")
	Eas.fullLen = ulen(Eas.full)
	Eas.typed = 0
	Eas.crawl.Text = ""

	-- карточка
	local num = data.num or (def and def.num) or "???"
	local name = data.name or (def and def.name) or "???"
	local en = (def and def.en) or ""
	local cls = data.threat or (def and def.class) or ""
	local tip = data.tip or (def and def.tip) or ""
	if unknown then
		num, name, en = "???", "НЕИЗВЕСТЕН", "UNKNOWN"
		cls = "КЛАСС УГРОЗЫ: НЕИЗВЕСТЕН. СИЛЬНАЯ ПОТЕРЯ СИГНАЛА."
		if tip == "" then tip = "Оставайтесь в помещении. Прячьтесь и не шумите." end
	end
	Eas.nameChars = chars(name)
	Eas.nameStr = name
	setText(Eas.num, "№ " .. tostring(num))
	Eas.name.set(name)
	Eas.name.prop("TextColor3", COL.white)
	Eas.name.main.TextColor3 = unknown and Color3.fromRGB(255, 70, 70) or COL.white
	setText(Eas.en, en ~= "" and (unknown and en or ("INMATE " .. tostring(num) .. " · " .. en)) or "")
	setText(Eas.cls, cls)
	setText(Eas.tip, tip ~= "" and tip or "Слушайте указания и не выходите на улицу.")
	local dir = data.directive
	local dirText = ""
	if type(dir) == "table" and dir.text then
		dirText = "📺 ДИРЕКТИВА: " .. tostring(dir.text)
	end
	setText(Eas.dir, dirText)
	Eas.dir.Visible = dirText ~= ""
	local ticker = string.gsub(table.concat(lines, "   •   "), "\n", " ")
	Eas.ticker.Text = "   •   " .. ticker .. "   •   " .. ticker
	Eas.tickW = textWidth("   •   " .. ticker, 20, F.title, 100000)
	Eas.ticker.Size = UDim2.fromOffset(Eas.tickW * 2 + 40, 34)

	Eas.duration = math.max(4, tonumber(data.duration) or (Config.Time and Config.Time.alertSeconds) or 34)
	Eas.t0 = T
	Eas.sawAlert = false
	Eas.intro = 1.3
	-- скорость печати: весь текст — за ~55% времени
	Eas.cps = math.max(26, Eas.fullLen / math.max(1, (Eas.duration - Eas.intro) * 0.55))

	-- сводка в HUD на ночь
	local title = "⚠ " .. tostring(name) .. " · №" .. tostring(num)
	if unknown then title = "⚠ НЕИЗВЕСТНЫЙ СУБЪЕКТ" end
	Hud.setAlertInfo({ title = title, tip = unknown and "Сигнал потерян. Прячься и не шуми." or tip,
		directive = (type(dir) == "table" and dir.text) or "" })

	Eas.visible = true
	guis.eas.Enabled = true
	Eas.bars.Visible = true
	Eas.root.Visible = true
	for n in pairs(openModals) do UI.close(n) end
	if Eas.tone then pcall(function() Eas.tone:Destroy() end) end
	Eas.tone = nil
	if Sound and Sound.play then
		local ok, s = pcall(Sound.play, "EasTone", nil, { Volume = 0.5 })
		if ok then Eas.tone = s end
	end
	updateMouse()
end

function Eas.hide(instant)
	if not Eas.visible then return end
	Eas.visible = false
	if Eas.tone then pcall(function() Eas.tone:Stop() Eas.tone:Destroy() end) end
	Eas.tone = nil
	if instant or not Eas.flick then
		guis.eas.Enabled = false
	else
		-- «выключение» телевизора: белая вспышка и гаснет
		Eas.flick.BackgroundTransparency = 0.2
		tween(Eas.flick, 0.25, { BackgroundTransparency = 1 })
		task.delay(0.22, function()
			if not Eas.visible then guis.eas.Enabled = false end
		end)
	end
	updateMouse()
end

function Eas.step(dt)
	local el = T - Eas.t0
	local phase = mattr("Phase", "")
	if phase == "alert" then Eas.sawAlert = true end
	if el > Eas.duration + 0.6 or (Eas.sawAlert and phase ~= "alert" and phase ~= "") then
		Eas.hide()
		return
	end
	-- вступление: таблица
	Eas.bars.Visible = el < Eas.intro
	-- шапка мигает красным/чёрным
	local on = math.floor(el * 2) % 2 == 0
	Eas.hdr.BackgroundColor3 = on and Color3.fromRGB(196, 18, 26) or Color3.fromRGB(8, 8, 10)
	Eas.hdrTitle.main.TextColor3 = on and COL.white or Color3.fromRGB(255, 40, 40)
	Eas.hdrSub.TextColor3 = on and COL.white or COL.amber
	Eas.cardStroke.Color = on and COL.red or COL.amber
	Eas.hdrTitle.jitter(2 + (rng:NextNumber() < 0.1 and 5 or 0))
	Eas.name.jitter(2)

	-- риски вокруг эмблемы
	for i, t in ipairs(Eas.ticks) do
		local a = (i / #Eas.ticks) * math.pi * 2 + el * 0.6
		t.Position = UDim2.new(0.5, math.cos(a) * 140, 0.5, math.sin(a) * 140)
		t.Rotation = math.deg(a) + 90
		t.BackgroundTransparency = (i % 2 == 0) and 0.2 or 0.6
	end

	-- печатная машинка
	if el > Eas.intro and Eas.typed < Eas.fullLen then
		Eas.typed = math.min(Eas.fullLen, Eas.typed + Eas.cps * dt)
	end
	local n = math.floor(Eas.typed)
	local s = utf8sub(Eas.full, n)
	if n < Eas.fullLen or math.floor(T * 2.5) % 2 == 0 then s = s .. "█" end
	setText(Eas.crawl, s)

	-- «НЕИЗВЕСТЕН» — глитч
	if Eas.unknown and rng:NextNumber() < 0.5 then
		local cs = {}
		for i, ch in ipairs(Eas.nameChars) do
			if rng:NextNumber() < 0.22 then cs[i] = GLITCH[rng:NextInteger(1, #GLITCH)] else cs[i] = ch end
		end
		Eas.name.set(table.concat(cs))
		Eas.name.jitter(rng:NextInteger(2, 7))
	end

	-- бегущая строка
	local w = Eas.tickW or 1000
	Eas.ticker.Position = UDim2.fromOffset(-((el * 110) % w), 0)
	-- полоса времени
	local frac = clamp01(el / Eas.duration)
	Eas.fill.Size = UDim2.fromScale(frac, 1)
	setText(Eas.left, "НОЧЬ НАСТУПИТ ЧЕРЕЗ " .. tostring(math.max(0, math.ceil(Eas.duration - el))) .. " С")
	-- экранное меню
	local secs = math.floor(el)
	setText(Eas.osdTime, string.format("SP  0:00:%02d   OCT.31.1994  %s", secs % 60, fmtClock(mattr("Clock", 21))))
	Eas.osdPlay.TextTransparency = (math.floor(el * 1.5) % 2 == 0) and 0 or 0.4

	-- VHS: зерно, бегущая полоса, мерцание, разрывы
	stepGrain(Eas.grain, 0.35, 4)
	Eas.roll.Position = UDim2.fromScale(0, (el / 3.5) % 1.3 - 0.15)
	Eas.flick.BackgroundTransparency = math.max(Eas.flick.BackgroundTransparency, 0.96 + 0.04 * rng:NextNumber())
	if rng:NextNumber() < 0.025 then
		Eas.tear.Visible = true
		Eas.tear.Position = UDim2.new(0, 0, rng:NextNumber(), 0)
		Eas.stage.Position = UDim2.new(0.5, rng:NextInteger(-14, 14), 0.5, 0)
	elseif Eas.tear.Visible and rng:NextNumber() < 0.5 then
		Eas.tear.Visible = false
		Eas.stage.Position = UDim2.fromScale(0.5, 0.5)
	end
end

-- ===================== загрузка: перемотка кассеты =====================
Loading.visible = false
local TIPS = {
	"Днём собирай яблоки во дворе и продавай их Яблочнику в гараже.",
	"В 21:00 включится телевизор. Слушай оповещение — оно говорит, как выжить.",
	"Запертая дверь задержит заключённого. Держи R у двери.",
	"Бег шумный. Присядь (C), чтобы двигаться тихо.",
	"Шкафы спасают, но не от всех. Читай досье в лечебнице.",
	"Фонарик садится. Запасные батарейки — в магазине.",
	"Рассвет оживляет погибших товарищей.",
	"Щиток в гараже. Без света в доме страшнее.",
	"Директива из оповещения действует всю ночь. Не нарушай её.",
}

function Loading.build()
	local root = frame(guis.full, { Name = "Loading", Size = UDim2.fromScale(1, 1), BackgroundColor3 = COL.black, Visible = false, Active = true, ZIndex = 10 })
	Loading.root = root
	local st = frame(root, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1280, 720), BackgroundTransparency = 1, ZIndex = 10 })
	fitScale(st, 1280, 720, 2, 1)
	Loading.stage = st
	Loading.logo = chromaLabel(st, "ASHGROVE", 120, F.title, COL.white, { Size = UDim2.fromOffset(1280, 140), Position = UDim2.fromOffset(0, 230), ZIndex = 12 }, 4)
	stroke(Loading.logo.main, COL.amber, 4, 0.75, true)
	label(st, spaced("ЛЕЧЕБНИЦА · ОКРУГ ЭМБЕР"), 22, F.code, COL.amber, { Size = UDim2.fromOffset(1280, 30), Position = UDim2.fromOffset(0, 370), ZIndex = 12 })
	Loading.text = label(st, "", 22, F.bold, COL.txt, { Size = UDim2.fromOffset(1000, 30), Position = UDim2.fromOffset(140, 430), ZIndex = 12 })
	Loading.dots = label(st, "", 22, F.code, COL.amber, { Size = UDim2.fromOffset(1280, 30), Position = UDim2.fromOffset(0, 466), ZIndex = 12 })
	Loading.tip = label(st, "", 18, F.body, COL.dim, { Size = UDim2.fromOffset(1000, 50), Position = UDim2.fromOffset(140, 620), TextWrapped = true, ZIndex = 12 })
	Loading.osd = label(st, "◀◀ REWIND", 34, F.osd, COL.white, { Size = UDim2.fromOffset(400, 40), Position = UDim2.fromOffset(40, 36), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13 })
	Loading.counter = label(st, "", 34, F.osd, COL.white, { Size = UDim2.fromOffset(400, 40), Position = UDim2.fromOffset(840, 36), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 13 })
	-- полосы трекинга
	Loading.bands = {}
	for i = 1, 7 do
		local b = frame(root, { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = COL.white, BackgroundTransparency = 0.8, ZIndex = 14 })
		grad(b, COL.white, Color3.fromRGB(120, 120, 140), 0, 0.2, 0.8)
		Loading.bands[i] = b
	end
	Loading.grain = makeGrain(root, 80, 15)
	addScanlines(root, 160, 0.75, 16)
	addVignette(root, COL.black, 0.2, 0.1, 17)
end

function Loading.show(data)
	if not Loading.root then return end
	Loading.visible = true
	Loading.root.Visible = true
	Loading.t0 = T
	Loading.tipI = rng:NextInteger(1, #TIPS)
	Loading.tipT = T
	setText(Loading.text, tostring((data and data.text) or "Едем к дому…"))
	setText(Loading.tip, "СОВЕТ: " .. TIPS[Loading.tipI])
end

function Loading.hide()
	if not Loading.visible then return end
	Loading.visible = false
	Loading.root.Visible = false
end

function Loading.step(dt)
	local el = T - Loading.t0
	for _, b in ipairs(Loading.bands) do
		b.Position = UDim2.fromScale(0, rng:NextNumber())
		b.Size = UDim2.new(1, 0, 0, rng:NextInteger(2, 26))
		b.BackgroundTransparency = 0.6 + 0.35 * rng:NextNumber()
	end
	stepGrain(Loading.grain, 0.5, 4)
	Loading.logo.jitter(3 + (rng:NextNumber() < 0.15 and 10 or 0))
	Loading.logo.holder.Position = UDim2.fromOffset(rng:NextNumber() < 0.08 and rng:NextInteger(-20, 20) or 0, 230)
	Loading.osd.TextTransparency = (math.floor(el * 2) % 2 == 0) and 0 or 0.6
	local cnt = math.max(0, 5000 - el * 900)
	setText(Loading.counter, string.format("%d:%02d:%02d", math.floor(cnt / 3600), math.floor(cnt / 60) % 60, math.floor(cnt) % 60))
	local n = math.floor(el * 4) % 6
	setText(Loading.dots, string.rep("▮", n) .. string.rep("▯", 5 - n))
	if T - Loading.tipT > 4 then
		Loading.tipT = T
		Loading.tipI = Loading.tipI % #TIPS + 1
		setText(Loading.tip, "СОВЕТ: " .. TIPS[Loading.tipI])
	end
end

-- ===================== итоги матча =====================
EndScr.visible = false

function EndScr.build()
	local root = frame(guis.full, { Name = "End", Size = UDim2.fromScale(1, 1), BackgroundColor3 = COL.black, BackgroundTransparency = 0.25, Visible = false, Active = true })
	EndScr.root = root
	addVignette(root, COL.black, 0.25, 0, 1)
	local p = frame(root, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(720, 470), BackgroundColor3 = COL.panel, BackgroundTransparency = 0.05, ZIndex = 2 })
	fitScale(p, 720, 470, 1.3, 0.94)
	corner(p, 6)
	EndScr.stroke = stroke(p, COL.amber, 2, 0.3)
	EndScr.panel = p
	label(p, "■ STOP  — КОНЕЦ ЗАПИСИ", 22, F.osd, COL.white, { Size = UDim2.new(1, -40, 0, 30), Position = UDim2.fromOffset(20, 14), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
	EndScr.title = chromaLabel(p, "", 60, F.title, COL.white, { Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, 54), ZIndex = 3 }, 3)
	EndScr.nights = label(p, "", 26, F.title, COL.txt, { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 146), ZIndex = 3 })
	EndScr.amber = label(p, "", 40, F.title, COL.amber, { Size = UDim2.new(0.5, 0, 0, 56), Position = UDim2.fromOffset(0, 196), ZIndex = 3 })
	stroke(EndScr.amber, COL.amber2, 3, 0.7, true)
	EndScr.xp = label(p, "", 40, F.title, COL.cyan, { Size = UDim2.new(0.5, 0, 0, 56), Position = UDim2.fromScale(0.5, 0), ZIndex = 3 })
	EndScr.xp.Position = UDim2.new(0.5, 0, 0, 196)
	EndScr.text = label(p, "", 17, F.body, COL.dim, { Size = UDim2.new(1, -60, 0, 80), Position = UDim2.fromOffset(30, 262), TextWrapped = true, ZIndex = 3 })
	EndScr.note = label(p, "В ЛОББИ — ЧЕРЕЗ НЕСКОЛЬКО СЕКУНД…", 16, F.mono, COL.dim, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -50), ZIndex = 3 })
	addScanlines(p, 90, 0.88, 4)
end

function EndScr.show(data)
	if not EndScr.root then return end
	data = data or {}
	EndScr.visible = true
	EndScr.root.Visible = true
	EndScr.t0 = T
	EndScr.data = data
	local win = data.win and true or false
	EndScr.title.set(win and "ВЫ ВЫЖИЛИ!" or "ВСЕ ПОГИБЛИ")
	EndScr.title.main.TextColor3 = win and COL.ok or Color3.fromRGB(255, 58, 58)
	EndScr.stroke.Color = win and COL.ok or COL.red
	setText(EndScr.nights, "НОЧЕЙ ПЕРЕЖИТО: " .. tostring(data.nights or 0))
	setText(EndScr.text, tostring(data.text or ""))
	EndScr.amber.Text = "+0 ◆"
	EndScr.xp.Text = "+0 XP"
	playSound(win and "Win" or "Lose")
	local sc = EndScr.panel:FindFirstChildOfClass("UIScale")
	if sc then
		local target = sc.Scale
		sc.Scale = target * 0.85
		tween(sc, 0.35, { Scale = target }, Enum.EasingStyle.Back)
	end
end

function EndScr.hide()
	if not EndScr.visible then return end
	EndScr.visible = false
	EndScr.root.Visible = false
end

function EndScr.step(dt)
	local d = EndScr.data or {}
	local k = clamp01((T - EndScr.t0 - 0.6) / 1.6)
	setText(EndScr.amber, "+" .. tostring(math.floor((tonumber(d.amber) or 0) * k + 0.5)) .. " ◆")
	setText(EndScr.xp, "+" .. tostring(math.floor((tonumber(d.xp) or 0) * k + 0.5)) .. " XP")
	EndScr.title.jitter(2 + (rng:NextNumber() < 0.06 and 6 or 0))
	EndScr.note.TextTransparency = 0.2 + 0.4 * (0.5 + 0.5 * math.sin(T * 3))
end

-- ===================== смерть и наблюдение =====================
function Death.build()
	local g = guis.death
	local root = frame(g, { Name = "Death", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(20, 0, 0), BackgroundTransparency = 0.55, Visible = false })
	Death.root = root
	addVignette(root, Color3.fromRGB(70, 0, 0), 0.3, 0, 1)
	local box = frame(root, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.26), Size = UDim2.fromOffset(900, 200), BackgroundTransparency = 1, ZIndex = 2 })
	hudScale(box)
	Death.title = chromaLabel(box, "ТЫ ПОГИБ", 72, F.title, Color3.fromRGB(255, 58, 58), { Size = UDim2.new(1, 0, 0, 90), ZIndex = 2 }, 3)
	Death.sub = label(box, "", 18, F.bold, COL.txt, { Size = UDim2.new(1, -80, 0, 70), Position = UDim2.fromOffset(40, 96), TextWrapped = true, ZIndex = 2 })
	stroke(Death.sub, COL.black, 1.5, 0.3, true)
	Death.grain = makeGrain(root, 40, 3)

	-- полоса наблюдения
	local bar = frame(g, { Name = "Spectate", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(460, 44),
		BackgroundColor3 = COL.black, BackgroundTransparency = 0.3, Visible = false })
	hudScale(bar)
	corner(bar, 4)
	stroke(bar, COL.red, 1.5, 0.3)
	Death.recDot = frame(bar, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = COL.red })
	round(Death.recDot)
	label(bar, "REC", 18, F.osd, COL.red, { Size = UDim2.fromOffset(50, 44), Position = UDim2.fromOffset(32, 0), TextXAlignment = Enum.TextXAlignment.Left })
	Death.specName = label(bar, "", 18, F.title, COL.txt, { Size = UDim2.new(1, -100, 1, 0), Position = UDim2.fromOffset(86, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd })
	Death.bar = bar
end

function Death.show(text)
	if not Death.root then return end
	deathText = text
	Death.title.set("ТЫ ПОГИБ")
	setText(Death.sub, tostring(text or "Наблюдаешь за товарищами. Оживление — на рассвете или дефибриллятором."))
	if not Death.root.Visible then
		Death.root.Visible = true
		Death.root.BackgroundTransparency = 0
		tween(Death.root, 1.2, { BackgroundTransparency = 0.55 })
	end
end

function Death.hide()
	deathText = nil
	if Death.root then Death.root.Visible = false end
	Death.spectate(nil)
end

function Death.spectate(name)
	spectating = name
	if not Death.bar then return end
	Death.bar.Visible = name ~= nil and name ~= ""
	if Death.bar.Visible then setText(Death.specName, "НАБЛЮДЕНИЕ: " .. tostring(name)) end
end

function Death.step(dt)
	if Death.bar and Death.bar.Visible then
		Death.recDot.BackgroundTransparency = (math.floor(T * 2) % 2 == 0) and 0 or 0.8
	end
	if Death.root and Death.root.Visible then
		Death.title.jitter(3)
		stepGrain(Death.grain, 0.25, 3)
		-- в режиме наблюдения надпись уезжает вверх и бледнеет, чтобы не мешать смотреть
		local spec = spectating ~= nil
		Death.title.holder.Parent.Position = UDim2.fromScale(0.5, spec and 0.08 or 0.26)
		Death.root.BackgroundTransparency = math.max(Death.root.BackgroundTransparency, spec and 0.85 or 0)
	end
end

-- ===================== концентрация в укрытии (QTE) =====================
-- стрелка бегает по полосе; нажми E/Пробел/тап, когда она в янтарной зоне
function Qte.build()
	local g = guis.qte
	local p = mk("TextButton", g, { Name = "QTE", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromOffset(540, 160),
		BackgroundColor3 = Color3.fromRGB(10, 6, 6), BackgroundTransparency = 0.15, Text = "", Visible = false })
	hudScale(p, 1.05)
	corner(p, 6)
	Qte.stroke = stroke(p, COL.red, 2, 0.2)
	Qte.panel = p
	Qte.title = chromaLabel(p, "СОСРЕДОТОЧЬСЯ!", 30, F.title, Color3.fromRGB(255, 74, 74), { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 8) }, 2)
	local track = frame(p, { Size = UDim2.fromOffset(480, 30), Position = UDim2.fromOffset(30, 60), BackgroundColor3 = COL.black, BackgroundTransparency = 0.2 })
	corner(track, 3)
	stroke(track, COL.line, 1, 0.7)
	Qte.track = track
	Qte.zone = frame(track, { Size = UDim2.fromScale(0.2, 1), Position = UDim2.fromScale(0.4, 0), BackgroundColor3 = COL.amber, BackgroundTransparency = 0.15 })
	grad(Qte.zone, COL.white, Color3.fromRGB(200, 200, 200), 90)
	Qte.needle = frame(track, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 5, 1, 12), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = COL.white, ZIndex = 3 })
	stroke(Qte.needle, COL.black, 1, 0.3)
	Qte.timer = frame(p, { Size = UDim2.fromOffset(480, 4), Position = UDim2.fromOffset(30, 96), BackgroundColor3 = COL.red })
	Qte.hint = label(p, "", 15, F.mono, COL.dim, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 108) })
	Qte.fb = label(p, "", 18, F.title, COL.ok, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 130) })
	p.Activated:Connect(function() Qte.press() end)
	Qte.active = nil
end

function Qte.newRound(q)
	q.zoneW = math.clamp(0.24 - q.hits * 0.02, 0.1, 0.24)
	q.zoneX = rng:NextNumber() * (1 - q.zoneW)
	q.roundT = 0
	q.win = math.max(1.8, 3.4 - q.hits * 0.2)
	Qte.zone.Size = UDim2.fromScale(q.zoneW, 1)
	Qte.zone.Position = UDim2.fromScale(q.zoneX, 0)
	Qte.zone.BackgroundColor3 = COL.amber
end

function Qte.result(ok)
	local q = Qte.active
	if not q then return end
	if ok then
		q.hits = q.hits + 1
		q.speed = math.min(2.6, q.speed * 1.12)
		Qte.fb.Text = "ЕСТЬ!"
		Qte.fb.TextColor3 = COL.ok
		Qte.zone.BackgroundColor3 = COL.ok
	else
		q.speed = math.max(0.8, q.speed * 0.92)
		Qte.fb.Text = "МИМО"
		Qte.fb.TextColor3 = COL.red
		Qte.zone.BackgroundColor3 = COL.red
		Qte.stroke.Transparency = 0
	end
	Qte.fb.TextTransparency = 0
	q.cool = 0.35
	if q.onResult then
		local cb = q.onResult
		task.spawn(function() safe("qte callback", cb, ok) end)
	end
end

function Qte.press()
	local q = Qte.active
	if not q or q.cool > 0 then return end
	local x = q.pos
	Qte.result(x >= q.zoneX and x <= q.zoneX + q.zoneW)
end

function Qte.start(onResult)
	Qte.stopAll()
	local q = { onResult = onResult, hits = 0, speed = 1, pos = 0, dir = 1, cool = 0.6, roundT = 0, win = 3 }
	Qte.active = q
	Qte.newRound(q)
	Qte.panel.Visible = true
	Qte.fb.Text = ""
	Qte.hint.Text = isTouch and "ТАПНИ, когда стрелка в янтарной зоне" or "[E] / [ПРОБЕЛ] — когда стрелка в янтарной зоне"
	pcall(function()
		CAS:BindActionAtPriority("AA_QTE", function(_, state)
			if state == Enum.UserInputState.Begin then Qte.press() end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 50, Enum.KeyCode.E, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2)
	end)
	local handle = {}
	function handle.stop()
		if Qte.active == q then Qte.stopAll() end
	end
	handle.Stop = handle.stop
	return handle
end

function Qte.stopAll()
	if not Qte.active then return end
	Qte.active = nil
	if Qte.panel then Qte.panel.Visible = false end
	pcall(function() CAS:UnbindAction("AA_QTE") end)
end

function Qte.step(dt)
	local q = Qte.active
	if not q then return end
	-- стрелка «пинг-понг»
	q.pos = q.pos + q.dir * dt * 0.75 * q.speed
	if q.pos > 1 then q.pos, q.dir = 1, -1 end
	if q.pos < 0 then q.pos, q.dir = 0, 1 end
	Qte.needle.Position = UDim2.fromScale(q.pos, 0.5)
	Qte.title.jitter(2)
	Qte.stroke.Transparency = math.min(0.6, Qte.stroke.Transparency + dt)
	if q.cool > 0 then
		q.cool = q.cool - dt
		Qte.fb.TextTransparency = 1 - math.max(0, q.cool) / 0.35
		if q.cool <= 0 then Qte.newRound(q) end
		return
	end
	q.roundT = q.roundT + dt
	Qte.timer.Size = UDim2.fromOffset(480 * (1 - clamp01(q.roundT / q.win)), 4)
	if q.roundT >= q.win then Qte.result(false) end
end

-- ===================== свой вид ProximityPrompt =====================
-- билборд: клавиша (заполняется при удержании), действие, объект, полоска удержания.
-- На сенсорном экране клавиша — кнопка: тап = InputHoldBegin/InputHoldEnd.
Prompts.shown = {}          -- prompt -> ui
Prompts.current = nil

local function promptAdornee(prompt)
	local p = prompt.Parent
	if not p then return nil end
	if p:IsA("BasePart") or p:IsA("Attachment") then return p end
	if p:IsA("Model") then return p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true) end
	return nil
end

local function keyName(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then return "👆" end
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		local n = prompt.GamepadKeyCode.Name
		return (string.gsub(n, "^Button", ""))
	end
	local n = prompt.KeyboardKeyCode.Name
	local map = { One = "1", Two = "2", Three = "3", Four = "4", Five = "5", LeftShift = "SHIFT", Space = "SPACE", Return = "ENTER" }
	return map[n] or n
end

local function makeCustom(d)
	if d:IsA("ProximityPrompt") and d.Style ~= Enum.ProximityPromptStyle.Custom then
		d.Style = Enum.ProximityPromptStyle.Custom
	end
end

function Prompts.show(prompt, inputType)
	Prompts.hide(prompt)
	local ad = promptAdornee(prompt)
	if not ad then return end
	local touch = inputType == Enum.ProximityPromptInputType.Touch
	local s = touch and 1.25 or 1
	local bb = mk("BillboardGui", guis.prompts, { Name = "Prompt", Adornee = ad, AlwaysOnTop = true, LightInfluence = 0, Active = true,
		Size = UDim2.fromOffset(math.floor(270 * s), math.floor(64 * s)), StudsOffset = Vector3.new(0, 0.4, 0), ResetOnSpawn = false,
		MaxDistance = (prompt.MaxActivationDistance or 10) + 8, ClipsDescendants = false })
	local root = frame(bb, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	mk("UIScale", root, { Scale = s })
	root.Size = UDim2.fromScale(1 / s, 1 / s)
	-- клавиша
	local key = mk("TextButton", root, { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(4, 6), BackgroundColor3 = Color3.fromRGB(12, 12, 16),
		BackgroundTransparency = 0.1, Text = "", ClipsDescendants = true })
	corner(key, 6)
	local kst = stroke(key, COL.amber, 2, 0.1)
	local fill = frame(key, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = COL.amber })
	local kl = label(key, keyName(prompt, inputType), 24, F.title, COL.amber, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	textMax(kl, 24, 9)
	kl.TextScaled = ulen(kl.Text) > 2
	-- плашка с текстом
	local plate = frame(root, { Size = UDim2.new(1, -66, 0, 46), Position = UDim2.fromOffset(62, 9), BackgroundColor3 = Color3.fromRGB(10, 11, 15), BackgroundTransparency = 0.18 })
	corner(plate, 4)
	stroke(plate, COL.line, 1, 0.8)
	frame(plate, { Size = UDim2.new(0, 3, 1, -10), Position = UDim2.fromOffset(0, 5), BackgroundColor3 = COL.amber })
	local act = label(plate, prompt.ActionText, 18, F.title, COL.txt, { Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(10, 3),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
	stroke(act, COL.black, 1, 0.4, true)
	local obj = label(plate, prompt.ObjectText, 12, F.mono, COL.dim, { Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(10, 27),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
	local bar = frame(plate, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(0, 0, 0, 3), BackgroundColor3 = COL.amber })
	local ui = { bb = bb, key = key, keyStroke = kst, fill = fill, keyLabel = kl, act = act, obj = obj, bar = bar, prompt = prompt, holding = false, t0 = 0, flash = 0 }
	-- тап/клик по клавише
	key.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			pcall(function() prompt:InputHoldBegin() end)
		end
	end)
	key.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			pcall(function() prompt:InputHoldEnd() end)
		end
	end)
	-- появление
	root.Position = UDim2.fromOffset(0, 8)
	tween(root, 0.15, { Position = UDim2.fromOffset(0, 0) })
	Prompts.shown[prompt] = ui
	Prompts.current = prompt
end

function Prompts.hide(prompt)
	local ui = Prompts.shown[prompt]
	if not ui then return end
	Prompts.shown[prompt] = nil
	ui.bb:Destroy()
	if Prompts.current == prompt then Prompts.current = next(Prompts.shown) end
end

function Prompts.init()
	guis.prompts = screen("AA_Prompts", 8)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") then pcall(makeCustom, d) end
	end
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then pcall(makeCustom, d) end
	end)
	PPS.PromptShown:Connect(function(prompt, inputType)
		pcall(makeCustom, prompt)
		safe("prompt show", Prompts.show, prompt, inputType)
	end)
	PPS.PromptHidden:Connect(function(prompt)
		safe("prompt hide", Prompts.hide, prompt)
	end)
	PPS.PromptButtonHoldBegan:Connect(function(prompt)
		local ui = Prompts.shown[prompt]
		if ui then ui.holding = true ui.t0 = T end
	end)
	PPS.PromptButtonHoldEnded:Connect(function(prompt)
		local ui = Prompts.shown[prompt]
		if ui then ui.holding = false end
	end)
	PPS.PromptTriggered:Connect(function(prompt, plr)
		if plr and plr ~= player then return end
		local ui = Prompts.shown[prompt]
		if ui then ui.flash = 0.25 ui.holding = false end
		local opens = prompt:GetAttribute("Opens")
		if type(opens) == "string" and MODAL_NAMES[opens] then
			if opens == "Dossier" then
				UI.open("Dossier", prompt:GetAttribute("Inmate"))
			else
				UI.open(opens)
			end
		end
	end)
end

function Prompts.step(dt)
	local modal = UI.anyModal()
	for prompt, ui in pairs(Prompts.shown) do
		if not prompt.Parent then
			Prompts.hide(prompt)
		else
			ui.bb.Enabled = prompt.Enabled and not modal
			setText(ui.act, prompt.ActionText)
			setText(ui.obj, prompt.ObjectText)
			local hd = prompt.HoldDuration or 0
			local frac = 0
			if ui.holding then
				if hd > 0 then frac = clamp01((T - ui.t0) / hd) else frac = 1 end
			end
			if ui.flash > 0 then
				ui.flash = ui.flash - dt
				frac = 1
			end
			ui.fill.Size = UDim2.fromScale(1, frac)
			ui.bar.Size = UDim2.new(frac, 0, 0, 3)
			ui.keyLabel.TextColor3 = frac > 0.5 and COL.black or COL.amber
			ui.keyStroke.Transparency = 0.1 + 0.25 * (0.5 + 0.5 * math.sin(T * 5))
		end
	end
end

-- @@SCREENS@@

-- ===================== модальные окна: общий каркас =====================
local mouseIconBefore = nil

updateMouse = function()
	if UI.anyModal() then
		if mouseIconBefore == nil then mouseIconBefore = UIS.MouseIconEnabled end
		UIS.MouseIconEnabled = true
		UIS.MouseBehavior = Enum.MouseBehavior.Default
	elseif mouseIconBefore ~= nil then
		UIS.MouseIconEnabled = mouseIconBefore
		mouseIconBefore = nil
	end
end

-- окно: затемнение (кнопка Modal освобождает мышь в 1-м лице), панель, шапка, тело
local function modalShell(name, title, tag, w, h)
	local root = mk("TextButton", guis.modal, { Name = name, Size = UDim2.fromScale(1, 1), BackgroundColor3 = COL.black,
		BackgroundTransparency = 0.3, Text = "", Modal = true })
	root.Activated:Connect(function() UI.close(name) end)
	local panel = frame(root, { Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 18),
		Size = UDim2.fromOffset(w, h), BackgroundColor3 = COL.panel, BackgroundTransparency = 0.04, Active = true, ClipsDescendants = true })
	fitScale(panel, w, h, 1.25, 0.95)
	corner(panel, 6)
	stroke(panel, COL.amber, 1.5, 0.55)
	grad(panel, COL.white, Color3.fromRGB(150, 150, 160), 90)
	-- шапка
	local head = frame(panel, { Name = "Head", Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = COL.panel2, BackgroundTransparency = 0.1 })
	frame(head, { Size = UDim2.new(0, 6, 1, -20), Position = UDim2.fromOffset(16, 10), BackgroundColor3 = COL.amber })
	local tl = label(head, title, 24, F.title, COL.amber, { Size = UDim2.new(1, -150, 0, 30), Position = UDim2.fromOffset(32, 6),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
	stroke(tl, COL.amber2, 2, 0.75, true)
	label(head, tag or "ASHGROVE // ФАЙЛ", 12, F.mono, COL.dim, { Size = UDim2.new(1, -150, 0, 16), Position = UDim2.fromOffset(33, 36),
		TextXAlignment = Enum.TextXAlignment.Left })
	local line = frame(head, { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = COL.amber })
	grad(line, COL.white, COL.white, 0, 0, 1)
	local x = button(head, "✕", "ghost", function() UI.close(name) end, { Size = UDim2.fromOffset(42, 42), Position = UDim2.new(1, -54, 0, 8), TextSize = 18 })
	x.Name = "Close"
	local body = frame(panel, { Name = "Body", Size = UDim2.new(1, -32, 1, -78), Position = UDim2.fromOffset(16, 70), BackgroundTransparency = 1 })
	addScanlines(panel, 110, 0.9, 40)
	tween(panel, 0.2, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
	return { root = root, panel = panel, body = body, head = head, title = tl, onClose = nil, refresh = nil }
end

-- прокручиваемая сетка карточек
local function scrollGrid(parent, cellW, cellH, gap)
	local sf = mk("ScrollingFrame", parent, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 6,
		ScrollBarImageColor3 = COL.amber, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y })
	pad(sf, 2, 10, 8, 2)
	mk("UIGridLayout", sf, { CellSize = UDim2.fromOffset(cellW, cellH), CellPadding = UDim2.fromOffset(gap or 10, gap or 10),
		SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center })
	return sf
end

local function card(parent, order, accent)
	local c = frame(parent, { BackgroundColor3 = COL.panel2, BackgroundTransparency = 0.15, LayoutOrder = order or 0 })
	corner(c, 5)
	local s = stroke(c, accent or COL.line, 1, accent and 0.3 or 0.85)
	grad(c, COL.white, Color3.fromRGB(170, 170, 180), 90)
	return c, s
end

-- ===================== магазин в гараже =====================
-- сетка предметов Config.Items + полоса продажи яблок по цене сложности матча
local function resultToast(res, fallback)
	if type(res) == "table" then
		UI.toast(tostring(res.msg or (res.ok and "Готово" or "Не получилось")), res.ok and COL.ok or COL.red)
	else
		UI.toast(fallback or "Нет связи с сервером", COL.red)
	end
end

Screens.Shop = function()
	local sh = modalShell("Shop", "🍎 ЯБЛОЧНИК · МАГАЗИН", "ГАРАЖ // КАССА №0021 · ОПЛАТА НАЛИЧНЫМИ", 940, 620)
	local body = sh.body
	local busy = false

	-- верхняя полоса: кошелёк и продажа яблок
	local top = frame(body, { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = COL.black, BackgroundTransparency = 0.45 })
	corner(top, 5)
	stroke(top, COL.line, 1, 0.85)
	local money = label(top, "", 24, F.title, COL.amber, { Size = UDim2.fromOffset(170, 56), Position = UDim2.fromOffset(16, 0), TextXAlignment = Enum.TextXAlignment.Left })
	stroke(money, COL.amber2, 2, 0.75, true)
	local apples = label(top, "", 18, F.bold, COL.txt, { Size = UDim2.fromOffset(140, 56), Position = UDim2.fromOffset(180, 0), TextXAlignment = Enum.TextXAlignment.Left })
	local sell = button(top, "", "green", nil, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(470, 42), TextSize = 16 })
	local closed = label(body, "МАГАЗИН ЗАКРЫТ ДО УТРА", 20, F.title, COL.red, { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 62), Visible = false })

	local gridHolder = frame(body, { Size = UDim2.new(1, 0, 1, -66), Position = UDim2.fromOffset(0, 66), BackgroundTransparency = 1 })
	local grid = scrollGrid(gridHolder, 208, 212, 10)

	local cards = {}
	local function price()
		local d = diffDef()
		return d.applePrice or 20
	end

	local function refresh()
		local m = pattr("Money", 0)
		local a = pattr("Apples", 0)
		local inv = inventory()
		local open = mattr("Phase", "day") == "day"
		setText(money, "$ " .. tostring(m))
		setText(apples, "🍎 " .. tostring(a) .. " шт.")
		local p = price()
		sell.Text = "🍎 ПРОДАТЬ ЯБЛОКИ  " .. tostring(a) .. " × $" .. tostring(p) .. " = $" .. tostring(a * p)
		setEnabled(sell, open and a > 0 and not busy)
		closed.Visible = not open
		gridHolder.Position = UDim2.fromOffset(0, open and 66 or 92)
		gridHolder.Size = UDim2.new(1, 0, 1, open and -66 or -92)
		for k, c in pairs(cards) do
			local it = Config.Items[k]
			local have = inv[k] or 0
			if it.gives then have = inv[it.gives] or 0 end
			c.owned.Text = have > 0 and ("У ТЕБЯ: " .. tostring(have)) or ""
			local can = open and m >= (it.price or 0) and not busy
			setEnabled(c.buy, can)
			c.price.TextColor3 = m >= (it.price or 0) and COL.amber or Color3.fromRGB(150, 110, 60)
		end
	end

	local function run(kind, key)
		if busy then return end
		busy = true
		refresh()
		local res = invoke("Shop", kind, key)
		busy = false
		resultToast(res)
		if res and res.ok then
			if kind == "sell" then playSound("Coin") end
		end
		if sh.root.Parent then refresh() end
	end
	sell.Activated:Connect(function() task.spawn(run, "sell") end)

	for i, k in ipairs(sortedKeys(Config.Items)) do
		local it = Config.Items[k]
		local c = card(grid, i)
		pad(c, 10, 12, 10, 12)
		local icon = label(c, it.icon or "❔", 38, F.body, COL.white, { Size = UDim2.fromOffset(48, 48) })
		local pr = label(c, "$" .. tostring(it.price or 0), 22, F.title, COL.amber, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4),
			Size = UDim2.fromOffset(110, 28), TextXAlignment = Enum.TextXAlignment.Right })
		local owned = label(c, "", 11, F.mono, COL.ok, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 32), Size = UDim2.fromOffset(110, 14),
			TextXAlignment = Enum.TextXAlignment.Right })
		label(c, it.name or k, 16, F.title, COL.txt, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 54), TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd })
		label(c, it.desc or "", 12, F.body, COL.dim, { Size = UDim2.new(1, 0, 0, 62), Position = UDim2.fromOffset(0, 78), TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
		local buy = button(c, "КУПИТЬ", "amber", function() run("buy", k) end, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 36), TextSize = 15 })
		cards[k] = { buy = buy, owned = owned, price = pr, icon = icon }
	end

	local acc = 0
	sh.tick = function(dt)
		acc = acc + dt
		if acc > 0.25 then
			acc = 0
			refresh()
		end
	end
	refresh()
	return sh
end

-- ===================== классы (киоск лобби) =====================
local profile = nil

local function profileFromAttrs()
	local cls = pattr("Class", "novice")
	local owned = { novice = true }
	owned[cls] = true
	local xp = pattr("XP", 0)
	local lvl = pattr("Level", (Config.levelOf and Config.levelOf(xp)) or 1)
	return { amber = pattr("Amber", 0), xp = xp, level = lvl, rank = pattr("Rank", (Config.rankOf and Config.rankOf(lvl)) or ""), class = cls, owned = owned, partial = true }
end

local function loadProfile()
	local res = invoke("Profile")
	if type(res) == "table" then
		res.owned = res.owned or {}
		profile = res
	end
	return profile
end

Screens.Classes = function()
	local sh = modalShell("Classes", "КЛАССЫ", "ОТДЕЛ КАДРОВ // ДОПУСК К СМЕНЕ", 940, 600)
	local body = sh.body
	local busy = false
	local prof = profile or profileFromAttrs()

	local top = frame(body, { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = COL.black, BackgroundTransparency = 0.45 })
	corner(top, 5)
	stroke(top, COL.line, 1, 0.85)
	local amber = label(top, "", 22, F.title, COL.amber, { Size = UDim2.fromOffset(260, 50), Position = UDim2.fromOffset(16, 0), TextXAlignment = Enum.TextXAlignment.Left })
	stroke(amber, COL.amber2, 2, 0.75, true)
	local lvl = label(top, "", 15, F.bold, COL.txt, { Size = UDim2.new(1, -300, 1, 0), Position = UDim2.fromOffset(280, 0), TextXAlignment = Enum.TextXAlignment.Right })

	local holder = frame(body, { Size = UDim2.new(1, 0, 1, -60), Position = UDim2.fromOffset(0, 60), BackgroundTransparency = 1 })
	local grid = scrollGrid(holder, 280, 200, 12)

	local function render()
		clear(grid, { UIGridLayout = true, UIPadding = true })
		setText(amber, "◆ " .. tostring(prof.amber or 0) .. " AMBER")
		local cdef = Config.Classes[prof.class or ""]
		setText(lvl, "УР. " .. tostring(prof.level or 1) .. " · " .. tostring(prof.rank or "") .. "   ·   КЛАСС: " .. ((cdef and cdef.name) or "—"))
		for i, k in ipairs(sortedKeys(Config.Classes)) do
			local C = Config.Classes[k]
			local own = (prof.owned and prof.owned[k]) or (C.price or 0) == 0
			local eq = prof.class == k
			local c, st = card(grid, i, eq and COL.amber or nil)
			if eq then c.BackgroundColor3 = Color3.fromRGB(50, 38, 8) end
			pad(c, 10, 12, 10, 12)
			label(c, C.icon or "🙂", 34, F.body, COL.white, { Size = UDim2.fromOffset(44, 44) })
			label(c, C.name or k, 20, F.title, eq and COL.amber or COL.txt, { Size = UDim2.new(1, -54, 0, 24), Position = UDim2.fromOffset(52, 2), TextXAlignment = Enum.TextXAlignment.Left })
			local stateText = own and "ЕСТЬ" or ("◆ " .. tostring(C.price or 0))
			if eq then stateText = "● ВЫБРАН" end
			label(c, stateText, 13, F.mono, own and COL.ok or COL.amber, { Size = UDim2.new(1, -54, 0, 16), Position = UDim2.fromOffset(52, 26), TextXAlignment = Enum.TextXAlignment.Left })
			label(c, C.desc or "", 13, F.body, COL.dim, { Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromOffset(0, 54), TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
			local txt, style, kind = "ВЫБРАТЬ", "dark", "setClass"
			if eq then txt, style, kind = "ВЫБРАН", "green", nil
			elseif not own then txt, style, kind = "КУПИТЬ · ◆" .. tostring(C.price or 0), "amber", "buyClass" end
			local b = button(c, txt, style, nil, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 36), TextSize = 14 })
			if not kind or busy or (kind == "buyClass" and (prof.amber or 0) < (C.price or 0)) then setEnabled(b, false) end
			if kind then
				b.Activated:Connect(function()
					if busy or b:GetAttribute("Off") then return end
					busy = true
					local res = invoke("Lobby", kind, k)
					busy = false
					resultToast(res)
					if type(res) == "table" and type(res.profile) == "table" then
						res.profile.owned = res.profile.owned or {}
						profile = res.profile
						prof = profile
					elseif type(res) == "table" and res.ok then
						if kind == "buyClass" then prof.owned[k] = true end
						if kind == "setClass" then prof.class = k end
					end
					if sh.root.Parent then render() end
				end)
			end
		end
	end
	render()
	task.spawn(function()
		local p = loadProfile()
		if p and sh.root.Parent then
			prof = p
			render()
		end
	end)
	return sh
end

-- ===================== досье заключённого =====================
-- секретная папка: фото (вращающаяся 3D-модель во ViewportFrame), штамп, поля дела
local function typedLine(parent, caption, value, order, color)
	local row = frame(parent, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order })
	vlist(row, 1)
	label(row, caption, 12, F.mono, Color3.fromRGB(110, 98, 80), { Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1 })
	local v = label(row, value, 16, F.mono, color or COL.ink, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2 })
	return v, row
end

local function buildPreview(sh, photo, def)
	local vf = mk("ViewportFrame", photo, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(26, 28, 32),
		Ambient = Color3.fromRGB(150, 150, 160), LightColor = Color3.fromRGB(255, 232, 200), LightDirection = Vector3.new(-0.6, -1, -0.8) })
	grad(vf, COL.white, Color3.fromRGB(120, 120, 130), 90)
	local cam = mk("Camera", vf, { FieldOfView = 34 })
	vf.CurrentCamera = cam
	local wm = mk("WorldModel", vf)
	local note = label(photo, "ФОТО\nОТСУТСТВУЕТ", 16, F.mono, COL.dim, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	if type(def.build) ~= "function" then return end
	task.spawn(function()
		local ok, model = pcall(def.build, ctx)
		if not ok or typeof(model) ~= "Instance" then
			if not ok then warnOnce("dossier build", model) end
			return
		end
		if not sh.root.Parent then model:Destroy() return end
		-- скрипты и звуки во ViewportFrame не нужны
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("ProximityPrompt") then d:Destroy() end
		end
		if model:IsA("Model") and model.PrimaryPart then model.PrimaryPart.Anchored = true end
		model.Parent = wm
		local cf, size = model:GetBoundingBox()
		local base = model:GetPivot()
		local h = math.max(size.Y, size.X * 0.8, 2)
		local center = cf.Position
		local dist = (h * 0.62) / math.tan(math.rad(17))
		cam.CFrame = CFrame.lookAt(center + Vector3.new(0, h * 0.08, dist), center)
		note.Visible = false
		sh.preview = { model = model, base = base, center = center, animOk = type(def.animate) == "function" }
	end)
end

Screens.Dossier = function(key)
	local def = inmateDef(key)
	local sh = modalShell("Dossier", "ДОСЬЕ · ASHGROVE", "ЛЕЧЕБНИЦА ASHGROVE // ОТДЕЛ СОДЕРЖАНИЯ // ДСП", 960, 620)
	local body = sh.body
	if not def then
		label(body, "ДЕЛО НЕ НАЙДЕНО", 26, F.title, COL.red, { Size = UDim2.fromScale(1, 0.5) })
		button(body, "← К СПИСКУ", "dark", function() UI.open("Dossiers") end, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.6) })
		return sh
	end
	-- папка и лист бумаги
	local folder = frame(body, { Size = UDim2.new(1, 0, 1, -6), Position = UDim2.fromOffset(0, 6), BackgroundColor3 = COL.manila })
	corner(folder, 6)
	frame(folder, { Size = UDim2.fromOffset(180, 22), Position = UDim2.fromOffset(24, -14), BackgroundColor3 = COL.manila })
	local paper = frame(folder, { Size = UDim2.new(1, -28, 1, -24), Position = UDim2.fromOffset(14, 12), BackgroundColor3 = COL.paper })
	corner(paper, 2)
	grad(paper, COL.white, Color3.fromRGB(225, 215, 190), 120)
	stroke(paper, Color3.fromRGB(150, 130, 90), 1, 0.5)

	-- фото
	local polaroid = frame(paper, { Size = UDim2.fromOffset(280, 330), Position = UDim2.fromOffset(22, 22), BackgroundColor3 = Color3.fromRGB(246, 244, 238) })
	stroke(polaroid, Color3.fromRGB(150, 140, 120), 1, 0.4)
	local photo = frame(polaroid, { Size = UDim2.fromOffset(256, 270), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.fromRGB(20, 22, 26), ClipsDescendants = true })
	buildPreview(sh, photo, def)
	label(polaroid, "INMATE № " .. tostring(def.num or "???"), 18, F.code, COL.ink, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -44) })
	-- скрепка
	local clip = frame(paper, { Size = UDim2.fromOffset(16, 56), Position = UDim2.fromOffset(150, 6), BackgroundTransparency = 1 })
	stroke(clip, Color3.fromRGB(150, 155, 165), 3, 0)
	corner(clip, 8)
	-- полоска цвета заключённого
	local cbar = frame(paper, { Size = UDim2.fromOffset(280, 8), Position = UDim2.fromOffset(22, 362), BackgroundColor3 = (typeof(def.color) == "Color3" and def.color) or COL.red })
	corner(cbar, 2)

	-- поля дела
	local sf = mk("ScrollingFrame", paper, { Size = UDim2.new(1, -350, 1, -100), Position = UDim2.fromOffset(326, 22), BackgroundTransparency = 1,
		ScrollBarThickness = 5, ScrollBarImageColor3 = Color3.fromRGB(120, 100, 60), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y })
	vlist(sf, 10)
	pad(sf, 0, 10, 10, 0)
	local nm = label(sf, tostring(def.name or "???"), 34, F.title, COL.ink, { Size = UDim2.new(1, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1 })
	textMax(nm, 34, 14)
	nm.TextScaled = true
	label(sf, tostring(def.en or ""), 16, F.code, Color3.fromRGB(110, 98, 80), { Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2 })
	frame(sf, { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.fromRGB(120, 100, 70), BackgroundTransparency = 0.4, LayoutOrder = 3 })
	typedLine(sf, "ДЕЛО №", tostring(def.num or "???"), 4)
	typedLine(sf, "КЛАССИФИКАЦИЯ", tostring(def.class or "НЕ УСТАНОВЛЕНА"), 5, Color3.fromRGB(150, 20, 24))
	local lines = {}
	for _, l in ipairs(def.alert or {}) do table.insert(lines, tostring(l)) end
	typedLine(sf, "ИЗ ТЕКСТА ОПОВЕЩЕНИЯ", #lines > 0 and table.concat(lines, " ") or "[ДАННЫЕ ИЗЪЯТЫ]", 6)
	local tipV, tipRow = typedLine(sf, "РЕКОМЕНДАЦИЯ ДЛЯ ГРАЖДАН", tostring(def.tip or "—"), 7, Color3.fromRGB(60, 40, 0))
	-- выделение маркером
	local hl = frame(tipRow, { Size = UDim2.new(1, 0, 1, -14), Position = UDim2.fromOffset(0, 15), BackgroundColor3 = Color3.fromRGB(255, 214, 60), BackgroundTransparency = 0.55, ZIndex = 0 })
	hl.ZIndex = tipV.ZIndex - 1
	-- зачёркнутые строки
	local red = frame(sf, { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 8 })
	for i = 0, 2 do
		frame(red, { Size = UDim2.new(0.35 + 0.2 * ((i * 37) % 3) / 2, 0, 0, 10), Position = UDim2.fromOffset(0, i * 15), BackgroundColor3 = COL.ink })
	end

	-- штамп
	local stamp = label(paper, "СОВЕРШЕННО\nСЕКРЕТНО", 26, F.title, COL.stamp, { Size = UDim2.fromOffset(250, 76), Position = UDim2.fromOffset(40, 380),
		Rotation = -9, TextTransparency = 0.15 })
	stroke(stamp, COL.stamp, 3, 0.2)
	-- низ листа
	label(paper, "ASHGROVE ASYLUM · ЭКЗ. 1 ИЗ 1 · ВЫНОС ЗАПРЕЩЁН", 12, F.mono, Color3.fromRGB(120, 108, 90), { AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, -350, 0, 16), Position = UDim2.new(0, 326, 1, -14), TextXAlignment = Enum.TextXAlignment.Left })
	button(paper, "← ВСЕ ДЕЛА", "dark", function() UI.open("Dossiers") end, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -40),
		Size = UDim2.fromOffset(150, 38), TextSize = 14 })

	local animErr = false
	sh.tick = function(dt)
		local p = sh.preview
		if not p or not p.model.Parent then return end
		local a = T * 0.7
		local rot = p.base - p.base.Position
		p.model:PivotTo(CFrame.new(p.base.Position) * CFrame.Angles(0, a, 0) * rot)
		if p.animOk and not animErr then
			local ok, err = pcall(def.animate, p.model, dt, T, ctx)
			if not ok then
				animErr = true
				warnOnce("dossier animate " .. tostring(key), err)
			end
		end
	end
	sh.onClose = function()
		if sh.preview and sh.preview.model then pcall(function() sh.preview.model:Destroy() end) end
	end
	return sh
end

-- ===================== список досье =====================
Screens.Dossiers = function()
	local sh = modalShell("Dossiers", "АРХИВ ДЕЛ", "ASHGROVE // КАРТОТЕКА ЗАКЛЮЧЁННЫХ", 760, 600)
	local list = allInmates()
	if #list == 0 then
		label(sh.body, "АРХИВ ПУСТ", 24, F.title, COL.dim, { Size = UDim2.fromScale(1, 1) })
		return sh
	end
	local sf = mk("ScrollingFrame", sh.body, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 6,
		ScrollBarImageColor3 = COL.amber, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y })
	vlist(sf, 6)
	pad(sf, 2, 12, 8, 2)
	for i, e in ipairs(list) do
		local d = e.def
		local row = mk("TextButton", sf, { Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = COL.panel2, BackgroundTransparency = 0.15, LayoutOrder = i, Text = "" })
		corner(row, 4)
		local st = stroke(row, COL.line, 1, 0.85)
		frame(row, { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = (typeof(d.color) == "Color3" and d.color) or COL.amber })
		label(row, tostring(d.num or "???"), 30, F.code, COL.amber, { Size = UDim2.fromOffset(90, 62), Position = UDim2.fromOffset(16, 0) })
		label(row, tostring(d.name or e.key), 20, F.title, COL.txt, { Size = UDim2.new(1, -260, 0, 26), Position = UDim2.fromOffset(112, 7), TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd })
		label(row, tostring(d.class or ""), 12, F.body, COL.dim, { Size = UDim2.new(1, -260, 0, 18), Position = UDim2.fromOffset(112, 35), TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd })
		label(row, tostring(d.en or "") .. "  ›", 14, F.code, COL.dim, { AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(140, 62), Position = UDim2.new(1, -14, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Right })
		row.MouseEnter:Connect(function() st.Color = COL.amber st.Transparency = 0.2 end)
		row.MouseLeave:Connect(function() st.Color = COL.line st.Transparency = 0.85 end)
		row.Activated:Connect(function()
			playSound("UiClick", { Volume = 0.35 })
			UI.open("Dossier", e.key)
		end)
	end
	return sh
end

-- ===================== задания (заглушка) =====================
local QUESTS = {
	{ name = "Собери 30 яблок", goal = 30, reward = 25, icon = "🍎" },
	{ name = "Переживи 3 ночи", goal = 3, reward = 40, icon = "🌙" },
	{ name = "Обезвредь заключённого", goal = 1, reward = 60, icon = "🎯" },
}

Screens.Quests = function()
	local sh = modalShell("Quests", "ЗАДАНИЯ ДНЯ", "ASHGROVE // ЕЖЕДНЕВНЫЙ НАРЯД", 640, 440)
	local box = frame(sh.body, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	vlist(box, 10)
	for i, q in ipairs(QUESTS) do
		local c = card(box, i)
		c.Size = UDim2.new(1, 0, 0, 86)
		pad(c, 10, 14, 10, 14)
		label(c, q.icon, 30, F.body, COL.white, { Size = UDim2.fromOffset(40, 40) })
		label(c, q.name, 18, F.title, COL.txt, { Size = UDim2.new(1, -170, 0, 22), Position = UDim2.fromOffset(52, 2), TextXAlignment = Enum.TextXAlignment.Left })
		label(c, "◆ " .. tostring(q.reward), 18, F.title, COL.amber, { AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(110, 22), Position = UDim2.new(1, 0, 0, 2),
			TextXAlignment = Enum.TextXAlignment.Right })
		local track = frame(c, { Size = UDim2.new(1, -52, 0, 10), Position = UDim2.fromOffset(52, 34), BackgroundColor3 = COL.black, BackgroundTransparency = 0.3 })
		corner(track, 3)
		frame(track, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = COL.amber })
		label(c, "0 / " .. tostring(q.goal), 12, F.mono, COL.dim, { Size = UDim2.new(1, -52, 0, 14), Position = UDim2.fromOffset(52, 50), TextXAlignment = Enum.TextXAlignment.Left })
	end
	local t = os.time()
	local left = 86400 - (t % 86400)
	label(box, string.format("Новые задания через %02d:%02d", math.floor(left / 3600), math.floor((left % 3600) / 60)), 13, F.mono, COL.dim,
		{ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 10 })
	return sh
end

-- ===================== коды (заглушка) =====================
Screens.Codes = function()
	local sh = modalShell("Codes", "КОДЫ", "ASHGROVE // ТЕРМИНАЛ ДОСТУПА", 560, 320)
	local body = sh.body
	label(body, "Введи код из сообщества игры:", 15, F.body, COL.dim, { Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
	local tb = mk("TextBox", body, { Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 30), BackgroundTransparency = 0.1, BackgroundColor3 = Color3.fromRGB(10, 12, 16),
		Font = F.code, TextSize = 28, TextColor3 = COL.amber, PlaceholderText = "ВВЕДИ КОД", PlaceholderColor3 = Color3.fromRGB(110, 90, 40),
		ClearTextOnFocus = false, Text = "" })
	corner(tb, 5)
	stroke(tb, COL.amber, 1.5, 0.4)
	local function submit()
		local code = string.gsub(tb.Text or "", "^%s+", "")
		if code == "" then
			UI.toast("Сначала введи код", COL.amber)
			return
		end
		UI.toast("Код не найден", COL.red)
		tb.Text = ""
	end
	tb.FocusLost:Connect(function(enter) if enter then submit() end end)
	button(body, "ВВЕСТИ ✓", "green", submit, { Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 100), TextSize = 17 })
	label(body, "Подсказка: коды выходят вместе с обновлениями.", 12, F.mono, COL.dim, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 160) })
	return sh
end

-- ===================== публичный API =====================
function UI.toast(text, color)
	if not started then return end
	safe("toast", Toasts.push, tostring(text or ""), color)
end

function UI.flash(color, startTransparency, seconds)
	if not started then return end
	safe("flash", Flash.flash, color, startTransparency, seconds)
end

function UI.jumpscareOverlay(color, seconds)
	if not started then return end
	safe("jumpscare", Flash.jumpscare, color, seconds)
end

function UI.setScene(name, data)
	if not started then return end
	data = data or {}
	if name == scene and data == sceneData then return end
	local prev = scene
	scene, sceneData = name, data
	for n in pairs(openModals) do UI.close(n) end
	safe("scene", function()
		guis.hud.Enabled = (name == "house")
		guis.lobby.Enabled = (name == "lobby")
		if name ~= "house" then
			Eas.hide(true)
			Death.hide()
			Qte.stopAll()
		end
		if name == "loading" then Loading.show(data) else Loading.hide() end
		if name == "end" then EndScr.show(data) else EndScr.hide() end
		if name == "house" and prev ~= "house" then Hud.onEnter(data) end
		if name == "lobby" then LobbyHud.onEnter() end
	end)
end

function UI.showAlert(data)
	if not started then return end
	safe("alert", Eas.show, data or {})
end

function UI.hideAlert()
	if not started then return end
	safe("alert hide", Eas.hide)
end

function UI.open(name, arg)
	if not started or not MODAL_NAMES[name] then return end
	for n in pairs(openModals) do UI.close(n) end
	local builder = Screens[name]
	if not builder then return end
	local ok, shell = pcall(builder, arg)
	if not ok or not shell then
		warnOnce("open " .. name, shell)
		return
	end
	openModals[name] = shell
	playSound("UiClick", { Volume = 0.4 })
	updateMouse()
end

function UI.close(name)
	local m = openModals[name]
	if not m then return end
	openModals[name] = nil
	if m.onClose then safe("close " .. name, m.onClose) end
	if m.root then m.root:Destroy() end
	updateMouse()
end

function UI.isOpen(name)
	return openModals[name] ~= nil
end

function UI.anyModal()
	if next(openModals) ~= nil then return true end
	if Eas.visible then return true end
	return false
end

function UI.setStamina(frac) stamina = clamp01(frac) end
function UI.setBattery(frac) battery = clamp01(frac) end
function UI.setFlashlight(on) flashlightOn = on and true or false end
function UI.setCrosshair(visible) crosshairOn = visible and true or false end

function UI.setSelected(itemKey)
	selectedKey = itemKey or ""
	if started then safe("hotbar sel", Hud.markSelected) end
end

-- порядок предметов в хотбаре (клавиши 1–9) — Controls может брать его отсюда
function UI.hotbarKeys()
	local ok, keys = pcall(Hud.slotKeys)
	if ok and keys then return keys end
	return {}
end

function UI.qte(onResult)
	if not started then return { stop = function() end } end
	local ok, h = pcall(Qte.start, onResult)
	if ok and h then return h end
	warnOnce("qte", h)
	return { stop = function() end }
end

function UI.showDeath(text)
	if not started then return end
	safe("death", Death.show, text)
end

function UI.hideDeath()
	if not started then return end
	safe("death hide", Death.hide)
end

function UI.setSpectating(nameOrNil)
	if not started then return end
	safe("spectate", Death.spectate, nameOrNil)
end

-- ===================== кадр =====================
local slowT = 0
local function onFrame(dt)
	T = T + dt
	slowT = slowT + dt
	if slowT > 0.5 then
		slowT = 0
		safe("refit", refit)
	end
	safe("vhs", Vhs.step, dt)
	if scene == "house" then safe("hud", Hud.step, dt) end
	if scene == "lobby" then safe("lobbyhud", LobbyHud.step, dt) end
	safe("signs", Signs.step, dt)
	if Eas.visible then safe("eas", Eas.step, dt) end
	if Loading.visible then safe("loading", Loading.step, dt) end
	if EndScr.visible then safe("end", EndScr.step, dt) end
	safe("death step", Death.step, dt)
	safe("qte step", Qte.step, dt)
	safe("flash step", Flash.step, dt)
	safe("prompts step", Prompts.step, dt)
	for name, m in pairs(openModals) do
		if m.tick then safe("tick " .. name, m.tick, dt) end
	end
end

-- ===================== инициализация =====================
function UI.init(c)
	ctx = c or {}
	player = ctx.player or Players.LocalPlayer
	Config = ctx.Config or require(RS:WaitForChild("Shared"):WaitForChild("Config"))
	Net = ctx.Net or require(RS:WaitForChild("Shared"):WaitForChild("Net"))
	Sound = ctx.Sound
	pgui = player:WaitForChild("PlayerGui")
	isTouch = UIS.TouchEnabled and not UIS.KeyboardEnabled
	viewport()

	guis.vhs = screen("AA_VHS", 2)
	guis.lobby = screen("AA_Lobby", 5)
	guis.hud = screen("AA_HUD", 6)
	guis.toast = screen("AA_Toast", 40)
	guis.modal = screen("AA_Modal", 30)
	guis.eas = screen("AA_EAS", 35)
	guis.death = screen("AA_Death", 25)
	guis.qte = screen("AA_QTE", 28)
	guis.full = screen("AA_Screens", 45)
	guis.fx = screen("AA_Flash", 60)
	started = true

	local parts = {
		{ "vhs", Vhs }, { "hud", Hud }, { "lobbyhud", LobbyHud }, { "toasts", Toasts }, { "eas", Eas },
		{ "loading", Loading }, { "end", EndScr }, { "death", Death }, { "qte", Qte }, { "flash", Flash },
	}
	for _, p in ipairs(parts) do
		if p[2].build then safe("build " .. p[1], p[2].build) end
	end
	guis.hud.Enabled = false
	guis.lobby.Enabled = true

	safe("prompts init", Prompts.init)
	safe("signs init", Signs.init)

	RunService.RenderStepped:Connect(onFrame)
	-- пока открыто окно — мышь свободна даже в режиме первого лица
	pcall(function()
		RunService:BindToRenderStep("AA_UIMouse", Enum.RenderPriority.Camera.Value + 2, function()
			if UI.anyModal() then UIS.MouseBehavior = Enum.MouseBehavior.Default end
		end)
	end)

	-- удалённые события (ждём их в отдельном потоке, чтобы не задерживать запуск)
	task.spawn(function()
		local ok, err = pcall(function()
			Net.event("Toast").OnClientEvent:Connect(function(text, color) UI.toast(text, color) end)
			Net.event("Alert").OnClientEvent:Connect(function(data) UI.showAlert(data) end)
			Net.event("Scene").OnClientEvent:Connect(function(name, data) UI.setScene(name, data) end)
			Net.event("Hidden").OnClientEvent:Connect(function(model)
				hiddenIn = model
				if not model then Qte.stopAll() end
			end)
		end)
		if not ok then warnOnce("remotes", err) end
	end)

	-- стартовая сцена: по MatchId
	local mid = player:GetAttribute("MatchId") or 0
	scene = ""
	if mid == 0 then UI.setScene("lobby", {}) else UI.setScene("house", { matchId = mid }) end
end

return UI
