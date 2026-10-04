-- Заключённый 388: ВИСЯЩИЙ (The Hanger) — дремлющий потолочный хищник.
-- Истощённая жёлто-серая фигура с паучьими конечностями и чёрными волосами, свисающими почти до пола.
-- Пробирается в дом (чаще через окно), заползает на потолок и ползёт к засаде: у дверных проёмов,
-- в коридорах, на кухне, на втором этаже. Там ждёт: дышит, скрипит, волосы свисают вниз.
-- Кто ИДЁТ в полный рост прямо под ним — падение сверху и смерть. Пригнувшись можно проскользнуть.
-- Луч фонаря на нём ~0.35 с → шипит и уползает к другой засаде. Выстрел → срывается, визжит
-- и удирает из дома до конца ночи. Промахнулся при падении — 4 с бросается на ближайшего, потом снова наверх.
-- Корень (HumanoidRootPart) всегда на полу; тело поднимается к потолку суставом Root (атрибут Lift).
-- Anim: walk, climb, ceiling (ползёт по потолку), ceilwait (засада), hiss, drop, floor, lunge, fall, flee.
local Players = game:GetService("Players")
local Rig = require(script.Parent.Parent:WaitForChild("Shared"):WaitForChild("Rig"))

local V_WALK, V_CRAWL, V_FAST = 9, 8.5, 19
local UNDER, LAND_R, T_DROP, T_TORCH = 3.3, 4.6, 0.32, 0.35
local CEIL = { climb = true, ceiling = true, ceilwait = true, hiss = true }
local PREF = { Hall = 3, Upstairs = 3, Kitchen = 2, Dining = 2, LivingRoom = 1 }

local Hanger = {
	key = "Hanger", num = "388", name = "ВИСЯЩИЙ", en = "THE HANGER", class = "Класс угрозы: дремлющий",
	color = Color3.fromRGB(189, 182, 140), hp = 300, speed = V_WALK, chase = V_FAST,
	difficulty = 1, minNight = 3, oneShot = true, reach = 4.2, hear = false, sight = 45, dark = 16,
	entry = "Window",
	alert = {
		"ПЕРСОНАЛ ЛЕЧЕБНИЦЫ СООБЩАЕТ: ЗАКЛЮЧЁННЫЙ 388 СНОВА И СНОВА ПИСАЛ НА СТЕНЕ КАМЕРЫ ОДНУ ФРАЗУ — «ПОЛ НЕБЕЗОПАСЕН».",
		"СУБЪЕКТ ЦЕПЛЯЕТСЯ ЗА ПОТОЛОК В КОРИДОРАХ И НА ЛЕСТНИЦАХ. ЕСЛИ ВЫ СЛЫШИТЕ НАД ГОЛОВОЙ КАПАНЬЕ ИЛИ СКРИП — ОСТАНОВИТЕСЬ.",
		"НЕ ПРОХОДИТЕ ПОД ТЕМ, ЧЕГО НЕ МОЖЕТЕ ЧЁТКО РАЗГЛЯДЕТЬ. ДЕРЖИТЕ СВЕТ ВКЛЮЧЁННЫМ. СМОТРИТЕ ВВЕРХ.",
	},
	tip = "Капает и скрипит сверху — посвети фонарём на потолок или обойди. Пригнувшись можно проскользнуть. Выстрел сгоняет его до утра.",
	directive = { code = "lights_on", text = "НЕ ВЫКЛЮЧАЙТЕ СВЕТ" },
	steps = { key = "Creak", fallback = "Footstep", pitch = 1.6, volume = 0.25 },
	ambient = { key = "Drip", fallback = "Breath", every = 5 },
	scare = Color3.fromRGB(230, 220, 150),
}

---------------------------------------------------------------- модель
local SKIN, SKIN2, BONE, HAIR = "#bdb68c", "#a39c74", "#8c8564", "#141212"

function Hanger.build(ctx)
	local R = Rig.build({
		name = "Hanger", footH = 0.25, footL = 0.95, legW = 0.42, hipX = 0.32, legU = 2.0, legL = 2.0,
		ltH = 0.55, utH = 1.7, torsoW = 1.15, torsoD = 0.6, armW = 0.32, armU = 2.1, armL = 2.1, hand = 0.7,
		neck = 0.55, head = Vector3.new(0.85, 1.0, 0.9), hunch = 0.3,
		skin = SKIN, shirt = SKIN, sleeve = SKIN2, forearm = SKIN, pants = SKIN2, shin = SKIN, belt = "#5a5244",
		shoes = SKIN2, hands = SKIN2, skinMat = Enum.Material.SmoothPlastic, cloth = Enum.Material.SmoothPlastic,
		stride = 8,
	})
	local P = R.parts
	-- рёбра, позвоночник, ключицы — истощённое тело
	for i = 0, 4 do
		Rig.add(R, "UpperTorso", "Rib", Vector3.new(1.0 - i * 0.06, 0.07, 0.06), CFrame.new(0, 0.45 - i * 0.24, -0.31), BONE)
	end
	for i = 0, 5 do
		Rig.ball(R, "UpperTorso", "Spine", 0.18, CFrame.new(0, 0.7 - i * 0.28, 0.3), BONE)
	end
	for _, sx in ipairs({ -1, 1 }) do
		Rig.add(R, "UpperTorso", "Collar", Vector3.new(0.5, 0.08, 0.08), CFrame.new(sx * 0.28, 0.78, -0.3) * CFrame.Angles(0, 0, sx * 0.25), BONE)
		Rig.ball(R, "LowerTorso", "HipBone", 0.3, CFrame.new(sx * 0.48, 0.15, -0.2), BONE)
		-- узловатые суставы, когти на руках и ногах
		Rig.ball(R, P[(sx < 0 and "Left" or "Right") .. "LowerArm"], "Joint", 0.42, CFrame.new(0, 1.05, 0), BONE)
		Rig.ball(R, P[(sx < 0 and "Left" or "Right") .. "LowerLeg"], "Joint", 0.5, CFrame.new(0, 1.0, 0), BONE)
		local hand = (sx < 0 and "Left" or "Right") .. "Hand"
		for i = -1, 1 do
			Rig.add(R, hand, "Claw", Vector3.new(0.06, 0.75, 0.06), CFrame.new(i * 0.09, -0.65, -0.03) * CFrame.Angles(0.25, 0, i * 0.15), BONE)
		end
		local foot = (sx < 0 and "Left" or "Right") .. "Foot"
		for i = -1, 1 do
			Rig.add(R, foot, "Toe", Vector3.new(0.07, 0.07, 0.35), CFrame.new(i * 0.12, -0.05, -0.6), BONE)
		end
	end
	-- грязная повязка на бёдрах с рваными полосами
	Rig.add(R, "LowerTorso", "Wrap", Vector3.new(1.12, 0.4, 0.66), CFrame.new(0, -0.05, 0), "#5a5244", Enum.Material.Fabric)
	for i = -1, 1 do
		Rig.add(R, "LowerTorso", "Rag", Vector3.new(0.22, 0.6, 0.05), CFrame.new(i * 0.32, -0.45, -0.34) * CFrame.Angles(0, 0, i * 0.1), "#4a4236", Enum.Material.Fabric)
	end
	-- голова: впалые глазницы, бледные глаза, разинутый чёрный рот
	local H, hz = "Head", -0.45
	Rig.sockets(R, H, CFrame.new(0, 0.12, hz - 0.01), 0.36, Vector3.new(0.3, 0.22, 0.05), "#1a140c")
	Rig.eyes(R, H, CFrame.new(0, 0.12, hz - 0.04), 0.36, 0.09, "#f2ecc0", { range = 6, brightness = 0.7 })
	Rig.add(R, H, "Mouth", Vector3.new(0.3, 0.48, 0.05), CFrame.new(0, -0.22, hz - 0.01), "#0a0404")
	for i = -1, 1 do
		Rig.add(R, H, "Tooth", Vector3.new(0.05, 0.1, 0.06), CFrame.new(i * 0.09, 0.0, hz - 0.03), "#c8c0a0")
	end
	Rig.add(R, H, "Cheek", Vector3.new(0.9, 0.18, 0.86), CFrame.new(0, -0.08, 0.02), SKIN2)
	Rig.add(R, H, "Scalp", Vector3.new(0.9, 0.3, 0.95), CFrame.new(0, 0.42, 0.02), HAIR)
	-- волосы: свой сустав HairJoint, клиент держит их вертикально вниз при любом наклоне тела
	local head = P.Head
	local scalpAt = head.Position + Vector3.new(0, 0.35, 0)
	local hair = Rig.part(R, "Hair", Vector3.new(0.6, 0.2, 0.6), CFrame.new(scalpAt), HAIR)
	Rig.joint(R, "HairJoint", head, hair, scalpAt)
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2
		local L = 2.6 + ((i * 37) % 10) / 9
		local r = 0.42
		local w = 0.1 + (i % 3) * 0.035
		Rig.addAt(R, hair, "Strand", Vector3.new(w, L, 0.08), CFrame.new(scalpAt + Vector3.new(math.sin(a) * r, -L / 2 + 0.1, math.cos(a) * r)) * CFrame.Angles(0, a, 0), (i % 2 == 0) and HAIR or "#221e1c")
	end
	Rig.finish(R)
	return R.model
end

---------------------------------------------------------------- поведение (сервер)
local function rootMotor(inm)
	local lt = inm.model:FindFirstChild("LowerTorso")
	return lt and lt:FindFirstChild("Root")
end

-- тело к потолку и на сервере (чтобы выстрел попадал туда, где его видят)
local function setLift(inm, lift)
	local G = inm.mem.hg
	lift = math.max(0, lift)
	if math.abs(lift - (G.lift or -1)) < 0.4 then return end
	G.lift = lift
	inm:attr("Lift", lift)
	local m = rootMotor(inm)
	if m then
		local base = m:GetAttribute("BaseC0") or m.C0
		if lift > 0.5 then
			m.C0 = CFrame.new(base.Position + Vector3.new(0, lift, 0)) * CFrame.Angles(-math.pi / 2, 0, 0) * (base - base.Position)
		else
			m.C0 = base
		end
	end
end

local function liftHere(inm)
	local feet = inm:feet()
	local c = inm:ceilingAt(feet, 22)
	if not c then return 0 end
	local hipY = inm.model:GetAttribute("HipY") or 4
	return math.clamp(c - feet.Y - hipY - 0.45, 0, 12)
end

local function anchors(inm)
	local G = inm.mem.hg
	if G.anchors then return G.anchors end
	local list = {}
	for _, room in ipairs(inm.H.rooms) do
		local w = PREF[room.Name] or 1
		for _ = 1, w do table.insert(list, inm:roomPoint(room)) end
	end
	-- у межкомнатных дверных проёмов: под косяком проходят все
	for _, d in ipairs(inm.house.doors or {}) do
		local leaf = d:FindFirstChild("Leaf")
		local panel = leaf and leaf:FindFirstChild("Panel")
		if panel and d:GetAttribute("Exterior") ~= true then
			local side = (math.random() < 0.5) and 1 or -1
			local p = panel.Position + panel.CFrame.LookVector * 2.6 * side
			local fy = inm:floorAt(p, 12)
			if fy then table.insert(list, Vector3.new(p.X, fy, p.Z)) end
		end
	end
	G.anchors = list
	return list
end

local function pickAnchor(inm, not_)
	local list = anchors(inm)
	if #list == 0 then return inm:randomRoomPoint() end
	local pls = inm:players()
	local cand = {}
	for _, a in ipairs(list) do
		local ok = a ~= not_
		for _, p in ipairs(pls) do
			if (p.feet - a).Magnitude < 10 then ok = false end
		end
		if ok then table.insert(cand, a) end
	end
	if #cand == 0 then cand = list end
	-- в половине случаев — засада ближе к случайному игроку
	if #pls > 0 and math.random() < 0.5 then
		local p = pls[math.random(#pls)]
		table.sort(cand, function(a, b) return (a - p.feet).Magnitude < (b - p.feet).Magnitude end)
		return cand[math.random(math.min(2, #cand))]
	end
	return cand[math.random(#cand)]
end

local function goAnchor(inm, fast)
	local G = inm.mem.hg
	G.anchor = pickAnchor(inm, G.anchor)
	G.fast = fast
	G.torch = 0
	inm.root.Anchored = false
	inm.root.CanCollide = false
	pcall(function() inm.root:SetNetworkOwner(nil) end)
	inm:setState("crawl")
end

local function climb(inm)
	inm.root.CanCollide = false
	inm:setState("climb")
	inm:setAnim("climb", 1.2)
end

-- кто-то светит на него фонарём (смотрит в его сторону, свет включён, линия видимости)
local function torched(inm)
	local body = inm:feet() + Vector3.new(0, (inm.model:GetAttribute("HipY") or 4) + (inm.mem.hg.lift or 0), 0)
	for _, p in ipairs(inm:players()) do
		if p.flash and not p.hidden then
			local to = body - p.head
			local d = to.Magnitude
			if d < 38 and d > 0.5 then
				local look = p.root.CFrame.LookVector
				local fl = Vector3.new(to.X, 0, to.Z)
				local facing = fl.Magnitude < 3 or Vector3.new(look.X, 0, look.Z).Unit:Dot(fl.Unit) > 0.75
				if facing and inm:los(p.head, body) then return true end
			end
		end
	end
	return false
end

local function walkerBelow(inm)
	for _, p in ipairs(inm:players()) do
		if not p.hidden and not p.crouch and p.speed > 3 and p.flat < UNDER and math.abs(p.dy) < 4 then return p end
	end
	return nil
end

local function startDrop(inm, p)
	local G = inm.mem.hg
	inm.root.Anchored = false
	inm.root.CanCollide = true
	pcall(function() inm.root:SetNetworkOwner(nil) end)
	setLift(inm, 0)
	G.ft = 0
	inm:face(p.pos)
	inm:setState("drop")
	inm:setAnim("drop", 0.5)
	inm:sound("Shriek", inm.root, { Volume = 1 }, "Stinger")
end

local function land(inm)
	local hit = false
	inm:sound("DoorBash", inm.root, { Volume = 0.8, PlaybackSpeed = 0.6 })
	inm:shakeNear(1.2, 0.4, 22)
	for _, p in ipairs(inm:players()) do
		if not p.hidden and p.flat < LAND_R and math.abs(p.dy) < 4 then
			inm:kill(p.plr)
			hit = true
		end
	end
	if hit then
		inm:setState("floor")
		inm:setAnim("floor", 1.4)
	else
		inm:setState("lunge")
		inm.mem.hg.tgt = nil
	end
end

local function startFall(inm)
	local G = inm.mem.hg
	G.fled = true
	inm.root.Anchored = false
	inm.root.CanCollide = true
	pcall(function() inm.root:SetNetworkOwner(nil) end)
	setLift(inm, 0)
	inm:setState("fall")
	inm:setAnim("fall", 0.9)
	inm:sound("Shriek", inm.root, { Volume = 1 }, "Stinger")
end

local function flee(inm, dt)
	local G = inm.mem.hg
	inm:setAnim("flee")
	if not G.exit then
		G.exit = inm:pickEntry(nil, inm:pos())
		G.exitPhase = "in"
		G.fleeT = 0
	end
	G.fleeT = G.fleeT + dt
	local e = G.exit
	if not e or G.fleeT > 16 then
		inm:say("ВИСЯЩИЙ сорвался с потолка и сбежал из дома!", nil, true)
		inm:despawn(0.6)
		return
	end
	if G.exitPhase == "in" then
		local r = inm:goTo(e.In.Position, V_FAST, { near = 2.5 })
		if r == "arrived" then
			if e:GetAttribute("Kind") == "Window" then
				local HL = inm.ctx and inm.ctx.HouseLogic
				if e:GetAttribute("Broken") ~= true and HL then pcall(HL.breakWindow, e) end
				inm:vault(e.In.Position, e.Out.Position, 0.6)
				G.exitPhase = "vault"
			else
				G.exitPhase = "out"
			end
		end
	elseif G.exitPhase == "vault" then
		if not inm.vaulting then G.fleeT = 99 end
	else
		local r = inm:goTo(e.Out.Position, V_FAST, { near = 2.5 })
		if r == "arrived" then G.fleeT = 99 end
	end
end

Hanger.server = {
	spawn = function(inm)
		inm.mem.hg = { lift = 0, torch = 0, idle = 0, idleMax = 50, ft = 0 }
		inm:attr("Lift", 0)
		inm.entry = (math.random() < 0.7) and inm:pickEntry("Window") or inm:pickEntry("Door")
	end,
	tick = function(inm, dt)
		local G = inm.mem.hg
		local S = inm.state
		if S == "fall" then
			if inm:since() > 0.9 then inm:setState("flee") end
			return
		end
		if S == "flee" then
			flee(inm, dt)
			return
		end
		if S == "enter" then
			if inm:enter(dt, { speed = V_WALK }) then climb(inm) end
			for _, p in ipairs(inm:players()) do
				if not p.hidden and p.flat < 3.5 then inm:tryAttack(p) end
			end
			return
		end
		if S == "climb" then
			inm:stop()
			setLift(inm, liftHere(inm))
			if inm:since() > 1.2 then goAnchor(inm, false) end
			return
		end
		if S == "crawl" then
			inm:setAnim("ceiling")
			setLift(inm, liftHere(inm))
			local r = inm:goTo(G.anchor, G.fast and V_CRAWL * 1.45 or V_CRAWL, { near = 1.6 })
			if r == "arrived" or inm:since() > 40 then
				inm:stop()
				inm.root.Anchored = true
				setLift(inm, liftHere(inm))
				inm:setState("wait")
				G.idle, G.torch = 0, 0
				G.idleMax = 45 + math.random() * 30
			end
			return
		end
		if S == "wait" then
			inm:setAnim("ceilwait")
			if torched(inm) then G.torch = G.torch + dt else G.torch = math.max(0, G.torch - dt * 0.5) end
			if G.torch > T_TORCH then
				inm:setState("hiss")
				inm:setAnim("hiss", 0.8)
				inm:sound("Hiss", inm.root, { Volume = 1 }, "Whisper")
				return
			end
			if inm:since() < 1.5 then return end
			local p = walkerBelow(inm)
			if p then
				startDrop(inm, p)
				return
			end
			G.idle = G.idle + dt
			if G.idle > G.idleMax then goAnchor(inm, false) end
			return
		end
		if S == "hiss" then
			if inm:since() > 0.8 then goAnchor(inm, true) end
			return
		end
		if S == "drop" then
			if inm:since() >= T_DROP then land(inm) end
			return
		end
		if S == "floor" then
			inm:stop()
			if inm:since() > 1.4 then climb(inm) end
			return
		end
		if S == "lunge" then
			inm:setAnim("lunge")
			if inm:since() < 0.45 then
				inm:stop()
				return
			end
			local p = G.tgt and inm:find(G.tgt)
			if not p or p.hidden then
				p = inm:look({ wide = true, sight = 45 })
			end
			if not p or inm:since() > 4.5 then
				climb(inm)
				return
			end
			G.tgt = p.plr
			inm:goTo(p.feet, V_FAST, { repath = 0.8, direct = p.flat < 16 and math.abs(p.dy) < 3, near = 1.2 })
			inm:tryAttack(p, { cooldown = 0.6 })
			return
		end
		climb(inm)
	end,
	-- выстрел: срывается с потолка и удирает из дома до утра
	onDamage = function(inm, amount, by)
		local G = inm.mem.hg
		if G and not G.fled then startFall(inm) end
	end,
	onStun = function(inm, s)
		local G = inm.mem.hg
		if G and G.fled then return false end
		if inm.state == "wait" or inm.state == "crawl" then
			-- оглушённый на потолке — падает и снова лезет наверх
			inm.root.Anchored = false
			inm.root.CanCollide = true
			setLift(inm, 0)
			inm:setState("floor")
		end
	end,
	cleanup = function(inm)
		setLift(inm, 0)
	end,
}

---------------------------------------------------------------- анимация (клиент)
local function hairDown(A, model)
	local j = A.j.HairJoint
	local head = model:FindFirstChild("Head")
	if not j or not head or not A.root then return end
	A.manual.HairJoint = true
	local at = (head.CFrame * j.pos).Position
	local yaw = A.root.CFrame - A.root.CFrame.Position
	local sway = CFrame.Angles(math.sin(A.t * 1.3) * 0.04, 0, math.sin(A.t * 0.9) * 0.05)
	j.m.C0 = head.CFrame:ToObjectSpace(CFrame.new(at) * yaw * sway)
end

function Hanger.animate(model, dt, t, ctx)
	local A = Rig.state(model)
	local D = A.data
	local anim = A.anim
	local lift = model:GetAttribute("Lift") or 0
	local want = (CEIL[anim] and lift > 0.5) and 1 or 0
	local rate = (want > (D.k or 0)) and 2.2 or 9
	D.k = (D.k or 0) + (want - (D.k or 0)) * math.min(1, dt * rate)
	D.lift = (D.lift or 0) + (lift - (D.lift or 0)) * math.min(1, dt * 4)
	local k = D.k
	Rig.begin(A)
	if k > 0.02 then
		-- распластан на потолке лицом вниз, паучьи лапы в стороны, суставы к потолку
		local mv = math.clamp(A.speed / 6, 0, 1)
		local s = math.sin(A.phase * 1.4) * mv
		local tw = (anim == "hiss") and math.sin(t * 40) * 0.12 or 0
		Rig.move(A, "Root", 0, D.lift * k, 0)
		Rig.rot(A, "Root", -math.pi / 2 * k + tw * 0.3, 0, s * 0.05 * k)
		Rig.rot(A, "Waist", 0.3 * k, 0, 0)
		Rig.rot(A, "LeftShoulder", 0, 0, (-2.2 + s * 0.35) * k)
		Rig.rot(A, "RightShoulder", 0, 0, (2.2 + s * 0.35) * k)
		Rig.rot(A, "LeftElbow", -1.1 * k, 0, 0)
		Rig.rot(A, "RightElbow", -1.1 * k, 0, 0)
		Rig.rot(A, "LeftHip", 0, 0, (-0.8 - s * 0.3) * k)
		Rig.rot(A, "RightHip", 0, 0, (0.8 - s * 0.3) * k)
		Rig.rot(A, "LeftKnee", -1.2 * k, 0, 0)
		Rig.rot(A, "RightKnee", -1.2 * k, 0, 0)
		if anim == "hiss" then
			Rig.rot(A, "Neck", 1.5 * k + tw, 0, tw)
		elseif anim == "ceilwait" then
			Rig.rot(A, "Neck", (0.8 + math.sin(t * 0.7) * 0.12) * k, math.sin(t * 0.45) * 0.5 * k, 0)
			Rig.twitch(A, 0.5, { "Neck", "LeftWrist", "RightWrist", "LeftElbow" }, 1.4)
		else
			Rig.rot(A, "Neck", 0.9 * k, 0, 0)
		end
	end
	if k < 0.98 then
		local f = 1 - k
		if anim == "dead" then
			Rig.dead(A, math.min(1, A.animT * 2.5))
		elseif anim == "stunned" or A.stunned then
			Rig.stagger(A, f)
			Rig.twitch(A, 0.8, { "Neck", "LeftShoulder", "RightShoulder" }, 0.15)
		elseif anim == "lunge" or anim == "flee" or anim == "floor" then
			-- почти на четвереньках, длинные руки загребают пол
			Rig.crawl(A, f, { tilt = 1.15, gait = 0.7 })
			if anim == "floor" then Rig.move(A, "Root", 0, -0.6 * f, 0) end
			Rig.twitch(A, 0.6, { "Neck", "Waist" }, 0.3)
		elseif anim == "drop" or anim == "fall" then
			local fl = math.sin(t * 30) * 0.5
			Rig.rot(A, "LeftShoulder", (2.5 + fl) * f, 0, -0.6 * f)
			Rig.rot(A, "RightShoulder", (2.5 - fl) * f, 0, 0.6 * f)
			Rig.rot(A, "Neck", 0.5 * f, 0, fl * 0.3)
		elseif anim == "attack" then
			Rig.crawl(A, f * 0.6, { tilt = 0.9 })
			Rig.lunge(A, Rig.strike(A.animT) * f)
		else
			local mv = math.clamp(A.speed / 9, 0, 1.2)
			if mv > 0.06 then Rig.walk(A, mv * f, { leg = 0.5, arm = 0.25, bob = 0.25 }) else Rig.idle(A, f, { look = 0.4 }) end
			Rig.rot(A, "LeftShoulder", 0.15 * f, 0, -0.12 * f)
			Rig.rot(A, "RightShoulder", 0.15 * f, 0, 0.12 * f)
			Rig.rot(A, "LeftElbow", 0.3 * f, 0, 0)
			Rig.rot(A, "RightElbow", 0.3 * f, 0, 0)
			if anim == "break" then Rig.pound(A, f) end
			if anim == "vault" then Rig.crawl(A, f, { tilt = 1.0 }) end
			if anim == "climb" then
				Rig.rot(A, "LeftShoulder", 2.6 * f, 0, -0.3 * f)
				Rig.rot(A, "RightShoulder", 2.6 * f, 0, 0.3 * f)
			end
			Rig.twitch(A, 0.4, { "Neck", "LeftWrist", "RightWrist" }, 0.9)
		end
	end
	Rig.apply(A)
	hairDown(A, model)
	-- глаза тлеют в темноте; в засаде еле видны
	local cam = workspace.CurrentCamera
	local near = 0
	if cam and A.root then near = math.clamp(1 - (cam.CFrame.Position - A.root.Position).Magnitude / 30, 0, 1) end
	if anim == "hiss" or anim == "drop" or anim == "lunge" then
		Rig.glow(A, 1.2)
	else
		Rig.glow(A, 0.25 + near * 0.6)
	end
end

return Hanger
