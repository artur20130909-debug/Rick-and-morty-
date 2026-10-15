--[[
	Power Pets Simulator — главный серверный скрипт.
	Строит миры, запускает сервисы, загружает и сохраняет игроков.
	Вся логика валют, яиц и питомцев выполняется только здесь, на сервере.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
require(Shared.Modules.Remotes) -- создаёт RemoteEvent / RemoteFunction

local Modules = script.Parent:WaitForChild("Modules")
local DataService = require(Modules.DataService)
local PlayerState = require(Modules.PlayerState)
local WorldBuilder = require(Modules.WorldBuilder)
local WorldService = require(Modules.WorldService)
local ClickService = require(Modules.ClickService)
local PetService = require(Modules.PetService)
local EggService = require(Modules.EggService)
local ShopService = require(Modules.ShopService)
local RebirthService = require(Modules.RebirthService)

local worldRefs = WorldBuilder.Build()

DataService.Init()
WorldService.Init(worldRefs)
EggService.Init(worldRefs)
ClickService.Init()
PetService.Init()
ShopService.Init()
RebirthService.Init()

local function onPlayerAdded(player)
	PlayerState.Setup(player)
	WorldService.PlayerAdded(player)

	local data = DataService.Load(player)
	if not data or not player.Parent then
		return
	end

	ShopService.PlayerLoaded(player)
	PlayerState.SyncPets(player)
	-- Клиент покажет предупреждение, если прогресс не сохраняется.
	player:SetAttribute("SaveDisabled", not DataService.CanSave(player))
	player:SetAttribute("DataLoaded", true)
	WorldService.OnDataLoaded(player)
end

local function onPlayerRemoving(player)
	ClickService.PlayerRemoving(player)
	PetService.PlayerRemoving(player)
	WorldService.PlayerRemoving(player)
	DataService.Release(player)
	PlayerState.Remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Сохранение при выключении сервера.
game:BindToClose(function()
	DataService.SaveAll()
end)

-- Автосохранение.
task.spawn(function()
	while true do
		task.wait(GameConfig.AutosaveInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			if DataService.Get(player) then
				task.spawn(DataService.Save, player)
				task.wait(0.2) -- немного разносим запросы во времени
			end
		end
	end
end)

print("[Power Pets Simulator] Сервер запущен")
