-- Каталог всего, из чего можно строить: материалы, формы и особые блоки.
--
-- Поля материала:
--   hp        прочность блока 2×2×2 (больше блок — больше прочность)
--   price     цена в магазине (0 = есть сразу)
--   blast     сколько урона от взрыва блок задерживает для того, что за ним (0..0.95)
--   nuke      то же для ядерного удара и радиации
--   bulletMul / explMul / laserMul — множители урона, который получает сам блок
--   regen     восстановление прочности в секунду (доля от максимума)
--   density   плотность для испытаний (меньше 1 — плавает в воде)
local Blocks = {}

Blocks.Shapes = {
	{ id = 1, key = "Block", name = "Блок", volume = 1 },
	{ id = 2, key = "Wedge", name = "Клин", volume = 0.5 },
	{ id = 3, key = "CornerWedge", name = "Угол", volume = 1 / 3 },
	{ id = 4, key = "Cylinder", name = "Цилиндр", volume = 0.785 },
	{ id = 5, key = "Ball", name = "Шар", volume = 0.524 },
}

local M = Enum.Material

Blocks.Materials = {
	{ id = 1, key = "Wood", name = "Дерево", material = M.WoodPlanks, color = Color3.fromRGB(161, 115, 72),
		hp = 100, price = 0, blast = 0.35, nuke = 0.2, density = 0.5, desc = "Дешёвое и лёгкое. Плавает в воде." },
	{ id = 2, key = "Plastic", name = "Пластик", material = M.SmoothPlastic, color = Color3.fromRGB(232, 232, 236),
		hp = 70, price = 0, blast = 0.25, nuke = 0.15, density = 0.7, desc = "Красится в любой цвет. Для декора." },
	{ id = 3, key = "Brick", name = "Кирпич", material = M.Brick, color = Color3.fromRGB(168, 84, 62),
		hp = 220, price = 120, blast = 0.5, nuke = 0.35, density = 1.9, desc = "Классика для первого бункера." },
	{ id = 4, key = "Stone", name = "Камень", material = M.Cobblestone, color = Color3.fromRGB(128, 128, 124),
		hp = 320, price = 250, blast = 0.55, nuke = 0.4, density = 2.4, desc = "Крепкий булыжник." },
	{ id = 5, key = "Concrete", name = "Бетон", material = M.Concrete, color = Color3.fromRGB(162, 162, 157),
		hp = 420, price = 400, blast = 0.62, nuke = 0.5, density = 2.4, desc = "Основа любого бункера." },
	{ id = 6, key = "Glass", name = "Стекло", material = M.Glass, color = Color3.fromRGB(170, 214, 235), transparency = 0.45, reflectance = 0.15,
		hp = 50, price = 60, blast = 0.1, nuke = 0.05, density = 2.4, desc = "Красиво, но хрупко." },
	{ id = 7, key = "Ice", name = "Лёд", material = M.Ice, color = Color3.fromRGB(176, 222, 255), transparency = 0.15,
		hp = 90, price = 150, blast = 0.3, nuke = 0.2, density = 0.9, desc = "Скользкий. Плавает." },
	{ id = 8, key = "Neon", name = "Неон", material = M.Neon, color = Color3.fromRGB(0, 255, 210),
		hp = 80, price = 200, blast = 0.2, nuke = 0.1, density = 1, desc = "Светится. Для красоты." },
	{ id = 9, key = "Sandbag", name = "Мешки с песком", material = M.Fabric, color = Color3.fromRGB(196, 172, 124),
		hp = 260, price = 300, blast = 0.55, nuke = 0.35, bulletMul = 0.25, density = 1.6, desc = "Пули почти не берут." },
	{ id = 10, key = "Rubber", name = "Резина", material = M.Rubber, color = Color3.fromRGB(44, 44, 48),
		hp = 240, price = 450, blast = 0.45, nuke = 0.3, explMul = 0.55, density = 1.2, desc = "Гасит ударную волну." },
	{ id = 11, key = "Metal", name = "Металл", material = M.DiamondPlate, color = Color3.fromRGB(152, 157, 162),
		hp = 650, price = 800, blast = 0.7, nuke = 0.55, density = 7.8, desc = "Рифлёный стальной лист." },
	{ id = 12, key = "ArmorGlass", name = "Бронестекло", material = M.Glass, color = Color3.fromRGB(120, 184, 255), transparency = 0.3, reflectance = 0.25,
		hp = 700, price = 1800, blast = 0.7, nuke = 0.4, bulletMul = 0.4, density = 2.6, desc = "Видно всё, а пули — нет." },
	{ id = 13, key = "Steel", name = "Броня", material = M.Metal, color = Color3.fromRGB(88, 94, 102),
		hp = 1000, price = 1500, blast = 0.78, nuke = 0.6, density = 7.8, desc = "Танковая броня." },
	{ id = 14, key = "Lead", name = "Свинец", material = M.CorrodedMetal, color = Color3.fromRGB(96, 102, 124),
		hp = 800, price = 2600, blast = 0.7, nuke = 0.9, density = 11, desc = "Лучшая защита от радиации." },
	{ id = 15, key = "Titanium", name = "Титан", material = M.Metal, color = Color3.fromRGB(206, 210, 220), reflectance = 0.1,
		hp = 1800, price = 4000, blast = 0.85, nuke = 0.7, density = 4.5, desc = "Лёгкий и сверхпрочный." },
	{ id = 16, key = "Obsidian", name = "Обсидиан", material = M.Basalt, color = Color3.fromRGB(44, 26, 60),
		hp = 2800, price = 7000, blast = 0.9, nuke = 0.8, density = 2.6, desc = "Почти неразрушим." },
	{ id = 17, key = "Gold", name = "Золото", material = M.Foil, color = Color3.fromRGB(255, 204, 64), reflectance = 0.35,
		hp = 500, price = 10000, blast = 0.6, nuke = 0.7, laserMul = 0.25, density = 19, desc = "Отражает орбитальный лазер." },
	{ id = 18, key = "Crystal", name = "Энергокристалл", material = M.Glass, color = Color3.fromRGB(80, 255, 240), transparency = 0.12, reflectance = 0.3,
		hp = 1500, price = 12000, blast = 0.82, nuke = 0.75, regen = 0.03, density = 1, desc = "Сам восстанавливает прочность." },
}

-- Особые блоки. Их размер фиксирован (кроме тех, где resizable = true; minSize — наименьший размер).
-- iconYaw — поворот модели на иконке в интерфейсе (камера иконки смотрит на блок сзади-справа).
Blocks.Items = {
	{ id = 1, key = "Seat", name = "Сиденье", class = "Seat", size = Vector3.new(2, 1, 2), material = M.WoodPlanks,
		color = Color3.fromRGB(140, 96, 60), hp = 150, price = 0, density = 0.6, desc = "На нём можно сидеть." },
	{ id = 2, key = "DriverSeat", name = "Кресло водителя", class = "VehicleSeat", size = Vector3.new(2, 1, 2), material = M.SmoothPlastic,
		color = Color3.fromRGB(46, 48, 54), hp = 200, price = 250, density = 0.8, desc = "Управляет колёсами и двигателями (WASD)." },
	{ id = 3, key = "Wheel", name = "Колесо", shape = "Cylinder", size = Vector3.new(2, 4, 4), material = M.Rubber,
		color = Color3.fromRGB(30, 30, 32), hp = 300, price = 200, density = 1, desc = "Крутится от кресла водителя." },
	{ id = 4, key = "Thruster", name = "Реактивный двигатель", shape = "Cylinder", size = Vector3.new(3, 2, 2), material = M.Metal,
		color = Color3.fromRGB(110, 114, 122), hp = 300, price = 600, density = 1, desc = "Толкает постройку вперёд (W)." },
	{ id = 5, key = "Balloon", name = "Воздушный шар", shape = "Ball", size = Vector3.new(4, 4, 4), material = M.SmoothPlastic,
		color = Color3.fromRGB(235, 64, 52), hp = 40, price = 300, density = 0.1, desc = "Поднимает постройку в воздух." },
	{ id = 6, key = "Door", name = "Дверь", size = Vector3.new(4, 7, 1), resizable = true, minSize = Vector3.new(2, 3, 1),
		material = M.WoodPlanks, color = Color3.fromRGB(120, 82, 50), hp = 400, price = 150, density = 0.6, desc = "Открывается кнопкой E." },
	{ id = 7, key = "Lamp", name = "Лампа", size = Vector3.new(1, 1, 1), resizable = true, material = M.Neon,
		color = Color3.fromRGB(255, 226, 160), hp = 50, price = 50, density = 1, desc = "Светит в бункере." },
	{ id = 8, key = "Flag", name = "Флаг", size = Vector3.new(1, 8, 1), material = M.Metal,
		color = Color3.fromRGB(200, 200, 205), hp = 60, price = 50, density = 1, desc = "Флаг цвета твоего участка." },
	{ id = 9, key = "TNT", name = "Динамит", size = Vector3.new(2, 2, 2), material = M.SmoothPlastic,
		color = Color3.fromRGB(200, 40, 36), hp = 30, price = 100, density = 1, desc = "Взрывается, если его разрушить!" },
	{ id = 10, key = "Medkit", name = "Аптечка", size = Vector3.new(2, 2, 2), material = M.SmoothPlastic,
		color = Color3.fromRGB(240, 240, 240), hp = 200, price = 1200, density = 1, desc = "Лечит всех рядом (10 стадов)." },
	{ id = 11, key = "AATurret", name = "Турель ПВО", size = Vector3.new(3, 2, 3), material = M.Metal,
		color = Color3.fromRGB(70, 82, 70), hp = 900, price = 3500, density = 3, desc = "Сбивает ракеты и снаряды на подлёте." },
	{ id = 12, key = "Shield", name = "Генератор щита", size = Vector3.new(3, 3, 3), material = M.Metal,
		color = Color3.fromRGB(60, 70, 96), hp = 800, price = 6000, density = 3, desc = "Купол радиусом 18, держит 2500 урона." },
	{ id = 13, key = "Guard", name = "Охранник", size = Vector3.new(2, 5, 2), material = M.Fabric,
		color = Color3.fromRGB(72, 86, 60), hp = 350, price = 9000, density = 1, blast = 0.25, nuke = 0.15, iconYaw = math.rad(200),
		desc = "Солдат с автоматом: сбивает ракеты и дроны рядом с собой." },
}

Blocks.ShieldRadius = 18
Blocks.ShieldHp = 2500
Blocks.ShieldRecharge = 18
Blocks.AARange = 85
Blocks.AACooldown = 1.1
Blocks.MedkitRange = 10
Blocks.GuardRange = 55      -- охранник стреляет по снарядам ближе этого расстояния
Blocks.GuardCooldown = 0.55 -- секунд между очередями одного охранника
Blocks.GuardChance = 0.5    -- шанс сбить = шанс турели ПВО для этого оружия (aa) × GuardChance

Blocks.MaterialById = {}
Blocks.MaterialByKey = {}
for _, m in Blocks.Materials do
	Blocks.MaterialById[m.id] = m
	Blocks.MaterialByKey[m.key] = m
	m.blast = m.blast or 0.3
	m.nuke = m.nuke or 0.2
	m.bulletMul = m.bulletMul or 1
	m.explMul = m.explMul or 1
	m.laserMul = m.laserMul or 1
	m.transparency = m.transparency or 0
	m.reflectance = m.reflectance or 0
end

Blocks.ItemById = {}
Blocks.ItemByKey = {}
for _, it in Blocks.Items do
	Blocks.ItemById[it.id] = it
	Blocks.ItemByKey[it.key] = it
	it.blast = it.blast or 0.5
	it.nuke = it.nuke or 0.4
	it.bulletMul = 1
	it.explMul = 1
	it.laserMul = 1
end

Blocks.ShapeById = {}
for _, s in Blocks.Shapes do
	Blocks.ShapeById[s.id] = s
end

-- Ключ для разблокировки в магазине: "m:Brick" или "i:Wheel"
function Blocks.unlockKey(kind: string, id: number): string
	if kind == "item" then
		return "i:" .. Blocks.ItemById[id].key
	end
	return "m:" .. Blocks.MaterialById[id].key
end

-- Описание блока (материал или особый) по спецификации
function Blocks.def(spec)
	if spec.item and spec.item > 0 then
		return Blocks.ItemById[spec.item]
	end
	return Blocks.MaterialById[spec.mat]
end

local function clampInt(v, lo, hi)
	v = math.floor((tonumber(v) or lo) + 0.5)
	return math.clamp(v, lo, hi)
end

-- Приводит размер к допустимому: целые стады, ограничения формы (шар — одинаковый по всем осям,
-- цилиндр — круглый), фиксированный размер у особых блоков, не меньше minSize (дверь — настоящая дверь).
function Blocks.normalizeSize(shapeId: number, itemId: number, size: Vector3, maxSize: number): Vector3
	if itemId and itemId > 0 then
		local it = Blocks.ItemById[itemId]
		if not it.resizable then
			return it.size
		end
		local lo: Vector3 = it.minSize or Vector3.one
		return Vector3.new(clampInt(size.X, lo.X, maxSize), clampInt(size.Y, lo.Y, maxSize), clampInt(size.Z, lo.Z, maxSize))
	end
	local x, y, z = clampInt(size.X, 1, maxSize), clampInt(size.Y, 1, maxSize), clampInt(size.Z, 1, maxSize)
	if shapeId == 5 then
		local d = math.max(x, y, z)
		return Vector3.new(d, d, d)
	elseif shapeId == 4 then
		local d = math.max(y, z)
		return Vector3.new(x, d, d)
	end
	return Vector3.new(x, y, z)
end

-- Максимальная прочность конкретного блока
function Blocks.maxHp(spec, size: Vector3): number
	local d = Blocks.def(spec)
	local volume = size.X * size.Y * size.Z
	if not (spec.item and spec.item > 0) then
		volume *= Blocks.ShapeById[spec.shape or 1].volume
	end
	local k = math.clamp(volume / 8, 0.25, 8)
	return math.floor(d.hp * k + 0.5)
end

return Blocks
