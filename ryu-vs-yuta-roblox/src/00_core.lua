--[[
	РЮ vs ЮТА — фан-анимация по «Магической битве» для Roblox
	Четыре части подряд (11 + 15 + 16 + 17 с). Тайминг совпадает с клипами кадр в кадр.

	КАК ЗАПУСТИТЬ
	  • Открой RyuVsYuta.rbxlx в Roblox Studio и нажми Play (F5).
	    Или вставь весь этот код в LocalScript: StarterPlayer → StarterPlayerScripts.
	  • Поставь графику на максимум (10): так неон, контуры и частицы выглядят лучше всего.
	  • Включи запись экрана и нажми ПРОБЕЛ: все части идут подряд без остановок.
	    Клавиши 1, 2, 3, 4 — отдельная часть. R — повторить.

	Этот файл собирается из папки src командой: python3 build_place.py
]]

local CONFIG = {
	PART = 0, -- 0: все части подряд; 1, 2, 3 или 4: только эта часть
	DUMMY_MODE = false, -- true: Рю и Юта — серые манекены без одежды
	OUTLINES = true, -- чёрный аниме-контур
	AUTO_START = false, -- true: начать сразу после загрузки
	SUBTITLES = "en", -- "en": английские субтитры как в клипе, "ru": русские, false: без субтитров
	-- свет: если в Studio слишком темно, подними AMBIENT (например 1.0); если пересвечено — опусти
	AMBIENT = 0.92, -- сила рассеянного света
	AMBIENT_WHITE = 0.6, -- насколько рассеянный свет белый (0 — цвет из кадра, 1 — чисто белый)
	SUN = 0.14, -- доля солнца: больше — сильнее объём, но синий пол уходит в бирюзу
	EXPOSURE = 0, -- общая экспозиция
}

-- Тайминг части 1, секунды
local T1 = {
	GLOW = 4.30, -- глаза засвечивает
	WHITE = 4.83, -- белая вспышка
	CLASH = 5.40, -- столкновение лучей
	TEAL = 6.98, -- бирюзовая волна
	CITY = 7.83, -- общий план города
	YUTA = 8.70, -- Юта и Рика
	RYU = 10.00, -- удар по Рю
	FIN = 11.17,
}

-- Тайминг части 2, секунды
local T2 = {
	LAUGH = 3.20, -- Рю смеётся
	ZOOM = 7.90, -- радужный рывок
	IMPACT1 = 8.55, -- чёрный кадр удара
	BURST = 8.65, -- жёлтый взрыв
	BLUR = 9.00, -- смаз с силуэтом Юты
	YUTARIKA = 9.20, -- Юта и Рика
	YUTACLOSE = 9.55, -- Юта крупно, рука Рики
	WHITE = 10.15, -- белая вспышка
	IMPACT2 = 10.30, -- чёрный кадр удара
	MIST = 10.40, -- белые полосы
	WIDE = 10.75, -- кратер в тумане
	LOW = 13.03, -- Рю снизу
	FIN = 15.39,
}

-- Тайминг части 3, секунды
local T3 = {
	RIGHT = 2.40, -- «That's right!»
	GOING = 4.00, -- «Let's keep going!»
	SMOKE = 6.40, -- дым и розовая точка вдали
	BLAST = 6.70, -- розовый луч сквозь обломки
	RUN = 7.20, -- Юта бежит
	TOP = 7.75, -- вид сверху на кратер
	REACH = 9.40, -- Рю тянет руку к Юте
	BUT = 12.50, -- «But...»
	BOOM = 13.90, -- жёлто-розовый взрыв
	WEAK = 14.80, -- «its force is weak!»
	FIN = 15.97,
}

-- Тайминг части 4, секунды
local T4 = {
	MIST = 0.73, -- Юта бежит сквозь туман и розовые искры
	YUTA = 1.73, -- Юта крупно на бегу
	LEAP = 6.23, -- из-за спины Юты: прыжок к Рю
	CHARGE = 7.33, -- Рю снизу, из причёски бьют голубые молнии
	FACE = 9.00, -- лицо Рю в осколках энергии
	SETTLE = 10.60, -- «I'll settle this.»: смех
	BURST = 12.70, -- энергия вспыхивает, тёмный смаз
	POSE = 13.67, -- «Granite Blast!»: руки в стороны
	FLASH = 15.47, -- чёрный кадр со звездой, белая вспышка
	TOP = 15.80, -- сверху: голубой залп из причёски
	SIDE = 16.30, -- Рю сбоку, залп уходит вперёд
	SWEEP = 16.45, -- залп сносит обломки
	FIN = 17.10,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local V3, CF, ANG, RGB = Vector3.new, CFrame.new, CFrame.Angles, Color3.fromRGB
local rad, sin, cos, abs, sqrt, floor = math.rad, math.sin, math.cos, math.abs, math.sqrt, math.floor
local rng = Random.new(20261031)

local function clamp01(x)
	if x < 0 then
		return 0
	elseif x > 1 then
		return 1
	end
	return x
end
local function lerp(a, b, t)
	return a + (b - a) * t
end
local function smooth(t)
	t = clamp01(t)
	return t * t * (3 - 2 * t)
end
local function easeOut(t)
	t = clamp01(t)
	return 1 - (1 - t) * (1 - t) * (1 - t)
end
local function easeIn(t)
	t = clamp01(t)
	return t * t
end
local function rr(a, b)
	return rng:NextNumber(a, b)
end
local function pick(list)
	return list[rng:NextInteger(1, #list)]
end
local function noise(x, y)
	return math.noise(x, y) * 2
end
local function randUnit()
	local v = V3(rr(-1, 1), rr(-1, 1), rr(-1, 1))
	if v.Magnitude < 0.05 then
		return V3(0, 1, 0)
	end
	return v.Unit
end
-- NumberSequence из пар {время, значение}
local function NS(list)
	local k = {}
	for i, p in ipairs(list) do
		k[i] = NumberSequenceKeypoint.new(p[1], p[2])
	end
	return NumberSequence.new(k)
end
-- ColorSequence из пар {время, цвет}
local function CS(list)
	local k = {}
	for i, p in ipairs(list) do
		k[i] = ColorSequenceKeypoint.new(p[1], p[2])
	end
	return ColorSequence.new(k)
end

local C = {
	white = RGB(255, 255, 255),
	black = RGB(0, 0, 0),
	ink = RGB(14, 12, 18),
	pink = RGB(255, 60, 185),
	pinkHot = RGB(255, 135, 225),
	magenta = RGB(205, 45, 175),
	cyan = RGB(60, 225, 255),
	cyanDeep = RGB(30, 140, 255),
	blue = RGB(40, 90, 255),
	teal = RGB(70, 230, 205),
	yellow = RGB(255, 236, 140),
	gold = RGB(255, 205, 80),
	orange = RGB(255, 150, 60),
	red = RGB(205, 55, 40),
	rock = RGB(46, 52, 52),
	blood = RGB(160, 14, 28),
	skinYuta = RGB(247, 222, 202),
	skinRyu = RGB(232, 196, 162),
	hairYuta = RGB(26, 38, 46),
	hairRyu = RGB(16, 16, 22),
	rika = RGB(242, 242, 248),
	rikaTail = RGB(22, 22, 30),
	gum = RGB(130, 28, 42),
	mouth = RGB(42, 6, 16),
	tooth = RGB(252, 250, 244),
}

-- камера и время ролика (общие для всех кадров)
local camCF, camFOV, shake = CF(0, 2000, 0), 70, 0
local songT = 0
