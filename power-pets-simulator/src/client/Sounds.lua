--[[
	Sounds — звуки интерфейса и музыка миров. Настройки — в Shared/Config/Sounds.
	- Сразу работают встроенные звуки (Fallback).
	- Когда сервер найдёт звуки в библиотеке Roblox (ReplicatedStorage.SoundLibrary), клиент проверяет
	  каждый кандидат через ContentProvider:PreloadAsync и подменяет звук первым, который загрузился.
	- Музыка играет по кругу и плавно сменяется при переходе в другой мир.
	Каждый эффект клонируется, поэтому быстрые клики не обрывают друг друга.
]]

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Sounds"))

local Sounds = {}

local folder = Instance.new("Folder")
folder.Name = "PowerPetsSounds"
folder.Parent = SoundService

local templates = {}
for name, config in pairs(SoundConfig.Effects) do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = (config.Id and config.Id ~= "") and config.Id or config.Fallback
	sound.Volume = config.Volume or 0.5
	sound.PlaybackSpeed = config.Pitch or 1
	sound.Parent = folder
	templates[name] = sound
end

local lastPlayed = {}

-- pitch — дополнительный множитель высоты (для разнообразия кликов).
function Sounds.Play(name, pitch)
	local template = templates[name]
	if not template or template.SoundId == "" then
		return
	end
	-- Не больше ~25 одинаковых звуков в секунду.
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < 0.04 then
		return
	end
	lastPlayed[name] = now

	local sound = template:Clone()
	sound.PlaybackSpeed = template.PlaybackSpeed * (pitch or 1)
	sound.Parent = folder
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 8)
end

------------------------------------------------------------------ МУЗЫКА
local musicEnabled = true
local musicTracks = {} -- [worldId] = Sound
local currentWorld = nil
local currentTrack = nil

local function fadeTo(sound, volume, duration)
	TweenService:Create(sound, TweenInfo.new(duration or 1.5, Enum.EasingStyle.Sine), { Volume = volume }):Play()
end

local function updateMusic()
	local track = currentWorld and musicTracks[currentWorld] or nil
	if currentTrack and currentTrack ~= track then
		local old = currentTrack
		fadeTo(old, 0, 1.2)
		task.delay(1.3, function()
			if currentTrack ~= old then
				old:Stop()
			end
		end)
	end
	currentTrack = track
	if track then
		if not track.IsPlaying then
			track.Volume = 0
			track:Play()
		end
		fadeTo(track, musicEnabled and (track:GetAttribute("TargetVolume") or 0.3) or 0, 1.5)
	end
end

function Sounds.SetWorld(worldId)
	if worldId ~= currentWorld then
		currentWorld = worldId
		updateMusic()
	end
end

function Sounds.IsMusicEnabled()
	return musicEnabled
end

function Sounds.ToggleMusic()
	musicEnabled = not musicEnabled
	if currentTrack then
		fadeTo(currentTrack, musicEnabled and (currentTrack:GetAttribute("TargetVolume") or 0.3) or 0, 0.5)
	end
	return musicEnabled
end

------------------------------------------------------------------ ПОДБОР ЗВУКОВ ИЗ БИБЛИОТЕКИ
-- Первый кандидат, который реально загрузился (у Creator Store бывают недоступные звуки).
local function firstWorking(candidates)
	for _, id in ipairs(candidates) do
		local probe = Instance.new("Sound")
		probe.SoundId = id
		local status = nil
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ probe }, function(_, fetchStatus)
				status = fetchStatus
			end)
		end)
		probe:Destroy()
		if ok and status == Enum.AssetFetchStatus.Success then
			return id
		end
	end
	return nil
end

local function resolveEntry(value)
	local isMusic = value:GetAttribute("IsMusic") == true
	local started = os.clock()
	while not value:GetAttribute("Ready") and os.clock() - started < 40 do
		task.wait(0.5)
	end
	local candidates = {}
	if value.Value ~= "" then
		table.insert(candidates, value.Value)
	end
	for id in string.gmatch(value:GetAttribute("Candidates") or "", "[^,]+") do
		table.insert(candidates, id)
	end
	local id = firstWorking(candidates)

	if isMusic then
		local worldId = string.gsub(value.Name, "^Music_", "")
		local config = SoundConfig.Music[worldId]
		if not id or not config then
			return
		end
		local track = Instance.new("Sound")
		track.Name = value.Name
		track.SoundId = id
		track.Looped = true
		track.Volume = 0
		track:SetAttribute("TargetVolume", config.Volume or 0.3)
		track.Parent = folder
		musicTracks[worldId] = track
		if currentWorld == worldId then
			updateMusic()
		end
	elseif id and templates[value.Name] then
		templates[value.Name].SoundId = id
	end
end

function Sounds.Init()
	task.spawn(function()
		local library = ReplicatedStorage:WaitForChild("SoundLibrary", 30)
		if not library then
			return
		end
		for _, value in ipairs(library:GetChildren()) do
			if value:IsA("StringValue") then
				task.spawn(resolveEntry, value)
			end
		end
	end)
end

return Sounds
