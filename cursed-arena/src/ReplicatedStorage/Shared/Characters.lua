-- Персонажи и их приёмы. Названия и описания — то, что видит игрок.
-- AI: подсказка ботам (range — с какой дистанции применять, kind — тип приёма).
local Characters = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

Characters.List = { "StormFist", "VoidLord", "CrimsonBlade", "ShadowCaller", "FlameDemon", "Thunderer" }
Characters.Default = "StormFist"

Characters.Defs = {
	StormFist = {
		Name = "Кулак Бури",
		Title = "Неудержимый",
		Desc = "Боец ближнего боя: быстрые серии, удар с отложенной волной и Резонанс — нажми клавишу приёма ещё раз в момент вспышки.",
		Color = rgb(255, 92, 51), Accent = rgb(255, 214, 92), Dark = rgb(60, 14, 10),
		M1Style = "fists",
		Difficulty = "Легко",
		Moves = {
			{ Id = "FistRush", Name = "Рывок Кулака", Cooldown = 9, Desc = "Рывок вперёд и серия ударов. Нажми 1 ещё раз во время вспышки — РЕЗОНАНС.", AI = { range = 26, kind = "gap" } },
			{ Id = "WhirlKick", Name = "Вихревой Пинок", Cooldown = 8, Desc = "Круговой удар ногой: бьёт всех рядом и подбрасывает.", AI = { range = 8, kind = "aoe" } },
			{ Id = "DelayedImpact", Name = "Отложенный Удар", Cooldown = 10, Desc = "Удар, а через миг — вторая волна. Вторая волна пробивает блок.", AI = { range = 7, kind = "melee" } },
			{ Id = "Crusher", Name = "Сокрушитель", Cooldown = 14, Desc = "Захват в прыжке и бросок о землю.", AI = { range = 15, kind = "grab" } },
		},
		Awakening = {
			Name = "ЯРОСТЬ БУРИ",
			Moves = {
				{ Id = "ThunderRush", Name = "Громовой Рывок", Cooldown = 6, Desc = "Длинный рывок с молниями: три удара и Резонанс.", AI = { range = 34, kind = "gap" } },
				{ Id = "Hurricane", Name = "Ураган", Cooldown = 7, Desc = "Смерч ударов: затягивает врагов и выбрасывает вверх.", AI = { range = 12, kind = "aoe" } },
				{ Id = "ThousandFists", Name = "Тысяча Кулаков", Cooldown = 9, Desc = "Град ударов перед собой.", AI = { range = 7, kind = "melee" } },
				{ Id = "HeavenStrike", Name = "Удар Небес", Cooldown = 999, Ultimate = true, Desc = "Прыжок в небо и падение с кулаком: огромный взрыв.", AI = { range = 45, kind = "ult" } },
			},
		},
	},

	VoidLord = {
		Name = "Повелитель Пустоты",
		Title = "Безмерный",
		Desc = "Маг пространства: притягивает, отталкивает, прыгает за спину и бьёт лучом. В пробуждении открывает территорию.",
		Color = rgb(92, 214, 255), Accent = rgb(170, 92, 255), Dark = rgb(20, 16, 48),
		M1Style = "palms",
		M1 = { Reach = 4.2 },
		Difficulty = "Средне",
		Moves = {
			{ Id = "Attract", Name = "Притяжение", Cooldown = 9, Desc = "Шар пустоты: стягивает врагов в одну точку.", AI = { range = 45, kind = "ranged" } },
			{ Id = "Repel", Name = "Отторжение", Cooldown = 9, Desc = "Взрыв пустоты перед собой: отбрасывает очень далеко.", AI = { range = 12, kind = "melee" } },
			{ Id = "Blink", Name = "Скачок", Cooldown = 7, Desc = "Мгновенно за спину ближайшего врага и удар ногой.", AI = { range = 40, kind = "gap" } },
			{ Id = "VoidBeam", Name = "Луч Пустоты", Cooldown = 15, Desc = "Заряд и огромный луч, пробивающий всё на пути.", AI = { range = 80, kind = "ranged" } },
		},
		Awakening = {
			Name = "БЕЗМЕРНОСТЬ",
			Moves = {
				{ Id = "GravityWell", Name = "Гравитационный Колодец", Cooldown = 8, Desc = "Чёрная дыра: три секунды тянет всех вокруг.", AI = { range = 45, kind = "ranged" } },
				{ Id = "Supernova", Name = "Сверхновая", Cooldown = 9, Desc = "Взрыв пустоты во все стороны.", AI = { range = 15, kind = "aoe" } },
				{ Id = "Distortion", Name = "Искажение", Cooldown = 6, Desc = "Три скачка подряд — и каждый с ударом.", AI = { range = 40, kind = "gap" } },
				{ Id = "EventHorizon", Name = "Территория: Горизонт Событий", Cooldown = 999, Ultimate = true, Domain = true, Desc = "Купол: враги внутри замедлены, не могут применять приёмы и получают урон.", AI = { range = 30, kind = "ult" } },
			},
		},
	},

	CrimsonBlade = {
		Name = "Алый Клинок",
		Title = "Мастер Меча",
		Desc = "Мечник: режет на расстоянии, ловит врага в контрстойку и пролетает сквозь толпу.",
		Color = rgb(230, 32, 56), Accent = rgb(245, 240, 235), Dark = rgb(40, 6, 12),
		M1Style = "sword",
		M1 = { Reach = 4.6, HitboxSize = Vector3.new(7.5, 6, 7), Damage = 3.8, FinisherDamage = 6 },
		Difficulty = "Средне",
		Moves = {
			{ Id = "WindCut", Name = "Рассечение", Cooldown = 7, Desc = "Летящий разрез: пробивает до трёх врагов.", AI = { range = 60, kind = "ranged" } },
			{ Id = "Counter", Name = "Контрстойка", Cooldown = 11, Desc = "Короткая стойка. Если ударят — блокирует и рубит в ответ.", AI = { range = 6, kind = "defense" } },
			{ Id = "BladeFlurry", Name = "Шквал Лезвий", Cooldown = 10, Desc = "Рывок сквозь врагов, затем серия порезов.", AI = { range = 26, kind = "gap" } },
			{ Id = "RisingSlash", Name = "Восходящий Разрез", Cooldown = 12, Desc = "Подброс разрезом и удар сверху.", AI = { range = 7, kind = "melee" } },
		},
		Awakening = {
			Name = "КРОВАВАЯ ЛУНА",
			Moves = {
				{ Id = "BladeFan", Name = "Веер Клинков", Cooldown = 6, Desc = "Пять летящих разрезов веером.", AI = { range = 55, kind = "ranged" } },
				{ Id = "InstantCut", Name = "Мгновенный Разрез", Cooldown = 6, Desc = "Телепорт к врагу и разрез насквозь.", AI = { range = 50, kind = "gap" } },
				{ Id = "ThousandCuts", Name = "Тысяча Порезов", Cooldown = 9, Desc = "Буря порезов вокруг себя.", AI = { range = 12, kind = "aoe" } },
				{ Id = "BladeGarden", Name = "Территория: Сад Клинков", Cooldown = 999, Ultimate = true, Domain = true, Desc = "Купол, в котором разрезы сами находят каждого врага.", AI = { range = 30, kind = "ult" } },
			},
		},
	},

	ShadowCaller = {
		Name = "Призыватель Теней",
		Title = "Тень",
		Desc = "Призыватель: теневые псы, вороны и пасть из-под земли. Умеет нырять в тень.",
		Color = rgb(128, 72, 220), Accent = rgb(64, 110, 255), Dark = rgb(14, 10, 24),
		M1Style = "claws",
		Difficulty = "Сложно",
		Moves = {
			{ Id = "Hounds", Name = "Теневые Псы", Cooldown = 10, Desc = "Два пса бегут к врагу и кусают.", AI = { range = 45, kind = "ranged" } },
			{ Id = "CrowSwarm", Name = "Стая Воронов", Cooldown = 9, Desc = "Стая летит вперёд, бьёт и ослепляет.", AI = { range = 45, kind = "ranged" } },
			{ Id = "ShadowDive", Name = "Нырок в Тень", Cooldown = 10, Desc = "Уйти в тень (неуязвим) и выпрыгнуть с апперкотом. Нажми 3 ещё раз, чтобы выйти раньше.", AI = { range = 20, kind = "gap" } },
			{ Id = "AbyssMaw", Name = "Пасть Бездны", Cooldown = 14, Desc = "Под врагом вырывается огромная пасть.", AI = { range = 45, kind = "ranged" } },
		},
		Awakening = {
			Name = "НОЧНОЙ ЛЕГИОН",
			Moves = {
				{ Id = "HoundPack", Name = "Стая Псов", Cooldown = 7, Desc = "Четыре пса бросаются на врагов.", AI = { range = 50, kind = "ranged" } },
				{ Id = "ShadowGiant", Name = "Теневой Великан", Cooldown = 9, Desc = "Огромный кулак тени бьёт вперёд.", AI = { range = 25, kind = "melee" } },
				{ Id = "ShadowChains", Name = "Теневые Цепи", Cooldown = 9, Desc = "Цепи сковывают всех вокруг.", AI = { range = 18, kind = "aoe" } },
				{ Id = "Abyss", Name = "Территория: Бездна", Cooldown = 999, Ultimate = true, Domain = true, Desc = "Пол становится тенью: враги вязнут, а псы кусают.", AI = { range = 30, kind = "ult" } },
			},
		},
	},

	FlameDemon = {
		Name = "Пламенный Демон",
		Title = "Пекло",
		Desc = "Огонь на дистанции: шары, столбы пламени и метеор. Поджигает врагов.",
		Color = rgb(255, 128, 28), Accent = rgb(255, 222, 90), Dark = rgb(70, 18, 6),
		M1Style = "flame",
		Difficulty = "Легко",
		Moves = {
			{ Id = "Fireball", Name = "Огненный Шар", Cooldown = 7, Desc = "Шар взрывается и поджигает.", AI = { range = 60, kind = "ranged" } },
			{ Id = "FlameDash", Name = "Огненный Рывок", Cooldown = 8, Desc = "Рывок, за которым горит дорожка.", AI = { range = 26, kind = "gap" } },
			{ Id = "FlamePillar", Name = "Столб Пламени", Cooldown = 10, Desc = "Под врагом вырывается столб огня.", AI = { range = 50, kind = "ranged" } },
			{ Id = "Meteor", Name = "Метеор", Cooldown = 15, Desc = "С неба падает метеор.", AI = { range = 55, kind = "ranged" } },
		},
		Awakening = {
			Name = "ИНФЕРНО",
			Moves = {
				{ Id = "FireBarrage", Name = "Огненный Шквал", Cooldown = 6, Desc = "Пять огненных шаров подряд.", AI = { range = 60, kind = "ranged" } },
				{ Id = "FireRing", Name = "Кольцо Огня", Cooldown = 8, Desc = "Огненная волна во все стороны.", AI = { range = 18, kind = "aoe" } },
				{ Id = "Phoenix", Name = "Феникс", Cooldown = 9, Desc = "Полёт огненной птицей сквозь врагов.", AI = { range = 35, kind = "gap" } },
				{ Id = "SolarFlare", Name = "Солнечная Вспышка", Cooldown = 999, Ultimate = true, Desc = "Маленькое солнце падает на арену.", AI = { range = 40, kind = "ult" } },
			},
		},
	},

	Thunderer = {
		Name = "Громовержец",
		Title = "Молния",
		Desc = "Самый быстрый: мгновенные шаги, цепные молнии и рельсотрон.",
		Color = rgb(110, 196, 255), Accent = rgb(255, 248, 160), Dark = rgb(12, 22, 48),
		M1Style = "zap",
		M1 = { Interval = 0.25, Damage = 3.1, FinisherDamage = 5 },
		Difficulty = "Средне",
		Moves = {
			{ Id = "FlashStep", Name = "Шаг Молнии", Cooldown = 6, Desc = "Мгновенный рывок сквозь врагов.", AI = { range = 26, kind = "gap" } },
			{ Id = "ChainLightning", Name = "Цепная Молния", Cooldown = 9, Desc = "Молния перескакивает между врагами.", AI = { range = 45, kind = "ranged" } },
			{ Id = "ThunderClap", Name = "Громовой Хлопок", Cooldown = 10, Desc = "Хлопок: оглушает всех рядом.", AI = { range = 11, kind = "aoe" } },
			{ Id = "Railgun", Name = "Рельсотрон", Cooldown = 14, Desc = "Короткий заряд и молниевый луч.", AI = { range = 90, kind = "ranged" } },
		},
		Awakening = {
			Name = "БУРЯ",
			Moves = {
				{ Id = "StormSteps", Name = "Шквальные Шаги", Cooldown = 5, Desc = "Три шага молнии подряд к врагу.", AI = { range = 40, kind = "gap" } },
				{ Id = "Thunderbolt", Name = "Удар Молнии", Cooldown = 8, Desc = "Молнии с неба бьют всех вокруг.", AI = { range = 35, kind = "aoe" } },
				{ Id = "Overload", Name = "Перегрузка", Cooldown = 8, Desc = "Разряд вокруг себя бьёт несколько раз.", AI = { range = 14, kind = "aoe" } },
				{ Id = "Judgment", Name = "Небесный Суд", Cooldown = 999, Ultimate = true, Desc = "Гроза: молнии бьют по врагам по всей округе.", AI = { range = 60, kind = "ult" } },
			},
		},
	},
}

function Characters.get(id)
	return Characters.Defs[id] or Characters.Defs[Characters.Default]
end

function Characters.valid(id)
	return type(id) == "string" and Characters.Defs[id] ~= nil
end

-- текущие 4 приёма (обычные или пробуждённые)
function Characters.moveset(id, awakened)
	local def = Characters.get(id)
	if awakened then return def.Awakening.Moves end
	return def.Moves
end

-- найти приём по Id
function Characters.findMove(id, moveId)
	local def = Characters.get(id)
	for _, m in ipairs(def.Moves) do if m.Id == moveId then return m end end
	for _, m in ipairs(def.Awakening.Moves) do if m.Id == moveId then return m end end
	return nil
end

return Characters
