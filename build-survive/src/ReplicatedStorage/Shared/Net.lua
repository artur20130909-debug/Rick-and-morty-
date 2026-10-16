-- Все удалённые события в одном месте. Сервер их создаёт, клиент ждёт.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- Клиент → сервер (RemoteFunction: клиент ждёт ответ)
local FUNCTIONS = {
	"Place", "Delete", "Paint", "Undo", "Clear",
	"SaveSlot", "LoadSlot", "LoadExample", "Buy", "GetData", "SetSettings",
	"StartSiege", "StopSiege", "FireRange", "Restore",
	"Launch", "StopLaunch",
	"Dig", "BuyPrefab", "PlacePrefab", "Admin",
}

-- Сервер → клиент (и иногда клиент → сервер)
local EVENTS = {
	"Data", "Notify", "SiegeState", "SiegeResult",
	"ProjectileSpawn", "Detonate", "Impact", "Warning",
	"LaserState", "AAShot", "ShieldState", "BlocksBroken", "Bomber", "LaunchState",
	"GuardShot",
}

-- Частые обновления, которые можно терять
local UNRELIABLE = { "ProjectileSync", "LaserTick" }

local folder: Folder

if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing :: Folder
	else
		local f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
		folder = f
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = folder
		end
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
	for _, name in UNRELIABLE do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("UnreliableRemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

function Net.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	return folder:WaitForChild(name) :: UnreliableRemoteEvent
end

return Net
