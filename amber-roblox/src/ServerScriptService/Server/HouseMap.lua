-- Карта «Дом 1990»: двухэтажный пригородный дом с пристроенным гаражом, двором с яблонями и улицей.
-- Строит модель дома по контракту ARCHITECTURE.md §6: двери, окна, укрытия, яблони, щиток, ТВ, магазин,
-- лампы, объёмы комнат, точки появления. Координаты — относительно origin (стад ≈ 0.29 м).
-- Улица на −Z, задний двор на +Z. Пол 1 этажа y=1, потолок 13, пол 2 этажа 14, потолок 26.
--
-- План 1 этажа (вид сверху; улица сверху = −Z):
--
--        X: -50            -26       -7      7                 26
--   Z=-20  +=====ВОРОТА=====+=окно==окно=+[ВХОД]+==окно====окно==+   фасад, крыльцо с колоннами
--          |  ГАРАЖ         | СТОЛОВАЯ   |шкаф  |  ГОСТИНАЯ      |
--          |  лавка яблок   |  стол      арка   |диван  столик [ТВ]  ТВ смотрит на −X (на диван)
--          |  (прилавок,    |            |ЛЕСТ- арка            |
--   Z=0    |   продавец)    |--дверь-----|НИЦА  |----арка--------|
--          |  холодильник   |ПРАЧЕЧНАЯ|туал|  ↑   | КУХНЯ кладовая |
--          |  щиток  ←дверь |         |----|  ↑   дверь  стол    |
--          |  верстак шкаф  |  стирка      |холл  |  плита  мойка   |
--   Z=+20  +================+===окно=======+окно--+=[ЗАДНЯЯ]=окно==+   задняя стена, крылечко во двор
--
-- План 2 этажа:  над столовой — ДЕТСКАЯ, над прачечной — СПАЛЬНЯ 2, над прихожей спереди — ВАННАЯ,
--   над гостиной — СПАЛЬНЯ РОДИТЕЛЕЙ, над кухней — КАБИНЕТ, посередине — коридор с бельевым шкафом.
-- Двор (+Z): забор 6 стадов с калитками, 6 мест под яблони (3 посажены), сарай, качели, разбрызгиватель.
-- Улица (−Z): тротуар, бордюр, фонари, почтовый ящик, подъездная дорожка с седаном, силуэты соседей.

local HouseMap = {}

local B, Config, M
local S -- состояние текущей постройки (build не уступает управление, поэтому одно на модуль)

local EXT, INT = 1.5, 1                       -- толщина наружных и внутренних стен
local F1, F2, C1, C2, TOP = 1, 14, 13, 26, 27  -- полы, потолки, верх стен
local PITCH = 0.625                            -- уклон крыши
local RIDGE = TOP + 20.75 * PITCH              -- конёк основной крыши
local GRIDGE = 13.6 + 12.75 * PITCH            -- конёк крыши гаража
local WARM = Color3.fromRGB(255, 214, 170)
local NC = { CanCollide = false }
local NCS = { CanCollide = false, CastShadow = false }
local WHITE = "#f1ece0"

local function deps()
	if B then return end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	B = require(Shared:WaitForChild("Build"))
	Config = require(Shared:WaitForChild("Config"))
end

local function initMats()
	local E = Enum.Material
	M = {
		wood = E.Wood, planks = E.WoodPlanks, fabric = E.Fabric, plastic = E.SmoothPlastic, metal = E.Metal,
		concrete = E.Concrete, brick = E.Brick, glass = E.Glass, neon = E.Neon, grass = E.Grass, asphalt = E.Asphalt,
		pavement = E.Pavement, slate = E.Slate, marble = E.Marble, ground = E.Ground, granite = E.Granite,
		foil = E.Foil, diamond = E.DiamondPlate, pebble = E.Pebble, mud = E.Mud,
		carpet = B.mat("Carpet", E.Fabric), plaster = B.mat("Plaster", E.SmoothPlastic),
		tiles = B.mat("CeramicTiles", E.Marble), shingles = B.mat("RoofShingles", E.Slate),
		leather = B.mat("Leather", E.Fabric), cardboard = B.mat("Cardboard", E.Wood), rubber = B.mat("Rubber", E.Plastic),
	}
end

local function img(key)
	return (Config and Config.Images and Config.Images[key]) or ""
end

-- ===== базовые помощники =====
local function V(x, y, z) return S.o + Vector3.new(x, y, z) end
local function CF(x, y, z, yaw)
	local c = CFrame.new(S.o.X + x, S.o.Y + y, S.o.Z + z)
	if yaw and yaw ~= 0 then c = c * CFrame.Angles(0, math.rad(yaw), 0) end
	return c
end
local function rnd(a, b) return a + (b - a) * S.rng:NextNumber() end
-- лёгкий разброс яркости цвета
local function vary(c, amt)
	c = B.color(c)
	local k = 1 + (S.rng:NextNumber() * 2 - 1) * (amt or 0.06)
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end
-- деталь по двум углам (локальные координаты)
local function blk(parent, name, x0, y0, z0, x1, y1, z1, color, mat, props)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	return B.part(parent, name, size, CF((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, mat, props)
end
-- деталь в системе f: x, z — центр, y — низ
local function fb(parent, name, f, x, y, z, sx, sy, sz, color, mat, props)
	return B.part(parent, name, Vector3.new(sx, sy, sz), f * CFrame.new(x, y + sy / 2, z), color, mat, props)
end
-- вертикальный цилиндр (y — низ)
local function fvc(parent, name, f, x, y, z, h, d, color, mat, props)
	return B.vcyl(parent, name, h, d, f * CFrame.new(x, y + h / 2, z), color, mat, props)
end
-- цилиндр вдоль локальной X / Z (центр)
local function fcx(parent, name, f, x, y, z, len, d, color, mat, props)
	return B.cyl(parent, name, len, d, f * CFrame.new(x, y, z), color, mat, props)
end
local function fcz(parent, name, f, x, y, z, len, d, color, mat, props)
	return B.cyl(parent, name, len, d, f * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(90), 0), color, mat, props)
end
local function fball(parent, name, f, x, y, z, d, color, mat, props)
	return B.ball(parent, name, d, f * CFrame.new(x, y, z), color, mat, props)
end
local function mark(parent, name, cf, size)
	return B.marker(parent, name, size or Vector3.new(1, 0.2, 1), cf)
end
-- деталь между двумя точками (перила, кабели)
local function beam(parent, name, a, b, th, color, mat, props)
	local d = (b - a).Magnitude
	return B.part(parent, name, Vector3.new(th, th, d), CFrame.lookAt((a + b) / 2, b), color, mat, props)
end
-- поворот так, чтобы локальная +Z смотрела внутрь (inside = знак нормали стены)
local function faceYaw(axis, inside)
	if axis == "x" then
		if inside > 0 then return 0 end
		return 180
	end
	if inside > 0 then return 90 end
	return -90
end
local function wallNormal(axis, inside)
	if axis == "x" then return Vector3.new(0, 0, inside) end
	return Vector3.new(inside, 0, 0)
end

-- ===== реестр проёмов в стенах =====
-- axis "x": стена вдоль X (линия z = line); "z": вдоль Z (x = line). c — центр проёма вдоль стены.
local function hole(axis, line, c, w, y0, y1, kind)
	table.insert(S.holes, { axis = axis, line = line, c = c, w = w, y0 = y0, y1 = y1, kind = kind })
end
local function holesOn(axis, line, s0, s1, yb, yt)
	local out = {}
	for _, h in ipairs(S.holes) do
		if h.axis == axis and math.abs(h.line - line) <= 0.8 and h.c > s0 and h.c < s1 and h.y1 > yb and h.y0 < yt then
			table.insert(out, h)
		end
	end
	return out
end
-- стена по линии с проёмами из реестра
local function wallLine(parent, name, axis, line, s0, s1, yb, yt, th, color, mat)
	local a, b
	if axis == "x" then a, b = V(s0, yb, line), V(s1, yb, line) else a, b = V(line, yb, s0), V(line, yb, s1) end
	local ops = {}
	for _, h in ipairs(holesOn(axis, line, s0, s1, yb, yt)) do
		table.insert(ops, { at = h.c - s0, w = h.w, y0 = math.max(0, h.y0 - yb), y1 = math.min(yt - yb, h.y1 - yb) })
	end
	return B.wall(parent, name, a, b, yt - yb, th, color, mat, ops)
end
-- отрезки [s0,s1] без проёмов (margin — запас по краям)
local function freeSpans(list, s0, s1, margin)
	table.sort(list, function(p, q) return p.c < q.c end)
	local spans, cur = {}, s0
	for _, h in ipairs(list) do
		local a, b = h.c - h.w / 2 - margin, h.c + h.w / 2 + margin
		if a > cur then table.insert(spans, { cur, a }) end
		cur = math.max(cur, b)
	end
	if s1 > cur then table.insert(spans, { cur, s1 }) end
	return spans
end

-- ===== свет =====
local function lampGlow(room, size, cf, shape, cls, lprops, color)
	S.lampN = S.lampN + 1
	local p = B.part(S.f.Lights, "Lamp_" .. room .. "_" .. S.lampN, size, cf, color or Color3.fromRGB(255, 236, 200), M.neon, NCS)
	if shape then p.Shape = shape end
	B.attrs(p, { Room = room, Glow = true })
	local lp = { Color = WARM, Range = 18, Brightness = 1.4 }
	if lprops then for k, v in pairs(lprops) do lp[k] = v end end
	B.light(p, cls or "PointLight", lp)
	table.insert(S.lights, p)
	return p
end
-- потолочный светильник: "dome" | "pendant" | "chandelier" | "fluor" | "fan" | "bar"
local function ceilingLight(room, x, z, cy, style, lprops)
	local par, f = S.f.Fixtures, CF(x, cy, z)
	local brass, cyl = "#b08a4a", Enum.PartType.Cylinder
	local down = CFrame.Angles(0, 0, math.rad(90))
	if style == "pendant" then
		fvc(par, "Cord", f, 0, -3.2, 0, 3.2, 0.12, "#2a2a2a", M.plastic, NCS)
		fvc(par, "Shade", f, 0, -4.4, 0, 1.3, 2.4, "#3a6a4a", M.glass, { CanCollide = false, CastShadow = false, Transparency = 0.25 })
		return lampGlow(room, Vector3.new(0.8, 0.8, 0.8), f * CFrame.new(0, -4.1, 0), Enum.PartType.Ball, "PointLight", lprops)
	elseif style == "chandelier" then
		fvc(par, "Stem", f, 0, -2.6, 0, 2.6, 0.18, brass, M.metal, NCS)
		for i = 0, 4 do
			local a = i * math.pi * 2 / 5
			local px, pz = math.cos(a) * 1.4, math.sin(a) * 1.4
			B.part(par, "Arm", Vector3.new(1.4, 0.12, 0.12), f * CFrame.new(px / 2, -2.6, pz / 2) * CFrame.Angles(0, -a, 0), brass, M.metal, NCS)
			fvc(par, "Candle", f, px, -2.6, pz, 0.6, 0.22, "#f4ecd8", M.plastic, NCS)
			fball(par, "Flame", f, px, -1.85, pz, 0.28, "#ffe2a8", M.neon, NCS)
		end
		return lampGlow(room, Vector3.new(0.9, 0.9, 0.9), f * CFrame.new(0, -2.9, 0), Enum.PartType.Ball, "PointLight", lprops)
	elseif style == "fluor" then
		fb(par, "Fixture", f, 0, -0.35, 0, 6, 0.35, 1.3, "#e8e8e4", M.metal, NCS)
		return lampGlow(room, Vector3.new(5.6, 0.25, 0.6), f * CFrame.new(0, -0.47, 0), nil, "PointLight", lprops, Color3.fromRGB(240, 244, 255))
	elseif style == "fan" then
		fvc(par, "Rod", f, 0, -1.6, 0, 1.6, 0.25, brass, M.metal, NCS)
		fvc(par, "Motor", f, 0, -2.3, 0, 0.8, 1.3, brass, M.metal, NCS)
		for i = 0, 3 do
			B.part(par, "Blade", Vector3.new(4.2, 0.08, 0.9), f * CFrame.Angles(0, i * math.pi / 2 + 0.3, 0) * CFrame.new(2.6, -2.0, 0), "#6a4a2e", M.wood, NCS)
		end
		return lampGlow(room, Vector3.new(0.5, 1.1, 1.1), f * CFrame.new(0, -2.6, 0) * down, cyl, "PointLight", lprops)
	elseif style == "bar" then
		return nil
	end
	-- dome: плоский плафон
	fvc(par, "Base", f, 0, -0.2, 0, 0.2, 2.4, brass, M.metal, NCS)
	return lampGlow(room, Vector3.new(0.5, 2, 2), f * CFrame.new(0, -0.45, 0) * down, cyl, "PointLight", lprops)
end
-- настольная лампа (y — верх поверхности)
local function tableLamp(room, x, y, z, shadeColor, lprops)
	local par, f = S.f.Fixtures, CF(x, y, z)
	fvc(par, "LampBase", f, 0, 0, 0, 0.25, 0.9, "#b08a4a", M.metal, NC)
	fvc(par, "LampStem", f, 0, 0.25, 0, 1.4, 0.15, "#b08a4a", M.metal, NC)
	fvc(par, "LampShade", f, 0, 1.3, 0, 1.0, 1.4, shadeColor or "#efe2c4", M.fabric, { CanCollide = false, CastShadow = false, Transparency = 0.15 })
	return lampGlow(room, Vector3.new(0.45, 0.45, 0.45), f * CFrame.new(0, 1.6, 0), Enum.PartType.Ball, "PointLight",
		lprops or { Range = 12, Brightness = 1.1 })
end
local function floorLamp(room, x, y, z)
	local par, f = S.f.Fixtures, CF(x, y, z)
	fvc(par, "LampBase", f, 0, 0, 0, 0.25, 1.4, "#3a3530", M.metal)
	fvc(par, "LampPole", f, 0, 0.25, 0, 5.2, 0.18, "#b08a4a", M.metal, NC)
	fvc(par, "LampShade", f, 0, 5.1, 0, 1.3, 1.8, "#e8d8a8", M.fabric, { CanCollide = false, CastShadow = false, Transparency = 0.15 })
	return lampGlow(room, Vector3.new(0.5, 0.5, 0.5), f * CFrame.new(0, 5.6, 0), Enum.PartType.Ball, "PointLight", { Range = 14, Brightness = 1.2 })
end
-- уличный фонарь у стены (бра)
local function wallLantern(room, x, y, z, yaw)
	local par, f = S.f.Fixtures, CF(x, y, z, yaw)
	fb(par, "LanternPlate", f, 0, -0.6, 0, 0.7, 1.6, 0.2, "#1e1e1e", M.metal, NC)
	fb(par, "LanternCap", f, 0, 0.75, -0.55, 1.0, 0.25, 1.0, "#1e1e1e", M.metal, NC)
	fb(par, "LanternGlass", f, 0, -0.55, -0.55, 0.85, 1.3, 0.85, "#f4e2b0", M.glass, { CanCollide = false, CastShadow = false, Transparency = 0.45 })
	return lampGlow(room, Vector3.new(0.4, 0.4, 0.4), f * CFrame.new(0, 0.1, -0.55), Enum.PartType.Ball, "PointLight", { Range = 16, Brightness = 1.3 })
end

-- ===== дверь (контракт §6: Leaf/Panel/Hinge/Prompt/LockPrompt/PathfindingModifier/In/Out) =====
-- d = { name, axis, x, z, y, inside (куда открывается), hinge (±1 вдоль локальной X), th, ext, color, style, room }
local function door(d)
	local f = CF(d.x, d.y, d.z, faceYaw(d.axis, d.inside))
	local th, color = d.th or INT, d.color or "#d8ccb0"
	local m = B.model(S.f.Doors, d.name)
	-- коробка и наличники (вне Leaf)
	fb(m, "Jamb", f, -2.65, -0.1, 0, 0.3, 8.9, th + 0.14, WHITE, M.wood)
	fb(m, "Jamb", f, 2.65, -0.1, 0, 0.3, 8.9, th + 0.14, WHITE, M.wood)
	fb(m, "Head", f, 0, 8.5, 0, 5.6, 0.3, th + 0.14, WHITE, M.wood)
	fb(m, "Threshold", f, 0, -0.1, 0, 5.6, 0.1, th + 0.3, "#7a5a3a", M.wood)
	for _, s in ipairs({ -1, 1 }) do
		local z = s * (th / 2 + 0.17)
		if not (d.ext and s < 0) then
			fb(m, "Casing", f, -3.15, -0.1, z, 0.7, 9.3, 0.16, WHITE, M.wood, NC)
			fb(m, "Casing", f, 3.15, -0.1, z, 0.7, 9.3, 0.16, WHITE, M.wood, NC)
			fb(m, "Casing", f, 0, 8.8, z, 7.0, 0.7, 0.16, WHITE, M.wood, NC)
		end
	end
	if d.ext then -- снаружи наличник поверх обшивки
		local z = -(th / 2 + 0.3)
		fb(m, "Casing", f, -3.2, -0.1, z, 0.8, 9.4, 0.2, WHITE, M.wood, NC)
		fb(m, "Casing", f, 3.2, -0.1, z, 0.8, 9.4, 0.2, WHITE, M.wood, NC)
		fb(m, "Casing", f, 0, 8.9, z, 7.2, 0.9, 0.2, WHITE, M.wood, NC)
	end
	local leaf = B.model(m, "Leaf")
	local panel = fb(leaf, "Panel", f, 0, 0.05, 0, 4.8, 8.4, 0.35, color, M.wood)
	leaf.PrimaryPart = panel
	local inset = vary(color, 0.12)
	if d.style == "back" then
		fb(leaf, "Glass", f, 0, 4.6, 0, 3.4, 3.0, 0.4, "#a9c2cf", M.glass, { Transparency = 0.45, CanCollide = false })
		fb(leaf, "Muntin", f, 0, 4.6, 0, 0.14, 3.0, 0.45, color, M.wood, NC)
		fb(leaf, "Muntin", f, 0, 6.03, 0, 3.4, 0.14, 0.45, color, M.wood, NC)
		fb(leaf, "Inset", f, 0, 0.9, 0, 3.4, 2.8, 0.43, inset, M.wood, NC)
	else
		for _, px in ipairs({ -1.05, 1.05 }) do
			fb(leaf, "Inset", f, px, 0.9, 0, 1.6, 2.9, 0.43, inset, M.wood, NC)
			if d.style == "front" then
				fb(leaf, "Glass", f, px, 5.2, 0, 1.4, 2.2, 0.43, "#c8b070", M.glass, { Transparency = 0.35, CanCollide = false })
			else
				fb(leaf, "Inset", f, px, 4.5, 0, 1.6, 3.2, 0.43, inset, M.wood, NC)
			end
		end
	end
	local kx = -d.hinge * 1.95
	for _, s in ipairs({ -1, 1 }) do
		fball(leaf, "Knob", f, kx, 4.1, s * 0.33, 0.36, "#c9a24a", M.metal, NC)
		fcz(leaf, "Rose", f, kx, 4.1, s * 0.2, 0.08, 0.5, "#c9a24a", M.metal, NC)
		if d.ext then fcz(leaf, "Deadbolt", f, kx, 5.0, s * 0.2, 0.08, 0.4, "#c9a24a", M.metal, NC) end
	end
	mark(m, "Hinge", f * CFrame.new(d.hinge * 2.4, 4.25, 0), Vector3.new(0.2, 8.4, 0.2))
	B.prompt(panel, "Prompt", "Открыть", "Дверь", { HoldDuration = 0 })
	B.prompt(panel, "LockPrompt", "Запереть", "Дверь", { KeyboardKeyCode = Enum.KeyCode.R, HoldDuration = 0.7, UIOffset = Vector2.new(0, 60) })
	local pm = Instance.new("PathfindingModifier")
	pm.Label = "Door"
	pm.PassThrough = true
	pm.Parent = panel
	B.attrs(m, { Kind = "Door", Exterior = d.ext == true, Lockable = d.lock ~= false, OpenAngle = 100 * d.hinge,
		Open = false, Locked = false, Broken = false, Health = 100, Room = d.room or "" })
	if d.ext then
		local n = wallNormal(d.axis, d.inside)
		local c = Vector3.new(d.x, d.y + 0.1, d.z)
		local pin, pout = c + n * 3.2, c - n * 4.2
		mark(m, "In", CFrame.lookAt(S.o + pin, S.o + pin + n))
		mark(m, "Out", CFrame.lookAt(S.o + pout, S.o + pout + n))
		table.insert(S.entries, m)
	end
	table.insert(S.doors, m)
	return m
end

-- арочный проём с наличниками (без створки)
local function archway(a)
	local f = CF(a.x, a.y, a.z, faceYaw(a.axis, 1))
	local w, h, th = a.w, a.h or 9.5, a.th or INT
	local par = S.f.Trim
	fb(par, "Jamb", f, -(w / 2 + 0.15), -0.1, 0, 0.3, h + 0.1, th + 0.14, WHITE, M.wood)
	fb(par, "Jamb", f, w / 2 + 0.15, -0.1, 0, 0.3, h + 0.1, th + 0.14, WHITE, M.wood)
	fb(par, "Head", f, 0, h - 0.3, 0, w + 0.6, 0.3, th + 0.14, WHITE, M.wood)
	fb(par, "Threshold", f, 0, -0.1, 0, w + 0.6, 0.1, th + 0.2, "#7a5a3a", M.wood)
	for _, s in ipairs({ -1, 1 }) do
		local z = s * (th / 2 + 0.17)
		fb(par, "Casing", f, -(w / 2 + 0.65), -0.1, z, 0.7, h + 0.4, 0.16, WHITE, M.wood, NC)
		fb(par, "Casing", f, w / 2 + 0.65, -0.1, z, 0.7, h + 0.4, 0.16, WHITE, M.wood, NC)
		fb(par, "Casing", f, 0, h, z, w + 2, 0.7, 0.16, WHITE, M.wood, NC)
	end
end

-- ===== окно (Glass, рама, подоконник, шторы/жалюзи, ставни; у входных окон — In/Out) =====
-- w = { name, room, axis, x, z, y, inside, w, h, sill, curtain, blinds, entry, inD, shutter }
local function window(wd)
	local W, Ht, sill = wd.w or 4.5, wd.h or 5.5, wd.sill or 3.2
	local f = CF(wd.x, wd.y + sill, wd.z, faceYaw(wd.axis, wd.inside))
	local th = EXT
	local m = B.model(S.f.Windows, wd.name)
	fb(m, "Frame", f, -(W / 2 + 0.15), -0.3, 0, 0.3, Ht + 0.6, th, WHITE, M.wood)
	fb(m, "Frame", f, W / 2 + 0.15, -0.3, 0, 0.3, Ht + 0.6, th, WHITE, M.wood)
	fb(m, "Frame", f, 0, Ht, 0, W + 0.6, 0.3, th, WHITE, M.wood)
	fb(m, "Frame", f, 0, -0.3, 0, W + 0.6, 0.3, th, WHITE, M.wood)
	fb(m, "Glass", f, 0, 0, 0.1, W, Ht, 0.15, "#9fb8c8", M.glass, { Transparency = 0.5, Reflectance = 0.05 })
	fb(m, "Sash", f, 0, Ht / 2 - 0.15, 0.1, W, 0.3, 0.42, WHITE, M.wood, NC)
	fb(m, "Muntin", f, 0, 0, 0.1, 0.16, Ht, 0.3, WHITE, M.wood, NC)
	-- внутри: подоконник, фартук, наличники
	local zi = th / 2
	fb(m, "Sill", f, 0, -0.55, zi + 0.4, W + 1.6, 0.25, 0.9, WHITE, M.wood)
	fb(m, "Apron", f, 0, -1.1, zi + 0.14, W + 1.2, 0.55, 0.12, WHITE, M.wood, NC)
	fb(m, "Casing", f, -(W / 2 + 0.6), -0.3, zi + 0.12, 0.6, Ht + 0.9, 0.14, WHITE, M.wood, NC)
	fb(m, "Casing", f, W / 2 + 0.6, -0.3, zi + 0.12, 0.6, Ht + 0.9, 0.14, WHITE, M.wood, NC)
	fb(m, "Casing", f, 0, Ht + 0.3, zi + 0.12, W + 1.8, 0.6, 0.14, WHITE, M.wood, NC)
	-- снаружи: отлив, наличники, ставни
	local zo = -(th / 2 + 0.3)
	fb(m, "SillOut", f, 0, -0.65, -(th / 2 + 0.35), W + 1.4, 0.3, 0.8, WHITE, M.wood)
	fb(m, "CasingOut", f, -(W / 2 + 0.6), -0.3, zo, 0.7, Ht + 0.9, 0.2, WHITE, M.wood, NC)
	fb(m, "CasingOut", f, W / 2 + 0.6, -0.3, zo, 0.7, Ht + 0.9, 0.2, WHITE, M.wood, NC)
	fb(m, "CasingOut", f, 0, Ht + 0.3, zo, W + 2, 0.8, 0.2, WHITE, M.wood, NC)
	if wd.shutter ~= false and W >= 4 then
		for _, s in ipairs({ -1, 1 }) do
			local sx = s * (W / 2 + 1.95)
			fb(m, "Shutter", f, sx, -0.2, zo - 0.05, 2.0, Ht + 0.5, 0.16, S.shutter, M.wood, NC)
			for k = 1, 3 do
				fb(m, "ShutterRail", f, sx, -0.2 + k * (Ht + 0.5) / 4, zo - 0.15, 1.7, 0.12, 0.06, vary(S.shutter, 0.2), M.wood, NCS)
			end
		end
	end
	-- шторы или жалюзи
	if wd.blinds then
		fb(m, "BlindRail", f, 0, Ht - 0.2, zi + 0.35, W + 0.2, 0.3, 0.4, WHITE, M.plastic, NC)
		for k = 1, 6 do
			fb(m, "Blind", f, 0, Ht - 0.3 - k * 0.24, zi + 0.35, W, 0.06, 0.45, "#efe8d6", M.plastic, NCS)
		end
	else
		local cc = wd.curtain or "#7a2f2f"
		fcx(m, "Rod", f, 0, Ht + 0.9, zi + 0.9, W + 2.6, 0.18, "#8a6a3a", M.metal, NC)
		for _, s in ipairs({ -1, 1 }) do
			fb(m, "Curtain", f, s * (W / 2 + 0.2), -1.4, zi + 0.9, 1.7, Ht + 2.2, 0.28, vary(cc, 0.04), M.fabric, NCS)
		end
		fb(m, "Valance", f, 0, Ht + 0.6, zi + 1.05, W + 2.6, 0.9, 0.2, vary(cc, 0.08), M.fabric, NCS)
	end
	B.attrs(m, { Kind = "Window", Broken = false, Room = wd.room })
	if wd.entry then
		local n = wallNormal(wd.axis, wd.inside)
		local c = Vector3.new(wd.x, 0, wd.z)
		local pin = c + n * (th / 2 + (wd.inD or 3)) + Vector3.new(0, wd.y + 0.1, 0)
		local pout = c - n * (th / 2 + 4) + Vector3.new(0, (wd.outY or 0) + 0.1, 0)
		mark(m, "In", CFrame.lookAt(S.o + pin, S.o + pin + n))
		mark(m, "Out", CFrame.lookAt(S.o + pout, S.o + pout + n))
		table.insert(S.entries, m)
	end
	table.insert(S.windows, m)
	return m
end

-- ===== укрытие: шкаф с жалюзийными дверцами =====
-- h = { name, room, kind = "Closet"|"Wardrobe"|"Cabinet", x, z, y, yaw (LookVector смотрит наружу), w, ht, d, color }
local function hideSpot(h)
	local f = CF(h.x, h.y, h.z, h.yaw)
	local w, ht, d = h.w or 5.2, h.ht or 8.4, h.d or 3.6
	local mat = (h.kind == "Cabinet") and M.metal or M.wood
	local col = h.color or WHITE
	local m = B.model(S.f.Hides, h.name)
	fb(m, "Back", f, 0, 0, d / 2 - 0.15, w, ht, 0.3, col, mat)
	fb(m, "Side", f, -(w / 2 - 0.15), 0, 0, 0.3, ht, d, col, mat)
	fb(m, "Side", f, w / 2 - 0.15, 0, 0, 0.3, ht, d, col, mat)
	fb(m, "Top", f, 0, ht - 0.3, 0, w, 0.3, d, col, mat)
	fb(m, "Crown", f, 0, ht, -0.08, w + 0.4, 0.3, d + 0.25, vary(col, 0.08), mat, NC)
	fb(m, "Plinth", f, 0, 0, -d / 2 + 0.25, w - 0.6, 0.45, 0.3, vary(col, 0.1), mat)
	-- невидимая преграда на месте дверец (слеты сами не мешают обзору изнутри)
	fb(m, "Front", f, 0, 0.45, -d / 2 + 0.2, w - 0.6, ht - 0.75, 0.3, nil, nil, { Transparency = 1 })
	local lh = ht - 0.75 - 0.05
	local lw = (w - 0.6) / 2 - 0.04
	local slat = vary(col, 0.05)
	local doorPart
	for _, s in ipairs({ -1, 1 }) do
		local cx = s * (lw / 2 + 0.02)
		local zf = -d / 2 + 0.12
		local st1 = fb(m, "Stile", f, cx - s * (lw / 2 - 0.17), 0.45, zf, 0.34, lh, 0.22, col, mat, NC)
		fb(m, "Stile", f, cx + s * (lw / 2 - 0.17), 0.45, zf, 0.34, lh, 0.22, col, mat, NC)
		fb(m, "Rail", f, cx, 0.45, zf, lw, 0.4, 0.22, col, mat, NC)
		fb(m, "Rail", f, cx, 0.45 + lh - 0.4, zf, lw, 0.4, 0.22, col, mat, NC)
		fb(m, "Rail", f, cx, 0.45 + lh / 2 - 0.2, zf, lw, 0.4, 0.22, col, mat, NC)
		local n = math.floor((lh / 2 - 0.6) / 0.55)
		for half = 0, 1 do
			local y0 = 0.45 + 0.4 + half * (lh / 2)
			for k = 0, n - 1 do
				B.part(m, "Slat", Vector3.new(lw - 0.6, 0.4, 0.06), f * CFrame.new(cx, y0 + 0.3 + k * 0.55, zf) * CFrame.Angles(math.rad(40), 0, 0), slat, mat, NCS)
			end
		end
		fball(m, "Knob", f, s * 0.35, ht * 0.5, -d / 2 - 0.05, 0.3, "#c9a24a", M.metal, NC)
		if s < 0 then doorPart = st1 end
	end
	doorPart.Name = "Door"
	-- одежда внутри
	fcx(m, "Rod", f, 0, ht - 1.4, d / 2 - 0.9, w - 0.6, 0.12, "#9a9a9a", M.metal, NCS)
	for i = 1, 3 do
		fb(m, "Clothes", f, -1.4 + i * 0.7, ht - 4.6, d / 2 - 0.9, 0.35, 3.1, 1.7, vary(h.clothes or "#5a4a6a", 0.3), M.fabric, NCS)
	end
	mark(m, "Inside", f * CFrame.new(0, 3, 0.15), Vector3.new(1, 1, 1))
	mark(m, "Exit", f * CFrame.new(0, 0.1, -(d / 2 + 2.8)))
	B.prompt(doorPart, "Prompt", "Спрятаться", h.label or "Шкаф", { HoldDuration = 0, MaxActivationDistance = 7 })
	B.attrs(m, { Kind = "Hide", HideType = h.kind or "Closet", Occupant = 0, Room = h.room })
	table.insert(S.hides, m)
	return m
end

-- ===== отделка комнат =====
local function planks(par, x0, z0, x1, z1, y, alongX, w, c, mat)
	local a0, a1 = z0, z1
	local L0, L1 = x0, x1
	if not alongX then a0, a1, L0, L1 = x0, x1, z0, z1 end
	local n = math.max(1, math.floor((a1 - a0) / w + 0.5))
	local ww = (a1 - a0) / n
	for i = 0, n - 1 do
		local a = a0 + i * ww
		local cut = L0 + (L1 - L0) * rnd(0.2, 0.8)
		local pieces = { { L0, cut }, { cut, L1 } }
		for _, p in ipairs(pieces) do
			local col = vary(c, 0.09)
			if alongX then
				blk(par, "Plank", p[1] + 0.03, y - 0.1, a + 0.03, p[2] - 0.03, y, a + ww - 0.03, col, mat or M.wood)
			else
				blk(par, "Plank", a + 0.03, y - 0.1, p[1] + 0.03, a + ww - 0.03, y, p[2] - 0.03, col, mat or M.wood)
			end
		end
	end
end
local function tiles(par, x0, z0, x1, z1, y, size, ca, cb, mat)
	local nx = math.max(1, math.floor((x1 - x0) / size + 0.5))
	local nz = math.max(1, math.floor((z1 - z0) / size + 0.5))
	local sx, sz = (x1 - x0) / nx, (z1 - z0) / nz
	for i = 0, nx - 1 do
		for k = 0, nz - 1 do
			local c = ca
			if cb and (i + k) % 2 == 1 then c = cb end
			blk(par, "Tile", x0 + i * sx + 0.04, y - 0.1, z0 + k * sz + 0.04, x0 + (i + 1) * sx - 0.04, y, z0 + (k + 1) * sz - 0.04, vary(c, 0.05), mat or M.tiles)
		end
	end
end
-- пол по типу
local function floorRect(par, kind, x0, z0, x1, z1, y, c, c2)
	if kind == "planks" then
		planks(par, x0, z0, x1, z1, y, (x1 - x0) >= (z1 - z0), 1.15, c)
	elseif kind == "planksX" then
		planks(par, x0, z0, x1, z1, y, true, 1.15, c)
	elseif kind == "planksZ" then
		planks(par, x0, z0, x1, z1, y, false, 1.15, c)
	elseif kind == "tiles" then
		tiles(par, x0, z0, x1, z1, y, 1.8, c, c2, M.tiles)
	elseif kind == "vinyl" then
		tiles(par, x0, z0, x1, z1, y, 2.4, c, c2, M.plastic)
	elseif kind == "concrete" then
		local mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
		for _, q in ipairs({ { x0, z0, mx, mz }, { mx, z0, x1, mz }, { x0, mz, mx, z1 }, { mx, mz, x1, z1 } }) do
			blk(par, "Slab", q[1] + 0.05, y - 0.1, q[2] + 0.05, q[3] - 0.05, y, q[4] - 0.05, vary(c, 0.04), M.concrete)
		end
	else
		local p = blk(par, "Carpet", x0, y - 0.1, z0, x1, y, z1, c, M.carpet)
		B.texture(p, Enum.NormalId.Top, img("Carpet"), 8, 8)
	end
end
-- стороны комнаты: обои/краска, плинтус, карниз, потолок
-- r = { name, x0, z0, x1, z1, y, h, floor, fc, fc2, wall, tex, wains, wainsColor, noWalls, noCeil, skip = {s=,n=,w=,e=} }
local function finishRoom(r)
	local par = S.f.Interior
	local y, h = r.y, r.h or 12
	local cy = y + h
	if r.floor then floorRect(S.f.Floors, r.floor, r.x0, r.z0, r.x1, r.z1, y, r.fc, r.fc2) end
	if not r.noCeil then
		local c = blk(par, "Ceiling", r.x0, cy - 0.2, r.z0, r.x1, cy, r.z1, r.ceil or "#e8e2d4", M.plaster)
		B.texture(c, Enum.NormalId.Bottom, img("Ceiling"), 8, 8)
	end
	local sides = {
		{ key = "s", axis = "x", face = r.z0, s0 = r.x0, s1 = r.x1, inward = 1 },
		{ key = "n", axis = "x", face = r.z1, s0 = r.x0, s1 = r.x1, inward = -1 },
		{ key = "w", axis = "z", face = r.x0, s0 = r.z0, s1 = r.z1, inward = 1 },
		{ key = "e", axis = "z", face = r.x1, s0 = r.z0, s1 = r.z1, inward = -1 },
	}
	for _, sd in ipairs(sides) do
		if not (r.skip and r.skip[sd.key]) then
			local all = holesOn(sd.axis, sd.face - sd.inward * 0.6, sd.s0, sd.s1, y, cy)
			local function along(s0, s1, off, y0, y1, th, color, mat, name, props)
				local line = sd.face + sd.inward * off
				local cx, cz, sx, sz = (s0 + s1) / 2, line, s1 - s0, th
				if sd.axis == "z" then cx, cz, sx, sz = line, (s0 + s1) / 2, th, s1 - s0 end
				return B.part(par, name, Vector3.new(sx, y1 - y0, sz), CF(cx, (y0 + y1) / 2, cz), color, mat, props)
			end
			-- обои (тонкая облицовка с проёмами)
			if not r.noWalls then
				local line = sd.face + sd.inward * 0.04
				local a, b
				if sd.axis == "x" then a, b = V(sd.s0, y, line), V(sd.s1, y, line) else a, b = V(line, y, sd.s0), V(line, y, sd.s1) end
				local ops = {}
				for _, hh in ipairs(all) do
					table.insert(ops, { at = hh.c - sd.s0, w = hh.w, y0 = math.max(0, hh.y0 - y), y1 = math.min(h, hh.y1 - y) })
				end
				local wm = B.wall(par, "Wallpaper", a, b, h - 0.2, 0.08, r.wall or "#d9cfbd", M.plaster, ops, NCS)
				if r.tex then
					for _, p in ipairs(wm:GetChildren()) do
						B.texture(p, Enum.NormalId.Front, img(r.tex), 6, 6)
						B.texture(p, Enum.NormalId.Back, img(r.tex), 6, 6)
					end
				end
				-- плитка до половины стены (ванные)
				if r.wains then
					local ops2 = {}
					for _, hh in ipairs(all) do
						table.insert(ops2, { at = hh.c - sd.s0, w = hh.w, y0 = math.max(0, hh.y0 - y), y1 = math.min(r.wains, hh.y1 - y) })
					end
					local line2 = sd.face + sd.inward * 0.12
					if sd.axis == "x" then a, b = V(sd.s0, y, line2), V(sd.s1, y, line2) else a, b = V(line2, y, sd.s0), V(line2, y, sd.s1) end
					local tm = B.wall(par, "WallTiles", a, b, r.wains, 0.1, r.wainsColor or "#dfe8e6", M.tiles, ops2, NCS)
					for _, p in ipairs(tm:GetChildren()) do
						B.texture(p, Enum.NormalId.Front, img("BathTiles"), 2, 2)
						B.texture(p, Enum.NormalId.Back, img("BathTiles"), 2, 2)
					end
				end
			end
			-- плинтус без дверных проёмов
			local low = {}
			for _, hh in ipairs(all) do
				if hh.y0 <= y + 0.6 then table.insert(low, hh) end
			end
			for _, sp in ipairs(freeSpans(low, sd.s0, sd.s1, 0.7)) do
				if sp[2] - sp[1] > 0.3 then
					along(sp[1], sp[2], 0.17, y, y + 0.65, 0.18, r.base or WHITE, M.wood, "Baseboard", NCS)
				end
			end
			-- карниз под потолком
			if not r.noCrown then
				along(sd.s0, sd.s1, 0.24, cy - 0.65, cy - 0.2, 0.32, WHITE, M.wood, "Crown", NCS)
			end
		end
	end
end

-- ===== обшивка сайдингом =====
-- out — знак наружной нормали; доски по 1 стаду с наклоном и разбросом цвета
local function siding(axis, line, s0, s1, out, y0, y1, color)
	local par = S.f.Siding
	local list = holesOn(axis, line, s0, s1, y0, y1)
	local off = line + out * (EXT / 2 + 0.1)
	local tilt = math.rad(3) * out
	local y = y0
	while y < y1 - 0.05 do
		local yt = math.min(y + 1, y1)
		local row = {}
		for _, hh in ipairs(list) do
			if hh.y1 + 0.6 > y and hh.y0 - 0.6 < yt then table.insert(row, hh) end
		end
		local col = vary(color, 0.035)
		for _, sp in ipairs(freeSpans(row, s0, s1, 0.75)) do
			local len = sp[2] - sp[1]
			if len > 0.2 then
				local cf
				if axis == "x" then
					cf = CF((sp[1] + sp[2]) / 2, (y + yt) / 2, off) * CFrame.Angles(-tilt, 0, 0)
					B.part(par, "Siding", Vector3.new(len, yt - y + 0.06, 0.2), cf, col, M.wood)
				else
					cf = CF(off, (y + yt) / 2, (sp[1] + sp[2]) / 2) * CFrame.Angles(0, 0, tilt)
					B.part(par, "Siding", Vector3.new(0.2, yt - y + 0.06, len), cf, col, M.wood)
				end
			end
		end
		y = yt
	end
end

-- скат крыши: e — середина карниза, r — середина конька (локальные Vector3), len — длина вдоль конька
local function slope(par, name, e, r, len, th, color, mat, props)
	local d = r - e
	local u = d.Unit
	local R = Vector3.yAxis:Cross(u).Unit
	local n = u:Cross(R)
	local c = S.o + (e + r) / 2 - n * (th / 2)
	return B.part(par, name, Vector3.new(len, th, d.Magnitude), CFrame.fromMatrix(c, R, n), color, mat, props), n
end
-- кровля: настил + ряды черепицы с разбросом цвета
local function roofPlane(e, r, len, courses)
	local par = S.f.Roof
	local deck, n = slope(par, "Deck", e, r, len, 0.8, "#3a332e", M.wood)
	local d = r - e
	for k = 0, courses - 1 do
		local a = e + d * (k / courses)
		local b = e + d * ((k + 1) / courses) + d.Unit * 0.35
		local p = slope(par, "Shingles", a + n * 0.18, b + n * 0.18, len + 0.2, 0.22, vary("#4a423c", 0.1), M.shingles)
		B.texture(p, Enum.NormalId.Top, img("RoofShingles"), 6, 6)
	end
	return deck, n
end

-- ===== план: двери, арки, окна (локальные координаты осей стен) =====
local DOORS = {
	{ name = "Door_Front", axis = "x", x = 3, z = -20, y = F1, inside = 1, hinge = 1, th = EXT, ext = true, color = "#6e1f1c", style = "front", room = "Hall" },
	{ name = "Door_Back", axis = "x", x = 12, z = 20, y = F1, inside = -1, hinge = -1, th = EXT, ext = true, color = "#e8e0cc", style = "back", room = "Kitchen" },
	{ name = "Door_Garage", axis = "z", x = -26, z = 5, y = F1, inside = 1, hinge = -1, th = EXT, color = "#cfc3a6", room = "Garage" },
	{ name = "Door_Kitchen", axis = "z", x = 7, z = 14, y = F1, inside = -1, hinge = 1, room = "Kitchen" },
	{ name = "Door_Laundry", axis = "z", x = -7, z = 14.5, y = F1, inside = -1, hinge = 1, room = "Laundry" },
	{ name = "Door_HalfBath", axis = "x", x = -11, z = 9, y = F1, inside = -1, hinge = 1, room = "HalfBath" },
	{ name = "Door_Bathroom", axis = "x", x = 3, z = -8, y = F2, inside = -1, hinge = -1, room = "Bathroom" },
	{ name = "Door_KidsRoom", axis = "z", x = -7, z = -5, y = F2, inside = -1, hinge = -1, room = "KidsRoom" },
	{ name = "Door_Bedroom2", axis = "z", x = -7, z = 13, y = F2, inside = -1, hinge = 1, room = "Bedroom2" },
	{ name = "Door_Bedroom1", axis = "z", x = 7, z = -3, y = F2, inside = 1, hinge = -1, room = "Bedroom1" },
	{ name = "Door_Study", axis = "z", x = 7, z = 13, y = F2, inside = 1, hinge = -1, room = "Study" },
}
local ARCHES = {
	{ axis = "z", x = -7, z = -11.5, y = F1, w = 6 },  -- прихожая → столовая
	{ axis = "z", x = 7, z = -2.5, y = F1, w = 6 },    -- коридор → гостиная
	{ axis = "x", x = 18, z = 2, y = F1, w = 6 },      -- гостиная → кухня
	{ axis = "x", x = -20.5, z = 0, y = F1, w = 5 },   -- столовая → прачечная
}
local WINDOWS = {
	-- 1 этаж: все окна — точки взлома (In/Out)
	{ name = "Window_LivingRoom_1", room = "LivingRoom", axis = "x", x = 14, z = -20, y = F1, inside = 1, entry = true, curtain = "#7a2f2f" },
	{ name = "Window_LivingRoom_2", room = "LivingRoom", axis = "x", x = 21.5, z = -20, y = F1, inside = 1, entry = true, curtain = "#7a2f2f" },
	{ name = "Window_LivingRoom_3", room = "LivingRoom", axis = "z", x = 26, z = -16.5, y = F1, inside = -1, entry = true, curtain = "#7a2f2f" },
	{ name = "Window_Dining_1", room = "Dining", axis = "x", x = -20, z = -20, y = F1, inside = 1, entry = true, curtain = "#2a4a6a" },
	{ name = "Window_Dining_2", room = "Dining", axis = "x", x = -12, z = -20, y = F1, inside = 1, entry = true, curtain = "#2a4a6a" },
	{ name = "Window_Kitchen_1", room = "Kitchen", axis = "x", x = 21.5, z = 20, y = F1, inside = -1, entry = true, blinds = true, inD = 5.5, sill = 3.8, h = 4.6 },
	{ name = "Window_Kitchen_2", room = "Kitchen", axis = "z", x = 26, z = 14.5, y = F1, inside = -1, entry = true, blinds = true, inD = 5.5, sill = 3.8, h = 4.6 },
	{ name = "Window_Hall_1", room = "Hall", axis = "x", x = -3.5, z = 20, y = F1, inside = -1, entry = true, curtain = "#8a7a4a" },
	{ name = "Window_Laundry_1", room = "Laundry", axis = "x", x = -12, z = 20, y = F1, inside = -1, entry = true, blinds = true },
	{ name = "Window_Garage_1", room = "Garage", axis = "z", x = -50, z = -1, y = F1, inside = 1, entry = true, blinds = true, shutter = false },
	{ name = "Window_Garage_2", room = "Garage", axis = "z", x = -50, z = 7, y = F1, inside = 1, entry = true, blinds = true, shutter = false },
	-- 2 этаж
	{ name = "Window_KidsRoom_1", room = "KidsRoom", axis = "x", x = -20, z = -20, y = F2, inside = 1, curtain = "#4a6a9a" },
	{ name = "Window_KidsRoom_2", room = "KidsRoom", axis = "x", x = -12, z = -20, y = F2, inside = 1, curtain = "#4a6a9a" },
	{ name = "Window_KidsRoom_3", room = "KidsRoom", axis = "z", x = -26, z = -10, y = F2, inside = 1, curtain = "#4a6a9a" },
	{ name = "Window_Bathroom_1", room = "Bathroom", axis = "x", x = 3.5, z = -20, y = F2, inside = 1, w = 3, h = 3, sill = 5, blinds = true, shutter = false },
	{ name = "Window_Bedroom1_1", room = "Bedroom1", axis = "x", x = 12, z = -20, y = F2, inside = 1, curtain = "#6a3a5a" },
	{ name = "Window_Bedroom1_2", room = "Bedroom1", axis = "x", x = 21.5, z = -20, y = F2, inside = 1, curtain = "#6a3a5a" },
	{ name = "Window_Bedroom1_3", room = "Bedroom1", axis = "z", x = 26, z = -0.5, y = F2, inside = -1, curtain = "#6a3a5a" },
	{ name = "Window_Study_1", room = "Study", axis = "x", x = 16, z = 20, y = F2, inside = -1, blinds = true },
	{ name = "Window_Study_2", room = "Study", axis = "z", x = 26, z = 12, y = F2, inside = -1, curtain = "#5a6a3a" },
	{ name = "Window_Upstairs_1", room = "Upstairs", axis = "x", x = 3.5, z = 20, y = F2, inside = -1, curtain = "#8a7a4a" },
	{ name = "Window_Bedroom2_1", room = "Bedroom2", axis = "x", x = -20, z = 20, y = F2, inside = -1, curtain = "#3a5a4a" },
	{ name = "Window_Bedroom2_2", room = "Bedroom2", axis = "x", x = -12, z = 20, y = F2, inside = -1, curtain = "#3a5a4a" },
	{ name = "Window_Bedroom2_3", room = "Bedroom2", axis = "z", x = -26, z = 16.5, y = F2, inside = 1, curtain = "#3a5a4a" },
}

local function registerHoles()
	for _, d in ipairs(DOORS) do
		local line, c = d.z, d.x
		if d.axis == "z" then line, c = d.x, d.z end
		hole(d.axis, line, c, 5.6, d.y - 0.1, d.y + 8.8, "door")
	end
	for _, a in ipairs(ARCHES) do
		local line, c = a.z, a.x
		if a.axis == "z" then line, c = a.x, a.z end
		hole(a.axis, line, c, a.w + 0.6, a.y - 0.1, a.y + 9.5, "arch")
	end
	for _, w in ipairs(WINDOWS) do
		local line, c = w.z, w.x
		if w.axis == "z" then line, c = w.x, w.z end
		local sill, ht = w.sill or 3.2, w.h or 5.5
		hole(w.axis, line, c, (w.w or 4.5) + 0.6, w.y + sill - 0.3, w.y + sill + ht + 0.3, "window")
	end
	hole("x", -20, -38, 16, 0.9, 11, "garage")
end

-- ===== каркас: плиты, стены, обшивка =====
local A = {} -- функции зон

function A.structure()
	local st = S.f.Structure
	local core, slab = "#d9cfbd", "#55524c"
	blk(st, "Foundation", -25.25, 0, -19.25, 25.25, 0.9, 19.25, slab, M.concrete)
	blk(st, "Foundation", -49.25, 0, -19.25, -26.75, 0.9, 19.25, slab, M.concrete)
	-- перекрытие с проёмом под лестницу (X -6.5..-0.5, Z -2..10)
	blk(st, "FloorSlab", -25.25, C1, -19.25, -6.5, 13.9, 19.25, slab, M.wood)
	blk(st, "FloorSlab", -0.5, C1, -19.25, 25.25, 13.9, 19.25, slab, M.wood)
	blk(st, "FloorSlab", -6.5, C1, -19.25, -0.5, 13.9, -2, slab, M.wood)
	blk(st, "FloorSlab", -6.5, C1, 10, -0.5, 13.9, 19.25, slab, M.wood)
	blk(st, "AtticSlab", -25.25, C2, -19.25, 25.25, TOP, 19.25, slab, M.wood)
	blk(st, "GarageAttic", -49.25, C1, -19.25, -26.75, 13.6, 19.25, slab, M.wood)
	-- наружные стены
	wallLine(st, "WallFront", "x", -20, -26.75, 26.75, 0, TOP, EXT, core, M.plaster)
	wallLine(st, "WallBack", "x", 20, -26.75, 26.75, 0, TOP, EXT, core, M.plaster)
	wallLine(st, "WallEast", "z", 26, -19.25, 19.25, 0, TOP, EXT, core, M.plaster)
	wallLine(st, "WallWest", "z", -26, -19.25, 19.25, 0, TOP, EXT, core, M.plaster)
	wallLine(st, "GarageFront", "x", -20, -50.75, -26.75, 0, 13.6, EXT, core, M.plaster)
	wallLine(st, "GarageBack", "x", 20, -50.75, -26.75, 0, 13.6, EXT, core, M.plaster)
	wallLine(st, "GarageWest", "z", -50, -19.25, 19.25, 0, 13.6, EXT, core, M.plaster)
	-- внутренние стены 1 этажа
	local y0, y1 = 0.9, C1
	wallLine(st, "Wall", "z", -7, -19.25, 19.25, y0, y1, INT, core, M.plaster)
	wallLine(st, "Wall", "z", 7, -19.25, 19.25, y0, y1, INT, core, M.plaster)
	wallLine(st, "Wall", "x", 2, 7.5, 25.25, y0, y1, INT, core, M.plaster)
	wallLine(st, "Wall", "x", 0, -25.25, -7.5, y0, y1, INT, core, M.plaster)
	wallLine(st, "Wall", "z", -15, 0.5, 9.5, y0, y1, INT, core, M.plaster)
	wallLine(st, "Wall", "x", 9, -15.5, -7.5, y0, y1, INT, core, M.plaster)
	-- внутренние стены 2 этажа
	y0, y1 = 13.9, C2
	wallLine(st, "Wall", "z", -7, -19.25, 19.25, y0, y1, INT, core, M.plaster)
	wallLine(st, "Wall", "z", 7, -19.25, 19.25, y0, y1, INT, core, M.plaster)
	wallLine(st, "Wall", "x", -8, -6.5, 6.5, y0, y1, INT, core, M.plaster)
	wallLine(st, "Wall", "x", 0, -25.25, -7.5, y0, y1, INT, core, M.plaster)
	wallLine(st, "Wall", "x", 4, 7.5, 25.25, y0, y1, INT, core, M.plaster)
	-- обшивка сайдингом, угловые доски, цоколь
	local sc = S.siding
	siding("x", -20, -26.95, 26.95, -1, 0.9, TOP, sc)
	siding("x", 20, -26.95, 26.95, 1, 0.9, TOP, sc)
	siding("z", 26, -20.95, 20.95, 1, 0.9, TOP, sc)
	siding("z", -26, -20.95, 20.95, -1, 14.6, TOP, sc)
	siding("x", -20, -50.95, -26.95, -1, 0.9, 13.6, sc)
	siding("x", 20, -50.95, -26.95, 1, 0.9, 13.6, sc)
	siding("z", -50, -20.95, 20.95, -1, 0.9, 13.6, sc)
	for _, c in ipairs({ { 26.85, -20.85, TOP }, { 26.85, 20.85, TOP }, { -50.85, -20.85, 13.6 }, { -50.85, 20.85, 13.6 } }) do
		blk(st, "CornerBoard", c[1] - 0.5, 0.9, c[2] - 0.5, c[1] + 0.5, c[3], c[2] + 0.5, WHITE, M.wood)
	end
	blk(st, "Plinth", -50.95, 0, -21.05, 26.95, 0.9, -20.75, "#77746c", M.concrete)
	blk(st, "Plinth", -50.95, 0, 20.75, 26.95, 0.9, 21.05, "#77746c", M.concrete)
	blk(st, "Plinth", 26.75, 0, -20.75, 27.05, 0.9, 20.75, "#77746c", M.concrete)
	blk(st, "Plinth", -51.05, 0, -20.75, -50.75, 0.9, 20.75, "#77746c", M.concrete)
	-- кирпичная труба на восточной стене
	local brick = "#7a4234"
	blk(st, "Chimney", 26.95, 0, -13.5, 31.4, 31.5, -6.5, brick, M.brick)
	blk(st, "Chimney", 27.9, 31.5, -12.6, 31.2, RIDGE + 2.5, -7.4, vary(brick, 0.08), M.brick)
	blk(st, "ChimneyCap", 27.6, RIDGE + 2.5, -12.9, 31.5, RIDGE + 3.1, -7.1, "#6a6a66", M.concrete)
	fvc(st, "Flue", CF(29.55, RIDGE + 3.1, -10), 0, 0, 0, 1.2, 1.2, "#3a3a3a", M.metal)
	for k = 1, 5 do
		blk(st, "BrickBand", 26.9, k * 5.6, -13.55, 31.45, k * 5.6 + 0.25, -6.45, vary(brick, 0.15), M.brick)
	end
end

-- ===== крыши =====
function A.roofs()
	local rf, core = S.f.Roof, "#d9cfbd"
	local rise = RIDGE - TOP
	for _, sx in ipairs({ -26, 26 }) do
		B.wedge(rf, "Gable", Vector3.new(EXT, rise, 20.75), CF(sx, TOP + rise / 2, -10.375), core, M.plaster)
		B.wedge(rf, "Gable", Vector3.new(EXT, rise, 20.75), CF(sx, TOP + rise / 2, 10.375, 180), core, M.plaster)
		local xs = sx + ((sx > 0) and 0.85 or -0.85)
		local tilt = math.rad(3) * ((sx > 0) and 1 or -1)
		local y = TOP
		while y < RIDGE - 1 do
			local hw = (RIDGE - (y + 1)) / PITCH
			B.part(S.f.Siding, "Siding", Vector3.new(0.2, 1.06, hw * 2), CF(xs, y + 0.5, 0) * CFrame.Angles(0, 0, tilt), vary(S.siding, 0.035), M.wood)
			y = y + 1
		end
		-- вентиляционная решётка во фронтоне
		blk(rf, "Vent", xs - 0.15, TOP + 5, -1.6, xs + 0.15, TOP + 8, 1.6, WHITE, M.wood)
	end
	local eY = TOP - 2.25 * PITCH
	for _, s in ipairs({ -1, 1 }) do
		roofPlane(Vector3.new(0, eY, 23 * s), Vector3.new(0, RIDGE, 0), 56, 12)
		blk(rf, "Fascia", -28, eY - 1.1, 23 * s - 0.15, 28, eY - 0.1, 23 * s + 0.15, WHITE, M.wood)
		blk(rf, "Soffit", -28, eY - 0.95, (s > 0) and 20.95 or -23, 28, eY - 0.75, (s > 0) and 23 or -20.95, WHITE, M.wood)
		blk(rf, "Gutter", -28.2, eY - 1.2, 23 * s + ((s > 0) and 0.15 or -0.85), 28.2, eY - 0.5, 23 * s + ((s > 0) and 0.85 or -0.15), "#e6e2d8", M.metal)
		for _, gx in ipairs({ -27.6, 27.6 }) do
			fvc(rf, "Downspout", CF(gx, 0.2, 23 * s + 0.5 * s), 0, 0, 0, eY - 1.2, 0.5, "#e6e2d8", M.metal)
		end
		for _, rx in ipairs({ -28.1, 28.1 }) do
			slope(rf, "Rake", Vector3.new(rx, eY + 0.1, 23 * s), Vector3.new(rx, RIDGE + 0.1, 0), 0.35, 1.2, WHITE, M.wood)
		end
	end
	blk(rf, "RidgeCap", -28.2, RIDGE - 0.1, -0.8, 28.2, RIDGE + 0.45, 0.8, "#3a3430", M.shingles)
	-- крыша гаража: конёк вдоль Z (фронтон к улице)
	local gr = GRIDGE - 13.6
	for _, sz in ipairs({ -20, 20 }) do
		B.wedge(rf, "Gable", Vector3.new(EXT, gr, 12.75), CF(-44.375, 13.6 + gr / 2, sz, 90), core, M.plaster)
		B.wedge(rf, "Gable", Vector3.new(EXT, gr, 12.75), CF(-31.625, 13.6 + gr / 2, sz, -90), core, M.plaster)
		local zs = sz + ((sz > 0) and 0.85 or -0.85)
		local tilt = math.rad(3) * ((sz > 0) and 1 or -1)
		local y = 13.6
		while y < GRIDGE - 1 do
			local hw = (GRIDGE - (y + 1)) / PITCH
			local xa, xb = -38 - hw, math.min(-38 + hw, -26.95)
			B.part(S.f.Siding, "Siding", Vector3.new(xb - xa, 1.06, 0.2), CF((xa + xb) / 2, y + 0.5, zs) * CFrame.Angles(-tilt, 0, 0), vary(S.siding, 0.035), M.wood)
			y = y + 1
		end
	end
	local gwY = 13.6 - 1.75 * PITCH
	roofPlane(Vector3.new(-52.5, gwY, 0), Vector3.new(-38, GRIDGE, 0), 44, 7)
	roofPlane(Vector3.new(-26.95, GRIDGE - 11.05 * PITCH, 0), Vector3.new(-38, GRIDGE, 0), 44, 6)
	blk(rf, "RidgeCap", -38.8, GRIDGE - 0.1, -22.2, -37.2, GRIDGE + 0.45, 22.2, "#3a3430", M.shingles)
	blk(rf, "Fascia", -52.65, gwY - 1.1, -22, -52.35, gwY - 0.1, 22, WHITE, M.wood)
	blk(rf, "Soffit", -52.5, gwY - 0.95, -22, -50.95, gwY - 0.75, 22, WHITE, M.wood)
	blk(rf, "Gutter", -53.35, gwY - 1.2, -22.2, -52.65, gwY - 0.5, 22.2, "#e6e2d8", M.metal)
	fvc(rf, "Downspout", CF(-53, 0.2, -21.5), 0, 0, 0, gwY - 1.2, 0.5, "#e6e2d8", M.metal)
	fvc(rf, "Downspout", CF(-53, 0.2, 21.5), 0, 0, 0, gwY - 1.2, 0.5, "#e6e2d8", M.metal)
	for _, rz in ipairs({ -22.1, 22.1 }) do
		slope(rf, "Rake", Vector3.new(-52.5, gwY + 0.1, rz), Vector3.new(-38, GRIDGE + 0.1, rz), 0.35, 1.2, WHITE, M.wood)
		slope(rf, "Rake", Vector3.new(-26.95, GRIDGE - 11.05 * PITCH + 0.1, rz), Vector3.new(-38, GRIDGE + 0.1, rz), 0.35, 1.2, WHITE, M.wood)
	end
end

-- ===== лестница: видимые ступени без коллизии + невидимый клин-пандус =====
function A.stairs()
	local st = S.f.Stairs
	local x0, x1, zb, zt, n = -6.5, -0.5, -8, 10, 13
	local run = (zt - zb) / n
	B.wedge(st, "Ramp", Vector3.new(x1 - x0, F2 - F1, zt - zb), CF((x0 + x1) / 2, (F1 + F2) / 2, (zb + zt) / 2), "#7a5232", M.wood,
		{ Transparency = 1, CastShadow = false })
	for i = 0, n - 1 do
		local top, z0 = F1 + i + 1, zb + i * run
		blk(st, "Riser", x0, top - 1, z0, x1, top - 0.14, z0 + run, "#efe9dc", M.wood, NC)
		blk(st, "Tread", x0, top - 0.14, z0 - 0.18, x1 + 0.12, top, z0 + run, vary("#7a5232", 0.06), M.wood, NC)
		blk(st, "Runner", x0 + 1.3, top, z0 - 0.18, x1 - 1.3, top + 0.04, z0 + run, "#6a2a2a", M.carpet, NCS)
		fvc(st, "Baluster", CF(-0.8, top, z0 + run / 2), 0, 0, 0, 3.3, 0.22, WHITE, M.wood, NCS)
	end
	B.wedge(st, "StairSide", Vector3.new(0.2, F2 - F1 - 0.6, zt - zb - 0.8), CF(-0.4, (F1 + F2) / 2 - 0.3, (zb + zt) / 2 + 0.4), "#e6dccb", M.plaster, NC)
	beam(st, "Stringer", V(-0.35, F1 + 0.15, zb), V(-0.35, F2 + 0.15, zt), 0.45, WHITE, M.wood, NC)
	beam(st, "Handrail", V(-0.8, F1 + 3.4, zb + 0.3), V(-0.8, F2 + 3.4, zt), 0.32, "#5a3a22", M.wood, NC)
	blk(st, "Newel", -1.3, F1, -8.9, -0.3, F1 + 4.2, -7.9, "#5a3a22", M.wood)
	blk(st, "NewelCap", -1.45, F1 + 4.2, -9.05, -0.15, F1 + 4.5, -7.75, "#5a3a22", M.wood, NC)
	-- невидимые ограждения (сбоку от лестницы и вокруг проёма наверху)
	blk(st, "Guard", -0.95, F1, -2, -0.6, F2 + 3.5, 10, nil, nil, { Transparency = 1, CastShadow = false })
	blk(st, "Guard", -6.5, F2, -2.2, -0.6, F2 + 3.5, -1.85, nil, nil, { Transparency = 1, CastShadow = false })
	-- перила на 2 этаже
	beam(st, "Handrail", V(-0.75, F2 + 3.4, -2), V(-0.75, F2 + 3.4, 10), 0.32, "#5a3a22", M.wood, NC)
	beam(st, "Handrail", V(-6.5, F2 + 3.4, -2), V(-0.75, F2 + 3.4, -2), 0.32, "#5a3a22", M.wood, NC)
	for z = -1.2, 9.6, 0.9 do fvc(st, "Baluster", CF(-0.75, F2, z), 0, 0, 0, 3.3, 0.2, WHITE, M.wood, NCS) end
	for x = -6, -1.2, 0.9 do fvc(st, "Baluster", CF(x, F2, -2), 0, 0, 0, 3.3, 0.2, WHITE, M.wood, NCS) end
	blk(st, "Newel", -1.2, F2, -2.45, -0.3, F2 + 4, -1.55, "#5a3a22", M.wood)
	blk(st, "Fascia", -6.5, C1 - 0.2, -2.15, -0.5, F2, -1.95, WHITE, M.wood, NC)
end

-- ===== ЭЛТ-телевизор (Model "TV", Part "Screen", ScreenFace) =====
function A.tv()
	local m = B.model(S.model, "TV")
	B.attrs(m, { Kind = "TV", ScreenFace = "Front" })
	local f = CF(24, F1, -10, 90) -- смотрит на −X, на диван
	local wood, plastic = "#4a3424", "#2b2926"
	fb(m, "Stand", f, 0, 0, 0.1, 5.8, 2.4, 2.4, wood, M.wood)
	fb(m, "StandShelf", f, 0, 0.9, -0.2, 5.4, 0.12, 1.9, vary(wood, 0.15), M.wood, NC)
	fb(m, "VCR", f, -1.2, 1.05, -0.4, 3, 0.55, 1.6, "#1c1c1c", M.plastic, NC)
	fb(m, "VCRDisplay", f, -0.4, 1.3, -1.21, 0.8, 0.15, 0.02, "#5aff8a", M.neon, NCS)
	fb(m, "Body", f, 0, 2.4, 0.15, 4.8, 3.9, 3.0, plastic, M.plastic)
	fb(m, "BackShell", f, 0, 2.7, 2.0, 3.6, 3.1, 1.2, plastic, M.plastic)
	fb(m, "Bezel", f, -0.35, 2.75, -1.37, 4.0, 3.2, 0.06, "#1a1918", M.plastic, NC)
	local scr = fb(m, "Screen", f, -0.35, 2.85, -1.42, 3.6, 2.7, 0.08, "#0f1a17", M.glass, { Reflectance = 0.08 })
	S.tvScreen = scr
	for k = 0, 2 do fcz(m, "Knob", f, 1.95, 5.3 - k * 0.7, -1.42, 0.12, 0.42, "#8a8a86", M.metal, NC) end
	fb(m, "Speaker", f, 1.95, 2.85, -1.4, 0.6, 1.0, 0.04, "#151515", M.fabric, NC)
	fb(m, "PowerLed", f, 1.95, 2.55, -1.42, 0.12, 0.12, 0.03, "#ff3a2a", M.neon, NCS)
	B.part(m, "Antenna", Vector3.new(0.08, 3.2, 0.08), f * CFrame.new(-0.6, 7.6, 1.2) * CFrame.Angles(0, 0, math.rad(25)), "#c8c8c8", M.metal, NCS)
	B.part(m, "Antenna", Vector3.new(0.08, 3.2, 0.08), f * CFrame.new(0.6, 7.6, 1.2) * CFrame.Angles(0, 0, math.rad(-25)), "#c8c8c8", M.metal, NCS)
	fball(m, "AntennaBase", f, 0, 6.45, 1.2, 0.6, "#1c1c1c", M.plastic, NC)
	S.tv = m
end

-- ===== лавка в гараже (Model "Shop") с продавцом =====
function A.shop()
	local m = B.model(S.model, "Shop")
	B.attrs(m, { Kind = "Shop" })
	local f = CF(-40, F1, -5, 180) -- LookVector → +Z (к покупателям); продавец за прилавком
	local wood = "#7a5a3a"
	local counter = fb(m, "Counter", f, 0, 0, 0, 10, 3.6, 2.4, wood, M.wood)
	for k = -2, 2 do fb(m, "CounterBoard", f, k * 2, 0.2, -1.22, 1.85, 3.2, 0.06, vary(wood, 0.12), M.wood, NCS) end
	local top = fb(m, "CounterTop", f, 0, 3.6, 0, 10.4, 0.25, 2.8, "#a8865a", M.wood)
	-- касса
	fb(m, "Register", f, 2.6, 3.85, 0.3, 1.8, 0.9, 1.5, "#d8d2c0", M.plastic)
	B.part(m, "RegisterKeys", Vector3.new(1.6, 0.1, 0.8), f * CFrame.new(2.6, 4.8, -0.1) * CFrame.Angles(math.rad(-20), 0, 0), "#3a3a3a", M.plastic, NC)
	fb(m, "RegisterDisplay", f, 2.6, 4.75, 0.75, 1.2, 0.5, 0.25, "#1a1a1a", M.plastic, NC)
	fb(m, "RegisterDigits", f, 2.6, 4.85, 0.6, 0.9, 0.25, 0.04, "#7aff6a", M.neon, NCS)
	-- ящик с яблоками на прилавке
	fb(m, "Crate", f, -2.8, 3.85, 0, 2.2, 1.0, 1.6, "#b08a5a", M.wood)
	for i = 0, 5 do
		fball(m, "Apple", f, -3.5 + (i % 3) * 0.7, 4.95, -0.35 + math.floor(i / 3) * 0.7, 0.62, vary("#c01e1e", 0.12), M.plastic, NCS)
	end
	fb(m, "PriceCard", f, -1.2, 3.85, -0.6, 1, 0.7, 0.05, "#f4ecd8", M.plastic, NC)
	-- вывеска
	local sign = fb(m, "Sign", f, 0, 9.0, 0.5, 8, 1.8, 0.25, "#3a1a0a", M.wood, NC)
	B.sign(sign, Enum.NormalId.Back, "ЯБЛОКИ  •  ЛАВКА", { TextColor3 = Color3.fromRGB(255, 208, 106) })
	B.sign(sign, Enum.NormalId.Front, "ЯБЛОКИ  •  ЛАВКА", { TextColor3 = Color3.fromRGB(255, 208, 106) })
	for _, sx in ipairs({ -3.5, 3.5 }) do fvc(m, "Chain", f, sx, 10.8, 0.5, 1.2, 0.1, "#8a8a8a", M.metal, NCS) end
	-- продавец яблок: статичная фигура в одежде 90-х (кепка, фланелевая рубашка, джинсы)
	local v = B.model(m, "Vendor")
	local skin, jeans, shirt = "#e0b48c", "#3a5a8a", "#a8322a"
	local p = f * CFrame.new(0, 0, 3.0)
	local function vb(name, x, y, z, sx, sy, sz, c, mat) return fb(v, name, p, x, y, z, sx, sy, sz, c, mat or M.fabric) end
	vb("Shoe", -0.5, 0, -0.15, 0.85, 0.45, 1.3, "#2a2420", M.leather)
	vb("Shoe", 0.5, 0, -0.15, 0.85, 0.45, 1.3, "#2a2420", M.leather)
	vb("Leg", -0.5, 0.45, 0, 0.9, 2.7, 0.95, jeans)
	vb("Leg", 0.5, 0.45, 0, 0.9, 2.7, 0.95, jeans)
	vb("Belt", 0, 3.1, 0, 2.05, 0.25, 1.05, "#2a1a10", M.leather)
	vb("Torso", 0, 3.3, 0, 2.1, 2.3, 1.05, shirt)
	for k = 0, 2 do vb("Plaid", 0, 3.6 + k * 0.7, -0.53, 2.12, 0.12, 0.02, "#2a1a1a") end
	vb("Apron", 0, 2.3, -0.56, 1.6, 2.7, 0.06, "#e8dcc0")
	B.part(v, "Arm", Vector3.new(0.75, 2.4, 0.8), p * CFrame.new(-1.45, 4.3, -0.5) * CFrame.Angles(math.rad(35), 0, 0), shirt, M.fabric)
	B.part(v, "Arm", Vector3.new(0.75, 2.4, 0.8), p * CFrame.new(1.45, 4.3, -0.5) * CFrame.Angles(math.rad(35), 0, 0), shirt, M.fabric)
	vb("Hand", -1.45, 3.35, -1.35, 0.6, 0.5, 0.7, skin, M.plastic)
	vb("Hand", 1.45, 3.35, -1.35, 0.6, 0.5, 0.7, skin, M.plastic)
	vb("Neck", 0, 5.6, 0, 0.55, 0.3, 0.55, skin, M.plastic)
	local head = vb("Head", 0, 5.85, 0, 1.25, 1.3, 1.2, skin, M.plastic)
	vb("Eye", -0.27, 6.55, -0.61, 0.16, 0.16, 0.04, "#1a1a1a", M.plastic)
	vb("Eye", 0.27, 6.55, -0.61, 0.16, 0.16, 0.04, "#1a1a1a", M.plastic)
	vb("Mustache", 0, 6.15, -0.61, 0.7, 0.14, 0.05, "#4a2e1a")
	vb("Cap", 0, 7.1, 0.05, 1.35, 0.42, 1.3, "#c4281c")
	vb("CapBill", 0, 7.1, -0.9, 1.1, 0.12, 0.8, "#c4281c")
	B.prompt(top, "Prompt", "Магазин", "Продавец яблок", { HoldDuration = 0, MaxActivationDistance = 9 })
	top.Prompt:SetAttribute("Opens", "Shop")
	S.shop = m
	S.shopTop = counter
	return head
end

-- ===== щиток (Model "FuseBox") на восточной стене гаража =====
function A.fuse()
	local m = B.model(S.model, "FuseBox")
	B.attrs(m, { Kind = "Fuse" })
	local f = CF(-26.75, F1, 11.5, 90) -- лицом в гараж (−X)
	local box = fb(m, "Box", f, 0, 4.2, -0.45, 2.4, 3.2, 0.9, "#7a7c80", M.metal)
	fb(m, "Door", f, 0, 4.35, -0.93, 2.1, 2.9, 0.06, "#8a8c90", M.metal, NC)
	fb(m, "Lever", f, 0.7, 5.4, -1.15, 0.3, 1.1, 0.35, "#c4281c", M.plastic)
	fball(m, "Lamp", f, -0.6, 6.85, -0.98, 0.32, "#36ff4a", M.neon, NCS)
	fb(m, "Label", f, -0.3, 6.2, -0.97, 0.9, 0.35, 0.02, "#f4ecd8", M.plastic, NCS)
	fb(m, "Conduit", f, 0, 7.4, -0.3, 0.3, 4.6, 0.3, "#9a9a9a", M.metal, NCS)
	B.prompt(box, "Prompt", "Щиток", "Электричество", { HoldDuration = 0.6, MaxActivationDistance = 8 })
	S.fuse = m
end

-- ===== яблоня (Model "Tree_n": Plant, Apples, Plot, Prompt) =====
local function appleTree(n, x, z, planted)
	local m = B.model(S.f.Trees, "Tree_" .. n)
	B.attrs(m, { Kind = "Tree", Slot = n, Planted = planted, Apples = 0 })
	local f = CF(x, 0, z, n * 47)
	local plot = fvc(m, "Plot", f, 0, -0.05, 0, 0.35, 9, "#4a3222", M.ground)
	for i = 0, 5 do
		local a = i * math.pi / 3
		fb(m, "Edging", f, math.cos(a) * 4.6, 0, math.sin(a) * 4.6, 1.4, 0.4, 0.6, "#8a8478", M.slate, NC)
	end
	B.prompt(plot, "Prompt", "Сорвать яблоко", "Яблоня", { HoldDuration = 0.4, MaxActivationDistance = 9 })
	local plant = B.model(m, "Plant")
	fvc(plant, "Trunk", f, 0, 0.2, 0, 7.5, 1.4, "#5a3e2a", M.wood)
	B.part(plant, "Branch", Vector3.new(0.6, 4, 0.6), f * CFrame.new(0.9, 7.2, 0) * CFrame.Angles(0, 0, math.rad(-35)), "#5a3e2a", M.wood, NC)
	B.part(plant, "Branch", Vector3.new(0.6, 4, 0.6), f * CFrame.new(-0.8, 7.0, 0.4) * CFrame.Angles(math.rad(20), 0, math.rad(35)), "#5a3e2a", M.wood, NC)
	local leaf = "#2f5a26"
	fball(plant, "Canopy", f, 0, 10.5, 0, 8, vary(leaf, 0.1), M.grass, NC)
	fball(plant, "Canopy", f, 2.3, 9.4, 1.0, 5.6, vary(leaf, 0.12), M.grass, NC)
	fball(plant, "Canopy", f, -2.2, 9.6, -1.1, 5.8, vary(leaf, 0.12), M.grass, NC)
	fball(plant, "Canopy", f, 0.4, 12.6, -0.5, 5.2, vary(leaf, 0.1), M.grass, NC)
	local apples = B.folder(m, "Apples")
	for i = 1, 4 do
		local a = i * 1.6
		fball(apples, "Apple" .. i, f, math.cos(a) * 3.6, 8.4 + (i % 2) * 1.2, math.sin(a) * 3.6, 0.75, vary("#c81e1e", 0.1), M.plastic, NCS)
	end
	table.insert(S.trees, m)
	return m
end
