-- Сборка всей карты. Порядок: рельеф → небо → постройки. Детали собираются в папку Map,
-- которая кладётся в workspace в самом конце (так Roblox строит быстрее).
-- Можно вызвать и в режиме редактирования из Command Bar (см. README) — старая карта и рельеф стираются.
local Map = {}

function Map.build()
	local folder = script
	local t0 = os.clock()
	local old = workspace:FindFirstChild("Map")
	if old then old:Destroy() end
	workspace.Terrain:Clear()
	local root = Instance.new("Folder")
	root.Name = "Map"

	require(folder.Terrain).build()
	require(folder.Sky).setup()
	require(folder.Hub).build(root)
	require(folder.Plots).build(root)
	require(folder.Zones).build(root)
	require(folder.BossArena).build(root)
	require(folder.RebirthTower).build(root)
	require(folder.Island).build(root)

	root.Parent = workspace
	workspace:SetAttribute("MapReady", true)
	print(string.format("[Map] карта построена за %.2f с", os.clock() - t0))
	return root
end

return Map
