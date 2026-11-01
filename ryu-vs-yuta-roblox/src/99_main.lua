----------------------------------------------------------------------
-- ЗАПУСК
----------------------------------------------------------------------

local savedCharCF = nil
local currentPart = 0

local function parkCharacter()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		if not savedCharCF then
			savedCharCF = hrp.CFrame
		end
		hrp.Anchored = true
		char:PivotTo(CF(0, 3000, 3000))
	end
end

local function releaseCharacter()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and savedCharCF then
		char:PivotTo(savedCharCF)
		hrp.Anchored = false
	end
	savedCharCF = nil
end

local function setCoreUI(on)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, on)
	end)
	pcall(function()
		StarterGui:SetCore("TopbarEnabled", on)
	end)
end

local function waitUntil(t)
	while playing and songT < t do
		RunService.RenderStepped:Wait()
	end
end

local function finish(which)
	ui.black.BackgroundTransparency = 0
	playing = false
	Shot.update = nil
	updaters = {}
	if Shot.folder then
		Shot.folder:Destroy()
		Shot.folder = nil
	end
	for _, r in ipairs(rigs) do
		r:show(false)
	end
	fx.blur.Size = 0
	ui.speed.Visible = false
	ui.sub.Visible = false
	ui.subs = nil
	if which == 0 then
		ui.endText.Text = "Конец"
	else
		ui.endText.Text = "Часть " .. which .. " — конец"
	end
	ui.endScreen.Visible = true
	camera.CameraType = Enum.CameraType.Custom
	releaseCharacter()
	setCoreUI(true)
end

-- which: 0 — все части подряд, 1..4 — одна часть
local function play(which)
	if playing then
		return
	end
	currentPart = which
	ui.start.Visible = false
	ui.endScreen.Visible = false
	ui.black.BackgroundTransparency = 1
	setCoreUI(false)
	parkCharacter()
	songT = 0
	playing = true
	local all = { P1, P2, P3, P4 }
	local list = all
	if which ~= 0 then
		list = { all[which] }
	end
	local offset = 0
	for _, part in ipairs(list) do
		partOffset = offset
		ui.subs = part.subs
		for _, s in ipairs(part.shots) do
			waitUntil(offset + s[1])
			if not playing then
				return
			end
			s[2]()
		end
		offset = offset + part.fin
	end
	waitUntil(offset)
	finish(which)
end

local function onFrame(dt)
	if not playing then
		return
	end
	if dt > 0.1 then
		dt = 0.1
	end
	songT = songT + dt
	if Shot.update then
		Shot.update(songT - Shot.t0, dt)
	end
	for _, r in ipairs(rigs) do
		if r.active then
			r:update(songT)
		end
	end
	local i = 1
	while i <= #updaters do
		if updaters[i](dt) == false then
			table.remove(updaters, i)
		else
			i = i + 1
		end
	end
	-- короткий смаз на стыке кадров
	local since = songT - Shot.t0
	local cut = 0
	if since < 0.12 then
		cut = 7 * (1 - since / 0.12)
	end
	fx.blur.Size = math.max(Shot.blur or 0, cut)
	-- плавная тряска: повороты камеры по шуму
	camera.CameraType = Enum.CameraType.Scriptable
	local s = CF()
	if shake > 0.001 then
		local k = songT * 16
		local nx = noise(k, 0.31) + 0.5 * noise(k * 2.3, 5.1)
		local ny = noise(k, 7.7) + 0.5 * noise(k * 2.3, 9.4)
		local nz = noise(k, 3.3)
		s = ANG(rad(nx * shake * 0.7), rad(ny * shake * 0.7), rad(nz * shake * 0.5))
	end
	camera.CFrame = camCF * s
	camera.FieldOfView = camFOV
	FX.faceSprites()
	updateSubtitles()
end

local function setup()
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.GlobalShadows = false
	for _, ch in ipairs(Lighting:GetChildren()) do
		if ch:IsA("Atmosphere") then
			ch.Parent = nil
		end
	end
	fx.cc = Instance.new("ColorCorrectionEffect")
	fx.cc.Parent = Lighting
	fx.bloom = Instance.new("BloomEffect")
	fx.bloom.Parent = Lighting
	fx.blur = Instance.new("BlurEffect")
	fx.blur.Size = 0
	fx.blur.Parent = Lighting
	fx.dof = Instance.new("DepthOfFieldEffect")
	fx.dof.Enabled = false
	fx.dof.Parent = Lighting
	fx.atmo = Instance.new("Atmosphere")
	setLook({})

	buildUI()
	buildBattlefield(world)
	buildEyes(world)
	yuta = buildYuta(world, { angry = 1.0, mouth = "grit", blood = true, look = 0.02, lidDrop = 0.035 })
	ryu = buildRyu(world, { mouth = "smirk" })
	rika = buildRika(world)
	rigs = { yuta, ryu, rika }
	for _, r in ipairs(rigs) do
		r:show(false)
	end

	RunService.RenderStepped:Connect(onFrame)
	local function start(part)
		if not playing then
			task.spawn(play, part)
		end
	end
	ui.btnAll.Activated:Connect(function()
		start(0)
	end)
	ui.btn1.Activated:Connect(function()
		start(1)
	end)
	ui.btn2.Activated:Connect(function()
		start(2)
	end)
	ui.btn3.Activated:Connect(function()
		start(3)
	end)
	ui.btn4.Activated:Connect(function()
		start(4)
	end)
	ui.again.Activated:Connect(function()
		start(currentPart)
	end)
	ui.other.Activated:Connect(function()
		start(0)
	end)
	UserInputService.InputBegan:Connect(function(input)
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.One then
			start(1)
		elseif input.KeyCode == Enum.KeyCode.Two then
			start(2)
		elseif input.KeyCode == Enum.KeyCode.Three then
			start(3)
		elseif input.KeyCode == Enum.KeyCode.Four then
			start(4)
		elseif input.KeyCode == Enum.KeyCode.Space then
			start(0)
		elseif input.KeyCode == Enum.KeyCode.R then
			start(currentPart)
		end
	end)
	if CONFIG.PART == 1 or CONFIG.PART == 2 or CONFIG.PART == 3 or CONFIG.PART == 4 then
		currentPart = CONFIG.PART
	end
	if CONFIG.AUTO_START then
		task.delay(1, function()
			start(currentPart)
		end)
	end
end

setup()
