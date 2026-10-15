--[[
	Power Pets Simulator — главный клиентский скрипт.
	Собирает интерфейс кодом (никаких .rbxm), подключает клики, питомцев и эффекты.
	Клиент ничего не начисляет сам — только отправляет запросы серверу и показывает результат.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local Client = script.Parent
local UI = Client:WaitForChild("UI")
ReplicatedStorage:WaitForChild("Shared")

local Sounds = require(Client:WaitForChild("Sounds"))
local State = require(Client:WaitForChild("State"))
local Kit = require(UI:WaitForChild("Kit"))
local Panels = require(UI:WaitForChild("Panels"))
local Hud = require(UI:WaitForChild("Hud"))
local Notifications = require(UI:WaitForChild("Notifications"))
local Popups = require(UI:WaitForChild("Popups"))
local PetsPanel = require(UI:WaitForChild("PetsPanel"))
local ShopPanel = require(UI:WaitForChild("ShopPanel"))
local RebirthPanel = require(UI:WaitForChild("RebirthPanel"))
local WorldsPanel = require(UI:WaitForChild("WorldsPanel"))
local HatchAnimation = require(UI:WaitForChild("HatchAnimation"))
local ClickController = require(Client:WaitForChild("ClickController"))
local PetFollow = require(Client:WaitForChild("PetFollow"))
local WorldEffects = require(Client:WaitForChild("WorldEffects"))
local ServerEvents = require(Client:WaitForChild("ServerEvents"))

-- ScreenGui лежат в StarterGui (src/gui). Если их нет — создаём сами.
local function getScreenGui(name, displayOrder, ignoreInset)
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild(name, 10)
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = name
		gui.ResetOnSpawn = false
		gui.ScreenInsets = ignoreInset and Enum.ScreenInsets.None or Enum.ScreenInsets.CoreUISafeInsets
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.DisplayOrder = displayOrder
		gui.Parent = playerGui
	end
	return gui
end

-- Стандартная панель предметов Roblox не нужна: у нас нет инструментов.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

State.Init()

local mainGui = getScreenGui("PowerPetsGui", 5, false)
local hatchGui = getScreenGui("HatchGui", 20, true)

local root = Kit.CreateScaledRoot(mainGui, "Root")
Popups.Init(mainGui)
Panels.Init(root)
local hud = Hud.Create(root)
Notifications.Init(root)

PetsPanel.Create()
ShopPanel.Create()
RebirthPanel.Create()
WorldsPanel.Create()

HatchAnimation.Init(hatchGui)
ClickController.Init(hud)
PetFollow.Init()
WorldEffects.Init(root)
ServerEvents.Init()

-- Предупреждение, если прогресс не сохраняется (Studio без доступа к API).
local saveWarningShown = false
State.Watch("SaveDisabled", function()
	if State.Get("SaveDisabled", false) == true and not saveWarningShown then
		saveWarningShown = true
		Notifications.Show("⚠️ Сохранение выключено: включи Studio Access to API Services", "warning")
	end
end)

-- Подсказка новичку.
State.Watch("DataLoaded", function()
	if State.IsLoaded() and State.Get("TotalStrength", 0) == 0 and State.Get("Rebirths", 0) == 0 then
		task.delay(2.5, function()
			Notifications.Show("Жми 💪 КЛИК, продавай силу в 💰 круге и открывай 🥚 яйца!", "info")
		end)
	end
end)

Sounds.Play("Button", 0.8)
