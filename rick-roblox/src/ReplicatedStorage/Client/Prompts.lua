-- Свой вид подсказок ProximityPrompt (стиль Custom): тёмная «таблетка» с клавишей и действием.
-- На телефоне подсказку можно нажать пальцем. Пока идёт сценка, подсказки скрыты (Prompts.enabled).
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local Prompts = {}
local G, Config, Hud
local shown = {} -- prompt -> BillboardGui
Prompts.enabled = true

local function keyText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then return "ТАП" end
	if inputType == Enum.ProximityPromptInputType.Gamepad then return prompt.GamepadKeyCode.Name:gsub("Button", "") end
	return prompt.KeyboardKeyCode.Name
end

local function build(prompt, inputType)
	local bb = Instance.new("BillboardGui")
	bb.Name = "RM_Prompt"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(300, 64)
	bb.SizeOffset = Vector2.new(0, 0.6)
	bb.LightInfluence = 0
	bb.MaxDistance = 40
	bb.ResetOnSpawn = false
	bb.Adornee = prompt.Parent
	bb.Active = true
	local btn = Instance.new("TextButton")
	btn.Name = "Pill"
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = UDim2.fromScale(0.5, 0.5)
	btn.Size = UDim2.fromOffset(10, 46)
	btn.AutomaticSize = Enum.AutomaticSize.X
	btn.BackgroundColor3 = Color3.fromRGB(10, 26, 14)
	btn.BackgroundTransparency = 0.12
	btn.Parent = bb
	G.corner(btn, UDim.new(0.5, 0))
	G.stroke(btn, Config.Colors.UiLime, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	G.pad(btn, 7, 0, 18, 0)
	G.list(btn, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local cap = G.frame(btn, { Name = "Key", Size = UDim2.fromOffset(34, 32), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Config.Colors.UiLime, LayoutOrder = 1 })
	G.corner(cap, 8)
	G.pad(cap, 8, 0, 8, 0)
	G.label(cap, keyText(prompt, inputType), { Size = UDim2.fromOffset(18, 32), AutomaticSize = Enum.AutomaticSize.X, FontFace = G.Fonts.Title,
		TextSize = 20, TextColor3 = Config.Colors.UiDark })
	local txt = prompt.ActionText
	if prompt.ObjectText ~= "" then txt = txt .. " · " .. prompt.ObjectText end
	local label = G.label(btn, txt, { Name = "Text", Size = UDim2.fromOffset(10, 46), AutomaticSize = Enum.AutomaticSize.X,
		FontFace = G.Fonts.Bold, TextSize = 21, LayoutOrder = 2 })
	-- полоска удержания
	local bar = G.frame(btn, { Name = "Hold", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 2), Size = UDim2.new(0, 0, 0, 3),
		BackgroundColor3 = Config.Colors.UiLime, ZIndex = 3 })
	bar.Visible = prompt.HoldDuration > 0
	local sc = Instance.new("UIScale")
	sc.Scale = 0.5
	sc.Parent = btn
	G.tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	-- нажатие пальцем / мышью
	btn.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
		end
	end)
	btn.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
		end
	end)
	local conns = {}
	table.insert(conns, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		label.Text = prompt.ActionText .. (prompt.ObjectText ~= "" and (" · " .. prompt.ObjectText) or "")
	end))
	table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function()
		bar.Size = UDim2.new(0, 0, 0, 3)
		G.tween(bar, prompt.HoldDuration, { Size = UDim2.new(1, 0, 0, 3) }, Enum.EasingStyle.Linear)
	end))
	table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function()
		G.tween(bar, 0.15, { Size = UDim2.new(0, 0, 0, 3) })
	end))
	table.insert(conns, prompt.Triggered:Connect(function()
		G.tween(sc, 0.08, { Scale = 0.9 })
		task.delay(0.09, function() G.tween(sc, 0.15, { Scale = 1 }, Enum.EasingStyle.Back) end)
	end))
	bb.Destroying:Connect(function() for _, c in ipairs(conns) do c:Disconnect() end end)
	bb.Parent = G.playerGui()
	return bb
end

function Prompts.init(ctx)
	G, Config, Hud = ctx.Gui, ctx.Config, ctx.Hud
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
		if shown[prompt] then shown[prompt]:Destroy() end
		local bb = build(prompt, inputType)
		bb.Enabled = Prompts.enabled
		shown[prompt] = bb
		Hud.crossFocus(true)
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		local bb = shown[prompt]
		shown[prompt] = nil
		if bb then bb:Destroy() end
		if next(shown) == nil then Hud.crossFocus(false) end
	end)
end

-- скрыть/показать все подсказки (во время сценок); ProximityPromptService.Enabled — только у этого игрока
function Prompts.setEnabled(on)
	Prompts.enabled = on
	ProximityPromptService.Enabled = on
	for _, bb in pairs(shown) do bb.Enabled = on end
end

local _u = UserInputService
return Prompts
