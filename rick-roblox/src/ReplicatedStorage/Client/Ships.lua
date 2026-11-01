-- Корабли Пожирателей (только у этого игрока). Тёмная «тарелка» с шипами по краю, бегущими
-- фиолетовыми огнями, светящимся ядром под куполом, розовым глазом-прожектором снизу и щупальцами.
-- Флот вылетает из разлома в небе по одному, встаёт кольцом вокруг героев и медленно кружит.
-- Прожекторы можно навести на героев, корабль-лидер подлетает ближе и сбрасывает гранату.
--   local fleet = Ships.fleet(center, riftCF, parent)
--   fleet:launch(i, n)            — вылет i-го корабля из n
--   fleet:tighten(r, h, t)        — сжать кольцо (множители радиуса и высоты) за t секунд
--   fleet:spot(target)            — лучи прожекторов на точку (nil — убрать)
--   fleet:moveShip(i, cf, t)      — увести корабль в точку и держать там
--   fleet:dropGrenade(i, landPos) — сбросить гранату, вернёт объект гранаты
--   fleet:destroy()
local RunService = game:GetService("RunService")

local Ships = {}
local Fleet = {}
Fleet.__index = Fleet
local Grenade = {}
Grenade.__index = Grenade
local B, U, Audio

function Ships.init(ctx)
	B, U, Audio = ctx.Build, ctx.Util, ctx.Audio
end

local NOPHYS = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
local TAU = math.pi * 2

local function props(extra)
	local t = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
	if extra then for k, v in pairs(extra) do t[k] = v end end
	return t
end

-- шар, растянутый в эллипсоид
local function ellipsoid(parent, name, size, color, mat, extra)
	local p = B.ball(parent, name, 1, CFrame.new(), color, mat, props(extra))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = size
	mesh.Parent = p
	return p
end

---------------------------------------------------------------------------
-- один корабль: детали + «оснастка» (смещения от центра корабля)
---------------------------------------------------------------------------
local function buildShip(parent, seed)
	local m = B.model(parent, "DevourerShip")
	B.outline(m)
	local ship = { model = m, rig = {}, parts = {}, cfs = {}, seed = seed, tentacles = {} }
	local function add(p, o, spin)
		table.insert(ship.rig, { p = p, o = o, spin = spin })
		table.insert(ship.parts, p)
		return p
	end
	local I = CFrame.new()
	ship.hull = add(ellipsoid(m, "Hull", Vector3.new(18, 3.4, 18), "#2A1E36", Enum.Material.SmoothPlastic), I)
	add(ellipsoid(m, "Skirt", Vector3.new(13, 2.4, 13), "#1C1426", Enum.Material.SmoothPlastic), CFrame.new(0, -1.0, 0))
	add(ellipsoid(m, "Top", Vector3.new(9.5, 4.6, 9.5), "#3B2A4E", Enum.Material.SmoothPlastic), CFrame.new(0, 1.4, 0))
	add(B.vcyl(m, "Band", 0.5, 11.2, I, "#140E1C", Enum.Material.Metal, props()), CFrame.new(0, 0.9, 0))
	add(ellipsoid(m, "Canopy", Vector3.new(4.8, 2.8, 4.8), "#B04BFF", Enum.Material.Glass, { Transparency = 0.3 }), CFrame.new(0, 3.4, 0))
	local core = add(B.ball(m, "Core", 2.2, I, "#FF3DD1", Enum.Material.Neon, props()), CFrame.new(0, 3.2, 0))
	B.light(core, "PointLight", { Color = Color3.fromRGB(255, 70, 220), Brightness = 2, Range = 16, Shadows = false })
	-- бегущие огни по ободу
	for i = 1, 10 do
		local a = i / 10 * TAU
		add(B.ball(m, "RimLight", 0.95, I, (i % 2 == 0) and "#FF3DD1" or "#9B5CFF", Enum.Material.Neon, props()),
			CFrame.new(math.cos(a) * 8.7, 0.15, math.sin(a) * 8.7), true)
	end
	-- шипы-когти по краю (острым краем наружу)
	for i = 1, 6 do
		local a = (i + 0.5) / 6 * TAU
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = dir * 9.6
		add(B.wedge(m, "Spike", Vector3.new(0.9, 1.3, 4.2), I, "#140E1C", Enum.Material.SmoothPlastic, props()),
			CFrame.lookAt(p, p + dir) * CFrame.new(0, -0.1, 0))
	end
	-- глаз-прожектор снизу
	ship.eye = add(ellipsoid(m, "Eye", Vector3.new(4.4, 1.5, 4.4), "#FF3DD1", Enum.Material.Neon), CFrame.new(0, -2.0, 0))
	add(B.vcyl(m, "EyeRing", 0.4, 5.4, I, "#140E1C", Enum.Material.Metal, props()), CFrame.new(0, -1.75, 0))
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 55
	spot.Range = 60
	spot.Brightness = 4
	spot.Color = Color3.fromRGB(255, 60, 200)
	spot.Shadows = false
	spot.Parent = ship.eye
	-- щупальца (качаются; смещения считаются каждый кадр)
	for j = 1, 3 do
		local a = (j / 3 + 0.08) * TAU
		local tn = { anchor = Vector3.new(math.cos(a) * 3.4, -2.2, math.sin(a) * 3.4), segs = {}, ph = j * 1.7 + seed }
		for k = 1, 5 do
			local d = 1.25 - k * 0.17
			local col = (k == 5) and "#FF3DD1" or "#2A1748"
			local seg = B.ball(m, "Tentacle", d, I, col, (k == 5) and Enum.Material.Neon or Enum.Material.SmoothPlastic, props())
			table.insert(tn.segs, seg)
			table.insert(ship.parts, seg)
		end
		table.insert(ship.tentacles, tn)
	end
	return ship
end

local function placeShip(ship, cf, t)
	local cfs = ship.cfs
	local n = 0
	local spin = CFrame.Angles(0, t * 0.9, 0)
	for _, r in ipairs(ship.rig) do
		n = n + 1
		if r.spin then cfs[n] = cf * spin * r.o else cfs[n] = cf * r.o end
	end
	for _, tn in ipairs(ship.tentacles) do
		local p = tn.anchor
		for k = 1, #tn.segs do
			local sw = math.sin(t * 1.8 + tn.ph + k * 0.6) * 0.32 * k
			local sw2 = math.cos(t * 1.3 + tn.ph + k * 0.5) * 0.32 * k
			p = p + Vector3.new(sw * 0.35, -1.15, sw2 * 0.35)
			n = n + 1
			cfs[n] = cf * CFrame.new(p)
		end
	end
	workspace:BulkMoveTo(ship.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	ship.cf = cf
end

---------------------------------------------------------------------------
-- флот
---------------------------------------------------------------------------
-- center — точка на земле, вокруг которой встаёт кольцо; riftCF — разлом (LookVector к героям)
function Ships.fleet(center, riftCF, parent)
	local self = setmetatable({}, Fleet)
	self.center = center
	self.rift = riftCF
	self.ships = {}
	self.ringR, self.ringH = 1, 1
	self.orbit = 0
	self.orbitSpeed = 0.07
	self.t = 0
	self.hums = {}
	local m = Instance.new("Model")
	m.Name = "RM_Fleet"
	m.Parent = parent or workspace
	self.model = m
	self.conn = RunService.RenderStepped:Connect(function(dt)
		if not U.paused then self:update(dt) end
	end)
	return self
end

-- место корабля в кольце (позиция кружит вокруг центра)
function Fleet:slotCF(ship)
	local a = ship.slotA + self.orbit
	local r = ship.slotR * self.ringR
	local x, z = math.cos(a) * r, math.sin(a) * r
	local h = ship.slotH * self.ringH
	-- над домом (сзади, +Z) летят выше, чтобы не задеть крышу
	if self.center.Z + z > -6 then h = h + 14 end
	local pos = self.center + Vector3.new(x, h + math.sin(self.t * 1.1 + ship.seed) * 0.8, z)
	local look = Vector3.new(self.center.X, pos.Y, self.center.Z)
	return CFrame.lookAt(pos, look) * CFrame.Angles(math.rad(-9), 0, math.sin(self.t * 0.8 + ship.seed) * 0.05)
end

function Fleet:launch(i, n)
	local ship = buildShip(self.model, i * 1.37)
	ship.index = i
	ship.slotA = math.pi * 1.5 + (i - 1) / n * TAU + (i % 2) * 0.12
	ship.slotR = 42 + (i % 3) * 7
	ship.slotH = 22 + (i % 4) * 5
	ship.state = "arrive"
	ship.k = 0
	ship.dur = 3.4 + (i % 3) * 0.4
	ship.from = self.rift.Position + self.rift.LookVector * 2
	-- контрольная точка дуги: вперёд от разлома и в сторону своего места
	local side = Vector3.new(math.cos(ship.slotA), 0, math.sin(ship.slotA))
	ship.ctrl = self.rift.Position + self.rift.LookVector * 70 + side * 40 + Vector3.new(0, -10, 0)
	placeShip(ship, CFrame.new(ship.from), self.t)
	table.insert(self.ships, ship)
	Audio.play("ShipFly", { at = ship.hull, volume = 1, min = 30, max = 500, pitchJitter = 0.1 })
	if i % 2 == 1 then
		local id = "ship_hum_" .. tostring(self) .. "_" .. i
		Audio.loop(id, "ShipHum", { at = ship.hull, volume = 0.6, min = 25, max = 260, speed = 0.9 + (i % 3) * 0.08 })
		table.insert(self.hums, id)
	end
	return ship
end

function Fleet:update(dt)
	self.t = self.t + dt
	self.orbit = self.orbit + self.orbitSpeed * dt
	for _, ship in ipairs(self.ships) do
		local cf
		if ship.state == "arrive" then
			ship.k = math.min(1, ship.k + dt / ship.dur)
			local k = 1 - (1 - ship.k) * (1 - ship.k)
			local slot = self:slotCF(ship)
			local p0, p1, p2 = ship.from, ship.ctrl, slot.Position
			local a, b = p0:Lerp(p1, k), p1:Lerp(p2, k)
			local pos = a:Lerp(b, k)
			local tangent = (b - a)
			local flyRot
			if tangent.Magnitude > 0.05 then
				flyRot = CFrame.lookAt(pos, pos + tangent) - pos
			else
				flyRot = slot - slot.Position
			end
			local w = U.smooth(math.clamp((ship.k - 0.55) / 0.45, 0, 1))
			local rot = flyRot:Lerp(slot - slot.Position, w)
			cf = CFrame.new(pos) * rot
			if ship.k >= 1 then ship.state = "hover" end
		elseif ship.state == "move" then
			ship.k = math.min(1, ship.k + dt / ship.dur)
			cf = ship.mFrom:Lerp(ship.mTo, U.smooth(ship.k))
			if ship.k >= 1 then ship.state = "hold" end
		elseif ship.state == "hold" then
			cf = ship.mTo * CFrame.new(0, math.sin(self.t * 1.4 + ship.seed) * 0.6, 0)
		else
			cf = self:slotCF(ship)
		end
		placeShip(ship, cf, self.t)
	end
	-- лучи прожекторов
	if self.beams then
		for _, bm in ipairs(self.beams) do
			local ship = bm.ship
			if ship.cf then
				local eye = (ship.cf * CFrame.new(0, -2.4, 0)).Position
				local tgt = self.spotTarget + bm.off
				bm.a0.WorldPosition = eye
				bm.a1.WorldPosition = tgt
			end
		end
	end
end

-- сжать или расширить кольцо (множители радиуса и высоты) за t секунд
function Fleet:tighten(r, h, t)
	local r0, h0 = self.ringR, self.ringH
	local el = 0
	task.spawn(function()
		while el < t do
			local dt = RunService.Heartbeat:Wait()
			if not U.paused then
				el = math.min(t, el + dt)
				local k = U.smooth(el / t)
				self.ringR = r0 + (r - r0) * k
				self.ringH = h0 + (h - h0) * k
			end
		end
	end)
end

-- лучи прожекторов на точку (Beam от глаза корабля к земле у героев); nil — убрать
function Fleet:spot(target)
	if self.beamFolder then self.beamFolder:Destroy() end
	self.beams = nil
	self.beamFolder = nil
	if not target then return end
	self.spotTarget = target
	local f = Instance.new("Folder")
	f.Name = "Spots"
	f.Parent = self.model
	self.beamFolder = f
	local anchor = B.part(f, "SpotAnchor", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), Color3.new(0, 0, 0), nil,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	self.beams = {}
	for i, ship in ipairs(self.ships) do
		local a0 = Instance.new("Attachment")
		a0.Parent = anchor
		local a1 = Instance.new("Attachment")
		a1.Parent = anchor
		local bm = Instance.new("Beam")
		bm.Attachment0 = a0
		bm.Attachment1 = a1
		bm.FaceCamera = true
		bm.Width0 = 2.6
		bm.Width1 = 9
		bm.LightEmission = 1
		bm.LightInfluence = 0
		bm.Brightness = 2
		bm.Color = ColorSequence.new(Color3.fromRGB(255, 90, 220), Color3.fromRGB(255, 40, 120))
		bm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.85) })
		bm.Segments = 1
		bm.Parent = anchor
		local ang = i / math.max(1, #self.ships) * TAU
		table.insert(self.beams, { ship = ship, a0 = a0, a1 = a1, off = Vector3.new(math.cos(ang) * 3, 0, math.sin(ang) * 3) })
	end
	self:update(0)
end

-- увести корабль i в точку cf за t секунд и держать там
function Fleet:moveShip(i, cf, t)
	local ship = self.ships[i]
	if not ship or not ship.cf then return end
	ship.mFrom = ship.cf
	ship.mTo = cf
	ship.k = 0
	ship.dur = t or 2
	ship.state = "move"
	Audio.play("ShipFly", { at = ship.hull, volume = 0.8, min = 20, max = 300, speed = 0.8 })
end

---------------------------------------------------------------------------
-- граната: шипастый шар с мигающим огоньком; летит по дуге и пищит всё чаще
---------------------------------------------------------------------------
function Fleet:dropGrenade(i, landPos, flight)
	local ship = self.ships[i]
	local from = ship and ship.cf and (ship.cf * CFrame.new(0, -2.6, 0)).Position or (landPos + Vector3.new(0, 30, 0))
	local g = setmetatable({}, Grenade)
	local m = B.model(self.model, "Grenade")
	B.outline(m)
	g.model = m
	g.parts, g.offs, g.cfs = {}, {}, {}
	local function add(p, o) table.insert(g.parts, p); table.insert(g.offs, o); return p end
	add(B.ball(m, "Shell", 1.5, CFrame.new(from), "#2A1748", Enum.Material.SmoothPlastic, props()), CFrame.new())
	add(B.vcyl(m, "Band", 0.3, 1.62, CFrame.new(from), "#FF3DD1", Enum.Material.Neon, props()), CFrame.new())
	for k = 1, 6 do
		local dir = ({ Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) })[k]
		add(B.wedge(m, "Spike", Vector3.new(0.3, 0.3, 0.6), CFrame.new(from), "#140E1C", Enum.Material.SmoothPlastic, props()),
			CFrame.lookAt(dir * 0.85, dir * 2))
	end
	g.led = add(B.ball(m, "Led", 0.45, CFrame.new(from), "#FF2B2B", Enum.Material.Neon, props()), CFrame.new(0, 0.78, 0))
	g.light = B.light(g.led, "PointLight", { Color = Color3.fromRGB(255, 40, 40), Brightness = 0, Range = 10, Shadows = false })
	g.pos = from
	g.alive = true
	local function place(cf)
		for k, p in ipairs(g.parts) do
			local _ = p
			g.cfs[k] = cf * g.offs[k]
		end
		workspace:BulkMoveTo(g.parts, g.cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	g.place = place
	flight = flight or 1.5
	Audio.play("Whoosh", { at = g.parts[1], volume = 0.6, speed = 1.4 })
	-- полёт по дуге (блокирует до приземления)
	local el = 0
	local land = landPos + Vector3.new(0, 0.75, 0)
	while el < flight do
		local dt = RunService.Heartbeat:Wait()
		if not U.paused then
			el = math.min(flight, el + dt)
			local k = el / flight
			local p = from:Lerp(land, k * k) + Vector3.new(0, math.sin(k * math.pi) * 3, 0)
			g.pos = p
			place(CFrame.new(p) * CFrame.Angles(el * 9, el * 6, 0))
		end
	end
	g.pos = land
	place(CFrame.new(land) * CFrame.Angles(0, el * 6, 0))
	Audio.play("Land", { at = g.parts[1], volume = 0.7, speed = 1.3 })
	return g
end

-- пищать всё чаще (асинхронно), пока граната жива
function Grenade:arm()
	task.spawn(function()
		local gap = 0.55
		while self.alive do
			self.led.Color = Color3.fromRGB(255, 60, 60)
			self.light.Brightness = 5
			Audio.play("Beep", { at = self.parts[1], volume = 0.9 })
			U.wait(0.08)
			if not self.alive then break end
			self.led.Color = Color3.fromRGB(90, 10, 10)
			self.light.Brightness = 0
			U.wait(gap)
			gap = math.max(0.07, gap * 0.8)
		end
	end)
end

function Grenade:destroy()
	self.alive = false
	if self.model then self.model:Destroy() end
end

function Fleet:destroy()
	if self.conn then self.conn:Disconnect() end
	for _, id in ipairs(self.hums) do Audio.stop(id, 0.3) end
	self.hums = {}
	if self.model then self.model:Destroy() end
end

local _n = NOPHYS
return Ships
