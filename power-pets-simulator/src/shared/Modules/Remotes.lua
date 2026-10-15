--[[
	Remotes — все RemoteEvent / RemoteFunction игры.
	Сервер создаёт их в ReplicatedStorage.Remotes, клиент ждёт их появления.

	Клиент → сервер (клиент только просит, всё решает сервер):
		Click            RemoteEvent     клик / тап
		GetInventory     RemoteFunction  список питомцев при входе
		PetAction        RemoteFunction  ("Equip" | "Unequip" | "Delete" | "Merge" | "EquipBest", uid)
		BuyBackpack      RemoteFunction  (level)
		BuyPetSlots      RemoteFunction  геймпасс «+2 слота»
		Rebirth          RemoteFunction  перерождение
		Teleport         RemoteFunction  (worldId) — телепорт / открытие мира из меню
	Сервер → клиент:
		InventoryChanged RemoteEvent     (список питомцев)
		EggHatched       RemoteEvent     (eggId, результаты) — запуск анимации
		Notify           RemoteEvent     (текст, вид) — всплывающее сообщение
		Effect           RemoteEvent     (вид, данные) — звуки и эффекты (монета, продажа, …)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFINITIONS = {
	Click = "RemoteEvent",
	GetInventory = "RemoteFunction",
	PetAction = "RemoteFunction",
	BuyBackpack = "RemoteFunction",
	BuyPetSlots = "RemoteFunction",
	Rebirth = "RemoteFunction",
	Teleport = "RemoteFunction",
	InventoryChanged = "RemoteEvent",
	EggHatched = "RemoteEvent",
	Notify = "RemoteEvent",
	Effect = "RemoteEvent",
}

local Remotes = {}

if RunService:IsServer() then
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local isNew = folder == nil
	if isNew then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
	end
	for name, className in pairs(DEFINITIONS) do
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
		Remotes[name] = remote
	end
	if isNew then
		folder.Parent = ReplicatedStorage
	end
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for name in pairs(DEFINITIONS) do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
