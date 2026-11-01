-- База камераменов (измерение туалетной войны, «50-я серия»). Строится только у этого игрока, далеко
-- от дома. Большой ангар Альянса: бетонный пол с разметкой, стены из панелей, фермы под крышей,
-- лампы, ящики, бочки, столы с мониторами, экран-радар. Слева — строй камераменов (костюм, вместо
-- головы — камера наблюдения), справа — спикермены (вместо головы — колонка), в глубине — огромный
-- Титан-камерамен в строительных лесах, рядом инженеры-камерамены со сваркой.
-- Головы поворачиваются (agent:lookAt), объективы «зумят», колонки качают басом.
--   local base = CameraBase.new()
--   base.spawn, base.portalCF, base.rickSpot — точки для сюжета
--   base.groups.cameramen / base.groups.speakermen / base.titan — для «осмотрись»
--   base:watch(group, target) — группа (или все: "all") смотрит на точку; target = nil — отвернуться
--   base:destroy()
local RunService = game:GetService("RunService")

local CameraBase = {}
CameraBase.__index = CameraBase
CameraBase.ORIGIN = Vector3.new(-420, 300, 0)
local B, U, Audio

function CameraBase.init(ctx)
	B, U, Audio = ctx.Build, ctx.Util, ctx.Audio
end

local A = CFrame.Angles
local r = math.rad
local SUIT, SUIT2, SHIRT, SHOE, SKIN = "#202227", "#16181C", "#F1F1EE", "#0E0E10", "#E6C3A1"
local METAL = Enum.Material.Metal

local function noCollide(extra)
	local t = { CanCollide = false, CanQuery = false, CanTouch = false }
	if extra then for k, v in pairs(extra) do t[k] = v end end
	return t
end

---------------------------------------------------------------------------
-- персонажи
---------------------------------------------------------------------------
-- костюм (туловище, ноги, руки, галстук); s — масштаб; P — набор B.kit
local function suit(P, s, tie, opts)
	opts = opts or {}
	for _, side in ipairs({ -1, 1 }) do
		P("Leg", 0.78 * s, 2.9 * s, 0.8 * s, side * 0.45 * s, 1.65 * s, 0, SUIT)
		P("Shoe", 0.84 * s, 0.42 * s, 1.25 * s, side * 0.45 * s, 0.21 * s, -0.18 * s, SHOE)
		P("Arm", 0.62 * s, 2.5 * s, 0.66 * s, side * 1.42 * s, 4.3 * s, 0, SUIT, nil, nil, A(0, 0, side * r(4)))
		P("Cuff", 0.66 * s, 0.18 * s, 0.7 * s, side * 1.5 * s, 3.03 * s, 0, SHIRT)
		P("Hand", 0.5 * s, 0.56 * s, 0.52 * s, side * 1.52 * s, 2.68 * s, 0, opts.glove or SKIN)
		P("Lapel", 0.34 * s, 1.5 * s, 0.06 * s, side * 0.4 * s, 4.95 * s, -0.55 * s, SUIT2, nil, nil, A(0, 0, side * r(14)))
	end
	P("Jacket", 2.2 * s, 2.6 * s, 1.05 * s, 0, 4.35 * s, 0, SUIT)
	P("Hips", 2.0 * s, 0.5 * s, 0.95 * s, 0, 3.0 * s, 0, SUIT)
	P("Shirt", 0.62 * s, 1.55 * s, 0.05 * s, 0, 4.9 * s, -0.53 * s, SHIRT)
	P("Tie", 0.24 * s, 1.25 * s, 0.06 * s, 0, 4.75 * s, -0.57 * s, tie)
	P("TieKnot", 0.3 * s, 0.24 * s, 0.08 * s, 0, 5.45 * s, -0.57 * s, tie)
	P("Button", 0.13 * s, 0.13 * s, 0.04 * s, 0, 3.75 * s, -0.55 * s, "#0C0C0E")
	P.vcyl("Neck", 0.55 * s, 0.42 * s, 0, 5.85 * s, 0, "#2F3238", METAL)
end

-- голова-камера: детали в координатах шеи (−Z — вперёд)
local function cameraHead(add, s, dark)
	local body = dark and "#3A3E46" or "#A3A9B1"
	local hood = dark and "#2A2D33" or "#868C94"
	add("Mount", Vector3.new(0.36, 0.55, 0.36) * s, CFrame.new(0, 0.25 * s, 0.25 * s), "#2F3238", METAL)
	add("CamBody", Vector3.new(1.25, 1.1, 2.0) * s, CFrame.new(0, 0.95 * s, -0.15 * s), body, Enum.Material.SmoothPlastic)
	add("Hood", Vector3.new(1.45, 0.14, 2.4) * s, CFrame.new(0, 1.57 * s, -0.32 * s), hood, METAL)
	add("Back", Vector3.new(1.0, 0.9, 0.2) * s, CFrame.new(0, 0.95 * s, 0.92 * s), hood, METAL)
	add("Barrel", Vector3.new(0.55, 0.95, 0.95) * s, CFrame.new(0, 0.95 * s, -1.38 * s) * A(0, r(90), 0), "#1E2024", METAL, "cyl", true)
	add("Lens", Vector3.new(0.06, 0.74, 0.74) * s, CFrame.new(0, 0.95 * s, -1.67 * s) * A(0, r(90), 0), "#2A4677", Enum.Material.Glass, "cyl", true)
	add("Glint", Vector3.new(0.16, 0.16, 0.16) * s, CFrame.new(0.17 * s, 1.12 * s, -1.71 * s), "#FFFFFF", Enum.Material.Neon, "ball", true)
	add("Rec", Vector3.new(0.17, 0.17, 0.17) * s, CFrame.new(0.46 * s, 1.32 * s, -1.12 * s), "#FF2B2B", Enum.Material.Neon, "ball")
end

-- голова-колонка
local function speakerHead(add, s)
	add("Cabinet", Vector3.new(1.55, 2.1, 1.25) * s, CFrame.new(0, 1.1 * s, 0), "#17171B", Enum.Material.SmoothPlastic)
	add("Top", Vector3.new(1.6, 0.1, 1.3) * s, CFrame.new(0, 2.18 * s, 0), "#2C2C33", METAL)
	add("WooferRim", Vector3.new(0.08, 1.28, 1.28) * s, CFrame.new(0, 0.78 * s, -0.64 * s) * A(0, r(90), 0), "#4A4A52", METAL, "cyl")
	add("Woofer", Vector3.new(0.1, 1.06, 1.06) * s, CFrame.new(0, 0.78 * s, -0.63 * s) * A(0, r(90), 0), "#26262C", Enum.Material.SmoothPlastic, "cyl", "cone")
	add("Cap", Vector3.new(0.12, 0.38, 0.38) * s, CFrame.new(0, 0.78 * s, -0.69 * s) * A(0, r(90), 0), "#5C5C66", METAL, "cyl", "cone")
	add("TweeterRim", Vector3.new(0.08, 0.56, 0.56) * s, CFrame.new(0, 1.72 * s, -0.64 * s) * A(0, r(90), 0), "#4A4A52", METAL, "cyl")
	add("Tweeter", Vector3.new(0.1, 0.36, 0.36) * s, CFrame.new(0, 1.72 * s, -0.66 * s) * A(0, r(90), 0), "#33333A", METAL, "cyl", "cone")
	add("Led", Vector3.new(0.14, 0.14, 0.14) * s, CFrame.new(0.6 * s, 2.0 * s, -0.63 * s), "#29E6FF", Enum.Material.Neon, "ball")
end

-- персонаж: kind = "camera" | "speaker"; cf — точка на полу, смотрит вперёд (−Z)
local function agent(parent, kind, cf, s, opts)
	opts = opts or {}
	local m = B.model(parent, kind == "camera" and "Cameraman" or "Speakerman")
	B.outline(m)
	local P = B.kit(m, cf)
	suit(P, s, opts.tie or "#141416", opts)
	local a = { model = m, kind = kind, cf = cf, s = s, neck = CFrame.new(0, 6.1 * s, 0), parts = {}, offs = {}, cfs = {},
		yaw = 0, pitch = 0, tyaw = 0, tpitch = 0, zoom = 0, tzoom = 0, pulse = 0, seed = opts.seed or 0,
		zoomIdx = {}, coneIdx = {}, speed = opts.turnSpeed or 3 }
	local neckCF = cf * a.neck
	local function add(name, size, off, color, mat, shape, tag)
		local p
		local pp = noCollide()
		if shape == "cyl" then
			p = B.cyl(m, name, size.X, size.Y, neckCF * off, color, mat, pp)
		elseif shape == "ball" then
			p = B.ball(m, name, size.X, neckCF * off, color, mat, pp)
		else
			p = B.part(m, name, size, neckCF * off, color, mat, pp)
		end
		table.insert(a.parts, p)
		table.insert(a.offs, off)
		if tag == true then table.insert(a.zoomIdx, #a.parts) end
		if tag == "cone" then table.insert(a.coneIdx, #a.parts) end
		return p
	end
	if kind == "camera" then cameraHead(add, s, opts.dark) else speakerHead(add, s) end
	if opts.hardhat then
		add("HardHat", Vector3.new(1.3, 0.35, 1.6) * s, CFrame.new(0, 1.82 * s, -0.2 * s), "#F2C230", Enum.Material.SmoothPlastic)
	end
	return a
end

-- поставить голову (поворот + зум объектива / качание динамика)
local function poseHead(a)
	local base = a.cf * a.neck * A(0, a.yaw, 0) * A(a.pitch, 0, 0)
	for i, off in ipairs(a.offs) do a.cfs[i] = base * off end
	for _, i in ipairs(a.zoomIdx) do a.cfs[i] = base * CFrame.new(0, 0, -0.38 * a.s * a.zoom) * a.offs[i] end
	for _, i in ipairs(a.coneIdx) do a.cfs[i] = base * CFrame.new(0, 0, -0.07 * a.s * a.pulse) * a.offs[i] end
	workspace:BulkMoveTo(a.parts, a.cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

---------------------------------------------------------------------------
-- ангар
---------------------------------------------------------------------------
local W, D0, D1, H = 46, -46, 50, 40 -- полуширина, передняя и задняя стены, высота

local function crate(parent, cf, s, col)
	local m = B.model(parent, "Crate")
	B.outline(m)
	local P = B.kit(m, cf)
	P("Box", 3.2 * s, 2.6 * s, 3.2 * s, 0, 1.3 * s, 0, col or "#6B5636", Enum.Material.WoodPlanks)
	P("Band", 3.3 * s, 0.3 * s, 3.3 * s, 0, 0.5 * s, 0, "#3E3326")
	P("Band", 3.3 * s, 0.3 * s, 3.3 * s, 0, 2.1 * s, 0, "#3E3326")
	return m
end

-- всё, кроме фона, — поверх фона
local function front(g, bg)
	for _, d in ipairs(g:GetChildren()) do
		if d ~= bg and d:IsA("GuiObject") then d.ZIndex = 2 end
	end
end

local function toiletIcon(parent, x, y, w, col)
	-- пиктограмма унитаза: бачок + чаша
	B.rect(parent, x + w * 0.2, y, w * 0.6, w * 0.35, col)
	local bowl = B.rect(parent, x, y + w * 0.38, w, w * 0.5, col)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.45, 0)
	c.Parent = bowl
end

function CameraBase.new()
	local self = setmetatable({}, CameraBase)
	local O = CameraBase.ORIGIN
	local root = CFrame.new(O)
	local m = Instance.new("Model")
	m.Name = "RM_CameraBase"
	self.model = m
	self.agents = {}
	self.groups = { cameramen = {}, speakermen = {} }
	self.t = 0
	local function at(x, y, z, rot)
		local c = root * CFrame.new(x, y, z)
		if rot then c = c * rot end
		return c
	end
	self.at = at
	local shell = B.model(m, "Hangar")
	-- пол, разметка
	B.part(shell, "Floor", Vector3.new(W * 2 + 2, 1, D1 - D0 + 2), at(0, -0.5, (D0 + D1) / 2), "#5E6066", Enum.Material.Concrete)
	for _, x in ipairs({ -8, 8 }) do
		B.part(shell, "Lane", Vector3.new(0.5, 0.04, 70), at(x, 0.02, -10), "#E2B13C", nil, noCollide({ CastShadow = false }))
	end
	for z = -40, 16, 8 do
		B.part(shell, "Arrow", Vector3.new(1.6, 0.04, 3), at(0, 0.02, z), "#C9CDD3", nil, noCollide({ CastShadow = false }))
	end
	-- стены и рёбра
	local wallCol = "#3E454D"
	B.part(shell, "WallL", Vector3.new(1, H, D1 - D0), at(-W - 0.5, H / 2, (D0 + D1) / 2), wallCol, METAL)
	B.part(shell, "WallR", Vector3.new(1, H, D1 - D0), at(W + 0.5, H / 2, (D0 + D1) / 2), wallCol, METAL)
	B.part(shell, "WallF", Vector3.new(W * 2 + 2, H, 1), at(0, H / 2, D0 - 0.5), wallCol, METAL)
	B.part(shell, "WallB", Vector3.new(W * 2 + 2, H, 1), at(0, H / 2, D1 + 0.5), wallCol, METAL)
	B.part(shell, "Roof", Vector3.new(W * 2 + 2, 1, D1 - D0 + 2), at(0, H + 0.5, (D0 + D1) / 2), "#2A2F35", METAL)
	for z = D0 + 6, D1 - 4, 12 do
		B.part(shell, "Rib", Vector3.new(1.2, H, 1.6), at(-W + 0.3, H / 2, z), "#2E343A", METAL)
		B.part(shell, "Rib", Vector3.new(1.2, H, 1.6), at(W - 0.3, H / 2, z), "#2E343A", METAL)
	end
	for _, side in ipairs({ -1, 1 }) do
		B.part(shell, "Stripe", Vector3.new(0.2, 1.2, D1 - D0), at(side * (W - 0.05), 3.2, (D0 + D1) / 2), "#2B5FA8", nil, noCollide())
		B.part(shell, "Stripe", Vector3.new(0.2, 0.3, D1 - D0), at(side * (W - 0.05), 4.2, (D0 + D1) / 2), "#E2B13C", nil, noCollide())
	end
	-- фермы под крышей
	for z = -34, 46, 16 do
		B.part(shell, "Truss", Vector3.new(W * 2, 0.9, 0.9), at(0, H - 6, z), "#4A525C", METAL)
		B.part(shell, "Truss", Vector3.new(W * 2, 0.6, 0.6), at(0, H - 1, z), "#4A525C", METAL)
		for x = -40, 40, 10 do
			B.part(shell, "Strut", Vector3.new(0.4, 5.6, 0.4), at(x, H - 3.5, z) * A(0, 0, r((x / 10) % 2 == 0 and 40 or -40)), "#4A525C", METAL)
		end
	end
	-- лампы
	local lamps = B.model(m, "Lamps")
	local k = 0
	for _, z in ipairs({ -30, -10, 10, 30 }) do
		for _, x in ipairs({ -18, 18 }) do
			k = k + 1
			B.vcyl(lamps, "Cable", H - 30, 0.15, at(x, 30 + (H - 30) / 2, z), "#1E1E22")
			B.vcyl(lamps, "Shade", 1.2, 4.2, at(x, 29.6, z), "#3B4A56", METAL)
			local bulb = B.vcyl(lamps, "Bulb", 0.2, 3.4, at(x, 28.95, z), "#FFF4D6", Enum.Material.Neon, noCollide({ CastShadow = false }))
			B.light(bulb, "PointLight", { Color = Color3.fromRGB(235, 242, 255), Brightness = 1.7, Range = 48, Shadows = (k == 3 or k == 6) })
		end
	end
	-- ящики, бочки
	local props = B.model(m, "Props")
	for _, c in ipairs({ { -40, -40, 1 }, { -36.5, -40, 1 }, { -40, -40, 1, 2.6 }, { 40, -38, 1.2 }, { 36, -40, 1 }, { 40, -34, 0.9 },
		{ -40, 30, 1.3 }, { -40, 35, 1.3, 0, "#5B6B3A" }, { -40, 32.5, 1.3, 3.4, "#5B6B3A" }, { 40, 36, 1.2, 0, "#5B6B3A" } }) do
		crate(props, at(c[1], c[4] or 0, c[2]) * A(0, r((c[1] * 7) % 20), 0), c[3], c[5])
	end
	for i, b in ipairs({ { 38, -26 }, { 40, -24 }, { 37, -22 }, { -38, 18 }, { -40, 20 } }) do
		local bm = B.model(props, "Barrel")
		B.outline(bm)
		B.vcyl(bm, "Barrel", 3, 2, at(b[1], 1.5, b[2]), (i % 2 == 0) and "#2B5FA8" or "#A8342B", METAL)
		B.vcyl(bm, "Ring", 0.2, 2.05, at(b[1], 0.8, b[2]), "#1E1E22", METAL)
		B.vcyl(bm, "Ring", 0.2, 2.05, at(b[1], 2.2, b[2]), "#1E1E22", METAL)
	end
	-- столы с мониторами (слева у стены) и экран-радар
	for i, z in ipairs({ -30, -22 }) do
		local dm = B.model(props, "Desk")
		B.outline(dm)
		local P = B.kit(dm, at(-41, 0, z) * A(0, r(-90), 0))
		P("Top", 6, 0.3, 2.4, 0, 3, 0, "#4A525C", METAL)
		P("Leg", 0.3, 3, 2.2, -2.8, 1.5, 0, "#2E343A", METAL)
		P("Leg", 0.3, 3, 2.2, 2.8, 1.5, 0, "#2E343A", METAL)
		for j = -1, 1, 2 do
			P("Stand", 0.3, 0.8, 0.3, j * 1.5, 3.5, 0.4, "#1E1E22")
			local mon = P("Monitor", 2.6, 1.7, 0.2, j * 1.5, 4.6, 0.4, "#111418")
			local g = B.surface(mon, Enum.NormalId.Front, 60)
			local gbg = B.rect(g, 0, 0, 1, 1, "#0D2236")
			B.text(g, 0.05, 0.05, 0.9, 0.25, "КАМЕРА " .. (i * 2 + j + 1) .. "  ● REC", "#FF5050", Enum.Font.Code)
			if j == 1 then
				toiletIcon(g, 0.42, 0.42, 0.16, "#E8E8E8")
			else
				B.text(g, 0.05, 0.45, 0.9, 0.3, "ЧИСТО", "#7CFF4A", Enum.Font.Code)
			end
			front(g, gbg)
		end
	end
	local radar = B.part(props, "Radar", Vector3.new(0.3, 9, 16), at(-W + 0.2, 11, 4), "#111418")
	local rg = B.surface(radar, Enum.NormalId.Right, 30)
	local rbg = B.rect(rg, 0, 0, 1, 1, "#071A12")
	B.text(rg, 0.04, 0.03, 0.92, 0.12, "РАДАР · СКИБИДИ-УГРОЗА", "#7CFF4A", Enum.Font.Code)
	for _, c in ipairs({ { 0.5, 0.55, 0.5 }, { 0.5, 0.55, 0.32 }, { 0.5, 0.55, 0.14 } }) do
		local ring = B.circle(rg, c[1] - c[3] / 2 * 0.56, c[2] - c[3] / 2, c[3] * 0.56, c[3], "#071A12")
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(60, 200, 90)
		st.Thickness = 2
		st.Parent = ring
	end
	for _, p in ipairs({ { 0.3, 0.4 }, { 0.62, 0.68 }, { 0.7, 0.3 }, { 0.4, 0.75 }, { 0.55, 0.45 } }) do
		toiletIcon(rg, p[1], p[2], 0.04, "#FF4A4A")
	end
	B.text(rg, 0.04, 0.88, 0.92, 0.1, "ОБНАРУЖЕНО: 5  ·  БАЗА №50 В БЕЗОПАСНОСТИ", "#E2B13C", Enum.Font.Code)
	front(rg, rbg)
	-- эмблема Альянса на задней стене
	local banner = B.part(props, "Banner", Vector3.new(26, 9, 0.3), at(0, 31, D1 - 0.2), "#1D3B66")
	local bg = B.surface(banner, Enum.NormalId.Front, 20)
	local bbg = B.rect(bg, 0, 0, 1, 1, "#1D3B66")
	B.text(bg, 0.05, 0.08, 0.9, 0.55, "АЛЬЯНС", "#F2F2F2", Enum.Font.GothamBlack)
	B.text(bg, 0.05, 0.62, 0.9, 0.3, "БАЗА №50 · КАМЕРАМЕНЫ · СПИКЕРМЕНЫ", "#E2B13C", Enum.Font.GothamBold)
	front(bg, bbg)
	-- ремонтная площадка титана: платформа с жёлто-чёрными полосами и леса
	local bay = B.model(m, "TitanBay")
	B.part(bay, "Pad", Vector3.new(30, 0.4, 22), at(0, 0.2, 36), "#3A3F46", METAL)
	for i = -7, 7 do
		B.part(bay, "Hazard", Vector3.new(1.2, 0.05, 22.2), at(i * 2, 0.42, 36) * A(0, r(30), 0), (i % 2 == 0) and "#E2B13C" or "#17171B", nil, noCollide({ CastShadow = false }))
	end
	B.part(bay, "PadTop", Vector3.new(26, 0.06, 18), at(0, 0.45, 36), "#3A3F46", METAL, noCollide({ CastShadow = false }))
	local scaffold = B.model(bay, "Scaffold")
	for _, x in ipairs({ -12, 12 }) do
		for _, z in ipairs({ 28, 44 }) do
			B.vcyl(scaffold, "Pole", 30, 0.5, at(x, 15, z), "#C9CFD6", METAL)
		end
		for _, y in ipairs({ 10, 20 }) do
			B.part(scaffold, "Deck", Vector3.new(3, 0.3, 16), at(x, y, 36), "#8C6A3D", Enum.Material.WoodPlanks)
			B.part(scaffold, "Rail", Vector3.new(0.25, 0.25, 16), at(x + (x > 0 and -1.4 or 1.4), y + 2.2, 36), "#E2B13C", METAL)
		end
		B.part(scaffold, "Brace", Vector3.new(0.3, 0.3, 21), at(x, 6, 36) * A(r(48), 0, 0), "#C9CFD6", METAL)
	end
	-- мигалки
	self.beacons = {}
	for _, x in ipairs({ -14.5, 14.5 }) do
		local bcn = B.ball(bay, "Beacon", 1.2, at(x, 30.6, 28), "#FF3B30", Enum.Material.Neon, noCollide())
		table.insert(self.beacons, { p = bcn, l = B.light(bcn, "PointLight", { Color = Color3.fromRGB(255, 60, 40), Brightness = 2, Range = 26, Shadows = false }) })
	end

	-- персонажи: камерамены слева, спикермены справа (смотрят в проход), титан в глубине
	local seed = 0
	for row, x in ipairs({ -15, -21 }) do
		for _, z in ipairs({ -16, -8, 0 }) do
			seed = seed + 1
			local a = agent(m, "camera", at(x, 0, z + (row - 1) * 1.5) * A(0, r(-90), 0), 1, { seed = seed, dark = (seed % 3 == 0), tie = (seed == 2) and "#B3261E" or nil })
			table.insert(self.agents, a)
			table.insert(self.groups.cameramen, a)
		end
	end
	for row, x in ipairs({ 15, 21 }) do
		for _, z in ipairs({ -16, -8, 0 }) do
			seed = seed + 1
			if not (row == 2 and z == 0) then
				local a = agent(m, "speaker", at(x, 0, z + (row - 1) * 1.5) * A(0, r(90), 0), 1, { seed = seed })
				table.insert(self.agents, a)
				table.insert(self.groups.speakermen, a)
			end
		end
	end
	-- инженеры на лесах (сварка)
	self.welders = {}
	for i, x in ipairs({ -12, 12 }) do
		local a = agent(m, "camera", at(x, 10.15, 33) * A(0, r(x < 0 and -90 or 90), 0), 0.95, { seed = 20 + i, hardhat = true, glove = "#C9A24A", turnSpeed = 2 })
		table.insert(self.agents, a)
		local hand = a.cf * CFrame.new(-1.5, 2.7, -0.4)
		local spark = B.part(m, "Weld", Vector3.new(0.3, 0.3, 0.3), hand, "#BFE8FF", Enum.Material.Neon, noCollide({ CastShadow = false }))
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 140, 40))
		pe.LightEmission = 1
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		pe.Lifetime = NumberRange.new(0.3, 0.7)
		pe.Speed = NumberRange.new(6, 12)
		pe.SpreadAngle = Vector2.new(70, 70)
		pe.Acceleration = Vector3.new(0, -40, 0)
		pe.Rate = 45
		pe.Parent = spark
		table.insert(self.welders, { p = spark, l = B.light(spark, "PointLight", { Color = Color3.fromRGB(170, 220, 255), Brightness = 3, Range = 14, Shadows = false }) })
	end
	-- Титан-камерамен (огромный, в лесах; голова поворачивается медленно)
	local ts = 4.4
	local tcf = at(0, 0.45, 38) -- лицом к входу (−Z)
	local titan = agent(m, "camera", tcf, ts, { seed = 99, turnSpeed = 0.9 })
	local TP = B.kit(titan.model, tcf)
	TP.ball("Core", 0.62 * ts, 0, 4.7 * ts, -0.58 * ts, "#4FC3FF", Enum.Material.Neon)
	for _, side in ipairs({ -1, 1 }) do
		TP("Pauldron", 1.05 * ts, 0.45 * ts, 1.3 * ts, side * 1.45 * ts, 5.75 * ts, 0, "#8E969E", METAL)
		TP.vcyl("Jet", 1.1 * ts, 0.5 * ts, side * 0.5 * ts, 4.7 * ts, 0.72 * ts, "#5E6B66", METAL)
	end
	local core = titan.model:FindFirstChild("Core")
	if core then B.light(core, "PointLight", { Color = Color3.fromRGB(80, 190, 255), Brightness = 2.5, Range = 30, Shadows = false }) end
	titan.tyaw = 0
	self.titan = titan
	table.insert(self.agents, titan)

	-- точки для сюжета
	self.spawn = CFrame.lookAt(O + Vector3.new(0, 3, -34), O + Vector3.new(0, 3, 0))
	self.portalCF = CFrame.lookAt(O + Vector3.new(0, 5.6, -38.5), O + Vector3.new(0, 5.6, 0))
	self.rickSpot = O + Vector3.new(-3.2, 0, -36.2) -- чуть позади Морти, не загораживает вид
	self.ORIGIN = O
	m.Parent = workspace
	for _, a in ipairs(self.agents) do poseHead(a) end
	self.conn = RunService.RenderStepped:Connect(function(dt)
		if not U.paused then self:update(dt) end
	end)
	return self
end

-- центр группы (для «посмотри на них»)
function CameraBase:groupCenter(list)
	local sum = Vector3.new()
	for _, a in ipairs(list) do sum = sum + (a.cf * a.neck).Position end
	return sum / math.max(1, #list)
end

function CameraBase:update(dt)
	self.t = self.t + dt
	local t = self.t
	for _, a in ipairs(self.agents) do
		local tgt = a.target
		if type(tgt) == "function" then tgt = tgt() end
		if tgt then
			local loc = (a.cf * a.neck):PointToObjectSpace(tgt)
			local flat = math.sqrt(loc.X * loc.X + loc.Z * loc.Z)
			a.tyaw = math.clamp(math.atan2(-loc.X, -loc.Z), r(-80), r(80))
			a.tpitch = math.clamp(math.atan2(loc.Y, math.max(0.1, flat)), r(-40), r(30))
		elseif a ~= self.titan then
			-- «сканируют» помещение
			a.tyaw = math.sin(t * 0.33 + a.seed * 1.7) * 0.45
			a.tpitch = math.sin(t * 0.21 + a.seed) * 0.08
		else
			a.tyaw, a.tpitch = 0, r(-12)
		end
		local k = 1 - math.exp(-a.speed * dt)
		a.yaw = a.yaw + (a.tyaw - a.yaw) * k
		a.pitch = a.pitch + (a.tpitch - a.pitch) * k
		a.zoom = a.zoom + (a.tzoom - a.zoom) * (1 - math.exp(-4 * dt))
		if a.kind == "speaker" then
			-- басовые толчки динамиков
			local beat = (t * 2 + a.seed * 0.13) % 1
			a.pulse = (a.target and 1 or 0.35) * math.max(0, 1 - beat * 4)
		end
		poseHead(a)
	end
	for i, bc in ipairs(self.beacons) do
		local on = math.sin(t * 6 + i * math.pi) > 0
		bc.p.Color = on and Color3.fromRGB(255, 70, 50) or Color3.fromRGB(90, 20, 15)
		bc.l.Brightness = on and 2.4 or 0.2
	end
	for i, w in ipairs(self.welders) do
		w.l.Brightness = 1.5 + math.abs(math.sin(t * 23 + i * 2)) * 2.5 * ((math.noise(t * 2, i) > -0.2) and 1 or 0)
	end
end

-- группа смотрит на точку или следит за ней (target — Vector3 или функция, nil — вернуться к своим делам);
-- zoom = false — без зума объективов
function CameraBase:watch(group, target, zoom)
	local list = group
	if group == "all" then list = self.agents end
	for _, a in ipairs(list) do
		a.target = target
		a.tzoom = (target and (zoom ~= false)) and 1 or 0
	end
end

function CameraBase:destroy()
	if self.conn then self.conn:Disconnect() end
	if self.model then self.model:Destroy() end
end

return CameraBase
