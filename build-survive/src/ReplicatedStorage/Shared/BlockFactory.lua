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

-- Декоративная деталь, приваренная к блоку. Не мешает лучам и столкновениям.
local function decor(parent: BasePart, cf: CFrame, size: Vector3, props: { [string]: any }): BasePart
	local d = newPart(props.className or "Part")
	d.Name = "Decor"
	d.Size = size
	d.CFrame = parent.CFrame * cf
	d.CanCollide = false
	d.CanQuery = false
	d.CanTouch = false
	d.Massless = true
	d.Anchored = false
	d.Material = props.Material or Enum.Material.SmoothPlastic
	d.Color = props.Color or Color3.new(1, 1, 1)
	if props.Shape then
		(d :: Part).Shape = props.Shape
	end
	d.Transparency = props.Transparency or 0
	d.Parent = parent
	local w = Instance.new("WeldConstraint")
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

-- Добавить «особые» части: свет, огонь двигателя, надписи...
local function decorate(part: BasePart, def, spec, opts: BuildOptions)
	local key = def.key
	local s = part.Size
	local ghost = opts.ghost
	if key == "Wheel" then
		decor(part, CFrame.new(), Vector3.new(s.X + 0.1, s.Y * 0.45, s.Z * 0.45),
			{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Color = Color3.fromRGB(190, 192, 198) })
	elseif key == "Thruster" then
		decor(part, CFrame.new(-s.X / 2 - 0.15, 0, 0), Vector3.new(0.3, s.Y * 0.8, s.Z * 0.8),
			{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 140, 40) })
		decor(part, CFrame.new(s.X / 2 + 0.1, 0, 0), Vector3.new(0.2, s.Y * 1.1, s.Z * 1.1),
			{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 62, 70) })
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
		decor(part, CFrame.new(0, -s.Y / 2 - 1.4, 0), Vector3.new(0.08, 3, 0.08),
			{ Material = Enum.Material.Fabric, Color = Color3.fromRGB(230, 230, 230) })
	elseif key == "Door" then
		decor(part, CFrame.new(s.X / 2 - 0.6, 0, -s.Z / 2 - 0.1), Vector3.new(0.3, 0.3, 0.25),
			{ Material = Enum.Material.Metal, Color = Color3.fromRGB(220, 190, 90) })
		decor(part, CFrame.new(s.X / 2 - 0.6, 0, s.Z / 2 + 0.1), Vector3.new(0.3, 0.3, 0.25),
			{ Material = Enum.Material.Metal, Color = Color3.fromRGB(220, 190, 90) })
	elseif key == "Lamp" then
		if not ghost and not opts.preview then
			local light = Instance.new("PointLight")
			light.Range = 20
			light.Brightness = 2
			light.Shadows = true
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
		decor(part, CFrame.new(0, s.Y / 2 + 0.3, 0), Vector3.new(0.12, 0.6, 0.12),
			{ Color = Color3.fromRGB(70, 60, 50), Material = Enum.Material.Fabric })
		if not ghost then
			faceText(part, Enum.NormalId.Front, "TNT", Color3.new(1, 1, 1))
			faceText(part, Enum.NormalId.Back, "TNT", Color3.new(1, 1, 1))
		end
	elseif key == "Medkit" then
		for _, cf in { CFrame.new(0, 0, -s.Z / 2 - 0.03), CFrame.new(0, s.Y / 2 + 0.03, 0) * CFrame.Angles(math.pi / 2, 0, 0) } do
			decor(part, cf, Vector3.new(s.X * 0.6, s.Y * 0.18, 0.06), { Material = Enum.Material.Neon, Color = Color3.fromRGB(230, 40, 40) })
			decor(part, cf, Vector3.new(s.X * 0.18, s.Y * 0.6, 0.06), { Material = Enum.Material.Neon, Color = Color3.fromRGB(230, 40, 40) })
		end
	elseif key == "AATurret" then
		decor(part, CFrame.new(0, s.Y / 2 + 0.5, 0), Vector3.new(1.8, 1, 1.8),
			{ Material = Enum.Material.Metal, Color = Color3.fromRGB(56, 66, 56) })
		for _, x in { -0.45, 0.45 } do
			decor(part, CFrame.new(x, s.Y / 2 + 1.5, -0.6) * CFrame.Angles(math.rad(50), 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
				Vector3.new(2.6, 0.32, 0.32), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 42, 44) })
		end
		decor(part, CFrame.new(0, s.Y / 2 + 1.1, 0.7), Vector3.new(0.9, 0.5, 0.2),
			{ Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 70, 50) })
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

-- Все детали блока (сам блок + декор) — чтобы, например, сделать их прозрачными
function BlockFactory.allParts(block: BasePart): { BasePart }
	local list = { block }
	for _, d in block:GetChildren() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

return BlockFactory
