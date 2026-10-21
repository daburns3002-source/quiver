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

	t.test("Front Arrow keeps the fan centred on the target", function()
		--[[ An even fan with nothing down the middle means a player aiming
		     straight at something misses it, which is the opposite of what
		     the card promises. ]]
		local specs = volley({ FrontArrow = 2 })
		local total = 0

		for _, spec in specs do
			total += spec.angleOffset
		end

		t.near(total, 0, 1e-6, "the fan is not balanced around the aim")
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

	t.test("Swift Arrows and Long Shot change flight, not count", function()
		local plain = volley({})
		local swift = volley({ SwiftArrows = 1 })
		local long = volley({ LongShot = 1 })

		t.equal(#swift, #plain, "Swift Arrows changed the arrow count")
		t.isTrue(swift[1].speed > plain[1].speed, "Swift Arrows did not speed anything up")
		t.isTrue(long[1].lifetime > plain[1].lifetime, "Long Shot did not extend anything")
	end)

	t.test("crit only exists once a chance has been drafted", function()
		t.near(volley({})[1].critChance, 0, 1e-9)

		local deadly = volley({ DeadlyStrike = 1 })
		t.isTrue(deadly[1].critChance > 0, "Deadly Strike granted no chance to crit")
	end)

	--[[ Overdraw is deliberately worthless on its own. That is the trap, and
	     it is only fair if the card that enables it is also offered. ]]
	t.test("Overdraw does nothing without a chance to crit", function()
		t.near(volley({ Overdraw = 3 })[1].critChance, 0, 1e-9)

		local both = volley({ DeadlyStrike = 1, Overdraw = 2 })
		local alone = volley({ DeadlyStrike = 1 })

		t.isTrue(
			both[1].critMultiplier > alone[1].critMultiplier,
			"Overdraw did not raise the payoff"
		)
	end)

	t.test("crit chance never exceeds certainty", function()
		local specs = volley({ DeadlyStrike = 99 })
		t.isTrue(specs[1].critChance <= 1, "crit chance went above 1")
	end)

	t.test("stats compound and never go backwards", function()
		local none = AbilityEffects.serverStats({})
		local some = AbilityEffects.serverStats({ Strength = 2, Vitality = 2, Precision = 2 })

		t.isTrue(some.damage > none.damage, "Strength did not raise damage")
		t.isTrue(some.maxHealth > none.maxHealth, "Vitality did not raise health")
		t.isTrue(some.attackCooldown < none.attackCooldown, "Precision did not shorten the gap")
	end)

	t.test("client stats compound and never go backwards", function()
		local none = AbilityEffects.clientStats({})
		local some = AbilityEffects.clientStats({ Agility = 2, Lightfoot = 2 })

		t.isTrue(some.moveSpeed > none.moveSpeed, "Agility did not raise move speed")
		t.isTrue(some.dashCooldown < none.dashCooldown, "Lightfoot did not shorten the dash")
	end)

	t.test("only Mending heals", function()
		t.isTrue(AbilityEffects.instantHeal("Mending", 100) > 0, "Mending healed nothing")
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
		local counts = { Precision = 3 }
		t.near(
			AbilityEffects.clientStats(counts).attackCooldown,
			AbilityEffects.serverStats(counts).attackCooldown,
			1e-9,
			"the client would fire at a different rate from the server"
		)
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

	t.test("Ricochet lets arrows bounce, and stacks", function()
		t.equal(volley({})[1].bounces, 0)
		t.isTrue(volley({ Ricochet = 1 })[1].bounces > 0, "Ricochet granted no bounces")
		t.isTrue(
			volley({ Ricochet = 2 })[1].bounces > volley({ Ricochet = 1 })[1].bounces,
			"a second Ricochet added nothing"
		)
	end)

	t.test("Soul Chain arms a kill, and stacks", function()
		t.equal(volley({})[1].chainOnKill, 0)
		t.isTrue(volley({ SoulChain = 1 })[1].chainOnKill > 0, "Soul Chain armed nothing")
		t.isTrue(
			volley({ SoulChain = 2 })[1].chainOnKill > volley({ SoulChain = 1 })[1].chainOnKill,
			"a second Soul Chain added nothing"
		)
	end)

	t.test("the behaviour cards reach every arrow in a wide volley", function()
		local specs = volley({ FrontArrow = 2, RearArrow = 1, BlastArrows = 1, Ricochet = 1 })
		t.isTrue(#specs > 3, "the volley did not widen")

		for index, spec in specs do
			t.isTrue(spec.splashRadius > 0, `arrow {index} does not explode`)
			t.isTrue(spec.bounces > 0, `arrow {index} does not bounce`)
		end
	end)

	t.test("Bloodthirst, Second Wind and Momentum reach the server stats", function()
		local none = AbilityEffects.serverStats({})
		t.equal(none.healPerKill, 0)
		t.isFalse(none.secondWind, "a fresh run starts with a free life")
		t.equal(none.momentumBonus, 0)

		local some = AbilityEffects.serverStats({
			Bloodthirst = 2,
			SecondWind = 1,
			Momentum = 2,
		})
		t.isTrue(some.healPerKill > 0, "Bloodthirst heals nothing")
		t.isTrue(some.secondWind, "Second Wind was not granted")
		t.isTrue(some.momentumBonus > 0, "Momentum adds nothing")
	end)

	--[[ Momentum multiplies damage by `1 + bonus` at full charge, so a bonus
	     at or above 1 means standing still doubles output — past that it stops
	     being a reward and becomes the only way to play. ]]
	t.test("Momentum at full stacks is a bonus, not a requirement", function()
		local capped = Abilities.byId.Momentum.maxStacks
		local bonus = AbilityEffects.serverStats({ Momentum = capped }).momentumBonus
		t.isTrue(bonus < 1.5, `standing still would multiply damage by {1 + bonus}`)
	end)

	t.test("count runs before pattern", function()
		t.isTrue(
			AbilityEffects.Stage.Count < AbilityEffects.Stage.Pattern,
			"pattern would widen a fan that does not exist yet"
		)
	end)
end
