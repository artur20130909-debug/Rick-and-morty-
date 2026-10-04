-- Точка входа клиента: собирает общий ctx и запускает клиентские модули по порядку.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Shared = RS:WaitForChild("Shared")
local ClientF = RS:WaitForChild("Client")

local ctx = {
	player = player,
	Config = require(Shared:WaitForChild("Config")),
	Build = require(Shared:WaitForChild("Build")),
	Net = require(Shared:WaitForChild("Net")),
	Sound = require(Shared:WaitForChild("Sound")),
}

local order = { "World", "UI", "Controls", "Hide", "Fx", "InmatesClient", "LobbySigns" }
for _, name in ipairs(order) do
	local m = ClientF:WaitForChild(name, 5)
	if m then
		local ok, mod = pcall(require, m)
		if ok then
			ctx[name] = mod
		else
			warn("[AA] Клиентский модуль " .. name .. " не загрузился: " .. tostring(mod))
		end
	else
		warn("[AA] Нет клиентского модуля " .. name)
	end
end
for _, name in ipairs(order) do
	local mod = ctx[name]
	if type(mod) == "table" and mod.init then
		local ok, err = pcall(mod.init, ctx)
		if not ok then warn("[AA] Ошибка запуска " .. name .. ": " .. tostring(err)) end
	end
end

-- свой «серверный» фонарик (его видят другие) у себя гасим: у нас есть локальный, он лучше
RunService.Heartbeat:Connect(function()
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local l = head and head:FindFirstChild("FlashlightRemote")
	if l and l.Enabled then l.Enabled = false end
end)

print("[AA] Клиент Stay Inside запущен")
