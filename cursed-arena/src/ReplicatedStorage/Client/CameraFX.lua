-- Камера: тряска, «удар» FOV, короткая кинокамера (пробуждение, ульта).
-- Кинокамера всегда возвращает обычную камеру сама (даже при ошибке или смерти).
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local CameraFX = {}
CameraFX.enabled = true      -- настройка «Тряска камеры»
CameraFX.baseFov = 70

local trauma = 0
local fovKick = 0
local cine = nil

function CameraFX.shake(m)
	if not CameraFX.enabled then return end
	trauma = math.min(1, trauma + (m or 0.5) * 0.42)
end

function CameraFX.kick(f)
	fovKick = math.max(fovKick, f or 4)
end

local function restore()
	local cam = workspace.CurrentCamera
	if not cam then return end
	cam.CameraType = Enum.CameraType.Custom
	local char = Players.LocalPlayer and Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
end

-- облёт вокруг модели dur секунд
function CameraFX.cinematic(model, dur)
	if cine then return end
	local root = model and model:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not root or not cam then return end
	cine = { model = model, root = root, t0 = os.clock(), dur = dur, startCF = cam.CFrame,
		yaw0 = math.atan2(-(cam.CFrame.Position - root.Position).X, (cam.CFrame.Position - root.Position).Z) }
	cam.CameraType = Enum.CameraType.Scriptable
	task.delay(dur + 0.3, function()
		if cine then
			cine = nil
			restore()
		end
	end)
end

function CameraFX.cancelCinematic()
	if cine then
		cine = nil
		restore()
	end
end

RunService:BindToRenderStep("CursedCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local cam = workspace.CurrentCamera
	if not cam then return end
	if cine then
		local ok = pcall(function()
			local c = cine
			local t = (os.clock() - c.t0) / c.dur
			if t >= 1 or not c.root.Parent then
				cine = nil
				restore()
				return
			end
			local look = c.root.CFrame.LookVector
			local ang = math.atan2(look.X, look.Z) + math.pi * (0.15 + 0.5 * t)
			local dist = 11 - 3 * math.sin(t * math.pi)
			local focus = c.root.Position + Vector3.new(0, 1.6, 0)
			local pos = focus + Vector3.new(math.sin(ang) * dist, 2.5 + 1.5 * t, math.cos(ang) * dist)
			cam.CFrame = CFrame.lookAt(pos, focus)
		end)
		if not ok then
			cine = nil
			restore()
		end
	end
	if trauma > 0 then
		local s = trauma * trauma
		local t = os.clock() * 26
		local rx = math.noise(t, 1.3) * s * 0.07
		local ry = math.noise(t, 7.1) * s * 0.07
		local rz = math.noise(t, 13.7) * s * 0.05
		cam.CFrame = cam.CFrame * CFrame.Angles(rx, ry, rz)
		trauma = math.max(0, trauma - dt * 2.4)
	end
	if fovKick > 0.01 then
		cam.FieldOfView = CameraFX.baseFov + fovKick
		fovKick = fovKick * math.max(0, 1 - dt * 9)
	elseif cam.FieldOfView ~= CameraFX.baseFov then
		cam.FieldOfView = CameraFX.baseFov
	end
end)

-- при смене персонажа — обычная камера
Players.LocalPlayer.CharacterAdded:Connect(function()
	cine = nil
	task.defer(restore)
end)

return CameraFX
