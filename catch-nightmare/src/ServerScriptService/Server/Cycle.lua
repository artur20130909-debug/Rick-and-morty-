-- Смена дня и ночи, события ночи (Кровавая луна, Глитч-ночь, Туман), удача сервера.
-- Состояние лежит в атрибутах ReplicatedStorage.State: Phase, PhaseEnds, Night, Event, ServerLuck, LuckEnds.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Cycle = {}
local S
local state
local forced = nil -- { phase = "day"|"night", event = key|nil }
local rng = Random.new()

local function now() return workspace:GetServerTimeNow() end

function Cycle.announce(text, color)
	Net.event("Announce"):FireAllClients(text, color)
end

function Cycle.isNight() return state:GetAttribute("Phase") == "night" end
function Cycle.event() return state:GetAttribute("Event") or "" end

-- удача: событие ночи × удача сервера (товар за Robux)
function Cycle.luck()
	local l = 1
	local e = Config.EventIndex[Cycle.event()]
	if e and Cycle.isNight() then l = l * e.luck end
	if (state:GetAttribute("LuckEnds") or 0) > now() then l = l * (state:GetAttribute("ServerLuck") or 1) end
	return l
end

function Cycle.addServerLuck(minutes, who)
	local t = math.max(now(), state:GetAttribute("LuckEnds") or 0) + minutes * 60
	state:SetAttribute("LuckEnds", t)
	state:SetAttribute("ServerLuck", 2)
	Cycle.announce(string.format("🍀 %s включил УДАЧУ ×2 для всего сервера на %d мин!", who, minutes), Color3.fromRGB(110, 255, 120))
end

-- фонарик на голове ночью
function Cycle.applyLight(char)
	local head = char and char:FindFirstChild("Head")
	if not head then return end
	local l = head:FindFirstChild("NightLight")
	if Cycle.isNight() then
		if not l then
			l = Instance.new("PointLight")
			l.Name = "NightLight"
			l.Range = 22
			l.Brightness = 1.1
			l.Color = Color3.fromRGB(190, 210, 255)
			l.Shadows = false
			l.Parent = head
		end
	elseif l then
		l:Destroy()
	end
end

local function lightsAll()
	for _, pl in ipairs(Players:GetPlayers()) do Cycle.applyLight(pl.Character) end
end

local function rollEvent()
	local x = rng:NextNumber(0, 100)
	local acc = 0
	for _, e in ipairs(Config.Events) do
		acc = acc + e.weight
		if x < acc then return e.key end
	end
	return ""
end

local function startDay()
	state:SetAttribute("Phase", "day")
	state:SetAttribute("Event", "")
	state:SetAttribute("PhaseEnds", now() + Config.DaySeconds)
	Cycle.announce("☀ Наступил день. Редкие монстры спрятались — время строить базу!", Color3.fromRGB(255, 230, 140))
	if S.Wild then S.Wild.onDay() end
	lightsAll()
end

local function startNight(event)
	local n = (state:GetAttribute("Night") or 0) + 1
	state:SetAttribute("Night", n)
	event = event or rollEvent()
	state:SetAttribute("Phase", "night")
	state:SetAttribute("Event", event)
	state:SetAttribute("PhaseEnds", now() + Config.NightSeconds)
	local e = Config.EventIndex[event]
	if e then
		Cycle.announce(string.format("🌙 НОЧЬ %d — %s: %s!", n, e.name, e.text), e.color)
	else
		Cycle.announce(string.format("🌙 НОЧЬ %d. Кошмары вышли на охоту...", n), Color3.fromRGB(150, 170, 255))
	end
	if S.Wild then S.Wild.onNight() end
	lightsAll()
end

-- админ: сразу переключить фазу
function Cycle.force(phase, event)
	forced = { phase = phase, event = event }
end

function Cycle.init(s)
	S = s
	state = RS:FindFirstChild("State")
	if not state then
		state = Instance.new("Folder")
		state.Name = "State"
		state.Parent = RS
	end
	state:SetAttribute("Night", 0)
	state:SetAttribute("ServerLuck", 1)
	state:SetAttribute("LuckEnds", 0)
	startDay()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(function()
				if forced then
					local f = forced
					forced = nil
					if f.phase == "night" then startNight(f.event) else startDay() end
				elseif now() >= (state:GetAttribute("PhaseEnds") or 0) then
					if Cycle.isNight() then startDay() else startNight() end
				end
				if (state:GetAttribute("ServerLuck") or 1) ~= 1 and (state:GetAttribute("LuckEnds") or 0) <= now() then
					state:SetAttribute("ServerLuck", 1)
					Cycle.announce("🍀 Удача сервера закончилась", Color3.fromRGB(200, 200, 200))
				end
			end)
			if not ok then warn("[CN] Cycle: " .. tostring(err)) end
		end
	end)
end

Cycle.now = now
return Cycle
