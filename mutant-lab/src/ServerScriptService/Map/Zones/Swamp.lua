-- Зона 2. Слизистое болото: топь, пруды с кувшинками, светящиеся лужи слизи, деревянный
-- настил через всё болото, мёртвые деревья с мхом, хижина на сваях, туман и светлячки.
local RS = game:GetService("ReplicatedStorage")
local B = require(RS.Shared.Build)
local P = require(script.Parent.Parent.Props)
local T = require(script.Parent.Parent.Terrain)

local Z = {}
local C, rgb = P.C, P.rgb
local M = Enum.Material

local WOOD = { rgb(112, 84, 58), rgb(98, 74, 52), rgb(126, 96, 66), rgb(90, 70, 50) }

-- деревянный настил по ломаной; высота настила над землёй — 0.8
local function boardwalk(m, rng, pts, L, w)
	local g = B.model(m, "Boardwalk")
	local y = L + 0.8
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local len = flat.Magnitude
		local frame = CFrame.lookAt(Vector3.new(a.X, y, a.Z), Vector3.new(b.X, y, b.Z))
		-- продольные балки
		for _, x in ipairs({ -w / 2 + 0.4, w / 2 - 0.4 }) do
			B.part(g, "Beam", Vector3.new(0.6, 0.6, len + 1), frame * CFrame.new(x, -0.5, -len / 2), WOOD[2], M.Wood)
		end
		-- доски поперёк
		local n = math.floor(len / 1.6)
		for k = 0, n do
			if rng:chance(0.96) then
				local c = frame * CFrame.new(rng:range(-0.15, 0.15), 0, -k * 1.6) * CFrame.Angles(0, math.rad(rng:range(-3, 3)), 0)
				B.part(g, "Plank", Vector3.new(w, 0.35, 1.4), c, rng:pick(WOOD), M.WoodPlanks)
			end
		end
		-- сваи и перила (перила только у прудов — через раз)
		local posts = math.max(1, math.floor(len / 6))
		for k = 0, posts do
			for _, x in ipairs({ -w / 2 + 0.4, w / 2 - 0.4 }) do
				local p = frame * Vector3.new(x, 0, -len * k / posts)
				B.part(g, "Pile", Vector3.new(0.7, 4, 0.7), CFrame.new(p - Vector3.new(0, 2.2, 0)), WOOD[4], M.Wood)
				if i % 2 == 0 then
					B.part(g, "RailPost", Vector3.new(0.4, 3, 0.4), CFrame.new(p + Vector3.new(0, 1.5, 0)), WOOD[1], M.Wood)
				end
			end
		end
		if i % 2 == 0 then
			for _, x in ipairs({ -w / 2 + 0.4, w / 2 - 0.4 }) do
				B.part(g, "Rail", Vector3.new(0.3, 0.3, len), frame * CFrame.new(x, 2.8, -len / 2), WOOD[1], M.Wood)
			end
		end
	end
	return g
end

local function slimePool(m, rng, pos, r)
	local g = B.model(m, "SlimePool")
	local goo = B.vcyl(g, "Slime", 0.4, r * 2, CFrame.new(pos + Vector3.new(0, 0.15, 0)), C.slime, M.Neon, { Transparency = 0.1, CanCollide = false })
	B.light(goo, "PointLight", { Range = r * 2 + 6, Brightness = 1.2, Color = C.slime })
	B.particles(goo, {
		Color = ColorSequence.new(rgb(200, 255, 150)), Size = NumberSequence.new(0.6, 0.1),
		Transparency = NumberSequence.new(0.2, 1), Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(1, 3),
		Rate = math.floor(r), EmissionDirection = Enum.NormalId.Top,
	})
	-- капли по краю
	local n = math.floor(r * 1.2)
	for i = 1, n do
		local a = i / n * math.pi * 2 + rng:range(-0.2, 0.2)
		local d = rng:range(1.2, 3)
		B.ball(g, "Blob", d, CFrame.new(pos + Vector3.new(math.cos(a) * r, d * 0.25, math.sin(a) * r)), rgb(90, 220, 70), M.Glass,
			{ Transparency = 0.25 })
	end
	return g
end

local function slimeMound(m, rng, pos)
	local g = B.model(m, "Slimes")
	for i = 1, rng:int(3, 5) do
		local a, r = rng:angle(), i == 1 and 0 or rng:range(1.5, 3.5)
		local d = i == 1 and rng:range(4, 6) or rng:range(1.6, 3.2)
		local p = pos + Vector3.new(math.cos(a) * r, d * 0.4, math.sin(a) * r)
		B.ellipsoid(g, "Slime", Vector3.new(d, d * 0.8, d), CFrame.new(p), rgb(110, 240, 90), M.Glass, { Transparency = 0.3 })
		B.ball(g, "Core", d * 0.45, CFrame.new(p), rgb(170, 255, 80), M.Neon, { CanCollide = false })
		if i == 1 then
			-- глазки
			for _, s in ipairs({ -1, 1 }) do
				B.ball(g, "Eye", d * 0.16, CFrame.new(p + Vector3.new(s * d * 0.16, d * 0.22, -d * 0.36)), Color3.new(1, 1, 1), M.SmoothPlastic, { CanCollide = false })
				B.ball(g, "Pupil", d * 0.08, CFrame.new(p + Vector3.new(s * d * 0.16, d * 0.22, -d * 0.43)), Color3.new(0, 0, 0), M.SmoothPlastic, { CanCollide = false })
			end
		end
	end
	return g
end

local function reeds(m, rng, pos, n)
	local g = B.model(m, "Reeds")
	for _ = 1, n do
		local a, r = rng:angle(), rng:range(0, 2)
		local p = pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local h = rng:range(2.5, 5)
		local tilt = CFrame.Angles(rng:range(-0.15, 0.15), 0, rng:range(-0.15, 0.15))
		local base = CFrame.new(p) * tilt
		B.part(g, "Reed", Vector3.new(0.2, h, 0.2), base * CFrame.new(0, h / 2, 0), rgb(90, 140, 60), M.Grass, { CanCollide = false, CastShadow = false })
		if rng:chance(0.6) then
			B.vcyl(g, "Cattail", 1, 0.5, base * CFrame.new(0, h - 0.6, 0), rgb(110, 70, 40), M.Fabric, { CanCollide = false })
		end
	end
	return g
end

local function hut(m, pos, yaw)
	local g = B.model(m, "WitchHut")
	local o = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local floorY = 6
	for _, x in ipairs({ -7, 0, 7 }) do
		for _, z in ipairs({ -7, 7 }) do
			B.part(g, "Stilt", Vector3.new(1, floorY + 2, 1), o * CFrame.new(x, (floorY - 2) / 2, z), WOOD[4], M.Wood)
		end
	end
	B.part(g, "Deck", Vector3.new(17, 0.6, 17), o * CFrame.new(0, floorY, 0), WOOD[1], M.WoodPlanks)
	local wo = o * CFrame.new(0, floorY + 0.3, 1.5)
	local function pt(x, z) return wo * Vector3.new(x, 0, z) end
	B.wall(g, "Front", pt(-6, -5), pt(6, -5), 7, 0.6, WOOD[3], M.WoodPlanks, { { at = 6, w = 3.4, y0 = 0, y1 = 5.5 }, { at = 2.2, w = 2, y0 = 3, y1 = 5 } })
	B.wall(g, "Back", pt(6, 5), pt(-6, 5), 7, 0.6, WOOD[3], M.WoodPlanks)
	B.wall(g, "Left", pt(-6, 5), pt(-6, -5), 7, 0.6, WOOD[2], M.WoodPlanks, { { at = 5, w = 2, y0 = 3, y1 = 5 } })
	B.wall(g, "Right", pt(6, -5), pt(6, 5), 7, 0.6, WOOD[2], M.WoodPlanks)
	-- двускатная крыша
	for _, s in ipairs({ -1, 1 }) do
		B.part(g, "Roof", Vector3.new(8.2, 0.6, 13), wo * CFrame.new(s * 3.3, 9.2, 0) * CFrame.Angles(0, 0, math.rad(-s * 35)), rgb(70, 90, 50), M.Grass)
	end
	B.part(g, "Ridge", Vector3.new(0.8, 0.8, 13.4), wo * CFrame.new(0, 11.5, 0), WOOD[4], M.Wood)
	B.vcyl(g, "Chimney", 4, 1.6, wo * CFrame.new(3, 11.5, 3), rgb(90, 90, 96), M.Cobblestone)
	local smoke = B.marker(g, "ChimneySmoke", Vector3.new(1, 1, 1), wo * CFrame.new(3, 13.7, 3))
	local s = Instance.new("Smoke")
	s.Color = rgb(170, 255, 150)
	s.Opacity = 0.15
	s.RiseVelocity = 3
	s.Size = 2
	s.Parent = smoke
	-- котёл внутри и зелёный свет из окон
	B.vcyl(g, "Pot", 2, 3, wo * CFrame.new(-2, 1, 1), C.metalDark, M.Metal)
	local brew = B.vcyl(g, "Brew", 0.2, 2.6, wo * CFrame.new(-2, 2.05, 1), C.slime, M.Neon)
	B.light(brew, "PointLight", { Range = 14, Brightness = 2, Color = C.slime })
	-- лестница
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Anchored = true
	ladder.Size = Vector3.new(2, floorY + 2, 2)
	ladder.CFrame = o * CFrame.new(0, (floorY + 2) / 2 - 1.6, -9.6)
	ladder.Color = WOOD[4]
	ladder.Material = M.Wood
	ladder.Parent = g
	P.signpost(g, o * CFrame.new(5, 0, -12) * CFrame.Angles(0, math.pi, 0), "ХИЖИНА", "Болотной ведьмы", C.slime, 8, 3)
	return g
end

function Z.build(ctx)
	local m, rng, occ, L = ctx.model, ctx.rng, ctx.occ, ctx.L
	local zone = ctx.zone
	local deco = B.model(m, "Decor")

	-- островки травы на топи
	for _ = 1, 14 do
		T.patch(rng:range(ctx.x0, ctx.x1), rng:range(zone.z1, zone.z0), L, rng:range(7, 14), rng:chance(0.5) and M.Grass or M.LeafyGrass)
	end
	-- настил через болото
	local pts = {
		Vector3.new(0, L, zone.z0 - 4), Vector3.new(-30, L, zone.z0 - 36), Vector3.new(-30, L, zone.z0 - 80),
		Vector3.new(26, L, zone.z0 - 120), Vector3.new(26, L, zone.z0 - 150), Vector3.new(0, L, zone.z1 + 34),
	}
	boardwalk(deco, rng, pts, L, 7)
	for i = 1, #pts - 1 do occ:addLine(pts[i], pts[i + 1], 6) end

	-- пруды
	local ponds = {}
	for _ = 1, 6 do
		local r = rng:range(9, 16)
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, r + 2)
		if x then
			T.pond(x, z, L, r, 3, M.Mud)
			occ:add(x, z, r + 1.5)
			table.insert(ponds, { x, z, r })
		end
	end
	for _, pd in ipairs(ponds) do
		local x, z, r = pd[1], pd[2], pd[3]
		for _ = 1, math.floor(r / 2) do
			local a, rr = rng:angle(), rng:range(0, r - 2)
			B.vcyl(deco, "LilyPad", 0.15, rng:range(1.8, 3.6), CFrame.new(x + math.cos(a) * rr, L - 0.7, z + math.sin(a) * rr),
				rgb(70, 160, 70), M.Grass, { CanCollide = false })
		end
		for _ = 1, 4 do
			local a = rng:angle()
			reeds(deco, rng, Vector3.new(x + math.cos(a) * (r + 1), L, z + math.sin(a) * (r + 1)), rng:int(4, 8))
		end
	end

	-- хижина ведьмы
	do
		local x, z = occ:find(rng, ctx.x0 + 10, ctx.x1 - 10, ctx.z0, ctx.z1, 14, 60)
		if x then
			hut(deco, Vector3.new(x, L, z), rng:range(-0.6, 0.6))
			occ:add(x, z, 13)
		end
	end
	-- лужи слизи и слизни
	for _ = 1, 7 do
		local r = rng:range(4, 8)
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, r + 2)
		if x then
			slimePool(deco, rng, Vector3.new(x, L, z), r)
			occ:add(x, z, r + 1)
		end
	end
	for _ = 1, 8 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 4)
		if x then
			slimeMound(deco, rng, Vector3.new(x, L, z))
			occ:add(x, z, 3.5)
		end
	end
	-- мёртвые деревья, камни, камыши
	for _ = 1, 12 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 5)
		if x then
			P.deadTree(deco, Vector3.new(x, L, z), rng, rng:range(1, 1.5), rgb(74, 66, 56), rgb(110, 150, 70))
			occ:add(x, z, 2.5)
		end
	end
	for _ = 1, 8 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 4)
		if x then
			P.rock(deco, Vector3.new(x, L, z), rng:range(3, 5), rng, rgb(96, 110, 90), M.Slate)
			occ:add(x, z, 3)
		end
	end
	for _ = 1, 10 do
		local x, z = occ:find(rng, ctx.x0, ctx.x1, ctx.z0, ctx.z1, 3)
		if x then reeds(deco, rng, Vector3.new(x, L, z), rng:int(5, 9)) end
	end
	-- туман над топью и светлячки
	for i = 1, 5 do
		local z = zone.z0 - 20 - (i - 1) * 40
		local fog = B.marker(deco, "Mist", Vector3.new(180, 2, 34), CFrame.new(0, L + 1.5, z))
		B.particles(fog, {
			Color = ColorSequence.new(rgb(200, 230, 190)), Size = NumberSequence.new(10, 16),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.86), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(0.3, 0.8), SpreadAngle = Vector2.new(180, 10),
			Rate = 3, LightEmission = 0, LightInfluence = 1, RotSpeed = NumberRange.new(-5, 5), Rotation = NumberRange.new(0, 360),
		})
		P.motes(deco, CFrame.new(rng:range(-50, 50), L + 5, z), Vector3.new(60, 8, 30), rgb(190, 255, 120), 8, "Fireflies")
	end
	P.signpost(deco, CFrame.new(16, L, zone.z0 - 14) * CFrame.Angles(0, math.rad(-20), 0), "СЛИЗИСТОЕ БОЛОТО", "Слизь, кувшинки, болотный газ", zone.accent, 13, 4)
	occ:add(16, zone.z0 - 14, 7)
end

return Z
