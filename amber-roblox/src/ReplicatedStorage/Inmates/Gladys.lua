-- Заключённая 330: ГЛЭДИС — незваная гостья.
-- Старушка в мешковатом полосатом цирковом комбинезоне, седые кудри, румяна, очки и широкая накрашенная улыбка.
-- Приезжает к крыльцу с крошечным велосипедом: звонок, смех, стук и мольбы («Я ЗАБЛУДИЛАСЬ, ДОРОГУША…»).
-- Открыли входную дверь — врывается и охотится на того, кто ближе к двери. Не открыли — через ~35 с
-- выбивает окно первого этажа. Внутри свет в доме зеленеет; каждые ~15 с он мигает и на 4 с становится
-- КРАСНЫМ: кто ДВИЖЕТСЯ у неё на виду — цель погони. В зелёной фазе замечает только шевеление рядом и бег.
-- Касание — смерть; укрытия спасают (из шкафа не вытаскивает).
-- Атрибуты модели: Phase (0 снаружи | 1 зелёный | 2 предупреждение | 3 красный), Anim.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Rig = require(script.Parent.Parent:WaitForChild("Shared"):WaitForChild("Rig"))

local PORCH_T, RED_EVERY, WARN, RED_DUR, RED_GRACE, FIRST_RED = 35, 15, 0.9, 4, 0.6, 11
local V_ROAM, V_CHASE = 10.5, 16
local GREEN = Color3.fromRGB(109, 255, 140)
local RED = Color3.fromRGB(255, 42, 42)
local SAY = Color3.fromRGB(150, 255, 160)

local PLEAS = {
	"Я ЗАБЛУДИЛАСЬ, ДОРОГУША… ВПУСТИ МЕНЯ?",
	"ТУК-ТУК! ЕСТЬ КТО ДОМА? Я ЖЕ СЛЫШУ, ЧТО ЕСТЬ…",
	"НА УЛИЦЕ ТАК ХОЛОДНО… ОТКРОЙ БАБУЛЕ ДВЕРЬ!",
	"Я ПРИНЕСЛА ВАМ ПЕЧЕНЬЕ, СОЛНЫШКО. ХИ-ХИ-ХИ!",
	"НУ ЖЕ, ДОРОГУША… Я ВСЕГО ЛИШЬ СТАРУШКА.",
	"КАК ЖЕ МНЕ НАЙТИ ДОРОГУ ДОМОЙ?.. ПУСТИ ПОГРЕТЬСЯ!",
}
local PLEA_LIT = "У ВАС ТАК УЮТНО ГОРИТ СВЕТ… ВПУСТИ МЕНЯ, ДОРОГУША!"
local PLEA_FINAL = "НЕ ХОЧЕШЬ ОТКРЫВАТЬ?.. НИЧЕГО, БАБУЛЯ ЗАЙДЁТ САМА!"
local OPENED = "ОЙ, СПАСИБО, ДОРОГУША! ХИ-ХИ-ХИ-ХИ!"
local SPOTTED = { "ВИЖУ ТЕБЯ, ДОРОГУША!", "КТО ЭТО ТАМ ШЕВЕЛИТСЯ?", "НЕ УБЕГАЙ ОТ БАБУЛИ!", "ПОПАЛСЯ, СОЛНЫШКО!" }
local SEQ = { "bell", "knock", "say", "laugh", "knock", "say", "bell", "say", "laugh", "knock", "say" }

local Gladys = {
	key = "Gladys", num = "330", name = "ГЛЭДИС", en = "GLADYS", class = "Класс угрозы: незваная гостья",
	color = Color3.fromRGB(77, 216, 112), hp = 400, speed = V_ROAM, chase = V_CHASE,
	difficulty = 1, minNight = 1, oneShot = true, pulls = false, reach = 4.2, cooldown = 1.0,
	sight = 70, dark = 20, inspect = 0.15,
	alert = {
		"ОЧЕВИДЦЫ ОПИСЫВАЮТ ПОЖИЛУЮ ЖЕНЩИНУ В МЕШКОВАТОМ ЦИРКОВОМ КОСТЮМЕ, БРОДЯЩУЮ ПО ЗАДНИМ ДВОРАМ, — ЗАКЛЮЧЁННАЯ 330.",
		"ЕСЛИ ВЫ СЛЫШИТЕ ВЕЛОСИПЕДНЫЙ ЗВОНОК ИЛИ ПРОНЗИТЕЛЬНЫЙ СМЕХ У СВОЕГО КРЫЛЬЦА — ПОГАСИТЕ ВЕСЬ СВЕТ И СПРЯЧЬТЕСЬ.",
		"НЕ ОТКРЫВАЙТЕ ДВЕРЬ ТОМУ, КТО ГОВОРИТ, ЧТО ЗАБЛУДИЛСЯ.",
	},
	tip = "Не открывай ей дверь. Свет стал красным — замри: она видит только тех, кто двигается.",
	directive = { code = "no_door", text = "НЕ ОТКРЫВАЙТЕ ДВЕРЬ" },
	steps = { key = "Squish", fallback = "Footstep", pitch = 0.55, volume = 0.55 },
	ambient = { key = "Laugh", fallback = "Whisper", every = 11 },
	scare = Color3.fromRGB(60, 255, 110),
}

---------------------------------------------------------------- модель
local CREAM, STRIPE = "#efe2c4", "#b8283c"
local FAB = Enum.Material.Fabric

-- вертикальные полоски по граням бруска (w × h × d)
local function stripes(R, limb, w, h, d, n, sides)
	for i = 1, n do
		local x = -w / 2 + (i - 0.5) * w / n
		for _, z in ipairs({ -d / 2 - 0.02, d / 2 + 0.02 }) do
			local p = Rig.add(R, limb, "Stripe", Vector3.new(w / n * 0.42, h * 0.98, 0.04), CFrame.new(x, 0, z), STRIPE, FAB)
			p.CastShadow = false
		end
	end
	for i = 1, sides or 1 do
		local z = -d / 2 + (i - 0.5) * d / (sides or 1)
		for _, x in ipairs({ -w / 2 - 0.02, w / 2 + 0.02 }) do
			local p = Rig.add(R, limb, "Stripe", Vector3.new(0.04, h * 0.98, d / (sides or 1) * 0.42), CFrame.new(x, 0, z), STRIPE, FAB)
			p.CastShadow = false
		end
	end
end

local function disc(R, limb, name, d, th, cf, color, mat)
	return Rig.cyl(R, limb, name, th, d, cf * CFrame.Angles(0, math.rad(90), 0), color, mat)
end

local function ring(R, limb, name, d, th, cf, color, mat)
	return Rig.cyl(R, limb, name, th, d, cf * CFrame.Angles(0, 0, math.rad(90)), color, mat)
end

-- крошечный детский велосипед у правого бока (приварен к корню, атрибут Bike)
local function bike(R)
	local x = 1.95
	local blue, tire, chrome = "#2f8fd8", "#161616", "#c8ccd2"
	local list = {}
	local function keep(p) p:SetAttribute("Bike", true); table.insert(list, p); return p end
	for _, z in ipairs({ -1.35, 1.1 }) do
		keep(Rig.addAt(R, "HumanoidRootPart", "Wheel", Vector3.new(0.22, 1.4, 1.4), CFrame.new(x, 0.72, z), tire, Rig.mat("Rubber", Enum.Material.SmoothPlastic), { Shape = Enum.PartType.Cylinder }))
		keep(Rig.addAt(R, "HumanoidRootPart", "Hub", Vector3.new(0.26, 0.5, 0.5), CFrame.new(x, 0.72, z), chrome, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder }))
		for k = 0, 2 do
			keep(Rig.addAt(R, "HumanoidRootPart", "Spoke", Vector3.new(0.04, 1.2, 0.04), CFrame.new(x, 0.72, z) * CFrame.Angles(math.rad(k * 60), 0, 0), chrome, Enum.Material.Metal))
		end
	end
	local M = Enum.Material.Metal
	keep(Rig.bar(R, "HumanoidRootPart", "Frame", Vector3.new(x, 1.55, -0.85), Vector3.new(x, 1.5, 0.75), 0.16, blue, M))
	keep(Rig.bar(R, "HumanoidRootPart", "Frame", Vector3.new(x, 1.5, -0.85), Vector3.new(x, 0.8, 0.15), 0.16, blue, M))
	keep(Rig.bar(R, "HumanoidRootPart", "Frame", Vector3.new(x, 0.8, 0.15), Vector3.new(x, 0.72, 1.1), 0.12, blue, M))
	keep(Rig.bar(R, "HumanoidRootPart", "Frame", Vector3.new(x, 1.5, 0.75), Vector3.new(x, 0.72, 1.1), 0.12, blue, M))
	keep(Rig.bar(R, "HumanoidRootPart", "Fork", Vector3.new(x, 2.25, -1.0), Vector3.new(x, 0.72, -1.35), 0.14, blue, M))
	keep(Rig.bar(R, "HumanoidRootPart", "Post", Vector3.new(x, 1.5, 0.75), Vector3.new(x, 1.85, 0.85), 0.12, chrome, M))
	keep(Rig.addAt(R, "HumanoidRootPart", "Seat", Vector3.new(0.38, 0.16, 0.62), CFrame.new(x, 1.92, 0.88), "#6a1a2a", Rig.mat("Leather", FAB)))
	keep(Rig.addAt(R, "HumanoidRootPart", "Bar", Vector3.new(1.3, 0.1, 0.1), CFrame.new(x - 0.05, 2.3, -1.0), chrome, M, { Shape = Enum.PartType.Cylinder }))
	keep(Rig.addAt(R, "HumanoidRootPart", "Bell", Vector3.new(0.12, 0.24, 0.24), CFrame.new(x + 0.35, 2.42, -1.0) * CFrame.Angles(0, 0, math.rad(90)), "#e8c64a", M, { Shape = Enum.PartType.Cylinder }))
	keep(Rig.addAt(R, "HumanoidRootPart", "Basket", Vector3.new(0.9, 0.55, 0.62), CFrame.new(x, 1.95, -1.6), "#cdb98e", Enum.Material.WoodPlanks))
	keep(Rig.addAt(R, "HumanoidRootPart", "Cookies", Vector3.new(0.7, 0.12, 0.5), CFrame.new(x, 2.24, -1.6), "#8a5a2a", Enum.Material.Sand))
	for i, c in ipairs({ "#ff7ab8", "#ffffff", "#7ad0ff" }) do
		keep(Rig.addAt(R, "HumanoidRootPart", "Streamer", Vector3.new(0.05, 0.6, 0.05), CFrame.new(x + 0.62, 2.0, -1.0 + (i - 2) * 0.05), c, FAB))
		keep(Rig.addAt(R, "HumanoidRootPart", "Streamer", Vector3.new(0.05, 0.6, 0.05), CFrame.new(x - 0.7, 2.0, -1.0 + (i - 2) * 0.05), c, FAB))
	end
	return list
end

function Gladys.build(ctx)
	local R = Rig.build({
		name = "Gladys", footH = 0.45, footL = 1.7, legW = 0.95, hipX = 0.52, legU = 1.0, legL = 0.95,
		ltH = 1.0, utH = 1.25, torsoW = 2.3, torsoD = 1.45, armW = 0.62, armU = 1.0, armL = 0.95, hand = 0.55,
		neck = 0.12, head = Vector3.new(1.45, 1.45, 1.4), hunch = 0.12,
		skin = "#ecd0b8", shirt = CREAM, pants = CREAM, shoes = "#b01e2a", hands = "#f4f4f0", stride = 5,
	})
	local P = R.parts
	-- полоски комбинезона
	stripes(R, "UpperTorso", 2.3, 1.25, 1.45, 4, 2)
	stripes(R, "LowerTorso", 2.3 * 0.92, 1.0, 1.45 * 0.95, 4, 2)
	for _, side in ipairs({ "Left", "Right" }) do
		stripes(R, side .. "UpperLeg", 0.95, 1.0, 0.95, 2, 1)
		stripes(R, side .. "LowerLeg", 0.95 * 0.92, 0.95, 0.95 * 0.92, 2, 1)
		stripes(R, side .. "UpperArm", 0.62, 1.0, 0.62, 2, 1)
		stripes(R, side .. "LowerArm", 0.62 * 0.9, 0.95, 0.62 * 0.9, 1, 1)
		-- огромные клоунские туфли с круглым носом и белой подошвой
		Rig.ball(R, side .. "Foot", "Toe", 1.05, CFrame.new(0, 0.12, -0.72), "#b01e2a", Enum.Material.SmoothPlastic)
		Rig.add(R, side .. "Foot", "Sole", Vector3.new(1.0, 0.1, 1.75), CFrame.new(0, -0.2, -0.05), "#f2efe6")
		-- рюш на штанине и манжета перчатки
		ring(R, side .. "LowerLeg", "Frill", 1.25, 0.18, CFrame.new(0, -0.42, 0), "#f2b8c8", FAB)
		ring(R, side .. "Hand", "Cuff", 0.78, 0.2, CFrame.new(0, 0.24, 0), "#ffffff", FAB)
		-- засохшие бурые пятна на перчатках
		Rig.add(R, side .. "Hand", "Stain", Vector3.new(0.25, 0.18, 0.04), CFrame.new(0.08, -0.08, -0.22), "#5a1a10")
	end
	-- животик, помпоны-пуговицы, жабо
	Rig.add(R, "LowerTorso", "Belly", Vector3.new(2.1, 0.8, 0.35), CFrame.new(0, 0.05, -0.8), CREAM, FAB)
	for i = 1, 4 do
		local p = Rig.add(R, "LowerTorso", "Stripe", Vector3.new(0.22, 0.78, 0.04), CFrame.new(-0.79 + (i - 1) * 0.53, 0.05, -0.99), STRIPE, FAB)
		p.CastShadow = false
	end
	Rig.ball(R, "UpperTorso", "Pompom", 0.36, CFrame.new(0, 0.3, -0.78), "#ffd23a", FAB)
	Rig.ball(R, "UpperTorso", "Pompom", 0.36, CFrame.new(0, -0.22, -0.78), "#3a8aff", FAB)
	Rig.ball(R, "LowerTorso", "Pompom", 0.36, CFrame.new(0, 0.2, -1.0), "#3ac85a", FAB)
	Rig.add(R, "UpperTorso", "Stain", Vector3.new(0.4, 0.3, 0.04), CFrame.new(0.55, -0.35, -0.75), "#4a140c")
	ring(R, "UpperTorso", "Ruff", 2.8, 0.3, CFrame.new(0, 0.66, 0), "#f6f2ea", FAB)
	ring(R, "UpperTorso", "Ruff2", 2.25, 0.26, CFrame.new(0, 0.86, 0), "#f2b8c8", FAB)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		Rig.ball(R, "UpperTorso", "Frill", 0.42, CFrame.new(math.cos(a) * 1.35, 0.62, math.sin(a) * 1.35), "#ffffff", FAB)
	end
	-- голова
	local H = "Head"
	local hz = -0.7
	Rig.add(R, H, "Jaw", Vector3.new(1.3, 0.35, 1.25), CFrame.new(0, -0.75, 0.02), "#e6c6ac")
	Rig.add(R, H, "Nose", Vector3.new(0.24, 0.34, 0.28), CFrame.new(0, -0.02, hz - 0.12), "#dcb49a")
	Rig.ball(R, H, "NoseTip", 0.26, CFrame.new(0, -0.17, hz - 0.22), "#e2a48a")
	for _, sx in ipairs({ -1, 1 }) do
		disc(R, H, "Cheek", 0.42, 0.05, CFrame.new(sx * 0.47, -0.2, hz - 0.01), "#ee5472")
		disc(R, H, "EyeWhite", 0.4, 0.06, CFrame.new(sx * 0.3, 0.2, hz - 0.01), "#fbfbf4")
		Rig.add(R, H, "Bag", Vector3.new(0.38, 0.08, 0.04), CFrame.new(sx * 0.3, -0.02, hz - 0.01), "#8a5a6a")
		-- очки: оправа из четырёх планок и мутное стекло
		local c = CFrame.new(sx * 0.3, 0.2, hz - 0.1)
		Rig.add(R, H, "Rim", Vector3.new(0.56, 0.06, 0.05), c * CFrame.new(0, 0.27, 0), "#3a2a1a")
		Rig.add(R, H, "Rim", Vector3.new(0.56, 0.06, 0.05), c * CFrame.new(0, -0.24, 0), "#3a2a1a")
		Rig.add(R, H, "Rim", Vector3.new(0.06, 0.5, 0.05), c * CFrame.new(-0.25, 0.01, 0), "#3a2a1a")
		Rig.add(R, H, "Rim", Vector3.new(0.06, 0.5, 0.05), c * CFrame.new(0.25, 0.01, 0), "#3a2a1a")
		Rig.add(R, H, "Lens", Vector3.new(0.46, 0.44, 0.02), c, "#cfe8d0", Enum.Material.Glass, { Transparency = 0.65 })
		Rig.add(R, H, "Temple", Vector3.new(0.05, 0.05, 0.75), CFrame.new(sx * 0.74, 0.4, -0.35), "#3a2a1a")
		Rig.add(R, H, "Brow", Vector3.new(0.42, 0.08, 0.06), CFrame.new(sx * 0.3, 0.55, hz - 0.02) * CFrame.Angles(0, 0, -sx * 0.25), "#9a9a96")
		Rig.ball(R, H, "Earring", 0.18, CFrame.new(sx * 0.76, -0.3, 0.05), "#e8c64a", Enum.Material.Metal)
	end
	Rig.add(R, H, "Bridge", Vector3.new(0.14, 0.05, 0.05), CFrame.new(0, 0.32, hz - 0.1), "#3a2a1a")
	-- зрачки светятся бледно-зелёным
	Rig.eyes(R, H, CFrame.new(0, 0.2, hz - 0.05), 0.6, 0.13, "#b4ffb0", { range = 6, brightness = 0.8 })
	-- широкая накрашенная улыбка дугой и зубы
	local c = 1.25
	for i = -3, 3 do
		local x = i * 0.12
		Rig.add(R, H, "Lip", Vector3.new(0.15, 0.075, 0.05), CFrame.new(x, -0.42 + c * x * x, hz - 0.01) * CFrame.Angles(0, 0, math.atan(2 * c * x)), "#8a0c1e")
	end
	Rig.add(R, H, "Teeth", Vector3.new(0.52, 0.09, 0.04), CFrame.new(0, -0.37, hz - 0.005), "#f4efe0")
	for _, y in ipairs({ 0.62, 0.52 }) do
		Rig.add(R, H, "Wrinkle", Vector3.new(0.6, 0.025, 0.03), CFrame.new(0, y + 0.04, hz - 0.005), "#c9a890")
	end
	-- седые кудри
	local curls = {
		{ 0, 0.85, 0.05, 0.85 }, { -0.55, 0.7, 0.05, 0.62 }, { 0.55, 0.7, 0.05, 0.62 }, { -0.75, 0.3, 0.15, 0.56 },
		{ 0.75, 0.3, 0.15, 0.56 }, { 0, 0.6, 0.55, 0.78 }, { -0.45, 0.85, 0.4, 0.56 }, { 0.45, 0.85, 0.4, 0.56 },
		{ -0.7, -0.05, 0.35, 0.5 }, { 0.7, -0.05, 0.35, 0.5 }, { 0, 0.2, 0.75, 0.72 }, { -0.3, 0.95, -0.35, 0.46 },
		{ 0.3, 0.95, -0.35, 0.46 }, { 0, 1.05, -0.15, 0.5 },
	}
	for i, q in ipairs(curls) do
		Rig.ball(R, H, "Curl", q[4], CFrame.new(q[1], q[2], q[3]), (i % 2 == 0) and "#a9a9a2" or "#c9c9c2", FAB)
	end
	bike(R)
	Rig.finish(R)
	return R.model
end

---------------------------------------------------------------- поведение (сервер)
local function door(inm)
	return inm.mem.gl.door
end

local function park(inm)
	local G = inm.mem.gl
	if G.parked then return end
	G.parked = true
	for _, p in ipairs(inm.model:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("Bike") then
			local w = p:FindFirstChild("Weld")
			if w then w:Destroy() end
			p.Anchored = true
			p:SetAttribute("Fixed", true)
		end
	end
end

local function startChase(inm, p, lock, text)
	local G = inm.mem.gl
	G.lock = os.clock() + (lock or 0)
	park(inm)
	inm:startChase(p)
	if text then inm:say(text, SAY, true) end
end

-- кто-то открыл (или выбил) входную дверь — врывается к ближайшему к двери
local function rush(inm)
	local G = inm.mem.gl
	local d = door(inm)
	local at = d and d:FindFirstChild("In") and d.In.Position or inm:pos()
	local best = nil
	for _, p in ipairs(inm:players()) do
		if not p.hidden then
			local dd = (p.pos - at).Magnitude
			if not best or dd < best.d then best = { p = p, d = dd } end
		end
	end
	G.rushed = true
	park(inm)
	if best then
		startChase(inm, best.p, 9, OPENED)
	else
		inm:say(OPENED, SAY, true)
		inm.entry = d
		inm.mem.enter = nil
		inm:setState("enter")
	end
end

local function seenOutside(inm)
	local best = nil
	for _, p in ipairs(inm:players()) do
		if not p.hidden and not inm:indoors(p.pos) and inm:canSee(p, { sight = 50 }) then
			if not best or p.dist < best.dist then best = p end
		end
	end
	return best
end

local function anyLit(inm)
	for _, L in ipairs(inm.H.lamps) do
		if L.light.Parent and L.light.Enabled then return true end
	end
	return false
end

local function porch(inm, dt)
	local G = inm.mem.gl
	local d = door(inm)
	if d and d:FindFirstChild("In") then inm:face(d.In.Position) end
	inm:stop()
	inm:setAnim("porch")
	if G.t >= G.next and G.t < PORCH_T - 5 then
		G.k = G.k + 1
		local ev = SEQ[(G.k - 1) % #SEQ + 1]
		G.next = G.t + 2.6 + math.random() * 1.8
		local panel = d and d:FindFirstChild("Leaf") and d.Leaf:FindFirstChild("Panel")
		if ev == "bell" then
			inm:setAnim("bell", 1.1)
			inm:sound("BikeBell", inm.root, { Volume = 0.8 })
		elseif ev == "knock" then
			inm:setAnim("knock", 1.1)
			for i = 0, 2 do
				task.delay(i * 0.28, function()
					if not inm.gone then inm:sound("DoorBash", panel or inm.root, { Volume = 0.35, PlaybackSpeed = 1.6 }) end
				end)
			end
		elseif ev == "laugh" then
			inm:setAnim("laugh", 1.4)
			inm:sound("Laugh", inm.root, { Volume = 0.9 }, "Whisper")
		else
			local text = PLEAS[(G.pi % #PLEAS) + 1]
			G.pi = G.pi + 1
			if not G.litSaid and G.k > 3 and inm.match.power ~= false and anyLit(inm) then
				G.litSaid = true
				text = PLEA_LIT
			end
			inm:say(text, SAY, true)
			G.next = G.next + 1.6
		end
	end
	if G.t > PORCH_T - 4 and not G.fin then
		G.fin = true
		inm:say(PLEA_FINAL, SAY, true)
		inm:setAnim("laugh", 1.8)
		inm:sound("Laugh", inm.root, { Volume = 1 }, "Whisper")
	end
	if G.t > PORCH_T then
		park(inm)
		inm.entry = inm:pickEntry("Window", inm:pos())
		inm.mem.enter = nil
		inm:setState("toWin")
	end
end

-- цикл света внутри: зелёный → предупреждение → КРАСНЫЙ 4 с → зелёный
local function cycle(inm, dt)
	local G = inm.mem.gl
	if G.ph == 0 then
		if inm:indoors() then
			G.ph, G.cyc, G.green = 1, 0, FIRST_RED
			inm:attr("Phase", 1)
			inm:sound("Laugh", inm.root, { Volume = 1 }, "Whisper")
		end
		return
	end
	G.cyc = G.cyc + dt
	local ph = G.ph
	if ph == 1 and G.cyc > G.green - WARN then ph = 2 end
	if ph == 2 and G.cyc > G.green then
		ph = 3
		G.cyc = 0
	end
	if ph == 3 and G.cyc > RED_DUR then
		ph = 1
		G.cyc = 0
		G.green = RED_EVERY
	end
	if ph ~= G.ph then
		G.ph = ph
		inm:attr("Phase", ph)
	end
end

local function inside(inm, dt)
	local G = inm.mem.gl
	local now = os.clock()
	cycle(inm, dt)
	local red = G.ph == 3
	if red and G.cyc > RED_GRACE then
		local best = nil
		for _, p in ipairs(inm:players()) do
			if not p.hidden and p.speed > 1.5 and inm:canSee(p, { wide = true, dark = 45 }) then
				if not best or p.dist < best.dist then best = p end
			end
		end
		if best and not (inm.state == "chase" and inm.target == best.plr) then
			local cur = inm.state == "chase" and inm.target and inm:find(inm.target)
			if not cur or cur.hidden or cur.dist > best.dist then
				startChase(inm, best, 2, SPOTTED[math.random(#SPOTTED)])
			end
		end
	elseif inm.state ~= "chase" then
		for _, p in ipairs(inm:players()) do
			if not p.hidden then
				local close = (p.speed > 1.5 and p.dist < 19) or p.dist < 8
				if close and inm:canSee(p, { sight = 20, near = 8 }) then
					startChase(inm, p, 0, nil)
					break
				end
				if inm.state ~= "search" and inm:hears(p) then inm:investigate(p.feet) end
			end
		end
	end
	if inm.state == "chase" then
		if now < G.lock and inm.target then
			local p = inm:find(inm.target)
			if p and not p.hidden then
				inm.lastSeenT = now
				inm.lastKnown = p.feet
			end
		end
		inm:chase(dt, { chase = V_CHASE * ((now < G.lock) and 1.08 or 1), pulls = false, lose = 5 })
	elseif red then
		inm:stop()
		inm:setAnim("redlook")
		local look = inm.root.CFrame.LookVector
		local a = dt * 1.2
		local nx = look.X * math.cos(a) - look.Z * math.sin(a)
		local nz = look.X * math.sin(a) + look.Z * math.cos(a)
		inm:face(inm:pos() + Vector3.new(nx, 0, nz))
	elseif inm.state == "search" then
		inm:search(dt, { speed = V_ROAM })
	elseif inm.state == "inspect" then
		inm:inspect(dt, {})
	else
		inm:setState("roam")
		inm:roam(dt, { speed = V_ROAM })
	end
	for _, p in ipairs(inm:players()) do
		if not p.hidden and p.flat < 3.6 then
			inm:tryAttack(p)
			break
		end
	end
end

Gladys.server = {
	spawn = function(inm)
		local d = inm:frontDoor()
		inm.mem.gl = { t = 0, k = 0, pi = 0, next = 0.5, ph = 0, cyc = 0, green = FIRST_RED, lock = 0, door = d }
		inm:attr("Phase", 0)
		if d then
			inm:setState("arrive")
		else
			park(inm)
			inm:setState("enter")
		end
	end,
	tick = function(inm, dt)
		local G = inm.mem.gl
		G.t = G.t + dt
		local S = inm.state
		if S == "arrive" or S == "porch" or S == "toWin" then
			local d = door(inm)
			if d and (d:GetAttribute("Open") == true or d:GetAttribute("Broken") == true) and not G.rushed then
				rush(inm)
				return
			end
			local o = seenOutside(inm)
			if o then
				startChase(inm, o, 2, "КТО ЭТО ТУТ ГУЛЯЕТ ПО НОЧАМ?..")
				return
			end
			if S == "arrive" then
				inm:setAnim("bike")
				local r = inm:goTo(d.Out.Position, 8, { near = 2.2 })
				if r == "arrived" or inm:since() > 40 then
					inm:setState("porch")
					G.t, G.next = 0, 0.4
				end
			elseif S == "porch" then
				porch(inm, dt)
			else
				local m = inm.mem.enter
				if m and m.phase == "break" and not G.brSaid then
					G.brSaid = true
					inm:say("ХИ-ХИ… БАБУЛЯ УЖЕ ИДЁТ!", SAY, true)
					inm:sound("Laugh", inm.root, { Volume = 1 }, "Whisper")
				end
				if inm:enter(dt, { speed = V_ROAM }) then inm:setState("roam") end
			end
			return
		end
		if S == "enter" then
			if inm:enter(dt, { speed = V_ROAM }) then inm:setState("roam") end
			cycle(inm, dt)
			return
		end
		inside(inm, dt)
	end,
}

---------------------------------------------------------------- анимация и свет (клиент)
local function houseOf(model)
	local houses = workspace:FindFirstChild("Houses")
	return houses and houses:FindFirstChild("House_" .. tostring(model:GetAttribute("MatchId")))
end

-- перекрасить лампы дома (только у себя); col = nil — вернуть как было
local function tint(A, model, col)
	local D = A.data
	if D.col == col then return end
	D.col = col
	D.saved = D.saved or {}
	if col then
		local house = houseOf(model)
		local lf = house and house:FindFirstChild("Lights", true)
		if not lf then return end
		for _, d in ipairs(lf:GetDescendants()) do
			if d:IsA("Light") then
				if not D.saved[d] then D.saved[d] = d.Color end
				d.Color = col
			elseif d:IsA("BasePart") and d:GetAttribute("Glow") then
				if not D.saved[d] then D.saved[d] = d.Color end
				d.Color = col
			end
		end
	else
		for inst, c in pairs(D.saved) do
			if inst.Parent then inst.Color = c end
		end
		D.saved = {}
	end
end

local function overlay(A, k)
	local D = A.data
	if k <= 0 and not D.gui then return end
	if not D.gui then
		local pl = Players.LocalPlayer
		local pg = pl and pl:FindFirstChild("PlayerGui")
		if not pg then return end
		local g = Instance.new("ScreenGui")
		g.Name = "GladysRed"
		g.IgnoreGuiInset = true
		g.ResetOnSpawn = false
		g.DisplayOrder = 3
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = Color3.fromRGB(255, 10, 10)
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.Parent = g
		g.Parent = pg
		D.gui, D.frame = g, f
	end
	D.frame.BackgroundTransparency = 1 - 0.16 * k
end

function Gladys.animate(model, dt, t, ctx)
	local A = Rig.state(model)
	local D = A.data
	-- фаза света: только у игроков этого матча
	local ph = model:GetAttribute("Phase") or 0
	local pl = Players.LocalPlayer
	if not pl or pl:GetAttribute("MatchId") ~= model:GetAttribute("MatchId") or A.anim == "dead" then ph = 0 end
	local col = nil
	if ph == 1 then col = GREEN end
	if ph == 2 then col = (math.floor(t * 9) % 2 == 0) and RED or GREEN end
	if ph == 3 then col = RED end
	tint(A, model, col)
	overlay(A, (ph == 3) and 1 or ((ph == 2) and 0.4 or 0))
	if ph ~= (D.ph or 0) then
		if ph == 3 and ctx then
			if ctx.UI then pcall(ctx.UI.flash, RED, 0.55, 0.5) end
			if ctx.Sound then pcall(ctx.Sound.play, "Stinger", nil, { Volume = 0.45, PlaybackSpeed = 0.75 }) end
		elseif ph == 2 and ctx and ctx.Sound then
			pcall(ctx.Sound.play, "Static", nil, { Volume = 0.3 })
		end
		D.ph = ph
	end
	-- поза
	Rig.begin(A)
	local anim = Rig.basic(A, { walkRef = 9, walk = { leg = 0.5, arm = 0.3, bob = 0.14, sway = 0.1 } })
	local mv = math.clamp(A.speed / 9, 0, 1.2)
	-- переваливается с ноги на ногу, голова клонится
	Rig.rot(A, "Root", 0, 0, math.sin(A.phase) * 0.07 * mv)
	Rig.rot(A, "Neck", 0, 0, math.sin(t * 1.6) * 0.1)
	if anim == "bike" or anim == "porch" or anim == "bell" or anim == "knock" then
		Rig.rot(A, "RightShoulder", 0.55, 0, 0.05)
		Rig.rot(A, "RightElbow", 0.35, 0, 0)
	end
	if anim == "chase" then
		Rig.rot(A, "Root", -0.18, 0, 0)
		Rig.rot(A, "LeftShoulder", 1.45, 0, 0.12)
		Rig.rot(A, "RightShoulder", 1.45, 0, -0.12)
		Rig.rot(A, "Neck", 0.15, 0, math.sin(t * 9) * 0.14)
		Rig.twitch(A, 0.5, { "Neck", "LeftWrist", "RightWrist" }, 0.5)
	elseif anim == "porch" then
		Rig.rot(A, "Neck", 0, 0, 0.25 + math.sin(t * 1.2) * 0.1)
		Rig.rot(A, "LeftShoulder", 0.2, 0, 0.1)
	elseif anim == "knock" then
		local k = math.abs(math.sin(A.animT * 10))
		Rig.rot(A, "LeftShoulder", 1.6 - k * 0.3, 0, 0.25)
		Rig.rot(A, "LeftElbow", 0.5 + k * 0.6, 0, 0)
		Rig.rot(A, "Neck", 0.05, 0, 0.15)
	elseif anim == "laugh" then
		Rig.rot(A, "Neck", 0.45 + math.sin(t * 22) * 0.06, 0, math.sin(t * 11) * 0.1)
		Rig.move(A, "Root", 0, math.abs(math.sin(t * 22)) * 0.08, 0)
		Rig.rot(A, "LeftShoulder", 0.9, 0, 0.5)
		Rig.rot(A, "LeftElbow", 1.4, 0, 0)
	elseif anim == "bell" then
		Rig.rot(A, "RightWrist", 0, 0, math.sin(t * 30) * 0.25)
		Rig.rot(A, "Neck", -0.1, 0, 0.2)
	elseif anim == "redlook" then
		Rig.rot(A, "Neck", -0.05, math.sin(t * 1.8) * 0.9, 0)
		Rig.rot(A, "LeftShoulder", 0.15, 0, -0.1)
		Rig.rot(A, "RightShoulder", 0.15, 0, 0.1)
	end
	Rig.apply(A)
	-- глаза: тлеют, в красной фазе — алые
	if ph == 3 or anim == "chase" then
		Rig.glow(A, 1.2, RED)
	else
		Rig.glow(A, 0.6 + math.sin(t * 2) * 0.15)
	end
end

function Gladys.cleanup(model, ctx)
	local A = Rig.state(model)
	tint(A, model, nil)
	if A.data.gui then
		A.data.gui:Destroy()
		A.data.gui = nil
	end
end

return Gladys
