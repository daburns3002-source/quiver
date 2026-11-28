--!strict
--[[
	Co-op: the pick made for a player who does not make it (`docs/COOP.md`,
	"The idle clock").

	A card screen or an Endless checkpoint holds the world for the whole
	party, and it used to hold it for as long as one player left it open: a
	teammate away from the keyboard stopped the run for good, and BACK TO
	LOBBY was the only way on (the four-playtester pass, 2026-11-28; owner
	the same day: "Yes, add it"). With more than one player in the run, a
	screen left open for `Coop.idle` seconds is answered by the server:

	- **a card screen** takes the rarest card in the hand, the leftmost of
	  equals: the player comes back to a build no worse than one they might
	  have picked;
	- **a checkpoint** takes FULL HEAL. Never BANK & LEAVE, which ends the
	  run for everybody, and never the Soulstone cache: nothing is paid for
	  being away.

	Alone, nothing is timed. A player whose teammate has left is alone.

	The clock is shown on both screens: the Player's `DRAFT` or `CHECKPOINT`
	attribute is the server time the pick will be made at, so the chooser
	counts down their own last seconds and the teammate reads who the run is
	waiting for (`UI/IdleClock`). The server keeps its own deadline on its own
	clock; the attribute is only for the words.

	Pure: what is picked and what is said. `Run/RunSession` and
	`Run/RoomController` keep the clocks.
]]

local IdlePick = {}

--[[ The Player attributes: the server time (`Workspace:GetServerTimeNow`)
     an open card screen, or an open checkpoint, is answered at. Nil when
     nothing is being timed for them. ]]
IdlePick.DRAFT = "DraftPickBy"
IdlePick.CHECKPOINT = "CheckpointPickBy"

--[[ What `Remotes.IdlePick` says was answered. ]]
export type Kind = "Card" | "Gift"

--[[ Whether a screen is timed at all: only with somebody else in the run
     to be kept waiting. `present` is the players here now, not the party's
     locked size, so a player left alone by a teammate reads as long as they
     like. ]]
function IdlePick.applies(present: number): boolean
	return present > 1
end

--[[ The card taken from `offer` (ability ids): the one of the highest
     `tierOf`, the first of equals. 0 for an empty hand, which nothing
     chooses. ]]
function IdlePick.card(offer: { string }, tierOf: (string) -> number): number
	local best, bestTier = 0, -math.huge
	for index, id in offer do
		local tier = tierOf(id)
		if tier > bestTier then
			best, bestTier = index, tier
		end
	end
	return best
end

--[[ The checkpoint's pick: the heal's index in `picks`
     (`Balance.Endless.checkpoint.picks`), the first if there is none. Each
     pick is read for its `key` alone, whatever else it carries. ]]
function IdlePick.gift(picks: { any }): number
	for index, pick in picks do
		if type(pick) == "table" and pick.key == "Heal" then
			return index
		end
	end
	return 1
end

--[[ Whole seconds until `by`, never under 0; nil with no clock. ]]
function IdlePick.left(by: unknown, now: number): number?
	if type(by) ~= "number" then
		return nil
	end
	return math.max(0, math.ceil(by - now))
end

--[[
	The clock's line, nil for none.

	`mine` is this player's seconds left, `warn` the last seconds they are
	counted down for: before that a clock over a hand being read is only
	noise. `waitingOn` and `theirs` are a teammate the run waits for and
	their seconds; said only to a player with no screen of their own, who
	otherwise looks at a room that has stopped for no reason they can see.
]]
function IdlePick.line(mine: number?, warn: number, waitingOn: string?, theirs: number?): string?
	if mine then
		return if mine <= warn then `PICKING FOR YOU IN {mine}` else nil
	end
	if waitingOn and theirs then
		return `WAITING FOR {string.upper(waitingOn)}: {theirs}`
	end
	return nil
end

--[[ What is said once a pick has been made for the player. ]]
function IdlePick.picked(name: string): string
	return if name == "" then "PICKED FOR YOU" else `PICKED FOR YOU: {string.upper(name)}`
end

return IdlePick
