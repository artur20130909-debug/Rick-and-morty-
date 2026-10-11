-- Строит карту при запуске сервера: земля, тёмный лес с тропинками, поляна с костром и лавкой
-- в центре, 8 баз по кругу. World.build() -> { bases = { Model... }, shop = Part }.
-- База смотрит дверью на центр карты (это её локальное −Z). Клетки — у задней стены.
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local B = require(Shared.Build)

local World = {}

local MAP = Config.Map
local rad = math.rad
local hex = Color3.fromHex

local BASE_COLORS = { "#3d5a80", "#7a3b3b", "#3b7a52", "#7a6a3b", "#5a3b7a", "#3b6f7a", "#7a3b66", "#4f4f4f" }

-- клетки: 2 ряда по 6, сначала центральные у задней стены
local SLOT_X = { -5, 5, -15, 15, -25, 25 }
local SLOT_ROWS = { 22, 8 }
local function slotOffsets()
	local out = {}
	for _, z in ipairs(SLOT_ROWS) do
		for _, x in ipairs(SLOT_X) do table.insert(out, Vector3.new(x, 0, z)) end
	end
	return out
end
World.SlotOffsets = slotOffsets()

---------------------------------------------------------------- лес
local function tree(parent, rng, x, z)
	local m = B.model(parent, "Tree")
	local h = rng:NextNumber(14, 24)
	local d = rng:NextNumber(1.6, 2.8)
	local dead = rng:NextNumber() < 0.3
	local bark = dead and hex("#3b3330") or hex("#4a3628")
	B.vcyl(m, "Trunk", h, d, CFrame.new(x, h / 2, z), bark, Enum.Material.Wood)
	if dead then
		for i = 1, rng:NextInteger(2, 4) do
			local y = h * rng:NextNumber(0.5, 0.9)
			local yaw = rng:NextNumber(0, 360)
			local len = rng:NextNumber(4, 7)
			local cf = CFrame.new(x, y, z) * CFrame.Angles(0, rad(yaw), rad(rng:NextNumber(20, 45))) * CFrame.new(len / 2, 0, 0)
			B.part(m, "Branch", Vector3.new(len, 0.6, 0.6), cf, bark, Enum.Material.Wood)
		end
	else
		local leaf = rng:NextNumber() < 0.5 and hex("#1f3b24") or hex("#24432a")
		B.ball(m, "Leaves", rng:NextNumber(9, 13), CFrame.new(x, h, z), leaf, Enum.Material.Grass)
		B.ball(m, "Leaves", rng:NextNumber(6, 9), CFrame.new(x + rng:NextNumber(-3, 3), h + 3.5, z + rng:NextNumber(-3, 3)), leaf, Enum.Material.Grass)
	end
	return m
end

local function mushroom(parent, rng, x, z)
	local colors = { hex("#40e0ff"), hex("#b06bff"), hex("#7dff6b") }
	local col = colors[rng:NextInteger(1, #colors)]
	B.vcyl(parent, "Stem", 0.8, 0.3, CFrame.new(x, 0.4, z), hex("#d8d0c0"))
	B.vcyl(parent, "Cap", 0.4, 1.2, CFrame.new(x, 0.9, z), col, Enum.Material.Neon)
end

-- расстояние от точки до ближайшей тропы (лучи от центра к базам)
local function pathDist(x, z)
	local best = math.huge
	for i = 1, MAP.BaseCount do
		local a = rad((i - 1) * 360 / MAP.BaseCount)
		local dx, dz = math.cos(a), math.sin(a)
		local along = x * dx + z * dz
		if along > 0 then
			local px, pz = x - dx * along, z - dz * along
			best = math.min(best, math.sqrt(px * px + pz * pz))
		end
	end
	return best
end

local function buildForest(map)
	local rng = Random.new(20261011)
	local forest = B.model(map, "Forest")
	local trees = 0
	local tries = 0
	while trees < 170 and tries < 3000 do
		tries = tries + 1
		local r = math.sqrt(rng:NextNumber(MAP.ForestMin ^ 2, MAP.ForestMax ^ 2))
		local a = rng:NextNumber(0, math.pi * 2)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if pathDist(x, z) > 9 then
			tree(forest, rng, x, z)
			trees = trees + 1
		end
	end
	local props = B.model(map, "Props")
	for _ = 1, 40 do
		local r = rng:NextNumber(MAP.SafeRadius + 6, MAP.ForestMax + 20)
		local a = rng:NextNumber(0, math.pi * 2)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if pathDist(x, z) > 7 then
			local s = rng:NextNumber(2, 5)
			local cf = CFrame.new(x, s * 0.25, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3))
			B.part(props, "Rock", Vector3.new(s * 1.3, s * 0.7, s), cf, hex("#55585e"), Enum.Material.Slate)
		end
	end
	for _ = 1, 90 do
		local r = rng:NextNumber(MAP.SafeRadius + 4, MAP.ForestMax)
		local a = rng:NextNumber(0, math.pi * 2)
		mushroom(props, rng, math.cos(a) * r, math.sin(a) * r)
	end
end

local function buildPaths(map)
	local paths = B.model(map, "Paths")
	local from, to = MAP.SafeRadius - 2, MAP.BaseRadius - MAP.BaseSize / 2 + 2
	for i = 1, MAP.BaseCount do
		local a = (i - 1) * 360 / MAP.BaseCount
		local dir = Vector3.new(math.cos(rad(a)), 0, math.sin(rad(a)))
		local mid = dir * ((from + to) / 2)
		local cf = CFrame.lookAt(Vector3.new(mid.X, 0.05, mid.Z), Vector3.new(mid.X, 0.05, mid.Z) + dir)
		B.part(paths, "Path", Vector3.new(10, 0.1, to - from), cf, hex("#5e4f3c"), Enum.Material.Ground, { CanQuery = false })
		-- фонари вдоль тропы
		for k = 1, 3 do
			local p = dir * (from + (to - from) * k / 4) + Vector3.new(-dir.Z, 0, dir.X) * 6.5
			B.vcyl(paths, "LampPost", 9, 0.5, CFrame.new(p.X, 4.5, p.Z), hex("#2b2b2b"), Enum.Material.Metal)
			local lamp = B.part(paths, "Lamp", Vector3.new(1.4, 1.4, 1.4), CFrame.new(p.X, 9.4, p.Z), hex("#ffcf7a"), Enum.Material.Neon)
			B.light(lamp, "PointLight", { Range = 18, Brightness = 1.3, Color = hex("#ffc27a"), Shadows = false })
		end
	end
end

---------------------------------------------------------------- центр: костёр и лавка
local function buildClearing(map)
	local c = B.model(map, "Clearing")
	B.vcyl(c, "Ground", 0.2, MAP.SafeRadius * 2, CFrame.new(0, 0.1, 0), hex("#5b4a36"), Enum.Material.Ground)
	local fire = B.part(c, "Campfire", Vector3.new(4, 1, 4), CFrame.new(0, 0.7, 0), hex("#3a2a1c"), Enum.Material.Wood)
	B.cyl(c, "Log", 6, 1, CFrame.new(0, 0.8, 0) * CFrame.Angles(0, rad(30), 0), hex("#5a3d26"), Enum.Material.Wood)
	B.cyl(c, "Log", 6, 1, CFrame.new(0, 0.8, 0) * CFrame.Angles(0, rad(-30), 0), hex("#5a3d26"), Enum.Material.Wood)
	for i = 0, 9 do
		local a = rad(i * 36)
		B.ball(c, "Stone", 1.4, CFrame.new(math.cos(a) * 3.6, 0.5, math.sin(a) * 3.6), hex("#6b6f75"), Enum.Material.Slate)
	end
	local f = Instance.new("Fire")
	f.Size = 7
	f.Heat = 12
	f.Color = hex("#ff8a2a")
	f.SecondaryColor = hex("#ffd84a")
	f.Parent = fire
	B.light(fire, "PointLight", { Range = 45, Brightness = 2.2, Color = hex("#ffb36b") })
	-- брёвна-скамейки
	for i = 0, 3 do
		local a = rad(45 + i * 90)
		local cf = CFrame.new(math.cos(a) * 11, 0.8, math.sin(a) * 11) * CFrame.Angles(0, -(a + rad(90)), 0)
		B.cyl(c, "Bench", 7, 1.6, cf, hex("#5a3d26"), Enum.Material.Wood)
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(0, 0.3, 16)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = c
	-- безопасная зона (для клиента и монстров)
	B.marker(c, "SafeZone", Vector3.new(MAP.SafeRadius * 2, 20, MAP.SafeRadius * 2), CFrame.new(0, 10, 0))
	return c
end

local function buildShop(map)
	local s = B.model(map, "Shop")
	local base = CFrame.new(0, 0, -20) -- лавка смотрит на костёр (+Z)
	local wood = hex("#7a5232")
	local counter = B.part(s, "Counter", Vector3.new(12, 3.5, 3), base * CFrame.new(0, 1.75, 0), wood, Enum.Material.WoodPlanks)
	B.part(s, "Top", Vector3.new(12.6, 0.4, 3.6), base * CFrame.new(0, 3.7, 0), hex("#5a3a22"), Enum.Material.Wood)
	for _, x in ipairs({ -5.8, 5.8 }) do
		B.part(s, "Pole", Vector3.new(0.6, 10, 0.6), base * CFrame.new(x, 5, -2.5), hex("#4a3020"), Enum.Material.Wood)
		B.part(s, "Pole", Vector3.new(0.6, 8, 0.6), base * CFrame.new(x, 4, 1.4), hex("#4a3020"), Enum.Material.Wood)
	end
	-- полосатый навес
	for i = 0, 5 do
		local col = (i % 2 == 0) and hex("#6b2fa0") or hex("#2a2140")
		B.part(s, "Awning", Vector3.new(2.2, 0.3, 5.4), base * CFrame.new(-5.5 + i * 2.2, 9, -0.6) * CFrame.Angles(rad(-14), 0, 0), col, Enum.Material.Fabric)
	end
	local board = B.part(s, "SignBoard", Vector3.new(12, 2.4, 0.4), base * CFrame.new(0, 10.6, 1.8), hex("#1a1426"), Enum.Material.Wood)
	B.sign(board, Enum.NormalId.Back, "🛒 ЛАВКА ЛОВЦА", { TextColor3 = hex("#ffd84a"), Font = Enum.Font.GothamBlack })
	-- продавец в капюшоне
	local cloak = hex("#231a33")
	B.part(s, "Keeper", Vector3.new(2.4, 4.2, 1.6), base * CFrame.new(0, 3.6, -2.6), cloak, Enum.Material.Fabric)
	B.ball(s, "Hood", 2.2, base * CFrame.new(0, 6.4, -2.6), cloak, Enum.Material.Fabric)
	local e1 = B.ball(s, "Eye", 0.35, base * CFrame.new(-0.4, 6.4, -1.6), hex("#ffe14a"), Enum.Material.Neon)
	local e2 = B.ball(s, "Eye", 0.35, base * CFrame.new(0.4, 6.4, -1.6), hex("#ffe14a"), Enum.Material.Neon)
	e1.CanCollide, e2.CanCollide = false, false
	-- товары на прилавке
	for i = 0, 4 do
		B.ball(s, "Jar", 0.9, base * CFrame.new(-4 + i * 2, 4.4, 0.3), (i % 2 == 0) and hex("#ffcf40") or hex("#ff4a6a"), Enum.Material.Glass, { Transparency = 0.2 })
	end
	B.light(board, "PointLight", { Range = 20, Brightness = 1.2, Color = hex("#c79bff"), Shadows = false })
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 1.5, 1.5)
	att.Parent = counter
	B.prompt(att, "ShopPrompt", "Открыть лавку", "Лавка Ловца", { MaxActivationDistance = 14, HoldDuration = 0 })
	return counter
end

---------------------------------------------------------------- базы
local function buildBase(folder, i)
	local a = rad((i - 1) * 360 / MAP.BaseCount)
	local center = Vector3.new(math.cos(a) * MAP.BaseRadius, 0, math.sin(a) * MAP.BaseRadius)
	local cf = CFrame.lookAt(center, Vector3.new(0, 0, 0))
	local half = MAP.BaseSize / 2
	local col = hex(BASE_COLORS[(i - 1) % #BASE_COLORS + 1])
	local m = B.model(folder, "Base_" .. i)
	m:SetAttribute("Index", i)
	m:SetAttribute("OwnerId", 0)
	m:SetAttribute("OwnerName", "")
	m:SetAttribute("Locked", false)
	m:SetAttribute("LockEnds", 0)
	m:SetAttribute("Income", 0)

	B.part(m, "Floor", Vector3.new(MAP.BaseSize, 1, MAP.BaseSize), cf * CFrame.new(0, 0.5, 0), col:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Concrete)
	B.marker(m, "Zone", Vector3.new(MAP.BaseSize, 24, MAP.BaseSize), cf * CFrame.new(0, 12, 0))
	local h, th = MAP.WallHeight, 2
	local wallCol = col:Lerp(Color3.fromRGB(30, 30, 35), 0.5)
	local walls = B.model(m, "Walls")
	local function w(x0, z0, x1, z1, openings)
		local p0 = (cf * CFrame.new(x0, 1, z0)).Position
		local p1 = (cf * CFrame.new(x1, 1, z1)).Position
		B.wall(walls, "Wall", p0, p1, h, th, wallCol, Enum.Material.Brick, openings)
	end
	local e = half - th / 2
	w(-half, e, half, e)                 -- задняя
	w(-e, -half, -e, half)               -- левая
	w(e, -half, e, half)                 -- правая
	w(-half, -e, half, -e, { { at = half, w = 12, y0 = 0, y1 = h } }) -- передняя с проёмом
	-- край стены (чтобы не смотрелось плоско)
	for _, x in ipairs({ -6.6, 6.6 }) do
		B.part(m, "DoorPost", Vector3.new(1.2, h + 1, 2.6), cf * CFrame.new(x, 1 + (h + 1) / 2, -e), col, Enum.Material.Metal)
	end
	local door = B.part(m, "Door", Vector3.new(12, h, 0.8), cf * CFrame.new(0, 1 + h / 2, -e), hex("#ff2a3a"), Enum.Material.Neon,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	local lockGui = Instance.new("BillboardGui")
	lockGui.Name = "LockGui"
	lockGui.Size = UDim2.new(0, 160, 0, 50)
	lockGui.StudsOffset = Vector3.new(0, h / 2 + 2, 0)
	lockGui.MaxDistance = 120
	lockGui.Enabled = false
	lockGui.Parent = door
	local lt = Instance.new("TextLabel")
	lt.Name = "Text"
	lt.Size = UDim2.fromScale(1, 1)
	lt.BackgroundTransparency = 1
	lt.Font = Enum.Font.GothamBlack
	lt.TextScaled = true
	lt.TextColor3 = hex("#ff5a6a")
	lt.TextStrokeTransparency = 0.3
	lt.Text = "🔒"
	lt.Parent = lockGui

	-- вывеска над дверью
	local sign = B.part(m, "SignBoard", Vector3.new(16, 3.2, 0.6), cf * CFrame.new(0, 1 + h + 1.6, -e), hex("#14121c"), Enum.Material.Wood)
	local _, signText = B.sign(sign, Enum.NormalId.Front, "Свободная база", { TextColor3 = hex("#ffe9a0"), Font = Enum.Font.GothamBlack })
	signText.Name = "OwnerText"
	-- имя и доход высоко над базой
	local top = B.marker(m, "Top", Vector3.new(1, 1, 1), cf * CFrame.new(0, 30, 0))
	local bg = Instance.new("BillboardGui")
	bg.Name = "OwnerGui"
	bg.Size = UDim2.new(0, 260, 0, 70)
	bg.MaxDistance = 450
	bg.LightInfluence = 0
	bg.Parent = top
	local n = Instance.new("TextLabel")
	n.Name = "NameText"
	n.Size = UDim2.new(1, 0, 0.6, 0)
	n.BackgroundTransparency = 1
	n.Font = Enum.Font.GothamBlack
	n.TextScaled = true
	n.TextColor3 = Color3.new(1, 1, 1)
	n.TextStrokeTransparency = 0.2
	n.Text = ""
	n.Parent = bg
	local inc = n:Clone()
	inc.Name = "Income"
	inc.Position = UDim2.new(0, 0, 0.6, 0)
	inc.Size = UDim2.new(1, 0, 0.4, 0)
	inc.TextColor3 = hex("#ffd84a")
	inc.Parent = bg
	-- метка «ТВОЯ БАЗА» (клиент включает её хозяину, когда он несёт монстра)
	local hm = Instance.new("BillboardGui")
	hm.Name = "HomeMarker"
	hm.Size = UDim2.new(0, 200, 0, 50)
	hm.AlwaysOnTop = true
	hm.MaxDistance = 2000
	hm.LightInfluence = 0
	hm.Enabled = false
	hm.Parent = top
	local ht = n:Clone()
	ht.Name = "Text"
	ht.Size = UDim2.fromScale(1, 1)
	ht.Text = "🏠 ТВОЯ БАЗА"
	ht.TextColor3 = hex("#7dff6b")
	ht.Parent = hm

	-- замок
	local pad = B.part(m, "LockPad", Vector3.new(5, 0.4, 5), cf * CFrame.new(-22, 1.2, -22), hex("#3cff6a"), Enum.Material.Neon)
	local post = B.part(m, "LockPost", Vector3.new(1, 4, 1), cf * CFrame.new(-22, 3, -25), hex("#2b2b30"), Enum.Material.Metal)
	B.sign(post, Enum.NormalId.Front, "🔒", nil, { PixelsPerStud = 50 })
	local lockAtt = Instance.new("Attachment")
	lockAtt.Position = Vector3.new(0, 2, 0)
	lockAtt.Parent = pad
	local lp = B.prompt(lockAtt, "LockPrompt", "Запереть базу", Config.LockSeconds .. " секунд", { HoldDuration = 0, MaxActivationDistance = 9 })
	lp:SetAttribute("For", "owner")

	B.marker(m, "Spawn", Vector3.new(2, 1, 2), cf * CFrame.new(0, 4, -16))

	-- фонари в углах
	for _, x in ipairs({ -half + 3, half - 3 }) do
		B.vcyl(m, "LampPost", 10, 0.6, cf * CFrame.new(x, 6, -half + 3), hex("#2b2b2b"), Enum.Material.Metal)
		local lamp = B.part(m, "Lamp", Vector3.new(1.6, 1.6, 1.6), cf * CFrame.new(x, 11.4, -half + 3), col:Lerp(Color3.new(1, 1, 1), 0.5), Enum.Material.Neon)
		B.light(lamp, "PointLight", { Range = 34, Brightness = 1.4, Color = col:Lerp(Color3.new(1, 1, 1), 0.6), Shadows = false })
	end

	-- клетки
	local slots = B.folder(m, "Slots")
	for s, off in ipairs(World.SlotOffsets) do
		local sm = B.model(slots, "Slot_" .. s)
		sm:SetAttribute("Slot", s)
		local scf = cf * CFrame.new(off.X, 0, off.Z)
		B.part(sm, "Rim", Vector3.new(8.6, 0.6, 8.6), scf * CFrame.new(0, 1.3, 0), hex("#55555c"), Enum.Material.Neon)
		local padPart = B.part(sm, "Pad", Vector3.new(8, 1, 8), scf * CFrame.new(0, 1.5, 0), hex("#2d2d33"), Enum.Material.DiamondPlate)
		B.marker(sm, "Anchor", Vector3.new(1, 1, 1), scf * CFrame.new(0, 2.05, 0))
		local bars = B.model(sm, "Bars")
		for _, c in ipairs({ { -3.8, -3.8 }, { 3.8, -3.8 }, { -3.8, 3.8 }, { 3.8, 3.8 } }) do
			B.part(bars, "Bar", Vector3.new(0.4, 9, 0.4), scf * CFrame.new(c[1], 6.5, c[2]), hex("#5d5d66"), Enum.Material.Metal, { CanCollide = false })
		end
		B.part(bars, "Bar", Vector3.new(8, 0.4, 0.4), scf * CFrame.new(0, 11, -3.8), hex("#5d5d66"), Enum.Material.Metal, { CanCollide = false })
		B.part(bars, "Bar", Vector3.new(8, 0.4, 0.4), scf * CFrame.new(0, 11, 3.8), hex("#5d5d66"), Enum.Material.Metal, { CanCollide = false })
		B.part(bars, "Bar", Vector3.new(0.4, 0.4, 8), scf * CFrame.new(-3.8, 11, 0), hex("#5d5d66"), Enum.Material.Metal, { CanCollide = false })
		B.part(bars, "Bar", Vector3.new(0.4, 0.4, 8), scf * CFrame.new(3.8, 11, 0), hex("#5d5d66"), Enum.Material.Metal, { CanCollide = false })
		local att = Instance.new("Attachment")
		att.Name = "PromptAtt"
		att.Position = Vector3.new(0, 3, -3)
		att.Parent = padPart
		local steal = B.prompt(att, "StealPrompt", "Украсть", "", { HoldDuration = Config.StealHold, MaxActivationDistance = 10, Enabled = false })
		steal:SetAttribute("For", "others")
		local sell = B.prompt(att, "SellPrompt", "Продать", "", { HoldDuration = Config.SellHold, MaxActivationDistance = 10, Enabled = false })
		sell:SetAttribute("For", "owner")
		local buy = B.prompt(att, "BuyPrompt", "Купить клетку", "", { HoldDuration = 0, MaxActivationDistance = 10, Enabled = false })
		buy:SetAttribute("For", "owner")
		local lg = Instance.new("BillboardGui")
		lg.Name = "LockedGui"
		lg.Size = UDim2.new(0, 150, 0, 40)
		lg.StudsOffset = Vector3.new(0, 2.5, 0)
		lg.MaxDistance = 60
		lg.Enabled = false
		lg.Parent = padPart
		local lgt = n:Clone()
		lgt.Name = "Text"
		lgt.Size = UDim2.fromScale(1, 1)
		lgt.TextColor3 = hex("#c8c8d0")
		lgt.Text = "🔒"
		lgt.Parent = lg
	end
	return m
end

function World.build()
	local map = B.folder(workspace, "Map")
	local ground = B.part(map, "Ground", Vector3.new(1000, 2, 1000), CFrame.new(0, -1, 0), hex("#2b3d27"), Enum.Material.Grass)
	ground.Locked = true
	for _, s in ipairs({ { 0, 480, 1000, 1 }, { 0, -480, 1000, 1 }, { 480, 0, 1, 1000 }, { -480, 0, 1, 1000 } }) do
		B.part(map, "Border", Vector3.new(s[3], 200, s[4]), CFrame.new(s[1], 100, s[2]), nil, nil, { Transparency = 1, CanQuery = false })
	end
	buildForest(map)
	buildPaths(map)
	buildClearing(map)
	local shop = buildShop(map)
	local folder = B.folder(workspace, "Bases")
	local bases = {}
	for i = 1, MAP.BaseCount do bases[i] = buildBase(folder, i) end
	B.folder(workspace, "Wild")
	B.folder(workspace, "Carried")
	return { bases = bases, shop = shop }
end

return World
