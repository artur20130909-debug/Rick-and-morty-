--[[
	Backpacks — рюкзаки. Сила от кликов копится до Capacity, потом её нужно продать.
	Рюкзаки покупаются по порядку за монеты в магазине. Первый выдаётся бесплатно.
]]

local Backpacks = {
	{ Name = "Мешочек", Icon = "👝", Capacity = 50, Price = 0 },
	{ Name = "Школьный рюкзак", Icon = "🎒", Capacity = 250, Price = 150 },
	{ Name = "Походный рюкзак", Icon = "🏕️", Capacity = 1000, Price = 1000 },
	{ Name = "Большой рюкзак", Icon = "🧳", Capacity = 4000, Price = 5000 },
	{ Name = "Пустынный мешок", Icon = "🏺", Capacity = 15000, Price = 25000 },
	{ Name = "Сундук фараона", Icon = "📦", Capacity = 60000, Price = 120000 },
	{ Name = "Космический контейнер", Icon = "🛰️", Capacity = 250000, Price = 600000 },
	{ Name = "Карманный портал", Icon = "🌀", Capacity = 1000000, Price = 3000000 },
	{ Name = "Чёрная дыра", Icon = "🕳️", Capacity = 10000000, Price = 20000000 },
}

return Backpacks
