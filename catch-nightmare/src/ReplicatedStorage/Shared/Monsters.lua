-- Модели монстров из простых деталей. Monsters.build(key, mutation) -> Model, Root.
-- Root — невидимая закреплённая деталь у ног монстра (перед — сторона −Z). Остальные детали
-- приварены к Root, без столкновений и без массы: монстра можно двигать одним Root.CFrame
-- и носить на голове. Подпись над монстром — Monsters.label(model, text...).
local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)

local Monsters = {}

local hex = Color3.fromHex
local rad = math.rad
local EYE_WHITE = Color3.fromRGB(245, 245, 245)
local BLACK = Color3.fromRGB(10, 10, 10)

-- конструктор деталей вокруг корня
local function ctx(m, root)
	local c = {}
	local function finish(p, off, color, mat, props)
		p.CFrame = root.CFrame * off
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if props then
			for k, v in pairs(props) do p[k] = v end
		end
		p.Parent = m
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
		return p
	end
	-- брусок: размер, позиция, цвет, материал, поворот (CFrame), свойства
	function c.box(sx, sy, sz, x, y, z, color, mat, rot, props)
		local p = Instance.new("Part")
		p.Size = Vector3.new(sx, sy, sz)
		return finish(p, CFrame.new(x, y, z) * (rot or CFrame.new()), color, mat, props)
	end
	function c.ball(d, x, y, z, color, mat, props)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(d, d, d)
		return finish(p, CFrame.new(x, y, z), color, mat, props)
	end
	-- вертикальный цилиндр
	function c.vcyl(h, d, x, y, z, color, mat, props)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(h, d, d)
		return finish(p, CFrame.new(x, y, z) * CFrame.Angles(0, 0, rad(90)), color, mat, props)
	end
	-- плоский цилиндр, смотрящий вперёд (−Z): пуговицы, пепперони
	function c.disc(d, th, x, y, z, color, mat, props)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(th, d, d)
		return finish(p, CFrame.new(x, y, z) * CFrame.Angles(0, rad(90), 0), color, mat, props)
	end
	function c.wedge(sx, sy, sz, x, y, z, color, mat, rot, props)
		local p = Instance.new("WedgePart")
		p.Size = Vector3.new(sx, sy, sz)
		return finish(p, CFrame.new(x, y, z) * (rot or CFrame.new()), color, mat, props)
	end
	-- глаз: белок + зрачок впереди; detail = без мутационной перекраски
	function c.eye(x, y, z, d, pupil, white)
		local e = c.ball(d, x, y, z, white or EYE_WHITE, Enum.Material.SmoothPlastic)
		e:SetAttribute("NoTint", true)
		local p = c.ball(d * 0.5, x, y, z - d * 0.32, pupil or BLACK, Enum.Material.SmoothPlastic)
		p:SetAttribute("NoTint", true)
		return e, p
	end
	function c.light(y, color, range, brightness)
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(0, y, 0)
		a.Parent = root
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range or 10
		l.Brightness = brightness or 1
		l.Shadows = false
		l.Parent = a
		return l
	end
	return c
end

local B = {}

B.slipper = function(c)
	c.box(2.2, 0.5, 4, 0, 0.25, 0, hex("#d86a8a"))
	c.box(2.3, 1.1, 2.2, 0, 0.95, -0.9, hex("#f2e6e9"), Enum.Material.Fabric)
	c.box(0.8, 0.1, 0.7, 0, 0.55, -2.05, hex("#c4243a"))
	for i = -1, 1, 2 do
		c.wedge(0.3, 0.35, 0.25, i * 0.75, 0.62, -2.05, EYE_WHITE, nil, CFrame.Angles(rad(180), 0, 0))
		c.wedge(0.3, 0.35, 0.25, i * 0.25, 0.62, -2.05, EYE_WHITE, nil, CFrame.Angles(rad(180), 0, 0))
	end
	c.eye(-0.5, 1.65, -1.3, 0.7)
	c.eye(0.5, 1.65, -1.3, 0.7)
end

B.dustbun = function(c)
	local grey = hex("#8d8d93")
	c.ball(2.6, 0, 1.5, 0, grey, Enum.Material.Fabric)
	local fuzz = { { 1.1, 2.3, 0.3 }, { -1.1, 2.2, 0.2 }, { 0.2, 2.8, 0.5 }, { 1.2, 1.0, 0.6 }, { -1.2, 1.1, 0.5 }, { 0, 1.6, 1.2 } }
	for _, f in ipairs(fuzz) do c.ball(1.0, f[1], f[2], f[3], hex("#7a7a80"), Enum.Material.Fabric) end
	c.eye(-0.5, 1.9, -1.0, 1.0)
	c.eye(0.5, 1.9, -1.0, 1.0)
	c.ball(0.6, -0.6, 0.3, -0.4, hex("#4a4a50"))
	c.ball(0.6, 0.6, 0.3, -0.4, hex("#4a4a50"))
end

B.fridge = function(c)
	c.box(3.2, 5.6, 2.8, 0, 3.0, 0, hex("#e9eef2"))
	c.box(3.25, 0.12, 0.1, 0, 4.0, -1.42, hex("#7d8790"))
	c.box(0.25, 1.2, 0.25, 1.2, 4.7, -1.5, hex("#9aa4ad"), Enum.Material.Metal)
	c.box(0.25, 1.2, 0.25, 1.2, 2.9, -1.5, hex("#9aa4ad"), Enum.Material.Metal)
	c.eye(-0.7, 5.0, -1.45, 0.8)
	c.eye(0.5, 5.0, -1.45, 0.8)
	c.box(1.8, 0.4, 0.1, -0.2, 2.2, -1.42, BLACK)
	for i = 0, 3 do c.box(0.3, 0.2, 0.1, -0.85 + i * 0.45, 2.33, -1.46, EYE_WHITE) end
	c.box(0.4, 0.4, 0.1, -1.0, 3.3, -1.45, hex("#e03c3c"))
	c.box(0.4, 0.4, 0.1, 0.4, 3.5, -1.45, hex("#f5c400"))
	c.box(0.4, 0.6, 0.6, -1, 0.3, 0, hex("#3a3f44"))
	c.box(0.4, 0.6, 0.6, 1, 0.3, 0, hex("#3a3f44"))
end

B.sock = function(c)
	local white, red = hex("#f4f4f4"), hex("#e23a3a")
	c.box(1.2, 0.6, 1.2, 0, 0.5, 0, white, nil, nil, { Transparency = 0.5 })
	c.box(1.6, 1.2, 2.6, 0, 1.4, -0.5, white, Enum.Material.Fabric)
	c.ball(1.5, 0, 1.4, 0.8, white, Enum.Material.Fabric)
	for i = 0, 3 do
		c.box(1.6, 0.8, 1.6, 0, 2.4 + i * 0.8, 0.4, (i % 2 == 0) and red or white, Enum.Material.Fabric)
	end
	c.eye(-0.4, 4.5, -0.45, 0.55)
	c.eye(0.4, 4.5, -0.45, 0.55)
	c.box(0.6, 0.15, 0.1, 0, 3.9, -0.42, BLACK)
end

B.wardrobe = function(c)
	local wood = hex("#6b4528")
	c.box(4, 6.4, 2.4, 0, 3.6, 0, wood, Enum.Material.WoodPlanks)
	c.box(4.3, 0.4, 2.7, 0, 7.0, 0, hex("#553620"), Enum.Material.Wood)
	c.box(3.6, 5.8, 0.1, 0, 3.6, -1.21, BLACK)
	c.box(1.9, 6, 0.2, -1.6, 3.6, -1.7, wood, Enum.Material.WoodPlanks, CFrame.Angles(0, rad(-35), 0))
	c.box(1.9, 6, 0.2, 1.6, 3.6, -1.7, wood, Enum.Material.WoodPlanks, CFrame.Angles(0, rad(35), 0))
	local eyes = { { -0.9, 5.4 }, { 0.6, 5.8 }, { -0.2, 4.4 }, { 1.0, 3.6 }, { -1.1, 2.8 }, { 0.3, 2.2 } }
	for _, e in ipairs(eyes) do
		local p = c.ball(0.4, e[1], e[2], -1.3, hex("#ffe14a"), Enum.Material.Neon)
		p:SetAttribute("NoTint", true)
	end
	for _, x in ipairs({ -1.6, 1.6 }) do
		c.box(0.4, 0.4, 0.4, x, 0.2, -0.8, hex("#3a2414"))
		c.box(0.4, 0.4, 0.4, x, 0.2, 0.8, hex("#3a2414"))
	end
	c.light(4, hex("#ffe14a"), 8, 0.6)
end

B.lamp = function(c)
	c.vcyl(0.4, 2.0, 0, 0.2, 0, hex("#2e2a26"), Enum.Material.Metal)
	c.vcyl(3.6, 0.35, 0, 2.2, 0, hex("#b08d3c"), Enum.Material.Metal)
	c.vcyl(1.8, 2.6, 0, 4.7, 0, hex("#f3e2b5"), Enum.Material.Fabric)
	local bulb = c.ball(1.1, 0, 3.8, 0, hex("#fff1a8"), Enum.Material.Neon)
	bulb:SetAttribute("NoTint", true)
	c.ball(0.4, -0.45, 4.95, -1.25, BLACK)
	c.ball(0.4, 0.45, 4.95, -1.25, BLACK)
	c.box(0.8, 0.15, 0.1, 0, 4.35, -1.3, BLACK)
	c.light(3.8, hex("#ffe9a0"), 12, 1.2)
end

B.grandma = function(c)
	c.ball(3.6, 0, 2.2, 0, hex("#7b4aa0"), Enum.Material.Fabric)
	c.box(3.2, 0.5, 2.2, 0, 3.75, 0, hex("#c0392b"), Enum.Material.Fabric)
	c.ball(2.0, 0, 4.7, 0, hex("#f1c9a5"))
	c.ball(2.1, 0, 4.95, 0.2, hex("#cfcfcf"), Enum.Material.Fabric)
	c.ball(1.1, 0, 5.95, 0.5, hex("#cfcfcf"), Enum.Material.Fabric)
	c.eye(-0.4, 4.75, -0.8, 0.45)
	c.eye(0.4, 4.75, -0.8, 0.45)
	c.box(1.4, 0.08, 0.08, 0, 4.85, -1.1, BLACK)
	c.ball(0.6, -0.4, 4.75, -1.0, hex("#bfe6ff"), Enum.Material.Glass, { Transparency = 0.6 })
	c.ball(0.6, 0.4, 4.75, -1.0, hex("#bfe6ff"), Enum.Material.Glass, { Transparency = 0.6 })
	for i = -1, 1, 2 do
		c.box(0.15, 1.6, 0.15, i * 0.55, 6.2, 0, hex("#2b2b2b"), nil, CFrame.Angles(0, 0, rad(-i * 20)))
		local tip = c.ball(0.35, i * 0.85, 7.0, 0, hex("#3cff6a"), Enum.Material.Neon)
		tip:SetAttribute("NoTint", true)
	end
	for i = 0, 2 do
		local led = c.ball(0.25, -0.5 + i * 0.5, 2.6, -1.75, (i == 1) and hex("#3fa9ff") or hex("#3cff6a"), Enum.Material.Neon)
		led:SetAttribute("NoTint", true)
	end
end

B.matryoshka = function(c)
	local red = hex("#c8102e")
	c.ball(3.0, 0, 1.9, 0, red)
	c.ball(2.2, 0, 3.6, 0, red)
	c.ball(1.4, 0, 3.7, -0.6, hex("#f6d7b8"))
	c.eye(-0.25, 3.85, -1.2, 0.3)
	c.eye(0.25, 3.85, -1.2, 0.3)
	c.ball(0.25, -0.42, 3.5, -1.2, hex("#ff6b81"))
	c.ball(0.25, 0.42, 3.5, -1.2, hex("#ff6b81"))
	c.ball(0.9, 0, 1.9, -1.2, hex("#ffd23f"))
	local leg = hex("#2a1a1a")
	for i = 1, 4 do
		local z = -1.2 + (i - 1) * 0.8
		for s = -1, 1, 2 do
			c.box(2.0, 0.25, 0.25, s * 1.9, 2.3, z, leg, nil, CFrame.Angles(0, 0, rad(s * 25)))
			c.box(0.25, 2.3, 0.25, s * 2.85, 1.15, z, leg)
		end
	end
end

B.cat404 = function(c)
	local black = hex("#121212")
	c.box(2, 1.8, 3.4, 0, 1.9, 0.3, black)
	c.box(2, 1.8, 1.8, 0, 3.2, -1.5, black)
	c.wedge(0.6, 0.8, 0.6, -0.6, 4.5, -1.5, black)
	c.wedge(0.6, 0.8, 0.6, 0.6, 4.5, -1.5, black)
	local e1 = c.box(0.6, 0.35, 0.1, -0.5, 3.4, -2.42, hex("#30f0ff"), Enum.Material.Neon)
	local e2 = c.box(0.6, 0.35, 0.1, 0.5, 3.4, -2.42, hex("#30f0ff"), Enum.Material.Neon)
	e1:SetAttribute("NoTint", true)
	e2:SetAttribute("NoTint", true)
	local ghost = c.box(2.1, 1.9, 1.9, 0.25, 3.25, -1.5, hex("#ff2bd6"), Enum.Material.Neon, nil, { Transparency = 0.75 })
	ghost:SetAttribute("NoTint", true)
	c.box(0.3, 0.3, 2.4, 0, 3.0, 2.5, black, nil, CFrame.Angles(rad(40), 0, 0))
	for _, p in ipairs({ { -0.6, -0.9 }, { 0.6, -0.9 }, { -0.6, 1.4 }, { 0.6, 1.4 } }) do
		c.box(0.5, 1.0, 0.5, p[1], 0.5, p[2], black)
	end
	c.light(3, hex("#30f0ff"), 8, 0.8)
end

B.pizzademon = function(c)
	local cheese = hex("#ffcf40")
	c.box(4.4, 0.8, 1.0, 0, 1.1, 0, hex("#d9a066"))
	-- треугольник из двух клиньев, остриё вверх
	c.wedge(0.8, 4.5, 2, 1, 3.75, 0, cheese, nil, CFrame.Angles(0, rad(-90), 0))
	c.wedge(0.8, 4.5, 2, -1, 3.75, 0, cheese, nil, CFrame.Angles(0, rad(90), 0))
	c.disc(0.8, 0.1, -0.8, 2.0, -0.42, hex("#b3261e"))
	c.disc(0.7, 0.1, 0.7, 2.4, -0.42, hex("#b3261e"))
	c.disc(0.5, 0.1, 0, 4.4, -0.42, hex("#b3261e"))
	local e1 = c.ball(0.45, -0.4, 3.3, -0.45, hex("#ff2a2a"), Enum.Material.Neon)
	local e2 = c.ball(0.45, 0.4, 3.3, -0.45, hex("#ff2a2a"), Enum.Material.Neon)
	e1:SetAttribute("NoTint", true)
	e2:SetAttribute("NoTint", true)
	c.box(1.0, 0.25, 0.1, 0, 2.75, -0.43, BLACK)
	c.wedge(0.3, 0.9, 0.4, -0.75, 4.4, 0, hex("#8b0000"), nil, CFrame.Angles(0, 0, rad(30)))
	c.wedge(0.3, 0.9, 0.4, 0.75, 4.4, 0, hex("#8b0000"), nil, CFrame.Angles(0, 0, rad(-30)))
	c.box(0.4, 0.7, 0.4, -1, 0.35, 0, hex("#5a3a20"))
	c.box(0.4, 0.7, 0.4, 1, 0.35, 0, hex("#5a3a20"))
	local crust = c.box(0.2, 0.2, 0.2, 0, 1.6, 0.3, cheese, nil, nil, { Transparency = 1 })
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 4
	fire.Parent = crust
end

B.moonhead = function(c)
	local dark = hex("#1b1b2a")
	c.box(0.35, 4, 0.35, -0.5, 2, 0, dark)
	c.box(0.35, 4, 0.35, 0.5, 2, 0, dark)
	c.box(1.4, 2.6, 0.9, 0, 5.2, 0, hex("#23233a"), Enum.Material.Fabric)
	c.box(0.3, 3.4, 0.3, -1.0, 4.6, 0, dark)
	c.box(0.3, 3.4, 0.3, 1.0, 4.6, 0, dark)
	local moon = c.ball(3.6, 0, 8.3, 0, hex("#f5f1d0"), Enum.Material.Neon)
	moon:SetAttribute("NoTint", true)
	c.ball(0.8, 0.8, 8.9, -1.4, hex("#d8d2a8"))
	c.ball(0.6, -0.9, 7.7, -1.45, hex("#d8d2a8"))
	c.ball(0.5, -0.6, 8.4, -1.65, BLACK)
	c.ball(0.5, 0.6, 8.4, -1.65, BLACK)
	c.box(1.0, 0.18, 0.1, 0, 7.6, -1.72, BLACK)
	c.light(8.3, hex("#fff6c8"), 18, 1.5)
end

B.nobody = function(c)
	local void = hex("#050505")
	c.box(0.6, 4, 0.6, -0.6, 2, 0, void)
	c.box(0.6, 4, 0.6, 0.6, 2, 0, void)
	local torso = c.box(2.2, 3, 1.2, 0, 5.5, 0, void)
	c.box(0.45, 4.5, 0.45, -1.5, 4.9, 0, void)
	c.box(0.45, 4.5, 0.45, 1.5, 4.9, 0, void)
	c.ball(1.8, 0, 7.9, 0, void)
	local e1 = c.ball(0.35, -0.35, 8.0, -0.82, EYE_WHITE, Enum.Material.Neon)
	local e2 = c.ball(0.35, 0.35, 8.0, -0.82, EYE_WHITE, Enum.Material.Neon)
	e1:SetAttribute("NoTint", true)
	e2:SetAttribute("NoTint", true)
	for i = 0, 5 do
		local a = rad(i * 60)
		local spike = c.box(0.15, 0.8, 0.15, math.cos(a) * 0.7, 9.0, math.sin(a) * 0.7, EYE_WHITE, Enum.Material.Neon)
		spike:SetAttribute("NoTint", true)
	end
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(0, 0, 0)
	smoke.Opacity = 0.25
	smoke.RiseVelocity = 1
	smoke.Size = 4
	smoke.Parent = torso
	c.light(8, EYE_WHITE, 10, 1)
end

-- перекраска под мутацию
local function tint(m, mut)
	local mu = Config.MutationIndex[mut or ""]
	if not mu then return end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Root" and not p:GetAttribute("NoTint") then
			p.Color = p.Color:Lerp(mu.color, 0.6)
			if mut == "gold" then p.Material = Enum.Material.Metal end
		end
	end
	if mut == "glitch" then m:SetAttribute("Glitch", true) end
	local root = m:FindFirstChild("Root")
	if root then
		local l = Instance.new("PointLight")
		l.Name = "MutationLight"
		l.Color = mu.color
		l.Range = 9
		l.Brightness = 1.2
		l.Shadows = false
		l.Parent = root
	end
end

-- собрать монстра в начале координат; потом ставить через model:PivotTo(cf)
function Monsters.build(key, mut)
	local def = Config.MonsterIndex[key] or Config.Monsters[1]
	local m = Instance.new("Model")
	m.Name = def.key
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 1, 2)
	root.CFrame = CFrame.new()
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.Parent = m
	m.PrimaryPart = root
	local builder = B[def.key] or B.slipper
	builder(ctx(m, root))
	tint(m, mut)
	m:SetAttribute("Key", def.key)
	m:SetAttribute("Mutation", mut or "")
	m:SetAttribute("Rarity", def.rarity)
	m:SetAttribute("Size", def.size)
	local r = Config.RarityIndex[def.rarity]
	if r.tier >= 4 then
		local a = Instance.new("Attachment")
		a.Name = "AuraAtt"
		a.Position = Vector3.new(0, def.size * 0.5, 0)
		a.Parent = root
		local l = Instance.new("PointLight")
		l.Name = "Aura"
		l.Color = r.color
		l.Range = 10
		l.Brightness = 0.8
		l.Shadows = false
		l.Parent = a
	end
	return m, root
end

-- подпись над монстром. line2 — нижняя строка («+25/с» или «1 к 50»)
function Monsters.label(m, line2, maxDistance)
	local root = m.PrimaryPart
	local key, mut = m:GetAttribute("Key"), m:GetAttribute("Mutation")
	local def = Config.MonsterIndex[key]
	local r = Util.rarityOf(key)
	local old = root:FindFirstChild("Label")
	if old then old:Destroy() end
	local g = Instance.new("BillboardGui")
	g.Name = "Label"
	g.Size = UDim2.new(0, 230, 0, 66)
	g.StudsOffset = Vector3.new(0, (def and def.size or 4) + 1.6, 0)
	g.MaxDistance = maxDistance or 70
	g.LightInfluence = 0
	g.AlwaysOnTop = false
	g.Parent = root
	local function line(text, y, h, color)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, h)
		t.Position = UDim2.new(0, 0, 0, y)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.RichText = true
		t.Text = text
		t.TextColor3 = color
		t.TextStrokeTransparency = 0.2
		t.Parent = g
		return t
	end
	local mu = Config.MutationIndex[mut or ""]
	local name = def and def.name or key
	if mu then name = string.format('<font color="%s">%s</font> %s', Util.hex(mu.color), mu.name, name) end
	line(name, 0, 26, Color3.new(1, 1, 1))
	line(r.name, 26, 20, r.color)
	line(line2 or "", 46, 20, Color3.fromRGB(255, 230, 120))
	return g
end

return Monsters
