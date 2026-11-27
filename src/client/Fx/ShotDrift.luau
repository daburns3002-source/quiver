--!strict
--[[
	How far the arrow you see is from the shot that did the damage.

	The player's volleys are predicted: `Combat/LocalFiring` draws an arrow
	the moment it fires, and `Main.client` throws away the server's copy of
	the same volley so the arrow is not drawn twice. That means the arrow on
	screen is the CLIENT's flight and the damage is the SERVER's, and nothing
	has ever compared the two.

	#453 fixed the part of this that was timing: both sides booked a volley at
	`now` rather than when it was due, so they crept apart for as long as the
	player stood still. What is left is spatial, and it cannot happen in
	Studio Play at all, because there one DataModel holds both sides:

	- **Origin.** The server fires from the player's replicated root, which
	  lags the client's own by roughly the upload trip while the player moves.
	- **Aim.** Both sides run `Aim.choose`, but over different data: the
	  client sees enemy positions as replication left them, the server sees
	  them live. A moving enemy puts the two aim points apart by about the
	  download trip times its speed.

	So this measures rather than guesses. It keeps the last few predictions,
	matches the server's copy of each to the one the client drew, and records
	how far apart the two origins and the two directions were. In Studio Play
	every number should be about zero -- that only proves the instrument
	works. The numbers that matter come from Studio's Test tab with a local
	server and a separate player window: the J key that reads this is
	Studio-only (`DevKeys`), so a published place cannot show them.

	Read it with `ShotDrift.report()`, bound to a dev key.
]]

local ShotDrift = {}

type Sample = { at: number, origin: Vector3, direction: Vector3 }

--[[ Long enough to still hold the prediction when the server's copy of it
     arrives on a bad connection, short enough that a stale one is never
     matched to the wrong volley. ]]
local KEEP = 1.0
--[[ Predictions awaiting the server's copy, oldest first. ]]
local pending: { Sample } = {}

local shots = 0
local matched = 0
local originSum, originWorst = 0, 0
local angleSum, angleWorst = 0, 0
local unmatched = 0

--[[ Called by `Combat/LocalFiring` for every volley this client draws. ]]
function ShotDrift.predicted(origin: Vector3, direction: Vector3)
	local now = os.clock()
	shots += 1
	table.insert(pending, { at = now, origin = origin, direction = direction })

	local keep = 1
	for index = 1, #pending do
		if now - pending[index].at <= KEEP then
			keep = index
			break
		end
		unmatched += 1
		keep = index + 1
	end
	if keep > 1 then
		table.move(pending, keep, #pending, 1)
		for index = #pending, #pending - keep + 2, -1 do
			pending[index] = nil
		end
	end
end

--[[ Called by `Main.client` with the server's copy of a volley this client
     predicted, just before it is thrown away. Matches the oldest prediction
     still waiting: volleys of one player arrive in the order they were
     fired, so the oldest unmatched one is this one's pair. ]]
function ShotDrift.server(origin: Vector3, direction: Vector3)
	local mine = table.remove(pending, 1)
	if not mine then
		return
	end

	matched += 1
	local apart = (origin - mine.origin).Magnitude
	originSum += apart
	originWorst = math.max(originWorst, apart)

	--[[ Both are unit vectors from `Aim`, but clamp anyway: a dot a hair
	     over 1 from rounding would make acos return nan and poison the sum. ]]
	local dot = math.clamp(direction:Dot(mine.direction), -1, 1)
	local degrees = math.deg(math.acos(dot))
	angleSum += degrees
	angleWorst = math.max(angleWorst, degrees)
end

--[[ One line, for a dev key or the console. ]]
function ShotDrift.report(): string
	if matched == 0 then
		return string.format("shot drift: %d predicted, none matched yet", shots)
	end
	return string.format(
		"shot drift over %d volleys: origin %.2f studs mean, %.2f worst; aim %.2f deg mean, %.2f worst; %d unmatched",
		matched,
		originSum / matched,
		originWorst,
		angleSum / matched,
		angleWorst,
		unmatched
	)
end

function ShotDrift.reset()
	table.clear(pending)
	shots, matched, unmatched = 0, 0, 0
	originSum, originWorst = 0, 0
	angleSum, angleWorst = 0, 0
end

--[[ For `tests/ShotDrift.spec`. ]]
function ShotDrift.stats(): {
	shots: number,
	matched: number,
	unmatched: number,
	origin: number,
	angle: number,
}
	return {
		shots = shots,
		matched = matched,
		unmatched = unmatched,
		origin = if matched > 0 then originSum / matched else 0,
		angle = if matched > 0 then angleSum / matched else 0,
	}
end

return ShotDrift
