--[[
	collect_sound_ids.lua — помощник для ручной загрузки звуков (если не хотите API-ключ).

	1. Studio → Window → Asset Manager → кнопка Bulk Import → выберите все файлы из assets/sounds.
	2. Когда звуки появятся в Asset Manager (папка Audio), перетащите их все в Workspace —
	   появятся объекты Sound с именами файлов (click, coin, music_forest …).
	3. Выделите их (или ничего не выделяйте — скрипт проверит Workspace, SoundService и ReplicatedStorage),
	   вставьте ВЕСЬ этот файл в командную строку (Window → Command Bar) и нажмите Enter.
	4. Скопируйте напечатанную таблицу в src/shared/Config/SoundIds.lua вместо строк «return { … }».
	   Объекты Sound из Workspace после этого можно удалить.
]]

local FILES = {
	{ "Click", "click" },
	{ "Button", "button" },
	{ "Coin", "coin" },
	{ "Sell", "sell" },
	{ "EggShake", "egg_shake" },
	{ "Hatch", "egg_crack" },
	{ "Reveal", "reveal" },
	{ "Rare", "fanfare" },
	{ "Rebirth", "rebirth" },
	{ "Unlock", "unlock" },
	{ "Merge", "merge" },
	{ "Teleport", "teleport" },
	{ "Error", "error" },
	{ "Purchase", "purchase" },
	{ "Music_Forest", "music_forest" },
	{ "Music_Desert", "music_desert" },
	{ "Music_Space", "music_space" },
}

local function normalize(name)
	name = string.lower(name)
	name = string.gsub(name, "%.ogg$", "")
	name = string.gsub(name, "^powerpets[%s_%-]*", "")
	name = string.gsub(name, "[%s%-]+", "_")
	return name
end

local roots = game:GetService("Selection"):Get()
if #roots == 0 then
	roots = { workspace, game:GetService("SoundService"), game:GetService("ReplicatedStorage") }
end

local found = {}
for _, root in ipairs(roots) do
	local items = root:GetDescendants()
	table.insert(items, root)
	for _, item in ipairs(items) do
		if item:IsA("Sound") and string.match(item.SoundId, "%d+") then
			found[normalize(item.Name)] = item.SoundId
		end
	end
end

local lines = { "return {" }
local missing = {}
for _, pair in ipairs(FILES) do
	local id = found[pair[2]] or ""
	if id == "" then
		table.insert(missing, pair[2])
	end
	table.insert(lines, string.format('\t%s = "%s",', pair[1], id))
end
table.insert(lines, "}")
print("\n" .. table.concat(lines, "\n"))
if #missing > 0 then
	warn("Не найдены звуки: " .. table.concat(missing, ", ") .. " — для них останутся звуки из библиотеки Roblox.")
end
