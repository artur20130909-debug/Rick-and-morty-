-- Осада: режимы «Выживание» (волны, от пули до ядерки и лазера) и «Полигон» (стреляешь сам).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Weapons = require(Shared.Weapons)
local Net = require(Shared.Net)

local Plots = require(script.Parent.Plots)
local Building = require(script.Parent.Building)
local Data = require(script.Parent.Data)
local Specials = require(script.Parent.Specials)
local Projectiles = require(script.Parent.Projectiles)
local Attacks = require(script.Parent.Attacks)

local Siege = {}

type Plot = Plots.Plot

export type State = {
	mode: string,
	plot: Plot,
	player: Player,
	difficulty: number,
	diff: any,
	ctx: Attacks.Ctx,
	snapshot: string,
	wave: number,
	cleared: number,
	gold: number,
	blocksLost: number,
	startTime: number,
	ended: boolean,
	newRecord: boolean,
	diedConn: RBXScriptConnection?,
	lastShot: number,
	heavyReady: number,
}

local rng = Random.new()

local function send(state: State, payload: { [string]: any })
	payload.active = not state.ended
	payload.mode = state.mode
	payload.difficulty = state.difficulty
	payload.plot = state.plot.index
	Net.event("SiegeState"):FireClient(state.player, payload)
end

local function pickWeapon(wave: number): string
	local total = 0
	local pool = {}
	for _, w in Weapons.List do
		if w.weight > 0 and w.wave <= wave then
			local weight = w.weight * ((w.wave >= wave - 1) and 1.6 or 1)
			total += weight
			table.insert(pool, { w.key, weight })
		end
	end
	local r = rng:NextNumber() * total
	for _, e in pool do
		r -= e[2]
		if r <= 0 then
			return e[1]
		end
	end
	return "Bullet"
end

-- Главное оружие волны: на волнах 1–12 — новое оружие, дальше — тяжёлая артиллерия
local function headlineFor(wave: number): string
	if wave <= #Weapons.List then
		return Weapons.List[wave].key
	end
	if wave % 4 == 0 then
		return "Nuke"
	elseif wave % 3 == 0 then
		return "Laser"
	elseif wave % 2 == 0 then
		return "Ballistic"
	end
	return "Cruise"
end

function Siege.finish(plot: Plot, reason: string)
	local state: State? = plot.siege
	if not state or state.ended then
		return
	end
	state.ended = true
	state.ctx.ended = true
	if state.diedConn then
		state.diedConn:Disconnect()
	end
	Projectiles.clearPlot(plot)
	Specials.stopShields(plot)
	local player = state.player
	if state.mode == "survival" and reason ~= "left" then
		local profile = Data.get(player)
		if profile then
			profile.Stats.Sieges = (profile.Stats.Sieges or 0) + 1
		end
		Net.event("SiegeResult"):FireClient(player, {
			waves = state.cleared,
			gold = state.gold,
			blocksLost = state.blocksLost,
			time = os.clock() - state.startTime,
			best = profile and profile.BestWave or 0,
			record = state.newRecord,
			reason = reason,
			difficulty = state.difficulty,
		})
		task.spawn(Data.save, player)
	end
	if reason ~= "left" then
		send(state, { phase = "ended" })
	end
	plot.model:SetAttribute("Siege", nil)
	local snapshot = state.snapshot
	task.delay((reason == "left") and 0 or 3, function()
		if plot.siege == state then
			plot.siege = nil
		end
		if reason ~= "left" and plot.owner == player then
			Building.restore(plot, snapshot)
			Building.notify(player, "Постройка восстановлена", "info")
		end
	end)
end

local function runSurvival(state: State)
	local ctx = state.ctx
	local plot = state.plot
	for i = Config.Siege.CountdownTime, 1, -1 do
		if state.ended then
			return
		end
		send(state, { phase = "countdown", n = i })
		task.wait(1)
	end
	local outside = 0
	while not state.ended do
		state.wave += 1
		local wave = state.wave
		local headline = headlineFor(wave)
		local duration = 18 + math.min(wave, 15) * 1.4
		if headline == "Nuke" then
			duration = math.max(duration, 20)
		elseif headline == "Laser" then
			duration = math.max(duration, 16)
		end
		ctx.mul = state.diff.damage * (1 + math.max(0, wave - #Weapons.List) * 0.06)
		send(state, {
			phase = "wave", wave = wave, duration = duration, headline = headline,
			newWeapon = (wave <= #Weapons.List) and Weapons.List[wave].key or nil,
		})
		Attacks.fire(ctx, headline)
		local waveEnd = os.clock() + duration
		local interval = math.max(0.75, 3.1 - wave * 0.13) / state.diff.rate
		local nextAttack = os.clock() + 1.5
		local heavy = Weapons.ByKey[headline].heavy
		while os.clock() < waveEnd and not state.ended do
			if os.clock() >= nextAttack then
				Attacks.fire(ctx, pickWeapon(wave))
				nextAttack = os.clock() + interval * rng:NextNumber(0.7, 1.3) * (heavy and 1.5 or 1)
			end
			-- игрок убежал с острова?
			local _, _, root = Plots.ownerCharacter(plot)
			if root and not Plots.isOnIsland(plot, root.Position, 92) then
				outside += 0.1
				if outside >= Config.Siege.LeavePlotGrace then
					Siege.finish(plot, "fled")
					return
				end
				if math.abs(outside - 0.1) < 0.01 then
					Building.notify(state.player, "Вернись на свой остров, иначе осада закончится!", "warning")
				end
			else
				outside = 0
			end
			task.wait(0.1)
		end
		if state.ended then
			return
		end
		-- волна пережита
		state.cleared = wave
		local reward = math.floor(Config.GoldPerWave * wave * state.diff.gold + 0.5)
		state.gold += reward
		Data.addGold(state.player, reward)
		local profile = Data.get(state.player)
		if profile then
			profile.Stats.Waves = (profile.Stats.Waves or 0) + 1
			if wave > profile.BestWave then
				profile.BestWave = wave
				state.newRecord = true
				Data.sync(state.player)
			end
		end
		send(state, { phase = "cleared", wave = wave, reward = reward })
		task.wait(Config.Siege.BreakBetweenWaves)
	end
end

function Siege.start(player: Player, mode: any, difficulty: any): (boolean, string?)
	local plot = Plots.of(player)
	if not plot then
		return false, "У тебя нет участка"
	end
	if plot.siege then
		return false, "Осада уже идёт"
	end
	if plot.launched then
		return false, "Сначала останови испытание"
	end
	if mode ~= "survival" and mode ~= "range" then
		return false, nil
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (char and hum and root and hum.Health > 0) then
		return false, "Подожди, пока персонаж появится"
	end
	if not Plots.isOnIsland(plot, root.Position, 90) then
		char:PivotTo(plot.spawn.CFrame + Vector3.new(0, 4, 0))
	end
	local di = math.clamp(math.floor(tonumber(difficulty) or 2), 1, #Config.Difficulties)
	if mode == "range" then
		di = 2
	end
	local diff = Config.Difficulties[di]
	local state: State = {
		mode = mode,
		plot = plot,
		player = player,
		difficulty = di,
		diff = diff,
		ctx = { plot = plot, player = player, mul = diff.damage, ended = false, nukes = 0 },
		snapshot = Building.serialize(plot),
		wave = 0,
		cleared = 0,
		gold = 0,
		blocksLost = 0,
		startTime = os.clock(),
		ended = false,
		newRecord = false,
		diedConn = nil,
		lastShot = 0,
		heavyReady = 0,
	}
	plot.siege = state
	plot.model:SetAttribute("Siege", mode)
	Specials.startShields(plot)
	if mode == "survival" then
		state.diedConn = hum.Died:Connect(function()
			Siege.finish(plot, "died")
		end)
		task.spawn(runSurvival, state)
	else
		send(state, { phase = "range" })
	end
	return true, nil
end

function Siege.stop(player: Player): (boolean, string?)
	local plot = Plots.of(player)
	if not plot or not plot.siege then
		return false, nil
	end
	Siege.finish(plot, "stop")
	return true, nil
end

-- Полигон: выстрел выбранным оружием (aim — точка на участке или nil = по игроку)
function Siege.fireRange(player: Player, key: any, aim: any): (boolean, string?)
	local plot = Plots.of(player)
	local state: State? = plot and plot.siege
	if not plot or not state or state.mode ~= "range" or state.ended then
		return false, "Сначала включи полигон"
	end
	local w = typeof(key) == "string" and Weapons.ByKey[key]
	if not w then
		return false, nil
	end
	local now = os.clock()
	if now - state.lastShot < Config.Siege.RangeCooldown then
		return false, nil
	end
	if w.heavy and now < state.heavyReady then
		return false, string.format("Перезарядка тяжёлого оружия: %.0f с", state.heavyReady - now)
	end
	if typeof(aim) ~= "Vector3" or not Plots.isOnIsland(plot, aim, 90) then
		aim = nil
	end
	state.lastShot = now
	if w.heavy then
		state.heavyReady = now + Config.Siege.RangeHeavyCooldown
	end
	Attacks.fire(state.ctx, w.key, aim)
	return true, nil
end

-- Полигон: вернуть постройку как была до начала
function Siege.restore(player: Player): (boolean, string?)
	local plot = Plots.of(player)
	local state: State? = plot and plot.siege
	if not plot or not state or state.mode ~= "range" or state.ended then
		return false, nil
	end
	Projectiles.clearPlot(plot)
	Building.restore(plot, state.snapshot)
	Specials.startShields(plot)
	return true, "Постройка восстановлена"
end

-- Что сохранить, если игрок выходит посреди осады (не руины, а целую постройку)
function Siege.snapshotOf(plot: Plot): string?
	local state: State? = plot.siege
	return state and state.snapshot or nil
end

return Siege
