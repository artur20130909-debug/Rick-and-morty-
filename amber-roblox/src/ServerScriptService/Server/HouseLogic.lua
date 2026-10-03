-- Логика дома: двери (открыть / закрыть / запереть / выбить), окна, укрытия,
-- яблони, электрощиток и свет. Работает с моделью дома из HouseMap (контракт — ARCHITECTURE.md §6).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local HouseLogic = {}
local ctx, Config, Sound, Net
local doorState = setmetatable({}, { __mode = "k" })   -- [дверь] = { closed, openCF, leafCopy, token, match }
local hideOwner = {}                                    -- [Player] = { hide, match, t0, fails }

local function warnOnce(tag, err)
	HouseLogic._warned = HouseLogic._warned or {}
	if HouseLogic._warned[tag] then return end
	HouseLogic._warned[tag] = true
	warn("[AA] HouseLogic " .. tag .. ": " .. tostring(err))
end

local function inMatch(match, plr)
	return plr and plr:GetAttribute("MatchId") == match.id and match:isAlive(plr)
end

local function connect(match, signal, fn)
	match.conns = match.conns or {}
	local c = signal:Connect(function(...)
		local ok, err = pcall(fn, ...)
		if not ok then warnOnce("prompt", err) end
	end)
	table.insert(match.conns, c)
	return c
end

---------------------------------------------------------------- двери
local function panelOf(door)
	local leaf = door:FindFirstChild("Leaf")
	return leaf and (leaf.PrimaryPart or leaf:FindFirstChild("Panel")), leaf
end

local function updateDoorPrompts(door)
	local panel = panelOf(door)
	if not panel then return end
	local broken = door:GetAttribute("Broken") == true
	local p = panel:FindFirstChild("Prompt")
	local lp = panel:FindFirstChild("LockPrompt")
	if p then
		p.Enabled = not broken
		if door:GetAttribute("Open") then p.ActionText = "Закрыть"
		elseif door:GetAttribute("Locked") then p.ActionText = "Заперто"
		else p.ActionText = "Открыть" end
	end
	if lp then
		lp.Enabled = not broken
		lp.ActionText = door:GetAttribute("Locked") and "Отпереть" or "Запереть"
	end
end

function HouseLogic.isOpen(door)
	return door:GetAttribute("Open") == true or door:GetAttribute("Broken") == true
end

function HouseLogic.isLocked(door)
	return door:GetAttribute("Locked") == true and door:GetAttribute("Broken") ~= true
end

-- открыть/закрыть с плавным поворотом вокруг петли
function HouseLogic.setDoor(door, open, byInmate)
	local st = doorState[door]
	if not st or door:GetAttribute("Broken") then return false end
	if open and door:GetAttribute("Locked") then return false end
	if (door:GetAttribute("Open") == true) == open then return true end
	local panel, leaf = panelOf(door)
	if not leaf then return false end
	door:SetAttribute("Open", open)
	st.token = st.token + 1
	local my = st.token
	local cv = Instance.new("CFrameValue")
	cv.Value = leaf:GetPivot()
	cv.Changed:Connect(function(v)
		if st.token == my and leaf.Parent then leaf:PivotTo(v) end
	end)
	local tw = TweenService:Create(cv, TweenInfo.new(byInmate and 0.25 or 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = open and st.openCF or st.closed })
	tw.Completed:Connect(function() cv:Destroy() end)
	tw:Play()
	updateDoorPrompts(door)
	if panel then Sound.play(open and "DoorOpen" or "DoorClose", panel, { Volume = byInmate and 0.9 or 0.6 }) end
	return true
end

function HouseLogic.setLocked(door, locked)
	if door:GetAttribute("Broken") then return end
	if locked and door:GetAttribute("Open") then HouseLogic.setDoor(door, false) end
	door:SetAttribute("Locked", locked)
	updateDoorPrompts(door)
	local panel = panelOf(door)
	if panel then Sound.play("DoorLock", panel) end
end

local function breakDoor(door)
	local panel, leaf = panelOf(door)
	door:SetAttribute("Broken", true)
	door:SetAttribute("Open", true)
	door:SetAttribute("Locked", false)
	updateDoorPrompts(door)
	if panel then Sound.play("DoorBreak", panel, { Volume = 1 }) end
	if not leaf then return end
	local push = panel and panel.CFrame.LookVector or Vector3.new(0, 0, 1)
	if math.random() < 0.5 then push = -push end
	for _, p in ipairs(leaf:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanQuery = false
			p.AssemblyLinearVelocity = push * (18 + math.random() * 10) + Vector3.new(0, 8, 0)
			pcall(function() p:SetNetworkOwner(nil) end)
		end
	end
	task.delay(1.5, function()
		for _, p in ipairs(leaf:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end)
end

-- удар по запертой двери; true — дверь выбита
function HouseLogic.damageDoor(door, amount)
	if door:GetAttribute("Broken") then return true end
	local h = (door:GetAttribute("Health") or 100) - (amount or 25)
	door:SetAttribute("Health", h)
	local st = doorState[door]
	local panel, leaf = panelOf(door)
	if panel then Sound.play("DoorBash", panel, { Volume = 1, PlaybackSpeed = 0.9 + math.random() * 0.2 }) end
	if h <= 0 then
		breakDoor(door)
		return true
	end
	-- дверь вздрагивает от удара
	if st and leaf and not door:GetAttribute("Open") then
		leaf:PivotTo(st.closed * CFrame.new(0, 0, (math.random() - 0.5) * 0.3) * CFrame.Angles(0, math.rad((math.random() - 0.5) * 3), 0))
		task.delay(0.08, function()
			if leaf.Parent and not door:GetAttribute("Open") and not door:GetAttribute("Broken") then leaf:PivotTo(st.closed) end
		end)
	end
	return false
end

local function wireDoor(match, door)
	local panel = panelOf(door)
	if not panel then return end
	local p = panel:FindFirstChild("Prompt")
	local lp = panel:FindFirstChild("LockPrompt")
	if p then
		connect(match, p.Triggered, function(plr)
			if not inMatch(match, plr) then return end
			if door:GetAttribute("Locked") and not door:GetAttribute("Open") then
				Sound.play("DoorLock", panel, { PlaybackSpeed = 1.3 })
				Net.event("Toast"):FireClient(plr, "Заперто. Держи R, чтобы отпереть.")
				return
			end
			HouseLogic.setDoor(door, not door:GetAttribute("Open"))
		end)
	end
	if lp then
		connect(match, lp.Triggered, function(plr)
			if not inMatch(match, plr) then return end
			HouseLogic.setLocked(door, not door:GetAttribute("Locked"))
		end)
	end
	updateDoorPrompts(door)
end

local function initDoor(match, door)
	local _, leaf = panelOf(door)
	local hinge = door:FindFirstChild("Hinge")
	if not leaf or not hinge then
		warnOnce("door " .. door.Name, "нет Leaf/Hinge")
		return
	end
	local closed = leaf:GetPivot()
	local h = hinge.CFrame
	local angle = math.rad(door:GetAttribute("OpenAngle") or 95)
	local rot = h * CFrame.Angles(0, angle, 0) * h:Inverse()
	doorState[door] = { closed = closed, openCF = rot * closed, leafCopy = leaf:Clone(), token = 0, match = match }
	door:SetAttribute("Open", false)
	door:SetAttribute("Locked", false)
	door:SetAttribute("Broken", false)
	door:SetAttribute("Health", 100)
	wireDoor(match, door)
end

-- утром двери чинят: выбитые ставим заново
local function repairDoor(match, door)
	local st = doorState[door]
	if not st then return end
	if door:GetAttribute("Broken") then
		local old = door:FindFirstChild("Leaf")
		if old then old:Destroy() end
		local leaf = st.leafCopy:Clone()
		leaf.Parent = door
		leaf:PivotTo(st.closed)
		door:SetAttribute("Broken", false)
		door:SetAttribute("Open", false)
		wireDoor(match, door)
	end
	door:SetAttribute("Health", 100)
	updateDoorPrompts(door)
end

---------------------------------------------------------------- окна
function HouseLogic.breakWindow(window)
	if window:GetAttribute("Broken") then return end
	window:SetAttribute("Broken", true)
	local glass = window:FindFirstChild("Glass")
	if not glass then return end
	glass.Transparency = 1
	glass.CanCollide = false
	glass.CanQuery = false
	Sound.play("GlassBreak", glass, { Volume = 1 })
	local props = workspace:FindFirstChild("Props")
	for _ = 1, 10 do
		local s = 0.2 + math.random() * 0.5
		local shard = Instance.new("Part")
		shard.Name = "Shard"
		shard.Size = Vector3.new(s, s * 1.4, 0.05)
		shard.Material = Enum.Material.Glass
		shard.Transparency = 0.4
		shard.Color = Color3.fromRGB(200, 225, 235)
		shard.CanCollide = true
		shard.CanQuery = false
		shard.CFrame = glass.CFrame * CFrame.new((math.random() - 0.5) * glass.Size.X, (math.random() - 0.5) * glass.Size.Y, 0)
			* CFrame.Angles(math.random() * 3, math.random() * 3, math.random() * 3)
		shard.AssemblyLinearVelocity = glass.CFrame.LookVector * (math.random() - 0.5) * 30 + Vector3.new(0, 4, 0)
		shard.Parent = props or workspace
		Debris:AddItem(shard, 6)
	end
end

local function repairWindow(window)
	if not window:GetAttribute("Broken") then return end
	window:SetAttribute("Broken", false)
	local glass = window:FindFirstChild("Glass")
	if glass then
		glass.Transparency = glass:GetAttribute("T0") or 0.5
		glass.CanCollide = true
		glass.CanQuery = true
	end
end

---------------------------------------------------------------- укрытия
function HouseLogic.occupant(hide)
	local id = hide:GetAttribute("Occupant") or 0
	if id == 0 then return nil end
	return Players:GetPlayerByUserId(id)
end

function HouseLogic.hiddenIn(plr)
	local h = hideOwner[plr]
	return h and h.hide or nil
end

function HouseLogic.hide(match, plr, hide)
	if hideOwner[plr] or HouseLogic.occupant(hide) then return false end
	if match.phase == "alert" or match.phase == "loading" or match.phase == "end" then return false end
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local inside = hide:FindFirstChild("Inside")
	if not hrp or not inside then return false end
	hide:SetAttribute("Occupant", plr.UserId)
	plr:SetAttribute("Hidden", true)
	hideOwner[plr] = { hide = hide, match = match, t0 = os.clock(), fails = 0 }
	hrp.Anchored = true
	char:PivotTo(inside.CFrame)
	Sound.play("DoorClose", inside, { Volume = 0.5 })
	Net.event("Hidden"):FireClient(plr, hide)
	return true
end

function HouseLogic.unhide(plr)
	local h = hideOwner[plr]
	if not h then return false end
	hideOwner[plr] = nil
	if h.hide.Parent then h.hide:SetAttribute("Occupant", 0) end
	plr:SetAttribute("Hidden", false)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		local exit = h.hide:FindFirstChild("Exit")
		if exit and h.hide.Parent then char:PivotTo(exit.CFrame + Vector3.new(0, 3, 0)) end
		hrp.Anchored = false
		local inside = h.hide:FindFirstChild("Inside")
		if inside then Sound.play("DoorOpen", inside, { Volume = 0.5 }) end
	end
	Net.event("Hidden"):FireClient(plr, nil)
	return true
end

-- заключённый вытаскивает игрока из укрытия
function HouseLogic.pullOut(match, plr)
	if not hideOwner[plr] then return false end
	HouseLogic.unhide(plr)
	match:fxTo(plr, "shake", 1.4, 0.6)
	match:fxTo(plr, "sound", "Stinger")
	Net.event("Toast"):FireClient(plr, "Тебя нашли!", Color3.fromRGB(255, 70, 70))
	return true
end

-- концентрация в укрытии: провал рядом с заключённым — тебя слышат
function HouseLogic.qte(plr, ok)
	local h = hideOwner[plr]
	if not h then return end
	if ok then return end
	h.fails = h.fails + 1
	local inside = h.hide:FindFirstChild("Inside")
	local pos = inside and inside.Position
	if not pos then return end
	local heard = false
	for _, inm in ipairs(h.match.inmates or {}) do
		if inm.root and inm.root.Parent and (inm.root.Position - pos).Magnitude < 24 then heard = true end
	end
	if heard then
		HouseLogic.pullOut(h.match, plr)
	else
		Net.event("Toast"):FireClient(plr, "Тише... ты шумишь", Color3.fromRGB(255, 190, 120))
	end
end

---------------------------------------------------------------- яблони
local function setVisible(model, vis)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			if p:GetAttribute("T0") == nil then
				p:SetAttribute("T0", p.Transparency)
				p:SetAttribute("CC0", p.CanCollide)
			end
			p.Transparency = vis and p:GetAttribute("T0") or 1
			p.CanCollide = vis and p:GetAttribute("CC0") or false
		end
	end
end

function HouseLogic.updateTree(tree)
	local planted = tree:GetAttribute("Planted") == true
	local n = tree:GetAttribute("Apples") or 0
	local plant = tree:FindFirstChild("Plant")
	if plant then setVisible(plant, planted) end
	local apples = tree:FindFirstChild("Apples")
	if apples then
		for i = 1, 8 do
			local a = apples:FindFirstChild("Apple" .. i)
			if a then
				if a:GetAttribute("T0") == nil then a:SetAttribute("T0", a.Transparency) end
				a.Transparency = (planted and n >= i) and a:GetAttribute("T0") or 1
				a.CanCollide = false
			end
		end
	end
	local p = tree:FindFirstChild("Prompt", true)
	if p then
		p.Enabled = planted and n > 0
		p.ObjectText = "Яблоня · " .. n
	end
end

function HouseLogic.plantTree(match)
	for _, t in ipairs(match.house.trees or {}) do
		if not t:GetAttribute("Planted") then
			t:SetAttribute("Planted", true)
			t:SetAttribute("Apples", 1)
			HouseLogic.updateTree(t)
			return true
		end
	end
	return false
end

-- раз в Config.AppleGrowSeconds на каждом посаженном дереве прибавляется яблоко
function HouseLogic.growApples(match)
	for _, t in ipairs(match.house.trees or {}) do
		local n = t:GetAttribute("Apples") or 0
		if t:GetAttribute("Planted") and n < Config.TreeMaxApples then
			t:SetAttribute("Apples", n + 1)
			HouseLogic.updateTree(t)
		end
	end
end

local function pickApple(match, plr, tree)
	local n = tree:GetAttribute("Apples") or 0
	if n <= 0 or not tree:GetAttribute("Planted") then return end
	local carried = plr:GetAttribute("Apples") or 0
	if carried >= Config.MaxApplesCarried then
		Net.event("Toast"):FireClient(plr, "Руки заняты! Продай яблоки в гараже.")
		return
	end
	tree:SetAttribute("Apples", n - 1)
	HouseLogic.updateTree(tree)
	local add = (plr:GetAttribute("Class") == "farmer") and 2 or 1
	plr:SetAttribute("Apples", math.min(Config.MaxApplesCarried, carried + add))
	match:fxTo(plr, "apple", add)
	local trunk = tree:FindFirstChild("Plot") or tree.PrimaryPart
	if trunk then Sound.play("ApplePick", trunk) end
end

---------------------------------------------------------------- свет и щиток
function HouseLogic.updateLights(match)
	local on = match.power ~= false
	for _, lamp in ipairs(match.house.lights or {}) do
		if lamp.Parent then
			for _, l in ipairs(lamp:GetDescendants()) do
				if l:IsA("Light") then l.Enabled = on end
			end
			if lamp:IsA("Light") then lamp.Enabled = on end
			if lamp:IsA("BasePart") and lamp:GetAttribute("Glow") then
				lamp.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
		end
	end
	local fuse = match.house.fuse
	local lampPart = fuse and fuse:FindFirstChild("Lamp", true)
	if lampPart and lampPart:IsA("BasePart") then
		lampPart.Color = on and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 50, 40)
	end
	local p = fuse and fuse:FindFirstChild("Prompt", true)
	if p then p.ActionText = on and "Выключить свет" or "Включить свет" end
end

function HouseLogic.setPower(match, on, quiet)
	if match.power == on and not quiet then return end
	match.power = on
	if match.folder then match.folder:SetAttribute("Power", on) end
	HouseLogic.updateLights(match)
	if not quiet then
		match:fx("power", on)
		local fuse = match.house.fuse
		local at = fuse and (fuse.PrimaryPart or fuse:FindFirstChildWhichIsA("BasePart", true))
		Sound.play(on and "PowerUp" or "PowerDown", at, { Volume = 1 })
	end
end

---------------------------------------------------------------- подключение к матчу
function HouseLogic.attach(match)
	local house = match.house
	match.conns = match.conns or {}
	for _, door in ipairs(house.doors or {}) do
		local ok, err = pcall(initDoor, match, door)
		if not ok then warnOnce("initDoor", err) end
	end
	for _, w in ipairs(house.windows or {}) do
		w:SetAttribute("Broken", false)
		local g = w:FindFirstChild("Glass")
		if g and g:GetAttribute("T0") == nil then g:SetAttribute("T0", g.Transparency) end
	end
	for _, hide in ipairs(house.hides or {}) do
		hide:SetAttribute("Occupant", 0)
		local p = hide:FindFirstChild("Prompt", true)
		if p then
			connect(match, p.Triggered, function(plr)
				if not inMatch(match, plr) then return end
				if hideOwner[plr] then return end
				if HouseLogic.occupant(hide) then
					Net.event("Toast"):FireClient(plr, "Здесь уже кто-то прячется")
					return
				end
				HouseLogic.hide(match, plr, hide)
			end)
		end
	end
	for _, tree in ipairs(house.trees or {}) do
		local p = tree:FindFirstChild("Prompt", true)
		if p then
			connect(match, p.Triggered, function(plr)
				if inMatch(match, plr) then pickApple(match, plr, tree) end
			end)
		end
		HouseLogic.updateTree(tree)
	end
	local fuse = house.fuse
	local fp = fuse and fuse:FindFirstChild("Prompt", true)
	if fp then
		fp.HoldDuration = 0.6
		connect(match, fp.Triggered, function(plr)
			if not inMatch(match, plr) then return end
			if match.power then
				HouseLogic.setPower(match, false)
				return
			end
			local wait = (plr:GetAttribute("Class") == "electric") and 0 or 1.2
			Sound.play("Fuse", fp.Parent)
			task.delay(wait, function()
				if match.phase ~= "end" then HouseLogic.setPower(match, true) end
			end)
		end)
	end
	HouseLogic.setPower(match, true, true)
end

-- рассвет: двери и окна как новые, свет включён
function HouseLogic.repairAll(match)
	for _, door in ipairs(match.house.doors or {}) do
		local ok, err = pcall(repairDoor, match, door)
		if not ok then warnOnce("repairDoor", err) end
	end
	for _, w in ipairs(match.house.windows or {}) do repairWindow(w) end
	HouseLogic.setPower(match, true, true)
end

function HouseLogic.unhideAll(match)
	for plr, h in pairs(hideOwner) do
		if h.match == match then HouseLogic.unhide(plr) end
	end
end

function HouseLogic.detach(match)
	HouseLogic.unhideAll(match)
	for _, c in ipairs(match.conns or {}) do c:Disconnect() end
	match.conns = {}
end

function HouseLogic.init(c)
	ctx = c
	Config = c.Config
	Sound = c.Sound
	Net = c.Net
	Players.PlayerRemoving:Connect(function(plr)
		local h = hideOwner[plr]
		if h then
			hideOwner[plr] = nil
			if h.hide.Parent then h.hide:SetAttribute("Occupant", 0) end
		end
	end)
end

return HouseLogic
