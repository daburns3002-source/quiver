--!strict
--[[
	Lobby parties (owner, 2026-11-19: "have there be a party system where you
	can invite someone in the server"; `docs/COOP.md`, "Parties"): the pure
	rules, over user ids, so they are testable without players. The server
	keeps the one `State` (`Run/Parties`) and the clients only ever see what
	it sets on their Player.

	- **An invite** goes from a player not in a party, or from a party's
	  leader with room, to a player in no party. Each player has at most one
	  invite out and one in at a time, an unanswered one lapses after
	  `inviteSeconds`, and after a NO (or a lapse) the same pair waits
	  `againSeconds` before it can be asked again: no invite spam.
	- **ACCEPT** makes the sender the leader (or adds to the leader's
	  party), up to `Coop.maxParty`. Every open invite the change leaves
	  impossible is taken away by `tidy`.
	- **LEAVE**, or leaving the server, takes a player out; a party left with
	  one player is over, and if the leader went, the next member leads.
	- **A run's start** (`plan`): the leader's start takes every member who
	  can come (`why` says why one cannot), then whoever stands in the
	  portal's mouth and is in no other party, up to `maxParty`. A member who
	  starts a run that does not take the whole party **leaves the party**
	  (`quits`) rather than being refused. A party whose every member goes
	  travels with the run (`carry`).
	- **The round trip**: a travelling party is written into the teleport's
	  data (`claim` reads it back) and forms again where its members land,
	  only when every member is there and each one's data names the same
	  party (`regroup`). What a teleport carries passes through the client,
	  so one player's data alone can never put them in someone's party.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Coop = require(ReplicatedStorage.Shared.Util.Coop)

local PartyRules = {}

--[[ The most players in a party: co-op's. ]]
PartyRules.maxParty = Coop.maxParty
--[[ Seconds an invite stays open before it lapses. ]]
PartyRules.inviteSeconds = 30
--[[ Seconds after a NO, or a lapse, before the same player may ask the
     same player again. ]]
PartyRules.againSeconds = 20
--[[ Seconds a party travelling back from a run waits for all its members
     to land before it is given up. ]]
PartyRules.regroupSeconds = 60

export type Party = { leader: number, members: { number } }
export type Invite = { from: number, to: number, at: number }
export type State = {
	parties: { Party },
	--[[ Open invites, by who they are to. ]]
	invites: { [number]: Invite },
	--[[ "from:to" to the time the pair may be asked again. ]]
	waits: { [string]: number },
}
export type Plan = {
	--[[ Who goes on the run, the starter first. ]]
	going: { number },
	--[[ Members of the starter's party who stay, and why. ]]
	left: { { id: number, why: string } },
	--[[ The starter's party, when all of it goes. ]]
	carry: Party?,
	--[[ The starter is a member, not the leader, and goes without the
	     whole party: they leave it. ]]
	quits: boolean,
}
export type Gone = { invite: Invite, why: string }

function PartyRules.new(): State
	return { parties = {}, invites = {}, waits = {} }
end

function PartyRules.partyOf(state: State, id: number): Party?
	for _, party in state.parties do
		if table.find(party.members, id) then
			return party
		end
	end
	return nil
end

--[[ The open invite `from` has sent, if any. ]]
function PartyRules.outgoing(state: State, from: number): Invite?
	for _, invite in state.invites do
		if invite.from == from then
			return invite
		end
	end
	return nil
end

local function pair(from: number, to: number): string
	return `{from}:{to}`
end

--[[ Why `from` may not have an invite to `to` stand, ignoring the
     one-at-a-time and waiting rules: nil when it may. ]]
local function blocked(state: State, from: number, to: number): string?
	if from == to then
		return "SELF"
	end
	local mine = PartyRules.partyOf(state, from)
	if mine and mine.leader ~= from then
		return "NOT_LEADER"
	end
	if mine and #mine.members >= PartyRules.maxParty then
		return "FULL"
	end
	if PartyRules.partyOf(state, to) then
		return "IN_PARTY"
	end
	return nil
end

--[[ Why `from` may not invite `to` now, or nil when they may. ]]
function PartyRules.canInvite(state: State, from: number, to: number, now: number): string?
	local why = blocked(state, from, to)
	if why then
		return why
	end
	local theirs = state.invites[from]
	if theirs and theirs.from == to then
		return "ASKED_YOU"
	end
	if state.invites[to] then
		return "ASKED"
	end
	if PartyRules.outgoing(state, from) then
		return "SENDING"
	end
	local wait = state.waits[pair(from, to)]
	if wait and now < wait then
		return "WAIT"
	end
	return nil
end

--[[ `from` invites `to`: nil when it is sent, or why not. ]]
function PartyRules.invite(state: State, from: number, to: number, now: number): string?
	local why = PartyRules.canInvite(state, from, to, now)
	if why then
		return why
	end
	state.invites[to] = { from = from, to = to, at = now }
	return nil
end

--[[ `to` answers `from`'s invite. "JOINED" with the party, "DECLINED", or
     why the answer counts for nothing ("GONE": no such invite open;
     "EXPIRED"; or a reason it can no longer be met). ]]
function PartyRules.answer(
	state: State,
	to: number,
	from: number,
	accept: boolean,
	now: number
): (string, Party?)
	local invite = state.invites[to]
	if not invite or invite.from ~= from then
		return "GONE", nil
	end
	state.invites[to] = nil
	if now > invite.at + PartyRules.inviteSeconds then
		state.waits[pair(from, to)] = now + PartyRules.againSeconds
		return "EXPIRED", nil
	end
	if not accept then
		state.waits[pair(from, to)] = now + PartyRules.againSeconds
		return "DECLINED", nil
	end
	local why = blocked(state, from, to)
	if why then
		return why, nil
	end
	local party: Party = PartyRules.partyOf(state, from) or { leader = from, members = { from } }
	if not table.find(state.parties, party) then
		table.insert(state.parties, party)
	end
	table.insert(party.members, to)
	return "JOINED", party
end

--[[ Takes away every open invite that has lapsed or can no longer be met,
     and says which and why ("EXPIRED" or "CANCELLED"). ]]
function PartyRules.tidy(state: State, now: number): { Gone }
	local gone: { Gone } = {}
	for to, invite in state.invites do
		local why = if now > invite.at + PartyRules.inviteSeconds
			then "EXPIRED"
			elseif blocked(state, invite.from, to) then "CANCELLED"
			else nil
		if why then
			state.invites[to] = nil
			if why == "EXPIRED" then
				state.waits[pair(invite.from, to)] = now + PartyRules.againSeconds
			end
			table.insert(gone, { invite = invite, why = why })
		end
	end
	for key, at in state.waits do
		if now >= at then
			state.waits[key] = nil
		end
	end
	return gone
end

--[[ Takes `id` out of their party. Returns the party they were in (as it
     is now, without them) and whether it is over (one player left, who is
     out of it too). The next member leads if the leader left. ]]
function PartyRules.leave(state: State, id: number): (Party?, boolean)
	local party = PartyRules.partyOf(state, id)
	if not party then
		return nil, false
	end
	table.remove(party.members, table.find(party.members, id) :: number)
	if #party.members < 2 then
		table.remove(state.parties, table.find(state.parties, party) :: number)
		return party, true
	end
	if party.leader == id then
		party.leader = party.members[1]
	end
	return party, false
end

--[[ `id` left the server: out of their party, and every invite to or from
     them taken away (returned, so both sides can be told). ]]
function PartyRules.drop(state: State, id: number): (Party?, boolean, { Invite })
	local party, over = PartyRules.leave(state, id)
	local taken: { Invite } = {}
	for to, invite in state.invites do
		if to == id or invite.from == id then
			state.invites[to] = nil
			table.insert(taken, invite)
		end
	end
	return party, over, taken
end

--[[
	Who goes when `starter` starts a run. `standing` is who else stands in
	the portal's mouth and may come (already checked: the level open to
	them, free in the lobby), in join order; it is empty for a start from
	PLAY's screen. `why(id)` is why a member of the starter's party cannot
	come, or nil when they can. A player in another party never goes.
]]
function PartyRules.plan(
	state: State,
	starter: number,
	standing: { number },
	why: (number) -> string?
): Plan
	local party = PartyRules.partyOf(state, starter)
	local going = { starter }
	local left = {}
	local function add(id: number): boolean
		if table.find(going, id) then
			return true
		end
		if #going >= PartyRules.maxParty then
			return false
		end
		table.insert(going, id)
		return true
	end
	if party and party.leader == starter then
		for _, id in party.members do
			if id ~= starter then
				local reason = why(id)
				if reason then
					table.insert(left, { id = id, why = reason })
				elseif not add(id) then
					table.insert(left, { id = id, why = "RUN_FULL" })
				end
			end
		end
	end
	for _, id in standing do
		local theirs = PartyRules.partyOf(state, id)
		if theirs == nil or theirs == party then
			add(id)
		end
	end
	local carry: Party? = nil
	local quits = false
	if party then
		local all = true
		for _, id in party.members do
			if not table.find(going, id) then
				all = false
			end
		end
		if all then
			carry = { leader = party.leader, members = table.clone(party.members) }
		elseif party.leader ~= starter then
			quits = true
		end
	end
	return { going = going, left = left, carry = carry, quits = quits }
end

--[[ The party as a teleport carries it. ]]
function PartyRules.carry(party: Party): Party
	return { leader = party.leader, members = table.clone(party.members) }
end

--[[ Reads one party out of a teleport's data (`groups`, a list) for player
     `id`: the one that names them, if it is a well-formed party (whole
     numbers, no repeats, two to `maxParty` of them, the leader among
     them). Anything else is nil. ]]
function PartyRules.claim(data: unknown, id: number): Party?
	if type(data) ~= "table" then
		return nil
	end
	local groups = (data :: any).groups
	if type(groups) ~= "table" then
		return nil
	end
	for _, group in groups :: { any } do
		if type(group) ~= "table" or type(group.members) ~= "table" then
			continue
		end
		local members: { number } = {}
		local fine = type(group.leader) == "number"
		for _, member in group.members :: { any } do
			if
				type(member) ~= "number"
				or member ~= math.floor(member)
				or table.find(members, member)
			then
				fine = false
				break
			end
			table.insert(members, member)
		end
		if
			fine
			and #members >= 2
			and #members <= PartyRules.maxParty
			and table.find(members, group.leader)
			and table.find(members, id)
		then
			return { leader = group.leader, members = members }
		end
	end
	return nil
end

local function same(a: Party, b: Party): boolean
	if a.leader ~= b.leader or #a.members ~= #b.members then
		return false
	end
	for i, id in a.members do
		if b.members[i] ~= id then
			return false
		end
	end
	return true
end

--[[ Forms again every party all of whose members are `here` with a claim
     naming that same party, none of them in a party already. Their claims
     are used up; the parties formed are returned. ]]
function PartyRules.regroup(
	state: State,
	claims: { [number]: Party },
	here: (number) -> boolean
): { Party }
	local formed: { Party } = {}
	for id, claim in claims do
		if claims[id] ~= claim then
			continue
		end
		local whole = true
		for _, member in claim.members do
			local theirs = claims[member]
			if
				not here(member)
				or not theirs
				or not same(theirs, claim)
				or PartyRules.partyOf(state, member)
			then
				whole = false
				break
			end
		end
		if whole then
			for _, member in claim.members do
				claims[member] = nil
			end
			local party = { leader = claim.leader, members = table.clone(claim.members) }
			table.insert(state.parties, party)
			table.insert(formed, party)
		end
	end
	return formed
end

--[[ The words a player is shown, by what happened and with whose name
     (in capitals). ]]
local WORDS: { [string]: string } = {
	-- to whoever tried to invite
	NOT_LEADER = "ONLY YOUR PARTY LEADER CAN INVITE",
	FULL = "YOUR PARTY IS FULL",
	IN_PARTY = "%s IS ALREADY IN A PARTY",
	ASKED = "%s ALREADY HAS AN INVITE",
	ASKED_YOU = "%s ALREADY INVITED YOU",
	SENDING = "WAIT FOR YOUR LAST INVITE",
	WAIT = "WAIT A LITTLE BEFORE ASKING %s AGAIN",
	AWAY = "%s IS NOT FREE IN THE LOBBY",
	SENT = "INVITE SENT TO %s",
	-- to the sender, after
	DECLINED = "%s SAID NO THANKS",
	EXPIRED = "%s DID NOT ANSWER",
	-- to whoever said yes to a party that can no longer take them
	CANT_JOIN = "%s'S PARTY CANNOT TAKE YOU NOW",
	-- joining and leaving
	JOINED_YOU = "%s JOINED YOUR PARTY!",
	YOU_JOINED = "YOU JOINED %s'S PARTY!",
	LEFT = "%s LEFT THE PARTY",
	OVER = "%s LEFT. THE PARTY IS OVER",
	YOU_LEFT = "YOU LEFT THE PARTY",
	LEADS = "%s LEADS THE PARTY NOW",
	QUIT = "%s WENT TO PLAY ALONE",
	BACK = "YOUR PARTY IS BACK TOGETHER",
	-- to a member the leader's run left behind
	LOCKED = "%s STARTED A LEVEL YOU HAVE NOT OPENED YET",
	LOCKED_HARD = "%s STARTED A LEVEL YOU HAVE NOT OPENED ON HARD",
	TITLE = "%s STARTED A RUN WHILE YOU WERE ON THE TITLE",
	BUSY = "%s STARTED A RUN WHILE YOU WERE BUSY",
	RUN_FULL = "%s'S RUN WAS FULL",
}
PartyRules.WORDS = table.freeze(WORDS)

--[[ What player sees for `what` (a key of `WORDS`), with `name`. ]]
function PartyRules.say(what: string, name: string?): string?
	local words = WORDS[what]
	if not words then
		return nil
	end
	return (string.gsub(words, "%%s", (string.gsub((name or ""):upper(), "%%", "%%%%"))))
end

return table.freeze(PartyRules)
