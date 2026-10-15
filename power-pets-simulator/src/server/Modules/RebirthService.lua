--[[
	RebirthService — перерождение.
	Сбрасывает силу, накопленную силу и монеты, навсегда даёт +50% к силе за клик.
	Питомцы, рюкзак и открытые миры остаются.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Modules.Formulas)
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)

local Modules = script.Parent
local DataService = require(Modules.DataService)
local PlayerState = require(Modules.PlayerState)
local RateLimiter = require(Modules.RateLimiter)

local RebirthService = {}

local rebirthLimiter = RateLimiter.new(1, 2)

function RebirthService.Rebirth(player)
	local data = DataService.Get(player)
	if not data then
		return false, "Данные ещё загружаются…"
	end
	local cost = Formulas.RebirthCost(data.Rebirths)
	if data.TotalStrength < cost then
		return false, string.format("Нужно ещё %s накопленной силы", Format.Number(cost - data.TotalStrength))
	end

	data.Rebirths += 1
	data.Strength = 0
	data.TotalStrength = 0
	data.Coins = 0
	PlayerState.SyncPets(player)
	PlayerState.Effect(player, "Rebirth", { Rebirths = data.Rebirths })
	return true, string.format("Перерождение #%d! Бонус к силе теперь %s", data.Rebirths, Format.Multiplier(Formulas.RebirthMultiplier(data.Rebirths)))
end

function RebirthService.Init()
	Remotes.Rebirth.OnServerInvoke = function(player)
		if not rebirthLimiter:Allow(player) then
			return false, "Не так быстро!"
		end
		return RebirthService.Rebirth(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		rebirthLimiter:Remove(player)
	end)
end

return RebirthService
