-- Звуки игры.
-- 1) Если в ReplicatedStorage есть папка SoundLibrary со звуком с таким же именем —
--    играет он (туда вставляются звуки из набора assets/sounds, см. README).
-- 2) Иначе — встроенный звук Roblox (rbxasset://), подобранный по смыслу.
-- volume — громкость, pitch = { от, до } — случайная высота, чтобы удары не звучали одинаково.
local Sounds = {}

local S = "rbxasset://sounds/"

Sounds.List = {
	Swing = { id = S .. "swordlunge.wav", volume = 0.35, pitch = { 1.35, 1.6 } },
	SwingHeavy = { id = S .. "swordlunge.wav", volume = 0.55, pitch = { 0.9, 1.05 } },
	Punch = { id = S .. "action_jump_land.mp3", volume = 0.9, pitch = { 1.25, 1.5 } },
	PunchHeavy = { id = S .. "collide.wav", volume = 0.55, pitch = { 1.5, 1.7 } },
	Slash = { id = S .. "swordslash.wav", volume = 0.6, pitch = { 0.95, 1.15 } },
	SlashHeavy = { id = S .. "swordslash.wav", volume = 0.8, pitch = { 0.75, 0.85 } },
	Block = { id = S .. "action_jump_land.mp3", volume = 0.7, pitch = { 0.7, 0.8 } },
	Parry = { id = S .. "electronicpingshort.wav", volume = 0.7, pitch = { 0.55, 0.6 } },
	GuardBreak = { id = S .. "collide.wav", volume = 0.7, pitch = { 1.1, 1.2 } },
	Dash = { id = S .. "swordlunge.wav", volume = 0.45, pitch = { 0.75, 0.85 } },
	Jump = { id = S .. "action_jump.mp3", volume = 0.4, pitch = { 1, 1.1 } },
	Land = { id = S .. "action_jump_land.mp3", volume = 0.5, pitch = { 0.9, 1 } },
	Explosion = { id = S .. "collide.wav", volume = 0.8, pitch = { 0.85, 1 } },
	ExplosionBig = { id = S .. "collide.wav", volume = 1, pitch = { 0.5, 0.6 } },
	Launch = { id = S .. "Rocket shot.wav", volume = 0.6, pitch = { 0.9, 1.1 } },
	Fire = { id = S .. "Launching rocket.wav", volume = 0.6, pitch = { 0.9, 1.05 } },
	Zap = { id = S .. "electronicpingshort.wav", volume = 0.5, pitch = { 1.6, 2 } },
	Thunder = { id = S .. "collide.wav", volume = 0.9, pitch = { 0.7, 0.8 } },
	Charge = { id = S .. "Launching rocket.wav", volume = 0.45, pitch = { 0.55, 0.6 } },
	Beam = { id = S .. "Launching rocket.wav", volume = 0.8, pitch = { 1.2, 1.3 } },
	Teleport = { id = S .. "swordlunge.wav", volume = 0.5, pitch = { 1.8, 2 } },
	Void = { id = S .. "collide.wav", volume = 0.6, pitch = { 0.6, 0.7 } },
	Shadow = { id = S .. "swordlunge.wav", volume = 0.45, pitch = { 0.5, 0.6 } },
	Bite = { id = S .. "action_jump_land.mp3", volume = 0.8, pitch = { 1.7, 1.9 } },
	Crow = { id = S .. "swordlunge.wav", volume = 0.4, pitch = { 2.2, 2.6 } },
	Awaken = { id = S .. "Launching rocket.wav", volume = 1, pitch = { 0.5, 0.55 } },
	Domain = { id = S .. "collide.wav", volume = 1, pitch = { 0.35, 0.4 } },
	Resonance = { id = S .. "collide.wav", volume = 1, pitch = { 1.9, 2.1 } },
	Death = { id = S .. "uuhhh.mp3", volume = 0.6, pitch = { 1, 1 } },
	Click = { id = S .. "clickfast.wav", volume = 0.5, pitch = { 1, 1.05 } },
	Select = { id = S .. "electronicpingshort.wav", volume = 0.45, pitch = { 1.2, 1.25 } },
	Ready = { id = S .. "electronicpingshort.wav", volume = 0.3, pitch = { 1.6, 1.7 } },
	Kill = { id = S .. "electronicpingshort.wav", volume = 0.6, pitch = { 0.9, 0.95 } },
	Rumble = { id = S .. "collide.wav", volume = 0.5, pitch = { 0.3, 0.35 } },
}

function Sounds.get(name)
	return Sounds.List[name]
end

return Sounds
