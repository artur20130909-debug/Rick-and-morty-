-- tools/mock/dump.lua — выгрузка сцены из мока в JSON для рендера в three.js (tools/render/).
-- Детали, свет, лучи (Beam), атрибуты обводки, освещение и камера первого игрока.
local mock = ...
local Vector3 = mock.G.Vector3
local DATA = mock.DATA
local fmt = string.format

local function num(x) return fmt("%.4g", x) end
local function arr(t) local o = {}; for i, v in ipairs(t) do o[i] = num(v) end; return "[" .. table.concat(o, ",") .. "]" end
local function str(s) return '"' .. tostring(s):gsub('[%c"\\]', " ") .. '"' end
local function cf12(cf)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return arr({ x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 })
end
local function col(c) return arr({ c.R, c.G, c.B }) end

local ws = mock.services.Workspace
local parts, lights, beams, guis = {}, {}, {}, {}
local outlineModels = {}

local function outlined(inst)
	local a = inst.Parent
	while a and a ~= ws do
		if a:IsA("Model") and a:GetAttribute("Outline") then return a end
		a = a.Parent
	end
	return nil
end

-- всё из workspace + то, что клиент повесил на свою камеру (телефон, контуры)
local all = ws:GetDescendants()
local plr0 = mock.services.Players:GetPlayers()[1]
if plr0 then
	local cam0 = mock.clientCtx(plr0).camera
	if cam0 then for _, x in ipairs(cam0:GetDescendants()) do table.insert(all, x) end end
end
for _, x in ipairs(all) do
	local d = x[DATA]
	local cn = d.cls.name
	if d.cls.isa.BasePart and cn ~= "Terrain" then
		local p = d.p
		local ltm = p.LocalTransparencyModifier or 0
		if p.Transparency < 0.999 and ltm < 0.999 then
			local shape = "Block"
			if cn == "WedgePart" then shape = "Wedge"
			elseif cn == "CornerWedgePart" then shape = "CornerWedge"
			elseif cn == "Part" or cn == "SpawnLocation" or cn == "Seat" then shape = p.Shape and p.Shape.Name or "Block" end
			local om = outlined(x)
			local id = om and tostring(om[DATA].id) or ""
			local size = p.Size
			local mesh = x:FindFirstChildOfClass("SpecialMesh")
			if mesh and mesh.MeshType.Name == "Sphere" then
				shape = "Ball3"
				size = Vector3.new(size.X * mesh.Scale.X, size.Y * mesh.Scale.Y, size.Z * mesh.Scale.Z)
			end
			parts[#parts + 1] = fmt('{"s":%s,"z":%s,"c":%s,"k":%s,"m":%s,"t":%s,"o":%s,"n":%s}',
				str(shape), arr({ size.X, size.Y, size.Z }), cf12(p.CFrame), col(p.Color), str(p.Material.Name),
				num(p.Transparency), str(id), str(p.Name))
		end
	elseif (cn == "PointLight" or cn == "SpotLight" or cn == "SurfaceLight") and d.p.Enabled then
		local par = x.Parent
		local pos, look
		if par and par:IsA("BasePart") then
			pos = par.Position
			local face = d.p.Face and d.p.Face.Name or "Front"
			local v = ({ Front = -par.CFrame.LookVector, Back = par.CFrame.LookVector, Top = par.CFrame.UpVector,
				Bottom = -par.CFrame.UpVector, Right = par.CFrame.RightVector, Left = -par.CFrame.RightVector })[face]
			look = v or -par.CFrame.UpVector
		elseif par and par:IsA("Attachment") then
			pos = par.WorldPosition
			look = -par.WorldCFrame.UpVector
		end
		if pos then
			lights[#lights + 1] = fmt('{"k":%s,"p":%s,"d":%s,"c":%s,"b":%s,"r":%s,"a":%s,"sh":%s}', str(cn),
				arr({ pos.X, pos.Y, pos.Z }), arr({ look.X, look.Y, look.Z }), col(d.p.Color), num(d.p.Brightness),
				num(d.p.Range), num(d.p.Angle or 90), d.p.Shadows and "true" or "false")
		end
	elseif cn == "Beam" and d.p.Enabled and d.p.Attachment0 and d.p.Attachment1 then
		local a0, a1 = d.p.Attachment0.WorldPosition, d.p.Attachment1.WorldPosition
		local tr = d.p.Transparency.Keypoints
		beams[#beams + 1] = fmt('{"a":%s,"b":%s,"w0":%s,"w1":%s,"c":%s,"t0":%s,"t1":%s,"e":%s}',
			arr({ a0.X, a0.Y, a0.Z }), arr({ a1.X, a1.Y, a1.Z }), num(d.p.Width0), num(d.p.Width1),
			col(d.p.Color.Keypoints[1].Value), num(tr[1].Value), num(tr[#tr].Value), num(d.p.LightEmission))
	elseif cn == "SurfaceGui" then
		-- фон первого кадра (Frame) — чтобы плакаты и экраны были цветными на превью
		local par = d.p.Adornee or x.Parent
		if par and par:IsA("BasePart") then
			local bg
			for _, c in ipairs(x:GetChildren()) do
				if c:IsA("GuiObject") and c.BackgroundTransparency < 0.9 then bg = c.BackgroundColor3; break end
			end
			local texts = {}
			for _, c in ipairs(x:GetDescendants()) do
				if c:IsA("TextLabel") and c.Text ~= "" then texts[#texts + 1] = str(c.Text) end
				if #texts >= 3 then break end
			end
			guis[#guis + 1] = fmt('{"part":%s,"z":%s,"c":%s,"face":%s,"bg":%s,"tx":[%s]}', str(par.Name),
				arr({ par.Size.X, par.Size.Y, par.Size.Z }), cf12(par.CFrame), str(d.p.Face.Name), bg and col(bg) or "null",
				table.concat(texts, ","))
		end
	end
end

local L = mock.services.Lighting
local light = fmt('{"clock":%s,"amb":%s,"oamb":%s,"bright":%s,"exp":%s,"shadows":%s,"lat":%s,"sun":%s}',
	num(L.ClockTime), col(L.Ambient), col(L.OutdoorAmbient), num(L.Brightness), num(L.ExposureCompensation),
	L.GlobalShadows and "true" or "false", num(L.GeographicLatitude), (function()
		local s = L:GetSunDirection(); return arr({ s.X, s.Y, s.Z }) end)())
local effects = {}
for _, e in ipairs(L:GetChildren()) do
	if e:IsA("ColorCorrectionEffect") and e.Enabled then
		effects[#effects + 1] = fmt('{"k":"cc","sat":%s,"con":%s,"bri":%s,"tint":%s}', num(e.Saturation), num(e.Contrast), num(e.Brightness), col(e.TintColor))
	elseif e:IsA("BloomEffect") and e.Enabled then
		effects[#effects + 1] = fmt('{"k":"bloom","i":%s,"s":%s,"th":%s}', num(e.Intensity), num(e.Size), num(e.Threshold))
	elseif e:IsA("Atmosphere") then
		effects[#effects + 1] = fmt('{"k":"atm","den":%s,"c":%s,"haze":%s}', num(e.Density), col(e.Color), num(e.Haze))
	end
end
local cam = "null"
local plr = mock.services.Players:GetPlayers()[1]
if plr then
	local ctx = mock.clientCtx(plr)
	if ctx.camera then cam = fmt('{"cf":%s,"fov":%s}', cf12(ctx.camera.CFrame), num(ctx.camera.FieldOfView)) end
end
return fmt('{"parts":[%s],"lights":[%s],"beams":[%s],"guis":[%s],"lighting":%s,"effects":[%s],"camera":%s}',
	table.concat(parts, ","), table.concat(lights, ","), table.concat(beams, ","), table.concat(guis, ","), light,
	table.concat(effects, ","), cam)
