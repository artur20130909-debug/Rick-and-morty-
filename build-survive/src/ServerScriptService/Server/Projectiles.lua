-- Снаряды на сервере: полёт, наведение, попадания, перехват ПВО, щиты.
-- Сервер считает «честную» траекторию лучами, а клиенты рисуют красивую картинку сами
-- (получают старт снаряда и поправки для управляемых ракет).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Blocks = require(Shared.Blocks)
local Weapons = require(Shared.Weapons)
local Net = require(Shared.Net)

local Plots = require(script.Parent.Plots)
local Specials = require(script.Parent.Specials)
local Damage = require(script.Parent.Damage)

local Projectiles = {}

type Plot = Plots.Plot

export type Proj = {
	id: number,
	w: any,
	plot: Plot,
	pos: Vector3,
	vel: Vector3,
	g: number,
	age: number,
	lifetime: number,
	target: Player?,
	targetPos: Vector3,
	mul: number,
	rolled: { [BasePart]: boolean },
	splitY: number?,
	burstY: number?,
	bomblet: boolean?,
	onDetonate: ((Vector3) -> ())?,
}

local active: { [number]: Proj } = {}
local count = 0
local nextId = 0
local syncTimer = 0
local rng = Random.new()

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = false

function Projectiles.setExclude(list: { Instance })
	params.FilterDescendantsInstances = list
end

function Projectiles.count(): number
	return count
end

local function remove(p: Proj)
	if active[p.id] then
		active[p.id] = nil
		count -= 1
	end
end

-- Создать снаряд. opts: target, targetPos, mul, lifetime, splitY, burstY, bomblet
function Projectiles.spawn(plot: Plot, w, pos: Vector3, vel: Vector3, opts: any): Proj?
	if count >= Config.Siege.MaxProjectiles then
		return nil
	end
	nextId += 1
	local p: Proj = {
		id = nextId,
		w = w,
		plot = plot,
		pos = pos,
		vel = vel,
		g = opts.g or w.gravity or 0,
		age = 0,
		lifetime = opts.lifetime or w.lifetime or 16,
		target = opts.target,
		targetPos = opts.targetPos or pos,
		mul = opts.mul or 1,
		rolled = {},
		splitY = opts.splitY,
		burstY = opts.burstY,
		bomblet = opts.bomblet,
		onDetonate = opts.onDetonate,
	}
	active[p.id] = p
	count += 1
	local target = p.target
	Net.event("ProjectileSpawn"):FireAllClients({
		id = p.id,
		w = w.key,
		p = pos,
		v = vel,
		g = p.g,
		t = workspace:GetServerTimeNow(),
		b = p.bomblet,
		tp = p.targetPos,
		u = target and target.UserId or nil,
	})
	return p
end

-- Повернуть вектор скорости к нужному направлению не больше чем на maxAngle радиан
local function turnToward(v: Vector3, desired: Vector3, maxAngle: number): Vector3
	if v.Magnitude < 1e-3 then
		return desired
	end
	local a, b = v.Unit, desired.Unit
	local ang = math.acos(math.clamp(a:Dot(b), -1, 1))
	if ang <= maxAngle or ang < 1e-4 then
		return desired
	end
	local axis = a:Cross(b)
	if axis.Magnitude < 1e-5 then
		axis = Vector3.yAxis:Cross(a)
		if axis.Magnitude < 1e-5 then
			axis = Vector3.xAxis
		end
	end
	return CFrame.fromAxisAngle(axis.Unit, maxAngle):VectorToWorldSpace(a) * desired.Magnitude
end

-- Пересечение отрезка o + d*t (t от 0 до 1) со сферой
local function segmentSphere(o: Vector3, d: Vector3, c: Vector3, r: number): number?
	local m = o - c
	local a = d:Dot(d)
	local b = 2 * m:Dot(d)
	local cc = m:Dot(m) - r * r
	local disc = b * b - 4 * a * cc
	if disc < 0 or a < 1e-8 then
		return nil
	end
	local t = (-b - math.sqrt(disc)) / (2 * a)
	if t >= 0 and t <= 1 then
		return t
	end
	return nil
end

local function kindOf(w): string
	return w.key == "Nuke" and "nuke" or "explosion"
end

local function detonate(p: Proj, pos: Vector3, normal: Vector3?, info: any)
	remove(p)
	local w = p.w
	info = info or {}
	if w.radius > 0 then
		Net.event("Detonate"):FireAllClients({
			id = p.id, w = p.bomblet and "Bomblet" or w.key, p = pos, n = normal,
			water = info.water, aa = info.intercepted, air = info.air,
		})
		local mul = p.mul * (info.intercepted and 0.15 or 1)
		Damage.explode(p.plot, pos, {
			radius = w.radius * (info.intercepted and 0.6 or 1),
			blockDamage = w.blockDamage,
			playerDamage = w.playerDamage,
			kind = kindOf(w),
			mul = mul,
		})
		if p.onDetonate then
			task.spawn(p.onDetonate, pos)
		end
	else
		Net.event("Impact"):FireAllClients({ id = p.id, p = pos, n = normal, water = info.water, shield = info.shield })
		if info.inst then
			Damage.bullet(p.plot, info.inst, pos, w.blockDamage * p.mul, w.playerDamage * p.mul)
		end
	end
end

local function fizzle(p: Proj)
	remove(p)
	Net.event("Detonate"):FireAllClients({ id = p.id, silent = true })
end

-- Кассетная бомба раскрывается
local function split(p: Proj, pos: Vector3)
	remove(p)
	Net.event("Detonate"):FireAllClients({ id = p.id, w = "ClusterOpen", p = pos })
	local w = p.w
	local g = p.g
	local vy = p.vel.Y
	local targetY = p.targetPos.Y
	local fall = math.max(0.5, (vy + math.sqrt(math.max(0, vy * vy + 2 * g * (pos.Y - targetY)))) / g)
	for i = 1, (w.bomblets or 10) do
		local a = (i / w.bomblets) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = rng:NextNumber(3, w.splitSpread or 20)
		local landing = p.targetPos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local flat = (landing - pos) * Vector3.new(1, 0, 1)
		local vel = Vector3.new(flat.X / fall, vy * rng:NextNumber(0.6, 1), flat.Z / fall)
		Projectiles.spawn(p.plot, w, pos, vel, { g = g, targetPos = landing, mul = p.mul, bomblet = true, lifetime = 8 })
	end
end

local function stepOne(p: Proj, dt: number)
	local w = p.w
	p.age += dt
	if p.age > p.lifetime or p.pos.Y < -60 then
		fizzle(p)
		return
	end
	local motion = w.motion
	if p.target and (motion == "Homing" or motion == "Cruise") then
		local char = p.target.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			p.targetPos = root.Position
		end
	end
	if motion == "Homing" then
		if p.age > 0.7 then
			p.vel = turnToward(p.vel, (p.targetPos - p.pos).Unit * w.speed, w.turnRate * dt)
		end
	elseif motion == "Cruise" then
		local flat = Vector3.new(p.targetPos.X - p.pos.X, 0, p.targetPos.Z - p.pos.Z)
		if flat.Magnitude > 70 then
			local cruiseY = p.targetPos.Y + (w.cruiseHeight or 18)
			local desired = flat.Unit * w.speed + Vector3.new(0, math.clamp((cruiseY - p.pos.Y) * 3, -80, 80), 0)
			p.vel = turnToward(p.vel, desired.Unit * w.speed, 2.2 * dt)
		else
			p.vel = turnToward(p.vel, (p.targetPos - p.pos).Unit * w.speed, 5 * dt)
		end
	elseif p.g > 0 then
		p.vel += Vector3.new(0, -p.g * dt, 0)
	end
	local newPos = p.pos + p.vel * dt

	if p.burstY and newPos.Y <= p.burstY then
		detonate(p, newPos, nil, { air = true })
		return
	end
	if p.splitY and newPos.Y <= p.splitY then
		split(p, newPos)
		return
	end

	local seg = newPos - p.pos
	-- щиты
	local hitT = 2
	local shield = nil
	for _, s in Specials.activeShields(p.plot) do
		if (p.pos - s.center).Magnitude > s.radius then
			local t = segmentSphere(p.pos, seg, s.center, s.radius)
			if t and t < hitT then
				hitT = t
				shield = s
			end
		end
	end
	local result = workspace:Raycast(p.pos, seg, params)
	if result then
		local t = (result.Position - p.pos).Magnitude / math.max(seg.Magnitude, 1e-4)
		if not shield or t < hitT then
			local water = result.Material == Enum.Material.Water
			detonate(p, result.Position, result.Normal, { inst = result.Instance, water = water })
			return
		end
	end
	if shield then
		local at = p.pos + seg * hitT
		local normal = (at - shield.center).Unit
		if w.radius > 0 then
			detonate(p, at + normal * 0.5, normal, { shield = true })
		else
			Specials.hitShield(shield, w.blockDamage * p.mul, at)
			detonate(p, at, normal, { shield = true })
		end
		return
	end

	-- турели ПВО
	if w.aa > 0 and not p.bomblet then
		for _, turret in Specials.aaTurrets(p.plot) do
			if not p.rolled[turret] and (turret.Position - newPos).Magnitude < Blocks.AARange and Specials.aaReady(turret) then
				p.rolled[turret] = true
				Specials.aaFired(turret)
				Net.event("AAShot"):FireAllClients({ from = turret.CFrame:PointToWorldSpace(Vector3.new(0, 3.3, -1.9)), to = newPos })
				if rng:NextNumber() < w.aa then
					detonate(p, newPos, nil, { intercepted = true, air = true })
					return
				end
				break
			end
		end
	elseif w.aa > 0 and p.bomblet and rng:NextNumber() < 0.02 then
		-- кассетные бомбочки тоже иногда сбивают
		for _, turret in Specials.aaTurrets(p.plot) do
			if (turret.Position - newPos).Magnitude < Blocks.AARange and Specials.aaReady(turret) then
				Specials.aaFired(turret)
				Net.event("AAShot"):FireAllClients({ from = turret.CFrame:PointToWorldSpace(Vector3.new(0, 3.3, -1.9)), to = newPos })
				detonate(p, newPos, nil, { intercepted = true, air = true })
				return
			end
		end
	end
	p.pos = newPos
end

function Projectiles.step(dt: number)
	-- копия списка: во время шага появляются новые снаряды (кассетные бомбы)
	local list = {}
	for _, p in active do
		table.insert(list, p)
	end
	for _, p in list do
		-- быстрые снаряды считаем короткими шагами, чтобы не пролетали сквозь тонкие стены
		local speed = p.vel.Magnitude
		local steps = math.clamp(math.ceil(speed * dt / 12), 1, 6)
		local sub = dt / steps
		for _ = 1, steps do
			if not active[p.id] then
				break
			end
			stepOne(p, sub)
		end
	end
	syncTimer += dt
	if syncTimer >= 0.12 then
		syncTimer = 0
		local batch = {}
		for _, p in active do
			local m = p.w.motion
			if m == "Homing" or m == "Cruise" then
				table.insert(batch, { p.id, p.pos, p.vel })
				if #batch >= 16 then
					Net.unreliable("ProjectileSync"):FireAllClients(batch)
					batch = {}
				end
			end
		end
		if #batch > 0 then
			Net.unreliable("ProjectileSync"):FireAllClients(batch)
		end
	end
end

-- Убрать все снаряды участка (конец осады)
function Projectiles.clearPlot(plot: Plot)
	for _, p in active do
		if p.plot == plot then
			fizzle(p)
		end
	end
end

Projectiles.Weapons = Weapons

return Projectiles
