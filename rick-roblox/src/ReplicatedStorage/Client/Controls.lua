-- Управление от первого лица: блокировка/разблокировка движения, бег (Shift), покачивание
-- камеры при ходьбе, шаги по полу, клавиша паузы. Обычное движение — стандартное Roblox
-- (WASD / джойстик на телефоне).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Controls = {}
local U, Config, Settings, Audio
local player = Players.LocalPlayer
local char, hum, root
local playerModule
local active = false     -- идёт обычная игра (не меню и не сценка)
local frozen = true
local sprint = false
local bobPhase, bobAmp, lastStep = 0, 0, 0
local fovBoost = 0
Controls.onPause = nil

local function getControls()
	if playerModule == nil then
		local ps = player:FindFirstChild("PlayerScripts")
		local pm = ps and ps:FindFirstChild("PlayerModule")
		if pm then
			local ok, m = pcall(require, pm)
			playerModule = ok and m or false
		end
	end
	if playerModule then
		local ok, c = pcall(function() return playerModule:GetControls() end)
		if ok then return c end
	end
	return nil
end

local function onCharacter(c)
	char = c
	hum = c:WaitForChild("Humanoid", 10)
	root = c:WaitForChild("HumanoidRootPart", 10)
	if not hum or not root then return end
	hum.WalkSpeed = frozen and 0 or Config.WalkSpeed
	-- стандартные шаги глушим, если есть свои (из атласа)
	if Config.Sounds.SfxAtlas ~= "" then
		task.delay(1, function()
			local run = root:FindFirstChild("Running")
			if run and run:IsA("Sound") then run.Volume = 0 end
		end)
	end
end

function Controls.init(ctx)
	U, Config, Settings, Audio = ctx.Util, ctx.Config, ctx.Settings, ctx.Audio
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end

	-- бег
	ContextActionService:BindAction("RM_Sprint", function(_, state)
		sprint = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
	-- пауза: P или M (Esc занят меню Roblox)
	ContextActionService:BindAction("RM_Pause", function(_, state)
		if state == Enum.UserInputState.Begin and Controls.onPause then Controls.onPause() end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.P, Enum.KeyCode.M, Enum.KeyCode.ButtonStart)

	RunService:BindToRenderStep("RM_Controls", Enum.RenderPriority.Character.Value + 1, function(dt)
		if not hum or not root or not root.Parent then return end
		local moving = false
		local speed = 0
		if active and not frozen then
			local v = root.AssemblyLinearVelocity
			speed = Vector3.new(v.X, 0, v.Z).Magnitude
			moving = speed > 1.5 and hum.FloorMaterial ~= Enum.Material.Air
			local want = (sprint and hum.MoveDirection.Magnitude > 0.1) and Config.RunSpeed or Config.WalkSpeed
			hum.WalkSpeed = U.damp(hum.WalkSpeed, want, 8, dt)
		end
		-- покачивание камеры
		local target = (moving and Settings.get("HeadBob")) and math.clamp(speed / Config.WalkSpeed, 0, 1.6) or 0
		bobAmp = U.damp(bobAmp, target, 7, dt)
		if moving then bobPhase = bobPhase + dt * (5.2 + speed * 0.28) end
		local off = Vector3.new(math.sin(bobPhase) * 0.075, -math.abs(math.cos(bobPhase)) * 0.12 + 0.06, 0) * bobAmp
		hum.CameraOffset = active and off or Vector3.new()
		-- шаги: на каждом «ударе» ноги
		if moving then
			local stepIdx = math.floor(bobPhase / math.pi)
			if stepIdx ~= lastStep then
				lastStep = stepIdx
				local mat = hum.FloorMaterial
				local vol = (mat == Enum.Material.Fabric or mat == Enum.Material.Carpet) and 0.22 or 0.42
				Audio.play("Step" .. tostring(math.random(1, 4)), { volume = vol * (sprint and 1.2 or 1), pitchJitter = 0.08 })
			end
		end
		-- чуть шире обзор на бегу
		local cam = workspace.CurrentCamera
		if active and cam.CameraType ~= Enum.CameraType.Scriptable then
			fovBoost = U.damp(fovBoost, (sprint and moving) and 6 or 0, 5, dt)
			cam.FieldOfView = Settings.get("Fov") + fovBoost
		end
	end)
end

-- обычная игра от первого лица (true) или меню/сценка (false)
function Controls.setActive(on)
	active = on
	if on then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
	else
		player.CameraMode = Enum.CameraMode.Classic
	end
end

-- запретить/разрешить движение персонажа
function Controls.freeze(on)
	frozen = on
	local c = getControls()
	if c then
		if on then c:Disable() else c:Enable() end
	end
	if hum then
		hum.WalkSpeed = on and 0 or Config.WalkSpeed
		hum.JumpHeight = on and 0 or 4
	end
end

-- поставить персонажа (корень) в точку; anchored — закрепить (лёжа, сидя)
function Controls.place(cf, anchored)
	if not root then return end
	root.Anchored = anchored == true
	root.AssemblyLinearVelocity = Vector3.new()
	if char then char:PivotTo(cf) else root.CFrame = cf end
end

function Controls.character() return char, hum, root end

-- позиция глаз персонажа относительно корня (для стыковки сценки с обычной камерой)
function Controls.eyeOffset()
	if char and root then
		local head = char:FindFirstChild("Head")
		if head then return head.Position.Y - root.Position.Y + 0.1 end
	end
	return 1.6
end

function Controls.isActive() return active end

local _uis = UserInputService
return Controls
