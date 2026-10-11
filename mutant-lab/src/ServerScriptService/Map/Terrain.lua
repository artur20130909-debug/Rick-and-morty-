-- Рельеф (Terrain): океан, остров, коридор зон с обрывами, хребты по бокам зон, река вокруг
-- острова босса, холмы и подъёмы между зонами. Особый рельеф зон (пруды, кратер, арки)
-- делают модули зон через помощники отсюда.
local RS = game:GetService("ReplicatedStorage")
local D = require(RS.Shared.MapData)
local Rng = require(RS.Shared.Rng)

local T = {}
local terrain = workspace.Terrain
local M = Enum.Material

-- блок с разбиением на куски (большие заливки за один раз Roblox делает медленно)
function T.block(x0, x1, y0, y1, z0, z1, mat)
	if x0 > x1 then x0, x1 = x1, x0 end
	if z0 > z1 then z0, z1 = z1, z0 end
	local CH = 512
	local x = x0
	while x < x1 do
		local xe = math.min(x + CH, x1)
		local z = z0
		while z < z1 do
			local ze = math.min(z + CH, z1)
			terrain:FillBlock(CFrame.new((x + xe) / 2, (y0 + y1) / 2, (z + ze) / 2), Vector3.new(xe - x, y1 - y0, ze - z), mat)
			z = ze
		end
		x = xe
	end
end

-- повёрнутый вокруг вертикали блок (дорожки, пятна)
function T.slab(cf, size, mat)
	terrain:FillBlock(cf, size, mat)
end

function T.ball(x, y, z, r, mat)
	terrain:FillBall(Vector3.new(x, y, z), r, mat)
end

-- вертикальный цилиндр: низ y0, верх y1
function T.cyl(x, z, y0, y1, r, mat)
	terrain:FillCylinder(CFrame.new(x, (y0 + y1) / 2, z), y1 - y0, r, mat)
end

-- круглое пятно другого материала на поверхности уровня y
function T.patch(x, z, y, r, mat)
	terrain:FillCylinder(CFrame.new(x, y - 1, z), 2, r, mat)
end

-- полоса материала по ломаной (тропинки), ширина w, поверхность на высоте y
function T.trail(points, y, w, mat)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local mid = Vector3.new((a.X + b.X) / 2, y - 1, (a.Z + b.Z) / 2)
		terrain:FillBlock(CFrame.lookAt(mid, mid + flat), Vector3.new(w, 2, flat.Magnitude + w * 0.5), mat)
		terrain:FillCylinder(CFrame.new(b.X, y - 1, b.Z), 2, w / 2, mat)
	end
end

-- пруд с водой: чаша глубиной depth, вода чуть ниже поверхности y
function T.pond(x, z, y, r, depth, bed)
	terrain:FillCylinder(CFrame.new(x, y + 1, z), 6, r, M.Air)
	terrain:FillCylinder(CFrame.new(x, y - depth - 1, z), 2, r + 2, bed or M.Mud)
	terrain:FillCylinder(CFrame.new(x, y - depth / 2 - 0.4, z), depth - 0.8, r, M.Water)
end

-- подъём из нижней зоны в верхнюю: клин от z = zb + len (уровень low) до zb (уровень high)
function T.ramp(zb, low, high, w, len, mat)
	local h = high - low
	terrain:FillWedge(CFrame.new(0, low + h / 2, zb + len / 2) * CFrame.Angles(0, math.pi, 0), Vector3.new(w, h, len), mat)
	-- подложка под клином, чтобы не было щели
	terrain:FillBlock(CFrame.new(0, low - 1, zb + len / 2), Vector3.new(w, 2, len), mat)
end

---------------------------------------------------------------------------
local ZONE_GROUND = {
	Mushroom = { top = M.LeafyGrass, ridge = M.Rock, cap = M.Grass },
	Swamp = { top = M.Mud, ridge = M.Ground, cap = M.Grass },
	Crystal = { top = M.Slate, ridge = M.Slate, cap = M.Rock },
	Junkyard = { top = M.Ground, ridge = M.Rock, cap = M.Ground },
	Crater = { top = M.Basalt, ridge = M.Basalt, cap = M.Rock },
}
T.ZONE_GROUND = ZONE_GROUND

local function setupLook()
	terrain.WaterColor = Color3.fromRGB(38, 150, 135)
	terrain.WaterTransparency = 0.35
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	terrain.WaterReflectance = 0.6
	terrain.Decoration = true -- колышущаяся трава на Grass
	local function col(mat, r, g, b) terrain:SetMaterialColor(mat, Color3.fromRGB(r, g, b)) end
	col(M.Grass, 96, 170, 84)
	col(M.LeafyGrass, 120, 150, 90)
	col(M.Sand, 222, 206, 160)
	col(M.Mud, 70, 84, 52)
	col(M.Ground, 112, 94, 72)
	col(M.Rock, 118, 116, 112)
	col(M.Slate, 88, 96, 118)
	col(M.Basalt, 52, 50, 56)
	col(M.CrackedLava, 120, 200, 60)
	col(M.Asphalt, 70, 70, 74)
	col(M.Concrete, 150, 150, 148)
	col(M.Cobblestone, 140, 136, 128)
end

local function oceanAndIsland()
	local sea = D.SEA
	-- морское дно и вода
	T.block(-1000, 1000, -26, -20, -1700, 800, M.Sand)
	T.block(-1000, 1000, -20, sea, -1700, 800, M.Water)
	-- пляжи (на 24 стада шире суши) и сама суша
	for _, r in ipairs(D.Island) do
		T.block(r[1] - 24, r[2] + 24, -24, -1, r[3] - 24, r[4] + 24, M.Sand)
	end
	-- неровный берег: плоские песчаные языки вдоль кромки (только там, где кромка выходит к морю)
	local rng = Rng.new(77)
	local function onLand(x, z)
		for _, r in ipairs(D.Island) do
			if x > r[1] - 20 and x < r[2] + 20 and z > r[3] - 20 and z < r[4] + 20 then return true end
		end
		return false
	end
	for _, r in ipairs(D.Island) do
		local x0, x1, z0, z1 = r[1] - 24, r[2] + 24, r[3] - 24, r[4] + 24
		local perim = {}
		for x = x0, x1, 30 do
			table.insert(perim, { x, z0, 0, -1 })
			table.insert(perim, { x, z1, 0, 1 })
		end
		for z = z0, z1, 30 do
			table.insert(perim, { x0, z, -1, 0 })
			table.insert(perim, { x1, z, 1, 0 })
		end
		for _, p in ipairs(perim) do
			local out = rng:range(-4, 10)
			local x, z = p[1] + p[3] * out + rng:range(-8, 8), p[2] + p[4] * out + rng:range(-8, 8)
			-- язык песка, если он не залезает на соседнюю сушу
			if not onLand(x + p[3] * 30, z + p[4] * 30) then
				T.cyl(x, z, -12, -1.6, rng:range(9, 18), M.Sand)
			end
		end
	end
	-- трава центрального острова
	local hub = D.Island[1]
	T.block(hub[1], hub[2], -24, 0, hub[3], hub[4], M.Grass)
	-- перешеек от площади к первой зоне
	local cor = D.Island[2]
	T.block(cor[1], cor[2], -24, 0, D.Zones[1].z0, cor[4], M.Grass)
end

local function zoneGround()
	local cor = D.Island[2]
	for i, z in ipairs(D.Zones) do
		local g = ZONE_GROUND[z.id]
		local z1 = z.z1
		if i == #D.Zones then z1 = cor[3] end
		T.block(cor[1], cor[2], -24, z.level, z.z0, z1, g.top)
		-- скальные обрывы к морю по краям коридора
		T.block(cor[1], cor[1] + 14, -24, z.level, z.z0, z1, M.Rock)
		T.block(cor[2] - 14, cor[2], -24, z.level, z.z0, z1, M.Rock)
	end
	-- подъёмы между зонами
	for i = 2, #D.Zones do
		local a, b = D.Zones[i - 1], D.Zones[i]
		T.ramp(b.z0, a.level, b.level, 26, 30, ZONE_GROUND[a.id].top)
	end
end

local function river()
	local r = D.River
	local x0, x1 = r.x - r.width / 2, r.x + r.width / 2
	local zt0, zt1 = r.zTurn - r.width / 2, r.zTurn + r.width / 2
	local hub = D.Island[1]
	-- русло на юг до моря и на восток до моря
	local function channel(ax0, ax1, az0, az1)
		T.block(ax0, ax1, -6, 6, az0, az1, M.Air)
		T.block(ax0 - 2, ax1 + 2, -12, -6, az0, az1, M.Sand)
		T.block(ax0, ax1, -6, D.SEA, az0, az1, M.Water)
	end
	channel(x0, x1, zt0, hub[4] + 30)
	channel(x0, hub[2] + 30, zt0, zt1)
	-- пологие берега
	for z = zt0, hub[4], 20 do
		T.ball(x0 - 4, -6, z, 5, M.Sand)
		T.ball(x1 + 4, -6, z, 5, M.Sand)
	end
end

local function hills()
	local rng = Rng.new(11)
	local spots = { { -300, -75 }, { -305, 105 }, { -95, 295 }, { 95, 295 }, { 330, 210 }, { 390, -40 }, { 260, 280 } }
	for _, s in ipairs(spots) do
		local r = rng:range(18, 26)
		T.ball(s[1], -r * 0.7, s[2], r, M.Grass)
		T.ball(s[1] + rng:range(-8, 8), -r * 0.6, s[2] + rng:range(-8, 8), r * 0.6, M.Rock)
		T.ball(s[1], -r * 0.7 + 1, s[2], r, M.Grass)
	end
end

-- хребты по бокам коридора зон, в конце коридора и по южной кромке первой зоны
local function ridges()
	local rng = Rng.new(2024)
	local cor = D.Island[2]
	local function ridgeBall(x, z, rmin, rmax, lift)
		local level = D.levelAt(z)
		local zone = D.Zones[1]
		for _, zz in ipairs(D.Zones) do
			if z <= zz.z0 and z > zz.z1 then zone = zz end
		end
		if z <= D.Zones[#D.Zones].z1 then zone = D.Zones[#D.Zones] end
		local g = ZONE_GROUND[zone.id]
		local r = rng:range(rmin, rmax)
		local y = level + rng:range(0, 8) + (lift or 0)
		T.ball(x, y, z, r, g.ridge)
		if rng:chance(0.6) then
			T.ball(x + rng:range(-6, 6), y + r * 0.55, z + rng:range(-6, 6), r * 0.55, g.cap)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		local z = D.Zones[1].z0 + 6
		while z > cor[3] + 10 do
			local crystal = z <= D.ZoneById.Crystal.z0 and z > D.ZoneById.Crystal.z1
			ridgeBall(side * rng:range(136, 150), z, crystal and 26 or 20, crystal and 36 or 30, crystal and 12 or 0)
			z = z - rng:range(18, 26)
		end
		-- южная кромка первой зоны, проход посередине
		local x = 44
		while x < 160 do
			ridgeBall(side * x, D.Zones[1].z0 + rng:range(-4, 4), 16, 22)
			x = x + rng:range(16, 22)
		end
	end
	-- северный край
	local x = -150
	while x <= 150 do
		ridgeBall(x, cor[3] + 14 + rng:range(-6, 6), 24, 34, 6)
		x = x + rng:range(18, 24)
	end
end

function T.build()
	setupLook()
	oceanAndIsland()
	zoneGround()
	river()
	hills()
	ridges()
end

return T
