-- Сюжет главы 2 «Вторжение»:
--   1. garage()     — Рик и Морти вываливаются из портала в гараж-лабораторию; Рик на большом экране
--                     рассказывает про Пожирателей: они пожирают миры и вселенные и добрались до нас;
--                     грохочет взрыв, Морти открывает ворота и выходит на улицу;
--   2. invasion()   — небо резко темнеет, в небе открывается разлом, корабли вылетают один за другим
--                     и окружают героев, лидер сбрасывает гранату — Рик утаскивает Морти в портал;
--   3. toiletWar()  — база камераменов («50-я серия»): Морти оглядывается, смотрит на камераменов,
--                     спикерменов и Титана; все поворачиваются к нему. Дальше — конец главы (Story.lua).
-- Общие помощники (trove, метки, состояние, подсказки) приходят из Story через env.
local Chapter2 = {}
local U, Config, Settings, Audio, Hud, Cine, Controls, World, Prompts, Outline
local Rick, Portal, Fx, Ships, CameraBase, Lab
local env

function Chapter2.init(c)
	U, Config, Settings, Audio, Hud, Cine, Controls, World, Prompts, Outline =
		c.Util, c.Config, c.Settings, c.Audio, c.Hud, c.Cine, c.Controls, c.World, c.Prompts, c.Outline
	Rick, Portal, Fx, Ships, CameraBase, Lab = c.Rick, c.Portal, c.Fx, c.Ships, c.CameraBase, c.Lab
end

local GREEN = Color3.fromRGB(190, 255, 150)

-- реплика: показать субтитр, Рик шевелит ртом (и рыгает, если в тексте есть «бурп»), подождать
local function line(who, key, rick, extra)
	local text = Config.Text[key] or key
	local hold = Hud.say(who, text)
	if rick and who == "РИК" then
		rick:talk(math.max(0.8, hold - 0.9))
		if string.find(text, "бурп", 1, true) then
			task.delay(hold * 0.45, function()
				if rick.model and rick.model.Parent then rick:doBurp() end
			end)
		end
	end
	U.wait(hold + (extra or 0.15))
end

-- сценка: забрать управление (камера остаётся там же)
local function sceneMode()
	env.setState("scene")
	Prompts.setEnabled(false)
	Controls.freeze(true)
	Controls.setActive(false)
	Hud.gameplay(false)
	local cam = workspace.CurrentCamera
	if not Cine.active then Cine.take(cam.CFrame, cam.FieldOfView) end
end

-- свободная ходьба: персонаж в точке cf (корень), камера смотрит на lookAt
local function roamMode(cf, lookAt)
	local eye = cf.Position + Vector3.new(0, Controls.eyeOffset(), 0)
	Controls.place(cf, false)
	Cine.release()
	workspace.CurrentCamera.CFrame = CFrame.lookAt(eye, lookAt or (eye + cf.LookVector * 5))
	env.setBodyHidden(false)
	Controls.setActive(true)
	Controls.freeze(false)
	Hud.gameplay(true)
	Prompts.setEnabled(true)
	env.setState("roam")
end

local function rootPos()
	local _, _, root = Controls.character()
	return root and root.Position
end

-- ждать, пока игрок не окажется в нужном месте; через hintAfter секунд — подсказка и маркер
local function waitReach(test, hintText, markerPart, hintAfter)
	local t0 = os.clock()
	local hinted = false
	while true do
		U.wait(0.15)
		local p = rootPos()
		if p and test(p) then break end
		if not hinted and Settings.get("Hints") and os.clock() - t0 > (hintAfter or 15) then
			hinted = true
			if hintText then Hud.toast(hintText, 4) end
			if markerPart then Hud.marker(markerPart) end
		end
	end
	Hud.marker(nil)
end

---------------------------------------------------------------------------
-- 1. Гараж-лаборатория
---------------------------------------------------------------------------
local function garage(fresh)
	local mk, trove = env.mk, env.trove
	sceneMode()
	-- из зелёной вспышки портала (или из меню) — в черноту, заставка главы
	Hud.fadeWait(1, fresh and 0 or 0.6, Color3.new(0, 0, 0))
	Hud.retro(false)
	Hud.eyesSet(1)
	Hud.blur(0)
	World.apply("lab", 0)
	local lab = Lab.new()
	trove:add(function() lab:reset() end)
	env.overrideThought("GarageDoor", "GarageDoorCh2")
	Audio.loop("lab", "LabAmb", { at = mk("GRickTalk"), volume = 0.55, min = 8, max = 45 })
	Hud.chapterCard(Config.Chapter2, Config.Text.GarageCard)
	-- Морти вываливается из портала
	local _, hum = Controls.character()
	if hum then
		hum.Sit = false
		hum.PlatformStand = false
	end
	local spot = mk("GMorty").CFrame
	Controls.place(spot, true)
	env.setBodyHidden(true)
	local eyeH = Controls.eyeOffset()
	local eye = spot.Position + Vector3.new(0, eyeH, 0)
	local pcf = mk("GPortal").CFrame
	local portal = Portal.new(pcf, 7, workspace)
	trove:add(function() portal:destroy() end)
	portal:open(0.3)
	local pp = pcf.Position
	Cine.take(CFrame.lookAt(pp + Vector3.new(0, 0, 0.4), pp + Vector3.new(0, -1.2, 10)), 92)
	Hud.fade(0, 0.35, Color3.new(0, 0, 0))
	Audio.play("Whoosh", { volume = 0.9 })
	Cine.play({
		{ t = 0, cf = Cine.get(), fov = 92 },
		{ t = 0.45, cf = CFrame.lookAt(Vector3.new(pp.X, 4.2, 6.0), Vector3.new(pp.X, 0, 14)) * CFrame.Angles(0, 0, math.rad(22)), fov = 82, ease = "linear" },
		{ t = 0.8, cf = CFrame.lookAt(Vector3.new(eye.X, 1.0, eye.Z), Vector3.new(eye.X - 1, 6, eye.Z + 9)) * CFrame.Angles(0, 0, math.rad(-10)), fov = 74, ease = "in" },
	})
	Audio.play("Land", { volume = 1 })
	Cine.shake(0.8, 0.7)
	Cine.breathe(0.8)
	-- следом выходит Рик
	U.wait(0.4)
	local rick = Rick.new(CFrame.lookAt(Vector3.new(pp.X, 0, pp.Z), mk("GRick").Position), workspace)
	trove:add(function() rick:destroy() end)
	Outline.add(rick.model)
	task.spawn(function()
		rick:moveTo(mk("GRick").Position, 1.1)
		rick:face(eye)
		rick.lookAt = eye
	end)
	U.wait(0.6)
	-- Морти поднимается
	Cine.play({
		{ t = 0, cf = Cine.get() },
		{ t = 0.9, cf = CFrame.lookAt(Vector3.new(eye.X, eye.Y - 1.4, eye.Z), Vector3.new(eye.X - 1.5, 4, eye.Z + 6)), ease = "inout" },
		{ t = 1.6, cf = CFrame.lookAt(eye, mk("GRick").Position + Vector3.new(0, 6, 0)), ease = "inout" },
	})
	portal:scaleTo(0, 0.5, Enum.EasingStyle.Back)
	task.delay(0.6, function() portal:destroy() end)
	line("МОРТИ", "LandGarage")
	line("РИК", "RickLab", rick)
	-- Рик идёт к экрану, игрок — за ним
	task.spawn(function()
		rick.lookAt = nil
		rick:moveTo(Vector3.new(69.2, 0, 19.6), 1.9)
		rick:moveTo(mk("GRickTalk").Position, 1.0)
		rick:face(mk("GMortyTalk").Position)
	end)
	roamMode(CFrame.lookAt(spot.Position, Vector3.new(71, spot.Position.Y, 22)), Vector3.new(71, 5, 22))
	Hud.objective(Config.Text.GoToRick)
	local goal = mk("GMortyTalk")
	waitReach(function(p)
		local d = p - goal.Position
		return Vector3.new(d.X, 0, d.Z).Magnitude < 5
	end, nil, goal, 10)
	Hud.objectiveDone()

	-- рассказ у большого экрана
	sceneMode()
	local talk = goal.CFrame
	Controls.place(talk, true)
	env.setBodyHidden(true)
	local teye = talk.Position + Vector3.new(0, eyeH, 0)
	local screenPos = Vector3.new(71, 6.8, 25.1)
	local view = Vector3.new(68.4, 5.3, 23.4) -- в кадре и Рик (слева), и экран
	rick:face(teye)
	rick.lookAt = teye
	Cine.move(CFrame.lookAt(teye, view), 1.0, "inout", 68)
	Cine.breathe(0.6)
	lab:devourers()
	Audio.play("Click", { volume = 0.6 })
	rick.lookAt = screenPos
	rick.aim = Vector3.new(68.2, 6.2, 25)
	line("РИК", "Explain1", rick)
	lab:multiverse()
	Audio.play("Notify", { volume = 0.5 })
	lab:eat(9, 7)
	line("РИК", "Explain2", rick, 0.4)
	rick.aim = nil
	rick.lookAt = teye
	Cine.move(CFrame.lookAt(teye, rick.cf.Position + Vector3.new(0, 6.4, 0)), 0.8, "inout", 62)
	line("МОРТИ", "MortyAsk")
	line("РИК", "Explain3", rick)
	lab:found()
	Audio.play("Sting", { volume = 0.6 })
	Cine.move(CFrame.lookAt(teye, view), 0.9, "inout", 68)
	rick.lookAt = screenPos
	rick.aim = Vector3.new(69.5, 6.6, 25)
	line("РИК", "Explain4", rick)
	rick.aim = nil
	rick.lookAt = teye
	line("МОРТИ", "MortyScared")
	Hud.say("РИК", Config.Text.RickPlan, { hold = 2 })
	rick:talk(1.4)
	U.wait(1.5)
	-- ВЗРЫВ где-то на улице
	Audio.play("Explosion", { volume = 1, speed = 0.85 })
	Hud.say(nil, Config.Text.Boom, { hold = 1.8 })
	Cine.shake(1.1, 1.6)
	lab:flicker(1.8)
	Fx.dust(CFrame.new(70, 11.1, 14), Vector3.new(16, 0.3, 16), workspace)
	U.wait(0.5)
	lab:alarm()
	Audio.loop("siren", "Siren", { at = lab.screen, volume = 0.45, min = 6, max = 60 })
	trove:add(function() Audio.stop("siren") end)
	Cine.move(CFrame.lookAt(teye, Vector3.new(69, 4, -2)), 0.7, "out", 70)
	line("МОРТИ", "WhatWasThat")
	local button = mk("GButton")
	rick.lookAt = button.Position
	Cine.move(CFrame.lookAt(teye, rick.cf.Position + Vector3.new(0, 6.2, 0)), 0.6, "inout")
	line("РИК", "RickDoor", rick)
	-- игрок открывает ворота
	roamMode(CFrame.lookAt(talk.Position, Vector3.new(button.Position.X, talk.Position.Y, button.Position.Z)), button.Position)
	Hud.objective(Config.Text.DoorObjective)
	local btnPart = workspace.House:FindFirstChild("DoorButton", true) or button
	local prompt = env.localPrompt(btnPart, "Открыть ворота", 9)
	if Settings.get("Hints") then
		task.delay(14, function()
			if prompt.Parent then
				Hud.toast(Config.Text.DoorHint, 4)
				Hud.marker(button)
			end
		end)
	end
	env.waitPrompt(prompt)
	prompt:Destroy()
	Hud.marker(nil)
	Hud.objectiveDone()
	lab:pressButton()
	Audio.stop("siren", 0.8)
	task.spawn(function() lab:openDoor(3.2) end)
	-- Рик выходит на улицу первым
	task.spawn(function()
		rick.lookAt = nil
		U.wait(0.6)
		rick:moveTo(Vector3.new(69.4, 0, 19.2), 0.9)
		rick:moveTo(Vector3.new(70.5, 0, 3.5), 1.7)
		rick:moveTo(Vector3.new(72.4, -0.95, -9.4), 1.8)
		rick:face(Vector3.new(60, 0, -60))
	end)
	U.wait(1.4)
	Hud.objective(Config.Text.GoOutside)
	local out = mk("GOutside")
	waitReach(function(p) return p.Z < -4.2 end, nil, out, 10)
	Hud.objectiveDone()
	Audio.stop("lab", 1)
	return rick, lab
end

---------------------------------------------------------------------------
-- 2. Вторжение: темнеющее небо, разлом, корабли, граната, портал
---------------------------------------------------------------------------
local function invasion(rick)
	local mk, trove = env.mk, env.trove
	sceneMode()
	local ground = -0.95
	local stand = CFrame.lookAt(Vector3.new(68.85, ground + 3, -8), Vector3.new(68.85, ground + 3, -30))
	Controls.place(stand, true)
	env.setBodyHidden(true)
	local eye = stand.Position + Vector3.new(0, Controls.eyeOffset(), 0)
	-- горящий дом соседей (взрыв был там)
	local fire = Fx.smokeColumn(Vector3.new(44, 28.2, -80), workspace, 1.3)
	trove:add(fire)
	Cine.move(CFrame.lookAt(eye, Vector3.new(46, 26, -80)), 1.6, "inout", 66)
	Audio.loop("tension", "Tension", { volume = 0.5 })
	trove:add(function() Audio.stop("tension") end)
	line("МОРТИ", "Smoke")
	-- небо резко темнеет, открывается разлом
	Audio.play("Rumble", { volume = 1 })
	World.apply("invasion", 3.2)
	Cine.shake(0.35, 3)
	local riftPos = Vector3.new(58, 150, -175)
	local riftCF = CFrame.lookAt(riftPos, eye)
	Cine.move(CFrame.lookAt(eye, riftPos + Vector3.new(0, -25, 0)), 3.0, "inout", 64)
	local rift = Portal.new(riftCF, 80, workspace, { palette = "dark", beadScale = 9 })
	trove:add(function() rift:destroy() end)
	rift:open(3.2, { quiet = true, max = 900 })
	Audio.play("SkyHorn", { volume = 1 })
	Cine.move(CFrame.lookAt(eye, riftPos), 1.2, "inout", 62)
	rick.lookAt = riftPos
	line("МОРТИ", "SkyDark")
	line("РИК", "RickSky", rick)
	-- корабли вылетают один за другим
	local center = mk("GInvasion").Position
	local fleet = Ships.fleet(center, riftCF, workspace)
	trove:add(function() fleet:destroy() end)
	local N = 7
	task.spawn(function()
		for i = 1, N do
			if not fleet.model.Parent then return end
			fleet:launch(i, N)
			U.wait(0.85)
		end
	end)
	Cine.move(CFrame.lookAt(eye, riftPos:Lerp(center, 0.45)), 2.4, "inout", 70)
	line("МОРТИ", "ShipsLine")
	-- герои озираются: корабли вокруг
	rick.lookAt = center + Vector3.new(0, 30, 0)
	local keys = {}
	for k = 0, 4 do
		local a = k * math.pi / 2
		local dir = Vector3.new(math.sin(a), 0.5, -math.cos(a))
		table.insert(keys, { t = k * 2.1, cf = CFrame.lookAt(eye, eye + dir), fov = 74, ease = "inout" })
	end
	keys[1].cf = Cine.get()
	Cine.play(keys, { wait = false })
	line("РИК", "RickShips", rick)
	fleet:tighten(0.74, 0.8, 4)
	U.wait(1.5)
	fleet:spot(Vector3.new(70.6, ground, -8.8))
	Audio.play("Sting", { volume = 0.7, speed = 0.9 })
	U.wait(2.3)
	line("МОРТИ", "Surrounded")
	-- лидер подлетает и сбрасывает гранату
	local leaderAt = CFrame.lookAt(Vector3.new(68.85, 19, -31), Vector3.new(68.85, 19, -8)) * CFrame.Angles(math.rad(-12), 0, 0)
	fleet:moveShip(1, leaderAt, 2.2)
	Cine.move(CFrame.lookAt(eye, leaderAt.Position + Vector3.new(0, -2, 0)), 1.6, "inout", 66)
	rick.lookAt = leaderAt.Position
	U.wait(1.0)
	local landAt = Vector3.new(68.3, ground, -14.5)
	Cine.moveAsync(CFrame.lookAt(eye, landAt), 1.5, "inout", 66)
	local grenade = fleet:dropGrenade(1, landAt, 1.5)
	trove:add(function() grenade:destroy() end)
	grenade:arm()
	rick.lookAt = grenade.pos
	U.wait(0.5)
	-- Рик открывает портал и утаскивает Морти
	local portalPos = Vector3.new(63.4, ground + 3.7, -8.4)
	Hud.say("РИК", Config.Text.RickGrenade, { hold = 1.6, speed = 0.015 })
	rick:talk(1.1)
	rick:face(portalPos)
	rick:shoot(portalPos)
	local portal = Portal.new(CFrame.lookAt(portalPos, eye), 6.5, workspace)
	trove:add(function() portal:destroy() end)
	portal:open(0.3)
	U.wait(0.35)
	rick.aim = nil
	rick.reach = 1
	rick.lookAt = eye
	Hud.say("МОРТИ", Config.Text.MortyAaa, { hold = 1.4, speed = 0.02 })
	Audio.play("Whoosh", { volume = 1, speed = 1.2 })
	task.spawn(function() rick:moveTo(Vector3.new(portalPos.X - 1, ground, portalPos.Z), 0.7) end)
	local into = CFrame.lookAt(portalPos + (eye - portalPos).Unit * 0.6, portalPos - (eye - portalPos).Unit * 5)
	Cine.play({
		{ t = 0, cf = Cine.get(), fov = 66 },
		{ t = 0.22, cf = CFrame.lookAt(eye + Vector3.new(0.3, -0.2, 0), portalPos) * CFrame.Angles(0, 0, math.rad(-14)), fov = 78, ease = "out" },
		{ t = 0.75, cf = into, fov = 104, ease = "in" },
	}, { wait = false })
	Cine.shake(0.8, 0.9)
	U.wait(0.45)
	-- взрыв гранаты за спиной
	local gpos = grenade.pos
	grenade:destroy()
	Fx.explosion(gpos, { size = 11, ground = ground, volume = 1 })
	Hud.fade(0.85, 0.12, Color3.fromRGB(255, 236, 200))
	U.wait(0.25)
	Hud.fadeWait(1, 0.25, GREEN)
	Cine.breathe(0)
	-- убрать улицу (свет и небо вернутся при следующем пресете)
	rick:destroy()
	portal:destroy()
	fleet:destroy()
	rift:destroy()
	if fire.Parent then fire:Destroy() end
	Audio.stop("tension", 0.5)
	U.wait(0.4)
end

---------------------------------------------------------------------------
-- 3. База камераменов («50-я серия»)
---------------------------------------------------------------------------
local function toiletWar()
	local trove = env.trove
	sceneMode()
	local base = CameraBase.new()
	trove:add(function() base:destroy() end)
	for _, a in ipairs(base.agents) do Outline.add(a.model) end
	World.apply("base", 0)
	Audio.loop("base", "BaseAmb", { volume = 0.5 })
	trove:add(function() Audio.stop("base") end)
	Controls.place(base.spawn, true)
	env.setBodyHidden(true)
	local eyeH = Controls.eyeOffset()
	local eye = base.spawn.Position + Vector3.new(0, eyeH, 0)
	local O = base.ORIGIN
	local portal = Portal.new(base.portalCF, 7, base.model)
	trove:add(function() portal:destroy() end)
	portal:open(0.25)
	local pp = base.portalCF.Position
	Cine.take(CFrame.lookAt(pp + Vector3.new(0, 0, 0.5), pp + Vector3.new(0, -1, 10)), 95)
	Hud.fade(0, 0.4, GREEN)
	Audio.play("Whoosh", { volume = 0.9 })
	Cine.play({
		{ t = 0, cf = Cine.get(), fov = 95 },
		{ t = 0.4, cf = CFrame.lookAt(Vector3.new(eye.X, eye.Y - 0.3, eye.Z - 2.5), Vector3.new(eye.X, 0, eye.Z + 8) + Vector3.new(0, O.Y, 0)) * CFrame.Angles(0, 0, math.rad(14)), fov = 84, ease = "linear" },
		{ t = 0.75, cf = CFrame.lookAt(Vector3.new(eye.X, eye.Y - 1.8, eye.Z), Vector3.new(eye.X + 0.5, O.Y + 0.5, eye.Z + 5)), fov = 72, ease = "in" },
	})
	Audio.play("Land", { volume = 1 })
	Cine.shake(0.7, 0.6)
	Cine.breathe(0.8)
	Hud.toast(Config.Text.BaseCard, 4)
	-- Рик выходит следом
	local rick = Rick.new(CFrame.lookAt(Vector3.new(pp.X, O.Y, pp.Z), base.rickSpot), base.model)
	trove:add(function() rick:destroy() end)
	Outline.add(rick.model)
	task.spawn(function()
		rick:moveTo(base.rickSpot, 1.2)
		rick:face(eye)
	end)
	-- встаёт и оглядывается: камерамены слева, спикермены справа, титан в глубине
	local camC = base:groupCenter(base.groups.cameramen)
	local spkC = base:groupCenter(base.groups.speakermen)
	local titanHead = (base.titan.cf * base.titan.neck).Position + Vector3.new(0, 4, 0)
	Cine.play({
		{ t = 0, cf = Cine.get() },
		{ t = 1.2, cf = CFrame.lookAt(eye, eye + Vector3.new(0, -0.1, 1)), ease = "inout" },
		{ t = 2.6, cf = CFrame.lookAt(eye, camC), ease = "inout" },
		{ t = 3.6, cf = CFrame.lookAt(eye, camC + Vector3.new(-2, 0, 4)), ease = "inout" },
		{ t = 5.2, cf = CFrame.lookAt(eye, spkC), ease = "inout" },
		{ t = 6.2, cf = CFrame.lookAt(eye, spkC + Vector3.new(2, 0, 4)), ease = "inout" },
		{ t = 8.0, cf = CFrame.lookAt(eye, titanHead), fov = 64, ease = "inout" },
	}, { wait = false })
	portal:scaleTo(0, 0.6, Enum.EasingStyle.Back)
	task.delay(0.7, function() portal:destroy() end)
	U.wait(1.0)
	line("МОРТИ", "BaseWhere")
	U.wait(2.4)
	line("РИК", "RickBase1", rick)
	Cine.move(CFrame.lookAt(eye, rick.cf.Position + Vector3.new(0, 6.2, 0)), 0.9, "inout", 70)
	rick.lookAt = eye
	line("РИК", "RickBase2", rick)
	-- игрок осматривается сам: нужно посмотреть на камераменов, спикерменов и титана
	roamMode(base.spawn, eye + Vector3.new(0, 0, 10))
	local function camPos() return workspace.CurrentCamera.CFrame.Position end
	local targets = {
		{ pos = camC, group = base.groups.cameramen, say = "SeeCameramen", sound = "CamZoom", need = 0.94 },
		{ pos = spkC, group = base.groups.speakermen, say = "SeeSpeakermen", sound = "Bass", need = 0.94 },
		{ pos = titanHead, group = { base.titan }, say = "SeeTitan", sound = "CamZoom", need = 0.97, rick = "RickTitan" },
	}
	local seen = 0
	local function objText() return string.format("%s  %d/%d", Config.Text.LookObjective, seen, #targets) end
	Hud.objective(objText())
	local t0 = os.clock()
	local hinted = false
	while seen < #targets do
		U.wait(0.1)
		local cf = workspace.CurrentCamera.CFrame
		for _, tg in ipairs(targets) do
			if not tg.done then
				local d = tg.pos - cf.Position
				if d.Magnitude < 95 and cf.LookVector:Dot(d.Unit) > tg.need then
					tg.done = true
					seen = seen + 1
					Hud.objectiveText(objText())
					base:watch(tg.group, camPos)
					Audio.play(tg.sound, { volume = 1, at = tg.group[1].model.PrimaryPart or tg.group[1].parts[1], min = 10, max = 120 })
					Hud.say("МОРТИ", Config.Text[tg.say])
					if tg.rick then
						task.delay(2.6, function()
							if rick.model and rick.model.Parent then
								local h = Hud.say("РИК", Config.Text[tg.rick])
								rick:talk(h - 0.9)
							end
						end)
					end
					break
				end
			end
		end
		if not hinted and Settings.get("Hints") and os.clock() - t0 > 22 then
			hinted = true
			Hud.toast(Config.Text.LookHint, 5)
		end
	end
	U.wait(3.6)
	Hud.objectiveDone()
	-- все смотрят на Морти
	sceneMode()
	Hud.fadeWait(1, 0.5, Color3.new(0, 0, 0))
	local spot = CFrame.lookAt(O + Vector3.new(0, 3, -12), O + Vector3.new(0, 3, 20))
	Controls.place(spot, true)
	env.setBodyHidden(true)
	local e2 = spot.Position + Vector3.new(0, eyeH, 0)
	rick.cf = CFrame.lookAt(O + Vector3.new(3, 0, -15), e2)
	rick.lookAt = e2
	base:watch("all", e2)
	base.titan.target = nil
	Cine.set(CFrame.lookAt(e2, camC + Vector3.new(0, -0.5, 2)), 70)
	Hud.fade(0, 0.6, Color3.new(0, 0, 0))
	Audio.play("CamZoom", { volume = 1 })
	Audio.play("Bass", { volume = 0.9 })
	Cine.play({
		{ t = 0, cf = Cine.get() },
		{ t = 2.2, cf = CFrame.lookAt(e2, spkC + Vector3.new(0, -0.5, 2)), ease = "inout" },
		{ t = 3.6, cf = CFrame.lookAt(e2, titanHead), fov = 60, ease = "inout" },
	}, { wait = false })
	line("МОРТИ", "AllLook")
	-- Титан медленно поворачивает голову к Морти
	base.titan.target = e2
	base.titan.tzoom = 1
	Audio.play("CamZoom", { volume = 1, speed = 0.55 })
	Cine.shake(0.25, 1.2)
	U.wait(1.6)
	Cine.move(CFrame.lookAt(e2, rick.cf.Position + Vector3.new(0, 6, 0)), 1.0, "inout", 68)
	line("РИК", "RickCalm", rick)
	line("РИК", "RickJoke", rick, 0.3)
	Cine.move(CFrame.lookAt(e2, titanHead + Vector3.new(0, -3, 0)), 1.2, "inout", 62)
	line("МОРТИ", "MortyEnd", nil, 0.6)
	Audio.stop("base", 1.5)
end

-- вся глава 2; fresh = true — начали с меню «Главы» (без главы 1)
function Chapter2.run(e, fresh)
	env = e
	local rick = garage(fresh)
	invasion(rick)
	toiletWar()
end

return Chapter2
