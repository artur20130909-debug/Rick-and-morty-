--[[
	Sounds — проигрывает звуки интерфейса. Список звуков — в Shared/Config/Sounds.
	Каждый звук клонируется, поэтому быстрые клики не обрывают друг друга.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Sounds"))

local Sounds = {}

local folder = Instance.new("Folder")
folder.Name = "PowerPetsSounds"
folder.Parent = SoundService

local templates = {}
for name, config in pairs(SoundConfig) do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = config.Id
	sound.Volume = config.Volume or 0.5
	sound.PlaybackSpeed = config.Pitch or 1
	sound.Parent = folder
	templates[name] = sound
end

local lastPlayed = {}

-- pitch — дополнительный множитель высоты (для разнообразия кликов).
function Sounds.Play(name, pitch)
	local template = templates[name]
	if not template then
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

return Sounds
