-- Окно магазина: материалы и особые блоки с 3D-превью, прочностью и ценой.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Blocks = require(Shared.Blocks)
local BlockFactory = require(Shared.BlockFactory)
local Util = require(Shared.Util)
local Net = require(Shared.Net)

local Client = script.Parent.Parent
local State = require(Client.State)
local SoundPlayer = require(Client.SoundPlayer)
local Theme = require(script.Parent.Theme)
local Lib = require(script.Parent.Lib)
local HUD = require(script.Parent.HUD)

local new = Lib.new
local ShopUI = {}

local cards: { { kind: string, def: any, button: TextButton, frame: Frame } } = {}
local list: ScrollingFrame
local tab = "mat"
local tabButtons: { [string]: TextButton } = {}
local goldLabel: TextLabel

local function stars(value: number, max: number): string
	local n = math.clamp(math.ceil(value / max * 5), 1, 5)
	return string.rep("★", n) .. string.rep("☆", 5 - n)
end

local function refresh()
	goldLabel.Text = Util.formatNumber(State.gold)
	for k, b in tabButtons do
		Lib.setButtonColor(b, k == tab and Theme.Accent2 or Theme.Panel2)
	end
	for _, c in cards do
		c.frame.Visible = c.kind == tab
		local owned = State.isUnlocked(c.kind, c.def.id)
		if c.def.price <= 0 then
			c.button.Text = "БЕСПЛАТНО"
			Lib.setButtonColor(c.button, Theme.Panel3)
		elseif owned then
			c.button.Text = "✔ КУПЛЕНО"
			Lib.setButtonColor(c.button, Theme.Panel3)
		else
			c.button.Text = Util.formatNumber(c.def.price)
			Lib.setButtonColor(c.button, State.gold >= c.def.price and Theme.Good or Color3.fromRGB(90, 70, 50))
		end
	end
end

local function makeCard(kind: string, def, order: number)
	local frame = Lib.panel({
		Size = UDim2.fromOffset(196, 268),
		BackgroundColor3 = Theme.Panel,
		LayoutOrder = order,
		Parent = list,
	})
	local vpBox = new("Frame", {
		Size = UDim2.new(1, -16, 0, 110),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Theme.Panel2,
		Parent = frame,
	}, { Lib.corner(10), Lib.gradient(Color3.fromRGB(70, 80, 110), Color3.fromRGB(28, 32, 46), 90) })
	local spec = kind == "item" and { mat = 0, shape = 1, item = def.id, size = def.size, rot = 1, color = def.color }
		or { mat = def.id, shape = 1, item = 0, size = Vector3.new(2, 2, 2), rot = 1, color = def.color }
	local vp = Lib.viewport(function()
		return BlockFactory.build(spec, CFrame.identity, { preview = true })
	end, nil, true)
	vp.Parent = vpBox
	Lib.label(def.name, 19, { FontFace = Theme.FontHeavy, Position = UDim2.fromOffset(10, 122), Size = UDim2.new(1, -20, 0, 24), Parent = frame })
	Lib.label(def.desc or "", 13, {
		TextColor3 = Theme.Sub,
		Position = UDim2.fromOffset(10, 148),
		Size = UDim2.new(1, -20, 0, 34),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	})
	local statText = string.format("Прочность %s\nЗащита от взрыва %s", stars(def.hp, 2800), stars((def.blast or 0.3) * 100, 90))
	if (def.nuke or 0) >= 0.85 then
		statText ..= "\n☢ Защита от радиации"
	end
	Lib.label(statText, 13, {
		TextColor3 = Theme.Accent,
		Position = UDim2.fromOffset(10, 184),
		Size = UDim2.new(1, -20, 0, 36),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	})
	local button = Lib.button("", {
		Position = UDim2.new(0, 10, 1, -44),
		Size = UDim2.new(1, -20, 0, 36),
		TextSize = 17,
		Parent = frame,
	})
	button.Activated:Connect(function()
		if def.price <= 0 or State.isUnlocked(kind, def.id) then
			State.selectBlock(kind, def.id)
			HUD.closeModal()
			return
		end
		local ok, msg = Net.func("Buy"):InvokeServer(kind, def.id)
		if ok then
			SoundPlayer.play("Purchase")
			HUD.toast(msg or "Куплено", "success")
			State.selectBlock(kind, def.id)
		elseif msg then
			HUD.toast(msg, "error")
		end
	end)
	table.insert(cards, { kind = kind, def = def, button = button, frame = frame })
end

function ShopUI.init()
	local shade, body = Lib.modal(HUD.gui(), "🛒 МАГАЗИН БЛОКОВ", Vector2.new(900, 640), function()
		HUD.closeModal()
	end)
	local top = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = body })
	for i, t in { { "mat", "Материалы" }, { "item", "Особые блоки" } } do
		tabButtons[t[1]] = Lib.button(t[2], {
			Position = UDim2.fromOffset((i - 1) * 190, 0),
			Size = UDim2.fromOffset(180, 42),
			Parent = top,
		}, function()
			tab = t[1]
			refresh()
		end)
	end
	local goldPill = Lib.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(190, 42),
		BackgroundColor3 = Theme.Panel2,
		Parent = top,
	})
	local coin = Lib.coin(26)
	coin.Position = UDim2.fromOffset(10, 8)
	coin.Parent = goldPill
	goldLabel = Lib.label("0", 22, { FontFace = Theme.FontHeavy, TextColor3 = Theme.Gold, Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -52, 1, 0), Parent = goldPill })

	list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = body,
	}, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(196, 268), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})
	for i, m in Blocks.Materials do
		makeCard("mat", m, i)
	end
	for i, it in Blocks.Items do
		makeCard("item", it, 100 + i)
	end
	HUD.registerModal("shop", shade, refresh)
	State.changed:Connect(function(key)
		if key == "gold" or key == "unlocked" then
			if State.modal == "shop" then
				refresh()
			end
		end
	end)
end

return ShopUI
