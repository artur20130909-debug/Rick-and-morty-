-- Небо и свет: солнечный день, лёгкая дымка, облака, мягкое свечение неона.
-- Клиент (MapFx) потом плавно меняет дымку и оттенок под каждую зону.
local RS = game:GetService("ReplicatedStorage")
local D = require(RS.Shared.MapData)

local Sky = {}

local function make(class, parent, name, props)
	local o = parent:FindFirstChild(name) or Instance.new(class)
	o.Name = name
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

function Sky.setup()
	local L = game:GetService("Lighting")
	L.ClockTime = 14.2
	L.GeographicLatitude = 30
	L.Brightness = 2.6
	L.Ambient = Color3.fromRGB(90, 96, 110)
	L.OutdoorAmbient = Color3.fromRGB(135, 140, 150)
	L.EnvironmentDiffuseScale = 1
	L.EnvironmentSpecularScale = 0.6
	L.GlobalShadows = true
	L.ShadowSoftness = 0.3
	L.ExposureCompensation = 0.1
	local a = D.Ambience.Hub
	make("Atmosphere", L, "Atmosphere", { Density = a.density, Offset = 0.15, Color = a.color, Decay = a.decay,
		Glare = a.glare, Haze = a.haze })
	make("Sky", L, "Sky", { SunAngularSize = 14, MoonAngularSize = 9, StarCount = 3000 })
	make("BloomEffect", L, "Bloom", { Intensity = 0.7, Size = 28, Threshold = 1.6 })
	make("ColorCorrectionEffect", L, "ColorCorrection", { Saturation = a.saturation, Contrast = a.contrast,
		Brightness = a.brightness, TintColor = a.tint })
	make("SunRaysEffect", L, "SunRays", { Intensity = 0.06, Spread = 0.6 })
	make("Clouds", workspace.Terrain, "Clouds", { Cover = 0.55, Density = 0.6, Color = Color3.fromRGB(245, 250, 255) })
end

return Sky
