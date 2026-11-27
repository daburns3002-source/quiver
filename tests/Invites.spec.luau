--!strict
--[[
	Invite rewards (`Util/InviteRules`, `Config/Rewards.invite`; owner,
	2026-11-18): who invited a new player is read from what Roblox gives the
	join, the welcome is settled once, the inviter is paid once a friend and
	at most a few friends a day, and nobody can farm it by rejoining.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InviteRules = require(ReplicatedStorage.Shared.Util.InviteRules)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local TestRunner = require(script.Parent.TestRunner)

local ME = 1001
local FRIEND = 2002
local DAY = 20400

return function(t: TestRunner.Helper)
	t.test("the inviter is Roblox's referral first, else the invite's launch data", function()
		local data = InviteRules.launchData(FRIEND)
		t.equal(InviteRules.inviter(0, data, ME), FRIEND)
		t.equal(InviteRules.inviter(nil, data, ME), FRIEND)
		t.equal(InviteRules.inviter(3003, data, ME), 3003, "Roblox's own word wins")
		t.isNil(InviteRules.inviter(nil, nil, ME), "nobody")
		t.isNil(InviteRules.inviter(ME, InviteRules.launchData(ME), ME), "not oneself")
		t.isNil(InviteRules.inviter(-5, "invite:-5", ME))
		t.isNil(InviteRules.inviter(nil, "invite:12abc", ME))
		t.isNil(InviteRules.inviter(nil, { inviter = FRIEND }, ME))
		t.isNil(
			InviteRules.inviter(nil, "invite:" .. string.rep("9", 80), ME),
			"a long string is refused"
		)
		t.isNil(InviteRules.inviter(0 / 0, "", ME))
	end)

	t.test("the welcome is settled once, and only for a player who was invited", function()
		local state = SaveSchema.default().invites
		t.isFalse(InviteRules.welcome(state), "nobody invited them")
		t.isTrue(InviteRules.invited(state, FRIEND))
		t.isFalse(InviteRules.invited(state, 3003), "never written over")
		t.equal(state.by, FRIEND)
		t.isTrue(InviteRules.welcome(state))
		t.isFalse(InviteRules.welcome(state), "rejoining pays nothing again")
		-- and the save keeps it so
		local again = SaveSchema.migrate(SaveSchema.migrate({ version = 27, invites = state }))
		t.isFalse(InviteRules.welcome(again.invites))
		t.equal(again.invites.by, FRIEND)
	end)

	t.test(
		"the inviter is paid once a friend, at most the cap a day, the rest the next day",
		function()
			local cap = Rewards.invite.cap
			t.isTrue(cap >= 1)
			local state = SaveSchema.default().invites
			local friends = {}
			for i = 1, cap + 2 do
				table.insert(friends, 5000 + i)
			end
			t.equal(InviteRules.left(state, DAY), cap)
			local paid = InviteRules.settle(state, friends, DAY)
			t.equal(#paid, cap)
			t.equal(InviteRules.left(state, DAY), 0)
			t.equal(#InviteRules.settle(state, friends, DAY), 0, "the cap holds all day")
			-- read again later the same day, nobody is paid twice
			t.equal(#InviteRules.settle(state, friends, DAY), 0)
			local tomorrow = InviteRules.settle(state, friends, DAY + 1)
			t.equal(#tomorrow, 2, "the two who waited are paid the next day")
			t.equal(tomorrow[1], 5000 + cap + 1)
			t.equal(#InviteRules.settle(state, friends, DAY + 2), 0, "and never again")
			t.isTrue(Rewards.invite.inviter.eggs ~= nil or Rewards.invite.inviter.coins ~= nil)
		end
	)

	t.test("the waiting list holds each friend once, the newest kept", function()
		local list = InviteRules.add(nil, FRIEND)
		t.equal(#list, 1)
		list = InviteRules.add(list, FRIEND)
		t.equal(#list, 1, "a friend is listed once")
		local mixed: any = { 3003, "junk" :: any, -1, 3003 }
		list = InviteRules.add(mixed, FRIEND)
		t.equal(#list, 2)
		t.equal(list[2], FRIEND)
		local long = nil :: any
		for i = 1, Rewards.invite.keep + 5 do
			long = InviteRules.add(long, i)
		end
		t.equal(#long, Rewards.invite.keep)
		t.equal(long[#long], Rewards.invite.keep + 5, "the newest is kept")
		t.equal(#InviteRules.list("broken"), 0)
	end)

	t.test("friends gone from the list are forgotten from what was counted", function()
		local state = SaveSchema.default().invites
		InviteRules.settle(state, { 1, 2 }, DAY)
		t.isTrue(state.counted["1"] and state.counted["2"])
		InviteRules.settle(state, { 2 }, DAY + 1)
		t.isNil(state.counted["1"])
		t.isTrue(state.counted["2"], "one still listed stays counted")
		-- a stored copy that claims more paid than a day allows is held to it
		local read = InviteRules.read({
			by = 3,
			owed = true,
			day = DAY,
			paid = 99,
			counted = { ["2"] = true },
		})
		t.equal(InviteRules.left(read, DAY), 0)
		t.isTrue(read.owed)
		t.isFalse(InviteRules.read({ by = 0, owed = true }).owed, "owed to nobody is not owed")
	end)
end
