-- Строительство на клиенте: «призрак» блока под курсором, установка, удаление, покраска,
-- пипетка, повороты и копание земли под участком. Всё проверяется ещё раз на сервере.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local BlockFactory = require(Shared.BlockFactory)
local Grid = require(Shared.Grid)
local MapLayout = require(Shared.MapLayout)
local Net = require(Shared.Net)
local UG = require(Shared.Underground)
local Util = require(Shared.Util)

local Client = script.Parent
local State = require(Client.State)
local SoundPlayer = require(Client.SoundPlayer)
local HUD = require(Client.UI.HUD)
local Lib = require(Client.UI.Lib)
local Theme = require(Client.UI.Theme)

local BuildController = {}

local player = Players.LocalPlayer
local ghost: Model? = nil
local ghostKey = ""
local ghostHighlight: Highlight
local hoverHighlight: Highlight
local ghostCF: CFrame? = nil
local ghostValid = false
local ghostNeedsDig = false -- призрак красный, потому что под ним ещё не выкопана земля
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
local EXPLAIN_REPEAT = 1.5 -- одну и ту же подсказку «почему нельзя» — не чаще
local lastPlacedKey = ""
local lastPlacedAt = 0
local lastActBlock: BasePart? = nil
local lastActAt = 0
local lastTouchAt = -1
local lastMouseAt = -1
local lastExplain = ""
local lastExplainAt = 0

-- подземелье: выкопанные клетки своего участка (атрибут Dug модели участка)
local dug: { [number]: boolean } = {}
local dugConn: RBXScriptConnection? = nil

-- инструмент «Копать»
local DIG_REPEAT = Config.HoldRepeat * 1.5 -- протяжка: пауза между клетками
local DIG_COLOR = Color3.fromRGB(255, 150, 50) -- копать — тёплый оранжевый
local FILL_COLOR = Color3.fromRGB(80, 170, 255) -- засыпать — голубой
local BAD_COLOR = Color3.fromRGB(255, 70, 70)
local DUST = "rbxasset://textures/particles/smoke_main.dds"
local digFolder: Folder
local digCursor: Part -- прозрачный куб размером с клетку (только на клиенте)
local digBox: SelectionBox
local digLabel: TextLabel
local modeButton: TextButton
local digCell: number? = nil -- клетка под курсором (номер UG.index)
local digCellFill = false -- в каком режиме найдена эта клетка
local digValid = false
local digReason: string? = nil -- почему клетку нельзя трогать (подпись у курсора)
local digBusy = false -- запрос ещё не вернулся: одновременно — не больше одного
local dragFill = false -- режим этой протяжки
local dragDigLayer: number? = nil -- слой (iy) первой клетки протяжки
local dragDug: { [number]: boolean } = {} -- клетки, выкопанные/засыпанные за эту протяжку
local lastDigCell = -1
local lastDigAt = 0

local NEED_DIG = "Сначала выкопай здесь землю — инструмент «Копать» (5)"
local NOT_EXPOSED = "Копать можно сверху или рядом с ямой"
local BEDROCK = "Ниже — скала: глубже копать нельзя"
local EDGE = "Край участка: дальше копать нельзя"
local BLOCKS_INSIDE = "Здесь стоят блоки — сначала убери их"

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

local function hintFor(tool: string?): string
	if tool == "dig" then
		if State.digFill then
			return "ЛКМ — засыпать яму  •  держи и веди — засыпать рядом  •  F или Shift+ЛКМ — копать  •  Ctrl+Z — отмена"
		end
		local depth = Config.Underground.Depth
		return string.format(
			"ЛКМ — копать землю  •  держи и веди — копать рядом  •  F или Shift+ЛКМ — засыпать  •  копать можно на %d %s вниз",
			depth,
			Util.plural(depth, "стад", "стада", "стадов")
		)
	end
	return tool and HINTS[tool] or ""
end

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

-- подсказка «почему нельзя» по клику (одна и та же — не чаще EXPLAIN_REPEAT)
local function explain(text: string)
	local now = os.clock()
	if text == lastExplain and now - lastExplainAt < EXPLAIN_REPEAT then
		return
	end
	lastExplain = text
	lastExplainAt = now
	HUD.toast(text, "warning")
end

-- ПОДЗЕМЕЛЬЕ ------------------------------------------------------------------------
-- Маска выкопанных клеток приходит атрибутом Dug модели участка (hex-строка, см. Underground)
local function watchDug(model: Model?)
	if dugConn then
		dugConn:Disconnect()
		dugConn = nil
	end
	dug = {}
	if not model then
		return
	end
	local function refresh()
		local hex = model:GetAttribute("Dug")
		dug = UG.decode(if type(hex) == "string" then hex else nil)
	end
	dugConn = model:GetAttributeChangedSignal("Dug"):Connect(refresh)
	refresh()
end

-- все клетки земли, которые блок задевает ниже пола, выкопаны?
local function cellsDug(center: Vector3, e: Vector3): boolean
	for _, i in UG.cellsInBox(center, e) do
		if not dug[i] then
			return false
		end
	end
	return true
end

local function layerOf(i: number): number
	local _, iy = UG.coords(i)
	return iy
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

-- Лучи видят землю и плиту пола (Ground), стенки и дно котлована (Foundation) и блоки
local function rayTargets(model: Model): { Instance }
	local list = {}
	for _, name in { "Ground", "Foundation", "Blocks" } do
		local folder = model:FindFirstChild(name)
		if folder then
			table.insert(list, folder)
		end
	end
	return list
end

-- skip — клетки, сквозь блоки в которых луч проходит (только что поставленные протяжкой):
-- иначе призрак «запрыгивает» на новый блок и следующий встаёт рядом с ним
local function castBuild(model: Model, skip: { [string]: boolean }?): RaycastResult?
	local ray = screenRay()
	if not ray then
		return nil
	end
	local blocks = model:FindFirstChild("Blocks")
	rayParams.FilterDescendantsInstances = rayTargets(model)
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

-- блок под лучом (земля и стенки котлована — не блоки: их не удалить и не покрасить)
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
-- Запрос к серверу. Ошибка в обработчике на сервере не должна «заклинить» счётчики запросов.
local function callServer(name: string, ...: any): (boolean, string?)
	local args = table.pack(...)
	local called, ok, msg = pcall(function()
		return Net.func(name):InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not called then
		warn(string.format("[Build] %s: %s", name, tostring(ok)))
		return false, nil
	end
	return ok == true, if type(msg) == "string" then msg else nil
end

-- true — запрос отправлен
local function invoke(name: string, okSound: string?, ...: any): boolean
	if inFlight > 4 then
		return false
	end
	inFlight += 1
	local args = table.pack(...)
	task.spawn(function()
		local ok, msg = callServer(name, table.unpack(args, 1, args.n))
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
	if ghost and center and not ghostValid and ghostNeedsDig then
		explain(NEED_DIG)
	end
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

-- КОПАНИЕ ---------------------------------------------------------------------------
-- Режим «Копать»: F переключает копать/засыпать, зажатый Shift — наоборот (на один клик)
local function digFillMode(): boolean
	local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	return State.digFill ~= shift
end

local function hideDigCursor()
	digCell = nil
	if digCursor.Parent then
		digCursor.Parent = nil
	end
end

local function showDigCursor(cf: CFrame, fill: boolean, valid: boolean, reason: string?)
	local color = if not valid then BAD_COLOR elseif fill then FILL_COLOR else DIG_COLOR
	digCursor.CFrame = cf
	digCursor.Color = color
	digBox.Color3 = color
	digLabel.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.45)
	digLabel.Text = if not valid then reason or "Нельзя" elseif fill then "⛰ Засыпать" else "⛏ Копать"
	if digCursor.Parent ~= digFolder then
		digCursor.Parent = digFolder
	end
end

-- облачко пыли в клетке после копания (вверх) или засыпки (оседает вниз)
local function dustBurst(cf: CFrame, fill: boolean)
	local q = State.settings.Graphics or 3
	local amount = if q == 1 then 0.35 elseif q == 2 then 0.65 else 1
	local holder = Instance.new("Part")
	holder.Name = "DigDust"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.one * (UG.CELL - 0.5)
	holder.CFrame = cf
	holder.Parent = digFolder
	local e = Instance.new("ParticleEmitter")
	e.Texture = DUST
	e.Rate = 0
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(60, 60)
	e.Speed = if fill then NumberRange.new(1, 3) else NumberRange.new(3, 8)
	e.Drag = 3
	e.Acceleration = Vector3.new(0, if fill then -14 else -3, 0)
	e.Lifetime = NumberRange.new(0.7, 1.4)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(Color3.fromRGB(134, 108, 80), Color3.fromRGB(96, 84, 70))
	e.LightInfluence = 1
	e.Parent = holder
	e:Emit(math.max(4, math.floor(14 * amount)))
	Debris:AddItem(holder, 2)
end

-- Клетка земли под курсором: (номер, можно ли, почему нельзя).
-- Копать: луч попал в плиту пола или землю — берём клетку сразу за поверхностью.
-- Засыпать: луч попал в любую поверхность в яме — берём пустую клетку перед ней.
local function findDigCell(model: Model, plotCF: CFrame, fill: boolean): (number?, boolean, string?)
	local hit = castBuild(model)
	if not hit then
		return nil, false, nil
	end
	local inst = hit.Instance
	local ground = model:FindFirstChild("Ground")
	local foundation = model:FindFirstChild("Foundation")
	local isSoil = ground ~= nil and inst:IsDescendantOf(ground) and (inst.Name == "Slab" or inst.Name == "Soil")
	local isFoundation = foundation ~= nil and inst:IsDescendantOf(foundation)
	if not fill and not isSoil and not isFoundation then
		return nil, false, nil -- блоки не копаем
	end
	-- точка чуть за поверхностью (в земле) или чуть перед ней (в пустоте)
	local inward = not fill and isSoil
	local p = plotCF:PointToObjectSpace(hit.Position + hit.Normal * (if inward then -0.05 else 0.05))
	local ix, iy, iz = UG.cellAt(p)
	if not (ix and iy and iz) then
		return nil, false, nil
	end
	local i = UG.index(ix, iy, iz)
	if fill then
		if not dug[i] then
			return nil, false, nil -- тут и так земля (или её только что засыпали)
		end
		if overlapsClient(model, plotCF * CFrame.new(UG.cellCenter(ix, iy, iz)), Vector3.one * UG.CELL) then
			return i, false, BLOCKS_INSIDE
		end
		return i, true, nil
	end
	if isFoundation then
		-- дно и стенки котлована: показываем пустую клетку перед ними красной
		if not dug[i] then
			return nil, false, nil
		end
		return i, false, if inst.Name == "Bedrock" then BEDROCK else EDGE
	end
	if dug[i] then
		return nil, false, nil -- уже выкопано: земля вот-вот исчезнет
	end
	if not UG.isExposed(dug, ix, iy, iz) then
		return i, false, NOT_EXPOSED
	end
	return i, true, nil
end

-- Выкопать или засыпать клетку под курсором. true — запрос отправлен
local function dig(): boolean
	local i = digCell
	if not i then
		return false
	end
	if not digValid then
		if digReason then
			explain(digReason)
		end
		return false
	end
	local now = os.clock()
	-- не больше одного запроса сразу; ту же клетку повторно — не раньше CLICK_DEBOUNCE
	if digBusy or (i == lastDigCell and now - lastDigAt < CLICK_DEBOUNCE) then
		return false
	end
	local _, plotCF = myPlot()
	if not plotCF then
		return false
	end
	local fill = digCellFill
	local ix, iy, iz = UG.coords(i)
	local cf = plotCF * CFrame.new(UG.cellCenter(ix, iy, iz))
	digBusy = true
	lastDigCell = i
	lastDigAt = now
	if holding then
		dragDug[i] = true
		dragDigLayer = dragDigLayer or iy
	end
	local mask = dug
	task.spawn(function()
		local ok, msg = callServer("Dig", ix, iy, iz, fill)
		digBusy = false
		if ok then
			-- не ждём атрибута Dug: курсор сразу перестаёт показывать эту клетку
			mask[i] = if fill then nil else true
			SoundPlayer.play("Dig", { speed = 0.9 + math.random() * 0.2 })
			dustBurst(cf, fill)
		elseif msg then
			HUD.toast(msg, "error")
		end
	end)
	return true
end

-- СЕТКА НА УЧАСТКЕ ------------------------------------------------------------------
local function buildGrid(model: Model)
	if gridGui then
		gridGui:Destroy()
		gridGui = nil
	end
	-- невидимая плоскость чуть выше пола: сетка не мерцает с плитой
	local plane = model:FindFirstChild("GridPlane") :: BasePart?
	if not plane then
		return
	end
	local g = Instance.new("SurfaceGui")
	g.Name = "BuildGrid"
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 16
	g.LightInfluence = 0.6
	g.Adornee = plane
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
-- подсказка и кнопка режима «Копать» (копать / засыпать)
local function refreshDigMode()
	if modeButton then
		modeButton.Text = if State.digFill then "Режим: ⛰ засыпать  (F)" else "Режим: ⛏ копать  (F)"
		Lib.setButtonColor(modeButton, if State.digFill then Color3.fromRGB(40, 92, 150) else Color3.fromRGB(150, 78, 30))
	end
	if State.tool == "dig" then
		HUD.setHint(hintFor("dig"))
	end
end

function BuildController.setTool(tool: string?)
	if (State.inSiege() or State.launched) and tool ~= nil then
		HUD.toast(State.launched and "Сначала останови испытание" or "Во время осады строить нельзя", "warning")
		tool = nil
	end
	State.set("tool", tool)
	HUD.setTool(tool)
	HUD.setHint(hintFor(tool))
	if tool ~= "build" then
		destroyGhost()
	end
	if tool ~= "dig" then
		hideDigCursor()
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
	modeButton.Visible = tool == "dig" and canBuildNow()
	if not model or not plotCF or not tool or not canBuildNow() then
		destroyGhost()
		hideDigCursor()
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
		-- ниже пола блок встаёт только в выкопанные клетки
		local inside = Grid.inBounds(center, e)
		ghostNeedsDig = inside and not cellsDug(center, e)
		local valid = inside and not ghostNeedsDig and not overlapsClient(model, cf, spec.size)
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
	elseif tool == "dig" then
		hoverHighlight.Adornee = nil
		hovered = nil
		-- во время протяжки режим не меняется (Shift можно отпустить)
		local fill = if holding then dragFill else digFillMode()
		local i, valid, reason = findDigCell(model, plotCF, fill)
		if not i then
			hideDigCursor()
			return
		end
		digCell, digCellFill, digValid, digReason = i, fill, valid, reason
		local ix, iy, iz = UG.coords(i)
		showDigCursor(plotCF * CFrame.new(UG.cellCenter(ix, iy, iz)), fill, valid, reason)
		-- протяжка: после HoldDelay копаем новые клетки того же слоя, что и первая
		if
			holding
			and valid
			and not digBusy
			and not dragDug[i]
			and now - pressAt >= Config.HoldDelay
			and now - lastHoldPlace >= DIG_REPEAT
			and (dragDigLayer == nil or iy == dragDigLayer)
		then
			lastHoldPlace = now
			dig()
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

-- курсор копания: куб чуть больше клетки (грани не мерцают с землёй), рамка и подпись
local function buildDigCursor()
	digFolder = Instance.new("Folder")
	digFolder.Name = "DigFx"
	digFolder.Parent = workspace
	local p = Instance.new("Part")
	p.Name = "DigCursor"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Transparency = 0.82
	p.Size = Vector3.one * (UG.CELL + 0.12)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	digCursor = p
	digBox = Instance.new("SelectionBox")
	digBox.LineThickness = 0.08
	digBox.SurfaceTransparency = 1
	digBox.Adornee = p
	digBox.Parent = p
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(320, 30)
	bb.StudsOffsetWorldSpace = Vector3.new(0, UG.CELL / 2 + 1.5, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 300
	bb.Adornee = p
	bb.Parent = p
	digLabel = Instance.new("TextLabel")
	digLabel.BackgroundTransparency = 1
	digLabel.Size = UDim2.fromScale(1, 1)
	digLabel.FontFace = Theme.FontHeavy
	digLabel.TextSize = 20
	digLabel.TextStrokeTransparency = 0.35
	digLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	digLabel.Parent = bb

	-- кнопка режима над панелью инструментов (на телефоне F не нажать)
	modeButton = Lib.button("", {
		Name = "DigMode",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -158),
		Size = UDim2.fromOffset(260, 40),
		TextSize = 17,
		Visible = false,
		Parent = HUD.gui(),
	}, function()
		State.set("digFill", not State.digFill)
	end)
	refreshDigMode()
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
	buildDigCursor()

	local function onPlot()
		local model = myPlot()
		watchDug(model)
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
		elseif key == "digFill" then
			refreshDigMode()
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
			elseif kc == Enum.KeyCode.Five then
				BuildController.setTool(if State.tool == "dig" then nil else "dig")
			elseif kc == Enum.KeyCode.F and State.tool == "dig" then
				State.set("digFill", not State.digFill)
				SoundPlayer.play("Hover")
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
			dragDug = {}
			dragAxis = nil
			dragDigLayer = nil
			if State.tool == "build" then
				-- слой протяжки задаёт первое попадание
				if ghostCenter then
					dragAxis = ghostAxis
					dragLayer = onAxis(ghostCenter, ghostAxis)
				end
				place()
			elseif State.tool == "dig" then
				-- режим и слой протяжки задаёт первый клик (Shift — наоборот)
				dragFill = digFillMode()
				if digCell then
					dragDigLayer = layerOf(digCell)
				end
				dig()
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
			elseif State.tool == "dig" then
				dig()
			else
				actOnHovered()
			end
		end)
	end)

	RunService.RenderStepped:Connect(update)
end

return BuildController
