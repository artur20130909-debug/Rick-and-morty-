-- Эффекты по событиям сервера (Fx): звуки, тряска камеры, вспышки, скримеры, урон,
-- монеты и яблоки (всплывающие «+$»), электричество, «тебя заметили», батарейка.
-- Тряска: небольшое смещение и крен камеры поверх всех остальных (и для обычной камеры,
-- и для Scriptable — в укрытии или в ролике), без накопления сдвига.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

local Fx = {}

local ctx, player, Sound, Net
local T = 0

---------------------------------------------------------------- помощники
local warned = {}
local function warnOnce(tag, err)
	if warned[tag] then return end
	warned[tag] = true
	warn("[AA] Fx." .. tostring(tag) .. ": " .. tostring(err))
end
local function guarded(tag, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then warnOnce(tag, err) end
	return ok
end
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end
-- вызвать функцию другого модуля через ctx; вернуть true, если она есть
local function call(modName, fnName, ...)
	local M = ctx and ctx[modName]
	if type(M) ~= "table" or type(M[fnName]) ~= "function" then return false end
	local ok, err = pcall(M[fnName], ...)
	if not ok then warnOnce(modName .. "." .. fnName, err) end
	return true
end
local function play(key, where, props)
	local ok, s = pcall(Sound.play, key, where, props)
	if not ok then
		warnOnce("sound." .. tostring(key), s)
		return nil
	end
	return s
end

---------------------------------------------------------------- тряска камеры
local shakes = {}
local last = { set = nil, off = nil }

function Fx.shake(power, seconds)
	table.insert(shakes, { p = clamp(tonumber(power) or 1, 0, 2), d = math.max(tonumber(seconds) or 0.4, 0.05), t0 = T })
end

local function shakeAmp()
	local a = 0
	for i = #shakes, 1, -1 do
		local s = shakes[i]
		local age = T - s.t0
		if age >= s.d then
			table.remove(shakes, i)
		else
			a = a + s.p * (1 - age / s.d)
		end
	end
	return math.min(a, 2.5)
end

local function shakeStep()
	local cam = workspace.CurrentCamera
	local amp = shakeAmp()
	if amp <= 0.001 then
		last.set = nil
		last.off = nil
		return
	end
	local off = Vector3.new(math.noise(T * 18, 1.3), math.noise(T * 18, 7.1), math.noise(T * 18, 3.3) * 0.5) * amp * 0.6
	local roll = math.noise(T * 11, 3.7) * amp * 0.06
	local offCF = CFrame.new(off) * CFrame.Angles(0, 0, roll)
	local base = cam.CFrame
	-- если камеру с прошлого кадра никто не двигал (неподвижный ролик) — сперва снимаем прошлый сдвиг
	if last.set and last.off and base == last.set then base = base * last.off:Inverse() end
	cam.CFrame = base * offCF
	last.set = cam.CFrame
	last.off = offCF
end

---------------------------------------------------------------- всплывающие надписи «+$»
local POP = { gui = nil, recent = {} }
local function popup(text, color)
	if not POP.gui or not POP.gui.Parent then
		local pg = player:FindFirstChildOfClass("PlayerGui")
		if not pg then return end
		local g = Instance.new("ScreenGui")
		g.Name = "AA_FxPopups"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.DisplayOrder = 6
		g.Parent = pg
		POP.gui = g
	end
	-- несколько надписей подряд — лесенкой
	local n = 0
	for i = #POP.recent, 1, -1 do
		if T - POP.recent[i] > 0.5 then
			table.remove(POP.recent, i)
		else
			n = n + 1
		end
	end
	table.insert(POP.recent, T)
	local y = 0.6 - n * 0.05
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.fromOffset(320, 44)
	l.Font = Enum.Font.GothamBlack
	l.TextSize = 30
	l.Text = text
	l.TextColor3 = color or rgb(255, 230, 120)
	l.TextStrokeTransparency = 0.35
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.Parent = POP.gui
	local ok = pcall(function()
		local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(l, info, { Position = UDim2.fromScale(0.5, y - 0.09), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(ok and 1.3 or 1, function() pcall(function() l:Destroy() end) end)
end
Fx.popup = popup

---------------------------------------------------------------- имена заключённых (для надписей)
local names = {}
local function inmateName(key)
	if type(key) ~= "string" then return nil end
	if names[key] ~= nil then return names[key] or nil end
	names[key] = false
	local folder = RS:FindFirstChild("Inmates")
	local mod = folder and folder:FindFirstChild(key)
	if mod and mod:IsA("ModuleScript") then
		local ok, def = pcall(require, mod)
		if ok and type(def) == "table" and def.name then names[key] = tostring(def.name) end
	end
	return names[key] or nil
end

---------------------------------------------------------------- обработчики видов Fx
local H = {}

H.sound = function(key, where, props)
	if type(key) ~= "string" then return end
	local w = nil
	if typeof(where) == "Vector3" or typeof(where) == "Instance" then w = where end
	play(key, w, type(props) == "table" and props or nil)
end

H.shake = function(power, seconds)
	Fx.shake(power, seconds)
end

H.jumpscare = function(key, model)
	-- ролик ведёт InmatesClient; Controls не трогает камеру это время
	call("Controls", "cinematic", 2.6)
	call("Hide", "forceExit")
	local IC = ctx.InmatesClient
	local done = false
	if type(IC) == "table" and type(IC.jumpscare) == "function" then
		local ok, err = pcall(IC.jumpscare, key, model)
		if ok then
			done = true
		else
			warnOnce("InmatesClient.jumpscare", err)
		end
	end
	if not done then
		-- запасной вариант без ролика
		play("Jumpscare", nil, { Volume = 1 })
		if not call("UI", "jumpscareOverlay", rgb(200, 0, 0), 1.2) then
			call("UI", "flash", rgb(200, 0, 0), 0, 1.2)
		end
		Fx.shake(1.6, 0.9)
	end
end

H.flash = function(color, startTr)
	if typeof(color) ~= "Color3" then color = Color3.new(1, 1, 1) end
	call("UI", "flash", color, tonumber(startTr) or 0.3, 0.5)
end

H.hurt = function(damage)
	local k = clamp((tonumber(damage) or 20) / 50, 0.2, 1)
	call("UI", "flash", rgb(200, 0, 0), 0.75 - 0.35 * k, 0.35 + 0.3 * k)
	play("Heartbeat", nil, { Volume = 0.75 })
	Fx.shake(0.4 + 0.6 * k, 0.3)
	call("World", "pulse", rgb(150, 0, 0), 0.5 + 0.3 * k, 0.9)
end

H.killed = function(key)
	-- сервер сам пишет тост с наградой; здесь — победный звук и короткая надпись
	play("Win", nil, { Volume = 0.45, PlaybackSpeed = 1.1 })
	call("UI", "flash", rgb(255, 240, 200), 0.75, 0.6)
	local name = inmateName(key)
	popup(name and (string.upper(name) .. " — ОБЕЗВРЕЖЕН") or "ОБЕЗВРЕЖЕН!", rgb(140, 255, 150))
end

H.revived = function()
	play("Heal", nil, { Volume = 0.8 })
	call("UI", "flash", Color3.new(1, 1, 1), 0.15, 1)
	popup("Ты снова жив!", rgb(200, 255, 220))
end

H.power = function(on)
	on = on and true or false
	-- World мерцает светом и сам играет звук щитка; если World нет — хотя бы звук
	if not call("World", "powerFx", on) then
		play(on and "PowerUp" or "PowerDown", nil, { Volume = 0.8 })
	end
	if not on then Fx.shake(0.15, 0.25) end
end

H.coin = function(amount)
	play("Coin", nil, { Volume = 0.6 })
	local n = tonumber(amount)
	if n and n > 0 then
		popup("+$" .. tostring(math.floor(n)), rgb(255, 214, 80))
	elseif n and n < 0 then
		-- покупка в магазине
		popup("−$" .. tostring(math.floor(-n)), rgb(255, 120, 100))
	end
end

H.apple = function(count)
	play("ApplePick", nil, { Volume = 0.6, PlaybackSpeed = 0.95 + math.random() * 0.1 })
	local n = tonumber(count) or 1
	popup("+" .. tostring(math.floor(n)) .. " 🍎", rgb(255, 120, 110))
end

H.spotted = function()
	play("Stinger", nil, { Volume = 0.85 })
	call("World", "pulse", rgb(110, 0, 0), 0.75, 1.1)
	Fx.shake(0.35, 0.4)
end

H.battery = function()
	call("Controls", "refillBattery")
	play("FlashlightClick", nil, { Volume = 0.5 })
	popup("🔋 100%", rgb(255, 236, 120))
end

-- обработать эффект локально (так же, как пришедший с сервера)
function Fx.handle(kind, a, b, c)
	local f = H[kind]
	if not f then
		warnOnce("unknown." .. tostring(kind), "неизвестный вид эффекта")
		return
	end
	guarded(tostring(kind), f, a, b, c)
end

function Fx.init(c)
	ctx = c
	player = c.player or game:GetService("Players").LocalPlayer
	Sound = c.Sound
	Net = c.Net
	task.spawn(function()
		local ok, ev = pcall(Net.event, "Fx")
		if not ok or not ev then return end
		ev.OnClientEvent:Connect(function(kind, a, b, cc)
			Fx.handle(kind, a, b, cc)
		end)
	end)
	RunService:BindToRenderStep("AA_FxShake", Enum.RenderPriority.Last.Value, function(dt)
		T = T + dt
		guarded("shake", shakeStep)
	end)
end

return Fx
