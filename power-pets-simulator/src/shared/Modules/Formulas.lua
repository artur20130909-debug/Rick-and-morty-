--[[
	Formulas — вся математика игры в одном месте.
	Сервер считает по этим формулам, клиент — только чтобы показать подсказки в интерфейсе.
]]

local Config = script.Parent.Parent:WaitForChild("Config")
local GameConfig = require(Config.GameConfig)
local Pets = require(Config.Pets)
local Eggs = require(Config.Eggs)
local Rarities = require(Config.Rarities)
local Worlds = require(Config.Worlds)
local Backpacks = require(Config.Backpacks)

local Formulas = {}

-- Округление до сотых, чтобы дробная сила не копила ошибки вида 0.30000000004.
function Formulas.Round(value)
	if math.abs(value) >= 1e12 then
		return math.floor(value)
	end
	return math.floor(value * 100 + 0.5) / 100
end

-- Множитель одного питомца (золотой — в GoldenMultiplier раз больше).
function Formulas.PetMultiplier(petId, golden)
	local pet = Pets[petId]
	if not pet then
		return 1
	end
	local multiplier = pet.Multiplier
	if golden then
		multiplier *= GameConfig.GoldenMultiplier
	end
	return multiplier
end

-- Общий множитель от надетых питомцев.
-- Бонусы складываются: x1.2 и x1.5 вместе дают x1.7 (1 + 0.2 + 0.5).
function Formulas.TotalPetMultiplier(petList)
	local total = 1
	for _, pet in ipairs(petList) do
		if pet.Equipped then
			total += Formulas.PetMultiplier(pet.Id, pet.Golden) - 1
		end
	end
	return Formulas.Round(total)
end

-- Постоянный множитель от перерождений: +50% за каждое.
function Formulas.RebirthMultiplier(rebirths)
	return 1 + (rebirths or 0) * GameConfig.RebirthBonus
end

-- Сила за один клик.
function Formulas.ClickPower(petMultiplier, rebirths)
	return Formulas.Round(GameConfig.BaseClickPower * petMultiplier * Formulas.RebirthMultiplier(rebirths))
end

-- Сколько накопленной силы нужно для следующего перерождения.
function Formulas.RebirthCost(rebirths)
	return math.floor(GameConfig.RebirthBaseCost * GameConfig.RebirthCostGrowth ^ (rebirths or 0))
end

-- Сколько монет дадут за силу на точке продажи мира.
function Formulas.SellValue(strength, worldId)
	local world = Worlds[worldId]
	local multiplier = world and world.SellMultiplier or 1
	return math.floor(strength * multiplier + 1e-6)
end

function Formulas.BackpackCapacity(level)
	local backpack = Backpacks[level] or Backpacks[1]
	return backpack.Capacity
end

-- Шансы яйца: возвращает { [petId] = процент }, питомцев по редкостям и сумму весов.
local chanceCache = {}
function Formulas.EggChances(eggId)
	local cached = chanceCache[eggId]
	if cached then
		return cached.Chances, cached.ByRarity, cached.Total
	end

	local egg = Eggs[eggId]
	local byRarity, total = {}, 0
	for _, petId in ipairs(egg.Pets) do
		local rarity = Pets[petId].Rarity
		if not byRarity[rarity] then
			byRarity[rarity] = {}
			total += Rarities[rarity].Chance
		end
		table.insert(byRarity[rarity], petId)
	end

	local chances = {}
	for rarity, list in pairs(byRarity) do
		for _, petId in ipairs(list) do
			chances[petId] = Rarities[rarity].Chance / total / #list * 100
		end
	end

	chanceCache[eggId] = { Chances = chances, ByRarity = byRarity, Total = total }
	return chances, byRarity, total
end

-- Случайный питомец из яйца. Сначала выбирается редкость по шансам, потом питомец внутри неё.
function Formulas.RollEgg(eggId, rng)
	local _, byRarity, total = Formulas.EggChances(eggId)
	local roll = rng:NextNumber() * total
	local lastList
	for _, rarity in ipairs(Rarities.Order) do
		local list = byRarity[rarity]
		if list then
			lastList = list
			roll -= Rarities[rarity].Chance
			if roll <= 0 then
				return list[rng:NextInteger(1, #list)]
			end
		end
	end
	-- Сюда попадаем только из-за погрешности дробей.
	return lastList[rng:NextInteger(1, #lastList)]
end

-- Питомцы яйца, отсортированные от частых к редким (для табличек и интерфейса).
function Formulas.EggPetsSorted(eggId)
	local list = table.clone(Eggs[eggId].Pets)
	table.sort(list, function(a, b)
		local ra, rb = Rarities[Pets[a].Rarity].Order, Rarities[Pets[b].Rarity].Order
		if ra ~= rb then
			return ra < rb
		end
		return Pets[a].Multiplier < Pets[b].Multiplier
	end)
	return list
end

return Formulas
