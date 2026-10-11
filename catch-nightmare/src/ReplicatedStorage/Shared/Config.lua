-- Все настройки игры в одном месте: время дня и ночи, редкости, монстры, мутации,
-- события, магазин, цены и товары за Robux. Меняй цифры здесь — код подхватит сам.
local Config = {}

Config.GameName = "Catch a Nightmare"
Config.DataStoreName = "CatchNightmare_v1"

---------------------------------------------------------------- время
Config.DaySeconds = 240        -- день
Config.NightSeconds = 180      -- ночь
Config.RestockSeconds = 300    -- обновление лавки

---------------------------------------------------------------- старт
Config.StartFear = 50
Config.StartCages = 4
Config.MaxCages = 10           -- без геймпасса
Config.PassCages = 2           -- геймпасс «+2 клетки»
Config.OfflineRate = 0.5       -- доля дохода, пока игрока нет
Config.OfflineCapSeconds = 3 * 3600

-- цена N-й клетки (первые Config.StartCages бесплатные)
Config.CagePrices = { [5] = 300, [6] = 1000, [7] = 3000, [8] = 9000, [9] = 25000, [10] = 70000, [11] = 150000, [12] = 300000 }

-- сети: уровень сети решает, каких монстров можно поймать
Config.Nets = {
	{ level = 1, name = "Сачок", price = 0, speed = 1.0 },
	{ level = 2, name = "Крепкая сеть", price = 500, speed = 0.9 },
	{ level = 3, name = "Стальная сеть", price = 5000, speed = 0.8 },
	{ level = 4, name = "Неоновая сеть", price = 50000, speed = 0.7 },
	{ level = 5, name = "Сеть Пустоты", price = 500000, speed = 0.6 },
}

---------------------------------------------------------------- редкости
-- chance — «1 к N». Ролл идёт от самой редкой: шанс = удача / N, первая удачная побеждает.
-- hold — сколько секунд держать E, net — нужный уровень сети, scare — шанс напугать за секунду рядом.
-- nightOnly — днём такие не появляются.
Config.Rarities = {
	{ key = "common", name = "Обычный", color = Color3.fromRGB(190, 190, 190), chance = 1, hold = 0.4, net = 1, scare = 0.04, speed = 7 },
	{ key = "uncommon", name = "Необычный", color = Color3.fromRGB(90, 214, 90), chance = 4, hold = 0.6, net = 1, scare = 0.06, speed = 8 },
	{ key = "rare", name = "Редкий", color = Color3.fromRGB(64, 170, 255), chance = 12, hold = 1.0, net = 2, scare = 0.1, speed = 9 },
	{ key = "epic", name = "Эпический", color = Color3.fromRGB(184, 92, 255), chance = 50, hold = 1.5, net = 3, scare = 0.16, speed = 10, nightOnly = true },
	{ key = "legendary", name = "Легендарный", color = Color3.fromRGB(255, 180, 0), chance = 300, hold = 2.0, net = 4, scare = 0.22, speed = 11, nightOnly = true },
	{ key = "mythic", name = "Мифический", color = Color3.fromRGB(255, 60, 110), chance = 3000, hold = 2.5, net = 5, scare = 0.3, speed = 12, nightOnly = true },
	{ key = "secret", name = "Секретный", color = Color3.fromRGB(255, 255, 255), chance = 60000, hold = 3.0, net = 5, scare = 0.4, speed = 13, nightOnly = true },
}
Config.RarityIndex = {}
for i, r in ipairs(Config.Rarities) do
	r.tier = i
	Config.RarityIndex[r.key] = r
end
Config.AnnounceTier = 5        -- с этой редкости поимку видит весь сервер (5 = легендарный)
Config.StealAnnounceTier = 4   -- с этой редкости весь сервер видит кражу

---------------------------------------------------------------- монстры
-- income — «Страх» в секунду. sell = income * Config.SellMul. size — высота модели (для подписи и переноски).
Config.SellMul = 40
Config.Monsters = {
	{ key = "slipper", name = "Тапок-Кусака", rarity = "common", income = 1, size = 2.5 },
	{ key = "dustbun", name = "Пыльный Бубу", rarity = "common", income = 2, size = 3 },
	{ key = "fridge", name = "Холодильник Валера", rarity = "uncommon", income = 6, size = 6 },
	{ key = "sock", name = "Носок-Призрак", rarity = "uncommon", income = 8, size = 5 },
	{ key = "wardrobe", name = "Шкаф с Глазами", rarity = "rare", income = 25, size = 7 },
	{ key = "lamp", name = "Лампа-Шептун", rarity = "rare", income = 32, size = 6 },
	{ key = "grandma", name = "Бабушка Wi-Fi", rarity = "epic", income = 110, size = 6 },
	{ key = "matryoshka", name = "Матрёшка-Паук", rarity = "epic", income = 140, size = 5 },
	{ key = "cat404", name = "Кот 404", rarity = "legendary", income = 600, size = 5 },
	{ key = "pizzademon", name = "Пицца-Демон", rarity = "legendary", income = 750, size = 6 },
	{ key = "moonhead", name = "Луноголовый", rarity = "mythic", income = 4000, size = 9 },
	{ key = "nobody", name = "Тот-Кого-Нет", rarity = "secret", income = 30000, size = 9 },
}
Config.MonsterIndex = {}
Config.MonstersByRarity = {}
for _, m in ipairs(Config.Monsters) do
	Config.MonsterIndex[m.key] = m
	local list = Config.MonstersByRarity[m.rarity]
	if not list then
		list = {}
		Config.MonstersByRarity[m.rarity] = list
	end
	table.insert(list, m)
end

---------------------------------------------------------------- мутации
-- chance — «1 к N» при появлении; mul — множитель дохода
Config.Mutations = {
	{ key = "gold", name = "Золотой", mul = 2, chance = 25, color = Color3.fromRGB(255, 205, 60) },
	{ key = "blood", name = "Кровавый", mul = 3, chance = 0, color = Color3.fromRGB(190, 10, 30) },   -- только в Кровавую луну
	{ key = "glitch", name = "Глитч", mul = 5, chance = 250, color = Color3.fromRGB(170, 60, 255) },
}
Config.MutationIndex = {}
for _, m in ipairs(Config.Mutations) do Config.MutationIndex[m.key] = m end

---------------------------------------------------------------- события ночи
-- выпадают в начале ночи: weight — вес (из 100), остальное — обычная ночь
Config.Events = {
	{ key = "bloodmoon", name = "КРОВАВАЯ ЛУНА", text = "удача ×3, кровавые мутации", weight = 18, luck = 3, color = Color3.fromRGB(255, 50, 50) },
	{ key = "glitch", name = "ГЛИТЧ-НОЧЬ", text = "глитч-мутации ×25", weight = 10, luck = 1.5, color = Color3.fromRGB(180, 80, 255) },
	{ key = "fog", name = "ТУМАН", text = "монстров больше, но их почти не видно", weight = 15, luck = 1.2, color = Color3.fromRGB(170, 180, 200) },
}
Config.EventIndex = {}
for _, e in ipairs(Config.Events) do Config.EventIndex[e.key] = e end
Config.BloodMutationChance = 3    -- в Кровавую луну «1 к 3» станет кровавым
Config.GlitchNightMul = 25        -- в Глитч-ночь глитч в 25 раз чаще

---------------------------------------------------------------- дикие монстры
Config.Wild = {
	DayInterval = 7, DayMax = 8,         -- днём редко и только до «Редкого»
	NightInterval = 2.4, NightMax = 22,
	FogBonus = 6,                        -- в туман можно на столько больше монстров
	LifeMin = 80, LifeMax = 140,         -- через сколько секунд монстр убегает
	ScareRange = 10, ScareCooldown = 6, StunSeconds = 1.3,
	ReserveSeconds = 12,                 -- монстр из приманки — только для хозяина приманки
	FirstCatchHelp = true,               -- новичку у базы появляется лёгкий монстр
}

---------------------------------------------------------------- переноска и кража
Config.CarrySpeed = 12          -- скорость с монстром на голове (обычная — 16)
Config.CarryRareSpeed = 10      -- с эпическим и выше
Config.TackleHold = 0.5         -- держать E, чтобы отобрать монстра у игрока
Config.TackleImmunity = 3       -- после отбора столько секунд нельзя отобрать снова
Config.StealHold = 1.8          -- держать E, чтобы утащить монстра из чужой клетки
Config.SellHold = 1.0
Config.LockSeconds = 60         -- замок базы

---------------------------------------------------------------- лавка
-- приманки: luck — множитель удачи, gold — во сколько раз чаще золотые, inStock — шанс появиться в лавке
Config.Baits = {
	{ key = "bait", name = "Приманка", price = 100, luck = 1.5, inStock = 1, min = 3, max = 8, icon = "🍖" },
	{ key = "golden", name = "Золотая приманка", price = 2500, luck = 4, gold = 5, inStock = 0.6, min = 1, max = 3, icon = "✨" },
	{ key = "blood", name = "Кровавая приманка", price = 25000, luck = 12, blood = true, inStock = 0.2, min = 1, max = 1, icon = "🩸" },
	{ key = "void", name = "Приманка Пустоты", price = 250000, luck = 40, inStock = 0.05, min = 1, max = 1, icon = "🕳" },
}
Config.BaitIndex = {}
for _, b in ipairs(Config.Baits) do Config.BaitIndex[b.key] = b end
Config.BaitDelay = 3            -- через сколько секунд из приманки вылезает монстр

---------------------------------------------------------------- Robux
-- Впиши ID из Creator Hub (Monetization). 0 — товар выключен.
Config.Products = {
	ServerLuck = { id = 0, name = "Удача ×2 для всего сервера", minutes = 15, robux = 49 },
}
Config.Passes = {
	DoubleFear = { id = 0, name = "×2 Страха навсегда", robux = 199 },
	ExtraCages = { id = 0, name = "+2 клетки", robux = 149 },
}

-- админы (UserId) для команд /night, /bloodmoon ... В Studio и у владельца игры работают всегда.
Config.Admins = {}

---------------------------------------------------------------- звуки
-- Встроенные звуки Roblox (rbxasset://) работают сразу. Свои — впиши цифры ID.
Config.Sounds = {
	Catch = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/button.wav",
	Whoosh = "rbxasset://sounds/swoosh.wav",
	Scream = "rbxasset://sounds/uuhhh.mp3",
	Alarm = "rbxasset://sounds/clickfast.wav",
	Cash = "rbxasset://sounds/electronicpingshort.wav",
	NightStart = "",
	DayStart = "",
	Jumpscare = "",
}

---------------------------------------------------------------- карта
Config.Map = {
	BaseCount = 8,
	BaseRadius = 262,      -- центры баз от центра карты
	BaseSize = 64,         -- квадрат базы
	WallHeight = 14,
	SafeRadius = 32,       -- поляна с костром: монстры не подходят
	ForestMin = 44, ForestMax = 192,
}

return Config
