-- Запуск сервера: строим дом Смитов, двери и улицу, настраиваем персонажей (все — Морти).
-- Сюжет, меню и камера работают на клиенте (StarterPlayerScripts/Client).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent:WaitForChild("Server")

local ctx = {
	Build = require(Shared:WaitForChild("Build")),
	Config = require(Shared:WaitForChild("Config")),
}
ctx.House = require(Server:WaitForChild("House"))
local Rooms = require(Server:WaitForChild("Rooms"))
local Doors = require(Server:WaitForChild("Doors"))
local Exterior = require(Server:WaitForChild("Exterior"))
local Characters = require(Server:WaitForChild("Characters"))

Players.CharacterAutoLoads = true
Characters.init(ctx)

local root = Instance.new("Model")
root.Name = "House"
local ok, err = pcall(function()
	ctx.House.build(ctx, root)
	Rooms.build(ctx, root)
	Doors.build(ctx, root)
	Exterior.build(ctx, root)
end)
if not ok then warn("[RM] ошибка постройки дома: " .. tostring(err)) end

-- точка появления — у кровати Морти (сюжет всё равно переставит персонажа)
local spawn = Instance.new("SpawnLocation")
spawn.Name = "MortySpawn"
spawn.Size = Vector3.new(4, 0.2, 4)
spawn.CFrame = CFrame.new(46.5, 12.1, 33.5)
spawn.Anchored = true
spawn.Transparency = 1
spawn.CanCollide = false
spawn.CanQuery = false
spawn.Neutral = true
spawn.Duration = 0
spawn.Parent = root

root.Parent = workspace
root:SetAttribute("Ready", true)
