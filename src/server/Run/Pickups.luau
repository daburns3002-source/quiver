--!strict
--[[
	What lies on the arena floor: XP crystals and hearts.

	The server owns every pickup. It decides what a kill drops, rolls the
	heart chance, holds each crystal's XP, and decides who walked over which
	heart. Clients are told that something dropped or was taken and draw it;
	nothing a client sends can create, move or collect one.

	Crystals belong to the player whose kill dropped them, and are credited to
	them alone, so two players in one arena never share or steal each other's
	XP. Hearts belong to nobody: whoever walks over one first takes it.

	This module holds the floor and answers questions about it. It does not
	award XP or heal anyone; `RunSession` does that with what this returns,
	which keeps the XP rules in one place.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local Pickups = {}

export type Kind = "Crystal" | "Heart"

type Pickup = {
	id: number,
	kind: Kind,
	position: Vector3,
	--[[ Crystals only: whose kill it was, and the XP it carries. ]]
	owner: Player?,
	xp: number,
}

local pickupDropped = Remotes.event(Remotes.PickupDropped)
local pickupsTaken = Remotes.event(Remotes.PickupsTaken)
local pickupsCleared = Remotes.event(Remotes.PickupsCleared)

local pickups: { [number]: Pickup } = {}
local nextId = 0

--[[ Height a pickup rests at: on the floor, not in it. ]]
local REST_Y = 0.6

local function add(kind: Kind, position: Vector3, owner: Player?, xp: number, from: Vector3)
	nextId += 1

	local pickup: Pickup = {
		id = nextId,
		kind = kind,
		position = Vector3.new(position.X, REST_Y, position.Z),
		owner = owner,
		xp = xp,
	}
	pickups[pickup.id] = pickup

	--[[ `from` is where it pops out of, so the client can throw it from the
	     body to where it lands rather than have it appear in place. ]]
	pickupDropped:FireAllClients(pickup.id, kind, pickup.position, from)
end

--[[
	A point within `radius` of `centre`, scattered by `random` and kept off
	the obstacles and inside the walls — a crystal inside a pillar is still
	collected, but a heart inside one could never be reached.
]]
local function scatter(
	centre: Vector3,
	radius: number,
	random: Random,
	resolve: (Vector3) -> Vector3
): Vector3
	local angle = random:NextNumber(0, 2 * math.pi)
	local distance = radius * math.sqrt(random:NextNumber())
	local point = centre + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	return resolve(point)
end

--[[
	How a kill's XP splits into crystals: `count` crystals carrying `each`,
	the last carrying whatever is left, so the crystals always add up to
	exactly what the kill was worth.
]]
function Pickups.split(xp: number): { number }
	local config = Balance.Pickups
	local count = math.clamp(math.ceil(xp / config.xpPerCrystal), 1, config.maxCrystalsPerKill)
	local each = math.floor(xp / count)

	local parts = table.create(count, each)
	parts[count] = xp - each * (count - 1)
	return parts
end

--[[
	What a kill leaves behind: its XP as crystals for `owner`, and perhaps a
	heart. `resolve` keeps a point off obstacles; it is passed in so this
	module stays testable without an arena standing.
]]
function Pickups.dropForKill(
	owner: Player,
	position: Vector3,
	xp: number,
	random: Random,
	resolve: (Vector3) -> Vector3
)
	local config = Balance.Pickups

	if xp > 0 then
		for _, amount in Pickups.split(xp) do
			add(
				"Crystal",
				scatter(position, config.crystalScatter, random, resolve),
				owner,
				amount,
				position
			)
		end
	end

	if random:NextNumber() < config.heartChance then
		Pickups.dropHeart(scatter(position, config.crystalScatter, random, resolve), position)
	end
end

function Pickups.dropHeart(position: Vector3, from: Vector3?)
	add("Heart", position, nil, 0, from or position)
end

--[[
	Draws every crystal in to its owner. Returns the XP each player is owed;
	crediting it is the caller's job. A crystal whose owner has left is simply
	gone.
]]
function Pickups.collectCrystals(): { [Player]: number }
	local owed: { [Player]: number } = {}
	local taken: { [Player]: { number } } = {}

	for id, pickup in pickups do
		local owner = pickup.owner
		if pickup.kind ~= "Crystal" then
			continue
		end

		pickups[id] = nil

		if owner and owner.Parent then
			owed[owner] = (owed[owner] or 0) + pickup.xp
			taken[owner] = taken[owner] or {}
			table.insert(taken[owner], id)
		end
	end

	for owner, ids in taken do
		pickupsTaken:FireAllClients(ids, owner)
	end

	return owed
end

--[[ Takes `player`'s own crystals within reach of `position`, and returns
     the XP they carried. Someone else's crystals stay where they are. ]]
function Pickups.takeCrystals(player: Player, position: Vector3): number
	local reach = Balance.Pickups.crystalRadius
	local ids: { number } = {}
	local xp = 0

	for id, pickup in pickups do
		if pickup.kind ~= "Crystal" or pickup.owner ~= player then
			continue
		end

		local offset = pickup.position - position
		if Vector2.new(offset.X, offset.Z).Magnitude <= reach then
			pickups[id] = nil
			table.insert(ids, id)
			xp += pickup.xp
		end
	end

	if #ids > 0 then
		pickupsTaken:FireAllClients(ids, player)
	end

	return xp
end

--[[ Takes every heart within reach of `position` for `player`, and returns
     how many. ]]
function Pickups.takeHearts(player: Player, position: Vector3): number
	local reach = Balance.Pickups.heartRadius
	local ids: { number } = {}

	for id, pickup in pickups do
		if pickup.kind ~= "Heart" then
			continue
		end

		local offset = pickup.position - position
		if Vector2.new(offset.X, offset.Z).Magnitude <= reach then
			pickups[id] = nil
			table.insert(ids, id)
		end
	end

	if #ids > 0 then
		pickupsTaken:FireAllClients(ids, player)
	end

	return #ids
end

function Pickups.count(kind: Kind): number
	local total = 0
	for _, pickup in pickups do
		if pickup.kind == kind then
			total += 1
		end
	end
	return total
end

--[[ Where each pickup of `kind` lies. For tests and probes. ]]
function Pickups.positions(kind: Kind): { Vector3 }
	local out = {}
	for _, pickup in pickups do
		if pickup.kind == kind then
			table.insert(out, pickup.position)
		end
	end
	return out
end

--[[ Empties the floor: a new arena starts bare, and nothing from the old one
     can be collected in it. ]]
function Pickups.clear()
	table.clear(pickups)
	pickupsCleared:FireAllClients()
end

return Pickups
