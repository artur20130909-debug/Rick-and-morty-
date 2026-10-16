-- Левая панель: выбор блока, формы, размера, поворота и цвета.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Blocks = require(Shared.Blocks)
local BlockFactory = require(Shared.BlockFactory)
local Grid = require(Shared.Grid)
local Util = require(Shared.Util)

local Client = script.Parent.Parent
local State = require(Client.State)
local Theme = require(script.Parent.Theme)
local Lib = require(script.Parent.Lib)
local HUD = require(script.Parent.HUD)

local new = Lib.new
local BuildPanel = {}

local panel: Frame
local paintPanel: Frame
local grid: ScrollingFrame
local tab = "mat"
local tabButtons: { [string]: TextButton } = {}
local tiles: { [string]: { frame: TextButton, lock: Frame } } = {}
local shapeButtons: { [number]: TextButton } = {}
local sizeLabels: { [string]: TextLabel } = {}
local sizeRow: Frame
local shapeRow: Frame
local swatches: { { b: TextButton, c: Color3 } } = {}
local defaultColorBtn: TextButton
local nameLabel: TextLabel
local statsLabel: TextLabel

local SHAPE_ICONS = { "■", "◢", "◣", "▬", "●" }

local function tileKey(kind: string, id: number): string
	return kind .. id
end

local function previewSpec(kind: string, id: number)
	if kind == "item" then
		local it = Blocks.ItemById[id]
		return { mat = 0, shape = 1, item = id, size = it.size, rot = 1, color = it.color }
	end
	local m = Blocks.MaterialById[id]
	return { mat = id, shape = 1, item = 0, size = Vector3.new(2, 2, 2), rot = 1, color = m.color }
end

local function refreshTiles()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child.Visible = child:GetAttribute("Kind") == tab
		end
	end
	for key, t in tiles do
		local kind = t.frame:GetAttribute("Kind")
		local id = t.frame:GetAttribute("Id")
		t.lock.Visible = not State.isUnlocked(kind, id)
		local selected = State.sel.kind == kind and State.sel.id == id
		local stroke = t.frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = selected and Theme.Accent or Theme.Stroke
			stroke.Transparency = selected and 0 or 0.86
			stroke.Thickness = selected and 3 or 1.5
		end
	end
	for k, b in tabButtons do
		Lib.setButtonColor(b, k == tab and Theme.Accent2 or Theme.Panel2)
	end
end

local function refreshSelection()
	local sel = State.sel
	local spec = State.spec()
	local def = Blocks.def(spec)
	nameLabel.Text = def.name
	local hp = Blocks.maxHp(spec, spec.size)
	statsLabel.Text = string.format("Прочность %s • Защита %d%%", Util.formatNumber(hp), math.floor((def.blast or 0) * 100 + 0.5))
	for id, b in shapeButtons do
		Lib.setButtonColor(b, (sel.kind == "mat" and sel.shape == id) and Theme.Accent2 or Theme.Panel2)
	end
	shapeRow.Visible = sel.kind == "mat"
	local resizable = sel.kind == "mat" or (Blocks.ItemById[sel.id] and Blocks.ItemById[sel.id].resizable)
	sizeRow.Visible = resizable == true
	sizeLabels.X.Text = tostring(spec.size.X)
	sizeLabels.Y.Text = tostring(spec.size.Y)
	sizeLabels.Z.Text = tostring(spec.size.Z)
	for _, s in swatches do
		local stroke = s.b:FindFirstChildOfClass("UIStroke")
		if stroke then
			local on = sel.customColor and s.c == sel.color
			stroke.Transparency = on and 0 or 0.7
			stroke.Thickness = on and 3 or 1
			stroke.Color = on and Theme.Accent or Color3.new(0, 0, 0)
		end
	end
	Lib.setButtonColor(defaultColorBtn, sel.customColor and Theme.Panel2 or Theme.Accent2)
	refreshTiles()
end

local function makeTile(kind: string, def, order: number)
	local b = Lib.button("", {
		Size = UDim2.fromOffset(94, 108),
		BackgroundColor3 = Theme.Panel2,
		LayoutOrder = order,
		Parent = grid,
	}, function()
		if State.isUnlocked(kind, def.id) then
			State.selectBlock(kind, def.id)
		else
			HUD.toast("«" .. def.name .. "» продаётся в магазине за " .. Util.formatNumber(def.price), "warning")
			HUD.openModal("shop")
		end
	end)
	b:SetAttribute("Kind", kind)
	b:SetAttribute("Id", def.id)
	local vpHolder = new("Frame", {
		Size = UDim2.new(1, -8, 0, 70),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		Parent = b,
	})
	local spec = previewSpec(kind, def.id)
	local vp = Lib.viewport(function()
		return BlockFactory.build(spec, CFrame.identity, { preview = true })
	end)
	vp.Parent = vpHolder
	Lib.label(def.name, 13, {
		FontFace = Theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 2, 1, -32),
		Size = UDim2.new(1, -4, 0, 28),
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = b,
	})
	local lock = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = false,
		Parent = b,
	}, {
		Lib.corner(12),
		Lib.label("🔒", 22, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 28) }),
		Lib.label(Util.formatNumber(def.price), 15, {
			FontFace = Theme.FontHeavy,
			TextColor3 = Theme.Gold,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 48),
			Size = UDim2.new(1, 0, 0, 20),
		}),
	})
	tiles[tileKey(kind, def.id)] = { frame = b, lock = lock }
end

local function stepper(axis: string, title: string, order: number): Frame
	local f = new("Frame", { Size = UDim2.fromOffset(96, 36), BackgroundTransparency = 1, LayoutOrder = order, Parent = sizeRow })
	Lib.label(title, 14, { TextColor3 = Theme.Sub, Size = UDim2.fromOffset(20, 36), TextYAlignment = Enum.TextYAlignment.Center, Parent = f })
	local function change(d: number)
		local s = State.sel.size
		local v = { X = s.X, Y = s.Y, Z = s.Z }
		v[axis] = math.clamp(v[axis] + d, 1, Config.MaxBlockSize)
		State.sel.size = Vector3.new(v.X, v.Y, v.Z)
		State.changed:Fire("sel", State.sel)
	end
	Lib.button("−", { Position = UDim2.fromOffset(18, 4), Size = UDim2.fromOffset(24, 28), TextSize = 18, Parent = f }, function()
		change(-1)
	end)
	sizeLabels[axis] = Lib.label("2", 18, {
		FontFace = Theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.fromOffset(26, 36),
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = f,
	})
	Lib.button("+", { Position = UDim2.fromOffset(68, 4), Size = UDim2.fromOffset(24, 28), TextSize = 18, Parent = f }, function()
		change(1)
	end)
	return f
end

local function buildPalette(parent: Instance, order: number)
	local holder = new("Frame", {
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	}, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(22, 22), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, c in Config.Palette do
		local b = new("TextButton", {
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = c,
			LayoutOrder = i,
			Parent = holder,
		}, { Lib.corner(6), new("UIStroke", { Thickness = 1, Transparency = 0.7 }) })
		b.Activated:Connect(function()
			State.sel.color = c
			State.sel.customColor = true
			State.changed:Fire("sel", State.sel)
		end)
		table.insert(swatches, { b = b, c = c })
	end
end

function BuildPanel.init()
	local gui = HUD.gui()
	panel = Lib.panel({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 20),
		Size = UDim2.fromOffset(336, 610),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	})
	local inner = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = panel }, {
		Lib.padding(12),
		Lib.list(Enum.FillDirection.Vertical, 8),
	})
	-- вкладки
	local tabs = new("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, LayoutOrder = 1, Parent = inner }, {
		Lib.list(Enum.FillDirection.Horizontal, 8),
	})
	for i, t in { { "mat", "Материалы" }, { "item", "Особые" } } do
		tabButtons[t[1]] = Lib.button(t[2], { Size = UDim2.new(0.5, -4, 1, 0), TextSize = 17, LayoutOrder = i, Parent = tabs }, function()
			tab = t[1]
			refreshTiles()
		end)
	end
	grid = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 236),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.Accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = inner,
	}, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(94, 108), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})
	for i, m in Blocks.Materials do
		makeTile("mat", m, i)
	end
	for i, it in Blocks.Items do
		makeTile("item", it, 100 + i)
	end
	-- название и характеристики
	nameLabel = Lib.label("", 20, { FontFace = Theme.FontHeavy, LayoutOrder = 3, Parent = inner })
	statsLabel = Lib.label("", 14, { TextColor3 = Theme.Sub, LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 18), Parent = inner })
	-- формы
	shapeRow = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 5, Parent = inner }, {
		Lib.list(Enum.FillDirection.Horizontal, 6),
	})
	for _, s in Blocks.Shapes do
		local b = Lib.button(SHAPE_ICONS[s.id], { Size = UDim2.fromOffset(56, 44), TextSize = 22, LayoutOrder = s.id, Parent = shapeRow }, function()
			State.sel.shape = s.id
			State.changed:Fire("sel", State.sel)
		end)
		b:SetAttribute("Tip", s.name)
		shapeButtons[s.id] = b
	end
	-- размер
	sizeRow = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 6, Parent = inner }, {
		Lib.list(Enum.FillDirection.Horizontal, 8),
	})
	stepper("X", "Ш", 1)
	stepper("Y", "В", 2)
	stepper("Z", "Д", 3)
	-- поворот
	local rotRow = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 7, Parent = inner }, {
		Lib.list(Enum.FillDirection.Horizontal, 6),
	})
	Lib.button("⟳ Повернуть  R", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 15, LayoutOrder = 1, Parent = rotRow }, function()
		State.sel.rot = Grid.rotate(State.sel.rot, "Y")
		State.changed:Fire("sel", State.sel)
	end)
	Lib.button("⤾ Наклонить  T", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 15, LayoutOrder = 2, Parent = rotRow }, function()
		State.sel.rot = Grid.rotate(State.sel.rot, "X")
		State.changed:Fire("sel", State.sel)
	end)
	-- цвет
	local colorHeader = new("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 8, Parent = inner })
	Lib.label("Цвет", 16, { FontFace = Theme.FontHeavy, Size = UDim2.new(0.4, 0, 1, 0), Parent = colorHeader })
	defaultColorBtn = Lib.button("Как у материала", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(160, 28),
		TextSize = 14,
		Parent = colorHeader,
	}, function()
		State.sel.customColor = false
		State.selectBlock(State.sel.kind, State.sel.id)
	end)
	buildPalette(inner, 9)

	-- маленькая панель для покраски
	paintPanel = Lib.panel({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 20),
		Size = UDim2.fromOffset(336, 130),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	})
	local pinner = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = paintPanel }, {
		Lib.padding(12),
		Lib.list(Enum.FillDirection.Vertical, 8),
	})
	Lib.label("🎨 Выбери цвет и кликай по блокам", 16, { FontFace = Theme.FontHeavy, LayoutOrder = 1, Parent = pinner })
	buildPalette(pinner, 2)

	State.changed:Connect(function(key)
		if key == "sel" or key == "unlocked" then
			refreshSelection()
		elseif key == "tool" or key == "modal" or key == "siege" or key == "launched" then
			BuildPanel.updateVisibility()
		end
	end)
	refreshSelection()
end

function BuildPanel.updateVisibility()
	local busy = State.inSiege() or State.launched
	panel.Visible = State.tool == "build" and not busy
	paintPanel.Visible = State.tool == "paint" and not busy
end

return BuildPanel
