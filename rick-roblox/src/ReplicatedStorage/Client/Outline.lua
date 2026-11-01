-- Чёрные контуры «как в мультике». Roblox рисует не больше 31 Highlight одновременно,
-- поэтому несколько раз в секунду выбираем ближайшие к камере предметы (Model с атрибутом
-- Outline) и вешаем на них контуры из общего пула.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Outline = {}
local Config, Settings
local POOL = 27
local pool = {}
local candidates = {}
local enabled = true
local acc = 0
local extra = {} -- локальные предметы сюжета (миска, телефон и т.п.)

local function centerOf(m)
	local ok, cf = pcall(function() return m:GetPivot() end)
	if ok then return cf.Position end
	return nil
end

local function collect()
	candidates = {}
	local house = workspace:FindFirstChild("House")
	if house then
		for _, d in ipairs(house:GetDescendants()) do
			if d:IsA("Model") and d:GetAttribute("Outline") then
				local c = centerOf(d)
				if c then table.insert(candidates, { model = d, pos = c }) end
			end
		end
	end
end

function Outline.init(ctx)
	Config, Settings = ctx.Config, ctx.Settings
	local folder = Instance.new("Folder")
	folder.Name = "RM_Outlines"
	folder.Parent = workspace.CurrentCamera
	for i = 1, POOL do
		local h = Instance.new("Highlight")
		h.Name = "Outline" .. i
		h.FillTransparency = 1
		h.OutlineTransparency = 0.05
		h.OutlineColor = Config.Colors.Outline
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Enabled = false
		h.Parent = folder
		pool[i] = h
	end
	collect()
	enabled = Settings.get("Outlines")
	Settings.Changed:Connect(function(k, v)
		if k == "Outlines" then
			enabled = v
			if not v then for _, h in ipairs(pool) do h.Enabled = false; h.Adornee = nil end end
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 0.25 or not enabled then return end
		acc = 0
		local cam = workspace.CurrentCamera
		local cp, look = cam.CFrame.Position, cam.CFrame.LookVector
		local list = {}
		local function consider(m, pos)
			local d = pos - cp
			local dist = d.Magnitude
			if dist > 70 then return end
			local facing = dist < 6 or (d / dist):Dot(look) > 0.15
			if not facing then return end
			table.insert(list, { m = m, s = dist })
		end
		for _, c in ipairs(candidates) do
			if c.model.Parent then consider(c.model, c.pos) end
		end
		for m in pairs(extra) do
			if m.Parent then
				local p = centerOf(m)
				if p then consider(m, p) end
			else
				extra[m] = nil
			end
		end
		table.sort(list, function(a, b) return a.s < b.s end)
		for i, h in ipairs(pool) do
			local item = list[i]
			if item then
				if h.Adornee ~= item.m then h.Adornee = item.m end
				h.Enabled = true
			else
				h.Enabled = false
				h.Adornee = nil
			end
		end
	end)
end

-- добавить локальный предмет (только у этого игрока)
function Outline.add(model) extra[model] = true end
function Outline.remove(model) extra[model] = nil end
function Outline.refresh() collect() end

local _cs = CollectionService
return Outline
