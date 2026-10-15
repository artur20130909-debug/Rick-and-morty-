--[[
	ClickService — клики. Клиент только сообщает «я кликнул», сервер сам считает силу.
	Защита от автокликеров: не больше GameConfig.MaxClicksPerSecond кликов в секунду,
	лишние клики просто не засчитываются.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Backpacks = require(Shared.Config.Backpacks)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Modules = script.Parent
local DataService = require(Modules.DataService)
local PlayerState = require(Modules.PlayerState)
local RateLimiter = require(Modules.RateLimiter)

local ClickService = {}

local clickLimiter = RateLimiter.new(GameConfig.MaxClicksPerSecond, math.max(3, math.floor(GameConfig.MaxClicksPerSecond / 3)))
local fullWarnedAt = {} -- [player] = когда последний раз предупреждали о полном рюкзаке

function ClickService.Click(player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if not clickLimiter:Allow(player) then
		return
	end

	local capacity = Backpacks[data.BackpackLevel].Capacity
	if data.Strength >= capacity then
		local now = os.clock()
		if (fullWarnedAt[player] or 0) + 5 < now then
			fullWarnedAt[player] = now
			PlayerState.Notify(player, "Рюкзак полон! Продай силу в зелёном круге продажи", "warning")
		end
		return
	end

	local power = PlayerState.GetClickPower(player)
	local newStrength = math.min(capacity, Formulas.Round(data.Strength + power))
	local gained = newStrength - data.Strength
	data.Strength = newStrength
	data.TotalStrength = Formulas.Round(data.TotalStrength + gained)
	data.Stats.Clicks += 1
	PlayerState.SyncStats(player)
end

function ClickService.PlayerRemoving(player)
	clickLimiter:Remove(player)
	fullWarnedAt[player] = nil
end

function ClickService.Init()
	Remotes.Click.OnServerEvent:Connect(ClickService.Click)
end

return ClickService
