--!strict
--[[
	Endless mode's schedule, curve, ramp and rotation (`docs/ENDLESS.md`,
	`Balance.Endless`, `Run/Waves`'s floor functions).

	All of it is pure — a floor number in, a description out — so the whole
	difficulty of the mode is pinned here rather than found in a playtest.
	The two numbers that *are* the difficulty (health 1.045 and damage 1.030
	a floor) are asserted by value, because the doc argues for those and not
	merely for "health faster than damage".

	What is not here is the run loop: `Run/RoomController` plays what these
	say a floor is, and holding the two apart is what keeps this testable
	without a running game.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local TestRunner = require(script.Parent.TestRunner)
local Waves = require(ServerScriptService.Server.Run.Waves)

return function(t: TestRunner.Helper)
	--[[
		=== Endless (`docs/ENDLESS.md`) ===

		The mode's whole difficulty and all of its pacing are these pure
		functions over `Balance.Endless`, so they are pinned here rather than
		discovered in a playtest.
	]]

	t.test("the Endless schedule: bosses every 10th, mini-bosses every 5th", function()
		local schedule = Balance.Endless
		t.equal(schedule.bossEvery, 10)
		t.equal(schedule.miniBossEvery, 5)
		for floor = 1, 60 do
			local kind = Waves.floorKind(floor)
			if floor % 10 == 0 then
				t.equal(kind, "Boss", `floor {floor} is not a boss`)
			elseif floor % 5 == 0 then
				t.equal(kind, "Elite", `floor {floor} is not a mini-boss`)
			else
				t.equal(kind, "Fight", `floor {floor} is not a fight`)
			end
		end
	end)

	--[[ The orthogonality is the contract: there is no precedence table,
	     so a draft can never be displaced by a fight or deferred past it. ]]
	t.test("the draft is every 3rd floor, whatever kind of floor it is", function()
		t.equal(Balance.Endless.draftEvery, 3)
		for floor = 1, 60 do
			t.equal(
				Waves.floorDrafts(floor),
				floor % 3 == 0,
				`floor {floor} drafts when it should not, or not when it should`
			)
		end
		-- floor 15 is a mini-boss that also drafts
		t.equal(Waves.floorKind(15), "Elite")
		t.isTrue(Waves.floorDrafts(15), "floor 15 is a mini-boss and loses its draft")
		-- floor 30 is a boss that also drafts
		t.equal(Waves.floorKind(30), "Boss")
		t.isTrue(Waves.floorDrafts(30), "floor 30 is a boss and loses its draft")
		-- and floor 9 drafts without being either
		t.equal(Waves.floorKind(9), "Fight")
		t.isTrue(Waves.floorDrafts(9))
		-- floor 10 is a boss that does not draft: 10 is not a multiple of 3
		t.isFalse(Waves.floorDrafts(10))
	end)

	--[[ The curve: health 1.045 and damage 1.030 per floor, compounding
	     from floor 1, health faster than damage on purpose. The numbers the
	     doc argues for are asserted, not just the shape. ]]
	t.test("the curve compounds from floor 1, health ahead of damage", function()
		t.near(Balance.Endless.health, 1.045, 1e-9)
		t.near(Balance.Endless.damage, 1.03, 1e-9)

		local first = Waves.floorCurve(1)
		t.near(first.health, 1, 1e-9, "floor 1 is the area's own difficulty")
		t.near(first.damage, 1, 1e-9)

		t.near(Waves.floorCurve(2).health, 1.045, 1e-9)
		t.near(Waves.floorCurve(11).health, 1.045 ^ 10, 1e-9)
		t.near(Waves.floorCurve(51).damage, 1.03 ^ 50, 1e-9)

		--[[ The doc's figure for floor 50 is 9.0x, which is 1.045^50 — one
		     step more than the formula it gives in the same section,
		     1.045^(floor - 1). The formula is the contract, so floor 50 is
		     1.045^49 = 8.64x and 9.0x is where floor 51 lands. Asserted both
		     ways so neither can drift unnoticed. ]]
		t.near(Waves.floorCurve(50).health, 1.045 ^ 49, 1e-9)
		t.near(Waves.floorCurve(50).health, 8.64, 0.01, "floor 50 is not about 8.6x health")
		t.near(Waves.floorCurve(51).health, 9.03, 0.01, "the doc's 9.0x is not floor 51")
		--[[ And never faster in damage than in health, at any depth: an
		     enemy that deletes you without warning is a worse game. ]]
		for floor = 1, 200 do
			local curve = Waves.floorCurve(floor)
			t.isTrue(curve.health >= curve.damage, `floor {floor} grows damage faster than health`)
		end
	end)

	t.test("the enemy count ramps off the area's base and caps", function()
		local schedule = Balance.Endless
		local base = 5
		t.equal(Waves.floorCount(base, 1), base, "floor 1 is the area's own count")
		t.equal(Waves.floorCount(base, schedule.countEvery), base + 1)
		-- the bonus is spent by floor 30 and never grows past it
		local full = base + schedule.countBonus
		t.equal(Waves.floorCount(base, 30), math.min(full, schedule.countCap))
		t.equal(Waves.floorCount(base, 200), math.min(full, schedule.countCap))
		-- and the arena's own cap wins over the ramp
		t.equal(Waves.floorCount(schedule.countCap + 4, 200), schedule.countCap)
		-- never steps back
		local previous = 0
		for floor = 1, 200 do
			local count = Waves.floorCount(base, floor)
			t.isTrue(count >= previous, `floor {floor} has fewer enemies than the one before`)
			previous = count
		end
	end)

	t.test("the areas rotate ten floors each, and the laps count from 1", function()
		local areas = Balance.Endless.areas
		t.isTrue(#areas >= 2, "Endless rotates over fewer than two areas")
		local lap = #areas * Balance.Endless.bossEvery
		for floor = 1, 10 do
			t.equal(Waves.floorArea(floor), 1, `floor {floor} is not in the first area`)
			t.equal(Waves.floorLap(floor), 1)
		end
		for floor = 11, 20 do
			t.equal(Waves.floorArea(floor), 2, `floor {floor} is not in the second area`)
			t.equal(Waves.floorLap(floor), 1, `floor {floor} is not still the first lap`)
		end
		-- the lap comes round: floor 1 + a lap is the first area again, one lap deeper
		t.equal(Waves.floorArea(1 + lap), 1)
		t.equal(Waves.floorLap(1 + lap), 2)
		t.equal(Waves.floorLap(lap), 1, "the last floor of lap 1 is still lap 1")
		t.equal(Waves.floorLap(lap + 1), 2)
	end)

	--[[ Drawn in order, so a run is reproducible, and bounded, so nothing
	     stacks twice however deep the run goes. ]]
	t.test("each lap past the first adds the next modifier, in order", function()
		local all = Balance.Endless.modifiers
		local lap = #Balance.Endless.areas * Balance.Endless.bossEvery
		t.equal(#Waves.floorModifiers(1), 0, "the first lap has a modifier")
		for n = 1, #all + 2 do
			local floor = n * lap + 1
			local held = Waves.floorModifiers(floor)
			t.equal(#held, math.min(n, #all), `lap {n + 1} holds the wrong number of modifiers`)
			for index, modifier in held do
				t.equal(modifier.key, all[index].key, `lap {n + 1} drew them out of order`)
			end
		end
	end)

	t.test("a modifier's fire rate is in force only from its lap", function()
		local lap = #Balance.Endless.areas * Balance.Endless.bossEvery
		local first = Balance.Endless.modifiers[1]
		t.near(Waves.floorFireRate(1), 1, 1e-9, "the first lap fires faster")
		if first.fireRate then
			t.near(Waves.floorFireRate(lap + 1), first.fireRate, 1e-9)
		end
	end)

	t.test("every floor to the cap has a fight in it, in a real area", function()
		for floor = 1, Balance.Endless.maxFloor do
			local description = Waves.describeFloor(floor)
			t.isTrue(description.count > 0, `floor {floor} is a fight with nobody in it`)
			t.isTrue(#description.roster > 0, `floor {floor} has no roster`)
			local area = Balance.Endless.areas[Waves.floorArea(floor)]
			t.notNil(Balance.Rooms[area.arena], `floor {floor}'s area has no arena`)
		end
	end)

	t.test("a boss floor fights the area's own boss, with no count bonus", function()
		for _, floor in { 10, 20, 30, 200 } do
			local area = Balance.Endless.areas[Waves.floorArea(floor)]
			local description = Waves.describeFloor(floor)
			t.equal(description.kind, "Boss")
			--[[ The depth ramp and the count bonus never touch a boss floor;
			     the area's own `bossByLap` is the only thing that says how
			     many there are. ]]
			t.equal(
				description.count,
				Waves.floorBossCount(floor),
				`floor {floor}'s boss was given the count ramp`
			)
			t.isTrue(description.roster[1] == area.boss.roster[1])
			t.notNil(area.boss.roster[1].boss, `floor {floor}'s boss is not a boss`)
		end
	end)

	--[[
		The owner's "for level 30 and 50 and on every time he appears in
		endless it should be 2 king bloblins" (2026-10-28), read as a ramp:
		floor 10 keeps one king, and every glade boss floor from 30 down
		fights two. By lap rather than by floor, so it still means "the
		second time the glade comes round" when a third area joins the
		rotation (`Balance.EndlessArea.bossByLap`).
	]]
	t.test("the glade's boss floors ramp to two King Bloblins from floor 30", function()
		local glade = Balance.Endless.areas[1]
		t.equal(glade.name, "Mossy Glade", "the rotation no longer opens in the glade")
		t.notNil(glade.bossByLap, "the glade's boss floors do not ramp")

		t.equal(Waves.describeFloor(10).count, 1, "floor 10 fights more than one king")
		for _, floor in { 30, 50, 70, 90, 190 } do
			t.equal(Waves.floorArea(floor), 1, `floor {floor} is not a glade floor`)
			local description = Waves.describeFloor(floor)
			t.equal(description.kind, "Boss")
			t.equal(description.count, 2, `floor {floor} does not fight two kings`)
			--[[ A roster of one, cycled: two of the same body, which is
			     what `EnemyManager.spawnWave` makes of it. ]]
			t.equal(#description.roster, 1)
			t.isTrue(description.roster[1] == glade.boss.roster[1])
		end
	end)

	t.test("an area with no ramp fights one boss however deep it is", function()
		local thornwood = Balance.Endless.areas[2]
		t.isNil(thornwood.bossByLap, "Thornwood's boss floors ramp")
		for _, floor in { 20, 40, 60, 200 } do
			t.equal(Waves.floorArea(floor), 2, `floor {floor} is not a Thornwood floor`)
			t.equal(
				Waves.describeFloor(floor).count,
				thornwood.boss.enemyCount,
				`floor {floor} does not fight one Broodmother`
			)
		end
	end)

	t.test("the PAIRED ELITES lap puts a second elite in a mini-boss fight", function()
		local lap = #Balance.Endless.areas * Balance.Endless.bossEvery
		--[[ The lap on which `Pairs` comes in: its place in the list is the
		     lap past the first that adds it. ]]
		local position = nil
		for index, modifier in Balance.Endless.modifiers do
			if modifier.key == "Pairs" then
				position = index
			end
		end
		t.notNil(position, "no PAIRED ELITES modifier to test")
		local before = 5
		local after = position :: number * lap + 5
		t.isFalse(Waves.floorHasModifier(before, "Pairs"))
		t.isTrue(Waves.floorHasModifier(after, "Pairs"))

		local area = Balance.Endless.areas[Waves.floorArea(after)]
		local paired = Waves.describeFloor(after)
		t.equal(paired.kind, "Elite")
		t.equal(
			paired.count,
			Waves.floorCount(area.miniBoss.enemyCount + 1, after),
			"the second elite brought nobody with it"
		)
		t.isTrue(paired.roster[1] == area.miniBoss.roster[1])
		t.isTrue(paired.roster[2] == area.miniBoss.roster[1], "the pair is not two of the same")
	end)

	--[[ Found in a Studio playtest: at floor 45 the paired elite pushed the
	     count to 13 against a cap of 12. The cap is the arena's room and the
	     device tiers' projectile budget (`docs/PERFORMANCE.md`), so no
	     modifier may step over it, however deep the run goes. ]]
	t.test("no floor ever puts more enemies in the arena than the cap", function()
		local cap = Balance.Endless.countCap
		for floor = 1, Balance.Endless.maxFloor do
			local description = Waves.describeFloor(floor)
			if description.kind ~= "Boss" then
				t.isTrue(
					description.count <= cap,
					`floor {floor} spawns {description.count}, over the cap of {cap}`
				)
			end
		end
	end)

	t.test("Soulstones are paid at boss floors only, growing per block", function()
		local pay = Balance.Endless.blockPay
		t.equal(Waves.floorPay(1), 0, "a fight floor pays Soulstones")
		t.equal(Waves.floorPay(5), 0, "a mini-boss floor pays Soulstones")
		t.equal(Waves.floorPay(10), pay)
		t.equal(Waves.floorPay(20), pay * 2)
		t.equal(Waves.floorPay(60), pay * 6)
		--[[ The run cap is the floor-60 total, which is what makes depth
		     past it pay prestige and not currency. ]]
		local through60 = 0
		for floor = 1, 60 do
			through60 += Waves.floorPay(floor)
		end
		t.equal(Balance.Endless.runCap, through60, "the run cap is not the floor-60 total")
	end)

	t.test("the milestones are the doc's floors, and only those reached", function()
		local floors = {}
		for _, milestone in Balance.Endless.milestones do
			table.insert(floors, milestone.floor)
			t.isTrue(milestone.soulstones > 0, `the floor {milestone.floor} milestone pays nothing`)
			t.isTrue(#milestone.name > 0)
			t.isTrue(
				milestone.floor <= Balance.Endless.maxFloor,
				`the floor {milestone.floor} milestone is past the hard cap`
			)
		end
		t.equal(table.concat(floors, ","), "10,20,30,50,75,100")

		--[[ **Floor 75 is a mini-boss floor, not a boss floor.** The doc
		     lists a milestone there and also vests rewards at boss floors,
		     and both cannot be true of it; the milestones are therefore
		     claimed as their floor is reached rather than at a boss floor
		     (`Run/RoomController.clearedFloor`). Pinned here so the
		     inconsistency is never rediscovered as a bug. ]]
		t.equal(Waves.floorKind(75), "Elite", "floor 75 became a boss floor")
		for _, floor in { 10, 20, 30, 50, 100 } do
			t.equal(Waves.floorKind(floor), "Boss", `floor {floor} is no longer a boss floor`)
		end

		t.equal(#Waves.floorMilestones(9), 0)
		t.equal(#Waves.floorMilestones(10), 1)
		t.equal(#Waves.floorMilestones(30), 3)
		t.equal(#Waves.floorMilestones(100), 6)
		t.equal(#Waves.floorMilestones(200), 6, "depth past 100 invents milestones")
		-- shallowest first, so claiming walks them in order
		local previous = 0
		for _, milestone in Waves.floorMilestones(200) do
			t.isTrue(milestone.floor > previous, "the milestones came back out of order")
			previous = milestone.floor
		end
	end)

	t.test("the hard cap bounds the run at floor 200", function()
		t.equal(Balance.Endless.maxFloor, 200)
		t.equal(Waves.floorsTotal(), 200)
	end)

	--[[ Endless must not borrow the story's pacing: its schedule is its own
	     so retuning one never moves the other (`docs/ENDLESS.md`). ]]
	t.test("Endless reads none of Balance.Waves's positions", function()
		local story = Balance.Waves
		local endless = Balance.Endless
		t.isTrue(endless.bossEvery ~= nil and endless.miniBossEvery ~= nil)
		t.isTrue(endless.draftEvery ~= nil)
		--[[ Floor 5 is a mini-boss while wave 5 is a Valkyrie, and floor 9 a
		     fight while wave 9 is an Angel: the two schedules genuinely
		     differ, so a shared read would show up here. ]]
		t.equal(Waves.kind(story.valkyrieAt), "Valkyrie")
		t.equal(Waves.floorKind(story.valkyrieAt), "Elite")
		t.equal(Waves.kind(story.angelAt), "Angel")
		t.equal(Waves.floorKind(story.angelAt), "Fight")
	end)

	t.test("the Endless stage carries nothing a floor could contradict", function()
		local stage = Balance.Stages[Balance.endlessStage]
		t.notNil(stage, "Balance.endlessStage names no stage")
		t.equal(stage.mode, "Endless")
		t.isNil(stage.waves, "the Endless stage has a wave count")
		t.isNil(stage.arena, "the Endless stage has one fixed arena")
		t.isNil(stage.fights, "the Endless stage has its own fights")
		--[[ No `area`, so `RunSession.areaPay` pays no coins for an Endless
		     kill: the mode pays Soulstones, and the story economy cannot be
		     inflated by depth. No `level`, so nothing of it is ever written
		     to `levelsBeaten`. ]]
		t.isNil(stage.area, "Endless pays an area's coins")
		t.isNil(stage.level, "Endless can be written to levelsBeaten")
		t.isNil(stage.enemyDamage, "the Endless stage fixes enemy damage")
		t.isNil(stage.enemyHealth, "the Endless stage fixes enemy health")
		t.isTrue(
			table.find(Balance.campaign, Balance.endlessStage) == nil,
			"Endless is in the campaign, so it scores story progress"
		)
	end)
end
