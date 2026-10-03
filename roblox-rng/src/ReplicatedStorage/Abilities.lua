-- Способности и персонажи: редкость, шанс «1 к N», урон, перезарядка, награда за выпадение.
-- Общий модуль: его читают и сервер (ролл, бой), и клиент (интерфейс).
local Abilities = {}

-- настройки игры
Abilities.Config = {
	ConfirmChance = 25,      -- если твоя способность «1 к 25» или реже — перед роллом спросим «точно крутить?»
	KillCoins = 10,          -- монеты за сбитого игрока
	DummyCoins = 2,          -- монеты за сбитый манекен
	-- песня ульты Рю — LARPZO из JJS, играет двумя слоями сразу (как в JJS): музыка + вокал «Let's larp».
	-- Если в Output пишет, что звук не загрузился (нет доступа) — найди другой в Toolbox → Audio
	-- или загрузи свой mp3 и впиши сюда его цифры. Пустой список — без песни.
	RyuSong = {
		"137364280179144",   -- Awakening AIZO / LARPZO: инструментал
		"73905683100406",    -- LARPZO: вокал
	},
	RyuSongVolume = 1,
}

Abilities.Rarities = {
	common    = { name = "Обычная",     color = Color3.fromRGB(200, 205, 215), order = 1, coins = 2 },
	uncommon  = { name = "Необычная",   color = Color3.fromRGB(90, 225, 110),  order = 2, coins = 5 },
	rare      = { name = "Редкая",      color = Color3.fromRGB(70, 155, 255),  order = 3, coins = 15 },
	epic      = { name = "Эпическая",   color = Color3.fromRGB(185, 95, 255),  order = 4, coins = 40 },
	legendary = { name = "Легендарная", color = Color3.fromRGB(255, 200, 40),  order = 5, coins = 120 },
	mythic    = { name = "Мифическая",  color = Color3.fromRGB(255, 60, 95),   order = 6, coins = 400 },
	secret    = { name = "СЕКРЕТНАЯ",   color = Color3.fromRGB(255, 255, 255), order = 7, coins = 1000 },
}

Abilities.List = {
	{ id = "Fire",      name = "Огонь",      icon = "🔥", rarity = "common",    chance = 2,    cooldown = 2.5, damage = 12, color = Color3.fromRGB(255, 120, 30),
	  desc = "Огненный шар летит вперёд и взрывается, отбрасывая всех рядом." },
	{ id = "Water",     name = "Вода",       icon = "💧", rarity = "common",    chance = 3,    cooldown = 3,   damage = 10, color = Color3.fromRGB(40, 150, 255),
	  desc = "Волна сносит всех, кто стоит перед тобой." },
	{ id = "Earth",     name = "Земля",      icon = "⛰", rarity = "uncommon",  chance = 6,    cooldown = 4,   damage = 14, color = Color3.fromRGB(165, 110, 60),
	  desc = "Удар о землю: камни подбрасывают врагов вокруг тебя." },
	{ id = "Wind",      name = "Ветер",      icon = "🌪", rarity = "uncommon",  chance = 10,   cooldown = 3.5, damage = 12, color = Color3.fromRGB(190, 255, 230),
	  desc = "Рывок-ураган: летишь вперёд и сдуваешь всех на пути." },
	{ id = "Lightning", name = "Молния",     icon = "⚡", rarity = "rare",      chance = 25,   cooldown = 5,   damage = 15, color = Color3.fromRGB(255, 240, 90),
	  desc = "Молния бьёт ближайшего врага и оглушает его." },
	{ id = "Ice",       name = "Лёд",        icon = "❄", rarity = "rare",      chance = 50,   cooldown = 5,   damage = 12, color = Color3.fromRGB(150, 230, 255),
	  desc = "Ледяной осколок замораживает врага на 2 секунды." },
	{ id = "Shadow",    name = "Тень",       icon = "🌑", rarity = "epic",      chance = 120,  cooldown = 6,   damage = 20, color = Color3.fromRGB(120, 70, 175),
	  desc = "Телепорт за спину врага и мощный удар." },
	{ id = "Gravity",   name = "Гравитация", icon = "🌀", rarity = "legendary", chance = 400,  cooldown = 8,   damage = 28, color = Color3.fromRGB(160, 80, 255),
	  desc = "Чёрная дыра затягивает врагов и взрывается." },
	{ id = "Meteor",    name = "Метеор",     icon = "☄", rarity = "mythic",    chance = 1000, cooldown = 10,  damage = 40, color = Color3.fromRGB(255, 70, 40),
	  desc = "С неба падает метеор. Огромный взрыв сносит всех вокруг." },
	-- персонаж: свой набор приёмов вместо одной способности (пока не выпадает из ролла — только кнопкой «Призвать Рю»)
	{ id = "Ryu",       name = "Рю",         icon = "🍰", rarity = "secret",    chance = 10000, rollable = false, character = true, cooldown = 0, damage = 0,
	  color = Color3.fromRGB(150, 220, 255), desc = "Рю Исигори из «Магической битвы»: десерт, рывок с серией ударов и Гранитный залп." },
}

-- приёмы Рю: клавиши 1, 2 и G (ульта)
Abilities.RyuMoves = {
	{ kind = "ryu1", key = "1", name = "Десерт",              cooldown = 20, color = Color3.fromRGB(255, 160, 200), desc = "Лечит и даёт +20% урона на 10 секунд." },
	{ kind = "ryu2", key = "2", name = "Вот каков десерт!",   cooldown = 12, color = Color3.fromRGB(255, 200, 120), desc = "Рывок; если попал — серия ударов и подброс." },
	{ kind = "ryu3", key = "G", name = "Гранитный залп",      cooldown = 45, color = Color3.fromRGB(150, 220, 255), desc = "УЛЬТА: поза, заряд и огромный луч." },
}

-- удар ладонью есть у всех всегда (отдельная кнопка)
Abilities.Slap = { id = "Slap", name = "Удар", cooldown = 0.8, damage = 5, color = Color3.fromRGB(255, 214, 170) }

Abilities.ById = {}
for i, a in ipairs(Abilities.List) do
	a.index = i
	Abilities.ById[a.id] = a
end

function Abilities.rarity(a)
	return Abilities.Rarities[a.rarity]
end

function Abilities.chanceText(a)
	return "1 к " .. tostring(a.chance)
end

-- то, что может выпасть в ролле, от самой редкой к самой частой
function Abilities.sortedByRarity()
	local t = {}
	for _, a in ipairs(Abilities.List) do
		if a.rollable ~= false then table.insert(t, a) end
	end
	table.sort(t, function(x, y) return x.chance > y.chance end)
	return t
end

return Abilities
