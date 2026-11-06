--!strict
--[[
	The Bogheart Caverns pets' targeting rules (docs/PETS-BOGHEART.md,
	Attacks). Bogheart is the crowded area (docs/ENEMIES-AND-ARENAS.md: "lean:
	Arcanist (crowded)"), so most of its pets read the room as a crowd: who
	is standing near whom, who is furthest off, what is inside a sneeze.

	Pure, so the server (`Combat/PetCombat`), the one-number power scale
	(`Util/PetPower`) and the hatchery's words (`Util/PetBlurb`) read one
	rule, and `tests/PetCrowd.spec` pins it. Every distance here is flat:
	height never decides who is in a crowd.
]]

--[[ An enemy as `Combat/PetCombat` sees it. ]]
export type Spot = { model: Model, position: Vector3 }

--[[ The Lichen Gecko's Fourth Lick: every `every`th attack hits `scale`
     times as hard. Counted, not rolled -- a pet is never luckier for one
     player than another. ]]
export type Combo = { every: number, scale: number }

--[[ The Olm's Tremor Snap: a bite is `per` harder for every other enemy
     within `radius` studs of its target, counting at most `most`. ]]
export type Crowd = { radius: number, per: number, most: number }

--[[ The Lanternfin's Glow Mote: the hit lands `fuse` seconds late, on the
     target and every enemy within `radius` studs of where it then stands. ]]
export type Burst = { radius: number, fuse: number }

--[[ The Gulpling's Little Belly Flop: it lands on the enemy with the most
     others around it, hitting everything within `radius` studs. ]]
export type Flop = { radius: number }

--[[ The Glowcap Wilf's Spore Sneeze: everything in a wedge `angle` degrees
     wide toward the nearest enemy, out to the pet's `range`. ]]
export type Cone = { angle: number }

--[[ The Prism Leviathan's Prism Split: as the bolt lands it breaks into
     `shards`, each flying to a different enemy within `radius` studs of
     the struck one for `share` of the bolt. ]]
export type Split = { shards: number, share: number, radius: number }

local PetCrowd = {}

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

--[[ The spots within `radius` of `at`, nearest first, leaving out
     `except` (the enemy the crowd is counted round). ]]
function PetCrowd.around(spots: { Spot }, at: Vector3, radius: number, except: Model?): { Spot }
	local out = {}
	for _, spot in spots do
		if spot.model ~= except and flat(spot.position, at) <= radius then
			table.insert(out, spot)
		end
	end
	table.sort(out, function(a, b)
		return flat(a.position, at) < flat(b.position, at)
	end)
	return out
end

--[[ The furthest of `spots` from `origin` (the Cave Cricket's Long Chirp
     picks the enemy the player is least likely to be dealing with). ]]
function PetCrowd.farthest(spots: { Spot }, origin: Vector3): Spot?
	local best: Spot? = nil
	local far = -1
	for _, spot in spots do
		local d = flat(spot.position, origin)
		if d > far then
			best, far = spot, d
		end
	end
	return best
end

--[[ The spot with the most others within `radius` of it. On a tie the
     earlier one wins, and `Combat/PetCombat` hands these over nearest
     first, so an even room is answered at the nearest. ]]
function PetCrowd.densest(spots: { Spot }, radius: number): Spot?
	local best: Spot? = nil
	local most = -1
	for _, spot in spots do
		local count = #PetCrowd.around(spots, spot.position, radius, spot.model)
		if count > most then
			best, most = spot, count
		end
	end
	return best
end

--[[ What a Combo multiplies attack number `attack` (1 for the first) by. ]]
function PetCrowd.comboScale(combo: Combo, attack: number): number
	if combo.every >= 1 and attack % combo.every == 0 then
		return combo.scale
	end
	return 1
end

--[[ A Combo's worth over many attacks: one in `every` is `scale`. ]]
function PetCrowd.comboAverage(combo: Combo): number
	if combo.every < 1 then
		return 1
	end
	return 1 + (combo.scale - 1) / combo.every
end

--[[ What a Crowd multiplies a bite by, with `others` enemies beside the
     target. Never below 1: an enemy alone takes a plain bite. ]]
function PetCrowd.crowdScale(crowd: Crowd, others: number): number
	return 1 + crowd.per * math.clamp(others, 0, crowd.most)
end

--[[ Whether `point` is inside a cone from `origin` toward `toward`,
     `angle` degrees wide in all and `reach` studs long. ]]
function PetCrowd.inCone(
	origin: Vector3,
	toward: Vector3,
	point: Vector3,
	angle: number,
	reach: number
): boolean
	local ahead = Vector3.new(toward.X - origin.X, 0, toward.Z - origin.Z)
	local offset = Vector3.new(point.X - origin.X, 0, point.Z - origin.Z)
	if offset.Magnitude > reach then
		return false
	end
	if ahead.Magnitude < 1e-3 or offset.Magnitude < 1e-3 then
		-- standing on top of the pet's owner is inside any sneeze
		return true
	end
	local cos = ahead.Unit:Dot(offset.Unit)
	return cos >= math.cos(math.rad(angle / 2)) - 1e-6
end

--[[ The enemies a Split's shards go to, struck at `at`: the nearest
     `shards` others within its radius. ]]
function PetCrowd.shardTargets(split: Split, spots: { Spot }, at: Vector3, struck: Model): { Spot }
	local near = PetCrowd.around(spots, at, split.radius, struck)
	local out = {}
	for i = 1, math.min(split.shards, #near) do
		out[i] = near[i]
	end
	return out
end

return table.freeze(PetCrowd)
