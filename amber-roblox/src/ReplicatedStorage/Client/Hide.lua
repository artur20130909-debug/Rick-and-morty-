-- Укрытие (шкаф, гардероб, тумба, под кроватью) на клиенте.
-- Сервер шлёт Hidden(модель укрытия) — камера переезжает внутрь и смотрит наружу сквозь щели:
-- дыхание, ограниченный обзор мышью (±35°), тёмные планки поверх экрана, размытые ближние доски.
-- Сердце стучит громче, когда рядом заключённый (модели в workspace.Inmates ближе 40 стадов).
-- Через 10 с в укрытии раз в несколько секунд запускается «концентрация» (UI.qte),
-- каждый результат уходит на сервер: Action("qte", ok). Выход — E, Пробел или кнопка: Action("unhide").
-- Hidden(nil) — сервер выпустил: возвращаем обычную камеру.
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local PPS = game:GetService("ProximityPromptService")

local Hide = {}

local ctx, player, Sound, Net
local Action = nil
local T = 0

local QTE_AFTER = 10       -- секунд в укрытии до первой концентрации
local QTE_TIMEOUT = 8      -- если UI так и не ответил — считаем промахом
local NEAR_RADIUS = 40
local YAW_LIMIT = math.rad(35)
local PITCH_LIMIT = math.rad(25)

---------------------------------------------------------------- помощники
local warned = {}
local function warnOnce(tag, err)
	if warned[tag] then return end
	warned[tag] = true
	warn("[AA] Hide." .. tostring(tag) .. ": " .. tostring(err))
end
local function guarded(tag, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then warnOnce(tag, err) end
	return ok
end
local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end
local function approach(a, b, d, rate) return a + (b - a) * (1 - math.exp(-rate * d)) end
local function smooth(t)
	t = clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function ui(name, ...)
	local U = ctx and ctx.UI
	if type(U) ~= "table" or type(U[name]) ~= "function" then return nil end
	local ok, r = pcall(U[name], ...)
	if not ok then
		warnOnce("UI." .. name, r)
		return nil
	end
	return r
end
local function call(modName, fnName, ...)
	local M = ctx and ctx[modName]
	if type(M) ~= "table" or type(M[fnName]) ~= "function" then return nil end
	local ok, r = pcall(M[fnName], ...)
	if not ok then
		warnOnce(modName .. "." .. fnName, r)
		return nil
	end
	return r
end
local function action(kind, a, b)
	if not Action then return end
	local ok, err = pcall(function() Action:FireServer(kind, a, b) end)
	if not ok then warnOnce("Action", err) end
end

---------------------------------------------------------------- состояние
local H = {
	model = nil, kind = "Closet", base = nil, fromCF = nil, t0 = 0,
	yaw = 0, pitch = 0, touch = Vector2.new(0, 0),
	near = 0, nearT = 0, spike = 0,
	breath = nil, heart = nil,
	qte = nil, round = 0, qteNext = 0,
	lastExitReq = -10, ltm = {}, ppsWas = true,
}

---------------------------------------------------------------- планки поверх экрана
local OV = { gui = nil, sets = {} }
local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	for k, v in pairs(props) do f[k] = v end
	f.Parent = parent
	return f
end
local function gradient(f, rot, seq)
	local g = Instance.new("UIGradient")
	g.Rotation = rot
	g.Transparency = seq
	g.Parent = f
	return g
end
-- тёмная планка: плотнее в середине, мягкие края
local SLAT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.3, 0.3),
	NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 0.85),
})

local function buildSet(kind)
	local holder = frame(OV.gui, { Name = kind, BackgroundTransparency = 1, Size = UDim2.fromScale(1.2, 1.2), Position = UDim2.fromScale(-0.1, -0.1), Visible = false })
	if kind == "UnderBed" then
		-- днище кровати сверху, край пола снизу
		local top = frame(holder, { Size = UDim2.fromScale(1, 0.5), Position = UDim2.fromScale(0, 0) })
		gradient(top, 90, NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.02), NumberSequenceKeypoint.new(0.8, 0.12), NumberSequenceKeypoint.new(1, 1) }))
		local fringe = frame(holder, { Size = UDim2.fromScale(1, 0.06), Position = UDim2.fromScale(0, 0.44), BackgroundColor3 = Color3.fromRGB(40, 30, 36) })
		gradient(fringe, 90, NumberSequence.new(0.2, 1))
		local bottom = frame(holder, { Size = UDim2.fromScale(1, 0.14), Position = UDim2.fromScale(0, 0.86) })
		gradient(bottom, -90, NumberSequence.new(0.15, 1))
	elseif kind == "Cabinet" then
		-- вертикальные щели дверцы
		for i = 0, 8 do
			local s = frame(holder, { Size = UDim2.fromScale(0.075, 1), Position = UDim2.fromScale(i * 0.125 - 0.02, 0) })
			gradient(s, 0, SLAT)
		end
		frame(holder, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.82 })
	else
		-- жалюзи шкафа: горизонтальные планки
		for i = 0, 9 do
			local s = frame(holder, { Size = UDim2.fromScale(1, 0.062), Position = UDim2.fromScale(0, i * 0.112 - 0.02) })
			gradient(s, 90, SLAT)
		end
		frame(holder, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.85 })
	end
	OV.sets[kind] = holder
	return holder
end

local function showOverlay(kind)
	if not OV.gui then
		local pg = player:FindFirstChildOfClass("PlayerGui")
		if not pg then return end
		local g = Instance.new("ScreenGui")
		g.Name = "AA_HideOverlay"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.DisplayOrder = 1
		g.Enabled = false
		g.Parent = pg
		OV.gui = g
	end
	local set = kind
	if set ~= "UnderBed" and set ~= "Cabinet" then set = "Closet" end
	for k, h in pairs(OV.sets) do h.Visible = (k == set) end
	local h = OV.sets[set] or buildSet(set)
	h.Visible = true
	OV.active = h
	OV.gui.Enabled = true
end

local function hideOverlay()
	if OV.gui then OV.gui.Enabled = false end
	OV.active = nil
end

---------------------------------------------------------------- своё тело не мешает обзору
local function setBodyHidden(on)
	local char = player.Character
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			if on then
				if H.ltm[d] == nil then H.ltm[d] = d.LocalTransparencyModifier end
				d.LocalTransparencyModifier = 1
			elseif H.ltm[d] ~= nil then
				d.LocalTransparencyModifier = H.ltm[d]
			end
		end
	end
	if not on then H.ltm = {} end
end

---------------------------------------------------------------- заключённые рядом
local function nearestInmate(pos)
	local f = workspace:FindFirstChild("Inmates")
	if not f then return math.huge end
	local my = player:GetAttribute("MatchId") or 0
	local best = math.huge
	for _, m in ipairs(f:GetChildren()) do
		if m:IsA("Model") then
			local mid = m:GetAttribute("MatchId")
			if mid == nil or my == 0 or mid == my then
				local ok, p = pcall(function() return m:GetPivot().Position end)
				if ok and p then
					local d = (p - pos).Magnitude
					if d < best then best = d end
				end
			end
		end
	end
	return best
end

---------------------------------------------------------------- концентрация (UI.qte)
local function stopQte()
	local q = H.qte
	H.qte = nil
	if q and type(q.handle) == "table" and type(q.handle.stop) == "function" then
		local ok, err = pcall(q.handle.stop)
		if not ok then warnOnce("qte.stop", err) end
	end
end

local function feedback(ok)
	if ok then return end
	-- сбилось дыхание: удар сердца, дрожь, тёмная вспышка
	H.spike = 1
	pcall(Sound.play, "Breath", nil, { Volume = 0.6, PlaybackSpeed = 1.25 })
	call("Fx", "shake", 0.45, 0.35)
	call("World", "pulse", Color3.fromRGB(90, 0, 0), 0.6, 0.7)
end

local function finishRound(round, ok)
	if not H.qte or H.qte.round ~= round then return end
	action("qte", ok and true or false)
	feedback(ok)
	stopQte()
	H.qteNext = T + 3.5 + math.random() * 2.5
end

local function startQte()
	if H.qte or not H.model then return end
	local U = ctx and ctx.UI
	if type(U) ~= "table" or type(U.qte) ~= "function" then
		H.qteNext = T + 5
		return
	end
	H.round = H.round + 1
	local round = H.round
	local q = { t0 = T, round = round }
	H.qte = q
	local ok, handle = pcall(U.qte, function(res) guarded("qteResult", finishRound, round, res) end)
	if not ok then
		warnOnce("UI.qte", handle)
		H.qte = nil
		H.qteNext = T + 5
		return
	end
	if H.qte == q then
		q.handle = handle
	elseif type(handle) == "table" and type(handle.stop) == "function" then
		-- ответ пришёл сразу — этот раунд уже закрыт
		pcall(handle.stop)
	end
end

local function qteStep()
	if not H.model then return end
	if H.qte then
		if T - H.qte.t0 > QTE_TIMEOUT then finishRound(H.qte.round, false) end
		return
	end
	local ph = call("World", "phase") or ""
	if ph == "alert" then return end
	if T - H.t0 >= QTE_AFTER and T >= H.qteNext then startQte() end
end

---------------------------------------------------------------- выход
local function requestExit()
	if not H.model then return end
	if T - H.t0 < 0.5 or T - H.lastExitReq < 0.6 then return end
	H.lastExitReq = T
	action("unhide")
end

local function exitHandler(_, state)
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	-- во время концентрации клавиши нужны интерфейсу
	if H.qte then return Enum.ContextActionResult.Pass end
	requestExit()
	return Enum.ContextActionResult.Sink
end

local function stopLoop(s)
	if s then pcall(function() s:Destroy() end) end
end

local function leave()
	if not H.model then return end
	stopQte()
	H.model = nil
	hideOverlay()
	stopLoop(H.breath)
	stopLoop(H.heart)
	H.breath = nil
	H.heart = nil
	call("World", "setMod", "hide", nil)
	pcall(function() PPS.Enabled = H.ppsWas end)
	pcall(function() CAS:UnbindAction("AA_HideExit") end)
	guarded("body", setBodyHidden, false)
	pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
	local cam = workspace.CurrentCamera
	if cam.CameraType == Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Custom end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
	cam.FieldOfView = 70
end

local function enter(model)
	if H.model == model then return end
	if H.model then leave() end
	local inside = model:FindFirstChild("Inside", true)
	local cf
	if inside and inside:IsA("BasePart") then
		cf = inside.CFrame
	else
		cf = model:GetPivot()
	end
	local kind = model:GetAttribute("HideType") or "Closet"
	H.model = model
	H.kind = kind
	H.base = cf * CFrame.new(0, (kind == "UnderBed") and 0.35 or 1.6, 0)
	H.t0 = T
	H.yaw = 0
	H.pitch = (kind == "UnderBed") and math.rad(-4) or 0
	H.touch = Vector2.new(0, 0)
	H.near = 0
	H.spike = 0
	H.qteNext = T + QTE_AFTER
	H.lastExitReq = -10
	local cam = workspace.CurrentCamera
	H.fromCF = cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable
	showOverlay(kind)
	local ok1, b = pcall(Sound.loop, "Breath", nil, { Volume = 0 })
	if ok1 then H.breath = b end
	local ok2, hb = pcall(Sound.loop, "Heartbeat", nil, { Volume = 0 })
	if ok2 then H.heart = hb end
	call("World", "setMod", "hide", { dofNear = 0.6, dofFar = 0.15, dofFocus = 8, dofRadius = 5, vignette = 0.4, exposure = -0.05, saturation = -0.1 })
	call("Controls", "setFlashlight", false)
	pcall(function()
		H.ppsWas = PPS.Enabled
		PPS.Enabled = false
	end)
	pcall(function()
		CAS:BindActionAtPriority("AA_HideExit", exitHandler, true, Enum.ContextActionPriority.High.Value + 10,
			Enum.KeyCode.E, Enum.KeyCode.Space, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonA)
		CAS:SetTitle("AA_HideExit", "Выйти")
		CAS:SetPosition("AA_HideExit", UDim2.new(0.15, 0, 0.2, 0))
	end)
end

---------------------------------------------------------------- кадр
local function camStep(dt)
	if not H.model then return end
	if not H.model.Parent then
		leave()
		return
	end
	local cam = workspace.CurrentCamera
	if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
	-- обзор мышью/пальцем, но не дальше щелей
	local modal = ui("anyModal") == true
	local look = Vector2.new(0, 0)
	if H.qte or modal then
		pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
	else
		pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.LockCenter end)
		local ok, d = pcall(function() return UIS:GetMouseDelta() end)
		if ok and d then look = d end
	end
	look = look + H.touch
	H.touch = Vector2.new(0, 0)
	H.yaw = clamp(H.yaw - look.X * 0.004, -YAW_LIMIT, YAW_LIMIT)
	H.pitch = clamp(H.pitch - look.Y * 0.004, -PITCH_LIMIT, PITCH_LIMIT)
	-- дыхание: чаще, когда кто-то рядом; дрожь от страха
	local near = H.near
	local rate = 1.3 + near * 1.6
	local br = math.sin(T * rate)
	local sway = CFrame.new(math.sin(T * 0.7) * 0.03, br * 0.035, 0) * CFrame.Angles(br * 0.006, math.sin(T * 0.5) * 0.004, 0)
	if near > 0.5 then
		local k = (near - 0.5) * 2
		sway = sway * CFrame.Angles(math.noise(T * 9, 1.7) * 0.006 * k, math.noise(T * 9, 4.2) * 0.006 * k, 0)
	end
	local target = H.base * CFrame.Angles(0, H.yaw, 0) * CFrame.Angles(H.pitch, 0, 0) * sway
	local k = (T - H.t0) / 0.35
	if k < 1 and H.fromCF then target = H.fromCF:Lerp(target, smooth(k)) end
	cam.CFrame = target
	cam.FieldOfView = approach(cam.FieldOfView, 64, dt, 5)
	-- планки чуть сдвигаются, когда смотришь по сторонам
	if OV.active then
		OV.active.Position = UDim2.fromScale(-0.1 - H.yaw / YAW_LIMIT * 0.06, -0.1 + H.pitch / PITCH_LIMIT * 0.05 + br * 0.004)
	end
	guarded("body", setBodyHidden, true)
end

local function slowStep(dt)
	if not H.model then return end
	-- сердце и дыхание по близости заключённого
	H.near = approach(H.near, clamp(1 - nearestInmate(H.base.Position) / NEAR_RADIUS, 0, 1), dt, 3)
	H.spike = math.max(0, H.spike - dt * 0.8)
	local near = H.near
	if H.heart then
		H.heart.Volume = clamp(0.08 + 0.85 * near ^ 1.3 + 0.5 * H.spike, 0, 1.2)
		H.heart.PlaybackSpeed = 0.85 + 0.6 * near + 0.2 * H.spike
	end
	if H.breath then
		H.breath.Volume = 0.3 * (1 - 0.65 * near)
		H.breath.PlaybackSpeed = 1 + 0.25 * near
	end
	call("World", "setMod", "hide", { dofNear = 0.6, dofFar = 0.15, dofFocus = 8, dofRadius = 5, vignette = 0.4 + 0.25 * near, exposure = -0.05, saturation = -0.1 - 0.1 * near })
	qteStep()
end

---------------------------------------------------------------- публичное API
function Hide.isHidden() return H.model ~= nil end
function Hide.current() return H.model end
function Hide.timeHidden()
	if not H.model then return 0 end
	return T - H.t0
end
function Hide.requestExit() requestExit() end
-- выпустить локально (без сервера): смена сцены, смерть, новый персонаж
function Hide.forceExit() leave() end

function Hide.init(c)
	ctx = c
	player = c.player or game:GetService("Players").LocalPlayer
	Sound = c.Sound
	Net = c.Net

	task.spawn(function()
		local ok, ev = pcall(Net.event, "Action")
		if ok then Action = ev end
	end)
	task.spawn(function()
		local ok, ev = pcall(Net.event, "Hidden")
		if not ok or not ev then return end
		ev.OnClientEvent:Connect(function(model)
			if typeof(model) == "Instance" then
				guarded("enter", enter, model)
			else
				guarded("leave", leave)
			end
		end)
	end)

	call("World", "onScene", function(scene, _, prev)
		-- повторный Scene "house" не выпускает из укрытия, настоящая смена сцены — выпускает
		if scene ~= "house" or prev ~= "house" then guarded("leave", leave) end
	end)
	player.CharacterAdded:Connect(function() guarded("leave", leave) end)
	player:GetAttributeChangedSignal("Alive"):Connect(function()
		if player:GetAttribute("Alive") == false then guarded("leave", leave) end
	end)
	player:GetAttributeChangedSignal("Hidden"):Connect(function()
		-- сервер снял флаг, а событие потерялось
		if player:GetAttribute("Hidden") == false and H.model and T - H.t0 > 1 then guarded("leave", leave) end
	end)
	UIS.InputChanged:Connect(function(input, gp)
		if gp or not H.model then return end
		if input.UserInputType == Enum.UserInputType.Touch then
			H.touch = H.touch + Vector2.new(input.Delta.X, input.Delta.Y) * 1.5
		end
	end)

	local acc = 0
	RunService:BindToRenderStep("AA_Hide", Enum.RenderPriority.Camera.Value + 2, function(dt)
		T = T + dt
		guarded("camera", camStep, dt)
		acc = acc + dt
		if acc >= 0.2 then
			local d = acc
			acc = 0
			guarded("slow", slowStep, d)
		end
	end)
end

return Hide
