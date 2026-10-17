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

-- ОХРАННИК ------------------------------------------------------------------------
-- Солдат в коробке 2×5×2, смотрит вперёд (-Z). Главная деталь — невидимая коробка: по ней бьют,
-- кликают и ищут соседей. Фигура — декор; подвижные части держатся на Weld, а клиент поворачивает
-- их C0 (дыхание, осмотр, прицеливание — World.lua):
--   GuardPelvis, Weld «GuardHips»     — ноги и пояс: разворот всей фигуры, если цель сбоку или сзади;
--   GuardTorso, Weld «GuardWaist»     — туловище: поворот к цели, дыхание;
--   GuardHead, Weld «GuardNeck»       — голова: осматривается, при стрельбе смотрит вдоль ствола;
--   GuardRifle, Weld «GuardShoulder»  — автомат: опущен или у плеча и смотрит в цель;
--   руки (GuardUpperArmR/L, GuardForearmR/L, Weld «GuardArm») сами тянутся к рукояткам автомата.
-- Все координаты — в системе блока в позе покоя: центр коробки, подошвы на дне (y = -2.5).
local G_PELVIS = Vector3.new(0, -0.12, 0)
local G_TORSO = Vector3.new(0, 0.8, 0)
local G_NECK = Vector3.new(0, 1.62, 0)
local G_HEAD = Vector3.new(0, 1.95, -0.02)
local G_SHOULDER_R = Vector3.new(0.58, 1.33, 0)
local G_SHOULDER_L = Vector3.new(-0.58, 1.33, 0)
local G_POCKET = Vector3.new(0.15, 1.5, -0.3) -- затыльник приклада у плеча, когда целится
local G_UPPER, G_FORE = 0.88, 0.9 -- плечо и предплечье (до середины кисти)
local G_POLE_R = Vector3.new(0.6, -0.8, 0.55) -- куда отводятся локти (в системе туловища)
local G_POLE_L = Vector3.new(-0.7, -0.85, 0.35)
local G_BLADE = math.rad(-28) -- целясь, разворачивается правым плечом назад: левая рука дотягивается
local G_WAIST_MAX = math.rad(65) -- дальше поворачиваются и ноги
local G_PITCH_MIN, G_PITCH_MAX = math.rad(-28), math.rad(84)
local G_SEGMENT = CFrame.Angles(0, math.pi / 2, 0) -- звено руки — цилиндр: ось X вдоль звена

-- Автомат в своей системе: начало — затыльник приклада, ствол смотрит в -Z
local G_RECEIVER = Vector3.new(0, 0.06, -0.92) -- центр ствольной коробки (деталь GuardRifle)
local G_GRIP_R = Vector3.new(0, -0.2, -0.72) -- правая кисть на пистолетной рукоятке
local G_GRIP_L = Vector3.new(0, -0.15, -1.45) -- левая — на передней рукоятке
local G_MUZZLE = Vector3.new(0, 0.06, -2.2) -- конец дульного тормоза

-- Опущенный автомат (в системе туловища): приклад у правого бока, ствол вниз-влево-вперёд,
-- магазин смотрит вниз — всё внутри коробки блока
local G_IDLE_RIFLE = (function(): CFrame
	local butt = Vector3.new(0.3, 0.4, -0.38)
	local dir = Vector3.new(-0.5, -0.83, -0.21).Unit
	local down = Vector3.new(0, -1, 0)
	local up = -(down - dir * down:Dot(dir)).Unit
	return CFrame.lookAt(butt, butt + dir, up)
end)()

export type GuardPose = {
	yaw: number, -- направление на цель вокруг оси Y блока (рад; 0 — вперёд, -Z)
	pitch: number, -- угол возвышения цели (рад)
	aim: number, -- 0 — автомат опущен, 1 — у плеча и смотрит в цель
	headYaw: number?, -- куда смотрит голова без прицеливания (рад, относительно туловища)
	headPitch: number?,
	breath: number?, -- дыхание: от -1 до 1
	sway: Vector3?, -- покачивание опущенного автомата (малые углы, рад)
	recoil: number?, -- отдача: 0..1
}

export type GuardRig = {
	hips: Weld,
	waist: Weld,
	neck: Weld,
	rifle: Weld,
	upperR: Weld,
	foreR: Weld,
	upperL: Weld,
	foreL: Weld,
}

type GuardJoints = {
	hips: CFrame,
	waist: CFrame,
	neck: CFrame,
	rifle: CFrame,
	upperR: CFrame,
	foreR: CFrame,
	upperL: CFrame,
	foreL: CFrame,
}

local GUARD_REST: GuardPose = { yaw = 0, pitch = 0, aim = 0 }

-- Угол в пределах [-π, π)
local function wrapAngle(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- Поворот к цели делится между туловищем (до G_WAIST_MAX) и ногами. Если цель точно сзади,
-- туловище снова смотрит прямо, а развёрнут весь солдат — переход через «сзади» без рывка.
local function splitTurn(turn: number): (number, number)
	local a = math.abs(turn)
	local waist = math.sign(turn) * math.min(a, G_WAIST_MAX, math.pi - a)
	return turn - waist, waist
end

-- Рука из двух звеньев: плечевой сустав s, кисть hand, локоть отводится в сторону pole
-- (всё в системе туловища). Возвращает CFrame центров плеча и предплечья (ось X — от сустава к суставу).
local function solveArm(s: Vector3, hand: Vector3, pole: Vector3): (CFrame, CFrame)
	local a, b = G_UPPER, G_FORE
	local d = hand - s
	local n = if d.Magnitude > 1e-4 then d.Unit else Vector3.new(0, -1, 0)
	local dist = math.clamp(d.Magnitude, math.abs(a - b) + 0.02, a + b - 0.001)
	-- угол в плече по теореме косинусов
	local cosA = math.clamp((a * a + dist * dist - b * b) / (2 * a * dist), -1, 1)
	local side = pole - n * pole:Dot(n)
	if side.Magnitude < 1e-4 then
		side = n:Cross(Vector3.xAxis)
	end
	side = side.Unit
	local elbow = s + (n * cosA + side * math.sqrt(1 - cosA * cosA)) * a
	local wrist = s + n * dist
	local normal = n:Cross(side) -- перпендикуляр к плоскости руки: «верх» обоих звеньев
	local upper = CFrame.lookAt((s + elbow) / 2, elbow, normal) * G_SEGMENT
	local fore = CFrame.lookAt((elbow + wrist) / 2, wrist, normal) * G_SEGMENT
	return upper, fore
end

-- C0 всех сварок охранника для позы
local function guardJoints(pose: GuardPose): GuardJoints
	local aim = math.clamp(pose.aim, 0, 1)
	local pitch = math.clamp(pose.pitch, G_PITCH_MIN, G_PITCH_MAX)
	local hipsYaw, waistYaw = splitTurn(wrapAngle(pose.yaw + G_BLADE) * aim)
	local breath = pose.breath or 0
	local hips = CFrame.new(G_PELVIS) * CFrame.Angles(0, hipsYaw, 0)
	local waist = CFrame.new(G_TORSO - G_PELVIS) * CFrame.Angles(0, waistYaw, 0)
		* CFrame.new(0, breath * 0.012, 0) * CFrame.Angles(breath * 0.012, 0, 0)
	-- голова осматривается, а при стрельбе смотрит вдоль ствола и склоняется к прикладу
	local headYaw, headPitch = pose.headYaw or 0, pose.headPitch or 0
	headYaw += (-G_BLADE - headYaw) * aim
	headPitch += (pitch * 0.8 - 0.05 - headPitch) * aim
	local neck = CFrame.new(G_NECK - G_TORSO) * CFrame.Angles(0, headYaw, 0) * CFrame.Angles(headPitch, 0, -0.22 * aim)
	-- автомат: из опущенного положения к плечу, ствол на цель (туловище развёрнуто на G_BLADE)
	local idle = G_IDLE_RIFLE
	local sway = pose.sway
	if sway then
		idle *= CFrame.Angles(sway.X, sway.Y, sway.Z)
	end
	local recoil = pose.recoil or 0
	local aimed = CFrame.new(G_POCKET - G_TORSO) * CFrame.Angles(0, -G_BLADE, 0)
		* CFrame.Angles(pitch + recoil * 0.08, 0, 0) * CFrame.new(0, 0, recoil * 0.07)
	local rifle = idle:Lerp(aimed, aim)
	local upperR, foreR = solveArm(G_SHOULDER_R - G_TORSO, rifle * G_GRIP_R, G_POLE_R)
	local upperL, foreL = solveArm(G_SHOULDER_L - G_TORSO, rifle * G_GRIP_L, G_POLE_L)
	return {
		hips = hips, waist = waist, neck = neck, rifle = rifle,
		upperR = upperR, foreR = foreR, upperL = upperL, foreL = foreL,
	}
end

-- Углы, на которые охранник поворачивается, чтобы целиться в точку (в системе блока)
function BlockFactory.guardAim(blockCF: CFrame, target: Vector3): (number, number)
	local d = blockCF:PointToObjectSpace(target) - Vector3.new(0, G_POCKET.Y, 0)
	local yaw = math.atan2(-d.X, -d.Z)
	local pitch = math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z))
	return yaw, math.clamp(pitch, G_PITCH_MIN, G_PITCH_MAX)
end

-- Где окажется дуло, когда охранник прицелится в точку. Сервер считает начало трассера отсюда,
-- клиент поворачивает фигуру по тем же формулам — выстрел вылетает из ствола.
function BlockFactory.guardMuzzle(blockCF: CFrame, target: Vector3): Vector3
	local yaw, pitch = BlockFactory.guardAim(blockCF, target)
	local j = guardJoints({ yaw = yaw, pitch = pitch, aim = 1 })
	return (blockCF * j.hips * j.waist * j.rifle):PointToWorldSpace(G_MUZZLE)
end

-- Сварки охранника; nil — если это не охранник (или детали ещё не дошли до клиента)
function BlockFactory.guardRig(block: BasePart): GuardRig?
	local function joint(parent: Instance?, partName: string, weldName: string): (Instance?, Weld?)
		local p = parent and parent:FindFirstChild(partName)
		local w = p and p:FindFirstChild(weldName)
		return p, if w and w:IsA("Weld") then w else nil
	end
	local pelvis, hips = joint(block, "GuardPelvis", "GuardHips")
	local torso, waist = joint(pelvis, "GuardTorso", "GuardWaist")
	local _, neck = joint(torso, "GuardHead", "GuardNeck")
	local _, rifle = joint(torso, "GuardRifle", "GuardShoulder")
	local _, upperR = joint(torso, "GuardUpperArmR", "GuardArm")
	local _, foreR = joint(torso, "GuardForearmR", "GuardArm")
	local _, upperL = joint(torso, "GuardUpperArmL", "GuardArm")
	local _, foreL = joint(torso, "GuardForearmL", "GuardArm")
	if hips and waist and neck and rifle and upperR and foreR and upperL and foreL then
		return {
			hips = hips, waist = waist, neck = neck, rifle = rifle,
			upperR = upperR, foreR = foreR, upperL = upperL, foreL = foreL,
		}
	end
	return nil
end

-- Поставить охранника в позу (клиент, каждый кадр для ближних охранников)
function BlockFactory.poseGuard(rig: GuardRig, pose: GuardPose)
	local j = guardJoints(pose)
	rig.hips.C0 = j.hips
	rig.waist.C0 = j.waist
	rig.neck.C0 = j.neck
	rig.rifle.C0 = j.rifle
	rig.upperR.C0 = j.upperR
	rig.foreR.C0 = j.foreR
	rig.upperL.C0 = j.upperL
	rig.foreL.C0 = j.foreL
end

local function buildGuard(part: BasePart, opts: BuildOptions)
	part.Transparency = 1
	part.CastShadow = false
	local base = part.Color
	local j = guardJoints(GUARD_REST)
	local fabric, plastic = Enum.Material.Fabric, Enum.Material.SmoothPlastic
	local function uniform(k: number): { [string]: any }
		return { Material = fabric, Color = base, Tint = k }
	end
	local black = { Material = plastic, Color = Color3.fromRGB(30, 31, 34) }
	local gunmetal = { Material = METAL, Color = Color3.fromRGB(40, 41, 45) }
	local polymer = { Material = plastic, Color = Color3.fromRGB(48, 49, 52) }
	local rubber = { Material = Enum.Material.Rubber, Color = Color3.fromRGB(32, 33, 35) }
	local leather = { Material = Enum.Material.Leather, Color = Color3.fromRGB(46, 38, 30) }
	local balaclava = Color3.fromRGB(36, 38, 40)
	local P = CFrame.new
	local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- цилиндр стоймя (ось Y)
	local ALONG = CFrame.Angles(0, math.pi / 2, 0) -- цилиндр вдоль Z
	-- детали группы: координаты в системе блока (или автомата) в позе покоя
	local function on(group: BasePart, origin: Vector3)
		return function(cf: CFrame, size: Vector3, props: { [string]: any }): BasePart
			return decor(group, P(-origin) * cf, size, props)
		end
	end

	-- НОГИ И ПОЯС
	local pelvis = rigPart(part, "GuardPelvis", "GuardHips", j.hips, CFrame.identity, Vector3.new(0.86, 0.42, 0.5), uniform(0.95))
	local legs = on(pelvis, G_PELVIS)
	legs(P(0, 0.05, 0), Vector3.new(0.92, 0.22, 0.54), { Material = fabric, Color = Color3.fromRGB(44, 42, 38) }) -- ремень
	legs(P(0, 0.05, -0.28), Vector3.new(0.14, 0.12, 0.04), { Material = METAL, Color = Color3.fromRGB(150, 150, 146) }) -- пряжка
	for _, x in { -0.34, 0.34 } do
		legs(P(x, 0, -0.3), Vector3.new(0.16, 0.2, 0.14), uniform(0.86)) -- подсумки на ремне
	end
	for _, x in { -0.22, 0.22 } do
		legs(P(x, -0.6, 0), Vector3.new(0.36, 0.95, 0.4), uniform(0.95)) -- бедро
		legs(P(x, -1.54, 0), Vector3.new(0.32, 0.95, 0.36), uniform(0.95)) -- голень
		legs(P(x, -1.12, -0.225), Vector3.new(0.3, 0.26, 0.1), rubber) -- наколенник
		legs(P(x, -2.12, -0.02), Vector3.new(0.36, 0.32, 0.42), leather) -- голенище ботинка
		legs(P(x, -2.35, -0.08), Vector3.new(0.38, 0.22, 0.62), leather) -- стопа
		legs(P(x, -2.19, -0.29), Vector3.new(0.38, 0.1, 0.2), { className = "WedgePart", Material = leather.Material, Color = leather.Color }) -- подъём
		legs(P(x, -2.47, -0.08), Vector3.new(0.4, 0.06, 0.66), rubber) -- подошва
	end
	legs(P(-0.42, -0.62, 0.02), Vector3.new(0.06, 0.28, 0.26), uniform(0.85)) -- карман на левом бедре
	legs(P(-0.43, -0.47, 0.02), Vector3.new(0.07, 0.07, 0.28), uniform(0.72)) -- клапан кармана
	legs(P(0.43, -0.45, 0.02), Vector3.new(0.08, 0.34, 0.22), black) -- кобура на правом бедре
	legs(P(0.43, -0.24, 0.06), Vector3.new(0.06, 0.14, 0.09), polymer) -- рукоятка пистолета
	legs(P(0.22, -0.72, 0), Vector3.new(0.37, 0.05, 0.41), black) -- ремешок кобуры

	-- ТУЛОВИЩЕ: куртка, бронежилет с подсумками, рюкзак с рацией
	local torso = rigPart(pelvis, "GuardTorso", "GuardWaist", j.waist, CFrame.identity, Vector3.new(0.88, 1.4, 0.46), uniform(1.05))
	local body = on(torso, G_TORSO)
	body(P(0, 0.92, 0), Vector3.new(0.92, 0.95, 0.56), uniform(0.78)) -- бронежилет
	for _, x in { -0.25, 0, 0.25 } do
		body(P(x, 0.63, -0.335), Vector3.new(0.22, 0.3, 0.12), uniform(0.9)) -- подсумки для магазинов
		body(P(x, 0.8, -0.335), Vector3.new(0.24, 0.07, 0.14), uniform(0.7)) -- клапаны
	end
	body(P(-0.22, 1.12, -0.32), Vector3.new(0.26, 0.24, 0.1), uniform(0.9)) -- нагрудный подсумок
	body(P(-0.22, 1.16, -0.375), Vector3.new(0.16, 0.1, 0.02), -- нашивка цвета участка
		{ Material = fabric, Color = opts.plotColor or Color3.fromRGB(226, 64, 64) })
	for _, x in { -0.28, 0.28 } do
		body(P(x, 1.51, 0), Vector3.new(0.22, 0.08, 0.58), uniform(0.75)) -- лямки жилета
	end
	body(P(0, 1.58, 0) * UPRIGHT, Vector3.new(0.2, 0.3, 0.3), { Shape = CYL, Material = fabric, Color = balaclava }) -- шея
	body(P(0, 0.95, 0.41), Vector3.new(0.66, 0.7, 0.3), uniform(0.85)) -- рюкзак
	body(P(0, 1.29, 0.41), Vector3.new(0.68, 0.12, 0.32), uniform(0.7))
	body(P(0.2, 1.08, 0.625), Vector3.new(0.2, 0.4, 0.15), { Material = METAL, Color = Color3.fromRGB(52, 54, 58) }) -- рация
	body(P(0.15, 1.22, 0.705), Vector3.new(0.05, 0.05, 0.02), { Material = Enum.Material.Neon, Color = Color3.fromRGB(70, 255, 100) })
	body(P(0.25, 1.82, 0.64) * UPRIGHT, Vector3.new(1.1, 0.035, 0.035), { Shape = CYL, Material = METAL, Color = Color3.fromRGB(26, 26, 28) }) -- антенна
	body(P(0.25, 2.38, 0.64), Vector3.new(0.07, 0.07, 0.07), { Shape = BALL, Material = plastic, Color = Color3.fromRGB(26, 26, 28) })

	-- ГОЛОВА: балаклава, очки, гарнитура и каска
	local head = rigPart(torso, "GuardHead", "GuardNeck", j.neck, P(G_NECK - G_HEAD), Vector3.new(0.62, 0.62, 0.62),
		{ Shape = BALL, Material = fabric, Color = balaclava })
	local face = on(head, G_HEAD)
	face(P(0, 2.15, 0), Vector3.new(0.68, 0.68, 0.68), { Shape = BALL, Material = Enum.Material.Plastic, Color = base, Tint = 1.12 }) -- каска
	face(P(0, 2.06, 0) * UPRIGHT, Vector3.new(0.04, 0.7, 0.7), { Shape = CYL, Material = Enum.Material.Plastic, Color = base, Tint = 0.95 }) -- край каски
	face(P(0, 2.16, -0.33), Vector3.new(0.14, 0.11, 0.06), black) -- крепление ночного прицела
	for _, x in { -0.335, 0.335 } do
		face(P(x, 2.1, 0), Vector3.new(0.04, 0.06, 0.26), black) -- боковые планки
		face(P(x * 0.925, 1.94, 0), Vector3.new(0.08, 0.2, 0.2), { Shape = CYL, Material = plastic, Color = Color3.fromRGB(30, 30, 32) }) -- наушники
	end
	local micFrom, micTo = Vector3.new(-0.32, 1.9, -0.06), Vector3.new(-0.12, 1.83, -0.3)
	face(CFrame.lookAt((micFrom + micTo) / 2, micTo), Vector3.new(0.03, 0.03, (micTo - micFrom).Magnitude), black) -- микрофон
	face(P(micTo), Vector3.new(0.06, 0.06, 0.06), { Shape = BALL, Material = plastic, Color = black.Color })
	face(P(0, 1.955, -0.28), Vector3.new(0.4, 0.17, 0.12), { Material = plastic, Color = Color3.fromRGB(196, 152, 118) }) -- лицо в прорези
	face(P(0, 1.955, -0.02) * UPRIGHT, Vector3.new(0.05, 0.64, 0.64), { Shape = CYL, Material = fabric, Color = Color3.fromRGB(24, 24, 26) }) -- ремешок очков
	face(P(0, 1.955, -0.33), Vector3.new(0.44, 0.13, 0.06), black) -- оправа очков
	for _, x in { -0.1, 0.1 } do
		face(P(x, 1.955, -0.36) * ALONG, Vector3.new(0.03, 0.11, 0.11),
			{ Shape = CYL, Material = Enum.Material.Glass, Color = Color3.fromRGB(255, 168, 40), Reflectance = 0.35 })
	end

	-- АВТОМАТ (координаты — в системе автомата)
	local rifle = rigPart(torso, "GuardRifle", "GuardShoulder", j.rifle, P(-G_RECEIVER), Vector3.new(0.14, 0.2, 0.62), gunmetal)
	local gun = on(rifle, G_RECEIVER)
	gun(P(0, -0.02, -0.025), Vector3.new(0.12, 0.3, 0.05), rubber) -- затыльник
	gun(P(0, -0.01, -0.26), Vector3.new(0.1, 0.26, 0.42), polymer) -- приклад
	gun(P(0, 0.14, -0.3), Vector3.new(0.08, 0.06, 0.24), polymer) -- щека
	gun(P(0, 0.08, -0.55) * ALONG, Vector3.new(0.2, 0.09, 0.09), { Shape = CYL, Material = METAL, Color = gunmetal.Color }) -- буферная трубка
	gun(P(0, -0.08, -0.96), Vector3.new(0.12, 0.12, 0.36), gunmetal) -- нижняя часть коробки
	gun(P(0, -0.22, -0.72) * CFrame.Angles(math.rad(-16), 0, 0), Vector3.new(0.1, 0.26, 0.12), polymer) -- пистолетная рукоятка
	gun(P(0, -0.16, -0.84), Vector3.new(0.03, 0.03, 0.2), black) -- спусковая скоба
	gun(P(0, -0.3, -1) * CFrame.Angles(math.rad(14), 0, 0), Vector3.new(0.09, 0.36, 0.15), { Material = METAL, Color = Color3.fromRGB(54, 52, 48) }) -- магазин
	gun(P(0.07, 0.07, -0.95), Vector3.new(0.02, 0.07, 0.16), black) -- окно выброса гильз
	gun(P(0, 0.06, -1.48), Vector3.new(0.15, 0.2, 0.5), polymer) -- цевьё
	gun(P(0, 0.17, -1.17), Vector3.new(0.07, 0.03, 1.08), black) -- планка сверху
	gun(P(0, -0.14, -1.45), Vector3.new(0.08, 0.22, 0.09), polymer) -- передняя рукоятка
	gun(P(0, 0.17, -1.77), Vector3.new(0.06, 0.13, 0.06), black) -- мушка
	gun(P(0, 0.06, -1.89) * ALONG, Vector3.new(0.34, 0.07, 0.07), { Shape = CYL, Material = METAL, Color = Color3.fromRGB(30, 30, 32) }) -- ствол
	gun(P(0, 0.06, -2.1) * ALONG, Vector3.new(0.16, 0.11, 0.11),
		{ Name = "GuardMuzzle", Shape = CYL, Material = METAL, Color = Color3.fromRGB(24, 24, 26) }) -- дульный тормоз
	-- прицел: труба, раструб объектива, окуляр, линзы и кольца крепления
	gun(P(0, 0.3, -0.95) * ALONG, Vector3.new(0.44, 0.12, 0.12), { Shape = CYL, Material = METAL, Color = black.Color })
	gun(P(0, 0.3, -1.2) * ALONG, Vector3.new(0.1, 0.16, 0.16), { Shape = CYL, Material = METAL, Color = black.Color })
	gun(P(0, 0.3, -0.71) * ALONG, Vector3.new(0.08, 0.14, 0.14), { Shape = CYL, Material = METAL, Color = black.Color })
	local lens = { Shape = CYL, Material = Enum.Material.Glass, Color = Color3.fromRGB(120, 200, 255), Reflectance = 0.4 }
	gun(P(0, 0.3, -1.255) * ALONG, Vector3.new(0.02, 0.12, 0.12), lens)
	gun(P(0, 0.3, -0.665) * ALONG, Vector3.new(0.02, 0.1, 0.1), lens)
	for _, z in { -0.82, -1.08 } do
		gun(P(0, 0.21, z), Vector3.new(0.06, 0.08, 0.06), black)
	end

	-- РУКИ: звенья на Weld, концы — в суставах; кисти держат рукоятки автомата
	local function arm(side: string, upperC0: CFrame, foreC0: CFrame)
		local upper = rigPart(torso, "GuardUpperArm" .. side, "GuardArm", upperC0, CFrame.identity,
			Vector3.new(G_UPPER, 0.28, 0.28), { Shape = CYL, Material = fabric, Color = base, Tint = 1.05 })
		decor(upper, P(-G_UPPER / 2, 0, 0), Vector3.new(0.34, 0.34, 0.34), { Shape = BALL, Material = fabric, Color = base, Tint = 0.8 }) -- плечо
		decor(upper, P(G_UPPER / 2, 0, 0), Vector3.new(0.3, 0.3, 0.3), { Shape = BALL, Material = rubber.Material, Color = rubber.Color }) -- налокотник
		local fore = rigPart(torso, "GuardForearm" .. side, "GuardArm", foreC0, CFrame.identity,
			Vector3.new(G_FORE, 0.25, 0.25), { Shape = CYL, Material = fabric, Color = base, Tint = 1.05 })
		decor(fore, P(G_FORE / 2 - 0.09, 0, 0), Vector3.new(0.08, 0.27, 0.27), { Shape = CYL, Material = fabric, Color = base, Tint = 0.75 }) -- манжета
		decor(fore, P(G_FORE / 2, 0, 0), Vector3.new(0.24, 0.2, 0.17), { Material = Enum.Material.Leather, Color = Color3.fromRGB(38, 38, 40) }) -- перчатка
	end
	arm("R", j.upperR, j.foreR)
	arm("L", j.upperL, j.foreL)
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
	elseif key == "Guard" then
		buildGuard(part, opts)
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
