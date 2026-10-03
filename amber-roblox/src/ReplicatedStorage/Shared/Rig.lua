-- Риг заключённого: модель из деталей (Part) с суставами Motor6D в стиле R15,
-- Humanoid с правильным HipHeight (стоит на полу и ходит через Humanoid:MoveTo) и Animator.
-- Плюс помощники процедурной анимации для клиента: суставы двигаются через Motor6D.C0.
--
-- Постройка (сервер и клиент; модель строится в начале координат, ноги на y = 0, лицом к −Z):
--   local R = Rig.build(opt)       -- R = { model, hum, root, parts = { Head = Part, LeftUpperArm = Part, ... } }
--   Rig.add(R, "Head", "Nose", size, offsetCF, color, material, props)  -- деталь, приваренная к части
--   Rig.ball / Rig.cyl (ось X) / Rig.wedge — то же для шара, цилиндра и клина
--   Rig.eyes(R, "Head", offsetCF, gap, d, color, opt)  -- светящиеся глаза: Neon + PointLight "EyeLight"
--   Rig.base / Rig.part / Rig.joint — своя схема (сегменты ползуна, волосы, нимб)
--   Rig.finish(R)                   -- все детали не закреплены и без столкновений (кроме корня)
--   Rig.serverSetup(model)          -- сервер: SetNetworkOwner(nil), отключить прыжки и падения
-- Анимация (клиент, каждый кадр):
--   Rig.track(model, dt); local A = Rig.state(model); Rig.begin(A)
--   Rig.basic(A) / walk / idle / lunge / stagger / crawl / twitch / dead / lookAt ...; Rig.apply(A)
-- Поворот Q задаётся в пространстве Part0 сустава: C0 = CFrame.new(orig.Position) * Q * orig.Rotation.
-- Порядок: каждый следующий Rig.rot умножается справа, то есть применяется к конечности раньше предыдущих.
local Build = require(script.Parent:WaitForChild("Build"))

local Rig = {}
Rig.mat = Build.mat     -- материал по имени с запасным (Rubber, Leather … есть не везде)
local EMPTY = {}
local ID = CFrame.new()

---------------------------------------------------------------- детали
local function setProps(o, props)
	if not props then return end
	for k, v in pairs(props) do
		if k ~= "Parent" then
			local ok = pcall(function() o[k] = v end)
			if not ok then warn("[AA] Rig: свойство " .. tostring(k)) end
		end
	end
end

local function newPart(parent, class, name, size, cf, color, material)
	local p = Instance.new(class or "Part")
	p.Name = name or "Part"
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = Build.color(color or "#8a8a8a")
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function weld(a, b)
	local w = Instance.new("Weld")
	w.Name = "Weld"
	w.Part0 = a
	w.Part1 = b
	w.C0 = a.CFrame:Inverse() * b.CFrame
	w.C1 = ID
	w.Parent = b
	return w
end
Rig.weld = weld

local function limbOf(R, limb)
	if typeof(limb) == "Instance" then return limb end
	local p = R.parts[limb]
	if not p then error("Rig: нет части " .. tostring(limb)) end
	return p
end

-- свободная деталь модели (без сварки): для своих суставов
function Rig.part(R, name, size, cf, color, material, props, class)
	local p = newPart(R.model, class, name, size, cf, color, material)
	setProps(p, props)
	R.parts[name] = R.parts[name] or p
	return p
end

-- деталь, приваренная к части limb; offset — CFrame относительно центра части
function Rig.add(R, limb, name, size, offset, color, material, props, class)
	local base = limbOf(R, limb)
	local p = newPart(R.model, class, name, size, base.CFrame * (offset or ID), color, material)
	setProps(p, props)
	weld(base, p)
	return p
end

-- то же, но cf задан в мире позы постройки (ноги на y = 0)
function Rig.addAt(R, limb, name, size, cf, color, material, props, class)
	local base = limbOf(R, limb)
	return Rig.add(R, base, name, size, base.CFrame:Inverse() * cf, color, material, props, class)
end

-- брусок от точки a до точки b (мир позы постройки), толщина th
function Rig.bar(R, limb, name, a, b, th, color, material, props)
	local len = (b - a).Magnitude
	if len < 0.01 then len = 0.01 end
	local up = math.abs((b - a).Unit.Y) > 0.95 and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
	local cf = CFrame.lookAt((a + b) / 2, b, up)
	return Rig.addAt(R, limb, name, Vector3.new(th, th, len), cf, color, material, props)
end

function Rig.ball(R, limb, name, d, offset, color, material, props)
	local size = (typeof(d) == "Vector3") and d or Vector3.new(d, d, d)
	local p = Rig.add(R, limb, name, size, offset, color, material, props)
	p.Shape = Enum.PartType.Ball
	return p
end

-- цилиндр: ось вдоль X у offset
function Rig.cyl(R, limb, name, length, d, offset, color, material, props)
	local p = Rig.add(R, limb, name, Vector3.new(length, d, d), offset, color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function Rig.wedge(R, limb, name, size, offset, color, material, props)
	return Rig.add(R, limb, name, size, offset, color, material, props, "WedgePart")
end

-- светящиеся глаза: две детали Neon «Eye» + PointLight «EyeLight» в первой
function Rig.eyes(R, limb, offset, gap, d, color, opt)
	opt = opt or EMPTY
	local list = {}
	for i, sx in ipairs({ -1, 1 }) do
		local cf = offset * CFrame.new(sx * gap / 2, 0, 0)
		local e
		if typeof(d) == "Vector3" then
			e = Rig.add(R, limb, "Eye", d, cf, color, Enum.Material.Neon)
		else
			e = Rig.ball(R, limb, "Eye", d, cf, color, Enum.Material.Neon)
		end
		e.CastShadow = false
		list[i] = e
	end
	local l = Instance.new("PointLight")
	l.Name = "EyeLight"
	l.Color = Build.color(color)
	l.Range = opt.range or 7
	l.Brightness = opt.brightness or 1.2
	l.Shadows = false
	l.Parent = list[1]
	return list
end

-- глазницы: тёмные впадины вокруг глаз
function Rig.sockets(R, limb, offset, gap, size, color)
	for _, sx in ipairs({ -1, 1 }) do
		local p = Rig.add(R, limb, "Socket", size, offset * CFrame.new(sx * gap / 2, 0, 0), color or "#120c0a")
		p.CastShadow = false
	end
end

---------------------------------------------------------------- суставы
-- Motor6D; at — мировая точка сустава в позе постройки; rot — запечённый поворот (сутулость и т.п.)
function Rig.joint(R, name, p0, p1, at, rot)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	local j = CFrame.new(at)
	m.C0 = p0.CFrame:Inverse() * j
	m.C1 = p1.CFrame:Inverse() * j
	if rot then m.C0 = m.C0 * rot end
	m:SetAttribute("BaseC0", m.C0)
	m.Parent = p1
	R.joints[name] = m
	return m
end

---------------------------------------------------------------- модель и Humanoid
-- голая основа: модель + невидимый корень + Humanoid (HipHeight по низу корня, ноги на y = 0)
function Rig.base(name, rootSize, rootY)
	local model = Instance.new("Model")
	model.Name = name or "Inmate"
	local R = { model = model, parts = {}, joints = {} }
	local root = newPart(model, "Part", "HumanoidRootPart", rootSize, CFrame.new(0, rootY, 0), "#ffffff")
	root.Transparency = 1
	root.CanCollide = true
	root.CanTouch = true
	root.Massless = false
	root.CastShadow = false
	R.root = root
	R.parts.HumanoidRootPart = root
	model.PrimaryPart = root
	local hum = Instance.new("Humanoid")
	setProps(hum, {
		RigType = Enum.HumanoidRigType.R15,
		DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None,
		HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff,
		BreakJointsOnDeath = false,
		RequiresNeck = false,
		AutoJumpEnabled = false,
		UseJumpPower = true,
		JumpPower = 0,
		WalkSpeed = 10,
		MaxSlopeAngle = 70,
		HipHeight = math.max(0.05, rootY - rootSize.Y / 2),
	})
	hum.Parent = model
	local an = Instance.new("Animator")
	an.Parent = hum
	R.hum = hum
	model:SetAttribute("RootHeight", rootY)
	return R
end

-- гуманоид. opt (в стадах, всё умножается на s):
--   s, footH, footL, legW, hipX, legU, legL, ltH, utH, torsoW, torsoD, armW, armU, armL, hand, neck, head (Vector3)
--   hunch (рад, сутулость), crawl (низкий корень), rootSize, rootY, stride (стадов на шаг-цикл)
--   цвета: skin, shirt, sleeve, forearm, pants, shin, belt, shoes, hands; cloth / skinMat — материалы
function Rig.build(opt)
	opt = opt or EMPTY
	local s = opt.s or 1
	local function o(k, d) return (opt[k] or d) * s end
	local footH, footL, legW, hipX = o("footH", 0.35), o("footL", 1.05), o("legW", 0.72), o("hipX", 0.45)
	local legU, legL, ltH, utH = o("legU", 1.1), o("legL", 1.1), o("ltH", 0.7), o("utH", 1.4)
	local torsoW, torsoD = o("torsoW", 1.9), o("torsoD", 0.95)
	local armW, armU, armL, hand, neck = o("armW", 0.58), o("armU", 1.15), o("armL", 1.05), o("hand", 0.5), o("neck", 0.15)
	local head = (opt.head or Vector3.new(1.1, 1.15, 1.1)) * s
	local skin = opt.skin or "#d8b89a"
	local shirt = opt.shirt or "#5a5a5a"
	local sleeve = opt.sleeve or shirt
	local forearm = opt.forearm or sleeve
	local pants = opt.pants or "#333333"
	local shin = opt.shin or pants
	local belt = opt.belt or pants
	local shoes = opt.shoes or "#222222"
	local hands = opt.hands or skin
	local cloth = opt.cloth or Enum.Material.Fabric
	local skinMat = opt.skinMat or Enum.Material.SmoothPlastic

	local hipY = footH + legL + legU
	local rootSize = opt.rootSize or Vector3.new(2 * s, 2 * s, 1 * s)
	local rootY = opt.rootY or (hipY + 0.2 * s)
	if opt.crawl and not opt.rootSize then
		rootSize = Vector3.new(2 * s, 1.6 * s, 2 * s)
		rootY = opt.rootY or (0.8 * s + 0.4)
	end
	local R = Rig.base(opt.name, rootSize, rootY)
	local model, P = R.model, R.parts
	R.s = s

	-- ноги
	for _, side in ipairs({ "Left", "Right" }) do
		local x = ((side == "Left") and -1 or 1) * hipX
		P[side .. "Foot"] = newPart(model, "Part", side .. "Foot", Vector3.new(legW * 1.02, footH, footL), CFrame.new(x, footH / 2, -footL * 0.18), shoes, cloth)
		P[side .. "LowerLeg"] = newPart(model, "Part", side .. "LowerLeg", Vector3.new(legW * 0.92, legL, legW * 0.92), CFrame.new(x, footH + legL / 2, 0), shin, cloth)
		P[side .. "UpperLeg"] = newPart(model, "Part", side .. "UpperLeg", Vector3.new(legW, legU, legW), CFrame.new(x, footH + legL + legU / 2, 0), pants, cloth)
	end
	-- туловище и голова
	local lt0 = hipY - 0.2 * s
	local waistY = lt0 + ltH
	local neckY = waistY + utH
	P.LowerTorso = newPart(model, "Part", "LowerTorso", Vector3.new(torsoW * 0.92, ltH, torsoD * 0.95), CFrame.new(0, lt0 + ltH / 2, 0), belt, cloth)
	P.UpperTorso = newPart(model, "Part", "UpperTorso", Vector3.new(torsoW, utH, torsoD), CFrame.new(0, waistY + utH / 2, 0), shirt, cloth)
	P.Head = newPart(model, "Part", "Head", head, CFrame.new(0, neckY + neck + head.Y / 2, 0), skin, skinMat)
	-- руки
	local shY = neckY - armW * 0.55
	local armTop = shY + armW * 0.45
	local elbowY = armTop - armU
	local wristY = elbowY - armL
	for _, side in ipairs({ "Left", "Right" }) do
		local x = ((side == "Left") and -1 or 1) * (torsoW / 2 + armW / 2)
		P[side .. "UpperArm"] = newPart(model, "Part", side .. "UpperArm", Vector3.new(armW, armU, armW), CFrame.new(x, armTop - armU / 2, 0), sleeve, cloth)
		P[side .. "LowerArm"] = newPart(model, "Part", side .. "LowerArm", Vector3.new(armW * 0.9, armL, armW * 0.9), CFrame.new(x, elbowY - armL / 2, 0), forearm, cloth)
		P[side .. "Hand"] = newPart(model, "Part", side .. "Hand", Vector3.new(armW * 0.95, hand, armW * 0.7), CFrame.new(x, wristY - hand / 2, 0), hands, skinMat)
	end

	-- суставы (имена как у R15)
	local hunch = opt.hunch or 0
	local root = R.root
	Rig.joint(R, "Root", root, P.LowerTorso, Vector3.new(0, hipY, 0))
	Rig.joint(R, "Waist", P.LowerTorso, P.UpperTorso, Vector3.new(0, waistY, 0), CFrame.Angles(-hunch, 0, 0))
	Rig.joint(R, "Neck", P.UpperTorso, P.Head, Vector3.new(0, neckY, 0), CFrame.Angles(hunch * 0.85, 0, 0))
	for _, side in ipairs({ "Left", "Right" }) do
		local sx = (side == "Left") and -1 or 1
		local ax = sx * (torsoW / 2 + armW / 2)
		Rig.joint(R, side .. "Shoulder", P.UpperTorso, P[side .. "UpperArm"], Vector3.new(ax, shY, 0), CFrame.Angles(hunch, 0, 0))
		Rig.joint(R, side .. "Elbow", P[side .. "UpperArm"], P[side .. "LowerArm"], Vector3.new(ax, elbowY, 0))
		Rig.joint(R, side .. "Wrist", P[side .. "LowerArm"], P[side .. "Hand"], Vector3.new(ax, wristY, 0))
		Rig.joint(R, side .. "Hip", P.LowerTorso, P[side .. "UpperLeg"], Vector3.new(sx * hipX, hipY, 0))
		Rig.joint(R, side .. "Knee", P[side .. "UpperLeg"], P[side .. "LowerLeg"], Vector3.new(sx * hipX, footH + legL, 0))
		Rig.joint(R, side .. "Ankle", P[side .. "LowerLeg"], P[side .. "Foot"], Vector3.new(sx * hipX, footH, 0))
	end

	R.hipY, R.neckY, R.waistY, R.shY = hipY, neckY, waistY, shY
	R.legU, R.legL, R.footH = legU, legL, footH
	R.armLen = armU + armL + hand
	model:SetAttribute("HipY", hipY)
	model:SetAttribute("LegLen", legU + legL)
	model:SetAttribute("ArmLen", R.armLen)
	model:SetAttribute("Height", neckY + neck + head.Y)
	model:SetAttribute("Stride", opt.stride or ((legU + legL) * 2.4))
	if opt.crawl then model:SetAttribute("Crawl", true) end
	return R
end

-- после постройки: всё не закреплено, детали без массы и без столкновений; корень сталкивается
function Rig.finish(R)
	local model = (typeof(R) == "Instance") and R or R.model
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			if d:GetAttribute("Fixed") ~= true then d.Anchored = false end
			if d ~= root then
				d.Massless = true
				d.CanCollide = false
				d.CanTouch = false
			end
		end
	end
	return model
end

-- сервер: физика NPC на сервере (SetNetworkOwner(nil) в pcall)
function Rig.own(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and not d.Anchored then
			pcall(function() d:SetNetworkOwner(nil) end)
		end
	end
end

function Rig.serverSetup(model)
	Rig.own(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	for _, name in ipairs({ "Jumping", "Climbing", "FallingDown", "Ragdoll", "Seated", "Swimming", "PlatformStanding", "Dead" }) do
		pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType[name], false) end)
	end
end

---------------------------------------------------------------- анимация (клиент)
local states = setmetatable({}, { __mode = "k" })

-- состояние анимации модели: суставы с исходным C0, скорость, фаза шага, Anim
function Rig.state(model)
	local A = states[model]
	if A then return A end
	A = {
		model = model, j = {}, t = 0, dt = 1 / 60, speed = 0, vy = 0, vel = Vector3.new(), phase = 0,
		anim = "", animT = 0, data = {}, manual = {}, sharp = {},
		root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart"),
		seed = math.random() * 100,
	}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			local base = d:GetAttribute("BaseC0")
			if typeof(base) ~= "CFrame" then base = d.C0 end
			A.j[d.Name] = { m = d, base = base, pos = CFrame.new(base.Position), rot = base - base.Position, cur = ID, tgt = ID }
		end
	end
	A.stride = model:GetAttribute("Stride") or 5
	A.hipY = model:GetAttribute("HipY") or 2.5
	A.rootH = model:GetAttribute("RootHeight") or 3
	A.legLen = model:GetAttribute("LegLen") or 2.2
	states[model] = A
	return A
end

-- скорость по смещению корня, фаза шага, смена Anim
function Rig.track(model, dt)
	local A = Rig.state(model)
	A.dt = dt
	A.t = A.t + dt
	local root = A.root
	if root and root.Parent then
		local p = root.Position
		if A.last and dt > 0 then
			local v = (p - A.last) / dt
			if v.Magnitude > 90 then v = Vector3.new() end
			A.vel = A.vel:Lerp(v, math.min(1, dt * 10))
		end
		A.last = p
	end
	A.speed = Vector3.new(A.vel.X, 0, A.vel.Z).Magnitude
	A.vy = A.vel.Y
	A.phase = A.phase + dt * A.speed / A.stride * math.pi * 2
	local anim = model:GetAttribute("Anim") or ""
	local n = model:GetAttribute("AnimN") or 0
	if anim ~= A.anim or n ~= A.animN then
		A.animN = n
		A.prevAnim = A.anim
		A.anim = anim
		A.animT = 0
	else
		A.animT = A.animT + dt
	end
	A.stunned = model:GetAttribute("Stunned") == true
	return A
end

function Rig.begin(A)
	for _, j in pairs(A.j) do j.tgt = ID end
end

function Rig.rot(A, name, x, y, z)
	local j = A.j[name]
	if j then j.tgt = j.tgt * CFrame.Angles(x or 0, y or 0, z or 0) end
end

function Rig.move(A, name, x, y, z)
	local j = A.j[name]
	if j then j.tgt = CFrame.new(x or 0, y or 0, z or 0) * j.tgt end
end

function Rig.set(A, name, cf)
	local j = A.j[name]
	if j then j.tgt = j.tgt * cf end
end

-- сустав встанет в цель сразу, без сглаживания (подёргивания)
function Rig.snap(A, name)
	local j = A.j[name]
	if j then j.snap = true end
end

-- записать C0 всех суставов (кроме A.manual[имя]); sharp — скорость сглаживания
function Rig.apply(A, sharp)
	local base = 1 - math.exp(-(sharp or 14) * A.dt)
	for name, j in pairs(A.j) do
		if not A.manual[name] and j.m.Parent then
			if j.snap then
				j.cur = j.tgt
				j.snap = false
			else
				local k = A.sharp[name]
				j.cur = j.cur:Lerp(j.tgt, k and (1 - math.exp(-k * A.dt)) or base)
			end
			j.m.C0 = j.pos * j.cur * j.rot
		end
	end
end

-- плавная шумовая функция для «живых» движений
function Rig.wobble(t, seed)
	seed = seed or 0
	return math.sin(t * 1.0 + seed) * 0.5 + math.sin(t * 2.31 + seed * 1.7) * 0.3 + math.sin(t * 0.37 + seed * 0.3) * 0.2
end

-- шаг: amt — размах (0..1.3), o.leg / o.arm / o.bob / o.lean / o.sway
function Rig.walk(A, amt, o)
	o = o or EMPTY
	if amt <= 0.001 then return end
	local s, c = math.sin(A.phase), math.cos(A.phase)
	local leg, arm = (o.leg or 0.7) * amt, (o.arm or 0.55) * amt
	Rig.rot(A, "LeftHip", s * leg, 0, 0)
	Rig.rot(A, "RightHip", -s * leg, 0, 0)
	Rig.rot(A, "LeftKnee", -math.max(0, c) * leg * 1.25, 0, 0)
	Rig.rot(A, "RightKnee", -math.max(0, -c) * leg * 1.25, 0, 0)
	Rig.rot(A, "LeftAnkle", math.max(0, c) * leg * 0.35, 0, 0)
	Rig.rot(A, "RightAnkle", math.max(0, -c) * leg * 0.35, 0, 0)
	Rig.rot(A, "LeftShoulder", -s * arm, 0, 0)
	Rig.rot(A, "RightShoulder", s * arm, 0, 0)
	Rig.rot(A, "LeftElbow", (0.2 + math.max(0, -s) * 0.35) * amt, 0, 0)
	Rig.rot(A, "RightElbow", (0.2 + math.max(0, s) * 0.35) * amt, 0, 0)
	local bob = (o.bob or 0.18) * amt
	Rig.move(A, "Root", 0, math.abs(c) * bob - bob * 0.6, 0)
	Rig.rot(A, "Root", -(o.lean or 0.06) * amt, -s * 0.06 * amt, s * (o.sway or 0.03) * amt)
	Rig.rot(A, "Waist", 0, s * 0.12 * amt, 0)
end

-- дыхание и неспешные повороты головы
function Rig.idle(A, amt, o)
	o = o or EMPTY
	amt = amt or 1
	local t = A.t
	local br = math.sin(t * (o.rate or 1.6) + A.seed)
	Rig.rot(A, "Waist", br * 0.035 * amt, 0, 0)
	Rig.rot(A, "LeftShoulder", 0, 0, -(0.04 + br * 0.025) * amt)
	Rig.rot(A, "RightShoulder", 0, 0, (0.04 + br * 0.025) * amt)
	Rig.rot(A, "Neck", (br * 0.03 + Rig.wobble(t * 0.4, A.seed + 3) * 0.12) * amt, Rig.wobble(t * 0.35, A.seed) * (o.look or 0.6) * amt, 0)
end

-- выпад для удара: k 0..1
function Rig.lunge(A, k)
	if k <= 0 then return end
	Rig.move(A, "Root", 0, -0.3 * k, -1.1 * k)
	Rig.rot(A, "Root", -0.3 * k, 0, 0)
	Rig.rot(A, "Waist", -0.25 * k, 0, 0)
	Rig.rot(A, "Neck", 0.35 * k, 0, 0)
	Rig.rot(A, "LeftShoulder", 1.75 * k, 0, -0.3 * k)
	Rig.rot(A, "RightShoulder", 1.75 * k, 0, 0.3 * k)
	Rig.rot(A, "LeftElbow", 0.15 * k, 0, 0)
	Rig.rot(A, "RightElbow", 0.15 * k, 0, 0)
	Rig.rot(A, "LeftWrist", -0.4 * k, 0, 0)
	Rig.rot(A, "RightWrist", -0.4 * k, 0, 0)
	Rig.rot(A, "LeftHip", 0.45 * k, 0, 0)
	Rig.rot(A, "RightHip", -0.35 * k, 0, 0)
	Rig.rot(A, "LeftKnee", -0.5 * k, 0, 0)
end

-- кривая удара по времени с начала анимации
function Rig.strike(t)
	if t < 0.16 then return t / 0.16 end
	if t < 0.4 then return 1 end
	return math.max(0, 1 - (t - 0.4) / 0.3)
end

-- оглушён: шатается, голова болтается
function Rig.stagger(A, k)
	k = k or 1
	local t = A.t
	Rig.move(A, "Root", 0, -0.35 * k, 0)
	Rig.rot(A, "Root", math.sin(t * 3.1) * 0.1 * k, math.sin(t * 1.3) * 0.15 * k, math.sin(t * 2.3) * 0.18 * k)
	Rig.rot(A, "Waist", 0.15 * k, 0, math.sin(t * 2.7) * 0.1 * k)
	Rig.rot(A, "Neck", 0.45 * k, 0, (0.5 + math.sin(t * 2) * 0.25) * k)
	Rig.rot(A, "LeftShoulder", math.sin(t * 3) * 0.3 * k, 0, -0.2 * k)
	Rig.rot(A, "RightShoulder", -math.sin(t * 3) * 0.3 * k, 0, 0.2 * k)
	Rig.rot(A, "LeftHip", 0.3 * k, 0, 0)
	Rig.rot(A, "RightHip", 0.25 * k, 0, 0)
	Rig.rot(A, "LeftKnee", -0.55 * k, 0, 0)
	Rig.rot(A, "RightKnee", -0.45 * k, 0, 0)
end

-- на четвереньках: amt — вес позы, o.tilt — наклон корпуса, o.drop — насколько опустить таз, o.gait — размах
function Rig.crawl(A, amt, o)
	o = o or EMPTY
	if amt <= 0.001 then return end
	local k = amt
	local tilt = o.tilt or 1.3
	local drop = o.drop or math.max(0, A.hipY - A.legLen * 0.55)
	local s = math.sin(A.phase * 1.3)
	local g = (o.gait or 0.5) * math.clamp(A.speed / 8, 0.15, 1.2)
	Rig.move(A, "Root", 0, -drop * k, 0)
	Rig.rot(A, "Root", -tilt * k, 0, s * 0.05 * k)
	Rig.rot(A, "Waist", 0.1 * k, s * 0.1 * k, 0)
	Rig.rot(A, "Neck", tilt * 0.9 * k, 0, 0)
	Rig.rot(A, "LeftShoulder", (tilt + 0.35 + s * g) * k, 0, -0.2 * k)
	Rig.rot(A, "RightShoulder", (tilt + 0.35 - s * g) * k, 0, 0.2 * k)
	Rig.rot(A, "LeftElbow", (0.35 + math.max(0, -s) * 0.4) * k, 0, 0)
	Rig.rot(A, "RightElbow", (0.35 + math.max(0, s) * 0.4) * k, 0, 0)
	Rig.rot(A, "LeftHip", (tilt - 0.25 - s * g * 0.8) * k, 0, -0.1 * k)
	Rig.rot(A, "RightHip", (tilt - 0.25 + s * g * 0.8) * k, 0, 0.1 * k)
	Rig.rot(A, "LeftKnee", -(1.35 + math.max(0, s) * 0.3) * k, 0, 0)
	Rig.rot(A, "RightKnee", -(1.35 + math.max(0, -s) * 0.3) * k, 0, 0)
end

-- резкие подёргивания суставов из списка (для ужаса); amt — сила, rate — средний интервал, с
function Rig.twitch(A, amt, list, rate)
	local tw = A.tw
	if not tw then
		tw = { next = 0, stop = 0 }
		A.tw = tw
	end
	if A.t >= tw.next then
		tw.name = list[math.random(#list)]
		tw.cf = CFrame.Angles((math.random() - 0.5) * 0.9 * amt, (math.random() - 0.5) * 1.3 * amt, (math.random() - 0.5) * 0.9 * amt)
		tw.stop = A.t + 0.05 + math.random() * 0.12
		tw.next = A.t + (rate or 0.6) * (0.3 + math.random() * 1.4)
	end
	if tw.name and A.t < tw.stop then
		Rig.set(A, tw.name, tw.cf)
		Rig.snap(A, tw.name)
	end
end

-- падает замертво: k 0..1
function Rig.dead(A, k)
	Rig.move(A, "Root", 0, -(A.hipY - 0.7) * k, 0.4 * k)
	Rig.rot(A, "Root", 1.35 * k, 0, 0.25 * k)
	Rig.rot(A, "Neck", -0.4 * k, 0, 0.6 * k)
	Rig.rot(A, "LeftShoulder", 2.2 * k, 0, -0.9 * k)
	Rig.rot(A, "RightShoulder", 1.6 * k, 0, 1.1 * k)
	Rig.rot(A, "LeftHip", -0.2 * k, 0, -0.3 * k)
	Rig.rot(A, "RightHip", 0.3 * k, 0, 0.25 * k)
	Rig.rot(A, "LeftKnee", -0.6 * k, 0, 0)
end

-- удары кулаками сверху (окно, дверь): k 0..1
function Rig.pound(A, k)
	local t = A.t
	Rig.rot(A, "Root", -0.1 * k, 0, 0)
	Rig.rot(A, "LeftShoulder", (2.4 + math.sin(t * 10) * 0.6) * k, 0, 0.15 * k)
	Rig.rot(A, "RightShoulder", (2.4 - math.sin(t * 10) * 0.6) * k, 0, -0.15 * k)
	Rig.rot(A, "LeftElbow", (0.6 + math.sin(t * 10) * 0.4) * k, 0, 0)
	Rig.rot(A, "RightElbow", (0.6 - math.sin(t * 10) * 0.4) * k, 0, 0)
	Rig.rot(A, "Neck", -0.2 * k, 0, 0)
end

-- тянется рукой вперёд (вытащить из шкафа, открыть дверцу)
function Rig.reach(A, k, side)
	side = side or "Right"
	local sx = (side == "Right") and 1 or -1
	Rig.rot(A, "Root", -0.2 * k, 0, 0)
	Rig.rot(A, side .. "Shoulder", 1.5 * k, 0, sx * 0.1 * k)
	Rig.rot(A, side .. "Elbow", 0.25 * k, 0, 0)
	Rig.rot(A, "Neck", 0.15 * k, 0, 0)
end

-- повернуть сустав (обычно Neck) к точке мира; макс. углы maxYaw / maxPitch
function Rig.lookAt(A, name, world, amt, maxYaw, maxPitch)
	local root = A.root
	if not root or amt <= 0 then return end
	local rel = root.CFrame:PointToObjectSpace(world) - Vector3.new(0, A.hipY + 1.5 - A.rootH, 0)
	local flat = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
	if flat < 0.1 then return end
	local yaw = math.clamp(math.atan2(-rel.X, -rel.Z), -(maxYaw or 1.2), maxYaw or 1.2)
	local pitch = math.clamp(math.atan2(rel.Y, flat), -(maxPitch or 0.7), maxPitch or 0.7)
	Rig.rot(A, name, pitch * amt, yaw * amt, 0)
end

-- общее поведение по Anim: шаг/покой, удар, оглушение, смерть, двери, окна, укрытия
function Rig.basic(A, o)
	o = o or EMPTY
	local anim = A.anim
	if anim == "dead" then
		Rig.dead(A, math.min(1, A.animT * 2.5))
		return "dead"
	end
	if anim == "stunned" or A.stunned then
		Rig.stagger(A, 1)
		return "stunned"
	end
	local mv = math.clamp(A.speed / (o.walkRef or 10), 0, o.maxStride or 1.25)
	if mv > 0.06 then
		Rig.walk(A, mv, o.walk)
	else
		Rig.idle(A, 1, o.idle)
	end
	if anim == "attack" then
		Rig.lunge(A, Rig.strike(A.animT))
	elseif anim == "hurt" then
		Rig.rot(A, "Root", 0.25 * math.max(0, 1 - A.animT * 3), 0, 0)
		Rig.rot(A, "Neck", -0.4 * math.max(0, 1 - A.animT * 3), 0, 0)
	elseif anim == "bash" then
		local k = Rig.strike(A.animT)
		Rig.move(A, "Root", 0, 0, -0.8 * k)
		Rig.rot(A, "Root", -0.2 * k, 0.5 * k, 0)
		Rig.rot(A, "RightShoulder", 1.2 * k, 0, 0.6 * k)
		Rig.rot(A, "LeftShoulder", 0.8 * k, 0, -0.4 * k)
	elseif anim == "break" then
		Rig.pound(A, 1)
	elseif anim == "vault" then
		Rig.rot(A, "Root", -0.5, 0, 0)
		Rig.rot(A, "LeftShoulder", 1.6, 0, -0.2)
		Rig.rot(A, "RightShoulder", 1.6, 0, 0.2)
		Rig.rot(A, "LeftHip", 1.2, 0, 0)
		Rig.rot(A, "RightHip", 0.6, 0, 0)
		Rig.rot(A, "LeftKnee", -1.4, 0, 0)
		Rig.rot(A, "RightKnee", -1.0, 0, 0)
	elseif anim == "pull" or anim == "inspect" then
		Rig.reach(A, math.min(1, A.animT * 4), "Right")
		if anim == "pull" then Rig.reach(A, math.min(1, A.animT * 4), "Left") end
	elseif anim == "look" or anim == "search" then
		Rig.rot(A, "Neck", 0, math.sin(A.t * 0.9 + A.seed) * 0.8, 0)
	end
	return anim
end

---------------------------------------------------------------- вид (клиент)
-- детали модели с исходной прозрачностью (кэш)
local function partsOf(A)
	if A.parts then return A.parts end
	local list = {}
	for _, d in ipairs(A.model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then table.insert(list, d) end
	end
	A.parts = list
	return list
end

-- локальная прозрачность всей модели (0 — видна, 1 — не видна); keep(part) -> true — не трогать
function Rig.fade(A, alpha, keep)
	if A.fadeA == alpha and not keep then return end
	A.fadeA = alpha
	for _, p in ipairs(partsOf(A)) do
		if p.Parent then
			if keep and keep(p) then p.LocalTransparencyModifier = 0 else p.LocalTransparencyModifier = alpha end
		end
	end
end

-- свечение глаз: k 0..1, color — новый цвет (необязательно)
function Rig.glow(A, k, color)
	local eyes = A.eyes
	if not eyes then
		eyes = {}
		for _, d in ipairs(A.model:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "Eye" then
				table.insert(eyes, { p = d, c = d.Color })
			elseif d:IsA("Light") and d.Name == "EyeLight" then
				A.eyeLight = d
				A.eyeLightB = d.Brightness
				A.eyeLightC = d.Color
			end
		end
		A.eyes = eyes
	end
	k = math.clamp(k, 0, 1.5)
	local dark = Color3.new(0.05, 0.05, 0.05)
	for _, e in ipairs(eyes) do
		if e.p.Parent then e.p.Color = dark:Lerp(color or e.c, math.min(1, k)) end
	end
	local l = A.eyeLight
	if l and l.Parent then
		l.Brightness = (A.eyeLightB or 1) * k
		l.Color = color or A.eyeLightC or l.Color
		l.Enabled = k > 0.02
	end
end

return Rig
