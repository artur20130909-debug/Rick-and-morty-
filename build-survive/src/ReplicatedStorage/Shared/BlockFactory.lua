-- Создаёт блок (деталь Roblox) по спецификации. Используется и сервером (настоящие блоки),
-- и клиентом (полупрозрачный «призрак» под курсором, иконки в магазине).
local Blocks = require(script.Parent.Blocks)

local BlockFactory = {}

export type BuildOptions = {
	ghost: boolean?,      -- призрак: без света, без столкновений
	preview: boolean?,    -- иконка в интерфейсе
	plotColor: Color3?,
}

local SMOOTH = Enum.SurfaceType.Smooth

local function newPart(className: string): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	return p
end

local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local METAL = Enum.Material.Metal

-- Цвет с множителем яркости: 1 — как есть, меньше 1 — темнее, больше — светлее
local function tinted(c: Color3, k: number): Color3
	return Color3.new(math.min(c.R * k, 1), math.min(c.G * k, 1), math.min(c.B * k, 1))
end

-- Декоративная деталь без сварки (её делают decor и rigPart). Не мешает лучам и столкновениям.
-- Tint — деталь окрашена в цвет блока с этим множителем и перекрашивается вместе с ним.
local function detail(parent: BasePart, cf: CFrame, size: Vector3, props: { [string]: any }): BasePart
	local d = newPart(props.className or "Part")
	d.Name = props.Name or "Decor"
	d.Size = size
	d.CFrame = parent.CFrame * cf
	d.CanCollide = false
	d.CanQuery = false
	d.CanTouch = false
	d.Massless = true
	d.Anchored = false
	d.Material = props.Material or Enum.Material.SmoothPlastic
	d.Color = props.Color or Color3.new(1, 1, 1)
	if props.Tint then
		d.Color = tinted(d.Color, props.Tint)
		d:SetAttribute("Tint", props.Tint)
	end
	if props.Shape then
		(d :: Part).Shape = props.Shape
	end
	d.Transparency = props.Transparency or 0
	d.Reflectance = props.Reflectance or 0
	d.Parent = parent
	return d
end

-- Декоративная деталь, приваренная к блоку (или к другой детали) неподвижно
local function decor(parent: BasePart, cf: CFrame, size: Vector3, props: { [string]: any }): BasePart
	local d = detail(parent, cf, size, props)
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent
	w.Part1 = d
	w.Parent = d
	return d
end

-- Подвижная деталь на Weld (как полотно двери): поворачивая C0, её анимируют
local function rigPart(parent: BasePart, name: string, weldName: string, c0: CFrame, c1: CFrame, size: Vector3, props: { [string]: any }): BasePart
	local d = detail(parent, c0 * c1:Inverse(), size, props)
	d.Name = name
	local w = Instance.new("Weld")
	w.Name = weldName
	w.C0 = c0
	w.C1 = c1
	w.Part0 = parent
	w.Part1 = d
	w.Parent = d
	return d
end

local function faceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, bg: Color3?)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 1
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = bg and 0 or 1
	t.BackgroundColor3 = bg or Color3.new()
	t.Text = text
	t.TextScaled = true
	t.TextColor3 = color
	t.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
	t.Parent = g
	g.Parent = part
end

-- ДВЕРЬ ---------------------------------------------------------------------------
-- Главная деталь — невидимая коробка: по ней бьют, кликают и ищут соседей.
-- Видны коробка двери и полотно "DoorLeaf" на петлях: Weld "DoorHinge" держит полотно,
-- C0 — ось петель (поворачивая C0, Specials открывает дверь), C1 — та же ось в системе полотна.
local DOOR_FRAME = 0.35 -- толщина коробки
local DOOR_GAP = 0.03 -- зазор вокруг полотна

local function buildDoor(part: BasePart, opts: BuildOptions)
	local s = part.Size
	local base = part.Color
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = true
	part.CastShadow = false

	local ft = math.min(DOOR_FRAME, s.X * 0.15, s.Y * 0.15)
	local g = DOOR_GAP
	local wood = Enum.Material.Wood
	-- коробка: два косяка и верх на всю глубину блока, темнее полотна
	local frame = { Material = wood, Color = base, Tint = 0.68 }
	for _, side in { -1, 1 } do
		decor(part, CFrame.new(side * (s.X / 2 - ft / 2), 0, 0), Vector3.new(ft, s.Y, s.Z), frame)
	end
	decor(part, CFrame.new(0, s.Y / 2 - ft / 2, 0), Vector3.new(s.X - ft * 2, ft, s.Z), frame)

	-- полотно заполняет проём; петли справа (+X), ручка слева
	local W = s.X - ft * 2 - g * 2
	local H = s.Y - ft - g * 2
	local lt = math.min(0.3, s.Z * 0.5)
	local leaf = newPart("Part")
	leaf.Name = "DoorLeaf"
	leaf.Size = Vector3.new(W, H, lt)
	leaf.Material = part.Material
	leaf.Color = base
	leaf:SetAttribute("Tint", 1)
	leaf.Anchored = false
	leaf.Massless = true
	leaf.CanCollide = not (opts.ghost or opts.preview)
	leaf.CanQuery = false
	leaf.CanTouch = false
	local hinge = Instance.new("Weld")
	hinge.Name = "DoorHinge"
	hinge.C0 = CFrame.new(s.X / 2 - ft, -ft / 2, 0)
	hinge.C1 = CFrame.new(W / 2 + g, 0, 0)
	leaf.CFrame = part.CFrame * hinge.C0 * hinge.C1:Inverse()
	leaf.Parent = part
	hinge.Part0 = part
	hinge.Part1 = leaf
	hinge.Parent = leaf

	-- декор полотна (координаты — от центра полотна)
	local face = lt / 2
	local panel = { Material = wood, Color = base, Tint = 0.82 }
	for _, side in { -1, 1 } do
		-- филёнки: верхняя и нижняя с каждой стороны
		local z = side * (face + 0.02)
		decor(leaf, CFrame.new(0, H * 0.1, z), Vector3.new(W * 0.62, H * 0.24, 0.06), panel)
		decor(leaf, CFrame.new(0, -H * 0.25, z), Vector3.new(W * 0.62, H * 0.34, 0.06), panel)
	end
	-- окошко
	decor(leaf, CFrame.new(0, H * 0.34, 0), Vector3.new(W * 0.42, H * 0.12, lt + 0.04),
		{ Material = Enum.Material.Glass, Color = Color3.fromRGB(120, 170, 205), Reflectance = 0.3 })
	-- ручка: стержень сквозь полотно, накладки и шарики с обеих сторон
	local brass = { Material = METAL, Color = Color3.fromRGB(222, 186, 92) }
	-- ручка между краем полотна и филёнками (у узкой двери накладка не наезжает на филёнку)
	local hx, hy = -W / 2 + math.min(0.4, W * 0.095), -H * 0.05
	decor(leaf, CFrame.new(hx, hy, 0) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(lt + 0.36, 0.08, 0.08),
		{ Shape = CYL, Material = METAL, Color = brass.Color })
	for _, side in { -1, 1 } do
		decor(leaf, CFrame.new(hx, hy, side * (face + 0.015)), Vector3.new(0.16, 0.42, 0.04), brass)
		decor(leaf, CFrame.new(hx, hy, side * (face + 0.18)), Vector3.new(0.24, 0.24, 0.24),
			{ Shape = BALL, Material = METAL, Color = brass.Color })
	end
	-- петли на оси поворота: при открытии крутятся на месте
	for _, y in { H * 0.36, -H * 0.36 } do
		decor(leaf, CFrame.new(W / 2 + g, y, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(math.min(0.7, H * 0.12), 0.36, 0.36),
			{ Shape = CYL, Material = METAL, Color = Color3.fromRGB(64, 64, 70) })
	end
end

-- ТУРЕЛЬ ПВО ----------------------------------------------------------------------
-- Каждая деталь опирается на другую: крыша блока → кольцо → корпус → стволы, ящики, радар.
local function buildTurret(part: BasePart)
	local top = part.Size.Y / 2
	local base = part.Color
	-- ось цилиндра (X) смотрит вперёд (-Z) и вверх под углом a
	local function aim(p: Vector3, a: number): CFrame
		return CFrame.new(p) * CFrame.Angles(a, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
	end
	-- поворотное кольцо на крыше
	decor(part, CFrame.new(0, top + 0.12, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.3, 2.6, 2.6),
		{ Shape = CYL, Material = METAL, Color = Color3.fromRGB(46, 48, 52) })
	-- корпус и наклонная лобовая броня
	decor(part, CFrame.new(0, top + 0.7, 0.15), Vector3.new(1.9, 0.9, 1.9), { Material = METAL, Color = base, Tint = 1.15 })
	decor(part, CFrame.new(0, top + 0.7, -1.13), Vector3.new(1.9, 0.9, 0.7),
		{ className = "WedgePart", Material = METAL, Color = base, Tint = 0.95 })
	-- 4 ствола (2×2) под 45°: казённики спрятаны в корпусе, на концах дульные тормоза
	local a = math.rad(45)
	local dir = Vector3.new(0, math.sin(a), -math.cos(a))
	local across = Vector3.new(0, math.cos(a), math.sin(a))
	for _, x in { -0.42, 0.42 } do
		for _, o in { 0.15, -0.15 } do
			local breech = Vector3.new(x, top + 0.8, -0.45) + across * o
			decor(part, aim(breech + dir * 1.1, a), Vector3.new(2.2, 0.18, 0.18),
				{ Shape = CYL, Material = METAL, Color = Color3.fromRGB(40, 42, 46) })
			decor(part, aim(breech + dir * 2.08, a), Vector3.new(0.36, 0.28, 0.28),
				{ Shape = CYL, Material = METAL, Color = Color3.fromRGB(28, 29, 32) })
		end
	end
	-- ящики с патронами по бокам корпуса
	for _, x in { -1.18, 1.18 } do
		decor(part, CFrame.new(x, top + 0.62, 0.25), Vector3.new(0.5, 0.6, 0.9), { Material = METAL, Color = Color3.fromRGB(112, 100, 62) })
	end
	-- радар на мачте и красная лампа на крыше корпуса
	decor(part, CFrame.new(0.55, top + 1.57, 0.8), Vector3.new(0.14, 0.9, 0.14), { Material = METAL, Color = Color3.fromRGB(58, 60, 64) })
	decor(part, aim(Vector3.new(0.55, top + 2.05, 0.8), math.rad(30)), Vector3.new(0.08, 0.9, 0.9),
		{ Shape = CYL, Material = METAL, Color = Color3.fromRGB(186, 190, 196) })
	decor(part, CFrame.new(-0.6, top + 1.23, 0.85), Vector3.new(0.26, 0.26, 0.26),
		{ Shape = BALL, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 60, 50) })
end

-- Добавить «особые» части: свет, огонь двигателя, надписи...
local function decorate(part: BasePart, def, spec, opts: BuildOptions)
	local key = def.key
	local s = part.Size
	local ghost = opts.ghost
	if key == "Wheel" then
		decor(part, CFrame.new(), Vector3.new(s.X + 0.1, s.Y * 0.45, s.Z * 0.45),
			{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Color = Color3.fromRGB(190, 192, 198) })
	elseif key == "Thruster" then
		-- сопло: тёмное кольцо, из него выглядывает светящийся диск; сзади — заглушка
		decor(part, CFrame.new(-s.X / 2 - 0.05, 0, 0), Vector3.new(0.3, s.Y * 0.95, s.Z * 0.95),
			{ Shape = CYL, Material = METAL, Color = Color3.fromRGB(46, 48, 54) })
		decor(part, CFrame.new(-s.X / 2 - 0.15, 0, 0), Vector3.new(0.3, s.Y * 0.8, s.Z * 0.8),
			{ Shape = CYL, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 140, 40) })
		decor(part, CFrame.new(s.X / 2 + 0.08, 0, 0), Vector3.new(0.2, s.Y * 1.1, s.Z * 1.1),
			{ Shape = CYL, Material = METAL, Color = Color3.fromRGB(60, 62, 70) })
		if not ghost and not opts.preview then
			local att = Instance.new("Attachment")
			att.Name = "Exhaust"
			att.Position = Vector3.new(-s.X / 2 - 0.3, 0, 0)
			att.Parent = part
			local fire = Instance.new("ParticleEmitter")
			fire.Name = "Flame"
			fire.Texture = "rbxasset://textures/particles/fire_main.dds"
			fire.EmissionDirection = Enum.NormalId.Left
			fire.Speed = NumberRange.new(18, 26)
			fire.Lifetime = NumberRange.new(0.15, 0.3)
			fire.Rate = 90
			fire.SpreadAngle = Vector2.new(6, 6)
			fire.LightEmission = 1
			fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0.2) })
			fire.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 90, 30))
			fire.Enabled = false
			fire.Parent = att
		end
	elseif key == "Balloon" then
		-- узелок цвета шара и верёвочка из него
		decor(part, CFrame.new(0, -s.Y / 2 + 0.02, 0), Vector3.new(0.4, 0.4, 0.4),
			{ Shape = BALL, Material = Enum.Material.SmoothPlastic, Color = part.Color, Tint = 0.8 })
		decor(part, CFrame.new(0, -s.Y / 2 - 1.4, 0), Vector3.new(0.08, 3, 0.08),
			{ Material = Enum.Material.Fabric, Color = Color3.fromRGB(230, 230, 230) })
	elseif key == "Door" then
		buildDoor(part, opts)
	elseif key == "Lamp" then
		if not ghost and not opts.preview then
			local light = Instance.new("PointLight")
			light.Range = 20
			light.Brightness = 2
			light.Shadows = part.Size.Magnitude > 2 -- маленькие лампы без теней (дешевле)
			light.Color = part.Color
			light.Parent = part
		end
	elseif key == "Flag" then
		decor(part, CFrame.new(0, s.Y / 2 - 1.4, -1.6), Vector3.new(0.12, 2.4, 3.2),
			{ Material = Enum.Material.Fabric, Color = opts.plotColor or Color3.fromRGB(226, 64, 64) })
		decor(part, CFrame.new(0, s.Y / 2 + 0.25, 0), Vector3.new(0.6, 0.6, 0.6),
			{ Shape = Enum.PartType.Ball, Material = Enum.Material.Metal, Color = Color3.fromRGB(240, 200, 70) })
	elseif key == "TNT" then
		decor(part, CFrame.new(0, s.Y * 0.28, 0), Vector3.new(s.X + 0.05, 0.25, s.Z + 0.05),
			{ Color = Color3.fromRGB(30, 30, 30) })
		decor(part, CFrame.new(0, -s.Y * 0.28, 0), Vector3.new(s.X + 0.05, 0.25, s.Z + 0.05),
			{ Color = Color3.fromRGB(30, 30, 30) })
		decor(part, CFrame.new(0, s.Y / 2 + 0.28, 0), Vector3.new(0.12, 0.6, 0.12),
			{ Color = Color3.fromRGB(70, 60, 50), Material = Enum.Material.Fabric })
		if not ghost then
			faceText(part, Enum.NormalId.Front, "TNT", Color3.new(1, 1, 1))
			faceText(part, Enum.NormalId.Back, "TNT", Color3.new(1, 1, 1))
		end
	elseif key == "Medkit" then
		-- красные кресты спереди, сзади и сверху (чуть утоплены, чтобы не было щели)
		local crosses = {
			CFrame.new(0, 0, -s.Z / 2 - 0.02),
			CFrame.new(0, 0, s.Z / 2 + 0.02),
			CFrame.new(0, s.Y / 2 + 0.02, 0) * CFrame.Angles(math.pi / 2, 0, 0),
		}
		for _, cf in crosses do
			decor(part, cf, Vector3.new(s.X * 0.6, s.Y * 0.18, 0.06), { Material = Enum.Material.Neon, Color = Color3.fromRGB(230, 40, 40) })
			decor(part, cf, Vector3.new(s.X * 0.18, s.Y * 0.6, 0.06), { Material = Enum.Material.Neon, Color = Color3.fromRGB(230, 40, 40) })
		end
	elseif key == "AATurret" then
		buildTurret(part)
	elseif key == "Shield" then
		decor(part, CFrame.new(0, s.Y / 2 + 0.3, 0), Vector3.new(1.8, 1.8, 1.8),
			{ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = Color3.fromRGB(90, 200, 255) })
		decor(part, CFrame.new(0, s.Y / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.3, 2.8, 2.8),
			{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Color = Color3.fromRGB(180, 190, 205) })
		if not ghost and not opts.preview then
			local light = Instance.new("PointLight")
			light.Range = 10
			light.Brightness = 1.5
			light.Color = Color3.fromRGB(90, 200, 255)
			light.Parent = part
		end
	end
end

-- Построить блок на месте cf. spec: { mat, shape, item, size, color }
function BlockFactory.build(spec, cf: CFrame, opts: BuildOptions?): BasePart
	local o: BuildOptions = opts or {}
	local def = Blocks.def(spec)
	local part: BasePart
	if spec.item and spec.item > 0 then
		local className = def.class or "Part"
		part = newPart(className)
		if def.shape == "Cylinder" then
			(part :: Part).Shape = Enum.PartType.Cylinder
		elseif def.shape == "Ball" then
			(part :: Part).Shape = Enum.PartType.Ball
		end
		if className == "VehicleSeat" then
			local seat = part :: VehicleSeat
			seat.MaxSpeed = 0
			seat.Torque = 0
			seat.TurnSpeed = 0
		end
	else
		local shape = spec.shape or 1
		if shape == 2 then
			part = newPart("WedgePart")
		elseif shape == 3 then
			part = newPart("CornerWedgePart")
		else
			part = newPart("Part")
			if shape == 4 then
				(part :: Part).Shape = Enum.PartType.Cylinder
			elseif shape == 5 then
				(part :: Part).Shape = Enum.PartType.Ball
			end
		end
	end
	part.Name = "Block"
	part.Size = spec.size
	part.CFrame = cf
	part.Material = def.material
	part.Color = spec.color or def.color
	part.Transparency = def.transparency or 0
	part.Reflectance = def.reflectance or 0
	if not o.ghost and not o.preview then
		local friction = (def.key == "Wheel") and 1.3 or 0.5
		part.CustomPhysicalProperties = PhysicalProperties.new(def.density or 1, friction, 0.15)
	end
	decorate(part, def, spec, o)
	if o.ghost then
		for _, d in part:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
			end
		end
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
	end
	return part
end

-- Все детали блока (сам блок + декор, включая декор на полотне двери) — чтобы, например,
-- сделать их прозрачными
function BlockFactory.allParts(block: BasePart): { BasePart }
	local list = { block }
	for _, d in block:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- Покрасить блок: сам блок и детали с атрибутом Tint (цвет блока × Tint)
function BlockFactory.applyColor(block: BasePart, color: Color3)
	block.Color = color
	for _, d in block:GetDescendants() do
		if d:IsA("BasePart") then
			local k = d:GetAttribute("Tint")
			if type(k) == "number" then
				d.Color = tinted(color, k)
			end
		end
	end
end

return BlockFactory
