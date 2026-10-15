--[[
	Format — красивые числа для интерфейса: 1500 -> "1.5K", 2300000 -> "2.3M".
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- Убирает лишние нули после точки: "1.50" -> "1.5", "2.00" -> "2".
local function trimZeros(text)
	if string.find(text, "%.") then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

local function threeDigits(value)
	if value >= 100 then
		return string.format("%.0f", value)
	elseif value >= 10 then
		return trimZeros(string.format("%.1f", value))
	end
	return trimZeros(string.format("%.2f", value))
end

-- Сокращённое число: 999 -> "999", 1234 -> "1.23K", 12.5 -> "12.5".
function Format.Number(value)
	value = tonumber(value) or 0
	if value ~= value or value == math.huge or value == -math.huge then
		return "∞"
	end

	local sign = ""
	if value < 0 then
		sign = "-"
		value = -value
	end

	if value < 1000 then
		if value == math.floor(value) then
			return sign .. string.format("%d", value)
		end
		return sign .. trimZeros(string.format("%.1f", value))
	end

	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end

	local text = threeDigits(value)
	-- 999.95K округляется до "1000" — переносим на следующий суффикс.
	if tonumber(text) and tonumber(text) >= 1000 and index < #SUFFIXES then
		value /= 1000
		index += 1
		text = threeDigits(value)
	end
	return sign .. text .. SUFFIXES[index]
end

-- Полное число с пробелами между разрядами: 1234567 -> "1 234 567".
function Format.Full(value)
	value = math.floor(tonumber(value) or 0)
	local text = tostring(math.abs(value))
	local result = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1 ")))
	result = string.gsub(result, "^ ", "")
	if value < 0 then
		result = "-" .. result
	end
	return result
end

-- Множитель: 2 -> "x2", 1.25 -> "x1.25".
function Format.Multiplier(value)
	value = tonumber(value) or 1
	if value >= 1000 then
		return "x" .. Format.Number(value)
	end
	return "x" .. trimZeros(string.format("%.2f", value))
end

-- Проценты: 60 -> "60%", 4.5 -> "4.5%", 0.25 -> "0.25%".
function Format.Percent(value)
	value = tonumber(value) or 0
	if value == math.floor(value) then
		return string.format("%d%%", value)
	elseif value >= 1 then
		return trimZeros(string.format("%.1f", value)) .. "%"
	end
	return trimZeros(string.format("%.2f", value)) .. "%"
end

-- Заглавные буквы с кириллицей: string.upper в Roblox меняет только латиницу.
function Format.Upper(text)
	local out = {}
	for _, code in utf8.codes(text) do
		if code >= 0x430 and code <= 0x44F then
			code -= 0x20
		elseif code == 0x451 then
			code = 0x401
		elseif code >= 97 and code <= 122 then
			code -= 32
		end
		table.insert(out, utf8.char(code))
	end
	return table.concat(out)
end

return Format
