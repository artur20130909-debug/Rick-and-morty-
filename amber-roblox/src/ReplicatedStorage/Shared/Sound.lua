-- Звуки по ключу из Config.Sounds. Пустой ID — тишина (без ошибок).
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Config = require(script.Parent.Config)
local B = require(script.Parent.Build)

local Sound = {}

function Sound.id(key)
	return B.asset(Config.Sounds[key])
end

-- where: BasePart/Attachment (звук в 3D), Vector3 (точка в мире) или nil (2D — только на клиенте)
function Sound.play(key, where, props)
	local id = Sound.id(key)
	if id == "" then return nil end
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundId = id
	s.Volume = 0.6
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 120
	B.apply(s, props)
	if typeof(where) == "Vector3" then
		local a = Instance.new("Attachment")
		a.Name = "SoundPoint"
		a.Parent = workspace.Terrain
		a.WorldPosition = where
		s.Parent = a
		Debris:AddItem(a, s.Looped and 3600 or 20)
	elseif typeof(where) == "Instance" then
		s.Parent = where
	else
		s.Parent = SoundService
	end
	s:Play()
	if not s.Looped then
		s.Ended:Connect(function() s:Destroy() end)
		Debris:AddItem(s, 30)
	end
	return s
end

-- зацикленный звук (фон, гул): возвращает Sound, его можно :Stop()/:Destroy()
function Sound.loop(key, where, props)
	local p = { Looped = true }
	for k, v in pairs(props or {}) do p[k] = v end
	return Sound.play(key, where, p)
end

return Sound
