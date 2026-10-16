-- Звуки игры. Для каждого звука — несколько ID по порядку предпочтения.
-- Игра сама проверяет, какой ID загрузился, и берёт первый рабочий.
-- Последним идёт встроенный звук Roblox (rbxasset://), он есть всегда.
--
-- Почти все ID — из официальной библиотеки Pro Sound Effects в Creator Store
-- (звуки с пометкой «(SFX)» от @ProSoundEffects) и музыка APM (@APMOfficial):
-- их может использовать любой разработчик.
-- Чтобы поменять звук: Creator Store → Audio → правый клик → Copy Asset ID → вставь первым в список.
local Sounds = {}

local EXPLOSION = "rbxasset://sounds/impact_explosion_03.mp3"
local THUD = "rbxasset://sounds/action_jump_land.mp3"
local SLIDER = "rbxasset://sounds/volume_slider.ogg"

local function id(n: number): string
	return "rbxassetid://" .. tostring(n)
end

-- volume: громкость, speed: скорость/высота, range: слышимость в 3D (стады), loop: повтор
Sounds.Defs = {
	-- Интерфейс и строительство
	Click = { ids = { id(9126109935), SLIDER }, volume = 0.45 },          -- Tonal Click Blurp (SFX)
	Hover = { ids = { SLIDER }, volume = 0.12, speed = 1.6 },
	Place = { ids = { id(9113263649), THUD }, volume = 0.32, speed = 1.7 }, -- Balloon Pop 3 (SFX), тонко и коротко
	Remove = { ids = { id(9119049084), THUD }, volume = 0.35, speed = 1.3 }, -- Shale Break 2 (SFX)
	Paint = { ids = { id(9126109935), SLIDER }, volume = 0.3, speed = 0.8 },
	Error = { ids = { id(9113085438), SLIDER }, volume = 0.2, speed = 1.2 },  -- Alarm Buzzer 3 (SFX)
	Coin = { ids = { id(1169755927), id(81816893340749), SLIDER }, volume = 0.5 }, -- Coin Collect, cash money sound
	Purchase = { ids = { id(81816893340749), id(1169755927), SLIDER }, volume = 0.6 },
	WaveStart = { ids = { id(9113083860), SLIDER }, volume = 0.5 },     -- Alarm Beeps 1 (SFX)
	WaveClear = { ids = { id(1169755927), SLIDER }, volume = 0.6, speed = 0.9 },
	Defeat = { ids = { id(9117870273), THUD }, volume = 0.6 },          -- Power Down 11 (SFX)

	-- Выстрелы
	Gunshot = { ids = { id(9113181642), id(9114692325), id(356911785), EXPLOSION }, volume = 0.7, range = 260 }, -- Assault Rifle 21 / Beretta 102
	Shotgun = { ids = { id(9113052249), id(5656322299), EXPLOSION }, volume = 0.8, range = 260 },             -- Air Bolt Gun 12 (SFX)
	Minigun = { ids = { id(9116338227), id(9113190595), EXPLOSION }, volume = 0.75, range = 300 },            -- Machine Gun 4 / Assault Rifle 3
	BulletWhiz = { ids = { id(9113634444), SLIDER }, volume = 0.5, range = 40 },                              -- Bullet Whiz 2 (SFX)
	BulletHit = { ids = { id(9118628948), THUD }, volume = 0.35, range = 120, speed = 1.4 },                  -- Rock Impacts 13 (SFX)
	Thump = { ids = { id(9113052249), THUD }, volume = 0.6, speed = 0.6, range = 260 },
	MortarLaunch = { ids = { id(9117895914), EXPLOSION }, volume = 0.5, speed = 0.7, range = 900 },          -- Pressure Blast 2 (SFX)
	RocketLaunch = { ids = { id(12222132), id(9114444008), EXPLOSION }, volume = 0.9, range = 900 },          -- Shoulder fired rocket.wav (@Roblox) / Fire Whoosh 3
	RocketLoop = { ids = { id(9125742111), id(9114444008) }, volume = 0.55, range = 220, loop = true },       -- Plasma Trails Constant Airy Whooshing (SFX)
	Jet = { ids = { id(9120054806), id(9114340342), id(9125742111) }, volume = 0.9, range = 1400 },          -- Time Travel Approach Fly By 3 (SFX)
	Incoming = { ids = { id(9114340342), id(9120054806) }, volume = 1, range = 2000 },                       -- Energy Pass By Sci Fi Whooshes (SFX)
	ShellWhistle = { ids = { id(9120054806), id(9113634444) }, volume = 0.6, speed = 1.4, range = 320 },

	-- Взрывы
	ExplosionSmall = { ids = { id(9117895914), id(9119701508), EXPLOSION }, volume = 0.9, range = 500 },       -- Pressure Blast 2 (SFX)
	ExplosionMedium = { ids = { id(9120705982), id(165969964), EXPLOSION }, volume = 1, range = 900 },          -- Whoosh Explosion 1 (SFX)
	ExplosionLarge = { ids = { id(9114363548), id(9119701508), EXPLOSION }, volume = 1, range = 1600 },         -- Explosion Soft Crack 11 (SFX)
	ExplosionHuge = { ids = { id(9114363548), id(165969964), EXPLOSION }, volume = 1, speed = 0.75, range = 2500 },
	NukeBlast = { ids = { id(9114363548), id(165969964), EXPLOSION }, volume = 1, speed = 0.5, range = 6000 },
	NukeRumble = { ids = { id(9114224217), id(9125392715), EXPLOSION }, volume = 1, speed = 0.8, range = 6000 }, -- Earthquake Explosion 3 (SFX)
	Debris = { ids = { id(9125392715), id(9118628948), THUD }, volume = 0.55, range = 260 },                   -- Big Rocks Drop Some Debris (SFX)
	MetalCrash = { ids = { id(9116546593), THUD }, volume = 0.6, range = 260 },                              -- Metal Crash 4 (SFX)
	WoodBreak = { ids = { id(9120827361), id(158712406), THUD }, volume = 0.5, range = 220 },                -- Wood Crack Splintering 1 (SFX)
	Splash = { ids = { id(9119481909), "rbxasset://sounds/impact_water.mp3" }, volume = 0.8, range = 500 },     -- Splash Thunking Impact 1 (SFX)

	-- Тревоги
	Siren = { ids = { id(9113073742), id(9067330158), id(9119755726) }, volume = 0.9 },     -- Air Raid Siren Old Fashioned 1 (SFX)
	Alarm = { ids = { id(9119755726), id(9113083860), SLIDER }, volume = 0.5 },             -- Synth Alarms Composite 2 (SFX)
	Warning = { ids = { id(9113083860), SLIDER }, volume = 0.45 },

	-- Лазер, щит, ПВО
	LaserCharge = { ids = { id(9125973257), id(9116231442), SLIDER }, volume = 0.9, range = 2000 },  -- Spaceship Blast Energy Charge Up (SFX)
	LaserLoop = { ids = { id(9116386540), id(9125742111) }, volume = 1, range = 900, loop = true },   -- Magic Force Field Constant 2 (SFX)
	LaserFire = { ids = { id(9116231442), id(9126069842), EXPLOSION }, volume = 1, range = 2000 },    -- Laser Cannon 207 (SFX)
	LaserEnd = { ids = { id(9117870273) }, volume = 0.7, range = 900 },
	Thunder = { ids = { id(9126069842), EXPLOSION }, volume = 0.8, range = 3000 },                   -- Synth Lightning Crack (SFX)
	ShieldHit = { ids = { id(9116273112), id(9114247505), SLIDER }, volume = 0.7, range = 300 },     -- Lightning Flashes Quick Electrical Bursts 19 (SFX)
	ShieldDown = { ids = { id(9117870273), SLIDER }, volume = 0.8, range = 300 },
	AAShot = { ids = { id(9113181642), id(9116338227), EXPLOSION }, volume = 0.6, speed = 1.15, range = 300 },

	-- Испытания
	Thruster = { ids = { id(9125742111), id(9114444008) }, volume = 0.5, range = 160, loop = true },

	-- Фон и музыка (APM Music — лицензия Roblox для всех)
	Wind = { ids = { id(9116258071), id(9125515917) }, volume = 0.18, loop = true },             -- Leaves Rustle Wind Blowing Through Trees 1 (SFX)
	MusicBuild1 = { ids = { id(1843404009), id(9044014229) }, volume = 0.35, music = true },      -- Happy Song (APM)
	MusicBuild2 = { ids = { id(9042666762), id(1845348751) }, volume = 0.35, music = true },      -- Chillin at Home (APM)
	MusicBuild3 = { ids = { id(9044014229), id(1843404009) }, volume = 0.3, music = true },       -- Stay Upbeat B (APM)
	MusicSiege1 = { ids = { id(9038254566), id(1845805363) }, volume = 0.38, music = true },      -- Metal Storm Breaks (APM)
	MusicSiege2 = { ids = { id(1839912010), id(1843083729) }, volume = 0.4, music = true },       -- Running Chase b (APM)
	MusicSiege3 = { ids = { id(1845805363), id(9043754347) }, volume = 0.35, music = true },      -- Fire Fight A (APM)
	MusicVictory = { ids = { id(1846248593), id(1843404009) }, volume = 0.45, music = true },     -- праздничный трек из уроков Roblox
}

Sounds.BuildPlaylist = { "MusicBuild1", "MusicBuild2", "MusicBuild3" }
Sounds.SiegePlaylist = { "MusicSiege1", "MusicSiege2", "MusicSiege3" }

-- Скорость звука для «задержки» далёких взрывов (стадов в секунду)
Sounds.SpeedOfSound = 1225

return Sounds
