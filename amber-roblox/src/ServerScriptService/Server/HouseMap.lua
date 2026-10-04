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
	local pr = B.prompt(top, "Prompt", "Магазин", "Продавец яблок", { HoldDuration = 0, MaxActivationDistance = 9 })
	pr:SetAttribute("Opens", "Shop")
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

-- ===== мебель: помощники (локальная −Z у рамки f — «перед» предмета) =====
local BOOKS = { "#7a2a22", "#2a4a6a", "#3a5a2a", "#8a6a2a", "#4a2a4a", "#c8b48a", "#1e1e22", "#6a3a1a" }
local function sofa(par, f, len, c)
	fb(par, "SofaBase", f, 0, 0, 0, len, 1.7, 3.4, vary(c, 0.04), M.fabric)
	local n = 3
	local cw = (len - 1.6) / n
	for i = 0, n - 1 do
		fb(par, "Cushion", f, -len / 2 + 0.8 + cw * (i + 0.5), 1.7, -0.2, cw - 0.1, 0.55, 2.6, vary(c, 0.07), M.fabric, NC)
	end
	fb(par, "SofaBack", f, 0, 1.7, 1.25, len - 1.6, 2.2, 0.9, vary(c, 0.05), M.fabric)
	for _, s in ipairs({ -1, 1 }) do fb(par, "SofaArm", f, s * (len / 2 - 0.4), 0, 0, 0.8, 2.6, 3.4, vary(c, 0.05), M.fabric) end
	fb(par, "Pillow", f, -len / 2 + 1.5, 2.25, 0.5, 1.3, 1.3, 0.45, "#d8c49a", M.fabric, NC)
	fb(par, "Pillow", f, len / 2 - 1.5, 2.25, 0.5, 1.3, 1.3, 0.45, "#c9a46a", M.fabric, NC)
end
local function armchair(par, f, c)
	fb(par, "ChairBase", f, 0, 0, 0, 3.0, 1.7, 3.0, c, M.fabric)
	fb(par, "Cushion", f, 0, 1.7, -0.2, 1.8, 0.5, 2.3, vary(c, 0.07), M.fabric, NC)
	fb(par, "ChairBack", f, 0, 1.7, 1.1, 2.2, 2.4, 0.8, vary(c, 0.05), M.fabric)
	for _, s in ipairs({ -1, 1 }) do fb(par, "ChairArm", f, s * 1.2, 0, 0, 0.6, 2.6, 3.0, vary(c, 0.05), M.fabric) end
end
local function tableF(par, f, sx, sz, h, c, mat)
	local top = fb(par, "TableTop", f, 0, h - 0.25, 0, sx, 0.25, sz, c, mat or M.wood)
	for _, a in ipairs({ -1, 1 }) do
		for _, b in ipairs({ -1, 1 }) do
			fb(par, "Leg", f, a * (sx / 2 - 0.3), 0, b * (sz / 2 - 0.3), 0.3, h - 0.25, 0.3, vary(c, 0.08), mat or M.wood, NC)
		end
	end
	fb(par, "Collider", f, 0, 0, 0, sx - 0.4, h - 0.3, sz - 0.4, nil, nil, { Transparency = 1, CastShadow = false })
	return top
end
local function chair(par, f, c)
	fb(par, "Seat", f, 0, 1.85, 0, 1.8, 0.25, 1.8, c, M.wood)
	fb(par, "ChairLegs", f, 0, 0, -0.65, 1.6, 1.85, 0.22, vary(c, 0.1), M.wood)
	fb(par, "ChairLegs", f, 0, 0, 0.65, 1.6, 1.85, 0.22, vary(c, 0.1), M.wood)
	fb(par, "ChairBack", f, 0, 2.1, 0.8, 1.8, 2.3, 0.22, vary(c, 0.06), M.wood, NC)
end
local function bed(par, f, w, len, blanket, frame)
	fb(par, "Frame", f, 0, 0, 0, w, 1.8, len, frame, M.wood)
	fb(par, "Mattress", f, 0, 1.8, 0.1, w - 0.3, 1.0, len - 0.5, "#efe8dc", M.fabric)
	fb(par, "Blanket", f, 0, 2.55, -len * 0.17, w + 0.1, 0.35, len * 0.62, vary(blanket, 0.03), M.fabric, NC)
	fb(par, "BlanketFold", f, 0, 2.6, len * 0.15, w + 0.1, 0.4, 0.8, vary(blanket, 0.12), M.fabric, NC)
	local np = (w > 5) and 2 or 1
	for i = 1, np do
		local px = (np == 1) and 0 or ((i == 1) and -w / 4 or w / 4)
		fb(par, "Pillow", f, px, 2.8, len / 2 - 1.1, math.min(w * 0.42, 2.4), 0.6, 1.3, "#f4f0e6", M.fabric, NC)
	end
	fb(par, "Headboard", f, 0, 0, len / 2 + 0.15, w + 0.4, 4.6, 0.35, frame, M.wood)
	fb(par, "Footboard", f, 0, 0, -len / 2 - 0.1, w + 0.4, 2.4, 0.3, frame, M.wood)
end
local function bookcase(par, f, w, h, d, c)
	fb(par, "CaseBack", f, 0, 0, d / 2 - 0.08, w, h, 0.16, vary(c, 0.1), M.wood)
	fb(par, "CaseSide", f, -w / 2 + 0.12, 0, 0, 0.24, h, d, c, M.wood)
	fb(par, "CaseSide", f, w / 2 - 0.12, 0, 0, 0.24, h, d, c, M.wood)
	fb(par, "CaseTop", f, 0, h - 0.2, 0, w, 0.2, d, c, M.wood)
	fb(par, "CaseBase", f, 0, 0, 0, w, 0.4, d, c, M.wood)
	local shelves = math.floor(h / 1.9)
	for s = 0, shelves - 1 do
		local y = 0.4 + s * 1.85
		if s > 0 then fb(par, "Shelf", f, 0, y - 0.15, 0, w - 0.4, 0.15, d - 0.2, c, M.wood, NC) end
		local x = -w / 2 + 0.35
		while x < w / 2 - 0.8 do
			local bw, bh = rnd(0.22, 0.42), rnd(1.0, 1.5)
			if rnd(0, 1) < 0.85 then
				fb(par, "Book", f, x + bw / 2, y, 0.05, bw - 0.02, bh, d * 0.7, BOOKS[S.rng:NextInteger(1, #BOOKS)], M.plastic, NCS)
			end
			x = x + bw
		end
	end
end
-- картина/плакат на стене: cf смотрит в комнату
local function picture(par, cf, w, h, key, canvas, frameCol)
	B.part(par, "PictureFrame", Vector3.new(w, h, 0.14), cf, frameCol or "#5a3a22", M.wood, NCS)
	local c = B.part(par, "Picture", Vector3.new(w - 0.4, h - 0.4, 0.04), cf * CFrame.new(0, 0, -0.08), canvas or "#8aa0a8", M.plastic, NCS)
	if key then B.decal(c, Enum.NormalId.Front, img(key)) end
	return c
end
local function wallClock(par, cf)
	B.cyl(par, "Clock", 0.18, 1.6, cf * CFrame.Angles(0, math.rad(90), 0), "#f4ecd8", M.plastic, NCS)
	B.cyl(par, "ClockRim", 0.14, 1.8, cf * CFrame.new(0, 0, 0.04) * CFrame.Angles(0, math.rad(90), 0), "#3a2a1a", M.wood, NCS)
	B.part(par, "ClockHand", Vector3.new(0.08, 0.55, 0.03), cf * CFrame.new(0, 0.22, -0.11), "#1a1a1a", M.plastic, NCS)
	B.part(par, "ClockHand", Vector3.new(0.6, 0.08, 0.03), cf * CFrame.new(0.25, 0, -0.12), "#1a1a1a", M.plastic, NCS)
end
local function rug(par, x0, z0, x1, z1, y, c, border)
	blk(par, "Rug", x0, y, z0, x1, y + 0.06, z1, border or vary(c, 0.2), M.carpet, NCS)
	blk(par, "Rug", x0 + 0.6, y + 0.01, z0 + 0.6, x1 - 0.6, y + 0.07, z1 - 0.6, c, M.carpet, NCS)
end
local function plant(par, x, y, z)
	local f = CF(x, y, z)
	fvc(par, "Pot", f, 0, 0, 0, 1.4, 1.5, "#9a5a32", M.concrete)
	for i = 0, 5 do
		B.part(par, "Leaf", Vector3.new(0.5, 2.4, 0.12), f * CFrame.Angles(0, i * 1.05, 0) * CFrame.new(0, 2.4, 0.35) * CFrame.Angles(math.rad(-25), 0, 0),
			vary("#2f6a2a", 0.15), M.grass, NCS)
	end
end
-- шкафчики со столешницей вдоль стены: front — направление лицевой стороны (Vector3)
local function counterRun(par, x0, z0, x1, z1, front, top)
	blk(par, "Cabinet", x0, F1, z0, x1, F1 + 3.0, z1, "#8a6a42", M.wood)
	local len = (front.X ~= 0) and (z1 - z0) or (x1 - x0)
	local n = math.max(1, math.floor(len / 2))
	for i = 0, n - 1 do
		local a = i * len / n + len / (2 * n)
		local cx, cz = x0 + a, (front.Z > 0) and z1 + 0.04 or z0 - 0.04
		local size = Vector3.new(len / n - 0.2, 2.2, 0.1)
		if front.X ~= 0 then
			cx, cz = (front.X > 0) and x1 + 0.04 or x0 - 0.04, z0 + a
			size = Vector3.new(0.1, 2.2, len / n - 0.2)
		end
		B.part(par, "CabinetDoor", size, CF(cx, F1 + 1.55, cz), "#9a7a4e", M.wood, NCS)
		B.part(par, "Handle", Vector3.new(0.2, 0.2, 0.2), CF(cx + front.X * 0.08, F1 + 2.4, cz + front.Z * 0.08), "#c9a24a", M.metal, NCS)
	end
	local o = 0.15
	blk(par, "Countertop", x0 - ((front.X < 0) and o or 0), F1 + 3.0, z0 - ((front.Z < 0) and o or 0),
		x1 + ((front.X > 0) and o or 0), F1 + 3.25, z1 + ((front.Z > 0) and o or 0), top or "#d8cfb8", M.plastic)
end

-- ===== 1 этаж =====
function A.hall()
	local fu = S.f.Furniture
	finishRoom({ name = "Hall", x0 = -6.5, z0 = -19.25, x1 = 6.5, z1 = 19.25, y = F1, floor = "planksZ", fc = "#8a5a36",
		wall = "#bfae8e", tex = "WallpaperLiving", noCeil = true })
	blk(S.f.Interior, "Ceiling", -0.5, C1 - 0.2, -19.25, 6.5, C1, 19.25, "#e8e2d4", M.plaster)
	blk(S.f.Interior, "Ceiling", -6.5, C1 - 0.2, -19.25, -0.5, C1, -2, "#e8e2d4", M.plaster)
	blk(S.f.Interior, "Ceiling", -6.5, C1 - 0.2, 10, -0.5, C1, 19.25, "#e8e2d4", M.plaster)
	hideSpot({ name = "Hide_Hall_1", room = "Hall", kind = "Closet", x = -4, z = -17.45, y = F1, yaw = 180, w = 5, d = 3.6, label = "Шкаф для курток", clothes = "#4a3a2a" })
	-- консоль с телефоном и зеркалом
	local f = CF(5.85, F1, -11.25, 90)
	tableF(fu, f, 3.6, 1.3, 3.1, "#6a4a2e")
	fb(fu, "Phone", f, -0.6, 3.1, 0, 0.9, 0.35, 0.7, "#d8d0bc", M.plastic, NC)
	fb(fu, "Handset", f, -0.6, 3.45, 0, 0.9, 0.18, 0.25, "#d8d0bc", M.plastic, NCS)
	fb(fu, "Bowl", f, 0.9, 3.1, 0, 0.8, 0.2, 0.8, "#b08a4a", M.metal, NCS)
	B.part(fu, "Mirror", Vector3.new(0.1, 3, 2.4), CF(6.42, F1 + 6.2, -11.25), "#b8c8d0", M.glass, { CanCollide = false, Reflectance = 0.35 })
	B.part(fu, "MirrorFrame", Vector3.new(0.08, 3.4, 2.8), CF(6.46, F1 + 6.2, -11.25), "#8a6a3a", M.wood, NCS)
	-- напольные часы, коврики, подставка для зонтов
	local g = CF(5.6, F1, 17.8, 90)
	fb(fu, "ClockCase", g, 0, 0, 0, 1.6, 7.6, 1.2, "#4a2e1a", M.wood)
	fcz(fu, "ClockFace", g, 0, 6.5, -0.62, 0.05, 1.1, "#f4ecd8", M.plastic, NCS)
	fb(fu, "Pendulum", g, 0, 2.2, -0.62, 0.5, 2.6, 0.04, "#c9a24a", M.metal, NCS)
	rug(fu, 0.6, -16, 5.4, 8, F1, "#6a2a2a")
	rug(fu, 1, -19.1, 5, -17.4, F1, "#4a3a2a")
	fvc(fu, "Umbrellas", CF(-0.6, F1, -18.5), 0, 0, 0, 2.4, 0.9, "#2a3a2a", M.metal, NC)
	picture(fu, CF(-6.42, F1 + 7, -3, -90), 2.4, 3, "FamilyPhoto", "#a89070")
	picture(fu, CF(6.42, F1 + 7, 4, 90), 3, 2.2, nil, "#6a7a5a")
	ceilingLight("Hall", 3, -13, C1, "dome")
	ceilingLight("Hall", 2.5, 14.5, C1, "dome")
end

function A.living()
	local fu = S.f.Furniture
	finishRoom({ name = "LivingRoom", x0 = 7.5, z0 = -19.25, x1 = 25.25, z1 = 1.5, y = F1, floor = "planksX", fc = "#7a5234",
		wall = "#b9b08a", tex = "WallpaperLiving" })
	sofa(fu, CF(10.8, F1, -10, -90), 7, "#6a4a3a")
	armchair(fu, CF(22.6, F1, -3.8, 42), "#5a5a3a")
	local ct = CF(16.1, F1, -10, 90)
	tableF(fu, ct, 4, 2.6, 1.7, "#5a3a22")
	fb(fu, "Magazine", ct, -0.8, 1.7, 0.2, 1.0, 0.06, 1.3, "#c84a3a", M.plastic, NCS)
	fb(fu, "Remote", ct, 0.7, 1.7, -0.3, 0.3, 0.12, 0.9, "#1a1a1a", M.plastic, NCS)
	fvc(fu, "Mug", ct, 0.9, 1.7, 0.6, 0.45, 0.4, "#e8e2d4", M.plastic, NCS)
	rug(fu, 13, -15, 20.5, -5, F1, "#6a2a2a")
	-- приставной столик с телефоном и лампой
	local st = CF(10.5, F1, -14.6, -90)
	tableF(fu, st, 1.8, 1.8, 2.4, "#5a3a22")
	fb(fu, "Phone", st, 0.3, 2.4, -0.3, 0.8, 0.35, 0.65, "#7a1a1a", M.plastic, NC)
	tableLamp("LivingRoom", 10.3, F1 + 2.4, -14.1)
	floorLamp("LivingRoom", 24.3, F1, -14.2)
	bookcase(fu, CF(8.2, F1, -17.1, -90), 3.8, 7.6, 1.4, "#6a4a2e")
	plant(fu, 24.2, F1, -18.3)
	plant(fu, 8.6, F1, 0.4)
	picture(fu, CF(7.62, F1 + 7, -12.4, -90), 2.6, 2.0, "FamilyPhoto", "#a89070", "#8a6a3a")
	picture(fu, CF(7.62, F1 + 7.4, -9.4, -90), 1.8, 2.6, "Poster1", "#5a7a8a", "#8a6a3a")
	picture(fu, CF(7.62, F1 + 6.8, -6.8, -90), 1.6, 1.6, nil, "#8a6a4a", "#8a6a3a")
	wallClock(fu, CF(12, F1 + 8.8, 1.38, 0))
	ceilingLight("LivingRoom", 16.5, -9, C1, "dome")
end

function A.kitchen()
	local fu = S.f.Furniture
	finishRoom({ name = "Kitchen", x0 = 7.5, z0 = 2.5, x1 = 25.25, z1 = 19.25, y = F1, floor = "vinyl", fc = "#d8d0b8", fc2 = "#7a8a6a",
		wall = "#e6dcb8", tex = nil })
	counterRun(fu, 16.5, 16.65, 25.25, 19.25, Vector3.new(0, 0, -1))
	counterRun(fu, 22.65, 11, 25.25, 16.65, Vector3.new(-1, 0, 0))
	counterRun(fu, 22.65, 6.9, 25.25, 8, Vector3.new(-1, 0, 0))
	blk(fu, "Backsplash", 16.5, F1 + 3.25, 19.05, 25.25, F1 + 5.2, 19.25, "#c8d8c8", M.tiles, NCS)
	-- мойка и смеситель под окном
	blk(fu, "Sink", 20.1, F1 + 3.0, 17.2, 22.9, F1 + 3.3, 18.7, "#a8b0b4", M.metal, NCS)
	blk(fu, "SinkBasin", 20.4, F1 + 3.27, 17.45, 22.6, F1 + 3.31, 18.45, "#5a6064", M.metal, NCS)
	fvc(fu, "Faucet", CF(21.5, F1 + 3.25, 18.85), 0, 0, 0, 1.2, 0.25, "#c8c8c8", M.metal, NCS)
	B.part(fu, "Spout", Vector3.new(0.18, 0.18, 0.9), CF(21.5, F1 + 4.4, 18.45), "#c8c8c8", M.metal, NCS)
	blk(fu, "Dishwasher", 17.4, F1 + 0.4, 16.55, 19.6, F1 + 2.9, 16.62, "#e8e4dc", M.plastic, NCS)
	-- плита с духовкой и вытяжкой
	local sv = CF(23.95, F1, 9.5, 90)
	fb(fu, "Stove", sv, 0, 0, 0, 3, 3.2, 2.6, "#ece8de", M.plastic)
	fb(fu, "OvenDoor", sv, 0, 0.5, -1.31, 2.5, 2.0, 0.06, "#1e1e1e", M.glass, NCS)
	fb(fu, "OvenHandle", sv, 0, 2.6, -1.42, 2.2, 0.15, 0.15, "#c8c8c8", M.metal, NCS)
	for _, b in ipairs({ { -0.7, -0.6 }, { 0.7, -0.6 }, { -0.7, 0.5 }, { 0.7, 0.5 } }) do
		fvc(fu, "Burner", sv, b[1], 3.2, b[2], 0.06, 0.9, "#1a1a1a", M.metal, NCS)
	end
	fb(fu, "StovePanel", sv, 0, 3.2, 1.15, 3, 0.9, 0.3, "#ece8de", M.plastic, NC)
	fb(fu, "Hood", sv, 0, 8.6, 0.35, 3.2, 1.0, 1.9, "#d8d0bc", M.metal, NC)
	fb(fu, "Kettle", sv, 0.7, 3.26, -0.6, 0.7, 0.7, 0.7, "#c8322a", M.metal, NCS)
	-- холодильник
	local fr = CF(23.8, F1, 4.85, 90)
	fb(fu, "Fridge", fr, 0, 0, 0, 3.8, 6.6, 2.9, "#e8e2cc", M.plastic)
	fb(fu, "FridgeSeam", fr, 0, 4.4, -1.46, 3.7, 0.08, 0.04, "#8a8478", M.plastic, NCS)
	fb(fu, "FridgeHandle", fr, 1.5, 2.6, -1.55, 0.2, 1.5, 0.2, "#c8c8c8", M.metal, NCS)
	fb(fu, "FridgeHandle", fr, 1.5, 4.8, -1.55, 0.2, 1.1, 0.2, "#c8c8c8", M.metal, NCS)
	for i = 0, 2 do fb(fu, "Magnet", fr, -0.9 + i * 0.6, 5.2 - i * 0.35, -1.47, 0.35, 0.35, 0.05, BOOKS[i + 1], M.plastic, NCS) end
	-- микроволновка, тостер, радио, полотенца
	local mw = CF(23.9, F1 + 3.25, 14.2, 90)
	fb(fu, "Microwave", mw, 0, 0, 0, 2.4, 1.3, 1.6, "#e2dccc", M.plastic)
	fb(fu, "MicrowaveDoor", mw, -0.3, 0.2, -0.81, 1.5, 0.9, 0.04, "#1e1e1e", M.glass, NCS)
	fb(fu, "Toaster", CF(17.6, F1 + 3.25, 18.2), 0, 0, 0, 1.1, 0.8, 0.7, "#c8c8c8", M.metal, NCS)
	fb(fu, "Radio", CF(24.6, F1 + 3.25, 18.4), 0, 0, 0, 1.2, 0.8, 0.6, "#3a2a1a", M.wood, NCS)
	fvc(fu, "PaperTowel", CF(19.6, F1 + 3.25, 18.6), 0, 0, 0, 1.0, 0.45, "#f4f0e6", M.fabric, NCS)
	-- навесные шкафы
	blk(fu, "UpperCabinet", 16.5, F1 + 7.4, 17.9, 18.8, F1 + 11, 19.25, "#8a6a42", M.wood)
	blk(fu, "UpperCabinet", 24.2, F1 + 7.4, 17.9, 25.25, F1 + 11, 19.25, "#8a6a42", M.wood)
	blk(fu, "UpperCabinet", 23.9, F1 + 7.4, 2.8, 25.25, F1 + 11, 6.9, "#8a6a42", M.wood)
	-- стол со стульями, ваза с фруктами
	local tf = CF(14, F1, 10.5)
	local top = tableF(fu, tf, 5, 3.5, 3.1, "#9a7a52")
	for _, c in ipairs({ { -1.25, -3.1, 180 }, { 1.25, -3.1, 180 }, { -1.25, 3.1, 0 }, { 1.25, 3.1, 0 } }) do
		chair(fu, CF(14 + c[1], F1, 10.5 + c[2], c[3]), "#7a5a3a")
	end
	fvc(fu, "FruitBowl", tf, 0, 3.1, 0, 0.45, 1.6, "#d8c8a8", M.plastic, NCS)
	for i = 0, 3 do
		fball(fu, "Fruit", tf, math.cos(i * 1.6) * 0.4, 3.75, math.sin(i * 1.6) * 0.4, 0.55, ({ "#c81e1e", "#e8c83a", "#7ab83a", "#e8822a" })[i + 1], M.plastic, NCS)
	end
	fvc(fu, "Plate", tf, -1.3, 3.1, -0.9, 0.08, 1.1, "#f4f0e6", M.plastic, NCS)
	fvc(fu, "Plate", tf, 1.3, 3.1, 0.9, 0.08, 1.1, "#f4f0e6", M.plastic, NCS)
	-- кладовая-укрытие
	hideSpot({ name = "Hide_Kitchen_1", room = "Kitchen", kind = "Closet", x = 10, z = 4.3, y = F1, yaw = 180, w = 5, d = 3.6, color = "#e8dfc8", label = "Кладовая", clothes = "#8a6a3a" })
	-- календарь, часы, настенный телефон
	B.part(fu, "Calendar", Vector3.new(0.05, 2.2, 1.6), CF(7.55, F1 + 6, 8.6), "#f4ecd8", M.plastic, NCS)
	B.part(fu, "CalendarPic", Vector3.new(0.06, 0.9, 1.4), CF(7.56, F1 + 6.6, 8.6), "#5a8aa8", M.plastic, NCS)
	wallClock(fu, CF(7.6, F1 + 9.6, 8.6, -90))
	fb(fu, "WallPhone", CF(13.6, F1 + 5, 2.6), 0, 0, 0, 0.8, 1.6, 0.4, "#e8e0c8", M.plastic, NCS)
	ceilingLight("Kitchen", 14, 10.5, C1, "pendant", { Range = 16 })
	ceilingLight("Kitchen", 20.5, 12, C1, "dome")
end

function A.dining()
	local fu = S.f.Furniture
	finishRoom({ name = "Dining", x0 = -25.25, z0 = -19.25, x1 = -7.5, z1 = -0.5, y = F1, floor = "planksX", fc = "#5e3c22",
		wall = "#8a5a52", tex = "WallpaperLiving" })
	local tf = CF(-16.5, F1, -10)
	tableF(fu, tf, 8, 4.6, 3.1, "#4a2e1a")
	local cs = { { -2, -3.3, 180 }, { 2, -3.3, 180 }, { -2, 3.3, 0 }, { 2, 3.3, 0 }, { -5.1, 0, -90 }, { 5.1, 0, 90 } }
	for _, c in ipairs(cs) do
		chair(fu, CF(-16.5 + c[1], F1, -10 + c[2], c[3]), "#5a3a22")
		local px, pz = c[1] * 0.62, c[2] * 0.5
		fvc(fu, "Plate", tf, px, 3.1, pz, 0.08, 1.2, "#f4f0e6", M.plastic, NCS)
	end
	fb(fu, "Runner", tf, 0, 3.1, 0, 6, 0.03, 1.4, "#c8b48a", M.fabric, NCS)
	for _, sx in ipairs({ -1.2, 1.2 }) do
		fvc(fu, "Candlestick", tf, sx, 3.1, 0, 1.0, 0.3, "#c9a24a", M.metal, NCS)
		fvc(fu, "Candle", tf, sx, 4.1, 0, 0.8, 0.22, "#f4ecd8", M.plastic, NCS)
	end
	rug(fu, -22, -14.2, -11, -5.8, F1, "#3a4a6a")
	-- сервант со стеклом
	local cf = CF(-24.4, F1, -10.5, -90)
	fb(fu, "Hutch", cf, 0, 0, 0, 7, 3.4, 1.7, "#4a2e1a", M.wood)
	fb(fu, "HutchTop", cf, 0, 3.4, 0.35, 6.6, 4.4, 1.0, "#4a2e1a", M.wood)
	fb(fu, "HutchGlass", cf, 0, 3.6, -0.17, 6.2, 4.0, 0.06, "#b8c8d0", M.glass, { CanCollide = false, Transparency = 0.5 })
	for i = 0, 4 do fvc(fu, "ChinaPlate", cf, -2.4 + i * 1.2, 5.2, 0.3, 0.9, 0.12, "#f4f0e6", M.plastic, NCS) end
	-- буфет
	local sb = CF(-8.35, F1, -4, 90)
	fb(fu, "Sideboard", sb, 0, 0, 0, 4.6, 3.2, 1.6, "#5a3a22", M.wood)
	fvc(fu, "Vase", sb, 1.4, 3.2, 0, 1.4, 0.7, "#3a5a7a", M.glass, NCS)
	picture(fu, CF(-7.62, F1 + 7, -4, 90), 3.2, 2.2, "Poster2", "#6a5a3a")
	picture(fu, CF(-16.5, F1 + 7.5, -0.62, 0), 4, 2.6, nil, "#4a6a5a")
	ceilingLight("Dining", -16.5, -10, C1, "chandelier", { Range = 18 })
end

function A.laundry()
	local fu = S.f.Furniture
	finishRoom({ name = "Laundry", x0 = -25.25, z0 = 0.5, x1 = -15.5, z1 = 19.25, y = F1, floor = "vinyl", fc = "#cfc8b4", fc2 = "#9a8a6a",
		wall = "#d8d4c4", skip = { e = true } })
	finishRoom({ name = "Laundry", x0 = -15.5, z0 = 9.5, x1 = -7.5, z1 = 19.25, y = F1, floor = "vinyl", fc = "#cfc8b4", fc2 = "#9a8a6a",
		wall = "#d8d4c4", skip = { w = true } })
	for i, c in ipairs({ "#f0eee6", "#e8e6de" }) do
		local f = CF(-23.15 + (i - 1) * 3.6, F1, 17.75)
		fb(fu, (i == 1) and "Washer" or "Dryer", f, 0, 0, 0, 3.4, 3.6, 2.9, c, M.plastic)
		fb(fu, "Controls", f, 0, 3.6, 1.15, 3.4, 0.9, 0.5, c, M.plastic, NC)
		fcz(fu, "Dial", f, 1.0, 4.05, 0.88, 0.1, 0.4, "#5a5a5a", M.plastic, NCS)
	end
	fb(fu, "Basket", CF(-21.3, F1 + 3.6, 17.6), 0, 0, 0, 1.8, 1.0, 1.4, "#e8e2c8", M.plastic, NC)
	blk(fu, "Shelf", -25.2, F1 + 7.4, 17.9, -17.6, F1 + 7.6, 19.25, "#8a6a42", M.wood)
	for i = 0, 3 do blk(fu, "Detergent", -24.6 + i * 1.8, F1 + 7.6, 18.2, -23.6 + i * 1.8, F1 + 9, 19, BOOKS[i + 2], M.cardboard, NCS) end
	-- раковина для стирки, скамья с крючками, обувь
	blk(fu, "UtilitySink", -9.9, F1, 17.0, -7.7, F1 + 3.3, 19.15, "#e8e8e2", M.plastic)
	blk(fu, "Bench", -25.2, F1, 10, -23.6, F1 + 1.9, 14.5, "#7a5a3a", M.wood)
	blk(fu, "HookRail", -25.24, F1 + 6.2, 9.8, -25.0, F1 + 6.6, 14.7, "#7a5a3a", M.wood, NCS)
	for i = 0, 2 do blk(fu, "Coat", -25.0, F1 + 3.4, 10.4 + i * 1.5, -24.5, F1 + 6.4, 11.4 + i * 1.5, BOOKS[i + 4], M.fabric, NCS) end
	blk(fu, "Boots", -24.8, F1, 15.1, -23.8, F1 + 1.2, 16.1, "#2a2420", M.leather, NCS)
	fb(fu, "LaundryBasket", CF(-18.5, F1, 12.5), 0, 0, 0, 2.2, 1.6, 1.6, "#d8d2b8", M.plastic)
	fb(fu, "Clothes", CF(-18.5, F1 + 1.6, 12.5), 0, 0, 0, 1.9, 0.4, 1.3, "#6a7aa8", M.fabric, NCS)
	ceilingLight("Laundry", -20.5, 9, C1, "fluor")
	-- туалет (половинная ванная)
	finishRoom({ name = "HalfBath", x0 = -14.5, z0 = 0.5, x1 = -7.5, z1 = 8.5, y = F1, floor = "tiles", fc = "#e8e4dc", fc2 = "#2a4a5a",
		wall = "#b8c8c0", wains = 4, wainsColor = "#d8e4e0" })
	local tf = CF(-11, F1, 1.8, 180)
	fb(fu, "ToiletBase", tf, 0, 0, -0.3, 1.3, 1.6, 2.0, "#f4f4f0", M.plastic)
	fb(fu, "ToiletSeat", tf, 0, 1.6, -0.4, 1.6, 0.18, 2.0, "#f4f4f0", M.plastic, NC)
	fb(fu, "ToiletTank", tf, 0, 1.6, 0.9, 2.0, 1.8, 0.9, "#f4f4f0", M.plastic)
	local sf = CF(-8.6, F1, 5, 90)
	fvc(fu, "Pedestal", sf, 0, 0, 0.2, 2.8, 0.8, "#f4f4f0", M.plastic)
	fb(fu, "Basin", sf, 0, 2.8, 0.1, 2.2, 0.5, 1.8, "#f4f4f0", M.plastic)
	B.part(fu, "Mirror", Vector3.new(0.1, 2.6, 2.0), CF(-7.6, F1 + 6, 5), "#b8c8d0", M.glass, { CanCollide = false, Reflectance = 0.35 })
	fcz(fu, "TowelRing", CF(-12.5, F1 + 4.5, 8.4), 0, 0, 0, 0.1, 1.0, "#c8c8c8", M.metal, NCS)
	ceilingLight("HalfBath", -11, 4.5, C1, "dome", { Range = 14 })
end

function A.garage()
	local fu = S.f.Furniture
	finishRoom({ name = "Garage", x0 = -49.25, z0 = -19.25, x1 = -26.75, z1 = 19.25, y = F1, floor = "concrete", fc = "#8a8780",
		noWalls = true, noCrown = true, base = "#77746c", ceil = "#c8c4b8" })
	-- рулонные ворота (закрыты, статичные)
	for i = 0, 4 do
		local y = 1 + i * 2
		blk(S.f.Structure, "GarageDoor", -46, y, -20.25, -30, y + 1.96, -19.95, vary("#ece8de", 0.02), M.metal)
		blk(S.f.Structure, "DoorRib", -45.6, y + 0.9, -20.35, -30.4, y + 1.05, -20.25, "#d8d4c8", M.metal, NCS)
	end
	for i = 0, 3 do blk(S.f.Structure, "DoorWindow", -44.5 + i * 4, 9.4, -20.3, -41.5 + i * 4, 10.4, -20.2, "#1e2a30", M.glass, NCS) end
	blk(S.f.Structure, "DoorHandle", -38.6, 2.0, -20.45, -37.4, 2.3, -20.25, "#8a8a8a", M.metal, NCS)
	for _, x in ipairs({ -46.4, -29.6 }) do blk(fu, "Track", x - 0.2, F1, -19.6, x + 0.2, 11.2, -19.2, "#8a8a8a", M.metal, NCS) end
	blk(fu, "Opener", -39.2, C1 - 1.2, -6, -36.8, C1 - 0.2, -3.8, "#d8d4c8", M.plastic, NCS)
	blk(fu, "OpenerRail", -38.15, C1 - 0.6, -19, -37.85, C1 - 0.3, -6, "#8a8a8a", M.metal, NCS)
	-- верстак, перфорированная доска с инструментами
	local wb = CF(-42, F1, 18.05)
	tableF(fu, wb, 10, 2.4, 3.3, "#8a6a42")
	fb(fu, "LowerShelf", wb, 0, 0.8, 0, 9.4, 0.2, 2.0, "#7a5a32", M.wood, NC)
	B.part(fu, "Pegboard", Vector3.new(10, 4.5, 0.15), CF(-42, F1 + 6.8, 19.17), "#b8a07a", M.cardboard, NCS)
	local tools = { { -45.5, 7.5, 0.4, 2.2 }, { -44.2, 7.2, 1.8, 0.35 }, { -42.5, 7.8, 0.3, 1.8 }, { -41, 7.0, 2.4, 1.0 }, { -38.8, 7.6, 0.5, 2.0 }, { -37.8, 8.0, 0.3, 1.4 } }
	for i, t in ipairs(tools) do
		B.part(fu, "Tool", Vector3.new(t[3], t[4], 0.12), CF(t[1], F1 + t[2], 19.05), ({ "#c8322a", "#8a8a8a", "#2a2a2a", "#c8c8c8", "#d8a83a", "#3a6a9a" })[i], M.metal, NCS)
	end
	fb(fu, "Vise", wb, -4, 3.3, -0.6, 1.0, 0.8, 0.8, "#3a5a3a", M.metal, NCS)
	fb(fu, "Toolbox", wb, 2.5, 3.3, 0, 2.2, 1.0, 1.0, "#c8322a", M.metal, NCS)
	-- стеллаж с коробками
	for s = 0, 3 do blk(fu, "RackShelf", -49.2, F1 + 0.5 + s * 2.2, 10, -47.3, F1 + 0.65 + s * 2.2, 17.5, "#8a8a8a", M.metal) end
	for _, z in ipairs({ 10, 17.4 }) do blk(fu, "RackPost", -49.2, F1, z - 0.1, -47.3, F1 + 7.4, z + 0.1, "#6a6a6a", M.metal, NCS) end
	for s = 0, 3 do
		local z = 10.4
		while z < 16.8 do
			local w = rnd(1.4, 2.3)
			if rnd(0, 1) < 0.8 then
				blk(fu, "Box", -49, F1 + 0.65 + s * 2.2, z, -47.6, F1 + 0.65 + s * 2.2 + rnd(1.0, 1.8), math.min(z + w - 0.1, 17.3), vary("#a8865a", 0.1), M.cardboard, NC)
			end
			z = z + w
		end
	end
	-- шкафчик-укрытие, старый холодильник, морозильный ларь
	hideSpot({ name = "Hide_Garage_1", room = "Garage", kind = "Cabinet", x = -31, z = 17.45, y = F1, yaw = 0, w = 4.6, ht = 8, d = 3.4, color = "#5f6e74", label = "Железный шкаф", clothes = "#3a4a3a" })
	local of = CF(-28.25, F1, -1, 90)
	fb(fu, "OldFridge", of, 0, 0, 0, 3, 6, 2.8, "#d8cfa8", M.plastic)
	fb(fu, "FridgeHandle", of, 1.2, 3.2, -1.45, 0.25, 1.4, 0.25, "#c8c8c8", M.metal, NCS)
	blk(fu, "ChestFreezer", -30, F1, -9.5, -26.8, F1 + 3, -5.5, "#ece8e0", M.plastic)
	-- газонокосилка, канистры, велосипед, масляные пятна
	local lm = CF(-44, F1, 11, 30)
	fb(fu, "Mower", lm, 0, 0.5, 0, 2.2, 1.0, 2.6, "#c8322a", M.metal)
	for _, w in ipairs({ { -1.1, -1 }, { 1.1, -1 }, { -1.1, 1 }, { 1.1, 1 } }) do fcx(fu, "Wheel", lm, w[1], 0.45, w[2], 0.25, 0.9, "#1a1a1a", M.rubber, NCS) end
	B.part(fu, "MowerHandle", Vector3.new(1.8, 0.15, 3.2), lm * CFrame.new(0, 2.4, 2.4) * CFrame.Angles(math.rad(50), 0, 0), "#3a3a3a", M.metal, NCS)
	for i = 0, 1 do blk(fu, "GasCan", -46.6 + i * 1.2, F1, 13.6, -45.8 + i * 1.2, F1 + 1.4, 14.6, "#c8322a", M.plastic, NCS) end
	local bk = CF(-48.6, F1, 3, 90)
	fcx(fu, "BikeWheel", bk, -1.4, 1.3, 0, 0.2, 2.6, "#1a1a1a", M.rubber, NCS)
	fcx(fu, "BikeWheel", bk, 1.4, 1.3, 0, 0.2, 2.6, "#1a1a1a", M.rubber, NCS)
	fcz(fu, "BikeFrame", bk, 0, 2.1, 0, 2.8, 0.2, "#3a7ac8", M.metal, NCS)
	for _, o in ipairs({ { -40, 4, 3.2 }, { -37, 9, 2.2 }, { -41.5, 12, 1.6 } }) do
		fvc(fu, "OilStain", CF(o[1], F1, o[2]), 0, 0, 0, 0.02, o[3], "#1e1c1a", M.plastic, NCS)
	end
	ceilingLight("Garage", -38, -9, C1, "fluor", { Range = 22, Color = Color3.fromRGB(240, 236, 220) })
	ceilingLight("Garage", -38, 9, C1, "fluor", { Range = 22, Color = Color3.fromRGB(240, 236, 220) })
end

-- ===== 2 этаж =====
function A.upstairs()
	local fu = S.f.Furniture
	finishRoom({ name = "Upstairs", x0 = -6.5, z0 = -7.5, x1 = 6.5, z1 = 19.25, y = F2, wall = "#c8b89a", tex = "WallpaperLiving", skip = { w = true } })
	floorRect(S.f.Floors, "carpet", -0.5, -7.5, 6.5, 19.25, F2, "#7a6a5a")
	floorRect(S.f.Floors, "carpet", -6.5, -7.5, -0.5, -2, F2, "#7a6a5a")
	floorRect(S.f.Floors, "carpet", -6.5, 10, -0.5, 19.25, F2, "#7a6a5a")
	hideSpot({ name = "Hide_Upstairs_1", room = "Upstairs", kind = "Closet", x = -3.5, z = 17.45, y = F2, yaw = 0, w = 5, d = 3.6, label = "Бельевой шкаф", clothes = "#e8e2d4" })
	local cf = CF(5.85, F2, 4, 90)
	tableF(fu, cf, 3.4, 1.2, 3, "#6a4a2e")
	plant(fu, 5.85, F2 + 3, 3.2)
	fb(fu, "PhotoFrame", cf, 0.8, 3, 0, 0.7, 0.9, 0.12, "#3a2a1a", M.wood, NCS)
	fb(fu, "LaundryBasket", CF(5.2, F2, 8.2), 0, 0, 0, 2, 1.5, 1.5, "#d8d2b8", M.plastic)
	picture(fu, CF(6.42, F2 + 7, 4.5, 90), 2.2, 2.8, "Poster3", "#7a8a6a")
	picture(fu, CF(6.42, F2 + 7, 7.8, 90), 1.6, 2.0, "FamilyPhoto", "#a89070")
	B.part(fu, "SmokeDetector", Vector3.new(0.9, 0.3, 0.9), CF(3, C2 - 0.35, 2), "#f4f0e6", M.plastic, NCS)
	ceilingLight("Upstairs", 3, -4.5, C2, "dome")
	ceilingLight("Upstairs", 2.5, 14, C2, "dome")
end

function A.bathroom()
	local fu = S.f.Furniture
	finishRoom({ name = "Bathroom", x0 = -6.5, z0 = -19.25, x1 = 6.5, z1 = -8.5, y = F2, floor = "tiles", fc = "#ece8e0", fc2 = "#6a8a9a",
		wall = "#c8d8d4", wains = 4.5, wainsColor = "#e2ecea" })
	-- ванна
	blk(fu, "TubBottom", -6.5, F2, -19.25, 1, F2 + 0.6, -15.9, "#f4f4f0", M.plastic)
	blk(fu, "TubWall", -6.5, F2 + 0.6, -15.9 - 0.4, 1, F2 + 2.2, -15.9, "#f4f4f0", M.plastic)
	blk(fu, "TubWall", -6.5, F2 + 0.6, -19.25, 1, F2 + 2.2, -18.85, "#f4f4f0", M.plastic)
	blk(fu, "TubWall", 0.6, F2 + 0.6, -18.85, 1, F2 + 2.2, -16.3, "#f4f4f0", M.plastic)
	blk(fu, "TubWall", -6.5, F2 + 0.6, -18.85, -6.1, F2 + 2.2, -16.3, "#f4f4f0", M.plastic)
	blk(fu, "TubCollider", -6.5, F2, -19.25, 1, F2 + 2.2, -15.9, nil, nil, { Transparency = 1, CastShadow = false })
	fcx(fu, "Faucet", CF(-5.9, F2 + 3, -17.6), 0, 0, 0, 0.8, 0.25, "#c8c8c8", M.metal, NCS)
	fcx(fu, "ShowerHead", CF(-6.1, F2 + 7.6, -17.6), 0, 0, 0, 0.6, 0.6, "#c8c8c8", M.metal, NCS)
	fcx(fu, "CurtainRod", CF(-2.75, F2 + 8.4, -15.8), 0, 0, 0, 7.6, 0.16, "#c8c8c8", M.metal, NCS)
	for i = 0, 2 do
		blk(fu, "ShowerCurtain", -6.4 + i * 1.3, F2 + 2.4, -15.95 - (i % 2) * 0.2, -5.2 + i * 1.3, F2 + 8.3, -15.75 - (i % 2) * 0.2, "#e8eef0", M.fabric, NCS)
	end
	-- унитаз
	local tf = CF(4.3, F2, -17.6, 180)
	fb(fu, "ToiletBase", tf, 0, 0, -0.3, 1.3, 1.6, 2.0, "#f4f4f0", M.plastic)
	fb(fu, "ToiletSeat", tf, 0, 1.6, -0.4, 1.6, 0.18, 2.0, "#f4f4f0", M.plastic, NC)
	fb(fu, "ToiletTank", tf, 0, 1.6, 0.9, 2.0, 1.8, 0.9, "#f4f4f0", M.plastic)
	-- тумба с раковиной, зеркало, лампа над зеркалом
	local vf = CF(-5.4, F2, -11.5, -90)
	fb(fu, "Vanity", vf, 0, 0, 0, 4, 3.0, 2.2, "#e8dfc8", M.wood)
	fb(fu, "VanityTop", vf, 0, 3.0, -0.05, 4.2, 0.25, 2.4, "#d8d0c4", M.marble)
	fb(fu, "Basin", vf, 0, 3.0, -0.1, 1.6, 0.27, 1.2, "#f4f4f0", M.plastic, NCS)
	fvc(fu, "Faucet", vf, 0, 3.25, 0.75, 0.7, 0.2, "#c8c8c8", M.metal, NCS)
	B.part(fu, "Mirror", Vector3.new(0.1, 3.4, 3.6), CF(-6.42, F2 + 6.4, -11.5), "#b8c8d0", M.glass, { CanCollide = false, Reflectance = 0.4 })
	B.part(fu, "LightBar", Vector3.new(0.4, 0.35, 3.8), CF(-6.3, F2 + 8.6, -11.5), "#c9a24a", M.metal, NCS)
	lampGlow("Bathroom", Vector3.new(0.35, 0.35, 0.35), CF(-6.0, F2 + 8.3, -11.5), Enum.PartType.Ball, "PointLight", { Range = 16 })
	fcz(fu, "TowelBar", CF(6.3, F2 + 5, -14), 0, 0, 0, 2.6, 0.12, "#c8c8c8", M.metal, NCS)
	blk(fu, "Towel", 6.15, F2 + 2.6, -15.1, 6.4, F2 + 5, -12.9, "#7a9ac8", M.fabric, NCS)
	blk(fu, "BathMat", -4, F2, -15.6, -0.5, F2 + 0.06, -13.8, "#6a8aa8", M.carpet, NCS)
end

function A.kids()
	local fu = S.f.Furniture
	finishRoom({ name = "KidsRoom", x0 = -25.25, z0 = -19.25, x1 = -7.5, z1 = -0.5, y = F2, floor = "carpet", fc = "#4a5a7a",
		wall = "#a8b6c6", tex = "WallpaperKids" })
	-- кровать — укрытие под кроватью
	local m = B.model(S.f.Hides, "Hide_KidsRoom_2")
	local f = CF(-21.3, F2, -14, -90) -- изголовье у западной стены, LookVector → к изножью (+X)
	local fr = fb(m, "Frame", f, 0, 1.6, 0, 4.2, 0.6, 7.6, "#c84a3a", M.wood)
	for _, a in ipairs({ -1, 1 }) do
		for _, b in ipairs({ -1, 1 }) do fb(m, "Leg", f, a * 1.9, 0, b * 3.6, 0.35, 1.6, 0.35, "#c84a3a", M.wood) end
	end
	fb(m, "Mattress", f, 0, 2.2, 0, 3.9, 0.8, 7.3, "#efe8dc", M.fabric)
	fb(m, "Blanket", f, 0, 2.85, -1.3, 4.3, 0.3, 4.9, "#3a7ac8", M.fabric, NC)
	fb(m, "Pillow", f, 0, 3.0, 2.8, 2.4, 0.55, 1.2, "#f4f0e6", M.fabric, NC)
	fb(m, "Headboard", f, 0, 0, 3.9, 4.6, 4.4, 0.35, "#c84a3a", M.wood)
	fb(m, "Skirt", f, 2.12, 0.55, 0, 0.06, 1.05, 7.2, "#3a7ac8", M.fabric, NCS)
	fball(m, "Teddy", f, 0.9, 3.4, 2.0, 1.0, "#a87a4a", M.fabric, NCS)
	mark(m, "Inside", CFrame.lookAt(V(-21.3, F2 + 1, -14), V(-21.3, F2 + 1, -10)), Vector3.new(1, 1, 1))
	mark(m, "Exit", CFrame.lookAt(V(-21.3, F2 + 0.1, -9.4), V(-21.3, F2 + 0.1, -5)))
	B.prompt(fr, "Prompt", "Спрятаться", "Под кроватью", { HoldDuration = 0, MaxActivationDistance = 7 })
	B.attrs(m, { Kind = "Hide", HideType = "UnderBed", Occupant = 0, Room = "KidsRoom" })
	table.insert(S.hides, m)
	-- сундук с игрушками, игрушки, кукольный домик, стол
	blk(fu, "ToyChest", -17.1, F2, -15.4, -15.2, F2 + 2.1, -12.6, "#e8c83a", M.wood)
	blk(fu, "ToyChestLid", -17.2, F2 + 2.1, -15.5, -15.1, F2 + 2.4, -12.5, "#3ac85a", M.wood, NC)
	hideSpot({ name = "Hide_KidsRoom_1", room = "KidsRoom", kind = "Closet", x = -19.5, z = -2.3, y = F2, yaw = 0, w = 5, d = 3.6, label = "Шкаф", clothes = "#c84a7a" })
	fvc(fu, "RoundRug", CF(-14, F2, -9), 0, 0, 0, 0.06, 7, "#e8a83a", M.carpet, NCS)
	fball(fu, "Ball", CF(-13, F2 + 0.8, -8), 0, 0, 0, 1.6, "#e84a3a", M.plastic)
	for i = 0, 3 do
		blk(fu, "Block", -11.8 + (i % 2) * 0.1, F2 + i * 0.8, -11.4, -11 + (i % 2) * 0.1, F2 + 0.8 + i * 0.8, -10.6, BOOKS[i + 1], M.plastic, NC)
	end
	local tr = CF(-15.5, F2, -6.4, 30)
	fb(fu, "ToyTruck", tr, 0, 0.4, 0, 1.2, 0.9, 2.4, "#e8c83a", M.plastic, NC)
	for _, w in ipairs({ { -0.65, -0.8 }, { 0.65, -0.8 }, { -0.65, 0.8 }, { 0.65, 0.8 } }) do fcx(fu, "Wheel", tr, w[1], 0.35, w[2], 0.2, 0.7, "#1a1a1a", M.rubber, NCS) end
	local dh = CF(-23.9, F2, -6.8, -90)
	fb(fu, "Dollhouse", dh, 0, 0, 0, 3.4, 2.8, 2.4, "#f4d8e0", M.wood)
	B.wedge(fu, "DollRoof", Vector3.new(3.6, 1.2, 1.3), dh * CFrame.new(0, 3.4, -0.65), "#c84a7a", M.wood, NC)
	B.wedge(fu, "DollRoof", Vector3.new(3.6, 1.2, 1.3), dh * CFrame.new(0, 3.4, 0.65) * CFrame.Angles(0, math.pi, 0), "#c84a7a", M.wood, NC)
	local dk = CF(-8.35, F2, -16.5, 90)
	tableF(fu, dk, 4, 1.7, 2.8, "#e8dcc0")
	chair(fu, CF(-10.3, F2, -16.5, -90), "#3a7ac8")
	for i = 0, 2 do fb(fu, "Crayon", dk, -0.8 + i * 0.3, 2.8, 0, 0.12, 0.12, 0.6, BOOKS[i + 1], M.plastic, NCS) end
	tableLamp("KidsRoom", -8.3, F2 + 2.8, -17.8, "#f4c8a8", { Range = 12, Brightness = 1 })
	picture(fu, CF(-16, F2 + 7.5, -19.13, 180), 3, 4, "Poster1", "#3a8ae8", "#e8e8e8")
	picture(fu, CF(-7.62, F2 + 7, -12, 90), 2.6, 3.4, "Poster2", "#e8c83a", "#e8e8e8")
	ceilingLight("KidsRoom", -16, -10, C2, "dome")
end

function A.bedroom2()
	local fu = S.f.Furniture
	finishRoom({ name = "Bedroom2", x0 = -25.25, z0 = 0.5, x1 = -7.5, z1 = 19.25, y = F2, floor = "carpet", fc = "#5a6a5a",
		wall = "#7d8a6a", tex = "WallpaperBedroom" })
	bed(fu, CF(-20.9, F2, 8, -90), 5.6, 8, "#6a3a3a", "#5a3a22")
	local ns = CF(-24.35, F2, 3.8, -90)
	fb(fu, "Nightstand", ns, 0, 0, 0, 1.8, 2.4, 1.6, "#5a3a22", M.wood)
	fb(fu, "AlarmClock", ns, 0.4, 2.4, 0, 0.7, 0.45, 0.4, "#1a1a1a", M.plastic, NCS)
	tableLamp("Bedroom2", -24.4, F2 + 2.4, 3.4)
	hideSpot({ name = "Hide_Bedroom2_1", room = "Bedroom2", kind = "Closet", x = -11.5, z = 2.3, y = F2, yaw = 180, w = 5, d = 3.6, label = "Шкаф", clothes = "#2a3a5a" })
	local dr = CF(-8.35, F2, 7, 90)
	fb(fu, "Dresser", dr, 0, 0, 0, 4.6, 3.6, 1.7, "#6a4a2e", M.wood)
	for k = 0, 2 do fb(fu, "Drawer", dr, 0, 0.4 + k * 1.05, -0.86, 4.2, 0.85, 0.05, "#7a5a3a", M.wood, NCS) end
	fb(fu, "Boombox", dr, 0, 3.6, 0, 2.4, 1.0, 0.8, "#2a2a2a", M.plastic, NCS)
	local dk = CF(-12, F2, 18.3)
	tableF(fu, dk, 5, 1.9, 3, "#8a6a42")
	chair(fu, CF(-12, F2, 16.2, 180), "#3a3a3a")
	for i = 0, 3 do fb(fu, "Cassette", dk, -1.5 + i * 0.5, 3, 0, 0.4, 0.12, 0.65, BOOKS[i + 2], M.plastic, NCS) end
	B.part(fu, "Guitar", Vector3.new(0.4, 4.2, 1.4), CF(-24.6, F2 + 2.2, 15.5) * CFrame.Angles(0, 0, math.rad(-12)), "#8a4a1a", M.wood, NCS)
	picture(fu, CF(-25.13, F2 + 7.5, 9, -90), 3.2, 4.2, "Poster3", "#2a2a2a", "#1a1a1a")
	ceilingLight("Bedroom2", -16, 10, C2, "dome")
end

function A.master()
	local fu = S.f.Furniture
	finishRoom({ name = "Bedroom1", x0 = 7.5, z0 = -19.25, x1 = 25.25, z1 = 3.5, y = F2, floor = "carpet", fc = "#8a6a6a",
		wall = "#c9a7a0", tex = "WallpaperBedroom" })
	bed(fu, CF(20.7, F2, -9, 90), 7, 8.5, "#7a4a6a", "#4a2e1a")
	for i, z in ipairs({ -13.5, -4.5 }) do
		local ns = CF(24.35, F2, z, 90)
		fb(fu, "Nightstand", ns, 0, 0, 0, 1.8, 2.4, 1.6, "#4a2e1a", M.wood)
		tableLamp("Bedroom1", 24.4, F2 + 2.4, z)
		if i == 1 then fb(fu, "Book", ns, -0.4, 2.4, 0, 0.8, 0.2, 1.0, "#2a4a6a", M.plastic, NCS) end
	end
	local dr = CF(16.85, F2, -18.4, 180)
	fb(fu, "Dresser", dr, 0, 0, 0, 3.9, 3.2, 1.7, "#4a2e1a", M.wood)
	for k = 0, 2 do fb(fu, "Drawer", dr, 0, 0.35 + k * 0.95, -0.86, 3.6, 0.8, 0.05, "#5a3a22", M.wood, NCS) end
	fb(fu, "JewelryBox", dr, -1, 3.2, 0, 0.9, 0.5, 0.6, "#7a2a2a", M.wood, NCS)
	B.part(fu, "Mirror", Vector3.new(2.6, 3.2, 0.1), CF(16.85, F2 + 5.6, -19.1), "#b8c8d0", M.glass, { CanCollide = false, Reflectance = 0.35 })
	hideSpot({ name = "Hide_Bedroom1_1", room = "Bedroom1", kind = "Wardrobe", x = 18, z = 1.75, y = F2, yaw = 0, w = 5, ht = 8, d = 3.5, color = "#6a4a2e", label = "Гардероб", clothes = "#7a5a6a" })
	blk(fu, "CedarChest", 14.6, F2, -11, 16.4, F2 + 2, -7, "#7a4a2a", M.wood)
	fb(fu, "LaundryBasket", CF(23.2, F2, 1.6), 0, 0, 0, 2, 1.5, 1.5, "#d8d2b8", M.plastic)
	armchair(fu, CF(10.4, F2, -16.4, -135), "#8a7a5a")
	rug(fu, 12.5, -14, 18.5, -4, F2, "#4a3a5a")
	picture(fu, CF(25.13, F2 + 7.6, -9, 90), 4.2, 2.6, nil, "#6a7a8a", "#c9a24a")
	ceilingLight("Bedroom1", 16, -8, C2, "fan")
end

function A.study()
	local fu = S.f.Furniture
	finishRoom({ name = "Study", x0 = 7.5, z0 = 4.5, x1 = 25.25, z1 = 19.25, y = F2, floor = "planksX", fc = "#8a6a46",
		wall = "#a89a78", tex = "WallpaperLiving" })
	local dk = CF(16, F2, 17.95)
	tableF(fu, dk, 5, 2.4, 3, "#6a4a2e")
	fb(fu, "Monitor", dk, -0.4, 3, 0.2, 2.2, 1.9, 1.9, "#d8d0bc", M.plastic)
	fb(fu, "MonitorScreen", dk, -0.4, 3.25, -0.76, 1.7, 1.35, 0.04, "#1a2a3a", M.glass, NCS)
	fb(fu, "Keyboard", dk, -0.4, 3, -0.9, 1.9, 0.12, 0.6, "#d8d0bc", M.plastic, NCS)
	fb(fu, "Mouse", dk, 0.9, 3, -0.9, 0.25, 0.12, 0.4, "#d8d0bc", M.plastic, NCS)
	fb(fu, "PCTower", dk, 2.6, 0, 0, 0.9, 2.4, 2.0, "#d8d0bc", M.plastic)
	tableLamp("Study", 14.2, F2 + 3, 18.5, "#3a6a4a", { Range = 12, Brightness = 1 })
	chair(fu, CF(16, F2, 15.4, 180), "#2a2a2a")
	bookcase(fu, CF(12, F2, 5.2, 180), 3.8, 7.6, 1.4, "#5a3a22")
	bookcase(fu, CF(16.2, F2, 5.2, 180), 3.8, 7.6, 1.4, "#5a3a22")
	blk(fu, "FilingCabinet", 19.5, F2, 17.4, 21.3, F2 + 4.4, 19.25, "#7a7c70", M.metal)
	for i = 0, 2 do blk(fu, "Box", 22.2, F2 + i * 1.4, 5 + (i % 2) * 0.4, 24.9, F2 + 1.4 + i * 1.4, 7.8 + (i % 2) * 0.4, vary("#a8865a", 0.1), M.cardboard) end
	picture(fu, CF(7.62, F2 + 7, 7.5, -90), 3, 2.2, "BlackRidgeLogo", "#8a9a8a")
	ceilingLight("Study", 16, 11, C2, "dome")
end

-- проёмы: двери, арки, окна
function A.openings()
	for _, d in ipairs(DOORS) do
		local ok, err = pcall(door, d)
		if not ok then warn("[AA] HouseMap дверь " .. d.name .. ": " .. tostring(err)) end
	end
	for _, a in ipairs(ARCHES) do pcall(archway, a) end
	for _, w in ipairs(WINDOWS) do
		local ok, err = pcall(window, w)
		if not ok then warn("[AA] HouseMap окно " .. w.name .. ": " .. tostring(err)) end
	end
end

-- ===== снаружи: крыльцо, дорожки, улица, машина =====
local function streetLamp(x, z, yaw)
	local par, f = S.f.Street, CF(x, 0, z, yaw)
	fvc(par, "LampPole", f, 0, 0, 0, 17, 0.6, "#2a2c30", M.metal)
	fb(par, "LampArm", f, 0, 16.4, -2, 0.3, 0.3, 4.2, "#2a2c30", M.metal, NC)
	fb(par, "LampHead", f, 0, 15.9, -4, 1.4, 0.6, 2.2, "#2a2c30", M.metal, NC)
	local g = fb(par, "LampGlow", f, 0, 15.75, -4, 1.1, 0.16, 1.8, "#ffd08a", M.neon, NCS)
	B.light(g, "SpotLight", { Face = Enum.NormalId.Bottom, Angle = 110, Range = 42, Brightness = 2.2, Color = Color3.fromRGB(255, 196, 130) })
end

local function sedan(x, z, yaw)
	local par = S.f.Street
	local f = CF(x, 0, z, yaw)
	local body = "#5a1e22"
	fb(par, "CarBody", f, 0, 1.1, 0, 6.6, 2.3, 15.5, body, M.metal)
	fb(par, "CarCabin", f, 0, 3.4, 0.6, 6.0, 2.1, 7.6, body, M.metal)
	fb(par, "Windshield", f, 0, 3.5, -3.3, 5.6, 1.8, 0.2, "#1a2228", M.glass, { CanCollide = false, Reflectance = 0.15 })
	fb(par, "RearGlass", f, 0, 3.5, 4.5, 5.6, 1.8, 0.2, "#1a2228", M.glass, { CanCollide = false, Reflectance = 0.15 })
	for _, s in ipairs({ -1, 1 }) do
		fb(par, "SideGlass", f, s * 3.02, 3.6, 0.6, 0.06, 1.6, 7.0, "#1a2228", M.glass, NCS)
		fb(par, "Trim", f, s * 3.32, 1.9, 0, 0.06, 0.2, 15, "#c8c8c8", M.metal, NCS)
		fb(par, "Mirror", f, s * 3.4, 3.4, -2.6, 0.5, 0.4, 0.3, body, M.metal, NCS)
		for _, wz in ipairs({ -4.8, 4.8 }) do
			fcx(par, "Tire", f, s * 2.95, 1.25, wz, 1.0, 2.5, "#1a1a1a", M.rubber, NC)
			fcx(par, "Hubcap", f, s * 3.47, 1.25, wz, 0.05, 1.4, "#b8b8b8", M.metal, NCS)
		end
		fb(par, "Headlight", f, s * 2.2, 1.9, -7.78, 1.4, 0.7, 0.06, "#f4f0d8", M.glass, NCS)
		fb(par, "Taillight", f, s * 2.3, 2.0, 7.78, 1.2, 0.6, 0.06, "#8a1a1a", M.glass, NCS)
	end
	fb(par, "Grille", f, 0, 1.6, -7.78, 2.4, 0.8, 0.06, "#2a2a2a", M.metal, NCS)
	fb(par, "Bumper", f, 0, 0.9, -7.85, 6.7, 0.5, 0.3, "#9a9a9a", M.metal, NCS)
	fb(par, "Bumper", f, 0, 0.9, 7.85, 6.7, 0.5, 0.3, "#9a9a9a", M.metal, NCS)
	local plate = fb(par, "Plate", f, 0, 1.3, 7.95, 1.6, 0.8, 0.05, "#f4f0e6", M.plastic, NCS)
	B.sign(plate, Enum.NormalId.Back, "4ABR 317", { TextColor3 = Color3.fromRGB(30, 40, 90) })
end

function A.exterior()
	local st, yd = S.f.Street, S.f.Yard
	blk(st, "Ground", -230, -2, -230, 230, 0, 230, "#3f5a2c", M.grass)
	-- дорожка к крыльцу и подъездная дорожка
	for i = 0, 6 do
		blk(st, "Walk", 0.5, 0, -30.5 - (i + 1) * 3.6 + 0.06, 5.5, 0.15, -30.5 - i * 3.6 - 0.06, vary("#9a968c", 0.04), M.concrete)
	end
	for i = 0, 3 do
		for k = 0, 1 do
			blk(st, "Driveway", -48.5 + k * 10.5 + 0.05, 0, -20.95 - (i + 1) * 10.75 + 0.05, -38 + k * 10.5 - 0.05, 0.14, -20.95 - i * 10.75 - 0.05, vary("#8e8a80", 0.04), M.concrete)
		end
	end
	fvc(st, "OilStain", CF(-38, 0.14, -36), 0, 0, 0, 0.02, 3, "#2a2826", M.plastic, NCS)
	-- тротуар, бордюр, дорога с разметкой (на обеих сторонах)
	for i = -11, 10 do
		blk(st, "Sidewalk", i * 20 + 0.06, 0, -58, i * 20 + 19.94, 0.2, -52, vary("#a29e94", 0.03), M.concrete)
		blk(st, "Sidewalk", i * 20 + 0.06, 0, -99, i * 20 + 19.94, 0.2, -93, vary("#a29e94", 0.03), M.concrete)
	end
	blk(st, "Kerb", -230, -0.3, -64.6, 230, 0.45, -64, "#b4b0a6", M.concrete)
	blk(st, "Kerb", -230, -0.3, -92.6, 230, 0.45, -92, "#b4b0a6", M.concrete)
	blk(st, "Road", -230, -0.3, -92, 230, 0.02, -64.6, "#2a2a2c", M.asphalt)
	for x = -150, 150, 12 do blk(st, "RoadLine", x, 0.02, -78.5, x + 5, 0.05, -78.1, "#c9b24a", M.plastic, NCS) end
	streetLamp(-75, -61, 180)
	streetLamp(35, -61, 180)
	streetLamp(-20, -95.5, 0)
	streetLamp(90, -95.5, 0)
	-- почтовый ящик с номером дома
	local mb = CF(8.5, 0, -55.5)
	fb(st, "MailPost", mb, 0, 0, 0, 0.4, 3.6, 0.4, "#5a4a3a", M.wood)
	local box = fb(st, "Mailbox", mb, 0, 3.6, 0, 1.0, 1.0, 2.0, "#2a4a8a", M.metal)
	fb(st, "MailFlag", mb, 0.55, 3.9, 0.4, 0.08, 1.0, 0.25, "#c8322a", M.metal, NCS)
	B.sign(box, Enum.NormalId.Right, "4317", { TextColor3 = Color3.fromRGB(240, 230, 200) })
	sedan(-38, -42, 180)
	-- клумбы и кусты вдоль фасада
	blk(yd, "Mulch", -26.95, 0, -23.6, -4.6, 0.12, -21.05, "#3a2618", M.ground)
	blk(yd, "Mulch", 10.6, 0, -23.6, 26.95, 0.12, -21.05, "#3a2618", M.ground)
	for _, x in ipairs({ -24, -16, -8, 17.75, 25 }) do
		fball(yd, "Bush", CF(x, 1.1, -22.4), 0, 0, 0, 3, vary("#2a4a22", 0.15), M.grass, NC)
	end
	-- дерево перед домом
	local tf = CF(20, 0, -42)
	fvc(yd, "Trunk", tf, 0, 0, 0, 12, 1.8, "#4a3424", M.wood)
	fball(yd, "Canopy", tf, 0, 15, 0, 12, "#2a4422", M.grass, NC)
	fball(yd, "Canopy", tf, 3, 13, 2, 8, "#304a26", M.grass, NC)
	fball(yd, "Canopy", tf, -3, 13.5, -1.5, 8.5, "#28401f", M.grass, NC)
	-- крыльцо с колоннами, перилами и навесом
	blk(yd, "PorchBase", -4.5, 0, -28.5, 10.5, 0.9, -20.95, "#8a8478", M.concrete)
	planks(yd, -4.5, -28.5, 10.5, -20.95, F1, false, 1.0, "#7a6a5a")
	for i = 0, 2 do
		blk(yd, "Step", -1, 0, -30.5 + i * 0.67, 7, 0.33 * (i + 1), -29.83 + i * 0.67, vary("#8a7a6a", 0.05), M.wood, NC)
	end
	B.wedge(yd, "Ramp", Vector3.new(8, 1, 2), CF(3, 0.5, -29.5), "#8a7a6a", M.wood, { Transparency = 1, CastShadow = false })
	for _, x in ipairs({ -4, -1.5, 7.5, 10 }) do
		blk(yd, "ColumnBase", x - 0.6, F1, -28.5, x + 0.6, F1 + 0.6, -27.3, WHITE, M.wood)
		fvc(yd, "Column", CF(x, F1 + 0.6, -27.9), 0, 0, 0, 9.6, 0.9, WHITE, M.wood)
		blk(yd, "Capital", x - 0.6, 11.2, -28.5, x + 0.6, 11.6, -27.3, WHITE, M.wood)
	end
	blk(yd, "Beam", -4.6, 11.6, -28.5, 10.6, 12.4, -27.3, WHITE, M.wood)
	blk(yd, "PorchCeiling", -4.5, 12.2, -28.4, 10.5, 12.4, -20.95, "#e8e4d8", M.wood)
	roofPlane(Vector3.new(3, 12.4, -29.3), Vector3.new(3, 14.4, -20.95), 16, 3)
	local rails = { { -4, -27.9, -1.5, -27.9 }, { 7.5, -27.9, 10, -27.9 }, { -4.3, -27.9, -4.3, -21.2 }, { 10.3, -27.9, 10.3, -21.2 } }
	for _, r in ipairs(rails) do
		local a, b = V(r[1], F1 + 3.2, r[2]), V(r[3], F1 + 3.2, r[4])
		beam(yd, "Rail", a, b, 0.3, WHITE, M.wood)
		beam(yd, "Rail", a - Vector3.new(0, 2.8, 0), b - Vector3.new(0, 2.8, 0), 0.25, WHITE, M.wood, NC)
		local n = math.floor((b - a).Magnitude / 0.8)
		for k = 1, n - 1 do
			local p = a:Lerp(b, k / n)
			B.part(yd, "Baluster", Vector3.new(0.18, 2.8, 0.18), CFrame.new(p - Vector3.new(0, 1.4, 0)), WHITE, M.wood, NCS)
		end
	end
	wallLantern("Porch", 7.3, F1 + 6.5, -21.2, 0)
	local num = blk(yd, "HouseNumber", -2.6, F1 + 6.8, -21.15, -0.4, F1 + 7.7, -20.97, "#2a2a2a", M.wood, NCS)
	B.sign(num, Enum.NormalId.Front, "4317", { TextColor3 = Color3.fromRGB(220, 190, 120) })
	blk(yd, "WelcomeMat", 1.4, F1, -23.6, 4.6, F1 + 0.05, -21.3, "#6a4a2a", M.carpet, NCS)
	-- заднее крылечко
	blk(yd, "StoopBase", 8.5, 0, 20.95, 15.5, 0.9, 25.5, "#8a8478", M.concrete)
	planks(yd, 8.5, 20.95, 15.5, 25.5, F1, true, 1.0, "#7a6a5a")
	for i = 0, 2 do
		blk(yd, "Step", 9, 0, 27.5 - (i + 1) * 0.67, 15, 0.33 * (i + 1), 27.5 - i * 0.67, vary("#8a7a6a", 0.05), M.wood, NC)
	end
	B.wedge(yd, "Ramp", Vector3.new(6, 1, 2), CF(12, 0.5, 26.5, 180), "#8a7a6a", M.wood, { Transparency = 1, CastShadow = false })
	wallLantern("Yard", 16.4, F1 + 7, 21.2, 180)
end

-- ===== задний двор =====
local function fence(x0, z0, x1, z1, gateAt, gateW)
	local par = S.f.Yard
	local a, b = Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z1)
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local yaw = math.deg(math.atan2(-dir.X, -dir.Z)) + 90
	local function seg(s0, s1)
		if s1 - s0 < 0.3 then return end
		local mid = a + dir * ((s0 + s1) / 2)
		local f = CF(mid.X, 0, mid.Z, yaw)
		local L = s1 - s0
		fb(par, "FenceCollider", f, 0, 0, 0, L, 6.2, 0.4, nil, nil, { Transparency = 1, CastShadow = false })
		fb(par, "FenceRail", f, 0, 1.2, 0.35, L, 0.35, 0.3, "#6e5038", M.wood, NC)
		fb(par, "FenceRail", f, 0, 4.6, 0.35, L, 0.35, 0.3, "#6e5038", M.wood, NC)
		local n = math.max(1, math.floor(L / 1.95))
		for k = 0, n - 1 do
			local x = -L / 2 + (k + 0.5) * L / n
			fb(par, "Board", f, x, 0, 0, L / n - 0.12, 6 + ((k % 2) * 0.15), 0.25, vary("#8a6a4a", 0.08), M.wood, NC)
		end
		for x = -L / 2, L / 2 + 0.01, 8 do fb(par, "Post", f, x, 0, 0.3, 0.5, 6.4, 0.5, "#5e4430", M.wood, NC) end
	end
	if gateAt then
		seg(0, gateAt - gateW / 2)
		seg(gateAt + gateW / 2, len)
		-- открытая калитка (статичная)
		local h = a + dir * (gateAt - gateW / 2)
		local f = CF(h.X, 0, h.Z, yaw) * CFrame.Angles(0, math.rad(-75), 0)
		fb(par, "Gate", f, gateW / 2 - 0.2, 0.3, 0, gateW - 0.4, 5.6, 0.25, "#7a5a3a", M.wood)
		fb(par, "GateBrace", f, gateW / 2 - 0.2, 2.8, 0.2, gateW - 0.6, 0.3, 0.1, "#5e4430", M.wood, NCS)
	else
		seg(0, len)
	end
end

function A.yard()
	local yd = S.f.Yard
	fence(-66, 84, 60, 84, 67, 6)        -- задний забор с калиткой (x = 1)
	fence(-66, 12, -66, 84)              -- западный
	fence(-66, 12, -51, 12, 7, 6)        -- от гаража к западному забору, калитка
	fence(60, 0, 60, 84)                 -- восточный
	fence(27.05, 0, 60, 0, 16, 6)        -- от дома к восточному забору, калитка
	-- шесть мест под яблони: 1–3 посажены, 4–6 — закрытые грядки
	local slots = { { -34, 42 }, { -12, 46 }, { 10, 44 }, { -34, 64 }, { -12, 68 }, { 10, 66 } }
	for i, p in ipairs(slots) do
		local ok, err = pcall(appleTree, i, p[1], p[2], i <= 3)
		if not ok then warn("[AA] HouseMap яблоня " .. i .. ": " .. tostring(err)) end
	end
	-- место для разбрызгивателя
	fvc(yd, "SprinklerPad", CF(-12, 0, 55), 0, 0, 0, 0.12, 2.6, "#8a8478", M.slate, NCS)
	S.sprinkler = B.marker(yd, "Sprinkler", Vector3.new(2, 0.4, 2), CF(-12, 0.3, 55))
	-- дорожка из плит
	local stones = { { 12, 29.5 }, { 9, 32.5 }, { 5, 35 }, { 0.5, 37 }, { -4, 39.5 }, { -8, 42.5 }, { -12, 50.5 }, { -22, 52 }, { -32, 53 }, { -42, 60 }, { -48, 66 } }
	for i, p in ipairs(stones) do
		fvc(yd, "Stone", CF(p[1], 0, p[2], i * 33), 0, 0, 0, 0.14, rnd(2.2, 2.8), vary("#8a8680", 0.08), M.slate, NCS)
	end
	-- сарай
	blk(yd, "Shed", -62, 0, 68, -50, 8, 80, "#7a5e44", M.wood)
	for k = 0, 7 do blk(yd, "ShedBoard", -49.95, 0.2 + k, 68.1, -49.8, 1.1 + k, 79.9, vary("#7a5e44", 0.06), M.wood, NCS) end
	B.wedge(yd, "ShedRoof", Vector3.new(13, 3, 6.6), CF(-56, 9.5, 70.7), "#3a3430", M.shingles)
	B.wedge(yd, "ShedRoof", Vector3.new(13, 3, 6.6), CF(-56, 9.5, 77.3, 180), "#3a3430", M.shingles)
	blk(yd, "ShedDoor", -49.8, 0, 71.5, -49.6, 6.6, 76.5, "#5a4030", M.wood, NC)
	blk(yd, "ShedHandle", -49.6, 3.2, 75.6, -49.4, 3.6, 76, "#8a8a8a", M.metal, NCS)
	-- качели
	local sw = CF(37, 0, 59)
	for _, s in ipairs({ -1, 1 }) do
		for _, t in ipairs({ -1, 1 }) do
			B.part(yd, "SwingLeg", Vector3.new(0.4, 9.4, 0.4), sw * CFrame.new(s * 6.5, 4.5, t * 1.4) * CFrame.Angles(math.rad(t * 16), 0, 0), "#3a6a8a", M.metal, NC)
		end
	end
	fcx(yd, "SwingBar", sw, 0, 9, 0, 13.4, 0.5, "#3a6a8a", M.metal, NC)
	for _, sx in ipairs({ -2.5, 2.5 }) do
		fvc(yd, "Rope", sw, sx - 0.8, 2.2, 0, 6.8, 0.1, "#c8b48a", M.fabric, NCS)
		fvc(yd, "Rope", sw, sx + 0.8, 2.2, 0, 6.8, 0.1, "#c8b48a", M.fabric, NCS)
		fb(yd, "SwingSeat", sw, sx, 2.0, 0, 2.0, 0.2, 0.9, "#c8322a", M.plastic, NC)
	end
	-- стол для пикника, гриль, кондиционер, шланг
	local pt = CF(36, 0, 34)
	fb(yd, "PicnicTop", pt, 0, 2.8, 0, 7, 0.3, 3, "#8a6a4a", M.wood)
	for _, s in ipairs({ -1, 1 }) do
		fb(yd, "PicnicBench", pt, 0, 1.6, s * 2.6, 7, 0.25, 1.1, "#8a6a4a", M.wood)
		fb(yd, "PicnicLeg", pt, s * 2.8, 0, 0, 0.3, 2.8, 5.8, "#6e5038", M.wood, NC)
	end
	fball(yd, "Grill", CF(31, 2.8, 25), 0, 0, 0, 2.4, "#1e1e1e", M.metal)
	for i = 0, 2 do
		B.part(yd, "GrillLeg", Vector3.new(0.15, 2.4, 0.15), CF(31, 1.2, 25) * CFrame.Angles(0, i * 2.1, 0) * CFrame.new(0.6, 0, 0) * CFrame.Angles(0, 0, math.rad(12)), "#1e1e1e", M.metal, NCS)
	end
	blk(yd, "ACUnit", 27.4, 0, 4, 30.6, 3, 7, "#b8b8b0", M.metal)
	fvc(yd, "ACFan", CF(29, 3, 5.5), 0, 0, 0, 0.05, 2.4, "#3a3a3a", M.metal, NCS)
	fcz(yd, "HoseReel", CF(23.5, 2, 21.3), 0, 0, 0, 0.8, 1.8, "#3a7a3a", M.plastic, NCS)
end

-- ===== силуэты соседних домов и деревья =====
local function neighbour(cx, cz, face, wall, roof)
	local par = S.f.Neighbors
	blk(par, "House", cx - 14, 0, cz - 10, cx + 14, 24, cz + 10, wall, M.wood)
	for _, s in ipairs({ -1, 1 }) do
		slope(par, "Roof", Vector3.new(cx, 23.4, cz + s * 11), Vector3.new(cx, 30.6, cz), 30, 0.8, roof, M.shingles)
	end
	for _, sx in ipairs({ -13.5, 13.5 }) do
		B.wedge(par, "Gable", Vector3.new(1, 6.6, 10), CF(cx + sx, 27.3, cz - 5), wall, M.wood)
		B.wedge(par, "Gable", Vector3.new(1, 6.6, 10), CF(cx + sx, 27.3, cz + 5, 180), wall, M.wood)
	end
	local zf = cz + face * 10.1
	local spots = { { -9, 4 }, { 9, 4 }, { -9, 15 }, { 0, 15 }, { 9, 15 } }
	for _, w in ipairs(spots) do
		local lit = S.rng:NextNumber() < 0.35
		local c, mat = "#161a22", M.glass
		if lit then c, mat = "#c8965a", M.neon end
		blk(par, "Window", cx + w[1] - 1.8, w[2], zf - 0.1, cx + w[1] + 1.8, w[2] + 4.5, zf + 0.1, c, mat, NCS)
	end
	blk(par, "Door", cx - 1.6, 0, zf - 0.1, cx + 1.6, 8, zf + 0.1, "#3a2a22", M.wood, NCS)
	blk(par, "Chimney", cx + 8, 20, cz - 2, cx + 10.5, 33, cz + 1, "#5a3a2e", M.brick)
end

function A.neighbors()
	neighbour(-140, 0, -1, "#9aa0a0", "#2e2a28")
	neighbour(128, 0, -1, "#b8ad94", "#3a2e2a")
	neighbour(-110, -130, 1, "#8a9488", "#2a2826")
	neighbour(-15, -130, 1, "#c4b8a0", "#33302c")
	neighbour(85, -130, 1, "#9c9484", "#2e2c2a")
	local par = S.f.Neighbors
	local trees = { { -150, 110 }, { -115, 125 }, { -85, 104 }, { -55, 118 }, { -22, 130 }, { 8, 112 }, { 38, 126 }, { 70, 106 }, { 100, 122 },
		{ 135, 108 }, { -90, -12 }, { 92, 18 }, { -62, -165 }, { 32, -168 }, { 130, -160 }, { -170, -60 }, { 170, -40 } }
	for i, t in ipairs(trees) do
		local f = CF(t[1], 0, t[2], i * 40)
		local h = rnd(10, 16)
		fvc(par, "Trunk", f, 0, 0, 0, h, rnd(1.4, 2.2), "#3a2e24", M.wood)
		fball(par, "Canopy", f, 0, h + 3, 0, rnd(10, 15), vary("#22361e", 0.15), M.grass, NC)
		fball(par, "Canopy", f, 2.5, h, 1.5, rnd(7, 10), vary("#263c20", 0.15), M.grass, NC)
	end
end

-- ===== служебные точки, объёмы комнат, «внутри дома» =====
local ROOMS = {
	{ "Hall", "Прихожая", 1, -6.5, -19.25, 6.5, 19.25 },
	{ "LivingRoom", "Гостиная", 1, 7.5, -19.25, 25.25, 1.5 },
	{ "Kitchen", "Кухня", 1, 7.5, 2.5, 25.25, 19.25 },
	{ "Dining", "Столовая", 1, -25.25, -19.25, -7.5, -0.5 },
	{ "Laundry", "Прачечная", 1, -25.25, 0.5, -15.5, 19.25 },
	{ "Laundry", "Прачечная", 1, -15.5, 9.5, -7.5, 19.25 },
	{ "HalfBath", "Туалет", 1, -14.5, 0.5, -7.5, 8.5 },
	{ "Garage", "Гараж", 1, -49.25, -19.25, -26.75, 19.25 },
	{ "Upstairs", "Коридор 2 этажа", 2, -6.5, -7.5, 6.5, 19.25 },
	{ "Bathroom", "Ванная", 2, -6.5, -19.25, 6.5, -8.5 },
	{ "Bedroom1", "Спальня родителей", 2, 7.5, -19.25, 25.25, 3.5 },
	{ "Study", "Кабинет", 2, 7.5, 4.5, 25.25, 19.25 },
	{ "KidsRoom", "Детская", 2, -25.25, -19.25, -7.5, -0.5 },
	{ "Bedroom2", "Спальня", 2, -25.25, 0.5, -7.5, 19.25 },
}

function A.markers()
	for _, r in ipairs(ROOMS) do
		local y0 = (r[3] == 1) and F1 or F2
		local p = B.marker(S.f.Rooms, r[1], Vector3.new(r[6] - r[4], 12, r[7] - r[5]), CF((r[4] + r[6]) / 2, y0 + 6, (r[5] + r[7]) / 2))
		B.attrs(p, { Label = r[2], Floor = r[3], Indoor = true })
		table.insert(S.rooms, p)
	end
	local outs = {
		{ "Porch", "Крыльцо", -4.5, -30.5, 10.5, -20.95, 13 },
		{ "Yard", "Двор", -66, 20.95, 60, 84, 20 },
		{ "Yard", "Двор", 26.95, 0, 60, 20.95, 20 },
		{ "Street", "Улица", -230, -100, 230, -30.5, 20 },
	}
	for _, r in ipairs(outs) do
		local p = B.marker(S.f.Rooms, r[1], Vector3.new(r[5] - r[3], r[7], r[6] - r[4]), CF((r[3] + r[5]) / 2, r[7] / 2, (r[4] + r[6]) / 2))
		B.attrs(p, { Label = r[2], Floor = 0, Indoor = false })
		table.insert(S.rooms, p)
	end
	-- дневные точки появления (гостиная и прихожая), смотрят в комнату; высота — уровень корня персонажа
	local sp = { { 12.5, -2.5, 17, -8 }, { 17, -16.8, 17, -8 }, { 3, -14, 3, -4 }, { 3, 2, 3, -10 }, { 18.3, -2.6, 15, -10 } }
	for _, p in ipairs(sp) do
		local cf = CFrame.lookAt(V(p[1], F1 + 3, p[2]), V(p[3], F1 + 3, p[4]))
		mark(S.f.Spawns, "Spawn", cf, Vector3.new(1, 1, 1))
		table.insert(S.spawns, cf)
	end
	-- места перед телевизором, смотрят на экран
	local scr = S.tvScreen and S.tvScreen.Position or V(21.5, F1 + 4, -10)
	for _, p in ipairs({ { 13.6, -14.4 }, { 13.6, -5.6 }, { 19.2, -14.6 }, { 19.2, -5.4 } }) do
		local pos = V(p[1], F1 + 3, p[2])
		local cf = CFrame.lookAt(pos, Vector3.new(scr.X, pos.Y, scr.Z))
		mark(S.f.AlertSpots, "AlertSpot", cf, Vector3.new(1, 1, 1))
		table.insert(S.alert, cf)
	end
	-- точки появления заключённых: улица и за задним забором
	for _, p in ipairs({ { -60, -78 }, { 60, -78 }, { -30, 96 }, { 40, 96 } }) do
		local cf = CFrame.lookAt(V(p[1], 3, p[2]), V(0, 3, 0))
		mark(S.f.InmateSpawns, "InmateSpawn", cf, Vector3.new(1, 1, 1))
		table.insert(S.inmateSpawns, cf)
	end
	S.interior = B.marker(S.model, "Interior", Vector3.new(77.9, TOP, 41.9), CF(-12, TOP / 2, 0))
end

-- ===== сборка =====
local FOLDERS = { "Doors", "Windows", "Hides", "Trees", "Lights", "Rooms", "Spawns", "AlertSpots", "InmateSpawns",
	"Structure", "Siding", "Roof", "Stairs", "Interior", "Floors", "Trim", "Fixtures", "Furniture", "Yard", "Street", "Neighbors" }
local ORDER = { "structure", "roofs", "stairs", "openings", "hall", "living", "kitchen", "dining", "laundry", "garage",
	"upstairs", "bathroom", "kids", "bedroom2", "master", "study", "tv", "shop", "fuse", "exterior", "yard", "neighbors", "markers" }

function HouseMap.init(ctx)
	if ctx and ctx.Build then
		B = ctx.Build
		Config = ctx.Config
	end
	deps()
end

function HouseMap.build(origin, parent, name)
	deps()
	initMats()
	local model = Instance.new("Model")
	model.Name = name or "House"
	S = {
		o = origin or Vector3.new(0, 0, 0), rng = Random.new(1990), model = model, f = {}, holes = {},
		doors = {}, windows = {}, entries = {}, hides = {}, trees = {}, lights = {}, rooms = {},
		spawns = {}, alert = {}, inmateSpawns = {}, lampN = 0, siding = "#d8d2be", shutter = "#2f4a3a",
	}
	for _, n in ipairs(FOLDERS) do S.f[n] = B.folder(model, n) end
	S.f.Fixtures.Parent = S.f.Furniture
	S.f.Trim.Parent = S.f.Structure
	registerHoles()
	for _, k in ipairs(ORDER) do
		local ok, err = pcall(A[k])
		if not ok then warn("[AA] HouseMap " .. k .. ": " .. tostring(err)) end
	end
	B.attrs(model, { Kind = "House" })
	model.Parent = parent
	local house = {
		model = model, origin = S.o, spawns = S.spawns, alertSpots = S.alert, tv = S.tv,
		doors = S.doors, windows = S.windows, entries = S.entries, hides = S.hides, trees = S.trees,
		fuse = S.fuse, shop = S.shop, lights = S.lights, rooms = S.rooms, inmateSpawns = S.inmateSpawns,
		interior = S.interior, sprinkler = S.sprinkler,
	}
	S = nil
	return house
end

function HouseMap.destroy(house)
	if house and house.model then
		pcall(function() house.model:Destroy() end)
		house.model = nil
	end
end

return HouseMap
