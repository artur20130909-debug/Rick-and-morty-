----------------------------------------------------------------------
-- ДЕТАЛИ, ТРЕУГОЛЬНИКИ, «ХОЛСТ» ДЛЯ РИСОВАНИЯ ДЕТАЛЯМИ
----------------------------------------------------------------------

-- o: neon, wedge, shape ("ball" = эллипсоид, "cyl" = цилиндр по оси X), alpha, material
local function newPart(parent, size, color, cf, o)
	o = o or {}
	local p = Instance.new(o.wedge and "WedgePart" or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.neon then
		p.Material = Enum.Material.Neon
	else
		p.Material = o.material or Enum.Material.SmoothPlastic
	end
	if o.shape == "ball" then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	elseif o.shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Size = size
	p.Color = color
	p.Transparency = o.alpha or 0
	if cf then
		p.CFrame = cf
	end
	p.Parent = parent
	return p
end

-- аниме-контур (и лёгкая заливка) для модели
local function outline(model, fillColor, fillT, lineColor)
	if not CONFIG.OUTLINES then
		return nil
	end
	local h = Instance.new("Highlight")
	h.FillColor = fillColor or C.white
	h.FillTransparency = fillT or 1
	h.OutlineColor = lineColor or C.ink
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	return h
end

-- Треугольник из двух клиньев (способ EgoMoose). Возвращает две CFrame и размеры.
local function triCFs(a, b, c)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local n = ac:Cross(ab)
	if n.Magnitude < 1e-10 or bc.Magnitude < 1e-6 then
		return nil
	end
	local right = n.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = abs(ab:Dot(up))
	if height < 1e-5 then
		return nil
	end
	return CFrame.fromMatrix((a + b) / 2, right, up, back), height, abs(ab:Dot(back)),
		CFrame.fromMatrix((a + c) / 2, -right, up, -back), abs(ac:Dot(back))
end

-- maker(size, color, cf, o) создаёт деталь; тут — треугольник толщиной thick
local function makeTri(maker, a, b, c, color, thick, o)
	local cf1, h, d1, cf2, d2 = triCFs(a, b, c)
	if not cf1 then
		return
	end
	local opts = { wedge = true, neon = o and o.neon, alpha = o and o.alpha, material = o and o.material, tag = o and o.tag }
	if d1 > 1e-4 then
		maker(V3(thick, h, d1), color, cf1, opts)
	end
	if d2 > 1e-4 then
		maker(V3(thick, h, d2), color, cf2, opts)
	end
end

-- Холст: рисуем плоские фигуры на плоскости frame. x вправо (для зрителя), y вверх,
-- слои растут к зрителю. k — масштаб, d — шаг между слоями.
local Canvas = {}
Canvas.__index = Canvas

function Canvas.new(maker, frame, k, d)
	return setmetatable({ maker = maker, frame = frame, k = k or 1, d = d or 0.003 }, Canvas)
end

-- плоскость смотрит на зрителя своей стороной -Z, поэтому «вправо для зрителя» = -X
function Canvas:local3(p, layer)
	return V3(-p[1] * self.k, p[2] * self.k, -(layer or 0) * self.d)
end

function Canvas:ellipse(x, y, rx, ry, color, layer, rot, o)
	o = o or {}
	local cf = self.frame * CF(-x * self.k, y * self.k, -(layer or 0) * self.d) * ANG(0, 0, -(rot or 0))
	return self.maker(V3(2 * rx * self.k, 2 * ry * self.k, self.d * 0.6), color, cf,
		{ shape = "ball", neon = o.neon, alpha = o.alpha, tag = o.tag or self.tag })
end

function Canvas:rect(x, y, w, h, color, layer, rot, o)
	o = o or {}
	local cf = self.frame * CF(-x * self.k, y * self.k, -(layer or 0) * self.d) * ANG(0, 0, -(rot or 0))
	return self.maker(V3(w * self.k, h * self.k, self.d * 0.6), color, cf, { neon = o.neon, alpha = o.alpha, tag = o.tag or self.tag })
end

function Canvas:tri(a, b, c, color, layer, o)
	local frame, maker = self.frame, self.maker
	if self.tag and not (o and o.tag) then
		o = { tag = self.tag, neon = o and o.neon, alpha = o and o.alpha }
	end
	makeTri(function(size, col, cf, opts)
		return maker(size, col, frame * cf, opts)
	end, self:local3(a, layer), self:local3(b, layer), self:local3(c, layer), color, self.d * 0.6, o)
end

-- выпуклый (или «звёздный») многоугольник: веер из центра
function Canvas:poly(pts, color, layer, o)
	local cx, cy = 0, 0
	for _, p in ipairs(pts) do
		cx, cy = cx + p[1], cy + p[2]
	end
	local c = { cx / #pts, cy / #pts }
	for i = 1, #pts do
		self:tri(c, pts[i], pts[i % #pts + 1], color, layer, o)
	end
end

-- полоса от кривой до горизонтали yEdge (маски над и под веками)
function Canvas:band(pts, yEdge, color, layer, o)
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		self:tri(a, b, { b[1], yEdge }, color, layer, o)
		self:tri(a, { b[1], yEdge }, { a[1], yEdge }, color, layer, o)
	end
end

-- штрих по точкам с меняющейся толщиной (сужается к концам)
function Canvas:stroke(pts, widths, color, layer, o)
	local n = #pts
	local L, R = {}, {}
	for i = 1, n do
		local p = pts[i]
		local a = pts[math.max(1, i - 1)]
		local b = pts[math.min(n, i + 1)]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local len = sqrt(dx * dx + dy * dy)
		if len < 1e-9 then
			len = 1e-9
		end
		local nx, ny = -dy / len, dx / len
		local w = widths
		if type(widths) == "table" then
			w = widths[i]
		end
		L[i] = { p[1] + nx * w / 2, p[2] + ny * w / 2 }
		R[i] = { p[1] - nx * w / 2, p[2] - ny * w / 2 }
	end
	for i = 1, n - 1 do
		self:tri(L[i], L[i + 1], R[i + 1], color, layer, o)
		self:tri(L[i], R[i + 1], R[i], color, layer, o)
	end
end

-- зеркально по x (для второго глаза)
local function mirror(pts)
	local out = {}
	for i, p in ipairs(pts) do
		out[i] = { -p[1], p[2] }
	end
	return out
end
