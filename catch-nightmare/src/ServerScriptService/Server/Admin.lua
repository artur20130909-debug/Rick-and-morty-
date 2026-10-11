-- Админ-команды для тестов и «админ-ивентов»: кнопки в админ-панели (Action "admin")
-- и команды в чате. Работают в Studio, у владельца игры и у UserId из Config.Admins.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Admin = {}
local S
local last = {} -- player -> { cmd, t } защита от двойного срабатывания

function Admin.isAdmin(player)
	if RunService:IsStudio() then return true end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then return true end
	return table.find(Config.Admins, player.UserId) ~= nil
end

local function spawnRarity(player, rarityKey)
	local list = Config.MonstersByRarity[rarityKey]
	if not list then return end
	local def = list[math.random(1, #list)]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local pos = hrp and (hrp.CFrame * CFrame.new(0, 0, -10)).Position or nil
	S.Wild.spawn({ pos = pos, key = def.key, mut = "" })
end

-- выполнить команду: "day", "night", "bloodmoon", "glitch", "fog", "spawn <редкость>", "fear <n>", "luck", "restock"
function Admin.run(player, text)
	if not Admin.isAdmin(player) or type(text) ~= "string" then return false end
	text = string.lower(text):gsub("^/", "")
	local cmd, arg = text:match("^(%S+)%s*(.*)$")
	if not cmd then return false end
	local l = last[player]
	if l and l.cmd == text and os.clock() - l.t < 0.5 then return true end
	last[player] = { cmd = text, t = os.clock() }
	if cmd == "day" then S.Cycle.force("day")
	elseif cmd == "night" then S.Cycle.force("night", arg ~= "" and arg or "")
	elseif cmd == "bloodmoon" or cmd == "glitch" or cmd == "fog" then S.Cycle.force("night", cmd)
	elseif cmd == "spawn" then spawnRarity(player, arg ~= "" and arg or "legendary")
	elseif cmd == "fear" then S.Data.addFear(player, tonumber(arg) or 10000)
	elseif cmd == "luck" then S.Cycle.addServerLuck(tonumber(arg) or Config.Products.ServerLuck.minutes, player.DisplayName)
	elseif cmd == "restock" then S.Shop.restock()
	else return false end
	Net.event("Toast"):FireClient(player, "Админ: " .. text, Color3.fromRGB(150, 200, 255))
	return true
end

function Admin.init(s)
	S = s
	local function hook(player)
		player:SetAttribute("IsAdmin", Admin.isAdmin(player))
		player.Chatted:Connect(function(msg)
			if string.sub(msg, 1, 1) == "/" then Admin.run(player, msg) end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, pl in ipairs(Players:GetPlayers()) do hook(pl) end
	Players.PlayerRemoving:Connect(function(pl) last[pl] = nil end)
end

return Admin
