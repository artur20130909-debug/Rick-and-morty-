-- Визуальные эффекты: взрывы, искры, ударные волны, ядерный гриб, орбитальный лазер,
-- бомбардировщик, предупреждающие круги, щиты, выстрелы ПВО.
-- Используются только встроенные текстуры Roblox (rbxasset://), поэтому всё работает сразу.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sounds = require(Shared.Sounds)

local Client = script.Parent
local State = require(Client.State)
local SoundPlayer = require(Client.SoundPlayer)
local CameraShake = require(Client.CameraShake)
local HUD = require(Client.UI.HUD)

local Fx = {}

local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local folder: Folder
local rng = Random.new()
local lastBulletSound = 0

local function quality(): number
	return State.settings.Graphics or 3
end

local function qmul(): number
	local q = quality()
	return q == 1 and 0.35 or (q == 2 and 0.65 or 1)
end

local function tween(obj: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	if not props.Parent then
		p.Parent = folder
	end
	return p
end

local function ns(points: { { number } }): NumberSequence
	local kps = {}
	for _, pt in points do
		table.insert(kps, NumberSequenceKeypoint.new(pt[1], pt[2]))
	end
	return NumberSequence.new(kps)
end

local function cs(points: { { any } }): ColorSequence
	local kps = {}
	for _, pt in points do
		table.insert(kps, ColorSequenceKeypoint.new(pt[1], pt[2]))
	end
	return ColorSequence.new(kps)
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.LightInfluence = 0
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- Точка с прикреплением, к которой цепляются частицы
local function holderAt(pos: Vector3, life: number): (Part, Attachment)
	local h = part({ Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(pos) })
	local a = Instance.new("Attachment")
	a.Parent = h
	Debris:AddItem(h, life)
	return h, a
end

local function camDistance(pos: Vector3): number
	return (workspace.CurrentCamera.CFrame.Position - pos).Magnitude
end

local function soundDelay(pos: Vector3): number
	return math.min(camDistance(pos) / Sounds.SpeedOfSound, 3)
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundBelow(pos: Vector3, depth: number): RaycastResult?
	local list: { Instance } = { folder }
	local debris = workspace:FindFirstChild("Debris")
	if debris then
		table.insert(list, debris)
	end
	for _, p in game:GetService("Players"):GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	groundParams.FilterDescendantsInstances = list
	return workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -depth - 1, 0), groundParams)
end

local function scorch(pos: Vector3, radius: number)
	if quality() == 1 then
		return
	end
	local hit = groundBelow(pos, radius * 0.8 + 2)
	if not hit or hit.Material == Enum.Material.Water then
		return
	end
	local d = radius * 1.3
	local cf = CFrame.lookAt(hit.Position, hit.Position + hit.Normal) * CFrame.Angles(0, math.pi / 2, 0)
	local mark = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.06, d, d),
		CFrame = cf * CFrame.new(-0.02, 0, 0),
		Color = Color3.fromRGB(24, 20, 18),
		Material = Enum.Material.Ground,
		Transparency = 0.15,
	})
	task.delay(12, function()
		tween(mark, 10, { Transparency = 1 })
	end)
	Debris:AddItem(mark, 23)
end

local function chunks(pos: Vector3, count: number, speed: number, color: Color3?)
	count = math.floor(count * qmul())
	for _ = 1, count do
		local s = rng:NextNumber(0.4, 1.3)
		local c = part({
			Size = Vector3.new(s, s * rng:NextNumber(0.5, 1), s),
			CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Color = color or Color3.fromRGB(60, 56, 52),
			Material = Enum.Material.Slate,
			Anchored = false,
			CanCollide = true,
			CastShadow = true,
		})
		c.CollisionGroup = "Debris"
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.4, 1.4), rng:NextNumber(-1, 1)).Unit
		c.AssemblyLinearVelocity = dir * speed * rng:NextNumber(0.5, 1.1)
		c.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-10, 10), rng:NextNumber(-10, 10))
		task.delay(2.5, function()
			tween(c, 0.8, { Transparency = 1 })
		end)
		Debris:AddItem(c, 3.4)
	end
end

local function ring(pos: Vector3, from: number, to: number, time: number, color: Color3, transparency: number)
	local r = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, from, from),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = transparency,
	})
	tween(r, time, { Size = Vector3.new(0.2, to, to), Transparency = 1 })
	Debris:AddItem(r, time + 0.1)
end

-- ВЗРЫВЫ ----------------------------------------------------------------------------
local SIZES = {
	Small = { sound = "ExplosionSmall", shake = 0.5 },
	Medium = { sound = "ExplosionMedium", shake = 0.9 },
	Large = { sound = "ExplosionLarge", shake = 1.6 },
	Huge = { sound = "ExplosionHuge", shake = 2.6 },
}

export type ExplosionOpts = { water: boolean?, air: boolean?, aa: boolean?, shake: number? }

function Fx.explosion(size: string, pos: Vector3, R: number, o: ExplosionOpts?)
	local opts: ExplosionOpts = o or {}
	local info = SIZES[size] or SIZES.Medium
	local m = qmul()
	local life = 8
	local holder, att = holderAt(pos, life)

	-- вспышка
	local flash = part({
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 232, 180),
		Size = Vector3.one * R * 0.4,
		CFrame = CFrame.new(pos),
	})
	tween(flash, 0.22, { Size = Vector3.one * R * 1.9, Transparency = 1 })
	Debris:AddItem(flash, 0.3)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = math.min(60, R * 5)
	light.Brightness = 12
	light.Shadows = quality() == 3
	light.Parent = holder
	tween(light, 0.8, { Brightness = 0 })

	if opts.water then
		-- столб воды
		local splash = emitter(att, {
			Texture = SMOKE,
			LightInfluence = 1,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(14, 14),
			Speed = NumberRange.new(R * 2.5, R * 5),
			Acceleration = Vector3.new(0, -90, 0),
			Lifetime = NumberRange.new(0.8, 1.6),
			Size = ns({ { 0, R * 0.25 }, { 1, R * 0.8 } }),
			Color = cs({ { 0, Color3.fromRGB(240, 248, 255) }, { 1, Color3.fromRGB(200, 220, 230) } }),
			Transparency = ns({ { 0, 0.15 }, { 1, 1 } }),
		})
		splash:Emit(math.floor((14 + R * 2) * m))
		ring(pos + Vector3.new(0, 0.3, 0), R * 0.5, R * 3, 0.9, Color3.fromRGB(220, 240, 255), 0.4)
		SoundPlayer.play("Splash", { position = pos, delay = soundDelay(pos) })
	end

	local fire = emitter(att, {
		Texture = FIRE,
		LightEmission = 0.9,
		Speed = NumberRange.new(R * 1.2, R * 3),
		Drag = 5,
		Lifetime = NumberRange.new(0.35, 0.85),
		Size = ns({ { 0, R * 0.35 }, { 0.35, R * 0.8 }, { 1, R * 0.25 } }),
		Color = cs({ { 0, Color3.fromRGB(255, 244, 200) }, { 0.3, Color3.fromRGB(255, 150, 50) }, { 1, Color3.fromRGB(110, 40, 20) } }),
		Transparency = ns({ { 0, 0.05 }, { 0.7, 0.45 }, { 1, 1 } }),
		ZOffset = 1,
	})
	fire:Emit(math.floor((10 + R * 2.2) * m))

	local smoke = emitter(att, {
		Texture = SMOKE,
		LightInfluence = 1,
		Speed = NumberRange.new(R * 0.4, R * 1.2),
		Drag = 1.6,
		Lifetime = NumberRange.new(2.5, 5),
		Acceleration = Vector3.new(0, R * 0.25 + 2, 0),
		Size = ns({ { 0, R * 0.45 }, { 1, R * 1.5 } }),
		Color = cs({ { 0, Color3.fromRGB(78, 72, 66) }, { 1, Color3.fromRGB(46, 44, 42) } }),
		Transparency = ns({ { 0, 0.15 }, { 0.6, 0.5 }, { 1, 1 } }),
	})
	smoke:Emit(math.floor((6 + R * 1.2) * m))

	local sparks = emitter(att, {
		Texture = SPARK,
		LightEmission = 1,
		Speed = NumberRange.new(R * 3, R * 7),
		Acceleration = Vector3.new(0, -80, 0),
		Drag = 1,
		Lifetime = NumberRange.new(0.5, 1.4),
		Size = ns({ { 0, R * 0.06 + 0.25 }, { 1, 0 } }),
		Color = cs({ { 0, Color3.fromRGB(255, 236, 150) }, { 1, Color3.fromRGB(255, 110, 40) } }),
	})
	sparks:Emit(math.floor((8 + R * 2) * m))

	if size ~= "Small" and not opts.air then
		ring(pos, R * 0.5, R * 3.2, 0.5, Color3.fromRGB(255, 210, 160), 0.55)
	end
	if (size == "Large" or size == "Huge") and not opts.water then
		chunks(pos, size == "Huge" and 18 or 9, R * 3)
	end
	if not opts.air and not opts.water then
		scorch(pos, R)
	end
	SoundPlayer.play(info.sound, { position = pos, delay = soundDelay(pos), speed = rng:NextNumber(0.9, 1.1) })
	local dist = camDistance(pos)
	local shake = (opts.shake or info.shake) * math.clamp(1 - dist / (R * 30 + 120), 0, 1) * 4
	if shake > 0.05 then
		task.delay(soundDelay(pos), function()
			CameraShake.shake(shake, 0.5 + R * 0.03)
		end)
	end
	if dist < R * 1.5 then
		HUD.flash(Color3.fromRGB(255, 220, 180), 0.35, 0.4)
	end
end

-- ПОПАДАНИЕ ПУЛИ ------------------------------------------------------------------------
function Fx.impact(pos: Vector3, normal: Vector3?, water: boolean?, shield: boolean?)
	local _, att = holderAt(pos, 2)
	local n = normal or Vector3.yAxis
	att.WorldCFrame = CFrame.lookAt(pos, pos + n) * CFrame.Angles(-math.pi / 2, 0, 0)
	if water then
		emitter(att, {
			Texture = SMOKE,
			LightInfluence = 1,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(12, 12),
			Speed = NumberRange.new(10, 20),
			Acceleration = Vector3.new(0, -60, 0),
			Lifetime = NumberRange.new(0.4, 0.7),
			Size = ns({ { 0, 0.4 }, { 1, 1.4 } }),
			Color = cs({ { 0, Color3.new(1, 1, 1) }, { 1, Color3.fromRGB(210, 230, 240) } }),
			Transparency = ns({ { 0, 0.2 }, { 1, 1 } }),
		}):Emit(5)
		return
	end
	emitter(att, {
		Texture = SPARK,
		LightEmission = 1,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(50, 50),
		Speed = NumberRange.new(14, 32),
		Acceleration = Vector3.new(0, -70, 0),
		Lifetime = NumberRange.new(0.15, 0.4),
		Size = ns({ { 0, 0.3 }, { 1, 0 } }),
		Color = shield and cs({ { 0, Color3.fromRGB(160, 230, 255) }, { 1, Color3.fromRGB(60, 140, 255) } })
			or cs({ { 0, Color3.fromRGB(255, 240, 170) }, { 1, Color3.fromRGB(255, 140, 50) } }),
	}):Emit(math.max(3, math.floor(8 * qmul())))
	emitter(att, {
		Texture = SMOKE,
		LightInfluence = 1,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(30, 30),
		Speed = NumberRange.new(2, 6),
		Lifetime = NumberRange.new(0.6, 1.1),
		Size = ns({ { 0, 0.4 }, { 1, 1.6 } }),
		Color = cs({ { 0, Color3.fromRGB(150, 140, 130) }, { 1, Color3.fromRGB(110, 106, 100) } }),
		Transparency = ns({ { 0, 0.4 }, { 1, 1 } }),
	}):Emit(2)
	if os.clock() - lastBulletSound > 0.06 then
		lastBulletSound = os.clock()
		SoundPlayer.play("BulletHit", { position = pos, speed = rng:NextNumber(0.85, 1.3) })
	end
end

-- РАЗРУШЕННЫЕ БЛОКИ -----------------------------------------------------------------
function Fx.blocksBroken(list: { any }, kind: string)
	local m = qmul()
	for i, e in list do
		if i > math.max(4, math.floor(24 * m)) then
			break
		end
		local pos, color = e[1], e[2]
		local _, att = holderAt(pos, 4)
		emitter(att, {
			Texture = SMOKE,
			LightInfluence = 1,
			Speed = NumberRange.new(2, 8),
			Drag = 2,
			Lifetime = NumberRange.new(1.2, 2.4),
			Size = ns({ { 0, 1.5 }, { 1, 4.5 } }),
			Color = cs({ { 0, color:Lerp(Color3.fromRGB(120, 116, 110), 0.5) }, { 1, Color3.fromRGB(90, 86, 82) } }),
			Transparency = ns({ { 0, 0.3 }, { 1, 1 } }),
		}):Emit(3)
		if i <= 6 and kind ~= "nuke" then
			chunks(pos, 3, 30, color)
		end
	end
	if #list > 0 then
		local first = list[1][1]
		SoundPlayer.play(rng:NextNumber() < 0.5 and "Debris" or "MetalCrash", { position = first, speed = rng:NextNumber(0.85, 1.15) })
	end
end

-- ЯДЕРНЫЙ ВЗРЫВ ---------------------------------------------------------------------
function Fx.nuke(pos: Vector3)
	local m = qmul()
	local ground = pos - Vector3.new(0, 28, 0)
	local dist = camDistance(pos)
	local delay = math.min(dist / Sounds.SpeedOfSound, 4)

	-- 1. Ослепительная вспышка
	HUD.flash(Color3.new(1, 1, 1), math.clamp(1.2 - dist / 4000, 0.6, 1), 3)
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if bloom then
		local bi, bs = bloom.Intensity, bloom.Size
		bloom.Intensity = 3
		bloom.Size = 56
		tween(bloom, 4, { Intensity = bi, Size = bs })
	end
	if cc then
		local tint, br, sat = cc.TintColor, cc.Brightness, cc.Saturation
		cc.Brightness = 0.5
		cc.TintColor = Color3.fromRGB(255, 196, 150)
		cc.Saturation = -0.15
		tween(cc, 2.5, { Brightness = br })
		task.delay(3, function()
			tween(cc, 16, { TintColor = tint, Saturation = sat })
		end)
	end
	if atmo then
		local haze, color = atmo.Haze, atmo.Color
		tween(atmo, 4, { Haze = 3.2, Color = Color3.fromRGB(210, 170, 140) })
		task.delay(8, function()
			tween(atmo, 22, { Haze = haze, Color = color })
		end)
	end

	-- 2. Огненный шар
	local fireball = part({
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		Color = Color3.new(1, 1, 1),
		Size = Vector3.one * 6,
		CFrame = CFrame.new(pos),
	})
	tween(fireball, 1.4, { Size = Vector3.one * 95, Color = Color3.fromRGB(255, 190, 70) }, Enum.EasingStyle.Quart)
	task.delay(1.4, function()
		tween(fireball, 3, { Color = Color3.fromRGB(255, 80, 20), Transparency = 0.35, CFrame = CFrame.new(pos + Vector3.new(0, 60, 0)) })
		task.wait(3)
		tween(fireball, 3, { Transparency = 1, Size = Vector3.one * 120 })
	end)
	Debris:AddItem(fireball, 8)
	local light = Instance.new("PointLight")
	light.Range = 120
	light.Brightness = 40
	light.Color = Color3.fromRGB(255, 200, 140)
	light.Shadows = true
	light.Parent = fireball
	tween(light, 7, { Brightness = 0 })

	-- 3. Ударная волна и купол давления
	ring(ground + Vector3.new(0, 1.5, 0), 20, 1600, 4.5, Color3.fromRGB(255, 236, 210), 0.25)
	local dome = part({
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.ForceField,
		Color = Color3.fromRGB(255, 220, 190),
		Size = Vector3.one * 10,
		CFrame = CFrame.new(ground),
	})
	tween(dome, 1.6, { Size = Vector3.one * 520, Transparency = 1 })
	Debris:AddItem(dome, 1.7)

	-- 4. Гриб: ножка, шляпка и кольцо
	local cap = part({ Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(pos) })
	local capAtt = Instance.new("Attachment")
	capAtt.Parent = cap
	local capFire = emitter(capAtt, {
		Texture = FIRE,
		LightEmission = 0.7,
		Rate = 60 * m,
		Speed = NumberRange.new(8, 22),
		Lifetime = NumberRange.new(1.5, 3),
		Size = ns({ { 0, 30 }, { 1, 55 } }),
		Color = cs({ { 0, Color3.fromRGB(255, 220, 140) }, { 0.5, Color3.fromRGB(255, 110, 40) }, { 1, Color3.fromRGB(90, 40, 20) } }),
		Transparency = ns({ { 0, 0.2 }, { 1, 1 } }),
		ZOffset = 2,
	})
	local capSmoke = emitter(capAtt, {
		Texture = SMOKE,
		LightInfluence = 0.6,
		LightEmission = 0.15,
		Rate = 45 * m,
		Speed = NumberRange.new(10, 30),
		Drag = 0.8,
		Lifetime = NumberRange.new(8, 14),
		Size = ns({ { 0, 40 }, { 0.5, 75 }, { 1, 95 } }),
		Color = cs({ { 0, Color3.fromRGB(150, 96, 60) }, { 0.4, Color3.fromRGB(104, 84, 72) }, { 1, Color3.fromRGB(80, 76, 74) } }),
		Transparency = ns({ { 0, 0.1 }, { 0.8, 0.4 }, { 1, 1 } }),
	})
	tween(cap, 12, { CFrame = CFrame.new(pos + Vector3.new(0, 250, 0)) }, Enum.EasingStyle.Sine)
	-- кольцо вокруг шляпки
	local ringAtts = {}
	for i = 1, (quality() == 1 and 5 or 10) do
		local a = Instance.new("Attachment")
		local ang = i / 10 * math.pi * 2
		a.Position = Vector3.new(math.cos(ang) * 45, -10, math.sin(ang) * 45)
		a.Parent = cap
		table.insert(ringAtts, emitter(a, {
			Texture = SMOKE,
			LightInfluence = 0.7,
			Rate = 6 * m,
			Speed = NumberRange.new(2, 8),
			Lifetime = NumberRange.new(6, 10),
			Size = ns({ { 0, 30 }, { 1, 60 } }),
			Color = cs({ { 0, Color3.fromRGB(140, 100, 74) }, { 1, Color3.fromRGB(90, 86, 84) } }),
			Transparency = ns({ { 0, 0.3 }, { 1, 1 } }),
		}))
	end
	-- ножка
	local stem = part({ Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(ground) })
	local stemAtt = Instance.new("Attachment")
	stemAtt.Parent = stem
	local stemSmoke = emitter(stemAtt, {
		Texture = SMOKE,
		LightInfluence = 0.7,
		LightEmission = 0.1,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(6, 6),
		Rate = 30 * m,
		Speed = NumberRange.new(26, 40),
		Lifetime = NumberRange.new(5, 7),
		Size = ns({ { 0, 22 }, { 1, 38 } }),
		Color = cs({ { 0, Color3.fromRGB(200, 120, 60) }, { 0.3, Color3.fromRGB(120, 96, 80) }, { 1, Color3.fromRGB(90, 88, 86) } }),
		Transparency = ns({ { 0, 0.15 }, { 1, 1 } }),
	})
	-- пылевая волна у земли
	local dust = emitter(stemAtt, {
		Texture = SMOKE,
		LightInfluence = 1,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(88, 88),
		Speed = NumberRange.new(70, 140),
		Drag = 0.9,
		Lifetime = NumberRange.new(4, 7),
		Size = ns({ { 0, 18 }, { 1, 50 } }),
		Color = cs({ { 0, Color3.fromRGB(170, 150, 128) }, { 1, Color3.fromRGB(120, 116, 110) } }),
		Transparency = ns({ { 0, 0.2 }, { 1, 1 } }),
	})
	dust:Emit(math.floor(60 * m))
	task.delay(4, function()
		capFire.Enabled = false
	end)
	task.delay(9, function()
		capSmoke.Enabled = false
		stemSmoke.Enabled = false
		for _, e in ringAtts do
			e.Enabled = false
		end
	end)
	Debris:AddItem(cap, 26)
	Debris:AddItem(stem, 18)
	chunks(ground + Vector3.new(0, 4, 0), 30, 140)

	-- 5. Звук и тряска приходят позже вспышки — как в жизни
	SoundPlayer.play("NukeBlast", { delay = delay })
	SoundPlayer.play("NukeRumble", { delay = delay + 0.3 })
	SoundPlayer.play("Thunder", { delay = delay, speed = 0.6 })
	task.delay(delay, function()
		local k = math.clamp(1 - dist / 2600, 0.2, 1)
		CameraShake.shake(7 * k, 5)
		CameraShake.shake(2 * k, 12, 6)
	end)

	-- 6. Пепел падает вокруг камеры
	if quality() >= 2 then
		local ash = part({ Transparency = 1, Size = Vector3.new(160, 1, 160) })
		local ashEmitter = emitter(ash, {
			Texture = SMOKE,
			LightInfluence = 1,
			EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(20, 20),
			Rate = 40,
			Speed = NumberRange.new(4, 9),
			Lifetime = NumberRange.new(6, 9),
			Size = ns({ { 0, 0.25 }, { 1, 0.15 } }),
			Color = cs({ { 0, Color3.fromRGB(80, 78, 76) }, { 1, Color3.fromRGB(50, 48, 46) } }),
			Transparency = ns({ { 0, 0.2 }, { 1, 1 } }),
		})
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not ash.Parent then
				conn:Disconnect()
				return
			end
			ash.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position + Vector3.new(0, 50, 0))
		end)
		task.delay(18, function()
			ashEmitter.Enabled = false
		end)
		Debris:AddItem(ash, 28)
	end
end

-- ПРЕДУПРЕЖДАЮЩИЙ КРУГ ----------------------------------------------------------------
function Fx.marker(pos: Vector3, radius: number, eta: number, nuke: boolean?)
	local hit = groundBelow(pos + Vector3.new(0, 60, 0), 120)
	local y = hit and hit.Position.Y or pos.Y
	local center = Vector3.new(pos.X, y + 0.15, pos.Z)
	local model = Instance.new("Model")
	model.Name = "Marker"
	model.Parent = folder
	local segs = nuke and 48 or 28
	local r = math.min(radius, nuke and 150 or 40)
	local color = nuke and Color3.fromRGB(255, 220, 40) or Color3.fromRGB(255, 50, 40)
	local pieces = {}
	for i = 1, segs do
		local a = i / segs * math.pi * 2
		local len = 2 * math.pi * r / segs * 0.6
		local p = part({
			Size = Vector3.new(len, 0.25, nuke and 1.4 or 0.5),
			CFrame = CFrame.new(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)) * CFrame.Angles(0, -a + math.pi / 2, 0),
			Color = color,
			Material = Enum.Material.Neon,
			Parent = model,
		})
		table.insert(pieces, p)
	end
	local disk = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, r * 2, r * 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.88,
		Parent = model,
	})
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 60)
	bb.StudsOffsetWorldSpace = Vector3.new(0, nuke and 30 or 8, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 1500
	bb.Adornee = disk
	bb.Parent = disk
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Parent = bb
	local started = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local left = eta - (os.clock() - started)
		if left <= 0 or not model.Parent then
			conn:Disconnect()
			model:Destroy()
			return
		end
		label.Text = (nuke and "☢ " or "⚠ ") .. string.format("%.1f", left)
		local pulse = (math.sin(os.clock() * (left < 1.5 and 22 or 10)) + 1) / 2
		for _, p in pieces do
			p.Transparency = 0.1 + pulse * 0.5
		end
		disk.Transparency = 0.93 - pulse * 0.08
	end)
end

-- ВЫСТРЕЛ ПВО -----------------------------------------------------------------------
function Fx.aaShot(from: Vector3, to: Vector3)
	local dir = to - from
	for i = 0, 3 do
		task.delay(i * 0.05, function()
			local t = part({
				Size = Vector3.new(0.18, 0.18, 6),
				CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -3),
				Color = Color3.fromRGB(255, 230, 120),
				Material = Enum.Material.Neon,
			})
			tween(t, 0.12, { CFrame = CFrame.lookAt(to, to + dir) * CFrame.new(0, 0, 3) }, Enum.EasingStyle.Linear)
			Debris:AddItem(t, 0.14)
		end)
	end
	local flash = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = CFrame.new(from), Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Neon })
	tween(flash, 0.12, { Transparency = 1, Size = Vector3.one * 3 })
	Debris:AddItem(flash, 0.15)
	-- чёрные клубы зенитных разрывов
	task.delay(0.15, function()
		local _, att = holderAt(to, 5)
		emitter(att, {
			Texture = SMOKE,
			LightInfluence = 1,
			Speed = NumberRange.new(2, 6),
			Lifetime = NumberRange.new(2, 3.5),
			Size = ns({ { 0, 2 }, { 1, 6 } }),
			Color = cs({ { 0, Color3.fromRGB(40, 38, 36) }, { 1, Color3.fromRGB(70, 68, 66) } }),
			Transparency = ns({ { 0, 0.2 }, { 1, 1 } }),
		}):Emit(4)
	end)
	SoundPlayer.play("AAShot", { position = from, speed = rng:NextNumber(1.05, 1.25) })
end

-- ЩИТ -------------------------------------------------------------------------------
function Fx.shield(data)
	if data.hit then
		local p = part({
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(110, 210, 255),
			Size = Vector3.one * 2,
			CFrame = CFrame.new(data.hit),
			Transparency = 0.2,
		})
		tween(p, 0.45, { Size = Vector3.one * 14, Transparency = 1 })
		Debris:AddItem(p, 0.5)
		SoundPlayer.play("ShieldHit", { position = data.hit })
	elseif data.up == false then
		SoundPlayer.play("ShieldDown", { position = data.p })
		local p = part({
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.ForceField,
			Color = Color3.fromRGB(255, 90, 90),
			Size = Vector3.one * data.r * 2,
			CFrame = CFrame.new(data.p),
		})
		tween(p, 0.8, { Size = Vector3.one * data.r * 2.6, Transparency = 1 })
		Debris:AddItem(p, 0.9)
	end
end

-- ОРБИТАЛЬНЫЙ ЛАЗЕР -----------------------------------------------------------------
type Laser = {
	phase: string,
	x: number,
	z: number,
	y: number,
	radius: number,
	model: Model,
	reticle: { Part },
	guide: BasePart,
	core: BasePart?,
	glow: BasePart?,
	impact: BasePart?,
	loop: Sound?,
	lastScorch: number,
}
local lasers: { [number]: Laser } = {}

local function laserCF(x: number, y: number, z: number, length: number): CFrame
	return CFrame.new(x, y + length / 2, z) * CFrame.Angles(0, 0, math.pi / 2)
end

function Fx.laserState(data)
	local id = data.id
	if data.phase == "charge" then
		local model = Instance.new("Model")
		model.Name = "Laser" .. id
		model.Parent = folder
		local r = data.r or 5
		local reticle = {}
		for i = 1, 16 do
			local a = i / 16 * math.pi * 2
			table.insert(reticle, part({
				Size = Vector3.new(1.6, 0.2, 0.35),
				Color = Color3.fromRGB(255, 40, 40),
				Material = Enum.Material.Neon,
				Parent = model,
				CFrame = CFrame.new(data.p + Vector3.new(math.cos(a) * r * 1.6, 0.3, math.sin(a) * r * 1.6)),
			}))
		end
		local guide = part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1600, 0.25, 0.25),
			Color = Color3.fromRGB(255, 40, 40),
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			Parent = model,
			CFrame = laserCF(data.p.X, data.p.Y, data.p.Z, 1600),
		})
		lasers[id] = {
			phase = "charge", x = data.p.X, z = data.p.Z, y = data.p.Y, radius = r,
			model = model, reticle = reticle, guide = guide, lastScorch = 0,
		}
		SoundPlayer.play("LaserCharge", { position = data.p })
		SoundPlayer.play("Thunder", { speed = 1.3, volume = 0.5 })
	elseif data.phase == "fire" then
		local L = lasers[id]
		if not L then
			return
		end
		L.phase = "fire"
		L.guide.Transparency = 1
		local r = L.radius
		L.core = part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1600, r * 1.1, r * 1.1),
			Color = Color3.fromRGB(255, 250, 235),
			Material = Enum.Material.Neon,
			Parent = L.model,
			CFrame = laserCF(L.x, L.y, L.z, 1600),
		})
		L.glow = part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1600, r * 2.8, r * 2.8),
			Color = Color3.fromRGB(255, 70, 30),
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			Parent = L.model,
			CFrame = laserCF(L.x, L.y, L.z, 1600),
		})
		local impact = part({ Transparency = 1, Size = Vector3.one, Parent = L.model, CFrame = CFrame.new(L.x, L.y, L.z) })
		local att = Instance.new("Attachment")
		att.Parent = impact
		local light = Instance.new("PointLight")
		light.Range = 70
		light.Brightness = 14
		light.Color = Color3.fromRGB(255, 140, 90)
		light.Shadows = true
		light.Parent = impact
		emitter(att, {
			Texture = SPARK,
			LightEmission = 1,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(70, 70),
			Rate = 140 * qmul(),
			Speed = NumberRange.new(20, 55),
			Acceleration = Vector3.new(0, -90, 0),
			Lifetime = NumberRange.new(0.4, 1.1),
			Size = ns({ { 0, 0.6 }, { 1, 0 } }),
			Color = cs({ { 0, Color3.fromRGB(255, 240, 180) }, { 1, Color3.fromRGB(255, 90, 30) } }),
		})
		emitter(att, {
			Texture = FIRE,
			LightEmission = 0.9,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(30, 30),
			Rate = 50 * qmul(),
			Speed = NumberRange.new(6, 14),
			Lifetime = NumberRange.new(0.4, 0.8),
			Size = ns({ { 0, r * 1.2 }, { 1, r * 0.4 } }),
			Color = cs({ { 0, Color3.fromRGB(255, 230, 170) }, { 1, Color3.fromRGB(255, 80, 30) } }),
			Transparency = ns({ { 0, 0.1 }, { 1, 1 } }),
		})
		emitter(att, {
			Texture = SMOKE,
			LightInfluence = 1,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(20, 20),
			Rate = 18 * qmul(),
			Speed = NumberRange.new(12, 24),
			Lifetime = NumberRange.new(2, 4),
			Size = ns({ { 0, 3 }, { 1, 12 } }),
			Color = cs({ { 0, Color3.fromRGB(70, 64, 60) }, { 1, Color3.fromRGB(110, 106, 102) } }),
			Transparency = ns({ { 0, 0.3 }, { 1, 1 } }),
		})
		L.impact = impact
		L.loop = SoundPlayer.play("LaserLoop", { parent = impact, loop = true })
		SoundPlayer.play("LaserFire", { position = Vector3.new(L.x, L.y, L.z) })
		local d = camDistance(Vector3.new(L.x, L.y, L.z))
		CameraShake.shake(2.2 * math.clamp(1 - d / 600, 0.1, 1), data.t or 5, 30)
		HUD.flash(Color3.fromRGB(255, 210, 190), math.clamp(0.6 - d / 1500, 0.1, 0.6), 0.6)
	elseif data.phase == "end" then
		local L = lasers[id]
		if not L then
			return
		end
		lasers[id] = nil
		if L.loop then
			SoundPlayer.fadeOut(L.loop, 0.5)
		end
		SoundPlayer.play("LaserEnd", { position = Vector3.new(L.x, L.y, L.z) })
		for _, p in { L.core, L.glow } do
			if p then
				tween(p, 0.45, { Size = Vector3.new(1600, 0.05, 0.05), Transparency = 1 })
			end
		end
		for _, p in L.reticle do
			tween(p, 0.4, { Transparency = 1 })
		end
		Debris:AddItem(L.model, 0.6)
	end
end

function Fx.laserTick(id: number, x: number, z: number, y: number?)
	local L = lasers[id]
	if not L then
		return
	end
	L.x, L.z = x, z
	if y then
		L.y = y
	end
end

local function updateLasers(dt: number)
	local t = os.clock()
	for _, L in lasers do
		local cf = laserCF(L.x, L.y, L.z, 1600)
		L.guide.CFrame = cf
		for i, p in L.reticle do
			local a = i / #L.reticle * math.pi * 2 + t * 1.5
			local rr = L.radius * (L.phase == "charge" and (1.6 + math.sin(t * 6) * 0.2) or 1.3)
			p.CFrame = CFrame.new(L.x + math.cos(a) * rr, L.y + 0.3, L.z + math.sin(a) * rr) * CFrame.Angles(0, -a, 0)
		end
		if L.core and L.glow then
			local flicker = 1 + math.sin(t * 40) * 0.06
			L.core.CFrame = cf
			L.glow.CFrame = cf
			L.glow.Size = Vector3.new(1600, L.radius * 2.8 * flicker, L.radius * 2.8 * flicker)
		end
		if L.impact then
			L.impact.CFrame = CFrame.new(L.x, L.y, L.z)
			if t - L.lastScorch > 0.3 then
				L.lastScorch = t
				scorch(Vector3.new(L.x, L.y + 1, L.z), L.radius * 0.9)
			end
		end
	end
end

-- БОМБАРДИРОВЩИК --------------------------------------------------------------------
function Fx.bomber(data)
	local s, e, v = data.s, data.e, data.v
	local dir = (e - s).Unit
	local total = (e - s).Magnitude / v
	local model = Instance.new("Model")
	model.Name = "Bomber"
	local body = Color3.fromRGB(78, 84, 92)
	local fus = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(34, 4.4, 4.4), Color = body, Material = Enum.Material.Metal, Parent = model })
	local function rel(p: BasePart, cf: CFrame)
		p:SetAttribute("Rel", cf)
	end
	rel(fus, CFrame.Angles(0, math.pi / 2, 0))
	local nose = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 4.4, Color = body, Material = Enum.Material.Metal, Parent = model })
	rel(nose, CFrame.new(0, 0, -17))
	local glass = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2, 4), Color = Color3.fromRGB(30, 40, 60), Material = Enum.Material.Glass, Reflectance = 0.4, Parent = model })
	rel(glass, CFrame.new(0, 1.6, -14))
	local wing = part({ Size = Vector3.new(44, 0.7, 7), Color = body, Material = Enum.Material.Metal, Parent = model })
	rel(wing, CFrame.new(0, -0.6, -2))
	local tail = part({ Size = Vector3.new(14, 0.5, 4), Color = body, Material = Enum.Material.Metal, Parent = model })
	rel(tail, CFrame.new(0, 0.5, 15))
	local fin = part({ Size = Vector3.new(0.5, 7, 5), Color = body, Material = Enum.Material.Metal, Parent = model })
	rel(fin, CFrame.new(0, 3.8, 15))
	local stripe = part({ Size = Vector3.new(0.55, 2, 2), Color = Color3.fromRGB(170, 30, 30), Material = Enum.Material.SmoothPlastic, Parent = model })
	rel(stripe, CFrame.new(0, 4.5, 15.5))
	local trails = {}
	for _, x in { -14, -7, 7, 14 } do
		local eng = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 2.2, 2.2), Color = Color3.fromRGB(60, 62, 66), Material = Enum.Material.Metal, Parent = model })
		rel(eng, CFrame.new(x, -1.6, -1) * CFrame.Angles(0, math.pi / 2, 0))
		local glow = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.8, 1.8), Color = Color3.fromRGB(255, 150, 60), Material = Enum.Material.Neon, Parent = model })
		rel(glow, CFrame.new(x, -1.6, 2.1) * CFrame.Angles(0, math.pi / 2, 0))
		local a = Instance.new("Attachment")
		a.Parent = glow
		table.insert(trails, emitter(a, {
			Texture = SMOKE,
			LightInfluence = 1,
			Rate = 30 * qmul(),
			Speed = NumberRange.new(0, 1),
			SpreadAngle = Vector2.new(2, 2),
			Lifetime = NumberRange.new(3, 4.5),
			Size = ns({ { 0, 1.2 }, { 1, 4.5 } }),
			Color = cs({ { 0, Color3.new(1, 1, 1) }, { 1, Color3.fromRGB(220, 225, 230) } }),
			Transparency = ns({ { 0, 0.4 }, { 1, 1 } }),
		}))
	end
	model.Parent = folder
	local jet = SoundPlayer.play("Jet", { parent = fus })
	local base = data.t
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local k = now - base
		if k > total or not model.Parent then
			conn:Disconnect()
			for _, tr in trails do
				tr.Enabled = false
			end
			task.delay(4, function()
				model:Destroy()
			end)
			return
		end
		local pos = s + dir * v * math.max(0, k)
		local cf = CFrame.lookAt(pos, pos + dir)
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				local r = p:GetAttribute("Rel") :: CFrame?
				if r then
					p.CFrame = cf * r
				end
			end
		end
	end)
	task.delay(total + 5, function()
		if jet and jet.Parent then
			jet:Destroy()
		end
	end)
end

function Fx.applyQuality()
	local q = quality()
	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if dof then
		dof.Enabled = q >= 3
	end
	if rays then
		rays.Enabled = q >= 2
	end
	if bloom then
		bloom.Enabled = q >= 2
	end
	Lighting.GlobalShadows = q >= 2
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Enabled = q >= 2
	end
end

function Fx.init()
	folder = Instance.new("Folder")
	folder.Name = "ClientFx"
	folder.Parent = workspace
	RunService.RenderStepped:Connect(updateLasers)
end

function Fx.folder(): Folder
	return folder
end

return Fx
