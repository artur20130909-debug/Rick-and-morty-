-- Точка входа сервера. Пока игра — это только карта.
-- Персонажи не появляются, пока карта не построена (иначе игрок упадёт в пустоту).
-- Если карта уже сохранена в месте (собрана заранее командой в Studio, см. README) — не строим заново.
local Players = game:GetService("Players")
local Map = require(script.Parent.Map)

Players.CharacterAutoLoads = false

if workspace:FindFirstChild("Map") then
	workspace:SetAttribute("MapReady", true)
else
	Map.build()
end

Players.CharacterAutoLoads = true
for _, plr in ipairs(Players:GetPlayers()) do
	if not plr.Character then
		task.spawn(function() plr:LoadCharacter() end)
	end
end
