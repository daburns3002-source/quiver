--!strict
--[[
	What a drafted loadout actually does to a shot.

	This is the test that enforces non-negotiable 1. An ability is a stage in
	a pipeline, and the thing that would quietly undo that is somebody adding
	an `if` to the firing code instead — so these assert the *observable*
	result of building a volley through the real pipeline, not that particular
	functions were called.

	Relationships again: "Front Arrow produces more arrows than none" survives
	every balance pass, "Front Arrow produces exactly four" does not.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)
local Types = require(ReplicatedStorage.Shared.Types)

local TestRunner = require(script.Parent.TestRunner)

local function request(): Types.ShotRequest
	return {
		damage = Balance.Player.baseDamage,
		speed = Balance.Projectile.speed,
		lifetime = Balance.Projectile.lifetime,
		origin = Vector3.zero,
		direction = Vector3.new(0, 0, -1),
	}
end

--[[ Builds a volley the way FiringSystem does, so what is asserted here is
     what a player would actually be shooting. ]]
local function volley(counts: { [string]: number }): { Types.ShotSpec }
	local pipeline = ShotPipeline.new()

	for _, stage in AbilityEffects.stages(counts) do
		pipeline:addStage(stage)
	end

	return pipeline:build(request())
end

return function(t: TestRunner.Helper)
	t.test("an empty loadout fires exactly one arrow", function()
		t.equal(#volley({}), 1)
	end)

	t.test("Front Arrow adds arrows", function()
		local one = #volley({ FrontArrow = 1 })
		local two = #volley({ FrontArrow = 2 })

		t.isTrue(one > 1, "one stack of Front Arrow added nothing")
		t.isTrue(two > one, "a second stack of Front Arrow added nothing")
	end)

	--[[
		The shape of a multi-arrow volley, which is the whole point of the
		card.

		Extra arrows fly in a lane beside each other, not fanned outwards. A
		fan separates with distance, so a player who aims every arrow at one
		enemy lands only the middle one — which is exactly the complaint this
		replaced.
	]]
	t.test("Front Arrow adds arrows beside the first, not fanned out", function()
		local specs = volley({ FrontArrow = 3 })
		t.isTrue(#specs > 1, "Front Arrow added nothing")

		local offsets: { number } = {}

		for _, spec in specs do
			t.near(spec.angleOffset, 0, 1e-9, "an extra arrow was aimed off the target")
			table.insert(offsets, spec.lateralOffset)
		end

		--[[ Distinct, or two arrows occupy the same space and one of them is
		     invisible. ]]
		table.sort(offsets)
		for index = 2, #offsets do
			t.isTrue(
				offsets[index] - offsets[index - 1] > 1e-6,
				"two arrows start in the same place"
			)
		end
	end)

	t.test("a volley stays centred on the line the player aimed along", function()
		for _, stacks in { 1, 2, 3, 4 } do
			local total = 0
			for _, spec in volley({ FrontArrow = stacks }) do
				total += spec.lateralOffset
			end
			t.near(total, 0, 1e-6, `a volley of {stacks + 1} arrows is lopsided`)
		end
	end)

	--[[
		The relationship the spacing has to keep.

		Widen it far enough and the outer arrows of a full-stack volley sail
		past the thing every one of them was aimed at. This holds the whole
		lane inside the narrowest enemy in the game, which is the only target
		that can miss.
	]]
	t.test("every arrow of a full volley still hits the narrowest enemy", function()
		local narrowest = math.huge
		for _, value in Balance.Enemies do
			local config = value :: Balance.EnemyConfig
			narrowest = math.min(narrowest, config.hitboxSize.X, config.hitboxSize.Z)
		end

		local reach = narrowest / 2 + Balance.Projectile.radius
		local capped = #Abilities.byId.FrontArrow.levels

		for _, spec in volley({ FrontArrow = capped }) do
			t.isTrue(
				math.abs(spec.lateralOffset) <= reach,
				`an arrow {math.abs(spec.lateralOffset)} studs out misses a {narrowest}-wide enemy`
			)
		end
	end)

	t.test("each pattern ability aims arrows somewhere new", function()
		for _, id in { "RearArrow", "SideArrows", "DiagonalArrows" } do
			local specs = volley({ [id] = 1 })
			t.isTrue(#specs > 1, `{id} produced no extra arrow`)

			local offCentre = false
			for _, spec in specs do
				if math.abs(spec.angleOffset) > 1e-6 then
					offCentre = true
				end
			end

			t.isTrue(offCentre, `{id} fired everything straight ahead`)
		end
	end)

	--[[ The compounding test: patterns multiply the whole volley rather than
	     adding one arrow, which is why Front Arrow is capped low. ]]
	--[[ Pattern abilities mirror whole volleys, so a lane fired backwards has
	     to stay a lane rather than collapsing onto one line. ]]
	t.test("a mirrored volley keeps its lane", function()
		local specs = volley({ FrontArrow = 2, RearArrow = 1 })

		local behind: { number } = {}
		for _, spec in specs do
			if math.abs(spec.angleOffset) > 1e-6 then
				table.insert(behind, spec.lateralOffset)
			end
		end

		t.isTrue(#behind > 1, "the rear volley lost its extra arrows")

		table.sort(behind)
		t.isTrue(behind[#behind] - behind[1] > 1e-6, "the rear arrows collapsed onto one line")
	end)

	t.test("count and pattern compound", function()
		local front = #volley({ FrontArrow = 2 })
		local both = #volley({ FrontArrow = 2, RearArrow = 1 })

		t.isTrue(both > front, "Rear Arrow did not act on the widened fan")
	end)

	t.test("Piercing Shot raises pierce on every arrow", function()
		for _, spec in volley({ PiercingShot = 2, FrontArrow = 1 }) do
			t.isTrue(spec.pierce > 0, "an arrow was left without pierce")
		end
	end)

	t.test("Swift Arrows and Long Shot change flight and payoff, not count", function()
		local plain = volley({})
		local swift = volley({ SwiftArrows = 1 })
		local long = volley({ LongShot = 1 })

		t.equal(#swift, #plain, "Swift Arrows changed the arrow count")
		t.isTrue(swift[1].speed > plain[1].speed, "Swift Arrows did not speed anything up")
		t.equal(plain[1].farBonus, 0)
		t.isTrue(long[1].farBonus > 0, "Long Shot set no bonus for range")
		t.isTrue(volley({ LongShot = 2 })[1].farBonus > long[1].farBonus, "level 2 added nothing")
	end)

	t.test("every arrow can crit a little, and Precision raises the chance", function()
		local plain = volley({})[1]
		t.near(plain.critChance, Balance.Player.critChance, 1e-9)

		t.isTrue(
			volley({ Precision = 1 })[1].critChance > plain.critChance,
			"Precision granted no extra chance"
		)
	end)

	t.test("Deadly Strike raises what a crit is worth, not how often", function()
		local plain = volley({})[1]
		local deadly = volley({ DeadlyStrike = 2 })[1]

		t.near(deadly.critChance, plain.critChance, 1e-9, "Deadly Strike changed the chance")
		t.isTrue(deadly.critMultiplier > plain.critMultiplier, "Deadly Strike raised nothing")
	end)

	t.test("crit chance never exceeds certainty", function()
		local specs = volley({ Precision = 99 })
		t.isTrue(specs[1].critChance <= 1, "crit chance went above 1")
	end)

	t.test("stats grow and never go backwards", function()
		local none = AbilityEffects.serverStats({})
		local some = AbilityEffects.serverStats({ Strength = 2, Vitality = 2 })

		t.isTrue(some.damage > none.damage, "Strength did not raise damage")
		t.isTrue(some.maxHealth > none.maxHealth, "Vitality did not raise health")
	end)

	t.test("Lightfoot makes the archer faster", function()
		local none = AbilityEffects.clientStats({})
		local some = AbilityEffects.clientStats({ Lightfoot = 2 })

		t.isTrue(some.moveSpeed > none.moveSpeed, "Lightfoot did not raise move speed")
	end)

	t.test("only the Heal card heals on the spot", function()
		t.isTrue(AbilityEffects.instantHeal("Heal", 100) > 0, "Heal healed nothing")
		t.equal(AbilityEffects.instantHeal("Mending", 100), 0)
		t.equal(AbilityEffects.instantHeal("Strength", 100), 0)
	end)

	--[[ Stages must land in the right bucket or ordering stops meaning
	     anything — a pattern that ran before count would fan one arrow and
	     then widen nothing. ]]
	t.test("every stage lands in a real bucket", function()
		local buckets: { [number]: boolean } = {}
		for _, value in AbilityEffects.Stage do
			buckets[value :: number] = true
		end

		local counts = {
			FrontArrow = 1,
			RearArrow = 1,
			PiercingShot = 1,
			SwiftArrows = 1,
			LongShot = 1,
			DeadlyStrike = 1,
		}

		for _, stage in AbilityEffects.stages(counts) do
			t.isTrue(buckets[stage.order], `{stage.name} is in no known bucket`)
		end
	end)

	--[[
		The prediction contract, and the bug it exists to stop.

		The client draws its own volley and skips the server's copy, so if the
		loadout does not reach it the player watches one unbuffed arrow for the
		whole run while the server fires the real ones elsewhere. Abilities
		then look like they do nothing and shots look like they miss — one
		cause, two complaints, and neither is visible to the type checker.

		So: whatever `clientStats` carries must rebuild the identical volley.
	]]
	t.test("the replicated loadout rebuilds the server's volley exactly", function()
		local counts = {
			FrontArrow = 2,
			RearArrow = 1,
			PiercingShot = 1,
			SwiftArrows = 1,
			DeadlyStrike = 1,
		}

		local server = volley(counts)
		local client = volley(AbilityEffects.clientStats(counts).abilities)

		t.equal(#client, #server, "the client would draw a different number of arrows")

		for index, spec in server do
			t.near(client[index].angleOffset, spec.angleOffset, 1e-9, "an arrow aims elsewhere")
			t.near(client[index].speed, spec.speed, 1e-9, "an arrow travels at a different speed")
			t.near(
				client[index].lifetime,
				spec.lifetime,
				1e-9,
				"an arrow fades at a different time"
			)
		end
	end)

	t.test("the client predicts the same firing rhythm as the server", function()
		local counts = { Momentum = 2 }
		local client = AbilityEffects.clientStats(counts)
		local server = AbilityEffects.serverStats(counts)
		t.near(client.attackCooldown, server.attackCooldown, 1e-9, "a different base rate")
		t.near(client.momentumBonus, server.momentumBonus, 1e-9, "a different Momentum")
	end)

	--[[ The server goes on mutating its own counts after sending them. ]]
	t.test("the replicated loadout is a copy", function()
		local counts = { FrontArrow = 1 }
		local sent = AbilityEffects.clientStats(counts).abilities

		counts.FrontArrow = 4

		t.equal(sent.FrontArrow, 1, "the client's copy changed underneath it")
	end)

	--[[ The abilities that change what a room asks of the player, rather than
	     how fast its numbers go up. Each asserts the spec field the server
	     actually reads, because that is the only thing that reaches the
	     game. ]]
	t.test("Blast Arrows gives every arrow a real explosion", function()
		local plain = volley({})
		t.near(plain[1].splashRadius, 0, 1e-9, "arrows explode without the card")

		local blast = volley({ BlastArrows = 1 })
		t.isTrue(blast[1].splashRadius > 0, "Blast Arrows set no radius")
		t.isTrue(blast[1].splashScale > 0, "Blast Arrows set no damage")

		local more = volley({ BlastArrows = 3 })
		t.isTrue(more[1].splashRadius > blast[1].splashRadius, "stacking did not widen it")
	end)

	--[[ A splash that matched the arrow would overtake the thing delivering
	     it, and shooting the floor beside a crowd would beat aiming. ]]
	t.test("splash never hits as hard as the arrow", function()
		t.isTrue(volley({ BlastArrows = 3 })[1].splashScale < 1, "splash matches a direct hit")
	end)

	t.test("Ricochet bounces between enemies, and stacks", function()
		t.equal(volley({})[1].ricochet, 0)
		t.isTrue(volley({ Ricochet = 1 })[1].ricochet > 0, "Ricochet granted no ricochets")
		t.isTrue(
			volley({ Ricochet = 2 })[1].ricochet > volley({ Ricochet = 1 })[1].ricochet,
			"a second Ricochet added nothing"
		)
	end)

	--[[ Two different abilities that used to be one. Archero 2's Ricochet
	     goes enemy to enemy; off the walls is Bouncy Wall. Neither should
	     quietly grant the other. ]]
	t.test("Ricochet and Bouncy Wall do not grant each other", function()
		t.equal(volley({ Ricochet = 1 })[1].bounces, 0, "Ricochet bounces off walls")
		t.equal(volley({ BouncyWall = 1 })[1].ricochet, 0, "Bouncy Wall ricochets")
	end)

	--[[ Multishot repeats a volley in time, not in space: the copies share
	     the first volley's aim and lane and differ only in when they leave. ]]
	t.test("Multishot repeats the volley later, along the same aim", function()
		local plain = volley({ FrontArrow = 1 })
		local doubled = volley({ FrontArrow = 1, Multishot = 1 })
		t.equal(#doubled, #plain * 2, "Multishot did not repeat every arrow")

		local now, later = 0, 0
		for _, spec in doubled do
			if spec.delay > 0 then
				later += 1
			else
				now += 1
			end
		end
		t.equal(now, #plain, "the first volley was delayed")
		t.equal(later, #plain, "the repeat was not delayed")

		for index, spec in plain do
			local copy = doubled[#plain + index]
			t.near(copy.angleOffset, spec.angleOffset, 1e-9, "a repeat was re-aimed")
			t.near(copy.lateralOffset, spec.lateralOffset, 1e-9, "a repeat left its lane")
		end

		t.isTrue(
			#volley({ Multishot = 2 }) > #volley({ Multishot = 1 }),
			"a second level added nothing"
		)
	end)

	--[[ Double Shot is a narrow fan: the arrows leave together, at small
	     angles either side of the aim. ]]
	t.test("Double Shot fans arrows narrowly around the aim", function()
		local specs = volley({ DoubleShot = 1 })
		t.equal(#specs, Abilities.byId.DoubleShot.levels[1], "the spread has the wrong count")

		local total = 0
		for _, spec in specs do
			t.equal(spec.delay, 0, "a spread arrow left late")
			t.isTrue(math.abs(spec.angleOffset) < math.rad(20), "the spread is not narrow")
			total += spec.angleOffset
		end
		t.near(total, 0, 1e-9, "the spread is lopsided")
		t.isTrue(#volley({ DoubleShot = 2 }) > #specs, "a second level added nothing")
	end)

	t.test("Blaze sets every arrow burning, and nothing else does", function()
		t.equal(volley({})[1].burn, 0)

		for index, spec in volley({ FrontArrow = 2, DiagonalArrows = 1, Blaze = 1 }) do
			t.isTrue(spec.burn > 0, `arrow {index} does not burn`)
			t.isTrue(spec.burnDuration > 0, `arrow {index} burns for no time`)
		end

		t.isTrue(
			volley({ Blaze = 2 })[1].burnDuration > volley({ Blaze = 1 })[1].burnDuration,
			"a second level burned no longer"
		)

		for _, ability in Abilities.all do
			if ability.id ~= "Blaze" then
				for _, spec in volley({ [ability.id] = 1 }) do
					t.equal(spec.burn, 0, `{ability.id} sets arrows burning`)
				end
			end
		end
	end)

	t.test("Tracking Eye makes arrows home, and nothing else does", function()
		t.equal(volley({})[1].homing, 0)
		t.isTrue(volley({ TrackingEye = 1 })[1].homing > 0, "Tracking Eye granted no homing")

		for _, ability in Abilities.all do
			if ability.id ~= "TrackingEye" then
				for _, spec in volley({ [ability.id] = 1 }) do
					t.equal(spec.homing, 0, `{ability.id} makes arrows home`)
				end
			end
		end
	end)

	t.test("Bouncy Wall lets arrows bounce off walls, and stacks", function()
		t.equal(volley({})[1].bounces, 0)
		t.isTrue(volley({ BouncyWall = 1 })[1].bounces > 0, "Bouncy Wall granted no bounces")
		t.isTrue(
			volley({ BouncyWall = 2 })[1].bounces > volley({ BouncyWall = 1 })[1].bounces,
			"a second Bouncy Wall added nothing"
		)
	end)

	--[[ The footage's fan is about ±30°. Held as a shape rather than a value:
	     diagonals that reach the sides are Side Arrows, and diagonals that
	     collapse onto the aim are Front Arrow. ]]
	t.test("Diagonal Arrows fan between straight ahead and the sides", function()
		local specs = volley({ DiagonalArrows = 1 })
		t.equal(#specs, 3, "Diagonal Arrows should add exactly two arrows")

		local left, right = false, false
		for _, spec in specs do
			local offset = spec.angleOffset
			if offset > 0 then
				left = true
			elseif offset < 0 then
				right = true
			end
			t.isTrue(math.abs(offset) < math.pi / 2, "a diagonal arrow fires to the side")
		end

		t.isTrue(left and right, "the diagonals are not either side of the aim")
		t.isTrue(
			math.abs(specs[2].angleOffset) > math.rad(10),
			"diagonals so narrow they land on the same enemy"
		)

		t.equal(#volley({ DiagonalArrows = 2 }), 5, "the second level should add two more")
	end)

	t.test("Soul Chain links more enemies each level", function()
		t.equal(volley({})[1].link, 0)
		t.isTrue(volley({ SoulChain = 1 })[1].link > 0, "Soul Chain linked nothing")
		t.isTrue(
			volley({ SoulChain = 2 })[1].link > volley({ SoulChain = 1 })[1].link,
			"a second level linked no more"
		)
		t.isTrue(Balance.Projectile.linkShare < 1, "a linked enemy takes the whole hit")
	end)

	t.test("the behaviour cards reach every arrow in a wide volley", function()
		local specs = volley({
			FrontArrow = 2,
			RearArrow = 1,
			BlastArrows = 1,
			Ricochet = 1,
			BouncyWall = 1,
		})
		t.isTrue(#specs > 3, "the volley did not widen")

		for index, spec in specs do
			t.isTrue(spec.splashRadius > 0, `arrow {index} does not explode`)
			t.isTrue(spec.ricochet > 0, `arrow {index} does not ricochet`)
			t.isTrue(spec.bounces > 0, `arrow {index} does not bounce`)
		end
	end)

	t.test("the vital and power cards reach the server stats", function()
		local none = AbilityEffects.serverStats({})
		t.equal(none.healPerKill, 0)
		t.equal(none.regenPerSecond, 0)
		t.equal(none.dodgeChance, 0)
		t.equal(none.secondWind, 0, "a fresh run starts with a free life")
		t.equal(none.overdrawBonus, 0)
		t.equal(none.momentumBonus, 0)

		local some = AbilityEffects.serverStats({
			Bloodthirst = 2,
			Mending = 1,
			Agility = 1,
			SecondWind = 1,
			Overdraw = 2,
			Momentum = 2,
		})
		t.isTrue(some.healPerKill > 0, "Bloodthirst heals nothing")
		t.isTrue(some.regenPerSecond > 0, "Mending regenerates nothing")
		t.isTrue(some.dodgeChance > 0, "Agility dodges nothing")
		t.isTrue(some.secondWind > 0 and some.secondWind < 1, "Second Wind revives at no share")
		t.isTrue(some.overdrawBonus > 0, "Overdraw adds nothing")
		t.isTrue(some.momentumBonus > 0, "Momentum adds nothing")
	end)

	--[[ Overdraw multiplies damage by `1 + bonus` at full charge. Past
	     about doubling, standing still stops being a reward and becomes the
	     only way to play. ]]
	t.test("Overdraw at its top level is a bonus, not a requirement", function()
		local levels = Abilities.byId.Overdraw.levels
		local bonus = AbilityEffects.serverStats({ Overdraw = #levels }).overdrawBonus
		t.isTrue(bonus < 1.5, `standing still would multiply damage by {1 + bonus}`)
	end)

	--[[ Momentum pays only after real movement, and only for a while after
	     stopping — banked by moving, spent on the shots after. ]]
	t.test("Momentum quickens fire only after moving, and only for a while", function()
		local cooldown = Balance.Player.attackCooldown
		local bonus = Abilities.byId.Momentum.levels[1]
		local momentum = Balance.Player.momentum

		t.equal(AbilityEffects.cooldownAt(cooldown, 0, 99, 0), cooldown, "no card, no change")
		t.isTrue(
			AbilityEffects.cooldownAt(cooldown, bonus, momentum.windup + 0.1, 0) < cooldown,
			"moving then stopping did not quicken fire"
		)
		t.equal(
			AbilityEffects.cooldownAt(cooldown, bonus, momentum.windup * 0.5, 0),
			cooldown,
			"a twitch counted as moving"
		)
		t.equal(
			AbilityEffects.cooldownAt(cooldown, bonus, 99, momentum.duration + 0.1),
			cooldown,
			"Momentum never ran out"
		)
	end)

	t.test("every card's level count matches its stat lines", function()
		for _, ability in Abilities.all do
			t.equal(#ability.stats, #ability.levels, `{ability.id} has stats for the wrong levels`)
			t.isTrue(#ability.levels >= 1, `{ability.id} has no levels`)
			for index = 2, #ability.levels do
				t.isTrue(
					ability.levels[index] > ability.levels[index - 1],
					`{ability.id} level {index} is no better than level {index - 1}`
				)
			end
		end
	end)

	t.test("count runs before pattern", function()
		t.isTrue(
			AbilityEffects.Stage.Count < AbilityEffects.Stage.Pattern,
			"pattern would widen a fan that does not exist yet"
		)
	end)
end
