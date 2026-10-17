-- Проверка готовых построек (Shared/Prefabs.lua, её создаёт tools/gen_prefabs.py) со стороны Luau.
-- Запуск: lune run tools/test_prefabs.luau
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

local Vector3 = roblox.Vector3

local Config = loadModule("Config")
local Blocks = loadModule("Blocks")
local Grid = loadModule("Grid")
local Serializer = loadModule("Serializer")
local UG = loadModule("Underground")
local Prefabs = loadModule("Prefabs")

-- Правила магазина (спецификация v3, раздел PREFABS)
local KEYS = {
	house = { "Cabin", "BrickHouse", "Cottage", "Villa", "Mansion" },
	bunker = { "Cellar", "Shelter", "MilitaryBunker", "CommandBunker", "DoomsdayBunker" },
}
local PRICES = {
	house = { 400, 1500, 5000, 14000, 40000 },
	bunker = { 600, 2500, 9000, 20000, 50000 },
}
local HOUSE_XZ = 22         -- дом: x, z от -22 до 22
local HOUSE_TOP = 60        -- и не выше 60
local KIOSK_LO, KIOSK_HI = 24, 32 -- над землёй бункер — только павильон в углу участка
local MAX_PREFAB = 650      -- лимит блоков одной постройки
local EPS = 1e-6
local DOOR_MIN = Vector3.new(2, 5, 1)
local MAX_SHADOW_LAMPS = 8 -- лампы крупнее 1×1×1 светят с тенями (BlockFactory) — это дорого

local function isInt(v: number): boolean
	return math.abs(v - math.round(v)) < 1e-9
end

type Box = { lo: Vector3, hi: Vector3 }

local function overlapVolume(a: Box, b: Box): number
	local dx = math.min(a.hi.X, b.hi.X) - math.max(a.lo.X, b.lo.X)
	local dy = math.min(a.hi.Y, b.hi.Y) - math.max(a.lo.Y, b.lo.Y)
	local dz = math.min(a.hi.Z, b.hi.Z) - math.max(a.lo.Z, b.lo.Z)
	if dx <= 0 or dy <= 0 or dz <= 0 then
		return 0
	end
	return dx * dy * dz
end

-- Порядок, ключи, цены -------------------------------------------------------------
check(#Prefabs == 10, "10 построек")
for i, pf in Prefabs do
	local kind = if i <= 5 then "house" else "bunker"
	local tier = if i <= 5 then i else i - 5
	check(pf.kind == kind and pf.tier == tier, pf.key .. ": вид и уровень по порядку")
	check(pf.key == KEYS[kind][tier], pf.key .. ": ключ на своём месте")
	check(pf.price == PRICES[kind][tier], pf.key .. ": цена")
	check(typeof(pf.name) == "string" and #pf.name > 0 and typeof(pf.icon) == "string" and #pf.icon > 0, pf.key .. ": имя и значок")
	check(typeof(pf.desc) == "string" and #pf.desc > 0, pf.key .. ": описание")
	check(typeof(pf.features) == "table" and #pf.features >= 3, pf.key .. ": пункты описания")
end

-- Каждая постройка -------------------------------------------------------------------
local maxHouse, maxBunker = 0, 0
for _, pf in Prefabs do
	local key = pf.key
	local bunker = pf.kind == "bunker"
	local specs = Serializer.decode(pf.data)
	check(string.sub(pf.data, 1, 3) == (if bunker then "v2|" else "v1|"), key .. ": формат строки")
	check(#specs == pf.blocks and Serializer.count(pf.data) == pf.blocks, key .. ": число блоков совпадает с полем blocks")
	check(pf.blocks > 0 and pf.blocks <= MAX_PREFAB, key .. ": не больше " .. MAX_PREFAB .. " блоков")
	if bunker then
		maxBunker = math.max(maxBunker, pf.blocks)
	else
		maxHouse = math.max(maxHouse, pf.blocks)
	end

	-- строка без потерь: декодировали и закодировали обратно — то же самое
	local hex = Serializer.dig(pf.data)
	check(Serializer.encode(specs, hex) == pf.data, key .. ": Serializer.encode(decode(data)) == data")

	-- маска земли
	local mask = UG.decode(hex)
	if bunker then
		check(hex ~= nil and #hex == UG.COUNT // 4, key .. ": маска из " .. UG.COUNT // 4 .. " hex-символов")
		check(UG.encode(mask) == hex, key .. ": UG.encode(UG.decode(hex)) == hex")
		check(UG.count(mask) > 0, key .. ": земля выкопана")
		-- связность: обход от верхнего слоя по выкопанным клеткам
		local reached = {}
		local queue = {}
		local topOk = true
		for i in mask do
			local ix, iy, iz = UG.coords(i)
			if iy == 1 then
				reached[i] = true
				table.insert(queue, i)
				-- в верхнем слое копаем только под павильоном (клетки 15–16)
				if ix < 15 or iz < 15 then
					topOk = false
				end
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
		check(UG.count(reached) == UG.count(mask), key .. ": все выкопанные клетки связаны с поверхностью")
		check(topOk, key .. ": пол участка вскрыт только под павильоном")
	else
		check(hex == nil, key .. ": у дома нет маски земли")
	end

	-- блоки: описание, размер, сетка, зоны, клетки
	local boxes: { Box } = {}
	local counts = { Guard = 0, AATurret = 0, Shield = 0, Medkit = 0 }
	local okDef, okSize, okAlign, okBounds, okZone, okCells, okDoor = true, true, true, true, true, true, true
	local shadowLamps = 0
	for n, s in specs do
		local def = if s.item > 0 then Blocks.ItemById[s.item] else Blocks.MaterialById[s.mat]
		if not def or not Blocks.ShapeById[s.shape] or s.rot < 1 or s.rot > 24 or (s.item > 0 and s.mat ~= 0) then
			okDef = false
			print("  нет такого блока: " .. key .. " #" .. n)
			continue
		end
		-- сервер приводит размер к допустимому — он не должен измениться
		local norm = Blocks.normalizeSize(s.shape, s.item, s.size, Config.MaxBlockSize)
		if norm ~= s.size then
			okSize = false
			print("  размер изменится: " .. key .. " #" .. n .. " " .. tostring(s.size) .. " -> " .. tostring(norm))
		end
		if s.item > 0 then
			counts[def.key] = (counts[def.key] or 0) + 1
			if def.key == "Door" and not (s.size.X >= DOOR_MIN.X and s.size.Y >= DOOR_MIN.Y and s.size.Z >= DOOR_MIN.Z) then
				okDoor = false
			end
			if def.key == "Lamp" and s.size.Magnitude > 2 then
				shadowLamps += 1
			end
		end
		local e = Grid.extents(s.size, s.rot)
		local lo, hi = s.pos - e / 2, s.pos + e / 2
		table.insert(boxes, { lo = lo, hi = hi })
		if not (Grid.isAligned(s.pos, e) and isInt(lo.X) and isInt(lo.Y) and isInt(lo.Z)) then
			okAlign = false
		end
		if not Grid.inBounds(s.pos, e) then
			okBounds = false
		end
		if bunker then
			if hi.Y > 0 and not (lo.X >= KIOSK_LO and hi.X <= KIOSK_HI and lo.Z >= KIOSK_LO and hi.Z <= KIOSK_HI) then
				okZone = false
				print("  над землёй вне павильона: " .. key .. " #" .. n)
			end
			for _, i in UG.cellsInBox(s.pos, e) do
				if not mask[i] then
					okCells = false
				end
			end
		else
			if lo.X < -HOUSE_XZ or hi.X > HOUSE_XZ or lo.Z < -HOUSE_XZ or hi.Z > HOUSE_XZ or lo.Y < 0 or hi.Y > HOUSE_TOP then
				okZone = false
				print("  вне зоны дома: " .. key .. " #" .. n)
			end
		end
	end
	check(okDef, key .. ": все материалы и особые блоки существуют")
	check(okSize, key .. ": размеры не меняются при загрузке на сервере")
	check(okDoor, key .. ": двери не меньше 2×5×1")
	check(shadowLamps <= MAX_SHADOW_LAMPS, key .. ": ламп с тенями не больше " .. MAX_SHADOW_LAMPS .. " (" .. shadowLamps .. ")")
	check(okAlign, key .. ": блоки по сетке")
	check(okBounds, key .. ": блоки внутри участка")
	check(okZone, key .. ": блоки в своей зоне")
	check(okCells, key .. ": подземные блоки только в выкопанной земле")

	-- пересечения (объём общей части коробок)
	table.sort(boxes, function(a, b)
		return a.lo.X < b.lo.X
	end)
	local overlaps = 0
	for i = 1, #boxes do
		local a = boxes[i]
		for j = i + 1, #boxes do
			local b = boxes[j]
			if b.lo.X >= a.hi.X then
				break
			end
			if overlapVolume(a, b) > EPS then
				overlaps += 1
			end
		end
	end
	check(overlaps == 0, key .. ": блоки не пересекаются (" .. overlaps .. ")")

	-- счётчики в описании и правила по уровням
	check(counts.Guard == pf.guards, key .. ": guards = " .. counts.Guard)
	check(counts.AATurret == pf.aa, key .. ": aa = " .. counts.AATurret)
	check(counts.Shield == pf.shields, key .. ": shields = " .. counts.Shield)
	check(counts.Medkit == pf.medkits, key .. ": medkits = " .. counts.Medkit)
	check(pf.guards == 0 or pf.tier >= 4, key .. ": охрана только с 4 уровня")
	check(pf.aa == 0 or pf.tier >= 3, key .. ": ПВО только с 3 уровня")
	check(pf.shields == 0 or pf.tier >= 5, key .. ": щит только на 5 уровне")
end

-- дом и бункер стоят на участке вместе — и ещё остаётся место для своих блоков
check(maxHouse + maxBunker <= Config.MaxBlocks - 150, "самый большой дом + бункер с запасом влезают в лимит участка")

print(string.format("\nПройдено: %d, провалено: %d", passed, failed))
if failed > 0 then
	error("есть проваленные тесты")
end
