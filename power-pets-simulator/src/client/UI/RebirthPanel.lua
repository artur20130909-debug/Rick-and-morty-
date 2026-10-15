--[[
	RebirthPanel — перерождение: текущий и следующий множитель, прогресс до перерождения,
	что сбросится и что останется. Кнопку нужно нажать дважды (подтверждение).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Modules.Formulas)
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)

local UI = script.Parent
local Kit = require(UI.Kit)
local Icons = require(UI.Icons)
local Panels = require(UI.Panels)
local Notifications = require(UI.Notifications)
local State = require(UI.Parent.State)

local RebirthPanel = {}

-- Плашка «что сбросится / останется» с тремя иконками.
local function makeChip(parent, title, color, iconNames, order, position)
	local chip = Kit.new("Frame", {
		Size = UDim2.new(0.5, -8, 0, 104),
		Position = position,
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
		ZIndex = 6,
		Parent = parent,
	})
	Kit.Corner(chip, UDim.new(0, 18))
	Kit.Stroke(chip, 3)
	Kit.Gradient(chip, Kit.Lighten(color, 0.55), Kit.Lighten(color, 0.2))
	Kit.Text({ Text = title, Color = Kit.Darken(color, 0.4), Stroke = false, Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 4), MaxTextSize = 20, ZIndex = 7, Parent = chip })
	local row = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, 68),
		Position = UDim2.fromOffset(6, 30),
		ZIndex = 7,
		Parent = chip,
	})
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 4),
		Parent = row,
	})
	for index, iconName in ipairs(iconNames) do
		local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(68, 68), LayoutOrder = index, ZIndex = 7, Parent = row })
		Icons.Create(holder, iconName, { Size = UDim2.fromScale(1, 1), ZIndex = 8 })
	end
	return chip
end

function RebirthPanel.Create()
	local panel = Panels.Create("Rebirth", "ПЕРЕРОЖДЕНИЕ", Vector2.new(580, 500), Kit.Colors.Purple, "Rebirth")
	local content = panel.Content

	-- Множитель: x1 → x1.5
	local multiplierBox = Kit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 92),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.1,
		ZIndex = 6,
		Parent = content,
	})
	Kit.Corner(multiplierBox, UDim.new(0, 20))
	Icons.Create(multiplierBox, "Rebirth", {
		Size = UDim2.fromOffset(96, 96),
		Position = UDim2.new(0, -6, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 8,
		Animate = "Spin",
		Speed = 1.5,
		Color = Color3.fromRGB(200, 150, 255),
	})
	local currentLabel = Kit.Text({ Text = "", Size = UDim2.new(0.3, 0, 0, 54), Position = UDim2.new(0.2, 0, 0, 8), MaxTextSize = 46, StrokeThickness = 3, ZIndex = 7, Parent = multiplierBox })
	Icons.Glyph(multiplierBox, "Arrow", { Size = UDim2.fromOffset(46, 40), Position = UDim2.new(0.56, 0, 0, 36), ZIndex = 8, Color = Kit.Colors.Yellow })
	local nextLabel = Kit.Text({ Text = "", Color = Kit.Colors.Yellow, Size = UDim2.new(0.3, 0, 0, 54), Position = UDim2.new(0.64, 0, 0, 8), MaxTextSize = 46, StrokeThickness = 3, ZIndex = 7, Parent = multiplierBox })
	Kit.Text({
		Text = "постоянный бонус к силе за каждый клик",
		Color = Color3.fromRGB(210, 200, 240),
		Font = Kit.FontBold,
		Size = UDim2.new(0.8, 0, 0, 22),
		Position = UDim2.new(0.18, 0, 0, 62),
		MaxTextSize = 17,
		Stroke = false,
		ZIndex = 7,
		Parent = multiplierBox,
	})

	local requirementLabel = Kit.Text({
		Text = "",
		Color = Kit.Colors.Ink,
		Stroke = false,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 100),
		MaxTextSize = 22,
		ZIndex = 6,
		Parent = content,
	})
	local bar, setBar = Kit.ProgressBar({
		Size = UDim2.new(1, -60, 0, 34),
		Position = UDim2.fromOffset(46, 130),
		Color = Kit.Colors.Purple,
		ZIndex = 6,
		Parent = content,
	})
	Icons.Create(content, "Star", { Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset(0, 120), ZIndex = 9 })
	local progressLabel = Kit.Text({
		Text = "",
		Size = UDim2.new(1, -10, 1, 0),
		Position = UDim2.fromOffset(5, 0),
		MaxTextSize = 22,
		ZIndex = 10,
		Parent = bar,
	})

	makeChip(content, "Сбросится", Kit.Colors.Red, { "Dumbbell", "Star", "Coin" }, 1, UDim2.fromOffset(0, 176))
	makeChip(content, "Останется", Kit.Colors.Green, { "Paw", "Backpack", "Globe" }, 2, UDim2.new(0.5, 8, 0, 176))

	local armed = false
	local armedAt = 0
	local busy = false
	local refresh -- объявлена ниже

	local _, buttonLabel, buttonGradient = Kit.Button({
		Name = "RebirthButton",
		Size = UDim2.new(1, -40, 0, 70),
		Position = UDim2.new(0, 20, 1, -76),
		Color = Kit.Colors.Purple,
		Icon = "Rebirth",
		IconColor = Color3.fromRGB(255, 255, 255),
		MaxTextSize = 30,
		StrokeThickness = 4,
		Depth = 7,
		ZIndex = 6,
		Parent = content,
		OnClick = function()
			if busy then
				return
			end
			local total = State.Get("TotalStrength", 0)
			local cost = Formulas.RebirthCost(State.Get("Rebirths", 0))
			if total < cost then
				Notifications.Show("Нужно ещё " .. Format.Number(cost - total) .. " накопленной силы", "error")
				return
			end
			if not armed then
				armed = true
				armedAt = os.clock()
				refresh()
				task.delay(3, function()
					if armed and os.clock() - armedAt >= 2.9 then
						armed = false
						refresh()
					end
				end)
				return
			end
			armed = false
			busy = true
			task.spawn(function()
				local ok, message = State.Invoke(Remotes.Rebirth)
				busy = false
				if message then
					Notifications.Show(message, ok and "success" or "error")
				end
				if ok then
					Panels.Close()
				end
				refresh()
			end)
		end,
	})

	refresh = function()
		local rebirths = State.Get("Rebirths", 0)
		local total = State.Get("TotalStrength", 0)
		local cost = Formulas.RebirthCost(rebirths)
		currentLabel.Text = Format.Multiplier(Formulas.RebirthMultiplier(rebirths))
		nextLabel.Text = Format.Multiplier(Formulas.RebirthMultiplier(rebirths + 1))
		requirementLabel.Text = "Нужно " .. Format.Number(cost) .. " накопленной силы"
		local fraction = cost > 0 and total / cost or 1
		setBar(fraction, fraction >= 1 and Kit.Colors.Green or Kit.Colors.Purple)
		progressLabel.Text = Format.Number(math.min(total, cost)) .. " / " .. Format.Number(cost)

		if fraction < 1 then
			armed = false
			buttonLabel.Text = "Копи силу"
			Kit.SetButtonColor(buttonGradient, Kit.Colors.Grey)
		elseif armed then
			buttonLabel.Text = "Точно? Нажми ещё раз!"
			Kit.SetButtonColor(buttonGradient, Kit.Colors.Orange)
		else
			buttonLabel.Text = "ПЕРЕРОДИТЬСЯ"
			Kit.SetButtonColor(buttonGradient, Kit.Colors.Purple)
		end
	end

	State.Watch({ "Rebirths", "TotalStrength" }, refresh)
	panel.OnOpen = function()
		armed = false
		refresh()
	end
end

return RebirthPanel
