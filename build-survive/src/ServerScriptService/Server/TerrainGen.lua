-- Рельеф: море, острова, пляжи, горы на горизонте и облака.
-- Строится при запуске сервера, если в месте ещё нет рельефа.
-- Чтобы «запечь» рельеф в файл и видеть его в Studio без запуска, выполни в Command Bar:
--   require(game.ServerScriptService.Server.TerrainGen).build(true)
-- и сохрани место (Ctrl+S).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MapLayout = require(Shared.MapLayout)

local TerrainGen = {}

local MATERIAL_COLORS: { [Enum.Material]: Color3 } = {
	[Enum.Material.Grass] = Color3.fromRGB(86, 128, 58),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(78, 120, 52),
	[Enum.Material.Sand] = Color3.fromRGB(214, 196, 150),
	[Enum.Material.Ground] = Color3.fromRGB(110, 92, 70),
	[Enum.Material.Rock] = Color3.fromRGB(120, 118, 112),
	[Enum.Material.Snow] = Color3.fromRGB(236, 242, 250),
	[Enum.Material.Mud] = Color3.fromRGB(80, 64, 50),
}

local function hasTerrain(terrain: Terrain): boolean
	if terrain:GetAttribute("Generated") then
		return true
	end
	-- в центре карты под водой должен быть песок или вода
	local region = Region3.new(Vector3.new(-8, -8, -8), Vector3.new(8, 0, 8)):ExpandToGrid(4)
	local materials = terrain:ReadVoxels(region, 4)
	local size = materials.Size
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				if materials[x][y][z] ~= Enum.Material.Air then
					return true
				end
			end
		end
	end
	return false
end

function TerrainGen.build(force: boolean?)
	local terrain = workspace.Terrain
	if not force and hasTerrain(terrain) then
		return
	end
	local started = os.clock()
	if force then
		terrain:Clear()
	end
	for material, color in MATERIAL_COLORS do
		terrain:SetMaterialColor(material, color)
	end
	for i, op in MapLayout.Terrain do
		local kind = op[1]
		if kind == "Cylinder" then
			terrain:FillCylinder(CFrame.new(op[2]), op[3], op[4], op[5])
		elseif kind == "Ball" then
			terrain:FillBall(op[2], op[3], op[4])
		elseif kind == "Block" then
			terrain:FillBlock(CFrame.new(op[2]), op[3], op[4])
		end
		if i % 20 == 0 then
			task.wait()
		end
	end
	if not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.52
		clouds.Density = 0.62
		clouds.Parent = terrain
	end
	terrain:SetAttribute("Generated", true)
	print(string.format("[TerrainGen] рельеф построен за %.1f с", os.clock() - started))
end

return TerrainGen
