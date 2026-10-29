-- Мелкие помощники для сервера и клиента
local Util = {}

-- общее время сервера и клиентов (одинаковое на всех машинах)
function Util.now()
	return workspace:GetServerTimeNow()
end

function Util.clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

function Util.lerp(a, b, t)
	return a + (b - a) * t
end

-- горизонтальное направление (без Y), единичное; если вектор нулевой — запасное
function Util.flat(v, fallback)
	if typeof(v) ~= "Vector3" then return fallback or Vector3.new(0, 0, -1) end
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then return fallback or Vector3.new(0, 0, -1) end
	return f.Unit
end

-- CFrame в точке pos, смотрящий по горизонтальному направлению dir
function Util.facing(pos, dir)
	local d = Util.flat(dir)
	return CFrame.lookAt(pos, pos + d)
end

function Util.root(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end

function Util.hum(model)
	return model and model:FindFirstChildOfClass("Humanoid")
end

function Util.alive(model)
	local h = Util.hum(model)
	return h ~= nil and h.Health > 0 and model.Parent ~= nil
end

-- точка на земле под pos (или pos, если земли нет)
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
function Util.ground(pos, depth)
	local map = workspace:FindFirstChild("Map")
	if not map then return pos, nil end
	groundParams.FilterDescendantsInstances = { map }
	local r = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -(depth or 60), 0), groundParams)
	if r then return r.Position, r end
	return pos, nil
end

-- луч только по карте
function Util.mapRay(origin, dir)
	local map = workspace:FindFirstChild("Map")
	if not map then return nil end
	groundParams.FilterDescendantsInstances = { map }
	return workspace:Raycast(origin, dir, groundParams)
end

function Util.weld(p0, p1)
	local w = Instance.new("WeldConstraint")
	w.Part0 = p0
	w.Part1 = p1
	w.Parent = p0
	return w
end

-- простая деталь: Util.part({ Size = ..., CFrame = ..., Color = ... }, parent)
function Util.part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	if parent then p.Parent = parent end
	return p
end

function Util.shuffle(t, rng)
	for i = #t, 2, -1 do
		local j = rng and rng:NextInteger(1, i) or math.random(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

-- случайное число из [a, b]
function Util.rand(a, b)
	return a + math.random() * (b - a)
end

-- случайный элемент
function Util.pick(t)
	return t[math.random(1, #t)]
end

function Util.colorHex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

return Util
