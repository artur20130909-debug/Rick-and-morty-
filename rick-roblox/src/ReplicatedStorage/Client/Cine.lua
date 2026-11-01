-- Кинокамера для сценок: ключевые кадры (позиция + поворот + поле зрения) с плавными переходами,
-- «дыхание» (лёгкое покачивание), тряска. Время сценок идёт только когда игра не на паузе.
local RunService = game:GetService("RunService")

local Cine = {}
local U, Settings
Cine.active = false

local state = {
	base = CFrame.new(), fov = 70, breathe = 0, breatheTarget = 0,
	shakeT = 0, shakeDur = 0, shakeP = 0, anim = nil, offset = CFrame.new(),
}

local EASE = {}
function EASE.linear(t) return t end
function EASE.inout(t) return t * t * (3 - 2 * t) end
function EASE.inout2(t) return t * t * t * (t * (t * 6 - 15) + 10) end
function EASE.out(t) return 1 - (1 - t) * (1 - t) * (1 - t) end
EASE["in"] = function(t) return t * t * t end
function EASE.back(t) local c1, c3 = 1.3, 2.3; return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2 end

local function evalAnim(a, t)
	local keys = a.keys
	local n = #keys
	if t <= keys[1].t then return keys[1].cf, keys[1].fov end
	if t >= keys[n].t then return keys[n].cf, keys[n].fov end
	local i = 1
	while i < n and keys[i + 1].t < t do i = i + 1 end
	local k0, k1 = keys[i], keys[i + 1]
	local u = (t - k0.t) / math.max(1e-4, k1.t - k0.t)
	local e = (EASE[k1.ease or "inout"] or EASE.inout)(u)
	local rot = k0.cf:Lerp(k1.cf, e)
	local pos
	if a.spline then
		-- позиция — по сплайну через все ключи (глобальный параметр по времени)
		local pts = a.points
		local seg = (i - 1) + e
		pos = U.catmull(pts, seg / (n - 1))
	else
		pos = k0.cf.Position:Lerp(k1.cf.Position, e)
	end
	local fov = k0.fov + (k1.fov - k0.fov) * e
	return CFrame.new(pos) * (rot - rot.Position), fov
end

local function render(dt)
	if not Cine.active then return end
	local cam = workspace.CurrentCamera
	if not U.paused then
		local a = state.anim
		if a then
			a.t = math.min(a.t + dt * (a.speed or 1), a.total)
			local cf, fov = evalAnim(a, a.t)
			state.base = cf
			state.fov = fov
			if a.t >= a.total then
				state.anim = nil
				a.done:Fire()
			end
		end
		if state.shakeT > 0 then state.shakeT = math.max(0, state.shakeT - dt) end
	end
	state.breathe = U.damp(state.breathe, state.breatheTarget, 2, dt)
	local off = CFrame.new()
	local t = os.clock()
	if state.breathe > 0.001 then
		local b = state.breathe
		off = off * CFrame.new(0, math.sin(t * 1.5) * 0.035 * b, 0)
			* CFrame.Angles(math.sin(t * 0.7) * 0.006 * b + math.noise(t * 0.3, 1) * 0.01 * b, math.noise(t * 0.25, 2) * 0.014 * b, math.sin(t * 0.5) * 0.004 * b)
	end
	if state.shakeT > 0 then
		local p = state.shakeP * (state.shakeT / math.max(0.01, state.shakeDur))
		off = off * CFrame.Angles(math.noise(t * 22, 3) * 0.04 * p, math.noise(t * 22, 4) * 0.04 * p, math.noise(t * 18, 5) * 0.03 * p)
	end
	cam.CFrame = state.base * state.offset * off
	cam.FieldOfView = state.fov
end

function Cine.init(ctx)
	U, Settings = ctx.Util, ctx.Settings
	RunService:BindToRenderStep("RM_Cine", Enum.RenderPriority.Camera.Value + 2, render)
end

-- взять камеру под управление сценки
function Cine.take(cf, fov)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	state.base = cf or cam.CFrame
	state.fov = fov or cam.FieldOfView
	state.offset = CFrame.new()
	state.anim = nil
	Cine.active = true
	render(0)
end

-- отдать камеру игроку (обычная камера Roblox)
function Cine.release()
	Cine.active = false
	state.anim = nil
	state.breatheTarget = 0
	state.breathe = 0
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = Settings.get("Fov")
	local plr = game:GetService("Players").LocalPlayer
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
end

function Cine.set(cf, fov)
	state.base = cf
	if fov then state.fov = fov end
	state.anim = nil
end

function Cine.get() return state.base, state.fov end

-- сыграть ключевые кадры: keys = { {t = 0, cf = CFrame, fov = 70}, {t = 1.2, cf = ..., ease = "inout"}, ... }
-- opts.spline — позиция по сплайну; opts.wait = false — не ждать конца
function Cine.play(keys, opts)
	opts = opts or {}
	for _, k in ipairs(keys) do k.fov = k.fov or state.fov end
	local a = { keys = keys, t = 0, total = keys[#keys].t, done = U.signal(), spline = opts.spline, speed = opts.speed }
	if opts.spline then
		a.points = {}
		for i, k in ipairs(keys) do a.points[i] = k.cf.Position end
	end
	if state.anim then state.anim.done:Fire() end
	state.anim = a
	if opts.wait ~= false then a.done.Event:Wait() end
	return a
end

-- плавно перевести камеру из текущего положения
function Cine.move(cf, t, ease, fov)
	return Cine.play({ { t = 0, cf = state.base, fov = state.fov }, { t = t, cf = cf, fov = fov or state.fov, ease = ease or "inout" } })
end
function Cine.moveAsync(cf, t, ease, fov)
	return Cine.play({ { t = 0, cf = state.base, fov = state.fov }, { t = t, cf = cf, fov = fov or state.fov, ease = ease or "inout" } }, { wait = false })
end

function Cine.breathe(amount) state.breatheTarget = amount or 0 end

function Cine.shake(power, dur)
	state.shakeP = math.max(state.shakeP * (state.shakeT > 0 and 1 or 0), power)
	state.shakeDur = dur
	state.shakeT = dur
end

-- дополнительный сдвиг поверх ключей (например, наклон головы)
function Cine.setOffset(cf) state.offset = cf or CFrame.new() end

return Cine
