-- Карта лобби: холодная туманная ночная площадь у ворот лечебницы Black Ridge.
-- Строит Model "Lobby" в начале координат (контракт §7 ARCHITECTURE.md):
-- точка появления, 4 кабинки (по одной на сложность), 4 киоска, большой экран EAS,
-- лечебница с рядом камер (по камере на каждый модуль ReplicatedStorage.Inmates),
-- заборы с колючкой, прожекторы, парковка с тюремным автобусом, будка охраны, фонари, деревья.
-- Освещение/небо/туман ставит клиент (World.lua); здесь только источники света внутри ламп.
--
-- План (вид сверху, север = −Z, юг = +Z; игрок появляется лицом на юг, к кабинкам и экрану):
--
--  z=-128 ┌──────────────── внешний забор + колючая проволока ────────────────────┐
--         │  ░░░░░░ ЛЕЧЕБНИЦА BLACK RIDGE (3 этажа, x −79..79, z −122..−87) ░░░░░░  │
--         │  ░ 3 эт.: окна с решётками            башня с вывеской над входом     ░  │
--  z=-87  │ [лестница]═ галерея 2 эт.: 2-й ряд камер ═══════════════════════════    │
--         │   ▯▯▯▯▯▯ [ВХОД «КОРПУС А»] ▯▯▯▯▯▯  1-й ряд камер, планшеты у дверей       │
--  z=-52  │ ●прожектор ═══ забор с колючкой ══[ВОРОТА BLACK RIDGE]══ забор ═══ ●    │
--         │ ПАРКОВКА  ┆      [Классы]      ◉ СПАВН (0,−8)      [Задания]   ┆ сквер  │
--         │ разметка  ┆   [Досье]                                 [Коды]   ┆ мёртвые│
--  z=+26  │ автобус   ┆        ┌Б4┐ ┌Б3┐ ┌Б2┐ ┌Б1┐  кабинки, вход на север   ┆ деревья│
--         │ лужи      ┆        бескон. сложн. средн. лёгк.                  ┆ скамьи │
--  z=+52  │           ┆            ███ ЭКРАН EAS 28×16 на ферме ███        ┆        │
--         │ будка охраны                                                            │
--  z=+128 └─[ворота открыты → бетонные блоки → туман]─────────────────────────────┘
--          x=-128                             x=0                           x=+128
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local B = require(Shared:WaitForChild("Build"))
local Config = require(Shared:WaitForChild("Config"))

local LobbyMap = {}
local ctx = nil

local V3, CF, ANG, rad = Vector3.new, CFrame.new, CFrame.Angles, math.rad
local M = Enum.Material
local NF = Enum.NormalId

-- ===== главные координаты (их же отдаёт отчёт ведущему) =====
local SPAWN_POS = V3(0, 0, -8)          -- центр точки появления
local PLAZA_Y = 0.3                     -- верх плитки площади
local BOOTH_Z = 26                      -- линия входов кабинок (кабинки уходят на +Z)
local BOOTH_STEP = 16                   -- шаг кабинок по X
local BILL_POS = V3(0, 28, 52)          -- центр экрана EAS
local FZ = -88                          -- середина толщины фасада лечебницы
local FACE_Z = FZ + 0.75                -- наружная грань фасада
local BACK_Z = -122                     -- задняя стена лечебницы
local STOREY = 13                       -- этаж лечебницы
local L1 = PLAZA_Y                      -- пол 1 этажа
local L2 = L1 + STOREY                  -- пол 2 этажа = настил галереи
local L3 = L2 + STOREY
local ROOF_Y = L3 + STOREY
local GATE_Z = -52                      -- линия внутреннего забора с воротами
local EDGE = 128                        -- внешний забор

-- ===== случайные числа (детерминированные, чтобы карта всегда одинаковая) =====
local seed = 20261003
local function rnd()
	seed = (seed * 16807) % 2147483647
	return seed / 2147483647
end
local function rr(a, b) return a + (b - a) * rnd() end

-- ===== цвета =====
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function clamp255(v) return math.floor(math.max(0, math.min(255, v)) + 0.5) end
-- лёгкий разброс цвета: amt = 0.06 → ±6% яркости и чуть-чуть оттенка
local function vary(c, amt)
	amt = amt or 0.06
	local k = 1 + (rnd() * 2 - 1) * amt
	local h = amt * 0.35
	return rgb(clamp255(c.R * 255 * k * (1 + (rnd() * 2 - 1) * h)),
		clamp255(c.G * 255 * k * (1 + (rnd() * 2 - 1) * h)),
		clamp255(c.B * 255 * k * (1 + (rnd() * 2 - 1) * h)))
end

local C = {
	concrete = rgb(124, 122, 116), concreteDark = rgb(84, 84, 82), concreteLight = rgb(150, 148, 140),
	brick = rgb(98, 56, 46), brickDark = rgb(72, 42, 36),
	steel = rgb(74, 78, 84), steelDark = rgb(40, 42, 46), rust = rgb(104, 68, 48),
	asphalt = rgb(46, 47, 50), lineWhite = rgb(196, 196, 186), lineYellow = rgb(206, 166, 48),
	amber = rgb(255, 176, 0), glass = rgb(150, 186, 204), darkGlass = rgb(26, 32, 38),
	grass = rgb(78, 74, 50), earth = rgb(46, 42, 34), bark = rgb(56, 46, 38),
	screen = rgb(10, 11, 14), paintGreen = rgb(140, 158, 144), sodium = rgb(255, 178, 104),
	cold = rgb(196, 220, 255), white = rgb(226, 224, 216),
}

-- цвета сложностей для подсветки кабинок
local DIFF_COLORS = {
	easy = rgb(96, 206, 112), normal = rgb(255, 176, 0), hard = rgb(232, 72, 52), endless = rgb(156, 96, 236),
}

-- заглавные названия (string.upper не трогает кириллицу)
local DIFF_TITLES = { easy = "ЛЁГКАЯ", normal = "СРЕДНЯЯ", hard = "СЛОЖНАЯ", endless = "БЕСКОНЕЧНАЯ" }

-- ===== мелкие помощники =====
-- деталь в локальной системе cf (x, y, z — смещение центра)
local function P(parent, name, size, cf, x, y, z, color, mat, props)
	return B.part(parent, name, size, cf * CF(x, y, z), color, mat, props)
end

-- тонкий цилиндр между двумя точками (трубы, ветки, перила)
local function rod(parent, name, a, b, d, color, mat, props)
	local dir = b - a
	local len = dir.Magnitude
	if len < 0.05 then return nil end
	local mid = a + dir * 0.5
	local cf = CFrame.lookAt(mid, b) * ANG(0, rad(90), 0)
	return B.cyl(parent, name, len, d, cf, color, mat, props)
end

-- брусок между двумя точками (балки, раскосы)
local function beam(parent, name, a, b, w, h, color, mat, props)
	local dir = b - a
	local len = dir.Magnitude
	if len < 0.05 then return nil end
	local cf = CFrame.lookAt(a + dir * 0.5, b)
	return B.part(parent, name, V3(w, h, len), cf, color, mat, props)
end

-- надпись: тёмная табличка с текстом
local function label(part, face, text, color, props, guiProps)
	local lp = { Text = text, TextColor3 = color or C.white, Font = Enum.Font.GothamBlack }
	if props then for k, v in pairs(props) do lp[k] = v end end
	return B.sign(part, face, text, lp, guiProps)
end

-- безопасный вызов участка постройки: ошибка в декорации не ломает всё лобби
local function safe(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then warn("[AA] LobbyMap: ошибка в «" .. name .. "»: " .. tostring(err)) end
	return ok
end

-- поворот так, чтобы локальный −Z смотрел из pos на target (по горизонтали)
local function facing(pos, target)
	return CFrame.lookAt(pos, V3(target.X, pos.Y, target.Z))
end

-- ==========================================================================
-- ТОЧКА ПОЯВЛЕНИЯ
-- ==========================================================================
local function buildSpawn(root)
	local f = B.model(root, "SpawnPad")
	local x, z = SPAWN_POS.X, SPAWN_POS.Z
	-- круглый помост с янтарным кольцом
	B.vcyl(f, "Dais", 0.5, 20, CF(x, PLAZA_Y - 0.1 + 0.25, z), C.concreteDark, M.Concrete)
	B.vcyl(f, "Ring", 0.1, 17.2, CF(x, 0.69, z), C.amber, M.Neon)
	B.vcyl(f, "Inner", 0.12, 16.6, CF(x, 0.72, z), rgb(36, 38, 44), M.Slate)
	-- огоньки по краю помоста
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + math.pi / 8
		B.part(f, "Glow", V3(0.5, 0.12, 0.5), CF(x + math.cos(a) * 9.3, 0.62, z + math.sin(a) * 9.3), C.amber, M.Neon)
	end
	-- сама точка появления: стальная плита, лицом на юг (+Z) к кабинкам и экрану
	local sp = B.make("SpawnLocation", {
		Name = "LobbySpawn", Anchored = true, CanCollide = true, Neutral = true, Duration = 0,
		AllowTeamChangeOnTouch = false, Enabled = true,
		Size = V3(10, 0.4, 10), CFrame = CF(x, 0.6, z) * ANG(0, math.pi, 0),
		Color = rgb(58, 60, 66), Material = M.DiamondPlate,
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
	}, root)
	-- нарисованная стрелка «к кабинкам»
	local acf = CF(x, 0.81, z + 2.2)
	P(f, "Arrow", V3(0.6, 0.02, 3.6), acf, 0, 0, -0.4, C.amber, M.SmoothPlastic)
	B.part(f, "Arrow", V3(0.6, 0.02, 2.2), acf * CF(-0.707, 0, 0.757) * ANG(0, rad(40), 0), C.amber, M.SmoothPlastic)
	B.part(f, "Arrow", V3(0.6, 0.02, 2.2), acf * CF(0.707, 0, 0.757) * ANG(0, rad(-40), 0), C.amber, M.SmoothPlastic)
	return sp
end

-- ==========================================================================
-- КАБИНКИ (по одной на сложность, стеклянный фасад, вход с севера)
-- ==========================================================================
local function buildBooth(parent, i, diffKey, bx)
	local d = Config.Difficulties[diffKey] or {}
	local dc = DIFF_COLORS[diffKey] or C.amber
	local m = B.model(parent, "Booth_" .. i)
	B.attrs(m, { Kind = "Booth", Index = i, Difficulty = diffKey, Max = Config.MaxPlayersPerHouse or 4, Count = 0, Countdown = -1 })
	local cf = CF(bx, PLAZA_Y, BOOTH_Z)         -- локальный −Z = север (к спавну), кабинка уходит в +Z
	local W, D, H = 10, 12, 10                    -- внутренний пол 10×12, высота 10
	local hw = W / 2 + 0.3
	local geo = B.model(m, "Shell")
	-- основание и пол
	P(geo, "Plinth", V3(W + 1.6, 0.4, D + 1.4), cf, 0, 0.2, D / 2, C.concreteDark, M.Concrete)
	P(geo, "Pad", V3(W, 0.12, D), cf, 0, 0.46, D / 2, rgb(62, 64, 70), M.DiamondPlate)
	B.vcyl(geo, "PadRing", 0.05, 7, cf * CF(0, 0.53, D / 2 + 0.5), dc, M.SmoothPlastic)
	B.vcyl(geo, "PadDisc", 0.06, 6.3, cf * CF(0, 0.55, D / 2 + 0.5), rgb(48, 50, 56), M.DiamondPlate)
	-- порог с полосами «зебра»
	P(geo, "Threshold", V3(5.4, 0.08, 0.9), cf, 0, 0.52, 0.5, C.amber, M.SmoothPlastic)
	for k = -2, 2 do
		B.part(geo, "Stripe", V3(0.35, 0.09, 1.0), cf * CF(k * 1.05, 0.53, 0.5) * ANG(0, rad(35), 0), rgb(20, 20, 22), M.SmoothPlastic)
	end
	-- задняя стена со стальной «шлюзовой» дверью
	P(geo, "BackWall", V3(W + 1.2, H, 0.8), cf, 0, H / 2 + 0.4, D + 0.4, rgb(66, 70, 76), M.Metal)
	P(geo, "DoorFrame", V3(5.6, 8.4, 0.2), cf, 0, 4.6, D - 0.08, rgb(30, 32, 36), M.Metal)
	P(geo, "DoorL", V3(2.5, 7.9, 0.2), cf, -1.3, 4.45, D - 0.2, rgb(92, 96, 102), M.DiamondPlate)
	P(geo, "DoorR", V3(2.5, 7.9, 0.2), cf, 1.3, 4.45, D - 0.2, rgb(92, 96, 102), M.DiamondPlate)
	P(geo, "DoorLight", V3(3.6, 0.35, 0.15), cf, 0, 9.1, D - 0.1, dc, M.Neon)
	-- боковые стены: стальной цоколь + стекло + стойки
	for s = -1, 1, 2 do
		P(geo, "Kick", V3(0.5, 1.2, D), cf, s * hw, 1.0, D / 2, C.steelDark, M.Metal)
		P(geo, "Glass", V3(0.25, H - 1.6, D - 0.6), cf, s * hw, 1.6 + (H - 1.6) / 2, D / 2, C.glass, M.Glass, { Transparency = 0.55 })
		for _, mz in ipairs({ 0, D / 2, D }) do
			P(geo, "Mullion", V3(0.5, H, 0.5), cf, s * hw, H / 2 + 0.4, mz, C.steel, M.Metal)
		end
	end
	-- фасад: стекло по краям и открытый вход 5.5 шириной посередине
	for s = -1, 1, 2 do
		local gx = s * (2.95 + (hw - 2.95) / 2)
		local gw = hw - 2.95 - 0.25
		P(geo, "FrontKick", V3(gw, 1.2, 0.4), cf, gx, 1.0, 0, C.steelDark, M.Metal)
		P(geo, "FrontGlass", V3(gw, H - 2.9, 0.25), cf, gx, 1.6 + (H - 2.9) / 2, 0, C.glass, M.Glass, { Transparency = 0.55 })
		P(geo, "Jamb", V3(0.5, H, 0.5), cf, s * 3.0, H / 2 + 0.4, 0, C.steel, M.Metal)
	end
	local header = P(geo, "Header", V3(W + 1.2, 1.4, 0.6), cf, 0, H - 0.3, 0, rgb(34, 36, 40), M.Metal)
	local nights = d.endless and "НОЧИ БЕЗ КОНЦА" or (tostring(d.nights or "?") .. " НОЧЕЙ")
	label(header, NF.Front, (DIFF_TITLES[diffKey] or d.name or diffKey) .. "  ·  " .. nights, dc)
	-- крыша, потолок и янтарная лампа
	P(geo, "Roof", V3(W + 2.2, 0.6, D + 1.8), cf, 0, H + 0.7, D / 2, rgb(38, 40, 44), M.Metal)
	P(geo, "Fascia", V3(W + 2.3, 0.25, 0.3), cf, 0, H + 0.45, -0.95, dc, M.Neon)
	P(geo, "Ceiling", V3(W, 0.2, D), cf, 0, H + 0.3, D / 2, rgb(150, 150, 146), M.SmoothPlastic)
	local lamp = B.vcyl(m, "Lamp", 0.25, 2.6, cf * CF(0, H + 0.08, D / 2), rgb(255, 170, 60), M.Neon)
	B.light(lamp, "PointLight", { Color = rgb(255, 166, 64), Range = 18, Brightness = 2.2 })
	-- скамейка ожидания у боковой стены
	P(geo, "Bench", V3(1.6, 0.3, 6), cf, -W / 2 + 1.0, 2.0, D / 2 + 1, rgb(84, 62, 44), M.WoodPlanks)
	P(geo, "BenchLeg", V3(1.2, 1.5, 0.3), cf, -W / 2 + 1.0, 1.2, D / 2 - 1.5, C.steelDark, M.Metal)
	P(geo, "BenchLeg", V3(1.2, 1.5, 0.3), cf, -W / 2 + 1.0, 1.2, D / 2 + 3.5, C.steelDark, M.Metal)
	-- вывеска над входом (её SurfaceGui рисует клиент), рамка позади
	P(geo, "SignFrame", V3(W + 0.8, 3.9, 0.5), cf, 0, H + 3.15, 0.15, rgb(26, 27, 30), M.Metal)
	P(geo, "SignPost", V3(0.3, 1.2, 0.3), cf, -4, H + 1.3, 0.2, C.steelDark, M.Metal)
	P(geo, "SignPost", V3(0.3, 1.2, 0.3), cf, 4, H + 1.3, 0.2, C.steelDark, M.Metal)
	local sign = P(m, "Sign", V3(W + 0.4, 3.4, 0.3), cf, 0, H + 3.15, -0.25, C.screen, M.SmoothPlastic)
	sign:SetAttribute("ScreenFace", "Front")
	-- зона: игроки, чей HumanoidRootPart внутри, считаются в кабинке
	local zone = B.marker(m, "Zone", V3(W, 9, D), cf * CF(0, 0.5 + 4.5, D / 2))
	zone.CanTouch = true
	return m
end

local function buildBooths(root)
	local f = B.folder(root, "Booths")
	local keys = {}
	for k, v in pairs(Config.Difficulties) do table.insert(keys, { k = k, o = v.order or 9 }) end
	table.sort(keys, function(a, b) return a.o < b.o end)
	local list = {}
	-- слева направо, если смотреть со спавна (игрок смотрит на +Z, его левая рука — +X)
	for i, e in ipairs(keys) do
		local bx = (#keys - 1) / 2 * BOOTH_STEP - (i - 1) * BOOTH_STEP
		local ok = safe("кабинка " .. e.k, function() table.insert(list, buildBooth(f, i, e.k, bx)) end)
		if not ok then error("кабинка " .. e.k .. " не построилась") end
	end
	-- общий указатель над рядом кабинок не нужен: экран EAS стоит прямо за ними
	return list
end

-- ==========================================================================
-- КИОСКИ (классы, досье, задания, коды)
-- ==========================================================================
local KIOSKS = {
	{ name = "Classes", title = "КЛАССЫ", color = rgb(64, 176, 96), pos = V3(-32, 0, -20), board = "ВЫБЕРИ КЛАСС\nза Amber" },
	{ name = "Dossiers", title = "ДОСЬЕ", color = rgb(206, 64, 54), pos = V3(-36, 0, 4), board = "ДОСЬЕ\nЗАКЛЮЧЁННЫХ" },
	{ name = "Quests", title = "ЗАДАНИЯ", color = rgb(64, 128, 222), pos = V3(32, 0, -20), board = "ЗАДАНИЯ\nи награды" },
	{ name = "Codes", title = "КОДЫ", color = rgb(146, 96, 222), pos = V3(36, 0, 4), board = "ВВЕДИ\nКОД" },
}

local function buildKiosk(parent, def)
	local m = B.model(parent, "Kiosk_" .. def.name)
	m:SetAttribute("Opens", def.name)
	m:SetAttribute("Kind", "Kiosk")
	local cf = facing(V3(def.pos.X, PLAZA_Y, def.pos.Z), SPAWN_POS)   -- −Z смотрит на спавн
	local col = def.color
	local panel = rgb(52, 54, 58)
	P(m, "Base", V3(9.4, 0.4, 7.6), cf, 0, 0.2, 0.2, C.concreteDark, M.Concrete)
	P(m, "BackWall", V3(9, 9, 0.6), cf, 0, 4.9, 3.3, panel, M.Metal)
	for s = -1, 1, 2 do
		P(m, "Side", V3(0.5, 9, 6.2), cf, s * 4.25, 4.9, 0.3, panel, M.Metal)
		P(m, "SideStripe", V3(0.55, 9, 0.6), cf, s * 4.25, 4.9, -2.4, col, M.SmoothPlastic)
	end
	-- прилавок
	local counter = P(m, "Counter", V3(8, 3.2, 1.4), cf, 0, 2.0, -2.3, rgb(70, 58, 46), M.WoodPlanks)
	P(m, "CounterTop", V3(8.4, 0.25, 1.9), cf, 0, 3.72, -2.3, rgb(40, 40, 44), M.Slate)
	P(m, "CounterStripe", V3(8.05, 0.5, 0.1), cf, 0, 3.0, -3.02, col, M.SmoothPlastic)
	-- монитор на прилавке
	P(m, "MonitorStand", V3(0.3, 0.8, 0.3), cf, 1.8, 4.2, -2.0, C.steelDark, M.Metal)
	local mcf = cf * CF(1.8, 5.2, -2.0) * ANG(rad(12), 0, 0)
	P(m, "Monitor", V3(2.4, 1.6, 0.3), mcf, 0, 0, 0, rgb(24, 24, 28), M.SmoothPlastic)
	local scr = P(m, "Screen", V3(2.1, 1.3, 0.05), mcf, 0, 0, -0.18, C.screen, M.SmoothPlastic)
	label(scr, NF.Front, def.title, col, { BackgroundTransparency = 0, BackgroundColor3 = rgb(8, 10, 14) }, { LightInfluence = 0 })
	-- полка с коробками позади прилавка
	P(m, "Shelf", V3(6, 3, 1.2), cf, 0, 1.9, 2.4, rgb(60, 50, 40), M.WoodPlanks)
	for k = 1, 3 do
		P(m, "Box", V3(rr(0.9, 1.4), rr(0.6, 1.1), 0.9), cf, -2.6 + k * 1.4, 3.75, 2.4, vary(rgb(150, 120, 80), 0.15), B.mat("Cardboard", M.SmoothPlastic))
	end
	-- доска на задней стене
	local board = P(m, "Board", V3(6, 2.8, 0.1), cf, 0, 6.6, 2.95, rgb(16, 18, 22), M.SmoothPlastic)
	label(board, NF.Front, def.board, rgb(230, 226, 214), { Font = Enum.Font.GothamBold }, { LightInfluence = 0.4 })
	-- крыша, вывеска и полосатый козырёк
	P(m, "Roof", V3(10.4, 0.5, 8.6), cf, 0, 9.65, -0.2, rgb(36, 38, 42), M.Metal)
	local fascia = P(m, "Fascia", V3(10.4, 1.6, 0.35), cf, 0, 10.2, -4.55, rgb(14, 15, 18), M.Metal)
	label(fascia, NF.Front, def.title, col)
	for k = 0, 5 do
		local stripe = (k % 2 == 0) and col or rgb(232, 228, 216)
		B.part(m, "Awning", V3(1.6, 0.15, 2.4), cf * CF(-4.0 + k * 1.6, 8.6, -5.4) * ANG(rad(-22), 0, 0), stripe, M.Fabric)
	end
	-- тёплая лампа под крышей
	local lamp = P(m, "Lamp", V3(3, 0.2, 0.6), cf, 0, 9.3, -1.2, rgb(255, 214, 160), M.Neon)
	B.light(lamp, "PointLight", { Color = rgb(255, 204, 150), Range = 14, Brightness = 1.6 })
	-- коврик перед прилавком
	P(m, "Mat", V3(6, 0.06, 2.4), cf, 0, 0.03, -4.6, rgb(30, 30, 32), M.Fabric)
	-- подсказка: клиент откроет нужный интерфейс по атрибуту Opens
	local prompt = B.prompt(counter, "Prompt", def.title, "Киоск", { HoldDuration = 0, MaxActivationDistance = 10 })
	prompt:SetAttribute("Opens", def.name)
	return m
end

local function buildKiosks(root)
	local f = B.folder(root, "Kiosks")
	local list = {}
	for _, def in ipairs(KIOSKS) do
		safe("киоск " .. def.name, function() table.insert(list, buildKiosk(f, def)) end)
	end
	return list
end

-- ==========================================================================
-- ЭКРАН ЭКСТРЕННОГО ОПОВЕЩЕНИЯ (над рядом кабинок, смотрит на спавн)
-- ==========================================================================
local function buildBillboard(root)
	local f = B.model(root, "BillboardFrame")
	local x, y, z = BILL_POS.X, BILL_POS.Y, BILL_POS.Z
	local W, H = 28, 16
	-- корпус и рамка
	B.part(f, "Housing", V3(W + 1.6, H + 1.6, 1.6), CF(x, y, z + 1.0), rgb(22, 23, 26), M.Metal)
	B.part(f, "BezelTop", V3(W + 1.8, 0.8, 0.5), CF(x, y + H / 2 + 0.4, z - 0.15), rgb(44, 46, 50), M.Metal)
	B.part(f, "BezelBottom", V3(W + 1.8, 0.8, 0.5), CF(x, y - H / 2 - 0.4, z - 0.15), rgb(44, 46, 50), M.Metal)
	B.part(f, "BezelL", V3(0.8, H, 0.5), CF(x - W / 2 - 0.4, y, z - 0.15), rgb(44, 46, 50), M.Metal)
	B.part(f, "BezelR", V3(0.8, H, 0.5), CF(x + W / 2 + 0.4, y, z - 0.15), rgb(44, 46, 50), M.Metal)
	-- сам экран: клиент рисует на грани ScreenFace
	local bill = B.part(root, "Billboard", V3(W, H, 0.4), CF(x, y, z), C.screen, M.SmoothPlastic)
	bill:SetAttribute("ScreenFace", "Front")
	B.light(bill, "SurfaceLight", { Face = NF.Front, Color = rgb(255, 150, 120), Range = 36, Angle = 75, Brightness = 1.1, Shadows = false })
	-- стальная ферма: две решётчатые опоры
	local legZ = z + 3
	for s = -1, 1, 2 do
		local lx = x + s * 10
		B.part(f, "Footing", V3(4, 1.2, 4), CF(lx, 0.6, legZ), C.concreteDark, M.Concrete)
		for t = -1, 1, 2 do
			B.part(f, "Leg", V3(0.7, y + H / 2 - 1, 0.7), CF(lx + t * 1.3, (y + H / 2 - 1) / 2 + 0.6, legZ), C.steel, M.Metal)
		end
		local top = y + H / 2 - 2
		local nb = 6
		for k = 0, nb - 1 do
			local y0 = 1.2 + k * (top - 1.2) / nb
			local y1 = 1.2 + (k + 1) * (top - 1.2) / nb
			local sgn = (k % 2 == 0) and 1 or -1
			beam(f, "Brace", V3(lx - sgn * 1.3, y0, legZ), V3(lx + sgn * 1.3, y1, legZ), 0.25, 0.25, C.steel, M.Metal)
		end
	end
	-- горизонтальные балки за экраном
	for _, by in ipairs({ y - H / 2 + 1.5, y + H / 2 - 1.5 }) do
		B.part(f, "Truss", V3(W + 2, 0.8, 0.8), CF(x, by, legZ), C.steel, M.Metal)
		B.part(f, "Strut", V3(W + 2, 0.4, 0.4), CF(x, by, z + 2.0), C.steelDark, M.Metal)
	end
	-- служебный мостик под экраном с перилами
	local wy = y - H / 2 - 3.6
	B.part(f, "Walkway", V3(W + 2, 0.25, 2.2), CF(x, wy, z - 1.2), rgb(70, 72, 76), M.DiamondPlate)
	B.part(f, "WalkwayEdge", V3(W + 2, 0.7, 0.15), CF(x, wy - 0.3, z - 2.3), rgb(30, 32, 36), M.Metal)
	local plate = B.part(f, "Plate", V3(16, 0.7, 0.1), CF(x, wy - 0.3, z - 2.4), rgb(16, 16, 18), M.SmoothPlastic)
	label(plate, NF.Front, "СИСТЕМА ЭКСТРЕННОГО ОПОВЕЩЕНИЯ  ·  BLACK RIDGE", C.amber)
	B.cyl(f, "Rail", W + 2, 0.18, CF(x, wy + 3.2, z - 2.25), C.steel, M.Metal)
	for k = 0, 6 do
		B.part(f, "RailPost", V3(0.2, 3.2, 0.2), CF(x - (W + 2) / 2 + 0.2 + k * (W + 1.6) / 6, wy + 1.6, z - 2.25), C.steel, M.Metal)
	end
	-- красный огонь на верхушке
	B.ball(f, "Beacon", 0.6, CF(x, y + H / 2 + 1.4, z + 1), rgb(255, 40, 30), M.Neon)
	return bill
end

-- ==========================================================================
-- КАМЕРЫ ЗАКЛЮЧЁННЫХ (одна на модуль Inmates)
-- ==========================================================================
-- данные заключённых: { key, num, name, color }, отсортированы по номеру
local function inmateList()
	local list = {}
	local folder = RS:FindFirstChild("Inmates")
	if not folder then return list end
	for _, ms in ipairs(folder:GetChildren()) do
		if ms:IsA("ModuleScript") then
			local e = { key = ms.Name, num = "???", name = ms.Name, color = C.amber }
			local ok, mod = pcall(require, ms)
			if ok and type(mod) == "table" then
				if mod.num ~= nil then e.num = tostring(mod.num) end
				if type(mod.name) == "string" then e.name = mod.name end
				if typeof(mod.color) == "Color3" then e.color = mod.color end
			else
				warn("[AA] LobbyMap: не загрузился заключённый " .. ms.Name .. ": " .. tostring(mod))
			end
			table.insert(list, e)
		end
	end
	table.sort(list, function(a, b)
		local na, nb = tonumber(a.num), tonumber(b.num)
		if na and nb and na ~= nb then return na < nb end
		if na and not nb then return true end
		if nb and not na then return false end
		return a.key < b.key
	end)
	return list
end

-- экран планшета: номер, имя, полоса цвета заключённого
local function tabletGui(tablet, e)
	local g = B.make("SurfaceGui", {
		Name = "Screen", Face = NF.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 80, LightInfluence = 0,
	}, tablet)
	local bg = B.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(8, 14, 18), BorderSizePixel = 0 }, g)
	B.make("Frame", { Size = UDim2.new(1, 0, 0.13, 0), BackgroundColor3 = e.color, BorderSizePixel = 0 }, bg)
	B.make("TextLabel", {
		Size = UDim2.new(1, 0, 0.13, 0), BackgroundTransparency = 1, Text = "BLACK RIDGE",
		TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = rgb(10, 10, 12),
	}, bg)
	B.make("TextLabel", {
		Position = UDim2.new(0.05, 0, 0.17, 0), Size = UDim2.new(0.9, 0, 0.1, 0), BackgroundTransparency = 1,
		Text = "ЗАКЛЮЧЁННЫЙ", TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = rgb(150, 170, 176),
	}, bg)
	B.make("TextLabel", {
		Position = UDim2.new(0.05, 0, 0.28, 0), Size = UDim2.new(0.9, 0, 0.3, 0), BackgroundTransparency = 1,
		Text = "№ " .. e.num, TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = C.amber,
	}, bg)
	B.make("TextLabel", {
		Position = UDim2.new(0.05, 0, 0.6, 0), Size = UDim2.new(0.9, 0, 0.16, 0), BackgroundTransparency = 1,
		Text = string.upper(e.name), TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = rgb(236, 236, 230),
	}, bg)
	B.make("TextLabel", {
		Position = UDim2.new(0.05, 0, 0.82, 0), Size = UDim2.new(0.9, 0, 0.1, 0), BackgroundTransparency = 1,
		Text = "[E] ДОСЬЕ", TextScaled = true, Font = Enum.Font.Code, TextColor3 = rgb(120, 220, 140),
	}, bg)
	return g
end

-- Камера в локальной системе cf: x поперёк проёма, −Z наружу (во двор), +Z вглубь здания,
-- пол на y = 0, высота этажа STOREY. W — ширина пролёта. e = данные заключённого или nil (пустая камера).
local CELL_D = 11
local function buildCell(parent, name, cf, W, e)
	local m = B.model(parent, name)
	local H = STOREY
	local hw = W / 2
	local wallCol = vary(C.concreteLight, 0.04)
	local P_W, DOOR_W = 2.4, 3.6
	local doorX = hw - P_W - DOOR_W / 2                 -- центр двери (столб с планшетом слева от неё со стороны двора)
	local barsR = doorX - DOOR_W / 2 - 0.6              -- правый край окна с решёткой (в локальном X)
	local barsL = -hw + 0.5
	local barsW = barsR - barsL
	-- передняя стена: столб, перемычка между дверью и решёткой, край, подоконник, верхняя перемычка
	P(m, "Pier", V3(P_W, H, 1.5), cf, hw - P_W / 2, H / 2, 0, wallCol, M.Concrete)
	P(m, "Lintel", V3(W - P_W, H - 8, 1.5), cf, -P_W / 2, 8 + (H - 8) / 2, 0, wallCol, M.Concrete)
	if barsW >= 1.2 then
		P(m, "Mullion", V3(0.6, 8, 1.5), cf, barsR + 0.3, 4, 0, wallCol, M.Concrete)
		P(m, "Edge", V3(0.5, 8, 1.5), cf, -hw + 0.25, 4, 0, wallCol, M.Concrete)
		P(m, "Sill", V3(barsW, 1, 1.5), cf, (barsL + barsR) / 2, 0.5, 0, wallCol, M.Concrete)
		local nb = math.max(2, math.floor(barsW / 0.55))
		for k = 1, nb do
			local bx = barsL + k * barsW / (nb + 1)
			B.vcyl(m, "Bar", 7, 0.18, cf * CF(bx, 4.5, -0.2), rgb(52, 56, 60), M.Metal)
		end
		P(m, "BarRail", V3(barsW, 0.25, 0.25), cf, (barsL + barsR) / 2, 4.5, -0.2, rgb(52, 56, 60), M.Metal)
	else
		P(m, "Fill", V3(barsR + 0.6 - (-hw), 8, 1.5), cf, (barsR + 0.6 - hw) / 2, 4, 0, wallCol, M.Concrete)
	end
	-- стальная дверь с окошком (полотно из четырёх кусков вокруг окна)
	local dcol = vary(rgb(70, 82, 80), 0.05)
	local dw, dh = DOOR_W - 0.2, 7.9
	local win0, win1 = 5.0, 6.6                         -- окошко по высоте
	local winW = 0.9
	P(m, "DoorLow", V3(dw, win0, 0.3), cf, doorX, win0 / 2, -0.1, dcol, M.CorrodedMetal)
	P(m, "DoorHigh", V3(dw, dh - win1, 0.3), cf, doorX, win1 + (dh - win1) / 2, -0.1, dcol, M.CorrodedMetal)
	P(m, "DoorSideA", V3((dw - winW) / 2, win1 - win0, 0.3), cf, doorX + winW / 2 + (dw - winW) / 4, (win0 + win1) / 2, -0.1, dcol, M.CorrodedMetal)
	P(m, "DoorSideB", V3((dw - winW) / 2, win1 - win0, 0.3), cf, doorX - winW / 2 - (dw - winW) / 4, (win0 + win1) / 2, -0.1, dcol, M.CorrodedMetal)
	P(m, "DoorGlass", V3(winW, win1 - win0, 0.08), cf, doorX, (win0 + win1) / 2, -0.05, rgb(120, 150, 160), M.Glass, { Transparency = 0.45 })
	B.vcyl(m, "DoorBar", win1 - win0, 0.12, cf * CF(doorX, (win0 + win1) / 2, -0.22), rgb(40, 42, 44), M.Metal)
	P(m, "Hatch", V3(1.4, 0.5, 0.12), cf, doorX, 3.6, -0.3, rgb(46, 52, 52), M.Metal)
	P(m, "Handle", V3(0.2, 0.9, 0.25), cf, doorX - dw / 2 + 0.4, 3.9, -0.35, rgb(150, 150, 146), M.Metal)
	P(m, "JambA", V3(0.2, 8.1, 0.5), cf, doorX + DOOR_W / 2 - 0.1, 4.05, -0.6, rgb(36, 38, 40), M.Metal)
	P(m, "JambB", V3(0.2, 8.1, 0.5), cf, doorX - DOOR_W / 2 + 0.1, 4.05, -0.6, rgb(36, 38, 40), M.Metal)
	P(m, "DoorHead", V3(DOOR_W, 0.25, 0.5), cf, doorX, 8.0, -0.6, rgb(36, 38, 40), M.Metal)
	-- табличка с номером над входом
	local plate = P(m, "Plate", V3(2.6, 1.0, 0.15), cf, doorX, 9.2, -0.83, rgb(14, 14, 16), M.SmoothPlastic)
	label(plate, NF.Front, e and e.num or "—", e and C.amber or rgb(110, 110, 110), { Font = Enum.Font.Code })
	-- внутренности: пол, потолок, стены (внутри — бледная «больничная» краска)
	local paint = vary(C.paintGreen, 0.05)
	P(m, "Floor", V3(W, 0.5, CELL_D + 1.5), cf, 0, -0.25, (CELL_D + 1.5) / 2 - 0.75, rgb(96, 98, 94), M.Concrete)
	P(m, "Ceiling", V3(W, 0.9, CELL_D), cf, 0, H - 0.55, CELL_D / 2 + 0.75, rgb(118, 120, 116), M.Concrete)
	P(m, "WallA", V3(0.5, H - 1, CELL_D), cf, hw - 0.25, (H - 1) / 2, CELL_D / 2 + 0.75, paint, B.mat("Plaster", M.Concrete))
	P(m, "WallB", V3(0.5, H - 1, CELL_D), cf, -hw + 0.25, (H - 1) / 2, CELL_D / 2 + 0.75, paint, B.mat("Plaster", M.Concrete))
	local back = P(m, "BackWall", V3(W, H - 1, 0.5), cf, 0, (H - 1) / 2, CELL_D + 0.5, paint, B.mat("Plaster", M.Concrete))
	P(m, "Dado", V3(W - 1, 3.5, 0.1), cf, 0, 1.75, CELL_D + 0.2, vary(rgb(84, 100, 92), 0.04), B.mat("Plaster", M.Concrete))
	-- кровать у стены, видной сквозь решётку
	local bedX = -hw + 2.2
	local blanket = e and e.color:Lerp(rgb(70, 70, 70), 0.45) or rgb(90, 92, 96)
	P(m, "BedFrame", V3(3.2, 0.35, 6.8), cf, bedX, 1.7, CELL_D - 3.2, rgb(60, 64, 68), M.Metal)
	P(m, "BedEnd", V3(3.2, 2.2, 0.2), cf, bedX, 1.1, CELL_D - 0.1 - 0.1, rgb(52, 56, 60), M.Metal)
	P(m, "BedEnd", V3(3.2, 1.7, 0.2), cf, bedX, 0.85, CELL_D - 6.6, rgb(52, 56, 60), M.Metal)
	P(m, "Mattress", V3(3.0, 0.5, 6.5), cf, bedX, 2.1, CELL_D - 3.2, rgb(178, 174, 160), M.Fabric)
	if e then
		P(m, "Pillow", V3(2.3, 0.4, 1.2), cf, bedX, 2.5, CELL_D - 1.1, rgb(206, 204, 194), M.Fabric)
		P(m, "Blanket", V3(3.1, 0.18, 4.0), cf, bedX, 2.42, CELL_D - 4.3, blanket, M.Fabric)
		-- унитаз из нержавейки и полка
		B.vcyl(m, "Toilet", 1.3, 1.5, cf * CF(hw - 1.4, 0.65, CELL_D - 0.9), rgb(170, 172, 170), M.Metal)
		P(m, "Tank", V3(1.8, 2.6, 0.7), cf, hw - 1.4, 1.3, CELL_D - 0.15, rgb(150, 152, 150), M.Metal)
		P(m, "Shelf", V3(2.4, 0.15, 0.8), cf, hw - 2.2, 6.0, CELL_D - 0.1, rgb(80, 70, 60), M.Wood)
		-- полоса цвета заключённого и номер на задней стене
		P(m, "Stripe", V3(W - 1, 0.45, 0.08), cf, 0, 4.0, CELL_D + 0.21, e.color, M.SmoothPlastic)
		local stencil = P(m, "Stencil", V3(3.2, 1.4, 0.05), cf, 0, 7.6, CELL_D + 0.23, paint, B.mat("Plaster", M.Concrete))
		label(stencil, NF.Front, e.num, rgb(40, 44, 42), { Font = Enum.Font.Code })
	end
	-- потолочный светильник в решётке
	local lamp = P(m, "Lamp", V3(1.6, 0.25, 0.8), cf, 0, H - 1.25, CELL_D / 2 + 1, e and rgb(200, 220, 230) or rgb(60, 64, 66), e and M.Neon or M.SmoothPlastic)
	if e then
		B.light(lamp, "PointLight", { Color = rgb(186, 214, 236), Range = 13, Brightness = 0.9, Shadows = false })
		-- планшет на столбе, лампа статуса над ним
		P(m, "TabletBox", V3(1.8, 2.3, 0.2), cf, hw - 1.45, 4.6, -0.85, rgb(30, 32, 36), M.Metal)
		local tablet = P(m, "Tablet", V3(1.5, 2.0, 0.1), cf, hw - 1.45, 4.6, -1.0, rgb(10, 14, 18), M.SmoothPlastic)
		tabletGui(tablet, e)
		local pr = B.prompt(tablet, "Prompt", "Досье", "Заключённый № " .. e.num, { HoldDuration = 0, MaxActivationDistance = 8 })
		pr:SetAttribute("Opens", "Dossier")
		pr:SetAttribute("Inmate", e.key)
		P(m, "StatusBox", V3(0.6, 0.6, 0.25), cf, hw - 1.45, 6.2, -0.85, rgb(30, 32, 36), M.Metal)
		P(m, "Status", V3(0.36, 0.36, 0.1), cf, hw - 1.45, 6.2, -1.0, rgb(255, 50, 40), M.Neon)
		B.attrs(m, { Kind = "Cell", Inmate = e.key, Num = e.num })
	end
	return m, back
end

-- ==========================================================================
-- ЛЕЧЕБНИЦА BLACK RIDGE: фасад с пролётами, камеры, галерея, лестница, крыша
-- ==========================================================================
-- раскладка пролётов: по perSide пролётов слева и справа от входного блока
local function asylumLayout(n)
	local L = { ENT = 9, CORNER = 4 }
	L.perSide = math.max(6, math.ceil(n / 4))
	L.perRow = L.perSide * 2
	L.CW = 11
	if L.perSide > 6 then L.CW = math.max(7.5, 66 / L.perSide) end
	L.HX = L.ENT + L.perSide * L.CW + L.CORNER
	L.bays = {}
	for b = 1, L.perSide do L.bays[b] = -L.HX + L.CORNER + (b - 0.5) * L.CW end
	for b = 1, L.perSide do L.bays[L.perSide + b] = L.ENT + (b - 0.5) * L.CW end
	L.XS = -L.HX - 4                  -- западный край галереи (здесь приходит лестница)
	L.XE = L.HX + 2
	return L
end

-- окно с решёткой: cf — центр проёма, −Z наружу; w×h — проём
local function windowDressing(parent, cf, w, h, lit)
	P(parent, "Glass", V3(w, h, 0.15), cf, 0, 0, 0.45, C.darkGlass, M.Glass, { Transparency = 0.25, Reflectance = 0.15 })
	if lit then
		P(parent, "RoomGlow", V3(w, h, 0.1), cf, 0, 0, 1.6, rgb(70, 92, 96), M.Neon, { Transparency = 0.55 })
	end
	local nb = math.max(2, math.floor(w / 0.9))
	for k = 1, nb do
		B.vcyl(parent, "Bar", h, 0.16, cf * CF(-w / 2 + k * w / (nb + 1), 0, -0.25), rgb(46, 48, 52), M.Metal)
	end
	P(parent, "Sill", V3(w + 0.9, 0.4, 1.1), cf, 0, -h / 2 - 0.2, -0.55, C.concreteLight, M.Concrete)
	P(parent, "Head", V3(w + 0.9, 0.7, 0.35), cf, 0, h / 2 + 0.35, -0.9, C.concreteLight, M.Concrete)
end

-- кирпичный пролёт с окном (2–3 этаж без камеры); cf как у камеры
local function windowBay(parent, cf, W, brickCol, lit)
	local a = (cf * CF(W / 2, 0, 0)).Position
	local b = (cf * CF(-W / 2, 0, 0)).Position
	B.wall(parent, "Wall", a, b, STOREY, 1.5, brickCol, M.Brick, { { at = W / 2, w = 3.6, y0 = 3.4, y1 = 9.6 } })
	windowDressing(parent, cf * CF(0, 6.5, 0), 3.6, 6.2, lit)
end

-- стена с окнами между точками a и b (низ стены), проёмы через равные промежутки
local function windowedWall(parent, name, a, b, y, h, col, mat, nWin, outward)
	local flat = V3(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	local ops = {}
	for k = 1, nWin do table.insert(ops, { at = len * k / (nWin + 1), w = 3.4, y0 = 3.4, y1 = 9.4 }) end
	B.wall(parent, name, V3(a.X, y, a.Z), V3(b.X, y, b.Z), h, 1.5, col, mat, ops)
	if nWin > 0 then
		local dir = flat.Unit
		for k = 1, nWin do
			local c = V3(a.X, y + 6.4, a.Z) + dir * (len * k / (nWin + 1))
			windowDressing(parent, CFrame.lookAt(c, c + outward), 3.4, 6.0, rnd() < 0.15)
		end
	end
end

local function buildAsylum(root, cellsFolder, inmates)
	local f = B.model(root, "Asylum")
	local n = #inmates
	local L = asylumLayout(n)
	local HX, ENT, CW = L.HX, L.ENT, L.CW
	local cells = {}
	local fac = B.model(f, "Facade")
	local top = ROOF_Y + 2.7                       -- верх парапета
	-- ряды камер: сначала первый этаж, остальные — на второй, группа по центру ряда
	local rows = { {}, {} }
	for i, e in ipairs(inmates) do
		if i <= L.perRow then table.insert(rows[1], e) else table.insert(rows[2], e) end
	end
	local function bayCF(b, level) return CF(L.bays[b], level, FZ) * ANG(0, math.pi, 0) end
	for r = 1, 2 do
		local level = (r == 1) and L1 or L2
		local list = rows[r]
		local off = math.floor((L.perRow - #list) / 2)
		for b = 1, L.perRow do
			local e = list[b - off]
			if e then
				local ok = safe("камера " .. e.key, function()
					local cell = buildCell(cellsFolder, "Cell_" .. e.key, bayCF(b, level), CW, e)
					cell:SetAttribute("Row", r)
					table.insert(cells, cell)
				end)
				if not ok then
					-- запасная камера: хотя бы планшет с подсказкой, чтобы досье открывалось
					local cell = B.model(cellsFolder, "Cell_" .. e.key)
					local t = B.part(cell, "Tablet", V3(1.5, 2, 0.1), bayCF(b, level) * CF(0, 4.6, -1), rgb(10, 14, 18), M.SmoothPlastic)
					local pr = B.prompt(t, "Prompt", "Досье", "Заключённый № " .. e.num, { HoldDuration = 0 })
					pr:SetAttribute("Opens", "Dossier")
					pr:SetAttribute("Inmate", e.key)
					table.insert(cells, cell)
				end
			elseif r == 1 then
				buildCell(fac, "EmptyCell", bayCF(b, level), CW, nil)
			else
				windowBay(fac, bayCF(b, level), CW, vary(C.brick, 0.07), rnd() < 0.12)
			end
		end
	end
	-- третий этаж: окна во всех пролётах
	for b = 1, L.perRow do windowBay(fac, CF(L.bays[b], L3, FZ) * ANG(0, math.pi, 0), CW, vary(C.brick, 0.07), rnd() < 0.15) end
	-- входной блок «КОРПУС А»
	local ent = B.model(f, "Entrance")
	local entCol = vary(C.concreteLight, 0.03)
	B.wall(ent, "Wall1", V3(-ENT, L1, FZ), V3(ENT, L1, FZ), STOREY, 1.5, entCol, M.Concrete, { { at = ENT, w = 8, y0 = 0, y1 = 10.5 } })
	for s = -1, 1, 2 do
		B.part(ent, "Door", V3(3.9, 10.4, 0.4), CF(s * 2, L1 + 5.2, FZ - 0.2), rgb(58, 66, 66), M.CorrodedMetal)
		B.part(ent, "DoorWin", V3(1.2, 2.2, 0.1), CF(s * 2, L1 + 7, FZ + 0.05), rgb(90, 120, 130), M.Glass, { Transparency = 0.3 })
		B.part(ent, "PushBar", V3(2.8, 0.3, 0.3), CF(s * 2, L1 + 4, FZ + 0.15), rgb(140, 140, 136), M.Metal)
	end
	B.part(ent, "DoorFrame", V3(8.8, 0.5, 0.8), CF(0, L1 + 10.75, FZ + 0.4), rgb(36, 38, 40), M.Metal)
	local blockSign = B.part(ent, "BlockSign", V3(7, 1.1, 0.2), CF(0, L1 + 11.4, FACE_Z + 0.1), rgb(16, 18, 18), M.SmoothPlastic)
	label(blockSign, NF.Back, "КОРПУС А", rgb(214, 222, 206))
	for s = -1, 1, 2 do
		local wl = B.part(ent, "WallLamp", V3(0.9, 1.2, 0.7), CF(s * 6.2, L1 + 8.5, FACE_Z + 0.35), rgb(40, 42, 44), M.Metal)
		B.part(ent, "WallLampLens", V3(0.7, 0.9, 0.08), CF(s * 6.2, L1 + 8.5, FACE_Z + 0.72), C.cold, M.Neon)
		B.light(wl, "SpotLight", { Face = NF.Back, Color = C.cold, Range = 20, Angle = 110, Brightness = 1.6, Shadows = (s == 1) })
	end
	B.wall(ent, "Wall2", V3(-ENT, L2, FZ), V3(ENT, L2, FZ), STOREY, 1.5, entCol, M.Concrete, { { at = ENT, w = 4.4, y0 = 0, y1 = 8.5 } })
	B.part(ent, "StaffDoor", V3(4.2, 8.4, 0.3), CF(0, L2 + 4.2, FZ - 0.1), rgb(64, 70, 72), M.CorrodedMetal)
	local staff = B.part(ent, "StaffSign", V3(3.6, 0.8, 0.1), CF(0, L2 + 9.3, FACE_Z + 0.05), rgb(150, 30, 26), M.SmoothPlastic)
	label(staff, NF.Back, "ТОЛЬКО ПЕРСОНАЛ", rgb(240, 236, 226))
	B.wall(ent, "Wall3", V3(-ENT, L3, FZ), V3(ENT, L3, FZ), STOREY, 1.5, entCol, M.Concrete, { { at = ENT, w = 8, y0 = 2.6, y1 = 10.6 } })
	windowDressing(ent, CFrame.lookAt(V3(0, L3 + 6.6, FZ), V3(0, L3 + 6.6, FZ + 10)), 8, 8, true)
	-- башня над входом с вывеской
	B.part(ent, "Tower", V3(2 * ENT, 9, 9), CF(0, ROOF_Y + 4.5, FACE_Z - 4.5), entCol, M.Concrete)
	B.part(ent, "TowerCap", V3(2 * ENT + 1.2, 0.9, 10.2), CF(0, ROOF_Y + 9.45, FACE_Z - 4.5), C.concreteDark, M.Concrete)
	local ts = B.part(ent, "TowerSign", V3(2 * ENT - 1.5, 4.6, 0.4), CF(0, ROOF_Y + 5.5, FACE_Z + 0.2), rgb(14, 16, 16), M.SmoothPlastic)
	label(ts, NF.Back, "BLACK RIDGE ASYLUM", rgb(206, 220, 200))
	for s = -1, 1, 2 do
		local sl = B.part(ent, "SignLamp", V3(1, 0.6, 1), CF(s * 5, ROOF_Y + 1.1, FACE_Z + 0.6) * ANG(rad(35), 0, 0), rgb(36, 38, 40), M.Metal)
		B.light(sl, "SpotLight", { Face = NF.Top, Color = C.cold, Range = 12, Angle = 70, Brightness = 2.5, Shadows = false })
	end
	-- углы, пилястры, пояса, карниз, парапет
	for s = -1, 1, 2 do
		B.part(fac, "Corner", V3(L.CORNER, top - L1, 1.5), CF(s * (HX - L.CORNER / 2), L1 + (top - L1) / 2, FZ), vary(C.concrete, 0.04), M.Concrete)
	end
	local px = { -HX + L.CORNER, -ENT, ENT, HX - L.CORNER }
	for b = 1, L.perSide - 1 do
		table.insert(px, -HX + L.CORNER + b * CW)
		table.insert(px, ENT + b * CW)
	end
	for _, x in ipairs(px) do
		B.part(fac, "Pilaster", V3(1, top - L1, 0.5), CF(x, L1 + (top - L1) / 2, FACE_Z + 0.25), vary(C.concrete, 0.04), M.Concrete)
	end
	B.part(fac, "Band3", V3(2 * HX + 1, 0.9, 0.8), CF(0, L3 - 0.45, FACE_Z + 0.4), C.concrete, M.Concrete)
	B.part(fac, "Cornice", V3(2 * HX + 2, 1.2, 1.8), CF(0, ROOF_Y + 0.2, FZ + 0.5), C.concreteDark, M.Concrete)
	-- оболочка: боковые и задняя стены, крыша
	local shell = B.model(f, "Shell")
	local z0, z1 = BACK_Z, FZ - 0.75
	for s = -1, 1, 2 do
		local x = s * (HX - 0.75)
		local out = V3(s, 0, 0)
		windowedWall(shell, "Side1", V3(x, 0, z0), V3(x, 0, z1), L1, STOREY, vary(C.concrete, 0.04), M.Concrete, 0, out)
		windowedWall(shell, "Side2", V3(x, 0, z0), V3(x, 0, z1), L2, STOREY, vary(C.brick, 0.06), M.Brick, 2, out)
		windowedWall(shell, "Side3", V3(x, 0, z0), V3(x, 0, z1), L3, STOREY, vary(C.brick, 0.06), M.Brick, 2, out)
		B.part(shell, "Parapet", V3(1.5, 2.7, z1 - z0), CF(x, ROOF_Y + 1.35, (z0 + z1) / 2), C.concreteDark, M.Concrete)
	end
	local bz = BACK_Z + 0.75
	windowedWall(shell, "Back1", V3(-HX, 0, bz), V3(HX, 0, bz), L1, STOREY, vary(C.concrete, 0.04), M.Concrete, 0, V3(0, 0, -1))
	windowedWall(shell, "Back2", V3(-HX, 0, bz), V3(HX, 0, bz), L2, STOREY, vary(C.brick, 0.06), M.Brick, 5, V3(0, 0, -1))
	windowedWall(shell, "Back3", V3(-HX, 0, bz), V3(HX, 0, bz), L3, STOREY, vary(C.brick, 0.06), M.Brick, 5, V3(0, 0, -1))
	B.part(shell, "Parapet", V3(2 * HX, 2.7, 1.5), CF(0, ROOF_Y + 1.35, bz), C.concreteDark, M.Concrete)
	B.part(shell, "ParapetFront", V3(2 * HX, 2.7, 1.5), CF(0, ROOF_Y + 1.35, FZ), vary(C.brick, 0.05), M.Brick)
	B.part(shell, "Coping", V3(2 * HX + 1, 0.4, 2), CF(0, top + 0.2, FZ), C.concreteLight, M.Concrete)
	B.part(shell, "Roof", V3(2 * HX - 3, 1, z1 - z0 - 1.5), CF(0, ROOF_Y + 0.5, (z0 + 1.5 + z1) / 2), rgb(52, 52, 54), M.Slate)
	B.part(shell, "Plinth", V3(2 * HX, 0.55, z1 - z0), CF(0, -0.025, (z0 + z1) / 2), C.concreteDark, M.Concrete)
	L.cells = cells
	L.model = f
	return L
end

-- галерея второго этажа вдоль фасада и наружная лестница с запада
local function buildCatwalk(root, L)
	local f = B.model(root, "Catwalk")
	local XS, XE = L.XS, L.XE
	local z0, z1 = FACE_Z, FACE_Z + 7
	local zc = (z0 + z1) / 2
	local steelC = rgb(66, 70, 74)
	-- настил кусками (разный оттенок), верх = пол 2 этажа
	local nDeck = math.ceil((XE - XS) / 11)
	local dl = (XE - XS) / nDeck
	for k = 0, nDeck - 1 do
		B.part(f, "Deck", V3(dl, 0.4, 7), CF(XS + (k + 0.5) * dl, L2 - 0.2, zc), vary(steelC, 0.05), M.DiamondPlate)
	end
	B.part(f, "EdgeBeam", V3(XE - XS, 0.9, 0.4), CF((XS + XE) / 2, L2 - 0.85, z1 - 0.2), rgb(40, 42, 46), M.Metal)
	B.part(f, "Ledger", V3(XE - XS, 0.6, 0.4), CF((XS + XE) / 2, L2 - 0.7, z0 + 0.2), rgb(40, 42, 46), M.Metal)
	-- колонны, поперечные балки и холодные лампы под настилом
	local nCol = math.ceil((XE - XS) / 11)
	local sp = (XE - XS - 1) / nCol
	for k = 0, nCol do
		local x = XS + 0.5 + k * sp
		local h = (L2 - 1.2) - L1
		B.part(f, "Column", V3(0.8, h, 0.8), CF(x, L1 + h / 2, z1 - 0.5), C.steel, M.Metal)
		B.part(f, "ColumnBase", V3(1.5, 0.25, 1.5), CF(x, L1 + 0.12, z1 - 0.5), C.steelDark, M.Metal)
		B.part(f, "CrossBeam", V3(0.6, 0.8, 7), CF(x, L2 - 0.8, zc), rgb(40, 42, 46), M.Metal)
		if k % 2 == 1 then
			local tube = B.part(f, "Tube", V3(3.2, 0.2, 0.3), CF(x + sp / 2, L2 - 1.1, zc - 1), rgb(206, 226, 240), M.Neon)
			B.light(tube, "PointLight", { Color = rgb(184, 214, 240), Range = 15, Brightness = 1.1, Shadows = (k % 4 == 1) })
		end
	end
	-- перила по внешнему краю и на восточном торце (запад открыт — там лестница)
	local ry = L2
	B.cyl(f, "Rail", XE - XS, 0.28, CF((XS + XE) / 2, ry + 3.6, z1 - 0.15), steelC, M.Metal)
	B.cyl(f, "MidRail", XE - XS, 0.2, CF((XS + XE) / 2, ry + 1.9, z1 - 0.15), steelC, M.Metal)
	B.part(f, "ToeBoard", V3(XE - XS, 0.5, 0.12), CF((XS + XE) / 2, ry + 0.25, z1 - 0.1), rgb(150, 120, 30), M.Metal)
	local nPost = math.ceil((XE - XS) / 5.5)
	for k = 0, nPost do
		B.part(f, "Post", V3(0.25, 3.6, 0.25), CF(XS + k * (XE - XS) / nPost, ry + 1.8, z1 - 0.15), steelC, M.Metal)
	end
	B.cyl(f, "EndRail", 7, 0.28, CF(XE - 0.15, ry + 3.6, zc) * ANG(0, rad(90), 0), steelC, M.Metal)
	B.cyl(f, "EndMid", 7, 0.2, CF(XE - 0.15, ry + 1.9, zc) * ANG(0, rad(90), 0), steelC, M.Metal)
	-- лестница: видимые ступени без столкновений + невидимый пандус-клин
	local N = 20
	local rise = (L2 - L1) / N
	local dep = 1.3
	local x0 = XS - N * dep
	for k = 1, N do
		local yt = L1 + k * rise
		B.part(f, "Step", V3(dep + 0.05, 0.3, 6.4), CF(x0 + (k - 0.5) * dep, yt - 0.15, zc), vary(steelC, 0.04), M.DiamondPlate, { CanCollide = (k == N) })
	end
	local run = N * dep
	B.wedge(f, "Ramp", V3(7, L2 - L1, run), CF(x0 + run / 2 - dep / 2, L1 + (L2 - L1) / 2, zc) * ANG(0, rad(90), 0), nil, nil, { Transparency = 1, CanCollide = true })
	local slope = math.atan((L2 - L1) / run)
	local slen = math.sqrt(run * run + (L2 - L1) * (L2 - L1))
	for _, sz in ipairs({ z0 + 0.15, z1 - 0.15 }) do
		B.part(f, "Stringer", V3(slen, 1.4, 0.3), CF(x0 + run / 2, L1 + (L2 - L1) / 2 - 0.5, sz) * ANG(0, 0, slope), rgb(44, 46, 50), M.Metal)
		rod(f, "Handrail", V3(x0, L1 + 3.4, sz), V3(XS, L2 + 3.4, sz), 0.24, steelC, M.Metal)
		for t = 0, 3 do
			local px = x0 + t * run / 3
			local py = L1 + (px - x0) / run * (L2 - L1)
			B.part(f, "HandPost", V3(0.22, 3.4, 0.22), CF(px, py + 1.7, sz), steelC, M.Metal)
		end
		local hx = x0 + run * 0.55
		local hy = L1 + 0.55 * (L2 - L1) - 1.2
		B.part(f, "StairLeg", V3(0.7, hy - L1, 0.7), CF(hx, L1 + (hy - L1) / 2, sz), C.steel, M.Metal)
	end
	B.part(f, "Landing", V3(4, 0.3, 8), CF(x0 - 2.2, L1 + 0.15, zc), C.concreteDark, M.Concrete)
	return f
end

-- ==========================================================================
-- ЗЕМЛЯ: грунт, плитка площади, бетон двора, асфальт парковки, сухая трава
-- ==========================================================================
-- прямоугольник плиток: x0..x1, z0..z1, верх yTop; tile — размер плитки; gap — шов
local function tiles(parent, name, x0, x1, z0, z1, tile, yTop, th, col, mat, amt, gap)
	local nx = math.max(1, math.floor((x1 - x0) / tile + 0.5))
	local nz = math.max(1, math.floor((z1 - z0) / tile + 0.5))
	local tx, tz = (x1 - x0) / nx, (z1 - z0) / nz
	gap = gap or 0
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			B.part(parent, name, V3(tx - gap, th, tz - gap), CF(x0 + (i + 0.5) * tx, yTop - th / 2, z0 + (j + 0.5) * tz), vary(col, amt), mat)
		end
	end
end

local function buildGround(root)
	local f = B.model(root, "Ground")
	B.part(f, "Earth", V3(320, 2, 320), CF(0, -1, 0), C.earth, M.Ground)
	-- площадь: плитка 12.5 со швами поверх тёмной подложки
	B.part(f, "Grout", V3(100, 0.25, 103), CF(0, 0.125, -0.5), rgb(64, 64, 62), M.Concrete)
	tiles(f, "Tile", -50, 50, -52, 51, 12.5, PLAZA_Y, 0.3, C.concrete, M.Concrete, 0.06, 0.22)
	-- двор лечебницы (бетонные плиты) и полосы вокруг здания
	tiles(f, "Yard", -125, 125, FACE_Z, GATE_Z, 25, PLAZA_Y, 0.3, rgb(104, 104, 100), M.Concrete, 0.05, 0.15)
	B.part(f, "Gravel", V3(250, 0.2, -BACK_Z - (-FACE_Z) + 6), CF(0, 0.1, (FACE_Z + BACK_Z - 6) / 2), rgb(70, 68, 62), M.Pebble)
	-- парковка: асфальт заплатками
	tiles(f, "Asphalt", -125, -54, GATE_Z, 128, 30, 0.2, 0.2, C.asphalt, M.Asphalt, 0.07, 0)
	-- газоны: восток и юг (сухая трава)
	tiles(f, "Grass", 50, 125, GATE_Z, 128, 25, 0.15, 0.15, C.grass, M.Grass, 0.12, 0)
	tiles(f, "Grass", -54, 50, 51, 128, 26, 0.15, 0.15, C.grass, M.Grass, 0.12, 0)
	B.part(f, "Strip", V3(4, 0.15, 103), CF(-52, 0.075, -0.5), C.grass, M.Grass)
	-- невидимые стены по периметру: дальше только туман
	for s = -1, 1, 2 do
		B.part(f, "Bound", V3(2, 60, 2 * EDGE + 20), CF(s * (EDGE + 8), 30, 0), nil, nil, { Transparency = 1, CastShadow = false })
		B.part(f, "Bound", V3(2 * EDGE + 20, 60, 2), CF(0, 30, s * (EDGE + 8)), nil, nil, { Transparency = 1, CastShadow = false })
	end
end

-- ==========================================================================
-- ЗАБОРЫ: сетка-рабица, кронштейны с колючей проволокой, спираль «егоза»
-- ==========================================================================
local GALV = rgb(118, 122, 126)

-- забор от a до b (низ на высоте a.Y); gaps = { {at = от a до центра проёма, w = ширина} };
-- lean — куда наклонены кронштейны колючки; coil — сколько витков спирали на пролёт между столбами
local function fenceRun(parent, a, b, gaps, lean, coil, H)
	H = H or 10
	local flat = V3(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	local dir = flat.Unit
	local zv = V3(-dir.Z, 0, dir.X)
	local side = ((lean.X * zv.X + lean.Z * zv.Z) >= 0) and 1 or -1
	local frame = CFrame.fromMatrix(V3(a.X, a.Y, a.Z), dir, V3(0, 1, 0))
	local list = {}
	for _, g in ipairs(gaps or {}) do table.insert(list, g) end
	table.sort(list, function(p, q) return p.at < q.at end)
	local spans, cursor = {}, 0
	for _, g in ipairs(list) do
		if g.at - g.w / 2 > cursor + 0.5 then table.insert(spans, { cursor, g.at - g.w / 2 }) end
		cursor = g.at + g.w / 2
	end
	if len - cursor > 0.5 then table.insert(spans, { cursor, len }) end
	local m = B.model(parent, "Fence")
	for _, sp in ipairs(spans) do
		local s0, s1 = sp[1], sp[2]
		local sl, sc = s1 - s0, (s0 + s1) / 2
		local nPost = math.max(1, math.ceil(sl / 10))
		local step = sl / nPost
		for k = 0, nPost do
			local s = s0 + k * step
			B.vcyl(m, "Post", H + 1, 0.4, frame * CF(s, (H + 1) / 2, 0), GALV, M.Metal)
			rod(m, "Arm", (frame * CF(s, H + 0.8, 0)).Position, (frame * CF(s, H + 2.6, side * 1.5)).Position, 0.16, GALV, M.Metal)
			if k < nPost and coil > 0 then
				-- витки спирали: перекрещенные тонкие прутки
				for c = 0, coil - 1 do
					local t = s + step * (c + 0.5) / coil
					local sg = (c % 2 == 0) and 1 or -1
					rod(m, "Razor", (frame * CF(t - 0.7, H + 0.25, -0.8 * sg)).Position, (frame * CF(t + 0.7, H + 1.9, 0.8 * sg)).Position, 0.08, rgb(168, 170, 174), M.Metal)
				end
			end
		end
		-- полотно сетки кусками до ~30 стадов (чуть разный оттенок)
		local nm = math.max(1, math.ceil(sl / 30))
		local ml = sl / nm
		for k = 0, nm - 1 do
			local mesh = B.part(m, "Mesh", V3(ml, H - 0.4, 0.08), frame * CF(s0 + (k + 0.5) * ml, 0.3 + (H - 0.4) / 2, 0), vary(rgb(128, 132, 136), 0.05), M.DiamondPlate, { Transparency = 0.62, CastShadow = false })
			B.texture(mesh, NF.Front, Config.Images.ChainLink, 3, 3)
			B.texture(mesh, NF.Back, Config.Images.ChainLink, 3, 3)
		end
		B.cyl(m, "TopRail", sl, 0.22, frame * CF(sc, H, 0), GALV, M.Metal)
		B.cyl(m, "BottomRail", sl, 0.14, frame * CF(sc, 0.35, 0), GALV, M.Metal)
		for j = 1, 3 do
			B.cyl(m, "Barb", sl, 0.07, frame * CF(sc, H + 0.8 + j * 0.55, side * j * 0.45), rgb(90, 92, 96), M.Metal)
		end
		if coil > 0 then
			B.cyl(m, "Coil", sl, 1.7, frame * CF(sc, H + 1.05, 0), rgb(176, 178, 182), M.Metal, { Transparency = 0.84, CastShadow = false })
		end
	end
	return m
end

-- табличка на заборе
local function fenceSign(parent, pos, yaw, text, bg, fg)
	local p = B.part(parent, "FenceSign", V3(5, 2.4, 0.12), B.at(pos.X, pos.Y, pos.Z, yaw), bg, M.Metal)
	label(p, NF.Front, text, fg, { Font = Enum.Font.GothamBlack })
	label(p, NF.Back, text, fg, { Font = Enum.Font.GothamBlack })
	return p
end

local function buildFences(root)
	local f = B.model(root, "Fences")
	local y = 0.15
	-- внутренний забор лечебницы с проёмом под главные ворота; колючка наклонена к лечебнице
	fenceRun(f, V3(-125, y, GATE_Z), V3(125, y, GATE_Z), { { at = 125, w = 20.8 } }, V3(0, 0, -1), 3)
	-- внешний периметр; на юге проём под въезд (x −104..−88)
	local E = EDGE
	fenceRun(f, V3(-E, y, -E), V3(E, y, -E), {}, V3(0, 0, -1), 2)
	fenceRun(f, V3(E, y, -E), V3(E, y, E), {}, V3(1, 0, 0), 2)
	fenceRun(f, V3(E, y, E), V3(-E, y, E), { { at = E + 96, w = 17.2 } }, V3(0, 0, 1), 2)
	fenceRun(f, V3(-E, y, E), V3(-E, y, -E), {}, V3(-1, 0, 0), 2)
	-- таблички
	fenceSign(f, V3(22, 5.5, GATE_Z + 0.15), 0, "ВХОД ТОЛЬКО ПО ПРОПУСКАМ", rgb(200, 196, 186), rgb(150, 24, 20))
	fenceSign(f, V3(-40, 5.5, GATE_Z + 0.15), 0, "ОСТОРОЖНО!\nВЫСОКОЕ НАПРЯЖЕНИЕ", rgb(232, 196, 40), rgb(20, 20, 20))
	fenceSign(f, V3(70, 5.5, GATE_Z + 0.15), 0, "ЗОНА ОХРАНЫ\nBLACK RIDGE", rgb(200, 196, 186), rgb(30, 30, 34))
	fenceSign(f, V3(-EDGE + 0.15, 5.5, 40), 90, "ОХРАНЯЕМАЯ ТЕРРИТОРИЯ", rgb(200, 196, 186), rgb(150, 24, 20))
end

-- главные ворота лечебницы: столбы, арка с вывеской BLACK RIDGE ASYLUM, распахнутые створки
local function buildMainGate(root)
	local f = B.model(root, "MainGate")
	local z = GATE_Z
	for s = -1, 1, 2 do
		local x = s * 9.2
		B.part(f, "Pillar", V3(2.4, 13, 2.4), CF(x, 0.3 + 6.5, z), vary(C.brickDark, 0.05), M.Brick)
		B.part(f, "PillarBase", V3(2.9, 1.4, 2.9), CF(x, 0.3 + 0.7, z), C.concreteDark, M.Concrete)
		B.part(f, "PillarCap", V3(3.0, 0.6, 3.0), CF(x, 13.6, z), C.concreteLight, M.Concrete)
		local lantern = B.part(f, "Lantern", V3(1.0, 1.4, 1.0), CF(x, 14.6, z), rgb(30, 32, 34), M.Metal)
		B.part(f, "LanternGlass", V3(0.8, 1.0, 1.05), CF(x, 14.6, z), rgb(200, 226, 255), M.Neon)
		B.light(lantern, "PointLight", { Color = C.cold, Range = 20, Brightness = 1.6 })
		-- распахнутая створка (повёрнута на 80° внутрь двора)
		local hinge = CF(s * 8, 0.3, z) * ANG(0, rad(s < 0 and 80 or -80), 0)
		local lw = 7.8
		local cx = -s * lw / 2
		local leaf = B.model(f, "GateLeaf")
		P(leaf, "LeafTop", V3(lw, 0.3, 0.3), hinge, cx, 9.6, 0, GALV, M.Metal)
		P(leaf, "LeafBottom", V3(lw, 0.3, 0.3), hinge, cx, 0.5, 0, GALV, M.Metal)
		P(leaf, "LeafEnd", V3(0.3, 9.4, 0.3), hinge, -s * lw, 5.05, 0, GALV, M.Metal)
		P(leaf, "LeafHinge", V3(0.3, 9.4, 0.3), hinge, 0, 5.05, 0, GALV, M.Metal)
		P(leaf, "LeafMesh", V3(lw, 9, 0.06), hinge, cx, 5.05, 0, rgb(128, 132, 136), M.DiamondPlate, { Transparency = 0.62, CastShadow = false })
		local d0 = (hinge * CF(0, 0.6, 0)).Position
		local d1 = (hinge * CF(-s * lw, 9.5, 0)).Position
		rod(leaf, "LeafBrace", d0, d1, 0.2, GALV, M.Metal)
	end
	-- арка: две балки, решётка и вывеска
	B.part(f, "ArchBeam", V3(21.2, 0.6, 0.6), CF(0, 14.2, z), C.steelDark, M.Metal)
	B.part(f, "ArchBeam", V3(21.2, 0.6, 0.6), CF(0, 16.0, z), C.steelDark, M.Metal)
	for k = 0, 5 do
		local x0 = -9 + k * 3
		beam(f, "ArchLattice", V3(x0, 14.2, z), V3(x0 + 3, 16.0, z), 0.2, 0.2, C.steelDark, M.Metal)
	end
	local sign = B.part(f, "GateSign", V3(20, 3.2, 0.4), CF(0, 17.9, z), rgb(14, 16, 16), M.Metal)
	label(sign, NF.Back, "BLACK RIDGE ASYLUM", rgb(214, 226, 206))
	label(sign, NF.Front, "BLACK RIDGE ASYLUM", rgb(214, 226, 206))
	local sub = B.part(f, "GateSub", V3(13, 1.1, 0.15), CF(0, 12.9, z), rgb(150, 28, 24), M.Metal)
	label(sub, NF.Back, "ПСИХИАТРИЧЕСКАЯ ЛЕЧЕБНИЦА СТРОГОГО РЕЖИМА", rgb(240, 236, 228))
	label(sub, NF.Front, "ПСИХИАТРИЧЕСКАЯ ЛЕЧЕБНИЦА СТРОГОГО РЕЖИМА", rgb(240, 236, 228))
	B.part(f, "SubHanger", V3(0.12, 0.8, 0.12), CF(-5, 13.8, z), C.steelDark, M.Metal)
	B.part(f, "SubHanger", V3(0.12, 0.8, 0.12), CF(5, 13.8, z), C.steelDark, M.Metal)
end

-- прожектор на мачте: светит из pos (низ мачты) в точку target
local function floodlight(parent, pos, target, h)
	h = h or 22
	local m = B.model(parent, "Floodlight")
	B.part(m, "Footing", V3(2.2, 1.0, 2.2), CF(pos.X, pos.Y + 0.5, pos.Z), C.concreteDark, M.Concrete)
	B.vcyl(m, "Mast", h, 0.8, CF(pos.X, pos.Y + h / 2, pos.Z), rgb(86, 90, 94), M.Metal)
	B.part(m, "JunctionBox", V3(0.9, 1.3, 0.6), CF(pos.X, pos.Y + 4, pos.Z) * CFrame.lookAt(V3(), V3(target.X - pos.X, 0, target.Z - pos.Z)) * CF(0, 0, -0.6), rgb(60, 64, 60), M.Metal)
	local topP = V3(pos.X, pos.Y + h, pos.Z)
	local flatDir = V3(target.X - pos.X, 0, target.Z - pos.Z).Unit
	local across = V3(-flatDir.Z, 0, flatDir.X)
	beam(m, "Crossbar", topP - across * 2.6, topP + across * 2.6, 0.35, 0.35, C.steelDark, M.Metal)
	for s = -1, 1, 2 do
		local hp = topP + across * (s * 1.9) + V3(0, 0.9, 0)
		local cf = CFrame.lookAt(hp, target)
		local head = B.part(m, "Head", V3(1.7, 1.3, 1.0), cf, rgb(40, 42, 44), M.Metal)
		B.part(m, "Lens", V3(1.45, 1.05, 0.1), cf * CF(0, 0, -0.52), rgb(230, 240, 255), M.Neon)
		B.part(m, "Yoke", V3(0.2, 0.9, 0.2), CF(hp.X, hp.Y - 0.7, hp.Z), C.steelDark, M.Metal)
		if s == 1 then
			B.light(head, "SpotLight", { Face = NF.Front, Color = rgb(206, 224, 255), Range = 60, Angle = 50, Brightness = 4 })
		end
	end
	return m
end

local function buildFloodlights(root)
	local f = B.model(root, "Floodlights")
	floodlight(f, V3(-46, 0.3, -56), V3(-28, 2, FACE_Z))
	floodlight(f, V3(46, 0.3, -56), V3(28, 2, FACE_Z))
	floodlight(f, V3(-123, 0.2, -10), V3(-90, 0, 20))
	floodlight(f, V3(-123, 0.2, 85), V3(-90, 0, 100))
	floodlight(f, V3(-48, 0.3, 47), V3(-14, 0, 30), 20)
	floodlight(f, V3(48, 0.3, 47), V3(14, 0, 30), 20)
	floodlight(f, V3(120, 0.3, -100), V3(80, 8, -100))
end

-- ==========================================================================
-- УЛИЧНАЯ МЕЛОЧЬ: фонари, скамейки, урны, конусы, барьеры, деревья, кусты, лужи, трещины
-- ==========================================================================
-- фонарь: pos — низ, кронштейн (локальный −Z) смотрит на target
local function lampPost(parent, pos, target, shadows)
	local m = B.model(parent, "LampPost")
	local cf = facing(pos, target)
	local poleC = rgb(46, 52, 50)
	B.vcyl(m, "Base", 1.2, 1.3, cf * CF(0, 0.6, 0), C.concreteDark, M.Concrete)
	B.vcyl(m, "Pole", 14, 0.5, cf * CF(0, 7.6, 0), poleC, M.Metal)
	B.vcyl(m, "Collar", 0.4, 0.75, cf * CF(0, 3.2, 0), poleC, M.Metal)
	P(m, "Arm", V3(0.3, 0.3, 3.4), cf, 0, 14.3, -1.5, poleC, M.Metal)
	P(m, "ArmBrace", V3(0.15, 0.15, 2.2), cf * CF(0, 13.5, -0.9) * ANG(rad(-35), 0, 0), 0, 0, 0, poleC, M.Metal)
	local head = P(m, "Head", V3(1.1, 0.5, 2.0), cf, 0, 14.25, -3.4, rgb(36, 38, 40), M.Metal)
	P(m, "Lens", V3(0.9, 0.1, 1.6), cf, 0, 13.97, -3.4, C.sodium, M.Neon)
	B.light(head, "SpotLight", { Face = NF.Bottom, Color = rgb(255, 180, 112), Range = 34, Angle = 115, Brightness = 2.4, Shadows = shadows ~= false })
	return m
end

local function bench(parent, cf)
	local m = B.model(parent, "Bench")
	local wood = rgb(92, 66, 44)
	for s = -1, 1, 2 do
		P(m, "Leg", V3(0.3, 1.9, 1.8), cf, s * 2.6, 0.95, 0, rgb(34, 36, 36), M.Metal)
	end
	for k = 0, 2 do
		P(m, "Slat", V3(6.2, 0.18, 0.5), cf, 0, 1.95, -0.6 + k * 0.6, vary(wood, 0.08), M.WoodPlanks)
	end
	for k = 0, 1 do
		B.part(m, "Back", V3(6.2, 0.45, 0.16), cf * CF(0, 2.7 + k * 0.7, 0.95 + k * 0.15) * ANG(rad(12), 0, 0), vary(wood, 0.08), M.WoodPlanks)
	end
	return m
end

local function trashCan(parent, pos)
	local m = B.model(parent, "TrashCan")
	local c = vary(rgb(44, 60, 50), 0.06)
	B.vcyl(m, "Body", 3, 2, CF(pos.X, pos.Y + 1.5, pos.Z), c, M.Metal)
	B.vcyl(m, "Rim", 0.25, 2.25, CF(pos.X, pos.Y + 3.0, pos.Z), rgb(30, 32, 32), M.Metal)
	B.vcyl(m, "Bag", 0.2, 1.8, CF(pos.X, pos.Y + 3.05, pos.Z), rgb(18, 18, 20), M.Plastic)
	return m
end

local function cone(parent, pos)
	local m = B.model(parent, "Cone")
	local o = rgb(236, 104, 24)
	B.part(m, "ConeBase", V3(1.3, 0.15, 1.3), CF(pos.X, pos.Y + 0.08, pos.Z), rgb(30, 30, 30), M.Plastic)
	B.vcyl(m, "ConeLow", 0.9, 0.95, CF(pos.X, pos.Y + 0.6, pos.Z), o, M.Plastic)
	B.vcyl(m, "ConeBand", 0.3, 0.75, CF(pos.X, pos.Y + 1.2, pos.Z), rgb(230, 230, 226), M.Plastic)
	B.vcyl(m, "ConeTop", 0.5, 0.55, CF(pos.X, pos.Y + 1.6, pos.Z), o, M.Plastic)
	return m
end

-- полицейская козлина «ПРОХОД ЗАКРЫТ»
local function sawhorse(parent, cf)
	local m = B.model(parent, "Barrier")
	local board = P(m, "Board", V3(6, 0.9, 0.15), cf, 0, 3.0, 0, rgb(232, 230, 222), M.Wood)
	label(board, NF.Front, "ПРОХОД ЗАКРЫТ", rgb(200, 30, 24))
	label(board, NF.Back, "ПРОХОД ЗАКРЫТ", rgb(200, 30, 24))
	P(m, "Rail", V3(6, 0.5, 0.15), cf, 0, 1.6, 0, rgb(236, 104, 24), M.Wood)
	for s = -1, 1, 2 do
		P(m, "LegA", V3(0.25, 3.4, 0.25), cf * CF(s * 2.6, 1.7, 0) * ANG(rad(15), 0, 0), 0, 0, -0.1, rgb(60, 60, 60), M.Metal)
		P(m, "LegB", V3(0.25, 3.4, 0.25), cf * CF(s * 2.6, 1.7, 0) * ANG(rad(-15), 0, 0), 0, 0, 0.1, rgb(60, 60, 60), M.Metal)
	end
	return m
end

-- бетонный блок «нью-джерси»
local function jersey(parent, cf)
	local m = B.model(parent, "Jersey")
	local c = vary(rgb(150, 148, 140), 0.05)
	P(m, "Base", V3(6, 1.2, 2.4), cf, 0, 0.6, 0, c, M.Concrete)
	P(m, "Top", V3(6, 1.8, 1.0), cf, 0, 2.1, 0, c, M.Concrete)
	P(m, "Stripe", V3(6.02, 0.35, 1.02), cf, 0, 2.6, 0, rgb(220, 180, 40), M.SmoothPlastic)
	return m
end

-- секция стального ограждения для толпы
local function crowdBarrier(parent, cf)
	local m = B.model(parent, "CrowdBarrier")
	local c = rgb(150, 154, 158)
	P(m, "Top", V3(7, 0.2, 0.2), cf, 0, 3.6, 0, c, M.Metal)
	P(m, "Bottom", V3(7, 0.2, 0.2), cf, 0, 0.8, 0, c, M.Metal)
	for k = 0, 6 do
		P(m, "Pale", V3(0.12, 2.8, 0.12), cf, -3 + k, 2.2, 0, c, M.Metal)
	end
	for s = -1, 1, 2 do
		P(m, "Foot", V3(0.2, 0.15, 2), cf, s * 3.3, 0.08, 0, c, M.Metal)
		P(m, "Upright", V3(0.2, 3.6, 0.2), cf, s * 3.4, 1.8, 0, c, M.Metal)
	end
	return m
end

-- мёртвое дерево: ствол из двух сужающихся цилиндров и кривые голые ветки
local function deadTree(parent, pos, scale)
	local m = B.model(parent, "DeadTree")
	scale = scale or 1
	local bark = vary(C.bark, 0.1)
	local h1, h2 = 7 * scale, 6 * scale
	B.vcyl(m, "Trunk", h1, 1.6 * scale, CF(pos.X, pos.Y + h1 / 2, pos.Z), bark, M.Wood)
	local lean = V3(rr(-0.6, 0.6), 0, rr(-0.6, 0.6)) * scale
	local t0 = V3(pos.X, pos.Y + h1 - 0.3, pos.Z)
	local t1 = t0 + V3(lean.X, h2, lean.Z)
	rod(m, "Trunk2", t0, t1, 1.0 * scale, bark, M.Wood)
	for k = 1, 5 do
		local a = rnd() * math.pi * 2
		local e = rad(rr(25, 60))
		local L = rr(3.5, 6.5) * scale
		local s = t0 + (t1 - t0) * rr(0.15, 0.95)
		local tip = s + V3(math.cos(a) * math.cos(e), math.sin(e), math.sin(a) * math.cos(e)) * L
		rod(m, "Branch", s, tip, rr(0.35, 0.55) * scale, bark, M.Wood)
		if k <= 3 then
			local a2 = a + rr(-0.9, 0.9)
			local tip2 = tip + V3(math.cos(a2), rr(0.4, 1.1), math.sin(a2)) * rr(1.5, 3) * scale
			rod(m, "Twig", tip, tip2, 0.2 * scale, bark, M.Wood)
		end
	end
	return m
end

local function bush(parent, pos, size)
	local m = B.model(parent, "Bush")
	size = size or 3.5
	local c = vary(rgb(58, 62, 38), 0.12)
	B.ball(m, "Leaves", size, CF(pos.X, pos.Y + size * 0.3, pos.Z), c, M.Grass)
	B.ball(m, "Leaves", size * 0.75, CF(pos.X + size * 0.4, pos.Y + size * 0.25, pos.Z + rr(-0.5, 0.5)), vary(c, 0.08), M.Grass)
	if rnd() < 0.5 then
		B.ball(m, "Leaves", size * 0.6, CF(pos.X - size * 0.35, pos.Y + size * 0.2, pos.Z + size * 0.3), vary(c, 0.08), M.Grass)
	end
	return m
end

-- лужа: несколько тёмных отражающих «блинов»
local function puddle(parent, pos, size)
	local m = B.model(parent, "Puddle")
	local c = rgb(22, 26, 32)
	B.vcyl(m, "Water", 0.03, size, CF(pos.X, pos.Y + 0.015, pos.Z), c, M.Glass, { Reflectance = 0.25, Transparency = 0.1, CastShadow = false })
	for k = 1, 2 do
		local a = rnd() * math.pi * 2
		local d = size * rr(0.5, 0.8)
		B.vcyl(m, "Water", 0.03, d, CF(pos.X + math.cos(a) * size * 0.4, pos.Y + 0.016, pos.Z + math.sin(a) * size * 0.4), c, M.Glass, { Reflectance = 0.25, Transparency = 0.1, CastShadow = false })
	end
	return m
end

-- трещина в покрытии: ломаная из тонких тёмных полосок
local function crack(parent, pos, len)
	local a = rnd() * math.pi * 2
	local p = pos
	local seg = len / 3
	for k = 1, 3 do
		a = a + rr(-0.7, 0.7)
		local q = p + V3(math.cos(a) * seg, 0, math.sin(a) * seg)
		beam(parent, "Crack", p, q, rr(0.1, 0.22), 0.02, rgb(24, 24, 26), M.SmoothPlastic, { CastShadow = false })
		p = q
	end
end

-- ==========================================================================
-- ТЮРЕМНЫЙ АВТОБУС (перед смотрит в локальный −Z)
-- ==========================================================================
local function prisonBus(parent, cf)
	local m = B.model(parent, "PrisonBus")
	local body = rgb(196, 196, 186)
	local Lb, Wb = 38, 8.6
	local hz = Lb / 2
	P(m, "Chassis", V3(Wb - 0.6, 1.2, Lb - 2), cf, 0, 2.1, 0, rgb(28, 28, 30), M.Metal)
	P(m, "LowerBody", V3(Wb, 3.6, Lb), cf, 0, 4.4, 0, body, M.Metal)
	P(m, "Windows", V3(Wb - 0.2, 2.6, Lb - 2), cf, 0, 7.5, 0.5, C.darkGlass, M.Glass, { Transparency = 0.15, Reflectance = 0.2 })
	P(m, "UpperBody", V3(Wb, 1.0, Lb), cf, 0, 9.3, 0, body, M.Metal)
	P(m, "RoofCap", V3(Wb - 0.8, 0.4, Lb - 1), cf, 0, 10.0, 0, rgb(170, 170, 162), M.Metal)
	P(m, "RoofHatch", V3(2.4, 0.3, 2.4), cf, 0, 10.3, 6, rgb(150, 150, 144), M.Metal)
	-- оконные стойки и решётки по бортам
	for s = -1, 1, 2 do
		for k = 0, 7 do
			P(m, "Pillar", V3(0.3, 2.6, 0.5), cf, s * (Wb / 2 - 0.05), 7.5, -hz + 4 + k * 4.6, body, M.Metal)
		end
		P(m, "Grille", V3(0.08, 0.15, Lb - 4), cf, s * (Wb / 2 + 0.05), 7.5, 1, rgb(40, 40, 40), M.Metal)
		P(m, "Grille", V3(0.08, 0.15, Lb - 4), cf, s * (Wb / 2 + 0.05), 8.3, 1, rgb(40, 40, 40), M.Metal)
		P(m, "Stripe", V3(0.08, 0.6, Lb), cf, s * (Wb / 2 + 0.02), 5.4, 0, rgb(214, 128, 24), M.SmoothPlastic)
		local txt = P(m, "Lettering", V3(0.05, 1.3, 20), cf, s * (Wb / 2 + 0.03), 4.3, 2, body, M.Metal)
		label(txt, s > 0 and NF.Right or NF.Left, "ИСПРАВИТЕЛЬНОЕ УЧРЕЖДЕНИЕ BLACK RIDGE", rgb(30, 34, 40))
		P(m, "Mirror", V3(0.3, 1.2, 0.8), cf, s * (Wb / 2 + 0.7), 7.2, -hz + 0.6, rgb(24, 24, 26), M.Metal)
	end
	-- колёса: ось цилиндра по X (поперёк автобуса)
	for _, wz in ipairs({ -hz + 6, hz - 9, hz - 5 }) do
		for s = -1, 1, 2 do
			B.cyl(m, "Wheel", 1.2, 3.4, cf * CF(s * (Wb / 2 - 0.4), 1.7, wz), rgb(22, 22, 24), B.mat("Rubber", M.SmoothPlastic))
			B.cyl(m, "Hub", 1.25, 1.5, cf * CF(s * (Wb / 2 - 0.4), 1.7, wz), rgb(120, 120, 116), M.Metal)
		end
	end
	-- перед: лобовое, решётка радиатора, фары, табло маршрута
	P(m, "Windshield", V3(Wb - 1, 2.8, 0.2), cf, 0, 7.4, -hz - 0.05, rgb(40, 50, 58), M.Glass, { Transparency = 0.2, Reflectance = 0.25 })
	P(m, "Grill", V3(5, 1.6, 0.2), cf, 0, 3.8, -hz - 0.1, rgb(36, 36, 38), M.DiamondPlate)
	P(m, "Bumper", V3(Wb + 0.2, 0.8, 0.6), cf, 0, 2.3, -hz - 0.3, rgb(30, 30, 32), M.Metal)
	for s = -1, 1, 2 do
		P(m, "Headlight", V3(1.1, 0.8, 0.1), cf, s * 3.1, 3.8, -hz - 0.1, rgb(220, 214, 180), M.SmoothPlastic)
		P(m, "TailLight", V3(1.0, 0.7, 0.1), cf, s * 3.2, 4.0, hz + 0.05, rgb(150, 20, 16), M.Neon)
	end
	local route = P(m, "RouteSign", V3(6, 0.9, 0.12), cf, 0, 9.3, -hz - 0.08, rgb(12, 12, 12), M.SmoothPlastic)
	label(route, NF.Front, "НЕ ОБСЛУЖИВАЕТСЯ", rgb(255, 140, 30), { Font = Enum.Font.Code })
	-- задняя аварийная дверь с решёткой
	P(m, "RearDoor", V3(3.4, 6.4, 0.15), cf, 0, 6.0, hz + 0.05, rgb(170, 170, 162), M.Metal)
	P(m, "RearWin", V3(2.6, 1.8, 0.1), cf, 0, 7.6, hz + 0.12, C.darkGlass, M.Glass)
	P(m, "RearBumper", V3(Wb + 0.2, 0.8, 0.6), cf, 0, 2.3, hz + 0.3, rgb(30, 30, 32), M.Metal)
	-- передняя дверь справа
	P(m, "Door", V3(0.12, 6.4, 2.8), cf, -(Wb / 2 + 0.03), 5.4, -hz + 2.4, rgb(150, 150, 144), M.Metal)
	return m
end

-- ==========================================================================
-- БУДКА ОХРАНЫ (КПП) и шлагбаум
-- ==========================================================================
local function guardBooth(parent, cf)
	local m = B.model(parent, "GuardBooth")
	local wall = rgb(166, 162, 150)
	local Wd = 8
	P(m, "Base", V3(Wd + 0.8, 0.5, Wd + 0.8), cf, 0, 0.25, 0, C.concreteDark, M.Concrete)
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			P(m, "CornerPost", V3(0.5, 8.6, 0.5), cf, sx * Wd / 2, 4.8, sz * Wd / 2, rgb(50, 52, 54), M.Metal)
		end
	end
	-- низ стен; дверь сзади (+Z)
	P(m, "LowFront", V3(Wd, 3.4, 0.4), cf, 0, 2.2, -Wd / 2, wall, M.Concrete)
	P(m, "LowL", V3(0.4, 3.4, Wd), cf, -Wd / 2, 2.2, 0, wall, M.Concrete)
	P(m, "LowR", V3(0.4, 3.4, Wd), cf, Wd / 2, 2.2, 0, wall, M.Concrete)
	P(m, "BackL", V3(2.4, 8.2, 0.4), cf, -2.8, 4.6, Wd / 2, wall, M.Concrete)
	P(m, "BackR", V3(2.4, 8.2, 0.4), cf, 2.8, 4.6, Wd / 2, wall, M.Concrete)
	P(m, "BackTop", V3(3.2, 1.2, 0.4), cf, 0, 8.1, Wd / 2, wall, M.Concrete)
	P(m, "Door", V3(3.1, 7.0, 0.2), cf, 0, 4.0, Wd / 2 + 0.05, rgb(70, 80, 84), M.Metal)
	-- стёкла по трём сторонам
	P(m, "GlassFront", V3(Wd - 0.5, 4.4, 0.15), cf, 0, 6.1, -Wd / 2, C.glass, M.Glass, { Transparency = 0.5 })
	P(m, "GlassL", V3(0.15, 4.4, Wd - 0.5), cf, -Wd / 2, 6.1, 0, C.glass, M.Glass, { Transparency = 0.5 })
	P(m, "GlassR", V3(0.15, 4.4, Wd - 0.5), cf, Wd / 2, 6.1, 0, C.glass, M.Glass, { Transparency = 0.5 })
	P(m, "Roof", V3(Wd + 2, 0.6, Wd + 2), cf, 0, 9.4, 0, rgb(46, 48, 50), M.Metal)
	local fascia = P(m, "Fascia", V3(Wd + 2, 1.0, 0.2), cf, 0, 9.2, -Wd / 2 - 1.05, rgb(20, 40, 70), M.Metal)
	label(fascia, NF.Front, "КПП · ОХРАНА", rgb(236, 236, 226))
	-- внутри: стол, монитор, стул, настольная лампа
	P(m, "Desk", V3(Wd - 1, 0.25, 2), cf, 0, 3.6, -Wd / 2 + 1.4, rgb(90, 70, 50), M.Wood)
	P(m, "DeskBody", V3(Wd - 1, 3.0, 0.3), cf, 0, 2.0, -Wd / 2 + 2.3, rgb(70, 56, 42), M.Wood)
	P(m, "Monitor", V3(1.6, 1.2, 1.0), cf, -1.5, 4.35, -Wd / 2 + 1.2, rgb(40, 40, 40), M.SmoothPlastic)
	P(m, "MonitorGlow", V3(1.3, 0.9, 0.05), cf, -1.5, 4.35, -Wd / 2 + 0.68, rgb(90, 140, 120), M.Neon)
	P(m, "Chair", V3(1.6, 0.3, 1.6), cf, 0, 2.2, 0, rgb(30, 30, 32), M.Fabric)
	P(m, "ChairBack", V3(1.6, 1.8, 0.25), cf, 0, 3.2, 0.8, rgb(30, 30, 32), M.Fabric)
	local lamp = P(m, "DeskLamp", V3(0.5, 0.4, 0.5), cf, 2, 4.2, -Wd / 2 + 1.3, rgb(255, 220, 160), M.Neon)
	B.light(lamp, "PointLight", { Color = rgb(255, 206, 150), Range = 12, Brightness = 1.4 })
	return m
end

-- шлагбаум: cf — тумба, стрела уходит в локальный +X, поднята
local function boomGate(parent, cf, len)
	local m = B.model(parent, "BoomGate")
	P(m, "Housing", V3(1.4, 3.4, 1.4), cf, 0, 1.7, 0, rgb(220, 180, 40), M.Metal)
	local pivot = cf * CF(0, 3.0, 0) * ANG(0, 0, rad(78))
	for k = 0, 4 do
		local c = (k % 2 == 0) and rgb(220, 30, 24) or rgb(236, 236, 230)
		P(m, "Arm", V3(len / 5, 0.35, 0.3), pivot, (k + 0.5) * len / 5 + 0.4, 0, 0, c, M.SmoothPlastic)
	end
	return m
end

-- доска «ПРОПАЛ РЕБЁНОК» с листовками
local function noticeBoard(parent, cf)
	local m = B.model(parent, "NoticeBoard")
	for s = -1, 1, 2 do P(m, "Leg", V3(0.35, 7, 0.35), cf, s * 3.2, 3.5, 0, rgb(70, 56, 40), M.Wood) end
	P(m, "Board", V3(7, 4, 0.3), cf, 0, 5, 0, rgb(120, 92, 62), M.Wood)
	B.part(m, "BoardRoof", V3(7.6, 0.25, 1.0), cf * CF(0, 7.2, 0) * ANG(rad(-15), 0, 0), rgb(50, 44, 38), M.Wood)
	local texts = { "ПРОПАЛ\nРЕБЁНОК", "AMBER\nALERT", "ВЫ ВИДЕЛИ\nЕЁ?", "ПРОПАЛ\nБЕЗ ВЕСТИ", "НЕ ВЫХОДИТЕ\nНОЧЬЮ" }
	for k = 1, 5 do
		local px = -2.7 + (k - 1) * 1.35
		local col = (k == 2) and rgb(255, 196, 40) or vary(rgb(226, 222, 206), 0.05)
		local poster = B.part(m, "Poster", V3(1.15, 1.6, 0.04), cf * CF(px, 5 + rr(-0.8, 0.8), -0.18) * ANG(0, 0, rad(rr(-6, 6))), col, M.SmoothPlastic)
		label(poster, NF.Front, texts[k], rgb(150, 20, 16), { Font = Enum.Font.GothamBlack })
	end
	return m
end

-- старая легковушка (длина по локальному Z)
local function sedan(parent, cf, col)
	local m = B.model(parent, "Car")
	P(m, "Body", V3(5.6, 1.7, 12), cf, 0, 2.0, 0, col, M.Metal)
	P(m, "Cabin", V3(5.0, 1.8, 6.2), cf, 0, 3.75, 0.6, C.darkGlass, M.Glass, { Transparency = 0.1, Reflectance = 0.2 })
	P(m, "Roof", V3(5.1, 0.25, 5.4), cf, 0, 4.75, 0.8, col, M.Metal)
	P(m, "Bumper", V3(5.8, 0.6, 0.4), cf, 0, 1.4, -6.1, rgb(150, 150, 146), M.Metal)
	P(m, "Bumper", V3(5.8, 0.6, 0.4), cf, 0, 1.4, 6.1, rgb(150, 150, 146), M.Metal)
	for _, wz in ipairs({ -3.8, 3.8 }) do
		for s = -1, 1, 2 do
			B.cyl(m, "Wheel", 0.9, 2.4, cf * CF(s * 2.5, 1.2, wz), rgb(22, 22, 24), B.mat("Rubber", M.SmoothPlastic))
		end
	end
	for s = -1, 1, 2 do
		P(m, "Headlight", V3(1.0, 0.5, 0.1), cf, s * 2.0, 2.2, -6.02, rgb(200, 196, 170), M.SmoothPlastic)
		P(m, "TailLight", V3(1.0, 0.5, 0.1), cf, s * 2.0, 2.2, 6.02, rgb(120, 20, 16), M.SmoothPlastic)
	end
	return m
end

-- бордюр из кусков (разный оттенок): от a до b по земле
local function kerb(parent, a, b, seg)
	local flat = V3(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	local n = math.max(1, math.ceil(len / (seg or 16)))
	for k = 0, n - 1 do
		local p0 = a + flat * (k / n)
		local p1 = a + flat * ((k + 1) / n)
		beam(parent, "Kerb", V3(p0.X, 0.35, p0.Z), V3(p1.X, 0.35, p1.Z), 0.8, 0.7, vary(C.concreteLight, 0.05), M.Concrete)
	end
end

-- ==========================================================================
-- ПЛОЩАДЬ: фонари, скамейки, урны, доска объявлений, лужи, трещины, бордюры
-- ==========================================================================
local function buildPlaza(root)
	local f = B.model(root, "Plaza")
	local sp = SPAWN_POS
	for _, p in ipairs({ V3(-47, PLAZA_Y, -46), V3(47, PLAZA_Y, -46), V3(-47, PLAZA_Y, -12), V3(47, PLAZA_Y, -12),
		V3(-47, PLAZA_Y, 20), V3(47, PLAZA_Y, 20), V3(-16, PLAZA_Y, -34), V3(16, PLAZA_Y, -34) }) do
		lampPost(f, p, sp)
	end
	for _, p in ipairs({ V3(-14, PLAZA_Y, -28), V3(14, PLAZA_Y, -28), V3(-22, PLAZA_Y, 14), V3(22, PLAZA_Y, 14) }) do
		bench(f, facing(p, sp))
		trashCan(f, p + V3((p.X > 0) and 4.5 or -4.5, 0, 0))
	end
	noticeBoard(f, facing(V3(44, PLAZA_Y, -34), sp))
	-- бетонные клумбы с сухими кустами у краёв ряда кабинок
	for s = -1, 1, 2 do
		local x = s * 40
		B.part(f, "Planter", V3(6, 1.6, 6), CF(x, PLAZA_Y + 0.8, 32), C.concrete, M.Concrete)
		B.part(f, "Soil", V3(5.2, 0.2, 5.2), CF(x, PLAZA_Y + 1.55, 32), rgb(40, 32, 26), M.Ground)
		bush(f, V3(x, PLAZA_Y + 1.6, 32), 3.2)
	end
	-- ограждения у главных ворот (воронка к проходу)
	crowdBarrier(f, B.at(-15, PLAZA_Y, -46, 20))
	crowdBarrier(f, B.at(15, PLAZA_Y, -46, -20))
	-- лужи и трещины в плитке
	puddle(f, V3(-30, PLAZA_Y, 18), 4)
	puddle(f, V3(24, PLAZA_Y, -42), 3.5)
	puddle(f, V3(6, PLAZA_Y, 16), 3)
	for k = 1, 9 do
		local p = V3(rr(-45, 45), PLAZA_Y + 0.005, rr(-48, 22))
		if (p - V3(sp.X, p.Y, sp.Z)).Magnitude > 12 then crack(f, p, rr(4, 9)) end
	end
	-- бордюры: восток и юг площади
	kerb(f, V3(50.4, 0, -52), V3(50.4, 0, 51.4), 20)
	kerb(f, V3(-50, 0, 51.4), V3(50.4, 0, 51.4), 20)
end

-- ==========================================================================
-- ПАРКОВКА: разметка, автобус, машины, лужи, выбоина с конусами
-- ==========================================================================
local function buildParking(root)
	local f = B.model(root, "Parking")
	local Y = 0.2
	local paint = B.model(f, "Paint")
	for k = 0, 18 do
		local z = -46 + 9 * k
		B.part(paint, "Line", V3(18, 0.02, 0.3), CF(-114, Y + 0.01, z), C.lineWhite, M.SmoothPlastic, { CastShadow = false })
		if z < 14 or z > 64 then
			B.part(paint, "Line", V3(18, 0.02, 0.3), CF(-68, Y + 0.01, z), C.lineWhite, M.SmoothPlastic, { CastShadow = false })
		end
	end
	-- место автобуса: жёлтая рамка и надпись
	B.part(paint, "BusBay", V3(0.35, 0.02, 50), CF(-77, Y + 0.012, 39), C.lineYellow, M.SmoothPlastic, { CastShadow = false })
	B.part(paint, "BusBay", V3(0.35, 0.02, 50), CF(-59, Y + 0.012, 39), C.lineYellow, M.SmoothPlastic, { CastShadow = false })
	B.part(paint, "BusBay", V3(18, 0.02, 0.35), CF(-68, Y + 0.012, 14), C.lineYellow, M.SmoothPlastic, { CastShadow = false })
	B.part(paint, "BusBay", V3(18, 0.02, 0.35), CF(-68, Y + 0.012, 64), C.lineYellow, M.SmoothPlastic, { CastShadow = false })
	local word = B.part(paint, "BusWord", V3(14, 0.02, 4), CF(-68, Y + 0.013, 18.5), nil, nil, { Transparency = 1, CanCollide = false, CastShadow = false })
	label(word, NF.Top, "АВТОБУС", C.lineYellow, { Font = Enum.Font.GothamBlack })
	for k = 0, 10 do
		B.part(paint, "Dash", V3(0.3, 0.02, 6), CF(-91, Y + 0.01, -40 + k * 16), C.lineYellow, M.SmoothPlastic, { CastShadow = false })
	end
	-- «зебра» перехода к площади
	for k = -2, 2 do
		B.part(paint, "Zebra", V3(7, 0.02, 1.1), CF(-58.5, Y + 0.01, k * 2.4), C.lineWhite, M.SmoothPlastic, { CastShadow = false })
	end
	-- пятна масла
	for k = 1, 6 do
		local z = -41.5 + 9 * math.floor(rr(0, 17.99))
		B.vcyl(paint, "Oil", 0.02, rr(2.5, 4), CF(rr(-117, -111), Y + 0.006, z), rgb(24, 24, 26), M.SmoothPlastic, { Transparency = 0.3, CastShadow = false })
	end
	-- бордюр между парковкой и площадью (с проходом у «зебры»)
	kerb(f, V3(-54.4, 0, -52), V3(-54.4, 0, -6.5), 16)
	kerb(f, V3(-54.4, 0, 6.5), V3(-54.4, 0, 127.5), 16)
	-- тюремный автобус и пара брошенных машин
	prisonBus(f, CF(-68, Y, 40) * ANG(0, rad(3), 0))
	sedan(f, CF(-114, Y, -41.5 + 9 * 3) * ANG(0, rad(92), 0), rgb(70, 44, 40))
	sedan(f, CF(-114, Y, -41.5 + 9 * 11) * ANG(0, rad(87), 0), rgb(52, 62, 74))
	sedan(f, CF(-68, Y, -41.5 + 9 * 2) * ANG(0, rad(-91), 0), rgb(150, 146, 132))
	-- выбоина, огороженная конусами и козлами
	B.vcyl(f, "Pothole", 0.03, 3.8, CF(-92, Y + 0.015, 60), rgb(16, 16, 18), M.Asphalt, { CastShadow = false })
	B.vcyl(f, "Pothole", 0.03, 2.4, CF(-91, Y + 0.02, 61.2), rgb(30, 26, 22), M.Ground, { CastShadow = false })
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + 0.4
		cone(f, V3(-92 + math.cos(a) * 3.6, Y, 60 + math.sin(a) * 3.6))
	end
	sawhorse(f, B.at(-92, Y, 55, 0))
	-- лужи и трещины
	puddle(f, V3(-90, Y, 10), 6)
	puddle(f, V3(-112, Y, 60), 4)
	puddle(f, V3(-82, Y, 96), 5)
	puddle(f, V3(-100, Y, -30), 4.5)
	puddle(f, V3(-64, Y, 86), 3.5)
	for k = 1, 14 do crack(f, V3(rr(-122, -58), Y + 0.005, rr(-48, 124)), rr(5, 12)) end
	-- фонари вдоль краёв
	lampPost(f, V3(-122, Y, 30), V3(-90, Y, 30))
	lampPost(f, V3(-122, Y, 110), V3(-90, Y, 110))
	lampPost(f, V3(-57, Y, 70), V3(-90, Y, 70), false)
	lampPost(f, V3(-57, Y, 110), V3(-90, Y, 110), false)
end

-- ==========================================================================
-- СКВЕР (восток) и пустырь за экраном (юг): дорожки, мёртвые деревья, кусты, скамейки
-- ==========================================================================
local function buildLawns(root)
	local f = B.model(root, "Lawns")
	local Y = 0.15
	B.part(f, "Path", V3(68, 0.1, 8), CF(84, 0.15, 0), rgb(88, 84, 76), M.Pebble)
	B.part(f, "Path", V3(8, 0.1, 176), CF(88, 0.16, 37), rgb(84, 80, 72), M.Pebble)
	bench(f, facing(V3(76, Y, 7), V3(76, Y, 0)))
	bench(f, facing(V3(104, Y, -7), V3(104, Y, 0)))
	bench(f, facing(V3(96, Y, 44), V3(88, Y, 44)))
	bench(f, facing(V3(80, Y, -40), V3(88, Y, -40)))
	trashCan(f, V3(81, Y, 7.5))
	trashCan(f, V3(96.5, Y, 50))
	lampPost(f, V3(66, Y, 6), V3(66, Y, 0))
	lampPost(f, V3(110, Y, -6), V3(110, Y, 0), false)
	lampPost(f, V3(93.5, Y, 70), V3(88, Y, 70), false)
	lampPost(f, V3(82.5, Y, -30), V3(88, Y, -30), false)
	lampPost(f, V3(-20, Y, 92), V3(0, Y, 92), false)
	-- мёртвые деревья
	local trees = { V3(70, Y, -40), V3(102, Y, -24), V3(117, Y, 18), V3(66, Y, 30), V3(106, Y, 62), V3(74, Y, 86),
		V3(114, Y, 110), V3(60, Y, 116), V3(-40, Y, 76), V3(-14, Y, 104), V3(30, Y, 82), V3(42, Y, 114), V3(-46, Y, 118),
		V3(118, Y, -40) }
	for _, p in ipairs(trees) do deadTree(f, p, rr(0.85, 1.3)) end
	-- кусты: вдоль полосы у парковки и по газонам
	for k = 0, 4 do bush(f, V3(-52, Y, -40 + k * 20 + rr(-3, 3)), rr(2.4, 3.2)) end
	for k = 1, 16 do
		local p
		if k <= 9 then p = V3(rr(56, 122), Y, rr(-46, 122)) else p = V3(rr(-48, 46), Y, rr(62, 122)) end
		if math.abs(p.X - 88) > 7 and math.abs(p.Z) > 7 then bush(f, p, rr(2.5, 4.5)) end
	end
	puddle(f, V3(70, Y, 50), 4)
end

-- ==========================================================================
-- ДВОР ЛЕЧЕБНИЦЫ: мусорные баки, бочки, кресло-каталка, щит, трещины, лужи
-- ==========================================================================
local function dumpster(parent, cf)
	local m = B.model(parent, "Dumpster")
	local c = vary(rgb(40, 70, 52), 0.08)
	P(m, "Box", V3(7, 4, 4), cf, 0, 2.4, 0, c, M.CorrodedMetal)
	B.part(m, "Lid", V3(7.2, 0.25, 4.3), cf * CF(0, 4.55, 0) * ANG(rad(-6), 0, 0), rgb(30, 30, 32), M.Plastic)
	for s = -1, 1, 2 do P(m, "Wheel", V3(0.6, 0.6, 0.6), cf, s * 3, 0.3, 1.4, rgb(20, 20, 20), M.Metal) end
	return m
end

local function wheelchair(parent, cf)
	local m = B.model(parent, "Wheelchair")
	local s = rgb(150, 152, 150)
	P(m, "Seat", V3(2, 0.25, 2), cf, 0, 2, 0, rgb(40, 40, 46), M.Fabric)
	B.part(m, "Back", V3(2, 2, 0.2), cf * CF(0, 3.1, 1.0) * ANG(rad(10), 0, 0), rgb(40, 40, 46), M.Fabric)
	for k = -1, 1, 2 do
		B.cyl(m, "BigWheel", 0.15, 2.8, cf * CF(k * 1.15, 1.4, 0.4), s, M.Metal, { Transparency = 0.1 })
		B.cyl(m, "SmallWheel", 0.15, 0.7, cf * CF(k * 0.8, 0.35, -1.0), rgb(30, 30, 30), M.Metal)
		P(m, "Handle", V3(0.12, 0.12, 0.8), cf, k * 0.9, 4.0, 1.4, s, M.Metal)
	end
	return m
end

local function buildCourtyard(root, L)
	local f = B.model(root, "Courtyard")
	local Y = PLAZA_Y
	local hx = L and L.HX or 79
	dumpster(f, facing(V3(hx + 12, Y, -82), V3(hx + 12, Y, -60)))
	dumpster(f, facing(V3(hx + 21, Y, -80), V3(hx + 21, Y, -60)) * ANG(0, rad(8), 0))
	for k = 0, 2 do
		B.vcyl(f, "Barrel", 3, 2, CF(hx + 30 + k * 2.3, Y + 1.5, -84 + (k % 2) * 1.5), vary(rgb(70, 60, 44), 0.12), M.CorrodedMetal)
	end
	wheelchair(f, facing(V3(26, Y, -64), V3(10, Y, -80)))
	-- электрощит с табличкой
	B.part(f, "Generator", V3(6, 5, 3.5), CF(-hx - 14, Y + 2.5, -64), rgb(70, 76, 64), M.CorrodedMetal)
	local warn1 = B.part(f, "GenSign", V3(2.6, 1.4, 0.05), CF(-hx - 14, Y + 3.2, -62.23), rgb(232, 196, 40), M.SmoothPlastic)
	label(warn1, NF.Back, "ОПАСНО!\n380 В", rgb(20, 20, 20))
	-- конусы у подножия лестницы и вдоль двора
	cone(f, V3(-hx - 34, Y, -78))
	cone(f, V3(-hx - 34, Y, -82))
	cone(f, V3(40, Y, -70))
	sawhorse(f, B.at(60, Y, -66, 15))
	puddle(f, V3(-20, Y, -70), 5)
	puddle(f, V3(50, Y, -78), 3.5)
	for k = 1, 8 do crack(f, V3(rr(-115, 115), Y + 0.005, rr(-80, -56)), rr(5, 12)) end
	-- холодные настенные фонари на 3 этаже фасада
	for _, x in ipairs({ -hx + 12, -hx * 0.45, hx * 0.45, hx - 12 }) do
		local lamp = B.part(f, "WallPack", V3(1.6, 1.0, 1.2), CF(x, L3 + 10.5, FACE_Z + 0.6), rgb(36, 38, 40), M.Metal)
		B.part(f, "WallPackLens", V3(1.3, 0.1, 0.9), CF(x, L3 + 9.98, FACE_Z + 0.65), C.cold, M.Neon)
		B.light(lamp, "SpotLight", { Face = NF.Bottom, Color = C.cold, Range = 40, Angle = 70, Brightness = 2.2, Shadows = false })
	end
	-- крыша: вентустановки, бак на опорах, антенна с красным огнём
	local ry = ROOF_Y + 1
	for k = -1, 1, 2 do
		B.part(f, "HVAC", V3(8, 3.5, 5), CF(k * (hx * 0.55), ry + 1.75, -110), rgb(140, 142, 140), M.Metal)
		B.vcyl(f, "Fan", 0.3, 3, CF(k * (hx * 0.55) + 1.5, ry + 3.6, -110), rgb(40, 40, 40), M.DiamondPlate)
	end
	local tx = -hx * 0.3
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			B.part(f, "TankLeg", V3(0.5, 8, 0.5), CF(tx + sx * 2.5, ry + 4, -112 + sz * 2.5), rgb(60, 50, 40), M.Wood)
		end
	end
	B.vcyl(f, "Tank", 7, 7.5, CF(tx, ry + 11.5, -112), rgb(92, 72, 54), M.WoodPlanks)
	B.vcyl(f, "TankRoof", 1, 8.2, CF(tx, ry + 15.5, -112), rgb(52, 50, 48), M.Metal)
	B.vcyl(f, "Antenna", 14, 0.35, CF(hx * 0.35, ry + 7, -115), rgb(90, 90, 92), M.Metal)
	B.ball(f, "AntennaLight", 0.6, CF(hx * 0.35, ry + 14.2, -115), rgb(255, 40, 30), M.Neon)
end

-- ==========================================================================
-- ЮЖНЫЙ ВЪЕЗД: открытые откатные ворота, шлагбаум, будка охраны, блоки, дорога в туман
-- ==========================================================================
local function buildSouthGate(root)
	local f = B.model(root, "SouthGate")
	local Y = 0.2
	local z = EDGE
	for _, x in ipairs({ -104.8, -87.2 }) do
		B.part(f, "GatePost", V3(1, 12, 1), CF(x, 6, z), rgb(90, 94, 98), M.Metal)
		B.part(f, "PostCap", V3(1.3, 0.3, 1.3), CF(x, 12.15, z), rgb(60, 62, 66), M.Metal)
	end
	-- откатная створка отъехала вдоль забора внутрь
	local gz = z - 1.3
	B.part(f, "SlideTop", V3(17, 0.35, 0.35), CF(-78.5, 10, gz), GALV, M.Metal)
	B.part(f, "SlideBottom", V3(17, 0.35, 0.35), CF(-78.5, 1.0, gz), GALV, M.Metal)
	B.part(f, "SlideMesh", V3(17, 8.6, 0.06), CF(-78.5, 5.5, gz), rgb(128, 132, 136), M.DiamondPlate, { Transparency = 0.62, CastShadow = false })
	for _, x in ipairs({ -87, -70 }) do
		B.part(f, "SlideEnd", V3(0.35, 9.4, 0.35), CF(x, 5.5, gz), GALV, M.Metal)
		B.cyl(f, "Roller", 0.3, 0.8, CF(x, 0.6, gz) * ANG(0, rad(90), 0), rgb(30, 30, 30), M.Metal)
	end
	-- дорога наружу и бетонные блоки поперёк неё
	B.part(f, "Road", V3(18, 0.2, 36), CF(-96, 0.1, z + 18), C.asphalt, M.Asphalt)
	B.part(f, "RoadLine", V3(0.3, 0.02, 34), CF(-96, 0.21, z + 18), C.lineYellow, M.SmoothPlastic, { CastShadow = false })
	for k = -1, 1 do jersey(f, B.at(-96 + k * 6.2, Y, z + 6, rr(-4, 4))) end
	sawhorse(f, B.at(-96, Y, z + 3.2, 0))
	cone(f, V3(-102, Y, z + 2.5))
	cone(f, V3(-90, Y, z + 2.2))
	cone(f, V3(-99, Y, z - 4))
	-- шлагбаум поднят, будка охраны у въезда
	boomGate(f, CF(-105.5, Y, z - 9), 15)
	guardBooth(f, facing(V3(-114, Y, z - 14), V3(-90, Y, z - 14)))
	lampPost(f, V3(-106, Y, z - 4), V3(-96, Y, z - 4))
end

-- ==========================================================================
-- ПОСТРОЙКА
-- ==========================================================================
function LobbyMap.build(parent)
	parent = parent or workspace
	seed = 20261003
	local old = parent:FindFirstChild("Lobby")
	if old then old:Destroy() end
	-- строим без родителя (быстрее), подключаем в самом конце
	local root = B.model(nil, "Lobby")
	root:SetAttribute("Kind", "Lobby")
	local lobby = { model = root, booths = {}, kiosks = {}, cells = {} }
	local inmates = inmateList()

	safe("земля", buildGround, root)
	lobby.spawn = buildSpawn(root)
	lobby.booths = buildBooths(root)
	lobby.kiosks = buildKiosks(root)
	lobby.billboard = buildBillboard(root)
	local cellsFolder = B.folder(root, "Cells")
	local L = nil
	safe("лечебница", function() L = buildAsylum(root, cellsFolder, inmates) end)
	if L then
		lobby.cells = L.cells
		safe("галерея", buildCatwalk, root, L)
	end
	safe("двор", buildCourtyard, root, L)
	safe("заборы", buildFences, root)
	safe("ворота", buildMainGate, root)
	safe("прожекторы", buildFloodlights, root)
	safe("площадь", buildPlaza, root)
	safe("парковка", buildParking, root)
	safe("сквер", buildLawns, root)
	safe("въезд", buildSouthGate, root)

	root.Parent = parent
	LobbyMap.current = lobby
	return lobby
end

function LobbyMap.init(c)
	ctx = c
end

return LobbyMap
