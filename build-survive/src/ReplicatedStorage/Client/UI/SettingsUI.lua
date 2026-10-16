-- Окно настроек: громкость, качество графики, тряска камеры, сетка.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Client = script.Parent.Parent
local State = require(Client.State)
local Theme = require(script.Parent.Theme)
local Lib = require(script.Parent.Lib)
local HUD = require(script.Parent.HUD)

local new = Lib.new
local SettingsUI = {}

SettingsUI.onChanged = State.newSignal()

local refreshers: { () -> () } = {}

local function save()
	SettingsUI.onChanged:Fire(State.settings)
	task.spawn(function()
		Net.func("SetSettings"):InvokeServer(State.settings)
	end)
end

local function row(parent: Instance, title: string, order: number): Frame
	local r = Lib.panel({ Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = Theme.Panel2, LayoutOrder = order, Parent = parent })
	Lib.label(title, 18, { FontFace = Theme.FontHeavy, Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(220, 60), TextYAlignment = Enum.TextYAlignment.Center, Parent = r })
	return r
end

local function volumeRow(parent: Instance, title: string, key: string, order: number)
	local r = row(parent, title, order)
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(300, 36),
		BackgroundTransparency = 1,
		Parent = r,
	}, { Lib.list(Enum.FillDirection.Horizontal, 6) })
	local buttons = {}
	for i = 0, 5 do
		local v = i / 5
		buttons[i] = Lib.button(i == 0 and "🔇" or tostring(i * 20), { Size = UDim2.fromOffset(44, 36), TextSize = 14, LayoutOrder = i, Parent = holder }, function()
			State.settings[key] = v
			save()
			for _, f in refreshers do
				f()
			end
		end)
	end
	table.insert(refreshers, function()
		for i, b in buttons do
			Lib.setButtonColor(b, math.abs((State.settings[key] or 0) - i / 5) < 0.05 and Theme.Accent2 or Theme.Panel3)
		end
	end)
end

local function choiceRow(parent: Instance, title: string, key: string, options: { { any } }, order: number)
	local r = row(parent, title, order)
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(330, 36),
		BackgroundTransparency = 1,
		Parent = r,
	}, { Lib.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right) })
	local buttons = {}
	for i, o in options do
		buttons[i] = Lib.button(o[2], { Size = UDim2.fromOffset(104, 36), TextSize = 15, LayoutOrder = i, Parent = holder }, function()
			State.settings[key] = o[1]
			save()
			for _, f in refreshers do
				f()
			end
		end)
	end
	table.insert(refreshers, function()
		for i, b in buttons do
			Lib.setButtonColor(b, State.settings[key] == options[i][1] and Theme.Accent2 or Theme.Panel3)
		end
	end)
end

function SettingsUI.init()
	local shade, body = Lib.modal(HUD.gui(), "⚙ НАСТРОЙКИ", Vector2.new(640, 520), function()
		HUD.closeModal()
	end)
	local holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = body }, { Lib.list(Enum.FillDirection.Vertical, 10) })
	volumeRow(holder, "🎵 Музыка", "Music", 1)
	volumeRow(holder, "🔊 Звуки", "Sfx", 2)
	choiceRow(holder, "✨ Графика", "Graphics", { { 1, "Низкая" }, { 2, "Средняя" }, { 3, "Ультра" } }, 3)
	choiceRow(holder, "📳 Тряска камеры", "CameraShake", { { true, "Вкл" }, { false, "Выкл" } }, 4)
	choiceRow(holder, "▦ Сетка на участке", "ShowGrid", { { true, "Вкл" }, { false, "Выкл" } }, 5)
	Lib.label("Совет: на слабом телефоне выбери «Низкая» — исчезнут тени и размытие, взрывы станут проще.", 14, {
		TextColor3 = Theme.Sub,
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = holder,
	})
	HUD.registerModal("settings", shade, function()
		for _, f in refreshers do
			f()
		end
	end)
end

return SettingsUI
