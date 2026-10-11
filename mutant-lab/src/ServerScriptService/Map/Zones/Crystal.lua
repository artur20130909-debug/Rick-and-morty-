-- Зона 3. Кристальные пещеры: каменные арки и нависающие скалы, гнёзда светящихся кристаллов,
-- огромный парящий кристалл в центре, сталагмиты, подземное озерцо и старая шахта с вагонеткой.
local RS = game:GetService("ReplicatedStorage")
local B = require(RS.Shared.Build)
local P = require(script.Parent.Parent.Props)
local T = require(script.Parent.Parent.Terrain)

local Z = {}
local C, rgb = P.C, P.rgb
local M = Enum.Material

local COLORS = { rgb(80, 230, 255), rgb(255, 90, 220), rgb(160, 100, 255), rgb(190, 240, 255) }
local GOLD = rgb(255, 210, 90)

local function stalagmite(m, pos, s, color)
	local g = B.model(m, "Stalagmite")
	B.vcyl(g, "Base", s * 0.8, s, CFrame.new(pos + Vector3.new(0, s * 0.3, 0)), color, M.Slate)
	B.vcyl(g, "Mid", s * 0.8, s * 0.62, CFrame.new(pos + Vector3.new(0, s * 0.95, 0)), color, M.Slate)
	B.vcyl(g, "Tip", s * 0.7, s * 0.32, CFrame.new(pos + Vector3.new(0, s * 1.6, 0)), color, M.Slate)
	return g
end

local function mineTrack(m, rng, a, b, L)
	local g = B.model(m, "MineTrack")
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	local frame = CFrame.lookAt(Vector3.new(a.X, L, a.Z), Vector3.new(b.X, L, b.Z))
	for _, x in ipairs({ -1.6, 1.6 }) do
		B.part(g, "Rail", Vector3.new(0.3, 0.3, len), frame * CFrame.new(x, 0.45, -len / 2), C.metalLight, M.Metal)
	end
	for k = 0, math.floor(len / 2.2) do
		B.part(g, "Sleeper", Vector3.new(4.6, 0.3, 0.8), frame * CFrame.new(0, 0.15, -k * 2.2), C.woodDark, M.Wood)
	end
	-- крепь с фонарями
	for k = 1, math.floor(len / 26) do
		local f = frame * CFrame.new(0, 0, -k * 26)
		for _, x in ipairs({ -4.5, 4.5 }) do
			B.part(g, "Prop", Vector3.new(0.9, 10, 0.9), f * CFrame.new(x, 5, 0), C.wood, M.Wood)
		end
		B.part(g, "Lintel", Vector3.new(10.4, 0.9, 1), f * CFrame.new(0, 10.2, 0), C.wood, M.Wood)
		B.part(g, "Chain", Vector3.new(0.15, 1.6, 0.15), f * CFrame.new(0, 9, 0), C.metalDark, M.Metal, { CanCollide = false })
		local lamp = B.ball(g, "Lantern", 0.9, f * CFrame.new(0, 7.9, 0), rgb(255, 200, 110), M.Neon, { CanCollide = false })
		B.light(lamp, "PointLight", { Range = 16, Brightness = 1.4, Color = rgb(255, 190, 110) })
	end
	-- вагонетка с кристаллами
	local cf = frame * CFrame.new(0, 0.6, -len * 0.35)
	B.part(g, "CartFloor", Vector3.new(4.4, 0.4, 5.6), cf * CFrame.new(0, 1.2, 0), C.metal, M.CorrodedMetal)
	for _, s in ipairs({ -1, 1 }) do
		B.part(g, "CartSide", Vector3.new(0.4, 2.6, 5.6), cf * CFrame.new(s * 2.2, 2.5, 0), C.metal, M.CorrodedMetal)
		B.part(g, "CartEnd", Vector3.new(4.4, 2.6, 0.4), cf * CFrame.new(0, 2.5, s * 2.8), C.metal, M.CorrodedMetal)
		for _, z in ipairs({ -1.8, 1.8 }) do
			B.cyl(g, "Wheel", 0.5, 1.6, cf * CFrame.new(s * 1.9, 0.6, z), C.metalDark, M.Metal)
		end
	end
	for _ = 1, 4 do
		P.crystal(g, (cf * CFrame.new(rng:range(-1.2, 1.2), 1.4, rng:range(-1.8, 1.8))).Position,
			Vector3.new(rng:range(-0.4, 0.4), 1, rng:range(-0.4, 0.4)), rng:range(2, 3.4), 0.8, rng:pick(COLORS))
	end
	-- вход в штольню у конца путей
	local e = frame * CFrame.new(0, 0, -len - 2)
	for _, x in ipairs({ -5, 5 }) do
		B.part(g, "PortalPost", Vector3.new(1.2, 11, 1.2), e * CFrame.new(x, 5.5, 0), C.woodDark, M.Wood)
	end
	B.part(g, "PortalBeam", Vector3.new(12, 1.4, 1.4), e * CFrame.new(0, 11.2, 0), C.woodDark, M.Wood)
	B.part(g, "Darkness", Vector3.new(9, 10.4, 1), e * CFrame.new(0, 5.2, -1.2), Color3.new(0, 0, 0), M.SmoothPlastic)
	local sign = B.part(g, "MineSign", Vector3.new(7, 1.6, 0.3), e * CFrame.new(0, 12.8, 0.4), C.wood, M.WoodPlanks)
	P.board(sign, Enum.NormalId.Back, "ШАХТА №3", nil, rgb(255, 220, 160))
	return g
end

local function giantCrystal(m, center)
	local g = B.model(m, "GiantCrystal")
	local mid = center + Vector3.new(0, 16, 0)
	P.crystal(g, mid, Vector3.yAxis, 9, 5, COLORS[1])
	P.crystal(g, mid, -Vector3.yAxis, 7, 5, COLORS[1])
	local glow = B.marker(g, "Glow", Vector3.new(1, 1, 1), CFrame.new(mid))
	B.light(glow, "PointLight", { Range = 50, Brightness = 3, Color = COLORS[1] })
	g.WorldPivot = CFrame.new(mid)
	B.tag(g, "Spin", { Speed = 14 })
	B.tag(g, "Bob", { Height = 1.4, Period = 6 })
	B.billboard(glow, "СЕРДЦЕ ПЕЩЕР", rgb(190, 245, 255), 14, UDim2.fromOffset(300, 50), 160)
	return g
end

function Z.build(ctx)
	local m, rng, occ, L = ctx.model, ctx.rng, ctx.occ, ctx.L
	local zone = ctx.zone
	local deco = B.model(m, "Decor")

	-- рельеф: пятна камня, арки, нависающие скалы, колонны
	for _ = 1, 14 do
		T.patch(rng:range(ctx.x0, ctx.x1), rng:range(zone.z1, zone.z0), L, rng:range(8, 16), M.Rock)
	end
	for _, zc in ipairs({ zone.z0 - 45, zone.z0 - 105, zone.z0 - 160 }) do
		for k = 0, 18 do
			local t = k / 18 * math.pi
			T.ball(-128 * math.cos(t), L + 4 + 48 * math.sin(t), zc + rng:range(-3, 3), rng:range(8, 10), k % 3 == 0 and M.Rock or M.Slate)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		for z = zone.z0 - 12, zone.z1 + 12, -26 do
			T.ball(side * rng:range(108, 116), L + rng:range(30, 38), z, rng:range(14, 18), M.Slate)
		end
	end
	for _ = 1, 3 do
		local x, z = occ:find(rng, ctx.x0 + 20, ctx.x1 - 20, ctx.z0 - 10, ctx.z1 + 10, 12)
		if x then
			local r = rng:range(5, 7.5)
			T.cyl(x, z, L - 2, L + 52, r, M.Rock)
			T.ball(x, L + 1, z, r + 3, M.Slate)
			occ:add(x, z, r + 4)
		end
	end

	-- парящий кристалл в центре
	local cz = (zone.z0 + zone.z1) / 2 + 5
	local center = Vector3.new(0, L, cz)
	giantCrystal(deco, center)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * 11, 0, math.sin(a) * 11)
		if i % 2 == 0 then
			P.crystalCluster(deco, p, rng:range(4, 6), rng, { COLORS[1], COLORS[4] }, false)
		else
			P.rock(deco, p, rng:range(3, 5), rng, rgb(90, 98, 124), M.Slate)
		end
	end
	occ:add(0, cz, 16)

	-- шахта вдоль западного склона
	local ta, tb = Vector3.new(-84, L, zone.z0 - 22), Vector3.new(-74, L, zone.z1 + 46)
	mineTrack(deco, rng, ta, tb, L)
	occ:addLine(ta, tb, 6)

	-- озерцо
	do
		local x, z = occ:find(rng, 20, ctx.x1, ctx.z0, ctx.z1, 16)
		if x then
			T.pond(x, z, L, 12, 3, M.Slate)
			for i = 0, 4 do
				local a = i / 5 * math.pi * 2 + 0.3
				P.crystalCluster(deco, Vector3.new(x + math.cos(a) * 14, L, z + math.sin(a) * 14), rng:range(3, 5), rng, { COLORS[4], COLORS[1] }, i == 0)
			end
			occ:add(x, z, 17)
		end
	end

	-- гнёзда кристаллов
	for i = 1, 26 do
		local s = rng:range(4, 11)
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, s * 0.5 + 1)
		if x then
			local cols = i % 9 == 0 and { GOLD } or COLORS
			P.crystalCluster(deco, Vector3.new(x, L, z), s, rng, cols, i % 2 == 0)
			occ:add(x, z, s * 0.45 + 1)
		end
	end
	for _ = 1, 22 do
		local s = rng:range(2.5, 6)
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, s * 0.6)
		if x then
			stalagmite(deco, Vector3.new(x, L, z), s, rng:pick({ rgb(96, 104, 128), rgb(110, 112, 130), rgb(84, 90, 112) }))
			occ:add(x, z, s * 0.55)
		end
	end
	-- светящиеся голубые грибочки
	for _ = 1, 12 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 3)
		if x then
			local g = B.model(deco, "GlowShrooms")
			for _ = 1, rng:int(3, 6) do
				local a, r = rng:angle(), rng:range(0, 2)
				local p = Vector3.new(x + math.cos(a) * r, L, z + math.sin(a) * r)
				local h = rng:range(0.8, 2)
				B.vcyl(g, "Stem", h, 0.35, CFrame.new(p + Vector3.new(0, h / 2, 0)), rgb(200, 230, 240), M.SmoothPlastic, { CanCollide = false })
				B.ellipsoid(g, "Cap", Vector3.new(1.6, 0.7, 1.6), CFrame.new(p + Vector3.new(0, h, 0)), rgb(90, 200, 255), M.Neon, { CanCollide = false })
			end
			occ:add(x, z, 2.5)
		end
	end
	for i = 1, 5 do
		P.motes(deco, CFrame.new(rng:range(-50, 50), L + 8, zone.z0 - 25 - (i - 1) * 38), Vector3.new(70, 14, 30), rng:pick(COLORS), 6, "Sparkles")
	end
	P.signpost(deco, CFrame.new(-16, L, zone.z0 - 14) * CFrame.Angles(0, math.rad(20), 0), "КРИСТАЛЬНЫЕ ПЕЩЕРЫ", "Кристаллы и пещерная роса", zone.accent, 14, 4)
	occ:add(-16, zone.z0 - 14, 7)
end

return Z
