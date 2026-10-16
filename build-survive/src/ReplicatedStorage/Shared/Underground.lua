-- Подземелье участка: земля под полом делится на клетки, их можно выкопать и засыпать обратно.
-- Только чистые функции (из Roblox — лишь Vector3): модуль общий для сервера, клиента и тестов.
--
-- Клетка (ix, iy, iz): ix, iz = 1..16 по осям X и Z участка, iy = 1..6 сверху вниз (1 — сразу под полом).
-- Координаты — локальные координаты участка (начало в центре участка на уровне пола, ось Y вверх).
-- Маска dug = { [индекс]: true } — выкопанные клетки. Невыкопанная клетка — сплошная земля,
-- в верхнем слое в ней ещё лежит бетонная плита пола.
local Config = require(script.Parent.Config)

local UG = {}

UG.CELL = Config.Underground.Cell
UG.DEPTH = Config.Underground.Depth
UG.NX = math.floor(Config.PlotSize.X / UG.CELL)
UG.NY = math.floor(UG.DEPTH / UG.CELL)
UG.NZ = math.floor(Config.PlotSize.Z / UG.CELL)
UG.COUNT = UG.NX * UG.NY * UG.NZ

local C = UG.CELL
local NX, NY, NZ = UG.NX, UG.NY, UG.NZ
local LAYER = NX * NZ                 -- клеток в одном слое
local X0 = -Config.PlotSize.X / 2     -- край зоны строительства по X
local Z0 = -Config.PlotSize.Z / 2     -- и по Z
local EPS = 0.01
local HEX_LEN = UG.COUNT // 4         -- длина маски в hex-символах (4 клетки на символ)

assert(UG.COUNT % 4 == 0, "число клеток подземелья должно делиться на 4")

local function isInt(v: number): boolean
	return v == math.floor(v)
end

local function finite(v: number): boolean
	return v == v and v ~= math.huge and v ~= -math.huge
end

-- Номер клетки (с нуля): слой за слоем, в слое — ряд за рядом вдоль X
function UG.index(ix: number, iy: number, iz: number): number
	return (iy - 1) * LAYER + (iz - 1) * NX + (ix - 1)
end

function UG.coords(i: number): (number, number, number)
	return i % NX + 1, i // LAYER + 1, (i // NX) % NZ + 1
end

function UG.inRange(ix: number, iy: number, iz: number): boolean
	return isInt(ix) and isInt(iy) and isInt(iz)
		and ix >= 1 and ix <= NX
		and iy >= 1 and iy <= NY
		and iz >= 1 and iz <= NZ
end

-- Центр клетки в координатах участка
function UG.cellCenter(ix: number, iy: number, iz: number): Vector3
	return Vector3.new(X0 + (ix - 0.5) * C, -(iy - 0.5) * C, Z0 + (iz - 0.5) * C)
end

-- В какой клетке точка (nil — точка вне котлована)
function UG.cellAt(p: Vector3): (number?, number?, number?)
	local ix = math.floor((p.X - X0) / C) + 1
	local iy = math.floor(-p.Y / C) + 1
	local iz = math.floor((p.Z - Z0) / C) + 1
	if UG.inRange(ix, iy, iz) then
		return ix, iy, iz
	end
	return nil, nil, nil
end

-- Клетки, которые задевает коробка (центр и габариты) ниже пола.
-- Касание гранью не считается: коробка должна заходить в клетку глубже чем на EPS.
function UG.cellsInBox(center: Vector3, extents: Vector3): { number }
	local out = {}
	local lo = center - extents / 2
	local hi = center + extents / 2
	if not (finite(lo.X) and finite(lo.Y) and finite(lo.Z) and finite(hi.X) and finite(hi.Y) and finite(hi.Z)) then
		return out
	end
	if lo.Y >= -EPS then
		return out -- целиком над полом
	end
	local x1 = math.max(1, math.floor((lo.X + EPS - X0) / C) + 1)
	local x2 = math.min(NX, math.ceil((hi.X - EPS - X0) / C))
	local z1 = math.max(1, math.floor((lo.Z + EPS - Z0) / C) + 1)
	local z2 = math.min(NZ, math.ceil((hi.Z - EPS - Z0) / C))
	local y1 = math.max(1, math.floor((EPS - hi.Y) / C) + 1)
	local y2 = math.min(NY, math.ceil((-lo.Y - EPS) / C))
	for iy = y1, y2 do
		for iz = z1, z2 do
			for ix = x1, x2 do
				table.insert(out, UG.index(ix, iy, iz))
			end
		end
	end
	return out
end

-- Можно ли копать эту клетку: верхний слой — всегда, ниже — только рядом с уже выкопанной
local NEIGHBOURS = {
	{ 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 },
}
function UG.isExposed(dug: { [number]: boolean }, ix: number, iy: number, iz: number): boolean
	if iy == 1 then
		return true
	end
	for _, d in NEIGHBOURS do
		local x, y, z = ix + d[1], iy + d[2], iz + d[3]
		if UG.inRange(x, y, z) and dug[UG.index(x, y, z)] then
			return true
		end
	end
	return false
end

-- Маска → строка: по 4 клетки на hex-символ (бит 1 — первая клетка четвёрки). Пустая маска — "".
local BITS = { 1, 2, 4, 8 }
function UG.encode(dug: { [number]: boolean }): string
	if next(dug) == nil then
		return ""
	end
	local chars = table.create(HEX_LEN)
	local any = false
	for k = 1, HEX_LEN do
		local base = (k - 1) * 4
		local n = 0
		for b = 0, 3 do
			if dug[base + b] then
				n += BITS[b + 1]
			end
		end
		if n > 0 then
			any = true
		end
		chars[k] = string.format("%x", n)
	end
	return any and table.concat(chars) or ""
end

-- Строка → маска. Пустая, чужая или испорченная строка — пустая маска (вся земля на месте).
function UG.decode(hex: string?): { [number]: boolean }
	local dug = {}
	if typeof(hex) ~= "string" or #hex ~= HEX_LEN or string.find(hex, "[^0-9a-fA-F]") then
		return dug
	end
	for k = 1, HEX_LEN do
		local n = tonumber(string.sub(hex, k, k), 16) or 0
		local base = (k - 1) * 4
		for b = 0, 3 do
			if n % 2 == 1 then
				dug[base + b] = true
			end
			n //= 2
		end
	end
	return dug
end

function UG.count(dug: { [number]: boolean }): number
	local n = 0
	for _, v in dug do
		if v then
			n += 1
		end
	end
	return n
end

export type Rect = { x0: number, z0: number, w: number, d: number }

-- Невыкопанные клетки слоя iy, собранные в прямоугольники (жадно: сначала вдоль X, потом вдоль Z).
-- x0, z0 — первая клетка (с единицы), w — ширина в клетках по X, d — глубина по Z.
function UG.layerRects(dug: { [number]: boolean }, iy: number): { Rect }
	local rects = {}
	local used: { [number]: boolean } = {}
	local function free(ix: number, iz: number): boolean
		local i = UG.index(ix, iy, iz)
		return not dug[i] and not used[i]
	end
	for iz = 1, NZ do
		for ix = 1, NX do
			if free(ix, iz) then
				local w = 1
				while ix + w <= NX and free(ix + w, iz) do
					w += 1
				end
				local d = 1
				while iz + d <= NZ do
					local rowFree = true
					for x = ix, ix + w - 1 do
						if not free(x, iz + d) then
							rowFree = false
							break
						end
					end
					if not rowFree then
						break
					end
					d += 1
				end
				for z = iz, iz + d - 1 do
					for x = ix, ix + w - 1 do
						used[UG.index(x, iy, z)] = true
					end
				end
				table.insert(rects, { x0 = ix, z0 = iz, w = w, d = d })
			end
		end
	end
	return rects
end

return UG
