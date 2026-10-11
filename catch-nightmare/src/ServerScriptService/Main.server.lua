-- Запуск сервера: строит карту, включает модули и встречает игроков.
-- Модули знают друг о друге через общую таблицу S (S.Data, S.Bases, S.Carry ...).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Util = require(Shared.Util)
local Server = script.Parent:WaitForChild("Server")

Net.init()

local S = {}
S.Data = require(Server.Data)
S.Cycle = require(Server.Cycle)
S.Bases = require(Server.Bases)
S.Carry = require(Server.Carry)
S.Wild = require(Server.Wild)
S.Shop = require(Server.Shop)
S.Monetize = require(Server.Monetize)
S.Admin = require(Server.Admin)

local world = require(Server.World).build()
S.Data.init(S)
S.Cycle.init(S)
S.Bases.init(S, world.bases)
S.Carry.init(S)
S.Wild.init(S)
S.Shop.init(S, world.shop)
S.Monetize.init(S)
S.Admin.init(S)

local function toast(player, text, color) Net.event("Toast"):FireClient(player, text, color) end

-- действия игрока
Net.event("Action").OnServerEvent:Connect(function(player, kind, a, b)
	local ok, err = pcall(function()
		if kind == "buy" then S.Shop.buy(player, a, b)
		elseif kind == "useBait" then S.Wild.useBait(player, a)
		elseif kind == "admin" then S.Admin.run(player, a)
		end
	end)
	if not ok then warn("[CN] Action " .. tostring(kind) .. ": " .. tostring(err)) end
end)

local function onCharacter(player, char)
	task.spawn(function()
		local hrp = char:WaitForChild("HumanoidRootPart", 10)
		if not hrp then return end
		task.wait(0.1)
		local cf = S.Bases.spawnCF(player)
		if cf then char:PivotTo(cf) end
		S.Cycle.applyLight(char)
	end)
	S.Carry.onCharacter(player, char)
end

local function onPlayer(player)
	local p = S.Data.load(player)
	if not player.Parent then
		S.Data.release(player)
		return
	end
	S.Monetize.checkPasses(player)
	local rec = S.Bases.assign(player)
	if not rec then
		player:Kick("Все базы на этом сервере заняты — зайди на другой сервер")
		return
	end
	S.Data.sync(player)
	-- доход, пока игрока не было
	if p.last > 0 then
		local away = math.min(os.time() - p.last, Config.OfflineCapSeconds)
		local inc = S.Bases.incomeOf(player)
		local earned = math.floor(away * inc * Config.OfflineRate)
		if away > 60 and earned > 0 then
			S.Data.addFear(player, earned)
			task.delay(3, function()
				if player.Parent then Net.event("Fx"):FireClient(player, "offline", earned, away) end
			end)
		end
	end
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	if player.Character then onCharacter(player, player.Character) end
	if p.isNew and Config.Wild.FirstCatchHelp then
		task.delay(4, function()
			if player.Parent then S.Wild.spawnHelper(player) end
		end)
	else
		task.delay(3, function()
			if player.Parent then toast(player, "С возвращением! Доход базы: +" .. Util.num(S.Bases.incomeOf(player)) .. " 💀/с", Color3.fromRGB(255, 230, 140)) end
		end)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, pl) end

Players.PlayerRemoving:Connect(function(player)
	S.Carry.onLeave(player)
	S.Data.release(player)
	S.Bases.release(player)
end)

print("[CN] " .. Config.GameName .. " запущена")
