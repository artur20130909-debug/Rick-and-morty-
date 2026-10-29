
---------------------------------------------------------------------------
-- 11. DataModel, службы, сеть, твины, окружение скриптов, загрузчик,
--     кадр, упрощённая физика, ввод (дописано для cursed-arena)
---------------------------------------------------------------------------
local function part5()
local DATA, defclass, N, coerce, newInstance = mock.DATA, I.defclass, I.N, I.coerce, I.newInstance
local isInst, fullName, eachDesc, getEvent, fireEvent = I.isInst, I.fullName, I.eachDesc, I.getEvent, I.fireEvent
local propChanged, findChild, fireSignal, newSignal = I.propChanged, I.findChild, I.fireSignal, I.newSignal
local destroyInst, classes, checkV3, checkCF = I.destroyInst, mock.classes, I.checkV3, I.checkCF
local setParentRaw, setPartCFrame, cloneInst = I.setParentRaw, I.setPartCFrame, I.cloneInst
local V0 = v3(0, 0, 0)
local WHITE = c3(1, 1, 1)
local BLACK = c3(0, 0, 0)

mock.G = G
local players = {}          -- список Player по порядку входа
mock.players = players
local gameInst, wsInst      -- DataModel, Workspace
local services = {}         -- имя класса -> экземпляр

---------------- создание экземпляров и «репликация» ----------------
-- экземпляр, созданный на клиенте, сервер не видит (как в Roblox)
local function ownerKeyOf(inst)
	local a = inst
	local guard = 0
	while a and guard < 64 do
		local d = a[DATA]
		if d.ownerKey then return d.ownerKey end
		a = d.parent
		guard = guard + 1
	end
	return nil
end
local function visibleTo(inst, ctx)
	local k = ownerKeyOf(inst)
	if not k then return true end
	return ctx.key == k
end
mock.visibleTo = visibleTo

local function markOwner(inst, key)
	inst[DATA].ownerKey = key
end

local InstanceLib = {}
function InstanceLib.new(cname, parent)
	if rawtype(cname) ~= "string" then throw("invalid argument #1 to 'new' (string expected, got " .. typeof(cname) .. ")") end
	local cls = classes[cname]
	if not cls or cls.noCreate or cls.service then
		throw("Unable to create an Instance of type \"" .. cname .. "\"")
	end
	local inst = newInstance(cls)
	local ctx = curCtx()
	if ctx.side == "client" then markOwner(inst, ctx.key) end
	if parent ~= nil then inst.Parent = parent end
	return inst
end
function InstanceLib.fromExisting(x)
	if not isInst(x) then throw("Instance.fromExisting: Instance expected") end
	local c = newInstance(x[DATA].cls)
	for k, v in pairs(x[DATA].p) do c[DATA].p[k] = v end
	return c
end
G.Instance = InstanceLib

-- Clone на клиенте даёт локальную копию
do
	local orig = classes.Instance.methods.Clone
	local function cloneWrapped(self)
		local c = orig(self)
		local ctx = curCtx()
		if c and ctx.side == "client" then markOwner(c, ctx.key) end
		return c
	end
	for _, cls in pairs(classes) do
		if cls.methods.Clone == orig then cls.methods.Clone = cloneWrapped end
		if cls.methods.clone == orig then cls.methods.clone = cloneWrapped end
	end
	classes.Instance.methods.Clone = cloneWrapped
end

---------------- копирование аргументов (сеть и Bindable) ----------------
local function copyVal(v, seen, remote, depth)
	local t = rawtype(v)
	if t == "table" then
		if isInst(v) or isMockObj(v) then return v end
		if seen[v] then
			if remote then suspicious("REMOTE", "циклическая таблица в аргументах удалённого события") end
			return nil
		end
		if depth > 60 then return nil end
		seen[v] = true
		local o = {}
		local hasArr = rawget(v, 1) ~= nil
		local hasDict = false
		for k, x in pairs(v) do
			local kt = rawtype(k)
			if remote then
				if kt == "number" then
					if not hasArr or k ~= floor(k) or k < 1 then hasDict = true end
				elseif kt == "string" then
					hasDict = true
				else
					suspicious("REMOTE", "ключ таблицы типа " .. typeof(k) .. " не передаётся по сети")
				end
			end
			local ck = copyVal(k, seen, remote, depth + 1)
			if ck ~= nil then o[ck] = copyVal(x, seen, remote, depth + 1) end
		end
		if remote and hasArr and hasDict then
			suspicious("REMOTE", "смешанная таблица (массив + словарь) в аргументах удалённого события — часть потеряется")
		end
		if remote and getmetatable(v) ~= nil then suspicious("REMOTE", "метатаблица не передаётся по сети") end
		seen[v] = nil
		return o
	elseif t == "function" or t == "thread" then
		if remote then
			suspicious("REMOTE", "функция/поток в аргументах удалённого события (в Roblox станет nil)")
			return nil
		end
		return v
	end
	return v
end
I.copyArgs = function(remote, ...)
	local n = select("#", ...)
	local out = {}
	for i = 1, n do out[i] = copyVal((select(i, ...)), {}, remote, 0) end
	return tunpack(out, 1, n)
end

---------------- удалённые события ----------------
mock.netDelay = 0
local function deliver(ctx, fn)
	local co = newThread(fn, ctx)
	if mock.netDelay > 0 then
		mock.timer(mock.netDelay, function() resume(co) end)
	else
		deferQ[#deferQ + 1] = { co = co, args = tpack() }
	end
end
mock.remoteStats = { toServer = 0, toClient = 0, bytes = 0 }
local function needPlayer(p, what)
	if not isInst(p) or p[DATA].cls.name ~= "Player" then
		throw(what .. ": Unable to cast value to Object (нужен Player, получено " .. typeof(p) .. ")")
	end
end
local clientOnlyCtx = function(ctx) return function(c) return c == ctx end end
local serverOnly = function(c) return c.side == "server" end
I.remote = {
	FireServer = function(self, ...)
		local ctx = curCtx()
		if ctx.side ~= "client" then throw("FireServer can only be called from the client") end
		local args = tpack(I.copyArgs(true, ...))
		local plr = ctx.player
		local d = self[DATA]
		mock.remoteStats.toServer = mock.remoteStats.toServer + 1
		deliver(SERVER, function()
			if not plr[DATA].parent then return end
			local s = d.sig and d.sig.OnServerEvent
			if s then fireSignal(s, serverOnly, plr, tunpack(args, 1, args.n)) end
		end)
	end,
	FireClient = function(self, plr, ...)
		local ctx = curCtx()
		if ctx.side ~= "server" then throw("FireClient can only be called from the server") end
		needPlayer(plr, "FireClient")
		local args = tpack(I.copyArgs(true, ...))
		local d = self[DATA]
		local cctx = clientCtx(plr)
		mock.remoteStats.toClient = mock.remoteStats.toClient + 1
		deliver(cctx, function()
			if not plr[DATA].parent then return end
			local s = d.sig and d.sig.OnClientEvent
			if s then fireSignal(s, clientOnlyCtx(cctx), tunpack(args, 1, args.n)) end
		end)
	end,
	FireAllClients = function(self, ...)
		local ctx = curCtx()
		if ctx.side ~= "server" then throw("FireAllClients can only be called from the server") end
		for _, plr in ipairs(players) do I.remote.FireClient(self, plr, ...) end
	end,
	InvokeServer = function(self, ...)
		local ctx = curCtx()
		if ctx.side ~= "client" then throw("InvokeServer can only be called from the client") end
		local co, ismain = co_running()
		if ismain then throw("InvokeServer в главном потоке") end
		local args = tpack(I.copyArgs(true, ...))
		local plr = ctx.player
		local d = self[DATA]
		deliver(SERVER, function()
			local tries = 0
			while not d.cbOnServerInvoke and tries < 600 do
				task.wait(0.05)
				tries = tries + 1
			end
			local cb = d.cbOnServerInvoke
			local res
			if not cb then
				res = { false, "OnServerInvoke не задан (" .. fullName(self) .. ")", n = 2 }
			else
				res = tpack(xpcall(cb, debug.traceback, plr, tunpack(args, 1, args.n)))
			end
			deliver(ctx, function() resume(co, res) end)
		end)
		local res = co_yield()
		if not res[1] then throw(tostring_(res[2])) end
		return I.copyArgs(true, tunpack(res, 2, res.n))
	end,
	InvokeClient = function(self, plr, ...)
		local ctx = curCtx()
		if ctx.side ~= "server" then throw("InvokeClient can only be called from the server") end
		needPlayer(plr, "InvokeClient")
		suspicious("REMOTE", "InvokeClient опасен: клиент может не ответить и сервер зависнет")
		local co = co_running()
		local args = tpack(I.copyArgs(true, ...))
		local d = self[DATA]
		local cctx = clientCtx(plr)
		deliver(cctx, function()
			local cb = d.cbOnClientInvoke
			local res = cb and tpack(xpcall(cb, debug.traceback, tunpack(args, 1, args.n))) or { false, "OnClientInvoke не задан", n = 2 }
			deliver(SERVER, function() resume(co, res) end)
		end)
		local res = co_yield()
		if not res[1] then throw(tostring_(res[2])) end
		return tunpack(res, 2, res.n)
	end,
	setCallback = function(self, d, name, f)
		if f ~= nil and rawtype(f) ~= "function" then throw(name .. " must be a function") end
		local ctx = curCtx()
		if name == "OnServerInvoke" and ctx.side ~= "server" then throw("OnServerInvoke can only be set on the server") end
		if name == "OnClientInvoke" and ctx.side ~= "client" then throw("OnClientInvoke can only be set on the client") end
		d["cb" .. name] = f
	end,
}

---------------- плавность (Easing) ----------------
local function easeIn(style, t)
	if style == "Linear" then return t
	elseif style == "Sine" then return 1 - cos(t * pi / 2)
	elseif style == "Quad" then return t * t
	elseif style == "Cubic" then return t * t * t
	elseif style == "Quart" then return t * t * t * t
	elseif style == "Quint" then return t * t * t * t * t
	elseif style == "Exponential" then return t == 0 and 0 or 2 ^ (10 * t - 10)
	elseif style == "Circular" then return 1 - sqrt(mmax(0, 1 - t * t))
	elseif style == "Back" then
		local c1 = 1.70158
		return (c1 + 1) * t * t * t - c1 * t * t
	elseif style == "Elastic" then
		if t == 0 or t == 1 then return t end
		local c4 = (2 * pi) / 3
		return -(2 ^ (10 * t - 10)) * sin((t * 10 - 10.75) * c4)
	elseif style == "Bounce" then
		local function out(x)
			local n1, d1 = 7.5625, 2.75
			if x < 1 / d1 then return n1 * x * x
			elseif x < 2 / d1 then x = x - 1.5 / d1; return n1 * x * x + 0.75
			elseif x < 2.5 / d1 then x = x - 2.25 / d1; return n1 * x * x + 0.9375 end
			x = x - 2.625 / d1
			return n1 * x * x + 0.984375
		end
		return 1 - out(1 - t)
	end
	return t
end
local function ease(style, dir, t)
	if t <= 0 then return 0 end
	if t >= 1 then return 1 end
	if dir == "In" then return easeIn(style, t)
	elseif dir == "Out" then return 1 - easeIn(style, 1 - t)
	end
	if t < 0.5 then return easeIn(style, t * 2) / 2 end
	return 1 - easeIn(style, (1 - t) * 2) / 2
end
mock.ease = ease

---------------- твины ----------------
local tweens = {}       -- активные
local tweenOwner = {}   -- inst -> { prop -> tween }
local function lerpVal(a, b, t, prop)
	local ta = typeof(a)
	if ta ~= typeof(b) then throw("TweenService:Create property " .. prop .. " type mismatch: " .. ta .. " vs " .. typeof(b)) end
	if ta == "number" then return a + (b - a) * t end
	if ta == "Vector3" or ta == "Vector2" or ta == "CFrame" or ta == "Color3" or ta == "UDim2" then return a:Lerp(b, t) end
	if ta == "UDim" then return UDim.new(a.Scale + (b.Scale - a.Scale) * t, a.Offset + (b.Offset - a.Offset) * t) end
	if ta == "boolean" then return t >= 1 and b or a end
	if ta == "NumberRange" then return NumberRange.new(a.Min + (b.Min - a.Min) * t, a.Max + (b.Max - a.Max) * t) end
	if ta == "Rect" then return Rect.new(a.Min:Lerp(b.Min, t), a.Max:Lerp(b.Max, t)) end
	throw("TweenService: property " .. prop .. " of type " .. ta .. " cannot be tweened")
end
local function tweenStep(tw, now)
	local td = tw[DATA]
	local s = td.tw
	if s.state ~= "Playing" then return false end
	local inst = s.inst
	if inst[DATA].destroyed then
		s.state = "Cancelled"
		td.p.PlaybackState = E("PlaybackState", "Cancelled")
		return false
	end
	local info = s.info
	local T = mmax(info.Time, 1e-6)
	local el = now - s.t0 - info.DelayTime
	if el < 0 then return true end
	local cycle = el / T
	local reps = info.RepeatCount
	local per = info.Reverses and 2 or 1
	local total = (reps < 0) and huge or (reps + 1) * per
	local done = cycle >= total
	local k
	if done then
		k = info.Reverses and 0 or 1
	else
		local c = floor(cycle)
		local f = cycle - c
		if info.Reverses and c % 2 == 1 then f = 1 - f end
		k = f
	end
	local a = ease(info.EasingStyle.Name, info.EasingDirection.Name, k)
	for prop, goal in pairs(s.goals) do
		local own = tweenOwner[inst]
		if own and own[prop] == tw then
			local ok, err = pcall(function() inst[prop] = lerpVal(s.start[prop], goal, a, prop) end)
			if not ok then recordError(err, err, s.ctx) end
		end
	end
	if done then
		s.state = "Completed"
		td.p.PlaybackState = E("PlaybackState", "Completed")
		local own = tweenOwner[inst]
		if own then for prop in pairs(s.goals) do if own[prop] == tw then own[prop] = nil end end end
		fireEvent(td, "Completed", E("PlaybackState", "Completed"))
		if s.cb then
			local cb = s.cb
			resume(newThread(function() cb(E("PlaybackState", "Completed")) end, s.ctx))
		end
		return false
	end
	return true
end
local function stepTweens()
	local now = mock.now
	local keep = {}
	local list = tweens
	tweens = {}
	for _, tw in ipairs(list) do
		if tweenStep(tw, now) then keep[#keep + 1] = tw end
	end
	for _, tw in ipairs(tweens) do keep[#keep + 1] = tw end
	tweens = keep
end
mock.activeTweens = function() return #tweens end

defclass("TweenBase", "Instance", { props = { PlaybackState = E("PlaybackState", "Begin") }, events = { "Completed" }, noCreate = true })
defclass("Tween", "TweenBase", {
	props = { Instance = N "Instance", TweenInfo = N "nilable" },
	methods = {
		Play = function(self)
			local d = self[DATA]
			local s = d.tw
			if s.state == "Playing" then return end
			local inst = s.inst
			if s.state ~= "Paused" then
				s.start = {}
				for prop in pairs(s.goals) do s.start[prop] = inst[prop] end
				s.t0 = mock.now
			else
				s.t0 = mock.now - (s.pausedAt - s.t0)
			end
			local own = tweenOwner[inst]
			if not own then
				own = setmt({}, { __mode = "v" })
				tweenOwner[inst] = own
			end
			for prop in pairs(s.goals) do
				local prev = own[prop]
				if prev and prev ~= self then
					local pd = prev[DATA]
					local still = false
					for p2 in pairs(pd.tw.goals) do if p2 ~= prop and own[p2] == prev then still = true end end
					if not still and pd.tw.state == "Playing" then
						pd.tw.state = "Cancelled"
						pd.p.PlaybackState = E("PlaybackState", "Cancelled")
						fireEvent(pd, "Completed", E("PlaybackState", "Cancelled"))
					end
				end
				own[prop] = self
			end
			s.state = "Playing"
			d.p.PlaybackState = E("PlaybackState", "Playing")
			tweens[#tweens + 1] = self
			tweenStep(self, mock.now)
		end,
		Pause = function(self)
			local s = self[DATA].tw
			if s.state == "Playing" then
				s.state = "Paused"
				s.pausedAt = mock.now
				self[DATA].p.PlaybackState = E("PlaybackState", "Paused")
			end
		end,
		Cancel = function(self)
			local d = self[DATA]
			local s = d.tw
			if s.state == "Playing" or s.state == "Paused" then
				s.state = "Cancelled"
				d.p.PlaybackState = E("PlaybackState", "Cancelled")
				fireEvent(d, "Completed", E("PlaybackState", "Cancelled"))
			end
		end,
	},
	noCreate = true,
})
local function createTween(inst, info, goals, cb)
	if not isInst(inst) then throw("TweenService:Create: Instance expected, got " .. typeof(inst)) end
	if typeof(info) ~= "TweenInfo" then throw("TweenService:Create: TweenInfo expected, got " .. typeof(info)) end
	if rawtype(goals) ~= "table" or isMockObj(goals) then throw("TweenService:Create: table of properties expected") end
	local cls = inst[DATA].cls
	for prop, goal in pairs(goals) do
		if rawtype(prop) ~= "string" then throw("TweenService:Create: property name must be a string") end
		if not I.isKnownProp(cls, prop) then throw("TweenService:Create: no property named '" .. prop .. "' for object '" .. inst[DATA].p.Name .. "' (" .. cls.name .. ")") end
		local cur = inst[prop]
		if cur ~= nil and typeof(cur) ~= typeof(goal) then
			throw("TweenService:Create property named '" .. prop .. "' cannot be tweened due to type mismatch (property is a '" .. typeof(cur) .. "', but given type is '" .. typeof(goal) .. "')")
		end
		if typeof(goal) == "EnumItem" or typeof(goal) == "string" or typeof(goal) == "Instance" then
			throw("TweenService:Create: property " .. prop .. " (" .. typeof(goal) .. ") cannot be tweened")
		end
	end
	local tw = newInstance(classes.Tween)
	local td = tw[DATA]
	td.p.Instance = inst
	td.p.TweenInfo = info
	local g = {}
	for k, v in pairs(goals) do g[k] = v end
	td.tw = { inst = inst, info = info, goals = g, state = "Begin", ctx = curCtx(), cb = cb }
	return tw
end
I.guiTween = function(self, props, info, override, cb)
	local own = tweenOwner[self]
	if own and not override then
		for prop in pairs(props) do if own[prop] and own[prop][DATA].tw.state == "Playing" then return false end end
	end
	local tw = createTween(self, info, props, cb)
	tw:Play()
	return true
end

---------------- службы ----------------
local function service(name, base, spec)
	spec = spec or {}
	spec.service = true
	defclass(name, base or "Instance", spec)
end

local serverOnlyServices = { ServerScriptService = true, ServerStorage = true }

local function getService(name)
	if rawtype(name) ~= "string" then throw("GetService: string expected") end
	local s = services[name]
	if s then return s end
	local cls = classes[name]
	if not cls or not cls.service then throw("'" .. name .. "' is not a valid Service name") end
	s = newInstance(cls)
	s[DATA].p.Name = name
	if serverOnlyServices[name] then s[DATA].serverOnly = true end
	services[name] = s
	if gameInst then setParentRaw(s, s[DATA], gameInst) end
	if cls.onCreate then cls.onCreate(s, s[DATA]) end
	return s
end
mock.getService = getService

defclass("DataModel", "Instance", {
	props = { PlaceId = 0, GameId = 0, JobId = "00000000-mock-job", CreatorId = 0, PlaceVersion = 1, PrivateServerId = "",
		PrivateServerOwnerId = 0, Genre = E("Genre", "All"), CreatorType = E("CreatorType", "User") },
	get = { Workspace = function() return wsInst end, workspace = function() return wsInst end },
	methods = {
		GetService = function(self, name) return getService(name) end,
		FindService = function(self, name) return services[name] end,
		IsLoaded = function() return true end,
		BindToClose = function(self, fn)
			if rawtype(fn) ~= "function" then throw("BindToClose: function expected") end
			mock.closeHandlers = mock.closeHandlers or {}
			mock.closeHandlers[#mock.closeHandlers + 1] = { fn = fn, ctx = curCtx() }
		end,
		GetJobsInfo = function() return {} end,
		Shutdown = function() end,
		SetPlaceId = function() end,
		SetUniverseId = function() end,
	},
	events = { "Loaded", "Close", "ServiceAdded", "ServiceRemoving", "GraphicsQualityChangeRequest" },
	noCreate = true,
})

---------------- Workspace и запросы пространства ----------------
local cameras = {}
local function ctxCamera(ctx)
	local c = cameras[ctx.key]
	if c and not c[DATA].destroyed then return c end
	c = newInstance(classes.Camera)
	c[DATA].p.Name = "Camera"
	if ctx.side == "client" then
		markOwner(c, ctx.key)
	elseif wsInst then
		setParentRaw(c, c[DATA], wsInst)
	end
	cameras[ctx.key] = c
	return c
end
mock.cameraOf = function(plr) return ctxCamera(clientCtx(plr)) end

-- OBB vs OBB (SAT)
local function obbOverlap(cfA, sA, cfB, sB)
	local ax = { cfA[1], cfA[4], cfA[7] }
	local ay = { cfA[2], cfA[5], cfA[8] }
	local az = { cfA[3], cfA[6], cfA[9] }
	local bx = { cfB[1], cfB[4], cfB[7] }
	local by = { cfB[2], cfB[5], cfB[8] }
	local bz = { cfB[3], cfB[6], cfB[9] }
	local A = { ax, ay, az }
	local B = { bx, by, bz }
	local ea = { sA.X / 2, sA.Y / 2, sA.Z / 2 }
	local eb = { sB.X / 2, sB.Y / 2, sB.Z / 2 }
	local t = { cfB.X - cfA.X, cfB.Y - cfA.Y, cfB.Z - cfA.Z }
	local function dot(u, v) return u[1] * v[1] + u[2] * v[2] + u[3] * v[3] end
	local R, AR = {}, {}
	for i = 1, 3 do
		R[i], AR[i] = {}, {}
		for j = 1, 3 do
			R[i][j] = dot(A[i], B[j])
			AR[i][j] = abs(R[i][j]) + 1e-6
		end
	end
	local tl = { dot(t, ax), dot(t, ay), dot(t, az) }
	for i = 1, 3 do
		local ra = ea[i]
		local rb = eb[1] * AR[i][1] + eb[2] * AR[i][2] + eb[3] * AR[i][3]
		if abs(tl[i]) > ra + rb then return false end
	end
	for j = 1, 3 do
		local ra = ea[1] * AR[1][j] + ea[2] * AR[2][j] + ea[3] * AR[3][j]
		local rb = eb[j]
		local tp = tl[1] * R[1][j] + tl[2] * R[2][j] + tl[3] * R[3][j]
		if abs(tp) > ra + rb then return false end
	end
	for i = 1, 3 do
		for j = 1, 3 do
			local i1, i2 = (i % 3) + 1, ((i + 1) % 3) + 1
			local j1, j2 = (j % 3) + 1, ((j + 1) % 3) + 1
			local ra = ea[i1] * AR[i2][j] + ea[i2] * AR[i1][j]
			local rb = eb[j1] * AR[i][j2] + eb[j2] * AR[i][j1]
			local tp = abs(tl[i2] * R[i1][j] - tl[i1] * R[i2][j])
			if tp > ra + rb then return false end
		end
	end
	return true
end
mock.obbOverlap = obbOverlap

local function sphereOBB(px, py, pz, r, cf, s)
	local lx, ly, lz = cfpointInv(cf, px, py, pz)
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	local cx = mmax(-hx, mmin(hx, lx))
	local cy = mmax(-hy, mmin(hy, ly))
	local cz = mmax(-hz, mmin(hz, lz))
	local dx, dy, dz = lx - cx, ly - cy, lz - cz
	return dx * dx + dy * dy + dz * dz <= r * r
end

local function filterVisible(list)
	local ctx = curCtx()
	local out = {}
	for _, p in ipairs(list) do
		if visibleTo(p, ctx) then out[#out + 1] = p end
	end
	return out
end

local function raycastVisible(origin, dir, params)
	local ctx = curCtx()
	local res = I.raycast(origin, dir, params)
	local guard = 0
	local extra
	while res and not visibleTo(res.Instance, ctx) and guard < 12 do
		guard = guard + 1
		extra = extra or {}
		extra[#extra + 1] = res.Instance
		local fd = params and paramsData(params)
		local np = RaycastParams.new()
		local list = {}
		local include = fd and fd.FilterType == E("RaycastFilterType", "Include")
		if fd then
			for _, x in ipairs(fd.FilterDescendantsInstances) do list[#list + 1] = x end
			np.RespectCanCollide = fd.RespectCanCollide
			np.IgnoreWater = fd.IgnoreWater
		end
		if include then
			-- в Include-режиме видимость не меняем: клиентская деталь попала в список явно
			return res
		end
		for _, x in ipairs(extra) do list[#list + 1] = x end
		np.FilterType = E("RaycastFilterType", "Exclude")
		np.FilterDescendantsInstances = list
		res = I.raycast(origin, dir, np)
	end
	return res
end

local worldMethods = {
	Raycast = function(self, origin, dir, params)
		checkV3(origin, "Raycast origin")
		checkV3(dir, "Raycast direction")
		if params ~= nil and typeof(params) ~= "RaycastParams" then throw("Raycast: RaycastParams expected, got " .. typeof(params)) end
		I.solveDirtyJoints()
		return raycastVisible(origin, dir, params)
	end,
	GetPartBoundsInBox = function(self, cf, size, params)
		cf = checkCF(cf, "GetPartBoundsInBox")
		size = checkV3(size, "GetPartBoundsInBox")
		if params ~= nil and typeof(params) ~= "OverlapParams" then throw("GetPartBoundsInBox: OverlapParams expected, got " .. typeof(params)) end
		I.solveDirtyJoints()
		local x0, y0, z0, x1, y1, z1 = I.boxAABB(cf, size)
		return filterVisible(I.queryAABB(x0, y0, z0, x1, y1, z1, params, function(part, d)
			return obbOverlap(cf, size, d.p.CFrame, d.p.Size)
		end))
	end,
	GetPartBoundsInRadius = function(self, pos, r, params)
		pos = checkV3(pos, "GetPartBoundsInRadius")
		if rawtype(r) ~= "number" then throw("GetPartBoundsInRadius: radius must be a number") end
		if params ~= nil and typeof(params) ~= "OverlapParams" then throw("GetPartBoundsInRadius: OverlapParams expected, got " .. typeof(params)) end
		I.solveDirtyJoints()
		return filterVisible(I.queryAABB(pos.X - r, pos.Y - r, pos.Z - r, pos.X + r, pos.Y + r, pos.Z + r, params, function(part, d)
			return sphereOBB(pos.X, pos.Y, pos.Z, r, d.p.CFrame, d.p.Size)
		end))
	end,
	GetPartsInPart = function(self, part, params)
		if not isInst(part) or not part[DATA].cls.isa.BasePart then throw("GetPartsInPart: BasePart expected") end
		I.solveDirtyJoints()
		local pd = part[DATA]
		local cf, size = pd.p.CFrame, pd.p.Size
		local x0, y0, z0, x1, y1, z1 = I.boxAABB(cf, size)
		return filterVisible(I.queryAABB(x0, y0, z0, x1, y1, z1, params, function(p2, d)
			return p2 ~= part and obbOverlap(cf, size, d.p.CFrame, d.p.Size)
		end))
	end,
	Spherecast = function(self, pos, r, dir, params)
		checkV3(pos, "Spherecast")
		checkV3(dir, "Spherecast")
		I.solveDirtyJoints()
		return raycastVisible(pos, dir, params)
	end,
	Blockcast = function(self, cf, size, dir, params)
		cf = checkCF(cf, "Blockcast")
		checkV3(dir, "Blockcast")
		I.solveDirtyJoints()
		return raycastVisible(CFget.Position(cf), dir, params)
	end,
	Shapecast = function(self, part, dir, params)
		I.solveDirtyJoints()
		return raycastVisible(part.Position, dir, params)
	end,
	FindPartOnRay = function(self, ray, ignore)
		suspicious("DEPRECATED", "FindPartOnRay устарел — используйте workspace:Raycast")
		local p = RaycastParams.new()
		if ignore then p.FilterDescendantsInstances = { ignore } end
		local r = raycastVisible(ray.Origin, ray.Direction, p)
		if r then return r.Instance, r.Position, r.Normal, r.Material end
		return nil, ray.Origin + ray.Direction, V0, E("Material", "Air")
	end,
	FindPartsInRegion3 = function(self, region, ignore, maxParts)
		suspicious("DEPRECATED", "FindPartsInRegion3 устарел — используйте GetPartBoundsInBox")
		local mn, mx = region.Min, region.Max
		local list = I.queryAABB(mn.X, mn.Y, mn.Z, mx.X, mx.Y, mx.Z, nil)
		return filterVisible(list)
	end,
	GetServerTimeNow = function() return mock.epoch + mock.now end,
	BulkMoveTo = function(self, parts, cfs, mode)
		if rawtype(parts) ~= "table" or rawtype(cfs) ~= "table" then throw("BulkMoveTo: tables expected") end
		if #parts ~= #cfs then throw("BulkMoveTo: parts and cframes must be the same length") end
		for i, p in ipairs(parts) do
			if not isInst(p) or not p[DATA].cls.isa.BasePart then throw("BulkMoveTo: element " .. i .. " is not a BasePart") end
			p.CFrame = cfs[i]
		end
	end,
	ArePartsTouchingOthers = function() return false end,
	GetRealPhysicsFPS = function() return 60 end,
	GetNumAwakeParts = function() return 0 end,
	GetPhysicsThrottling = function() return 100 end,
	IKMoveTo = function(self, part, cf) part.CFrame = cf end,
	JoinToOutsiders = function() end,
	UnjoinFromOutsiders = function() end,
	PGSIsEnabled = function() return true end,
	SetInsertPoint = function() end,
	ZoomToExtents = function() end,
	CalculateJumpPower = function(self, g, h) return sqrt(2 * g * h) end,
}
for k, f in pairs(worldMethods) do classes.WorldRoot.methods[k] = f; classes.WorldModel.methods[k] = f end

service("Workspace", "WorldRoot", {
	props = { Gravity = 196.2, FallenPartsDestroyHeight = -500, StreamingEnabled = false, AllowThirdPartySales = false,
		AirDensity = 0.0012, GlobalWind = V0, TouchesUseCollisionGroups = false, StreamingMinRadius = 64, StreamingTargetRadius = 1024,
		ClientAnimatorThrottling = E("ClientAnimatorThrottlingMode", "Default"), SignalBehavior = E("SignalBehavior", "Default"),
		PhysicsSteppingMethod = E("PhysicsSteppingMethod", "Default"), RejectCharacterDeletions = E("RejectCharacterDeletions", "Default") },
	get = {
		CurrentCamera = function() return ctxCamera(curCtx()) end,
		DistributedGameTime = function() return mock.now end,
		Terrain = function(self, d) return findChild(d, "Terrain") end,
	},
	set = {
		CurrentCamera = function(self, d, v)
			if v ~= nil and (not isInst(v) or v[DATA].cls.name ~= "Camera") then throw("Unable to assign property CurrentCamera. Camera expected") end
			cameras[curCtx().key] = v
		end,
	},
	methods = worldMethods,
})
for k, f in pairs(worldMethods) do classes.Workspace.methods[k] = f end

-- Terrain: заливки превращаем в невидимые «опоры», чтобы лучи и персонажи стояли на них
defclass("Terrain", "BasePart", {
	props = { WaterColor = c3(0.05, 0.33, 0.36), WaterReflectance = 1, WaterTransparency = 0.3, WaterWaveSize = 0.15,
		WaterWaveSpeed = 10, Decoration = false, GrassLength = 0.7, MaterialColors = "" },
	get = { MaxExtents = function() return Region3.new(v3(-1e5, -1e5, -1e5), v3(1e5, 1e5, 1e5)) end },
	methods = {
		FillBlock = function(self, cf, size, mat)
			cf = checkCF(cf, "FillBlock")
			size = checkV3(size, "FillBlock")
			if typeof(mat) ~= "EnumItem" then throw("FillBlock: Enum.Material expected") end
			if mat.Name == "Air" then return end
			local p = newInstance(classes.Part)
			p[DATA].p.Name = "TerrainFill"
			p[DATA].p.Anchored = true
			p[DATA].p.Transparency = 1
			p[DATA].p.CFrame = cf
			p[DATA].p.Size = size
			p[DATA].p.Material = mat
			p[DATA].p.CanCollide = mat.Name ~= "Water"
			p[DATA].terrainFill = true
			setParentRaw(p, p[DATA], self)
		end,
		FillBall = function(self, pos, r, mat)
			classes.Terrain.methods.FillBlock(self, CFrame.new(pos), v3(r * 1.6, r * 1.6, r * 1.6), mat)
		end,
		FillCylinder = function(self, cf, h, r, mat)
			classes.Terrain.methods.FillBlock(self, cf, v3(r * 1.8, h, r * 1.8), mat)
		end,
		FillWedge = function(self, cf, size, mat) classes.Terrain.methods.FillBlock(self, cf, size, mat) end,
		FillRegion = function(self, region, res, mat) classes.Terrain.methods.FillBlock(self, region.CFrame, region.Size, mat) end,
		Clear = function(self) self:ClearAllChildren() end,
		ReadVoxels = function() return {}, {} end,
		WriteVoxels = function() end,
		ReplaceMaterial = function() end,
		GetMaterialColor = function() return c3(0.4, 0.6, 0.3) end,
		SetMaterialColor = function() end,
		CellCenterToWorld = function(self, x, y, z) return v3(x * 4 + 2, y * 4 + 2, z * 4 + 2) end,
		WorldToCell = function(self, p) return v3(floor(p.X / 4), floor(p.Y / 4), floor(p.Z / 4)) end,
		WorldToCellPreferSolid = function(self, p) return v3(floor(p.X / 4), floor(p.Y / 4), floor(p.Z / 4)) end,
		CopyRegion = function() return nil end,
		PasteRegion = function() end,
	},
	noCreate = true,
})

---------------- Players / Player ----------------
local function playerByChar(model)
	for _, p in ipairs(players) do if p[DATA].p.Character == model then return p end end
	return nil
end

local mouseClass = defclass("PlayerMouse", "Instance", {
	props = { Icon = "", TargetFilter = N "Instance" },
	get = {
		Hit = function(self, d) return mock.mouseHit(d.player).cf end,
		Target = function(self, d) return mock.mouseHit(d.player).part end,
		Origin = function(self, d) return ctxCamera(clientCtx(d.player))[DATA].p.CFrame end,
		UnitRay = function(self, d) return mock.mouseHit(d.player).ray end,
		X = function(self, d) return mock.inputOf(d.player).mouse.X end,
		Y = function(self, d) return mock.inputOf(d.player).mouse.Y end,
		ViewSizeX = function() return mock.viewport.w end,
		ViewSizeY = function() return mock.viewport.h end,
		TargetSurface = function() return E("NormalId", "Top") end,
		hit = function(self, d) return mock.mouseHit(d.player).cf end,
	},
	events = { "Button1Down", "Button1Up", "Button2Down", "Button2Up", "Move", "WheelForward", "WheelBackward", "Idle", "KeyDown", "KeyUp" },
	noCreate = true,
})

local function buildDefaultRig()
	-- обычный R6-манекен (если в StarterPlayer нет StarterCharacter)
	local m = newInstance(classes.Model)
	local function part(name, size, cf)
		local p = newInstance(classes.Part)
		p[DATA].p.Name = name
		p[DATA].p.Size = size
		p[DATA].p.CFrame = cf
		p[DATA].p.CanCollide = name == "Torso" or name == "Head"
		setParentRaw(p, p[DATA], m)
		return p
	end
	local hrp = part("HumanoidRootPart", v3(2, 2, 1), CFrame.new(0, 3, 0))
	hrp[DATA].p.Transparency = 1
	local torso = part("Torso", v3(2, 2, 1), CFrame.new(0, 3, 0))
	local head = part("Head", v3(2, 1, 1), CFrame.new(0, 4.5, 0))
	local la = part("Left Arm", v3(1, 2, 1), CFrame.new(-1.5, 3, 0))
	local ra = part("Right Arm", v3(1, 2, 1), CFrame.new(1.5, 3, 0))
	local ll = part("Left Leg", v3(1, 2, 1), CFrame.new(-0.5, 1, 0))
	local rl = part("Right Leg", v3(1, 2, 1), CFrame.new(0.5, 1, 0))
	local function motor(name, p0, p1, c0, c1)
		local j = newInstance(classes.Motor6D)
		j[DATA].p.Name = name
		j.C0 = c0
		j.C1 = c1
		j.Part0 = p0
		j.Part1 = p1
		setParentRaw(j, j[DATA], p0)
	end
	motor("RootJoint", hrp, torso, CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Neck", torso, head, CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Right Shoulder", torso, ra, CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Shoulder", torso, la, CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	motor("Right Hip", torso, rl, CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Hip", torso, ll, CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	local hum = newInstance(classes.Humanoid)
	setParentRaw(hum, hum[DATA], m)
	m[DATA].p.PrimaryPart = hrp
	return m
end
mock.buildDefaultRig = buildDefaultRig

local runScriptsIn -- объявлено ниже

local function pickSpawn()
	local list = {}
	if wsInst then
		eachDesc(wsInst, function(x)
			local xd = x[DATA]
			if xd.cls.name == "SpawnLocation" and xd.p.Enabled ~= false then list[#list + 1] = x end
		end)
	end
	if #list == 0 then return CFrame.new(0, 5, 0) end
	local sp = list[(mock.spawnPick or 0) % #list + 1]
	mock.spawnPick = (mock.spawnPick or 0) + 1
	local sd = sp[DATA]
	return CFrame.new(CFget.Position(sd.p.CFrame) + v3(0, sd.p.Size.Y / 2 + 3, 0))
end

local function resetPlayerGui(plr)
	local pd = plr[DATA]
	local pg = findChild(pd, "PlayerGui")
	if not pg then return end
	local sg = services.StarterGui
	-- удалить старые ScreenGui с ResetOnSpawn
	for _, c in ipairs(pg:GetChildren()) do
		local cd = c[DATA]
		if cd.cls.isa.LayerCollector and cd.p.ResetOnSpawn ~= false and cd.fromStarter then destroyInst(c, cd) end
	end
	if sg then
		for _, c in ipairs(sg:GetChildren()) do
			local cd = c[DATA]
			local need = true
			if cd.cls.isa.LayerCollector and cd.p.ResetOnSpawn == false then
				if pd.guiCopied and pd.guiCopied[c] then need = false end
			end
			if need then
				local copy = cloneInst(c)
				if copy then
					copy[DATA].fromStarter = true
					pd.guiCopied = pd.guiCopied or {}
					pd.guiCopied[c] = true
					setParentRaw(copy, copy[DATA], pg)
					runScriptsIn(copy, plr)
				end
			end
		end
	end
end

local function loadCharacter(plr)
	local pd = plr[DATA]
	local old = pd.p.Character
	if old then
		fireEvent(pd, "CharacterRemoving", old)
		destroyInst(old, old[DATA])
	end
	local sp = services.StarterPlayer
	local tmpl = sp and findChild(sp[DATA], "StarterCharacter")
	local char
	if tmpl then char = cloneInst(tmpl) else char = buildDefaultRig() end
	char[DATA].p.Name = pd.p.Name
	local hum = char:FindFirstChildOfClass("Humanoid")
	if sp and hum then
		local sd = sp[DATA].p
		hum[DATA].p.WalkSpeed = sd.CharacterWalkSpeed or 16
		hum[DATA].p.JumpHeight = sd.CharacterJumpHeight or 7.2
		hum[DATA].p.JumpPower = sd.CharacterJumpPower or 50
		hum[DATA].p.UseJumpPower = sd.CharacterUseJumpPower or false
	end
	local scs = sp and findChild(sp[DATA], "StarterCharacterScripts")
	if scs then
		for _, c in ipairs(scs:GetChildren()) do
			local ex = findChild(char[DATA], c[DATA].p.Name)
			if ex then destroyInst(ex, ex[DATA]) end
			local copy = cloneInst(c)
			if copy then setParentRaw(copy, copy[DATA], char) end
		end
	end
	local cf = pickSpawn()
	if pd.p.RespawnLocation then
		local rl = pd.p.RespawnLocation[DATA]
		cf = CFrame.new(CFget.Position(rl.p.CFrame) + v3(0, rl.p.Size.Y / 2 + 3, 0))
	end
	char:PivotTo(cf)
	setParentRaw(char, char[DATA], wsInst)
	pd.p.Character = char
	if pd.sig then propChanged(plr, pd, "Character") end
	local cam = ctxCamera(clientCtx(plr))
	cam[DATA].p.CameraSubject = hum
	resetPlayerGui(plr)
	fireEvent(pd, "CharacterAdded", char)
	runScriptsIn(char, plr)
	fireEvent(pd, "CharacterAppearanceLoaded", char)
	return char
end
mock.loadCharacter = loadCharacter

I.onHumanoidDied = function(hum)
	local hd = hum[DATA]
	local m = hd.parent
	if not m then return end
	if hd.p.BreakJointsOnDeath then
		eachDesc(m, function(x)
			local xd = x[DATA]
			if xd.cls.isa.JointInstance or xd.cls.isa.WeldConstraint then
				if not xd.destroyed then destroyInst(x, xd) end
			end
		end)
	end
	local plr = playerByChar(m)
	local ps = services.Players
	if plr and ps and ps[DATA].p.CharacterAutoLoads then
		mock.timer(ps[DATA].p.RespawnTime or 5, function()
			if plr[DATA].parent and plr[DATA].p.Character == m then
				local co = newThread(function() loadCharacter(plr) end, SERVER)
				resume(co)
			end
		end)
	end
end

defclass("Player", "Instance", {
	props = { UserId = 0, DisplayName = "", AccountAge = 365, Character = N "Instance:Model", RespawnLocation = N "Instance:SpawnLocation",
		Team = N "Instance:Team", TeamColor = BrickColor.new("White"), Neutral = true, CameraMaxZoomDistance = 128, CameraMinZoomDistance = 0.5,
		CameraMode = E("CameraMode", "Classic"), DevEnableMouseLock = true, AutoJumpEnabled = true, HealthDisplayDistance = 100,
		NameDisplayDistance = 100, CanLoadCharacterAppearance = true, CharacterAppearanceId = 0, LocaleId = "ru-ru",
		MembershipType = E("MembershipType", "None"), ReplicationFocus = N "Instance", GameplayPaused = false,
		DevComputerMovementMode = E("DevComputerMovementMode", "UserChoice"), DevTouchMovementMode = E("DevTouchMovementMode", "UserChoice"),
		DevCameraOcclusionMode = E("DevCameraOcclusionMode", "Zoom") },
	methods = {
		LoadCharacter = function(self)
			if curCtx().side ~= "server" then throw("LoadCharacter can only be called by the backend server") end
			loadCharacter(self)
		end,
		LoadCharacterAsync = function(self) loadCharacter(self) end,
		LoadCharacterWithHumanoidDescription = function(self, desc) loadCharacter(self) end,
		Kick = function(self, msg) mock.emit("print", "Kick " .. tostring_(self[DATA].p.Name) .. ": " .. tostring_(msg)); mock.removePlayer(self) end,
		GetMouse = function(self)
			local d = self[DATA]
			if not d.mouse then
				d.mouse = newInstance(classes.PlayerMouse)
				d.mouse[DATA].player = self
			end
			return d.mouse
		end,
		GetNetworkPing = function() return 0.05 end,
		HasAppearanceLoaded = function() return true end,
		ClearCharacterAppearance = function() end,
		DistanceFromCharacter = function(self, p)
			local ch = self[DATA].p.Character
			local r = ch and findChild(ch[DATA], "HumanoidRootPart")
			if not r then return 0 end
			return (CFget.Position(r[DATA].p.CFrame) - p).Magnitude
		end,
		GetFriendsOnline = function() return {} end,
		IsFriendsWith = function() return false end,
		GetRankInGroup = function() return 0 end,
		GetRoleInGroup = function() return "Guest" end,
		IsInGroup = function() return false end,
		Move = function(self, dir, rel)
			local ch = self[DATA].p.Character
			local h = ch and ch:FindFirstChildOfClass("Humanoid")
			if h then h:Move(dir, rel) end
		end,
		SetSuperSafeChat = function() end,
		GetJoinData = function() return {} end,
	},
	events = { "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "Chatted", "Idled", "OnTeleport" },
	noCreate = true,
})

defclass("BasePlayerGui", "Instance", { noCreate = true, methods = { GetGuiObjectsAtPosition = function() return {} end } })
defclass("PlayerGui", "BasePlayerGui", { props = { ScreenOrientation = E("ScreenOrientation", "LandscapeSensor"),
	SelectionImageObject = N "Instance" }, get = { CurrentScreenOrientation = function() return E("ScreenOrientation", "LandscapeRight") end },
	methods = { SetTopbarTransparency = function() end, GetTopbarTransparency = function() return 0.5 end }, noCreate = true })
defclass("Backpack", "Instance")
defclass("PlayerScripts", "Instance", { noCreate = true })
defclass("StarterGear", "Instance")

service("Players", "Instance", {
	props = { CharacterAutoLoads = true, MaxPlayers = 12, RespawnTime = 5, BubbleChat = false, ClassicChat = true,
		PreferredPlayers = 12, UseStrafingAnimations = false, BanningEnabled = true },
	get = {
		LocalPlayer = function() local c = curCtx() if c.side == "client" then return c.player end return nil end,
		NumPlayers = function() return #players end,
		localPlayer = function() local c = curCtx() if c.side == "client" then return c.player end return nil end,
	},
	methods = {
		GetPlayers = function() local o = {} for i, p in ipairs(players) do o[i] = p end return o end,
		GetPlayerFromCharacter = function(self, m)
			if m == nil then return nil end
			return playerByChar(m)
		end,
		GetPlayerByUserId = function(self, id) for _, p in ipairs(players) do if p[DATA].p.UserId == id then return p end end return nil end,
		GetHumanoidDescriptionFromUserId = function(self, id)
			if rawtype(id) ~= "number" then throw("GetHumanoidDescriptionFromUserId: number expected") end
			if id <= 0 then throw("HTTP 400 (Bad Request): userId must be positive") end
			return newInstance(classes.HumanoidDescription)
		end,
		GetHumanoidDescriptionFromOutfitId = function() return newInstance(classes.HumanoidDescription) end,
		GetCharacterAppearanceInfoAsync = function() return { assets = {}, bodyColors = {} } end,
		GetNameFromUserIdAsync = function(self, id) return "User" .. tostring_(id) end,
		GetUserIdFromNameAsync = function() return 1 end,
		GetUserThumbnailAsync = function(self, id) return "rbxthumb://type=AvatarHeadShot&id=" .. tostring_(id) .. "&w=150&h=150", true end,
		CreateHumanoidModelFromDescription = function(self, desc, rig) return buildDefaultRig() end,
		CreateHumanoidModelFromUserId = function() return buildDefaultRig() end,
		GetFriendsAsync = function() return nil end,
		Chat = function() end,
	},
	events = { "PlayerAdded", "PlayerRemoving", "PlayerMembershipChanged", "UserSubscriptionStatusChanged" },
})

---------------- RunService ----------------
local renderBinds = {} -- ctx.key -> { {name, prio, fn} }
service("RunService", "Instance", {
	props = { ClientGitHash = "mock" },
	methods = {
		IsServer = function() return curCtx().side == "server" end,
		IsClient = function() return curCtx().side == "client" end,
		IsStudio = function() return true end,
		IsRunning = function() return true end,
		IsRunMode = function() return false end,
		IsEdit = function() return false end,
		BindToRenderStep = function(self, name, prio, fn)
			local ctx = curCtx()
			if ctx.side ~= "client" then throw("BindToRenderStep can only be used from local scripts") end
			if rawtype(fn) ~= "function" then throw("BindToRenderStep: function expected") end
			local list = renderBinds[ctx.key] or {}
			renderBinds[ctx.key] = list
			for i = #list, 1, -1 do if list[i].name == name then tremove(list, i) end end
			list[#list + 1] = { name = name, prio = tonumber(prio) or 0, fn = fn, ctx = ctx }
			tsort(list, function(a, b) return a.prio < b.prio end)
		end,
		UnbindFromRenderStep = function(self, name)
			local ctx = curCtx()
			local list = renderBinds[ctx.key]
			if list then for i = #list, 1, -1 do if list[i].name == name then tremove(list, i) end end end
		end,
		Pause = function() end, Run = function() end, Stop = function() end, Set3dRenderingEnabled = function() end,
	},
	events = { "Heartbeat", "Stepped", "RenderStepped", "PreRender", "PreAnimation", "PreSimulation", "PostSimulation" },
	eventInit = {
		RenderStepped = function(s) s.onConnect = function(sig, ctx) if ctx.side ~= "client" then throw("RenderStepped event can only be used from local scripts") end end end,
		PreRender = function(s) s.onConnect = function(sig, ctx) if ctx.side ~= "client" then throw("PreRender event can only be used from local scripts") end end end,
	},
})

---------------- TweenService, Debris, CollectionService ----------------
service("TweenService", "Instance", {
	methods = {
		Create = function(self, inst, info, goals) return createTween(inst, info, goals) end,
		GetValue = function(self, alpha, style, dir) return ease(style.Name, dir.Name, alpha) end,
		SmoothDamp = function(self, cur, target, vel, smooth) return target, vel end,
	},
})
service("Debris", "Instance", {
	props = { MaxItems = 1000 },
	methods = {
		AddItem = function(self, item, t)
			if not isInst(item) then throw("Debris:AddItem: Instance expected, got " .. typeof(item)) end
			mock.timer(tonumber(t) or 10, function()
				local d = item[DATA]
				if not d.destroyed then destroyInst(item, d) end
			end)
		end,
		addItem = function(self, item, t) classes.Debris.methods.AddItem(self, item, t) end,
	},
})
service("CollectionService", "Instance", {
	methods = {
		GetTagged = function(self, tag)
			local out = {}
			local set = I.tagged[tag]
			if set then
				for inst in pairs(set) do if not inst[DATA].destroyed then out[#out + 1] = inst end end
				tsort(out, function(a, b) return a[DATA].id < b[DATA].id end)
			end
			return out
		end,
		AddTag = function(self, inst, tag) inst:AddTag(tag) end,
		RemoveTag = function(self, inst, tag) inst:RemoveTag(tag) end,
		HasTag = function(self, inst, tag) return inst:HasTag(tag) end,
		GetTags = function(self, inst) return inst:GetTags() end,
		GetAllTags = function() local o = {} for k in pairs(I.tagged) do o[#o + 1] = k end return o end,
		GetInstanceAddedSignal = function(self, tag)
			local k = "add:" .. tag
			I.tagSignals[k] = I.tagSignals[k] or newSignal("InstanceAdded:" .. tag, self)
			return I.tagSignals[k]
		end,
		GetInstanceRemovedSignal = function(self, tag)
			local k = "rem:" .. tag
			I.tagSignals[k] = I.tagSignals[k] or newSignal("InstanceRemoved:" .. tag, self)
			return I.tagSignals[k]
		end,
	},
	events = { "TagAdded", "TagRemoved" },
})

---------------- ввод ----------------
local inputs = {} -- ctx.key -> состояние
local function inputOf(plr)
	local k = clientCtx(plr).key
	local s = inputs[k]
	if not s then
		s = { keys = {}, buttons = {}, mouse = v2(mock.viewport.w / 2, mock.viewport.h / 2), touch = false, keyboard = true,
			mouseEnabled = true, gamepad = false, lastType = E("UserInputType", "Keyboard"), yaw = 0, pitch = -0.25, zoom = 14 }
		inputs[k] = s
	end
	return s
end
mock.inputOf = inputOf
local function curInput()
	local c = curCtx()
	if c.side ~= "client" then return nil end
	return inputOf(c.player)
end

defclass("InputObject", "Instance", {
	props = { KeyCode = E("KeyCode", "Unknown"), UserInputType = E("UserInputType", "None"), UserInputState = E("UserInputState", "None"),
		Position = V0, Delta = V0 },
	methods = { IsModifierKeyDown = function() return false end },
	noCreate = true,
})
local function newInputObj(kc, uit, st, pos)
	local o = newInstance(classes.InputObject)
	local p = o[DATA].p
	p.KeyCode = kc or E("KeyCode", "Unknown")
	p.UserInputType = uit or E("UserInputType", "None")
	p.UserInputState = st or E("UserInputState", "Begin")
	p.Position = pos or V0
	p.Name = "InputObject"
	return o
end

local function uisGet(field, default)
	return function()
		local s = curInput()
		if not s then return default end
		return s[field]
	end
end
service("UserInputService", "Instance", {
	props = { MouseBehavior = E("MouseBehavior", "Default"), MouseIconEnabled = true, MouseDeltaSensitivity = 1, ModalEnabled = false,
		OverrideMouseIconBehavior = E("OverrideMouseIconBehavior", "None") },
	get = {
		TouchEnabled = uisGet("touch", false),
		KeyboardEnabled = uisGet("keyboard", false),
		MouseEnabled = uisGet("mouseEnabled", false),
		GamepadEnabled = uisGet("gamepad", false),
		AccelerometerEnabled = function() return false end,
		GyroscopeEnabled = function() return false end,
		VREnabled = function() return false end,
		PreferredInput = function()
			local s = curInput()
			if s and s.touch then return E("PreferredInput", "Touch") end
			return E("PreferredInput", "KeyboardAndMouse")
		end,
	},
	methods = {
		IsKeyDown = function(self, kc)
			local s = curInput()
			return s ~= nil and s.keys[kc.Name] == true
		end,
		IsMouseButtonPressed = function(self, uit)
			local s = curInput()
			return s ~= nil and s.buttons[uit.Name] == true
		end,
		GetMouseLocation = function()
			local s = curInput()
			return s and s.mouse or v2(0, 0)
		end,
		GetMouseDelta = function() return v2(0, 0) end,
		GetKeysPressed = function()
			local s = curInput()
			local out = {}
			if s then for k in pairs(s.keys) do out[#out + 1] = newInputObj(E("KeyCode", k), E("UserInputType", "Keyboard"), E("UserInputState", "Begin")) end end
			return out
		end,
		GetMouseButtonsPressed = function() return {} end,
		GetFocusedTextBox = function() return nil end,
		GetLastInputType = function()
			local s = curInput()
			return s and s.lastType or E("UserInputType", "None")
		end,
		GetGamepadConnected = function() return false end,
		GetConnectedGamepads = function() return {} end,
		GetNavigationGamepads = function() return {} end,
		GetSupportedGamepadKeyCodes = function() return {} end,
		GetStringForKeyCode = function(self, kc) return kc.Name end,
		GetImageForKeyCode = function() return "" end,
		GetDeviceRotation = function() return V0, CFrame.new() end,
		GetDeviceGravity = function() return newInputObj() end,
		GetDeviceAcceleration = function() return newInputObj() end,
	},
	events = { "InputBegan", "InputChanged", "InputEnded", "JumpRequest", "TouchStarted", "TouchMoved", "TouchEnded", "TouchTap",
		"TouchLongPress", "TouchPan", "TouchPinch", "TouchRotate", "TouchSwipe", "LastInputTypeChanged", "WindowFocused",
		"WindowFocusReleased", "TextBoxFocused", "TextBoxFocusReleased", "GamepadConnected", "GamepadDisconnected", "PointerAction",
		"DeviceRotationChanged", "DeviceGravityChanged", "DeviceAccelerationChanged" },
})

local casBinds = {} -- ctx.key -> name -> { fn, inputs, prio, seq }
local casSeq = 0
local function casBind(name, fn, touch, prio, ...)
	local ctx = curCtx()
	if ctx.side ~= "client" then throw("ContextActionService can only be used on the client") end
	if rawtype(name) ~= "string" then throw("BindAction: action name must be a string") end
	if rawtype(fn) ~= "function" then throw("BindAction: function expected") end
	local list = casBinds[ctx.key] or {}
	casBinds[ctx.key] = list
	local ins = {}
	for i = 1, select("#", ...) do
		local x = select(i, ...)
		if typeof(x) ~= "EnumItem" then throw("BindAction: input #" .. i .. " must be Enum.KeyCode or Enum.UserInputType, got " .. typeof(x)) end
		ins[#ins + 1] = x
	end
	casSeq = casSeq + 1
	list[name] = { fn = fn, inputs = ins, prio = prio, seq = casSeq, ctx = ctx, touch = touch and true or false }
end
service("ContextActionService", "Instance", {
	methods = {
		BindAction = function(self, name, fn, touch, ...) casBind(name, fn, touch, 2000, ...) end,
		BindActionAtPriority = function(self, name, fn, touch, prio, ...) casBind(name, fn, touch, tonumber(prio) or 2000, ...) end,
		UnbindAction = function(self, name)
			local list = casBinds[curCtx().key]
			if list then list[name] = nil end
		end,
		UnbindAllActions = function() casBinds[curCtx().key] = {} end,
		GetButton = function() return nil end,
		SetTitle = function() end, SetDescription = function() end, SetImage = function() end, SetPosition = function() end,
		GetBoundActionInfo = function(self, name)
			local list = casBinds[curCtx().key]
			local b = list and list[name]
			if not b then return {} end
			return { inputTypes = b.inputs, priorityLevel = b.prio, createTouchButton = b.touch, stackOrder = b.seq }
		end,
		GetAllBoundActionInfo = function()
			local out = {}
			for name, b in pairs(casBinds[curCtx().key] or {}) do out[name] = { inputTypes = b.inputs, priorityLevel = b.prio } end
			return out
		end,
		BindActivate = function() end, UnbindActivate = function() end,
		CallFunction = function(self, name, state, inobj)
			local b = (casBinds[curCtx().key] or {})[name]
			if b then return b.fn(name, state, inobj) end
		end,
	},
	events = { "LocalToolEquipped", "LocalToolUnequipped" },
})

---------------- прочие службы ----------------
service("GuiService", "Instance", {
	props = { AutoSelectGuiEnabled = true, CoreGuiNavigationEnabled = true, GuiNavigationEnabled = true, SelectedObject = N "Instance",
		TouchControlsEnabled = true, MenuIsOpen = false, PreferredTextSize = E("PreferredTextSize", "Medium"),
		PreferredTransparency = 1, ReducedMotionEnabled = false },
	get = { TopbarInset = function() return Rect.new(0, 0, mock.viewport.w, 58) end, IsModalDialog = function() return false end,
		IsWindows = function() return true end },
	methods = {
		GetGuiInset = function() return v2(0, 58), v2(0, 0) end,
		IsTenFootInterface = function() return false end,
		GetScreenResolution = function() return v2(mock.viewport.w, mock.viewport.h) end,
		CloseInspectMenu = function() end, InspectPlayerFromUserId = function() end, SetInspectMenuEnabled = function() end,
		AddSelectionParent = function() end, RemoveSelectionGroup = function() end,
	},
	events = { "MenuOpened", "MenuClosed", "MenuClosed", "UiMessageChanged" },
})
service("TextService", "Instance", {
	methods = {
		GetTextSize = function(self, text, size, font, frame)
			text = tostring_(text)
			local w = (utf8.len(text) or #text) * size * 0.52
			local lines = 1
			if frame and frame.X > 0 and w > frame.X then
				lines = ceil(w / frame.X)
				w = frame.X
			end
			return v2(w, size * lines)
		end,
		GetTextBoundsAsync = function(self, params) return v2(100, 20) end,
		FilterStringAsync = function(self, s) return { GetNonChatStringForBroadcastAsync = function() return s end } end,
	},
})
local function jsonEncode(v, out, depth)
	depth = depth or 0
	if depth > 100 then throw("JSONEncode: глубина слишком большая") end
	local t = rawtype(v)
	if v == nil then out[#out + 1] = "null"
	elseif t == "boolean" then out[#out + 1] = v and "true" or "false"
	elseif t == "number" then
		if v ~= v or v == huge or v == -huge then out[#out + 1] = "null" else out[#out + 1] = luauToString(v) end
	elseif t == "string" then
		out[#out + 1] = '"' .. sgsub(v, '[%c"\\]', function(c)
			local m = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
			return m[c] or sformat("\\u%04x", sbyte(c))
		end) .. '"'
	elseif t == "table" and not isMockObj(v) then
		if rawget(v, 1) ~= nil or next(v) == nil then
			out[#out + 1] = "["
			for i = 1, #v do
				if i > 1 then out[#out + 1] = "," end
				jsonEncode(v[i], out, depth + 1)
			end
			out[#out + 1] = "]"
		else
			out[#out + 1] = "{"
			local first = true
			local keys = {}
			for k in pairs(v) do keys[#keys + 1] = tostring_(k) end
			tsort(keys)
			for _, k in ipairs(keys) do
				if not first then out[#out + 1] = "," end
				first = false
				jsonEncode(k, out, depth + 1)
				out[#out + 1] = ":"
				local val = v[k]
				if val == nil then val = v[tonumber(k)] end
				jsonEncode(val, out, depth + 1)
			end
			out[#out + 1] = "}"
		end
	else
		throw("JSONEncode: нельзя закодировать " .. typeof(v))
	end
end
local function jsonDecode(s)
	local pos = 1
	local function ws() pos = sfind(s, "[^ \t\r\n]", pos) or #s + 1 end
	local val
	local function str()
		local out = {}
		pos = pos + 1
		while true do
			local c = ssub(s, pos, pos)
			if c == "" then throw("JSONDecode: незакрытая строка") end
			if c == '"' then pos = pos + 1 break end
			if c == "\\" then
				local n = ssub(s, pos + 1, pos + 1)
				local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
				if n == "u" then
					out[#out + 1] = utf8.char(tonumber(ssub(s, pos + 2, pos + 5), 16))
					pos = pos + 6
				else
					out[#out + 1] = map[n] or n
					pos = pos + 2
				end
			else
				out[#out + 1] = c
				pos = pos + 1
			end
		end
		return tconcat(out)
	end
	function val()
		ws()
		local c = ssub(s, pos, pos)
		if c == "{" then
			local o = {}
			pos = pos + 1
			ws()
			if ssub(s, pos, pos) == "}" then pos = pos + 1 return o end
			while true do
				ws()
				local k = str()
				ws()
				pos = pos + 1
				o[k] = val()
				ws()
				local d = ssub(s, pos, pos)
				pos = pos + 1
				if d == "}" then break end
			end
			return o
		elseif c == "[" then
			local o = {}
			pos = pos + 1
			ws()
			if ssub(s, pos, pos) == "]" then pos = pos + 1 return o end
			while true do
				o[#o + 1] = val()
				ws()
				local d = ssub(s, pos, pos)
				pos = pos + 1
				if d == "]" then break end
			end
			return o
		elseif c == '"' then return str()
		elseif ssub(s, pos, pos + 3) == "true" then pos = pos + 4 return true
		elseif ssub(s, pos, pos + 4) == "false" then pos = pos + 5 return false
		elseif ssub(s, pos, pos + 3) == "null" then pos = pos + 4 return nil
		end
		local num = smatch(s, "^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
		if not num or num == "" then throw("JSONDecode: неожиданный символ '" .. c .. "'") end
		pos = pos + #num
		return tonumber(num)
	end
	return val()
end
service("HttpService", "Instance", {
	props = { HttpEnabled = false },
	methods = {
		GenerateGUID = function(self, wrap)
			local t = {}
			for i = 1, 32 do t[i] = sformat("%x", math.random(0, 15)) end
			local g = sformat("%s-%s-%s-%s-%s", tconcat(t, "", 1, 8), tconcat(t, "", 9, 12), tconcat(t, "", 13, 16), tconcat(t, "", 17, 20), tconcat(t, "", 21, 32))
			g = supper(g)
			if wrap == false then return g end
			return "{" .. g .. "}"
		end,
		JSONEncode = function(self, v) local out = {} jsonEncode(v, out) return tconcat(out) end,
		JSONDecode = function(self, s) return jsonDecode(s) end,
		UrlEncode = function(self, s) return (sgsub(s, "[^%w%-_%.~]", function(c) return sformat("%%%02X", sbyte(c)) end)) end,
		GetAsync = function() throw("Http requests are not enabled. Enable via game settings") end,
		PostAsync = function() throw("Http requests are not enabled. Enable via game settings") end,
		RequestAsync = function() throw("Http requests are not enabled. Enable via game settings") end,
	},
})
service("PhysicsService", "Instance", {
	methods = {
		RegisterCollisionGroup = function(self, name)
			mock.collisionGroups = mock.collisionGroups or { Default = true }
			mock.collisionGroups[name] = true
		end,
		UnregisterCollisionGroup = function(self, name) if mock.collisionGroups then mock.collisionGroups[name] = nil end end,
		IsCollisionGroupRegistered = function(self, name) return name == "Default" or (mock.collisionGroups and mock.collisionGroups[name] == true) or false end,
		CollisionGroupSetCollidable = function(self, a, b, on)
			local g = mock.collisionGroups or { Default = true }
			if not g[a] and a ~= "Default" then throw("CollisionGroupSetCollidable: группа '" .. tostring_(a) .. "' не зарегистрирована") end
			if not g[b] and b ~= "Default" then throw("CollisionGroupSetCollidable: группа '" .. tostring_(b) .. "' не зарегистрирована") end
			mock.collidable = mock.collidable or {}
			mock.collidable[a .. "|" .. b] = on
			mock.collidable[b .. "|" .. a] = on
		end,
		CollisionGroupsAreCollidable = function(self, a, b)
			local c = mock.collidable and mock.collidable[a .. "|" .. b]
			if c == nil then return true end
			return c
		end,
		GetRegisteredCollisionGroups = function() return {} end,
		GetMaxCollisionGroups = function() return 32 end,
		SetPartCollisionGroup = function(self, part, g) suspicious("DEPRECATED", "SetPartCollisionGroup устарел — используйте part.CollisionGroup"); part.CollisionGroup = g end,
	},
})
service("Lighting", "Instance", {
	props = { Ambient = c3(0.5, 0.5, 0.5), Brightness = 2, ClockTime = 14, ColorShift_Bottom = BLACK, ColorShift_Top = BLACK,
		EnvironmentDiffuseScale = 0, EnvironmentSpecularScale = 0, ExposureCompensation = 0, FogColor = c3(0.75, 0.75, 0.75),
		FogEnd = 100000, FogStart = 0, GeographicLatitude = 41.7, GlobalShadows = true, OutdoorAmbient = c3(0.5, 0.5, 0.5),
		ShadowSoftness = 0.2, Technology = E("Technology", "ShadowMap"), LightingStyle = E("LightingStyle", "Realistic"),
		PrioritizeLightingQuality = false },
	get = {
		TimeOfDay = function(self, d)
			local t = d.p.ClockTime % 24
			local h = floor(t)
			local m = floor((t - h) * 60)
			local s = floor(((t - h) * 60 - m) * 60)
			return sformat("%02d:%02d:%02d", h, m, s)
		end,
	},
	set = {
		TimeOfDay = function(self, d, v)
			local h, m, s = smatch(tostring_(v), "^(%d+):?(%d*):?(%d*)")
			if not h then throw("TimeOfDay: неверный формат") end
			d.p.ClockTime = (tonumber(h) + (tonumber(m) or 0) / 60 + (tonumber(s) or 0) / 3600) % 24
			if d.sig then propChanged(self, d, "ClockTime") end
		end,
		ClockTime = function(self, d, v)
			if rawtype(v) ~= "number" then v = coerce("ClockTime", "number", v) end
			d.p.ClockTime = v % 24
			if d.sig then propChanged(self, d, "ClockTime") end
		end,
	},
	methods = {
		GetMinutesAfterMidnight = function(self) return self[DATA].p.ClockTime * 60 end,
		SetMinutesAfterMidnight = function(self, m) self.ClockTime = m / 60 end,
		GetSunDirection = function(self)
			local t = self[DATA].p.ClockTime
			local a = (t - 6) / 12 * pi
			return v3(cos(a), sin(a), -0.3).Unit
		end,
		GetMoonDirection = function(self)
			local t = self[DATA].p.ClockTime
			local a = (t - 18) / 12 * pi
			return v3(cos(a), sin(a), 0.3).Unit
		end,
	},
	events = { "LightingChanged" },
})
service("ReplicatedStorage", "Instance")
service("ReplicatedFirst", "Instance", { methods = { RemoveDefaultLoadingScreen = function() end, SetDefaultLoadingGuiRemoved = function() end,
	IsDefaultLoadingGuiRemoved = function() return true end, IsFinishedReplicating = function() return true end },
	events = { "DefaultLoadingGuiRemoved", "FinishedReplicating" } })
service("ServerScriptService", "Instance", { props = { LoadStringEnabled = false } })
service("ServerStorage", "Instance")
service("StarterPack", "Instance")
service("StarterGui", "BasePlayerGui", {
	props = { ShowDevelopmentGui = true, ResetPlayerGuiOnSpawn = true, ScreenOrientation = E("ScreenOrientation", "LandscapeSensor"),
		VirtualCursorMode = E("VirtualCursorMode", "Default") },
	methods = {
		SetCoreGuiEnabled = function(self, t, on)
			if typeof(t) ~= "EnumItem" or rawget(t, "__typename") ~= "CoreGuiType" then throw("SetCoreGuiEnabled: Enum.CoreGuiType expected") end
			mock.coreGui = mock.coreGui or {}
			mock.coreGui[curCtx().key .. ":" .. t.Name] = on and true or false
		end,
		GetCoreGuiEnabled = function(self, t)
			local v = mock.coreGui and mock.coreGui[curCtx().key .. ":" .. t.Name]
			if v == nil then return true end
			return v
		end,
		SetCore = function(self, name, value)
			local known = { ResetButtonCallback = true, TopbarEnabled = true, SendNotification = true, ChatActive = true,
				PointsNotificationsActive = true, BadgesNotificationsActive = true, ChatMakeSystemMessage = true, ChatWindowPosition = true,
				ChatWindowSize = true, ChatBarDisabled = true, AvatarContextMenuEnabled = true, CoreGuiChatConnections = true }
			if not known[name] then throw("SetCore: " .. tostring_(name) .. " has not been registered by the CoreScripts") end
			if curCtx().side ~= "client" then throw("SetCore can only be called from the client") end
		end,
		GetCore = function(self, name)
			if name == "TopbarEnabled" or name == "ChatActive" then return true end
			throw("GetCore: " .. tostring_(name) .. " has not been registered by the CoreScripts")
		end,
		RegisterSetCore = function() end, RegisterGetCore = function() end,
	},
})
service("StarterPlayer", "Instance", {
	props = { CameraMaxZoomDistance = 400, CameraMinZoomDistance = 0.5, CameraMode = E("CameraMode", "Classic"),
		CharacterWalkSpeed = 16, CharacterJumpHeight = 7.2, CharacterJumpPower = 50, CharacterUseJumpPower = false,
		CharacterMaxSlopeAngle = 89, AutoJumpEnabled = true, EnableMouseLockOption = true, LoadCharacterAppearance = true,
		UserEmotesEnabled = true, HealthDisplayDistance = 100, NameDisplayDistance = 100, AllowCustomAnimations = true,
		DevComputerMovementMode = E("DevComputerMovementMode", "UserChoice"), DevTouchMovementMode = E("DevTouchMovementMode", "UserChoice"),
		DevCameraOcclusionMode = E("DevCameraOcclusionMode", "Zoom"), DevComputerCameraMovementMode = E("DevComputerCameraMovementMode", "UserChoice"),
		DevTouchCameraMovementMode = E("DevTouchCameraMovementMode", "UserChoice"), EnableDynamicHeads = E("LoadDynamicHeads", "Default"),
		CharacterWalkSpeedMax = 16 },
})
defclass("StarterPlayerScripts", "Instance")
defclass("StarterCharacterScripts", "Instance")
service("SoundService", "Instance", {
	props = { AmbientReverb = E("ReverbType", "NoReverb"), DistanceFactor = 3.33, DopplerScale = 1, RespectFilteringEnabled = true,
		RolloffScale = 1, VolumetricAudio = E("VolumetricAudio", "Automatic"), DefaultListenerLocation = E("ListenerLocation", "Character") },
	methods = {
		PlayLocalSound = function(self, s) if isInst(s) then s:Play() end end,
		SetListener = function() end,
		GetListener = function() return E("ListenerType", "Camera"), nil end,
	},
})
service("Teams", "Instance", { methods = { GetTeams = function(self) return self:GetChildren() end } })
service("Chat", "Instance", { props = { BubbleChatEnabled = true, LoadDefaultChat = true },
	methods = { Chat = function() end, FilterStringAsync = function(self, s) return s end, CanUserChatAsync = function() return true end } })
service("TextChatService", "Instance", { props = { ChatVersion = E("ChatVersion", "TextChatService"), CreateDefaultCommands = true,
	CreateDefaultTextChannels = true } })
service("ContentProvider", "Instance", {
	props = { BaseUrl = "https://www.roblox.com/" },
	get = { RequestQueueSize = function() return 0 end },
	methods = {
		PreloadAsync = function(self, list, cb)
			if rawtype(list) ~= "table" then throw("PreloadAsync: table expected") end
			if cb then
				for _, a in ipairs(list) do
					local id = isInst(a) and (a[DATA].p.SoundId or a[DATA].p.Texture or a[DATA].p.Image or "") or tostring_(a)
					cb(id, E("AssetFetchStatus", "Success"))
				end
			end
		end,
		GetAssetFetchStatus = function() return E("AssetFetchStatus", "Success") end,
	},
})
service("MarketplaceService", "Instance", {
	methods = { PromptProductPurchase = function() end, PromptGamePassPurchase = function() end, PromptPurchase = function() end,
		UserOwnsGamePassAsync = function() return false end, GetProductInfo = function() return { Name = "Mock", PriceInRobux = 0 } end,
		PlayerOwnsAsset = function() return false end },
	events = { "PromptProductPurchaseFinished", "PromptGamePassPurchaseFinished", "PromptPurchaseFinished" },
})
service("BadgeService", "Instance", { methods = { AwardBadge = function() return true end, UserHasBadgeAsync = function() return false end } })
service("ProximityPromptService", "Instance", { props = { Enabled = true, MaxPromptsVisible = 16 },
	events = { "PromptTriggered", "PromptTriggerEnded", "PromptButtonHoldBegan", "PromptButtonHoldEnded", "PromptShown", "PromptHidden" } })
service("VRService", "Instance", { props = { VREnabled = false, GuiInputUserCFrame = E("UserCFrame", "Head") },
	methods = { GetUserCFrame = function() return CFrame.new() end, GetUserCFrameEnabled = function() return false end } })
service("HapticService", "Instance", { methods = { IsVibrationSupported = function() return false end, IsMotorSupported = function() return false end,
	SetMotor = function() end, GetMotor = function() return 0 end } })
service("LocalizationService", "Instance", { props = { RobloxLocaleId = "ru-ru", SystemLocaleId = "ru-ru" },
	methods = { GetCountryRegionForPlayerAsync = function() return "RU" end, GetTranslatorForPlayerAsync = function() return nil end } })
service("PolicyService", "Instance", { methods = { GetPolicyInfoForPlayerAsync = function() return { AreAdsAllowed = false, ArePaidRandomItemsRestricted = false,
	AllowedExternalLinkReferences = {}, IsPaidItemTradingAllowed = true, IsSubjectToChinaPolicies = false } end } })
service("KeyframeSequenceProvider", "Instance", { methods = { RegisterKeyframeSequence = function() return "rbxassetid://0" end,
	RegisterActiveKeyframeSequence = function() return "rbxassetid://0" end, GetKeyframeSequenceAsync = function() return newInstance(classes.KeyframeSequence) end } })
service("AnimationClipProvider", "Instance", { methods = { RegisterAnimationClip = function() return "rbxassetid://0" end,
	RegisterActiveAnimationClip = function() return "rbxassetid://0" end } })
service("PathfindingService", "Instance", {
	methods = {
		CreatePath = function(self, params)
			local p = newInstance(classes.Path)
			p[DATA].params = params
			return p
		end,
		FindPathAsync = function(self, a, b)
			local p = newInstance(classes.Path)
			p:ComputeAsync(a, b)
			return p
		end,
	},
})
defclass("Path", "Instance", {
	props = { Status = E("PathStatus", "NoPath") },
	methods = {
		ComputeAsync = function(self, a, b)
			checkV3(a, "ComputeAsync")
			checkV3(b, "ComputeAsync")
			local d = self[DATA]
			d.wps = { PathWaypoint.new(a, E("PathWaypointAction", "Walk")), PathWaypoint.new(b, E("PathWaypointAction", "Walk")) }
			d.p.Status = E("PathStatus", "Success")
		end,
		GetWaypoints = function(self) return self[DATA].wps or {} end,
		CheckOcclusionAsync = function() return -1 end,
	},
	events = { "Blocked", "Unblocked" },
	noCreate = true,
})
service("AssetService", "Instance", { methods = { CreateEditableImage = function() throw("EditableImage не поддерживается в песочнице") end } })
service("SocialService", "Instance", { methods = { CanSendGameInviteAsync = function() return false end, PromptGameInvite = function() end } })
service("GroupService", "Instance", { methods = { GetGroupsAsync = function() return {} end } })
service("StarterCharacterScriptsService", "Instance")
service("UserGameSettings", "Instance", { props = { SavedQualityLevel = E("SavedQualitySetting", "Automatic"), MasterVolume = 1,
	RotationType = E("RotationType", "MovementRelative"), MouseSensitivity = 1, ComputerMovementMode = E("ComputerMovementMode", "Default") },
	methods = { GetCameraYInvertValue = function() return 1 end, InFullScreen = function() return false end, InStudioMode = function() return true end },
	events = { "FullscreenChanged", "StudioModeChanged" } })
service("TestService", "Instance")
service("Selection", "Instance", { methods = { Get = function() return {} end, Set = function() end } })
service("Stats", "Instance", { get = { DataReceiveKbps = function() return 0 end, DataSendKbps = function() return 0 end,
	HeartbeatTimeMs = function() return 16 end, PhysicsReceiveKbps = function() return 0 end, InstanceCount = function() return 0 end,
	PrimitivesCount = function() return mock.partsInWorkspace() end }, methods = { GetTotalMemoryUsageMb = function() return 300 end } })
service("MemoryStoreService", "Instance")
service("MessagingService", "Instance", { methods = { PublishAsync = function() end, SubscribeAsync = function() return { Disconnect = function() end } end } })
service("TeleportService", "Instance", { methods = { Teleport = function() end, TeleportAsync = function() end, GetLocalPlayerTeleportData = function() return nil end } })
service("DataStoreService", "Instance", { methods = { GetDataStore = function() throw("DataStore недоступен в песочнице (как в Studio без доступа к API)") end,
	GetOrderedDataStore = function() throw("DataStore недоступен в песочнице") end } })

---------------- Humanoid: дополнения ----------------
classes.Humanoid.getters.FloorMaterial = function(self, d)
	if d.dead then return E("Material", "Air") end
	if d.grounded == false then return E("Material", "Air") end
	return d.floorMat or E("Material", "Plastic")
end
classes.Humanoid.getters.SeatPart = function() return nil end
do
	local origChange = classes.Humanoid.methods.ChangeState
	classes.Humanoid.methods.ChangeState = function(self, st)
		local d = self[DATA]
		local ctx = curCtx()
		local m = d.parent
		local plr = m and playerByChar(m)
		if plr and ctx.side == "server" then
			suspicious("HUMANOID", "сервер вызывает ChangeState у персонажа игрока — в Roblox это работает только на клиенте-владельце")
		end
		if typeof(st) == "EnumItem" and d.stateEnabled and d.stateEnabled[st] == false and st.Name ~= "Dead" then return end
		return origChange(self, st)
	end
end

---------------- окружение скриптов ----------------
local function luauTable()
	local t = {}
	for k, v in pairs(table) do t[k] = v end
	local frozen = setmt({}, { __mode = "k" })
	t.find = function(tbl, v, init)
		if rawtype(tbl) ~= "table" then throw("invalid argument #1 to 'find' (table expected, got " .. typeof(tbl) .. ")") end
		for i = init or 1, #tbl do if tbl[i] == v then return i end end
		return nil
	end
	t.clear = function(tbl) for k in pairs(tbl) do tbl[k] = nil end end
	t.create = function(n, v) local o = {} for i = 1, n do o[i] = v end return o end
	t.clone = function(tbl)
		if rawtype(tbl) ~= "table" then throw("invalid argument #1 to 'clone' (table expected, got " .. typeof(tbl) .. ")") end
		local o = {}
		for k, v in pairs(tbl) do o[k] = v end
		return setmt(o, getmetatable(tbl))
	end
	t.freeze = function(tbl) frozen[tbl] = true return tbl end
	t.isfrozen = function(tbl) return frozen[tbl] == true end
	t.getn = function(tbl) return #tbl end
	t.foreach = function(tbl, f) for k, v in pairs(tbl) do f(k, v) end end
	t.foreachi = function(tbl, f) for i, v in ipairs(tbl) do f(i, v) end end
	t.maxn = nil
	local origInsert, origRemove = table.insert, table.remove
	t.insert = function(tbl, ...)
		if frozen[tbl] then throw("attempt to modify a readonly table") end
		return origInsert(tbl, ...)
	end
	t.remove = function(tbl, ...)
		if frozen[tbl] then throw("attempt to modify a readonly table") end
		return origRemove(tbl, ...)
	end
	return t
end
local function perlin(x, y, z)
	-- детерминированный гладкий шум ~[-0.5, 0.5]
	y, z = y or 0, z or 0
	local function h(a, b, c) local n = sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453 return n - floor(n) end
	local xi, yi, zi = floor(x), floor(y), floor(z)
	local xf, yf, zf = x - xi, y - yi, z - zi
	local function fade(t) return t * t * t * (t * (t * 6 - 15) + 10) end
	local u, v, w = fade(xf), fade(yf), fade(zf)
	local function lerp(a, b, t) return a + (b - a) * t end
	local c000, c100 = h(xi, yi, zi), h(xi + 1, yi, zi)
	local c010, c110 = h(xi, yi + 1, zi), h(xi + 1, yi + 1, zi)
	local c001, c101 = h(xi, yi, zi + 1), h(xi + 1, yi, zi + 1)
	local c011, c111 = h(xi, yi + 1, zi + 1), h(xi + 1, yi + 1, zi + 1)
	local r = lerp(lerp(lerp(c000, c100, u), lerp(c010, c110, u), v), lerp(lerp(c001, c101, u), lerp(c011, c111, u), v), w)
	if xf == 0 and yf == 0 and zf == 0 then return 0 end
	return r - 0.5
end
local function luauMath()
	local m = {}
	for k, v in pairs(math) do m[k] = v end
	m.clamp = function(x, a, b)
		if rawtype(x) ~= "number" or rawtype(a) ~= "number" or rawtype(b) ~= "number" then throw("invalid argument to 'clamp' (number expected)") end
		if a > b then throw("invalid argument #3 to 'clamp' (max must be greater than or equal to min)") end
		if x < a then return a end
		if x > b then return b end
		return x
	end
	m.sign = function(x) if x > 0 then return 1 elseif x < 0 then return -1 end return 0 end
	m.round = function(x) if x >= 0 then return floor(x + 0.5) end return -floor(-x + 0.5) end
	m.noise = perlin
	m.log = function(x, b) if b then return math.log(x) / math.log(b) end return math.log(x) end
	m.atan2 = function(y, x) return math.atan(y, x) end
	m.pow = function(a, b) return a ^ b end
	m.cosh = function(x) return (math.exp(x) + math.exp(-x)) / 2 end
	m.sinh = function(x) return (math.exp(x) - math.exp(-x)) / 2 end
	m.tanh = function(x) local a, b = math.exp(x), math.exp(-x) return (a - b) / (a + b) end
	m.ldexp = function(x, e) return x * 2 ^ e end
	m.frexp = function(x)
		if x == 0 then return 0, 0 end
		local e = floor(math.log(abs(x), 2)) + 1
		return x / 2 ^ e, e
	end
	m.map = function(x, a, b, c, d) return c + (x - a) * (d - c) / (b - a) end
	m.lerp = function(a, b, t) return a + (b - a) * t end
	m.floor = function(x) return floor(x) end
	m.ceil = function(x) return ceil(x) end
	m.type = nil
	m.tointeger = nil
	m.ult = nil
	return m
end
local function luauString()
	local s = {}
	for k, v in pairs(string) do s[k] = v end
	s.split = function(str, sep)
		if rawtype(str) ~= "string" then throw("invalid argument #1 to 'split' (string expected)") end
		sep = sep or ","
		local out = {}
		if sep == "" then
			for i = 1, #str do out[i] = ssub(str, i, i) end
			return out
		end
		local i = 1
		while true do
			local a, b = sfind(str, sep, i, true)
			if not a then
				out[#out + 1] = ssub(str, i)
				break
			end
			out[#out + 1] = ssub(str, i, a - 1)
			i = b + 1
		end
		return out
	end
	s.format = function(fmt, ...)
		local args = tpack(...)
		local idx = 0
		for spec in sgmatch(fmt, "%%[-+ #0]*%d*%.?%d*([%a%%])") do
			if spec ~= "%" then
				idx = idx + 1
				local v = args[idx]
				if (spec == "d" or spec == "i" or spec == "x" or spec == "X" or spec == "c" or spec == "o" or spec == "u") and rawtype(v) == "number" then
					if v ~= floor(v) then args[idx] = v >= 0 and floor(v) or ceil(v) end
					if v ~= v or v == huge or v == -huge then args[idx] = 0 end
				end
				if spec == "s" and v ~= nil and rawtype(v) ~= "string" then args[idx] = luauToString(v) end
			end
		end
		return sformat(fmt, tunpack(args, 1, args.n))
	end
	return s
end
local function luauCoroutine()
	local c = {}
	for k, v in pairs(coroutine) do c[k] = v end
	c.create = function(fn)
		if rawtype(fn) ~= "function" then throw("invalid argument #1 to 'create' (function expected)") end
		return newThread(fn, curCtx())
	end
	c.wrap = function(fn)
		local co = newThread(fn, curCtx())
		return function(...)
			local r = tpack(co_resume(co, ...))
			if not r[1] then error_(r[2], 2) end
			return tunpack(r, 2, r.n)
		end
	end
	c.isyieldable = function() local _, main = co_running() return not main end
	return c
end
local bit32lib = {
	band = function(...) local r = 0xFFFFFFFF for i = 1, select("#", ...) do r = r & (floor(select(i, ...)) & 0xFFFFFFFF) end return r end,
	bor = function(...) local r = 0 for i = 1, select("#", ...) do r = r | (floor(select(i, ...)) & 0xFFFFFFFF) end return r end,
	bxor = function(...) local r = 0 for i = 1, select("#", ...) do r = r ~ (floor(select(i, ...)) & 0xFFFFFFFF) end return r end,
	bnot = function(x) return (~floor(x)) & 0xFFFFFFFF end,
	lshift = function(x, n) return (floor(x) << n) & 0xFFFFFFFF end,
	rshift = function(x, n) return (floor(x) & 0xFFFFFFFF) >> n end,
	arshift = function(x, n)
		x = floor(x) & 0xFFFFFFFF
		if x & 0x80000000 ~= 0 then return ((x >> n) | (0xFFFFFFFF << (32 - n))) & 0xFFFFFFFF end
		return x >> n
	end,
	btest = function(...) return bit32lib.band(...) ~= 0 end,
	extract = function(x, f, w) w = w or 1 return (floor(x) >> f) & ((1 << w) - 1) end,
	replace = function(x, v, f, w) w = w or 1 local mask = ((1 << w) - 1) << f return ((floor(x) & ~mask) | ((floor(v) << f) & mask)) & 0xFFFFFFFF end,
	lrotate = function(x, n) x = floor(x) & 0xFFFFFFFF n = n % 32 return ((x << n) | (x >> (32 - n))) & 0xFFFFFFFF end,
	rrotate = function(x, n) x = floor(x) & 0xFFFFFFFF n = n % 32 return ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF end,
	countlz = function(x) x = floor(x) & 0xFFFFFFFF local n = 0 for i = 31, 0, -1 do if x & (1 << i) ~= 0 then break end n = n + 1 end return n end,
	countrz = function(x) x = floor(x) & 0xFFFFFFFF local n = 0 for i = 0, 31 do if x & (1 << i) ~= 0 then break end n = n + 1 end return n end,
}

local userSettings = setmt({}, { __index = function(t, k)
	if k == "GetService" then return function(self, name) return getService(name) end end
	if k == "IsUserFeatureEnabled" then return function() return false end end
	if k == "GameSettings" then return getService("UserGameSettings") end
	throw(tostring_(k) .. " is not a valid member of UserSettings")
end, __type = "Instance" })

local knownGlobals = {}
local function fillG()
	G.game = gameInst
	G.Game = gameInst
	G.workspace = wsInst
	G.Workspace = wsInst
	G.Vector3 = Vector3
	G.Vector2 = Vector2
	G.CFrame = CFrame
	G.Color3 = Color3
	G.BrickColor = BrickColor
	G.UDim = UDim
	G.UDim2 = UDim2
	G.Enum = Enum
	G.typeof = typeof
	G.type = function(v)
		local t = rawtype(v)
		if t == "table" and isMockObj(v) then return "userdata" end
		return t
	end
	G.print = doPrint
	G.warn = doWarn
	G.error = error_
	G.assert = function(v, msg, ...)
		if not v then error_(msg == nil and "Assertion failed!" or msg, 2) end
		return v, msg, ...
	end
	G.pcall = pcall
	G.xpcall = xpcall
	G.select = select
	G.next = next
	G.pairs = function(t)
		if rawtype(t) ~= "table" or isMockObj(t) then throw("invalid argument #1 to 'pairs' (table expected, got " .. typeof(t) .. ")") end
		return next, t, nil
	end
	G.ipairs = function(t)
		if rawtype(t) ~= "table" or isMockObj(t) then throw("invalid argument #1 to 'ipairs' (table expected, got " .. typeof(t) .. ")") end
		return ipairs(t)
	end
	G.tonumber = tonumber
	G.tostring = function(v) return luauToString(v) end
	G.rawget = rawget
	G.rawset = rawset
	G.rawequal = rawequal
	G.rawlen = rawlen
	G.setmetatable = setmt
	G.getmetatable = getmetatable
	G.unpack = tunpack
	G.newproxy = function(mt) local p = {} if mt then setmt(p, {}) end return p end
	G.gcinfo = function() return 1024 end
	G.collectgarbage = function(opt) if opt == "count" then return 1024 end return 0 end
	G.string = luauString()
	G.table = luauTable()
	G.math = luauMath()
	G.os = { time = function(t) if t then return os.time(t) end return floor(mock.epoch + mock.now) end,
		clock = function() return mock.now end, date = function(f, t) return os.date(f, t or floor(mock.epoch + mock.now)) end,
		difftime = os.difftime }
	G.utf8 = utf8
	G.coroutine = luauCoroutine()
	G.bit32 = bit32lib
	G.debug = { traceback = debug.traceback, info = function(lvl, what)
		local info = debug.getinfo(rawtype(lvl) == "number" and lvl + 1 or lvl, "Sln")
		if not info then return nil end
		local out = {}
		for ch in sgmatch(what or "sln", ".") do
			if ch == "s" then out[#out + 1] = info.short_src
			elseif ch == "l" then out[#out + 1] = info.currentline
			elseif ch == "n" then out[#out + 1] = info.name
			elseif ch == "a" then out[#out + 1] = 0
			elseif ch == "f" then out[#out + 1] = info.func end
		end
		return tunpack(out)
	end, profilebegin = function() end, profileend = function() end, setmemorycategory = function() end,
		resetmemorycategory = function() end, dumpcodesize = function() end }
	G.task = task
	G.tick = function() return mock.epoch + mock.now end
	G.time = function() return mock.now end
	G.elapsedTime = function() return mock.now end
	G.wait = function(t)
		suspicious("DEPRECATED", "wait() устарел — используйте task.wait()")
		return task.wait(t or 0.03)
	end
	G.delay = function(t, f) suspicious("DEPRECATED", "delay() устарел — используйте task.delay()") return task.delay(t, f) end
	G.spawn = function(f) suspicious("DEPRECATED", "spawn() устарел — используйте task.spawn()") return task.defer(f) end
	G.settings = function() return setmt({}, { __index = function() return setmt({}, { __index = function() return 0 end }) end }) end
	G.UserSettings = function() return userSettings end
	G.shared = {}
	G._G = {}
	G.version = function() return "0.700.0.0" end
	G.printidentity = function() doPrint("Current identity is 2") end
	G.require = mock.require
	G.Instance = InstanceLib
	G.DockWidgetPluginGuiInfo = nil
	G.SharedTable = nil
	for k in pairs(G) do knownGlobals[k] = true end
end

local envMt = {
	__index = function(t, k)
		local v = G[k]
		if v == nil and rawtype(k) == "string" and not knownGlobals[k] then
			suspicious("GLOBAL", "чтение неизвестной глобальной переменной '" .. k .. "' (в Roblox будет nil)")
		end
		return v
	end,
	__newindex = function(t, k, v)
		suspicious("GLOBAL", "запись в глобальную переменную '" .. tostring_(k) .. "' — забыт local?")
		rawset(t, k, v)
	end,
}
local function makeEnv(scr)
	return setmt({ script = scr }, envMt)
end

local function chunkName(scr)
	local d = scr[DATA]
	if d.srcPath then return "@" .. d.srcPath end
	return "@" .. fullName(scr)
end

---------------- require ----------------
local modCaches = {} -- ctx.key -> { [module] = entry }
function mock.require(m)
	if rawtype(m) == "number" then throw("require(assetId): загрузка модулей по ID в песочнице не поддерживается") end
	if not isInst(m) or m[DATA].cls.name ~= "ModuleScript" then
		throw("Attempted to call require with invalid argument(s). (получено " .. typeof(m) .. (isInst(m) and (" " .. m[DATA].cls.name) or "") .. ")")
	end
	local ctx = curCtx()
	local cache = modCaches[ctx.key]
	if not cache then
		cache = {}
		modCaches[ctx.key] = cache
	end
	local e = cache[m]
	local co = co_running()
	if e then
		if e.state == "loading" then
			-- цикл require или параллельная загрузка
			local a = e.loader
			if a == co then throw("Requested module was required recursively (цикл require: " .. fullName(m) .. ")") end
			local chain = e.waiting or {}
			e.waiting = chain
			chain[#chain + 1] = co
			local guard = 0
			while e.state == "loading" and guard < 100000 do
				co_yield()
				guard = guard + 1
			end
		end
		if e.state == "error" then throw("Requested module experienced an error while loading (" .. fullName(m) .. ")") end
		return e.value
	end
	e = { state = "loading", loader = co }
	cache[m] = e
	local d = m[DATA]
	local env = makeEnv(m)
	local fn, err = load(d.p.Source or "", chunkName(m), "t", env)
	if not fn then
		e.state = "error"
		recordError(err, nil, ctx)
		throw("Requested module experienced an error while loading (синтаксис: " .. tostring_(err) .. ")")
	end
	local r = tpack(xpcall(fn, function(msg) return { msg = msg, tb = debug.traceback(msg, 2) } end))
	local function wake()
		if e.waiting then
			local w = e.waiting
			e.waiting = nil
			for _, x in ipairs(w) do deferQ[#deferQ + 1] = { co = x, args = tpack() } end
		end
	end
	if not r[1] then
		e.state = "error"
		local info = r[2]
		recordError(info.msg, info.tb, ctx)
		wake()
		throw("Requested module experienced an error while loading (" .. fullName(m) .. ")")
	end
	if r.n ~= 2 then
		e.state = "error"
		wake()
		throw("Module code did not return exactly one value (" .. fullName(m) .. ")")
	end
	e.state = "done"
	e.value = r[2]
	wake()
	return r[2]
end

---------------- запуск скриптов ----------------
mock.scriptsRun = 0
local function runScript(scr, ctx)
	local d = scr[DATA]
	if d.ran or d.p.Disabled or d.p.Enabled == false then return end
	d.ran = true
	mock.scriptsRun = mock.scriptsRun + 1
	local env = makeEnv(scr)
	local fn, err = load(d.p.Source or "", chunkName(scr), "t", env)
	if not fn then
		recordError(err, nil, ctx)
		return
	end
	local co = newThread(fn, ctx)
	resume(co)
end
mock.runScript = runScript

-- скрипты внутри поддерева (персонаж, PlayerGui, PlayerScripts)
function runScriptsIn(root, plr)
	local list = {}
	local function visit(x)
		local xd = x[DATA]
		if xd.cls.name == "LocalScript" or xd.cls.name == "Script" then list[#list + 1] = x end
	end
	visit(root)
	eachDesc(root, visit)
	for _, s in ipairs(list) do
		local sd = s[DATA]
		local rc = sd.p.RunContext and sd.p.RunContext.Name or "Legacy"
		if sd.cls.name == "LocalScript" or rc == "Client" then
			if plr then runScript(s, clientCtx(plr)) end
		else
			runScript(s, SERVER)
		end
	end
end

---------------- DataModel: создание ----------------
function mock.newGame()
	gameInst = newInstance(classes.DataModel)
	gameInst[DATA].p.Name = "Game"
	for _, name in ipairs({ "Workspace", "Players", "Lighting", "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService",
		"ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "Teams", "SoundService", "Chat", "TextChatService",
		"RunService", "UserInputService", "TweenService", "Debris", "CollectionService", "ContextActionService", "GuiService",
		"HttpService", "TextService", "PhysicsService" }) do
		getService(name)
	end
	wsInst = services.Workspace
	I.setWorkspace(wsInst)
	local terr = newInstance(classes.Terrain)
	terr[DATA].p.Name = "Terrain"
	terr[DATA].p.Anchored = true
	setParentRaw(terr, terr[DATA], wsInst)
	local sp = services.StarterPlayer
	local sps = newInstance(classes.StarterPlayerScripts)
	sps[DATA].p.Name = "StarterPlayerScripts"
	setParentRaw(sps, sps[DATA], sp)
	local scs = newInstance(classes.StarterCharacterScripts)
	scs[DATA].p.Name = "StarterCharacterScripts"
	setParentRaw(scs, scs[DATA], sp)
	ctxCamera(SERVER)
	fillG()
	return gameInst
end
mock.game = function() return gameInst end
mock.service = function(n) return services[n] end

-- построение дерева из описания (Python): { cls, name, props = { [k] = value }, refs = { [k] = id }, id, src, children = {} }
function mock.buildTree(spec, parent, byId, pendingRefs)
	byId = byId or {}
	local top = pendingRefs == nil
	pendingRefs = pendingRefs or {}
	local inst
	local cls = classes[spec.cls]
	if spec.service then
		inst = getService(spec.cls)
	elseif spec.cls == "Terrain" then
		inst = wsInst:FindFirstChild("Terrain")
	elseif spec.cls == "StarterPlayerScripts" or spec.cls == "StarterCharacterScripts" then
		inst = parent and parent:FindFirstChild(spec.cls)
		if not inst then
			inst = newInstance(classes[spec.cls])
			setParentRaw(inst, inst[DATA], parent)
		end
	else
		if not cls then
			suspicious("LOAD", "класс " .. tostring_(spec.cls) .. " неизвестен песочнице — заменён папкой (" .. tostring_(spec.name) .. ")", "place")
			cls = classes.Folder
		end
		inst = newInstance(cls)
	end
	local d = inst[DATA]
	if spec.name and not spec.service then d.p.Name = spec.name end
	if spec.src then d.srcPath = spec.src end
	if spec.id then byId[spec.id] = inst end
	for k, v in pairs(spec.props or {}) do
		local ok, err = pcall(function() inst[k] = v end)
		if not ok then
			suspicious("LOAD", "свойство " .. spec.cls .. "." .. k .. " не загрузилось: " .. tostring_(err), "place:" .. tostring_(spec.name))
		end
	end
	for k, v in pairs(spec.attrs or {}) do inst:SetAttribute(k, v) end
	for _, tag in ipairs(spec.tags or {}) do inst:AddTag(tag) end
	for k, id in pairs(spec.refs or {}) do pendingRefs[#pendingRefs + 1] = { inst = inst, k = k, id = id } end
	if parent and not spec.service and inst[DATA].parent ~= parent then setParentRaw(inst, d, parent) end
	for _, c in ipairs(spec.children or {}) do mock.buildTree(c, inst, byId, pendingRefs) end
	if top then
		for _, r in ipairs(pendingRefs) do
			local target = byId[r.id]
			if target then
				local ok, err = pcall(function() r.inst[r.k] = target end)
				if not ok then suspicious("LOAD", "ссылка " .. r.k .. " не установилась: " .. tostring_(err), "place") end
			end
		end
		I.solveDirtyJoints()
	end
	return inst
end

-- запуск серверных скриптов (Workspace и ServerScriptService)
function mock.startServer()
	local list = {}
	for _, root in ipairs({ services.ServerScriptService, wsInst }) do
		eachDesc(root, function(x)
			local xd = x[DATA]
			if xd.cls.name == "Script" then
				local rc = xd.p.RunContext and xd.p.RunContext.Name or "Legacy"
				if rc ~= "Client" then list[#list + 1] = x end
			end
		end)
	end
	for _, s in ipairs(list) do runScript(s, SERVER) end
	runDeferred()
end

---------------- игроки ----------------
local nextUserId = 1
function mock.addPlayer(name, opts)
	opts = opts or {}
	local plr = newInstance(classes.Player)
	local pd = plr[DATA]
	pd.p.Name = name
	rawset(plr, "__name", name)
	pd.p.DisplayName = opts.displayName or name
	pd.p.UserId = opts.userId or nextUserId
	nextUserId = nextUserId + 1
	for _, cn in ipairs({ "Backpack", "PlayerGui", "PlayerScripts", "StarterGear" }) do
		local c = newInstance(classes[cn])
		c[DATA].p.Name = cn
		setParentRaw(c, c[DATA], plr)
	end
	local inp = inputOf(plr)
	if opts.touch then inp.touch, inp.keyboard, inp.mouseEnabled = true, false, false end
	players[#players + 1] = plr
	setParentRaw(plr, pd, services.Players)
	fireEvent(services.Players[DATA], "PlayerAdded", plr)
	-- клиентские скрипты игрока
	local sp = services.StarterPlayer
	local sps = findChild(sp[DATA], "StarterPlayerScripts")
	local ps = findChild(pd, "PlayerScripts")
	if sps then
		for _, c in ipairs(sps:GetChildren()) do
			local copy = cloneInst(c)
			if copy then
				markOwner(copy, clientCtx(plr).key)
				setParentRaw(copy, copy[DATA], ps)
			end
		end
	end
	local rf = services.ReplicatedFirst
	if rf then runScriptsIn(rf, plr) end
	runScriptsIn(ps, plr)
	if services.Players[DATA].p.CharacterAutoLoads then
		local co = newThread(function() loadCharacter(plr) end, SERVER)
		resume(co)
	else
		resetPlayerGui(plr)
	end
	runDeferred()
	return plr
end
function mock.removePlayer(plr)
	for i = #players, 1, -1 do if players[i] == plr then tremove(players, i) end end
	fireEvent(services.Players[DATA], "PlayerRemoving", plr)
	local ch = plr[DATA].p.Character
	if ch and not ch[DATA].destroyed then destroyInst(ch, ch[DATA]) end
	destroyInst(plr, plr[DATA])
end
function mock.asClient(plr, fn, ...)
	local co = newThread(fn, clientCtx(plr))
	return resume(co, ...)
end
function mock.asServer(fn, ...)
	local co = newThread(fn, SERVER)
	return resume(co, ...)
end

---------------- ввод (симуляция) ----------------
local function guiAbsRect(g)
	local x, y, w, h = I.guiAbs(g, g[DATA])
	return x, y, w, h
end
local function playerOfGui(g)
	local a = g
	while a do
		local ad = a[DATA]
		if ad.cls.name == "PlayerGui" then return ad.parent end
		a = ad.parent
	end
	return nil
end
local function guiVisible(g)
	local a = g
	while a do
		local ad = a[DATA]
		if ad.cls.isa.GuiObject and ad.p.Visible == false then return false end
		if ad.cls.isa.LayerCollector then return ad.p.Enabled ~= false end
		if ad.cls.name == "PlayerGui" then return true end
		a = ad.parent
	end
	return false
end
mock.guiVisible = guiVisible

function mock.click(btn)
	if not isInst(btn) or not btn[DATA].cls.isa.GuiButton then throw("mock.click: GuiButton expected") end
	local plr = playerOfGui(btn)
	if not plr then throw("mock.click: кнопка не в PlayerGui") end
	if not guiVisible(btn) then
		suspicious("UI", "клик по невидимой кнопке " .. fullName(btn), "harness")
	end
	local ctx = clientCtx(plr)
	local co = newThread(function()
		local d = btn[DATA]
		local x, y, w, h = guiAbsRect(btn)
		local inp = newInputObj(E("KeyCode", "Unknown"), E("UserInputType", "MouseButton1"), E("UserInputState", "Begin"), v3(x + w / 2, y + h / 2, 0))
		fireEvent(d, "InputBegan", inp)
		fireEvent(d, "MouseButton1Down", x + w / 2, y + h / 2)
		fireEvent(d, "MouseButton1Up", x + w / 2, y + h / 2)
		fireEvent(d, "MouseButton1Click")
		fireEvent(d, "Activated", inp, 1)
		inp[DATA].p.UserInputState = E("UserInputState", "End")
		fireEvent(d, "InputEnded", inp)
	end, ctx)
	resume(co)
	runDeferred()
end

local function fireInput(plr, kind, inp, processed)
	local uis = services.UserInputService
	local ctx = clientCtx(plr)
	local s = uis[DATA].sig and uis[DATA].sig[kind]
	if s then fireSignal(s, clientOnlyCtx(ctx), inp, processed and true or false) end
end

local function casDispatch(plr, inp, state)
	local ctx = clientCtx(plr)
	local list = casBinds[ctx.key]
	if not list then return false end
	local cands = {}
	for name, b in pairs(list) do
		for _, x in ipairs(b.inputs) do
			if x == inp[DATA].p.KeyCode or x == inp[DATA].p.UserInputType then
				cands[#cands + 1] = { name = name, b = b }
				break
			end
		end
	end
	tsort(cands, function(a, b) if a.b.prio ~= b.b.prio then return a.b.prio > b.b.prio end return a.b.seq > b.b.seq end)
	for _, c in ipairs(cands) do
		local result
		local co = newThread(function() result = c.b.fn(c.name, state, inp) end, ctx)
		resume(co)
		if result == nil or (typeof(result) == "EnumItem" and result.Name == "Sink") then return true end
	end
	return false
end

-- нажать/отпустить клавишу: mock.key(plr, "Q", true)
function mock.key(plr, keyName, down)
	local s = inputOf(plr)
	local kc = E("KeyCode", keyName)
	local st = E("UserInputState", down and "Begin" or "End")
	if down then s.keys[keyName] = true else s.keys[keyName] = nil end
	s.lastType = E("UserInputType", "Keyboard")
	local inp = newInputObj(kc, E("UserInputType", "Keyboard"), st, v3(s.mouse.X, s.mouse.Y, 0))
	local sunk = casDispatch(plr, inp, st)
	fireInput(plr, down and "InputBegan" or "InputEnded", inp, false)
	if keyName == "Space" and down then
		local ch = plr[DATA].p.Character
		local h = ch and ch:FindFirstChildOfClass("Humanoid")
		if h then h.Jump = true end
		local uis = services.UserInputService
		local sig = uis[DATA].sig and uis[DATA].sig.JumpRequest
		if sig then fireSignal(sig, clientOnlyCtx(clientCtx(plr))) end
	end
	runDeferred()
	return sunk
end
function mock.tap(plr, keyName, hold)
	mock.key(plr, keyName, true)
	mock.run(hold or 0.05)
	mock.key(plr, keyName, false)
end
-- кнопка мыши: mock.mouseButton(plr, 1, true)
function mock.mouseButton(plr, n, down, x, y)
	local s = inputOf(plr)
	if x then s.mouse = v2(x, y) end
	local uitName = "MouseButton" .. tostring_(n)
	local uit = E("UserInputType", uitName)
	local st = E("UserInputState", down and "Begin" or "End")
	if down then s.buttons[uitName] = true else s.buttons[uitName] = nil end
	s.lastType = uit
	local inp = newInputObj(E("KeyCode", "Unknown"), uit, st, v3(s.mouse.X, s.mouse.Y, 0))
	casDispatch(plr, inp, st)
	fireInput(plr, down and "InputBegan" or "InputEnded", inp, false)
	local m = plr[DATA].mouse
	if m then fireEvent(m[DATA], (n == 1 and "Button1" or "Button2") .. (down and "Down" or "Up")) end
	runDeferred()
end
function mock.click1(plr, hold)
	mock.mouseButton(plr, 1, true)
	mock.run(hold or 0.05)
	mock.mouseButton(plr, 1, false)
end
function mock.setMouse(plr, x, y)
	local s = inputOf(plr)
	s.mouse = v2(x, y)
	local inp = newInputObj(E("KeyCode", "Unknown"), E("UserInputType", "MouseMovement"), E("UserInputState", "Change"), v3(x, y, 0))
	fireInput(plr, "InputChanged", inp, false)
end
function mock.setCameraYaw(plr, yaw, pitch, zoom)
	local s = inputOf(plr)
	s.yaw = yaw or s.yaw
	s.pitch = pitch or s.pitch
	s.zoom = zoom or s.zoom
end
-- курсор: куда смотрит мышь
function mock.mouseHit(plr)
	local s = inputOf(plr)
	local cam = ctxCamera(clientCtx(plr))
	local ray = cam:ViewportPointToRay(s.mouse.X, s.mouse.Y)
	local params = RaycastParams.new()
	local ch = plr[DATA].p.Character
	if ch then params.FilterDescendantsInstances = { ch } end
	local r = I.raycast(ray.Origin, ray.Direction * 1000, params)
	if r then return { cf = CFrame.new(r.Position), part = r.Instance, ray = ray } end
	return { cf = CFrame.new(ray.Origin + ray.Direction * 1000), part = nil, ray = ray }
end

-- управление по умолчанию: WASD относительно камеры
local function applyControls(plr)
	local s = inputOf(plr)
	local ch = plr[DATA].p.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if s.forcedMove then
		hum[DATA].moveDir = s.forcedMove
		return
	end
	local x = (s.keys.D and 1 or 0) - (s.keys.A and 1 or 0)
	local z = (s.keys.S and 1 or 0) - (s.keys.W and 1 or 0)
	if x == 0 and z == 0 then
		if hum[DATA].ctrlMoving then
			hum[DATA].moveDir = nil
			hum[DATA].ctrlMoving = false
		end
		return
	end
	local cam = ctxCamera(clientCtx(plr))
	local cf = cam[DATA].p.CFrame
	local look = CFget.LookVector(cf)
	local fl = v3(look.X, 0, look.Z)
	if fl.Magnitude < 1e-3 then fl = v3(0, 0, -1) end
	fl = fl.Unit
	local right = v3(-fl.Z, 0, fl.X)
	local dir = right * x + fl * (-z)
	hum[DATA].moveDir = dir.Unit
	hum[DATA].ctrlMoving = true
end
-- принудительное движение игрока (для сценариев)
function mock.walk(plr, dir)
	local s = inputOf(plr)
	s.forcedMove = dir
	if dir == nil then
		local ch = plr[DATA].p.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if hum then hum[DATA].moveDir = nil end
	end
end

-- камера Custom: за спиной персонажа
local function updateCamera(plr)
	local cam = ctxCamera(clientCtx(plr))
	local cd = cam[DATA]
	if cd.p.CameraType.Name ~= "Custom" and cd.p.CameraType.Name ~= "Follow" then return end
	local ch = plr[DATA].p.Character
	local subj = cd.p.CameraSubject
	local root
	if subj and isInst(subj) and subj[DATA].cls.name == "Humanoid" then root = I.rootPartOf(subj)
	elseif subj and isInst(subj) and subj[DATA].cls.isa.BasePart then root = subj
	elseif ch then root = findChild(ch[DATA], "HumanoidRootPart") end
	if not root then return end
	local s = inputOf(plr)
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	local off = (hum and hum[DATA].p.CameraOffset) or V0
	local focus = CFget.Position(root[DATA].p.CFrame) + v3(0, 1.5, 0) + off
	local yaw, pitch, zoom = s.yaw, s.pitch, s.zoom
	local dir = v3(math.sin(yaw) * math.cos(pitch), -math.sin(pitch), math.cos(yaw) * math.cos(pitch))
	local pos = focus + dir * zoom
	cd.p.CFrame = CFrame.lookAt(pos, focus)
	cd.p.Focus = CFrame.new(focus)
end

---------------- упрощённая физика ----------------
local movers = {} -- constraint -> true
local function moverHook(self, d, inWs) movers[self] = inWs or nil end
for _, cn in ipairs({ "LinearVelocity", "BodyVelocity", "AlignPosition", "BodyPosition", "VectorForce", "BodyForce" }) do
	classes[cn].wsHook = moverHook
end
local function moverPart(c)
	local d = c[DATA]
	if not d.p.Enabled and d.cls.isa.Constraint then return nil end
	if d.cls.isa.Constraint then
		local a0 = d.p.Attachment0
		local p = a0 and a0[DATA].parent
		if p and p[DATA].cls.isa.BasePart then return p end
		return nil
	end
	local p = d.parent
	if p and p[DATA].cls.isa.BasePart then return p end
	return nil
end
local function rootOfPart(p)
	local list = I.assemblyOf(p)
	for _, x in ipairs(list) do if x[DATA].p.Anchored then return nil end end
	for _, x in ipairs(list) do if x[DATA].p.Name == "HumanoidRootPart" then return x end end
	return list[1]
end
local floorP = RaycastParams.new()
local physStats = { steps = 0 }
mock.physStats = physStats

local function hipOffset(hum, root)
	local hd = hum[DATA]
	local hh = hd.p.HipHeight or 0
	if hd.p.RigType and hd.p.RigType.Name == "R6" and hh == 0 then return 3 end
	return hh + root[DATA].p.Size.Y / 2
end

local function physicsStep(dt)
	physStats.steps = physStats.steps + 1
	local g = wsInst[DATA].p.Gravity or 196.2
	-- скорости от «двигателей»
	local forced = {}
	for c in pairs(movers) do
		local cd = c[DATA]
		if not cd.destroyed and cd.inWs then
			local p = moverPart(c)
			local r = p and rootOfPart(p)
			if r then
				local f = forced[r] or {}
				forced[r] = f
				local cls = cd.cls.name
				if cls == "LinearVelocity" then
					if cd.p.Enabled and (cd.p.MaxForce or 0) > 0 then
						local mode = cd.p.VelocityConstraintMode and cd.p.VelocityConstraintMode.Name or "Vector"
						if mode == "Vector" then
							local v = cd.p.VectorVelocity
							if cd.p.RelativeTo and cd.p.RelativeTo.Name ~= "World" then
								local a0 = cd.p.Attachment0
								if a0 then v = v3(cfvec(cfmul(I.attParentCF(a0[DATA]), a0[DATA].p.CFrame), v.X, v.Y, v.Z)) end
							end
							f.vel = v
						elseif mode == "Line" then
							f.vel = cd.p.LineDirection.Unit * cd.p.LineVelocity
						else
							f.planeVel = cd.p.PlaneVelocity
						end
					end
				elseif cls == "BodyVelocity" then
					local mf = cd.p.MaxForce
					f.bv = { v = cd.p.Velocity, x = mf.X > 0, y = mf.Y > 0, z = mf.Z > 0 }
				elseif cls == "AlignPosition" then
					if cd.p.Enabled then
						local target
						if cd.p.Mode and cd.p.Mode.Name == "OneAttachment" then target = cd.p.Position
						elseif cd.p.Attachment1 then
							local a1 = cd.p.Attachment1[DATA]
							target = CFget.Position(cfmul(I.attParentCF(a1), a1.p.CFrame))
						end
						if target then f.alignTo = { pos = target, rigid = cd.p.RigidityEnabled, maxV = cd.p.MaxVelocity, resp = cd.p.Responsiveness } end
					end
				elseif cls == "BodyPosition" then
					f.alignTo = { pos = cd.p.Position, rigid = false, maxV = huge, resp = 20 }
				end
			end
		end
	end
	-- персонажи
	for hum in pairs(I.humans) do
		local hd = hum[DATA]
		local m = hd.parent
		local root = I.rootPartOf(hum)
		if root and m and root[DATA].inWs and not root[DATA].p.Anchored then
			local rd = root[DATA]
			local c = rd.p.CFrame
			local vel = hd.vel or V0
			local st = hd.state and hd.state.Name or "Running"
			local f = forced[root]
			local hip = hipOffset(hum, root)
			local alive = not hd.dead
			local physicsState = st == "Physics" or st == "Ragdoll" or st == "FallingDown" or st == "PlatformStanding" or hd.p.PlatformStand or st == "Dead"
			local dir
			if alive and not physicsState then
				local mv = hd.move
				if mv then
					if mock.now - mv.t0 > 8 then
						hd.move = nil
						fireEvent(hd, "MoveToFinished", false)
					else
						local target = mv.target
						if mv.part and mv.part[DATA] then target = CFget.Position(mv.part[DATA].p.CFrame) + target end
						local dx, dz = target.X - c.X, target.Z - c.Z
						local dist = sqrt(dx * dx + dz * dz)
						if dist < 1.2 then
							hd.move = nil
							fireEvent(hd, "MoveToFinished", true)
						else
							dir = v3(dx / dist, 0, dz / dist)
						end
					end
				elseif hd.moveDir then
					local md = hd.moveDir
					local mm = sqrt(md.X * md.X + md.Z * md.Z)
					if mm > 1e-3 then dir = v3(md.X / mm, 0, md.Z / mm) * mmin(mm, 1) end
				end
			end
			local horiz
			if f and f.vel then
				vel = f.vel
			elseif f and f.bv then
				local bv = f.bv
				vel = v3(bv.x and bv.v.X or vel.X, bv.y and bv.v.Y or vel.Y, bv.z and bv.v.Z or vel.Z)
			else
				if dir and hd.p.WalkSpeed > 0 then
					horiz = dir * hd.p.WalkSpeed
				elseif hd.grounded ~= false then
					horiz = v3(vel.X * 0.8, 0, vel.Z * 0.8)
					if horiz.Magnitude < 0.05 then horiz = V0 end
				else
					horiz = v3(vel.X, 0, vel.Z)
				end
				vel = v3(horiz.X, vel.Y, horiz.Z)
				-- прыжок
				if hd.p.Jump then
					hd.p.Jump = false
					local enabled = not (hd.stateEnabled and hd.stateEnabled[E("HumanoidStateType", "Jumping")] == false)
					local h = hd.p.UseJumpPower and ((hd.p.JumpPower or 0) ^ 2 / (2 * g)) or (hd.p.JumpHeight or 0)
					if alive and not physicsState and hd.grounded ~= false and h > 0 and enabled then
						vel = v3(vel.X, sqrt(2 * g * h), vel.Z)
						hd.grounded = false
						fireEvent(hd, "Jumping", true)
						local old = hd.state
						hd.state = E("HumanoidStateType", "Jumping")
						fireEvent(hd, "StateChanged", old or E("HumanoidStateType", "Running"), hd.state)
					end
				end
			end
			local nvel = vel
			if not (f and (f.vel or (f.bv and f.bv.y))) then
				if hd.grounded == false then nvel = v3(vel.X, vel.Y - g * dt, vel.Z) end
			end
			if f and f.alignTo then
				local a = f.alignTo
				local p = CFget.Position(c)
				local delta = a.pos - p
				if a.rigid then nvel = delta / dt else nvel = delta * mmin(1, (a.resp or 10) * dt) / dt end
				if a.maxV and a.maxV < huge and nvel.Magnitude > a.maxV then nvel = nvel.Unit * a.maxV end
			end
			local pos = CFget.Position(c)
			local step = nvel * dt
			-- стены: луч по горизонтали на уровне торса
			local hstep = v3(step.X, 0, step.Z)
			if hstep.Magnitude > 1e-4 then
				floorP.FilterDescendantsInstances = { m }
				floorP.FilterType = E("RaycastFilterType", "Exclude")
				floorP.RespectCanCollide = true
				local hit = I.raycast(pos, hstep.Unit * (hstep.Magnitude + 1), floorP)
				if hit then
					local allowed = mmax(0, hit.Distance - 1)
					step = hstep.Unit * allowed + v3(0, step.Y, 0)
					hd.hitWall = { t = mock.now, part = hit.Instance, normal = hit.Normal }
					nvel = v3(0, nvel.Y, 0)
				end
			end
			local np = pos + step
			-- пол
			floorP.FilterDescendantsInstances = { m }
			floorP.FilterType = E("RaycastFilterType", "Exclude")
			floorP.RespectCanCollide = true
			local probe = mmax(0, -step.Y) + hip + 0.6
			local hit = I.raycast(v3(np.X, np.Y + 1, np.Z), v3(0, -(probe + 1), 0), floorP)
			local wasGrounded = hd.grounded ~= false
			if hit and nvel.Y <= 0.01 and (np.Y - hip) <= hit.Position.Y + 0.35 then
				np = v3(np.X, hit.Position.Y + hip, np.Z)
				if not wasGrounded then
					fireEvent(hd, "StateChanged", hd.state or E("HumanoidStateType", "Freefall"), E("HumanoidStateType", "Landed"))
				end
				nvel = v3(nvel.X, 0, nvel.Z)
				hd.grounded = true
				hd.floorMat = hit.Material
			else
				hd.grounded = false
			end
			local ncf
			local hdir = v3(nvel.X, 0, nvel.Z)
			if alive and not physicsState and dir and hd.p.AutoRotate and hdir.Magnitude > 0.1 and not (f and f.vel) then
				ncf = CFrame.lookAt(np, np + dir)
			else
				ncf = cfnew(np.X, np.Y, np.Z, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9])
			end
			if (np - pos).Magnitude > 1e-5 or ncf ~= c then setPartCFrame(root, rd, ncf) end
			rd.p.AssemblyLinearVelocity = nvel
			hd.vel = nvel
			hd.moveDirection = dir or V0
			-- состояние
			if alive and not physicsState then
				local want
				if hd.grounded then want = "Running" elseif nvel.Y > 0 then want = "Jumping" else want = "Freefall" end
				if not hd.state or hd.state.Name ~= want then
					local old = hd.state
					hd.state = E("HumanoidStateType", want)
					fireEvent(hd, "StateChanged", old or E("HumanoidStateType", "Running"), hd.state)
					if want == "Freefall" then fireEvent(hd, "FreeFalling", true) end
				end
				if hd.grounded then fireEvent(hd, "Running", horiz and horiz.Magnitude or 0) end
			end
			-- падение в бездну
			if np.Y < (wsInst[DATA].p.FallenPartsDestroyHeight or -500) then
				hum.Health = 0
				destroyInst(m, m[DATA])
			end
		end
	end
	-- прочие детали с двигателями (снаряды без гуманоида)
	for r, f in pairs(forced) do
		local rd = r[DATA]
		local isChar = false
		local par = rd.parent
		if par and par[DATA].children then
			for _, c in ipairs(par[DATA].children) do if c[DATA].cls.name == "Humanoid" then isChar = true break end end
		end
		if not isChar and rd.inWs and not rd.p.Anchored then
			local vel = f.vel or (f.bv and f.bv.v) or rd.p.AssemblyLinearVelocity
			if f.alignTo then vel = (f.alignTo.pos - CFget.Position(rd.p.CFrame)) / dt end
			local c = rd.p.CFrame
			setPartCFrame(r, rd, c + vel * dt)
			rd.p.AssemblyLinearVelocity = vel
		end
	end
end
mock.physicsStep = physicsStep

---------------- кадр ----------------
local function rsSig(name)
	local rs = services.RunService
	return rs and rs[DATA].sig and rs[DATA].sig[name]
end
local function fireRS(name, filter, ...)
	local s = rsSig(name)
	if s then fireSignal(s, filter, ...) end
end
mock.frameDt = 1 / 60
function mock.step(dt)
	dt = dt or mock.frameDt
	mock.now = mock.now + dt
	mock.frame = mock.frame + 1
	runTimers()
	runDeferred()
	for _, plr in ipairs(players) do
		local ctx = clientCtx(plr)
		applyControls(plr)
		updateCamera(plr)
		local list = renderBinds[ctx.key]
		if list then
			for _, b in ipairs(list) do
				local fn = b.fn
				resume(newThread(function() fn(dt) end, ctx))
			end
		end
		fireRS("RenderStepped", clientOnlyCtx(ctx), dt)
		fireRS("PreRender", clientOnlyCtx(ctx), dt)
	end
	stepTweens()
	runDeferred()
	fireRS("PreAnimation", nil, dt)
	fireRS("Stepped", nil, mock.now, dt)
	fireRS("PreSimulation", nil, dt)
	I.solveDirtyJoints()
	physicsStep(dt)
	I.solveDirtyJoints()
	I.flushIndex()
	fireRS("Heartbeat", nil, dt)
	fireRS("PostSimulation", nil, dt)
	runDeferred()
	I.solveDirtyJoints()
end
function mock.run(seconds, dt)
	dt = dt or mock.frameDt
	local n = floor(seconds / dt + 0.5)
	for _ = 1, mmax(1, n) do mock.step(dt) end
end

---------------- снимки для превью ----------------
local function colorOf(c) return { floor(c.R * 255 + 0.5), floor(c.G * 255 + 0.5), floor(c.B * 255 + 0.5) } end
function mock.dumpParts(viewerPlr)
	local ctx = viewerPlr and clientCtx(viewerPlr) or SERVER
	local out = {}
	local function addPart(x, xd)
		if xd.terrainFill then return end
		local tr = xd.p.Transparency or 0
		local ltm = xd.p.LocalTransparencyModifier or 0
		if tr >= 0.999 then return end
		local c = xd.p.CFrame
		local s = xd.p.Size
		local mesh
		local decals = {}
		for _, ch in ipairs(xd.children or {}) do
			local cd = ch[DATA]
			if cd.cls.name == "SpecialMesh" then
				mesh = { type = cd.p.MeshType.Name, scale = { cd.p.Scale.X, cd.p.Scale.Y, cd.p.Scale.Z }, offset = { cd.p.Offset.X, cd.p.Offset.Y, cd.p.Offset.Z } }
			elseif cd.cls.name == "Decal" and (cd.p.Transparency or 0) < 1 then
				decals[#decals + 1] = { face = cd.p.Face.Name, texture = cd.p.Texture }
			end
		end
		local light
		for _, ch in ipairs(xd.children or {}) do
			local cd = ch[DATA]
			if cd.cls.isa.Light and cd.p.Enabled ~= false then
				light = { color = colorOf(cd.p.Color), range = cd.p.Range or 8, brightness = cd.p.Brightness or 1 }
			end
		end
		out[#out + 1] = {
			name = xd.p.Name, cls = xd.cls.name, shape = xd.p.Shape and xd.p.Shape.Name or "Block",
			cf = { c.X, c.Y, c.Z, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9] },
			size = { s.X, s.Y, s.Z }, color = colorOf(xd.p.Color), material = xd.p.Material.Name,
			transparency = 1 - (1 - tr) * (1 - ltm), reflectance = xd.p.Reflectance or 0, mesh = mesh, decals = decals, light = light,
			path = fullName(x),
		}
	end
	local function walk(inst)
		local d = inst[DATA]
		for _, x in ipairs(d.children or {}) do
			local xd = x[DATA]
			if visibleTo(x, ctx) then
				if xd.cls.isa.BasePart and xd.cls.name ~= "Terrain" then addPart(x, xd) end
				walk(x)
			end
		end
	end
	walk(wsInst)
	-- детали в камере клиента
	if viewerPlr then
		local cam = ctxCamera(ctx)
		walk(cam)
	end
	return out
end
function mock.dumpLights()
	local out = {}
	eachDesc(wsInst, function(x)
		local xd = x[DATA]
		if xd.cls.isa.Light and xd.p.Enabled ~= false then
			local par = xd.parent
			local pos
			if par and par[DATA].cls.isa.BasePart then pos = CFget.Position(par[DATA].p.CFrame)
			elseif par and par[DATA].cls.name == "Attachment" then pos = CFget.Position(cfmul(I.attParentCF(par[DATA]), par[DATA].p.CFrame)) end
			if pos then out[#out + 1] = { pos = { pos.X, pos.Y, pos.Z }, color = colorOf(xd.p.Color), range = xd.p.Range or 8, brightness = xd.p.Brightness or 1 } end
		end
	end)
	return out
end
function mock.dumpGui(plr)
	local out = {}
	local pg = findChild(plr[DATA], "PlayerGui")
	if not pg then return out end
	local order = 0
	local function walk(inst, depth, layer, clip)
		local d = inst[DATA]
		for _, x in ipairs(d.children or {}) do
			local xd = x[DATA]
			local cls = xd.cls
			if cls.isa.LayerCollector then
				if xd.p.Enabled ~= false and cls.name == "ScreenGui" then
					walk(x, 0, xd.p.DisplayOrder or 0, nil)
				end
			elseif cls.isa.GuiObject then
				if xd.p.Visible ~= false then
					local ax, ay, aw, ah = I.guiAbs(x, xd)
					order = order + 1
					local e = { cls = cls.name, name = xd.p.Name, x = ax, y = ay, w = aw, h = ah, z = xd.p.ZIndex or 1, layer = layer,
						depth = depth, order = order, bg = colorOf(xd.p.BackgroundColor3), bgT = xd.p.BackgroundTransparency, rot = xd.p.Rotation or 0,
						clip = clip }
					if xd.p.Text ~= nil then
						e.text = xd.p.Text
						e.textColor = colorOf(xd.p.TextColor3)
						e.textSize = xd.p.TextSize
						e.textScaled = xd.p.TextScaled
						e.textT = xd.p.TextTransparency
						e.strokeT = xd.p.TextStrokeTransparency
						e.strokeColor = colorOf(xd.p.TextStrokeColor3)
						e.xAlign = xd.p.TextXAlignment.Name
						e.yAlign = xd.p.TextYAlignment.Name
						e.wrapped = xd.p.TextWrapped
						e.rich = xd.p.RichText
						e.font = xd.p.FontFace and tostring_(xd.p.FontFace.Family) or ""
						e.bold = xd.p.FontFace and xd.p.FontFace.Weight and xd.p.FontFace.Weight.Name or "Regular"
					end
					if xd.p.Image ~= nil then
						e.image = xd.p.Image
						e.imageColor = colorOf(xd.p.ImageColor3)
						e.imageT = xd.p.ImageTransparency
					end
					for _, ch in ipairs(xd.children or {}) do
						local cd = ch[DATA]
						if cd.cls.name == "UICorner" then e.corner = { cd.p.CornerRadius.Scale, cd.p.CornerRadius.Offset }
						elseif cd.cls.name == "UIStroke" and cd.p.Enabled ~= false then
							e.stroke = { color = colorOf(cd.p.Color), thickness = cd.p.Thickness, t = cd.p.Transparency, mode = cd.p.ApplyStrokeMode.Name }
						elseif cd.cls.name == "UIGradient" and cd.p.Enabled ~= false then
							local kps = {}
							for _, kp in ipairs(cd.p.Color.Keypoints) do kps[#kps + 1] = { kp.Time, colorOf(kp.Value) } end
							local tks = {}
							for _, kp in ipairs(cd.p.Transparency.Keypoints) do tks[#tks + 1] = { kp.Time, kp.Value } end
							e.gradient = { colors = kps, transp = tks, rot = cd.p.Rotation }
						end
					end
					out[#out + 1] = e
					local nclip = clip
					if xd.p.ClipsDescendants then nclip = { ax, ay, aw, ah } end
					walk(x, depth + 1, layer, nclip)
				end
			end
		end
	end
	walk(pg, 0, 0, nil)
	return out
end

end -- part5
part5()
return mock
