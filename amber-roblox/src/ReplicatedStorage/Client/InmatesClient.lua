-- Клиент: оживляет модели заключённых из workspace.Inmates (Inmates/<Key>.animate каждый кадр),
-- звуковые подсказки рядом с ними (шаги, дыхание, смех, стук сердца) и скример-ролик при смерти.
-- InmatesClient.jumpscare(key, model) — 1.5 с: камера Scriptable, локальная копия заключённого
-- бросается в объектив, тряска, звук Jumpscare и UI.jumpscareOverlay; без модели — «помехи» на экране.
-- Модули могут задать: steps = {key, fallback, pitch, volume}, ambient = {key, fallback, every},
-- scare = Color3 (цвет вспышки скримера), cleanup(model, ctx) — когда модель исчезла.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local Rig = require(RS:WaitForChild("Shared"):WaitForChild("Rig"))

local InmatesClient = {}
local ctx, Sound
local defs = {}
local known = {}
local cues = setmetatable({}, { __mode = "k" })
local warned = {}
local heart = nil
local scaring = false
local clockT = 0

local function warnOnce(tag, err)
	if warned[tag] then return end
	warned[tag] = true
	warn("[AA] InmatesClient " .. tag .. ": " .. tostring(err))
end

local function defOf(key)
	if not key or key == "" then return nil end
	local d = defs[key]
	if d ~= nil then return d or nil end
	local f = RS:FindFirstChild("Inmates")
	local ms = f and f:FindFirstChild(key)
	if ms and ms:IsA("ModuleScript") then
		local ok, res = pcall(require, ms)
		if ok and type(res) == "table" then
			defs[key] = res
			return res
		end
		warnOnce("require " .. key, res)
	end
	defs[key] = false
	return nil
end

-- ключ звука, если он задан в Config.Sounds, иначе запасной
local function sk(key, fallback)
	if key and Sound and Sound.id(key) ~= "" then return key end
	if fallback and Sound and Sound.id(fallback) ~= "" then return fallback end
	return nil
end

local function play(key, where, props)
	if not key or not Sound then return end
	pcall(Sound.play, key, where, props)
end

---------------------------------------------------------------- звуки рядом
local function cueModel(model, d, dist, dt)
	local c = cues[model]
	if not c then
		c = { step = 0, amb = 3 + math.random() * 4 }
		cues[model] = c
	end
	local A = Rig.state(model)
	if model:GetAttribute("Lurk") == true or A.anim == "dead" then return end
	local root = A.root
	if not root then return end
	-- шаги по фазе шага
	local st = math.floor(A.phase / math.pi)
	if st ~= c.step then
		c.step = st
		if A.speed > 1.5 and dist < 45 then
			local s = d.steps or {}
			local key = sk(s.key or "Footstep", s.fallback or "Footstep")
			local loud = (A.anim == "chase") and 1.3 or 1
			play(key, root, {
				Volume = (s.volume or 0.5) * loud,
				PlaybackSpeed = (s.pitch or 0.8) * (0.9 + math.random() * 0.2),
				RollOffMinDistance = 6, RollOffMaxDistance = 55,
			})
		end
	end
	-- редкие звуки: дыхание, смех, капли
	c.amb = c.amb - dt
	if c.amb <= 0 then
		local a = d.ambient or {}
		c.amb = (a.every or 8) * (0.6 + math.random() * 0.8)
		if dist < 40 then
			local head = model:FindFirstChild("Head") or root
			play(sk(a.key or "Breath", a.fallback or "Breath"), head, { Volume = 0.45, RollOffMinDistance = 5, RollOffMaxDistance = 40 })
		end
	end
end

local function setHeart(near)
	if not heart then
		if not Sound or Sound.id("Heartbeat") == "" then return end
		local ok, s = pcall(Sound.loop, "Heartbeat", nil, { Volume = 0 })
		if not ok or not s then return end
		heart = s
	end
	local k = math.clamp(1 - near / 40, 0, 1)
	local vol = (k ^ 1.5) * 0.9
	heart.Volume = heart.Volume + (vol - heart.Volume) * 0.1
	heart.PlaybackSpeed = 0.85 + k * 0.6
end

---------------------------------------------------------------- кадр
local function cleanupModel(model)
	known[model] = nil
	cues[model] = nil
	local d = defOf(model:GetAttribute("InmateKey"))
	if d and d.cleanup then
		local ok, err = pcall(d.cleanup, model, ctx)
		if not ok then warnOnce("cleanup", err) end
	end
end

local function defaultAnim(model)
	local A = Rig.state(model)
	Rig.begin(A)
	Rig.basic(A)
	Rig.apply(A)
	Rig.glow(A, (A.anim == "chase") and 1.2 or 0.6)
end

local function step(dt)
	clockT = clockT + dt
	local folder = workspace:FindFirstChild("Inmates")
	local cam = workspace.CurrentCamera
	local me = Players.LocalPlayer
	local myMatch = me and me:GetAttribute("MatchId")
	local camPos = cam and cam.CFrame.Position or Vector3.new()
	local near = math.huge
	if folder then
		for _, model in ipairs(folder:GetChildren()) do
			local key = model:GetAttribute("InmateKey")
			local root = model:IsA("Model") and model.PrimaryPart
			if key and root then
				local dist = (root.Position - camPos).Magnitude
				if dist < 300 then
					known[model] = true
					local d = defOf(key)
					Rig.track(model, dt)
					local ok, err
					if d and d.animate then
						ok, err = pcall(d.animate, model, dt, clockT, ctx)
					else
						ok, err = pcall(defaultAnim, model)
					end
					if not ok then warnOnce("animate " .. key, err) end
					if d then
						local ok2, err2 = pcall(cueModel, model, d, dist, dt)
						if not ok2 then warnOnce("cues", err2) end
					end
					if model:GetAttribute("MatchId") == myMatch and model:GetAttribute("Lurk") ~= true
						and model:GetAttribute("Anim") ~= "dead" and dist < near then
						near = dist
					end
				end
			end
		end
	end
	for model in pairs(known) do
		if not folder or model.Parent ~= folder then cleanupModel(model) end
	end
	local alive = me and me:GetAttribute("Alive") ~= false
	setHeart((alive and not scaring) and near or math.huge)
end

---------------------------------------------------------------- скример
local function staticGui(seconds)
	local me = Players.LocalPlayer
	local pg = me and me:FindFirstChild("PlayerGui")
	if not pg then return end
	local g = Instance.new("ScreenGui")
	g.Name = "AAStatic"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 50
	local bars = {}
	for i = 1, 24 do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.Size = UDim2.new(1, 0, 1 / 24, 1)
		f.Position = UDim2.fromScale(0, (i - 1) / 24)
		f.Parent = g
		bars[i] = f
	end
	g.Parent = pg
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < seconds and g.Parent do
			for _, f in ipairs(bars) do
				local v = math.random()
				f.BackgroundColor3 = Color3.new(v, v, v)
				f.BackgroundTransparency = 0.05 + math.random() * 0.25
			end
			RunService.RenderStepped:Wait()
		end
		g:Destroy()
	end)
end

local function makeClone(d, model)
	local c = nil
	if d and d.build then
		local ok, res = pcall(d.build, ctx)
		if ok and typeof(res) == "Instance" then c = res end
	end
	if not c and model and model.Parent then
		local ok, res = pcall(function() return model:Clone() end)
		if ok then c = res end
	end
	if not c then return nil end
	local root = c.PrimaryPart or c:FindFirstChild("HumanoidRootPart")
	if not root then
		c:Destroy()
		return nil
	end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum then hum:Destroy() end
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = (p == root) or p:GetAttribute("Bike") == true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.LocalTransparencyModifier = 0
		end
	end
	for _, a in ipairs({ "Lurk", "Lift", "Phase", "MatchId", "Stunned" }) do c:SetAttribute(a, nil) end
	c:SetAttribute("Anim", "attack")
	c.Name = "JumpscareClone"
	return c, root
end

local function runScare(key, model)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local d = defOf(key)
	local color = (d and (d.scare or d.color)) or Color3.fromRGB(200, 0, 0)
	local save = { type = cam.CameraType, subject = cam.CameraSubject, fov = cam.FieldOfView, cf = cam.CFrame }
	local clone, root = makeClone(d, model)
	play(sk("Jumpscare", "Stinger"), nil, { Volume = 1 })
	if ctx and ctx.UI then
		local ok = pcall(ctx.UI.jumpscareOverlay, color, 1.2)
		if not ok then pcall(ctx.UI.flash, color, 0, 1.2) end
	end
	if not clone then
		-- нет модели (Телеведущий / помехи): статика на экране и тряска
		play(sk("Static", "EasNoise"), nil, { Volume = 1 })
		staticGui(1.3)
	end
	local head = clone and (clone:FindFirstChild("Head") or root)
	local rel = (clone and head) and root.CFrame:ToObjectSpace(head.CFrame).Position or Vector3.new()
	if clone then clone.Parent = workspace end
	cam.CameraType = Enum.CameraType.Scriptable
	local base = save.cf
	local back = base.Rotation * CFrame.Angles(0, math.pi, 0)
	local t = 0
	local lastSeen = os.clock()
	while t < 1.5 do
		local dt = RunService.RenderStepped:Wait()
		t = t + dt
		lastSeen = os.clock()
		-- рывок к объективу: 0.12 с появление, до 0.45 с — бросок, дальше дрожит у лица
		local dist = 7
		if t > 0.12 then
			local k = math.min(1, (t - 0.12) / 0.33)
			dist = 7 - 5.6 * k * k
		end
		local power = (t < 0.12) and 0.2 or 1
		local shake = CFrame.Angles((math.random() - 0.5) * 0.06 * power, (math.random() - 0.5) * 0.06 * power, (math.random() - 0.5) * 0.04 * power)
		cam.CFrame = base * shake
		cam.FieldOfView = save.fov + (55 - save.fov) * math.min(1, t / 0.4)
		if clone and root and root.Parent then
			local target = (base * CFrame.new(0, -0.1, -dist)).Position
			local jitter = Vector3.new((math.random() - 0.5) * 0.08, (math.random() - 0.5) * 0.08, 0)
			root.CFrame = CFrame.new(target + jitter) * back * CFrame.new(-rel)
			Rig.track(clone, dt)
			if d and d.animate then pcall(d.animate, clone, dt, clockT + t, ctx) end
		end
	end
	if clone then clone:Destroy() end
	cam.FieldOfView = save.fov
	cam.CameraType = save.type
	if save.subject and save.subject.Parent then cam.CameraSubject = save.subject end
	return lastSeen
end

function InmatesClient.jumpscare(key, model)
	if scaring then return end
	scaring = true
	task.spawn(function()
		local cam = workspace.CurrentCamera
		local saveType = cam and cam.CameraType
		local saveSubject = cam and cam.CameraSubject
		local saveFov = cam and cam.FieldOfView
		local ok, err = pcall(runScare, key, model)
		if not ok then
			warnOnce("jumpscare", err)
			if cam then
				cam.CameraType = saveType or Enum.CameraType.Custom
				if saveSubject and saveSubject.Parent then cam.CameraSubject = saveSubject end
				if saveFov then cam.FieldOfView = saveFov end
			end
		end
		scaring = false
	end)
end

function InmatesClient.init(c)
	ctx = c
	Sound = c.Sound
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(step, math.min(dt, 0.1))
		if not ok then warnOnce("step", err) end
	end)
end

return InmatesClient
