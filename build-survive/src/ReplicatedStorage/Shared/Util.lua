-- Мелкие помощники.
local Util = {}

-- 1250000 -> "1 250 000"
function Util.formatNumber(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local neg = string.sub(s, 1, 1) == "-"
	if neg then
		s = string.sub(s, 2)
	end
	local out = string.reverse(s):gsub("(%d%d%d)", "%1 ")
	out = string.reverse(out)
	if string.sub(out, 1, 1) == " " then
		out = string.sub(out, 2)
	end
	return (neg and "-" or "") .. out
end

function Util.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Util.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Util.colorToHex(c: Color3): string
	return string.format("%02X%02X%02X", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end

function Util.hexToColor(hex: string): Color3?
	if typeof(hex) ~= "string" or #hex ~= 6 then
		return nil
	end
	local r, g, b = tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16), tonumber(string.sub(hex, 5, 6), 16)
	if not (r and g and b) then
		return nil
	end
	return Color3.fromRGB(r, g, b)
end

-- Склонение: 1 блок, 2 блока, 5 блоков
function Util.plural(n: number, one: string, few: string, many: string): string
	local n10, n100 = n % 10, n % 100
	if n10 == 1 and n100 ~= 11 then
		return one
	elseif n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14) then
		return few
	end
	return many
end

function Util.isFiniteNumber(v: any): boolean
	return typeof(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function Util.shuffle<T>(t: { T }, rng: Random?): { T }
	local r = rng or Random.new()
	for i = #t, 2, -1 do
		local j = r:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

return Util
