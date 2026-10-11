-- Зоны собирательства: общая часть. Стены с воротами между зонами (барьер с ценой открытия),
-- арка-вход в первую зону, невидимые границы, области зон и точки появления ингредиентов.
-- Наполнение каждой зоны — в модулях Zones/<Id>.
local RS = game:GetService("ReplicatedStorage")
local B = require(RS.Shared.Build)
local D = require(RS.Shared.MapData)
local Rng = require(RS.Shared.Rng)
local P = require(script.Parent.Props)

local Zones = {}
local C, rgb = P.C, P.rgb
local M = Enum.Material

local INNER = 98       -- предметы ставим в x от −INNER до INNER
local WALL_GAP = 16    -- и не ближе этого к стенам между зонами
local SPAWNS = 45      -- точек появления ингредиентов на зону

-- 1000000 -> "1 000 000"
function Zones.formatPrice(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^ ", ""))
end

local function gateWall(parent, lower, upper)
	local m = B.model(parent, "Gate_" .. upper.id)
	local zb = upper.z0
	local base = lower.level - 2
	local top = upper.level + 20
	local accent = upper.accent
	local stone = rgb(70, 72, 82)
	local half = 160
	local openW = 26
	local openTop = upper.level + 15
	B.wall(m, "Wall", Vector3.new(-half, base, zb), Vector3.new(half, base, zb), top - base, 8, stone, M.Slate, {
		{ at = half, w = openW, y0 = 0, y1 = openTop - base },
	})
	-- зубцы и светящаяся полоса
	for x = -half + 5, half - 5, 10 do
		if math.abs(x) > openW / 2 + 8 then
			B.part(m, "Merlon", Vector3.new(5, 4, 9), CFrame.new(x, top + 2, zb), stone, M.Slate)
		end
	end
	for _, sz in ipairs({ -4.1, 4.1 }) do
		B.part(m, "Stripe", Vector3.new(half * 2, 0.6, 0.2), CFrame.new(0, upper.level + 17, zb + sz), accent, M.Neon)
	end
	-- башни у прохода
	for _, x in ipairs({ -openW / 2 - 5, openW / 2 + 5 }) do
		B.part(m, "Tower", Vector3.new(10, top - base + 8, 12), CFrame.new(x, (base + top + 8) / 2, zb), rgb(56, 58, 68), M.Slate)
		B.part(m, "TowerCap", Vector3.new(12, 1.5, 14), CFrame.new(x, top + 8.75, zb), rgb(46, 48, 58), M.Slate)
		local orb = B.ball(m, "Beacon", 4, CFrame.new(x, top + 11.5, zb), accent, M.Neon)
		B.light(orb, "PointLight", { Range = 30, Brightness = 2, Color = accent })
		B.tag(orb, "Pulse", { Speed = 2 })
	end
	-- надписи над проходом: с юга — куда ведёт и цена, с севера — куда вернуться
	local sign = B.part(m, "GateSign", Vector3.new(openW + 4, 4.5, 0.6), CFrame.new(0, openTop + 2.6, zb + 4.4), rgb(28, 30, 40), M.SmoothPlastic)
	P.board(sign, Enum.NormalId.Back, "🔒 " .. upper.title, "Открыть: " .. Zones.formatPrice(upper.price) .. " монет", accent, rgb(28, 30, 40))
	local back = B.part(m, "BackSign", Vector3.new(openW + 4, 3, 0.6), CFrame.new(0, openTop + 2, zb - 4.4), rgb(28, 30, 40), M.SmoothPlastic)
	P.board(back, Enum.NormalId.Front, "↓ " .. lower.title, nil, lower.accent, rgb(28, 30, 40))
	-- барьер: сервер игры уберёт его для тех, кто открыл зону
	local barrier = B.part(m, "Barrier", Vector3.new(openW, openTop - upper.level + 1, 1.2),
		CFrame.new(0, upper.level + (openTop - upper.level + 1) / 2 - 1, zb), accent, M.ForceField, { Transparency = 0.15 })
	B.attrs(barrier, { Zone = upper.id, Price = upper.price })
	B.tag(barrier, "ZoneBarrier")
	-- невидимая преграда над стеной: не перепрыгнуть с грибов и хребтов
	B.part(m, "InvisibleCeiling", Vector3.new(half * 2, 120, 2), CFrame.new(0, top + 60, zb), nil, nil,
		{ Transparency = 1, CastShadow = false, CanQuery = false })
	return m
end

local function bounds(parent, zone)
	local depth = zone.z0 - zone.z1
	local mk = B.marker(parent, "Bounds", Vector3.new(D.ZONE_HALF_W * 2, 80, depth), CFrame.new(0, zone.level + 30, (zone.z0 + zone.z1) / 2))
	B.attrs(mk, { Zone = zone.id, Level = zone.level, Price = zone.price, Index = zone.index })
	return mk
end

-- невидимые стены: не дают обойти ворота по хребтам и берегу
local function sideWalls(parent)
	local zs, ze = D.Zones[1].z0 + 10, D.Island[2][3]
	for _, x in ipairs({ -130, 130 }) do
		B.part(parent, "InvisibleWall", Vector3.new(2, 160, zs - ze), CFrame.new(x, 40, (zs + ze) / 2), nil, nil,
			{ Transparency = 1, CastShadow = false, CanQuery = false })
	end
	B.part(parent, "InvisibleWall", Vector3.new(262, 160, 2), CFrame.new(0, 40, ze + 18), nil, nil,
		{ Transparency = 1, CastShadow = false, CanQuery = false })
end

function Zones.build(root)
	local folder = B.folder(root, "Zones")
	sideWalls(folder)
	-- вход в первую зону
	local z1 = D.Zones[1]
	P.arch(folder, CFrame.new(0, z1.level, z1.z0), 30, 20, rgb(80, 70, 96), z1.accent, z1.title, "Зона 1 · вход свободный")

	for i, zone in ipairs(D.Zones) do
		local zm = B.model(folder, zone.id)
		B.attrs(zm, { Zone = zone.id, Index = i })
		bounds(zm, zone)
		if i > 1 then gateWall(zm, D.Zones[i - 1], zone) end
		local ctx = {
			zone = zone,
			model = zm,
			rng = Rng.new(1000 + i * 37),
			occ = P.newOcc(),
			L = zone.level,
			x0 = -INNER, x1 = INNER,
			z0 = zone.z0 - WALL_GAP, z1 = zone.z1 + WALL_GAP,
		}
		-- проходы у ворот держим свободными
		ctx.occ:add(0, zone.z0 - 6, 18)
		ctx.occ:add(0, zone.z1 + 26, 22)
		require(script[zone.id]).build(ctx)
		local spawns = B.folder(zm, "Spawns")
		P.spawnPoints(spawns, ctx.rng, ctx.occ, ctx.x0, ctx.x1, ctx.z0, ctx.z1, ctx.spawnY or ctx.L, SPAWNS, zone.id)
	end
	return folder
end

return Zones
