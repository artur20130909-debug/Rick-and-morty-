-- ИИ заключённых (сервер): выбор на ночь, появление, навигация (PathfindingService), двери и окна,
-- зрение и слух, состояния enter → roam → chase → search → roam, проверка укрытий, удары, оглушение, урон.
-- Один цикл Heartbeat (~15 Гц) тикает всех заключённых в pcall: def.server.tick(inm, dt) или inm:hunt(dt).
--
-- API (§8): init, choose, spawn, despawnAll, damage, stun, nearest, info; дополнительно despawn(inm), list(match).
-- Модули Inmates/<Key>.lua пользуются методами inm (Inmate.*): goTo, stop, face, players, look, listen, canSee,
-- startChase, hunt, roam, chase, search, enter, tryAttack, kill, hurt, vault, teleport, setAnim, setState,
-- sound, fx, say, shakeNear, litAt, ceilingAt, floorAt, hideOf, pickHide, pickEntry, despawn …
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")
local RS = game:GetService("ReplicatedStorage")

local Rig = require(RS:WaitForChild("Shared"):WaitForChild("Rig"))

local InmateAI = {}
local ctx, HouseLogic, Sound
local modules, order = {}, {}
local loaded = false
local active = {}
local folder = nil
local losParams = nil
local tickId = 0
local roomCache = setmetatable({}, { __mode = "k" })
local warned = {}
local EMPTY = {}
local TICK = 1 / 15
local BODY_GROUP = "InmateBody"
local clock = os.clock

local function warnOnce(tag, err)
	local k = tag .. tostring(err)
	if warned[k] then return end
	warned[k] = true
	warn("[AA] InmateAI " .. tag .. ": " .. tostring(err))
end

local function fdist(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

---------------------------------------------------------------- модули заключённых
local function loadModules()
	if loaded then return end
	loaded = true
	local f = RS:FindFirstChild("Inmates")
	if not f then return end
	for _, ms in ipairs(f:GetChildren()) do
		if ms:IsA("ModuleScript") then
			local ok, def = pcall(require, ms)
			if ok and type(def) == "table" then
				def.key = def.key or ms.Name
				def.server = def.server or {}
				modules[def.key] = def
				if ms.Name ~= def.key then modules[ms.Name] = def end
				table.insert(order, def.key)
			else
				warnOnce("require " .. ms.Name, def)
			end
		end
	end
	table.sort(order)
end

function InmateAI.info(key)
	loadModules()
	return key and modules[key] or nil
end

---------------------------------------------------------------- лучи
local function updateLos()
	local list = { folder }
	local props = workspace:FindFirstChild("Props")
	if props then table.insert(list, props) end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(list, p.Character) end
	end
	losParams.FilterDescendantsInstances = list
end

-- луч, который проходит сквозь стекло и прозрачные детали
local function clearLine(a, b)
	local full = b - a
	if full.Magnitude < 0.05 then return true end
	local o, dir = a, full
	for _ = 1, 6 do
		local hit = workspace:Raycast(o, dir, losParams)
		if not hit then return true end
		local inst = hit.Instance
		if inst.Material == Enum.Material.Glass or inst.Transparency > 0.6 or inst.Name == "Glass" then
			o = hit.Position + full.Unit * 0.06
			dir = b - o
			if dir:Dot(full) <= 0 or dir.Magnitude < 0.05 then return true end
		else
			return false
		end
	end
	return false
end

---------------------------------------------------------------- заключённый
local Inmate = {}
Inmate.__index = Inmate
InmateAI.Inmate = Inmate

function Inmate:now() return clock() end
function Inmate:pos() return self.root.Position end
function Inmate:feet() return self.root.Position - Vector3.new(0, self.rootH, 0) end
function Inmate:eye() return self.root.Position + Vector3.new(0, self.eyeH - self.rootH, 0) end
function Inmate:stunned() return clock() < self.stunUntil end
function Inmate:since() return clock() - self.stateAt end

function Inmate:attr(name, v)
	if self.model.Parent then self.model:SetAttribute(name, v) end
end

-- Anim для клиента; hold — держать столько секунд (удар, взлом), прочие смены в это время игнорируются
function Inmate:setAnim(name, hold)
	local now = clock()
	if hold then
		self.animLock = now + hold
		self.animN = self.animN + 1
		self:attr("AnimN", self.animN)
	elseif now < self.animLock then
		return
	end
	if self.anim ~= name then
		self.anim = name
		self:attr("Anim", name)
	end
end

function Inmate:setState(s)
	if self.state ~= s then
		self.prevState = self.state
		self.state = s
		self.stateAt = clock()
	end
end

function Inmate:fx(kind, a, b, c)
	local ok, err = pcall(self.match.fx, self.match, kind, a, b, c)
	if not ok then warnOnce("fx", err) end
end

function Inmate:fxTo(plr, kind, a, b, c)
	pcall(self.match.fxTo, self.match, plr, kind, a, b, c)
end

-- есть ли звук в Config.Sounds (иначе берём запасной)
function Inmate:snd(key, fallback)
	if key and Sound and Sound.id(key) ~= "" then return key end
	return fallback
end

-- звук у всех в матче; at — Vector3/Instance (по умолчанию корень)
function Inmate:sound(key, at, props, fallback)
	local k = self:snd(key, fallback)
	if k then self:fx("sound", k, at or self.root, props) end
end

-- реплика заключённого (всплывающий текст у всех в матче), не чаще раза в 1.5 с
function Inmate:say(text, color, force)
	local now = clock()
	if not force and now < (self.sayAt or 0) then return end
	self.sayAt = now + 1.5
	pcall(self.match.toast, self.match, text, color or self.def.color)
end

function Inmate:shakeNear(power, secs, radius, at)
	at = at or self.root.Position
	for _, p in ipairs(self:players()) do
		local d = (p.pos - at).Magnitude
		if d < radius then self:fxTo(p.plr, "shake", power * (1 - d / radius), secs) end
	end
end

---------------------------------------------------------------- дом
function Inmate:refreshHouse()
	local house = self.house
	local H = { panels = {}, panelDoor = {}, lamps = {}, rooms = {}, at = clock() }
	for _, door in ipairs(house.doors or {}) do
		local leaf = door:FindFirstChild("Leaf")
		local panel = leaf and (leaf.PrimaryPart or leaf:FindFirstChild("Panel"))
		if panel then
			table.insert(H.panels, panel)
			H.panelDoor[panel] = door
		end
	end
	if #H.panels > 0 then
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = H.panels
		H.doorParams = rp
	end
	for _, lamp in ipairs(house.lights or {}) do
		local l = lamp:IsA("Light") and lamp or lamp:FindFirstChildWhichIsA("Light", true)
		local part = lamp:IsA("BasePart") and lamp or (l and l.Parent)
		if l and part and part:IsA("BasePart") then table.insert(H.lamps, { part = part, light = l }) end
	end
	for _, r in ipairs(house.rooms or {}) do
		if r:GetAttribute("Indoor") == true then table.insert(H.rooms, r) end
	end
	self.H = H
end

-- точки пола в комнате (кэш на дом)
local function roomPoints(house, room)
	local cache = roomCache[house]
	if not cache then
		cache = {}
		roomCache[house] = cache
	end
	if cache[room] then return cache[room] end
	local pts = {}
	local cf, size = room.CFrame, room.Size
	local bottom = room.Position.Y - size.Y / 2
	for _ = 1, 10 do
		local x = (math.random() - 0.5) * math.max(0, size.X - 5)
		local z = (math.random() - 0.5) * math.max(0, size.Z - 5)
		local from = (cf * CFrame.new(x, size.Y / 2 - 1, z)).Position
		local hit = workspace:Raycast(from, Vector3.new(0, -size.Y - 3, 0), losParams)
		if hit and hit.Normal.Y > 0.7 and hit.Position.Y < bottom + 1.6 then
			table.insert(pts, hit.Position)
			if #pts >= 4 then break end
		end
	end
	if #pts == 0 then table.insert(pts, Vector3.new(room.Position.X, bottom + 0.1, room.Position.Z)) end
	cache[room] = pts
	return pts
end

-- случайная точка пола в данной комнате
function Inmate:roomPoint(room)
	local pts = roomPoints(self.house, room)
	return pts[math.random(#pts)]
end

-- случайная точка в комнате дома (Indoor=true); except — не та же комната
function Inmate:randomRoomPoint(except)
	local rooms = self.H.rooms
	if #rooms > 0 then
		local room = rooms[math.random(#rooms)]
		if room == except and #rooms > 1 then room = rooms[math.random(#rooms)] end
		local pts = roomPoints(self.house, room)
		return pts[math.random(#pts)], room
	end
	local sp = self.house.spawns
	if sp and #sp > 0 then return sp[math.random(#sp)].Position, nil end
	return self.house.origin, nil
end

function Inmate:litAt(pos)
	if self.match.power == false then return false end
	local n = 0
	for _, L in ipairs(self.H.lamps) do
		local l = L.light
		if l.Parent and l.Enabled then
			local d = (L.part.Position - pos).Magnitude
			if d < l.Range * 0.9 then
				n = n + 1
				if clearLine(L.part.Position, pos) then return true end
				if n >= 3 then return false end
			end
		end
	end
	return false
end

function Inmate:indoors(pos)
	local ok, r = pcall(self.match.isIndoors, self.match, pos or self:feet() + Vector3.new(0, 2, 0))
	return ok and r == true
end

-- высота потолка над точкой (nil — неба над головой)
function Inmate:ceilingAt(pos, up)
	local hit = workspace:Raycast(pos + Vector3.new(0, 1.5, 0), Vector3.new(0, up or 30, 0), losParams)
	return hit and hit.Position.Y or nil
end

function Inmate:floorAt(pos, down)
	local hit = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -(down or 20), 0), losParams)
	return hit and hit.Position.Y or nil
end

function Inmate:hideOf(plr)
	for _, h in ipairs(self.house.hides or {}) do
		local ok, occ = pcall(HouseLogic.occupant, h)
		if ok and occ == plr then return h end
	end
	return nil
end

function Inmate:pickHide(pos, radius)
	local list = {}
	for _, h in ipairs(self.house.hides or {}) do
		local ex = h:FindFirstChild("Exit")
		if ex and h ~= self.mem.lastHide and (ex.Position - pos).Magnitude < radius then table.insert(list, h) end
	end
	if #list == 0 then return nil end
	return list[math.random(#list)]
end

-- вход в дом: kind = "Door" | "Window" | nil; из трёх ближайших — случайный
function Inmate:pickEntry(kind, near)
	local list = {}
	for _, e in ipairs(self.house.entries or {}) do
		if e.Parent and e:FindFirstChild("Out") and e:FindFirstChild("In") then
			if not kind or e:GetAttribute("Kind") == kind then table.insert(list, e) end
		end
	end
	if #list == 0 then
		if kind then return self:pickEntry(nil, near) end
		return nil
	end
	near = near or self.root.Position
	table.sort(list, function(a, b) return (a.Out.Position - near).Magnitude < (b.Out.Position - near).Magnitude end)
	return list[math.random(math.min(3, #list))]
end

-- входная дверь (наружная, ближе всех к улице −Z)
function Inmate:frontDoor()
	local best, bz = nil, math.huge
	for _, e in ipairs(self.house.entries or {}) do
		if e:GetAttribute("Kind") == "Door" and e:FindFirstChild("Out") and e.Out.Position.Z < bz then
			best, bz = e, e.Out.Position.Z
		end
	end
	return best
end

---------------------------------------------------------------- игроки
function Inmate:info(plr)
	if not plr or not plr.Parent then return nil end
	local m = self.match
	local alive = m.alive and m.alive[plr] == true
	if m.isAlive then
		local ok, r = pcall(m.isAlive, m, plr)
		if ok then alive = r end
	end
	if not alive then return nil end
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return nil end
	local pos = root.Position
	local head = char:FindFirstChild("Head")
	local my = self.root.Position
	local v = root.AssemblyLinearVelocity
	local feet = pos - Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)
	return {
		plr = plr, char = char, root = root, hum = hum, pos = pos, feet = feet,
		head = head and head.Position or (pos + Vector3.new(0, 1.5, 0)),
		hidden = plr:GetAttribute("Hidden") == true,
		sprint = plr:GetAttribute("Sprinting") == true,
		crouch = plr:GetAttribute("Crouching") == true,
		flash = plr:GetAttribute("Flashlight") == true,
		speed = Vector3.new(v.X, 0, v.Z).Magnitude,
		dist = (pos - my).Magnitude, flat = fdist(pos, my), dy = feet.Y - (my.Y - self.rootH),
	}
end

-- живые игроки матча (кэш на тик); спрятавшиеся тоже (hidden = true)
function Inmate:players()
	if self.pT == tickId and self.pList then return self.pList end
	local out = {}
	for _, plr in ipairs(self.match.players or {}) do
		local p = self:info(plr)
		if p then table.insert(out, p) end
	end
	self.pT, self.pList = tickId, out
	return out
end

function Inmate:find(plr, fresh)
	if fresh then return self:info(plr) end
	for _, p in ipairs(self:players()) do
		if p.plr == plr then return p end
	end
	return nil
end

function Inmate:nearest(filter)
	local best = nil
	for _, p in ipairs(self:players()) do
		if (not filter or filter(p)) and (not best or p.dist < best.dist) then best = p end
	end
	return best
end

---------------------------------------------------------------- чувства
function Inmate:los(a, b) return clearLine(a, b) end

-- видит ли игрока: o.sight (дальность), o.dark (в темноте), o.cone (cos половины угла), o.wide, o.near
function Inmate:canSee(p, o)
	o = o or EMPTY
	if not p or p.hidden then return false end
	local def = self.def
	local eye = self:eye()
	local d = (p.head - eye).Magnitude
	local range = o.sight or def.sight or 70
	if not (p.flash or self:litAt(p.pos)) then
		if self:indoors(p.pos) then
			range = math.min(range, o.dark or def.dark or 26)
		else
			range = math.min(range, o.outdoor or def.outdoor or 45)
		end
	end
	if p.crouch then range = range * 0.75 end
	if d > range then return false end
	if d > (o.near or 7) then
		local cone = o.cone or def.cone or 0.82
		if o.wide then cone = math.min(cone, 0.1) end
		local fwd = flat(self.root.CFrame.LookVector)
		local to = Vector3.new(p.head.X - eye.X, 0, p.head.Z - eye.Z)
		if fwd.Magnitude > 0.1 and to.Magnitude > 0.5 and fwd.Unit:Dot(to.Unit) < cone then return false end
	end
	return clearLine(eye, p.head) or clearLine(eye, p.pos)
end

function Inmate:look(o)
	local best = nil
	for _, p in ipairs(self:players()) do
		if not p.hidden and self:canSee(p, o) and (not best or p.dist < best.dist) then best = p end
	end
	return best
end

-- слух: бег (Sprinting) ~40 стадов, присед — вдвое тише, шаги вплотную
function Inmate:hears(p, o)
	o = o or EMPTY
	if not p or p.hidden then return false end
	local hear = o.hear
	if hear == nil then hear = self.def.hear end
	if hear == false then return false end
	local r = 0
	if p.sprint and p.speed > 3 then r = hear or 40 end
	if not p.crouch and p.speed > 3 then r = math.max(r, o.feel or 9) end
	if p.crouch then r = r * 0.5 end
	if math.abs(p.dy) > 8 then r = r * 0.6 end
	return p.dist < r
end

function Inmate:listen(o)
	local best = nil
	for _, p in ipairs(self:players()) do
		if self:hears(p, o) and (not best or p.dist < best.dist) then best = p end
	end
	return best
end

---------------------------------------------------------------- движение
function Inmate:stop()
	local nav = self.nav
	nav.moving = false
	nav.moveTarget = nil
	if not self.root.Anchored then self.hum:MoveTo(self.root.Position) end
end

function Inmate:face(at)
	if self.root.Anchored then return end
	local p = self.root.Position
	local d = Vector3.new(at.X - p.X, 0, at.Z - p.Z)
	if d.Magnitude < 0.2 then return end
	if flat(self.root.CFrame.LookVector):Dot(d.Unit) > 0.985 then return end
	self.root.CFrame = CFrame.lookAt(p, p + d.Unit)
end

function Inmate:resetNav()
	local nav = self.nav
	nav.wps, nav.goal, nav.idx, nav.dirty = nil, nil, 1, false
	nav.gen = nav.gen + 1
	nav.computing = false
	nav.moveTarget = nil
	nav.chkAt = nil
	nav.stuck = 0
end

-- мгновенно переставить (корень на высоте rootH над точкой пола)
function Inmate:teleport(pos, look)
	local p = pos + Vector3.new(0, self.rootH + 0.1, 0)
	local dir = look and flat(look) or flat(self.root.CFrame.LookVector)
	if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, -1) end
	self.root.CFrame = CFrame.lookAt(p, p + dir.Unit)
	self.root.AssemblyLinearVelocity = Vector3.new()
	self:resetNav()
end

function Inmate:computePath(goal)
	local nav = self.nav
	nav.computing = true
	nav.dirty = false
	nav.goal = goal
	nav.computedAt = clock()
	nav.gen = nav.gen + 1
	local gen = nav.gen
	local from = self.root.Position
	task.spawn(function()
		local ok, err = pcall(function() self.path:ComputeAsync(from, goal) end)
		if nav.gen ~= gen then return end
		nav.computing = false
		if self.gone then return end
		if not ok then warnOnce("path", err) end
		local status = ok and self.path.Status.Name or "Error"
		nav.status = status
		if status == "Success" or status == "ClosestNoPath" or status == "ClosestOutOfRange" then
			local wps = self.path:GetWaypoints()
			nav.wps = wps
			nav.idx = 2
			local last = wps[#wps]
			nav.partial = status ~= "Success" or (last ~= nil and (last.Position - goal).Magnitude > 4)
		else
			nav.wps = nil
			nav.partial = true
		end
	end)
end

function Inmate:nextWaypoint(feet)
	local nav = self.nav
	local wps = nav.wps
	if not wps then return nil end
	while nav.idx <= #wps do
		local w = wps[nav.idx].Position
		if fdist(feet, w) < 2.2 and math.abs(feet.Y - w.Y) < 4.5 then
			nav.idx = nav.idx + 1
		else
			return w
		end
	end
	return nil
end

-- закрытая дверь между точками (луч только по полотнам дверей)
function Inmate:doorAhead(from, to)
	local H = self.H
	if not H.doorParams then return nil end
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local len = d.Magnitude
	if len < 0.05 then return nil end
	local dir = d.Unit
	local y = math.clamp(from.Y, self:feet().Y + 1, self:feet().Y + 6)
	local o = Vector3.new(from.X, y, from.Z)
	local remaining = math.min(len + 1.5, 6)
	local now = clock()
	for _ = 1, 4 do
		local hit = workspace:Raycast(o, dir * remaining, H.doorParams)
		if not hit then return nil end
		local door = H.panelDoor[hit.Instance]
		if door and door.Parent and not HouseLogic.isOpen(door) and (self.nav.ignoreDoor[door] or 0) < now then
			return door, hit.Position
		end
		remaining = remaining - (hit.Position - o).Magnitude - 0.06
		if remaining <= 0 then return nil end
		o = hit.Position + dir * 0.06
	end
	return nil
end

-- открыть (не заперта) или выбивать (заперта); возвращает "opening"/"bashing" или nil — путь свободен
function Inmate:handleDoor(door, at)
	local nav = self.nav
	local now = clock()
	self:stop()
	nav.chkAt = nil
	if HouseLogic.isOpen(door) then return nil end
	self:face(at)
	if HouseLogic.isLocked(door) then
		if now >= nav.bashAt then
			nav.bashAt = now + (self.def.bashEvery or 0.8)
			self:setAnim("bash", 0.45)
			self:sound("DoorBash", at, { Volume = 0.5, PlaybackSpeed = 0.7 })
			self:shakeNear(0.6, 0.25, 26, at)
			local ok, broken = pcall(HouseLogic.damageDoor, door, self.def.bash or 22)
			if not ok then
				warnOnce("damageDoor", broken)
				nav.ignoreDoor[door] = now + 6
			elseif broken then
				nav.pauseUntil = now + 0.35
				nav.dirty = true
			end
			if self.def.server.onBash then pcall(self.def.server.onBash, self, door, broken) end
		end
		return "bashing"
	end
	nav.tries[door] = (nav.tries[door] or 0) + 1
	local ok, res = pcall(HouseLogic.setDoor, door, true, true)
	if not ok or res == false or nav.tries[door] > 4 then
		if nav.tries[door] > 4 then
			nav.ignoreDoor[door] = now + 6
			nav.tries[door] = 0
		end
	end
	self:setAnim("inspect", 0.35)
	nav.pauseUntil = now + 0.4
	return "opening"
end

-- застрял (1.5 с почти на месте) — пересчитать путь; трижды подряд — шагнуть к точке пути
function Inmate:checkStuck(now, pos)
	local nav = self.nav
	if not nav.chkAt then
		nav.chkAt, nav.chkPos = now, pos
		return
	end
	if now - nav.chkAt < 1.5 then return end
	if fdist(pos, nav.chkPos) < 1.2 and self.hum.WalkSpeed > 1 then
		nav.stuck = nav.stuck + 1
		nav.dirty = true
		if nav.stuck >= 3 then
			local w = self:nextWaypoint(self:feet()) or nav.goal
			nav.stuck = 0
			if w then self:teleport(w, w - pos) end
		end
	else
		nav.stuck = 0
	end
	nav.chkAt, nav.chkPos = now, pos
end

-- идти к точке пола goal со скоростью speed. o.repath — пересчёт пути раз в N с, o.direct — прямо,
-- o.near — радиус прибытия. Возвращает "arrived" | "moving" | "opening" | "bashing" | "waiting" | "anchored"
function Inmate:goTo(goal, speed, o)
	o = o or EMPTY
	local nav = self.nav
	if self.root.Anchored then return "anchored" end
	local now = clock()
	local pos = self.root.Position
	local feet = pos - Vector3.new(0, self.rootH, 0)
	if fdist(feet, goal) < (o.near or 3) and math.abs(feet.Y - goal.Y) < 5 then
		self:stop()
		return "arrived"
	end
	if now < nav.pauseUntil then
		self:stop()
		return "waiting"
	end
	self.hum.WalkSpeed = speed
	local target
	if o.direct then
		target = goal
		nav.wps = nil
		nav.goal = goal
	else
		local changed = (not nav.goal) or (nav.goal - goal).Magnitude > (o.regoal or 4)
		local stale = o.repath and (now - nav.computedAt > o.repath)
		if (changed or stale or nav.dirty) and not nav.computing then self:computePath(goal) end
		target = self:nextWaypoint(feet) or goal
	end
	local door, at = self:doorAhead(pos, target)
	if door then
		local r = self:handleDoor(door, at)
		if r then return r end
	end
	if nav.moveTarget ~= target or now - nav.moveAt > 1.5 then
		self.hum:MoveTo(target)
		nav.moveTarget, nav.moveAt = target, now
	end
	nav.moving = true
	self:checkStuck(now, pos)
	return "moving"
end

-- перелезть (окно): корень закреплён, плавно Out → над подоконником → In, потом снова физика
function Inmate:vault(fromPos, toPos, dur, onDone)
	dur = dur or 0.8
	self.vaulting = true
	self:stop()
	self:setAnim("vault", dur + 0.1)
	local root = self.root
	local look = flat(toPos - fromPos)
	if look.Magnitude < 0.1 then look = flat(root.CFrame.LookVector) end
	look = look.Unit
	local h = Vector3.new(0, self.rootH, 0)
	local a = CFrame.lookAt(fromPos + h, fromPos + h + look)
	local mid = (fromPos + toPos) / 2 + h + Vector3.new(0, 1.6, 0)
	local b = CFrame.lookAt(toPos + h, toPos + h + look)
	root.Anchored = true
	root.CFrame = a
	local t1 = TweenService:Create(root, TweenInfo.new(dur * 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = CFrame.lookAt(mid, mid + look) })
	t1:Play()
	task.delay(dur * 0.5, function()
		if self.gone then return end
		local t2 = TweenService:Create(root, TweenInfo.new(dur * 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { CFrame = b })
		t2:Play()
	end)
	task.delay(dur + 0.05, function()
		if self.gone then return end
		root.CFrame = b
		if not self.holdAnchor then root.Anchored = false end
		Rig.own(self.model)
		self.vaulting = false
		self:resetNav()
		if onDone then pcall(onDone) end
	end)
end

---------------------------------------------------------------- состояния
-- проникновение в дом: к маркеру Out входа; дверь — открыть/выбить; окно — разбить и перелезть
function Inmate:enter(dt, o)
	o = o or EMPTY
	local def = self.def
	local m = self.mem.enter
	if not m then
		local e = self.entry or self:pickEntry(o.entryKind or def.entry)
		if not e then return true end
		self.entry = e
		m = { phase = "approach", t = 0, t0 = clock() }
		self.mem.enter = m
	end
	local e = self.entry
	if not e.Parent then
		self.mem.enter, self.entry = nil, nil
		return false
	end
	local outP, inP = e.Out.Position, e.In.Position
	local isWin = e:GetAttribute("Kind") == "Window"
	local speed = o.speed or def.speed or 10
	m.t = m.t + dt
	if m.phase == "approach" then
		self:setAnim(o.anim or "walk")
		local r = self:goTo(outP, speed, { near = 2.5 })
		if r == "arrived" then
			m.phase = isWin and "break" or "door"
			m.t = 0
		elseif clock() - m.t0 > 45 then
			self:teleport(outP, inP - outP)
		end
		return false
	elseif m.phase == "door" then
		self:setAnim(o.anim or "walk")
		local r = self:goTo(inP, speed, { near = 2.5 })
		if r == "arrived" or m.t > 30 then return true end
		return false
	elseif m.phase == "break" then
		self:stop()
		self:face(inP)
		if e:GetAttribute("Broken") == true or m.t > (def.breakTime or 1.4) then
			if e:GetAttribute("Broken") ~= true then pcall(HouseLogic.breakWindow, e) end
			self:shakeNear(0.7, 0.3, 30, outP)
			m.phase = "vault"
			self:vault(outP, inP, def.vaultTime or 0.8)
		else
			self:setAnim("break")
		end
		return false
	elseif m.phase == "vault" then
		return not self.vaulting
	end
	return true
end

function Inmate:spotted(plr)
	local now = clock()
	if (self.spotCd[plr] or 0) > now then return end
	self.spotCd[plr] = now + 10
	self:fxTo(plr, "spotted", self.key)
	if self.def.server.onSpot then pcall(self.def.server.onSpot, self, plr) end
end

function Inmate:startChase(p, quiet)
	local was = self.target
	self.target = p.plr
	self.lastKnown = p.feet
	self.lastSeenT = clock()
	self:setState("chase")
	if not quiet and was ~= p.plr then self:spotted(p.plr) end
end

function Inmate:investigate(pos)
	if self.state == "search" and self.lastKnown and (self.lastKnown - pos).Magnitude < 6 then
		self.lastKnown = pos
		return
	end
	self.lastKnown = pos
	self.mem.search = nil
	self:setState("search")
end

function Inmate:roam(dt, o)
	o = o or EMPTY
	local def = self.def
	local m = self.mem.roam
	if not m then
		m = {}
		self.mem.roam = m
	end
	local now = clock()
	if not m.goal then
		m.goal, m.room = self:randomRoomPoint(m.room)
		m.pause, m.t0, m.turn = nil, now, 0
	end
	if m.pause then
		self:stop()
		self:setAnim("look")
		if now > m.turn then
			m.turn = now + 1 + math.random()
			local a = math.random() * math.pi * 2
			self:face(self.root.Position + Vector3.new(math.cos(a), 0, math.sin(a)))
		end
		if now > m.pause then
			m.goal = nil
			if math.random() < (o.inspect or def.inspect or 0.3) then
				local h = self:pickHide(self:feet(), 28)
				if h then self:startInspect(h) end
			end
		end
		return
	end
	self:setAnim("roam")
	local r = self:goTo(m.goal, o.speed or def.speed or 10)
	if r == "arrived" or now - m.t0 > 25 then
		m.pause = now + 1.2 + math.random() * 2.2
		m.turn = now + 0.5
	end
end

function Inmate:chase(dt, o)
	o = o or EMPTY
	local def = self.def
	local p = self.target and self:find(self.target)
	if not p then
		self.target = nil
		self:setState(self.lastKnown and "search" or "roam")
		return
	end
	local now = clock()
	if p.hidden then
		local pulls = o.pulls
		if pulls == nil then pulls = def.pulls end
		if pulls ~= false and now - (self.lastSeenT or 0) < 2.5 then
			local h = self:hideOf(p.plr)
			if h then
				self:startPull(h, p.plr)
				return
			end
		end
		self.target = nil
		self:setState("search")
		return
	end
	local vis = self:canSee(p, { wide = true, sight = o.sight, dark = o.dark })
	if vis then
		self.lastKnown = p.feet
		self.lastSeenT = now
	end
	if now - (self.lastSeenT or 0) > (o.lose or def.lose or 7) then
		self.target = nil
		self:setState("search")
		return
	end
	self:setAnim(o.anim or "chase")
	local speed = o.chase or def.chase or 15
	local direct = vis and p.flat < 14 and math.abs(p.dy) < 3.5 and clearLine(self.root.Position, p.pos)
	local r = self:goTo(vis and p.feet or self.lastKnown, speed, { repath = 1.0, direct = direct, near = 1.5 })
	if r == "arrived" and not vis then
		self.target = nil
		self:setState("search")
		return
	end
	self:tryAttack(p, o)
end

function Inmate:search(dt, o)
	o = o or EMPTY
	local def = self.def
	local m = self.mem.search
	if not m or m.at ~= self.stateAt then
		m = { at = self.stateAt, phase = "go", t = 0, turn = 0 }
		self.mem.search = m
	end
	if m.phase == "go" then
		self:setAnim("search")
		if not self.lastKnown then
			m.phase = "look"
		else
			local r = self:goTo(self.lastKnown, (o.speed or def.speed or 10) * 1.2, { near = 3 })
			if r == "arrived" or self:since() > 20 then m.phase, m.t = "look", 0 end
		end
		return
	end
	self:stop()
	self:setAnim("look")
	m.t = m.t + dt
	if m.t > m.turn then
		m.turn = m.t + 0.9
		local a = math.random() * math.pi * 2
		self:face(self.root.Position + Vector3.new(math.cos(a), 0, math.sin(a)))
	end
	if m.t > 3.2 then
		self.lastKnown = nil
		if math.random() < (o.searchInspect or def.searchInspect or 0.5) then
			local h = self:pickHide(self:feet(), 20)
			if h then
				self:startInspect(h)
				return
			end
		end
		self:setState("roam")
	end
end

function Inmate:startInspect(hide)
	self.mem.ins = { hide = hide, phase = "go", t = 0 }
	self.mem.lastHide = hide
	self:setState("inspect")
end

-- проверить укрытие: подойти, открыть, постоять, уйти (def.findChance — шанс найти того, кто внутри)
function Inmate:inspect(dt, o)
	o = o or EMPTY
	local def = self.def
	local m = self.mem.ins
	local hide = m and m.hide
	local exit = hide and hide.Parent and hide:FindFirstChild("Exit")
	local inside = hide and hide:FindFirstChild("Inside")
	if not exit or not inside then
		self:setState("roam")
		return
	end
	if m.phase == "go" then
		self:setAnim("roam")
		local r = self:goTo(exit.Position, o.speed or def.speed or 10, { near = 2.6 })
		if r == "arrived" or self:since() > 15 then
			m.phase, m.t = "open", 0
			self:face(inside.Position)
			self:setAnim("inspect", 1.4)
			self:sound("DoorOpen", inside.Position, { Volume = 0.7 })
		end
		return
	end
	self:stop()
	m.t = m.t + dt
	if not m.checked and m.t > 0.6 then
		m.checked = true
		local ok, occ = pcall(HouseLogic.occupant, hide)
		if ok and occ then
			local p = self:find(occ)
			if p and math.random() < (o.findChance or def.findChance or 0) then
				self.target = occ
				self.lastSeenT = clock()
				self:startPull(hide, occ)
				m.found = true
				return
			end
			self:fxTo(occ, "shake", 0.35, 0.6)
			self:fxTo(occ, "sound", self:snd("Breath", "Heartbeat"), inside, { Volume = 0.8 })
		end
	end
	if m.t > 1.9 then
		self:sound("DoorClose", inside.Position, { Volume = 0.6 })
		self:setState("roam")
	end
end

function Inmate:startPull(hide, plr)
	self.mem.pull = { hide = hide, plr = plr, phase = "go", t = 0 }
	self.target = plr
	self:setState("pull")
end

-- видел, как игрок спрятался: подойти, открыть, вытащить (HouseLogic.pullOut) и ударить
function Inmate:pull(dt, o)
	o = o or EMPTY
	local m = self.mem.pull
	if not m then
		self:setState("roam")
		return
	end
	local hide, plr = m.hide, m.plr
	local ok, occ = pcall(HouseLogic.occupant, hide)
	if not ok or occ ~= plr then
		local p = self:find(plr)
		if p and not p.hidden then self:startChase(p, true) else self:setState("search") end
		return
	end
	local exit = hide:FindFirstChild("Exit")
	local inside = hide:FindFirstChild("Inside")
	if not exit then
		self:setState("search")
		return
	end
	if m.phase == "go" then
		self:setAnim("chase")
		local r = self:goTo(exit.Position, o.chase or self.def.chase or 15, { near = 2.8 })
		if r == "arrived" or self:since() > 12 then
			m.phase, m.t = "pull", 0
			if inside then self:face(inside.Position) end
			self:setAnim("pull", 1.0)
			self:sound("DoorOpen", inside or exit, { Volume = 1 })
		end
		return
	end
	self:stop()
	m.t = m.t + dt
	if m.t > 0.7 then
		pcall(HouseLogic.pullOut, self.match, plr)
		self.attackReady = clock() + 0.35
		self.lastSeenT = clock()
		self.lastKnown = exit.Position
		self.target = plr
		self:setState("chase")
	end
end

---------------------------------------------------------------- удары
function Inmate:kill(plr)
	local ok, err = pcall(self.match.killPlayer, self.match, plr, self)
	if not ok then warnOnce("killPlayer", err) end
	if self.target == plr then self.target = nil end
	self.pauseUntil = clock() + 1.6
	if self.def.server.onKill then pcall(self.def.server.onKill, self, plr) end
end

function Inmate:hurt(plr, amount)
	local ok, err = pcall(self.match.damagePlayer, self.match, plr, amount, self)
	if not ok then warnOnce("damagePlayer", err) end
end

-- удар вблизи (~4.5 стада) с перезарядкой; def.oneShot — сразу насмерть (скример)
function Inmate:tryAttack(p, o)
	o = o or EMPTY
	local def = self.def
	local now = clock()
	if not p or p.hidden or now < self.attackReady then return false end
	local reach = o.reach or def.reach or 4.5
	if p.flat > reach or math.abs(p.dy) > (o.reachY or def.reachY or 5) then return false end
	if not (clearLine(self:eye(), p.head) or clearLine(self.root.Position, p.pos)) then return false end
	self.attackReady = now + (o.cooldown or def.cooldown or 1.3)
	self:face(p.pos)
	self:setAnim("attack", 0.6)
	local plr = p.plr
	local oneShot = o.oneShot
	if oneShot == nil then oneShot = def.oneShot end
	local dmg = o.damage or def.damage or 35
	task.delay(o.windup or def.windup or 0.22, function()
		if self.gone or self.dead or self:stunned() then return end
		local q = self:find(plr, true)
		if not q or q.hidden or q.flat > reach + 2.5 or math.abs(q.dy) > 6 then return end
		if oneShot then self:kill(plr) else self:hurt(plr, dmg) end
	end)
	return true
end

---------------------------------------------------------------- охота по умолчанию
-- o: speed, chase, sight, dark, hear, reach, damage, oneShot, pulls, inspect, blindEnter, entryKind
function Inmate:hunt(dt, o)
	o = o or EMPTY
	if self.state == "enter" then
		if self:enter(dt, o) then self:setState("roam") end
		if not o.blindEnter and not self.vaulting then
			local seen = self:look(o)
			if seen then self:startChase(seen) end
		end
		return
	end
	if self.state ~= "pull" then
		local seen = self:look(o)
		if seen then
			local cur = self.state == "chase" and self.target and self:find(self.target)
			if not cur or cur.hidden or (seen.plr ~= self.target and seen.dist + 10 < cur.dist) then
				self:startChase(seen)
			end
		elseif self.state ~= "chase" then
			local heard = self:listen(o)
			if heard then self:investigate(heard.feet) end
		end
	end
	local st = self.state
	if st == "chase" then
		self:chase(dt, o)
	elseif st == "search" then
		self:search(dt, o)
	elseif st == "pull" then
		self:pull(dt, o)
	elseif st == "inspect" then
		self:inspect(dt, o)
	else
		if st ~= "roam" then self:setState("roam") end
		self:roam(dt, o)
	end
	if self.state ~= "chase" then
		for _, p in ipairs(self:players()) do
			if not p.hidden and p.flat < (o.reach or self.def.reach or 4.5) * 0.8 then
				if self:tryAttack(p, o) then break end
			end
		end
	end
end

---------------------------------------------------------------- появление и уход
function Inmate:despawn(fade)
	if self.gone then return end
	self.gone = true
	local srv = self.def.server
	if srv.cleanup then pcall(srv.cleanup, self) end
	if self.pathConn then self.pathConn:Disconnect() end
	local list = self.match.inmates
	if list then
		local i = table.find(list, self)
		if i then table.remove(list, i) end
	end
	local model = self.model
	fade = fade or 0
	if fade <= 0 or not model.Parent then
		model:Destroy()
		return
	end
	task.spawn(function()
		local parts = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 1 then table.insert(parts, { p = d, t = d.Transparency }) end
			if d:IsA("Light") then d.Enabled = false end
		end
		local steps = 8
		for i = 1, steps do
			for _, e in ipairs(parts) do
				if e.p.Parent then e.p.Transparency = e.t + (1 - e.t) * i / steps end
			end
			task.wait(fade / steps)
		end
		model:Destroy()
	end)
end

function Inmate:die(byPlayer)
	if self.dead then return end
	self.dead = true
	self.hp = 0
	self:attr("Hp", 0)
	self:attr("Stunned", false)
	self.animLock = 0
	self:setAnim("dead")
	self:stop()
	self.hum.WalkSpeed = 0
	if self.def.server.onDeath then pcall(self.def.server.onDeath, self, byPlayer) end
	local ok, err = pcall(self.match.onInmateKilled, self.match, self, byPlayer)
	if not ok then warnOnce("onInmateKilled", err) end
	task.delay(2.2, function() self:despawn(1.2) end)
end

local function respawnFromVoid(inm)
	local e = inm:pickEntry(nil)
	if e and inm.state ~= "enter" then
		inm:teleport(e.In.Position, e.In.Position - e.Out.Position)
	else
		local sp = inm.house.inmateSpawns
		local cf = (sp and #sp > 0) and sp[math.random(#sp)] or CFrame.new(inm.house.origin + Vector3.new(0, 0, -80))
		inm:teleport(cf.Position, cf.LookVector)
		inm.mem.enter = nil
		inm:setState("enter")
	end
end

local function tickOne(inm, dt)
	local model, root = inm.model, inm.root
	if not model.Parent or not root.Parent or inm.match.cleaned or inm.match.phase == "end" then
		inm:despawn(0)
		return
	end
	inm.t = inm.t + dt
	if inm.dead then return end
	if root.Position.Y < inm.house.origin.Y - 50 then respawnFromVoid(inm) end
	local now = clock()
	if now - inm.H.at > 15 then inm:refreshHouse() end
	if now < inm.stunUntil then
		if not root.Anchored then inm.hum:MoveTo(root.Position) end
		inm.hum.WalkSpeed = 0
		return
	elseif model:GetAttribute("Stunned") then
		model:SetAttribute("Stunned", false)
		inm.animLock = 0
	end
	if now < inm.pauseUntil then
		inm:stop()
		inm:setAnim("idle")
		return
	end
	local srv = inm.def.server
	if srv.tick then srv.tick(inm, dt) else inm:hunt(dt) end
end

-- атрибуты модели разом
local function setAttrs(inst, t)
	for k, v in pairs(t) do inst:SetAttribute(k, v) end
end

local function placeAtSpawn(model, house, rootH)
	local sp = house.inmateSpawns
	local cf = (sp and #sp > 0) and sp[math.random(#sp)] or CFrame.new(house.origin + Vector3.new(0, 0, -80))
	local look = flat(house.origin - cf.Position)
	if look.Magnitude < 0.1 then look = Vector3.new(0, 0, 1) end
	local p = cf.Position + Vector3.new(0, rootH + 0.2, 0)
	model:PivotTo(CFrame.lookAt(p, p + look.Unit))
	return cf
end

function InmateAI.spawn(match, key)
	loadModules()
	local def = modules[key]
	if not def then error("нет модуля заключённого " .. tostring(key)) end
	if not match or not match.house then error("у матча нет дома") end
	local ok, built = pcall(def.build, ctx)
	if not ok or typeof(built) ~= "Instance" then error("build " .. tostring(key) .. ": " .. tostring(built)) end
	local model = Rig.finish(built)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		model:Destroy()
		error("у модели " .. tostring(key) .. " нет HumanoidRootPart/Humanoid")
	end
	model.Name = def.key
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then pcall(function() d.CollisionGroup = BODY_GROUP end) end
	end
	local hpMul = (match.diff and match.diff.hpMul) or 1
	local maxHp = math.max(1, math.floor((def.hp or 200) * hpMul + 0.5))
	local rootH = model:GetAttribute("RootHeight") or root.Position.Y
	local inm = setmetatable({
		key = def.key, def = def, match = match, house = match.house, model = model, hum = hum, root = root, ctx = ctx,
		hp = maxHp, maxHp = maxHp, stunUntil = 0, state = "enter", target = nil,
		rootH = rootH, eyeH = def.eyeH or (model:GetAttribute("Height") or (rootH + 2)) * 0.92,
		mem = {}, spotCd = {}, t = 0, stateAt = clock(), anim = "", animLock = 0, animN = 0,
		attackReady = 0, pauseUntil = 0,
		nav = { idx = 1, gen = 0, computing = false, computedAt = 0, dirty = false, pauseUntil = 0, bashAt = 0,
			moveAt = 0, stuck = 0, ignoreDoor = {}, tries = {} },
	}, Inmate)
	setAttrs(model, {
		InmateKey = def.key, MatchId = match.id or 0, Anim = "idle", AnimN = 0, Hp = maxHp, MaxHp = maxHp, Stunned = false,
	})
	inm.spawnCF = placeAtSpawn(model, match.house, rootH)
	model.Parent = folder
	Rig.serverSetup(model)
	hum.WalkSpeed = def.speed or 10
	inm.path = PathfindingService:CreatePath({
		AgentRadius = 2, AgentHeight = 6, AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 4,
		Costs = { Door = 2 },
	})
	inm.pathConn = inm.path.Blocked:Connect(function(idx)
		if inm.nav.wps and idx >= inm.nav.idx then inm.nav.dirty = true end
	end)
	inm:refreshHouse()
	inm:setAnim("idle")
	table.insert(active, inm)
	if def.server.spawn then
		local ok2, err = pcall(def.server.spawn, inm)
		if not ok2 then warnOnce("spawn " .. def.key, err) end
	end
	task.defer(function()
		if not inm.gone and match.inmates and not table.find(match.inmates, inm) then table.insert(match.inmates, inm) end
	end)
	return inm
end

function InmateAI.despawn(inm, fade)
	if inm then inm:despawn(fade or 0.8) end
end

function InmateAI.despawnAll(match)
	for i = #active, 1, -1 do
		local inm = active[i]
		if inm.match == match then
			inm:despawn(0.8)
			table.remove(active, i)
		end
	end
	if folder and match then
		for _, m in ipairs(folder:GetChildren()) do
			if m:GetAttribute("MatchId") == match.id then
				task.delay(1.2, function() if m.Parent then m:Destroy() end end)
			end
		end
	end
end

function InmateAI.list(match)
	local out = {}
	for _, inm in ipairs(active) do
		if not inm.gone and (not match or inm.match == match) then table.insert(out, inm) end
	end
	return out
end

function InmateAI.stun(inm, seconds)
	if not inm or inm.gone or inm.dead then return end
	seconds = seconds or 2
	local srv = inm.def.server
	if srv.onStun then
		local ok, r = pcall(srv.onStun, inm, seconds)
		if ok and r == false then return end
	end
	inm.stunUntil = math.max(inm.stunUntil, clock() + seconds)
	inm:attr("Stunned", true)
	inm:setAnim("stunned", seconds)
	inm:stop()
	inm.hum.WalkSpeed = 0
	if inm.target == nil and inm.state ~= "enter" then inm:setState("search") end
end

function InmateAI.damage(inm, amount, byPlayer)
	if not inm or inm.gone or inm.dead then return end
	local def = inm.def
	if def.server.onDamage then
		local ok, r = pcall(def.server.onDamage, inm, amount, byPlayer)
		if ok and r == false then return end
		if not ok then warnOnce("onDamage " .. inm.key, r) end
	end
	if def.immortal then
		InmateAI.stun(inm, def.stagger or 2)
		return
	end
	inm.hp = math.max(0, inm.hp - (amount or 0))
	inm:attr("Hp", inm.hp)
	if inm.hp <= 0 then
		inm:die(byPlayer)
		return
	end
	InmateAI.stun(inm, def.flinch or 0.35)
	-- выстрел выдаёт стрелка
	if byPlayer and inm.state ~= "chase" and inm.state ~= "enter" then
		local p = inm:find(byPlayer)
		if p and not p.hidden then inm:startChase(p) end
	end
end

function InmateAI.nearest(match, pos, radius)
	local best, bd = nil, radius or math.huge
	for _, inm in ipairs(active) do
		if not inm.gone and not inm.dead and inm.match == match and inm.root.Parent then
			local d = (inm.root.Position - pos).Magnitude
			if d <= bd then best, bd = inm, d end
		end
	end
	return best, best and bd or nil
end

-- какой заключённый выйдет этой ночью: tier = сложность (+1 после 4-й ночи, ≤3), minNight, без повторов (match.used)
function InmateAI.choose(match)
	loadModules()
	local night = match.night or 1
	local tier = (match.diff and match.diff.tier) or 1
	if night > 4 then tier = tier + 1 end
	tier = math.min(3, tier)
	match.used = match.used or {}
	local count = #(match.players or {})
	local function pool(useHistory)
		local list = {}
		for _, key in ipairs(order) do
			local d = modules[key]
			if not d.special and not d.companion and (d.difficulty or 1) <= tier and (d.minNight or 1) <= night
				and (not d.coopOnly or count >= 2) and (not useHistory or not match.used[key]) then
				table.insert(list, d)
			end
		end
		return list
	end
	local list = pool(true)
	if #list == 0 then
		for k in pairs(match.used) do match.used[k] = nil end
		if match.lastInmate then match.used[match.lastInmate] = true end
		list = pool(true)
	end
	if #list == 0 then list = pool(false) end
	if #list == 0 then return nil end
	local total = 0
	for _, d in ipairs(list) do total = total + (d.weight or 1) end
	local r = math.random() * total
	local pick = list[#list]
	for _, d in ipairs(list) do
		r = r - (d.weight or 1)
		if r <= 0 then
			pick = d
			break
		end
	end
	match.used[pick.key] = true
	match.lastInmate = pick.key
	return pick.key
end

function InmateAI.init(c)
	ctx = c
	HouseLogic = c.HouseLogic
	Sound = c.Sound
	folder = workspace:FindFirstChild("Inmates")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Inmates"
		folder.Parent = workspace
	end
	losParams = RaycastParams.new()
	losParams.FilterType = Enum.RaycastFilterType.Exclude
	losParams.IgnoreWater = true
	updateLos()
	-- тело заключённого не задевает мир и игроков: сталкивается только корень
	pcall(function() PhysicsService:RegisterCollisionGroup(BODY_GROUP) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(BODY_GROUP, "Default", false) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(BODY_GROUP, BODY_GROUP, false) end)
	loadModules()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < TICK then return end
		local step = math.min(acc, 0.25)
		acc = 0
		tickId = tickId + 1
		local ok, err = pcall(updateLos)
		if not ok then warnOnce("los", err) end
		for i = #active, 1, -1 do
			local inm = active[i]
			if inm.gone then
				table.remove(active, i)
			else
				local ok2, err2 = pcall(tickOne, inm, step)
				if not ok2 then warnOnce("tick " .. tostring(inm.key), err2) end
			end
		end
	end)
end

return InmateAI
