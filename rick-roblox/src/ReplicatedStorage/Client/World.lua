-- Свет и атмосфера (стиль «мульт + свет»): пресеты «ночь» (меню) и «утро» (игра),
-- цветокоррекция, свечение, лучи солнца из окон (Beam) с пылинками, включение ламп по комнатам.
-- Качество эффектов берётся из настроек (Effects 1..3).
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local World = {}
local Config, Settings, U
local house
local cc, bloom, rays, atmos, sky
local beamsFolder
local preset = nil

local PRESETS = {
	-- «цифровое измерение»: темно, насыщенно, сильное свечение неона
	pixel = {
		ClockTime = 0, Brightness = 0.3, Ambient = Color3.fromRGB(26, 16, 46), OutdoorAmbient = Color3.fromRGB(20, 12, 34),
		EnvironmentDiffuseScale = 0.2, EnvironmentSpecularScale = 0.1, ExposureCompensation = 0.35,
		cc = { Saturation = 0.35, Contrast = 0.22, Brightness = 0, TintColor = Color3.fromRGB(226, 210, 255) },
		bloom = { Intensity = 1.3, Size = 26, Threshold = 0.85 },
		rays = { Intensity = 0, Spread = 0.5 },
		atmos = { Density = 0.4, Offset = 0, Color = Color3.fromRGB(40, 24, 70), Decay = Color3.fromRGB(20, 10, 40), Glare = 0, Haze = 2.2 },
		lamps = {},
		beams = false,
	},
	night = {
		ClockTime = 0.3, Brightness = 1.2, Ambient = Color3.fromRGB(34, 38, 62), OutdoorAmbient = Color3.fromRGB(38, 44, 78),
		EnvironmentDiffuseScale = 0.35, EnvironmentSpecularScale = 0.2, ExposureCompensation = 0.25,
		cc = { Saturation = 0.16, Contrast = 0.14, Brightness = 0.01, TintColor = Color3.fromRGB(214, 224, 255) },
		bloom = { Intensity = 0.9, Size = 30, Threshold = 1.05 },
		rays = { Intensity = 0, Spread = 0.5 },
		atmos = { Density = 0.25, Offset = 0.1, Color = Color3.fromRGB(70, 82, 130), Decay = Color3.fromRGB(30, 34, 60), Glare = 0, Haze = 1.5 },
		lamps = { MortyNight = true },
		beams = false,
	},
	morning = {
		ClockTime = 7.45, Brightness = 3.1, Ambient = Color3.fromRGB(112, 112, 124), OutdoorAmbient = Color3.fromRGB(140, 138, 150),
		EnvironmentDiffuseScale = 0.55, EnvironmentSpecularScale = 0.25, ExposureCompensation = 0.12,
		cc = { Saturation = 0.2, Contrast = 0.07, Brightness = 0.02, TintColor = Color3.fromRGB(255, 247, 234) },
		bloom = { Intensity = 0.45, Size = 24, Threshold = 1.3 },
		rays = { Intensity = 0.045, Spread = 0.55 },
		atmos = { Density = 0.27, Offset = 0.12, Color = Color3.fromRGB(233, 216, 190), Decay = Color3.fromRGB(122, 146, 178), Glare = 0.45, Haze = 1.3 },
		lamps = { Kitchen = true },
		beams = true,
	},
}

local function ensure(class, name)
	local e = Lighting:FindFirstChild(name)
	if not e then
		e = Instance.new(class)
		e.Name = name
		e.Parent = Lighting
	end
	return e
end

function World.init(ctx)
	Config, Settings, U = ctx.Config, ctx.Settings, ctx.Util
	house = workspace:WaitForChild("House")
	cc = ensure("ColorCorrectionEffect", "RM_Color")
	bloom = ensure("BloomEffect", "RM_Bloom")
	rays = ensure("SunRaysEffect", "RM_Rays")
	atmos = ensure("Atmosphere", "RM_Atmosphere")
	sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Name = "RM_Sky"
		sky.SunAngularSize = 14
		sky.MoonAngularSize = 9
		sky.StarCount = 3000
		sky.Parent = Lighting
	end
	pcall(function() Lighting.Technology = Enum.Technology.Future end)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.22
	Lighting.GeographicLatitude = 30
	beamsFolder = Instance.new("Folder")
	beamsFolder.Name = "RM_SunBeams"
	beamsFolder.Parent = workspace
	Settings.Changed:Connect(function(k)
		if k == "Effects" and preset then World.apply(preset, 0) end
	end)
end

-- включить лампы комнат из списка (остальные выключить)
local function setLamps(list)
	local lights = house:FindFirstChild("Lights")
	if not lights then return end
	for _, lamp in ipairs(lights:GetChildren()) do
		local room = lamp:GetAttribute("Room")
		if room then
			local on = list[room] == true
			for _, l in ipairs(lamp:GetChildren()) do
				if l:IsA("Light") then l.Enabled = on end
			end
			if lamp:GetAttribute("Glow") then
				lamp.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
		end
	end
end

-- лучи солнца из окна: сетка ленточных лучей (FaceCamera) от стекла по направлению света
local anchor -- невидимая деталь в начале координат, к ней крепятся точки лучей
local function beamsFor(windowName)
	if not anchor then
		anchor = Instance.new("Part")
		anchor.Name = "RM_BeamAnchor"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.CFrame = CFrame.new()
		anchor.Parent = beamsFolder
	end
	local wins = house:FindFirstChild("Windows")
	local w = wins and wins:FindFirstChild(windowName)
	local glass = w and w:FindFirstChild("Glass")
	if not glass then return end
	local sun = Lighting:GetSunDirection()
	local dir = -sun
	if dir.Y > -0.05 then return end -- солнце слишком низко или за горизонтом
	-- свет должен идти внутрь дома: проверяем по нормали стекла
	local n = glass.CFrame.LookVector
	local outward = (glass.Position - Vector3.new(28, glass.Position.Y, 20)).Unit
	if n:Dot(outward) > 0 then n = -n end -- n — нормаль внутрь дома
	if dir:Dot(n) <= 0.05 then return end
	local floorY = glass.Position.Y > 10 and 12 or 0
	local size = glass.Size
	local q = Settings.get("Effects")
	local cols = q >= 3 and 4 or 2
	local rows = q >= 3 and 3 or 2
	for i = 1, cols do
		for j = 1, rows do
			local lx = (i - 0.5) / cols - 0.5
			local ly = (j - 0.5) / rows - 0.5
			local p = glass.CFrame * Vector3.new(lx * size.X * 0.9, ly * size.Y * 0.9, 0)
			local len = (p.Y - floorY) / -dir.Y
			len = math.min(len, 45)
			local a0 = Instance.new("Attachment")
			a0.Parent = anchor
			a0.WorldPosition = p + dir * 0.6
			local a1 = Instance.new("Attachment")
			a1.Parent = anchor
			a1.WorldPosition = p + dir * len
			local b = Instance.new("Beam")
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.FaceCamera = true
			b.Width0 = size.X / cols * 1.15
			b.Width1 = size.X / cols * 1.3
			b.Color = ColorSequence.new(Color3.fromRGB(255, 232, 186))
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Brightness = 1.4
			b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.86), NumberSequenceKeypoint.new(0.6, 0.93), NumberSequenceKeypoint.new(1, 1) })
			b.Segments = 1
			b.Parent = beamsFolder
			a0.Name = "RM_BeamA"
			a1.Name = "RM_BeamB"
		end
	end
	-- пылинки в луче
	if q >= 2 then
		local mid = glass.Position + dir * 6
		local dust = Instance.new("Part")
		dust.Name = "RM_Dust"
		dust.Anchored = true
		dust.CanCollide = false
		dust.CanQuery = false
		dust.CanTouch = false
		dust.Transparency = 1
		dust.Size = Vector3.new(size.X, size.Y, 10)
		dust.CFrame = CFrame.lookAt(mid, mid + dir)
		dust.Parent = beamsFolder
		local pe = Instance.new("ParticleEmitter")
		pe.Rate = 7
		pe.Lifetime = NumberRange.new(5, 9)
		pe.Speed = NumberRange.new(0.05, 0.25)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new(0.07)
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(0.7, 0.45), NumberSequenceKeypoint.new(1, 1) })
		pe.LightEmission = 1
		pe.LightInfluence = 0
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 240, 210))
		pe.Shape = Enum.ParticleEmitterShape.Box
		pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		pe.Parent = dust
	end
end

local function clearBeams()
	beamsFolder:ClearAllChildren()
	anchor = nil
end

-- применить пресет: name = "night" | "morning"; t — время перехода
function World.apply(name, t)
	preset = name
	local p = PRESETS[name]
	if not p then return end
	t = t or 0
	local q = Settings.get("Effects")
	local function to(obj, props)
		if t > 0 then
			TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props):Play()
		else
			for k, v in pairs(props) do obj[k] = v end
		end
	end
	Lighting.ClockTime = p.ClockTime
	-- утреннее солнце должно светить в окна на восточной стороне (+X); если в этой версии Roblox
	-- солнце в это время с другой стороны — берём зеркальное время дня (та же высота солнца)
	if p.beams and Lighting:GetSunDirection().X < 0 then Lighting.ClockTime = 24 - p.ClockTime end
	to(Lighting, { Brightness = p.Brightness, Ambient = p.Ambient, OutdoorAmbient = p.OutdoorAmbient,
		EnvironmentDiffuseScale = p.EnvironmentDiffuseScale, EnvironmentSpecularScale = p.EnvironmentSpecularScale,
		ExposureCompensation = p.ExposureCompensation })
	to(cc, p.cc)
	cc.Enabled = true
	bloom.Enabled = q >= 2
	to(bloom, p.bloom)
	rays.Enabled = q >= 3
	to(rays, p.rays)
	for k, v in pairs(p.atmos) do atmos[k] = v end
	if q <= 1 then atmos.Haze = 0 end
	Lighting.GlobalShadows = true
	setLamps(p.lamps)
	clearBeams()
	if p.beams and q >= 2 then
		beamsFor("MortyWindow")
		beamsFor("MortyWindow2")
		beamsFor("KitchenWindow")
	end
end

-- включить/выключить отдельную группу ламп (например, ночник)
function World.lamps(list) setLamps(list) end

local _u = U
return World
