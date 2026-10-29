-- Звуки на клиенте. Свой звук из ReplicatedStorage.SoundLibrary важнее встроенного.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Sounds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sounds"))

local SoundFX = {}
SoundFX.volume = 1

local host
local function hostPart()
	if host and host.Parent then return host end
	host = Instance.new("Part")
	host.Name = "SoundHost"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Transparency = 1
	host.Size = Vector3.one * 0.2
	host.CFrame = CFrame.new(0, -3000, 0)
	host.Parent = workspace:FindFirstChild("LocalFX") or workspace
	return host
end

local function resolve(name)
	local def = Sounds.get(name)
	if not def then return nil end
	local lib = ReplicatedStorage:FindFirstChild("SoundLibrary")
	local custom = lib and lib:FindFirstChild(name)
	if custom and custom:IsA("Sound") and custom.SoundId ~= "" then
		return custom.SoundId, def.volume * (custom.Volume > 0 and custom.Volume / 0.5 or 1), def.pitch, true
	end
	return def.id, def.volume, def.pitch, false
end

-- where: Vector3 (звук в точке), модель/деталь (звук на ней) или nil (без направления)
function SoundFX.play(name, where, volMul)
	local id, vol, pitch = resolve(name)
	if not id then return nil end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol * (volMul or 1) * SoundFX.volume
	s.PlaybackSpeed = pitch[1] + math.random() * (pitch[2] - pitch[1])
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 12
	s.RollOffMaxDistance = 240
	if typeof(where) == "Vector3" then
		local att = Instance.new("Attachment")
		att.Parent = hostPart()
		att.WorldPosition = where
		s.Parent = att
		Debris:AddItem(att, 6)
	elseif typeof(where) == "Instance" then
		local part = where:IsA("BasePart") and where or where:FindFirstChild("HumanoidRootPart") or where:FindFirstChildWhichIsA("BasePart")
		s.Parent = part or SoundService
	else
		s.Parent = SoundService
	end
	s:Play()
	Debris:AddItem(s, 6)
	return s
end

return SoundFX
