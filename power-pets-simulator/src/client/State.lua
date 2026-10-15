--[[
	State — то, что клиент знает о своём игроке.
	Числа (сила, монеты, множители…) сервер кладёт в атрибуты игрока — они приходят сами.
	Список питомцев приходит через RemoteEvent InventoryChanged.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Remotes"))

local State = {}

local player = Players.LocalPlayer
State.Player = player
State.Inventory = {}

local inventoryListeners = {}

local function fireInventory()
	for _, callback in ipairs(inventoryListeners) do
		task.spawn(callback, State.Inventory)
	end
end

function State.Get(name, default)
	local value = player:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

-- Вызывает callback сразу и при каждом изменении любого из атрибутов.
function State.Watch(names, callback)
	if type(names) == "string" then
		names = { names }
	end
	for _, name in ipairs(names) do
		player:GetAttributeChangedSignal(name):Connect(callback)
	end
	task.spawn(callback)
end

function State.OnInventory(callback)
	table.insert(inventoryListeners, callback)
	task.spawn(callback, State.Inventory)
end

function State.IsLoaded()
	return player:GetAttribute("DataLoaded") == true
end

-- Открытые миры: { Forest = true, … }
function State.UnlockedWorlds()
	local result = {}
	local text = State.Get("UnlockedWorlds", "Forest")
	for worldId in string.gmatch(text, "[^,]+") do
		result[worldId] = true
	end
	return result
end

function State.EquippedCount()
	local count = 0
	for _, pet in ipairs(State.Inventory) do
		if pet.Equipped then
			count += 1
		end
	end
	return count
end

function State.FindPet(uid)
	for _, pet in ipairs(State.Inventory) do
		if pet.Uid == uid then
			return pet
		end
	end
	return nil
end

-- Безопасный вызов RemoteFunction: никогда не кидает ошибку, возвращает ok, сообщение.
function State.Invoke(remote, ...)
	local args = table.pack(...)
	local ok, result, message = pcall(function()
		return remote:InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok then
		return false, "Нет связи с сервером"
	end
	return result, message
end

function State.Init()
	Remotes.InventoryChanged.OnClientEvent:Connect(function(list)
		if type(list) == "table" then
			State.Inventory = list
			fireInventory()
		end
	end)
	task.spawn(function()
		local ok, list = pcall(function()
			return Remotes.GetInventory:InvokeServer()
		end)
		if ok and type(list) == "table" and #State.Inventory == 0 then
			State.Inventory = list
			fireInventory()
		end
	end)
end

return State
