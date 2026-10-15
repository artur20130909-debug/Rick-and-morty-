--[[
	SoundLibrary — подбирает звуки и музыку из библиотеки Roblox (Creator Store).
	Для каждого звука из Config/Sounds без ручного Id сервер ищет несколько кандидатов
	через AssetService:SearchAudioAsync и кладёт их в ReplicatedStorage.SoundLibrary
	(атрибут Candidates = "id1,id2,..."). Клиент проверяет, какой загружается, и берёт первый рабочий.
	Если поиск недоступен, клиент использует встроенные звуки (Fallback).
]]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Sounds"))

local SoundLibrary = {}

local MAX_CANDIDATES = 6

-- Чем «надёжнее» звук, тем выше он в списке: одобренные Roblox и звуки от самой Roblox.
local function score(item)
	local value = 0
	if item.IsEndorsed then
		value += 2
	end
	local creator = item.Creator
	if type(creator) == "table" then
		if creator.Name == "Roblox" or creator.Id == 1 then
			value += 3
		end
		if creator.HasVerifiedBadge or creator.IsVerified then
			value += 1
		end
	end
	return value
end

local function search(entry, isMusic)
	local ok, result = pcall(function()
		local params = Instance.new("AudioSearchParams")
		params.SearchKeyword = entry.Search
		params.AudioSubType = isMusic and Enum.AudioSubType.Music or Enum.AudioSubType.SoundEffect
		if entry.MaxDuration then
			params.MaxDuration = entry.MaxDuration
		end
		if entry.MinDuration then
			params.MinDuration = entry.MinDuration
		end
		local pages = AssetService:SearchAudioAsync(params)
		return pages:GetCurrentPage()
	end)
	if not ok or type(result) ~= "table" then
		return {}, tostring(result)
	end
	local items = {}
	for index, item in ipairs(result) do
		local id = type(item) == "table" and tonumber(item.Id or item.AssetId)
		if id then
			table.insert(items, { Id = id, Score = score(item), Index = index })
		end
	end
	table.sort(items, function(a, b)
		if a.Score ~= b.Score then
			return a.Score > b.Score
		end
		return a.Index < b.Index
	end)
	local ids = {}
	for index = 1, math.min(MAX_CANDIDATES, #items) do
		table.insert(ids, "rbxassetid://" .. items[index].Id)
	end
	return ids
end

function SoundLibrary.Init()
	local folder = Instance.new("Folder")
	folder.Name = "SoundLibrary"

	local function addEntry(name, entry, isMusic)
		local value = Instance.new("StringValue")
		value.Name = name
		value.Value = entry.Id or ""
		value:SetAttribute("IsMusic", isMusic)
		value:SetAttribute("Candidates", "")
		value.Parent = folder
		return value
	end

	local jobs = {}
	for name, entry in pairs(SoundConfig.Effects) do
		table.insert(jobs, { Value = addEntry(name, entry, false), Entry = entry, IsMusic = false })
	end
	for worldId, entry in pairs(SoundConfig.Music) do
		table.insert(jobs, { Value = addEntry("Music_" .. worldId, entry, true), Entry = entry, IsMusic = true })
	end
	folder.Parent = ReplicatedStorage

	-- Поиск идёт в фоне и не задерживает запуск игры.
	task.spawn(function()
		local failures = 0
		for _, job in ipairs(jobs) do
			if (job.Entry.Id or "") == "" and job.Entry.Search then
				local ids, err = search(job.Entry, job.IsMusic)
				if #ids > 0 then
					job.Value:SetAttribute("Candidates", table.concat(ids, ","))
				else
					failures += 1
					if failures == 1 and err then
						warn("[SoundLibrary] Поиск звуков недоступен, будут встроенные звуки:", err)
					end
				end
				task.wait(0.2)
			end
			job.Value:SetAttribute("Ready", true)
		end
		folder:SetAttribute("Ready", true)
	end)
end

return SoundLibrary
