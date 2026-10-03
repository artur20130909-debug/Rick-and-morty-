-- Лобби: постройка (LobbyMap, а если он упал — простое запасное лобби), появление игроков,
-- кабинки: кто стоит в зоне кабинки, тот через Config.BoothCountdown секунд уезжает в дом.
local Players = game:GetService("Players")

local Lobby = {}
local ctx, Config, Net, B
local timers = {}        -- [кабинка] = os.clock() старта

local function insideZone(zone, pos)
	local l = zone.CFrame:PointToObjectSpace(pos)
	local s = zone.Size / 2
	return math.abs(l.X) <= s.X and math.abs(l.Z) <= s.Z and l.Y >= -s.Y - 1 and l.Y <= s.Y + 5
end

-- запасное лобби: площадка, точка появления и четыре кабинки (если LobbyMap не построился)
local function fallbackLobby()
	local model = B.model(workspace, "Lobby")
	B.part(model, "Ground", Vector3.new(220, 2, 220), CFrame.new(0, -1, 0), Color3.fromRGB(60, 62, 66), Enum.Material.Asphalt)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.5, 30)
	spawn.Material = Enum.Material.Metal
	spawn.Parent = model
	local boothsF = B.folder(model, "Booths")
	local booths = {}
	local diffs = { "easy", "normal", "hard", "endless" }
	for i, d in ipairs(diffs) do
		local x = (i - 2.5) * 18
		local bm = B.model(boothsF, "Booth_" .. i)
		B.attrs(bm, { Kind = "Booth", Index = i, Difficulty = d, Max = Config.MaxPlayersPerHouse, Count = 0, Countdown = -1 })
		B.part(bm, "Floor", Vector3.new(12, 0.4, 12), CFrame.new(x, 0.2, -20), Color3.fromRGB(255, 170, 40), Enum.Material.Neon)
		B.marker(bm, "Zone", Vector3.new(11, 6, 11), CFrame.new(x, 3, -20))
		local sign = B.part(bm, "Sign", Vector3.new(12, 4, 0.5), CFrame.new(x, 9, -26), Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic)
		sign:SetAttribute("ScreenFace", "Front")
		table.insert(booths, bm)
	end
	return { model = model, spawn = spawn, booths = booths, kiosks = {}, cells = {} }
end

function Lobby.sendToLobby(plr)
	if not plr.Parent then return end
	plr:SetAttribute("MatchId", 0)
	plr:SetAttribute("Alive", true)
	plr:SetAttribute("Hidden", false)
	plr:SetAttribute("Money", 0)
	plr:SetAttribute("Apples", 0)
	plr:SetAttribute("Static", 0)
	plr:SetAttribute("Sprinting", false)
	plr:SetAttribute("Crouching", false)
	plr:SetAttribute("Flashlight", false)
	if ctx.Items then ctx.Items.clear(plr) end
	plr.CameraMode = Enum.CameraMode.Classic
	local ok, err = pcall(function() plr:LoadCharacter() end)
	if not ok then warn("[AA] LoadCharacter: " .. tostring(err)) end
	local spawn = Lobby.lobby and Lobby.lobby.spawn
	local char = plr.Character
	if spawn and char then char:PivotTo(spawn.CFrame + Vector3.new((math.random() - 0.5) * 6, 4, (math.random() - 0.5) * 6)) end
	Net.event("Scene"):FireClient(plr, "lobby", {})
end

local function boothTick()
	local lobby = Lobby.lobby
	if not lobby then return end
	for _, booth in ipairs(lobby.booths or {}) do
		local zone = booth:FindFirstChild("Zone", true)
		if zone then
			local list = {}
			local max = booth:GetAttribute("Max") or Config.MaxPlayersPerHouse
			for _, plr in ipairs(Players:GetPlayers()) do
				if (plr:GetAttribute("MatchId") or 0) == 0 and #list < max then
					local char = plr.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if hrp and hum and hum.Health > 0 and insideZone(zone, hrp.Position) then table.insert(list, plr) end
				end
			end
			booth:SetAttribute("Count", #list)
			if #list > 0 then
				if not timers[booth] then timers[booth] = os.clock() + Config.BoothCountdown end
				local left = timers[booth] - os.clock()
				booth:SetAttribute("Countdown", math.max(0, math.ceil(left)))
				if left <= 0 then
					timers[booth] = nil
					booth:SetAttribute("Countdown", -1)
					booth:SetAttribute("Count", 0)
					ctx.Match.start(list, booth:GetAttribute("Difficulty") or "normal")
				end
			else
				timers[booth] = nil
				booth:SetAttribute("Countdown", -1)
			end
		end
	end
end

function Lobby.init(c)
	ctx = c
	Config = c.Config
	Net = c.Net
	B = c.Build
	local lobby = nil
	if c.LobbyMap and c.LobbyMap.build then
		local ok, res = pcall(c.LobbyMap.build, workspace)
		if ok and res and res.model then
			lobby = res
		else
			warn("[AA] LobbyMap не построился, включаю запасное лобби: " .. tostring(res))
		end
	end
	if not lobby then
		local old = workspace:FindFirstChild("Lobby")
		if old then old:Destroy() end
		lobby = fallbackLobby()
	end
	Lobby.lobby = lobby
	local function onPlayer(plr)
		if c.Data then c.Data.get(plr) end
		Lobby.sendToLobby(plr)
	end
	Players.PlayerAdded:Connect(function(plr) task.spawn(onPlayer, plr) end)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(boothTick)
			if not ok then
				Lobby.errs = (Lobby.errs or 0) + 1
				if Lobby.errs <= 3 then warn("[AA] Ошибка кабинок: " .. tostring(err)) end
			end
		end
	end)
end

return Lobby
