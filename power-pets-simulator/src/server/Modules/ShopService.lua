--[[
	ShopService — магазин: рюкзаки за монеты и геймпасс «+2 слота питомцев».

	Геймпасс: если GameConfig.PetSlotsGamepassId = 0, это заглушка — кнопка выдаёт слоты
	бесплатно (флаг PetSlotsPass сохраняется в данных). Когда впишешь настоящий ID,
	заработает покупка за Robux через MarketplaceService, а тестовый флаг перестанет учитываться.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Backpacks = require(Shared.Config.Backpacks)
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)

local Modules = script.Parent
local DataService = require(Modules.DataService)
local PlayerState = require(Modules.PlayerState)
local RateLimiter = require(Modules.RateLimiter)

local ShopService = {}

local shopLimiter = RateLimiter.new(4, 6)

function ShopService.BuyBackpack(player, level)
	local data = DataService.Get(player)
	if not data then
		return false, "Данные ещё загружаются…"
	end
	if type(level) ~= "number" then
		return false, "Неверный рюкзак"
	end
	level = math.floor(level)
	if level <= data.BackpackLevel then
		return false, "Этот рюкзак уже есть"
	end
	if level ~= data.BackpackLevel + 1 then
		return false, "Сначала купи предыдущий рюкзак"
	end
	local backpack = Backpacks[level]
	if not backpack then
		return false, "Это самый большой рюкзак"
	end
	if data.Coins < backpack.Price then
		return false, string.format("Не хватает монет: нужно %s", Format.Number(backpack.Price))
	end
	data.Coins -= backpack.Price
	data.BackpackLevel = level
	PlayerState.SyncStats(player)
	PlayerState.Effect(player, "Purchase", { Kind = "Backpack", Level = level })
	return true, string.format("Куплен «%s»: вмещает %s силы", backpack.Name, Format.Number(backpack.Capacity))
end

local function grantPetSlots(player)
	PlayerState.SyncPets(player)
	PlayerState.Effect(player, "Purchase", { Kind = "PetSlots" })
end

function ShopService.BuyPetSlots(player)
	local data = DataService.Get(player)
	if not data then
		return false, "Данные ещё загружаются…"
	end
	if PlayerState.HasPetSlots(player, data) then
		return false, "Уже куплено"
	end

	local gamepassId = GameConfig.PetSlotsGamepassId
	if gamepassId == 0 then
		data.PetSlotsPass = true
		grantPetSlots(player)
		return true, "Тестовый геймпасс: теперь можно надеть " .. GameConfig.GamepassEquipSlots .. " питомцев!"
	end

	MarketplaceService:PromptGamePassPurchase(player, gamepassId)
	return true, nil
end

-- Проверка настоящего геймпасса при входе.
function ShopService.PlayerLoaded(player)
	local gamepassId = GameConfig.PetSlotsGamepassId
	if gamepassId == 0 then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)
	PlayerState.SetOwnsGamepass(player, ok and owns)
end

function ShopService.PlayerRemoving(player)
	shopLimiter:Remove(player)
end

function ShopService.Init()
	Remotes.BuyBackpack.OnServerInvoke = function(player, level)
		if not shopLimiter:Allow(player) then
			return false, "Не так быстро!"
		end
		return ShopService.BuyBackpack(player, level)
	end

	Remotes.BuyPetSlots.OnServerInvoke = function(player)
		if not shopLimiter:Allow(player) then
			return false, "Не так быстро!"
		end
		return ShopService.BuyPetSlots(player)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, purchased)
		if purchased and gamepassId == GameConfig.PetSlotsGamepassId and gamepassId ~= 0 then
			PlayerState.SetOwnsGamepass(player, true)
			grantPetSlots(player)
			PlayerState.Notify(player, "Спасибо за покупку! Теперь можно надеть " .. GameConfig.GamepassEquipSlots .. " питомцев", "success")
		end
	end)

	Players.PlayerRemoving:Connect(ShopService.PlayerRemoving)
end

return ShopService
