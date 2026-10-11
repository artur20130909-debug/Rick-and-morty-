-- Остров босса: мост через реку и колизей. Внутри — площадка призыва мирового босса,
-- светящееся кольцо рун, жаровни, гигантские кости; снаружи — трибуны и табло с таймером.
local RS = game:GetService("ReplicatedStorage")
local B = require(RS.Shared.Build)
local D = require(RS.Shared.MapData)
local Rng = require(RS.Shared.Rng)
local P = require(script.Parent.Props)

local Arena = {}
local C, rgb = P.C, P.rgb
local M = Enum.Material

local RED = rgb(255, 70, 60)
local STONE = rgb(150, 140, 128)
local STONE_DARK = rgb(112, 104, 96)

local function bridge(m)
	local g = B.model(m, "Bridge")
	local r = D.River
	local x0, x1 = r.x - r.width / 2 - 10, r.x + r.width / 2 + 10
	local n = 8
	local prev
	for i = 0, n do
		local t = i / n
		local x = x0 + (x1 - x0) * t
		local y = 0.4 + math.sin(t * math.pi) * 2.4
		local p = Vector3.new(x, y, 0)
		if prev then
			local mid = (prev + p) / 2
			local len = (p - prev).Magnitude
			B.part(g, "Deck", Vector3.new(len + 0.3, 1, 16), CFrame.lookAt(mid, p) * CFrame.Angles(0, math.rad(90), 0),
				C.wood, M.WoodPlanks)
			for _, z in ipairs({ -8.4, 8.4 }) do
				B.part(g, "Rail", Vector3.new(len + 0.3, 0.6, 0.6), CFrame.lookAt(mid + Vector3.new(0, 3.2, z), p + Vector3.new(0, 3.2, z)) * CFrame.Angles(0, math.rad(90), 0),
					STONE, M.Slate)
			end
		end
		for _, z in ipairs({ -8.4, 8.4 }) do
			B.part(g, "Baluster", Vector3.new(1, 3.4, 1), CFrame.new(p + Vector3.new(0, 1.7, z)), STONE_DARK, M.Slate)
		end
		prev = p
	end
	-- опоры в воде и фонари на концах
	for _, x in ipairs({ r.x - 6, r.x + 6 }) do
		B.part(g, "Pier", Vector3.new(3, 8, 14), CFrame.new(x, -3, 0), STONE_DARK, M.Slate)
	end
	for _, x in ipairs({ x0, x1 }) do
		for _, z in ipairs({ -8.4, 8.4 }) do
			P.lamp(g, Vector3.new(x, 0, z), RED, 9)
		end
	end
	return g
end

local function brazier(m, pos)
	local g = B.model(m, "Brazier")
	B.vcyl(g, "Stand", 4, 1.4, CFrame.new(pos + Vector3.new(0, 2, 0)), C.metalDark, M.Metal)
	B.vcyl(g, "Bowl", 1.4, 4, CFrame.new(pos + Vector3.new(0, 4.6, 0)), rgb(60, 50, 44), M.Metal)
	local coals = B.vcyl(g, "Coals", 0.3, 3.4, CFrame.new(pos + Vector3.new(0, 5.35, 0)), rgb(255, 120, 40), M.Neon)
	local f = Instance.new("Fire")
	f.Heat = 8
	f.Size = 4
	f.Color = rgb(255, 140, 50)
	f.SecondaryColor = rgb(255, 60, 30)
	f.Parent = coals
	B.light(coals, "PointLight", { Range = 22, Brightness = 2, Color = rgb(255, 140, 70) })
	return g
end

local function bone(m, a, b, d)
	local g = B.model(m, "Bone")
	B.between(g, "Shaft", a, b, d, rgb(235, 228, 205), M.SmoothPlastic, true)
	local dir = (b - a).Unit
	local side = dir:Cross(Vector3.yAxis).Unit
	for _, p in ipairs({ a, b }) do
		B.ball(g, "Knob", d * 1.5, CFrame.new(p + side * d * 0.5), rgb(235, 228, 205), M.SmoothPlastic)
		B.ball(g, "Knob", d * 1.5, CFrame.new(p - side * d * 0.5), rgb(235, 228, 205), M.SmoothPlastic)
	end
	return g
end

function Arena.build(root)
	local m = B.model(root, "BossArena")
	local c = D.Boss.center
	local R = D.Boss.radius
	local function at(deg, r, y) local d = P.compass(deg) * r return Vector3.new(c.X + d.X, y, c.Z + d.Z) end
	local entrance = 270 -- запад, к мосту
	local function nearEntrance(a)
		-- угол кольца B.ring отсчитывается против часовой (90° — запад)
		return math.abs(a - 90) < 12
	end

	bridge(m)
	P.path(m, Vector3.new(D.River.x + D.River.width / 2 + 10, 0.3, 0), Vector3.new(c.X - R - 6, 0.3, 0), 16)

	-- пол
	B.vcyl(m, "Floor", 1.2, R * 2 + 4, CFrame.new(c.X, 0.6, c.Z), STONE, M.Cobblestone)
	B.vcyl(m, "BattleFloor", 1.3, 70, CFrame.new(c.X, 0.65, c.Z), rgb(96, 88, 84), M.Slate)
	B.ring(m, "RuneRing", CFrame.new(c.X, 1.33, c.Z), 33, 48, 0.1, 1.1, RED, M.Neon)
	B.ring(m, "RuneRing", CFrame.new(c.X, 1.33, c.Z), 22, 36, 0.1, 0.6, RED, M.Neon)
	for i = 0, 5 do
		local a = i * 60
		local p0, p1 = at(a, 22, 1.34), at(a, 33, 1.34)
		B.part(m, "RuneLine", Vector3.new(0.6, 0.1, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), RED, M.Neon)
	end
	-- площадка призыва
	B.vcyl(m, "SummonBase", 1.6, 18, CFrame.new(c.X, 1.6, c.Z), rgb(60, 54, 56), M.Basalt)
	local core = B.vcyl(m, "SummonCore", 0.3, 10, CFrame.new(c.X, 2.5, c.Z), RED, M.Neon)
	B.light(core, "PointLight", { Range = 30, Brightness = 2, Color = RED })
	B.tag(core, "Pulse", { Speed = 1.2 })
	local spawnMk = B.marker(m, "BossSpawn", Vector3.new(6, 6, 6), CFrame.new(c.X, 6, c.Z))
	B.attrs(spawnMk, { Role = "BossSpawn" })
	local zoneMk = B.marker(m, "BossZone", Vector3.new(R * 2, 40, R * 2), CFrame.new(c.X, 20, c.Z))
	B.attrs(zoneMk, { Role = "BossZone" })

	-- стена с колоннами и жаровнями
	B.ring(m, "Wall", CFrame.new(c.X, 6, c.Z), R + 2, 64, 12, 3, STONE_DARK, M.Slate, nearEntrance)
	B.ring(m, "WallCap", CFrame.new(c.X, 12.4, c.Z), R + 2, 64, 0.8, 3.6, STONE, M.Slate, nearEntrance)
	for a = 0, 345, 15 do
		if math.abs(a - entrance) > 14 then
			local p = at(a, R + 2, 0)
			B.part(m, "Column", Vector3.new(4, 16, 4), CFrame.new(p + Vector3.new(0, 8, 0)), STONE, M.Slate)
			if a % 30 == 0 then
				brazier(m, p + Vector3.new(0, 16, 0) - Vector3.new(0, 4, 0))
			else
				B.part(m, "Banner", Vector3.new(3, 7, 0.3), P.facing(p + Vector3.new(0, 10, 0), c) * CFrame.new(0, 0, -2.2), rgb(160, 30, 30), M.Fabric)
			end
		end
	end
	-- трибуны снаружи стены (по ним можно подняться прыжками)
	for k, r in ipairs({ R + 6, R + 10, R + 14 }) do
		B.ring(m, "Stands", CFrame.new(c.X, k * 1.5, c.Z), r, 72, k * 3, 4, k % 2 == 0 and STONE or STONE_DARK, M.Slate, nearEntrance)
	end
	B.ring(m, "BackWall", CFrame.new(c.X, 7.5, c.Z), R + 17, 80, 15, 2, STONE_DARK, M.Slate, nearEntrance)

	-- вход: арка с табло
	local gate = at(entrance, R + 4, 0)
	local arch = P.arch(m, P.facing(gate, c), 22, 20, rgb(80, 70, 70), RED, "АРЕНА БОССА", "Босс появится через 60:00", M.Slate)
	local board = arch:FindFirstChild("Beam")
	if board then board.Name = "TimerBoard" end
	-- жаровни внутри и кости
	for i = 0, 7 do
		brazier(m, at(i * 45 + 22.5, R - 6, 1.2))
	end
	local rng = Rng.new(99)
	for _ = 1, 3 do
		local a, r = rng:angle(), rng:range(38, 46)
		local p = Vector3.new(c.X + math.cos(a) * r, 2.2, c.Z + math.sin(a) * r)
		local yaw = rng:angle()
		local half = Vector3.new(math.cos(yaw), 0, math.sin(yaw)) * rng:range(4, 6)
		bone(m, p - half, p + half, rng:range(1.4, 2))
	end
	-- деревья и камни на острове
	local deco = B.model(m, "Decor")
	local spots = { { 380, 140 }, { 250, 150 }, { 400, 60 }, { 360, -80 }, { 260, -80 }, { 300, 240 }, { 380, 260 } }
	for _, s in ipairs(spots) do
		P.tree(deco, Vector3.new(s[1], 0, s[2]), rng, rng:range(1, 1.3), P.TreePalettes[rng:int(1, 3)])
	end
	for _ = 1, 6 do
		P.rock(deco, Vector3.new(rng:range(240, 400), 0, rng:range(90, 300)), rng:range(3, 6), rng)
	end
	return m
end

return Arena
