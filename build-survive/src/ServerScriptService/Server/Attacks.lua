-- Как стреляет каждое оружие: откуда, куда целится, сколько снарядов.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Weapons = require(Shared.Weapons)
local Net = require(Shared.Net)

local Plots = require(script.Parent.Plots)
local Projectiles = require(script.Parent.Projectiles)
local Damage = require(script.Parent.Damage)
local Data = require(script.Parent.Data)

local Attacks = {}

type Plot = Plots.Plot

-- Контекст атаки (его создаёт Siege)
export type Ctx = {
	plot: Plot,
	player: Player?,
	mul: number,
	ended: boolean,
	nukes: number,
}

local rng = Random.new()
local laserId = 0

local function rand(t: { Vector3 }): Vector3
	return t[rng:NextInteger(1, #t)]
end

local function spreadDir(dir: Vector3, deg: number): Vector3
	if deg <= 0 then
		return dir.Unit
	end
	local cf = CFrame.lookAt(Vector3.zero, dir)
		* CFrame.Angles(0, 0, rng:NextNumber(0, math.pi * 2))
		* CFrame.Angles(rng:NextNumber(0, math.rad(deg)), 0, 0)
	return cf.LookVector
end

local function ownerRoot(ctx: Ctx): BasePart?
	local _, _, root = Plots.ownerCharacter(ctx.plot)
	return root
end

-- Выбрать цель: игрок (чаще) или случайный блок постройки
local function pickTarget(ctx: Ctx, aim: Vector3?, playerChance: number?): (Vector3, Player?)
	if aim then
		return aim, nil
	end
	local root = ownerRoot(ctx)
	if root and rng:NextNumber() < (playerChance or 0.65) then
		return root.Position, ctx.player
	end
	local blocks = ctx.plot.blocks:GetChildren()
	if #blocks > 0 then
		local b = blocks[rng:NextInteger(1, #blocks)] :: BasePart
		return b.Position, nil
	end
	if root then
		return root.Position, ctx.player
	end
	return ctx.plot.cf * Vector3.new(rng:NextNumber(-24, 24), 2, rng:NextNumber(-24, 24)), nil
end

-- Упреждение для быстрых снарядов
local function lead(target: Vector3, targetPlayer: Player?, from: Vector3, speed: number): Vector3
	if not targetPlayer or speed <= 0 then
		return target
	end
	local char = targetPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return target
	end
	local t = (target - from).Magnitude / speed
	return target + root.AssemblyLinearVelocity * Vector3.new(1, 0, 1) * t * 0.7
end

local function nearestTower(ctx: Ctx, target: Vector3): Vector3
	-- чаще стреляет ближайшая вышка, иногда — случайная
	if rng:NextNumber() < 0.35 then
		return rand(ctx.plot.towers)
	end
	local best, bestD = ctx.plot.towers[1], math.huge
	for _, t in ctx.plot.towers do
		local d = (t - target).Magnitude
		if d < bestD then
			best, bestD = t, d
		end
	end
	return best
end

local function warnMarker(ctx: Ctx, kind: string, pos: Vector3, radius: number, eta: number)
	Net.event("Warning"):FireAllClients({ kind = kind, p = pos, r = radius, t = eta, plot = ctx.plot.index })
end

-- ОРУЖИЕ --------------------------------------------------------------------------
local fire = {}

local function bulletBurst(ctx: Ctx, w, aim: Vector3?)
	local target, tp = pickTarget(ctx, aim, 0.8)
	local muzzle = nearestTower(ctx, target)
	local n = w.burst or 1
	for _ = 1, n do
		if ctx.ended then
			return
		end
		local root = tp and ownerRoot(ctx)
		local t = (root and not aim) and root.Position or target
		local aimAt = lead(t, tp, muzzle, w.speed)
		Projectiles.spawn(ctx.plot, w, muzzle, spreadDir(aimAt - muzzle, w.spread or 0) * w.speed, { mul = ctx.mul, lifetime = 3 })
		if n > 1 then
			task.wait(w.burstGap or 0.1)
		end
	end
end

fire.Bullet = bulletBurst
fire.Minigun = bulletBurst

function fire.Shotgun(ctx: Ctx, w, aim: Vector3?)
	local target, tp = pickTarget(ctx, aim, 0.85)
	local muzzle = nearestTower(ctx, target)
	local aimAt = lead(target, tp, muzzle, w.speed)
	for _ = 1, (w.pellets or 8) do
		Projectiles.spawn(ctx.plot, w, muzzle, spreadDir(aimAt - muzzle, w.spread) * w.speed * rng:NextNumber(0.9, 1.1), { mul = ctx.mul, lifetime = 3 })
	end
end

function fire.Grenade(ctx: Ctx, w, aim: Vector3?)
	local target = pickTarget(ctx, aim, 0.7)
	local muzzle = nearestTower(ctx, target)
	target += Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
	local t = math.clamp((target - muzzle).Magnitude / 55, 1.2, 2.6)
	Projectiles.spawn(ctx.plot, w, muzzle, Weapons.solveBallistic(muzzle, target, w.gravity, t), { mul = ctx.mul, targetPos = target })
end

function fire.Mortar(ctx: Ctx, w, aim: Vector3?)
	local target = pickTarget(ctx, aim, 0.6)
	target += Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
	local origin = rand(ctx.plot.layout.mortars)
	local t = w.flightTime
	warnMarker(ctx, "marker", target, w.radius, t)
	Projectiles.spawn(ctx.plot, w, origin, Weapons.solveBallistic(origin, target, w.gravity, t), { mul = ctx.mul, targetPos = target, lifetime = t + 3 })
end

function fire.RPG(ctx: Ctx, w, aim: Vector3?)
	local target, tp = pickTarget(ctx, aim, 0.6)
	local origin = rand(ctx.plot.layout.rails)
	local aimAt = lead(target, tp, origin, w.speed)
	Projectiles.spawn(ctx.plot, w, origin, spreadDir(aimAt - origin, 0.6) * w.speed, { mul = ctx.mul, targetPos = aimAt, lifetime = 8 })
end

function fire.Homing(ctx: Ctx, w, aim: Vector3?)
	local target, tp = pickTarget(ctx, aim, 0.9)
	local origin = rand(ctx.plot.layout.silos)
	local away = (target - origin) * Vector3.new(1, 0, 1)
	local vel = Vector3.new(0, w.speed * 0.9, 0) + (away.Magnitude > 0 and away.Unit * w.speed * 0.25 or Vector3.zero)
	Projectiles.spawn(ctx.plot, w, origin, vel, { mul = ctx.mul, target = tp, targetPos = target })
end

function fire.Cruise(ctx: Ctx, w, aim: Vector3?)
	local target, tp = pickTarget(ctx, aim, 0.5)
	local origin = rand(ctx.plot.layout.rails)
	local flat = (target - origin) * Vector3.new(1, 0, 1)
	Projectiles.spawn(ctx.plot, w, origin, (flat.Unit + Vector3.new(0, 0.2, 0)).Unit * w.speed, { mul = ctx.mul, target = tp, targetPos = target })
end

function fire.Cluster(ctx: Ctx, w, aim: Vector3?)
	local target = pickTarget(ctx, aim, 0.5)
	local fortPos = ctx.plot.layout.fortCf.Position
	local dir = ((target - fortPos) * Vector3.new(1, 0, 1)).Unit
	local altitude = target.Y + 170
	local speed = 140
	local drop = (altitude - (target.Y + w.splitHeight))
	local fallTime = math.sqrt(2 * drop / w.gravity)
	local release = Vector3.new(target.X, altitude, target.Z) - dir * speed * fallTime
	local start = release - dir * 520
	local finish = release + dir * 760
	local releaseDelay = 520 / speed
	Net.event("Bomber"):FireAllClients({ s = start, e = finish, v = speed, t = workspace:GetServerTimeNow(), drop = releaseDelay })
	task.delay(releaseDelay, function()
		if ctx.ended then
			return
		end
		Projectiles.spawn(ctx.plot, w, release, dir * speed, {
			mul = ctx.mul, targetPos = target, splitY = target.Y + w.splitHeight, g = w.gravity, lifetime = 10,
		})
	end)
end

function fire.Ballistic(ctx: Ctx, w, aim: Vector3?)
	local target = pickTarget(ctx, aim, 0.6)
	target += Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
	local start = target + Vector3.new(rng:NextNumber(-40, 40), w.dropHeight, rng:NextNumber(-40, 40))
	local eta = (target - start).Magnitude / w.speed
	warnMarker(ctx, "marker", target, w.radius, eta)
	Projectiles.spawn(ctx.plot, w, start, (target - start).Unit * w.speed, { mul = ctx.mul, targetPos = target, lifetime = eta + 3 })
end

function fire.Nuke(ctx: Ctx, w, aim: Vector3?)
	local target = aim
	if not target then
		local root = ownerRoot(ctx)
		target = root and root.Position or ctx.plot.cf.Position
	end
	local floorY = ctx.plot.cf.Position.Y
	local ground = Vector3.new(target.X, floorY, target.Z)
	local start = ground + Vector3.new(0, w.dropHeight, 0)
	local eta = (w.dropHeight - w.burstHeight) / w.speed
	warnMarker(ctx, "nuke", ground, w.radius, eta)
	ctx.nukes += 1
	Projectiles.spawn(ctx.plot, w, start, Vector3.new(0, -w.speed, 0), {
		mul = ctx.mul,
		targetPos = ground,
		burstY = floorY + w.burstHeight,
		lifetime = eta + 5,
		onDetonate = function()
			-- если игрок пережил ядерный взрыв — это рекорд в статистику
			task.wait(2.5)
			local player = ctx.player
			local root = ownerRoot(ctx)
			if player and root and not ctx.ended then
				local profile = Data.get(player)
				if profile then
					profile.Stats.Nukes = (profile.Stats.Nukes or 0) + 1
				end
				Net.event("Notify"):FireClient(player, "☢ Ты пережил ядерный удар!", "success")
			end
		end,
	})
end

function fire.Laser(ctx: Ctx, w, aim: Vector3?)
	laserId += 1
	local id = laserId
	local plot = ctx.plot
	local function playerXZ(): Vector3?
		local root = ownerRoot(ctx)
		return root and Vector3.new(root.Position.X, 0, root.Position.Z)
	end
	local start = aim or playerXZ() or plot.cf.Position
	local pos = Vector3.new(start.X, 0, start.Z)
	local floorY = plot.cf.Position.Y
	Net.event("LaserState"):FireAllClients({ id = id, phase = "charge", p = Vector3.new(pos.X, floorY, pos.Z), t = w.chargeTime, r = w.beamRadius })
	local t = 0
	local dt = 0.1
	while t < w.chargeTime do
		if ctx.ended then
			Net.event("LaserState"):FireAllClients({ id = id, phase = "end" })
			return
		end
		if not aim then
			local p = playerXZ()
			if p then
				local d = p - pos
				local step = math.min(d.Magnitude, 22 * dt)
				if d.Magnitude > 0.01 then
					pos += d.Unit * step
				end
			end
		end
		Net.unreliable("LaserTick"):FireAllClients(id, pos.X, pos.Z, nil)
		task.wait(dt)
		t += dt
	end
	Net.event("LaserState"):FireAllClients({ id = id, phase = "fire", p = Vector3.new(pos.X, floorY, pos.Z), t = w.duration, r = w.beamRadius })
	t = 0
	while t < w.duration and not ctx.ended do
		if not aim then
			local p = playerXZ()
			if p then
				local d = p - pos
				local step = math.min(d.Magnitude, w.trackSpeed * dt)
				if d.Magnitude > 0.01 then
					pos += d.Unit * step
				end
			end
		end
		local hitY = Damage.laserTick(plot, pos.X, pos.Z, w.beamRadius, w.blockDamage, w.playerDamage, dt, ctx.mul)
		Net.unreliable("LaserTick"):FireAllClients(id, pos.X, pos.Z, hitY)
		task.wait(dt)
		t += dt
	end
	Net.event("LaserState"):FireAllClients({ id = id, phase = "end" })
end

-- Выстрелить оружием key. aim — точка (полигон), иначе цель выбирается сама.
function Attacks.fire(ctx: Ctx, key: string, aim: Vector3?)
	local w = Weapons.ByKey[key]
	local f = fire[key]
	if not w or not f then
		return
	end
	task.spawn(f, ctx, w, aim)
end

return Attacks
