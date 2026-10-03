-- Точка входа сервера Amber Alert: удалённые события, служебные папки и запуск модулей по порядку.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("Shared")
local Server = script.Parent:WaitForChild("Server")

local ctx = {
	Config = require(Shared:WaitForChild("Config")),
	Build = require(Shared:WaitForChild("Build")),
	Net = require(Shared:WaitForChild("Net")),
	Sound = require(Shared:WaitForChild("Sound")),
}
ctx.Net.init()
Players.CharacterAutoLoads = false   -- персонажей появляет сам сервер (лобби, дом, рассвет)

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end
folder(workspace, "Houses")
folder(workspace, "Inmates")
folder(workspace, "Props")
folder(RS, "Matches")

local order = { "Data", "HouseMap", "LobbyMap", "HouseLogic", "Items", "InmateAI", "Match", "Lobby" }
for _, name in ipairs(order) do
	local m = Server:FindFirstChild(name)
	if m then
		local ok, mod = pcall(require, m)
		if ok then
			ctx[name] = mod
		else
			warn("[AA] Модуль " .. name .. " не загрузился: " .. tostring(mod))
		end
	else
		warn("[AA] Нет модуля " .. name)
	end
end
for _, name in ipairs(order) do
	local mod = ctx[name]
	if type(mod) == "table" and mod.init then
		local ok, err = pcall(mod.init, ctx)
		if not ok then warn("[AA] Ошибка запуска " .. name .. ": " .. tostring(err)) end
	end
end
print("[AA] Сервер Amber Alert запущен")
