--[[
	Eggs — яйца с питомцами.

	World     — в каком мире стоит яйцо (ключ из Worlds)
	Price     — цена одного открытия в монетах
	Position  — место подставки внутри мира (X и Z относительно центра мира)
	Color / SpotColor — цвета скорлупы
	Pets      — ID питомцев из Pets.lua. Шанс выпадения зависит от редкости питомца (Rarities.lua),
	            а внутри одной редкости питомцы выпадают поровну.

	Чтобы добавить яйцо: допиши запись, добавь ID в Eggs.Order и выбери свободное место в мире.
]]

local Eggs = {
	ForestEgg = {
		Name = "Лесное яйцо",
		World = "Forest",
		Price = 50,
		Position = Vector3.new(40, 0, 32),
		Color = Color3.fromRGB(150, 225, 110),
		SpotColor = Color3.fromRGB(80, 165, 60),
		Pets = { "Kitten", "Puppy", "Fox", "Owl", "ForestSpirit" },
	},
	MushroomEgg = {
		Name = "Грибное яйцо",
		World = "Forest",
		Price = 400,
		Position = Vector3.new(40, 0, 8),
		Color = Color3.fromRGB(255, 96, 96),
		SpotColor = Color3.fromRGB(255, 255, 255),
		Pets = { "Bunny", "Hedgehog", "Bear", "Raccoon", "Unicorn" },
	},

	SandEgg = {
		Name = "Песчаное яйцо",
		World = "Desert",
		Price = 2500,
		Position = Vector3.new(40, 0, 32),
		Color = Color3.fromRGB(246, 214, 140),
		SpotColor = Color3.fromRGB(210, 150, 80),
		Pets = { "Lizard", "Fennec", "Scorpion", "Camel", "Sphinx" },
	},
	PyramidEgg = {
		Name = "Пирамидное яйцо",
		World = "Desert",
		Price = 15000,
		Position = Vector3.new(40, 0, 8),
		Color = Color3.fromRGB(255, 200, 60),
		SpotColor = Color3.fromRGB(60, 110, 220),
		Pets = { "Scarab", "Snake", "MummyCat", "Phoenix", "Pharaoh" },
	},

	MoonEgg = {
		Name = "Лунное яйцо",
		World = "Space",
		Price = 120000,
		Position = Vector3.new(40, 0, 32),
		Color = Color3.fromRGB(210, 215, 235),
		SpotColor = Color3.fromRGB(140, 145, 175),
		Pets = { "Alien", "Robot", "SpaceCat", "StarDragon", "BlackHole" },
	},
	GalaxyEgg = {
		Name = "Галактическое яйцо",
		World = "Space",
		Price = 800000,
		Position = Vector3.new(40, 0, 8),
		Color = Color3.fromRGB(150, 80, 255),
		SpotColor = Color3.fromRGB(90, 230, 255),
		Pets = { "Meteor", "Ufo", "CrystalGolem", "GalaxyWhale", "CosmicGod" },
	},
}

-- Порядок для интерфейса и построения мира.
Eggs.Order = { "ForestEgg", "MushroomEgg", "SandEgg", "PyramidEgg", "MoonEgg", "GalaxyEgg" }

return Eggs
