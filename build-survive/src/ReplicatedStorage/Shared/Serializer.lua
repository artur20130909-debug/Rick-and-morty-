-- Упаковка постройки в строку (для сохранения в DataStore) и обратно.
-- Формат: "v1|" + блоки через ";", поля блока через ",":
--   материал, форма, особый блок, x*2, y*2, z*2, ширина, высота, длина, поворот, цвет (hex)
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

function Serializer.encode(specs: { Spec }): string
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
	return "v1|" .. table.concat(parts, ";")
end

function Serializer.decode(str: string?): { Spec }
	local out = {}
	if typeof(str) ~= "string" or string.sub(str, 1, 3) ~= "v1|" then
		return out
	end
	for chunk in string.gmatch(string.sub(str, 4), "[^;]+") do
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

function Serializer.count(str: string?): number
	if typeof(str) ~= "string" or #str <= 3 then
		return 0
	end
	local _, n = string.gsub(str, ";", ";")
	return n + 1
end

return Serializer
