-- Базы игроков: выдача базы, монстры в клетках, доход каждую секунду, замок двери,
-- кража из чужой клетки, продажа, покупка клетки (через Shop).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local Monsters = require(Shared.Monsters)

local Bases = {}
local S
local list = {}
local byPlayer = {}
local HALF = Config.Map.BaseSize / 2

local function toast(player, text, color) Net.event("Toast"):FireClient(player, text, color) end
local function fx(player, ...) Net.event("Fx"):FireClient(player, ...) end

local function alive(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hum and hrp and hum.Health > 0 then return hrp end
	return nil
end

function Bases.baseOf(player) return byPlayer[player] end
function Bases.all() return list end

-- точка внутри базы?
function Bases.inBase(rec, pos)
	local p = rec.cf:PointToObjectSpace(pos)
	return math.abs(p.X) <= HALF and math.abs(p.Z) <= HALF and p.Y < 40
end

-- база, в которой стоит точка (или nil)
function Bases.at(pos)
	for _, rec in ipairs(list) do
		if Bases.inBase(rec, pos) then return rec end
	end
	return nil
end

function Bases.spawnCF(player)
	local rec = byPlayer[player]
	if not rec then return nil end
	return rec.model.Spawn.CFrame
end

function Bases.incomeOf(player)
	local p = S.Data.get(player)
	if not p then return 0 end
	local sum = 0
	for _, e in pairs(p.slots) do sum = sum + Util.income(e.k, e.m) end
	if player:GetAttribute("PassDoubleFear") then sum = sum * 2 end
	return sum
end

---------------------------------------------------------------- клетки
local function slotModel(rec, s) return rec.model.Slots:FindFirstChild("Slot_" .. s) end

local function setBars(sm, visible)
	for _, b in ipairs(sm.Bars:GetChildren()) do
		b.Transparency = visible and 0 or 0.85
	end
end

-- обновить вид и подсказки клетки
function Bases.refreshSlot(rec, s)
	local sm = slotModel(rec, s)
	if not sm then return end
	local owner = rec.owner
	local p = owner and S.Data.get(owner)
	local open = p ~= nil and s <= p.cages
	local entry = p and open and p.slots[s] or nil
	local nextBuy = p ~= nil and s == p.cages + 1 and s <= S.Data.maxCages(owner)
	local pad = sm.Pad
	local att = pad.PromptAtt

	setBars(sm, open)
	if entry then
		sm.Rim.Color = Util.rarityOf(entry.k).color
	elseif open then
		sm.Rim.Color = Color3.fromRGB(85, 85, 92)
	else
		sm.Rim.Color = Color3.fromRGB(30, 30, 34)
	end

	-- монстр
	local cur = rec.monsters[s]
	if cur and (not entry or cur:GetAttribute("Key") ~= entry.k or cur:GetAttribute("Mutation") ~= entry.m) then
		cur:Destroy()
		cur = nil
		rec.monsters[s] = nil
	end
	if entry and not cur then
		local m = Monsters.build(entry.k, entry.m)
		m.Name = "Monster"
		m:PivotTo(sm.Anchor.CFrame)
		local inc = Util.income(entry.k, entry.m)
		if owner:GetAttribute("PassDoubleFear") then inc = inc * 2 end
		Monsters.label(m, "+" .. Util.num(inc) .. " 💀/с", 45)
		m.Parent = sm
		CollectionService:AddTag(m, "CageMonster")
		rec.monsters[s] = m
	end

	-- подсказки
	local locked = rec.model:GetAttribute("Locked")
	att.StealPrompt.Enabled = entry ~= nil and not locked
	att.StealPrompt.ObjectText = entry and Util.fullName(entry.k, entry.m) or ""
	att.SellPrompt.Enabled = entry ~= nil
	att.SellPrompt.ObjectText = entry and ("+" .. Util.num(Util.sellPrice(entry.k, entry.m)) .. " 💀") or ""
	att.BuyPrompt.Enabled = nextBuy
	local price = Config.CagePrices[s] or 0
	att.BuyPrompt.ObjectText = Util.num(price) .. " 💀"
	pad.LockedGui.Enabled = nextBuy
	pad.LockedGui.Text.Text = "🔒 " .. Util.num(price) .. " 💀"
end

function Bases.refreshAll(rec)
	for s = 1, #rec.slots do Bases.refreshSlot(rec, s) end
end

-- force — пересоздать модели монстров (например, после геймпасса ×2 меняются подписи)
function Bases.refreshPlayer(player, force)
	local rec = byPlayer[player]
	if not rec then return end
	if force then
		for s, m in pairs(rec.monsters) do
			m:Destroy()
			rec.monsters[s] = nil
		end
	end
	Bases.refreshAll(rec)
end

-- первая свободная открытая клетка
function Bases.freeSlot(player)
	local p = S.Data.get(player)
	if not p then return nil end
	for s = 1, p.cages do
		if not p.slots[s] then return s end
	end
	return nil
end

-- положить монстра в клетку; номер клетки или nil
function Bases.place(player, entry)
	local rec = byPlayer[player]
	local p = S.Data.get(player)
	local s = Bases.freeSlot(player)
	if not rec or not p or not s then return nil end
	p.slots[s] = { k = entry.k, m = entry.m or "" }
	Bases.refreshSlot(rec, s)
	return s
end

---------------------------------------------------------------- владельцы
local function setOwnerVisuals(rec)
	local m = rec.model
	local owner = rec.owner
	m:SetAttribute("OwnerId", owner and owner.UserId or 0)
	m:SetAttribute("OwnerName", owner and owner.DisplayName or "")
	m.SignBoard.Sign.OwnerText.Text = owner and ("База " .. owner.DisplayName) or "Свободная база"
	m.Top.OwnerGui.NameText.Text = owner and owner.DisplayName or ""
	m.Top.OwnerGui.Income.Text = ""
end

function Bases.assign(player)
	if byPlayer[player] then return byPlayer[player] end
	for _, rec in ipairs(list) do
		if not rec.owner then
			rec.owner = player
			byPlayer[player] = rec
			player:SetAttribute("BaseIndex", rec.index)
			setOwnerVisuals(rec)
			Bases.refreshAll(rec)
			return rec
		end
	end
	return nil
end

function Bases.release(player)
	local rec = byPlayer[player]
	if not rec then return end
	byPlayer[player] = nil
	rec.owner = nil
	for s, m in pairs(rec.monsters) do
		m:Destroy()
		rec.monsters[s] = nil
	end
	Bases.unlock(rec)
	setOwnerVisuals(rec)
	Bases.refreshAll(rec)
end

---------------------------------------------------------------- замок
function Bases.lock(rec)
	local m = rec.model
	if m:GetAttribute("Locked") then return false end
	m:SetAttribute("Locked", true)
	m:SetAttribute("LockEnds", S.Cycle.now() + Config.LockSeconds)
	m.Door.Transparency = 0.35
	m.Door.CanCollide = true
	m.Door.LockGui.Enabled = true
	m.LockPad.Color = Color3.fromRGB(255, 60, 70)
	Bases.refreshAll(rec)
	return true
end

function Bases.unlock(rec)
	local m = rec.model
	m:SetAttribute("Locked", false)
	m:SetAttribute("LockEnds", 0)
	m.Door.Transparency = 1
	m.Door.CanCollide = false
	m.Door.LockGui.Enabled = false
	m.LockPad.Color = Color3.fromRGB(60, 255, 106)
	if rec.owner then Bases.refreshAll(rec) end
end

---------------------------------------------------------------- действия у клеток
local function near(player, part, dist)
	local hrp = alive(player)
	return hrp ~= nil and (hrp.Position - part.Position).Magnitude <= dist
end

function Bases.steal(thief, rec, s)
	local owner = rec.owner
	if not owner or owner == thief then return end
	if rec.model:GetAttribute("Locked") then
		toast(thief, "База заперта!", Color3.fromRGB(255, 90, 90))
		return
	end
	if S.Carry.get(thief) then
		toast(thief, "Руки заняты — сначала отнеси монстра на базу", Color3.fromRGB(255, 200, 90))
		return
	end
	local sm = slotModel(rec, s)
	if not sm or not near(thief, sm.Pad, 16) then return end
	local p = S.Data.get(owner)
	local entry = p and p.slots[s]
	if not entry then return end
	p.slots[s] = nil
	Bases.refreshSlot(rec, s)
	local ok = S.Carry.start(thief, { k = entry.k, m = entry.m }, { from = "steal", ownerId = owner.UserId, ownerName = owner.DisplayName })
	if not ok then
		p.slots[s] = entry
		Bases.refreshSlot(rec, s)
		return
	end
	local name = Util.fullName(entry.k, entry.m)
	fx(owner, "stolen", name, thief.DisplayName)
	toast(thief, "Утащил " .. name .. "! Беги на свою базу!", Color3.fromRGB(255, 220, 90))
end

function Bases.sell(player, rec, s)
	if rec.owner ~= player then return end
	local p = S.Data.get(player)
	local entry = p and p.slots[s]
	if not entry then return end
	local sm = slotModel(rec, s)
	if not sm or not near(player, sm.Pad, 16) then return end
	local price = Util.sellPrice(entry.k, entry.m)
	p.slots[s] = nil
	S.Data.addFear(player, price)
	Bases.refreshSlot(rec, s)
	fx(player, "cash", price)
	toast(player, "Продано: " .. Util.fullName(entry.k, entry.m) .. " за " .. Util.num(price) .. " 💀", Color3.fromRGB(255, 220, 90))
end

---------------------------------------------------------------- запуск
function Bases.init(s, models)
	S = s
	for i, m in ipairs(models) do
		local floor = m.Floor
		local rec = {
			index = i, model = m, owner = nil, monsters = {}, slots = {},
			cf = CFrame.new(floor.Position.X, 0, floor.Position.Z) * floor.CFrame.Rotation,
		}
		for _, sm in ipairs(m.Slots:GetChildren()) do
			rec.slots[sm:GetAttribute("Slot")] = sm
		end
		list[i] = rec
		m.LockPad.Attachment.LockPrompt.Triggered:Connect(function(player)
			if rec.owner ~= player then return end
			if Bases.lock(rec) then
				toast(player, "🔒 База заперта на " .. Config.LockSeconds .. " секунд", Color3.fromRGB(120, 255, 140))
			else
				toast(player, "База уже заперта", Color3.fromRGB(255, 200, 90))
			end
		end)
		for idx, sm in pairs(rec.slots) do
			local att = sm.Pad.PromptAtt
			att.StealPrompt.Triggered:Connect(function(player) Bases.steal(player, rec, idx) end)
			att.SellPrompt.Triggered:Connect(function(player) Bases.sell(player, rec, idx) end)
			att.BuyPrompt.Triggered:Connect(function(player)
				if rec.owner == player then S.Shop.buyCage(player) end
			end)
		end
	end

	-- доход каждую секунду и снятие замков
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				local t = S.Cycle.now()
				for _, rec in ipairs(list) do
					local m = rec.model
					if m:GetAttribute("Locked") and (m:GetAttribute("LockEnds") or 0) <= t then Bases.unlock(rec) end
					local owner = rec.owner
					if owner and owner.Parent then
						local inc = Bases.incomeOf(owner)
						if inc > 0 then S.Data.addFear(owner, inc) end
						owner:SetAttribute("Income", inc)
						m:SetAttribute("Income", inc)
						m.Top.OwnerGui.Income.Text = "+" .. Util.num(inc) .. " 💀/с"
					end
				end
			end)
			if not ok then warn("[CN] Bases: " .. tostring(err)) end
		end
	end)
end

return Bases
