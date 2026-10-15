--[[
	DataService — загрузка и сохранение прогресса через DataStoreService.

	Что сохраняется: сила, накопленная сила, монеты, перерождения, рюкзак, питомцы,
	открытые миры, текущий мир, тестовый геймпасс и немного статистики.

	- Загрузка с повторными попытками. Если хранилище недоступно (место не опубликовано
	  или в Studio выключен доступ к API), игра работает, но прогресс не сохраняется.
	- Если данные не удалось прочитать из-за ошибки, мы НЕ сохраняем поверх них,
	  чтобы не стереть настоящий прогресс игрока.
	- Автосейв (из Main.server.lua), сохранение при выходе и при выключении сервера.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Pets = require(Shared.Config.Pets)
local Worlds = require(Shared.Config.Worlds)
local Backpacks = require(Shared.Config.Backpacks)

local DataService = {}

local TEMPLATE = {
	Version = 1,
	Strength = 0, -- сила в рюкзаке (продаётся за монеты)
	TotalStrength = 0, -- сила, накопленная с последнего перерождения (лидерборд, порталы)
	Coins = 0,
	Rebirths = 0,
	BackpackLevel = 1,
	Pets = {}, -- { { Uid = 1, Id = "Kitten", Golden = false, Equipped = true }, ... }
	NextPetUid = 1,
	UnlockedWorlds = { [GameConfig.StartWorld] = true },
	CurrentWorld = GameConfig.StartWorld,
	PetSlotsPass = false, -- тестовый геймпасс (когда PetSlotsGamepassId = 0)
	Stats = {
		Clicks = 0,
		EggsOpened = 0,
	},
}

local store = nil
local storeEnabled = true
local profiles = {} -- [player] = { Data = {...}, CanSave = bool, Saving = bool }

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in pairs(value) do
		copy[key] = deepCopy(item)
	end
	return copy
end

-- Дополняет сохранение недостающими полями из шаблона и чинит неверные типы.
local function reconcile(data)
	if type(data) ~= "table" then
		return deepCopy(TEMPLATE)
	end
	for key, default in pairs(TEMPLATE) do
		if data[key] == nil or type(data[key]) ~= type(default) then
			data[key] = deepCopy(default)
		elseif type(default) == "table" and key ~= "Pets" and key ~= "UnlockedWorlds" then
			for subKey, subDefault in pairs(default) do
				if type(data[key][subKey]) ~= type(subDefault) then
					data[key][subKey] = deepCopy(subDefault)
				end
			end
		end
	end

	-- Числа не должны быть отрицательными или NaN.
	for _, key in ipairs({ "Strength", "TotalStrength", "Coins", "Rebirths" }) do
		local number = data[key]
		if number ~= number or number < 0 then
			data[key] = 0
		end
	end
	data.Rebirths = math.floor(data.Rebirths)
	data.BackpackLevel = math.clamp(math.floor(data.BackpackLevel), 1, #Backpacks)
	data.Strength = math.min(data.Strength, Backpacks[data.BackpackLevel].Capacity)

	-- Питомцы: выкидываем тех, кого больше нет в конфиге, чиним номера.
	local cleanPets, usedUids, maxUid = {}, {}, 0
	for _, pet in ipairs(data.Pets) do
		if type(pet) == "table" and type(pet.Id) == "string" and Pets[pet.Id] and #cleanPets < GameConfig.MaxPets then
			local uid = tonumber(pet.Uid)
			if not uid or usedUids[uid] then
				uid = nil
			end
			table.insert(cleanPets, {
				Uid = uid,
				Id = pet.Id,
				Golden = pet.Golden == true,
				Equipped = pet.Equipped == true,
			})
			if uid then
				usedUids[uid] = true
				maxUid = math.max(maxUid, uid)
			end
		end
	end
	for _, pet in ipairs(cleanPets) do
		if not pet.Uid then
			maxUid += 1
			pet.Uid = maxUid
		end
	end
	data.Pets = cleanPets
	data.NextPetUid = math.max(math.floor(tonumber(data.NextPetUid) or 1), maxUid + 1)

	-- Миры: только существующие, стартовый всегда открыт.
	local unlocked = { [GameConfig.StartWorld] = true }
	for worldId, isOpen in pairs(data.UnlockedWorlds) do
		if Worlds[worldId] and worldId ~= "Order" and isOpen == true then
			unlocked[worldId] = true
		end
	end
	data.UnlockedWorlds = unlocked
	if not unlocked[data.CurrentWorld] then
		data.CurrentWorld = GameConfig.StartWorld
	end

	data.Version = TEMPLATE.Version
	return data
end

local function keyFor(player)
	return "Player_" .. player.UserId
end

-- Ошибки, после которых пробовать снова бессмысленно (Studio без доступа к API и т. п.).
local function isFatalError(message)
	message = tostring(message)
	return string.find(message, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(message, "publish", 1, true) ~= nil
		or string.find(message, "403", 1, true) ~= nil
end

function DataService.Init()
	if game.PlaceId == 0 then
		storeEnabled = false
		warn("[DataService] Место не опубликовано — сохранение отключено. Опубликуй игру и включи API Services, чтобы проверить сохранения.")
		return
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	if ok then
		store = result
	else
		storeEnabled = false
		warn("[DataService] DataStore недоступен:", result)
	end
end

-- Загружает данные игрока. Возвращает таблицу данных или nil, если игрок уже вышел.
function DataService.Load(player)
	local raw = nil
	local canSave = false

	if storeEnabled and store then
		local attempts = 4
		for attempt = 1, attempts do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				raw = result
				canSave = true
				break
			end
			warn(string.format("[DataService] Не удалось загрузить %s (попытка %d): %s", player.Name, attempt, tostring(result)))
			if isFatalError(result) then
				storeEnabled = false
				warn("[DataService] Сохранение отключено. В Studio: Game Settings → Security → Enable Studio Access to API Services.")
				break
			end
			if attempt < attempts then
				task.wait(attempt * 1.5)
			end
		end
	end

	if not player.Parent then
		return nil
	end

	local data = reconcile(raw)
	profiles[player] = {
		Data = data,
		CanSave = canSave,
		Saving = false,
	}
	return data
end

function DataService.Get(player)
	local profile = profiles[player]
	return profile and profile.Data or nil
end

function DataService.CanSave(player)
	local profile = profiles[player]
	return profile ~= nil and profile.CanSave and storeEnabled
end

function DataService.Save(player)
	local profile = profiles[player]
	if not profile or not profile.CanSave or not storeEnabled or not store then
		return false
	end

	-- Не пишем одновременно два сохранения одного игрока.
	while profile.Saving do
		task.wait(0.1)
	end
	profile.Saving = true

	local snapshot = deepCopy(profile.Data)
	snapshot.LastSaved = os.time()
	local success = false
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function()
				return snapshot
			end)
		end)
		if ok then
			success = true
			break
		end
		warn(string.format("[DataService] Не удалось сохранить %s (попытка %d): %s", player.Name, attempt, tostring(err)))
		if attempt < 3 then
			task.wait(attempt)
		end
	end

	profile.Saving = false
	return success
end

-- Сохраняет и забывает игрока (при выходе).
function DataService.Release(player)
	if profiles[player] then
		DataService.Save(player)
		profiles[player] = nil
	end
end

-- Сохраняет всех сразу (при выключении сервера).
function DataService.SaveAll()
	local pending = 0
	for player in pairs(profiles) do
		pending += 1
		task.spawn(function()
			DataService.Save(player)
			pending -= 1
		end)
	end
	local started = os.clock()
	local limit = RunService:IsStudio() and 5 or 25
	while pending > 0 and os.clock() - started < limit do
		task.wait(0.1)
	end
end

function DataService.ForEachLoaded(callback)
	for player, profile in pairs(profiles) do
		callback(player, profile.Data)
	end
end

return DataService
