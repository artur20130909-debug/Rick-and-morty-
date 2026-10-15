--[[
	EggService — открытие яиц. Подставки строит WorldBuilder, здесь к ним добавляются
	кнопки ProximityPrompt «Открыть ×1» и «Открыть ×3».

	Всё решает сервер: проверка мира, расстояния, денег и места в инвентаре,
	списание монет, выбор питомца по шансам. Клиенту отправляется только результат
	(RemoteEvent EggHatched) — он показывает анимацию.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Eggs = require(Shared.Config.Eggs)
local Worlds = require(Shared.Config.Worlds)
local Formulas = require(Shared.Modules.Formulas)
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)

local Modules = script.Parent
local DataService = require(Modules.DataService)
local PlayerState = require(Modules.PlayerState)
local PetService = require(Modules.PetService)

local EggService = {}

local rng = Random.new()
local lastOpen = {} -- [player] = время последнего открытия
local eggParts = {} -- [eggId] = деталь яйца

function EggService.Open(player, eggId, count)
	local data = DataService.Get(player)
	local egg = Eggs[eggId]
	if not data or not egg or eggId == "Order" then
		return
	end
	count = math.clamp(math.floor(tonumber(count) or 1), 1, GameConfig.MultiOpenCount)

	local now = os.clock()
	if (lastOpen[player] or 0) + GameConfig.EggOpenCooldown > now then
		return
	end
	lastOpen[player] = now

	if not data.UnlockedWorlds[egg.World] then
		PlayerState.Notify(player, "🔒 Сначала открой мир «" .. Worlds[egg.World].Name .. "»", "error")
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local eggPart = eggParts[eggId]
	if not root or not eggPart or (root.Position - eggPart.Position).Magnitude > GameConfig.EggOpenDistance then
		PlayerState.Notify(player, "Подойди ближе к яйцу", "error")
		return
	end

	local price = egg.Price * count
	if data.Coins < price then
		PlayerState.Notify(
			player,
			string.format("Не хватает монет: нужно 🪙 %s, у тебя 🪙 %s", Format.Number(price), Format.Number(data.Coins)),
			"error"
		)
		return
	end
	if #data.Pets + count > GameConfig.MaxPets then
		PlayerState.Notify(player, string.format("Инвентарь полон (%d/%d). Удали ненужных питомцев", #data.Pets, GameConfig.MaxPets), "error")
		return
	end

	data.Coins -= price
	local results = {}
	for _ = 1, count do
		local petId = Formulas.RollEgg(eggId, rng)
		local pet = PetService.AddPet(player, petId, false)
		if pet then
			PetService.TryAutoEquip(player, pet)
			table.insert(results, { Uid = pet.Uid, Id = petId })
		end
	end
	data.Stats.EggsOpened += count

	PlayerState.SyncPets(player)
	Remotes.EggHatched:FireClient(player, eggId, results)
end

local function addPrompt(eggPart, eggId, count, offsetX, key, gamepadKey)
	local egg = Eggs[eggId]
	local attachment = Instance.new("Attachment")
	attachment.Name = "Prompt" .. count
	attachment.Position = Vector3.new(offsetX, -0.5, 0)
	attachment.Parent = eggPart

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Open" .. count
	prompt.ActionText = "Открыть ×" .. count
	prompt.ObjectText = egg.Name .. " • 🪙 " .. Format.Number(egg.Price * count)
	prompt.KeyboardKeyCode = key
	prompt.GamepadKeyCode = gamepadKey
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	prompt.Parent = attachment

	prompt.Triggered:Connect(function(player)
		EggService.Open(player, eggId, count)
	end)
end

function EggService.PlayerRemoving(player)
	lastOpen[player] = nil
end

function EggService.Init(worldRefs)
	for _, info in pairs(worldRefs) do
		for eggId, eggPart in pairs(info.EggStands) do
			eggParts[eggId] = eggPart
			addPrompt(eggPart, eggId, 1, -2.4, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
			addPrompt(eggPart, eggId, GameConfig.MultiOpenCount, 2.4, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
		end
	end
	Players.PlayerRemoving:Connect(EggService.PlayerRemoving)
end

return EggService
