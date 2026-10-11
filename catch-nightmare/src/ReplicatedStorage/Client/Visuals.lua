-- Что клиент делает с миром у себя: освещение дня/ночи и событий, показ подсказок только тем,
-- кому они нужны (свою клетку нельзя «украсть», чужую — «продать»), проход хозяина через
-- запертую дверь своей базы, покачивание монстров в клетках, метка «ТВОЯ БАЗА», таймер замков.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Util = require(Shared.Util)

local Visuals = {}
local player = Players.LocalPlayer
local state = RS:WaitForChild("State")

---------------------------------------------------------------- освещение
local atmo, cc, bloom
local clock = Instance.new("NumberValue")
clock.Value = 14.5

local PRESETS = {
	day = {
		clock = 14.5, light = { Brightness = 2.2, Ambient = Color3.fromRGB(70, 70, 85), OutdoorAmbient = Color3.fromRGB(125, 125, 140),
			FogStart = 200, FogEnd = 900, FogColor = Color3.fromRGB(170, 180, 200), ExposureCompensation = 0 },
		atmo = { Density = 0.25, Color = Color3.fromRGB(200, 190, 215), Decay = Color3.fromRGB(110, 100, 130), Haze = 1 },
		cc = { TintColor = Color3.fromRGB(255, 250, 245), Saturation = 0.05, Contrast = 0.05, Brightness = 0 },
	},
	night = {
		clock = 24.2, light = { Brightness = 0.6, Ambient = Color3.fromRGB(22, 22, 38), OutdoorAmbient = Color3.fromRGB(45, 48, 80),
			FogStart = 30, FogEnd = 280, FogColor = Color3.fromRGB(12, 12, 26), ExposureCompensation = 0.2 },
		atmo = { Density = 0.42, Color = Color3.fromRGB(40, 42, 75), Decay = Color3.fromRGB(20, 20, 45), Haze = 2 },
		cc = { TintColor = Color3.fromRGB(205, 210, 255), Saturation = -0.15, Contrast = 0.1, Brightness = 0 },
	},
}
local function variant(base, light, atmoP, ccP)
	local p = { clock = base.clock, light = {}, atmo = {}, cc = {} }
	for k, v in pairs(base.light) do p.light[k] = v end
	for k, v in pairs(base.atmo) do p.atmo[k] = v end
	for k, v in pairs(base.cc) do p.cc[k] = v end
	for k, v in pairs(light or {}) do p.light[k] = v end
	for k, v in pairs(atmoP or {}) do p.atmo[k] = v end
	for k, v in pairs(ccP or {}) do p.cc[k] = v end
	return p
end
PRESETS.bloodmoon = variant(PRESETS.night, { OutdoorAmbient = Color3.fromRGB(90, 25, 30), FogColor = Color3.fromRGB(45, 0, 6) },
	{ Color = Color3.fromRGB(95, 15, 20), Decay = Color3.fromRGB(60, 5, 10) }, { TintColor = Color3.fromRGB(255, 165, 165), Saturation = 0.1 })
PRESETS.glitch = variant(PRESETS.night, { OutdoorAmbient = Color3.fromRGB(60, 30, 95), FogColor = Color3.fromRGB(25, 5, 40) },
	{ Color = Color3.fromRGB(70, 25, 110) }, { TintColor = Color3.fromRGB(225, 185, 255), Saturation = 0.35 })
PRESETS.fog = variant(PRESETS.night, { FogStart = 4, FogEnd = 95, FogColor = Color3.fromRGB(40, 44, 55) }, { Density = 0.65 }, {})

local current = nil
local function applyLighting(instant)
	local phase = state:GetAttribute("Phase") or "day"
	local key = phase
	if phase == "night" then
		local ev = state:GetAttribute("Event") or ""
		if PRESETS[ev] then key = ev end
	end
	if key == current then return end
	current = key
	local p = PRESETS[key]
	local info = TweenInfo.new(instant and 0 or 4, Enum.EasingStyle.Sine)
	-- время суток крутим через число, чтобы закат шёл вперёд, а не назад
	local target = p.clock
	if target < clock.Value and phase == "night" then target = target + 24 end
	if phase == "day" and clock.Value > 24 then clock.Value = clock.Value - 24 end
	if phase == "day" and clock.Value > target then clock.Value = clock.Value - 24 end
	TweenService:Create(clock, info, { Value = target }):Play()
	TweenService:Create(Lighting, info, p.light):Play()
	TweenService:Create(atmo, info, p.atmo):Play()
	TweenService:Create(cc, info, p.cc):Play()
end

local function setupLighting()
	atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Parent = Lighting
	cc = Lighting:FindFirstChild("CN_Color") or Instance.new("ColorCorrectionEffect")
	cc.Name = "CN_Color"
	cc.Parent = Lighting
	bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 0.9
	bloom.Parent = Lighting
	clock.Changed:Connect(function(v) Lighting.ClockTime = v % 24 end)
	applyLighting(true)
	state:GetAttributeChangedSignal("Phase"):Connect(function() applyLighting(false) end)
	state:GetAttributeChangedSignal("Event"):Connect(function() applyLighting(false) end)
end

---------------------------------------------------------------- подсказки только для своих
local origDist = setmetatable({}, { __mode = "k" })

local function baseOf(inst)
	local a = inst.Parent
	while a and a ~= workspace do
		if a:IsA("Model") and a:GetAttribute("OwnerId") ~= nil then return a end
		a = a.Parent
	end
	return nil
end

local function filterPrompt(p)
	local mode = p:GetAttribute("For")
	if not mode then return end
	if origDist[p] == nil then origDist[p] = p.MaxActivationDistance end
	local me = player.UserId
	local show
	if mode == "notself" then
		show = p:GetAttribute("UserId") ~= me
	else
		local base = baseOf(p)
		local owner = base and base:GetAttribute("OwnerId") or 0
		if mode == "owner" then show = owner == me else show = owner ~= 0 and owner ~= me end
	end
	p.MaxActivationDistance = show and origDist[p] or 0
end

local function filterIn(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ProximityPrompt") then filterPrompt(d) end
	end
end

local function setupPrompts()
	filterIn(workspace)
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			task.defer(function() if d.Parent then filterPrompt(d) end end)
		end
	end)
	local bases = workspace:WaitForChild("Bases")
	local function hookBase(b)
		b:GetAttributeChangedSignal("OwnerId"):Connect(function() filterIn(b) end)
	end
	for _, b in ipairs(bases:GetChildren()) do hookBase(b) end
	bases.ChildAdded:Connect(hookBase)
end

---------------------------------------------------------------- своя база: дверь и метка
local hookedDoor = nil
local function myBase()
	local idx = player:GetAttribute("BaseIndex")
	local bases = workspace:FindFirstChild("Bases")
	return idx and bases and bases:FindFirstChild("Base_" .. idx) or nil
end

local function hookMyBase()
	local b = myBase()
	if not b then return end
	local door = b:FindFirstChild("Door")
	if door and door ~= hookedDoor then
		hookedDoor = door
		door.CanCollide = false
		door:GetPropertyChangedSignal("CanCollide"):Connect(function()
			if door.CanCollide then door.CanCollide = false end
		end)
	end
	filterIn(b)
end

---------------------------------------------------------------- монстры в клетках
local bobbing = {}
local function addBob(m)
	if not m:IsA("Model") then return end
	bobbing[m] = { cf = m:GetPivot(), phase = math.random() * 6, glitch = m:GetAttribute("Mutation") == "glitch" }
end

local function setupBob()
	for _, m in ipairs(CollectionService:GetTagged("CageMonster")) do addBob(m) end
	CollectionService:GetInstanceAddedSignal("CageMonster"):Connect(function(m)
		task.defer(function() if m.Parent then addBob(m) end end)
	end)
	CollectionService:GetInstanceRemovedSignal("CageMonster"):Connect(function(m) bobbing[m] = nil end)
	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local camPos = cam.CFrame.Position
		local t = os.clock()
		for m, b in pairs(bobbing) do
			local root = m.PrimaryPart
			if not m.Parent or not root then
				bobbing[m] = nil
			elseif (b.cf.Position - camPos).Magnitude < 160 then
				local y = math.sin(t * 2 + b.phase) * 0.3 + 0.3
				local cf = b.cf * CFrame.new(0, y, 0) * CFrame.Angles(0, math.sin(t * 0.8 + b.phase) * 0.3, 0)
				if b.glitch and math.random() < 0.1 then cf = cf * CFrame.new(math.random() * 0.8 - 0.4, 0, math.random() * 0.8 - 0.4) end
				root.CFrame = cf
			end
		end
	end)
end

---------------------------------------------------------------- метка базы и таймер замков
local function update()
	local b = myBase()
	local carrying = (player:GetAttribute("Carrying") or "") ~= ""
	if b then
		local hm = b.Top:FindFirstChild("HomeMarker")
		if hm then hm.Enabled = carrying end
	end
	local bases = workspace:FindFirstChild("Bases")
	if not bases then return end
	local t = workspace:GetServerTimeNow()
	for _, base in ipairs(bases:GetChildren()) do
		local door = base:FindFirstChild("Door")
		local g = door and door:FindFirstChild("LockGui")
		if g and base:GetAttribute("Locked") then
			g.Text.Text = "🔒 " .. Util.time((base:GetAttribute("LockEnds") or 0) - t)
		end
	end
end

function Visuals.init()
	setupLighting()
	setupPrompts()
	setupBob()
	hookMyBase()
	player:GetAttributeChangedSignal("BaseIndex"):Connect(hookMyBase)
	task.spawn(function()
		while true do
			local ok, err = pcall(update)
			if not ok then warn("[CN] Visuals: " .. tostring(err)) end
			task.wait(0.25)
		end
	end)
end

return Visuals
