-- Зона 5. Радиоактивный кратер: воронка от метеорита со светящимся озером и самим метеоритом,
-- трещины лавы, бочки с отходами, ядовитые лужи, паровые гейзеры, обугленные деревья,
-- предупреждающие знаки и заброшенная станция наблюдения.
local RS = game:GetService("ReplicatedStorage")
local B = require(RS.Shared.Build)
local P = require(script.Parent.Parent.Props)
local T = require(script.Parent.Parent.Terrain)

local Z = {}
local C, rgb = P.C, P.rgb
local M = Enum.Material

local GREEN = rgb(170, 255, 40)
local TOXIC_CRYSTALS = { rgb(170, 255, 40), rgb(120, 255, 120), rgb(220, 255, 90) }

local function warningSign(m, cf)
	local g = B.model(m, "WarningSign")
	B.part(g, "Post", Vector3.new(0.5, 6, 0.5), cf * CFrame.new(0, 3, 0), C.metal, M.Metal)
	local board = B.part(g, "Board", Vector3.new(5, 4, 0.3), cf * CFrame.new(0, 6.5, 0) * CFrame.Angles(0, 0, math.rad(45)), C.warning, M.SmoothPlastic)
	local gui = P.board(board, Enum.NormalId.Front, "☢", nil, Color3.new(0, 0, 0))
	local label = gui:FindFirstChildWhichIsA("Frame"):FindFirstChild("Title")
	label.Rotation = -45
	label.TextStrokeTransparency = 1
	P.board(board, Enum.NormalId.Back, "ОПАСНО", nil, Color3.new(0, 0, 0))
	return g
end

local function toxicPool(m, pos, r)
	local goo = B.vcyl(m, "ToxicPool", 0.4, r * 2, CFrame.new(pos + Vector3.new(0, 0.12, 0)), GREEN, M.Neon, { CanCollide = false })
	B.light(goo, "PointLight", { Range = r * 2 + 8, Brightness = 1.5, Color = GREEN })
	B.particles(goo, {
		Color = ColorSequence.new(rgb(210, 255, 150)), Size = NumberSequence.new(0.8, 0.2), Transparency = NumberSequence.new(0.3, 1),
		Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(1, 2.5), Rate = 4, EmissionDirection = Enum.NormalId.Top,
	})
	return goo
end

local function vent(m, rng, pos)
	local g = B.model(m, "SteamVent")
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2
		P.rock(g, pos + Vector3.new(math.cos(a) * 2.6, 0, math.sin(a) * 2.6), rng:range(1.4, 2.2), rng, rgb(60, 58, 62), M.Basalt)
	end
	local core = B.vcyl(g, "Hole", 0.3, 3, CFrame.new(pos + Vector3.new(0, 0.1, 0)), GREEN, M.Neon, { CanCollide = false })
	B.particles(core, {
		Color = ColorSequence.new(rgb(220, 255, 200), rgb(255, 255, 255)), Size = NumberSequence.new(2, 9),
		Transparency = NumberSequence.new(0.4, 1), Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(8, 14),
		SpreadAngle = Vector2.new(8, 8), Rate = 10, LightEmission = 0.2, Drag = 0.6, EmissionDirection = Enum.NormalId.Top,
		RotSpeed = NumberRange.new(-30, 30), Rotation = NumberRange.new(0, 360),
	})
	return g
end

local function outpost(m, rng, pos, yaw)
	local g = B.model(m, "Outpost")
	local o = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local w, d, h = 18, 14, 8
	local function pt(x, z) return o * Vector3.new(x, 0, z) end
	local col = rgb(150, 154, 150)
	B.part(g, "Slab", Vector3.new(w + 4, 0.6, d + 4), o * CFrame.new(0, 0.3, 0), C.concrete, M.Concrete)
	B.wall(g, "Front", pt(-w / 2, -d / 2), pt(w / 2, -d / 2), h, 1.2, col, M.Concrete, { { at = w / 2, w = 4, y0 = 0.6, y1 = 6 }, { at = 3.5, w = 3, y0 = 3.5, y1 = 5.5 } })
	B.wall(g, "Back", pt(w / 2, d / 2), pt(-w / 2, d / 2), h, 1.2, col, M.Concrete)
	B.wall(g, "Left", pt(-w / 2, d / 2), pt(-w / 2, -d / 2), h, 1.2, col, M.Concrete)
	B.wall(g, "Right", pt(w / 2, -d / 2), pt(w / 2, d / 2), h, 1.2, col, M.Concrete, { { at = d / 2, w = 3, y0 = 3.5, y1 = 5.5 } })
	B.part(g, "Roof", Vector3.new(w + 1.5, 1, d + 1.5), o * CFrame.new(0, h + 0.5, 0), rgb(120, 124, 120), M.Concrete)
	B.part(g, "Stripe", Vector3.new(w + 0.1, 1, 0.2), o * CFrame.new(0, h - 1, -d / 2 - 0.55), C.warning, M.SmoothPlastic)
	-- вращающийся радар
	local radar = B.model(g, "Radar")
	local rc = o * CFrame.new(4, h + 1, 3)
	B.vcyl(g, "RadarPole", 3, 0.8, rc * CFrame.new(0, 1.5, 0), C.metal, M.Metal)
	B.part(radar, "Dish", Vector3.new(7, 2.4, 0.4), rc * CFrame.new(0, 3.6, 0) * CFrame.Angles(math.rad(-15), 0, 0), C.metalLight, M.Metal)
	B.part(radar, "Arm", Vector3.new(0.4, 0.4, 2), rc * CFrame.new(0, 3.6, -0.9), C.metal, M.Metal)
	radar.WorldPivot = rc * CFrame.new(0, 3.6, 0)
	B.tag(radar, "Spin", { Speed = 60 })
	local lamp = B.ball(g, "Beacon", 0.8, o * CFrame.new(-6, h + 1.4, -4), rgb(255, 60, 40), M.Neon)
	B.light(lamp, "PointLight", { Range = 12, Color = rgb(255, 60, 40) })
	B.tag(lamp, "Pulse", { Speed = 2 })
	-- мешки с песком
	for i = -3, 3 do
		B.ellipsoid(g, "Sandbag", Vector3.new(2.4, 1, 1.4), o * CFrame.new(i * 2.3 + rng:range(-0.2, 0.2), 0.9, -d / 2 - 4) * CFrame.Angles(0, rng:range(-0.2, 0.2), 0),
			rgb(170, 150, 110), M.Fabric)
	end
	local sign = B.part(g, "Sign", Vector3.new(10, 2, 0.3), o * CFrame.new(0, h - 2.8, -d / 2 - 0.75), rgb(30, 34, 30), M.SmoothPlastic)
	P.board(sign, Enum.NormalId.Front, "СТАНЦИЯ НАБЛЮДЕНИЯ", nil, GREEN, rgb(30, 34, 30))
	return g
end

local function meteor(m, rng, pos)
	local g = B.model(m, "Meteor")
	B.ball(g, "Rock", 16, CFrame.new(pos), rgb(56, 46, 46), M.CrackedLava)
	for _ = 1, 6 do
		local dir = Vector3.new(rng:range(-1, 1), rng:range(0.2, 1), rng:range(-1, 1)).Unit
		P.crystal(g, pos + dir * 6.5, dir, rng:range(4, 8), rng:range(1.4, 2.2), rng:pick(TOXIC_CRYSTALS))
	end
	local glow = B.marker(g, "Glow", Vector3.new(1, 1, 1), CFrame.new(pos + Vector3.new(0, 10, 0)))
	B.light(glow, "PointLight", { Range = 60, Brightness = 3, Color = GREEN })
	B.billboard(glow, "МЕТЕОРИТ", rgb(210, 255, 120), 6, UDim2.fromOffset(240, 50), 200)
	-- обломки парят вокруг
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		local frag = B.part(g, "Fragment", Vector3.new(rng:range(1.5, 3), rng:range(1.5, 3), rng:range(1.5, 3)),
			CFrame.new(pos + Vector3.new(math.cos(a) * 13, rng:range(4, 10), math.sin(a) * 13)) * CFrame.Angles(rng:angle(), rng:angle(), 0),
			rgb(70, 60, 60), M.Basalt, { CanCollide = false })
		B.tag(frag, "Bob", { Height = rng:range(0.8, 1.6), Period = rng:range(3, 5) })
	end
	-- дым над воронкой
	local smoke = B.marker(g, "Smoke", Vector3.new(20, 1, 20), CFrame.new(pos + Vector3.new(0, 4, 0)))
	B.particles(smoke, {
		Color = ColorSequence.new(rgb(190, 240, 140), rgb(120, 130, 120)), Size = NumberSequence.new(6, 18),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.75), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(3, 5), Rate = 3, LightEmission = 0.3, Drag = 0.3,
		RotSpeed = NumberRange.new(-10, 10), Rotation = NumberRange.new(0, 360), EmissionDirection = Enum.NormalId.Top,
	})
	return g
end

function Z.build(ctx)
	local m, rng, occ, L = ctx.model, ctx.rng, ctx.occ, ctx.L
	local zone = ctx.zone
	local deco = B.model(m, "Decor")

	for _ = 1, 12 do
		T.patch(rng:range(ctx.x0, ctx.x1), rng:range(zone.z1, zone.z0), L, rng:range(5, 11), M.CrackedLava)
	end
	for _ = 1, 8 do
		T.patch(rng:range(ctx.x0, ctx.x1), rng:range(zone.z1, zone.z0), L, rng:range(8, 14), M.Rock)
	end

	-- воронка: вал из базальта, потом вырезаем шар
	local cz = (zone.z0 + zone.z1) / 2 - 8
	local CR, CH = 55, 30 -- радиус шара и высота его центра над землёй
	for i = 0, 27 do
		local a = i / 28 * math.pi * 2
		T.ball(math.cos(a) * 49, L - 2, cz + math.sin(a) * 49, rng:range(8, 11), M.Basalt)
	end
	T.ball(0, L + CH, cz, CR, M.Air)
	local bottom = L + CH - CR
	-- светящееся озеро на дне и метеорит
	local lakeY = bottom + 1.6
	local lake = B.vcyl(deco, "CraterLake", 1, 30, CFrame.new(0, lakeY - 0.5, cz), GREEN, M.Neon, { Transparency = 0.05 })
	B.light(lake, "PointLight", { Range = 40, Brightness = 2, Color = GREEN })
	meteor(deco, rng, Vector3.new(0, lakeY + 5, cz))
	occ:add(0, cz, 60)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + 0.2
		local r = 25
		local y = L + CH - math.sqrt(CR * CR - r * r)
		P.crystalCluster(deco, Vector3.new(math.cos(a) * r, y, cz + math.sin(a) * r), rng:range(4, 7), rng, TOXIC_CRYSTALS, i % 2 == 0)
	end
	-- предупреждения по краю воронки
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.5
		local p = Vector3.new(math.cos(a) * 62, L, cz + math.sin(a) * 62)
		warningSign(deco, P.facing(p, Vector3.new(0, L, cz)) * CFrame.Angles(0, math.pi, 0))
	end

	-- станция наблюдения
	do
		local x, z = occ:find(rng, ctx.x0 + 12, ctx.x1 - 12, ctx.z0 - 4, ctx.z1 + 10, 15, 80)
		if x then
			outpost(deco, rng, Vector3.new(x, L, z), x < 0 and math.rad(70) or math.rad(-70))
			occ:add(x, z, 15)
		end
	end
	-- ядовитые лужи, бочки, гейзеры, обугленные деревья, кристаллы
	for _ = 1, 6 do
		local r = rng:range(3, 6)
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, r + 1)
		if x then
			toxicPool(deco, Vector3.new(x, L, z), r)
			occ:add(x, z, r + 1)
		end
	end
	for _ = 1, 9 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 5)
		if x then
			for _ = 1, rng:int(3, 6) do
				local a, r = rng:angle(), rng:range(0, 3)
				local cf = CFrame.new(x + math.cos(a) * r, L, z + math.sin(a) * r)
				if rng:chance(0.3) then
					-- опрокинутая бочка и лужа
					P.barrel(deco, cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, rng:angle(), math.rad(90)) * CFrame.new(0, -2, 0), C.warning, false)
					B.vcyl(deco, "Spill", 0.15, rng:range(3, 5), cf * CFrame.new(rng:range(1, 2), 0.08, 0), GREEN, M.Neon, { CanCollide = false })
				else
					P.barrel(deco, cf, C.warning, true)
				end
			end
			occ:add(x, z, 5)
		end
	end
	for _ = 1, 8 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 5)
		if x then
			vent(deco, rng, Vector3.new(x, L, z))
			occ:add(x, z, 4.5)
		end
	end
	for _ = 1, 10 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 4)
		if x then
			P.deadTree(deco, Vector3.new(x, L, z), rng, rng:range(0.9, 1.3), rgb(34, 30, 30), nil)
			occ:add(x, z, 2.5)
		end
	end
	for _ = 1, 10 do
		local s = rng:range(3, 7)
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, s * 0.5 + 1)
		if x then
			P.crystalCluster(deco, Vector3.new(x, L, z), s, rng, TOXIC_CRYSTALS, rng:chance(0.5))
			occ:add(x, z, s * 0.45 + 1)
		end
	end
	for _ = 1, 8 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 4)
		if x then
			P.rock(deco, Vector3.new(x, L, z), rng:range(3, 6), rng, rgb(60, 58, 62), M.Basalt)
			occ:add(x, z, 3.5)
		end
	end
	-- обломки сетчатого забора
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 5 do
			if rng:chance(0.7) then
				local z = zone.z0 - 30 - k * 24
				local cf = CFrame.new(side * 96, L, z) * CFrame.Angles(0, math.rad(90 + rng:range(-10, 10)), math.rad(rng:range(-12, 12)))
				B.part(deco, "FencePost", Vector3.new(0.4, 7, 0.4), cf * CFrame.new(-4, 3.5, 0), C.metal, M.Metal)
				B.part(deco, "FencePost", Vector3.new(0.4, 7, 0.4), cf * CFrame.new(4, 3.5, 0), C.metal, M.Metal)
				B.part(deco, "FenceMesh", Vector3.new(8, 6, 0.1), cf * CFrame.new(0, 3.6, 0), C.metalLight, M.Metal,
					{ Transparency = 0.6, CastShadow = false })
			end
		end
	end
	for i = 1, 5 do
		P.motes(deco, CFrame.new(rng:range(-50, 50), L + 6, zone.z0 - 25 - (i - 1) * 38), Vector3.new(70, 12, 30), GREEN, 7, "Spores")
	end
	P.signpost(deco, CFrame.new(-16, L, zone.z0 - 14) * CFrame.Angles(0, math.rad(20), 0), "РАДИОАКТИВНЫЙ КРАТЕР", "Осколки метеорита и токсичная слизь", zone.accent, 15, 4)
	occ:add(-16, zone.z0 - 14, 7)
end

return Z
