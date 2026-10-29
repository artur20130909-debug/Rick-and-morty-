-- Попадания: геометрия по корню персонажа (капсула ~ радиус 1.4, высота 5.5).
-- Так хитбоксы одинаковы для игроков, ботов и манекенов и не зависят от аксессуаров.
local Fighters = require(script.Parent.Fighters)

local Hitbox = {}

local R = 1.4      -- «толщина» персонажа
local HALF_H = 2.8 -- половина высоты (корень — в центре торса)

local function ok(f, exclude)
	return Fighters.alive(f) and not (exclude and exclude[f])
end

-- ящик cf/size (cf — центр и поворот ящика)
function Hitbox.box(cf, size, exclude)
	local out = {}
	local hx, hy, hz = size.X / 2 + R, size.Y / 2 + HALF_H * 0.6, size.Z / 2 + R
	for _, f in ipairs(Fighters.list) do
		if ok(f, exclude) then
			local lp = cf:PointToObjectSpace(f.root.Position)
			if math.abs(lp.X) <= hx and math.abs(lp.Y) <= hy and math.abs(lp.Z) <= hz then
				out[#out + 1] = f
			end
		end
	end
	return out
end

-- шар вокруг точки
function Hitbox.radius(pos, r, exclude)
	local out = {}
	for _, f in ipairs(Fighters.list) do
		if ok(f, exclude) then
			local d = f.root.Position - pos
			local dy = math.max(0, math.abs(d.Y) - HALF_H * 0.5)
			local dist = math.sqrt(d.X * d.X + d.Z * d.Z + dy * dy)
			if dist <= r + R then out[#out + 1] = f end
		end
	end
	return out
end

-- отрезок (луч, разрез): все, кто ближе width/2 к отрезку от a до b
function Hitbox.segment(a, b, width, exclude)
	local out = {}
	local ab = b - a
	local L2 = ab:Dot(ab)
	for _, f in ipairs(Fighters.list) do
		if ok(f, exclude) then
			local p = f.root.Position
			local t = 0
			if L2 > 1e-6 then t = math.clamp((p - a):Dot(ab) / L2, 0, 1) end
			local q = a + ab * t
			local d = p - q
			local dy = math.max(0, math.abs(d.Y) - HALF_H * 0.5)
			local dist = math.sqrt(d.X * d.X + d.Z * d.Z + dy * dy)
			if dist <= width / 2 + R then out[#out + 1] = { f = f, t = t } end
		end
	end
	table.sort(out, function(x, y) return x.t < y.t end)
	local res = {}
	for i, e in ipairs(out) do res[i] = e.f end
	return res
end

-- ближайший враг в конусе перед origin (cosAngle — косинус половины угла)
function Hitbox.cone(origin, dir, range, cosAngle, exclude)
	local best, bestD
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 1e-3 then return nil end
	flat = flat.Unit
	for _, f in ipairs(Fighters.list) do
		if ok(f, exclude) then
			local d = f.root.Position - origin
			local fd = Vector3.new(d.X, 0, d.Z)
			local dist = fd.Magnitude
			if dist <= range and dist > 0.01 then
				local c = fd.Unit:Dot(flat)
				if c >= cosAngle then
					-- чуть предпочитаем тех, кто ближе к центру прицела
					local score = dist * (1.6 - c)
					if not bestD or score < bestD then best, bestD = f, score end
				end
			elseif dist <= 0.01 then
				best = f
				bestD = 0
			end
		end
	end
	return best
end

-- ближайший враг вообще
function Hitbox.nearest(origin, range, exclude)
	local best, bestD
	for _, f in ipairs(Fighters.list) do
		if ok(f, exclude) then
			local d = (f.root.Position - origin).Magnitude
			if d <= range and (not bestD or d < bestD) then best, bestD = f, d end
		end
	end
	return best, bestD
end

return Hitbox
