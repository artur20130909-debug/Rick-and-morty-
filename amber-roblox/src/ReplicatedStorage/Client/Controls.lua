-- Управление игроком на клиенте:
--  * камера: в доме — от первого лица (LockFirstPerson), в лобби — свободная от третьего;
--    покачивание при ходьбе, расширение обзора (FOV) при беге, выглядывание из-за угла (Q/E);
--  * бег (Shift) с выносливостью, присед (C / Ctrl), шаги по материалу пола;
--  * фонарик (F): локальный прожектор у камеры с лёгким запаздыванием, батарейка садится, на остатке мигает;
--  * предметы: клавиши 1–9 выбирают, клик или кнопка «Исп.» применяет; модель предмета в руке;
--  * смерть: наблюдение за живыми товарищами (←/→, клик или кнопка), возврат при оживлении;
--  * во время экстренного оповещения взгляд тянется к телевизору;
--  * сенсорные кнопки для телефона (ContextActionService).
-- Сервер узнаёт о беге/приседе/фонарике/предметах через Action и сам решает, что из этого следует.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local PPS = game:GetService("ProximityPromptService")

local Controls = {}

local ctx, player, Config, Sound, Net
local Action = nil
local T = 0

local BASE_FOV = 70
local DEATH_DELAY = 1.5       -- после Alive=false (сервер ставит его через 1.5 с скримера) — и только потом наблюдение
local SPRINT_SECONDS = 6.5    -- полный запас выносливости на столько секунд бега
local REGEN_SECONDS = 8       -- и восстанавливается за столько
local REGEN_DELAY = 1.1       -- пауза перед восстановлением
local PRIORITY = Enum.ContextActionPriority.High.Value

---------------------------------------------------------------- помощники
local warned = {}
local function warnOnce(tag, err)
	if warned[tag] then return end
	warned[tag] = true
	warn("[AA] Controls." .. tostring(tag) .. ": " .. tostring(err))
end
local function guarded(tag, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then warnOnce(tag, err) end
	return ok
end
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end
local function approach(a, b, d, rate) return a + (b - a) * (1 - math.exp(-rate * d)) end

-- вызов UI через ctx (модуль пишется параллельно — всё под pcall)
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
local function world(name, ...)
	local W = ctx and ctx.World
	if type(W) ~= "table" or type(W[name]) ~= "function" then return nil end
	local ok, r = pcall(W[name], ...)
	if not ok then
		warnOnce("World." .. name, r)
		return nil
	end
	return r
end
local function action(kind, a, b)
	if not Action then return end
	local ok, err = pcall(function() Action:FireServer(kind, a, b) end)
	if not ok then warnOnce("Action", err) end
end
local function play(key, where, props)
	local ok, s = pcall(Sound.play, key, where, props)
	if ok then return s end
	return nil
end

local function localFolder()
	local f = workspace:FindFirstChild("AA_Local")
	if not f then
		f = Instance.new("Folder")
		f.Name = "AA_Local"
		f.Parent = workspace
	end
	return f
end

---------------------------------------------------------------- состояние
local st = {
	char = nil, hum = nil, root = nil,
	stamina = 100, uiStamina = -1, exhausted = false, lastSprintT = -10,
	sprintHeld = false, sprintToggle = false, sprinting = false,
	crouch = false, crouchOff = 0, jumpOff = false,
	lean = 0, leanL = false, leanR = false,
	light = false, battery = 1, uiBattery = -1, lightToggleT = -10, lowWarned = false,
	equipped = "", equipT = -10, lastUse = -10,
	bob = 0, bobAmp = 0, stepIdx = 0, fov = BASE_FOV,
	dead = false, deadT = 0, deathShown = false, specTarget = nil, specCheck = 0,
	cinematicUntil = 0, alertSince = nil,
	camKey = "", crosshair = nil,
	prompts = {}, promptCount = 0,
}

local function scene()
	local s = world("scene")
	if s then return s end
	return ((player:GetAttribute("MatchId") or 0) ~= 0) and "house" or "lobby"
end
local function phase() return world("phase") or "" end
local function isHidden()
	local H = ctx and ctx.Hide
	if type(H) == "table" and type(H.isHidden) == "function" then
		local ok, r = pcall(H.isHidden)
		if ok then return r and true or false end
	end
	return player:GetAttribute("Hidden") == true
end
local function anyModal() return ui("anyModal") == true end
local function staminaMax()
	local mul = (player:GetAttribute("Class") == "runner") and 1.6 or 1
	return (Config.StaminaMax or 100) * mul
end

---------------------------------------------------------------- фонарик
local FL = { part = nil, spot = nil, spill = nil, rot = nil }
local function ensureFlashlight()
	if FL.part and FL.part.Parent then return end
	local p = Instance.new("Part")
	p.Name = "AA_Flashlight"
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	pcall(function()
		p.CanQuery = false
		p.CanTouch = false
	end)
	local s = Instance.new("SpotLight")
	s.Name = "Beam"
	s.Face = Enum.NormalId.Front
	s.Angle = 45
	s.Range = 55
	s.Brightness = 0
	s.Color = rgb(255, 241, 214)
	s.Shadows = true
	s.Enabled = false
	s.Parent = p
	local pl = Instance.new("PointLight")
	pl.Name = "Spill"
	pl.Range = 7
	pl.Brightness = 0
	pl.Color = rgb(255, 236, 205)
	pl.Shadows = false
	pl.Enabled = false
	pl.Parent = p
	p.Parent = localFolder()
	FL.part, FL.spot, FL.spill, FL.rot = p, s, pl, nil
end

local function flashlightAllowed()
	return scene() == "house" and not st.dead and not isHidden()
end

local function setFlashlight(on, silent)
	on = on and true or false
	if on and not flashlightAllowed() then on = false end
	if on and st.battery <= 0 then
		if not silent then
			play("FlashlightClick", nil, { Volume = 0.5 })
			ui("toast", "Батарейка села — купи новую в гараже", rgb(255, 190, 80))
		end
		on = false
	end
	if st.light == on then return end
	st.light = on
	st.lightToggleT = T
	if not silent then play("FlashlightClick", nil, { Volume = 0.5 }) end
	action("flashlight", on)
	ui("setFlashlight", on)
end

local function updateFlashlight(dt, camCF)
	if st.light then
		if not flashlightAllowed() then
			setFlashlight(false, true)
		else
			local secs = (Config.FlashlightSeconds or 150) * ((player:GetAttribute("Class") == "electric") and 2 or 1)
			st.battery = math.max(0, st.battery - dt / secs)
			if st.battery < 0.15 and not st.lowWarned then
				st.lowWarned = true
				ui("toast", "Фонарик садится", rgb(255, 190, 80))
			end
			if st.battery <= 0 then
				setFlashlight(false)
				ui("toast", "Батарейка села", rgb(255, 120, 80))
			end
		end
	end
	if math.abs(st.battery - st.uiBattery) >= 0.005 then
		st.uiBattery = st.battery
		ui("setBattery", st.battery)
	end
	ensureFlashlight()
	if not st.light then
		if FL.spot.Enabled then
			FL.spot.Enabled = false
			FL.spill.Enabled = false
		end
		FL.rot = nil
		return
	end
	-- фонарь в левой руке; луч смотрит в точку перед взглядом и чуть запаздывает при повороте
	local pos = (camCF * CFrame.new(-0.55, -0.55, -1.55)).Position
	local aim = camCF.Position + camCF.LookVector * 30
	local want = CFrame.lookAt(pos, aim)
	want = want - want.Position
	if FL.rot then
		FL.rot = FL.rot:Lerp(want, 1 - math.exp(-16 * dt))
	else
		FL.rot = want
	end
	FL.part.CFrame = CFrame.new(pos) * FL.rot
	local b = 2.6
	if st.battery < 0.15 then
		local k = st.battery / 0.15
		if math.random() < 0.06 + (1 - k) * 0.14 then
			b = b * (0.05 + math.random() * 0.25)
		else
			b = b * (0.55 + 0.45 * k)
		end
	end
	FL.spot.Enabled = true
	FL.spill.Enabled = true
	FL.spot.Brightness = b
	FL.spill.Brightness = b * 0.12
end

---------------------------------------------------------------- модель предмета в руке
local VM = { model = nil, key = "", torch = nil, rot = nil, kick = 0, sprint = 0, muzzle = nil }
local MAT = Enum.Material

local function vpart(m, name, size, cf, color, material, cylinder, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or MAT.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	pcall(function()
		p.CanQuery = false
		p.CanTouch = false
	end)
	if cylinder then p.Shape = Enum.PartType.Cylinder end
	if props then
		for k, v in pairs(props) do p[k] = v end
	end
	p.Parent = m
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))   -- цилиндр стоймя
local FORWARD = CFrame.Angles(0, math.rad(90), 0)   -- цилиндр вдоль взгляда

local function itemModel(key)
	local m = Instance.new("Model")
	m.Name = "AA_Viewmodel"
	local grip = vpart(m, "Grip", Vector3.new(0.1, 0.1, 0.1), CFrame.new(), Color3.new(1, 1, 1), nil, false, { Transparency = 1 })
	m.PrimaryPart = grip
	VM.muzzle = nil
	if key == "shotgun" then
		local barrel = vpart(m, "Barrel", Vector3.new(0.16, 0.16, 2.6), CFrame.new(0, 0.14, -1.1), rgb(40, 40, 44), MAT.Metal)
		vpart(m, "Tube", Vector3.new(0.12, 0.12, 2.0), CFrame.new(0, -0.03, -0.85), rgb(52, 52, 56), MAT.Metal)
		vpart(m, "Pump", Vector3.new(0.22, 0.2, 0.6), CFrame.new(0, -0.03, -1.05), rgb(96, 62, 36), MAT.Wood)
		vpart(m, "Receiver", Vector3.new(0.24, 0.32, 0.7), CFrame.new(0, 0.06, 0.2), rgb(34, 34, 38), MAT.Metal)
		vpart(m, "Stock", Vector3.new(0.22, 0.34, 0.9), CFrame.new(0, -0.08, 0.95) * CFrame.Angles(math.rad(-8), 0, 0), rgb(112, 72, 40), MAT.Wood)
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(0, 0, -1.4)
		a.Parent = barrel
		local fl = Instance.new("PointLight")
		fl.Range = 16
		fl.Brightness = 6
		fl.Color = rgb(255, 190, 90)
		fl.Enabled = false
		fl.Parent = a
		VM.muzzle = fl
	elseif key == "battery" then
		for i = -1, 1, 2 do
			local x = i * 0.16
			vpart(m, "Cell", Vector3.new(0.32, 0.28, 0.28), CFrame.new(x, 0.15, 0) * UPRIGHT, rgb(232, 182, 30), MAT.SmoothPlastic, true)
			vpart(m, "CellBottom", Vector3.new(0.3, 0.285, 0.285), CFrame.new(x, -0.15, 0) * UPRIGHT, rgb(24, 24, 26), MAT.SmoothPlastic, true)
			vpart(m, "Tip", Vector3.new(0.06, 0.1, 0.1), CFrame.new(x, 0.34, 0) * UPRIGHT, rgb(200, 150, 90), MAT.Metal, true)
		end
	elseif key == "medkit" then
		vpart(m, "Box", Vector3.new(0.8, 0.55, 0.32), CFrame.new(), rgb(236, 236, 232))
		vpart(m, "CrossH", Vector3.new(0.36, 0.11, 0.02), CFrame.new(0, 0, -0.17), rgb(200, 20, 30))
		vpart(m, "CrossV", Vector3.new(0.11, 0.36, 0.02), CFrame.new(0, 0, -0.17), rgb(200, 20, 30))
		vpart(m, "Handle", Vector3.new(0.3, 0.06, 0.06), CFrame.new(0, 0.31, 0), rgb(90, 90, 96))
	elseif key == "pepper" then
		vpart(m, "Can", Vector3.new(0.75, 0.24, 0.24), CFrame.new() * UPRIGHT, rgb(196, 24, 24), MAT.SmoothPlastic, true)
		vpart(m, "Label", Vector3.new(0.22, 0.245, 0.245), CFrame.new(0, -0.05, 0) * UPRIGHT, rgb(240, 240, 236), MAT.SmoothPlastic, true)
		vpart(m, "Cap", Vector3.new(0.12, 0.18, 0.18), CFrame.new(0, 0.43, 0) * UPRIGHT, rgb(20, 20, 22), MAT.SmoothPlastic, true)
		vpart(m, "Nozzle", Vector3.new(0.06, 0.06, 0.08), CFrame.new(0, 0.45, -0.1), rgb(240, 240, 240))
	elseif key == "beartrap" then
		local tilt = CFrame.Angles(math.rad(55), 0, 0)
		vpart(m, "Base", Vector3.new(0.08, 0.9, 0.9), tilt * UPRIGHT, rgb(62, 62, 66), MAT.Metal, true)
		vpart(m, "Plate", Vector3.new(0.1, 0.3, 0.3), tilt * CFrame.new(0, 0.04, 0) * UPRIGHT, rgb(110, 100, 80), MAT.Metal, true)
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			vpart(m, "Tooth", Vector3.new(0.07, 0.14, 0.05), tilt * CFrame.new(math.cos(a) * 0.4, 0.08, math.sin(a) * 0.4) * CFrame.Angles(0, -a, 0), rgb(150, 150, 156), MAT.Metal)
		end
	elseif key == "motion" then
		vpart(m, "Base", Vector3.new(0.42, 0.14, 0.42), CFrame.new(0, -0.2, 0), rgb(86, 86, 92))
		vpart(m, "Neck", Vector3.new(0.18, 0.08, 0.08), CFrame.new(0, -0.05, 0) * UPRIGHT, rgb(60, 60, 64), MAT.Metal, true)
		vpart(m, "Dome", Vector3.new(0.34, 0.34, 0.34), CFrame.new(0, 0.12, 0), rgb(255, 240, 200), MAT.SmoothPlastic, false, { Shape = Enum.PartType.Ball })
		vpart(m, "Sensor", Vector3.new(0.1, 0.1, 0.1), CFrame.new(0, -0.18, -0.21), rgb(255, 40, 40), MAT.Neon, false, { Shape = Enum.PartType.Ball })
	elseif key == "stun" then
		vpart(m, "Body", Vector3.new(0.22, 0.34, 0.75), CFrame.new(), rgb(22, 22, 24))
		vpart(m, "Stripe", Vector3.new(0.23, 0.08, 0.5), CFrame.new(0, 0.06, 0.05), rgb(255, 210, 30))
		vpart(m, "ProngL", Vector3.new(0.04, 0.04, 0.14), CFrame.new(-0.06, 0.08, -0.44), rgb(190, 190, 196), MAT.Metal)
		vpart(m, "ProngR", Vector3.new(0.04, 0.04, 0.14), CFrame.new(0.06, 0.08, -0.44), rgb(190, 190, 196), MAT.Metal)
		vpart(m, "Spark", Vector3.new(0.1, 0.02, 0.02), CFrame.new(0, 0.08, -0.5), rgb(120, 180, 255), MAT.Neon)
	elseif key == "defib" then
		for i = 0, 1 do
			local x = (i == 0) and -0.4 or 0.15
			vpart(m, "Handle", Vector3.new(0.4, 0.14, 0.14), CFrame.new(x, -0.1, 0.05) * UPRIGHT, rgb(200, 30, 30), MAT.SmoothPlastic, true)
			vpart(m, "Pad", Vector3.new(0.06, 0.42, 0.42), CFrame.new(x, 0.1, -0.12) * CFrame.Angles(math.rad(-70), 0, 0) * UPRIGHT, rgb(170, 170, 176), MAT.Metal, true)
		end
	elseif key == "shells" then
		for i = -1, 1 do
			vpart(m, "Shell", Vector3.new(0.42, 0.13, 0.13), CFrame.new(i * 0.15, 0.05, 0) * UPRIGHT, rgb(190, 30, 30), MAT.SmoothPlastic, true)
			vpart(m, "Brass", Vector3.new(0.1, 0.135, 0.135), CFrame.new(i * 0.15, -0.2, 0) * UPRIGHT, rgb(212, 170, 80), MAT.Metal, true)
		end
	else
		-- коробка из магазина для всего остального
		vpart(m, "Box", Vector3.new(0.5, 0.5, 0.5), CFrame.new(), rgb(168, 126, 82), MAT.SmoothPlastic)
		vpart(m, "Tape", Vector3.new(0.52, 0.1, 0.52), CFrame.new(0, 0, 0), rgb(214, 196, 150))
	end
	return m
end

local function torchModel()
	local m = Instance.new("Model")
	m.Name = "AA_Torch"
	local grip = vpart(m, "Grip", Vector3.new(0.1, 0.1, 0.1), CFrame.new(), Color3.new(1, 1, 1), nil, false, { Transparency = 1 })
	m.PrimaryPart = grip
	vpart(m, "Body", Vector3.new(0.75, 0.16, 0.16), CFrame.new(0, 0, 0) * FORWARD, rgb(36, 36, 40), MAT.Metal, true)
	vpart(m, "Head", Vector3.new(0.2, 0.25, 0.25), CFrame.new(0, 0, -0.45) * FORWARD, rgb(46, 46, 50), MAT.Metal, true)
	vpart(m, "Lens", Vector3.new(0.03, 0.21, 0.21), CFrame.new(0, 0, -0.56) * FORWARD, rgb(255, 244, 214), MAT.Neon, true)
	vpart(m, "Switch", Vector3.new(0.06, 0.04, 0.1), CFrame.new(0, 0.09, -0.05), rgb(200, 40, 40))
	return m
end

local function clearViewmodel()
	if VM.model then pcall(function() VM.model:Destroy() end) end
	VM.model = nil
	VM.key = ""
	VM.muzzle = nil
end

local function updateViewmodel(dt, cam)
	local camCF = cam.CFrame
	local show = st.camKey == "first" and scene() == "house" and not st.dead and not isHidden()
	local key = show and st.equipped or ""
	if key ~= VM.key then
		clearViewmodel()
		if key ~= "" then
			VM.model = itemModel(key)
			VM.model.Parent = cam
		end
		VM.key = key
	end
	local wantTorch = show and st.light
	if wantTorch and not VM.torch then
		VM.torch = torchModel()
		VM.torch.Parent = cam
	elseif not wantTorch and VM.torch then
		pcall(function() VM.torch:Destroy() end)
		VM.torch = nil
	end
	if not VM.model and not VM.torch then
		VM.rot = nil
		return
	end
	-- лёгкое запаздывание за поворотом камеры, покачивание шагов, отдача
	local camRot = camCF - camCF.Position
	if VM.rot then
		VM.rot = VM.rot:Lerp(camRot, 1 - math.exp(-18 * dt))
	else
		VM.rot = camRot
	end
	local base = CFrame.new(camCF.Position) * VM.rot
	local bob = CFrame.new(math.sin(st.bob) * 0.04 * st.bobAmp, -math.abs(math.cos(st.bob)) * 0.05 * st.bobAmp + math.sin(T * 1.6) * 0.01, 0)
	VM.kick = VM.kick * math.exp(-9 * dt)
	VM.sprint = approach(VM.sprint, st.sprinting and 1 or 0, dt, 8)
	local pose = CFrame.Angles(-0.35 * VM.sprint, 0.35 * VM.sprint, 0)
	local kick = CFrame.new(0, 0.02 * VM.kick, 0.3 * VM.kick) * CFrame.Angles(0.35 * VM.kick, 0, 0)
	if VM.model and VM.model.PrimaryPart then
		VM.model:PivotTo(base * CFrame.new(0.85, -0.85, -1.5) * bob * pose * kick)
	end
	if VM.torch and VM.torch.PrimaryPart then
		VM.torch:PivotTo(base * CFrame.new(-0.55, -0.55, -1.0) * bob)
	end
end

---------------------------------------------------------------- предметы
local function hotbar()
	-- порядок слотов берём у UI (он рисует хотбар), чтобы клавиши 1–9 совпадали с картинкой
	local fromUi = ui("hotbarKeys")
	if type(fromUi) == "table" and #fromUi > 0 then return fromUi end
	local list = {}
	local inv = player:FindFirstChild("Inventory")
	if not inv then return list end
	for _, v in ipairs(inv:GetChildren()) do
		if (v:IsA("IntValue") or v:IsA("NumberValue")) and (v.Value or 0) > 0 then
			table.insert(list, v.Name)
		end
	end
	local items = Config.Items or {}
	table.sort(list, function(a, b)
		local oa = items[a] and items[a].order or 1000
		local ob = items[b] and items[b].order or 1000
		if oa ~= ob then return oa < ob end
		return a < b
	end)
	return list
end

local function inList(list, x)
	for _, v in ipairs(list) do
		if v == x then return true end
	end
	return false
end

local function equip(key)
	key = key or ""
	if st.equipped == key then return end
	st.equipped = key
	st.equipT = T
	action("equip", key)
	ui("setSelected", key)
	play("UiClick", nil, { Volume = 0.2 })
end

local function canUseItems()
	return scene() == "house" and not st.dead and not isHidden()
end

local function selectSlot(i)
	if not canUseItems() then return end
	local key = hotbar()[i]
	if not key then return end
	if st.equipped == key then
		equip("")
	else
		equip(key)
	end
end

local function cycleSlot(step)
	if not canUseItems() then return end
	local list = hotbar()
	if #list == 0 then return end
	local idx = 0
	for i, k in ipairs(list) do
		if k == st.equipped then idx = i end
	end
	idx = (idx - 1 + step) % #list + 1
	equip(list[idx])
end

local function useItem()
	if st.equipped == "" or not canUseItems() then return end
	if T - st.lastUse < 0.3 or anyModal() then return end
	st.lastUse = T
	local cam = workspace.CurrentCamera
	action("use", st.equipped, cam.CFrame)
	if st.equipped == "shotgun" then
		VM.kick = 1
		local fl = VM.muzzle
		if fl then
			fl.Enabled = true
			task.delay(0.06, function() pcall(function() fl.Enabled = false end) end)
		end
	else
		VM.kick = 0.35
	end
end

---------------------------------------------------------------- шаги
local STEP = {
	Wood = { 0.95, 1 }, WoodPlanks = { 0.95, 1 },
	Carpet = { 0.8, 0.45 }, Fabric = { 0.8, 0.45 },
	Grass = { 0.85, 0.6 }, LeafyGrass = { 0.85, 0.6 }, Ground = { 0.85, 0.65 }, Mud = { 0.8, 0.6 },
	Sand = { 0.8, 0.5 }, Snow = { 0.8, 0.5 },
	Concrete = { 1.05, 0.9 }, Slate = { 1.05, 0.9 }, Brick = { 1.05, 0.9 }, Cobblestone = { 1.05, 0.9 },
	Pavement = { 1.05, 0.9 }, Asphalt = { 1.0, 0.9 }, Rock = { 1.05, 0.9 }, Plaster = { 1.05, 0.85 },
	Metal = { 1.2, 0.9 }, DiamondPlate = { 1.2, 0.95 }, CorrodedMetal = { 1.15, 0.9 },
	CeramicTiles = { 1.12, 0.85 }, Marble = { 1.12, 0.85 }, Granite = { 1.1, 0.85 }, Glass = { 1.2, 0.8 },
}
local function footstep(hum)
	local mat = "Plastic"
	pcall(function() mat = hum.FloorMaterial.Name end)
	local m = STEP[mat] or { 1, 0.8 }
	local vol = 0.35 * m[2]
	if st.crouch then
		vol = vol * 0.35
	elseif st.sprinting then
		vol = vol * 1.4
	end
	local s = play("Footstep", nil, { Volume = vol, PlaybackSpeed = m[1] * (0.94 + math.random() * 0.12) })
	if s then
		-- стандартный звук — длинная петля шагов; оставляем только один шаг
		task.delay(0.45, function() pcall(function() if s.Parent then s:Destroy() end end) end)
	end
end

---------------------------------------------------------------- выглядывание (Q/E)
local rayParams = nil
local function leanLimit(root, dir)
	if not rayParams then
		rayParams = RaycastParams.new()
		local ok = pcall(function() rayParams.FilterType = Enum.RaycastFilterType.Exclude end)
		if not ok then pcall(function() rayParams.FilterType = Enum.RaycastFilterType.Blacklist end) end
	end
	rayParams.FilterDescendantsInstances = { st.char, localFolder(), workspace.CurrentCamera }
	local origin = root.Position + Vector3.new(0, 1.5 + st.crouchOff, 0)
	local hit = workspace:Raycast(origin, root.CFrame.RightVector * dir * 1.7, rayParams)
	if hit then return clamp((hit.Distance - 0.55) / 1.1, 0, 1) end
	return 1
end

---------------------------------------------------------------- бег, присед, шаги, смещение камеры
local function releaseMoves()
	if st.sprinting then
		st.sprinting = false
		action("sprint", false)
	end
	st.sprintHeld = false
	st.sprintToggle = false
	if st.crouch then
		st.crouch = false
		action("crouch", false)
	end
	st.leanL = false
	st.leanR = false
end

local function toggleCrouch()
	if st.dead or isHidden() then return end
	st.crouch = not st.crouch
	if st.crouch and st.sprinting then
		st.sprinting = false
		action("sprint", false)
	end
	action("crouch", st.crouch)
end

local function moveStep(dt)
	local hum, root = st.hum, st.root
	if not hum or not root or not hum.Parent then return end
	local sc = scene()
	local inHouse = sc == "house"
	local hidden = isHidden()
	local frozen = inHouse and phase() == "alert"
	local moving = hum.MoveDirection.Magnitude > 0.1
	local maxSt = staminaMax()
	local mul = maxSt / (Config.StaminaMax or 100)
	if st.stamina > maxSt then st.stamina = maxSt end

	-- бег и выносливость
	local want = (st.sprintHeld or st.sprintToggle) and moving and not st.crouch and not st.exhausted
		and not st.dead and not hidden and not frozen and st.stamina > 0
	if want then
		st.stamina = math.max(0, st.stamina - dt * (Config.StaminaMax or 100) / SPRINT_SECONDS)
		st.lastSprintT = T
		if st.stamina <= 0 then
			st.exhausted = true
			st.sprintToggle = false
			want = false
			play("Breath", nil, { Volume = 0.45 })
		end
	elseif T - st.lastSprintT > REGEN_DELAY then
		st.stamina = math.min(maxSt, st.stamina + dt * (Config.StaminaMax or 100) * mul / REGEN_SECONDS)
	end
	if st.exhausted and st.stamina >= maxSt * 0.3 then st.exhausted = false end
	if not moving then st.sprintToggle = false end
	if want ~= st.sprinting then
		st.sprinting = want
		action("sprint", want)
	end
	local frac = st.stamina / maxSt
	if math.abs(frac - st.uiStamina) > 0.01 then
		st.uiStamina = frac
		ui("setStamina", frac)
	end

	-- скорость: сервер замораживает во время оповещения, мы тоже держим 0
	local speed = Config.WalkSpeed or 12
	if st.crouch then
		speed = Config.CrouchSpeed or 6
	elseif st.sprinting then
		speed = Config.SprintSpeed or 20
	end
	if frozen or hidden or (inHouse and st.dead) then speed = 0 end
	if math.abs(hum.WalkSpeed - speed) > 0.01 then hum.WalkSpeed = speed end
	local noJump = st.crouch or frozen or hidden or (inHouse and st.dead)
	if noJump ~= st.jumpOff then
		st.jumpOff = noJump
		pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, not noJump) end)
	end

	-- шаги и покачивание
	local vel = root.AssemblyLinearVelocity
	local hs = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local onGround = hum.FloorMaterial ~= Enum.Material.Air
	local amp = 0
	if onGround and hs > 1 and not hidden then
		local sps = clamp(hs * 0.2, 1.4, 3.4) -- шагов в секунду
		st.bob = st.bob + dt * sps * math.pi
		amp = clamp(hs / 12, 0, 1.6)
		if st.crouch then amp = amp * 0.6 end
		local idx = math.floor(st.bob / math.pi)
		if idx ~= st.stepIdx then
			st.stepIdx = idx
			footstep(hum)
		end
	else
		st.stepIdx = math.floor(st.bob / math.pi)
	end
	st.bobAmp = approach(st.bobAmp, amp, dt, 8)

	-- присед и выглядывание
	st.crouchOff = approach(st.crouchOff, st.crouch and -1.6 or 0, dt, 10)
	local leanTarget = 0
	if st.camKey == "first" and not frozen and not st.sprinting then
		leanTarget = (st.leanR and 1 or 0) - (st.leanL and 1 or 0)
		if leanTarget ~= 0 then leanTarget = leanTarget * leanLimit(root, leanTarget) end
	end
	st.lean = approach(st.lean, leanTarget, dt, 9)

	if st.camKey == "first" then
		local bx = math.sin(st.bob) * 0.06 * st.bobAmp
		local by = -math.abs(math.cos(st.bob)) * 0.09 * st.bobAmp + math.sin(T * 1.7) * 0.02
		hum.CameraOffset = Vector3.new(st.lean * 1.1 + bx, st.crouchOff + by, 0)
	elseif hum.CameraOffset.Magnitude > 0.001 then
		hum.CameraOffset = Vector3.new()
	end
end

---------------------------------------------------------------- смерть и наблюдение
local function teammates()
	local my = player:GetAttribute("MatchId") or 0
	local list = {}
	if my == 0 then return list end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and (p:GetAttribute("MatchId") or 0) == my and p:GetAttribute("Alive") ~= false then
			local c = p.Character
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if h and h.Health > 0 then table.insert(list, p) end
		end
	end
	table.sort(list, function(a, b) return a.UserId < b.UserId end)
	return list
end

local function pickSpectate(step)
	local list = teammates()
	if #list == 0 then
		if st.specTarget then ui("setSpectating", nil) end
		st.specTarget = nil
		return
	end
	local idx = 0
	for i, p in ipairs(list) do
		if p == st.specTarget then idx = i end
	end
	if idx == 0 then
		idx = 1
	else
		idx = (idx - 1 + step) % #list + 1
	end
	local changed = list[idx] ~= st.specTarget
	st.specTarget = list[idx]
	if changed then ui("setSpectating", st.specTarget.DisplayName or st.specTarget.Name) end
end

local function setDead(dead)
	if dead == st.dead then return end
	st.dead = dead
	if dead then
		st.deadT = T
		st.deathShown = false
		st.deathPos = st.root and st.root.Position or nil
		setFlashlight(false, true)
		releaseMoves()
		if st.equipped ~= "" then
			st.equipped = ""
			ui("setSelected", "")
		end
	else
		st.specTarget = nil
		st.deathShown = false
		ui("hideDeath")
		ui("setSpectating", nil)
	end
end

local function checkAlive()
	setDead(scene() == "house" and player:GetAttribute("Alive") == false)
end

---------------------------------------------------------------- режим камеры
local function wantedCamKey()
	if T < st.cinematicUntil then return "cinematic" end
	if isHidden() then return "hidden" end
	if scene() == "house" then
		if st.dead then
			if not st.deathShown then return "dying" end
			if st.specTarget then return "spec:" .. tostring(st.specTarget.UserId) end
			return "orbit"
		end
		return "first"
	end
	return "third"
end

local function specHumanoid()
	local c = st.specTarget and st.specTarget.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function applyCamKey(key)
	local cam = workspace.CurrentCamera
	local prev = st.camKey
	st.camKey = key
	if key == "first" then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = 0.5
		if cam.CameraType ~= Enum.CameraType.Custom then cam.CameraType = Enum.CameraType.Custom end
		if st.hum then cam.CameraSubject = st.hum end
	elseif key == "third" then
		player.CameraMode = Enum.CameraMode.Classic
		if cam.CameraType ~= Enum.CameraType.Custom then cam.CameraType = Enum.CameraType.Custom end
		if st.hum then cam.CameraSubject = st.hum end
		if prev ~= "" and prev ~= "third" then
			-- отодвинуть камеру от затылка после вида от первого лица
			player.CameraMinZoomDistance = 9
			task.delay(0.3, function()
				if st.camKey == "third" then player.CameraMinZoomDistance = 0.5 end
			end)
		else
			player.CameraMinZoomDistance = 0.5
		end
	elseif string.sub(key, 1, 5) == "spec:" then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 7
		if cam.CameraType ~= Enum.CameraType.Custom then cam.CameraType = Enum.CameraType.Custom end
		local h = specHumanoid()
		if h then cam.CameraSubject = h end
	elseif key == "orbit" then
		player.CameraMode = Enum.CameraMode.Classic
		cam.CameraType = Enum.CameraType.Scriptable
	end
	local cross = key == "first"
	if cross ~= st.crosshair then
		st.crosshair = cross
		ui("setCrosshair", cross)
	end
end

local function camStep(dt)
	local cam = workspace.CurrentCamera
	local key = wantedCamKey()
	if key ~= st.camKey then applyCamKey(key) end
	if key == "first" then
		-- оповещение: взгляд тянется к телевизору (сначала быстро, потом мягко)
		if phase() == "alert" then
			if not st.alertSince then st.alertSince = T end
			local tv = world("tvPosition")
			if tv then
				local k = (T - st.alertSince < 2) and 5 or 1.2
				local pos = cam.CFrame.Position
				cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(pos, tv), 1 - math.exp(-k * dt))
			end
		else
			st.alertSince = nil
		end
		-- наклон головы при выглядывании и в такт шагам
		local roll = -st.lean * math.rad(8) + math.sin(st.bob) * math.rad(0.35) * st.bobAmp
		if math.abs(roll) > 0.0001 then cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, roll) end
		local fov = BASE_FOV + (st.sprinting and 8 or 0) - (st.crouch and 2 or 0)
		st.fov = approach(st.fov, fov, dt, 6)
		cam.FieldOfView = st.fov
	elseif key == "orbit" then
		-- некого показывать: медленный облёт дома
		local center = st.deathPos or Vector3.new()
		local h = world("house")
		if h then pcall(function() center = h:GetPivot().Position end) end
		local a = T * 0.08
		local eye = center + Vector3.new(math.cos(a) * 70, 40, math.sin(a) * 70)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(eye, center + Vector3.new(0, 8, 0))
	elseif key ~= "hidden" and key ~= "cinematic" and math.abs(st.fov - BASE_FOV) > 0.05 then
		st.fov = approach(st.fov, BASE_FOV, dt, 6)
		cam.FieldOfView = st.fov
	end
end

-- раз в секунду: камера не должна застрять в Scriptable, наблюдение — на живом товарище
local function slowCheck()
	checkAlive()
	local cam = workspace.CurrentCamera
	local key = st.camKey
	if (key == "first" or key == "third" or string.sub(key, 1, 5) == "spec:") and cam.CameraType == Enum.CameraType.Scriptable then
		applyCamKey(key)
	end
	if st.dead and st.deathShown then
		local h = specHumanoid()
		if not h or h.Health <= 0 or (st.specTarget and st.specTarget:GetAttribute("Alive") == false) then
			st.specTarget = nil
			pickSpectate(0)
		elseif st.camKey ~= "orbit" and cam.CameraSubject ~= h then
			cam.CameraSubject = h
		end
	end
	-- выбранный предмет кончился
	if st.equipped ~= "" and T - st.equipT > 1 and not inList(hotbar(), st.equipped) then
		st.equipped = ""
		ui("setSelected", "")
	end
end

local function deathStep()
	if st.dead and not st.deathShown and T - st.deadT >= DEATH_DELAY and T >= st.cinematicUntil then
		st.deathShown = true
		ui("showDeath", "Ты погиб. Дождись рассвета — или пусть товарищ оживит тебя дефибриллятором.")
		pickSpectate(0)
	end
end

---------------------------------------------------------------- ввод: клавиатура, мышь
local NUMKEYS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine] = 9,
}

local function onInputBegan(input, gp)
	local ut = input.UserInputType
	if ut == Enum.UserInputType.MouseButton1 then
		if gp then return end
		if st.dead and st.deathShown then
			pickSpectate(1)
			return
		end
		useItem()
		return
	end
	if gp then return end
	local kc = input.KeyCode
	if kc == Enum.KeyCode.Q then
		st.leanL = true
	elseif kc == Enum.KeyCode.E then
		-- E — ещё и клавиша подсказок: выглядываем, только если рядом нечего нажать
		if st.promptCount == 0 and not anyModal() then st.leanR = true end
	elseif kc == Enum.KeyCode.Left or kc == Enum.KeyCode.Right then
		if st.dead and st.deathShown then pickSpectate((kc == Enum.KeyCode.Left) and -1 or 1) end
	else
		local n = NUMKEYS[kc]
		if n then selectSlot(n) end
	end
end

local function onInputEnded(input)
	local kc = input.KeyCode
	if kc == Enum.KeyCode.Q then
		st.leanL = false
	elseif kc == Enum.KeyCode.E then
		st.leanR = false
	end
end

local function onInputChanged(input, gp)
	if gp or input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
	if st.camKey ~= "first" or anyModal() then return end
	local z = input.Position.Z
	if z > 0 then
		cycleSlot(-1)
	elseif z < 0 then
		cycleSlot(1)
	end
end

---------------------------------------------------------------- сенсорные кнопки и геймпад (ContextActionService)
local bound = {}
local function isBegin(state) return state == Enum.UserInputState.Begin end
local function isTouch(input) return input and input.UserInputType == Enum.UserInputType.Touch end

local HANDLERS = {
	AA_Sprint = function(_, state, input)
		if isTouch(input) then
			if isBegin(state) then st.sprintToggle = not st.sprintToggle end
		elseif isBegin(state) then
			st.sprintHeld = true
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			st.sprintHeld = false
		end
		-- Shift не должен включать «замок мыши»
		return Enum.ContextActionResult.Sink
	end,
	AA_Crouch = function(_, state)
		if isBegin(state) then toggleCrouch() end
		return Enum.ContextActionResult.Sink
	end,
	AA_Light = function(_, state)
		if isBegin(state) then setFlashlight(not st.light) end
		return Enum.ContextActionResult.Sink
	end,
	AA_Use = function(_, state)
		if isBegin(state) then useItem() end
		return Enum.ContextActionResult.Sink
	end,
	AA_Next = function(_, state)
		if isBegin(state) then pickSpectate(1) end
		return Enum.ContextActionResult.Sink
	end,
}
local BIND = {
	AA_Sprint = { title = "Бег", pos = UDim2.new(0.15, 0, 0.55, 0), keys = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 } },
	AA_Crouch = { title = "Присесть", pos = UDim2.new(0.5, 0, 0.2, 0), keys = { Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB } },
	AA_Light = { title = "Фонарь", pos = UDim2.new(0.5, 0, 0.55, 0), keys = { Enum.KeyCode.F, Enum.KeyCode.DPadUp } },
	AA_Use = { title = "Исп.", pos = UDim2.new(0.15, 0, 0.2, 0), keys = { Enum.KeyCode.ButtonR2 } },
	AA_Next = { title = "Далее", pos = UDim2.new(0.5, 0, 0.2, 0), keys = { Enum.KeyCode.ButtonR1 } },
}

local function setBound(name, on)
	if (bound[name] and true or false) == on then return end
	bound[name] = on
	if on then
		local b = BIND[name]
		CAS:BindActionAtPriority(name, HANDLERS[name], true, PRIORITY, (table.unpack or unpack)(b.keys))
		pcall(function() CAS:SetTitle(name, b.title) end)
		pcall(function() CAS:SetPosition(name, b.pos) end)
	else
		pcall(function() CAS:UnbindAction(name) end)
	end
end

local function refreshBindings()
	local sc = scene()
	local hidden = isHidden()
	local alive = not st.dead
	setBound("AA_Sprint", alive and not hidden)
	setBound("AA_Crouch", alive and not hidden)
	setBound("AA_Light", sc == "house" and alive and not hidden)
	setBound("AA_Use", sc == "house" and alive and not hidden and st.equipped ~= "")
	setBound("AA_Next", sc == "house" and st.dead and st.deathShown)
end

---------------------------------------------------------------- персонаж и сцена
local function onCharacter(char)
	st.char = char
	st.hum = nil
	st.root = nil
	st.jumpOff = false
	task.spawn(function()
		local hum = char:WaitForChild("Humanoid", 10)
		local root = char:WaitForChild("HumanoidRootPart", 10)
		if st.char ~= char then return end
		st.hum = hum
		st.root = root
		st.crouch = false
		st.crouchOff = 0
		st.sprinting = false
		st.lean = 0
		st.camKey = "" -- переприменить режим камеры к новому персонажу
		if hum then pcall(function() hum.CameraOffset = Vector3.new() end) end
		-- свои шаги играем сами — стандартный звук бега глушим
		if root then
			local function mute(s)
				if s:IsA("Sound") and s.Name == "Running" then
					s.Volume = 0
					s:GetPropertyChangedSignal("Volume"):Connect(function()
						if s.Volume ~= 0 then s.Volume = 0 end
					end)
				end
			end
			for _, s in ipairs(root:GetChildren()) do mute(s) end
			root.ChildAdded:Connect(mute)
		end
	end)
end

local function onScene(sc, data, prev)
	st.camKey = ""
	if sc ~= "house" then
		setFlashlight(false, true)
		setDead(false)
		releaseMoves()
		if st.equipped ~= "" then
			st.equipped = ""
			ui("setSelected", "")
		end
	end
	if sc == "house" and prev ~= "house" then
		-- новый матч: полная батарейка и выносливость
		st.battery = 1
		st.lowWarned = false
		st.stamina = staminaMax()
		ui("setBattery", 1)
		ui("setFlashlight", false)
	end
	-- после смены сцены камера никогда не остаётся Scriptable
	local cam = workspace.CurrentCamera
	if cam.CameraType == Enum.CameraType.Scriptable and not isHidden() then
		cam.CameraType = Enum.CameraType.Custom
		if st.hum then cam.CameraSubject = st.hum end
	end
end

---------------------------------------------------------------- публичное API
-- батарейка заряжена (Fx "battery")
function Controls.refillBattery()
	st.battery = 1
	st.lowWarned = false
	st.uiBattery = -1
	ui("setBattery", 1)
end
-- кто-то другой (скример) управляет камерой ближайшие seconds секунд
function Controls.cinematic(seconds)
	st.cinematicUntil = math.max(st.cinematicUntil, T + (seconds or 2))
end
function Controls.setFlashlight(on) setFlashlight(on) end
function Controls.flashlightOn() return st.light end
function Controls.battery() return st.battery end
function Controls.stamina() return st.stamina / staminaMax() end
function Controls.equipped() return st.equipped end
function Controls.isSpectating() return st.dead and st.deathShown end
function Controls.recoil(power) VM.kick = math.max(VM.kick, power or 0.5) end

function Controls.init(c)
	ctx = c
	player = c.player or Players.LocalPlayer
	Config = c.Config
	Sound = c.Sound
	Net = c.Net
	st.stamina = staminaMax()

	task.spawn(function()
		local ok, ev = pcall(Net.event, "Action")
		if ok then Action = ev end
	end)
	pcall(function() player.DevEnableMouseLock = false end)

	if player.Character then onCharacter(player.Character) end
	player.CharacterAdded:Connect(onCharacter)

	world("onScene", onScene)
	player:GetAttributeChangedSignal("Alive"):Connect(function() guarded("alive", checkAlive) end)
	player:GetAttributeChangedSignal("Equipped"):Connect(function()
		local v = player:GetAttribute("Equipped") or ""
		if v == st.equipped then return end
		-- свежий локальный выбор важнее запоздалого ответа сервера
		if T - st.equipT < 0.6 then return end
		st.equipped = v
		ui("setSelected", v)
	end)
	player:GetAttributeChangedSignal("Flashlight"):Connect(function()
		-- сервер выключил фонарь (например, заключённый «гасит» свет)
		if player:GetAttribute("Flashlight") == false and st.light and T - st.lightToggleT > 1 then
			st.light = false
			ui("setFlashlight", false)
		end
	end)

	PPS.PromptShown:Connect(function(prompt)
		if not st.prompts[prompt] then
			st.prompts[prompt] = true
			st.promptCount = st.promptCount + 1
		end
	end)
	PPS.PromptHidden:Connect(function(prompt)
		if st.prompts[prompt] then
			st.prompts[prompt] = nil
			st.promptCount = math.max(0, st.promptCount - 1)
		end
	end)

	UIS.InputBegan:Connect(function(input, gp) guarded("inputBegan", onInputBegan, input, gp) end)
	UIS.InputEnded:Connect(function(input) guarded("inputEnded", onInputEnded, input) end)
	UIS.InputChanged:Connect(function(input, gp) guarded("inputChanged", onInputChanged, input, gp) end)

	local slowAcc, bindAcc = 0, 0
	RunService:BindToRenderStep("AA_Move", Enum.RenderPriority.Camera.Value - 1, function(dt)
		T = T + dt
		guarded("move", moveStep, dt)
		guarded("death", deathStep)
		slowAcc = slowAcc + dt
		if slowAcc >= 1 then
			slowAcc = 0
			guarded("slowCheck", slowCheck)
		end
		bindAcc = bindAcc + dt
		if bindAcc >= 0.25 then
			bindAcc = 0
			guarded("bindings", refreshBindings)
		end
	end)
	RunService:BindToRenderStep("AA_Cam", Enum.RenderPriority.Camera.Value + 1, function(dt)
		guarded("camera", camStep, dt)
	end)
	RunService:BindToRenderStep("AA_Follow", Enum.RenderPriority.Last.Value + 5, function(dt)
		local cam = workspace.CurrentCamera
		guarded("flashlight", updateFlashlight, dt, cam.CFrame)
		guarded("viewmodel", updateViewmodel, dt, cam)
	end)
	guarded("bindings", refreshBindings)
	ui("setBattery", st.battery)
	ui("setFlashlight", false)
end

return Controls
