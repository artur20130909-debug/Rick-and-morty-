-- Подземелье на сервере: какие клетки земли выкопаны на каждом участке, сборка земли из деталей,
-- проверки «можно ли копать / засыпать» и вырезание рельефа под участками.
--
-- Земля — детали в папке участка Ground. Каждый слой клеток собирается из прямоугольников
-- невыкопанных клеток (UG.layerRects): верхний слой — бетонная плита пола (Slab) и грунт под ней,
-- нижние — только грунт (Soil). Детали твёрдые: в них упираются снаряды, лазер и луч строительства.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local UG = require(Shared.Underground)

local Plots = require(script.Parent.Plots)

local Underground = {}

type Plot = Plots.Plot

local C = UG.CELL
local X0 = -Config.PlotSize.X / 2
local Z0 = -Config.PlotSize.Z / 2
local SLAB = 2 -- толщина плиты пола (верх — на уровне пола)

local SLAB_COLOR = Color3.fromRGB(164, 166, 164)
local SOIL_TOP = Color3.fromRGB(118, 92, 64)    -- грунт сразу под полом
local SOIL_BOTTOM = Color3.fromRGB(86, 70, 56)  -- у дна котлована

-- Грунт темнеет с глубиной, а у самого дна превращается в камень
local function soilLook(iy: number): (Enum.Material, Color3)
	local t = (UG.NY > 1) and (iy - 1) / (UG.NY - 1) or 0
	local color = SOIL_TOP:Lerp(SOIL_BOTTOM, t)
	if iy == UG.NY then
		return Enum.Material.Rock, color
	elseif iy == UG.NY - 1 then
		return Enum.Material.Slate, color
	end
	return Enum.Material.Ground, color
end

-- Деталь земли: прямоугольник клеток rect по горизонтали, от yBottom до yTop по высоте
local function makePart(plot: Plot, name: string, iy: number, rect: UG.Rect, yTop: number, yBottom: number, key: string)
	local material, color
	if name == "Slab" then
		material, color = Enum.Material.Concrete, SLAB_COLOR
	else
		material, color = soilLook(iy)
	end
	local sx, sz = rect.w * C, rect.d * C
	local center = Vector3.new(X0 + (rect.x0 - 1) * C + sx / 2, (yTop + yBottom) / 2, Z0 + (rect.z0 - 1) * C + sz / 2)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.CastShadow = true
	p.Locked = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material
	p.Color = color
	p.Size = Vector3.new(sx, yTop - yBottom, sz)
	p.CFrame = plot.cf * CFrame.new(center)
	p:SetAttribute("Layer", iy)
	p:SetAttribute("Rect", key)
	p.Parent = plot.ground
end

local function keyOf(name: string, rect: UG.Rect): string
	return string.format("%s:%d:%d:%d:%d", name, rect.x0, rect.z0, rect.w, rect.d)
end

-- Пересобрать один слой. Детали, которые не изменились, остаются на месте: копание задевает
-- лишь несколько прямоугольников, и клиенту не нужно заново получать весь слой.
local function rebuildLayer(plot: Plot, iy: number)
	local wanted: { [string]: { name: string, rect: UG.Rect } } = {}
	for _, rect in UG.layerRects(plot.dug, iy) do
		if iy == 1 then
			wanted[keyOf("Slab", rect)] = { name = "Slab", rect = rect }
		end
		wanted[keyOf("Soil", rect)] = { name = "Soil", rect = rect }
	end
	for _, child in plot.ground:GetChildren() do
		if child:GetAttribute("Layer") == iy then
			local key = child:GetAttribute("Rect")
			if typeof(key) == "string" and wanted[key] then
				wanted[key] = nil -- уже стоит
			else
				child:Destroy()
			end
		end
	end
	local top = -(iy - 1) * C
	for key, w in wanted do
		if w.name == "Slab" then
			makePart(plot, "Slab", iy, w.rect, 0, -SLAB, key)
		elseif iy == 1 then
			makePart(plot, "Soil", iy, w.rect, -SLAB, -C, key)
		else
			makePart(plot, "Soil", iy, w.rect, top, top - C, key)
		end
	end
end

-- Пересобрать землю: слой iy или все слои (nil)
function Underground.rebuild(plot: Plot, iy: number?)
	if iy then
		rebuildLayer(plot, iy)
		return
	end
	-- полная сборка убирает и всё постороннее (например, заглушку земли из файла карты)
	for _, child in plot.ground:GetChildren() do
		if typeof(child:GetAttribute("Rect")) ~= "string" then
			child:Destroy()
		end
	end
	for layer = 1, UG.NY do
		rebuildLayer(plot, layer)
	end
end

local function updateAttribute(plot: Plot)
	plot.model:SetAttribute("Dug", UG.encode(plot.dug))
end

function Underground.encode(plot: Plot): string
	return UG.encode(plot.dug)
end

local charParams = OverlapParams.new()
charParams.FilterType = Enum.RaycastFilterType.Include
charParams.MaxParts = 1

local function characters(): { Instance }
	local list: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

-- Персонажей, которых засыпало землёй (загрузили постройку без ямы), поднимаем к точке появления
local function rescue(plot: Plot)
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if char and root then
			local ix, iy, iz = UG.cellAt(plot.cf:PointToObjectSpace(root.Position))
			if ix and iy and iz and not plot.dug[UG.index(ix, iy, iz)] then
				char:PivotTo(plot.spawn.CFrame + Vector3.new(0, 4, 0))
			end
		end
	end
end

-- Заменить маску целиком (загрузка сохранения, готовый бункер). Пересобираются только изменённые слои.
function Underground.setMask(plot: Plot, dug: { [number]: boolean })
	local clean: { [number]: boolean } = {}
	for i, v in dug do
		if v == true and typeof(i) == "number" and i >= 0 and i < UG.COUNT and i == math.floor(i) then
			clean[i] = true
		end
	end
	local changed: { [number]: boolean } = {}
	for i in clean do
		if not plot.dug[i] then
			local _, iy = UG.coords(i)
			changed[iy] = true
		end
	end
	for i in plot.dug do
		if not clean[i] then
			local _, iy = UG.coords(i)
			changed[iy] = true
		end
	end
	plot.dug = clean
	for iy in changed do
		Underground.rebuild(plot, iy)
	end
	updateAttribute(plot)
	if next(changed) then
		rescue(plot)
	end
end

-- Вся земля на месте (игрок ушёл с участка)
function Underground.reset(plot: Plot)
	Underground.setMask(plot, {})
end

-- Коробку блока можно поставить: все клетки ниже пола, которые она задевает, выкопаны
function Underground.isClear(plot: Plot, center: Vector3, extents: Vector3): boolean
	for _, i in UG.cellsInBox(center, extents) do
		if not plot.dug[i] then
			return false
		end
	end
	return true
end

local blockParams = OverlapParams.new()
blockParams.FilterType = Enum.RaycastFilterType.Include
blockParams.MaxParts = 1

-- Выкопать (fill = false) или засыпать (fill = true) клетку i. Только проверки по правилам земли:
-- владелец, антиспам и отмена — в Building.dig.
function Underground.digCell(plot: Plot, i: number, fill: boolean): (boolean, string?)
	if typeof(i) ~= "number" or i ~= math.floor(i) or i < 0 or i >= UG.COUNT then
		return false, "Здесь копать нельзя"
	end
	local ix, iy, iz = UG.coords(i)
	if fill then
		if not plot.dug[i] then
			return false, "Здесь и так земля"
		end
		local cf = plot.cf * CFrame.new(UG.cellCenter(ix, iy, iz))
		local box = Vector3.new(C, C, C) - Vector3.new(0.1, 0.1, 0.1)
		blockParams.FilterDescendantsInstances = { plot.blocks }
		if #workspace:GetPartBoundsInBox(cf, box, blockParams) > 0 then
			return false, "Сначала убери блоки из этой ямы"
		end
		local chars = characters()
		if #chars > 0 then
			charParams.FilterDescendantsInstances = chars
			if #workspace:GetPartBoundsInBox(cf, box, charParams) > 0 then
				return false, "Нельзя засыпать яму, в которой кто-то стоит"
			end
		end
		plot.dug[i] = nil
	else
		if plot.dug[i] then
			return false, "Здесь уже выкопано"
		end
		if not UG.isExposed(plot.dug, ix, iy, iz) then
			return false, "Копать можно только с поверхности или рядом с ямой"
		end
		plot.dug[i] = true
	end
	Underground.rebuild(plot, iy)
	updateAttribute(plot)
	return true, nil
end

-- Вырезать рельеф под всеми участками: там котлован, его стенки — детали Foundation.
-- Можно вызывать повторно (например, после пересборки рельефа).
function Underground.carveAll()
	local terrain = workspace.Terrain
	for _, plot in Plots.list do
		terrain:FillBlock(plot.cf * CFrame.new(0, -13.25, 0), Vector3.new(72, 26.5, 72), Enum.Material.Air)
	end
end

function Underground.init()
	for _, plot in Plots.list do
		plot.dug = {}
		Underground.rebuild(plot)
		updateAttribute(plot)
	end
end

return Underground
