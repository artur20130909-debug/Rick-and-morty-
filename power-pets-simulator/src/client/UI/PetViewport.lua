--[[
	PetViewport — 3D-превью питомца в интерфейсе (ViewportFrame с камерой).
	Питомец плавно покачивается, пока окно видно на экране.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetBuilder = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("PetBuilder"))

local UI = script.Parent
local Kit = require(UI.Kit)

local PetViewport = {}
PetViewport.__index = PetViewport

local active = {}

-- Виден ли объект на экране (учитывает видимость всех родителей).
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
		if view.Model and view.Model.Parent and isShown(view.Frame) then
			local swing = math.sin(t * 1.3 + view.Seed) * 0.6
			local bob = math.sin(t * 2.2 + view.Seed) * 0.08 * view.Radius
			view.Model:PivotTo(CFrame.new(0, bob, 0) * CFrame.Angles(0, swing, 0))
		end
	end
end)

-- props: Size, Position, AnchorPoint, BackgroundColor3, BackgroundTransparency, ZIndex
function PetViewport.new(parent, props)
	local frame = Kit.new("ViewportFrame", {
		Name = "PetViewport",
		Size = props.Size or UDim2.fromOffset(200, 200),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.BackgroundColor3 or Color3.new(1, 1, 1),
		BackgroundTransparency = props.BackgroundTransparency or 0,
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.6, -1, 1),
		ZIndex = props.ZIndex or 1,
		Parent = parent,
	})
	if props.Corner then
		Kit.Corner(frame, props.Corner)
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = frame
	frame.CurrentCamera = camera

	local view = setmetatable({
		Frame = frame,
		Camera = camera,
		Model = nil,
		Radius = 1,
		Seed = math.random() * 10,
	}, PetViewport)
	active[view] = true
	return view
end

function PetViewport:SetPet(petId, golden)
	if self.Model then
		self.Model:Destroy()
		self.Model = nil
	end
	if not petId then
		return
	end
	local model = PetBuilder.Build(petId, golden)
	if not model then
		return
	end
	local boxCFrame, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z) * 0.5
	local center = boxCFrame.Position
	local distance = radius * 3.4 + 1
	self.Camera.CFrame = CFrame.lookAt(center + Vector3.new(0, radius * 0.35, -distance), center)
	self.Radius = radius
	model.Parent = self.Frame
	self.Model = model
end

function PetViewport:Destroy()
	active[self] = nil
	if self.Model then
		self.Model:Destroy()
		self.Model = nil
	end
	self.Frame:Destroy()
end

return PetViewport
