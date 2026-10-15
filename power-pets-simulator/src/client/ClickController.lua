--[[
	ClickController — клики и тапы.
	Сила начисляется за: большую кнопку «КЛИК!», клик мышью по миру (ПК), тап по экрану (телефон).
	Клиент сам не даёт отправить больше ~14 кликов в секунду, а сервер всё равно проверяет лимит.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)

local Client = script.Parent
local State = require(Client.State)
local Sounds = require(Client.Sounds)
local UI = Client:WaitForChild("UI")
local Kit = require(UI.Kit)
local Popups = require(UI.Popups)
local Panels = require(UI.Panels)
local HatchAnimation = require(UI.HatchAnimation)

local ClickController = {}

local MIN_INTERVAL = 1 / math.max(1, GameConfig.MaxClicksPerSecond - 1)
local lastClick = 0
local lastFullWarning = 0
local hud = nil

function ClickController.Click(screenPosition)
	if not State.IsLoaded() or HatchAnimation.IsPlaying() then
		return
	end
	local now = os.clock()
	if now - lastClick < MIN_INTERVAL then
		return
	end
	lastClick = now

	local strength = State.Get("Strength", 0)
	local capacity = State.Get("Capacity", 50)
	if strength >= capacity then
		if now - lastFullWarning > 0.6 then
			lastFullWarning = now
			Popups.Show(screenPosition, "Рюкзак полон!", Kit.Colors.Red, 0.8)
			Sounds.Play("Error")
			if hud then
				hud.FlashFull()
			end
		end
		return
	end

	Remotes.Click:FireServer()
	Sounds.Play("Click", 0.92 + math.random() * 0.22)
	local power = math.min(State.Get("ClickPower", 1), capacity - strength)
	Popups.Show(screenPosition, "+" .. Format.Number(power), Kit.Colors.Yellow, 1)
	if hud then
		hud.Punch()
	end
end

function ClickController.Init(hudObject)
	hud = hudObject
	local button = hud.ClickButton

	button.Activated:Connect(function()
		local center = button.AbsolutePosition + button.AbsoluteSize / 2
		local spread = button.AbsoluteSize.X * 0.45
		local position = center + Vector2.new(math.random(-100, 100) / 100 * spread, -button.AbsoluteSize.Y * 0.62)
		ClickController.Click(position)
	end)

	-- ПК: клик мышью по миру (не по интерфейсу).
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or Panels.AnyOpen() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			ClickController.Click(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)

	-- Телефон: короткий тап по экрану (не по кнопкам и не по джойстику).
	UserInputService.TouchTap:Connect(function(positions, processed)
		if processed or Panels.AnyOpen() then
			return
		end
		local position = positions[1]
		if position then
			ClickController.Click(Vector2.new(position.X, position.Y))
		end
	end)
end

return ClickController
