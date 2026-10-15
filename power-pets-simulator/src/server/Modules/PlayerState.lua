--[[
	PlayerState — связывает данные игрока с тем, что видят клиенты:
	- leaderstats (Сила, Перерождения) для таблицы лидеров;
	- атрибуты игрока (Strength, Coins, ClickPower, EquippedPets, …) — их читает интерфейс
	  и все клиенты (чтобы рисовать чужих питомцев);
	- список питомцев (RemoteEvent InventoryChanged);
	- уведомления и эффекты.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Worlds = require(Shared.Config.Worlds)
local Backpacks = require(Shared.Config.Backpacks)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local DataService = require(script.Parent.DataService)

local PlayerState = {}

local petMultipliers = {} -- [player] = общий множитель питомцев
local ownsGamepass = {} -- [player] = true, если куплен настоящий геймпасс

function PlayerState.Setup(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local strength = Instance.new("IntValue")
	strength.Name = "Сила"
	strength.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Перерождения"
	rebirths.Parent = leaderstats

	leaderstats.Parent = player
end

function PlayerState.SetOwnsGamepass(player, owns)
	ownsGamepass[player] = owns == true
end

function PlayerState.HasPetSlots(player, data)
	if GameConfig.PetSlotsGamepassId == 0 then
		return data.PetSlotsPass == true
	end
	return ownsGamepass[player] == true
end

function PlayerState.MaxEquipped(player, data)
	data = data or DataService.Get(player)
	if data and PlayerState.HasPetSlots(player, data) then
		return GameConfig.GamepassEquipSlots
	end
	return GameConfig.BaseEquipSlots
end

function PlayerState.GetClickPower(player)
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	return Formulas.ClickPower(petMultipliers[player] or 1, data.Rebirths)
end

local function unlockedList(data)
	local list = {}
	for _, worldId in ipairs(Worlds.Order) do
		if data.UnlockedWorlds[worldId] then
			table.insert(list, worldId)
		end
	end
	return table.concat(list, ",")
end

-- Обновляет числа: атрибуты и leaderstats. Вызывается после любого изменения валют.
function PlayerState.SyncStats(player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local backpack = Backpacks[data.BackpackLevel]

	player:SetAttribute("Strength", data.Strength)
	player:SetAttribute("Capacity", backpack.Capacity)
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("TotalStrength", data.TotalStrength)
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("BackpackLevel", data.BackpackLevel)
	player:SetAttribute("World", data.CurrentWorld)
	player:SetAttribute("UnlockedWorlds", unlockedList(data))
	player:SetAttribute("RebirthMultiplier", Formulas.RebirthMultiplier(data.Rebirths))
	player:SetAttribute("PetMultiplier", petMultipliers[player] or 1)
	player:SetAttribute("ClickPower", PlayerState.GetClickPower(player))
	player:SetAttribute("PetSlotsPass", PlayerState.HasPetSlots(player, data))
	player:SetAttribute("MaxEquipped", PlayerState.MaxEquipped(player, data))

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local strength = leaderstats:FindFirstChild("Сила")
		local rebirths = leaderstats:FindFirstChild("Перерождения")
		if strength then
			strength.Value = math.floor(data.TotalStrength)
		end
		if rebirths then
			rebirths.Value = data.Rebirths
		end
	end
end

function PlayerState.InventorySnapshot(player)
	local data = DataService.Get(player)
	if not data then
		return {}
	end
	local list = table.create(#data.Pets)
	for index, pet in ipairs(data.Pets) do
		list[index] = {
			Uid = pet.Uid,
			Id = pet.Id,
			Golden = pet.Golden,
			Equipped = pet.Equipped,
		}
	end
	return list
end

-- Пересчитывает всё, что связано с питомцами, и отправляет инвентарь клиенту.
function PlayerState.SyncPets(player)
	local data = DataService.Get(player)
	if not data then
		return
	end

	-- Если слотов стало меньше (например, геймпасс пропал) — снимаем лишних.
	local maxEquipped = PlayerState.MaxEquipped(player, data)
	local equipped = 0
	local parts = {}
	for _, pet in ipairs(data.Pets) do
		if pet.Equipped then
			equipped += 1
			if equipped > maxEquipped then
				pet.Equipped = false
			else
				table.insert(parts, pet.Id .. ":" .. (pet.Golden and "1" or "0"))
			end
		end
	end

	petMultipliers[player] = Formulas.TotalPetMultiplier(data.Pets)
	player:SetAttribute("EquippedPets", table.concat(parts, ","))
	player:SetAttribute("PetCount", #data.Pets)

	Remotes.InventoryChanged:FireClient(player, PlayerState.InventorySnapshot(player))
	PlayerState.SyncStats(player)
end

function PlayerState.Notify(player, text, kind)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

function PlayerState.Effect(player, kind, payload)
	Remotes.Effect:FireClient(player, kind, payload or {})
end

function PlayerState.Remove(player)
	petMultipliers[player] = nil
	ownsGamepass[player] = nil
end

return PlayerState
