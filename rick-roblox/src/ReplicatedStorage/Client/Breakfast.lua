-- Завтрак: миска, коробка хлопьев «Хрусти-О», молоко и ложка (только у этого игрока)
-- и их анимации: насыпать хлопья, налить молоко, съесть ложку.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Breakfast = {}
Breakfast.__index = Breakfast
local Config, B, Audio, U, Outline, Cine

function Breakfast.init(ctx)
	Config, B, Audio, U, Outline, Cine = ctx.Config, ctx.Build, ctx.Audio, ctx.Util, ctx.Outline, ctx.Cine
end

local function noCollide(m)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
end

-- «оснастка»: запоминаем положение каждой детали относительно опорной точки модели,
-- потом ставим детали точно (без накопления ошибок, как бывает при частом PivotTo)
local function rig(m, pivot)
	local r = { pivot = pivot, parts = {} }
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then table.insert(r.parts, { p = p, off = pivot:ToObjectSpace(p.CFrame) }) end
	end
	return r
end
local function setRig(r, cf)
	r.pivot = cf
	for _, e in ipairs(r.parts) do e.p.CFrame = cf * e.off end
end

-- плавно двигать оснастку за время t
local function moveModel(r, toCF, t, style)
	local v = Instance.new("CFrameValue")
	v.Value = r.pivot
	v.Changed:Connect(function(cf) setRig(r, cf) end)
	local tw = TweenService:Create(v, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Value = toCF })
	tw:Play()
	tw.Completed:Connect(function() v:Destroy() end)
	return tw
end

function Breakfast.new(markers)
	local self = setmetatable({}, Breakfast)
	local m = Instance.new("Model")
	m.Name = "RM_Breakfast"
	self.model = m
	local bowlCF = markers:WaitForChild("BowlSpot").CFrame
	local boxCF = markers:WaitForChild("BoxSpot").CFrame
	local milkCF = markers:WaitForChild("MilkSpot").CFrame
	self.bowlTop = bowlCF.Position + Vector3.new(0, 0.62, 0)

	-- миска: настоящая полая (кольцо из наклонных стенок + дно), голубая каёмка
	local bowl = B.model(m, "Bowl")
	B.outline(bowl)
	local SEG, R0, R1, BH = 24, 0.6, 0.8, 0.55
	local wallLen = math.sqrt((R1 - R0) ^ 2 + BH ^ 2)
	local tilt = math.atan2(R1 - R0, BH)
	for i = 0, SEG - 1 do
		local a = i / SEG * math.pi * 2
		local rm = (R0 + R1) / 2
		local arc = 2 * math.pi * R1 / SEG * 1.15
		local cf = bowlCF * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.08 + BH / 2, -rm) * CFrame.Angles(-tilt, 0, 0)
		B.part(bowl, "Wall", Vector3.new(arc, wallLen, 0.07), cf, "#FFFFFF")
		B.part(bowl, "Rim", Vector3.new(arc, 0.07, 0.1), bowlCF * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.08 + BH, -R1), "#5A86E0")
	end
	B.vcyl(bowl, "Bottom", 0.1, R0 * 2 + 0.05, bowlCF * CFrame.new(0, 0.1, 0), "#F2F5FA")
	B.vcyl(bowl, "Foot", 0.08, 0.95, bowlCF * CFrame.new(0, 0.04, 0), "#DCE6F2")
	self.R0, self.R1, self.BH = R0, R1, BH
	-- содержимое: горка хлопьев, молоко и колечки «Хрусти-О» на поверхности
	self.cereal = B.vcyl(m, "Cereal", 0.02, 1.2, bowlCF * CFrame.new(0, 0.2, 0), "#D99A3E")
	self.milk = B.vcyl(m, "Milk", 0.02, 1.25, bowlCF * CFrame.new(0, 0.2, 0), "#FBFBF7")
	self.cereal.Transparency = 1
	self.milk.Transparency = 1
	self.bits = {}
	local rnd = Random.new(7)
	local GOLD = { "#E8A93E", "#D98A2B", "#F2C14E", "#C9792A", "#EDB650" }
	for i = 1, 28 do
		local a = rnd:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rnd:NextNumber()) * 0.85
		local ring = B.vcyl(m, "Ring", 0.07, 0.22, CFrame.new(), GOLD[rnd:NextInteger(1, #GOLD)])
		local hole = B.vcyl(m, "Hole", 0.075, 0.08, CFrame.new(), "#7A4A1C")
		ring.Transparency = 1
		hole.Transparency = 1
		table.insert(self.bits, { p = ring, h = hole, a = a, r = r, tx = rnd:NextNumber(-0.4, 0.4), tz = rnd:NextNumber(-0.4, 0.4),
			dy = rnd:NextNumber(0, 0.05), spin = rnd:NextNumber(0, 6.28) })
	end
	-- салфетка-подложка под миской и рассыпанные колечки у коробки
	local mat = B.part(m, "Placemat", Vector3.new(2.4, 0.03, 3.4), bowlCF * CFrame.new(0, 0.015, -0.2), "#E2504A", Enum.Material.Fabric)
	local mg0 = B.surface(mat, Enum.NormalId.Top, 40)
	for k = 0, 5 do B.rect(mg0, 0, k / 6, 1, 1 / 12, "#F4F0E8", { BackgroundTransparency = 0.15 }) end
	for k = 0, 3 do B.rect(mg0, k / 4, 0, 1 / 8, 1, "#F4F0E8", { BackgroundTransparency = 0.55 }) end
	for k, off in ipairs({ { 1.3, 1.25 }, { 1.6, 1.05 }, { 1.15, 1.55 }, { 1.9, 1.4 } }) do
		local cf = bowlCF * CFrame.new(off[1], 0.04, off[2]) * CFrame.Angles(0, k, 0)
		B.vcyl(m, "Spilled", 0.06, 0.22, cf, GOLD[k])
		B.vcyl(m, "SpilledHole", 0.065, 0.08, cf, "#7A4A1C")
	end
	-- стакан апельсинового сока
	local juice = B.model(m, "Juice")
	B.outline(juice)
	local jcf = bowlCF * CFrame.new(0.55, 0, 1.55)
	B.vcyl(juice, "Glass", 0.95, 0.5, jcf * CFrame.new(0, 0.475, 0), "#DDF2FF", Enum.Material.Glass, { Transparency = 0.6 })
	B.vcyl(juice, "OJ", 0.7, 0.44, jcf * CFrame.new(0, 0.38, 0), "#FFA526")
	B.vcyl(juice, "Foam", 0.04, 0.44, jcf * CFrame.new(0, 0.75, 0), "#FFD27A")
	self.bowlCF = bowlCF

	-- коробка хлопьев (лицом к Морти: Морти сидит с запада)
	local box = B.model(m, "CerealBox")
	B.outline(box)
	local boxBase = boxCF * CFrame.Angles(0, math.rad(90), 0)
	local body = B.part(box, "Body", Vector3.new(1.2, 1.7, 0.45), boxBase * CFrame.new(0, 0.85, 0), "#E2504A")
	B.part(box, "Flap", Vector3.new(1.2, 0.04, 0.3), boxBase * CFrame.new(0, 1.74, -0.28) * CFrame.Angles(math.rad(-35), 0, 0), "#C83F3A")
	B.part(box, "Side", Vector3.new(0.02, 1.6, 0.4), boxBase * CFrame.new(0.61, 0.85, 0), "#F2D85A")
	local g = B.surface(body, Enum.NormalId.Front, 140)
	B.rect(g, 0, 0, 1, 1, "#E2504A")
	B.rect(g, 0, 0, 1, 0.24, "#C83F3A")
	B.text(g, 0.05, 0.03, 0.9, 0.18, "ХРУСТИ-О", "#FFFFFF", Enum.Font.GothamBlack, { TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(90, 20, 20) })
	-- нарисованная миска с колечками
	local clipBowl = B.rect(g, 0.12, 0.46, 0.76, 0.26, "#E2504A", { ClipsDescendants = true, BackgroundTransparency = 1 })
	B.circle(clipBowl, 0, -1, 1, 2, "#FFFFFF")
	B.rect(clipBowl, 0, 0, 1, 0.12, "#5A86E0")
	for k, p in ipairs({ { 0.2, 0.36 }, { 0.38, 0.31 }, { 0.56, 0.33 }, { 0.3, 0.42 }, { 0.48, 0.41 }, { 0.65, 0.39 }, { 0.42, 0.27 } }) do
		B.circle(g, p[1], p[2], 0.15, 0.1, (k % 2 == 0) and "#E8A93E" or "#F2C14E")
		B.circle(g, p[1] + 0.052, p[2] + 0.035, 0.046, 0.03, "#8A5A22")
	end
	-- пчёлка-талисман и «звезда» новинки
	B.circle(g, 0.66, 0.2, 0.22, 0.13, "#F2D85A")
	B.rect(g, 0.71, 0.2, 0.04, 0.13, "#222222")
	B.rect(g, 0.79, 0.2, 0.04, 0.13, "#222222")
	B.circle(g, 0.62, 0.15, 0.12, 0.07, "#FFFFFF", { BackgroundTransparency = 0.2 })
	B.rect(g, 0.06, 0.25, 0.22, 0.13, "#F2D85A", { Rotation = 20 })
	B.text(g, 0.06, 0.27, 0.22, 0.09, "НОВИНКА", "#C23B3B", Enum.Font.GothamBlack, { Rotation = 20 })
	B.rect(g, 0, 0.8, 1, 0.2, "#F2D85A")
	B.text(g, 0.06, 0.82, 0.88, 0.16, "С МЁДОМ!", "#C23B3B", Enum.Font.GothamBlack)
	box.PrimaryPart = body
	self.box = rig(box, body.CFrame)
	self.boxRest = body.CFrame

	-- молоко (пакет с «домиком»)
	local milk = B.model(m, "MilkCarton")
	B.outline(milk)
	local mbase = milkCF * CFrame.Angles(0, math.rad(90), 0)
	local mbody = B.part(milk, "Body", Vector3.new(0.8, 1.3, 0.8), mbase * CFrame.new(0, 0.65, 0), "#FFFFFF")
	B.wedge(milk, "RoofA", Vector3.new(0.8, 0.35, 0.4), mbase * CFrame.new(0, 1.475, -0.2), "#FFFFFF")
	B.wedge(milk, "RoofB", Vector3.new(0.8, 0.35, 0.4), mbase * CFrame.new(0, 1.475, 0.2) * CFrame.Angles(0, math.rad(180), 0), "#FFFFFF")
	B.part(milk, "Fin", Vector3.new(0.8, 0.15, 0.06), mbase * CFrame.new(0, 1.72, 0), "#F3F3F3")
	local mg = B.surface(mbody, Enum.NormalId.Front, 120)
	B.rect(mg, 0, 0.3, 1, 0.4, "#4A90D0")
	B.text(mg, 0.05, 0.36, 0.9, 0.26, "МОЛОКО", "#FFFFFF", Enum.Font.GothamBlack)
	milk.PrimaryPart = mbody
	self.milkBox = rig(milk, mbody.CFrame)
	self.milkBody = mbody
	self.milkRest = mbody.CFrame

	-- ложка (лежит справа от миски)
	local spoon = B.model(m, "Spoon")
	local sbase = bowlCF * CFrame.new(0.15, 0.06, -1.25) * CFrame.Angles(0, math.rad(90), 0)
	local handle = B.part(spoon, "Handle", Vector3.new(0.9, 0.05, 0.1), sbase, "#C9CFD6", Enum.Material.Metal)
	local head = B.part(spoon, "Head", Vector3.new(0.34, 0.08, 0.26), sbase * CFrame.new(0.55, 0.01, 0), "#C9CFD6", Enum.Material.Metal)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = head
	spoon.PrimaryPart = handle
	self.spoon = rig(spoon, sbase)
	self.spoonRest = sbase
	-- рука, держащая ложку (видна только когда ложка поднята)
	self.hand = B.part(m, "Hand", Vector3.new(0.34, 0.28, 0.5), sbase, Config.Colors.Skin, nil, { Transparency = 1 })
	self.scoop = B.ball(m, "Scoop", 0.2, sbase, "#E3A646", nil, { Transparency = 1 })

	noCollide(m)
	m.Parent = workspace
	Outline.add(bowl)
	Outline.add(box)
	Outline.add(milk)
	self.level = 0      -- хлопья 0..1
	self.milkLevel = 0
	return self
end

-- уровень содержимого: 0..1 → высота над дном; диаметр растёт вместе с высотой (миска расширяется)
function Breakfast:fillCyl(part, level, color)
	local bottom, top = 0.15, 0.08 + self.BH * 0.86
	local y = bottom + (top - bottom) * level
	local rTop = self.R0 + (self.R1 - self.R0) * ((y - 0.08) / self.BH) - 0.06
	local h = math.max(0.02, y - 0.1)
	part.Size = Vector3.new(h, rTop * 2, rTop * 2)
	part.CFrame = self.bowlCF * CFrame.new(0, 0.1 + h / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	part.Transparency = level <= 0.01 and 1 or 0
	return y, rTop
end

function Breakfast:updateFill()
	local cy, cr = self:fillCyl(self.cereal, self.level)
	local my = cy
	if self.milkLevel > 0.01 then
		my = self:fillCyl(self.milk, math.min(self.milkLevel * 0.92, self.level))
		self.milk.Transparency = 0.04
	else
		self.milk.Transparency = 1
	end
	local surf = math.max(cy, my)
	for i, b in ipairs(self.bits) do
		local show = self.level > 0.02 and (i / #self.bits) <= math.max(0.15, self.level)
		local r = b.r * cr * 0.92
		local pos = self.bowlCF * CFrame.new(math.cos(b.a) * r, surf + 0.01 + b.dy, math.sin(b.a) * r)
		local cf = pos * CFrame.Angles(b.tx, b.spin, b.tz)
		b.p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
		b.h.CFrame = cf * CFrame.new(0, 0.003, 0) * CFrame.Angles(0, 0, math.rad(90))
		b.p.Transparency = show and 0 or 1
		b.h.Transparency = show and 0 or 1
	end
end

local function animate(self, t, fn)
	local el = 0
	while el < t do
		local dt = RunService.Heartbeat:Wait()
		if not U.paused then
			el = math.min(t, el + dt)
			fn(el / t)
		end
	end
end

-- насыпать хлопья
function Breakfast:pour()
	local above = CFrame.new(self.bowlTop + Vector3.new(0.15, 1.5, 0.7))
	local tilt = CFrame.fromMatrix(above.Position, Vector3.new(1, 0, 0), Vector3.new(0, -0.55, -0.85).Unit)
	moveModel(self.box, above * (self.boxRest - self.boxRest.Position), 0.5)
	U.wait(0.5)
	moveModel(self.box, tilt, 0.45)
	U.wait(0.4)
	Audio.play("Pour", { volume = 0.8 })
	-- падающие хлопья (настоящие детали, падают на миску)
	local bits = {}
	task.spawn(function()
		for i = 1, 22 do
			local p = Instance.new("Part")
			p.Shape = Enum.PartType.Ball
			p.Size = Vector3.new(0.18, 0.18, 0.18)
			p.Color = (i % 2 == 0) and Color3.fromRGB(217, 138, 43) or Color3.fromRGB(242, 193, 78)
			p.Material = Enum.Material.SmoothPlastic
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.CFrame = CFrame.new(self.bowlTop + Vector3.new(math.random(-10, 10) / 60, 0.9, math.random(-10, 10) / 60 + 0.15))
			p.Parent = self.model
			p.AssemblyLinearVelocity = Vector3.new(0, -4, -1)
			table.insert(bits, p)
			task.wait(0.06)
		end
	end)
	animate(self, 1.6, function(a)
		self.level = a
		self:updateFill()
	end)
	moveModel(self.box, above * (self.boxRest - self.boxRest.Position), 0.4)
	U.wait(0.4)
	moveModel(self.box, self.boxRest, 0.5)
	task.delay(1.2, function() for _, p in ipairs(bits) do p:Destroy() end end)
	U.wait(0.5)
end

-- налить молоко
function Breakfast:pourMilk()
	local above = CFrame.new(self.bowlTop + Vector3.new(0.1, 1.4, -0.75))
	local tilt = CFrame.fromMatrix(above.Position, Vector3.new(-1, 0, 0), Vector3.new(0, -0.5, 0.87).Unit)
	moveModel(self.milkBox, above * (self.milkRest - self.milkRest.Position), 0.5)
	U.wait(0.5)
	moveModel(self.milkBox, tilt, 0.45)
	U.wait(0.4)
	Audio.play("Milk", { volume = 0.8 })
	local stream = B.part(self.model, "Stream", Vector3.new(0.09, 1, 0.09), CFrame.new(self.bowlTop), "#FFFFFF", nil,
		{ CanCollide = false, CanQuery = false, CastShadow = false })
	animate(self, 1.7, function(a)
		local spout = self.milkBody.CFrame * Vector3.new(0, 0.9, 0)
		local bottom = self.bowlTop + Vector3.new(0, -0.1, 0)
		local len = (spout - bottom).Magnitude
		stream.Size = Vector3.new(0.09, len, 0.09)
		stream.CFrame = CFrame.lookAt((spout + bottom) / 2, bottom) * CFrame.Angles(math.rad(90), 0, 0)
		stream.Transparency = (a < 0.05 or a > 0.95) and 1 or 0.05
		self.milkLevel = a
		self:updateFill()
	end)
	stream:Destroy()
	moveModel(self.milkBox, above * (self.milkRest - self.milkRest.Position), 0.4)
	U.wait(0.4)
	moveModel(self.milkBox, self.milkRest, 0.5)
	U.wait(0.5)
end

-- одна ложка: из миски ко рту и обратно. eaten — сколько осталось (0..1)
function Breakfast:spoonful(remaining)
	local cam = workspace.CurrentCamera
	local spoon = self.spoon
	local scoop = self.scoop
	local hand = self.hand
	local rest = self.spoonRest
	local dip = CFrame.new(self.bowlTop + Vector3.new(0.05, -0.12, 0.35)) * (rest - rest.Position) * CFrame.Angles(0, 0, math.rad(-22))
	Audio.play("Spoon", { volume = 0.5, pitchJitter = 0.1 })
	local function mouth()
		-- ложка смотрит черпаком к лицу (ручка уходит вправо-вниз)
		return cam.CFrame * CFrame.new(0.1, -0.4, -0.95) * CFrame.Angles(0, math.rad(160), math.rad(14))
	end
	local cur = rest
	local function place(cf, showScoop)
		cur = cf
		setRig(spoon, cf)
		hand.CFrame = cf * CFrame.new(-0.42, 0.05, 0.02)
		hand.Transparency = 0
		scoop.CFrame = cf * CFrame.new(0.55, 0.08, 0)
		scoop.Transparency = showScoop and 0 or 1
	end
	-- в миску (зачерпнуть)
	animate(self, 0.35, function(a)
		place(rest:Lerp(dip, U.smooth(a)), false)
	end)
	animate(self, 0.25, function(a)
		place(dip * CFrame.Angles(0, 0, math.rad(30) * a), a > 0.5)
	end)
	local scooped = cur
	-- ко рту
	animate(self, 0.45, function(a)
		place(scooped:Lerp(mouth(), U.smooth(a)), true)
	end)
	scoop.Transparency = 1
	Audio.play("Crunch" .. tostring(math.random(1, 3)), { volume = 0.9, pitchJitter = 0.06 })
	Cine.shake(0.25, 0.5)
	-- уровень в миске уменьшается
	local fromL, fromM = self.level, self.milkLevel
	animate(self, 0.35, function(a)
		self.level = fromL + (remaining - fromL) * a
		self.milkLevel = fromM + (remaining * 0.9 - fromM) * a
		self:updateFill()
		place(mouth(), false)
	end)
	-- обратно
	local m0 = cur
	animate(self, 0.4, function(a)
		place(m0:Lerp(rest, U.smooth(a)), false)
	end)
	hand.Transparency = 1
end

function Breakfast:destroy()
	if self.model then self.model:Destroy() end
end

return Breakfast
