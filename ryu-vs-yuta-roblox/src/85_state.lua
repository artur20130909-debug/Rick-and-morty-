----------------------------------------------------------------------
-- СОСТОЯНИЕ И ОБЩЕЕ ДЛЯ КАДРОВ
----------------------------------------------------------------------

local world = Instance.new("Folder")
world.Name = "RyuVsYuta"
world.Parent = workspace

local yuta, ryu, rika
local rigs = {}
local playing = false
local fx = {}

-- позы: {x, y, z} в градусах. Руки и хвост висят вниз: x+ — вперёд.
local POSE = {
	rikaFire = {
		spine = { -25, 0, 0 }, chest = { -20, 0, 0 }, neck = { 20, 0, 0 }, head = { -5, 0, 0 }, jaw = { -32, 0, 0 },
		shR = { 75, 0, 25 }, elR = { 35, 0, 0 }, haR = { 20, 0, 0 },
		shL = { 40, 0, -55 }, elL = { 70, 0, 0 }, haL = { 10, 0, 0 },
		tail1 = { -18, 0, 0 }, tail2 = { -18, 0, 0 }, tail3 = { -18, 0, 6 }, tail4 = { -18, 0, 8 }, tail5 = { -18, 0, 8 },
		tail6 = { -18, 0, 4 }, tail7 = { -18, 0, 0 }, tail8 = { -18, 0, 0 }, tail9 = { -18, 0, 0 },
	},
	rikaLoom = {
		spine = { -15, 0, 0 }, chest = { -15, 0, 0 }, neck = { 15, 20, 0 }, head = { 5, 25, 0 }, jaw = { -35, 0, 0 },
		shL = { 140, 0, 5 }, elL = { 5, 0, 0 }, haL = { -10, 0, 0 },
		shR = { 50, 0, 35 }, elR = { 60, 0, 0 }, haR = { 10, 0, 0 },
		tail1 = { -15, 0, 0 }, tail2 = { -15, 0, 0 }, tail3 = { -15, 0, 5 }, tail4 = { -15, 0, 5 }, tail5 = { -15, 0, 5 },
		tail6 = { -15, 0, 0 }, tail7 = { -15, 0, 0 }, tail8 = { -15, 0, 0 }, tail9 = { -15, 0, 0 },
	},
	rikaHand = {
		spine = { -10, 0, 0 }, chest = { -10, 0, 0 }, neck = { 10, 0, 0 }, jaw = { -25, 0, 0 },
		shL = { 100, 0, 0 }, elL = { 40, 0, 0 }, haL = { 60, 0, 0 },
		fL1 = { 0, 0, -20 }, fL2 = { -10, 0, -8 }, fL3 = { -10, 0, 0 }, fL4 = { -10, 0, 8 }, fL5 = { -10, 0, 16 },
		shR = { 30, 0, 30 }, elR = { 40, 0, 0 },
	},
	yutaCast = {
		root = { -4, 0, 0 }, neck = { -8, 50, 0 },
		rArm = { 124, 0, -8 }, lArm = { -24, 0, -14 }, rLeg = { 10, 0, 0 }, lLeg = { -12, 0, 0 },
	},
	yutaOrb = {
		root = { -6, 0, 0 }, neck = { -6, 50, 0 },
		lArm = { 85, 0, 10 }, rArm = { 20, 0, 20 }, rLeg = { 8, 0, 0 }, lLeg = { -10, 0, 0 },
	},
	ryuHit = {
		root = { 10, -8, -6 }, neck = { 6, 12, 8 },
		rArm = { 30, 0, 72 }, lArm = { 70, 0, -28 }, rLeg = { -14, 0, 4 }, lLeg = { 12, 0, -4 },
	},
	ryuLaugh = {
		root = { 4, 0, 0 }, neck = { -4, -18, -4 },
		rArm = { 8, 0, 10 }, lArm = { 8, 0, -10 },
	},
	ryuStand = {
		root = { -4, 0, 0 }, neck = { -2, 0, 0 },
		rArm = { 25, 0, 8 }, lArm = { 18, 0, -10 }, rLeg = { -12, 0, 6 }, lLeg = { 14, 0, -6 },
	},
	ryuBack = {
		rArm = { 8, 0, 12 }, lArm = { 8, 0, -12 }, rLeg = { 0, 0, 8 }, lLeg = { 0, 0, -8 },
	},
	ryuArmsWide = {
		root = { 6, 0, 0 }, neck = { 10, -10, 0 }, rArm = { 20, 0, 75 }, lArm = { 20, 0, -75 }, rLeg = { 0, 0, 6 }, lLeg = { 0, 0, -6 },
	},
	ryuHeadBack = {
		root = { 10, 0, 0 }, neck = { 22, -10, 6 }, rArm = { 30, 0, 80 }, lArm = { 30, 0, -80 }, rLeg = { 0, 0, 6 }, lLeg = { 0, 0, -6 },
	},
	ryuReach = {
		root = { -12, 0, 0 }, neck = { -5, 0, 0 }, rArm = { 85, 0, -10 }, lArm = { -20, 0, -20 }, rLeg = { -20, 0, 0 }, lLeg = { 20, 0, 0 },
	},
	ryuSide = {
		root = { -8, 0, 0 }, neck = { -4, 0, 0 }, rArm = { 80, 0, 10 }, lArm = { -30, 0, -10 }, rLeg = { -15, 0, 0 }, lLeg = { 15, 0, 0 },
	},
	ryuLow = {
		root = { 8, 0, 0 }, neck = { 10, -20, 6 },
		rArm = { 10, 0, 12 }, lArm = { 15, 0, -15 },
	},
}

-- Ровный «анимешный» свет. Яркое солнце пересвечивает синий канал, и синий
-- асфальт в Studio становится бирюзовым. Поэтому солнце слабое, а основной свет
-- даёт почти белый рассеянный: цвета деталей видны такими, какими заданы.
local function setLook(o)
	local sun = (o.brightness or 1.5) * CONFIG.SUN
	local amb = (o.ambient or RGB(70, 80, 110)):Lerp(C.white, CONFIG.AMBIENT_WHITE)
	local out = (o.outdoor or o.ambient or RGB(70, 80, 110)):Lerp(C.white, CONFIG.AMBIENT_WHITE)
	local lift = CONFIG.AMBIENT
	if (o.brightness or 1.5) <= 0 then
		-- плоский кадр (глаза): весь свет рассеянный, цвета ровно как заданы
		sun, lift = 0, 1
		amb, out = o.ambient or C.white, o.outdoor or o.ambient or C.white
	end
	Lighting.ClockTime = o.clock or 0
	Lighting.Brightness = sun
	Lighting.Ambient = Color3.new(amb.R * lift, amb.G * lift, amb.B * lift)
	Lighting.OutdoorAmbient = Color3.new(out.R * lift, out.G * lift, out.B * lift)
	Lighting.FogColor = o.fogColor or RGB(16, 22, 44)
	Lighting.FogStart = o.fogStart or 200
	Lighting.FogEnd = o.fogEnd or 1100
	Lighting.ExposureCompensation = CONFIG.EXPOSURE
	fx.cc.TintColor = o.tint or C.white
	fx.cc.Saturation = (o.sat or 0) * 0.6
	fx.cc.Contrast = (o.contrast or 0) * 0.5
	fx.cc.Brightness = 0
	fx.bloom.Intensity = math.min(o.bloom or 0.8, 1.0)
	fx.bloom.Size = o.bloomSize or 36
	-- светятся только неон и эффекты, белая куртка и облака не «плывут»
	fx.bloom.Threshold = math.max(o.bloomThreshold or 0.85, 0.97)
	-- пелена тумана поверх кадра: o.veil = { цвет, прозрачность сверху, прозрачность снизу }
	if ui.haze then
		if o.veil then
			ui.haze.BackgroundColor3 = o.veil[1]
			ui.haze.BackgroundTransparency = 0
			ui.hazeGrad.Transparency = NS({ { 0, o.veil[2] }, { 1, o.veil[3] } })
		else
			ui.haze.BackgroundTransparency = 1
		end
	end
	-- дымка (Atmosphere) только там, где в аниме туман
	if o.haze then
		fx.atmo.Density = o.haze
		fx.atmo.Offset = 0
		fx.atmo.Color = o.hazeColor or RGB(226, 214, 245)
		fx.atmo.Decay = o.hazeDecay or RGB(170, 160, 220)
		fx.atmo.Glare = 0
		fx.atmo.Haze = o.hazeSoft or 1.5
		fx.atmo.Parent = Lighting
	else
		fx.atmo.Parent = nil
	end
	if o.dof then
		fx.dof.Enabled = true
		fx.dof.FocusDistance = o.dof[1]
		fx.dof.InFocusRadius = o.dof[2]
		fx.dof.FarIntensity = o.dof[3]
		fx.dof.NearIntensity = o.dof[4] or 0
	else
		fx.dof.Enabled = false
	end
end

-- поставить риг так, чтобы кость boneName оказалась в точке/повороте want
local function placeBoneAt(rig, boneName, want)
	rig:place(CF())
	rig:update(songT)
	local rel = rig.bones[boneName].world
	rig:place(want * rel:Inverse())
	rig:update(songT)
end

local partOffset = 0 -- начало текущей части на общем таймлайне

-- субтитры как в клипе (CONFIG.SUBTITLES): строка видна, пока идёт её отрезок
local function updateSubtitles()
	local lab = ui.sub
	if not CONFIG.SUBTITLES or not ui.subs or not playing then
		lab.Visible = false
		return
	end
	local t = songT - partOffset
	for _, line in ipairs(ui.subs) do
		if t >= line[1] and t < line[2] then
			lab.Text = (CONFIG.SUBTITLES == "ru") and line[4] or line[3]
			lab.Visible = true
			return
		end
	end
	lab.Visible = false
end

local function beginShot(t0)
	updaters = {}
	for _, sp in ipairs(sprites.shot) do
		sp.dead = true
	end
	sprites.shot = {}
	if Shot.folder then
		Shot.folder:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "Shot"
	f.Parent = world
	Shot.folder = f
	Shot.anchor = newPart(f, V3(0.2, 0.2, 0.2), C.white, CF(), { alpha = 1 })
	Shot.debris = Instance.new("Model")
	Shot.debris.Name = "Debris"
	Shot.debris.Parent = f
	outline(Shot.debris, nil, 1)
	Shot.t0 = t0 + partOffset
	Shot.update = nil
	Shot.scene = nil
	for _, hp in ipairs(ryu and ryu.hair or {}) do
		hp.Color = C.hairRyu
	end
	for _, bp in ipairs(yuta and yuta.tags.sblood or {}) do
		bp.Transparency = 1
	end
	shake = 0
	for _, r in ipairs(rigs) do
		r:show(false)
		for _, name in ipairs({ "root", "neck", "coat", "rArm", "lArm", "rLeg", "lLeg" }) do
			if r.bones[name] and r ~= rika then
				r.bones[name].wob = nil
			end
		end
	end
	ui.flash.BackgroundTransparency = 1
	ui.flash.BackgroundColor3 = C.white
	ui.flashGrad.Color = ColorSequence.new(C.white, C.white)
	ui.flashGrad.Rotation = 0
	ui.tint.BackgroundTransparency = 1
	ui.washTop.BackgroundTransparency = 1
	ui.washBottom.BackgroundTransparency = 1
	ui.impact1.Visible = false
	ui.impact2.Visible = false
	ui.vignette.Visible = false
	ui.speed.Visible = false
	Shot.blur = 0
	return f
end
