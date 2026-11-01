-- Гараж-лаборатория в главе 2 (меняется только у этого игрока): большой экран рисует рассказ Рика
-- (Пожиратели → карта мультивселенной → съеденные вселенные → «обнаружены в C-137» → тревога),
-- лампы мигают от взрыва, ворота гаража сворачиваются вверх, как рольставни.
-- lab:reset() возвращает всё как было (экран «ожидание», ворота закрыты).
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Lab = {}
Lab.__index = Lab
local B, U, Audio

function Lab.init(ctx)
	B, U, Audio = ctx.Build, ctx.Util, ctx.Audio
end

local MAGENTA = "#FF3DD1"
local GREEN = "#7CFF4A"
local RED = "#FF3B30"

local function tween(obj, t, props, style)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

function Lab.new()
	local self = setmetatable({}, Lab)
	local house = workspace:WaitForChild("House")
	local lab = house:WaitForChild("GarageLab")
	self.screen = lab:WaitForChild("LabScreen")
	self.gui = self.screen:WaitForChild("Display")
	self.idle = self.gui:FindFirstChild("Idle")
	self.button = lab:FindFirstChild("DoorButton")
	self.leaf = house:FindFirstChild("GarageDoorLeaf", true)
	self.tubes = {}
	local lights = house:FindFirstChild("Lights")
	if lights then
		for _, l in ipairs(lights:GetChildren()) do
			if l:GetAttribute("Room") == "Garage" then table.insert(self.tubes, l) end
		end
	end
	-- запомнить ворота (чтобы вернуть)
	self.saved = {}
	if self.leaf then
		for _, p in ipairs(self.leaf:GetChildren()) do
			if p:IsA("BasePart") then
				table.insert(self.saved, { p = p, cf = p.CFrame, size = p.Size, tr = p.Transparency, cc = p.CanCollide })
			end
		end
	end
	self.lift = 0
	return self
end

---------------------------------------------------------------------------
-- экран
---------------------------------------------------------------------------
function Lab:clear()
	if self.show then self.show:Destroy() end
	self.show = nil
	self.anim = (self.anim or 0) + 1 -- остановить прошлые анимации экрана
end

function Lab:frame(bg)
	self:clear()
	if self.idle then self.idle.Visible = false end
	local f = B.rect(self.gui, 0, 0, 1, 1, bg or "#0B1A12", { Name = "Show", ZIndex = 2 })
	self.show = f
	return f
end

-- «Пожиратели»: значок-клякса со щупальцами и подпись
function Lab:devourers()
	local f = self:frame("#14081C")
	B.text(f, 0.05, 0.05, 0.9, 0.14, "ДОСЬЕ RICK OS: ПОЖИРАТЕЛИ", "#E9D6FF", Enum.Font.Code, { ZIndex = 3 })
	local blob = B.circle(f, 0.08, 0.28, 0.22, 0.42, MAGENTA, { ZIndex = 4 })
	for i = 0, 5 do
		local arm = B.rect(f, 0.19 - 0.005, 0.49 - 0.02, 0.2, 0.04, "#B02A93", { ZIndex = 3, AnchorPoint = Vector2.new(0, 0.5), Rotation = i * 60 + 15 })
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = arm
	end
	B.circle(f, 0.14, 0.38, 0.05, 0.1, "#FFFFFF", { ZIndex = 5 })
	B.circle(f, 0.155, 0.41, 0.025, 0.05, "#14081C", { ZIndex = 6 })
	B.text(f, 0.38, 0.28, 0.58, 0.14, "межпространственные паразиты", MAGENTA, Enum.Font.Code, { ZIndex = 3, TextXAlignment = Enum.TextXAlignment.Left })
	B.text(f, 0.38, 0.46, 0.58, 0.12, "питание: МИРЫ И ВСЕЛЕННЫЕ", "#E9D6FF", Enum.Font.Code, { ZIndex = 3, TextXAlignment = Enum.TextXAlignment.Left })
	B.text(f, 0.38, 0.62, 0.58, 0.12, "угроза: ★★★★★", "#FFD23D", Enum.Font.Code, { ZIndex = 3, TextXAlignment = Enum.TextXAlignment.Left })
	local id = self.anim
	task.spawn(function()
		local t = 0
		while self.anim == id and blob.Parent do
			t = t + RunService.Heartbeat:Wait()
			local s = 1 + math.sin(t * 5) * 0.05
			blob.Size = UDim2.fromScale(0.22 * s, 0.42 * s)
		end
	end)
end

-- карта мультивселенной: кружки-вселенные с подписями; C-137 — зелёная
function Lab:multiverse()
	local f = self:frame("#071423")
	B.text(f, 0.05, 0.03, 0.9, 0.12, "КАРТА МУЛЬТИВСЕЛЕННОЙ", "#9FD8FF", Enum.Font.Code, { ZIndex = 3 })
	self.eaten = 0
	self.counter = B.text(f, 0.05, 0.87, 0.9, 0.1, "ПОГЛОЩЕНО ВСЕЛЕННЫХ: 0", MAGENTA, Enum.Font.Code, { ZIndex = 3 })
	self.worlds = {}
	local names = { "C-131", "J-19", "D-99", "C-500A", "Z-8", "K-22", "C-35", "G-1", "C-137", "P-4", "B-12", "X-6", "M-3", "F-70", "Q-9", "R-77", "S-2", "T-44" }
	local cols = { "#2CC7E0", "#6E8BFF", "#FFD23D", "#FF8A5C", "#9B5CFF", "#4FE3A1" }
	local i = 0
	for row = 0, 2 do
		for col = 0, 5 do
			i = i + 1
			local x = 0.07 + col * 0.15 + ((row % 2 == 1) and 0.05 or 0)
			local y = 0.18 + row * 0.22
			local name = names[i]
			local me = name == "C-137"
			local w = B.circle(f, x, y, 0.075, 0.144, me and GREEN or cols[(i % #cols) + 1], { ZIndex = 4 })
			local st = Instance.new("UIStroke")
			st.Color = Color3.new(1, 1, 1)
			st.Thickness = me and 3 or 1.5
			st.Parent = w
			local lbl = B.text(f, x - 0.03, y + 0.15, 0.135, 0.05, name, me and GREEN or "#CFE6FF", Enum.Font.Code, { ZIndex = 3 })
			table.insert(self.worlds, { f = w, l = lbl, me = me, x = x, y = y })
		end
	end
end

-- Пожиратели съедают вселенные одну за другой (асинхронно, n штук за dur секунд)
function Lab:eat(n, dur)
	if not self.worlds then return end
	local list = {}
	for _, w in ipairs(self.worlds) do if not w.me and not w.dead then table.insert(list, w) end end
	local id = self.anim
	local f = self.show
	task.spawn(function()
		local blob = B.circle(f, 0.5, 1.1, 0.06, 0.115, MAGENTA, { ZIndex = 6 })
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(80, 10, 60)
		st.Thickness = 2
		st.Parent = blob
		for k = 1, math.min(n, #list) do
			if self.anim ~= id then return end
			local w = table.remove(list, math.random(1, #list))
			tween(blob, dur / n * 0.6, { Position = UDim2.fromScale(w.x + 0.008, w.y + 0.015) }, Enum.EasingStyle.Sine)
			U.wait(dur / n * 0.6)
			if self.anim ~= id then return end
			w.dead = true
			tween(w.f, 0.3, { BackgroundColor3 = Color3.fromRGB(30, 22, 34), Size = UDim2.fromScale(0.045, 0.086) })
			w.l.TextColor3 = Color3.fromRGB(255, 70, 90)
			w.l.Text = "✕ " .. w.l.Text
			self.eaten = self.eaten + 1
			self.counter.Text = "ПОГЛОЩЕНО ВСЕЛЕННЫХ: " .. (self.eaten * 1000 + math.random(0, 999))
			U.wait(dur / n * 0.4)
		end
	end)
end

-- «обнаружены в C-137»: красное кольцо пульсирует вокруг нашей вселенной
function Lab:found()
	if not self.worlds then self:multiverse() end
	local me
	for _, w in ipairs(self.worlds) do if w.me then me = w end end
	local f = self.show
	local ring = B.circle(f, me.x - 0.03, me.y - 0.058, 0.135, 0.26, "#000000", { ZIndex = 5, BackgroundTransparency = 1 })
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(255, 59, 48)
	st.Thickness = 5
	st.Parent = ring
	local warn = B.text(f, 0.05, 0.87, 0.9, 0.1, "⚠ ОБНАРУЖЕНЫ В C-137 — ЭТО МЫ!", RED, Enum.Font.Code, { ZIndex = 7, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(7, 20, 35) })
	local id = self.anim
	task.spawn(function()
		local t = 0
		while self.anim == id and ring.Parent do
			t = t + RunService.Heartbeat:Wait()
			local s = 1 + (t * 1.6 % 1) * 0.5
			ring.Size = UDim2.fromScale(0.135 * s, 0.26 * s)
			ring.Position = UDim2.fromScale(me.x + 0.0375 - 0.0675 * s, me.y + 0.072 - 0.13 * s)
			st.Transparency = (t * 1.6 % 1)
			warn.TextTransparency = (math.floor(t * 3) % 2 == 0) and 0 or 0.6
		end
	end)
end

-- тревога: красный экран мигает
function Lab:alarm()
	local f = self:frame("#3A0606")
	local big = B.text(f, 0.05, 0.22, 0.9, 0.38, "ТРЕВОГА!", "#FFFFFF", Enum.Font.GothamBlack, { ZIndex = 3 })
	B.text(f, 0.05, 0.64, 0.9, 0.12, "ВЗРЫВ · СЕКТОР: УЛИЦА", "#FFD0D0", Enum.Font.Code, { ZIndex = 3 })
	local id = self.anim
	task.spawn(function()
		local on = true
		while self.anim == id and f.Parent do
			on = not on
			f.BackgroundColor3 = on and Color3.fromRGB(200, 20, 20) or Color3.fromRGB(58, 6, 6)
			big.TextColor3 = on and Color3.new(1, 1, 1) or Color3.fromRGB(255, 80, 80)
			U.wait(0.35)
		end
	end)
end

---------------------------------------------------------------------------
-- свет и ворота
---------------------------------------------------------------------------
-- лампы мигают dur секунд (взрыв), потом горят
function Lab:flicker(dur)
	task.spawn(function()
		local t = 0
		while t < dur do
			local on = math.random() > 0.45
			for _, tube in ipairs(self.tubes) do
				for _, l in ipairs(tube:GetChildren()) do
					if l:IsA("Light") then l.Enabled = on end
				end
				tube.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
			local w = 0.05 + math.random() * 0.12
			U.wait(w)
			t = t + w
		end
		for _, tube in ipairs(self.tubes) do
			for _, l in ipairs(tube:GetChildren()) do
				if l:IsA("Light") then l.Enabled = true end
			end
			tube.Material = Enum.Material.Neon
		end
	end)
end

-- ворота гаража: «рольставни» — нижний край поднимается, полотно сворачивается под потолок
local function setLift(self, lift)
	self.lift = lift
	for _, s in ipairs(self.saved) do
		local p = s.p
		if p.Name == "GarageDoor" then
			local h = math.max(0.3, s.size.Y - lift)
			local bottom = s.cf.Position.Y - s.size.Y / 2 + lift
			p.Size = Vector3.new(s.size.X, h, s.size.Z)
			p.CFrame = s.cf + Vector3.new(0, bottom + h / 2 - s.cf.Position.Y, 0)
		elseif p.Name == "HandleBar" then
			p.CFrame = s.cf + Vector3.new(0, lift, 0)
			p.Transparency = (lift > 7.4) and 1 or s.tr
		else
			-- полосы панелей «уезжают» в рулон, когда край их догоняет
			local bottom = lift
			p.Transparency = (s.cf.Position.Y < bottom + 0.15) and 1 or s.tr
			p.CanCollide = s.cc and p.Transparency < 1
		end
	end
end

function Lab:openDoor(t)
	if not self.leaf then return end
	t = t or 3
	Audio.play("GarageDoor", { at = self.button or self.screen, volume = 1, min = 8, max = 90 })
	local el = 0
	local total = 8.7
	while el < t do
		local dt = RunService.Heartbeat:Wait()
		if not U.paused then
			el = math.min(t, el + dt)
			setLift(self, total * U.smooth(el / t))
		end
	end
end

-- нажать кнопку ворот (кнопка утапливается и мигает)
function Lab:pressButton()
	local b = self.button
	if not b then return end
	Audio.play("Button", { at = b, volume = 0.9 })
	local cf = b.CFrame
	b.CFrame = cf * CFrame.new(0, 0, 0.08)
	b.Color = Color3.fromRGB(90, 255, 90)
	task.delay(0.25, function() if b.Parent then b.CFrame = cf end end)
end

function Lab:reset()
	self:clear()
	self.worlds = nil
	if self.idle then self.idle.Visible = true end
	for _, s in ipairs(self.saved) do
		s.p.CFrame = s.cf
		s.p.Size = s.size
		s.p.Transparency = s.tr
		s.p.CanCollide = s.cc
	end
	self.lift = 0
	if self.button then self.button.Color = Color3.fromRGB(210, 59, 59) end
end

return Lab
