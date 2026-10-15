--[[
	PetService — инвентарь питомцев: надеть, снять, удалить, «надеть лучших»,
	слияние 5 одинаковых в одного золотого. Всё проверяется на сервере.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Pets = require(Shared.Config.Pets)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Modules = script.Parent
local DataService = require(Modules.DataService)
local PlayerState = require(Modules.PlayerState)
local RateLimiter = require(Modules.RateLimiter)

local PetService = {}

local actionLimiter = RateLimiter.new(8, 10)

local function findPet(data, uid)
	for index, pet in ipairs(data.Pets) do
		if pet.Uid == uid then
			return pet, index
		end
	end
	return nil, nil
end

local function countEquipped(data)
	local count = 0
	for _, pet in ipairs(data.Pets) do
		if pet.Equipped then
			count += 1
		end
	end
	return count
end

local function petName(pet)
	local config = Pets[pet.Id]
	return (pet.Golden and "Золотой " or "") .. config.Name
end

-- Добавляет питомца в инвентарь (без синхронизации — её делает вызывающий код).
function PetService.AddPet(player, petId, golden)
	local data = DataService.Get(player)
	if not data or not Pets[petId] then
		return nil
	end
	local pet = {
		Uid = data.NextPetUid,
		Id = petId,
		Golden = golden == true,
		Equipped = false,
	}
	data.NextPetUid += 1
	table.insert(data.Pets, pet)
	return pet
end

-- Надевает питомца, если есть свободный слот (используется при вылуплении).
function PetService.TryAutoEquip(player, pet)
	local data = DataService.Get(player)
	if data and countEquipped(data) < PlayerState.MaxEquipped(player, data) then
		pet.Equipped = true
		return true
	end
	return false
end

function PetService.Equip(player, uid)
	local data = DataService.Get(player)
	local pet = findPet(data, uid)
	if not pet then
		return false, "Питомец не найден"
	end
	if pet.Equipped then
		return true
	end
	local maxEquipped = PlayerState.MaxEquipped(player, data)
	if countEquipped(data) >= maxEquipped then
		return false, string.format("Все слоты заняты (%d/%d). Сними кого-нибудь или купи +2 слота в магазине", maxEquipped, maxEquipped)
	end
	pet.Equipped = true
	PlayerState.SyncPets(player)
	return true, "Надет: " .. petName(pet)
end

function PetService.Unequip(player, uid)
	local data = DataService.Get(player)
	local pet = findPet(data, uid)
	if not pet then
		return false, "Питомец не найден"
	end
	pet.Equipped = false
	PlayerState.SyncPets(player)
	return true, "Снят: " .. petName(pet)
end

function PetService.Delete(player, uid)
	local data = DataService.Get(player)
	local pet, index = findPet(data, uid)
	if not pet then
		return false, "Питомец не найден"
	end
	table.remove(data.Pets, index)
	PlayerState.SyncPets(player)
	return true, "Удалён: " .. petName(pet)
end

function PetService.EquipBest(player)
	local data = DataService.Get(player)
	local sorted = table.clone(data.Pets)
	table.sort(sorted, function(a, b)
		local ma, mb = Formulas.PetMultiplier(a.Id, a.Golden), Formulas.PetMultiplier(b.Id, b.Golden)
		if ma ~= mb then
			return ma > mb
		end
		return a.Uid < b.Uid
	end)
	for _, pet in ipairs(data.Pets) do
		pet.Equipped = false
	end
	local maxEquipped = PlayerState.MaxEquipped(player, data)
	for index = 1, math.min(maxEquipped, #sorted) do
		sorted[index].Equipped = true
	end
	PlayerState.SyncPets(player)
	if #sorted == 0 then
		return false, "У тебя пока нет питомцев — открой яйцо!"
	end
	return true, "⭐ Надеты лучшие питомцы"
end

-- 5 одинаковых обычных питомцев -> 1 золотой (множитель ×2).
function PetService.Merge(player, uid)
	local data = DataService.Get(player)
	local pet = findPet(data, uid)
	if not pet then
		return false, "Питомец не найден"
	end
	if pet.Golden then
		return false, "Этот питомец уже золотой ✨"
	end

	local candidates = {}
	for _, other in ipairs(data.Pets) do
		if other.Id == pet.Id and not other.Golden then
			table.insert(candidates, other)
		end
	end
	local need = GameConfig.GoldenMergeCount
	if #candidates < need then
		return false, string.format("Нужно %d одинаковых: у тебя %d из %d", need, #candidates, need)
	end

	-- Сначала забираем ненадетых, выбранного питомца — в любом случае.
	table.sort(candidates, function(a, b)
		if (a == pet) ~= (b == pet) then
			return a == pet
		end
		if a.Equipped ~= b.Equipped then
			return not a.Equipped
		end
		return a.Uid < b.Uid
	end)
	local used = {}
	local wasEquipped = false
	for index = 1, need do
		used[candidates[index]] = true
		wasEquipped = wasEquipped or candidates[index].Equipped
	end
	local remaining = {}
	for _, other in ipairs(data.Pets) do
		if not used[other] then
			table.insert(remaining, other)
		end
	end
	data.Pets = remaining

	local golden = PetService.AddPet(player, pet.Id, true)
	if wasEquipped then
		golden.Equipped = true
	else
		PetService.TryAutoEquip(player, golden)
	end
	PlayerState.SyncPets(player)
	PlayerState.Effect(player, "Merge", { PetId = pet.Id, Uid = golden.Uid })
	return true, "✨ Получен " .. petName(golden) .. "!"
end

local ACTIONS = {
	Equip = PetService.Equip,
	Unequip = PetService.Unequip,
	Delete = PetService.Delete,
	Merge = PetService.Merge,
	EquipBest = PetService.EquipBest,
}

function PetService.PlayerRemoving(player)
	actionLimiter:Remove(player)
end

function PetService.Init()
	Remotes.PetAction.OnServerInvoke = function(player, action, uid)
		if not DataService.Get(player) then
			return false, "Данные ещё загружаются…"
		end
		if not actionLimiter:Allow(player) then
			return false, "Не так быстро!"
		end
		local handler = type(action) == "string" and ACTIONS[action]
		if not handler then
			return false, "Неизвестное действие"
		end
		if action ~= "EquipBest" and type(uid) ~= "number" then
			return false, "Неверный питомец"
		end
		return handler(player, uid)
	end

	Remotes.GetInventory.OnServerInvoke = function(player)
		local started = os.clock()
		while not DataService.Get(player) and player.Parent and os.clock() - started < 30 do
			task.wait(0.25)
		end
		return PlayerState.InventorySnapshot(player)
	end
end

return PetService
