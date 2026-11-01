-- Рик Санчез (модель из деталей, только у этого игрока). Скелет из групп: туловище, голова,
-- две ноги, две руки — каждая группа вращается вокруг своего сустава. Умеет: стоять и дышать,
-- ходить (ноги и руки качаются), поворачивать голову, говорить (рот открывается), моргать,
-- рыгать, целиться и стрелять зелёным лучом из портальной пушки, тянуть руку к Морти.
local RunService = game:GetService("RunService")

local Rick = {}
Rick.__index = Rick
local B, U, Audio, Config

function Rick.init(ctx)
	B, U, Audio, Config = ctx.Build, ctx.Util, ctx.Audio, ctx.Config
end

local SKIN = "#EADDCB"
local SKIN2 = "#D9C7B2"
local COAT = "#F4F4F0"
local COAT2 = "#DEDED8"
local SHIRT = "#8EC3DF"
local PANTS = "#6F5236"
local BELT = "#3E3026"
local HAIR = "#B4DCEF"
local HAIR2 = "#93C3DB"
local SHOES = "#3B2A20"
local A = CFrame.Angles
local r = math.rad

-- cf — точка на полу между ступнями, смотрит вперёд (−Z)
function Rick.new(cf, parent)
	local self = setmetatable({}, Rick)
	self.cf = cf
	self.t = 0
	self.aim = nil          -- точка, куда целится правая рука
	self.lookAt = nil       -- точка, куда смотрит голова
	self.walk = 0           -- 0..1 сила походки
	self.walkPhase = 0
	self.talkT = 0          -- сколько ещё «говорить»
	self.burpT = 0
	self.reach = 0          -- 0..1 левая рука тянется вперёд (схватить Морти)
	self.blink = 0
	local m = Instance.new("Model")
	m.Name = "RM_Rick"
	self.model = m
	self.groups = { root = {}, torso = {}, head = {}, legL = {}, legR = {}, armL = {}, armR = {} }
	local function add(group, name, size, off, color, opt)
		opt = opt or {}
		local p
		if opt.shape == "ball" then
			p = B.ball(m, name, 1, CFrame.new(), color, opt.mat)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Scale = size
			mesh.Parent = p
		elseif opt.shape == "wedge" then
			p = B.wedge(m, name, size, CFrame.new(), color, opt.mat)
		elseif opt.shape == "cyl" then
			p = B.cyl(m, name, size.X, size.Y, CFrame.new(), color, opt.mat)
		else
			p = B.part(m, name, size, CFrame.new(), color, opt.mat)
		end
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		if opt.transparency then p.Transparency = opt.transparency end
		table.insert(self.groups[group], { p = p, off = off })
		return p
	end
	self.add = add

	-- НОГИ (сустав — тазобедренный, y = 3.2 от пола)
	for _, s in ipairs({ -1, 1 }) do
		local g = s < 0 and "legL" or "legR"
		add(g, "Thigh", Vector3.new(0.66, 1.75, 0.68), CFrame.new(0, -0.85, 0), PANTS)
		add(g, "Shin", Vector3.new(0.6, 1.5, 0.62), CFrame.new(0, -2.35, 0.02), PANTS)
		add(g, "Cuff", Vector3.new(0.66, 0.18, 0.68), CFrame.new(0, -2.95, 0.02), "#5E4530")
		add(g, "Shoe", Vector3.new(0.72, 0.36, 1.05), CFrame.new(0, -3.02, -0.18), SHOES)
		add(g, "Toe", Vector3.new(0.72, 0.36, 0.55), CFrame.new(0, -3.02, -0.68), SHOES, { shape = "ball" })
	end

	-- ТУЛОВИЩЕ (сустав — таз, y = 3.2)
	add("torso", "Belt", Vector3.new(1.74, 0.22, 0.94), CFrame.new(0, 0.1, 0), BELT)
	add("torso", "Buckle", Vector3.new(0.3, 0.2, 0.06), CFrame.new(0, 0.1, -0.48), "#C9A44A", { mat = Enum.Material.Metal })
	add("torso", "Sweater", Vector3.new(1.7, 2.1, 0.9), CFrame.new(0, 1.25, 0), SHIRT)
	add("torso", "Collar", Vector3.new(0.9, 0.25, 0.92), CFrame.new(0, 2.3, -0.02), "#7FB4D0")
	-- халат: спина, расходящиеся полы, бока, плечи, лацканы, карманы
	add("torso", "CoatBack", Vector3.new(2.05, 3.9, 0.12), CFrame.new(0, 0.7, 0.5), COAT)
	add("torso", "CoatHem", Vector3.new(2.15, 0.9, 0.12), CFrame.new(0, -1.15, 0.56) * A(r(-6), 0, 0), COAT)
	for _, s in ipairs({ -1, 1 }) do
		add("torso", "CoatFront", Vector3.new(0.62, 3.9, 0.12), CFrame.new(s * 0.72, 0.7, -0.5) * A(0, s * r(8), 0), COAT)
		add("torso", "CoatFlap", Vector3.new(0.68, 0.9, 0.12), CFrame.new(s * 0.78, -1.15, -0.55) * A(r(6), s * r(14), 0), COAT)
		add("torso", "CoatSide", Vector3.new(0.12, 3.9, 1.05), CFrame.new(s * 1.0, 0.7, 0), COAT)
		add("torso", "Lapel", Vector3.new(0.08, 1.1, 0.42), CFrame.new(s * 0.42, 1.9, -0.55) * A(r(-90), 0, s * r(-14)), COAT2, { shape = "wedge" })
		add("torso", "Pocket", Vector3.new(0.48, 0.5, 0.05), CFrame.new(s * 0.72, -0.35, -0.58) * A(0, s * r(8), 0), COAT2)
	end
	add("torso", "Shoulders", Vector3.new(2.2, 0.38, 1.08), CFrame.new(0, 2.25, 0), COAT)
	-- ручки в нагрудном кармане
	add("torso", "BreastPocket", Vector3.new(0.4, 0.4, 0.05), CFrame.new(-0.72, 1.5, -0.58), COAT2)
	add("torso", "PenA", Vector3.new(0.35, 0.07, 0.07), CFrame.new(-0.82, 1.78, -0.6) * A(0, 0, r(90)), "#3B6FB0", { shape = "cyl" })
	add("torso", "PenB", Vector3.new(0.3, 0.07, 0.07), CFrame.new(-0.66, 1.75, -0.6) * A(0, 0, r(90)), "#C23B3B", { shape = "cyl" })
	add("torso", "Neck", Vector3.new(0.48, 0.5, 0.48), CFrame.new(0, 2.6, 0), SKIN)

	-- ГОЛОВА (сустав — шея, y = 2.75 над тазом)
	add("head", "Cranium", Vector3.new(1.32, 1.45, 1.3), CFrame.new(0, 0.95, 0.02), SKIN, { shape = "ball" })
	add("head", "Jaw", Vector3.new(1.18, 0.95, 1.15), CFrame.new(0, 0.38, -0.06), SKIN, { shape = "ball" })
	add("head", "Chin", Vector3.new(0.7, 0.35, 0.5), CFrame.new(0, 0.05, -0.38), SKIN2, { shape = "ball" })
	add("head", "EarL", Vector3.new(0.18, 0.38, 0.28), CFrame.new(-0.66, 0.85, 0.05), SKIN2, { shape = "ball" })
	add("head", "EarR", Vector3.new(0.18, 0.38, 0.28), CFrame.new(0.66, 0.85, 0.05), SKIN2, { shape = "ball" })
	self.eyes = {}
	for _, s in ipairs({ -1, 1 }) do
		local e = add("head", "Eye", Vector3.new(0.44, 0.5, 0.22), CFrame.new(s * 0.29, 1.08, -0.6), "#FFFFFF", { shape = "ball" })
		local pu = add("head", "Pupil", Vector3.new(0.12, 0.12, 0.08), CFrame.new(s * 0.27, 1.06, -0.71), "#111111", { shape = "ball" })
		add("head", "EyeBag", Vector3.new(0.34, 0.05, 0.05), CFrame.new(s * 0.29, 0.8, -0.64) * A(0, 0, s * r(-10)), "#BFA992")
		table.insert(self.eyes, { e = e, pu = pu })
	end
	-- моноброва зигзагом
	for k = -2, 2 do
		add("head", "Brow", Vector3.new(0.12, 0.26, 0.22), CFrame.new(k * 0.21, 1.42 + (k % 2) * 0.05, -0.62) * A(r(-90), 0, r(k * 12)), "#8FB3C9", { shape = "wedge" })
	end
	add("head", "Nose", Vector3.new(0.17, 0.34, 0.26), CFrame.new(0, 0.8, -0.72) * A(r(12), 0, 0), SKIN2)
	self.mouth = add("head", "Mouth", Vector3.new(0.62, 0.06, 0.08), CFrame.new(0.03, 0.42, -0.66) * A(0, 0, r(4)), "#5A3A32")
	self.mouthOpen = add("head", "MouthOpen", Vector3.new(0.5, 0.25, 0.1), CFrame.new(0.03, 0.4, -0.62), "#3A1A1A", { shape = "ball", transparency = 1 })
	add("head", "Drool", Vector3.new(0.08, 0.22, 0.06), CFrame.new(0.33, 0.27, -0.64), "#BFE6F5", { mat = Enum.Material.Glass })
	-- волосы: основа и шипы-«лезвия» (два клина спина к спине), торчат назад и вверх
	add("head", "HairBase", Vector3.new(1.42, 0.75, 1.36), CFrame.new(0, 1.42, 0.12), HAIR, { shape = "ball" })
	local spikes = {
		{ 0, 1.85, 0.1, -20, 0, 0, 1.2 }, { -0.42, 1.75, 0.15, -15, 0, 30, 1.1 }, { 0.42, 1.75, 0.15, -15, 0, -30, 1.1 },
		{ -0.72, 1.35, 0.25, 0, 0, 62, 1.0 }, { 0.72, 1.35, 0.25, 0, 0, -62, 1.0 }, { -0.55, 1.6, 0.55, -50, 20, 35, 1.0 },
		{ 0.55, 1.6, 0.55, -50, -20, -35, 1.0 }, { 0, 1.55, 0.7, -70, 0, 0, 1.15 }, { -0.3, 1.2, 0.72, -95, 10, 20, 0.85 },
		{ 0.3, 1.2, 0.72, -95, -10, -20, 0.85 }, { -0.68, 1.05, 0.45, -30, 30, 75, 0.8 }, { 0.68, 1.05, 0.45, -30, -30, -75, 0.8 },
	}
	for i, s in ipairs(spikes) do
		local len = s[7]
		local base = CFrame.new(s[1], s[2], s[3]) * A(r(s[4]), r(s[5]), r(s[6]))
		local col = (i % 3 == 0) and HAIR2 or HAIR
		add("head", "Spike", Vector3.new(0.18, len, 0.32), base * CFrame.new(-0.09, len / 2, 0), col, { shape = "wedge" })
		add("head", "Spike", Vector3.new(0.18, len, 0.32), base * CFrame.new(0.09, len / 2, 0) * A(0, r(180), 0), col, { shape = "wedge" })
	end

	-- РУКИ (сустав — плечо, по бокам вверху туловища)
	for _, s in ipairs({ -1, 1 }) do
		local g = s < 0 and "armL" or "armR"
		add(g, "Upper", Vector3.new(0.56, 1.3, 0.58), CFrame.new(0, -0.6, 0), COAT)
		add(g, "Lower", Vector3.new(0.52, 1.2, 0.54), CFrame.new(0, -1.8, 0), COAT)
		add(g, "Cuff", Vector3.new(0.56, 0.18, 0.58), CFrame.new(0, -2.42, 0), COAT2)
		add(g, "Hand", Vector3.new(0.44, 0.5, 0.32), CFrame.new(0, -2.75, 0), SKIN)
		add(g, "Thumb", Vector3.new(0.14, 0.28, 0.14), CFrame.new(-s * 0.24, -2.68, -0.08) * A(0, 0, s * r(25)), SKIN)
	end
	-- портальная пушка в правой руке: вдоль руки (дуло смотрит туда же, куда рука)
	add("armR", "GunHandle", Vector3.new(0.24, 0.42, 0.28), CFrame.new(0, -2.85, 0.1), "#8E969E", { mat = Enum.Material.Metal })
	add("armR", "GunBody", Vector3.new(0.42, 1.0, 0.42), CFrame.new(0, -3.25, -0.12), "#BFC6CC", { mat = Enum.Material.Metal })
	add("armR", "GunTank", Vector3.new(0.5, 0.3, 0.3), CFrame.new(0, -3.2, 0.2) * A(0, 0, r(90)), "#DDF2FF", { shape = "cyl", mat = Enum.Material.Glass, transparency = 0.4 })
	add("armR", "GunFluid", Vector3.new(0.44, 0.22, 0.22), CFrame.new(0, -3.2, 0.2) * A(0, 0, r(90)), "#7CFF4A", { shape = "cyl", mat = Enum.Material.Neon })
	add("armR", "GunRing", Vector3.new(0.08, 0.5, 0.5), CFrame.new(0, -3.7, -0.12) * A(0, 0, r(90)), "#6E767E", { shape = "cyl", mat = Enum.Material.Metal })
	add("armR", "GunTip", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, -3.85, -0.12), "#9CFF6A", { shape = "ball", mat = Enum.Material.Neon })
	add("armR", "GunDial", Vector3.new(0.12, 0.12, 0.12), CFrame.new(0.23, -3.0, -0.12), "#D23B3B", { shape = "ball" })
	self.muzzle = CFrame.new(0, -4.1, -0.12)

	B.outline(m)
	m.Parent = parent or workspace
	self.conn = RunService.RenderStepped:Connect(function(dt) self:update(dt) end)
	self:update(0)
	return self
end

local function place(list, cf)
	for _, e in ipairs(list) do e.p.CFrame = cf * e.off end
end

function Rick:update(dt)
	if U.paused then dt = 0 end
	self.t = self.t + dt
	local t = self.t
	-- походка
	if self.walk > 0.01 then self.walkPhase = self.walkPhase + dt * 7 end
	local sw = math.sin(self.walkPhase) * self.walk
	local bob = math.sin(t * 1.8) * 0.04 + math.abs(math.cos(self.walkPhase)) * 0.12 * self.walk
	local root = self.cf * CFrame.new(0, bob, 0)
	place(self.groups.root, root)
	-- туловище чуть сутулится и покачивается
	local burp = self.burpT > 0 and math.sin(math.min(1, self.burpT) * math.pi) or 0
	local torso = root * CFrame.new(0, 3.2, 0) * A(r(7) - burp * r(6), math.sin(t * 0.7) * 0.03 + sw * 0.06, sw * 0.03)
	place(self.groups.torso, torso)
	-- голова: смотрит на цель (с ограничением), при «бурпе» запрокидывается
	local neck = torso * CFrame.new(0, 2.75, -0.05)
	local headRot = A(math.sin(t * 0.9) * 0.03 - burp * r(18), math.sin(t * 0.5) * 0.05, 0)
	if self.lookAt then
		local loc = neck:PointToObjectSpace(self.lookAt)
		local yaw = math.clamp(math.atan2(-loc.X, -loc.Z), -1.0, 1.0)
		local pitch = math.clamp(math.atan2(loc.Y, math.sqrt(loc.X * loc.X + loc.Z * loc.Z)), -0.5, 0.5)
		self.hyaw = (self.hyaw or 0) + (yaw - (self.hyaw or 0)) * math.min(1, dt * 6)
		self.hpitch = (self.hpitch or 0) + (pitch - (self.hpitch or 0)) * math.min(1, dt * 6)
		headRot = A(0, self.hyaw, 0) * A(self.hpitch, 0, 0) * headRot
	end
	place(self.groups.head, neck * headRot)
	-- моргание
	self.blink = self.blink - dt
	if self.blink < -3 - (math.sin(t * 13.7) + 1) then self.blink = 0.12 end
	for _, e in ipairs(self.eyes) do
		local closed = self.blink > 0
		e.e.Transparency = closed and 1 or 0
		e.pu.Transparency = closed and 1 or 0
	end
	-- рот: говорит / рыгает
	if self.talkT > 0 then self.talkT = self.talkT - dt end
	if self.burpT > 0 then self.burpT = self.burpT - dt end
	local open = 0
	if self.burpT > 0 then open = 1
	elseif self.talkT > 0 then open = (math.sin(t * 17) + math.sin(t * 11.3)) > 0.3 and 0.8 or 0.15 end
	self.mouthOpen.Transparency = open > 0.1 and 0 or 1
	local mesh = self.mouthOpen:FindFirstChildOfClass("SpecialMesh")
	if mesh then mesh.Scale = Vector3.new(0.5, 0.12 + open * 0.3, 0.1) end
	-- ноги
	place(self.groups.legL, root * CFrame.new(-0.42, 3.2, 0) * A(sw * r(28), 0, 0))
	place(self.groups.legR, root * CFrame.new(0.42, 3.2, 0) * A(-sw * r(28), 0, 0))
	-- левая рука: качается при ходьбе или тянется вперёд (схватить Морти)
	local armL = torso * CFrame.new(-1.25, 2.05, 0) * A(-sw * r(22) + math.sin(t * 1.1) * 0.02, 0, r(6))
	if self.reach > 0.01 then
		armL = armL:Lerp(torso * CFrame.new(-1.25, 2.05, 0) * A(r(-85), r(-10), 0), self.reach)
	end
	place(self.groups.armL, armL)
	-- правая рука с пушкой: целится или опущена
	local sh = torso * CFrame.new(1.25, 2.05, 0)
	local armR
	if self.aim then
		-- направляем «вниз» руки (−Y) на цель
		local dir = (self.aim - sh.Position)
		if dir.Magnitude > 0.01 then
			local look = CFrame.lookAt(sh.Position, self.aim)
			armR = look * A(r(90), 0, 0)
		end
	end
	armR = armR or (sh * A(sw * r(22) + r(-20), 0, r(-4)))
	self.armCF = armR
	place(self.groups.armR, armR)
end

-- говорить: рот двигается t секунд
function Rick:talk(t) self.talkT = t end
function Rick:doBurp()
	self.burpT = 0.7
	Audio.play("Burp", { at = self.mouth, volume = 0.8, pitchJitter = 0.06 })
end

function Rick:face(pos)
	local p = self.cf.Position
	self.cf = CFrame.lookAt(p, Vector3.new(pos.X, p.Y, pos.Z))
end

-- идти к точке (на полу) за t секунд, с походкой
function Rick:moveTo(pos, t)
	local from = self.cf
	local flat = Vector3.new(pos.X, from.Position.Y, pos.Z)
	local dir = flat - from.Position
	local rot = (dir.Magnitude > 0.1) and (CFrame.lookAt(from.Position, flat) - from.Position) or (from - from.Position)
	local to = CFrame.new(pos) * rot
	self.cf = CFrame.new(from.Position) * rot
	from = self.cf
	self.walk = 1
	local el = 0
	while el < t do
		local dt = RunService.Heartbeat:Wait()
		if not U.paused then
			el = math.min(t, el + dt)
			self.cf = from:Lerp(to, U.smooth(el / t))
		end
	end
	self.walk = 0
end

-- выстрел зелёным лучом в точку
function Rick:shoot(target)
	self.aim = target
	self:update(0)
	local muzzle = (self.armCF * self.muzzle).Position
	Audio.play("Laser", { at = self.mouth, volume = 0.9, pitchJitter = 0.08 })
	local len = (target - muzzle).Magnitude
	local beam = B.part(self.model, "Laser", Vector3.new(0.28, 0.28, len), CFrame.lookAt((muzzle + target) / 2, target), "#B6FF7A", Enum.Material.Neon,
		{ CanCollide = false, CanQuery = false, CastShadow = false })
	local flash = B.ball(self.model, "Flash", 0.9, CFrame.new(muzzle), "#E6FFC8", Enum.Material.Neon, { CanCollide = false, CanQuery = false, CastShadow = false })
	B.light(flash, "PointLight", { Color = Color3.fromRGB(150, 255, 90), Brightness = 4, Range = 18, Shadows = false })
	task.spawn(function()
		for i = 1, 6 do
			RunService.Heartbeat:Wait()
			beam.Transparency = i / 6
			flash.Transparency = i / 6
			beam.Size = Vector3.new(0.28 * (1 - i / 7), 0.28 * (1 - i / 7), len)
		end
		beam:Destroy()
		flash:Destroy()
	end)
end

-- точка у дула (откуда вылетает портал)
function Rick:muzzlePos()
	self:update(0)
	return (self.armCF * self.muzzle).Position
end

function Rick:destroy()
	if self.conn then self.conn:Disconnect() end
	if self.model then self.model:Destroy() end
end

return Rick
