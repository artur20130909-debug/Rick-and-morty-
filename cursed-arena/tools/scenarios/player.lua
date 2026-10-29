-- Игрок: меню, выбор персонажа, удары, блок, рывки, приёмы, пробуждение. Боты — 2 (по умолчанию).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local plr = Players:GetPlayers()[1]
h.wait(2)
local pg = plr.PlayerGui
local menu = pg:FindFirstChild("CursedMenu")
print("меню открыто:", menu and menu.Menu.Visible)
-- выбрать Повелителя Пустоты через карточку и кнопку
local grid = menu.Menu.Content.Page_chars.Grid
mock.click(grid.VoidLord)
h.wait(0.2)
local det = menu.Menu.Content.Page_chars.DetailsHolder.Details
print("в карточке:", det.CharName.Text, "| кнопка:", det.Select.Text)
mock.click(det.Select)
h.wait(1)
print("CharId:", plr:GetAttribute("CharId"), "Char на модели:", plr.Character:GetAttribute("Char"))
print("меню после выбора:", menu.Menu.Visible)
local hud = pg.CursedHUD.HUD
local slots = hud.Bottom.Slots
print("ячейки:", slots.Slot1.MoveName.Text, "/", slots.Slot2.MoveName.Text, "/", slots.Slot3.MoveName.Text, "/", slots.Slot4.MoveName.Text)
-- к манекенам
local dummies = {}
for _, m in ipairs(workspace.Bots:GetChildren()) do
	if m:GetAttribute("Kind") == "dummy" then dummies[#dummies + 1] = m end
end
print("манекенов:", #dummies)
local target = dummies[1]
local root = plr.Character.HumanoidRootPart
if target then
	local tp = target.HumanoidRootPart.Position
	root.CFrame = CFrame.lookAt(tp + Vector3.new(0, 0, 5), tp)
	mock.setCameraYaw(plr, 0, -0.2, 12)
end
h.wait(0.5)
-- серия M1 (зажатая ЛКМ)
local cvp = workspace.CurrentCamera
mock.mouseButton(plr, 1, true, 640, 360)
h.wait(1.4)
mock.mouseButton(plr, 1, false)
h.wait(0.3)
print("HP манекена после серии:", target and math.floor(target.Humanoid.Health))
-- блок
mock.key(plr, "F", true)
h.wait(0.4)
print("блок у модели:", plr.Character:GetAttribute("Blocking"))
mock.key(plr, "F", false)
h.wait(0.5)
-- рывки
local p0 = root.Position
mock.tap(plr, "Q")
h.wait(0.4)
print("рывок вперёд, сдвиг:", math.floor((root.Position - p0).Magnitude))
mock.key(plr, "D", true)
h.wait(0.05)
p0 = root.Position
mock.tap(plr, "Q")
h.wait(0.35)
mock.key(plr, "D", false)
print("рывок вбок, сдвиг:", math.floor((root.Position - p0).Magnitude))
h.wait(1)
-- приёмы
if target then
	local tp = target.HumanoidRootPart.Position
	root.CFrame = CFrame.lookAt(tp + Vector3.new(0, 0, 6), tp)
end
local function st()
	local c = plr.Character
	local t = {}
	for _, a in ipairs({ "Busy", "Stunned", "Rooted", "Ragdoll", "Blocking", "Silenced" }) do
		if c:GetAttribute(a) then t[#t + 1] = a end
	end
	return table.concat(t, ",")
end
for _, k in ipairs({ "One", "Two", "Three", "Four" }) do
	print("перед " .. k .. ": состояние [" .. st() .. "]")
	mock.tap(plr, k)
	h.wait(2.2)
	print("после " .. k .. ": ячейка", slots["Slot" .. ({ One = 1, Two = 2, Three = 3, Four = 4 })[k]].Time.Text, "HP манекена", target and math.floor(target.Humanoid.Health))
end
-- пробуждение: дадим шкалу через сервер
local Fighters
mock.asServer(function()
	local SS = game:GetService("ServerScriptService")
	Fighters = mock.require(SS.Server.Fighters)
	local Combat = mock.require(SS.Server.Combat)
	Combat.setMeter(Fighters.ofPlayer(plr), 100)
end)
h.wait(0.3)
print("перед G: [" .. st() .. "] шкала", plr.Character:GetAttribute("Meter"))
mock.tap(plr, "G")
h.wait(2)
print("пробуждён:", plr.Character:GetAttribute("Awakened"), "| ячейка 4:", slots.Slot4.MoveName.Text, slots.Slot4.Tag.Text)
mock.tap(plr, "Four")
h.wait(4)
print("после ульты: ячейка 4", slots.Slot4.Time.Text)
-- меню по M и обратно
mock.tap(plr, "M")
h.wait(0.3)
print("меню по M:", menu.Menu.Visible, "HUD скрыт:", not hud.Visible)
mock.click(menu.Menu.Left.Tab_settings)
h.wait(0.1)
mock.click(menu.Menu.Content.Page_settings:FindFirstChild("Row"):FindFirstChild("Stepper").Plus)
h.wait(0.5)
print("ботов:", RS:GetAttribute("BotCount"))
mock.click(menu.Menu.Left.Play)
h.wait(0.3)
print("меню закрыто:", not menu.Menu.Visible)
h.wait(3)
