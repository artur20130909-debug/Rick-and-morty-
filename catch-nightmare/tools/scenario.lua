-- Сценарий песочницы: два игрока проходят основной цикл игры. Возвращает число провалов.
local mock = ...
local game = mock.game
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ws = game:GetService("Workspace")
local fails = 0

local function check(cond, what)
	if cond then
		print("  ok    " .. what)
	else
		print("  FAIL  " .. what)
		fails = fails + 1
	end
end
local function step(name) print("\n== " .. name) end
local function run(s) mock.run(s) end

local function base(p) return ws.Bases:FindFirstChild("Base_" .. tostring(p:GetAttribute("BaseIndex"))) end
local function hrp(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function act(p, ...)
	local args = table.pack(...)
	mock.asClient(p, function() RS.Remotes.Action:FireServer(table.unpack(args, 1, args.n)) end)
	run(0.3)
end
local function near(p, part, off)
	if part:IsA("ProximityPrompt") then part = part.Parent end
	local pos = part:IsA("Attachment") and part.WorldPosition or part.Position
	mock.teleport(p, pos + (off or Vector3.new(0, 0, 3)))
	run(0.1)
end
local function monstersIn(b)
	local n = 0
	for _, sm in ipairs(b.Slots:GetChildren()) do
		if sm:FindFirstChild("Monster") then n = n + 1 end
	end
	return n
end

step("Запуск сервера")
mock.startServer()
run(1)
check(ws:FindFirstChild("Map") ~= nil, "карта построена")
check(#ws.Bases:GetChildren() == 8, "8 баз")
check(RS:FindFirstChild("State") and RS.State:GetAttribute("Phase") == "day", "начался день")
print("  деталей в workspace: " .. mock.partsInWorkspace())

step("Новый игрок Alice")
local alice = mock.addPlayer("Alice", 101)
run(6)
check(alice:GetAttribute("BaseIndex") == 1, "Alice получила базу 1")
check(alice:GetAttribute("Fear") == 50, "стартовый Страх 50")
local ab = base(alice)
local h = hrp(alice)
check(h and (h.Position - ab.Spawn.Position).Magnitude < 6, "Alice появилась на своей базе")
check(alice.PlayerGui:FindFirstChild("HUD") ~= nil, "интерфейс создан")
check(ab.Slots.Slot_1.Pad.PromptAtt.BuyPrompt.Enabled == false and ab.Slots.Slot_5.Pad.PromptAtt.BuyPrompt.Enabled == true, "кнопка покупки 5-й клетки")

step("Первый монстр-подсказка и ловля")
local helper = nil
for _, m in ipairs(ws.Wild:GetChildren()) do
	if m:GetAttribute("Key") == "slipper" then helper = m end
end
check(helper ~= nil, "у базы появился Тапок-Кусака")
if helper then
	local prompt = helper.Root.PromptAtt.CatchPrompt
	near(alice, prompt, Vector3.new(0, 0, 4))
	local ok, why = mock.trigger(alice, prompt)
	check(ok, "подсказка «Поймать» сработала " .. tostring(why or ""))
	run(0.5)
	check(alice:GetAttribute("Carrying") == "Тапок-Кусака", "Alice несёт монстра")
	check(alice.Character.Humanoid.WalkSpeed == 12, "с монстром медленнее (12)")
	check(#ws.Carried:GetChildren() == 1, "модель на голове")
end

step("Доставка на базу")
mock.teleport(alice, ab.Spawn.Position)
run(1)
check(alice:GetAttribute("Carrying") == "", "монстр больше не на голове")
check(monstersIn(ab) == 1, "монстр в клетке")
check(alice:GetAttribute("Caught") == 1, "счётчик поимок 1")
check(alice.Character.Humanoid.WalkSpeed == 16, "скорость снова 16")
local f0 = alice:GetAttribute("Fear")
run(5)
local f1 = alice:GetAttribute("Fear")
check(f1 >= f0 + 4 and f1 <= f0 + 6, "доход +1/с капает (" .. f0 .. " -> " .. f1 .. ")")

step("Второй игрок Bob крадёт")
local bob = mock.addPlayer("Bob", 102)
run(6)
check(bob:GetAttribute("BaseIndex") == 2, "Bob получил базу 2")
local bb = base(bob)
local stealP = ab.Slots.Slot_1.Pad.PromptAtt.StealPrompt
check(stealP.Enabled, "можно украсть у Alice")
near(bob, stealP, Vector3.new(0, 0, -3))
local ok = mock.trigger(bob, stealP)
check(ok, "Bob нажал «Украсть»")
run(0.5)
check(bob:GetAttribute("Carrying") ~= "", "Bob несёт монстра Alice")
check(monstersIn(ab) == 0, "клетка Alice пуста")

step("Alice отбирает обратно")
local tp = hrp(bob):FindFirstChild("TacklePrompt")
check(tp and tp.Enabled, "у Bob появилась подсказка «Отобрать»")
mock.teleport(alice, hrp(bob).Position + Vector3.new(3, 0, 0))
run(0.1)
ok = mock.trigger(alice, tp)
check(ok, "Alice нажала «Отобрать»")
run(0.5)
check(bob:GetAttribute("Carrying") == "" and (alice:GetAttribute("Carrying") ~= "" or monstersIn(ab) == 1), "монстр у Alice (или уже в её клетке)")
check(bob.Character.Humanoid.WalkSpeed == 0, "Bob оглушён")
mock.teleport(alice, ab.Spawn.Position)
run(1.5)
check(monstersIn(ab) == 1, "Alice вернула монстра в клетку")
check(alice:GetAttribute("Caught") == 1, "возврат не считается поимкой")

step("Замок базы")
near(alice, ab.LockPad.Attachment, Vector3.new(0, 0, 2))
ok = mock.trigger(alice, ab.LockPad.Attachment.LockPrompt)
run(0.3)
check(ok and ab:GetAttribute("Locked") == true, "база заперта")
check(stealP.Enabled == false, "украсть нельзя, пока заперто")
check(ab.Door.CanCollide == false, "у хозяина дверь проходима (клиент)")
run(61)
check(ab:GetAttribute("Locked") == false, "замок снялся через 60 с")
check(stealP.Enabled == true, "снова можно украсть")

step("Админ и лавка")
check(alice:GetAttribute("IsAdmin") == true, "в Studio все админы")
act(alice, "admin", "fear 100000")
check(alice:GetAttribute("Fear") >= 100000, "админ: +100K Страха")
act(alice, "buy", "net")
check(alice:GetAttribute("Net") == 2, "куплена сеть 2")
act(alice, "buy", "bait", "bait")
check(alice:GetAttribute("Bait_bait") == 1, "куплена приманка")
act(alice, "buy", "cage")
check(alice:GetAttribute("Cages") == 5, "куплена 5-я клетка")
check(ab.Slots.Slot_6.Pad.PromptAtt.BuyPrompt.Enabled, "следующая клетка — 6-я")
local shopInfo
mock.asClient(alice, function() shopInfo = RS.Remotes.GetShop:InvokeServer() end)
run(0.3)
check(type(shopInfo) == "table" and shopInfo.net == 2 and shopInfo.left.bait >= 2, "GetShop отвечает")

step("Лавка открывается у прилавка")
local shopPrompt = ws.Map.Shop:FindFirstChild("ShopPrompt", true)
near(alice, shopPrompt, Vector3.new(0, 0, 4))
ok = mock.trigger(alice, shopPrompt)
run(0.6)
local hud = alice.PlayerGui.HUD
check(ok and hud.Shop.Visible, "окно лавки открыто")
local rows = 0
for _, c in ipairs(hud.Shop:FindFirstChildOfClass("ScrollingFrame"):GetChildren()) do
	if c:IsA("Frame") then rows = rows + 1 end
end
check(rows == 5, "в лавке 5 сетей (" .. rows .. ")")

step("Приманка в лесу")
mock.teleport(alice, Vector3.new(0, 4, 120))
run(0.2)
local before = #ws.Wild:GetChildren()
act(alice, "useBait", "bait")
check(alice:GetAttribute("Bait_bait") == 0, "приманка потрачена")
run(3.5)
local reserved = nil
for _, m in ipairs(ws.Wild:GetChildren()) do
	local lbl = m:FindFirstChild("Root") and m.Root:FindFirstChild("Label")
	if lbl and lbl:FindFirstChildOfClass("TextLabel") then
		for _, t in ipairs(lbl:GetChildren()) do
			if t:IsA("TextLabel") and string.find(t.Text, "Alice", 1, true) then reserved = m end
		end
	end
end
check(reserved ~= nil, "из приманки вылез монстр для Alice")

step("Кровавая луна")
act(alice, "admin", "bloodmoon")
run(1)
check(RS.State:GetAttribute("Phase") == "night" and RS.State:GetAttribute("Event") == "bloodmoon", "ночь Кровавой луны")
local h2 = alice.Character.Head:FindFirstChild("NightLight")
check(h2 ~= nil, "ночью фонарик на голове")
mock.teleport(bob, Vector3.new(100, 4, 0))
run(40)
check(#ws.Wild:GetChildren() >= 8, "ночью много монстров (" .. #ws.Wild:GetChildren() .. ")")
act(alice, "admin", "spawn secret")
run(1)
local secret = nil
for _, m in ipairs(ws.Wild:GetChildren()) do
	if m:GetAttribute("Key") == "nobody" then secret = m end
end
check(secret ~= nil, "админ: секретный монстр появился")
if secret then
	local sp = secret.Root.PromptAtt.CatchPrompt
	near(alice, sp, Vector3.new(0, 0, 3))
	mock.trigger(alice, sp)
	run(0.3)
	check(alice:GetAttribute("Carrying") == "", "сетью 2 секретного не поймать")
end

step("Испуг и смерть с монстром")
-- Bob ловит монстра в лесу и умирает: монстр остаётся в лесу
local any = nil
for _, m in ipairs(ws.Wild:GetChildren()) do
	if (m:GetAttribute("NeedNet") or 9) <= 1 and m:FindFirstChild("Root") and m.Root:FindFirstChild("PromptAtt") then any = m break end
end
if any then
	local cp = any.Root.PromptAtt.CatchPrompt
	near(bob, cp, Vector3.new(0, 0, 3))
	mock.trigger(bob, cp)
	run(0.3)
end
local carried = bob:GetAttribute("Carrying") ~= ""
check(carried or any == nil, "Bob поймал монстра")
if carried then
	local nWild = #ws.Wild:GetChildren()
	bob.Character.Humanoid.Health = 0
	run(0.5)
	check(bob:GetAttribute("Carrying") == "", "после смерти монстр не на голове")
	check(#ws.Wild:GetChildren() >= nWild, "монстр вернулся в лес")
	run(6)
	local hb = hrp(bob)
	check(hb and (hb.Position - bb.Spawn.Position).Magnitude < 6, "Bob возродился на своей базе")
end

step("Удача за Robux")
mock.asServer(function()
	local C = require(RS.Shared.Config)
	C.Products.ServerLuck.id = 777
end)
run(0.1)
local dec = mock.buyProduct(alice, 777)
run(0.2)
check(tostring(dec) == "Enum.ProductPurchaseDecision.PurchaseGranted", "покупка удачи выдана (" .. tostring(dec) .. ")")
check(RS.State:GetAttribute("ServerLuck") == 2, "удача сервера ×2")

step("Продажа")
local fs = alice:GetAttribute("Fear")
local sellP = ab.Slots.Slot_1.Pad.PromptAtt.SellPrompt
near(alice, sellP, Vector3.new(0, 0, -3))
ok = mock.trigger(alice, sellP)
run(0.3)
check(ok and alice:GetAttribute("Fear") >= fs + 40, "продан Тапок за 40")
check(monstersIn(ab) == 0, "клетка пуста после продажи")

step("Выход вора с украденным")
-- Alice снова ловит монстра, кладёт в клетку, Bob крадёт и выходит
act(alice, "admin", "day")
run(1)
check(RS.State:GetAttribute("Phase") == "day", "снова день")
-- положим монстра Alice напрямую через ловлю новичка
local wildList = ws.Wild:GetChildren()
local pick = nil
for _, m in ipairs(wildList) do
	if (m:GetAttribute("NeedNet") or 9) <= 2 then pick = m break end
end
if pick then
	local cp = pick.Root.PromptAtt.CatchPrompt
	near(alice, cp, Vector3.new(0, 0, 3))
	mock.trigger(alice, cp)
	run(0.3)
	mock.teleport(alice, ab.Spawn.Position)
	run(1)
end
check(monstersIn(ab) >= 1, "у Alice снова есть монстр")
local slotWith = nil
for _, sm in ipairs(ab.Slots:GetChildren()) do
	if sm:FindFirstChild("Monster") then slotWith = sm end
end
if slotWith then
	local sp = slotWith.Pad.PromptAtt.StealPrompt
	near(bob, sp, Vector3.new(0, 0, -3))
	mock.trigger(bob, sp)
	run(0.3)
	check(bob:GetAttribute("Carrying") ~= "", "Bob украл")
	local n0 = monstersIn(ab)
	mock.removePlayer(bob)
	run(1)
	check(monstersIn(ab) == n0 + 1, "после выхода вора монстр вернулся к Alice")
	check(ws.Bases.Base_2:GetAttribute("OwnerId") == 0, "база Bob освободилась")
end

step("Сохранение и перезаход")
local fearBefore = alice:GetAttribute("Fear")
mock.removePlayer(alice)
run(1)
local saved = mock.dsData["CatchNightmare_v1/global"]["u_101"]
check(saved ~= nil, "данные Alice сохранены")
print("  сохранено: " .. tostring(saved and string.sub(saved, 1, 200)))
-- имитируем час отсутствия
local data = mock.jsonDecode(saved)
data.last = data.last - 3600
mock.dsData["CatchNightmare_v1/global"]["u_101"] = mock.jsonEncode(data, "x")
local alice2 = mock.addPlayer("Alice", 101)
run(7)
local ab2 = base(alice2)
check(alice2:GetAttribute("Net") == 2 and alice2:GetAttribute("Cages") == 5, "сеть и клетки загрузились")
check(monstersIn(ab2) >= 1, "монстры снова в клетках")
check(alice2:GetAttribute("Fear") > fearBefore, "начислен доход за время отсутствия (" .. fearBefore .. " -> " .. alice2:GetAttribute("Fear") .. ")")

step("Интерфейс: вкладки лавки, кнопки, скример")
local DATA = mock.DATA
local function click(btn) mock.I.fireEvent(btn[DATA], "Activated") run(0.4) end
local function findButton(root, text)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("TextButton") and string.find(d.Text, text, 1, true) then return d end
	end
	return nil
end
local hud2 = alice2.PlayerGui.HUD
click(findButton(hud2, "Лавка"))
check(hud2.Shop.Visible, "кнопка «Лавка» открывает окно")
local list = hud2.Shop:FindFirstChildOfClass("ScrollingFrame")
local function rowsNow()
	local n = 0
	for _, c in ipairs(list:GetChildren()) do if c:IsA("Frame") then n = n + 1 end end
	return n
end
click(findButton(hud2.Shop, "Приманки"))
check(rowsNow() == 4, "вкладка приманок: 4 строки")
local buyBait = nil
for _, c in ipairs(list:GetChildren()) do
	if c:IsA("Frame") then
		local b = c:FindFirstChildOfClass("TextButton")
		if b and string.find(b.Text, "100", 1, true) then buyBait = b end
	end
end
check(buyBait ~= nil, "есть кнопка покупки обычной приманки")
if buyBait then click(buyBait) end
check(alice2:GetAttribute("Bait_bait") == 1, "приманка куплена кнопкой")
click(findButton(hud2.Shop, "Клетки"))
check(rowsNow() == 2, "вкладка клеток")
click(findButton(hud2.Shop, "Robux"))
check(rowsNow() == 3, "вкладка Robux")
click(findButton(hud2.Shop, "✕"))
check(not hud2.Shop.Visible, "окно закрывается")
run(0.3)
local baitBtn = findButton(hud2, "🍖 ×1")
check(baitBtn ~= nil and baitBtn.Visible, "на панели появилась приманка ×1")
click(findButton(hud2, "Админ"))
check(hud2.Admin.Visible, "админ-панель открывается")
local nWild = #ws.Wild:GetChildren()
click(findButton(hud2.Admin, "Легендарный"))
run(0.5)
check(#ws.Wild:GetChildren() == nWild + 1, "кнопка админа спавнит монстра")
mock.asServer(function() RS.Remotes.Fx:FireClient(alice2, "scare", "nobody", "secret") end)
run(0.3)
check(alice2.PlayerGui.Scare.Frame.Visible, "скример показан")
run(1.5)
check(not alice2.PlayerGui.Scare.Frame.Visible, "скример скрылся")

step("Полный цикл дня и ночи")
run(300)
check(RS.State:GetAttribute("Phase") == "night", "день сменился ночью сам")
run(200)
check(RS.State:GetAttribute("Phase") == "day", "ночь сменилась днём")

print("\nпровалов: " .. fails)
return fails
