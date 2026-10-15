--[[
	WorldService — всё, что происходит в мирах:
	- телепорт между мирами и открытие новых миров (порталы и меню «Миры»);
	- продажа силы на точке продажи;
	- монеты на земле: появление, сбор, возрождение;
	- возвращение игрока в его мир после смерти и при входе.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Worlds = require(Shared.Config.Worlds)
local Formulas = require(Shared.Modules.Formulas)
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)

local Modules = script.Parent
local DataService = require(Modules.DataService)
local PlayerState = require(Modules.PlayerState)
local RateLimiter = require(Modules.RateLimiter)

local WorldService = {}

local worldRefs = nil
local rng = Random.new()
local portalCooldown = {} -- [player] = время последнего касания портала
local teleportLimiter = RateLimiter.new(1, 2)

local function playerFromHit(hit)
	local model = hit:FindFirstAncestorOfClass("Model")
	while model do
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				return player
			end
			return nil
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

------------------------------------------------------------------ ТЕЛЕПОРТ И МИРЫ

function WorldService.Teleport(player, worldId)
	local data = DataService.Get(player)
	local info = worldRefs[worldId]
	if not data or not info then
		return
	end
	data.CurrentWorld = worldId
	PlayerState.SyncStats(player)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local target = info.Spawn * CFrame.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
	-- Подгружаем мир вокруг точки появления (при включённом StreamingEnabled), чтобы игрок не провалился.
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, 2)
	end)
	if character.Parent then
		character:PivotTo(target)
	end
	PlayerState.Effect(player, "Teleport", { World = worldId })
end

-- Попросить переход в мир: открывает его, если хватает накопленной силы, и телепортирует.
function WorldService.RequestWorld(player, worldId)
	local data = DataService.Get(player)
	local world = Worlds[worldId]
	if not data then
		return false, "Данные ещё загружаются…"
	end
	if type(worldId) ~= "string" or worldId == "Order" or not world then
		return false, "Такого мира нет"
	end

	if not data.UnlockedWorlds[worldId] then
		local previous = Worlds.Order[world.Order - 1]
		if previous and not data.UnlockedWorlds[previous] then
			return false, "Сначала открой мир «" .. Worlds[previous].Name .. "»"
		end
		if data.TotalStrength < world.UnlockStrength then
			return false,
				string.format(
					"Мир «%s» закрыт: нужно %s накопленной силы (у тебя %s)",
					world.Name,
					Format.Number(world.UnlockStrength),
					Format.Number(data.TotalStrength)
				)
		end
		data.UnlockedWorlds[worldId] = true
		PlayerState.Effect(player, "Unlock", { World = worldId })
	end

	WorldService.Teleport(player, worldId)
	return true, world.Name
end

local function onPortalTouched(hit, targetWorld)
	local player = playerFromHit(hit)
	if not player then
		return
	end
	local now = os.clock()
	if (portalCooldown[player] or 0) + 2 > now then
		return
	end
	portalCooldown[player] = now
	local ok, message = WorldService.RequestWorld(player, targetWorld)
	if not ok and message then
		PlayerState.Notify(player, message, "warning")
	end
end

------------------------------------------------------------------ ПРОДАЖА

function WorldService.Sell(player, worldId)
	local data = DataService.Get(player)
	if not data or data.Strength < 1 then
		return
	end
	local sold = data.Strength
	local coins = Formulas.SellValue(sold, worldId)
	data.Strength = 0
	data.Coins += coins
	PlayerState.SyncStats(player)
	PlayerState.Effect(player, "Sell", { Amount = coins, Strength = sold })
end

-- Раз в 0.25 секунды проверяем, кто стоит в круге продажи.
local function sellLoop()
	while true do
		task.wait(0.25)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = DataService.Get(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if data and root and data.Strength >= 1 then
				for worldId, info in pairs(worldRefs) do
					local offset = root.Position - info.Sell.Position
					if Vector2.new(offset.X, offset.Z).Magnitude <= info.Sell.Radius and math.abs(offset.Y) < 10 then
						WorldService.Sell(player, worldId)
						break
					end
				end
			end
		end
	end
end

------------------------------------------------------------------ МОНЕТЫ

local function spawnCoin(worldId)
	local info = worldRefs[worldId]
	local config = Worlds[worldId]
	local x, z, groundY = info.RandomCoinPoint(rng)
	local big = rng:NextNumber() < GameConfig.BigCoinChance
	local value = config.CoinValue * (big and GameConfig.BigCoinMultiplier or 1)
	local diameter = big and 4.4 or 2.8

	local coin = Instance.new("Part")
	coin.Name = big and "BigCoin" or "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.5, diameter, diameter)
	coin.CFrame = CFrame.new(Vector3.new(info.Origin.X + x, (groundY or info.Origin.Y) + diameter / 2 + 1, info.Origin.Z + z))
		* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CastShadow = false
	coin.Color = config.Palette.Coin
	coin.Material = Enum.Material.SmoothPlastic
	coin.Reflectance = 0.25
	coin:SetAttribute("Value", value)

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(Color3.new(1, 1, 1), config.Palette.Coin)
	sparkle.LightEmission = 1
	sparkle.Rate = big and 5 or 2
	sparkle.Lifetime = NumberRange.new(0.6, 1)
	sparkle.Speed = NumberRange.new(0.5, 1)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Parent = coin

	local light = Instance.new("PointLight")
	light.Color = config.Palette.Coin
	light.Range = big and 9 or 6
	light.Brightness = 0.8
	light.Parent = coin

	local collected = false
	coin.Touched:Connect(function(hit)
		if collected then
			return
		end
		local player = playerFromHit(hit)
		if not player then
			return
		end
		local data = DataService.Get(player)
		if not data then
			return
		end
		collected = true
		data.Coins += value
		PlayerState.SyncStats(player)
		PlayerState.Effect(player, "Coin", { Amount = value, Position = coin.Position })
		coin:Destroy()
		task.delay(GameConfig.CoinRespawnTime + rng:NextNumber(0, 4), spawnCoin, worldId)
	end)

	CollectionService:AddTag(coin, "Coin")
	coin.Parent = info.CoinsFolder
end

------------------------------------------------------------------ ИГРОКИ

function WorldService.PlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		local data = DataService.Get(player)
		if not data or data.CurrentWorld == GameConfig.StartWorld then
			return
		end
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root and character.Parent then
			task.wait(0.1)
			WorldService.Teleport(player, data.CurrentWorld)
		end
	end)
end

-- Данные загрузились: если игрок вышел из игры в другом мире — возвращаем его туда.
function WorldService.OnDataLoaded(player)
	local data = DataService.Get(player)
	if data and data.CurrentWorld ~= GameConfig.StartWorld and player.Character then
		WorldService.Teleport(player, data.CurrentWorld)
	end
end

function WorldService.PlayerRemoving(player)
	portalCooldown[player] = nil
	teleportLimiter:Remove(player)
end

function WorldService.Init(refs)
	worldRefs = refs

	for worldId, info in pairs(worldRefs) do
		for _, portal in ipairs(info.Portals) do
			portal.Touch.Touched:Connect(function(hit)
				onPortalTouched(hit, portal.TargetWorld)
			end)
		end
		for _ = 1, Worlds[worldId].CoinCount do
			spawnCoin(worldId)
		end
	end

	Remotes.Teleport.OnServerInvoke = function(player, worldId)
		if not teleportLimiter:Allow(player) then
			return false, "Не так быстро!"
		end
		return WorldService.RequestWorld(player, worldId)
	end

	task.spawn(sellLoop)
end

return WorldService
