--[[
	WorldBuilder — строит все миры при запуске сервера (никаких .rbxm-файлов).
	Рельеф — настоящий Terrain (трава, вода, песок, камень), постройки и декор — из деталей.

	Модули в папке World/:
		Build      — помощники (детали, надписи, Terrain, поиск высоты, расстановка декора)
		Props      — декор (деревья, кусты, камни, кактусы, кристаллы, ракета, мельница …)
		Structures — постройки (точка появления, фонтан, магазин, арка, продажа, яйца, порталы)
		Themes     — рельеф и декор каждого мира (Forest / Desert / Space)

	WorldBuilder.Build() -> { [worldId] = информация о мире } (см. конец buildWorld)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Worlds = require(Shared.Config.Worlds)
local Eggs = require(Shared.Config.Eggs)

local World = script.Parent:WaitForChild("World")
local Build = require(World.Build)
local Structures = require(World.Structures)
local Themes = require(World.Themes)

local WorldBuilder = {}

local HALF = Build.HALF

-- Цвета материалов рельефа (общие для всех миров, поэтому в каждом мире свои материалы).
local TERRAIN_COLORS = {
	[Enum.Material.Grass] = Color3.fromRGB(96, 196, 70),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(80, 200, 90),
	[Enum.Material.Ground] = Color3.fromRGB(176, 128, 80),
	[Enum.Material.Cobblestone] = Color3.fromRGB(190, 182, 168),
	[Enum.Material.Sand] = Color3.fromRGB(245, 212, 150),
	[Enum.Material.Sandstone] = Color3.fromRGB(222, 166, 104),
	[Enum.Material.Limestone] = Color3.fromRGB(238, 222, 190),
	[Enum.Material.Rock] = Color3.fromRGB(128, 122, 140),
	[Enum.Material.Snow] = Color3.fromRGB(235, 240, 255),
	[Enum.Material.Basalt] = Color3.fromRGB(78, 60, 122),
	[Enum.Material.Slate] = Color3.fromRGB(70, 58, 108),
	[Enum.Material.Pavement] = Color3.fromRGB(150, 150, 185),
	[Enum.Material.Glacier] = Color3.fromRGB(150, 210, 255),
	[Enum.Material.CrackedLava] = Color3.fromRGB(255, 110, 200),
}

local function buildWorld(worldId, rootFolder)
	local config = Worlds[worldId]
	local origin = config.Origin
	local palette = config.Palette
	local folder = Build.folder(worldId, rootFolder)

	local ctx = {
		Id = worldId,
		Config = config,
		Origin = origin,
		Palette = palette,
		Folder = folder,
		Map = Build.folder("Map", folder),
		Decor = Build.folder("Decor", folder),
		Rng = Random.new(config.Seed or 1),
		Obstacles = {},
	}

	-- Постройки ставим первыми: декор потом обходит их стороной.
	local spawnCFrame = Structures.spawn(ctx, worldId == GameConfig.StartWorld)
	Structures.fountain(ctx)
	Structures.shopStall(ctx)
	Structures.welcomeArch(ctx, config.ArchTitle or string.upper(config.Name))
	local sell = Structures.sellShop(ctx)

	local eggStands = {}
	for _, eggId in ipairs(Eggs.Order) do
		if Eggs[eggId].World == worldId then
			eggStands[eggId] = Structures.eggStand(ctx, eggId)
		end
	end

	local portals = {}
	local nextWorld = Worlds.Order[config.Order + 1]
	local previousWorld = Worlds.Order[config.Order - 1]
	if nextWorld then
		table.insert(portals, Structures.portal(ctx, Build.LAYOUT.NextPortal, nextWorld, false))
	end
	if previousWorld then
		table.insert(portals, Structures.portal(ctx, Build.LAYOUT.BackPortal, previousWorld, true))
	end

	-- Рельеф и декор мира.
	local theme = Themes[config.Theme]
	if theme then
		theme(ctx)
	end

	-- Невидимые стены по краю игровой зоны.
	local walls = {
		{ Vector3.new(HALF + 1, 75, 0), Vector3.new(2, 150, HALF * 2 + 4) },
		{ Vector3.new(-HALF - 1, 75, 0), Vector3.new(2, 150, HALF * 2 + 4) },
		{ Vector3.new(0, 75, HALF + 1), Vector3.new(HALF * 2 + 4, 150, 2) },
		{ Vector3.new(0, 75, -HALF - 1), Vector3.new(HALF * 2 + 4, 150, 2) },
	}
	for _, wall in ipairs(walls) do
		Build.part(ctx.Map, {
			Name = "Wall",
			Size = wall[2],
			CFrame = CFrame.new(origin + wall[1]),
			Transparency = 1,
			CastShadow = false,
			CanQuery = false,
		})
	end

	local coinsFolder = Build.folder("Coins", folder)

	return {
		Id = worldId,
		Folder = folder,
		Origin = origin,
		-- Игрок появляется над площадкой и смотрит на север (-Z), к центру мира.
		Spawn = spawnCFrame,
		Sell = sell,
		EggStands = eggStands,
		Portals = portals,
		CoinsFolder = coinsFolder,
		-- Случайное свободное место для монеты: (x, z) относительно центра мира и высота земли.
		RandomCoinPoint = function(rng)
			for _ = 1, 40 do
				local x = rng:NextNumber(-HALF + 8, HALF - 8)
				local z = rng:NextNumber(-HALF + 8, HALF - 8)
				if Build.isFree(ctx, x, z, 2, true) then
					local groundY, material = Build.groundAt(origin + Vector3.new(x, 0, z), origin.Y)
					if material ~= Enum.Material.Water then
						return x, z, groundY
					end
				end
			end
			return rng:NextNumber(-4, 4), rng:NextNumber(-60, 40), origin.Y
		end,
	}
end

function WorldBuilder.Build()
	if GameConfig.RemoveTemplateBaseplate then
		local baseplate = Workspace:FindFirstChild("Baseplate")
		if baseplate and baseplate:IsA("BasePart") then
			baseplate:Destroy()
		end
		for _, item in ipairs(Workspace:GetDescendants()) do
			if item:IsA("SpawnLocation") then
				item:Destroy()
			end
		end
	end

	local old = Workspace:FindFirstChild("Worlds")
	if old then
		old:Destroy()
	end

	local terrain = Workspace.Terrain
	terrain:Clear()
	for material, color in pairs(TERRAIN_COLORS) do
		terrain:SetMaterialColor(material, color)
	end

	local rootFolder = Instance.new("Folder")
	rootFolder.Name = "Worlds"
	rootFolder.Parent = Workspace
	local result = {}
	for _, worldId in ipairs(Worlds.Order) do
		result[worldId] = buildWorld(worldId, rootFolder)
	end
	return result
end

return WorldBuilder
