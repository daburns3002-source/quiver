--!strict
--[[
	The shape of one slime hop (`Balance.SlimeHop.keys`) at any point
	through it: the keys eased into one another, as the owner's handoff
	samples them. Pure, so `tests/HopCurve.spec` can pin that a hop starts
	and ends at rest and never jumps; `Fx/SlimeHop` draws it.
]]

local HopCurve = {}

export type Key = {
	at: number,
	tall: number,
	wide: number,
	deep: number,
	tilt: number,
	lift: number,
	ease: number,
}

export type Sample = {
	tall: number,
	wide: number,
	deep: number,
	tilt: number,
	lift: number,
	ease: number,
}

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

--[[ The hop `f` of the way through (only its fractional part counts). ]]
function HopCurve.sample(keys: { Key }, f: number): Sample
	f = f % 1
	local i = 1
	while i < #keys - 1 and f > keys[i + 1].at do
		i += 1
	end
	local a, b = keys[i], keys[i + 1]
	local span = b.at - a.at
	local u = if span > 0 then smooth(math.clamp((f - a.at) / span, 0, 1)) else 1
	local function mix(x: number, y: number): number
		return x + (y - x) * u
	end
	return {
		tall = mix(a.tall, b.tall),
		wide = mix(a.wide, b.wide),
		deep = mix(a.deep, b.deep),
		tilt = mix(a.tilt, b.tilt),
		lift = mix(a.lift, b.lift),
		ease = mix(a.ease, b.ease),
	}
end

return HopCurve
