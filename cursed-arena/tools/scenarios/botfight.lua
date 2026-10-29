-- Боты дерутся друг с другом; считаем события эффектов
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local plr = Players:GetPlayers()[1]
local counts = {}
mock.asClient(plr, function()
	RS.Remotes.FX.OnClientEvent:Connect(function(name, data)
		counts[name] = (counts[name] or 0) + 1
		if name == "Anim" then counts["anim:" .. tostring(data.a)] = (counts["anim:" .. tostring(data.a)] or 0) + 1 end
	end)
	RS.Remotes.Action:FireServer("Bots", 6, 3)
end)
h.wait(1)
local char = plr.Character
char.HumanoidRootPart.CFrame = CFrame.new(220, 5, 220)
for i = 1, 12 do
	h.wait(10)
	local line = {}
	for _, b in ipairs(workspace.Bots:GetChildren()) do
		local hum = b:FindFirstChildOfClass("Humanoid")
		if hum and b:GetAttribute("Kind") == "bot" then
			line[#line + 1] = string.format("%s[%s]%d%s", b.Name, tostring(b:GetAttribute("Char")):sub(1, 5), math.floor(hum.Health), b:GetAttribute("Awakened") and "*" or "")
		end
	end
	print("t=" .. i * 10, table.concat(line, " "))
end
local keys = {}
for k in pairs(counts) do keys[#keys + 1] = k end
table.sort(keys)
local out = {}
for _, k in ipairs(keys) do out[#out + 1] = k .. "=" .. counts[k] end
print("FX: " .. table.concat(out, ", "))
