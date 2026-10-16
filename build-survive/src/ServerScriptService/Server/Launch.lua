-- Испытание постройки: блоки свариваются, становятся физическими,
-- колёса крутятся от кресла водителя, двигатели толкают, шары поднимают.
-- Так можно построить машину, танк, катер, самолёт или робота на колёсах.
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Blocks = require(Shared.Blocks)
local Net = require(Shared.Net)

local Plots = require(script.Parent.Plots)
local Building = require(script.Parent.Building)

local Launch = {}

type Plot = Plots.Plot

type Wheel = { part: BasePart, hinge: HingeConstraint }
type Run = {
	plot: Plot,
	player: Player,
	snapshot: string,
	wheels: { Wheel },
	thrusters: { { part: BasePart, force: VectorForce, flame: ParticleEmitter? } },
	conn: RBXScriptConnection?,
	dirSign: number,
	wrongTime: number,
	flipped: boolean,
}

local runs: { [number]: Run } = {}

local ITEM_WHEEL = Blocks.ItemByKey.Wheel.id
local ITEM_THRUSTER = Blocks.ItemByKey.Thruster.id
local ITEM_BALLOON = Blocks.ItemByKey.Balloon.id

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function isItem(b: Instance, id: number): boolean
	return b:GetAttribute("Item") == id
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

function Launch.isRunning(plot: Plot): boolean
	return runs[plot.index] ~= nil
end

function Launch.snapshotOf(plot: Plot): string?
	local r = runs[plot.index]
	return r and r.snapshot or nil
end

local function drive(run: Run, dt: number)
	-- кресло водителя, в котором кто-то сидит
	local seat: VehicleSeat? = nil
	for _, b in run.plot.blocks:GetChildren() do
		if b:IsA("VehicleSeat") and b.Occupant then
			seat = b
			break
		end
	end
	local throttle, steer = 0, 0
	if seat then
		throttle, steer = seat.ThrottleFloat, seat.SteerFloat
	end
	local speed = Config.Launch.WheelSpeed
	for _, w in run.wheels do
		if w.part.Parent and seat then
			local right = seat.CFrame.RightVector
			local side = ((w.part.Position - seat.Position):Dot(right) >= 0) and 1 or -1
			local axisSign = (w.part.CFrame.RightVector:Dot(right) >= 0) and 1 or -1
			local d = math.clamp(throttle - steer * side, -1, 1)
			w.hinge.AngularVelocity = -speed * d * axisSign * run.dirSign
		else
			w.hinge.AngularVelocity = 0
		end
	end
	-- автоматическая проверка направления: если на «газ» едем назад — переворачиваем знак
	if seat and math.abs(throttle) > 0.5 and #run.wheels > 0 and not run.flipped then
		local v = seat.AssemblyLinearVelocity:Dot(seat.CFrame.LookVector) * throttle
		if v < -2 then
			run.wrongTime += dt
			if run.wrongTime > 0.6 then
				run.dirSign = -run.dirSign
				run.flipped = true
			end
		else
			run.wrongTime = 0
		end
	end
	local on = throttle > 0.1
	for _, t in run.thrusters do
		t.force.Enabled = on and t.part.Parent ~= nil
		if t.flame then
			t.flame.Enabled = on
		end
	end
end

function Launch.start(player: Player): (boolean, string?)
	local plot = Plots.of(player)
	if not plot then
		return false, "У тебя нет участка"
	end
	if plot.siege then
		return false, "Сначала закончи осаду"
	end
	if runs[plot.index] then
		return false, "Испытание уже идёт"
	end
	local list = plot.blocks:GetChildren()
	if #list == 0 then
		return false, "Сначала построй что-нибудь"
	end
	local run: Run = {
		plot = plot,
		player = player,
		snapshot = Building.serialize(plot),
		wheels = {},
		thrusters = {},
		conn = nil,
		dirSign = 1,
		wrongTime = 0,
		flipped = false,
	}
	runs[plot.index] = run
	plot.launched = true

	overlap.FilterDescendantsInstances = { plot.blocks }
	local pairsDone: { [string]: boolean } = {}
	local ids: { [Instance]: number } = {}
	for i, b in list do
		ids[b] = i
	end
	local function key(a: Instance, b: Instance): string
		local x, y = ids[a] or 0, ids[b] or 0
		return x < y and (x .. "|" .. y) or (y .. "|" .. x)
	end

	-- 1. Свариваем соприкасающиеся блоки (колёса — отдельно)
	for _, b in list do
		if b:IsA("BasePart") and not isItem(b, ITEM_WHEEL) then
			local near = workspace:GetPartBoundsInBox(b.CFrame, b.Size + Vector3.new(0.3, 0.3, 0.3), overlap)
			for _, n in near do
				if n ~= b and n.Name == "Block" and not isItem(n, ITEM_WHEEL) then
					local k = key(b, n)
					if not pairsDone[k] then
						pairsDone[k] = true
						weld(b, n)
					end
				end
			end
		end
	end

	-- 2. Колёса на шарнирах
	for _, b in list do
		if b:IsA("BasePart") and isItem(b, ITEM_WHEEL) then
			local attached = false
			for _, side in { 1, -1 } do
				local face = b.CFrame * CFrame.new(side * (b.Size.X / 2 + 0.3), 0, 0)
				local near = workspace:GetPartBoundsInBox(face, Vector3.new(0.5, b.Size.Y * 0.5, b.Size.Z * 0.5), overlap)
				for _, n in near do
					if n ~= b and n.Name == "Block" and not isItem(n, ITEM_WHEEL) then
						local pivot = b.CFrame * CFrame.new(side * b.Size.X / 2, 0, 0)
						local a0 = Instance.new("Attachment")
						a0.CFrame = n.CFrame:ToObjectSpace(pivot)
						a0.Parent = n
						local a1 = Instance.new("Attachment")
						a1.CFrame = CFrame.new(side * b.Size.X / 2, 0, 0)
						a1.Parent = b
						local hinge = Instance.new("HingeConstraint")
						hinge.Attachment0 = a0
						hinge.Attachment1 = a1
						hinge.ActuatorType = Enum.ActuatorType.Motor
						hinge.MotorMaxTorque = Config.Launch.WheelTorque
						hinge.MotorMaxAcceleration = 60
						hinge.AngularVelocity = 0
						hinge.Parent = b
						table.insert(run.wheels, { part = b, hinge = hinge })
						attached = true
						break
					end
				end
				if attached then
					break
				end
			end
			if not attached then
				-- колесо ни к чему не прикреплено сбоку — просто привариваем к соседу
				local near = workspace:GetPartBoundsInBox(b.CFrame, b.Size + Vector3.new(0.3, 0.3, 0.3), overlap)
				for _, n in near do
					if n ~= b and n.Name == "Block" then
						weld(b, n)
						break
					end
				end
			end
		end
	end

	-- 3. Двигатели и воздушные шары
	local g = workspace.Gravity
	for _, b in list do
		if b:IsA("BasePart") and isItem(b, ITEM_THRUSTER) then
			local att = Instance.new("Attachment")
			att.Name = "ThrustAttachment"
			att.Parent = b
			local f = Instance.new("VectorForce")
			f.Attachment0 = att
			f.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			f.Force = Vector3.new(Config.Launch.ThrusterForce, 0, 0)
			f.ApplyAtCenterOfMass = true
			f.Enabled = false
			f.Parent = b
			local exhaust = b:FindFirstChild("Exhaust")
			local flame = exhaust and exhaust:FindFirstChild("Flame") :: ParticleEmitter?
			table.insert(run.thrusters, { part = b, force = f, flame = flame })
		elseif b:IsA("BasePart") and isItem(b, ITEM_BALLOON) then
			local att = Instance.new("Attachment")
			att.Parent = b
			local f = Instance.new("VectorForce")
			f.Attachment0 = att
			f.RelativeTo = Enum.ActuatorRelativeTo.World
			f.Force = Vector3.new(0, Config.Launch.BalloonLift * g, 0)
			f.ApplyAtCenterOfMass = true
			f.Parent = b
		end
	end

	-- 4. Отпускаем физику
	for _, b in list do
		if b:IsA("BasePart") then
			b.Anchored = false
		end
	end
	for _, b in list do
		if b:IsA("BasePart") and b.Parent and b:CanSetNetworkOwnership() then
			pcall(function()
				b:SetNetworkOwner(player)
			end)
		end
	end

	run.conn = RunService.Heartbeat:Connect(function(dt)
		drive(run, dt)
	end)
	Net.event("LaunchState"):FireClient(player, { active = true, wheels = #run.wheels, thrusters = #run.thrusters })
	return true, nil
end

function Launch.stop(player: Player, silent: boolean?): (boolean, string?)
	local plot = Plots.of(player)
	if not plot then
		return false, nil
	end
	local run = runs[plot.index]
	if not run then
		return false, nil
	end
	runs[plot.index] = nil
	if run.conn then
		run.conn:Disconnect()
	end
	-- выкинуть всех из кресел, чтобы персонажей не утянуло
	for _, b in plot.blocks:GetChildren() do
		if b:IsA("Seat") or b:IsA("VehicleSeat") then
			local occupant = (b :: any).Occupant :: Humanoid?
			if occupant then
				occupant.Sit = false
				occupant.Jump = true
			end
		end
	end
	plot.launched = false
	if not silent then
		Building.restore(plot, run.snapshot)
		Net.event("LaunchState"):FireClient(player, { active = false })
	end
	return true, nil
end

return Launch
