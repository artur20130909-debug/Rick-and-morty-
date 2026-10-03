-- tools/mock/roblox.lua
-- Мок Roblox API для офлайн-прогона Luau-модулей игры в Lua 5.4 (через Python lupa).
-- Что внутри:
--   * типы данных (Vector3, CFrame, Color3, UDim2, ...), Enum, typeof, расширения Luau;
--   * классы Instance со свойствами по умолчанию, проверкой типов и белыми списками свойств;
--   * сигналы, планировщик с виртуальным временем (task.*), службы (Players, RunService,
--     TweenService, Workspace:Raycast, PathfindingService, DataStoreService ...);
--   * удалённые события: сервер и клиент живут в одном состоянии Lua, у каждого потока
--     есть «контекст» (server / client:<игрок>), поэтому RunService:IsServer() честный;
--   * require с кэшем на контекст и поиском циклов.
-- Ошибки потоков копятся в mock.errors (с трассировкой), подозрительные обращения
-- (несуществующие свойства, неизвестные Enum, NaN ...) — в mock.suspicious.

local mock = {}
local MOCK_SRC = "@tools/mock/roblox.lua"
mock.MOCK_SRC = MOCK_SRC

local rawtype, rawget, rawset, rawequal, rawlen = type, rawget, rawset, rawequal, rawlen
local setmt, dgetmt, dgetinfo = setmetatable, debug.getmetatable, debug.getinfo
local tostring_, tonumber, select, next, pairs, ipairs = tostring, tonumber, select, next, pairs, ipairs
local pcall, xpcall, error_ = pcall, xpcall, error
local floor, ceil, sqrt, abs, sin, cos = math.floor, math.ceil, math.sqrt, math.abs, math.sin, math.cos
local atan, acos, asin, huge, pi = math.atan, math.acos, math.asin, math.huge, math.pi
local mmax, mmin, mtype = math.max, math.min, math.type
local co_create, co_resume, co_yield = coroutine.create, coroutine.resume, coroutine.yield
local co_status, co_running, co_close = coroutine.status, coroutine.running, coroutine.close
local tinsert, tremove, tconcat, tunpack, tpack, tsort = table.insert, table.remove, table.concat, table.unpack, table.pack, table.sort
local sformat, ssub, sfind, srep, sbyte, schar = string.format, string.sub, string.find, string.rep, string.byte, string.char
local sgsub, smatch, sgmatch, slower, supper = string.gsub, string.match, string.gmatch, string.lower, string.upper

---------------------------------------------------------------------------
-- 1. Вывод и отчёт
---------------------------------------------------------------------------

mock.now = 0            -- виртуальное время, с
mock.frame = 0
mock.epoch = 1767225600 -- «настоящее» время старта (для tick/os.time)
mock.output = nil       -- function(kind, text) — задаёт Python; иначе print
mock.printEnabled = true
mock.quietDepth = 0     -- >0 — не записывать подозрительное (проверки харнесса)
mock.errors = {}
mock.suspicious = {}
mock.warns = {}
mock.prints = 0

local function emit(kind, text)
	local out = mock.output
	if out then out(kind, text) else print("[" .. kind .. "] " .. text) end
end
mock.emit = emit

-- первый кадр стека, который не принадлежит моку: "src/.../File.lua:123"
local function userLoc(level)
	level = level or 2
	while level < 80 do
		local info = dgetinfo(level, "Sl")
		if not info then return nil end
		local src = info.source
		if src ~= MOCK_SRC and sbyte(src, 1) == 64 then
			return ssub(src, 2) .. ":" .. tostring_(info.currentline)
		end
		level = level + 1
	end
	return nil
end
mock.userLoc = userLoc

-- ошибка «как в Roblox»: позиция указывает на строку пользовательского кода
local function throw(msg)
	local loc = userLoc(2)
	error_(loc and (loc .. ": " .. msg) or msg, 0)
end
mock.throw = throw

-- tostring как в Luau: 10.0 -> "10"
local function luauToString(v)
	if rawtype(v) == "number" and mtype(v) == "float" then
		if v ~= v then return "nan" end
		if v == huge then return "inf" end
		if v == -huge then return "-inf" end
		if v == floor(v) and abs(v) < 1e15 then return sformat("%d", v) end
		return sformat("%.14g", v)
	end
	return tostring_(v)
end
mock.tostring = luauToString

-- трассировка без кадров мока (если ошибка не в самом моке)
local function cleanTb(msg, tb)
	if not tb then return "" end
	local keepMock = sfind(msg, "roblox.lua", 1, true) ~= nil
	local out = {}
	for line in sgmatch(tb, "[^\n]+") do
		local isMock = sfind(line, "tools/mock/roblox.lua", 1, true) ~= nil
		local isC = sfind(line, "[C]:", 1, true) ~= nil
		if line ~= msg and (keepMock or not isMock) and not isC then out[#out + 1] = line end
	end
	return tconcat(out, "\n")
end

local errIndex = {}
local function recordError(msg, tb, ctx)
	msg = luauToString(msg)
	local e = errIndex[msg]
	if e then
		e.count = e.count + 1
		return e
	end
	e = {
		msg = msg, tb = cleanTb(msg, tb), label = ctx and ctx.label or "?", t = mock.now, count = 1,
		cascade = sfind(msg, "Requested module experienced an error while loading", 1, true) ~= nil,
	}
	errIndex[msg] = e
	mock.errors[#mock.errors + 1] = e
	emit("error", sformat("t=%.2f [%s] %s", mock.now, e.label, msg))
	return e
end
mock.recordError = recordError

local suspIndex = {}
local curCtx -- объявлено ниже
local function suspicious(kind, msg, loc)
	if mock.quietDepth > 0 then return end
	loc = loc or userLoc(3)
	if not loc then return end -- обращение из харнесса — не считаем
	local key = kind .. "\0" .. msg .. "\0" .. loc
	local e = suspIndex[key]
	if e then
		e.count = e.count + 1
		return
	end
	e = { kind = kind, msg = msg, loc = loc, count = 1, t = mock.now, ctx = curCtx().label }
	suspIndex[key] = e
	mock.suspicious[#mock.suspicious + 1] = e
	if mock.echoSuspicious then emit("suspicious", sformat("%s %s @ %s", kind, msg, loc)) end
end
mock.suspect = suspicious

local function quiet(fn, ...)
	mock.quietDepth = mock.quietDepth + 1
	local r = tpack(pcall(fn, ...))
	mock.quietDepth = mock.quietDepth - 1
	if not r[1] then error_(r[2], 0) end
	return tunpack(r, 2, r.n)
end
mock.quiet = quiet

local function argsToText(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = luauToString((select(i, ...))) end
	return tconcat(parts, " ")
end

local warnIndex = {}
local function doWarn(...)
	local msg = argsToText(...)
	local loc = userLoc(3) or "?"
	local key = msg .. "\0" .. loc
	local e = warnIndex[key]
	if e then
		e.count = e.count + 1
		return
	end
	e = { msg = msg, loc = loc, count = 1, t = mock.now, ctx = curCtx().label }
	warnIndex[key] = e
	mock.warns[#mock.warns + 1] = e
	emit("warn", sformat("t=%.2f [%s] %s  (%s)", mock.now, e.ctx, msg, loc))
end

local function doPrint(...)
	mock.prints = mock.prints + 1
	if mock.printEnabled then
		emit("print", sformat("t=%.2f [%s] %s", mock.now, curCtx().label, argsToText(...)))
	end
end

---------------------------------------------------------------------------
-- 2. Контексты потоков и планировщик (виртуальное время)
---------------------------------------------------------------------------

-- контекст: { side = "server"|"client", player = Player|nil, label = "...", key = "..." }
local SERVER = { side = "server", label = "server", key = "server" }
mock.SERVER = SERVER
mock.mainCtx = SERVER
local threadCtx = setmt({}, { __mode = "k" })
mock.threadCtx = threadCtx

curCtx = function()
	local co, ismain = co_running()
	if ismain then return mock.mainCtx end
	return threadCtx[co] or mock.mainCtx
end
mock.curCtx = curCtx

local clientCtxs = {}
local function clientCtx(player)
	local c = clientCtxs[player]
	if not c then
		local nm = rawget(player, "__name") or "?"
		c = { side = "client", player = player, label = "client:" .. nm, key = "client:" .. nm }
		clientCtxs[player] = c
	end
	return c
end

-- защита от бесконечных циклов: счётчик инструкций на одно возобновление потока
local budget = setmt({}, { __mode = "k" })
mock.hookEvery = 1000000
mock.hookLimit = 600 -- ×1e6 инструкций без уступки (task.wait) — «Script timeout»
local function hookfn()
	local co = co_running()
	local n = (budget[co] or 0) + 1
	budget[co] = n
	if n > mock.hookLimit then
		budget[co] = 0
		error_("Script timeout: exhausted allowed execution time (цикл без task.wait?)", 2)
	end
end
mock.useHook = true

local function newThread(fn, ctx)
	local co = co_create(fn)
	threadCtx[co] = ctx or curCtx()
	if mock.useHook then debug.sethook(co, hookfn, "", mock.hookEvery) end
	return co
end
mock.newThread = newThread

local function resume(co, ...)
	if co_status(co) ~= "suspended" then return false end
	budget[co] = 0
	local ok, err = co_resume(co, ...)
	if not ok then
		recordError(err, debug.traceback(co, luauToString(err)), threadCtx[co])
	end
	return ok
end
mock.resume = resume

-- куча таймеров (минимум по времени, затем по порядку постановки)
local heap, heapN, heapSeq = {}, 0, 0
local function hless(a, b)
	if a.at ~= b.at then return a.at < b.at end
	return a.seq < b.seq
end
local function hpush(e)
	heapSeq = heapSeq + 1
	e.seq = heapSeq
	heapN = heapN + 1
	local i = heapN
	heap[i] = e
	while i > 1 do
		local p = i // 2
		if hless(heap[i], heap[p]) then
			heap[i], heap[p] = heap[p], heap[i]
			i = p
		else
			break
		end
	end
end
local function hpop()
	if heapN == 0 then return nil end
	local top = heap[1]
	heap[1] = heap[heapN]
	heap[heapN] = nil
	heapN = heapN - 1
	local i = 1
	while true do
		local l, r, s = i * 2, i * 2 + 1, i
		if l <= heapN and hless(heap[l], heap[s]) then s = l end
		if r <= heapN and hless(heap[r], heap[s]) then s = r end
		if s == i then break end
		heap[i], heap[s] = heap[s], heap[i]
		i = s
	end
	return top
end
mock.timer = function(delay, fn) hpush({ at = mock.now + delay, fn = fn }) end
mock.pendingTimers = function() return heapN end

local waitEntry = setmt({}, { __mode = "k" })
local deferQ = {}

local function checkFn(f, what)
	if rawtype(f) ~= "function" and rawtype(f) ~= "thread" then
		throw("invalid argument #1 to '" .. what .. "' (function or thread expected, got " .. rawtype(f) .. ")")
	end
end

local task = {}
function task.spawn(f, ...)
	checkFn(f, "spawn")
	local co = rawtype(f) == "thread" and f or newThread(f, curCtx())
	resume(co, ...)
	return co
end
function task.defer(f, ...)
	checkFn(f, "defer")
	local co = rawtype(f) == "thread" and f or newThread(f, curCtx())
	deferQ[#deferQ + 1] = { co = co, args = tpack(...) }
	return co
end
function task.delay(t, f, ...)
	checkFn(f, "delay")
	local co = rawtype(f) == "thread" and f or newThread(f, curCtx())
	local e = { at = mock.now + mmax(tonumber(t) or 0, 1e-6), co = co, args = tpack(...), kind = "delay" }
	waitEntry[co] = e
	hpush(e)
	return co
end
function task.wait(t)
	local co, ismain = co_running()
	if ismain then throw("attempt to yield from outside a coroutine (task.wait в главном потоке)") end
	t = tonumber(t) or 0
	local e = { at = mock.now + mmax(t, 1e-6), co = co, start = mock.now, kind = "wait" }
	waitEntry[co] = e
	hpush(e)
	return co_yield()
end
function task.cancel(co)
	if rawtype(co) ~= "thread" then throw("invalid argument #1 to 'cancel' (thread expected)") end
	waitEntry[co] = nil
	for _, d in ipairs(deferQ) do if d.co == co then d.cancelled = true end end
	if co_status(co) == "suspended" then co_close(co) end
end
function task.synchronize() end
function task.desynchronize() end
mock.task = task

-- уступить поток до явного пробуждения (сигналы, WaitForChild)
local function yieldUntilWoken()
	local co, ismain = co_running()
	if ismain then throw("attempt to yield from outside a coroutine") end
	return co_yield()
end

-- обработать отложенные потоки (task.defer)
local function runDeferred()
	local guard = 0
	while #deferQ > 0 and guard < 100000 do
		local q = deferQ
		deferQ = {}
		for _, d in ipairs(q) do
			guard = guard + 1
			if not d.cancelled then resume(d.co, tunpack(d.args, 1, d.args.n)) end
		end
	end
end
mock.runDeferred = runDeferred

-- разбудить все потоки, чьё время пришло
local function runTimers()
	local now = mock.now
	while heapN > 0 and heap[1].at <= now do
		local e = hpop()
		if e.fn then
			local ok, err = xpcall(e.fn, debug.traceback)
			if not ok then recordError(err, err, SERVER) end
		elseif waitEntry[e.co] == e then
			waitEntry[e.co] = nil
			if e.kind == "wait" then
				resume(e.co, now - e.start, now)
			else
				resume(e.co, tunpack(e.args, 1, e.args.n))
			end
		end
	end
end
mock.runTimers = runTimers

---------------------------------------------------------------------------
-- 3. typeof и типы данных
---------------------------------------------------------------------------

local function typeof(v)
	local t = rawtype(v)
	if t == "table" then
		local mt = dgetmt(v)
		if mt then
			local tn = rawget(mt, "__type")
			if tn then return tn end
		end
	end
	return t
end
mock.typeof = typeof

local function isMockObj(v)
	if rawtype(v) ~= "table" then return false end
	local mt = dgetmt(v)
	return mt ~= nil and rawget(mt, "__type") ~= nil
end
mock.isMockObj = isMockObj

local LOCKED = "The metatable is locked"

local function dtype(name)
	return { __type = name, __metatable = LOCKED }
end

-- проверка числового аргумента конструктора
local function numArg(v, i, fname)
	if v == nil then return 0 end
	local n = tonumber(v)
	if n == nil then
		throw(sformat("invalid argument #%d to '%s' (number expected, got %s)", i, fname, typeof(v)))
	end
	return n
end

local function arithErr(op, a, b)
	throw(sformat("attempt to perform arithmetic (%s) on %s and %s", op, typeof(a), typeof(b)))
end

local function memberErr(k, tname)
	throw(tostring_(k) .. " is not a valid member of " .. tname)
end

local function fmtn(x)
	return luauToString(x)
end

---------------- Vector3 ----------------
local V3mt = dtype("Vector3")
local V3m = {}
local function v3(x, y, z) return setmt({ X = x, Y = y, Z = z }, V3mt) end
mock.v3 = v3
local Vector3 = {}
function Vector3.new(x, y, z)
	if rawtype(x) ~= "number" then x = numArg(x, 1, "Vector3.new") end
	if rawtype(y) ~= "number" then y = numArg(y, 2, "Vector3.new") end
	if rawtype(z) ~= "number" then z = numArg(z, 3, "Vector3.new") end
	return setmt({ X = x, Y = y, Z = z }, V3mt)
end
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)

local function isV3(v) return dgetmt(v) == V3mt end

local V3get = {
	Magnitude = function(a) return sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z) end,
	Unit = function(a)
		local m = sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
		return v3(a.X / m, a.Y / m, a.Z / m)
	end,
	x = function(a) return a.X end, y = function(a) return a.Y end, z = function(a) return a.Z end,
}
V3get.magnitude = V3get.Magnitude
V3get.unit = V3get.Unit
V3mt.__index = function(t, k)
	local m = V3m[k]
	if m ~= nil then return m end
	local g = V3get[k]
	if g then return g(t) end
	memberErr(k, "Vector3")
end
V3mt.__newindex = function(t, k) throw(tostring_(k) .. " cannot be assigned to") end
V3mt.__add = function(a, b)
	if dgetmt(a) == V3mt and dgetmt(b) == V3mt then return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
	arithErr("add", a, b)
end
V3mt.__sub = function(a, b)
	if dgetmt(a) == V3mt and dgetmt(b) == V3mt then return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
	arithErr("sub", a, b)
end
V3mt.__mul = function(a, b)
	local ma, mb = dgetmt(a), dgetmt(b)
	if ma == V3mt then
		if mb == V3mt then return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
		if rawtype(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	elseif rawtype(a) == "number" and mb == V3mt then
		return v3(a * b.X, a * b.Y, a * b.Z)
	end
	arithErr("mul", a, b)
end
V3mt.__div = function(a, b)
	local ma, mb = dgetmt(a), dgetmt(b)
	if ma == V3mt then
		if mb == V3mt then return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z) end
		if rawtype(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	elseif rawtype(a) == "number" and mb == V3mt then
		return v3(a / b.X, a / b.Y, a / b.Z)
	end
	arithErr("div", a, b)
end
V3mt.__idiv = function(a, b)
	if dgetmt(a) == V3mt and rawtype(b) == "number" then return v3(floor(a.X / b), floor(a.Y / b), floor(a.Z / b)) end
	arithErr("idiv", a, b)
end
V3mt.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3mt.__tostring = function(a) return fmtn(a.X) .. ", " .. fmtn(a.Y) .. ", " .. fmtn(a.Z) end
V3mt.__concat = function(a, b) arithErr("concat", a, b) end

local function needV3(v, fname)
	if dgetmt(v) ~= V3mt then throw("invalid argument to '" .. fname .. "' (Vector3 expected, got " .. typeof(v) .. ")") end
end
function V3m.Lerp(a, b, t)
	needV3(b, "Lerp")
	return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
end
function V3m.Dot(a, b) needV3(b, "Dot"); return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V3m.Cross(a, b)
	needV3(b, "Cross")
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3m.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	return abs(a.X - b.X) <= eps and abs(a.Y - b.Y) <= eps and abs(a.Z - b.Z) <= eps
end
function V3m.Min(a, ...)
	local x, y, z = a.X, a.Y, a.Z
	for i = 1, select("#", ...) do
		local b = select(i, ...)
		x, y, z = mmin(x, b.X), mmin(y, b.Y), mmin(z, b.Z)
	end
	return v3(x, y, z)
end
function V3m.Max(a, ...)
	local x, y, z = a.X, a.Y, a.Z
	for i = 1, select("#", ...) do
		local b = select(i, ...)
		x, y, z = mmax(x, b.X), mmax(y, b.Y), mmax(z, b.Z)
	end
	return v3(x, y, z)
end
local function sign(x) if x > 0 then return 1 elseif x < 0 then return -1 end return 0 end
function V3m.Abs(a) return v3(abs(a.X), abs(a.Y), abs(a.Z)) end
function V3m.Ceil(a) return v3(ceil(a.X), ceil(a.Y), ceil(a.Z)) end
function V3m.Floor(a) return v3(floor(a.X), floor(a.Y), floor(a.Z)) end
function V3m.Sign(a) return v3(sign(a.X), sign(a.Y), sign(a.Z)) end
function V3m.Angle(a, b, axis)
	local c = a:Cross(b)
	local ang = atan(c.Magnitude, a:Dot(b))
	if axis and c:Dot(axis) < 0 then ang = -ang end
	return ang
end
V3m.lerp = V3m.Lerp
V3m.Dot = V3m.Dot
V3m.isClose = V3m.FuzzyEq

---------------- Vector2 ----------------
local V2mt = dtype("Vector2")
local V2m = {}
local function v2(x, y) return setmt({ X = x, Y = y }, V2mt) end
mock.v2 = v2
local Vector2 = {}
function Vector2.new(x, y)
	if rawtype(x) ~= "number" then x = numArg(x, 1, "Vector2.new") end
	if rawtype(y) ~= "number" then y = numArg(y, 2, "Vector2.new") end
	return v2(x, y)
end
Vector2.zero = v2(0, 0)
Vector2.one = v2(1, 1)
Vector2.xAxis = v2(1, 0)
Vector2.yAxis = v2(0, 1)
local V2get = {
	Magnitude = function(a) return sqrt(a.X * a.X + a.Y * a.Y) end,
	Unit = function(a)
		local m = sqrt(a.X * a.X + a.Y * a.Y)
		return v2(a.X / m, a.Y / m)
	end,
	x = function(a) return a.X end, y = function(a) return a.Y end,
}
V2get.magnitude = V2get.Magnitude
V2get.unit = V2get.Unit
V2mt.__index = function(t, k)
	local m = V2m[k]
	if m ~= nil then return m end
	local g = V2get[k]
	if g then return g(t) end
	memberErr(k, "Vector2")
end
V2mt.__newindex = function(t, k) throw(tostring_(k) .. " cannot be assigned to") end
V2mt.__add = function(a, b)
	if dgetmt(a) == V2mt and dgetmt(b) == V2mt then return v2(a.X + b.X, a.Y + b.Y) end
	arithErr("add", a, b)
end
V2mt.__sub = function(a, b)
	if dgetmt(a) == V2mt and dgetmt(b) == V2mt then return v2(a.X - b.X, a.Y - b.Y) end
	arithErr("sub", a, b)
end
V2mt.__mul = function(a, b)
	local ma, mb = dgetmt(a), dgetmt(b)
	if ma == V2mt then
		if mb == V2mt then return v2(a.X * b.X, a.Y * b.Y) end
		if rawtype(b) == "number" then return v2(a.X * b, a.Y * b) end
	elseif rawtype(a) == "number" and mb == V2mt then
		return v2(a * b.X, a * b.Y)
	end
	arithErr("mul", a, b)
end
V2mt.__div = function(a, b)
	local ma, mb = dgetmt(a), dgetmt(b)
	if ma == V2mt then
		if mb == V2mt then return v2(a.X / b.X, a.Y / b.Y) end
		if rawtype(b) == "number" then return v2(a.X / b, a.Y / b) end
	elseif rawtype(a) == "number" and mb == V2mt then
		return v2(a / b.X, a / b.Y)
	end
	arithErr("div", a, b)
end
V2mt.__unm = function(a) return v2(-a.X, -a.Y) end
V2mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
V2mt.__tostring = function(a) return fmtn(a.X) .. ", " .. fmtn(a.Y) end
function V2m.Lerp(a, b, t) return v2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end
function V2m.Dot(a, b) return a.X * b.X + a.Y * b.Y end
function V2m.Cross(a, b) return a.X * b.Y - a.Y * b.X end
function V2m.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	return abs(a.X - b.X) <= eps and abs(a.Y - b.Y) <= eps
end
function V2m.Min(a, b) return v2(mmin(a.X, b.X), mmin(a.Y, b.Y)) end
function V2m.Max(a, b) return v2(mmax(a.X, b.X), mmax(a.Y, b.Y)) end
function V2m.Abs(a) return v2(abs(a.X), abs(a.Y)) end
function V2m.Ceil(a) return v2(ceil(a.X), ceil(a.Y)) end
function V2m.Floor(a) return v2(floor(a.X), floor(a.Y)) end
function V2m.Sign(a) return v2(sign(a.X), sign(a.Y)) end
function V2m.Angle(a, b, signed)
	local ang = atan(a.X * b.Y - a.Y * b.X, a.X * b.X + a.Y * b.Y)
	if not signed then ang = abs(ang) end
	return ang
end

-- int16-варианты (редко нужны): те же векторы с другим именем типа
local V3i16mt = dtype("Vector3int16")
V3i16mt.__index = function(t, k) memberErr(k, "Vector3int16") end
local Vector3int16 = { new = function(x, y, z) return setmt({ X = floor(x or 0), Y = floor(y or 0), Z = floor(z or 0) }, V3i16mt) end }
local V2i16mt = dtype("Vector2int16")
V2i16mt.__index = function(t, k) memberErr(k, "Vector2int16") end
local Vector2int16 = { new = function(x, y) return setmt({ X = floor(x or 0), Y = floor(y or 0) }, V2i16mt) end }

---------------- CFrame ----------------
-- поля: X, Y, Z — позиция; [1..9] — матрица поворота по строкам (r00 r01 r02 r10 ... r22)
local CFmt = dtype("CFrame")
local CFm = {}
local function cfnew(x, y, z, a, b, c, d, e, f, g, h, i)
	return setmt({ X = x, Y = y, Z = z, a, b, c, d, e, f, g, h, i }, CFmt)
end
mock.cfnew = cfnew
local function isCF(v) return dgetmt(v) == CFmt end

local function cfmul(A, B)
	local a1, a2, a3, a4, a5, a6, a7, a8, a9 = A[1], A[2], A[3], A[4], A[5], A[6], A[7], A[8], A[9]
	local b1, b2, b3, b4, b5, b6, b7, b8, b9 = B[1], B[2], B[3], B[4], B[5], B[6], B[7], B[8], B[9]
	local bx, by, bz = B.X, B.Y, B.Z
	return cfnew(
		a1 * bx + a2 * by + a3 * bz + A.X, a4 * bx + a5 * by + a6 * bz + A.Y, a7 * bx + a8 * by + a9 * bz + A.Z,
		a1 * b1 + a2 * b4 + a3 * b7, a1 * b2 + a2 * b5 + a3 * b8, a1 * b3 + a2 * b6 + a3 * b9,
		a4 * b1 + a5 * b4 + a6 * b7, a4 * b2 + a5 * b5 + a6 * b8, a4 * b3 + a5 * b6 + a6 * b9,
		a7 * b1 + a8 * b4 + a9 * b7, a7 * b2 + a8 * b5 + a9 * b8, a7 * b3 + a8 * b6 + a9 * b9)
end
mock.cfmul = cfmul
local function cfinv(A)
	local a1, a2, a3, a4, a5, a6, a7, a8, a9 = A[1], A[2], A[3], A[4], A[5], A[6], A[7], A[8], A[9]
	local x, y, z = A.X, A.Y, A.Z
	return cfnew(
		-(a1 * x + a4 * y + a7 * z), -(a2 * x + a5 * y + a8 * z), -(a3 * x + a6 * y + a9 * z),
		a1, a4, a7, a2, a5, a8, a3, a6, a9)
end
mock.cfinv = cfinv
local function cfpoint(A, x, y, z)
	return A[1] * x + A[2] * y + A[3] * z + A.X, A[4] * x + A[5] * y + A[6] * z + A.Y, A[7] * x + A[8] * y + A[9] * z + A.Z
end
local function cfvec(A, x, y, z)
	return A[1] * x + A[2] * y + A[3] * z, A[4] * x + A[5] * y + A[6] * z, A[7] * x + A[8] * y + A[9] * z
end
local function cfpointInv(A, x, y, z)
	x, y, z = x - A.X, y - A.Y, z - A.Z
	return A[1] * x + A[4] * y + A[7] * z, A[2] * x + A[5] * y + A[8] * z, A[3] * x + A[6] * y + A[9] * z
end
local function cfvecInv(A, x, y, z)
	return A[1] * x + A[4] * y + A[7] * z, A[2] * x + A[5] * y + A[8] * z, A[3] * x + A[6] * y + A[9] * z
end
mock.cfpoint, mock.cfpointInv, mock.cfvec, mock.cfvecInv = cfpoint, cfpointInv, cfvec, cfvecInv

local IDENT = cfnew(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)

local function rotX(a) local c, s = cos(a), sin(a); return 1, 0, 0, 0, c, -s, 0, s, c end
local function rotY(a) local c, s = cos(a), sin(a); return c, 0, s, 0, 1, 0, -s, 0, c end
local function rotZ(a) local c, s = cos(a), sin(a); return c, -s, 0, s, c, 0, 0, 0, 1 end
local function m3(a1, a2, a3, a4, a5, a6, a7, a8, a9, b1, b2, b3, b4, b5, b6, b7, b8, b9)
	return a1 * b1 + a2 * b4 + a3 * b7, a1 * b2 + a2 * b5 + a3 * b8, a1 * b3 + a2 * b6 + a3 * b9,
		a4 * b1 + a5 * b4 + a6 * b7, a4 * b2 + a5 * b5 + a6 * b8, a4 * b3 + a5 * b6 + a6 * b9,
		a7 * b1 + a8 * b4 + a9 * b7, a7 * b2 + a8 * b5 + a9 * b8, a7 * b3 + a8 * b6 + a9 * b9
end
local function anglesXYZ(rx, ry, rz)
	local a1, a2, a3, a4, a5, a6, a7, a8, a9 = m3(rotX(rx), rotY(ry))
	return m3(a1, a2, a3, a4, a5, a6, a7, a8, a9, rotZ(rz))
end
local function anglesYXZ(rx, ry, rz)
	local a1, a2, a3, a4, a5, a6, a7, a8, a9 = m3(rotY(ry), rotX(rx))
	return m3(a1, a2, a3, a4, a5, a6, a7, a8, a9, rotZ(rz))
end

-- кватернионы (для Lerp)
local function toQuat(c)
	local m00, m01, m02, m10, m11, m12, m20, m21, m22 = c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9]
	local tr = m00 + m11 + m22
	local w, x, y, z
	if tr > 0 then
		local s = sqrt(tr + 1) * 2
		w = 0.25 * s; x = (m21 - m12) / s; y = (m02 - m20) / s; z = (m10 - m01) / s
	elseif m00 > m11 and m00 > m22 then
		local s = sqrt(1 + m00 - m11 - m22) * 2
		w = (m21 - m12) / s; x = 0.25 * s; y = (m01 + m10) / s; z = (m02 + m20) / s
	elseif m11 > m22 then
		local s = sqrt(1 + m11 - m00 - m22) * 2
		w = (m02 - m20) / s; x = (m01 + m10) / s; y = 0.25 * s; z = (m12 + m21) / s
	else
		local s = sqrt(1 + m22 - m00 - m11) * 2
		w = (m10 - m01) / s; x = (m02 + m20) / s; y = (m12 + m21) / s; z = 0.25 * s
	end
	return x, y, z, w
end
local function fromQuat(px, py, pz, x, y, z, w)
	local n = sqrt(x * x + y * y + z * z + w * w)
	if n == 0 then return cfnew(px, py, pz, 1, 0, 0, 0, 1, 0, 0, 0, 1) end
	x, y, z, w = x / n, y / n, z / n, w / n
	return cfnew(px, py, pz,
		1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w),
		2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w),
		2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y))
end

local CFrame = {}
local function cfFromLook(px, py, pz, tx, ty, tz, ux, uy, uz)
	local lx, ly, lz = tx - px, ty - py, tz - pz
	local m = sqrt(lx * lx + ly * ly + lz * lz)
	if m < 1e-12 then return cfnew(px, py, pz, 1, 0, 0, 0, 1, 0, 0, 0, 1) end
	lx, ly, lz = lx / m, ly / m, lz / m
	ux, uy, uz = ux or 0, uy or 1, uz or 0
	-- right = look x up
	local rx, ry, rz = ly * uz - lz * uy, lz * ux - lx * uz, lx * uy - ly * ux
	local rm = sqrt(rx * rx + ry * ry + rz * rz)
	if rm < 1e-9 then
		-- взгляд параллелен «вверх»: берём другую ось
		ux, uy, uz = 0, 0, (ly > 0) and 1 or -1
		rx, ry, rz = ly * uz - lz * uy, lz * ux - lx * uz, lx * uy - ly * ux
		rm = sqrt(rx * rx + ry * ry + rz * rz)
	end
	rx, ry, rz = rx / rm, ry / rm, rz / rm
	-- up = right x look
	local vx, vy, vz = ry * lz - rz * ly, rz * lx - rx * lz, rx * ly - ry * lx
	return cfnew(px, py, pz, rx, vx, -lx, ry, vy, -ly, rz, vz, -lz)
end

function CFrame.new(...)
	local n = select("#", ...)
	if n == 0 then return cfnew(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1) end
	local a, b = ...
	if n == 1 or (n == 2 and b == nil) then
		if dgetmt(a) ~= V3mt then throw("invalid argument #1 to 'CFrame.new' (Vector3 expected, got " .. typeof(a) .. ")") end
		return cfnew(a.X, a.Y, a.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	if n == 2 then
		if dgetmt(a) ~= V3mt or dgetmt(b) ~= V3mt then throw("invalid arguments to 'CFrame.new' (Vector3, Vector3 expected)") end
		return cfFromLook(a.X, a.Y, a.Z, b.X, b.Y, b.Z)
	end
	local t = { ... }
	for i = 1, n do
		if rawtype(t[i]) ~= "number" then t[i] = numArg(t[i], i, "CFrame.new") end
	end
	if n == 3 then return cfnew(t[1], t[2], t[3], 1, 0, 0, 0, 1, 0, 0, 0, 1) end
	if n == 7 then return fromQuat(t[1], t[2], t[3], t[4], t[5], t[6], t[7]) end
	if n == 12 then return cfnew(t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8], t[9], t[10], t[11], t[12]) end
	throw("Invalid number of arguments: " .. n .. " (CFrame.new)")
end
CFrame.identity = IDENT
function CFrame.lookAt(at, target, up)
	if not isV3(at) or not isV3(target) then throw("invalid arguments to 'CFrame.lookAt' (Vector3 expected)") end
	return cfFromLook(at.X, at.Y, at.Z, target.X, target.Y, target.Z, up and up.X, up and up.Y, up and up.Z)
end
function CFrame.lookAlong(at, dir, up)
	return cfFromLook(at.X, at.Y, at.Z, at.X + dir.X, at.Y + dir.Y, at.Z + dir.Z, up and up.X, up and up.Y, up and up.Z)
end
function CFrame.Angles(rx, ry, rz)
	rx, ry, rz = numArg(rx, 1, "Angles"), numArg(ry, 2, "Angles"), numArg(rz, 3, "Angles")
	return cfnew(0, 0, 0, anglesXYZ(rx, ry, rz))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(rx, ry, rz)
	rx, ry, rz = numArg(rx, 1, "fromEulerAnglesYXZ"), numArg(ry, 2, "fromEulerAnglesYXZ"), numArg(rz, 3, "fromEulerAnglesYXZ")
	return cfnew(0, 0, 0, anglesYXZ(rx, ry, rz))
end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
function CFrame.fromEulerAngles(rx, ry, rz, order)
	return CFrame.Angles(rx, ry, rz)
end
function CFrame.fromAxisAngle(axis, angle)
	if not isV3(axis) then throw("invalid argument #1 to 'fromAxisAngle' (Vector3 expected)") end
	local m = axis.Magnitude
	local x, y, z = axis.X / m, axis.Y / m, axis.Z / m
	local c, s = cos(angle), sin(angle)
	local t = 1 - c
	return cfnew(0, 0, 0,
		t * x * x + c, t * x * y - s * z, t * x * z + s * y,
		t * x * y + s * z, t * y * y + c, t * y * z - s * x,
		t * x * z - s * y, t * y * z + s * x, t * z * z + c)
end
function CFrame.fromMatrix(pos, vx, vy, vz)
	if not isV3(pos) or not isV3(vx) or not isV3(vy) then throw("invalid arguments to 'CFrame.fromMatrix' (Vector3 expected)") end
	if vz == nil then vz = vx:Cross(vy).Unit end
	return cfnew(pos.X, pos.Y, pos.Z, vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z)
end
function CFrame.fromRotationBetweenVectors(a, b)
	local ua, ub = a.Unit, b.Unit
	local c = ua:Cross(ub)
	local d = ua:Dot(ub)
	if c.Magnitude < 1e-9 then
		if d > 0 then return IDENT end
		local perp = abs(ua.X) < 0.9 and v3(1, 0, 0) or v3(0, 1, 0)
		return CFrame.fromAxisAngle(ua:Cross(perp), pi)
	end
	return CFrame.fromAxisAngle(c, atan(c.Magnitude, d))
end

local CFget = {
	Position = function(c) return v3(c.X, c.Y, c.Z) end,
	LookVector = function(c) return v3(-c[3], -c[6], -c[9]) end,
	RightVector = function(c) return v3(c[1], c[4], c[7]) end,
	UpVector = function(c) return v3(c[2], c[5], c[8]) end,
	ZVector = function(c) return v3(c[3], c[6], c[9]) end,
	Rotation = function(c) return cfnew(0, 0, 0, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9]) end,
	x = function(c) return c.X end, y = function(c) return c.Y end, z = function(c) return c.Z end,
}
CFget.p = CFget.Position
CFget.lookVector = CFget.LookVector
CFget.rightVector = CFget.RightVector
CFget.upVector = CFget.UpVector
CFget.XVector = CFget.RightVector
CFget.YVector = CFget.UpVector
CFmt.__index = function(t, k)
	local m = CFm[k]
	if m ~= nil then return m end
	local g = CFget[k]
	if g then return g(t) end
	memberErr(k, "CFrame")
end
CFmt.__newindex = function(t, k) throw(tostring_(k) .. " cannot be assigned to") end
CFmt.__mul = function(a, b)
	if dgetmt(a) ~= CFmt then arithErr("mul", a, b) end
	local mb = dgetmt(b)
	if mb == CFmt then return cfmul(a, b) end
	if mb == V3mt then return v3(cfpoint(a, b.X, b.Y, b.Z)) end
	arithErr("mul", a, b)
end
CFmt.__add = function(a, b)
	if dgetmt(a) == CFmt and dgetmt(b) == V3mt then
		return cfnew(a.X + b.X, a.Y + b.Y, a.Z + b.Z, a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9])
	end
	arithErr("add", a, b)
end
CFmt.__sub = function(a, b)
	if dgetmt(a) == CFmt and dgetmt(b) == V3mt then
		return cfnew(a.X - b.X, a.Y - b.Y, a.Z - b.Z, a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9])
	end
	arithErr("sub", a, b)
end
CFmt.__eq = function(a, b)
	for i = 1, 9 do if a[i] ~= b[i] then return false end end
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
CFmt.__tostring = function(c)
	local t = { fmtn(c.X), fmtn(c.Y), fmtn(c.Z) }
	for i = 1, 9 do t[#t + 1] = fmtn(c[i]) end
	return tconcat(t, ", ")
end
CFmt.__unm = function(a) arithErr("unm", a, nil) end
CFmt.__div = function(a, b) arithErr("div", a, b) end

function CFm.Inverse(c) return cfinv(c) end
function CFm.GetComponents(c) return c.X, c.Y, c.Z, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9] end
CFm.components = CFm.GetComponents
local function needCF(v, fname)
	if dgetmt(v) ~= CFmt then throw("invalid argument to '" .. fname .. "' (CFrame expected, got " .. typeof(v) .. ")") end
end
function CFm.ToWorldSpace(c, ...)
	local n = select("#", ...)
	if n <= 1 then local b = ...; needCF(b, "ToWorldSpace"); return cfmul(c, b) end
	local out = {}
	for i = 1, n do out[i] = cfmul(c, (select(i, ...))) end
	return tunpack(out, 1, n)
end
function CFm.ToObjectSpace(c, ...)
	local inv = cfinv(c)
	local n = select("#", ...)
	if n <= 1 then local b = ...; needCF(b, "ToObjectSpace"); return cfmul(inv, b) end
	local out = {}
	for i = 1, n do out[i] = cfmul(inv, (select(i, ...))) end
	return tunpack(out, 1, n)
end
local function mapV(c, f, fname, ...)
	local n = select("#", ...)
	if n <= 1 then
		local v = ...
		needV3(v, fname)
		return v3(f(c, v.X, v.Y, v.Z))
	end
	local out = {}
	for i = 1, n do
		local v = select(i, ...)
		needV3(v, fname)
		out[i] = v3(f(c, v.X, v.Y, v.Z))
	end
	return tunpack(out, 1, n)
end
function CFm.PointToWorldSpace(c, ...) return mapV(c, cfpoint, "PointToWorldSpace", ...) end
function CFm.PointToObjectSpace(c, ...) return mapV(c, cfpointInv, "PointToObjectSpace", ...) end
function CFm.VectorToWorldSpace(c, ...) return mapV(c, cfvec, "VectorToWorldSpace", ...) end
function CFm.VectorToObjectSpace(c, ...) return mapV(c, cfvecInv, "VectorToObjectSpace", ...) end
function CFm.toWorldSpace(c, b) return cfmul(c, b) end
function CFm.toObjectSpace(c, b) return cfmul(cfinv(c), b) end
function CFm.pointToObjectSpace(c, v) return v3(cfpointInv(c, v.X, v.Y, v.Z)) end
function CFm.pointToWorldSpace(c, v) return v3(cfpoint(c, v.X, v.Y, v.Z)) end
function CFm.vectorToObjectSpace(c, v) return v3(cfvecInv(c, v.X, v.Y, v.Z)) end
function CFm.vectorToWorldSpace(c, v) return v3(cfvec(c, v.X, v.Y, v.Z)) end

function CFm.ToEulerAnglesXYZ(c)
	local r02 = mmax(-1, mmin(1, c[3]))
	local ry = asin(r02)
	local rx = atan(-c[6], c[9])
	local rz = atan(-c[2], c[1])
	return rx, ry, rz
end
function CFm.ToEulerAnglesYXZ(c)
	local r12 = mmax(-1, mmin(1, c[6]))
	local rx = asin(-r12)
	local ry = atan(c[3], c[9])
	local rz = atan(c[4], c[5])
	return rx, ry, rz
end
CFm.toEulerAnglesXYZ = CFm.ToEulerAnglesXYZ
CFm.ToOrientation = CFm.ToEulerAnglesYXZ
function CFm.ToEulerAngles(c) return CFm.ToEulerAnglesXYZ(c) end
function CFm.ToAxisAngle(c)
	local x, y, z, w = toQuat(c)
	if w > 1 then w = 1 elseif w < -1 then w = -1 end
	local ang = 2 * acos(w)
	local s = sqrt(1 - w * w)
	if s < 1e-9 then return v3(1, 0, 0), 0 end
	return v3(x / s, y / s, z / s), ang
end
CFm.toAxisAngle = CFm.ToAxisAngle
function CFm.Lerp(a, b, t)
	needCF(b, "Lerp")
	local ax, ay, az, aw = toQuat(a)
	local bx, by, bz, bw = toQuat(b)
	local d = ax * bx + ay * by + az * bz + aw * bw
	if d < 0 then bx, by, bz, bw, d = -bx, -by, -bz, -bw, -d end
	local k0, k1
	if d > 0.9995 then
		k0, k1 = 1 - t, t
	else
		local th = acos(d)
		local s = sin(th)
		k0, k1 = sin((1 - t) * th) / s, sin(t * th) / s
	end
	return fromQuat(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t,
		ax * k0 + bx * k1, ay * k0 + by * k1, az * k0 + bz * k1, aw * k0 + bw * k1)
end
CFm.lerp = CFm.Lerp
function CFm.Orthonormalize(c)
	local x = v3(c[1], c[4], c[7]).Unit
	local y = v3(c[2], c[5], c[8])
	y = (y - x * x:Dot(y)).Unit
	local z = x:Cross(y)
	return cfnew(c.X, c.Y, c.Z, x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z)
end
function CFm.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	for i = 1, 9 do if abs(a[i] - b[i]) > eps then return false end end
	return abs(a.X - b.X) <= eps and abs(a.Y - b.Y) <= eps and abs(a.Z - b.Z) <= eps
end
function CFm.AngleBetween(a, b)
	local _, ang = CFm.ToAxisAngle(cfmul(cfinv(a), b))
	return ang
end

---------------- Color3 ----------------
local C3mt = dtype("Color3")
local C3m = {}
local function c3(r, g, b) return setmt({ R = r, G = g, B = b }, C3mt) end
mock.c3 = c3
local Color3 = {}
function Color3.new(r, g, b)
	if rawtype(r) ~= "number" then r = numArg(r, 1, "Color3.new") end
	if rawtype(g) ~= "number" then g = numArg(g, 2, "Color3.new") end
	if rawtype(b) ~= "number" then b = numArg(b, 3, "Color3.new") end
	return c3(r, g, b)
end
function Color3.fromRGB(r, g, b)
	r, g, b = numArg(r, 1, "Color3.fromRGB"), numArg(g, 2, "Color3.fromRGB"), numArg(b, 3, "Color3.fromRGB")
	return c3(r / 255, g / 255, b / 255)
end
function Color3.fromHSV(h, s, v)
	h, s, v = numArg(h, 1, "fromHSV"), numArg(s, 2, "fromHSV"), numArg(v, 3, "fromHSV")
	h = (h % 1) * 6
	local i = floor(h)
	local f = h - i
	local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
	i = i % 6
	if i == 0 then return c3(v, t, p) elseif i == 1 then return c3(q, v, p)
	elseif i == 2 then return c3(p, v, t) elseif i == 3 then return c3(p, q, v)
	elseif i == 4 then return c3(t, p, v) end
	return c3(v, p, q)
end
function Color3.fromHex(hex)
	if rawtype(hex) ~= "string" then throw("invalid argument #1 to 'fromHex' (string expected, got " .. typeof(hex) .. ")") end
	local s = sgsub(hex, "^#", "")
	if #s == 3 then s = sgsub(s, ".", "%0%0") end
	if #s ~= 6 or smatch(s, "[^%x]") then throw("Unable to convert characters to hex value: '" .. hex .. "'") end
	return c3(tonumber(ssub(s, 1, 2), 16) / 255, tonumber(ssub(s, 3, 4), 16) / 255, tonumber(ssub(s, 5, 6), 16) / 255)
end
function Color3.toHSV(c)
	local r, g, b = c.R, c.G, c.B
	local mx, mn = mmax(r, g, b), mmin(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then h = ((g - b) / d) % 6
		elseif mx == g then h = (b - r) / d + 2
		else h = (r - g) / d + 4 end
		h = h / 6
	end
	local s = mx > 0 and d / mx or 0
	return h, s, mx
end
C3m.ToHSV = Color3.toHSV
function C3m.Lerp(a, b, t)
	if dgetmt(b) ~= C3mt then throw("invalid argument #1 to 'Lerp' (Color3 expected, got " .. typeof(b) .. ")") end
	return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function C3m.ToHex(c)
	local function q(x) return mmax(0, mmin(255, floor(x * 255 + 0.5))) end
	return sformat("%02X%02X%02X", q(c.R), q(c.G), q(c.B))
end
local C3get = { r = function(c) return c.R end, g = function(c) return c.G end, b = function(c) return c.B end }
C3mt.__index = function(t, k)
	local m = C3m[k]
	if m ~= nil then return m end
	local g = C3get[k]
	if g then return g(t) end
	memberErr(k, "Color3")
end
C3mt.__newindex = function(t, k) throw(tostring_(k) .. " cannot be assigned to") end
C3mt.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
C3mt.__tostring = function(c) return fmtn(c.R) .. ", " .. fmtn(c.G) .. ", " .. fmtn(c.B) end
C3mt.__add = function(a, b) arithErr("add", a, b) end
C3mt.__mul = function(a, b) arithErr("mul", a, b) end
C3mt.__sub = function(a, b) arithErr("sub", a, b) end

---------------- BrickColor (минимально) ----------------
local BCmt = dtype("BrickColor")
local BRICKS = {
	{ 1, "White", 242, 243, 243 }, { 194, "Medium stone grey", 163, 162, 165 }, { 199, "Dark stone grey", 99, 95, 98 },
	{ 26, "Black", 27, 42, 53 }, { 1003, "Really black", 17, 17, 17 }, { 1001, "Institutional white", 248, 248, 248 },
	{ 21, "Bright red", 196, 40, 28 }, { 1004, "Really red", 255, 0, 0 }, { 23, "Bright blue", 13, 105, 172 },
	{ 1010, "Really blue", 0, 0, 255 }, { 37, "Bright green", 75, 151, 75 }, { 28, "Dark green", 40, 127, 71 },
	{ 24, "Bright yellow", 245, 205, 48 }, { 106, "Bright orange", 218, 133, 65 }, { 192, "Reddish brown", 105, 64, 40 },
	{ 217, "Brown", 124, 92, 70 }, { 1002, "Mid gray", 205, 205, 205 }, { 1005, "Deep orange", 255, 176, 0 },
	{ 1009, "New Yeller", 255, 255, 0 }, { 1020, "Lime green", 0, 255, 0 }, { 1019, "Toothpaste", 0, 255, 255 },
	{ 1032, "Hot pink", 255, 0, 191 }, { 125, "Light orange", 234, 184, 146 }, { 1030, "Pastel brown", 255, 204, 153 },
}
local bcByName, bcByNum = {}, {}
local BCm = {}
local function mkBC(e)
	local b = setmt({ Number = e[1], Name = e[2], Color = c3(e[3] / 255, e[4] / 255, e[5] / 255),
		r = e[3] / 255, g = e[4] / 255, b = e[5] / 255 }, BCmt)
	bcByName[e[2]] = b
	bcByNum[e[1]] = b
	return b
end
for _, e in ipairs(BRICKS) do mkBC(e) end
BCmt.__index = function(t, k) local m = BCm[k]; if m then return m end; memberErr(k, "BrickColor") end
BCmt.__tostring = function(b) return b.Name end
BCmt.__eq = function(a, b) return a.Number == b.Number end
local function nearestBrick(c)
	local best, bd = nil, huge
	for _, b in pairs(bcByNum) do
		local d = (b.Color.R - c.R) ^ 2 + (b.Color.G - c.G) ^ 2 + (b.Color.B - c.B) ^ 2
		if d < bd then best, bd = b, d end
	end
	return best
end
local BrickColor = {}
function BrickColor.new(a, g, b)
	if rawtype(a) == "string" then return bcByName[a] or bcByName["Medium stone grey"] end
	if rawtype(a) == "number" and g == nil then return bcByNum[a] or bcByName["Medium stone grey"] end
	if rawtype(a) == "number" then return nearestBrick(c3(a, g, b)) end
	if dgetmt(a) == C3mt then return nearestBrick(a) end
	return bcByName["Medium stone grey"]
end
BrickColor.random = function() return bcByNum[194] end
BrickColor.palette = function(i) return BRICKS[i] and bcByNum[BRICKS[i][1]] or bcByNum[194] end
for _, nm in ipairs({ "White", "Gray", "DarkGray", "Black", "Red", "Yellow", "Green", "Blue" }) do
	local map = { White = 1, Gray = 194, DarkGray = 199, Black = 26, Red = 21, Yellow = 24, Green = 28, Blue = 23 }
	BrickColor[nm] = function() return bcByNum[map[nm]] end
end
mock.nearestBrick = nearestBrick

---------------- UDim / UDim2 ----------------
local UDmt = dtype("UDim")
local function udim(s, o) return setmt({ Scale = s, Offset = o }, UDmt) end
local UDim = {}
function UDim.new(s, o) return udim(numArg(s, 1, "UDim.new"), numArg(o, 2, "UDim.new")) end
UDmt.__index = function(t, k) memberErr(k, "UDim") end
UDmt.__newindex = function(t, k) throw(tostring_(k) .. " cannot be assigned to") end
UDmt.__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end
UDmt.__tostring = function(a) return fmtn(a.Scale) .. ", " .. fmtn(a.Offset) end
UDmt.__add = function(a, b)
	if dgetmt(a) == UDmt and dgetmt(b) == UDmt then return udim(a.Scale + b.Scale, a.Offset + b.Offset) end
	arithErr("add", a, b)
end
UDmt.__sub = function(a, b)
	if dgetmt(a) == UDmt and dgetmt(b) == UDmt then return udim(a.Scale - b.Scale, a.Offset - b.Offset) end
	arithErr("sub", a, b)
end
UDmt.__unm = function(a) return udim(-a.Scale, -a.Offset) end

local U2mt = dtype("UDim2")
local U2m = {}
local function udim2(xs, xo, ys, yo) return setmt({ X = udim(xs, xo), Y = udim(ys, yo) }, U2mt) end
mock.udim2 = udim2
local UDim2 = {}
function UDim2.new(a, b, c, d)
	if dgetmt(a) == UDmt then
		if dgetmt(b) ~= UDmt then throw("invalid argument #2 to 'UDim2.new' (UDim expected)") end
		return setmt({ X = a, Y = b }, U2mt)
	end
	if rawtype(a) ~= "number" then a = numArg(a, 1, "UDim2.new") end
	if rawtype(b) ~= "number" then b = numArg(b, 2, "UDim2.new") end
	if rawtype(c) ~= "number" then c = numArg(c, 3, "UDim2.new") end
	if rawtype(d) ~= "number" then d = numArg(d, 4, "UDim2.new") end
	return udim2(a, b, c, d)
end
function UDim2.fromScale(x, y) return udim2(numArg(x, 1, "fromScale"), 0, numArg(y, 2, "fromScale"), 0) end
function UDim2.fromOffset(x, y) return udim2(0, numArg(x, 1, "fromOffset"), 0, numArg(y, 2, "fromOffset")) end
local U2get = { Width = function(u) return u.X end, Height = function(u) return u.Y end }
U2mt.__index = function(t, k)
	local m = U2m[k]
	if m then return m end
	local g = U2get[k]
	if g then return g(t) end
	memberErr(k, "UDim2")
end
U2mt.__newindex = function(t, k) throw(tostring_(k) .. " cannot be assigned to") end
U2mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
U2mt.__tostring = function(a)
	return "{" .. fmtn(a.X.Scale) .. ", " .. fmtn(a.X.Offset) .. "}, {" .. fmtn(a.Y.Scale) .. ", " .. fmtn(a.Y.Offset) .. "}"
end
U2mt.__add = function(a, b)
	if dgetmt(a) == U2mt and dgetmt(b) == U2mt then
		return udim2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
	end
	arithErr("add", a, b)
end
U2mt.__sub = function(a, b)
	if dgetmt(a) == U2mt and dgetmt(b) == U2mt then
		return udim2(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
	end
	arithErr("sub", a, b)
end
U2mt.__unm = function(a) return udim2(-a.X.Scale, -a.X.Offset, -a.Y.Scale, -a.Y.Offset) end
U2mt.__mul = function(a, b) arithErr("mul", a, b) end
function U2m.Lerp(a, b, t)
	if dgetmt(b) ~= U2mt then throw("invalid argument #1 to 'Lerp' (UDim2 expected, got " .. typeof(b) .. ")") end
	return udim2(a.X.Scale + (b.X.Scale - a.X.Scale) * t, a.X.Offset + (b.X.Offset - a.X.Offset) * t,
		a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t, a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t)
end

---------------- Rect / NumberRange ----------------
local Rectmt = dtype("Rect")
local Rect = {}
function Rect.new(a, b, c, d)
	local mn, mx
	if dgetmt(a) == V2mt then mn, mx = a, b or a
	else mn, mx = v2(numArg(a, 1, "Rect.new"), numArg(b, 2, "Rect.new")), v2(numArg(c, 3, "Rect.new"), numArg(d, 4, "Rect.new")) end
	return setmt({ Min = mn, Max = mx, Width = mx.X - mn.X, Height = mx.Y - mn.Y }, Rectmt)
end
Rectmt.__index = function(t, k) memberErr(k, "Rect") end
Rectmt.__eq = function(a, b) return a.Min == b.Min and a.Max == b.Max end
Rectmt.__tostring = function(r) return tostring_(r.Min) .. ", " .. tostring_(r.Max) end

local NRmt = dtype("NumberRange")
local NumberRange = {}
function NumberRange.new(a, b)
	a = numArg(a, 1, "NumberRange.new")
	if b == nil then b = a end
	b = numArg(b, 2, "NumberRange.new")
	if b < a then throw("NumberRange: invalid range (max < min)") end
	return setmt({ Min = a, Max = b }, NRmt)
end
NRmt.__index = function(t, k) memberErr(k, "NumberRange") end
NRmt.__eq = function(a, b) return a.Min == b.Min and a.Max == b.Max end
NRmt.__tostring = function(r) return fmtn(r.Min) .. " " .. fmtn(r.Max) end

---------------- NumberSequence / ColorSequence ----------------
local NSKmt = dtype("NumberSequenceKeypoint")
NSKmt.__index = function(t, k) memberErr(k, "NumberSequenceKeypoint") end
local NumberSequenceKeypoint = {}
function NumberSequenceKeypoint.new(t, v, e)
	return setmt({ Time = numArg(t, 1, "NumberSequenceKeypoint.new"), Value = numArg(v, 2, "NumberSequenceKeypoint.new"),
		Envelope = numArg(e, 3, "NumberSequenceKeypoint.new") }, NSKmt)
end
local function checkKeypoints(kps, what)
	if #kps < 2 then throw(what .. ": requires at least 2 keypoints") end
	if kps[1].Time ~= 0 then throw(what .. " time must start at 0, and end at 1") end
	if kps[#kps].Time ~= 1 then throw(what .. " time must start at 0, and end at 1") end
	for i = 2, #kps do
		if kps[i].Time < kps[i - 1].Time then throw(what .. ": keypoints must be ordered by time") end
	end
end
local NSmt = dtype("NumberSequence")
NSmt.__index = function(t, k) memberErr(k, "NumberSequence") end
NSmt.__eq = function(a, b)
	if #a.Keypoints ~= #b.Keypoints then return false end
	for i, k in ipairs(a.Keypoints) do
		local o = b.Keypoints[i]
		if k.Time ~= o.Time or k.Value ~= o.Value or k.Envelope ~= o.Envelope then return false end
	end
	return true
end
local NumberSequence = {}
function NumberSequence.new(a, b)
	local kps
	if rawtype(a) == "table" and not isMockObj(a) then
		kps = {}
		for i, k in ipairs(a) do
			if dgetmt(k) ~= NSKmt then throw("NumberSequence.new: keypoint #" .. i .. " is " .. typeof(k)) end
			kps[i] = k
		end
		checkKeypoints(kps, "NumberSequence")
	else
		a = numArg(a, 1, "NumberSequence.new")
		if b == nil then b = a end
		b = numArg(b, 2, "NumberSequence.new")
		kps = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) }
	end
	return setmt({ Keypoints = kps }, NSmt)
end
local CSKmt = dtype("ColorSequenceKeypoint")
CSKmt.__index = function(t, k) memberErr(k, "ColorSequenceKeypoint") end
local ColorSequenceKeypoint = {}
function ColorSequenceKeypoint.new(t, c)
	if dgetmt(c) ~= C3mt then throw("invalid argument #2 to 'ColorSequenceKeypoint.new' (Color3 expected, got " .. typeof(c) .. ")") end
	return setmt({ Time = numArg(t, 1, "ColorSequenceKeypoint.new"), Value = c }, CSKmt)
end
local CSmt = dtype("ColorSequence")
CSmt.__index = function(t, k) memberErr(k, "ColorSequence") end
local ColorSequence = {}
function ColorSequence.new(a, b)
	local kps
	if dgetmt(a) == C3mt then
		b = b or a
		if dgetmt(b) ~= C3mt then throw("invalid argument #2 to 'ColorSequence.new' (Color3 expected)") end
		kps = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b) }
	elseif rawtype(a) == "table" and not isMockObj(a) then
		kps = {}
		for i, k in ipairs(a) do
			if dgetmt(k) ~= CSKmt then throw("ColorSequence.new: keypoint #" .. i .. " is " .. typeof(k)) end
			kps[i] = k
		end
		checkKeypoints(kps, "ColorSequence")
	else
		throw("invalid argument #1 to 'ColorSequence.new' (Color3 or table expected, got " .. typeof(a) .. ")")
	end
	return setmt({ Keypoints = kps }, CSmt)
end
