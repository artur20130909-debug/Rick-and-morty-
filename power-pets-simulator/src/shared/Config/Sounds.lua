--[[
	Sounds — звуки и музыка.

	Как выбирается звук (по порядку):
	1. Id — собственный звук игры. Все звуки и музыка синтезированы скриптом tools/make_sounds.py
	   и лежат в assets/sounds (поле File). После загрузки в Roblox их ID попадают в Config/SoundIds
	   (см. README, «Свои звуки»), а отсюда — в поле Id.
	2. Search — пока своих ID нет, сервер при запуске ищет звук в библиотеке Roblox (Creator Store)
	   по этим словам, клиент проверяет, что звук загружается, и берёт первый рабочий.
	3. Fallback — встроенный звук Roblox, если ничего не нашлось.

	Volume — громкость, Pitch — скорость (выше = тоньше), MaxDuration — самая большая длина звука в секундах.
]]

local SoundIds = require(script.Parent:WaitForChild("SoundIds"))

local Sounds = {
	Effects = {
		Click = { Search = "pop click", MaxDuration = 2, Fallback = "rbxasset://sounds/clickfast.wav", Volume = 0.55, Pitch = 1, File = "click.ogg" },
		Button = { Search = "ui button click", MaxDuration = 2, Fallback = "rbxasset://sounds/button.wav", Volume = 0.45, Pitch = 1, File = "button.ogg" },
		Coin = { Search = "coin collect", MaxDuration = 3, Fallback = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 1, File = "coin.ogg" },
		Sell = { Search = "cash register", MaxDuration = 4, Fallback = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.65, Pitch = 1, File = "sell.ogg" },
		EggShake = { Search = "wood knock", MaxDuration = 2, Fallback = "rbxasset://sounds/snap.wav", Volume = 0.5, Pitch = 1.1, File = "egg_shake.ogg" },
		Hatch = { Search = "egg crack", MaxDuration = 3, Fallback = "rbxasset://sounds/glassbreak.wav", Volume = 0.55, Pitch = 1, File = "egg_crack.ogg" },
		Reveal = { Search = "magic sparkle", MaxDuration = 4, Fallback = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.55, Pitch = 1, File = "reveal.ogg" },
		Rare = { Search = "fanfare win", MaxDuration = 6, Fallback = "rbxasset://sounds/victory.wav", Volume = 0.6, Pitch = 1, File = "fanfare.ogg" },
		Rebirth = { Search = "power up", MaxDuration = 6, Fallback = "rbxasset://sounds/victory.wav", Volume = 0.65, Pitch = 1, File = "rebirth.ogg" },
		Unlock = { Search = "level up", MaxDuration = 5, Fallback = "rbxasset://sounds/victory.wav", Volume = 0.6, Pitch = 1, File = "unlock.ogg" },
		Merge = { Search = "magic chime", MaxDuration = 5, Fallback = "rbxasset://sounds/victory.wav", Volume = 0.6, Pitch = 1.1, File = "merge.ogg" },
		Teleport = { Search = "whoosh", MaxDuration = 3, Fallback = "rbxasset://sounds/swoosh.wav", Volume = 0.6, Pitch = 1, File = "teleport.ogg" },
		Error = { Search = "error buzz", MaxDuration = 2, Fallback = "rbxasset://sounds/hit.wav", Volume = 0.32, Pitch = 1, File = "error.ogg" },
		Purchase = { Search = "purchase success", MaxDuration = 3, Fallback = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.55, Pitch = 1, File = "purchase.ogg" },
	},

	-- Музыка для каждого мира (играет по кругу, кнопка с нотой её выключает).
	Music = {
		Forest = { Search = "happy cartoon adventure", MinDuration = 40, Volume = 0.3, File = "music_forest.ogg" },
		Desert = { Search = "arabian desert", MinDuration = 40, Volume = 0.3, File = "music_desert.ogg" },
		Space = { Search = "space ambient synth", MinDuration = 40, Volume = 0.3, File = "music_space.ogg" },
	},
}

-- ID из Config/SoundIds: строка "rbxassetid://…", просто цифры или число.
local function normalizeId(id)
	if type(id) == "number" then
		return "rbxassetid://" .. math.floor(id)
	end
	if type(id) ~= "string" or id == "" then
		return nil
	end
	if string.match(id, "^%d+$") then
		return "rbxassetid://" .. id
	end
	return id
end

for name, entry in pairs(Sounds.Effects) do
	entry.Id = normalizeId(SoundIds[name]) or entry.Id
end
for worldId, entry in pairs(Sounds.Music) do
	entry.Id = normalizeId(SoundIds["Music_" .. worldId]) or entry.Id
end

return Sounds
