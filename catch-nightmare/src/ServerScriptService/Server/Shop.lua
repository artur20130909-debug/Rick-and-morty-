-- Лавка Ловца: сети (навсегда), приманки (запас обновляется каждые Config.RestockSeconds),
-- клетки. Запас общий на сервер, но каждый игрок может купить до «запаса» штук сам.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)

local Shop = {}
local S
local stock = {}
local restockId = 0
local bought = {} -- player -> { id = restockId, [key] = n }
local rng = Random.new()

local function toast(player, text, color) Net.event("Toast"):FireClient(player, text, color) end
local RED = Color3.fromRGB(255, 110, 90)
local GOLD = Color3.fromRGB(255, 220, 90)

local function restock()
	restockId = restockId + 1
	for _, b in ipairs(Config.Baits) do
		if rng:NextNumber() < b.inStock then stock[b.key] = rng:NextInteger(b.min, b.max) else stock[b.key] = 0 end
	end
	local state = RS:FindFirstChild("State")
	if state then state:SetAttribute("RestockAt", S.Cycle.now() + Config.RestockSeconds) end
	for _, b in ipairs(Config.Baits) do
		if b.inStock < 0.5 and stock[b.key] > 0 then
			S.Cycle.announce(string.format("🛒 В Лавке Ловца появилась %s %s!", b.icon, b.name), GOLD)
		end
	end
end
Shop.restock = restock

local function boughtOf(player)
	local t = bought[player]
	if not t or t.id ~= restockId then
		t = { id = restockId }
		bought[player] = t
	end
	return t
end

local function left(player, key)
	return math.max(0, (stock[key] or 0) - (boughtOf(player)[key] or 0))
end

function Shop.info(player)
	local p = S.Data.get(player)
	local l = {}
	for _, b in ipairs(Config.Baits) do l[b.key] = left(player, b.key) end
	return {
		stock = stock, left = l, restockAt = RS.State:GetAttribute("RestockAt"),
		net = p and p.net or 1, cages = p and p.cages or 0, maxCages = S.Data.maxCages(player),
	}
end

function Shop.buyCage(player)
	local p = S.Data.get(player)
	if not p then return end
	local n = p.cages + 1
	if n > S.Data.maxCages(player) then
		toast(player, "Больше клеток нет (геймпасс даёт ещё " .. Config.PassCages .. ")", RED)
		return
	end
	local price = Config.CagePrices[n] or math.huge
	if not S.Data.spend(player, price) then
		toast(player, "Не хватает Страха: нужно " .. Util.num(price) .. " 💀", RED)
		return
	end
	p.cages = n
	S.Data.sync(player)
	S.Bases.refreshPlayer(player)
	Net.event("Fx"):FireClient(player, "cash", -price)
	toast(player, "Новая клетка! Теперь их " .. n, GOLD)
end

local function buyNet(player)
	local p = S.Data.get(player)
	if not p then return end
	local def = Config.Nets[p.net + 1]
	if not def then
		toast(player, "У тебя лучшая сеть!", GOLD)
		return
	end
	if not S.Data.spend(player, def.price) then
		toast(player, "Не хватает Страха: нужно " .. Util.num(def.price) .. " 💀", RED)
		return
	end
	p.net = def.level
	S.Data.sync(player)
	Net.event("Fx"):FireClient(player, "cash", -def.price)
	toast(player, "🕸 " .. def.name .. "! Теперь ловишь монстров сети " .. def.level, GOLD)
end

local function buyBait(player, key)
	local def = Config.BaitIndex[key]
	local p = S.Data.get(player)
	if not def or not p then return end
	if left(player, key) <= 0 then
		toast(player, "Закончилось! Жди обновления лавки", RED)
		return
	end
	if not S.Data.spend(player, def.price) then
		toast(player, "Не хватает Страха: нужно " .. Util.num(def.price) .. " 💀", RED)
		return
	end
	local t = boughtOf(player)
	t[key] = (t[key] or 0) + 1
	p.baits[key] = (p.baits[key] or 0) + 1
	S.Data.sync(player)
	Net.event("Fx"):FireClient(player, "cash", -def.price)
	toast(player, def.icon .. " Куплено: " .. def.name, GOLD)
end

function Shop.buy(player, what, key)
	if what == "net" then buyNet(player)
	elseif what == "bait" then buyBait(player, key)
	elseif what == "cage" then Shop.buyCage(player)
	end
end

function Shop.init(s, shopCounter)
	S = s
	restock()
	Net.func("GetShop").OnServerInvoke = function(player) return Shop.info(player) end
	local prompt = shopCounter:FindFirstChild("ShopPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(player) Net.event("Fx"):FireClient(player, "openShop") end)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			local at = RS.State:GetAttribute("RestockAt") or 0
			if S.Cycle.now() >= at then
				local ok, err = pcall(restock)
				if not ok then warn("[CN] Shop: " .. tostring(err)) end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(pl) bought[pl] = nil end)
end

return Shop
