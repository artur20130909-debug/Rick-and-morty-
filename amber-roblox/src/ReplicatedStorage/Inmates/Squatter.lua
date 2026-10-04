-- Заключённый 077: ЖИЛЕЦ (The Squatter) — дремлющий.
-- Небритый мужчина в грязной майке и клетчатых пижамных штанах, длинные сальные волосы, руки до колен.
-- ФАЗА 1 (до 2:00): сидит в одном случайном укрытии. Снаружи видны только два глаза в щели дверцы:
--   ярко вспыхивают в луче фонаря, тускло — вблизи. Неуязвим. Кто залезет в ЕГО шкаф — мгновенная смерть.
--   С 1:30 шкаф скребётся и дребезжит, дыхание тяжелеет (предупреждение).
-- ФАЗА 2 (2:00): вырывается («ЭТО МОЙ ДОМ!») и становится быстрым охотником, которого можно застрелить.
-- Атрибуты модели: Lurk (сидит в шкафу), Warn (скоро вырвется), Anim.
local Players = game:GetService("Players")
local Rig = require(script.Parent.Parent:WaitForChild("Shared"):WaitForChild("Rig"))

local SPEED, CHASE, BURST, WARN = 11, 17.5, 26, 25.5
local SAY = Color3.fromRGB(230, 210, 150)

local Squatter = {
	key = "Squatter", num = "077", name = "ЖИЛЕЦ", en = "THE SQUATTER", class = "Класс угрозы: дремлющий",
	color = Color3.fromRGB(200, 184, 144), hp = 450, speed = SPEED, chase = CHASE,
	difficulty = 2, minNight = 3, oneShot = true, reach = 4.5, cooldown = 1.1, sight = 70, dark = 26,
	inspect = 0.35, findChance = 0.2,
	alert = {
		"ПОСТУПАЮТ СООБЩЕНИЯ О НЕЗНАКОМЦЕ, КОТОРЫЙ ПРОНИКАЕТ В ДОМА И ПРЯЧЕТСЯ В ШКАФАХ И КЛАДОВЫХ. НЕБРИТЫЙ, В ГРЯЗНОЙ МАЙКЕ И ПИЖАМНЫХ ШТАНАХ.",
		"КОГДА ЖИЛЬЦЫ ЧУВСТВУЮТ СЕБЯ В БЕЗОПАСНОСТИ, КОГДА ОНИ ЧУВСТВУЮТ СЕБЯ ЗАЩИЩЁННЫМИ, — ОН ПОКИДАЕТ СВОЁ УКРЫТИЕ И НАПАДАЕТ.",
		"ПРОВЕРЯЙТЕ КАЖДОЕ УКРЫТИЕ, ПРЕЖДЕ ЧЕМ ВОЙТИ.",
	},
	tip = "Перед тем как спрятаться, посвети фонарём в щель шкафа: если блеснули глаза — там Жилец, туда нельзя. В 2:00 он вырвется наружу и погонится — прячься в другой шкаф или стреляй.",
	directive = { code = "check_hides", text = "ПРОВЕРЯЙТЕ УКРЫТИЯ" },
	steps = { key = "Footstep", pitch = 0.75, volume = 0.5 },
	ambient = { key = "Breath", every = 6 },
	scare = Color3.fromRGB(255, 200, 90),
}

---------------------------------------------------------------- модель
local SKIN, SKIN_D = "#c6ab92", "#a3876f"
local PLAID, PLAID_R, PLAID_W = "#3c4c82", "#962834", "#e8dcc0"
local HAIR = "#251c12"
local FAB = Enum.Material.Fabric

-- клетка на штанине: поперечные полосы-обручи и продольные полоски
local function plaid(R, limb, w, h, d)
	for _, y in ipairs({ -h * 0.28, h * 0.22 }) do
		Rig.add(R, limb, "Plaid", Vector3.new(w + 0.04, h * 0.14, d + 0.04), CFrame.new(0, y, 0), PLAID_R, FAB)
		Rig.add(R, limb, "Plaid", Vector3.new(w + 0.06, h * 0.03, d + 0.06), CFrame.new(0, y + h * 0.12, 0), PLAID_W, FAB)
	end
	for _, x in ipairs({ -w * 0.22, w * 0.25 }) do
		for _, z in ipairs({ -d / 2 - 0.025, d / 2 + 0.025 }) do
			local p = Rig.add(R, limb, "Plaid", Vector3.new(w * 0.14, h * 0.98, 0.04), CFrame.new(x, 0, z), PLAID_R, FAB)
			p.CastShadow = false
		end
	end
end

function Squatter.build(ctx)
	local R = Rig.build({
		name = "Squatter", footH = 0.3, footL = 1.0, legW = 0.6, hipX = 0.38, legU = 1.45, legL = 1.4,
		ltH = 0.55, utH = 1.55, torsoW = 1.6, torsoD = 0.85, armW = 0.4, armU = 1.5, armL = 1.45, hand = 0.62,
		neck = 0.3, head = Vector3.new(1.15, 1.3, 1.15), hunch = 0.32,
		skin = SKIN, shirt = "#ddd4b8", sleeve = SKIN, forearm = SKIN, pants = PLAID, belt = PLAID,
		shoes = SKIN, hands = SKIN_D, stride = 6.5,
	})
	-- майка: голые плечи, вырез, пятна
	for _, sx in ipairs({ -1, 1 }) do
		Rig.add(R, "UpperTorso", "Shoulder", Vector3.new(0.42, 0.3, 0.8), CFrame.new(sx * 0.6, 0.66, 0), SKIN)
		Rig.add(R, "UpperTorso", "Strap", Vector3.new(0.16, 0.32, 0.88), CFrame.new(sx * 0.3, 0.66, 0), "#cfc5a6", FAB)
	end
	Rig.add(R, "UpperTorso", "Neckline", Vector3.new(0.5, 0.3, 0.06), CFrame.new(0, 0.62, -0.43), SKIN)
	Rig.add(R, "UpperTorso", "Stain", Vector3.new(0.5, 0.42, 0.04), CFrame.new(-0.3, 0.05, -0.44), "#a68d58")
	Rig.add(R, "UpperTorso", "Stain", Vector3.new(0.3, 0.55, 0.04), CFrame.new(0.38, -0.3, -0.44), "#86683f")
	Rig.add(R, "UpperTorso", "Stain", Vector3.new(0.25, 0.2, 0.04), CFrame.new(0.1, -0.6, -0.44), "#5a3a1a")
	Rig.add(R, "UpperTorso", "Stain", Vector3.new(0.6, 0.5, 0.04), CFrame.new(0, -0.2, 0.44), "#9a8250")
	Rig.add(R, "LowerTorso", "Waistband", Vector3.new(1.55, 0.18, 0.86), CFrame.new(0, 0.2, 0), PLAID_W, FAB)
	-- клетчатые пижамные штаны
	for _, side in ipairs({ "Left", "Right" }) do
		plaid(R, side .. "UpperLeg", 0.6, 1.45, 0.6)
		plaid(R, side .. "LowerLeg", 0.55, 1.4, 0.55)
		-- босые ступни с грязными ногтями, костлявые пальцы рук
		for i = -1, 1 do
			Rig.add(R, side .. "Foot", "Nail", Vector3.new(0.12, 0.06, 0.08), CFrame.new(i * 0.17, 0.1, -0.5), "#6e5c48")
		end
		Rig.add(R, side .. "Foot", "Dirt", Vector3.new(0.58, 0.05, 0.9), CFrame.new(0, -0.14, 0), "#4a3a2a")
		for i = -1, 1 do
			Rig.add(R, side .. "Hand", "Finger", Vector3.new(0.09, 0.55, 0.09), CFrame.new(i * 0.12, -0.5, -0.04) * CFrame.Angles(0.15, 0, i * 0.08), SKIN_D)
			Rig.add(R, side .. "Hand", "Nail", Vector3.new(0.09, 0.08, 0.1), CFrame.new(i * 0.12 + i * 0.02, -0.78, -0.08), "#4e3c28")
		end
		Rig.ball(R, side .. "LowerArm", "Elbow", 0.42, CFrame.new(0, 0.72, 0), SKIN)
		Rig.ball(R, side .. "LowerLeg", "Knee", 0.6, CFrame.new(0, 0.7, -0.05), PLAID_R, FAB)
	end
	-- голова: щетина, выпученные глаза, кривая жёлтая ухмылка, сальные патлы
	local H, hz = "Head", -0.58
	Rig.add(R, H, "Stubble", Vector3.new(1.18, 0.5, 1.18), CFrame.new(0, -0.42, 0.0), "#6c625a", Enum.Material.Sand)
	Rig.add(R, H, "Nose", Vector3.new(0.2, 0.36, 0.24), CFrame.new(0.02, 0.0, hz - 0.1) * CFrame.Angles(0, 0, 0.08), SKIN_D)
	for _, sx in ipairs({ -1, 1 }) do
		Rig.add(R, H, "EyeWhite", Vector3.new(0.32, 0.22, 0.05), CFrame.new(sx * 0.28, 0.2, hz - 0.01), "#efe4c8")
		Rig.add(R, H, "Lid", Vector3.new(0.34, 0.07, 0.05), CFrame.new(sx * 0.28, 0.07, hz - 0.015), "#86625a")
		Rig.add(R, H, "Brow", Vector3.new(0.36, 0.1, 0.06), CFrame.new(sx * 0.28, 0.4, hz - 0.02) * CFrame.Angles(0, 0, sx * 0.22), HAIR)
		Rig.add(R, H, "Ear", Vector3.new(0.12, 0.32, 0.22), CFrame.new(sx * 0.62, 0.05, 0.05), SKIN_D)
		-- сальные пряди: по бокам до плеч и пара прядей на лице
		Rig.add(R, H, "Hair", Vector3.new(0.16, 1.6, 0.95), CFrame.new(sx * 0.62, -0.25, 0.1), HAIR, Enum.Material.SmoothPlastic, { Reflectance = 0.05 })
		Rig.add(R, H, "Strand", Vector3.new(0.1, 1.0, 0.05), CFrame.new(sx * 0.42, 0.05, hz - 0.03) * CFrame.Angles(0, 0, sx * 0.06), HAIR)
	end
	Rig.add(R, H, "Pupil", Vector3.new(0.1, 0.12, 0.04), CFrame.new(-0.27, 0.19, hz - 0.04), "#140e0c")
	Rig.add(R, H, "Pupil", Vector3.new(0.1, 0.12, 0.04), CFrame.new(0.3, 0.21, hz - 0.04), "#140e0c")
	-- блики в глазах: именно их видно в щели шкафа
	Rig.eyes(R, H, CFrame.new(0.01, 0.22, hz - 0.07), 0.56, 0.07, "#f2ffb0", { range = 5, brightness = 0.6 })
	Rig.add(R, H, "Mouth", Vector3.new(0.55, 0.11, 0.04), CFrame.new(0.05, -0.32, hz - 0.01) * CFrame.Angles(0, 0, 0.09), "#3a1a14")
	Rig.add(R, H, "Teeth", Vector3.new(0.42, 0.06, 0.045), CFrame.new(0.05, -0.29, hz - 0.015) * CFrame.Angles(0, 0, 0.09), "#d6c46e")
	Rig.add(R, H, "Tooth", Vector3.new(0.06, 0.1, 0.045), CFrame.new(-0.12, -0.34, hz - 0.016), "#b8a050")
	Rig.add(R, H, "HairTop", Vector3.new(1.2, 0.25, 1.2), CFrame.new(0, 0.62, 0.02), HAIR)
	Rig.add(R, H, "HairBack", Vector3.new(1.2, 1.9, 0.25), CFrame.new(0, -0.15, 0.62), HAIR)
	Rig.add(R, H, "Fringe", Vector3.new(1.1, 0.22, 0.12), CFrame.new(0, 0.5, hz - 0.03) * CFrame.Angles(0, 0, -0.06), HAIR)
	Rig.finish(R)
	return R.model
end

---------------------------------------------------------------- поведение (сервер)
local function lurkAt(inm, hide)
	local inside = hide:FindFirstChild("Inside")
	local root = inm.root
	root.Anchored = true
	root.CanCollide = false
	if inside then
		local cf = inside.CFrame
		local p = cf.Position + Vector3.new(0, inm.rootH - 3, 0)
		root.CFrame = CFrame.lookAt(p, p + Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z))
	end
	inm:attr("Lurk", true)
	inm:setAnim("lurk")
end

local function burst(inm)
	local S = inm.mem.sq
	local hide = S.hide
	S.ph = 2
	S.bt = 0
	inm:attr("Lurk", false)
	inm:attr("Warn", false)
	local root = inm.root
	local exit = hide and hide:FindFirstChild("Exit")
	local inside = hide and hide:FindFirstChild("Inside")
	if exit then
		local look = inside and (exit.Position - inside.Position) or root.CFrame.LookVector
		inm:teleport(exit.Position, look)
	end
	root.Anchored = false
	root.CanCollide = true
	pcall(function() root:SetNetworkOwner(nil) end)
	inm:setState("burst")
	inm:setAnim("burst", 1.3)
	local at = inside or root
	inm:sound("DoorBash", at, { Volume = 1, PlaybackSpeed = 0.8 })
	inm:sound("DoorBreak", at, { Volume = 0.8 })
	inm:sound("Growl", root, { Volume = 1 }, "Stinger")
	inm:say("ЭТО МОЙ ДОМ!", SAY, true)
	inm:shakeNear(1.3, 0.5, 40)
end

local function lurkTick(inm, dt)
	local S = inm.mem.sq
	local hide = S.hide
	inm:stop()
	inm.stunUntil = 0
	if not hide or not hide.Parent then
		burst(inm)
		return
	end
	-- залез в ЕГО шкаф
	local HL = inm.ctx and inm.ctx.HouseLogic
	local ok, occ = pcall(HL.occupant, hide)
	if ok and occ then
		inm:sound("DoorBash", hide:FindFirstChild("Inside") or inm.root, { Volume = 1 })
		inm:kill(occ)
		S.k = S.k + 1
	end
	local clock = inm.match.clock or 21
	local inside = hide:FindFirstChild("Inside") or inm.root
	S.br = S.br - dt
	if S.br <= 0 then
		S.br = S.warn and (1.7 + math.random() * 0.5) or (3.3 + math.random() * 1.2)
		inm:sound("Breath", inside, { Volume = S.warn and 0.55 or 0.3, PlaybackSpeed = S.warn and 0.85 or 0.95, RollOffMaxDistance = 30 })
	end
	if S.warn then
		S.rt = S.rt - dt
		if S.rt <= 0 then
			S.rt = 1.3 + math.random() * 1.6
			inm:sound("DoorBash", inside, { Volume = 0.25, PlaybackSpeed = 1.7, RollOffMaxDistance = 45 })
		end
	end
	if clock >= BURST then
		burst(inm)
	elseif clock >= WARN and not S.warn then
		S.warn = true
		inm:attr("Warn", true)
		inm:say("Где-то в доме кто-то тяжело дышит и скребётся изнутри шкафа…", SAY, true)
	end
end

Squatter.server = {
	spawn = function(inm)
		local HL = inm.ctx and inm.ctx.HouseLogic
		local free = {}
		for _, h in ipairs(inm.house.hides or {}) do
			local ok, occ = pcall(HL.occupant, h)
			if h:FindFirstChild("Inside") and not (ok and occ) then table.insert(free, h) end
		end
		inm.mem.sq = { ph = 1, k = 0, br = 1 + math.random() * 2, rt = 1, bt = 0 }
		if #free == 0 then
			inm.mem.sq.ph = 2
			return
		end
		local hide = free[math.random(#free)]
		inm.mem.sq.hide = hide
		inm.mem.lastHide = hide
		inm:setState("lurk")
		lurkAt(inm, hide)
	end,
	tick = function(inm, dt)
		local S = inm.mem.sq
		if S.ph == 1 then
			lurkTick(inm, dt)
			return
		end
		if inm.state == "burst" then
			S.bt = S.bt + dt
			inm:stop()
			if S.bt > 0.45 then
				for _, p in ipairs(inm:players()) do
					if not p.hidden and p.flat < 5 and math.abs(p.dy) < 4 then inm:kill(p.plr) end
				end
			end
			if S.bt > 1.3 then
				local p = inm:nearest(function(q) return not q.hidden end)
				if p then inm:investigate(p.feet) else inm:setState("roam") end
			end
			return
		end
		inm:hunt(dt, { speed = SPEED, chase = CHASE })
	end,
	-- в шкафу неуязвим
	onDamage = function(inm, amount, by)
		if inm.mem.sq and inm.mem.sq.ph == 1 then return false end
	end,
	onStun = function(inm, s)
		if inm.mem.sq and inm.mem.sq.ph == 1 then return false end
	end,
}

---------------------------------------------------------------- анимация (клиент)
local function keepEye(p)
	return p.Name == "Eye"
end

-- насколько луч фонаря игрока попадает в точку (0..1)
local function beam(pos)
	local pl = Players.LocalPlayer
	local cam = workspace.CurrentCamera
	if not pl or not cam or pl:GetAttribute("Flashlight") ~= true then return 0 end
	local to = pos - cam.CFrame.Position
	local d = to.Magnitude
	if d > 45 or d < 0.1 then return 0 end
	local c = to.Unit:Dot(cam.CFrame.LookVector)
	if c < 0.9 then return 0 end
	return math.clamp((c - 0.9) / 0.07, 0, 1) * (1 - d / 60)
end

function Squatter.animate(model, dt, t, ctx)
	local A = Rig.state(model)
	local D = A.data
	local lurk = model:GetAttribute("Lurk") == true
	if lurk then
		-- видно только глаза в щели; вспыхивают в луче фонаря, моргают
		Rig.fade(A, 1, keepEye)
		local head = model:FindFirstChild("Head")
		local k = 0.12
		if head then
			k = math.max(k, 1.3 * beam(head.Position))
			local cam = workspace.CurrentCamera
			if cam then
				local d = (cam.CFrame.Position - head.Position).Magnitude
				if d < 9 then k = math.max(k, 0.25 + 0.35 * (1 - d / 9)) end
			end
		end
		D.k = (D.k or 0) + (k - (D.k or 0)) * math.min(1, dt * 12)
		D.blink = (D.blink or 3) - dt
		if D.blink < -0.13 then D.blink = 2.5 + math.random() * 4 end
		Rig.glow(A, (D.blink < 0) and 0 or D.k)
		Rig.begin(A)
		Rig.idle(A, model:GetAttribute("Warn") and 2.5 or 1, { rate = model:GetAttribute("Warn") and 4 or 1.6, look = 0.2 })
		Rig.rot(A, "Neck", 0.1, 0, 0.18)
		Rig.apply(A)
		return
	end
	if A.fadeA == 1 then Rig.fade(A, 0) end
	Rig.begin(A)
	local anim = Rig.basic(A, { walkRef = 11, walk = { leg = 0.55, arm = 0.35, bob = 0.1, lean = 0.1 } })
	local mv = math.clamp(A.speed / 11, 0, 1.3)
	if anim == "burst" then
		Rig.move(A, "Root", 0, -0.6, 0)
		Rig.rot(A, "Waist", -0.35, 0, 0)
		Rig.rot(A, "Neck", 0.35, 0, 0.1)
		Rig.rot(A, "LeftShoulder", 1.7, 0, -0.45)
		Rig.rot(A, "RightShoulder", 1.7, 0, 0.45)
		Rig.rot(A, "LeftHip", 0.55, 0, 0)
		Rig.rot(A, "RightHip", -0.35, 0, 0)
		Rig.rot(A, "LeftKnee", -0.7, 0, 0)
		Rig.twitch(A, 1, { "Neck", "LeftShoulder", "RightShoulder", "Waist" }, 0.15)
	elseif anim == "chase" then
		-- размашистый бег на полусогнутых, руки болтаются
		local s = math.sin(A.phase)
		Rig.rot(A, "Waist", -0.2, 0, 0)
		Rig.rot(A, "LeftShoulder", 0.4 - s * 0.6, 0, -0.25)
		Rig.rot(A, "RightShoulder", 0.4 + s * 0.6, 0, 0.25)
		Rig.rot(A, "Neck", 0.3, 0, math.sin(t * 7) * 0.12)
		Rig.twitch(A, 0.6, { "Neck", "LeftElbow", "RightElbow" }, 0.4)
	else
		-- шаркающая походка, руки висят, голова подёргивается
		Rig.rot(A, "LeftShoulder", 0.2, 0, -0.05)
		Rig.rot(A, "RightShoulder", 0.2, 0, 0.05)
		Rig.rot(A, "Neck", 0, 0, math.sin(t * 0.9) * 0.15 + ((math.sin(t * 2.7) > 0.95) and 0.25 or 0))
		Rig.twitch(A, 0.35, { "Neck", "LeftWrist", "RightWrist" }, 1.2)
	end
	Rig.rot(A, "Root", 0, 0, math.sin(A.phase) * 0.04 * mv)
	Rig.apply(A)
	Rig.glow(A, (anim == "chase" or anim == "burst") and 1 or 0.35)
end

return Squatter
