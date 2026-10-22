--!strict
--[[
	Remote accessor.

	The server creates the remotes; the client waits for them. Both sides name
	them through this module so a typo is a missing key rather than a silent
	`WaitForChild` that hangs forever.

	Nothing here grants authority. Every remote listed below is server→client
	except RequestRespawn, and that one carries no payload the server trusts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local WAIT_TIMEOUT = 10

local Remotes = {}

--[[
	Server → clients. One packet per volley, carrying the whole shot description
	so clients can simulate the flight locally. See Types.ShotEvent.
]]
Remotes.ShotFired = "ShotFired"

--[[
	Server → clients. An enemy took damage: enough for a flash and a damage
	number. The client is told what happened, never asked to decide it.
]]
Remotes.EnemyHit = "EnemyHit"

--[[
	Server → clients. An enemy died, for the death effect. Carries the position
	and nothing else: the enemy instance is destroyed in the same step, so a
	reference to it would not reliably survive the trip. Anything a future
	effect needs — archetype, rarity, loot — travels as data, never as the
	instance it describes.
]]
Remotes.EnemyDied = "EnemyDied"

--[[
	Server → clients. An enemy began winding up a shot: origin, the direction
	it is committed to (or currently pointed), how long the wind-up lasts, and
	which tell to draw.

	Sent as data rather than as a part the server builds, for the same reason
	projectiles are: the client decides how to draw a warning, the server only
	decides that there is one. A `Line` tell is only truthful because the
	matching shot locks its aim — see Balance.EnemyShot.locksAim.
]]
Remotes.EnemyTelegraph = "EnemyTelegraph"

--[[
	Server → clients. The run moved on: which room, how many there are, and
	what state it is in ("Fighting", "Cleared", "Dead", "Complete").

	The client renders this and decides nothing. Room progress is exactly the
	kind of thing a client must never report — it is the gate the whole meta
	loop will hang off in Phase 5.
]]
Remotes.RunStateChanged = "RunStateChanged"

--[[ Server → one client. The local player took damage, for shake and vignette. ]]
Remotes.PlayerDamaged = "PlayerDamaged"

--[[ Server → one client. Health changed for any reason, including spawn. ]]
Remotes.HealthChanged = "HealthChanged"

--[[ Server → one client. Run XP and level, for the bar under the health. ]]
Remotes.XpChanged = "XpChanged"

--[[
	Server → one client. Here are the cards you may choose from.

	Ability *ids*, because the client has the same Config and can render names
	and descriptions itself. The server keeps the authoritative copy of what it
	offered, so the reply below can be checked rather than believed.
]]
Remotes.AbilityOffer = "AbilityOffer"

--[[
	Client → server. "I pick the nth card."

	An index into the offer the server itself just sent, and nothing else. A
	client that lies can only pick a different one of the three cards it was
	already going to be allowed to pick — it cannot name an ability, a stack
	count or a stat. See CLAUDE.md, non-negotiable 2.
]]
Remotes.AbilityChosen = "AbilityChosen"

--[[
	Server → one client. The stats the client needs in order to predict.

	Deliberately tiny, and deliberately not "the player's stats": the client
	pins WalkSpeed every frame and runs the dash timer locally, so those two
	numbers have to live there or prediction fights the server. Nothing that
	decides an outcome is ever sent here.
]]
Remotes.PlayerStats = "PlayerStats"

--[[
	Server → one client. The run is over; here is what you built.

	Sent on death and on finishing the last room. Carries the held abilities
	rather than a rendered string, so the client can show them however it
	likes and the server never has to know what a card looks like.
]]
Remotes.RunSummary = "RunSummary"

--[[
	Server → all clients. Something exploded here, this wide.

	The radius travels with it rather than being looked up, because what the
	player needs to learn from the effect is exactly how far the blast
	reaches — and that is a number the loadout changes. An effect drawn at a
	fixed size would teach them the wrong one.
]]
Remotes.Explosion = "Explosion"

--[[
	Server → all clients. Something dropped on the floor: an id, its kind
	("Crystal" or "Heart"), where it rests, and where it popped out from.
]]
Remotes.PickupDropped = "PickupDropped"

--[[ Server → all clients. These pickups were taken by this player; fly them
     to the player and drop them. ]]
Remotes.PickupsTaken = "PickupsTaken"

--[[ Server → all clients. The floor is bare: a new arena was built. ]]
Remotes.PickupsCleared = "PickupsCleared"

--[[ Server → all clients. This player was revived here, and cannot be hurt
     for this many seconds. ]]
Remotes.PlayerRevived = "PlayerRevived"

--[[ Server → all clients. A Soul Chain link: from the enemy hit, to each of
     these. ]]
Remotes.SoulLink = "SoulLink"

--[[ Server → one client. A hit on this player missed: Agility. ]]
Remotes.PlayerDodged = "PlayerDodged"

--[[ Client → server. Redeal the open hand. The server checks there is a
     hand and a reroll left; the client says nothing else. ]]
Remotes.AbilityReroll = "AbilityReroll"

--[[ Client → server, testing only. Asks that the next hand include a
     Mythic, so its reveal can be seen. The server ignores it outside Studio. ]]
Remotes.DebugForceMythic = "DebugForceMythic"

local function getFolder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing :: Folder
		end

		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end

	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT)
	assert(folder, `Remotes folder never replicated after {WAIT_TIMEOUT}s`)
	return folder :: Folder
end

--[[
	Returns the named RemoteEvent, creating it on the server and waiting for it
	on the client.
]]
function Remotes.event(name: string): RemoteEvent
	local folder = getFolder()

	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end

		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end

	local remote = folder:WaitForChild(name, WAIT_TIMEOUT)
	assert(remote, `Remote "{name}" never replicated after {WAIT_TIMEOUT}s`)
	return remote :: RemoteEvent
end

return Remotes
