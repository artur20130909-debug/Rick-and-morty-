-- Щупальца из «цифрового измерения»: цепочка шаров от основания к цели, извиваются,
-- вырастают, хватают, а от выстрела Рика рассыпаются на пиксели. Только у этого игрока.
local RunService = game:GetService("RunService")

local Tentacles = {}
Tentacles.__index = Tentacles
local B, U, Audio

function Tentacles.init(ctx)
	B, U, Audio = ctx.Build, ctx.Util, ctx.Audio
end

-- baseFn() -> CFrame основания (LookVector — куда растёт), targetFn() -> Vector3 цели
-- opts: segments, radius, color, tip, pixel (кубики вместо шаров), seed
function Tentacles.new(parent, baseFn, targetFn, opts)
	opts = opts or {}
	local self = setmetatable({}, Tentacles)
	self.baseFn, self.targetFn = baseFn, targetFn
	self.n = opts.segments or 18
	self.r = opts.radius or 0.35
	self.len = 0          -- 0..1 — насколько вытянулось
	self.goal = 0
	self.speed = 1
	self.t = (opts.seed or 1) * 1.7
	self.wiggle = opts.wiggle or 1
	self.pixel = opts.pixel == true
	self.parts = {}
	self.model = Instance.new("Model")
	self.model.Name = "RM_Tentacle"
	local col = B.color(opts.color or "#3B1F5C")
	local tip = B.color(opts.tip or "#7CFF4A")
	for i = 1, self.n do
		local k = 1 - (i - 1) / self.n
		local d = self.r * 2 * (0.35 + 0.65 * k)
		local c = col:Lerp(tip, (i / self.n) ^ 3)
		local p
		if opts.pixel then
			p = B.part(self.model, "Seg", Vector3.new(d, d, d), CFrame.new(), c, (i > self.n - 2) and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		else
			p = B.ball(self.model, "Seg", d, CFrame.new(), c, (i > self.n - 2) and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		end
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = i % 2 == 0
		p.Transparency = 1
		self.parts[i] = p
	end
	-- присоски: маленькие светлые точки на каждом третьем сегменте
	self.model.Parent = parent or workspace
	self.conn = RunService.RenderStepped:Connect(function(dt) self:update(dt) end)
	return self
end

function Tentacles:grow(to, speed)
	self.goal = to
	self.speed = speed or 1
end

function Tentacles:update(dt)
	if U.paused then return end
	self.t = self.t + dt
	self.len = self.len + (self.goal - self.len) * math.min(1, dt * 2.2 * self.speed)
	local base = self.baseFn()
	local target = self.targetFn()
	local p0 = base.Position
	local toT = target - p0
	local dist = toT.Magnitude
	if dist < 0.01 then return end
	local dir = toT / dist
	-- две оси, перпендикулярные направлению, для извивания
	local side = dir:Cross(Vector3.yAxis)
	if side.Magnitude < 0.1 then side = dir:Cross(Vector3.xAxis) end
	side = side.Unit
	local up = side:Cross(dir).Unit
	local reach = dist * self.len
	-- первая часть растёт из основания вдоль его направления, потом поворачивает к цели
	local look = base.LookVector
	for i, p in ipairs(self.parts) do
		local a = (i - 1) / (self.n - 1)
		local s = a * reach
		local bend = math.min(1, a * 2.2)
		local path = p0 + (look * s):Lerp(dir * s, bend)
		local amp = math.sin(a * math.pi) * 0.9 * self.wiggle * math.min(1, reach / 3)
		local w1 = math.sin(self.t * 3.1 - a * 7) * amp
		local w2 = math.cos(self.t * 2.3 - a * 5) * amp * 0.7
		local pos = path + side * w1 + up * w2
		if self.pixel then
			-- кубики выстроены вдоль щупальца (аккуратная «пиксельная змейка»)
			local prev = self.prevPos and self.prevPos[i - 1]
			if prev and (pos - prev).Magnitude > 1e-3 then p.CFrame = CFrame.lookAt(pos, prev) else p.CFrame = CFrame.new(pos) end
		else
			p.CFrame = CFrame.new(pos) * CFrame.Angles(self.t * 0.5 + i, i * 0.7, 0)
		end
		self.prevPos = self.prevPos or {}
		self.prevPos[i] = pos
		p.Transparency = (self.len < 0.02) and 1 or 0
	end
end

-- точка кончика (куда стрелять)
function Tentacles:tip()
	return self.parts[self.n].Position
end

-- рассыпаться на пиксели (кубики разлетаются и гаснут)
function Tentacles:burst()
	if self.conn then self.conn:Disconnect(); self.conn = nil end
	Audio.play("PixelBurst", { at = self.parts[math.floor(self.n / 2)], volume = 0.9, pitchJitter = 0.1 })
	local bits = {}
	for i, p in ipairs(self.parts) do
		if i % 2 == 1 then
			for k = 1, 2 do
				local c = B.part(self.model, "Pixel", Vector3.new(0.3, 0.3, 0.3), p.CFrame, p.Color, Enum.Material.Neon,
					{ CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
				table.insert(bits, { p = c, v = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5) * 18 })
			end
		end
		p.Transparency = 1
	end
	task.spawn(function()
		local t = 0
		while t < 0.9 do
			local dt = RunService.Heartbeat:Wait()
			t = t + dt
			for _, b in ipairs(bits) do
				b.v = b.v + Vector3.new(0, -30 * dt, 0)
				b.p.CFrame = b.p.CFrame + b.v * dt
				b.p.Transparency = t / 0.9
			end
		end
		self:destroy()
	end)
end

function Tentacles:destroy()
	if self.conn then self.conn:Disconnect(); self.conn = nil end
	if self.model then self.model:Destroy() end
end

return Tentacles
