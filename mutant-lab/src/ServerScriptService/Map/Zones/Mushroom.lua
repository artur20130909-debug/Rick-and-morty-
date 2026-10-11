-- Зона 1. Грибной лес: гигантские грибы (на шляпки можно запрыгнуть), тропа, поваленные
-- брёвна, россыпи маленьких грибов, кольцо фей и светлячки.
local RS = game:GetService("ReplicatedStorage")
local B = require(RS.Shared.Build)
local P = require(script.Parent.Parent.Props)
local T = require(script.Parent.Parent.Terrain)

local Z = {}
local rgb = P.rgb
local M = Enum.Material

local CAPS = {
	{ cap = rgb(220, 60, 60), gill = rgb(240, 210, 190), spot = rgb(255, 255, 255), glow = false },
	{ cap = rgb(150, 80, 230), gill = rgb(210, 180, 250), spot = rgb(255, 170, 255), glow = true },
	{ cap = rgb(40, 190, 170), gill = rgb(170, 240, 225), spot = rgb(200, 255, 240), glow = true },
	{ cap = rgb(240, 140, 40), gill = rgb(250, 220, 170), spot = rgb(255, 240, 200), glow = false },
	{ cap = rgb(70, 110, 240), gill = rgb(180, 200, 255), spot = rgb(150, 230, 255), glow = true },
}
local STEMS = { rgb(238, 228, 205), rgb(225, 215, 235), rgb(215, 232, 222) }

local function giantMushroom(m, rng, pos, h, style)
	local g = B.model(m, "GiantMushroom")
	local d = 2.4 + h * 0.13
	local lean = Vector3.new(rng:range(-2, 2), 0, rng:range(-2, 2))
	local top = pos + Vector3.new(0, h, 0) + lean
	local stemCol = rng:pick(STEMS)
	B.between(g, "Stem", pos - Vector3.new(0, 1, 0), top, d, stemCol, M.SmoothPlastic, true)
	B.ellipsoid(g, "Foot", Vector3.new(d * 1.9, d * 0.9, d * 1.9), CFrame.new(pos), stemCol, M.SmoothPlastic)
	-- юбочка на ножке
	B.vcyl(g, "Ring", 0.5, d * 1.5, CFrame.new(pos:Lerp(top, 0.72)), stemCol, M.SmoothPlastic)
	local cd = math.min(30, h * 0.9 + 6)
	local ch = cd * 0.34
	local capC = top + Vector3.new(0, ch * 0.22, 0)
	B.ellipsoid(g, "Cap", Vector3.new(cd, ch, cd), CFrame.new(capC), style.cap, M.SmoothPlastic)
	B.vcyl(g, "Gills", 0.5, cd * 0.84, CFrame.new(top + Vector3.new(0, -ch * 0.05, 0)), style.gill, M.SmoothPlastic)
	-- пятна на шляпке
	local n = rng:int(5, 9)
	for i = 1, n do
		local th = rng:range(0.25, 1.05)
		local ph = (i / n) * math.pi * 2 + rng:range(-0.3, 0.3)
		local p = capC + Vector3.new(cd / 2 * math.sin(th) * math.cos(ph), ch / 2 * math.cos(th), cd / 2 * math.sin(th) * math.sin(ph))
		B.ball(g, "Spot", cd * rng:range(0.08, 0.13), CFrame.new(p), style.spot, style.glow and M.Neon or M.SmoothPlastic,
			{ CanCollide = false, CastShadow = false })
	end
	if style.glow then
		local lightMk = B.marker(g, "Glow", Vector3.new(1, 1, 1), CFrame.new(top - Vector3.new(0, 2, 0)))
		B.light(lightMk, "PointLight", { Range = 22, Brightness = 1.4, Color = style.spot })
	end
	return g, d, cd
end

local function miniMushrooms(m, rng, pos, n)
	local g = B.model(m, "MiniMushrooms")
	local style = rng:pick(CAPS)
	for _ = 1, n do
		local a, r = rng:angle(), rng:range(0, 2.2)
		local p = pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local h = rng:range(0.8, 2.6)
		local d = rng:range(1.2, 2.8)
		B.vcyl(g, "Stem", h, d * 0.3, CFrame.new(p + Vector3.new(0, h / 2, 0)), rng:pick(STEMS), M.SmoothPlastic, { CanCollide = false })
		B.ellipsoid(g, "Cap", Vector3.new(d, d * 0.5, d), CFrame.new(p + Vector3.new(0, h, 0)), style.cap,
			style.glow and M.Neon or M.SmoothPlastic, { CanCollide = false })
	end
	return g
end

local function log(m, rng, pos, yaw, len)
	local g = B.model(m, "Log")
	local cf = CFrame.new(pos + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, yaw, 0)
	B.cyl(g, "Log", len, 3, cf * CFrame.Angles(0, 0, math.rad(rng:range(-3, 3))), rgb(110, 80, 58), M.Wood)
	for _, x in ipairs({ -len / 2, len / 2 }) do
		B.cyl(g, "Cut", 0.2, 2.6, cf * CFrame.new(x, 0, 0), rgb(200, 170, 120), M.Wood)
	end
	for _ = 1, 3 do
		local x = rng:range(-len / 2 + 1, len / 2 - 1)
		B.ellipsoid(g, "Moss", Vector3.new(3, 1, 2.6), cf * CFrame.new(x, 1.3, 0), rgb(90, 160, 70), M.Grass, { CanCollide = false })
	end
	miniMushrooms(g, rng, (cf * CFrame.new(rng:range(-len / 3, len / 3), 1.4, 0)).Position, 3)
	return g
end

function Z.build(ctx)
	local m, rng, occ, L = ctx.model, ctx.rng, ctx.occ, ctx.L
	local zone = ctx.zone
	local deco = B.model(m, "Decor")

	-- пятна травы и тропа
	for _ = 1, 16 do
		T.patch(rng:range(ctx.x0, ctx.x1), rng:range(zone.z1, zone.z0), L, rng:range(8, 16), M.Grass)
	end
	local xs = { 0, 22, -20, 26, -22, 10, 0 }
	local pts = {}
	for i, x in ipairs(xs) do
		local z = zone.z0 + (zone.z1 - zone.z0) * (i - 1) / (#xs - 1)
		table.insert(pts, Vector3.new(x, L, z))
	end
	T.trail(pts, L, 10, M.Ground)
	for i = 1, #pts - 1 do occ:addLine(pts[i], pts[i + 1], 7) end

	-- холмики
	for _ = 1, 5 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 12)
		if x then
			local r = rng:range(10, 14)
			T.ball(x, L - r + rng:range(2, 4), z, r, M.LeafyGrass)
			occ:add(x, z, r * 0.7)
		end
	end

	-- кольцо фей в центре
	do
		local x, z = occ:find(rng, -50, 50, zone.z0 - 60, zone.z1 + 60, 12)
		if x then
			local c = Vector3.new(x, L, z)
			for i = 0, 11 do
				local a = i / 12 * math.pi * 2
				local g = miniMushrooms(deco, rng, c + Vector3.new(math.cos(a) * 8, 0, math.sin(a) * 8), 1)
				g.Name = "FairyRing"
			end
			B.part(deco, "FairyStone", Vector3.new(3, 4, 3), CFrame.new(c + Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, 0.4, 0.1),
				rgb(150, 140, 170), M.Slate)
			local orb = B.ball(deco, "FairyOrb", 1.4, CFrame.new(c + Vector3.new(0, 6, 0)), rgb(255, 180, 255), M.Neon, { CanCollide = false })
			B.light(orb, "PointLight", { Range = 16, Brightness = 2, Color = rgb(255, 180, 255) })
			B.tag(orb, "Bob", { Height = 0.8, Period = 3 })
			P.motes(deco, CFrame.new(c + Vector3.new(0, 4, 0)), Vector3.new(16, 6, 16), rgb(255, 190, 255), 10, "FairyDust")
			occ:add(x, z, 11)
		end
	end

	-- гигантские грибы (свой учёт шляпок, чтобы они не врастали друг в друга)
	local caps = P.newOcc()
	local made = 0
	for _ = 1, 60 do
		if made >= 17 then break end
		local h = rng:range(10, 27)
		local cd = math.min(30, h * 0.9 + 6)
		local x, z = occ:find(rng, ctx.x0 + 4, ctx.x1 - 4, ctx.z0 - 4, ctx.z1 + 4, 3, 20)
		if x and caps:free(x, z, cd * 0.45) then
			local _, d, capD = giantMushroom(deco, rng, Vector3.new(x, L, z), h, rng:pick(CAPS))
			caps:add(x, z, capD * 0.45)
			occ:add(x, z, d / 2 + 2.5)
			made = made + 1
		end
	end

	-- поваленные брёвна
	for _ = 1, 5 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 9)
		if x then
			local yaw, len = rng:angle(), rng:range(12, 18)
			log(deco, rng, Vector3.new(x, L, z), yaw, len)
			local dir = Vector3.new(math.cos(yaw), 0, -math.sin(yaw)) * (len / 2)
			occ:addLine(Vector3.new(x, L, z) - dir, Vector3.new(x, L, z) + dir, 2.5)
		end
	end
	-- россыпи маленьких грибов, камни, деревья, цветы
	for _ = 1, 26 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 3)
		if x then
			miniMushrooms(deco, rng, Vector3.new(x, L, z), rng:int(3, 6))
			occ:add(x, z, 2.5)
		end
	end
	for _ = 1, 10 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 4)
		if x then
			P.rock(deco, Vector3.new(x, L, z), rng:range(3, 6), rng, rgb(120, 118, 128), M.Slate)
			occ:add(x, z, 3.5)
		end
	end
	for _ = 1, 6 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 7)
		if x then
			P.tree(deco, Vector3.new(x, L, z), rng, rng:range(0.9, 1.2), P.TreePalettes[2])
			occ:add(x, z, 3)
		end
	end
	for _ = 1, 12 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 4)
		if x then
			P.flowers(deco, Vector3.new(x, L, z), rng, 10, { rgb(255, 120, 220), rgb(200, 140, 255), rgb(255, 240, 120) }, 3)
		end
	end
	-- светлячки
	for i = 1, 6 do
		local z = zone.z0 - 25 - (i - 1) * 30
		P.motes(deco, CFrame.new(rng:range(-60, 60), L + 6, z), Vector3.new(50, 10, 30), i % 2 == 0 and rgb(255, 230, 120) or rgb(220, 160, 255), 8, "Fireflies")
	end
	-- указатель
	P.signpost(deco, CFrame.new(-14, L, zone.z0 - 14) * CFrame.Angles(0, math.rad(20), 0), "ГРИБНОЙ ЛЕС", "Грибы-светяки и споры", zone.accent, 12, 4)
	occ:add(-14, zone.z0 - 14, 7)
end

return Z
