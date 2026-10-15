--[[
	RateLimiter — «ведро с жетонами» для защиты от спама запросами.
	rate  — сколько действий в секунду разрешено в среднем
	burst — сколько можно сделать подряд после паузы
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(rate, burst)
	return setmetatable({
		Rate = rate,
		Burst = burst or rate,
		Buckets = {},
	}, RateLimiter)
end

function RateLimiter:Allow(player)
	local now = os.clock()
	local bucket = self.Buckets[player]
	if not bucket then
		bucket = { Tokens = self.Burst, Time = now }
		self.Buckets[player] = bucket
	end
	bucket.Tokens = math.min(self.Burst, bucket.Tokens + (now - bucket.Time) * self.Rate)
	bucket.Time = now
	if bucket.Tokens >= 1 then
		bucket.Tokens -= 1
		return true
	end
	return false
end

function RateLimiter:Remove(player)
	self.Buckets[player] = nil
end

return RateLimiter
