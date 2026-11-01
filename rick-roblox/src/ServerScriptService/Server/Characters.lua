-- Персонаж: каждый игрок — Морти (жёлтая футболка, синие штаны, каштановые волосы).
-- Игроки не толкают друг друга (группа столкновений Players).
local Characters = {}

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local B, C

local function hair(char)
	local head = char:FindFirstChild("Head")
	if not head or char:FindFirstChild("MortyHair") then return end
	local m = Instance.new("Model")
	m.Name = "MortyHair"
	local col = C.Colors.MortyHair
	local s = head.Size.Y / 1.2
	local function blob(name, size, offset, rot)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(1, 1, 1)
		p.Color = col
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = true
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = size * s
		mesh.Parent = p
		p.CFrame = head.CFrame * CFrame.new(offset * s) * (rot or CFrame.new())
		p.Parent = m
		B.weld(head, p)
		return p
	end
	-- шапка волос (сверху и сзади), чёлка и пара прядей
	blob("Cap", Vector3.new(1.32, 0.78, 1.3), Vector3.new(0, 0.38, 0.08))
	blob("Back", Vector3.new(1.28, 0.9, 0.7), Vector3.new(0, 0.12, 0.38))
	blob("Fringe", Vector3.new(1.1, 0.34, 0.5), Vector3.new(0.05, 0.5, -0.42), CFrame.Angles(math.rad(-20), 0, math.rad(-6)))
	blob("SideL", Vector3.new(0.3, 0.6, 0.7), Vector3.new(-0.6, 0.15, 0.1))
	blob("SideR", Vector3.new(0.3, 0.6, 0.7), Vector3.new(0.6, 0.15, 0.1))
	m.Parent = char
end

local function setGroup(char)
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then p.CollisionGroup = "Players" end
	end
	char.DescendantAdded:Connect(function(p)
		if p:IsA("BasePart") then p.CollisionGroup = "Players" end
	end)
end

local function mortify(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = C.Colors.Skin
	desc.LeftArmColor = C.Colors.Skin
	desc.RightArmColor = C.Colors.Skin
	desc.TorsoColor = C.Colors.MortyShirt
	desc.LeftLegColor = C.Colors.MortyPants
	desc.RightLegColor = C.Colors.MortyPants
	desc.HeightScale = 0.92
	desc.WidthScale = 0.95
	desc.DepthScale = 0.95
	desc.HeadScale = 1.12
	desc.BodyTypeScale = 0
	desc.ProportionScale = 0
	local ok, err = pcall(function() hum:ApplyDescription(desc) end)
	if not ok then warn("[RM] не удалось применить внешность Морти: " .. tostring(err)) end
	-- рукава футболки и кроссовки
	for _, n in ipairs({ "LeftUpperArm", "RightUpperArm", "UpperTorso", "LowerTorso" }) do
		local p = char:FindFirstChild(n)
		if p then p.Color = C.Colors.MortyShirt end
	end
	local lt = char:FindFirstChild("LowerTorso")
	if lt then lt.Color = C.Colors.MortyPants end
	for _, n in ipairs({ "LeftFoot", "RightFoot" }) do
		local p = char:FindFirstChild(n)
		if p then p.Color = C.Colors.MortyShoes end
	end
	hair(char)
	hum.DisplayName = "Морти"
	hum.WalkSpeed = C.WalkSpeed
	hum.UseJumpPower = false
	hum.JumpHeight = 4
end

function Characters.init(ctx)
	B, C = ctx.Build, ctx.Config
	pcall(function() PhysicsService:RegisterCollisionGroup("Players") end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable("Players", "Players", false) end)
	local function onPlayer(plr)
		plr.CharacterAdded:Connect(function(char)
			setGroup(char)
			task.defer(function()
				local ok, err = pcall(mortify, char)
				if not ok then warn("[RM] mortify: " .. tostring(err)) end
			end)
		end)
		if plr.Character then
			setGroup(plr.Character)
			task.defer(mortify, plr.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
end

return Characters
