-- Надписи лобби: табло кабинок (сложность, игроки, отсчёт), большой экран над площадью
-- и подсказка внизу экрана. Всё рисуется из атрибутов, которые выставляет сервер.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LobbySigns = {}
local ctx, Config
local FONT = Enum.Font.Code
local AMBER = Color3.fromRGB(255, 176, 0)
local DIFF_COLORS = { easy = Color3.fromRGB(110, 230, 120), normal = Color3.fromRGB(255, 190, 60),
	hard = Color3.fromRGB(255, 80, 70), endless = Color3.fromRGB(190, 120, 255) }

local function label(parent, text, size, pos, color, scaled)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = FONT
	l.Text = text
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextScaled = scaled ~= false
	l.TextStrokeTransparency = 0.6
	l.Parent = parent
	return l
end

local function surface(part)
	local old = part:FindFirstChild("LobbyScreen")
	if old then old:Destroy() end
	local g = Instance.new("SurfaceGui")
	g.Name = "LobbyScreen"
	g.Face = Enum.NormalId[part:GetAttribute("ScreenFace") or "Front"] or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 50
	g.LightInfluence = 0
	g.Brightness = 2
	g.Parent = part
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
	bg.BorderSizePixel = 0
	bg.Parent = g
	return g, bg
end

local booths = {}
local function setupBooth(model)
	local sign = model:FindFirstChild("Sign", true)
	if not sign or not sign:IsA("BasePart") then return end
	local _, bg = surface(sign)
	local key = model:GetAttribute("Difficulty") or "normal"
	local d = Config.Difficulties[key]
	local col = DIFF_COLORS[key] or AMBER
	local title = label(bg, d and string.upper(d.name) or key, UDim2.fromScale(1, 0.42), UDim2.fromScale(0, 0.04), col)
	local info = label(bg, "", UDim2.fromScale(1, 0.24), UDim2.fromScale(0, 0.48), Color3.fromRGB(230, 230, 230))
	local cd = label(bg, "", UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0.74), AMBER)
	local function upd()
		local n = model:GetAttribute("Count") or 0
		local max = model:GetAttribute("Max") or 4
		local c = model:GetAttribute("Countdown") or -1
		local nights = d and (d.endless and "∞ ночей" or (d.nights .. " ночей")) or ""
		info.Text = "ИГРОКИ " .. n .. "/" .. max .. "  ·  " .. nights
		if c >= 0 and n > 0 then cd.Text = "СТАРТ ЧЕРЕЗ " .. c else cd.Text = "ЗАЙДИ ВНУТРЬ" end
	end
	for _, a in ipairs({ "Count", "Max", "Countdown" }) do model:GetAttributeChangedSignal(a):Connect(upd) end
	upd()
	booths[model] = { title = title, cd = cd }
end

local billboard = nil
local function setupBillboard(part)
	local _, bg = surface(part)
	local head = Instance.new("Frame")
	head.Size = UDim2.fromScale(1, 0.22)
	head.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
	head.BorderSizePixel = 0
	head.Parent = bg
	label(head, "⚠ ЭКСТРЕННОЕ ОПОВЕЩЕНИЕ ⚠", UDim2.fromScale(1, 0.8), UDim2.fromScale(0, 0.1), Color3.new(1, 1, 1))
	label(bg, Config.GameName or "STAY INSIDE", UDim2.fromScale(1, 0.34), UDim2.fromScale(0, 0.26), AMBER)
	local online = label(bg, "", UDim2.fromScale(1, 0.12), UDim2.fromScale(0, 0.62), Color3.fromRGB(200, 200, 210))
	local clip = Instance.new("Frame")
	clip.Size = UDim2.fromScale(1, 0.16)
	clip.Position = UDim2.fromScale(0, 0.8)
	clip.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	clip.BorderSizePixel = 0
	clip.ClipsDescendants = true
	clip.Parent = bg
	local ticker = label(clip, "ЛЕЧЕБНИЦА ASHGROVE: ЗАКЛЮЧЁННЫЕ НА СВОБОДЕ  ·  НЕ ОТКРЫВАЙТЕ ДВЕРЬ НЕЗНАКОМЦАМ  ·  "
		.. "ЗАЙДИТЕ В КАБИНКУ, ЧТОБЫ НАЧАТЬ  ·  СЛЕДИТЕ ЗА ТЕЛЕВИЗОРОМ В 21:00  ·  ", UDim2.fromScale(3, 1), UDim2.fromScale(0, 0), AMBER)
	ticker.TextXAlignment = Enum.TextXAlignment.Left
	billboard = { head = head, online = online, ticker = ticker }
end

-- подсказка и баланс внизу экрана в лобби
local hud = nil
local function setupHud()
	local pg = ctx.player:WaitForChild("PlayerGui")
	local g = Instance.new("ScreenGui")
	g.Name = "LobbyHint"
	g.ResetOnSpawn = false
	g.Parent = pg
	local l = label(g, "", UDim2.new(0.6, 0, 0, 26), UDim2.new(0.2, 0, 1, -40), AMBER)
	l.TextStrokeTransparency = 0.2
	hud = { gui = g, label = l }
end

local function scan(lobby)
	for _, d in ipairs(lobby:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("Kind") == "Booth" and not booths[d] then pcall(setupBooth, d) end
		if d:IsA("BasePart") and d.Name == "Billboard" and not billboard then pcall(setupBillboard, d) end
	end
end

function LobbySigns.init(c)
	ctx = c
	Config = c.Config
	pcall(setupHud)
	task.spawn(function()
		local lobby = workspace:WaitForChild("Lobby", 60)
		if not lobby then return end
		task.wait(1)
		scan(lobby)
		lobby.DescendantAdded:Connect(function() task.defer(scan, lobby) end)
	end)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local inLobby = (ctx.player:GetAttribute("MatchId") or 0) == 0
		if hud then
			hud.gui.Enabled = inLobby
			if inLobby then
				hud.label.Text = "Amber: " .. (ctx.player:GetAttribute("Amber") or 0) .. "   ·   Уровень " .. (ctx.player:GetAttribute("Level") or 1)
					.. " " .. (ctx.player:GetAttribute("Rank") or "") .. "   ·   Зайди в кабинку, чтобы начать"
			end
		end
		if billboard then
			billboard.head.BackgroundColor3 = (math.floor(t * 2) % 2 == 0) and Color3.fromRGB(170, 0, 0) or Color3.fromRGB(90, 0, 0)
			billboard.ticker.Position = UDim2.fromScale(-((t * 0.04) % 1) * 2, 0)
			billboard.online.Text = "ИГРОКОВ НА СЕРВЕРЕ: " .. #Players:GetPlayers()
		end
		for _, b in pairs(booths) do
			b.cd.TextTransparency = (b.cd.Text ~= "ЗАЙДИ ВНУТРЬ" and math.floor(t * 3) % 2 == 0) and 0.4 or 0
		end
	end)
end

return LobbySigns
