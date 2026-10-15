-- Сценарий для визуальной проверки: проходит игру и выгружает интерфейс и мир в JSON.
local G = M.G
local function svc(name)
	return M.service(name)
end
local SCREEN = SCREEN_SIZE or { 1280, 720 }
M.screenSize = SCREEN

---------------------------------------------------------------- JSON
local function jstr(s)
	s = string.gsub(s, '[%c"\\]', function(c)
		if c == '"' then
			return '\\"'
		elseif c == "\\" then
			return "\\\\"
		elseif c == "\n" then
			return "\\n"
		elseif c == "\t" then
			return "\\t"
		end
		return string.format("\\u%04x", string.byte(c))
	end)
	return '"' .. s .. '"'
end
local ids = setmetatable({}, { __mode = "k" })
local nextId = 0
local function idOf(p)
	if not ids[p] then
		nextId += 1
		ids[p] = nextId
	end
	return ids[p]
end
local function num(v)
	if v ~= v or v == math.huge or v == -math.huge then
		return "0"
	end
	return string.format("%.6g", v)
end
local function enc(v)
	local t = M.typeof(v)
	if t == "number" then
		return num(v)
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "string" then
		return jstr(v)
	elseif t == "Color3" then
		return string.format('{"t":"C3","v":[%s,%s,%s]}', num(v.R), num(v.G), num(v.B))
	elseif t == "UDim2" then
		local x, y = rawget(v, "X"), rawget(v, "Y")
		return string.format('{"t":"UD2","v":[%s,%s,%s,%s]}', num(x.Scale), num(x.Offset), num(y.Scale), num(y.Offset))
	elseif t == "UDim" then
		return string.format('{"t":"UD","v":[%s,%s]}', num(v.Scale), num(v.Offset))
	elseif t == "Vector2" then
		return string.format('{"t":"V2","v":[%s,%s]}', num(v.X), num(v.Y))
	elseif t == "Vector3" then
		return string.format('{"t":"V3","v":[%s,%s,%s]}', num(v.X), num(v.Y), num(v.Z))
	elseif t == "CFrame" then
		local p = {}
		for i = 1, 12 do
			p[i] = num(rawget(v, i))
		end
		return '{"t":"CF","v":[' .. table.concat(p, ",") .. "]}"
	elseif t == "EnumItem" then
		return jstr(v.Name)
	elseif t == "ColorSequence" then
		local ks = {}
		for _, k in ipairs(v.Keypoints) do
			table.insert(ks, string.format("[%s,%s,%s,%s]", num(k.Time), num(k.Value.R), num(k.Value.G), num(k.Value.B)))
		end
		return '{"t":"CS","v":[' .. table.concat(ks, ",") .. "]}"
	elseif t == "NumberSequence" then
		local ks = {}
		for _, k in ipairs(v.Keypoints) do
			table.insert(ks, string.format("[%s,%s]", num(k.Time), num(k.Value)))
		end
		return '{"t":"NS","v":[' .. table.concat(ks, ",") .. "]}"
	elseif t == "NumberRange" then
		return string.format('{"t":"NR","v":[%s,%s]}', num(v.Min), num(v.Max))
	elseif t == "Font" then
		return string.format('{"t":"Font","family":%s,"weight":%s}', jstr(v.Family), jstr(v.Weight.Name))
	elseif t == "Instance" then
		return string.format('{"t":"Ref","v":%d}', idOf(v))
	end
	return "null"
end
local function dumpNode(p, out)
	local d = M.D[p]
	if not d or d.Destroyed then
		return
	end
	local props = {}
	for k, v in pairs(d.Props) do
		table.insert(props, jstr(k) .. ":" .. enc(v))
	end
	local attrs = {}
	for k, v in pairs(d.Attributes or {}) do
		local e = enc(v)
		table.insert(attrs, jstr(k) .. ":" .. e)
	end
	table.insert(out, string.format('{"id":%d,"class":%s,"props":{%s},"attrs":{%s},"children":[', idOf(p), jstr(d.ClassName), table.concat(props, ","), table.concat(attrs, ",")))
	local first = true
	for _, child in ipairs(d.Children) do
		if M.D[child] and not M.D[child].Destroyed then
			if not first then
				table.insert(out, ",")
			end
			first = false
			dumpNode(child, out)
		end
	end
	table.insert(out, "]}")
end
local function emit(tag, inst)
	local out = {}
	dumpNode(inst, out)
	print("@@DUMP " .. tag .. " " .. table.concat(out))
end
local function emitRaw(tag, json)
	print("@@DUMP " .. tag .. " " .. json)
end

---------------------------------------------------------------- игра
M.buildTree()
local SSS, RS, Workspace = svc("ServerScriptService"), svc("ReplicatedStorage"), svc("Workspace")
M.runScript(SSS.Server.Main, M.SERVER)
M.run(0.5)
local worlds = Workspace:FindFirstChild("Worlds")
local Modules = SSS.Server.Modules
local DataService = M.requireIn(M.SERVER, Modules.DataService)
local PlayerState = M.requireIn(M.SERVER, Modules.PlayerState)
local PetService = M.requireIn(M.SERVER, Modules.PetService)

local player, ctx = M.addPlayer("Player", 1001)
M.run(0.3)
M.spawnCharacter(player, worlds.Forest.Spawn.SpawnLocation.Position)
M.runScript(svc("StarterPlayer").StarterPlayerScripts.Client.Main, ctx)
M.run(3)
local root = player.PlayerGui.PowerPetsGui.Root

local function press(button)
	M.inCtx(ctx, function()
		M.fire(M.event(button, "Activated"))
	end)
end

-- богатый игрок: монеты, сила, много питомцев
local data = DataService.Get(player)
data.Coins = 1284500
data.Strength = 36
data.TotalStrength = 45200
data.Rebirths = 2
data.BackpackLevel = 3
M.inCtx(M.SERVER, function()
	for _, petId in ipairs({ "Kitten", "Puppy", "Fox", "Owl", "ForestSpirit", "Bunny", "Hedgehog", "Bear", "Raccoon", "Unicorn", "Lizard", "Fennec", "Phoenix", "Pharaoh" }) do
		PetService.AddPet(player, petId, false)
	end
	PetService.AddPet(player, "Kitten", true)
	PetService.AddPet(player, "Unicorn", true)
	for _ = 1, 4 do
		PetService.AddPet(player, "Fox", false)
	end
	PetService.EquipBest(player)
	PlayerState.SyncStats(player)
	PlayerState.SyncPets(player)
end)
M.run(2)
emitRaw("screen", string.format("[%d,%d]", SCREEN[1], SCREEN[2]))
emit("hud", player.PlayerGui)

local function panelShot(menuName, tag, extra)
	press(root.SideMenu[menuName])
	M.run(1.2)
	if extra then
		extra()
		M.run(0.8)
	end
	emit(tag, player.PlayerGui)
	local close = root.PanelLayer[menuName].Body:FindFirstChild("Close", true)
	if close then
		press(close)
	end
	M.run(0.8)
end
panelShot("Pets", "pets", function()
	local grid = root.PanelLayer.Pets.Body:FindFirstChild("Grid", true)
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("TextButton") then
			press(child)
			break
		end
	end
end)
panelShot("Shop", "shop")
panelShot("Shop", "shop_passes", function()
	press(root.PanelLayer.Shop.Body:FindFirstChild("TabPasses", true))
end)
panelShot("Worlds", "worlds")
panelShot("Rebirth", "rebirth")

-- открытие яйца: анимация в разные моменты
local prompt = worlds.Forest.ForestEgg.EggModel.Egg.Prompt1.Open1
local eggStand = nil
print("@@INFO prompt " .. tostring(prompt and prompt:GetFullName()) .. " stand " .. tostring(eggStand))
if prompt then
	local eggPart = worlds.Forest.ForestEgg.EggModel.Egg
	player.Character.HumanoidRootPart.CFrame = G.CFrame.new(eggPart.Position + G.Vector3.new(0, 0, 7))
	M.inCtx(M.SERVER, function()
		M.fire(M.event(prompt, "Triggered"), player)
	end)
	M.run(0.9)
	emit("hatch_shake", player.PlayerGui)
	M.run(2.6)
	emit("hatch_reveal", player.PlayerGui)
	M.run(6)
end

-- своя подсказка у лавки
local stallPrompt = worlds.Forest.ShopStall.Counter.PromptPoint.OpenShop
M.inCtx(ctx, function()
	M.fire(M.event(svc("ProximityPromptService"), "PromptShown"), stallPrompt, G.Enum.ProximityPromptInputType.Touch)
end)
M.run(0.6)
emit("prompt", player.PlayerGui)

-- мир и освещение
emit("lighting", svc("Lighting"))
local fills = {}
for _, f in ipairs(M.terrainFills) do
	local c = f.Center
	table.insert(fills, string.format('{"k":"%s","c":[%s,%s,%s],"s":[%s,%s,%s],"r":%s,"h":%s,"m":"%s"}', f.Kind, num(c.X), num(c.Y), num(c.Z),
		num(f.Size and f.Size.X or 0), num(f.Size and f.Size.Y or 0), num(f.Size and f.Size.Z or 0), num(f.Radius or 0), num(f.Height or 0), f.Material))
end
emitRaw("terrain", "[" .. table.concat(fills, ",") .. "]")
emit("workspace", Workspace)
local cam = Workspace.CurrentCamera
print("@@INFO camera " .. tostring(cam and cam.CFrame.Position))
