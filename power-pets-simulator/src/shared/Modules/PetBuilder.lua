--[[
	PetBuilder — собирает 3D-модель питомца из простых деталей по описанию Look из конфига Pets.
	Никаких мешей и картинок: всё из шаров, цилиндров и блоков, поэтому легко добавлять новых питомцев.

	PetBuilder.Build(petId, golden) -> Model
		Центр модели (Model.PrimaryPart "Root") находится в точке (0, 0, 0), мордочка смотрит в -Z.
		Все детали закреплены (Anchored) и не сталкиваются ни с чем — модель двигают через PivotTo / BulkMoveTo.
]]

local Config = script.Parent.Parent:WaitForChild("Config")
local Pets = require(Config.Pets)
local Rarities = require(Config.Rarities)

local PetBuilder = {}

local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(25, 20, 35)
local BLUSH = Color3.fromRGB(255, 130, 160)
local GOLD = Color3.fromRGB(255, 196, 40)
local GOLD_LIGHT = Color3.fromRGB(255, 232, 130)

-- Чем реже питомец, тем он чуть крупнее.
local RARITY_SCALE = {
	Common = 1,
	Rare = 1.05,
	Epic = 1.12,
	Legendary = 1.22,
	Mythic = 1.35,
}

local SIDES = { -1, 1 }

local function vertical(position)
	-- Цилиндр в Roblox вытянут по оси X; поворот делает его вертикальным.
	return CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
end

function PetBuilder.Build(petId, golden)
	local config = Pets[petId]
	if not config then
		warn("[PetBuilder] Нет питомца с ID", petId)
		return nil
	end

	local look = config.Look or {}
	local R = (look.Size or 1) * (RARITY_SCALE[config.Rarity] or 1)
	local main = look.Color or Color3.fromRGB(200, 200, 200)
	local accent = look.Accent or main:Lerp(WHITE, 0.55)
	local dark = main:Lerp(INK, 0.35)
	local shape = look.Shape or "Ball"

	local model = Instance.new("Model")
	model.Name = petId
	local roles = {}

	-- Создаёт деталь. kind: "Block" | "Ball" | "Cylinder" | "Ellipsoid".
	-- role: "Body" и "Accent" перекрашиваются у золотых питомцев, "Detail" — нет.
	local function add(kind, size, cframe, color, role, options)
		options = options or {}
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if kind == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif kind == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		elseif kind == "Ellipsoid" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
		part.Size = size
		part.CFrame = cframe
		part.Color = color
		part.Material = options.Material or (role == "Body" and look.Material) or Enum.Material.SmoothPlastic
		part.Transparency = options.Transparency or 0
		part.Name = options.Name or role or "Part"
		part.Parent = model
		roles[part] = role or "Detail"
		return part
	end

	-- Вектор в «единицах питомца» (масштаб R).
	local function v(x, y, z)
		return Vector3.new(x, y, z) * R
	end

	-- Цилиндр от точки a до точки b.
	local function cylinderBetween(a, b, diameter, color, role, options)
		local length = (b - a).Magnitude
		local cframe = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
		return add("Cylinder", Vector3.new(length, diameter, diameter), cframe, color, role, options)
	end

	local root = add("Block", Vector3.new(0.2, 0.2, 0.2), CFrame.identity, WHITE, "Root", { Transparency = 1, Name = "Root" })
	model.PrimaryPart = root

	-- Голова: центр и радиус, к ним крепятся глаза, уши и рога.
	local head = { Center = Vector3.zero, Radius = R }
	local tailAnchor = v(0, -0.15, 0.95)
	local hasFace = true
	local bodyOptions = { Transparency = look.Transparency }

	------------------------------------------------------------------ ТЕЛО
	if shape == "Ball" then
		add("Ball", v(2, 2, 2), CFrame.identity, main, "Body", bodyOptions)
		if look.Belly ~= false then
			add("Ellipsoid", v(1.3, 1.0, 0.5), CFrame.new(v(0, -0.4, -0.72)), accent, "Accent")
		end
	elseif shape == "Blob" then
		add("Ellipsoid", v(2.3, 1.9, 2.3), CFrame.identity, main, "Body", bodyOptions)
		add("Ellipsoid", v(1.7, 0.8, 1.7), CFrame.new(v(0, -0.7, 0)), main:Lerp(accent, 0.4), "Accent", bodyOptions)
		head = { Center = v(0, 0.05, 0), Radius = R * 1.08 }
		tailAnchor = v(0, -0.1, 1.05)
	elseif shape == "Long" then
		add("Ellipsoid", v(1.6, 1.35, 2.8), CFrame.new(v(0, -0.15, 0.55)), main, "Body", bodyOptions)
		add("Ball", v(1.7, 1.7, 1.7), CFrame.new(v(0, 0.2, -0.75)), main, "Body", bodyOptions)
		add("Ellipsoid", v(1.05, 0.55, 2.0), CFrame.new(v(0, -0.55, 0.45)), accent, "Accent")
		head = { Center = v(0, 0.2, -0.75), Radius = R * 0.85 }
		tailAnchor = v(0, -0.1, 1.85)
	elseif shape == "Box" then
		add("Block", v(1.9, 1.7, 1.6), CFrame.identity, main, "Body")
		add("Block", v(1.5, 0.85, 0.12), CFrame.new(v(0, 0.15, -0.8)), INK, "Detail")
		add("Block", v(0.9, 0.35, 0.1), CFrame.new(v(0, -0.5, -0.81)), accent, "Accent")
		for _, side in ipairs(SIDES) do
			add("Cylinder", v(0.3, 0.6, 0.6), CFrame.new(v(side * 1.05, 0.1, 0)), accent, "Accent")
		end
		tailAnchor = v(0, -0.3, 0.85)
	elseif shape == "Disc" then
		hasFace = false
		add("Cylinder", v(0.5, 3, 3), vertical(v(0, -0.25, 0)), main, "Body")
		add("Cylinder", v(0.25, 2.2, 2.2), vertical(v(0, -0.6, 0)), dark, "Body")
		add("Ellipsoid", v(1.6, 1.2, 1.6), CFrame.new(v(0, 0.25, 0)), accent, "Detail", {
			Transparency = 0.45,
			Material = Enum.Material.Glass,
		})
		-- Пилот внутри купола.
		add("Ball", v(0.8, 0.8, 0.8), CFrame.new(v(0, 0.2, 0)), Color3.fromRGB(130, 236, 120), "Detail")
		for _, side in ipairs(SIDES) do
			add("Ball", v(0.22, 0.22, 0.22), CFrame.new(v(side * 0.16, 0.28, -0.32)), INK, "Detail")
		end
		for i = 1, 8 do
			local angle = (i / 8) * math.pi * 2
			local color = (i % 2 == 0) and Color3.fromRGB(255, 230, 80) or Color3.fromRGB(255, 90, 200)
			add("Ball", v(0.3, 0.3, 0.3), CFrame.new(v(math.cos(angle) * 1.35, -0.25, math.sin(angle) * 1.35)), color, "Detail", {
				Material = Enum.Material.Neon,
			})
		end
	elseif shape == "Gem" then
		add("Block", v(1.8, 1.9, 1.5), CFrame.identity, main, "Body")
		for _, side in ipairs(SIDES) do
			add("Block", v(0.6, 1.1, 0.6), CFrame.new(v(side * 1.2, -0.3, 0)) * CFrame.Angles(0, 0, side * math.rad(-12)), main, "Body")
		end
		local shards = {
			{ v(0, 1.15, 0.1), 0, 0.6 },
			{ v(-0.55, 1.0, 0.2), -25, 0.45 },
			{ v(0.55, 1.0, 0.2), 25, 0.45 },
			{ v(-1.0, 0.75, 0.15), -45, 0.35 },
			{ v(1.0, 0.75, 0.15), 45, 0.35 },
		}
		for _, shard in ipairs(shards) do
			local height = shard[3] * 2.2
			add("Block", Vector3.new(shard[3], height, shard[3]) * R, CFrame.new(shard[1]) * CFrame.Angles(0, math.rad(45), math.rad(-shard[2])), accent, "Accent", {
				Material = Enum.Material.Neon,
				Transparency = 0.1,
			})
		end
		head = { Center = v(0, 0.1, 0.05), Radius = R * 0.92 }
	elseif shape == "Hole" then
		add("Ball", v(2, 2, 2), CFrame.identity, main, "Body")
	end

	------------------------------------------------------------------ ЛИЦО
	local function addFace()
		local c, r = head.Center, head.Radius
		local eyeColor = look.EyeColor or INK
		local eyeMaterial = look.EyeGlow and Enum.Material.Neon or nil
		local style = look.EyeStyle or (shape == "Box" and "Led") or "Ball"

		for _, side in ipairs(SIDES) do
			if style == "Led" then
				add("Block", Vector3.new(0.36, 0.24, 0.08) * r, CFrame.new(c + Vector3.new(side * 0.36, 0.17, -0.88) * r), eyeColor, "Detail", {
					Material = Enum.Material.Neon,
				})
			elseif style == "Alien" then
				local position = c + Vector3.new(side * 0.4, 0.12, -0.84) * r
				add("Ellipsoid", Vector3.new(0.44, 0.66, 0.3) * r, CFrame.new(position) * CFrame.Angles(0, 0, side * math.rad(-28)), INK, "Detail")
				add("Ball", Vector3.one * 0.13 * r, CFrame.new(position + Vector3.new(-0.06, 0.12, -0.13) * r), WHITE, "Detail")
			else
				local big = style == "Big"
				local size = big and 0.5 or 0.36
				local depth = big and -0.92 or -0.86
				if big then
					add("Ball", Vector3.one * 0.66 * r, CFrame.new(c + Vector3.new(side * 0.38, 0.14, -0.78) * r), look.EyeRing or WHITE, "Detail")
				end
				local position = c + Vector3.new(side * 0.37, 0.14, depth) * r
				add("Ball", Vector3.one * size * r, CFrame.new(position), eyeColor, "Detail", { Material = eyeMaterial })
				if not look.EyeGlow then
					add("Ball", Vector3.one * 0.12 * r, CFrame.new(position + Vector3.new(-0.06, 0.08, -size * 0.45) * r), WHITE, "Detail")
				end
			end
		end

		-- Румянец.
		if look.Blush ~= false and style ~= "Led" then
			for _, side in ipairs(SIDES) do
				local position = c + Vector3.new(side * 0.6, -0.18, -0.76) * r
				local normal = (position - c).Unit
				add("Ellipsoid", Vector3.new(0.3, 0.17, 0.08) * r, CFrame.lookAt(position, position + normal), BLUSH, "Detail", {
					Transparency = 0.2,
				})
			end
		end

		-- Мордочка и нос.
		if look.Snout then
			add("Ellipsoid", Vector3.new(0.8, 0.55, 0.6) * r, CFrame.new(c + Vector3.new(0, -0.28, -0.86) * r), accent, "Accent")
			if look.Nose then
				add("Ball", Vector3.one * 0.2 * r, CFrame.new(c + Vector3.new(0, -0.14, -1.13) * r), look.Nose, "Detail")
			end
		elseif look.Nose then
			add("Ball", Vector3.one * 0.17 * r, CFrame.new(c + Vector3.new(0, -0.08, -0.99) * r), look.Nose, "Detail")
		end

		if look.Beak then
			add("Ellipsoid", Vector3.new(0.36, 0.28, 0.5) * r, CFrame.new(c + Vector3.new(0, -0.12, -1.0) * r) * CFrame.Angles(math.rad(15), 0, 0), look.Beak, "Detail")
		end

		-- Маска енота.
		if look.Mask then
			add("Ellipsoid", Vector3.new(1.35, 0.42, 0.5) * r, CFrame.new(c + Vector3.new(0, 0.14, -0.72) * r), look.Mask, "Detail")
		end
	end

	if hasFace then
		addFace()
	end

	------------------------------------------------------------------ УШИ
	local c, r = head.Center, head.Radius
	local earColor = look.EarColor or main
	local earScale = look.EarScale or 1
	if look.Ears == "Pointy" or look.Ears == "Tiny" then
		local size = (look.Ears == "Tiny" and 0.36 or 0.62) * earScale
		for _, side in ipairs(SIDES) do
			local base = c + Vector3.new(side * 0.52, 0.82 + size * 0.15, 0.02) * r
			local tilt = CFrame.Angles(0, 0, side * math.rad(-18)) * CFrame.Angles(0, 0, math.rad(45))
			add("Block", Vector3.new(size, size, 0.22) * r, CFrame.new(base) * tilt, earColor, "Body")
			if look.Ears == "Pointy" then
				add("Block", Vector3.new(size * 0.6, size * 0.6, 0.1) * r, CFrame.new(base + Vector3.new(0, -0.03, -0.12) * r) * tilt, accent, "Accent")
			end
		end
	elseif look.Ears == "Round" then
		for _, side in ipairs(SIDES) do
			local base = c + Vector3.new(side * 0.62, 0.72, 0) * r
			add("Ball", Vector3.one * 0.56 * earScale * r, CFrame.new(base), earColor, "Body")
			add("Ball", Vector3.one * 0.32 * earScale * r, CFrame.new(base + Vector3.new(0, 0, -0.14 * earScale) * r), accent, "Accent")
		end
	elseif look.Ears == "Long" then
		for _, side in ipairs(SIDES) do
			local cframe = CFrame.new(c + Vector3.new(side * 0.38, 1.3, 0.05) * r) * CFrame.Angles(0, 0, side * math.rad(-10))
			add("Ellipsoid", Vector3.new(0.34, 1.3, 0.22) * r, cframe, earColor, "Body")
			add("Ellipsoid", Vector3.new(0.18, 1.0, 0.06) * r, cframe * CFrame.new(Vector3.new(0, 0, -0.1) * r), accent, "Accent")
		end
	elseif look.Ears == "Floppy" then
		for _, side in ipairs(SIDES) do
			local cframe = CFrame.new(c + Vector3.new(side * 0.92, 0.12, 0) * r) * CFrame.Angles(0, 0, side * math.rad(15))
			add("Ellipsoid", Vector3.new(0.36, 0.95, 0.55) * r, cframe, earColor, "Body")
		end
	end

	------------------------------------------------------------------ ХВОСТ
	local tailColor = look.TailColor or main
	local ta = tailAnchor
	if look.Tail == "Thin" then
		local a = ta
		local b = ta + v(0, 0.55, 0.65)
		cylinderBetween(a, b, 0.22 * R, tailColor, "Body")
		add("Ball", Vector3.one * 0.26 * R, CFrame.new(b), look.TailTip or tailColor, "Body")
	elseif look.Tail == "Fluffy" then
		local cframe = CFrame.new(ta + v(0, 0.35, 0.45)) * CFrame.Angles(math.rad(-40), 0, 0)
		add("Ellipsoid", v(0.6, 0.6, 1.3), cframe, tailColor, "Body")
		add("Ball", Vector3.one * 0.48 * R, cframe * CFrame.new(v(0, 0, 0.55)), look.TailTip or accent, "Accent")
	elseif look.Tail == "Puff" then
		add("Ball", Vector3.one * 0.55 * R, CFrame.new(ta + v(0, 0, 0.1)), tailColor, "Accent")
	elseif look.Tail == "Stinger" then
		local points = { v(0, -0.1, 1.05), v(0, 0.45, 1.4), v(0, 1.05, 1.35), v(0, 1.4, 0.95) }
		for i, point in ipairs(points) do
			add("Ball", Vector3.one * (0.5 - i * 0.05) * R, CFrame.new(point), main, "Body")
		end
		add("Ellipsoid", v(0.18, 0.18, 0.55), CFrame.new(v(0, 1.3, 0.6)) * CFrame.Angles(math.rad(35), 0, 0), INK, "Detail")
	elseif look.Tail == "Fins" then
		for _, side in ipairs(SIDES) do
			add("Ellipsoid", v(1.1, 0.14, 0.6), CFrame.new(ta + v(side * 0.55, 0.15, 0.25)) * CFrame.Angles(0, side * math.rad(-30), 0), accent, "Accent")
			add("Ellipsoid", v(0.9, 0.12, 0.45), CFrame.new(v(side * 0.95, -0.35, -0.05)) * CFrame.Angles(0, 0, side * math.rad(-25)), accent, "Accent")
		end
		-- Звёздочки на спине кита.
		for i = 1, 5 do
			add("Ball", Vector3.one * 0.14 * R, CFrame.new(v((i - 3) * 0.22, 0.52 - math.abs(i - 3) * 0.04, 0.35 + (i % 2) * 0.35)), WHITE, "Detail", {
				Material = Enum.Material.Neon,
			})
		end
	elseif look.Tail == "Flame" then
		local flameColors = { look.Accent or Color3.fromRGB(255, 160, 40), Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 90, 30) }
		for i = 1, 3 do
			add("Ellipsoid", Vector3.new(0.9 - i * 0.2, 0.9 - i * 0.2, 1.1) * R, CFrame.new(ta + v(0, 0.12 * i, 0.35 + i * 0.45)), flameColors[i], "Detail", {
				Material = Enum.Material.Neon,
				Transparency = 0.15 + i * 0.12,
			})
		end
	end

	------------------------------------------------------------------ КРЫЛЬЯ
	local wingColor = look.WingColor or accent
	if look.Wings == "Feather" then
		for _, side in ipairs(SIDES) do
			local cframe = CFrame.new(v(side * 1.0, 0.15, 0.3)) * CFrame.Angles(0, 0, side * math.rad(-40))
			add("Ellipsoid", v(0.2, 0.9, 1.0), cframe, wingColor, "Accent")
			add("Ellipsoid", v(0.16, 0.6, 0.8), cframe * CFrame.new(v(0, 0.5, 0.15)), wingColor:Lerp(WHITE, 0.25), "Accent")
		end
	elseif look.Wings == "Bat" then
		for _, side in ipairs(SIDES) do
			local cframe = CFrame.new(v(side * 1.1, 0.35, 0.35)) * CFrame.Angles(0, 0, side * math.rad(-50))
			add("Ellipsoid", v(0.12, 1.1, 1.2), cframe, wingColor, "Accent")
			add("Ellipsoid", v(0.1, 0.7, 0.5), cframe * CFrame.new(v(0, 0.55, -0.35)), wingColor:Lerp(INK, 0.2), "Accent")
		end
	elseif look.Wings == "Bug" then
		for _, side in ipairs(SIDES) do
			local cframe = CFrame.new(v(side * 0.7, 0.62, 0.45)) * CFrame.Angles(0, 0, side * math.rad(-28))
			add("Ellipsoid", v(0.08, 0.7, 1.1), cframe, Color3.fromRGB(220, 250, 255), "Detail", { Transparency = 0.4 })
		end
	end

	------------------------------------------------------------------ УКРАШЕНИЯ
	if look.Horn then
		add("Ellipsoid", Vector3.new(0.24, 1.0, 0.24) * r, CFrame.new(c + Vector3.new(0, 1.12, -0.42) * r) * CFrame.Angles(math.rad(-25), 0, 0), look.Horn, "Detail", {
			Material = Enum.Material.Neon,
		})
	end

	if look.Horns == "Dragon" then
		for _, side in ipairs(SIDES) do
			local cframe = CFrame.new(c + Vector3.new(side * 0.45, 0.98, 0.15) * r) * CFrame.Angles(math.rad(30), 0, side * math.rad(-15))
			add("Ellipsoid", Vector3.new(0.22, 0.85, 0.22) * r, cframe, look.HornColor or accent, "Detail")
		end
	elseif look.Horns == "Antlers" then
		local hornColor = look.HornColor or Color3.fromRGB(170, 120, 80)
		local hornMaterial = look.Glow and Enum.Material.Neon or nil
		for _, side in ipairs(SIDES) do
			local base = c + Vector3.new(side * 0.4, 0.8, 0) * r
			local top = c + Vector3.new(side * 0.95, 1.65, 0.1) * r
			local middle = base:Lerp(top, 0.5)
			cylinderBetween(base, top, 0.13 * r, hornColor, "Detail", { Material = hornMaterial })
			cylinderBetween(middle, c + Vector3.new(side * 0.35, 1.55, -0.1) * r, 0.11 * r, hornColor, "Detail", { Material = hornMaterial })
			cylinderBetween(top, c + Vector3.new(side * 1.3, 1.85, 0) * r, 0.1 * r, hornColor, "Detail", { Material = hornMaterial })
		end
	end

	if look.Antenna then
		local antennaColor = look.AntennaColor or accent
		local count = look.Antenna
		for i = 1, count do
			local offsetX = count == 1 and 0 or (i == 1 and -0.38 or 0.38)
			local base = c + Vector3.new(offsetX, 0.85, 0) * r
			local tip = c + Vector3.new(offsetX * 1.6, 1.6, -0.05) * r
			cylinderBetween(base, tip, 0.08 * r, INK, "Detail")
			add("Ball", Vector3.one * 0.3 * r, CFrame.new(tip), antennaColor, "Detail", { Material = Enum.Material.Neon })
		end
	end

	if look.Halo then
		for i = 1, 14 do
			local angle = (i / 14) * math.pi * 2
			add("Ball", Vector3.one * 0.2 * r, CFrame.new(c + Vector3.new(math.cos(angle) * 0.62, 1.5, math.sin(angle) * 0.62) * r), Color3.fromRGB(255, 225, 90), "Detail", {
				Material = Enum.Material.Neon,
			})
		end
	end

	if look.Crown then
		local crownY = look.Headdress and 1.15 or 0.98
		add("Cylinder", Vector3.new(0.32, 1.05, 1.05) * r, vertical(c + Vector3.new(0, crownY, 0.05) * r), GOLD, "Detail", { Material = Enum.Material.Metal })
		for i = 1, 5 do
			local angle = (i / 5) * math.pi * 2
			local position = c + Vector3.new(math.cos(angle) * 0.42, crownY + 0.25, 0.05 + math.sin(angle) * 0.42) * r
			add("Block", Vector3.new(0.22, 0.22, 0.22) * r, CFrame.new(position) * CFrame.Angles(math.rad(45), 0, math.rad(45)), GOLD, "Detail", { Material = Enum.Material.Metal })
		end
		add("Ball", Vector3.one * 0.18 * r, CFrame.new(c + Vector3.new(0, crownY, -0.5) * r), Color3.fromRGB(255, 60, 90), "Detail", { Material = Enum.Material.Neon })
	end

	if look.Headdress then
		-- Платок-немес: капюшон сзади и полосы по бокам.
		add("Ellipsoid", Vector3.new(2.2, 1.7, 2.0) * r, CFrame.new(c + Vector3.new(0, 0.3, 0.2) * r), look.Headdress, "Detail")
		for _, side in ipairs(SIDES) do
			add("Block", Vector3.new(0.45, 1.25, 0.3) * r, CFrame.new(c + Vector3.new(side * 0.88, -0.45, -0.25) * r), look.Headdress, "Detail")
			add("Block", Vector3.new(0.47, 0.18, 0.32) * r, CFrame.new(c + Vector3.new(side * 0.88, -0.2, -0.25) * r), GOLD, "Detail")
			add("Block", Vector3.new(0.47, 0.18, 0.32) * r, CFrame.new(c + Vector3.new(side * 0.88, -0.7, -0.25) * r), GOLD, "Detail")
		end
		add("Block", Vector3.new(1.9, 0.16, 0.3) * r, CFrame.new(c + Vector3.new(0, 0.62, -0.62) * r) * CFrame.Angles(math.rad(-25), 0, 0), GOLD, "Detail")
	end

	if look.Spikes then
		for i = 1, 14 do
			local around = math.rad(-110 + (i - 1) % 7 * (220 / 6))
			local elevation = math.rad(i <= 7 and 20 or 55)
			local direction = Vector3.new(math.sin(around) * math.cos(elevation), math.sin(elevation), math.cos(around) * math.cos(elevation))
			local position = c + direction * 0.95 * r
			add("Ellipsoid", Vector3.new(0.24, 0.24, 0.75) * r, CFrame.lookAt(position, position + direction), look.Spikes, "Body")
		end
	end

	if look.Bandage then
		local bands = { -0.55, -0.05, 0.45 }
		for i, y in ipairs(bands) do
			local diameter = 2 * math.sqrt(math.max(0, 1 - y * y)) + 0.06
			add("Cylinder", Vector3.new(0.18, diameter, diameter) * r, vertical(c + Vector3.new(0, y, 0) * r) * CFrame.Angles(0, 0, math.rad(i * 7 - 14)), accent, "Accent")
		end
	end

	if look.Hump then
		add("Ball", Vector3.one * 0.95 * R, CFrame.new(v(0, 0.8, 0.4)), main, "Body")
	end

	if look.Claws then
		for _, side in ipairs(SIDES) do
			local base = v(side * 0.85, -0.35, -0.75)
			add("Ellipsoid", v(0.5, 0.32, 0.65), CFrame.new(base) * CFrame.Angles(0, side * math.rad(-20), 0), main, "Body")
			add("Ellipsoid", v(0.18, 0.18, 0.4), CFrame.new(base + v(side * -0.12, 0.08, -0.4)) * CFrame.Angles(0, side * math.rad(25), 0), accent, "Accent")
		end
	end

	if look.Mane then
		local points = { v(0, 0.98, 0.05), v(0, 0.85, 0.45), v(0, 0.55, 0.8), v(0, 0.15, 0.98), v(0, -0.25, 0.95) }
		for i, point in ipairs(points) do
			local color = look.Mane[(i - 1) % #look.Mane + 1]
			add("Ball", Vector3.one * 0.5 * R, CFrame.new(point), color, "Detail")
		end
	end

	if look.Helmet then
		add("Ball", Vector3.one * 2.6 * r, CFrame.new(c), Color3.fromRGB(200, 240, 255), "Detail", {
			Transparency = 0.7,
			Material = Enum.Material.Glass,
		})
		add("Cylinder", Vector3.new(0.3, 2.0, 2.0) * r, vertical(c + Vector3.new(0, -1.0, 0) * r), Color3.fromRGB(220, 225, 240), "Detail", {
			Material = Enum.Material.Metal,
		})
	end

	if look.Ring then
		local tilt = CFrame.Angles(0, math.rad(20), math.rad(12))
		add("Cylinder", Vector3.new(0.06, 3.4, 3.4) * R, vertical(Vector3.zero) * tilt, look.Ring, "Detail", {
			Material = Enum.Material.Neon,
			Transparency = 0.25,
		})
		if look.Ring2 then
			add("Cylinder", Vector3.new(0.05, 2.6, 2.6) * R, vertical(Vector3.zero) * CFrame.Angles(0, math.rad(-15), math.rad(-20)), look.Ring2, "Detail", {
				Material = Enum.Material.Neon,
				Transparency = 0.3,
			})
		end
	end

	------------------------------------------------------------------ ЗОЛОТО И СВЕЧЕНИЕ
	if golden then
		for part, role in pairs(roles) do
			if role == "Body" then
				part.Color = GOLD
				part.Material = Enum.Material.SmoothPlastic
				part.Reflectance = 0.25
			elseif role == "Accent" then
				part.Color = GOLD_LIGHT
				part.Reflectance = 0.15
			end
		end
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = GOLD
		sparkles.Parent = root
	end

	if look.Glow or golden or config.Rarity == "Legendary" or config.Rarity == "Mythic" then
		local light = Instance.new("PointLight")
		light.Color = golden and GOLD or (look.GlowColor or Rarities[config.Rarity].Color)
		light.Range = 8 * R
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = root
	end

	return model
end

-- Список деталей модели и их смещения относительно центра (для быстрого движения через BulkMoveTo).
function PetBuilder.GetParts(model)
	local parts, offsets = {}, {}
	local pivot = model:GetPivot()
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
			table.insert(offsets, pivot:ToObjectSpace(descendant.CFrame))
		end
	end
	return parts, offsets
end

return PetBuilder
