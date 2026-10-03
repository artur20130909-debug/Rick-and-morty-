-- Профиль игрока: Amber (валюта лобби), опыт, уровень, ранг, купленные классы.
-- Хранится в DataStore (в несохранённом месте Studio просто живёт в памяти).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Data = {}
local ctx, Config
local store = nil
local profiles = {}      -- [Player] = профиль

local function newProfile()
	return { amber = 0, xp = 0, class = "novice", owned = { novice = true }, wins = 0, nights = 0 }
end

local function syncAttrs(plr)
	local p = profiles[plr]
	if not p then return end
	local lvl = Config.levelOf(p.xp)
	plr:SetAttribute("Amber", p.amber)
	plr:SetAttribute("XP", p.xp)
	plr:SetAttribute("Level", lvl)
	plr:SetAttribute("Rank", Config.rankOf(lvl))
	plr:SetAttribute("Class", p.class)
end

local function load(plr)
	local p = newProfile()
	if store then
		local ok, saved = pcall(function() return store:GetAsync("u" .. plr.UserId) end)
		if ok and type(saved) == "table" then
			p.amber = tonumber(saved.amber) or 0
			p.xp = tonumber(saved.xp) or 0
			p.wins = tonumber(saved.wins) or 0
			p.nights = tonumber(saved.nights) or 0
			if type(saved.owned) == "table" then
				for k, v in pairs(saved.owned) do
					if Config.Classes[k] and v then p.owned[k] = true end
				end
			end
			if type(saved.class) == "string" and p.owned[saved.class] then p.class = saved.class end
		elseif not ok then
			warn("[AA] Не удалось загрузить профиль: " .. tostring(saved))
		end
	end
	profiles[plr] = p
	syncAttrs(plr)
	return p
end

function Data.save(plr)
	local p = profiles[plr]
	if not p or not store then return end
	local ok, err = pcall(function()
		store:SetAsync("u" .. plr.UserId, { amber = p.amber, xp = p.xp, class = p.class, owned = p.owned, wins = p.wins, nights = p.nights })
	end)
	if not ok then warn("[AA] Не удалось сохранить профиль: " .. tostring(err)) end
end

function Data.get(plr)
	return profiles[plr] or load(plr)
end

function Data.snapshot(plr)
	local p = Data.get(plr)
	local lvl = Config.levelOf(p.xp)
	local owned = {}
	for k in pairs(p.owned) do owned[k] = true end
	return { amber = p.amber, xp = p.xp, level = lvl, rank = Config.rankOf(lvl), class = p.class, owned = owned, wins = p.wins, nights = p.nights }
end

function Data.addAmber(plr, n)
	local p = Data.get(plr)
	p.amber = math.max(0, p.amber + math.floor(n))
	syncAttrs(plr)
end

function Data.addXp(plr, n)
	local p = Data.get(plr)
	local before = Config.levelOf(p.xp)
	p.xp = p.xp + math.floor(n)
	syncAttrs(plr)
	local after = Config.levelOf(p.xp)
	if after > before and ctx.Net then
		ctx.Net.event("Toast"):FireClient(plr, "Новый уровень: " .. after .. " · " .. Config.rankOf(after), Color3.fromRGB(255, 190, 60))
	end
end

function Data.addStats(plr, nights, won)
	local p = Data.get(plr)
	p.nights = p.nights + (nights or 0)
	if won then p.wins = p.wins + 1 end
end

function Data.classOf(plr)
	return Data.get(plr).class
end

local function lobbyInvoke(plr, action, key)
	local p = Data.get(plr)
	local c = Config.Classes[key or ""]
	if not c then return { ok = false, msg = "Нет такого класса", profile = Data.snapshot(plr) } end
	if (plr:GetAttribute("MatchId") or 0) ~= 0 then
		return { ok = false, msg = "Классы меняются только в лобби", profile = Data.snapshot(plr) }
	end
	if action == "buyClass" then
		if p.owned[key] then
			p.class = key
			syncAttrs(plr)
			return { ok = true, msg = "Выбран класс: " .. c.name, profile = Data.snapshot(plr) }
		end
		if p.amber < c.price then
			return { ok = false, msg = "Не хватает Amber: нужно " .. c.price, profile = Data.snapshot(plr) }
		end
		p.amber = p.amber - c.price
		p.owned[key] = true
		p.class = key
		syncAttrs(plr)
		Data.save(plr)
		return { ok = true, msg = "Куплен класс: " .. c.name, profile = Data.snapshot(plr) }
	elseif action == "setClass" then
		if not p.owned[key] then return { ok = false, msg = "Сначала купи этот класс", profile = Data.snapshot(plr) } end
		p.class = key
		syncAttrs(plr)
		return { ok = true, msg = "Выбран класс: " .. c.name, profile = Data.snapshot(plr) }
	end
	return { ok = false, msg = "Неизвестное действие", profile = Data.snapshot(plr) }
end

function Data.init(c)
	ctx = c
	Config = c.Config
	local ok, err = pcall(function() store = DataStoreService:GetDataStore("AmberAlertRemake_v1") end)
	if not ok then
		store = nil
		warn("[AA] Сохранение недоступно (опубликуй место и включи API Services): " .. tostring(err))
	end
	c.Net.func("Profile").OnServerInvoke = function(plr) return Data.snapshot(plr) end
	c.Net.func("Lobby").OnServerInvoke = function(plr, action, key)
		local okL, res = pcall(lobbyInvoke, plr, action, key)
		if okL then return res end
		warn("[AA] Ошибка Lobby: " .. tostring(res))
		return { ok = false, msg = "Ошибка", profile = Data.snapshot(plr) }
	end
	Players.PlayerAdded:Connect(load)
	for _, p in ipairs(Players:GetPlayers()) do if not profiles[p] then load(p) end end
	Players.PlayerRemoving:Connect(function(plr)
		Data.save(plr)
		profiles[plr] = nil
	end)
	game:BindToClose(function()
		for _, p in ipairs(Players:GetPlayers()) do Data.save(p) end
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			for _, p in ipairs(Players:GetPlayers()) do task.spawn(Data.save, p) end
		end
	end)
end

return Data
