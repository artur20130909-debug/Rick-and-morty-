-- Интерфейс игрока: кнопка РОЛЛ с прокруткой способностей, авто-ролл, инвентарь, удача,
-- кнопки «Удар» (F / клик) и «Способность» (E), объявления и тряска камеры.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Abilities = require(RS:WaitForChild("Abilities"))
local remotes = RS:WaitForChild("Remotes")
local R = {}
for _, n in ipairs({ "Roll", "Equip", "GetData", "BuyLuck", "Use", "Announce", "DataUpdate", "Shake" }) do R[n] = remotes:WaitForChild(n) end

local data = { owned = {}, equipped = nil, coins = 0, luckLeft = 0, luckCost = 50 }
local luckEnds = 0

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
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(r or 0.2, 0) }) end
local function stroke(c, th) return new("UIStroke", { Color = c or Color3.fromRGB(20, 15, 35), Thickness = th or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function tstroke(th) return new("UIStroke", { Color = Color3.fromRGB(20, 15, 35), Thickness = th or 2 }) end
local function grad(a, b) return new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = 90 }) end
local function tween(o, t, goal, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
local function sound(id, vol, pitch)
	local s = new("Sound", { SoundId = id, Volume = vol or 0.4, PlaybackSpeed = pitch or 1, Parent = SoundService })
	return s
end
local sTick = sound("rbxasset://sounds/electronicpingshort.wav", 0.15, 1.6)
local sWin = sound("rbxasset://sounds/electronicpingshort.wav", 0.5, 0.8)
local function play(s, pitch) if pitch then s.PlaybackSpeed = pitch end; pcall(function() SoundService:PlayLocalSound(s) end) end
local function rarityOf(a) return Abilities.Rarities[a.rarity] end

local FONT = Enum.Font.FredokaOne
local DARK = Color3.fromRGB(28, 22, 46)

---------------------------------------------------------------- экран
local gui = new("ScreenGui", { Name = "RNGUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

-- вспышка на редкий ролл
local flash = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 50, Parent = gui })

-- сверху: надетая способность и подсказка
local equippedLbl = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(0.42, 0, 0, 34),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.15, Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "Способность: нет — сделай РОЛЛ!", Parent = gui },
	{ corner(0.4), stroke(Color3.fromRGB(120, 90, 255), 2), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }) })
local hintLbl = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.new(0.5, 0, 0, 24), BackgroundTransparency = 1,
	Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(210, 180, 255), Text = "Прыгни в фиолетовый портал, чтобы попасть на арену!", Parent = gui }, { tstroke(2) })

-- слева: монеты, инвентарь, удача
local coinsLbl = new("TextLabel", { Position = UDim2.new(0, 10, 0.3, 0), Size = UDim2.new(0, 170, 0, 36), BackgroundColor3 = DARK, BackgroundTransparency = 0.15,
	Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(255, 215, 80), Text = "Монеты: 0", Parent = gui }, { corner(0.3), stroke(Color3.fromRGB(255, 200, 60), 2) })
local invBtn = new("TextButton", { Position = UDim2.new(0, 10, 0.3, 44), Size = UDim2.new(0, 170, 0, 44), BackgroundColor3 = Color3.fromRGB(70, 140, 255),
	Font = FONT, TextScaled = true, TextStrokeTransparency = 0.2, TextStrokeColor3 = DARK, TextColor3 = Color3.new(1, 1, 1), Text = "Инвентарь", AutoButtonColor = true, Parent = gui },
	{ corner(0.3), stroke(), grad(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 190, 255)) })
local luckBtn = new("TextButton", { Position = UDim2.new(0, 10, 0.3, 96), Size = UDim2.new(0, 170, 0, 44), BackgroundColor3 = Color3.fromRGB(80, 200, 110),
	Font = FONT, TextScaled = true, TextStrokeTransparency = 0.2, TextStrokeColor3 = DARK, TextColor3 = Color3.new(1, 1, 1), Text = "Удача ×2 — 50", AutoButtonColor = true, Parent = gui },
	{ corner(0.3), stroke(), grad(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 230, 180)) })

-- снизу по центру: лента ролла (как открытие кейса) и кнопки
local CARD, GAP, NCARDS, WIN = 104, 8, 46, 40
local reel = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -98), Size = UDim2.new(0.52, 0, 0, 122), BackgroundColor3 = DARK, BackgroundTransparency = 0.08,
	ClipsDescendants = true, Parent = gui }, { corner(0.12), stroke(Color3.fromRGB(120, 90, 255), 3), new("UISizeConstraint", { MinSize = Vector2.new(330, 110) }) })
local reelStroke = reel:FindFirstChildOfClass("UIStroke")
local strip = new("Frame", { Size = UDim2.new(0, NCARDS * (CARD + GAP), 1, -16), Position = UDim2.new(0, 0, 0, 8), BackgroundTransparency = 1, Parent = reel })
local reelIdle = new("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(220, 210, 255),
	Text = "Нажми РОЛЛ и выбей стихию!", ZIndex = 5, Parent = reel }, { tstroke(3), new("UIPadding", { PaddingTop = UDim.new(0.25, 0), PaddingBottom = UDim.new(0.25, 0), PaddingLeft = UDim.new(0.05, 0), PaddingRight = UDim.new(0.05, 0) }) })
-- затемнение краёв ленты и метка-указатель по центру
local shadeL = new("Frame", { Size = UDim2.new(0.22, 0, 1, 0), BackgroundColor3 = DARK, BorderSizePixel = 0, ZIndex = 4, Parent = reel },
	{ new("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
local shadeR = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.22, 0, 1, 0), BackgroundColor3 = DARK, BorderSizePixel = 0, ZIndex = 4, Parent = reel },
	{ new("UIGradient", { Transparency = NumberSequence.new(1, 0) }) })
local marker = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 215, 70), BorderSizePixel = 0, ZIndex = 6, Parent = reel })
for _, top in ipairs({ true, false }) do
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, top and 0 or 1, 0), Size = UDim2.new(0, 16, 0, 16), Rotation = 45, BackgroundColor3 = Color3.fromRGB(255, 215, 70),
		BorderSizePixel = 0, ZIndex = 6, Parent = reel }, { stroke(DARK, 2) })
end
-- кнопка «надеть» после ролла
local equipPrompt = new("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -226), Size = UDim2.new(0.26, 0, 0, 44), BackgroundColor3 = Color3.fromRGB(80, 200, 110),
	Font = FONT, TextScaled = true, TextStrokeTransparency = 0.2, TextStrokeColor3 = DARK, TextColor3 = Color3.new(1, 1, 1), Text = "НАДЕТЬ", Visible = false, AutoButtonColor = true, Parent = gui },
	{ corner(0.3), stroke(DARK, 3), new("UISizeConstraint", { MinSize = Vector2.new(220, 40) }), new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }) })

local rollBtn = new("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(0.2, 0, 0, 70), BackgroundColor3 = Color3.fromRGB(255, 180, 40),
	Font = FONT, TextScaled = true, TextStrokeTransparency = 0.2, TextStrokeColor3 = DARK, TextColor3 = Color3.new(1, 1, 1), Text = "РОЛЛ", AutoButtonColor = true, Parent = gui },
	{ corner(0.3), stroke(DARK, 4), grad(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 60)), new("UISizeConstraint", { MinSize = Vector2.new(150, 60) }) })
local autoBtn = new("TextButton", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.6, 10, 1, -24), Size = UDim2.new(0.09, 0, 0, 52), BackgroundColor3 = Color3.fromRGB(110, 110, 130),
	Font = FONT, TextScaled = true, TextStrokeTransparency = 0.2, TextStrokeColor3 = DARK, TextColor3 = Color3.new(1, 1, 1), Text = "АВТО: ВЫКЛ", AutoButtonColor = true, Parent = gui },
	{ corner(0.3), stroke(DARK, 3), new("UISizeConstraint", { MinSize = Vector2.new(96, 44) }) })

-- справа снизу: удар и способность
local function attackButton(pos, color, title, key)
	local b = new("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = pos, Size = UDim2.new(0, 96, 0, 96), BackgroundColor3 = color, Text = "", AutoButtonColor = true, Parent = gui },
		{ corner(1), stroke(DARK, 4) })
	new("TextLabel", { Size = UDim2.new(1, -10, 0.45, 0), Position = UDim2.new(0, 5, 0.18, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		Text = title, Name = "Title", ZIndex = 3, Parent = b }, { tstroke(2) })
	new("TextLabel", { Size = UDim2.new(1, 0, 0.24, 0), Position = UDim2.new(0, 0, 0.64, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(230, 230, 240),
		Text = key, Name = "Key", ZIndex = 3, Parent = b }, { tstroke(1.5) })
	local cd = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
		Name = "Cooldown", ZIndex = 2, Parent = b }, { corner(1) })
	return b, cd
end
local slapBtn, slapCd = attackButton(UDim2.new(1, -124, 1, -20), Color3.fromRGB(255, 150, 120), "УДАР", "F / клик")
local abilBtn, abilCd = attackButton(UDim2.new(1, -16, 1, -110), Color3.fromRGB(120, 90, 255), "—", "E")

-- объявления (редкие роллы, кто кого сбил)
local feed = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), Size = UDim2.new(0.6, 0, 0, 120), BackgroundTransparency = 1, Parent = gui },
	{ new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
local feedN = 0
local function announce(text, color, big)
	feedN = feedN + 1
	local l = new("TextLabel", { Size = UDim2.new(1, 0, 0, big and 34 or 24), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = color or Color3.new(1, 1, 1),
		Text = text, LayoutOrder = feedN, TextTransparency = 1, Parent = feed }, { tstroke(2.5) })
	tween(l, 0.25, { TextTransparency = 0 })
	task.delay(big and 6 or 4, function()
		if l.Parent then tween(l, 0.5, { TextTransparency = 1 }); task.wait(0.55); l:Destroy() end
	end)
	local kids = feed:GetChildren()
	local labels = {}
	for _, k in ipairs(kids) do if k:IsA("TextLabel") then table.insert(labels, k) end end
	if #labels > 4 then table.sort(labels, function(a, b) return a.LayoutOrder < b.LayoutOrder end); labels[1]:Destroy() end
end

---------------------------------------------------------------- инвентарь
local inv = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.5, 0, 0.66, 0), BackgroundColor3 = DARK, Visible = false, ZIndex = 20, Parent = gui },
	{ corner(0.06), stroke(Color3.fromRGB(120, 90, 255), 4), new("UISizeConstraint", { MinSize = Vector2.new(330, 260) }) })
new("TextLabel", { Size = UDim2.new(1, -60, 0, 44), Position = UDim2.new(0, 14, 0, 6), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.new(1, 1, 1), Text = "Твои способности", ZIndex = 21, Parent = inv }, { tstroke(2) })
local closeBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.new(0, 40, 0, 40), BackgroundColor3 = Color3.fromRGB(230, 70, 80),
	Font = FONT, TextScaled = true, TextStrokeTransparency = 0.2, TextStrokeColor3 = DARK, TextColor3 = Color3.new(1, 1, 1), Text = "X", ZIndex = 21, Parent = inv }, { corner(0.3), stroke() })
local list = new("ScrollingFrame", { Position = UDim2.new(0, 10, 0, 58), Size = UDim2.new(1, -20, 1, -68), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 21, Parent = inv },
	{ new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function refreshInventory()
	for _, c in ipairs(list:GetChildren()) do if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end end
	local any = false
	for _, a in ipairs(Abilities.sortedByRarity()) do
		local n = data.owned[a.id]
		if n then
			any = true
			local r = rarityOf(a)
			local row = new("Frame", { Size = UDim2.new(1, -10, 0, 74), BackgroundColor3 = Color3.fromRGB(45, 38, 70), LayoutOrder = -a.chance, ZIndex = 22, Parent = list },
				{ corner(0.15), stroke(r.color, 2) })
			new("TextLabel", { Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(0.62, 0, 0, 30), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = a.color, Text = a.name .. "  ×" .. n, ZIndex = 23, Parent = row }, { tstroke(2) })
			new("TextLabel", { Position = UDim2.new(0, 10, 0, 34), Size = UDim2.new(0.62, 0, 0, 18), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = r.color, Text = r.name .. " · " .. Abilities.chanceText(a), ZIndex = 23, Parent = row })
			new("TextLabel", { Position = UDim2.new(0, 10, 0, 53), Size = UDim2.new(0.62, 0, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(200, 200, 215), Text = a.desc, ZIndex = 23, Parent = row })
			local isEq = data.equipped == a.id
			local eq = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.3, 0, 0, 44), BackgroundColor3 = isEq and Color3.fromRGB(90, 90, 110) or Color3.fromRGB(80, 200, 110),
				Font = FONT, TextScaled = true, TextStrokeTransparency = 0.2, TextStrokeColor3 = DARK, TextColor3 = Color3.new(1, 1, 1), Text = isEq and "Надето" or "Надеть", AutoButtonColor = not isEq, ZIndex = 23, Parent = row }, { corner(0.3), stroke() })
			if not isEq then
				eq.MouseButton1Click:Connect(function() R.Equip:InvokeServer(a.id) end)
			end
		end
	end
	if not any then
		new("TextLabel", { Size = UDim2.new(1, -10, 0, 60), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(200, 200, 215),
			Text = "Пока пусто. Нажми РОЛЛ!", ZIndex = 22, Parent = list })
	end
end
invBtn.MouseButton1Click:Connect(function() inv.Visible = not inv.Visible; if inv.Visible then refreshInventory() end end)
closeBtn.MouseButton1Click:Connect(function() inv.Visible = false end)

---------------------------------------------------------------- данные
local function applyData(p)
	if not p then return end
	data = p
	luckEnds = os.clock() + (p.luckLeft or 0)
	coinsLbl.Text = "Монеты: " .. tostring(p.coins or 0)
	local a = Abilities.ById[p.equipped or ""]
	if a then
		local r = rarityOf(a)
		equippedLbl.Text = "Способность: " .. a.name .. " (" .. r.name .. ")"
		equippedLbl.TextColor3 = a.color
		abilBtn.Title.Text = string.upper(a.name)
		abilBtn.BackgroundColor3 = a.color:Lerp(Color3.new(0, 0, 0), 0.25)
	else
		equippedLbl.Text = "Способность: нет — сделай РОЛЛ!"
		equippedLbl.TextColor3 = Color3.new(1, 1, 1)
		abilBtn.Title.Text = "—"
	end
	if inv.Visible then refreshInventory() end
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
			luckBtn.Text = string.format("Удача ×2: %d:%02d", math.floor(left / 60), math.floor(left % 60))
		else
			luckBtn.Text = "Удача ×2 — " .. tostring(data.luckCost or 50)
		end
		task.wait(0.5)
	end
end)
luckBtn.MouseButton1Click:Connect(function()
	local ok = R.BuyLuck:InvokeServer()
	if not ok then announce("Не хватает монет! Сбивай врагов и манекены на арене.", Color3.fromRGB(255, 120, 120), false) end
end)

---------------------------------------------------------------- РОЛЛ
local rolling, auto = false, false
local totalW = 0
for _, a in ipairs(Abilities.List) do totalW = totalW + 1 / a.chance end
-- «настоящий» случайный выбор для карточек-пустышек: частые встречаются часто, редкие — редко
local function fillerPick(minChance)
	for _ = 1, 20 do
		local r, acc = math.random() * totalW, 0
		for _, a in ipairs(Abilities.List) do
			acc = acc + 1 / a.chance
			if r <= acc then
				if not minChance or a.chance >= minChance then return a end
				break
			end
		end
	end
	local list = Abilities.sortedByRarity()
	return list[math.random(1, 3)]
end

local function makeCard(a, i)
	local r = rarityOf(a)
	local c = new("Frame", { Position = UDim2.new(0, (i - 1) * (CARD + GAP), 0, 0), Size = UDim2.new(0, CARD, 1, 0), BackgroundColor3 = a.color:Lerp(Color3.new(0, 0, 0), 0.55), Parent = strip },
		{ corner(0.14), stroke(r.color, 3), new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 170)), Rotation = 90 }) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.1, 0), Size = UDim2.new(0, 34, 0, 34), BackgroundColor3 = a.color, Parent = c }, { corner(1), stroke(Color3.new(1, 1, 1), 2) })
	new("TextLabel", { Position = UDim2.new(0, 4, 0.47, 0), Size = UDim2.new(1, -8, 0.28, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = a.name, Parent = c }, { tstroke(2) })
	new("TextLabel", { Position = UDim2.new(0, 4, 0.76, 0), Size = UDim2.new(1, -8, 0.18, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = r.color, Text = Abilities.chanceText(a), Parent = c }, { tstroke(1.5) })
	local sc = new("UIScale", { Scale = 1, Parent = c })
	return c, sc
end

local function buildStrip(final)
	for _, ch in ipairs(strip:GetChildren()) do ch:Destroy() end
	local cards = {}
	for i = 1, NCARDS do
		local a = fillerPick()
		if i == WIN then a = final
		elseif (i == WIN - 1 or i == WIN + 1) and math.random() < 0.6 then a = fillerPick(25)   -- «чуть-чуть не повезло» рядом с выигрышем
		end
		local c, sc = makeCard(a, i)
		cards[i] = { frame = c, scale = sc, a = a }
	end
	return cards
end

-- большой показ редкой способности на весь экран
local reveal = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 40, Parent = gui })
local rays = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.45, 0), Size = UDim2.new(0, 900, 0, 900), BackgroundTransparency = 1, ZIndex = 41, Parent = reveal })
local rayList = {}
for i = 0, 11 do
	local r = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 70, 1, 0), Rotation = i * 15, BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.75, BorderSizePixel = 0, ZIndex = 41, Parent = rays }, { new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }), Rotation = 90 }) })
	table.insert(rayList, r)
end
local bigCard = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.45, 0), Size = UDim2.new(0, 250, 0, 300), BackgroundColor3 = DARK, ZIndex = 42, Parent = reveal },
	{ corner(0.08) })
local bigStroke = new("UIStroke", { Thickness = 6, Color = Color3.new(1, 1, 1), Parent = bigCard })
local bigScale = new("UIScale", { Scale = 1, Parent = bigCard })
local bigOrb = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.08, 0), Size = UDim2.new(0, 96, 0, 96), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 43, Parent = bigCard },
	{ corner(1), stroke(Color3.new(1, 1, 1), 4) })
local bigRarity = new("TextLabel", { Position = UDim2.new(0, 10, 0.44, 0), Size = UDim2.new(1, -20, 0, 30), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "", ZIndex = 43, Parent = bigCard }, { tstroke(3) })
local bigName = new("TextLabel", { Position = UDim2.new(0, 10, 0.55, 0), Size = UDim2.new(1, -20, 0, 52), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "", TextColor3 = Color3.new(1, 1, 1), ZIndex = 43, Parent = bigCard }, { tstroke(4) })
local bigRainbow = new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 140)), ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)) }), Enabled = false, Parent = bigName })
local bigChance = new("TextLabel", { Position = UDim2.new(0, 10, 0.75, 0), Size = UDim2.new(1, -20, 0, 26), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "", TextColor3 = Color3.fromRGB(230, 230, 240), ZIndex = 43, Parent = bigCard }, { tstroke(2) })
local bigHint = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.45, 175), Size = UDim2.new(0, 300, 0, 22), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
	Text = "нажми, чтобы продолжить", TextColor3 = Color3.fromRGB(200, 200, 215), ZIndex = 42, Parent = reveal }, { tstroke(2) })

local revealOpen = false
local function shakeCam(power, dur)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local e = os.clock() - t0
		if e > dur then conn:Disconnect(); hum.CameraOffset = Vector3.new(); return end
		local m = power * (1 - e / dur)
		hum.CameraOffset = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, 0) * m
	end)
end

local function bigReveal(a)
	local r = rarityOf(a)
	revealOpen = true
	reveal.Visible = true
	reveal.BackgroundTransparency = 1
	tween(reveal, 0.25, { BackgroundTransparency = 0.3 })
	for _, ray in ipairs(rayList) do ray.BackgroundColor3 = r.color end
	rays.Rotation = 0
	bigStroke.Color = r.color
	bigOrb.BackgroundColor3 = a.color
	bigRarity.Text = string.upper(r.name) .. "!"
	bigRarity.TextColor3 = r.color
	bigName.Text = a.name
	bigName.TextColor3 = (a.rarity == "mythic") and Color3.new(1, 1, 1) or a.color
	bigRainbow.Enabled = a.rarity == "mythic"
	bigChance.Text = Abilities.chanceText(a)
	bigScale.Scale = 0.15
	tween(bigScale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
	play(sWin, 0.5)
	shakeCam(a.chance >= 120 and 1.2 or 0.6, 0.6)
	flash.BackgroundColor3 = a.color
	flash.BackgroundTransparency = 0.1
	tween(flash, 0.8, { BackgroundTransparency = 1 })
	-- искры разлетаются от карточки
	for i = 1, 26 do
		local ang = math.random() * math.pi * 2
		local d = 180 + math.random() * 260
		local sz = 6 + math.random() * 10
		local p = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.45, 0), Size = UDim2.new(0, sz, 0, sz), Rotation = math.random() * 90,
			BackgroundColor3 = (i % 3 == 0) and Color3.new(1, 1, 1) or r.color, BorderSizePixel = 0, ZIndex = 41, Parent = reveal })
		tween(p, 0.9 + math.random() * 0.5, { Position = UDim2.new(0.5, math.cos(ang) * d, 0.45, math.sin(ang) * d), BackgroundTransparency = 1, Rotation = math.random() * 360 }, Enum.EasingStyle.Quart)
		task.delay(1.6, function() p:Destroy() end)
	end
	local t0 = os.clock()
	while revealOpen and os.clock() - t0 < 3.2 do
		local e = os.clock() - t0
		rays.Rotation = e * 25
		bigRainbow.Offset = Vector2.new(math.sin(e * 2) * 0.5, 0)
		bigOrb.Size = UDim2.new(0, 96 + math.sin(e * 6) * 6, 0, 96 + math.sin(e * 6) * 6)
		RunService.RenderStepped:Wait()
	end
	revealOpen = false
	tween(reveal, 0.25, { BackgroundTransparency = 1 })
	tween(bigScale, 0.2, { Scale = 0.1 })
	task.wait(0.22)
	reveal.Visible = false
end
reveal.MouseButton1Click:Connect(function() revealOpen = false end)

local promptToken = 0
local function showEquipPrompt(a)
	promptToken = promptToken + 1
	local my = promptToken
	equipPrompt.Text = "НАДЕТЬ: " .. string.upper(a.name)
	equipPrompt.BackgroundColor3 = a.color:Lerp(Color3.fromRGB(60, 60, 70), 0.35)
	equipPrompt:SetAttribute("Id", a.id)
	equipPrompt.Visible = true
	task.delay(7, function() if promptToken == my then equipPrompt.Visible = false end end)
end
equipPrompt.MouseButton1Click:Connect(function()
	local id = equipPrompt:GetAttribute("Id")
	equipPrompt.Visible = false
	if id and R.Equip:InvokeServer(id) then
		local a = Abilities.ById[id]
		announce("Надета способность: " .. a.name, a.color, false)
	end
end)

local function doRoll()
	if rolling then return end
	rolling = true
	rollBtn.Text = "..."
	equipPrompt.Visible = false
	local res = R.Roll:InvokeServer()
	if not res then
		rolling = false
		rollBtn.Text = "РОЛЛ"
		return
	end
	local final = Abilities.ById[res.id]
	local fast = auto
	reelIdle.Visible = false
	local cards = buildStrip(final)
	-- лента прокручивается и плавно останавливается на выпавшей карточке
	local W = reel.AbsoluteSize.X
	local step = CARD + GAP
	local startX = W / 2 - (2 * step + CARD / 2)
	local endX = W / 2 - ((WIN - 1) * step + CARD / 2) + (math.random() - 0.5) * CARD * 0.6
	strip.Position = UDim2.new(0, startX, 0, 8)
	local dur = fast and 1.7 or 3.1
	local tw = tween(strip, dur, { Position = UDim2.new(0, endX, 0, 8) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local lastIdx, done = -1, false
	tw.Completed:Connect(function() done = true end)
	while not done do
		local idx = math.floor((W / 2 - strip.Position.X.Offset) / step)
		if idx ~= lastIdx then
			lastIdx = idx
			play(sTick, 1.1 + math.min(idx, 40) / 40 * 0.8)
			local c = cards[idx + 1]
			if c then reelStroke.Color = rarityOf(c.a).color end
		end
		RunService.RenderStepped:Wait()
	end
	-- выигрышная карточка: подпрыгивает и светится, остальные гаснут
	local win = cards[WIN]
	for i, c in ipairs(cards) do if i ~= WIN then tween(c.frame, 0.3, { BackgroundTransparency = 0.6 }) end end
	win.scale.Scale = 1.25
	tween(win.scale, 0.4, { Scale = 1.1 }, Enum.EasingStyle.Back)
	reelStroke.Color = rarityOf(final).color
	play(sWin, final.chance >= 50 and 0.7 or 1.1)
	if final.chance >= 25 and (not fast or final.chance >= 120) then
		bigReveal(final)
	elseif final.chance >= 6 then
		flash.BackgroundColor3 = final.color
		flash.BackgroundTransparency = 0.55
		tween(flash, 0.6, { BackgroundTransparency = 1 })
	end
	if res.equipped then
		announce("Надета: " .. final.name .. (res.isNew and " (новая!)" or ""), final.color, false)
	elseif not fast then
		showEquipPrompt(final)
		if res.isNew then announce("Новая способность: " .. final.name .. "!", final.color, false) end
	end
	task.wait(fast and 0.25 or 0.4)
	rolling = false
	rollBtn.Text = "РОЛЛ"
end

rollBtn.MouseButton1Click:Connect(function() task.spawn(doRoll) end)
autoBtn.MouseButton1Click:Connect(function()
	auto = not auto
	autoBtn.Text = auto and "АВТО: ВКЛ" or "АВТО: ВЫКЛ"
	autoBtn.BackgroundColor3 = auto and Color3.fromRGB(80, 200, 110) or Color3.fromRGB(110, 110, 130)
	if auto then
		task.spawn(function()
			while auto do
				doRoll()
				task.wait(0.3)
			end
		end)
	end
end)

---------------------------------------------------------------- оживление карты (локально, плавно)
local decor = {}
task.spawn(function()
	local mapF = workspace:WaitForChild("Map", 60)
	if not mapF then return end
	task.wait(1)
	for _, o in ipairs(mapF:GetDescendants()) do
		local spin, bob = o:GetAttribute("Spin"), o:GetAttribute("Bob")
		if (spin or bob) and (o:IsA("Model") or o:IsA("BasePart")) then
			local isModel = o:IsA("Model")
			table.insert(decor, { o = o, cf = isModel and o:GetPivot() or o.CFrame, spin = spin or 0, bob = bob or 0, ph = math.random() * 6, model = isModel })
		end
	end
end)
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, d in ipairs(decor) do
		if d.o.Parent then
			local up = Vector3.new(0, math.sin(t * 1.1 + d.ph) * d.bob, 0)
			if d.model then
				d.o:PivotTo((d.cf + up) * CFrame.Angles(0, 0, t * d.spin))
			else
				d.o.CFrame = CFrame.new(d.cf.Position + up) * CFrame.Angles(0, t * d.spin, 0) * (d.cf - d.cf.Position)
			end
		end
	end
end)

---------------------------------------------------------------- бой
local lastUse = { slap = 0, ability = 0 }

local function inArena() return player:GetAttribute("InArena") == true end

local function cooldownAnim(frame, t)
	frame.Size = UDim2.new(1, 0, 1, 0)
	tween(frame, t, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Linear)
end

local function use(kind)
	if not inArena() then
		announce("На арене! Сначала прыгни в портал.", Color3.fromRGB(210, 180, 255), false)
		return
	end
	local a = (kind == "slap") and Abilities.Slap or Abilities.ById[data.equipped or ""]
	if not a then
		announce("Нет способности — нажми РОЛЛ!", Color3.fromRGB(255, 200, 80), false)
		return
	end
	local now = os.clock()
	if now - lastUse[kind] < a.cooldown then return end
	lastUse[kind] = now
	cooldownAnim(kind == "slap" and slapCd or abilCd, a.cooldown)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local dir = hrp and hrp.CFrame.LookVector or Vector3.new(0, 0, -1)
	R.Use:FireServer(kind, dir)
end

slapBtn.MouseButton1Click:Connect(function() use("slap") end)
abilBtn.MouseButton1Click:Connect(function() use("ability") end)
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F or input.UserInputType == Enum.UserInputType.MouseButton1 then use("slap")
	elseif input.KeyCode == Enum.KeyCode.E then use("ability")
	elseif input.KeyCode == Enum.KeyCode.R then task.spawn(doRoll) end
end)

-- подсказка про портал и «тусклые» кнопки в лобби
local function updateArenaState()
	local a = inArena()
	hintLbl.Visible = not a
	slapBtn.BackgroundTransparency = a and 0 or 0.5
	abilBtn.BackgroundTransparency = a and 0 or 0.5
end
player:GetAttributeChangedSignal("InArena"):Connect(updateArenaState)
updateArenaState()

---------------------------------------------------------------- объявления и тряска
R.Announce.OnClientEvent:Connect(function(text, color, big)
	announce(text, color, big)
	if big then
		flash.BackgroundColor3 = color
		flash.BackgroundTransparency = 0.6
		tween(flash, 1, { BackgroundTransparency = 1 })
	end
end)

R.Shake.OnClientEvent:Connect(function(pos, power)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return end
	local dist = (hrp.Position - pos).Magnitude
	local k = math.clamp(1 - dist / 120, 0, 1) * power
	if k <= 0.02 then return end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local e = os.clock() - t0
		if e > 0.5 then conn:Disconnect(); hum.CameraOffset = Vector3.new(); return end
		local m = k * (1 - e / 0.5) * 1.6
		hum.CameraOffset = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, 0) * m
	end)
end)

print("[RNG] Интерфейс загружен")
