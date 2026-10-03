-- Настройки и данные игры (общие для сервера и клиента).
-- Звуки и картинки: вставь ID из Roblox (только цифры). Пустая строка — звук/картинка просто не используется.
local Config = {}

Config.GameName = "AMBER ALERT"
Config.MaxPlayersPerHouse = 4
Config.BoothCountdown = 15          -- секунд в кабинке до старта
Config.MaxApplesCarried = 14
Config.AppleGrowSeconds = 18        -- раз в столько секунд на каждом дереве прибавляется яблоко (разбрызгиватель — вдвое быстрее)
Config.TreeMaxApples = 4
Config.DawnBonus = 40               -- $ каждому на рассвете
Config.KillBounty = 120             -- $ за обезвреженного заключённого
Config.StaminaMax = 100
Config.FlashlightSeconds = 150      -- на сколько хватает батарейки
Config.WalkSpeed, Config.SprintSpeed, Config.CrouchSpeed = 12, 20, 6

-- время суток в часах: день 7:00 → 21:00 (оповещение) → ночь до 31:00 (= 7:00 следующего дня)
Config.Time = { dayStart = 7, alertAt = 21, nightEnd = 31, alertSeconds = 34, dawnSeconds = 7, loadingSeconds = 3 }

Config.Difficulties = {
	easy    = { order = 1, name = "Лёгкая",      nights = 5,    applePrice = 18, daySeconds = 150, nightSeconds = 150, hpMul = 0.9,  tier = 1, amber = 40,  xp = 60 },
	normal  = { order = 2, name = "Средняя",     nights = 7,    applePrice = 25, daySeconds = 140, nightSeconds = 165, hpMul = 1,    tier = 2, amber = 90,  xp = 120 },
	hard    = { order = 3, name = "Сложная",     nights = 10,   applePrice = 37, daySeconds = 130, nightSeconds = 180, hpMul = 1.15, tier = 3, amber = 180, xp = 220 },
	endless = { order = 4, name = "Бесконечная", nights = 9999, applePrice = 30, daySeconds = 130, nightSeconds = 170, hpMul = 1,    tier = 3, amber = 0,   xp = 40, endless = true },
}

-- предметы магазина в гараже (покупаются днём за $)
Config.Items = {
	battery   = { order = 1,  name = "Батарейки",          icon = "🔋", price = 25,  desc = "Полный заряд фонарика." },
	medkit    = { order = 2,  name = "Аптечка",            icon = "🩹", price = 50,  desc = "+60 здоровья.", heal = 60 },
	pepper    = { order = 3,  name = "Перцовый баллончик", icon = "🧯", price = 60,  desc = "Оглушает вблизи на 3 с. 3 заряда.", charges = 3, stun = 3, range = 10 },
	beartrap  = { order = 4,  name = "Капкан",             icon = "🪤", price = 70,  desc = "Ставится на пол и держит заключённого 6 с.", stun = 6 },
	motion    = { order = 5,  name = "Лампа с датчиком",   icon = "💡", price = 65,  desc = "Ставится на пол и загорается, когда рядом кто-то есть." },
	stun      = { order = 6,  name = "Электрошокер",       icon = "⚡", price = 130, desc = "Оглушает на 4 с. Перезарядка 20 с.", stun = 4, range = 8, cooldown = 20 },
	defib     = { order = 7,  name = "Дефибриллятор",      icon = "💓", price = 200, desc = "Оживить товарища у его тела." },
	shotgun   = { order = 8,  name = "Дробовик",           icon = "🔫", price = 260, desc = "Урон заключённым. В комплекте 4 патрона.", damage = 60, range = 90, ammo = 4 },
	shells    = { order = 9,  name = "Патроны ×4",         icon = "🧨", price = 45,  desc = "Для дробовика.", gives = "shells", count = 4 },
	tree      = { order = 10, name = "Яблоня",             icon = "🌳", price = 150, desc = "Ещё одно дерево во дворе.", farm = true },
	sprinkler = { order = 11, name = "Разбрызгиватель",    icon = "💦", price = 120, desc = "Яблоки растут вдвое быстрее.", farm = true },
}

-- классы покупаются в лобби за Amber
Config.Classes = {
	novice   = { order = 1, name = "Новичок",  price = 0,   icon = "🙂", desc = "Фонарик. Ничего лишнего.", items = {} },
	farmer   = { order = 2, name = "Фермер",   price = 120, icon = "🧑‍🌾", desc = "Срывает по 2 яблока и начинает с $60.", items = {}, money = 60 },
	hunter   = { order = 3, name = "Охотник",  price = 250, icon = "🎯", desc = "Начинает с дробовиком.", items = { shotgun = 1, shells = 4 } },
	medic    = { order = 4, name = "Медик",    price = 220, icon = "⛑", desc = "Начинает с дефибриллятором и аптечкой.", items = { defib = 1, medkit = 1 } },
	electric = { order = 5, name = "Электрик", price = 160, icon = "🔌", desc = "Фонарь горит вдвое дольше, щиток включает мгновенно.", items = { battery = 1 } },
	runner   = { order = 6, name = "Бегун",    price = 160, icon = "👟", desc = "Выносливость +60%.", items = {} },
}

Config.Ranks = { "Recruit", "Documented", "Field Operative", "Cleared Personnel", "Containment Unit", "Research Unit",
	"Anomalous Specialist", "Black Ridge Operator", "Classified", "Amber Alert" }
Config.XpPerLevel = 200
function Config.levelOf(xp) return math.floor((xp or 0) / Config.XpPerLevel) + 1 end
function Config.rankOf(level) return Config.Ranks[math.clamp(math.floor(((level or 1) - 1) / 3) + 1, 1, #Config.Ranks)] end

-- текст экстренного оповещения (первая строка всегда одна и та же)
Config.AlertHead = "ГРАЖДАНСКИЕ ВЛАСТИ ОБЪЯВИЛИ ЧРЕЗВЫЧАЙНУЮ СИТУАЦИЮ В ВАШЕМ РАЙОНЕ."
Config.AlertUnknown = {
	"МЫ ПОЛУЧАЕМ СООБЩЕНИЯ О НАРУШЕНИИ ПЕРИМЕТРА В ЛЕЧЕБНИЦЕ BLACK RIDGE.",
	"ОДИН ЗАКЛЮЧЁННЫЙ НЕ НАЙДЕН. ЕГО ИМЯ, КЛАССИФИКАЦИЯ И УРОВЕНЬ УГРОЗЫ — НЕИЗВЕСТНЫ. СИЛЬНАЯ ПОТЕРЯ СИГНАЛА.",
	"ГРАЖДАНАМ РЕКОМЕНДУЕТСЯ ОСТАВАТЬСЯ В ПОМЕЩЕНИИ ДО ПОЛУЧЕНИЯ НОВОЙ ИНФОРМАЦИИ.",
}

-- Звуки. Ключ -> ID в Roblox. Сгенерированные файлы лежат в assets/sounds (см. assets/MANIFEST.md).
-- Загрузи их: Studio → View → Asset Manager → Bulk Import, затем ПКМ по звуку → Copy ID.
Config.Sounds = {
	EasTone = "", EasNoise = "", Static = "", TvNews = "",
	DoorOpen = "", DoorClose = "", DoorLock = "", DoorBash = "", DoorBreak = "",
	GlassBreak = "", Footstep = "rbxasset://sounds/action_footsteps_plastic.mp3", FlashlightClick = "",
	ApplePick = "", Coin = "", PowerDown = "", PowerUp = "", Fuse = "",
	Shotgun = "", Pepper = "", Stun = "", TrapSnap = "", Heal = "", Defib = "",
	Jumpscare = "", Heartbeat = "", Breath = "", Whisper = "",
	AmbientLobby = "", AmbientDay = "", AmbientNight = "", AmbientHouse = "", Wind = "", Crickets = "",
	Stinger = "", Dawn = "", Win = "", Lose = "", UiClick = "rbxasset://sounds/electronicpingshort.wav", UiHover = "",
}

-- Картинки (Decal/Texture). Ключ -> ID. Сгенерированные файлы — assets/images.
Config.Images = {
	WallpaperLiving = "", WallpaperBedroom = "", WallpaperKids = "", KitchenTiles = "", BathTiles = "",
	Carpet = "", WoodFloor = "", Ceiling = "", Siding = "", RoofShingles = "",
	EasLogo = "", BlackRidgeLogo = "", Poster1 = "", Poster2 = "", Poster3 = "", FamilyPhoto = "",
	TvStatic = "", Vignette = "", Grain = "",
}

return Config
