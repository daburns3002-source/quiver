--!strict
--[[
	Lobby parties (`Shared/Util/PartyRules`, `Run/Parties`): who may invite
	whom, that invites lapse and cannot be spammed, joining and leaving, who
	a run's start takes along, and that a party travelling to a run and back
	forms again only from every member's own word.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyRules = require(ReplicatedStorage.Shared.Util.PartyRules)
local TestRunner = require(script.Parent.TestRunner)

local A, B, C, D = 101, 202, 303, 404

local function none(_: number): string?
	return nil
end

local function joined(state: PartyRules.State, from: number, to: number, now: number)
	assert(PartyRules.invite(state, from, to, now) == nil, "invite refused")
	local outcome = PartyRules.answer(state, to, from, true, now + 1)
	assert(outcome == "JOINED", `not joined: {outcome}`)
end

return function(t: TestRunner.Helper)
	t.test("a party holds co-op's most and no more", function()
		t.isTrue(PartyRules.maxParty >= 2)
		t.isTrue(PartyRules.inviteSeconds > 0 and PartyRules.againSeconds > 0)
	end)

	t.test("ACCEPT makes the sender the leader", function()
		local s = PartyRules.new()
		t.isNil(PartyRules.invite(s, A, B, 0))
		local outcome, party = PartyRules.answer(s, B, A, true, 5)
		t.equal(outcome, "JOINED")
		t.notNil(party)
		t.equal((party :: PartyRules.Party).leader, A)
		t.equal(PartyRules.partyOf(s, B), party)
		t.equal(PartyRules.partyOf(s, A), party)
		t.isNil(s.invites[B])
	end)

	t.test("nobody invites themselves, a member never invites, a full party never does", function()
		local s = PartyRules.new()
		t.equal(PartyRules.canInvite(s, A, A, 0), "SELF")
		joined(s, A, B, 0)
		t.equal(PartyRules.canInvite(s, B, C, 10), "NOT_LEADER")
		if PartyRules.maxParty == 2 then
			t.equal(PartyRules.canInvite(s, A, C, 10), "FULL")
		end
		t.equal(PartyRules.canInvite(s, C, B, 10), "IN_PARTY")
	end)

	t.test("one invite out and one in at a time", function()
		local s = PartyRules.new()
		t.isNil(PartyRules.invite(s, A, B, 0))
		t.equal(PartyRules.invite(s, A, C, 1), "SENDING")
		t.equal(PartyRules.invite(s, C, B, 1), "ASKED")
		t.equal(PartyRules.invite(s, B, A, 1), "ASKED_YOU")
	end)

	t.test("a NO makes the same pair wait, others may still ask", function()
		local s = PartyRules.new()
		PartyRules.invite(s, A, B, 0)
		t.equal((PartyRules.answer(s, B, A, false, 2)), "DECLINED")
		t.isNil(PartyRules.partyOf(s, B))
		t.equal(PartyRules.canInvite(s, A, B, 3), "WAIT")
		t.isNil(PartyRules.canInvite(s, C, B, 3))
		t.isNil(PartyRules.canInvite(s, A, C, 3))
		t.isNil(PartyRules.canInvite(s, A, B, 2 + PartyRules.againSeconds))
	end)

	t.test("an unanswered invite lapses, and a late ACCEPT joins nothing", function()
		local s = PartyRules.new()
		PartyRules.invite(s, A, B, 0)
		local late = PartyRules.inviteSeconds + 1
		t.equal(#PartyRules.tidy(s, PartyRules.inviteSeconds - 1), 0)
		local gone = PartyRules.tidy(s, late)
		t.equal(#gone, 1)
		t.equal(gone[1].why, "EXPIRED")
		t.equal((PartyRules.answer(s, B, A, true, late)), "GONE")
		t.isNil(PartyRules.partyOf(s, B))
		t.equal(PartyRules.canInvite(s, A, B, late), "WAIT")
		-- answered after the time but before a tidy: still nothing
		local s2 = PartyRules.new()
		PartyRules.invite(s2, A, B, 0)
		t.equal((PartyRules.answer(s2, B, A, true, late)), "EXPIRED")
		t.isNil(PartyRules.partyOf(s2, B))
	end)

	t.test("an answer counts only for the invite that is open", function()
		local s = PartyRules.new()
		PartyRules.invite(s, A, B, 0)
		t.equal((PartyRules.answer(s, B, C, true, 1)), "GONE")
		t.equal((PartyRules.answer(s, C, A, true, 1)), "GONE")
		t.notNil(s.invites[B])
	end)

	t.test("joining a party takes away invites it made impossible", function()
		local s = PartyRules.new()
		PartyRules.invite(s, A, B, 0)
		PartyRules.invite(s, C, D, 0)
		-- D joins B's party: B now leads, D is in a party
		PartyRules.answer(s, D, C, false, 1)
		PartyRules.invite(s, B, D, 1)
		PartyRules.answer(s, D, B, true, 2)
		local gone = PartyRules.tidy(s, 3)
		t.equal(#gone, 1)
		t.equal(gone[1].invite.to, B)
		t.equal(gone[1].why, "CANCELLED")
		t.equal((PartyRules.answer(s, B, A, true, 3)), "GONE")
	end)

	t.test("an ACCEPT after the party filled joins nothing", function()
		if PartyRules.maxParty ~= 2 then
			return
		end
		local s = PartyRules.new()
		PartyRules.invite(s, A, B, 0)
		-- B is in C's party before answering A
		s.parties = { { leader = C, members = { C, B } } }
		t.equal((PartyRules.answer(s, B, A, true, 1)), "IN_PARTY")
	end)

	t.test("LEAVE ends a party of two; the next member leads a bigger one", function()
		local s = PartyRules.new()
		joined(s, A, B, 0)
		local party, over = PartyRules.leave(s, B)
		t.notNil(party)
		t.isTrue(over)
		t.isNil(PartyRules.partyOf(s, A))
		local big = PartyRules.new()
		big.parties = { { leader = A, members = { A, B, C } } }
		local after, ended = PartyRules.leave(big, A)
		t.isFalse(ended)
		t.equal((after :: PartyRules.Party).leader, B)
		t.equal(#(after :: PartyRules.Party).members, 2)
		t.isNil((PartyRules.leave(PartyRules.new(), A)))
	end)

	t.test("leaving the server takes every invite to and from them", function()
		local s = PartyRules.new()
		PartyRules.invite(s, A, B, 0)
		PartyRules.invite(s, C, A, 0)
		local _, _, taken = PartyRules.drop(s, A)
		t.equal(#taken, 2)
		t.isNil((next(s.invites)))
	end)

	t.test("the leader's start takes the party, then the portal, up to the most", function()
		local s = PartyRules.new()
		joined(s, A, B, 0)
		local plan = PartyRules.plan(s, A, {}, none)
		t.equal(plan.going[1], A)
		t.notNil(table.find(plan.going, B))
		t.equal(#plan.left, 0)
		t.notNil(plan.carry)
		t.equal((plan.carry :: PartyRules.Party).leader, A)
		t.isFalse(plan.quits)
		-- a stranger in the portal comes only if there is room
		local crowded = PartyRules.plan(s, A, { C }, none)
		t.isTrue(#crowded.going <= PartyRules.maxParty)
		t.notNil(table.find(crowded.going, B))
	end)

	t.test("a member who cannot come stays behind, told why, and nothing travels", function()
		local s = PartyRules.new()
		joined(s, A, B, 0)
		local plan = PartyRules.plan(s, A, {}, function(id)
			return if id == B then "LOCKED" else nil
		end)
		t.equal(#plan.going, 1)
		t.equal(#plan.left, 1)
		t.equal(plan.left[1].id, B)
		t.equal(plan.left[1].why, "LOCKED")
		t.isNil(plan.carry)
		t.isFalse(plan.quits)
	end)

	t.test("a member who starts alone leaves the party", function()
		local s = PartyRules.new()
		joined(s, A, B, 0)
		local plan = PartyRules.plan(s, B, {}, none)
		t.equal(#plan.going, 1)
		t.isTrue(plan.quits)
		t.isNil(plan.carry)
		-- with the leader in the same portal mouth, the party goes together
		local together = PartyRules.plan(s, B, { A }, none)
		t.notNil(table.find(together.going, A))
		t.isFalse(together.quits)
		t.equal((together.carry :: PartyRules.Party).leader, A)
	end)

	t.test(
		"a start with no party is the portal's rule, and never takes another party's player",
		function()
			local s = PartyRules.new()
			joined(s, A, B, 0)
			local plan = PartyRules.plan(s, C, { B, D }, none)
			t.equal(plan.going[1], C)
			t.isNil(table.find(plan.going, B))
			t.isNil(plan.carry)
			t.isFalse(plan.quits)
			if PartyRules.maxParty == 2 then
				t.equal(plan.going[2], D)
			end
		end
	)

	t.test("a teleport's party is read back only when well formed and naming the player", function()
		local data = { groups = { { leader = A, members = { A, B } } } }
		t.notNil(PartyRules.claim(data, A))
		t.notNil(PartyRules.claim(data, B))
		t.isNil(PartyRules.claim(data, C))
		t.isNil(PartyRules.claim(nil, A))
		t.isNil(PartyRules.claim({ groups = "x" }, A))
		t.isNil(PartyRules.claim({ groups = { { leader = C, members = { A, B } } } }, A))
		t.isNil(PartyRules.claim({ groups = { { leader = A, members = { A, A } } } }, A))
		t.isNil(PartyRules.claim({ groups = { { leader = A, members = { A } } } }, A))
		t.isNil(PartyRules.claim({ groups = { { leader = A, members = { A, 1.5 } } } }, A))
		local many = { A }
		for i = 1, PartyRules.maxParty do
			table.insert(many, 1000 + i)
		end
		t.isNil(PartyRules.claim({ groups = { { leader = A, members = many } } }, A))
	end)

	t.test("a party forms again only when every member is here and says the same", function()
		local everyone = function(_: number): boolean
			return true
		end
		local party = { leader = A, members = { A, B } }
		local s = PartyRules.new()
		-- only one of them here yet
		local claims: { [number]: PartyRules.Party } = { [A] = PartyRules.carry(party) }
		t.equal(#PartyRules.regroup(s, claims, everyone), 0)
		claims[B] = PartyRules.carry(party)
		local formed = PartyRules.regroup(s, claims, everyone)
		t.equal(#formed, 1)
		t.equal(formed[1].leader, A)
		t.equal(PartyRules.partyOf(s, B), formed[1])
		t.isNil((next(claims)))
	end)

	t.test("one player's word alone never puts them in someone's party", function()
		local everyone = function(_: number): boolean
			return true
		end
		local s = PartyRules.new()
		-- C claims to be with A, but A's own data names B
		local claims: { [number]: PartyRules.Party } = {
			[A] = { leader = A, members = { A, B } },
			[C] = { leader = A, members = { A, C } },
		}
		t.equal(#PartyRules.regroup(s, claims, everyone), 0)
		t.isNil(PartyRules.partyOf(s, C))
		-- a claim on someone not in this server forms nothing
		local s2 = PartyRules.new()
		local claims2: { [number]: PartyRules.Party } = {
			[A] = { leader = A, members = { A, B } },
			[B] = { leader = A, members = { A, B } },
		}
		t.equal(#PartyRules.regroup(s2, claims2, function(id)
			return id ~= B
		end), 0)
	end)

	t.test("every reason a player can be given has words", function()
		for _, key in
			{
				"NOT_LEADER",
				"FULL",
				"IN_PARTY",
				"ASKED",
				"ASKED_YOU",
				"SENDING",
				"WAIT",
				"DECLINED",
				"EXPIRED",
				"CANT_JOIN",
				"AWAY",
				"SENT",
				"YOU_JOINED",
				"LEFT",
				"OVER",
				"LEADS",
				"QUIT",
				"LOCKED",
				"LOCKED_HARD",
				"TITLE",
				"BUSY",
				"RUN_FULL",
			}
		do
			t.notNil(PartyRules.say(key, "Pip"), key)
		end
		t.equal(PartyRules.say("JOINED_YOU", "Pip"), "PIP JOINED YOUR PARTY!")
		t.equal(PartyRules.say("IN_PARTY", "100%"), "100% IS ALREADY IN A PARTY")
		t.isNil(PartyRules.say("NOPE", "Pip"))
	end)
end
