--[[
	Backpacks — рюкзаки. Сила от кликов копится до Capacity, потом её нужно продать.
	Рюкзаки покупаются по порядку за монеты в магазине. Первый выдаётся бесплатно.
]]

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Color — цвет 3D-рюкзака в магазине.
local Backpacks = {
	{ Name = "Мешочек", Color = rgb(196, 160, 120), Capacity = 50, Price = 0 },
	{ Name = "Школьный рюкзак", Color = rgb(90, 170, 255), Capacity = 250, Price = 150 },
	{ Name = "Походный рюкзак", Color = rgb(110, 200, 90), Capacity = 1000, Price = 1000 },
	{ Name = "Большой рюкзак", Color = rgb(255, 150, 60), Capacity = 4000, Price = 5000 },
	{ Name = "Пустынный мешок", Color = rgb(240, 200, 110), Capacity = 15000, Price = 25000 },
	{ Name = "Сундук фараона", Color = rgb(255, 205, 50), Capacity = 60000, Price = 120000 },
	{ Name = "Космический контейнер", Color = rgb(120, 220, 255), Capacity = 250000, Price = 600000 },
	{ Name = "Карманный портал", Color = rgb(190, 110, 255), Capacity = 1000000, Price = 3000000 },
	{ Name = "Чёрная дыра", Color = rgb(60, 45, 90), Capacity = 10000000, Price = 20000000 },
}

return Backpacks
