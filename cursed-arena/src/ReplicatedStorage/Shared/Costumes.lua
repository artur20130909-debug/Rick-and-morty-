-- Образы персонажей из деталей (для ботов, манекенов и предпросмотра в меню)
-- и оружие (меч Алого Клинка — у всех, кто им играет).
local Costumes = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

-- цвета тела: кожа, торс, ноги
Costumes.Body = {
	StormFist = { skin = rgb(224, 172, 132), torso = rgb(232, 96, 40), legs = rgb(36, 32, 34) },
	VoidLord = { skin = rgb(236, 206, 180), torso = rgb(44, 30, 74), legs = rgb(30, 22, 52) },
	CrimsonBlade = { skin = rgb(240, 200, 170), torso = rgb(236, 232, 226), legs = rgb(40, 34, 36) },
	ShadowCaller = { skin = rgb(206, 170, 150), torso = rgb(24, 20, 30), legs = rgb(18, 16, 22) },
	FlameDemon = { skin = rgb(196, 120, 92), torso = rgb(28, 24, 24), legs = rgb(150, 54, 20) },
	Thunderer = { skin = rgb(230, 186, 150), torso = rgb(38, 76, 160), legs = rgb(28, 30, 44) },
	Dummy = { skin = rgb(196, 160, 110), torso = rgb(150, 116, 74), legs = rgb(120, 92, 60) },
}

local function mk(model, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- прикрепить к части тела: offset — в системе этой части (в покое)
local function attach(folder, bodyPart, name, size, offset, color, material, shape)
	local p = mk(folder, name, size, bodyPart.CFrame * offset, color, material, shape)
	local w = Instance.new("WeldConstraint")
	w.Part0 = bodyPart
	w.Part1 = p
	w.Parent = p
	p.Parent = folder
	return p
end
Costumes.attach = attach

local function wedge(folder, bodyPart, name, size, offset, color, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = bodyPart.CFrame * offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = bodyPart
	w.Part1 = p
	w.Parent = p
	p.Parent = folder
	return p
end

function Costumes.setBody(model, id)
	local c = Costumes.Body[id] or Costumes.Body.Dummy
	local map = { Head = c.skin, ["Left Arm"] = c.skin, ["Right Arm"] = c.skin, Torso = c.torso, ["Left Leg"] = c.legs, ["Right Leg"] = c.legs }
	for name, col in pairs(map) do
		local p = model:FindFirstChild(name)
		if p then p.Color = col end
	end
	local bc = model:FindFirstChildOfClass("BodyColors")
	if bc then
		bc.HeadColor3, bc.LeftArmColor3, bc.RightArmColor3 = c.skin, c.skin, c.skin
		bc.TorsoColor3, bc.LeftLegColor3, bc.RightLegColor3 = c.torso, c.legs, c.legs
	end
end

local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

-- полный образ (боты, меню)
local builders = {}

builders.StormFist = function(f, m)
	local head, torso = m.Head, m.Torso
	local hair = rgb(30, 22, 20)
	attach(f, head, "Hair", Vector3.new(1.3, 0.35, 1.3), CF(0, 0.55, 0.02), hair)
	for i = -2, 2 do
		wedge(f, head, "Spike", Vector3.new(0.22, 0.45, 0.5), CF(i * 0.26, 0.85, 0.15) * ANG(rad(-15), 0, 0), hair)
	end
	attach(f, head, "Headband", Vector3.new(1.32, 0.18, 1.32), CF(0, 0.32, 0), rgb(220, 30, 30))
	attach(f, head, "BandTail", Vector3.new(0.2, 0.12, 0.9), CF(0.25, 0.3, 0.95) * ANG(rad(-25), rad(10), 0), rgb(220, 30, 30))
	attach(f, torso, "Belt", Vector3.new(2.06, 0.3, 1.06), CF(0, -0.75, 0), rgb(20, 20, 20))
	attach(f, torso, "Collar", Vector3.new(0.5, 1.5, 0.06), CF(0, 0.2, -0.53) * ANG(0, 0, rad(28)), rgb(255, 196, 120))
	for _, side in ipairs({ "Left Arm", "Right Arm" }) do
		local arm = m[side]
		attach(f, arm, "Wrap", Vector3.new(1.06, 0.55, 1.06), CF(0, -0.68, 0), rgb(245, 238, 225), Enum.Material.Fabric)
	end
end

builders.VoidLord = function(f, m)
	local head, torso = m.Head, m.Torso
	local cloth = rgb(48, 28, 84)
	attach(f, head, "Hood", Vector3.new(1.45, 1.45, 1.45), CF(0, 0.12, 0.12), cloth, Enum.Material.Fabric)
	attach(f, head, "HoodFront", Vector3.new(1.45, 0.4, 0.3), CF(0, 0.62, -0.62), cloth, Enum.Material.Fabric)
	attach(f, head, "EyeL", Vector3.new(0.22, 0.1, 0.05), CF(-0.22, 0.08, -0.62), rgb(92, 230, 255), Enum.Material.Neon)
	attach(f, head, "EyeR", Vector3.new(0.22, 0.1, 0.05), CF(0.22, 0.08, -0.62), rgb(92, 230, 255), Enum.Material.Neon)
	attach(f, torso, "Coat", Vector3.new(2.12, 2.1, 1.12), CF(0, -0.05, 0), cloth, Enum.Material.Fabric)
	attach(f, torso, "CoatTail", Vector3.new(2.0, 1.6, 0.12), CF(0, -1.6, 0.5), cloth, Enum.Material.Fabric)
	attach(f, torso, "Trim", Vector3.new(0.14, 2.1, 1.14), CF(0, -0.05, 0), rgb(170, 92, 255), Enum.Material.Neon)
	attach(f, torso, "Sigil", Vector3.new(0.5, 0.5, 0.06), CF(0, 0.35, -0.6) * ANG(0, 0, rad(45)), rgb(92, 230, 255), Enum.Material.Neon)
end

builders.CrimsonBlade = function(f, m)
	local head, torso = m.Head, m.Torso
	local hair = rgb(24, 18, 20)
	attach(f, head, "Hair", Vector3.new(1.3, 0.4, 1.3), CF(0, 0.52, 0.05), hair)
	attach(f, head, "TopKnot", Vector3.new(0.45, 0.5, 0.45), CF(0, 0.9, 0.3), hair)
	attach(f, head, "Tip", Vector3.new(0.47, 0.16, 0.47), CF(0, 1.1, 0.3), rgb(220, 30, 50))
	attach(f, torso, "Sash", Vector3.new(2.08, 0.4, 1.08), CF(0, -0.7, 0), rgb(214, 28, 48))
	attach(f, torso, "Lapel", Vector3.new(0.4, 2.0, 0.06), CF(-0.2, 0.05, -0.53) * ANG(0, 0, rad(-20)), rgb(214, 28, 48))
	attach(f, torso, "Scabbard", Vector3.new(0.22, 0.22, 3.4), CF(-1.1, -0.85, 0.4) * ANG(rad(-20), rad(10), 0), rgb(20, 16, 18))
end

builders.ShadowCaller = function(f, m)
	local head, torso = m.Head, m.Torso
	local cloak = rgb(16, 14, 22)
	attach(f, head, "Hood", Vector3.new(1.42, 1.42, 1.42), CF(0, 0.12, 0.14), cloak, Enum.Material.Fabric)
	attach(f, head, "Mask", Vector3.new(1.0, 1.0, 0.12), CF(0, 0, -0.62), rgb(232, 226, 214))
	attach(f, head, "SlitL", Vector3.new(0.26, 0.08, 0.05), CF(-0.2, 0.1, -0.69), rgb(150, 80, 255), Enum.Material.Neon)
	attach(f, head, "SlitR", Vector3.new(0.26, 0.08, 0.05), CF(0.2, 0.1, -0.69), rgb(150, 80, 255), Enum.Material.Neon)
	attach(f, torso, "Cloak", Vector3.new(2.16, 2.0, 1.16), CF(0, 0, 0), cloak, Enum.Material.Fabric)
	attach(f, torso, "Cape", Vector3.new(2.3, 3.2, 0.12), CF(0, -0.6, 0.62) * ANG(rad(6), 0, 0), cloak, Enum.Material.Fabric)
	attach(f, torso, "Scarf", Vector3.new(2.2, 0.45, 1.2), CF(0, 0.82, 0), rgb(92, 46, 160), Enum.Material.Fabric)
end

builders.FlameDemon = function(f, m)
	local head, torso = m.Head, m.Torso
	local hair = rgb(250, 120, 30)
	attach(f, head, "Hair", Vector3.new(1.3, 0.4, 1.3), CF(0, 0.52, 0.04), hair, Enum.Material.Neon)
	for i = -1, 1 do
		wedge(f, head, "Flame", Vector3.new(0.35, 0.6, 0.55), CF(i * 0.38, 0.95, 0.1) * ANG(rad(-10), 0, rad(i * -12)), rgb(255, 196, 60), Enum.Material.Neon)
	end
	wedge(f, head, "HornL", Vector3.new(0.18, 0.55, 0.3), CF(-0.5, 0.72, -0.1) * ANG(rad(-10), 0, rad(20)), rgb(40, 20, 18))
	wedge(f, head, "HornR", Vector3.new(0.18, 0.55, 0.3), CF(0.5, 0.72, -0.1) * ANG(rad(-10), 0, rad(-20)), rgb(40, 20, 18))
	attach(f, torso, "Belt", Vector3.new(2.06, 0.3, 1.06), CF(0, -0.85, 0), rgb(60, 30, 20))
	attach(f, torso, "Mark", Vector3.new(0.7, 0.18, 0.06), CF(0, 0.4, -0.53), rgb(255, 140, 30), Enum.Material.Neon)
	for _, side in ipairs({ "Left Arm", "Right Arm" }) do
		attach(f, m[side], "Cuff", Vector3.new(1.06, 0.3, 1.06), CF(0, -0.8, 0), rgb(255, 140, 30), Enum.Material.Neon)
	end
end

builders.Thunderer = function(f, m)
	local head, torso = m.Head, m.Torso
	local hair = rgb(255, 240, 150)
	attach(f, head, "Hair", Vector3.new(1.3, 0.35, 1.3), CF(0, 0.55, 0.04), hair)
	for i = -2, 2 do
		wedge(f, head, "Spike", Vector3.new(0.25, 0.5, 0.6), CF(i * 0.25, 0.85, 0.2) * ANG(rad(-35), 0, 0), hair)
	end
	attach(f, head, "Goggles", Vector3.new(1.34, 0.2, 1.34), CF(0, 0.32, 0), rgb(40, 40, 46))
	attach(f, head, "Lens", Vector3.new(0.7, 0.24, 0.1), CF(0, 0.34, -0.66), rgb(120, 210, 255), Enum.Material.Glass)
	attach(f, torso, "Stripe", Vector3.new(0.3, 2.04, 1.04), CF(0.55, 0, 0) * ANG(0, 0, rad(18)), rgb(255, 230, 90), Enum.Material.Neon)
	attach(f, torso, "Collar", Vector3.new(2.1, 0.35, 1.1), CF(0, 0.9, 0), rgb(26, 50, 120))
end

builders.Dummy = function(f, m)
	local torso = m.Torso
	attach(f, torso, "Target", Vector3.new(1.0, 1.0, 0.05), CF(0, 0.1, -0.53), rgb(230, 230, 230))
	attach(f, torso, "Bull", Vector3.new(0.45, 0.45, 0.06), CF(0, 0.1, -0.54), rgb(220, 40, 40))
end

function Costumes.apply(model, id)
	local old = model:FindFirstChild("Costume")
	if old then old:Destroy() end
	Costumes.setBody(model, id)
	local face = model:FindFirstChild("Head") and model.Head:FindFirstChild("face")
	if face and (id == "VoidLord" or id == "ShadowCaller") then face.Transparency = 1 end
	local f = Instance.new("Folder")
	f.Name = "Costume"
	f.Parent = model
	local b = builders[id]
	if b then b(f, model) end
	return f
end

-- меч в правой руке (лезвие — вперёд из кулака)
function Costumes.sword(model, color)
	local arm = model:FindFirstChild("Right Arm")
	if not arm then return nil end
	local old = model:FindFirstChild("Weapon")
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = "Weapon"
	f.Parent = model
	attach(f, arm, "Handle", Vector3.new(0.24, 0.24, 1.3), CF(0, -0.95, -0.15), rgb(26, 20, 22), Enum.Material.Fabric)
	attach(f, arm, "Guard", Vector3.new(0.12, 0.6, 0.6), CF(0, -0.95, -0.85) * ANG(0, rad(90), 0), rgb(210, 170, 70), Enum.Material.Metal, Enum.PartType.Cylinder)
	local blade = attach(f, arm, "Blade", Vector3.new(0.07, 0.3, 4.3), CF(0, -0.92, -3.05), rgb(222, 226, 232), Enum.Material.Metal)
	blade.Reflectance = 0.25
	local edge = attach(f, arm, "Edge", Vector3.new(0.05, 0.06, 4.25), CF(0, -0.79, -3.05), color or rgb(230, 32, 56), Enum.Material.Neon)
	edge.Transparency = 0.4
	return f
end

return Costumes
