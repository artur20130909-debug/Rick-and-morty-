-- Упаковка постройки в строку (для сохранения в DataStore) и обратно.
-- Формат v1: "v1|" + блоки через ";", поля блока через ",":
--   материал, форма, особый блок, x*2, y*2, z*2, ширина, высота, длина, поворот, цвет (hex)
-- Формат v2 (есть выкопанная земля): "v2|" + блоки (как в v1, могут быть пустыми) + "|" + маска
--   выкопанных клеток (hex, см. Shared/Underground).
local Util = require(script.Parent.Util)

local Serializer = {}

export type Spec = {
	mat: number,
	shape: number,
	item: number,
	pos: Vector3,
	size: Vector3,
	rot: number,
	color: Color3,
}

function Serializer.encode(specs: { Spec }, digHex: string?): string
	local parts = table.create(#specs)
	for i, s in specs do
		parts[i] = string.format(
			"%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s",
			s.mat or 0, s.shape or 1, s.item or 0,
			math.round(s.pos.X * 2), math.round(s.pos.Y * 2), math.round(s.pos.Z * 2),
			math.round(s.size.X), math.round(s.size.Y), math.round(s.size.Z),
			s.rot or 1, Util.colorToHex(s.color)
		)
	end
	local blocks = table.concat(parts, ";")
	if typeof(digHex) == "string" and digHex ~= "" then
		return "v2|" .. blocks .. "|" .. digHex
	end
	return "v1|" .. blocks
end

-- Строка разбирается на часть с блоками и маску земли (nil — формат не наш)
local function split(str: string?): (string?, string?)
	if typeof(str) ~= "string" then
		return nil, nil
	end
	local version = string.sub(str, 1, 3)
	local rest = string.sub(str, 4)
	if version == "v1|" then
		return rest, nil
	elseif version == "v2|" then
		local bar = string.find(rest, "|", 1, true)
		if bar then
			return string.sub(rest, 1, bar - 1), string.sub(rest, bar + 1)
		end
		return rest, nil
	end
	return nil, nil
end

function Serializer.decode(str: string?): { Spec }
	local out = {}
	local blocks = split(str)
	if not blocks then
		return out
	end
	for chunk in string.gmatch(blocks, "[^;]+") do
		local f = string.split(chunk, ",")
		if #f == 11 then
			local n = {}
			local ok = true
			for i = 1, 10 do
				n[i] = tonumber(f[i])
				if not n[i] then
					ok = false
					break
				end
			end
			local color = Util.hexToColor(f[11])
			if ok and color then
				table.insert(out, {
					mat = n[1], shape = n[2], item = n[3],
					pos = Vector3.new(n[4] / 2, n[5] / 2, n[6] / 2),
					size = Vector3.new(n[7], n[8], n[9]),
					rot = n[10],
					color = color,
				})
			end
		end
	end
	return out
end

-- Маска выкопанной земли из строки v2 (nil — земля не тронута)
function Serializer.dig(str: string?): string?
	local _, hex = split(str)
	if hex and hex ~= "" then
		return hex
	end
	return nil
end

function Serializer.count(str: string?): number
	local blocks = split(str)
	if not blocks or blocks == "" then
		return 0
	end
	local _, n = string.gsub(blocks, ";", ";")
	return n + 1
end

return Serializer
