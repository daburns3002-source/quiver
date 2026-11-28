--!strict
--[[
	Co-op's idle clock (`Util/IdlePick`, `docs/COOP.md`): what the server
	picks for a player who left a card screen or an Endless checkpoint open,
	and what the clock's line says. Held here: nothing is timed for a player
	alone, the pick is never one that ends the run or pays for being away,
	and every hand the game can deal has a card to take.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Coop = require(ReplicatedStorage.Shared.Util.Coop)
local IdlePick = require(ReplicatedStorage.Shared.Util.IdlePick)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local TestRunner = require(script.Parent.TestRunner)

local function tierOf(id: string): number
	local ability = Abilities.byId[id]
	local rarity = ability and Rarities.byName[ability.rarity]
	return if rarity then rarity.tier else 0
end

return function(t: TestRunner.Helper)
	t.test("nothing is timed for a player alone", function()
		t.isFalse(IdlePick.applies(0), "nobody")
		t.isFalse(IdlePick.applies(1), "a solo run, or a teammate who left")
		t.isTrue(IdlePick.applies(2), "a party of two")
		t.isTrue(IdlePick.applies(3), "and of three")
	end)

	t.test("the clock leaves time to read, and warns before it picks", function()
		t.isTrue(Coop.idle.draft >= 20, "a hand can be read twice")
		t.isTrue(Coop.idle.checkpoint >= 20, "and a checkpoint")
		t.isTrue(Coop.idle.warn >= 5, "the countdown is long enough to act on")
		t.isTrue(Coop.idle.warn < Coop.idle.draft, "and is not the whole wait")
		t.isTrue(Coop.idle.warn < Coop.idle.checkpoint, "on either screen")
	end)

	t.test("the card picked is the rarest, the leftmost of equals", function()
		local tiers = { a = 1, b = 3, c = 3, d = 2 }
		local function tier(id: string): number
			return tiers[id] or 0
		end
		t.equal(IdlePick.card({ "a", "b", "c" }, tier), 2, "the first of two Rares")
		t.equal(IdlePick.card({ "c", "b", "a" }, tier), 1, "wherever it is dealt")
		t.equal(IdlePick.card({ "a", "d", "a" }, tier), 2, "the one better card")
		t.equal(IdlePick.card({ "a" }, tier), 1, "a hand of one")
		t.equal(IdlePick.card({ "x", "y" }, tier), 1, "cards it does not know are still cards")
		t.equal(IdlePick.card({}, tier), 0, "an empty hand has nothing to take")
	end)

	t.test("every card the game holds has a tier, so every hand has a pick", function()
		for id, ability in Abilities.byId do
			t.isTrue(tierOf(id) >= 1, `{id} ({ability.rarity}) has a tier`)
		end
		local hand: { string } = {}
		for id in Abilities.byId do
			table.insert(hand, id)
			if #hand == 3 then
				break
			end
		end
		local index = IdlePick.card(hand, tierOf)
		t.isTrue(index >= 1 and index <= #hand, "a real hand's pick is one of its cards")
	end)

	t.test("the checkpoint's pick is the heal: never the bank, never the cache", function()
		local picks = Balance.Endless.checkpoint.picks
		local gift = IdlePick.gift(picks)
		t.isTrue(gift >= 1 and gift <= #picks, "one of the gifts, so never 0 (BANK & LEAVE)")
		t.equal(picks[gift].key, "Heal", "the heal")
		t.equal(
			IdlePick.gift({ { key = "Card" }, { key = "Shop" }, { key = "Heal" } }),
			3,
			"wherever it is listed"
		)
		t.equal(IdlePick.gift({ { key = "Card" } }), 1, "the first if there is no heal")
	end)

	t.test("seconds left are whole, counted down and never negative", function()
		t.isNil(IdlePick.left(nil, 100), "no clock")
		t.isNil(IdlePick.left("soon", 100), "nor a clock that is not a time")
		t.equal(IdlePick.left(130, 100), 30, "the whole wait")
		t.equal(IdlePick.left(109.2, 100), 10, "a part second still shows its second")
		t.equal(IdlePick.left(100, 100), 0, "due")
		t.equal(IdlePick.left(90, 100), 0, "overdue is not negative")
	end)

	t.test("the line: your own last seconds, or who the run waits for", function()
		local warn = Coop.idle.warn
		t.isNil(IdlePick.line(nil, warn, nil, nil), "nothing timed, nothing said")
		t.isNil(IdlePick.line(warn + 1, warn, nil, nil), "a hand being read is left alone")
		t.equal(IdlePick.line(warn, warn, nil, nil), `PICKING FOR YOU IN {warn}`, "the countdown")
		t.equal(IdlePick.line(0, warn, nil, nil), "PICKING FOR YOU IN 0", "to nought")
		t.equal(
			IdlePick.line(nil, warn, "Alex", 23),
			"WAITING FOR ALEX: 23",
			"a teammate reads who it is"
		)
		t.isNil(
			IdlePick.line(warn + 5, warn, "Alex", 3),
			"a player still reading is not told about the other"
		)
		t.equal(
			IdlePick.line(4, warn, "Alex", 3),
			"PICKING FOR YOU IN 4",
			"their own clock comes first"
		)
		t.isNil(IdlePick.line(nil, warn, "Alex", nil), "a name with no clock says nothing")
	end)

	t.test("what was picked is said in capitals", function()
		t.equal(IdlePick.picked("Multishot"), "PICKED FOR YOU: MULTISHOT")
		t.equal(IdlePick.picked("FULL HEAL"), "PICKED FOR YOU: FULL HEAL")
		t.equal(IdlePick.picked(""), "PICKED FOR YOU", "nothing to name")
	end)
end
