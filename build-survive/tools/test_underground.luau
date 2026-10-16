-- Тесты подземелья (клетки земли, маска, сборка слоёв) и формата сохранений v2.
-- Запуск: lune run tools/test_underground.luau
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
local function vnear(a, b, eps: number?): boolean
	return (a - b).Magnitude <= (eps or 1e-3)
end

local Vector3 = roblox.Vector3
local Color3 = roblox.Color3

local Config = loadModule("Config")
local UG = loadModule("Underground")
local Grid = loadModule("Grid")
local Serializer = loadModule("Serializer")

-- Случайные числа с постоянным зерном (Random из Roblox в Lune нет)
math.randomseed(20261016)
local rng = {
	NextNumber = function(_): number
		return math.random()
	end,
	NextInteger = function(_, lo: number, hi: number): number
		return math.random(lo, hi)
	end,
}

-- Размеры -----------------------------------------------------------------------------
check(UG.CELL == Config.Underground.Cell and UG.CELL == 4, "клетка 4 стада")
check(UG.DEPTH == Config.Underground.Depth and UG.DEPTH == 24, "глубина 24")
check(UG.NX == 16 and UG.NY == 6 and UG.NZ == 16, "сетка 16×6×16")
check(UG.COUNT == 1536, "1536 клеток")

-- Индексы -----------------------------------------------------------------------------
do
	local seen = {}
	local okAll, okFormula, okRange = true, true, true
	for iy = 1, UG.NY do
		for iz = 1, UG.NZ do
			for ix = 1, UG.NX do
				local i = UG.index(ix, iy, iz)
				if i ~= (iy - 1) * 256 + (iz - 1) * 16 + (ix - 1) then
					okFormula = false
				end
				if i < 0 or i >= UG.COUNT or seen[i] then
					okRange = false
				end
				seen[i] = true
				local x, y, z = UG.coords(i)
				if x ~= ix or y ~= iy or z ~= iz then
					okAll = false
				end
			end
		end
	end
	check(okFormula, "индекс по формуле из спецификации")
	check(okRange, "индексы 0..1535 без повторов")
	check(okAll, "index → coords → те же клетки")
	local okBack = true
	for i = 0, UG.COUNT - 1 do
		if UG.index(UG.coords(i)) ~= i then
			okBack = false
		end
	end
	check(okBack, "coords → index для всех клеток")
end

check(UG.inRange(1, 1, 1) and UG.inRange(16, 6, 16), "углы сетки в диапазоне")
check(not UG.inRange(0, 1, 1) and not UG.inRange(17, 1, 1), "X вне сетки")
check(not UG.inRange(1, 0, 1) and not UG.inRange(1, 7, 1), "Y вне сетки")
check(not UG.inRange(1, 1, 0) and not UG.inRange(1, 1, 17), "Z вне сетки")
check(not UG.inRange(1.5, 1, 1), "дробная клетка — не в диапазоне")
check(not UG.inRange(0 / 0, 1, 1), "NaN — не в диапазоне")
check(not UG.inRange(math.huge, 1, 1), "бесконечность — не в диапазоне")

-- Центры клеток и поиск клетки по точке -------------------------------------------------
check(vnear(UG.cellCenter(1, 1, 1), Vector3.new(-30, -2, -30)), "центр первой клетки")
check(vnear(UG.cellCenter(16, 6, 16), Vector3.new(30, -22, 30)), "центр последней клетки")
do
	local ok = true
	for i = 0, UG.COUNT - 1 do
		local ix, iy, iz = UG.coords(i)
		local c = UG.cellCenter(ix, iy, iz)
		local x, y, z = UG.cellAt(c)
		if x ~= ix or y ~= iy or z ~= iz then
			ok = false
		end
		-- углы клетки чуть внутри
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local p = c + Vector3.new(sx, sy, sz) * 1.99
					local px, py, pz = UG.cellAt(p)
					if px ~= ix or py ~= iy or pz ~= iz then
						ok = false
					end
				end
			end
		end
	end
	check(ok, "cellAt(cellCenter) и углы клеток — та же клетка")
end
check(UG.cellAt(Vector3.new(0, 0.5, 0)) == nil, "над полом — не клетка")
check(UG.cellAt(Vector3.new(0, -24.01, 0)) == nil, "ниже дна — не клетка")
check(UG.cellAt(Vector3.new(32.5, -2, 0)) == nil, "за краем участка — не клетка")
check(UG.cellAt(Vector3.new(0 / 0, -2, 0)) == nil, "NaN — не клетка")
do
	local ix, iy, iz = UG.cellAt(Vector3.new(-32, -0.001, 31.999))
	check(ix == 1 and iy == 1 and iz == 16, "точка на краю участка у пола")
end

-- Клетки под коробкой блока -------------------------------------------------------------
local function sorted(list: { number }): { number }
	local copy = table.clone(list)
	table.sort(copy)
	return copy
end
local function sameList(a: { number }, b: { number }): boolean
	if #a ~= #b then
		return false
	end
	local sa, sb = sorted(a), sorted(b)
	for i = 1, #sa do
		if sa[i] ~= sb[i] then
			return false
		end
	end
	return true
end

check(#UG.cellsInBox(Vector3.new(0, 1, 0), Vector3.new(2, 2, 2)) == 0, "блок на полу — без клеток")
check(#UG.cellsInBox(Vector3.new(5, 30, -7), Vector3.new(16, 16, 16)) == 0, "блок высоко — без клеток")
check(#UG.cellsInBox(Vector3.new(0, 0.995, 0), Vector3.new(2, 2, 2)) == 0, "уходит под пол меньше чем на EPS — не считается")
check(sameList(UG.cellsInBox(Vector3.new(-30, -2, -30), Vector3.new(4, 4, 4)), { UG.index(1, 1, 1) }), "блок ровно по границам клетки — одна клетка")
check(sameList(UG.cellsInBox(Vector3.new(4, -4, 4), Vector3.new(8, 8, 8)), {
	UG.index(9, 1, 9), UG.index(10, 1, 9), UG.index(9, 1, 10), UG.index(10, 1, 10),
	UG.index(9, 2, 9), UG.index(10, 2, 9), UG.index(9, 2, 10), UG.index(10, 2, 10),
}), "куб 8×8×8 по границам — 8 клеток")
check(sameList(UG.cellsInBox(Vector3.new(-31, 1, -31), Vector3.new(2, 4, 2)), { UG.index(1, 1, 1) }), "частично над полом — только верхняя клетка")
check(sameList(UG.cellsInBox(Vector3.new(-28, -1, -31), Vector3.new(2, 2, 2)), { UG.index(1, 1, 1), UG.index(2, 1, 1) }), "на границе двух клеток — обе")
check(sameList(UG.cellsInBox(Vector3.new(-31, -23, -31), Vector3.new(2, 2, 2)), { UG.index(1, 6, 1) }), "у дна — нижний слой")
check(sameList(UG.cellsInBox(Vector3.new(-2, -12, -2), Vector3.new(2, 24, 2)), {
	UG.index(8, 1, 8), UG.index(8, 2, 8), UG.index(8, 3, 8), UG.index(8, 4, 8), UG.index(8, 5, 8), UG.index(8, 6, 8),
}), "столб от пола до дна — 6 клеток")
check(#UG.cellsInBox(Vector3.new(0 / 0, -2, 0), Vector3.new(2, 2, 2)) == 0, "NaN — без клеток")
do
	-- ниже дна и за краем участка — только существующие клетки
	local list = UG.cellsInBox(Vector3.new(30, -26, 30), Vector3.new(8, 8, 8))
	local ok = #list > 0
	for _, i in list do
		if i < 0 or i >= UG.COUNT then
			ok = false
		end
	end
	check(ok, "коробка за пределами котлована обрезается по сетке")
end

-- Сверка с перебором всех клеток на случайных коробках (с целыми и половинными краями)
do
	local ok = true
	for _ = 1, 400 do
		local size = Vector3.new(rng:NextInteger(1, 16), rng:NextInteger(1, 16), rng:NextInteger(1, 16))
		local lo = Vector3.new(rng:NextInteger(-32, 32 - size.X), rng:NextInteger(-26, 6), rng:NextInteger(-32, 32 - size.Z))
		if rng:NextNumber() < 0.3 then
			lo += Vector3.new(0.5, 0.5, 0.5)
		end
		local center = lo + size / 2
		local expected = {}
		for i = 0, UG.COUNT - 1 do
			local ix, iy, iz = UG.coords(i)
			local c = UG.cellCenter(ix, iy, iz)
			local ox = math.min(lo.X + size.X, c.X + 2) - math.max(lo.X, c.X - 2)
			local oy = math.min(lo.Y + size.Y, c.Y + 2, 0) - math.max(lo.Y, c.Y - 2)
			local oz = math.min(lo.Z + size.Z, c.Z + 2) - math.max(lo.Z, c.Z - 2)
			if ox > 0.01 and oy > 0.01 and oz > 0.01 then
				table.insert(expected, i)
			end
		end
		if not sameList(UG.cellsInBox(center, size), expected) then
			ok = false
			print("  коробка " .. tostring(center) .. " " .. tostring(size))
			break
		end
	end
	check(ok, "cellsInBox совпадает с перебором на 400 случайных коробках")
end

-- Можно ли копать ---------------------------------------------------------------------------
do
	local dug = {}
	check(UG.isExposed(dug, 5, 1, 5), "верхний слой копается всегда")
	check(not UG.isExposed(dug, 5, 2, 5), "второй слой без ямы над ним — нельзя")
	dug[UG.index(5, 1, 5)] = true
	check(UG.isExposed(dug, 5, 2, 5), "под ямой — можно")
	check(not UG.isExposed(dug, 6, 2, 5), "по диагонали от ямы — нельзя")
	dug[UG.index(5, 2, 5)] = true
	check(UG.isExposed(dug, 6, 2, 5), "сбоку от ямы — можно")
	check(UG.isExposed(dug, 5, 3, 5), "ещё ниже — можно")
	check(not UG.isExposed(dug, 5, 4, 5), "через клетку — нельзя")
	local edge = { [UG.index(1, 1, 1)] = true }
	check(UG.isExposed(edge, 1, 2, 1), "угол сетки: соседи за краем не мешают")
	check(not UG.isExposed(edge, 16, 6, 16), "дальний угол — нельзя")
	local deep = { [UG.index(3, 6, 3)] = true }
	check(UG.isExposed(deep, 3, 5, 3), "над выкопанной клеткой — можно")
end

-- Маска в строку и обратно ---------------------------------------------------------------
local function sameMask(a, b): boolean
	for i, v in a do
		if v and not b[i] then
			return false
		end
	end
	for i, v in b do
		if v and not a[i] then
			return false
		end
	end
	return true
end

check(UG.encode({}) == "", "пустая маска — пустая строка")
check(UG.encode({ [7] = false }) == "", "маска без выкопанных клеток — пустая строка")
check(next(UG.decode("")) == nil, "пустая строка — пустая маска")
check(next(UG.decode(nil)) == nil, "nil — пустая маска")
check(next(UG.decode("abc")) == nil, "короткая строка — пустая маска")
check(next(UG.decode(string.rep("g", 384))) == nil, "не hex — пустая маска")
check(next(UG.decode(string.rep("f", 383) .. "-")) == nil, "испорченный символ — пустая маска")
check(next(UG.decode(123 :: any)) == nil, "не строка — пустая маска")
do
	local one = UG.encode({ [0] = true })
	check(#one == 384 and one == "1" .. string.rep("0", 383), "клетка 0 — бит 1 первого символа")
	check(UG.encode({ [5] = true }) == "02" .. string.rep("0", 382), "клетка 5 — бит 2 второго символа")
	check(UG.encode({ [3] = true, [2] = true }) == "c" .. string.rep("0", 383), "клетки 2 и 3 — символ c")
	local full = {}
	for i = 0, UG.COUNT - 1 do
		full[i] = true
	end
	local fullHex = UG.encode(full)
	check(fullHex == string.rep("f", 384), "всё выкопано — 384 символа f")
	check(UG.count(UG.decode(fullHex)) == UG.COUNT, "всё выкопано — обратно 1536 клеток")
	check(UG.count(UG.decode(string.rep("F", 384))) == UG.COUNT, "заглавные hex тоже читаются")
	local okRound, okFormat = true, true
	for _ = 1, 200 do
		local mask = {}
		local p = rng:NextNumber()
		for i = 0, UG.COUNT - 1 do
			if rng:NextNumber() < p * 0.3 then
				mask[i] = true
			end
		end
		local hex = UG.encode(mask)
		if next(mask) == nil then
			if hex ~= "" then
				okFormat = false
			end
		elseif #hex ~= 384 or string.find(hex, "[^0-9a-f]") then
			okFormat = false
		end
		if not sameMask(UG.decode(hex), mask) then
			okRound = false
		end
	end
	check(okFormat, "маска: 384 строчных hex-символа или пусто")
	check(okRound, "маска: encode → decode на 200 случайных масках")
end
check(UG.count({}) == 0 and UG.count({ [1] = true, [9] = true, [4] = false }) == 2, "count")

-- Слои земли: прямоугольники ровно покрывают невыкопанные клетки ----------------------------
local function checkRects(mask, iy: number): (boolean, string?)
	local cover = {}
	for _, r in UG.layerRects(mask, iy) do
		if r.w < 1 or r.d < 1 or r.x0 < 1 or r.z0 < 1 or r.x0 + r.w - 1 > UG.NX or r.z0 + r.d - 1 > UG.NZ then
			return false, "прямоугольник за сеткой"
		end
		for z = r.z0, r.z0 + r.d - 1 do
			for x = r.x0, r.x0 + r.w - 1 do
				local i = UG.index(x, iy, z)
				if mask[i] then
					return false, "закрыта выкопанная клетка"
				end
				if cover[i] then
					return false, "прямоугольники перекрываются"
				end
				cover[i] = true
			end
		end
	end
	for z = 1, UG.NZ do
		for x = 1, UG.NX do
			local i = UG.index(x, iy, z)
			if not mask[i] and not cover[i] then
				return false, "дыра в земле"
			end
		end
	end
	return true, nil
end

do
	local rects = UG.layerRects({}, 1)
	check(#rects == 1 and rects[1].x0 == 1 and rects[1].z0 == 1 and rects[1].w == 16 and rects[1].d == 16, "нетронутый слой — один прямоугольник 16×16")
	local layer = {}
	for z = 1, UG.NZ do
		for x = 1, UG.NX do
			layer[UG.index(x, 3, z)] = true
		end
	end
	check(#UG.layerRects(layer, 3) == 0, "весь слой выкопан — нет деталей")
	check(#UG.layerRects(layer, 2) == 1, "соседний слой не задет")
	-- жадно: сначала вдоль X, потом вдоль Z
	local corner = { [UG.index(16, 1, 1)] = true }
	local r = UG.layerRects(corner, 1)
	check(#r == 2, "выкопан угол — два прямоугольника")
	check(r[1].x0 == 1 and r[1].z0 == 1 and r[1].w == 15 and r[1].d == 16, "первый прямоугольник 15×16")
	check(r[2].x0 == 16 and r[2].z0 == 2 and r[2].w == 1 and r[2].d == 15, "второй прямоугольник 1×15")
	local okAll, why = true, nil
	for n = 1, 120 do
		local mask = {}
		local p = (n % 6) / 5
		for i = 0, UG.COUNT - 1 do
			if rng:NextNumber() < p then
				mask[i] = true
			end
		end
		for iy = 1, UG.NY do
			local ok, msg = checkRects(mask, iy)
			if not ok then
				okAll, why = false, msg
			end
		end
	end
	check(okAll, "случайные маски: прямоугольники ровно покрывают землю (" .. tostring(why) .. ")")
end

-- Сохранения v1 и v2 -------------------------------------------------------------------------
do
	local specs = {
		{ mat = 5, shape = 2, item = 0, pos = Vector3.new(3, 1.5, -7.5), size = Vector3.new(2, 3, 1), rot = 7, color = Color3.fromRGB(10, 200, 255) },
		{ mat = 1, shape = 1, item = 0, pos = Vector3.new(-30, -22, -30), size = Vector3.new(4, 4, 4), rot = 1, color = Color3.fromRGB(120, 80, 40) },
	}
	local mask = { [UG.index(1, 1, 1)] = true, [UG.index(1, 2, 1)] = true, [UG.index(1, 6, 1)] = true }
	local hex = UG.encode(mask)

	local v1 = Serializer.encode(specs)
	check(string.sub(v1, 1, 3) == "v1|", "без маски — v1")
	check(Serializer.encode(specs, "") == v1, "пустая маска — тоже v1")
	check(Serializer.encode(specs, nil) == v1, "nil — тоже v1")
	check(Serializer.dig(v1) == nil, "в v1 нет маски")
	check(Serializer.count(v1) == 2, "count v1")

	local v2 = Serializer.encode(specs, hex)
	check(string.sub(v2, 1, 3) == "v2|", "с маской — v2")
	check(v2 == "v2|" .. string.sub(v1, 4) .. "|" .. hex, "v2 = блоки как в v1 + маска")
	check(Serializer.dig(v2) == hex, "маска из v2")
	check(sameMask(UG.decode(Serializer.dig(v2)), mask), "маска через сохранение — та же")
	check(Serializer.count(v2) == 2, "count v2")
	local back = Serializer.decode(v2)
	check(#back == 2, "v2: 2 блока")
	check(back[1].mat == 5 and back[1].shape == 2 and back[1].rot == 7 and vnear(back[1].pos, specs[1].pos), "v2: поля блока 1")
	check(vnear(back[2].pos, specs[2].pos) and vnear(back[2].size, specs[2].size), "v2: подземный блок")
	check(back[2].color:ToHex() == specs[2].color:ToHex(), "v2: цвет")

	local empty = Serializer.encode({}, hex)
	check(empty == "v2||" .. hex, "только маска без блоков")
	check(#Serializer.decode(empty) == 0, "v2 без блоков — 0 блоков")
	check(Serializer.count(empty) == 0, "count v2 без блоков")
	check(Serializer.dig(empty) == hex, "маска из v2 без блоков")
	check(Serializer.encode({}) == "v1|" and Serializer.count("v1|") == 0, "пустая постройка v1")

	check(Serializer.dig(nil) == nil and Serializer.dig("мусор") == nil, "маска из мусора — nil")
	check(Serializer.count(nil) == 0 and Serializer.count("мусор") == 0, "count мусора — 0")
	check(#Serializer.decode("v2|1,2,3;bad|" .. hex) == 0, "v2: битые блоки пропускаются")
	check(Serializer.dig("v2|" .. string.sub(v1, 4) .. "|") == nil, "v2 с пустой маской — nil")
	check(#Serializer.decode("v3|" .. string.sub(v1, 4)) == 0, "чужая версия не читается")
end

-- Границы участка под землёй ------------------------------------------------------------------
check(Grid.inBounds(Vector3.new(0, -1, 0), Vector3.new(2, 2, 2)), "блок сразу под полом — в зоне")
check(Grid.inBounds(Vector3.new(0, -23, 0), Vector3.new(2, 2, 2)), "блок на дне котлована — в зоне")
check(not Grid.inBounds(Vector3.new(0, -24, 0), Vector3.new(2, 2, 2)), "ниже дна — вне зоны")
check(Grid.inBounds(Vector3.new(0, -12, 0), Vector3.new(4, 24, 4)), "столб на всю глубину — в зоне")
check(Grid.inBounds(Vector3.new(31, -22, -31), Vector3.new(2, 4, 2)), "угол котлована — в зоне")
check(not Grid.inBounds(Vector3.new(32, -10, 0), Vector3.new(2, 2, 2)), "под землёй за краем X — вне зоны")
check(not Grid.inBounds(Vector3.new(0, 96, 0), Vector3.new(2, 2, 2)), "выше потолка — по-прежнему вне зоны")

-- Готовые бункеры (если модуль уже есть): подземные блоки только в выкопанных клетках,
-- все выкопанные клетки связаны с поверхностью
if fs.isFile(SHARED .. "Prefabs.lua") then
	local Blocks = loadModule("Blocks")
	local Prefabs = loadModule("Prefabs")
	for _, pf in Prefabs do
		local mask = UG.decode(Serializer.dig(pf.data))
		local okCells, okBounds = true, true
		for _, b in Serializer.decode(pf.data) do
			local size = Blocks.normalizeSize(b.shape, b.item, b.size, Config.MaxBlockSize)
			local e = Grid.extents(size, b.rot)
			if not Grid.inBounds(b.pos, e) then
				okBounds = false
			end
			for _, i in UG.cellsInBox(b.pos, e) do
				if not mask[i] then
					okCells = false
				end
			end
		end
		check(okBounds, pf.key .. ": блоки внутри участка")
		check(okCells, pf.key .. ": подземные блоки только в выкопанной земле")
		-- связность: обход от верхнего слоя по выкопанным клеткам
		local reached = {}
		local queue = {}
		for i in mask do
			local _, iy = UG.coords(i)
			if iy == 1 then
				reached[i] = true
				table.insert(queue, i)
			end
		end
		local head = 1
		while head <= #queue do
			local ix, iy, iz = UG.coords(queue[head])
			head += 1
			for _, d in { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } } do
				local x, y, z = ix + d[1], iy + d[2], iz + d[3]
				if UG.inRange(x, y, z) then
					local j = UG.index(x, y, z)
					if mask[j] and not reached[j] then
						reached[j] = true
						table.insert(queue, j)
					end
				end
			end
		end
		check(UG.count(reached) == UG.count(mask), pf.key .. ": все выкопанные клетки связаны с поверхностью")
	end
end

print(string.format("\nПройдено: %d, провалено: %d", passed, failed))
if failed > 0 then
	error("есть проваленные тесты")
end
