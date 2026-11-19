--!strict
--[[
	Invite rewards (`Config/Rewards.invite`; owner, 2026-11-18). A friend
	who joins by an invite for the first time ever is welcomed with a
	reward once they reach the lobby, and the one who invited them is paid
	too, at most `cap` friends a reward day. Pure: `Data/Invites` decides
	with it, `tests/Invites.spec` pins it.

	**Who invited.** Roblox's own word first: the join data's
	`ReferredByPlayerId`. Failing that, the invite's launch data, which the
	game writes as "invite:<user id>" (`UI/InvitePrompt`). Launch data can
	be typed into a link by anyone, and a referral can come from a shared
	link, so either way the two are paid only if Roblox says they are
	friends (`Data/Invites`).

	**Nobody is counted twice.** The invited friend's own save remembers
	who invited them and whether that is settled (`owed`), so rejoining
	pays nothing again; the inviter's save keeps the friends already paid
	for (`counted`) and how many were paid today (`paid` on `day`).
	An inviter who is not on the friend's server hears of them through a
	waiting list kept apart from the save (`Data/Invites`' store), which
	this module only shapes (`add`).
]]

local Rewards = require(script.Parent.Parent.Config.Rewards)

local InviteRules = {}

export type Invites = {
	--[[ Who invited this player, by user id; 0 for nobody. ]]
	by: number,
	--[[ This player's welcome, and their inviter's reward, are still to
	     be settled. Set once, on the very first join. ]]
	owed: boolean,
	--[[ Friends this player has been paid for, by user id as a string. ]]
	counted: { [string]: boolean },
	--[[ The reward day `paid` belongs to, and how many friends were paid
	     for on it. ]]
	day: number,
	paid: number,
}

local PREFIX = "invite:"
--[[ The largest user id read (Roblox's are well under it). ]]
local LARGEST = 2 ^ 53

local function whole(value: unknown): number
	if type(value) ~= "number" or value ~= value or value >= LARGEST then
		return 0
	end
	return math.max(0, math.floor(value))
end

function InviteRules.empty(): Invites
	return { by = 0, owed = false, counted = {}, day = 0, paid = 0 }
end

--[[ A stored copy read back, whatever was stored. ]]
function InviteRules.read(value: unknown): Invites
	local out = InviteRules.empty()
	if type(value) ~= "table" then
		return out
	end
	local stored = value :: any
	out.by = whole(stored.by)
	out.owed = stored.owed == true and out.by > 0
	if type(stored.counted) == "table" then
		for key, yes in stored.counted do
			if type(key) == "string" and yes == true and whole(tonumber(key)) > 0 then
				out.counted[key] = true
			end
		end
	end
	out.day = whole(stored.day)
	out.paid = math.min(whole(stored.paid), Rewards.invite.cap)
	return out
end

--[[ The launch data an invite carries: who sent it. ]]
function InviteRules.launchData(userId: number): string
	return PREFIX .. string.format("%d", userId)
end

--[[ Who invited a joining player `self`, from the join data's
     `ReferredByPlayerId` and `LaunchData` as Roblox gave them (anything at
     all): the user id, nil for nobody. ]]
function InviteRules.inviter(referredBy: unknown, launchData: unknown, self: number): number?
	local referred = whole(referredBy)
	if referred > 0 and referred ~= self then
		return referred
	end
	if type(launchData) == "string" and #launchData <= 64 then
		local digits = string.match(launchData, "^" .. PREFIX .. "(%d+)$")
		local id = whole(tonumber(digits or ""))
		if id > 0 and id ~= self then
			return id
		end
	end
	return nil
end

--[[ A brand new player was invited by `by`: written down, owed. Only ever
     on the first join (the caller checks the save is new), and never over
     an inviter already written. ]]
function InviteRules.invited(state: Invites, by: number): boolean
	if state.by > 0 or by <= 0 then
		return false
	end
	state.by = by
	state.owed = true
	return true
end

--[[ Settles the welcome: marked, and true if it was owed (pay it then,
     and tell the inviter). ]]
function InviteRules.welcome(state: Invites): boolean
	if not state.owed or state.by <= 0 then
		return false
	end
	state.owed = false
	return true
end

--[[ How many more friends can be paid for on `today`. ]]
function InviteRules.left(state: Invites, today: number): number
	if state.day ~= today then
		return Rewards.invite.cap
	end
	return math.max(0, Rewards.invite.cap - state.paid)
end

--[[ The inviter's side: `friends` are the user ids on their waiting list.
     Each not paid for yet is paid now while the day's cap allows; the rest
     wait for a later day. Returns the friends to pay for, marked. Friends
     no longer on the list are forgotten from `counted`: the list only ever
     loses its oldest, which never come back. ]]
function InviteRules.settle(state: Invites, friends: { number }, today: number): { number }
	if state.day ~= today then
		state.day = today
		state.paid = 0
	end
	local out = {}
	local listed: { [string]: boolean } = {}
	for _, friend in friends do
		local id = whole(friend)
		if id <= 0 then
			continue
		end
		local key = string.format("%d", id)
		listed[key] = true
		if not state.counted[key] and state.paid < Rewards.invite.cap then
			state.counted[key] = true
			state.paid += 1
			table.insert(out, id)
		end
	end
	for key in state.counted do
		if not listed[key] then
			state.counted[key] = nil
		end
	end
	return out
end

--[[ A stored waiting list read back (anything stored): user ids, each
     once, oldest first. ]]
function InviteRules.list(stored: unknown): { number }
	local out: { number } = {}
	if type(stored) == "table" then
		for _, value in stored :: { any } do
			local id = whole(value)
			if id > 0 and not table.find(out, id) then
				table.insert(out, id)
			end
		end
	end
	return out
end

--[[ The waiting list kept for an inviter (anything stored), with `friend`
     on it once, at the end, and the newest `keep` kept. ]]
function InviteRules.add(stored: unknown, friend: number): { number }
	local out = InviteRules.list(stored)
	local at = table.find(out, friend)
	if at then
		table.remove(out, at)
	end
	table.insert(out, friend)
	while #out > Rewards.invite.keep do
		table.remove(out, 1)
	end
	return out
end

return InviteRules
