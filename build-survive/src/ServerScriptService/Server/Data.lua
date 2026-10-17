-- Профили игроков: золото, купленные блоки и готовые постройки, рекорды, слоты сохранений.
-- Если DataStore недоступен (Studio без доступа к API), игра работает, но ничего не сохраняет.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Serializer = require(Shared.Serializer)

local Data = {}

export type Profile = {
	Gold: number,
	Unlocked: { [string]: boolean },
	Prefabs: { [string]: boolean }, -- купленные готовые дома и бункеры (ключи Shared/Prefabs)
	BestWave: number,
	Slots: { [string]: string },
	SlotInfo: { [string]: { count: number, time: number } },
	Auto: string,
	Settings: { [string]: any },
	Stats: { [string]: number },
	LastDaily: number,
}

local profiles: { [Player]: Profile } = {}
local newPlayers: { [Player]: boolean } = {}
local canSave: { [Player]: boolean } = {}
local store: DataStore? = nil

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[Data] DataStore недоступен:", result)
	end
end

local function defaultProfile(): Profile
	return {
		Gold = Config.StartGold,
		Unlocked = {},
		Prefabs = {},
		BestWave = 0,
		Slots = {},
		SlotInfo = {},
		Auto = "",
		Settings = table.clone(Config.DefaultSettings),
		Stats = { Sieges = 0, Waves = 0, Nukes = 0, Blocks = 0 },
		LastDaily = 0,
	}
end

-- Добавить в старый профиль поля, которых в нём ещё нет
local function reconcile(data: any): Profile
	local base = defaultProfile()
	if typeof(data) ~= "table" then
		return base
	end
	for k, v in base do
		if data[k] == nil or typeof(data[k]) ~= typeof(v) then
			data[k] = v
		end
	end
	for k, v in Config.DefaultSettings do
		if data.Settings[k] == nil then
			data.Settings[k] = v
		end
	end
	return data
end

local function updateLeaderstats(player: Player, p: Profile)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local gold = ls:FindFirstChild("Золото") :: IntValue?
		local best = ls:FindFirstChild("Рекорд") :: IntValue?
		if gold then
			gold.Value = p.Gold
		end
		if best then
			best.Value = p.BestWave
		end
	end
	player:SetAttribute("Gold", p.Gold)
	player:SetAttribute("BestWave", p.BestWave)
end

function Data.load(player: Player): Profile
	local key = "u" .. player.UserId
	local loaded: any = nil
	local ok = false
	if store then
		for attempt = 1, 3 do
			local success, result = pcall(function()
				return (store :: DataStore):GetAsync(key)
			end)
			if success then
				ok = true
				loaded = result
				break
			end
			warn("[Data] попытка " .. attempt .. ":", result)
			if string.find(tostring(result), "Studio", 1, true) then
				break
			end
			task.wait(1.5)
		end
	end
	local profile = reconcile(loaded)
	profiles[player] = profile
	newPlayers[player] = loaded == nil
	canSave[player] = ok

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local gold = Instance.new("IntValue")
	gold.Name = "Золото"
	gold.Parent = ls
	local best = Instance.new("IntValue")
	best.Name = "Рекорд"
	best.Parent = ls
	ls.Parent = player
	updateLeaderstats(player, profile)
	return profile
end

function Data.saveEnabled(player: Player): boolean
	return canSave[player] == true
end

function Data.save(player: Player): boolean
	local profile = profiles[player]
	if not (profile and canSave[player] and store) then
		return false
	end
	local key = "u" .. player.UserId
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key, function()
			return profile
		end)
	end)
	if not ok then
		warn("[Data] не удалось сохранить:", err)
	end
	return ok
end

function Data.get(player: Player): Profile?
	return profiles[player]
end

function Data.isNew(player: Player): boolean
	return newPlayers[player] == true
end

function Data.release(player: Player)
	newPlayers[player] = nil
	profiles[player] = nil
	canSave[player] = nil
end

-- Отправить клиенту всё, что ему нужно знать о профиле
function Data.sync(player: Player)
	local p = profiles[player]
	if not p then
		return
	end
	local slots = {}
	for i = 1, Config.SaveSlots do
		local info = p.SlotInfo[tostring(i)]
		slots[i] = info and { count = info.count, time = info.time } or false
	end
	Net.event("Data"):FireClient(player, {
		gold = p.Gold,
		unlocked = p.Unlocked,
		prefabs = p.Prefabs,
		bestWave = p.BestWave,
		slots = slots,
		settings = p.Settings,
		stats = p.Stats,
		saveEnabled = canSave[player] == true,
	})
	updateLeaderstats(player, p)
end

function Data.addGold(player: Player, amount: number)
	local p = profiles[player]
	if not p then
		return
	end
	p.Gold = math.max(0, math.floor(p.Gold + amount))
	Data.sync(player)
end

function Data.isUnlocked(player: Player, key: string): boolean
	local p = profiles[player]
	return p ~= nil and p.Unlocked[key] == true
end

function Data.unlock(player: Player, key: string)
	local p = profiles[player]
	if p then
		p.Unlocked[key] = true
	end
end

-- Готовые постройки (магазин домов и бункеров)
function Data.ownsPrefab(player: Player, key: string): boolean
	local p = profiles[player]
	return p ~= nil and p.Prefabs[key] == true
end

function Data.givePrefab(player: Player, key: string)
	local p = profiles[player]
	if p then
		p.Prefabs[key] = true
	end
end

function Data.setSlot(player: Player, slot: number, str: string)
	local p = profiles[player]
	if not p then
		return
	end
	p.Slots[tostring(slot)] = str
	p.SlotInfo[tostring(slot)] = { count = Serializer.count(str), time = os.time() }
end

function Data.getSlot(player: Player, slot: number): string?
	local p = profiles[player]
	return p and p.Slots[tostring(slot)]
end

-- Ежедневный бонус: раз в 20 часов
function Data.tryDaily(player: Player): number
	local p = profiles[player]
	if not p then
		return 0
	end
	local now = os.time()
	if now - p.LastDaily >= 20 * 3600 then
		p.LastDaily = now
		p.Gold += Config.DailyBonus
		return Config.DailyBonus
	end
	return 0
end

-- Сохранить всех (при выключении сервера). Ждёт до 25 секунд.
function Data.saveAll()
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			Data.save(player)
			pending -= 1
		end)
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 25 do
		task.wait(0.1)
	end
end

return Data
