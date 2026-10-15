--[[
	CustomPrompts — свой красивый вид кнопок ProximityPrompt (яйца, магазин).
	Сервер ставит подсказке Style = Custom и атрибуты:
		Price (число)  — цена в монетах (покажется с монеткой)
		Icon (строка)  — имя 3D-иконки из IconModels
		Color (Color3) — цвет карточки
		OpensPanel (строка) — открыть окно интерфейса (например, "Shop" у лавки магазина)
	На телефоне карточку можно просто нажать, на ПК — клавиша (E / R), на геймпаде — кнопка.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Modules.Format)

local UI = script.Parent
local Kit = require(UI.Kit)
local Icons = require(UI.Icons)
local Panels = require(UI.Panels)

local CustomPrompts = {}

local shown = {} -- [prompt] = BillboardGui

local function keyText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "ТАП"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return (string.gsub(prompt.GamepadKeyCode.Name, "Button", ""))
	end
	return prompt.KeyboardKeyCode.Name
end

local function hide(prompt)
	local gui = shown[prompt]
	if not gui then
		return
	end
	shown[prompt] = nil
	local scale = gui:FindFirstChild("Card") and gui.Card:FindFirstChildOfClass("UIScale")
	if scale then
		local tween = Kit.Tween(scale, 0.12, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween.Completed:Once(function()
			gui:Destroy()
		end)
	else
		gui:Destroy()
	end
end

local function show(prompt, inputType, playerGui)
	hide(prompt)
	local color = prompt:GetAttribute("Color") or Kit.Colors.Green
	local price = prompt:GetAttribute("Price")
	local iconName = prompt:GetAttribute("Icon")

	local gui = Kit.new("BillboardGui", {
		Name = "Prompt_" .. prompt.Name,
		Adornee = prompt.Parent,
		AlwaysOnTop = true,
		Active = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	-- Карточка 250×100 «дизайн-пикселей» масштабируется под экран (UIScale от центра),
	-- а сам BillboardGui берём с запасом, чтобы карточка и её «прыжок» при нажатии не обрезались.
	local targetScale = math.clamp(Kit.Scale * 1.05, 0.65, 1.2)
	gui.Size = UDim2.fromOffset(math.ceil(250 * targetScale * 1.2) + 8, math.ceil(100 * targetScale * 1.2) + 8)
	local card = Kit.new("TextButton", {
		Name = "Card",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(250, 100),
		Parent = gui,
	})
	Kit.Corner(card, UDim.new(0, 22))
	Kit.Stroke(card, 4)
	Kit.Gradient(card, Kit.Lighten(color, 0.3), Kit.Darken(color, 0.2))
	local scale = Kit.new("UIScale", { Scale = 0, Parent = card })
	Kit.Tween(scale, 0.25, { Scale = targetScale }, Enum.EasingStyle.Back)

	-- Кружок с клавишей.
	local key = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(58, 58),
		BackgroundColor3 = Kit.Colors.Ink,
		Parent = card,
	})
	Kit.Corner(key, UDim.new(0.5, 0))
	Kit.Stroke(key, 3, Color3.new(1, 1, 1))
	Kit.Text({ Text = keyText(prompt, inputType), Size = UDim2.fromScale(0.8, 0.6), Position = UDim2.fromScale(0.1, 0.2), MaxTextSize = 28, Parent = key })

	local textX = 76
	if iconName then
		Icons.Create(card, iconName, { Size = UDim2.fromOffset(64, 64), Position = UDim2.new(1, -66, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
	end
	Kit.Text({
		Text = prompt.ActionText,
		Size = UDim2.new(1, -textX - 70, 0, 40),
		Position = UDim2.fromOffset(textX, 10),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 32,
		StrokeThickness = 3,
		Parent = card,
	})
	if price then
		Icons.Coin2D(card, { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(textX, 56), ZIndex = 2 })
		Kit.Text({
			Text = Format.Number(price),
			Color = Kit.Colors.Yellow,
			Size = UDim2.new(1, -textX - 110, 0, 30),
			Position = UDim2.fromOffset(textX + 34, 55),
			XAlign = Enum.TextXAlignment.Left,
			MaxTextSize = 26,
			StrokeThickness = 3,
			Parent = card,
		})
	else
		Kit.Text({
			Text = prompt.ObjectText,
			Size = UDim2.new(1, -textX - 70, 0, 28),
			Position = UDim2.fromOffset(textX, 56),
			XAlign = Enum.TextXAlignment.Left,
			MaxTextSize = 22,
			Parent = card,
		})
	end

	-- Нажатие по карточке (телефон и мышь).
	card.Activated:Connect(function()
		scale.Scale = targetScale * 1.15
		Kit.Tween(scale, 0.25, { Scale = targetScale }, Enum.EasingStyle.Back)
		prompt:InputHoldBegin()
		task.wait()
		prompt:InputHoldEnd()
	end)

	shown[prompt] = gui
end

function CustomPrompts.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			show(prompt, inputType, playerGui)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		hide(prompt)
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		-- Лавка магазина в мире открывает окно магазина.
		local panelName = prompt:GetAttribute("OpensPanel")
		if type(panelName) == "string" then
			Panels.Open(panelName)
		end
		local gui = shown[prompt]
		local scale = gui and gui:FindFirstChild("Card") and gui.Card:FindFirstChildOfClass("UIScale")
		if scale then
			local target = math.clamp(Kit.Scale * 1.05, 0.65, 1.2)
			scale.Scale = target * 1.15
			Kit.Tween(scale, 0.25, { Scale = target }, Enum.EasingStyle.Back)
		end
	end)
end

return CustomPrompts
