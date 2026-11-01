-- Настройки игры «Мой iPhone Duo». Этот модуль читают и сервер, и клиент.
local Config = {}

Config.ToolName = "iPhone Duo"

-- Как телефон лежит в руке. Если в руке он стоит криво — поменяй цифры:
-- Y — выше/ниже, X — левее/правее.
Config.Grip = CFrame.new(0, -0.45, 0)

-- Батарея (в процентах)
Config.Battery = {
	Start = 100,
	IdleDrain = 0.05, -- в секунду, когда телефон просто в руке
	FlashlightDrain = 0.35, -- дополнительно, пока горит фонарик
	MusicDrain = 0.25, -- дополнительно, пока играет музыка
	ChargeRate = 6, -- в секунду на зарядной станции
	ChargeRadius = 7, -- в стадах от центра зарядки
}

-- Турбо-бег
Config.Turbo = { Speed = 42, Duration = 8, Cooldown = 20, Cost = 8 }

-- Цвета корпуса (меняются в приложении «Цвет», видят все игроки)
Config.Colors = {
	{ Name = "Натуральный титан", Color = Color3.fromRGB(190, 184, 172) },
	{ Name = "Космический чёрный", Color = Color3.fromRGB(45, 45, 50) },
	{ Name = "Небесно-голубой", Color = Color3.fromRGB(120, 170, 220) },
	{ Name = "Розовое золото", Color = Color3.fromRGB(232, 178, 160) },
	{ Name = "Мятный", Color = Color3.fromRGB(150, 215, 185) },
	{ Name = "Фиолетовый", Color = Color3.fromRGB(150, 110, 200) },
	{ Name = "Красный (PRODUCT)", Color = Color3.fromRGB(200, 40, 50) },
	{ Name = "Золотой", Color = Color3.fromRGB(230, 195, 110) },
}

-- Обои экрана (только у тебя)
Config.Wallpapers = {
	{ Name = "Закат", A = Color3.fromRGB(255, 120, 90), B = Color3.fromRGB(120, 60, 200) },
	{ Name = "Океан", A = Color3.fromRGB(40, 180, 230), B = Color3.fromRGB(20, 40, 120) },
	{ Name = "Лес", A = Color3.fromRGB(120, 210, 120), B = Color3.fromRGB(20, 80, 60) },
	{ Name = "Ночь", A = Color3.fromRGB(60, 60, 90), B = Color3.fromRGB(10, 10, 20) },
	{ Name = "Конфета", A = Color3.fromRGB(255, 160, 210), B = Color3.fromRGB(150, 200, 255) },
}

-- Места для приложения «Карта». Позиции совпадают с картой из MapBuilder.
Config.Locations = {
	{ Name = "Спавн", Icon = "🏠", Position = Vector3.new(0, 4, 0) },
	{ Name = "Магазин Duo", Icon = "🛍️", Position = Vector3.new(0, 4, -70) },
	{ Name = "Крыша башни", Icon = "🗼", Position = Vector3.new(74, 64, 34) },
	{ Name = "Пляж", Icon = "🏖️", Position = Vector3.new(-90, 4, 60) },
	{ Name = "Парк", Icon = "🌳", Position = Vector3.new(70, 4, -40) },
}

-- Зарядные станции (позиции центра)
Config.Chargers = {
	Vector3.new(14, 0.6, 10),
	Vector3.new(-14, 0.6, -54),
	Vector3.new(86, 61.2, 46),
}

-- Музыка. Roblox часто закрывает звуки авторов, поэтому, если трек молчит,
-- найди другой в Toolbox → Audio и впиши его цифры сюда или прямо в приложение.
Config.Music = {
	{ Name = "Relaxed Scene", Id = "1848354536" },
	{ Name = "Time To Relax", Id = "9044702906" },
	{ Name = "Трек 3", Id = "1837849285" },
}
Config.MusicVolume = 0.5

-- Встроенные звуки Roblox (работают всегда)
Config.Sounds = {
	Click = "rbxasset://sounds/electronicpingshort.wav",
	Ring = "rbxasset://sounds/electronicpingshort.wav",
	Shutter = "rbxasset://sounds/swoosh.wav",
	Notify = "rbxasset://sounds/electronicpingshort.wav",
}

-- Сутки в игре: сколько реальных минут длится один игровой день
Config.DayLengthMinutes = 10

-- Сообщения
Config.MessageMaxLength = 120
Config.MessageCooldown = 2
Config.CallCooldown = 6

-- Мини-игра «Тап-тап»
Config.TapGameSeconds = 15

return Config
