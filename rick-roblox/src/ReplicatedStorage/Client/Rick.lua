-- Рик Санчез (модель из деталей, только у этого игрока): халат, голубые волосы-шипы, моноброва,
-- портальная пушка. Умеет стоять, поворачиваться, целиться и стрелять зелёным лучом.
local RunService = game:GetService("RunService")

local Rick = {}
Rick.__index = Rick
local B, U, Audio, Config

function Rick.init(ctx)
	B, U, Audio, Config = ctx.Build, ctx.Util, ctx.Audio, ctx.Config
end

local SKIN = "#E9DCCB"
local COAT = "#F4F4F0"
local SHIRT = "#9CC9E2"
local PANTS = "#7A5A3C"
local HAIR = "#B4D9EC"
local SHOES = "#4A3A30"

-- cf — точка на полу между ступнями, смотрит вперёд (−Z)
function Rick.new(cf, parent)
	local self = setmetatable({}, Rick)
	self.cf = cf
	self.t = 0
	self.aim = nil
	local m = Instance.new("Model")
	m.Name = "RM_Rick"
	self.model = m
	self.body = {}  -- { part, offset } относительно точки на полу
	self.arm = {}   -- правая рука с пушкой: смещения относительно плеча
	local function add(list, name, size, off, color, mat, shape)
		local p
		if shape == "ball" then p = B.ball(m, name, size.X, CFrame.new(), color, mat)
		elseif shape == "wedge" then p = B.wedge(m, name, size, CFrame.new(), color, mat)
		else p = B.part(m, name, size, CFrame.new(), color, mat) end
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		table.insert(list, { p = p, off = off })
		return p
	end
	local A = CFrame.Angles
	local r = math.rad
	-- ноги и обувь
	add(self.body, "LegL", Vector3.new(0.7, 2.9, 0.7), CFrame.new(-0.42, 1.65, 0), PANTS)
	add(self.body, "LegR", Vector3.new(0.7, 2.9, 0.7), CFrame.new(0.42, 1.65, 0), PANTS)
	add(self.body, "ShoeL", Vector3.new(0.75, 0.3, 1.1), CFrame.new(-0.42, 0.15, -0.15), SHOES)
	add(self.body, "ShoeR", Vector3.new(0.75, 0.3, 1.1), CFrame.new(0.42, 0.15, -0.15), SHOES)
	-- туловище: голубая кофта и белый халат
	add(self.body, "Shirt", Vector3.new(1.8, 2.4, 0.95), CFrame.new(0, 4.25, 0), SHIRT)
	add(self.body, "CoatBack", Vector3.new(2.1, 3.9, 0.18), CFrame.new(0, 3.6, 0.52), COAT)
	add(self.body, "CoatL", Vector3.new(0.7, 3.9, 0.18), CFrame.new(-0.72, 3.6, -0.52), COAT)
	add(self.body, "CoatR", Vector3.new(0.7, 3.9, 0.18), CFrame.new(0.72, 3.6, -0.52), COAT)
	add(self.body, "CoatSideL", Vector3.new(0.18, 3.9, 1.05), CFrame.new(-1.0, 3.6, 0), COAT)
	add(self.body, "CoatSideR", Vector3.new(0.18, 3.9, 1.05), CFrame.new(1.0, 3.6, 0), COAT)
	add(self.body, "Collar", Vector3.new(1.9, 0.35, 1.15), CFrame.new(0, 5.45, 0), COAT)
	-- левая рука (опущена)
	add(self.body, "ArmL", Vector3.new(0.6, 2.3, 0.6), CFrame.new(-1.35, 4.3, 0) * A(0, 0, r(-6)), COAT)
	add(self.body, "HandL", Vector3.new(0.5, 0.55, 0.5), CFrame.new(-1.48, 2.95, 0), SKIN)
	-- шея и голова (вытянутая)
	add(self.body, "Neck", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 5.75, 0), SKIN)
	add(self.body, "Head", Vector3.new(1.35, 1.6, 1.3), CFrame.new(0, 6.75, -0.05), SKIN)
	add(self.body, "Chin", Vector3.new(1.1, 0.35, 1.0), CFrame.new(0, 5.95, -0.2), SKIN)
	-- лицо
	add(self.body, "EyeL", Vector3.new(0.42, 0.42, 0.42), CFrame.new(-0.3, 6.95, -0.66), "#FFFFFF", nil, "ball")
	add(self.body, "EyeR", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0.3, 6.95, -0.66), "#FFFFFF", nil, "ball")
	add(self.body, "PupilL", Vector3.new(0.13, 0.13, 0.13), CFrame.new(-0.27, 6.93, -0.86), "#111111", nil, "ball")
	add(self.body, "PupilR", Vector3.new(0.13, 0.13, 0.13), CFrame.new(0.27, 6.93, -0.86), "#111111", nil, "ball")
	add(self.body, "Unibrow", Vector3.new(1.15, 0.16, 0.12), CFrame.new(0, 7.25, -0.68) * A(0, 0, r(-4)), "#7FA3B8")
	add(self.body, "Nose", Vector3.new(0.18, 0.35, 0.22), CFrame.new(0, 6.65, -0.73), "#DCC9B5")
	add(self.body, "Mouth", Vector3.new(0.7, 0.07, 0.06), CFrame.new(0.05, 6.25, -0.66) * A(0, 0, r(5)), "#6B4A40")
	add(self.body, "Drool", Vector3.new(0.08, 0.25, 0.06), CFrame.new(0.33, 6.08, -0.66), "#BFE6F5", Enum.Material.Glass)
	-- волосы: шипы во все стороны (назад и вверх)
	add(self.body, "HairBase", Vector3.new(1.45, 0.5, 1.4), CFrame.new(0, 7.55, 0.05), HAIR)
	local spikes = {
		{ 0, 8.05, 0.1, -15, 0, 0 }, { -0.55, 7.85, 0.1, -10, 0, 35 }, { 0.55, 7.85, 0.1, -10, 0, -35 },
		{ -0.75, 7.35, 0.2, 0, 0, 70 }, { 0.75, 7.35, 0.2, 0, 0, -70 }, { 0, 7.6, 0.65, -60, 0, 0 },
		{ -0.45, 7.5, 0.6, -55, 25, 25 }, { 0.45, 7.5, 0.6, -55, -25, -25 },
	}
	for i, s in ipairs(spikes) do
		add(self.body, "Spike" .. i, Vector3.new(0.6, 0.9, 0.7), CFrame.new(s[1], s[2], s[3]) * A(r(s[4]), r(s[5]), r(s[6])), HAIR, nil, "wedge")
	end
	-- правая рука с портальной пушкой (вращается в плече)
	self.shoulder = CFrame.new(1.35, 5.2, 0)
	add(self.arm, "ArmR", Vector3.new(0.6, 0.6, 2.2), CFrame.new(0, 0, -1.0), COAT)
	add(self.arm, "HandR", Vector3.new(0.5, 0.55, 0.5), CFrame.new(0, 0, -2.25), SKIN)
	add(self.arm, "GunBody", Vector3.new(0.45, 0.55, 1.1), CFrame.new(0, 0.05, -2.6), "#C9CFD6", Enum.Material.Metal)
	add(self.arm, "GunTube", Vector3.new(0.3, 0.3, 0.6), CFrame.new(0, 0.05, -3.35), "#7CFF4A", Enum.Material.Neon)
	add(self.arm, "GunTop", Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, 0.42, -2.55), "#9CFF6A", Enum.Material.Neon, "ball")
	self.muzzle = CFrame.new(0, 0.05, -3.7)
	B.outline(m)
	m.Parent = parent or workspace
	self.conn = RunService.RenderStepped:Connect(function(dt) self:update(dt) end)
	self:update(0)
	return self
end

function Rick:update(dt)
	if not U.paused then self.t = self.t + dt end
	local bob = math.sin(self.t * 2) * 0.05
	local root = self.cf * CFrame.new(0, bob, 0)
	for _, e in ipairs(self.body) do e.p.CFrame = root * e.off end
	-- рука: по умолчанию опущена вперёд-вниз, при прицеливании смотрит на цель
	local sh = root * self.shoulder
	local armCF
	if self.aim then
		armCF = CFrame.lookAt(sh.Position, self.aim)
	else
		armCF = sh * CFrame.Angles(math.rad(-55), 0, 0)
	end
	self.armCF = armCF
	for _, e in ipairs(self.arm) do e.p.CFrame = armCF * e.off end
end

function Rick:face(pos)
	local p = self.cf.Position
	self.cf = CFrame.lookAt(p, Vector3.new(pos.X, p.Y, pos.Z))
end

function Rick:moveTo(pos, t)
	local from = self.cf
	local to = CFrame.new(pos) * (self.cf - self.cf.Position)
	local el = 0
	while el < t do
		local dt = RunService.Heartbeat:Wait()
		if not U.paused then
			el = math.min(t, el + dt)
			self.cf = from:Lerp(to, U.smooth(el / t))
		end
	end
end

-- выстрел зелёным лучом в точку
function Rick:shoot(target)
	self.aim = target
	self:update(0)
	local muzzle = (self.armCF * self.muzzle).Position
	Audio.play("Laser", { at = self.model:FindFirstChild("GunTube"), volume = 0.9, pitchJitter = 0.08 })
	local len = (target - muzzle).Magnitude
	local beam = B.part(self.model, "Laser", Vector3.new(0.28, 0.28, len), CFrame.lookAt((muzzle + target) / 2, target), "#B6FF7A", Enum.Material.Neon,
		{ CanCollide = false, CanQuery = false, CastShadow = false })
	local flash = B.ball(self.model, "Flash", 0.9, CFrame.new(muzzle), "#E6FFC8", Enum.Material.Neon, { CanCollide = false, CanQuery = false, CastShadow = false })
	local light = B.light(flash, "PointLight", { Color = Color3.fromRGB(150, 255, 90), Brightness = 4, Range = 18, Shadows = false })
	local _ = light
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

function Rick:destroy()
	if self.conn then self.conn:Disconnect() end
	if self.model then self.model:Destroy() end
end

return Rick
