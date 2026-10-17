-- Особые блоки: двери, аптечки, энергокристаллы, генераторы щита, турели ПВО и охранники.
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Blocks = require(Shared.Blocks)
local BlockFactory = require(Shared.BlockFactory)
local Net = require(Shared.Net)

local Plots = require(script.Parent.Plots)

local Specials = {}

type Plot = Plots.Plot

export type Shield = {
	block: BasePart,
	center: Vector3,
	radius: number,
	hp: number,
	maxHp: number,
	active: boolean,
	downUntil: number,
	dome: BasePart?,
	plot: Plot,
}

local shields: { [number]: { Shield } } = {}
local aaReady: { [BasePart]: number } = {}
local guardReady: { [BasePart]: number } = {}

local ITEM_DOOR = Blocks.ItemByKey.Door.id
local ITEM_MEDKIT = Blocks.ItemByKey.Medkit.id
local ITEM_SHIELD = Blocks.ItemByKey.Shield.id
local ITEM_AA = Blocks.ItemByKey.AATurret.id
local ITEM_GUARD = Blocks.ItemByKey.Guard.id
local MAT_CRYSTAL = Blocks.MaterialByKey.Crystal.id

-- ДВЕРИ ---------------------------------------------------------------------------
local DOOR_SWING = math.rad(95)
local DOOR_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Полотно поворачивается на петлях (Weld "DoorHinge": C0 — ось петель) — от того, кто открыл.
-- Открытая дверь не мешает ходить; закрытая снова твёрдая, когда полотно встанет на место.
local function toggleDoor(door: BasePart, player: Player?)
	local open = not door:GetAttribute("Open")
	door:SetAttribute("Open", open)
	local prompt = door:FindFirstChild("DoorPrompt") :: ProximityPrompt?
	if prompt then
		prompt.ActionText = open and "Закрыть" or "Открыть"
	end
	local leaf = door:FindFirstChild("DoorLeaf") :: BasePart?
	if not leaf then
		return
	end
	local hinge = leaf:FindFirstChild("DoorHinge") :: Weld?
	if not hinge then
		return
	end
	local goal = CFrame.new(hinge.C0.Position)
	if open then
		leaf.CanCollide = false
		local sign = 1
		local char = player and player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and door.CFrame:PointToObjectSpace(root.Position).Z > 0 then
			sign = -1
		end
		goal *= CFrame.Angles(0, sign * DOOR_SWING, 0)
	end
	-- новый твин сам отменяет предыдущий (то же свойство C0)
	local tween = TweenService:Create(hinge, DOOR_TWEEN, { C0 = goal })
	tween.Completed:Connect(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed and not door:GetAttribute("Open") and leaf.Parent then
			leaf.CanCollide = true
		end
	end)
	tween:Play()
end

-- ЩИТЫ ----------------------------------------------------------------------------
local function makeDome(s: Shield): BasePart
	local dome = Instance.new("Part")
	dome.Name = "ShieldDome"
	dome.Shape = Enum.PartType.Ball
	dome.Size = Vector3.one * s.radius * 2
	dome.CFrame = CFrame.new(s.center)
	dome.Anchored = true
	dome.CanCollide = false
	dome.CanQuery = false
	dome.CanTouch = false
	dome.CastShadow = false
	dome.Material = Enum.Material.ForceField
	dome.Color = Color3.fromRGB(80, 190, 255)
	dome.Transparency = 0
	dome.Parent = s.plot.effects
	return dome
end

-- Включить щиты на время осады
function Specials.startShields(plot: Plot)
	Specials.stopShields(plot)
	local list = {}
	for _, b in plot.blocks:GetChildren() do
		if b:IsA("BasePart") and b:GetAttribute("Item") == ITEM_SHIELD then
			local s: Shield = {
				block = b,
				center = b.Position,
				radius = Blocks.ShieldRadius,
				hp = Blocks.ShieldHp,
				maxHp = Blocks.ShieldHp,
				active = true,
				downUntil = 0,
				dome = nil,
				plot = plot,
			}
			s.dome = makeDome(s)
			table.insert(list, s)
		end
	end
	shields[plot.index] = list
end

function Specials.stopShields(plot: Plot)
	local list = shields[plot.index]
	if list then
		for _, s in list do
			if s.dome then
				s.dome:Destroy()
			end
		end
	end
	shields[plot.index] = nil
end

function Specials.activeShields(plot: Plot): { Shield }
	local out = {}
	local list = shields[plot.index]
	if list then
		for _, s in list do
			if s.active and s.block.Parent == plot.blocks then
				table.insert(out, s)
			end
		end
	end
	return out
end

local function setShieldActive(s: Shield, active: boolean)
	s.active = active
	if s.dome then
		TweenService:Create(s.dome, TweenInfo.new(0.4), { Transparency = active and 0 or 1 }):Play()
	end
	Net.event("ShieldState"):FireAllClients({ p = s.center, r = s.radius, up = active })
end

-- Щит принял удар; возвращает true, если выдержал
function Specials.hitShield(s: Shield, amount: number, at: Vector3): boolean
	if not s.active then
		return false
	end
	s.hp -= amount
	Net.event("ShieldState"):FireAllClients({ p = s.center, r = s.radius, hit = at, hp = math.max(0, s.hp) / s.maxHp })
	if s.hp <= 0 then
		s.hp = 0
		s.downUntil = os.clock() + Blocks.ShieldRecharge
		setShieldActive(s, false)
		return false
	end
	return true
end

-- Какой активный щит накрывает точку?
function Specials.shieldCovering(plot: Plot, pos: Vector3): Shield?
	for _, s in Specials.activeShields(plot) do
		if (pos - s.center).Magnitude <= s.radius then
			return s
		end
	end
	return nil
end

-- Списки турелей и охранников участка: снаряды спрашивают их каждый шаг, поэтому список
-- собирается заново, только когда блоки участка менялись (ChildAdded/ChildRemoved в Specials.init).
-- Список общий: его только читают, не меняют.
local itemLists: { [number]: { [number]: { BasePart } } } = {}

local function blocksWithItem(plot: Plot, item: number): { BasePart }
	local lists = itemLists[plot.index]
	if not lists then
		lists = {}
		itemLists[plot.index] = lists
	end
	local list = lists[item]
	if not list then
		local out = {}
		for _, b in plot.blocks:GetChildren() do
			if b:IsA("BasePart") and b:GetAttribute("Item") == item then
				table.insert(out, b)
			end
		end
		lists[item] = out
		list = out
	end
	return list
end

-- ПВО -----------------------------------------------------------------------------
function Specials.aaTurrets(plot: Plot): { BasePart }
	return blocksWithItem(plot, ITEM_AA)
end

function Specials.aaReady(turret: BasePart): boolean
	return os.clock() >= (aaReady[turret] or 0)
end

function Specials.aaFired(turret: BasePart)
	aaReady[turret] = os.clock() + Blocks.AACooldown
end

-- ОХРАННИКИ -----------------------------------------------------------------------
-- Стреляют по ракетам рядом с собой (сам выстрел и шанс сбить — в Projectiles)
function Specials.guards(plot: Plot): { BasePart }
	return blocksWithItem(plot, ITEM_GUARD)
end

function Specials.guardReady(guard: BasePart): boolean
	return os.clock() >= (guardReady[guard] or 0)
end

function Specials.guardFired(guard: BasePart)
	guardReady[guard] = os.clock() + Blocks.GuardCooldown
end

-- ЦИКЛЫ ---------------------------------------------------------------------------
function Specials.init()
	for _, plot in Plots.list do
		plot.blocks.ChildAdded:Connect(function()
			itemLists[plot.index] = nil
		end)
		plot.blocks.ChildRemoved:Connect(function(b: Instance)
			itemLists[plot.index] = nil
			if b:IsA("BasePart") then
				aaReady[b] = nil
				guardReady[b] = nil
			end
		end)
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if prompt.Name == "DoorPrompt" then
			local door = prompt.Parent
			if door and door:IsA("BasePart") and door:GetAttribute("Item") == ITEM_DOOR then
				toggleDoor(door, player)
			end
		end
	end)

	-- аптечки: лечат каждые полсекунды
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, plot in Plots.list do
				local medkits = {}
				for _, b in plot.blocks:GetChildren() do
					if b:IsA("BasePart") and b:GetAttribute("Item") == ITEM_MEDKIT then
						table.insert(medkits, b)
					end
				end
				if #medkits > 0 then
					for _, c in Plots.charactersOnIsland(plot) do
						for _, m in medkits do
							if (c.root.Position - m.Position).Magnitude <= Blocks.MedkitRange then
								c.hum.Health = math.min(c.hum.MaxHealth, c.hum.Health + 3)
								break
							end
						end
					end
				end
			end
		end
	end)

	-- энергокристаллы восстанавливаются, щиты перезаряжаются
	task.spawn(function()
		local regen = Blocks.MaterialByKey.Crystal.regen
		while true do
			task.wait(1)
			for _, plot in Plots.list do
				if plot.siege then
					for _, b in plot.blocks:GetChildren() do
						if b:IsA("BasePart") and b:GetAttribute("Mat") == MAT_CRYSTAL and (b:GetAttribute("Item") or 0) == 0 then
							local hp, maxHp = b:GetAttribute("Hp") or 0, b:GetAttribute("MaxHp") or 1
							if hp < maxHp then
								hp = math.min(maxHp, hp + maxHp * regen)
								b:SetAttribute("Hp", hp)
								local base = b:GetAttribute("BaseColor") or b.Color
								BlockFactory.applyColor(b, base:Lerp(Color3.fromRGB(28, 22, 18), (1 - hp / maxHp) * 0.7))
							end
						end
					end
				end
				local list = shields[plot.index]
				if list then
					for _, s in list do
						if s.block.Parent ~= plot.blocks then
							if s.dome then
								s.dome:Destroy()
								s.dome = nil
							end
							s.active = false
						elseif not s.active and s.downUntil > 0 and os.clock() >= s.downUntil then
							s.hp = s.maxHp
							s.downUntil = 0
							setShieldActive(s, true)
						end
					end
				end
			end
		end
	end)
end

return Specials
