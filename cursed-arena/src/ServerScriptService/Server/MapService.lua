-- Карта: ломающиеся предметы (фонари, скамейки, ящики, машины), метки (манекены, боты).
-- Сломанный предмет прячется на сервере, обломки рисуют клиенты; через время предмет возвращается.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(script.Parent.Net)

local MapService = {}
local items = {}   -- { model, center, radius, broken, saved }

local function partsOf(inst)
	local out = {}
	if inst:IsA("BasePart") then out[#out + 1] = inst end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then out[#out + 1] = d end
	end
	return out
end

function MapService.init()
	local map = workspace:WaitForChild("Map")
	local folder = map:FindFirstChild("Breakables")
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			local parts = partsOf(m)
			if #parts > 0 then
				local minV, maxV
				for _, p in ipairs(parts) do
					local a, b = p.Position - p.Size / 2, p.Position + p.Size / 2
					minV = minV and Vector3.new(math.min(minV.X, a.X), math.min(minV.Y, a.Y), math.min(minV.Z, a.Z)) or a
					maxV = maxV and Vector3.new(math.max(maxV.X, b.X), math.max(maxV.Y, b.Y), math.max(maxV.Z, b.Z)) or b
				end
				items[#items + 1] = { model = m, parts = parts, center = (minV + maxV) / 2, radius = (maxV - minV).Magnitude / 2, broken = false }
			end
		end
	end
end

local function restore(it)
	if not it.broken then return end
	it.broken = false
	for p, s in pairs(it.saved) do
		if p.Parent then
			p.Transparency = s.t
			p.CanCollide = s.c
			p.CanQuery = s.q
		end
	end
	it.saved = nil
	Net.fx("Restore", { m = it.model })
end

-- сломать всё в радиусе
function MapService.breakAt(pos, radius, force)
	local broken = {}
	for _, it in ipairs(items) do
		if not it.broken and (it.center - pos).Magnitude <= radius + it.radius * 0.6 then
			it.broken = true
			it.saved = {}
			for _, p in ipairs(it.parts) do
				it.saved[p] = { t = p.Transparency, c = p.CanCollide, q = p.CanQuery }
				p.Transparency = 1
				p.CanCollide = false
				p.CanQuery = false
			end
			broken[#broken + 1] = it.model
			task.delay(Config.Breakables.RestoreTime, function() restore(it) end)
		end
	end
	if #broken > 0 then
		Net.fx("Break", { list = broken, p = pos, f = force or 1 })
	end
	return #broken
end

-- метки на карте: Map/Markers/<имя>
function MapService.markers(name)
	local out = {}
	local map = workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("Markers")
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			if m.Name == name and m:IsA("BasePart") then out[#out + 1] = m.CFrame end
		end
	end
	return out
end

return MapService
