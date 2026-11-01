-- Улица вокруг дома: газон, дорожки, подъездная дорога, улица, соседние дома, деревья, забор.
-- Внутрь соседних домов не попасть — это декорации для вида из окон.
local Exterior = {}

local B, C
local GROUND = -1.2

local function tree(parent, x, z, s, kind)
	local m = B.model(parent, "Tree")
	B.outline(m)
	s = s or 1
	B.vcyl(m, "Trunk", 9 * s, 1.6 * s, CFrame.new(x, GROUND + 4.5 * s, z), "#7A5235")
	local leaf = kind == 2 and "#5E9E3E" or "#4E8F3A"
	B.ball(m, "Crown", 9 * s, CFrame.new(x, GROUND + 11 * s, z), leaf)
	B.ball(m, "Crown", 6.5 * s, CFrame.new(x + 3 * s, GROUND + 9.5 * s, z + 1.5 * s), B.shade(leaf, 1.12))
	B.ball(m, "Crown", 6 * s, CFrame.new(x - 2.8 * s, GROUND + 10 * s, z - 1.6 * s), B.shade(leaf, 0.9))
	return m
end

local function bush(parent, x, z, s)
	local m = B.model(parent, "Bush")
	B.ball(m, "Bush", 3.2 * s, CFrame.new(x, GROUND + 1.2 * s, z), "#5A9E45")
	B.ball(m, "Bush", 2.4 * s, CFrame.new(x + 1.4 * s, GROUND + 1.0 * s, z + 0.6 * s), "#6AAE52")
	return m
end

-- соседний дом (коробка с двускатной крышей, окна, дверь)
local function neighbour(parent, cx, cz, w, d, h, wall, roofCol, facing)
	local m = B.model(parent, "Neighbour")
	local base = CFrame.new(cx, GROUND, cz) * CFrame.Angles(0, math.rad(facing or 0), 0)
	local P = B.kit(m, base)
	P("Body", w, h, d, 0, h / 2, 0, wall)
	P("Foundation", w + 0.6, 1.2, d + 0.6, 0, 0.6, 0, "#B9B3A8", Enum.Material.Concrete)
	local rise = d * 0.32
	P.wedge("Roof", w + 2, rise, d / 2 + 1, 0, h + rise / 2, -d / 4 - 0.5, roofCol)
	P.wedge("Roof", w + 2, rise, d / 2 + 1, 0, h + rise / 2, d / 4 + 0.5, roofCol, nil, nil, CFrame.Angles(0, math.rad(180), 0))
	-- окна на фасаде (−Z) и сзади
	local cols = math.max(2, math.floor(w / 9))
	for fl = 0, 1 do
		for i = 0, cols - 1 do
			local x = -w / 2 + (i + 0.5) * w / cols
			if not (fl == 0 and i == math.floor(cols / 2)) then
				P("Win", 3.6, 4.2, 0.2, x, 4 + fl * 11, -d / 2 - 0.05, "#7FB2D6", Enum.Material.Glass, { Transparency = 0.15 })
				P("WinFrame", 4.2, 4.8, 0.15, x, 4 + fl * 11, -d / 2 - 0.02, "#F6F2EA")
			end
			P("WinB", 3.6, 4.2, 0.2, x, 4 + fl * 11, d / 2 + 0.05, "#7FB2D6", Enum.Material.Glass, { Transparency = 0.15 })
			P("WinBFrame", 4.2, 4.8, 0.15, x, 4 + fl * 11, d / 2 + 0.02, "#F6F2EA")
		end
	end
	P("Door", 4, 7.5, 0.3, (math.floor(cols / 2) + 0.5) * w / cols - w / 2, 4.95, -d / 2 - 0.1, "#7A4A2E")
	-- боковые окна
	for fl = 0, 1 do
		P("WinS", 0.2, 4.2, 3.6, -w / 2 - 0.05, 4 + fl * 11, 0, "#7FB2D6", Enum.Material.Glass, { Transparency = 0.15 })
		P("WinS", 0.2, 4.2, 3.6, w / 2 + 0.05, 4 + fl * 11, 0, "#7FB2D6", Enum.Material.Glass, { Transparency = 0.15 })
	end
	return m
end

function Exterior.build(ctx, root)
	B, C = ctx.Build, ctx.Config
	local ext = B.folder(root, "Exterior")
	-- земля
	B.part(ext, "Grass", Vector3.new(1000, 2, 1000), CFrame.new(28, GROUND - 1, 20), "#7DB65A", Enum.Material.Grass)
	-- улица перед домом (z < −22)
	B.part(ext, "Street", Vector3.new(1000, 0.2, 26), CFrame.new(28, GROUND + 0.05, -42), "#5B5E66", Enum.Material.Asphalt)
	for x = -200, 260, 16 do
		B.part(ext, "Line", Vector3.new(7, 0.05, 0.6), CFrame.new(x, GROUND + 0.18, -42), "#F2D85A")
	end
	B.part(ext, "Sidewalk", Vector3.new(1000, 0.5, 5), CFrame.new(28, GROUND + 0.25, -26.5), "#C9C4B8", Enum.Material.Concrete)
	B.part(ext, "Sidewalk", Vector3.new(1000, 0.5, 5), CFrame.new(28, GROUND + 0.25, -57.5), "#C9C4B8", Enum.Material.Concrete)
	B.part(ext, "Curb", Vector3.new(1000, 0.6, 0.5), CFrame.new(28, GROUND + 0.3, -29.2), "#B3AEA2", Enum.Material.Concrete)
	-- дорожка к крыльцу и подъезд к гаражу
	B.part(ext, "Path", Vector3.new(4.5, 0.3, 16), CFrame.new(32, GROUND + 0.15, -16), "#C9C4B8", Enum.Material.Concrete)
	B.part(ext, "Driveway", Vector3.new(18, 0.25, 26), CFrame.new(68.5, GROUND + 0.12, -14), "#A7A39B", Enum.Material.Concrete)
	-- почтовый ящик
	local mb = B.model(ext, "Mailbox")
	B.outline(mb)
	B.part(mb, "Post", Vector3.new(0.4, 3.6, 0.4), CFrame.new(38, GROUND + 1.8, -22.5), "#6B4226")
	B.part(mb, "Box", Vector3.new(1.0, 1.0, 1.8), CFrame.new(38, GROUND + 4.0, -22.5), "#3B6FB0")
	B.part(mb, "Flag", Vector3.new(0.1, 0.8, 0.3), CFrame.new(38.55, GROUND + 4.4, -22.2), "#D23B3B")
	-- машина у гаража (простая, мультяшная)
	local car = B.model(ext, "Car")
	B.outline(car)
	local P = B.kit(car, CFrame.new(68.5, GROUND, -12))
	P("Body", 7.0, 2.4, 13, 0, 2.2, 0, "#C9D6E2")
	P("Cabin", 6.2, 2.2, 6.5, 0, 4.4, 0.8, "#B3C3D2")
	P("Windshield", 5.8, 1.8, 0.15, 0, 4.4, -2.5, "#5C7A92", Enum.Material.Glass, { Transparency = 0.1 })
	for _, w in ipairs({ { -3.4, -4 }, { 3.4, -4 }, { -3.4, 4.2 }, { 3.4, 4.2 } }) do
		P.cyl("Wheel", 1.0, 2.4, w[1], 1.2, w[2], "#222226")
	end
	P("Light", 1.2, 0.6, 0.1, -2.4, 2.6, -6.55, "#FFF6C2", Enum.Material.Neon)
	P("Light", 1.2, 0.6, 0.1, 2.4, 2.6, -6.55, "#FFF6C2", Enum.Material.Neon)
	-- забор вокруг заднего двора
	local fence = B.model(ext, "Fence")
	local function fenceLine(a, b)
		local d = (b - a)
		local n = math.floor(d.Magnitude / 1.4)
		for i = 0, n do
			local p = a + d * (i / n)
			B.part(fence, "Board", Vector3.new(1.0, 5, 0.25), CFrame.lookAt(p + Vector3.new(0, GROUND + 2.5, 0), p + Vector3.new(0, GROUND + 2.5, 0) + Vector3.new(d.Z, 0, -d.X)), "#F4EFE6")
		end
		local mid = (a + b) / 2
		B.part(fence, "Rail", Vector3.new(0.3, 0.4, d.Magnitude), CFrame.lookAt(mid + Vector3.new(0, GROUND + 3.8, 0), mid + Vector3.new(0, GROUND + 3.8, 0) + d), "#E6E0D4")
	end
	fenceLine(Vector3.new(-14, 0, 6), Vector3.new(-14, 0, 86))
	fenceLine(Vector3.new(-14, 0, 86), Vector3.new(96, 0, 86))
	fenceLine(Vector3.new(96, 0, 86), Vector3.new(96, 0, 6))
	-- деревья и кусты
	tree(ext, 74, 40, 1.15, 1)      -- в лучах утреннего солнца у окна Морти
	tree(ext, -8, 64, 1.0, 2)
	tree(ext, 40, 70, 1.25, 1)
	tree(ext, 10, -20, 0.9, 2)
	tree(ext, 90, -20, 1.0, 1)
	tree(ext, -40, -70, 1.1, 2)
	tree(ext, 120, -72, 1.0, 1)
	for _, b in ipairs({ { 4, -3 }, { 12, -3 }, { 20, -3 }, { 44, -3 }, { 50, -3 }, { 2, 44 }, { 54, 44 } }) do
		bush(ext, b[1], b[2], 1)
	end
	-- клумба и качели на заднем дворе
	local sw = B.model(ext, "Swing")
	B.outline(sw)
	B.part(sw, "Post", Vector3.new(0.5, 10, 0.5), CFrame.new(20, GROUND + 5, 62) * CFrame.Angles(0, 0, math.rad(8)), "#C23B3B")
	B.part(sw, "Post", Vector3.new(0.5, 10, 0.5), CFrame.new(28, GROUND + 5, 62) * CFrame.Angles(0, 0, math.rad(-8)), "#C23B3B")
	B.part(sw, "Bar", Vector3.new(9, 0.5, 0.5), CFrame.new(24, GROUND + 9.8, 62), "#C23B3B")
	B.part(sw, "Seat", Vector3.new(2.2, 0.3, 1), CFrame.new(24, GROUND + 2.5, 62), "#3B6FB0")
	-- соседи
	local nb = B.folder(ext, "Neighbours")
	neighbour(nb, -48, 18, 40, 30, 22, "#D7C3E0", "#5E5A6E", 0)
	neighbour(nb, 140, 18, 44, 30, 22, "#BFD8C0", "#6B5E57", 0)
	neighbour(nb, -10, -84, 42, 30, 22, "#F0D2A6", "#6E5E57", 180)
	neighbour(nb, 50, -84, 40, 30, 22, "#C8DCEA", "#5A5E6E", 180)
	neighbour(nb, 110, -84, 42, 30, 22, "#E8C9C0", "#6E5E57", 180)
	-- фонари на улице
	for _, x in ipairs({ -20, 46, 110 }) do
		local lp = B.model(ext, "StreetLamp")
		B.part(lp, "Pole", Vector3.new(0.6, 16, 0.6), CFrame.new(x, GROUND + 8, -30), "#3A3A44")
		B.part(lp, "Arm", Vector3.new(0.4, 0.4, 3), CFrame.new(x, GROUND + 15.8, -31.3), "#3A3A44")
		B.part(lp, "Bulb", Vector3.new(1.2, 0.6, 1.2), CFrame.new(x, GROUND + 15.4, -32.6), "#FFF1C6")
	end
	return ext
end

return Exterior
