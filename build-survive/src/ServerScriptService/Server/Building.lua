-- Строительство на сервере: проверка каждого запроса клиента, создание блоков,
-- отмена действий, сохранение и загрузка построек.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Blocks = require(Shared.Blocks)
local Grid = require(Shared.Grid)
local BlockFactory = require(Shared.BlockFactory)
local Serializer = require(Shared.Serializer)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local Examples = require(Shared.Examples)

local Plots = require(script.Parent.Plots)
local Data = require(script.Parent.Data)

local Building = {}

type Spec = Serializer.Spec
type Plot = Plots.Plot

local lastAction: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	Net.event("Notify"):FireClient(player, text, kind or "info")
end
Building.notify = notify

-- Можно ли сейчас менять постройку на участке?
function Building.canEdit(plot: Plot): (boolean, string?)
	if plot.siege then
		return false, "Во время осады строить нельзя"
	end
	if plot.launched then
		return false, "Сначала останови испытание"
	end
	return true, nil
end

function Building.specOf(block: BasePart): Spec
	return {
		mat = block:GetAttribute("Mat") or 1,
		shape = block:GetAttribute("Shape") or 1,
		item = block:GetAttribute("Item") or 0,
		pos = block:GetAttribute("Local") or Vector3.zero,
		size = block:GetAttribute("BlockSize") or block.Size,
		rot = block:GetAttribute("Rot") or 1,
		color = block:GetAttribute("BaseColor") or block.Color,
	}
end

-- Создать блок на участке (без проверок — их делает вызывающий код)
function Building.create(plot: Plot, spec: Spec): BasePart
	local cf = Grid.worldCFrame(plot.cf, spec.pos, spec.rot)
	local part = BlockFactory.build(spec, cf, { plotColor = plot.color })
	local maxHp = Blocks.maxHp(spec, spec.size)
	part:SetAttribute("Mat", spec.mat)
	part:SetAttribute("Shape", spec.shape)
	part:SetAttribute("Item", spec.item)
	part:SetAttribute("Rot", spec.rot)
	part:SetAttribute("Local", spec.pos)
	part:SetAttribute("BlockSize", spec.size)
	part:SetAttribute("BaseColor", spec.color)
	part:SetAttribute("Hp", maxHp)
	part:SetAttribute("MaxHp", maxHp)
	local def = Blocks.def(spec)
	if spec.item > 0 and def.key == "Door" then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DoorPrompt"
		prompt.ActionText = "Открыть"
		prompt.ObjectText = "Дверь"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end
	part.Parent = plot.blocks
	return part
end

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

function Building.overlaps(plot: Plot, spec: Spec, ignore: BasePart?): boolean
	overlapParams.FilterDescendantsInstances = { plot.blocks }
	local cf = Grid.worldCFrame(plot.cf, spec.pos, spec.rot)
	local hits = workspace:GetPartBoundsInBox(cf, spec.size - Vector3.new(0.12, 0.12, 0.12), overlapParams)
	for _, h in hits do
		if h ~= ignore and h.Name == "Block" then
			return true
		end
	end
	return false
end

-- Превратить запрос клиента в проверенную спецификацию
local function validate(player: Player, req: any): (Spec?, string?)
	if typeof(req) ~= "table" then
		return nil, "Неверный запрос"
	end
	if typeof(req.pos) ~= "Vector3" or typeof(req.size) ~= "Vector3" or typeof(req.color) ~= "Color3" then
		return nil, "Неверный запрос"
	end
	local pos: Vector3 = req.pos
	if not (Util.isFiniteNumber(pos.X) and Util.isFiniteNumber(pos.Y) and Util.isFiniteNumber(pos.Z)) then
		return nil, "Неверный запрос"
	end
	local item = math.floor(tonumber(req.item) or 0)
	local mat = math.floor(tonumber(req.mat) or 1)
	local shape = math.floor(tonumber(req.shape) or 1)
	local rot = math.floor(tonumber(req.rot) or 1)
	if rot < 1 or rot > 24 then
		rot = 1
	end
	if item > 0 then
		local it = Blocks.ItemById[item]
		if not it then
			return nil, "Нет такого блока"
		end
		if it.price > 0 and not Data.isUnlocked(player, "i:" .. it.key) then
			return nil, "Сначала купи «" .. it.name .. "» в магазине"
		end
		mat, shape = 0, 1
	else
		local m = Blocks.MaterialById[mat]
		if not m then
			return nil, "Нет такого материала"
		end
		if m.price > 0 and not Data.isUnlocked(player, "m:" .. m.key) then
			return nil, "Сначала купи «" .. m.name .. "» в магазине"
		end
		if not Blocks.ShapeById[shape] then
			shape = 1
		end
		item = 0
	end
	local size = Blocks.normalizeSize(shape, item, req.size, Config.MaxBlockSize)
	return {
		mat = mat, shape = shape, item = item,
		pos = pos, size = size, rot = rot, color = req.color,
	}, nil
end

local function pushUndo(plot: Plot, action: any)
	table.insert(plot.undo, action)
	if #plot.undo > Config.UndoDepth then
		table.remove(plot.undo, 1)
	end
end

local function cooldownOk(player: Player): boolean
	local now = os.clock()
	if now - (lastAction[player] or 0) < Config.PlaceCooldown then
		return false
	end
	lastAction[player] = now
	return true
end

function Building.count(plot: Plot): number
	return #plot.blocks:GetChildren()
end

function Building.place(player: Player, req: any): (boolean, string?)
	local plot = Plots.of(player)
	if not plot then
		return false, "У тебя нет участка"
	end
	local can, why = Building.canEdit(plot)
	if not can then
		return false, why
	end
	if not cooldownOk(player) then
		return false, nil
	end
	local spec, err = validate(player, req)
	if not spec then
		return false, err
	end
	local e = Grid.extents(spec.size, spec.rot)
	if not Grid.isAligned(spec.pos, e) then
		return false, "Блок не попал в сетку"
	end
	if not Grid.inBounds(spec.pos, e) then
		return false, "Строить можно только внутри рамки участка"
	end
	if Building.count(plot) >= Config.MaxBlocks then
		return false, "Достигнут лимит: " .. Config.MaxBlocks .. " блоков"
	end
	if Building.overlaps(plot, spec) then
		return false, "Здесь уже есть блок"
	end
	local part = Building.create(plot, spec)
	pushUndo(plot, { type = "place", block = part })
	local profile = Data.get(player)
	if profile then
		profile.Stats.Blocks = (profile.Stats.Blocks or 0) + 1
	end
	return true, nil
end

local function ownBlock(player: Player, block: any): (Plot?, BasePart?)
	local plot = Plots.of(player)
	if not plot or typeof(block) ~= "Instance" or not block:IsA("BasePart") or block.Parent ~= plot.blocks then
		return nil, nil
	end
	return plot, block :: BasePart
end

function Building.delete(player: Player, block: any): (boolean, string?)
	local plot, part = ownBlock(player, block)
	if not plot or not part then
		return false, nil
	end
	local can, why = Building.canEdit(plot)
	if not can then
		return false, why
	end
	if not cooldownOk(player) then
		return false, nil
	end
	pushUndo(plot, { type = "delete", spec = Building.specOf(part) })
	part:Destroy()
	return true, nil
end

function Building.paint(player: Player, block: any, color: any): (boolean, string?)
	local plot, part = ownBlock(player, block)
	if not plot or not part or typeof(color) ~= "Color3" then
		return false, nil
	end
	local can, why = Building.canEdit(plot)
	if not can then
		return false, why
	end
	local old = part:GetAttribute("BaseColor") or part.Color
	if old == color then
		return true, nil
	end
	pushUndo(plot, { type = "paint", block = part, color = old })
	part.Color = color
	part:SetAttribute("BaseColor", color)
	local light = part:FindFirstChildOfClass("PointLight")
	if light and part:GetAttribute("Item") == Blocks.ItemByKey.Lamp.id then
		light.Color = color
	end
	return true, nil
end

function Building.serialize(plot: Plot): string
	local specs = {}
	for _, child in plot.blocks:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(specs, Building.specOf(child))
		end
	end
	return Serializer.encode(specs)
end

function Building.clear(plot: Plot)
	plot.blocks:ClearAllChildren()
end

-- Построить из строки (сохранение, снимок до осады). Неверные блоки пропускаются.
function Building.loadString(plot: Plot, str: string?): number
	local specs = Serializer.decode(str)
	local n = 0
	for _, spec in specs do
		if n >= Config.MaxBlocks then
			break
		end
		local okDef = (spec.item > 0 and Blocks.ItemById[spec.item]) or (spec.item == 0 and Blocks.MaterialById[spec.mat])
		if okDef and spec.rot >= 1 and spec.rot <= 24 then
			spec.shape = Blocks.ShapeById[spec.shape] and spec.shape or 1
			spec.size = Blocks.normalizeSize(spec.shape, spec.item, spec.size, Config.MaxBlockSize)
			local e = Grid.extents(spec.size, spec.rot)
			if Grid.inBounds(spec.pos, e) and Grid.isAligned(spec.pos, e) then
				Building.create(plot, spec)
				n += 1
			end
		end
	end
	return n
end

-- Заменить постройку целиком (снимок / слот). withUndo — можно будет отменить.
function Building.restore(plot: Plot, str: string?, withUndo: boolean?)
	if withUndo then
		pushUndo(plot, { type = "clear", data = Building.serialize(plot) })
	end
	Building.clear(plot)
	Building.loadString(plot, str)
end

function Building.undo(player: Player): (boolean, string?)
	local plot = Plots.of(player)
	if not plot then
		return false, nil
	end
	local can, why = Building.canEdit(plot)
	if not can then
		return false, why
	end
	local action = table.remove(plot.undo)
	if not action then
		return false, "Нечего отменять"
	end
	if action.type == "place" then
		if action.block and action.block.Parent == plot.blocks then
			action.block:Destroy()
		end
	elseif action.type == "delete" then
		if not Building.overlaps(plot, action.spec) and Building.count(plot) < Config.MaxBlocks then
			Building.create(plot, action.spec)
		end
	elseif action.type == "paint" then
		local b = action.block
		if b and b.Parent == plot.blocks then
			b.Color = action.color
			b:SetAttribute("BaseColor", action.color)
		end
	elseif action.type == "clear" then
		Building.clear(plot)
		Building.loadString(plot, action.data)
	end
	return true, nil
end

function Building.clearRequest(player: Player): (boolean, string?)
	local plot = Plots.of(player)
	if not plot then
		return false, nil
	end
	local can, why = Building.canEdit(plot)
	if not can then
		return false, why
	end
	if Building.count(plot) == 0 then
		return false, "Участок и так пустой"
	end
	pushUndo(plot, { type = "clear", data = Building.serialize(plot) })
	Building.clear(plot)
	return true, nil
end

function Building.saveSlot(player: Player, slot: any): (boolean, string?)
	local plot = Plots.of(player)
	slot = tonumber(slot)
	if not plot or not slot or slot < 1 or slot > Config.SaveSlots then
		return false, nil
	end
	slot = math.floor(slot)
	local str = Building.serialize(plot)
	Data.setSlot(player, slot, str)
	task.spawn(Data.save, player)
	Data.sync(player)
	local n = Building.count(plot)
	return true, string.format("Сохранено в слот %d: %d %s", slot, n, Util.plural(n, "блок", "блока", "блоков"))
end

function Building.loadSlot(player: Player, slot: any): (boolean, string?)
	local plot = Plots.of(player)
	slot = tonumber(slot)
	if not plot or not slot then
		return false, nil
	end
	local can, why = Building.canEdit(plot)
	if not can then
		return false, why
	end
	local str = Data.getSlot(player, math.floor(slot))
	if not str or str == "" then
		return false, "Слот пустой"
	end
	Building.restore(plot, str, true)
	return true, "Постройка загружена (отменить — Ctrl+Z)"
end

-- Стартовый домик для нового игрока
function Building.starter(plot: Plot)
	Building.loadString(plot, Examples[1].data)
end

function Building.loadExample(player: Player, index: any): (boolean, string?)
	local plot = Plots.of(player)
	local ex = Examples[tonumber(index) or 0]
	if not plot or not ex then
		return false, nil
	end
	local can, why = Building.canEdit(plot)
	if not can then
		return false, why
	end
	Building.restore(plot, ex.data, true)
	return true, "Загружен пример: " .. ex.name .. " (отменить — Ctrl+Z)"
end

function Building.forget(player: Player)
	lastAction[player] = nil
end

return Building
