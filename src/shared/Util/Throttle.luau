--!strict
--[[
	A token bucket: `burst` asks at once, then `rate` a second. Pure, so
	`tests/Throttle.spec` can drive it with made-up clocks.

	What `Net/Inbound` holds every remote a client fires to: one bucket per
	player per remote. A person pressing buttons never empties one; a script
	firing a remote in a loop does, and from then on gets `rate` a second.
]]

local Throttle = {}

export type Bucket = { tokens: number, at: number }

function Throttle.new(burst: number, now: number): Bucket
	return { tokens = burst, at = now }
end

--[[ Takes one ask from the bucket, refilled for the time since the last.
     False (and nothing taken) when it is empty. A clock that goes back adds
     nothing. ]]
function Throttle.take(bucket: Bucket, now: number, rate: number, burst: number): boolean
	local since = math.max(0, now - bucket.at)
	bucket.tokens = math.min(burst, bucket.tokens + since * rate)
	bucket.at = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

return Throttle
