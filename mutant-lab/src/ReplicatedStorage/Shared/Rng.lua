-- Свой генератор случайных чисел (Парк — Миллер). Даёт одинаковую последовательность в Roblox
-- и в песочнице tools/run_map.py, поэтому превью карты совпадает с тем, что строится в игре.
local Rng = {}
Rng.__index = Rng

function Rng.new(seed)
	return setmetatable({ s = math.floor(seed) % 2147483646 + 1 }, Rng)
end

-- число в [0, 1)
function Rng:next()
	self.s = (self.s * 16807) % 2147483647
	return self.s / 2147483647
end

function Rng:range(a, b)
	return a + (b - a) * self:next()
end

function Rng:int(a, b)
	return a + math.floor(self:next() * (b - a + 1))
end

function Rng:chance(p)
	return self:next() < p
end

function Rng:pick(list)
	return list[self:int(1, #list)]
end

-- угол в радианах
function Rng:angle()
	return self:next() * 2 * math.pi
end

return Rng
