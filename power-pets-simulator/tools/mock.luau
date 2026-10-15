-- Мини-мок Roblox для прогона кода игры в Luau CLI.
-- Проверяет имена свойств/методов/событий и Enum по официальному API-дампу.
-- Сервер и клиент живут в одной VM, у каждого потока есть контекст (server / client).
-- Ожидает в окружении: API, SOURCES, TREE.

local M = {}
M.now = 0
M.errors = {}
M.warnings = {}
M.prints = {}
M.unimplemented = {}
M.placeId = 12345
M.screenSize = { 1280, 720 }

local builtinTypeof = typeof
local Classes, Enums = API.Classes, API.Enums

local function fail(msg)
	error(msg, 3)
end

------------------------------------------------------------------------ КОНТЕКСТЫ И ПЛАНИРОВЩИК
local SERVER = { name = "server" }
M.SERVER = SERVER
local currentCtx = SERVER
local coCtx = setmetatable({}, { __mode = "k" })

local function recordError(msg)
	table.insert(M.errors, msg)
	print("!! ERROR: " .. msg)
end
M.recordError = recordError

local function resumeCo(co, ...)
	if coroutine.status(co) ~= "suspended" then
		return
	end
	local prev = currentCtx
	currentCtx = coCtx[co] or prev
	local ok, err = coroutine.resume(co, ...)
	currentCtx = prev
	if not ok then
		recordError("[" .. ((coCtx[co] or prev).name or "?") .. "] " .. tostring(err) .. "\n" .. debug.traceback(co))
	end
end
M.resume = resumeCo

local function newCo(fn, ctx)
	local co = coroutine.create(fn)
	coCtx[co] = ctx or currentCtx
	return co
end

local queue = {}
local seq = 0
local function enqueue(at, co, args)
	seq += 1
	table.insert(queue, { At = at, Seq = seq, Co = co, Args = args or table.pack() })
end

local task = {}
function task.spawn(fn, ...)
	local co = fn
	if type(fn) == "function" then
		co = newCo(fn)
	end
	resumeCo(co, ...)
	return co
end
function task.defer(fn, ...)
	local co = fn
	if type(fn) == "function" then
		co = newCo(fn)
	end
	enqueue(M.now, co, table.pack(...))
	return co
end
function task.delay(t, fn, ...)
	local co = fn
	if type(fn) == "function" then
		co = newCo(fn)
	end
	enqueue(M.now + (t or 0), co, table.pack(...))
	return co
end
function task.wait(t)
	local co = coroutine.running()
	local start = M.now
	enqueue(M.now + math.max(t or 0, 1 / 60), co)
	coroutine.yield()
	return M.now - start
end
function task.cancel(co)
	for i = #queue, 1, -1 do
		if queue[i].Co == co then
			table.remove(queue, i)
		end
	end
end
M.task = task

local function runDue(limit)
	while true do
		local bestIndex, best = nil, nil
		for i, item in ipairs(queue) do
			if item.At <= limit and (not best or item.At < best.At or (item.At == best.At and item.Seq < best.Seq)) then
				bestIndex, best = i, item
			end
		end
		if not best then
			break
		end
		table.remove(queue, bestIndex)
		if best.At > M.now then
			M.now = best.At
		end
		resumeCo(best.Co, table.unpack(best.Args, 1, best.Args.n))
	end
end

------------------------------------------------------------------------ TYPEOF
local function mtype(v)
	local mt = getmetatable(v)
	if type(mt) == "table" and rawget(mt, "__mocktype") then
		return mt.__mocktype
	end
	return builtinTypeof(v)
end
M.typeof = mtype

------------------------------------------------------------------------ VECTOR3
local V3mt = { __mocktype = "Vector3" }
local Vector3 = {}
local function v3(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, V3mt)
end
local function isV3(v)
	return getmetatable(v) == V3mt
end
local function checkNum(v, what)
	if type(v) ~= "number" then
		fail(what .. ": ожидалось число, получено " .. mtype(v))
	end
	return v
end
function Vector3.new(x, y, z)
	return v3(checkNum(x or 0, "Vector3.new"), checkNum(y or 0, "Vector3.new"), checkNum(z or 0, "Vector3.new"))
end
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)
local V3methods = {}
function V3methods.Lerp(a, b, t)
	return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
end
function V3methods.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3methods.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
V3mt.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			return v3(0 / 0, 0 / 0, 0 / 0)
		end
		return v3(v.X / m, v.Y / m, v.Z / m)
	end
	local method = V3methods[k]
	if method then
		return method
	end
	fail(tostring(k) .. " is not a valid member of Vector3")
end
V3mt.__newindex = function()
	fail("Vector3 is read-only")
end
V3mt.__add = function(a, b)
	if not (isV3(a) and isV3(b)) then
		fail("Vector3 + " .. mtype(b))
	end
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3mt.__sub = function(a, b)
	if not (isV3(a) and isV3(b)) then
		fail("Vector3 - " .. mtype(b))
	end
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3mt.__mul = function(a, b)
	if type(a) == "number" then
		return v3(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	elseif isV3(a) and isV3(b) then
		return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
	end
	fail("bad Vector3 multiplication with " .. mtype(b))
end
V3mt.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	elseif isV3(b) then
		return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
	end
	fail("bad Vector3 division")
end
V3mt.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3mt.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3mt.__tostring = function(v)
	return string.format("%g, %g, %g", v.X, v.Y, v.Z)
end

------------------------------------------------------------------------ VECTOR2
local V2mt = { __mocktype = "Vector2" }
local Vector2 = {}
local function v2(x, y)
	return setmetatable({ X = x, Y = y }, V2mt)
end
local function isV2(v)
	return getmetatable(v) == V2mt
end
function Vector2.new(x, y)
	return v2(checkNum(x or 0, "Vector2.new"), checkNum(y or 0, "Vector2.new"))
end
Vector2.zero = v2(0, 0)
Vector2.one = v2(1, 1)
V2mt.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y)
		return v2(v.X / m, v.Y / m)
	elseif k == "Lerp" then
		return function(a, b, t)
			return v2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
		end
	end
	fail(tostring(k) .. " is not a valid member of Vector2")
end
V2mt.__newindex = function()
	fail("Vector2 is read-only")
end
V2mt.__add = function(a, b)
	if not (isV2(a) and isV2(b)) then
		fail("Vector2 + " .. mtype(b))
	end
	return v2(a.X + b.X, a.Y + b.Y)
end
V2mt.__sub = function(a, b)
	if not (isV2(a) and isV2(b)) then
		fail("Vector2 - " .. mtype(b))
	end
	return v2(a.X - b.X, a.Y - b.Y)
end
V2mt.__mul = function(a, b)
	if type(a) == "number" then
		return v2(b.X * a, b.Y * a)
	elseif type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	elseif isV2(a) and isV2(b) then
		return v2(a.X * b.X, a.Y * b.Y)
	end
	fail("bad Vector2 multiplication")
end
V2mt.__div = function(a, b)
	if type(b) == "number" then
		return v2(a.X / b, a.Y / b)
	end
	return v2(a.X / b.X, a.Y / b.Y)
end
V2mt.__unm = function(a)
	return v2(-a.X, -a.Y)
end
V2mt.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end

------------------------------------------------------------------------ CFRAME
-- Хранение: позиция + матрица поворота по строкам (r00..r22). Столбцы — оси Right, Up, Back.
local CFmt = { __mocktype = "CFrame" }
local CFrame = {}
local function cf(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return setmetatable({ x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }, CFmt)
end
local function isCF(v)
	return getmetatable(v) == CFmt
end
local IDENTITY = cf(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
CFrame.identity = IDENTITY
local function cfmul(a, b)
	local ax, ay, az, a00, a01, a02, a10, a11, a12, a20, a21, a22 = table.unpack(a)
	local bx, by, bz, b00, b01, b02, b10, b11, b12, b20, b21, b22 = table.unpack(b)
	return cf(
		a00 * bx + a01 * by + a02 * bz + ax,
		a10 * bx + a11 * by + a12 * bz + ay,
		a20 * bx + a21 * by + a22 * bz + az,
		a00 * b00 + a01 * b10 + a02 * b20,
		a00 * b01 + a01 * b11 + a02 * b21,
		a00 * b02 + a01 * b12 + a02 * b22,
		a10 * b00 + a11 * b10 + a12 * b20,
		a10 * b01 + a11 * b11 + a12 * b21,
		a10 * b02 + a11 * b12 + a12 * b22,
		a20 * b00 + a21 * b10 + a22 * b20,
		a20 * b01 + a21 * b11 + a22 * b21,
		a20 * b02 + a21 * b12 + a22 * b22
	)
end
local function cfinv(a)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = table.unpack(a)
	-- транспонированная матрица
	local nx = -(r00 * x + r10 * y + r20 * z)
	local ny = -(r01 * x + r11 * y + r21 * z)
	local nz = -(r02 * x + r12 * y + r22 * z)
	return cf(nx, ny, nz, r00, r10, r20, r01, r11, r21, r02, r12, r22)
end
local function cfpoint(a, v)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = table.unpack(a)
	return v3(r00 * v.X + r01 * v.Y + r02 * v.Z + x, r10 * v.X + r11 * v.Y + r12 * v.Z + y, r20 * v.X + r21 * v.Y + r22 * v.Z + z)
end
local function rotX(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(0, 0, 0, 1, 0, 0, 0, c, -s, 0, s, c)
end
local function rotY(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(0, 0, 0, c, 0, s, 0, 1, 0, -s, 0, c)
end
local function rotZ(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(0, 0, 0, c, -s, 0, s, c, 0, 0, 0, 1)
end
function CFrame.new(...)
	local n = select("#", ...)
	local a, b, c = ...
	if n == 0 then
		return IDENTITY
	elseif n == 1 then
		if not isV3(a) then
			fail("CFrame.new(Vector3) ожидает Vector3, получено " .. mtype(a))
		end
		return cf(a.X, a.Y, a.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	elseif n == 2 and isV3(a) and isV3(b) then
		return CFrame.lookAt(a, b)
	elseif n == 3 then
		return cf(checkNum(a, "CFrame.new"), checkNum(b, "CFrame.new"), checkNum(c, "CFrame.new"), 1, 0, 0, 0, 1, 0, 0, 0, 1)
	elseif n == 12 then
		return cf(...)
	end
	fail("CFrame.new: неподдерживаемые аргументы")
end
function CFrame.Angles(rx, ry, rz)
	checkNum(rx, "CFrame.Angles")
	checkNum(ry, "CFrame.Angles")
	checkNum(rz, "CFrame.Angles")
	return cfmul(cfmul(rotX(rx), rotY(ry)), rotZ(rz))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.lookAt(at, target, up)
	if not (isV3(at) and isV3(target)) then
		fail("CFrame.lookAt ожидает Vector3")
	end
	up = up or Vector3.yAxis
	local look = target - at
	if look.Magnitude < 1e-9 then
		return cf(at.X, at.Y, at.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	look = look.Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(Vector3.xAxis)
		if right.Magnitude < 1e-6 then
			right = look:Cross(Vector3.zAxis)
		end
	end
	right = right.Unit
	local upv = right:Cross(look).Unit
	local back = -look
	return cf(at.X, at.Y, at.Z, right.X, upv.X, back.X, right.Y, upv.Y, back.Y, right.Z, upv.Z, back.Z)
end
local CFmethods = {}
function CFmethods.Inverse(a)
	return cfinv(a)
end
function CFmethods.ToObjectSpace(a, b)
	return cfmul(cfinv(a), b)
end
function CFmethods.ToWorldSpace(a, b)
	return cfmul(a, b)
end
function CFmethods.PointToWorldSpace(a, v)
	return cfpoint(a, v)
end
function CFmethods.PointToObjectSpace(a, v)
	return cfpoint(cfinv(a), v)
end
function CFmethods.Lerp(a, b, t)
	local r = {}
	for i = 1, 12 do
		r[i] = a[i] + (b[i] - a[i]) * t
	end
	-- ортонормализация поворота
	local right = v3(r[4], r[7], r[10])
	local up = v3(r[5], r[8], r[11])
	if right.Magnitude < 1e-6 or up.Magnitude < 1e-6 then
		return b
	end
	right = right.Unit
	local back = right:Cross(up).Unit
	up = back:Cross(right).Unit
	return cf(r[1], r[2], r[3], right.X, up.X, back.X, right.Y, up.Y, back.Y, right.Z, up.Z, back.Z)
end
function CFmethods.GetComponents(a)
	return table.unpack(a)
end
CFmt.__index = function(c, k)
	if k == "Position" or k == "p" then
		return v3(c[1], c[2], c[3])
	elseif k == "X" then
		return c[1]
	elseif k == "Y" then
		return c[2]
	elseif k == "Z" then
		return c[3]
	elseif k == "LookVector" then
		return v3(-c[6], -c[9], -c[12])
	elseif k == "RightVector" then
		return v3(c[4], c[7], c[10])
	elseif k == "UpVector" then
		return v3(c[5], c[8], c[11])
	elseif k == "Rotation" then
		return cf(0, 0, 0, c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
	end
	local method = CFmethods[k]
	if method then
		return method
	end
	fail(tostring(k) .. " is not a valid member of CFrame")
end
CFmt.__newindex = function()
	fail("CFrame is read-only")
end
CFmt.__mul = function(a, b)
	if not isCF(a) then
		fail("CFrame multiplication: left side is " .. mtype(a))
	end
	if isCF(b) then
		return cfmul(a, b)
	elseif isV3(b) then
		return cfpoint(a, b)
	end
	fail("CFrame * " .. mtype(b))
end
CFmt.__add = function(a, b)
	if not isV3(b) then
		fail("CFrame + " .. mtype(b))
	end
	return cf(a[1] + b.X, a[2] + b.Y, a[3] + b.Z, a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12])
end
CFmt.__sub = function(a, b)
	if not isV3(b) then
		fail("CFrame - " .. mtype(b))
	end
	return cf(a[1] - b.X, a[2] - b.Y, a[3] - b.Z, a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12])
end

------------------------------------------------------------------------ ПРОЧИЕ ТИПЫ
local function simpleType(name, fields)
	local mt = { __mocktype = name }
	mt.__index = function(_, k)
		fail(tostring(k) .. " is not a valid member of " .. name)
	end
	mt.__newindex = function()
		fail(name .. " is read-only")
	end
	return function(values)
		return setmetatable(values, mt)
	end, mt
end

local makeColor3, C3mt = simpleType("Color3")
local Color3 = {}
local C3methods = {}
C3mt.__index = function(c, k)
	if C3methods[k] then
		return C3methods[k]
	end
	fail(tostring(k) .. " is not a valid member of Color3")
end
C3mt.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
function Color3.new(r, g, b)
	return makeColor3({ R = checkNum(r or 0, "Color3.new"), G = checkNum(g or 0, "Color3.new"), B = checkNum(b or 0, "Color3.new") })
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHSV(h, s, v)
	return Color3.new(v, v * (1 - s), v * (1 - s * h))
end
function C3methods.Lerp(a, b, t)
	if getmetatable(b) ~= C3mt then
		fail("Color3:Lerp ожидает Color3")
	end
	checkNum(t, "Color3:Lerp")
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function C3methods.ToHSV(c)
	return 0, 0, math.max(c.R, c.G, c.B)
end

local makeUDim, UDmt = simpleType("UDim")
local UDim = {}
function UDim.new(scale, offset)
	return makeUDim({ Scale = checkNum(scale or 0, "UDim.new"), Offset = checkNum(offset or 0, "UDim.new") })
end
UDmt.__index = function(_, k)
	fail(tostring(k) .. " is not a valid member of UDim")
end

local makeUDim2, UD2mt = simpleType("UDim2")
local UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	if getmetatable(xs) == UDmt then
		return makeUDim2({ X = xs, Y = xo })
	end
	return makeUDim2({ X = UDim.new(xs or 0, xo or 0), Y = UDim.new(ys or 0, yo or 0) })
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x or 0, 0, y or 0)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x or 0, 0, y or 0, 0)
end
UD2mt.__index = function(u, k)
	if k == "Width" then
		return rawget(u, "X")
	elseif k == "Height" then
		return rawget(u, "Y")
	end
	fail(tostring(k) .. " is not a valid member of UDim2")
end

local makeCSK = simpleType("ColorSequenceKeypoint")
local ColorSequenceKeypoint = {
	new = function(t, c)
		return makeCSK({ Time = t, Value = c })
	end,
}
local makeCS = simpleType("ColorSequence")
local ColorSequence = {
	new = function(a, b)
		if type(a) == "table" and getmetatable(a) == nil then
			for _, k in ipairs(a) do
				if mtype(k) ~= "ColorSequenceKeypoint" then
					fail("ColorSequence.new: ожидались ColorSequenceKeypoint")
				end
			end
			if a[1].Time ~= 0 or a[#a].Time ~= 1 then
				fail("ColorSequence: первая точка должна быть в 0, последняя в 1")
			end
			return makeCS({ Keypoints = a })
		end
		if getmetatable(a) ~= C3mt or (b ~= nil and getmetatable(b) ~= C3mt) then
			fail("ColorSequence.new ожидает Color3")
		end
		return makeCS({ Keypoints = { makeCSK({ Time = 0, Value = a }), makeCSK({ Time = 1, Value = b or a }) } })
	end,
}
local makeNSK = simpleType("NumberSequenceKeypoint")
local NumberSequenceKeypoint = {
	new = function(t, v, e)
		return makeNSK({ Time = checkNum(t, "NSK"), Value = checkNum(v, "NSK"), Envelope = e or 0 })
	end,
}
local makeNS = simpleType("NumberSequence")
local NumberSequence = {
	new = function(a, b)
		if type(a) == "table" then
			if a[1].Time ~= 0 or a[#a].Time ~= 1 then
				fail("NumberSequence: первая точка должна быть в 0, последняя в 1")
			end
			return makeNS({ Keypoints = a })
		end
		checkNum(a, "NumberSequence.new")
		return makeNS({ Keypoints = { makeNSK({ Time = 0, Value = a, Envelope = 0 }), makeNSK({ Time = 1, Value = b or a, Envelope = 0 }) } })
	end,
}
local makeNR = simpleType("NumberRange")
local NumberRange = {
	new = function(a, b)
		checkNum(a, "NumberRange.new")
		if b and b < a then
			fail("NumberRange: max < min")
		end
		return makeNR({ Min = a, Max = b or a })
	end,
}

------------------------------------------------------------------------ RAYCAST
local RPmt = { __mocktype = "RaycastParams" }
local RaycastParams = {
	new = function()
		return setmetatable({ FilterDescendantsInstances = {}, IgnoreWater = false, RespectCanCollide = false }, RPmt)
	end,
}
RPmt.__index = function(_, k)
	if k == "FilterType" then
		return nil
	end
	fail(tostring(k) .. " is not a valid member of RaycastParams")
end
local makeRaycastResult = simpleType("RaycastResult")

------------------------------------------------------------------------ ENUM
local enumItemCache = {}
local EImt = { __mocktype = "EnumItem" }
EImt.__index = function(_, k)
	fail(tostring(k) .. " is not a valid member of EnumItem")
end
EImt.__tostring = function(e)
	return "Enum." .. e.EnumType .. "." .. e.Name
end
local function enumItem(enumName, itemName)
	local items = Enums[enumName]
	if not items then
		fail("Enum." .. tostring(enumName) .. " не существует")
	end
	local value = items[itemName]
	if value == nil then
		fail(tostring(itemName) .. " is not a valid member of Enum." .. enumName)
	end
	local key = enumName .. "." .. itemName
	local item = enumItemCache[key]
	if not item then
		item = setmetatable({ Name = itemName, Value = value, EnumType = enumName }, EImt)
		enumItemCache[key] = item
	end
	return item
end
M.enumItem = enumItem
local enumObjCache = {}
local Enum = setmetatable({}, {
	__index = function(_, enumName)
		if not Enums[enumName] then
			fail("Enum." .. tostring(enumName) .. " не существует")
		end
		local obj = enumObjCache[enumName]
		if not obj then
			obj = setmetatable({}, {
				__mocktype = "Enum",
				__index = function(_, itemName)
					if itemName == "GetEnumItems" then
						return function()
							local list = {}
							for name in pairs(Enums[enumName]) do
								table.insert(list, enumItem(enumName, name))
							end
							return list
						end
					end
					return enumItem(enumName, itemName)
				end,
			})
			enumObjCache[enumName] = obj
		end
		return obj
	end,
})

------------------------------------------------------------------------ TweenInfo, Random, Font
local makeTI = simpleType("TweenInfo")
local TweenInfo = {
	new = function(time, style, direction, repeatCount, reverses, delayTime)
		if style ~= nil and (mtype(style) ~= "EnumItem" or style.EnumType ~= "EasingStyle") then
			fail("TweenInfo.new: EasingStyle неверный")
		end
		if direction ~= nil and (mtype(direction) ~= "EnumItem" or direction.EnumType ~= "EasingDirection") then
			fail("TweenInfo.new: EasingDirection неверный")
		end
		return makeTI({ Time = time or 1, RepeatCount = repeatCount or 0, Reverses = reverses or false, DelayTime = delayTime or 0 })
	end,
}

local Rmt = { __mocktype = "Random" }
Rmt.__index = {
	NextNumber = function(self, a, b)
		local x = self._next()
		if a then
			return a + (b - a) * x
		end
		return x
	end,
	NextInteger = function(self, a, b)
		if type(a) ~= "number" or type(b) ~= "number" or b < a then
			fail("Random:NextInteger: неверный диапазон")
		end
		return a + math.floor(self._next() * (b - a + 1))
	end,
}
local Random = {
	new = function(seed)
		local state = (seed or 12345) % 2147483647
		if state <= 0 then
			state = 1
		end
		return setmetatable({
			_next = function()
				state = (state * 16807) % 2147483647
				return (state - 1) / 2147483646
			end,
		}, Rmt)
	end,
}

local makeFont = simpleType("Font")
local Font = {}
function Font.new(family, weight, style)
	if type(family) ~= "string" then
		fail("Font.new: family должен быть строкой")
	end
	if weight ~= nil and (mtype(weight) ~= "EnumItem" or weight.EnumType ~= "FontWeight") then
		fail("Font.new: weight должен быть Enum.FontWeight")
	end
	return makeFont({ Family = family, Weight = weight or enumItem("FontWeight", "Regular"), Style = style or enumItem("FontStyle", "Normal"), Bold = false })
end
function Font.fromEnum(item)
	if mtype(item) ~= "EnumItem" or item.EnumType ~= "Font" then
		fail("Font.fromEnum ожидает Enum.Font")
	end
	return Font.new("rbxasset://fonts/families/" .. item.Name .. ".json")
end
function Font.fromName(name, weight, style)
	return Font.new("rbxasset://fonts/families/" .. name .. ".json", weight, style)
end

------------------------------------------------------------------------ СИГНАЛЫ
local Sigmt = { __mocktype = "RBXScriptSignal" }
local Connmt = { __mocktype = "RBXScriptConnection" }
Connmt.__index = {
	Disconnect = function(self)
		self.Connected = false
	end,
}
local function newSignal(name)
	return setmetatable({ Name = name, Conns = {}, Waiters = {} }, Sigmt)
end
Sigmt.__index = {
	Connect = function(self, fn)
		if type(fn) ~= "function" then
			fail("Connect ожидает функцию (" .. tostring(self.Name) .. ")")
		end
		local conn = setmetatable({ Connected = true, Fn = fn, Ctx = currentCtx }, Connmt)
		table.insert(self.Conns, conn)
		return conn
	end,
	Once = function(self, fn)
		local conn
		conn = self:Connect(function(...)
			conn:Disconnect()
			fn(...)
		end)
		return conn
	end,
	Wait = function(self)
		local co = coroutine.running()
		table.insert(self.Waiters, co)
		return coroutine.yield()
	end,
}
local function fireSignal(signal, filter, ...)
	for _, conn in ipairs(table.clone(signal.Conns)) do
		if conn.Connected and (not filter or filter(conn.Ctx)) then
			local co = newCo(conn.Fn, conn.Ctx)
			resumeCo(co, ...)
		end
	end
	local waiters = signal.Waiters
	signal.Waiters = {}
	for _, co in ipairs(waiters) do
		if not filter or filter(coCtx[co]) then
			resumeCo(co, ...)
		else
			table.insert(signal.Waiters, co)
		end
	end
end
M.fire = function(signal, ...)
	fireSignal(signal, nil, ...)
end
M.newSignal = newSignal

------------------------------------------------------------------------ INSTANCE
local D = setmetatable({}, { __mode = "k" }) -- proxy -> данные
local Imt = { __mocktype = "Instance" }
local function isInst(v)
	return getmetatable(v) == Imt
end
M.isInst = isInst

local function classOf(name)
	return Classes[name]
end
local function isA(className, target)
	local name = className
	while name and Classes[name] do
		if name == target then
			return true
		end
		name = Classes[name].S
	end
	return false
end
local function findMember(className, kind, member)
	local name = className
	while name and Classes[name] do
		local value = Classes[name][kind][member]
		if value ~= nil then
			return value, name
		end
		name = Classes[name].S
	end
	return nil
end

local collection = { Tags = setmetatable({}, { __mode = "k" }), Added = {}, Removed = {} }
local gameRoot -- DataModel
local function inGame(inst)
	local d = D[inst]
	while d do
		if d.Proxy == gameRoot then
			return true
		end
		d = d.Parent and D[d.Parent]
	end
	return false
end

local DEFAULTS = {
	Visible = true, Enabled = true, CanCollide = true, CanTouch = true, CanQuery = true, CastShadow = true,
	Archivable = true, ResetOnSpawn = true, RequiresLineOfSight = true, AutoButtonColor = true, Active = false,
	TextSize = 14, Volume = 0.5, PlaybackSpeed = 1, Range = 8, Brightness = 1, Gravity = 196.2, FieldOfView = 70,
	MaxActivationDistance = 10, Health = 100, MaxHealth = 100, Scale = 1, Rate = 20, Thickness = 1,
	Size_BasePart = v3(4, 1.2, 2), Size_GuiObject = UDim2.new(0, 100, 0, 100),
}
local function defaultFor(className, prop, spec)
	local category, typeName = string.match(spec, "^([^:]+):([^:]+)")
	if prop == "Size" then
		if isA(className, "BasePart") then
			return DEFAULTS.Size_BasePart
		elseif isA(className, "GuiObject") then
			return DEFAULTS.Size_GuiObject
		end
	end
	if DEFAULTS[prop] ~= nil then
		return DEFAULTS[prop]
	end
	if category == "Primitive" then
		if typeName == "bool" then
			return false
		elseif typeName == "string" then
			return ""
		end
		return 0
	elseif category == "Enum" then
		local items = Enums[typeName]
		local best, bestValue = nil, math.huge
		for name, value in pairs(items) do
			if value < bestValue then
				best, bestValue = name, value
			end
		end
		return best and enumItem(typeName, best) or nil
	elseif category == "DataType" then
		if typeName == "Vector3" then
			return Vector3.zero
		elseif typeName == "Vector2" then
			return Vector2.zero
		elseif typeName == "CFrame" then
			return IDENTITY
		elseif typeName == "Color3" then
			return Color3.new(0.64, 0.64, 0.64)
		elseif typeName == "UDim2" then
			return UDim2.new()
		elseif typeName == "UDim" then
			return UDim.new()
		elseif typeName == "Font" then
			return Font.fromEnum(enumItem("Font", "SourceSans"))
		elseif typeName == "Content" or typeName == "ContentId" then
			return ""
		elseif typeName == "NumberRange" then
			return NumberRange.new(0)
		elseif typeName == "NumberSequence" then
			return NumberSequence.new(0)
		elseif typeName == "ColorSequence" then
			return ColorSequence.new(Color3.new(1, 1, 1))
		end
	end
	return nil
end

local function checkValue(className, prop, spec, value)
	local category, typeName = string.match(spec, "^([^:]+):([^:]+)")
	local t = mtype(value)
	local where = className .. "." .. prop
	if category == "Primitive" then
		if typeName == "bool" then
			if t ~= "boolean" then
				fail(where .. ": ожидался bool, получено " .. t)
			end
		elseif typeName == "string" then
			if t ~= "string" and t ~= "number" then
				fail(where .. ": ожидалась строка, получено " .. t)
			end
		else
			if t ~= "number" then
				fail(where .. ": ожидалось число, получено " .. t)
			end
			if value ~= value then
				fail(where .. ": NaN")
			end
		end
	elseif category == "Enum" then
		if t == "EnumItem" then
			if value.EnumType ~= typeName then
				fail(where .. ": ожидался Enum." .. typeName .. ", получен Enum." .. value.EnumType)
			end
		elseif t == "string" then
			if Enums[typeName][value] == nil then
				fail(where .. ": нет Enum." .. typeName .. "." .. value)
			end
			return enumItem(typeName, value)
		else
			fail(where .. ": ожидался Enum." .. typeName .. ", получено " .. t)
		end
	elseif category == "DataType" then
		if typeName == "Content" or typeName == "ContentId" then
			if t ~= "string" then
				fail(where .. ": ожидалась строка (Content)")
			end
		elseif t ~= typeName then
			fail(where .. ": ожидался " .. typeName .. ", получено " .. t)
		end
		if typeName == "Vector3" and (value.X ~= value.X or value.Y ~= value.Y or value.Z ~= value.Z) then
			fail(where .. ": Vector3 с NaN")
		end
		if typeName == "CFrame" then
			for i = 1, 12 do
				if value[i] ~= value[i] then
					fail(where .. ": CFrame с NaN")
				end
			end
		end
	elseif category == "Class" then
		if value ~= nil and not (isInst(value) and isA(D[value].ClassName, typeName)) then
			fail(where .. ": ожидался " .. typeName .. ", получено " .. t)
		end
	end
	return value
end

local Instance = {}
local methods = {} -- [имя] = function(self, d, ...)
local getters = {} -- [имя свойства] = function(self, d)
local setters = {} -- [имя свойства] = function(self, d, value) (после проверки)
local classSetup = {} -- [класс] = function(self, d) при создании

local function propSignal(d, prop)
	d.PropSignals[prop] = d.PropSignals[prop] or newSignal(prop .. "Changed")
	return d.PropSignals[prop]
end

local function newInstance(className)
	local proxy = setmetatable({}, Imt)
	local d = {
		Proxy = proxy,
		ClassName = className,
		Props = {},
		Children = {},
		Attributes = {},
		AttrSignals = {},
		PropSignals = {},
		Events = {},
		Callbacks = {},
	}
	d.Props.Name = className
	D[proxy] = d
	for name in pairs(classSetup) do
		if isA(className, name) then
			classSetup[name](proxy, d)
		end
	end
	return proxy
end
M.newInstance = newInstance

local function eventOf(proxy, name)
	local d = D[proxy]
	if not d.Events[name] then
		d.Events[name] = newSignal(name)
	end
	return d.Events[name]
end
M.event = eventOf

local function fireTagAdded(inst)
	local tags = collection.Tags[inst]
	if tags then
		for tag in pairs(tags) do
			if collection.Added[tag] then
				fireSignal(collection.Added[tag], nil, inst)
			end
		end
	end
end
local function fireTagRemoved(inst)
	local tags = collection.Tags[inst]
	if tags then
		for tag in pairs(tags) do
			if collection.Removed[tag] then
				fireSignal(collection.Removed[tag], nil, inst)
			end
		end
	end
end

local function descendants(proxy, out)
	out = out or {}
	for _, child in ipairs(D[proxy].Children) do
		table.insert(out, child)
		descendants(child, out)
	end
	return out
end

local function setParent(proxy, newParent)
	local d = D[proxy]
	if d.Destroyed and newParent ~= nil then
		fail("The Parent property of " .. d.Props.Name .. " is locked")
	end
	if newParent ~= nil and not isInst(newParent) then
		fail("Parent должен быть Instance")
	end
	if newParent == proxy then
		fail("Нельзя сделать объект родителем самого себя")
	end
	local old = d.Parent
	if old == newParent then
		return
	end
	local wasInGame = inGame(proxy)
	if old then
		local list = D[old].Children
		for i, child in ipairs(list) do
			if child == proxy then
				table.remove(list, i)
				break
			end
		end
		fireSignal(eventOf(old, "ChildRemoved"), nil, proxy)
	end
	d.Parent = newParent
	if newParent then
		table.insert(D[newParent].Children, proxy)
		fireSignal(eventOf(newParent, "ChildAdded"), nil, proxy)
		local ancestor = newParent
		while ancestor do
			fireSignal(eventOf(ancestor, "DescendantAdded"), nil, proxy)
			ancestor = D[ancestor].Parent
		end
	end
	local nowInGame = inGame(proxy)
	if nowInGame and not wasInGame then
		fireTagAdded(proxy)
		for _, desc in ipairs(descendants(proxy)) do
			fireTagAdded(desc)
		end
	elseif wasInGame and not nowInGame then
		fireTagRemoved(proxy)
		for _, desc in ipairs(descendants(proxy)) do
			fireTagRemoved(desc)
		end
	end
	fireSignal(propSignal(d, "Parent"), nil)
	fireSignal(eventOf(proxy, "AncestryChanged"), nil, proxy, newParent)
end

Imt.__index = function(proxy, key)
	local d = D[proxy]
	if not d then
		fail("обращение к уничтоженному объекту")
	end
	if key == "Parent" then
		return d.Parent
	elseif key == "ClassName" then
		return d.ClassName
	end
	if type(key) ~= "string" then
		fail("неверный ключ Instance: " .. tostring(key))
	end
	local cls = d.ClassName
	-- метод
	local allowed = findMember(cls, "M", key)
	if allowed ~= nil then
		if allowed == false then
			fail(key .. " недоступен скриптам игры (" .. cls .. ")")
		end
		local impl = methods[key]
		if impl then
			return function(self, ...)
				if self ~= proxy then
					fail("метод " .. key .. " вызван через точку вместо двоеточия")
				end
				return impl(self, D[self], ...)
			end
		end
		return function(self)
			M.unimplemented[cls .. ":" .. key] = true
			return nil
		end
	end
	-- свойство
	local spec = findMember(cls, "P", key)
	if spec ~= nil then
		local readFlags = string.match(spec, "^[^:]+:[^:]+:(.*)$") or ""
		if string.find(readFlags, "S") then
			fail(cls .. "." .. key .. " недоступно для чтения скриптами")
		end
		if getters[key] then
			local value = getters[key](proxy, d)
			if value ~= nil then
				return value
			end
		end
		local value = d.Props[key]
		if value == nil then
			value = defaultFor(cls, key, spec)
		end
		return value
	end
	-- событие
	local ev = findMember(cls, "E", key)
	if ev ~= nil then
		return eventOf(proxy, key)
	end
	-- колбэк
	if findMember(cls, "C", key) ~= nil then
		return d.Callbacks[key]
	end
	-- ребёнок
	for _, child in ipairs(d.Children) do
		if D[child].Props.Name == key then
			return child
		end
	end
	fail(key .. " is not a valid member of " .. cls .. " \"" .. tostring(d.Props.Name) .. "\"")
end

Imt.__newindex = function(proxy, key, value)
	local d = D[proxy]
	if not d then
		fail("запись в уничтоженный объект")
	end
	local cls = d.ClassName
	if key == "Parent" then
		setParent(proxy, value)
		return
	end
	if findMember(cls, "C", key) ~= nil then
		if value ~= nil and type(value) ~= "function" then
			fail(cls .. "." .. key .. " ожидает функцию")
		end
		d.Callbacks[key] = value
		if M.onCallbackSet then
			M.onCallbackSet(proxy, key, value)
		end
		return
	end
	local spec = findMember(cls, "P", key)
	if spec == nil then
		fail(tostring(key) .. " is not a valid member of " .. cls)
	end
	local flags = string.match(spec, "^[^:]+:[^:]+:(.*)$") or ""
	if string.find(flags, "r") and not (M.allowReadOnly and M.allowReadOnly[key]) then
		fail(cls .. "." .. key .. " только для чтения")
	end
	if string.find(flags, "n") then
		fail(cls .. "." .. key .. " нельзя менять из скрипта (NotScriptable)")
	end
	if string.find(flags, "W") then
		fail(cls .. "." .. key .. " недоступно для записи скриптами")
	end
	if string.find(flags, "d") then
		table.insert(M.warnings, "устаревшее свойство " .. cls .. "." .. key)
	end
	value = checkValue(cls, key, spec, value)
	if setters[key] then
		setters[key](proxy, d, value)
	else
		d.Props[key] = value
	end
	if d.PropSignals[key] then
		fireSignal(d.PropSignals[key], nil)
	end
end
Imt.__tostring = function(proxy)
	return D[proxy] and tostring(D[proxy].Props.Name) or "<destroyed>"
end

function Instance.new(className, parent)
	local cls = classOf(className)
	if not cls then
		fail("Неизвестный класс " .. tostring(className))
	end
	if string.find(cls.F, "c") or string.find(cls.F, "s") then
		fail("Нельзя создать " .. className .. " через Instance.new")
	end
	local inst = newInstance(className)
	if parent then
		inst.Parent = parent
	end
	return inst
end

------------------------------------------------------------------------ МЕТОДЫ INSTANCE
function methods.IsA(self, d, name)
	if not Classes[name] then
		fail("IsA: неизвестный класс " .. tostring(name))
	end
	return isA(d.ClassName, name)
end
function methods.FindFirstChild(self, d, name, recursive)
	for _, child in ipairs(d.Children) do
		if D[child].Props.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in ipairs(d.Children) do
			local found = methods.FindFirstChild(child, D[child], name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function methods.FindFirstChildOfClass(self, d, className)
	if not Classes[className] then
		fail("FindFirstChildOfClass: неизвестный класс " .. tostring(className))
	end
	for _, child in ipairs(d.Children) do
		if D[child].ClassName == className then
			return child
		end
	end
	return nil
end
function methods.FindFirstChildWhichIsA(self, d, className, recursive)
	for _, child in ipairs(recursive and descendants(self) or d.Children) do
		if isA(D[child].ClassName, className) then
			return child
		end
	end
	return nil
end
function methods.FindFirstAncestorOfClass(self, d, className)
	if not Classes[className] then
		fail("FindFirstAncestorOfClass: неизвестный класс " .. tostring(className))
	end
	local current = d.Parent
	while current do
		if D[current].ClassName == className then
			return current
		end
		current = D[current].Parent
	end
	return nil
end
function methods.FindFirstAncestorWhichIsA(self, d, className)
	local current = d.Parent
	while current do
		if isA(D[current].ClassName, className) then
			return current
		end
		current = D[current].Parent
	end
	return nil
end
function methods.FindFirstAncestor(self, d, name)
	local current = d.Parent
	while current do
		if D[current].Props.Name == name then
			return current
		end
		current = D[current].Parent
	end
	return nil
end
function methods.WaitForChild(self, d, name, timeout)
	local found = methods.FindFirstChild(self, d, name)
	if found then
		return found
	end
	local started = M.now
	local warned = false
	while true do
		task.wait(1 / 60)
		found = methods.FindFirstChild(self, d, name)
		if found then
			return found
		end
		if timeout and M.now - started >= timeout then
			return nil
		end
		if not timeout and not warned and M.now - started > 5 then
			warned = true
			table.insert(M.warnings, "Infinite yield possible on WaitForChild(" .. name .. ") в " .. tostring(d.Props.Name))
		end
	end
end
function methods.GetChildren(self, d)
	return table.clone(d.Children)
end
function methods.GetDescendants(self, d)
	return descendants(self)
end
function methods.IsDescendantOf(self, d, other)
	local current = d.Parent
	while current do
		if current == other then
			return true
		end
		current = D[current].Parent
	end
	return false
end
function methods.IsAncestorOf(self, d, other)
	return methods.IsDescendantOf(other, D[other], self)
end
function methods.GetFullName(self, d)
	local parts = {}
	local current = self
	while current and current ~= gameRoot do
		table.insert(parts, 1, D[current].Props.Name)
		current = D[current].Parent
	end
	return table.concat(parts, ".")
end
function methods.ClearAllChildren(self, d)
	for _, child in ipairs(table.clone(d.Children)) do
		child:Destroy()
	end
end
function methods.Destroy(self, d)
	if d.Destroyed then
		return
	end
	fireSignal(eventOf(self, "Destroying"), nil)
	for _, child in ipairs(table.clone(d.Children)) do
		methods.Destroy(child, D[child])
	end
	setParent(self, nil)
	d.Destroyed = true
	for _, signal in pairs(d.Events) do
		for _, conn in ipairs(signal.Conns) do
			conn.Connected = false
		end
	end
end
function methods.Clone(self, d)
	local copy = newInstance(d.ClassName)
	local cd = D[copy]
	for k, v in pairs(d.Props) do
		cd.Props[k] = v
	end
	for k, v in pairs(d.Attributes) do
		cd.Attributes[k] = v
	end
	if collection.Tags[self] then
		collection.Tags[copy] = table.clone(collection.Tags[self])
	end
	for _, child in ipairs(d.Children) do
		local childCopy = methods.Clone(child, D[child])
		setParent(childCopy, copy)
	end
	if d.ClassName == "Model" and d.Props.PrimaryPart then
		cd.Props.PrimaryPart = nil
	end
	return copy
end
local ATTR_TYPES = {
	boolean = true, number = true, string = true, UDim = true, UDim2 = true, Color3 = true, Vector2 = true,
	Vector3 = true, CFrame = true, NumberSequence = true, ColorSequence = true, NumberRange = true, Font = true, EnumItem = true,
}
function methods.SetAttribute(self, d, name, value)
	if type(name) ~= "string" or not string.match(name, "^[%w_]+$") or #name > 100 or string.sub(name, 1, 3) == "RBX" then
		fail("SetAttribute: неверное имя атрибута " .. tostring(name))
	end
	if value ~= nil and not ATTR_TYPES[mtype(value)] then
		fail("SetAttribute(" .. name .. "): тип " .. mtype(value) .. " не поддерживается")
	end
	if d.Attributes[name] == value then
		return
	end
	d.Attributes[name] = value
	if d.AttrSignals[name] then
		fireSignal(d.AttrSignals[name], nil)
	end
	fireSignal(eventOf(self, "AttributeChanged"), nil, name)
end
function methods.GetAttribute(self, d, name)
	return d.Attributes[name]
end
function methods.GetAttributes(self, d)
	return table.clone(d.Attributes)
end
function methods.GetAttributeChangedSignal(self, d, name)
	d.AttrSignals[name] = d.AttrSignals[name] or newSignal("Attr:" .. name)
	return d.AttrSignals[name]
end
function methods.GetPropertyChangedSignal(self, d, prop)
	if findMember(d.ClassName, "P", prop) == nil then
		fail("GetPropertyChangedSignal: у " .. d.ClassName .. " нет свойства " .. tostring(prop))
	end
	return propSignal(d, prop)
end
-- Instance:AddTag(tag) и CollectionService:AddTag(instance, tag)
local function tagArgs(self, d, a, b)
	if d.ClassName == "CollectionService" then
		if not isInst(a) then
			fail("CollectionService: первый аргумент должен быть Instance")
		end
		return a, b
	end
	return self, a
end
function methods.AddTag(self, d, a, b)
	local inst, tag = tagArgs(self, d, a, b)
	if type(tag) ~= "string" then
		fail("AddTag: тег должен быть строкой")
	end
	collection.Tags[inst] = collection.Tags[inst] or {}
	if collection.Tags[inst][tag] then
		return
	end
	collection.Tags[inst][tag] = true
	if inGame(inst) and collection.Added[tag] then
		fireSignal(collection.Added[tag], nil, inst)
	end
end
function methods.HasTag(self, d, a, b)
	local inst, tag = tagArgs(self, d, a, b)
	return collection.Tags[inst] ~= nil and collection.Tags[inst][tag] == true
end

------------------------------------------------------------------------ ДЕТАЛИ И МОДЕЛИ
getters.Position = function(self, d)
	if isA(d.ClassName, "BasePart") then
		return (d.Props.CFrame or IDENTITY).Position
	end
	return nil
end
setters.Position = function(self, d, value)
	if isA(d.ClassName, "BasePart") then
		local c = d.Props.CFrame or IDENTITY
		d.Props.CFrame = cfmul(cf(value.X, value.Y, value.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1), c.Rotation)
	else
		d.Props.Position = value
	end
end
setters.CFrame = function(self, d, value)
	d.Props.CFrame = value
	if d.PropSignals.Position then
		fireSignal(d.PropSignals.Position, nil)
	end
end

local function partsOf(model)
	local list = {}
	for _, desc in ipairs(descendants(model)) do
		if isA(D[desc].ClassName, "BasePart") then
			table.insert(list, desc)
		end
	end
	return list
end
local function boundingBox(model)
	local minV, maxV
	for _, part in ipairs(partsOf(model)) do
		local pd = D[part]
		local c = pd.Props.CFrame or IDENTITY
		local s = pd.Props.Size or DEFAULTS.Size_BasePart
		for _, sx in ipairs({ -0.5, 0.5 }) do
			for _, sy in ipairs({ -0.5, 0.5 }) do
				for _, sz in ipairs({ -0.5, 0.5 }) do
					local p = cfpoint(c, v3(s.X * sx, s.Y * sy, s.Z * sz))
					minV = minV and v3(math.min(minV.X, p.X), math.min(minV.Y, p.Y), math.min(minV.Z, p.Z)) or p
					maxV = maxV and v3(math.max(maxV.X, p.X), math.max(maxV.Y, p.Y), math.max(maxV.Z, p.Z)) or p
				end
			end
		end
	end
	if not minV then
		return IDENTITY, Vector3.zero
	end
	local center = (minV + maxV) / 2
	return cf(center.X, center.Y, center.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1), maxV - minV
end
function methods.GetPivot(self, d)
	if isA(d.ClassName, "BasePart") then
		return d.Props.CFrame or IDENTITY
	end
	local primary = d.Props.PrimaryPart
	if primary and D[primary] then
		return D[primary].Props.CFrame or IDENTITY
	end
	if not d.Props.WorldPivot then
		d.Props.WorldPivot = (boundingBox(self))
	end
	return d.Props.WorldPivot
end
function methods.PivotTo(self, d, target)
	if mtype(target) ~= "CFrame" then
		fail("PivotTo ожидает CFrame")
	end
	if isA(d.ClassName, "BasePart") then
		self.CFrame = target
		return
	end
	local current = methods.GetPivot(self, d)
	local delta = cfmul(target, cfinv(current))
	for _, part in ipairs(partsOf(self)) do
		local pd = D[part]
		pd.Props.CFrame = cfmul(delta, pd.Props.CFrame or IDENTITY)
	end
	if not d.Props.PrimaryPart then
		d.Props.WorldPivot = target
	end
end
function methods.GetBoundingBox(self, d)
	return boundingBox(self)
end
function methods.GetExtentsSize(self, d)
	local _, size = boundingBox(self)
	return size
end
methods.BulkMoveTo = function(self, d, parts, cframes, mode)
	if type(parts) ~= "table" or type(cframes) ~= "table" or #parts ~= #cframes then
		fail("BulkMoveTo: списки разной длины")
	end
	if mode ~= nil and (mtype(mode) ~= "EnumItem" or mode.EnumType ~= "BulkMoveMode") then
		fail("BulkMoveTo: неверный режим")
	end
	for i, part in ipairs(parts) do
		if not isInst(part) or not isA(D[part].ClassName, "BasePart") then
			fail("BulkMoveTo: элемент " .. i .. " не BasePart")
		end
		if mtype(cframes[i]) ~= "CFrame" then
			fail("BulkMoveTo: элемент " .. i .. " не CFrame")
		end
		D[part].Props.CFrame = cframes[i]
	end
	M.bulkMoves = (M.bulkMoves or 0) + 1
end

------------------------------------------------------------------------ GUI
local function guiAbs(self)
	local d = D[self]
	if isA(d.ClassName, "LayerCollector") then
		return 0, 0, M.screenSize[1], M.screenSize[2]
	end
	if not isA(d.ClassName, "GuiObject") then
		return 0, 0, M.screenSize[1], M.screenSize[2]
	end
	local px, py, pw, ph = 0, 0, M.screenSize[1], M.screenSize[2]
	if d.Parent and (isA(D[d.Parent].ClassName, "GuiObject") or isA(D[d.Parent].ClassName, "LayerCollector")) then
		px, py, pw, ph = guiAbs(d.Parent)
	end
	local size = d.Props.Size or DEFAULTS.Size_GuiObject
	local pos = d.Props.Position or UDim2.new()
	local anchor = d.Props.AnchorPoint or Vector2.zero
	local w = size.X.Scale * pw + size.X.Offset
	local h = size.Y.Scale * ph + size.Y.Offset
	local x = px + pos.X.Scale * pw + pos.X.Offset - anchor.X * w
	local y = py + pos.Y.Scale * ph + pos.Y.Offset - anchor.Y * h
	return x, y, w, h
end
getters.AbsoluteSize = function(self)
	local _, _, w, h = guiAbs(self)
	return v2(w, h)
end
getters.AbsolutePosition = function(self)
	local x, y = guiAbs(self)
	return v2(x, y)
end

------------------------------------------------------------------------ СЕРВИСЫ
local services = {}
local function service(name)
	local svc = services[name]
	if svc then
		return svc
	end
	local cls = Classes[name]
	if not cls or not string.find(cls.F, "s") then
		fail("GetService: " .. tostring(name) .. " не сервис")
	end
	svc = newInstance(name)
	D[svc].Props.Name = name
	services[name] = svc
	setParent(svc, gameRoot)
	return svc
end
methods.GetService = function(self, d, name)
	return service(name)
end
methods.FindService = function(self, d, name)
	return services[name]
end

-- Players
local players = {}
getters.LocalPlayer = function(self, d)
	return currentCtx.player
end
methods.GetPlayers = function(self, d)
	local list = {}
	for _, p in ipairs(players) do
		if D[p].Parent then
			table.insert(list, p)
		end
	end
	return list
end
methods.GetPlayerFromCharacter = function(self, d, character)
	for _, p in ipairs(players) do
		if D[p].Props.Character == character then
			return p
		end
	end
	return nil
end
methods.Kick = function(self, d, message)
	table.insert(M.warnings, "Kick: " .. tostring(message))
end
methods.RequestStreamAroundAsync = function(self, d, position, timeout)
	if currentCtx ~= SERVER then
		fail("RequestStreamAroundAsync можно вызывать только на сервере")
	end
	task.wait(0.05)
end

-- RunService
methods.IsServer = function()
	return currentCtx == SERVER
end
methods.IsClient = function()
	return currentCtx ~= SERVER
end
methods.IsStudio = function()
	return true
end
methods.IsRunning = function()
	return true
end

-- Camera
methods.WorldToScreenPoint = function(self, d, point)
	return v3(M.screenSize[1] / 2, M.screenSize[2] / 2, 10), true
end
methods.WorldToViewportPoint = methods.WorldToScreenPoint

-- GuiService
methods.GetGuiInset = function()
	return v2(0, 58), v2(0, 0)
end

-- StarterGui
methods.SetCoreGuiEnabled = function(self, d, kind, enabled)
	if mtype(kind) ~= "EnumItem" or kind.EnumType ~= "CoreGuiType" then
		fail("SetCoreGuiEnabled: ожидался Enum.CoreGuiType")
	end
end
methods.SetCore = function() end

-- Debris
methods.AddItem = function(self, d, item, lifetime)
	if not isInst(item) then
		fail("Debris:AddItem ожидает Instance")
	end
	task.delay(lifetime or 10, function()
		if D[item] and not D[item].Destroyed then
			item:Destroy()
		end
	end)
end

-- Sound
methods.Play = function(self, d)
	if d.ClassName == "Sound" then
		d.Props.IsPlaying = true
		M.soundsPlayed = (M.soundsPlayed or 0) + 1
		local id = d.Props.SoundId or ""
		M.soundIds = M.soundIds or {}
		M.soundIds[id] = true
		if not d.Props.Looped then
			task.delay(0.5, function()
				if D[self] and not D[self].Destroyed then
					d.Props.IsPlaying = false
					fireSignal(eventOf(self, "Ended"), nil, id)
				end
			end)
		end
	elseif d.ClassName == "Tween" then
		d.Play(self)
	end
end
methods.Stop = function(self, d)
	d.Props.IsPlaying = false
end

-- CollectionService
methods.GetTagged = function(self, d, tag)
	local list = {}
	for inst, tags in pairs(collection.Tags) do
		if tags[tag] and D[inst] and not D[inst].Destroyed and inGame(inst) then
			table.insert(list, inst)
		end
	end
	return list
end
methods.GetInstanceAddedSignal = function(self, d, tag)
	collection.Added[tag] = collection.Added[tag] or newSignal("TagAdded:" .. tag)
	return collection.Added[tag]
end
methods.GetInstanceRemovedSignal = function(self, d, tag)
	collection.Removed[tag] = collection.Removed[tag] or newSignal("TagRemoved:" .. tag)
	return collection.Removed[tag]
end
methods.RemoveTag = function(self, d, a, b)
	local inst, tag = tagArgs(self, d, a, b)
	if collection.Tags[inst] then
		collection.Tags[inst][tag] = nil
	end
end

-- TweenService
methods.Create = function(self, d, inst, info, goals)
	if not isInst(inst) then
		fail("TweenService:Create: первый аргумент не Instance")
	end
	if mtype(info) ~= "TweenInfo" then
		fail("TweenService:Create: второй аргумент не TweenInfo")
	end
	if type(goals) ~= "table" then
		fail("TweenService:Create: цели должны быть таблицей")
	end
	for key, value in pairs(goals) do
		local spec = findMember(D[inst].ClassName, "P", key)
		if not spec then
			fail("Tween: у " .. D[inst].ClassName .. " нет свойства " .. tostring(key))
		end
		local valueType = mtype(value)
		local okTypes = { number = true, boolean = true, Vector3 = true, Vector2 = true, CFrame = true, Color3 = true, UDim2 = true, UDim = true, EnumItem = true }
		if not okTypes[valueType] then
			fail("Tween: свойство " .. key .. " типа " .. valueType .. " нельзя анимировать")
		end
		checkValue(D[inst].ClassName, key, spec, value)
	end
	local tween = newInstance("Tween")
	local td = D[tween]
	td.Play = function()
		if td.Started then
			return
		end
		td.Started = true
		if info.RepeatCount < 0 then
			return
		end
		task.delay(info.Time * (info.RepeatCount + 1) + info.DelayTime, function()
			if td.Cancelled then
				return
			end
			if D[inst] and not D[inst].Destroyed then
				for key, value in pairs(goals) do
					inst[key] = value
				end
			end
			fireSignal(eventOf(tween, "Completed"), nil, enumItem("PlaybackState", "Completed"))
		end)
	end
	return tween
end
methods.Cancel = function(self, d)
	d.Cancelled = true
end
methods.Pause = function() end

-- DataStoreService
M.dataStores = {}
M.dataStoreFailures = 0
local function checkJson(value, path, seen)
	local t = type(value)
	if t == "string" or t == "boolean" then
		return
	elseif t == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			fail("DataStore: недопустимое число в " .. path)
		end
		return
	elseif t == "table" then
		if getmetatable(value) ~= nil then
			fail("DataStore: значение " .. path .. " типа " .. mtype(value) .. " нельзя сохранить")
		end
		local n = #value
		local count = 0
		for k, v in pairs(value) do
			count += 1
			if type(k) == "number" then
				if k < 1 or k > n or k ~= math.floor(k) then
					fail("DataStore: массив с дырами в " .. path)
				end
			elseif type(k) ~= "string" then
				fail("DataStore: ключ типа " .. type(k) .. " в " .. path)
			end
			checkJson(v, path .. "." .. tostring(k), seen)
		end
		if n > 0 and count ~= n then
			fail("DataStore: смешанная таблица в " .. path)
		end
		return
	end
	fail("DataStore: значение типа " .. t .. " в " .. path)
end
local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end
M.deepCopy = deepCopy
local DSmt = { __mocktype = "Instance" }
DSmt.__index = {
	GetAsync = function(self, key)
		task.wait(0.05)
		if M.dataStoreFailures > 0 then
			M.dataStoreFailures -= 1
			error("502: API Services rejected request (mock)")
		end
		return deepCopy(M.dataStores[self.Name][key])
	end,
	SetAsync = function(self, key, value)
		task.wait(0.05)
		checkJson(value, key, {})
		M.dataStores[self.Name][key] = deepCopy(value)
	end,
	UpdateAsync = function(self, key, transform)
		task.wait(0.05)
		local result = transform(deepCopy(M.dataStores[self.Name][key]))
		if result ~= nil then
			checkJson(result, key, {})
			M.dataStores[self.Name][key] = deepCopy(result)
			M.saves = (M.saves or 0) + 1
		end
		return result
	end,
}
methods.GetDataStore = function(self, d, name)
	M.dataStores[name] = M.dataStores[name] or {}
	return setmetatable({ Name = name }, DSmt)
end

-- MarketplaceService
M.purchasePrompts = {}
methods.UserOwnsGamePassAsync = function(self, d, userId, id)
	task.wait(0.02)
	return false
end
methods.PromptGamePassPurchase = function(self, d, player, id)
	table.insert(M.purchasePrompts, id)
end

------------------------------------------------------------------------ REMOTES
local function serialize(value, depth)
	depth = depth or 0
	if depth > 50 then
		fail("Remote: слишком глубокая таблица")
	end
	local t = mtype(value)
	if t == "function" or t == "thread" then
		fail("Remote: нельзя передать " .. t)
	end
	if t == "table" then
		local copy = {}
		local hasNum, hasStr = false, false
		for k, v in pairs(value) do
			if type(k) == "number" then
				hasNum = true
			else
				hasStr = true
			end
			copy[k] = serialize(v, depth + 1)
		end
		if hasNum and hasStr then
			table.insert(M.warnings, "Remote: смешанная таблица — часть ключей потеряется")
		end
		return copy
	end
	return value
end
local function packArgs(...)
	local args = table.pack(...)
	for i = 1, args.n do
		args[i] = serialize(args[i])
	end
	return args
end
methods.FireServer = function(self, d, ...)
	if currentCtx == SERVER then
		fail("FireServer вызван на сервере")
	end
	local player = currentCtx.player
	local args = packArgs(...)
	M.remoteLog = M.remoteLog or {}
	M.remoteLog[d.Props.Name] = (M.remoteLog[d.Props.Name] or 0) + 1
	local co = newCo(function()
		fireSignal(eventOf(self, "OnServerEvent"), function(ctx)
			return ctx == SERVER
		end, player, table.unpack(args, 1, args.n))
	end, SERVER)
	enqueue(M.now + 0.03, co)
end
methods.FireClient = function(self, d, player, ...)
	if currentCtx ~= SERVER then
		fail("FireClient вызван на клиенте")
	end
	if not isInst(player) or D[player].ClassName ~= "Player" then
		fail("FireClient: первый аргумент должен быть Player")
	end
	local args = packArgs(...)
	M.remoteLog = M.remoteLog or {}
	M.remoteLog[d.Props.Name] = (M.remoteLog[d.Props.Name] or 0) + 1
	local co = newCo(function()
		fireSignal(eventOf(self, "OnClientEvent"), function(ctx)
			return ctx ~= SERVER and ctx.player == player
		end, table.unpack(args, 1, args.n))
	end, SERVER)
	enqueue(M.now + 0.03, co)
end
methods.FireAllClients = function(self, d, ...)
	for _, player in ipairs(players) do
		methods.FireClient(self, d, player, ...)
	end
end
methods.InvokeServer = function(self, d, ...)
	if currentCtx == SERVER then
		fail("InvokeServer вызван на сервере")
	end
	local player = currentCtx.player
	local args = packArgs(...)
	local caller = coroutine.running()
	local co = newCo(function()
		task.wait(0.03)
		local callback = d.Callbacks.OnServerInvoke
		while not callback do
			task.wait(0.1)
			callback = d.Callbacks.OnServerInvoke
		end
		local results = table.pack(pcall(callback, player, table.unpack(args, 1, args.n)))
		task.wait(0.03)
		if not results[1] then
			recordError("OnServerInvoke " .. d.Props.Name .. ": " .. tostring(results[2]))
			resumeCo(caller, false, "error")
			return
		end
		for i = 2, results.n do
			results[i] = serialize(results[i])
		end
		resumeCo(caller, true, table.unpack(results, 2, results.n))
	end, SERVER)
	enqueue(M.now, co)
	local packed = table.pack(coroutine.yield())
	if not packed[1] then
		error("Server error in " .. d.Props.Name, 2)
	end
	return table.unpack(packed, 2, packed.n)
end

------------------------------------------------------------------------ КЛАССЫ: НАСТРОЙКА ПРИ СОЗДАНИИ
classSetup.Workspace = function(self, d)
	local camera = newInstance("Camera")
	D[camera].Props.Name = "Camera"
	setParent(camera, self)
	d.Props.CurrentCamera = camera
	d.Props.Gravity = 196.2
	local terrain = newInstance("Terrain")
	D[terrain].Props.Name = "Terrain"
	setParent(terrain, self)
	d.Props.Terrain = terrain
end

------------------------------------------------------------------------ TERRAIN (упрощённо: только столбцы по вертикали)
M.terrainFills = {}
local function checkMaterial(material, where)
	if mtype(material) ~= "EnumItem" or material.EnumType ~= "Material" then
		fail(where .. ": ожидался Enum.Material")
	end
end
methods.FillBlock = function(self, d, cframe, size, material)
	if mtype(cframe) ~= "CFrame" or mtype(size) ~= "Vector3" then
		fail("FillBlock(CFrame, Vector3, Material)")
	end
	checkMaterial(material, "FillBlock")
	table.insert(M.terrainFills, { Kind = "Block", Center = cframe.Position, Size = size, Material = material.Name })
end
methods.FillBall = function(self, d, center, radius, material)
	if mtype(center) ~= "Vector3" or type(radius) ~= "number" then
		fail("FillBall(Vector3, number, Material)")
	end
	checkMaterial(material, "FillBall")
	table.insert(M.terrainFills, { Kind = "Ball", Center = center, Radius = radius, Material = material.Name })
end
methods.FillCylinder = function(self, d, cframe, height, radius, material)
	if mtype(cframe) ~= "CFrame" or type(height) ~= "number" or type(radius) ~= "number" then
		fail("FillCylinder(CFrame, number, number, Material)")
	end
	checkMaterial(material, "FillCylinder")
	table.insert(M.terrainFills, { Kind = "Cylinder", Center = cframe.Position, Height = height, Radius = radius, Material = material.Name })
end
methods.Clear = function(self, d)
	if d.ClassName == "Terrain" then
		M.terrainFills = {}
	end
end
methods.SetMaterialColor = function(self, d, material, color)
	checkMaterial(material, "SetMaterialColor")
	if mtype(color) ~= "Color3" then
		fail("SetMaterialColor: ожидался Color3")
	end
end
-- Вертикальный «столбец» рельефа в точке (x, z): список отрезков { lo, hi, материал }.
local function terrainColumn(x, z)
	local intervals = {}
	local function subtract(lo, hi)
		local result = {}
		for _, item in ipairs(intervals) do
			if item[2] <= lo or item[1] >= hi then
				table.insert(result, item)
			else
				if item[1] < lo then
					table.insert(result, { item[1], lo, item[3] })
				end
				if item[2] > hi then
					table.insert(result, { hi, item[2], item[3] })
				end
			end
		end
		intervals = result
	end
	for _, fill in ipairs(M.terrainFills) do
		local lo, hi
		local c = fill.Center
		if fill.Kind == "Block" then
			if math.abs(x - c.X) <= fill.Size.X / 2 and math.abs(z - c.Z) <= fill.Size.Z / 2 then
				lo, hi = c.Y - fill.Size.Y / 2, c.Y + fill.Size.Y / 2
			end
		elseif fill.Kind == "Ball" then
			local d2 = (x - c.X) ^ 2 + (z - c.Z) ^ 2
			if d2 < fill.Radius ^ 2 then
				local h = math.sqrt(fill.Radius ^ 2 - d2)
				lo, hi = c.Y - h, c.Y + h
			end
		elseif fill.Kind == "Cylinder" then
			if (x - c.X) ^ 2 + (z - c.Z) ^ 2 < fill.Radius ^ 2 then
				lo, hi = c.Y - fill.Height / 2, c.Y + fill.Height / 2
			end
		end
		if lo then
			subtract(lo, hi)
			if fill.Material ~= "Air" then
				table.insert(intervals, { lo, hi, fill.Material })
			end
		end
	end
	return intervals
end
M.terrainColumn = terrainColumn
methods.Raycast = function(self, d, origin, direction, params)
	if mtype(origin) ~= "Vector3" or mtype(direction) ~= "Vector3" then
		fail("Raycast(Vector3, Vector3, RaycastParams)")
	end
	if params ~= nil and mtype(params) ~= "RaycastParams" then
		fail("Raycast: третий аргумент должен быть RaycastParams")
	end
	M.raycasts = (M.raycasts or 0) + 1
	if math.abs(direction.X) > 1e-6 or math.abs(direction.Z) > 1e-6 or direction.Y >= 0 then
		return nil -- мок умеет только лучи строго вниз
	end
	local bottom = origin.Y + direction.Y
	local best
	for _, item in ipairs(terrainColumn(origin.X, origin.Z)) do
		local top = item[2]
		if top <= origin.Y and top >= bottom and (not best or top > best[2]) then
			if not (params and params.IgnoreWater and item[3] == "Water") then
				best = item
			end
		end
	end
	if not best then
		return nil
	end
	return makeRaycastResult({
		Position = v3(origin.X, best[2], origin.Z),
		Normal = Vector3.yAxis,
		Material = enumItem("Material", best[3]),
		Instance = D[self].Props.Terrain,
		Distance = origin.Y - best[2],
	})
end

------------------------------------------------------------------------ ЗВУКИ: поиск и загрузка
M.audioSearches = 0
methods.SearchAudioAsync = function(self, d, params)
	if not isInst(params) or D[params].ClassName ~= "AudioSearchParams" then
		fail("SearchAudioAsync ожидает AudioSearchParams")
	end
	task.wait(0.05)
	M.audioSearches += 1
	local pages = newInstance("AudioPages")
	local items = {}
	for i = 1, 8 do
		table.insert(items, {
			Id = 9000000 + M.audioSearches * 10 + i,
			Title = tostring(D[params].Props.SearchKeyword) .. " " .. i,
			Duration = 2,
			IsEndorsed = i == 3,
			Creator = { Name = i == 2 and "Roblox" or "Someone", Id = i == 2 and 1 or 777 },
		})
	end
	D[pages].Items = items
	return pages
end
methods.GetCurrentPage = function(self, d)
	return d.Items or {}
end
M.preloads = 0
methods.PreloadAsync = function(self, d, list, callback)
	if type(list) ~= "table" then
		fail("PreloadAsync ожидает список")
	end
	task.wait(0.05)
	for _, item in ipairs(list) do
		M.preloads += 1
		local id = isInst(item) and (D[item].Props.SoundId or "") or tostring(item)
		-- для проверки: «недоступные» звуки — с номером, оканчивающимся на 1
		local status = string.match(id, "1$") and "Failure" or "Success"
		if callback then
			callback(id, enumItem("AssetFetchStatus", status))
		end
	end
end
methods.InputHoldBegin = function(self, d)
	local player = currentCtx.player
	if player then
		local prompt = self
		local co = newCo(function()
			fireSignal(eventOf(prompt, "Triggered"), nil, player)
			fireSignal(eventOf(service("ProximityPromptService"), "PromptTriggered"), nil, prompt, player)
		end, SERVER)
		enqueue(M.now + 0.03, co)
	end
end
methods.InputHoldEnd = function() end

------------------------------------------------------------------------ ИГРА
gameRoot = newInstance("DataModel")
D[gameRoot].Props.Name = "Game"
getters.PlaceId = function(self, d)
	if d.ClassName == "DataModel" then
		return M.placeId
	end
	return nil
end
M.bindToClose = {}
methods.BindToClose = function(self, d, fn)
	table.insert(M.bindToClose, { Fn = fn, Ctx = currentCtx })
end
M.game = gameRoot
M.service = service
M.D = D

------------------------------------------------------------------------ ОКРУЖЕНИЕ СКРИПТОВ
local G = {
	game = gameRoot,
	Game = gameRoot,
	Vector3 = Vector3,
	Vector2 = Vector2,
	CFrame = CFrame,
	Color3 = Color3,
	UDim = UDim,
	UDim2 = UDim2,
	ColorSequence = ColorSequence,
	ColorSequenceKeypoint = ColorSequenceKeypoint,
	NumberSequence = NumberSequence,
	NumberSequenceKeypoint = NumberSequenceKeypoint,
	NumberRange = NumberRange,
	TweenInfo = TweenInfo,
	Random = Random,
	Font = Font,
	RaycastParams = RaycastParams,
	Enum = Enum,
	Instance = Instance,
	task = task,
	typeof = mtype,
	tick = function()
		return 1767225600 + M.now
	end,
	time = function()
		return M.now
	end,
	wait = task.wait,
	spawn = task.spawn,
	delay = task.delay,
	warn = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		table.insert(M.warnings, table.concat(parts, " "))
	end,
	print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		table.insert(M.prints, table.concat(parts, " "))
	end,
	os = setmetatable({
		clock = function()
			return M.now
		end,
		time = function()
			return 1767225600 + math.floor(M.now)
		end,
	}, { __index = os }),
}
G.workspace = service("Workspace")
M.G = G
G.shared = {}
setmetatable(G, { __index = _G })

local moduleCache = {} -- [ctx][module] = { Loaded, Value }
local function requireModule(target)
	if not isInst(target) or D[target].ClassName ~= "ModuleScript" then
		error("require ожидает ModuleScript, получено " .. mtype(target), 2)
	end
	local cache = moduleCache[currentCtx]
	if not cache then
		cache = {}
		moduleCache[currentCtx] = cache
	end
	local entry = cache[target]
	if entry then
		if not entry.Loaded then
			error("Циклический require: " .. D[target].SourcePath, 2)
		end
		return entry.Value
	end
	entry = { Loaded = false }
	cache[target] = entry
	local chunk = M.loadChunk(target)
	local results = table.pack(chunk())
	if results.n ~= 1 then
		error("Модуль " .. D[target].SourcePath .. " должен вернуть ровно одно значение", 2)
	end
	entry.Value = results[1]
	entry.Loaded = true
	return entry.Value
end
G.require = requireModule

local function loadChunk(inst)
	local d = D[inst]
	local path = d.SourcePath
	if not path then
		fail("У скрипта " .. tostring(d.Props.Name) .. " нет исходника")
	end
	local source = SOURCES[path]
	local fn, err = loadstring(source, "=" .. path)
	if not fn then
		error("Ошибка компиляции " .. path .. ": " .. tostring(err))
	end
	local env = setmetatable({ script = inst }, { __index = G })
	setfenv(fn, env)
	return fn
end
M.loadChunk = loadChunk

-- Запуск Script / LocalScript в контексте.
function M.runScript(inst, ctx)
	local fn = loadChunk(inst)
	local co = newCo(fn, ctx)
	resumeCo(co)
end

-- Построение дерева из TREE (как делает Rojo).
local function ensurePath(segments)
	local current = gameRoot
	for i, name in ipairs(segments) do
		local child
		if i == 1 then
			child = service(name)
		else
			child = methods.FindFirstChild(current, D[current], name)
		end
		if not child then
			child = newInstance("Folder")
			D[child].Props.Name = name
			setParent(child, current)
		end
		current = child
	end
	return current
end
function M.buildTree()
	for _, node in ipairs(TREE) do
		local segments = string.split(node.path, "/")
		local name = table.remove(segments)
		local parent = ensurePath(segments)
		local inst = methods.FindFirstChild(parent, D[parent], name)
		if inst and D[inst].ClassName ~= node.class then
			-- папка-заглушка, созданная раньше, становится нужным классом
			local old = inst
			inst = newInstance(node.class)
			D[inst].Props.Name = name
			for _, child in ipairs(table.clone(D[old].Children)) do
				setParent(child, inst)
			end
			setParent(old, nil)
			setParent(inst, parent)
		elseif not inst then
			inst = newInstance(node.class)
			D[inst].Props.Name = name
			setParent(inst, parent)
		end
		if node.source then
			D[inst].SourcePath = node.source
		end
		for key, value in pairs(node.props or {}) do
			if type(value) == "string" then
				local spec = findMember(node.class, "P", key)
				if spec and string.match(spec, "^Enum:") then
					value = enumItem(string.match(spec, "^Enum:([^:]+)"), value)
				end
			end
			inst[key] = value
		end
	end
end

-- Игроки.
function M.addPlayer(name, userId)
	local player = newInstance("Player")
	local d = D[player]
	d.Props.Name = name
	d.Props.UserId = userId
	d.Props.DisplayName = name
	table.insert(players, player)
	local playerGui = newInstance("PlayerGui")
	D[playerGui].Props.Name = "PlayerGui"
	setParent(playerGui, player)
	local playerScripts = newInstance("PlayerScripts")
	D[playerScripts].Props.Name = "PlayerScripts"
	setParent(playerScripts, player)
	setParent(player, service("Players"))
	local ctx = { name = "client:" .. name, player = player }
	d.Ctx = ctx
	local co = newCo(function()
		fireSignal(eventOf(service("Players"), "PlayerAdded"), function(c)
			return c == SERVER
		end, player)
	end, SERVER)
	resumeCo(co)
	return player, ctx
end
function M.removePlayer(player)
	local co = newCo(function()
		fireSignal(eventOf(service("Players"), "PlayerRemoving"), nil, player)
		setParent(player, nil)
	end, SERVER)
	resumeCo(co)
end
function M.spawnCharacter(player, position)
	local d = D[player]
	if d.Props.Character then
		methods.Destroy(d.Props.Character, D[d.Props.Character])
	end
	local character = newInstance("Model")
	D[character].Props.Name = d.Props.Name
	local root = newInstance("Part")
	D[root].Props.Name = "HumanoidRootPart"
	D[root].Props.Size = v3(2, 2, 1)
	D[root].Props.CFrame = cf(position.X, position.Y + 3, position.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	setParent(root, character)
	local head = newInstance("Part")
	D[head].Props.Name = "Head"
	D[head].Props.CFrame = cf(position.X, position.Y + 4.5, position.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	setParent(head, character)
	local humanoid = newInstance("Humanoid")
	D[humanoid].Props.Name = "Humanoid"
	setParent(humanoid, character)
	D[character].Props.PrimaryPart = root
	setParent(character, service("Workspace"))
	d.Props.Character = character
	-- StarterGui -> PlayerGui (ResetOnSpawn = false копируется один раз)
	local playerGui = methods.FindFirstChild(player, d, "PlayerGui")
	for _, item in ipairs(D[service("StarterGui")].Children) do
		local existing = methods.FindFirstChild(playerGui, D[playerGui], D[item].Props.Name)
		if not existing then
			setParent(methods.Clone(item, D[item]), playerGui)
		end
	end
	local co = newCo(function()
		fireSignal(eventOf(player, "CharacterAdded"), nil, character)
	end, SERVER)
	resumeCo(co)
	return character
end

function M.step(dt)
	dt = dt or 1 / 60
	local target = M.now + dt
	runDue(target)
	M.now = target
	local runService = service("RunService")
	local co = newCo(function()
		fireSignal(eventOf(runService, "RenderStepped"), nil, dt)
		fireSignal(eventOf(runService, "Heartbeat"), nil, dt)
	end, SERVER)
	resumeCo(co)
	runDue(M.now)
end
function M.run(seconds, dt)
	local finish = M.now + seconds
	while M.now < finish - 1e-9 do
		M.step(dt or 1 / 30)
	end
end
-- Выполнить функцию в контексте (как будто это код сервера или клиента).
function M.inCtx(ctx, fn, ...)
	local co = newCo(fn, ctx)
	resumeCo(co, ...)
end
function M.requireIn(ctx, inst)
	local result
	local co = newCo(function()
		result = requireModule(inst)
	end, ctx)
	resumeCo(co)
	return result
end
function M.closeGame()
	for _, item in ipairs(M.bindToClose) do
		local co = newCo(item.Fn, item.Ctx)
		resumeCo(co)
	end
end
M.fireTouched = function(part, hit)
	local co = newCo(function()
		fireSignal(eventOf(part, "Touched"), nil, hit)
	end, SERVER)
	resumeCo(co)
end
M.isA = isA
M.collection = collection

return M
