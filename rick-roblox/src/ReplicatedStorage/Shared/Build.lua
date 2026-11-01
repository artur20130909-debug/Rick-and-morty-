-- Помощники постройки (сервер и клиент): детали, клинья, цилиндры, шары, стены с проёмами,
-- свет, подсказки ProximityPrompt, надписи. Все детали по умолчанию закреплены (Anchored)
-- и сделаны из SmoothPlastic — это основа «мультяшного» стиля.
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

-- чуть светлее/темнее (k > 1 — светлее), чтобы большие плоскости не были одного цвета
function B.shade(c, k)
	c = B.color(c)
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

-- ID ассета из Config: "" -> "", "123" -> "rbxassetid://123", "rbxasset://..." -> как есть
function B.asset(id)
	if id == nil or id == "" then return "" end
	if tonumber(id) then return "rbxassetid://" .. tostring(id) end
	return tostring(id)
end

-- материал по имени с запасным вариантом
function B.mat(name, fallback)
	local ok, m = pcall(function() return Enum.Material[name] end)
	if ok and m then return m end
	return fallback or Enum.Material.SmoothPlastic
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

-- клин: вертикальная грань сзади (+Z), скат смотрит вперёд-вверх (−Z)
function B.wedge(parent, name, size, cf, color, material, props)
	return basePart("WedgePart", parent, name, size, cf, color, material, props)
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

-- невидимая служебная деталь (зоны, точки, якоря)
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

-- Конструктор мебели: детали задаются в локальных координатах предмета (центр детали).
-- local P = B.kit(model, cf)
-- P(имя, sx, sy, sz, x, y, z, цвет, материал, свойства[, поворот CFrame])
-- P.cyl(имя, длина, d, x, y, z, цвет, ...)    — ось X; P.vcyl — ось Y; P.ball(имя, d, x, y, z, цвет, ...)
-- P.wedge(имя, sx, sy, sz, x, y, z, цвет, ...)
function B.kit(model, cf)
	local P = {}
	local function at(x, y, z, rot)
		local c = cf * CFrame.new(x, y, z)
		if rot then c = c * rot end
		return c
	end
	P.at = at
	P.cf = cf
	setmetatable(P, {
		__call = function(_, name, sx, sy, sz, x, y, z, color, material, props, rot)
			return B.part(model, name, Vector3.new(sx, sy, sz), at(x, y, z, rot), color, material, props)
		end,
	})
	function P.wedge(name, sx, sy, sz, x, y, z, color, material, props, rot)
		return B.wedge(model, name, Vector3.new(sx, sy, sz), at(x, y, z, rot), color, material, props)
	end
	function P.cyl(name, length, d, x, y, z, color, material, props, rot)
		return B.cyl(model, name, length, d, at(x, y, z, rot), color, material, props)
	end
	function P.vcyl(name, height, d, x, y, z, color, material, props, rot)
		return B.vcyl(model, name, height, d, at(x, y, z, rot), color, material, props)
	end
	function P.ball(name, d, x, y, z, color, material, props, rot)
		return B.ball(model, name, d, at(x, y, z, rot), color, material, props)
	end
	return P
end

-- Стена от точки a до точки b (низ стены), высота h, толщина th.
-- openings: { { at = расстояние от a до центра проёма, w = ширина, y0 = низ, y1 = верх }, ... }
-- Возвращает Model; куски стены называются "Wall".
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

-- источник света: class = "PointLight" | "SpotLight" | "SurfaceLight"
function B.light(parent, class, props)
	local l = Instance.new(class)
	l.Shadows = true
	apply(l, props)
	l.Parent = parent
	return l
end

-- подсказка взаимодействия (клавиша E). Стиль Custom — рисуем свою (Client/Prompts).
function B.prompt(parent, name, action, object, props)
	local p = Instance.new("ProximityPrompt")
	p.Name = name or "Prompt"
	p.ActionText = action or ""
	p.ObjectText = object or ""
	p.MaxActivationDistance = 7
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Style = Enum.ProximityPromptStyle.Custom
	apply(p, props)
	p.Parent = parent
	return p
end

-- надпись на грани детали (вывески, плакаты, экраны). Возвращает SurfaceGui и TextLabel.
function B.sign(part, face, text, props, guiProps)
	local g = Instance.new("SurfaceGui")
	g.Name = "Sign"
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 50
	g.LightInfluence = 1
	apply(g, guiProps)
	g.Parent = part
	local l = Instance.new("TextLabel")
	l.Name = "Text"
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

-- пустой SurfaceGui на грани (для рисунков из Frame)
function B.surface(part, face, ppsu, guiProps)
	local g = Instance.new("SurfaceGui")
	g.Name = "Surface"
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppsu or 50
	g.LightInfluence = 1
	g.ClipsDescendants = true
	apply(g, guiProps)
	g.Parent = part
	return g
end

-- прямоугольник/круг/текст внутри GUI в долях (x, y, w, h от 0 до 1)
function B.rect(parent, x, y, w, h, color, props)
	local f = Instance.new("Frame")
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = B.color(color)
	f.BorderSizePixel = 0
	apply(f, props)
	f.Parent = parent
	return f
end
function B.circle(parent, x, y, w, h, color, props)
	local f = B.rect(parent, x, y, w, h, color, props)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	return f
end
function B.text(parent, x, y, w, h, text, color, font, props)
	local l = Instance.new("TextLabel")
	l.Position = UDim2.fromScale(x, y)
	l.Size = UDim2.fromScale(w, h)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = font or Enum.Font.GothamBlack
	l.TextColor3 = B.color(color or "#ffffff")
	apply(l, props)
	l.Parent = parent
	return l
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

-- предмет обводится контуром (Client/Outline выбирает ближайшие и вешает Highlight)
function B.outline(model)
	model:SetAttribute("Outline", true)
	return model
end

-- CFrame: позиция + поворот вокруг вертикали в градусах
function B.at(x, y, z, yawDeg)
	return CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
end

return B
