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

-- снизу по центру: окно ролла и кнопки
local rollBox = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.new(0.36, 0, 0, 92), BackgroundColor3 = DARK, BackgroundTransparency = 0.1, Parent = gui },
	{ corner(0.2), stroke(Color3.fromRGB(120, 90, 255), 3) })
local rollScale = new("UIScale", { Scale = 1, Parent = rollBox })
local rollStroke = rollBox:FindFirstChildOfClass("UIStroke")
local rollName = new("TextLabel", { Position = UDim2.new(0, 0, 0.05, 0), Size = UDim2.new(1, 0, 0.55, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1), Text = "Нажми РОЛЛ!", Parent = rollBox }, { tstroke(3) })
local rollInfo = new("TextLabel", { Position = UDim2.new(0, 0, 0.6, 0), Size = UDim2.new(1, 0, 0.32, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
	TextColor3 = Color3.fromRGB(200, 200, 220), Text = "Выбей способность: огонь, вода, молния...", Parent = rollBox }, { tstroke(2) })
local newTag = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.9, 0, 0.05, 0), Size = UDim2.new(0, 90, 0, 26), Rotation = 12, BackgroundColor3 = Color3.fromRGB(255, 70, 110),
	Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "НОВАЯ!", Visible = false, Parent = rollBox }, { corner(0.4), stroke() })

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
local pool = Abilities.List

local function showRoll(a, final)
	local r = rarityOf(a)
	rollName.Text = a.name
	rollName.TextColor3 = a.color
	rollInfo.Text = r.name .. " · " .. Abilities.chanceText(a)
	rollInfo.TextColor3 = r.color
	rollStroke.Color = r.color
	if final then
		rollScale.Scale = 1.25
		tween(rollScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

local function doRoll()
	if rolling then return end
	rolling = true
	rollBtn.Text = "..."
	newTag.Visible = false
	local res = R.Roll:InvokeServer()
	if not res then
		rolling = false
		rollBtn.Text = "РОЛЛ"
		return
	end
	local final = Abilities.ById[res.id]
	-- прокрутка: быстро, потом всё медленнее
	local wait_, i = 0.035, 0
	while wait_ < 0.3 do
		i = i + 1
		local a = pool[math.random(1, math.min(#pool, 4 + math.floor(i / 3)))]
		showRoll(a, false)
		play(sTick, 1.3 + math.random() * 0.5)
		task.wait(wait_)
		wait_ = wait_ * 1.13
	end
	showRoll(final, true)
	play(sWin, final.chance >= 50 and 0.6 or 1)
	if final.chance >= 25 then
		flash.BackgroundColor3 = final.color
		flash.BackgroundTransparency = 0.25
		tween(flash, 0.9, { BackgroundTransparency = 1 })
	end
	if res.isNew then newTag.Visible = true end
	if res.equipped then announce("Надета новая способность: " .. final.name .. "!", final.color, false) end
	task.wait(0.5)
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
				task.wait(0.35)
			end
		end)
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
