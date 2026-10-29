-- Процедурный аниматор всех бойцов (игроки, боты, манекены) на этом клиенте.
-- База: стойка/бег/прыжок/блок/оглушение; поверх — анимация приёма (Poses.Anims) и «откид» при попадании.
-- Позы переводятся в Motor6D.Transform каждый кадр (RunService.PreSimulation).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Poses = require(Shared.Poses)
local Rig = require(Shared.Rig)
local Characters = require(Shared.Characters)

local Animator = {}
local recs = {}        -- model -> запись
Animator.recs = recs
Animator.local_model = nil
Animator.localBlock = false

local JOINTS = Poses.JOINTS
local BASE = Poses.BaseVals
local MAXDIST = 320

local function newVals()
	local t = {}
	for _, j in ipairs(JOINTS) do t[j] = { 0, 0, 0, 0, 0, 0 } end
	return t
end

local function copyInto(dst, src)
	for _, j in ipairs(JOINTS) do
		local d, s = dst[j], src[j]
		for i = 1, 6 do d[i] = s[i] end
	end
end

-- dst = dst*(1-w) + src*w  (только суставы src)
local function blend(dst, src, w)
	if w <= 0 then return end
	for j, s in pairs(src) do
		local d = dst[j]
		if d then
			for i = 1, 6 do d[i] = d[i] + (s[i] - d[i]) * w end
		end
	end
end

local function addScaled(dst, src, k)
	if k == 0 then return end
	for j, s in pairs(src) do
		local d = dst[j]
		if d then for i = 1, 6 do d[i] = d[i] + s[i] * k end end
	end
end

local function approach(cur, target, rate, dt)
	return cur + (target - cur) * math.min(1, rate * dt)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function getRec(model)
	local r = recs[model]
	if r then return r end
	local root = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return nil end
	local motors, rot0 = Rig.find(model)
	if not motors.T then return nil end
	r = {
		model = model, root = root, hum = hum, motors = motors, rot0 = rot0,
		vals = newVals(), base = newVals(), runVals = newVals(), tmp = {},
		phase = 0, blockW = 0, stunW = 0, airW = 0, combatW = 0, moveW = 0, rootedW = 0,
		action = nil, flinch = nil, freezeUntil = 0, lastCombat = -100, t = 0,
		airborne = false, airCheck = 0,
	}
	recs[model] = r
	return r
end

function Animator.track(model)
	return getRec(model)
end

-- проиграть анимацию приёма
function Animator.play(model, name, speed)
	local anim = Poses.get(name)
	if not anim then return end
	local r = getRec(model)
	if not r then return end
	-- плавный переход: текущая поза — стартовая точка
	r.action = { anim = anim, name = name, t = 0, speed = speed or 1, w = 0, out = false, outW = 1 }
	r.lastCombat = os.clock()
	r.lastPlay = { name = name, at = os.clock() }
end

function Animator.stop(model)
	local r = recs[model]
	if r and r.action and not r.action.out then
		r.action.out = true
		r.action.outW = r.action.w
	end
end

-- недавно уже запущена такая анимация (предсказание на своём клиенте)
function Animator.recentlyPlayed(model, name, window)
	local r = recs[model]
	return r and r.lastPlay and r.lastPlay.name == name and os.clock() - r.lastPlay.at < (window or 0.35)
end

function Animator.flinch(model, heavy)
	local r = getRec(model)
	if not r then return end
	r.flinch = { t = 0, kind = heavy and "heavy" or "light", side = math.random() < 0.5 and -1 or 1 }
	r.lastCombat = os.clock()
end

-- стоп-кадр при сильном ударе
function Animator.freeze(model, t)
	local r = recs[model]
	if r then r.freezeUntil = math.max(r.freezeUntil, os.clock() + t) end
end

function Animator.combat(model)
	local r = recs[model]
	if r then r.lastCombat = os.clock() end
end

---------------------------------------------------------------- бег
local function runPose(r, out, amp, style, phase, back)
	local s = math.sin(phase)
	local c = math.cos(phase)
	local bob = math.abs(c)
	local dir = back and -1 or 1
	local T, H, RA, LA, RL, LL = out.T, out.H, out.RA, out.LA, out.RL, out.LL
	T[1], T[2], T[3], T[4], T[5], T[6] = (back and -4 or 9) * amp, 7 * s * amp * dir, 0, 0, -0.18 * amp + 0.2 * bob * amp, 0
	H[1], H[2], H[3] = (back and 2 or -5) * amp, -6 * s * amp * dir, 0
	H[4], H[5], H[6] = 0, 0, 0
	local arm = 48 * amp
	if style == "ninja" then
		RA[1], RA[2], RA[3] = -62, 0, 14
		LA[1], LA[2], LA[3] = -62, 0, 14
		T[1] = 22 * amp
		H[1] = -14 * amp
	elseif style == "sword" then
		RA[1], RA[2], RA[3] = 30 - 10 * s * amp, 0, 8
		LA[1], LA[2], LA[3] = arm * s, 0, 7
	else
		RA[1], RA[2], RA[3] = -arm * s, 0, 7
		LA[1], LA[2], LA[3] = arm * s, 0, 7
	end
	RA[4], RA[5], RA[6] = 0, 0, 0
	LA[4], LA[5], LA[6] = 0, 0, 0
	RL[1], RL[2], RL[3], RL[4], RL[5], RL[6] = 46 * s * amp * dir, 0, 2, 0, 0, 0
	LL[1], LL[2], LL[3], LL[4], LL[5], LL[6] = -46 * s * amp * dir, 0, 2, 0, 0, 0
end

local RUN_STYLE = { Thunderer = "ninja", ShadowCaller = "ninja", CrimsonBlade = "sword" }

---------------------------------------------------------------- кадр
local function updateRec(r, dt, now, camPos)
	local model, root, hum = r.model, r.root, r.hum
	if not model.Parent or not root.Parent then return false end
	if model:GetAttribute("Ragdoll") or hum.Health <= 0 then
		r.action = nil
		return true
	end
	if camPos and (root.Position - camPos).Magnitude > MAXDIST then return true end
	local frozen = now < r.freezeUntil
	local adt = frozen and 0 or dt
	r.t = r.t + adt
	local charId = model:GetAttribute("Char") or "StormFist"
	local def = Characters.Defs[charId]
	local style = def and def.M1Style or "fists"
	if charId == "Dummy" then style = "stand" end

	-- движение
	local vel = root.AssemblyLinearVelocity
	local cf = root.CFrame
	local fwd = vel:Dot(cf.LookVector)
	local side = vel:Dot(cf.RightVector)
	local hs = math.sqrt(fwd * fwd + side * side)
	-- в воздухе?
	r.airCheck = r.airCheck - dt
	if r.airCheck <= 0 then
		r.airCheck = 0.06
		local map = workspace:FindFirstChild("Map")
		if map then
			rayParams.FilterDescendantsInstances = { map }
			local hit = workspace:Raycast(root.Position, Vector3.new(0, -4.2, 0), rayParams)
			r.airborne = hit == nil
		end
	end
	local blocking = model:GetAttribute("Blocking") or (model == Animator.local_model and Animator.localBlock)
	local stunned = model:GetAttribute("Stunned")
	local rooted = model:GetAttribute("Rooted")
	local guardBroken = model:GetAttribute("GuardBroken")
	r.blockW = approach(r.blockW, blocking and 1 or 0, 22, dt)
	r.stunW = approach(r.stunW, stunned and 1 or 0, 12, dt)
	r.rootedW = approach(r.rootedW, rooted and 1 or 0, 10, dt)
	r.airW = approach(r.airW, r.airborne and 1 or 0, 10, dt)
	local inCombat = (os.clock() - r.lastCombat) < 6 or model:GetAttribute("Awakened")
	r.combatW = approach(r.combatW, inCombat and 1 or 0, 3, dt)
	r.moveW = approach(r.moveW, math.clamp(hs / 14, 0, 1), 10, dt)

	-- база: спокойная стойка -> боевая
	local vals = r.vals
	local stanceName = Poses.StanceOf[style] or "fists"
	if style == "stand" then stanceName = "stand" end
	copyInto(vals, BASE.stand)
	if stanceName ~= "stand" then blend(vals, BASE[stanceName], r.combatW) end
	-- дыхание
	local br = math.sin(r.t * 2.1)
	vals.T[5] = vals.T[5] + 0.03 * br
	vals.RA[1] = vals.RA[1] + 1.6 * br
	vals.LA[1] = vals.LA[1] + 1.6 * br
	vals.H[1] = vals.H[1] - 1 * br

	-- бег
	if r.moveW > 0.01 and not r.airborne then
		local stride = 7.2
		r.phase = r.phase + adt * hs / stride * math.pi * 2
		local amp = math.clamp(hs / 20, 0.35, 1.25)
		runPose(r, r.runVals, amp, RUN_STYLE[charId] or "normal", r.phase, fwd < -2)
		blend(vals, r.runVals, r.moveW)
	end
	-- воздух
	if r.airW > 0.01 then
		local vy = vel.Y
		local airPose = vy > 4 and BASE.air_up or BASE.air_down
		blend(vals, airPose, r.airW * 0.85)
	end
	-- блок / оглушение / сковывание
	if r.blockW > 0.01 then blend(vals, style == "sword" and BASE.block_sword or BASE.block, r.blockW) end
	if r.stunW > 0.01 then
		blend(vals, guardBroken and BASE.dizzy or BASE.stun, r.stunW)
		local sway = math.sin(r.t * (guardBroken and 4 or 9))
		vals.T[3] = vals.T[3] + sway * (guardBroken and 8 or 2) * r.stunW
		vals.H[3] = vals.H[3] + sway * (guardBroken and 12 or 3) * r.stunW
	end
	if r.rootedW > 0.01 then blend(vals, BASE.rooted, r.rootedW) end

	-- приём
	local a = r.action
	if a then
		local anim = a.anim
		a.t = a.t + adt * a.speed
		local w
		if a.out then
			a.outW = a.outW - adt / math.max(0.02, anim.fo)
			w = a.outW
			if w <= 0 then
				r.action = nil
				w = 0
			end
		else
			w = math.min(1, a.t / math.max(0.01, anim.fi))
			if not anim.loop and a.t >= anim.d then
				if anim.fo <= 0 then
					r.action = nil
					w = 0
				else
					a.out = true
					a.outW = 1
				end
			end
		end
		a.w = w
		if r.action and w > 0 then
			local tt = anim.loop and a.t or math.min(a.t, anim.d)
			Poses.sample(anim, tt, r.tmp)
			-- только суставы этой анимации
			for j in pairs(anim.mask) do
				local d, s = vals[j], r.tmp[j]
				for i = 1, 6 do d[i] = d[i] + (s[i] - d[i]) * w end
			end
		end
	end

	-- откид при попадании
	local fl = r.flinch
	if fl then
		fl.t = fl.t + adt
		local k
		if fl.t < 0.05 then k = fl.t / 0.05 else k = math.max(0, 1 - (fl.t - 0.05) / 0.28) end
		if k <= 0 then
			r.flinch = nil
		else
			addScaled(vals, Poses.FlinchVals[fl.kind], k)
			vals.T[3] = vals.T[3] + 8 * fl.side * k
		end
	end

	Rig.apply(r.motors, r.rot0, vals)
	return true
end

local started = false
function Animator.start()
	if started then return end
	started = true
	-- новые бойцы появляются в workspace (игроки) и workspace.Bots
	RunService.PreSimulation:Connect(function(dt)
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position
		local now = os.clock()
		for model, r in pairs(recs) do
			local ok, alive = pcall(updateRec, r, dt, now, camPos)
			if not ok then
				warn("[Animator] " .. tostring(alive))
				recs[model] = nil
			elseif not alive then
				recs[model] = nil
			end
		end
	end)
	-- подхватываем всех бойцов
	local function scan(container)
		for _, m in ipairs(container:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("Fighter") then getRec(m) end
		end
	end
	local function watch(container)
		container.ChildAdded:Connect(function(m)
			if m:IsA("Model") then
				task.defer(function()
					if m:GetAttribute("Fighter") then getRec(m) end
				end)
				m:GetAttributeChangedSignal("Fighter"):Connect(function()
					if m:GetAttribute("Fighter") then getRec(m) end
				end)
			end
		end)
	end
	scan(workspace)
	watch(workspace)
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		scan(bots)
		watch(bots)
	end
	workspace.ChildAdded:Connect(function(c)
		if c.Name == "Bots" and c:IsA("Folder") then
			scan(c)
			watch(c)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			scan(workspace)
			local b = workspace:FindFirstChild("Bots")
			if b then scan(b) end
		end
	end)
end

return Animator
