-- BUILD & SURVIVE — сервер. Здесь всё соединяется вместе.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Server = script.Parent:WaitForChild("Server")
local TerrainGen = require(Server.TerrainGen)
local Data = require(Server.Data)
local Plots = require(Server.Plots)
local Building = require(Server.Building)
local Shop = require(Server.Shop)
local Specials = require(Server.Specials)
local Damage = require(Server.Damage)
local Projectiles = require(Server.Projectiles)
local Siege = require(Server.Siege)
local Launch = require(Server.Launch)
local Lobby = require(Server.Lobby)
local Underground = require(Server.Underground)
local PrefabShop = require(Server.PrefabShop)
local Admin = require(Server.Admin)

-- Мир --------------------------------------------------------------------------------
Plots.init()
Underground.init()
task.spawn(function()
	TerrainGen.build()
	-- под каждым участком вырезаем рельеф: там котлован с землёй-блоками (модуль Underground)
	Underground.carveAll()
end)
Damage.init()
Specials.init()
Lobby.init()
Admin.init()

-- То, сквозь что пролетают снаряды: вышки, вражеские базы, обломки, купола щитов
do
	local exclude: { Instance } = { Damage.debrisFolder() }
	local map = workspace:FindFirstChild("Map")
	local forts = map and map:FindFirstChild("EnemyForts")
	if forts then
		table.insert(exclude, forts)
	end
	for _, plot in Plots.list do
		local towers = plot.model:FindFirstChild("Towers")
		if towers then
			table.insert(exclude, towers)
		end
		table.insert(exclude, plot.effects)
	end
	Projectiles.setExclude(exclude)
	Damage.setExclude(exclude)
end

RunService.Heartbeat:Connect(function(dt)
	Projectiles.step(math.min(dt, 0.1))
end)

-- Игроки -----------------------------------------------------------------------------
local function setCollisionGroup(char: Model)
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Players"
		end
	end
	char.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = "Players"
		end
	end)
end

local function onPlayerAdded(player: Player)
	-- участок выдаём сразу (без ожидания сохранений), чтобы игрок появился на нём
	local plot = Plots.assign(player)
	player.CharacterAdded:Connect(setCollisionGroup)
	if player.Character then
		setCollisionGroup(player.Character)
	end
	local profile = Data.load(player)
	if not player.Parent then
		Data.release(player)
		return
	end
	if plot then
		if profile.Auto ~= "" then
			Building.restore(plot, profile.Auto)
		elseif Data.isNew(player) then
			Building.starter(plot)
		end
		-- если персонаж успел появиться где-то ещё — переносим на свой участок
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if char and root and not Plots.isOnIsland(plot, root.Position) then
			char:PivotTo(plot.spawn.CFrame + Vector3.new(0, 4, 0))
		end
	end
	local bonus = Data.tryDaily(player)
	Data.sync(player)
	task.delay(2, function()
		if not player.Parent then
			return
		end
		if not plot then
			Building.notify(player, "Все участки заняты — можно смотреть, как строят другие", "warning")
		else
			Building.notify(player, "Твой участок: " .. plot.colorName .. ". Строй и выживай!", "info")
		end
		if bonus > 0 then
			Building.notify(player, "Ежедневный бонус: +" .. bonus .. " золота", "success")
		end
		if not Data.saveEnabled(player) then
			Building.notify(player, "Сохранения выключены (в Studio: Game Settings → Security → API Services)", "warning")
		end
	end)
end

local function onPlayerRemoving(player: Player)
	local plot = Plots.of(player)
	local profile = Data.get(player)
	if plot and profile then
		-- сохраняем целую постройку, а не руины после осады
		profile.Auto = Siege.snapshotOf(plot) or Launch.snapshotOf(plot) or Building.serialize(plot)
		Siege.finish(plot, "left")
		Launch.stop(player, true)
	end
	Data.save(player)
	if plot then
		Building.clear(plot)
		Underground.reset(plot)
		plot.siege = nil
		plot.launched = false
		Plots.release(player)
	end
	Building.forget(player)
	Data.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		local plot = Plots.of(player)
		local profile = Data.get(player)
		if plot and profile then
			profile.Auto = Siege.snapshotOf(plot) or Launch.snapshotOf(plot) or Building.serialize(plot)
		end
	end
	Data.saveAll()
end)

-- Автосохранение
task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for _, player in Players:GetPlayers() do
			local plot = Plots.of(player)
			local profile = Data.get(player)
			if plot and profile and not plot.siege and not plot.launched then
				profile.Auto = Building.serialize(plot)
			end
			task.spawn(Data.save, player)
		end
	end
end)

-- Удалённые вызовы -------------------------------------------------------------------
local function bind(name: string, handler: (Player, ...any) -> (boolean, string?))
	Net.func(name).OnServerInvoke = function(player: Player, ...)
		local ok, a, b = pcall(handler, player, ...)
		if not ok then
			warn("[" .. name .. "]", a)
			return false, "Ошибка сервера"
		end
		return a, b
	end
end

bind("Place", Building.place)
bind("Delete", Building.delete)
bind("Paint", Building.paint)
bind("Undo", Building.undo)
bind("Clear", Building.clearRequest)
bind("SaveSlot", Building.saveSlot)
bind("LoadSlot", Building.loadSlot)
bind("LoadExample", Building.loadExample)
bind("Dig", Building.dig)
bind("BuyPrefab", PrefabShop.buy)
bind("PlacePrefab", PrefabShop.place)
bind("Admin", Admin.handle)
bind("Buy", Shop.buy)
bind("StartSiege", Siege.start)
bind("StopSiege", Siege.stop)
bind("FireRange", Siege.fireRange)
bind("Restore", Siege.restore)
bind("Launch", Launch.start)
bind("StopLaunch", function(player)
	return Launch.stop(player)
end)
bind("GetData", function(player)
	Data.sync(player)
	return true, nil
end)
bind("SetSettings", function(player, settings)
	local profile = Data.get(player)
	if not profile or typeof(settings) ~= "table" then
		return false, nil
	end
	for k, default in Config.DefaultSettings do
		local v = settings[k]
		if v ~= nil and typeof(v) == typeof(default) then
			profile.Settings[k] = v
		end
	end
	return true, nil
end)

print("[BUILD & SURVIVE] сервер запущен")
