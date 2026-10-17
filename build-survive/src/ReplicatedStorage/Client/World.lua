-- Мир на клиенте: настройки графики, музыка (спокойная при стройке, боевая при осаде),
-- шум ветра, мигание огней на вражеских базах, «живые» охранники на участках.
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sounds = require(Shared.Sounds)
local Blocks = require(Shared.Blocks)
local BlockFactory = require(Shared.BlockFactory)
local Net = require(Shared.Net)

local Client = script.Parent
local State = require(Client.State)
local SoundPlayer = require(Client.SoundPlayer)
local CameraShake = require(Client.CameraShake)
local Fx = require(Client.Fx)

local World = {}

function World.applySettings()
	local s = State.settings
	SoundPlayer.setVolumes(s.Sfx or 1, (s.Music or 0.5) * 0.9)
	CameraShake.enabled = s.CameraShake ~= false
	Fx.applyQuality()
end

local function updateMusic()
	if State.inSiege() then
		SoundPlayer.playlist(Sounds.SiegePlaylist)
	else
		SoundPlayer.playlist(Sounds.BuildPlaylist)
	end
end

-- ОХРАННИКИ ------------------------------------------------------------------------
-- Фигуру охранника строит BlockFactory; здесь она оживает: дышит, медленно осматривается,
-- покачивает опущенным автоматом, а по событию GuardShot вскидывает автомат к цели и стреляет.
-- Двигаются только C0 сварок фигуры и только на этом клиенте. Анимируются лишь охранники
-- рядом с камерой и в кадре — все в одном цикле.
local ITEM_GUARD = Blocks.ItemByKey.Guard.id
local GUARD_VIEW = 180 -- дальше этого охранники стоят неподвижно
local GUARD_HOLD = 1.2 -- сколько секунд держит цель после выстрела
local GUARD_RAISE, GUARD_LOWER = 9, 2.2 -- скорость: вскинуть автомат / опустить (доля в секунду)
local GUARD_TURN = 14 -- как быстро доворачивается к цели

type GuardAnim = {
	block: BasePart,
	rig: BlockFactory.GuardRig?,
	retryAt: number, -- детали фигуры ещё не пришли: когда искать их снова
	phase: number, -- сдвиг фаз, чтобы охранники не двигались хором
	aim: number, -- 0 — автомат опущен, 1 — у плеча
	yaw: number,
	pitch: number,
	target: Vector3?,
	holdUntil: number,
	kicks: { number }, -- моменты выстрелов очереди (отдача)
	recoil: number,
	resting: boolean, -- стоит в позе покоя
	pose: BlockFactory.GuardPose,
}

local guards: { [Instance]: GuardAnim } = {}
local guardRng = Random.new()
local REST_POSE: BlockFactory.GuardPose = { yaw = 0, pitch = 0, aim = 0 }

local function wrapAngle(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

local function trackGuard(b: Instance)
	if guards[b] or not b:IsA("BasePart") or b:GetAttribute("Item") ~= ITEM_GUARD then
		return
	end
	guards[b] = {
		block = b,
		rig = nil,
		retryAt = 0,
		phase = guardRng:NextNumber(0, 100),
		aim = 0,
		yaw = 0,
		pitch = 0,
		target = nil,
		holdUntil = 0,
		kicks = {},
		recoil = 0,
		resting = true,
		pose = { yaw = 0, pitch = 0, aim = 0 },
	}
end

local function watchPlot(model: Instance)
	local blocks = model:WaitForChild("Blocks", 30)
	if not blocks then
		return
	end
	blocks.ChildAdded:Connect(trackGuard)
	blocks.ChildRemoved:Connect(function(b: Instance)
		guards[b] = nil
	end)
	for _, b in blocks:GetChildren() do
		trackGuard(b)
	end
end

-- Сервер: охранник g выстрелил из точки from в точку to
local function onGuardShot(d: any)
	if typeof(d) ~= "table" or typeof(d.from) ~= "Vector3" or typeof(d.to) ~= "Vector3" then
		return
	end
	local to: Vector3 = d.to
	Fx.guardShot(d.from, to)
	local g = if typeof(d.g) == "Instance" then guards[d.g] else nil
	if not g then
		return
	end
	local now = os.clock()
	if g.aim < 0.05 then
		-- автомат был опущен: сразу разворачивается к цели, а не от прошлой
		g.yaw, g.pitch = BlockFactory.guardAim(g.block.CFrame, to)
	end
	g.target = to
	g.holdUntil = now + GUARD_HOLD
	for i = 0, Fx.GuardRounds - 1 do
		table.insert(g.kicks, now + i * Fx.GuardRoundTime)
	end
end

-- Охранник в кадре (с запасом по краям), а не за спиной камеры
local function onScreen(cam: Camera, pos: Vector3): boolean
	local p = cam:WorldToViewportPoint(pos)
	local size = cam.ViewportSize
	return p.Z > 0 and p.X > -size.X * 0.2 and p.X < size.X * 1.2 and p.Y > -size.Y * 0.2 and p.Y < size.Y * 1.2
end

local function updateGuards(dt: number)
	if next(guards) == nil then
		return
	end
	local cam = workspace.CurrentCamera
	local camPos = cam.CFrame.Position
	local now = os.clock()
	for _, g in guards do
		local block = g.block
		local aiming = now < g.holdUntil or g.aim > 0
		if (block.Position - camPos).Magnitude > GUARD_VIEW then
			-- далеко: встаёт в покой и больше не трогается, пока не подойдёшь
			if not g.resting and g.rig then
				BlockFactory.poseGuard(g.rig, REST_POSE)
			end
			g.resting = true
			g.aim, g.recoil, g.holdUntil, g.target = 0, 0, 0, nil
			table.clear(g.kicks)
			continue
		end
		if not aiming and not onScreen(cam, block.Position) then
			continue
		end
		local rig = g.rig
		if not rig then
			if now < g.retryAt then
				continue
			end
			rig = BlockFactory.guardRig(block)
			g.rig = rig
			g.retryAt = now + 1
			if not rig then
				continue
			end
		end

		-- вскинуть автомат, пока держит цель; потом медленно опустить
		if now < g.holdUntil then
			g.aim = math.min(1, g.aim + dt * GUARD_RAISE)
		else
			g.aim = math.max(0, g.aim - dt * GUARD_LOWER)
		end
		local target = g.target
		if target then
			local yaw, pitch = BlockFactory.guardAim(block.CFrame, target)
			local k = math.min(1, dt * GUARD_TURN)
			g.yaw = wrapAngle(g.yaw + wrapAngle(yaw - g.yaw) * k)
			g.pitch += (pitch - g.pitch) * k
			if g.aim <= 0 then
				g.target = nil
			end
		end
		-- отдача: каждый выстрел очереди толкает автомат к плечу
		while g.kicks[1] and g.kicks[1] <= now do
			table.remove(g.kicks, 1)
			g.recoil = 1
		end
		g.recoil = math.max(0, g.recoil - dt * 9)

		-- дыхание, осмотр по сторонам и покачивание автомата: медленные синусы со своей фазой
		local t = now + g.phase
		local a = g.aim
		local pose = g.pose
		pose.yaw = g.yaw
		pose.pitch = g.pitch
		pose.aim = a * a * (3 - 2 * a)
		pose.breath = math.sin(t * 1.7)
		pose.headYaw = math.sin(t * 0.31) * 0.55 + math.sin(t * 0.87) * 0.12
		pose.headPitch = math.sin(t * 0.53) * 0.05 - 0.04
		pose.sway = Vector3.new(math.sin(t * 1.13) * 0.025, math.sin(t * 0.71) * 0.035, math.sin(t * 0.93) * 0.02)
		pose.recoil = g.recoil
		BlockFactory.poseGuard(rig, pose)
		g.resting = false
	end
end

local function initGuards()
	Net.event("GuardShot").OnClientEvent:Connect(onGuardShot)
	task.spawn(function()
		local plots = workspace:WaitForChild("Plots")
		for _, model in plots:GetChildren() do
			task.spawn(watchPlot, model)
		end
	end)
end

function World.init()
	World.applySettings()
	updateMusic()
	SoundPlayer.play("Wind", { loop = true })
	State.changed:Connect(function(key)
		if key == "settings" then
			World.applySettings()
		elseif key == "siege" then
			updateMusic()
		end
	end)
	initGuards()
	-- красные огни на антеннах вражеских баз мигают
	local lights = {}
	local map = workspace:WaitForChild("Map", 10)
	local forts = map and map:FindFirstChild("EnemyForts")
	if forts then
		for _, d in forts:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "AntennaLight" then
				table.insert(lights, d)
			end
		end
	end
	RunService.Heartbeat:Connect(function(dt: number)
		local on = math.floor(os.clock() * 1.25) % 2 == 0
		for _, l in lights do
			l.Transparency = on and 0 or 0.85
			local pl = l:FindFirstChildOfClass("PointLight")
			if pl then
				pl.Enabled = on
			end
		end
		updateGuards(dt)
	end)
end

return World
