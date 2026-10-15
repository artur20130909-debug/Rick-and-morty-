--[[
	Worlds — миры игры. Порядок открытия задаёт Worlds.Order.

	UnlockStrength — сколько накопленной силы (⭐) нужно, чтобы портал пустил в мир
	Origin         — центр мира в Workspace (миры стоят далеко друг от друга)
	SellMultiplier — сколько монет даёт 1 сила на точке продажи этого мира
	CoinValue      — цена одной монеты на земле, CoinCount — сколько монет лежит одновременно
	Theme          — какой набор декора строить (Forest / Desert / Space, см. server/Modules/WorldBuilder)
	Palette        — цвета мира
	Lighting       — освещение, которое клиент включает, когда игрок в этом мире
	Gravity        — гравитация для игрока в этом мире (в космосе прыжки выше)
]]

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Worlds = {
	Forest = {
		Order = 1,
		Name = "Лес",
		Icon = "🌲",
		Description = "Уютный лес с грибами. Здесь всё начинается!",
		UnlockStrength = 0,
		Origin = Vector3.new(0, 0, 0),
		SellMultiplier = 1,
		CoinValue = 10,
		CoinCount = 30,
		Theme = "Forest",
		Seed = 11,
		Color = rgb(96, 205, 90),
		Palette = {
			Ground = rgb(110, 196, 72),
			Path = rgb(196, 156, 104),
			Stand = rgb(150, 110, 70),
			PortalFrame = rgb(120, 86, 56),
			Coin = rgb(255, 205, 40),
			Trunk = rgb(130, 88, 56),
			Leaves = { rgb(70, 170, 60), rgb(90, 190, 70), rgb(60, 150, 70), rgb(120, 200, 80) },
			Flowers = { rgb(255, 90, 120), rgb(255, 220, 60), rgb(160, 120, 255), rgb(255, 255, 255), rgb(255, 150, 60) },
			Rock = rgb(150, 150, 160),
			Water = rgb(70, 170, 235),
		},
		Lighting = {
			ClockTime = 14,
			Brightness = 2.2,
			Ambient = rgb(118, 128, 108),
			OutdoorAmbient = rgb(150, 168, 140),
			StarCount = 3000,
			Atmosphere = {
				Density = 0.3,
				Offset = 0.15,
				Color = rgb(199, 232, 255),
				Decay = rgb(110, 160, 120),
				Glare = 0,
				Haze = 1.2,
			},
		},
		Gravity = 196.2,
	},

	Desert = {
		Order = 2,
		Name = "Пустыня",
		Icon = "🏜️",
		Description = "Жаркие пески, пирамиды и древние питомцы.",
		UnlockStrength = 10000,
		Origin = Vector3.new(2000, 0, 0),
		SellMultiplier = 2,
		CoinValue = 150,
		CoinCount = 30,
		Theme = "Desert",
		Seed = 22,
		Color = rgb(255, 196, 80),
		Palette = {
			Ground = rgb(240, 206, 140),
			Path = rgb(214, 170, 110),
			Stand = rgb(200, 150, 90),
			PortalFrame = rgb(196, 140, 80),
			Coin = rgb(255, 220, 60),
			Cactus = rgb(90, 170, 80),
			Sandstone = { rgb(230, 190, 120), rgb(214, 172, 104) },
			Dune = rgb(236, 198, 128),
			Rock = rgb(196, 126, 86),
			Water = rgb(60, 190, 230),
			PalmTrunk = rgb(160, 110, 66),
			PalmLeaves = rgb(80, 180, 70),
		},
		Lighting = {
			ClockTime = 12.5,
			Brightness = 3,
			Ambient = rgb(150, 130, 100),
			OutdoorAmbient = rgb(200, 172, 132),
			StarCount = 3000,
			Atmosphere = {
				Density = 0.35,
				Offset = 0.1,
				Color = rgb(255, 226, 170),
				Decay = rgb(210, 150, 90),
				Glare = 0.4,
				Haze = 2,
			},
		},
		Gravity = 196.2,
	},

	Space = {
		Order = 3,
		Name = "Космос",
		Icon = "🚀",
		Description = "Летающий остров среди звёзд. Низкая гравитация!",
		UnlockStrength = 300000,
		Origin = Vector3.new(4000, 60, 0),
		SellMultiplier = 5,
		CoinValue = 2500,
		CoinCount = 30,
		Theme = "Space",
		Seed = 33,
		Color = rgb(150, 90, 255),
		Palette = {
			Ground = rgb(76, 56, 120),
			Path = rgb(110, 90, 170),
			Stand = rgb(60, 50, 100),
			PortalFrame = rgb(70, 60, 120),
			Coin = rgb(120, 240, 255),
			Crystals = { rgb(90, 240, 255), rgb(255, 100, 220), rgb(170, 110, 255) },
			Rock = rgb(96, 84, 130),
			Lamp = rgb(120, 240, 255),
			Planets = { rgb(255, 140, 70), rgb(90, 220, 255), rgb(255, 90, 180) },
		},
		Lighting = {
			ClockTime = 0,
			Brightness = 1,
			Ambient = rgb(120, 90, 170),
			OutdoorAmbient = rgb(150, 120, 210),
			StarCount = 6000,
			Atmosphere = {
				Density = 0.25,
				Offset = 0,
				Color = rgb(120, 80, 200),
				Decay = rgb(40, 20, 90),
				Glare = 0,
				Haze = 0.5,
			},
		},
		Gravity = 70,
	},
}

-- Порядок миров: каждый следующий открывается порталом из предыдущего.
Worlds.Order = { "Forest", "Desert", "Space" }

return Worlds
