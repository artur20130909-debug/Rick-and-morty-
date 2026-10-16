-- Тесты чистой логики (без Roblox Studio). Запуск: lune run tools/test.luau
-- Модули из src/ReplicatedStorage/Shared загружаются как в игре: require(script.Parent.X) работает.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local SHARED = "src/ReplicatedStorage/Shared/"

-- Типы данных Roblox из Lune становятся глобальными, как в игре
local env = {}
for _, name in { "Vector3", "Vector2", "CFrame", "Color3", "Enum", "NumberRange", "NumberSequence", "ColorSequence", "UDim2", "UDim", "Font", "PhysicalProperties", "Instance", "NumberSequenceKeypoint", "ColorSequenceKeypoint" } do
	env[name] = (roblox :: any)[name]
end

local cache = {}
local function loadModule(name: string): any
	if cache[name] then
		return cache[name]
	end
	local source = fs.readFile(SHARED .. name .. ".lua")
	local moduleEnv = {}
	for k, v in env do
		moduleEnv[k] = v
	end
	-- script.Parent.X -> модуль X из той же папки
	moduleEnv.script = { Parent = setmetatable({}, { __index = function(_, k) return { __module = k } end }) }
	moduleEnv.require = function(m)
		if type(m) == "table" and m.__module then
			return loadModule(m.__module)
		end
		error("unsupported require")
	end
	local fn = luau.load(source, { debugName = name, environment = moduleEnv })
	local result = fn()
	cache[name] = result
	return result
end

local passed, failed = 0, 0
local function check(cond: boolean, msg: string)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL: " .. msg)
	end
end
local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-4)
end
local function vnear(a, b, eps: number?): boolean
	return (a - b).Magnitude <= (eps or 1e-3)
end

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3

-- Grid ------------------------------------------------------------------------------
local Grid = loadModule("Grid")
check(#Grid.Rotations == 24, "24 поворота")
check(Grid.rotIndex(Grid.Rotations[1]) == 1, "индекс единичного поворота")
for i, r in Grid.Rotations do
	check(Grid.rotIndex(r) == i, "rotIndex для поворота " .. i)
end
-- 4 поворота вокруг Y возвращают в исходное
local idx = 1
for _ = 1, 4 do
	idx = Grid.rotate(idx, "Y")
end
check(idx == 1, "4×R = исходный поворот")
idx = 1
for _ = 1, 4 do
	idx = Grid.rotate(idx, "X")
end
check(idx == 1, "4×T = исходный поворот")
check(Grid.rotate(1, "Y") ~= 1, "R меняет поворот")

-- габариты повёрнутого блока 2×4×6
local e1 = Grid.extents(Vector3.new(2, 4, 6), 1)
check(vnear(e1, Vector3.new(2, 4, 6)), "габариты без поворота")
local ry = Grid.rotate(1, "Y")
local e2 = Grid.extents(Vector3.new(2, 4, 6), ry)
check(vnear(e2, Vector3.new(6, 4, 2)), "габариты после R: X и Z меняются местами")
local rx = Grid.rotate(1, "X")
local e3 = Grid.extents(Vector3.new(2, 4, 6), rx)
check(vnear(e3, Vector3.new(2, 6, 4)), "габариты после T: Y и Z меняются местами")

-- установка на пол участка (повёрнутого на 30°)
local plotCF = CFrame.new(216.5, 5, 125) * CFrame.Angles(0, math.rad(-120), 0)
local hit = plotCF * Vector3.new(3.3, 0, -7.6)
local up = plotCF:VectorToWorldSpace(Vector3.new(0, 1, 0))
local c = Grid.placement(plotCF, hit, up, Vector3.new(2, 2, 2), 1)
check(vnear(c, Vector3.new(3, 1, -8)) or vnear(c, Vector3.new(4, 1, -8)) or vnear(c, Vector3.new(3, 1, -7)), "блок 2×2×2 на полу встаёт по сетке: " .. tostring(c))
check(Grid.isAligned(c, Vector3.new(2, 2, 2)), "выровнен по сетке")
check(Grid.inBounds(c, Vector3.new(2, 2, 2)), "внутри участка")
-- блок 3×1×1: центр на половинках
local c3 = Grid.placement(plotCF, hit, up, Vector3.new(3, 1, 1), 1)
check(Grid.isAligned(c3, Vector3.new(3, 1, 1)), "нечётный размер выровнен: " .. tostring(c3))
check(near(c3.Y, 0.5), "нечётная высота: центр на 0.5")
-- установка на боковую грань блока
local blockCenter = Vector3.new(0, 1, 0)
local sideHit = plotCF * (blockCenter + Vector3.new(1, 0.3, 0.2))
local sideNormal = plotCF:VectorToWorldSpace(Vector3.new(1, 0, 0))
local cs = Grid.placement(plotCF, sideHit, sideNormal, Vector3.new(2, 2, 2), 1)
check(vnear(cs, Vector3.new(2, 1, 0)), "на грань блока справа: " .. tostring(cs))
-- на верх блока
local topHit = plotCF * (blockCenter + Vector3.new(0.2, 1, -0.4))
local ct = Grid.placement(plotCF, topHit, up, Vector3.new(2, 2, 2), 1)
check(vnear(ct, Vector3.new(0, 3, 0)), "на верх блока: " .. tostring(ct))
-- границы
check(not Grid.inBounds(Vector3.new(32, 1, 0), Vector3.new(2, 2, 2)), "за краем X")
check(Grid.inBounds(Vector3.new(31, 1, 31), Vector3.new(2, 2, 2)), "угол участка — можно")
check(not Grid.inBounds(Vector3.new(0, 96, 0), Vector3.new(2, 2, 2)), "выше потолка")
check(not Grid.inBounds(Vector3.new(0, 0, 0), Vector3.new(2, 2, 2)), "ниже пола")
check(not Grid.isAligned(Vector3.new(0.3, 1, 0), Vector3.new(2, 2, 2)), "сдвинутый блок — не по сетке")
-- мировой CFrame и обратно
local wcf = Grid.worldCFrame(plotCF, Vector3.new(4, 3, -2), ry)
check(vnear(plotCF:PointToObjectSpace(wcf.Position), Vector3.new(4, 3, -2)), "worldCFrame ставит в нужную точку")
check(Grid.rotIndex(plotCF:ToObjectSpace(wcf)) == ry, "поворот сохраняется в системе участка")

-- Serializer ------------------------------------------------------------------------
local Serializer = loadModule("Serializer")
local specs = {
	{ mat = 5, shape = 2, item = 0, pos = Vector3.new(3, 1.5, -7.5), size = Vector3.new(2, 3, 1), rot = 7, color = Color3.fromRGB(10, 200, 255) },
	{ mat = 0, shape = 1, item = 3, pos = Vector3.new(-31, 2, 31), size = Vector3.new(1.5, 4, 4), rot = 24, color = Color3.fromRGB(30, 30, 32) },
}
local str = Serializer.encode(specs)
check(string.sub(str, 1, 3) == "v1|", "версия формата")
local back = Serializer.decode(str)
check(#back == 2, "раскодировано 2 блока")
check(back[1].mat == 5 and back[1].shape == 2 and back[1].rot == 7, "поля блока 1")
check(vnear(back[1].pos, specs[1].pos), "позиция блока 1")
check(back[1].color:ToHex() == specs[1].color:ToHex(), "цвет блока 1")
check(back[2].item == 3 and back[2].rot == 24, "особый блок")
check(Serializer.count(str) == 2, "count")
check(#Serializer.decode("мусор") == 0, "мусор не ломает загрузку")
check(#Serializer.decode("v1|1,2,3;bad") == 0, "битая строка пропускается")
check(Serializer.count("v1|") == 0, "пустая постройка")

-- Blocks ----------------------------------------------------------------------------
local Blocks = loadModule("Blocks")
check(#Blocks.Materials == 18, "18 материалов")
check(#Blocks.Items == 12, "12 особых блоков")
check(vnear(Blocks.normalizeSize(5, 0, Vector3.new(2, 5, 3), 16), Vector3.new(5, 5, 5)), "шар — одинаковый по осям")
check(vnear(Blocks.normalizeSize(4, 0, Vector3.new(6, 2, 3), 16), Vector3.new(6, 3, 3)), "цилиндр — круглый")
check(vnear(Blocks.normalizeSize(1, 0, Vector3.new(40, 0, 2.6), 16), Vector3.new(16, 1, 3)), "ограничение размеров")
check(vnear(Blocks.normalizeSize(1, 3, Vector3.new(9, 9, 9), 16), Blocks.ItemById[3].size), "колесо — фиксированный размер")
local wood = { mat = 1, shape = 1, item = 0 }
check(Blocks.maxHp(wood, Vector3.new(2, 2, 2)) == 100, "прочность дерева 2×2×2")
check(Blocks.maxHp(wood, Vector3.new(4, 4, 4)) == 800, "больше блок — больше прочность")
check(Blocks.maxHp({ mat = 1, shape = 2, item = 0 }, Vector3.new(2, 2, 2)) == 50, "клин — половина")
local prevPrice = -1
for _, m in Blocks.Materials do
	check(m.blast >= 0 and m.blast < 1 and m.nuke >= 0 and m.nuke < 1, "защита в пределах 0..1: " .. m.key)
	check(m.price >= 0, "цена: " .. m.key)
	prevPrice = m.price
end
local _ = prevPrice

-- Weapons ---------------------------------------------------------------------------
local Weapons = loadModule("Weapons")
check(#Weapons.List == 12, "12 видов оружия")
for i, w in Weapons.List do
	check(w.wave == i, "оружие " .. w.key .. " появляется на волне " .. i)
end
local p0, p1 = Vector3.new(-300, 9, 40), Vector3.new(210, 6, 130)
for _, g in { 90, 196.2 } do
	local v0 = Weapons.solveBallistic(p0, p1, g, 5.5)
	check(vnear(Weapons.ballistic(p0, v0, g, 5.5), p1, 0.01), "баллистика попадает в цель (g=" .. g .. ")")
end
check(Weapons.ByKey.Nuke.radius > Weapons.ByKey.Ballistic.radius, "ядерка мощнее баллистики")

-- Util ------------------------------------------------------------------------------
local Util = loadModule("Util")
check(Util.formatNumber(1250000) == "1 250 000", "формат числа: " .. Util.formatNumber(1250000))
check(Util.formatNumber(999) == "999", "формат 999")
check(Util.formatNumber(1000) == "1 000", "формат 1000")
check(Util.plural(1, "блок", "блока", "блоков") == "блок", "1 блок")
check(Util.plural(3, "блок", "блока", "блоков") == "блока", "3 блока")
check(Util.plural(11, "блок", "блока", "блоков") == "блоков", "11 блоков")
check(Util.plural(22, "блок", "блока", "блоков") == "блока", "22 блока")
check(Util.formatTime(125) == "2:05", "время")

-- MapLayout -------------------------------------------------------------------------
local MapLayout = loadModule("MapLayout")
check(#MapLayout.Plots == 6, "6 участков")
for _, p in MapLayout.Plots do
	check(#p.towers == 4 and #p.rails == 3 and #p.silos == 4 and #p.mortars == 3, "точки запуска у участка " .. p.index)
	local look = p.cf.LookVector
	local toCenter = (Vector3.new(0, p.cf.Position.Y, 0) - p.cf.Position).Unit
	check(look:Dot(toCenter) > 0.99, "участок " .. p.index .. " смотрит на лобби")
	check(near(p.cf.Position.Y, MapLayout.Floor), "пол участка на высоте " .. MapLayout.Floor)
end
check(#MapLayout.Terrain > 20, "рельеф описан")

-- BlockFactory: каждый материал × каждая форма и каждый особый блок собираются без ошибок
local BlockFactory = loadModule("BlockFactory")
local built = 0
for _, m in Blocks.Materials do
	for _, sh in Blocks.Shapes do
		local spec = { mat = m.id, shape = sh.id, item = 0, size = Blocks.normalizeSize(sh.id, 0, Vector3.new(2, 3, 4), 16), rot = 1, color = m.color }
		local ok, part = pcall(BlockFactory.build, spec, CFrame.new(1, 2, 3), {})
		check(ok, "сборка " .. m.key .. "/" .. sh.key .. ": " .. tostring(part))
		if ok then
			built += 1
			check(part.Name == "Block", "имя Block")
			check(vnear(part.CFrame.Position, Vector3.new(1, 2, 3)), "позиция блока")
			local expected = sh.id == 2 and "WedgePart" or (sh.id == 3 and "CornerWedgePart" or "Part")
			check(part.ClassName == expected, "класс " .. part.ClassName .. " для формы " .. sh.key)
		end
	end
end
for _, it in Blocks.Items do
	for _, opts in { {}, { ghost = true }, { preview = true } } do
		local spec = { mat = 0, shape = 1, item = it.id, size = it.size, rot = 1, color = it.color }
		local ok, part = pcall(BlockFactory.build, spec, CFrame.new(0, 5, 0), opts)
		check(ok, "сборка особого блока " .. it.key .. ": " .. tostring(part))
		if ok then
			built += 1
			check(part.ClassName == (it.class or "Part"), "класс " .. it.key)
			local solid = opts.ghost == nil and opts.preview == nil
			for _, d in part:GetDescendants() do
				if d:IsA("BasePart") then
					if d.Name == "DoorLeaf" then
						-- полотно двери — твёрдое (кроме призрака и иконки), но лучи его не видят
						check(d.CanQuery == false and d.CanCollide == solid, "полотно двери: столкновения только у настоящей двери")
					else
						check(d.CanQuery == false and d.CanCollide == false, "декор не мешает лучам: " .. it.key)
					end
				end
			end
		end
	end
end
check(built == 18 * 5 + 12 * 3, "собрано блоков: " .. built)

-- Габариты детали в мире (AABB) по CFrame и Size
local function aabb(p)
	local cf, s = p.CFrame, p.Size
	local x, y, z = cf.XVector, cf.YVector, cf.ZVector
	local h = Vector3.new(
		math.abs(x.X) * s.X + math.abs(y.X) * s.Y + math.abs(z.X) * s.Z,
		math.abs(x.Y) * s.X + math.abs(y.Y) * s.Y + math.abs(z.Y) * s.Z,
		math.abs(x.Z) * s.X + math.abs(y.Z) * s.Y + math.abs(z.Z) * s.Z
	) / 2
	return { lo = cf.Position - h, hi = cf.Position + h, part = p }
end
local function touching(a, b, tol: number): boolean
	return a.lo.X <= b.hi.X + tol and b.lo.X <= a.hi.X + tol
		and a.lo.Y <= b.hi.Y + tol and b.lo.Y <= a.hi.Y + tol
		and a.lo.Z <= b.hi.Z + tol and b.lo.Z <= a.hi.Z + tol
end
local function inside(a, b, tol: number): boolean
	return a.lo.X >= b.lo.X - tol and a.lo.Y >= b.lo.Y - tol and a.lo.Z >= b.lo.Z - tol
		and a.hi.X <= b.hi.X + tol and a.hi.Y <= b.hi.Y + tol and a.hi.Z <= b.hi.Z + tol
end
local function buildItem(key: string, size: any?, opts: any?)
	local it = Blocks.ItemByKey[key]
	local spec = { mat = 0, shape = 1, item = it.id, size = size or it.size, rot = 1, color = it.color }
	return BlockFactory.build(spec, CFrame.new(3, 6, -2) * CFrame.Angles(0, math.rad(30), 0), opts or {})
end
local function decorOf(part)
	local list = {}
	for _, d in part:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- Декор не висит в воздухе: от главной детали до каждой детали можно дойти по касающимся
-- габаритам (допуск 0.05)
for _, it in Blocks.Items do
	local part = buildItem(it.key)
	local boxes = { aabb(part) }
	for _, d in decorOf(part) do
		table.insert(boxes, aabb(d))
	end
	local reached = { [1] = true }
	local queue = { 1 }
	while #queue > 0 do
		local i = table.remove(queue)
		for j = 1, #boxes do
			if not reached[j] and touching(boxes[i], boxes[j], 0.05) then
				reached[j] = true
				table.insert(queue, j)
			end
		end
	end
	for j = 2, #boxes do
		local d = boxes[j].part
		check(reached[j] == true, it.key .. ": деталь висит в воздухе " .. d.Name .. " " .. tostring(d.Size)
			.. " в " .. tostring(part.CFrame:PointToObjectSpace(d.CFrame.Position)))
	end
end

-- Турель ПВО: каждая деталь касается другой детали или самого блока; не больше 16 деталей
do
	local turret = buildItem("AATurret")
	local parts = decorOf(turret)
	check(#parts <= 16 and #parts >= 10, "турель ПВО: деталей декора " .. #parts)
	local boxes = { aabb(turret) }
	for _, d in parts do
		table.insert(boxes, aabb(d))
	end
	local wedges = 0
	for i = 2, #boxes do
		local ok = false
		for j = 1, #boxes do
			if j ~= i and touching(boxes[i], boxes[j], 0.05) then
				ok = true
				break
			end
		end
		check(ok, "турель ПВО: деталь ни к чему не прилегает " .. tostring(boxes[i].part.Size))
		if boxes[i].part.ClassName == "WedgePart" then
			wedges += 1
		end
	end
	check(wedges >= 1, "турель ПВО: есть наклонная броня")
end

-- Дверь: невидимая главная деталь, полотно на Weld, коробка и полотно красятся с блоком
do
	local door = buildItem("Door")
	check(door.Transparency == 1 and door.CanCollide == false and door.CanQuery == true and door.CastShadow == false,
		"дверь: главная деталь прозрачная, без столкновений, но видна лучам")
	local leaf = door:FindFirstChild("DoorLeaf")
	check(leaf ~= nil and leaf:IsA("BasePart"), "дверь: есть полотно DoorLeaf")
	if leaf then
		check(leaf.CanCollide == true and leaf.CanQuery == false and leaf.Massless == true, "дверь: полотно твёрдое, лучи его не видят")
		local hinge = leaf:FindFirstChild("DoorHinge")
		check(hinge ~= nil and hinge.ClassName == "Weld", "дверь: полотно держит Weld DoorHinge")
		if hinge then
			check(hinge.Part0 == door and hinge.Part1 == leaf, "дверь: Weld от блока к полотну")
			local expected = door.CFrame * hinge.C0 * hinge.C1:Inverse()
			check(vnear(leaf.CFrame.Position, expected.Position) and vnear(leaf.CFrame.LookVector, expected.LookVector),
				"дверь: полотно стоит там, куда его ставит Weld")
			-- открытая дверь (как в Specials): полотно уходит из проёма к петлям
			local opened = door.CFrame * (CFrame.new(hinge.C0.Position) * CFrame.Angles(0, math.rad(95), 0)) * hinge.C1:Inverse()
			local lp = door.CFrame:PointToObjectSpace(opened.Position)
			local hp = hinge.C0.Position
			check(math.abs(lp.X - hp.X) < 0.3 and math.abs(lp.Z) > leaf.Size.X * 0.45, "дверь: открытое полотно освобождает проём " .. tostring(lp))
		end
		check(inside(aabb(leaf), aabb(door), 0.01), "дверь: закрытое полотно внутри блока")
		local onLeaf = 0
		for _, d in leaf:GetDescendants() do
			if d:IsA("BasePart") then
				onLeaf += 1
			end
		end
		check(onLeaf >= 8, "дверь: на полотне филёнки, окошко, ручка и петли: " .. onLeaf)
	end
	-- в призраке и иконке полотно без столкновений
	for _, opts in { { ghost = true }, { preview = true } } do
		local d2 = buildItem("Door", nil, opts)
		local l2 = d2:FindFirstChild("DoorLeaf")
		check(l2 ~= nil and l2.CanCollide == false, "дверь-призрак/иконка: полотно без столкновений")
	end
	-- дверь любого размера собирается, детали не вылезают за блок (кроме ручки)
	for _, size in { Vector3.new(1, 1, 1), Vector3.new(2, 3, 1), Vector3.new(6, 9, 2), Vector3.new(16, 16, 16) } do
		local ok, d = pcall(buildItem, "Door", size)
		check(ok, "дверь " .. tostring(size) .. ": " .. tostring(d))
		if ok then
			for _, p in decorOf(d) do
				check(p.Size.X > 0 and p.Size.Y > 0 and p.Size.Z > 0, "дверь " .. tostring(size) .. ": размер детали > 0")
			end
			local l = d:FindFirstChild("DoorLeaf")
			check(l ~= nil and inside(aabb(l), aabb(d), 0.01), "дверь " .. tostring(size) .. ": полотно в проёме")
		end
	end

	-- applyColor: блок и детали с Tint перекрашиваются, остальные — нет
	local before = {}
	for _, p in decorOf(door) do
		before[p] = p.Color
	end
	local red = Color3.fromRGB(200, 40, 40)
	BlockFactory.applyColor(door, red)
	check(door.Color == red, "applyColor: цвет блока")
	local tintedCount = 0
	for _, p in decorOf(door) do
		local k = p:GetAttribute("Tint")
		if type(k) == "number" then
			tintedCount += 1
			local c = p.Color
			check(near(c.R, math.min(red.R * k, 1), 0.01) and near(c.G, math.min(red.G * k, 1), 0.01) and near(c.B, math.min(red.B * k, 1), 0.01),
				"applyColor: деталь с Tint " .. k .. " в цвет блока")
		else
			check(p.Color == before[p], "applyColor: деталь без Tint не меняется (" .. p.Name .. ")")
		end
	end
	check(tintedCount >= 8, "дверь: полотно, филёнки и коробка помечены Tint: " .. tintedCount)
	local leafTint = leaf and leaf:GetAttribute("Tint")
	check(leafTint == 1, "дверь: полотно — цвет блока")
	-- коробка темнее полотна
	local darker = 0
	for _, p in door:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Decor" and type(p:GetAttribute("Tint")) == "number" and p:GetAttribute("Tint") < 1 then
			darker += 1
		end
	end
	check(darker == 3, "дверь: коробка из трёх деталей темнее полотна: " .. darker)
end

-- Примеры построек: в сетке, внутри участка, без пересечений, колёса на что-то опираются
local Examples = loadModule("Examples")
check(#Examples == 4, "4 примера")
local Config = loadModule("Config")
for _, ex in Examples do
	local list = Serializer.decode(ex.data)
	check(#list > 10, "пример «" .. ex.name .. "» не пустой")
	check(#list <= Config.MaxBlocks, "пример в лимите")
	local boxes = {}
	for _, b in list do
		local size = Blocks.normalizeSize(b.shape, b.item, b.size, Config.MaxBlockSize)
		check(vnear(size, b.size), ex.name .. ": размер не меняется при загрузке " .. tostring(b.size))
		local e = Grid.extents(b.size, b.rot)
		check(Grid.isAligned(b.pos, e), ex.name .. ": блок в сетке " .. tostring(b.pos))
		check(Grid.inBounds(b.pos, e), ex.name .. ": блок внутри участка " .. tostring(b.pos))
		table.insert(boxes, { lo = b.pos - e / 2, hi = b.pos + e / 2, b = b })
	end
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			local a, c = boxes[i], boxes[j]
			local ox = math.min(a.hi.X, c.hi.X) - math.max(a.lo.X, c.lo.X)
			local oy = math.min(a.hi.Y, c.hi.Y) - math.max(a.lo.Y, c.lo.Y)
			local oz = math.min(a.hi.Z, c.hi.Z) - math.max(a.lo.Z, c.lo.Z)
			check(not (ox > 0.05 and oy > 0.05 and oz > 0.05), ex.name .. ": пересекаются блоки " .. tostring(a.b.pos) .. " и " .. tostring(c.b.pos))
		end
	end
	-- колесо должно касаться боком не-колеса (иначе не будет шарнира)
	for _, w in boxes do
		if w.b.item == 3 then
			local ok = false
			for _, c in boxes do
				if c.b.item ~= 3 then
					local touchX = math.abs(c.hi.X - w.lo.X) < 0.01 or math.abs(c.lo.X - w.hi.X) < 0.01
					local oy = math.min(w.hi.Y, c.hi.Y) - math.max(w.lo.Y, c.lo.Y)
					local oz = math.min(w.hi.Z, c.hi.Z) - math.max(w.lo.Z, c.lo.Z)
					if touchX and oy > 0.5 and oz > 0.5 then
						ok = true
					end
				end
			end
			check(ok, ex.name .. ": колесо " .. tostring(w.b.pos) .. " прикреплено сбоку")
		end
	end
end

print(string.format("\nПройдено: %d, провалено: %d", passed, failed))
if failed > 0 then
	error("есть проваленные тесты")
end
