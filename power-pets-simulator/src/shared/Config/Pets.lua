--[[
	Pets — все питомцы игры.

	Ключ таблицы — ID питомца (его используют яйца и сохранения, не меняй ID у уже выпущенных питомцев).
	Name        — имя в интерфейсе
	Rarity      — ключ из Rarities (Common, Rare, Epic, Legendary, Mythic)
	Multiplier  — множитель силы за клик (x1.2 … x50). Золотой питомец даёт вдвое больше.
	Icon        — эмодзи для карточки в инвентаре
	Look        — как собрать 3D-модель (см. Modules/PetBuilder):
		Shape      "Ball" | "Blob" | "Long" | "Box" | "Disc" | "Gem" | "Hole"
		Color      основной цвет, Accent — второй цвет (живот, внутренность ушей)
		Ears       "Pointy" | "Round" | "Long" | "Floppy" | "Tiny"   (EarScale — размер ушей)
		Tail       "Thin" | "Fluffy" | "Puff" | "Stinger" | "Fins" | "Flame"
		Wings      "Feather" | "Bat" | "Bug"
		EyeStyle   "Ball" | "Big" | "Led" | "Alien"
		и украшения: Snout, Nose, Beak, Horn, Horns ("Dragon"/"Antlers"), Antenna (1/2), Halo,
		Crown, Headdress, Spikes, Mask, Ring, Bandage, Hump, Claws, Helmet, Mane, Glow.

	Чтобы добавить питомца: допиши запись сюда и добавь его ID в список Pets нужного яйца (Eggs.lua).
]]

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Pets = {
	------------------------------------------------------------------ ЛЕС
	-- Лесное яйцо
	Kitten = {
		Name = "Котёнок",
		Rarity = "Common",
		Multiplier = 1.2,
		Icon = "🐱",
		Look = {
			Color = rgb(255, 170, 80),
			Accent = rgb(255, 236, 214),
			Ears = "Pointy",
			Tail = "Thin",
			Nose = rgb(255, 120, 150),
		},
	},
	Puppy = {
		Name = "Щенок",
		Rarity = "Rare",
		Multiplier = 1.5,
		Icon = "🐶",
		Look = {
			Color = rgb(206, 150, 98),
			Accent = rgb(255, 240, 222),
			Ears = "Floppy",
			EarColor = rgb(140, 92, 56),
			Snout = true,
			Nose = rgb(40, 30, 30),
			Tail = "Thin",
		},
	},
	Fox = {
		Name = "Лисёнок",
		Rarity = "Epic",
		Multiplier = 2,
		Icon = "🦊",
		Look = {
			Color = rgb(255, 122, 40),
			Accent = rgb(255, 250, 240),
			Ears = "Pointy",
			EarScale = 1.2,
			Snout = true,
			Nose = rgb(40, 30, 30),
			Tail = "Fluffy",
			TailTip = rgb(255, 255, 255),
		},
	},
	Owl = {
		Name = "Сова",
		Rarity = "Legendary",
		Multiplier = 3,
		Icon = "🦉",
		Look = {
			Color = rgb(150, 105, 70),
			Accent = rgb(240, 220, 180),
			EyeStyle = "Big",
			EyeRing = rgb(255, 214, 90),
			Ears = "Tiny",
			Beak = rgb(255, 170, 40),
			Wings = "Feather",
			WingColor = rgb(120, 82, 52),
			Blush = false,
		},
	},
	ForestSpirit = {
		Name = "Лесной дух",
		Rarity = "Mythic",
		Multiplier = 5,
		Icon = "🌿",
		Look = {
			Shape = "Blob",
			Color = rgb(120, 255, 170),
			Accent = rgb(210, 255, 225),
			Transparency = 0.15,
			EyeColor = rgb(20, 90, 60),
			Horns = "Antlers",
			HornColor = rgb(90, 255, 140),
			Glow = true,
			GlowColor = rgb(120, 255, 170),
		},
	},

	-- Грибное яйцо
	Bunny = {
		Name = "Зайчик",
		Rarity = "Common",
		Multiplier = 1.4,
		Icon = "🐰",
		Look = {
			Color = rgb(250, 250, 250),
			Accent = rgb(255, 190, 210),
			Ears = "Long",
			Nose = rgb(255, 120, 150),
			Tail = "Puff",
			TailColor = rgb(255, 255, 255),
		},
	},
	Hedgehog = {
		Name = "Ёжик",
		Rarity = "Rare",
		Multiplier = 1.8,
		Icon = "🦔",
		Look = {
			Color = rgb(196, 150, 104),
			Accent = rgb(246, 222, 186),
			Spikes = rgb(110, 76, 50),
			Snout = true,
			Nose = rgb(40, 30, 30),
			Ears = "Round",
			EarScale = 0.6,
		},
	},
	Bear = {
		Name = "Медвежонок",
		Rarity = "Epic",
		Multiplier = 2.5,
		Icon = "🐻",
		Look = {
			Color = rgb(150, 98, 56),
			Accent = rgb(226, 186, 136),
			Ears = "Round",
			Snout = true,
			Nose = rgb(40, 30, 30),
		},
	},
	Raccoon = {
		Name = "Енот",
		Rarity = "Legendary",
		Multiplier = 4,
		Icon = "🦝",
		Look = {
			Color = rgb(140, 140, 152),
			Accent = rgb(232, 232, 238),
			Ears = "Pointy",
			Mask = rgb(50, 48, 60),
			Snout = true,
			Nose = rgb(30, 30, 30),
			Tail = "Fluffy",
			TailTip = rgb(50, 48, 60),
		},
	},
	Unicorn = {
		Name = "Единорог",
		Rarity = "Mythic",
		Multiplier = 8,
		Icon = "🦄",
		Look = {
			Color = rgb(255, 255, 255),
			Accent = rgb(255, 205, 235),
			Ears = "Pointy",
			EarScale = 0.8,
			Horn = rgb(255, 215, 80),
			Mane = { rgb(255, 90, 140), rgb(255, 190, 70), rgb(120, 220, 120), rgb(110, 170, 255), rgb(190, 120, 255) },
			Tail = "Fluffy",
			TailColor = rgb(190, 120, 255),
			TailTip = rgb(255, 90, 140),
			Glow = true,
			GlowColor = rgb(255, 170, 230),
		},
	},

	------------------------------------------------------------------ ПУСТЫНЯ
	-- Песчаное яйцо
	Lizard = {
		Name = "Ящерка",
		Rarity = "Common",
		Multiplier = 2.5,
		Icon = "🦎",
		Look = {
			Shape = "Long",
			Color = rgb(120, 196, 80),
			Accent = rgb(236, 240, 140),
			Tail = "Thin",
		},
	},
	Fennec = {
		Name = "Фенек",
		Rarity = "Rare",
		Multiplier = 3.5,
		Icon = "🦊",
		Look = {
			Color = rgb(242, 204, 144),
			Accent = rgb(255, 246, 232),
			Ears = "Pointy",
			EarScale = 1.6,
			Snout = true,
			Nose = rgb(40, 30, 30),
			Tail = "Fluffy",
			TailTip = rgb(120, 80, 50),
		},
	},
	Scorpion = {
		Name = "Скорпион",
		Rarity = "Epic",
		Multiplier = 5,
		Icon = "🦂",
		Look = {
			Color = rgb(196, 70, 44),
			Accent = rgb(255, 160, 110),
			Claws = true,
			Tail = "Stinger",
			Blush = false,
		},
	},
	Camel = {
		Name = "Верблюд",
		Rarity = "Legendary",
		Multiplier = 8,
		Icon = "🐫",
		Look = {
			Color = rgb(214, 164, 104),
			Accent = rgb(246, 220, 176),
			Hump = true,
			Snout = true,
			Nose = rgb(90, 60, 40),
			Ears = "Tiny",
			Tail = "Thin",
		},
	},
	Sphinx = {
		Name = "Сфинкс",
		Rarity = "Mythic",
		Multiplier = 14,
		Icon = "🗿",
		Look = {
			Color = rgb(232, 192, 96),
			Accent = rgb(255, 230, 160),
			Ears = "Pointy",
			Headdress = rgb(60, 110, 220),
			EyeColor = rgb(30, 60, 140),
			Glow = true,
			GlowColor = rgb(255, 210, 110),
		},
	},

	-- Пирамидное яйцо
	Scarab = {
		Name = "Скарабей",
		Rarity = "Common",
		Multiplier = 3.5,
		Icon = "🪲",
		Look = {
			Color = rgb(40, 120, 130),
			Accent = rgb(110, 220, 200),
			Material = Enum.Material.Metal,
			Antenna = 2,
			Wings = "Bug",
			Blush = false,
		},
	},
	Snake = {
		Name = "Змейка",
		Rarity = "Rare",
		Multiplier = 5,
		Icon = "🐍",
		Look = {
			Shape = "Long",
			Color = rgb(150, 210, 60),
			Accent = rgb(255, 230, 110),
			Tail = "Thin",
			EyeColor = rgb(60, 30, 10),
		},
	},
	MummyCat = {
		Name = "Кот-мумия",
		Rarity = "Epic",
		Multiplier = 7,
		Icon = "🧟",
		Look = {
			Color = rgb(236, 226, 200),
			Accent = rgb(205, 190, 160),
			Ears = "Pointy",
			Bandage = true,
			EyeColor = rgb(80, 255, 120),
			EyeGlow = true,
			Blush = false,
			Belly = false,
		},
	},
	Phoenix = {
		Name = "Феникс",
		Rarity = "Legendary",
		Multiplier = 11,
		Icon = "🔥",
		Look = {
			Color = rgb(255, 92, 30),
			Accent = rgb(255, 214, 60),
			Beak = rgb(255, 214, 60),
			Wings = "Feather",
			WingColor = rgb(255, 160, 40),
			Tail = "Flame",
			Ears = "Tiny",
			EarColor = rgb(255, 214, 60),
			Glow = true,
			GlowColor = rgb(255, 140, 40),
		},
	},
	Pharaoh = {
		Name = "Фараон",
		Rarity = "Mythic",
		Multiplier = 20,
		Icon = "👑",
		Look = {
			Color = rgb(255, 210, 70),
			Accent = rgb(255, 240, 180),
			Headdress = rgb(40, 80, 200),
			Crown = true,
			EyeColor = rgb(20, 40, 120),
			Glow = true,
			GlowColor = rgb(255, 220, 90),
		},
	},

	------------------------------------------------------------------ КОСМОС
	-- Лунное яйцо
	Alien = {
		Name = "Инопланетянин",
		Rarity = "Common",
		Multiplier = 6,
		Icon = "👽",
		Look = {
			Color = rgb(130, 236, 120),
			Accent = rgb(200, 255, 190),
			EyeStyle = "Alien",
			Antenna = 2,
			AntennaColor = rgb(255, 90, 200),
			Blush = false,
		},
	},
	Robot = {
		Name = "Робот",
		Rarity = "Rare",
		Multiplier = 8,
		Icon = "🤖",
		Look = {
			Shape = "Box",
			Color = rgb(160, 176, 200),
			Accent = rgb(90, 104, 130),
			Material = Enum.Material.Metal,
			EyeColor = rgb(60, 230, 255),
			Antenna = 1,
			AntennaColor = rgb(255, 80, 80),
		},
	},
	SpaceCat = {
		Name = "Космо-кот",
		Rarity = "Epic",
		Multiplier = 12,
		Icon = "🐈",
		Look = {
			Color = rgb(70, 60, 140),
			Accent = rgb(140, 220, 255),
			Ears = "Pointy",
			Tail = "Thin",
			Helmet = true,
			EyeColor = rgb(120, 240, 255),
			EyeGlow = true,
		},
	},
	StarDragon = {
		Name = "Звёздный дракон",
		Rarity = "Legendary",
		Multiplier = 20,
		Icon = "🐉",
		Look = {
			Color = rgb(130, 64, 230),
			Accent = rgb(110, 240, 255),
			Horns = "Dragon",
			HornColor = rgb(255, 230, 120),
			Wings = "Bat",
			WingColor = rgb(80, 40, 170),
			Tail = "Thin",
			Snout = true,
			Glow = true,
			GlowColor = rgb(150, 110, 255),
		},
	},
	BlackHole = {
		Name = "Чёрная дыра",
		Rarity = "Mythic",
		Multiplier = 35,
		Icon = "🕳️",
		Look = {
			Shape = "Hole",
			Color = rgb(14, 10, 22),
			Accent = rgb(255, 140, 40),
			Ring = rgb(255, 150, 50),
			Ring2 = rgb(200, 80, 255),
			EyeColor = rgb(255, 255, 255),
			EyeGlow = true,
			Glow = true,
			GlowColor = rgb(200, 100, 255),
		},
	},

	-- Галактическое яйцо
	Meteor = {
		Name = "Метеорчик",
		Rarity = "Common",
		Multiplier = 9,
		Icon = "☄️",
		Look = {
			Shape = "Blob",
			Color = rgb(130, 108, 96),
			Accent = rgb(255, 150, 60),
			Material = Enum.Material.Slate,
			Tail = "Flame",
			EyeColor = rgb(255, 200, 80),
			EyeGlow = true,
			Blush = false,
		},
	},
	Ufo = {
		Name = "НЛО",
		Rarity = "Rare",
		Multiplier = 12,
		Icon = "🛸",
		Look = {
			Shape = "Disc",
			Color = rgb(180, 190, 210),
			Accent = rgb(120, 240, 255),
			Material = Enum.Material.Metal,
		},
	},
	CrystalGolem = {
		Name = "Кристальный голем",
		Rarity = "Epic",
		Multiplier = 18,
		Icon = "💎",
		Look = {
			Shape = "Gem",
			Color = rgb(70, 80, 120),
			Accent = rgb(90, 240, 255),
			Material = Enum.Material.Slate,
			EyeColor = rgb(90, 240, 255),
			EyeGlow = true,
			Glow = true,
			GlowColor = rgb(90, 240, 255),
		},
	},
	GalaxyWhale = {
		Name = "Галактический кит",
		Rarity = "Legendary",
		Multiplier = 28,
		Icon = "🐋",
		Look = {
			Shape = "Long",
			Color = rgb(60, 90, 220),
			Accent = rgb(170, 220, 255),
			Tail = "Fins",
			Size = 1.1,
			Glow = true,
			GlowColor = rgb(120, 160, 255),
		},
	},
	CosmicGod = {
		Name = "Космический бог",
		Rarity = "Mythic",
		Multiplier = 50,
		Icon = "✨",
		Look = {
			Color = rgb(255, 250, 235),
			Accent = rgb(255, 220, 120),
			Halo = true,
			Wings = "Feather",
			WingColor = rgb(255, 255, 255),
			Crown = true,
			EyeColor = rgb(80, 160, 255),
			EyeGlow = true,
			Glow = true,
			GlowColor = rgb(255, 240, 170),
		},
	},
}

return Pets
