-- BUILD & SURVIVE — клиент. Запускает интерфейс, строительство, эффекты и звук.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Serializer = require(Shared.Serializer)

local Client = ReplicatedStorage:WaitForChild("Client")
local State = require(Client.State)
local SoundPlayer = require(Client.SoundPlayer)
local CameraShake = require(Client.CameraShake)
local Fx = require(Client.Fx)
local World = require(Client.World)
local BuildController = require(Client.BuildController)
local Projectiles = require(Client.Projectiles)
local UI = Client:WaitForChild("UI")
local HUD = require(UI.HUD)
local BuildPanel = require(UI.BuildPanel)
local ShopUI = require(UI.ShopUI)
local SiegeUI = require(UI.SiegeUI)
local SavesUI = require(UI.SavesUI)
local SettingsUI = require(UI.SettingsUI)

local player = Players.LocalPlayer
local _ = Serializer

SoundPlayer.init()
CameraShake.init()
Fx.init()
HUD.init()
BuildPanel.init()
ShopUI.init()
SiegeUI.init()
SavesUI.init()
SettingsUI.init()
BuildController.init()
Projectiles.init()

-- Данные профиля с сервера
local firstData = true
Net.event("Data").OnClientEvent:Connect(function(d)
	local oldGold = State.gold
	State.unlocked = d.unlocked or {}
	State.bestWave = d.bestWave or 0
	State.slots = d.slots or {}
	State.stats = d.stats or {}
	State.saveEnabled = d.saveEnabled == true
	State.set("gold", d.gold or 0)
	State.changed:Fire("unlocked", State.unlocked)
	State.changed:Fire("slots", State.slots)
	State.changed:Fire("saveEnabled", State.saveEnabled)
	if firstData and d.settings then
		for k, v in d.settings do
			State.settings[k] = v
		end
		State.changed:Fire("settings", State.settings)
	end
	HUD.setGold(State.gold, not firstData and State.gold > oldGold)
	firstData = false
end)

Net.event("Notify").OnClientEvent:Connect(function(text, kind)
	HUD.toast(text, kind)
end)

Net.event("LaunchState").OnClientEvent:Connect(function(d)
	State.set("launched", d.active == true)
	HUD.setLaunchBar(d.active == true)
	HUD.setHotbarVisible(not d.active and not State.inSiege())
	if d.active then
		HUD.toast(string.format("Испытание! Колёс: %d, двигателей: %d", d.wheels or 0, d.thrusters or 0), "info")
	end
end)

SettingsUI.onChanged:Connect(function()
	State.changed:Fire("settings", State.settings)
end)

-- Кнопки меню справа
HUD.onMenu:Connect(function(key)
	if key == "shop" or key == "siege" or key == "saves" or key == "settings" then
		if key == "siege" and State.inSiege() then
			HUD.toast("Осада уже идёт", "warning")
			return
		end
		HUD.openModal(key)
	elseif key == "launch" then
		task.spawn(function()
			local ok, msg = Net.func("Launch"):InvokeServer()
			if not ok and msg then
				HUD.toast(msg, "error")
			end
		end)
	elseif key == "launchStop" then
		task.spawn(function()
			Net.func("StopLaunch"):InvokeServer()
		end)
	end
end)

-- Магазин в лобби (кнопка E у прилавка)
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ShopPrompt" then
		HUD.openModal("shop")
	end
end)

-- Счётчик блоков на своём участке
local function watchBlocks()
	local idx = player:GetAttribute("Plot")
	if not idx then
		return
	end
	local plot = workspace:WaitForChild("Plots"):WaitForChild("Plot" .. idx)
	local blocks = plot:WaitForChild("Blocks")
	local function update()
		HUD.setBlocks(#blocks:GetChildren())
	end
	blocks.ChildAdded:Connect(update)
	blocks.ChildRemoved:Connect(update)
	update()
end
player:GetAttributeChangedSignal("Plot"):Connect(watchBlocks)
task.spawn(watchBlocks)

World.init()
Net.func("GetData"):InvokeServer()
HUD.setHint("Нажми 1 или «Строить», чтобы начать. Справа — магазин, осада и сохранения.")
task.delay(12, function()
	if not State.tool then
		HUD.setHint("")
	end
end)
