-- Предметы и действия игрока: инвентарь, магазин в гараже (купить/продать яблоки),
-- использование предметов (дробовик, баллончик, шокер, капкан, лампа, аптечка, батарейки, дефибриллятор),
-- фонарик, бег/присед для слуха заключённых, выход из укрытия и концентрация.
local Players = game:GetService("Players")

local Items = {}
local ctx, Config, Sound, Net, B
local stunReady = {}            -- [Player] = os.clock(), когда шокер снова готов
local lastUse = {}              -- [Player] = os.clock() — защита от спама

---------------------------------------------------------------- инвентарь
local function inv(plr)
	local f = plr:FindFirstChild("Inventory")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Inventory"
		f.Parent = plr
	end
	return f
end

function Items.count(plr, key)
	local v = inv(plr):FindFirstChild(key)
	return v and v.Value or 0
end

function Items.add(plr, key, n)
	local f = inv(plr)
	local v = f:FindFirstChild(key)
	if not v then
		v = Instance.new("IntValue")
		v.Name = key
		v.Parent = f
	end
	v.Value = v.Value + (n or 1)
end

function Items.take(plr, key, n)
	n = n or 1
	local v = inv(plr):FindFirstChild(key)
	if not v or v.Value < n then return false end
	v.Value = v.Value - n
	if v.Value <= 0 and key ~= "shotgun" then
		v:Destroy()
		if plr:GetAttribute("Equipped") == key then plr:SetAttribute("Equipped", "") end
	end
	return true
end

function Items.clear(plr)
	inv(plr):ClearAllChildren()
	plr:SetAttribute("Equipped", "")
end

-- стартовый набор класса в начале матча
function Items.giveStart(plr)
	Items.clear(plr)
	local cls = Config.Classes[plr:GetAttribute("Class") or "novice"] or Config.Classes.novice
	plr:SetAttribute("Money", cls.money or 0)
	plr:SetAttribute("Apples", 0)
	for k, n in pairs(cls.items or {}) do Items.add(plr, k, n) end
end

---------------------------------------------------------------- помощники
local function matchOf(plr)
	return ctx.Match and ctx.Match.of(plr)
end

local function charParts(plr)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return char, hrp, hum
end

local function toast(plr, text, color)
	Net.event("Toast"):FireClient(plr, text, color)
end

local function nearShop(match, plr)
	local shop = match.house.shop
	local _, hrp = charParts(plr)
	if not shop or not hrp then return false end
	return (shop:GetPivot().Position - hrp.Position).Magnitude < 28
end

-- заключённые перед игроком (конус), ближе range
local function inmatesInCone(match, origin, dir, range, minDot)
	local out = {}
	for _, inm in ipairs(match.inmates or {}) do
		local r = inm.root
		if r and r.Parent then
			local to = r.Position - origin
			local d = to.Magnitude
			if d <= range and (d < 3 or to.Unit:Dot(dir) >= minDot) then table.insert(out, inm) end
		end
	end
	return out
end

local function groundBelow(pos, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
	return hit and hit.Position or (pos - Vector3.new(0, 3, 0))
end

---------------------------------------------------------------- расставляемые предметы
local function placeTrap(match, plr)
	local char, hrp = charParts(plr)
	local pos = groundBelow(hrp.Position + hrp.CFrame.LookVector * 2.5, { char })
	local m = B.model(workspace.Props, "BearTrap")
	local base = B.cyl(m, "Base", 0.25, 2.6, CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(70, 66, 60), Enum.Material.CorrodedMetal, { CanCollide = false })
	for i = -1, 1, 2 do
		B.part(m, "Jaw", Vector3.new(2.4, 0.5, 0.12), CFrame.new(pos + Vector3.new(0, 0.35, i * 0.9)) * CFrame.Angles(math.rad(i * 25), 0, 0),
			Color3.fromRGB(110, 105, 95), Enum.Material.Metal, { CanCollide = false })
	end
	m.PrimaryPart = base
	m:SetAttribute("MatchId", match.id)
	match.props = match.props or {}
	table.insert(match.props, m)
	Sound.play("TrapSnap", base, { Volume = 0.3, PlaybackSpeed = 1.6 })
	task.spawn(function()
		while m.Parent and match.phase ~= "end" do
			for _, inm in ipairs(match.inmates or {}) do
				if inm.root and inm.root.Parent and (inm.root.Position - pos).Magnitude < 3 then
					if ctx.InmateAI then pcall(ctx.InmateAI.stun, inm, Config.Items.beartrap.stun) end
					Sound.play("TrapSnap", base, { Volume = 1 })
					match:toast("Капкан сработал!", Color3.fromRGB(255, 200, 80))
					m:Destroy()
					return
				end
			end
			task.wait(0.1)
		end
	end)
end

local function placeMotionLamp(match, plr)
	local char, hrp = charParts(plr)
	local pos = groundBelow(hrp.Position + hrp.CFrame.LookVector * 2.5, { char })
	local m = B.model(workspace.Props, "MotionLamp")
	local base = B.part(m, "Base", Vector3.new(1, 0.4, 1), CFrame.new(pos + Vector3.new(0, 0.2, 0)), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
	local bulb = B.ball(m, "Bulb", 0.8, CFrame.new(pos + Vector3.new(0, 0.75, 0)), Color3.fromRGB(255, 240, 200), Enum.Material.SmoothPlastic, { CanCollide = false })
	local light = B.light(bulb, "PointLight", { Range = 22, Brightness = 2.5, Color = Color3.fromRGB(255, 235, 200), Enabled = false })
	m.PrimaryPart = base
	match.props = match.props or {}
	table.insert(match.props, m)
	task.spawn(function()
		while m.Parent and match.phase ~= "end" do
			local near = false
			for _, inm in ipairs(match.inmates or {}) do
				if inm.root and inm.root.Parent and (inm.root.Position - pos).Magnitude < 14 then near = true end
			end
			for _, p in ipairs(match.players) do
				local _, r = charParts(p)
				if r and match:isAlive(p) and (r.Position - pos).Magnitude < 9 then near = true end
			end
			if light.Enabled ~= near then
				light.Enabled = near
				bulb.Material = near and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
			task.wait(0.2)
		end
	end)
end

---------------------------------------------------------------- использование предметов
local function useItem(plr, key, camCF)
	local match = matchOf(plr)
	if not match or not match:isAlive(plr) or plr:GetAttribute("Hidden") then return end
	local now = os.clock()
	if lastUse[plr] and now - lastUse[plr] < 0.35 then return end
	lastUse[plr] = now
	local char, hrp, hum = charParts(plr)
	if not hrp or not hum then return end
	local it = Config.Items[key]
	if not it or Items.count(plr, key) <= 0 then return end
	-- камера должна быть у головы игрока (защита от подмены)
	local origin, dir = hrp.Position + Vector3.new(0, 1.5, 0), hrp.CFrame.LookVector
	if typeof(camCF) == "CFrame" and (camCF.Position - hrp.Position).Magnitude < 12 then
		origin, dir = camCF.Position, camCF.LookVector
	end

	if key == "battery" then
		Items.take(plr, key)
		match:fxTo(plr, "battery")
		Sound.play("FlashlightClick", hrp)
	elseif key == "medkit" then
		if hum.Health >= hum.MaxHealth then toast(plr, "Ты и так здоров"); return end
		Items.take(plr, key)
		hum.Health = math.min(hum.MaxHealth, hum.Health + it.heal)
		Sound.play("Heal", hrp)
	elseif key == "pepper" then
		Items.take(plr, key)
		Sound.play("Pepper", hrp, { Volume = 0.9 })
		for _, inm in ipairs(inmatesInCone(match, origin, dir, it.range, 0.55)) do
			if ctx.InmateAI then pcall(ctx.InmateAI.stun, inm, it.stun) end
		end
	elseif key == "stun" then
		if stunReady[plr] and now < stunReady[plr] then
			toast(plr, string.format("Шокер заряжается: %d с", math.ceil(stunReady[plr] - now)))
			return
		end
		stunReady[plr] = now + it.cooldown
		Sound.play("Stun", hrp, { Volume = 0.9 })
		for _, inm in ipairs(inmatesInCone(match, origin, dir, it.range, 0.3)) do
			if ctx.InmateAI then pcall(ctx.InmateAI.stun, inm, it.stun) end
		end
	elseif key == "shotgun" then
		if not Items.take(plr, "shells") then
			toast(plr, "Нет патронов — купи в гараже")
			Sound.play("DoorLock", hrp, { PlaybackSpeed = 1.8 })
			return
		end
		Sound.play("Shotgun", hrp, { Volume = 1, RollOffMaxDistance = 300 })
		match:fxTo(plr, "shake", 0.8, 0.25)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = { workspace:FindFirstChild("Props") }
		for _, p in ipairs(match.players) do if p.Character then table.insert(ignore, p.Character) end end
		params.FilterDescendantsInstances = ignore
		local hitInm = nil
		local hit = workspace:Raycast(origin, dir * it.range, params)
		if hit then
			for _, inm in ipairs(match.inmates or {}) do
				if inm.model and hit.Instance:IsDescendantOf(inm.model) then hitInm = inm end
			end
		end
		-- дробь разлетается: близкий заключённый в узком конусе тоже получает урон
		if not hitInm then
			local list = inmatesInCone(match, origin, dir, 30, 0.93)
			hitInm = list[1]
		end
		if hitInm and ctx.InmateAI then
			pcall(ctx.InmateAI.damage, hitInm, it.damage, plr)
		end
	elseif key == "beartrap" then
		Items.take(plr, key)
		placeTrap(match, plr)
	elseif key == "motion" then
		Items.take(plr, key)
		placeMotionLamp(match, plr)
	elseif key == "defib" then
		local body = ctx.Match.nearestBody(match, hrp.Position, 10)
		if not body then toast(plr, "Подойди к телу товарища"); return end
		Items.take(plr, key)
		Sound.play("Defib", hrp, { Volume = 1 })
		ctx.Match.revive(match, body.player, body.cf)
		match:toast(plr.DisplayName .. " оживил(а) " .. body.player.DisplayName .. "!", Color3.fromRGB(120, 255, 160))
	end
end

---------------------------------------------------------------- магазин
local function shop(plr, action, key)
	local match = matchOf(plr)
	if not match then return { ok = false, msg = "Магазин работает только в доме" } end
	if not match:isAlive(plr) then return { ok = false, msg = "Ты мёртв" } end
	if match.phase ~= "day" then return { ok = false, msg = "Магазин закрыт до утра" } end
	if not nearShop(match, plr) then return { ok = false, msg = "Подойди к прилавку в гараже" } end
	if action == "sell" then
		local n = plr:GetAttribute("Apples") or 0
		if n <= 0 then return { ok = false, msg = "Нечего продавать — собери яблоки во дворе" } end
		local v = n * match.diff.applePrice
		plr:SetAttribute("Apples", 0)
		plr:SetAttribute("Money", (plr:GetAttribute("Money") or 0) + v)
		match:fxTo(plr, "coin", v)
		return { ok = true, msg = "Продано " .. n .. " 🍎 за $" .. v }
	elseif action == "buy" then
		local it = Config.Items[key or ""]
		if not it then return { ok = false, msg = "Нет такого товара" } end
		local money = plr:GetAttribute("Money") or 0
		if money < it.price then return { ok = false, msg = "Не хватает денег: нужно $" .. it.price } end
		if key == "tree" then
			if not ctx.HouseLogic.plantTree(match) then return { ok = false, msg = "Во дворе больше нет места" } end
		elseif key == "sprinkler" then
			if match.sprinkler then return { ok = false, msg = "Разбрызгиватель уже есть" } end
			match.sprinkler = true
			match.folder:SetAttribute("Sprinkler", true)
			local spot = match.house.sprinkler
			if spot then
				local m = B.model(match.house.model, "Sprinkler")
				local base = B.vcyl(m, "Base", 0.4, 1.2, spot.CFrame, Color3.fromRGB(60, 120, 60), Enum.Material.Plastic)
				B.vcyl(m, "Head", 0.6, 0.4, spot.CFrame * CFrame.new(0, 0.5, 0), Color3.fromRGB(180, 180, 180), Enum.Material.Metal)
				local pe = Instance.new("ParticleEmitter")
				pe.Rate = 60
				pe.Speed = NumberRange.new(10, 14)
				pe.SpreadAngle = Vector2.new(60, 60)
				pe.Lifetime = NumberRange.new(0.6, 1)
				pe.Size = NumberSequence.new(0.15, 0.05)
				pe.Color = ColorSequence.new(Color3.fromRGB(200, 225, 255))
				pe.Transparency = NumberSequence.new(0.3, 1)
				pe.Acceleration = Vector3.new(0, -30, 0)
				pe.Parent = base
				m.PrimaryPart = base
			end
		elseif key == "shotgun" then
			Items.add(plr, "shotgun", 1)
			Items.add(plr, "shells", it.ammo or 4)
		elseif key == "shells" then
			Items.add(plr, "shells", it.count or 4)
		elseif key == "pepper" then
			Items.add(plr, "pepper", it.charges or 3)
		else
			Items.add(plr, key, 1)
		end
		plr:SetAttribute("Money", money - it.price)
		match:fxTo(plr, "coin", -it.price)
		return { ok = true, msg = "Куплено: " .. it.name }
	end
	return { ok = false, msg = "?" }
end

---------------------------------------------------------------- фонарик, который видят другие
local function setFlashlight(plr, on)
	plr:SetAttribute("Flashlight", on == true)
	local char = plr.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return end
	local l = head:FindFirstChild("FlashlightRemote")
	if not l then
		l = Instance.new("SpotLight")
		l.Name = "FlashlightRemote"
		l.Face = Enum.NormalId.Front
		l.Angle = 50
		l.Range = 45
		l.Brightness = 2.2
		l.Color = Color3.fromRGB(255, 244, 220)
		l.Shadows = true
		l.Parent = head
	end
	l.Enabled = on == true
end

local function onAction(plr, kind, a, b)
	if type(kind) ~= "string" then return end
	if kind == "flashlight" then
		setFlashlight(plr, a == true)
	elseif kind == "sprint" then
		plr:SetAttribute("Sprinting", a == true)
	elseif kind == "crouch" then
		plr:SetAttribute("Crouching", a == true)
	elseif kind == "equip" then
		if type(a) ~= "string" then a = "" end
		if a ~= "" and Items.count(plr, a) <= 0 then a = "" end
		plr:SetAttribute("Equipped", a)
	elseif kind == "use" then
		if type(a) == "string" then useItem(plr, a, b) end
	elseif kind == "unhide" then
		ctx.HouseLogic.unhide(plr)
	elseif kind == "qte" then
		ctx.HouseLogic.qte(plr, a == true)
	end
end

function Items.init(c)
	ctx = c
	Config = c.Config
	Sound = c.Sound
	Net = c.Net
	B = c.Build
	Net.event("Action").OnServerEvent:Connect(function(plr, kind, a, b)
		local ok, err = pcall(onAction, plr, kind, a, b)
		if not ok then warn("[AA] Ошибка действия " .. tostring(kind) .. ": " .. tostring(err)) end
	end)
	Net.func("Shop").OnServerInvoke = function(plr, action, key)
		local ok, res = pcall(shop, plr, action, key)
		if ok then return res end
		warn("[AA] Ошибка магазина: " .. tostring(res))
		return { ok = false, msg = "Ошибка магазина" }
	end
	Players.PlayerAdded:Connect(function(plr) inv(plr) end)
	for _, p in ipairs(Players:GetPlayers()) do inv(p) end
	Players.PlayerRemoving:Connect(function(plr)
		stunReady[plr] = nil
		lastUse[plr] = nil
	end)
	-- фонарик в голове переживает смерть: при новом персонаже выключаем
	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function() plr:SetAttribute("Flashlight", false) end)
	end)
end

return Items
