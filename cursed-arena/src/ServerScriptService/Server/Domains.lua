-- Территории (ульты Повелителя Пустоты, Алого Клинка и Призывателя Теней).
-- Купол радиуса r на dur секунд: враги внутри получают эффекты своего стиля,
-- выйти за границу нельзя (выталкивает обратно). Две территории рядом — ломают друг друга.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Fighters = require(script.Parent.Fighters)
local Combat = require(script.Parent.Combat)
local Net = require(script.Parent.Net)

local Domains = {}
Domains.active = {}
local nextId = 0

local function inside(d, f)
	local p = f.root.Position
	local c = d.center
	return (Vector3.new(p.X, 0, p.Z) - Vector3.new(c.X, 0, c.Z)).Magnitude <= d.radius and math.abs(p.Y - c.Y) < d.radius
end
Domains.inside = inside

function Domains.close(d, reason)
	if d.closed then return end
	d.closed = true
	for i = #Domains.active, 1, -1 do
		if Domains.active[i] == d then table.remove(Domains.active, i) end
	end
	Net.fx("DomainEnd", { id = d.id, reason = reason })
	if d.onEnd then pcall(d.onEnd, d, reason) end
end

-- opts: style, radius, duration, tick (интервал), onTick(d, victims), onEnd
function Domains.open(f, opts)
	nextId = nextId + 1
	local center = Util.ground(f.root.Position)
	local d = {
		id = nextId, owner = f, style = opts.style, center = center, radius = opts.radius or Config.Domain.Radius,
		endTime = Util.now() + (opts.duration or Config.Domain.Duration), tick = opts.tick or 0.5, nextTick = Util.now() + 0.6,
		onTick = opts.onTick, onEnd = opts.onEnd, closed = false,
	}
	-- столкновение территорий
	for _, o in ipairs(Domains.active) do
		if (o.center - center).Magnitude < (o.radius + d.radius) * Config.Domain.ClashDistance then
			Net.fx("DomainClash", { p = (o.center + center) / 2 })
			Domains.close(o, "clash")
			return nil
		end
	end
	table.insert(Domains.active, d)
	Net.fx("Domain", { id = d.id, m = f.model, style = d.style, c = center, r = d.radius, dur = opts.duration or Config.Domain.Duration,
		name = opts.name })
	return d
end

RunService.Heartbeat:Connect(function()
	if #Domains.active == 0 then return end
	local now = Util.now()
	for i = #Domains.active, 1, -1 do
		local d = Domains.active[i]
		if d and not d.closed then
			if now >= d.endTime or not Fighters.alive(d.owner) then
				Domains.close(d, "end")
			else
				-- враги внутри: замедление, тишина, не выйти
				local victims = {}
				for _, f in ipairs(Fighters.list) do
					if f ~= d.owner and Fighters.alive(f) then
						local p = f.root.Position
						local flat = Vector3.new(p.X - d.center.X, 0, p.Z - d.center.Z)
						local dist = flat.Magnitude
						if dist <= d.radius and math.abs(p.Y - d.center.Y) < d.radius then
							victims[#victims + 1] = f
							f.silenceEnd = math.max(f.silenceEnd, now + 0.25)
							f.slowEnd = math.max(f.slowEnd, now + 0.25)
							f.slowMult = math.min(f.slowMult < 1 and now < f.slowEnd and f.slowMult or 1, d.slow or 0.45)
						elseif dist <= d.radius + 6 and dist > d.radius and f.domainId == d.id then
							-- пытается выйти — вталкиваем обратно
							Combat.knockback(f, -flat.Unit * 40, 0.12)
						end
						if dist <= d.radius then f.domainId = d.id end
					end
				end
				if now >= d.nextTick then
					d.nextTick = now + d.tick
					if d.onTick then
						local ok, err = pcall(d.onTick, d, victims)
						if not ok then warn("[Domains] " .. tostring(err)) end
					end
				end
			end
		end
	end
end)

-- сбросить замедление после территории
table.insert(Fighters.onExpire, function(f, now)
	if f.slowMult < 1 and now >= f.slowEnd then f.slowMult = 1 end
end)

return Domains
