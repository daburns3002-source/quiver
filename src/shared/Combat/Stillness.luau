--!strict
--[[
	The stillness channel: a card that charges while the player stands still.

	This game attacks when the player stops, so standing still is the moment
	of commitment, and several cards pay out on how long it has lasted
	(docs/CARD-IDEAS.md, "build these once"): Sniper Shot and Barrage ready
	a shot, Singularity grows an orb, Stone Skin raises a guard, Blade
	Cyclone keeps its blades whirling. Each asks the same two questions of
	the same clock, `Session.stationarySince` (os.clock, nil while moving),
	so they all live here, pure, and `tests/Stillness.spec` pins them.

	A charge that is spent starts again from the moment it was spent, not
	from the moment the player stopped: standing still for ten seconds pays
	a 2 s charge five times, not once and then every frame.
]]

local Stillness = {}

--[[ Seconds the player has stood still at `now`; 0 while moving. ]]
function Stillness.heldFor(since: number?, now: number): number
	if not since then
		return 0
	end
	return math.max(0, now - since)
end

--[[ Whether a charge of `charge` seconds is full at `now`: the player has
     stood still that long, and that long since it was last spent at
     `spentAt` (-math.huge for never). ]]
function Stillness.ready(since: number?, spentAt: number, charge: number, now: number): boolean
	if not since then
		return false
	end
	return now - math.max(since, spentAt) >= charge
end

--[[ How far a charge has come at `now`, 0 to 1, for something drawn growing
     as it charges (Singularity's orb). 0 while moving. ]]
function Stillness.progress(since: number?, spentAt: number, charge: number, now: number): number
	if not since or charge <= 0 then
		return 0
	end
	return math.clamp((now - math.max(since, spentAt)) / charge, 0, 1)
end

return table.freeze(Stillness)
