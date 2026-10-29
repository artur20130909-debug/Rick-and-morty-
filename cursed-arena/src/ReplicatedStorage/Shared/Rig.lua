-- Суставы R6 и перевод «понятной» позы в Motor6D.Transform.
--
-- Поза сустава задаётся в градусах:
--   T (торс относительно HumanoidRootPart): p — наклон вперёд, y — поворот вправо, r — наклон вправо,
--     x/u/f — сдвиг вправо/вверх/вперёд (в studs);
--   H (голова): p — кивок вниз, y — взгляд вправо, r — наклон вправо;
--   RA/LA (руки), RL/LL (ноги): p — вперёд (поднять перед собой), r — в сторону (наружу),
--     y — поворот вокруг своей оси. Левая сторона зеркалится сама.
-- Transform = Rot0⁻¹ · M · Rot0, где M — поворот в системе родительской детали вокруг сустава,
-- Rot0 — поворот C0. Так поза не зависит от того, как в риге повёрнуты сами суставы.
local Rig = {}

Rig.Joints = { T = "RootJoint", H = "Neck", RA = "Right Shoulder", LA = "Left Shoulder", RL = "Right Hip", LL = "Left Hip" }
Rig.Order = { "T", "H", "RA", "LA", "RL", "LL" }
Rig.Parts = { T = "HumanoidRootPart", H = "Torso", RA = "Torso", LA = "Torso", RL = "Torso", LL = "Torso" }
Rig.Fields = { "p", "y", "r", "x", "u", "f" }

local rad = math.rad
local SIDE = { RA = 1, RL = 1, LA = -1, LL = -1 }

-- поворот (и сдвиг) в системе родительской детали
function Rig.localCF(key, p, y, r, x, u, f)
	p, y, r = rad(p or 0), rad(y or 0), rad(r or 0)
	if key == "T" or key == "H" then
		local cf = CFrame.Angles(-p, -y, -r)
		if key == "T" and (x ~= 0 or u ~= 0 or f ~= 0) then
			cf = CFrame.new(x or 0, u or 0, -(f or 0)) * cf
		end
		return cf
	end
	local s = SIDE[key]
	return CFrame.Angles(p, 0, 0) * CFrame.Angles(0, 0, r * s) * CFrame.Angles(0, y * s, 0)
end

-- найти суставы персонажа: { T = Motor6D, ... } и их Rot0
function Rig.find(model)
	local out = {}
	local rot0 = {}
	for key, jname in pairs(Rig.Joints) do
		local part = model:FindFirstChild(Rig.Parts[key])
		local m = part and part:FindFirstChild(jname)
		if m and m:IsA("Motor6D") then
			out[key] = m
			rot0[key] = m.C0 - m.C0.Position
		end
	end
	return out, rot0
end

-- применить позу: values[key] = { p, y, r, x, u, f } (числа в градусах/studs)
function Rig.apply(motors, rot0, values)
	for key, m in pairs(motors) do
		local v = values[key]
		local r0 = rot0[key]
		if v and r0 then
			local M = Rig.localCF(key, v[1], v[2], v[3], v[4], v[5], v[6])
			m.Transform = r0:Inverse() * M * r0
		end
	end
end

-- сбросить в нейтраль
function Rig.reset(motors)
	for _, m in pairs(motors) do m.Transform = CFrame.new() end
end

return Rig
