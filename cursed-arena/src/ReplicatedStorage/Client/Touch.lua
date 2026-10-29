-- Кнопки для телефона и планшета: УДАР (зажать — серия), БЛОК (держать), РЫВОК.
-- Приёмы — нажатием на ячейки панели, пробуждение — на шкалу (это делает Hud).
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Client = ReplicatedStorage:WaitForChild("Client")
local Theme = require(Client.Theme)
local Controller = require(Client.Controller)
local Hud = require(Client.Hud)

local Touch = {}
local ui = {}
Touch.ui = ui

local function roundButton(parent, name, text, size, pos, color)
	local b = Theme.button({ Name = name, Text = text, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color, BackgroundTransparency = 0.35, TextSize = math.floor(size * 0.2), FontFace = Theme.BlackItalic,
		AutoButtonColor = false, Parent = parent })
	Theme.corner(b, size)
	Theme.stroke(b, Color3.new(1, 1, 1), 2, 0.55)
	Theme.textStroke(b, 1.5)
	return b
end

local function hold(btn, onDown, onUp)
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			btn.BackgroundTransparency = 0.1
			onDown()
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			btn.BackgroundTransparency = 0.35
			if onUp then onUp() end
		end
	end)
end

function Touch.init(gui)
	ui.enabled = UserInputService.TouchEnabled
	if not ui.enabled then return end
	local root = Hud.makeRoot(gui, "Touch")
	ui.root = root
	-- справа снизу, вокруг стандартной кнопки прыжка
	local m1 = roundButton(root, "M1", "УДАР", 118, UDim2.new(1, -250, 1, -150), Color3.fromRGB(200, 50, 50))
	hold(m1, function() Controller.setM1Held(true) end, function() Controller.setM1Held(false) end)
	local block = roundButton(root, "Block", "БЛОК", 84, UDim2.new(1, -120, 1, -290), Color3.fromRGB(60, 110, 220))
	hold(block, function() Controller.setBlock(true) end, function() Controller.setBlock(false) end)
	local dash = roundButton(root, "Dash", "РЫВОК", 84, UDim2.new(1, -250, 1, -290), Color3.fromRGB(80, 80, 100))
	hold(dash, function() Controller.dash() end)
	ui.m1, ui.block, ui.dash = m1, block, dash
	-- на телефоне панель приёмов чуть выше, чтобы не мешать джойстику
	local bottom = Hud.ui.bottom
	if bottom then bottom.Position = UDim2.new(0.5, -40, 1, -14) end
end

function Touch.update()
	if not ui.enabled or not ui.root then return end
	local c = Controller.state
	ui.block.BackgroundTransparency = c.blocking and 0.05 or 0.35
end

function Touch.setVisible(on)
	if ui.root then ui.root.Visible = on end
end

return Touch
