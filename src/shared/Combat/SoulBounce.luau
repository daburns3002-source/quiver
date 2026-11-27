--!strict
--[[
	Soul Chain's fireball: the order it leaps between the linked enemies, when
	it lands on each, and the arc of a leap (owner, 2026-11-11: "soul link
	should be like brand ult").

	One pure module for both sides. The server decides who is linked and for
	how much, as it always did (`Server/Combat/SoulLink`); this only says in
	what order the fireball visits them and how long each leap takes, so the
	server can land each share as the fireball does and the client can draw
	the same leaps (`Fx/Upgrades/SoulFireFx`). Pinned by `tests/ChainSoulFx.spec`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local SoulBounce = {}

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

--[[ The order to visit `stops` in, as indices into it: always the nearest
     one not yet visited, starting from `from`, so the fireball never leaps
     past one enemy to reach another. ]]
function SoulBounce.route(from: Vector3, stops: { Vector3 }): { number }
	local order: { number } = {}
	local visited: { [number]: boolean } = {}
	local at = from
	for _ = 1, #stops do
		local best, bestDistance = 0, math.huge
		for index, stop in stops do
			if not visited[index] then
				local distance = flatDistance(at, stop)
				if distance < bestDistance then
					best, bestDistance = index, distance
				end
			end
		end
		visited[best] = true
		table.insert(order, best)
		at = stops[best]
	end
	return order
end

--[[ Seconds one leap of `distance` studs takes. ]]
function SoulBounce.hopTime(distance: number): number
	local hop = Balance.Projectile.linkHop
	return math.clamp(distance / hop.speed, hop.min, hop.max)
end

--[[ Seconds after it sets out that the fireball lands on each of `stops`,
     visited in the order given. ]]
function SoulBounce.times(from: Vector3, stops: { Vector3 }): { number }
	local times: { number } = {}
	local at, elapsed = from, 0
	for _, stop in stops do
		elapsed += SoulBounce.hopTime(flatDistance(at, stop))
		table.insert(times, elapsed)
		at = stop
	end
	return times
end

--[[ How high a leap of `distance` studs rises at its middle. ]]
function SoulBounce.apex(distance: number): number
	local leap = Balance.UpgradeFx.soul.leap
	return math.clamp(distance * leap.share, leap.min, leap.max)
end

--[[ Where the fireball is `u` (0 to 1) of the way through a leap from `a`
     to `b`: a straight line along the ground, an arc above it. ]]
function SoulBounce.at(a: Vector3, b: Vector3, u: number): Vector3
	local t = math.clamp(u, 0, 1)
	local rise = 4 * SoulBounce.apex(flatDistance(a, b)) * t * (1 - t)
	return a:Lerp(b, t) + Vector3.new(0, rise, 0)
end

return SoulBounce
