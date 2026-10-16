-- Строительство на клиенте: «призрак» блока под курсором, установка, удаление, покраска,
-- пипетка, повороты. Всё проверяется ещё раз на сервере.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local BlockFactory = require(Shared.BlockFactory)
local Grid = require(Shared.Grid)
local MapLayout = require(Shared.MapLayout)
local Net = require(Shared.Net)

local Client = script.Parent
local State = require(Client.State)
local SoundPlayer = require(Client.SoundPlayer)
local HUD = require(Client.UI.HUD)

local BuildController = {}

local player = Players.LocalPlayer
local ghost: Model? = nil
local ghostKey = ""
local ghostHighlight: Highlight
local hoverHighlight: Highlight
local ghostCF: CFrame? = nil
local ghostValid = false
local ghostCenter: Vector3? = nil
local hovered: BasePart? = nil
local holding = false
local lastHoldPlace = 0
local lastPlacedCenter: Vector3? = nil
local inFlight = 0
local touchPos: Vector2? = nil
local gridGui: SurfaceGui? = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local HINTS = {
	build = "ЛКМ — поставить (держи, чтобы ставить подряд)  •  R — повернуть  •  T — наклонить  •  Q — пипетка  •  Ctrl+Z — отмена",
	delete = "Кликай по блокам, чтобы удалить (можно держать)  •  Ctrl+Z — вернуть",
	paint = "Кликай по блокам, чтобы покрасить  •  цвет — в панели слева",
	pick = "Кликни по блоку — скопируешь материал, форму, размер, поворот и цвет",
}

local function myPlot(): (Model?, CFrame?)
	local idx = player:GetAttribute("Plot")
	if not idx then
		return nil, nil
	end
	local plots = workspace:FindFirstChild("Plots")
	local model = plots and plots:FindFirstChild("Plot" .. idx) :: Model?
	local layout = MapLayout.Plots[idx]
	return model, layout and layout.cf
end

local function canBuildNow(): boolean
	return not State.inSiege() and not State.launched and State.modal == nil
end

-- ПРИЗРАК ---------------------------------------------------------------------------
local function destroyGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	ghostKey = ""
	ghostCF = nil
end

local function ensureGhost()
	local spec = State.spec()
	local key = string.format("%d:%d:%d:%s:%d:%s", spec.mat, spec.shape, spec.item, tostring(spec.size), spec.rot, spec.color:ToHex())
	if ghost and key == ghostKey then
		return
	end
	local keepCF = ghostCF
	destroyGhost()
	ghostKey = key
	local m = Instance.new("Model")
	m.Name = "BuildGhost"
	local part = BlockFactory.build(spec, CFrame.identity * Grid.Rotations[spec.rot], { ghost = true })
	for _, p in BlockFactory.allParts(part) do
		p.Transparency = math.max(p.Transparency, 0) + (1 - p.Transparency) * 0.45
	end
	part.Parent = m
	m.PrimaryPart = part
	m.Parent = workspace
	ghostHighlight.Adornee = m
	ghost = m
	ghostCF = keepCF
end

local function setGhostValid(valid: boolean)
	ghostValid = valid
	ghostHighlight.OutlineColor = valid and Color3.fromRGB(90, 255, 140) or Color3.fromRGB(255, 70, 70)
	ghostHighlight.FillColor = valid and Color3.fromRGB(90, 255, 140) or Color3.fromRGB(255, 60, 60)
end

local function screenRay(): Ray?
	local cam = workspace.CurrentCamera
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		if not touchPos then
			return nil
		end
		return cam:ScreenPointToRay(touchPos.X, touchPos.Y)
	end
	local m = UserInputService:GetMouseLocation()
	return cam:ViewportPointToRay(m.X, m.Y)
end

local function castBuild(model: Model): RaycastResult?
	local ray = screenRay()
	if not ray then
		return nil
	end
	local base = model:FindFirstChild("Base")
	local blocks = model:FindFirstChild("Blocks")
	rayParams.FilterDescendantsInstances = { base :: Instance, blocks :: Instance }
	return workspace:Raycast(ray.Origin, ray.Direction * 600, rayParams)
end

local function blockFromHit(hit: RaycastResult?, model: Model): BasePart?
	if not hit then
		return nil
	end
	local inst = hit.Instance
	if inst:IsA("BasePart") and inst.Name == "Block" and inst.Parent == model:FindFirstChild("Blocks") then
		return inst
	end
	return nil
end

local function overlapsClient(model: Model, cf: CFrame, size: Vector3): boolean
	local blocks = model:FindFirstChild("Blocks")
	if not blocks then
		return false
	end
	overlap.FilterDescendantsInstances = { blocks }
	local hits = workspace:GetPartBoundsInBox(cf, size - Vector3.new(0.12, 0.12, 0.12), overlap)
	for _, h in hits do
		if h.Name == "Block" then
			return true
		end
	end
	return false
end

-- ДЕЙСТВИЯ --------------------------------------------------------------------------
local function invoke(name: string, okSound: string?, ...: any)
	if inFlight > 4 then
		return
	end
	inFlight += 1
	local args = { ... }
	task.spawn(function()
		local ok, msg = Net.func(name):InvokeServer(table.unpack(args))
		inFlight -= 1
		if ok then
			if okSound then
				SoundPlayer.play(okSound, { speed = 0.92 + math.random() * 0.16 })
			end
		elseif msg then
			HUD.toast(msg, "error")
		end
	end)
end

local function place()
	if not (ghost and ghostValid and ghostCenter) then
		return
	end
	local spec = State.spec()
	lastPlacedCenter = ghostCenter
	invoke("Place", "Place", {
		mat = spec.mat,
		shape = spec.shape,
		item = spec.item,
		pos = ghostCenter,
		size = spec.size,
		rot = spec.rot,
		color = spec.color,
	})
	-- маленький «пульс» призрака
	if ghost and ghost.PrimaryPart then
		local p = ghost.PrimaryPart
		ghostHighlight.FillTransparency = 0.35
		task.delay(0.08, function()
			ghostHighlight.FillTransparency = 0.82
		end)
		p.Transparency = p.Transparency
	end
end

local function pick(block: BasePart)
	local item = block:GetAttribute("Item") or 0
	local sel = State.sel
	if item > 0 then
		sel.kind = "item"
		sel.id = item
	else
		sel.kind = "mat"
		sel.id = block:GetAttribute("Mat") or 1
		sel.shape = block:GetAttribute("Shape") or 1
	end
	sel.size = block:GetAttribute("BlockSize") or block.Size
	sel.rot = block:GetAttribute("Rot") or 1
	sel.color = block:GetAttribute("BaseColor") or block.Color
	sel.customColor = true
	if not State.isUnlocked(sel.kind, sel.id) then
		HUD.toast("Этот блок ещё не куплен", "warning")
	end
	State.changed:Fire("sel", sel)
	BuildController.setTool("build")
	SoundPlayer.play("Click")
end

local function actOnHovered()
	local b = hovered
	if not b then
		return
	end
	if State.tool == "delete" then
		hovered = nil
		invoke("Delete", "Remove", b)
	elseif State.tool == "paint" then
		local c = State.sel.color
		if (b:GetAttribute("BaseColor") or b.Color) ~= c then
			invoke("Paint", "Paint", b, c)
		end
	elseif State.tool == "pick" then
		pick(b)
	end
end

-- СЕТКА НА УЧАСТКЕ ------------------------------------------------------------------
local function buildGrid(model: Model)
	if gridGui then
		gridGui:Destroy()
		gridGui = nil
	end
	local base = model:FindFirstChild("Base") :: BasePart?
	if not base then
		return
	end
	local g = Instance.new("SurfaceGui")
	g.Name = "BuildGrid"
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 16
	g.LightInfluence = 0.6
	g.Adornee = base
	local n = Config.PlotSize.X
	for i = 0, n, 2 do
		local major = i % 8 == 0
		for _, vertical in { true, false } do
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.BackgroundColor3 = major and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(40, 44, 52)
			f.BackgroundTransparency = major and 0.72 or 0.8
			local w = major and 3 or 2
			if vertical then
				f.Size = UDim2.new(0, w, 1, 0)
				f.Position = UDim2.new(i / n, -w / 2, 0, 0)
			else
				f.Size = UDim2.new(1, 0, 0, w)
				f.Position = UDim2.new(0, 0, i / n, -w / 2)
			end
			f.Parent = g
		end
	end
	g.Enabled = false
	g.Parent = player:WaitForChild("PlayerGui")
	gridGui = g
end

-- ИНСТРУМЕНТЫ ------------------------------------------------------------------------
function BuildController.setTool(tool: string?)
	if (State.inSiege() or State.launched) and tool ~= nil then
		HUD.toast(State.launched and "Сначала останови испытание" or "Во время осады строить нельзя", "warning")
		tool = nil
	end
	State.set("tool", tool)
	HUD.setTool(tool)
	HUD.setHint(tool and HINTS[tool] or "")
	if tool ~= "build" then
		destroyGhost()
	end
	hovered = nil
	hoverHighlight.Adornee = nil
end

local function update(dt: number)
	local model, plotCF = myPlot()
	local tool = State.tool
	if gridGui then
		gridGui.Enabled = tool == "build" and State.settings.ShowGrid == true and canBuildNow()
	end
	if not model or not plotCF or not tool or not canBuildNow() then
		destroyGhost()
		hoverHighlight.Adornee = nil
		hovered = nil
		return
	end
	local hit = castBuild(model)
	if tool == "build" then
		hoverHighlight.Adornee = nil
		if not hit then
			if ghost then
				ghost.Parent = nil
			end
			ghostCenter = nil
			return
		end
		ensureGhost()
		local g = ghost :: Model
		g.Parent = workspace
		local spec = State.spec()
		local center = Grid.placement(plotCF, hit.Position, hit.Normal, spec.size, spec.rot)
		local e = Grid.extents(spec.size, spec.rot)
		local cf = Grid.worldCFrame(plotCF, center, spec.rot)
		ghostCenter = center
		local valid = Grid.inBounds(center, e) and not overlapsClient(model, cf, spec.size)
		setGhostValid(valid)
		-- плавное движение призрака
		if not ghostCF or (ghostCF.Position - cf.Position).Magnitude > 30 then
			ghostCF = cf
		else
			ghostCF = (ghostCF :: CFrame):Lerp(cf, math.clamp(dt * 22, 0, 1))
		end
		g:PivotTo(ghostCF :: CFrame)
		-- зажатая кнопка: ставим новые блоки, когда курсор переходит в новую клетку
		if holding and ghostValid and os.clock() - lastHoldPlace > Config.HoldRepeat and center ~= lastPlacedCenter then
			lastHoldPlace = os.clock()
			place()
		end
	else
		local b = blockFromHit(hit, model)
		hovered = b
		hoverHighlight.Adornee = b
		if b then
			local colors = {
				delete = Color3.fromRGB(255, 70, 70),
				paint = State.sel.color,
				pick = Color3.fromRGB(255, 220, 90),
			}
			hoverHighlight.OutlineColor = colors[tool] or Color3.new(1, 1, 1)
			hoverHighlight.FillColor = colors[tool] or Color3.new(1, 1, 1)
		end
		if holding and tool ~= "pick" and os.clock() - lastHoldPlace > 0.12 then
			lastHoldPlace = os.clock()
			actOnHovered()
		end
	end
end

function BuildController.init()
	-- подсветки лежат в пустой папке: без Adornee они ничего не подсвечивают
	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "BuildFx"
	fxFolder.Parent = workspace
	ghostHighlight = Instance.new("Highlight")
	ghostHighlight.FillTransparency = 0.82
	ghostHighlight.OutlineTransparency = 0
	ghostHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	ghostHighlight.Parent = fxFolder
	hoverHighlight = Instance.new("Highlight")
	hoverHighlight.FillTransparency = 0.6
	hoverHighlight.OutlineTransparency = 0
	hoverHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hoverHighlight.Parent = fxFolder
	setGhostValid(true)

	local function onPlot()
		local model = myPlot()
		if model then
			buildGrid(model)
		end
	end
	player:GetAttributeChangedSignal("Plot"):Connect(onPlot)
	onPlot()

	HUD.onTool:Connect(function(tool)
		BuildController.setTool(tool)
	end)
	HUD.onUndo:Connect(function()
		invoke("Undo", "Remove")
	end)
	State.changed:Connect(function(key)
		if key == "siege" or key == "launched" then
			if State.inSiege() or State.launched then
				BuildController.setTool(nil)
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local kc = input.KeyCode
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
			if kc == Enum.KeyCode.Z and ctrl then
				invoke("Undo", "Remove")
			elseif kc == Enum.KeyCode.One then
				BuildController.setTool(if State.tool == "build" then nil else "build")
			elseif kc == Enum.KeyCode.Two then
				BuildController.setTool(if State.tool == "delete" then nil else "delete")
			elseif kc == Enum.KeyCode.Three then
				BuildController.setTool(if State.tool == "paint" then nil else "paint")
			elseif kc == Enum.KeyCode.Four then
				BuildController.setTool(if State.tool == "pick" then nil else "pick")
			elseif kc == Enum.KeyCode.R and State.tool == "build" then
				local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				State.sel.rot = Grid.rotate(State.sel.rot, shift and "Z" or "Y")
				State.changed:Fire("sel", State.sel)
				SoundPlayer.play("Hover")
			elseif kc == Enum.KeyCode.T and State.tool == "build" then
				State.sel.rot = Grid.rotate(State.sel.rot, "X")
				State.changed:Fire("sel", State.sel)
				SoundPlayer.play("Hover")
			elseif kc == Enum.KeyCode.Q and State.tool == "build" then
				local model = myPlot()
				local b = model and blockFromHit(castBuild(model), model)
				if b then
					pick(b)
				end
			elseif kc == Enum.KeyCode.Escape and not State.modal then
				BuildController.setTool(nil)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			if not State.tool or not canBuildNow() then
				return
			end
			holding = true
			lastHoldPlace = os.clock()
			if State.tool == "build" then
				lastPlacedCenter = nil
				place()
			else
				actOnHovered()
			end
		elseif input.UserInputType == Enum.UserInputType.Touch then
			touchPos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = false
		end
	end)
	-- на телефоне: короткое касание = клик
	UserInputService.TouchTap:Connect(function(positions, processed)
		if processed or not State.tool or not canBuildNow() then
			return
		end
		local p = positions[1]
		touchPos = Vector2.new(p.X, p.Y)
		task.defer(function()
			update(1)
			if State.tool == "build" then
				place()
			else
				actOnHovered()
			end
		end)
	end)

	RunService.RenderStepped:Connect(update)
end

return BuildController
