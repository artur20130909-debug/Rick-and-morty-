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
	admin: boolean,  -- осаду запустил или ускорил админ: рекорды и статистика не засчитываются
	inWave: boolean, -- сейчас идёт волна (не отсчёт и не перерыв)
	skip: boolean,   -- админ попросил засчитать текущую волну досрочно
}

-- Админ-панель: с какой самой поздней волны можно начать выживание
Siege.MaxAdminWave = 30

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
		if profile and not state.admin then
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

-- Новый контекст атак: снаряды и лазеры, привязанные к старому, сразу прекращаются
local function renewCtx(state: State)
	local old = state.ctx
	old.ended = true
	state.ctx = { plot = state.plot, player = state.player, mul = old.mul, ended = false, nukes = old.nukes }
end

local function runSurvival(state: State)
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
		local ctx = state.ctx
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
		state.inWave = true
		Attacks.fire(ctx, headline)
		local waveEnd = os.clock() + duration
		local interval = math.max(0.75, 3.1 - wave * 0.13) / state.diff.rate
		local nextAttack = os.clock() + 1.5
		local heavy = Weapons.ByKey[headline].heavy
		while os.clock() < waveEnd and not state.ended and not state.skip do
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
		state.inWave = false
		if state.ended then
			return
		end
		if state.skip then
			-- волну пропустил админ: её снаряды и лазеры убираем, награда — как за обычную волну (один раз)
			state.skip = false
			renewCtx(state)
			Projectiles.clearPlot(plot)
		end
		-- волна пережита
		state.cleared = wave
		local reward = math.floor(Config.GoldPerWave * wave * state.diff.gold + 0.5)
		state.gold += reward
		Data.addGold(state.player, reward)
		local profile = Data.get(state.player)
		if profile and not state.admin then
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

-- Начать осаду. Аргументы уже проверены: mode — "survival" или "range", di — номер сложности,
-- startWave — с какой волны начать (обычно 1), admin — осаду запустил админ.
local function begin(player: Player, mode: string, di: number, startWave: number, admin: boolean): (boolean, string?)
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
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (char and hum and root and hum.Health > 0) then
		return false, "Подожди, пока персонаж появится"
	end
	if not Plots.isOnIsland(plot, root.Position, 90) then
		char:PivotTo(plot.spawn.CFrame + Vector3.new(0, 4, 0))
	end
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
		wave = startWave - 1,
		cleared = 0,
		gold = 0,
		blocksLost = 0,
		startTime = os.clock(),
		ended = false,
		newRecord = false,
		diedConn = nil,
		lastShot = 0,
		heavyReady = 0,
		admin = admin,
		inWave = false,
		skip = false,
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

-- Удалённый вызов StartSiege: всё, что прислал клиент, проверяется здесь.
-- Лишние аргументы клиента отбрасываются — до админских параметров begin они не доходят.
function Siege.start(player: Player, mode: any, difficulty: any): (boolean, string?)
	if mode ~= "survival" and mode ~= "range" then
		return false, nil
	end
	local d = tonumber(difficulty) or 2
	if d ~= d then
		d = 2 -- NaN
	end
	local di = math.clamp(math.floor(d), 1, #Config.Difficulties)
	return begin(player, mode, di, 1, false)
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

-- АДМИН-ПАНЕЛЬ (вызывает только сервер, модуль Admin; к удалённым вызовам не привязано) -------

-- Выживание сразу с волны wave на сложности difficulty. Рекорды в такой осаде не засчитываются.
function Siege.adminStart(player: Player, difficulty: number, wave: number): (boolean, string?)
	local di = math.clamp(math.floor(difficulty), 1, #Config.Difficulties)
	local first = math.clamp(math.floor(wave), 1, Siege.MaxAdminWave)
	return begin(player, "survival", di, first, true)
end

-- Засчитать текущую волну как пройденную. Сама волна заканчивается в runSurvival: награда — одна,
-- как за обычную волну, снаряды волны убираются, дальше идёт обычный перерыв и следующая волна.
function Siege.skipWave(player: Player): (boolean, string?)
	local plot = Plots.of(player)
	local state: State? = plot and plot.siege
	if not state or state.ended or state.mode ~= "survival" then
		return false, "Сейчас нет осады в режиме «Выживание»"
	end
	if not state.inWave then
		return false, "Волна ещё не началась — подожди пару секунд"
	end
	if state.skip then
		return false, "Волна уже заканчивается"
	end
	state.skip = true
	state.admin = true
	return true, "Волна " .. state.wave .. " засчитана"
end

-- Цели админского выстрела «по мне»: эти виды оружия сами следят за игроком
local TRACKS_PLAYER = { Homing = true, Laser = true, Nuke = true }

-- Выстрел любым оружием без перезарядки. target: "me" — по себе, "block" — по случайному блоку,
-- Vector3 — в точку на своём острове. Если осады нет — сам включает полигон.
function Siege.adminFire(player: Player, key: string, target: string | Vector3): (boolean, string?)
	local plot = Plots.of(player)
	if not plot then
		return false, "У тебя нет участка"
	end
	local w = Weapons.ByKey[key]
	if not w then
		return false, "Нет такого оружия"
	end
	local aim: Vector3? = nil
	if typeof(target) == "Vector3" then
		if not Plots.isOnIsland(plot, target, 90) then
			return false, "Цель должна быть на твоём острове"
		end
		aim = target
	elseif target == "block" then
		local list = plot.blocks:GetChildren()
		if #list == 0 then
			return false, "На участке нет ни одного блока"
		end
		aim = (list[rng:NextInteger(1, #list)] :: BasePart).Position
	elseif target ~= "me" then
		return false, "Неизвестная цель"
	end
	local state: State? = plot.siege
	if not state then
		local ok, err = begin(player, "range", 2, 1, true)
		if not ok then
			return false, err
		end
		state = plot.siege
	end
	if not state or state.ended then
		return false, "Осада заканчивается — подожди, пока постройка восстановится"
	end
	-- «по мне»: самонаводящимся целиться не нужно, остальным — в то место, где игрок стоит сейчас
	-- (полигон мог только что перенести его на участок)
	if target == "me" and not TRACKS_PLAYER[w.key] then
		local _, _, root = Plots.ownerCharacter(plot)
		if root then
			aim = root.Position
		end
	end
	Attacks.fire(state.ctx, w.key, aim)
	return true, nil
end

-- Что сохранить, если игрок выходит посреди осады (не руины, а целую постройку)
function Siege.snapshotOf(plot: Plot): string?
	local state: State? = plot.siege
	return state and state.snapshot or nil
end

return Siege
