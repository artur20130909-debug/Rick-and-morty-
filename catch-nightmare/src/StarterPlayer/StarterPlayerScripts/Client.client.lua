-- Запуск клиента: картинка мира (свет, подсказки, клетки) и интерфейс.
local RS = game:GetService("ReplicatedStorage")
local Client = RS:WaitForChild("Client")

local Visuals = require(Client:WaitForChild("Visuals"))
local UI = require(Client:WaitForChild("UI"))

Visuals.init()
UI.init()
