-- Админские инструменты на клиенте: полёт.
-- Включается кнопкой в админ-панели: сервер проверяет права и ставит игроку атрибут Fly.
-- Персонажем управляет компьютер игрока, поэтому сам полёт — здесь: LinearVelocity держит
-- скорость (и гравитацию), AlignOrientation поворачивает персонажа туда, куда смотрит камера.
-- Управление: WASD — лететь, Пробел / E — вверх, Ctrl / Q — вниз, Shift — быстрее.
-- На телефоне: джойстик — лететь (вверх-вниз — куда смотрит камера), кнопка прыжка — вверх.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AdminTools = {}

local player = Players.LocalPlayer

local SPEED = 60        -- стад/с
local FAST = 3          -- множитель скорости с Shift
local ACCEL = 8         -- как быстро скорость догоняет нужную (1/с): полёт плавный, без рывков
local MAX_ACCEL = 1500  -- предел ускорения (стад/с²): с запасом против гравитации, но без «пушечных» толчков
local MAX_TORQUE = 1e7  -- поворот — сразу

type Flight = {
	char: Model,
	hum: Humanoid,
	attachment: Attachment,
	velocity: LinearVelocity,
	align: AlignOrientation,
	conns: { RBXScriptConnection },
}

local flight: Flight? = nil
local K = Enum.KeyCode

local function wantsFly(): boolean
	return player:GetAttribute("IsAdmin") == true and player:GetAttribute("Fly") == true
end

local function stop()
	local f = flight
	if not f then
		return
	end
	flight = nil
	for _, c in f.conns do
		c:Disconnect()
	end
	f.velocity:Destroy()
	f.align:Destroy()
	f.attachment:Destroy()
	if f.hum.Parent and f.hum.Health > 0 then
		f.hum.PlatformStand = false
		f.hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

local function start(char: Model)
	stop()
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root or hum.Health <= 0 then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "AdminFly"
	attachment.Parent = root

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "AdminFlyVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.MaxForce = math.max(root.AssemblyMass, 1) * MAX_ACCEL
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root

	local _, yaw, _ = root.CFrame:ToOrientation()
	local align = Instance.new("AlignOrientation")
	align.Name = "AdminFlyAlign"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = MAX_TORQUE
	align.Responsiveness = 40
	align.CFrame = CFrame.fromOrientation(0, yaw, 0)
	align.Parent = root

	-- без «стойки» гуманоид не пытается идти и падать, им управляют только ограничения
	hum.PlatformStand = true
	flight = {
		char = char,
		hum = hum,
		attachment = attachment,
		velocity = velocity,
		align = align,
		conns = {
			hum.Died:Connect(stop),
			char.AncestryChanged:Connect(function()
				if not char:IsDescendantOf(workspace) then
					stop()
				end
			end),
		},
	}
end

-- Полёт включён атрибутом — включаем или выключаем на текущем персонаже
local function refresh()
	local char = player.Character
	if char and wantsFly() then
		if not flight or flight.char ~= char then
			start(char)
		end
	else
		stop()
	end
end

local function keyAxis(plus: { Enum.KeyCode }, minus: { Enum.KeyCode }): number
	local v = 0
	for _, k in plus do
		if UserInputService:IsKeyDown(k) then
			v += 1
			break
		end
	end
	for _, k in minus do
		if UserInputService:IsKeyDown(k) then
			v -= 1
			break
		end
	end
	return v
end

-- Куда лететь (длина — от 0 до 1)
local function wantedDirection(hum: Humanoid): Vector3
	local cam = workspace.CurrentCamera
	local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector
	if UserInputService:GetFocusedTextBox() then
		return Vector3.zero -- пишет в чат
	end
	local forward = keyAxis({ K.W, K.Up }, { K.S, K.Down })
	local side = keyAxis({ K.D }, { K.A })
	local up = keyAxis({ K.Space, K.E }, { K.LeftControl, K.RightControl, K.Q })
	local dir = look * forward + right * side + Vector3.yAxis * up
	if forward == 0 and side == 0 then
		-- телефон и геймпад: джойстик задаёт MoveDirection (по горизонтали, относительно камеры)
		local move = hum.MoveDirection
		if move.Magnitude > 0.01 then
			local flat = Vector3.new(look.X, 0, look.Z)
			local along = flat.Magnitude > 0.01 and move:Dot(flat.Unit) or 0
			dir += move + Vector3.yAxis * look.Y * along
		end
		if up == 0 and hum.Jump then
			dir += Vector3.yAxis
		end
	end
	if dir.Magnitude > 1 then
		dir = dir.Unit
	end
	return dir
end

local function step(dt: number)
	local f = flight
	if not f then
		return
	end
	-- в сиденье (испытание машины) не летаем: ограничения потащили бы всю постройку
	local seated = f.hum.SeatPart ~= nil
	f.velocity.Enabled = not seated
	f.align.Enabled = not seated
	if seated then
		return
	end
	local fast = UserInputService:IsKeyDown(K.LeftShift) or UserInputService:IsKeyDown(K.RightShift)
	local target = wantedDirection(f.hum) * SPEED * (fast and FAST or 1)
	f.velocity.VectorVelocity = f.velocity.VectorVelocity:Lerp(target, math.min(1, dt * ACCEL))
	local look = workspace.CurrentCamera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		f.align.CFrame = CFrame.lookAt(Vector3.zero, flat)
	end
end

function AdminTools.isFlying(): boolean
	return flight ~= nil
end

function AdminTools.init()
	player:GetAttributeChangedSignal("Fly"):Connect(refresh)
	player:GetAttributeChangedSignal("IsAdmin"):Connect(refresh)
	player.CharacterAdded:Connect(function(char)
		-- полёт остаётся включённым и после смерти: ждём, пока соберётся новый персонаж
		char:WaitForChild("HumanoidRootPart", 10)
		char:WaitForChild("Humanoid", 10)
		refresh()
	end)
	player.CharacterRemoving:Connect(stop)
	RunService.RenderStepped:Connect(step)
	refresh()
end

return AdminTools
