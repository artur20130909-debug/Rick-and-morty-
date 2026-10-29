-- Набор инструментов для приёмов: начало/конец приёма, ожидание с проверкой прерывания,
-- рывки, хитбоксы, снаряды, захваты, эффекты.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Fighters = require(script.Parent.Fighters)
local Combat = require(script.Parent.Combat)
local Hitbox = require(script.Parent.Hitbox)
local Ragdoll = require(script.Parent.Ragdoll)
local Net = require(script.Parent.Net)

local Kit = {}
Kit.Config = Config
Kit.Util = Util
Kit.Fighters = Fighters
Kit.Combat = Combat
Kit.Hitbox = Hitbox
Kit.Ragdoll = Ragdoll
Kit.Net = Net
Kit.MapService = nil -- ставит Main

function Kit.now() return Util.now() end

---------------------------------------------------------------- жизнь приёма
function Kit.start(f, moveId, busyTime, speed, canJump)
	f.moveToken = f.moveToken + 1
	f.moveId = moveId
	Fighters.busy(f, busyTime or 0.5, speed, canJump)
	return f.moveToken
end

function Kit.valid(f, tok)
	return Fighters.alive(f) and f.moveToken == tok and not f.ragdolled
end

-- подождать; false — приём прерван (боец оглушён, умер, начал другое)
function Kit.wait(f, tok, t)
	if t and t > 0 then task.wait(t) end
	return Kit.valid(f, tok)
end

function Kit.finish(f, tok)
	if f.moveToken == tok then
		f.moveId = nil
		f.counter = nil
		Fighters.clearBusy(f)
	end
end

-- окно повторного нажатия той же клавиши (Резонанс, выход из тени); игроку — подсказка на панели
function Kit.recast(f, slot, fromT, untilT, cb, miss)
	f.recast = { slot = slot, fromT = fromT, untilT = untilT, cb = cb, miss = miss }
	if f.player then Net.to(f.player, "Recast", { slot = slot, from = fromT, to = untilT }) end
end

-- продлить «занятость» приёма
function Kit.busy(f, t, speed, canJump)
	Fighters.busy(f, t, speed, canJump)
end

-- суперброня: удары не прерывают приём (урон проходит)
function Kit.armor(f, t)
	f.armorEnd = math.max(f.armorEnd, Util.now() + t)
end

function Kit.iframes(f, t)
	f.iframesEnd = math.max(f.iframesEnd, Util.now() + t)
end

-- удалить вместе с прерыванием приёма
function Kit.track(f, inst)
	table.insert(f.cleanup, inst)
	return inst
end

---------------------------------------------------------------- эффекты
function Kit.anim(f, name, speed)
	Net.fx("Anim", { m = f.model, a = name, s = speed })
end

function Kit.stopAnim(f)
	Net.fx("AnimStop", { m = f.model })
end

function Kit.fx(name, data)
	Net.fx(name, data)
end

function Kit.shake(pos, mag, radius)
	Net.fx("Shake", { p = pos, m = mag or 1, r = radius or 60 })
end

function Kit.sound(name, pos, parent)
	Net.fx("Sound", { n = name, p = pos, m = parent })
end

---------------------------------------------------------------- направление и цели
local function finite(v)
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e6
end

-- данные прицела от клиента: { dir = Vector3, pos = Vector3 }
function Kit.cleanAim(aim)
	local out = {}
	if type(aim) == "table" then
		if finite(aim.dir) and aim.dir.Magnitude > 0.01 then out.dir = aim.dir.Unit end
		if finite(aim.pos) then out.pos = aim.pos end
	end
	return out
end

function Kit.dir(f, aim)
	local look = f.root.CFrame.LookVector
	if aim and aim.dir then return Util.flat(aim.dir, Util.flat(look)) end
	return Util.flat(look)
end

function Kit.face(f, dir)
	local p = f.root.Position
	local d = Util.flat(dir, Util.flat(f.root.CFrame.LookVector))
	f.root.CFrame = CFrame.lookAt(p, p + d)
end

function Kit.faceTarget(f, target)
	if target and target.root then Kit.face(f, target.root.Position - f.root.Position) end
end

-- враг в конусе прицела (мягкое наведение)
function Kit.target(f, aim, range, cosAngle)
	return Hitbox.cone(f.root.Position, Kit.dir(f, aim), range, cosAngle or 0.55, { [f] = true })
end

-- точка на земле для приёмов «по месту»: курсор (если близко), иначе враг, иначе впереди
function Kit.aimPoint(f, aim, maxDist, fallbackDist)
	local origin = f.root.Position
	local t = Kit.target(f, aim, maxDist, 0.5)
	if t then return Util.ground(t.root.Position), t end
	if aim and aim.pos then
		local d = aim.pos - origin
		local flat = Vector3.new(d.X, 0, d.Z)
		if flat.Magnitude <= maxDist and flat.Magnitude > 2 then return Util.ground(aim.pos), nil end
		if flat.Magnitude > maxDist then
			return Util.ground(origin + flat.Unit * maxDist), nil
		end
	end
	return Util.ground(origin + Kit.dir(f, aim) * (fallbackDist or 20)), nil
end

-- от атакующего к цели, с подбросом
function Kit.knock(f, target, force, up)
	local d = Combat.away(f, target)
	return d * (force or 50) + Vector3.new(0, up or 0, 0)
end

---------------------------------------------------------------- попадания
-- info может быть таблицей или функцией(target) -> таблица
local function infoFor(info, target)
	if type(info) == "function" then return info(target) end
	return info
end

function Kit.hitList(f, list, info, hitSet)
	local res = {}
	for _, t in ipairs(list) do
		if t ~= f and not (hitSet and hitSet[t]) then
			if hitSet then hitSet[t] = true end
			local r = Combat.hit(f, t, infoFor(info, t))
			res[#res + 1] = { f = t, r = r }
		end
	end
	return res
end

-- ящик перед бойцом: ширина, высота, длина; forward — смещение центра вперёд
function Kit.boxFront(f, dir, width, height, length, info, hitSet, forward)
	local pos = f.root.Position + dir * (forward or length / 2)
	local cf = CFrame.lookAt(pos, pos + dir)
	local list = Hitbox.box(cf, Vector3.new(width, height, length), { [f] = true })
	return Kit.hitList(f, list, info, hitSet)
end

function Kit.radiusHit(f, pos, r, info, hitSet)
	local list = Hitbox.radius(pos, r, { [f] = true })
	return Kit.hitList(f, list, info, hitSet)
end

function Kit.segmentHit(f, a, b, width, info, hitSet)
	local list = Hitbox.segment(a, b, width, { [f] = true })
	return Kit.hitList(f, list, info, hitSet)
end

function Kit.anyHit(res)
	for _, e in ipairs(res) do
		if e.r == "hit" or e.r == "killed" then return true end
	end
	return false
end

function Kit.firstHit(res)
	for _, e in ipairs(res) do
		if e.r == "hit" or e.r == "killed" then return e.f end
	end
	return nil
end

---------------------------------------------------------------- движение
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Include

local function setVel(f, vel)
	local root = f.root
	local att = root:FindFirstChild("MoveAtt")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "MoveAtt"
		att.Parent = root
	end
	local lv = root:FindFirstChild("MoveVel")
	if not lv then
		lv = Instance.new("LinearVelocity")
		lv.Name = "MoveVel"
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.MaxForce = 1e7
		lv.Parent = root
		Kit.track(f, lv)
	end
	lv.VectorVelocity = vel
	return lv
end
Kit.setVel = setVel

function Kit.stopVel(f)
	local lv = f.root:FindFirstChild("MoveVel")
	if lv then lv:Destroy() end
end

-- рывок: dir * speed на time секунд. opts:
--   contact = радиус касания врага (вернёт первого задетого и остановится, если stop ~= false)
--   onContact = function(target) (для пролёта сквозь), up = вертикальная скорость
-- Возвращает цель (если коснулись), иначе nil.
function Kit.dash(f, tok, dir, speed, time, opts)
	opts = opts or {}
	local d = dir.Unit
	local vel = d * speed + Vector3.new(0, opts.up or 0, 0)
	setVel(f, vel)
	local t0 = os.clock()
	local hitTarget
	local touched = {}
	local map = workspace:FindFirstChild("Map")
	while os.clock() - t0 < time do
		local dt = RunService.Heartbeat:Wait()
		if not Kit.valid(f, tok) then
			Kit.stopVel(f)
			return nil
		end
		-- стена впереди — стоп
		if map then
			wallParams.FilterDescendantsInstances = { map }
			local r = workspace:Raycast(f.root.Position, d * (speed * dt + 2.2), wallParams)
			if r and r.Normal.Y < 0.5 then break end
		end
		if opts.contact then
			local list = Hitbox.radius(f.root.Position + d * 1.5, opts.contact, { [f] = true })
			for _, t in ipairs(list) do
				if not touched[t] then
					touched[t] = true
					if opts.onContact then opts.onContact(t) end
					if opts.stop ~= false then
						hitTarget = t
						break
					end
				end
			end
			if hitTarget then break end
		end
	end
	Kit.stopVel(f)
	f.root.AssemblyLinearVelocity = Vector3.new(0, f.root.AssemblyLinearVelocity.Y, 0)
	return hitTarget
end

-- мгновенно переместить
function Kit.teleport(f, pos, lookDir)
	local d = Util.flat(lookDir or f.root.CFrame.LookVector)
	f.root.CFrame = CFrame.lookAt(pos, pos + d)
	f.root.AssemblyLinearVelocity = Vector3.zero
end

-- безопасная точка рядом (не в стене)
function Kit.safePoint(from, to)
	local map = workspace:FindFirstChild("Map")
	if not map then return to end
	wallParams.FilterDescendantsInstances = { map }
	local d = to - from
	if d.Magnitude < 0.1 then return to end
	local r = workspace:Raycast(from, d, wallParams)
	if r then return r.Position - d.Unit * 2.5 end
	return to
end

-- держать цель перед собой (захват) на время t; offset — CFrame относительно атакующего
function Kit.hold(f, target, offset, t, tok)
	target.rootEnd = math.max(target.rootEnd, Util.now() + t)
	-- игрока на время захвата двигает сервер (иначе его клиент «перетягивает» позицию)
	local owned = target.player ~= nil
	if owned then pcall(function() target.root:SetNetworkOwner(nil) end) end
	local t0 = os.clock()
	while os.clock() - t0 < t do
		RunService.Heartbeat:Wait()
		if tok and not Kit.valid(f, tok) then break end
		if not Fighters.alive(target) then break end
		local cf = f.root.CFrame * offset
		target.root.CFrame = cf
		target.root.AssemblyLinearVelocity = Vector3.zero
	end
	target.rootEnd = 0
	if owned and target.root.Parent and target.player.Parent then
		pcall(function() target.root:SetNetworkOwner(target.player) end)
	end
end

---------------------------------------------------------------- снаряды
-- Снаряд летит по прямой; на сервере — проверка попаданий, у клиентов — картинка.
-- opts: from, dir, speed, range, radius, pierce, kind, color, size, onHit(target, pos) -> true = продолжить,
--       onEnd(pos, hitWall), ghost (сквозь стены), info (если нет onHit — обычный удар)
local projectiles = {}
local projId = 0
function Kit.projectile(f, opts)
	projId = projId + 1
	local p = {
		id = projId, f = f, pos = opts.from, dir = opts.dir.Unit, speed = opts.speed or 80, range = opts.range or 80,
		radius = opts.radius or 2, pierce = opts.pierce or 1, opts = opts, travelled = 0, hit = {}, dead = false,
	}
	p.hit[f] = true
	projectiles[#projectiles + 1] = p
	Net.fx("Proj", { id = p.id, k = opts.kind or "orb", p = p.pos, v = p.dir * p.speed, r = p.range, t0 = Util.now(),
		m = f.model, c = opts.color, s = opts.size or p.radius, x = opts.extra })
	return p
end

local function endProj(p, pos, hitWall)
	if p.dead then return end
	p.dead = true
	Net.fx("ProjEnd", { id = p.id, p = pos, w = hitWall })
	if p.opts.onEnd then
		task.spawn(function()
			local ok, err = pcall(p.opts.onEnd, pos, hitWall)
			if not ok then warn("[Kit] projectile onEnd: " .. tostring(err)) end
		end)
	end
end

function Kit.endProjectile(p, pos)
	endProj(p, pos or p.pos, false)
end

local projParams = RaycastParams.new()
projParams.FilterType = Enum.RaycastFilterType.Include
RunService.Heartbeat:Connect(function(dt)
	if #projectiles == 0 then return end
	local map = workspace:FindFirstChild("Map")
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		if p.dead then
			table.remove(projectiles, i)
		else
			local step = math.min(p.speed * dt, p.range - p.travelled)
			local a = p.pos
			local b = a + p.dir * step
			local wallHit
			if map and not p.opts.ghost then
				projParams.FilterDescendantsInstances = { map }
				local r = workspace:Raycast(a, b - a, projParams)
				if r then
					b = r.Position
					wallHit = true
				end
			end
			local list = Hitbox.segment(a, b, p.radius * 2, p.hit)
			for _, t in ipairs(list) do
				if not p.dead then
					p.hit[t] = true
					local cont = false
					if p.opts.onHit then
						local ok, res = pcall(p.opts.onHit, t, t.root.Position)
						if not ok then warn("[Kit] projectile onHit: " .. tostring(res)) end
						cont = ok and res == true
					elseif p.opts.info then
						Combat.hit(p.f, t, infoFor(p.opts.info, t))
					end
					p.pierce = p.pierce - 1
					if not cont and p.pierce <= 0 then
						endProj(p, t.root.Position, false)
					end
				end
			end
			if not p.dead then
				p.pos = b
				p.travelled = p.travelled + (b - a).Magnitude
				if wallHit then
					endProj(p, b, true)
				elseif p.travelled >= p.range - 1e-3 then
					endProj(p, b, false)
				end
			end
		end
	end
end)

---------------------------------------------------------------- карта и разное
function Kit.breakAt(pos, radius, force)
	if Kit.MapService then Kit.MapService.breakAt(pos, radius, force) end
end

function Kit.ground(pos, depth)
	return (Util.ground(pos, depth))
end

-- через t секунд выполнить fn (ошибки — в Output, без падения сервера)
function Kit.after(t, fn)
	task.delay(t, function()
		local ok, err = pcall(fn)
		if not ok then warn("[Kit] " .. tostring(err)) end
	end)
end

-- серверная деталь-«призыв» (видна всем, двигается сервером)
function Kit.part(props, f)
	local p = Util.part(props, workspace:FindFirstChild("FX") or workspace)
	if f then Kit.track(f, p) end
	return p
end

function Kit.debris(inst, t)
	Debris:AddItem(inst, t)
end

return Kit
