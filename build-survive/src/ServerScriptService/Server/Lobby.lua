-- Лобби: таблица рекордов сервера.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Util = require(Shared.Util)

local Lobby = {}

local function rowsFrame(): Frame?
	local map = workspace:FindFirstChild("Map")
	local lobby = map and map:FindFirstChild("Lobby")
	local board = lobby and lobby:FindFirstChild("Leaderboard")
	local gui = board and board:FindFirstChild("SurfaceGui")
	return gui and gui:FindFirstChild("Rows") :: Frame?
end

function Lobby.refresh()
	local rows = rowsFrame()
	if not rows then
		return
	end
	local list = {}
	for _, p in Players:GetPlayers() do
		table.insert(list, { name = p.DisplayName, wave = p:GetAttribute("BestWave") or 0, gold = p:GetAttribute("Gold") or 0 })
	end
	table.sort(list, function(a, b)
		if a.wave ~= b.wave then
			return a.wave > b.wave
		end
		return a.gold > b.gold
	end)
	rows:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.01, 0)
	layout.Parent = rows
	if #list == 0 then
		return
	end
	for i = 1, math.min(8, #list) do
		local e = list[i]
		local row = Instance.new("TextLabel")
		row.Size = UDim2.fromScale(1, 0.11)
		row.BackgroundTransparency = i % 2 == 0 and 1 or 0.85
		row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		row.BorderSizePixel = 0
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
		row.TextColor3 = i == 1 and Color3.fromRGB(255, 214, 90) or Color3.fromRGB(230, 236, 250)
		row.Text = string.format("  %d. %s — волна %d • %s зол.", i, e.name, e.wave, Util.formatNumber(e.gold))
		row.LayoutOrder = i
		row.Parent = rows
	end
end

function Lobby.init()
	task.spawn(function()
		while true do
			Lobby.refresh()
			task.wait(8)
		end
	end)
end

return Lobby
