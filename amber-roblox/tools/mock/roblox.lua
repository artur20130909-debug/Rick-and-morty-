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

local G = {} -- глобальные имена песочницы скриптов

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

local V2mt, v2, Vector2
do
---------------- Vector2 ----------------
V2mt = dtype("Vector2")
local V2m = {}
function v2(x, y) return setmt({ X = x, Y = y }, V2mt) end
mock.v2 = v2
Vector2 = {}
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

	G.Vector3int16 = Vector3int16
	G.Vector2int16 = Vector2int16
end

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

local anglesXYZ, anglesYXZ, toQuat, fromQuat, cfFromLook
local CFrame = {}
do
local function rotX(a) local c, s = cos(a), sin(a); return 1, 0, 0, 0, c, -s, 0, s, c end
local function rotY(a) local c, s = cos(a), sin(a); return c, 0, s, 0, 1, 0, -s, 0, c end
local function rotZ(a) local c, s = cos(a), sin(a); return c, -s, 0, s, c, 0, 0, 0, 1 end
local function m3(a1, a2, a3, a4, a5, a6, a7, a8, a9, b1, b2, b3, b4, b5, b6, b7, b8, b9)
	return a1 * b1 + a2 * b4 + a3 * b7, a1 * b2 + a2 * b5 + a3 * b8, a1 * b3 + a2 * b6 + a3 * b9,
		a4 * b1 + a5 * b4 + a6 * b7, a4 * b2 + a5 * b5 + a6 * b8, a4 * b3 + a5 * b6 + a6 * b9,
		a7 * b1 + a8 * b4 + a9 * b7, a7 * b2 + a8 * b5 + a9 * b8, a7 * b3 + a8 * b6 + a9 * b9
end
function anglesXYZ(rx, ry, rz)
	local a1, a2, a3, a4, a5, a6, a7, a8, a9 = m3(rotX(rx), rotY(ry))
	return m3(a1, a2, a3, a4, a5, a6, a7, a8, a9, rotZ(rz))
end
function anglesYXZ(rx, ry, rz)
	local a1, a2, a3, a4, a5, a6, a7, a8, a9 = m3(rotY(ry), rotX(rx))
	return m3(a1, a2, a3, a4, a5, a6, a7, a8, a9, rotZ(rz))
end

-- кватернионы (для Lerp)
function toQuat(c)
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
function fromQuat(px, py, pz, x, y, z, w)
	local n = sqrt(x * x + y * y + z * z + w * w)
	if n == 0 then return cfnew(px, py, pz, 1, 0, 0, 0, 1, 0, 0, 0, 1) end
	x, y, z, w = x / n, y / n, z / n, w / n
	return cfnew(px, py, pz,
		1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w),
		2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w),
		2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y))
end

function cfFromLook(px, py, pz, tx, ty, tz, ux, uy, uz)
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

end

local CFget
do
CFget = {
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

end

---------------- Color3 ----------------
local C3mt = dtype("Color3")
local C3m = {}
local c3, Color3
do
function c3(r, g, b) return setmt({ R = r, G = g, B = b }, C3mt) end
mock.c3 = c3
Color3 = {}
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

end

local nearestBrick, BrickColor
do
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
function nearestBrick(c)
	local best, bd = nil, huge
	for _, b in pairs(bcByNum) do
		local d = (b.Color.R - c.R) ^ 2 + (b.Color.G - c.G) ^ 2 + (b.Color.B - c.B) ^ 2
		if d < bd then best, bd = b, d end
	end
	return best
end
BrickColor = {}
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

end

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

do
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

	G.Rect = Rect
	G.NumberRange = NumberRange
	G.NumberSequenceKeypoint = NumberSequenceKeypoint
	G.NumberSequence = NumberSequence
	G.ColorSequenceKeypoint = ColorSequenceKeypoint
	G.ColorSequence = ColorSequence
end

---------------------------------------------------------------------------
-- 4. Enum (ленивые значения; для известных типов — список настоящих имён)
---------------------------------------------------------------------------

local KNOWN_ENUMS = {
	Material = "Plastic SmoothPlastic Neon Wood WoodPlanks Marble Slate Concrete Granite Brick Pebble Cobblestone Rock Sandstone Basalt CrackedLava Limestone Pavement CorrodedMetal DiamondPlate Foil Metal Grass LeafyGrass Sand Fabric Snow Mud Ground Asphalt Salt Ice Glacier Glass ForceField Air Water Cardboard Carpet CeramicTiles ClayRoofTiles RoofShingles Leather Plaster Rubber",
	Font = "Legacy Arial ArialBold SourceSans SourceSansBold SourceSansSemibold SourceSansLight SourceSansItalic Bodoni Garamond Cartoon Code Highway SciFi Arcade Fantasy Antique Gotham GothamMedium GothamBold GothamBlack GothamSemibold AmaticSC Bangers Creepster DenkOne Fondamento FredokaOne GrenzeGotisch IndieFlower JosefinSans Jura Kalam LuckiestGuy Merriweather Michroma Nunito Oswald PatrickHand PermanentMarker Roboto RobotoCondensed RobotoMono Sarpanch SpecialElite TitilliumWeb Ubuntu BuilderSans BuilderSansMedium BuilderSansBold BuilderSansExtraBold Arimo ArimoBold Unknown",
	PartType = "Ball Block Cylinder Wedge CornerWedge",
	NormalId = "Right Top Back Left Bottom Front",
	SurfaceType = "Smooth Glue Weld Studs Inlet Universal Hinge Motor SteppingMotor SmoothNoOutlines",
	EasingStyle = "Linear Sine Back Quad Quart Quint Bounce Elastic Exponential Circular Cubic",
	EasingDirection = "In Out InOut",
	UserInputType = "MouseButton1 MouseButton2 MouseButton3 MouseWheel MouseMovement Touch Keyboard Focus Accelerometer Gyro Gamepad1 Gamepad2 Gamepad3 Gamepad4 Gamepad5 Gamepad6 Gamepad7 Gamepad8 TextInput InputMethod None",
	UserInputState = "Begin Change End Cancel None",
	HumanoidStateType = "FallingDown Ragdoll GettingUp Jumping Swimming Freefall Flying Landed Running RunningNoPhysics StrafingNoPhysics Climbing Seated PlatformStanding Dead Physics None",
	HumanoidRigType = "R6 R15",
	PathStatus = "Success ClosestNoPath ClosestOutOfRange FailStartNotEmpty FailFinishNotEmpty NoPath",
	PathWaypointAction = "Walk Jump Custom",
	RaycastFilterType = "Exclude Include Blacklist Whitelist",
	CameraType = "Fixed Attach Watch Track Follow Custom Scriptable Orbital",
	CameraMode = "Classic LockFirstPerson",
	MouseBehavior = "Default LockCenter LockCurrentPosition",
	ZIndexBehavior = "Global Sibling",
	TextXAlignment = "Left Center Right",
	TextYAlignment = "Top Center Bottom",
	TextTruncate = "None AtEnd SplitWord",
	FillDirection = "Horizontal Vertical",
	SortOrder = "Name Custom LayoutOrder",
	HorizontalAlignment = "Center Left Right",
	VerticalAlignment = "Center Top Bottom",
	ScaleType = "Stretch Slice Tile Fit Crop",
	ApplyStrokeMode = "Contextual Border",
	AutomaticSize = "None X Y XY",
	PlaybackState = "Begin Delayed Playing Paused Completed Cancelled",
	SizeConstraint = "RelativeXY RelativeXX RelativeYY",
	AspectType = "FitWithinMaxSize ScaleWithParentSize",
	DominantAxis = "Width Height",
	SurfaceGuiSizingMode = "FixedSize PixelsPerStud",
	CoreGuiType = "PlayerList Health Backpack Chat All EmotesMenu SelfView Captures",
	ContextActionResult = "Pass Sink",
	ContextActionPriority = "Low Medium Default High",
	FontWeight = "Thin ExtraLight Light Regular Medium SemiBold Bold ExtraBold Heavy",
	FontStyle = "Normal Italic",
	RollOffMode = "Inverse Linear LinearSquare InverseTapered",
	HighlightDepthMode = "AlwaysOnTop Occluded",
	LineJoinMode = "Round Bevel Miter",
	BorderMode = "Outline Middle Inset",
	AnimationPriority = "Idle Movement Action Action2 Action3 Action4 Core",
	MeshType = "Head Torso Wedge Prism Pyramid ParallelRamp RightAngleRamp CornerWedge Brick Sphere Cylinder FileMesh",
	HumanoidDisplayDistanceType = "Viewer Subject None",
	HumanoidHealthDisplayType = "DisplayWhenDamaged AlwaysOn AlwaysOff",
	NameOcclusion = "OccludeAll EnemyOcclusion NoOcclusion",
	ParticleEmitterShape = "Box Sphere Cylinder Disc",
	ParticleOrientation = "FacingCamera FacingCameraWorldUp VelocityParallel VelocityPerpendicular",
	TextureMode = "Stretch Wrap Static",
	ResamplerMode = "Default Pixelated",
	ElasticBehavior = "WhenScrollable Always Never",
	ScrollingDirection = "X Y XY",
	ScrollBarInset = "None ScrollBar Always",
	Technology = "Legacy Voxel Compatibility ShadowMap Future Unified",
	FieldOfViewMode = "Vertical Diagonal MaxAxis",
	StartCorner = "TopLeft TopRight BottomLeft BottomRight",
	ButtonStyle = "Custom RobloxButtonDefault RobloxButton RobloxRoundButton RobloxRoundDefaultButton RobloxRoundDropdownButton",
	FrameStyle = "Custom ChatBlue RobloxSquare RobloxRound ChatGreen ChatRed DropShadow",
	TextDirection = "Auto LeftToRight RightToLeft",
	ExplosionType = "NoCraters Craters",
	DevComputerMovementMode = "UserChoice KeyboardMouse ClickToMove Scriptable",
	DevTouchMovementMode = "UserChoice Thumbstick DPad Thumbpad ClickToMove Scriptable DynamicThumbstick",
	DevCameraOcclusionMode = "Zoom Invisicam",
	ActuatorType = "None Motor Servo",
	RenderFidelity = "Automatic Precise Performance",
	CollisionFidelity = "Default Hull Box PreciseConvexDecomposition",
	DataStoreRequestType = "GetAsync SetIncrementAsync UpdateAsync GetSortedAsync SetIncrementSortedAsync OnUpdate ListAsync GetVersionAsync RemoveVersionAsync",
	ChatVersion = "LegacyChatService TextChatService",
	KeyCode = "Unknown Backspace Tab Clear Return Pause Escape Space QuotedDouble Hash Dollar Percent Ampersand Quote LeftParenthesis RightParenthesis Asterisk Plus Comma Minus Period Slash Zero One Two Three Four Five Six Seven Eight Nine Colon Semicolon LessThan Equals GreaterThan Question At LeftBracket BackSlash RightBracket Caret Underscore Backquote A B C D E F G H I J K L M N O P Q R S T U V W X Y Z LeftCurly Pipe RightCurly Tilde Delete KeypadZero KeypadOne KeypadTwo KeypadThree KeypadFour KeypadFive KeypadSix KeypadSeven KeypadEight KeypadNine KeypadPeriod KeypadDivide KeypadMultiply KeypadMinus KeypadPlus KeypadEnter KeypadEquals Up Down Right Left Insert Home End PageUp PageDown LeftShift RightShift LeftMeta RightMeta LeftAlt RightAlt LeftControl RightControl CapsLock NumLock ScrollLock LeftSuper RightSuper Mode Compose Help Print SysReq Break Menu Power Euro Undo F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12 F13 F14 F15 ButtonX ButtonY ButtonA ButtonB ButtonR1 ButtonL1 ButtonR2 ButtonL2 ButtonR3 ButtonL3 ButtonStart ButtonSelect DPadLeft DPadRight DPadUp DPadDown Thumbstick1 Thumbstick2 MouseLeftButton MouseRightButton MouseMiddleButton MouseBackButton MouseNoButton MouseX MouseY",
}
local ENUM_ALIASES = { RaycastFilterType = { Blacklist = "Exclude", Whitelist = "Include" } }
-- настоящие значения для KeyCode (часто сравнивают .Value)
local KEY_VALUES = { Backspace = 8, Tab = 9, Return = 13, Escape = 27, Space = 32, Zero = 48, One = 49, Two = 50, Three = 51,
	Four = 52, Five = 53, Six = 54, Seven = 55, Eight = 56, Nine = 57, Up = 273, Down = 274, Right = 275, Left = 276,
	LeftShift = 304, RightShift = 303, LeftControl = 306, RightControl = 305, LeftAlt = 308, RightAlt = 307, Unknown = 0 }
for i = 0, 25 do KEY_VALUES[schar(65 + i)] = 97 + i end

local EnumItemMt = dtype("EnumItem")
local EnumTypeMt = dtype("Enum")
local enumTypes = {}
local enumData = setmt({}, { __mode = "k" })

local EnumItemM = {}
function EnumItemM.IsA(item, name) return item.EnumType == enumTypes[name] end
EnumItemMt.__index = function(t, k)
	local m = EnumItemM[k]
	if m then return m end
	memberErr(k, "EnumItem")
end
EnumItemMt.__newindex = function(t, k) throw(tostring_(k) .. " cannot be assigned to") end
EnumItemMt.__tostring = function(t) return "Enum." .. rawget(t, "__typename") .. "." .. t.Name end

local function getEnumItem(et, name, fromUser)
	local d = enumData[et]
	local it = d.items[name]
	if it then return it end
	local alias = ENUM_ALIASES[d.name] and ENUM_ALIASES[d.name][name]
	if alias then
		it = getEnumItem(et, alias, false)
		d.items[name] = it
		return it
	end
	if d.known and not d.known[name] and fromUser then
		suspicious("ENUM", "Enum." .. d.name .. "." .. tostring_(name) .. " не существует в Roblox")
	end
	local val = (d.name == "KeyCode" and KEY_VALUES[name]) or (d.known and d.known[name]) or (d.nextValue)
	if not (d.known and d.known[name]) then d.nextValue = d.nextValue + 1 end
	it = setmt({ Name = name, Value = val, EnumType = et, __typename = d.name }, EnumItemMt)
	d.items[name] = it
	d.list[#d.list + 1] = it
	return it
end

local EnumTypeM = {}
function EnumTypeM.GetEnumItems(et)
	local d = enumData[et]
	if d.known then for _, nm in ipairs(d.knownList) do getEnumItem(et, nm, false) end end
	local out = {}
	for i, it in ipairs(d.list) do out[i] = it end
	return out
end
function EnumTypeM.FromName(et, name) return enumData[et].items[name] end
function EnumTypeM.FromValue(et, v)
	for _, it in ipairs(EnumTypeM.GetEnumItems(et)) do if it.Value == v then return it end end
	return nil
end
EnumTypeMt.__index = function(t, k)
	local m = EnumTypeM[k]
	if m then return m end
	if rawtype(k) ~= "string" then return nil end
	return getEnumItem(t, k, true)
end
EnumTypeMt.__newindex = function(t, k) throw("Enums are read-only") end
EnumTypeMt.__tostring = function(t) return enumData[t].name end

local function getEnumType(name)
	local et = enumTypes[name]
	if et then return et end
	et = setmt({}, EnumTypeMt)
	local d = { name = name, items = {}, list = {}, nextValue = 0 }
	local known = KNOWN_ENUMS[name]
	if known then
		d.known, d.knownList = {}, {}
		local i = 0
		for nm in sgmatch(known, "%S+") do
			d.known[nm] = i
			d.knownList[#d.knownList + 1] = nm
			i = i + 1
		end
		d.nextValue = i + 1000
	end
	enumData[et] = d
	enumTypes[name] = et
	return et
end
local Enum = setmt({}, {
	__type = "Enums", __metatable = LOCKED,
	__index = function(t, k)
		if rawtype(k) ~= "string" then return nil end
		if k == "GetEnums" then return function() local o = {} for _, v in pairs(enumTypes) do o[#o + 1] = v end return o end end
		return getEnumType(k)
	end,
	__newindex = function() throw("Enum is read-only") end,
})
mock.Enum = Enum
local function E(tp, name) return getEnumItem(getEnumType(tp), name, false) end
mock.E = E
local function enumTypeName(item) return rawget(item, "__typename") end

---------------------------------------------------------------------------
-- 5. Прочие типы данных
---------------------------------------------------------------------------

local TweenInfo, Ray, mkray, RaycastParams, OverlapParams, paramsData, raycastResult, PhysicalProperties, Font, mkfont, DateTime, Random, Region3, Faces, Axes, PathWaypoint
do
local TImt = dtype("TweenInfo")
TImt.__index = function(t, k) memberErr(k, "TweenInfo") end
TweenInfo = {}
function TweenInfo.new(time, style, dir, rep, rev, delay)
	if style ~= nil and (typeof(style) ~= "EnumItem" or enumTypeName(style) ~= "EasingStyle") then
		throw("invalid argument #2 to 'TweenInfo.new' (Enum.EasingStyle expected, got " .. typeof(style) .. ")")
	end
	if dir ~= nil and (typeof(dir) ~= "EnumItem" or enumTypeName(dir) ~= "EasingDirection") then
		throw("invalid argument #3 to 'TweenInfo.new' (Enum.EasingDirection expected, got " .. typeof(dir) .. ")")
	end
	return setmt({ Time = numArg(time == nil and 1 or time, 1, "TweenInfo.new"), EasingStyle = style or E("EasingStyle", "Quad"),
		EasingDirection = dir or E("EasingDirection", "Out"), RepeatCount = numArg(rep, 4, "TweenInfo.new"),
		Reverses = rev and true or false, DelayTime = numArg(delay, 6, "TweenInfo.new") }, TImt)
end

local Raymt = dtype("Ray")
local RayM = {}
Ray = {}
function mkray(o, d) return setmt({ Origin = o, Direction = d }, Raymt) end
function Ray.new(o, d)
	needV3(o, "Ray.new")
	needV3(d, "Ray.new")
	return mkray(o, d)
end
function RayM.ClosestPoint(r, p)
	local u = r.Direction.Unit
	local t = mmax(0, (p - r.Origin):Dot(u))
	return r.Origin + u * t
end
function RayM.Distance(r, p) return (p - RayM.ClosestPoint(r, p)).Magnitude end
Raymt.__index = function(t, k)
	if k == "Unit" then return mkray(t.Origin, t.Direction.Unit) end
	local m = RayM[k]
	if m then return m end
	memberErr(k, "Ray")
end

-- RaycastParams / OverlapParams: изменяемые, с проверкой присваиваний
local function filterList(v, what)
	if rawtype(v) ~= "table" or isMockObj(v) then throw(what .. ".FilterDescendantsInstances: table of Instances expected, got " .. typeof(v)) end
	local out = {}
	for i, x in ipairs(v) do
		if typeof(x) ~= "Instance" then throw(what .. ".FilterDescendantsInstances[" .. i .. "] is not an Instance (" .. typeof(x) .. ")") end
		out[i] = x
	end
	return out
end
local function paramsType(tname, defaults)
	local mt = dtype(tname)
	local priv = setmt({}, { __mode = "k" })
	local methods = {
		AddToFilter = function(self, x)
			local d = priv[self]
			if typeof(x) == "Instance" then d.FilterDescendantsInstances[#d.FilterDescendantsInstances + 1] = x
			else for _, i in ipairs(x) do d.FilterDescendantsInstances[#d.FilterDescendantsInstances + 1] = i end end
		end,
	}
	mt.__index = function(t, k)
		local d = priv[t]
		if defaults[k] ~= nil or k == "FilterDescendantsInstances" then
			if k == "FilterDescendantsInstances" then
				local c = {}
				for i, x in ipairs(d[k]) do c[i] = x end
				return c
			end
			return d[k]
		end
		if methods[k] then return methods[k] end
		memberErr(k, tname)
	end
	mt.__newindex = function(t, k, v)
		local d = priv[t]
		if k == "FilterDescendantsInstances" then d[k] = filterList(v, tname) return end
		if k == "FilterType" then
			if typeof(v) ~= "EnumItem" or enumTypeName(v) ~= "RaycastFilterType" then throw(tname .. ".FilterType: Enum.RaycastFilterType expected, got " .. typeof(v)) end
			d[k] = v
			return
		end
		if defaults[k] == nil then memberErr(k, tname) end
		if rawtype(defaults[k]) ~= rawtype(v) then throw(tname .. "." .. k .. ": " .. rawtype(defaults[k]) .. " expected, got " .. typeof(v)) end
		d[k] = v
	end
	local ctor = function(init)
		local o = setmt({}, mt)
		local d = { FilterDescendantsInstances = {} }
		for k, v in pairs(defaults) do d[k] = v end
		priv[o] = d
		if rawtype(init) == "table" then for k, v in pairs(init) do o[k] = v end end
		return o
	end
	return ctor, priv
end
local rpDefaults = { FilterType = true, IgnoreWater = false, CollisionGroup = "Default", RespectCanCollide = false, BruteForceAllSlow = false }
local opDefaults = { FilterType = true, MaxParts = 0, CollisionGroup = "Default", RespectCanCollide = false, BruteForceAllSlow = false }
local newRaycastParams, rpPriv = paramsType("RaycastParams", rpDefaults)
local newOverlapParams, opPriv = paramsType("OverlapParams", opDefaults)
RaycastParams = { new = function(i) local o = newRaycastParams(i); rpPriv[o].FilterType = rpPriv[o].FilterType == true and E("RaycastFilterType", "Exclude") or rpPriv[o].FilterType; return o end }
OverlapParams = { new = function(i) local o = newOverlapParams(i); opPriv[o].FilterType = opPriv[o].FilterType == true and E("RaycastFilterType", "Exclude") or opPriv[o].FilterType; return o end }
function paramsData(p)
	if p == nil then return nil end
	return rpPriv[p] or opPriv[p] or throw("invalid params (RaycastParams/OverlapParams expected, got " .. typeof(p) .. ")")
end

local RRmt = dtype("RaycastResult")
RRmt.__index = function(t, k) memberErr(k, "RaycastResult") end
function raycastResult(inst, pos, normal, material, dist)
	return setmt({ Instance = inst, Position = pos, Normal = normal, Material = material, Distance = dist }, RRmt)
end

local PPmt = dtype("PhysicalProperties")
PPmt.__index = function(t, k) memberErr(k, "PhysicalProperties") end
PhysicalProperties = {}
function PhysicalProperties.new(a, f, e, fw, ew)
	if typeof(a) == "EnumItem" then return setmt({ Density = 0.7, Friction = 0.3, Elasticity = 0.5, FrictionWeight = 1, ElasticityWeight = 1 }, PPmt) end
	return setmt({ Density = numArg(a, 1, "PhysicalProperties.new"), Friction = numArg(f or 0.3, 2, "PhysicalProperties.new"),
		Elasticity = numArg(e or 0.5, 3, "PhysicalProperties.new"), FrictionWeight = fw or 1, ElasticityWeight = ew or 1 }, PPmt)
end

local Fontmt = dtype("Font")
Font = {}
function mkfont(fam, w, s)
	return setmt({ Family = fam, Weight = w or E("FontWeight", "Regular"), Style = s or E("FontStyle", "Normal") }, Fontmt)
end
Fontmt.__index = function(t, k)
	if k == "Bold" then return t.Weight == E("FontWeight", "Bold") end
	memberErr(k, "Font")
end
Fontmt.__eq = function(a, b) return a.Family == b.Family and a.Weight == b.Weight and a.Style == b.Style end
function Font.new(fam, w, s)
	if rawtype(fam) ~= "string" then throw("invalid argument #1 to 'Font.new' (string expected, got " .. typeof(fam) .. ")") end
	return mkfont(fam, w, s)
end
function Font.fromEnum(e)
	if typeof(e) ~= "EnumItem" or enumTypeName(e) ~= "Font" then throw("invalid argument #1 to 'Font.fromEnum' (Enum.Font expected, got " .. typeof(e) .. ")") end
	return mkfont("rbxasset://fonts/families/" .. e.Name .. ".json")
end
function Font.fromName(n, w, s) return mkfont("rbxasset://fonts/families/" .. tostring_(n) .. ".json", w, s) end
function Font.fromId(id, w, s) return mkfont("rbxassetid://" .. tostring_(id), w, s) end

local DTmt = dtype("DateTime")
local DTm = {}
DTmt.__index = function(t, k)
	if k == "UnixTimestamp" then return floor(rawget(t, "ms") / 1000) end
	if k == "UnixTimestampMillis" then return rawget(t, "ms") end
	local m = DTm[k]
	if m then return m end
	memberErr(k, "DateTime")
end
local function mkdt(ms) return setmt({ ms = floor(ms) }, DTmt) end
DateTime = {}
function DateTime.now() return mkdt((mock.epoch + mock.now) * 1000) end
function DateTime.fromUnixTimestamp(s) return mkdt(numArg(s, 1, "fromUnixTimestamp") * 1000) end
function DateTime.fromUnixTimestampMillis(ms) return mkdt(numArg(ms, 1, "fromUnixTimestampMillis")) end
function DateTime.fromUniversalTime(y, mo, d, h, mi, s, ms)
	local t = os.time({ year = y or 1970, month = mo or 1, day = d or 1, hour = h or 0, min = mi or 0, sec = s or 0, isdst = false })
	return mkdt(t * 1000 + (ms or 0))
end
DateTime.fromLocalTime = DateTime.fromUniversalTime
function DateTime.fromIsoDate(s)
	local y, mo, d, h, mi, se = smatch(tostring_(s), "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
	if not y then return nil end
	return DateTime.fromUniversalTime(tonumber(y), tonumber(mo), tonumber(d), tonumber(h), tonumber(mi), tonumber(se))
end
function DTm.ToUniversalTime(t)
	local ms = rawget(t, "ms")
	local d = os.date("!*t", floor(ms / 1000))
	return { Year = d.year, Month = d.month, Day = d.day, Hour = d.hour, Minute = d.min, Second = d.sec, Millisecond = ms % 1000 }
end
DTm.ToLocalTime = DTm.ToUniversalTime
function DTm.ToIsoDate(t) return os.date("!%Y-%m-%dT%H:%M:%SZ", floor(rawget(t, "ms") / 1000)) end
function DTm.FormatUniversalTime(t, fmt)
	local u = DTm.ToUniversalTime(t)
	local s = tostring_(fmt or "")
	s = sgsub(s, "YYYY", sformat("%04d", u.Year))
	s = sgsub(s, "MM", sformat("%02d", u.Month))
	s = sgsub(s, "DD", sformat("%02d", u.Day))
	s = sgsub(s, "HH", sformat("%02d", u.Hour))
	s = sgsub(s, "mm", sformat("%02d", u.Minute))
	s = sgsub(s, "ss", sformat("%02d", u.Second))
	return s
end
DTm.FormatLocalTime = DTm.FormatUniversalTime

-- Random: xorshift64*, детерминированный от seed
local Rndmt = dtype("Random")
local RndM = {}
Rndmt.__index = function(t, k) local m = RndM[k]; if m then return m end; memberErr(k, "Random") end
local function rndNext(r)
	local x = rawget(r, "s")
	x = x ~ (x << 13)
	x = x ~ (x >> 7)
	x = x ~ (x << 17)
	rawset(r, "s", x)
	return x
end
Random = {}
local randSeedCounter = 7
function Random.new(seed)
	if seed == nil then
		randSeedCounter = randSeedCounter + 1
		seed = randSeedCounter * 7919
	end
	local s = floor(numArg(seed, 1, "Random.new"))
	if s == 0 then s = 88172645463325252 end
	local r = setmt({ s = s ~ 0x5DEECE66D }, Rndmt)
	for _ = 1, 4 do rndNext(r) end
	return r
end
function RndM.NextNumber(r, a, b)
	local u = ((rndNext(r) >> 11) & 0x1FFFFFFFFFFFFF) / 9007199254740992.0
	if a == nil then return u end
	return a + (b - a) * u
end
function RndM.NextInteger(r, a, b)
	a, b = floor(numArg(a, 1, "NextInteger")), floor(numArg(b, 2, "NextInteger"))
	if b < a then throw("invalid argument #2 to 'NextInteger' (interval is empty)") end
	return a + ((rndNext(r) >> 1) % (b - a + 1))
end
function RndM.NextUnitVector(r)
	local z = RndM.NextNumber(r, -1, 1)
	local th = RndM.NextNumber(r, 0, 2 * pi)
	local s = sqrt(1 - z * z)
	return v3(s * cos(th), s * sin(th), z)
end
function RndM.Shuffle(r, t)
	for i = #t, 2, -1 do
		local j = RndM.NextInteger(r, 1, i)
		t[i], t[j] = t[j], t[i]
	end
end
function RndM.Clone(r) return setmt({ s = rawget(r, "s") }, Rndmt) end

local R3mt = dtype("Region3")
R3mt.__index = function(t, k) memberErr(k, "Region3") end
Region3 = {}
function Region3.new(a, b)
	return setmt({ CFrame = CFrame.new((a + b) / 2), Size = b - a, Min = a, Max = b }, R3mt)
end

local Facesmt = dtype("Faces")
Facesmt.__index = function(t, k) return false end
Faces = { new = function(...) local o = {}; for _, f in ipairs({ ... }) do o[f.Name] = true end; return setmt(o, Facesmt) end }
local Axesmt = dtype("Axes")
Axesmt.__index = function(t, k) return false end
Axes = { new = function(...) local o = {}; for _, f in ipairs({ ... }) do o[f.Name] = true end; return setmt(o, Axesmt) end }

local PWmt = dtype("PathWaypoint")
PWmt.__index = function(t, k) memberErr(k, "PathWaypoint") end
PathWaypoint = {}
function PathWaypoint.new(pos, action, label)
	needV3(pos, "PathWaypoint.new")
	return setmt({ Position = pos, Action = action or E("PathWaypointAction", "Walk"), Label = label or "" }, PWmt)
end

	G.TweenInfo = TweenInfo
	G.Ray = Ray
	G.RaycastParams = RaycastParams
	G.OverlapParams = OverlapParams
	G.PhysicalProperties = PhysicalProperties
	G.Font = Font
	G.DateTime = DateTime
	G.Random = Random
	G.Region3 = Region3
	G.Faces = Faces
	G.Axes = Axes
	G.PathWaypoint = PathWaypoint
end

-- общие наборы для проверки типов свойств
mock.types = {
	V3mt = V3mt, V2mt = V2mt, CFmt = CFmt, C3mt = C3mt, U2mt = U2mt, UDmt = UDmt,
}

-- разделы 6+ — в отдельных функциях (у каждой свой лимит в 200 локальных)
local I = {} -- внутреннее API между разделами файла
mock.I = I
local function part2()

---------------------------------------------------------------------------
-- 6. Сигналы
---------------------------------------------------------------------------

local SigMt = dtype("RBXScriptSignal")
local ConnMt = dtype("RBXScriptConnection")
local SigM, ConnM = {}, {}
SigMt.__index = function(t, k)
	local m = SigM[k]
	if m then return m end
	memberErr(k, "RBXScriptSignal")
end
SigMt.__tostring = function(s) return "Signal " .. tostring_(rawget(s, "name")) end
ConnMt.__index = function(t, k)
	local m = ConnM[k]
	if m then return m end
	memberErr(k, "RBXScriptConnection")
end

local function newSignal(name, owner)
	return setmt({ name = name, owner = owner, conns = {}, depth = 0 }, SigMt)
end
I.newSignal = newSignal

local function compact(sig)
	local out = {}
	for _, c in ipairs(sig.conns) do if c.Connected then out[#out + 1] = c end end
	sig.conns = out
	sig.dirty = false
end

function SigM.Connect(sig, fn)
	if rawtype(fn) ~= "function" then throw("Attempt to connect failed: Passed value is not a function") end
	local ctx = curCtx()
	local hook = rawget(sig, "onConnect")
	if hook then hook(sig, ctx) end
	local c = setmt({ Connected = true, fn = fn, ctx = ctx, sig = sig }, ConnMt)
	local conns = sig.conns
	conns[#conns + 1] = c
	return c
end
function SigM.Once(sig, fn)
	if rawtype(fn) ~= "function" then throw("Attempt to connect failed: Passed value is not a function") end
	local c
	c = SigM.Connect(sig, function(...)
		ConnM.Disconnect(c)
		return fn(...)
	end)
	return c
end
function SigM.Wait(sig)
	local co, ismain = co_running()
	if ismain then throw("attempt to yield from outside a coroutine (Signal:Wait)") end
	local w = rawget(sig, "waiters")
	if not w then
		w = {}
		sig.waiters = w
	end
	w[#w + 1] = co
	return co_yield()
end
function SigM.ConnectParallel(sig, fn) return SigM.Connect(sig, fn) end
SigM.connect = SigM.Connect
SigM.wait = SigM.Wait
function ConnM.Disconnect(c)
	if c.Connected then
		c.Connected = false
		local sig = c.sig
		sig.dirty = true
		if sig.depth == 0 then compact(sig) end
	end
end
ConnM.disconnect = ConnM.Disconnect

-- запуск обработчиков: каждый — в своём потоке со своим контекстом (как в Roblox)
local function fireSignal(sig, filter, ...)
	local conns = sig.conns
	local n = #conns
	if n > 0 then
		sig.depth = sig.depth + 1
		for i = 1, n do
			local c = conns[i]
			if c.Connected and (filter == nil or filter(c.ctx)) then
				resume(newThread(c.fn, c.ctx), ...)
			end
		end
		sig.depth = sig.depth - 1
		if sig.dirty and sig.depth == 0 then compact(sig) end
	end
	local w = rawget(sig, "waiters")
	if w then
		sig.waiters = nil
		for i = 1, #w do
			local co = w[i]
			if filter == nil or filter(threadCtx[co] or mock.mainCtx) then resume(co, ...)
			else
				local nw = rawget(sig, "waiters") or {}
				nw[#nw + 1] = co
				sig.waiters = nw
			end
		end
	end
end
I.fireSignal = fireSignal
local function disconnectAll(sig)
	for _, c in ipairs(sig.conns) do c.Connected = false end
	sig.conns = {}
end
local function signalHasListeners(sig)
	return sig and (#sig.conns > 0 or rawget(sig, "waiters") ~= nil)
end
I.signalHasListeners = signalHasListeners

-- простой сигнал для служб: obj[name] — объект сигнала
mock.signal = newSignal
mock.fire = function(sig, ...) fireSignal(sig, nil, ...) end

---------------------------------------------------------------------------
-- 7. Ядро Instance
---------------------------------------------------------------------------

local DATA = setmt({}, { __tostring = function() return "<DATA>" end })
mock.DATA = DATA
local classes = {}
mock.classes = classes
local eventCount = {}
local nextId = 0
mock.created = {} -- класс -> сколько создано

local function isInst(v) return rawtype(v) == "table" and rawget(v, DATA) ~= nil end
I.isInst = isInst
mock.isInst = isInst

local function fullName(inst)
	if not isInst(inst) then return tostring_(inst) end
	local parts = {}
	local a = inst
	local guard = 0
	while a and guard < 100 do
		local d = a[DATA]
		if d.cls.name == "DataModel" then break end
		tinsert(parts, 1, d.p.Name)
		a = d.parent
		guard = guard + 1
	end
	return tconcat(parts, ".")
end
I.fullName = fullName
mock.fullName = fullName

local function isA(inst, cname) return inst[DATA].cls.isa[cname] == true end
I.isA = isA

local function specOf(v)
	local t = typeof(v)
	if t == "EnumItem" then return "E:" .. enumTypeName(v) end
	if t == "nil" then return true end
	return t
end
local function N(spec) return { __nilspec = spec } end
I.N = N

local function specName(spec)
	if rawtype(spec) ~= "string" then return "value" end
	if ssub(spec, 1, 2) == "E:" then return "Enum." .. ssub(spec, 3) end
	return spec
end

-- приведение значения к типу свойства (или ошибка «как в Roblox»)
local function coerce(k, spec, v)
	if spec == true or spec == "any" then return v end
	local tv = rawtype(v)
	if tv == spec then return v end
	if tv == "table" then
		local mt = dgetmt(v)
		local tn = mt and rawget(mt, "__type")
		if tn == spec then return v end
		if tn == "Instance" and ssub(spec, 1, 8) == "Instance" then
			if #spec > 9 then
				local need = ssub(spec, 10)
				if not isA(v, need) then
					throw(sformat("Unable to assign property %s. %s expected, got %s", k, need, v[DATA].cls.name))
				end
			end
			return v
		end
		if tn == "EnumItem" and ssub(spec, 1, 2) == "E:" then
			if enumTypeName(v) == ssub(spec, 3) then return v end
			throw(sformat("Unable to assign property %s. Expected Enum.%s, got Enum.%s", k, ssub(spec, 3), enumTypeName(v)))
		end
	elseif v == nil then
		if ssub(spec, 1, 8) == "Instance" or spec == "function" or spec == "nilable" then return nil end
	elseif spec == "number" and tv == "string" then
		local n = tonumber(v)
		if n then return n end
	elseif spec == "string" and tv == "number" then
		return luauToString(v)
	elseif ssub(spec, 1, 2) == "E:" then
		local et = getEnumType(ssub(spec, 3))
		if tv == "string" then return getEnumItem(et, v, true) end
		if tv == "number" then
			local it = EnumTypeM.FromValue(et, v)
			if it then return it end
		end
	elseif spec == "nilable" then
		return v
	end
	throw(sformat("Unable to assign property %s. %s expected, got %s", k, specName(spec), typeof(v)))
end
I.coerce = coerce

local function getEvent(self, d, k)
	local sig = d.sig
	if not sig then
		sig = {}
		d.sig = sig
	end
	local s = sig[k]
	if not s then
		s = newSignal(k, self)
		local hk = d.cls.eventInit and d.cls.eventInit[k]
		if hk then hk(s, self, d) end
		sig[k] = s
		eventCount[k] = (eventCount[k] or 0) + 1
	end
	return s
end
I.getEvent = getEvent
local function fireEvent(d, k, ...)
	local sig = d.sig
	if not sig then return end
	local s = sig[k]
	if s then fireSignal(s, nil, ...) end
end
I.fireEvent = fireEvent

local function propChanged(self, d, k)
	local ps = d.psig and d.psig[k]
	if ps then fireSignal(ps, nil) end
	local ch = d.sig.Changed
	if ch then
		if d.cls.valueChanged then
			if k == "Value" then fireSignal(ch, nil, d.p.Value) end
		else
			fireSignal(ch, nil, k)
		end
	end
end
I.propChanged = propChanged

local function findChild(d, name)
	local ch = d.children
	if not ch then return nil end
	for i = 1, #ch do
		local c = ch[i]
		if c[DATA].p.Name == name then return c end
	end
	return nil
end
I.findChild = findChild

mock.lastMissing = nil
local function serverOnlyHidden(d)
	return d.serverOnly and curCtx().side == "client"
end
I.serverOnlyHidden = serverOnlyHidden

local function makeIndex(cls)
	local getters, types, methods, events, cname, generic = cls.getters, cls.types, cls.methods, cls.events, cls.name, cls.generic
	return function(self, k)
		local d = self[DATA]
		local g = getters[k]
		if g then return g(self, d) end
		if types[k] ~= nil then return d.p[k] end
		local m = methods[k]
		if m then return m end
		if events[k] then return getEvent(self, d, k) end
		if d.children then
			if serverOnlyHidden(d) then
				suspicious("REPLICATION", "клиент читает " .. fullName(self) .. "." .. tostring_(k) .. " — содержимое " .. cname .. " не видно клиенту")
				return nil
			end
			local c = findChild(d, k)
			if c then return c end
		end
		local v = d.p[k]
		if v ~= nil then return v end
		if rawtype(k) == "string" then
			mock.lastMissing = fullName(self) .. "." .. k
			if not generic then
				suspicious("READ", cname .. "." .. k .. " — нет такого свойства/метода/ребёнка у " .. fullName(self) .. " (в Roblox ошибка)")
			end
		end
		return nil
	end
end

local function makeNewIndex(cls)
	local setters, getters, types, methods, events, cname, generic = cls.setters, cls.getters, cls.types, cls.methods, cls.events, cls.name, cls.generic
	return function(self, k, v)
		local d = self[DATA]
		local s = setters[k]
		if s then
			s(self, d, v)
			return
		end
		local spec = types[k]
		if spec ~= nil then
			if getters[k] then throw("Unable to assign property " .. tostring_(k) .. ". Property is read only") end
			if spec ~= true and rawtype(v) ~= spec then v = coerce(k, spec, v) end
			if v ~= v then suspicious("NAN", cname .. "." .. k .. " = NaN") end
			local p = d.p
			if p[k] ~= v then
				p[k] = v
				if d.sig then propChanged(self, d, k) end
			end
			return
		end
		if getters[k] then throw("Unable to assign property " .. tostring_(k) .. ". Property is read only") end
		if methods[k] or events[k] then throw("Unable to assign property " .. tostring_(k) .. " — это метод/событие " .. cname) end
		if not generic then
			suspicious("WRITE", cname .. "." .. tostring_(k) .. " = " .. typeof(v) .. " — нет такого свойства (в Roblox ошибка)")
		end
		d.p[k] = v
		if d.sig then propChanged(self, d, k) end
	end
end

local function copyInto(dst, src) for k, v in pairs(src) do dst[k] = v end end

-- описание класса: props = значения по умолчанию (N"тип" — по умолчанию nil),
-- get/set — вычисляемые свойства, methods, events = { "Имя", ... }, init(self, d)
local function defclass(name, superName, spec)
	spec = spec or {}
	local super = superName and classes[superName]
	if superName and not super then error("mock: unknown superclass " .. superName .. " for " .. name) end
	local cls = { name = name, super = super, defaults = {}, types = {}, getters = {}, setters = {}, methods = {},
		events = {}, isa = {}, eventInit = {}, initChain = {} }
	if super then
		copyInto(cls.defaults, super.defaults)
		copyInto(cls.types, super.types)
		copyInto(cls.getters, super.getters)
		copyInto(cls.setters, super.setters)
		copyInto(cls.methods, super.methods)
		copyInto(cls.events, super.events)
		copyInto(cls.isa, super.isa)
		copyInto(cls.eventInit, super.eventInit)
		for _, f in ipairs(super.initChain) do cls.initChain[#cls.initChain + 1] = f end
		cls.wsHook = super.wsHook
		cls.onDestroy = super.onDestroy
		cls.valueChanged = super.valueChanged
		cls.onClone = super.onClone
	end
	cls.isa[name] = true
	for k, v in pairs(spec.props or {}) do
		if rawtype(v) == "table" and rawget(v, "__nilspec") then
			cls.types[k] = v.__nilspec
			cls.defaults[k] = nil
		else
			cls.types[k] = specOf(v)
			cls.defaults[k] = v
		end
	end
	for k, f in pairs(spec.get or {}) do cls.getters[k] = f end
	for k, f in pairs(spec.set or {}) do cls.setters[k] = f end
	for k, f in pairs(spec.methods or {}) do cls.methods[k] = f end
	for _, e in ipairs(spec.events or {}) do cls.events[e] = true end
	for k, f in pairs(spec.eventInit or {}) do cls.eventInit[k] = f end
	if spec.init then cls.initChain[#cls.initChain + 1] = spec.init end
	if spec.wsHook then cls.wsHook = spec.wsHook end
	if spec.onDestroy then cls.onDestroy = spec.onDestroy end
	if spec.onClone then cls.onClone = spec.onClone end
	if spec.valueChanged then cls.valueChanged = true end
	cls.noCreate = spec.noCreate
	cls.service = spec.service
	cls.generic = spec.generic
	cls.mt = {
		__type = "Instance", __metatable = LOCKED,
		__index = makeIndex(cls), __newindex = makeNewIndex(cls),
		__tostring = function(self) return self[DATA].p.Name end,
	}
	classes[name] = cls
	return cls
end
I.defclass = defclass
mock.defclass = defclass

local function isKnownProp(cls, k)
	return cls.types[k] ~= nil or cls.getters[k] ~= nil or cls.setters[k] ~= nil
end
I.isKnownProp = isKnownProp

local function newInstance(cls)
	local p = {}
	for k, v in next, cls.defaults do p[k] = v end
	p.Name = cls.name
	nextId = nextId + 1
	local d = { cls = cls, p = p, id = nextId }
	local self = setmt({ [DATA] = d }, cls.mt)
	d.self = self
	local ic = cls.initChain
	for i = 1, #ic do ic[i](self, d) end
	mock.created[cls.name] = (mock.created[cls.name] or 0) + 1
	return self
end
I.newInstance = newInstance

-- обход потомков (в глубину, по порядку)
local function eachDesc(inst, fn)
	local ch = inst[DATA].children
	if not ch then return end
	for i = 1, #ch do
		local c = ch[i]
		fn(c)
		eachDesc(c, fn)
	end
end
I.eachDesc = eachDesc

-- признак «в workspace» поддерживается для всех экземпляров (нужен индексу деталей)
local workspaceInst
local function markInWs(self, d, val)
	d.inWs = val
	local h = d.cls.wsHook
	if h then h(self, d, val) end
	local ch = d.children
	if ch then
		for i = 1, #ch do
			local c = ch[i]
			markInWs(c, c[DATA], val)
		end
	end
end

local function checkWaiters(parent, pd, child)
	local ws = pd.waiters
	local name = child[DATA].p.Name
	for i = #ws, 1, -1 do
		local w = ws[i]
		if w.name == name then
			tremove(ws, i)
			w.done = true
			resume(w.co, child)
		end
	end
end
I.checkWaiters = checkWaiters

local function fireDescRemoving(op, self)
	local a = op
	while a do
		local ad = a[DATA]
		local s = ad.sig and ad.sig.DescendantRemoving
		if s then
			fireSignal(s, nil, self)
			eachDesc(self, function(x) fireSignal(s, nil, x) end)
		end
		a = ad.parent
	end
end

local function setParentRaw(self, d, np)
	local op = d.parent
	if op == np then return end
	if op then
		local od = op[DATA]
		if eventCount.DescendantRemoving then fireDescRemoving(op, self) end
		local ch = od.children
		for i = #ch, 1, -1 do
			if ch[i] == self then
				tremove(ch, i)
				break
			end
		end
		fireEvent(od, "ChildRemoved", self)
	end
	d.parent = np
	if np then
		local nd = np[DATA]
		local ch = nd.children
		if not ch then
			ch = {}
			nd.children = ch
		end
		ch[#ch + 1] = self
	end
	local nowIn = false
	if np then nowIn = np[DATA].inWs or np == workspaceInst end
	if (d.inWs or false) ~= nowIn then markInWs(self, d, nowIn) end
	if d.sig then propChanged(self, d, "Parent") end
	if eventCount.AncestryChanged then
		local s = d.sig and d.sig.AncestryChanged
		if s then fireSignal(s, nil, self, np) end
		eachDesc(self, function(x)
			local xd = x[DATA]
			local xs = xd.sig and xd.sig.AncestryChanged
			if xs then fireSignal(xs, nil, self, np) end
		end)
	end
	if np then
		local nd = np[DATA]
		fireEvent(nd, "ChildAdded", self)
		if nd.waiters then checkWaiters(np, nd, self) end
		if eventCount.DescendantAdded then
			local a = np
			while a do
				local ad = a[DATA]
				local s = ad.sig and ad.sig.DescendantAdded
				if s then
					fireSignal(s, nil, self)
					eachDesc(self, function(x) fireSignal(s, nil, x) end)
				end
				a = ad.parent
			end
		end
	end
	local hk = d.cls.onParent
	if hk then hk(self, d, op, np) end
end
I.setParentRaw = setParentRaw

local function setParent(self, d, np)
	if np ~= nil and not isInst(np) then
		throw("Unable to assign property Parent. Instance expected, got " .. typeof(np))
	end
	if d.parent == np then return end
	if d.destroyed then
		throw("The Parent property of " .. d.p.Name .. " is locked, current parent: NULL, new parent " .. (np and np[DATA].p.Name or "NULL"))
	end
	if d.cls.service and d.parent then throw("Unable to change Parent of service " .. d.p.Name) end
	if np then
		local a = np
		while a do
			if a == self then
				throw("Attempt to set parent of " .. fullName(self) .. " to " .. fullName(np) .. " would result in circular reference")
			end
			a = a[DATA].parent
		end
	end
	setParentRaw(self, d, np)
end
I.setParent = setParent

local tagged = {} -- tag -> { [inst] = true }
I.tagged = tagged
local tagSignals = {} -- "add:tag"/"rem:tag" -> signal
I.tagSignals = tagSignals

local function destroyInst(self, d)
	if d.destroyed then return end
	fireEvent(d, "Destroying")
	local ch = d.children
	if ch then
		for i = #ch, 1, -1 do
			local c = ch[i]
			if c then destroyInst(c, c[DATA]) end
		end
	end
	if d.parent then setParentRaw(self, d, nil) end
	d.destroyed = true
	if d.sig then for _, s in pairs(d.sig) do disconnectAll(s) end end
	if d.psig then for _, s in pairs(d.psig) do disconnectAll(s) end end
	if d.asig then for _, s in pairs(d.asig) do disconnectAll(s) end end
	if d.tags then
		for tag in pairs(d.tags) do
			if tagged[tag] then tagged[tag][self] = nil end
			local s = tagSignals["rem:" .. tag]
			if s then fireSignal(s, nil, self) end
		end
	end
	local od = d.cls.onDestroy
	if od then od(self, d) end
end
I.destroyInst = destroyInst

local ATTR_TYPES = { ["nil"] = true, boolean = true, number = true, string = true, UDim = true, UDim2 = true,
	BrickColor = true, Color3 = true, Vector2 = true, Vector3 = true, CFrame = true, NumberSequence = true,
	ColorSequence = true, NumberRange = true, Rect = true, Font = true, EnumItem = true }

local function cloneTree(src, map)
	local sd = src[DATA]
	if sd.p.Archivable == false then return nil end
	local c = newInstance(sd.cls)
	local cd = c[DATA]
	for k, v in pairs(sd.p) do cd.p[k] = v end
	if sd.attrs then
		cd.attrs = {}
		for k, v in pairs(sd.attrs) do cd.attrs[k] = v end
	end
	if sd.tags then
		cd.tags = {}
		for k in pairs(sd.tags) do
			cd.tags[k] = true
			tagged[k] = tagged[k] or {}
			tagged[k][c] = true
		end
	end
	cd.srcPath, cd.pivot, cd.serverOnly = sd.srcPath, sd.pivot, sd.serverOnly
	map[src] = c
	local ch = sd.children
	if ch then
		for i = 1, #ch do
			local cc = cloneTree(ch[i], map)
			if cc then setParentRaw(cc, cc[DATA], c) end
		end
	end
	return c
end

local function cloneInst(self)
	local map = {}
	local root = cloneTree(self, map)
	if not root then return nil end
	-- ссылки внутри копируемого дерева переводим на копии (Part0, PrimaryPart, Adornee ...)
	for orig, copy in pairs(map) do
		local cd = copy[DATA]
		for k, v in pairs(cd.p) do
			if isInst(v) and map[v] then cd.p[k] = map[v] end
		end
		local oc = cd.cls.onClone
		if oc then oc(copy, cd, orig) end
	end
	return root
end
I.cloneInst = cloneInst

I.disconnectAll = disconnectAll
I.ATTR_TYPES = ATTR_TYPES
I.eventCount = eventCount
I.markInWs = markInWs
I.setWorkspace = function(w) workspaceInst = w end
I.SigM, I.ConnM = SigM, ConnM
end -- part2
part2()

---------------------------------------------------------------------------
-- 8. Пространственный индекс деталей, лучи, соединения, базовые классы
---------------------------------------------------------------------------
local function part3()
local DATA, defclass, N, coerce, newInstance = mock.DATA, I.defclass, I.N, I.coerce, I.newInstance
local setParent, setParentRaw, isInst, fullName, eachDesc = I.setParent, I.setParentRaw, I.isInst, I.fullName, I.eachDesc
local getEvent, fireEvent, propChanged, findChild, fireSignal, newSignal = I.getEvent, I.fireEvent, I.propChanged, I.findChild, I.fireSignal, I.newSignal
local serverOnlyHidden, destroyInst, cloneInst, tagged, tagSignals = I.serverOnlyHidden, I.destroyInst, I.cloneInst, I.tagged, I.tagSignals
local checkWaiters, ATTR_TYPES, isKnownProp = I.checkWaiters, I.ATTR_TYPES, I.isKnownProp
local V0 = v3(0, 0, 0)
local classes = mock.classes

---------------- индекс (равномерная сетка) ----------------
local CELL = 16
local grid, bigParts, partCells, dirty, registered = {}, {}, {}, {}, {}
local regCount = 0
local function cellKey(cx, cy, cz) return ((cx + 32768) * 65536 + (cy + 32768)) * 65536 + (cz + 32768) end
local function partAABB(d)
	local c, s = d.p.CFrame, d.p.Size
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	local ex = abs(c[1]) * hx + abs(c[2]) * hy + abs(c[3]) * hz
	local ey = abs(c[4]) * hx + abs(c[5]) * hy + abs(c[6]) * hz
	local ez = abs(c[7]) * hx + abs(c[8]) * hy + abs(c[9]) * hz
	return c.X - ex, c.Y - ey, c.Z - ez, c.X + ex, c.Y + ey, c.Z + ez
end
I.partAABB = partAABB
local function unindex(part)
	local keys = partCells[part]
	if keys == "big" then
		bigParts[part] = nil
	elseif keys then
		for i = 1, #keys do
			local cell = grid[keys[i]]
			if cell then cell[part] = nil end
		end
	end
	partCells[part] = nil
end
local function index(part)
	local d = part[DATA]
	local x0, y0, z0, x1, y1, z1 = partAABB(d)
	local cx0, cy0, cz0 = floor(x0 / CELL), floor(y0 / CELL), floor(z0 / CELL)
	local cx1, cy1, cz1 = floor(x1 / CELL), floor(y1 / CELL), floor(z1 / CELL)
	local n = (cx1 - cx0 + 1) * (cy1 - cy0 + 1) * (cz1 - cz0 + 1)
	if n ~= n or n > 64 or n < 1 then
		bigParts[part] = true
		partCells[part] = "big"
		return
	end
	local keys = {}
	for cx = cx0, cx1 do
		for cy = cy0, cy1 do
			for cz = cz0, cz1 do
				local k = cellKey(cx, cy, cz)
				local cell = grid[k]
				if not cell then
					cell = {}
					grid[k] = cell
				end
				cell[part] = true
				keys[#keys + 1] = k
			end
		end
	end
	partCells[part] = keys
end
local function flush()
	for part in pairs(dirty) do
		dirty[part] = nil
		unindex(part)
		if registered[part] then index(part) end
	end
end
I.flushIndex = flush
local function partWsHook(self, d, inWs)
	if d.cls.name == "Terrain" then return end
	if inWs then
		if not registered[self] then
			registered[self] = true
			regCount = regCount + 1
		end
		dirty[self] = true
	else
		if registered[self] then
			registered[self] = nil
			regCount = regCount - 1
		end
		dirty[self] = nil
		unindex(self)
	end
end
mock.partsInWorkspace = function() return regCount end
mock.registeredParts = function() local o = {} for p in pairs(registered) do o[#o + 1] = p end return o end

---------------- луч против детали ----------------
local function slab(l, v, h, tmin, tmax, axis, nAxis, nSign)
	if abs(v) < 1e-12 then
		if l < -h or l > h then return nil end
		return tmin, tmax, nAxis, nSign
	end
	local t1, t2 = (-h - l) / v, (h - l) / v
	local sg = -1
	if t1 > t2 then t1, t2, sg = t2, t1, 1 end
	if t1 > tmin then tmin, nAxis, nSign = t1, axis, sg end
	if t2 < tmax then tmax = t2 end
	if tmin > tmax then return nil end
	return tmin, tmax, nAxis, nSign
end
-- возвращает t, нормаль в мире (nx, ny, nz) или nil
local function rayPart(d, ox, oy, oz, dx, dy, dz, maxT)
	local c, s = d.p.CFrame, d.p.Size
	local lx, ly, lz = cfpointInv(c, ox, oy, oz)
	local vx, vy, vz = cfvecInv(c, dx, dy, dz)
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	local shape = d.p.Shape
	local cname = d.cls.name
	local nlx, nly, nlz
	local tmin
	if shape and shape.Name == "Ball" then
		local r = mmin(hx, hy, hz)
		local b = lx * vx + ly * vy + lz * vz
		local cc = lx * lx + ly * ly + lz * lz - r * r
		if cc < 0 then return nil end
		local disc = b * b - cc
		if disc < 0 then return nil end
		tmin = -b - sqrt(disc)
		if tmin < 0 or tmin > maxT then return nil end
		nlx, nly, nlz = (lx + vx * tmin) / r, (ly + vy * tmin) / r, (lz + vz * tmin) / r
	else
		local tmax, ax, sg = huge, 0, 0
		tmin = -huge
		tmin, tmax, ax, sg = slab(lx, vx, hx, tmin, tmax, 1, ax, sg)
		if not tmin then return nil end
		if shape and shape.Name == "Cylinder" then
			-- ось X, круг в плоскости YZ
			local r = mmin(hy, hz)
			local a = vy * vy + vz * vz
			local b = ly * vy + lz * vz
			local cc = ly * ly + lz * lz - r * r
			if a < 1e-12 then
				if cc > 0 then return nil end
			else
				local disc = b * b - a * cc
				if disc < 0 then return nil end
				local sq = sqrt(disc)
				local t1, t2 = (-b - sq) / a, (-b + sq) / a
				if t1 > tmin then tmin, ax = t1, 9 end
				if t2 < tmax then tmax = t2 end
				if tmin > tmax then return nil end
			end
		else
			tmin, tmax, ax, sg = slab(ly, vy, hy, tmin, tmax, 2, ax, sg)
			if not tmin then return nil end
			tmin, tmax, ax, sg = slab(lz, vz, hz, tmin, tmax, 3, ax, sg)
			if not tmin then return nil end
			if cname == "WedgePart" then
				-- сплошное: y*hz - z*hy <= 0 (скат смотрит вверх и к -Z)
				local f0 = ly * hz - lz * hy
				local df = vy * hz - vz * hy
				if abs(df) < 1e-12 then
					if f0 > 0 then return nil end
				else
					local t = -f0 / df
					if df > 0 then
						if t < tmax then tmax = t end
					elseif t > tmin then
						tmin, ax = t, 8
					end
					if tmin > tmax then return nil end
				end
			end
		end
		if tmin < 0 or tmin > maxT then return nil end
		if ax == 1 then nlx, nly, nlz = sg, 0, 0
		elseif ax == 2 then nlx, nly, nlz = 0, sg, 0
		elseif ax == 3 then nlx, nly, nlz = 0, 0, sg
		elseif ax == 8 then
			local m = sqrt(hz * hz + hy * hy)
			nlx, nly, nlz = 0, hz / m, -hy / m
		else
			local py, pz = ly + vy * tmin, lz + vz * tmin
			local m = sqrt(py * py + pz * pz)
			nlx, nly, nlz = 0, py / m, pz / m
		end
	end
	local nx, ny, nz = cfvec(c, nlx, nly, nlz)
	return tmin, nx, ny, nz
end
I.rayPart = rayPart

local function makeFilter(params)
	local fd = params and paramsData(params)
	if not fd then return function(part, d) return d.p.CanQuery end end
	local include = fd.FilterType == E("RaycastFilterType", "Include")
	local set = nil
	if #fd.FilterDescendantsInstances > 0 then
		set = {}
		for _, x in ipairs(fd.FilterDescendantsInstances) do set[x] = true end
	end
	local respect = fd.RespectCanCollide
	return function(part, d)
		if not d.p.CanQuery then return false end
		if respect and not d.p.CanCollide then return false end
		if set then
			local a = part
			local inF = false
			while a do
				if set[a] then
					inF = true
					break
				end
				a = a[DATA].parent
			end
			if include then return inF end
			return not inF
		end
		return not include
	end, fd
end

local tested = {}
local stamp = 0
local function raycast(origin, dir, params)
	needV3(origin, "Raycast")
	needV3(dir, "Raycast")
	flush()
	local pass = makeFilter(params)
	local ox, oy, oz = origin.X, origin.Y, origin.Z
	local L = sqrt(dir.X * dir.X + dir.Y * dir.Y + dir.Z * dir.Z)
	if L == 0 or L ~= L then return nil end
	if L > 15000 then L = 15000 end
	local dx, dy, dz = dir.X / L, dir.Y / L, dir.Z / L
	stamp = stamp + 1
	local st = stamp
	local bestT, bestPart, bnx, bny, bnz = L, nil, 0, 0, 0
	local function test(part)
		if tested[part] == st then return end
		tested[part] = st
		local d = part[DATA]
		if pass(part, d) then
			local t, nx, ny, nz = rayPart(d, ox, oy, oz, dx, dy, dz, bestT)
			if t and t <= bestT then bestT, bestPart, bnx, bny, bnz = t, part, nx, ny, nz end
		end
	end
	for part in pairs(bigParts) do test(part) end
	local cx, cy, cz = floor(ox / CELL), floor(oy / CELL), floor(oz / CELL)
	local sx, sy, sz = dx > 0 and 1 or -1, dy > 0 and 1 or -1, dz > 0 and 1 or -1
	local tMaxX = abs(dx) > 1e-12 and (((cx + (dx > 0 and 1 or 0)) * CELL - ox) / dx) or huge
	local tMaxY = abs(dy) > 1e-12 and (((cy + (dy > 0 and 1 or 0)) * CELL - oy) / dy) or huge
	local tMaxZ = abs(dz) > 1e-12 and (((cz + (dz > 0 and 1 or 0)) * CELL - oz) / dz) or huge
	local tdx = abs(dx) > 1e-12 and CELL / abs(dx) or huge
	local tdy = abs(dy) > 1e-12 and CELL / abs(dy) or huge
	local tdz = abs(dz) > 1e-12 and CELL / abs(dz) or huge
	local t, guard = 0, 0
	while t <= bestT and guard < 20000 do
		guard = guard + 1
		local cell = grid[cellKey(cx, cy, cz)]
		if cell then for part in pairs(cell) do test(part) end end
		if tMaxX < tMaxY and tMaxX < tMaxZ then
			t, cx, tMaxX = tMaxX, cx + sx, tMaxX + tdx
		elseif tMaxY < tMaxZ then
			t, cy, tMaxY = tMaxY, cy + sy, tMaxY + tdy
		else
			t, cz, tMaxZ = tMaxZ, cz + sz, tMaxZ + tdz
		end
	end
	if not bestPart then return nil end
	return raycastResult(bestPart, v3(ox + dx * bestT, oy + dy * bestT, oz + dz * bestT), v3(bnx, bny, bnz),
		bestPart[DATA].p.Material, bestT)
end
I.raycast = raycast

-- детали, чьи габариты (AABB) пересекают заданный AABB
local function queryAABB(x0, y0, z0, x1, y1, z1, params, extra)
	flush()
	local pass, fd = makeFilter(params)
	local maxParts = fd and fd.MaxParts or 0
	local out, seen = {}, {}
	local function consider(part)
		if seen[part] then return end
		seen[part] = true
		local d = part[DATA]
		if not pass(part, d) then return end
		local a0, b0, c0, a1, b1, c1 = partAABB(d)
		if a1 < x0 or a0 > x1 or b1 < y0 or b0 > y1 or c1 < z0 or c0 > z1 then return end
		if extra and not extra(part, d, a0, b0, c0, a1, b1, c1) then return end
		out[#out + 1] = part
	end
	local cx0, cy0, cz0 = floor(x0 / CELL), floor(y0 / CELL), floor(z0 / CELL)
	local cx1, cy1, cz1 = floor(x1 / CELL), floor(y1 / CELL), floor(z1 / CELL)
	local n = (cx1 - cx0 + 1) * (cy1 - cy0 + 1) * (cz1 - cz0 + 1)
	for part in pairs(bigParts) do consider(part) end
	if n > 20000 or n ~= n then
		for part in pairs(registered) do consider(part) end
	else
		for cx = cx0, cx1 do
			for cy = cy0, cy1 do
				for cz = cz0, cz1 do
					local cell = grid[cellKey(cx, cy, cz)]
					if cell then for part in pairs(cell) do consider(part) end end
				end
			end
		end
	end
	if maxParts > 0 and #out > maxParts then
		for i = #out, maxParts + 1, -1 do out[i] = nil end
	end
	return out
end
I.queryAABB = queryAABB

local function boxAABB(cf, size)
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local ex = abs(cf[1]) * hx + abs(cf[2]) * hy + abs(cf[3]) * hz
	local ey = abs(cf[4]) * hx + abs(cf[5]) * hy + abs(cf[6]) * hz
	local ez = abs(cf[7]) * hx + abs(cf[8]) * hy + abs(cf[9]) * hz
	return cf.X - ex, cf.Y - ey, cf.Z - ez, cf.X + ex, cf.Y + ey, cf.Z + ez
end
I.boxAABB = boxAABB

-- точка внутри детали (с учётом формы)
local function pointInPart(d, x, y, z, pad)
	pad = pad or 0
	local lx, ly, lz = cfpointInv(d.p.CFrame, x, y, z)
	local s = d.p.Size
	local hx, hy, hz = s.X / 2 + pad, s.Y / 2 + pad, s.Z / 2 + pad
	local shape = d.p.Shape
	if shape and shape.Name == "Ball" then
		local r = mmin(hx, hy, hz)
		return lx * lx + ly * ly + lz * lz <= r * r
	end
	if abs(lx) > hx or abs(ly) > hy or abs(lz) > hz then return false end
	if shape and shape.Name == "Cylinder" then
		local r = mmin(hy, hz)
		return ly * ly + lz * lz <= r * r
	end
	if d.cls.name == "WedgePart" then return ly * (s.Z / 2) - lz * (s.Y / 2) <= 0 end
	return true
end
I.pointInPart = pointInPart

---------------- соединения и сборки ----------------
local jointDirty = {}
local function jointActive(jd)
	return not jd.destroyed and jd.parent ~= nil and jd.p.Enabled ~= false and jd.p.Part0 ~= nil and jd.p.Part1 ~= nil
end
local function setCFrameRaw(part, d, cf)
	d.p.CFrame = cf
	if d.inWs then dirty[part] = true end
	if d.sig then
		propChanged(part, d, "CFrame")
		propChanged(part, d, "Position")
	end
end
I.setCFrameRaw = setCFrameRaw

local function assemblyOf(part)
	local seen, list, i = { [part] = true }, { part }, 1
	while i <= #list do
		local p = list[i]
		i = i + 1
		local js = p[DATA].joints
		if js then
			for j in pairs(js) do
				local jd = j[DATA]
				if jointActive(jd) then
					local other = jd.p.Part0 == p and jd.p.Part1 or jd.p.Part0
					if other and not seen[other] then
						seen[other] = true
						list[#list + 1] = other
					end
				end
			end
		end
	end
	return list
end
I.assemblyOf = assemblyOf

-- жёсткий перенос всех незакреплённых деталей сборки вслед за деталью
local function propagate(part, old, new)
	local list = assemblyOf(part)
	if #list < 2 then return end
	local delta = cfmul(new, cfinv(old))
	for i = 2, #list do
		local q = list[i]
		local qd = q[DATA]
		if not qd.p.Anchored then setCFrameRaw(q, qd, cfmul(delta, qd.p.CFrame)) end
	end
end

local function rootOf(list)
	for _, p in ipairs(list) do if p[DATA].p.Anchored then return p end end
	for _, p in ipairs(list) do if p[DATA].p.Name == "HumanoidRootPart" then return p end end
	return list[1]
end

-- расставить детали сборки по соединениям (как физика Roblox)
local function solveAssembly(part)
	local list = assemblyOf(part)
	local root = rootOf(list)
	local seen, q, i = { [root] = true }, { root }, 1
	while i <= #q do
		local p = q[i]
		i = i + 1
		local pd = p[DATA]
		local js = pd.joints
		if js then
			for j in pairs(js) do
				local jd = j[DATA]
				if jointActive(jd) then
					local p0, p1 = jd.p.Part0, jd.p.Part1
					local other = (p0 == p) and p1 or p0
					if other and not seen[other] then
						seen[other] = true
						q[#q + 1] = other
						local od = other[DATA]
						if not od.p.Anchored then
							local cf
							if jd.cls.isa.WeldConstraint then
								local rel = jd.rel or IDENT
								if p0 == p then cf = cfmul(pd.p.CFrame, rel) else cf = cfmul(pd.p.CFrame, cfinv(rel)) end
							else
								local C0, C1, T = jd.p.C0 or IDENT, jd.p.C1 or IDENT, jd.p.Transform or IDENT
								if p0 == p then
									cf = cfmul(cfmul(cfmul(pd.p.CFrame, C0), T), cfinv(C1))
								else
									cf = cfmul(cfmul(cfmul(pd.p.CFrame, C1), cfinv(T)), cfinv(C0))
								end
							end
							setCFrameRaw(other, od, cf)
						end
					end
				end
			end
		end
	end
	return list
end
I.solveAssembly = solveAssembly
mock.solveJoints = function(model)
	local done = {}
	local function visit(x)
		local xd = x[DATA]
		if xd.cls.isa.BasePart and xd.joints and not done[x] then
			for _, p in ipairs(solveAssembly(x)) do done[p] = true end
		end
	end
	if model[DATA].cls.isa.BasePart then visit(model) end
	eachDesc(model, visit)
end
local function markJointDirty(jd)
	local p0, p1 = jd.p.Part0, jd.p.Part1
	if p0 and p0[DATA].inWs then jointDirty[p0] = true end
	if p1 and p1[DATA].inWs then jointDirty[p1] = true end
end
I.solveDirtyJoints = function()
	if next(jointDirty) == nil then return end
	local list = jointDirty
	jointDirty = {}
	local done = {}
	for p in pairs(list) do
		if not done[p] then
			for _, x in ipairs(solveAssembly(p)) do done[x] = true end
		end
	end
end
local function linkJoint(joint, jd, k, v)
	local old = jd.p[k]
	if old == v then return end
	if old then
		local od = old[DATA]
		if od.joints then od.joints[joint] = nil end
	end
	jd.p[k] = v
	if v then
		local vd = v[DATA]
		vd.joints = vd.joints or {}
		vd.joints[joint] = true
	end
	if jd.cls.isa.WeldConstraint and jd.p.Part0 and jd.p.Part1 then
		jd.rel = cfmul(cfinv(jd.p.Part0[DATA].p.CFrame), jd.p.Part1[DATA].p.CFrame)
	end
	markJointDirty(jd)
	if jd.sig then propChanged(joint, jd, k) end
end
local function unlinkJoint(joint, jd)
	for _, k in ipairs({ "Part0", "Part1" }) do
		local p = jd.p[k]
		if p and p[DATA].joints then p[DATA].joints[joint] = nil end
	end
end

---------------------------------------------------------------------------
-- 9. Базовые классы: Instance, PVInstance, BasePart, Model ...
---------------------------------------------------------------------------

local function needStr(v, what)
	if rawtype(v) ~= "string" then throw("Argument 1 missing or nil (" .. what .. " ждёт строку, получено " .. typeof(v) .. ")") end
end
local function isDescOf(x, anc)
	local a = x[DATA].parent
	while a do
		if a == anc then return true end
		a = a[DATA].parent
	end
	return false
end
I.isDescOf = isDescOf

local function getChildrenList(self)
	local d = self[DATA]
	if serverOnlyHidden(d) then return {} end
	local out = {}
	local ch = d.children
	if ch then for i = 1, #ch do out[i] = ch[i] end end
	return out
end
local function getDescList(self)
	local out = {}
	if serverOnlyHidden(self[DATA]) then return out end
	eachDesc(self, function(c) out[#out + 1] = c end)
	return out
end
local function findDesc(self, pred)
	local ch = self[DATA].children
	if not ch then return nil end
	for i = 1, #ch do
		local c = ch[i]
		if pred(c) then return c end
		local r = findDesc(c, pred)
		if r then return r end
	end
	return nil
end

local InstanceMethods = {
	Destroy = function(self) destroyInst(self, self[DATA]) end,
	Remove = function(self)
		suspicious("DEPRECATED", "Instance:Remove() устарел — используйте Destroy")
		setParent(self, self[DATA], nil)
	end,
	Clone = function(self) return cloneInst(self) end,
	ClearAllChildren = function(self)
		local ch = self[DATA].children
		if ch then
			for i = #ch, 1, -1 do
				local c = ch[i]
				if c then destroyInst(c, c[DATA]) end
			end
		end
	end,
	FindFirstChild = function(self, name, recursive)
		needStr(name, "FindFirstChild")
		local d = self[DATA]
		if serverOnlyHidden(d) then return nil end
		if recursive then return findDesc(self, function(c) return c[DATA].p.Name == name end) end
		return findChild(d, name)
	end,
	FindFirstChildOfClass = function(self, cn)
		needStr(cn, "FindFirstChildOfClass")
		local ch = self[DATA].children
		if ch then for i = 1, #ch do if ch[i][DATA].cls.name == cn then return ch[i] end end end
		return nil
	end,
	FindFirstChildWhichIsA = function(self, cn, recursive)
		needStr(cn, "FindFirstChildWhichIsA")
		if recursive then return findDesc(self, function(c) return c[DATA].cls.isa[cn] == true end) end
		local ch = self[DATA].children
		if ch then for i = 1, #ch do if ch[i][DATA].cls.isa[cn] then return ch[i] end end end
		return nil
	end,
	FindFirstDescendant = function(self, name)
		needStr(name, "FindFirstDescendant")
		return findDesc(self, function(c) return c[DATA].p.Name == name end)
	end,
	FindFirstAncestor = function(self, name)
		needStr(name, "FindFirstAncestor")
		local a = self[DATA].parent
		while a do
			if a[DATA].p.Name == name then return a end
			a = a[DATA].parent
		end
		return nil
	end,
	FindFirstAncestorOfClass = function(self, cn)
		needStr(cn, "FindFirstAncestorOfClass")
		local a = self[DATA].parent
		while a do
			if a[DATA].cls.name == cn then return a end
			a = a[DATA].parent
		end
		return nil
	end,
	FindFirstAncestorWhichIsA = function(self, cn)
		needStr(cn, "FindFirstAncestorWhichIsA")
		local a = self[DATA].parent
		while a do
			if a[DATA].cls.isa[cn] then return a end
			a = a[DATA].parent
		end
		return nil
	end,
	GetChildren = getChildrenList,
	GetDescendants = getDescList,
	IsA = function(self, cn)
		needStr(cn, "IsA")
		return self[DATA].cls.isa[cn] == true
	end,
	IsDescendantOf = function(self, anc)
		if anc == nil then return false end
		if not isInst(anc) then throw("IsDescendantOf: Instance expected, got " .. typeof(anc)) end
		return isDescOf(self, anc)
	end,
	IsAncestorOf = function(self, desc)
		if desc == nil then return false end
		if not isInst(desc) then throw("IsAncestorOf: Instance expected, got " .. typeof(desc)) end
		return isDescOf(desc, self)
	end,
	GetFullName = function(self) return fullName(self) end,
	GetDebugId = function(self) return "MOCK_" .. self[DATA].id end,
	GetActor = function() return nil end,
	IsPropertyModified = function() return false end,
	ResetPropertyToDefault = function() end,
	WaitForChild = function(self, name, timeout)
		needStr(name, "WaitForChild")
		local d = self[DATA]
		local hidden = serverOnlyHidden(d)
		if not hidden then
			local c = findChild(d, name)
			if c then return c end
		end
		local co, ismain = co_running()
		if ismain then throw("WaitForChild в главном потоке: " .. fullName(self) .. "." .. name .. " не найден") end
		local w = { co = co, name = name }
		d.waiters = d.waiters or {}
		if not hidden then d.waiters[#d.waiters + 1] = w end
		local loc = userLoc(2) or "?"
		local selfName = fullName(self)
		if timeout then
			mock.timer(tonumber(timeout) or 0, function()
				if w.done then return end
				w.done = true
				for i = #d.waiters, 1, -1 do if d.waiters[i] == w then tremove(d.waiters, i) end end
				resume(co, nil)
			end)
		else
			mock.timer(5, function()
				if w.done then return end
				suspicious("INFINITE_YIELD", "Infinite yield possible on '" .. selfName .. ":WaitForChild(\"" .. name .. "\")'", loc)
			end)
		end
		return co_yield()
	end,
	GetAttribute = function(self, name)
		needStr(name, "GetAttribute")
		local a = self[DATA].attrs
		return a and a[name]
	end,
	SetAttribute = function(self, name, value)
		needStr(name, "SetAttribute")
		if #name > 100 or not smatch(name, "^[%w_]+$") or ssub(name, 1, 3) == "RBX" then
			throw("SetAttribute: недопустимое имя атрибута '" .. name .. "' (только буквы, цифры и _, до 100 символов)")
		end
		local t = typeof(value)
		if not ATTR_TYPES[t] then throw("SetAttribute(" .. name .. "): attribute type " .. t .. " is not supported") end
		if t == "number" and value ~= value then suspicious("NAN", "SetAttribute(\"" .. name .. "\", NaN)") end
		local d = self[DATA]
		local a = d.attrs
		if not a then
			a = {}
			d.attrs = a
		end
		local old = a[name]
		if rawequal(old, value) or (typeof(old) == t and old == value) then return end
		a[name] = value
		if d.sig then
			fireEvent(d, "AttributeChanged", name)
			local as = d.asig and d.asig[name]
			if as then fireSignal(as, nil) end
		end
	end,
	GetAttributes = function(self)
		local out = {}
		local a = self[DATA].attrs
		if a then for k, v in pairs(a) do out[k] = v end end
		return out
	end,
	GetAttributeChangedSignal = function(self, name)
		needStr(name, "GetAttributeChangedSignal")
		local d = self[DATA]
		d.sig = d.sig or {}
		d.asig = d.asig or {}
		local s = d.asig[name]
		if not s then
			s = newSignal("AttributeChanged:" .. name, self)
			d.asig[name] = s
		end
		return s
	end,
	GetPropertyChangedSignal = function(self, prop)
		needStr(prop, "GetPropertyChangedSignal")
		local d = self[DATA]
		if not d.cls.generic and not isKnownProp(d.cls, prop) and prop ~= "Parent" and prop ~= "Name" then
			throw(prop .. " is not a valid property name. (" .. d.cls.name .. ")")
		end
		d.sig = d.sig or {}
		d.psig = d.psig or {}
		local s = d.psig[prop]
		if not s then
			s = newSignal("PropertyChanged:" .. prop, self)
			d.psig[prop] = s
		end
		return s
	end,
	AddTag = function(self, tag)
		needStr(tag, "AddTag")
		local d = self[DATA]
		d.tags = d.tags or {}
		if d.tags[tag] then return end
		d.tags[tag] = true
		tagged[tag] = tagged[tag] or {}
		tagged[tag][self] = true
		local s = tagSignals["add:" .. tag]
		if s then fireSignal(s, nil, self) end
	end,
	RemoveTag = function(self, tag)
		local d = self[DATA]
		if not (d.tags and d.tags[tag]) then return end
		d.tags[tag] = nil
		if tagged[tag] then tagged[tag][self] = nil end
		local s = tagSignals["rem:" .. tag]
		if s then fireSignal(s, nil, self) end
	end,
	HasTag = function(self, tag)
		local d = self[DATA]
		return d.tags ~= nil and d.tags[tag] == true
	end,
	GetTags = function(self)
		local out = {}
		local d = self[DATA]
		if d.tags then for k in pairs(d.tags) do out[#out + 1] = k end end
		tsort(out)
		return out
	end,
}
InstanceMethods.clone = InstanceMethods.Clone
InstanceMethods.destroy = InstanceMethods.Destroy
InstanceMethods.remove = InstanceMethods.Remove
InstanceMethods.isA = InstanceMethods.IsA
InstanceMethods.findFirstChild = InstanceMethods.FindFirstChild
InstanceMethods.getChildren = InstanceMethods.GetChildren
InstanceMethods.children = InstanceMethods.GetChildren
InstanceMethods.isDescendantOf = InstanceMethods.IsDescendantOf

defclass("Instance", nil, {
	props = { Archivable = true, Name = "Instance" },
	get = {
		Parent = function(self, d) return d.parent end,
		ClassName = function(self, d) return d.cls.name end,
		className = function(self, d) return d.cls.name end,
	},
	set = {
		Parent = function(self, d, v) setParent(self, d, v) end,
		Name = function(self, d, v)
			if rawtype(v) ~= "string" then
				if rawtype(v) == "number" then v = luauToString(v)
				else throw("Unable to assign property Name. string expected, got " .. typeof(v)) end
			end
			if d.p.Name == v then return end
			d.p.Name = v
			if d.sig then propChanged(self, d, "Name") end
			local par = d.parent
			if par and par[DATA].waiters then checkWaiters(par, par[DATA], self) end
		end,
	},
	methods = InstanceMethods,
	events = { "Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged",
		"AttributeChanged", "Destroying" },
	noCreate = true,
})
defclass("Folder", "Instance")
defclass("Configuration", "Instance")
defclass("PVInstance", "Instance", { noCreate = true })
I.Instance = classes.Instance

---------------- BasePart ----------------
local function deg(x) return x * 180 / pi end
local function rad(x) return x * pi / 180 end
local function checkCF(v, k)
	if dgetmt(v) ~= CFmt then v = coerce(k or "CFrame", "CFrame", v) end
	if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z or v[1] ~= v[1] or v[5] ~= v[5] or v[9] ~= v[9] then
		suspicious("NAN", "присвоен CFrame с NaN (" .. (k or "CFrame") .. ")")
	end
	return v
end
local function checkV3(v, k)
	if dgetmt(v) ~= V3mt then v = coerce(k, "Vector3", v) end
	if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z then suspicious("NAN", "присвоен Vector3 с NaN (" .. k .. ")") end
	return v
end
I.checkCF, I.checkV3 = checkCF, checkV3

local function setPartCFrame(self, d, v)
	local old = d.p.CFrame
	if d.joints then propagate(self, old, v) end
	setCFrameRaw(self, d, v)
end
I.setPartCFrame = setPartCFrame

local function rotOf(c) return c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9] end

local function partPivot(self, d) return cfmul(d.p.CFrame, d.p.PivotOffset) end

defclass("BasePart", "PVInstance", {
	props = {
		Anchored = false, CanCollide = true, CanQuery = true, CanTouch = true, CastShadow = true, Locked = false,
		Massless = false, Transparency = 0, Reflectance = 0, LocalTransparencyModifier = 0, RootPriority = 0,
		EnableFluidForces = true, AudioCanCollide = true, Size = v3(4, 1, 2), CFrame = IDENT,
		Color = c3(163 / 255, 162 / 255, 165 / 255), Material = E("Material", "Plastic"), MaterialVariant = "",
		CollisionGroup = "Default", CollisionGroupId = 0, CustomPhysicalProperties = N "nilable",
		AssemblyLinearVelocity = V0, AssemblyAngularVelocity = V0, PivotOffset = IDENT,
		TopSurface = E("SurfaceType", "Smooth"), BottomSurface = E("SurfaceType", "Smooth"),
		FrontSurface = E("SurfaceType", "Smooth"), BackSurface = E("SurfaceType", "Smooth"),
		LeftSurface = E("SurfaceType", "Smooth"), RightSurface = E("SurfaceType", "Smooth"), ResizeIncrement = 1,
	},
	get = {
		Position = function(self, d) local c = d.p.CFrame return v3(c.X, c.Y, c.Z) end,
		Orientation = function(self, d)
			local rx, ry, rz = CFm.ToEulerAnglesYXZ(d.p.CFrame)
			return v3(deg(rx), deg(ry), deg(rz))
		end,
		Rotation = function(self, d)
			local rx, ry, rz = CFm.ToEulerAnglesXYZ(d.p.CFrame)
			return v3(deg(rx), deg(ry), deg(rz))
		end,
		BrickColor = function(self, d) return nearestBrick(d.p.Color) end,
		Mass = function(self, d) local s = d.p.Size return s.X * s.Y * s.Z * 0.7 end,
		AssemblyMass = function(self, d) local s = d.p.Size return s.X * s.Y * s.Z * 0.7 end,
		AssemblyRootPart = function(self, d) return rootOf(assemblyOf(self)) end,
		AssemblyCenterOfMass = function(self, d) return CFget.Position(d.p.CFrame) end,
		CenterOfMass = function(self, d) return V0 end,
		ExtentsCFrame = function(self, d) return d.p.CFrame end,
		ExtentsSize = function(self, d) return d.p.Size end,
		Velocity = function(self, d) return d.p.AssemblyLinearVelocity end,
		RotVelocity = function(self, d) return d.p.AssemblyAngularVelocity end,
		ReceiveAge = function() return 0 end,
		ResizeableFaces = function() return Faces.new() end,
	},
	set = {
		CFrame = function(self, d, v) setPartCFrame(self, d, checkCF(v, "CFrame")) end,
		Position = function(self, d, v)
			v = checkV3(v, "Position")
			local c = d.p.CFrame
			setPartCFrame(self, d, cfnew(v.X, v.Y, v.Z, rotOf(c)))
		end,
		Orientation = function(self, d, v)
			v = checkV3(v, "Orientation")
			local c = d.p.CFrame
			setPartCFrame(self, d, cfnew(c.X, c.Y, c.Z, anglesYXZ(rad(v.X), rad(v.Y), rad(v.Z))))
		end,
		Rotation = function(self, d, v)
			v = checkV3(v, "Rotation")
			local c = d.p.CFrame
			setPartCFrame(self, d, cfnew(c.X, c.Y, c.Z, anglesXYZ(rad(v.X), rad(v.Y), rad(v.Z))))
		end,
		Size = function(self, d, v)
			v = checkV3(v, "Size")
			if v.X < 0.001 or v.Y < 0.001 or v.Z < 0.001 then
				if v.X < 0 or v.Y < 0 or v.Z < 0 then suspicious("SIZE", "отрицательный размер детали " .. tostring_(v)) end
				v = v3(mmax(v.X, 0.001), mmax(v.Y, 0.001), mmax(v.Z, 0.001))
			end
			if d.p.Size == v then return end
			d.p.Size = v
			if d.inWs then dirty[self] = true end
			if d.sig then propChanged(self, d, "Size") end
		end,
		BrickColor = function(self, d, v)
			if typeof(v) ~= "BrickColor" then throw("Unable to assign property BrickColor. BrickColor expected, got " .. typeof(v)) end
			d.p.Color = v.Color
			if d.sig then propChanged(self, d, "Color") end
		end,
		Velocity = function(self, d, v) d.p.AssemblyLinearVelocity = checkV3(v, "Velocity") end,
		RotVelocity = function(self, d, v) d.p.AssemblyAngularVelocity = checkV3(v, "RotVelocity") end,
	},
	events = { "Touched", "TouchEnded", "LocalSimulationTouched", "StoppedTouching" },
	methods = {
		GetPivot = function(self) return partPivot(self, self[DATA]) end,
		PivotTo = function(self, cf)
			local d = self[DATA]
			cf = checkCF(cf, "PivotTo")
			setPartCFrame(self, d, cfmul(cf, cfinv(d.p.PivotOffset)))
		end,
		GetMass = function(self) local s = self[DATA].p.Size return s.X * s.Y * s.Z * 0.7 end,
		GetTouchingParts = function() return {} end,
		GetConnectedParts = function(self) return assemblyOf(self) end,
		GetJoints = function(self)
			local o = {}
			local js = self[DATA].joints
			if js then for j in pairs(js) do o[#o + 1] = j end end
			return o
		end,
		ApplyImpulse = function(self, v)
			local d = self[DATA]
			v = checkV3(v, "ApplyImpulse")
			if d.p.Anchored then return end
			local m = d.p.Size.X * d.p.Size.Y * d.p.Size.Z * 0.7
			d.p.AssemblyLinearVelocity = d.p.AssemblyLinearVelocity + v / m
		end,
		ApplyImpulseAtPosition = function(self, v) end,
		ApplyAngularImpulse = function(self, v) end,
		SetNetworkOwner = function(self, plr)
			if curCtx().side ~= "server" then throw("SetNetworkOwner can only be called from the server") end
			for _, p in ipairs(assemblyOf(self)) do
				if p[DATA].p.Anchored then
					throw("Network Ownership API cannot be called on Anchored parts or parts welded to Anchored parts.")
				end
			end
			self[DATA].owner = plr
		end,
		GetNetworkOwner = function(self) return self[DATA].owner end,
		SetNetworkOwnershipAuto = function() end,
		GetNetworkOwnershipAuto = function() return true end,
		CanSetNetworkOwnership = function(self)
			for _, p in ipairs(assemblyOf(self)) do if p[DATA].p.Anchored then return false, "Anchored" end end
			return true
		end,
		GetRootPart = function(self) return rootOf(assemblyOf(self)) end,
		BreakJoints = function(self)
			local js = self[DATA].joints
			if js then for j in pairs(js) do destroyInst(j, j[DATA]) end end
		end,
		MakeJoints = function() end,
		IsGrounded = function(self)
			for _, p in ipairs(assemblyOf(self)) do if p[DATA].p.Anchored then return true end end
			return false
		end,
		Resize = function() return true end,
		GetVelocityAtPosition = function(self) return self[DATA].p.AssemblyLinearVelocity end,
		GetClosestPointOnSurface = function(self, p) return p end,
		SubtractAsync = function(self) return cloneInst(self) end,
		UnionAsync = function(self) return cloneInst(self) end,
		IntersectAsync = function(self) return cloneInst(self) end,
		AngularAccelerationToTorque = function() return V0 end,
		TorqueToAngularAcceleration = function() return V0 end,
	},
	wsHook = partWsHook,
	onDestroy = function(self, d)
		if d.joints then for j in pairs(d.joints) do destroyInst(j, j[DATA]) end end
	end,
	noCreate = true,
})
local function shapeSet(self, d, v)
	if typeof(v) ~= "EnumItem" then v = coerce("Shape", "E:PartType", v) end
	if enumTypeName(v) ~= "PartType" then throw("Unable to assign property Shape. Expected Enum.PartType") end
	d.p.Shape = v
	if d.inWs then dirty[self] = true end
	if d.sig then propChanged(self, d, "Shape") end
end
defclass("Part", "BasePart", { props = { Shape = E("PartType", "Block") }, set = { Shape = shapeSet } })
defclass("FormFactorPart", "BasePart", { noCreate = true })
defclass("WedgePart", "BasePart")
defclass("CornerWedgePart", "BasePart")
defclass("TrussPart", "BasePart", { props = { Style = E("Style", "AlternatingSupports") } })
defclass("MeshPart", "BasePart", {
	props = { MeshId = "", TextureID = "", DoubleSided = false, RenderFidelity = E("RenderFidelity", "Automatic"),
		CollisionFidelity = E("CollisionFidelity", "Default"), HasJointOffset = false, HasSkinnedMesh = false },
	get = { MeshSize = function(self, d) return d.p.Size end },
})
defclass("SpawnLocation", "Part", {
	props = { AllowTeamChangeOnTouch = false, Duration = 10, Enabled = true, Neutral = true, TeamColor = BrickColor.new("White") },
})
defclass("Seat", "Part", { props = { Disabled = false }, get = { Occupant = function() return nil end }, methods = { Sit = function() end } })
defclass("VehicleSeat", "BasePart", {
	props = { Disabled = false, HeadsUpDisplay = true, MaxSpeed = 25, Steer = 0, SteerFloat = 0, Throttle = 0, ThrottleFloat = 0, Torque = 10, TurnSpeed = 1 },
	get = { Occupant = function() return nil end },
})
defclass("PartOperation", "BasePart", {
	props = { UsePartColor = false, RenderFidelity = E("RenderFidelity", "Automatic"), SmoothingAngle = 0,
		CollisionFidelity = E("CollisionFidelity", "Default") }, noCreate = true,
})
defclass("UnionOperation", "PartOperation")
defclass("NegateOperation", "PartOperation")
defclass("IntersectOperation", "PartOperation")
I.dirtyPart = function(part) if part[DATA].inWs then dirty[part] = true end end

---------------- Model ----------------
local function partsOf(model)
	local out = {}
	eachDesc(model, function(c)
		local cd = c[DATA]
		if cd.cls.isa.BasePart and cd.cls.name ~= "Terrain" then out[#out + 1] = c end
	end)
	return out
end
I.partsOf = partsOf
local function modelPivot(self, d)
	local pp = d.p.PrimaryPart
	if pp and isDescOf(pp, self) then
		local pd = pp[DATA]
		return cfmul(pd.p.CFrame, pd.p.PivotOffset)
	end
	if d.pivot then return d.pivot end
	local x0, y0, z0, x1, y1, z1 = huge, huge, huge, -huge, -huge, -huge
	local any = false
	eachDesc(self, function(c)
		local cd = c[DATA]
		if cd.cls.isa.BasePart and cd.cls.name ~= "Terrain" then
			any = true
			local a, b, e, f, g, h = partAABB(cd)
			if a < x0 then x0 = a end
			if b < y0 then y0 = b end
			if e < z0 then z0 = e end
			if f > x1 then x1 = f end
			if g > y1 then y1 = g end
			if h > z1 then z1 = h end
		end
	end)
	if not any then return IDENT end
	return cfnew((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, 1, 0, 0, 0, 1, 0, 0, 0, 1)
end
I.modelPivot = modelPivot
local function modelPivotTo(self, d, cf)
	cf = checkCF(cf, "PivotTo")
	local cur = modelPivot(self, d)
	local delta = cfmul(cf, cfinv(cur))
	eachDesc(self, function(c)
		local cd = c[DATA]
		if cd.cls.isa.BasePart and cd.cls.name ~= "Terrain" then
			setCFrameRaw(c, cd, cfmul(delta, cd.p.CFrame))
		elseif cd.pivot then
			cd.pivot = cfmul(delta, cd.pivot)
		end
	end)
	local pp = d.p.PrimaryPart
	if not (pp and isDescOf(pp, self)) then d.pivot = cf end
end
I.modelPivotTo = modelPivotTo
local function boundingBox(self, d)
	local F = modelPivot(self, d)
	local x0, y0, z0, x1, y1, z1 = huge, huge, huge, -huge, -huge, -huge
	local any = false
	for _, p in ipairs(partsOf(self)) do
		any = true
		local pd = p[DATA]
		local rel = cfmul(cfinv(F), pd.p.CFrame)
		local s = pd.p.Size
		local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
		local ex = abs(rel[1]) * hx + abs(rel[2]) * hy + abs(rel[3]) * hz
		local ey = abs(rel[4]) * hx + abs(rel[5]) * hy + abs(rel[6]) * hz
		local ez = abs(rel[7]) * hx + abs(rel[8]) * hy + abs(rel[9]) * hz
		x0, y0, z0 = mmin(x0, rel.X - ex), mmin(y0, rel.Y - ey), mmin(z0, rel.Z - ez)
		x1, y1, z1 = mmax(x1, rel.X + ex), mmax(y1, rel.Y + ey), mmax(z1, rel.Z + ez)
	end
	if not any then return F, V0 end
	local cx, cy, cz = cfpoint(F, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	return cfnew(cx, cy, cz, rotOf(F)), v3(x1 - x0, y1 - y0, z1 - z0)
end
I.boundingBox = boundingBox

defclass("Model", "PVInstance", {
	props = { PrimaryPart = N "Instance:BasePart", LevelOfDetail = E("ModelLevelOfDetail", "Automatic"),
		ModelStreamingMode = E("ModelStreamingMode", "Default") },
	get = {
		WorldPivot = function(self, d) return modelPivot(self, d) end,
	},
	set = {
		WorldPivot = function(self, d, v)
			v = checkCF(v, "WorldPivot")
			local pp = d.p.PrimaryPart
			if pp and isDescOf(pp, self) then
				local pd = pp[DATA]
				pd.p.PivotOffset = cfmul(cfinv(pd.p.CFrame), v)
			else
				d.pivot = v
			end
		end,
		PrimaryPart = function(self, d, v)
			v = coerce("PrimaryPart", "Instance:BasePart", v)
			if v and not isDescOf(v, self) then
				suspicious("MODEL", "PrimaryPart модели " .. fullName(self) .. " — не её потомок (" .. fullName(v) .. ")")
			end
			if d.p.PrimaryPart == v then return end
			d.p.PrimaryPart = v
			if d.sig then propChanged(self, d, "PrimaryPart") end
		end,
	},
	methods = {
		GetPivot = function(self) return modelPivot(self, self[DATA]) end,
		PivotTo = function(self, cf) modelPivotTo(self, self[DATA], cf) end,
		GetBoundingBox = function(self) return boundingBox(self, self[DATA]) end,
		GetExtentsSize = function(self)
			local _, s = boundingBox(self, self[DATA])
			return s
		end,
		GetModelSize = function(self)
			local _, s = boundingBox(self, self[DATA])
			return s
		end,
		GetModelCFrame = function(self) return (boundingBox(self, self[DATA])) end,
		MoveTo = function(self, pos)
			pos = checkV3(pos, "MoveTo")
			local d = self[DATA]
			local cur = modelPivot(self, d)
			modelPivotTo(self, d, cur + (pos - CFget.Position(cur)))
		end,
		TranslateBy = function(self, v)
			v = checkV3(v, "TranslateBy")
			local d = self[DATA]
			modelPivotTo(self, d, modelPivot(self, d) + v)
		end,
		SetPrimaryPartCFrame = function(self, cf)
			local d = self[DATA]
			local pp = d.p.PrimaryPart
			if not pp then throw("Model:SetPrimaryPartCFrame() failed because no PrimaryPart has been set, or the PrimaryPart no longer exists. Please set Model.PrimaryPart before using this.") end
			cf = checkCF(cf, "SetPrimaryPartCFrame")
			local delta = cfmul(cf, cfinv(pp[DATA].p.CFrame))
			for _, p in ipairs(partsOf(self)) do setCFrameRaw(p, p[DATA], cfmul(delta, p[DATA].p.CFrame)) end
		end,
		GetPrimaryPartCFrame = function(self)
			local pp = self[DATA].p.PrimaryPart
			if not pp then throw("Model:GetPrimaryPartCFrame() failed because no PrimaryPart has been set") end
			return pp[DATA].p.CFrame
		end,
		ScaleTo = function(self, s) self[DATA].scale = s end,
		GetScale = function(self) return self[DATA].scale or 1 end,
		BreakJoints = function(self)
			for _, p in ipairs(partsOf(self)) do classes.BasePart.methods.BreakJoints(p) end
		end,
		MakeJoints = function() end,
		ResetOrientationToIdentity = function() end,
		SetIdentityOrientation = function() end,
		AddPersistentPlayer = function() end,
		RemovePersistentPlayer = function() end,
		GetPersistentPlayers = function() return {} end,
	},
})
defclass("WorldRoot", "Model", { noCreate = true })
defclass("WorldModel", "WorldRoot")

---------------- Attachment ----------------
local function attParentCF(d)
	local par = d.parent
	if par and par[DATA].cls.isa.BasePart and par[DATA].cls.name ~= "Terrain" then return par[DATA].p.CFrame end
	return IDENT
end
I.attParentCF = attParentCF
local function setAttCF(self, d, cf)
	d.p.CFrame = cf
	if d.sig then
		propChanged(self, d, "CFrame")
		propChanged(self, d, "WorldPosition")
	end
end
defclass("Attachment", "Instance", {
	props = { CFrame = IDENT, Visible = false },
	get = {
		Position = function(self, d) return CFget.Position(d.p.CFrame) end,
		Orientation = function(self, d)
			local rx, ry, rz = CFm.ToEulerAnglesYXZ(d.p.CFrame)
			return v3(deg(rx), deg(ry), deg(rz))
		end,
		Axis = function(self, d) return CFget.RightVector(d.p.CFrame) end,
		SecondaryAxis = function(self, d) return CFget.UpVector(d.p.CFrame) end,
		WorldCFrame = function(self, d) return cfmul(attParentCF(d), d.p.CFrame) end,
		WorldPosition = function(self, d) return CFget.Position(cfmul(attParentCF(d), d.p.CFrame)) end,
		WorldOrientation = function(self, d)
			local rx, ry, rz = CFm.ToEulerAnglesYXZ(cfmul(attParentCF(d), d.p.CFrame))
			return v3(deg(rx), deg(ry), deg(rz))
		end,
		WorldAxis = function(self, d) return CFget.RightVector(cfmul(attParentCF(d), d.p.CFrame)) end,
		WorldSecondaryAxis = function(self, d) return CFget.UpVector(cfmul(attParentCF(d), d.p.CFrame)) end,
	},
	set = {
		CFrame = function(self, d, v) setAttCF(self, d, checkCF(v, "CFrame")) end,
		Position = function(self, d, v)
			v = checkV3(v, "Position")
			setAttCF(self, d, cfnew(v.X, v.Y, v.Z, rotOf(d.p.CFrame)))
		end,
		Orientation = function(self, d, v)
			v = checkV3(v, "Orientation")
			local c = d.p.CFrame
			setAttCF(self, d, cfnew(c.X, c.Y, c.Z, anglesYXZ(rad(v.X), rad(v.Y), rad(v.Z))))
		end,
		WorldCFrame = function(self, d, v)
			v = checkCF(v, "WorldCFrame")
			setAttCF(self, d, cfmul(cfinv(attParentCF(d)), v))
		end,
		WorldPosition = function(self, d, v)
			v = checkV3(v, "WorldPosition")
			local lx, ly, lz = cfpointInv(attParentCF(d), v.X, v.Y, v.Z)
			setAttCF(self, d, cfnew(lx, ly, lz, rotOf(d.p.CFrame)))
		end,
		Axis = function(self, d, v) end,
		SecondaryAxis = function(self, d, v) end,
	},
	methods = { GetConstraints = function() return {} end },
})
defclass("Bone", "Attachment", {
	props = { Transform = IDENT },
	get = {
		TransformedCFrame = function(self, d) return cfmul(d.p.CFrame, d.p.Transform) end,
		TransformedWorldCFrame = function(self, d) return cfmul(attParentCF(d), cfmul(d.p.CFrame, d.p.Transform)) end,
	},
})

---------------- соединения ----------------
local jointSetters = {
	Part0 = function(self, d, v) linkJoint(self, d, "Part0", coerce("Part0", "Instance:BasePart", v)) end,
	Part1 = function(self, d, v) linkJoint(self, d, "Part1", coerce("Part1", "Instance:BasePart", v)) end,
}
local function jointProp(name, spec)
	return function(self, d, v)
		if spec ~= true and rawtype(v) ~= spec then v = coerce(name, spec, v) end
		d.p[name] = v
		markJointDirty(d)
		if d.sig then propChanged(self, d, name) end
	end
end
local function jointOnDestroy(self, d) unlinkJoint(self, d) end
local function jointOnParent(self, d) markJointDirty(d) end
local function jointOnClone(copy, cd, orig)
	local p0, p1 = cd.p.Part0, cd.p.Part1
	cd.p.Part0, cd.p.Part1 = nil, nil
	if p0 then linkJoint(copy, cd, "Part0", p0) end
	if p1 then linkJoint(copy, cd, "Part1", p1) end
	cd.rel = orig[DATA].rel
end
defclass("JointInstance", "Instance", {
	props = { Part0 = N "Instance:BasePart", Part1 = N "Instance:BasePart", C0 = IDENT, C1 = IDENT, Enabled = true },
	get = { Active = function(self, d) return d.p.Part0 ~= nil and d.p.Part1 ~= nil and d.p.Enabled end },
	set = { Part0 = jointSetters.Part0, Part1 = jointSetters.Part1, C0 = jointProp("C0", "CFrame"), C1 = jointProp("C1", "CFrame"),
		Enabled = jointProp("Enabled", "boolean") },
	onDestroy = jointOnDestroy, onClone = jointOnClone, noCreate = true,
})
classes.JointInstance.onParent = jointOnParent
defclass("Weld", "JointInstance")
classes.Weld.onParent = jointOnParent
defclass("ManualWeld", "JointInstance")
classes.ManualWeld.onParent = jointOnParent
defclass("Snap", "JointInstance")
classes.Snap.onParent = jointOnParent
defclass("Glue", "JointInstance")
defclass("Motor", "JointInstance", { props = { CurrentAngle = 0, DesiredAngle = 0, MaxVelocity = 0 } })
defclass("Motor6D", "Motor", {
	props = { Transform = IDENT },
	set = { Transform = jointProp("Transform", "CFrame") },
})
classes.Motor6D.onParent = jointOnParent
defclass("VelocityMotor", "JointInstance")
defclass("WeldConstraint", "Instance", {
	props = { Part0 = N "Instance:BasePart", Part1 = N "Instance:BasePart", Enabled = true },
	get = { Active = function(self, d) return d.p.Part0 ~= nil and d.p.Part1 ~= nil and d.p.Enabled end },
	set = { Part0 = jointSetters.Part0, Part1 = jointSetters.Part1, Enabled = jointProp("Enabled", "boolean") },
	onDestroy = jointOnDestroy, onClone = jointOnClone,
})
classes.WeldConstraint.onParent = jointOnParent
defclass("NoCollisionConstraint", "Instance", { props = { Part0 = N "Instance:BasePart", Part1 = N "Instance:BasePart", Enabled = true } })

-- constraints на вложениях (физику не моделируем — только свойства)
defclass("Constraint", "Instance", {
	props = { Attachment0 = N "Instance:Attachment", Attachment1 = N "Instance:Attachment", Enabled = true,
		Color = BrickColor.new("Bright blue"), Visible = false },
	get = { Active = function(self, d) return d.p.Enabled end },
	noCreate = true,
})
local constraintProps = {
	AlignPosition = { Position = V0, MaxForce = huge, MaxVelocity = huge, Responsiveness = 10, RigidityEnabled = false,
		ApplyAtCenterOfMass = false, ReactionForceEnabled = false, Mode = E("PositionAlignmentMode", "TwoAttachment"),
		ForceLimitMode = E("ForceLimitMode", "Magnitude"), MaxAxesForce = V0, ForceRelativeTo = E("ActuatorRelativeTo", "World") },
	AlignOrientation = { CFrame = IDENT, MaxTorque = huge, MaxAngularVelocity = huge, Responsiveness = 10, RigidityEnabled = false,
		PrimaryAxisOnly = false, ReactionTorqueEnabled = false, Mode = E("OrientationAlignmentMode", "TwoAttachment"),
		PrimaryAxis = v3(1, 0, 0), SecondaryAxis = v3(0, 1, 0), LookAtPosition = V0, AlignType = E("AlignType", "AllAxes") },
	LinearVelocity = { VectorVelocity = V0, MaxForce = 1000, VelocityConstraintMode = E("VelocityConstraintMode", "Vector"),
		RelativeTo = E("ActuatorRelativeTo", "World"), LineDirection = v3(1, 0, 0), LineVelocity = 0, PlaneVelocity = v2(0, 0),
		PrimaryTangentAxis = v3(1, 0, 0), SecondaryTangentAxis = v3(0, 1, 0), ForceLimitsEnabled = true, MaxAxesForce = V0,
		ForceLimitMode = E("ForceLimitMode", "Magnitude"), MaxPlanarAxesForce = v2(0, 0) },
	AngularVelocity = { AngularVelocity = V0, MaxTorque = 0, RelativeTo = E("ActuatorRelativeTo", "World"), ReactionTorqueEnabled = false },
	VectorForce = { Force = V0, RelativeTo = E("ActuatorRelativeTo", "Attachment0"), ApplyAtCenterOfMass = false },
	Torque = { Torque = V0, RelativeTo = E("ActuatorRelativeTo", "Attachment0") },
	BallSocketConstraint = { LimitsEnabled = false, UpperAngle = 45, TwistLimitsEnabled = false, Radius = 0.15, Restitution = 0 },
	HingeConstraint = { ActuatorType = E("ActuatorType", "None"), AngularVelocity = 0, MotorMaxTorque = 0, MotorMaxAcceleration = huge,
		TargetAngle = 0, ServoMaxTorque = 0, AngularSpeed = 0, AngularResponsiveness = 45, LimitsEnabled = false, UpperAngle = 45,
		LowerAngle = -45, Restitution = 0, Radius = 0.15 },
	RopeConstraint = { Length = 5, Thickness = 0.1, Restitution = 0, WinchEnabled = false, WinchForce = 10000, WinchSpeed = 2,
		WinchTarget = 5, WinchResponsiveness = 45 },
	RodConstraint = { Length = 5, Thickness = 0.1, LimitsEnabled = false, LimitAngle0 = 90, LimitAngle1 = 90 },
	SpringConstraint = { Stiffness = 0, Damping = 0, FreeLength = 1, Coils = 3, Radius = 0.4, Thickness = 0.1, LimitsEnabled = false,
		MaxLength = 5, MinLength = 0, MaxForce = huge },
	PrismaticConstraint = { ActuatorType = E("ActuatorType", "None"), LimitsEnabled = false, LowerLimit = 0, UpperLimit = 5,
		Velocity = 0, MotorMaxForce = 0, TargetPosition = 0, ServoMaxForce = 0, Speed = 0, Size = 0.15 },
	CylindricalConstraint = { ActuatorType = E("ActuatorType", "None"), LimitsEnabled = false, LowerLimit = 0, UpperLimit = 5 },
	PlaneConstraint = {}, UniversalConstraint = { LimitsEnabled = false, MaxAngle = 45, Radius = 0.2 },
}
for name, props in pairs(constraintProps) do defclass(name, "Constraint", { props = props }) end

-- старые BodyMover-ы
defclass("BodyMover", "Instance", { noCreate = true })
defclass("BodyVelocity", "BodyMover", { props = { Velocity = V0, MaxForce = v3(4000, 4000, 4000), P = 1250 } })
defclass("BodyGyro", "BodyMover", { props = { CFrame = IDENT, MaxTorque = v3(400000, 0, 400000), D = 500, P = 3000 } })
defclass("BodyPosition", "BodyMover", { props = { Position = V0, MaxForce = v3(4000, 4000, 4000), D = 1250, P = 10000 } })
defclass("BodyForce", "BodyMover", { props = { Force = V0 } })
defclass("BodyAngularVelocity", "BodyMover", { props = { AngularVelocity = V0, MaxTorque = v3(4000, 4000, 4000), P = 1250 } })

I.partWsHook = partWsHook
I.raycast = raycast
end -- part3
part3()

---------------------------------------------------------------------------
-- 10. Остальные классы: Humanoid, анимации, свет, эффекты, звук, значения,
--     скрипты, удалённые события, подсказки, камера, GUI
---------------------------------------------------------------------------
local function part4()
local DATA, defclass, N, coerce, newInstance = mock.DATA, I.defclass, I.N, I.coerce, I.newInstance
local isInst, fullName, eachDesc, getEvent, fireEvent = I.isInst, I.fullName, I.eachDesc, I.getEvent, I.fireEvent
local propChanged, findChild, fireSignal, newSignal = I.propChanged, I.findChild, I.fireSignal, I.newSignal
local destroyInst, classes, checkV3 = I.destroyInst, mock.classes, I.checkV3
local V0 = v3(0, 0, 0)
local WHITE = c3(1, 1, 1)
local BLACK = c3(0, 0, 0)

---------------- Humanoid ----------------
local humans = {}
I.humans = humans
local function rootPartOf(hum)
	local m = hum[DATA].parent
	if not m then return nil end
	local r = findChild(m[DATA], "HumanoidRootPart")
	if r and r[DATA].cls.isa.BasePart then return r end
	local pp = m[DATA].p.PrimaryPart
	return pp
end
I.rootPartOf = rootPartOf
local function setState(self, d, st)
	local old = d.state or E("HumanoidStateType", "Running")
	if old == st then return end
	d.state = st
	fireEvent(d, "StateChanged", old, st)
end
local function die(self, d)
	if d.dead then return end
	d.dead = true
	d.move = nil
	setState(self, d, E("HumanoidStateType", "Dead"))
	fireEvent(d, "Died")
	if I.onHumanoidDied then I.onHumanoidDied(self) end
end
local function finishMove(self, d, ok)
	d.move = nil
	fireEvent(d, "MoveToFinished", ok)
end
local function loadTrack(owner, anim)
	if not isInst(anim) or not anim[DATA].cls.isa.Animation then
		throw("LoadAnimation: Unable to cast value to Object (нужен экземпляр Animation, получено " .. typeof(anim) .. ")")
	end
	local t = newInstance(classes.AnimationTrack)
	local td = t[DATA]
	td.p.Animation = anim
	td.p.Name = anim[DATA].p.Name
	td.owner = owner
	if anim[DATA].p.AnimationId == "" then suspicious("ANIM", "LoadAnimation с пустым AnimationId (" .. anim[DATA].p.Name .. ")") end
	local od = owner[DATA]
	od.tracks = od.tracks or {}
	od.tracks[#od.tracks + 1] = t
	return t
end
local function playingTracks(owner)
	local out = {}
	for _, t in ipairs(owner[DATA].tracks or {}) do if t[DATA].playing then out[#out + 1] = t end end
	return out
end

defclass("Humanoid", "Instance", {
	props = {
		Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, UseJumpPower = false, HipHeight = 0,
		AutoRotate = true, AutoJumpEnabled = true, PlatformStand = false, Sit = false, Jump = false, DisplayName = "",
		DisplayDistanceType = E("HumanoidDisplayDistanceType", "Viewer"), HealthDisplayType = E("HumanoidHealthDisplayType", "DisplayWhenDamaged"),
		HealthDisplayDistance = 100, NameDisplayDistance = 100, NameOcclusion = E("NameOcclusion", "OccludeAll"),
		RigType = E("HumanoidRigType", "R6"), MaxSlopeAngle = 89, RequiresNeck = true, BreakJointsOnDeath = true,
		EvaluateStateMachine = true, CameraOffset = V0, AutomaticScalingEnabled = true, WalkToPoint = V0,
		WalkToPart = N "Instance:BasePart", TargetPoint = V0, CollisionType = E("HumanoidCollisionType", "OuterBox"),
	},
	get = {
		RootPart = function(self) return rootPartOf(self) end,
		MoveDirection = function(self, d) return d.moveDirection or V0 end,
		FloorMaterial = function(self, d) return d.dead and E("Material", "Air") or E("Material", "Plastic") end,
		SeatPart = function() return nil end,
	},
	set = {
		Health = function(self, d, v)
			if rawtype(v) ~= "number" then v = coerce("Health", "number", v) end
			if v ~= v then suspicious("NAN", "Humanoid.Health = NaN") return end
			if v > d.p.MaxHealth then v = d.p.MaxHealth end
			if v < 0 then v = 0 end
			if d.p.Health == v then return end
			d.p.Health = v
			if d.sig then
				propChanged(self, d, "Health")
				fireEvent(d, "HealthChanged", v)
			end
			if v <= 0 then die(self, d) end
		end,
		MaxHealth = function(self, d, v)
			if rawtype(v) ~= "number" then v = coerce("MaxHealth", "number", v) end
			d.p.MaxHealth = v
			if d.p.Health > v then d.p.Health = v end
			if d.sig then propChanged(self, d, "MaxHealth") end
		end,
	},
	events = { "Died", "HealthChanged", "MoveToFinished", "Running", "Jumping", "StateChanged", "Touched", "Seated",
		"FreeFalling", "Climbing", "GettingUp", "FallingDown", "Ragdoll", "PlatformStanding", "Swimming", "Strafing",
		"AnimationPlayed", "ApplyDescriptionFinished", "StateEnabledChanged", "ServerBreakJoints" },
	methods = {
		TakeDamage = function(self, amount)
			if rawtype(amount) ~= "number" then throw("TakeDamage: number expected, got " .. typeof(amount)) end
			local d = self[DATA]
			local m = d.parent
			if m and m[DATA].children then
				for _, c in ipairs(m[DATA].children) do if c[DATA].cls.name == "ForceField" then return end end
			end
			self.Health = d.p.Health - amount
		end,
		MoveTo = function(self, pos, part)
			local d = self[DATA]
			pos = checkV3(pos, "MoveTo")
			if part ~= nil and not isInst(part) then throw("MoveTo: part must be a BasePart") end
			if d.dead then return end
			d.move = { target = pos, part = part, t0 = mock.now }
			d.p.WalkToPoint = pos
		end,
		Move = function(self, dir, relativeToCamera)
			local d = self[DATA]
			dir = checkV3(dir, "Move")
			d.moveDir = dir
		end,
		ChangeState = function(self, st)
			local d = self[DATA]
			if typeof(st) ~= "EnumItem" then throw("ChangeState: Enum.HumanoidStateType expected") end
			if st.Name == "Dead" then
				d.p.Health = 0
				die(self, d)
			else
				setState(self, d, st)
			end
		end,
		GetState = function(self)
			local d = self[DATA]
			return d.state or E("HumanoidStateType", "Running")
		end,
		SetStateEnabled = function(self, st, on)
			local d = self[DATA]
			d.stateEnabled = d.stateEnabled or {}
			d.stateEnabled[st] = on and true or false
		end,
		GetStateEnabled = function(self, st)
			local d = self[DATA]
			if d.stateEnabled and d.stateEnabled[st] ~= nil then return d.stateEnabled[st] end
			return true
		end,
		LoadAnimation = function(self, anim)
			suspicious("DEPRECATED", "Humanoid:LoadAnimation устарел — используйте Animator:LoadAnimation")
			return loadTrack(self, anim)
		end,
		GetPlayingAnimationTracks = function(self) return playingTracks(self) end,
		EquipTool = function(self, tool)
			local m = self[DATA].parent
			if tool and m then tool.Parent = m; fireEvent(tool[DATA], "Equipped") end
		end,
		UnequipTools = function(self) end,
		ApplyDescription = function() end,
		ApplyDescriptionReset = function() end,
		GetAppliedDescription = function() return newInstance(classes.HumanoidDescription) end,
		AddAccessory = function(self, acc) acc.Parent = self[DATA].parent end,
		GetAccessories = function(self)
			local out = {}
			local m = self[DATA].parent
			if m then for _, c in ipairs(m:GetChildren()) do if c[DATA].cls.isa.Accoutrement then out[#out + 1] = c end end end
			return out
		end,
		RemoveAccessories = function() end,
		BuildRigFromAttachments = function() end,
		GetBodyPartR15 = function() return E("BodyPartR15", "Unknown") end,
		GetLimb = function() return E("Limb", "Unknown") end,
		GetMoveVelocity = function(self) return (self[DATA].moveDirection or V0) * self[DATA].p.WalkSpeed end,
		ReplaceBodyPartR15 = function() return true end,
	},
	wsHook = function(self, d, inWs) humans[self] = inWs or nil end,
})
I.humanDie = die

-- шаг движения гуманоидов (MoveTo / Move), без физики, с прилипанием к полу лучом вниз
local floorParams
local function updateHumanoids(dt)
	for hum in pairs(humans) do
		local d = hum[DATA]
		local dir
		local target
		local mv = d.move
		if mv then
			if mock.now - mv.t0 > 8 then
				finishMove(hum, d, false)
				mv = nil
			else
				target = mv.target
				if mv.part and mv.part[DATA] then target = mv.part[DATA].p.CFrame.Position + target end
			end
		end
		local root = (mv or d.moveDir) and not d.dead and rootPartOf(hum)
		if root then
			local rd = root[DATA]
			local c = rd.p.CFrame
			local speed = d.p.WalkSpeed
			local stepLen = speed * dt
			local nx, nz, done
			if mv then
				local dx, dz = target.X - c.X, target.Z - c.Z
				local dist = sqrt(dx * dx + dz * dz)
				if dist <= stepLen + 0.05 then
					nx, nz, done = target.X, target.Z, true
					dir = dist > 1e-6 and v3(dx / dist, 0, dz / dist) or nil
				else
					dir = v3(dx / dist, 0, dz / dist)
					nx, nz = c.X + dir.X * stepLen, c.Z + dir.Z * stepLen
				end
			else
				local md = d.moveDir
				local m = sqrt(md.X * md.X + md.Z * md.Z)
				if m > 1e-3 then
					dir = v3(md.X / m, 0, md.Z / m)
					local k = mmin(m, 1)
					nx, nz = c.X + dir.X * stepLen * k, c.Z + dir.Z * stepLen * k
				end
			end
			if nx then
				-- высота: пол под новой точкой (луч вниз), иначе оставляем
				local hip = d.p.HipHeight + rd.p.Size.Y / 2
				local footY = c.Y - hip
				local ny = c.Y
				floorParams = floorParams or RaycastParams.new()
				floorParams.FilterDescendantsInstances = { hum[DATA].parent }
				floorParams.FilterType = E("RaycastFilterType", "Exclude")
				floorParams.RespectCanCollide = true
				local hit = I.raycast(v3(nx, footY + 2.5, nz), v3(0, -40, 0), floorParams)
				if hit then ny = hit.Position.Y + hip end
				local ncf
				if dir and d.p.AutoRotate then
					ncf = CFrame.lookAt(v3(nx, ny, nz), v3(nx + dir.X, ny, nz + dir.Z))
				else
					ncf = cfnew(nx, ny, nz, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9])
				end
				I.setPartCFrame(root, rd, ncf)
				rd.p.AssemblyLinearVelocity = dir and dir * speed or V0
				d.moveDirection = dir or V0
			end
			if done then
				rd.p.AssemblyLinearVelocity = V0
				d.moveDirection = V0
				finishMove(hum, d, true)
			end
		elseif d.moveDirection and d.moveDirection ~= V0 then
			d.moveDirection = V0
		end
	end
end
I.updateHumanoids = updateHumanoids

---------------- анимации ----------------
defclass("Animation", "Instance", { props = { AnimationId = "" } })
defclass("AnimationController", "Instance", {
	methods = {
		LoadAnimation = function(self, a) return loadTrack(self, a) end,
		GetPlayingAnimationTracks = function(self) return playingTracks(self) end,
	},
	events = { "AnimationPlayed" },
})
defclass("Animator", "Instance", {
	props = { PreferLodEnabled = true, EvaluationThrottled = false },
	methods = {
		LoadAnimation = function(self, a) return loadTrack(self, a) end,
		GetPlayingAnimationTracks = function(self) return playingTracks(self) end,
		StepAnimations = function() end,
		ApplyJointVelocities = function() end,
	},
	events = { "AnimationPlayed" },
})
defclass("AnimationTrack", "Instance", {
	props = { Animation = N "Instance:Animation", Looped = false, Priority = E("AnimationPriority", "Core"), Speed = 1,
		TimePosition = 0, WeightCurrent = 1, WeightTarget = 1 },
	get = {
		IsPlaying = function(self, d) return d.playing == true end,
		Length = function(self, d)
			local a = d.p.Animation
			return (a and a[DATA].p.AnimationId ~= "") and 1 or 0
		end,
	},
	methods = {
		Play = function(self, fade, weight, speed)
			local d = self[DATA]
			d.playing = true
			if speed then d.p.Speed = speed end
			d.playToken = (d.playToken or 0) + 1
			local tok = d.playToken
			if d.owner then fireEvent(d.owner[DATA], "AnimationPlayed", self) end
			if not d.p.Looped then
				mock.timer(1 / mmax(0.01, abs(d.p.Speed)), function()
					if d.playToken == tok and d.playing then
						d.playing = false
						fireEvent(d, "Stopped")
						fireEvent(d, "Ended")
					end
				end)
			end
		end,
		Stop = function(self)
			local d = self[DATA]
			if d.playing then
				d.playing = false
				fireEvent(d, "Stopped")
				fireEvent(d, "Ended")
			end
		end,
		AdjustSpeed = function(self, s) self[DATA].p.Speed = s or 1 end,
		AdjustWeight = function(self, w) self[DATA].p.WeightTarget = w or 1 end,
		GetMarkerReachedSignal = function(self, name)
			local d = self[DATA]
			d.markers = d.markers or {}
			d.markers[name] = d.markers[name] or newSignal("Marker:" .. tostring_(name), self)
			return d.markers[name]
		end,
		GetTimeOfKeyframe = function() return 0 end,
	},
	events = { "Stopped", "Ended", "DidLoop", "KeyframeReached" },
	noCreate = true,
})
defclass("KeyframeSequence", "Instance", { props = { Loop = true, Priority = E("AnimationPriority", "Action") },
	methods = { AddKeyframe = function(self, k) k.Parent = self end, GetKeyframes = function(self) return self:GetChildren() end } })
defclass("Keyframe", "Instance", { props = { Time = 0 },
	methods = { AddPose = function(self, p) p.Parent = self end, GetPoses = function(self) return self:GetChildren() end,
		AddMarker = function(self, m) m.Parent = self end, GetMarkers = function() return {} end } })
defclass("Pose", "Instance", { props = { CFrame = IDENT, Weight = 1, EasingStyle = E("PoseEasingStyle", "Linear"),
	EasingDirection = E("PoseEasingDirection", "In") },
	methods = { AddSubPose = function(self, p) p.Parent = self end, GetSubPoses = function(self) return self:GetChildren() end } })
defclass("KeyframeMarker", "Instance", { props = { Value = "" } })

---------------- свет и окружение ----------------
defclass("Light", "Instance", { props = { Brightness = 1, Color = WHITE, Enabled = true, Shadows = false }, noCreate = true })
defclass("PointLight", "Light", { props = { Range = 8 } })
defclass("SpotLight", "Light", { props = { Angle = 90, Face = E("NormalId", "Front"), Range = 16 } })
defclass("SurfaceLight", "Light", { props = { Angle = 90, Face = E("NormalId", "Front"), Range = 16 } })
defclass("Sky", "Instance", { props = { SkyboxBk = "", SkyboxDn = "", SkyboxFt = "", SkyboxLf = "", SkyboxRt = "", SkyboxUp = "",
	CelestialBodiesShown = true, StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11, SunTextureId = "", MoonTextureId = "",
	SkyboxOrientation = V0 } })
defclass("Atmosphere", "Instance", { props = { Density = 0.395, Offset = 0, Color = c3(199 / 255, 199 / 255, 199 / 255),
	Decay = c3(106 / 255, 112 / 255, 125 / 255), Glare = 0, Haze = 0 } })
defclass("Clouds", "Instance", { props = { Cover = 0.5, Density = 0.7, Color = WHITE, Enabled = true } })
defclass("PostEffect", "Instance", { props = { Enabled = true }, noCreate = true })
defclass("BloomEffect", "PostEffect", { props = { Intensity = 1, Size = 24, Threshold = 2 } })
defclass("BlurEffect", "PostEffect", { props = { Size = 24 } })
defclass("ColorCorrectionEffect", "PostEffect", { props = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = WHITE } })
defclass("SunRaysEffect", "PostEffect", { props = { Intensity = 0.25, Spread = 1 } })
defclass("DepthOfFieldEffect", "PostEffect", { props = { FarIntensity = 0.75, FocusDistance = 0.05, InFocusRadius = 10, NearIntensity = 0.75 } })
defclass("ColorGradingEffect", "PostEffect", { props = { TonemapperPreset = E("TonemapperPreset", "Default") } })

---------------- визуальные эффекты и украшения ----------------
defclass("ParticleEmitter", "Instance", {
	props = { Acceleration = V0, Brightness = 1, Color = ColorSequence.new(WHITE), Drag = 0, EmissionDirection = E("NormalId", "Top"),
		Enabled = true, FlipbookFramerate = NumberRange.new(1), FlipbookLayout = E("ParticleFlipbookLayout", "None"),
		FlipbookMode = E("ParticleFlipbookMode", "Loop"), FlipbookStartRandom = false, Lifetime = NumberRange.new(5, 10),
		LightEmission = 0, LightInfluence = 0, LockedToPart = false, Orientation = E("ParticleOrientation", "FacingCamera"),
		Rate = 20, RotSpeed = NumberRange.new(0), Rotation = NumberRange.new(0), Shape = E("ParticleEmitterShape", "Box"),
		ShapeInOut = E("ParticleEmitterShapeInOut", "Outward"), ShapePartial = 1, ShapeStyle = E("ParticleEmitterShapeStyle", "Volume"),
		Size = NumberSequence.new(1), Speed = NumberRange.new(5), SpreadAngle = v2(0, 0), Squash = NumberSequence.new(0),
		Texture = "rbxasset://textures/particles/sparkles_main.dds", TimeScale = 1, Transparency = NumberSequence.new(0),
		VelocityInheritance = 0, WindAffectsDrag = false, ZOffset = 0 },
	methods = { Emit = function(self, n) local d = self[DATA]; d.emitted = (d.emitted or 0) + (n or 16) end, Clear = function() end },
})
defclass("Beam", "Instance", { props = { Attachment0 = N "Instance:Attachment", Attachment1 = N "Instance:Attachment", Brightness = 1,
	Color = ColorSequence.new(WHITE), CurveSize0 = 0, CurveSize1 = 0, Enabled = true, FaceCamera = false, LightEmission = 0,
	LightInfluence = 0, Segments = 10, Texture = "", TextureLength = 1, TextureMode = E("TextureMode", "Stretch"), TextureSpeed = 1,
	Transparency = NumberSequence.new(0.5), Width0 = 1, Width1 = 1, ZOffset = 0 },
	methods = { SetTextureOffset = function() end } })
defclass("Trail", "Instance", { props = { Attachment0 = N "Instance:Attachment", Attachment1 = N "Instance:Attachment", Brightness = 1,
	Color = ColorSequence.new(WHITE), Enabled = true, FaceCamera = false, Lifetime = 2, LightEmission = 0, LightInfluence = 0,
	MaxLength = 0, MinLength = 0.1, Texture = "", TextureLength = 1, TextureMode = E("TextureMode", "Stretch"),
	Transparency = NumberSequence.new(0.5), WidthScale = NumberSequence.new(1) }, methods = { Clear = function() end } })
defclass("Highlight", "Instance", { props = { Adornee = N "Instance", DepthMode = E("HighlightDepthMode", "AlwaysOnTop"), Enabled = true,
	FillColor = c3(1, 0, 0), FillTransparency = 0.5, OutlineColor = WHITE, OutlineTransparency = 0 } })
defclass("Fire", "Instance", { props = { Color = c3(236 / 255, 139 / 255, 70 / 255), SecondaryColor = c3(139 / 255, 80 / 255, 55 / 255),
	Enabled = true, Heat = 9, Size = 5, TimeScale = 1 } })
defclass("Smoke", "Instance", { props = { Color = WHITE, Enabled = true, Opacity = 0.5, RiseVelocity = 1, Size = 1, TimeScale = 1 } })
defclass("Sparkles", "Instance", { props = { SparkleColor = c3(144 / 255, 25 / 255, 1), Enabled = true, TimeScale = 1 } })
defclass("Explosion", "Instance", { props = { BlastPressure = 500000, BlastRadius = 4, DestroyJointRadiusPercent = 1,
	ExplosionType = E("ExplosionType", "Craters"), Position = V0, TimeScale = 1, Visible = true }, events = { "Hit" } })
defclass("ForceField", "Instance", { props = { Visible = true } })
defclass("Decal", "Instance", { props = { Color3 = WHITE, Texture = "", Transparency = 0, Face = E("NormalId", "Front"), ZIndex = 1,
	LocalTransparencyModifier = 0, ColorMap = "", TextureContent = "" } })
defclass("Texture", "Decal", { props = { OffsetStudsU = 0, OffsetStudsV = 0, StudsPerTileU = 2, StudsPerTileV = 2 } })
defclass("SurfaceAppearance", "Instance", { props = { AlphaMode = E("AlphaMode", "Overlay"), ColorMap = "", MetalnessMap = "",
	NormalMap = "", RoughnessMap = "", Color = WHITE } })
defclass("DataModelMesh", "Instance", { props = { Offset = V0, Scale = v3(1, 1, 1), VertexColor = v3(1, 1, 1) }, noCreate = true })
defclass("SpecialMesh", "DataModelMesh", { props = { MeshType = E("MeshType", "Head"), MeshId = "", TextureId = "" } })
defclass("BlockMesh", "DataModelMesh")
defclass("CylinderMesh", "DataModelMesh")
defclass("MaterialVariant", "Instance", { props = { BaseMaterial = E("Material", "Plastic"), ColorMap = "", MetalnessMap = "",
	NormalMap = "", RoughnessMap = "", StudsPerTile = 10, MaterialPattern = E("MaterialPattern", "Regular") } })
defclass("SelectionBox", "Instance", { props = { Adornee = N "Instance", Color3 = c3(13 / 255, 105 / 255, 172 / 255), LineThickness = 0.15,
	SurfaceColor3 = c3(13 / 255, 105 / 255, 172 / 255), SurfaceTransparency = 1, Transparency = 0, Visible = true } })
defclass("HandleAdornment", "Instance", { props = { Adornee = N "Instance", AlwaysOnTop = false, CFrame = IDENT, Color3 = WHITE,
	SizeRelativeOffset = V0, Transparency = 0, Visible = true, ZIndex = -1 }, noCreate = true })
defclass("BoxHandleAdornment", "HandleAdornment", { props = { Size = v3(1, 1, 1) } })
defclass("SphereHandleAdornment", "HandleAdornment", { props = { Radius = 1 } })
defclass("CylinderHandleAdornment", "HandleAdornment", { props = { Height = 1, Radius = 1, InnerRadius = 0, Angle = 360 } })
defclass("ConeHandleAdornment", "HandleAdornment", { props = { Height = 2, Radius = 0.5 } })
defclass("LineHandleAdornment", "HandleAdornment", { props = { Length = 5, Thickness = 1 } })
defclass("ClickDetector", "Instance", { props = { MaxActivationDistance = 32, CursorIcon = "" },
	events = { "MouseClick", "MouseHoverEnter", "MouseHoverLeave", "RightMouseClick" } })
defclass("Clothing", "Instance", { props = { Color3 = WHITE }, noCreate = true })
defclass("Shirt", "Clothing", { props = { ShirtTemplate = "" } })
defclass("Pants", "Clothing", { props = { PantsTemplate = "" } })
defclass("ShirtGraphic", "Instance", { props = { Graphic = "", Color3 = WHITE } })
defclass("BodyColors", "Instance", { props = { HeadColor3 = WHITE, LeftArmColor3 = WHITE, RightArmColor3 = WHITE,
	LeftLegColor3 = WHITE, RightLegColor3 = WHITE, TorsoColor3 = WHITE } })
defclass("CharacterMesh", "Instance", { props = { BaseTextureId = 0, MeshId = 0, OverlayTextureId = 0, BodyPart = E("BodyPart", "Head") } })
defclass("Accoutrement", "Instance", { props = { AttachmentPoint = IDENT }, noCreate = false })
defclass("Accessory", "Accoutrement", { props = { AccessoryType = E("AccessoryType", "Unknown") } })
defclass("Hat", "Accoutrement")
defclass("HumanoidDescription", "Instance", { props = { HeightScale = 1, WidthScale = 1, DepthScale = 1, HeadScale = 1,
	BodyTypeScale = 0, ProportionScale = 0, Shirt = 0, Pants = 0, Face = 0, Head = 0, Torso = 0, LeftArm = 0, RightArm = 0,
	LeftLeg = 0, RightLeg = 0, HeadColor = WHITE, TorsoColor = WHITE, LeftArmColor = WHITE, RightArmColor = WHITE,
	LeftLegColor = WHITE, RightLegColor = WHITE, HatAccessory = "", HairAccessory = "", FaceAccessory = "" } })
defclass("PathfindingModifier", "Instance", { props = { Label = "", PassThrough = false } })
defclass("PathfindingLink", "Instance", { props = { Attachment0 = N "Instance:Attachment", Attachment1 = N "Instance:Attachment",
	IsBidirectional = true, Label = "" } })
defclass("Team", "Instance", { props = { AutoAssignable = true, TeamColor = BrickColor.new("White") },
	methods = { GetPlayers = function() return {} end }, events = { "PlayerAdded", "PlayerRemoved" } })

---------------- значения ----------------
defclass("ValueBase", "Instance", { noCreate = true, valueChanged = true })
local function valueClass(name, default, spec)
	defclass(name, "ValueBase", {
		props = { Value = default },
		set = {
			Value = function(self, d, v)
				if spec then v = coerce("Value", spec, v) end
				if name == "IntValue" and rawtype(v) == "number" then
					if v ~= v then suspicious("NAN", "IntValue.Value = NaN") end
					if v == v and abs(v) < 2 ^ 62 then v = floor(v) end
				end
				if d.p.Value == v and typeof(d.p.Value) == typeof(v) then return end
				d.p.Value = v
				if d.sig then propChanged(self, d, "Value") end
			end,
		},
	})
	if default == nil then classes[name].types.Value = spec end
end
valueClass("IntValue", 0, "number")
valueClass("NumberValue", 0, "number")
valueClass("StringValue", "", "string")
valueClass("BoolValue", false, "boolean")
valueClass("ObjectValue", nil, "Instance")
valueClass("CFrameValue", IDENT, "CFrame")
valueClass("Vector3Value", V0, "Vector3")
valueClass("Color3Value", BLACK, "Color3")
valueClass("BrickColorValue", BrickColor.new("Medium stone grey"), "BrickColor")
valueClass("RayValue", Ray.new(V0, V0), "Ray")
valueClass("IntConstrainedValue", 0, "number")
valueClass("DoubleConstrainedValue", 0, "number")
classes.IntConstrainedValue.types.MinValue, classes.IntConstrainedValue.types.MaxValue = "number", "number"

---------------- скрипты ----------------
defclass("LuaSourceContainer", "Instance", { props = { Source = "" }, noCreate = true })
defclass("BaseScript", "LuaSourceContainer", { props = { Disabled = false, Enabled = true, LinkedSource = "",
	RunContext = E("RunContext", "Legacy") }, noCreate = true })
defclass("Script", "BaseScript")
defclass("LocalScript", "Script")
defclass("ModuleScript", "LuaSourceContainer", { props = { LinkedSource = "" } })

---------------- удалённые и связующие события (поведение — в разделе удалённых) ----------------
local function remoteMethod(name)
	return function(...) return I.remote[name](...) end
end
local function sideOnly(side, what)
	return function(sig, ctx)
		if ctx.side ~= side then throw(what .. " can only be used on the " .. side) end
	end
end
local function callbackProp(name)
	return function(self, d) throw(name .. " is a callback member of " .. d.cls.name .. "; you can only set the callback value, get is not available") end
end
defclass("RemoteEvent", "Instance", {
	events = { "OnServerEvent", "OnClientEvent" },
	eventInit = {
		OnServerEvent = function(s) s.onConnect = sideOnly("server", "OnServerEvent") end,
		OnClientEvent = function(s) s.onConnect = sideOnly("client", "OnClientEvent") end,
	},
	methods = { FireServer = remoteMethod("FireServer"), FireClient = remoteMethod("FireClient"),
		FireAllClients = remoteMethod("FireAllClients") },
})
defclass("UnreliableRemoteEvent", "RemoteEvent")
defclass("RemoteFunction", "Instance", {
	get = { OnServerInvoke = callbackProp("OnServerInvoke"), OnClientInvoke = callbackProp("OnClientInvoke") },
	set = {
		OnServerInvoke = function(self, d, f) I.remote.setCallback(self, d, "OnServerInvoke", f) end,
		OnClientInvoke = function(self, d, f) I.remote.setCallback(self, d, "OnClientInvoke", f) end,
	},
	methods = { InvokeServer = remoteMethod("InvokeServer"), InvokeClient = remoteMethod("InvokeClient") },
})
defclass("BindableEvent", "Instance", {
	events = { "Event" },
	methods = { Fire = function(self, ...) local d = self[DATA]; fireEvent(d, "Event", I.copyArgs(false, ...)) end },
})
defclass("BindableFunction", "Instance", {
	get = { OnInvoke = callbackProp("OnInvoke") },
	set = { OnInvoke = function(self, d, f)
		if f ~= nil and rawtype(f) ~= "function" then throw("OnInvoke must be a function") end
		d.cb = f
	end },
	methods = { Invoke = function(self, ...)
		local f = self[DATA].cb
		if not f then throw("BindableFunction:Invoke — OnInvoke не задан (" .. fullName(self) .. ")") end
		return I.copyArgs(false, f(I.copyArgs(false, ...)))
	end },
})

---------------- инструменты, подсказки ----------------
defclass("BackpackItem", "Instance", { props = { TextureId = "" }, noCreate = true })
defclass("Tool", "BackpackItem", {
	props = { CanBeDropped = true, Enabled = true, Grip = IDENT, ManualActivationOnly = false, RequiresHandle = true, ToolTip = "" },
	events = { "Activated", "Deactivated", "Equipped", "Unequipped" },
	methods = { Activate = function(self) fireEvent(self[DATA], "Activated") end, Deactivate = function(self) fireEvent(self[DATA], "Deactivated") end },
})
defclass("ProximityPrompt", "Instance", {
	props = { ActionText = "Interact", ObjectText = "", Enabled = true, HoldDuration = 0, KeyboardKeyCode = E("KeyCode", "E"),
		GamepadKeyCode = E("KeyCode", "ButtonX"), MaxActivationDistance = 10, RequiresLineOfSight = true,
		Style = E("ProximityPromptStyle", "Default"), UIOffset = v2(0, 0), ClickablePrompt = true, AutoLocalize = true,
		Exclusivity = E("ProximityPromptExclusivity", "OnePerButton"), MaxIndicatorDistance = 0, RootLocalizationTable = N "Instance" },
	events = { "Triggered", "TriggerEnded", "PromptButtonHoldBegan", "PromptButtonHoldEnded", "PromptShown", "PromptHidden" },
	methods = { InputHoldBegin = function() end, InputHoldEnd = function() end },
})
defclass("Dialog", "Instance", { props = { InitialPrompt = "", Purpose = E("DialogPurpose", "Help"), Tone = E("DialogTone", "Neutral") } })

---------------- звук ----------------
local soundStats = { played = 0, byId = {}, loops = 0 }
mock.soundStats = soundStats
local function soundLen(d) return d.p.SoundId ~= "" and 1.5 or 0 end
local function soundPlay(self)
	local d = self[DATA]
	d.playing = true
	d.p.Playing = true
	soundStats.played = soundStats.played + 1
	local id = d.p.SoundId
	soundStats.byId[id] = (soundStats.byId[id] or 0) + 1
	if d.p.Looped then soundStats.loops = soundStats.loops + 1 end
	fireEvent(d, "Played", id)
	d.tok = (d.tok or 0) + 1
	local tok = d.tok
	if id ~= "" and not d.p.Looped then
		mock.timer(soundLen(d) / mmax(0.05, d.p.PlaybackSpeed), function()
			if d.tok == tok and d.playing and not d.destroyed then
				d.playing = false
				d.p.Playing = false
				fireEvent(d, "Ended", id)
			end
		end)
	end
end
defclass("Sound", "Instance", {
	props = { SoundId = "", Volume = 0.5, Looped = false, PlaybackSpeed = 1, TimePosition = 0, Playing = false,
		RollOffMode = E("RollOffMode", "Inverse"), RollOffMinDistance = 10, RollOffMaxDistance = 10000, EmitterSize = 10,
		MaxDistance = 10000, PlayOnRemove = false, SoundGroup = N "Instance:SoundGroup", PlaybackRegionsEnabled = false,
		PlaybackRegion = NumberRange.new(0, 60000), LoopRegion = NumberRange.new(0, 60000), Pitch = 1, AudioContent = "" },
	get = {
		IsPlaying = function(self, d) return d.playing == true end,
		IsPaused = function(self, d) return not d.playing end,
		IsLoaded = function() return true end,
		TimeLength = function(self, d) return soundLen(d) end,
		PlaybackLoudness = function() return 0 end,
	},
	set = {
		Playing = function(self, d, v)
			if v then soundPlay(self) else d.playing = false; d.p.Playing = false end
		end,
	},
	methods = {
		Play = soundPlay,
		Stop = function(self)
			local d = self[DATA]
			d.playing = false
			d.p.Playing = false
			d.p.TimePosition = 0
			fireEvent(d, "Stopped", d.p.SoundId)
		end,
		Pause = function(self) local d = self[DATA]; d.playing = false; d.p.Playing = false; fireEvent(d, "Paused", d.p.SoundId) end,
		Resume = function(self) soundPlay(self); fireEvent(self[DATA], "Resumed", self[DATA].p.SoundId) end,
	},
	events = { "Ended", "Played", "Paused", "Resumed", "Stopped", "Loaded", "DidLoop" },
})
defclass("SoundGroup", "Instance", { props = { Volume = 0.5 } })
defclass("SoundEffect", "Instance", { props = { Enabled = true, Priority = 0 }, noCreate = true })
for _, nm in ipairs({ "ReverbSoundEffect", "EqualizerSoundEffect", "DistortionSoundEffect", "EchoSoundEffect", "ChorusSoundEffect",
	"FlangeSoundEffect", "PitchShiftSoundEffect", "TremoloSoundEffect", "CompressorSoundEffect" }) do
	defclass(nm, "SoundEffect", { props = { DecayTime = 1.5, Density = 1, Diffusion = 1, DryLevel = -6, WetLevel = 0,
		HighGain = 0, LowGain = 0, MidGain = 0, Level = 0.5, Delay = 1, Feedback = 0.5, Octave = 1.25, Depth = 0.5,
		Frequency = 5, Rate = 0.5, Mix = 0.5, Attack = 0.1, GainMakeup = 0, Ratio = 40, Release = 0.1, Threshold = -40 } })
end

---------------- камера ----------------
local VIEW_W, VIEW_H = 1280, 720
mock.viewport = { w = VIEW_W, h = VIEW_H }
local function camProject(d, pos)
	local cf = d.p.CFrame
	local lx, ly, lz = mock.cfpointInv(cf, pos.X, pos.Y, pos.Z)
	local depth = -lz
	local fov = math.rad(d.p.FieldOfView)
	local th = math.tan(fov / 2)
	local aspect = VIEW_W / VIEW_H
	if depth <= 1e-6 then return v3(0, 0, depth), false end
	local nx = lx / (depth * th * aspect)
	local ny = ly / (depth * th)
	local sx, sy = (nx + 1) / 2 * VIEW_W, (1 - ny) / 2 * VIEW_H
	return v3(sx, sy, depth), sx >= 0 and sx <= VIEW_W and sy >= 0 and sy <= VIEW_H
end
local function camRay(d, x, y, depth)
	local cf = d.p.CFrame
	local th = math.tan(math.rad(d.p.FieldOfView) / 2)
	local aspect = VIEW_W / VIEW_H
	local nx, ny = x / VIEW_W * 2 - 1, 1 - y / VIEW_H * 2
	local dir = v3(mock.cfvec(cf, nx * th * aspect, ny * th, -1)).Unit
	return Ray.new(cf.Position, dir * (depth or 1))
end
defclass("Camera", "Instance", {
	props = { CFrame = CFrame.lookAt(v3(0, 20, 20), V0), Focus = IDENT, FieldOfView = 70, FieldOfViewMode = E("FieldOfViewMode", "Vertical"),
		CameraType = E("CameraType", "Custom"), CameraSubject = N "Instance", HeadLocked = true, HeadScale = 1,
		VRTiltAndRollEnabled = false },
	get = {
		ViewportSize = function() return v2(VIEW_W, VIEW_H) end,
		NearPlaneZ = function() return -0.1 end,
		DiagonalFieldOfView = function(self, d) return d.p.FieldOfView * 1.6 end,
		MaxAxisFieldOfView = function(self, d) return d.p.FieldOfView * 1.4 end,
		CoordinateFrame = function(self, d) return d.p.CFrame end,
	},
	set = { CoordinateFrame = function(self, d, v) self.CFrame = v end },
	methods = {
		WorldToViewportPoint = function(self, p) checkV3(p, "WorldToViewportPoint"); return camProject(self[DATA], p) end,
		WorldToScreenPoint = function(self, p) checkV3(p, "WorldToScreenPoint"); return camProject(self[DATA], p) end,
		ViewportPointToRay = function(self, x, y, depth) return camRay(self[DATA], x, y, depth) end,
		ScreenPointToRay = function(self, x, y, depth) return camRay(self[DATA], x, y, depth) end,
		GetPartsObscuringTarget = function() return {} end,
		ZoomToExtents = function() end,
		Interpolate = function(self, cf, focus) self.CFrame = cf end,
		GetRenderCFrame = function(self) return self[DATA].p.CFrame end,
		GetRoll = function() return 0 end,
		SetRoll = function() end,
		PanUnits = function() end,
		TiltUnits = function() return true end,
		GetLargestCutoffDistance = function() return 0 end,
	},
	events = { "InterpolationFinished" },
})

---------------- GUI ----------------
local function guiAbs(self, d)
	local cls = d.cls
	if cls.isa.ScreenGui then
		if d.p.IgnoreGuiInset then return 0, 0, VIEW_W, VIEW_H end
		return 0, 58, VIEW_W, VIEW_H - 58
	end
	if cls.isa.SurfaceGui then
		if d.p.SizingMode.Name == "PixelsPerStud" then
			local par = d.p.Adornee or d.parent
			if par and par[DATA].cls.isa.BasePart then
				local s = par[DATA].p.Size
				local f = d.p.Face.Name
				local w, h = s.X, s.Y
				if f == "Left" or f == "Right" then w, h = s.Z, s.Y elseif f == "Top" or f == "Bottom" then w, h = s.X, s.Z end
				return 0, 0, w * d.p.PixelsPerStud, h * d.p.PixelsPerStud
			end
		end
		return 0, 0, d.p.CanvasSize.X, d.p.CanvasSize.Y
	end
	if cls.isa.BillboardGui then
		local s = d.p.Size
		return 0, 0, s.X.Offset + s.X.Scale * 100, s.Y.Offset + s.Y.Scale * 100
	end
	if cls.isa.GuiObject then
		local par = d.parent
		local px, py, pw, ph = 0, 0, VIEW_W, VIEW_H
		if par and par[DATA].cls.isa.GuiBase2d then px, py, pw, ph = guiAbs(par, par[DATA]) end
		local s, pos, ap = d.p.Size, d.p.Position, d.p.AnchorPoint
		local w, h = s.X.Scale * pw + s.X.Offset, s.Y.Scale * ph + s.Y.Offset
		local sc = d.p.SizeConstraint.Name
		if sc == "RelativeXX" then h = s.Y.Scale * pw + s.Y.Offset elseif sc == "RelativeYY" then w = s.X.Scale * ph + s.X.Offset end
		local x = px + pos.X.Scale * pw + pos.X.Offset - ap.X * w
		local y = py + pos.Y.Scale * ph + pos.Y.Offset - ap.Y * h
		return x, y, w, h
	end
	return 0, 0, 0, 0
end
I.guiAbs = guiAbs
local function textBounds(d)
	local text = tostring_(d.p.Text or "")
	if d.p.RichText then text = sgsub(text, "<[^>]+>", "") end
	local n = utf8.len(text) or #text
	local size = d.p.TextSize
	if d.p.TextScaled then size = 24 end
	return v2(n * size * 0.5, size)
end
I.textBounds = textBounds

defclass("GuiBase", "Instance", { noCreate = true })
defclass("GuiBase2d", "GuiBase", {
	props = { AutoLocalize = true, RootLocalizationTable = N "Instance", SelectionGroup = false,
		SelectionBehaviorDown = E("SelectionBehavior", "Escape"), SelectionBehaviorUp = E("SelectionBehavior", "Escape"),
		SelectionBehaviorLeft = E("SelectionBehavior", "Escape"), SelectionBehaviorRight = E("SelectionBehavior", "Escape") },
	get = {
		AbsolutePosition = function(self, d) local x, y = guiAbs(self, d) return v2(x, y) end,
		AbsoluteSize = function(self, d) local _, _, w, h = guiAbs(self, d) return v2(w, h) end,
		AbsoluteRotation = function(self, d) return d.p.Rotation or 0 end,
	},
	noCreate = true,
})
defclass("LayerCollector", "GuiBase2d", { props = { Enabled = true, ResetOnSpawn = true, ZIndexBehavior = E("ZIndexBehavior", "Sibling") }, noCreate = true })
defclass("ScreenGui", "LayerCollector", { props = { DisplayOrder = 0, IgnoreGuiInset = false, ClipToDeviceSafeArea = true,
	ScreenInsets = E("ScreenInsets", "CoreUISafeInsets"), SafeAreaCompatibility = E("SafeAreaCompatibility", "FullscreenExtension") } })
defclass("GuiMain", "ScreenGui")
defclass("SurfaceGuiBase", "LayerCollector", { props = { Adornee = N "Instance", Face = E("NormalId", "Front"), Active = true }, noCreate = true })
defclass("SurfaceGui", "SurfaceGuiBase", { props = { AlwaysOnTop = false, Brightness = 1, CanvasSize = v2(800, 600), ClipsDescendants = true,
	LightInfluence = 1, PixelsPerStud = 50, SizingMode = E("SurfaceGuiSizingMode", "FixedSize"), ToolPunchThroughDistance = 0,
	ZOffset = 0, MaxDistance = 0, HorizontalCurvature = 0 } })
defclass("BillboardGui", "LayerCollector", { props = { Adornee = N "Instance", AlwaysOnTop = false, Brightness = 1, ClipsDescendants = false,
	DistanceLowerLimit = 0, DistanceStep = 0, DistanceUpperLimit = -1, ExtentsOffset = V0, ExtentsOffsetWorldSpace = V0,
	LightInfluence = 0, MaxDistance = huge, Size = udim2(0, 0, 0, 0), SizeOffset = v2(0, 0), StudsOffset = V0,
	StudsOffsetWorldSpace = V0, Active = false, PlayerToHideFrom = N "Instance" },
	get = { CurrentDistance = function() return 10 end } })

local function guiTween(self, props, info, override, cb)
	return I.guiTween(self, props, info, override, cb)
end
defclass("GuiObject", "GuiBase2d", {
	props = { Active = false, AnchorPoint = v2(0, 0), AutomaticSize = E("AutomaticSize", "None"),
		BackgroundColor3 = c3(163 / 255, 162 / 255, 165 / 255), BackgroundTransparency = 0, BorderColor3 = c3(27 / 255, 42 / 255, 53 / 255),
		BorderMode = E("BorderMode", "Outline"), BorderSizePixel = 1, ClipsDescendants = false, Interactable = true, LayoutOrder = 0,
		Position = udim2(0, 0, 0, 0), Rotation = 0, Selectable = false, SelectionOrder = 0, Size = udim2(0, 100, 0, 100),
		SizeConstraint = E("SizeConstraint", "RelativeXY"), Transparency = 0, Visible = true, ZIndex = 1,
		SelectionImageObject = N "Instance", NextSelectionDown = N "Instance", NextSelectionUp = N "Instance",
		NextSelectionLeft = N "Instance", NextSelectionRight = N "Instance", GuiState = E("GuiState", "Idle") },
	events = { "InputBegan", "InputChanged", "InputEnded", "MouseEnter", "MouseLeave", "MouseMoved", "MouseWheelForward",
		"MouseWheelBackward", "TouchTap", "TouchLongPress", "TouchPan", "TouchPinch", "TouchRotate", "TouchSwipe",
		"SelectionGained", "SelectionLost", "SelectionChanged" },
	methods = {
		TweenPosition = function(self, pos, dir, style, t, override, cb)
			return guiTween(self, { Position = pos }, TweenInfo.new(t or 1, style or E("EasingStyle", "Quad"), dir or E("EasingDirection", "Out")), override, cb)
		end,
		TweenSize = function(self, size, dir, style, t, override, cb)
			return guiTween(self, { Size = size }, TweenInfo.new(t or 1, style or E("EasingStyle", "Quad"), dir or E("EasingDirection", "Out")), override, cb)
		end,
		TweenSizeAndPosition = function(self, size, pos, dir, style, t, override, cb)
			return guiTween(self, { Size = size, Position = pos }, TweenInfo.new(t or 1, style or E("EasingStyle", "Quad"), dir or E("EasingDirection", "Out")), override, cb)
		end,
	},
	noCreate = true,
})
defclass("Frame", "GuiObject", { props = { Style = E("FrameStyle", "Custom") } })
defclass("ScrollingFrame", "GuiObject", {
	props = { CanvasSize = udim2(0, 0, 2, 0), CanvasPosition = v2(0, 0), AutomaticCanvasSize = E("AutomaticSize", "None"),
		ScrollBarThickness = 12, ScrollBarImageColor3 = c3(1, 1, 1), ScrollBarImageTransparency = 0,
		ScrollingDirection = E("ScrollingDirection", "XY"), ScrollingEnabled = true, ElasticBehavior = E("ElasticBehavior", "WhenScrollable"),
		VerticalScrollBarInset = E("ScrollBarInset", "None"), HorizontalScrollBarInset = E("ScrollBarInset", "None"),
		VerticalScrollBarPosition = E("VerticalScrollBarPosition", "Right"), TopImage = "", MidImage = "", BottomImage = "" },
	get = {
		AbsoluteCanvasSize = function(self, d)
			local _, _, w, h = guiAbs(self, d)
			local cs = d.p.CanvasSize
			return v2(cs.X.Scale * w + cs.X.Offset, cs.Y.Scale * h + cs.Y.Offset)
		end,
		AbsoluteWindowSize = function(self, d) local _, _, w, h = guiAbs(self, d) return v2(w, h) end,
	},
})
local textProps = { Text = "Label", TextColor3 = c3(27 / 255, 42 / 255, 53 / 255), TextSize = 14, Font = E("Font", "Legacy"),
	FontFace = Font.fromEnum(E("Font", "Legacy")), TextScaled = false, TextWrapped = false, TextXAlignment = E("TextXAlignment", "Center"),
	TextYAlignment = E("TextYAlignment", "Center"), TextTransparency = 0, TextStrokeColor3 = BLACK, TextStrokeTransparency = 1,
	RichText = false, LineHeight = 1, MaxVisibleGraphemes = -1, TextTruncate = E("TextTruncate", "None"),
	TextDirection = E("TextDirection", "Auto"), OpenTypeFeatures = "", TextWrap = false }
local textGet = {
	TextBounds = function(self, d) return textBounds(d) end,
	TextFits = function(self, d)
		local b = textBounds(d)
		local _, _, w, h = guiAbs(self, d)
		return b.X <= w and b.Y <= h
	end,
	ContentText = function(self, d) return d.p.RichText and sgsub(d.p.Text, "<[^>]+>", "") or d.p.Text end,
	LocalizedText = function(self, d) return d.p.Text end,
}
local textSet = {
	Text = function(self, d, v)
		if rawtype(v) ~= "string" then
			if rawtype(v) == "number" then v = luauToString(v)
			else throw("Unable to assign property Text. string expected, got " .. typeof(v)) end
		end
		if d.p.Text == v then return end
		d.p.Text = v
		if d.sig then propChanged(self, d, "Text") end
	end,
}
local buttonProps = { AutoButtonColor = true, Modal = false, Selected = false, Style = E("ButtonStyle", "Custom"), Active = true, Selectable = true }
local buttonEvents = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click",
	"MouseButton2Down", "MouseButton2Up", "SecondaryActivated" }
defclass("GuiButton", "GuiObject", { props = buttonProps, events = buttonEvents, noCreate = true })
local function merge(a, b) local o = {} for k, v in pairs(a) do o[k] = v end for k, v in pairs(b or {}) do o[k] = v end return o end
defclass("TextLabel", "GuiObject", { props = merge(textProps, { Size = udim2(0, 200, 0, 50) }), get = textGet, set = textSet })
defclass("TextButton", "GuiButton", { props = merge(textProps, { Text = "Button", Size = udim2(0, 200, 0, 50) }), get = textGet, set = textSet })
defclass("TextBox", "GuiObject", {
	props = merge(textProps, { Text = "TextBox", Size = udim2(0, 200, 0, 50), ClearTextOnFocus = true, MultiLine = false,
		PlaceholderText = "", PlaceholderColor3 = c3(0.7, 0.7, 0.7), CursorPosition = 1, SelectionStart = -1,
		ShowNativeInput = true, TextEditable = true, Active = true, Selectable = true }),
	get = textGet, set = textSet,
	methods = { CaptureFocus = function() end, ReleaseFocus = function() end, IsFocused = function() return false end },
	events = { "FocusLost", "Focused", "ReturnPressedFromOnScreenKeyboard" },
})
local imageProps = { Image = "", ImageColor3 = WHITE, ImageTransparency = 0, ImageRectOffset = v2(0, 0), ImageRectSize = v2(0, 0),
	ResampleMode = E("ResamplerMode", "Default"), ScaleType = E("ScaleType", "Stretch"), SliceCenter = Rect.new(0, 0, 0, 0),
	SliceScale = 1, TileSize = udim2(1, 0, 1, 0), ImageContent = "" }
defclass("ImageLabel", "GuiObject", { props = imageProps, get = { IsLoaded = function() return true end } })
defclass("ImageButton", "GuiButton", { props = merge(imageProps, { HoverImage = "", PressedImage = "" }), get = { IsLoaded = function() return true end } })
defclass("ViewportFrame", "GuiObject", { props = { CurrentCamera = N "Instance:Camera", Ambient = c3(200 / 255, 200 / 255, 200 / 255),
	LightColor = c3(140 / 255, 140 / 255, 140 / 255), LightDirection = v3(-1, -1, -1), ImageColor3 = WHITE, ImageTransparency = 0 } })
defclass("CanvasGroup", "GuiObject", { props = { GroupColor3 = WHITE, GroupTransparency = 0 } })
defclass("VideoFrame", "GuiObject", { props = { Video = "", Looped = false, Playing = false, Volume = 1, TimePosition = 0 },
	get = { TimeLength = function() return 0 end, IsLoaded = function() return true end, Resolution = function() return v2(0, 0) end },
	methods = { Play = function(self) self[DATA].p.Playing = true end, Pause = function(self) self[DATA].p.Playing = false end },
	events = { "Ended", "Loaded", "Paused", "Played", "DidLoop" } })

-- UI-компоненты
defclass("UIBase", "Instance", { noCreate = true })
defclass("UIComponent", "UIBase", { noCreate = true })
defclass("UICorner", "UIComponent", { props = { CornerRadius = udim(0, 8) } })
defclass("UIStroke", "UIComponent", { props = { ApplyStrokeMode = E("ApplyStrokeMode", "Contextual"), Color = BLACK,
	LineJoinMode = E("LineJoinMode", "Round"), Thickness = 1, Transparency = 0, Enabled = true,
	BorderStrokePosition = E("BorderStrokePosition", "Outer"), ZIndex = 1, StrokeSizingMode = E("StrokeSizingMode", "FixedSize") } })
defclass("UIGradient", "UIComponent", { props = { Color = ColorSequence.new(WHITE), Enabled = true, Offset = v2(0, 0), Rotation = 0,
	Transparency = NumberSequence.new(0) } })
defclass("UIPadding", "UIComponent", { props = { PaddingBottom = udim(0, 0), PaddingLeft = udim(0, 0), PaddingRight = udim(0, 0), PaddingTop = udim(0, 0) } })
defclass("UIScale", "UIComponent", { props = { Scale = 1 } })
defclass("UIConstraint", "UIComponent", { noCreate = true })
defclass("UIAspectRatioConstraint", "UIConstraint", { props = { AspectRatio = 1, AspectType = E("AspectType", "FitWithinMaxSize"),
	DominantAxis = E("DominantAxis", "Width") } })
defclass("UISizeConstraint", "UIConstraint", { props = { MaxSize = v2(huge, huge), MinSize = v2(0, 0) } })
defclass("UITextSizeConstraint", "UIConstraint", { props = { MaxTextSize = 100, MinTextSize = 1 } })
defclass("UIFlexItem", "UIComponent", { props = { FlexMode = E("UIFlexMode", "None"), GrowRatio = 0, ShrinkRatio = 0,
	ItemLineAlignment = E("ItemLineAlignment", "Automatic") } })
defclass("UIDragDetector", "UIComponent", { props = { Enabled = true }, events = { "DragStart", "DragContinue", "DragEnd" } })
local function contentSize(self, d)
	local par = d.parent
	if not par then return v2(0, 0) end
	local vertical = d.p.FillDirection.Name == "Vertical"
	local pad = d.p.Padding and d.p.Padding.Offset or 0
	local total, cross, n = 0, 0, 0
	for _, c in ipairs(par[DATA].children or {}) do
		local cd = c[DATA]
		if cd.cls.isa.GuiObject and cd.p.Visible then
			local _, _, w, h = guiAbs(c, cd)
			if vertical then total, cross = total + h, mmax(cross, w) else total, cross = total + w, mmax(cross, h) end
			n = n + 1
		end
	end
	total = total + mmax(0, n - 1) * pad
	if vertical then return v2(cross, total) end
	return v2(total, cross)
end
defclass("UILayout", "UIComponent", { noCreate = true })
defclass("UIGridStyleLayout", "UILayout", { props = { FillDirection = E("FillDirection", "Horizontal"),
	HorizontalAlignment = E("HorizontalAlignment", "Left"), VerticalAlignment = E("VerticalAlignment", "Top"),
	SortOrder = E("SortOrder", "LayoutOrder") }, get = { AbsoluteContentSize = contentSize },
	methods = { ApplyLayout = function() end, SetCustomSortFunction = function() end }, noCreate = true })
defclass("UIListLayout", "UIGridStyleLayout", { props = { FillDirection = E("FillDirection", "Vertical"), Padding = udim(0, 0),
	Wraps = false, HorizontalFlex = E("UIFlexAlignment", "None"), VerticalFlex = E("UIFlexAlignment", "None"),
	ItemLineAlignment = E("ItemLineAlignment", "Automatic") } })
defclass("UIGridLayout", "UIGridStyleLayout", { props = { CellPadding = udim2(0, 5, 0, 5), CellSize = udim2(0, 100, 0, 100),
	FillDirectionMaxCells = 0, StartCorner = E("StartCorner", "TopLeft") },
	get = { AbsoluteCellCount = function() return v2(1, 1) end, AbsoluteCellSize = function(self, d)
		return v2(d.p.CellSize.X.Offset, d.p.CellSize.Y.Offset) end } })
defclass("UIPageLayout", "UIGridStyleLayout", { props = { Animated = true, Circular = false, EasingDirection = E("EasingDirection", "Out"),
	EasingStyle = E("EasingStyle", "Back"), GamepadInputEnabled = true, Padding = udim(0, 0), ScrollWheelInputEnabled = true,
	TouchInputEnabled = true, TweenTime = 1 },
	get = { CurrentPage = function() return nil end },
	methods = { JumpTo = function() end, JumpToIndex = function() end, Next = function() end, Previous = function() end },
	events = { "PageEnter", "PageLeave", "Stopped" } })
defclass("UITableLayout", "UIGridStyleLayout", { props = { FillEmptySpaceColumns = false, FillEmptySpaceRows = false,
	MajorAxis = E("TableMajorAxis", "RowMajor"), Padding = udim2(0, 0, 0, 0) } })
end -- part4
part4()
