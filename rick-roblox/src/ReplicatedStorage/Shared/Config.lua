-- Общие настройки игры: цвета, размеры дома, звуки, тексты сюжета, настройки по умолчанию.
-- Тексты и ID звуков удобно править здесь — остальной код берёт их отсюда.
local Config = {}

Config.Version = "0.1"
Config.Title = "РИК И МОРТИ"
Config.Chapter = "ГЛАВА 1 · СБОЙ"

-- Размеры дома (в стадах). Этаж 1: пол y = 0, этаж 2: пол y = 12, высота стен 11.
Config.House = {
	Floor1 = 0, Floor2 = 12, WallH = 11,
	X0 = 0, X1 = 56, Z0 = 0, Z1 = 40,
}

-- Палитра «как в сериале»: яркие, чуть приглушённые цвета
Config.Colors = {
	Outline = Color3.fromRGB(26, 23, 32),
	Skin = Color3.fromRGB(250, 214, 178),
	MortyShirt = Color3.fromRGB(246, 214, 64),
	MortyPants = Color3.fromRGB(52, 94, 168),
	MortyHair = Color3.fromRGB(104, 62, 32),
	MortyShoes = Color3.fromRGB(235, 235, 235),
	Portal = Color3.fromRGB(120, 255, 70),
	PortalDark = Color3.fromRGB(30, 150, 40),
	PortalLight = Color3.fromRGB(225, 255, 160),
	UiLime = Color3.fromRGB(184, 240, 58),
	UiDark = Color3.fromRGB(11, 42, 18),
	UiCyan = Color3.fromRGB(44, 199, 224),
}

-- Звуки. Пустая строка — тишина (игра не ломается).
-- Музыку и общий файл эффектов загрузи в Studio (см. README, раздел «Звуки»).
Config.Sounds = {
	MusicMenu = "",          -- assets/sounds/MusicMenu.ogg
	MusicMorning = "",       -- assets/sounds/MusicMorning.ogg
	SfxAtlas = "",           -- assets/sounds/SfxAtlas.ogg — все короткие звуки в одном файле
	-- встроенные в Roblox звуки (работают без загрузки)
	Footstep = "rbxasset://sounds/action_footsteps_plastic.mp3",
	UiClick = "rbxasset://sounds/electronicpingshort.wav",
	-- двери (ID из библиотеки Roblox)
	DoorOpen = "7274931838",
	DoorClose = "6814493519",
}

-- Где какой звук лежит в SfxAtlas.ogg: { начало, конец } в секундах.
-- Таблица генерируется вместе с файлом (tools/gen_audio.py → assets/sounds/atlas.txt).
Config.Sfx = {
	Alarm = { 0.0, 1.6 },
	Click = { 2.0, 2.15 },
	Hover = { 2.4, 2.5 },
	Whoosh = { 3.0, 4.6 },
	PortalHum = { 5.0, 9.0 },
	Blink = { 9.5, 10.1 },
	Rustle = { 10.5, 11.9 },
	Step1 = { 12.5, 12.8 }, Step2 = { 13.0, 13.3 }, Step3 = { 13.5, 13.8 }, Step4 = { 14.0, 14.3 },
	AlarmOff = { 14.5, 14.8 },
	Pour = { 15.0, 17.0 },
	Milk = { 17.5, 19.5 },
	Crunch1 = { 20.0, 20.7 }, Crunch2 = { 21.0, 21.7 }, Crunch3 = { 22.0, 22.7 },
	Spoon = { 23.0, 23.4 },
	PhoneOut = { 23.8, 24.4 },
	PhoneTap = { 24.6, 24.75 },
	Swipe = { 25.0, 25.4 },
	TikTokSong = { 25.8, 33.8 },
	Glitch = { 34.2, 37.2 },
	Vibrate = { 37.6, 38.6 },
	Notify = { 39.0, 39.8 },
	Sting = { 40.2, 42.6 },
	Birds = { 43.0, 55.0 },
	Thought = { 55.5, 56.1 },
	Locked = { 56.5, 57.0 },
	Paper = { 57.4, 58.0 },
	Chair = { 58.4, 59.2 },
	-- продолжение главы
	Tentacle = { 60.0, 62.0 },
	Pull = { 62.5, 64.5 },
	Land = { 65.0, 65.8 },
	Flicker = { 66.2, 66.8 },
	Laser = { 67.2, 67.8 },
	PixelBurst = { 68.2, 69.0 },
	Burp = { 69.4, 70.6 },
	PixelAmb = { 71.0, 87.0 },
}

-- Настройки по умолчанию (меню «Настройки»)
Config.DefaultSettings = {
	Music = 0.6,          -- громкость музыки 0..1
	Sfx = 0.85,           -- громкость звуков 0..1
	Sensitivity = 1.0,    -- чувствительность мыши 0.2..2
	Fov = 72,             -- поле зрения 60..95
	HeadBob = true,       -- покачивание камеры при ходьбе
	Outlines = true,      -- чёрные контуры предметов
	Effects = 3,          -- эффекты: 1 низкие, 2 средние, 3 высокие
	Subtitles = 2,        -- размер субтитров: 1 мелкие, 2 средние, 3 крупные
	Hints = true,         -- маркер цели и подсказки
}

-- Тексты сюжета (Морти немного заикается — как в сериале)
Config.Text = {
	DayCard = "Понедельник. 7:30",
	Alarm = "[будильник пищит]",
	Wake1 = "Ммм… уже утро?",
	Wake2 = "Б-блин, опять понедельник…",
	GetUpHint = "Встать",
	AlarmObjective = "Выключи будильник",
	AlarmDone = "Фух. Т-тишина…",
	BreakfastObjective = "Спустись на кухню и позавтракай",
	Hungry = "Живот урчит. Н-надо поесть.",
	KitchenHint = "Кухня на первом этаже — по лестнице вниз",
	SitObjective = "Сядь за стол",
	PourObjective = "Насыпь хлопья",
	MilkObjective = "Налей молоко",
	EatObjective = "Позавтракай",
	Yum = "М-м… хрустят.",
	Full = "Ух, наелся.",
	PhoneObjective = "Достань телефон",
	PhoneThink = "Т-так, что там нового в ТикТоке?",
	SwipeObjective = "Листай ленту",
	Lag1 = "Ну давай, грузись…",
	WhatThe = "Б-блин, ч-что за фигня с телефоном?!",
	ToBeContinued = "ПРОДОЛЖЕНИЕ СЛЕДУЕТ…",
	ChapterEnd = "КОНЕЦ ГЛАВЫ 1",
	Thanks = "Спасибо, что поиграли!",
	-- продолжение: щупальца, пиксельный мир, Рик
	WhatIsThat = "Ч-что это такое?!",
	Scream = "А-а-а-а-а!",
	MyHands = "Ч-что со мной?!",
	WhereAmI = "Г-где я? Это что… внутри игры?",
	FindExit = "Найди выход",
	CorridorHint = "Иди вперёд по коридору",
	Creepy = "Т-тут как-то жутко…",
	NoNoNo = "Н-нет-нет-нет! Отстаньте!",
	RickArrive = "Морти! *бурп* А ну отошли от моего внука, байты-переростки!",
	MortyRick = "Р-Рик?! Т-ты как здесь оказался?",
	Rick1 = "Это цифровые паразиты, Морти. Залипнешь в телефон — и они утащат тебя к себе в сервер.",
	Rick2 = "Потом объясню. Давай в портал, пока они не *бурп* перезагрузились!",
	PortalObjective = "Беги в портал",
	-- случайные мысли у предметов
	SummerDoor = "Саммер меня убьёт, если я зайду.",
	ParentsDoor = "Мама с папой уже ушли на работу.",
	GarageDoor = "З-закрыто. Рик опять что-то мастерит…",
	FrontDoor = "Сначала позавтракаю.",
	BackDoor = "Во двор потом.",
	Computer = "П-поиграю после школы.",
	Window = "Хорошая погода. Даже жалко идти в школу.",
	Poster = "Мой любимый плакат.",
	Mirror = "Ну и причёска…",
	Tv = "Нет времени на телек.",
	Fridge = "Хм, тут записка от мамы.",
	Note = "Морти!\nХлопья и молоко на столе.\nНе опоздай в школу!\nЦелую, мама.\n\nP.S. Не буди дедушку.",
	Bed = "Н-не, второй раз я не усну.",
	Backpack = "Рюкзак. Домашку я, конечно, не сделал.",
	Clock = "Будильник. Уже тихий.",
	Toilet = "Не сейчас.",
	PhotoFamily = "Семейное фото. Дедушка тут какой-то странный.",
}

-- Задержки и скорости
Config.WalkSpeed = 12
Config.RunSpeed = 18
Config.HintDelay = 35       -- через сколько секунд без прогресса показать подсказку

return Config
