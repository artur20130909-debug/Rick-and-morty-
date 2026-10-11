-- Переноска монстра на голове: пойманного в лесу или украденного с чужой базы.
-- Пока несёшь — идёшь медленнее, и любой может «Отобрать» монстра (подсказка на твоём персонаже).
-- Дошёл до своей базы — монстр сам садится в свободную клетку.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local Monsters = require(Shared.Monsters)

local Carry = {}
local S
local carrying = {}   -- player -> { entry = {k,m}, info = {...}, model }
local stunUntil = {}  -- player -> время
local fullWarn = {}   -- player -> время последнего «нет мест»
local WALK = 16

local function toast(player, text, color) Net.event("Toast"):FireClient(player, text, color) end
local function fx(player, ...) Net.event("Fx"):FireClient(player, ...) end
local function now() return S.Cycle.now() end

local function parts(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local head = char and char:FindFirstChild("Head")
	if hum and hrp and head and hum.Health > 0 then return hum, hrp, head end
	return nil
end

function Carry.get(player) return carrying[player] end

-- скорость: оглушён -> 0, с монстром -> медленнее
function Carry.updateSpeed(player)
	local hum = parts(player)
	if not hum then return end
	if (stunUntil[player] or 0) > now() then
		hum.WalkSpeed = 0
		return
	end
	local st = carrying[player]
	if st then
		local tier = Util.rarityOf(st.entry.k).tier
		hum.WalkSpeed = tier >= 4 and Config.CarryRareSpeed or Config.CarrySpeed
	else
		hum.WalkSpeed = WALK
	end
end

function Carry.stun(player, seconds)
	stunUntil[player] = now() + seconds
	Carry.updateSpeed(player)
	task.delay(seconds + 0.05, function()
		if player.Parent then Carry.updateSpeed(player) end
	end)
end

local function setPrompt(player, on)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local p = hrp and hrp:FindFirstChild("TacklePrompt")
	if p then p.Enabled = on end
end

-- начать нести; false, если персонажа нет
function Carry.start(player, entry, info)
	if carrying[player] then return false end
	local hum, _, head = parts(player)
	if not hum then return false end
	local m, root = Monsters.build(entry.k, entry.m)
	m.Name = "Carried_" .. player.Name
	Monsters.label(m, "🎒 " .. player.DisplayName, 80)
	m:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.3, 0))
	m:SetAttribute("CarrierId", player.UserId)
	m.Parent = workspace.Carried
	root.Anchored = false
	local w = Instance.new("WeldConstraint")
	w.Part0 = head
	w.Part1 = root
	w.Parent = root
	carrying[player] = { entry = { k = entry.k, m = entry.m or "" }, info = info or {}, model = m, since = now() }
	player:SetAttribute("Carrying", Util.fullName(entry.k, entry.m))
	player:SetAttribute("CarryRarity", Util.rarityOf(entry.k).key)
	setPrompt(player, true)
	Carry.updateSpeed(player)
	fx(player, "carry", Util.fullName(entry.k, entry.m))
	return true
end

-- перестать нести (монстр исчезает); вернуть состояние
local function stop(player)
	local st = carrying[player]
	if not st then return nil end
	carrying[player] = nil
	if st.model then st.model:Destroy() end
	if player.Parent then
		player:SetAttribute("Carrying", "")
		player:SetAttribute("CarryRarity", "")
		setPrompt(player, false)
		Carry.updateSpeed(player)
	end
	return st
end

-- уронить: mode = "wild" (монстр убегает в лес рядом) или "leave" (игрок вышел/умер)
function Carry.drop(player, mode, pos)
	local st = carrying[player]
	if not st then return end
	if not pos then
		local root = st.model and st.model.PrimaryPart
		pos = root and root.Position or nil
	end
	stop(player)
	-- украденный монстр при выходе вора возвращается хозяину, если тот на сервере
	if mode == "leave" and st.info.from == "steal" then
		local owner = Players:GetPlayerByUserId(st.info.ownerId or 0)
		if owner and owner ~= player and S.Bases.place(owner, st.entry) then
			toast(owner, Util.fullName(st.entry.k, st.entry.m) .. " вернулся к тебе!", Color3.fromRGB(120, 255, 140))
			return
		end
	end
	if pos and S.Wild then
		S.Wild.spawn({ pos = Vector3.new(pos.X, 0, pos.Z), key = st.entry.k, mut = st.entry.m, fromDrop = true })
	end
end

-- отнести на свою базу
local function deliver(player, st)
	local slot = S.Bases.place(player, st.entry)
	if not slot then
		if (fullWarn[player] or 0) < now() then
			fullWarn[player] = now() + 4
			toast(player, "Нет свободных клеток! Продай монстра или купи клетку", Color3.fromRGB(255, 120, 90))
		end
		return
	end
	stop(player)
	local name = Util.fullName(st.entry.k, st.entry.m)
	local r = Util.rarityOf(st.entry.k)
	local p = S.Data.get(player)
	local info = st.info
	if info.from == "steal" and info.ownerId ~= player.UserId then
		if r.tier >= Config.StealAnnounceTier then
			S.Cycle.announce(string.format("🦹 %s украл %s у %s!", player.DisplayName, name, info.ownerName or "?"), r.color)
		end
		toast(player, "Украдено: " .. name .. "!", r.color)
	elseif info.from == "steal" then
		toast(player, "Вернул своего: " .. name, Color3.fromRGB(120, 255, 140))
	else
		if p then
			p.caught = p.caught + 1
			S.Data.sync(player)
		end
		if r.tier >= Config.AnnounceTier then
			S.Cycle.announce(string.format("🔥 %s поймал: %s (%s, 1 к %s)!", player.DisplayName, name, r.name, Util.num(r.chance)), r.color)
		end
	end
	fx(player, "delivered", name, r.key)
end

-- отобрать монстра у игрока
local function tackle(thief, victim)
	if thief == victim then return end
	local st = carrying[victim]
	if not st or carrying[thief] then return end
	if (st.immune or 0) > now() then
		toast(thief, "Не вышло — попробуй ещё раз через секунду", Color3.fromRGB(255, 200, 90))
		return
	end
	local _, hrpT = parts(thief)
	local _, hrpV = parts(victim)
	if not hrpT or not hrpV or (hrpT.Position - hrpV.Position).Magnitude > 14 then return end
	stop(victim)
	local info = st.info
	if info.from ~= "steal" then
		-- пойманный в лесу становится «украденным» у того, кто его поймал
		info = { from = "steal", ownerId = victim.UserId, ownerName = victim.DisplayName }
	end
	if Carry.start(thief, st.entry, info) then
		carrying[thief].immune = now() + Config.TackleImmunity
		Carry.stun(victim, 1)
		local name = Util.fullName(st.entry.k, st.entry.m)
		fx(victim, "tackled", name, thief.DisplayName)
		toast(thief, "Отобрал " .. name .. "! Беги на базу!", Color3.fromRGB(255, 220, 90))
	else
		Carry.drop(victim, "wild", hrpV.Position)
	end
end

-- новый персонаж: подсказка «Отобрать» и смерть
function Carry.onCharacter(player, char)
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hrp or not hum then return end
	local p = Instance.new("ProximityPrompt")
	p.Name = "TacklePrompt"
	p.ActionText = "Отобрать"
	p.ObjectText = player.DisplayName
	p.HoldDuration = Config.TackleHold
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.F
	p.Enabled = false
	p:SetAttribute("For", "notself")
	p:SetAttribute("UserId", player.UserId)
	p.Parent = hrp
	p.Triggered:Connect(function(thief) tackle(thief, player) end)
	hum.Died:Connect(function()
		Carry.drop(player, "leave", hrp.Position)
	end)
	stunUntil[player] = nil
	Carry.updateSpeed(player)
end

function Carry.onLeave(player)
	Carry.drop(player, "leave")
	stunUntil[player] = nil
	fullWarn[player] = nil
end

function Carry.init(s)
	S = s
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(function()
				for player, st in pairs(carrying) do
					local _, hrp = parts(player)
					if not hrp or not st.model.Parent then
						Carry.drop(player, "leave")
					else
						local rec = S.Bases.baseOf(player)
						if rec and S.Bases.inBase(rec, hrp.Position) then deliver(player, st) end
					end
				end
			end)
			if not ok then warn("[CN] Carry: " .. tostring(err)) end
		end
	end)
end

return Carry
