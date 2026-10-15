--[[
	ServerEvents — реакции на сообщения сервера: уведомления, эффекты (монеты, продажа,
	перерождение, золотой питомец…) и запуск анимации яйца.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)

local Client = script.Parent
local Sounds = require(Client.Sounds)
local UI = Client:WaitForChild("UI")
local Kit = require(UI.Kit)
local Popups = require(UI.Popups)
local Notifications = require(UI.Notifications)
local HatchAnimation = require(UI.HatchAnimation)
local PetsPanel = require(UI.PetsPanel)

local ServerEvents = {}

local EFFECTS = {}

function EFFECTS.Coin(payload)
	Sounds.Play("Coin", 0.9 + math.random() * 0.3)
	local text = "+" .. Format.Number(payload.Amount or 0)
	local camera = Workspace.CurrentCamera
	if camera and typeof(payload.Position) == "Vector3" then
		local screen, onScreen = camera:WorldToScreenPoint(payload.Position)
		if onScreen then
			Popups.Show(Vector2.new(screen.X, screen.Y), text, Kit.Colors.Yellow, 1.1, true)
			return
		end
	end
	Popups.Center(text, Kit.Colors.Yellow, 1.2, true)
end

function EFFECTS.Sell(payload)
	Sounds.Play("Sell")
	task.delay(0.12, Sounds.Play, "Coin", 1.2)
	Popups.Center("+" .. Format.Number(payload.Amount or 0), Kit.Colors.Yellow, 2, true)
end

function EFFECTS.Unlock(payload)
	local world = Worlds[payload.World]
	Sounds.Play("Unlock")
	if world then
		Notifications.Show("Открыт новый мир: " .. world.Name .. "!", "success")
	end
end

function EFFECTS.Teleport()
	Sounds.Play("Teleport")
end

function EFFECTS.Rebirth(payload)
	Sounds.Play("Rebirth")
	Popups.Center("ПЕРЕРОЖДЕНИЕ #" .. tostring(payload.Rebirths or ""), Kit.Colors.Purple, 2.2)
end

function EFFECTS.Merge(payload)
	Sounds.Play("Merge")
	Popups.Center("ЗОЛОТОЙ ПИТОМЕЦ!", Kit.Colors.Gold, 1.9)
	if payload.Uid then
		PetsPanel.Select(payload.Uid)
	end
end

function EFFECTS.Purchase()
	Sounds.Play("Purchase")
end

function ServerEvents.Init()
	Remotes.Notify.OnClientEvent:Connect(function(text, kind)
		if type(text) == "string" then
			Notifications.Show(text, kind)
		end
	end)

	Remotes.Effect.OnClientEvent:Connect(function(kind, payload)
		local handler = EFFECTS[kind]
		if handler then
			handler(type(payload) == "table" and payload or {})
		end
	end)

	Remotes.EggHatched.OnClientEvent:Connect(function(eggId, results)
		HatchAnimation.Play(eggId, results)
	end)
end

return ServerEvents
