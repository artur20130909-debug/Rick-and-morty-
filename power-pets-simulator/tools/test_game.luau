-- Сквозной тест игры на моке: сервер + клиент в одной VM.
-- Проходит путь игрока: вход, клики, продажа, монеты, яйца, питомцы, магазин, миры,
-- перерождение, выход, сохранение, повторный вход, сбой DataStore, выключение сервера.
local G = M.G
local Vector3, CFrame, UDim2 = G.Vector3, G.CFrame, G.UDim2
local failures = 0

local function check(condition, message)
	if condition then
		print("  ok   " .. message)
	else
		failures += 1
		print("  FAIL " .. message)
	end
end

local function svc(name)
	return M.service(name)
end

print("== сборка дерева (как Rojo)")
-- Свои звуки: ID числом и строкой из цифр (как после tools/upload_sounds.py или ручной вставки).
local idsPath = "src/shared/Config/SoundIds.lua"
SOURCES[idsPath] = string.gsub(SOURCES[idsPath], 'Coin = ""', "Coin = 123456")
SOURCES[idsPath] = string.gsub(SOURCES[idsPath], 'Music_Space = ""', 'Music_Space = "777"')
M.buildTree()
local SSS, RS, Workspace = svc("ServerScriptService"), svc("ReplicatedStorage"), svc("Workspace")
local StarterPlayer = svc("StarterPlayer")
local ProximityPromptService = svc("ProximityPromptService")

print("== запуск сервера")
M.runScript(SSS.Server.Main, M.SERVER)
M.run(0.5)
check(#M.errors == 0, "сервер стартовал без ошибок")
local worlds = Workspace:FindFirstChild("Worlds")
check(worlds ~= nil, "папка Worlds построена")
local partCount = 0
for _, item in ipairs(worlds:GetDescendants()) do
	if item:IsA("BasePart") then
		partCount += 1
	end
end
print("  деталей в мирах:", partCount)
for _, worldId in ipairs({ "Forest", "Desert", "Space" }) do
	check(#worlds[worldId].Coins:GetChildren() == 30, worldId .. ": 30 монет")
end
check(#svc("CollectionService"):GetTagged("Portal") == 4, "4 портала")

local Modules = SSS.Server.Modules
local DataService = M.requireIn(M.SERVER, Modules.DataService)
local PlayerState = M.requireIn(M.SERVER, Modules.PlayerState)
local PetService = M.requireIn(M.SERVER, Modules.PetService)
local remotes = RS.Remotes

print("== игрок заходит")
local player, ctx = M.addPlayer("Tester", 1001)
M.run(0.3)
local spawnLocation = worlds.Forest.Spawn.SpawnLocation
M.spawnCharacter(player, spawnLocation.Position)
M.runScript(StarterPlayer.StarterPlayerScripts.Client.Main, ctx)
M.run(3)
check(player:GetAttribute("DataLoaded") == true, "данные загружены")
check(player:GetAttribute("SaveDisabled") == false, "сохранение включено")
check(player.leaderstats["Сила"].Value == 0, "leaderstats: Сила = 0")
check(player.leaderstats["Перерождения"].Value == 0, "leaderstats: Перерождения = 0")
local gui = player.PlayerGui.PowerPetsGui
local root = gui:FindFirstChild("Root")
check(root ~= nil, "интерфейс построен")
local clickButton = root:FindFirstChild("ClickButton")
check(clickButton ~= nil, "кнопка КЛИК есть")
check(root.PanelLayer:FindFirstChild("Pets") ~= nil and root.PanelLayer:FindFirstChild("Shop") ~= nil, "окна созданы")
local function panelPart(name, ...)
	local node = root.PanelLayer[name].Body
	for _, child in ipairs({ ... }) do
		node = node[child]
	end
	return node
end

-- HUD
local function findText(container, pattern)
	for _, item in ipairs(container:GetDescendants()) do
		if item:IsA("TextLabel") and string.find(item.Text, pattern, 1, true) then
			return item
		end
	end
	return nil
end
check(findText(root.TopBar, "0 / 50") ~= nil, "счётчик рюкзака «0 / 50»")
check(findText(root, "+1 силы за клик") ~= nil, "подпись силы за клик")
check(findText(root, "ЛЕС") ~= nil, "плашка мира «ЛЕС» (заглавные кириллицей)")
local forestPortalStatus = worlds.Forest.Portal_Desert:FindFirstChild("Status", true)
check(forestPortalStatus.Text == "Закрыто: 0 / 10K силы", "табличка портала для игрока: " .. forestPortalStatus.Text)
-- монеты крутятся на клиенте
local someCoin = worlds.Forest.Coins:GetChildren()[2]
local coinCFrame = someCoin.CFrame
M.run(0.2)
check(someCoin.CFrame ~= coinCFrame and (someCoin.CFrame.Position - coinCFrame.Position).Magnitude < 1, "монеты крутятся и покачиваются")

print("== все питомцы собираются (обычные и золотые)")
local Pets = M.requireIn(ctx, RS.Shared.Config.Pets)
local PetBuilder = M.requireIn(ctx, RS.Shared.Modules.PetBuilder)
local built, minParts, maxParts = 0, math.huge, 0
for petId in pairs(Pets) do
	for _, golden in ipairs({ false, true }) do
		local model
		M.inCtx(ctx, function()
			model = PetBuilder.Build(petId, golden)
		end)
		if model and model.PrimaryPart then
			built += 1
			local parts = 0
			for _, item in ipairs(model:GetDescendants()) do
				if item:IsA("BasePart") then
					parts += 1
				end
			end
			minParts = math.min(minParts, parts)
			maxParts = math.max(maxParts, parts)
			local _, size = model:GetBoundingBox()
			if size.Magnitude > 9 then
				print("  крупный питомец:", petId, size)
			end
			model:Destroy()
		else
			print("  не собрался:", petId, golden)
		end
	end
end
print("  деталей в питомце: от", minParts, "до", maxParts)
check(built == 60, "собраны все 30 питомцев ×2")

print("== конфиги и форматирование")
local Eggs = M.requireIn(M.SERVER, RS.Shared.Config.Eggs)
local Formulas = M.requireIn(M.SERVER, RS.Shared.Modules.Formulas)
local Format = M.requireIn(M.SERVER, RS.Shared.Modules.Format)
local Worlds = M.requireIn(M.SERVER, RS.Shared.Config.Worlds)
for _, eggId in ipairs(Eggs.Order) do
	local chances = Formulas.EggChances(eggId)
	local sum = 0
	for petId, chance in pairs(chances) do
		sum += chance
		assert(Pets[petId], petId)
	end
	check(math.abs(sum - 100) < 1e-6, eggId .. ": шансы в сумме 100%")
	check(Worlds[Eggs[eggId].World] ~= nil, eggId .. ": мир существует")
end
local rng = G.Random.new(7)
local counts = {}
for _ = 1, 20000 do
	local petId = Formulas.RollEgg("ForestEgg", rng)
	counts[petId] = (counts[petId] or 0) + 1
end
print(string.format("  20000 открытий лесного яйца: Котёнок %.1f%%, Щенок %.1f%%, Лис %.1f%%, Сова %.2f%%, Дух %.2f%%",
	(counts.Kitten or 0) / 200, (counts.Puppy or 0) / 200, (counts.Fox or 0) / 200, (counts.Owl or 0) / 200, (counts.ForestSpirit or 0) / 200))
check(math.abs((counts.Kitten or 0) / 200 - 60) < 2 and math.abs((counts.ForestSpirit or 0) / 200 - 0.5) < 0.3, "распределение редкостей похоже на 60/25/10/4.5/0.5")
local cases = {
	{ 0, "0" }, { 12.5, "12.5" }, { 999, "999" }, { 1000, "1K" }, { 1234, "1.23K" }, { 15000, "15K" },
	{ 999950, "1M" }, { 1500000, "1.5M" }, { 2.5e9, "2.5B" }, { 1e15, "1Qa" },
}
for _, case in ipairs(cases) do
	check(Format.Number(case[1]) == case[2], "Format.Number(" .. case[1] .. ") = " .. Format.Number(case[1]))
end
check(Format.Multiplier(1.2) == "x1.2" and Format.Multiplier(50) == "x50", "Format.Multiplier")
check(Format.Percent(4.5) == "4.5%" and Format.Percent(0.5) == "0.5%" and Format.Percent(60) == "60%", "Format.Percent")
check(Format.Full(1234567) == "1 234 567", "Format.Full")

local function press(button)
	M.inCtx(ctx, function()
		M.fire(M.event(button, "Activated"))
	end)
end
local function invoke(remote, ...)
	local results
	local args = table.pack(...)
	M.inCtx(ctx, function()
		results = table.pack(remote:InvokeServer(table.unpack(args, 1, args.n)))
	end)
	M.run(0.3)
	return table.unpack(results or {}, 1, results and results.n or 0)
end

print("== свои 3D-иконки")
local IconModels = M.requireIn(ctx, StarterPlayer.StarterPlayerScripts.Client.UI.IconModels)
local Icons = M.requireIn(ctx, StarterPlayer.StarterPlayerScripts.Client.UI.Icons)
local iconCount = 0
for _, name in ipairs(IconModels.Names) do
	local frame
	M.inCtx(ctx, function()
		frame = Icons.Create(root, name, { Size = UDim2.fromOffset(60, 60) })
	end)
	if frame and frame:IsA("ViewportFrame") and frame.CurrentCamera then
		local parts = 0
		for _, item in ipairs(frame:GetDescendants()) do
			if item:IsA("BasePart") then
				parts += 1
			end
		end
		if parts >= 3 then
			iconCount += 1
		else
			print("  мало деталей в иконке", name, parts)
		end
		frame:Destroy()
	end
end
print("  иконок:", iconCount, table.concat(IconModels.Names, ", "))
check(iconCount == #IconModels.Names and iconCount >= 20, "все 3D-иконки собираются")

-- обводка крутящейся иконки всегда позади деталей (иначе корона чернеет на полуобороте)
local spinView
M.inCtx(ctx, function()
	local _
	_, spinView = Icons.Create(root, "Crown", { Size = UDim2.fromOffset(120, 120), Animate = "Spin", Speed = 2 })
end)
local outlinesBehind = spinView and spinView.Outlines and #spinView.Outlines > 0
for _ = 1, 8 do
	M.run(0.4)
	local look = spinView.Camera.CFrame.LookVector
	for _, pair in ipairs(spinView.Outlines or {}) do
		if (pair[1].Position - pair[2].Position):Dot(look) <= 0 then
			outlinesBehind = false
		end
	end
end
check(outlinesBehind, "обводка крутящейся 3D-иконки остаётся за деталями при любом повороте")
M.inCtx(ctx, function()
	spinView:Destroy()
end)

-- анимированные иконки меню (PivotTo каждый кадр) не «разваливаются» со временем
local pawModel = root.SideMenu.Pets.Face:FindFirstChild("View3D") and root.SideMenu.Pets.Face.View3D:FindFirstChildOfClass("Model")
M.run(6)
local pawOk = pawModel ~= nil
if pawModel then
	local pivot = pawModel:GetPivot()
	local right, up = pivot.RightVector, pivot.UpVector
	pawOk = math.abs(right.Magnitude - 1) < 1e-6 and math.abs(up.Magnitude - 1) < 1e-6 and math.abs(right:Dot(up)) < 1e-6
end
check(pawOk, "иконка меню после 6 с анимации осталась ровной (поворот ортонормирован)")

print("== рельеф и мир")
check(#M.terrainFills > 100, "рельеф Terrain построен (" .. #M.terrainFills .. " заливок)")
local column = M.terrainColumn(-72, -58)
local hasWater = false
for _, item in ipairs(column) do
	if item[3] == "Water" then
		hasWater = true
	end
end
check(hasWater, "в лесу есть озеро с водой")
local coinsOnGround = true
for _, worldId in ipairs({ "Forest", "Desert", "Space" }) do
	for _, coinPart in ipairs(worlds[worldId].Coins:GetChildren()) do
		local origin = worlds[worldId]:FindFirstChild("Spawn")
		local _ = origin
		if coinPart.Position.Y < -20 + (worldId == "Space" and 60 or 0) then
			coinsOnGround = false
		end
	end
end
check(coinsOnGround, "монеты лежат на земле, а не под ней")
check(worlds.Forest:FindFirstChild("ShopStall") ~= nil and worlds.Forest:FindFirstChild("Fountain") ~= nil and worlds.Forest:FindFirstChild("WelcomeArch") ~= nil, "лавка, фонтан и арка построены")
check(#svc("CollectionService"):GetTagged("Spin") >= 7, "крутящиеся детали (мельница, кольца порталов, монеты у продажи)")

print("== табло яиц и свои подсказки")
local playerGui = player.PlayerGui
check(playerGui:FindFirstChild("EggDisplay_ForestEgg") ~= nil, "табло лесного яйца с 3D-питомцами")
local display = playerGui:FindFirstChild("EggDisplay_ForestEgg")
local displayViews = 0
for _, item in ipairs(display and display:GetDescendants() or {}) do
	if item:IsA("ViewportFrame") then
		displayViews += 1
	end
end
check(displayViews == 5, "на табло 5 питомцев в 3D")
local stallPrompt = worlds.Forest.ShopStall.Counter.PromptPoint.OpenShop
M.inCtx(ctx, function()
	M.fire(M.event(svc("ProximityPromptService"), "PromptShown"), stallPrompt, G.Enum.ProximityPromptInputType.Touch)
end)
M.run(0.4)
local stallGui = playerGui:FindFirstChild("Prompt_OpenShop")
check(stallGui ~= nil, "своя кнопка у лавки магазина")
if stallGui then
	press(stallGui.Card)
	M.run(0.5)
end
check(root.PanelLayer.Shop.Visible, "лавка открывает окно магазина")
press(panelPart("Shop", "Header", "Close"))
M.run(0.4)
M.inCtx(ctx, function()
	M.fire(M.event(svc("ProximityPromptService"), "PromptHidden"), stallPrompt)
end)
M.run(0.4)
check(playerGui:FindFirstChild("Prompt_OpenShop") == nil, "кнопка исчезает, когда отходишь")

print("== звуки из библиотеки Roblox")
M.run(8)
local library = RS:FindFirstChild("SoundLibrary")
check(library ~= nil and library:GetAttribute("Ready") == true, "сервер подобрал звуки (" .. tostring(M.audioSearches) .. " поисков)")
local soundsFolder = svc("SoundService"):FindFirstChild("PowerPetsSounds")
local clickSound = soundsFolder and soundsFolder:FindFirstChild("Click")
check(clickSound and string.find(clickSound.SoundId, "rbxassetid://") ~= nil and not string.find(clickSound.SoundId, "1$"), "клиент взял рабочий звук: " .. tostring(clickSound and clickSound.SoundId))
check(soundsFolder and soundsFolder:FindFirstChild("Music_Forest") ~= nil and soundsFolder.Music_Forest.IsPlaying, "музыка леса играет")
check(library and library.Coin.Value == "rbxassetid://123456" and library.Coin:GetAttribute("Candidates") == "", "свой ID монеты из SoundIds, без поиска")
check(library and library.Music_Space.Value == "rbxassetid://777", "свой ID музыки космоса из SoundIds")
local coinSound = soundsFolder and soundsFolder:FindFirstChild("Coin")
check(coinSound and coinSound.SoundId == "rbxassetid://123456", "клиент играет свой звук монеты: " .. tostring(coinSound and coinSound.SoundId))

print("== клики")
for _ = 1, 30 do
	press(clickButton)
	M.step(1 / 30)
end
M.run(0.3)
local strength = player:GetAttribute("Strength")
print("  сила после секунды кликов:", strength)
check(strength >= 10 and strength <= 16, "клики засчитываются (~14/с)")
check(player.leaderstats["Сила"].Value == strength, "leaderstats обновился")

print("== защита от спама")
M.run(2)
local before = player:GetAttribute("Strength")
M.inCtx(ctx, function()
	for _ = 1, 100 do
		remotes.Click:FireServer()
	end
end)
M.run(0.2)
local gained = player:GetAttribute("Strength") - before
print("  100 мгновенных кликов дали:", gained)
check(gained <= 8, "сервер режет спам")

print("== полный рюкзак")
for _ = 1, 160 do
	press(clickButton)
	M.step(1 / 15)
end
M.run(0.3)
check(player:GetAttribute("Strength") == player:GetAttribute("Capacity"), "сила упёрлась в рюкзак (50)")

print("== продажа")
local hrp = player.Character.HumanoidRootPart
local sellPad = worlds.Forest.SellZone.SellPad
hrp.CFrame = CFrame.new(sellPad.Position + Vector3.new(2, 3, 1))
M.run(0.6)
check(player:GetAttribute("Strength") == 0, "сила продана")
check(player:GetAttribute("Coins") == 50, "получено 50 монет")

print("== монета на земле")
local coin = worlds.Forest.Coins:GetChildren()[1]
local value = coin:GetAttribute("Value")
local coinsBefore = player:GetAttribute("Coins")
M.fireTouched(coin, hrp)
M.fireTouched(coin, hrp)
M.run(0.2)
check(player:GetAttribute("Coins") == coinsBefore + value, "монета собрана один раз (+" .. value .. ")")
check(coin.Parent == nil, "монета исчезла")
M.run(20)
check(#worlds.Forest.Coins:GetChildren() == 30, "монета появилась снова")

print("== яйца")
local data = DataService.Get(player)
data.Coins = 100000
PlayerState.SyncStats(player)
local eggPart = worlds.Forest.ForestEgg.EggModel.Egg
hrp.CFrame = CFrame.new(eggPart.Position + Vector3.new(0, 0, 7))
M.inCtx(M.SERVER, function()
	M.fire(M.event(eggPart.Prompt1.Open1, "Triggered"), player)
end)
M.run(0.3)
check(#data.Pets == 1, "вылупился 1 питомец")
check(data.Pets[1] and data.Pets[1].Equipped, "питомец надет автоматически")
check((player:GetAttribute("EquippedPets") or "") ~= "", "атрибут EquippedPets")
check(#player.PlayerGui.HatchGui:GetChildren() > 1, "анимация яйца запущена")
M.run(6)
M.inCtx(M.SERVER, function()
	M.fire(M.event(eggPart.Prompt3.Open3, "Triggered"), player)
end)
M.run(0.3)
check(#data.Pets == 4, "открытие ×3")
check(player:GetAttribute("Coins") == 100000 - 50 - 150, "списано 200 монет")
M.run(8)
check(#player.PlayerGui.HatchGui:GetChildren() == 1, "анимация закончилась и убрана")
check(ProximityPromptService.Enabled == true, "подсказки снова включены")
local clientPets = Workspace:FindFirstChild("ClientPets")
check(clientPets ~= nil and #clientPets:GetChildren() == 3, "3 питомца летают за игроком")
check((M.bulkMoves or 0) > 0, "питомцы двигаются (BulkMoveTo)")

-- далеко от яйца
hrp.CFrame = CFrame.new(eggPart.Position + Vector3.new(0, 0, 60))
M.run(1)
M.inCtx(M.SERVER, function()
	M.fire(M.event(eggPart.Prompt1.Open1, "Triggered"), player)
end)
M.run(0.3)
check(#data.Pets == 4, "издалека яйцо не открывается")
-- нет денег
hrp.CFrame = CFrame.new(eggPart.Position + Vector3.new(0, 0, 7))
data.Coins = 10
M.run(1)
M.inCtx(M.SERVER, function()
	M.fire(M.event(eggPart.Prompt1.Open1, "Triggered"), player)
end)
M.run(0.3)
check(#data.Pets == 4 and data.Coins == 10, "без денег яйцо не открывается")

print("== окно питомцев")
press(root.SideMenu.Pets)
M.run(0.6)
local petsPanel = root.PanelLayer.Pets
check(petsPanel.Visible, "окно питомцев открыто")
local grid = panelPart("Pets", "Content", "Grid")
local cardCount = 0
for _, child in ipairs(grid:GetChildren()) do
	if child:IsA("TextButton") then
		cardCount += 1
	end
end
check(cardCount == 4, "4 карточки питомцев")
press(panelPart("Pets", "Header", "EquipBest"))
M.run(0.5)
local equipped = 0
for _, pet in ipairs(data.Pets) do
	if pet.Equipped then
		equipped += 1
	end
end
check(equipped == 3, "надеты 3 лучших")

-- снять / надеть через кнопку
local details = panelPart("Pets", "Content", "Details")
press(details.Equip)
M.run(0.5)
equipped = 0
for _, pet in ipairs(data.Pets) do
	if pet.Equipped then
		equipped += 1
	end
end
check(equipped == 2, "кнопка «Снять» сработала")

-- слияние
for _ = 1, 5 do
	PetService.AddPet(player, "Kitten", false)
end
PlayerState.SyncPets(player)
M.run(0.3)
local kittenUid
for _, pet in ipairs(data.Pets) do
	if pet.Id == "Kitten" and not pet.Golden then
		kittenUid = pet.Uid
	end
end
local ok, message = invoke(remotes.PetAction, "Merge", kittenUid)
print("  слияние:", ok, message)
local goldenCount, kittens = 0, 0
for _, pet in ipairs(data.Pets) do
	if pet.Golden then
		goldenCount += 1
	elseif pet.Id == "Kitten" then
		kittens += 1
	end
end
check(ok == true and goldenCount == 1, "получен золотой питомец")
M.run(1)

-- удаление с подтверждением
local countBefore = #data.Pets
press(details.Delete)
M.run(0.3)
check(#data.Pets == countBefore, "первое нажатие «Удалить» только спрашивает")
press(details.Delete)
M.run(0.5)
check(#data.Pets == countBefore - 1, "второе нажатие удаляет")

-- неверные запросы
ok, message = invoke(remotes.PetAction, "Hack", 1)
check(ok == false, "неизвестное действие отклонено: " .. tostring(message))
ok, message = invoke(remotes.PetAction, "Delete", "abc")
check(ok == false, "неверный uid отклонён")
press(panelPart("Pets", "Header", "Close"))
M.run(0.5)
check(not petsPanel.Visible, "окно закрылось")

print("== магазин")
data.Coins = 2000
PlayerState.SyncStats(player)
press(root.SideMenu.Shop)
M.run(0.5)
ok, message = invoke(remotes.BuyBackpack, 3)
check(ok == false, "нельзя перепрыгнуть рюкзак: " .. tostring(message))
ok, message = invoke(remotes.BuyBackpack, 2)
check(ok == true and player:GetAttribute("Capacity") == 250, "куплен рюкзак 2: " .. tostring(message))
check(player:GetAttribute("Coins") == 1850, "списано 150 монет")
-- покупка через кнопку в окне (рюкзак 3 за 1000)
local shopPanel = root.PanelLayer.Shop
local buyButton = panelPart("Shop", "Content", "BackpacksPage", "Backpack3", "Buy")
check(buyButton ~= nil and buyButton.Face.Label.Text == "1K", "кнопка покупки рюкзака 3 с ценой 1K")
if buyButton then
	press(buyButton)
	M.run(0.5)
end
check(player:GetAttribute("BackpackLevel") == 3, "рюкзак 3 куплен через кнопку")
ok, message = invoke(remotes.BuyPetSlots)
check(ok == true and player:GetAttribute("MaxEquipped") == 5, "геймпасс-заглушка: 5 слотов")
press(panelPart("Shop", "Header", "Close"))
M.run(0.5)

print("== миры")
ok, message = invoke(remotes.Teleport, "Desert")
check(ok == false, "пустыня закрыта без силы: " .. tostring(message))
data.TotalStrength = 20000
PlayerState.SyncStats(player)
M.run(0.5)
press(root.SideMenu.Worlds)
M.run(0.5)
local worldsPanel = root.PanelLayer.Worlds
local openButton = panelPart("Worlds", "Content", "Desert", "Go")
check(openButton.Face.Label.Text == "Открыть!", "кнопка «Открыть!» для пустыни")
if openButton then
	press(openButton)
	M.run(1)
end
check(player:GetAttribute("World") == "Desert", "игрок в пустыне")
check(string.find(player:GetAttribute("UnlockedWorlds"), "Desert") ~= nil, "пустыня открыта")
check((hrp.Position - worlds.Desert.SellZone.SellPad.Position).Magnitude < 200, "персонаж перенесён в пустыню")
M.run(1.5)
check(findText(root, "ПУСТЫНЯ") ~= nil, "плашка/баннер «ПУСТЫНЯ»")
check(math.abs(svc("Lighting").ClockTime - 12.5) < 0.01, "освещение пустыни включено на клиенте")
check(forestPortalStatus.Text == "Открыто — заходи!", "табличка портала обновилась: " .. forestPortalStatus.Text)
-- продажа в пустыне ×2
data.Strength = 100
PlayerState.SyncStats(player)
local coinsNow = data.Coins
hrp.CFrame = CFrame.new(worlds.Desert.SellZone.SellPad.Position + Vector3.new(0, 3, 0))
M.run(0.6)
check(data.Coins == coinsNow + 200, "в пустыне продажа ×2")

-- портал в космос (не хватает силы) и назад
local spacePortal, backPortal
for _, model in ipairs(worlds.Desert:GetChildren()) do
	if model.Name == "Portal_Space" then
		spacePortal = model
	elseif model.Name == "BackPortal_Forest" then
		backPortal = model
	end
end
M.fireTouched(spacePortal.Touch, hrp)
M.run(0.3)
check(player:GetAttribute("World") == "Desert", "портал в космос не пустил")
M.run(2.5)
M.fireTouched(backPortal.Touch, hrp)
M.run(0.5)
check(player:GetAttribute("World") == "Forest", "портал назад в лес")
M.run(2.5)
-- портал в пустыню — уже открыт
local forestPortal = worlds.Forest.Portal_Desert
M.fireTouched(forestPortal.Touch, hrp)
M.run(0.5)
check(player:GetAttribute("World") == "Desert", "портал в пустыню пускает")

print("== перерождение")
data.TotalStrength = 60000
PlayerState.SyncStats(player)
press(root.SideMenu.Rebirth)
M.run(0.5)
local rebirthPanel = root.PanelLayer.Rebirth
local rebirthButton = panelPart("Rebirth", "Content", "RebirthButton")
press(rebirthButton)
M.run(0.3)
check(player:GetAttribute("Rebirths") == 0, "первое нажатие только спрашивает")
press(rebirthButton)
M.run(0.6)
check(player:GetAttribute("Rebirths") == 1, "перерождение #1")
check(data.Coins == 0 and data.TotalStrength == 0 and data.Strength == 0, "сила и монеты сброшены")
check(player:GetAttribute("RebirthMultiplier") == 1.5, "множитель x1.5")
check(#data.Pets > 0 and data.BackpackLevel == 3, "питомцы и рюкзак остались")
check(player.leaderstats["Перерождения"].Value == 1, "leaderstats: Перерождения = 1")
local power = player:GetAttribute("ClickPower")
print("  сила клика:", power, "множитель питомцев:", player:GetAttribute("PetMultiplier"))

print("== выход и сохранение")
M.removePlayer(player)
M.run(1)
local stored = M.dataStores["PowerPetsSimulator_v1"]["Player_1001"]
check(stored ~= nil, "данные сохранены в DataStore")
check(stored and stored.Rebirths == 1 and #stored.Pets == #data.Pets, "в сохранении перерождения и питомцы")
check(stored and stored.UnlockedWorlds.Desert == true and stored.CurrentWorld == "Desert", "в сохранении миры")

print("== повторный вход")
local player2, ctx2 = M.addPlayer("Tester", 1001)
M.run(0.1)
M.spawnCharacter(player2, spawnLocation.Position)
M.run(1.5)
check(player2:GetAttribute("Rebirths") == 1, "перерождения загрузились")
check(player2:GetAttribute("BackpackLevel") == 3, "рюкзак загрузился")
check(player2:GetAttribute("World") == "Desert", "мир загрузился")
local hrp2 = player2.Character.HumanoidRootPart
check((hrp2.Position - worlds.Desert.SellZone.SellPad.Position).Magnitude < 200, "игрок появился в пустыне")
check(player2:GetAttribute("MaxEquipped") == 5, "тестовый геймпасс сохранился")
-- смерть и возрождение в своём мире
M.spawnCharacter(player2, spawnLocation.Position)
M.run(1)
check((player2.Character.HumanoidRootPart.Position - worlds.Desert.SellZone.SellPad.Position).Magnitude < 200, "после смерти — снова в пустыне")

print("== сбой DataStore")
M.dataStoreFailures = 10
local player3 = M.addPlayer("Unlucky", 2002)
M.run(15)
check(player3:GetAttribute("DataLoaded") == true and player3:GetAttribute("SaveDisabled") == true, "игра идёт, но сохранение отключено")
M.dataStoreFailures = 0
M.removePlayer(player3)
M.run(1)
check(M.dataStores["PowerPetsSimulator_v1"]["Player_2002"] == nil, "чужие данные не перезаписаны пустыми")

print("== выключение сервера")
M.closeGame()
M.run(3)

print("")
print("== ИТОГ")
print("  проверок провалено:", failures)
print("  ошибок выполнения:", #M.errors)
for _, err in ipairs(M.errors) do
	print("  ERR " .. err)
end
local unimpl = {}
for key in pairs(M.unimplemented) do
	table.insert(unimpl, key)
end
table.sort(unimpl)
print("  методы-заглушки мока:", table.concat(unimpl, ", "))
local seenWarn = {}
for _, w in ipairs(M.warnings) do
	if not seenWarn[w] then
		seenWarn[w] = true
		print("  WARN " .. w)
	end
end
print("  prints:", table.concat(M.prints, " | "))
local ids = {}
for id in pairs(M.soundIds or {}) do
	table.insert(ids, id)
end
table.sort(ids)
print("  звуки:", table.concat(ids, ", "))
print("  remotes:", (function()
	local list = {}
	for name, count in pairs(M.remoteLog or {}) do
		table.insert(list, name .. "=" .. count)
	end
	table.sort(list)
	return table.concat(list, " ")
end)())

if failures > 0 or #M.errors > 0 then
	error(string.format("ТЕСТЫ НЕ ПРОШЛИ: проверок провалено %d, ошибок выполнения %d", failures, #M.errors))
end
print("ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ")
