-- Урон: взрывы, пули, лазер. Прочность блоков, обломки, укрытия игроков.
--
-- Главная идея: стены защищают. Каждый блок между взрывом и игроком гасит часть урона —
-- тем больше, чем прочнее материал (поле blast/nuke) и чем толще блок.
local PhysicsService = game:GetService("PhysicsService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Blocks = require(Shared.Blocks)
local BlockFactory = require(Shared.BlockFactory)
local Net = require(Shared.Net)

local Plots = require(script.Parent.Plots)
local Specials = require(script.Parent.Specials)

local Damage = {}

type Plot = Plots.Plot

export type ExplosionOpts = {
	radius: number,
	blockDamage: number,
	playerDamage: number,
	kind: string, -- "explosion" | "nuke"
	mul: number?,
}

local ITEM_TNT = Blocks.ItemByKey.TNT.id

local debrisFolder: Folder
local debrisCount = 0
local rng = Random.new()

local blockParams = RaycastParams.new()
blockParams.FilterType = Enum.RaycastFilterType.Include

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

function Damage.init()
	local existing = workspace:FindFirstChild("Debris")
	if existing then
		debrisFolder = existing :: Folder
	else
		local f = Instance.new("Folder")
		f.Name = "Debris"
		f.Parent = workspace
		debrisFolder = f
	end
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Debris")
		PhysicsService:RegisterCollisionGroup("Players")
	end)
	PhysicsService:CollisionGroupSetCollidable("Debris", "Debris", false)
	PhysicsService:CollisionGroupSetCollidable("Debris", "Players", false)
end

function Damage.debrisFolder(): Folder
	return debrisFolder
end

function Damage.defOf(block: BasePart)
	local item = block:GetAttribute("Item") or 0
	if item > 0 then
		return Blocks.ItemById[item]
	end
	return Blocks.MaterialById[block:GetAttribute("Mat") or 1] or Blocks.MaterialById[1]
end

local function plotOf(block: Instance): Plot?
	local folder = block.Parent
	local model = folder and folder.Parent
	local idx = model and model:GetAttribute("PlotIndex")
	return idx and Plots.list[idx] or nil
end

-- Насколько блок «толстый» вдоль направления dir (стады)
local function thickness(block: BasePart, dir: Vector3): number
	local cf = block.CFrame
	local s = block.Size
	return math.clamp(
		math.abs(dir:Dot(cf.RightVector)) * s.X + math.abs(dir:Dot(cf.UpVector)) * s.Y + math.abs(dir:Dot(cf.LookVector)) * s.Z,
		0.5,
		24
	)
end

local function resistOf(def, kind: string): number
	if kind == "nuke" then
		return def.nuke or 0.3
	end
	return def.blast or 0.3
end

-- Какая доля урона дойдёт от точки from до точки to сквозь блоки участка (1 = вся, 0 = ничего)
function Damage.cover(plot: Plot, from: Vector3, to: Vector3, kind: string): number
	blockParams.FilterDescendantsInstances = { plot.blocks }
	local factor = 1
	local origin = from
	for _ = 1, 8 do
		local delta = to - origin
		local dist = delta.Magnitude
		if dist < 0.1 then
			break
		end
		local unit = delta / dist
		local result = workspace:Raycast(origin, delta, blockParams)
		if not result then
			break
		end
		local block = result.Instance
		if block:IsA("BasePart") and block.Name == "Block" then
			local def = Damage.defOf(block)
			local layer = (1 - resistOf(def, kind)) ^ (thickness(block, unit) / 2)
			factor *= layer
			if factor < 0.01 then
				return 0
			end
		end
		origin = result.Position + unit * 0.05
	end
	return factor
end

local function falloff(x: number, kind: string): number
	if x >= 1 then
		return 0
	end
	if kind == "nuke" then
		return 1 - 0.7 * x * x
	end
	return (1 - x) ^ 0.75
end

local function charColor(block: BasePart)
	local hp, maxHp = tonumber(block:GetAttribute("Hp")) or 1, tonumber(block:GetAttribute("MaxHp")) or 1
	local base = block:GetAttribute("BaseColor") or block.Color
	block.Color = base:Lerp(Config.CharredColor, math.clamp(1 - hp / maxHp, 0, 1) * 0.75)
end

local function makeDebris(block: BasePart, from: Vector3?, kind: string)
	debrisCount += 1
	for _, d in block:GetDescendants() do
		if d:IsA("ProximityPrompt") or d:IsA("Weld") and d.Name == "SeatWeld" then
			d:Destroy()
		end
	end
	local parts = BlockFactory.allParts(block)
	for _, p in parts do
		p.CanQuery = false
		p.CanTouch = false
		p.CollisionGroup = "Debris"
	end
	block.Parent = debrisFolder
	block.Anchored = false
	local dir = from and (block.Position - from) or Vector3.yAxis
	if dir.Magnitude < 0.05 then
		dir = Vector3.yAxis
	end
	dir = dir.Unit
	local speed = (kind == "nuke" and 230) or (kind == "bullet" and 10) or (kind == "laser" and 6) or 75
	speed *= rng:NextNumber(0.6, 1.2)
	block.AssemblyLinearVelocity = dir * speed + Vector3.new(0, speed * 0.35, 0)
	block.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
	task.delay(Config.DebrisLifetime - 1.2, function()
		for _, p in parts do
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(1.1), { Transparency = 1 }):Play()
			end
		end
	end)
	task.delay(Config.DebrisLifetime, function()
		debrisCount -= 1
		block:Destroy()
	end)
end

-- Блок разрушен
function Damage.destroyBlock(block: BasePart, from: Vector3?, kind: string)
	local plot = plotOf(block)
	local pos = block.Position
	local isTnt = block:GetAttribute("Item") == ITEM_TNT
	if plot and plot.siege then
		plot.siege.blocksLost += 1
	end
	if debrisCount < Config.DebrisLimit then
		makeDebris(block, from, kind)
	else
		block:Destroy()
	end
	if isTnt and plot then
		task.delay(0.12, function()
			Net.event("Detonate"):FireAllClients({ w = "TNT", p = pos })
			Damage.explode(plot, pos, { radius = 12, blockDamage = 600, playerDamage = 70, kind = "explosion" })
		end)
	end
end

-- Нанести урон блоку. Возвращает true, если блок разрушен.
function Damage.damageBlock(block: BasePart, amount: number, kind: string, from: Vector3?): boolean
	if not block.Parent or block.Name ~= "Block" then
		return false
	end
	local def = Damage.defOf(block)
	if kind == "bullet" then
		amount *= def.bulletMul or 1
	elseif kind == "laser" then
		amount *= def.laserMul or 1
	else
		amount *= def.explMul or 1
	end
	local hp = (tonumber(block:GetAttribute("Hp")) or 1) - amount
	if hp <= 0 then
		Damage.destroyBlock(block, from, kind)
		return true
	end
	block:SetAttribute("Hp", hp)
	charColor(block)
	return false
end

-- Персонаж по детали (если деталь — часть игрока)
function Damage.humanoidOf(inst: Instance): Humanoid?
	local model = inst:FindFirstAncestorOfClass("Model")
	while model do
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			return hum
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- Взрыв в точке pos
function Damage.explode(plot: Plot, pos: Vector3, o: ExplosionOpts)
	local R = o.radius
	local kind = o.kind
	local mul = o.mul or 1

	-- 1. Щиты принимают часть удара на себя
	local protecting = {}
	for _, s in Specials.activeShields(plot) do
		local d = (pos - s.center).Magnitude
		if d > s.radius - 0.5 and d < s.radius + R then
			local share = o.blockDamage * mul * 0.35 * (1 - math.clamp((d - s.radius) / R, 0, 1))
			if Specials.hitShield(s, share, pos) then
				table.insert(protecting, s)
			end
		end
	end
	local function shielded(p: Vector3): boolean
		for _, s in protecting do
			if (p - s.center).Magnitude <= s.radius then
				return true
			end
		end
		return false
	end

	-- 2. Игроки (считаем до разрушения стен — стены успевают закрыть)
	for _, c in Plots.charactersOnIsland(plot) do
		local d = (c.root.Position - pos).Magnitude
		if d < R then
			local head = c.char:FindFirstChild("Head") :: BasePart?
			local cover = Damage.cover(plot, pos, c.root.Position, kind)
			if head then
				cover = math.max(cover, Damage.cover(plot, pos, head.Position, kind))
			end
			local dmg = o.playerDamage * mul * falloff(d / R, kind) * cover
			if shielded(c.root.Position) then
				dmg *= 0.1
			end
			if dmg >= 0.5 then
				c.hum:TakeDamage(dmg)
			end
		end
	end

	-- 3. Блоки
	overlap.FilterDescendantsInstances = { plot.blocks }
	blockParams.FilterDescendantsInstances = { plot.blocks }
	local parts = workspace:GetPartBoundsInRadius(pos, R, overlap)
	local broken = {}
	for _, b in parts do
		if b.Name == "Block" and b.Parent == plot.blocks then
			local half = (b.Size.X + b.Size.Y + b.Size.Z) / 6
			local d = math.max(0, (b.Position - pos).Magnitude - half)
			local f = falloff(d / R, kind)
			if f > 0 then
				local occl = 1
				local toBlock = b.Position - pos
				if toBlock.Magnitude > half + 0.5 then
					local hit = workspace:Raycast(pos, toBlock, blockParams)
					if hit and hit.Instance ~= b and hit.Instance.Name == "Block" then
						occl = 1 - resistOf(Damage.defOf(hit.Instance :: BasePart), kind) * 0.9
					end
				end
				local dmg = o.blockDamage * mul * f * occl
				if shielded(b.Position) then
					dmg *= 0.1
				end
				local bp, bc = b.Position, b.Color
				if Damage.damageBlock(b, dmg, kind, pos) and #broken < 24 then
					table.insert(broken, { bp, bc })
				end
			end
		end
	end
	if #broken > 0 then
		Net.event("BlocksBroken"):FireAllClients(broken, kind)
	end
end

-- Попадание пули
function Damage.bullet(plot: Plot, inst: Instance, pos: Vector3, blockDamage: number, playerDamage: number)
	local hum = Damage.humanoidOf(inst)
	if hum then
		local root = hum.RootPart
		if root and Plots.isOnIsland(plot, root.Position) then
			hum:TakeDamage(playerDamage)
		end
		return
	end
	if inst:IsA("BasePart") and inst.Name == "Block" and inst.Parent == plot.blocks then
		Damage.damageBlock(inst, blockDamage, "bullet", pos)
	end
end

local laserParams = RaycastParams.new()
laserParams.FilterType = Enum.RaycastFilterType.Exclude

function Damage.setExclude(list: { Instance })
	laserParams.FilterDescendantsInstances = list
end

-- Один «тик» орбитального лазера в точке (x, z). Возвращает высоту, где луч упёрся.
function Damage.laserTick(plot: Plot, x: number, z: number, beamRadius: number, blockDps: number, playerDps: number, dt: number, mul: number): number
	local topY = plot.cf.Position.Y + Config.PlotSize.Y + 200
	local result = workspace:Raycast(Vector3.new(x, topY, z), Vector3.new(0, -topY - 60, 0), laserParams)
	local hitY = result and result.Position.Y or 0
	-- купол щита
	for _, s in Specials.activeShields(plot) do
		local dx, dz = x - s.center.X, z - s.center.Z
		local h2 = dx * dx + dz * dz
		if h2 < s.radius * s.radius then
			local domeY = s.center.Y + math.sqrt(s.radius * s.radius - h2)
			if domeY > hitY then
				Specials.hitShield(s, blockDps * dt * 0.5 * mul, Vector3.new(x, domeY, z))
				if s.active then
					return domeY
				end
			end
		end
	end
	if result then
		local hum = Damage.humanoidOf(result.Instance)
		if hum then
			hum:TakeDamage(playerDps * dt * mul)
		end
		local hitPos = result.Position
		overlap.FilterDescendantsInstances = { plot.blocks }
		local parts = workspace:GetPartBoundsInRadius(hitPos, beamRadius, overlap)
		for _, b in parts do
			if b.Name == "Block" and b.Parent == plot.blocks then
				local top = b.Position.Y + b.Size.Magnitude * 0.3
				if top >= hitY - 2.5 then
					local hd = Vector2.new(b.Position.X - x, b.Position.Z - z).Magnitude
					local f = 1 - math.clamp(hd / (beamRadius + 2), 0, 0.7)
					Damage.damageBlock(b, blockDps * dt * mul * f, "laser", hitPos + Vector3.new(0, 4, 0))
				end
			end
		end
	end
	-- игроки рядом с пятном луча (не под крышей)
	for _, c in Plots.charactersOnIsland(plot) do
		local p = c.root.Position
		local hd = Vector2.new(p.X - x, p.Z - z).Magnitude
		if hd < beamRadius * 0.9 and p.Y > hitY - 3.5 then
			c.hum:TakeDamage(playerDps * dt * mul * 0.6)
		end
	end
	return hitY
end

return Damage
