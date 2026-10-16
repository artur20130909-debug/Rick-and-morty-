-- Проигрывание звуков. Для каждого звука пробует ID по очереди и запоминает первый,
-- который реально загрузился (если ID закрыт или удалён — берёт следующий).
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sounds = require(Shared.Sounds)

local SoundPlayer = {}

local resolved: { [string]: string } = {}
local resolving: { [string]: boolean } = {}
local sfxGroup: SoundGroup
local musicGroup: SoundGroup
local anchor: Part

local function group(name: string, volume: number): SoundGroup
	local g = SoundService:FindFirstChild(name) :: SoundGroup?
	if not g then
		local ng = Instance.new("SoundGroup")
		ng.Name = name
		ng.Volume = volume
		ng.Parent = SoundService
		g = ng
	end
	return g :: SoundGroup
end

local function tryLoad(id: string): boolean
	local s = Instance.new("Sound")
	s.SoundId = id
	local ok = false
	local done = false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ s }, function(_, status)
				ok = status == Enum.AssetFetchStatus.Success
			end)
		end)
		done = true
	end)
	local t = os.clock()
	while not done and os.clock() - t < 12 do
		task.wait(0.05)
	end
	if ok or s.IsLoaded then
		s:Destroy()
		return true
	end
	s:Destroy()
	return false
end

local function resolve(key: string)
	if resolved[key] or resolving[key] then
		return
	end
	local def = Sounds.Defs[key]
	if not def then
		return
	end
	resolving[key] = true
	-- пока проверяем — используем первый вариант
	resolved[key] = def.ids[1]
	for _, id in def.ids do
		if tryLoad(id) then
			resolved[key] = id
			resolving[key] = nil
			return
		end
	end
	resolved[key] = def.ids[#def.ids]
	resolving[key] = nil
end

function SoundPlayer.init()
	sfxGroup = group("SFX", 1)
	musicGroup = group("Music", 0.5)
	anchor = Instance.new("Part")
	anchor.Name = "SoundAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Parent = workspace
	-- проверяем все звуки в фоне (сначала короткие эффекты, потом музыку)
	local list = {}
	for key, def in Sounds.Defs do
		table.insert(list, { key, def.music and 1 or 0 })
	end
	table.sort(list, function(a, b)
		return a[2] < b[2]
	end)
	for _, e in list do
		task.spawn(resolve, e[1])
	end
end

function SoundPlayer.setVolumes(sfx: number, music: number)
	if sfxGroup then
		sfxGroup.Volume = sfx
	end
	if musicGroup then
		musicGroup.Volume = music
	end
end

function SoundPlayer.idOf(key: string): string?
	local def = Sounds.Defs[key]
	if not def then
		return nil
	end
	return resolved[key] or def.ids[1]
end

export type PlayOpts = {
	volume: number?,
	speed: number?,
	loop: boolean?,
	parent: Instance?,
	position: Vector3?,
	delay: number?,
	noAutoDestroy: boolean?,
}

-- Создать и запустить звук. Без parent/position — звук «в голове» (2D).
function SoundPlayer.play(key: string, opts: PlayOpts?): Sound?
	local def = Sounds.Defs[key]
	if not def then
		return nil
	end
	local o: PlayOpts = opts or {}
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundId = SoundPlayer.idOf(key) or ""
	s.Volume = (def.volume or 0.5) * (o.volume or 1)
	s.PlaybackSpeed = (def.speed or 1) * (o.speed or 1)
	s.Looped = o.loop or def.loop or false
	s.SoundGroup = def.music and musicGroup or sfxGroup
	if def.range then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = math.max(10, def.range * 0.08)
		s.RollOffMaxDistance = def.range
	end
	local parent: Instance = SoundService
	if o.parent then
		parent = o.parent
	elseif o.position then
		local att = Instance.new("Attachment")
		att.WorldPosition = o.position
		att.Parent = anchor
		parent = att
		s.Ended:Connect(function()
			att:Destroy()
		end)
		task.delay(30, function()
			if att.Parent and not s.Looped then
				att:Destroy()
			end
		end)
	end
	s.Parent = parent
	local function start()
		if s.Parent then
			s:Play()
		end
	end
	if o.delay and o.delay > 0 then
		task.delay(o.delay, start)
	else
		start()
	end
	if not s.Looped and not o.noAutoDestroy then
		s.Ended:Connect(function()
			s:Destroy()
		end)
	end
	return s
end

function SoundPlayer.fadeOut(s: Sound?, t: number?)
	if not s then
		return
	end
	local tw = TweenService:Create(s, TweenInfo.new(t or 0.6), { Volume = 0 })
	tw.Completed:Connect(function()
		s:Destroy()
	end)
	tw:Play()
end

-- Музыка: плейлист с плавной сменой треков
local currentMusic: Sound? = nil
local currentList: { string }? = nil
local musicToken = 0

function SoundPlayer.playlist(list: { string }?)
	if list == currentList then
		return
	end
	currentList = list
	musicToken += 1
	local token = musicToken
	SoundPlayer.fadeOut(currentMusic, 1.5)
	currentMusic = nil
	if not list then
		return
	end
	task.spawn(function()
		local i = math.random(1, #list)
		while token == musicToken do
			local key = list[i]
			local s = SoundPlayer.play(key, { noAutoDestroy = true })
			if not s then
				return
			end
			local target = s.Volume
			s.Volume = 0
			TweenService:Create(s, TweenInfo.new(2), { Volume = target }):Play()
			currentMusic = s
			local started = os.clock()
			while token == musicToken and s.Parent and (s.IsPlaying or os.clock() - started < 3) do
				task.wait(0.5)
			end
			if token ~= musicToken then
				return
			end
			if s.Parent then
				s:Destroy()
			end
			i = i % #list + 1
			task.wait(1)
		end
	end)
end

return SoundPlayer
