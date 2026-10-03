-- Облик мира на клиенте (всё локально, другие игроки этого не видят):
--  * Lighting, небо (Sky), туман (Atmosphere), облака (Clouds) и пост-обработка по сцене и часам матча;
--  * лобби: глубокая ночь, холодная луна, густой низкий туман, звёзды, свечение прожекторов и билборда;
--  * дом: утро → полдень → золотой час → сумерки → ночь → рассвет; без электричества — темнее и бледнее;
--  * экстренное оповещение: мигающий красно-синий свет телевизора, виньетка, лёгкое размытие;
--  * дождь (частицы над камерой) и молнии, фоновые звуки; в доме меньше тумана, дождь не идёт;
--  * телевизор «КАНАЛ 6»: новости с бегущей строкой, погода, мультики, настроечная таблица, помехи, EAS;
--  * мелкая анимация: случайное мерцание ламп ночью, «дыхание» тумана в лобби.
-- Другие модули узнают отсюда сцену (World.scene/state/onScene) и меняют настроение (setMod, pulse).
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local World = {}

local ctx, player, Config, Sound, B, Net
local T = 0 -- внутренние часы модуля, секунды

---------------------------------------------------------------- помощники
local warned = {}
local function warnOnce(tag, err)
	if warned[tag] then return end
	warned[tag] = true
	warn("[AA] World." .. tostring(tag) .. ": " .. tostring(err))
end

local function guarded(tag, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then warnOnce(tag, err) end
	return ok
end

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end
local function smoothstep(t)
	t = clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function approach(a, b, d, rate) return a + (b - a) * (1 - math.exp(-rate * d)) end
local function scaleC(c, k) return Color3.new(clamp(c.R * k, 0, 1), clamp(c.G * k, 0, 1), clamp(c.B * k, 0, 1)) end
local function desat(c, k)
	local g = (c.R + c.G + c.B) / 3
	return c:Lerp(Color3.new(g, g, g), clamp(k, 0, 1))
end
local function mulC(a, b) return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B) end

-- выставить свойство, не падая, если его нет в этой версии движка
local badProp = {}
local function setp(obj, prop, v)
	if not obj then return end
	local key = tostring(obj.ClassName) .. "." .. prop
	if badProp[key] then return end
	local ok, err = pcall(function() obj[prop] = v end)
	if not ok then
		badProp[key] = true
		warnOnce(key, err)
	end
end

local function new(class, props, parent)
	local o = Instance.new(class)
	if props then
		for k, v in pairs(props) do o[k] = v end
	end
	if parent then o.Parent = parent end
	return o
end

-- папка для локальных деталей клиента (дождь и т. п.)
local function localFolder()
	local f = workspace:FindFirstChild("AA_Local")
	if not f then
		f = Instance.new("Folder")
		f.Name = "AA_Local"
		f.Parent = workspace
	end
	return f
end

local function getRoot()
	local c = player and player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

---------------------------------------------------------------- пресеты освещения
-- Все значения одного «кадра» освещения. Цвета — Color3, остальное — числа.
local DEF = {
	ClockTime = 12, Brightness = 2, Exposure = 0, Diffuse = 1, Specular = 1,
	Ambient = rgb(40, 40, 46), Outdoor = rgb(110, 110, 118), ShiftTop = rgb(0, 0, 0),
	AtmDensity = 0.3, AtmOffset = 0.1, AtmColor = rgb(199, 199, 199), AtmDecay = rgb(106, 112, 125), AtmGlare = 0, AtmHaze = 0,
	CcBright = 0, CcContrast = 0, CcSat = 0, CcTint = rgb(255, 255, 255),
	BloomInt = 0.6, BloomSize = 24, BloomThr = 1.6,
	RaysInt = 0.05, RaysSpread = 0.6,
	DofFar = 0.06, DofFocus = 40, DofRadius = 50, DofNear = 0,
	Blur = 0, CloudCover = 0.5, CloudDensity = 0.4, CloudColor = rgb(255, 255, 255),
	Stars = 0, Vignette = 0.1,
}
local function copy(t)
	local o = {}
	for k, v in pairs(t) do o[k] = v end
	return o
end
local function P(t)
	local o = copy(DEF)
	for k, v in pairs(t) do o[k] = v end
	return o
end

-- ClockTime по кругу: 23.8 → 0.2 идёт коротким путём
local function wrapLerp(a, b, t)
	local d = (b - a) % 24
	if d > 12 then d = d - 24 end
	return (a + d * t) % 24
end
local function mix(a, b, t)
	local o = {}
	for k, va in pairs(a) do
		local vb = b[k]
		if vb == nil then
			o[k] = va
		elseif k == "ClockTime" then
			o[k] = wrapLerp(va, vb, t)
		elseif typeof(va) == "Color3" then
			o[k] = va:Lerp(vb, t)
		else
			o[k] = va + (vb - va) * t
		end
	end
	return o
end

-- лобби: глубокая ночь у лечебницы, холодная луна, низкий густой туман, звёзды
local LOBBY = P({
	ClockTime = 0.3, Brightness = 1.6, Exposure = 0.15, Diffuse = 0.7, Specular = 0.8,
	Ambient = rgb(20, 22, 32), Outdoor = rgb(58, 70, 104), ShiftTop = rgb(40, 58, 110),
	AtmDensity = 0.42, AtmOffset = 0.12, AtmColor = rgb(96, 110, 142), AtmDecay = rgb(32, 40, 64), AtmGlare = 0, AtmHaze = 2.3,
	CcBright = 0.01, CcContrast = 0.16, CcSat = -0.32, CcTint = rgb(206, 220, 255),
	BloomInt = 1.0, BloomSize = 34, BloomThr = 1.1, RaysInt = 0.04, RaysSpread = 0.5,
	DofFar = 0.16, DofFocus = 45, DofRadius = 50,
	CloudCover = 0.62, CloudDensity = 0.35, CloudColor = rgb(44, 50, 66), Stars = 4000, Vignette = 0.22,
})

-- дом: опорные точки по игровым часам (7…31); между ними — плавное смешивание.
-- Небо Roblox садит солнце около 18:00, поэтому вечерние часы игры чуть «сжаты» в ClockTime,
-- чтобы золотой час (18–19) и сумерки (20–21) выглядели как надо.
local NIGHT = {
	ClockTime = 22.6, Brightness = 0.75, Exposure = -0.1, Diffuse = 0.55, Specular = 0.6,
	Ambient = rgb(11, 12, 19), Outdoor = rgb(34, 43, 72), ShiftTop = rgb(26, 38, 80),
	AtmDensity = 0.39, AtmOffset = 0.08, AtmColor = rgb(58, 68, 98), AtmDecay = rgb(24, 29, 46), AtmGlare = 0, AtmHaze = 2.0,
	CcBright = -0.01, CcContrast = 0.15, CcSat = -0.24, CcTint = rgb(198, 212, 255),
	BloomInt = 1.0, BloomSize = 30, BloomThr = 1.2, RaysInt = 0, DofFar = 0.12, DofFocus = 30, DofRadius = 45,
	CloudCover = 0.6, CloudDensity = 0.5, CloudColor = rgb(36, 42, 58), Stars = 3000, Vignette = 0.26,
}
local function nightAt(clockTime, bright, outdoor)
	local t = copy(NIGHT)
	t.ClockTime = clockTime
	t.Brightness = bright
	t.Outdoor = outdoor
	return P(t)
end
local HOUSE_KEYS = {
	{ 7, P({ -- утро
		ClockTime = 7.1, Brightness = 2.1, Exposure = 0.05,
		Ambient = rgb(54, 50, 56), Outdoor = rgb(122, 116, 124), ShiftTop = rgb(40, 24, 10),
		AtmDensity = 0.33, AtmOffset = 0.22, AtmColor = rgb(214, 204, 200), AtmDecay = rgb(150, 138, 150), AtmGlare = 0.3, AtmHaze = 1.4,
		CcBright = 0.01, CcContrast = 0.05, CcSat = -0.02, CcTint = rgb(255, 245, 236),
		BloomInt = 0.55, BloomSize = 26, BloomThr = 1.7, RaysInt = 0.11, RaysSpread = 0.7,
		DofFar = 0.05, CloudCover = 0.5, CloudDensity = 0.4, CloudColor = rgb(255, 238, 228), Vignette = 0.1,
	}) },
	{ 11, P({ -- полдень
		ClockTime = 12.4, Brightness = 3, Exposure = 0,
		Ambient = rgb(60, 60, 66), Outdoor = rgb(132, 132, 138), ShiftTop = rgb(10, 8, 4),
		AtmDensity = 0.27, AtmOffset = 0.06, AtmColor = rgb(200, 208, 220), AtmDecay = rgb(110, 128, 156), AtmGlare = 0, AtmHaze = 0.6,
		CcContrast = 0.07, CcSat = 0.05, CcTint = rgb(255, 252, 246),
		BloomInt = 0.45, BloomThr = 1.9, RaysInt = 0.05,
		DofFar = 0.04, CloudCover = 0.45, CloudDensity = 0.45, CloudColor = rgb(255, 255, 255), Vignette = 0.08,
	}) },
	{ 16, P({ -- после обеда
		ClockTime = 15.3, Brightness = 2.8, Exposure = 0,
		Ambient = rgb(62, 58, 60), Outdoor = rgb(138, 130, 126), ShiftTop = rgb(30, 18, 6),
		AtmDensity = 0.28, AtmOffset = 0.1, AtmColor = rgb(215, 205, 200), AtmDecay = rgb(140, 120, 110), AtmGlare = 0.2, AtmHaze = 0.9,
		CcContrast = 0.07, CcSat = 0.05, CcTint = rgb(255, 246, 232),
		BloomInt = 0.5, BloomThr = 1.8, RaysInt = 0.08,
		DofFar = 0.04, CloudCover = 0.48, CloudDensity = 0.45, CloudColor = rgb(255, 246, 236), Vignette = 0.08,
	}) },
	{ 18, P({ -- золотой час
		ClockTime = 16.9, Brightness = 2.5, Exposure = 0.05,
		Ambient = rgb(64, 52, 48), Outdoor = rgb(150, 118, 98), ShiftTop = rgb(110, 60, 20),
		AtmDensity = 0.31, AtmOffset = 0.25, AtmColor = rgb(255, 196, 150), AtmDecay = rgb(190, 118, 86), AtmGlare = 0.7, AtmHaze = 1.5,
		CcContrast = 0.09, CcSat = 0.1, CcTint = rgb(255, 226, 192),
		BloomInt = 0.75, BloomSize = 30, BloomThr = 1.5, RaysInt = 0.2, RaysSpread = 0.75,
		DofFar = 0.06, CloudCover = 0.5, CloudDensity = 0.45, CloudColor = rgb(255, 200, 160), Vignette = 0.1,
	}) },
	{ 19.3, P({ -- солнце у горизонта
		ClockTime = 17.5, Brightness = 2.0, Exposure = 0.05,
		Ambient = rgb(58, 46, 46), Outdoor = rgb(138, 98, 84), ShiftTop = rgb(120, 50, 20),
		AtmDensity = 0.32, AtmOffset = 0.28, AtmColor = rgb(240, 160, 120), AtmDecay = rgb(150, 80, 70), AtmGlare = 0.9, AtmHaze = 1.6,
		CcContrast = 0.09, CcSat = 0.06, CcTint = rgb(255, 212, 176),
		BloomInt = 0.8, BloomSize = 30, BloomThr = 1.45, RaysInt = 0.22, RaysSpread = 0.75,
		DofFar = 0.07, CloudCover = 0.5, CloudDensity = 0.45, CloudColor = rgb(240, 160, 130), Vignette = 0.12,
	}) },
	{ 20.2, P({ -- сумерки
		ClockTime = 17.95, Brightness = 1.35, Exposure = 0, Diffuse = 0.9, Specular = 0.9,
		Ambient = rgb(40, 34, 44), Outdoor = rgb(92, 74, 96), ShiftTop = rgb(60, 30, 40),
		AtmDensity = 0.34, AtmOffset = 0.3, AtmColor = rgb(170, 118, 132), AtmDecay = rgb(88, 58, 90), AtmGlare = 0.4, AtmHaze = 1.7,
		CcContrast = 0.1, CcSat = -0.05, CcTint = rgb(238, 206, 218),
		BloomInt = 0.85, BloomSize = 28, BloomThr = 1.4, RaysInt = 0.1,
		DofFar = 0.08, CloudCover = 0.52, CloudDensity = 0.45, CloudColor = rgb(170, 112, 128), Stars = 300, Vignette = 0.14,
	}) },
	{ 21, P({ -- поздние сумерки (оповещение)
		ClockTime = 18.5, Brightness = 0.9, Exposure = -0.05, Diffuse = 0.8, Specular = 0.8,
		Ambient = rgb(22, 22, 32), Outdoor = rgb(54, 58, 86), ShiftTop = rgb(20, 24, 50),
		AtmDensity = 0.36, AtmOffset = 0.18, AtmColor = rgb(92, 94, 128), AtmDecay = rgb(44, 44, 74), AtmGlare = 0, AtmHaze = 1.8,
		CcContrast = 0.12, CcSat = -0.14, CcTint = rgb(206, 212, 246),
		BloomInt = 0.95, BloomSize = 28, BloomThr = 1.3, RaysInt = 0.02,
		DofFar = 0.1, DofFocus = 34, DofRadius = 48, CloudCover = 0.55, CloudDensity = 0.48, CloudColor = rgb(78, 78, 108), Stars = 1500, Vignette = 0.2,
	}) },
	{ 22, P(NIGHT) },                                       -- ночь
	{ 26, nightAt(1.0, 0.85, rgb(36, 46, 78)) },           -- полночь: луна выше
	{ 29.6, nightAt(4.2, 0.7, rgb(32, 40, 66)) },          -- глубокая ночь
	{ 30.4, P({ -- предрассветный час
		ClockTime = 5.5, Brightness = 1.0, Exposure = -0.05, Diffuse = 0.7, Specular = 0.7,
		Ambient = rgb(26, 25, 34), Outdoor = rgb(76, 74, 100), ShiftTop = rgb(40, 30, 50),
		AtmDensity = 0.37, AtmOffset = 0.2, AtmColor = rgb(122, 110, 140), AtmDecay = rgb(92, 70, 100), AtmGlare = 0, AtmHaze = 1.7,
		CcContrast = 0.1, CcSat = -0.1, CcTint = rgb(226, 214, 240),
		BloomInt = 0.9, BloomThr = 1.4, RaysInt = 0.02,
		DofFar = 0.1, CloudCover = 0.55, CloudDensity = 0.45, CloudColor = rgb(150, 118, 140), Stars = 600, Vignette = 0.18,
	}) },
	{ 31, P({ -- рассвет
		ClockTime = 6.4, Brightness = 1.8, Exposure = 0.05, Diffuse = 0.95, Specular = 0.95,
		Ambient = rgb(46, 42, 50), Outdoor = rgb(122, 104, 114), ShiftTop = rgb(80, 40, 24),
		AtmDensity = 0.35, AtmOffset = 0.25, AtmColor = rgb(255, 190, 170), AtmDecay = rgb(170, 118, 128), AtmGlare = 0.5, AtmHaze = 1.6,
		CcContrast = 0.06, CcSat = 0, CcTint = rgb(255, 228, 214),
		BloomInt = 0.7, BloomThr = 1.5, RaysInt = 0.16,
		DofFar = 0.06, CloudCover = 0.5, CloudDensity = 0.42, CloudColor = rgb(255, 190, 170), Vignette = 0.12,
	}) },
}

local function housePreset(h)
	local first, last = HOUSE_KEYS[1], HOUSE_KEYS[#HOUSE_KEYS]
	if h <= first[1] then return copy(first[2]) end
	if h >= last[1] then return copy(last[2]) end
	for i = 1, #HOUSE_KEYS - 1 do
		local a, b = HOUSE_KEYS[i], HOUSE_KEYS[i + 1]
		if h <= b[1] then
			return mix(a[2], b[2], smoothstep((h - a[1]) / (b[1] - a[1])))
		end
	end
	return copy(last[2])
end

-- насколько сейчас «ночь» (0 — день, 1 — ночь) по игровым часам
local function nightOf(h)
	if h <= 20 then return 0 end
	if h < 22 then return smoothstep((h - 20) / 2) end
	if h <= 30 then return 1 end
	return 1 - smoothstep((h - 30) / 1)
end

---------------------------------------------------------------- состояние сцены
local S = {
	scene = "lobby", sceneT = -100, matchId = 0, match = nil, house = nil,
	phase = "", clock = 7, night = 1, power = true, alertData = nil,
}
local E = { indoor = 0, rain = 0, powerOff = 0, alert = 0, night = 0 } -- сглаженные факторы
local mods = {}      -- имя -> поправки настроения от других модулей
local pulses = {}    -- вспышки виньетки
local listeners = {} -- подписчики на смену сцены
local snapNext = true
local cur = nil      -- текущий (сглаженный) кадр освещения
local weather = { key = "", nightRain = false, dayRain = false, dayFrom = 0, dayTo = 0, tDay = 21, tNight = 9 }

local H = { rooms = {}, indoorRooms = {}, lights = {}, interior = nil } -- разметка дома

local function findHouse(id)
	local hs = workspace:FindFirstChild("Houses")
	return hs and hs:FindFirstChild("House_" .. tostring(id)) or nil
end

local function findMatch(id)
	if not id or id == 0 then return nil end
	local ms = RS:FindFirstChild("Matches")
	return ms and ms:FindFirstChild("Match_" .. tostring(id)) or nil
end

local function inside(part, pos)
	local ok, lp = pcall(function() return part.CFrame:PointToObjectSpace(pos) end)
	if not ok or not lp then return false end
	local s = part.Size
	return math.abs(lp.X) <= s.X / 2 and math.abs(lp.Y) <= s.Y / 2 and math.abs(lp.Z) <= s.Z / 2
end

local function scanHouse(h)
	H = { rooms = {}, indoorRooms = {}, lights = {}, interior = nil }
	if not h then return end
	local rf = h:FindFirstChild("Rooms")
	if rf then
		for _, r in ipairs(rf:GetChildren()) do
			if r:IsA("BasePart") then
				table.insert(H.rooms, r)
				if r:GetAttribute("Indoor") == true then table.insert(H.indoorRooms, r) end
			end
		end
	end
	local lf = h:FindFirstChild("Lights")
	if lf then
		for _, p in ipairs(lf:GetDescendants()) do
			if p:IsA("BasePart") then
				local l = p:FindFirstChildWhichIsA("Light")
				if l then table.insert(H.lights, { part = p, light = l }) end
			end
		end
	end
	local it = h:FindFirstChild("Interior", true)
	if it and it:IsA("BasePart") then H.interior = it end
end

---------------------------------------------------------------- объекты освещения
local L = {}
local function own(parent, class, name)
	local o = parent:FindFirstChild(name)
	if o and o.ClassName == class then return o end
	o = Instance.new(class)
	o.Name = name
	o.Parent = parent
	return o
end

local function setupLighting()
	-- небо и атмосфера бывают только в одном экземпляре — если уже есть, берём существующие
	L.sky = Lighting:FindFirstChildOfClass("Sky") or own(Lighting, "Sky", "AA_Sky")
	L.atm = Lighting:FindFirstChildOfClass("Atmosphere") or own(Lighting, "Atmosphere", "AA_Atmosphere")
	L.cc = own(Lighting, "ColorCorrectionEffect", "AA_Color")
	L.bloom = own(Lighting, "BloomEffect", "AA_Bloom")
	L.rays = own(Lighting, "SunRaysEffect", "AA_SunRays")
	L.dof = own(Lighting, "DepthOfFieldEffect", "AA_Focus")
	L.blur = own(Lighting, "BlurEffect", "AA_Blur")
	setp(L.blur, "Size", 0)
	setp(L.blur, "Enabled", false)
	setp(L.sky, "CelestialBodiesShown", true)
	setp(L.sky, "MoonAngularSize", 14)
	setp(L.sky, "SunAngularSize", 16)
	setp(Lighting, "GlobalShadows", true)
	-- стиль освещения задан в файле места; с клиента пробуем молча (обычно не разрешено)
	pcall(function() Lighting.LightingStyle = Enum.LightingStyle.Realistic end)
	-- облака живут в Terrain
	guarded("clouds", function()
		local terrain = workspace:FindFirstChildOfClass("Terrain")
		if not terrain then return end
		local c = terrain:FindFirstChildOfClass("Clouds")
		if not c then
			c = Instance.new("Clouds")
			c.Name = "AA_Clouds"
			c.Parent = terrain
		end
		L.clouds = c
	end)
end

local lastStars = -1
local function applyLighting(p)
	setp(Lighting, "ClockTime", p.ClockTime)
	setp(Lighting, "Brightness", p.Brightness)
	setp(Lighting, "ExposureCompensation", clamp(p.Exposure, -3, 3))
	setp(Lighting, "EnvironmentDiffuseScale", clamp(p.Diffuse, 0, 1))
	setp(Lighting, "EnvironmentSpecularScale", clamp(p.Specular, 0, 1))
	setp(Lighting, "Ambient", p.Ambient)
	setp(Lighting, "OutdoorAmbient", p.Outdoor)
	setp(Lighting, "ColorShift_Top", p.ShiftTop)
	local a = L.atm
	if a then
		setp(a, "Density", clamp(p.AtmDensity, 0, 1))
		setp(a, "Offset", clamp(p.AtmOffset, 0, 1))
		setp(a, "Color", p.AtmColor)
		setp(a, "Decay", p.AtmDecay)
		setp(a, "Glare", clamp(p.AtmGlare, 0, 10))
		setp(a, "Haze", clamp(p.AtmHaze, 0, 10))
	end
	if L.cc then
		setp(L.cc, "Brightness", clamp(p.CcBright, -1, 1))
		setp(L.cc, "Contrast", clamp(p.CcContrast, -1, 1))
		setp(L.cc, "Saturation", clamp(p.CcSat, -1, 1))
		setp(L.cc, "TintColor", p.CcTint)
	end
	if L.bloom then
		setp(L.bloom, "Intensity", clamp(p.BloomInt, 0, 3))
		setp(L.bloom, "Size", clamp(p.BloomSize, 0, 56))
		setp(L.bloom, "Threshold", clamp(p.BloomThr, 0.8, 4))
	end
	if L.rays then
		setp(L.rays, "Intensity", clamp(p.RaysInt, 0, 1))
		setp(L.rays, "Spread", clamp(p.RaysSpread, 0, 1))
	end
	if L.dof then
		setp(L.dof, "FarIntensity", clamp(p.DofFar, 0, 1))
		setp(L.dof, "FocusDistance", clamp(p.DofFocus, 0, 200))
		setp(L.dof, "InFocusRadius", clamp(p.DofRadius, 0, 50))
		setp(L.dof, "NearIntensity", clamp(p.DofNear, 0, 1))
	end
	if L.blur then
		local b = clamp(p.Blur, 0, 56)
		setp(L.blur, "Size", b)
		setp(L.blur, "Enabled", b > 0.05)
	end
	if L.clouds then
		setp(L.clouds, "Cover", clamp(p.CloudCover, 0, 1))
		setp(L.clouds, "Density", clamp(p.CloudDensity, 0, 1))
		setp(L.clouds, "Color", p.CloudColor)
	end
	-- звёзды пересчитываются дорого: меняем только заметными шагами
	local stars = math.floor(clamp(p.Stars, 0, 5000) / 250 + 0.5) * 250
	if stars ~= lastStars and L.sky then
		lastStars = stars
		setp(L.sky, "StarCount", stars)
	end
end

---------------------------------------------------------------- виньетка и зерно (экранный слой)
local VG = { s = -1, c = BLACK }
local function buildVignette()
	local pg = player:WaitForChild("PlayerGui", 30)
	if not pg then return end
	local g = new("ScreenGui", { Name = "AA_Vignette", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = -5 })
	setp(g, "ZIndexBehavior", Enum.ZIndexBehavior.Sibling)
	local function edge(pos, size, rot)
		local f = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = BLACK, Position = pos, Size = size, BackgroundTransparency = 0 }, g)
		local gr = new("UIGradient", { Rotation = rot }, f)
		return { f = f, g = gr }
	end
	VG.edges = {
		edge(UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.38), 90),
		edge(UDim2.fromScale(0, 0.62), UDim2.fromScale(1, 0.38), -90),
		edge(UDim2.fromScale(0, 0), UDim2.fromScale(0.32, 1), 0),
		edge(UDim2.fromScale(0.68, 0), UDim2.fromScale(0.32, 1), 180),
	}
	local vid = B.asset(Config.Images.Vignette)
	if vid ~= "" then
		VG.img = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = vid, ImageColor3 = BLACK, ImageTransparency = 1 }, g)
	end
	local gid = B.asset(Config.Images.Grain)
	if gid ~= "" then
		VG.grain = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 256, 1, 256), Image = gid, ImageTransparency = 1 }, g)
		setp(VG.grain, "ScaleType", Enum.ScaleType.Tile)
		setp(VG.grain, "TileSize", UDim2.fromOffset(256, 256))
	end
	g.Parent = pg
	VG.gui = g
end

local function updateVignette(base, grainAmount)
	-- вспышки (испуг, урон) поверх постоянной виньетки
	local ps, pc = 0, BLACK
	for i = #pulses, 1, -1 do
		local p = pulses[i]
		local age = T - p.t0
		if age >= p.d then
			table.remove(pulses, i)
		else
			local env = p.s * (1 - age / p.d) ^ 1.5
			if age < 0.06 then env = p.s * age / 0.06 end
			if env > ps then
				ps = env
				pc = p.c
			end
		end
	end
	local s = clamp(math.max(base, ps), 0, 0.95)
	local col = BLACK:Lerp(pc, clamp(ps * 1.2, 0, 0.85))
	if VG.edges and (math.abs(s - VG.s) > 0.004 or col ~= VG.c) then
		VG.s = s
		VG.c = col
		local seq = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - s),
			NumberSequenceKeypoint.new(0.5, 1 - s * 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		for _, e in ipairs(VG.edges) do
			e.g.Transparency = seq
			e.f.BackgroundColor3 = col
		end
		if VG.img then
			VG.img.ImageTransparency = 1 - s
			VG.img.ImageColor3 = col
		end
	end
	if VG.grain then
		VG.grain.ImageTransparency = 1 - grainAmount
		if grainAmount > 0 then
			VG.grain.Position = UDim2.fromOffset(-math.random(0, 255), -math.random(0, 255))
		end
	end
end

---------------------------------------------------------------- фоновые звуки
local loops = {}
local function loopFor(key)
	local e = loops[key]
	if e then return e end
	e = { v = 0 }
	local ok, s = pcall(Sound.loop, key, nil, { Volume = 0 })
	if ok and s then
		e.s = s
		if key == "Rain" or key == "Wind" or key == "Crickets" or key == "AmbientDay" then
			-- внутри дома звуки улицы глуше
			local okEq, eq = pcall(function()
				return new("EqualizerSoundEffect", { HighGain = 0, MidGain = 0, LowGain = 0, Priority = 0 }, s)
			end)
			if okEq then e.eq = eq end
		end
	end
	loops[key] = e
	return e
end
local LOOP_KEYS = { "AmbientLobby", "AmbientDay", "AmbientNight", "AmbientHouse", "Wind", "Crickets", "Rain" }

local function updateLoops(d, inHouse)
	local want = {}
	if S.scene == "lobby" or not inHouse then
		want.AmbientLobby = 0.5
		want.Wind = 0.32
	else
		local out = 1 - E.indoor
		local night = E.night
		local powerOn = 1 - E.powerOff
		want.AmbientDay = (1 - night) * (0.2 + 0.25 * out)
		want.AmbientNight = night * (0.3 + 0.12 * out)
		want.Crickets = night * (1 - E.rain * 0.6) * (0.1 + 0.4 * out)
		want.Wind = 0.06 + (0.22 * night + 0.18 * E.rain) * (0.35 + 0.65 * out)
		want.AmbientHouse = powerOn * E.indoor * 0.16
		want.Rain = E.rain * (0.18 + 0.4 * out)
		if S.phase == "alert" then
			for k, v in pairs(want) do want[k] = v * 0.35 end
		end
		if S.scene == "end" then
			for k, v in pairs(want) do want[k] = v * 0.5 end
		end
	end
	for _, key in ipairs(LOOP_KEYS) do
		local e = loopFor(key)
		e.v = approach(e.v, want[key] or 0, d, 1.2)
		if e.s then
			e.s.Volume = e.v
			if e.eq then
				e.eq.HighGain = -20 * E.indoor
				e.eq.MidGain = -6 * E.indoor
			end
		end
	end
end

---------------------------------------------------------------- дождь и молнии
local rain = { part = nil, em = nil }
local function buildRain()
	local p = new("Part", {
		Name = "AA_Rain", Size = Vector3.new(90, 1, 90), Anchored = true, CanCollide = false,
		Transparency = 1, CastShadow = false,
	})
	setp(p, "CanQuery", false)
	setp(p, "CanTouch", false)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Rain"
	local tex = B.asset(Config.Images.Rain)
	if tex == "" then tex = "rbxasset://textures/particles/sparkles_main.dds" end
	setp(e, "Texture", tex)
	setp(e, "EmissionDirection", Enum.NormalId.Bottom)
	setp(e, "Speed", NumberRange.new(62, 78))
	setp(e, "Lifetime", NumberRange.new(0.7, 0.85))
	setp(e, "Rate", 0)
	setp(e, "Size", NumberSequence.new(0.1))
	setp(e, "Squash", NumberSequence.new(2.6))
	setp(e, "Transparency", NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0.65) }))
	setp(e, "Color", ColorSequence.new(rgb(180, 196, 222)))
	setp(e, "LightInfluence", 0.8)
	setp(e, "LightEmission", 0.1)
	setp(e, "Orientation", Enum.ParticleOrientation.VelocityParallel)
	setp(e, "Acceleration", Vector3.new(3, 0, 1.5))
	setp(e, "SpreadAngle", Vector2.new(3, 3))
	setp(e, "LockedToPart", false)
	setp(e, "Enabled", false)
	e.Parent = p
	p.Parent = localFolder()
	rain.part = p
	rain.em = e
end

local function followRain(cam)
	if not rain.part then return end
	local cf = cam.CFrame
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then flat = flat.Unit * 16 end
	rain.part.CFrame = CFrame.new(cf.Position + flat + Vector3.new(0, 30, 0))
end

local function updateRainEmitter()
	if not rain.em then return end
	local r = E.rain * (1 - E.indoor)
	if r < 0.03 then
		if rain.em.Enabled then rain.em.Enabled = false end
		return
	end
	rain.em.Enabled = true
	rain.em.Rate = 520 * r
end

-- план погоды на ночь/день: одинаковый у всех игроков матча (зерно — номер матча и ночи)
local function planWeather()
	local key = tostring(S.matchId) .. ":" .. tostring(S.night)
	if weather.key == key then return end
	weather.key = key
	local rng = Random.new((S.matchId or 0) * 1009 + (S.night or 1) * 31 + 7)
	weather.nightRain = rng:NextNumber() < 0.75
	weather.dayRain = rng:NextNumber() < 0.3
	weather.dayFrom = rng:NextNumber(9, 15)
	weather.dayTo = weather.dayFrom + rng:NextNumber(1.5, 3.5)
	weather.tDay = rng:NextInteger(17, 26)
	weather.tNight = rng:NextInteger(5, 12)
end

local function rainTarget(inHouse, hour)
	if not inHouse then return 0 end
	local ph = S.phase
	if ph == "night" or ph == "alert" then return weather.nightRain and 1 or 0 end
	if ph == "dawn" then return weather.nightRain and 0.35 or 0 end
	if weather.dayRain and hour >= weather.dayFrom and hour <= weather.dayTo then return 0.7 end
	return 0
end

local lightning = { next = 20, t0 = -100 }
local function lightningFlash()
	local age = T - lightning.t0
	if age < 0.08 then return 1 end
	if age < 0.16 then return 0.15 end
	if age < 0.24 then return 0.8 end
	if age < 0.7 then return 0.3 * (0.7 - age) / 0.46 end
	return 0
end

---------------------------------------------------------------- электричество: щелчок и мерцание
local power = { t0 = -100, on = true, last = nil }
local function powerFlick()
	local age = T - power.t0
	if age > 1 then return 0 end
	if power.on then
		if age < 0.06 then return 0.5 end
		if age < 0.12 then return -1.2 end
		if age < 0.2 then return 0.35 end
		return 0
	end
	if age < 0.07 then return -2.4 end
	if age < 0.12 then return 0 end
	if age < 0.2 then return -2.0 end
	if age < 0.27 then return -0.3 end
	return -1.2 * (1 - (age - 0.27) / 0.73)
end

function World.powerFx(on)
	on = on and true or false
	if T - power.t0 < 1.5 and power.on == on then return end
	power.t0 = T
	power.on = on
	pcall(Sound.play, on and "PowerUp" or "PowerDown", nil, { Volume = 0.8 })
end

---------------------------------------------------------------- декоративное мерцание ламп
local flick = { next = 30, item = nil, t0 = 0, dur = 0, orig = 0 }
local function updateLampFlicker(camPos)
	if flick.item then
		local l = flick.item.light
		local age = T - flick.t0
		if age >= flick.dur or not l.Parent then
			pcall(function() l.Brightness = flick.orig end)
			flick.item = nil
		else
			l.Brightness = flick.orig * ((math.random() < 0.45) and 0.08 or (0.7 + math.random() * 0.3))
		end
		return
	end
	if T < flick.next then return end
	flick.next = T + 25 + math.random() * 30
	if E.night < 0.8 or not S.power or #H.lights == 0 then return end
	local near = {}
	for _, it in ipairs(H.lights) do
		if it.light.Parent and it.light.Enabled and (it.part.Position - camPos).Magnitude < 70 then
			table.insert(near, it)
		end
	end
	if #near == 0 then return end
	local it = near[math.random(1, #near)]
	flick.item = it
	flick.orig = it.light.Brightness
	flick.t0 = T
	flick.dur = 0.5 + math.random() * 0.8
end

local function stopLampFlicker()
	if flick.item then
		pcall(function() flick.item.light.Brightness = flick.orig end)
		flick.item = nil
	end
end

---------------------------------------------------------------- билборд лобби: отсвет экрана
local BB = { light = nil, tried = -100, tries = 0 }
local function setupBillboard()
	if BB.light and BB.light.Parent then return end
	local wait = (BB.tries < 5) and 3 or 15
	if T - BB.tried < wait then return end
	BB.tried = T
	BB.tries = BB.tries + 1
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then return end
	local best, bestScore = nil, 0
	for _, d in ipairs(lobby:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("ScreenFace") then
			local n = string.lower(d.Name)
			local s = d.Size
			local score = s.X * s.Y + s.Y * s.Z + s.X * s.Z
			if string.find(n, "billboard") then score = score + 1e6 end
			if n == "sign" or n == "tablet" then score = score * 0.01 end
			if score > bestScore then
				best = d
				bestScore = score
			end
		end
	end
	if not best then return end
	local face = Enum.NormalId.Front
	pcall(function() face = Enum.NormalId[best:GetAttribute("ScreenFace")] end)
	local l = new("SurfaceLight", { Name = "AA_BillboardGlow", Face = face, Range = 30, Angle = 80, Brightness = 1.4, Color = rgb(255, 178, 80), Shadows = false })
	l.Parent = best
	BB.light = l
end

local function updateBillboard()
	if not BB.light then return end
	local on = S.scene == "lobby"
	BB.light.Enabled = on
	if on then
		BB.light.Brightness = 1.25 + 0.2 * math.sin(T * 2.3) + (math.random() < 0.03 and -0.6 or 0)
	end
end

---------------------------------------------------------------- телевизор «КАНАЛ 6»
local FONT_B = Enum.Font.GothamBlack
local FONT = Enum.Font.GothamBold
local FONT_M = Enum.Font.RobotoMono
local CENTER = Enum.TextXAlignment.Center

local TICKER = "ЛЕЧЕБНИЦА BLACK RIDGE: РУКОВОДСТВО ЗАВЕРЯЕТ, ЧТО ВСЁ ПОД КОНТРОЛЕМ  •••  "
	.. "ЦЕНЫ НА ЯБЛОКИ ВЫРОСЛИ ВДВОЕ  •••  ПОЛИЦИЯ ПРОСИТ ЗАПИРАТЬ ДВЕРИ НА НОЧЬ  •••  "
	.. "ВЕЧЕРОМ ОЖИДАЕТСЯ ТУМАН  •••  ПРОПАВШИЙ ПОЧТАЛЬОН С УЛИЦЫ ВЯЗОВ ДО СИХ ПОР НЕ НАЙДЕН  •••  "
	.. "ЯРМАРКА УРОЖАЯ ПЕРЕНЕСЕНА НА СУББОТУ  •••  "
local HEADLINES = {
	"ГОРОДСКИЕ НОВОСТИ", "УРОЖАЙ ЯБЛОК — РЕКОРДНЫЙ", "BLACK RIDGE: ПРОВЕРКА ОХРАНЫ",
	"РЕМОНТ ШОССЕ №9 ПРОДЛЁН", "ЖИТЕЛИ ЖАЛУЮТСЯ НА ШУМ НОЧЬЮ", "ПОГОДА: НОЧЬЮ ТУМАН",
}

local TV = { part = nil, gui = nil, light = nil, att = nil, layers = {}, upd = {}, cur = "", untilT = 0, rot = 1, near = false, noSignal = false }

local function box(parent, x, y, w, h, color, props)
	local f = new("Frame", {
		BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color or BLACK,
	})
	if props then
		for k, v in pairs(props) do f[k] = v end
	end
	f.Parent = parent
	return f
end
local function txt(parent, x, y, w, h, text, color, size, font, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		Text = text, TextColor3 = color or WHITE, TextSize = size or 14, Font = font or FONT,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	if props then
		for k, v in pairs(props) do l[k] = v end
	end
	l.Parent = parent
	return l
end
local function corner(f, r)
	new("UICorner", { CornerRadius = UDim.new(r or 0.5, 0) }, f)
	return f
end
local function grad(f, c0, c1, rot)
	new("UIGradient", { Color = ColorSequence.new(c0, c1), Rotation = rot or 90 }, f)
	return f
end
local function textWidth(text, perChar)
	local n = utf8.len(text) or #text
	return n * perChar
end
local function clockText()
	local c = (S.clock or 7) % 24
	local h = math.floor(c)
	local m = math.floor((c - h) * 60)
	return string.format("%02d:%02d", h, m)
end

local function buildNews(root)
	local Lr = grad(box(root, 0, 0, 320, 240, WHITE, { Name = "News", Visible = false }), rgb(24, 52, 120), rgb(6, 14, 44), 90)
	-- задник: глобус с сеткой
	local globe = corner(box(Lr, 14, 30, 120, 120, rgb(60, 120, 210), { BackgroundTransparency = 0.45, ClipsDescendants = true }), 0.5)
	for i = 1, 3 do
		box(globe, 0, i * 30, 120, 1, WHITE, { BackgroundTransparency = 0.6 })
		box(globe, i * 30, 0, 1, 120, WHITE, { BackgroundTransparency = 0.6 })
	end
	-- ведущий за столом
	corner(box(Lr, 168, 106, 116, 96, rgb(36, 38, 56)), 0.3)
	box(Lr, 214, 106, 24, 48, rgb(232, 232, 236))
	box(Lr, 222, 110, 8, 40, rgb(176, 22, 32))
	local head = corner(box(Lr, 200, 50, 52, 60, rgb(226, 188, 158)), 0.5)
	corner(box(head, -3, -6, 58, 26, rgb(64, 42, 30)), 0.5)
	box(head, 14, 24, 6, 6, rgb(30, 30, 30))
	box(head, 32, 24, 6, 6, rgb(30, 30, 30))
	local mouth = box(head, 19, 42, 14, 3, rgb(120, 40, 40))
	box(Lr, 120, 168, 200, 14, rgb(82, 58, 44))
	-- логотип канала и часы
	local logo = box(Lr, 262, 8, 50, 40, rgb(200, 24, 24))
	txt(logo, 0, 1, 50, 10, "КАНАЛ", WHITE, 9, FONT, { TextXAlignment = CENTER })
	txt(logo, 0, 8, 50, 32, "6", WHITE, 30, FONT_B, { TextXAlignment = CENTER })
	local clock = txt(Lr, 10, 6, 120, 18, "07:00", WHITE, 15, FONT_M, { TextStrokeTransparency = 0.5 })
	-- плашка заголовка
	local bar = box(Lr, 0, 182, 320, 24, rgb(236, 236, 242))
	box(bar, 0, 0, 6, 24, rgb(200, 24, 24))
	local headline = txt(bar, 12, 0, 300, 24, HEADLINES[1], rgb(16, 18, 40), 15, FONT_B)
	-- бегущая строка
	local strip = box(Lr, 0, 208, 320, 32, rgb(168, 16, 24), { ClipsDescendants = true })
	local crawl = txt(strip, 320, 0, 3000, 32, TICKER, WHITE, 16, FONT_M)
	local tag = box(strip, 0, 0, 74, 32, rgb(255, 204, 40))
	txt(tag, 0, 0, 74, 32, "СРОЧНО", rgb(20, 16, 10), 15, FONT_B, { TextXAlignment = CENTER })
	local cw = textWidth(TICKER, 9.6)
	local x = 320
	TV.layers.news = Lr
	TV.upd.news = function(dt)
		x = x - 55 * dt
		if x < 74 - cw then x = 320 end
		crawl.Position = UDim2.fromOffset(math.floor(x), 0)
		clock.Text = clockText()
		headline.Text = HEADLINES[math.floor(T / 7) % #HEADLINES + 1]
		mouth.Size = UDim2.fromOffset(14, (math.floor(T * 7) % 3 == 0) and 6 or 3)
		head.Position = UDim2.fromOffset(200 + math.floor(math.sin(T * 0.9) * 2), 50 + math.floor(math.sin(T * 1.7)))
	end
end

local function buildWeather(root)
	local Lr = grad(box(root, 0, 0, 320, 240, WHITE, { Name = "Weather", Visible = false }), rgb(80, 150, 225), rgb(24, 70, 150), 90)
	txt(Lr, 12, 6, 200, 28, "ПОГОДА", WHITE, 24, FONT_B, { TextStrokeTransparency = 0.6 })
	local logo = box(Lr, 268, 8, 42, 30, rgb(200, 24, 24))
	txt(logo, 0, 0, 42, 30, "6", WHITE, 22, FONT_B, { TextXAlignment = CENTER })
	-- карта области
	local land = corner(box(Lr, 16, 48, 180, 132, rgb(86, 150, 78)), 0.3)
	corner(box(land, 90, 70, 100, 70, rgb(96, 160, 84)), 0.45)
	box(land, 20, 60, 150, 6, rgb(70, 140, 220), { Rotation = -18 })
	corner(box(land, 104, 46, 10, 10, WHITE), 0.5)
	txt(land, 116, 40, 80, 20, "ГОРОД", WHITE, 12, FONT, { TextStrokeTransparency = 0.5 })
	-- солнце
	local rays = box(Lr, 40, 60, 44, 44, rgb(255, 196, 40), { BackgroundTransparency = 0.25 })
	local sun = corner(box(Lr, 46, 66, 32, 32, rgb(255, 222, 60)), 0.5)
	-- облако с каплями
	local cloud = box(Lr, 110, 70, 70, 36, WHITE, { BackgroundTransparency = 1 })
	corner(box(cloud, 0, 14, 70, 22, rgb(236, 240, 246)), 0.5)
	corner(box(cloud, 12, 2, 30, 30, rgb(236, 240, 246)), 0.5)
	corner(box(cloud, 32, 0, 30, 30, rgb(244, 246, 250)), 0.5)
	local drops = {}
	for i = 1, 5 do drops[i] = box(cloud, 4 + i * 11, 36, 3, 9, rgb(120, 180, 255)) end
	-- прогноз
	local panel = box(Lr, 206, 48, 104, 132, rgb(10, 28, 70), { BackgroundTransparency = 0.3 })
	txt(panel, 8, 4, 96, 16, "СЕГОДНЯ", rgb(200, 220, 255), 12, FONT)
	local tDay = txt(panel, 8, 18, 96, 30, "+21°", WHITE, 26, FONT_B)
	txt(panel, 8, 54, 96, 16, "НОЧЬЮ", rgb(200, 220, 255), 12, FONT)
	local tNight = txt(panel, 8, 68, 96, 30, "+9°", WHITE, 26, FONT_B)
	local tKind = txt(panel, 8, 104, 96, 20, "ЯСНО", rgb(255, 230, 120), 12, FONT_B)
	local strip = box(Lr, 0, 196, 320, 44, rgb(10, 20, 50))
	local note = txt(strip, 10, 0, 300, 44, "", WHITE, 12, FONT, { TextWrapped = true })
	TV.layers.weather = Lr
	TV.upd.weather = function()
		rays.Rotation = (T * 25) % 360
		sun.Position = UDim2.fromOffset(46, 66 + math.floor(math.sin(T * 1.5) * 2))
		cloud.Position = UDim2.fromOffset(110 + math.floor(math.sin(T * 0.35) * 26), 70)
		local wet = weather.nightRain
		for i, dr in ipairs(drops) do
			dr.Visible = wet
			dr.Position = UDim2.fromOffset(4 + i * 11, 36 + math.floor((T * 40 + i * 7) % 20))
		end
		tKind.Text = wet and "НОЧЬЮ ДОЖДЬ" or "ЯСНО"
		note.Text = wet and "Вечером с запада придут дождь и туман. Закройте окна на ночь."
			or "Ночь будет ясной и прохладной. В низинах туман."
		tDay.Text = "+" .. tostring(weather.tDay) .. "°"
		tNight.Text = "+" .. tostring(weather.tNight) .. "°"
	end
end

local function buildCartoon(root)
	local Lr = box(root, 0, 0, 320, 240, rgb(120, 200, 255), { Name = "Cartoon", Visible = false, ClipsDescendants = true })
	local srays = box(Lr, 248, 14, 52, 52, rgb(255, 236, 120), { BackgroundTransparency = 0.3 })
	corner(box(Lr, 254, 20, 40, 40, rgb(255, 214, 60)), 0.5)
	corner(box(Lr, -70, 150, 240, 170, rgb(96, 196, 90)), 0.5)
	corner(box(Lr, 140, 162, 280, 170, rgb(72, 176, 84)), 0.5)
	box(Lr, 0, 200, 320, 40, rgb(70, 160, 70))
	local cl = box(Lr, 30, 34, 60, 26, WHITE, { BackgroundTransparency = 1 })
	corner(box(cl, 0, 8, 60, 18, WHITE), 0.5)
	corner(box(cl, 14, 0, 26, 24, WHITE), 0.5)
	-- герой: жёлтый колобок
	local hero = corner(box(Lr, 0, 0, 40, 40, rgb(255, 216, 58)), 0.5)
	box(hero, 10, 10, 6, 9, BLACK)
	box(hero, 24, 10, 6, 9, BLACK)
	corner(box(hero, 12, 26, 16, 6, rgb(170, 40, 40)), 0.5)
	-- рыжий кот гонится за ним
	local cat = corner(box(Lr, 0, 0, 34, 30, rgb(232, 110, 60)), 0.35)
	box(cat, 2, -6, 10, 10, rgb(232, 110, 60), { Rotation = 45 })
	box(cat, 22, -6, 10, 10, rgb(232, 110, 60), { Rotation = 45 })
	box(cat, 8, 9, 5, 7, BLACK)
	box(cat, 21, 9, 5, 7, BLACK)
	txt(Lr, 10, 4, 220, 34, "МУЛЬТИКИ", WHITE, 26, FONT_B, { TextStrokeTransparency = 0, TextStrokeColor3 = rgb(200, 40, 120) })
	TV.layers.cartoon = Lr
	TV.upd.cartoon = function()
		srays.Rotation = (T * 40) % 360
		cl.Position = UDim2.fromOffset(math.floor((T * 12) % 400) - 60, 34)
		local hx = (T * 70) % 420 - 50
		hero.Position = UDim2.fromOffset(math.floor(hx), math.floor(156 - math.abs(math.sin(T * 5)) * 46))
		hero.Rotation = (T * 200) % 360
		cat.Position = UDim2.fromOffset(math.floor(hx - 80 + math.sin(T * 3) * 8), math.floor(168 - math.abs(math.sin(T * 7 + 1)) * 18))
	end
end

local function buildBars(root)
	local Lr = box(root, 0, 0, 320, 240, BLACK, { Name = "Bars", Visible = false })
	local cols = { rgb(192, 192, 192), rgb(192, 192, 0), rgb(0, 192, 192), rgb(0, 192, 0), rgb(192, 0, 192), rgb(192, 0, 0), rgb(0, 0, 192) }
	for i, c in ipairs(cols) do box(Lr, (i - 1) * 46, 0, 46, 160, c) end
	local rev = { rgb(0, 0, 192), BLACK, rgb(192, 0, 192), BLACK, rgb(0, 192, 192), BLACK, rgb(192, 192, 192) }
	for i, c in ipairs(rev) do box(Lr, (i - 1) * 46, 160, 46, 20, c) end
	box(Lr, 0, 180, 320, 60, rgb(14, 14, 18))
	local clock = txt(Lr, 12, 186, 300, 22, "КАНАЛ 6 · 07:00", WHITE, 18, FONT_M)
	txt(Lr, 12, 210, 300, 20, "УТРЕННИЙ ЭФИР НАЧНЁТСЯ ЧЕРЕЗ НЕСКОЛЬКО МИНУТ", rgb(200, 200, 200), 10, FONT)
	local circ = corner(box(Lr, 120, 40, 80, 80, BLACK, { BackgroundTransparency = 0.45 }), 0.5)
	txt(circ, 0, 0, 80, 80, "6", WHITE, 54, FONT_B, { TextXAlignment = CENTER })
	TV.layers.bars = Lr
	TV.upd.bars = function()
		clock.Text = "КАНАЛ 6 · " .. clockText()
	end
end

local function buildStatic(root)
	local Lr = box(root, 0, 0, 320, 240, rgb(26, 26, 28), { Name = "Static", Visible = false, ClipsDescendants = true })
	local img = nil
	local sid = B.asset(Config.Images.TvStatic)
	if sid ~= "" then
		img = new("ImageLabel", { BackgroundTransparency = 1, Image = sid, Size = UDim2.fromOffset(448, 336) }, Lr)
		setp(img, "ScaleType", Enum.ScaleType.Tile)
		setp(img, "TileSize", UDim2.fromOffset(128, 96))
	end
	local bars, dots = {}, {}
	for i = 1, 16 do bars[i] = box(Lr, 0, 0, 320, 4, WHITE, { BackgroundTransparency = 0.8 }) end
	for i = 1, 60 do dots[i] = box(Lr, 0, 0, 3, 2, WHITE) end
	local msg = txt(Lr, 0, 96, 320, 48, "НЕТ СИГНАЛА", WHITE, 28, FONT_B, { TextXAlignment = CENTER, TextStrokeTransparency = 0.3, Visible = false })
	TV.layers.static = Lr
	TV.upd.static = function()
		local g0 = 0.08 + math.random() * 0.1
		Lr.BackgroundColor3 = Color3.new(g0, g0, g0)
		if img then img.Position = UDim2.fromOffset(-math.random(0, 127), -math.random(0, 95)) end
		for _, b in ipairs(bars) do
			local g = math.random()
			b.BackgroundColor3 = Color3.new(g, g, g)
			b.BackgroundTransparency = 0.35 + math.random() * 0.6
			b.Position = UDim2.fromOffset(0, math.random(0, 236))
			b.Size = UDim2.fromOffset(320, math.random(1, 9))
		end
		for _, dt in ipairs(dots) do
			local g = 0.5 + math.random() * 0.5
			dt.BackgroundColor3 = Color3.new(g, g, g)
			dt.Position = UDim2.fromOffset(math.random(0, 318), math.random(0, 238))
		end
		msg.Visible = TV.noSignal
		msg.TextTransparency = (math.floor(T * 2) % 2 == 0) and 0 or 0.4
	end
end

local function easCrawlText(d)
	local parts = {}
	local lines = d.lines or {}
	if lines[1] ~= Config.AlertHead then table.insert(parts, Config.AlertHead) end
	for _, l in ipairs(lines) do table.insert(parts, tostring(l)) end
	if d.tip then table.insert(parts, tostring(d.tip)) end
	local s = table.concat(parts, "   •••   ")
	if #s > 1400 then s = string.sub(s, 1, 1400) end
	return s
end

local function buildEas(root)
	local Lr = box(root, 0, 0, 320, 240, rgb(6, 6, 10), { Name = "Eas", Visible = false })
	local top = box(Lr, 0, 0, 320, 40, rgb(200, 0, 0))
	txt(top, 0, 2, 320, 24, "ЭКСТРЕННОЕ ОПОВЕЩЕНИЕ", WHITE, 20, FONT_B, { TextXAlignment = CENTER })
	txt(top, 0, 24, 320, 14, "СИСТЕМА ОПОВЕЩЕНИЯ НАСЕЛЕНИЯ", rgb(255, 210, 210), 10, FONT, { TextXAlignment = CENTER })
	-- предупреждающая лента
	local stripe = box(Lr, 0, 40, 320, 10, rgb(255, 200, 0), { ClipsDescendants = true })
	for i = 0, 20 do box(stripe, i * 18 - 10, -6, 8, 24, BLACK, { Rotation = 35 }) end
	local bigX = 12
	local logo = B.asset(Config.Images.EasLogo)
	if logo ~= "" then
		new("ImageLabel", { BackgroundTransparency = 1, Image = logo, Position = UDim2.fromOffset(10, 66), Size = UDim2.fromOffset(64, 64) }, Lr)
		bigX = 84
	end
	local big = txt(Lr, bigX, 58, 320 - bigX - 12, 90, "", WHITE, 22, FONT_B, {
		TextWrapped = true, TextXAlignment = CENTER, TextYAlignment = Enum.TextYAlignment.Center,
	})
	local sub = txt(Lr, 12, 150, 296, 46, "", rgb(255, 220, 120), 12, FONT, { TextWrapped = true, TextXAlignment = CENTER })
	local strip = box(Lr, 0, 200, 320, 40, BLACK, { ClipsDescendants = true })
	box(strip, 0, 0, 320, 2, rgb(200, 0, 0))
	local crawl = txt(strip, 320, 2, 16000, 38, "", WHITE, 18, FONT_M)
	local x, cw, last = 320, 0, nil
	TV.layers.eas = Lr
	TV.upd.eas = function(dt)
		local d = S.alertData or {}
		local text = easCrawlText(d)
		if text ~= last then
			last = text
			crawl.Text = text
			cw = textWidth(text, 10.8)
			x = 320
		end
		x = x - 70 * dt
		if x < -cw then x = 320 end
		crawl.Position = UDim2.fromOffset(math.floor(x), 2)
		top.BackgroundColor3 = (math.floor(T * 2.2) % 2 == 0) and rgb(210, 0, 0) or rgb(110, 0, 0)
		if d.unknown then
			big.Text = "ЗАКЛЮЧЁННЫЙ №???\nСИГНАЛ ПОВРЕЖДЁН"
		else
			big.Text = "ЗАКЛЮЧЁННЫЙ №" .. tostring(d.num or "???") .. "\n«" .. tostring(d.name or "НЕИЗВЕСТНО") .. "»"
		end
		local dir = d.directive
		sub.Text = (type(dir) == "table" and dir.text) or (d.tip and tostring(d.tip)) or "ОСТАВАЙТЕСЬ В ПОМЕЩЕНИИ"
	end
end

local function buildStandby(root)
	local Lr = grad(box(root, 0, 0, 320, 240, WHITE, { Name = "Standby", Visible = false }), rgb(64, 0, 0), rgb(8, 0, 0), 90)
	txt(Lr, 0, 14, 320, 20, "ЭКСТРЕННОЕ ОПОВЕЩЕНИЕ ДЕЙСТВУЕТ", rgb(255, 180, 180), 13, FONT_B, { TextXAlignment = CENTER })
	local big = txt(Lr, 0, 64, 320, 90, "ОСТАВАЙТЕСЬ\nВ УКРЫТИИ", WHITE, 30, FONT_B, { TextXAlignment = CENTER, TextWrapped = true })
	txt(Lr, 0, 166, 320, 20, "ЗАПРИТЕ ДВЕРИ · ВЫКЛЮЧИТЕ СВЕТ", rgb(255, 210, 120), 13, FONT, { TextXAlignment = CENTER })
	local num = txt(Lr, 0, 196, 320, 30, "", rgb(255, 90, 90), 15, FONT_M, { TextXAlignment = CENTER })
	TV.layers.standby = Lr
	TV.upd.standby = function()
		big.TextTransparency = (math.floor(T * 1.5) % 2 == 0) and 0 or 0.6
		local d = S.alertData
		if d then
			num.Text = d.unknown and "ЗАКЛЮЧЁННЫЙ №???" or ("ЗАКЛЮЧЁННЫЙ №" .. tostring(d.num or "???"))
		else
			num.Text = ""
		end
	end
end

local function buildOverlay(root)
	-- кинескоп: строки развёртки, затемнение по краям, блик стекла
	local O = box(root, 0, 0, 320, 240, BLACK, { Name = "Overlay", BackgroundTransparency = 1, ZIndex = 50 })
	for i = 0, 59 do box(O, 0, i * 4, 320, 1, BLACK, { BackgroundTransparency = 0.8, ZIndex = 50 }) end
	local function edge(x, y, w, h, rot)
		local f = box(O, x, y, w, h, BLACK, { ZIndex = 51 })
		new("UIGradient", { Rotation = rot, Transparency = NumberSequence.new(0.35, 1) }, f)
	end
	edge(0, 0, 320, 40, 90)
	edge(0, 200, 320, 40, -90)
	edge(0, 0, 48, 240, 0)
	edge(272, 0, 48, 240, 180)
	local glare = box(O, 0, 0, 320, 240, WHITE, { ZIndex = 52 })
	new("UIGradient", { Rotation = 35, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.86), NumberSequenceKeypoint.new(0.35, 0.97), NumberSequenceKeypoint.new(1, 1),
	}) }, glare)
	TV.overlay = O
end

local TV_LIGHT = {
	news = rgb(120, 160, 255), weather = rgb(110, 170, 255), cartoon = rgb(255, 226, 140),
	bars = rgb(220, 220, 255), static = rgb(200, 205, 220), standby = rgb(255, 40, 40),
}

local function unmountTV()
	if TV.gui then pcall(function() TV.gui:Destroy() end) end
	if TV.att then pcall(function() TV.att:Destroy() end) end
	if TV.news then pcall(function() TV.news:Destroy() end) end
	TV = { part = nil, gui = nil, light = nil, att = nil, layers = {}, upd = {}, cur = "", untilT = 0, rot = 1, near = false, noSignal = false }
end

local function mountTV(screen, tvModel)
	unmountTV()
	local faceName = screen:GetAttribute("ScreenFace") or (tvModel and tvModel:GetAttribute("ScreenFace")) or "Front"
	local face = Enum.NormalId.Front
	pcall(function() face = Enum.NormalId[faceName] end)
	local g = new("SurfaceGui", { Name = "AA_TV", Face = face })
	setp(g, "SizingMode", Enum.SurfaceGuiSizingMode.FixedSize)
	setp(g, "CanvasSize", Vector2.new(320, 240))
	setp(g, "LightInfluence", 0)
	setp(g, "Brightness", 1.4)
	setp(g, "ClipsDescendants", true)
	setp(g, "ZIndexBehavior", Enum.ZIndexBehavior.Sibling)
	local root = box(g, 0, 0, 320, 240, BLACK, { Name = "Root", ClipsDescendants = true })
	TV.root = root
	buildNews(root)
	buildWeather(root)
	buildCartoon(root)
	buildBars(root)
	buildStatic(root)
	buildEas(root)
	buildStandby(root)
	buildOverlay(root)
	g.Parent = screen
	TV.gui = g
	TV.part = screen
	-- свет экрана: точка чуть перед стеклом, чтобы корпус не загораживал
	local n = Vector3.new(0, 0, -1)
	pcall(function() n = Vector3.FromNormalId(face) end)
	local s = screen.Size
	local half = math.abs(n.X) * s.X / 2 + math.abs(n.Y) * s.Y / 2 + math.abs(n.Z) * s.Z / 2
	TV.faceOffset = n * half
	local att = new("Attachment", { Name = "AA_TVGlow", Position = n * (half + 0.9) })
	att.Parent = screen
	local pl = new("PointLight", { Name = "AA_TVLight", Range = 12, Brightness = 0, Color = TV_LIGHT.news, Shadows = true })
	pl.Parent = att
	TV.att = att
	TV.light = pl
	local okS, snd = pcall(Sound.loop, "TvNews", screen, { Volume = 0, RollOffMinDistance = 6, RollOffMaxDistance = 45 })
	if okS then TV.news = snd end
end

local function tvSet(name)
	if TV.cur == name then return end
	TV.cur = name
	for k, Lr in pairs(TV.layers) do Lr.Visible = (k == name) end
	if TV.gui then TV.gui.Enabled = (name ~= "off") end
	if name == "static" and TV.part and TV.near then
		pcall(Sound.play, "Static", TV.part, { Volume = 0.16, RollOffMaxDistance = 40 })
	end
	if name ~= "static" then TV.noSignal = false end
end

-- обязательная передача по фазе матча (nil — обычное дневное вещание)
local function tvForced()
	if not S.power then return "off" end
	if S.phase == "alert" then return "eas" end
	if S.phase == "night" then return "standby" end
	return nil
end

local ROTATION = { { "news", 26 }, { "weather", 14 }, { "cartoon", 22 }, { "news", 20 }, { "cartoon", 16 }, { "weather", 12 } }
local function nextProgramme()
	local forced = tvForced()
	if forced then return forced, (forced == "standby") and 8 or 9999 end
	local h = (S.clock or 7) % 24
	if h < 8.5 and not TV.barsShown then
		TV.barsShown = true
		return "bars", 9
	end
	if h >= 19.5 then return "news", 30 end
	local e = ROTATION[TV.rot]
	TV.rot = TV.rot % #ROTATION + 1
	return e[1], e[2]
end

local function tvSchedule()
	local forced = tvForced()
	if forced == "off" then
		tvSet("off")
		return
	end
	if TV.cur == "off" then
		tvSet("static")
		TV.untilT = T + 0.8
		return
	end
	-- смена обязательной передачи — через помехи
	if forced and TV.cur ~= forced and TV.cur ~= "static" then
		tvSet("static")
		TV.untilT = T + 0.7
		return
	end
	if not forced and (TV.cur == "eas" or TV.cur == "standby") then
		tvSet("static")
		TV.untilT = T + 0.9
		return
	end
	if T < TV.untilT then return end
	if forced == "standby" and TV.cur == "standby" then
		tvSet("static")
		TV.noSignal = true
		TV.untilT = T + 2.5
		return
	end
	if TV.cur == "static" then
		local name, dur = nextProgramme()
		tvSet(name)
		TV.untilT = T + dur
	else
		tvSet("static")
		TV.untilT = T + 0.5 + math.random() * 0.7
	end
end

local function updateTvLight()
	local l = TV.light
	if not l then return end
	local name = TV.cur
	if name == "off" or name == "" then
		l.Enabled = false
		return
	end
	l.Enabled = true
	if name == "eas" then
		-- оповещение: красный и синий по очереди, с мерцанием кинескопа
		local red = math.floor(T / 0.45) % 2 == 0
		l.Color = red and rgb(255, 30, 30) or rgb(40, 80, 255)
		l.Range = 22
		l.Brightness = 2.2 + math.random() * 1.3
		return
	end
	l.Color = TV_LIGHT[name] or TV_LIGHT.news
	l.Range = 12 + 6 * E.night
	local base = 0.45 + 0.9 * E.night
	if name == "standby" then
		l.Brightness = base * (0.55 + 0.35 * math.sin(T * 3))
	elseif name == "static" then
		l.Brightness = base * (0.5 + math.random() * 0.7)
	else
		l.Brightness = base * (0.85 + math.random() * 0.3)
	end
end

local function tvTick(dt, camPos)
	if not TV.part or not TV.part.Parent then return end
	TV.near = (TV.part.Position - camPos).Magnitude < 90
	tvSchedule()
	updateTvLight()
	if TV.news then
		local want = 0
		if (TV.cur == "news" or TV.cur == "weather") and TV.near then want = 0.32 end
		TV.news.Volume = approach(TV.news.Volume, want, dt, 4)
	end
	if not TV.near then return end
	local f = TV.upd[TV.cur]
	if f then f(dt) end
	-- редкое «подёргивание» кадра, как у старого кинескопа
	if TV.root then
		local j = (math.random() < 0.04) and math.random(-3, 3) or 0
		TV.root.Position = UDim2.fromOffset(0, j)
	end
end

local function findTV(house)
	local tvm = house:FindFirstChild("TV", true)
	if not (tvm and tvm:FindFirstChild("Screen", true)) then
		tvm = nil
		for _, d in ipairs(house:GetDescendants()) do
			if d:GetAttribute("Kind") == "TV" then
				tvm = d
				break
			end
		end
	end
	if not tvm then return nil, nil end
	local screen = tvm:FindFirstChild("Screen", true)
	if screen and screen:IsA("BasePart") then return screen, tvm end
	return nil, nil
end

---------------------------------------------------------------- сцена
local function setHouse(h)
	if S.house == h then return end
	S.house = h
	stopLampFlicker()
	unmountTV()
	scanHouse(h)
	if not h then return end
	-- дом мог догрузиться не полностью: несколько попыток найти телевизор и комнаты
	task.spawn(function()
		for _ = 1, 30 do
			if S.house ~= h then return end
			if #H.rooms == 0 or #H.lights == 0 then guarded("scanHouse", scanHouse, h) end
			if not TV.part then
				local ok, screen, tvm = pcall(findTV, h)
				if ok and screen then guarded("mountTV", mountTV, screen, tvm) end
			end
			if TV.part and #H.rooms > 0 then return end
			task.wait(0.5)
		end
	end)
end

local function fireScene(scene, data, prev)
	for _, fn in ipairs(listeners) do
		local ok, err = pcall(fn, scene, data, prev)
		if not ok then warnOnce("onScene", err) end
	end
end

local function setScene(scene, data)
	data = data or {}
	local prev = S.scene
	S.sceneT = T
	if scene == "house" then
		local id = data.matchId or player:GetAttribute("MatchId") or S.matchId or 0
		S.matchId = id
		S.match = findMatch(id)
		local h = data.house
		if typeof(h) ~= "Instance" then h = findHouse(id) end
		if h then
			setHouse(h)
		else
			-- модель дома ещё не пришла — подождём её
			task.spawn(function()
				for _ = 1, 40 do
					task.wait(0.5)
					if S.scene ~= "house" or S.matchId ~= id then return end
					local hh = findHouse(id)
					if hh then
						setHouse(hh)
						return
					end
				end
			end)
		end
	elseif scene == "lobby" then
		S.matchId = 0
		S.match = nil
		S.alertData = nil
		S.phase = ""
		S.power = true
		setHouse(nil)
	elseif scene == "loading" then
		S.matchId = data.matchId or player:GetAttribute("MatchId") or S.matchId
		S.match = findMatch(S.matchId)
	end
	S.scene = scene
	S.sceneData = data
	if prev ~= scene and (scene == "house" or scene == "lobby") then snapNext = true end
	fireScene(scene, data, prev)
end

-- страховка: если событие Scene потерялось, сцену можно понять по атрибутам и положению игрока
local function inferScene()
	local id = player:GetAttribute("MatchId") or 0
	local root = getRoot()
	if id == 0 then
		if root and root.Position.Magnitude < 1500 then return "lobby", nil end
		return nil, nil
	end
	local h = findHouse(id)
	if h and root then
		local ok, piv = pcall(function() return h:GetPivot().Position end)
		if ok and (root.Position - piv).Magnitude < 700 then return "house", h end
	end
	return nil, nil
end

local function safetyCheck()
	if T - S.sceneT < 4 then return end
	local sc, h = inferScene()
	if not sc or sc == S.scene then return end
	if S.scene == "end" and sc ~= "lobby" then return end
	setScene(sc, { matchId = player:GetAttribute("MatchId"), house = h })
end

local function readMatch()
	if S.matchId and S.matchId ~= 0 and (not S.match or not S.match.Parent) then
		S.match = findMatch(S.matchId)
	end
	local m = S.match
	if not m then return end
	S.phase = m:GetAttribute("Phase") or S.phase
	S.clock = tonumber(m:GetAttribute("Clock")) or S.clock
	S.night = tonumber(m:GetAttribute("Night")) or S.night
	local pw = m:GetAttribute("Power")
	if pw ~= nil then S.power = pw and true or false end
end

local function houseHour()
	local h = tonumber(S.clock) or 7
	if S.phase == "night" and h < 21 then h = 21 end
	return clamp(h, 7, 31)
end

---------------------------------------------------------------- главный такт
local indoorT, indoorTarget = 0, 0
local function tick(d, cam)
	readMatch()
	local camPos = cam.CFrame.Position
	local inHouse = S.house ~= nil and S.scene ~= "lobby"

	-- электричество пропало / появилось
	if inHouse then
		if power.last ~= nil and power.last ~= S.power then World.powerFx(S.power) end
		power.last = S.power
	else
		power.last = nil
	end

	-- внутри или снаружи
	indoorT = indoorT - d
	if indoorT <= 0 then
		indoorT = 0.25
		indoorTarget = (inHouse and World.isIndoors(camPos)) and 1 or 0
	end

	local hour = houseHour()
	if inHouse then planWeather() end
	E.night = inHouse and nightOf(hour) or 1
	E.indoor = approach(E.indoor, indoorTarget, d, 3)
	E.rain = approach(E.rain, rainTarget(inHouse, hour), d, 0.3)
	E.powerOff = approach(E.powerOff, (inHouse and not S.power) and 1 or 0, d, 2.5)
	E.alert = approach(E.alert, (inHouse and S.phase == "alert") and 1 or 0, d, 1.2)
	if snapNext then
		E.indoor = indoorTarget
		E.rain = rainTarget(inHouse, hour)
		E.powerOff = (inHouse and not S.power) and 1 or 0
		E.alert = (inHouse and S.phase == "alert") and 1 or 0
	end

	-- цель: пресет сцены + погода + свет + «внутри» + оповещение + настроение
	local p = inHouse and housePreset(hour) or copy(LOBBY)
	local r = E.rain
	if r > 0.001 then
		p.Brightness = p.Brightness * (1 - 0.45 * r)
		p.Outdoor = scaleC(desat(p.Outdoor, 0.4 * r), 1 - 0.2 * r)
		p.AtmDensity = p.AtmDensity + 0.07 * r
		p.AtmHaze = p.AtmHaze + 1.2 * r
		p.AtmGlare = p.AtmGlare * (1 - r)
		p.AtmColor = desat(p.AtmColor, 0.5 * r)
		p.CcSat = p.CcSat - 0.12 * r
		p.RaysInt = p.RaysInt * (1 - 0.85 * r)
		p.Stars = p.Stars * (1 - r)
		p.CloudCover = p.CloudCover + (0.93 - p.CloudCover) * r
		p.CloudDensity = p.CloudDensity + (0.85 - p.CloudDensity) * r
		p.CloudColor = scaleC(desat(p.CloudColor, 0.6 * r), 1 - 0.35 * r)
		p.ShiftTop = p.ShiftTop:Lerp(BLACK, r)
	end
	local po = E.powerOff
	if po > 0.001 then
		p.Ambient = scaleC(p.Ambient, 1 - 0.65 * po)
		p.CcSat = p.CcSat - 0.22 * po
		p.CcTint = p.CcTint:Lerp(rgb(190, 202, 236), 0.6 * po)
		p.Exposure = p.Exposure - 0.2 * po
		p.CcContrast = p.CcContrast + 0.06 * po
	end
	local ind = E.indoor
	if ind > 0.001 then
		p.AtmDensity = p.AtmDensity * (1 - 0.65 * ind)
		p.AtmHaze = p.AtmHaze * (1 - 0.75 * ind)
		-- днём глаз привыкает к полумраку комнат, ночью при свете ламп — тёплый оттенок
		p.Exposure = p.Exposure + 0.3 * ind * (1 - E.night)
		p.CcTint = p.CcTint:Lerp(rgb(255, 236, 214), 0.35 * ind * E.night * (1 - po))
	end
	if inHouse then p.Exposure = p.Exposure - 0.08 * (1 - ind) * E.night end
	local al = E.alert
	if al > 0.001 then
		p.Blur = math.max(p.Blur, 3 * al)
		p.Vignette = math.max(p.Vignette, 0.45 * al)
		p.CcContrast = p.CcContrast + 0.05 * al
		p.CcSat = p.CcSat - 0.1 * al
	end
	for _, m in pairs(mods) do
		if m.exposure then p.Exposure = p.Exposure + m.exposure end
		if m.saturation then p.CcSat = p.CcSat + m.saturation end
		if m.contrast then p.CcContrast = p.CcContrast + m.contrast end
		if m.brightness then p.CcBright = p.CcBright + m.brightness end
		if m.tint then p.CcTint = mulC(p.CcTint, m.tint) end
		if m.vignette then p.Vignette = math.max(p.Vignette, m.vignette) end
		if m.blur then p.Blur = math.max(p.Blur, m.blur) end
		if m.dofNear then p.DofNear = math.max(p.DofNear, m.dofNear) end
		if m.dofFar then p.DofFar = math.max(p.DofFar, m.dofFar) end
		if m.dofFocus then p.DofFocus = m.dofFocus end
		if m.dofRadius then p.DofRadius = m.dofRadius end
		if m.fogMul then p.AtmDensity = p.AtmDensity * m.fogMul end
	end

	-- плавный переход (при смене сцены — сразу)
	if snapNext or not cur then
		cur = p
		snapNext = false
	else
		cur = mix(cur, p, 1 - math.exp(-1.6 * d))
	end

	-- мгновенные эффекты поверх: молния, щелчок щитка, «дыхание» тумана в лобби
	local out = copy(cur)
	if inHouse and E.night > 0.7 and E.rain > 0.6 then
		if T > lightning.next then
			lightning.next = T + 14 + math.random() * 18
			lightning.t0 = T
			task.delay(0.7 + math.random() * 1.6, function() pcall(Sound.play, "Thunder", nil, { Volume = 0.7 }) end)
		end
	else
		lightning.next = math.max(lightning.next, T + 6)
	end
	local lf = lightningFlash()
	if lf > 0 then
		out.Outdoor = out.Outdoor:Lerp(rgb(170, 180, 220), lf * 0.7)
		out.Brightness = out.Brightness + 2.5 * lf
		out.Exposure = out.Exposure + 0.2 * lf * (1 - 0.5 * ind)
	end
	if inHouse then out.Exposure = out.Exposure + powerFlick() end
	if not inHouse then out.AtmDensity = out.AtmDensity + 0.025 * math.sin(T * 0.21) end

	guarded("applyLighting", applyLighting, out)
	-- зерно плёнки (если есть картинка Grain): ночью в доме заметнее
	local grain = inHouse and (0.03 + 0.05 * E.night) or 0.05
	guarded("vignette", updateVignette, out.Vignette, grain)
	guarded("loops", updateLoops, d, inHouse)
	guarded("rainEmitter", updateRainEmitter)
	if inHouse then
		guarded("lampFlicker", updateLampFlicker, camPos)
	else
		stopLampFlicker()
		guarded("billboard", setupBillboard)
	end
	guarded("billboardGlow", updateBillboard)
end

local acc, tvAcc, safeAcc = 0, 0, 0
local function frame(dt)
	T = T + dt
	local cam = workspace.CurrentCamera
	if not cam then return end
	guarded("rainFollow", followRain, cam)
	acc = acc + dt
	if acc >= 0.05 then
		local d = math.min(acc, 0.5)
		acc = 0
		guarded("tick", tick, d, cam)
	end
	tvAcc = tvAcc + dt
	if tvAcc >= 1 / 15 then
		local d = math.min(tvAcc, 0.5)
		tvAcc = 0
		guarded("tv", tvTick, d, cam.CFrame.Position)
	end
	safeAcc = safeAcc + dt
	if safeAcc >= 1 then
		safeAcc = 0
		guarded("safety", safetyCheck)
	end
end

---------------------------------------------------------------- публичное API
function World.scene() return S.scene end
function World.house() return S.house end
function World.match() return S.match end
function World.phase() return S.phase end
function World.clock() return S.clock end
function World.power() return S.power end
function World.rain() return E.rain end
function World.state()
	return {
		scene = S.scene, matchId = S.matchId, match = S.match, house = S.house, phase = S.phase,
		clock = S.clock, night = S.night, power = S.power, indoor = E.indoor > 0.5, rain = E.rain,
	}
end
-- подписка на смену сцены: fn(scene, data, prevScene)
function World.onScene(fn)
	table.insert(listeners, fn)
end
function World.isIndoors(pos)
	for _, r in ipairs(H.indoorRooms) do
		if inside(r, pos) then return true end
	end
	if #H.indoorRooms == 0 and H.interior then return inside(H.interior, pos) end
	return false
end
-- самая маленькая комната, в которой находится точка
function World.roomAt(pos)
	local best, bv = nil, math.huge
	for _, r in ipairs(H.rooms) do
		if inside(r, pos) then
			local v = r.Size.X * r.Size.Y * r.Size.Z
			if v < bv then
				best = r
				bv = v
			end
		end
	end
	return best
end
-- центр экрана телевизора в мире (для камеры во время оповещения)
function World.tvPosition()
	if TV.part and TV.part.Parent then
		return TV.part.CFrame:PointToWorldSpace(TV.faceOffset or Vector3.new())
	end
	return nil
end
function World.tvPart() return TV.part end
-- настроение от других модулей: { exposure, saturation, contrast, brightness, tint, vignette, blur, dofNear, dofFar, dofFocus, dofRadius, fogMul } или nil
function World.setMod(name, m)
	mods[name] = m
end
-- короткая вспышка виньетки (испуг, урон)
function World.pulse(color, strength, seconds)
	table.insert(pulses, { c = color or rgb(120, 0, 0), s = strength or 0.6, d = seconds or 0.6, t0 = T })
end

function World.init(c)
	ctx = c
	player = c.player or game:GetService("Players").LocalPlayer
	Config = c.Config
	Sound = c.Sound
	B = c.Build
	Net = c.Net
	guarded("setupLighting", setupLighting)
	guarded("buildRain", buildRain)
	task.spawn(function() guarded("buildVignette", buildVignette) end)

	-- начальная сцена по атрибутам (событие Scene могло прийти раньше нас)
	local sc, h = inferScene()
	if sc == "house" then
		setScene("house", { matchId = player:GetAttribute("MatchId"), house = h })
	elseif (player:GetAttribute("MatchId") or 0) ~= 0 then
		setScene("loading", { matchId = player:GetAttribute("MatchId") })
	end
	snapNext = true

	task.spawn(function()
		local ok, ev = pcall(Net.event, "Scene")
		if ok and ev then
			ev.OnClientEvent:Connect(function(scene, data)
				guarded("Scene", setScene, scene, data)
			end)
		end
	end)
	task.spawn(function()
		local ok, ev = pcall(Net.event, "Alert")
		if ok and ev then
			ev.OnClientEvent:Connect(function(data)
				if type(data) == "table" then S.alertData = data end
			end)
		end
	end)
	player:GetAttributeChangedSignal("MatchId"):Connect(function()
		-- матч закончился, а Scene "lobby" ещё не пришёл — safetyCheck догонит через пару секунд
		S.sceneT = math.min(S.sceneT, T - 2)
	end)

	RunService:BindToRenderStep("AA_World", Enum.RenderPriority.Camera.Value + 10, function(dt)
		local ok, err = pcall(frame, dt)
		if not ok then warnOnce("frame", err) end
	end)
end

return World
