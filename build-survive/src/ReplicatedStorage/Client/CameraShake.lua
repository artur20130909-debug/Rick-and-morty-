-- Тряска камеры от взрывов. Несколько толчков складываются и плавно затухают.
-- Смещение снимается перед работой стандартной камеры, чтобы взгляд не «уплывал».
local RunService = game:GetService("RunService")

local CameraShake = {}

type Shake = { amp: number, dur: number, t: number, freq: number, seed: number }
local shakes: { Shake } = {}
local applied = CFrame.identity
CameraShake.enabled = true

-- amp — сила в градусах, dur — длительность в секундах
function CameraShake.shake(amp: number, dur: number, freq: number?)
	if not CameraShake.enabled or amp <= 0.01 then
		return
	end
	table.insert(shakes, { amp = math.min(amp, 9), dur = dur, t = 0, freq = freq or 18, seed = math.random() * 100 })
end

function CameraShake.init()
	RunService:BindToRenderStep("BuildSurviveShakeUndo", Enum.RenderPriority.Camera.Value - 1, function()
		if applied ~= CFrame.identity then
			local cam = workspace.CurrentCamera
			cam.CFrame = cam.CFrame * applied:Inverse()
			applied = CFrame.identity
		end
	end)
	RunService:BindToRenderStep("BuildSurviveShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if #shakes == 0 then
			return
		end
		local rx, ry, rz = 0, 0, 0
		for i = #shakes, 1, -1 do
			local s = shakes[i]
			s.t += dt
			if s.t >= s.dur then
				table.remove(shakes, i)
			else
				local k = (1 - s.t / s.dur) ^ 2 * s.amp
				local x = s.t * s.freq + s.seed
				rx += math.noise(x, 0.5, 0) * k
				ry += math.noise(0.5, x, 0) * k
				rz += math.noise(0, 0.5, x) * k * 0.5
			end
		end
		applied = CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame * applied
	end)
end

return CameraShake
