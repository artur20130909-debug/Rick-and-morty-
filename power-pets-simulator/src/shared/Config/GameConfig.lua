--[[
	GameConfig — общие настройки и баланс игры.
	Все числа можно менять здесь: сервер и клиент читают один и тот же модуль.
]]

local GameConfig = {}

GameConfig.GameName = "Power Pets Simulator"

-- Сохранение ---------------------------------------------------------------
-- Если поменять имя хранилища, у всех игроков начнётся новый прогресс.
GameConfig.DataStoreName = "PowerPetsSimulator_v1"
GameConfig.AutosaveInterval = 60 -- секунд между автосохранениями

-- Клики ----------------------------------------------------------------------
GameConfig.BaseClickPower = 1 -- сила за один клик без бонусов
GameConfig.MaxClicksPerSecond = 15 -- сервер не засчитывает клики сверх этого (защита от автокликеров)

-- Питомцы --------------------------------------------------------------------
GameConfig.MaxPets = 150 -- размер инвентаря
GameConfig.BaseEquipSlots = 3 -- сколько питомцев можно надеть без геймпасса
GameConfig.GamepassEquipSlots = 5 -- сколько можно надеть с геймпассом
GameConfig.GoldenMergeCount = 5 -- сколько одинаковых питомцев сливаются в одного золотого
GameConfig.GoldenMultiplier = 2 -- золотой питомец даёт множитель ×2 к своему обычному

-- Геймпасс «+2 слота питомцев».
-- 0 = заглушка: кнопка в магазине выдаёт слоты бесплатно (удобно для тестов).
-- Создай геймпасс на create.roblox.com и впиши сюда его ID — тогда будет настоящая покупка за Robux.
GameConfig.PetSlotsGamepassId = 0

-- Яйца -----------------------------------------------------------------------
GameConfig.EggOpenDistance = 16 -- с какого расстояния сервер разрешает открыть яйцо
GameConfig.EggOpenCooldown = 0.6 -- пауза между открытиями одного игрока (секунды)
GameConfig.MultiOpenCount = 3 -- вторая кнопка у яйца: «Открыть ×3»

-- Перерождение ---------------------------------------------------------------
GameConfig.RebirthBonus = 0.5 -- +50% к силе за каждое перерождение
GameConfig.RebirthBaseCost = 50000 -- сколько накопленной силы нужно для первого перерождения
GameConfig.RebirthCostGrowth = 3 -- во сколько раз дорожает каждое следующее перерождение

-- Мир ------------------------------------------------------------------------
GameConfig.StartWorld = "Forest"
GameConfig.SellRadius = 9 -- радиус точки продажи (в стадах)
GameConfig.CoinRespawnTime = 12 -- через сколько секунд появляется новая монета
GameConfig.BigCoinChance = 0.1 -- шанс большой монеты
GameConfig.BigCoinMultiplier = 5 -- во сколько раз большая монета дороже
-- Удалить стандартные Baseplate и SpawnLocation из шаблона Studio: карта строится кодом.
GameConfig.RemoveTemplateBaseplate = true

return GameConfig
