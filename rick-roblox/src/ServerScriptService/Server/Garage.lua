-- Гараж-лаборатория Рика (внутри гаража из House.lua): космический корабль Рика, верстак с инструментами,
-- большой экран, полки с гаджетами, бак с портальной жидкостью, лампы дневного света, кнопка ворот.
-- Метки для сюжета (главы 2) — в папке House.Markers, имена начинаются с G.
local Garage = {}

local B, C

-- внутренние границы гаража
local X0, X1, Z0, Z1 = 56.7, 80.3, -0.3, 25.3
local Y0, Y1 = 0, 11.4

local function item(parent, name, cf, outline)
	local m = B.model(parent, name)
	if outline ~= false then B.outline(m) end
	return m, B.kit(m, cf)
end

local function ellipsoid(parent, name, size, cf, color, mat, props)
	local p = B.ball(parent, name, 1, cf, color, mat, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = size
	mesh.Parent = p
	return p
end

-- космический корабль Рика: овальный корпус, стеклянный купол, плавники, двигатели
local function cruiser(parent)
	local base = CFrame.new(62.2, Y0, 13.5)
	local m = B.model(parent, "SpaceCruiser")
	B.outline(m)
	local function at(x, y, z, rot) local c = base * CFrame.new(x, y, z); if rot then c = c * rot end; return c end
	ellipsoid(m, "Hull", Vector3.new(7.2, 2.6, 12.5), at(0, 2.7, 0), "#8FA39A")
	ellipsoid(m, "Belly", Vector3.new(6.6, 1.3, 11.5), at(0, 1.75, 0), "#6E7F77")
	B.part(m, "Stripe", Vector3.new(7.3, 0.25, 9), at(0, 2.9, 0.3), "#C9493E")
	local dome = ellipsoid(m, "Dome", Vector3.new(4.4, 2.6, 5.2), at(0, 3.9, -0.6), "#BFE6F5", Enum.Material.Glass, { Transparency = 0.45 })
	local _ = dome
	B.part(m, "SeatL", Vector3.new(1.2, 1.4, 1.2), at(-0.9, 3.5, 0.1), "#5A3A2A")
	B.part(m, "SeatR", Vector3.new(1.2, 1.4, 1.2), at(0.9, 3.5, 0.1), "#5A3A2A")
	B.part(m, "Wheel", Vector3.new(0.9, 0.9, 0.2), at(-0.9, 3.9, -1.5) * CFrame.Angles(math.rad(-30), 0, 0), "#2B2B33")
	-- нос и фары
	ellipsoid(m, "Nose", Vector3.new(3.6, 1.4, 2.2), at(0, 2.4, -5.6), "#7D9088")
	B.ball(m, "LightL", 0.6, at(-1.6, 2.6, -6.0), "#FFF6C2", Enum.Material.Neon)
	B.ball(m, "LightR", 0.6, at(1.6, 2.6, -6.0), "#FFF6C2", Enum.Material.Neon)
	-- плавники
	for _, s in ipairs({ -1, 1 }) do
		B.wedge(m, "Fin", Vector3.new(0.3, 1.8, 3.2), at(s * 3.7, 2.6, 3.4) * CFrame.Angles(0, 0, s * math.rad(-20)), "#C9493E")
		B.cyl(m, "Thruster", 1.8, 1.5, at(s * 1.7, 2.4, 6.4) * CFrame.Angles(0, math.rad(90), 0), "#5E6B66", Enum.Material.Metal)
		B.cyl(m, "Flame", 0.1, 1.1, at(s * 1.7, 2.4, 7.32) * CFrame.Angles(0, math.rad(90), 0), "#FF9A2E", Enum.Material.Neon)
		for _, z in ipairs({ -3.5, 3.5 }) do
			B.vcyl(m, "Leg", 1.4, 0.3, at(s * 2.4, 0.7, z), "#5E6B66", Enum.Material.Metal)
			B.vcyl(m, "Pad", 0.15, 1.0, at(s * 2.4, 0.08, z), "#3A3A44")
		end
	end
	B.vcyl(m, "Antenna", 1.6, 0.12, at(1.4, 5.3, 1.6), "#C9CFD6", Enum.Material.Metal)
	B.ball(m, "AntennaTip", 0.3, at(1.4, 6.15, 1.6), "#FF3B30", Enum.Material.Neon)
	return m
end

function Garage.build(ctx, root)
	B, C = ctx.Build, ctx.Config
	local G = B.folder(root, "GarageLab")
	local lights = root:FindFirstChild("Lights")
	local marks = root:FindFirstChild("Markers")
	local function mark(name, cf) return B.marker(marks, name, Vector3.new(1, 1, 1), cf) end

	-- отделка: внутренняя стена со стороны дома (с проёмом двери в кладовую), пятна масла на полу
	local lining = B.model(G, "Lining")
	B.wall(lining, "W", Vector3.new(X0 + 0.15, Y0, Z0), Vector3.new(X0 + 0.15, Y0, Z1), Y1, 0.3, "#CFC9BC", nil,
		{ { at = 7 - Z0, w = 4.8, y0 = 0, y1 = 8.2 } })
	B.part(lining, "Stripe", Vector3.new(0.05, 0.6, Z1 - Z0), CFrame.new(X0 + 0.32, 1.2, (Z0 + Z1) / 2), "#E2B13C")
	for _, s in ipairs({ { 66, 4, 2.4 }, { 73, 17, 1.6 }, { 70.5, 9, 1.2 } }) do
		B.vcyl(G, "OilStain", 0.02, s[3], CFrame.new(s[1], 0.012, s[2]), "#4E4B47", nil, { CanCollide = false, CastShadow = false })
	end

	-- лампы дневного света
	for k, z in ipairs({ 5.5, 13, 20.5 }) do
		B.part(G, "LampHousing", Vector3.new(8.4, 0.3, 1.0), CFrame.new(68.5, Y1 - 0.2, z), "#D6DCE3", Enum.Material.Metal)
		local tube = B.part(lights, "Tube", Vector3.new(7.8, 0.22, 0.4), CFrame.new(68.5, Y1 - 0.42, z), "#F4FBFF", Enum.Material.SmoothPlastic, { CastShadow = false })
		B.attrs(tube, { Room = "Garage", Glow = true })
		B.light(tube, "PointLight", { Color = Color3.fromRGB(225, 240, 255), Brightness = 1.4, Range = 20, Enabled = false, Shadows = k == 2 })
	end

	cruiser(G)

	-- верстак у дальней стены, над ним — большой экран и перфопанель с инструментами
	local bench, P = item(G, "Workbench", CFrame.new(70, Y0, Z1 - 1.0))
	P("Top", 15, 0.3, 2.0, 0, 3.0, 0, "#9C6B3D")
	P("Shelf", 14.6, 0.2, 1.8, 0, 0.8, 0, "#8C5733")
	for _, x in ipairs({ -7.2, -2.4, 2.4, 7.2 }) do P("Leg", 0.3, 2.9, 0.3, x, 1.45, -0.8, "#5A3A2A") end
	P("Vise", 0.9, 0.7, 0.6, -6, 3.5, -0.4, "#3B6FB0", Enum.Material.Metal)
	P("Laptop", 1.6, 0.08, 1.1, -3.4, 3.2, 0, "#2B2B33")
	P("LaptopScreen", 1.6, 1.0, 0.06, -3.4, 3.7, 0.5, "#13324F", nil, nil, CFrame.Angles(math.rad(-12), 0, 0))
	for k = 0, 2 do
		P.vcyl("Beaker", 0.8, 0.45, 1 + k * 0.7, 3.55, -0.2, "#DDF2FF", Enum.Material.Glass, { Transparency = 0.4 })
		P.vcyl("Goo", 0.45, 0.38, 1 + k * 0.7, 3.4, -0.2, (k == 1) and "#FF3DD1" or "#7CFF4A", Enum.Material.Neon)
	end
	P("Crate", 1.6, 1.0, 1.4, 5.6, 1.4, 0, "#B98552")
	-- маленький робот на верстаке (тот самый, что «передаёт масло»)
	P("RobotBody", 0.9, 0.5, 0.9, 4.2, 3.4, -0.2, "#C9CFD6", Enum.Material.Metal)
	P("RobotEye", 0.35, 0.35, 0.1, 4.2, 3.45, -0.67, "#29E6FF", Enum.Material.Neon)
	P("RobotArm", 0.12, 0.6, 0.12, 4.8, 3.6, -0.2, "#8E969E", nil, nil, CFrame.Angles(0, 0, math.rad(-30)))
	local _b = bench
	-- перфопанель с инструментами (слева от экрана)
	local peg = B.part(G, "Pegboard", Vector3.new(4.6, 4, 0.15), CFrame.new(61.3, 5.8, Z1 - 0.1), "#C9A46B")
	local pg = B.surface(peg, Enum.NormalId.Front, 30)
	for i = 0, 8 do for j = 0, 7 do B.circle(pg, 0.04 + i * 0.115, 0.05 + j * 0.125, 0.025, 0.025, "#7A5A3A") end end
	B.part(G, "Wrench", Vector3.new(0.25, 1.8, 0.1), CFrame.new(60, 6.2, Z1 - 0.25) * CFrame.Angles(0, 0, math.rad(15)), "#C9CFD6", Enum.Material.Metal)
	B.part(G, "HammerHandle", Vector3.new(0.2, 1.6, 0.12), CFrame.new(61.3, 5.6, Z1 - 0.25), "#9C6B3D")
	B.part(G, "HammerHead", Vector3.new(0.9, 0.35, 0.3), CFrame.new(61.3, 6.45, Z1 - 0.28), "#5E6B66", Enum.Material.Metal)
	B.part(G, "Saw", Vector3.new(1.4, 0.6, 0.05), CFrame.new(62.6, 6.6, Z1 - 0.22), "#D6DCE3", Enum.Material.Metal)
	-- большой экран (его рисует клиент во время рассказа Рика)
	local scr = B.part(G, "LabScreen", Vector3.new(10, 5.2, 0.3), CFrame.new(71, 6.8, Z1 - 0.2), "#111418")
	B.part(G, "ScreenFrame", Vector3.new(10.5, 5.7, 0.2), CFrame.new(71, 6.8, Z1 - 0.08), "#3A3A44", Enum.Material.Metal)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Display"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(800, 416)
	sg.LightInfluence = 0
	sg.Brightness = 1.6
	sg.ClipsDescendants = true
	sg.Parent = scr
	B.rect(sg, 0, 0, 1, 1, "#0B1A12", { Name = "Bg" })
	B.text(sg, 0.05, 0.4, 0.9, 0.2, "RICK OS · ожидание…", "#7CFF4A", Enum.Font.Code, { Name = "Idle", ZIndex = 2 })
	-- провода от экрана к баку
	B.cyl(G, "Cable", 9, 0.25, CFrame.new(74.5, 0.13, 20.5) * CFrame.Angles(0, math.rad(-35), 0), "#222226")
	B.cyl(G, "Cable", 6, 0.25, CFrame.new(66.5, 0.13, 22.5) * CFrame.Angles(0, math.rad(10), 0), "#2B2B33")

	-- полки у восточной стены с гаджетами
	local sh, S = item(G, "Shelves", CFrame.new(X1 - 1.0, Y0, 8))
	for i = 0, 3 do S("Shelf", 1.8, 0.15, 7, 0, 0.6 + i * 2.2, 0, "#8E969E", Enum.Material.Metal) end
	S("Post", 0.15, 7.4, 0.15, -0.8, 3.7, -3.4, "#6E767E", Enum.Material.Metal)
	S("Post", 0.15, 7.4, 0.15, -0.8, 3.7, 3.4, "#6E767E", Enum.Material.Metal)
	local gadgetCols = { "#7CFF4A", "#29E6FF", "#FF3DD1", "#FFD23D" }
	for i = 0, 2 do
		for k = 0, 2 do
			local y = 0.75 + i * 2.2
			if (i + k) % 2 == 0 then
				S("Box", 1.2, 1.0, 1.4, -0.1, y + 0.5, -2.2 + k * 2.2, "#B98552")
			else
				S.ball("Gadget", 0.8, -0.1, y + 0.45, -2.2 + k * 2.2, gadgetCols[(i + k) % 4 + 1], Enum.Material.Neon)
				S("Base", 0.9, 0.2, 0.9, -0.1, y + 0.1, -2.2 + k * 2.2, "#3A3A44")
			end
		end
	end
	S("Helmet", 1.1, 0.9, 1.1, -0.1, 7.6 + 0.45, 0, "#C9CFD6", Enum.Material.Metal)
	local _s = sh
	-- бак с портальной жидкостью (светится и пузырится)
	local tank, T = item(G, "PortalTank", CFrame.new(X1 - 1.6, Y0, 15.5))
	T.vcyl("Base", 0.6, 3, 0, 0.3, 0, "#3A3A44", Enum.Material.Metal)
	T.vcyl("Glass", 5.5, 2.6, 0, 3.35, 0, "#DDF2FF", Enum.Material.Glass, { Transparency = 0.55 })
	local fluid = T.vcyl("Fluid", 4.6, 2.3, 0, 2.95, 0, "#7CFF4A", Enum.Material.Neon, { Transparency = 0.15 })
	T.vcyl("Cap", 0.5, 3, 0, 6.35, 0, "#3A3A44", Enum.Material.Metal)
	B.light(fluid, "PointLight", { Color = Color3.fromRGB(120, 255, 80), Brightness = 1.2, Range = 14, Shadows = false })
	local bub = Instance.new("ParticleEmitter")
	bub.Rate = 6
	bub.Lifetime = NumberRange.new(1.5, 2.5)
	bub.Speed = NumberRange.new(1, 2)
	bub.SpreadAngle = Vector2.new(8, 8)
	bub.Size = NumberSequence.new(0.18)
	bub.Color = ColorSequence.new(Color3.fromRGB(220, 255, 190))
	bub.LightEmission = 1
	bub.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	bub.EmissionDirection = Enum.NormalId.Right
	bub.Parent = fluid
	local _t = tank
	-- доска с формулами
	local board = B.part(G, "Chalkboard", Vector3.new(0.15, 3.6, 6), CFrame.new(X1 - 0.1, 6.2, 21.5), "#24352A")
	local bg = B.surface(board, Enum.NormalId.Left, 40)
	B.rect(bg, 0, 0, 1, 1, "#24352A")
	B.text(bg, 0.05, 0.08, 0.9, 0.2, "Ψ(x) = ∞ / 0 ?!", "#E9F2EA", Enum.Font.AmaticSC)
	B.text(bg, 0.05, 0.36, 0.9, 0.2, "портал → С-137", "#E9F2EA", Enum.Font.AmaticSC)
	B.text(bg, 0.05, 0.64, 0.9, 0.2, "НЕ ТРОГАТЬ, МОРТИ", "#FFB4B4", Enum.Font.AmaticSC)
	-- бочки с ядовито-зелёным содержимым
	for k, z in ipairs({ 1.6, 3.8 }) do
		local bm, Bb = item(G, "Barrel", CFrame.new(X1 - 1.4, Y0, z))
		Bb.vcyl("Barrel", 2.6, 1.8, 0, 1.3, 0, (k == 1) and "#2F6B3A" or "#3B6FB0", Enum.Material.Metal)
		Bb.vcyl("Ring", 0.15, 1.85, 0, 0.6, 0, "#222226", Enum.Material.Metal)
		Bb.vcyl("Ring", 0.15, 1.85, 0, 2.0, 0, "#222226", Enum.Material.Metal)
		Bb.vcyl("Goo", 0.05, 1.5, 0, 2.62, 0, "#7CFF4A", Enum.Material.Neon)
		local _bm = bm
	end
	-- холодильник Рика
	local fr, F = item(G, "LabFridge", CFrame.new(X0 + 1.6, Y0, Z1 - 1.6) * CFrame.Angles(0, math.rad(90), 0))
	F("Body", 2.6, 6, 2.4, 0, 3, 0, "#E8E4D8")
	F("Handle", 0.15, 1.6, 0.2, -1.0, 4.2, -1.3, "#C9CFD6", Enum.Material.Metal)
	local sticker = F("Sticker", 1.2, 0.6, 0.03, 0.2, 4.6, -1.22, "#FFD23D")
	B.sign(sticker, Enum.NormalId.Front, "НЕ ТРОГАТЬ!", { TextColor3 = Color3.fromRGB(180, 30, 30), Font = Enum.Font.GothamBlack })
	local _f = fr
	-- кнопка ворот у двери
	local panel = B.part(G, "DoorPanel", Vector3.new(0.9, 1.3, 0.2), CFrame.new(78.6, 4.2, Z0 + 0.12), "#3A3A44", Enum.Material.Metal)
	local button = B.part(G, "DoorButton", Vector3.new(0.45, 0.45, 0.2), CFrame.new(78.6, 4.35, Z0 + 0.25), "#D23B3B", Enum.Material.Neon)
	local _p = panel
	-- метки для сюжета
	mark("GPortal", CFrame.lookAt(Vector3.new(72, 5.6, 3.6), Vector3.new(72, 5.6, 20)))
	mark("GMorty", CFrame.lookAt(Vector3.new(72, 3, 7.6), Vector3.new(72, 3, 20)))
	mark("GRick", CFrame.lookAt(Vector3.new(69.6, 0, 8.4), Vector3.new(69.6, 0, 20)))
	mark("GRickTalk", CFrame.lookAt(Vector3.new(65.6, 0, 21.4), Vector3.new(72.2, 0, 13.5)))
	mark("GMortyTalk", CFrame.lookAt(Vector3.new(72.2, 3, 13.5), Vector3.new(71, 3, 22)))
	mark("GOutside", CFrame.new(68.85, -1.2, -8))
	mark("GInvasion", CFrame.new(68.85, -1.2, -12))
	mark("GButton", button.CFrame)
	return G
end

return Garage
