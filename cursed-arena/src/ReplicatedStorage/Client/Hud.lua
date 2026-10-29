-- Интерфейс боя: здоровье, пробуждение, панель приёмов, рывок/блок, комбо, лента убийств,
-- объявления, цифры урона, вспышки экрана, экран поражения, подсказки управления.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = ReplicatedStorage:WaitForChild("Client")
local Config = require(Shared.Config)
local Characters = require(Shared.Characters)
local Theme = require(Client.Theme)
local Controller = require(Client.Controller)
local SoundFX = require(Client.SoundFX)

local Hud = {}
Hud.showDamage = true
Hud.onMenu = nil        -- ставит ClientMain: открыть меню

local player = Players.LocalPlayer
local ui = {}           -- ссылки на элементы
Hud.ui = ui

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local SLOT_W, SLOT_H, GAP = 154, 58, 8
local BOTTOM_W = SLOT_W * 4 + GAP * 3

local function tween(inst, t, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function hex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function textWidth(text, size)
	local n = utf8.len(text) or #text
	return n * size * 0.62
end

local function touchOnly()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

---------------------------------------------------------------- корень с масштабом
-- корневой кадр размером 1/s экрана + UIScale s: всё рисуется в «эталонных» 1366x768
local function scaleFor()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(1366, 768)
	return math.clamp(math.min(vs.X / 1366, vs.Y / 768), 0.55, 1.5)
end

function Hud.makeRoot(gui, name)
	local s = scaleFor()
	local root = Theme.frame({ Name = name or "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1 / s, 1 / s), Parent = gui })
	local sc = Instance.new("UIScale")
	sc.Scale = s
	sc.Parent = root
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local ns = scaleFor()
			sc.Scale = ns
			root.Size = UDim2.fromScale(1 / ns, 1 / ns)
		end)
	end
	return root
end

---------------------------------------------------------------- построение
local function keyBadge(parent, text, pos, size)
	local b = Theme.label({ Name = "Key", Text = text, Size = UDim2.fromOffset(size or 20, size or 20), Position = pos,
		BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(235, 235, 240), TextColor3 = BLACK,
		FontFace = Theme.Black, TextSize = 13, ZIndex = 4, Parent = parent })
	Theme.corner(b, 4)
	return b
end

local function buildSlot(parent, i)
	local s = Theme.button({ Name = "Slot" .. i, AutoButtonColor = false, Size = UDim2.fromOffset(SLOT_W, SLOT_H),
		Position = UDim2.fromOffset((i - 1) * (SLOT_W + GAP), 0), BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.18,
		ClipsDescendants = true, Parent = parent })
	Theme.corner(s, 6)
	local stroke = Theme.stroke(s, Theme.Line, 1.5, 0.15)
	local grad = Theme.gradient(s, Color3.fromRGB(34, 34, 46), Color3.fromRGB(12, 12, 18), 90)
	local accent = Theme.frame({ Name = "Accent", Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Theme.Accent, ZIndex = 3, Parent = s })
	local cd = Theme.frame({ Name = "Cooldown", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0), BackgroundColor3 = BLACK, BackgroundTransparency = 0.38, ZIndex = 2, Parent = s })
	local key = keyBadge(s, tostring(i), UDim2.fromOffset(6, 7))
	local name = Theme.label({ Name = "MoveName", Text = "", Size = UDim2.new(1, -14, 0, 30), Position = UDim2.fromOffset(8, 25),
		FontFace = Theme.Black, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 4, Parent = s })
	local time = Theme.label({ Name = "Time", Text = "", Size = UDim2.fromOffset(60, 20), Position = UDim2.new(1, -66, 0, 6),
		FontFace = Theme.BlackItalic, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4, Parent = s })
	Theme.textStroke(time, 1.5)
	local tag = Theme.label({ Name = "Tag", Text = "", Size = UDim2.fromOffset(80, 16), Position = UDim2.new(1, -86, 0, 8),
		FontFace = Theme.Black, TextSize = 11, TextColor3 = Theme.Gold, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4, Parent = s })
	local glow = Theme.frame({ Name = "Glow", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 5, Parent = s })
	s.Activated:Connect(function() Controller.move(i) end)
	return { frame = s, stroke = stroke, grad = grad, accent = accent, cd = cd, key = key, name = name, time = time, tag = tag, glow = glow,
		wasReady = true, base = s.Position }
end

local function bar(parent, name, pos, size, color)
	local track = Theme.frame({ Name = name, Position = pos, Size = size, BackgroundColor3 = Color3.fromRGB(8, 8, 12),
		BackgroundTransparency = 0.25, ClipsDescendants = true, Parent = parent })
	Theme.corner(track, 4)
	Theme.stroke(track, Color3.fromRGB(0, 0, 0), 1.5, 0.3)
	local ghost = Theme.frame({ Name = "Ghost", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 236, 236),
		BackgroundTransparency = 0.35, ZIndex = 2, Parent = track })
	Theme.corner(ghost, 4)
	local fill = Theme.frame({ Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ZIndex = 3, Parent = track })
	Theme.corner(fill, 4)
	local g = Theme.gradient(fill, color, Theme.shade(color, -0.25), 90)
	local shine = Theme.frame({ Name = "Shine", Size = UDim2.new(1, 0, 0.42, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.82,
		ZIndex = 4, Parent = fill })
	Theme.corner(shine, 4)
	return { track = track, ghost = ghost, fill = fill, grad = g, shown = 1, ghostV = 1 }
end

local function chip(parent, name, text, pos)
	local c = Theme.frame({ Name = name, Position = pos, Size = UDim2.fromOffset(96, 24), BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.2, ClipsDescendants = true, Parent = parent })
	Theme.corner(c, 5)
	local stroke = Theme.stroke(c, Theme.Line, 1.2, 0.3)
	local fill = Theme.frame({ Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(70, 70, 92),
		BackgroundTransparency = 0.25, ZIndex = 2, Parent = c })
	local label = Theme.label({ Name = "Label", Text = text, Size = UDim2.fromScale(1, 1), FontFace = Theme.Black, TextSize = 12,
		ZIndex = 3, Parent = c })
	return { frame = c, fill = fill, label = label, stroke = stroke }
end

local function buildBottom(root)
	local b = Theme.frame({ Name = "Bottom", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(BOTTOM_W, 150), Parent = root })
	ui.bottom = b
	-- имя и персонаж
	ui.name = Theme.label({ Name = "PlayerName", Text = player.DisplayName, Size = UDim2.fromOffset(300, 20), Position = UDim2.fromOffset(2, 38),
		FontFace = Theme.Bold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, RichText = true, Parent = b })
	Theme.textStroke(ui.name, 1.2)
	ui.awakenText = Theme.label({ Name = "AwakenText", Text = "", Size = UDim2.fromOffset(330, 20), Position = UDim2.new(1, -332, 0, 38),
		FontFace = Theme.BlackItalic, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Theme.Dim, Parent = b })
	Theme.textStroke(ui.awakenText, 1.2)
	-- здоровье
	ui.hp = bar(b, "Health", UDim2.fromOffset(0, 60), UDim2.new(1, 0, 0, 18), Theme.Good)
	ui.hpText = Theme.label({ Name = "HPText", Text = "100", Size = UDim2.fromOffset(90, 18), Position = UDim2.new(1, -96, 0, 60),
		FontFace = Theme.BlackItalic, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6, Parent = b })
	Theme.textStroke(ui.hpText, 1.5)
	-- пробуждение
	ui.meter = bar(b, "Awakening", UDim2.fromOffset(0, 82), UDim2.new(1, 0, 0, 7), Theme.Accent)
	ui.meter.shown = 0
	ui.meter.ghostV = 0
	ui.meter.ghost.Visible = false
	ui.meterGlow = Theme.frame({ Name = "MeterGlow", Position = UDim2.fromOffset(-3, 79), Size = UDim2.new(1, 6, 0, 13),
		BackgroundColor3 = Theme.Gold, BackgroundTransparency = 1, ZIndex = 0, Parent = b })
	Theme.corner(ui.meterGlow, 6)
	local meterBtn = Theme.button({ Name = "AwakenButton", Text = "", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 0, 16), ZIndex = 7, Parent = b })
	meterBtn.Activated:Connect(function() Controller.awaken() end)
	-- приёмы
	local row = Theme.frame({ Name = "Slots", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 0, SLOT_H), Parent = b })
	ui.slots = {}
	for i = 1, 4 do ui.slots[i] = buildSlot(row, i) end
	-- рывок и блок
	local side = Theme.frame({ Name = "Side", BackgroundTransparency = 1, Position = UDim2.fromOffset(-106, 66), Size = UDim2.fromOffset(96, 84), Parent = b })
	ui.dashF = chip(side, "Dash", "Q  РЫВОК", UDim2.fromOffset(0, 0))
	ui.dashS = chip(side, "Evade", "A/D+Q  УВОРОТ", UDim2.fromOffset(0, 28))
	ui.block = chip(side, "Block", "F  БЛОК", UDim2.fromOffset(0, 56))
	ui.dashS.label.TextSize = 11
end

local function buildCard(root)
	local c = Theme.frame({ Name = "Card", Position = UDim2.fromOffset(16, 64), Size = UDim2.fromOffset(300, 66), BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.2, ClipsDescendants = true, Parent = root })
	Theme.corner(c, 6)
	Theme.stroke(c, Theme.Line, 1.2, 0.3)
	ui.cardGrad = Theme.gradient(c, Theme.Accent, Theme.Panel, 0, 0.55, 0.05)
	ui.cardStripe = Theme.frame({ Name = "Stripe", Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = Theme.Accent, ZIndex = 2, Parent = c })
	ui.cardName = Theme.label({ Name = "CharName", Text = "", Position = UDim2.fromOffset(18, 8), Size = UDim2.new(1, -24, 0, 30),
		FontFace = Theme.BlackItalic, TextSize = 25, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = c })
	Theme.textStroke(ui.cardName, 1.5)
	ui.cardTitle = Theme.label({ Name = "CharTitle", Text = "", Position = UDim2.fromOffset(19, 38), Size = UDim2.new(1, -24, 0, 18),
		FontFace = Theme.Medium, TextSize = 13, TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = c })
	local menu = Theme.button({ Name = "MenuButton", Text = "МЕНЮ", Position = UDim2.fromOffset(16, 136), Size = UDim2.fromOffset(120, 32),
		BackgroundColor3 = Theme.Panel2, BackgroundTransparency = 0.1, TextSize = 15, Parent = root })
	Theme.corner(menu, 6)
	Theme.stroke(menu, Theme.Line, 1.2, 0.2)
	ui.menuKey = keyBadge(menu, "M", UDim2.new(1, -26, 0, 6))
	menu.Activated:Connect(function()
		SoundFX.play("Click")
		if Hud.onMenu then Hud.onMenu() end
	end)
	ui.menuButton = menu
end

local function buildCombo(root)
	local c = Theme.frame({ Name = "Combo", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -36, 0.44, 0),
		Size = UDim2.fromOffset(240, 120), Parent = root })
	ui.combo = c
	ui.comboNum = Theme.label({ Name = "Num", Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(240, 76),
		FontFace = Theme.BlackItalic, TextSize = 72, TextXAlignment = Enum.TextXAlignment.Right, Parent = c })
	ui.comboGrad = Theme.gradient(ui.comboNum, WHITE, Theme.Gold, 90)
	Theme.textStroke(ui.comboNum, 3)
	ui.comboLabel = Theme.label({ Name = "Label", Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 74), Size = UDim2.fromOffset(240, 24),
		FontFace = Theme.BlackItalic, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right, Parent = c })
	Theme.textStroke(ui.comboLabel, 2)
	c.Visible = false
end

local function buildFeed(root)
	local f = Theme.frame({ Name = "Killfeed", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 250),
		Size = UDim2.fromOffset(420, 240), Parent = root })
	Theme.list(f, Enum.FillDirection.Vertical, 5, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top)
	ui.feed = f
	ui.feedN = 0
end

local function buildAnnounce(root)
	local a = Theme.frame({ Name = "Announce", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromOffset(900, 110), Parent = root })
	ui.announce = a
	ui.annBand = Theme.frame({ Name = "Band", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = BLACK, BackgroundTransparency = 1, Parent = a })
	ui.annBandGrad = Theme.gradient(ui.annBand, WHITE, WHITE, 0)
	ui.annBandGrad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) })
	ui.annSub = Theme.label({ Name = "Sub", Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 0, 0, 24),
		FontFace = Theme.Black, TextSize = 16, TextColor3 = Theme.Gold, TextTransparency = 1, Parent = a })
	Theme.textStroke(ui.annSub, 1.5)
	ui.annText = Theme.label({ Name = "Title", Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.new(1, 0, 0, 64),
		FontFace = Theme.BlackItalic, TextSize = 50, TextTransparency = 1, Parent = a })
	ui.annStroke = Theme.textStroke(ui.annText, 3)
	ui.annStroke.Transparency = 1
end

local function buildCenter(root)
	-- вспышка экрана
	ui.flash = Theme.frame({ Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 40, Parent = root })
	-- окно «нажми ещё раз»
	ui.cue = Theme.label({ Name = "Cue", Text = "ЖМИ!", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(300, 60),
		FontFace = Theme.BlackItalic, TextSize = 44, TextColor3 = Theme.Gold, TextTransparency = 1, ZIndex = 30, Parent = root })
	ui.cueStroke = Theme.textStroke(ui.cue, 3)
	ui.cueStroke.Transparency = 1
	-- уведомления
	ui.notify = Theme.label({ Name = "Notify", Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -182), Size = UDim2.fromOffset(560, 34),
		BackgroundTransparency = 1, BackgroundColor3 = Theme.Panel, FontFace = Theme.Bold, TextSize = 16, TextTransparency = 1, ZIndex = 20, Parent = root })
	Theme.corner(ui.notify, 6)
	ui.notifyStroke = Theme.stroke(ui.notify, Theme.Bad, 1.5, 1)
end

local function buildDeath(root)
	local d = Theme.frame({ Name = "Death", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, ZIndex = 35, Visible = false, Parent = root })
	local g = Theme.gradient(d, BLACK, BLACK, 90)
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.35, 0.75), NumberSequenceKeypoint.new(0.65, 0.75), NumberSequenceKeypoint.new(1, 0.15) })
	ui.death = d
	ui.deathTitle = Theme.label({ Name = "Title", Text = "ВЫ ПОВЕРЖЕНЫ", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(900, 80), FontFace = Theme.BlackItalic, TextSize = 64, TextColor3 = Color3.fromRGB(255, 70, 70), ZIndex = 36, Parent = d })
	Theme.textStroke(ui.deathTitle, 3)
	ui.deathBy = Theme.label({ Name = "By", Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(900, 30), FontFace = Theme.Bold, TextSize = 20, RichText = true, ZIndex = 36, Parent = d })
	Theme.textStroke(ui.deathBy, 1.5)
	ui.deathTimer = Theme.label({ Name = "Timer", Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromOffset(900, 26), FontFace = Theme.Medium, TextSize = 17, TextColor3 = Theme.Dim, ZIndex = 36, Parent = d })
end

local HINTS = {
	{ "ЛКМ", "удар (зажми — серия)" },
	{ "F", "блок (вовремя — парирование)" },
	{ "Q", "рывок  ·  A/D + Q — уворот" },
	{ "1–4", "приёмы" },
	{ "Пробел", "+ 4-й удар — апперкот" },
	{ "G", "пробуждение (шкала полна)" },
	{ "M", "меню и персонажи" },
}
local function buildHints(root)
	local h = Theme.frame({ Name = "Hints", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16), Size = UDim2.fromOffset(268, 24 + #HINTS * 22),
		BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.3, Parent = root })
	Theme.corner(h, 6)
	Theme.stroke(h, Theme.Line, 1.2, 0.4)
	Theme.label({ Name = "Head", Text = "УПРАВЛЕНИЕ  ·  H — скрыть", Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 18),
		FontFace = Theme.Black, TextSize = 11, TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Left, Parent = h })
	for i, row in ipairs(HINTS) do
		local y = 22 + (i - 1) * 22
		local k = Theme.label({ Name = "K" .. i, Text = row[1], Position = UDim2.fromOffset(10, y + 2), Size = UDim2.fromOffset(math.max(22, textWidth(row[1], 12) + 10), 18),
			BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(230, 230, 236), TextColor3 = BLACK, FontFace = Theme.Black, TextSize = 12, Parent = h })
		Theme.corner(k, 4)
		Theme.label({ Name = "T" .. i, Text = row[2], Position = UDim2.fromOffset(78, y), Size = UDim2.fromOffset(186, 22),
			FontFace = Theme.Medium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = h })
	end
	ui.hints = h
end

-- gui — основной HUD (прячется вместе с меню), overlay — поверх всего (объявления, вспышки, уведомления)
function Hud.init(gui, overlay)
	ui.gui = gui
	local root = Hud.makeRoot(gui, "HUD")
	ui.root = root
	local top = Hud.makeRoot(overlay or gui, "Overlay")
	ui.top = top
	buildBottom(root)
	buildCard(root)
	buildCombo(root)
	buildFeed(root)
	buildAnnounce(top)
	buildCenter(top)
	buildDeath(root)
	buildHints(root)
	if touchOnly() then
		ui.hints.Visible = false
		ui.menuKey.Visible = false
		for _, s in ipairs(ui.slots) do s.key.Visible = false end
		ui.dashF.label.Text = "РЫВОК"
		ui.dashS.label.Text = "УВОРОТ"
		ui.block.label.Text = "БЛОК"
	end
	-- подсказки прячутся сами через 40 с
	task.delay(40, function()
		if ui.hints.Visible then tween(ui.hints, 0.5, { BackgroundTransparency = 1 }) task.wait(0.5) ui.hints.Visible = false end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.H then
			ui.hints.Visible = not ui.hints.Visible
			ui.hints.BackgroundTransparency = 0.3
		end
	end)
	Hud.setCharacter(player:GetAttribute("CharId") or Characters.Default, false)
end

---------------------------------------------------------------- персонаж и приёмы
Hud.charId = nil
Hud.awakened = false

function Hud.setCharacter(charId, awakened)
	if not Characters.valid(charId) then charId = Characters.Default end
	Hud.charId = charId
	Hud.awakened = awakened and true or false
	local def = Characters.get(charId)
	local moves = Characters.moveset(charId, Hud.awakened)
	ui.cardName.Text = string.upper(def.Name)
	ui.cardTitle.Text = def.Title .. "  ·  сложность: " .. string.lower(def.Difficulty)
	ui.cardStripe.BackgroundColor3 = def.Color
	ui.cardGrad.Color = ColorSequence.new(def.Color, Theme.Panel)
	ui.name.Text = player.DisplayName .. '  <font color="' .. hex(def.Color) .. '">' .. def.Name .. "</font>"
	ui.meter.grad.Color = ColorSequence.new(def.Color, def.Accent)
	for i, s in ipairs(ui.slots) do
		local m = moves[i]
		s.name.Text = m and string.upper(m.Name) or ""
		s.accent.BackgroundColor3 = (m and m.Ultimate) and Theme.Gold or def.Color
		s.tag.Text = (m and m.Ultimate) and (m.Domain and "ТЕРРИТОРИЯ" or "УЛЬТА") or ""
		s.stroke.Color = (m and m.Ultimate) and Theme.Gold or Theme.Line
		if Hud.awakened then
			s.grad.Color = ColorSequence.new(Theme.shade(def.Dark, 0.15), Color3.fromRGB(12, 12, 18))
		else
			s.grad.Color = ColorSequence.new(Color3.fromRGB(34, 34, 46), Color3.fromRGB(12, 12, 18))
		end
	end
end

---------------------------------------------------------------- кадр
local function setBar(b, value, dt, ghostRate)
	b.shown = b.shown + (value - b.shown) * math.min(1, dt * 18)
	if value > b.ghostV then b.ghostV = value else b.ghostV = b.ghostV + (value - b.ghostV) * math.min(1, dt * (ghostRate or 2.2)) end
	b.fill.Size = UDim2.fromScale(math.clamp(b.shown, 0, 1), 1)
	b.ghost.Size = UDim2.fromScale(math.clamp(b.ghostV, 0, 1), 1)
end

local pulse = 0
local function fmtTime(t)
	if t >= 10 then return string.format("%d", math.ceil(t)) end
	return string.format("%.1f", t)
end

function Hud.update(dt)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	pulse = pulse + dt
	-- здоровье
	if hum then
		local frac = hum.MaxHealth > 0 and hum.Health / hum.MaxHealth or 0
		setBar(ui.hp, frac, dt)
		ui.hpText.Text = string.format("%d", math.ceil(math.max(0, hum.Health)))
		local col = frac > 0.5 and Theme.Good or (frac > 0.25 and Color3.fromRGB(255, 200, 70) or Theme.Bad)
		ui.hp.grad.Color = ColorSequence.new(col, Theme.shade(col, -0.3))
	end
	-- пробуждение
	local meter = char and (char:GetAttribute("Meter") or 0) or 0
	local awakened = char and char:GetAttribute("Awakened") or false
	setBar(ui.meter, meter / Config.Awaken.Max, dt)
	local def = Characters.get(Hud.charId)
	if awakened then
		local left = meter / Config.Awaken.Max * Config.Awaken.Duration
		ui.awakenText.Text = string.format("%s  %d:%02d", def.Awakening.Name, math.floor(left / 60), math.floor(left % 60))
		ui.awakenText.TextColor3 = def.Accent
		ui.meterGlow.BackgroundTransparency = 0.6 + 0.15 * math.sin(pulse * 6)
		ui.meterGlow.BackgroundColor3 = def.Color
	elseif meter >= Config.Awaken.Max then
		ui.awakenText.Text = touchOnly() and "НАЖМИ НА ШКАЛУ — ПРОБУЖДЕНИЕ!" or "G — ПРОБУЖДЕНИЕ!"
		ui.awakenText.TextColor3 = Theme.Gold:Lerp(WHITE, 0.5 + 0.5 * math.sin(pulse * 8))
		ui.meterGlow.BackgroundTransparency = 0.45 + 0.3 * math.sin(pulse * 8)
		ui.meterGlow.BackgroundColor3 = Theme.Gold
	else
		ui.awakenText.Text = string.format("ПРОБУЖДЕНИЕ  %d%%", math.floor(meter))
		ui.awakenText.TextColor3 = Theme.Dim
		ui.meterGlow.BackgroundTransparency = 1
	end
	if awakened ~= Hud.awakened and Hud.charId then Hud.setCharacter(Hud.charId, awakened) end
	-- приёмы
	local now = workspace:GetServerTimeNow()
	local silenced = char and char:GetAttribute("Silenced")
	local rc = Controller.recast
	for i, s in ipairs(ui.slots) do
		local left = (Controller.cds[i] or 0) - now
		local len = math.max(0.1, Controller.cdLen[i] or 1)
		local recast = rc and rc.slot == i and now <= rc.to
		if recast then
			s.cd.Size = UDim2.fromScale(1, 0)
			s.time.Text = ""
			local open = now >= rc.from
			s.glow.BackgroundTransparency = open and (0.55 + 0.25 * math.sin(pulse * 30)) or 0.85
			s.glow.BackgroundColor3 = Theme.Gold
			s.tag.Text = "ЕЩЁ РАЗ!"
			s.name.TextTransparency = 0
		elseif left > 0 then
			s.cd.Size = UDim2.fromScale(1, math.clamp(left / len, 0, 1))
			s.time.Text = fmtTime(left)
			s.name.TextTransparency = 0.45
			s.wasReady = false
			if s.glow.BackgroundColor3 == Theme.Gold then s.glow.BackgroundTransparency = 1 end
		else
			s.cd.Size = UDim2.fromScale(1, 0)
			s.time.Text = ""
			s.name.TextTransparency = 0
			if not s.wasReady then
				s.wasReady = true
				s.glow.BackgroundColor3 = WHITE
				s.glow.BackgroundTransparency = 0.35
				tween(s.glow, 0.45, { BackgroundTransparency = 1 })
			end
			if s.tag.Text == "ЕЩЁ РАЗ!" then
				local moves = Characters.moveset(Hud.charId, Hud.awakened)
				local m = moves[i]
				s.tag.Text = (m and m.Ultimate) and (m.Domain and "ТЕРРИТОРИЯ" or "УЛЬТА") or ""
				s.glow.BackgroundTransparency = 1
			end
		end
		if silenced and not recast then s.name.TextTransparency = 0.6 end
	end
	-- рывок
	local t = os.clock()
	local function dashChip(c, keys)
		local rem, total = 0, 1
		for _, k in ipairs(keys) do
			local r = (Controller.dashReady[k] or 0) - t
			if r > rem then
				rem = r
				total = (k == "F" and Config.Dash.FrontCooldown) or (k == "B" and Config.Dash.BackCooldown) or Config.Dash.SideCooldown
			end
		end
		c.fill.Size = UDim2.fromScale(math.clamp(rem / total, 0, 1), 1)
		c.label.TextTransparency = rem > 0 and 0.45 or 0
	end
	dashChip(ui.dashF, { "F" })
	dashChip(ui.dashS, { "L", "R" })
	local blocking = char and (char:GetAttribute("Blocking") or Controller.state.blocking)
	local broken = char and char:GetAttribute("GuardBroken")
	if broken then
		ui.block.fill.Size = UDim2.fromScale(1, 1)
		ui.block.fill.BackgroundColor3 = Theme.Bad
		ui.block.label.Text = "БЛОК ПРОБИТ"
	elseif blocking then
		ui.block.fill.Size = UDim2.fromScale(1, 1)
		ui.block.fill.BackgroundColor3 = Color3.fromRGB(90, 150, 255)
		ui.block.label.Text = touchOnly() and "БЛОК" or "F  БЛОК"
	else
		ui.block.fill.Size = UDim2.fromScale(0, 1)
		ui.block.label.Text = touchOnly() and "БЛОК" or "F  БЛОК"
	end
	-- экран поражения
	if ui.deathUntil then
		local rem = ui.deathUntil - os.clock()
		if rem > 0 then
			ui.deathTimer.Text = string.format("Возрождение через %d…", math.ceil(rem))
		else
			ui.deathTimer.Text = "Возрождение…"
		end
	end
end

---------------------------------------------------------------- реакции
function Hud.denied(what, slot)
	if what == "cooldown" and slot and ui.slots[slot] then
		local s = ui.slots[slot]
		s.frame.Position = s.base + UDim2.fromOffset(4, 0)
		tween(s.frame, 0.18, { Position = s.base }, Enum.EasingStyle.Elastic)
	elseif what == "silenced" then
		Hud.notify("Внутри чужой территории приёмы не работают!", "bad")
	elseif what == "meter" then
		ui.meterGlow.BackgroundColor3 = Theme.Bad
		ui.meterGlow.BackgroundTransparency = 0.5
		tween(ui.meterGlow, 0.4, { BackgroundTransparency = 1 })
	end
end

function Hud.pressed(slot)
	local s = ui.slots[slot]
	if not s then return end
	s.glow.BackgroundColor3 = WHITE
	s.glow.BackgroundTransparency = 0.6
	tween(s.glow, 0.25, { BackgroundTransparency = 1 })
end

function Hud.flash(color, t, a)
	local f = ui.flash
	f.BackgroundColor3 = color or WHITE
	f.BackgroundTransparency = 1 - (a or 0.3)
	tween(f, t or 0.25, { BackgroundTransparency = 1 })
end

local annToken = 0
function Hud.announce(text, color, sub)
	annToken = annToken + 1
	local tok = annToken
	color = color or WHITE
	ui.annText.Text = text or ""
	ui.annSub.Text = sub or ""
	ui.annText.TextColor3 = WHITE
	ui.annStroke.Color = Theme.shade(color, -0.6)
	ui.annBandGrad.Color = ColorSequence.new(color, color)
	ui.annText.TextSize = 70
	ui.annText.TextTransparency = 0
	ui.annStroke.Transparency = 0.1
	ui.annSub.TextTransparency = sub and 0 or 1
	ui.annSub.TextColor3 = color:Lerp(WHITE, 0.35)
	ui.annBand.BackgroundTransparency = 0.25
	ui.annBand.Size = UDim2.new(0.2, 0, 0, 64)
	tween(ui.annText, 0.25, { TextSize = 50 }, Enum.EasingStyle.Back)
	tween(ui.annBand, 0.3, { Size = UDim2.new(1, 0, 0, 64) })
	task.delay(2.2, function()
		if tok ~= annToken then return end
		tween(ui.annText, 0.5, { TextTransparency = 1 })
		tween(ui.annStroke, 0.5, { Transparency = 1 })
		tween(ui.annSub, 0.5, { TextTransparency = 1 })
		tween(ui.annBand, 0.5, { BackgroundTransparency = 1 })
	end)
end

local notifyToken = 0
function Hud.notify(text, kind)
	notifyToken = notifyToken + 1
	local tok = notifyToken
	local n = ui.notify
	n.Text = text
	n.Size = UDim2.fromOffset(math.max(260, textWidth(text, 16) + 40), 34)
	n.TextTransparency = 0
	n.BackgroundTransparency = 0.15
	ui.notifyStroke.Transparency = 0.2
	ui.notifyStroke.Color = kind == "bad" and Theme.Bad or (kind == "good" and Theme.Good or Theme.Line)
	if kind == "bad" then SoundFX.play("Click", nil, 0.6) end
	task.delay(2.6, function()
		if tok ~= notifyToken then return end
		tween(n, 0.4, { TextTransparency = 1, BackgroundTransparency = 1 })
		tween(ui.notifyStroke, 0.4, { Transparency = 1 })
	end)
end

local cueToken = 0
function Hud.cue(window)
	cueToken = cueToken + 1
	local tok = cueToken
	local c = ui.cue
	c.Text = "ЖМИ!"
	c.TextSize = 70
	c.TextTransparency = 0
	ui.cueStroke.Transparency = 0.1
	tween(c, 0.12, { TextSize = 46 }, Enum.EasingStyle.Back)
	SoundFX.play("Ready", nil, 0.8)
	task.delay(math.max(0.2, window or 0.25), function()
		if tok ~= cueToken then return end
		tween(c, 0.2, { TextTransparency = 1 })
		tween(ui.cueStroke, 0.2, { Transparency = 1 })
	end)
end

local comboToken = 0
function Hud.combo(n)
	comboToken = comboToken + 1
	local tok = comboToken
	local c = ui.combo
	if not n or n < 2 then
		if c.Visible then
			tween(ui.comboNum, 0.3, { TextTransparency = 1 })
			tween(ui.comboLabel, 0.3, { TextTransparency = 1 })
			task.delay(0.3, function() if tok == comboToken then c.Visible = false end end)
		end
		return
	end
	c.Visible = true
	ui.comboNum.Text = tostring(n)
	ui.comboLabel.Text = n >= 20 and "БЕЗУМНОЕ КОМБО" or (n >= 10 and "СУПЕР КОМБО" or "УДАРОВ")
	ui.comboNum.TextTransparency = 0
	ui.comboLabel.TextTransparency = 0
	local hot = n >= 10 and Theme.Bad or Theme.Gold
	ui.comboGrad.Color = ColorSequence.new(WHITE, hot)
	ui.comboNum.TextSize = 92
	tween(ui.comboNum, 0.16, { TextSize = 72 }, Enum.EasingStyle.Back)
end

-- лента убийств
function Hud.killfeed(d)
	local feed = ui.feed
	ui.feedN = ui.feedN + 1
	local kname, vname = d.k, d.v or "?"
	local kc, vc = d.kc or WHITE, d.vc or WHITE
	local mine = (kname == player.DisplayName) or (vname == player.DisplayName)
	local size = 15
	local wK = kname and textWidth(kname, size) or 0
	local wV = textWidth(vname, size)
	local w = math.floor(wK + wV + (kname and 64 or 40))
	local e = Theme.frame({ Name = "Kill" .. ui.feedN, LayoutOrder = -ui.feedN, Size = UDim2.fromOffset(w, 28), BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.2, Parent = feed })
	Theme.corner(e, 5)
	local st = Theme.stroke(e, mine and Theme.Gold or Theme.Line, mine and 1.6 or 1.1, mine and 0.1 or 0.4)
	local x = 10
	local labels = {}
	if kname then
		labels[#labels + 1] = Theme.label({ Name = "Killer", Text = kname, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(wK + 2, 28),
			FontFace = Theme.Black, TextSize = size, TextColor3 = kc:Lerp(WHITE, 0.25), TextXAlignment = Enum.TextXAlignment.Left, Parent = e })
		x = x + wK + 8
	end
	-- значок: два скрещённых клинка
	local icon = Theme.frame({ Name = "Icon", BackgroundTransparency = 1, Position = UDim2.fromOffset(x, 4), Size = UDim2.fromOffset(20, 20), Parent = e })
	for _, r in ipairs({ 45, -45 }) do
		labels[#labels + 1] = Theme.frame({ Name = "Blade", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(20, 3), Rotation = r, BackgroundColor3 = kname and Theme.Bad or Theme.Dim, Parent = icon })
	end
	x = x + 26
	labels[#labels + 1] = Theme.label({ Name = "Victim", Text = vname, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(wV + 2, 28),
		FontFace = Theme.Black, TextSize = size, TextColor3 = vc:Lerp(WHITE, 0.25), TextXAlignment = Enum.TextXAlignment.Left, Parent = e })
	-- не больше 6 строк
	local kids = {}
	for _, c in ipairs(feed:GetChildren()) do if c:IsA("Frame") then kids[#kids + 1] = c end end
	table.sort(kids, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	for i = 7, #kids do kids[i]:Destroy() end
	task.delay(7, function()
		if not e.Parent then return end
		tween(e, 0.5, { BackgroundTransparency = 1 })
		tween(st, 0.5, { Transparency = 1 })
		for _, l in ipairs(labels) do
			if l:IsA("TextLabel") then tween(l, 0.5, { TextTransparency = 1 }) else tween(l, 0.5, { BackgroundTransparency = 1 }) end
		end
		task.wait(0.55)
		e:Destroy()
	end)
	-- моё поражение
	if vname == player.DisplayName and d.kind == "player" then Hud.death(kname, kc) end
end

-- цифры урона над целью
local dmgStack = {}
function Hud.damage(model, amount, color, crit, dot)
	if not Hud.showDamage or not model then return end
	local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
	if not root then return end
	local now = os.clock()
	local st = dmgStack[model]
	if not st or now - st.t > 0.6 then st = { t = now, n = 0 } end
	st.t = now
	st.n = (st.n + 1) % 4
	dmgStack[model] = st
	local bb = Instance.new("BillboardGui")
	bb.Name = "Damage"
	bb.Adornee = root
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(140, 48)
	bb.StudsOffset = Vector3.new((math.random() - 0.5) * 2.4, 2.6 + st.n * 0.7, 0)
	bb.MaxDistance = 160
	local l = Theme.label({ Name = "Amount", Text = string.format(amount >= 10 and "%d" or "%.1f", amount), Size = UDim2.fromScale(1, 1),
		FontFace = Theme.BlackItalic, TextSize = crit and 40 or (dot and 20 or 28), TextColor3 = crit and Color3.fromRGB(255, 60, 60) or (color or WHITE):Lerp(WHITE, 0.35),
		Parent = bb })
	Theme.textStroke(l, crit and 3 or 2)
	bb.Parent = player:FindFirstChildOfClass("PlayerGui")
	l.TextSize = (crit and 56 or 38)
	tween(l, 0.15, { TextSize = crit and 40 or (dot and 20 or 28) }, Enum.EasingStyle.Back)
	tween(bb, 0.8, { StudsOffset = bb.StudsOffset + Vector3.new(0, 2.2, 0) }, Enum.EasingStyle.Quad)
	task.delay(0.45, function() tween(l, 0.35, { TextTransparency = 1 }) end)
	game:GetService("Debris"):AddItem(bb, 0.9)
end

function Hud.death(killer, kc)
	local d = ui.death
	if not ui.deathUntil then
		d.Visible = true
		d.BackgroundTransparency = 1
		tween(d, 0.6, { BackgroundTransparency = 0.25 })
		ui.deathTitle.TextTransparency = 1
		tween(ui.deathTitle, 0.4, { TextTransparency = 0 })
		ui.deathUntil = os.clock() + Config.RespawnTime
		ui.deathBy.Text = ""
	end
	if killer then
		ui.deathBy.Text = 'Вас победил <font color="' .. hex((kc or WHITE):Lerp(WHITE, 0.2)) .. '">' .. killer .. "</font>"
	end
end

function Hud.respawned()
	ui.deathUntil = nil
	if ui.death.Visible then
		tween(ui.death, 0.3, { BackgroundTransparency = 1 })
		tween(ui.deathTitle, 0.3, { TextTransparency = 1 })
		task.delay(0.32, function() ui.death.Visible = false end)
	end
end

function Hud.setVisible(on)
	ui.root.Visible = on
end

return Hud
