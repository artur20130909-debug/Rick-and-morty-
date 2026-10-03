-- Удалённые события и функции. Сервер создаёт их (Net.init), клиент ждёт.
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local Net = {}
Net.Events = { "Action", "Toast", "Alert", "Scene", "Fx", "Hidden" }
Net.Functions = { "Shop", "Profile", "Lobby" }

local folder = nil
local function getFolder()
	if folder then return folder end
	if RunService:IsServer() then
		folder = RS:FindFirstChild("Remotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = RS
		end
	else
		folder = RS:WaitForChild("Remotes")
	end
	return folder
end

local function get(class, name)
	local f = getFolder()
	local r = f:FindFirstChild(name)
	if r then return r end
	if RunService:IsServer() then
		r = Instance.new(class)
		r.Name = name
		r.Parent = f
		return r
	end
	return f:WaitForChild(name)
end

function Net.event(name) return get("RemoteEvent", name) end
function Net.func(name) return get("RemoteFunction", name) end

-- сервер: создать всё сразу
function Net.init()
	for _, n in ipairs(Net.Events) do Net.event(n) end
	for _, n in ipairs(Net.Functions) do Net.func(n) end
end

return Net
