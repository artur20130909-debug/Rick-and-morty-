--[[
	Rarities — редкости питомцев.
	Chance — шанс в процентах. Если в яйце нет питомца какой-то редкости,
	шансы остальных редкостей пересчитываются пропорционально.
]]

local Rarities = {
	Common = {
		Name = "Обычный",
		Chance = 60,
		Color = Color3.fromRGB(176, 186, 197),
		Order = 1,
	},
	Rare = {
		Name = "Редкий",
		Chance = 25,
		Color = Color3.fromRGB(77, 166, 255),
		Order = 2,
	},
	Epic = {
		Name = "Эпик",
		Chance = 10,
		Color = Color3.fromRGB(177, 92, 255),
		Order = 3,
	},
	Legendary = {
		Name = "Легендарный",
		Chance = 4.5,
		Color = Color3.fromRGB(255, 176, 32),
		Order = 4,
	},
	Mythic = {
		Name = "Мифический",
		Chance = 0.5,
		Color = Color3.fromRGB(255, 61, 127),
		Order = 5,
	},
}

-- Порядок от самой частой редкости к самой редкой.
Rarities.Order = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

return Rarities
