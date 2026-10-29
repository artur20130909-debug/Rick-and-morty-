-- Обработчики эффектов от сервера (Remotes.FX): удары, блоки, приёмы, снаряды, территории.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = ReplicatedStorage:WaitForChild("Client")
local Characters = require(Shared.Characters)
local Poses = require(Shared.Poses)
local Util = require(Shared.Util)
local FX = require(Client.FX)
local Animator = require(Client.Animator)
local CameraFX = require(Client.CameraFX)
local SoundFX = require(Client.SoundFX)

local Effects = {}
local H = {}
Effects.handlers = H
Effects.ui = nil          -- ставит ClientMain: { flash = f(color, t, a), announce = f(...), killfeed = f(...), damage = f(...) }

local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)

local function myChar() return player.Character end
local function isMe(model) return model ~= nil and model == player.Character end
local function rootOf(m) return m and m:FindFirstChild("HumanoidRootPart") end
local function colorsOf(model)
	local id = model and model:GetAttribute("Char")
	local def = id and Characters.Defs[id]
	if def then return def.Color, def.Accent end
	return Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 220, 120)
end
local function ground(pos)
	return (Util.ground(pos, 30))
end

local HIT_COLORS = {
	punch = { Color3.fromRGB(255, 236, 200), Color3.fromRGB(255, 255, 255) },
	heavy = { Color3.fromRGB(255, 150, 70), Color3.fromRGB(255, 240, 200) },
	crit = { Color3.fromRGB(230, 20, 30), Color3.fromRGB(10, 0, 0) },
	crit2 = { Color3.fromRGB(255, 70, 40), Color3.fromRGB(255, 220, 120) },
	slash = { Color3.fromRGB(240, 40, 60), Color3.fromRGB(255, 255, 255) },
	slashHeavy = { Color3.fromRGB(230, 20, 50), Color3.fromRGB(255, 230, 230) },
	void = { Color3.fromRGB(92, 214, 255), Color3.fromRGB(170, 92, 255) },
	shadow = { Color3.fromRGB(128, 72, 220), Color3.fromRGB(30, 20, 50) },
	bite = { Color3.fromRGB(140, 80, 230), Color3.fromRGB(20, 10, 30) },
	fire = { Color3.fromRGB(255, 128, 28), Color3.fromRGB(255, 222, 90) },
	zap = { Color3.fromRGB(110, 196, 255), Color3.fromRGB(255, 248, 160) },
}
local HIT_SOUND = { punch = "Punch", heavy = "PunchHeavy", crit = "Resonance", crit2 = "PunchHeavy", slash = "Slash", slashHeavy = "SlashHeavy",
	void = "Punch", shadow = "Punch", bite = "Bite", fire = "Punch", zap = "Zap" }

---------------------------------------------------------------- удары
H.Hit = function(d)
	local target = d.t
	local kind = d.k or "punch"
	local cols = HIT_COLORS[kind] or HIT_COLORS.punch
	local pos = d.p or (rootOf(target) and rootOf(target).Position)
	if not pos then return end
	local heavy = d.heavy or kind == "crit" or kind == "heavy"
	FX.impact(pos, cols[1], heavy, cols[2])
	if kind == "fire" then
		FX.emit(pos, { tex = "fire", color = cols[1], color2 = cols[2], n = 10, speed = 10, life = 0.35 })
	elseif kind == "shadow" or kind == "bite" then
		FX.emit(pos, { tex = "smoke", color = Color3.fromRGB(40, 20, 60), n = 6, speed = 8, life = 0.5, light = 0 })
	elseif kind == "zap" then
		for _ = 1, 2 do FX.bolt(pos, pos + Vector3.new(Util.rand(-4, 4), Util.rand(-2, 4), Util.rand(-4, 4)), cols[1], 0.18, 0.12, cols[2]) end
	elseif kind == "slash" or kind == "slashHeavy" then
		FX.slashMark(pos, cols[1], heavy and 7 or 5, 0.22)
	end
	SoundFX.play(HIT_SOUND[kind] or "Punch", pos)
	if target then
		Animator.flinch(target, heavy)
		if d.hs then Animator.freeze(target, d.hs) end
	end
	if d.a then
		Animator.combat(d.a)
		if d.hs then Animator.freeze(d.a, d.hs) end
	end
	-- камера и интерфейс для участников
	if isMe(d.a) then
		CameraFX.shake((d.s or 0.25) * 0.8)
		if heavy then CameraFX.kick(3) end
		if Effects.ui and d.d and d.d > 0 then Effects.ui.damage(target, d.d, cols[1], d.crit) end
	elseif isMe(target) then
		CameraFX.shake(math.max(0.35, d.s or 0.35))
		if Effects.ui then Effects.ui.flash(Color3.fromRGB(200, 20, 20), 0.25, heavy and 0.35 or 0.2) end
	end
end

H.Dmg = function(d)
	if isMe(d.a) and Effects.ui and d.d and d.d >= 0.5 then
		Effects.ui.damage(d.t, d.d, Color3.fromRGB(255, 170, 90), false, true)
	end
end

H.Block = function(d)
	local t = d.t
	local root = rootOf(t)
	local pos = d.p or (root and root.Position)
	if not pos then return end
	local front = root and (root.Position + root.CFrame.LookVector * 1.6) or pos
	FX.ball(front, Color3.fromRGB(150, 210, 255), 0.6, d.heavy and 3 or 2, 0.18, 0.2)
	FX.sparks(front, Color3.fromRGB(200, 230, 255), d.heavy and 12 or 7, 40, { dir = root and root.CFrame.LookVector, spread = 0.9, size = 0.18, life = 0.15 })
	SoundFX.play("Block", pos)
	Animator.flinch(t, false)
	if isMe(t) then CameraFX.shake(0.25) end
end

H.Parry = function(d)
	local root = rootOf(d.t)
	local pos = d.p or (root and root.Position)
	if not pos then return end
	FX.ball(pos, WHITE, 1, 6, 0.3, 0)
	FX.ring(pos, Color3.fromRGB(180, 230, 255), 1, 10, 0.4, { cf = CFrame.lookAt(pos, workspace.CurrentCamera.CFrame.Position) * CFrame.Angles(math.rad(90), 0, 0), w = 0.6 })
	FX.light(pos, Color3.fromRGB(200, 240, 255), 30, 8, 0.35)
	FX.text(pos + Vector3.new(0, 3.5, 0), "ПАРИРОВАНИЕ!", Color3.fromRGB(170, 230, 255), 1)
	SoundFX.play("Parry", pos)
	if d.a then Animator.flinch(d.a, true) end
	if isMe(d.t) or isMe(d.a) then CameraFX.shake(0.6) end
end

H.GuardBreak = function(d)
	local pos = d.p or (rootOf(d.t) and rootOf(d.t).Position)
	if not pos then return end
	FX.ball(pos, Color3.fromRGB(255, 200, 120), 1, 5, 0.3, 0.1)
	FX.sparks(pos, Color3.fromRGB(150, 210, 255), 18, 50, { size = 0.3 })
	FX.text(pos + Vector3.new(0, 3.5, 0), "БЛОК ПРОБИТ", Color3.fromRGB(255, 190, 90), 0.9)
	SoundFX.play("GuardBreak", pos)
	if isMe(d.t) then CameraFX.shake(0.7) end
end

H.Evade = function(d)
	if d.t then FX.afterimage(d.t, Color3.fromRGB(200, 220, 255), 0.3) end
end

H.Death = function(d)
	local pos = d.p
	if pos then
		FX.ball(pos, Color3.fromRGB(255, 255, 255), 1, 5, 0.4, 0.3)
		FX.emit(pos, { tex = "smoke", color = Color3.fromRGB(80, 80, 90), n = 10, speed = 8, life = 1, light = 0, lightInf = 1 })
	end
	SoundFX.play("Death", d.m)
end

---------------------------------------------------------------- анимации
H.Anim = function(d)
	if not d.m then return end
	if isMe(d.m) and Animator.recentlyPlayed(d.m, d.a, 0.3) then return end
	Animator.play(d.m, d.a, d.s)
end
H.AnimStop = function(d)
	if d.m then Animator.stop(d.m) end
end

H.M1 = function(d)
	local list = Poses.M1[d.st or "fists"] or Poses.M1.fists
	local name
	if d.v == "up" then name = list[5] elseif d.v == "down" then name = list[6] else name = list[math.clamp(d.i or 1, 1, 4)] end
	if isMe(d.m) then return end
	Animator.play(d.m, name)
	Effects.swing(d.m, d.st, d.i, d.v)
end

-- след замаха M1
function Effects.swing(model, style, i, variant)
	local root = rootOf(model)
	if not root then return end
	local c1, c2 = colorsOf(model)
	local fin = (i or 1) >= 4 or variant == "up" or variant == "down"
	SoundFX.play(fin and "SwingHeavy" or (style == "sword" and "Slash" or "Swing"), root.Position, style == "sword" and 0.6 or 1)
	if style == "sword" then
		local tilt = (i == 1 and 35) or (i == 2 and 0) or (i == 3 and -60) or 80
		task.delay(0.07, function()
			if not root.Parent then return end
			FX.slash(root.CFrame * CFrame.new(0, 0.4, -1) * CFrame.Angles(0, 0, math.rad(tilt)), c1, fin and 7 or 5.5, fin and 1.3 or 0.9, 0.26, 170, WHITE)
		end)
	elseif style == "palms" then
		task.delay(0.1, function()
			if not root.Parent then return end
			local p = root.Position + root.CFrame.LookVector * 3
			FX.ring(p, c1, 0.5, fin and 5 or 3, 0.22, { cf = CFrame.lookAt(p, p + root.CFrame.LookVector) * CFrame.Angles(math.rad(90), 0, 0), w = 0.3, h = 0.15, n = 18 })
		end)
	elseif style == "claws" then
		task.delay(0.1, function()
			if not root.Parent then return end
			local p = root.Position + root.CFrame.LookVector * 3
			for k = -1, 1 do FX.slashMark(p + root.CFrame.RightVector * k * 0.5, c1, 3.5, 0.2) end
		end)
	elseif style == "flame" then
		task.delay(0.1, function()
			if not root.Parent then return end
			FX.emit(root.Position + root.CFrame.LookVector * 3, { tex = "fire", color = c1, color2 = c2, n = 8, speed = 12, life = 0.3 })
		end)
	elseif style == "zap" then
		task.delay(0.08, function()
			if not root.Parent then return end
			local p = root.Position + root.CFrame.LookVector * 3
			FX.bolt(root.Position + root.CFrame.LookVector, p, c1, 0.15, 0.1, c2)
		end)
	end
end

H.Dash = function(d)
	local m = d.m
	if not m or isMe(m) then return end
	Effects.dashFX(m, d.d)
end

function Effects.dashFX(model, key)
	Animator.play(model, "dash_" .. (key or "F"))
	local root = rootOf(model)
	if not root then return end
	local c1 = colorsOf(model)
	FX.trail(model, Color3.fromRGB(230, 230, 240):Lerp(c1, 0.3), 0.28, nil, 0.8)
	FX.emit(ground(root.Position) + Vector3.new(0, 0.5, 0), { tex = "smoke", color = Color3.fromRGB(200, 196, 190), n = 6, speed = 6, life = 0.5, light = 0, lightInf = 1,
		size = NumberSequence.new(1.2, 2.4), transp = NumberSequence.new(0.5, 1) })
	SoundFX.play("Dash", root.Position)
end

---------------------------------------------------------------- пробуждение и ульты
local auras = {}
local function addAura(model)
	if auras[model] then return end
	local root = rootOf(model)
	local torso = model:FindFirstChild("Torso")
	if not root or not torso then return end
	local c1, c2 = colorsOf(model)
	local att = Instance.new("Attachment")
	att.Parent = torso
	local e = Instance.new("ParticleEmitter")
	e.Texture = FX.TEX.spark
	e.Color = ColorSequence.new(c1, c2)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Rate = 35 * FX.quality
	e.Speed = NumberRange.new(3, 7)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(0, 12, 0)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = att
	local hl = Instance.new("Highlight")
	hl.Adornee = model
	hl.FillTransparency = 0.88
	hl.FillColor = c1
	hl.OutlineColor = c2
	hl.OutlineTransparency = 0.25
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = FX.folder
	local light = Instance.new("PointLight")
	light.Color = c1
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = torso
	auras[model] = { att, hl, light }
end
local function removeAura(model)
	local a = auras[model]
	if a then
		for _, x in ipairs(a) do x:Destroy() end
		auras[model] = nil
	end
end
Effects.addAura, Effects.removeAura = addAura, removeAura

H.Awaken = function(d)
	local m = d.m
	local root = rootOf(m)
	if not root then return end
	local c1, c2 = colorsOf(m)
	local pos = root.Position
	FX.ball(pos, WHITE, 1, 8, 0.4, 0)
	FX.ball(pos, c1, 2, 14, 0.8, 0.3)
	FX.ring(ground(pos) + Vector3.new(0, 0.3, 0), c1, 2, 26, 0.8, { w = 1.4, h = 0.5 })
	FX.ring(ground(pos) + Vector3.new(0, 0.3, 0), c2, 1, 18, 0.6, { w = 0.8, h = 0.4 })
	FX.light(pos, c1, 45, 10, 1)
	for _ = 1, 4 do FX.bolt(pos, pos + Vector3.new(Util.rand(-10, 10), Util.rand(4, 14), Util.rand(-10, 10)), c1, 0.3, 0.3, c2) end
	FX.emit(pos, { tex = "spark", color = c1, color2 = c2, n = 40, speed = 30, life = 0.8 })
	SoundFX.play("Awaken", pos)
	addAura(m)
	local near = myChar() and rootOf(myChar()) and (rootOf(myChar()).Position - pos).Magnitude < 80
	if near then CameraFX.shake(0.8) end
	if Effects.ui then Effects.ui.announce(d.name or "ПРОБУЖДЕНИЕ", c1, isMe(m) and "ПРОБУЖДЕНИЕ" or nil) end
	if isMe(m) then CameraFX.cinematic(m, 1.4) end
end

H.AwakenEnd = function(d)
	if d.m then removeAura(d.m) end
end

H.Ult = function(d)
	local m = d.m
	local c1 = d.c or colorsOf(m)
	if Effects.ui then Effects.ui.announce(d.text or "", c1, d.domain and "ТЕРРИТОРИЯ" or "УЛЬТА") end
	local root = rootOf(m)
	if root then
		FX.light(root.Position, c1, 40, 8, 0.8)
		FX.ball(root.Position, c1, 1, 7, 0.5, 0.2)
	end
	if Effects.ui and root and myChar() and rootOf(myChar()) and (rootOf(myChar()).Position - root.Position).Magnitude < 120 then
		Effects.ui.flash(c1, 0.35, 0.25)
	end
	if isMe(m) and d.domain then CameraFX.cinematic(m, 1.1) end
end

H.Swap = function(d)
	local root = rootOf(d.m)
	if root then
		local c1 = colorsOf(d.m)
		FX.ball(root.Position, c1, 1, 5, 0.35, 0.3)
		FX.emit(root.Position, { tex = "smoke", color = c1, n = 10, speed = 8, life = 0.6 })
	end
	removeAura(d.m)
end

---------------------------------------------------------------- общие эффекты приёмов
H.Burst = function(d)
	if not d.p then return end
	local c = d.c or WHITE
	FX.ball(d.p, c, 0.5, d.r or 4, 0.3, 0.2)
	if d.k == "wind" then
		FX.ring(d.p, c, 1, (d.r or 4) * 1.4, 0.35, { w = 0.6, h = 0.3 })
	elseif d.k == "void" then
		FX.ball(d.p, Color3.fromRGB(10, 6, 30), 0.5, (d.r or 4) * 0.6, 0.35, 0.1, Enum.Material.SmoothPlastic)
		FX.emit(d.p, { tex = "spark", color = c, n = 16, speed = (d.r or 4) * 4, life = 0.4 })
	elseif d.k == "shadow" then
		FX.emit(d.p, { tex = "smoke", color = Color3.fromRGB(40, 20, 60), n = 10, speed = 10, life = 0.6, light = 0 })
	elseif d.k == "slash" then
		for _ = 1, 4 do FX.slashMark(d.p + Vector3.new(Util.rand(-3, 3), Util.rand(-1, 3), Util.rand(-3, 3)), c, 6, 0.3) end
	else
		FX.sparks(d.p, c, 8, 35, { size = 0.22 })
	end
	FX.light(d.p, c, (d.r or 4) * 4, 4, 0.25)
end

H.Ring = function(d)
	if d.p then FX.ring(d.p + Vector3.new(0, 0.3, 0), d.c or WHITE, 1, d.r or 8, d.t or 0.35, { w = 0.9, h = 0.4 }) end
end

H.Shock = function(d)
	if not d.p then return end
	local c = d.c or WHITE
	FX.ball(d.p, d.c2 or WHITE, 0.5, (d.r or 8) * 0.35, 0.18, 0)
	FX.ring(d.p, c, 1, d.r or 8, 0.35, { w = 1, h = 0.5 })
	FX.ring(ground(d.p) + Vector3.new(0, 0.2, 0), c, 1, (d.r or 8) * 1.1, 0.45, { w = 0.7, h = 0.3 })
	FX.light(d.p, c, (d.r or 8) * 3, 6, 0.3)
	if d.k == "zap" then
		for _ = 1, 5 do
			local a = Util.rand(0, 6.28)
			FX.bolt(d.p, d.p + Vector3.new(math.cos(a) * (d.r or 8), Util.rand(-1, 2), math.sin(a) * (d.r or 8)), c, 0.25, 0.2, d.c2)
		end
	end
end

H.Vortex = function(d)
	if d.p then FX.vortex(d.p, d.r or 10, d.c or WHITE, d.t or 1.2, d.c2) end
	if d.k == "void" then SoundFX.play("Void", d.p) end
end

H.Beam = function(d)
	if not (d.a and d.b) then return end
	FX.beam(d.a, d.b, d.c or WHITE, d.w or 4, d.t or 0.6, d.c2)
	FX.ball(d.a, d.c2 or WHITE, 1, (d.w or 4) * 1.2, 0.3, 0.1)
	FX.ball(d.b, d.c or WHITE, 1, (d.w or 4) * 1.5, 0.4, 0.2)
	if d.k == "zap" then
		for _ = 1, 3 do FX.bolt(d.a, d.b, d.c2 or WHITE, 0.3, 0.25, d.c) end
	end
	local me = myChar() and rootOf(myChar())
	if me and (me.Position - d.a).Magnitude < 90 then CameraFX.shake(0.6) end
end

H.Bolt = function(d)
	if d.a and d.b then FX.bolt(d.a, d.b, d.c or WHITE, d.w or 0.5, 0.25, d.c2) end
end

H.Strike = function(d)
	if not d.p then return end
	local top = d.p + Vector3.new(Util.rand(-6, 6), d.big and 140 or 90, Util.rand(-6, 6))
	FX.bolt(top, d.p, d.c or WHITE, d.big and 1.6 or 0.9, d.big and 0.4 or 0.25, d.c2)
	FX.bolt(top, d.p, d.c2 or WHITE, d.big and 0.6 or 0.4, d.big and 0.4 or 0.25, d.c)
	FX.ball(d.p, WHITE, 1, d.big and 9 or 5, 0.25, 0)
	FX.ring(d.p + Vector3.new(0, 0.3, 0), d.c or WHITE, 1, d.big and 14 or 7, 0.35, { w = 0.8, h = 0.3 })
	FX.light(d.p, d.c or WHITE, d.big and 70 or 35, 10, 0.3)
	FX.debris(d.p, d.big and 10 or 4, FX.groundColor(d.p), Enum.Material.Slate, 28, 0.6)
end

H.SlashArc = function(d)
	if d.cf then FX.slash(d.cf, d.c or WHITE, d.r or 6, d.w or 1, 0.3, 170, WHITE) end
end

H.SlashMark = function(d)
	if d.p then FX.slashMark(d.p, d.c or WHITE, d.big and 8 or 6, 0.3) end
end

H.Lines = function(d)
	if not (d.a and d.b) then return end
	local dir = d.b - d.a
	if dir.Magnitude < 0.5 then return end
	local right = dir:Cross(Vector3.yAxis)
	right = right.Magnitude > 0.01 and right.Unit or Vector3.xAxis
	for i = -2, 2 do
		local off = right * i * 0.7 + Vector3.new(0, i * 0.35, 0)
		FX.beam(d.a + off, d.b + off, d.c or WHITE, (d.w or 0.6) * (i == 0 and 1.4 or 0.6), 0.3, WHITE)
	end
	FX.slashMark(d.b, d.c or WHITE, 8, 0.3)
end

H.Trail = function(d)
	if d.m then
		local c = d.c or WHITE
		FX.trail(d.m, c, d.t or 0.4, nil, 1)
		if d.k == "zap" then
			local root = rootOf(d.m)
			if root then
				task.spawn(function()
					local t0 = os.clock()
					while os.clock() - t0 < (d.t or 0.4) and root.Parent do
						FX.bolt(root.Position, root.Position - root.CFrame.LookVector * 4 + Vector3.new(Util.rand(-1, 1), Util.rand(-1, 1), 0), c, 0.15, 0.1)
						task.wait(0.05)
					end
				end)
			end
		end
	end
end

-- заряд в руках
H.Charge = function(d)
	local m = d.m
	if not m then return end
	local c = d.c or WHITE
	local hands = {}
	if d.hand == "R" then hands = { m:FindFirstChild("Right Arm") }
	else hands = { m:FindFirstChild("Right Arm"), m:FindFirstChild("Left Arm") } end
	local dur = d.t or 0.4
	for _, arm in ipairs(hands) do
		if arm then
			local ball = FX.part({ Shape = Enum.PartType.Ball, Color = c, Size = Vector3.one * 0.2, Transparency = 0.1 })
			local l = Instance.new("PointLight")
			l.Color = c
			l.Range = 10
			l.Brightness = 3
			l.Parent = ball
			FX.run(dur, function(t)
				if not arm.Parent then return end
				local s = (d.big and 2.6 or 1.4) * (0.3 + 0.7 * t) * (1 + math.sin(t * 40) * 0.08)
				ball.Size = Vector3.one * s
				ball.CFrame = arm.CFrame * CFrame.new(0, -1.2, 0)
			end, function() ball:Destroy() end)
		end
	end
	local root = rootOf(m)
	if root then
		FX.emit(root.Position, { tex = "spark", color = c, n = 18, speed = -14, life = dur, spread = 180 })
		if d.big then SoundFX.play("Charge", root.Position) end
	end
end

H.Cone = function(d)
	if not (d.p and d.d) then return end
	local dir = d.d
	local len, w = d.len or 14, d.w or 10
	for i = 1, 3 do
		local p = d.p + dir * (len * i / 3)
		local cf = CFrame.lookAt(p, p + dir) * CFrame.Angles(math.rad(90), 0, 0)
		task.delay(i * 0.04, function()
			FX.ring(p, i % 2 == 0 and (d.c2 or WHITE) or d.c, w * 0.15 * i, w * 0.3 * i + 2, 0.35, { cf = cf, w = 0.8, h = 0.3, n = 22 })
		end)
	end
	FX.ball(d.p + dir * 3, d.c or WHITE, 1, 6, 0.25, 0.2)
	FX.emit(d.p + dir * 4, { tex = "spark", color = d.c or WHITE, n = 24, speed = 40, life = 0.5, spread = 25 })
end

H.Explosion = function(d)
	if not d.p then return end
	FX.explosion(d.p, d.r or 10, d.c or Color3.fromRGB(255, 140, 40), d.c2)
	if d.k == "void" then
		FX.ball(d.p, Color3.fromRGB(8, 4, 20), (d.r or 10) * 0.2, (d.r or 10) * 0.7, 0.5, 0, Enum.Material.SmoothPlastic)
	elseif d.k == "zap" then
		for _ = 1, 6 do
			local a = Util.rand(0, 6.28)
			FX.bolt(d.p, d.p + Vector3.new(math.cos(a), Util.rand(0, 0.8), math.sin(a)) * (d.r or 10), d.c, 0.3, 0.3, d.c2)
		end
	elseif d.k == "fire" then
		FX.emit(d.p, { tex = "fire", color = d.c, color2 = d.c2, n = 30, speed = (d.r or 10) * 2, life = 0.6,
			size = NumberSequence.new({ NumberSequenceKeypoint.new(0, (d.r or 10) * 0.3), NumberSequenceKeypoint.new(1, 0) }) })
	end
	SoundFX.play((d.r or 10) > 18 and "ExplosionBig" or "Explosion", d.p)
	local me = myChar() and rootOf(myChar())
	if me then
		local dist = (me.Position - d.p).Magnitude
		if dist < (d.r or 10) * 6 then CameraFX.shake(math.clamp(1.2 - dist / ((d.r or 10) * 6), 0.2, 1.2)) end
	end
end

H.Crater = function(d)
	if d.p then FX.crater(d.p, d.r or 8, d.c) end
end

H.Impact = function(d)
	if not d.p then return end
	local gc = FX.groundColor(d.p)
	FX.ring(d.p + Vector3.new(0, 0.3, 0), gc:Lerp(WHITE, 0.4), 1, d.r or 6, 0.35, { w = 0.7, h = 0.3, mat = Enum.Material.SmoothPlastic, t0 = 0.3 })
	FX.debris(d.p, 5, gc, Enum.Material.Slate, 22, 0.6)
	FX.emit(d.p + Vector3.new(0, 0.5, 0), { tex = "smoke", color = gc:Lerp(WHITE, 0.5), n = 8, speed = 10, life = 0.6, light = 0, lightInf = 1 })
end

H.Warn = function(d)
	if d.p then FX.warn(d.p, d.r or 6, d.c or Color3.fromRGB(255, 60, 60), d.t or 0.6) end
end

H.Pillar = function(d)
	if not d.p then return end
	FX.pillar(d.p, d.r or 5, d.h or 30, d.c or WHITE, d.t or 0.8, d.c2)
	if d.k == "fire" then
		FX.emit(d.p + Vector3.new(0, 4, 0), { tex = "fire", color = d.c, color2 = d.c2, n = 30, speed = 30, life = 0.7, spread = 20,
			size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0) }) })
	end
	FX.ring(d.p + Vector3.new(0, 0.3, 0), d.c or WHITE, 1, (d.r or 5) * 1.8, 0.4, { w = 0.8, h = 0.3 })
end

H.Meteor = function(d)
	if not d.p then return end
	local dur = d.t or 1.2
	local from = d.p + Vector3.new(-50, 150, 35)
	local rock = FX.part({ Shape = Enum.PartType.Ball, Color = Color3.fromRGB(70, 40, 30), Material = Enum.Material.CrackedLava, Size = Vector3.one * 9 })
	local glow = FX.part({ Shape = Enum.PartType.Ball, Color = d.c or Color3.fromRGB(255, 120, 30), Size = Vector3.one * 12, Transparency = 0.45 })
	local l = Instance.new("PointLight")
	l.Color = d.c or Color3.fromRGB(255, 120, 30)
	l.Range = 40
	l.Brightness = 5
	l.Parent = glow
	local last = from
	FX.run(dur, function(t)
		local p = from:Lerp(d.p, t * t)
		rock.CFrame = CFrame.new(p) * CFrame.Angles(t * 8, t * 5, 0)
		glow.CFrame = CFrame.new(p)
		if (p - last).Magnitude > 4 then
			FX.ball(p, d.c2 or Color3.fromRGB(255, 200, 80), 3, 7, 0.4, 0.3)
			last = p
		end
	end, function() FX.kill(rock, glow) end)
	SoundFX.play("Fire", d.p, 0.8)
end

H.Sun = function(d)
	local m = d.m
	local root = rootOf(m)
	if not root then return end
	local dur = d.t or 1.6
	local core = FX.part({ Shape = Enum.PartType.Ball, Color = d.c2 or WHITE, Size = Vector3.one })
	local shell = FX.part({ Shape = Enum.PartType.Ball, Color = d.c or Color3.fromRGB(255, 130, 30), Size = Vector3.one, Transparency = 0.35 })
	local l = Instance.new("PointLight")
	l.Color = d.c or Color3.fromRGB(255, 140, 40)
	l.Range = 60
	l.Brightness = 6
	l.Parent = core
	FX.run(dur + 0.4, function(t)
		if not root.Parent then return end
		local k = math.min(1, t * (dur + 0.4) / dur)
		local r = (d.r or 9) * k
		local p = root.Position + Vector3.new(0, 6 + r, 0)
		core.Size = Vector3.one * math.max(0.2, r * 1.3)
		shell.Size = Vector3.one * math.max(0.2, r * 2 * (1 + math.sin(t * 30) * 0.04))
		core.CFrame = CFrame.new(p)
		shell.CFrame = CFrame.new(p)
	end, function() FX.kill(core, shell) end)
	SoundFX.play("Charge", root.Position, 1.2)
end

H.SunFall = function(d)
	if not (d.a and d.b) then return end
	local ball = FX.part({ Shape = Enum.PartType.Ball, Color = d.c or Color3.fromRGB(255, 130, 30), Size = Vector3.one * 18, Transparency = 0.2 })
	local core = FX.part({ Shape = Enum.PartType.Ball, Color = d.c2 or WHITE, Size = Vector3.one * 11 })
	FX.run(d.t or 0.35, function(t)
		local p = d.a:Lerp(d.b, t * t)
		ball.CFrame = CFrame.new(p)
		core.CFrame = CFrame.new(p)
	end, function() FX.kill(ball, core) end)
end

H.Storm = function(d)
	-- тучи: затемнить небо у тех, кто рядом
	local me = myChar() and rootOf(myChar())
	if not me or not d.p or (me.Position - d.p).Magnitude > (d.r or 60) * 1.5 then return end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "StormGrade"
	cc.TintColor = Color3.fromRGB(170, 185, 230)
	cc.Brightness = 0
	cc.Contrast = 0
	cc.Parent = Lighting
	local dur = d.t or 3
	FX.run(dur, function(t)
		local k = math.min(1, t * dur / 0.4) * (1 - math.max(0, (t * dur - (dur - 0.5)) / 0.5))
		cc.Brightness = -0.18 * k
		cc.Contrast = 0.2 * k
	end, function() cc:Destroy() end)
end

H.FireTrail = function(d)
	if not (d.a and d.b) then return end
	local dir = d.b - d.a
	local n = math.clamp(math.floor(dir.Magnitude / 4), 1, 12)
	for i = 0, n do
		local p = d.a:Lerp(d.b, i / n) + Vector3.new(0, 0.4, 0)
		local host = FX.part({ Size = Vector3.new(2, 0.2, 2), CFrame = CFrame.new(p), Transparency = 1 })
		local fire = Instance.new("Fire")
		fire.Color = d.c or Color3.fromRGB(255, 128, 28)
		fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
		fire.Size = 4
		fire.Heat = 9
		fire.Parent = host
		local glow = FX.part({ Shape = Enum.PartType.Cylinder, Color = d.c or Color3.fromRGB(255, 128, 28), Size = Vector3.new(0.12, 3.2, 3.2),
			CFrame = CFrame.new(p - Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 0.4 })
		task.delay(d.t or 2, function()
			fire.Enabled = false
			FX.run(0.5, function(t) glow.Transparency = 0.4 + 0.6 * t end, function() FX.kill(glow) end)
			task.delay(1.5, function() host:Destroy() end)
		end)
	end
end

H.FireRing = function(d)
	if not d.p then return end
	FX.ring(d.p + Vector3.new(0, 1, 0), d.c, 1, d.r or 20, d.t or 0.55, { w = 2.2, h = 2.4, n = 32, k = 1.6 })
	FX.ring(d.p + Vector3.new(0, 0.4, 0), d.c2 or WHITE, 1, (d.r or 20) * 0.95, d.t or 0.55, { w = 0.8, h = 0.5, n = 32, k = 1.6 })
	FX.light(d.p, d.c, (d.r or 20) * 2.5, 8, 0.6)
	for i = 1, 10 do
		local a = i / 10 * 6.28
		task.delay(0.05 * (i % 4), function()
			FX.emit(d.p + Vector3.new(math.cos(a) * (d.r or 20) * 0.6, 1, math.sin(a) * (d.r or 20) * 0.6),
				{ tex = "fire", color = d.c, color2 = d.c2, n = 6, speed = 14, life = 0.5 })
		end)
	end
end

H.Phoenix = function(d)
	local m = d.m
	local torso = m and m:FindFirstChild("Torso")
	if not torso then return end
	local wings = {}
	for _, s in ipairs({ -1, 1 }) do
		wings[#wings + 1] = { p = FX.part({ Color = d.c or Color3.fromRGB(255, 128, 28), Size = Vector3.new(5, 0.3, 2.2), Transparency = 0.15 }), s = s }
	end
	local body = FX.part({ Shape = Enum.PartType.Ball, Color = d.c2 or Color3.fromRGB(255, 222, 90), Size = Vector3.one * 3.5, Transparency = 0.3 })
	FX.trail(m, d.c or Color3.fromRGB(255, 128, 28), d.t or 0.5, nil, 2)
	FX.run(d.t or 0.5, function(t)
		if not torso.Parent then return end
		local flap = math.sin(t * 40) * 0.5
		for _, w in ipairs(wings) do
			w.p.CFrame = torso.CFrame * CFrame.new(w.s * 2.8, 0.6, 0) * CFrame.Angles(0, 0, w.s * flap)
			w.p.Transparency = 0.15 + 0.85 * t ^ 3
		end
		body.CFrame = torso.CFrame
		body.Transparency = 0.3 + 0.7 * t ^ 2
	end, function()
		for _, w in ipairs(wings) do w.p:Destroy() end
		body:Destroy()
	end)
end

H.ShadowPool = function(d)
	if not d.p then return end
	local r = d.r or 5
	local disc = FX.part({ Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(10, 6, 16), Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(0.12, 0.2, 0.2), CFrame = CFrame.new(d.p + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	local edge = FX.part({ Shape = Enum.PartType.Cylinder, Color = d.c or Color3.fromRGB(128, 72, 220), Size = Vector3.new(0.08, 0.2, 0.2),
		CFrame = CFrame.new(d.p + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 0.2 })
	local dur = d.t or 0.8
	FX.run(dur, function(t)
		local k = math.min(1, t * dur / 0.2) * (1 - math.max(0, (t - 0.7) / 0.3))
		local rr = r * 2 * k
		disc.Size = Vector3.new(0.12, math.max(0.05, rr), math.max(0.05, rr))
		edge.Size = Vector3.new(0.08, math.max(0.05, rr + 0.8), math.max(0.05, rr + 0.8))
		if d.warn then edge.Transparency = 0.2 + 0.4 * math.abs(math.sin(t * 20)) end
	end, function() FX.kill(disc, edge) end)
	FX.emit(d.p + Vector3.new(0, 0.5, 0), { tex = "smoke", color = Color3.fromRGB(30, 16, 48), n = 6, speed = 4, life = 0.8, light = 0, accel = Vector3.new(0, 6, 0) })
end

H.ShadowBurst = function(d)
	if not d.p then return end
	for i = 1, 10 do
		local a = i / 10 * 6.28
		local p = d.p + Vector3.new(math.cos(a) * (d.r or 6) * 0.5, 0, math.sin(a) * (d.r or 6) * 0.5)
		local spike = FX.part({ Color = Color3.fromRGB(12, 8, 20), Material = Enum.Material.SmoothPlastic, Size = Vector3.new(0.8, 0.2, 0.8),
			CFrame = CFrame.new(p) * CFrame.Angles(Util.rand(-0.4, 0.4), a, Util.rand(-0.4, 0.4)) })
		FX.run(0.5, function(t)
			local h = 7 * math.sin(math.min(1, t * 3) * math.pi / 2) * (1 - math.max(0, (t - 0.6) / 0.4))
			spike.Size = Vector3.new(0.8, math.max(0.1, h), 0.8)
			spike.CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, a, 0)
		end, function() spike:Destroy() end)
	end
	FX.ball(d.p + Vector3.new(0, 2, 0), d.c or Color3.fromRGB(128, 72, 220), 1, d.r or 6, 0.35, 0.3)
	FX.emit(d.p + Vector3.new(0, 1, 0), { tex = "smoke", color = Color3.fromRGB(40, 20, 60), n = 12, speed = 12, life = 0.7, light = 0 })
end

H.Maw = function(d)
	if not d.p then return end
	local r = d.r or 7
	local teeth = {}
	local n = d.small and 6 or 10
	for i = 1, n do
		local a = i / n * 6.28
		local base = d.p + Vector3.new(math.cos(a) * r * 0.8, 0, math.sin(a) * r * 0.8)
		teeth[#teeth + 1] = { p = FX.part({ Color = Color3.fromRGB(14, 8, 22), Material = Enum.Material.SmoothPlastic, Size = Vector3.new(1.2, 1, 1.2) }), base = base, a = a }
	end
	local glow = FX.part({ Shape = Enum.PartType.Cylinder, Color = d.c or Color3.fromRGB(128, 72, 220), Size = Vector3.new(0.1, r * 1.8, r * 1.8),
		CFrame = CFrame.new(d.p + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 0.3 })
	local H0 = d.small and 4 or r * 1.4
	FX.run(0.7, function(t)
		local rise = math.sin(math.min(1, t * 3) * math.pi / 2)
		local close = math.clamp((t - 0.25) / 0.2, 0, 1)
		local fall = math.max(0, (t - 0.65) / 0.35)
		for _, x in ipairs(teeth) do
			local h = H0 * rise * (1 - fall)
			local tilt = math.rad(15 + 45 * close)
			x.p.Size = Vector3.new(1.2, math.max(0.1, h), 1.2)
			local toC = (d.p - x.base)
			x.p.CFrame = CFrame.lookAt(x.base, x.base + Vector3.new(toC.X, 0, toC.Z)) * CFrame.Angles(-tilt, 0, 0) * CFrame.new(0, h / 2, 0)
		end
		glow.Transparency = 0.3 + 0.7 * t
	end, function()
		for _, x in ipairs(teeth) do x.p:Destroy() end
		glow:Destroy()
	end)
	FX.light(d.p, d.c or Color3.fromRGB(128, 72, 220), r * 4, 4, 0.5)
end

H.Smoke = function(d)
	if d.p then
		FX.emit(d.p, { tex = "smoke", color = Color3.fromRGB(30, 18, 46), n = 10, speed = 6, life = 0.7, light = 0, lightInf = 1,
			size = NumberSequence.new((d.r or 3) * 0.6, (d.r or 3) * 1.2) })
		FX.ball(d.p, d.c or Color3.fromRGB(128, 72, 220), 0.5, d.r or 3, 0.3, 0.4)
	end
end

H.GiantFist = function(d)
	if not d.cf then return end
	local dur = d.t or 0.6
	local len = d.len or 30
	local fist = FX.part({ Color = d.c2 or Color3.fromRGB(14, 10, 22), Material = Enum.Material.SmoothPlastic, Size = Vector3.new(8, 7, 8), Transparency = 0.1 })
	local knuckles = FX.part({ Color = d.c or Color3.fromRGB(128, 72, 220), Size = Vector3.new(8.2, 2, 2.2), Transparency = 0.2 })
	local arm = FX.part({ Color = d.c2 or Color3.fromRGB(14, 10, 22), Material = Enum.Material.SmoothPlastic, Size = Vector3.new(5, 5, 1), Transparency = 0.2 })
	FX.run(dur, function(t)
		local k = math.min(1, t * dur / 0.3)
		k = 1 - (1 - k) ^ 3
		local back = d.cf * CFrame.new(0, 3, 6)
		local tip = back * CFrame.new(0, 0, -len * k - 4)
		fist.CFrame = tip
		knuckles.CFrame = tip * CFrame.new(0, 1.5, -3.6)
		local mid = back:Lerp(tip, 0.5)
		arm.Size = Vector3.new(5, 5, math.max(1, len * k))
		arm.CFrame = mid
		local fade = math.max(0, (t - 0.6) / 0.4)
		fist.Transparency = 0.1 + 0.9 * fade
		knuckles.Transparency = 0.2 + 0.8 * fade
		arm.Transparency = 0.2 + 0.8 * fade
	end, function() FX.kill(fist, knuckles, arm) end)
	SoundFX.play("Shadow", d.cf.Position, 1.2)
end

H.Chains = function(d)
	local m = d.m
	local root = rootOf(m)
	if not root or not d.a then return end
	local links = {}
	for i = 1, 10 do
		links[i] = FX.part({ Color = (i % 2 == 0) and (d.c or Color3.fromRGB(128, 72, 220)) or Color3.fromRGB(20, 16, 28), Size = Vector3.new(0.4, 0.4, 1.2),
			Material = i % 2 == 0 and Enum.Material.Neon or Enum.Material.Metal })
	end
	local dur = d.t or 2
	FX.run(dur, function(t)
		if not root.Parent then return end
		local a, b = d.a, root.Position
		for i, l in ipairs(links) do
			local p0 = a:Lerp(b, (i - 1) / #links)
			local p1 = a:Lerp(b, i / #links)
			l.Size = Vector3.new(0.4, 0.4, (p1 - p0).Magnitude + 0.2)
			l.CFrame = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, 0, i * 0.8)
			l.Transparency = t > 0.85 and (t - 0.85) / 0.15 or 0
		end
	end, function() for _, l in ipairs(links) do l:Destroy() end end)
end

H.Afterimage = function(d)
	if d.m then FX.afterimage(d.m, d.c or WHITE, 0.4) end
end

H.Blink = function(d)
	if not (d.a and d.b) then return end
	FX.beam(d.a, d.b, d.c or WHITE, 0.35, 0.2, WHITE)
	FX.ball(d.a, d.c or WHITE, 0.5, 3, 0.25, 0.2)
	FX.ball(d.b, d.c or WHITE, 0.5, 3.5, 0.3, 0.2)
	SoundFX.play("Teleport", d.b)
end

H.Glint = function(d)
	local m = d.m
	local blade = m and m:FindFirstChild("Weapon") and m.Weapon:FindFirstChild("Blade")
	local p = blade and blade.Position or (rootOf(m) and rootOf(m).Position)
	if p then
		FX.ball(p, d.c or WHITE, 0.2, 1.6, 0.3, 0)
		FX.sparks(p, d.c or WHITE, 5, 12, { size = 0.12, g = 0 })
	end
end

H.Mark = function(d)
	local root = rootOf(d.m)
	if not root then return end
	local dur = d.t or 0.45
	FX.run(dur, function(t)
		if not root.Parent then return end
	end)
	FX.ring(root.Position, d.c or WHITE, 3, 1, dur, { w = 0.35, h = 0.35, n = 16, k = 1 })
	FX.text(root.Position + Vector3.new(0, 3, 0), "!", d.c or WHITE, 0.6, dur)
end

-- окно Резонанса: вспышка на кулаке
H.Cue = function(d)
	local m = d.m
	local arm = m and m:FindFirstChild("Right Arm")
	if not arm then return end
	task.delay(d.d or 0.1, function()
		if not arm.Parent then return end
		local p = (arm.CFrame * CFrame.new(0, -1.2, 0)).Position
		FX.ball(p, d.c or Color3.fromRGB(255, 214, 92), 0.4, 3.5, 0.22, 0)
		FX.light(p, d.c or Color3.fromRGB(255, 214, 92), 18, 6, 0.25)
		if isMe(m) and Effects.ui and Effects.ui.cue then Effects.ui.cue((d.t or 0.3) - (d.d or 0.1)) end
	end)
end

H.Resonance = function(d)
	local p = d.p
	if not p then return end
	FX.ball(p, Color3.fromRGB(8, 0, 0), 1, 7, 0.3, 0, Enum.Material.SmoothPlastic)
	FX.ball(p, d.c or Color3.fromRGB(230, 20, 30), 2, 11, 0.45, 0.25)
	for _ = 1, 8 do
		local dir = Vector3.new(Util.rand(-1, 1), Util.rand(-0.6, 1), Util.rand(-1, 1)).Unit
		FX.bolt(p, p + dir * Util.rand(6, 13), Color3.fromRGB(10, 0, 0), 0.4, 0.3, d.c or Color3.fromRGB(230, 20, 30))
	end
	FX.ring(p, d.c or Color3.fromRGB(230, 20, 30), 1, 14, 0.45, { cf = CFrame.lookAt(p, workspace.CurrentCamera.CFrame.Position) * CFrame.Angles(math.rad(90), 0, 0) })
	FX.light(p, Color3.fromRGB(255, 30, 30), 50, 10, 0.5)
	FX.text(p + Vector3.new(0, 4.5, 0), "РЕЗОНАНС!", Color3.fromRGB(255, 60, 60), 1.4, 1.1)
	SoundFX.play("Resonance", p)
	local me = myChar() and rootOf(myChar())
	if me and (me.Position - p).Magnitude < 80 then CameraFX.shake(1) end
	if Effects.ui then Effects.ui.flash(Color3.fromRGB(120, 0, 0), 0.25, 0.35) end
end

H.Text = function(d)
	local p = d.p or (rootOf(d.m) and rootOf(d.m).Position + Vector3.new(0, 4, 0))
	if p then FX.text(p, d.text or "", d.c or WHITE, 1) end
end

H.Shake = function(d)
	local me = myChar() and rootOf(myChar())
	if not me or not d.p then return end
	local dist = (me.Position - d.p).Magnitude
	local r = d.r or 60
	if dist < r then CameraFX.shake((d.m or 1) * (1 - dist / r)) end
end

H.Sound = function(d)
	SoundFX.play(d.n, d.p or d.m)
end

---------------------------------------------------------------- снаряды (картинка у клиента)
local projs = {}
local function makeProj(d)
	local kind = d.k
	local c = d.c or WHITE
	local s = d.s or 2
	local parts = {}
	if kind == "voidorb" then
		parts[1] = FX.part({ Shape = Enum.PartType.Ball, Color = Color3.fromRGB(10, 6, 30), Material = Enum.Material.SmoothPlastic, Size = Vector3.one * s * 1.3 })
		parts[2] = FX.part({ Shape = Enum.PartType.Ball, Color = c, Size = Vector3.one * s * 2.2, Transparency = 0.45 })
	elseif kind == "fireball" then
		parts[1] = FX.part({ Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 240, 180), Size = Vector3.one * s * 1.1 })
		parts[2] = FX.part({ Shape = Enum.PartType.Ball, Color = c, Size = Vector3.one * s * 2, Transparency = 0.3 })
	elseif kind == "slash" then
		parts[1] = FX.part({ Color = c, Size = Vector3.new(s, 0.3, 0.7) })
		parts[2] = FX.part({ Color = WHITE, Size = Vector3.new(s * 0.8, 0.12, 0.35) })
		parts[3] = FX.part({ Color = c, Size = Vector3.new(s * 0.7, 0.25, 0.6), Transparency = 0.4 })
		parts[4] = FX.part({ Color = c, Size = Vector3.new(s * 0.7, 0.25, 0.6), Transparency = 0.4 })
	elseif kind == "crows" then
		for i = 1, 9 do
			parts[i] = FX.part({ Color = Color3.fromRGB(14, 10, 20), Material = Enum.Material.SmoothPlastic, Size = Vector3.new(1.4, 0.15, 0.6) })
		end
	else
		parts[1] = FX.part({ Shape = Enum.PartType.Ball, Color = c, Size = Vector3.one * s * 1.5 })
	end
	local l = Instance.new("PointLight")
	l.Color = c
	l.Range = 16
	l.Brightness = 3
	l.Parent = parts[1]
	return parts
end

H.Proj = function(d)
	if not d.id then return end
	local p = { d = d, parts = makeProj(d), t0 = d.t0, offsets = {} }
	if d.k == "crows" then
		for i = 1, #p.parts do p.offsets[i] = Vector3.new(Util.rand(-4, 4), Util.rand(-1.5, 2.5), Util.rand(-3, 3)) end
	end
	projs[d.id] = p
	if d.k == "fireball" then SoundFX.play("Fire", d.p) elseif d.k == "slash" then SoundFX.play("Slash", d.p) end
end

H.ProjEnd = function(d)
	local p = projs[d.id]
	if not p then return end
	projs[d.id] = nil
	for _, x in ipairs(p.parts) do x:Destroy() end
	local c = p.d.c or WHITE
	if d.p then
		if p.d.k == "slash" then
			FX.slashMark(d.p, c, 6, 0.25)
		elseif p.d.k == "crows" then
			FX.emit(d.p, { tex = "smoke", color = Color3.fromRGB(20, 14, 30), n = 8, speed = 10, life = 0.5, light = 0 })
		elseif p.d.k ~= "fireball" and p.d.k ~= "voidorb" then
			FX.ball(d.p, c, 0.5, 3, 0.2, 0.2)
		end
	end
end

RunService.RenderStepped:Connect(function()
	if next(projs) == nil then return end
	local now = Util.now()
	for id, p in pairs(projs) do
		local d = p.d
		local el = now - (p.t0 or now)
		local v = d.v
		local dist = math.min(v.Magnitude * el, d.r or 100)
		local dir = v.Magnitude > 0 and v.Unit or Vector3.zAxis
		local pos = d.p + dir * dist
		local cf = CFrame.lookAt(pos, pos + dir)
		if d.k == "voidorb" or d.k == "fireball" then
			local wob = 1 + math.sin(el * 30) * 0.08
			p.parts[1].CFrame = cf
			p.parts[2].CFrame = cf
			p.parts[2].Size = Vector3.one * (d.s or 2) * 2 * wob
			if d.k == "fireball" and math.random() < 0.5 then
				FX.ball(pos - dir * 1.5, d.c or WHITE, (d.s or 2) * 0.6, (d.s or 2) * 1.2, 0.25, 0.3)
			end
		elseif d.k == "slash" then
			local s = d.s or 6
			p.parts[1].CFrame = cf
			p.parts[2].CFrame = cf * CFrame.new(0, 0, -0.1)
			p.parts[3].CFrame = cf * CFrame.new(-s * 0.5, 0, 0.5) * CFrame.Angles(0, math.rad(-25), 0)
			p.parts[4].CFrame = cf * CFrame.new(s * 0.5, 0, 0.5) * CFrame.Angles(0, math.rad(25), 0)
		elseif d.k == "crows" then
			for i, part in ipairs(p.parts) do
				local o = p.offsets[i]
				local flap = math.sin(el * 25 + i) * 0.6
				part.CFrame = cf * CFrame.new(o + Vector3.new(0, math.sin(el * 6 + i) * 0.5, 0)) * CFrame.Angles(0, 0, flap)
			end
		else
			p.parts[1].CFrame = cf
		end
		if el > 6 then
			for _, x in ipairs(p.parts) do x:Destroy() end
			projs[id] = nil
		end
	end
end)

---------------------------------------------------------------- территории
local domains = {}
local grade
local function setGrade(style, on)
	if on then
		if not grade then
			grade = Instance.new("ColorCorrectionEffect")
			grade.Name = "DomainGrade"
			grade.Parent = Lighting
		end
		local tint = { void = Color3.fromRGB(170, 160, 255), blade = Color3.fromRGB(255, 150, 160), abyss = Color3.fromRGB(170, 140, 220) }
		grade.TintColor = tint[style] or WHITE
		grade.Contrast = 0.25
		grade.Saturation = -0.2
		grade.Brightness = -0.08
		grade.Enabled = true
	elseif grade then
		grade.Enabled = false
	end
end

H.Domain = function(d)
	local model, cols = FX.dome(d.c, d.r or 42, d.style, (d.dur or 9) + 0.2)
	local dom = { id = d.id, c = d.c, r = d.r or 42, style = d.style, model = model, cols = cols, t0 = os.clock(), dur = d.dur or 9 }
	domains[d.id] = dom
	FX.ring(d.c + Vector3.new(0, 0.5, 0), cols[2], 2, dom.r, 0.7, { w = 2, h = 1 })
	FX.light(d.c + Vector3.new(0, 10, 0), cols[2], dom.r * 2, 8, 1)
	SoundFX.play("Domain", d.c)
	CameraFX.shake(0.7)
	-- внутреннее убранство
	task.spawn(function()
		while domains[d.id] and os.clock() - dom.t0 < dom.dur do
			if dom.style == "void" then
				for _ = 1, 3 do
					local a = Util.rand(0, 6.28)
					local rr = Util.rand(0, dom.r * 0.9)
					FX.ball(d.c + Vector3.new(math.cos(a) * rr, Util.rand(2, dom.r * 0.7), math.sin(a) * rr), Util.pick({ cols[2], cols[3], WHITE }), 0.2, 0.6, 1.2, 0.1)
				end
			elseif dom.style == "blade" then
				local a = Util.rand(0, 6.28)
				local rr = Util.rand(0, dom.r * 0.9)
				FX.slashMark(d.c + Vector3.new(math.cos(a) * rr, Util.rand(2, 12), math.sin(a) * rr), cols[2], Util.rand(5, 10), 0.35)
			elseif dom.style == "abyss" then
				local a = Util.rand(0, 6.28)
				local rr = Util.rand(0, dom.r * 0.9)
				FX.emit(d.c + Vector3.new(math.cos(a) * rr, 0.5, math.sin(a) * rr), { tex = "smoke", color = Color3.fromRGB(20, 10, 34), n = 3, speed = 3, life = 1.2, light = 0,
					accel = Vector3.new(0, 3, 0) })
			end
			task.wait(0.12)
		end
	end)
end

H.DomainEnd = function(d)
	local dom = domains[d.id]
	if not dom then return end
	domains[d.id] = nil
	if dom.model and dom.model.Parent then
		-- быстро растворить
		for _, x in ipairs(dom.model:GetDescendants()) do
			if x:IsA("BasePart") then
				local t0 = x.Transparency
				FX.run(0.4, function(t) x.Transparency = t0 + (1 - t0) * t end)
			end
		end
		task.delay(0.45, function() if dom.model then dom.model:Destroy() end end)
	end
	if d.reason == "clash" then FX.explosion(dom.c + Vector3.new(0, 6, 0), 16, dom.cols[2], WHITE) end
end

H.DomainClash = function(d)
	if d.p then
		FX.explosion(d.p + Vector3.new(0, 5, 0), 20, Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 200, 120))
		FX.text(d.p + Vector3.new(0, 10, 0), "СТОЛКНОВЕНИЕ ТЕРРИТОРИЙ", Color3.fromRGB(255, 240, 200), 1.6, 1.6)
	end
end

-- внутри территории: подкрасить картинку
RunService.Heartbeat:Connect(function()
	local me = myChar() and rootOf(myChar())
	local inside
	if me then
		for _, dom in pairs(domains) do
			local p = me.Position
			if (Vector3.new(p.X, 0, p.Z) - Vector3.new(dom.c.X, 0, dom.c.Z)).Magnitude <= dom.r then inside = dom end
		end
	end
	setGrade(inside and inside.style, inside ~= nil)
end)

---------------------------------------------------------------- карта
H.Break = function(d)
	for _, m in ipairs(d.list or {}) do
		local parts = {}
		if m:IsA("BasePart") then parts = { m } else
			for _, x in ipairs(m:GetDescendants()) do if x:IsA("BasePart") then parts[#parts + 1] = x end end
		end
		for i, p in ipairs(parts) do
			if i > 6 then break end
			local n = math.clamp(math.floor(p.Size.Magnitude / 2), 2, 6)
			FX.debris(p.Position, n, p.Color, p.Material, 30 * (d.f or 1), math.clamp(p.Size.Magnitude / 6, 0.4, 1.4))
		end
	end
	if d.p then SoundFX.play("Explosion", d.p, 0.6) end
end

H.Restore = function(d) end
H.Kill = function(d) if Effects.ui then Effects.ui.killfeed(d) end end
H.Streak = function(d) if Effects.ui then Effects.ui.announce(string.format("%s — серия %d!", d.name or "?", d.n or 0), d.c, "СЕРИЯ") end end
H.BotsConfig = function(d) if Effects.ui and Effects.ui.botsConfig then Effects.ui.botsConfig(d) end end

function Effects.handle(name, data)
	local h = H[name]
	if h then
		local ok, err = pcall(h, data or {})
		if not ok then warn("[Effects] " .. tostring(name) .. ": " .. tostring(err)) end
	end
end

return Effects
