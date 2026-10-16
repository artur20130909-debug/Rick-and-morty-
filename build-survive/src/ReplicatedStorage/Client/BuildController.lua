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
local ghostAxis = "Y" -- ось нормали поверхности под призраком (в координатах участка)
local hovered: BasePart? = nil
local inFlight = 0
local touchPos: Vector2? = nil
local gridGui: SurfaceGui? = nil

-- зажатая кнопка мыши (протяжка)
local holding = false
local pressAt = 0
local lastHoldPlace = 0
local dragAxis: string? = nil -- слой протяжки: ось нормали первого попадания…
local dragLayer = 0 -- …и координата центра первого блока по этой оси
local dragPlaced: { [string]: boolean } = {} -- клетки, поставленные за эту протяжку
local dragActed: { [BasePart]: boolean } = {} -- блоки, удалённые/покрашенные за эту протяжку

-- защита от дребезга и двойных срабатываний
local CLICK_DEBOUNCE = 0.25 -- ту же клетку/блок повторно — не раньше
local ACT_REPEAT = 0.15 -- удаление/покраска при зажатии: не чаще
local TOUCH_GUARD = 0.5 -- касание и «клик мыши» от того же касания считаем одним действием
local lastPlacedKey = ""
local lastPlacedAt = 0
local lastActBlock: BasePart? = nil
local lastActAt = 0
local lastTouchAt = -1
local lastMouseAt = -1

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local HINTS = {
	build = "ЛКМ — поставить  •  держи и веди — ставить рядом  •  R — повернуть  •  T — наклонить  •  Q — пипетка  •  Ctrl+Z — отмена",
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

-- ось с наибольшей компонентой (как в Grid.placement)
local function normalAxis(v: Vector3): string
	local ax, ay, az = math.abs(v.X), math.abs(v.Y), math.abs(v.Z)
	if ax >= ay and ax >= az then
		return "X"
	elseif ay >= az then
		return "Y"
	end
	return "Z"
end

local function onAxis(v: Vector3, axis: string): number
	if axis == "X" then
		return v.X
	elseif axis == "Y" then
		return v.Y
	end
	return v.Z
end

-- ключ клетки: центры блоков кратны 0.5 стада
local function cellKey(c: Vector3): string
	return string.format("%d,%d,%d", math.round(c.X * 2), math.round(c.Y * 2), math.round(c.Z * 2))
end

-- ПРИЗРАК ---------------------------------------------------------------------------
local function destroyGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	ghostKey = ""
	ghostCF = nil
	ghostCenter = nil
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

-- look — какой цвет показать (по умолчанию как valid)
local function setGhostValid(valid: boolean, look: boolean?)
	ghostValid = valid
	local ok = if look == nil then valid else look
	ghostHighlight.OutlineColor = ok and Color3.fromRGB(90, 255, 140) or Color3.fromRGB(255, 70, 70)
	ghostHighlight.FillColor = ok and Color3.fromRGB(90, 255, 140) or Color3.fromRGB(255, 60, 60)
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

-- skip — клетки, сквозь блоки в которых луч проходит (только что поставленные протяжкой):
-- иначе призрак «запрыгивает» на новый блок и следующий встаёт рядом с ним
local function castBuild(model: Model, skip: { [string]: boolean }?): RaycastResult?
	local ray = screenRay()
	if not ray then
		return nil
	end
	local base = model:FindFirstChild("Base")
	local blocks = model:FindFirstChild("Blocks")
	rayParams.FilterDescendantsInstances = { base :: Instance, blocks :: Instance }
	local origin, dir = ray.Origin, ray.Direction.Unit
	local left = 600
	for _ = 1, 12 do
		local hit = workspace:Raycast(origin, dir * left, rayParams)
		if not hit or not skip then
			return hit
		end
		local inst = hit.Instance
		-- полотно двери видно лучам (CanCollide=true), считаем его частью самой двери
		if inst.Name == "DoorLeaf" and inst.Parent then
			inst = inst.Parent
		end
		local c = if inst.Parent == blocks then inst:GetAttribute("Local") else nil
		if typeof(c) ~= "Vector3" or not skip[cellKey(c)] then
			return hit
		end
		-- луч, начатый внутри детали, её не видит — продолжаем чуть дальше точки входа
		local step = (hit.Position - origin).Magnitude + 0.02
		origin += dir * step
		left -= step
		if left <= 0 then
			break
		end
	end
	return nil
end

local function blockFromHit(hit: RaycastResult?, model: Model): BasePart?
	if not hit then
		return nil
	end
	local inst = hit.Instance
	if inst.Name == "DoorLeaf" and inst.Parent then
		inst = inst.Parent :: Instance
	end
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
-- true — запрос отправлен
local function invoke(name: string, okSound: string?, ...: any): boolean
	if inFlight > 4 then
		return false
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
	return true
end

local function place(): boolean
	local center = ghostCenter
	if not (ghost and ghostValid and center) then
		return false
	end
	local key = cellKey(center)
	local now = os.clock()
	-- дребезг: ту же клетку повторно — не раньше чем через CLICK_DEBOUNCE
	if key == lastPlacedKey and now - lastPlacedAt < CLICK_DEBOUNCE then
		return false
	end
	local spec = State.spec()
	local sent = invoke("Place", "Place", {
		mat = spec.mat,
		shape = spec.shape,
		item = spec.item,
		pos = center,
		size = spec.size,
		rot = spec.rot,
		color = spec.color,
	})
	if not sent then
		return false
	end
	lastPlacedKey = key
	lastPlacedAt = now
	if holding then
		dragPlaced[key] = true
		if not dragAxis then
			dragAxis = ghostAxis
			dragLayer = onAxis(center, ghostAxis)
		end
	end
	-- маленький «пульс» призрака
	ghostHighlight.FillTransparency = 0.35
	task.delay(0.08, function()
		ghostHighlight.FillTransparency = 0.82
	end)
	return true
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
	local now = os.clock()
	-- один блок — одно действие: за протяжку и при быстром повторном клике
	if dragActed[b] or (b == lastActBlock and now - lastActAt < CLICK_DEBOUNCE) then
		return
	end
	lastActBlock = b
	lastActAt = now
	if holding then
		dragActed[b] = true
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
	holding = false
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
	local now = os.clock()
	if tool == "build" then
		hoverHighlight.Adornee = nil
		-- пока кнопка зажата, луч не видит блоки этой протяжки
		local hit = castBuild(model, if holding then dragPlaced else nil)
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
		ghostAxis = normalAxis(plotCF:VectorToObjectSpace(hit.Normal))
		local valid = Grid.inBounds(center, e) and not overlapsClient(model, cf, spec.size)
		-- клетка уже поставлена этой протяжкой — это не ошибка, красным не подсвечиваем
		local done = holding and dragPlaced[cellKey(center)] == true
		setGhostValid(valid, valid or done)
		-- плавное движение призрака
		if not ghostCF or (ghostCF.Position - cf.Position).Magnitude > 30 then
			ghostCF = cf
		else
			ghostCF = (ghostCF :: CFrame):Lerp(cf, math.clamp(dt * 22, 0, 1))
		end
		g:PivotTo(ghostCF :: CFrame)
		-- протяжка: после HoldDelay ставим блоки в новых клетках того же слоя, что и первый
		if
			holding
			and ghostValid
			and not done
			and now - pressAt >= Config.HoldDelay
			and now - lastHoldPlace >= Config.HoldRepeat
			and (dragAxis == nil or math.abs(onAxis(center, dragAxis) - dragLayer) < 0.01)
		then
			lastHoldPlace = now
			place()
		end
	else
		local b = blockFromHit(castBuild(model), model)
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
		-- удаление/покраска при зажатии: после HoldDelay, только блок под курсором, каждый — один раз
		if
			holding
			and b
			and not dragActed[b]
			and tool ~= "pick"
			and now - pressAt >= Config.HoldDelay
			and now - lastHoldPlace >= ACT_REPEAT
		then
			lastHoldPlace = now
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
			local now = os.clock()
			-- «клик», пришедший вместе с касанием, — дубль: касание обработает TouchTap
			if now - lastTouchAt < TOUCH_GUARD then
				return
			end
			if not State.tool or not canBuildNow() then
				return
			end
			lastMouseAt = now
			holding = true
			pressAt = now
			lastHoldPlace = now
			dragPlaced = {}
			dragActed = {}
			dragAxis = nil
			if State.tool == "build" then
				-- слой протяжки задаёт первое попадание
				if ghostCenter then
					dragAxis = ghostAxis
					dragLayer = onAxis(ghostCenter, ghostAxis)
				end
				place()
			else
				actOnHovered()
			end
		elseif input.UserInputType == Enum.UserInputType.Touch then
			lastTouchAt = os.clock()
			touchPos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = false
		end
	end)
	-- окно потеряло фокус — отпускания кнопки можем не дождаться
	UserInputService.WindowFocusReleased:Connect(function()
		holding = false
	end)
	-- на телефоне: короткое касание = одно действие (InputBegan Touch только запоминает точку)
	UserInputService.TouchTap:Connect(function(positions, processed)
		if processed or not State.tool or not canBuildNow() then
			return
		end
		-- это касание уже сработало как клик мыши
		if os.clock() - lastMouseAt < TOUCH_GUARD then
			return
		end
		local p = positions[1]
		if not p then
			return
		end
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
