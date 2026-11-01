-- Пиксельный мир «внутри телефона» (только у этого игрока): зал появления, длинный тёмный
-- коридор из кубиков, мигающие лампы, летающие пиксели, пиксельные картинки на стенах,
-- конечный зал, где Рик открывает портал. Плюс пиксельные руки Морти перед камерой.
local RunService = game:GetService("RunService")

local PixelWorld = {}
PixelWorld.__index = PixelWorld
local B, U, Audio, Config

PixelWorld.ORIGIN = Vector3.new(400, 300, 0)

function PixelWorld.init(ctx)
	B, U, Audio, Config = ctx.Build, ctx.Util, ctx.Audio, ctx.Config
end

-- рисунок из кубиков: rows — строки сверху вниз, символ → цвет из pal
local function sprite(parent, cf, rows, pal, px)
	for r, row in ipairs(rows) do
		for c = 1, #row do
			local ch = row:sub(c, c)
			local col = pal[ch]
			if col then
				B.part(parent, "Px", Vector3.new(px, px, px * 0.6), cf * CFrame.new((c - (#row + 1) / 2) * px, -(r - (#rows + 1) / 2) * px, 0), col,
					Enum.Material.Neon, { CastShadow = false, CanQuery = false })
			end
		end
	end
end

function PixelWorld.new()
	local self = setmetatable({}, PixelWorld)
	local O = PixelWorld.ORIGIN
	local m = Instance.new("Model")
	m.Name = "RM_PixelWorld"
	self.model = m
	self.lamps = {}
	self.floaters = {}
	local function L(x, y, z) return CFrame.new(O + Vector3.new(x, y, z)) end
	local DARK, DARK2 = "#1B1230", "#271A44"
	local WALL = "#130C24"

	-- пол «шахматкой»
	local function floorArea(x0, x1, z0, z1, tile)
		local nx, nz = math.floor((x1 - x0) / tile + 0.5), math.floor((z1 - z0) / tile + 0.5)
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				local col = ((i + j) % 2 == 0) and DARK or DARK2
				B.part(m, "Tile", Vector3.new(tile, 1, tile), L(x0 + (i + 0.5) * tile, -0.5, z0 + (j + 0.5) * tile), col)
			end
		end
	end
	floorArea(-10, 10, 0, 20, 5)       -- зал появления
	floorArea(-5, 5, 20, 120, 5)       -- коридор
	floorArea(-10, 10, 120, 140, 5)    -- конечный зал

	-- стены, потолок
	local function wall(x0, x1, z0, z1, h)
		B.part(m, "Wall", Vector3.new(math.max(x1 - x0, 1), h, math.max(z1 - z0, 1)), L((x0 + x1) / 2, h / 2, (z0 + z1) / 2), WALL)
	end
	-- зал появления (z 0..20)
	wall(-11, 11, -1, 0, 14); wall(-11, -10, 0, 20, 14); wall(10, 11, 0, 20, 14)
	wall(-11, -5, 20, 21, 14); wall(5, 11, 20, 21, 14)
	B.part(m, "Ceil", Vector3.new(22, 1, 22), L(0, 14.5, 10), WALL)
	-- коридор (z 20..120)
	wall(-6, -5, 20, 120, 12); wall(5, 6, 20, 120, 12)
	B.part(m, "Ceil", Vector3.new(12, 1, 100), L(0, 12.5, 70), WALL)
	-- конечный зал (z 120..140)
	wall(-11, -5, 119, 120, 14); wall(5, 11, 119, 120, 14)
	wall(-11, -10, 120, 140, 14); wall(10, 11, 120, 140, 14); wall(-11, 11, 140, 141, 14)
	B.part(m, "Ceil", Vector3.new(22, 1, 22), L(0, 14.5, 130), WALL)

	-- неоновые линии вдоль пола и потолка коридора
	for _, x in ipairs({ -4.9, 4.9 }) do
		B.part(m, "NeonFloor", Vector3.new(0.2, 0.2, 100), L(x, 0.15, 70), "#29E6FF", Enum.Material.Neon, { CastShadow = false })
		B.part(m, "NeonCeil", Vector3.new(0.2, 0.2, 100), L(x, 11.85, 70), "#FF3DD1", Enum.Material.Neon, { CastShadow = false })
	end
	-- «кирпичики»-пиксели на стенах коридора
	local rnd = Random.new(42)
	for z = 22, 118, 3 do
		for _, side in ipairs({ -1, 1 }) do
			if rnd:NextNumber() < 0.55 then
				local y = rnd:NextInteger(1, 10)
				local col = ({ "#2E1E55", "#3A2470", "#1F3A66", "#40205C" })[rnd:NextInteger(1, 4)]
				B.part(m, "Brick", Vector3.new(0.3, 1, 2), L(side * 4.85, y + 0.5, z), col, nil, { CanQuery = false })
			end
		end
	end
	-- лампы (мигают)
	for k, z in ipairs({ 30, 50, 70, 90, 110 }) do
		local side = (k % 2 == 0) and 1 or -1
		local lamp = B.part(m, "Lamp", Vector3.new(0.6, 1, 1), L(side * 4.6, 8, z), (k % 2 == 0) and "#29E6FF" or "#FFD23D", Enum.Material.Neon, { CastShadow = false })
		local l = B.light(lamp, "PointLight", { Color = lamp.Color, Brightness = 1.4, Range = 20, Shadows = true })
		table.insert(self.lamps, { part = lamp, light = l, color = lamp.Color, seed = k })
	end
	-- свет в зале появления и в конце
	local top = B.part(m, "Glow", Vector3.new(2, 0.3, 2), L(0, 14, 10), "#B98CFF", Enum.Material.Neon, { CastShadow = false })
	B.light(top, "PointLight", { Color = Color3.fromRGB(170, 120, 255), Brightness = 1.6, Range = 26, Shadows = true })

	-- пиксельные картинки на стенах зала появления
	local pal = { R = "#FF3B5C", W = "#FFFFFF", Y = "#FFD23D", O = "#FF9A2E", G = "#7CFF4A", C = "#29E6FF" }
	sprite(m, L(-9.6, 8, 7) * CFrame.Angles(0, math.rad(90), 0), {
		".RR.RR.", "RRWRRRR", "RRRRRRR", ".RRRRR.", "..RRR..", "...R...",
	}, pal, 0.55)
	sprite(m, L(9.6, 8, 13) * CFrame.Angles(0, math.rad(-90), 0), {
		"..YYY..", ".YOOOY.", "YOYYYOY", "YOYYYOY", "YOYYYOY", ".YOOOY.", "..YYY..",
	}, pal, 0.55)
	sprite(m, L(0, 9, 0.4) * CFrame.Angles(0, math.rad(180), 0), {
		"...G...", "..GGG..", ".GGGGG.", "...G...", "...G...",
	}, pal, 0.5)
	-- надпись «ЗАГРУЗКА МИРА…»
	local sign = B.part(m, "Sign", Vector3.new(12, 2.2, 0.2), L(0, 11.5, 0.2), "#0B0716", nil, { CastShadow = false })
	local _, label = B.sign(sign, Enum.NormalId.Back, "ЗАГРУЗКА МИРА… 99%", { TextColor3 = Color3.fromRGB(124, 255, 74), Font = Enum.Font.Arcade },
		{ LightInfluence = 0, Brightness = 2 })
	self.signLabel = label
	-- указатель вперёд в начале коридора
	sprite(m, L(0, 9, 20.6) * CFrame.Angles(0, math.rad(180), 0), {
		"..C..", ".CCC.", "CCCCC", "..C..", "..C..",
	}, pal, 0.45)

	-- летающие пиксели
	for i = 1, 36 do
		local p = B.part(m, "Floater", Vector3.new(0.35, 0.35, 0.35), L(rnd:NextNumber(-4, 4), rnd:NextNumber(1, 10), rnd:NextNumber(2, 135)),
			({ "#7CFF4A", "#29E6FF", "#FF3DD1", "#FFD23D" })[rnd:NextInteger(1, 4)], Enum.Material.Neon,
			{ CanCollide = false, CanQuery = false, CastShadow = false })
		table.insert(self.floaters, { p = p, base = p.Position, ph = rnd:NextNumber(0, 6.28) })
	end

	-- метки (в мировых координатах)
	self.spawn = CFrame.lookAt(O + Vector3.new(0, 3, 6), O + Vector3.new(0, 3, 30))
	self.ambushZ = O.Z + 74
	self.rickSpot = O + Vector3.new(0, 0, 112)
	self.portalCF = CFrame.lookAt(O + Vector3.new(0, 6, 128), O + Vector3.new(0, 6, 60))
	self.t = 0
	self.flicker = 0.15
	m.Parent = workspace
	self.conn = RunService.RenderStepped:Connect(function(dt) self:update(dt) end)
	return self
end

function PixelWorld:update(dt)
	if U.paused then return end
	self.t = self.t + dt
	for _, f in ipairs(self.floaters) do
		f.p.CFrame = CFrame.new(f.base + Vector3.new(math.sin(self.t * 0.7 + f.ph) * 0.6, math.sin(self.t + f.ph) * 0.8, 0))
			* CFrame.Angles(self.t + f.ph, self.t * 0.6, 0)
	end
	for _, l in ipairs(self.lamps) do
		local on = math.noise(self.t * 4, l.seed) > -self.flicker * 3 + 0.1 or self.flicker < 0.05
		if self.flicker > 0.9 then on = math.random() < 0.5 end
		l.light.Enabled = on
		l.part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	end
	if self.signLabel then
		self.signLabel.Text = (math.floor(self.t * 2) % 7 == 0) and "З̷АГ̷Р̷УЗКА М̷ИРА… 9̷9%" or "ЗАГРУЗКА МИРА… 99%"
	end
end

-- 0 — лампы горят ровно, 1 — сильно мигают
function PixelWorld:setFlicker(v) self.flicker = v end
function PixelWorld:lampsColor(c)
	for _, l in ipairs(self.lamps) do
		l.light.Color = c or l.color
		l.part.Color = c or l.color
	end
end

function PixelWorld:destroy()
	if self.conn then self.conn:Disconnect() end
	if self.model then self.model:Destroy() end
end

---------------------------------------------------------------------------
-- пиксельные руки Морти перед камерой
---------------------------------------------------------------------------
local Hands = {}
Hands.__index = Hands

function PixelWorld.hands()
	local self = setmetatable({}, Hands)
	local m = Instance.new("Model")
	m.Name = "RM_PixelHands"
	self.model = m
	self.cubes = {}
	self.t = 0
	self.raise = 0
	self.goal = 1
	local px = 0.052
	local SKIN = Config.Colors.Skin
	local SKIN2 = Color3.fromRGB(222, 176, 140)
	local SHIRT = Config.Colors.MortyShirt
	local SHIRT2 = Color3.fromRGB(205, 168, 34)
	-- рисунок руки (ладонь к камере), снизу рукав
	local rows = {
		".f.f.f.f..",
		".f.f.f.f..",
		".f.f.f.f..",
		"pppppppp..",
		"pppppppptt",
		"pppppppptt",
		"pppppppp..",
		".pppppp...",
		"ssssssss..",
		"ssssssss..",
	}
	for _, side in ipairs({ -1, 1 }) do
		for r, row in ipairs(rows) do
			for c = 1, #row do
				local ch = row:sub(c, c)
				if ch ~= "." then
					local cc = (side == 1) and c or (#row + 1 - c)
					local col
					if ch == "s" then col = (r == 9) and SHIRT2 or SHIRT
					elseif ch == "t" then col = SKIN2
					else col = ((c + r) % 5 == 0) and SKIN2 or SKIN end
					local p = B.part(m, "Px", Vector3.new(px, px, px), CFrame.new(), col, nil,
						{ CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
					table.insert(self.cubes, { p = p, side = side, x = (cc - 5.5) * px, y = -(r - 5.5) * px, finger = ch == "f", col = c })
				end
			end
		end
	end
	m.Parent = workspace.CurrentCamera
	self.bind = "RM_PixelHands" .. tostring(math.random(1, 1e6))
	RunService:BindToRenderStep(self.bind, Enum.RenderPriority.Camera.Value + 6, function(dt) self:update(dt) end)
	return self
end

function Hands:update(dt)
	if not U.paused then self.t = self.t + dt end
	self.raise = self.raise + (self.goal - self.raise) * math.min(1, dt * 3)
	local cam = workspace.CurrentCamera.CFrame
	local lift = (1 - self.raise) * -0.9
	for _, c in ipairs(self.cubes) do
		local s = c.side
		local base = cam * CFrame.new(s * 0.36, -0.24 + lift + math.sin(self.t * 1.3 + s) * 0.015, -1.05)
			* CFrame.Angles(math.rad(8), s * math.rad(-14) + math.sin(self.t * 0.8) * 0.12 * s, s * math.rad(-8))
		local wig = c.finger and math.sin(self.t * 6 + c.col) * 0.03 or 0
		c.p.CFrame = base * CFrame.new(c.x, c.y, wig)
	end
end

function Hands:lower() self.goal = 0 end

function Hands:destroy()
	RunService:UnbindFromRenderStep(self.bind)
	self.model:Destroy()
end

return PixelWorld
