-- Магазин готовых построек: покупка домов и бункеров за золото и установка их на участок.
--
-- Дом встаёт в центр участка: блоки игрока на его месте (габариты дома + 1 стад по X и Z) убираются.
-- Бункер занимает подземелье: убирается всё, что построено ниже пола, и блоки в углу участка,
-- где стоит вход, а земля выкапывается по маске бункера (выкопанное раньше засыпается).
-- Перед установкой запоминается снимок участка — всё возвращается по Ctrl+Z.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Serializer = require(Shared.Serializer)
local Util = require(Shared.Util)
local UG = require(Shared.Underground)
local Prefabs = require(Shared.Prefabs)

local Data = require(script.Parent.Data)
local Plots = require(script.Parent.Plots)
local Building = require(script.Parent.Building)
local Underground = require(script.Parent.Underground)

local PrefabShop = {}

type Spec = Serializer.Spec
type Plot = Plots.Plot

-- Запись в Shared/Prefabs (её создаёт tools/gen_prefabs.py)
export type Prefab = {
	key: string,
	kind: string, -- "house" | "bunker"
	tier: number,
	name: string,
	icon: string,
	price: number,
	desc: string,
	features: { string },
	blocks: number,
	guards: number,
	aa: number,
	shields: number,
	medkits: number,
	data: string,
}

-- Коробка в координатах участка: нижний и верхний углы
type Box = { lo: Vector3, hi: Vector3 }

-- Что нужно для установки: блоки постройки, зона замены, маска земли (у бункера)
type Plan = { specs: { Spec }, zone: Box?, dug: { [number]: boolean }? }

local EPS = 0.01
local MARGIN = 1          -- зона замены шире постройки на 1 стад по X и Z
local KIOSK_LO = 24       -- вход бункера стоит в углу участка: x, z от 24 до 32 (клетки 15–16)
local PLACE_COOLDOWN = 1.5 -- установка тяжёлая (сотни блоков) — не чаще раза в 1,5 секунды

local byKey: { [string]: Prefab } = {}
for _, p in (Prefabs :: { Prefab }) do
	byKey[p.key] = p
end

local plans: { [string]: Plan } = {}
local lastPlace: { [Player]: number } = {}

local function find(key: any): Prefab?
	if typeof(key) ~= "string" then
		return nil
	end
	return byKey[key]
end

local function boxOf(spec: Spec): Box
	local e = Grid.extents(spec.size, spec.rot)
	return { lo = spec.pos - e / 2, hi = spec.pos + e / 2 }
end

-- Коробки пересекаются по объёму (касание гранями не считается)
local function intersects(a: Box, b: Box): boolean
	return a.lo.X < b.hi.X - EPS and b.lo.X < a.hi.X - EPS
		and a.lo.Y < b.hi.Y - EPS and b.lo.Y < a.hi.Y - EPS
		and a.lo.Z < b.hi.Z - EPS and b.lo.Z < a.hi.Z - EPS
end

-- Общие габариты списка блоков (nil — список пустой)
local function bounds(specs: { Spec }): Box?
	local lo, hi
	for _, spec in specs do
		local b = boxOf(spec)
		lo = if lo then lo:Min(b.lo) else b.lo
		hi = if hi then hi:Max(b.hi) else b.hi
	end
	if not (lo and hi) then
		return nil
	end
	return { lo = lo, hi = hi }
end

local function grow(b: Box, d: number): Box
	local v = Vector3.new(d, 0, d)
	return { lo = b.lo - v, hi = b.hi + v }
end

-- План установки считается один раз на постройку
local function planOf(prefab: Prefab): Plan
	local cached = plans[prefab.key]
	if cached then
		return cached
	end
	local specs = Serializer.decode(prefab.data)
	local plan: Plan
	if prefab.kind == "bunker" then
		-- зона входа: угол участка (и наземная часть бункера, если она вдруг шире) по высоте входа
		local surface = {}
		for _, spec in specs do
			if boxOf(spec).lo.Y >= -EPS then
				table.insert(surface, spec)
			end
		end
		local s = bounds(surface)
		local zone: Box? = nil
		if s then
			local edge = Config.PlotSize.X / 2
			zone = grow({
				lo = Vector3.new(math.min(KIOSK_LO, s.lo.X), 0, math.min(KIOSK_LO, s.lo.Z)),
				hi = Vector3.new(math.max(edge, s.hi.X), s.hi.Y, math.max(edge, s.hi.Z)),
			}, MARGIN)
		end
		plan = { specs = specs, zone = zone, dug = UG.decode(Serializer.dig(prefab.data)) }
	else
		local b = bounds(specs)
		plan = { specs = specs, zone = if b then grow(b, MARGIN) else nil }
	end
	plans[prefab.key] = plan
	return plan
end

-- Блоки участка, которые уступят место постройке
local function blocksToRemove(plot: Plot, prefab: Prefab, plan: Plan): { BasePart }
	local list = {}
	local bunker = prefab.kind == "bunker"
	for _, child in plot.blocks:GetChildren() do
		if child:IsA("BasePart") then
			local b = boxOf(Building.specOf(child))
			if (bunker and b.lo.Y < -EPS) or (plan.zone and intersects(b, plan.zone)) then
				table.insert(list, child)
			end
		end
	end
	return list
end

local rescueParams = OverlapParams.new()
rescueParams.FilterType = Enum.RaycastFilterType.Include

-- Персонажей, которых засыпало землёй или задело стенами новой постройки, переносим к точке появления
local function rescue(plot: Plot)
	rescueParams.FilterDescendantsInstances = { plot.blocks }
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if char and root and Plots.isInBuildZone(plot, root.Position, 2) then
			local stuck = false
			local ix, iy, iz = UG.cellAt(plot.cf:PointToObjectSpace(root.Position))
			if ix and iy and iz and not plot.dug[UG.index(ix, iy, iz)] then
				stuck = true -- внутри земли
			else
				local box = root.Size - Vector3.new(0.2, 0.2, 0.2)
				for _, hit in workspace:GetPartBoundsInBox(root.CFrame, box, rescueParams) do
					if hit.CanCollide then
						stuck = true -- внутри стены
						break
					end
				end
			end
			if stuck then
				char:PivotTo(plot.spawn.CFrame + Vector3.new(0, 4, 0))
			end
		end
	end
end

-- Купить постройку (удалённый вызов BuyPrefab)
function PrefabShop.buy(player: Player, key: any): (boolean, string?)
	local prefab = find(key)
	if not prefab then
		return false, "Нет такой постройки"
	end
	local profile = Data.get(player)
	if not profile then
		return false, "Профиль ещё загружается — попробуй через пару секунд"
	end
	if profile.Prefabs[prefab.key] then
		return false, "Уже куплено"
	end
	if profile.Gold < prefab.price then
		return false, "Не хватает золота: нужно ещё " .. Util.formatNumber(prefab.price - profile.Gold)
	end
	profile.Gold -= prefab.price
	profile.Prefabs[prefab.key] = true
	Data.sync(player)
	task.spawn(Data.save, player)
	return true, "Куплено: «" .. prefab.name .. "»! Жми «Поставить на участок»"
end

-- Поставить постройку на участок игрока. free = true — без проверки покупки и антиспама
-- (только для сервера: админ-панель). Клиент сюда не попадает — у него PrefabShop.place.
function PrefabShop.placeInternal(player: Player, key: any, free: boolean?): (boolean, string?)
	local prefab = find(key)
	if not prefab or (prefab.kind ~= "house" and prefab.kind ~= "bunker") then
		return false, "Нет такой постройки"
	end
	local plot = Plots.of(player)
	if not plot then
		return false, "У тебя нет участка"
	end
	local can, why = Building.canEdit(plot)
	if not can then
		return false, why
	end
	if not free then
		if not Data.get(player) then
			return false, "Профиль ещё загружается — попробуй через пару секунд"
		end
		if not Data.ownsPrefab(player, prefab.key) then
			return false, "Сначала купи «" .. prefab.name .. "» в магазине"
		end
		local now = os.clock()
		if now - (lastPlace[player] or 0) < PLACE_COOLDOWN then
			return false, "Подожди секунду — постройка ещё ставится"
		end
		lastPlace[player] = now
	end

	local plan = planOf(prefab)
	local bunker = prefab.kind == "bunker"
	if #plan.specs == 0 or (bunker and next(plan.dug or {}) == nil) then
		return false, "Эту постройку сейчас нельзя поставить"
	end
	-- сначала всё считаем и проверяем: участок меняется, только если постройка точно влезет
	local remove = blocksToRemove(plot, prefab, plan)
	local total = Building.count(plot) - #remove + #plan.specs
	if total > Config.MaxBlocks then
		return false, string.format("Не хватит лимита: получится %s из %s блоков. Убери лишние блоки и попробуй снова",
			Util.formatNumber(total), Util.formatNumber(Config.MaxBlocks))
	end

	Building.pushUndo(plot, { type = "clear", data = Building.serialize(plot) })
	for _, part in remove do
		part:Destroy()
	end
	if bunker and plan.dug then
		-- маска ставится до блоков: подземные блоки проверяются по выкопанным клеткам
		Underground.setMask(plot, plan.dug)
	end
	Building.loadString(plot, prefab.data)
	rescue(plot)

	if bunker then
		return true, "Бункер «" .. prefab.name .. "» построен! Вход — в углу участка. Отменить — Ctrl+Z"
	end
	return true, "Дом «" .. prefab.name .. "» поставлен! Отменить — Ctrl+Z"
end

-- Удалённый вызов PlacePrefab: лишние аргументы клиента отбрасываются, бесплатно поставить нельзя
function PrefabShop.place(player: Player, key: any): (boolean, string?)
	return PrefabShop.placeInternal(player, key, false)
end

Players.PlayerRemoving:Connect(function(player)
	lastPlace[player] = nil
end)

return PrefabShop
