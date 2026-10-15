--[[
	PetFollow — питомцы летают за игроками.
	Сервер пишет надетых питомцев в атрибут игрока EquippedPets ("Kitten:0,Fox:1" — 1 = золотой),
	а каждый клиент сам рисует питомцев всех игроков. Так движение плавное и не грузит сервер.
	Все детали двигаются одним вызовом workspace:BulkMoveTo за кадр.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pets = require(Shared.Config.Pets)
local PetBuilder = require(Shared.Modules.PetBuilder)

local PetFollow = {}

local DRAW_DISTANCE = 300
local folder = nil
local entries = {} -- [player] = { Key = "...", Pets = { { Model, Parts, Offsets, CFrame } } }

local function parse(text)
	local list = {}
	for item in string.gmatch(text or "", "[^,]+") do
		local petId, golden = string.match(item, "^([^:]+):?(%d?)$")
		if petId and Pets[petId] then
			table.insert(list, { Id = petId, Golden = golden == "1" })
		end
	end
	return list
end

local function clear(entry)
	for _, pet in ipairs(entry.Pets or {}) do
		pet.Model:Destroy()
	end
	entry.Pets = {}
end

local function rebuild(player)
	local entry = entries[player]
	if not entry then
		return
	end
	local key = player:GetAttribute("EquippedPets") or ""
	if entry.Key == key then
		return
	end
	-- Старые позиции сохраняем, чтобы новые питомцы не «прыгали» из центра мира.
	local previous = {}
	for index, pet in ipairs(entry.Pets or {}) do
		previous[index] = pet.CFrame
	end
	clear(entry)
	entry.Key = key
	for index, item in ipairs(parse(key)) do
		local model = PetBuilder.Build(item.Id, item.Golden)
		if model then
			local parts, offsets = PetBuilder.GetParts(model)
			table.insert(entry.Pets, {
				Model = model,
				Parts = parts,
				Offsets = offsets,
				CFrame = previous[index],
			})
		end
	end
end

local function track(player)
	if entries[player] then
		return
	end
	entries[player] = { Key = nil, Pets = {} }
	rebuild(player)
	player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(player)
	end)
end

local function untrack(player)
	local entry = entries[player]
	if entry then
		clear(entry)
		entries[player] = nil
	end
end

local partBuffer = {}
local cframeBuffer = {}

local function step(deltaTime)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local t = os.clock()
	local alpha = 1 - math.exp(-9 * deltaTime)
	local count = 0

	for player, entry in pairs(entries) do
		local petCount = #entry.Pets
		if petCount > 0 then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local visible = root ~= nil and (root.Position - cameraPosition).Magnitude < DRAW_DISTANCE
			if visible then
				local look = root.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				if flat.Magnitude < 0.01 then
					flat = Vector3.new(0, 0, -1)
				end
				local base = CFrame.lookAt(root.Position, root.Position + flat.Unit)
				local moving = root.AssemblyLinearVelocity.Magnitude > 2

				for index, pet in ipairs(entry.Pets) do
					if pet.Model.Parent ~= folder then
						pet.Model.Parent = folder
					end
					-- Дуга позади игрока: +Z в системе base — это «сзади».
					local offsetX = (index - (petCount + 1) / 2) * 3.6
					local offsetZ = 5 + math.abs(offsetX) * 0.35
					local bob = math.sin(t * 3 + index * 1.7) * 0.35
					if moving then
						bob += math.abs(math.sin(t * 9 + index)) * 0.7
					end
					local target = base * CFrame.new(offsetX, -0.6 + bob, offsetZ)
					if pet.CFrame then
						pet.CFrame = pet.CFrame:Lerp(target, alpha)
					else
						pet.CFrame = target
					end
					for partIndex, part in ipairs(pet.Parts) do
						count += 1
						partBuffer[count] = part
						cframeBuffer[count] = pet.CFrame * pet.Offsets[partIndex]
					end
				end
			else
				for _, pet in ipairs(entry.Pets) do
					if pet.Model.Parent then
						pet.Model.Parent = nil
					end
					pet.CFrame = nil
				end
			end
		end
	end

	-- Обрезаем буферы до текущего размера.
	for index = count + 1, #partBuffer do
		partBuffer[index] = nil
		cframeBuffer[index] = nil
	end
	if count > 0 then
		Workspace:BulkMoveTo(partBuffer, cframeBuffer, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function PetFollow.Init()
	folder = Instance.new("Folder")
	folder.Name = "ClientPets"
	folder.Parent = Workspace

	for _, player in ipairs(Players:GetPlayers()) do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(untrack)
	RunService.RenderStepped:Connect(step)
end

return PetFollow
