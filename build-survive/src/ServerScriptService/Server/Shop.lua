-- Магазин: покупка материалов и особых блоков за золото.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Blocks = require(Shared.Blocks)
local Util = require(Shared.Util)

local Data = require(script.Parent.Data)

local Shop = {}

function Shop.buy(player: Player, kind: any, id: any): (boolean, string?)
	id = tonumber(id)
	if not id or (kind ~= "mat" and kind ~= "item") then
		return false, nil
	end
	local def = (kind == "item") and Blocks.ItemById[id] or Blocks.MaterialById[id]
	if not def then
		return false, nil
	end
	local profile = Data.get(player)
	if not profile then
		return false, nil
	end
	local key = (kind == "item" and "i:" or "m:") .. def.key
	if def.price <= 0 or profile.Unlocked[key] then
		return false, "Уже есть"
	end
	if profile.Gold < def.price then
		return false, "Не хватает золота: нужно ещё " .. Util.formatNumber(def.price - profile.Gold)
	end
	profile.Gold -= def.price
	profile.Unlocked[key] = true
	Data.sync(player)
	task.spawn(Data.save, player)
	return true, "Куплено: " .. def.name
end

return Shop
