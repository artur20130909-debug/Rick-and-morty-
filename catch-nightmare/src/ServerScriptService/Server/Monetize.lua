-- Покупки за Robux: товар «Удача ×2 для всего сервера» и геймпассы (×2 Страха, +2 клетки).
-- ID задаются в Config.Products / Config.Passes; 0 — товар выключен.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)

local Monetize = {}
local S
local granted = {} -- PurchaseId -> true (чтобы не выдать дважды)

local function applyPass(player, name)
	player:SetAttribute("Pass" .. name, true)
	if name == "ExtraCages" then
		S.Data.sync(player)
		S.Bases.refreshPlayer(player)
	elseif name == "DoubleFear" then
		S.Bases.refreshPlayer(player, true)
	end
end

function Monetize.checkPasses(player)
	for name, p in pairs(Config.Passes) do
		if p.id and p.id ~= 0 then
			local ok, owns = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, p.id) end)
			if ok and owns then applyPass(player, name) end
		end
	end
end

function Monetize.init(s)
	S = s
	MarketplaceService.ProcessReceipt = function(info)
		if granted[info.PurchaseId] then return Enum.ProductPurchaseDecision.PurchaseGranted end
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local luck = Config.Products.ServerLuck
		if luck.id ~= 0 and info.ProductId == luck.id then
			S.Cycle.addServerLuck(luck.minutes, player.DisplayName)
			granted[info.PurchaseId] = true
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then return end
		for name, p in pairs(Config.Passes) do
			if p.id ~= 0 and p.id == passId then applyPass(player, name) end
		end
	end)
end

return Monetize
