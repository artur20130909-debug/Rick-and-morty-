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
local Panels = require(UI.Panels)
local Notifications = require(UI.Notifications)
local State = require(UI.Parent.State)

local RebirthPanel = {}

function RebirthPanel.Create()
	local panel = Panels.Create("Rebirth", "🔁 ПЕРЕРОЖДЕНИЕ", Vector2.new(540, 440), Kit.Colors.Purple)
	local content = panel.Content

	local multiplierLabel = Kit.Text({
		Text = "",
		Size = UDim2.new(1, 0, 0, 56),
		MaxTextSize = 50,
		StrokeThickness = 3,
		Color = Kit.Colors.Yellow,
		ZIndex = 4,
		Parent = content,
	})
	Kit.Text({
		Text = "постоянный бонус к силе за каждый клик",
		Color = Kit.Colors.GreyDark,
		Stroke = false,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 56),
		MaxTextSize = 19,
		ZIndex = 4,
		Parent = content,
	})

	local requirementLabel = Kit.Text({
		Text = "",
		Color = Kit.Colors.Ink,
		Stroke = false,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 90),
		MaxTextSize = 22,
		ZIndex = 4,
		Parent = content,
	})
	local bar, setBar = Kit.ProgressBar({
		Size = UDim2.new(1, -20, 0, 32),
		Position = UDim2.fromOffset(10, 122),
		Color = Kit.Colors.Purple,
		ZIndex = 4,
		Parent = content,
	})
	local progressLabel = Kit.Text({
		Text = "",
		Size = UDim2.new(1, -10, 1, 0),
		Position = UDim2.fromOffset(5, 0),
		MaxTextSize = 22,
		ZIndex = 7,
		Parent = bar,
	})

	local infoBox = Kit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 92),
		Position = UDim2.fromOffset(0, 166),
		BackgroundColor3 = Kit.Colors.PanelDark,
		ZIndex = 4,
		Parent = content,
	})
	Kit.Corner(infoBox, UDim.new(0, 14))
	Kit.Text({
		Text = "Сбросится: 💪 сила, ⭐ накопленная сила, 🪙 монеты",
		Color = Kit.Colors.RedDark,
		Stroke = false,
		Font = Kit.FontBold,
		Size = UDim2.new(1, -20, 0.5, -6),
		Position = UDim2.fromOffset(10, 6),
		MaxTextSize = 20,
		ZIndex = 5,
		Parent = infoBox,
	})
	Kit.Text({
		Text = "Останется: 🐾 питомцы, 🎒 рюкзак, 🌍 миры",
		Color = Kit.Colors.GreenDark,
		Stroke = false,
		Font = Kit.FontBold,
		Size = UDim2.new(1, -20, 0.5, -6),
		Position = UDim2.new(0, 10, 0.5, 0),
		MaxTextSize = 20,
		ZIndex = 5,
		Parent = infoBox,
	})

	local armed = false
	local armedAt = 0
	local busy = false
	local refresh -- объявлена ниже

	local _, buttonLabel, buttonGradient = Kit.Button({
		Name = "RebirthButton",
		Size = UDim2.new(1, -40, 0, 60),
		Position = UDim2.fromOffset(20, 272),
		Color = Kit.Colors.Purple,
		MaxTextSize = 30,
		StrokeThickness = 4,
		ZIndex = 4,
		Parent = content,
		OnClick = function()
			if busy then
				return
			end
			local total = State.Get("TotalStrength", 0)
			local cost = Formulas.RebirthCost(State.Get("Rebirths", 0))
			if total < cost then
				Notifications.Show("Нужно ещё " .. Format.Number(cost - total) .. " ⭐ силы", "error")
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
		local current = Formulas.RebirthMultiplier(rebirths)
		local nextMultiplier = Formulas.RebirthMultiplier(rebirths + 1)

		multiplierLabel.Text = Format.Multiplier(current) .. "  ➜  " .. Format.Multiplier(nextMultiplier)
		requirementLabel.Text = "Нужно ⭐ " .. Format.Number(cost) .. " накопленной силы"
		local fraction = cost > 0 and total / cost or 1
		setBar(fraction, fraction >= 1 and Kit.Colors.Green or Kit.Colors.Purple)
		progressLabel.Text = Format.Number(math.min(total, cost)) .. " / " .. Format.Number(cost)

		if fraction < 1 then
			armed = false
			buttonLabel.Text = "🔒 Копи силу"
			Kit.SetButtonColor(buttonGradient, Kit.Colors.Grey)
		elseif armed then
			buttonLabel.Text = "Точно? Нажми ещё раз!"
			Kit.SetButtonColor(buttonGradient, Kit.Colors.Orange)
		else
			buttonLabel.Text = "🔁 ПЕРЕРОДИТЬСЯ"
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
