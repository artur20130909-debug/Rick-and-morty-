-- Клиент: оживляет карту и меняет атмосферу по зонам.
--   * метки Spin / Bob / Pulse / Zap (ставит сервер при постройке): вращение, покачивание,
--     пульсация неона, «молнии» катушек Теслы — только рядом с камерой, чтобы не тратить FPS;
--   * дымка и оттенок плавно меняются, когда игрок переходит в другую зону;
--   * при входе в зону сверху экрана всплывает её название.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local D = require(RS.Shared.MapData)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local NEAR = 260 -- анимируем только то, что ближе

if not game:IsLoaded() then game.Loaded:Wait() end
if not workspace:GetAttribute("MapReady") then
	workspace:GetAttributeChangedSignal("MapReady"):Wait()
end

---------------------------------------------------------------------------
-- Анимации по меткам
---------------------------------------------------------------------------
local movers, pulses, zaps = {}, {}, {}

local function pivotOf(inst)
	if inst:IsA("Model") then return inst:GetPivot() end
	return inst.CFrame
end

local function addMover(inst)
	if movers[inst] then return end
	movers[inst] = {
		base = pivotOf(inst),
		spin = inst:HasTag("Spin") and (inst:GetAttribute("Speed") or 30) or 0,
		axisX = inst:GetAttribute("Axis") == "X",
		bobH = inst:HasTag("Bob") and (inst:GetAttribute("Height") or 1) or 0,
		bobT = inst:GetAttribute("Period") or 3,
		phase = (pivotOf(inst).Position.X * 0.37 + pivotOf(inst).Position.Z * 0.11) % (math.pi * 2),
	}
end
local function addPulse(inst)
	if inst:IsA("BasePart") and not pulses[inst] then
		local light = inst:FindFirstChildWhichIsA("Light")
		pulses[inst] = { speed = inst:GetAttribute("Speed") or 1.5, light = light, bright = light and light.Brightness or 0,
			phase = (inst.Position.X + inst.Position.Z) % 6 }
	end
end
local function addZap(inst)
	if inst:IsA("Beam") and not table.find(zaps, inst) then table.insert(zaps, inst) end
end
-- метки уже на месте + те, что появятся позже (детали догружаются)
for _, tag in ipairs({ "Spin", "Bob" }) do
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do addMover(inst) end
	CollectionService:GetInstanceAddedSignal(tag):Connect(addMover)
end
for _, inst in ipairs(CollectionService:GetTagged("Pulse")) do addPulse(inst) end
CollectionService:GetInstanceAddedSignal("Pulse"):Connect(addPulse)
for _, inst in ipairs(CollectionService:GetTagged("Zap")) do addZap(inst) end
CollectionService:GetInstanceAddedSignal("Zap"):Connect(addZap)

local zapTimer = 0
RunService.Heartbeat:Connect(function(dt)
	local t = os.clock()
	local cam = camera.CFrame.Position
	for inst, m in pairs(movers) do
		local p = m.base.Position
		if (p - cam).Magnitude < NEAR and inst.Parent then
			local cf = m.base
			if m.bobH ~= 0 then
				cf = cf + Vector3.new(0, math.sin(t * 2 * math.pi / m.bobT + m.phase) * m.bobH, 0)
			end
			if m.spin ~= 0 then
				local a = math.rad(m.spin * t)
				cf = cf * (m.axisX and CFrame.Angles(a, 0, 0) or CFrame.Angles(0, a, 0))
			end
			if inst:IsA("Model") then inst:PivotTo(cf) else inst.CFrame = cf end
		end
	end
	for part, pl in pairs(pulses) do
		if (part.Position - cam).Magnitude < NEAR then
			local k = 0.5 + 0.5 * math.sin(t * pl.speed * 2 + pl.phase)
			part.Transparency = 0.45 * (1 - k)
			if pl.light then pl.light.Brightness = pl.bright * (0.4 + 0.6 * k) end
		end
	end
	zapTimer = zapTimer + dt
	if zapTimer > 0.08 then
		zapTimer = 0
		for _, beam in ipairs(zaps) do
			beam.CurveSize0 = math.random() * 8 - 4
			beam.CurveSize1 = math.random() * 8 - 4
			beam.Transparency = NumberSequence.new(math.random() < 0.15 and 1 or 0.1, 0.3)
		end
	end
end)

---------------------------------------------------------------------------
-- Атмосфера зон и название зоны
---------------------------------------------------------------------------
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local FADE = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local function applyAmbience(key)
	local a = D.Ambience[key] or D.Ambience.Hub
	if atmosphere then
		TweenService:Create(atmosphere, FADE, { Density = a.density, Haze = a.haze, Color = a.color, Decay = a.decay, Glare = a.glare }):Play()
	end
	if correction then
		TweenService:Create(correction, FADE, { TintColor = a.tint, Saturation = a.saturation, Contrast = a.contrast, Brightness = a.brightness }):Play()
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = "ZoneTitle"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")
local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.fromScale(0.5, 0.12)
title.Size = UDim2.fromScale(0.6, 0.07)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = Color3.new(1, 1, 1)
title.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
title.TextTransparency = 1
title.TextStrokeTransparency = 1
title.Text = ""
title.Parent = gui
local sub = Instance.new("TextLabel")
sub.AnchorPoint = Vector2.new(0.5, 0)
sub.Position = UDim2.fromScale(0.5, 0.19)
sub.Size = UDim2.fromScale(0.4, 0.035)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.GothamBold
sub.TextScaled = true
sub.TextColor3 = Color3.fromRGB(220, 230, 240)
sub.TextStrokeTransparency = 1
sub.TextTransparency = 1
sub.Text = ""
sub.Parent = gui

local showToken = 0
local function showTitle(area)
	local name = D.AreaNames[area]
	if not name then return end
	local zone = D.ZoneById[area]
	title.Text = name
	title.TextColor3 = zone and zone.accent:Lerp(Color3.new(1, 1, 1), 0.35) or Color3.new(1, 1, 1)
	sub.Text = zone and ("Зона " .. zone.index) or ""
	showToken = showToken + 1
	local my = showToken
	local fadeIn = TweenInfo.new(0.5)
	TweenService:Create(title, fadeIn, { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
	TweenService:Create(sub, fadeIn, { TextTransparency = 0.1 }):Play()
	task.delay(3, function()
		if my ~= showToken then return end
		local fadeOut = TweenInfo.new(1)
		TweenService:Create(title, fadeOut, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(sub, fadeOut, { TextTransparency = 1 }):Play()
	end)
end

local currentArea, currentAmbience
local checkTimer = 0
RunService.Heartbeat:Connect(function(dt)
	checkTimer = checkTimer + dt
	if checkTimer < 0.4 then return end
	checkTimer = 0
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local area, amb = D.areaAt(root.Position)
	if amb ~= currentAmbience then
		currentAmbience = amb
		applyAmbience(amb)
	end
	if area ~= currentArea then
		local prev = currentArea
		currentArea = area
		if area ~= "Wild" and not (area == "Plots" and prev == "Wild") then showTitle(area) end
	end
end)
