-- Участки для строительства: кто где строит, табличка с именем, место появления.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local MapLayout = require(Shared.MapLayout)

local Plots = {}

export type Plot = {
	index: number,
	model: Model,
	cf: CFrame,
	color: Color3,
	colorName: string,
	blocks: Folder,
	effects: Folder,
	base: BasePart,
	spawn: SpawnLocation,
	sign: BasePart?,
	towers: { Vector3 },
	layout: any,
	owner: Player?,
	-- состояние режимов (заполняют Siege и Launch)
	siege: any,
	launched: boolean,
	undo: { any },
}

Plots.list = {} :: { Plot }
local byOwner: { [Player]: Plot } = {}

function Plots.init()
	local folder = workspace:WaitForChild("Plots")
	for _, entry in MapLayout.Plots do
		local model = folder:WaitForChild("Plot" .. entry.index) :: Model
		local colorInfo = Config.PlotColors[entry.index]
		local plot: Plot = {
			index = entry.index,
			model = model,
			cf = entry.cf,
			color = colorInfo.color,
			colorName = colorInfo.name,
			blocks = model:WaitForChild("Blocks") :: Folder,
			effects = model:WaitForChild("Effects") :: Folder,
			base = model:WaitForChild("Base") :: BasePart,
			spawn = model:WaitForChild("Spawn") :: SpawnLocation,
			sign = model:FindFirstChild("Sign") :: BasePart?,
			towers = entry.towers,
			layout = entry,
			owner = nil,
			siege = nil,
			launched = false,
			undo = {},
		}
		model:SetAttribute("PlotIndex", entry.index)
		model:SetAttribute("Owner", 0)
		Plots.list[entry.index] = plot
		Plots.setSign(plot, nil)
	end
end

function Plots.setSign(plot: Plot, owner: Player?)
	local sign = plot.sign
	if not sign then
		return
	end
	local gui = sign:FindFirstChild("SurfaceGui")
	local label = gui and gui:FindFirstChild("Owner") :: TextLabel?
	if label then
		label.Text = owner and owner.DisplayName or "Свободный участок"
	end
end

function Plots.assign(player: Player): Plot?
	if byOwner[player] then
		return byOwner[player]
	end
	for _, plot in Plots.list do
		if not plot.owner then
			plot.owner = player
			plot.undo = {}
			byOwner[player] = plot
			plot.model:SetAttribute("Owner", player.UserId)
			player:SetAttribute("Plot", plot.index)
			player.RespawnLocation = plot.spawn
			Plots.setSign(plot, player)
			return plot
		end
	end
	return nil
end

function Plots.release(player: Player)
	local plot = byOwner[player]
	if not plot then
		return
	end
	byOwner[player] = nil
	plot.owner = nil
	plot.undo = {}
	plot.model:SetAttribute("Owner", 0)
	Plots.setSign(plot, nil)
end

function Plots.of(player: Player): Plot?
	return byOwner[player]
end

-- Позиция внутри острова участка? (для урона и правил осады)
function Plots.isOnIsland(plot: Plot, pos: Vector3, radius: number?): boolean
	local l = plot.cf:PointToObjectSpace(pos)
	local r = radius or 82
	return l.X * l.X + l.Z * l.Z <= r * r and l.Y > -30 and l.Y < Config.PlotSize.Y + 60
end

-- Позиция внутри зоны строительства (с запасом margin)?
function Plots.isInBuildZone(plot: Plot, pos: Vector3, margin: number?): boolean
	local m = margin or 0
	local l = plot.cf:PointToObjectSpace(pos)
	local hx, hz = Config.PlotSize.X / 2 + m, Config.PlotSize.Z / 2 + m
	return math.abs(l.X) <= hx and math.abs(l.Z) <= hz and l.Y > -10 and l.Y < Config.PlotSize.Y + 40
end

function Plots.ownerCharacter(plot: Plot): (Model?, Humanoid?, BasePart?)
	local owner = plot.owner
	local char = owner and owner.Character
	if not char then
		return nil, nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hum and root and hum.Health > 0 then
		return char, hum, root
	end
	return nil, nil, nil
end

-- Все живые персонажи на острове участка
function Plots.charactersOnIsland(plot: Plot): { { char: Model, hum: Humanoid, root: BasePart, player: Player } }
	local out = {}
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if char and hum and root and hum.Health > 0 and Plots.isOnIsland(plot, root.Position) then
			table.insert(out, { char = char, hum = hum, root = root, player = player })
		end
	end
	return out
end

return Plots
