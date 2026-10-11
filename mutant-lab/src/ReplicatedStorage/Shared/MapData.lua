-- Описание карты «Mutant Lab»: где что стоит, уровни земли, цены зон, атмосфера.
-- Общий модуль: сервер строит по нему карту, клиент — определяет, в какой зоне игрок.
--
-- Оси: север = −Z (туда идут зоны), восток = +X (арена босса), юг = +Z (лаборатории игроков),
-- запад = −X (башня ребёрта). Земля в центре — на высоте 0.
local D = {}

D.SEA = -3              -- уровень моря
D.HUB_R = 80            -- радиус центральной площади
D.ZONE_HALF_W = 120     -- зоны идут коридором шириной 240 (x от −120 до 120)

-- Зоны собирательства: z0 — южная граница (вход), z1 — северная, level — высота земли
D.Zones = {
	{ id = "Mushroom", title = "ГРИБНОЙ ЛЕС", name = "Грибной лес", z0 = -170, z1 = -370, level = 0, price = 0,
		accent = Color3.fromRGB(190, 110, 255) },
	{ id = "Swamp", title = "СЛИЗИСТОЕ БОЛОТО", name = "Слизистое болото", z0 = -370, z1 = -570, level = 6, price = 1000,
		accent = Color3.fromRGB(120, 255, 80) },
	{ id = "Crystal", title = "КРИСТАЛЬНЫЕ ПЕЩЕРЫ", name = "Кристальные пещеры", z0 = -570, z1 = -770, level = 12, price = 15000,
		accent = Color3.fromRGB(90, 220, 255) },
	{ id = "Junkyard", title = "СВАЛКА РОБОТОВ", name = "Свалка роботов", z0 = -770, z1 = -970, level = 18, price = 200000,
		accent = Color3.fromRGB(255, 170, 60) },
	{ id = "Crater", title = "РАДИОАКТИВНЫЙ КРАТЕР", name = "Радиоактивный кратер", z0 = -970, z1 = -1170, level = 24, price = 3000000,
		accent = Color3.fromRGB(170, 255, 40) },
}
D.ZoneById = {}
for i, z in ipairs(D.Zones) do
	z.index = i
	D.ZoneById[z.id] = z
end

-- Лаборатории игроков: дуга к югу от площади
D.Plots = { count = 6, radius = 175, spread = 112, size = 54 }

-- Остров босса за рекой (восток) и башня ребёрта (запад)
D.Boss = { center = Vector3.new(310, 0, 0), radius = 55 }
D.River = { x = 215, width = 24, zTurn = -100 }
D.Rebirth = { center = Vector3.new(-215, 0, 0) }
D.Ufo = { center = Vector3.new(-250, 0, 205) }

-- Суша: прямоугольники { x0, x1, z0, z1 } (центральный остров и коридор зон)
D.Island = {
	{ -340, 420, -130, 330 },
	{ -175, 175, -1200, -60 },
}

-- Атмосфера по областям (клиент плавно переключает при переходе)
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
D.Ambience = {
	Hub = { density = 0.27, haze = 1.2, color = rgb(205, 228, 220), decay = rgb(120, 170, 150), glare = 0.2,
		tint = rgb(255, 255, 255), saturation = 0.15, contrast = 0.05, brightness = 0 },
	Mushroom = { density = 0.32, haze = 1.8, color = rgb(222, 200, 255), decay = rgb(150, 105, 205), glare = 0.1,
		tint = rgb(252, 244, 255), saturation = 0.25, contrast = 0.05, brightness = 0 },
	Swamp = { density = 0.46, haze = 3, color = rgb(175, 212, 145), decay = rgb(80, 120, 60), glare = 0,
		tint = rgb(236, 255, 226), saturation = 0.1, contrast = 0.06, brightness = -0.03 },
	Crystal = { density = 0.42, haze = 2, color = rgb(145, 175, 235), decay = rgb(60, 72, 140), glare = 0.3,
		tint = rgb(218, 232, 255), saturation = 0.22, contrast = 0.1, brightness = -0.06 },
	Junkyard = { density = 0.38, haze = 2.6, color = rgb(232, 205, 165), decay = rgb(150, 112, 72), glare = 0.2,
		tint = rgb(255, 246, 228), saturation = -0.05, contrast = 0.08, brightness = 0 },
	Crater = { density = 0.46, haze = 2.6, color = rgb(205, 240, 145), decay = rgb(100, 140, 40), glare = 0.1,
		tint = rgb(236, 255, 212), saturation = 0.15, contrast = 0.12, brightness = -0.04 },
	Boss = { density = 0.33, haze = 1.6, color = rgb(235, 190, 190), decay = rgb(145, 75, 75), glare = 0.2,
		tint = rgb(255, 242, 242), saturation = 0.2, contrast = 0.1, brightness = 0 },
	Rebirth = { density = 0.3, haze = 1.6, color = rgb(222, 200, 255), decay = rgb(130, 90, 190), glare = 0.3,
		tint = rgb(248, 240, 255), saturation = 0.2, contrast = 0.06, brightness = 0 },
}

-- Названия областей для всплывающей надписи
D.AreaNames = {
	Hub = "Лаб-Сити", Plots = "Лаборатории", Boss = "Арена босса", Rebirth = "Башня ребёрта",
}
for _, z in ipairs(D.Zones) do D.AreaNames[z.id] = z.name end

local function flatDist(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- В какой области точка: возвращает ключ ("Hub", "Mushroom", ...) и ключ атмосферы
function D.areaAt(pos)
	if math.abs(pos.X) < D.ZONE_HALF_W + 40 then
		for _, z in ipairs(D.Zones) do
			if pos.Z <= z.z0 and pos.Z > z.z1 then return z.id, z.id end
		end
	end
	if flatDist(pos, D.Boss.center) < D.Boss.radius + 30 then return "Boss", "Boss" end
	if flatDist(pos, D.Rebirth.center) < 45 then return "Rebirth", "Rebirth" end
	local r = flatDist(pos, Vector3.zero)
	if r < D.HUB_R + 6 then return "Hub", "Hub" end
	if pos.Z > 60 and r > D.Plots.radius - 45 and r < D.Plots.radius + 45 then return "Plots", "Hub" end
	return "Wild", "Hub"
end

-- Высота земли зоны (для расстановки предметов)
function D.levelAt(z)
	for _, zone in ipairs(D.Zones) do
		if z <= zone.z0 and z > zone.z1 then return zone.level end
	end
	if z <= D.Zones[#D.Zones].z1 then return D.Zones[#D.Zones].level end
	return 0
end

return D
