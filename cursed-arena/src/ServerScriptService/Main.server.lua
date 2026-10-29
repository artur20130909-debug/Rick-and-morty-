-- Точка входа сервера CURSED ARENA
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")

local Kit = require(Server.Kit)
local Actions = require(Server.Actions)
local Spawner = require(Server.Spawner)
local MapService = require(Server.MapService)
local Bots = require(Server.Bots)
local Domains = require(Server.Domains)

-- папка для серверных «призывов» (псы, кулак тени и т.п.)
local fx = Instance.new("Folder")
fx.Name = "FX"
fx.Parent = workspace

Kit.MapService = MapService
Kit.Domains = Domains

-- приёмы персонажей: Server/Moves/<Персонаж>
for _, mod in ipairs(Server.Moves:GetChildren()) do
	if mod:IsA("ModuleScript") then
		local ok, res = pcall(require, mod)
		if ok then
			Actions.Moves[mod.Name] = res
		else
			warn("[Main] не загрузились приёмы " .. mod.Name .. ": " .. tostring(res))
		end
	end
end

MapService.init()
Spawner.init()
Actions.init(Spawner, Bots)
Bots.init()

-- облака
local terrain = workspace:FindFirstChildOfClass("Terrain")
if terrain and not terrain:FindFirstChildOfClass("Clouds") then
	local c = Instance.new("Clouds")
	c.Cover = 0.55
	c.Density = 0.55
	c.Color = Color3.fromRGB(255, 250, 245)
	c.Parent = terrain
end

print("[CURSED ARENA] сервер запущен")
