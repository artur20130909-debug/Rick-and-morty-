-- Действия бойца: M1-серия, блок, рывок, приёмы 1–4, пробуждение.
-- Игроки присылают их через Remotes.Action, боты вызывают напрямую.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Characters = require(Shared.Characters)
local Fighters = require(script.Parent.Fighters)
local Combat = require(script.Parent.Combat)
local Hitbox = require(script.Parent.Hitbox)
local Kit = require(script.Parent.Kit)
local Net = require(script.Parent.Net)

local Actions = {}
Actions.Moves = {} -- charId -> { MoveId = function(Kit, f, aim, def, slot) }

-- настройки M1 с учётом персонажа
local m1Cache = {}
function Actions.m1Config(charId)
	local c = m1Cache[charId]
	if c then return c end
	c = {}
	for k, v in pairs(Config.M1) do c[k] = v end
	local def = Characters.get(charId)
	if def.M1 then for k, v in pairs(def.M1) do c[k] = v end end
	m1Cache[charId] = c
	return c
end

local M1_FX = { fists = "punch", flame = "fire", zap = "zap", claws = "shadow", palms = "void", sword = "slash" }

---------------------------------------------------------------- M1
function Actions.m1(f, aim, jumpHeld)
	local now = Util.now()
	if not Fighters.canAct(f, now) then return false end
	if now < f.m1CdEnd then return false end
	local cfg = Actions.m1Config(f.charId)
	if now - f.m1Last < cfg.Interval then return false end
	if now - f.m1Last > cfg.ComboWindow then f.m1Index = 0 end
	f.m1Index = f.m1Index + 1
	f.m1Last = now
	local idx = f.m1Index
	local finisher = idx >= cfg.Count
	local variant = "n"
	if finisher then
		if f.hum.FloorMaterial == Enum.Material.Air then variant = "down"
		elseif jumpHeld then variant = "up" end
		f.m1CdEnd = now + cfg.EndLag
		f.m1Index = 0
	end
	local dir = Kit.dir(f, aim)
	if not f.player then Kit.face(f, dir) end
	Fighters.busy(f, cfg.BusyTime * (finisher and 1.7 or 1), cfg.BusySpeed, not finisher)
	local style = f.def.M1Style
	Net.fxExcept(f.player, "M1", { m = f.model, i = idx, v = variant, st = style })
	local tok = f.moveToken
	task.delay(cfg.Windup * (finisher and 1.5 or 1), function()
		if not Fighters.alive(f) or f.ragdolled or Util.now() < f.stunEnd or f.moveToken ~= tok then return end
		local d = Kit.dir(f, { dir = dir })
		local pos = f.root.Position + d * cfg.Reach
		local cf = CFrame.lookAt(pos, pos + d)
		local list = Hitbox.box(cf, cfg.HitboxSize, { [f] = true })
		local fx = M1_FX[style] or "punch"
		local any = false
		for _, t in ipairs(list) do
			local info = {
				damage = finisher and cfg.FinisherDamage or cfg.Damage,
				stun = finisher and 0.95 or cfg.Stun,
				m1 = true, fx = fx, heavy = finisher, pos = t.root.Position - d * 1.2,
			}
			if finisher then
				local away = Combat.away(f, t)
				info.blockCost = 2
				if variant == "up" then
					info.knockback = away * 8 + Vector3.new(0, cfg.UppercutUp, 0)
					info.ragdoll = 1.35
					info.kbTime = 0.2
				elseif variant == "down" then
					info.knockback = away * 10 + Vector3.new(0, -cfg.DownslamDown, 0)
					info.ragdoll = 1.2
					info.kbTime = 0.15
				else
					info.knockback = away * cfg.Knockback + Vector3.new(0, cfg.KnockUp, 0)
					info.ragdoll = cfg.Ragdoll
					info.kbTime = 0.2
				end
				info.shake = 0.6
				info.hitstop = 0.07
			else
				info.knockback = Combat.away(f, t) * 5
				info.kbTime = 0.08
				info.hitstop = 0.03
			end
			local r = Combat.hit(f, t, info)
			if r == "hit" or r == "killed" then any = true end
		end
		-- шаг вперёд, чтобы серия не «распадалась»
		if any and not finisher and Fighters.alive(f) then
			Kit.setVel(f, d * 9)
			task.delay(0.08, function()
				if Fighters.alive(f) and f.moveToken == tok then Kit.stopVel(f) end
			end)
		end
		if finisher and variant == "down" and any then
			Net.fx("Impact", { p = Util.ground(pos), r = 7, k = "dust" })
		end
	end)
	return true
end

---------------------------------------------------------------- блок
function Actions.block(f, on)
	local now = Util.now()
	if on then
		if not Fighters.alive(f) or f.ragdolled or now < f.stunEnd or now < f.rootEnd or now < f.busyEnd or now < f.blockLockEnd then
			return false
		end
		if f.blockReleased and now - f.blockReleased < Config.Block.Cooldown then return false end
		if not f.blocking then
			f.blocking = true
			f.blockStart = now
		end
		return true
	end
	if f.blocking then
		f.blocking = false
		f.blockReleased = now
	end
	return true
end

---------------------------------------------------------------- рывок
local DASH_CD = { F = "FrontCooldown", B = "BackCooldown", L = "SideCooldown", R = "SideCooldown" }
function Actions.dash(f, key, vec)
	local now = Util.now()
	if not Fighters.alive(f) or f.ragdolled or now < f.stunEnd or now < f.rootEnd then return false end
	if now < f.busyEnd or f.blocking then return false end
	if not DASH_CD[key] then key = "F" end
	if now < f.dashCd[key] then return false end
	f.dashCd[key] = now + Config.Dash[DASH_CD[key]]
	if key == "L" or key == "R" then f.evadeEnd = now + Config.Dash.EvadeTime end
	if not f.player then
		-- боты: двигает сервер
		local look = f.root.CFrame.LookVector
		local right = f.root.CFrame.RightVector
		local d = (key == "B" and -look) or (key == "L" and -right) or (key == "R" and right) or look
		if typeof(vec) == "Vector3" and vec.Magnitude > 0.1 then d = vec end
		d = Util.flat(d, look)
		local root = f.root
		local att = root:FindFirstChild("DashAtt") or Instance.new("Attachment")
		att.Name = "DashAtt"
		att.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Name = "DashVel"
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.MaxForce = 1e7
		lv.VectorVelocity = d * Config.Dash.Speed
		lv.Parent = root
		task.delay(Config.Dash.Time, function() lv:Destroy() end)
	end
	Net.fxExcept(f.player, "Dash", { m = f.model, d = key })
	return true
end

---------------------------------------------------------------- приёмы
function Actions.move(f, slot, aim)
	local now = Util.now()
	if type(slot) ~= "number" or slot < 1 or slot > 4 or slot ~= math.floor(slot) then return false end
	-- повторное нажатие (Резонанс, выход из тени)
	local rc = f.recast
	if rc and rc.slot == slot then
		f.recast = nil
		if now <= rc.untilT and now >= (rc.fromT or 0) then
			task.spawn(rc.cb, Kit.cleanAim(aim))
			return true
		end
		if now < (rc.fromT or 0) then
			-- поспешил: окно ещё не открылось
			if rc.miss then task.spawn(rc.miss) end
			return true
		end
	end
	if not Fighters.canAct(f, now) then return false end
	if now < f.silenceEnd then
		Net.to(f.player, "Notify", { text = "Внутри чужой территории приёмы не работают!", kind = "bad" })
		return false
	end
	if now < f.cds[slot] then return false end
	local def = Characters.moveset(f.charId, f.awakened)[slot]
	if not def then return false end
	if def.Ultimate and f.ultUsed then return false end
	local mod = Actions.Moves[f.charId]
	local fn = mod and mod[def.Id]
	if not fn then
		warn("[Actions] нет приёма " .. tostring(def.Id))
		return false
	end
	if def.Ultimate then
		f.ultUsed = true
		f.cds[slot] = f.awakenEnd
	else
		f.cds[slot] = now + def.Cooldown
	end
	Net.to(f.player, "CD", { slot = slot, t = f.cds[slot], d = def.Ultimate and (f.awakenEnd - now) or def.Cooldown })
	aim = Kit.cleanAim(aim)
	if not f.player then Kit.face(f, Kit.dir(f, aim)) end
	task.spawn(function()
		local ok, err = pcall(fn, Kit, f, aim, def, slot)
		if not ok then
			warn("[Moves] " .. def.Id .. ": " .. tostring(err))
			if Fighters.alive(f) then Combat.cancelMove(f) end
		end
	end)
	return true
end

function Actions.awaken(f)
	return Combat.awaken(f)
end

---------------------------------------------------------------- приём от игроков
local rate = {}
function Actions.init(Spawner, Bots)
	Net.Action.OnServerEvent:Connect(function(player, kind, a, b)
		if type(kind) ~= "string" then return end
		-- защита от спама
		local t = os.clock()
		local r = rate[player]
		if not r or t - r.t > 1 then
			r = { t = t, n = 0 }
			rate[player] = r
		end
		r.n = r.n + 1
		if r.n > 40 then return end
		if kind == "Select" then
			Spawner.select(player, a)
			return
		elseif kind == "Bots" then
			if Bots then Bots.configure(a, b) end
			return
		elseif kind == "Respawn" then
			Spawner.respawn(player)
			return
		end
		local f = Fighters.ofPlayer(player)
		if not f then return end
		if kind == "M1" then
			Actions.m1(f, Kit.cleanAim(a), b == true)
		elseif kind == "Block" then
			Actions.block(f, a == true)
		elseif kind == "Dash" then
			Actions.dash(f, type(a) == "string" and a or "F", typeof(b) == "Vector3" and b or nil)
		elseif kind == "Move" then
			Actions.move(f, a, b)
		elseif kind == "Awaken" then
			Actions.awaken(f)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(p) rate[p] = nil end)
end

-- общий цикл бойцов
RunService.Heartbeat:Connect(function(dt)
	Fighters.step(dt)
end)

return Actions
