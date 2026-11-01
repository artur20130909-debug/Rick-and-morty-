-- Сценарий песочницы: проходит всю историю как игрок (меню → глава 1: пробуждение, будильник,
-- кухня, завтрак, телефон, пиксельный мир → глава 2: гараж, улица, корабли, база камераменов →
-- конец → меню → «Главы» → глава 2 сразу → пауза) и делает снимки для рендера.
local mock = ...
local ws = mock.services.Workspace
local CFrame = mock.G.CFrame
local Vector3 = mock.G.Vector3

local function step(sec, label)
	mock.run(sec)
	if label then print(string.format("t=%.1f  %s", mock.now, label)) end
end
local function promptOn(partName)
	local list = mock.findAll(ws, function(x)
		return x.ClassName == "ProximityPrompt" and x.Name == "RM_StoryPrompt" and x.Parent and x.Parent.Name == partName
	end)
	return list[1]
end
local function must(x, what)
	if not x then error("не найдено: " .. what) end
	return x
end
-- ждать (в игровом времени), пока cond() не станет истинным
local function waitFor(cond, timeout, what)
	local t0 = mock.now
	while not cond() do
		mock.run(0.2)
		if mock.now - t0 > (timeout or 30) then error("не дождались: " .. (what or "?")) end
	end
end
local pgRef
local function actionVisible()
	local a = mock.find(pgRef, "Action")
	return a and a.Visible and #a:GetChildren() > 1
end
-- нажать клавишу, когда появится кнопка действия
local function press(plr, key, what)
	waitFor(actionVisible, 40, "кнопка действия: " .. (what or key))
	mock.key(plr, key)
	mock.run(0.3)
end

mock.startServer()
step(0.5)
local plr = mock.addPlayer("Morty")
step(4, "меню")
mock.snapshot("menu")

-- главное меню: настройки (открыть/закрыть), затем «Играть»
local pg = plr.PlayerGui
pgRef = pg
local settingsBtn = must(mock.find(must(mock.find(pg, "Settings"), "Settings holder"), "Button"), "кнопка Настройки")
mock.click(settingsBtn)
step(0.6, "настройки открыты")
local fx = mock.find(pg, "Effects")
if fx then mock.click(must(mock.find(fx, "Opt2"), "Opt2")) end
mock.click(must(mock.find(must(mock.find(pg, "Done"), "Done holder"), "Button"), "Готово"))
step(0.5, "настройки закрыты")
mock.click(must(mock.find(must(mock.find(pg, "Play"), "Play holder"), "Button"), "кнопка Играть"))
step(3, "влетели в портал")
step(9, "просыпаемся")
mock.snapshot("wake")
press(plr, "Space", "встать")
step(5.5, "встали")
mock.snapshot("stand")

-- будильник
waitFor(function() return promptOn("Body") ~= nil end, 20, "подсказка будильника")
local p = promptOn("Body")
mock.triggerPrompt(p, plr)
step(6, "будильник выключен")

-- идём на кухню (телепорт) — проверяем, что задание засчитано
local char = plr.Character
char.HumanoidRootPart.CFrame = CFrame.new(40.6, 3, 22)
step(2.5, "на кухне")
waitFor(function() return promptOn("Seat") ~= nil end, 20, "подсказка стула")
local seat = promptOn("Seat")
mock.triggerPrompt(seat, plr)
step(3, "сели за стол")
mock.snapshot("seated")
press(plr, "E", "хлопья")
step(5, "насыпали хлопья")
press(plr, "E", "молоко")
step(5, "налили молоко")
mock.snapshot("bowl")
for i = 1, 5 do
	press(plr, "E", "ложка")
	step(2.3, "ложка " .. i)
end
step(4, "наелся")
press(plr, "F", "телефон")
step(6.5, "телефон: блокировка → ТикТок")
mock.snapshot("phone")
step(4, "ролик 1")
press(plr, "E", "листать")
step(4, "ролик 2 + лаги")
mock.snapshot("lag")
step(4.5, "глитч")
mock.snapshot("glitch")
step(6, "мысль Морти")
step(3.5, "щупальца из телефона")
mock.snapshot("tentacles")
-- ждём пиксельный мир: персонаж окажется около ORIGIN (400, 300, 0)
waitFor(function() local r = plr.Character.HumanoidRootPart; return r.Position.Y > 250 end, 30, "пиксельный мир")
step(3, "пиксельные руки")
mock.snapshot("pixelhands")
waitFor(function() return mock.find(pg, "Objective") and mock.find(pg, "Objective").Visible end, 20, "задание найди выход")
step(1.5, "коридор")
mock.snapshot("corridor")
-- идём по коридору (телепорт за линию засады)
plr.Character.HumanoidRootPart.CFrame = CFrame.new(400, 303, 80)
step(4, "засада")
mock.snapshot("ambush")
step(4, "Рик стреляет")
mock.snapshot("rick")
waitFor(function()
	local o = mock.find(pg, "Objective")
	local t = o and o:FindFirstChild("Text")
	return o and o.Visible and t and t.Text == "Беги в портал"
end, 40, "задание «Беги в портал»")
step(1, "разговор с Риком закончен")
-- бежим в портал
do local r = plr.Character.HumanoidRootPart; r.CFrame = CFrame.new(400, 303, r.Position.Z + 24) end
step(3, "вошли в портал")

-- ГЛАВА 2: заставка → гараж
local function objectiveIs(text)
	local o = mock.find(pg, "Objective")
	local t = o and o:FindFirstChild("Text")
	return o and o.Visible and t and string.find(t.Text, text, 1, true) ~= nil
end
local function root() return plr.Character.HumanoidRootPart end
-- повернуть камеру игрока (у клиента своя камера)
local function lookAt(eye, target) mock.clientCtx(plr).camera.CFrame = CFrame.lookAt(eye, target) end
local function chapter2(tag)
	waitFor(function() local p = root().Position; return p.Y < 50 and p.X > 56 and p.X < 81 and p.Z > 0 end, 40, "гараж")
	step(1.2, "вываливаемся из портала")
	mock.snapshot("garage_land" .. tag)
	waitFor(function() return objectiveIs("Подойди к Рику") end, 40, "задание «Подойди к Рику»")
	step(1, "Рик идёт к экрану")
	root().CFrame = CFrame.new(72.2, 3, 13.5)
	step(3, "подошли к Рику")
	step(5, "досье на экране")
	mock.snapshot("lab_devourers" .. tag)
	step(9, "карта мультивселенной")
	mock.snapshot("lab_map" .. tag)
	waitFor(function() return objectiveIs("Открой ворота") end, 90, "задание «Открой ворота»")
	mock.snapshot("lab_alarm" .. tag)
	local btn = must(promptOn("DoorButton"), "подсказка кнопки ворот")
	mock.triggerPrompt(btn, plr)
	step(4, "ворота открылись")
	mock.snapshot("door_open" .. tag)
	waitFor(function() return objectiveIs("Выйди на улицу") end, 20, "задание «Выйди на улицу»")
	root().CFrame = CFrame.new(68.85, 2.1, -6)
	step(5, "дым над домом соседей")
	mock.snapshot("smoke" .. tag)
	step(7, "небо темнеет, разлом")
	mock.snapshot("rift" .. tag)
	step(9, "корабли вылетают")
	mock.snapshot("ships" .. tag)
	step(8, "кольцо кораблей")
	mock.snapshot("surround" .. tag)
	step(6, "граната")
	mock.snapshot("grenade" .. tag)
	-- база камераменов
	waitFor(function() return root().Position.X < -300 end, 60, "база камераменов")
	step(0.6, "вываливаемся на базе")
	mock.snapshot("base_land" .. tag)
	step(3.5, "оглядываемся")
	mock.snapshot("base_look" .. tag)
	waitFor(function() return objectiveIs("Осмотрись") end, 60, "задание «Осмотрись»")
	step(1, "осматриваемся")
	local O = Vector3.new(-420, 300, 0)
	local eye = root().Position + Vector3.new(0, 1.5, 0)
	lookAt(eye, O + Vector3.new(-18, 6.5, -7.3))
	step(1.5, "смотрим на камераменов")
	mock.snapshot("base_cameramen" .. tag)
	step(2)
	lookAt(eye, O + Vector3.new(18, 6.5, -7.3))
	step(3.5, "смотрим на спикерменов")
	mock.snapshot("base_speakermen" .. tag)
	lookAt(eye, O + Vector3.new(0, 34, 38))
	step(3, "смотрим на титана")
	mock.snapshot("base_titan" .. tag)
	step(9, "все смотрят на Морти")
	mock.snapshot("base_stare" .. tag)
end
chapter2("")
waitFor(function() return mock.find(pg, "ToMenu") ~= nil end, 90, "кнопка В главное меню")
step(1, "конец главы 2")
mock.snapshot("ending")
local toMenu = mock.find(pg, "ToMenu")
mock.click(must(mock.find(toMenu, "Button"), "В меню"))
step(4, "снова меню")
-- меню «Главы» → глава 2 сразу
mock.click(must(mock.find(must(mock.find(pg, "Chapters"), "Chapters holder"), "Button"), "кнопка Главы"))
step(1, "окно глав")
mock.snapshot("chapters")
mock.click(must(mock.find(must(mock.find(pg, "Chapter2"), "Chapter2 holder"), "Button"), "Глава 2"))
step(3, "глава 2 с меню")
waitFor(function() local p = root().Position; return p.Y < 50 and p.X > 56 and p.X < 81 and p.Z > 0 end, 40, "гараж (с меню)")
step(6, "в гараже")
mock.key(plr, "P")
step(1, "пауза")
local mm = mock.find(pg, "MainMenu")
if mm then mock.click(must(mock.find(mm, "Button"), "Главное меню")) end
step(3, "из паузы в меню")
-- пауза в новой игре (глава 1)
mock.click(must(mock.find(must(mock.find(pg, "Play"), "Play holder"), "Button"), "кнопка Играть 2"))
waitFor(actionVisible, 40, "снова в кровати")
step(1, "снова проснулись")
mock.key(plr, "P")
step(1, "пауза")
mm = mock.find(pg, "MainMenu")
if mm then mock.click(must(mock.find(mm, "Button"), "Главное меню")) end
step(3, "из паузы в меню")
-- после выхода в меню гараж вернулся как был (ворота закрыты, экран «ожидание»)
do
	local door = must(mock.find(ws, "GarageDoor"), "ворота гаража")
	if math.abs(door.Size.Y - 9) > 0.01 then error("ворота гаража не закрылись: высота " .. door.Size.Y) end
	local idle = must(mock.find(ws, "Idle"), "надпись экрана")
	if not idle.Visible then error("экран лаборатории не вернулся в «ожидание»") end
end
print("сценарий пройден, t =", mock.now)
