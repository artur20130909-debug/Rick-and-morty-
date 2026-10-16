-- Мир на клиенте: настройки графики, музыка (спокойная при стройке, боевая при осаде),
-- шум ветра, мигание огней на вражеских базах.
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sounds = require(Shared.Sounds)

local Client = script.Parent
local State = require(Client.State)
local SoundPlayer = require(Client.SoundPlayer)
local CameraShake = require(Client.CameraShake)
local Fx = require(Client.Fx)

local World = {}

function World.applySettings()
	local s = State.settings
	SoundPlayer.setVolumes(s.Sfx or 1, (s.Music or 0.5) * 0.9)
	CameraShake.enabled = s.CameraShake ~= false
	Fx.applyQuality()
end

local function updateMusic()
	if State.inSiege() then
		SoundPlayer.playlist(Sounds.SiegePlaylist)
	else
		SoundPlayer.playlist(Sounds.BuildPlaylist)
	end
end

function World.init()
	World.applySettings()
	updateMusic()
	SoundPlayer.play("Wind", { loop = true })
	State.changed:Connect(function(key)
		if key == "settings" then
			World.applySettings()
		elseif key == "siege" then
			updateMusic()
		end
	end)
	-- красные огни на антеннах вражеских баз мигают
	local lights = {}
	local map = workspace:WaitForChild("Map", 10)
	local forts = map and map:FindFirstChild("EnemyForts")
	if forts then
		for _, d in forts:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "AntennaLight" then
				table.insert(lights, d)
			end
		end
	end
	RunService.Heartbeat:Connect(function()
		local on = math.floor(os.clock() * 1.25) % 2 == 0
		for _, l in lights do
			l.Transparency = on and 0 or 0.85
			local pl = l:FindFirstChildOfClass("PointLight")
			if pl then
				pl.Enabled = on
			end
		end
	end)
end

return World
