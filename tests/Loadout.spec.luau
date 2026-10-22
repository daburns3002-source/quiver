--!strict
--[[
	The draft.

	Everything here is the kind of mistake that ruins a run quietly rather
	than loudly: a cap that is off by one, an offer that can repeat itself, a
	level that gets swallowed, an index the client can push past the end of
	the offer. None of it is visible to the type checker and none of it throws
	— it just hands out the wrong cards.

	`Loadout` takes a `Random` and knows nothing about sessions precisely so
	all of this can be driven by hand.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local Loadout = require(ServerScriptService.Server.Run.Loadout)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local TestRunner = require(script.Parent.TestRunner)

--[[ Fixed seed: a test that fails one run in twenty is a test nobody trusts. ]]
local function dice(): Random
	return Random.new(20261021)
end

--[[ Enough XP to be certain of a level without depending on the curve. ]]
local function levelUp(state: Loadout.State): number
	return Loadout.addXp(state, state.xpToNext)
end

return function(t: TestRunner.Helper)
	t.test("a fresh loadout holds nothing and owes nothing", function()
		local state = Loadout.new()

		t.equal(state.level, 1)
		t.equal(state.pendingLevels, 0)
		t.isNil(state.offer)
		t.isTrue(state.xpToNext > 0, "a new run needs no XP to level")
	end)

	t.test("exactly enough XP levels once", function()
		local state = Loadout.new()
		t.equal(levelUp(state), 1)
		t.equal(state.level, 2)
		t.equal(state.pendingLevels, 1)
	end)

	--[[ One kill in a late area can be worth more than a whole level, and
	     swallowing the remainder would silently cost the player a card. ]]
	t.test("a single huge award can grant several levels", function()
		local state = Loadout.new()
		local gained = Loadout.addXp(state, 100000)

		t.isTrue(gained > 1, `a huge award granted only {gained} level(s)`)
		t.equal(state.pendingLevels, gained)
		t.equal(state.level, 1 + gained)
	end)

	t.test("levelling stops at the ceiling", function()
		local state = Loadout.new()
		Loadout.addXp(state, 1e9)

		t.equal(state.level, Progression.maxLevel)
		t.equal(Loadout.addXp(state, 1e9), 0, "levelled past the ceiling")
	end)

	t.test("an offer holds the configured number of distinct cards", function()
		local state = Loadout.new()
		levelUp(state)

		local offer = Loadout.openOffer(state, false, dice())
		t.notNil(offer, "no offer after levelling")

		local cards = offer :: { string }
		t.equal(#cards, Progression.offerCount)

		--[[ `isNil`, not `isFalse`: the helper asserts a value *is* false, and
		     an id seen for the first time is absent rather than false. ]]
		local seen: { [string]: boolean } = {}
		for _, id in cards do
			t.isNil(seen[id], `{id} was offered twice in one draft`)
			seen[id] = true
		end
	end)

	t.test("nothing is offered until a level is owed", function()
		local state = Loadout.new()
		t.isNil(Loadout.openOffer(state, false, dice()), "offered a card at level one")
	end)

	t.test("a second offer cannot open over an open one", function()
		local state = Loadout.new()
		Loadout.addXp(state, 1e9)

		t.notNil(Loadout.openOffer(state, false, dice()), "no first offer")
		t.isNil(Loadout.openOffer(state, false, dice()), "two card screens opened at once")
	end)

	--[[ A card that does nothing is worse than a card that is merely bad: it
	     makes the draft look like it is not paying attention. ]]
	t.test("a pure heal is not offered at full health", function()
		local state = Loadout.new()
		Loadout.addXp(state, 1e9)

		for _ = 1, 40 do
			state.offer = nil
			state.pendingLevels = math.max(state.pendingLevels, 1)

			local offer = Loadout.openOffer(state, true, Random.new())
			if offer then
				for _, id in offer do
					local ability = Abilities.byId[id]
					t.isFalse(ability.instant == true, "a heal was offered at full health")
				end
			end
		end
	end)

	t.test("an ability at its cap stops being offered", function()
		local state = Loadout.new()
		local capped = Abilities.byId.RearArrow
		state.counts[capped.id] = #capped.levels

		t.equal(Loadout.remaining(state, capped), 0)

		Loadout.addXp(state, 1e9)

		for _ = 1, 40 do
			state.offer = nil
			state.pendingLevels = math.max(state.pendingLevels, 1)

			local offer = Loadout.openOffer(state, false, Random.new())
			if offer then
				t.isNil(table.find(offer, capped.id), "a capped ability was offered")
			end
		end
	end)

	--[[ The validation boundary. The client sends an index and nothing else,
	     and every one of these is something it might send instead. ]]
	t.test("only a real index into the open offer is accepted", function()
		local state = Loadout.new()
		levelUp(state)
		local offer = Loadout.openOffer(state, false, dice()) :: { string }

		t.isNil(Loadout.choose(state, 0), "index zero was accepted")
		t.isNil(Loadout.choose(state, #offer + 1), "an index past the end was accepted")
		t.isNil(Loadout.choose(state, -1), "a negative index was accepted")
		t.isNil(Loadout.choose(state, 1.5), "a fractional index was accepted")
		t.notNil(Loadout.choose(state, 1), "a valid index was refused")
	end)

	t.test("choosing with nothing on offer does nothing", function()
		local state = Loadout.new()
		t.isNil(Loadout.choose(state, 1), "granted an ability with no offer open")
	end)

	t.test("a choice consumes the offer and the level that owed it", function()
		local state = Loadout.new()
		levelUp(state)
		Loadout.openOffer(state, false, dice())

		local ability = Loadout.choose(state, 1)
		t.notNil(ability, "a valid choice was refused")
		t.isNil(state.offer, "the offer survived being taken")
		t.equal(state.pendingLevels, 0)
		t.equal(state.counts[(ability :: Abilities.Ability).id], 1)
	end)

	t.test("two levels owed produce two cards in sequence", function()
		local state = Loadout.new()
		Loadout.addXp(state, 1e9)
		local owed = state.pendingLevels

		for _ = 1, math.min(owed, 5) do
			t.notNil(Loadout.openOffer(state, false, dice()), "a owed level produced no card")
			t.notNil(Loadout.choose(state, 1), "a card could not be taken")
		end
	end)

	--[[ A heal you drank is not part of your build, and the run summary that
	     shows it would be lying about what the player assembled. ]]
	t.test("instant abilities are not held", function()
		local state = Loadout.new()
		state.counts.Heal = 2
		state.counts.Strength = 1

		local held = Loadout.held(state)
		t.isNil(held.Heal, "a consumed heal is being held")
		t.equal(held.Strength, 1)
	end)

	--[[ Relationships, not values. Retuning the curve must not fail a test;
	     tuning it into a shape that cannot work should. ]]
	t.test("levels get more expensive, never cheaper", function()
		local state = Loadout.new()
		local previous = state.xpToNext

		for _ = 1, 6 do
			Loadout.addXp(state, state.xpToNext)
			t.isTrue(state.xpToNext >= previous, "a later level cost less than an earlier one")
			previous = state.xpToNext
		end
	end)

	--[[ Exclusions are read both ways, so holding either side of a pair must
	     keep the other out of every offer — whichever ability the rule was
	     written on. Many seeded rolls, so a rule that only sometimes applied
	     would show. ]]
	t.test("an excluded ability is never offered, from either side", function()
		for _, pair in { { "TrackingEye", "BouncyWall" }, { "BouncyWall", "TrackingEye" } } do
			local held, barred = pair[1], pair[2]
			local state = Loadout.new()
			state.counts[held] = 1
			Loadout.addXp(state, 1e9)

			t.isTrue(
				Loadout.excluded(state, Abilities.byId[barred]),
				`{held} does not bar {barred}`
			)

			local random = dice()
			for _ = 1, 60 do
				state.offer = nil
				state.pendingLevels = math.max(state.pendingLevels, 1)

				local offer = Loadout.openOffer(state, false, random)
				if offer then
					t.isNil(table.find(offer, barred), `{barred} was offered while holding {held}`)
				end
			end
		end
	end)

	t.test("every exclusion names a real ability, and not itself", function()
		for _, ability in Abilities.all do
			local excludes = ability.excludes
			if not excludes then
				continue
			end

			for _, id in excludes do
				t.notNil(Abilities.byId[id], `{ability.id} excludes unknown ability {id}`)
				t.isTrue(
					id ~= ability.id,
					`{ability.id} excludes itself and could never be offered`
				)
			end
		end
	end)

	--[[ A Valkyrie or an Angel is a gift. Taking its card must not spend a
	     level the player is owed, or every encounter would quietly cost
	     them their next draft. ]]
	t.test("a Valkyrie's card is a gift, not a level", function()
		local state = Loadout.new()
		levelUp(state)
		local owed = state.pendingLevels

		local offer = Loadout.openValkyrie(state, false, dice(), 2)
		t.notNil(offer)
		t.equal(#(offer :: { string }), 2, "a Valkyrie should offer two cards")
		t.isTrue((offer :: { string })[1] ~= (offer :: { string })[2], "the two cards are the same")

		t.notNil(Loadout.choose(state, 1))
		t.equal(state.pendingLevels, owed, "the Valkyrie's card spent a level")
	end)

	t.test("an Angel offers a stat or a heal", function()
		local state = Loadout.new()
		local offer = Loadout.openAngel(state, dice())
		t.notNil(offer)

		local heal, stat = false, false
		for _, id in offer :: { string } do
			if id == "Heal" then
				heal = true
			elseif Abilities.byId[id] and Abilities.byId[id].category == "Stats" then
				stat = true
			end
		end
		t.isTrue(heal, "an Angel offered no heal")
		t.isTrue(stat, "an Angel offered no stat")
	end)

	t.test("an encounter cannot open over an open card screen", function()
		local state = Loadout.new()
		levelUp(state)
		t.notNil(Loadout.openOffer(state, false, dice()))
		t.isNil(Loadout.openValkyrie(state, false, dice(), 2))
		t.isNil(Loadout.openAngel(state, dice()))
	end)

	t.test("there are enough abilities to fill an offer", function()
		t.isTrue(
			#Abilities.all >= Progression.offerCount,
			"fewer abilities exist than a single draft offers"
		)
	end)
	--[[ Weighted by rarity: over many hands a Common turns up far more
	     often than a Mythic. Counted, not computed, so the test holds the
	     draw itself rather than restating its formula. ]]
	t.test("common cards are dealt more often than mythic ones", function()
		local seen: { [string]: number } = {}
		local random = Random.new(11)
		for _ = 1, 400 do
			for _, id in Loadout.rollOffer(Loadout.new(), true, random) do
				local rarity = Abilities.byId[id].rarity
				seen[rarity] = (seen[rarity] or 0) + 1
			end
		end

		t.isTrue(
			(seen.Common or 0) > (seen.Mythic or 0) * 3,
			"Mythic cards come up as often as Common"
		)
	end)

	t.test("a hand never holds the same card twice, nor a filler card", function()
		local random = Random.new(5)
		for _ = 1, 200 do
			local hand = Loadout.rollOffer(Loadout.new(), true, random)
			local seen: { [string]: boolean } = {}
			for _, id in hand do
				t.isNil(seen[id], `{id} was dealt twice in one hand`)
				t.isFalse(Abilities.byId[id].filler == true, `{id} is filler, dealt by rarity`)
				seen[id] = true
			end
		end
	end)

	t.test("a reroll redeals the hand and spends one reroll", function()
		local state = Loadout.new()
		levelUp(state)
		t.notNil(Loadout.openOffer(state, false, dice()))
		local before = state.rerolls

		t.notNil(Loadout.reroll(state, false, dice()))
		t.equal(state.rerolls, before - 1)
		t.equal(#(state.offer :: { string }), Progression.offerCount)
	end)

	t.test("no reroll without a hand, or with none left", function()
		local state = Loadout.new()
		t.isNil(Loadout.reroll(state, false, dice()), "rerolled with no hand open")

		levelUp(state)
		Loadout.openOffer(state, false, dice())
		state.rerolls = 0
		t.isNil(Loadout.reroll(state, false, dice()), "rerolled with none left")
	end)

	t.test("a short hand is topped up with a heal only when hurt", function()
		local state = Loadout.new()
		for _, ability in Abilities.all do
			if not ability.filler then
				state.counts[ability.id] = #ability.levels
			end
		end

		t.equal(#Loadout.rollOffer(state, true, dice()), 0, "a heal was dealt at full health")
		local hurt = Loadout.rollOffer(state, false, dice())
		t.equal(#hurt, 1)
		t.equal(hurt[1], "Heal")
	end)
	--[[ The Studio-only "show me a Mythic" request: the next hand has one,
	     the one after is dealt normally again. ]]
	t.test("a forced rarity lands in the next hand once", function()
		local state = Loadout.new()
		state.forceRarity = "Mythic"
		local hand = Loadout.rollOffer(state, true, dice())
		local found = false
		for _, id in hand do
			if Abilities.byId[id].rarity == "Mythic" then
				found = true
			end
		end
		t.isTrue(found, "no Mythic in the forced hand")
		t.equal(#hand, Progression.offerCount)
		t.isNil(state.forceRarity, "the request was not forgotten")
	end)
end
