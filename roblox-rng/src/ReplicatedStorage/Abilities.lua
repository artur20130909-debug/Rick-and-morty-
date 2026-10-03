-- Способности: редкость, шанс «1 к N», цвет, перезарядка, описание.
-- Общий модуль: его читают и сервер (ролл, бой), и клиент (интерфейс).
local Abilities = {}

Abilities.Rarities = {
	common    = { name = "Обычная",     color = Color3.fromRGB(200, 205, 215), order = 1 },
	uncommon  = { name = "Необычная",   color = Color3.fromRGB(90, 225, 110),  order = 2 },
	rare      = { name = "Редкая",      color = Color3.fromRGB(70, 155, 255),  order = 3 },
	epic      = { name = "Эпическая",   color = Color3.fromRGB(185, 95, 255),  order = 4 },
	legendary = { name = "Легендарная", color = Color3.fromRGB(255, 200, 40),  order = 5 },
	mythic    = { name = "Мифическая",  color = Color3.fromRGB(255, 60, 95),   order = 6 },
}

Abilities.List = {
	{ id = "Fire",      name = "Огонь",      rarity = "common",    chance = 2,    cooldown = 2.5, color = Color3.fromRGB(255, 120, 30),
	  desc = "Огненный шар летит вперёд и взрывается, отбрасывая всех рядом." },
	{ id = "Water",     name = "Вода",       rarity = "common",    chance = 3,    cooldown = 3,   color = Color3.fromRGB(40, 150, 255),
	  desc = "Волна сносит всех, кто стоит перед тобой." },
	{ id = "Earth",     name = "Земля",      rarity = "uncommon",  chance = 6,    cooldown = 4,   color = Color3.fromRGB(165, 110, 60),
	  desc = "Удар о землю: камни подбрасывают врагов вокруг тебя." },
	{ id = "Wind",      name = "Ветер",      rarity = "uncommon",  chance = 10,   cooldown = 3.5, color = Color3.fromRGB(190, 255, 230),
	  desc = "Рывок-ураган: летишь вперёд и сдуваешь всех на пути." },
	{ id = "Lightning", name = "Молния",     rarity = "rare",      chance = 25,   cooldown = 5,   color = Color3.fromRGB(255, 240, 90),
	  desc = "Молния бьёт ближайшего врага и оглушает его." },
	{ id = "Ice",       name = "Лёд",        rarity = "rare",      chance = 50,   cooldown = 5,   color = Color3.fromRGB(150, 230, 255),
	  desc = "Ледяной осколок замораживает врага на 2 секунды." },
	{ id = "Shadow",    name = "Тень",       rarity = "epic",      chance = 120,  cooldown = 6,   color = Color3.fromRGB(120, 70, 175),
	  desc = "Телепорт за спину врага и мощный удар." },
	{ id = "Gravity",   name = "Гравитация", rarity = "legendary", chance = 400,  cooldown = 8,   color = Color3.fromRGB(160, 80, 255),
	  desc = "Чёрная дыра затягивает врагов и взрывается." },
	{ id = "Meteor",    name = "Метеор",     rarity = "mythic",    chance = 1000, cooldown = 10,  color = Color3.fromRGB(255, 70, 40),
	  desc = "С неба падает метеор. Огромный взрыв сносит всех вокруг." },
}

-- Удар ладонью есть у всех всегда (отдельная кнопка), его не роллят
Abilities.Slap = { id = "Slap", name = "Удар", cooldown = 0.8, color = Color3.fromRGB(255, 214, 170) }

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

-- от самой редкой к самой частой: так удобно роллить
function Abilities.sortedByRarity()
	local t = {}
	for _, a in ipairs(Abilities.List) do table.insert(t, a) end
	table.sort(t, function(x, y) return x.chance > y.chance end)
	return t
end

return Abilities
