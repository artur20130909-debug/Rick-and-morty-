-- Сетка строительства. Все расчёты — в локальных координатах участка:
-- начало координат в центре участка на уровне пола, ось Y вверх.
-- Блоки всегда выровнены по сетке в 1 стад и повёрнуты на углы, кратные 90°.
local Config = require(script.Parent.Config)

local Grid = {}

local HALF_PI = math.pi / 2

-- 24 поворота «кубика» (все варианты осей). Индекс 1 — без поворота.
Grid.Rotations = {} :: { CFrame }

local function sameRotation(a: CFrame, b: CFrame): boolean
	local ac = { a:GetComponents() }
	local bc = { b:GetComponents() }
	for i = 4, 12 do
		if math.abs(ac[i] - bc[i]) > 0.01 then
			return false
		end
	end
	return true
end

local function snapRotation(cf: CFrame): CFrame
	local c = { cf:GetComponents() }
	for i = 4, 12 do
		c[i] = math.round(c[i])
	end
	return CFrame.new(0, 0, 0, c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
end

for yaw = 0, 3 do
	for pitch = 0, 3 do
		for roll = 0, 3 do
			local cf = snapRotation(CFrame.Angles(0, yaw * HALF_PI, 0) * CFrame.Angles(pitch * HALF_PI, 0, 0) * CFrame.Angles(0, 0, roll * HALF_PI))
			local found = false
			for _, r in Grid.Rotations do
				if sameRotation(r, cf) then
					found = true
					break
				end
			end
			if not found then
				table.insert(Grid.Rotations, cf)
			end
		end
	end
end
assert(#Grid.Rotations == 24, "ожидалось 24 поворота")

-- Ближайший индекс поворота для произвольного CFrame
function Grid.rotIndex(cf: CFrame): number
	local snapped = snapRotation(cf - cf.Position)
	for i, r in Grid.Rotations do
		if sameRotation(r, snapped) then
			return i
		end
	end
	return 1
end

-- Повернуть индекс вокруг локальных осей участка: axis = "Y" | "X" | "Z"
function Grid.rotate(index: number, axis: string, dir: number?): number
	local d = (dir or 1) * HALF_PI
	local turn
	if axis == "Y" then
		turn = CFrame.Angles(0, d, 0)
	elseif axis == "X" then
		turn = CFrame.Angles(d, 0, 0)
	else
		turn = CFrame.Angles(0, 0, d)
	end
	return Grid.rotIndex(turn * (Grid.Rotations[index] or Grid.Rotations[1]))
end

-- Габариты (AABB) блока после поворота
function Grid.extents(size: Vector3, index: number): Vector3
	local r = Grid.Rotations[index] or Grid.Rotations[1]
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = r:GetComponents()
	return Vector3.new(
		math.abs(r00) * size.X + math.abs(r01) * size.Y + math.abs(r02) * size.Z,
		math.abs(r10) * size.X + math.abs(r11) * size.Y + math.abs(r12) * size.Z,
		math.abs(r20) * size.X + math.abs(r21) * size.Y + math.abs(r22) * size.Z
	)
end

local function snapAxis(p: number, e: number): number
	return math.round(p - e / 2) + e / 2
end

local function axisOf(v: Vector3): (string, number)
	local ax, ay, az = math.abs(v.X), math.abs(v.Y), math.abs(v.Z)
	if ax >= ay and ax >= az then
		return "X", (v.X >= 0 and 1 or -1)
	elseif ay >= az then
		return "Y", (v.Y >= 0 and 1 or -1)
	end
	return "Z", (v.Z >= 0 and 1 or -1)
end

-- Куда встанет блок, если навести курсор на точку hitPos с нормалью hitNormal.
-- Возвращает центр блока в локальных координатах участка.
function Grid.placement(plotCF: CFrame, hitPos: Vector3, hitNormal: Vector3, size: Vector3, index: number): Vector3
	local lp = plotCF:PointToObjectSpace(hitPos)
	local ln = plotCF:VectorToObjectSpace(hitNormal)
	local e = Grid.extents(size, index)
	local axis, sign = axisOf(ln)
	local x, y, z
	if axis == "X" then
		x = math.round(lp.X) + sign * e.X / 2
	else
		x = snapAxis(lp.X, e.X)
	end
	if axis == "Y" then
		y = math.round(lp.Y) + sign * e.Y / 2
	else
		y = snapAxis(lp.Y, e.Y)
	end
	if axis == "Z" then
		z = math.round(lp.Z) + sign * e.Z / 2
	else
		z = snapAxis(lp.Z, e.Z)
	end
	return Vector3.new(x, y, z)
end

-- Блок целиком внутри зоны строительства? Снизу зона доходит до дна котлована
-- (выкопана ли там земля, проверяется отдельно — по маске участка, см. Shared/Underground).
function Grid.inBounds(center: Vector3, e: Vector3): boolean
	local s = Config.PlotSize
	local eps = 0.01
	return center.X - e.X / 2 >= -s.X / 2 - eps
		and center.X + e.X / 2 <= s.X / 2 + eps
		and center.Z - e.Z / 2 >= -s.Z / 2 - eps
		and center.Z + e.Z / 2 <= s.Z / 2 + eps
		and center.Y - e.Y / 2 >= -Config.Underground.Depth - eps
		and center.Y + e.Y / 2 <= s.Y + eps
end

-- Блок выровнен по сетке? (проверка на сервере против подделанных запросов)
function Grid.isAligned(center: Vector3, e: Vector3): boolean
	local function ok(v)
		return math.abs(v - math.round(v)) < 0.02
	end
	return ok(center.X - e.X / 2) and ok(center.Y - e.Y / 2) and ok(center.Z - e.Z / 2)
end

-- Мировой CFrame блока по локальному центру и повороту
function Grid.worldCFrame(plotCF: CFrame, center: Vector3, index: number): CFrame
	return plotCF * CFrame.new(center) * (Grid.Rotations[index] or Grid.Rotations[1])
end

return Grid
