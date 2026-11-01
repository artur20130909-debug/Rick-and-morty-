-- Настройки игрока: громкость, мышь, поле зрения, эффекты, субтитры, подсказки.
-- Хранятся в памяти на время игры; изменение сразу применяется (событие Changed).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Settings = {}
Settings.values = {}

local changed = Instance.new("BindableEvent")
Settings.Changed = changed.Event

local Config

function Settings.init(ctx)
	Config = ctx.Config
	for k, v in pairs(Config.DefaultSettings) do Settings.values[k] = v end
	-- если игрок уже менял настройки в этой сессии — берём их из атрибутов
	local plr = Players.LocalPlayer
	for k in pairs(Config.DefaultSettings) do
		local v = plr:GetAttribute("Set_" .. k)
		if v ~= nil then Settings.values[k] = v end
	end
	Settings.apply()
end

function Settings.get(k) return Settings.values[k] end

function Settings.set(k, v)
	if Settings.values[k] == v then return end
	Settings.values[k] = v
	Players.LocalPlayer:SetAttribute("Set_" .. k, v)
	Settings.apply()
	changed:Fire(k, v)
end

function Settings.reset()
	for k, v in pairs(Config.DefaultSettings) do
		Settings.values[k] = v
		Players.LocalPlayer:SetAttribute("Set_" .. k, v)
		changed:Fire(k, v)
	end
	Settings.apply()
end

-- то, что применяется напрямую (остальное слушают модули через Changed)
function Settings.apply()
	pcall(function() UserInputService.MouseDeltaSensitivity = Settings.values.Sensitivity end)
	local cam = workspace.CurrentCamera
	if cam and cam.CameraType ~= Enum.CameraType.Scriptable then cam.FieldOfView = Settings.values.Fov end
end

return Settings
