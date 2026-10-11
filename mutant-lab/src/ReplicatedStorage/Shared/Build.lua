-- Помощники постройки (сервер и клиент): детали, клинья, цилиндры, стены с проёмами,
-- свет, подсказки ProximityPrompt, надписи, текстуры. Все детали по умолчанию закреплены (Anchored).
local B = {}

local function apply(o, props)
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then o[k] = v end
		end
	end
end
B.apply = apply

-- цвет: Color3, "#RRGGBB" или r, g, b (0..255)
function B.color(r, g, b)
	if typeof(r) == "Color3" then return r end
	if type(r) == "string" then return Color3.fromHex(r) end
	return Color3.fromRGB(r, g, b)
end

-- ID ассета из Config: "" -> "", "123" -> "rbxassetid://123", "rbxasset://..." -> как есть
function B.asset(id)
	if id == nil or id == "" then return "" end
	if tonumber(id) then return "rbxassetid://" .. tostring(id) end
	return tostring(id)
end

-- материал по имени с запасным вариантом (новые материалы вроде Carpet, Plaster, RoofShingles,
-- CeramicTiles, Leather, Rubber, Cardboard, ClayRoofTiles есть не во всех версиях)
function B.mat(name, fallback)
	local ok, m = pcall(function() return Enum.Material[name] end)
	if ok and m then return m end
	return fallback or Enum.Material.SmoothPlastic
end

function B.make(class, props, parent)
	local o = Instance.new(class)
	apply(o, props)
	o.Parent = parent or (props and props.Parent)
	return o
end

function B.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name or "Model"
	m.Parent = parent
	return m
end

function B.folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name or "Folder"
	f.Parent = parent
	return f
end

local function basePart(class, parent, name, size, cf, color, material, props)
	local p = Instance.new(class)
	p.Name = name or class
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	if color then p.Color = B.color(color) end
	p.Material = material or Enum.Material.SmoothPlastic
	apply(p, props)
	p.Parent = parent
	return p
end

-- прямоугольная деталь: size — Vector3, cf — CFrame центра
function B.part(parent, name, size, cf, color, material, props)
	return basePart("Part", parent, name, size, cf, color, material, props)
end

-- клин: наклонная грань идёт от верхнего заднего (+Z) ребра к нижнему переднему (−Z)
function B.wedge(parent, name, size, cf, color, material, props)
	return basePart("WedgePart", parent, name, size, cf, color, material, props)
end

function B.cornerWedge(parent, name, size, cf, color, material, props)
	return basePart("CornerWedgePart", parent, name, size, cf, color, material, props)
end

-- цилиндр: ось вдоль X у cf; length — длина, d — диаметр
function B.cyl(parent, name, length, d, cf, color, material, props)
	local p = basePart("Part", parent, name, Vector3.new(length, d, d), cf, color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- вертикальный цилиндр (ось вверх) с центром в cf
function B.vcyl(parent, name, height, d, cf, color, material, props)
	return B.cyl(parent, name, height, d, cf * CFrame.Angles(0, 0, math.rad(90)), color, material, props)
end

function B.ball(parent, name, d, cf, color, material, props)
	local p = basePart("Part", parent, name, Vector3.new(d, d, d), cf, color, material, props)
	p.Shape = Enum.PartType.Ball
	return p
end

-- невидимая служебная деталь (зоны, точки появления, якоря)
function B.marker(parent, name, size, cf, props)
	local p = basePart("Part", parent, name, size or Vector3.new(1, 1, 1), cf, nil, nil, props)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	apply(p, props)
	return p
end

-- Стена от точки a до точки b (обе — низ стены на полу), высота h, толщина th.
-- openings: { { at = расстояние от a до центра проёма, w = ширина, y0 = низ проёма, y1 = верх проёма }, ... }
-- Собирает стену из кусков вокруг проёмов (двери, окна). Возвращает Model.
-- Совет: внешние стены не тоньше 1 стада, иначе свет «протекает» сквозь них.
function B.wall(parent, name, a, b, h, th, color, material, openings, props)
	local m = B.model(parent, name)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	if len < 0.01 then return m end
	local frame = CFrame.fromMatrix(a, flat.Unit, Vector3.yAxis)
	local function seg(x0, x1, y0, y1)
		if x1 - x0 < 0.02 or y1 - y0 < 0.02 then return end
		B.part(m, "Wall", Vector3.new(x1 - x0, y1 - y0, th), frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0), color, material, props)
	end
	local list = {}
	for _, o in ipairs(openings or {}) do table.insert(list, o) end
	table.sort(list, function(p, q) return p.at < q.at end)
	local cursor = 0
	for _, o in ipairs(list) do
		local x0, x1 = o.at - o.w / 2, o.at + o.w / 2
		if x0 > cursor then seg(cursor, x0, 0, h) end
		if (o.y0 or 0) > 0 then seg(math.max(x0, cursor), x1, 0, o.y0) end
		if (o.y1 or h) < h then seg(math.max(x0, cursor), x1, o.y1, h) end
		cursor = math.max(cursor, x1)
	end
	seg(cursor, len, 0, h)
	return m
end

-- источник света: class = "PointLight" | "SpotLight" | "SurfaceLight"; тени выключены по умолчанию
-- (на открытой карте сотни фонарей — тени от каждого слишком дороги)
function B.light(parent, class, props)
	local l = Instance.new(class)
	l.Shadows = false
	apply(l, props)
	l.Parent = parent
	return l
end

-- подсказка взаимодействия (клавиша E по умолчанию)
function B.prompt(parent, name, action, object, props)
	local p = Instance.new("ProximityPrompt")
	p.Name = name or "Prompt"
	p.ActionText = action or ""
	p.ObjectText = object or ""
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	apply(p, props)
	p.Parent = parent
	return p
end

-- надпись на грани детали (вывески, таблички, экраны)
function B.sign(part, face, text, props, guiProps)
	local g = Instance.new("SurfaceGui")
	g.Name = "Sign"
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 1
	apply(g, guiProps)
	g.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text or ""
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.new(1, 1, 1)
	apply(l, props)
	l.Parent = g
	return g, l
end

-- повторяющаяся текстура (обои, плитка); id из Config.Images; пустой id — ничего не делаем
function B.texture(part, face, id, studsU, studsV, props)
	local url = B.asset(id)
	if url == "" then return nil end
	local t = Instance.new("Texture")
	t.Texture = url
	t.Face = face or Enum.NormalId.Front
	t.StudsPerTileU = studsU or 4
	t.StudsPerTileV = studsV or 4
	apply(t, props)
	t.Parent = part
	return t
end

-- одиночная картинка (плакат, лицо)
function B.decal(part, face, id, props)
	local url = B.asset(id)
	if url == "" then return nil end
	local d = Instance.new("Decal")
	d.Texture = url
	d.Face = face or Enum.NormalId.Front
	apply(d, props)
	d.Parent = part
	return d
end

function B.weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
	return w
end

function B.attrs(inst, t)
	for k, v in pairs(t) do inst:SetAttribute(k, v) end
	return inst
end

-- CFrame: позиция + поворот вокруг вертикали в градусах
function B.at(x, y, z, yawDeg)
	return CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
end

-- эллипсоид (шляпки грибов, капли слизи, тарелка): деталь с SpecialMesh Sphere, растянутым по размеру детали.
-- Столкновения у такой детали — по её коробке, поэтому на шляпку гриба можно запрыгнуть.
function B.ellipsoid(parent, name, size, cf, color, material, props)
	local p = basePart("Part", parent, name, size, cf, color, material, props)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

-- брус от точки a до точки b (трубы, балки, ветки): cyl = true — цилиндр, иначе квадратное сечение
function B.between(parent, name, a, b, d, color, material, cyl, props)
	local len = (b - a).Magnitude
	if len < 0.01 then return nil end
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b)
	if cyl then
		return B.cyl(parent, name, len, d, cf * CFrame.Angles(0, math.rad(90), 0), color, material, props)
	end
	return B.part(parent, name, Vector3.new(d, d, len), cf, color, material, props)
end

-- кольцо из n брусков по окружности радиуса r вокруг cf (ось кольца — UpVector у cf).
-- skip(угол в градусах) -> true пропускает сегмент (проходы в стенах).
function B.ring(parent, name, cf, r, n, h, th, color, material, skip, props)
	local m = B.model(parent, name)
	local seg = 2 * math.pi * r / n
	for i = 0, n - 1 do
		local a = 360 * i / n
		if not (skip and skip(a)) then
			local c = cf * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0, -r)
			B.part(m, name, Vector3.new(seg * 1.04, h, th), c, color, material, props)
		end
	end
	return m
end

-- метка для клиентских анимаций (Spin / Bob / Pulse) — см. MapFx
function B.tag(inst, tag, attrs)
	inst:AddTag(tag)
	if attrs then B.attrs(inst, attrs) end
	return inst
end

-- частицы: props поверх разумных значений по умолчанию
function B.particles(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 0.6
	e.Rate = 6
	apply(e, props)
	e.Parent = parent
	return e
end

-- плавающая надпись над деталью
function B.billboard(part, text, color, offsetY, size, maxDist)
	local g = Instance.new("BillboardGui")
	g.Name = "Label"
	g.Size = size or UDim2.fromOffset(260, 60)
	g.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	g.MaxDistance = maxDist or 150
	g.LightInfluence = 0
	g.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.2
	l.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
	l.Parent = g
	return g, l
end

return B
