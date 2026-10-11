-- Прогресс игроков: загрузка и сохранение в DataStore, атрибуты игрока для интерфейса и таблица лидеров.
-- В неопубликованном Studio DataStore недоступен — игра работает, просто ничего не сохраняет.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("Shared").Config)

local Data = {}
local S
local store = nil
local profiles = {}

local function defaults()
	local baits = {}
	for _, b in ipairs(Config.Baits) do baits[b.key] = 0 end
	return { v = 1, fear = Config.StartFear, net = 1, cages = Config.StartCages, slots = {}, baits = baits, caught = 0, last = 0 }
end

-- из сохранения в рабочий вид: slots — массив {s,k,m} -> таблица slot -> {k,m}
local function fromSaved(saved)
	local p = defaults()
	if type(saved) ~= "table" then return p end
	p.fear = tonumber(saved.fear) or p.fear
	p.net = math.clamp(tonumber(saved.net) or 1, 1, #Config.Nets)
	p.cages = math.clamp(tonumber(saved.cages) or p.cages, Config.StartCages, Config.MaxCages + Config.PassCages)
	p.caught = tonumber(saved.caught) or 0
	p.last = tonumber(saved.last) or 0
	if type(saved.baits) == "table" then
		for k in pairs(p.baits) do p.baits[k] = math.max(0, math.floor(tonumber(saved.baits[k]) or 0)) end
	end
	if type(saved.slots) == "table" then
		for _, e in ipairs(saved.slots) do
			if type(e) == "table" and Config.MonsterIndex[e.k] and tonumber(e.s) then
				p.slots[math.floor(e.s)] = { k = e.k, m = e.m or "" }
			end
		end
	end
	return p
end

local function toSaved(p)
	local slots = {}
	for s, e in pairs(p.slots) do table.insert(slots, { s = s, k = e.k, m = e.m }) end
	table.sort(slots, function(a, b) return a.s < b.s end)
	return { v = 1, fear = math.floor(p.fear), net = p.net, cages = p.cages, slots = slots, baits = p.baits, caught = p.caught, last = os.time() }
end

local function key(player) return "u_" .. player.UserId end

function Data.init(s)
	S = s
	local ok, res = pcall(function() return DataStoreService:GetDataStore(Config.DataStoreName) end)
	if ok then store = res else warn("[CN] DataStore недоступен, прогресс не сохраняется: " .. tostring(res)) end
	-- автосохранение
	task.spawn(function()
		while true do
			task.wait(90)
			for _, pl in ipairs(Players:GetPlayers()) do
				task.spawn(Data.save, pl)
			end
		end
	end)
	game:BindToClose(function()
		if RunService:IsStudio() and not store then return end
		for _, pl in ipairs(Players:GetPlayers()) do task.spawn(Data.save, pl) end
		task.wait(2)
	end)
end

-- загрузка (уступает поток); возвращает профиль
function Data.load(player)
	local saved, failed = nil, false
	if store then
		failed = true
		for attempt = 1, 3 do
			local ok, res = pcall(function() return store:GetAsync(key(player)) end)
			if ok then
				saved, failed = res, false
				break
			end
			warn("[CN] загрузка не удалась (" .. attempt .. "): " .. tostring(res))
			task.wait(1.5)
		end
	end
	local p = fromSaved(saved)
	p.isNew = saved == nil and not failed
	p.noSave = failed -- чтобы не затереть настоящие данные пустыми
	profiles[player] = p
	-- таблица лидеров
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local fear = Instance.new("IntValue")
	fear.Name = "💀 Страх"
	fear.Parent = ls
	local caught = Instance.new("IntValue")
	caught.Name = "👻 Поймано"
	caught.Parent = ls
	ls.Parent = player
	Data.sync(player)
	return p
end

function Data.get(player) return profiles[player] end

function Data.save(player)
	local p = profiles[player]
	if not p or p.noSave or not store then return end
	local payload = toSaved(p)
	local ok, err = pcall(function() store:SetAsync(key(player), payload) end)
	if not ok then warn("[CN] сохранение не удалось: " .. tostring(err)) end
end

function Data.release(player)
	Data.save(player)
	profiles[player] = nil
end

-- максимум клеток с учётом геймпасса
function Data.maxCages(player)
	return Config.MaxCages + (player:GetAttribute("PassExtraCages") and Config.PassCages or 0)
end

-- атрибуты игрока для клиента
function Data.sync(player)
	local p = profiles[player]
	if not p then return end
	player:SetAttribute("Fear", math.floor(p.fear))
	player:SetAttribute("Net", p.net)
	player:SetAttribute("Cages", p.cages)
	player:SetAttribute("MaxCages", Data.maxCages(player))
	player:SetAttribute("Caught", p.caught)
	for k, n in pairs(p.baits) do player:SetAttribute("Bait_" .. k, n) end
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local f = ls:FindFirstChild("💀 Страх")
		if f then f.Value = math.floor(p.fear) end
		local c = ls:FindFirstChild("👻 Поймано")
		if c then c.Value = p.caught end
	end
end

function Data.addFear(player, n)
	local p = profiles[player]
	if not p then return end
	p.fear = p.fear + n
	local v = math.floor(p.fear)
	player:SetAttribute("Fear", v)
	local ls = player:FindFirstChild("leaderstats")
	local f = ls and ls:FindFirstChild("💀 Страх")
	if f then f.Value = v end
end

-- списать; false, если не хватает
function Data.spend(player, n)
	local p = profiles[player]
	if not p or p.fear < n then return false end
	Data.addFear(player, -n)
	return true
end

return Data
