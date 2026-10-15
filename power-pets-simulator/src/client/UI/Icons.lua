--[[
	Icons — собственные иконки игры.
	Icons.Create(parent, name, props)    — 3D-иконка (см. IconModels) в ViewportFrame
	Icons.Pet(parent, petId, golden, props) — 3D-портрет питомца
	Icons.Coin2D(parent, props)          — плоская монетка из рамок (дёшево, для «+N» и цен)
	Icons.Glyph(parent, kind, props)     — плоские значки из рамок: "Close", "Plus", "Check", "Arrow"
	props: Size, Position, AnchorPoint, ZIndex, Animate ("Swing"|"Spin"|"Bob"), Outline (false — без контура),
	       Color, Color2, Zoom, LayoutOrder, Name
	Возвращает ViewportFrame и объект Viewport3D.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetBuilder = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("PetBuilder"))

local UI = script.Parent
local Kit = require(UI.Kit)
local IconModels = require(UI.IconModels)
local Viewport3D = require(UI.Viewport3D)

local Icons = {}

local DEFAULT_OUTLINE = 0.16

function Icons.Create(parent, name, props)
	props = props or {}
	local view = Viewport3D.new(parent, props)
	local model, settings = IconModels.Build(name, props)
	view:SetModel(model, {
		Outline = props.Outline ~= false and (props.Outline or DEFAULT_OUTLINE) or nil,
		Yaw = props.Yaw or settings.Yaw,
		Pitch = props.Pitch or settings.Pitch,
		Zoom = props.Zoom,
	})
	return view.Frame, view
end

function Icons.Pet(parent, petId, golden, props)
	props = props or {}
	local view = Viewport3D.new(parent, props)
	local model = PetBuilder.Build(petId, golden)
	if model then
		view:SetModel(model, {
			Outline = props.Outline ~= false and (props.Outline or 0.12) or nil,
			Yaw = props.Yaw or math.rad(-20),
			Pitch = props.Pitch or 0.15,
			Zoom = props.Zoom,
		})
	end
	return view.Frame, view
end

function Icons.Coin2D(parent, props)
	props = props or {}
	local coin = Kit.new("Frame", {
		Name = props.Name or "Coin",
		Size = props.Size or UDim2.fromOffset(28, 28),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = parent,
	})
	Kit.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = coin })
	Kit.Corner(coin, UDim.new(0.5, 0))
	Kit.Gradient(coin, Color3.fromRGB(255, 226, 90), Color3.fromRGB(235, 150, 20))
	Kit.new("UIStroke", { Color = Kit.Colors.Ink, Thickness = props.StrokeThickness or 2, Parent = coin })
	local inner = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		BackgroundColor3 = Color3.fromRGB(255, 205, 50),
		ZIndex = (props.ZIndex or 1) + 1,
		Parent = coin,
	})
	Kit.Corner(inner, UDim.new(0.5, 0))
	Kit.new("UIStroke", { Color = Color3.fromRGB(215, 140, 20), Thickness = 1.5, Parent = inner })
	local shine = Kit.new("Frame", {
		Position = UDim2.fromScale(0.2, 0.14),
		Size = UDim2.fromScale(0.28, 0.18),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.25,
		Rotation = -30,
		ZIndex = (props.ZIndex or 1) + 2,
		Parent = coin,
	})
	Kit.Corner(shine, UDim.new(0.5, 0))
	return coin
end

-- Плоские значки из полосок.
function Icons.Glyph(parent, kind, props)
	props = props or {}
	local holder = Kit.new("Frame", {
		Name = props.Name or kind,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromOffset(24, 24),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		ZIndex = props.ZIndex or 1,
		Parent = parent,
	})
	local color = props.Color or Kit.Colors.White
	local function bar(rotation, length, offsetX, offsetY)
		local item = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5 + (offsetX or 0), 0, 0.5 + (offsetY or 0), 0),
			Size = UDim2.fromScale(length, 0.22),
			Rotation = rotation,
			BackgroundColor3 = color,
			ZIndex = holder.ZIndex,
			Parent = holder,
		})
		Kit.Corner(item, UDim.new(0.5, 0))
		Kit.new("UIStroke", { Color = Kit.Colors.Ink, Thickness = 2, Parent = item })
		return item
	end
	if kind == "Close" then
		bar(45, 1)
		bar(-45, 1)
	elseif kind == "Plus" then
		bar(0, 1)
		bar(90, 1)
	elseif kind == "Check" then
		bar(45, 0.5, -0.17, 0.12)
		bar(-50, 0.85, 0.12, -0.02)
	elseif kind == "Arrow" then
		bar(0, 0.8, -0.05)
		bar(40, 0.5, 0.2, -0.12)
		bar(-40, 0.5, 0.2, 0.12)
	end
	return holder
end

-- Кнопки Kit умеют показывать иконки слева от текста.
Kit.SetIconFactory(Icons)

return Icons
