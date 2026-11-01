-- Сценарий песочницы: проходит всю главу 1 как игрок (меню → пробуждение → будильник →
-- кухня → завтрак → телефон → конец → снова меню) и делает снимки для рендера.
local mock = ...
local ws = mock.services.Workspace
local CFrame = mock.G.CFrame

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
step(8, "конец главы")
mock.snapshot("ending")
waitFor(function() return mock.find(pg, "ToMenu") ~= nil end, 30, "кнопка В главное меню")
local toMenu = mock.find(pg, "ToMenu")
mock.click(must(mock.find(toMenu, "Button"), "В меню"))
step(4, "снова меню")
-- пауза в новой игре
mock.click(must(mock.find(must(mock.find(pg, "Play"), "Play holder"), "Button"), "кнопка Играть 2"))
waitFor(actionVisible, 40, "снова в кровати")
step(1, "снова проснулись")
mock.key(plr, "P")
step(1, "пауза")
local mm = mock.find(pg, "MainMenu")
if mm then mock.click(must(mock.find(mm, "Button"), "Главное меню")) end
step(3, "из паузы в меню")
print("сценарий пройден, t =", mock.now)
