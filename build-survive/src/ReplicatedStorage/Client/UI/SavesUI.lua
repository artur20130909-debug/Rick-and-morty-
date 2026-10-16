-- Окно сохранений: 3 слота и очистка участка.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local Examples = require(Shared.Examples)

local Client = script.Parent.Parent
local State = require(Client.State)
local Theme = require(script.Parent.Theme)
local Lib = require(script.Parent.Lib)
local HUD = require(script.Parent.HUD)

local new = Lib.new
local SavesUI = {}

local infoLabels: { TextLabel } = {}
local note: TextLabel
local clearBtn: TextButton
local confirmClear = false

local function refresh()
	for i = 1, Config.SaveSlots do
		local info = State.slots[i]
		if info then
			infoLabels[i].Text = string.format("%d %s • %s", info.count, Util.plural(info.count, "блок", "блока", "блоков"), os.date("%d.%m %H:%M", info.time))
			infoLabels[i].TextColor3 = Theme.Text
		else
			infoLabels[i].Text = "Пусто"
			infoLabels[i].TextColor3 = Theme.Muted
		end
	end
	note.Text = State.saveEnabled and "Постройка на участке сохраняется автоматически, когда ты выходишь из игры."
		or "⚠ Сохранения выключены: опубликуй игру и включи Game Settings → Security → Enable Studio Access to API Services."
	note.TextColor3 = State.saveEnabled and Theme.Sub or Theme.Accent
	confirmClear = false
	clearBtn.Text = "🧹 Очистить участок"
end

local function call(name: string, ...: any)
	local args = { ... }
	task.spawn(function()
		local ok, msg = Net.func(name):InvokeServer(table.unpack(args))
		if msg then
			HUD.toast(msg, ok and "success" or "error")
		end
	end)
end

function SavesUI.init()
	local shade, body = Lib.modal(HUD.gui(), "💾 СОХРАНЕНИЯ", Vector2.new(660, 640), function()
		HUD.closeModal()
	end)
	local holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = body }, { Lib.list(Enum.FillDirection.Vertical, 10) })
	for i = 1, Config.SaveSlots do
		local row = Lib.panel({ Size = UDim2.new(1, 0, 0, 72), BackgroundColor3 = Theme.Panel2, LayoutOrder = i, Parent = holder })
		Lib.label("Слот " .. i, 20, { FontFace = Theme.FontHeavy, Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(200, 26), Parent = row })
		infoLabels[i] = Lib.label("Пусто", 15, { Position = UDim2.fromOffset(16, 38), Size = UDim2.fromOffset(280, 22), Parent = row })
		Lib.button("Сохранить", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -150, 0.5, 0),
			Size = UDim2.fromOffset(130, 44),
			BackgroundColor3 = Theme.Good,
			TextSize = 17,
			Parent = row,
		}, function()
			call("SaveSlot", i)
		end)
		Lib.button("Загрузить", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(130, 44),
			BackgroundColor3 = Theme.Info,
			TextSize = 17,
			Parent = row,
		}, function()
			call("LoadSlot", i)
		end)
	end
	clearBtn = Lib.button("🧹 Очистить участок", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = Color3.fromRGB(120, 40, 40),
		LayoutOrder = 10,
		Parent = holder,
	}, function()
		if not confirmClear then
			confirmClear = true
			clearBtn.Text = "Точно? Нажми ещё раз (отменить можно Ctrl+Z)"
			return
		end
		confirmClear = false
		clearBtn.Text = "🧹 Очистить участок"
		call("Clear")
	end)
	note = Lib.label("", 14, { LayoutOrder = 11, Size = UDim2.new(1, 0, 0, 40), Parent = holder })
	-- готовые примеры
	Lib.label("Примеры построек", 18, { FontFace = Theme.FontHeavy, LayoutOrder = 12, Parent = holder })
	local exRow = new("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, LayoutOrder = 13, Parent = holder }, {
		Lib.list(Enum.FillDirection.Horizontal, 8),
	})
	local icons = { "🏠", "🛡", "🤖", "🚜" }
	for i, ex in Examples do
		local b = Lib.button(icons[i] .. " " .. ex.name, {
			Size = UDim2.new(0.25, -6, 1, 0),
			TextSize = 14,
			TextWrapped = true,
			BackgroundColor3 = Theme.Panel3,
			LayoutOrder = i,
			Parent = exRow,
		}, function()
			call("LoadExample", i)
		end)
		b:SetAttribute("Tip", ex.desc)
	end
	HUD.registerModal("saves", shade, refresh)
	State.changed:Connect(function(key)
		if (key == "slots" or key == "saveEnabled") and State.modal == "saves" then
			refresh()
		end
	end)
end

return SavesUI
