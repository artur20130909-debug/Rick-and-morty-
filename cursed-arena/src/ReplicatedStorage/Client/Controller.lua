-- Управление: ПК (мышь + клавиатура), геймпад, телефон (кнопки создаёт HUD и зовёт Controller.*).
-- M1 и рывок показываются у себя сразу (без ожидания сервера), урон и проверки — на сервере.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = ReplicatedStorage:WaitForChild("Client")
local Config = require(Shared.Config)
local Characters = require(Shared.Characters)
local Poses = require(Shared.Poses)
local Util = require(Shared.Util)
local Animator = require(Client.Animator)
local Effects = require(Client.Effects)

local Controller = {}
local player = Players.LocalPlayer
local Action = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Action")

Controller.enabled = true           -- false, пока открыто меню
Controller.cds = { 0, 0, 0, 0 }     -- конец перезарядки приёмов (время сервера)
Controller.cdLen = { 1, 1, 1, 1 }   -- полная длина перезарядки (для полоски)
Controller.dashReady = { F = 0, B = 0, L = 0, R = 0 } -- os.clock(), когда рывок снова доступен
Controller.recast = nil             -- { slot, from, to } окно повторного нажатия (время сервера)
Controller.awakened = false
-- обратные вызовы для интерфейса
Controller.onDenied = nil           -- function(what, slot) — нажали, но нельзя (перезарядка, мало шкалы)
Controller.onM1 = nil               -- function(index)
Controller.onDash = nil             -- function(key)
Controller.onMove = nil             -- function(slot)

local state = {
	char = nil, hum = nil, root = nil,
	m1Index = 0, m1Last = -100, m1CdEnd = 0, busyEnd = 0,
	m1Held = false, blockHeld = false, blocking = false,
	faceDir = nil, faceUntil = 0,
	dashUntil = 0, dashLV = nil, dashFace = nil,
	lastSend = {},
}
Controller.state = state

---------------------------------------------------------------- персонаж
local function attr(name)
	return state.char and state.char:GetAttribute(name)
end

local function alive()
	return state.hum ~= nil and state.hum.Health > 0 and state.root ~= nil and state.root.Parent ~= nil
end

local function charId()
	local id = attr("Char") or player:GetAttribute("CharId")
	if Characters.valid(id) then return id end
	return Characters.Default
end

local m1Cache = {}
local function m1Config()
	local id = charId()
	local c = m1Cache[id]
	if c then return c end
	c = {}
	for k, v in pairs(Config.M1) do c[k] = v end
	local def = Characters.get(id)
	if def.M1 then for k, v in pairs(def.M1) do c[k] = v end end
	m1Cache[id] = c
	return c
end

-- можно ли сейчас действовать (по данным сервера и своим)
local function free()
	if not Controller.enabled or not alive() then return false end
	if attr("Ragdoll") or attr("Stunned") or attr("Rooted") then return false end
	if attr("Busy") then return false end
	if state.blocking then return false end
	return true
end
Controller.free = free

local function serverNow()
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------- прицел
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function enemiesNear(pos, range)
	local out = {}
	local function scan(folder)
		if not folder then return end
		for _, m in ipairs(folder:GetChildren()) do
			if m ~= state.char and m:IsA("Model") and m:GetAttribute("Fighter") then
				local r = m:FindFirstChild("HumanoidRootPart")
				local h = m:FindFirstChildOfClass("Humanoid")
				if r and h and h.Health > 0 and not m:GetAttribute("Invisible") then
					local d = (r.Position - pos).Magnitude
					if d <= range then out[#out + 1] = { model = m, root = r, dist = d } end
				end
			end
		end
	end
	scan(workspace)
	scan(workspace:FindFirstChild("Bots"))
	return out
end

local function mouseLocked()
	return UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
end

-- куда целимся: { dir = направление, pos = точка на карте }
function Controller.aim()
	local cam = workspace.CurrentCamera
	if not cam or not alive() then return {} end
	local rootPos = state.root.Position
	local look = Util.flat(cam.CFrame.LookVector, state.root.CFrame.LookVector)
	local pos
	local filter = { state.char }
	local fx = workspace:FindFirstChild("FX")
	if fx then filter[#filter + 1] = fx end
	local lfx = workspace:FindFirstChild("LocalFX")
	if lfx then filter[#filter + 1] = lfx end
	rayParams.FilterDescendantsInstances = filter
	local ray
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		local vs = cam.ViewportSize
		ray = cam:ViewportPointToRay(vs.X / 2, vs.Y * 0.42)
	elseif mouseLocked() then
		local vs = cam.ViewportSize
		ray = cam:ViewportPointToRay(vs.X / 2, vs.Y / 2)
	else
		local m = UserInputService:GetMouseLocation()
		ray = cam:ViewportPointToRay(m.X, m.Y)
	end
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, rayParams)
	pos = hit and hit.Position or (ray.Origin + ray.Direction * 500)
	local dir = look
	-- свободная мышь на ПК: бьём в сторону курсора
	if not mouseLocked() and UserInputService.MouseEnabled then
		dir = Util.flat(pos - rootPos, look)
	end
	-- мягкое наведение: ближайший враг перед нами
	local best, bestScore
	for _, e in ipairs(enemiesNear(rootPos, 16)) do
		local to = Util.flat(e.root.Position - rootPos, dir)
		local dot = to:Dot(dir)
		if dot > 0.6 or e.dist < 5 and dot > 0.1 then
			local score = e.dist - dot * 6
			if not bestScore or score < bestScore then best, bestScore = e, score end
		end
	end
	if best then
		dir = Util.flat(best.root.Position - rootPos, dir)
		if (pos - rootPos).Magnitude > 40 or not hit then pos = best.root.Position end
	end
	return { dir = dir, pos = pos }
end

-- повернуться в сторону удара на короткое время
local function faceFor(dir, t)
	if not dir or not alive() then return end
	state.faceDir = Util.flat(dir, state.root.CFrame.LookVector)
	state.faceUntil = os.clock() + t
	state.hum.AutoRotate = false
	local p = state.root.Position
	state.root.CFrame = CFrame.lookAt(p, p + state.faceDir)
end

---------------------------------------------------------------- M1
local function jumpHeld()
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then return true end
	if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA) then return true end
	if UserInputService.TouchEnabled and state.hum and state.hum.Jump then return true end
	return Controller.touchJump == true
end

function Controller.m1()
	if not free() then return false end
	local cfg = m1Config()
	local now = os.clock()
	if now < state.m1CdEnd then return false end
	if now - state.m1Last < cfg.Interval then return false end
	if now - state.m1Last > cfg.ComboWindow then state.m1Index = 0 end
	state.m1Index = state.m1Index + 1
	state.m1Last = now
	local idx = state.m1Index
	local finisher = idx >= cfg.Count
	local variant = "n"
	local up = jumpHeld()
	local air = state.hum.FloorMaterial == Enum.Material.Air
	if finisher then
		if up then variant = "up" elseif air then variant = "down" end
		state.m1CdEnd = now + cfg.EndLag
		state.m1Index = 0
	end
	state.busyEnd = now + cfg.BusyTime * (finisher and 1.7 or 1)
	local aim = Controller.aim()
	faceFor(aim.dir, finisher and 0.4 or 0.3)
	local style = Characters.get(charId()).M1Style
	local list = Poses.M1[style] or Poses.M1.fists
	local name
	if variant == "up" then name = list[5] elseif variant == "down" then name = list[6] else name = list[idx] end
	Animator.play(state.char, name)
	Effects.swing(state.char, style, idx, variant)
	Action:FireServer("M1", aim, up, air)
	if Controller.onM1 then Controller.onM1(idx) end
	return true
end

function Controller.setM1Held(on)
	state.m1Held = on and true or false
	if on then Controller.m1() end
end

---------------------------------------------------------------- блок
function Controller.setBlock(on)
	on = on and true or false
	state.blockHeld = on
	if on then
		if not alive() or not Controller.enabled then return end
		if attr("Ragdoll") or attr("Stunned") or attr("Rooted") or attr("Busy") then return end
		state.blocking = true
		Animator.localBlock = true
		state.m1Held = false
		Action:FireServer("Block", true)
	elseif state.blocking then
		state.blocking = false
		Animator.localBlock = false
		Action:FireServer("Block", false)
	end
end

---------------------------------------------------------------- рывок
local DASH_CD = { F = "FrontCooldown", B = "BackCooldown", L = "SideCooldown", R = "SideCooldown" }

local function stopDash()
	if state.dashLV then
		state.dashLV:Destroy()
		state.dashLV = nil
	end
	state.dashUntil = 0
	state.dashFace = nil
	if state.hum and os.clock() >= state.faceUntil then state.hum.AutoRotate = true end
end

-- направление по нажатым клавишам относительно камеры
local function dashDirection()
	local cam = workspace.CurrentCamera
	local look = Util.flat(cam and cam.CFrame.LookVector or state.root.CFrame.LookVector, state.root.CFrame.LookVector)
	local right = Vector3.new(-look.Z, 0, look.X)
	local md = state.hum.MoveDirection
	md = Vector3.new(md.X, 0, md.Z)
	if md.Magnitude < 0.2 then
		local fwd = Util.flat(state.root.CFrame.LookVector)
		return "F", fwd, fwd
	end
	md = md.Unit
	local f, r = md:Dot(look), md:Dot(right)
	if math.abs(f) >= math.abs(r) * 0.9 then
		if f >= 0 then return "F", md, md end
		return "B", md, -md
	end
	return (r > 0 and "R" or "L"), md, look
end

function Controller.dash()
	if not free() or attr("Busy") then return false end
	local key, dir, face = dashDirection()
	local now = os.clock()
	if now < Controller.dashReady[key] then
		if Controller.onDenied then Controller.onDenied("dash", key) end
		return false
	end
	Controller.dashReady[key] = now + Config.Dash[DASH_CD[key]]
	-- сброс серии M1 не нужен: рывок можно вставить между ударами
	stopDash()
	local root = state.root
	local att = root:FindFirstChild("ClientDashAtt")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "ClientDashAtt"
		att.Parent = root
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "ClientDash"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * Config.Dash.Speed
	lv.MaxForce = 1e6
	lv.Parent = root
	state.dashLV = lv
	state.dashUntil = now + Config.Dash.Time
	state.dashFace = face
	state.hum.AutoRotate = false
	local p = root.Position
	root.CFrame = CFrame.lookAt(p, p + face)
	Effects.dashFX(state.char, key)
	Action:FireServer("Dash", key, dir)
	if Controller.onDash then Controller.onDash(key) end
	return true
end

---------------------------------------------------------------- приёмы 1–4 и пробуждение
function Controller.slotReady(slot)
	return serverNow() >= (Controller.cds[slot] or 0)
end

function Controller.recastOpen(slot)
	local rc = Controller.recast
	return rc ~= nil and rc.slot == slot and serverNow() <= rc.to + 0.1
end

function Controller.move(slot)
	if not alive() or not Controller.enabled then return false end
	local now = os.clock()
	-- не чаще 8 раз в секунду на кнопку
	if now - (state.lastSend[slot] or 0) < 0.12 then return false end
	local recast = Controller.recastOpen(slot)
	if not recast then
		if not Controller.slotReady(slot) then
			if Controller.onDenied then Controller.onDenied("cooldown", slot) end
			return false
		end
		if attr("Silenced") then
			if Controller.onDenied then Controller.onDenied("silenced", slot) end
			return false
		end
		if not free() then return false end
	end
	state.lastSend[slot] = now
	local aim = Controller.aim()
	if not recast then faceFor(aim.dir, 0.25) end
	Action:FireServer("Move", slot, aim)
	if Controller.onMove then Controller.onMove(slot) end
	return true
end

function Controller.awaken()
	if not alive() or not Controller.enabled then return false end
	if attr("Awakened") then return false end
	if (attr("Meter") or 0) < Config.Awaken.Max then
		if Controller.onDenied then Controller.onDenied("meter") end
		return false
	end
	if not free() then return false end
	Action:FireServer("Awaken")
	return true
end

-- снять всё зажатое (открыли меню, умерли)
function Controller.releaseAll()
	state.m1Held = false
	if state.blocking or state.blockHeld then
		state.blockHeld = true
		Controller.setBlock(false)
	end
	state.blockHeld = false
end

---------------------------------------------------------------- ввод
local MOVE_KEYS = {}
for i, k in ipairs(Config.Keys.Moves) do MOVE_KEYS[k] = i end
local PAD_MOVES = { [Enum.KeyCode.ButtonX] = 1, [Enum.KeyCode.ButtonY] = 2, [Enum.KeyCode.ButtonR1] = 3, [Enum.KeyCode.ButtonL1] = 4 }
local NUMPAD = { [Enum.KeyCode.KeypadOne] = 1, [Enum.KeyCode.KeypadTwo] = 2, [Enum.KeyCode.KeypadThree] = 3, [Enum.KeyCode.KeypadFour] = 4 }

UserInputService.InputBegan:Connect(function(input, processed)
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 then
		if processed then return end
		Controller.setM1Held(true)
		return
	end
	if processed then return end
	local k = input.KeyCode
	if k == Config.Keys.Block or k == Enum.KeyCode.ButtonL2 then
		Controller.setBlock(true)
	elseif k == Config.Keys.Dash or k == Enum.KeyCode.ButtonB then
		Controller.dash()
	elseif k == Config.Keys.Awaken or k == Enum.KeyCode.DPadUp then
		Controller.awaken()
	elseif k == Enum.KeyCode.ButtonR2 then
		Controller.setM1Held(true)
	elseif MOVE_KEYS[k] or NUMPAD[k] or PAD_MOVES[k] then
		Controller.move(MOVE_KEYS[k] or NUMPAD[k] or PAD_MOVES[k])
	end
end)

UserInputService.InputEnded:Connect(function(input)
	local t = input.UserInputType
	local k = input.KeyCode
	if t == Enum.UserInputType.MouseButton1 or k == Enum.KeyCode.ButtonR2 then
		state.m1Held = false
	elseif k == Config.Keys.Block or k == Enum.KeyCode.ButtonL2 then
		Controller.setBlock(false)
	end
end)

UserInputService.WindowFocusReleased:Connect(function()
	Controller.releaseAll()
end)

---------------------------------------------------------------- кадр
RunService.RenderStepped:Connect(function()
	if not alive() then return end
	local now = os.clock()
	-- зажатая ЛКМ — серия продолжается сама
	if state.m1Held and not state.blocking then Controller.m1() end
	-- блок: если зажат, но сервер ещё не дал (были оглушены) — пробуем снова
	if state.blockHeld and not state.blocking then Controller.setBlock(true) end
	if state.blocking and (attr("Ragdoll") or attr("Stunned")) and not attr("Blocking") then
		-- пробили блок или оглушили: отпускаем, игрок нажмёт снова
		state.blocking = false
		Animator.localBlock = false
	end
	-- рывок
	if state.dashLV then
		if now >= state.dashUntil or attr("Ragdoll") or attr("Stunned") then
			stopDash()
		elseif state.dashFace then
			local p = state.root.Position
			state.root.CFrame = CFrame.lookAt(p, p + state.dashFace)
		end
	end
	-- поворот к цели удара
	if state.faceDir then
		if now < state.faceUntil and not attr("Ragdoll") then
			if not state.dashLV then
				local p = state.root.Position
				local cur = Util.flat(state.root.CFrame.LookVector)
				local d = cur:Lerp(state.faceDir, 0.5)
				if d.Magnitude > 0.05 then state.root.CFrame = CFrame.lookAt(p, p + d.Unit) end
			end
		else
			state.faceDir = nil
			if not state.dashLV then state.hum.AutoRotate = true end
		end
	end
end)

local function bind(char)
	state.char = char
	state.hum = char:WaitForChild("Humanoid", 10)
	state.root = char:WaitForChild("HumanoidRootPart", 10)
	state.m1Index, state.m1Last, state.m1CdEnd, state.busyEnd = 0, -100, 0, 0
	state.blocking, state.m1Held = false, false
	state.faceDir, state.dashLV, state.dashUntil = nil, nil, 0
	Animator.local_model = char
	Animator.localBlock = false
	Controller.recast = nil
	for k in pairs(Controller.dashReady) do Controller.dashReady[k] = 0 end
	if state.hum then
		state.hum.Died:Connect(function()
			if state.char == char then Controller.releaseAll() end
		end)
	end
end

player.CharacterAdded:Connect(bind)
if player.Character then task.spawn(bind, player.Character) end

return Controller
