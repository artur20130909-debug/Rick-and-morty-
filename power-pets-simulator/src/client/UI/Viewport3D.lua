--[[
	Viewport3D — 3D-картинка в интерфейсе (ViewportFrame + камера).
	Используется для иконок, питомцев в карточках, яиц и превью.

	local view = Viewport3D.new(parent, { Size = …, Position = …, Animate = "Swing" | "Spin" | "Bob" | nil })
	view:SetModel(model, { Outline = 0.16, Yaw = 0.3, Pitch = 0.15, Zoom = 1 })
	view:SetTransform(cframe) — повернуть модель вручную (например, тряска яйца)

	Контур (Outline) — мультяшная тёмная обводка: позади каждой детали ставится её
	чуть увеличенная тёмная копия.
]]

local RunService = game:GetService("RunService")

local UI = script.Parent
local Kit = require(UI.Kit)

local Viewport3D = {}
Viewport3D.__index = Viewport3D

local OUTLINE_COLOR = Color3.fromRGB(35, 30, 60)
local active = {}

local function isShown(guiObject)
	local current = guiObject
	while current and not current:IsA("LayerCollector") do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end
	return current ~= nil and current.Enabled
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for view in pairs(active) do
		if view.Animate and view.Model and view.Model.Parent and isShown(view.Frame) then
			local base = view.Base
			local animation
			if view.Animate == "Spin" then
				animation = CFrame.Angles(0, t * (view.Speed or 1.2) + view.Seed, 0)
			elseif view.Animate == "Bob" then
				animation = CFrame.new(0, math.sin(t * 2 + view.Seed) * 0.08 * view.Radius, 0) * CFrame.Angles(0, math.sin(t * 1.1 + view.Seed) * 0.25, 0)
			else
				animation = CFrame.new(0, math.sin(t * 2.2 + view.Seed) * 0.06 * view.Radius, 0) * CFrame.Angles(0, math.sin(t * 1.3 + view.Seed) * 0.6, 0)
			end
			view.Model:PivotTo(base * animation)
		end
	end
end)

--[[ props: Size, Position, AnchorPoint, ZIndex, BackgroundColor3, BackgroundTransparency (1 по умолчанию),
	Corner, FieldOfView, Animate, Speed, Name, LayoutOrder ]]
function Viewport3D.new(parent, props)
	props = props or {}
	local frame = Kit.new("ViewportFrame", {
		Name = props.Name or "View3D",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.BackgroundColor3 or Color3.new(1, 1, 1),
		BackgroundTransparency = props.BackgroundTransparency or 1,
		Ambient = props.Ambient or Color3.fromRGB(170, 170, 185),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.55, -0.9, 1),
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = parent,
	})
	if props.Corner then
		Kit.Corner(frame, props.Corner)
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = props.FieldOfView or 30
	camera.Parent = frame
	frame.CurrentCamera = camera

	local view = setmetatable({
		Frame = frame,
		Camera = camera,
		Model = nil,
		Base = CFrame.identity,
		Radius = 1,
		Animate = props.Animate,
		Speed = props.Speed,
		Seed = math.random() * 10,
	}, Viewport3D)
	active[view] = true
	return view
end

local function addOutline(model, width)
	local parts = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item.Transparency < 0.5 and not item:GetAttribute("NoOutline") then
			table.insert(parts, item)
		end
	end
	for _, part in ipairs(parts) do
		local copy = part:Clone()
		for _, child in ipairs(copy:GetChildren()) do
			if not child:IsA("DataModelMesh") then
				child:Destroy()
			end
		end
		copy.Name = "Outline"
		copy.Color = OUTLINE_COLOR
		copy.Material = Enum.Material.SmoothPlastic
		copy.Reflectance = 0
		copy.Transparency = 0
		copy.Size = part.Size + Vector3.one * width
		copy.CFrame = part.CFrame + Vector3.new(0, 0, width * 0.9)
		copy.Parent = model
	end
end

-- options: Outline (толщина или nil), Yaw, Pitch (наклон камеры), Zoom (1 = вписать целиком)
function Viewport3D:SetModel(model, options)
	options = options or {}
	if self.Model then
		self.Model:Destroy()
		self.Model = nil
	end
	if not model then
		return
	end
	if options.Outline and options.Outline > 0 then
		addOutline(model, options.Outline)
	end
	local boxCFrame, size = model:GetBoundingBox()
	local center = boxCFrame.Position
	local radius = math.max(size.X, size.Y, size.Z) * 0.5
	local fov = math.rad(self.Camera.FieldOfView)
	local distance = radius / math.tan(fov / 2) * 1.08 / (options.Zoom or 1)
	local pitch = options.Pitch or 0.12
	self.Camera.CFrame = CFrame.lookAt(center + Vector3.new(0, distance * pitch, -distance), center)
	self.Base = CFrame.Angles(0, options.Yaw or 0, 0)
	self.Radius = radius
	model:PivotTo(self.Base)
	model.Parent = self.Frame
	self.Model = model
end

function Viewport3D:SetTransform(cframe)
	if self.Model then
		self.Model:PivotTo(self.Base * cframe)
	end
end

function Viewport3D:Destroy()
	active[self] = nil
	if self.Model then
		self.Model:Destroy()
		self.Model = nil
	end
	self.Frame:Destroy()
end

return Viewport3D
