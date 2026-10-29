-- Сеть сервера: эффекты всем игрокам и личные сообщения
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = {}
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
Net.Action = Remotes:WaitForChild("Action")
Net.FXEvent = Remotes:WaitForChild("FX")
Net.PrivateEvent = Remotes:WaitForChild("Private")

-- эффект для всех: имя + таблица данных (модели, позиции, числа)
function Net.fx(name, data)
	Net.FXEvent:FireAllClients(name, data or {})
end

-- эффект всем, кроме одного игрока (он уже показал его у себя сам)
function Net.fxExcept(player, name, data)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then Net.FXEvent:FireClient(p, name, data or {}) end
	end
end

-- личное сообщение игроку
function Net.to(player, kind, data)
	if player and player.Parent then
		Net.PrivateEvent:FireClient(player, kind, data or {})
	end
end

return Net
