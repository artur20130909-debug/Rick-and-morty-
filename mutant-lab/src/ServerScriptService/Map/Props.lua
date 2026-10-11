-- Общие «кирпичики» карты: фонари, скамейки, заборы, вывески, камни, деревья, бочки, колбы, дорожки.
-- Плюс учёт занятых мест (Occ), чтобы предметы и точки появления ингредиентов не залезали друг на друга.
local RS = game:GetService("ReplicatedStorage")
local B = require(RS.Shared.Build)

local P = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
P.rgb = rgb

-- палитра карты
P.C = {
	metal = rgb(70, 76, 88), metalLight = rgb(150, 158, 170), metalDark = rgb(38, 42, 50),
	wood = rgb(124, 86, 56), woodDark = rgb(84, 58, 40), stone = rgb(120, 124, 130), stoneDark = rgb(78, 80, 88),
	concrete = rgb(178, 184, 188), path = rgb(196, 182, 150), white = rgb(240, 242, 245),
	slime = rgb(120, 255, 80), toxic = rgb(160, 255, 40), labTeal = rgb(60, 220, 190), labPurple = rgb(170, 90, 255),
	warning = rgb(255, 200, 40), black = rgb(25, 25, 30),
}
local C = P.C
local M_WOOD = Enum.Material.Wood

-- направление по компасу: 0° — север (−Z), 90° — восток (+X)
function P.compass(deg)
	local a = math.rad(deg)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end

-- CFrame в точке pos, «лицом» (−Z детали) в сторону target по горизонтали
function P.facing(pos, target)
	local t = Vector3.new(target.X, pos.Y, target.Z)
	if (t - pos).Magnitude < 0.01 then return CFrame.new(pos) end
	return CFrame.lookAt(pos, t)
end

---------------------------------------------------------------------------
-- Учёт занятых мест: круги на плоскости XZ
---------------------------------------------------------------------------
local Occ = {}
Occ.__index = Occ
function P.newOcc() return setmetatable({ list = {} }, Occ) end
function Occ:add(x, z, r) table.insert(self.list, { x, z, r }) end
function Occ:free(x, z, r)
	for _, c in ipairs(self.list) do
		local dx, dz = c[1] - x, c[2] - z
		local rr = c[3] + r
		if dx * dx + dz * dz < rr * rr then return false end
	end
	return true
end
-- занять линию (дорожку) кругами
function Occ:addLine(a, b, r)
	local len = (b - a).Magnitude
	local n = math.max(1, math.ceil(len / (r * 0.8)))
	for i = 0, n do
		local p = a:Lerp(b, i / n)
		self:add(p.X, p.Z, r)
	end
end
-- найти свободное место в прямоугольнике; nil — не нашлось
function Occ:find(rng, x0, x1, z0, z1, r, tries)
	for _ = 1, tries or 30 do
		local x, z = rng:range(x0 + r, x1 - r), rng:range(math.min(z0, z1) + r, math.max(z0, z1) - r)
		if self:free(x, z, r) then return x, z end
	end
	return nil
end

---------------------------------------------------------------------------
-- Дорожки
---------------------------------------------------------------------------
-- плоская дорожка от a до b (y берётся из точек), со скруглёнными концами
function P.path(parent, a, b, w, color, material, th)
	th = th or 0.4
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	if len < 0.05 then return end
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, mid + flat)
	B.part(parent, "Path", Vector3.new(w, th, len), cf, color or C.path, material or Enum.Material.Pavement)
	B.vcyl(parent, "PathEnd", th, w, CFrame.new(b), color or C.path, material or Enum.Material.Pavement)
end

-- дорожка по дуге окружности (центр c, радиус r, углы по компасу от a0 до a1)
function P.arcPath(parent, c, r, a0, a1, w, y, color, material, step)
	step = step or 6
	local n = math.max(1, math.ceil(math.abs(a1 - a0) / step))
	local prev
	for i = 0, n do
		local a = a0 + (a1 - a0) * i / n
		local p = c + P.compass(a) * r
		p = Vector3.new(p.X, y, p.Z)
		if prev then P.path(parent, prev, p, w, color, material) end
		prev = p
	end
end

---------------------------------------------------------------------------
-- Уличные мелочи
---------------------------------------------------------------------------
function P.lamp(parent, pos, color, h)
	h = h or 12
	local m = B.model(parent, "Lamp")
	B.vcyl(m, "Base", 0.8, 1.8, CFrame.new(pos + Vector3.new(0, 0.4, 0)), C.metalDark, Enum.Material.Metal)
	B.vcyl(m, "Pole", h, 0.6, CFrame.new(pos + Vector3.new(0, h / 2, 0)), C.metal, Enum.Material.Metal)
	B.vcyl(m, "Cap", 0.5, 2.6, CFrame.new(pos + Vector3.new(0, h + 1.6, 0)), C.metalDark, Enum.Material.Metal)
	local head = B.ball(m, "Glow", 2, CFrame.new(pos + Vector3.new(0, h + 0.6, 0)), color or C.labTeal, Enum.Material.Neon)
	head.CastShadow = false
	B.light(head, "PointLight", { Range = 20, Brightness = 1.3, Color = color or C.labTeal })
	return m
end

function P.bench(parent, cf)
	local m = B.model(parent, "Bench")
	B.part(m, "Seat", Vector3.new(6, 0.4, 1.8), cf * CFrame.new(0, 1.6, 0), C.wood, Enum.Material.WoodPlanks)
	B.part(m, "Back", Vector3.new(6, 1.6, 0.3), cf * CFrame.new(0, 2.8, 0.85) * CFrame.Angles(math.rad(-10), 0, 0), C.wood, Enum.Material.WoodPlanks)
	for _, x in ipairs({ -2.5, 2.5 }) do
		B.part(m, "Leg", Vector3.new(0.4, 1.4, 1.6), cf * CFrame.new(x, 0.7, 0), C.metalDark, Enum.Material.Metal)
	end
	return m
end

-- забор от a до b: столбы через step, две перекладины
function P.fence(parent, a, b, h, color, material, step)
	local m = B.model(parent, "Fence")
	h, step = h or 4, step or 8
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	if len < 0.5 then return m end
	local n = math.max(1, math.floor(len / step + 0.5))
	for i = 0, n do
		local p = a:Lerp(b, i / n)
		B.part(m, "Post", Vector3.new(0.7, h + 0.4, 0.7), CFrame.new(p + Vector3.new(0, (h + 0.4) / 2, 0)), color, material)
	end
	local cf = CFrame.lookAt((a + b) / 2, (a + b) / 2 + flat)
	for _, y in ipairs({ h * 0.45, h * 0.9 }) do
		B.part(m, "Rail", Vector3.new(0.35, 0.45, len), cf * CFrame.new(0, y, 0), color, material)
	end
	return m
end

-- табличка-надпись на грани детали: заголовок и подпись
function P.board(part, face, title, sub, textColor, bgColor)
	local g = Instance.new("SurfaceGui")
	g.Name = "Board"
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 30
	g.LightInfluence = 0.6
	g.Parent = part
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = bgColor and 0 or 1
	f.BackgroundColor3 = bgColor or Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.Parent = g
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Size = sub and UDim2.fromScale(0.94, 0.58) or UDim2.fromScale(0.94, 0.84)
	t.Position = UDim2.fromScale(0.03, sub and 0.06 or 0.08)
	t.Text = title
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = textColor or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.4
	t.Parent = f
	if sub then
		local s = Instance.new("TextLabel")
		s.Name = "Sub"
		s.BackgroundTransparency = 1
		s.Size = UDim2.fromScale(0.9, 0.3)
		s.Position = UDim2.fromScale(0.05, 0.64)
		s.Text = sub
		s.TextScaled = true
		s.Font = Enum.Font.GothamBold
		s.TextColor3 = textColor or Color3.new(1, 1, 1)
		s.TextTransparency = 0.1
		s.Parent = f
	end
	return g
end

-- указатель на двух столбах; cf — низ по центру, лицо — к −Z
function P.signpost(parent, cf, title, sub, accent, w, h)
	w, h = w or 12, h or 4
	local m = B.model(parent, "Sign")
	for _, x in ipairs({ -w / 2 + 0.8, w / 2 - 0.8 }) do
		B.part(m, "Post", Vector3.new(0.8, h + 4, 0.8), cf * CFrame.new(x, (h + 4) / 2, 0), C.woodDark, Enum.Material.Wood)
	end
	local board = B.part(m, "Board", Vector3.new(w, h, 0.6), cf * CFrame.new(0, 4 + h / 2 - 0.4, 0), C.wood, Enum.Material.WoodPlanks)
	B.part(m, "Trim", Vector3.new(w + 0.4, 0.4, 0.8), cf * CFrame.new(0, 4 + h - 0.2, 0), accent or C.labTeal, Enum.Material.Neon)
	P.board(board, Enum.NormalId.Front, title, sub)
	P.board(board, Enum.NormalId.Back, title, sub)
	return m
end

-- арка-въезд с надписью (cf — низ по центру, проход вдоль Z)
function P.arch(parent, cf, w, h, color, accent, title, sub, material)
	local m = B.model(parent, "Arch")
	material = material or Enum.Material.Slate
	for _, x in ipairs({ -w / 2 - 2, w / 2 + 2 }) do
		B.part(m, "Pillar", Vector3.new(4, h, 4), cf * CFrame.new(x, h / 2, 0), color, material)
		B.part(m, "PillarCap", Vector3.new(5, 1, 5), cf * CFrame.new(x, h + 0.5, 0), color, material)
		local orb = B.ball(m, "Orb", 2.4, cf * CFrame.new(x, h + 2.2, 0), accent, Enum.Material.Neon)
		B.light(orb, "PointLight", { Range = 16, Brightness = 1.5, Color = accent })
		B.tag(orb, "Pulse", { Speed = 1.5 })
	end
	local beam = B.part(m, "Beam", Vector3.new(w + 8, 6, 2), cf * CFrame.new(0, h - 3, 0), color, material)
	B.part(m, "Stripe", Vector3.new(w + 8.2, 0.5, 2.2), cf * CFrame.new(0, h - 5.6, 0), accent, Enum.Material.Neon)
	P.board(beam, Enum.NormalId.Front, title, sub)
	P.board(beam, Enum.NormalId.Back, title, sub)
	return m
end

---------------------------------------------------------------------------
-- Природа
---------------------------------------------------------------------------
-- камень из 2–3 повёрнутых глыб; s — примерный размер
function P.rock(parent, pos, s, rng, color, material)
	local m = B.model(parent, "Rock")
	color = color or C.stone
	material = material or Enum.Material.Slate
	local n = rng:int(1, 3)
	for i = 1, n do
		local k = i == 1 and 1 or rng:range(0.45, 0.7)
		local size = Vector3.new(s * k * rng:range(0.8, 1.3), s * k * rng:range(0.5, 0.9), s * k * rng:range(0.8, 1.2))
		local off = i == 1 and Vector3.zero or Vector3.new(rng:range(-s, s) * 0.5, 0, rng:range(-s, s) * 0.5)
		local cf = CFrame.new(pos + off + Vector3.new(0, size.Y * 0.32, 0))
			* CFrame.Angles(rng:range(-0.25, 0.25), rng:angle(), rng:range(-0.25, 0.25))
		local shade = rng:range(0.85, 1.1)
		B.part(m, "Stone", size, cf, Color3.new(math.min(1, color.R * shade), math.min(1, color.G * shade), math.min(1, color.B * shade)), material)
	end
	return m
end

-- инопланетное дерево: изогнутый ствол и шары листвы
P.TreePalettes = {
	{ rgb(64, 200, 170), rgb(40, 160, 150), rgb(120, 230, 190) },   -- бирюзовое
	{ rgb(220, 110, 200), rgb(170, 80, 190), rgb(250, 160, 220) },  -- розовое
	{ rgb(150, 210, 70), rgb(100, 170, 60), rgb(190, 240, 110) },   -- салатовое
}
function P.tree(parent, pos, rng, scale, palette, trunkColor)
	local m = B.model(parent, "Tree")
	scale = scale or 1
	palette = palette or rng:pick(P.TreePalettes)
	local h = rng:range(12, 18) * scale
	local d = rng:range(1.4, 2) * scale
	local p = pos
	local dir = Vector3.new(rng:range(-0.3, 0.3), 1, rng:range(-0.3, 0.3)).Unit
	local segs = 3
	for i = 1, segs do
		local q = p + dir * (h / segs)
		B.between(m, "Trunk", p, q, d * (1.15 - i * 0.15), trunkColor or C.woodDark, Enum.Material.Wood, true)
		B.ball(m, "Knot", d * (1.15 - i * 0.15), CFrame.new(q), trunkColor or C.woodDark, Enum.Material.Wood)
		p = q
		dir = (dir + Vector3.new(rng:range(-0.35, 0.35), 0, rng:range(-0.35, 0.35))).Unit
	end
	local n = rng:int(3, 5)
	for i = 1, n do
		local r = rng:range(5, 8) * scale
		local off = i == 1 and Vector3.new(0, r * 0.3, 0)
			or Vector3.new(rng:range(-1, 1) * r * 0.8, rng:range(-0.2, 0.5) * r, rng:range(-1, 1) * r * 0.8)
		B.ellipsoid(m, "Leaves", Vector3.new(r * 2, r * 1.5, r * 2), CFrame.new(p + off), palette[(i - 1) % #palette + 1], Enum.Material.Grass)
	end
	return m, p
end

-- клумба: тонкие стебли с яркими головками
function P.flowers(parent, center, rng, n, colors, radius)
	local m = B.model(parent, "Flowers")
	for _ = 1, n do
		local a, r = rng:angle(), rng:range(0, radius or 4)
		local p = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local h = rng:range(0.8, 2)
		B.part(m, "Stem", Vector3.new(0.15, h, 0.15), CFrame.new(p + Vector3.new(0, h / 2, 0)), rgb(70, 150, 60), Enum.Material.Grass,
			{ CanCollide = false, CastShadow = false })
		local head = B.ball(m, "Bloom", rng:range(0.5, 0.9), CFrame.new(p + Vector3.new(0, h, 0)), rng:pick(colors),
			rng:chance(0.3) and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		head.CanCollide = false
		head.CastShadow = false
	end
	return m
end

-- мёртвое дерево: тёмный ствол, кривые ветки, по желанию — свисающий мох
function P.deadTree(parent, pos, rng, scale, color, moss)
	local m = B.model(parent, "DeadTree")
	scale = scale or 1
	color = color or rgb(70, 62, 55)
	local h = rng:range(10, 16) * scale
	local d = rng:range(1.4, 2.2) * scale
	local top = pos + Vector3.new(rng:range(-1.5, 1.5), h, rng:range(-1.5, 1.5)) * Vector3.new(scale, 1, scale)
	B.between(m, "Trunk", pos - Vector3.new(0, 1, 0), top, d, color, M_WOOD, true)
	B.ball(m, "Root", d * 1.6, CFrame.new(pos + Vector3.new(0, 0.2, 0)), color, M_WOOD)
	local n = rng:int(2, 4)
	for _ = 1, n do
		local t = rng:range(0.45, 0.95)
		local from = (pos):Lerp(top, t)
		local a = rng:angle()
		local len = rng:range(3, 6) * scale
		local to = from + Vector3.new(math.cos(a) * len, rng:range(1, 3.5) * scale, math.sin(a) * len)
		B.between(m, "Branch", from, to, d * 0.45, color, M_WOOD, true)
		if rng:chance(0.5) then
			local a2 = a + rng:range(-1, 1)
			B.between(m, "Twig", to, to + Vector3.new(math.cos(a2) * len * 0.5, len * 0.4, math.sin(a2) * len * 0.5), d * 0.25, color, M_WOOD, true)
		end
		if moss then
			for _ = 1, rng:int(1, 3) do
				local p = from:Lerp(to, rng:range(0.3, 1))
				local l = rng:range(1.5, 4)
				B.part(m, "Moss", Vector3.new(0.25, l, 0.5), CFrame.new(p - Vector3.new(0, l / 2, 0)), moss, Enum.Material.Grass,
					{ CanCollide = false, CastShadow = false })
			end
		end
	end
	return m
end

---------------------------------------------------------------------------
-- Кристаллы
---------------------------------------------------------------------------
-- один кристалл: стеклянная оболочка, светящаяся сердцевина и заострённая верхушка из двух клиньев
function P.crystal(parent, base, dir, h, w, color)
	local up = dir.Unit
	local right = up:Cross(Vector3.new(0.31, 0, 0.95))
	if right.Magnitude < 0.01 then right = Vector3.xAxis end
	right = right.Unit
	local back = right:Cross(up)
	local function frame(p) return CFrame.fromMatrix(p, right, up, back) end
	local shell = B.part(parent, "Crystal", Vector3.new(w, h, w), frame(base + up * (h / 2)), color, Enum.Material.Glass,
		{ Transparency = 0.25, Reflectance = 0.15 })
	B.part(parent, "Core", Vector3.new(w * 0.45, h * 0.92, w * 0.45), frame(base + up * (h * 0.47)), color, Enum.Material.Neon,
		{ CanCollide = false, CastShadow = false })
	local tipH = w * 1.1
	local tipC = frame(base + up * (h + tipH / 2))
	B.wedge(parent, "Tip", Vector3.new(w, tipH, w / 2), tipC * CFrame.new(0, 0, -w / 4), color, Enum.Material.Glass,
		{ Transparency = 0.25, Reflectance = 0.15 })
	B.wedge(parent, "Tip", Vector3.new(w, tipH, w / 2), tipC * CFrame.new(0, 0, w / 4) * CFrame.Angles(0, math.pi, 0), color, Enum.Material.Glass,
		{ Transparency = 0.25, Reflectance = 0.15 })
	return shell
end

-- гнездо кристаллов: size — высота самого большого
function P.crystalCluster(parent, pos, size, rng, colors, withLight)
	local m = B.model(parent, "Crystals")
	local color = rng:pick(colors)
	local n = rng:int(4, 7)
	for i = 1, n do
		local a = rng:angle()
		local r = i == 1 and 0 or rng:range(0.3, 1) * size * 0.35
		local base = pos + Vector3.new(math.cos(a) * r, -0.6, math.sin(a) * r)
		local tilt = i == 1 and rng:range(0, 0.15) or rng:range(0.25, 0.7)
		local dir = Vector3.new(math.cos(a) * tilt, 1, math.sin(a) * tilt)
		local h = (i == 1 and 1 or rng:range(0.35, 0.75)) * size
		P.crystal(m, base, dir, h, h * rng:range(0.2, 0.28), rng:chance(0.8) and color or rng:pick(colors))
	end
	B.ball(m, "Base", size * 0.45, CFrame.new(pos - Vector3.new(0, size * 0.12, 0)), C.stoneDark, Enum.Material.Slate)
	if withLight then
		local glow = B.marker(m, "Glow", Vector3.new(1, 1, 1), CFrame.new(pos + Vector3.new(0, size * 0.6, 0)))
		B.light(glow, "PointLight", { Range = math.max(14, size * 2.2), Brightness = 1.6, Color = color })
	end
	return m
end

---------------------------------------------------------------------------
-- Лабораторное
---------------------------------------------------------------------------
-- бочка; toxic — светящаяся крышка
function P.barrel(parent, cf, color, toxic)
	local m = B.model(parent, "Barrel")
	B.vcyl(m, "Body", 4, 3, cf * CFrame.new(0, 2, 0), color, Enum.Material.Metal)
	for _, y in ipairs({ 0.9, 3.1 }) do
		B.vcyl(m, "Rim", 0.25, 3.15, cf * CFrame.new(0, y, 0), C.metalDark, Enum.Material.Metal)
	end
	if toxic then
		local lid = B.vcyl(m, "Goo", 0.2, 2.6, cf * CFrame.new(0, 4.05, 0), C.toxic, Enum.Material.Neon)
		B.light(lid, "PointLight", { Range = 8, Brightness = 1, Color = C.toxic })
	end
	return m
end

function P.crate(parent, cf, s, color)
	local m = B.model(parent, "Crate")
	s = s or 4
	color = color or C.wood
	B.part(m, "Box", Vector3.new(s, s, s), cf * CFrame.new(0, s / 2, 0), color, Enum.Material.WoodPlanks)
	for _, y in ipairs({ 0.2, s - 0.2 }) do
		B.part(m, "Band", Vector3.new(s + 0.1, 0.35, s + 0.1), cf * CFrame.new(0, y, 0), C.woodDark, Enum.Material.Wood)
	end
	return m
end

-- стеклянная колба с жидкостью и «зародышем» мутанта внутри
function P.tank(parent, pos, h, d, liquid, withCreature)
	local m = B.model(parent, "Tank")
	B.vcyl(m, "Base", 1.6, d + 1.2, CFrame.new(pos + Vector3.new(0, 0.8, 0)), C.metalDark, Enum.Material.DiamondPlate)
	B.vcyl(m, "Liquid", h - 0.6, d - 0.5, CFrame.new(pos + Vector3.new(0, 1.6 + (h - 0.6) / 2, 0)), liquid, Enum.Material.Glass,
		{ Transparency = 0.35 })
	B.vcyl(m, "Glass", h, d, CFrame.new(pos + Vector3.new(0, 1.6 + h / 2, 0)), rgb(210, 240, 255), Enum.Material.Glass,
		{ Transparency = 0.7 })
	B.vcyl(m, "Cap", 1.2, d + 0.8, CFrame.new(pos + Vector3.new(0, 1.6 + h + 0.6, 0)), C.metal, Enum.Material.Metal)
	local glow = B.vcyl(m, "Ring", 0.3, d + 0.9, CFrame.new(pos + Vector3.new(0, 1.7, 0)), liquid, Enum.Material.Neon)
	B.light(glow, "PointLight", { Range = 12, Brightness = 1.2, Color = liquid })
	if withCreature then
		local c = B.ball(m, "Embryo", d * 0.45, CFrame.new(pos + Vector3.new(0, 1.6 + h * 0.5, 0)), rgb(40, 40, 60), Enum.Material.SmoothPlastic,
			{ CanCollide = false, Transparency = 0.2 })
		B.tag(c, "Bob", { Height = 0.6, Period = 3 })
	end
	local bubbles = B.marker(m, "Bubbles", Vector3.new(d * 0.6, 0.2, d * 0.6), CFrame.new(pos + Vector3.new(0, 2, 0)))
	B.particles(bubbles, {
		Color = ColorSequence.new(Color3.new(1, 1, 1)), Size = NumberSequence.new(0.25, 0.1),
		Transparency = NumberSequence.new(0.3, 1), Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(1.5, 3), Rate = 4, EmissionDirection = Enum.NormalId.Top, LightEmission = 0.4,
	})
	return m
end

-- труба между точками с фланцами на концах
function P.pipe(parent, a, b, d, color)
	local m = B.model(parent, "Pipe")
	B.between(m, "Pipe", a, b, d, color or C.metal, Enum.Material.Metal, true)
	for _, p in ipairs({ a, b }) do B.ball(m, "Joint", d * 1.3, CFrame.new(p), C.metalDark, Enum.Material.Metal) end
	return m
end

-- светлячки / искры: невидимая область с частицами
function P.motes(parent, cf, size, color, rate, name)
	local box = B.marker(parent, name or "Motes", size, cf)
	B.particles(box, {
		Color = ColorSequence.new(color), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35),
			NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.1, 0.6), Lifetime = NumberRange.new(3, 6), Speed = NumberRange.new(0.3, 1),
		SpreadAngle = Vector2.new(180, 180), Rate = rate or 8, LightEmission = 1, Drag = 1,
		EmissionDirection = Enum.NormalId.Top,
	})
	return box
end

---------------------------------------------------------------------------
-- Точки появления ингредиентов
---------------------------------------------------------------------------
-- n невидимых меток в прямоугольнике зоны; сервер игры позже будет создавать на них ингредиенты
function P.spawnPoints(folder, rng, occ, x0, x1, z0, z1, y, n, zoneId)
	local made = 0
	for i = 1, n do
		local x, z = occ:find(rng, x0, x1, z0, z1, 3, 40)
		if x then
			occ:add(x, z, 4)
			local mk = B.marker(folder, "Spawn", Vector3.new(2, 1, 2), CFrame.new(x, y + 0.5, z))
			B.attrs(mk, { Zone = zoneId, Index = i })
			made = made + 1
		end
	end
	return made
end

return P
