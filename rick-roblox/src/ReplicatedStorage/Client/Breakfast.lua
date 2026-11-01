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
	self.bowlTop = bowlCF.Position + Vector3.new(0, 0.55, 0)

	-- миска
	local bowl = B.model(m, "Bowl")
	B.outline(bowl)
	B.vcyl(bowl, "Outer", 0.5, 1.5, bowlCF * CFrame.new(0, 0.25, 0), "#FFFFFF")
	B.vcyl(bowl, "Foot", 0.1, 0.9, bowlCF * CFrame.new(0, 0.05, 0), "#E8F0FF")
	B.vcyl(bowl, "Band", 0.12, 1.53, bowlCF * CFrame.new(0, 0.36, 0), "#5A86E0")
	self.cereal = B.vcyl(m, "Cereal", 0.02, 1.26, bowlCF * CFrame.new(0, 0.5, 0), "#E3A646")
	self.milk = B.vcyl(m, "Milk", 0.02, 1.3, bowlCF * CFrame.new(0, 0.49, 0), "#FFFFFF")
	self.cereal.Transparency = 1
	self.milk.Transparency = 1
	self.bits = {}
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2
		local r = (i % 3) * 0.17 + 0.12
		local bit = B.ball(m, "Bit", 0.2, bowlCF * CFrame.new(math.cos(a) * r, 0.52, math.sin(a) * r), (i % 2 == 0) and "#D98A2B" or "#F2C14E")
		bit.Transparency = 1
		table.insert(self.bits, { p = bit, off = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r) })
	end
	self.bowlCF = bowlCF

	-- коробка хлопьев (лицом к Морти: Морти сидит с запада)
	local box = B.model(m, "CerealBox")
	B.outline(box)
	local boxBase = boxCF * CFrame.Angles(0, math.rad(90), 0)
	local body = B.part(box, "Body", Vector3.new(1.2, 1.7, 0.45), boxBase * CFrame.new(0, 0.85, 0), "#E2504A")
	local g = B.surface(body, Enum.NormalId.Front, 120)
	B.rect(g, 0, 0, 1, 1, "#E2504A")
	B.rect(g, 0, 0.62, 1, 0.38, "#F2D85A")
	B.text(g, 0.06, 0.06, 0.88, 0.22, "ХРУСТИ-О", "#FFFFFF", Enum.Font.GothamBlack)
	B.circle(g, 0.22, 0.32, 0.56, 0.32, "#FFFFFF")
	B.circle(g, 0.32, 0.37, 0.36, 0.22, "#F2B33C")
	B.text(g, 0.08, 0.72, 0.84, 0.16, "С МЁДОМ!", "#C23B3B", Enum.Font.GothamBlack)
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

local function setFill(part, baseCF, level, maxH)
	local h = math.max(0.02, maxH * level)
	part.Size = Vector3.new(h, part.Size.Y, part.Size.Z)
	part.CFrame = baseCF * CFrame.new(0, 0.46 + h / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	part.Transparency = level <= 0.001 and 1 or 0
end

function Breakfast:updateFill()
	setFill(self.cereal, self.bowlCF, self.level, 0.22)
	setFill(self.milk, self.bowlCF, math.min(self.milkLevel, self.level + 0.05), 0.2)
	self.milk.Transparency = self.milkLevel <= 0.001 and 1 or 0.05
	local top = 0.46 + math.max(0.22 * self.level, 0.2 * math.min(self.milkLevel, self.level + 0.05)) + 0.03
	for i, b in ipairs(self.bits) do
		local show = self.level > (i - 1) / #self.bits * 0.9
		b.p.Transparency = show and 0 or 1
		b.p.CFrame = self.bowlCF * CFrame.new(b.off.X, top, b.off.Z)
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
