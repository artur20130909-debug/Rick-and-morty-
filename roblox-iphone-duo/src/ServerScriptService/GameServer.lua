-- Сервер игры «Мой iPhone Duo»: строит карту, собирает телефон и кладёт его каждому игроку в инвентарь,
-- считает батарею и выполняет действия приложений (фонарик, музыка, чат, звонки, карта, турбо, цвет).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage:WaitForChild("PhoneConfig"))
local Map = require(script.Parent:WaitForChild("MapBuilder"))
local make = Map.make

Map.build()

-- Каналы связи с клиентом
local remotes = make("Folder", { Name = "PhoneRemotes", Parent = ReplicatedStorage })
local actionEvent = make("RemoteEvent", { Name = "PhoneAction", Parent = remotes })
local notifyEvent = make("RemoteEvent", { Name = "PhoneNotify", Parent = remotes })

local function now()
	return workspace:GetServerTimeNow()
end

----------------------------------------------------------------------------------------------------
-- Модель телефона: две половинки, петля посередине, два экрана, двойная камера и вспышка.
----------------------------------------------------------------------------------------------------
local HALF_W, HALF_H, THICK, GAP = 0.8, 1.6, 0.1, 0.06

local function phonePart(name, size, color, material, parent)
	return make("Part", {
		Name = name,
		Size = size,
		Color = color,
		Material = material or Enum.Material.Metal,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Massless = true,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Parent = parent,
	})
end

local function screenGui(part, name)
	local gui = make("SurfaceGui", {
		Name = name,
		Face = Enum.NormalId.Back, -- задняя грань детали смотрит на игрока, который держит телефон
		LightInfluence = 0,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 160,
		Parent = part,
	})
	local bg = make("Frame", { Name = "Bg", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Parent = gui })
	make("UIGradient", { Name = "Wallpaper", Rotation = 90, Color = ColorSequence.new(Config.Wallpapers[1].A, Config.Wallpapers[1].B), Parent = bg })
	return gui, bg
end

local function buildPhoneTool()
	local tool = make("Tool", {
		Name = Config.ToolName,
		ToolTip = "Твой телефон с двумя экранами",
		CanBeDropped = false,
		RequiresHandle = true,
		Grip = Config.Grip,
	})
	local bodyColor = Config.Colors[1].Color
	local handle = phonePart("Handle", Vector3.new(HALF_W, HALF_H, THICK), bodyColor, Enum.Material.Metal, tool)
	handle.CFrame = CFrame.new()
	local base = handle.CFrame
	local rightX = HALF_W + GAP

	local right = phonePart("RightBody", Vector3.new(HALF_W, HALF_H, THICK), bodyColor, Enum.Material.Metal, tool)
	right.CFrame = base * CFrame.new(rightX, 0, 0)

	local hinge = phonePart("Hinge", Vector3.new(HALF_H, 0.09, 0.09), Color3.fromRGB(120, 120, 128), Enum.Material.Metal, tool)
	hinge.Shape = Enum.PartType.Cylinder
	hinge.CFrame = base * CFrame.new(rightX / 2, 0, 0) * CFrame.Angles(0, 0, math.rad(90))

	-- Экраны (на стороне +Z, к игроку)
	local leftScreen = phonePart("LeftScreen", Vector3.new(HALF_W - 0.06, HALF_H - 0.08, 0.01), Color3.fromRGB(10, 10, 14), Enum.Material.Glass, tool)
	leftScreen.CFrame = base * CFrame.new(0, 0, THICK / 2 + 0.006)
	local rightScreen = phonePart("RightScreen", Vector3.new(HALF_W - 0.06, HALF_H - 0.08, 0.01), Color3.fromRGB(10, 10, 14), Enum.Material.Glass, tool)
	rightScreen.CFrame = base * CFrame.new(rightX, 0, THICK / 2 + 0.006)

	local _, lbg = screenGui(leftScreen, "Display")
	make("TextLabel", { Name = "Clock", Size = UDim2.fromScale(1, 0.22), Position = UDim2.fromScale(0, 0.12), BackgroundTransparency = 1,
		Text = "12:00", TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), Parent = lbg })
	make("TextLabel", { Name = "Label", Size = UDim2.fromScale(1, 0.08), Position = UDim2.fromScale(0, 0.36), BackgroundTransparency = 1,
		Text = "iPhone Duo", TextScaled = true, Font = Enum.Font.Gotham, TextColor3 = Color3.new(1, 1, 1), Parent = lbg })
	make("TextLabel", { Name = "Battery", Size = UDim2.fromScale(0.9, 0.07), Position = UDim2.fromScale(0.05, 0.02), BackgroundTransparency = 1,
		Text = "100%", TextScaled = true, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.new(1, 1, 1), Parent = lbg })

	local _, rbg = screenGui(rightScreen, "Display")
	make("TextLabel", { Name = "AppIcon", Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.25), BackgroundTransparency = 1,
		Text = "📱", TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), Parent = rbg })
	make("TextLabel", { Name = "AppName", Size = UDim2.fromScale(1, 0.09), Position = UDim2.fromScale(0, 0.6), BackgroundTransparency = 1,
		Text = "Главный экран", TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), Parent = rbg })

	-- Задняя сторона левой половинки: двойная камера и вспышка
	local bump = phonePart("CameraBump", Vector3.new(0.36, 0.36, 0.03), Color3.fromRGB(40, 40, 45), Enum.Material.Glass, tool)
	bump.CFrame = base * CFrame.new(-0.14, 0.55, -THICK / 2 - 0.015)
	for i, dy in ipairs({ 0.08, -0.08 }) do
		local lens = phonePart("Lens" .. i, Vector3.new(0.03, 0.13, 0.13), Color3.fromRGB(10, 10, 20), Enum.Material.Glass, tool)
		lens.Shape = Enum.PartType.Cylinder
		lens.CFrame = bump.CFrame * CFrame.new(-0.06, dy, -0.02) * CFrame.Angles(0, math.rad(90), 0)
	end
	local flash = phonePart("Flash", Vector3.new(0.06, 0.06, 0.02), Color3.fromRGB(255, 240, 200), Enum.Material.SmoothPlastic, tool)
	flash.CFrame = bump.CFrame * CFrame.new(0.1, 0.08, -0.02)
	make("SpotLight", { Name = "Torch", Face = Enum.NormalId.Front, Angle = 70, Range = 45, Brightness = 6,
		Color = Color3.fromRGB(255, 245, 225), Shadows = true, Enabled = false, Parent = flash })

	-- Звуки из телефона (их слышат все рядом)
	make("Sound", { Name = "Music", Volume = Config.MusicVolume, Looped = true, RollOffMaxDistance = 80, Parent = handle })
	make("Sound", { Name = "Ring", SoundId = Config.Sounds.Ring, Volume = 0.8, PlaybackSpeed = 1.2, RollOffMaxDistance = 60, Parent = handle })
	make("Sound", { Name = "Shutter", SoundId = Config.Sounds.Shutter, Volume = 0.7, PlaybackSpeed = 1.6, RollOffMaxDistance = 40, Parent = handle })

	-- Всё приваривается к ручке
	for _, p in ipairs(tool:GetChildren()) do
		if p:IsA("BasePart") and p ~= handle then
			make("WeldConstraint", { Part0 = handle, Part1 = p, Parent = p })
		end
	end
	return tool
end

local template = buildPhoneTool()
template.Parent = ServerStorage

----------------------------------------------------------------------------------------------------
-- Состояние игроков
----------------------------------------------------------------------------------------------------
local state = {} -- [player] = { flashlight, music, lastMsg, lastCall, lastTp, turboUntil }

local function getPhone(player)
	local char = player.Character
	local tool = char and char:FindFirstChild(Config.ToolName)
	if tool and tool:IsA("Tool") then
		return tool, true
	end
	local bp = player:FindFirstChildOfClass("Backpack")
	tool = bp and bp:FindFirstChild(Config.ToolName)
	if tool and tool:IsA("Tool") then
		return tool, false
	end
	return nil, false
end

local function notify(player, kind, data)
	notifyEvent:FireClient(player, kind, data or {})
end

local function applyColor(tool, index)
	local entry = Config.Colors[index] or Config.Colors[1]
	for _, name in ipairs({ "Handle", "RightBody" }) do
		local p = tool:FindFirstChild(name)
		if p then
			p.Color = entry.Color
		end
	end
	local hinge = tool:FindFirstChild("Hinge")
	if hinge then
		hinge.Color = entry.Color:Lerp(Color3.new(0, 0, 0), 0.3)
	end
end

local function setFlashlight(player, on)
	local st = state[player]
	if not st then
		return
	end
	st.flashlight = on and true or false
	local tool = getPhone(player)
	local flash = tool and tool:FindFirstChild("Flash")
	if flash then
		flash.Material = st.flashlight and Enum.Material.Neon or Enum.Material.SmoothPlastic
		local torch = flash:FindFirstChild("Torch")
		if torch then
			torch.Enabled = st.flashlight
		end
	end
	player:SetAttribute("Flashlight", st.flashlight)
end

local function stopMusic(player)
	local st = state[player]
	if st then
		st.music = false
	end
	local tool = getPhone(player)
	local snd = tool and tool.Handle:FindFirstChild("Music")
	if snd then
		snd:Stop()
	end
	player:SetAttribute("MusicId", "")
end

local function playMusic(player, id)
	local tool = getPhone(player)
	local snd = tool and tool.Handle:FindFirstChild("Music")
	if not snd then
		return
	end
	snd:Stop()
	snd.SoundId = "rbxassetid://" .. id
	snd:Play()
	state[player].music = true
	player:SetAttribute("MusicId", id)
	task.delay(4, function()
		if snd.Parent and snd.SoundId == "rbxassetid://" .. id and not snd.IsLoaded then
			notify(player, "toast", { text = "Трек " .. id .. " не загрузился. Возможно, Roblox закрыл этот звук — попробуй другой ID." })
		end
	end)
end

local function setScreen(player, icon, name)
	local tool = getPhone(player)
	local scr = tool and tool:FindFirstChild("RightScreen")
	local bg = scr and scr:FindFirstChild("Display") and scr.Display:FindFirstChild("Bg")
	if bg then
		bg.AppIcon.Text = icon
		bg.AppName.Text = name
	end
end

local function givePhone(player)
	local tool = getPhone(player)
	if not tool then
		tool = template:Clone()
		tool.Parent = player:WaitForChild("Backpack")
	end
	applyColor(tool, player:GetAttribute("PhoneColor") or 1)
	-- после возрождения фонарик и музыка выключены
	local st = state[player]
	if st then
		st.flashlight = false
		st.music = false
	end
	player:SetAttribute("Flashlight", false)
	player:SetAttribute("MusicId", "")
end

local function onPlayerAdded(player)
	state[player] = { flashlight = false, music = false, lastMsg = 0, lastCall = 0, lastTp = 0, turboUntil = 0 }
	player:SetAttribute("Battery", Config.Battery.Start)
	player:SetAttribute("Charging", false)
	player:SetAttribute("PhoneColor", 1)
	player:SetAttribute("TurboReadyAt", 0)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid")
		task.wait(0.1)
		givePhone(player)
	end)
	if player.Character then
		givePhone(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end

Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
end)

----------------------------------------------------------------------------------------------------
-- Действия приложений
----------------------------------------------------------------------------------------------------
local function hasPower(player)
	if (player:GetAttribute("Battery") or 0) <= 0 then
		notify(player, "toast", { text = "🔋 Телефон разряжен! Встань на зелёную зарядку ⚡" })
		return false
	end
	return true
end

local function spendBattery(player, amount)
	local b = player:GetAttribute("Battery") or 0
	player:SetAttribute("Battery", math.max(0, b - amount))
end

local function filterFor(text, fromId, toId)
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, fromId)
	end)
	if not ok then
		return nil
	end
	local ok2, filtered = pcall(function()
		return result:GetChatForUserAsync(toId)
	end)
	if not ok2 then
		return nil
	end
	return filtered
end

local handlers = {}

function handlers.flashlight(player, on)
	if on and not hasPower(player) then
		return
	end
	setFlashlight(player, on == true)
end

function handlers.music(player, id)
	if id == nil or id == "" then
		stopMusic(player)
		return
	end
	id = tostring(id):gsub("%D", "")
	if #id < 3 or #id > 20 then
		notify(player, "toast", { text = "Это не похоже на ID звука. Нужны только цифры." })
		return
	end
	if not hasPower(player) then
		return
	end
	playMusic(player, id)
end

function handlers.photo(player)
	if not hasPower(player) then
		return
	end
	local tool = getPhone(player)
	if tool then
		tool.Handle.Shutter:Play()
		local flash = tool:FindFirstChild("Flash")
		local torch = flash and flash:FindFirstChild("Torch")
		if torch and not torch.Enabled then
			torch.Enabled = true
			task.delay(0.12, function()
				if torch.Parent and not (state[player] and state[player].flashlight) then
					torch.Enabled = false
				end
			end)
		end
	end
	spendBattery(player, 0.5)
end

function handlers.screen(player, icon, name)
	if type(icon) ~= "string" or type(name) ~= "string" then
		return
	end
	setScreen(player, icon:sub(1, 32), name:sub(1, 64))
end

function handlers.color(player, index)
	index = tonumber(index)
	if not index or not Config.Colors[index] then
		return
	end
	player:SetAttribute("PhoneColor", index)
	local tool = getPhone(player)
	if tool then
		applyColor(tool, index)
	end
end

function handlers.teleport(player, index)
	index = tonumber(index)
	local loc = index and Config.Locations[index]
	local st = state[player]
	if not loc or not st or now() - st.lastTp < 2 then
		return
	end
	if not hasPower(player) then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	st.lastTp = now()
	local _, yaw = root.CFrame:ToOrientation()
	char:PivotTo(CFrame.new(loc.Position) * CFrame.Angles(0, yaw, 0))
	spendBattery(player, 2)
	notify(player, "toast", { text = loc.Icon .. " Ты в месте «" .. loc.Name .. "»" })
end

function handlers.turbo(player)
	local st = state[player]
	if not st then
		return
	end
	if now() < (player:GetAttribute("TurboReadyAt") or 0) then
		return
	end
	if (player:GetAttribute("Battery") or 0) < Config.Turbo.Cost then
		notify(player, "toast", { text = "🔋 Для турбо нужно хотя бы " .. Config.Turbo.Cost .. "% заряда" })
		return
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	spendBattery(player, Config.Turbo.Cost)
	player:SetAttribute("TurboReadyAt", now() + Config.Turbo.Cooldown)
	local token = now()
	st.turboUntil = token
	hum.WalkSpeed = Config.Turbo.Speed
	notify(player, "toast", { text = "🚀 Турбо на " .. Config.Turbo.Duration .. " секунд!" })
	task.delay(Config.Turbo.Duration, function()
		if hum.Parent and st.turboUntil == token then
			hum.WalkSpeed = 16
		end
	end)
end

function handlers.message(player, text)
	local st = state[player]
	if not st or type(text) ~= "string" then
		return
	end
	text = text:gsub("[%c]", " ")
	text = text:sub(1, Config.MessageMaxLength)
	if text:match("^%s*$") or now() - st.lastMsg < Config.MessageCooldown then
		return
	end
	if not hasPower(player) then
		return
	end
	st.lastMsg = now()
	for _, other in ipairs(Players:GetPlayers()) do
		local filtered = filterFor(text, player.UserId, other.UserId)
		if filtered then
			notify(other, "message", { from = player.DisplayName, fromId = player.UserId, text = filtered })
		end
	end
end

function handlers.call(player, targetId)
	local st = state[player]
	local target = Players:GetPlayerByUserId(tonumber(targetId) or 0)
	if not st or not target or target == player then
		return
	end
	if now() - st.lastCall < Config.CallCooldown then
		notify(player, "toast", { text = "Подожди пару секунд перед новым звонком" })
		return
	end
	if not hasPower(player) then
		return
	end
	st.lastCall = now()
	spendBattery(player, 1)
	notify(target, "call", { from = player.DisplayName, fromId = player.UserId })
	notify(player, "toast", { text = "📞 Звоним " .. target.DisplayName .. "…" })
	local tool = getPhone(target)
	if tool then
		local ring = tool.Handle.Ring
		task.spawn(function()
			for _ = 1, 4 do
				if not ring.Parent then
					break
				end
				ring:Play()
				task.wait(0.6)
			end
		end)
	end
end

function handlers.callAnswer(player, callerId, accepted)
	local caller = Players:GetPlayerByUserId(tonumber(callerId) or 0)
	if not caller then
		return
	end
	notify(caller, "callResult", { name = player.DisplayName, accepted = accepted == true })
end

actionEvent.OnServerEvent:Connect(function(player, action, ...)
	local fn = type(action) == "string" and handlers[action]
	if fn then
		local ok, err = pcall(fn, player, ...)
		if not ok then
			warn("[iPhone Duo] ошибка в действии " .. action .. ": " .. tostring(err))
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- Батарея, зарядки, часы на экране и смена дня и ночи
----------------------------------------------------------------------------------------------------
local function nearCharger(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, pos in ipairs(Config.Chargers) do
		local d = root.Position - pos
		if Vector3.new(d.X, 0, d.Z).Magnitude <= Config.Battery.ChargeRadius and math.abs(d.Y) < 6 then
			return true
		end
	end
	return false
end

local function clockText()
	local t = Lighting.ClockTime
	local h = math.floor(t)
	local m = math.floor((t - h) * 60)
	return string.format("%02d:%02d", h, m)
end

local STEP = 0.5
task.spawn(function()
	while true do
		task.wait(STEP)
		-- сутки: 24 игровых часа за Config.DayLengthMinutes реальных минут
		Lighting.ClockTime = (Lighting.ClockTime + 24 * STEP / (Config.DayLengthMinutes * 60)) % 24
		local clock = clockText()
		for _, player in ipairs(Players:GetPlayers()) do
			local st = state[player]
			if st then
				local tool, equipped = getPhone(player)
				local battery = player:GetAttribute("Battery") or 0
				local charging = nearCharger(player)
				if charging then
					battery = math.min(100, battery + Config.Battery.ChargeRate * STEP)
				elseif equipped then
					local drain = Config.Battery.IdleDrain
					if st.flashlight then
						drain = drain + Config.Battery.FlashlightDrain
					end
					if st.music then
						drain = drain + Config.Battery.MusicDrain
					end
					battery = math.max(0, battery - drain * STEP)
				end
				if player:GetAttribute("Charging") ~= charging then
					player:SetAttribute("Charging", charging)
				end
				local wasDead = (player:GetAttribute("Battery") or 0) <= 0
				player:SetAttribute("Battery", battery)
				if battery <= 0 and not wasDead then
					setFlashlight(player, false)
					stopMusic(player)
					notify(player, "toast", { text = "🔋 Телефон сел! Найди зелёную зарядку ⚡ (одна есть у спавна)" })
				end
				if tool then
					local disp = tool.LeftScreen:FindFirstChild("Display")
					local bg = disp and disp:FindFirstChild("Bg")
					if bg then
						bg.Clock.Text = clock
						bg.Battery.Text = (charging and "⚡" or "") .. math.floor(battery) .. "%"
						bg.Visible = battery > 0
					end
					local rdisp = tool.RightScreen:FindFirstChild("Display")
					if rdisp and rdisp:FindFirstChild("Bg") then
						rdisp.Bg.Visible = battery > 0
					end
				end
			end
		end
	end
end)
