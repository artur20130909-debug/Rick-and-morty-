-- Админ-панель на сервере: кто админ и все команды для тестов — золото и покупки, бессмертие,
-- скорость, телепорт, осада с любой волны, любое оружие, готовые постройки, земля, время суток,
-- статистика сервера. Окно панели — клиентский модуль UI/AdminUI (клавиша F2).
--
-- Каждый вызов заново проверяет права (атрибут IsAdmin нужен только интерфейсу), принимает
-- лишь команды из списка ниже и проверяет каждый аргумент: клиенту доверять нельзя.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local GroupService = game:GetService("GroupService")
local Stats = game:GetService("Stats")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Blocks = require(Shared.Blocks)
local Grid = require(Shared.Grid)
local Weapons = require(Shared.Weapons)
local Examples = require(Shared.Examples)
local Prefabs = require(Shared.Prefabs)
local MapLayout = require(Shared.MapLayout)
local UG = require(Shared.Underground)
local Util = require(Shared.Util)

local Plots = require(script.Parent.Plots)
local Data = require(script.Parent.Data)
local Building = require(script.Parent.Building)
local Underground = require(script.Parent.Underground)
local Projectiles = require(script.Parent.Projectiles)
local Siege = require(script.Parent.Siege)
local PrefabShop = require(script.Parent.PrefabShop)

local Admin = {}

type Plot = Plots.Plot
type Handler = (player: Player, arg: any) -> (boolean, string?)

-- Пресеты (клиент присылает само значение, сервер принимает только эти)
local GOLD_STEPS = { 1000, 10000, 100000 }
local WALK_SPEEDS = { 16, 32, 64, 120 }
local JUMP_HEIGHTS = { 7.2, 20, 50, 120 }
local TIMES: { [string]: { clock: number, name: string } } = {
	morning = { clock = 7, name = "утро" },
	day = { clock = 13, name = "день" },
	sunset = { clock = 18.2, name = "закат" },
	night = { clock = 0, name = "ночь" },
}

local GOD_FIELD = "AdminGodField" -- невидимое силовое поле бессмертия в персонаже
local MAP_RADIUS = 1650           -- телепорт к точке: дальше по горизонтали — уже край карты
local MAP_BOTTOM, MAP_TOP = -40, 900
local C = UG.CELL

local prefabByKey: { [string]: any } = {}
for _, p in Prefabs do
	prefabByKey[p.key] = p
end

-- ПРАВА -----------------------------------------------------------------------------
-- Владелец группы, которой принадлежит место: узнаём один раз (при ошибке — не чаще раза в 30 с)
local groupOwner: number? = nil
local groupChecked = false
local groupBusy = false -- запрос уже идёт: второй параллельно не шлём
local groupRetryAt = 0

local function creatorGroupOwner(): number?
	if groupChecked or groupBusy or os.clock() < groupRetryAt then
		return groupOwner
	end
	groupBusy = true
	local ok, info = pcall(function()
		return GroupService:GetGroupInfoAsync(game.CreatorId)
	end)
	groupBusy = false
	if ok then
		groupChecked = true
		local owner = typeof(info) == "table" and info.Owner
		if typeof(owner) == "table" and typeof(owner.Id) == "number" then
			groupOwner = owner.Id
		end
	else
		groupRetryAt = os.clock() + 30
		warn("[Admin] не удалось узнать владельца группы:", info)
	end
	return groupOwner
end

-- В Studio админ — любой игрок (для тестов). В опубликованной игре — владелец места,
-- владелец группы-владельца и UserId из Config.Admins.
function Admin.isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(Config.Admins, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return game.CreatorId > 0 and player.UserId == game.CreatorId
	end
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		return creatorGroupOwner() == player.UserId
	end
	return false
end

-- ПОМОЩНИКИ -------------------------------------------------------------------------
local function isIntIn(v: any, lo: number, hi: number): boolean
	return typeof(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end

local function isFiniteVector(v: any): boolean
	return typeof(v) == "Vector3" and Util.isFiniteNumber(v.X) and Util.isFiniteNumber(v.Y) and Util.isFiniteNumber(v.Z)
end

-- Переключатель: true/false — включить/выключить, всё остальное — поменять на противоположное
local function toggled(arg: any, current: any): boolean
	if typeof(arg) == "boolean" then
		return arg
	end
	return current ~= true
end

local function aliveCharacter(player: Player): (Model?, Humanoid?, BasePart?)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if char and hum and root and hum.Health > 0 then
		return char, hum, root
	end
	return nil, nil, nil
end

-- Участок, который сейчас можно менять (не идёт осада и испытание)
local function editablePlot(player: Player): (Plot?, string?)
	local plot = Plots.of(player)
	if not plot then
		return nil, "У тебя нет участка"
	end
	local can, why = Building.canEdit(plot)
	if not can then
		return nil, why
	end
	return plot, nil
end

local function snapshotForUndo(plot: Plot)
	Building.pushUndo(plot, { type = "clear", data = Building.serialize(plot) })
end

-- Перенести персонажа. Сидящего сначала отстёгиваем от сиденья, иначе он утащит за собой машину.
local function moveCharacter(char: Model, hum: Humanoid, root: BasePart, cf: CFrame)
	local seat = hum.SeatPart
	if seat then
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		hum.Sit = false
	end
	char:PivotTo(cf)
	root.AssemblyLinearVelocity = Vector3.zero
end

-- Повернуть только вокруг вертикали — так, как персонаж смотрит сейчас
local function yawOf(root: BasePart): CFrame
	local _, y, _ = root.CFrame:ToOrientation()
	return CFrame.fromOrientation(0, y, 0)
end

-- Бессмертие: невидимое силовое поле (урон в игре идёт через Humanoid:TakeDamage, поле его гасит)
local function applyGod(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local field = char:FindFirstChild(GOD_FIELD)
	if player:GetAttribute("God") == true then
		if not field then
			local f = Instance.new("ForceField")
			f.Name = GOD_FIELD
			f.Visible = false
			f.Parent = char
		end
	elseif field then
		field:Destroy()
	end
end

-- Скорость бега и высота прыжка (атрибуты переживают смерть персонажа)
local function applyMovement(player: Player, hum: Humanoid)
	local walk = player:GetAttribute("AdminWalk")
	if typeof(walk) == "number" then
		hum.WalkSpeed = walk
	end
	local jump = player:GetAttribute("AdminJump")
	if typeof(jump) == "number" then
		-- задаём оба свойства: какое из них работает, решает Humanoid.UseJumpPower
		hum.JumpHeight = jump
		hum.JumpPower = math.sqrt(2 * workspace.Gravity * jump)
	end
end

-- Куда встать на дне котлована: самая глубокая выкопанная клетка, над которой тоже пусто
-- (персонажу нужно две клетки в высоту) и где нет блоков; среди равных — ближе к центру.
local pitParams = OverlapParams.new()
pitParams.FilterType = Enum.RaycastFilterType.Include
pitParams.MaxParts = 1

local function pitSpot(plot: Plot): Vector3?
	local list = {}
	for i in plot.dug do
		local ix, iy, iz = UG.coords(i)
		if iy == 1 or plot.dug[UG.index(ix, iy - 1, iz)] then
			local c = UG.cellCenter(ix, iy, iz)
			table.insert(list, { iy = iy, d = c.X * c.X + c.Z * c.Z, c = c })
		end
	end
	table.sort(list, function(a, b)
		if a.iy ~= b.iy then
			return a.iy > b.iy
		end
		return a.d < b.d
	end)
	pitParams.FilterDescendantsInstances = { plot.blocks }
	local box = Vector3.new(C - 0.2, 2 * C - 0.2, C - 0.2)
	for _, e in list do
		local column = plot.cf * CFrame.new(e.c + Vector3.new(0, C / 2, 0))
		if #workspace:GetPartBoundsInBox(column, box, pitParams) == 0 then
			return Vector3.new(e.c.X, e.c.Y - C / 2 + 3, e.c.Z) -- корень персонажа в 3 стадах над полом клетки
		end
	end
	return nil
end

-- Блок хотя бы частью уходит под пол (в клетки земли)?
local function isUnderground(block: BasePart): boolean
	local spec = Building.specOf(block)
	return #UG.cellsInBox(spec.pos, Grid.extents(spec.size, spec.rot)) > 0
end

-- Замеряем частоту кадров сервера (Heartbeat) раз в секунду
local heartbeatFps = 60

-- КОМАНДЫ ---------------------------------------------------------------------------
local commands: { [string]: Handler } = {}

-- Экономика
commands.gold = function(player, arg)
	if not table.find(GOLD_STEPS, arg) then
		return false, "Неверная сумма"
	end
	Data.addGold(player, arg)
	return true, "+" .. Util.formatNumber(arg) .. " золота"
end

commands.goldZero = function(player)
	local profile = Data.get(player)
	if not profile then
		return false, "Профиль ещё загружается"
	end
	profile.Gold = 0
	Data.sync(player)
	return true, "Золото обнулено"
end

commands.unlockAll = function(player)
	local profile = Data.get(player)
	if not profile then
		return false, "Профиль ещё загружается"
	end
	local n = 0
	local function unlock(key: string)
		if not profile.Unlocked[key] then
			profile.Unlocked[key] = true
			n += 1
		end
	end
	for _, m in Blocks.Materials do
		if m.price > 0 then
			unlock(Blocks.unlockKey("mat", m.id))
		end
	end
	for _, it in Blocks.Items do
		if it.price > 0 then
			unlock(Blocks.unlockKey("item", it.id))
		end
	end
	Data.sync(player)
	if n == 0 then
		return true, "Все материалы и особые блоки уже открыты"
	end
	return true, string.format("Открыто бесплатно: %d %s", n, Util.plural(n, "покупка", "покупки", "покупок"))
end

commands.unlockPrefabs = function(player)
	local profile = Data.get(player)
	if not profile then
		return false, "Профиль ещё загружается"
	end
	local n = 0
	for _, p in Prefabs do
		if not profile.Prefabs[p.key] then
			profile.Prefabs[p.key] = true
			n += 1
		end
	end
	Data.sync(player)
	if n == 0 then
		return true, "Все готовые постройки уже куплены"
	end
	return true, string.format("Открыто бесплатно: %d %s", n, Util.plural(n, "постройка", "постройки", "построек"))
end

commands.resetPurchases = function(player)
	local profile = Data.get(player)
	if not profile then
		return false, "Профиль ещё загружается"
	end
	profile.Unlocked = {}
	profile.Prefabs = {}
	Data.sync(player)
	return true, "Покупки сброшены: материалы, особые блоки и постройки снова продаются"
end

-- Игрок
commands.god = function(player, arg)
	local on = toggled(arg, player:GetAttribute("God"))
	player:SetAttribute("God", on)
	applyGod(player)
	local _, hum = aliveCharacter(player)
	if on and hum then
		hum.Health = hum.MaxHealth
	end
	return true, on and "Бессмертие включено" or "Бессмертие выключено"
end

commands.heal = function(player)
	local _, hum = aliveCharacter(player)
	if not hum then
		return false, "Подожди, пока персонаж появится"
	end
	hum.Health = hum.MaxHealth
	return true, "Здоровье восстановлено"
end

commands.speed = function(player, arg)
	if not table.find(WALK_SPEEDS, arg) then
		return false, "Неверная скорость"
	end
	player:SetAttribute("AdminWalk", arg)
	local _, hum = aliveCharacter(player)
	if hum then
		applyMovement(player, hum)
	end
	return true, "Скорость бега: " .. arg
end

commands.jump = function(player, arg)
	if not table.find(JUMP_HEIGHTS, arg) then
		return false, "Неверная высота прыжка"
	end
	player:SetAttribute("AdminJump", arg)
	local _, hum = aliveCharacter(player)
	if hum then
		applyMovement(player, hum)
	end
	return true, "Высота прыжка: " .. arg .. " ст."
end

commands.fly = function(player, arg)
	-- сам полёт — на клиенте (модуль AdminTools): персонажем управляет его компьютер
	local on = toggled(arg, player:GetAttribute("Fly"))
	player:SetAttribute("Fly", on)
	if on then
		return true, "Полёт: WASD — лететь, Пробел / E — вверх, Ctrl / Q — вниз, Shift — быстрее"
	end
	return true, "Полёт выключен"
end

commands.tp = function(player, arg)
	local char, hum, root = aliveCharacter(player)
	if not (char and hum and root) then
		return false, "Подожди, пока персонаж появится"
	end
	if arg == "lobby" then
		moveCharacter(char, hum, root, CFrame.new(MapLayout.LobbySpawn + Vector3.new(0, 1, 0)) * yawOf(root))
		return true, "Ты в лобби"
	end
	local plot = Plots.of(player)
	if not plot then
		return false, "У тебя нет участка"
	end
	if arg == "plot" then
		moveCharacter(char, hum, root, plot.spawn.CFrame + Vector3.new(0, 4, 0))
		return true, "Ты на своём участке"
	elseif arg == "pit" then
		local spot = pitSpot(plot)
		if not spot then
			return false, "В котловане негде встать: сначала выкопай яму (или «Выкопать всё» на вкладке «Постройка»)"
		end
		moveCharacter(char, hum, root, plot.cf * CFrame.new(spot))
		return true, "Ты на дне котлована"
	end
	return false, "Неизвестная точка телепорта"
end

commands.tpPoint = function(player, arg)
	if not isFiniteVector(arg) then
		return false, "Неверная точка"
	end
	local p: Vector3 = arg
	if Vector2.new(p.X, p.Z).Magnitude > MAP_RADIUS or p.Y < MAP_BOTTOM or p.Y > MAP_TOP then
		return false, "Эта точка за краем карты"
	end
	local char, hum, root = aliveCharacter(player)
	if not (char and hum and root) then
		return false, "Подожди, пока персонаж появится"
	end
	moveCharacter(char, hum, root, CFrame.new(p + Vector3.new(0, 3.5, 0)) * yawOf(root))
	return true, nil
end

-- Осада
commands.siegeStart = function(player, arg)
	if typeof(arg) ~= "table" then
		return false, "Неверный запрос"
	end
	local wave, di = arg.wave, arg.difficulty
	if not isIntIn(wave, 1, Siege.MaxAdminWave) or not isIntIn(di, 1, #Config.Difficulties) then
		return false, "Неверная волна или сложность"
	end
	local ok, err = Siege.adminStart(player, di, wave)
	if not ok then
		return false, err
	end
	return true, string.format("Выживание с волны %d, сложность «%s» (рекорды не засчитываются)", wave, Config.Difficulties[di].name)
end

commands.skipWave = function(player)
	return Siege.skipWave(player)
end

commands.siegeEnd = function(player)
	if not Siege.stop(player) then
		return false, "Осада не идёт"
	end
	return true, "Осада закончена"
end

commands.fire = function(player, arg)
	if typeof(arg) ~= "table" or typeof(arg.key) ~= "string" or not Weapons.ByKey[arg.key] then
		return false, "Нет такого оружия"
	end
	local target: string | Vector3
	if arg.target == "me" or arg.target == "block" then
		target = arg.target
	elseif arg.target == "aim" and isFiniteVector(arg.aim) then
		target = arg.aim
	else
		return false, "Неверная цель"
	end
	return Siege.adminFire(player, arg.key, target)
end

commands.restore = function(player)
	local ok, msg = Siege.restore(player)
	if not ok then
		return false, "Восстанавливать нечего: полигон не включён"
	end
	return true, msg
end

-- Постройка
commands.prefab = function(player, arg)
	if typeof(arg) ~= "string" or not prefabByKey[arg] then
		return false, "Нет такой постройки"
	end
	-- бесплатно и без покупки; остальные проверки (осада, лимит блоков, отмена) — в магазине построек
	return PrefabShop.placeInternal(player, arg, true)
end

commands.clearPlot = function(player)
	local ok, err = Building.clearRequest(player)
	if not ok then
		return false, err or "Участок нельзя очистить"
	end
	return true, "Участок очищен (отменить — Ctrl+Z)"
end

commands.digAll = function(player)
	local plot, err = editablePlot(player)
	if not plot then
		return false, err
	end
	if UG.count(plot.dug) >= UG.COUNT then
		return false, "Котлован и так выкопан целиком"
	end
	snapshotForUndo(plot)
	local all: { [number]: boolean } = {}
	for i = 0, UG.COUNT - 1 do
		all[i] = true
	end
	Underground.setMask(plot, all)
	return true, string.format("Выкопан весь котлован: %d клеток (отменить — Ctrl+Z)", UG.COUNT)
end

commands.fillAll = function(player)
	local plot, err = editablePlot(player)
	if not plot then
		return false, err
	end
	if next(plot.dug) == nil then
		return false, "Котлован и так засыпан"
	end
	-- снимок для отмены — до того, как убрать подземные блоки
	snapshotForUndo(plot)
	local removed = 0
	for _, child in plot.blocks:GetChildren() do
		if child:IsA("BasePart") and isUnderground(child) then
			child:Destroy()
			removed += 1
		end
	end
	Underground.setMask(plot, {})
	local text = "Котлован засыпан"
	if removed > 0 then
		text ..= string.format(", убрано %d %s под землёй", removed, Util.plural(removed, "блок", "блока", "блоков"))
	end
	return true, text .. " (отменить — Ctrl+Z)"
end

commands.example = function(player, arg)
	if not isIntIn(arg, 1, #Examples) then
		return false, "Нет такого примера"
	end
	return Building.loadExample(player, arg)
end

-- Мир
commands.time = function(_player, arg)
	local t = typeof(arg) == "string" and TIMES[arg] or nil
	if not t then
		return false, "Неизвестное время суток"
	end
	Lighting.ClockTime = t.clock
	return true, "Время суток: " .. t.name
end

-- Информация (короткий текст для вкладки «Инфо»)
commands.stats = function(player)
	local plot = Plots.of(player)
	local lines = {
		string.format("Сервер: %d FPS, физика: %d FPS", math.floor(heartbeatFps + 0.5), math.floor(workspace:GetRealPhysicsFPS() + 0.5)),
		string.format("Память сервера: %d МБ", math.floor(Stats:GetTotalMemoryUsageMb() + 0.5)),
		string.format("Игроков: %d из %d", #Players:GetPlayers(), Players.MaxPlayers),
		string.format("Снарядов в полёте: %d", Projectiles.count()),
	}
	if plot then
		table.insert(lines, string.format("Мой участок: %d из %d блоков", Building.count(plot), Config.MaxBlocks))
		table.insert(lines, string.format("Выкопано клеток земли: %d из %d", UG.count(plot.dug), UG.COUNT))
		local state = plot.siege
		if state and not state.ended then
			if state.mode == "survival" then
				table.insert(lines, string.format("Осада: выживание, волна %d, сложность «%s»", state.wave, state.diff.name))
			else
				table.insert(lines, "Осада: полигон")
			end
		else
			table.insert(lines, "Осада: нет")
		end
	else
		table.insert(lines, "Мой участок: нет (все заняты)")
	end
	return true, table.concat(lines, "\n")
end

-- Удалённый вызов Admin: (команда, аргумент)
function Admin.handle(player: Player, cmd: any, arg: any): (boolean, string?)
	if not Admin.isAdmin(player) then
		return false, "Нет прав администратора"
	end
	local handler = typeof(cmd) == "string" and commands[cmd]
	if not handler then
		return false, "Неизвестная команда"
	end
	return handler(player, arg)
end

-- ЗАПУСК ----------------------------------------------------------------------------
local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10)
	if not (hum and hum:IsA("Humanoid")) or char.Parent == nil then
		return
	end
	applyGod(player)
	applyMovement(player, hum :: Humanoid)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	-- проверка группы может подождать ответа сайта — поэтому отдельной задачей
	task.spawn(function()
		local admin = Admin.isAdmin(player)
		if player.Parent then
			player:SetAttribute("IsAdmin", admin)
		end
	end)
end

function Admin.init()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	local frames, elapsed = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		frames += 1
		elapsed += dt
		if elapsed >= 1 then
			heartbeatFps = frames / elapsed
			frames, elapsed = 0, 0
		end
	end)
end

return Admin
