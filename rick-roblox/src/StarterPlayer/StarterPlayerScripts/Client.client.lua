-- Запуск клиента: подключаем модули и передаём управление App (меню → главы 1–2).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = ReplicatedStorage:WaitForChild("Client")

local ctx = {
	Build = require(Shared:WaitForChild("Build")),
	Config = require(Shared:WaitForChild("Config")),
}
local names = { "Util", "Settings", "Audio", "Gui", "Hud", "Prompts", "Cine", "Controls", "World", "Outline",
	"Portal", "Menu", "Breakfast", "Phone", "Tentacles", "Rick", "PixelWorld", "Fx", "Ships", "CameraBase", "Lab",
	"Chapter2", "Story", "App" }
for _, n in ipairs(names) do
	ctx[n] = require(Client:WaitForChild(n))
end

-- порядок важен: настройки → звук → интерфейс → камера и управление
for _, n in ipairs({ "Settings", "Audio", "Gui", "Hud", "Prompts", "Cine", "Controls", "Portal", "Menu", "Breakfast", "Phone", "Tentacles", "Rick", "PixelWorld",
	"Fx", "Ships", "CameraBase", "Lab" }) do
	local ok, err = pcall(function() ctx[n].init(ctx) end)
	if not ok then warn("[RM] init " .. n .. ": " .. tostring(err)) end
end

ctx.App.start(ctx)
