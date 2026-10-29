-- Рэгдолл для R6: суставы Motor6D отключаются, их заменяют шарниры BallSocket.
-- Игрокам состояние «Physics» включает их собственный клиент (так требует Roblox),
-- ботам и манекенам — сервер.
local Util = require(game:GetService("ReplicatedStorage").Shared.Util)

local Ragdoll = {}

local JOINTS = {
	{ motor = "Neck", part = "Head", a0 = Vector3.new(0, 1, 0), a1 = Vector3.new(0, -0.5, 0), up = true, cone = 40, twist = 40 },
	{ motor = "Right Shoulder", part = "Right Arm", a0 = Vector3.new(1, 0.5, 0), a1 = Vector3.new(-0.5, 0.5, 0), cone = 100, twist = 70 },
	{ motor = "Left Shoulder", part = "Left Arm", a0 = Vector3.new(-1, 0.5, 0), a1 = Vector3.new(0.5, 0.5, 0), cone = 100, twist = 70 },
	{ motor = "Right Hip", part = "Right Leg", a0 = Vector3.new(0.5, -1, 0), a1 = Vector3.new(0, 1, 0), cone = 70, twist = 30 },
	{ motor = "Left Hip", part = "Left Leg", a0 = Vector3.new(-0.5, -1, 0), a1 = Vector3.new(0, 1, 0), cone = 70, twist = 30 },
}

local DOWN = CFrame.Angles(0, 0, -math.pi / 2) -- ось X вложения смотрит вниз
local UP = CFrame.Angles(0, 0, math.pi / 2)

local function setup(model)
	local torso = model:FindFirstChild("Torso")
	if not torso then return nil end
	local data = model:FindFirstChild("RagdollRig")
	if data then return data end
	data = Instance.new("Folder")
	data.Name = "RagdollRig"
	for _, j in ipairs(JOINTS) do
		local part = model:FindFirstChild(j.part)
		if part then
			local rot = j.up and UP or DOWN
			local a0 = Instance.new("Attachment")
			a0.Name = "RD_" .. j.part .. "_0"
			a0.CFrame = CFrame.new(j.a0) * rot
			a0.Parent = torso
			local a1 = Instance.new("Attachment")
			a1.Name = "RD_" .. j.part .. "_1"
			a1.CFrame = CFrame.new(j.a1) * rot
			a1.Parent = part
			local s = Instance.new("BallSocketConstraint")
			s.Name = j.part
			s.Attachment0 = a0
			s.Attachment1 = a1
			s.LimitsEnabled = true
			s.UpperAngle = j.cone
			s.TwistLimitsEnabled = true
			s.TwistLowerAngle = -j.twist
			s.TwistUpperAngle = j.twist
			s.Enabled = false
			s.Parent = data
			local nc = Instance.new("NoCollisionConstraint")
			nc.Part0 = torso
			nc.Part1 = part
			nc.Parent = data
		end
	end
	local ll, rl = model:FindFirstChild("Left Leg"), model:FindFirstChild("Right Leg")
	if ll and rl then
		local nc = Instance.new("NoCollisionConstraint")
		nc.Part0 = ll
		nc.Part1 = rl
		nc.Parent = data
	end
	data.Parent = model
	return data
end
Ragdoll.setup = setup

local function setEnabled(f, on)
	local model = f.model
	local torso = model:FindFirstChild("Torso")
	local data = setup(model)
	if not torso or not data then return end
	for _, j in ipairs(JOINTS) do
		local m = torso:FindFirstChild(j.motor)
		local s = data:FindFirstChild(j.part)
		local part = model:FindFirstChild(j.part)
		if m then m.Enabled = not on end
		if s then s.Enabled = on end
		if part and j.part ~= "Head" then part.CanCollide = on end
	end
end

function Ragdoll.start(f, duration)
	local now = Util.now()
	f.ragdollEnd = math.max(f.ragdollEnd, now + duration)
	f.blocking = false
	if f.ragdolled then return end
	f.ragdolled = true
	setEnabled(f, true)
	f.model:SetAttribute("Ragdoll", true)
	if not f.player then
		f.hum.PlatformStand = false
		f.hum:ChangeState(Enum.HumanoidStateType.Physics)
	end
end

function Ragdoll.stop(f)
	if not f.ragdolled then return end
	f.ragdolled = false
	f.ragdollEnd = 0
	setEnabled(f, false)
	f.model:SetAttribute("Ragdoll", false)
	if not f.player and f.hum.Health > 0 then
		f.hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	-- встаём ровно: убираем крен корня
	local root = f.root
	if root and root.Parent and f.hum.Health > 0 then
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) end
		local pos = root.Position
		local ground = Util.ground(pos, 12)
		local y = math.max(pos.Y, ground.Y + 3)
		root.CFrame = CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(pos.X, y, pos.Z) + flat.Unit)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

-- проверка окончания (зовёт Fighters.step через onExpire)
function Ragdoll.tick(f, now)
	if f.ragdolled and not f.dead and now >= f.ragdollEnd then
		Ragdoll.stop(f)
	end
end

return Ragdoll
