--!strict
--[[
	Co-op (`docs/COOP.md`): the party's size and what it scales, as pure
	functions both sides read.

	The party's size is **locked when a run starts** and published as the
	Workspace's `PartySize` attribute (`partySize`). It is never recomputed
	when a player leaves, or a party could drop a player to make a boss
	easier (the kick exploit).

	- **Enemy count** is what scales, not their health, so more players
	  means more of the game rather than a spongier one. A boss is one body,
	  so a boss fight's count never scales; boss health takes it instead.
	- **Enemy damage is untouched**: there are just more things hitting.
	- **Downed and revive**: after Second Wind and any pet revive are spent,
	  a player at zero health in a party goes down rather than dying. A
	  teammate standing close for `revive.hold` seconds stands them up at
	  `revive.health` of max health. Down for `revive.bleedOut` seconds with
	  nobody there, they are out until the next room, which they start at
	  `revive.returnHealth`. The run is lost only when nobody is standing.

	The arena footprint does not scale: the arenas are art imports now, 1:1
	with their sheets, not the procedural kits the doc was written against.
]]

local Workspace = game:GetService("Workspace")

local Coop = {}

--[[ The most players a party holds. Two first, three later (owner,
     2026-10-27). ]]
Coop.maxParty = 2

--[[ Per party size, from 1. Sizes past the table use its last row. ]]
Coop.scale = {
	{ count = 1.0, health = 1.0, bossHealth = 1.0 },
	{ count = 1.65, health = 1.10, bossHealth = 1.7 },
	{ count = 2.3, health = 1.20, bossHealth = 2.3 },
}

Coop.revive = {
	--[[ Studs from the downed player a teammate must stand within. ]]
	radius = 6,
	--[[ Seconds the teammate must stay in range. Leaving range keeps the
	     progress but stops it filling; it drains at `drain` per second. ]]
	hold = 2.5,
	drain = 1,
	--[[ Share of max health a revive stands them up at. ]]
	health = 0.4,
	--[[ Seconds down before they are out for the rest of the room. ]]
	bleedOut = 20,
	--[[ Share of max health an out player starts the next room at. ]]
	returnHealth = 0.3,
}

--[[ Party portal: how long a START waits for the teleport, seconds, and how
     long a run server waits for its whole party to arrive. ]]
Coop.arrivalWait = 20

Coop.ATTRIBUTE = "PartySize"

local function row(size: number)
	local index = math.clamp(math.floor(size), 1, #Coop.scale)
	return Coop.scale[index]
end

--[[ The locked party size of the run being played: 1 outside a run. ]]
function Coop.partySize(): number
	local size = Workspace:GetAttribute(Coop.ATTRIBUTE)
	return if type(size) == "number" and size >= 1 then math.floor(size) else 1
end

--[[ How many enemies a fight of `count` brings for a party of `size`.
     Rounded, and never fewer than the solo count. ]]
function Coop.enemyCount(count: number, size: number): number
	if count <= 0 then
		return count
	end
	return math.max(count, math.floor(count * row(size).count + 0.5))
end

--[[ The health multiplier on an enemy for a party of `size`. ]]
function Coop.healthScale(size: number, boss: boolean): number
	local r = row(size)
	return if boss then r.bossHealth else r.health
end

--[[ How far a revive has come after `dt` seconds, from `progress` (0 to
     `revive.hold`), with or without a teammate in range. ]]
function Coop.reviveStep(progress: number, dt: number, inRange: boolean): number
	if inRange then
		return math.min(Coop.revive.hold, progress + dt)
	end
	return math.max(0, progress - dt * Coop.revive.drain)
end

--[[ Who goes into the party at a portal: the starter first, then the others
     standing in that portal, in join order, up to `maxParty`. Pure, over
     user ids, so it is testable without players. ]]
function Coop.pickParty(starter: number, inPortal: { number }): { number }
	local party = { starter }
	for _, id in inPortal do
		if #party >= Coop.maxParty then
			break
		end
		if id ~= starter then
			table.insert(party, id)
		end
	end
	return party
end

return Coop
