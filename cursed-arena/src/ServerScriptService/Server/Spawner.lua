-- Игроки: появление, внешний вид аватара, смена персонажа, возрождение, статистика.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Characters = require(Shared.Characters)
local Costumes = require(Shared.Costumes)
local Fighters = require(script.Parent.Fighters)
local Combat = require(script.Parent.Combat)
local Net = require(script.Parent.Net)

local Spawner = {}

local function stat(player, name)
	local ls = player:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild(name)
end

-- имя для ленты убийств
function Spawner.nameOf(f)
	if not f then return "?" end
	if f.player then return f.player.DisplayName end
	return f.model:GetAttribute("DisplayName") or f.model.Name
end

local function setupWeapon(f)
	local w = f.model:FindFirstChild("Weapon")
	if f.charId == "CrimsonBlade" then
		if not w then Costumes.sword(f.model, f.def.Color) end
	elseif w then
		w:Destroy()
	end
end
Spawner.setupWeapon = setupWeapon

local function applyAppearance(player, model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum or player.UserId <= 0 then return end
	local ok, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(player.UserId) end)
	if not ok or not desc then return end
	-- масштаб R15 к R6 не относится
	pcall(function()
		desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale = 1, 1, 1, 1
		desc.BodyTypeScale, desc.ProportionScale = 0, 0
	end)
	local ok2, err = pcall(function() hum:ApplyDescription(desc) end)
	if not ok2 then warn("[Spawner] не удалось надеть аватар: " .. tostring(err)) end
end

local function onCharacter(player, model)
	local charId = player:GetAttribute("CharId")
	if not Characters.valid(charId) then charId = Characters.Default end
	local f = Fighters.new(model, "player", player, charId)
	if not f then return end
	setupWeapon(f)
	task.spawn(applyAppearance, player, model)
	Net.to(player, "Spawned", { c = charId })
end

local function onPlayerAdded(player)
	if not Characters.valid(player:GetAttribute("CharId")) then
		player:SetAttribute("CharId", Characters.Default)
	end
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local kills = Instance.new("IntValue")
	kills.Name = "Убийства"
	kills.Parent = ls
	local streak = Instance.new("IntValue")
	streak.Name = "Серия"
	streak.Parent = ls
	ls.Parent = player
	player.CharacterAdded:Connect(function(model) onCharacter(player, model) end)
	task.defer(function()
		if player.Parent then player:LoadCharacter() end
	end)
end

function Spawner.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in ipairs(Players:GetPlayers()) do onPlayerAdded(p) end
	Players.PlayerRemoving:Connect(function(player)
		local f = Fighters.ofPlayer(player)
		if f then Fighters.remove(f) end
	end)

	-- убийства: статистика, лента, возрождение игрока
	table.insert(Combat.onKill, function(killer, victim)
		local kname, vname = Spawner.nameOf(killer), Spawner.nameOf(victim)
		Net.fx("Kill", {
			k = killer and kname or nil, kc = killer and killer.def.Color or nil,
			v = vname, vc = victim.def.Color, kind = victim.kind,
		})
		if victim.player then
			local s = stat(victim.player, "Серия")
			if s then s.Value = 0 end
			local p = victim.player
			local model = victim.model
			task.delay(Config.RespawnTime, function()
				if p.Parent and p.Character == model then p:LoadCharacter() end
			end)
		end
		if killer and killer.player and killer ~= victim then
			local k = stat(killer.player, "Убийства")
			if k then k.Value = k.Value + 1 end
			local s = stat(killer.player, "Серия")
			if s then
				s.Value = s.Value + 1
				local n = s.Value
				if n == 3 or n == 5 or n == 10 or (n > 10 and n % 5 == 0) then
					Net.fx("Streak", { name = kname, n = n, c = killer.def.Color })
				end
			end
			-- небольшая награда: немного шкалы и здоровья
			Combat.addMeter(killer, 12)
			if Fighters.alive(killer) then
				killer.hum.Health = math.min(killer.hum.MaxHealth, killer.hum.Health + 10)
			end
		end
	end)
end

-- смена персонажа (из меню)
function Spawner.select(player, charId)
	if not Characters.valid(charId) then return end
	local f = Fighters.ofPlayer(player)
	if f and Fighters.alive(f) then
		local now = Util.now()
		if f.charId == charId then return end
		if now - math.max(f.lastDamageTime, f.lastDealtTime) < Config.InCombatTime then
			Net.to(player, "Notify", { text = "В бою персонажа сменить нельзя — подожди пару секунд", kind = "bad" })
			Net.to(player, "Selected", { c = player:GetAttribute("CharId"), ok = false })
			return
		end
		player:SetAttribute("CharId", charId)
		Combat.cancelMove(f)
		if f.awakened then Combat.endAwaken(f) end
		f.charId = charId
		f.def = Characters.get(charId)
		f.cds = { 0, 0, 0, 0 }
		f.m1Index = 0
		Combat.setMeter(f, 0)
		f.model:SetAttribute("Char", charId)
		setupWeapon(f)
		Net.fx("Swap", { m = f.model, c = charId })
		Net.to(player, "Moveset", { awakened = false })
		Net.to(player, "Selected", { c = charId, ok = true })
	else
		player:SetAttribute("CharId", charId)
		Net.to(player, "Selected", { c = charId, ok = true })
	end
end

-- «Возродиться» из меню (если застрял)
function Spawner.respawn(player)
	local f = Fighters.ofPlayer(player)
	if f and Fighters.alive(f) then
		local now = Util.now()
		if now - math.max(f.lastDamageTime, f.lastDealtTime) < Config.InCombatTime then
			Net.to(player, "Notify", { text = "В бою нельзя — подожди пару секунд", kind = "bad" })
			return
		end
	end
	player:LoadCharacter()
end

return Spawner
