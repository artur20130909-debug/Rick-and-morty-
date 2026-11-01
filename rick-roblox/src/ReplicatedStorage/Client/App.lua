-- Клиент целиком: загрузка → главное меню → история (с начала или с главы 2) → снова меню.
-- Пауза (P / кнопка II).
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ContentProvider = game:GetService("ContentProvider")

local App = {}
local ctx
local inStory = false
local paused = false
local wasActive = false

local function coreGui()
	-- прячем лишнее из стандартного интерфейса Roblox (список игроков, рюкзак, чат оставляем)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) end)
	-- кнопка «Сброс персонажа» сломала бы сценки — отключаем (повторяем, пока CoreScripts не готовы)
	task.spawn(function()
		for _ = 1, 20 do
			local ok = pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)
			if ok then break end
			task.wait(0.5)
		end
	end)
end

-- экран загрузки
local function loading()
	local G, Config = ctx.Gui, ctx.Config
	local sg, root = G.screen("Loading", 100)
	local bg = G.frame(root, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 14, 9) })
	local logo = G.logo(root, ctx.Util.upper("Рик и Морти"), 64, UDim2.new(0.5, 0, 0.5, -90))
	local _l = logo
	local dot = G.frame(root, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 40), Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Config.Colors.Portal })
	G.corner(dot, UDim.new(0.5, 0))
	local gr = G.gradient(dot, { Config.Colors.PortalLight, Config.Colors.Portal, Config.Colors.PortalDark, Config.Colors.Portal, Config.Colors.PortalLight }, 0)
	local label = G.label(root, "Загрузка…", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 80), Size = UDim2.fromOffset(400, 30),
		FontFace = G.Fonts.BodyBold, TextSize = 20, TextColor3 = Color3.fromRGB(200, 230, 200) })
	local spinning = true
	task.spawn(function()
		while spinning do
			gr.Rotation = (gr.Rotation + 9) % 360
			task.wait(1 / 30)
		end
	end)
	return function()
		spinning = false
		G.tween(bg, 0.6, { BackgroundTransparency = 1 })
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("TextLabel") then G.tween(d, 0.5, { TextTransparency = 1 }) end
			if d:IsA("Frame") then G.tween(d, 0.5, { BackgroundTransparency = 1 }) end
			if d:IsA("UIStroke") then G.tween(d, 0.5, { Transparency = 1 }) end
		end
		task.delay(0.7, function() sg:Destroy() end)
	end, label
end

local function toMenu()
	local Story, Menu, Hud, Controls, Cine = ctx.Story, ctx.Menu, ctx.Hud, ctx.Controls, ctx.Cine
	inStory = false
	paused = false
	ctx.Util.setPaused(false)
	ctx.Audio.setPaused(false)
	Story.cleanup()
	Hud.gameplay(false)
	Controls.setActive(false)
	Controls.freeze(true)
	ctx.Prompts.setEnabled(false)
	Hud.fadeSet(1)
	-- персонаж ждёт в коридоре (вне кадра меню) и скрыт у себя на экране
	local hide = workspace.House.Markers:FindFirstChild("MenuHide")
	if hide then Controls.place(hide.CFrame, true) end
	Story.hideBody(true)
	Menu.sceneStart()
	Hud.fade(0, 1.2)
	Menu.show(function(chapter)
		Menu.enterPortal()
		Menu.hide()
		Menu.sceneStop()
		Cine.release()
		inStory = true
		Story.start(toMenu, chapter)
	end)
end
App.toMenu = toMenu

local function togglePause()
	local Menu, Story = ctx.Menu, ctx.Story
	if not inStory or Story.state() == "ending" then return end
	if paused then
		Menu.unpause()
		paused = false
		ctx.Util.setPaused(false)
		ctx.Audio.setPaused(false)
		if wasActive then ctx.Controls.freeze(false) end
		return
	end
	paused = true
	wasActive = Story.state() == "roam"
	ctx.Util.setPaused(true)
	ctx.Audio.setPaused(true)
	ctx.Controls.freeze(true)
	Menu.pause(function()
		paused = false
		ctx.Util.setPaused(false)
		ctx.Audio.setPaused(false)
		if wasActive then ctx.Controls.freeze(false) end
	end, function()
		paused = false
		-- обычное ожидание: U.wait на паузе стоит на месте (игра ещё на паузе до toMenu)
		ctx.Hud.fade(1, 0.5)
		task.wait(0.5)
		toMenu()
	end)
end

function App.start(c)
	ctx = c
	coreGui()
	local done, label = loading()
	-- ждём, пока сервер построит дом
	local house = workspace:WaitForChild("House", 60)
	while house and not house:GetAttribute("Ready") do task.wait(0.1) end
	label.Text = "Почти готово…"
	-- модули, которым нужен дом
	for _, name in ipairs({ "World", "Outline", "Story" }) do
		local ok, err = pcall(function() c[name].init(c) end)
		if not ok then warn("[RM] init " .. name .. ": " .. tostring(err)) end
	end
	-- подгрузить звуки заранее (не дольше 6 секунд)
	local list = {}
	for _, k in ipairs({ "MusicMenu", "MusicMorning", "SfxAtlas" }) do
		local id = c.Build.asset(c.Config.Sounds[k])
		if id ~= "" then
			local s = Instance.new("Sound")
			s.SoundId = id
			table.insert(list, s)
		end
	end
	if #list > 0 then
		local fin = false
		task.spawn(function() pcall(function() ContentProvider:PreloadAsync(list) end); fin = true end)
		local t0 = os.clock()
		while not fin and os.clock() - t0 < 6 do task.wait(0.1) end
	end
	local char = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
	char:WaitForChild("HumanoidRootPart", 10)
	c.Controls.onPause = togglePause
	c.Hud.pauseButton(togglePause)
	toMenu()
	done()
end

return App
