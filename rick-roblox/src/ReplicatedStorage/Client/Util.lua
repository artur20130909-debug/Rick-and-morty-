-- Общие помощники клиента: математика, сглаживание, твины, «уборщик» (Trove) и пауза.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local U = {}

function U.lerp(a, b, t) return a + (b - a) * t end
function U.clamp01(t) return math.clamp(t, 0, 1) end
function U.smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
function U.smoother(t)
	t = math.clamp(t, 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10)
end
function U.easeOutBack(t)
	local c1, c3 = 1.4, 2.4
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end
-- экспоненциальное сглаживание, не зависящее от частоты кадров
function U.damp(current, target, speed, dt)
	return current + (target - current) * (1 - math.exp(-speed * dt))
end

-- твин с удобными значениями по умолчанию; возвращает Tween
function U.tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Пауза игры: сюжетные ожидания идут только когда игра не на паузе
U.paused = false
local pauseChanged = Instance.new("BindableEvent")
U.PauseChanged = pauseChanged.Event
function U.setPaused(p)
	if U.paused == p then return end
	U.paused = p
	pauseChanged:Fire(p)
end

-- ожидание в «игровом» времени (замирает на паузе)
function U.wait(t)
	local left = t or 0
	local start = os.clock()
	while left > 0 do
		local dt = RunService.Heartbeat:Wait()
		if not U.paused then left = left - dt end
	end
	return os.clock() - start
end

-- ждать, пока cond() не вернёт true (с проверкой каждый кадр)
function U.waitUntil(cond, timeout)
	local t0 = os.clock()
	while not cond() do
		RunService.Heartbeat:Wait()
		if timeout and os.clock() - t0 > timeout then return false end
	end
	return true
end

-- Trove: собирает объекты и подключения, чтобы потом убрать всё разом
local Trove = {}
Trove.__index = Trove
function U.trove()
	return setmetatable({ items = {} }, Trove)
end
function Trove:add(x)
	table.insert(self.items, x)
	return x
end
function Trove:clean()
	local items = self.items
	self.items = {}
	for i = #items, 1, -1 do
		local x = items[i]
		local t = typeof(x)
		if t == "RBXScriptConnection" then
			x:Disconnect()
		elseif t == "Instance" then
			x:Destroy()
		elseif type(x) == "function" then
			local ok, err = pcall(x)
			if not ok then warn("[RM] уборка: " .. tostring(err)) end
		elseif type(x) == "table" and x.Destroy then
			x:Destroy()
		end
	end
end

-- простой сигнал (на BindableEvent)
function U.signal()
	local be = Instance.new("BindableEvent")
	return {
		Event = be.Event,
		Fire = function(_, ...) be:Fire(...) end,
		Connect = function(_, f) return be.Event:Connect(f) end,
		Wait = function() return be.Event:Wait() end,
		Destroy = function() be:Destroy() end,
	}
end

-- Кривая Катмулла — Рома по точкам (Vector3), t от 0 до 1
function U.catmull(points, t)
	local n = #points
	if n == 1 then return points[1] end
	local seg = (n - 1) * math.clamp(t, 0, 1)
	local i = math.min(math.floor(seg) + 1, n - 1)
	local u = seg - (i - 1)
	local p0 = points[math.max(i - 1, 1)]
	local p1 = points[i]
	local p2 = points[i + 1]
	local p3 = points[math.min(i + 2, n)]
	local u2, u3 = u * u, u * u * u
	return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u3)
end

-- заглавные буквы и для кириллицы (string.upper её не трогает)
local LOWER = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
local UPPER = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
local map = {}
do
	local lo, up = {}, {}
	for _, c in utf8.codes(LOWER) do table.insert(lo, utf8.char(c)) end
	for _, c in utf8.codes(UPPER) do table.insert(up, utf8.char(c)) end
	for i = 1, #lo do map[lo[i]] = up[i] end
end
function U.upper(s)
	local out = {}
	for _, c in utf8.codes(s) do
		local ch = utf8.char(c)
		table.insert(out, map[ch] or string.upper(ch))
	end
	return table.concat(out)
end

return U
