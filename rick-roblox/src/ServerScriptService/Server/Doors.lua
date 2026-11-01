-- Двери: полотно на петлях, открытие по E (ProximityPrompt), часть дверей заперта.
-- Состояние двери общее для всех игроков (сервер), мысль Морти у запертой двери показывает клиент
-- (атрибут Thought на подсказке).
local Doors = {}

local TweenService = game:GetService("TweenService")

local B, C, House

-- into: в какую сторону по нормали к стене открывается (+1 — к большему x/z), hinge: low/high край проёма
local SPEC = {
	Morty = { into = 1, hinge = "high", color = "#F4EFE6", sign = "МОРТИ", open = 0 },
	Summer = { into = 1, hinge = "low", color = "#F4EFE6", locked = "SummerDoor", sign = "НЕ ВХОДИТЬ!" },
	Parents = { into = -1, hinge = "low", color = "#F4EFE6", locked = "ParentsDoor" },
	Bath = { into = -1, hinge = "high", color = "#F4EFE6", open = 0.35 },
	Mudroom = { into = 1, hinge = "low", color = "#F4EFE6", open = 0 },
	Garage = { into = 1, hinge = "high", color = "#C9C2B4", locked = "GarageDoor", sign = "ГАРАЖ" },
	Front = { into = 1, hinge = "low", color = "#7A4A2E", locked = "FrontDoor", front = true },
	Back = { into = -1, hinge = "high", color = "#7A4A2E", locked = "BackDoor", glass = true },
}

local function buildDoor(id, spec, parent)
	local o = House.opening(id)
	if not o then return nil end
	local y = o.fl == 1 and C.House.Floor1 or C.House.Floor2
	local w, h = o.w, o.y1 - o.y0
	-- локальная система: X — вдоль стены от петли, Z — нормаль стены (+Z — в сторону into)
	local hingeAt = spec.hinge == "high" and (o.c + w / 2) or (o.c - w / 2)
	local dirAlong = spec.hinge == "high" and -1 or 1 -- куда от петли идёт полотно
	local hingePos, alongVec, normalVec
	if o.axis == "z" then
		hingePos = Vector3.new(hingeAt, y, o.at)
		alongVec = Vector3.new(dirAlong, 0, 0)
		normalVec = Vector3.new(0, 0, spec.into)
	else
		hingePos = Vector3.new(o.at, y, hingeAt)
		alongVec = Vector3.new(0, 0, dirAlong)
		normalVec = Vector3.new(spec.into, 0, 0)
	end
	local upVec = Vector3.yAxis
	-- правая тройка: X = along, Y = up, Z = X × Y; если она смотрит не туда — открываем в −Z
	local zVec = alongVec:Cross(upVec)
	local openSign = (zVec:Dot(normalVec) > 0) and 1 or -1
	local hingeCF = CFrame.fromMatrix(hingePos, alongVec, upVec)

	local m = B.model(parent, "Door_" .. id)
	B.attrs(m, { Kind = "Door", Locked = spec.locked ~= nil, Open = false })
	local leaf = B.model(m, "Leaf")
	local lw, lh, th = w - 0.2, h - 0.12, 0.32
	local P = B.kit(leaf, hingeCF * CFrame.new(lw / 2 + 0.05, lh / 2 + 0.02, 0))
	local panel = P("Panel", lw, lh, th, 0, 0, 0, spec.color)
	leaf.PrimaryPart = panel
	-- филёнки с обеих сторон
	local inset = B.shade(spec.color, 0.92)
	for _, s in ipairs({ -1, 1 }) do
		if spec.glass then
			P("Glass", lw * 0.55, lh * 0.32, 0.06, 0, lh * 0.22, s * (th / 2), "#CFEAFF", Enum.Material.Glass, { Transparency = 0.5 })
			P("Inset", lw * 0.62, lh * 0.32, 0.06, 0, -lh * 0.22, s * (th / 2 + 0.02), inset)
		else
			P("Inset", lw * 0.62, lh * 0.34, 0.06, 0, lh * 0.2, s * (th / 2 + 0.02), inset)
			P("Inset", lw * 0.62, lh * 0.34, 0.06, 0, -lh * 0.2, s * (th / 2 + 0.02), inset)
		end
		-- ручка
		P.ball("Knob", 0.42, lw / 2 - 0.45, -lh / 2 + 3.7, s * (th / 2 + 0.22), "#D8B25A", Enum.Material.Metal)
		P("KnobBase", 0.25, 0.6, 0.12, lw / 2 - 0.45, -lh / 2 + 3.7, s * (th / 2 + 0.05), "#C79E4A", Enum.Material.Metal)
	end
	if spec.sign then
		local plate = P("Plate", 2.2, 0.9, 0.08, 0, lh * 0.36, -openSign * (th / 2 + 0.06), spec.locked and "#E25B7E" or "#4A7BD0")
		B.sign(plate, openSign > 0 and Enum.NormalId.Front or Enum.NormalId.Back, spec.sign, { Font = Enum.Font.GothamBlack })
	end
	for _, p in ipairs(leaf:GetDescendants()) do
		if p:IsA("BasePart") and p ~= panel then
			p.CanCollide = false
			p.CanQuery = false
		end
	end
	-- подсказка
	local prompt = B.prompt(panel, "Prompt", "Открыть", "", { MaxActivationDistance = 7, HoldDuration = 0 })
	if spec.locked then
		prompt:SetAttribute("Thought", spec.locked)
		prompt:SetAttribute("Locked", true)
	end
	m:SetAttribute("DoorId", id)

	local angle = Instance.new("NumberValue")
	angle.Name = "Angle"
	angle.Parent = m
	local closedCF = hingeCF * CFrame.new(lw / 2 + 0.05, lh / 2 + 0.02, 0)
	local function place(a)
		-- поворот вокруг вертикали в петле: свободный край уходит в сторону into
		local rot = CFrame.Angles(0, -openSign * math.rad(a), 0)
		leaf:PivotTo(hingeCF * rot * CFrame.new(lw / 2 + 0.05, lh / 2 + 0.02, 0))
	end
	angle.Changed:Connect(function(a) place(a) end)
	local busy = false
	local function setOpen(open, who)
		if busy then return end
		busy = true
		m:SetAttribute("Open", open)
		prompt.ActionText = open and "Закрыть" or "Открыть"
		local snd = Instance.new("Sound")
		snd.SoundId = B.asset(open and C.Sounds.DoorOpen or C.Sounds.DoorClose)
		snd.Volume = 0.5
		snd.RollOffMaxDistance = 60
		snd.Parent = panel
		if snd.SoundId ~= "" then snd:Play() end
		task.delay(3, function() snd:Destroy() end)
		local tw = TweenService:Create(angle, TweenInfo.new(open and 0.7 or 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = open and 100 or 0 })
		tw:Play()
		tw.Completed:Wait()
		busy = false
	end
	prompt.Triggered:Connect(function(plr)
		if spec.locked then
			-- подёргать ручку
			local t0 = TweenService:Create(angle, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 1, true), { Value = 1.5 })
			t0:Play()
			return
		end
		setOpen(not m:GetAttribute("Open"), plr)
	end)
	if spec.open and spec.open > 0 then
		angle.Value = 100 * spec.open
		place(angle.Value)
		m:SetAttribute("Open", true)
		prompt.ActionText = "Закрыть"
	else
		leaf:PivotTo(closedCF)
	end
	return m
end

function Doors.build(ctx, root)
	B, C, House = ctx.Build, ctx.Config, ctx.House
	local f = B.folder(root, "Doors")
	for id, spec in pairs(SPEC) do
		buildDoor(id, spec, f)
	end
	return f
end

return Doors
