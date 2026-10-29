-- Клиент: связывает управление, анимации, эффекты, звук и интерфейс.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = ReplicatedStorage:WaitForChild("Client")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Characters = require(Shared.Characters)
local Theme = require(Client.Theme)
local Animator = require(Client.Animator)
local Effects = require(Client.Effects)
local Controller = require(Client.Controller)
local Hud = require(Client.Hud)
local Menu = require(Client.Menu)
local Touch = require(Client.Touch)

-- стандартные панели Roblox, которые не нужны в боёвке
for _, t in ipairs({ Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.EmotesMenu }) do
	pcall(function() StarterGui:SetCoreGuiEnabled(t, false) end)
end
pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)

---------------------------------------------------------------- интерфейс
local pg = player:WaitForChild("PlayerGui")
local function screen(name, order)
	local g = Instance.new("ScreenGui")
	g.Name = name
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = order
	g.Parent = pg
	return g
end
local hudGui = screen("CursedHUD", 5)
local menuGui = screen("CursedMenu", 10)
local overlayGui = screen("CursedOverlay", 20)

Hud.init(hudGui, overlayGui)
Touch.init(hudGui)
Menu.init(menuGui)

-- «ослепление»: тёмная пелена
local blind = Theme.frame({ Name = "Blind", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 2, 12), BackgroundTransparency = 1,
	ZIndex = 1, Parent = hudGui })

Hud.onMenu = function() Menu.open() end
local Action = Remotes:WaitForChild("Action")
Menu.onOpen = function(open)
	Controller.enabled = not open
	if open then Controller.releaseAll() end
	Hud.setVisible(not open)
	Touch.setVisible(not open)
	Action:FireServer("Menu", open)
end

Effects.ui = {
	flash = Hud.flash, announce = Hud.announce, killfeed = Hud.killfeed, damage = Hud.damage,
	cue = Hud.cue, botsConfig = Menu.botsConfig, notify = Hud.notify,
}
Controller.onDenied = Hud.denied
Controller.onMove = Hud.pressed

Animator.start()

---------------------------------------------------------------- сеть
local function myChar()
	local c = player.Character
	local id = c and c:GetAttribute("Char") or player:GetAttribute("CharId")
	if Characters.valid(id) then return id end
	return Characters.Default
end

local function resetCooldowns()
	for i = 1, 4 do
		Controller.cds[i] = 0
		Controller.cdLen[i] = 1
	end
	Controller.recast = nil
end

Remotes:WaitForChild("FX").OnClientEvent:Connect(function(name, data)
	Effects.handle(name, data)
end)

Remotes:WaitForChild("Private").OnClientEvent:Connect(function(kind, d)
	d = d or {}
	if kind == "CD" then
		if d.slot then
			Controller.cds[d.slot] = d.t or 0
			Controller.cdLen[d.slot] = d.d or 1
		end
	elseif kind == "Combo" then
		Hud.combo(d.n)
	elseif kind == "Moveset" then
		Controller.awakened = d.awakened and true or false
		resetCooldowns()
		Hud.setCharacter(myChar(), Controller.awakened)
	elseif kind == "Spawned" then
		Controller.awakened = false
		resetCooldowns()
		Hud.setCharacter(d.c or myChar(), false)
		Hud.respawned()
		if Menu.isOpen then Action:FireServer("Menu", true) end
	elseif kind == "Selected" then
		Menu.selected(d.c, d.ok)
		if d.ok then
			resetCooldowns()
			Hud.setCharacter(d.c, false)
		end
	elseif kind == "Notify" then
		Hud.notify(d.text or "", d.kind)
	elseif kind == "Recast" then
		Controller.recast = { slot = d.slot, from = d.from or 0, to = d.to or 0 }
	end
end)

---------------------------------------------------------------- свой персонаж
local function bindCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	Hud.respawned()
	-- рэгдолл: сервер включает шарниры, а состояние гуманоида переключает владелец (этот клиент)
	char:GetAttributeChangedSignal("Ragdoll"):Connect(function()
		if hum.Health <= 0 then return end
		if char:GetAttribute("Ragdoll") then
			hum:ChangeState(Enum.HumanoidStateType.Physics)
		else
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
	hum.Died:Connect(function()
		Hud.death(nil)
		Hud.combo(0)
	end)
end
player.CharacterAdded:Connect(bindCharacter)
if player.Character then task.spawn(bindCharacter, player.Character) end

-- состояние всех бойцов: невидимость, горение, аура пробуждения (10 раз в секунду)
local fires = {}
local invis = {}
local function setInvisible(model, value)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = value end
	end
end
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc = acc + dt
	if acc < 0.1 then return end
	acc = 0
	for model in pairs(Animator.recs) do
		if model.Parent then
			-- невидимость (свой персонаж — полупрозрачный)
			local inv = model:GetAttribute("Invisible") and true or false
			if inv ~= (invis[model] or false) then
				invis[model] = inv
				setInvisible(model, inv and (model == player.Character and 0.65 or 1) or 0)
			end
			-- горение
			local burning = model:GetAttribute("Burning") and true or false
			local fire = fires[model]
			if burning and not fire then
				local torso = model:FindFirstChild("Torso")
				if torso then
					fire = Instance.new("Fire")
					fire.Heat = 6
					fire.Size = 4
					fire.Color = Color3.fromRGB(255, 120, 30)
					fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
					fire.Parent = torso
					fires[model] = fire
				end
			elseif not burning and fire then
				fire:Destroy()
				fires[model] = nil
			end
			-- аура пробуждения (если зашли позже, чем персонаж пробудился)
			if model:GetAttribute("Awakened") then Effects.addAura(model) else Effects.removeAura(model) end
		else
			invis[model] = nil
			if fires[model] then fires[model]:Destroy() fires[model] = nil end
		end
	end
	local c = player.Character
	local b = c and c:GetAttribute("Blind")
	local target = b and 0.08 or 1
	if math.abs(blind.BackgroundTransparency - target) > 0.01 then
		blind.BackgroundTransparency = blind.BackgroundTransparency + (target - blind.BackgroundTransparency) * 0.5
	end
end)

RunService.RenderStepped:Connect(function(dt)
	Hud.update(dt)
	Touch.update(dt)
end)

-- при входе — экран выбора персонажа
Menu.open("chars")
