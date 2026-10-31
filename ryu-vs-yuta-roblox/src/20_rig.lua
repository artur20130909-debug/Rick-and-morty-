----------------------------------------------------------------------
-- СКЕЛЕТ: кости поворачиваются плавно, детали едут за костями
----------------------------------------------------------------------

local Rig = {}
Rig.__index = Rig

-- outlineMode: "model" — один контур на всю модель; "groups" — свой контур у каждой группы
function Rig.new(name, parent, outlineMode, fill)
	local self = setmetatable({}, Rig)
	self.model = Instance.new("Model")
	self.model.Name = name
	self.model.Parent = parent
	self.home = parent
	self.bones = {}
	self.list = {}
	self.groups = {}
	self.root = CF()
	self.active = true
	self.outlineMode = outlineMode or "model"
	self.fill = fill
	if self.outlineMode == "model" then
		outline(self.model, fill and fill[1], fill and fill[2])
	end
	return self
end

function Rig:group(name)
	local g = self.groups[name]
	if g then
		return g
	end
	g = Instance.new("Model")
	g.Name = name
	g.Parent = self.model
	if self.outlineMode == "groups" then
		outline(g, self.fill and self.fill[1], self.fill and self.fill[2])
	end
	self.groups[name] = g
	return g
end

function Rig:addBone(name, parentName, offset)
	local b = {
		name = name,
		parent = parentName and self.bones[parentName] or nil,
		offset = offset or CF(),
		rot = CF(),
		from = CF(),
		to = CF(),
		t0 = 0,
		dur = 0,
		parts = {},
		world = CF(),
		wob = nil,
	}
	self.bones[name] = b
	table.insert(self.list, b)
	return b
end

function Rig:add(boneName, size, color, rel, o, groupName)
	local parent = self.model
	if groupName then
		parent = self:group(groupName)
	end
	local p = newPart(parent, size, color, nil, o)
	local e = { p = p, rel = rel or CF() }
	table.insert(self.bones[boneName].parts, e)
	return p, e
end

-- maker для Canvas/makeTri: детали в системе координат кости
function Rig:maker(boneName, groupName, tags)
	return function(size, color, cf, o)
		local p, e = self:add(boneName, size, color, cf, o, groupName)
		if tags and o and o.tag then
			tags[o.tag] = tags[o.tag] or {}
			table.insert(tags[o.tag], p)
		end
		return p
	end
end

-- pose = { кость = {x, y, z} в градусах }; кости без значения возвращаются в ноль
function Rig:pose(pose, dur, now)
	for _, b in ipairs(self.list) do
		local a = pose[b.name]
		local target = CF()
		if a then
			target = ANG(rad(a[1]), rad(a[2] or 0), rad(a[3] or 0))
		end
		b.from = b.rot
		b.to = target
		b.t0 = now or 0
		b.dur = dur or 0
		if b.dur <= 0 then
			b.rot = target
		end
	end
end

function Rig:place(cf)
	self.root = cf
end

function Rig:show(on)
	self.active = on
	if on then
		self.model.Parent = self.home
	else
		self.model.Parent = nil
	end
end

function Rig:update(now)
	for _, b in ipairs(self.list) do
		if b.dur > 0 then
			local a = clamp01((now - b.t0) / b.dur)
			b.rot = b.from:Lerp(b.to, smooth(a))
			if a >= 1 then
				b.dur = 0
				b.rot = b.to
			end
		end
		local base = self.root
		if b.parent then
			base = b.parent.world
		end
		local w = base * b.offset * b.rot
		if b.wob then
			w = w * b.wob(now)
		end
		b.world = w
		for _, e in ipairs(b.parts) do
			e.p.CFrame = w * e.rel
		end
	end
end

function Rig:point(boneName, v)
	return self.bones[boneName].world * v
end

-- показать один вариант из группы (например, рот: ухмылка / оскал / смех)
local function showVariant(tags, prefix, name)
	for tag, parts in pairs(tags) do
		if string.sub(tag, 1, #prefix) == prefix then
			local on = (tag == prefix .. name)
			for _, p in ipairs(parts) do
				if on then
					p.Transparency = 0
				else
					p.Transparency = 1
				end
			end
		end
	end
end
