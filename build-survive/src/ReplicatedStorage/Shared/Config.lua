-- Общие настройки игры. Всё, что можно поменять без программирования, — здесь.
local Config = {}

Config.GameName = "BUILD & SURVIVE"
Config.GameNameRu = "Построй и выживи"
Config.Version = "1.0"

-- Строительство
Config.PlotSize = Vector3.new(64, 96, 64) -- ширина, высота, длина зоны строительства (в стадах)
Config.MaxBlocks = 1500                   -- лимит блоков на одном участке
Config.MaxBlockSize = 16                  -- максимальный размер блока по одной оси
Config.DefaultBlockSize = Vector3.new(2, 2, 2)
Config.UndoDepth = 60
Config.PlaceCooldown = 0.045              -- антиспам на сервере (сек)
Config.HoldDelay = 0.35                   -- зажатая кнопка мыши: через сколько секунд начинается протяжка
Config.HoldRepeat = 0.12                  -- протяжка: пауза между блоками (сек)

-- Экономика
Config.StartGold = 500
Config.DailyBonus = 150
Config.GoldPerWave = 15                   -- золото за волну = GoldPerWave * номер волны * множитель сложности

-- Сохранения
Config.DataStoreName = "BuildSurvive_v1"
Config.AutosaveInterval = 120
Config.SaveSlots = 3

-- Разрушения
Config.DebrisLimit = 160                  -- сколько обломков может лететь одновременно
Config.DebrisLifetime = 5
Config.CharredColor = Color3.fromRGB(28, 22, 18)

-- Осада
Config.Siege = {
	CountdownTime = 4,
	BreakBetweenWaves = 4,
	LeavePlotGrace = 4,          -- сколько секунд можно стоять вне участка
	RangeCooldown = 0.35,        -- полигон: пауза между выстрелами
	RangeHeavyCooldown = 6,      -- полигон: пауза после ядерки/лазера/баллистики
	MaxProjectiles = 140,
}

Config.Difficulties = {
	{ key = "Easy", name = "Лёгкая", damage = 0.6, rate = 0.75, gold = 0.6, color = Color3.fromRGB(90, 200, 120) },
	{ key = "Normal", name = "Нормальная", damage = 1.0, rate = 1.0, gold = 1.0, color = Color3.fromRGB(255, 196, 64) },
	{ key = "Hard", name = "Хардкор", damage = 1.4, rate = 1.3, gold = 1.6, color = Color3.fromRGB(255, 120, 50) },
	{ key = "Apocalypse", name = "Апокалипсис", damage = 2.0, rate = 1.7, gold = 2.5, color = Color3.fromRGB(235, 60, 60) },
}

-- Испытания (запуск постройки)
Config.Launch = {
	WheelSpeed = 22,       -- рад/с
	WheelTorque = 60000,
	ThrusterForce = 9000,
	BalloonLift = 30,      -- сколько единиц массы поднимает один шар (деревянный блок 2×2×2 весит 4)
}

-- Цвета палитры (покраска)
Config.Palette = {
	Color3.fromRGB(245, 245, 245), Color3.fromRGB(190, 190, 195), Color3.fromRGB(120, 122, 128), Color3.fromRGB(60, 62, 68), Color3.fromRGB(22, 23, 26),
	Color3.fromRGB(235, 64, 52), Color3.fromRGB(176, 32, 40), Color3.fromRGB(255, 136, 40), Color3.fromRGB(255, 196, 40), Color3.fromRGB(255, 236, 120),
	Color3.fromRGB(130, 210, 70), Color3.fromRGB(52, 150, 70), Color3.fromRGB(26, 90, 56), Color3.fromRGB(64, 200, 190), Color3.fromRGB(40, 140, 220),
	Color3.fromRGB(30, 70, 170), Color3.fromRGB(120, 80, 220), Color3.fromRGB(190, 70, 210), Color3.fromRGB(255, 120, 190), Color3.fromRGB(255, 205, 170),
	Color3.fromRGB(196, 140, 90), Color3.fromRGB(140, 92, 56), Color3.fromRGB(92, 60, 38), Color3.fromRGB(210, 190, 140), Color3.fromRGB(108, 120, 80),
}

-- Цвета команд/участков (как в Build a Boat — у каждого участка свой цвет)
Config.PlotColors = {
	{ name = "Красный", color = Color3.fromRGB(226, 64, 64) },
	{ name = "Синий", color = Color3.fromRGB(56, 128, 236) },
	{ name = "Зелёный", color = Color3.fromRGB(64, 196, 96) },
	{ name = "Жёлтый", color = Color3.fromRGB(246, 200, 50) },
	{ name = "Фиолетовый", color = Color3.fromRGB(160, 84, 230) },
	{ name = "Оранжевый", color = Color3.fromRGB(250, 132, 40) },
}

-- Графика по умолчанию (игрок может поменять в настройках)
Config.DefaultSettings = {
	Music = 0.5,
	Sfx = 1,
	Graphics = 3, -- 1 низкая, 2 средняя, 3 ультра
	CameraShake = true,
	ShowGrid = true,
}

return Config
