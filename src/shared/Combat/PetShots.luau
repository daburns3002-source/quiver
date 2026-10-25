--!strict
--[[
	When a pet's projectile reaches its enemy, so the server's blow lands as
	the piece drawn by `Fx/PetAttackFx` arrives (owner, 2026-10-25: the
	Hootmoss's and Babacorn's damage came before their shots). Both sides
	read it: the client for how long a piece flies, `Combat/PetCombat` for
	when each blow lands.

	A piece flies at its `speed` for the distance to its target as it leaves,
	at least `MIN_FLIGHT`; a homing one follows a moving target but still
	arrives on that clock. A pet's blows ride its first piece's volley in
	turn: blow n rides piece ((n - 1) % count) + 1, which leaves
	`at + (piece - 1) * every` into the attack.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetAttacks = require(ReplicatedStorage.Shared.Config.PetAttacks)

type Shot = PetAttacks.Shot

local PetShots = {}

PetShots.MIN_FLIGHT = 0.15
PetShots.DEFAULT_SPEED = 25
--[[ Where `Fx/PetPreview` stands a lone pet, in its owner's root frame
     (a column to the left, `BEHIND` back): the server measures flights from
     here. ]]
PetShots.HEEL = Vector3.new(-4.2, 0, 4)

--[[ The pet's first piece, if it is a projectile: its blows wait for it. ]]
function PetShots.projectile(pet: string): Shot?
	local shots = (PetAttacks :: any)[pet] :: { Shot }?
	local first = shots and shots[1]
	return if first and first.kind == "Projectile" then first else nil
end

--[[ Seconds a piece flies to a target `distance` studs away. ]]
function PetShots.flight(shot: Shot, distance: number): number
	return math.max(PetShots.MIN_FLIGHT, distance / (shot.speed or PetShots.DEFAULT_SPEED))
end

--[[ Seconds into the attack that the piece carrying blow `blow` (1-based)
     leaves the pet. ]]
function PetShots.launch(shot: Shot, blow: number): number
	local piece = (blow - 1) % math.max(shot.count or 1, 1)
	return shot.at + piece * (shot.every or 0)
end

--[[ Where the pet stands for the server: at heel of `root`. ]]
function PetShots.heel(root: CFrame): Vector3
	return root:PointToWorldSpace(PetShots.HEEL)
end

return PetShots
