-- самопроверка песочницы
local Players = game:GetService("Players")
h.wait(0.5)
local plr = Players:GetPlayers()[1]
local char = plr.Character
local root = char.HumanoidRootPart
print("старт", root.Position)
h.wait(1)
print("после 1с (стоит на земле, y≈3)", root.Position)
mock.key(plr, "W", true)
h.wait(1)
mock.key(plr, "W", false)
print("после W 1с (сдвинулся на ~20)", root.Position)
mock.key(plr, "Space", true) mock.key(plr, "Space", false)
h.wait(0.25)
print("в прыжке", root.Position.Y)
h.wait(1)
print("приземлился", root.Position.Y)
-- рывок LinearVelocity
local att = Instance.new("Attachment", root)
local lv = Instance.new("LinearVelocity")
lv.Attachment0 = att
lv.MaxForce = 1e6
lv.VectorVelocity = Vector3.new(80, 0, 0)
lv.Parent = root
h.wait(0.25)
lv:Destroy()
print("после рывка +x ~20", root.Position)
-- твин
local p = Instance.new("Part")
p.Anchored = true
p.Position = Vector3.new(0, 10, 0)
p.Parent = workspace
local tw = game:GetService("TweenService"):Create(p, TweenInfo.new(1, Enum.EasingStyle.Linear), { Position = Vector3.new(10, 10, 0), Transparency = 1 })
tw:Play()
h.wait(0.5)
print("твин на полпути x≈5", p.Position.X, p.Transparency)
h.wait(0.6)
print("твин конец", p.Position.X, tw.PlaybackState)
-- луч и запрос
local r = workspace:Raycast(Vector3.new(0, 50, 0), Vector3.new(0, -100, 0))
print("луч вниз попал в", r and r.Instance.Name, r and r.Position.Y)
local parts = workspace:GetPartBoundsInRadius(root.Position, 4)
print("рядом с персонажем деталей", #parts)
-- удалённые события
local re = game.ReplicatedStorage.Remotes.Action
local got
re.OnServerEvent:Connect(function(who, a, b) got = { who.Name, a, b } end)
mock.asClient(plr, function() re:FireServer("M1", { dir = Vector3.new(1, 0, 0) }) end)
h.frames(2)
print("сервер получил", got and got[1], got and got[2], got and typeof(got[3].dir))
local back
mock.asClient(plr, function()
	game.ReplicatedStorage.Remotes.FX.OnClientEvent:Connect(function(name, data) back = name .. ":" .. tostring(data.n) end)
end)
game.ReplicatedStorage.Remotes.FX:FireAllClients("Hit", { n = 5 })
h.frames(2)
print("клиент получил", back)
