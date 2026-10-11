-- Общие расчёты для сервера и клиента: формат чисел и времени, ролл редкости и мутации,
-- доход монстра, цена продажи.
local Config = require(script.Parent.Config)

local Util = {}

local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1234 -> "1.2K", 15 -> "15"
function Util.num(n)
	n = tonumber(n) or 0
	local neg = n < 0
	if neg then n = -n end
	local i = 1
	while n >= 1000 and i < #SUFFIX do
		n = n / 1000
		i = i + 1
	end
	local s
	if i == 1 then
		s = tostring(math.floor(n + 0.5))
	elseif n < 10 then
		s = string.format("%.2f", math.floor(n * 100) / 100)
	elseif n < 100 then
		s = string.format("%.1f", math.floor(n * 10) / 10)
	else
		s = tostring(math.floor(n))
	end
	if s:find(".", 1, true) then
		s = (s:gsub("(%..-)0+$", "%1"))
		s = (s:gsub("%.$", ""))
	end
	return (neg and "-" or "") .. s .. SUFFIX[i]
end

-- 125 -> "2:05"
function Util.time(sec)
	sec = math.max(0, math.floor(tonumber(sec) or 0))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- редкость по удаче; maxTier — самая высокая разрешённая (днём ниже)
function Util.rollRarity(rng, luck, maxTier)
	luck = math.max(1, luck or 1)
	maxTier = maxTier or #Config.Rarities
	for i = math.min(maxTier, #Config.Rarities), 2, -1 do
		local r = Config.Rarities[i]
		if rng:NextNumber() < luck / r.chance then return r end
	end
	return Config.Rarities[1]
end

-- случайный монстр этой редкости
function Util.rollMonster(rng, rarityKey)
	local list = Config.MonstersByRarity[rarityKey] or Config.MonstersByRarity.common
	return list[rng:NextInteger(1, #list)]
end

-- мутация: opts = { event = "bloodmoon"|..., gold = множитель золотых, blood = true }
function Util.rollMutation(rng, opts)
	opts = opts or {}
	local glitch = Config.MutationIndex.glitch.chance
	if opts.event == "glitch" then glitch = glitch / Config.GlitchNightMul end
	if rng:NextNumber() < 1 / glitch then return "glitch" end
	if opts.blood or opts.event == "bloodmoon" then
		local bc = opts.blood and 1.5 or Config.BloodMutationChance
		if rng:NextNumber() < 1 / bc then return "blood" end
	end
	local gold = Config.MutationIndex.gold.chance / (opts.gold or 1)
	if rng:NextNumber() < 1 / gold then return "gold" end
	return ""
end

function Util.mutMul(mut)
	local m = Config.MutationIndex[mut or ""]
	return m and m.mul or 1
end

-- доход монстра в секунду (без геймпасса)
function Util.income(key, mut)
	local m = Config.MonsterIndex[key]
	if not m then return 0 end
	return m.income * Util.mutMul(mut)
end

function Util.sellPrice(key, mut)
	return Util.income(key, mut) * Config.SellMul
end

-- подпись «Золотой Кот 404»
function Util.fullName(key, mut)
	local m = Config.MonsterIndex[key]
	local name = m and m.name or key
	local mu = Config.MutationIndex[mut or ""]
	if mu then name = mu.name .. " " .. name end
	return name
end

function Util.rarityOf(key)
	local m = Config.MonsterIndex[key]
	return Config.RarityIndex[m and m.rarity or "common"]
end

-- цвет в hex для RichText
function Util.hex(c)
	return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

return Util
