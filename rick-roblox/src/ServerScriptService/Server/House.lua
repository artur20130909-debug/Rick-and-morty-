-- Дом Смитов: каркас (полы, потолки, стены с проёмами, окна, лестница, крыша, гараж, крыльцо).
-- Мебель расставляет Rooms.lua, двери — Doors.lua, улицу — Exterior.lua.
--
-- План (вид сверху, x — вправо, z — вниз; улица со стороны z < 0):
--   Этаж 1 (пол y = 0):  гостиная x 0..22 | прихожая и столовая x 22..36 (лестница у стены x 22.5..28.5,
--                        z 4..20, подъём к z = 20) | кладовая x 36..56, z 0..14 | кухня x 36..56, z 14..40
--   Этаж 2 (пол y = 12): спальня родителей x 0..22, z 0..26 | ванная x 0..22, z 26..40 | коридор x 22..36 |
--                        комната Саммер x 36..56, z 0..20 | комната Морти x 36..56, z 20..40
local House = {}

local B, C
local H

-- Комнаты: этаж, границы, цвета стен/пола/потолка, материал пола
local ROOMS = {
	{ id = "Living", label = "Гостиная", fl = 1, x0 = 0, x1 = 22, z0 = 0, z1 = 40, wall = "#BFCC9A", floor = "#A9764B", fmat = "WoodPlanks", ceil = "#F3EEE4" },
	{ id = "Foyer", label = "Прихожая", fl = 1, x0 = 22, x1 = 36, z0 = 0, z1 = 40, wall = "#E9D6B5", floor = "#A0704A", fmat = "WoodPlanks", ceil = "#F3EEE4" },
	{ id = "Mudroom", label = "Кладовая", fl = 1, x0 = 36, x1 = 56, z0 = 0, z1 = 14, wall = "#D8D2C2", floor = "#9C9488", fmat = "Slate", ceil = "#F0EDE6" },
	{ id = "Kitchen", label = "Кухня", fl = 1, x0 = 36, x1 = 56, z0 = 14, z1 = 40, wall = "#F1DB9F", floor = "checker", ceil = "#F6F1E6" },
	{ id = "Parents", label = "Спальня", fl = 2, x0 = 0, x1 = 22, z0 = 0, z1 = 26, wall = "#D9B7B0", floor = "#B9A48C", fmat = "Fabric", ceil = "#F3EEE4" },
	{ id = "Bath", label = "Ванная", fl = 2, x0 = 0, x1 = 22, z0 = 26, z1 = 40, wall = "#A9DAD6", floor = "#E8EEF0", fmat = "Slate", ceil = "#F4F7F7" },
	{ id = "Hall", label = "Коридор", fl = 2, x0 = 22, x1 = 36, z0 = 0, z1 = 40, wall = "#E9D6B5", floor = "#A0704A", fmat = "WoodPlanks", ceil = "#F3EEE4" },
	{ id = "Summer", label = "Комната Саммер", fl = 2, x0 = 36, x1 = 56, z0 = 0, z1 = 20, wall = "#E7B4D0", floor = "#C6B29A", fmat = "Fabric", ceil = "#F6EEF2" },
	{ id = "Morty", label = "Комната Морти", fl = 2, x0 = 36, x1 = 56, z0 = 20, z1 = 40, wall = "#9EC3D3", floor = "#B9A58D", fmat = "Fabric", ceil = "#F1ECE4" },
}
House.ROOMS = ROOMS

-- Проёмы. axis = "x": стена x = const (проём вдоль z), axis = "z": стена z = const (проём вдоль x).
-- kind: door (дверь с полотном), arch (просто проём), window, exdoor (входная/задняя дверь)
local OPENINGS = {
	-- этаж 1
	{ id = "Front", kind = "exdoor", fl = 1, axis = "z", at = 0, c = 32, w = 4.6, y0 = 0, y1 = 8 },
	{ kind = "window", fl = 1, axis = "z", at = 0, c = 25.5, w = 3, y0 = 3, y1 = 8 },
	{ kind = "window", fl = 1, axis = "z", at = 0, c = 6, w = 5, y0 = 3, y1 = 8.5 },
	{ kind = "window", fl = 1, axis = "z", at = 0, c = 16, w = 5, y0 = 3, y1 = 8.5 },
	{ kind = "window", fl = 1, axis = "x", at = 0, c = 12, w = 5, y0 = 3, y1 = 8.5 },
	{ kind = "window", fl = 1, axis = "x", at = 0, c = 28, w = 5, y0 = 3, y1 = 8.5 },
	{ kind = "arch", fl = 1, axis = "x", at = 22, c = 30, w = 12, y0 = 0, y1 = 9 },
	{ kind = "window", fl = 1, axis = "z", at = 40, c = 31, w = 5, y0 = 3, y1 = 8.5 },
	{ id = "Mudroom", kind = "door", fl = 1, axis = "x", at = 36, c = 7, w = 4.6, y0 = 0, y1 = 8 },
	{ kind = "arch", fl = 1, axis = "x", at = 36, c = 29, w = 14, y0 = 0, y1 = 9 },
	{ kind = "window", fl = 1, axis = "x", at = 56, c = 30, w = 7, y0 = 4.6, y1 = 8.6, id = "KitchenWindow" },
	{ id = "Back", kind = "exdoor", fl = 1, axis = "z", at = 40, c = 50, w = 4.2, y0 = 0, y1 = 8 },
	{ kind = "window", fl = 1, axis = "z", at = 40, c = 42, w = 4.5, y0 = 4.6, y1 = 8.6 },
	{ id = "Garage", kind = "door", fl = 1, axis = "x", at = 56, c = 7, w = 4.6, y0 = 0, y1 = 8 },
	{ kind = "window", fl = 1, axis = "z", at = 0, c = 46, w = 4, y0 = 4, y1 = 8 },
	-- этаж 2
	{ kind = "window", fl = 2, axis = "z", at = 0, c = 32, w = 4, y0 = 3.5, y1 = 8 },
	{ kind = "window", fl = 2, axis = "z", at = 40, c = 30, w = 4, y0 = 3.5, y1 = 8 },
	{ id = "Parents", kind = "door", fl = 2, axis = "x", at = 22, c = 23.2, w = 4.6, y0 = 0, y1 = 8 },
	{ id = "Bath", kind = "door", fl = 2, axis = "x", at = 22, c = 33, w = 4.2, y0 = 0, y1 = 8 },
	{ id = "Summer", kind = "door", fl = 2, axis = "x", at = 36, c = 10, w = 4.6, y0 = 0, y1 = 8 },
	{ id = "Morty", kind = "door", fl = 2, axis = "x", at = 36, c = 24, w = 4.6, y0 = 0, y1 = 8 },
	{ kind = "window", fl = 2, axis = "x", at = 56, c = 30.5, w = 8, y0 = 3, y1 = 9, id = "MortyWindow" },
	{ kind = "window", fl = 2, axis = "z", at = 40, c = 50, w = 4.5, y0 = 3.5, y1 = 8.5, id = "MortyWindow2" },
	{ kind = "window", fl = 2, axis = "x", at = 56, c = 10, w = 5, y0 = 3.5, y1 = 8.5 },
	{ kind = "window", fl = 2, axis = "z", at = 0, c = 46, w = 5, y0 = 3.5, y1 = 8.5 },
	{ kind = "window", fl = 2, axis = "x", at = 0, c = 13, w = 6, y0 = 3.5, y1 = 8.5 },
	{ kind = "window", fl = 2, axis = "z", at = 0, c = 11, w = 5, y0 = 3.5, y1 = 8.5 },
	{ kind = "window", fl = 2, axis = "z", at = 40, c = 11, w = 3, y0 = 5, y1 = 8 },
}
House.OPENINGS = OPENINGS

-- Лестница: x 22.5..28.5, низ у z = 4 (y = 0), верх у z = 20 (y = 12)
local STAIR = { x0 = 22.5, x1 = 28.5, z0 = 4, z1 = 20, steps = 16 }
House.STAIR = STAIR

local T = 0.35        -- толщина отделки стены (с каждой стороны)
local SHELL = 0.7     -- толщина наружной обшивки
local SIDING = "#EADBB2"
local TRIM = "#F6F2EA"
local ROOF = "#6E5E57"
local FOUND = "#B9B3A8"

local function floorY(fl) return fl == 1 and C.House.Floor1 or C.House.Floor2 end

-- проёмы, лежащие на линии стены (axis, at) этажа fl
local function openingsOn(fl, axis, at, from, to, origin)
	local out = {}
	for _, o in ipairs(OPENINGS) do
		if o.fl == fl and o.axis == axis and math.abs(o.at - at) < 0.01 and o.c > from and o.c < to then
			table.insert(out, { at = o.c - origin, w = o.w, y0 = o.y0, y1 = o.y1 })
		end
	end
	return out
end

-- отделка комнаты: 4 тонкие стены изнутри, с проёмами
local function lining(room, parent)
	local y = floorY(room.fl)
	local h = C.House.WallH
	local m = B.model(parent, "Walls_" .. room.id)
	local col = B.color(room.wall)
	local x0, x1, z0, z1 = room.x0, room.x1, room.z0, room.z1
	-- южная (z0) и северная (z1) стены идут вдоль x
	B.wall(m, "S", Vector3.new(x0, y, z0 + T / 2), Vector3.new(x1, y, z0 + T / 2), h, T, col, nil, openingsOn(room.fl, "z", z0, x0, x1, x0))
	B.wall(m, "N", Vector3.new(x0, y, z1 - T / 2), Vector3.new(x1, y, z1 - T / 2), h, T, col, nil, openingsOn(room.fl, "z", z1, x0, x1, x0))
	-- западная (x0) и восточная (x1) идут вдоль z (между южной и северной)
	B.wall(m, "W", Vector3.new(x0 + T / 2, y, z0 + T), Vector3.new(x0 + T / 2, y, z1 - T), h, T, col, nil, openingsOn(room.fl, "x", x0, z0, z1, z0 + T))
	B.wall(m, "E", Vector3.new(x1 - T / 2, y, z0 + T), Vector3.new(x1 - T / 2, y, z1 - T), h, T, col, nil, openingsOn(room.fl, "x", x1, z0, z1, z0 + T))
	-- плинтус и карниз по периметру (с разрывами в дверях)
	local trim = B.model(parent, "Trim_" .. room.id)
	local function band(axis, at, from, to, inward, yb, hb, thick)
		local ops = openingsOn(room.fl, axis, at, from, to, 0)
		local cuts = {}
		for _, o in ipairs(ops) do
			if o.y0 < yb + hb then table.insert(cuts, { o.at - o.w / 2, o.at + o.w / 2 }) end
		end
		table.sort(cuts, function(a, b) return a[1] < b[1] end)
		local cur = from
		local function seg(s0, s1)
			if s1 - s0 < 0.1 then return end
			local len = s1 - s0
			local mid = (s0 + s1) / 2
			local pos, size
			if axis == "z" then
				pos = Vector3.new(mid, y + yb + hb / 2, at + inward * (T + thick / 2))
				size = Vector3.new(len, hb, thick)
			else
				pos = Vector3.new(at + inward * (T + thick / 2), y + yb + hb / 2, mid)
				size = Vector3.new(thick, hb, len)
			end
			B.part(trim, "Trim", size, CFrame.new(pos), TRIM)
		end
		for _, c in ipairs(cuts) do
			seg(cur, c[1])
			cur = math.max(cur, c[2])
		end
		seg(cur, to)
	end
	band("z", z0, x0 + T, x1 - T, 1, 0, 0.6, 0.15)
	band("z", z1, x0 + T, x1 - T, -1, 0, 0.6, 0.15)
	band("x", x0, z0 + T, z1 - T, 1, 0, 0.6, 0.15)
	band("x", x1, z0 + T, z1 - T, -1, 0, 0.6, 0.15)
	band("z", z0, x0 + T, x1 - T, 1, h - 0.45, 0.45, 0.22)
	band("z", z1, x0 + T, x1 - T, -1, h - 0.45, 0.45, 0.22)
	band("x", x0, z0 + T, z1 - T, 1, h - 0.45, 0.45, 0.22)
	band("x", x1, z0 + T, z1 - T, -1, h - 0.45, 0.45, 0.22)
end

-- пол и потолок комнаты (с дырой под лестницу)
local function slabs(room, parent)
	local y = floorY(room.fl)
	local h = C.House.WallH
	local m = B.model(parent, "Floor_" .. room.id)
	local function rectXZ(name, x0, x1, z0, z1, yc, th, color, mat)
		if x1 - x0 < 0.05 or z1 - z0 < 0.05 then return end
		B.part(m, name, Vector3.new(x1 - x0, th, z1 - z0), CFrame.new((x0 + x1) / 2, yc, (z0 + z1) / 2), color, mat)
	end
	-- вырез под лестницу (для коридора на 2 этаже и потолка прихожей на 1)
	local hole = (room.id == "Hall") or (room.id == "Foyer")
	local function rectWithHole(name, yc, th, color, mat)
		if not hole then
			rectXZ(name, room.x0, room.x1, room.z0, room.z1, yc, th, color, mat)
			return
		end
		local sx0, sx1, sz0, sz1 = STAIR.x0, STAIR.x1, STAIR.z0, STAIR.z1
		rectXZ(name, room.x0, room.x1, room.z0, sz0, yc, th, color, mat)
		rectXZ(name, room.x0, room.x1, sz1, room.z1, yc, th, color, mat)
		rectXZ(name, room.x0, sx0, sz0, sz1, yc, th, color, mat)
		rectXZ(name, sx1, room.x1, sz0, sz1, yc, th, color, mat)
	end
	-- пол
	if room.floor == "checker" then
		local tile = 4
		local nx = math.floor((room.x1 - room.x0) / tile + 0.5)
		local nz = math.floor((room.z1 - room.z0) / tile + 0.5)
		local tw, tz = (room.x1 - room.x0) / nx, (room.z1 - room.z0) / nz
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				local col = ((i + j) % 2 == 0) and "#EFEAE0" or "#C9BFA9"
				rectXZ("Tile", room.x0 + i * tw, room.x0 + (i + 1) * tw, room.z0 + j * tz, room.z0 + (j + 1) * tz, y - 0.25, 0.5, col)
			end
		end
	elseif room.fl == 2 and hole then
		rectWithHole("Floor", y - 0.25, 0.5, room.floor, B.mat(room.fmat))
	else
		rectXZ("Floor", room.x0, room.x1, room.z0, room.z1, y - 0.25, 0.5, room.floor, B.mat(room.fmat))
	end
	-- потолок (нижняя часть перекрытия)
	if room.fl == 1 then
		rectWithHole("Ceiling", y + h + 0.25, 0.5, room.ceil)
	else
		rectXZ("Ceiling", room.x0, room.x1, room.z0, room.z1, y + h + 0.25, 0.5, room.ceil)
	end
end

-- наружная обшивка: 4 стены по периметру дома на два этажа, с проёмами окон и дверей
local function shell(parent)
	local m = B.model(parent, "Shell")
	local X0, X1, Z0, Z1 = C.House.X0, C.House.X1, C.House.Z0, C.House.Z1
	local h = C.House.WallH
	local o = SHELL / 2
	for fl = 1, 2 do
		local y = floorY(fl)
		local hh = h + 1
		B.wall(m, "S" .. fl, Vector3.new(X0 - SHELL, y, Z0 - o), Vector3.new(X1 + SHELL, y, Z0 - o), hh, SHELL, SIDING, nil, openingsOn(fl, "z", Z0, X0, X1, X0 - SHELL))
		B.wall(m, "N" .. fl, Vector3.new(X0 - SHELL, y, Z1 + o), Vector3.new(X1 + SHELL, y, Z1 + o), hh, SHELL, SIDING, nil, openingsOn(fl, "z", Z1, X0, X1, X0 - SHELL))
		B.wall(m, "W" .. fl, Vector3.new(X0 - o, y, Z0), Vector3.new(X0 - o, y, Z1), hh, SHELL, SIDING, nil, openingsOn(fl, "x", X0, Z0, Z1, Z0))
		B.wall(m, "E" .. fl, Vector3.new(X1 + o, y, Z0), Vector3.new(X1 + o, y, Z1), hh, SHELL, SIDING, nil, openingsOn(fl, "x", X1, Z0, Z1, Z0))
	end
	-- межэтажный пояс, углы, цоколь
	local band = "#D9C79A"
	B.part(m, "Band", Vector3.new(X1 - X0 + SHELL * 2 + 0.4, 0.8, 0.3), CFrame.new((X0 + X1) / 2, 11.6, Z0 - SHELL - 0.15), band)
	B.part(m, "Band", Vector3.new(X1 - X0 + SHELL * 2 + 0.4, 0.8, 0.3), CFrame.new((X0 + X1) / 2, 11.6, Z1 + SHELL + 0.15), band)
	B.part(m, "Band", Vector3.new(0.3, 0.8, Z1 - Z0 + SHELL * 2), CFrame.new(X0 - SHELL - 0.15, 11.6, (Z0 + Z1) / 2), band)
	B.part(m, "Band", Vector3.new(0.3, 0.8, Z1 - Z0 + SHELL * 2), CFrame.new(X1 + SHELL + 0.15, 11.6, (Z0 + Z1) / 2), band)
	for _, p in ipairs({ { X0 - SHELL, Z0 - SHELL }, { X1 + SHELL, Z0 - SHELL }, { X0 - SHELL, Z1 + SHELL }, { X1 + SHELL, Z1 + SHELL } }) do
		B.part(m, "Corner", Vector3.new(0.9, 24, 0.9), CFrame.new(p[1], 12, p[2]), TRIM)
	end
	-- цоколь (дом стоит на 1.2 выше земли)
	B.part(m, "Foundation", Vector3.new(X1 - X0 + SHELL * 2 + 0.6, 1.4, Z1 - Z0 + SHELL * 2 + 0.6), CFrame.new((X0 + X1) / 2, -0.75, (Z0 + Z1) / 2), FOUND, Enum.Material.Concrete)
	return m
end

-- окно: рама изнутри и снаружи, стекло, перемычка, подоконник
local function window(o, parent)
	local y = floorY(o.fl)
	local m = B.model(parent, o.id or "Window")
	B.attrs(m, { Kind = "Window" })
	local horiz = o.axis == "z"
	local w, hgt = o.w, o.y1 - o.y0
	local cy = y + (o.y0 + o.y1) / 2
	local base
	if horiz then base = CFrame.new(o.c, cy, o.at) else base = CFrame.new(o.at, cy, o.c) * CFrame.Angles(0, math.rad(90), 0) end
	-- в локальных координатах окна: X — вдоль стены, Z — сквозь стену (наружу при at = 0 / x = 0 — это −Z)
	local P = B.kit(m, base)
	local depth = T * 2 + SHELL + 0.4
	P("Glass", w - 0.3, hgt - 0.3, 0.12, 0, 0, 0, "#BFE6FF", Enum.Material.Glass, { Transparency = 0.72, CastShadow = false, Reflectance = 0.05 })
	local f = 0.3
	-- рама (сквозь всю толщину стены)
	P("Frame", w + f * 2, f, depth, 0, hgt / 2 + f / 2, 0, TRIM)
	P("Frame", w + f * 2, f, depth, 0, -hgt / 2 - f / 2, 0, TRIM)
	P("Frame", f, hgt, depth, -w / 2 - f / 2, 0, 0, TRIM)
	P("Frame", f, hgt, depth, w / 2 + f / 2, 0, 0, TRIM)
	-- переплёт
	P("Mullion", 0.18, hgt, 0.2, 0, 0, 0, TRIM)
	if hgt > 4.2 then P("Mullion", w, 0.18, 0.2, 0, hgt * 0.12, 0, TRIM) end
	-- подоконники с обеих сторон
	P("Sill", w + 1.0, 0.25, 0.7, 0, -hgt / 2 - f - 0.12, depth / 2 + 0.2, TRIM)
	P("Sill", w + 1.0, 0.25, 0.7, 0, -hgt / 2 - f - 0.12, -depth / 2 - 0.2, TRIM)
	return m
end

-- наличник вокруг дверного проёма (с обеих сторон стены)
local function casing(o, parent)
	local y = floorY(o.fl)
	local m = B.model(parent, "Casing")
	local base
	if o.axis == "z" then base = CFrame.new(o.c, y, o.at) else base = CFrame.new(o.at, y, o.c) * CFrame.Angles(0, math.rad(90), 0) end
	local P = B.kit(m, base)
	local depth = (o.kind == "exdoor" or o.id == "Garage") and (T + SHELL + 0.3) * 2 or (T * 2 + 0.3)
	local h = o.y1
	P("Jamb", 0.45, h + 0.45, depth, -o.w / 2 - 0.22, h / 2 + 0.22, 0, TRIM)
	P("Jamb", 0.45, h + 0.45, depth, o.w / 2 + 0.22, h / 2 + 0.22, 0, TRIM)
	P("Head", o.w + 0.9, 0.45, depth, 0, h + 0.22, 0, TRIM)
	return m
end

-- лестница: видимые ступени (без столкновений) + невидимый пандус (по нему ходят)
local function stairs(parent)
	local m = B.model(parent, "Stairs")
	local n = STAIR.steps
	local run = (STAIR.z1 - STAIR.z0) / n
	local rise = 12 / n
	local wdt = STAIR.x1 - STAIR.x0
	local cx = (STAIR.x0 + STAIR.x1) / 2
	for i = 1, n do
		local top = rise * i
		local z0 = STAIR.z0 + (i - 1) * run
		B.part(m, "Step", Vector3.new(wdt, top, run), CFrame.new(cx, top / 2, z0 + run / 2), "#C99A6B", nil, { CanCollide = false })
		B.part(m, "Nose", Vector3.new(wdt, 0.18, run + 0.12), CFrame.new(cx, top - 0.09, z0 + run / 2 - 0.06), "#9B6A42", nil, { CanCollide = false })
		B.part(m, "Riser", Vector3.new(wdt - 0.1, rise - 0.2, 0.06), CFrame.new(cx, top - rise / 2 - 0.1, z0 - 0.02), "#F6F2EA", nil, { CanCollide = false })
	end
	-- пандус
	local len = math.sqrt((STAIR.z1 - STAIR.z0) ^ 2 + 12 ^ 2)
	B.wedge(m, "Ramp", Vector3.new(wdt, 12, STAIR.z1 - STAIR.z0), CFrame.new(cx, 6, (STAIR.z0 + STAIR.z1) / 2), nil, nil,
		{ Transparency = 1, CanCollide = true, CastShadow = false, CanQuery = true })
	-- боковая панель (тетива) со стороны прихожей
	B.part(m, "Stringer", Vector3.new(0.3, 1.1, len + 0.6), CFrame.new(STAIR.x1 + 0.15, 6.2, (STAIR.z0 + STAIR.z1) / 2) * CFrame.Angles(-math.atan2(12, STAIR.z1 - STAIR.z0), 0, 0), "#9B6A42")
	-- перила вдоль лестницы
	local rail = "#7A4E2C"
	for i = 0, 4 do
		local z = STAIR.z0 + 0.6 + i * (STAIR.z1 - STAIR.z0 - 1.2) / 4
		local yb = (z - STAIR.z0) / (STAIR.z1 - STAIR.z0) * 12
		B.part(m, "Baluster", Vector3.new(0.3, 3.2, 0.3), CFrame.new(STAIR.x1 - 0.2, yb + 1.6, z), "#F6F2EA")
	end
	B.part(m, "Handrail", Vector3.new(0.35, 0.3, len), CFrame.new(STAIR.x1 - 0.2, 6 + 3.2, (STAIR.z0 + STAIR.z1) / 2) * CFrame.Angles(-math.atan2(12, STAIR.z1 - STAIR.z0), 0, 0), rail)
	B.part(m, "Newel", Vector3.new(0.7, 4.2, 0.7), CFrame.new(STAIR.x1 - 0.2, 2.1, STAIR.z0 - 0.2), rail)
	-- ограждение проёма на 2 этаже (восточный и южный край)
	local y2 = 12
	B.part(m, "Rail2", Vector3.new(0.35, 0.3, STAIR.z1 - STAIR.z0 + 0.4), CFrame.new(STAIR.x1 + 0.1, y2 + 3.4, (STAIR.z0 + STAIR.z1) / 2), rail)
	B.part(m, "Rail2", Vector3.new(STAIR.x1 - STAIR.x0 + 0.4, 0.3, 0.35), CFrame.new(cx, y2 + 3.4, STAIR.z0 - 0.1), rail)
	for z = STAIR.z0, STAIR.z1, 2 do
		B.part(m, "Baluster2", Vector3.new(0.25, 3.4, 0.25), CFrame.new(STAIR.x1 + 0.1, y2 + 1.7, z), "#F6F2EA")
	end
	for x = STAIR.x0 + 1, STAIR.x1, 2 do
		B.part(m, "Baluster2", Vector3.new(0.25, 3.4, 0.25), CFrame.new(x, y2 + 1.7, STAIR.z0 - 0.1), "#F6F2EA")
	end
	-- невидимые барьеры по краю проёма (чтобы не упасть вниз)
	B.marker(m, "Barrier", Vector3.new(0.5, 6, STAIR.z1 - STAIR.z0), CFrame.new(STAIR.x1 + 0.1, y2 + 3, (STAIR.z0 + STAIR.z1) / 2), { CanCollide = true })
	B.marker(m, "Barrier", Vector3.new(STAIR.x1 - STAIR.x0, 6, 0.5), CFrame.new(cx, y2 + 3, STAIR.z0 - 0.1), { CanCollide = true })
	-- кладовка под лестницей (стенка со стороны гостиной уже есть) — торцевая стенка внизу
	return m
end

-- крыша: двускатная, конёк вдоль x
local function roof(parent)
	local m = B.model(parent, "Roof")
	local X0, X1, Z0, Z1 = C.House.X0, C.House.X1, C.House.Z0, C.House.Z1
	local base = 24
	local rise = 11
	local half = (Z1 - Z0) / 2 + SHELL
	local cz = (Z0 + Z1) / 2
	local cx = (X0 + X1) / 2
	-- чердак (фронтоны): два клина в цвет обшивки
	-- у клина высокая грань сзади (+Z): южная половина — как есть, северная — развёрнута
	B.wedge(m, "Gable", Vector3.new(X1 - X0 + SHELL * 2, rise, half), CFrame.new(cx, base + rise / 2, cz - half / 2), SIDING)
	B.wedge(m, "Gable", Vector3.new(X1 - X0 + SHELL * 2, rise, half), CFrame.new(cx, base + rise / 2, cz + half / 2) * CFrame.Angles(0, math.rad(180), 0), SIDING)
	-- скаты
	local slope = math.atan2(rise, half)
	local len = math.sqrt(rise * rise + half * half) + 2.2
	local over = 2.2
	local w = X1 - X0 + SHELL * 2 + over * 2
	for _, s in ipairs({ -1, 1 }) do
		local cf = CFrame.new(cx, base + rise / 2 + 0.6, cz + s * half / 2) * CFrame.Angles(s * slope, 0, 0)
		B.part(m, "RoofSlab", Vector3.new(w, 0.7, len), cf * CFrame.new(0, 0, s * 1.0), ROOF)
		-- полосы черепицы
		for k = 1, 5 do
			B.part(m, "Shingle", Vector3.new(w, 0.12, 0.25), cf * CFrame.new(0, 0.4, s * 1.0 + (k - 3) * len / 6), B.shade(ROOF, 0.85))
		end
		-- водосток
		B.part(m, "Gutter", Vector3.new(w, 0.5, 0.5), CFrame.new(cx, base - 0.5, cz + s * (half + over)), "#E9E5DC")
	end
	B.part(m, "Ridge", Vector3.new(w, 0.6, 1.2), CFrame.new(cx, base + rise + 0.75, cz), B.shade(ROOF, 0.8))
	-- карниз над вторым этажом
	B.part(m, "Eave", Vector3.new(X1 - X0 + SHELL * 2 + 0.8, 0.5, Z1 - Z0 + SHELL * 2 + 0.8), CFrame.new(cx, base - 0.25, cz), TRIM)
	-- труба
	B.part(m, "Chimney", Vector3.new(3, 14, 3), CFrame.new(X0 + 6, base + 7, cz + 6), "#A0574A", Enum.Material.Brick)
	B.part(m, "ChimneyCap", Vector3.new(3.6, 0.6, 3.6), CFrame.new(X0 + 6, base + 14.3, cz + 6), "#6B4A40")
	return m
end

-- гараж справа от дома: внутри лаборатория Рика (Garage.lua), ворота поднимает клиент в главе 2
local function garage(parent)
	local m = B.model(parent, "Garage")
	local x0, x1, z0, z1 = C.House.X1 + SHELL, C.House.X1 + 25, -1, 26
	local h = 13
	local th = 0.7
	local cx = (x0 + x1) / 2
	B.part(m, "Floor", Vector3.new(x1 - x0, 1.2, z1 - z0), CFrame.new(cx, -0.6, (z0 + z1) / 2), FOUND, Enum.Material.Concrete)
	-- стены: полые (внутри — лаборатория Рика, см. Garage.lua)
	local yb, ht = -1.2, h
	B.part(m, "WallN", Vector3.new(x1 - x0, ht, th), CFrame.new(cx, yb + ht / 2, z1 - th / 2), SIDING)
	B.part(m, "WallE", Vector3.new(th, ht, z1 - z0), CFrame.new(x1 - th / 2, yb + ht / 2, (z0 + z1) / 2), SIDING)
	-- передняя стена с проёмом ворот 16 × 9
	local dw, dh = 16, 9
	local dl, dr = cx - dw / 2, cx + dw / 2
	B.part(m, "WallS", Vector3.new(dl - x0, ht, th), CFrame.new((x0 + dl) / 2, yb + ht / 2, z0 + th / 2), SIDING)
	B.part(m, "WallS", Vector3.new(x1 - dr, ht, th), CFrame.new((dr + x1) / 2, yb + ht / 2, z0 + th / 2), SIDING)
	B.part(m, "Header", Vector3.new(dw, ht - (dh + 1.2), th), CFrame.new(cx, yb + 1.2 + dh + (ht - dh - 1.2) / 2, z0 + th / 2), SIDING)
	B.part(m, "Ceiling", Vector3.new(x1 - x0, 0.4, z1 - z0), CFrame.new(cx, yb + ht - 0.2, (z0 + z1) / 2), "#BDB8AE")
	-- ворота: панель и полосы в одной модели (клиент поднимает их в сюжете)
	local leaf = B.model(m, "GarageDoorLeaf")
	local door = B.part(leaf, "GarageDoor", Vector3.new(dw, dh, 0.3), CFrame.new(cx, dh / 2, z0 + 0.35), "#F1EEE6")
	for k = 1, 4 do
		B.part(leaf, "Panel", Vector3.new(dw + 0.1, 0.18, 0.42), CFrame.new(cx, k * 1.8, z0 + 0.35), "#D9D4C8")
	end
	B.part(leaf, "HandleBar", Vector3.new(1.6, 0.25, 0.5), CFrame.new(cx, 1.2, z0 + 0.3), "#8E969E", Enum.Material.Metal)
	leaf.PrimaryPart = door
	B.part(m, "DoorTrim", Vector3.new(dw + 1.2, 0.6, 0.6), CFrame.new(cx, dh + 0.3, z0 - 0.1), TRIM)
	B.part(m, "DoorTrimL", Vector3.new(0.6, dh, 0.6), CFrame.new(dl - 0.3, dh / 2, z0 - 0.1), TRIM)
	B.part(m, "DoorTrimR", Vector3.new(0.6, dh, 0.6), CFrame.new(dr + 0.3, dh / 2, z0 - 0.1), TRIM)
	-- пологий пандус от подъездной дорожки к полу гаража (чтобы не спотыкаться)
	B.wedge(m, "Ramp", Vector3.new(dw, 1.2, 2.4), CFrame.new(cx, -0.6, z0 - 1.2), FOUND, Enum.Material.Concrete)
	-- односкатная крыша: высокая сторона у стены дома (−X)
	B.wedge(m, "Roof", Vector3.new(z1 - z0 + 2, 4, x1 - x0 + 2), CFrame.new(cx, h - 1.2 + 2, (z0 + z1) / 2) * CFrame.Angles(0, math.rad(-90), 0), ROOF)
	-- окошко сбоку
	B.part(m, "Window", Vector3.new(0.3, 3, 4), CFrame.new(x1 + 0.05, 6, 16), "#7DA6C2", Enum.Material.Glass, { Transparency = 0.2 })
	B.part(m, "WindowFrame", Vector3.new(0.4, 3.6, 4.6), CFrame.new(x1 + 0.02, 6, 16), TRIM)
	-- зелёный отсвет из-под ворот (Рик что-то мастерит)
	local glow = B.part(m, "Glow", Vector3.new(15, 0.15, 0.6), CFrame.new(cx, 0.08, z0 - 0.2), "#7CFF4A", Enum.Material.Neon, { CastShadow = false })
	B.light(glow, "PointLight", { Color = Color3.fromRGB(120, 255, 80), Brightness = 1.5, Range = 8, Shadows = false })
	return m
end

-- крыльцо с навесом у входной двери
local function porch(parent)
	local m = B.model(parent, "Porch")
	local cx = 32
	B.part(m, "Deck", Vector3.new(12, 1.2, 6), CFrame.new(cx, -0.6, -3.7), "#A88C6C", Enum.Material.WoodPlanks)
	B.part(m, "Step", Vector3.new(7, 0.6, 1.6), CFrame.new(cx, -0.9, -7.5), "#B9B3A8", Enum.Material.Concrete)
	for _, dx in ipairs({ -5.4, 5.4 }) do
		B.part(m, "Column", Vector3.new(0.8, 9.6, 0.8), CFrame.new(cx + dx, 4.8, -6.2), TRIM)
	end
	B.wedge(m, "Canopy", Vector3.new(13, 1.6, 7), CFrame.new(cx, 10.4, -3.8), ROOF)
	B.part(m, "Beam", Vector3.new(13, 0.6, 0.8), CFrame.new(cx, 9.4, -6.2), TRIM)
	B.part(m, "Mat", Vector3.new(4, 0.1, 2.4), CFrame.new(cx, 0.05, -1.8), "#7A3E2E", Enum.Material.Fabric)
	local lamp = B.part(m, "PorchLamp", Vector3.new(0.6, 1, 0.6), CFrame.new(cx + 3.4, 8.5, -0.9), "#FFF1C6", Enum.Material.Neon)
	B.light(lamp, "PointLight", { Color = Color3.fromRGB(255, 214, 160), Brightness = 0.6, Range = 10, Enabled = false })
	-- номер дома
	local plate = B.part(m, "Number", Vector3.new(2.2, 1, 0.15), CFrame.new(cx - 3.6, 6.5, -0.95), "#2B3A5A")
	B.sign(plate, Enum.NormalId.Front, "19", { TextColor3 = Color3.fromRGB(240, 220, 160) })
	return m
end

-- пол и потолок для каждой комнаты, отделка стен, окна, наличники
function House.build(ctx, root)
	B, C = ctx.Build, ctx.Config
	H = root
	local structure = B.folder(root, "Structure")
	for _, r in ipairs(ROOMS) do
		lining(r, structure)
		slabs(r, structure)
	end
	shell(structure)
	local wins = B.folder(root, "Windows")
	for _, o in ipairs(OPENINGS) do
		if o.kind == "window" then window(o, wins)
		elseif o.kind == "door" or o.kind == "exdoor" or o.kind == "arch" then casing(o, structure) end
	end
	stairs(structure)
	roof(structure)
	garage(structure)
	porch(structure)
	-- зоны комнат (для подсказок и звуков шагов)
	local zones = B.folder(root, "Rooms")
	for _, r in ipairs(ROOMS) do
		local y = floorY(r.fl)
		local z = B.marker(zones, r.id, Vector3.new(r.x1 - r.x0, C.House.WallH, r.z1 - r.z0),
			CFrame.new((r.x0 + r.x1) / 2, y + C.House.WallH / 2, (r.z0 + r.z1) / 2))
		B.attrs(z, { Label = r.label, Floor = r.fl, Mat = r.fmat or "Tile" })
	end
	return root
end

-- данные проёма по id (для Doors.lua)
function House.opening(id)
	for _, o in ipairs(OPENINGS) do
		if o.id == id then return o end
	end
	return nil
end

return House
