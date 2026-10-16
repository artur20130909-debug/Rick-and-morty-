-- Всё, чем стреляют по постройке: от пули до ядерной бомбы и орбитального лазера.
--
-- origin   откуда летит: Tower (вышки у участка), Fort (вражеская база в море),
--          Bomber (самолёт), Sky (с неба), Orbit (спутник)
-- motion   Straight (по прямой), Ballistic (по дуге), Homing (самонаведение),
--          Cruise (низко над землёй, потом пикирует), Drop (падает), Parachute (на парашюте), Beam (луч)
-- radius   радиус взрыва (0 — без взрыва, только попадание)
-- blockDamage / playerDamage — урон блоку и игроку в эпицентре
-- aa       шанс, что турель ПВО собьёт снаряд
-- wave     с какой волны появляется в режиме «Выживание»
local Weapons = {}

Weapons.List = {
	{
		key = "Bullet", name = "Пуля", icon = "•", wave = 1, weight = 10,
		desc = "Очереди из пулемётных вышек вокруг участка.",
		origin = "Tower", motion = "Straight", speed = 520, gravity = 0,
		radius = 0, blockDamage = 14, playerDamage = 9, burst = 4, burstGap = 0.12, spread = 1.6,
		visual = "Tracer", color = Color3.fromRGB(255, 216, 120), launchSound = "Gunshot", fx = "Spark",
	},
	{
		key = "Shotgun", name = "Дробь", icon = "⁂", wave = 2, weight = 8,
		desc = "Девять дробинок веером. Опасна вблизи.",
		origin = "Tower", motion = "Straight", speed = 420, gravity = 0,
		radius = 0, blockDamage = 10, playerDamage = 6, pellets = 9, spread = 7,
		visual = "Tracer", color = Color3.fromRGB(255, 190, 110), launchSound = "Shotgun", fx = "Spark",
	},
	{
		key = "Minigun", name = "Пулемёт", icon = "⋯", wave = 3, weight = 7,
		desc = "Длинная очередь. Стены из мешков с песком держат лучше всего.",
		origin = "Tower", motion = "Straight", speed = 640, gravity = 0,
		radius = 0, blockDamage = 12, playerDamage = 5, burst = 22, burstGap = 0.06, spread = 2.6,
		visual = "Tracer", color = Color3.fromRGB(255, 240, 160), launchSound = "Minigun", fx = "Spark",
	},
	{
		key = "Grenade", name = "Граната", icon = "◉", wave = 4, weight = 7,
		desc = "Летит по дуге и взрывается от удара.",
		origin = "Tower", motion = "Ballistic", flightTime = 1.9, gravity = 196.2,
		radius = 8, blockDamage = 160, playerDamage = 38, aa = 0.3,
		visual = "Grenade", launchSound = "Thump", fx = "Small", shake = 0.4,
	},
	{
		key = "Mortar", name = "Миномёт", icon = "☄", wave = 5, weight = 6,
		desc = "Мина падает почти отвесно. Нужна крыша!",
		origin = "Fort", motion = "Ballistic", flightTime = 5.5, gravity = 90,
		radius = 11, blockDamage = 260, playerDamage = 52, aa = 0.35, warn = true,
		visual = "Shell", launchSound = "MortarLaunch", fx = "Medium", shake = 0.6,
	},
	{
		key = "RPG", name = "РПГ", icon = "➶", wave = 6, weight = 6,
		desc = "Реактивная граната с дымным следом.",
		origin = "Fort", motion = "Straight", speed = 150, gravity = 0,
		radius = 10, blockDamage = 320, playerDamage = 60, aa = 0.4,
		visual = "Rocket", launchSound = "RocketLaunch", loopSound = "RocketLoop", fx = "Medium", shake = 0.7,
	},
	{
		key = "Homing", name = "Самонаводящаяся ракета", icon = "➹", wave = 7, weight = 5,
		desc = "Взлетает вверх и сама летит за тобой. Прячься за стенами!",
		origin = "Fort", motion = "Homing", speed = 125, turnRate = 2.2, gravity = 0,
		radius = 11, blockDamage = 360, playerDamage = 64, aa = 0.45, lifetime = 14,
		visual = "Missile", launchSound = "RocketLaunch", loopSound = "RocketLoop", fx = "Medium", shake = 0.8,
	},
	{
		key = "Cluster", name = "Кассетная бомба", icon = "✺", wave = 8, weight = 4,
		desc = "Бомбардировщик сбрасывает кассету — она раскрывается на 12 бомб.",
		origin = "Bomber", motion = "Drop", speed = 0, gravity = 120,
		radius = 6, blockDamage = 170, playerDamage = 26, bomblets = 12, splitHeight = 70, splitSpread = 22, aa = 0.3,
		visual = "Bomb", launchSound = "Jet", fx = "Small", shake = 0.5,
	},
	{
		key = "Cruise", name = "Крылатая ракета", icon = "✈", wave = 9, weight = 3,
		desc = "Летит низко над водой и пикирует на цель.",
		origin = "Fort", motion = "Cruise", speed = 230, gravity = 0, cruiseHeight = 18,
		radius = 20, blockDamage = 950, playerDamage = 95, aa = 0.25, lifetime = 12,
		visual = "BigMissile", launchSound = "RocketLaunch", loopSound = "RocketLoop", fx = "Large", shake = 1.2, heavy = true,
	},
	{
		key = "Ballistic", name = "Баллистическая ракета", icon = "⇓", wave = 10, weight = 0,
		desc = "Падает из стратосферы. Огромный взрыв.",
		origin = "Sky", motion = "Drop", speed = 380, gravity = 0, dropHeight = 900,
		radius = 32, blockDamage = 1900, playerDamage = 130, aa = 0.15, warn = true,
		visual = "Reentry", launchSound = "Incoming", fx = "Huge", shake = 2, heavy = true,
	},
	{
		key = "Nuke", name = "Ядерная бомба", icon = "☢", wave = 11, weight = 0,
		desc = "Медленно опускается на парашюте... Выживет только тот, кто за толстыми стенами из свинца или бетона.",
		origin = "Sky", motion = "Parachute", speed = 50, gravity = 0, dropHeight = 520, burstHeight = 28,
		radius = 150, blockDamage = 12000, playerDamage = 300, aa = 0, warn = true,
		visual = "Nuke", launchSound = "Siren", fx = "Nuke", shake = 4, heavy = true,
	},
	{
		key = "Laser", name = "Орбитальный лазер", icon = "☼", wave = 12, weight = 0,
		desc = "Луч из космоса прожигает крышу слой за слоем и ползёт за тобой. Золото его отражает.",
		origin = "Orbit", motion = "Beam", chargeTime = 3, duration = 5.5, beamRadius = 5, trackSpeed = 7,
		radius = 5, blockDamage = 1100, playerDamage = 75, aa = 0,
		visual = "Laser", launchSound = "LaserCharge", loopSound = "LaserLoop", fx = "Laser", shake = 1.2, heavy = true,
	},
}

Weapons.ByKey = {}
for i, w in Weapons.List do
	w.index = i
	w.aa = w.aa or 0
	w.shake = w.shake or 0
	Weapons.ByKey[w.key] = w
end

-- Сколько стоит «перезарядка» в режиме Полигон
function Weapons.cooldown(w): number
	if w.heavy then
		return 6
	end
	return 0.35
end

-- Положение снаряда с постоянным ускорением (для клиента и сервера одинаково)
function Weapons.ballistic(p0: Vector3, v0: Vector3, g: number, t: number): Vector3
	return p0 + v0 * t + Vector3.new(0, -0.5 * g * t * t, 0)
end

-- Начальная скорость, чтобы попасть из p0 в p1 за время t при гравитации g
function Weapons.solveBallistic(p0: Vector3, p1: Vector3, g: number, t: number): Vector3
	local d = p1 - p0
	return Vector3.new(d.X / t, d.Y / t + 0.5 * g * t, d.Z / t)
end

return Weapons
