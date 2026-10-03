-- Интерфейс «Стихийных битв RNG» (v3).
-- РОЛЛ: новая способность ЗАМЕНЯЕТ старую; если сейчас редкая — сначала спросим «точно крутить?».
-- Лента прокрутки: карусель, «почти выпало», стук, вспышка, блик, большой показ редких с переворотом карты.
-- Монеты за ролл и за сбитых, удача ×2, ТЕСТ-кнопка «Призвать Рю».
-- Бой: F/клик — удар, E — способность, у Рю: 1 — Десерт, 2 — «Вот каков десерт!», G — ульта.
-- Позы персонажей (видят все) и кинокамера для комбо и ульты Рю.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local Abilities = require(RS:WaitForChild("Abilities"))
local CFG = Abilities.Config
local remotes = RS:WaitForChild("Remotes")
local R = {}
for _, n in ipairs({ "Roll", "Summon", "GetData", "BuyLuck", "Use", "Announce", "DataUpdate", "Shake", "Cinematic" }) do R[n] = remotes:WaitForChild(n) end

-- рюкзак не нужен: клавиши 1 и 2 заняты приёмами Рю
task.spawn(function()
	for _ = 1, 10 do
		if pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end) then break end
		task.wait(1)
	end
end)

local data = { equipped = nil, coins = 0, luckLeft = 0, luckCost = 50 }
local luckEnds = 0
local TOUCH = UIS.TouchEnabled and not UIS.KeyboardEnabled

---------------------------------------------------------------- помощники
local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then o[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = o end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local DARK = Color3.fromRGB(28, 22, 46)
local GOLD = Color3.fromRGB(255, 210, 70)
local PURPLE = Color3.fromRGB(130, 95, 255)
local FONT = Enum.Font.FredokaOne

local function corner(r) return new("UICorner", { CornerRadius = UDim.new(r or 0.2, 0) }) end
local function stroke(c, th) return new("UIStroke", { Color = c or DARK, Thickness = th or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function tstroke(th) return new("UIStroke", { Color = Color3.fromRGB(20, 15, 35), Thickness = th or 2 }) end
local function grad(a, b, rot) return new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rot or 90 }) end
local function padding(px) return new("UIPadding", { PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px), PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px) }) end
local function darker(c, k) return c:Lerp(BLACK, k) end
local function lighter(c, k) return c:Lerp(WHITE, k) end
local function tween(o, t, goal, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
local function sound(id, vol, pitch)
	return new("Sound", { SoundId = id, Volume = vol or 0.4, PlaybackSpeed = pitch or 1, Parent = SoundService })
end
local sTick = sound("rbxasset://sounds/electronicpingshort.wav", 0.12, 1.6)
local sWin = sound("rbxasset://sounds/electronicpingshort.wav", 0.5, 0.8)
local sSlash = sound("rbxasset://sounds/swordslash.wav", 0.6, 1)
local sLunge = sound("rbxasset://sounds/swordlunge.wav", 0.6, 1)
local sUnsheath = sound("rbxasset://sounds/unsheath.wav", 0.6, 1)
local function play(s, pitch) if pitch then s.PlaybackSpeed = pitch end; pcall(function() SoundService:PlayLocalSound(s) end) end
local function rarityOf(a) return Abilities.Rarities[a.rarity] end

-- string.upper не умеет кириллицу — делаем сами
local function upper(s)
	local out = {}
	for _, c in utf8.codes(s) do
		if c >= 0x430 and c <= 0x44F then c = c - 0x20
		elseif c == 0x451 then c = 0x401
		elseif c >= 97 and c <= 122 then c = c - 32 end
		table.insert(out, utf8.char(c))
	end
	return table.concat(out)
end

---------------------------------------------------------------- экраны
local pg = player:WaitForChild("PlayerGui")
local gui = new("ScreenGui", { Name = "RNGUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg })
local top = new("ScreenGui", { Name = "RNGTop", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg })
local hud = new("Frame", { Name = "HUD", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = gui })

local flash = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50, Parent = top })
local function doFlash(color, from, t)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = from
	tween(flash, t or 0.6, { BackgroundTransparency = 1 })
end

---------------------------------------------------------------- тряска камеры (одна на всё)
local shakeAmp = 0
local cine = false        -- идёт кинокамера: "combo" / "ult"
local function addShake(power) shakeAmp = math.max(shakeAmp, power) end
local function shakeCF()
	if shakeAmp <= 0.01 then return CFrame.new() end
	local m = shakeAmp * 0.45
	return CFrame.new((math.random() * 2 - 1) * m, (math.random() * 2 - 1) * m, 0) * CFrame.Angles(0, 0, (math.random() * 2 - 1) * m * 0.04)
end
local offsetDirty = false
RunService.RenderStepped:Connect(function(dt)
	shakeAmp = math.max(0, shakeAmp - dt * 2.2)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if shakeAmp > 0.01 and not cine then
		hum.CameraOffset = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, 0) * shakeAmp * 1.4
		offsetDirty = true
	elseif offsetDirty then
		hum.CameraOffset = Vector3.new()
		offsetDirty = false
	end
end)

---------------------------------------------------------------- верх: способность, подсказка, лента объявлений
local eqLbl = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(0.46, 0, 0, 36), BackgroundColor3 = DARK, BackgroundTransparency = 0.12,
	Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "Способность: нет — нажми РОЛЛ!", Parent = hud },
	{ corner(0.45), new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }),
	  new("UISizeConstraint", { MinSize = Vector2.new(320, 30) }) })
local eqStroke = new("UIStroke", { Color = PURPLE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = eqLbl })
local hintLbl = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.new(0.5, 0, 0, 24), BackgroundTransparency = 1,
	Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(210, 180, 255), Text = "Прыгни в фиолетовый портал, чтобы попасть на арену!", Parent = hud }, { tstroke(2) })

local feed = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 76), Size = UDim2.new(0.6, 0, 0, 130), BackgroundTransparency = 1, Parent = hud },
	{ new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
local feedN = 0
local function announce(text, color, big)
	feedN = feedN + 1
	local l = new("TextLabel", { Size = UDim2.new(1, 0, 0, big and 34 or 24), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = color or WHITE,
		Text = text, LayoutOrder = feedN, TextTransparency = 1, Parent = feed }, { tstroke(2.5) })
	tween(l, 0.25, { TextTransparency = 0 })
	task.delay(big and 6 or 4, function()
		if l.Parent then tween(l, 0.5, { TextTransparency = 1 }); task.wait(0.55); l:Destroy() end
	end)
	local labels = {}
	for _, k in ipairs(feed:GetChildren()) do if k:IsA("TextLabel") then table.insert(labels, k) end end
	if #labels > 4 then table.sort(labels, function(a, b) return a.LayoutOrder < b.LayoutOrder end); labels[1]:Destroy() end
end
local lastHint = {}
local function hint(text, color)
	if lastHint[text] and os.clock() - lastHint[text] < 2.5 then return end
	lastHint[text] = os.clock()
	announce(text, color or Color3.fromRGB(210, 180, 255), false)
end

---------------------------------------------------------------- слева: монеты, удача, призыв Рю
-- текст кнопки — отдельной надписью внутри: UIGradient кнопки иначе перекрасил бы и буквы
local function button(parent, anchor, pos, size, text, c1, c2)
	local b = new("TextButton", { AnchorPoint = anchor or Vector2.new(0, 0), Position = pos, Size = size, BackgroundColor3 = WHITE, Text = "", AutoButtonColor = true, Parent = parent },
		{ corner(0.3), stroke(DARK, 3) })
	local g = grad(c1, c2)
	g.Parent = b
	local l = new("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextWrapped = true, TextColor3 = WHITE,
		TextStrokeTransparency = 0.1, TextStrokeColor3 = DARK, Text = text, Parent = b },
		{ new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })
	return b, g, l
end

local coinsLbl = new("TextLabel", { Position = UDim2.new(0, 12, 0.3, 0), Size = UDim2.new(0, 200, 0, 42), BackgroundColor3 = DARK, BackgroundTransparency = 0.12, Font = FONT, TextScaled = true,
	TextColor3 = GOLD, Text = "💰 0", Parent = hud }, { corner(0.35), padding(6), stroke(GOLD, 2) })
local coinsScale = new("UIScale", { Parent = coinsLbl })
local luckBtn, _, luckTxt = button(hud, nil, UDim2.new(0, 12, 0.3, 50), UDim2.new(0, 200, 0, 46), "🍀 Удача ×2 — 50", Color3.fromRGB(140, 240, 160), Color3.fromRGB(40, 160, 80))
local summonBtn = button(hud, nil, UDim2.new(0, 12, 0.3, 104), UDim2.new(0, 200, 0, 58), "🍰 Призвать Рю (ТЕСТ)", Color3.fromRGB(200, 245, 255), Color3.fromRGB(70, 130, 220))

---------------------------------------------------------------- лента ролла
local CARD, GAP, NCARDS, WIN = 112, 10, 52, 44
local STEP = CARD + GAP
local REEL_H, CARD_H = 150, 116

local reelWrap = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100), Size = UDim2.new(0.52, 0, 0, REEL_H), BackgroundTransparency = 1, Parent = hud },
	{ new("UISizeConstraint", { MinSize = Vector2.new(360, REEL_H), MaxSize = Vector2.new(920, REEL_H) }) })
local reelGlow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 18, 1, 18), BackgroundColor3 = PURPLE, BackgroundTransparency = 0.8,
	BorderSizePixel = 0, Parent = reelWrap }, { corner(0.16) })
local reel = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = WHITE, ClipsDescendants = true, Parent = reelWrap },
	{ corner(0.1), grad(Color3.fromRGB(58, 46, 98), Color3.fromRGB(18, 14, 32)) })
local reelStroke = new("UIStroke", { Color = PURPLE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = reel })
-- «прожектор» под указателем: цвет редкости карточки, что сейчас под ним
local spot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, CARD + 60, 1, 0), BackgroundColor3 = PURPLE, BackgroundTransparency = 0.5,
	BorderSizePixel = 0, ZIndex = 1, Parent = reel },
	{ new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 1) }) }) })
local strip = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, NCARDS * STEP, 0, CARD_H), BackgroundTransparency = 1, ZIndex = 2, Parent = reel })
new("Frame", { Size = UDim2.new(0.2, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(14, 10, 26), BorderSizePixel = 0, ZIndex = 4, Parent = reel },
	{ new("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.2, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(14, 10, 26), BorderSizePixel = 0, ZIndex = 4, Parent = reel },
	{ new("UIGradient", { Transparency = NumberSequence.new(1, 0) }) })
local reelIdle = new("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(220, 210, 255),
	Text = "Нажми 🎲 РОЛЛ и выбей стихию!", ZIndex = 5, Parent = reel }, { tstroke(3), new("UIPadding", { PaddingTop = UDim.new(0.3, 0), PaddingBottom = UDim.new(0.3, 0), PaddingLeft = UDim.new(0.06, 0), PaddingRight = UDim.new(0.06, 0) }) })
local marker = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 6, Parent = reel })
local markerScale = new("UIScale", { Parent = marker })
local pins = {}
for _, topSide in ipairs({ true, false }) do
	table.insert(pins, new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, topSide and 0 or 1, 0), Size = UDim2.new(0, 18, 0, 18), Rotation = 45,
		BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 7, Parent = reel }, { stroke(DARK, 2) }))
end

-- надпись «ВЫПАЛО» над лентой
local banner = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -262), Size = UDim2.new(0, 460, 0, 66), BackgroundTransparency = 1, Visible = false, Parent = hud })
local bannerScale = new("UIScale", { Parent = banner })
local bannerTitle = new("TextLabel", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "", Parent = banner }, { tstroke(3.5) })
local bannerSub = new("TextLabel", { Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "", Parent = banner }, { tstroke(2) })

-- кнопки РОЛЛ и АВТО
local rollBtn, rollGrad, rollTxt = button(hud, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -18), UDim2.new(0, 230, 0, 72), "🎲 РОЛЛ", Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 130, 40))
rollGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 50)), ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 190, 70)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 245, 190)), ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 190, 70)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 40)) })
rollGrad.Rotation = 20
local rollScale = new("UIScale", { Parent = rollBtn })
if not TOUCH then
	new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 6), Size = UDim2.new(0, 30, 0, 22), BackgroundColor3 = DARK, Font = FONT, TextScaled = true, Text = "R",
		TextColor3 = WHITE, ZIndex = 3, Parent = rollBtn }, { corner(0.4), stroke(WHITE, 1.5) })
end
local autoBtn, autoGrad, autoTxt = button(hud, Vector2.new(0, 1), UDim2.new(0.5, 128, 1, -26), UDim2.new(0, 120, 0, 56), "АВТО: ВЫКЛ", Color3.fromRGB(170, 170, 190), Color3.fromRGB(90, 90, 110))

---------------------------------------------------------------- справа снизу: кнопки боя
local cluster = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, TOUCH and -150 or -14), Size = UDim2.new(0, 214, 0, 214), BackgroundTransparency = 1, Parent = hud })
local function actionButton(pos, size, color, icon, title, key)
	local b = new("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = pos, Size = UDim2.new(0, size, 0, size), BackgroundColor3 = WHITE, Text = "", AutoButtonColor = true, Parent = cluster }, { corner(1) })
	local st = new("UIStroke", { Color = DARK, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	local g = new("UIGradient", { Color = ColorSequence.new(lighter(color, 0.3), darker(color, 0.3)), Rotation = 90, Parent = b })
	local ic = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.1, 0), Size = UDim2.new(0.46, 0, 0.4, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
		Text = icon, TextColor3 = WHITE, Parent = b })
	local tl = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.84, 0, 0.27, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
		TextWrapped = true, Text = title, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = DARK, Parent = b })
	local kb = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(0, 36, 0, 20), BackgroundColor3 = DARK, Font = FONT, TextScaled = true,
		Text = key, TextColor3 = WHITE, Visible = not TOUCH, ZIndex = 6, Parent = b }, { corner(0.5), stroke(WHITE, 1.5) })
	local cd = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, Visible = false, ZIndex = 5, Parent = b }, { corner(1) })
	local cdt = new("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "", TextColor3 = WHITE, TextStrokeTransparency = 0,
		TextStrokeColor3 = DARK, ZIndex = 5, Parent = cd }, { new("UIPadding", { PaddingTop = UDim.new(0.28, 0), PaddingBottom = UDim.new(0.28, 0) }) })
	local sc = new("UIScale", { Parent = b })
	return { btn = b, stroke = st, grad = g, icon = ic, title = tl, key = kb, cd = cd, cdText = cdt, scale = sc, readyAt = 0, total = 1 }
end
local slapB = actionButton(UDim2.new(1, 0, 1, 0), 96, Color3.fromRGB(255, 150, 120), "✋", "УДАР", "F")
local abilB = actionButton(UDim2.new(1, -106, 1, 0), 92, PURPLE, "?", "НЕТ", "E")
local RYU_MOVES = {}
for _, m in ipairs(Abilities.RyuMoves) do RYU_MOVES[m.kind] = m end
local ryuB = {
	ryu1 = actionButton(UDim2.new(1, -106, 1, 0), 88, RYU_MOVES.ryu1.color, "🍰", "ДЕСЕРТ", "1"),
	ryu2 = actionButton(UDim2.new(1, 0, 1, -106), 88, RYU_MOVES.ryu2.color, "👊", "ВОТ КАКОВ ДЕСЕРТ!", "2"),
	ryu3 = actionButton(UDim2.new(1, -100, 1, -100), 108, RYU_MOVES.ryu3.color, "💥", "ГРАНИТНЫЙ ЗАЛП", "G"),
}
for _, b in pairs(ryuB) do b.btn.Visible = false end
local allButtons = { slapB, abilB, ryuB.ryu1, ryuB.ryu2, ryuB.ryu3 }
local buffLbl = new("TextLabel", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 0, -8), Size = UDim2.new(0, 220, 0, 30), BackgroundColor3 = Color3.fromRGB(120, 40, 90), BackgroundTransparency = 0.15,
	Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(255, 200, 230), Text = "", Visible = false, Parent = cluster }, { corner(0.4), padding(4), stroke(Color3.fromRGB(255, 160, 210), 2) })
local buffUntil = 0

---------------------------------------------------------------- большой показ (рубашка → переворот → способность)
local reveal = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = BLACK, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 40, Parent = top })
local rays = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.46, 0), Size = UDim2.new(0, 1000, 0, 1000), BackgroundTransparency = 1, Parent = reveal })
local rayList = {}
for i = 0, 11 do
	table.insert(rayList, new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 74, 1, 0), Rotation = i * 15, BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.72, BorderSizePixel = 0, Parent = rays },
		{ new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 1) }), Rotation = 90 }) }))
end
local bigCard = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.46, 0), Size = UDim2.new(0, 270, 0, 350), BackgroundColor3 = WHITE, Parent = reveal }, { corner(0.07) })
local bigGrad = new("UIGradient", { Rotation = 90, Parent = bigCard })
local bigStroke = new("UIStroke", { Thickness = 6, Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = bigCard })
local bigScale = new("UIScale", { Parent = bigCard })
-- рубашка карты
local back = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = bigCard })
local backQ = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.45, 0), Size = UDim2.new(0.6, 0, 0.45, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
	Text = "?", TextColor3 = WHITE, Parent = back }, { tstroke(4) })
local backTxt = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.76, 0), Size = UDim2.new(0.8, 0, 0.09, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
	Text = "...", TextColor3 = WHITE, Parent = back }, { tstroke(2) })
-- лицевая сторона
local front = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, Parent = bigCard })
local fIconBg = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.2, 0), Size = UDim2.new(0, 116, 0, 116), BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, Parent = front }, { corner(1) })
local fIcon = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.2, 0), Size = UDim2.new(0, 88, 0, 88), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "", Parent = front })
local fRarity = new("TextLabel", { Position = UDim2.new(0, 10, 0.38, 0), Size = UDim2.new(1, -20, 0, 30), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "", Parent = front }, { tstroke(3) })
local fName = new("TextLabel", { Position = UDim2.new(0, 10, 0.47, 0), Size = UDim2.new(1, -20, 0, 54), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "", TextColor3 = WHITE, Parent = front }, { tstroke(4) })
local fRainbow = new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 140)), ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)) }), Enabled = false, Parent = fName })
local fChance = new("TextLabel", { Position = UDim2.new(0, 10, 0.63, 0), Size = UDim2.new(1, -20, 0, 24), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "", TextColor3 = Color3.fromRGB(230, 230, 240), Parent = front }, { tstroke(2) })
local fDesc = new("TextLabel", { Position = UDim2.new(0, 14, 0.71, 0), Size = UDim2.new(1, -28, 0, 50), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextScaled = true, TextWrapped = true,
	Text = "", TextColor3 = Color3.fromRGB(215, 215, 230), Parent = front })
local fReward = new("TextLabel", { Position = UDim2.new(0, 10, 0.87, 0), Size = UDim2.new(1, -20, 0, 30), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "", TextColor3 = GOLD, Parent = front }, { tstroke(2.5) })
local fRecord = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -20, 0, 14), Size = UDim2.new(0, 150, 0, 30), Rotation = 14, BackgroundColor3 = Color3.fromRGB(235, 60, 80),
	Font = FONT, TextScaled = true, Text = "НОВЫЙ РЕКОРД!", TextColor3 = WHITE, Visible = false, ZIndex = 3, Parent = front }, { corner(0.3), padding(4), stroke(WHITE, 2) })
local revealHint = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.46, 196), Size = UDim2.new(0, 300, 0, 22), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
	Text = "нажми, чтобы продолжить", TextColor3 = Color3.fromRGB(200, 200, 215), Visible = false, Parent = reveal }, { tstroke(2) })

local blurFx = nil
local function setBlur(size, t)
	local camNow = workspace.CurrentCamera
	if not blurFx or blurFx.Parent ~= camNow then
		if blurFx then blurFx:Destroy() end
		blurFx = new("BlurEffect", { Size = 0, Parent = camNow })
	end
	tween(blurFx, t or 0.3, { Size = size })
end

local function sparkles(color, n)
	for i = 1, n do
		local ang = math.random() * math.pi * 2
		local d = 180 + math.random() * 300
		local sz = 6 + math.random() * 12
		local p = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.46, 0), Size = UDim2.new(0, sz, 0, sz), Rotation = math.random() * 90,
			BackgroundColor3 = (i % 3 == 0) and WHITE or color, BorderSizePixel = 0, Parent = reveal })
		tween(p, 0.9 + math.random() * 0.6, { Position = UDim2.new(0.5, math.cos(ang) * d, 0.46, math.sin(ang) * d), BackgroundTransparency = 1, Rotation = math.random() * 360 }, Enum.EasingStyle.Quart)
		task.delay(1.6, function() p:Destroy() end)
	end
end

local revealOpen = false
local function bigReveal(a, res, summon)
	local r = rarityOf(a)
	local special = (a.rarity == "mythic" or a.rarity == "secret")
	revealOpen = false
	reveal.Visible = true
	reveal.BackgroundTransparency = 1
	tween(reveal, 0.3, { BackgroundTransparency = 0.3 })
	setBlur(18, 0.4)
	for _, ray in ipairs(rayList) do ray.BackgroundColor3 = r.color end
	-- рубашка: дрожит, стук всё чаще
	back.Visible, front.Visible = true, false
	bigGrad.Color = ColorSequence.new(Color3.fromRGB(70, 60, 110), Color3.fromRGB(20, 16, 36))
	bigStroke.Color = r.color
	backQ.TextColor3 = r.color
	backTxt.Text = summon and "ПРИЗЫВ..." or "..."
	bigCard.Size = UDim2.new(0, 270, 0, 350)
	bigCard.Rotation = 0
	bigScale.Scale = 0.2
	revealHint.Visible = false
	tween(bigScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	local wob = summon and 1.2 or (special and 1.3 or 0.85)
	local t0, beat = os.clock(), 0
	while os.clock() - t0 < wob do
		local e = os.clock() - t0
		local k = e / wob
		bigCard.Rotation = math.sin(e * 45) * 5 * k
		rays.Rotation = e * 20
		bigStroke.Thickness = 6 + math.sin(e * 30) * 2 * k
		if e > beat then beat = beat + 0.25 * (1 - k * 0.6); play(sTick, 0.6 + k * 0.8) end
		RunService.RenderStepped:Wait()
	end
	bigCard.Rotation = 0
	bigStroke.Thickness = 6
	-- переворот карты
	tween(bigCard, 0.12, { Size = UDim2.new(0, 0, 0, 350) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.12)
	back.Visible, front.Visible = false, true
	bigGrad.Color = ColorSequence.new(darker(a.color, 0.35), Color3.fromRGB(18, 14, 32))
	fIconBg.BackgroundColor3 = r.color
	fIcon.Text = a.icon or ""
	fRarity.Text = summon and "СЕКРЕТНЫЙ ПЕРСОНАЖ!" or (upper(r.name) .. "!")
	fRarity.TextColor3 = r.color
	fName.Text = upper(a.name)
	fName.TextColor3 = special and WHITE or a.color
	fRainbow.Enabled = special
	fChance.Text = a.character and "Рю Исигори · «Магическая битва»" or Abilities.chanceText(a)
	fDesc.Text = a.character and "[1] Десерт   [2] Вот каков десерт!   [G] Гранитный залп" or a.desc
	fReward.Text = (res and res.coins) and ("+" .. res.coins .. " монет") or ""
	fRecord.Visible = (res and res.newBest) and true or false
	tween(bigCard, 0.3, { Size = UDim2.new(0, 270, 0, 350) }, Enum.EasingStyle.Back)
	play(sWin, 0.5)
	doFlash(a.color, 0.05, 0.9)
	addShake(special and 1.4 or 0.8)
	sparkles(r.color, special and 44 or 28)
	-- держим, пока не нажмут (или 4 секунды)
	revealOpen = true
	revealHint.Visible = true
	local t1 = os.clock()
	while revealOpen and os.clock() - t1 < 4 do
		local e = os.clock() - t1
		rays.Rotation = (wob + e) * 20
		if special then
			for i, ray in ipairs(rayList) do ray.BackgroundColor3 = Color3.fromHSV((e * 0.25 + i / 12) % 1, 0.55, 1) end
			fRainbow.Offset = Vector2.new(math.sin(e * 2) * 0.5, 0)
		end
		fIcon.Position = UDim2.new(0.5, 0, 0.2, math.sin(e * 4) * 4)
		fIconBg.Size = UDim2.new(0, 116 + math.sin(e * 6) * 6, 0, 116 + math.sin(e * 6) * 6)
		RunService.RenderStepped:Wait()
	end
	revealOpen = false
	tween(reveal, 0.25, { BackgroundTransparency = 1 })
	tween(bigScale, 0.22, { Scale = 0.1 })
	setBlur(0, 0.3)
	task.wait(0.25)
	reveal.Visible = false
end
reveal.MouseButton1Click:Connect(function() revealOpen = false end)

---------------------------------------------------------------- окно «Вы точно хотите прокрутить?»
local modal = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = BLACK, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 60, Parent = top })
local panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 440, 0, 290), BackgroundColor3 = WHITE, Parent = modal },
	{ corner(0.08), grad(Color3.fromRGB(64, 50, 110), Color3.fromRGB(24, 19, 42)) })
local panelStroke = new("UIStroke", { Color = GOLD, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = panel })
local panelScale = new("UIScale", { Parent = panel })
new("TextLabel", { Position = UDim2.new(0, 16, 0, 14), Size = UDim2.new(1, -32, 0, 40), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = WHITE,
	Text = "Вы точно хотите прокрутить?", Parent = panel }, { tstroke(3) })
local mini = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.new(1, -40, 0, 92), BackgroundColor3 = WHITE, Parent = panel }, { corner(0.18) })
local miniGrad = new("UIGradient", { Rotation = 90, Parent = mini })
local miniStroke = new("UIStroke", { Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = mini })
local miniIcon = new("TextLabel", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.new(0, 68, 0, 68), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "", Parent = mini })
local miniName = new("TextLabel", { Position = UDim2.new(0, 92, 0, 10), Size = UDim2.new(1, -104, 0, 42), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
	Text = "", Parent = mini }, { tstroke(3) })
local miniInfo = new("TextLabel", { Position = UDim2.new(0, 92, 0, 54), Size = UDim2.new(1, -104, 0, 26), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
	Text = "", Parent = mini }, { tstroke(2) })
new("TextLabel", { Position = UDim2.new(0, 16, 0, 164), Size = UDim2.new(1, -32, 0, 26), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(255, 175, 150),
	Text = "Если прокрутишь — она пропадёт навсегда!", Parent = panel }, { tstroke(2) })
local yesBtn = button(panel, Vector2.new(0, 1), UDim2.new(0, 16, 1, -16), UDim2.new(0.5, -24, 0, 62), "ДА, КРУТИТЬ", Color3.fromRGB(255, 150, 110), Color3.fromRGB(220, 50, 60))
local noBtn = button(panel, Vector2.new(1, 1), UDim2.new(1, -16, 1, -16), UDim2.new(0.5, -24, 0, 62), "НЕТ, ОСТАВИТЬ", Color3.fromRGB(150, 245, 160), Color3.fromRGB(40, 160, 80))
local confirmAnswer = nil
yesBtn.MouseButton1Click:Connect(function() confirmAnswer = true end)
noBtn.MouseButton1Click:Connect(function() confirmAnswer = false end)

local function askConfirm(a)
	local r = rarityOf(a)
	miniGrad.Color = ColorSequence.new(darker(a.color, 0.3), darker(a.color, 0.75))
	miniStroke.Color = r.color
	miniIcon.Text = a.icon or ""
	miniName.Text = "Сейчас у тебя: " .. a.name
	miniName.TextColor3 = WHITE
	miniInfo.Text = a.character and (r.name .. "  ·  персонаж") or (r.name .. "  ·  " .. Abilities.chanceText(a))
	miniInfo.TextColor3 = r.color
	confirmAnswer = nil
	modal.Visible = true
	modal.BackgroundTransparency = 1
	tween(modal, 0.2, { BackgroundTransparency = 0.45 })
	panelScale.Scale = 0.6
	tween(panelScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	play(sTick, 0.8)
	local t0 = os.clock()
	while confirmAnswer == nil do
		local k = (math.sin((os.clock() - t0) * 5) + 1) / 2
		panelStroke.Color = GOLD:Lerp(r.color, k)
		RunService.RenderStepped:Wait()
	end
	tween(panelScale, 0.15, { Scale = 0.7 })
	tween(modal, 0.15, { BackgroundTransparency = 1 })
	task.wait(0.15)
	modal.Visible = false
	return confirmAnswer
end

---------------------------------------------------------------- кинорамка (полосы сверху/снизу и титры)
local barTop = new("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 30, Parent = top })
local barBot = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 30, Parent = top })
local cineTitle = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.78, 0), Size = UDim2.new(0.7, 0, 0.1, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
	Text = "", TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = DARK, Visible = false, ZIndex = 31, Parent = top })
local cineTitleScale = new("UIScale", { Parent = cineTitle })
local cineSub = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.945, 0), Size = UDim2.new(0.6, 0, 0.045, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
	Text = "", TextColor3 = Color3.fromRGB(200, 200, 215), Visible = false, ZIndex = 31, Parent = top })

local function bars(on)
	local s = on and UDim2.new(1, 0, 0.11, 0) or UDim2.new(1, 0, 0, 0)
	tween(barTop, 0.3, { Size = s })
	tween(barBot, 0.3, { Size = s })
end
local function cineText(title, sub, color)
	cineTitle.Text = title
	cineTitle.TextColor3 = color or WHITE
	cineTitle.TextTransparency = 1
	cineTitle.TextStrokeTransparency = 1
	cineTitleScale.Scale = 2.4
	cineTitle.Visible = true
	tween(cineTitle, 0.2, { TextTransparency = 0, TextStrokeTransparency = 0 })
	tween(cineTitleScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	cineSub.Text = sub or ""
	cineSub.Visible = true
end
local function cineTextHide()
	tween(cineTitle, 0.2, { TextTransparency = 1, TextStrokeTransparency = 1 })
	cineSub.Visible = false
end

---------------------------------------------------------------- данные
local rolling = false
local pending = nil
local lastEq = nil

local function updateActionBar()
	local a = Abilities.ById[data.equipped or ""]
	local isRyu = a ~= nil and a.id == "Ryu"
	abilB.btn.Visible = not isRyu
	for _, b in pairs(ryuB) do b.btn.Visible = isRyu end
	if a and not a.character then
		abilB.icon.Text = a.icon or "?"
		abilB.title.Text = upper(a.name)
		abilB.grad.Color = ColorSequence.new(lighter(a.color, 0.3), darker(a.color, 0.3))
	elseif not a then
		abilB.icon.Text = "?"
		abilB.title.Text = "НЕТ"
		abilB.grad.Color = ColorSequence.new(lighter(PURPLE, 0.3), darker(PURPLE, 0.3))
	end
end

local function refreshEquipped()
	local a = Abilities.ById[data.equipped or ""]
	if a then
		local r = rarityOf(a)
		eqLbl.Text = (a.character and "Персонаж: " or "Способность: ") .. (a.icon or "") .. " " .. a.name .. "  ·  " .. r.name .. (a.character and "" or (" (" .. Abilities.chanceText(a) .. ")"))
		eqLbl.TextColor3 = a.color
		eqStroke.Color = r.color
	else
		eqLbl.Text = "Способность: нет — нажми РОЛЛ!"
		eqLbl.TextColor3 = WHITE
		eqStroke.Color = PURPLE
	end
	updateActionBar()
	if data.equipped == "Ryu" and lastEq ~= "Ryu" then
		announce("Рю: [1] Десерт · [2] Вот каков десерт! · [G] ГРАНИТНЫЙ ЗАЛП", Color3.fromRGB(150, 220, 255), true)
	end
	lastEq = data.equipped
end

local function applyData(p)
	if not p then return end
	if rolling then pending = p; return end   -- не портим сюрприз, пока крутится лента
	data = p
	luckEnds = os.clock() + (p.luckLeft or 0)
	coinsLbl.Text = "💰 " .. tostring(p.coins or 0)
	refreshEquipped()
end
local function flushPending()
	if pending then
		local p = pending
		pending = nil
		applyData(p)
	end
end
R.DataUpdate.OnClientEvent:Connect(applyData)
task.spawn(function()
	for _ = 1, 30 do
		local p = R.GetData:InvokeServer()
		if p then applyData(p); break end
		task.wait(1)
	end
end)

-- таймер удачи
task.spawn(function()
	while true do
		local left = luckEnds - os.clock()
		if left > 0 then
			luckTxt.Text = string.format("🍀 Удача ×2: %d:%02d", math.floor(left / 60), math.floor(left % 60))
		else
			luckTxt.Text = "🍀 Удача ×2 — " .. tostring(data.luckCost or 50)
		end
		task.wait(0.5)
	end
end)
luckBtn.MouseButton1Click:Connect(function()
	local ok = R.BuyLuck:InvokeServer()
	if not ok then hint("Не хватает монет! Сбивай врагов (+" .. CFG.KillCoins .. ") и манекены (+" .. CFG.DummyCoins .. ") и крути ролл.", Color3.fromRGB(255, 130, 130)) end
end)

---------------------------------------------------------------- РОЛЛ: карточки
local rollable = Abilities.sortedByRarity()
-- «пустые» карточки: частые встречаются чаще, но и редкие мелькают (так интереснее)
local function fillWeight(a) return a.chance ^ -0.55 end
local totalW = 0
for _, a in ipairs(rollable) do totalW = totalW + fillWeight(a) end
local function fillerPick(minChance)
	for _ = 1, 30 do
		local r, acc = math.random() * totalW, 0
		for _, a in ipairs(rollable) do
			acc = acc + fillWeight(a)
			if r <= acc then
				if not minChance or a.chance >= minChance then return a end
				break
			end
		end
	end
	return rollable[math.random(1, 3)]
end

local function makeCard(a, i)
	local r = rarityOf(a)
	local x = (i - 1) * STEP + CARD / 2
	local c = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, x, 0.5, 0), Size = UDim2.new(0, CARD, 1, 0), BackgroundColor3 = WHITE, Parent = strip },
		{ corner(0.12), new("UIGradient", { Color = ColorSequence.new(darker(lighter(a.color, 0.1), 0.35), darker(a.color, 0.8)), Rotation = 90 }) })
	new("UIStroke", { Color = r.color, Thickness = (r.order >= 3) and 3 or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = c })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.3, 0), Size = UDim2.new(0, 60, 0, 60), BackgroundColor3 = r.color, BackgroundTransparency = 0.72, Parent = c }, { corner(1) })
	local icon = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.3, 0), Size = UDim2.new(0, 46, 0, 46), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
		Text = a.icon or "", Parent = c })
	local name = new("TextLabel", { Position = UDim2.new(0, 5, 0.56, 0), Size = UDim2.new(1, -10, 0.2, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = WHITE,
		Text = a.name, Parent = c }, { tstroke(2) })
	new("TextLabel", { Position = UDim2.new(0, 5, 0.76, 0), Size = UDim2.new(1, -10, 0.13, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = r.color,
		Text = Abilities.chanceText(a), Parent = c }, { tstroke(1.5) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(0.7, 0, 0, 4), BackgroundColor3 = r.color, BorderSizePixel = 0, Parent = c }, { corner(1) })
	local clip = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3, Parent = c })
	local shine = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(-0.6, 0, 0.5, 0), Size = UDim2.new(0.35, 0, 1.6, 0), Rotation = 18, BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false, Parent = clip },
		{ new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1) }) }) })
	local fl = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 4, Parent = c }, { corner(0.12) })
	local dim = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = BLACK, BackgroundTransparency = 1, ZIndex = 5, Parent = c }, { corner(0.12) })
	local sc = new("UIScale", { Scale = 0.845, Parent = c })
	return { frame = c, scale = sc, a = a, x = x, icon = icon, name = name, shine = shine, flash = fl, dim = dim }
end

local function buildStrip(final)
	for _, ch in ipairs(strip:GetChildren()) do ch:Destroy() end
	local cards = {}
	for i = 1, NCARDS do
		local a = fillerPick()
		if i == WIN then a = final
		elseif i == WIN + 1 and math.random() < 0.6 then a = fillerPick(25)   -- «чуть-чуть не повезло» рядом с выигрышем
		elseif i == WIN - 1 and math.random() < 0.4 then a = fillerPick(25) end
		cards[i] = makeCard(a, i)
	end
	return cards
end

---------------------------------------------------------------- РОЛЛ: движение ленты
local reelSt = { c = 0, idx = 0, cards = nil, W = 0 }
local function idxAt(c) return math.floor((c + GAP / 2) / STEP) + 1 end

-- c — координата ленты под указателем
local function setCenter(c, dt)
	local st = reelSt
	local vel = (dt and dt > 0) and math.abs(c - st.c) / dt or 0
	st.c = c
	strip.Position = UDim2.new(0, st.W / 2 - c, 0.5, 0)
	local cards = st.cards
	local half = st.W / 2 / STEP + 2
	local i0 = math.max(1, math.floor(c / STEP - half))
	local i1 = math.min(#cards, math.ceil(c / STEP + half) + 1)
	local blur = math.clamp((vel - 500) / 2200, 0, 0.75)    -- на большой скорости надписи «смазываются»
	for i = i0, i1 do
		local cd = cards[i]
		local d = math.abs(cd.x - c) / STEP
		cd.scale.Scale = 1.1 - math.min(d, 3) * 0.085          -- карусель: в центре крупнее
		cd.icon.TextTransparency = blur
		cd.name.TextTransparency = blur
	end
	local idx = idxAt(c)
	if idx ~= st.idx then
		st.idx = idx
		local cd = cards[idx]
		if cd then
			local col = rarityOf(cd.a).color
			reelStroke.Color = col
			spot.BackgroundColor3 = col
		end
		play(sTick, 1.2 + math.min(idx, WIN) / WIN * 0.7)
		for _, p in ipairs(pins) do
			p.Size = UDim2.new(0, 26, 0, 26)
			tween(p, 0.12, { Size = UDim2.new(0, 18, 0, 18) })
		end
	end
end

local function easeOut(p) return function(u) return 1 - (1 - u) ^ p end end
local function easeInOut(u) return (1 - math.cos(math.pi * u)) / 2 end

local function moveTo(toC, dur, ease)
	local fromC = reelSt.c
	local t0 = os.clock()
	local last = t0
	while true do
		local now = os.clock()
		local u = math.min(1, (now - t0) / dur)
		setCenter(fromC + (toC - fromC) * ease(u), now - last)
		last = now
		if u >= 1 then break end
		RunService.RenderStepped:Wait()
	end
end

-- пауза-интрига: лента замерла у самой границы, сердце стучит
local function suspense(t)
	local t0, beat = os.clock(), 0
	reelGlow.BackgroundColor3 = WHITE
	while os.clock() - t0 < t do
		local e = os.clock() - t0
		local k = (math.sin(e * 22) + 1) / 2
		reelGlow.BackgroundTransparency = 0.35 + k * 0.4
		markerScale.Scale = 1 + k * 0.3
		if e > beat then beat = beat + 0.22; play(sTick, 0.55) end
		RunService.RenderStepped:Wait()
	end
	markerScale.Scale = 1
end

local bannerToken = 0
local function showBanner(a, res)
	local r = rarityOf(a)
	bannerToken = bannerToken + 1
	local my = bannerToken
	bannerTitle.Text = "ВЫПАЛО: " .. (a.icon or "") .. " " .. upper(a.name)
	bannerTitle.TextColor3 = a.color
	bannerSub.Text = r.name .. " · " .. Abilities.chanceText(a) .. ((res and res.coins) and ("  ·  +" .. res.coins .. " монет") or "")
	bannerSub.TextColor3 = r.color
	bannerTitle.TextTransparency, bannerSub.TextTransparency = 0, 0
	banner.Visible = true
	bannerScale.Scale = 0.3
	tween(bannerScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.8, function()
		if bannerToken ~= my then return end
		tween(bannerTitle, 0.4, { TextTransparency = 1 })
		tween(bannerSub, 0.4, { TextTransparency = 1 })
		task.wait(0.45)
		if bannerToken == my then banner.Visible = false end
	end)
end

local function coinFly(n)
	local from = reel.AbsolutePosition + reel.AbsoluteSize / 2
	local to = coinsLbl.AbsolutePosition + coinsLbl.AbsoluteSize / 2
	local l = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(from.X, from.Y - 50), Size = UDim2.fromOffset(170, 40), BackgroundTransparency = 1,
		Font = FONT, TextScaled = true, Text = "+" .. n .. " 💰", TextColor3 = GOLD, ZIndex = 20, Parent = gui }, { tstroke(3) })
	local sc = new("UIScale", { Scale = 0.4, Parent = l })
	tween(sc, 0.3, { Scale = 1.2 }, Enum.EasingStyle.Back)
	task.delay(0.5, function()
		tween(l, 0.55, { Position = UDim2.fromOffset(to.X, to.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(sc, 0.55, { Scale = 0.5 })
	end)
	task.delay(1.05, function()
		l:Destroy()
		coinsScale.Scale = 1.25
		tween(coinsScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		play(sTick, 2)
	end)
end

local function land(cards, final, res, fast)
	local r = rarityOf(final)
	local win = cards[WIN]
	for i, cd in ipairs(cards) do
		if i ~= WIN then tween(cd.dim, 0.35, { BackgroundTransparency = 0.45 }) end
	end
	win.scale.Scale = 1.34
	tween(win.scale, 0.5, { Scale = 1.2 }, Enum.EasingStyle.Back)
	win.flash.BackgroundTransparency = 0.05
	tween(win.flash, 0.5, { BackgroundTransparency = 1 })
	win.shine.Visible = true
	win.shine.Position = UDim2.new(-0.6, 0, 0.5, 0)
	tween(win.shine, 0.6, { Position = UDim2.new(1.6, 0, 0.5, 0) }, Enum.EasingStyle.Sine)
	reelStroke.Color = r.color
	spot.BackgroundColor3 = r.color
	reelGlow.BackgroundColor3 = r.color
	reelGlow.BackgroundTransparency = 0.15
	tween(reelGlow, 1.4, { BackgroundTransparency = 0.8 })
	play(sWin, final.chance >= 50 and 0.7 or 1.1)
	showBanner(final, res)
	if res and res.coins then coinFly(res.coins) end
	if final.chance >= CFG.ConfirmChance and (not fast or final.chance >= 120) then
		task.wait(0.35)
		bigReveal(final, res, false)
	elseif final.chance >= 6 then
		doFlash(final.color, 0.6, 0.6)
	end
	if res and res.newBest and final.chance >= 6 then announce("Новый рекорд: " .. (final.icon or "") .. " " .. final.name .. "!", final.color, false) end
end

local function spin(final, res, fast)
	reelIdle.Visible = false
	banner.Visible = false
	bannerToken = bannerToken + 1
	reelGlow.BackgroundColor3 = PURPLE
	reelGlow.BackgroundTransparency = 0.8
	local cards = buildStrip(final)
	reelSt.cards = cards
	reelSt.W = reel.AbsoluteSize.X
	reelSt.idx = 0
	local cx = (WIN - 1) * STEP + CARD / 2 + (math.random() - 0.5) * CARD * 0.5    -- где именно на карточке остановится указатель
	setCenter(2 * STEP + CARD / 2, 0)
	local rare = final.chance >= CFG.ConfirmChance
	if fast then
		moveTo(cx + 12, 2.0, easeOut(3.5))
		moveTo(cx, 0.25, easeInOut)
	elseif rare then
		-- замирает на соседней карточке у самой границы... пауза... и переползает на редкую
		local edge = (WIN - 1) * STEP - GAP - 4
		moveTo(edge, 4.6, easeOut(4.5))
		suspense(0.55)
		moveTo(cx, 0.75, easeInOut)
	else
		-- иногда проскакивает на соседнюю (часто редкую) карточку и откатывается назад
		local bnd = WIN * STEP - GAP / 2 - cx
		local over
		if math.random() < 0.35 then over = bnd + STEP * 0.14 else over = math.min(bnd * 0.6, STEP * 0.16) end
		moveTo(cx + over, 4.0, easeOut(4))
		moveTo(cx, over > bnd and 0.5 or 0.3, easeInOut)
	end
	land(cards, final, res, fast)
end

---------------------------------------------------------------- РОЛЛ: логика
local auto = false
local autoToken = 0

local function setRollText(t) rollTxt.Text = t end

local doRoll
local function setAuto(on)
	auto = on
	autoTxt.Text = on and "АВТО: ВКЛ" or "АВТО: ВЫКЛ"
	autoGrad.Color = on and ColorSequence.new(Color3.fromRGB(150, 245, 160), Color3.fromRGB(40, 160, 80)) or ColorSequence.new(Color3.fromRGB(170, 170, 190), Color3.fromRGB(90, 90, 110))
	autoToken = autoToken + 1
	local my = autoToken
	if on then
		task.spawn(function()
			while auto and autoToken == my do
				doRoll()
				task.wait(0.35)
			end
		end)
	end
end

doRoll = function()
	if rolling or cine then return end
	rolling = true
	setRollText("...")
	local res = R.Roll:InvokeServer(false)
	if res and res.needConfirm then
		local cur = Abilities.ById[res.current or ""]
		if auto then setAuto(false) end
		local yes = cur and askConfirm(cur)
		if not yes then
			rolling = false
			setRollText("🎲 РОЛЛ")
			flushPending()
			if cur then announce("Оставили: " .. (cur.icon or "") .. " " .. cur.name, cur.color, false) end
			return
		end
		res = R.Roll:InvokeServer(true)
	end
	if not res or not res.id then
		rolling = false
		setRollText("🎲 РОЛЛ")
		flushPending()
		return
	end
	local final = Abilities.ById[res.id]
	local ok, err = pcall(spin, final, res, auto)
	if not ok then warn("[RNG] Ошибка ленты: " .. tostring(err)) end
	task.wait(auto and 0.3 or 0.6)
	rolling = false
	setRollText("🎲 РОЛЛ")
	flushPending()
	if auto and final.chance >= CFG.ConfirmChance then
		setAuto(false)
		announce("Авто-ролл остановлен: выпала редкая способность!", final.color, false)
	end
end

rollBtn.MouseButton1Click:Connect(function() task.spawn(doRoll) end)
autoBtn.MouseButton1Click:Connect(function() setAuto(not auto) end)

-- блик бегает по кнопке РОЛЛ
task.spawn(function()
	while true do
		local t = os.clock()
		rollGrad.Offset = Vector2.new(((t * 0.6) % 2.4) - 1.2, 0)
		if not rolling then rollScale.Scale = 1 + math.sin(t * 3) * 0.03 end
		RunService.RenderStepped:Wait()
	end
end)

-- ТЕСТ: призвать Рю
summonBtn.MouseButton1Click:Connect(function()
	if rolling or cine then return end
	rolling = true
	local ok = R.Summon:InvokeServer("Ryu")
	if ok then
		local okR, err = pcall(bigReveal, Abilities.ById.Ryu, nil, true)
		if not okR then warn("[RNG] Ошибка показа: " .. tostring(err)) end
	end
	rolling = false
	flushPending()
end)

---------------------------------------------------------------- бой
local busyUntil = 0
local function inArena() return player:GetAttribute("InArena") == true end
local function press(b)
	b.scale.Scale = 0.85
	tween(b.scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function use(kind, fromClick)
	local now = os.clock()
	if cine or now < busyUntil then return end
	local eq = Abilities.ById[data.equipped or ""]
	local isRyu = (kind == "ryu1" or kind == "ryu2" or kind == "ryu3")
	local b, cd
	if isRyu then
		if not eq or eq.id ~= "Ryu" then return end
		b, cd = ryuB[kind], RYU_MOVES[kind].cooldown
	else
		if not inArena() then
			if not fromClick then hint("Сначала прыгни в портал — бой только на арене!") end
			return
		end
		if kind == "slap" then
			b, cd = slapB, Abilities.Slap.cooldown
		else
			if not eq then hint("Нет способности — нажми РОЛЛ!", Color3.fromRGB(255, 200, 80)); return end
			if eq.character then hint("У Рю приёмы на клавишах 1, 2 и G", Color3.fromRGB(150, 220, 255)); return end
			b, cd = abilB, eq.cooldown
		end
	end
	if now < b.readyAt then return end
	b.readyAt = now + cd
	b.total = cd
	press(b)
	if kind == "ryu1" then buffUntil = now + 10.7
	elseif kind == "ryu2" then busyUntil = now + 0.6; play(sLunge, 0.9)
	elseif kind == "ryu3" then busyUntil = now + 3.3 end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local dir = hrp and hrp.CFrame.LookVector or Vector3.new(0, 0, -1)
	R.Use:FireServer(kind, dir)
end

slapB.btn.MouseButton1Click:Connect(function() use("slap") end)
abilB.btn.MouseButton1Click:Connect(function() use("ability") end)
for kind, b in pairs(ryuB) do b.btn.MouseButton1Click:Connect(function() use(kind) end) end

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	local k = input.KeyCode
	if input.UserInputType == Enum.UserInputType.MouseButton1 then use("slap", true)
	elseif k == Enum.KeyCode.F then use("slap")
	elseif k == Enum.KeyCode.E then use("ability")
	elseif k == Enum.KeyCode.One then use("ryu1")
	elseif k == Enum.KeyCode.Two then use("ryu2")
	elseif k == Enum.KeyCode.G then use("ryu3")
	elseif k == Enum.KeyCode.R then task.spawn(doRoll) end
end)

-- перезарядки, свечение ульты, бафф десерта
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for _, b in ipairs(allButtons) do
		local left = b.readyAt - now
		if left > 0 then
			b.cd.Visible = true
			b.cd.BackgroundTransparency = 0.3 + 0.4 * (1 - left / b.total)
			b.cdText.Text = (left >= 10) and tostring(math.ceil(left)) or string.format("%.1f", left)
		elseif b.cd.Visible then
			b.cd.Visible = false
			b.scale.Scale = 1.15
			tween(b.scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end
	local ult = ryuB.ryu3
	if ult.btn.Visible and ult.readyAt <= now then
		local k = (math.sin(now * 5) + 1) / 2
		ult.stroke.Color = Color3.fromRGB(120, 220, 255):Lerp(WHITE, k)
		ult.stroke.Thickness = 4 + k * 3
	else
		ult.stroke.Color = DARK
		ult.stroke.Thickness = 4
	end
	local bl = buffUntil - now
	if bl > 0 and bl <= 10 then
		buffLbl.Visible = true
		buffLbl.Text = "🍰 Урон +20% · " .. math.ceil(bl) .. " с"
	else
		buffLbl.Visible = false
	end
end)

-- подсказка про портал и «тусклые» кнопки в лобби
local function updateArenaState()
	local a = inArena()
	hintLbl.Visible = not a
	slapB.btn.BackgroundTransparency = a and 0 or 0.5
	abilB.btn.BackgroundTransparency = a and 0 or 0.5
end
player:GetAttributeChangedSignal("InArena"):Connect(updateArenaState)
updateArenaState()

---------------------------------------------------------------- позы персонажей (всё видно всем: сервер ставит атрибут Pose)
-- Углы в градусах в осях «родительской» детали сустава: X — вправо, Y — вверх, −Z — вперёд.
-- Rx(+) поднимает руку/ногу вперёд; Rz(+) отводит правую руку в сторону (левую — Rz(−));
-- корпус/шея: Rx(−) — наклон вперёд, Ry(+) — правое плечо вперёд; локоть Rx(+) сгибает руку.
local function E(x, y, z) return CFrame.fromEulerAnglesYXZ(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0)) end
local POSES = {
	punchR    = { speed = 32, RS = E(92, -25, 0), RE = E(4), LS = E(50, 0, -15), LE = E(110), Waist = E(0, 25, 0), Neck = E(0, -18, 0), RH = E(-12), LH = E(22), LK = E(-18) },
	punchL    = { speed = 32, LS = E(92, 25, 0), LE = E(4), RS = E(50, 0, 15), RE = E(110), Waist = E(0, -25, 0), Neck = E(0, 18, 0), LH = E(-12), RH = E(22), RK = E(-18) },
	kick      = { speed = 26, RH = E(88), RK = E(0), LK = E(-14), Root = E(12), RS = E(35, 0, 45), LS = E(35, 0, -45), RE = E(60), LE = E(60) },
	uppercut  = { speed = 26, RS = E(168, -10, 0), RE = E(15), LS = E(20, 0, -25), LE = E(95), Waist = E(14, 22, 0), Neck = E(16), LH = E(22), LK = E(-25), RH = E(-14) },
	push      = { speed = 22, RS = E(88, 0, -8), LS = E(88, 0, 8), RE = E(8), LE = E(8), Waist = E(-10), LH = E(20), RH = E(-14) },
	slam      = { speed = 20, RS = E(-25, 0, 28), LS = E(-25, 0, -28), Waist = E(-32), Neck = E(22), Root = E(-8), RH = E(30), RK = E(-40), LH = E(-8), LK = E(-30) },
	point     = { speed = 20, RS = E(90), RE = E(0), LS = E(0, 0, -10), Waist = E(0, 14, 0), Neck = E(0, -10, 0) },
	-- Рю
	slide     = { speed = 22, Root = E(-30), Waist = E(-8), Neck = E(22), RS = E(-55, 0, 18), LS = E(-55, 0, -18), RE = E(20), LE = E(20), RH = E(-22), LH = E(38), LK = E(-42), RK = E(-28) },
	eat       = { speed = 14, RS = E(65, 0, -32), RE = E(125), LS = E(12, 0, -8), LE = E(35), Neck = E(-6) },
	stagger   = { speed = 24, Waist = E(18, -10, 0), Neck = E(24), RS = E(28, 0, 38), LS = E(28, 0, -38), RE = E(30), LE = E(30), Root = E(8) },
	stagger2  = { speed = 24, Waist = E(-28, 12, 0), Neck = E(-14), RS = E(38, 0, 12), LS = E(38, 0, -12), RE = E(60), LE = E(60), RH = E(15), RK = E(-20) },
	-- ульта: поправил кок → заряд в ладонях → луч
	ultHair   = { speed = 12, RS = E(150, 0, -28), RE = E(75), Neck = E(10, -12, 0), LS = E(8, 0, -30), LE = E(80), RH = E(0, 0, 10), LH = E(0, 0, -10) },
	ultCharge = { speed = 10, shake = 1.5, RS = E(72, 0, -30), LS = E(72, 0, 30), RE = E(40), LE = E(40), Waist = E(-8), Neck = E(-4), Root = E(-4),
		RH = E(-18, 0, 14), LH = E(28, 0, -14), LK = E(-28), RK = E(-10) },
	ultFire   = { speed = 26, shake = 2.5, RS = E(92, 0, -14), LS = E(92, 0, 14), RE = E(0), LE = E(0), Waist = E(-12), Neck = E(-4), Root = E(-8),
		RH = E(-25, 0, 10), LH = E(35, 0, -10), LK = E(-32) },
}
local R15J = { RS = { "RightUpperArm", "RightShoulder" }, LS = { "LeftUpperArm", "LeftShoulder" }, RE = { "RightLowerArm", "RightElbow" }, LE = { "LeftLowerArm", "LeftElbow" },
	RH = { "RightUpperLeg", "RightHip" }, LH = { "LeftUpperLeg", "LeftHip" }, RK = { "RightLowerLeg", "RightKnee" }, LK = { "LeftLowerLeg", "LeftKnee" },
	Waist = { "UpperTorso", "Waist" }, Neck = { "Head", "Neck" }, Root = { "LowerTorso", "Root" } }
local R6J = { RS = { "Torso", "Right Shoulder" }, LS = { "Torso", "Left Shoulder" }, RH = { "Torso", "Right Hip" }, LH = { "Torso", "Left Hip" },
	Neck = { "Torso", "Neck" }, Root = { "HumanoidRootPart", "RootJoint" } }

local poseStates = setmetatable({}, { __mode = "k" })
local function buildPoseState(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	local r6 = hum.RigType ~= Enum.HumanoidRigType.R15
	local joints, n = {}, 0
	for key, path in pairs(r6 and R6J or R15J) do
		local part = char:FindFirstChild(path[1])
		local m = part and part:FindFirstChild(path[2])
		if m and m:IsA("Motor6D") then
			local rot = m.C0 - m.C0.Position
			joints[key] = { motor = m, rot = rot, rinv = rot:Inverse(), cur = CFrame.new(), w = 0 }
			n = n + 1
		end
	end
	if n == 0 then return nil end
	return { joints = joints, r6 = r6, pose = nil, token = nil, start = 0, active = false }
end

local function poseTarget(def, key, r6)
	if r6 and key == "Root" then
		local a, b = def.Root, def.Waist     -- у R6 нет пояса — наклоняем весь корпус
		if a and b then return a * b end
		return a or b
	end
	return def[key]
end

-- Stepped идёт ПОСЛЕ анимаций: смешиваем анимацию с позой через Motor6D.Transform
RunService.Stepped:Connect(function(_, dt)
	local now = os.clock()
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if char then
			local pose = char:GetAttribute("Pose")
			local st = poseStates[char]
			if pose and not st then
				st = buildPoseState(char)
				poseStates[char] = st
			end
			if st and (pose or st.active) then
				local token = char:GetAttribute("PoseToken")
				if pose ~= st.pose or token ~= st.token then
					if pose and pose == st.pose then
						for _, j in pairs(st.joints) do j.cur = j.cur:Lerp(CFrame.new(), 0.6) end   -- тот же удар ещё раз — «замах»
					end
					st.pose, st.token, st.start = pose, token, now
				end
				local name = pose
				if pose == "ultCharge" and now - st.start < 0.7 then name = "ultHair" end
				local def = name and POSES[name]
				local speed = def and def.speed or 12
				local a = 1 - math.exp(-dt * speed)
				local aw = 1 - math.exp(-dt * math.max(14, speed))
				local sh = def and def.shake and math.rad(def.shake) or 0
				local any = false
				for key, j in pairs(st.joints) do
					if j.motor.Parent then
						local tg = def and poseTarget(def, key, st.r6)
						if tg then
							if sh > 0 then tg = tg * CFrame.Angles((math.random() * 2 - 1) * sh, (math.random() * 2 - 1) * sh, (math.random() * 2 - 1) * sh) end
							if j.w < 0.02 then j.cur = tg else j.cur = j.cur:Lerp(tg, a) end
							j.w = j.w + (1 - j.w) * aw
						else
							j.w = j.w - j.w * aw
						end
						if j.w > 0.003 then
							any = true
							j.motor.Transform = j.motor.Transform:Lerp(j.rinv * j.cur * j.rot, j.w)
						elseif j.w > 0 then
							j.w = 0
							j.motor.Transform = CFrame.new()
						end
					end
				end
				st.active = any or pose ~= nil
			end
		end
	end
end)

---------------------------------------------------------------- кинокамера: комбо и ульта Рю
local cineToken = 0

local function restoreCamera()
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
end

-- облёт двух бойцов, в конце камера провожает подброшенного
local function cineCombo(a, b, dur, my)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cineText("ВОТ КАКОВ ДЕСЕРТ!", "РЮ ИСИГОРИ", Color3.fromRGB(255, 220, 140))
	local side = (math.random() < 0.5) and 1 or -1
	local t0, last = os.clock(), os.clock()
	local cf = nil
	while cineToken == my and os.clock() - t0 < dur and a.Parent and b.Parent do
		local now = os.clock()
		local e, dt = now - t0, now - last
		last = now
		local pa, pb = a.Position, b.Position
		local mid = (pa + pb) / 2 + Vector3.new(0, 1.2, 0)
		local axis = Vector3.new(pb.X - pa.X, 0, pb.Z - pa.Z)
		if axis.Magnitude < 0.1 then axis = Vector3.new(0, 0, -1) end
		axis = axis.Unit
		local perp = Vector3.new(-axis.Z, 0, axis.X) * side
		local ang = math.rad(-50 + e / dur * 110)
		local dir = perp * math.cos(ang) + axis * math.sin(ang)
		local look = mid
		if e > 1.55 then look = mid:Lerp(pb + Vector3.new(0, 2, 0), math.min(1, (e - 1.55) / 0.4)) end
		local target = CFrame.lookAt(mid + dir * (10 - e * 1.2) + Vector3.new(0, 2.2 + e * 0.6, 0), look)
		cf = cf and cf:Lerp(target, 1 - math.exp(-dt * 12)) or target
		cam.CFrame = cf * shakeCF()
		cam.FieldOfView = 62 - e * 3
		RunService.RenderStepped:Wait()
	end
end

-- ульта: крупный план (поправил кок) → общий план (заряд) → вспышка → из-за плеча вдоль луча
local function cineUlt(hrp, dur, my)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	play(sUnsheath, 0.8)
	local t0 = os.clock()
	local titled, fired = false, false
	while cineToken == my and os.clock() - t0 < dur and hrp.Parent do
		local e = os.clock() - t0
		local cf0 = hrp.CFrame
		local look, right, up = cf0.LookVector, cf0.RightVector, Vector3.new(0, 1, 0)
		local head = cf0.Position + up * 1.6
		local cf, fov
		if not titled and e > 0.2 then
			titled = true
			cineText("ГРАНИТНЫЙ ЗАЛП", "РЮ ИСИГОРИ · УЛЬТА", Color3.fromRGB(170, 230, 255))
		end
		if e < 0.7 then
			local k = e / 0.7
			cf = CFrame.lookAt(head + look * (5.2 - k * 1.2) + right * 1.0 - up * 0.6, head + up * 0.3)
			fov = 50
		elseif e < 1.4 then
			local k = (e - 0.7) / 0.7
			cf = CFrame.lookAt(cf0.Position + look * 10 + right * (6 - k * 2) + up * (1.2 + k), cf0.Position + up * 0.8 + look * 1.5)
			fov = 60
		else
			if not fired then
				fired = true
				cineTextHide()
				doFlash(WHITE, 0, 0.5)
				addShake(1.2)
				play(sLunge, 0.5)
			end
			local k = math.min(1, (e - 1.4) / 1.7)
			cf = CFrame.lookAt(cf0.Position - look * (8 + k * 3) + right * 3.5 + up * (3 + k), cf0.Position + look * 45 + up * 0.5)
			fov = 75 + k * 5
		end
		cam.CFrame = cf * shakeCF()
		cam.FieldOfView = fov
		RunService.RenderStepped:Wait()
	end
end

R.Cinematic.OnClientEvent:Connect(function(kind, a, b, dur)
	cineToken = cineToken + 1
	local my = cineToken
	dur = tonumber(dur) or 2.5
	local char = player.Character
	local myHrp = char and char:FindFirstChild("HumanoidRootPart")
	if a == myHrp then busyUntil = math.max(busyUntil, os.clock() + dur) end
	task.spawn(function()
		cine = kind
		hud.Visible = false
		bars(true)
		local ok, err = pcall(function()
			if kind == "combo" and a and b then cineCombo(a, b, dur, my)
			elseif kind == "ult" and a then cineUlt(a, dur, my) end
		end)
		if not ok then warn("[RNG] Ошибка камеры: " .. tostring(err)) end
		if cineToken == my then
			cine = false
			bars(false)
			cineTextHide()
			hud.Visible = true
			restoreCamera()
		end
	end)
end)

---------------------------------------------------------------- оживление карты (локально, плавно)
local decor = {}
task.spawn(function()
	local mapF = workspace:WaitForChild("Map", 60)
	if not mapF then return end
	task.wait(1)
	for _, o in ipairs(mapF:GetDescendants()) do
		local spinA, bob = o:GetAttribute("Spin"), o:GetAttribute("Bob")
		if (spinA or bob) and (o:IsA("Model") or o:IsA("BasePart")) then
			local isModel = o:IsA("Model")
			table.insert(decor, { o = o, cf = isModel and o:GetPivot() or o.CFrame, spin = spinA or 0, bob = bob or 0, ph = math.random() * 6, model = isModel })
		end
	end
end)
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, d in ipairs(decor) do
		if d.o.Parent then
			local upV = Vector3.new(0, math.sin(t * 1.1 + d.ph) * d.bob, 0)
			if d.model then
				d.o:PivotTo((d.cf + upV) * CFrame.Angles(0, 0, t * d.spin))
			else
				d.o.CFrame = CFrame.new(d.cf.Position + upV) * CFrame.Angles(0, t * d.spin, 0) * (d.cf - d.cf.Position)
			end
		end
	end
end)

---------------------------------------------------------------- объявления и тряска
R.Announce.OnClientEvent:Connect(function(text, color, big)
	announce(text, color, big)
	if big and not cine and color then doFlash(color, 0.65, 1) end
end)

R.Shake.OnClientEvent:Connect(function(pos, power)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or typeof(pos) ~= "Vector3" then return end
	local k = math.clamp(1 - (hrp.Position - pos).Magnitude / 120, 0, 1) * (tonumber(power) or 0.5)
	if k <= 0.02 then return end
	addShake(k)
	if cine == "combo" then play(sSlash, 0.8 + math.random() * 0.4) end
end)

print("[RNG] Интерфейс v3 загружен")
