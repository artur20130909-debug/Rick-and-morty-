-- Снаряды на клиенте: красивые модели, дымные следы, свет, звук полёта.
-- Траекторию считает сервер; клиент повторяет её по формулам и подправляется по синхронизации.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Weapons = require(Shared.Weapons)
local Net = require(Shared.Net)

local Client = script.Parent
local State = require(Client.State)
local SoundPlayer = require(Client.SoundPlayer)
local Fx = require(Client.Fx)

local Projectiles = {}

local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

type Vis = {
	id: number,
	w: any,
	model: Model,
	root: BasePart,
	p0: Vector3,
	v0: Vector3,
	g: number,
	t0: number,
	pos: Vector3,
	vel: Vector3,
	guided: boolean,
	correction: Vector3,
	emitters: { ParticleEmitter },
	loop: Sound?,
	whistled: boolean,
	target: Vector3?,
	bomblet: boolean,
}

local active: { [number]: Vis } = {}
local lastLaunchSound: { [string]: number } = {}
local rng = Random.new()

local function quality(): number
	return State.settings.Graphics or 3
end

local function ns(a: number, b: number): NumberSequence
	return NumberSequence.new(a, b)
end

local function basePart(model: Model, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = model
	return p
end

-- Детали модели снаряда хранят смещение относительно «корня» (вдоль -Z — вперёд)
local function attach(model: Model, root: BasePart, rel: CFrame, props: { [string]: any }): Part
	local p = basePart(model, props)
	p:SetAttribute("Rel", rel)
	return p
end

local ALONG = CFrame.Angles(0, math.pi / 2, 0) -- цилиндр осью вдоль Z

local function smokeTrail(parent: Instance, size: number, life: number, color: Color3?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Rate = (quality() == 1 and 25 or 70)
	e.Lifetime = NumberRange.new(life * 0.7, life)
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(8, 8)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, size * 2.6) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(color or Color3.fromRGB(205, 200, 195), Color3.fromRGB(150, 148, 146))
	e.LightInfluence = 1
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Parent = parent
	return e
end

local function flame(parent: Instance, size: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = FIRE
	e.Rate = 120
	e.Lifetime = NumberRange.new(0.08, 0.18)
	e.Speed = NumberRange.new(5, 12)
	e.EmissionDirection = Enum.NormalId.Back
	e.SpreadAngle = Vector2.new(10, 10)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.2) })
	e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 190), Color3.fromRGB(255, 110, 40))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Parent = parent
	return e
end

local function exhaustLight(parent: Instance, range: number)
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 160, 90)
	l.Range = range
	l.Brightness = 3
	l.Parent = parent
end

-- МОДЕЛИ ----------------------------------------------------------------------------
local function buildVisual(kind: string, w): (Model, BasePart, { ParticleEmitter })
	local model = Instance.new("Model")
	model.Name = "Projectile"
	local emitters = {}
	local root: Part
	if kind == "Tracer" then
		root = basePart(model, {
			Size = Vector3.new(0.16, 0.16, 5),
			Color = w.color or Color3.fromRGB(255, 220, 130),
			Material = Enum.Material.Neon,
		})
	elseif kind == "Grenade" then
		root = basePart(model, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Color = Color3.fromRGB(60, 80, 50), Material = Enum.Material.Metal })
		local a = Instance.new("Attachment")
		a.Parent = root
		table.insert(emitters, smokeTrail(a, 0.4, 0.8, Color3.fromRGB(180, 180, 175)))
	elseif kind == "Bomblet" then
		root = basePart(model, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, Color = Color3.fromRGB(70, 70, 64), Material = Enum.Material.Metal })
		local a = Instance.new("Attachment")
		a.Parent = root
		table.insert(emitters, smokeTrail(a, 0.3, 0.5))
	elseif kind == "Shell" then
		root = basePart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 0.9, 0.9), Color = Color3.fromRGB(56, 64, 52), Material = Enum.Material.Metal })
		root:SetAttribute("Spin", ALONG)
		local a = Instance.new("Attachment")
		a.Parent = root
		table.insert(emitters, smokeTrail(a, 0.5, 1.2, Color3.fromRGB(170, 168, 160)))
	elseif kind == "Rocket" or kind == "Missile" or kind == "BigMissile" or kind == "Reentry" then
		local big = kind == "BigMissile" or kind == "Reentry"
		local len = big and 9 or (kind == "Missile" and 5 or 3.2)
		local d = big and 1.8 or (kind == "Missile" and 1.1 or 0.8)
		local bodyColor = kind == "Rocket" and Color3.fromRGB(86, 96, 70) or Color3.fromRGB(232, 234, 238)
		if kind == "Reentry" then
			bodyColor = Color3.fromRGB(255, 190, 120)
		end
		root = basePart(model, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(len, d, d),
			Color = bodyColor,
			Material = kind == "Reentry" and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		})
		root:SetAttribute("Spin", ALONG)
		attach(model, root, CFrame.new(0, 0, -len / 2 - d * 0.3), {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(d, d, d * 1.6),
			Color = kind == "Reentry" and Color3.fromRGB(255, 240, 200) or Color3.fromRGB(200, 40, 40),
			Material = kind == "Reentry" and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		})
		for i = 0, 3 do
			local a = i * math.pi / 2
			attach(model, root, CFrame.new(0, 0, len / 2 - d * 0.6) * CFrame.Angles(0, 0, a) * CFrame.new(0, d * 0.75, 0), {
				Size = Vector3.new(0.12, d * 0.9, d * 1.2),
				Color = Color3.fromRGB(60, 62, 66),
				Material = Enum.Material.Metal,
			})
		end
		if big and kind == "BigMissile" then
			attach(model, root, CFrame.new(0, 0, 0.5), { Size = Vector3.new(7, 0.2, 2), Color = Color3.fromRGB(200, 202, 208), Material = Enum.Material.Metal })
		end
		local tail = Instance.new("Attachment")
		tail.Position = Vector3.new(0, 0, 0)
		tail.Parent = root
		tail:SetAttribute("Tail", len / 2)
		table.insert(emitters, flame(tail, d * 1.3))
		table.insert(emitters, smokeTrail(tail, d * 1.1, big and 4 or 2.6))
		exhaustLight(root, big and 30 or 16)
		if kind == "Reentry" then
			local glow = Instance.new("ParticleEmitter")
			glow.Texture = FIRE
			glow.Rate = 80
			glow.Lifetime = NumberRange.new(0.3, 0.6)
			glow.Speed = NumberRange.new(1, 4)
			glow.Size = ns(6, 2)
			glow.Color = ColorSequence.new(Color3.fromRGB(255, 220, 160), Color3.fromRGB(255, 80, 30))
			glow.LightEmission = 1
			glow.Parent = root
			table.insert(emitters, glow)
		end
	elseif kind == "Bomb" then
		root = basePart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.6, 1.6), Color = Color3.fromRGB(70, 76, 66), Material = Enum.Material.Metal })
		root:SetAttribute("Spin", ALONG)
		attach(model, root, CFrame.new(0, 0, -2.1), { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, Color = Color3.fromRGB(70, 76, 66), Material = Enum.Material.Metal })
		attach(model, root, CFrame.new(0, 0, 2.2), { Size = Vector3.new(2.2, 0.15, 1), Color = Color3.fromRGB(50, 52, 50), Material = Enum.Material.Metal })
		attach(model, root, CFrame.new(0, 0, 2.2), { Size = Vector3.new(0.15, 2.2, 1), Color = Color3.fromRGB(50, 52, 50), Material = Enum.Material.Metal })
		attach(model, root, ALONG, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.65, 1.65), Color = Color3.fromRGB(240, 200, 40) })
	elseif kind == "Nuke" then
		root = basePart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 3.2, 3.2), Color = Color3.fromRGB(78, 88, 70), Material = Enum.Material.Metal })
		root:SetAttribute("Spin", CFrame.Angles(0, 0, math.pi / 2)) -- вертикально
		attach(model, root, CFrame.new(0, -3.6, 0), { Shape = Enum.PartType.Ball, Size = Vector3.new(3.2, 3.4, 3.2), Color = Color3.fromRGB(78, 88, 70), Material = Enum.Material.Metal })
		for i, y in { 1.4, -1 } do
			attach(model, root, CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), {
				Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 3.3, 3.3),
				Color = i == 1 and Color3.fromRGB(250, 210, 30) or Color3.fromRGB(20, 20, 20), Material = Enum.Material.SmoothPlastic,
			})
		end
		attach(model, root, CFrame.new(0, 4.2, 0), { Size = Vector3.new(4, 1.4, 0.2), Color = Color3.fromRGB(50, 54, 50), Material = Enum.Material.Metal })
		attach(model, root, CFrame.new(0, 4.2, 0), { Size = Vector3.new(0.2, 1.4, 4), Color = Color3.fromRGB(50, 54, 50), Material = Enum.Material.Metal })
		-- парашют
		attach(model, root, CFrame.new(0, 22, 0), {
			Shape = Enum.PartType.Ball, Size = Vector3.new(24, 9, 24),
			Color = Color3.fromRGB(240, 120, 40), Material = Enum.Material.Fabric,
		})
		attach(model, root, CFrame.new(0, 21.5, 0), {
			Shape = Enum.PartType.Ball, Size = Vector3.new(24.3, 8, 24.3),
			Color = Color3.fromRGB(245, 245, 240), Material = Enum.Material.Fabric, Transparency = 0.4,
		})
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			local top = Vector3.new(math.cos(a) * 11, 20, math.sin(a) * 11)
			local bottom = Vector3.new(0, 4.5, 0)
			local mid = (top + bottom) / 2
			attach(model, root, CFrame.lookAt(mid, top), { Size = Vector3.new(0.1, 0.1, (top - bottom).Magnitude), Color = Color3.fromRGB(220, 220, 220) })
		end
		local blink = attach(model, root, CFrame.new(0, -1.8, -1.7), { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, Color = Color3.fromRGB(255, 40, 40), Material = Enum.Material.Neon })
		blink:SetAttribute("Blink", true)
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 40, 40)
		l.Range = 18
		l.Brightness = 3
		l.Parent = blink
	else
		root = basePart(model, { Shape = Enum.PartType.Ball, Size = Vector3.one, Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon })
	end
	model.PrimaryPart = root
	return model, root, emitters
end

local function place(v: Vis, pos: Vector3, vel: Vector3)
	local dir = vel.Magnitude > 0.01 and vel.Unit or Vector3.new(0, -1, 0)
	local cf
	if v.w.key == "Nuke" and not v.bomblet then
		cf = CFrame.new(pos) * CFrame.Angles(math.sin(os.clock() * 1.3) * 0.08, os.clock() * 0.3, math.cos(os.clock() * 1.1) * 0.08)
	else
		cf = CFrame.lookAt(pos, pos + dir)
	end
	local spin = v.root:GetAttribute("Spin") :: CFrame?
	v.root.CFrame = spin and (cf * spin) or cf
	for _, p in v.model:GetChildren() do
		if p ~= v.root and p:IsA("BasePart") then
			local rel = p:GetAttribute("Rel") :: CFrame?
			if rel then
				p.CFrame = cf * rel
			end
			if p:GetAttribute("Blink") then
				p.Transparency = (math.floor(os.clock() * 3) % 2 == 0) and 0 or 0.9
			end
		end
	end
	-- хвостовое крепление пламени — сзади корпуса (+Z в системе «смотрит вперёд»)
	for _, a in v.root:GetChildren() do
		if a:IsA("Attachment") then
			local tail = a:GetAttribute("Tail") :: number?
			if tail then
				a.WorldCFrame = cf * CFrame.new(0, 0, tail)
			end
		end
	end
end

-- Оставить дымный след висеть в воздухе после взрыва
local function detachTrails(v: Vis)
	for _, e in v.emitters do
		local att = e.Parent
		if att and att:IsA("Attachment") then
			local holder = Instance.new("Part")
			holder.Anchored = true
			holder.CanCollide = false
			holder.CanQuery = false
			holder.CanTouch = false
			holder.Transparency = 1
			holder.Size = Vector3.one * 0.2
			holder.CFrame = att.WorldCFrame
			holder.Parent = Fx.folder()
			local na = Instance.new("Attachment")
			na.Parent = holder
			e.Parent = na
			e.Enabled = false
			Debris:AddItem(holder, 6)
		end
	end
end

local function remove(id: number)
	local v = active[id]
	if not v then
		return
	end
	active[id] = nil
	detachTrails(v)
	if v.loop then
		SoundPlayer.fadeOut(v.loop, 0.2)
	end
	v.model:Destroy()
end

local function onSpawn(d)
	local w = Weapons.ByKey[d.w]
	if not w then
		return
	end
	local kind = d.b and "Bomblet" or w.visual
	local model, root, emitters = buildVisual(kind, w)
	local v: Vis = {
		id = d.id,
		w = w,
		model = model,
		root = root,
		p0 = d.p,
		v0 = d.v,
		g = d.g or 0,
		t0 = d.t,
		pos = d.p,
		vel = d.v,
		guided = w.motion == "Homing" or w.motion == "Cruise",
		correction = Vector3.zero,
		emitters = emitters,
		loop = nil,
		whistled = false,
		target = d.tp,
		bomblet = d.b == true,
	}
	place(v, d.p, d.v)
	model.Parent = Fx.folder()
	active[d.id] = v
	-- звук выстрела (пулемёт не повторяет звук на каждую пулю)
	local launch = w.launchSound
	if launch and not d.b then
		local key = launch .. tostring(math.floor(d.p.X)) .. tostring(math.floor(d.p.Z))
		local gap = (w.key == "Minigun") and 1.1 or (w.key == "Bullet" and 0.25 or 0)
		if os.clock() - (lastLaunchSound[key] or 0) >= gap then
			lastLaunchSound[key] = os.clock()
			if launch == "Siren" or launch == "Incoming" or launch == "Jet" then
				-- сирена и рёв играют в SiegeUI / Fx
				if launch == "Incoming" then
					SoundPlayer.play("Incoming", { position = d.tp or d.p })
				end
			else
				SoundPlayer.play(launch, { position = d.p, speed = rng:NextNumber(0.94, 1.06) })
			end
		end
	end
	if w.loopSound then
		v.loop = SoundPlayer.play(w.loopSound, { parent = root, loop = true })
	end
end

local function step(dt: number)
	local now = workspace:GetServerTimeNow()
	for id, v in active do
		if v.guided then
			v.pos += v.vel * dt
			-- плавно гасим поправку от сервера
			local c = v.correction * math.min(1, dt * 8)
			v.pos += c
			v.correction -= c
		else
			local t = math.max(0, now - v.t0)
			v.pos = Weapons.ballistic(v.p0, v.v0, v.g, t)
			v.vel = v.v0 + Vector3.new(0, -v.g * t, 0)
			if v.w.motion == "Parachute" then
				v.pos += Vector3.new(math.sin(t * 0.7) * 2, 0, math.cos(t * 0.5) * 2)
			end
		end
		place(v, v.pos, v.vel)
		-- свист падающей мины / бомбы
		if not v.whistled and (v.w.visual == "Shell" or v.w.visual == "Bomb" or v.bomblet) and v.vel.Y < 0 and v.target then
			local h = v.pos.Y - v.target.Y
			if h > 0 and h / math.max(1, -v.vel.Y) < 1.6 then
				v.whistled = true
				if not v.bomblet or rng:NextNumber() < 0.25 then
					SoundPlayer.play("ShellWhistle", { parent = v.root, speed = rng:NextNumber(0.9, 1.15) })
				end
			end
		end
		if now - v.t0 > 30 then
			remove(id)
		end
	end
end

local function onSync(batch)
	for _, e in batch do
		local v = active[e[1]]
		if v then
			v.correction = e[2] - v.pos
			v.vel = e[3]
		end
	end
end

local function fxSize(key: string): string
	local w = Weapons.ByKey[key]
	return w and w.fx or "Medium"
end

local function onDetonate(d)
	local v = d.id and active[d.id]
	if d.id then
		remove(d.id)
	end
	if d.silent then
		return
	end
	local key = d.w
	if key == "ClusterOpen" then
		Fx.explosion("Small", d.p, 3, { air = true, shake = 0.2 })
		return
	end
	if key == "Bomblet" then
		Fx.explosion("Small", d.p, 6, { water = d.water })
		return
	end
	if key == "TNT" then
		Fx.explosion("Medium", d.p, 12, {})
		return
	end
	local w = Weapons.ByKey[key]
	if not w then
		return
	end
	if w.fx == "Nuke" then
		if d.aa then
			Fx.explosion("Large", d.p, 20, { air = true })
		else
			Fx.nuke(d.p)
		end
		return
	end
	local size = fxSize(key)
	local R = w.radius
	if d.aa then
		size = "Small"
		R = math.max(4, R * 0.5)
	end
	Fx.explosion(size, d.p, R, { water = d.water, air = d.air or d.aa, shake = w.shake })
	local _ = v
end

function Projectiles.init()
	Net.event("ProjectileSpawn").OnClientEvent:Connect(onSpawn)
	Net.unreliable("ProjectileSync").OnClientEvent:Connect(onSync)
	Net.event("Detonate").OnClientEvent:Connect(onDetonate)
	Net.event("Impact").OnClientEvent:Connect(function(d)
		if d.id then
			remove(d.id)
		end
		Fx.impact(d.p, d.n, d.water, d.shield)
	end)
	Net.event("Warning").OnClientEvent:Connect(function(d)
		Fx.marker(d.p, d.r, d.t, d.kind == "nuke")
	end)
	Net.event("AAShot").OnClientEvent:Connect(function(d)
		Fx.aaShot(d.from, d.to)
	end)
	Net.event("ShieldState").OnClientEvent:Connect(Fx.shield)
	Net.event("BlocksBroken").OnClientEvent:Connect(Fx.blocksBroken)
	Net.event("Bomber").OnClientEvent:Connect(Fx.bomber)
	Net.event("LaserState").OnClientEvent:Connect(Fx.laserState)
	Net.unreliable("LaserTick").OnClientEvent:Connect(Fx.laserTick)
	RunService.RenderStepped:Connect(step)
	-- пули пролетают рядом — свист
	local player = Players.LocalPlayer
	task.spawn(function()
		while true do
			task.wait(0.1)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				for _, v in active do
					if v.w.visual == "Tracer" and not v.whistled and (v.pos - root.Position).Magnitude < 12 then
						v.whistled = true
						if rng:NextNumber() < 0.35 then
							SoundPlayer.play("BulletWhiz", { position = v.pos, speed = rng:NextNumber(0.9, 1.2) })
						end
					end
				end
			end
		end
	end)
	local _ = TweenService
end

return Projectiles
