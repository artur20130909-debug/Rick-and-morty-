-- Зелёный портал Рика (меню и переходы). Без картинок: вихрь — вложенные круги с вращающимися
-- полосатыми градиентами на SurfaceGui, светящийся край из шариков Neon, искры, зелёный свет.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Portal = {}
Portal.__index = Portal
local Config, B, Audio

function Portal.init(ctx)
	Config, B, Audio = ctx.Config, ctx.Build, ctx.Audio
end

local function stripes(c1, c2, n)
	local kps = {}
	for i = 0, n do
		local t = i / n
		table.insert(kps, ColorSequenceKeypoint.new(t, (i % 2 == 0) and c1 or c2))
	end
	return ColorSequence.new(kps)
end

-- cf: центр портала, LookVector смотрит на зрителя; d — диаметр
function Portal.new(cf, d, parent)
	local self = setmetatable({}, Portal)
	self.cf = cf
	self.d = d
	self.scale = 0.02
	self.t = 0
	local m = Instance.new("Model")
	m.Name = "RM_Portal"
	self.model = m
	-- задний диск и тёмное кольцо
	self.disc = B.cyl(m, "Disc", 0.08, d, cf * CFrame.new(0, 0, 0.12) * CFrame.Angles(0, math.rad(90), 0), Config.Colors.PortalDark, Enum.Material.Neon, { CastShadow = false, CanCollide = false, CanQuery = false })
	self.rim = B.cyl(m, "Rim", 0.06, d + 0.5, cf * CFrame.new(0, 0, 0.18) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(18, 90, 24), Enum.Material.Neon, { CastShadow = false, CanCollide = false, CanQuery = false })
	-- панель с вихрем (две стороны)
	self.panel = B.part(m, "Swirl", Vector3.new(d, d, 0.04), cf, Color3.new(0, 0, 0), nil, { Transparency = 1, CastShadow = false, CanCollide = false, CanQuery = false })
	self.layers = {}
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 60
		g.LightInfluence = 0
		g.Brightness = 2.2
		g.ClipsDescendants = true
		g.Parent = self.panel
		local specs = {
			{ s = 1.0, a = Color3.fromRGB(24, 120, 30), b = Color3.fromRGB(46, 168, 44), n = 12, sp = 24 },
			{ s = 0.86, a = Color3.fromRGB(57, 194, 50), b = Color3.fromRGB(110, 226, 74), n = 10, sp = -46 },
			{ s = 0.68, a = Color3.fromRGB(123, 225, 74), b = Color3.fromRGB(184, 245, 106), n = 8, sp = 70 },
			{ s = 0.48, a = Color3.fromRGB(200, 255, 138), b = Color3.fromRGB(150, 240, 80), n = 6, sp = -110 },
			{ s = 0.26, a = Color3.fromRGB(238, 255, 200), b = Color3.fromRGB(210, 255, 150), n = 4, sp = 160 },
		}
		for i, sp in ipairs(specs) do
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, 0.5)
			f.Size = UDim2.fromScale(sp.s, sp.s)
			f.BackgroundColor3 = Color3.new(1, 1, 1)
			f.BorderSizePixel = 0
			f.ZIndex = i
			f.Parent = g
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = f
			local gr = Instance.new("UIGradient")
			gr.Color = stripes(sp.a, sp.b, sp.n)
			gr.Rotation = i * 37
			gr.Parent = f
			table.insert(self.layers, { g = gr, sp = (face == Enum.NormalId.Back) and -sp.sp or sp.sp })
		end
	end
	-- светящийся край: шарики по окружности
	self.beads = {}
	for i = 1, 22 do
		local bead = B.ball(m, "Bead", 0.42, cf, (i % 3 == 0) and Config.Colors.PortalLight or Config.Colors.Portal, Enum.Material.Neon,
			{ CastShadow = false, CanCollide = false, CanQuery = false })
		table.insert(self.beads, { p = bead, a = (i - 1) / 22 * math.pi * 2, r = 0.5 + (i % 2) * 0.03, s = 0.42 + (i % 4) * 0.08 })
	end
	-- искры
	local emitter = B.part(m, "Sparks", Vector3.new(d * 0.8, d * 0.8, 0.1), cf * CFrame.new(0, 0, -0.1), Color3.new(0, 0, 0),
		nil, { Transparency = 1, CastShadow = false, CanCollide = false, CanQuery = false })
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Config.Colors.PortalLight, Config.Colors.Portal)
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(0.7, 1.5)
	pe.Speed = NumberRange.new(2, 6)
	pe.Drag = 2
	pe.SpreadAngle = Vector2.new(60, 60)
	pe.Rate = 34
	pe.EmissionDirection = Enum.NormalId.Front
	pe.Parent = emitter
	self.emitter = pe
	self.sparkPart = emitter
	-- свет
	local lp = B.part(m, "LightPoint", Vector3.new(0.2, 0.2, 0.2), cf * CFrame.new(0, 0, -1.4), Color3.new(0, 0, 0),
		nil, { Transparency = 1, CastShadow = false, CanCollide = false, CanQuery = false })
	self.light = B.light(lp, "PointLight", { Color = Color3.fromRGB(110, 255, 70), Brightness = 3.2, Range = 26, Shadows = true })
	self.lightPart = lp
	m.Parent = parent or workspace
	self:apply()
	self.conn = RunService.RenderStepped:Connect(function(dt) self:update(dt) end)
	return self
end

-- применить масштаб ко всем частям
function Portal:apply()
	local s = math.max(self.scale, 0.01)
	local d = self.d * s
	local cf = self.cf
	self.disc.Size = Vector3.new(0.08, d, d)
	self.disc.CFrame = cf * CFrame.new(0, 0, 0.12) * CFrame.Angles(0, math.rad(90), 0)
	self.rim.Size = Vector3.new(0.06, d + 0.5 * s, d + 0.5 * s)
	self.rim.CFrame = cf * CFrame.new(0, 0, 0.18) * CFrame.Angles(0, math.rad(90), 0)
	self.panel.Size = Vector3.new(d, d, 0.04)
	self.panel.CFrame = cf
	for _, g in ipairs(self.panel:GetChildren()) do
		if g:IsA("SurfaceGui") then g.PixelsPerStud = math.clamp(420 / d, 10, 400) end
	end
	self.sparkPart.Size = Vector3.new(d * 0.8, d * 0.8, 0.1)
	self.sparkPart.CFrame = cf * CFrame.new(0, 0, -0.1)
	self.light.Range = 8 + 18 * math.min(s, 1.5)
	self.lightPart.CFrame = cf * CFrame.new(0, 0, -1.4 * s)
end

function Portal:update(dt)
	self.t = self.t + dt
	for _, l in ipairs(self.layers) do
		l.g.Rotation = (l.g.Rotation + l.sp * dt) % 360
	end
	local s = math.max(self.scale, 0.01)
	local r0 = self.d * s
	for i, b in ipairs(self.beads) do
		b.a = b.a + dt * (1.6 + (i % 3) * 0.4)
		local wob = 1 + math.sin(self.t * 5 + i) * 0.035
		local r = r0 * b.r * wob
		b.p.CFrame = self.cf * CFrame.new(math.cos(b.a) * r, math.sin(b.a) * r, -0.05)
		local bs = b.s * s * (0.8 + 0.4 * math.abs(math.sin(self.t * 3 + i)))
		b.p.Size = Vector3.new(bs, bs, bs)
	end
	self.light.Brightness = 3 + math.sin(self.t * 4) * 0.4
end

-- плавно изменить размер (t секунд)
function Portal:scaleTo(s, t, style)
	local v = Instance.new("NumberValue")
	v.Value = self.scale
	v.Changed:Connect(function(x)
		self.scale = x
		if self.model.Parent then self:apply() end
	end)
	local tw = TweenService:Create(v, TweenInfo.new(t or 0.6, style or Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = s })
	tw:Play()
	tw.Completed:Connect(function() v:Destroy() end)
	return tw
end

function Portal:open(t)
	Audio.play("Whoosh", { at = self.panel, volume = 0.8 })
	self:scaleTo(1, t or 0.9)
	self.hum = Audio.loop("portal_hum_" .. tostring(self), "PortalHum", { at = self.panel, volume = 0.55, min = 4, max = 50 })
end

function Portal:destroy()
	if self.conn then self.conn:Disconnect() end
	if self.hum then Audio.stop("portal_hum_" .. tostring(self), 0.4) end
	if self.model then self.model:Destroy() end
end

return Portal
