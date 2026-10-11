-- tools/mock/mini.lua
-- Маленький мок Roblox API для прогона кода карты в Lua 5.4 (через Python lupa) без Roblox Studio.
-- Умеет: Vector3 / CFrame / Color3 и прочие типы, Enum с проверкой имён, Instance со строгими
-- списками свойств и проверкой типов, Terrain (запоминает все заливки), службы, task, TweenService.
-- Ошибки скриптов копятся в M.errors, предупреждения — в M.warns. Цель — поймать опечатки
-- и неверные типы до запуска в Studio, а заодно выгрузить детали и рельеф для превью.

local M = { errors = {}, warns = {}, prints = {}, terrainOps = {}, heartbeat = {}, deferred = {} }

local floor, sqrt, sin, cos, abs = math.floor, math.sqrt, math.sin, math.cos, math.abs
local atan2 = function(y, x) return math.atan(y, x) end

local function typeErr(msg) error(msg, 3) end

---------------------------------------------------------------------------
-- typeof
---------------------------------------------------------------------------
local TYPE = {}           -- metatable -> имя типа
local function typeof(v)
	local mt = getmetatable(v)
	if mt and TYPE[mt] then return TYPE[mt] end
	return type(v)
end
M.typeof = typeof

local function frozen(mt, name)
	TYPE[mt] = name
	mt.__newindex = function(_, k) error(name .. "." .. tostring(k) .. " cannot be assigned to", 2) end
	mt.__metatable = nil
	return mt
end

---------------------------------------------------------------------------
-- Vector3 / Vector2
---------------------------------------------------------------------------
local V3 = {}
local V3mt = {}
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3mt) end
local function isV3(v) return getmetatable(v) == V3mt end
local V3methods = {}
V3mt.__index = function(t, k)
	if k == "Magnitude" then return sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then
		local m = sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		if m == 0 then return v3(0 / 0, 0 / 0, 0 / 0) end
		return v3(t.X / m, t.Y / m, t.Z / m)
	end
	if k == "x" then return t.X elseif k == "y" then return t.Y elseif k == "z" then return t.Z end
	local f = V3methods[k]
	if f then return f end
	error(tostring(k) .. " is not a valid member of Vector3", 2)
end
V3mt.__add = function(a, b)
	if not (isV3(a) and isV3(b)) then error("attempt to perform arithmetic (add) on Vector3 and " .. typeof(isV3(a) and b or a), 2) end
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3mt.__sub = function(a, b)
	if not (isV3(a) and isV3(b)) then error("attempt to perform arithmetic (sub) on Vector3 and " .. typeof(isV3(a) and b or a), 2) end
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3mt.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	if isV3(a) and isV3(b) then return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
	error("attempt to perform arithmetic (mul) on Vector3 and " .. typeof(b), 2)
end
V3mt.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	if isV3(a) and isV3(b) then return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z) end
	error("attempt to perform arithmetic (div) on Vector3 and " .. typeof(b), 2)
end
V3mt.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3mt.__tostring = function(a) return string.format("%g, %g, %g", a.X, a.Y, a.Z) end
frozen(V3mt, "Vector3")
function V3methods.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V3methods.Cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V3methods.Lerp(a, b, t) return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end
function V3methods.Abs(a) return v3(abs(a.X), abs(a.Y), abs(a.Z)) end
function V3methods.Min(a, b) return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
function V3methods.Max(a, b) return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
function V3methods.FuzzyEq(a, b, eps) return (a - b).Magnitude <= (eps or 1e-5) end
function V3methods.Floor(a) return v3(floor(a.X), floor(a.Y), floor(a.Z)) end
V3.new = function(x, y, z)
	for _, c in ipairs({ x or 0, y or 0, z or 0 }) do
		if type(c) ~= "number" then error("Vector3.new expects numbers, got " .. typeof(c), 2) end
	end
	return v3(x, y, z)
end
V3.zero, V3.one = v3(0, 0, 0), v3(1, 1, 1)
V3.xAxis, V3.yAxis, V3.zAxis = v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1)

local V2mt = {}
local function v2(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2mt) end
V2mt.__index = function(t, k)
	if k == "Magnitude" then return sqrt(t.X * t.X + t.Y * t.Y) end
	if k == "Unit" then local m = sqrt(t.X * t.X + t.Y * t.Y) return v2(t.X / m, t.Y / m) end
	error(tostring(k) .. " is not a valid member of Vector2", 2)
end
V2mt.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
V2mt.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
V2mt.__mul = function(a, b) if type(b) == "number" then return v2(a.X * b, a.Y * b) end return v2(a.X * b.X, a.Y * b.Y) end
V2mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
frozen(V2mt, "Vector2")
local V2 = { new = function(x, y) return v2(x, y) end, zero = v2(0, 0), one = v2(1, 1) }

---------------------------------------------------------------------------
-- CFrame: позиция p и матрица поворота r (по строкам), world = p + R * local
---------------------------------------------------------------------------
local CFmt = {}
local function cf(px, py, pz, r)
	return setmetatable({ px = px, py = py, pz = pz,
		r = r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CFmt)
end
local function isCF(v) return getmetatable(v) == CFmt end
local function matmul(a, b)
	local o = {}
	for i = 0, 2 do
		for j = 0, 2 do
			o[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return o
end
local function rotv(r, x, y, z)
	return r[1] * x + r[2] * y + r[3] * z, r[4] * x + r[5] * y + r[6] * z, r[7] * x + r[8] * y + r[9] * z
end
local function transpose(r) return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] } end
local function Rx(a) local c, s = cos(a), sin(a) return { 1, 0, 0, 0, c, -s, 0, s, c } end
local function Ry(a) local c, s = cos(a), sin(a) return { c, 0, s, 0, 1, 0, -s, 0, c } end
local function Rz(a) local c, s = cos(a), sin(a) return { c, -s, 0, s, c, 0, 0, 0, 1 } end

local CFmethods = {}
CFmt.__index = function(t, k)
	if k == "Position" or k == "p" then return v3(t.px, t.py, t.pz) end
	if k == "X" then return t.px elseif k == "Y" then return t.py elseif k == "Z" then return t.pz end
	local r = t.r
	if k == "RightVector" or k == "XVector" then return v3(r[1], r[4], r[7]) end
	if k == "UpVector" or k == "YVector" then return v3(r[2], r[5], r[8]) end
	if k == "ZVector" then return v3(r[3], r[6], r[9]) end
	if k == "LookVector" then return v3(-r[3], -r[6], -r[9]) end
	if k == "Rotation" then return cf(0, 0, 0, r) end
	local f = CFmethods[k]
	if f then return f end
	error(tostring(k) .. " is not a valid member of CFrame", 2)
end
CFmt.__mul = function(a, b)
	if not isCF(a) then error("attempt to perform arithmetic (mul) on " .. typeof(a) .. " and CFrame", 2) end
	if isCF(b) then
		local x, y, z = rotv(a.r, b.px, b.py, b.pz)
		return cf(a.px + x, a.py + y, a.pz + z, matmul(a.r, b.r))
	elseif isV3(b) then
		local x, y, z = rotv(a.r, b.X, b.Y, b.Z)
		return v3(a.px + x, a.py + y, a.pz + z)
	end
	error("attempt to perform arithmetic (mul) on CFrame and " .. typeof(b), 2)
end
CFmt.__add = function(a, b)
	if not isV3(b) then error("attempt to perform arithmetic (add) on CFrame and " .. typeof(b), 2) end
	return cf(a.px + b.X, a.py + b.Y, a.pz + b.Z, a.r)
end
CFmt.__sub = function(a, b)
	if not isV3(b) then error("attempt to perform arithmetic (sub) on CFrame and " .. typeof(b), 2) end
	return cf(a.px - b.X, a.py - b.Y, a.pz - b.Z, a.r)
end
CFmt.__eq = function(a, b)
	for i = 1, 9 do if a.r[i] ~= b.r[i] then return false end end
	return a.px == b.px and a.py == b.py and a.pz == b.pz
end
CFmt.__tostring = function(a) return string.format("%g, %g, %g, ...", a.px, a.py, a.pz) end
frozen(CFmt, "CFrame")

function CFmethods.Inverse(a)
	local rt = transpose(a.r)
	local x, y, z = rotv(rt, a.px, a.py, a.pz)
	return cf(-x, -y, -z, rt)
end
function CFmethods.ToWorldSpace(a, b) return a * b end
function CFmethods.ToObjectSpace(a, b) return a:Inverse() * b end
function CFmethods.PointToWorldSpace(a, v) return a * v end
function CFmethods.PointToObjectSpace(a, v) return a:Inverse() * v end
function CFmethods.VectorToWorldSpace(a, v) local x, y, z = rotv(a.r, v.X, v.Y, v.Z) return v3(x, y, z) end
function CFmethods.VectorToObjectSpace(a, v) local x, y, z = rotv(transpose(a.r), v.X, v.Y, v.Z) return v3(x, y, z) end
function CFmethods.Lerp(a, b, t)
	local r = t < 0.5 and a.r or b.r
	return cf(a.px + (b.px - a.px) * t, a.py + (b.py - a.py) * t, a.pz + (b.pz - a.pz) * t, r)
end
function CFmethods.GetComponents(a)
	local r = a.r
	return a.px, a.py, a.pz, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]
end
CFmethods.components = CFmethods.GetComponents
function CFmethods.ToEulerAnglesYXZ(a)
	local r = a.r
	local x = math.asin(math.max(-1, math.min(1, -r[6])))
	return x, atan2(r[3], r[9]), atan2(r[4], r[5])
end
CFmethods.ToOrientation = CFmethods.ToEulerAnglesYXZ
function CFmethods.ToEulerAnglesXYZ(a)
	local r = a.r
	local y = math.asin(math.max(-1, math.min(1, r[3])))
	return atan2(-r[6], r[9]), y, atan2(-r[2], r[1])
end

local CF = {}
function CF.new(...)
	local n = select("#", ...)
	local a = { ... }
	if n == 0 then return cf(0, 0, 0) end
	if n == 1 then
		if not isV3(a[1]) then error("CFrame.new: expected Vector3, got " .. typeof(a[1]), 2) end
		return cf(a[1].X, a[1].Y, a[1].Z)
	end
	if n == 2 then return CF.lookAt(a[1], a[2]) end
	if n == 3 then
		for i = 1, 3 do if type(a[i]) ~= "number" then error("CFrame.new expects numbers, got " .. typeof(a[i]), 2) end end
		return cf(a[1], a[2], a[3])
	end
	if n == 7 then return cf(a[1], a[2], a[3], Rx(0)) end -- кватернион: не нужен для карты
	if n == 12 then return cf(a[1], a[2], a[3], { a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12] }) end
	error("CFrame.new: bad argument count " .. n, 2)
end
function CF.Angles(x, y, z)
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
		error("CFrame.Angles expects 3 numbers", 2)
	end
	return cf(0, 0, 0, matmul(matmul(Rx(x), Ry(y)), Rz(z)))
end
CF.fromEulerAnglesXYZ = CF.Angles
function CF.fromEulerAnglesYXZ(x, y, z) return cf(0, 0, 0, matmul(matmul(Ry(y), Rx(x)), Rz(z))) end
CF.fromOrientation = CF.fromEulerAnglesYXZ
function CF.fromAxisAngle(axis, ang)
	local u = axis.Unit
	local x, y, z = u.X, u.Y, u.Z
	local c, s = cos(ang), sin(ang)
	local t = 1 - c
	return cf(0, 0, 0, { t * x * x + c, t * x * y - s * z, t * x * z + s * y,
		t * x * y + s * z, t * y * y + c, t * y * z - s * x,
		t * x * z - s * y, t * y * z + s * x, t * z * z + c })
end
function CF.fromMatrix(pos, vx, vy, vz)
	if not (isV3(pos) and isV3(vx) and isV3(vy)) then error("CFrame.fromMatrix expects Vector3s", 2) end
	vz = vz or vx:Cross(vy).Unit
	return cf(pos.X, pos.Y, pos.Z, { vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z })
end
function CF.lookAt(pos, target, up)
	if not (isV3(pos) and isV3(target)) then error("CFrame.lookAt expects Vector3s", 2) end
	up = up or V3.yAxis
	local look = (target - pos).Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then right = look:Cross(V3.zAxis) end
	right = right.Unit
	local upv = right:Cross(look)
	return CF.fromMatrix(pos, right, upv, -look)
end
CF.identity = cf(0, 0, 0)

---------------------------------------------------------------------------
-- Color3, BrickColor, UDim, UDim2, последовательности, прочее
---------------------------------------------------------------------------
local C3mt = {}
local function c3(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3mt) end
C3mt.__index = function(t, k)
	if k == "r" then return t.R elseif k == "g" then return t.G elseif k == "b" then return t.B end
	if k == "Lerp" then return function(a, b, x) return c3(a.R + (b.R - a.R) * x, a.G + (b.G - a.G) * x, a.B + (b.B - a.B) * x) end end
	if k == "ToHSV" then
		return function(a)
			local mx, mn = math.max(a.R, a.G, a.B), math.min(a.R, a.G, a.B)
			local d, h = mx - mn, 0
			if d > 0 then
				if mx == a.R then h = ((a.G - a.B) / d) % 6 elseif mx == a.G then h = (a.B - a.R) / d + 2 else h = (a.R - a.G) / d + 4 end
				h = h / 6
			end
			return h, mx == 0 and 0 or d / mx, mx
		end
	end
	if k == "ToHex" then return function(a) return string.format("%02X%02X%02X", floor(a.R * 255 + 0.5), floor(a.G * 255 + 0.5), floor(a.B * 255 + 0.5)) end end
	error(tostring(k) .. " is not a valid member of Color3", 2)
end
C3mt.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
C3mt.__tostring = function(a) return string.format("%g, %g, %g", a.R, a.G, a.B) end
frozen(C3mt, "Color3")
local C3 = {}
function C3.new(r, g, b)
	r, g, b = r or 0, g or 0, b or 0
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then error("Color3.new expects numbers", 2) end
	return c3(r, g, b)
end
function C3.fromRGB(r, g, b)
	r, g, b = r or 0, g or 0, b or 0
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then error("Color3.fromRGB expects numbers", 2) end
	return c3(r / 255, g / 255, b / 255)
end
function C3.fromHex(s)
	s = s:gsub("#", "")
	if #s ~= 6 or not s:match("^%x+$") then error("Unable to convert characters to hex value", 2) end
	return c3(tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255)
end
function C3.fromHSV(h, s, v)
	local i = floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then return c3(v, t, p) elseif i == 1 then return c3(q, v, p) elseif i == 2 then return c3(p, v, t)
	elseif i == 3 then return c3(p, q, v) elseif i == 4 then return c3(t, p, v) end
	return c3(v, p, q)
end

local function record(name, fields)
	local mt = { __index = function(_, k) error(tostring(k) .. " is not a valid member of " .. name, 2) end }
	frozen(mt, name)
	return function(t) return setmetatable(t, mt) end, mt
end
local mkBrick = record("BrickColor")
local BrickColor = {
	new = function(n) return mkBrick({ Name = tostring(n), Color = c3(0.6, 0.6, 0.6) }) end,
	random = function() return mkBrick({ Name = "Random", Color = c3(0.5, 0.5, 0.5) }) end,
}
local mkUDim = record("UDim")
local UDim = { new = function(s, o) return mkUDim({ Scale = s or 0, Offset = o or 0 }) end }
local mkUDim2 = record("UDim2")
local UDim2 = {
	new = function(xs, xo, ys, yo) return mkUDim2({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }) end,
	fromScale = function(x, y) return mkUDim2({ X = UDim.new(x, 0), Y = UDim.new(y, 0) }) end,
	fromOffset = function(x, y) return mkUDim2({ X = UDim.new(0, x), Y = UDim.new(0, y) }) end,
}
local mkNR = record("NumberRange")
local NumberRange = { new = function(a, b) return mkNR({ Min = a, Max = b or a }) end }
local mkNSK = record("NumberSequenceKeypoint")
local NumberSequenceKeypoint = { new = function(t, v, e) return mkNSK({ Time = t, Value = v, Envelope = e or 0 }) end }
local mkNS = record("NumberSequence")
local NumberSequence = {
	new = function(a, b)
		if type(a) == "number" then
			return mkNS({ Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) } })
		end
		if type(a) ~= "table" or #a < 2 then error("NumberSequence.new: need at least 2 keypoints", 2) end
		if a[1].Time ~= 0 or a[#a].Time ~= 1 then error("NumberSequence: keypoints must start at time 0 and end at time 1", 2) end
		return mkNS({ Keypoints = a })
	end,
}
local mkCSK = record("ColorSequenceKeypoint")
local ColorSequenceKeypoint = { new = function(t, c) return mkCSK({ Time = t, Value = c }) end }
local mkCS = record("ColorSequence")
local ColorSequence = {
	new = function(a, b)
		if typeof(a) == "Color3" then
			return mkCS({ Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) } })
		end
		if type(a) ~= "table" or #a < 2 then error("ColorSequence.new: need at least 2 keypoints", 2) end
		if a[1].Time ~= 0 or a[#a].Time ~= 1 then error("ColorSequence: keypoints must start at time 0 and end at time 1", 2) end
		return mkCS({ Keypoints = a })
	end,
}
local mkTI = record("TweenInfo")
local TweenInfo = {
	new = function(t, style, dir, rep, rev, delay)
		return mkTI({ Time = t or 1, EasingStyle = style, EasingDirection = dir, RepeatCount = rep or 0, Reverses = rev or false, DelayTime = delay or 0 })
	end,
}
local mkPP = record("PhysicalProperties")
local PhysicalProperties = { new = function(d, f, e) return mkPP({ Density = d, Friction = f, Elasticity = e }) end }

-- Random (в игре мы пользуемся своим генератором, этот — только для совместимости)
local RandomMT = {}
RandomMT.__index = {
	NextNumber = function(self, a, b)
		self.s = (self.s * 16807) % 2147483647
		local x = self.s / 2147483647
		if a then return a + (b - a) * x end
		return x
	end,
	NextInteger = function(self, a, b) return a + floor(self:NextNumber() * (b - a + 1)) end,
}
TYPE[RandomMT] = "Random"
local RandomLib = { new = function(seed) return setmetatable({ s = (floor(seed or 1) % 2147483646) + 1 }, RandomMT) end }

---------------------------------------------------------------------------
-- Enum
---------------------------------------------------------------------------
local ENUMS = {
	Material = "Plastic SmoothPlastic Neon Wood WoodPlanks Marble Slate Concrete Granite Brick Pebble Cobblestone Rock Sandstone Basalt CrackedLava Asphalt LeafyGrass Salt Limestone Pavement CorrodedMetal DiamondPlate Foil Metal Grass Ice Glacier Snow Sand Fabric Glass ForceField Mud Ground Water Air Cardboard Carpet CeramicTiles ClayRoofTiles RoofShingles Leather Plaster Rubber",
	PartType = "Ball Block Cylinder Wedge CornerWedge",
	NormalId = "Top Bottom Front Back Left Right",
	SurfaceType = "Smooth Glue Weld Studs Inlet Universal Hinge Motor SteppingMotor SmoothNoOutlines",
	MeshType = "Head Torso Wedge Prism Pyramid ParallelRamp RightAngleRamp CornerWedge Brick Sphere Cylinder FileMesh",
	Font = "Legacy Arial ArialBold SourceSans SourceSansBold SourceSansLight SourceSansItalic SourceSansSemibold Bodoni Garamond Cartoon Code Highway SciFi Arcade Fantasy Antique Gotham GothamMedium GothamBold GothamBlack AmaticSC Bangers Creepster DenkOne Fondamento FredokaOne GrenzeGotisch IndieFlower JosefinSans Jura Kalam LuckiestGuy Merriweather Michroma Nunito Oswald PatrickHand PermanentMarker Roboto RobotoCondensed RobotoMono Sarpanch SpecialElite TitilliumWeb Ubuntu BuilderSans BuilderSansMedium BuilderSansBold BuilderSansExtraBold Arimo ArimoBold",
	SurfaceGuiSizingMode = "FixedSize PixelsPerStud",
	TextXAlignment = "Left Center Right",
	TextYAlignment = "Top Center Bottom",
	ZIndexBehavior = "Global Sibling",
	EasingStyle = "Linear Sine Back Quad Quart Quint Bounce Elastic Exponential Circular Cubic",
	EasingDirection = "In Out InOut",
	ParticleEmitterShape = "Box Sphere Cylinder Disc",
	ParticleEmitterShapeInOut = "Outward Inward InAndOut",
	ParticleEmitterShapeStyle = "Volume Surface",
	ParticleOrientation = "FacingCamera FacingCameraWorldUp VelocityParallel VelocityPerpendicular",
	KeyCode = "E F R Q Space LeftShift One Two Three",
	ApplyStrokeMode = "Contextual Border",
	TextureMode = "Stretch Wrap Static",
	RollOffMode = "Inverse Linear InverseTapered LinearSquare",
	Technology = "Legacy Voxel Compatibility ShadowMap Future Unified",
	HumanoidStateType = "Running Jumping Freefall Dead",
	UserInputType = "MouseButton1 Touch Keyboard",
	ScaleType = "Stretch Slice Tile Fit Crop",
	AutomaticSize = "None X Y XY",
	ProximityPromptStyle = "Default Custom",
	PlaybackState = "Begin Delayed Playing Paused Completed Cancelled",
	SizeConstraint = "RelativeXY RelativeXX RelativeYY",
	HighlightDepthMode = "AlwaysOnTop Occluded",
	TrussStyle = "AlternatingSupports BridgeStyleSupports NoSupports",
	ModelStreamingMode = "Default Atomic Persistent PersistentPerPlayer Nonatomic",
	FillDirection = "Horizontal Vertical",
	HorizontalAlignment = "Left Center Right",
	VerticalAlignment = "Top Center Bottom",
	SortOrder = "LayoutOrder Name Custom",
	ScreenInsets = "None DeviceSafeInsets CoreUISafeInsets TopbarSafeInsets",
}
local EnumItemMT = { __index = function(_, k) error(tostring(k) .. " is not a valid member of EnumItem", 2) end,
	__tostring = function(e) return "Enum." .. e.EnumType .. "." .. e.Name end }
frozen(EnumItemMT, "EnumItem")
local Enum = {}
for tname, list in pairs(ENUMS) do
	local items, i = {}, 0
	for n in list:gmatch("%S+") do
		items[n] = setmetatable({ Name = n, Value = i, EnumType = tname }, EnumItemMT)
		i = i + 1
	end
	local et = setmetatable({}, {
		__index = function(_, k)
			if k == "GetEnumItems" then
				return function() local o = {} for _, v in pairs(items) do o[#o + 1] = v end return o end
			end
			local it = items[k]
			if not it then error(tostring(k) .. " is not a valid member of Enum." .. tname, 2) end
			return it
		end,
	})
	Enum[tname] = et
end
setmetatable(Enum, { __index = function(_, k) error(tostring(k) .. " is not a valid member of Enum (mock: add it to ENUMS if real)", 2) end })

-- материалы, которые принимает Terrain
local TERRAIN_MATS = {}
for n in ("Grass LeafyGrass Sand Rock Slate Basalt CrackedLava Mud Ground Asphalt Concrete Brick Cobblestone Glacier Ice Snow Salt Sandstone Limestone Pavement WoodPlanks Water Air"):gmatch("%S+") do
	TERRAIN_MATS[n] = true
end

---------------------------------------------------------------------------
-- Сигналы
---------------------------------------------------------------------------
local SignalMT = { __index = {} }
SignalMT.__index.Connect = function(self, fn)
	if type(fn) ~= "function" then error("Connect expects a function", 2) end
	local c = { fn = fn, Connected = true }
	c.Disconnect = function() c.Connected = false end
	table.insert(self.list, c)
	return c
end
SignalMT.__index.Once = SignalMT.__index.Connect
SignalMT.__index.Wait = function() return nil end
SignalMT.__index.Fire = function(self, ...)
	for _, c in ipairs(self.list) do if c.Connected then c.fn(...) end end
end
TYPE[SignalMT] = "RBXScriptSignal"
local function signal() return setmetatable({ list = {} }, SignalMT) end

---------------------------------------------------------------------------
-- Instance
---------------------------------------------------------------------------
local DATA = setmetatable({}, { __mode = "k" })
local classes = {}
local InstMT = {}
TYPE[InstMT] = "Instance"
local function isInst(v) return getmetatable(v) == InstMT end
M.isInst = isInst
M.DATA = DATA

local function def(name, super, props, methods, opts)
	classes[name] = { name = name, super = super and classes[super], props = props or {}, methods = methods or {}, opts = opts or {} }
end
local function findProp(cls, k)
	while cls do
		local p = cls.props[k]
		if p then return p end
		cls = cls.super
	end
end
local function findMethod(cls, k)
	while cls do
		local f = cls.methods[k]
		if f then return f end
		cls = cls.super
	end
end
local function isA(cls, name)
	while cls do
		if cls.name == name then return true end
		cls = cls.super
	end
	return false
end

local function checkType(t, v)
	if t == "any" then return true end
	if t == "num" then return type(v) == "number" and v == v end
	if t == "bool" then return type(v) == "boolean" end
	if t == "str" then return type(v) == "string" end
	if t == "inst" then return v == nil or isInst(v) end
	if t:sub(1, 5) == "enum:" then
		if type(v) == "string" then return pcall(function() return Enum[t:sub(6)][v] end) end
		return typeof(v) == "EnumItem" and v.EnumType == t:sub(6)
	end
	return typeof(v) == t
end

-- служебные: свойства, которые вычисляются
local function partSetCF(d, c) d.props.CFrame = c end

InstMT.__index = function(self, k)
	local d = DATA[self]
	if k == "ClassName" then return d.cls.name end
	if k == "Parent" then return d.parent end
	local cls = d.cls
	-- особые вычисляемые свойства
	if isA(cls, "BasePart") and cls.name ~= "Terrain" then
		if k == "Position" then return d.props.CFrame.Position end
		if k == "Orientation" then
			local x, y, z = d.props.CFrame:ToOrientation()
			return v3(math.deg(x), math.deg(y), math.deg(z))
		end
	end
	if cls.name == "Attachment" and k == "WorldPosition" then
		local par = d.parent
		if par and DATA[par].props.CFrame then return DATA[par].props.CFrame * d.props.CFrame.Position end
		return d.props.CFrame.Position
	end
	local p = findProp(cls, k)
	if p then
		local v = d.props[k]
		if v == nil and p.get then return p.get(self, d) end
		return v
	end
	local f = findMethod(cls, k)
	if f then return f end
	for _, c in ipairs(d.children) do
		if DATA[c].props.Name == k then return c end
	end
	error(tostring(k) .. " is not a valid member of " .. cls.name .. " \"" .. tostring(d.props.Name) .. "\"", 2)
end

local function setParent(self, d, p)
	if p ~= nil and not isInst(p) then error("Parent must be an Instance, got " .. typeof(p), 3) end
	if d.locked then error("The Parent property of " .. d.props.Name .. " is locked", 3) end
	local q = p
	while q do
		if q == self then error("Attempt to set parent of " .. d.props.Name .. " to itself or descendant", 3) end
		q = DATA[q].parent
	end
	local old = d.parent
	if old then
		local list = DATA[old].children
		for i = #list, 1, -1 do if list[i] == self then table.remove(list, i) break end end
	end
	d.parent = p
	if p then
		table.insert(DATA[p].children, self)
		DATA[p].signals.ChildAdded:Fire(self)
	end
end

InstMT.__newindex = function(self, k, v)
	local d = DATA[self]
	if k == "Parent" then return setParent(self, d, v) end
	local cls = d.cls
	if isA(cls, "BasePart") and cls.name ~= "Terrain" then
		if k == "Position" then
			if not isV3(v) then error("Position: expected Vector3, got " .. typeof(v), 2) end
			d.props.CFrame = cf(v.X, v.Y, v.Z, d.props.CFrame.r)
			return
		end
		if k == "Orientation" then
			if not isV3(v) then error("Orientation: expected Vector3, got " .. typeof(v), 2) end
			local p = d.props.CFrame.Position
			d.props.CFrame = CF.new(p) * CF.fromOrientation(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
			return
		end
	end
	local p = findProp(cls, k)
	if not p then error(tostring(k) .. " is not a valid member of " .. cls.name .. " \"" .. tostring(d.props.Name) .. "\"", 2) end
	if p.readonly then error(k .. " is read-only (" .. cls.name .. ")", 2) end
	if not checkType(p.t, v) then
		error(string.format("Unable to assign property %s. %s expected, got %s (%s)", k, p.t, typeof(v), cls.name), 2)
	end
	if type(v) == "string" and p.t:sub(1, 5) == "enum:" then v = Enum[p.t:sub(6)][v] end
	if k == "Size" and isA(cls, "BasePart") then
		v = v3(math.max(0.001, v.X), math.max(0.001, v.Y), math.max(0.001, v.Z))
	end
	d.props[k] = v
	local sig = d.propSignals[k]
	if sig then sig:Fire() end
end
InstMT.__tostring = function(self) return DATA[self].props.Name end

local function newInstance(clsName, noCheck)
	local cls = classes[clsName]
	if not cls then error("Unable to create an Instance of type \"" .. tostring(clsName) .. "\"", 3) end
	if cls.opts.noCreate and not noCheck then error("Unable to create an Instance of type \"" .. clsName .. "\"", 3) end
	local d = { cls = cls, props = {}, children = {}, attrs = {}, tags = {}, propSignals = {},
		signals = { ChildAdded = signal(), Destroying = signal(), AncestryChanged = signal() } }
	local c = cls
	local chain = {}
	while c do table.insert(chain, 1, c) c = c.super end
	for _, cc in ipairs(chain) do
		for k, p in pairs(cc.props) do
			if p.default ~= nil then d.props[k] = p.default end
		end
	end
	d.props.Name = clsName
	local o = setmetatable({}, InstMT)
	DATA[o] = d
	M.created = (M.created or 0) + 1
	return o
end
M.newInstance = newInstance

local function P(t, default, extra)
	local p = { t = t, default = default }
	if extra then for k, v in pairs(extra) do p[k] = v end end
	return p
end
local RO = { readonly = true }

local function descendants(self, out)
	for _, c in ipairs(DATA[self].children) do
		out[#out + 1] = c
		descendants(c, out)
	end
	return out
end

local ATTR_TYPES = { string = true, number = true, boolean = true, Vector3 = true, Vector2 = true, Color3 = true,
	CFrame = true, UDim = true, UDim2 = true, NumberRange = true, NumberSequence = true, ColorSequence = true, BrickColor = true, ["nil"] = true }

local CollectionTags = {}

def("Instance", nil, {
	Name = P("str", "Instance"),
	Archivable = P("bool", true),
}, {
	IsA = function(self, n) return isA(DATA[self].cls, n) end,
	GetChildren = function(self) local o = {} for i, c in ipairs(DATA[self].children) do o[i] = c end return o end,
	GetDescendants = function(self) return descendants(self, {}) end,
	FindFirstChild = function(self, n, rec)
		for _, c in ipairs(DATA[self].children) do if DATA[c].props.Name == n then return c end end
		if rec then
			for _, c in ipairs(descendants(self, {})) do if DATA[c].props.Name == n then return c end end
		end
		return nil
	end,
	FindFirstChildOfClass = function(self, n)
		for _, c in ipairs(DATA[self].children) do if DATA[c].cls.name == n then return c end end
	end,
	FindFirstChildWhichIsA = function(self, n)
		for _, c in ipairs(DATA[self].children) do if isA(DATA[c].cls, n) then return c end end
	end,
	FindFirstAncestor = function(self, n)
		local p = DATA[self].parent
		while p do if DATA[p].props.Name == n then return p end p = DATA[p].parent end
	end,
	FindFirstAncestorWhichIsA = function(self, n)
		local p = DATA[self].parent
		while p do if isA(DATA[p].cls, n) then return p end p = DATA[p].parent end
	end,
	IsDescendantOf = function(self, a)
		local p = DATA[self].parent
		while p do if p == a then return true end p = DATA[p].parent end
		return false
	end,
	WaitForChild = function(self, n, timeout)
		for _, c in ipairs(DATA[self].children) do if DATA[c].props.Name == n then return c end end
		if timeout then return nil end
		table.insert(M.warns, "Infinite yield possible on WaitForChild(\"" .. n .. "\") of " .. DATA[self].props.Name)
		return nil
	end,
	GetFullName = function(self)
		local parts, o = {}, self
		while o and DATA[o].cls.name ~= "DataModel" do table.insert(parts, 1, DATA[o].props.Name) o = DATA[o].parent end
		return table.concat(parts, ".")
	end,
	Destroy = function(self)
		local d = DATA[self]
		for _, c in ipairs(descendants(self, {})) do DATA[c].destroyed = true end
		d.signals.Destroying:Fire()
		setParent(self, d, nil)
		d.destroyed = true
		d.locked = true
	end,
	ClearAllChildren = function(self)
		for _, c in ipairs(self:GetChildren()) do c:Destroy() end
	end,
	Clone = function(self)
		local d = DATA[self]
		local o = newInstance(d.cls.name, true)
		local od = DATA[o]
		for k, v in pairs(d.props) do od.props[k] = v end
		for k, v in pairs(d.attrs) do od.attrs[k] = v end
		for k, v in pairs(d.tags) do od.tags[k] = v end
		for _, c in ipairs(d.children) do c:Clone().Parent = o end
		return o
	end,
	SetAttribute = function(self, k, v)
		if type(k) ~= "string" then error("SetAttribute: name must be a string", 2) end
		if not ATTR_TYPES[typeof(v)] then error("SetAttribute: type " .. typeof(v) .. " is not supported (" .. k .. ")", 2) end
		DATA[self].attrs[k] = v
	end,
	GetAttribute = function(self, k) return DATA[self].attrs[k] end,
	GetAttributes = function(self) local o = {} for k, v in pairs(DATA[self].attrs) do o[k] = v end return o end,
	GetAttributeChangedSignal = function() return signal() end,
	AddTag = function(self, t)
		DATA[self].tags[t] = true
		CollectionTags[t] = CollectionTags[t] or {}
		CollectionTags[t][self] = true
	end,
	HasTag = function(self, t) return DATA[self].tags[t] == true end,
	RemoveTag = function(self, t) DATA[self].tags[t] = nil if CollectionTags[t] then CollectionTags[t][self] = nil end end,
	GetTags = function(self) local o = {} for t in pairs(DATA[self].tags) do o[#o + 1] = t end return o end,
	GetPropertyChangedSignal = function(self, k)
		local d = DATA[self]
		if not findProp(d.cls, k) and k ~= "Parent" then error(k .. " is not a valid property name", 2) end
		d.propSignals[k] = d.propSignals[k] or signal()
		return d.propSignals[k]
	end,
}, { noCreate = true })

-- события, доступные через свойства-«сигналы»
local function sig(name) return P("any", nil, { get = function(_, d) d.signals[name] = d.signals[name] or signal() return d.signals[name] end, readonly = true }) end
classes.Instance.props.ChildAdded = sig("ChildAdded")
classes.Instance.props.ChildRemoved = sig("ChildRemoved")
classes.Instance.props.DescendantAdded = sig("DescendantAdded")
classes.Instance.props.Destroying = sig("Destroying")
classes.Instance.props.AncestryChanged = sig("AncestryChanged")
classes.Instance.props.Changed = sig("Changed")

local function bboxOf(list)
	local mn, mx
	for _, p in ipairs(list) do
		local d = DATA[p]
		local c, s = d.props.CFrame, d.props.Size
		for _, sx in ipairs({ -0.5, 0.5 }) do
			for _, sy in ipairs({ -0.5, 0.5 }) do
				for _, sz in ipairs({ -0.5, 0.5 }) do
					local w = c * v3(s.X * sx, s.Y * sy, s.Z * sz)
					mn = mn and mn:Min(w) or w
					mx = mx and mx:Max(w) or w
				end
			end
		end
	end
	return mn, mx
end
local function partsIn(self)
	local o = {}
	for _, c in ipairs(descendants(self, {})) do
		if isA(DATA[c].cls, "BasePart") and DATA[c].cls.name ~= "Terrain" then o[#o + 1] = c end
	end
	return o
end

def("PVInstance", "Instance", {}, {}, { noCreate = true })
local SURF = "enum:SurfaceType"
def("BasePart", "PVInstance", {
	Size = P("Vector3", v3(4, 1, 2)), CFrame = P("CFrame", cf(0, 0, 0)), Color = P("Color3", c3(0.64, 0.64, 0.64)),
	BrickColor = P("BrickColor", nil), Material = P("enum:Material", Enum.Material.Plastic), MaterialVariant = P("str", ""),
	Transparency = P("num", 0), Reflectance = P("num", 0), LocalTransparencyModifier = P("num", 0),
	Anchored = P("bool", false), CanCollide = P("bool", true), CanQuery = P("bool", true), CanTouch = P("bool", true),
	CastShadow = P("bool", true), Locked = P("bool", false), Massless = P("bool", false), CollisionGroup = P("str", "Default"),
	TopSurface = P(SURF, Enum.SurfaceType.Smooth), BottomSurface = P(SURF, Enum.SurfaceType.Smooth),
	LeftSurface = P(SURF, Enum.SurfaceType.Smooth), RightSurface = P(SURF, Enum.SurfaceType.Smooth),
	FrontSurface = P(SURF, Enum.SurfaceType.Smooth), BackSurface = P(SURF, Enum.SurfaceType.Smooth),
	CustomPhysicalProperties = P("any", nil), AssemblyLinearVelocity = P("Vector3", v3()), AssemblyAngularVelocity = P("Vector3", v3()),
	EnableFluidForces = P("bool", true), AudioCanCollide = P("bool", true),
	Touched = sig("Touched"), TouchEnded = sig("TouchEnded"),
}, {
	GetPivot = function(self) return DATA[self].props.CFrame end,
	PivotTo = function(self, c)
		if not isCF(c) then error("PivotTo expects CFrame", 2) end
		DATA[self].props.CFrame = c
	end,
	GetTouchingParts = function() return {} end,
	GetMass = function(self) local s = DATA[self].props.Size return s.X * s.Y * s.Z * 0.7 end,
}, { noCreate = true })
def("Part", "BasePart", { Shape = P("enum:PartType", Enum.PartType.Block) })
def("WedgePart", "BasePart", {})
def("CornerWedgePart", "BasePart", {})
def("TrussPart", "BasePart", { Style = P("enum:TrussStyle", Enum.TrussStyle.AlternatingSupports) })
def("SpawnLocation", "Part", { Duration = P("num", 10), Neutral = P("bool", true), Enabled = P("bool", true),
	AllowTeamChangeOnTouch = P("bool", false), TeamColor = P("BrickColor", nil) })
def("MeshPart", "BasePart", { MeshId = P("str", ""), TextureID = P("str", "") })
def("Terrain", "BasePart", {
	WaterColor = P("Color3", c3(0.05, 0.33, 0.36)), WaterTransparency = P("num", 0.3), WaterWaveSize = P("num", 0.15),
	WaterWaveSpeed = P("num", 10), WaterReflectance = P("num", 1), Decoration = P("bool", false),
}, {
	FillBlock = function(self, c, size, mat)
		if not isCF(c) then error("FillBlock: argument 1 must be CFrame, got " .. typeof(c), 2) end
		if not isV3(size) then error("FillBlock: argument 2 must be Vector3, got " .. typeof(size), 2) end
		if typeof(mat) ~= "EnumItem" or mat.EnumType ~= "Material" or not TERRAIN_MATS[mat.Name] then
			error("FillBlock: bad terrain material " .. tostring(mat), 2)
		end
		if size.X * size.Y * size.Z / 64 > 4194304 then table.insert(M.warns, "FillBlock: very large region " .. tostring(size)) end
		table.insert(M.terrainOps, { op = "block", cf = c, size = size, mat = mat.Name })
	end,
	FillBall = function(self, center, r, mat)
		if not isV3(center) then error("FillBall: argument 1 must be Vector3, got " .. typeof(center), 2) end
		if type(r) ~= "number" or r <= 0 then error("FillBall: radius must be a positive number", 2) end
		if typeof(mat) ~= "EnumItem" or not TERRAIN_MATS[mat.Name] then error("FillBall: bad terrain material " .. tostring(mat), 2) end
		table.insert(M.terrainOps, { op = "ball", center = center, r = r, mat = mat.Name })
	end,
	FillCylinder = function(self, c, h, r, mat)
		if not isCF(c) then error("FillCylinder: argument 1 must be CFrame, got " .. typeof(c), 2) end
		if type(h) ~= "number" or type(r) ~= "number" then error("FillCylinder: height/radius must be numbers", 2) end
		if typeof(mat) ~= "EnumItem" or not TERRAIN_MATS[mat.Name] then error("FillCylinder: bad terrain material " .. tostring(mat), 2) end
		table.insert(M.terrainOps, { op = "cyl", cf = c, h = h, r = r, mat = mat.Name })
	end,
	FillWedge = function(self, c, size, mat)
		if not isCF(c) or not isV3(size) then error("FillWedge: expects CFrame, Vector3", 2) end
		if typeof(mat) ~= "EnumItem" or not TERRAIN_MATS[mat.Name] then error("FillWedge: bad terrain material " .. tostring(mat), 2) end
		table.insert(M.terrainOps, { op = "wedge", cf = c, size = size, mat = mat.Name })
	end,
	Clear = function() M.terrainOps = {} end,
	SetMaterialColor = function(self, mat, col)
		if typeof(mat) ~= "EnumItem" or not TERRAIN_MATS[mat.Name] then error("SetMaterialColor: bad material", 2) end
		if typeof(col) ~= "Color3" then error("SetMaterialColor: expected Color3", 2) end
		M.terrainColors = M.terrainColors or {}
		M.terrainColors[mat.Name] = col
	end,
}, { noCreate = true })

def("Model", "PVInstance", {
	PrimaryPart = P("inst", nil), WorldPivot = P("CFrame", nil),
	LevelOfDetail = P("any", nil), ModelStreamingMode = P("enum:ModelStreamingMode", Enum.ModelStreamingMode.Default),
}, {
	GetPivot = function(self)
		local d = DATA[self]
		if d.props.PrimaryPart then return DATA[d.props.PrimaryPart].props.CFrame end
		if d.props.WorldPivot then return d.props.WorldPivot end
		local mn, mx = bboxOf(partsIn(self))
		if not mn then return cf(0, 0, 0) end
		local c = (mn + mx) / 2
		return cf(c.X, c.Y, c.Z)
	end,
	PivotTo = function(self, c)
		if not isCF(c) then error("PivotTo expects CFrame", 2) end
		local delta = c * self:GetPivot():Inverse()
		for _, p in ipairs(partsIn(self)) do DATA[p].props.CFrame = delta * DATA[p].props.CFrame end
		if DATA[self].props.WorldPivot then DATA[self].props.WorldPivot = c end
	end,
	GetBoundingBox = function(self)
		local mn, mx = bboxOf(partsIn(self))
		if not mn then return cf(0, 0, 0), v3() end
		local c = (mn + mx) / 2
		return cf(c.X, c.Y, c.Z), mx - mn
	end,
	GetExtentsSize = function(self)
		local mn, mx = bboxOf(partsIn(self))
		if not mn then return v3() end
		return mx - mn
	end,
	MoveTo = function(self, pos)
		local p = self:GetPivot()
		self:PivotTo(p + (pos - p.Position))
	end,
	ScaleTo = function() end,
	GetScale = function() return 1 end,
})
def("Folder", "Instance", {})
def("Configuration", "Instance", {})
def("Actor", "Model", {})

-- скрипты
def("LuaSourceContainer", "Instance", { Source = P("str", "") }, {}, { noCreate = true })
def("ModuleScript", "LuaSourceContainer", {})
def("Script", "LuaSourceContainer", { Disabled = P("bool", false), Enabled = P("bool", true) })
def("LocalScript", "Script", {})

-- свет
def("Light", "Instance", { Brightness = P("num", 1), Color = P("Color3", c3(1, 1, 1)), Enabled = P("bool", true), Shadows = P("bool", false) }, {}, { noCreate = true })
def("PointLight", "Light", { Range = P("num", 8) })
def("SpotLight", "Light", { Range = P("num", 16), Angle = P("num", 90), Face = P("enum:NormalId", Enum.NormalId.Front) })
def("SurfaceLight", "Light", { Range = P("num", 16), Angle = P("num", 90), Face = P("enum:NormalId", Enum.NormalId.Front) })

-- эффекты частиц
def("ParticleEmitter", "Instance", {
	Color = P("ColorSequence", nil), Size = P("NumberSequence", nil), Transparency = P("NumberSequence", nil),
	Lifetime = P("NumberRange", nil), Rate = P("num", 20), Speed = P("NumberRange", nil), SpreadAngle = P("Vector2", v2()),
	Texture = P("str", ""), LightEmission = P("num", 0), LightInfluence = P("num", 1), Rotation = P("NumberRange", nil),
	RotSpeed = P("NumberRange", nil), Acceleration = P("Vector3", v3()), Drag = P("num", 0),
	EmissionDirection = P("enum:NormalId", Enum.NormalId.Top), Enabled = P("bool", true), ZOffset = P("num", 0),
	Shape = P("enum:ParticleEmitterShape", Enum.ParticleEmitterShape.Box),
	ShapeInOut = P("enum:ParticleEmitterShapeInOut", Enum.ParticleEmitterShapeInOut.Outward),
	ShapeStyle = P("enum:ParticleEmitterShapeStyle", Enum.ParticleEmitterShapeStyle.Volume), ShapePartial = P("num", 1),
	Squash = P("NumberSequence", nil), Orientation = P("enum:ParticleOrientation", Enum.ParticleOrientation.FacingCamera),
	LockedToPart = P("bool", false), VelocityInheritance = P("num", 0), Brightness = P("num", 1), TimeScale = P("num", 1),
}, { Emit = function() end, Clear = function() end })
def("Fire", "Instance", { Color = P("Color3", c3(1, 0.5, 0)), SecondaryColor = P("Color3", c3(1, 0, 0)), Heat = P("num", 9),
	Size = P("num", 5), Enabled = P("bool", true), TimeScale = P("num", 1) })
def("Smoke", "Instance", { Color = P("Color3", c3(1, 1, 1)), Opacity = P("num", 0.5), RiseVelocity = P("num", 1),
	Size = P("num", 1), Enabled = P("bool", true), TimeScale = P("num", 1) })
def("Sparkles", "Instance", { SparkleColor = P("Color3", c3(0.56, 0.34, 1)), Enabled = P("bool", true), TimeScale = P("num", 1) })

def("DataModelMesh", "Instance", { Scale = P("Vector3", v3(1, 1, 1)), Offset = P("Vector3", v3()), VertexColor = P("Vector3", v3(1, 1, 1)) }, {}, { noCreate = true })
def("SpecialMesh", "DataModelMesh", { MeshType = P("enum:MeshType", Enum.MeshType.Head), MeshId = P("str", ""), TextureId = P("str", "") })
def("Attachment", "Instance", { CFrame = P("CFrame", cf(0, 0, 0)), Visible = P("bool", false),
	Position = P("Vector3", nil, { get = function(_, d) return d.props.CFrame.Position end }),
	WorldPosition = P("Vector3", nil, { readonly = true }) })
def("Beam", "Instance", {
	Attachment0 = P("inst", nil), Attachment1 = P("inst", nil), Color = P("ColorSequence", nil), Transparency = P("NumberSequence", nil),
	Width0 = P("num", 1), Width1 = P("num", 1), CurveSize0 = P("num", 0), CurveSize1 = P("num", 0), FaceCamera = P("bool", false),
	LightEmission = P("num", 0), LightInfluence = P("num", 0), Texture = P("str", ""), TextureSpeed = P("num", 1),
	TextureLength = P("num", 1), TextureMode = P("enum:TextureMode", Enum.TextureMode.Stretch), Segments = P("num", 10),
	Enabled = P("bool", true), Brightness = P("num", 1), ZOffset = P("num", 0),
})
def("Sound", "Instance", { SoundId = P("str", ""), Volume = P("num", 0.5), Looped = P("bool", false), Playing = P("bool", false),
	PlaybackSpeed = P("num", 1), RollOffMaxDistance = P("num", 10000), RollOffMinDistance = P("num", 10),
	RollOffMode = P("enum:RollOffMode", Enum.RollOffMode.Inverse), TimePosition = P("num", 0), IsPlaying = P("bool", false, RO) },
	{ Play = function() end, Stop = function() end, Pause = function() end, Resume = function() end })
def("ProximityPrompt", "Instance", { ActionText = P("str", "Interact"), ObjectText = P("str", ""), MaxActivationDistance = P("num", 10),
	RequiresLineOfSight = P("bool", true), KeyboardKeyCode = P("enum:KeyCode", Enum.KeyCode.E), HoldDuration = P("num", 0),
	Enabled = P("bool", true), Style = P("enum:ProximityPromptStyle", Enum.ProximityPromptStyle.Default), UIOffset = P("Vector2", v2()),
	ClickablePrompt = P("bool", true), Triggered = sig("Triggered") })
def("WeldConstraint", "Instance", { Part0 = P("inst", nil), Part1 = P("inst", nil), Enabled = P("bool", true) })
def("Highlight", "Instance", { FillColor = P("Color3", c3(1, 0, 0)), OutlineColor = P("Color3", c3(1, 1, 1)), FillTransparency = P("num", 0.5),
	OutlineTransparency = P("num", 0), DepthMode = P("enum:HighlightDepthMode", Enum.HighlightDepthMode.AlwaysOnTop), Adornee = P("inst", nil), Enabled = P("bool", true) })
def("FaceInstance", "Instance", { Face = P("enum:NormalId", Enum.NormalId.Front) }, {}, { noCreate = true })
def("Decal", "FaceInstance", { Texture = P("str", ""), Transparency = P("num", 0), Color3 = P("Color3", c3(1, 1, 1)), ZIndex = P("num", 1) })
def("Texture", "Decal", { StudsPerTileU = P("num", 2), StudsPerTileV = P("num", 2), OffsetStudsU = P("num", 0), OffsetStudsV = P("num", 0) })
for _, n in ipairs({ "StringValue", "NumberValue", "IntValue", "BoolValue", "ObjectValue", "Vector3Value", "CFrameValue", "Color3Value" }) do
	def(n, "Instance", { Value = P("any", nil) })
end

-- освещение и атмосфера
def("Atmosphere", "Instance", { Density = P("num", 0.395), Offset = P("num", 0), Color = P("Color3", c3(0.78, 0.78, 0.78)),
	Decay = P("Color3", c3(0.42, 0.44, 0.49)), Glare = P("num", 0), Haze = P("num", 0) })
def("Sky", "Instance", { SkyboxBk = P("str", ""), SkyboxDn = P("str", ""), SkyboxFt = P("str", ""), SkyboxLf = P("str", ""),
	SkyboxRt = P("str", ""), SkyboxUp = P("str", ""), SunAngularSize = P("num", 21), MoonAngularSize = P("num", 11),
	StarCount = P("num", 3000), CelestialBodiesShown = P("bool", true), SunTextureId = P("str", ""), MoonTextureId = P("str", ""),
	SkyboxOrientation = P("Vector3", v3()) })
def("Clouds", "Instance", { Cover = P("num", 0.5), Density = P("num", 0.7), Color = P("Color3", c3(1, 1, 1)), Enabled = P("bool", true) })
def("PostEffect", "Instance", { Enabled = P("bool", true) }, {}, { noCreate = true })
def("BloomEffect", "PostEffect", { Intensity = P("num", 1), Size = P("num", 24), Threshold = P("num", 2) })
def("ColorCorrectionEffect", "PostEffect", { Brightness = P("num", 0), Contrast = P("num", 0), Saturation = P("num", 0), TintColor = P("Color3", c3(1, 1, 1)) })
def("SunRaysEffect", "PostEffect", { Intensity = P("num", 0.25), Spread = P("num", 1) })
def("BlurEffect", "PostEffect", { Size = P("num", 24) })
def("DepthOfFieldEffect", "PostEffect", { FarIntensity = P("num", 0.75), FocusDistance = P("num", 0.05), InFocusRadius = P("num", 10), NearIntensity = P("num", 0.75) })

-- интерфейс
def("GuiBase2d", "Instance", { AbsoluteSize = P("Vector2", v2(800, 600), RO), AbsolutePosition = P("Vector2", v2(), RO) }, {}, { noCreate = true })
def("LayerCollector", "GuiBase2d", { Enabled = P("bool", true), ResetOnSpawn = P("bool", true),
	ZIndexBehavior = P("enum:ZIndexBehavior", Enum.ZIndexBehavior.Sibling) }, {}, { noCreate = true })
def("ScreenGui", "LayerCollector", { IgnoreGuiInset = P("bool", false), DisplayOrder = P("num", 0),
	ScreenInsets = P("enum:ScreenInsets", Enum.ScreenInsets.CoreUISafeInsets) })
def("SurfaceGui", "LayerCollector", { Face = P("enum:NormalId", Enum.NormalId.Front), SizingMode = P("enum:SurfaceGuiSizingMode", Enum.SurfaceGuiSizingMode.FixedSize),
	PixelsPerStud = P("num", 50), CanvasSize = P("Vector2", v2(800, 600)), LightInfluence = P("num", 1), Brightness = P("num", 1),
	AlwaysOnTop = P("bool", false), Adornee = P("inst", nil), ClipsDescendants = P("bool", true), MaxDistance = P("num", 1000) })
def("BillboardGui", "LayerCollector", { Size = P("UDim2", UDim2.new(0, 0, 0, 0)), StudsOffset = P("Vector3", v3()),
	StudsOffsetWorldSpace = P("Vector3", v3()), ExtentsOffset = P("Vector3", v3()), ExtentsOffsetWorldSpace = P("Vector3", v3()),
	SizeOffset = P("Vector2", v2()), AlwaysOnTop = P("bool", false), MaxDistance = P("num", 1e9), LightInfluence = P("num", 0),
	Brightness = P("num", 1), Adornee = P("inst", nil), ClipsDescendants = P("bool", false), DistanceLowerLimit = P("num", 0),
	DistanceUpperLimit = P("num", -1) })
def("GuiObject", "GuiBase2d", { Size = P("UDim2", UDim2.new(0, 100, 0, 100)), Position = P("UDim2", UDim2.new(0, 0, 0, 0)),
	AnchorPoint = P("Vector2", v2()), BackgroundColor3 = P("Color3", c3(1, 1, 1)), BackgroundTransparency = P("num", 0),
	BorderSizePixel = P("num", 1), BorderColor3 = P("Color3", c3(0.1, 0.1, 0.1)), Visible = P("bool", true), ZIndex = P("num", 1),
	Rotation = P("num", 0), LayoutOrder = P("num", 0), ClipsDescendants = P("bool", false),
	AutomaticSize = P("enum:AutomaticSize", Enum.AutomaticSize.None), SizeConstraint = P("enum:SizeConstraint", Enum.SizeConstraint.RelativeXY),
	Active = P("bool", false) }, {}, { noCreate = true })
def("Frame", "GuiObject", {})
local TEXT = { Text = P("str", "Label"), TextColor3 = P("Color3", c3(0.1, 0.1, 0.1)), TextScaled = P("bool", false), TextSize = P("num", 14),
	Font = P("enum:Font", Enum.Font.Legacy), FontFace = P("any", nil), TextStrokeTransparency = P("num", 1), TextStrokeColor3 = P("Color3", c3(0, 0, 0)),
	TextTransparency = P("num", 0), TextWrapped = P("bool", false), TextXAlignment = P("enum:TextXAlignment", Enum.TextXAlignment.Center),
	TextYAlignment = P("enum:TextYAlignment", Enum.TextYAlignment.Center), RichText = P("bool", false), LineHeight = P("num", 1) }
def("TextLabel", "GuiObject", TEXT)
def("TextButton", "GuiObject", TEXT)
def("ImageLabel", "GuiObject", { Image = P("str", ""), ImageColor3 = P("Color3", c3(1, 1, 1)), ImageTransparency = P("num", 0),
	ScaleType = P("enum:ScaleType", Enum.ScaleType.Stretch) })
def("UIComponent", "Instance", {}, {}, { noCreate = true })
def("UICorner", "UIComponent", { CornerRadius = P("UDim", UDim.new(0, 8)) })
def("UIStroke", "UIComponent", { Color = P("Color3", c3(0, 0, 0)), Thickness = P("num", 1), Transparency = P("num", 0),
	ApplyStrokeMode = P("enum:ApplyStrokeMode", Enum.ApplyStrokeMode.Contextual), Enabled = P("bool", true) })
def("UIGradient", "UIComponent", { Color = P("ColorSequence", nil), Rotation = P("num", 0), Transparency = P("NumberSequence", nil),
	Offset = P("Vector2", v2()), Enabled = P("bool", true) })
def("UIPadding", "UIComponent", { PaddingTop = P("UDim", UDim.new()), PaddingBottom = P("UDim", UDim.new()),
	PaddingLeft = P("UDim", UDim.new()), PaddingRight = P("UDim", UDim.new()) })
def("UIListLayout", "UIComponent", { FillDirection = P("enum:FillDirection", Enum.FillDirection.Vertical), Padding = P("UDim", UDim.new()),
	HorizontalAlignment = P("enum:HorizontalAlignment", Enum.HorizontalAlignment.Left), VerticalAlignment = P("enum:VerticalAlignment", Enum.VerticalAlignment.Top),
	SortOrder = P("enum:SortOrder", Enum.SortOrder.LayoutOrder) })
def("UIAspectRatioConstraint", "UIComponent", { AspectRatio = P("num", 1) })

-- службы
def("ServiceProvider", "Instance", {}, {}, { noCreate = true })
def("Camera", "Instance", { CFrame = P("CFrame", cf(0, 20, 20)), FieldOfView = P("num", 70), CameraType = P("any", nil),
	CameraSubject = P("inst", nil), Focus = P("CFrame", cf(0, 0, 0)), ViewportSize = P("Vector2", v2(1280, 720), RO) })
def("Workspace", "Model", { Gravity = P("num", 196.2), StreamingEnabled = P("bool", false), CurrentCamera = P("inst", nil),
	FallenPartsDestroyHeight = P("num", -500), DistributedGameTime = P("num", 0) },
	{ Raycast = function() return nil end, GetPartBoundsInRadius = function() return {} end, GetPartBoundsInBox = function() return {} end,
	  GetServerTimeNow = function() return 0 end }, { noCreate = true })
def("Lighting", "Instance", { Ambient = P("Color3", c3(0.27, 0.27, 0.27)), OutdoorAmbient = P("Color3", c3(0.5, 0.5, 0.5)),
	Brightness = P("num", 2), ClockTime = P("num", 14), TimeOfDay = P("str", "14:00:00"), GeographicLatitude = P("num", 23.5),
	GlobalShadows = P("bool", true), ShadowSoftness = P("num", 0.2), EnvironmentDiffuseScale = P("num", 0), EnvironmentSpecularScale = P("num", 0),
	ExposureCompensation = P("num", 0), FogColor = P("Color3", c3(0.75, 0.75, 0.75)), FogEnd = P("num", 100000), FogStart = P("num", 0),
	ColorShift_Top = P("Color3", c3(0, 0, 0)), ColorShift_Bottom = P("Color3", c3(0, 0, 0)), Technology = P("enum:Technology", Enum.Technology.Future) },
	{}, { noCreate = true })
def("Player", "Instance", { Character = P("inst", nil), UserId = P("num", 1), DisplayName = P("str", "Player"),
	CharacterAdded = sig("CharacterAdded"), CharacterRemoving = sig("CharacterRemoving") },
	{ GetMouse = function() return {} end, Kick = function() end }, { noCreate = true })
def("Humanoid", "Instance", { WalkSpeed = P("num", 16), JumpPower = P("num", 50), Health = P("num", 100), MaxHealth = P("num", 100), RootPart = P("inst", nil) })
for _, n in ipairs({ "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterPlayer", "StarterPlayerScripts", "StarterGui",
	"StarterPack", "SoundService", "Teams", "PlayerGui", "Backpack", "PlayerScripts", "StarterCharacterScripts" }) do
	def(n, "Instance", {}, {}, { noCreate = true })
end

---------------------------------------------------------------------------
-- DataModel и службы
---------------------------------------------------------------------------
local services = {}
def("DataModel", "Instance", {}, {
	GetService = function(self, n)
		local s = services[n]
		if not s then error("'" .. tostring(n) .. "' is not a valid Service name (mock)", 2) end
		return s
	end,
	IsLoaded = function() return true end,
	BindToClose = function() end,
}, { noCreate = true })
local game = newInstance("DataModel", true)
DATA[game].props.Name = "Game"
DATA[game].signals.Loaded = signal()

local function service(cls, name)
	local s = newInstance(cls, true)
	DATA[s].props.Name = name or cls
	setParent(s, DATA[s], game)
	DATA[s].locked = true
	services[name or cls] = s
	return s
end
for _, n in ipairs({ "Workspace", "Lighting", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterPlayer",
	"StarterGui", "StarterPack", "SoundService", "Teams" }) do
	service(n)
end
local workspace = services.Workspace
local terrain = newInstance("Terrain", true)
DATA[terrain].props.Name = "Terrain"
setParent(terrain, DATA[terrain], workspace)
DATA[terrain].locked = true
local cam = newInstance("Camera", true)
DATA[cam].props.Name = "Camera"
setParent(cam, DATA[cam], workspace)
DATA[workspace].props.CurrentCamera = cam
local sps = newInstance("StarterPlayerScripts", true)
DATA[sps].props.Name = "StarterPlayerScripts"
setParent(sps, DATA[sps], services.StarterPlayer)

-- Players
local PlayersSvc = setmetatable({ LocalPlayer = nil, PlayerAdded = signal(), PlayerRemoving = signal() }, { __index = {
	GetPlayers = function(self) return self.LocalPlayer and { self.LocalPlayer } or {} end,
	GetPlayerFromCharacter = function() return nil end,
} })
services.Players = PlayersSvc

local RunSvc = {
	Heartbeat = signal(), RenderStepped = signal(), Stepped = signal(), PostSimulation = signal(), PreRender = signal(),
}
RunSvc.isServer = true
setmetatable(RunSvc, { __index = {
	IsServer = function(self) return self.isServer end,
	IsClient = function(self) return not self.isServer end,
	IsStudio = function() return true end,
	BindToRenderStep = function(_, _, _, fn) RunSvc.RenderStepped:Connect(fn) end,
	UnbindFromRenderStep = function() end,
} })
services.RunService = RunSvc

services.CollectionService = {
	AddTag = function(_, inst, t) inst:AddTag(t) end,
	HasTag = function(_, inst, t) return inst:HasTag(t) end,
	RemoveTag = function(_, inst, t) inst:RemoveTag(t) end,
	GetTagged = function(_, t)
		local o = {}
		for inst in pairs(CollectionTags[t] or {}) do if not DATA[inst].destroyed then o[#o + 1] = inst end end
		table.sort(o, function(a, b) return a:GetFullName() < b:GetFullName() end)
		return o
	end,
	GetInstanceAddedSignal = function() return signal() end,
	GetInstanceRemovedSignal = function() return signal() end,
}

local TweenMT = { __index = { Play = function(self) self.PlaybackState = Enum.PlaybackState.Playing end,
	Cancel = function() end, Pause = function() end } }
services.TweenService = {
	Create = function(_, inst, info, goals)
		if not isInst(inst) then error("TweenService:Create: argument 1 must be an Instance", 2) end
		if typeof(info) ~= "TweenInfo" then error("TweenService:Create: argument 2 must be TweenInfo", 2) end
		for k, v in pairs(goals) do
			local p = findProp(DATA[inst].cls, k)
			if not p and not (isA(DATA[inst].cls, "BasePart") and (k == "Position" or k == "Orientation")) then
				error("TweenService:Create: no property " .. tostring(k) .. " in " .. DATA[inst].cls.name, 2)
			end
			if p and not checkType(p.t, v) then error("TweenService:Create: wrong type for " .. k, 2) end
		end
		return setmetatable({ Completed = signal(), PlaybackState = Enum.PlaybackState.Begin, goals = goals, inst = inst }, TweenMT)
	end,
	GetValue = function(_, a) return a end,
}
services.UserInputService = { InputBegan = signal(), InputEnded = signal(), TouchEnabled = false, KeyboardEnabled = true,
	GetLastInputType = function() return Enum.UserInputType.Keyboard end }
services.Debris = { AddItem = function() end }
services.ContentProvider = { PreloadAsync = function() end }

---------------------------------------------------------------------------
-- Глобальное окружение скриптов
---------------------------------------------------------------------------
local mathX = setmetatable({
	clamp = function(x, a, b)
		if a > b then error("math.clamp: max must be greater than or equal to min", 2) end
		return math.max(a, math.min(b, x))
	end,
	sign = function(x) return x > 0 and 1 or (x < 0 and -1 or 0) end,
	round = function(x) return floor(x + 0.5) end,
	noise = function(x, y, z) -- не как в Roblox: в коде карты не используем
		return (sin((x or 0) * 12.9898 + (y or 0) * 78.233 + (z or 0) * 37.719) * 43758.5453) % 1 - 0.5
	end,
	lerp = function(a, b, t) return a + (b - a) * t end,
}, { __index = math })
local tableX = setmetatable({
	create = function(n, v) local t = {} for i = 1, n do t[i] = v end return t end,
	find = function(t, v, init) for i = init or 1, #t do if t[i] == v then return i end end return nil end,
	clear = function(t) for k in pairs(t) do t[k] = nil end end,
	freeze = function(t) return t end,
	isfrozen = function() return false end,
	clone = function(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end,
	unpack = table.unpack,
}, { __index = table })
local stringX = setmetatable({
	split = function(s, sep)
		sep = sep or ","
		local o, i = {}, 1
		while true do
			local a, b = string.find(s, sep, i, true)
			if not a then o[#o + 1] = s:sub(i) break end
			o[#o + 1] = s:sub(i, a - 1)
			i = b + 1
		end
		return o
	end,
}, { __index = string })

local function runThread(fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then table.insert(M.errors, debug.traceback(co, tostring(err))) end
	return co
end

local task = {
	wait = function(t) return t or 0.03 end,
	spawn = function(fn, ...)
		if type(fn) == "thread" then return fn end
		return runThread(fn, ...)
	end,
	defer = function(fn, ...)
		local args = table.pack(...)
		table.insert(M.deferred, function() runThread(fn, table.unpack(args, 1, args.n)) end)
	end,
	delay = function(_, fn, ...)
		local args = table.pack(...)
		table.insert(M.deferred, function() runThread(fn, table.unpack(args, 1, args.n)) end)
	end,
	cancel = function() end,
	synchronize = function() end,
	desynchronize = function() end,
}

local moduleCache = {}
local makeEnv

local function runSource(scriptInst, isModule)
	local d = DATA[scriptInst]
	local src = d.props.Source
	local env = makeEnv(scriptInst)
	local chunk, err = load(src, "@" .. scriptInst:GetFullName(), "t", env)
	if not chunk then error("syntax error: " .. err, 0) end
	return chunk
end

local function requireModule(m)
	if not isInst(m) or DATA[m].cls.name ~= "ModuleScript" then
		error("Attempted to call require with invalid argument(s).", 2)
	end
	local c = moduleCache[m]
	if c then
		if c.loading then error("Requested module was required recursively: " .. m:GetFullName(), 2) end
		return c.value
	end
	c = { loading = true }
	moduleCache[m] = c
	local chunk = runSource(m, true)
	local res = table.pack(chunk())
	if res.n ~= 1 then error("Module code did not return exactly one value: " .. m:GetFullName(), 2) end
	c.loading = false
	c.value = res[1]
	return c.value
end

local Instance = {
	new = function(cls, parent)
		local o = newInstance(cls)
		if parent then o.Parent = parent end
		return o
	end,
}

makeEnv = function(scriptInst)
	local env = {
		game = game, workspace = workspace, Workspace = workspace, script = scriptInst,
		Instance = Instance, Vector3 = V3, Vector2 = V2, CFrame = CF, Color3 = C3, BrickColor = BrickColor,
		UDim = UDim, UDim2 = UDim2, Enum = Enum, TweenInfo = TweenInfo, NumberSequence = NumberSequence,
		NumberSequenceKeypoint = NumberSequenceKeypoint, ColorSequence = ColorSequence, ColorSequenceKeypoint = ColorSequenceKeypoint,
		NumberRange = NumberRange, Random = RandomLib, PhysicalProperties = PhysicalProperties, task = task,
		math = mathX, string = stringX, table = tableX, utf8 = utf8, coroutine = coroutine, os = os,
		typeof = typeof, type = type, tostring = tostring, tonumber = tonumber, pairs = pairs, ipairs = ipairs, next = next,
		select = select, unpack = table.unpack, rawget = rawget, rawset = rawset, rawequal = rawequal, setmetatable = setmetatable,
		getmetatable = getmetatable, pcall = pcall, xpcall = xpcall, error = error, assert = assert,
		print = function(...)
			local t = {}
			for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
			table.insert(M.prints, table.concat(t, " "))
		end,
		warn = function(...)
			local t = {}
			for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
			table.insert(M.warns, table.concat(t, " "))
		end,
		require = requireModule,
		tick = function() return os.clock() end, time = function() return os.clock() end, wait = task.wait,
		spawn = task.spawn, delay = task.delay, debug = { traceback = debug.traceback, profilebegin = function() end, profileend = function() end },
	}
	return setmetatable(env, { __index = function(_, k) error("unknown global '" .. tostring(k) .. "'", 2) end,
		__newindex = function(_, k) error("assignment to global '" .. tostring(k) .. "' (use local)", 2) end })
end

---------------------------------------------------------------------------
-- API для харнесса
---------------------------------------------------------------------------
M.game = game
M.services = services
M.workspace = workspace
M.terrain = terrain
M.CF, M.V3, M.C3 = CF, V3, C3

function M.addScript(parent, cls, name, source)
	local s = newInstance(cls, true)
	DATA[s].props.Name = name
	DATA[s].props.Source = source
	setParent(s, DATA[s], parent)
	return s
end
function M.addFolder(parent, name, cls)
	local f = newInstance(cls or "Folder", true)
	DATA[f].props.Name = name
	setParent(f, DATA[f], parent)
	return f
end
function M.service(n) return services[n] end

function M.runScript(s)
	local ok, err = xpcall(function()
		local chunk = runSource(s, false)
		local co = coroutine.create(chunk)
		local ok2, e2 = coroutine.resume(co)
		if not ok2 then error(debug.traceback(co, tostring(e2)), 0) end
	end, function(e) return tostring(e) end)
	if not ok then table.insert(M.errors, err) end
	local guard = 0
	while #M.deferred > 0 and guard < 10000 do
		local f = table.remove(M.deferred, 1)
		f()
		guard = guard + 1
	end
end

-- клиентский режим: игрок с персонажем в точке pos
function M.makeClient(pos)
	RunSvc.isServer = false
	local plr = newInstance("Player", true)
	DATA[plr].props.Name = "Tester"
	local pg = newInstance("PlayerGui", true)
	DATA[pg].props.Name = "PlayerGui"
	setParent(pg, DATA[pg], plr)
	local char = newInstance("Model", true)
	DATA[char].props.Name = "Tester"
	local root = newInstance("Part", true)
	DATA[root].props.Name = "HumanoidRootPart"
	DATA[root].props.CFrame = cf(pos.X, pos.Y, pos.Z)
	setParent(root, DATA[root], char)
	local hum = newInstance("Humanoid", true)
	setParent(hum, DATA[hum], char)
	DATA[char].props.PrimaryPart = root
	setParent(char, DATA[char], workspace)
	DATA[plr].props.Character = char
	PlayersSvc.LocalPlayer = plr
	return plr, root
end

function M.step(dt, frames)
	for _ = 1, frames or 1 do
		for _, sigName in ipairs({ "Heartbeat", "RenderStepped" }) do
			for _, c in ipairs(RunSvc[sigName].list) do
				if c.Connected then
					local ok, err = xpcall(c.fn, debug.traceback, dt)
					if not ok then table.insert(M.errors, err) c.Connected = false end
				end
			end
		end
		local guard = 0
		while #M.deferred > 0 and guard < 1000 do table.remove(M.deferred, 1)() guard = guard + 1 end
	end
end

-- выгрузка деталей и рельефа в JSON (для превью)
local function num(x) return string.format("%.3f", x) end
local function col(c) return "[" .. num(c.R) .. "," .. num(c.G) .. "," .. num(c.B) .. "]" end
local function cfj(c)
	local r = c.r
	return "[" .. table.concat({ num(c.px), num(c.py), num(c.pz), num(r[1]), num(r[2]), num(r[3]), num(r[4]), num(r[5]), num(r[6]), num(r[7]), num(r[8]), num(r[9]) }, ",") .. "]"
end
local function jstr(s) return '"' .. tostring(s):gsub('[%c"\\]', function(ch) return string.format("\\u%04x", ch:byte()) end) .. '"' end

function M.exportJSON()
	local out = { '{"parts":[' }
	local first = true
	for _, p in ipairs(descendants(workspace, {})) do
		local d = DATA[p]
		if isA(d.cls, "BasePart") and d.cls.name ~= "Terrain" then
			local pr = d.props
			local shape = d.cls.name == "Part" and pr.Shape.Name or (d.cls.name == "WedgePart" and "Wedge" or (d.cls.name == "CornerWedgePart" and "CornerWedge" or "Block"))
			for _, c in ipairs(d.children) do
				local cd = DATA[c]
				if cd.cls.name == "SpecialMesh" then shape = "Mesh" .. cd.props.MeshType.Name end
			end
			local light = false
			for _, c in ipairs(d.children) do if isA(DATA[c].cls, "Light") then light = true end end
			local s = pr.Size
			local top = p:FindFirstAncestorWhichIsA("Model")
			local group = "?"
			local q = p
			while q and DATA[q].parent and DATA[q].parent ~= workspace do q = DATA[q].parent end
			if q then group = DATA[q].props.Name end
			local zone = q and p or nil
			local sub = DATA[p].parent
			local subName = "?"
			local a = p
			while a and DATA[a].parent and DATA[DATA[a].parent].parent ~= workspace do a = DATA[a].parent end
			if a and DATA[a].parent and DATA[a].parent ~= workspace then subName = DATA[a].props.Name else subName = DATA[p].props.Name end
			out[#out + 1] = (first and "" or ",") .. "{" ..
				'"n":' .. jstr(pr.Name) .. ',"g":' .. jstr(group) .. ',"sg":' .. jstr(subName) .. ',"s":' .. jstr(shape) ..
				',"sz":[' .. num(s.X) .. "," .. num(s.Y) .. "," .. num(s.Z) .. '],"cf":' .. cfj(pr.CFrame) ..
				',"c":' .. col(pr.Color) .. ',"t":' .. num(pr.Transparency) .. ',"m":' .. jstr(pr.Material.Name) ..
				',"cc":' .. tostring(pr.CanCollide) .. ',"l":' .. tostring(light) .. "}"
			first = false
			local _ = top and zone and sub
		end
	end
	out[#out + 1] = '],"terrain":['
	for i, t in ipairs(M.terrainOps) do
		local s = (i > 1 and "," or "") .. '{"op":"' .. t.op .. '","mat":"' .. t.mat .. '"'
		if t.cf then s = s .. ',"cf":' .. cfj(t.cf) end
		if t.size then s = s .. ',"size":[' .. num(t.size.X) .. "," .. num(t.size.Y) .. "," .. num(t.size.Z) .. "]" end
		if t.center then s = s .. ',"center":[' .. num(t.center.X) .. "," .. num(t.center.Y) .. "," .. num(t.center.Z) .. "]" end
		if t.r then s = s .. ',"r":' .. num(t.r) end
		if t.h then s = s .. ',"h":' .. num(t.h) end
		out[#out + 1] = s .. "}"
	end
	out[#out + 1] = '],"waterColor":' .. col(DATA[terrain].props.WaterColor)
	out[#out + 1] = ',"terrainColors":{'
	local tc, firstc = M.terrainColors or {}, true
	local names = {}
	for k in pairs(tc) do names[#names + 1] = k end
	table.sort(names)
	for _, k in ipairs(names) do
		out[#out + 1] = (firstc and "" or ",") .. jstr(k) .. ":" .. col(tc[k])
		firstc = false
	end
	out[#out + 1] = "}}"
	return table.concat(out)
end

-- статистика: сколько экземпляров каждого класса в workspace и Lighting
function M.stats()
	local counts = {}
	for _, root in ipairs({ workspace, services.Lighting }) do
		for _, o in ipairs(descendants(root, {})) do
			local n = DATA[o].cls.name
			counts[n] = (counts[n] or 0) + 1
		end
	end
	local o = {}
	for k, v in pairs(counts) do o[#o + 1] = k .. "=" .. v end
	table.sort(o)
	return table.concat(o, " ")
end

return M
