-- Звук: музыка с плавной сменой треков, короткие эффекты из общего файла SfxAtlas
-- (кусок файла задаётся PlaybackRegion), 3D-звуки у предметов, петли (будильник, гул, птицы).
-- Если ID пустой — звук просто не играет.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Audio = {}
local Config, Settings, B
local musicGroup, sfxGroup, eq
local current -- текущая музыка { sound, key }
local loops = {}

local function group(name)
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = 1
	g.Parent = SoundService
	return g
end

function Audio.init(ctx)
	Config, Settings, B = ctx.Config, ctx.Settings, ctx.Build
	musicGroup = group("Music")
	sfxGroup = group("Sfx")
	eq = Instance.new("EqualizerSoundEffect")
	eq.Enabled = false
	eq.HighGain = -24
	eq.MidGain = -8
	eq.LowGain = 0
	eq.Parent = musicGroup
	local function applyVol()
		musicGroup.Volume = Settings.get("Music")
		sfxGroup.Volume = Settings.get("Sfx")
	end
	applyVol()
	Settings.Changed:Connect(applyVol)
end

local function asset(id) return B.asset(id) end

-- если атлас ещё не загружен — встроенные звуки Roblox для самого нужного
local FALLBACK = { Click = "UiClick", PhoneTap = "UiClick", AlarmOff = "UiClick" }

-- «приглушить» музыку (пауза, телефон)
function Audio.muffle(on)
	if eq then eq.Enabled = on end
end

-- музыка: key из Config.Sounds (MusicMenu / MusicMorning); fade — секунды
function Audio.music(key, fade, volume)
	fade = fade or 1.5
	if current and current.key == key then return end
	local old = current
	current = nil
	if old then
		local s = old.sound
		local tw = TweenService:Create(s, TweenInfo.new(fade), { Volume = 0 })
		tw:Play()
		tw.Completed:Connect(function() s:Destroy() end)
	end
	if not key then return end
	local id = asset(Config.Sounds[key])
	if id == "" then return end
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = musicGroup
	s.Parent = SoundService
	s:Play()
	TweenService:Create(s, TweenInfo.new(fade), { Volume = volume or 0.5 }):Play()
	current = { sound = s, key = key }
end

function Audio.stopMusic(fade) Audio.music(nil, fade) end

-- звук из атласа (или отдельный звук, если в Config.Sounds есть такой ключ)
-- opts: at = Instance (3D), volume, speed, pitchJitter, loop
function Audio.play(name, opts)
	opts = opts or {}
	local s = Instance.new("Sound")
	s.Name = name
	local region = Config.Sfx[name]
	local atlas = asset(Config.Sounds.SfxAtlas)
	local direct = Config.Sounds[name] or Config.Sounds[FALLBACK[name] or ""]
	if region and atlas ~= "" then
		s.SoundId = atlas
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(region[1], region[2])
		if opts.loop then s.LoopRegion = NumberRange.new(region[1], region[2]) end
	elseif direct and direct ~= "" then
		s.SoundId = asset(direct)
	else
		s:Destroy()
		return nil
	end
	s.Volume = opts.volume or 0.7
	local sp = opts.speed or 1
	if opts.pitchJitter then sp = sp * (1 + (math.random() * 2 - 1) * opts.pitchJitter) end
	s.PlaybackSpeed = sp
	s.Looped = opts.loop == true
	s.SoundGroup = sfxGroup
	if opts.at then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = opts.min or 6
		s.RollOffMaxDistance = opts.max or 70
		s.Parent = opts.at
	else
		s.Parent = SoundService
	end
	s:Play()
	if not s.Looped then
		local len = region and (region[2] - region[1]) or 4
		task.delay(len / math.max(sp, 0.1) + 0.5, function() if s.Parent then s:Destroy() end end)
	end
	return s
end

-- петля с именем (чтобы потом остановить): Audio.loop("alarm", "Alarm", {at = part})
function Audio.loop(id, name, opts)
	Audio.stop(id)
	opts = opts or {}
	opts.loop = true
	local s = Audio.play(name, opts)
	if s then loops[id] = s end
	return s
end

function Audio.stop(id, fade)
	local s = loops[id]
	loops[id] = nil
	if not s then return end
	if fade and fade > 0 then
		local tw = TweenService:Create(s, TweenInfo.new(fade), { Volume = 0 })
		tw:Play()
		tw.Completed:Connect(function() s:Destroy() end)
	else
		s:Destroy()
	end
end

function Audio.stopAll()
	for id in pairs(loops) do Audio.stop(id) end
end

-- пауза: петли замирают
function Audio.setPaused(p)
	for _, s in pairs(loops) do
		if p then s:Pause() else s:Resume() end
	end
	Audio.muffle(p)
end

-- отдельный звук по ID (двери и т.п.)
function Audio.oneShot(id, at, volume)
	local url = asset(id)
	if url == "" then return nil end
	local s = Instance.new("Sound")
	s.SoundId = url
	s.Volume = volume or 0.6
	s.SoundGroup = sfxGroup
	s.Parent = at or SoundService
	s:Play()
	task.delay(6, function() if s.Parent then s:Destroy() end end)
	return s
end

return Audio
