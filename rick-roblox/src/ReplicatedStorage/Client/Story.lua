-- Сюжет главы 1 «Сбой»: пробуждение (вид от первого лица), будильник, путь на кухню,
-- завтрак, телефон с лагающим ТикТоком, мысль Морти и конец главы.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Story = {}
local ctx
local U, Config, Settings, Audio, Hud, Cine, Controls, World, Prompts, Outline, Breakfast, Phone, G, B
local player = Players.LocalPlayer
local trove
local thread
local state = "idle" -- idle | intro | roam | scene | ending
local hideBody = false
local markers

local function mk(name) return markers:WaitForChild(name) end

-- скрыть своё тело (в сценках камера стоит в голове)
local function setBodyHidden(on)
	hideBody = on
	local char = player.Character
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = on and 1 or 0 end
	end
end

-- подсказка, созданная только у этого игрока
local function localPrompt(part, action, dist)
	local p = B.prompt(part, "RM_StoryPrompt", action, "", { MaxActivationDistance = dist or 7 })
	trove:add(p)
	return p
end

local function waitPrompt(p)
	local done = U.signal()
	local c = p.Triggered:Connect(function() done:Fire() end)
	done.Event:Wait()
	c:Disconnect()
end

---------------------------------------------------------------------------
-- 1. Пробуждение
---------------------------------------------------------------------------
local function lyingCF()
	local head = mk("BedHead").Position
	return CFrame.fromMatrix(Vector3.new(head.X + 0.1, 14.75, head.Z - 1.4), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1))
end

local function intro()
	state = "intro"
	Hud.fadeSet(1, Color3.new(0, 0, 0))
	Hud.eyesSet(0)
	Hud.blur(24)
	Hud.gameplay(false)
	Prompts.setEnabled(false)
	Controls.setActive(false)
	Controls.freeze(true)
	World.apply("morning", 0)
	-- персонаж лежит в кровати
	local _, hum = Controls.character()
	if hum then hum.PlatformStand = true end
	Controls.place(lyingCF(), true)
	setBodyHidden(true)
	local eye = mk("BedHead").Position
	-- голова повёрнута к тумбочке: видно потолок и мигающий будильник
	local lookUp = CFrame.lookAt(eye, eye + Vector3.new(0.92, 0.32, -0.05), Vector3.new(-0.3, 0.15, 1))
	Cine.take(lookUp, 70)
	Cine.breathe(1)
	Audio.music("MusicMorning", 3, 0.35)
	Audio.loop("birds", "Birds", { volume = 0.22 })
	Hud.chapterCard(Config.Chapter, Config.Text.DayCard)
	-- будильник
	local clock = workspace.House.Furniture:WaitForChild("AlarmClock")
	local digits = clock:FindFirstChild("Digits", true)
	Audio.loop("alarm", "Alarm", { at = clock.PrimaryPart, volume = 0.9, min = 5, max = 60 })
	local blinking = true
	trove:add(function() blinking = false end)
	task.spawn(function()
		while blinking and digits do
			digits.TextTransparency = 0
			task.wait(0.4)
			if not blinking then break end
			digits.TextTransparency = 0.85
			task.wait(0.3)
		end
		if digits then digits.TextTransparency = 0 end
	end)
	Hud.say(nil, Config.Text.Alarm, { hold = 2.5 })
	Hud.fade(0, 1.2)
	U.wait(1.4)
	-- моргание
	Audio.play("Blink", { volume = 0.4 })
	Hud.eyes(0.22, 0.9)
	Hud.blur(16, 0.9)
	U.wait(1.1)
	Hud.eyes(0, 0.18)
	U.wait(0.3)
	Hud.eyes(0.55, 0.7)
	Hud.blur(8, 0.7)
	U.wait(0.9)
	Hud.eyes(0.1, 0.15)
	U.wait(0.22)
	Hud.eyes(1, 0.9)
	Hud.blur(0, 1.4)
	U.wait(0.8)
	Hud.thinkWait(Config.Text.Wake1, 0.1)
	Hud.thinkWait(Config.Text.Wake2, 0.1)
	-- встать
	local act = Hud.action(Config.Text.GetUpHint, { Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.ButtonA }, { keyLabel = "Space" })
	act:once()
	Hud.hideSay()
	-- сценка подъёма: сесть → развернуться → встать
	Audio.play("Rustle", { volume = 0.7 })
	local stand = mk("StandSpot").CFrame
	local eyeH = Controls.eyeOffset()
	local standEye = stand.Position + Vector3.new(0, eyeH, 0)
	local window = Vector3.new(55, standEye.Y - 0.4, 30.5)
	local sit = mk("BedSit").Position
	Cine.breathe(0.5)
	Cine.play({
		{ t = 0, cf = Cine.get() },
		{ t = 1.1, cf = CFrame.lookAt(sit, sit + Vector3.new(0.1, -0.55, -1)), ease = "inout" },
		{ t = 1.6, cf = CFrame.lookAt(sit + Vector3.new(0.15, -0.05, 0), sit + Vector3.new(0.3, -0.6, -1)), ease = "inout" },
		{ t = 2.5, cf = CFrame.lookAt(sit + Vector3.new(1.4, -0.45, -0.4), sit + Vector3.new(6, -1.2, -2.4)), ease = "inout" },
		{ t = 3.6, cf = CFrame.lookAt(standEye + Vector3.new(-0.5, -0.25, 0.2), window), ease = "inout" },
		{ t = 4.2, cf = CFrame.lookAt(standEye, window), ease = "out" },
	}, { spline = true })
	-- отдаём управление
	if hum then hum.PlatformStand = false end
	Controls.place(CFrame.lookAt(stand.Position, Vector3.new(window.X, stand.Position.Y, window.Z)), false)
	Cine.release()
	workspace.CurrentCamera.CFrame = CFrame.lookAt(standEye, window)
	setBodyHidden(false)
	Controls.setActive(true)
	Controls.freeze(false)
	Hud.gameplay(true)
	Prompts.setEnabled(true)
	Cine.breathe(0)
	state = "roam"
	return clock, function() blinking = false end
end

---------------------------------------------------------------------------
-- 2. Будильник и дорога на кухню
---------------------------------------------------------------------------
local function alarmAndKitchen(clock, stopBlink)
	Hud.objective(Config.Text.AlarmObjective)
	-- из-за двери гаража тихо гудит что-то научное (Рик)
	Audio.loop("garage", "PortalHum", { at = mk("GarageHum"), volume = 0.4, min = 3, max = 28, speed = 0.75 })
	local p = localPrompt(clock.PrimaryPart, "Выключить", 8)
	if Settings.get("Hints") then
		task.delay(12, function()
			if p.Parent then Hud.toast("Будильник на тумбочке у кровати") end
		end)
	end
	waitPrompt(p)
	p:Destroy()
	stopBlink()
	Audio.stop("alarm")
	Audio.play("AlarmOff", { at = clock.PrimaryPart, volume = 0.8 })
	Hud.objectiveDone()
	Hud.thinkWait(Config.Text.AlarmDone, 0.3)
	Hud.think(Config.Text.Hungry)
	U.wait(1.5)
	Hud.objective(Config.Text.BreakfastObjective)
	-- подсказка, если игрок долго не находит кухню
	local goal = mk("KitchenGoal")
	local reached = false
	local t0 = os.clock()
	local hinted = false
	local _, _, root = Controls.character()
	while not reached do
		U.wait(0.25)
		local _, _, r = Controls.character()
		root = r
		if root then
			local d = root.Position - goal.Position
			if Vector3.new(d.X, 0, d.Z).Magnitude < 12 and root.Position.Y < 7 then reached = true end
		end
		if not hinted and not reached and Settings.get("Hints") and os.clock() - t0 > Config.HintDelay then
			hinted = true
			Hud.toast(Config.Text.KitchenHint, 5)
			Hud.marker(goal)
		end
	end
	Hud.marker(nil)
	Hud.objectiveDone()
end

---------------------------------------------------------------------------
-- 3. Завтрак
---------------------------------------------------------------------------
local function breakfast(food)
	U.wait(1.2)
	Hud.objective(Config.Text.SitObjective)
	local chair = workspace.House.Furniture:WaitForChild("ChairMorty")
	local p = localPrompt(chair:WaitForChild("Seat"), "Сесть за стол", 8)
	waitPrompt(p)
	p:Destroy()
	Hud.objectiveDone()
	-- садимся
	state = "scene"
	Prompts.setEnabled(false)
	Controls.freeze(true)
	Controls.setActive(false)
	Hud.gameplay(false)
	local cam = workspace.CurrentCamera
	Cine.take(cam.CFrame, cam.FieldOfView)
	setBodyHidden(true)
	local _, hum = Controls.character()
	Controls.place(mk("SeatMorty").CFrame, true)
	if hum then hum.Sit = true end
	Audio.play("Chair", { volume = 0.7 })
	Cine.move(mk("SeatCam").CFrame, 1.3, "inout", 66)
	Cine.breathe(0.7)
	-- хлопья
	Hud.objective(Config.Text.PourObjective)
	Hud.action("Насыпать хлопья", { Enum.KeyCode.E, Enum.KeyCode.ButtonX }):once()
	Hud.objectiveDone()
	food:pour()
	-- молоко
	Hud.objective(Config.Text.MilkObjective)
	Hud.action("Налить молоко", { Enum.KeyCode.E, Enum.KeyCode.ButtonX }):once()
	Hud.objectiveDone()
	food:pourMilk()
	-- есть
	Hud.objective(Config.Text.EatObjective)
	local total = 5
	for i = 1, total do
		local a = Hud.action(string.format("Есть  %d/%d", i - 1, total), { Enum.KeyCode.E, Enum.KeyCode.ButtonX, Enum.KeyCode.Space })
		a:once()
		food:spoonful(1 - i / total)
		if i == 2 then Hud.think(Config.Text.Yum) end
	end
	Hud.objectiveDone()
	Hud.thinkWait(Config.Text.Full, 0.2)
end

---------------------------------------------------------------------------
-- 4. Телефон
---------------------------------------------------------------------------
local function phoneScene()
	Hud.objective(Config.Text.PhoneObjective)
	Hud.action("Достать телефон", { Enum.KeyCode.F, Enum.KeyCode.E, Enum.KeyCode.ButtonY }, { keyLabel = "F" }):once()
	Hud.objectiveDone()
	local cam = workspace.CurrentCamera
	local base = cam.CFrame
	-- чуть опустить взгляд и приблизить (фокус на телефоне)
	Cine.move(base * CFrame.Angles(math.rad(8), 0, 0), 0.8, "inout", 60)
	local phone = Phone.new()
	trove:add(function() phone:destroy() end)
	Outline.add(phone.model)
	phone:raise()
	Audio.muffle(true)
	U.wait(0.6)
	phone:lockScreen()
	U.wait(1.4)
	Hud.thinkWait(Config.Text.PhoneThink, 0)
	phone:openTikTok()
	phone:video1()
	U.wait(3.6)
	Hud.objective(Config.Text.SwipeObjective)
	Hud.action("Листать", { Enum.KeyCode.E, Enum.KeyCode.Space, Enum.UserInputType.MouseWheel, Enum.KeyCode.ButtonX }, { keyLabel = "E" }):once()
	Hud.objectiveDone()
	phone:swipeToVideo2()
	U.wait(2.2)
	phone:lag(3.2)
	U.wait(1.0)
	Hud.think(Config.Text.Lag1)
	U.wait(3.0)
	Cine.shake(0.6, 2.8)
	phone:glitch(3.0)
	Audio.play("Sting", { volume = 0.7 })
	Cine.shake(0.3, 0.8)
	U.wait(0.6)
	-- главная фраза
	Hud.think(Config.Text.WhatThe, { hold = 3.6, speed = 0.035 })
	Cine.move(cam.CFrame * CFrame.Angles(math.rad(-4), math.rad(2), 0), 1.4, "out", 54)
	U.wait(3.4)
	return phone
end

---------------------------------------------------------------------------
-- 5. Конец главы
---------------------------------------------------------------------------
local function ending(onMenu)
	state = "ending"
	Hud.objective(nil)
	Hud.letterbox(true, 1.2)
	Hud.fadeWait(1, 1.6, Color3.new(0, 0, 0))
	Audio.muffle(false)
	Audio.stopAll()
	Audio.music("MusicMenu", 2, 0.45)
	local sg, root = G.screen("Ending", 60)
	trove:add(sg)
	local t1 = G.label(root, Config.Text.ChapterEnd, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.36, 0), Size = UDim2.fromOffset(900, 70),
		FontFace = G.Fonts.Title, TextSize = 60, TextColor3 = Config.Colors.UiLime, TextTransparency = 1 })
	G.stroke(t1, Config.Colors.UiDark, 4, 1).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	local t2 = G.label(root, Config.Text.ToBeContinued, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.48, 0), Size = UDim2.fromOffset(900, 40),
		FontFace = G.Fonts.Wide, TextSize = 30, TextTransparency = 0 })
	t2.MaxVisibleGraphemes = 0
	local t3 = G.label(root, Config.Text.Thanks, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.58, 0), Size = UDim2.fromOffset(900, 30),
		FontFace = G.Fonts.Body, TextSize = 22, TextTransparency = 1, TextColor3 = Color3.fromRGB(210, 230, 210) })
	G.tween(t1, 1.2, { TextTransparency = 0 })
	local s = t1:FindFirstChildOfClass("UIStroke")
	if s then G.tween(s, 1.2, { Transparency = 0 }) end
	U.wait(1.2)
	local n = utf8.len(Config.Text.ToBeContinued) or 20
	for i = 1, n do
		t2.MaxVisibleGraphemes = i
		task.wait(0.06)
	end
	U.wait(0.8)
	G.tween(t3, 1, { TextTransparency = 0 })
	U.wait(1)
	local chosen = U.signal()
	local holder = G.button(root, "В ГЛАВНОЕ МЕНЮ", { name = "ToMenu", size = Vector2.new(380, 64), onClick = function() chosen:Fire() end })
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0.68, 0)
	local modal = G.modal(root, "Free")
	modal.BackgroundTransparency = 1
	modal.ZIndex = 0
	chosen.Event:Wait()
	Hud.letterbox(false, 0.3)
	onMenu()
end

---------------------------------------------------------------------------
-- запуск и сброс
---------------------------------------------------------------------------
function Story.init(c)
	ctx = c
	U, Config, Settings, Audio, Hud, Cine, Controls, World, Prompts, Outline, Breakfast, Phone, G, B =
		c.Util, c.Config, c.Settings, c.Audio, c.Hud, c.Cine, c.Controls, c.World, c.Prompts, c.Outline, c.Breakfast, c.Phone, c.Gui, c.Build
	markers = workspace:WaitForChild("House"):WaitForChild("Markers")
	trove = U.trove()
	-- мысли у предметов (подсказки с атрибутом Thought)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if state ~= "roam" then return end
		local key = prompt:GetAttribute("Thought")
		if not key then return end
		if prompt:GetAttribute("NoteText") then
			Controls.freeze(true)
			Hud.note(Config.Text.Note)
			Controls.freeze(false)
			return
		end
		if prompt:GetAttribute("Locked") then Audio.play("Locked", { at = prompt.Parent, volume = 0.7 }) end
		local text = Config.Text[key]
		if text then Hud.think(text) end
	end)
	-- скрывать тело каждый кадр, пока идёт сценка (Roblox может вернуть прозрачность)
	RunService.RenderStepped:Connect(function()
		if hideBody then
			local char = player.Character
			if char then
				for _, d in ipairs(char:GetDescendants()) do
					if (d:IsA("BasePart") or d:IsA("Decal")) and d.LocalTransparencyModifier < 1 then d.LocalTransparencyModifier = 1 end
				end
			end
		end
	end)
end

-- вся глава; onMenu — вернуться в главное меню
function Story.start(onMenu)
	Story.cleanup()
	thread = task.spawn(function()
		local clock, stopBlink = intro()
		alarmAndKitchen(clock, stopBlink)
		local food = Breakfast.new(markers)
		trove:add(function() food:destroy() end)
		breakfast(food)
		phoneScene()
		ending(onMenu)
	end)
end

-- убрать всё, что создала глава, и вернуть персонажа в исходное состояние
function Story.cleanup()
	if thread and coroutine.status(thread) ~= "dead" and thread ~= coroutine.running() then
		pcall(task.cancel, thread)
	end
	thread = nil
	trove:clean()
	Audio.stop("alarm")
	Audio.stop("tiktok")
	Audio.stop("birds")
	Audio.stop("garage")
	Audio.muffle(false)
	Hud.objective(nil)
	Hud.marker(nil)
	Hud.hideSay()
	Hud.letterbox(false, 0.2)
	setBodyHidden(false)
	local _, hum, root = Controls.character()
	if hum then
		hum.Sit = false
		hum.PlatformStand = false
	end
	if root then root.Anchored = false end
	state = "idle"
end

function Story.state() return state end
function Story.hideBody(on) setBodyHidden(on) end
function Story.inGame() return state == "roam" or state == "scene" or state == "intro" end

return Story
