-- Общие настройки боя. Все числа баланса — здесь.
local Config = {}

Config.GameName = "CURSED ARENA"
Config.Subtitle = "битва техник"
Config.Version = "1.0"

-- персонаж
Config.MaxHealth = 100
Config.WalkSpeed = 20
Config.JumpHeight = 7.5
Config.StunSpeed = 4          -- скорость под оглушением
Config.BusySpeed = 9          -- скорость во время приёма (если приём не задал свою)
Config.RespawnTime = 4
Config.SpawnProtection = 2.5  -- неуязвимость после появления, с
Config.RegenDelay = 9         -- через сколько секунд без урона начинается лечение
Config.RegenPerSecond = 3
Config.ComboResetTime = 2.2   -- счётчик комбо сбрасывается, если долго не попадать
Config.InCombatTime = 6       -- столько секунд после урона нельзя сменить персонажа
Config.KillPlaneY = -60

-- M1 (обычные удары, ЛКМ). Четвёртый удар — добивающий.
Config.M1 = {
	Count = 4,
	Interval = 0.29,      -- минимум между ударами
	ComboWindow = 0.95,   -- если пауза дольше — серия начинается заново
	EndLag = 1.05,        -- пауза после четвёртого удара
	Windup = 0.09,        -- через сколько после замаха проверяется попадание
	Damage = 3.5,
	FinisherDamage = 5.5,
	Stun = 0.62,
	BusyTime = 0.24,
	BusySpeed = 11,
	HitboxSize = Vector3.new(5.6, 6, 6),
	Reach = 3.6,          -- центр хитбокса на столько впереди
	Knockback = 62,       -- отбрасывание добивающим
	KnockUp = 24,
	Ragdoll = 1.25,
	UppercutUp = 64,      -- пробел + 4-й удар
	DownslamDown = 95,    -- 4-й удар в воздухе
}

-- блок (F) и парирование
Config.Block = {
	ChipMult = 0.2,       -- сколько урона приёмов проходит сквозь блок
	MaxDurability = 9,    -- сколько ударов выдержит блок
	RegenPerSecond = 1.6,
	GuardBreakStun = 1.8,
	ParryWindow = 0.17,   -- если зажать блок прямо перед ударом — парирование
	ParryStun = 1.15,
	Speed = 7,
	FrontDot = -0.1,      -- блок держит удары спереди и сбоку
	Cooldown = 0.35,      -- после отпускания блока
}

-- рывок (Q): вперёд/назад/вбок
Config.Dash = {
	Speed = 90,
	Time = 0.26,
	FrontCooldown = 2.4,
	BackCooldown = 2.2,
	SideCooldown = 1.5,
	EvadeTime = 0.24,     -- боковой рывок уводит от M1
}

-- пробуждение (G): копится от урона
Config.Awaken = {
	Max = 100,
	PerDamageDealt = 1.15,
	PerDamageTaken = 0.55,
	Duration = 60,
	Heal = 25,
	SpeedMult = 1.14,
	DamageMult = 1.2,
	CooldownMult = 0.65,
	Invuln = 1.6,         -- неуязвимость во время позы пробуждения
}

-- территория (ульта трёх персонажей)
Config.Domain = {
	Radius = 42,
	Duration = 9,
	ClashDistance = 0.8,  -- если две территории ближе (r1+r2)*k — они ломают друг друга
}

-- боты
Config.Bots = {
	Default = 2,
	Max = 6,
	RespawnTime = 5,
	Names = { "Рэн", "Аки", "Сора", "Кайто", "Мирай", "Юки", "Харуто", "Нао", "Рику", "Мэй", "Дайки", "Хина" },
	Difficulty = {
		{ Name = "Лёгкие", React = 0.55, Block = 0.15, Aggro = 0.45, MoveChance = 0.25, Dash = 0.15 },
		{ Name = "Обычные", React = 0.32, Block = 0.35, Aggro = 0.7, MoveChance = 0.45, Dash = 0.3 },
		{ Name = "Сильные", React = 0.18, Block = 0.55, Aggro = 0.9, MoveChance = 0.7, Dash = 0.45 },
	},
	DefaultDifficulty = 2,
}

-- манекены в додзё
Config.Dummy = {
	HealDelay = 3,
	RespawnTime = 3,
}

-- ломающиеся предметы карты
Config.Breakables = {
	RestoreTime = 25,
}

-- клавиши ПК
Config.Keys = {
	Block = Enum.KeyCode.F,
	Dash = Enum.KeyCode.Q,
	Awaken = Enum.KeyCode.G,
	Menu = Enum.KeyCode.M,
	Moves = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four },
}

return Config
