-- Башня ребёрта (запад): высокая башня с парящей сферой на верхушке и портал у подножия,
-- обращённый к площади. Через портал игрок будет делать ребёрт (сброс ради множителя).
local RS = game:GetService("ReplicatedStorage")
local B = require(RS.Shared.Build)
local D = require(RS.Shared.MapData)
local P = require(script.Parent.Props)

local Tower = {}
local rgb = P.rgb
local M = Enum.Material

local VIOLET = rgb(190, 110, 255)
local MARBLE = rgb(226, 220, 240)
local MARBLE_DARK = rgb(160, 150, 190)

function Tower.build(root)
	local m = B.model(root, "RebirthTower")
	local c = D.Rebirth.center
	local cx, cz = c.X, c.Z

	-- площадь
	B.vcyl(m, "Plaza", 1, 56, CFrame.new(cx, 0.5, cz), MARBLE, M.Marble)
	B.ring(m, "PlazaRing", CFrame.new(cx, 1.03, cz), 25, 48, 0.1, 0.8, VIOLET, M.Neon)

	-- башня: основание, ствол с поясами и окнами, балкон, шпиль
	local x0 = cx - 6 -- башня чуть смещена на запад, портал смотрит на восток
	B.vcyl(m, "Base", 6, 28, CFrame.new(x0, 4, cz), MARBLE_DARK, M.Marble)
	B.vcyl(m, "Shaft", 48, 20, CFrame.new(x0, 7 + 24, cz), MARBLE, M.Marble)
	for y = 14, 50, 9 do
		B.vcyl(m, "Band", 1, 20.8, CFrame.new(x0, y, cz), VIOLET, M.Neon)
	end
	for k = 0, 11 do
		local a = k * 30
		for _, y in ipairs({ 20, 38 }) do
			local d = P.compass(a + (y == 38 and 15 or 0))
			local p = Vector3.new(x0 + d.X * 10, y, cz + d.Z * 10)
			B.part(m, "Window", Vector3.new(2, 4, 0.6), P.facing(p, Vector3.new(x0, y, cz)), rgb(60, 40, 90), M.Glass, { Transparency = 0.1 })
		end
	end
	B.vcyl(m, "Balcony", 1.6, 28, CFrame.new(x0, 55.8, cz), MARBLE_DARK, M.Marble)
	B.ring(m, "Battlement", CFrame.new(x0, 58, cz), 13.4, 24, 3, 1.2, MARBLE, M.Marble, function(a) return math.floor(a / 15) % 2 == 1 end)
	local tiers = { { 18, 4 }, { 14, 4 }, { 10, 4 }, { 6, 5 }, { 2.6, 6 } }
	local y = 56.6
	for _, t in ipairs(tiers) do
		B.vcyl(m, "Spire", t[2], t[1], CFrame.new(x0, y + t[2] / 2, cz), t[1] > 9 and MARBLE_DARK or VIOLET, t[1] > 9 and M.Marble or M.Neon)
		y = y + t[2]
	end
	-- парящая сфера с кольцами
	local orbY = y + 9
	local orb = B.ball(m, "RebirthOrb", 7, CFrame.new(x0, orbY, cz), VIOLET, M.Neon, { CanCollide = false })
	B.light(orb, "PointLight", { Range = 60, Brightness = 3, Color = VIOLET })
	B.tag(orb, "Bob", { Height = 1.5, Period = 5 })
	for i, tilt in ipairs({ 20, -35 }) do
		local ringCf = CFrame.new(x0, orbY, cz) * CFrame.Angles(math.rad(tilt), 0, math.rad(i * 25))
		local ring = B.ring(m, "OrbRing", ringCf, 6.5 + i * 1.5, 30, 0.35, 0.35, i == 1 and rgb(255, 220, 255) or VIOLET, M.Neon, nil,
			{ CanCollide = false, CastShadow = false })
		ring.WorldPivot = ringCf
		B.tag(ring, "Spin", { Speed = i == 1 and 35 or -50 })
	end

	-- портал к востоку от башни: кольцо в плоскости YZ и мерцающая плёнка
	local px = x0 + 15
	local portalCf = CFrame.new(px, 10.5, cz)
	B.part(m, "PortalStep", Vector3.new(8, 1, 18), CFrame.new(px, 1.5, cz), MARBLE_DARK, M.Marble)
	B.part(m, "PortalStep", Vector3.new(4, 1, 14), CFrame.new(px + 4, 1, cz), MARBLE_DARK, M.Marble)
	B.ring(m, "PortalRing", portalCf * CFrame.Angles(0, 0, math.rad(90)), 8, 32, 1.4, 1.6, VIOLET, M.Neon)
	B.ring(m, "PortalFrame", portalCf * CFrame.Angles(0, 0, math.rad(90)), 9.4, 36, 1.8, 2.2, MARBLE_DARK, M.Marble)
	local film = B.cyl(m, "PortalFilm", 0.3, 15.4, portalCf, rgb(220, 150, 255), M.ForceField, { Transparency = 0.1, CanCollide = false })
	B.light(film, "PointLight", { Range = 26, Brightness = 2, Color = VIOLET })
	B.particles(film, {
		Color = ColorSequence.new(rgb(240, 200, 255), VIOLET), Size = NumberSequence.new(0.5, 0),
		Transparency = NumberSequence.new(0, 1), Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(30, 30), Rate = 14, LightEmission = 1, EmissionDirection = Enum.NormalId.Right,
	})
	local st = B.marker(m, "RebirthPortal", Vector3.new(6, 16, 16), portalCf)
	B.attrs(st, { Station = "Rebirth" })
	local sign = B.part(m, "Sign", Vector3.new(16, 3.6, 0.6), CFrame.new(px + 1.2, 21.5, cz) * CFrame.Angles(0, math.rad(90), 0), rgb(40, 30, 60), M.SmoothPlastic)
	P.board(sign, Enum.NormalId.Back, "РЕБЁРТ", "Начни заново — получи множитель", VIOLET, rgb(40, 30, 60))

	-- обелиски с парящими кристаллами
	for _, a in ipairs({ 45, 135, 225, 315 }) do
		local d = P.compass(a)
		local p = Vector3.new(cx + d.X * 22, 1, cz + d.Z * 22)
		B.part(m, "Obelisk", Vector3.new(3, 12, 3), CFrame.new(p + Vector3.new(0, 6, 0)), MARBLE_DARK, M.Marble)
		B.wedge(m, "ObeliskTop", Vector3.new(3, 2, 1.5), CFrame.new(p + Vector3.new(0, 13, -0.75)), MARBLE_DARK, M.Marble)
		B.wedge(m, "ObeliskTop", Vector3.new(3, 2, 1.5), CFrame.new(p + Vector3.new(0, 13, 0.75)) * CFrame.Angles(0, math.pi, 0), MARBLE_DARK, M.Marble)
		local cr = B.model(m, "FloatingCrystal")
		P.crystal(cr, p + Vector3.new(0, 17, 0), Vector3.yAxis, 2.4, 1.4, VIOLET)
		P.crystal(cr, p + Vector3.new(0, 17, 0), -Vector3.yAxis, 2, 1.4, VIOLET)
		cr.WorldPivot = CFrame.new(p + Vector3.new(0, 17, 0))
		B.tag(cr, "Spin", { Speed = 50 })
		B.tag(cr, "Bob", { Height = 0.6, Period = 3 })
	end
	return m
end

return Tower
