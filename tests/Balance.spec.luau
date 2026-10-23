--!strict
--[[
	Config invariants.

	Balance is pure data, so the type checker already catches a missing field.
	What it cannot catch is a number that is individually legal and wrong in
	context — and tonight produced one of exactly that kind: the Lurker's dive
	was gated on being further away than its own `attackRange`, which a ranged
	enemy parks itself at, so the condition could never be true twice.

	These assert relationships between numbers, not the numbers themselves.
	Tuning a value should never fail a test here; tuning it into a shape that
	cannot work should.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local TestRunner = require(script.Parent.TestRunner)

--[[
	`Balance.Enemies` is a table with named keys, so generic iteration over it
	yields `unknown`. Restated once here rather than cast at every use site.
]]
local function archetypes(): { [string]: Balance.EnemyConfig }
	return Balance.Enemies :: any
end

return function(t: TestRunner.Helper)
	t.test("every archetype has sane core stats", function()
		for name, config in archetypes() do
			t.isTrue(config.health > 0, `{name} needs positive health`)
			t.isTrue(#config.displayName > 0, `{name} needs a display name`)
			--[[ A boss does not walk and swing: its moves carry it and do its
			     damage (`EnemyConfig.boss`, checked below). ]]
			if config.boss then
				continue
			end
			t.isTrue(config.moveSpeed > 0, `{name} needs positive move speed`)
			t.isTrue(config.attackRange > 0, `{name} needs positive attack range`)
			t.isTrue(config.attackDamage > 0, `{name} needs positive damage`)
			t.isTrue(config.attackCooldown > 0, `{name} needs a positive cooldown`)
		end
	end)

	--[[ A boss's moves hurt in a handful, never in one: not a slam, and not
	     a whole grab (the lash and the chest bump after it). ]]
	t.test("a boss's hits are lethal in a handful, never in one", function()
		for name, config in archetypes() do
			local boss = config.boss
			if not boss then
				continue
			end
			local half = Balance.Player.maxHealth / 2
			t.isTrue(boss.bounce.damage > 0 and boss.bounce.damage < half, `{name}'s slam`)
			local grab = boss.lash.damage + boss.lash.bumpDamage
			t.isTrue(boss.lash.damage > 0 and grab < half, `{name}'s grab`)
		end
	end)

	t.test("a ranged archetype can hold its distance without stalling", function()
		for name, config in archetypes() do
			local shot = config.shot
			if shot then
				t.isTrue(
					config.attackRange > Balance.Player.attackRange * 0.2,
					`{name} shoots from so close it may as well be melee`
				)
				t.isTrue(shot.count >= 1, `{name} must fire at least one projectile`)
				t.isTrue(shot.speed > 0, `{name} needs a positive projectile speed`)
				t.isTrue(shot.lifetime > 0, `{name} needs a positive projectile lifetime`)

				--[[ Its shots reach as far as it is allowed to fire from, or
				     it opens fire at players its shots can never touch. ]]
				local fireRange = shot.range or config.attackRange
				t.isTrue(
					shot.speed * shot.lifetime >= fireRange - 1e-6,
					`{name} fires from {fireRange} studs but its shots die at {shot.speed * shot.lifetime}`
				)
			end
		end
	end)

	t.test("a telegraph is long enough to react to", function()
		for name, config in archetypes() do
			local shot = config.shot
			if shot then
				t.isTrue(shot.telegraph > 0, `{name} needs a non-zero telegraph`)
				t.isTrue(
					shot.telegraph < config.attackCooldown,
					`{name} winds up for longer than its own cooldown`
				)
			end
		end
	end)

	--[[ A drawn line that re-aims is a lie, and players learn to ignore tells
	     that lie. This is the one coupling in the config that must hold. ]]
	t.test("a Line tell always locks its aim", function()
		for name, config in archetypes() do
			local shot = config.shot
			if shot and shot.tell == "Line" then
				t.isTrue(shot.locksAim, `{name} draws a line it does not commit to`)
			end
		end
	end)

	--[[ The bug that shipped tonight, in config form. ]]
	t.test("a burrower's surface distance is inside its attack range", function()
		for name, config in archetypes() do
			local burrow = config.burrow
			if burrow then
				t.isTrue(
					burrow.surfaceDistance < config.attackRange,
					`{name} would surface further away than it shoots from`
				)
				t.isTrue(burrow.duration > 0, `{name} needs a positive dive duration`)
				t.isTrue(
					burrow.surfaceTell > 0 and burrow.surfaceTell < burrow.duration,
					`{name} needs a warning that fits inside its dive`
				)
				t.isTrue(burrow.speedScale > 1, `{name} should dive faster than it walks`)
				t.isTrue(burrow.cooldown > 0, `{name} must not be able to chain dives`)
			end
		end
	end)

	t.test("enemy projectiles stay slow enough to read", function()
		for name, config in archetypes() do
			local shot = config.shot
			--[[ The teardown asks for 8–20 studs/s so a phone player can see
			     them coming. The Lancer is the deliberate exception: its
			     counterplay is the line, not the flight time. ]]
			if shot and shot.tell ~= "Line" then
				t.isTrue(shot.speed <= 24, `{name} fires too fast to dodge on sight`)
			end
		end
	end)

	--[[
		The order archetypes appear in is the tutorial, and it is the kind of
		thing that regresses silently: one shared roster across all ten rooms
		put a charger, a spitter and a burrower in the opening fight, which
		reads as the game being too hard rather than as three mechanics
		arriving at once.
	]]
	t.test("no room introduces more than one new archetype", function()
		local met: { [string]: boolean } = {}

		for index, room in Balance.Rooms do
			local introduced = {}

			for _, config in room.roster do
				if not met[config.displayName] then
					met[config.displayName] = true
					table.insert(introduced, config.displayName)
				end
			end

			t.isTrue(
				#introduced <= 1,
				`room {index} introduces {#introduced} new archetypes at once: {table.concat(
					introduced,
					", "
				)}`
			)
		end
	end)

	t.test("the first room teaches exactly one thing", function()
		local first = Balance.Rooms[1]
		local names: { [string]: boolean } = {}
		local distinct = 0

		for _, config in first.roster do
			if not names[config.displayName] then
				names[config.displayName] = true
				distinct += 1
			end
		end

		t.equal(distinct, 1, "the opener should hold a single archetype")
	end)

	t.test("every archetype is introduced somewhere in the run", function()
		local used: { [string]: boolean } = {}

		for _, room in Balance.Rooms do
			for _, config in room.roster do
				used[config.displayName] = true
				--[[ What it splits into arrives with it (the Brood Slime's
				     babies). ]]
				local split = config.split
				if split then
					used[split.into.displayName] = true
				end
			end
		end

		for name, config in archetypes() do
			t.isTrue(used[config.displayName], `{name} never appears in any room`)
		end
	end)

	t.test("every room is playable", function()
		t.isTrue(#Balance.Rooms > 0, "there must be at least one room")

		for index, room in Balance.Rooms do
			t.isTrue(#room.name > 0, `room {index} needs a name`)
			t.isTrue(room.enemyCount > 0, `room {index} needs enemies`)
			t.isTrue(#room.roster > 0, `room {index} has nothing to spawn`)

			for _, obstacle in room.obstacles do
				t.isTrue(
					obstacle.size.X > 0 and obstacle.size.Z > 0,
					`room {index} has a flat obstacle`
				)

				local halfX = Balance.Arena.size.X / 2
				local halfZ = Balance.Arena.size.Z / 2

				t.isTrue(
					math.abs(obstacle.offset.X) + obstacle.size.X / 2 <= halfX,
					`room {index} has an obstacle through the east or west wall`
				)
				t.isTrue(
					math.abs(obstacle.offset.Y) + obstacle.size.Z / 2 <= halfZ,
					`room {index} has an obstacle through the north or south wall`
				)
			end
		end
	end)

	--[[
		A layout that put a pillar on either fixed point would wall the player
		into it or make the room unfinishable. Both are easy to do by accident
		when hand-authoring offsets, and neither is visible until the room is
		played.
	]]
	t.test("no room blocks the player start or the exit pad", function()
		local start = Balance.Arena.spawnPosition
		local door = Balance.Run.doorOffset

		local fixed = {
			{ label = "the player start", x = start.X, z = start.Z },
			{ label = "the exit pad", x = door.X, z = door.Y },
		}

		for index, room in Balance.Rooms do
			for _, obstacle in room.obstacles do
				for _, point in fixed do
					local insideX = math.abs(point.x - obstacle.offset.X) < obstacle.size.X / 2
					local insideZ = math.abs(point.z - obstacle.offset.Y) < obstacle.size.Z / 2

					t.isFalse(insideX and insideZ, `room {index} puts an obstacle on {point.label}`)
				end
			end
		end
	end)

	t.test("the exit pad and the player start are both inside the arena", function()
		local halfX = Balance.Arena.size.X / 2
		local halfZ = Balance.Arena.size.Z / 2
		local door = Balance.Run.doorOffset
		local start = Balance.Arena.spawnPosition

		t.isTrue(
			math.abs(door.X) < halfX and math.abs(door.Y) < halfZ,
			"the pad is outside the arena"
		)
		t.isTrue(
			math.abs(start.X) < halfX and math.abs(start.Z) < halfZ,
			"the player start is outside the arena"
		)
	end)

	--[[ If a wave could spawn closer than this, the player is in melee before
	     they have taken a step — which is the bug this suite was written
	     alongside. ]]
	t.test("the spawn exclusion is smaller than the arena can satisfy", function()
		--[[
			Measured from the player start rather than the arena centre,
			because that is where players are when a wave is placed — and it
			sits near a wall, so the reachable distance is far larger than a
			centre-based figure suggests. Using the centre would make a
			workable exclusion look impossible.
		]]
		local start = Balance.Arena.spawnPosition
		local halfX = Balance.Arena.size.X / 2
		local halfZ = Balance.Arena.size.Z / 2
		local corners = {
			Vector2.new(halfX, halfZ),
			Vector2.new(-halfX, halfZ),
			Vector2.new(halfX, -halfZ),
			Vector2.new(-halfX, -halfZ),
		}

		local furthest = 0
		for _, corner in corners do
			furthest = math.max(furthest, (corner - Vector2.new(start.X, start.Z)).Magnitude)
		end

		t.isTrue(
			Balance.Spawning.minSpawnDistance > 0,
			"enemies need a minimum distance from the player"
		)
		t.isTrue(
			Balance.Spawning.minSpawnDistance < furthest,
			`nothing in the arena sits {Balance.Spawning.minSpawnDistance} studs from the start`
		)
	end)

	--[[
		The radius is what the server casts with *and* what the client draws,
		so it is the one number that decides whether a shot that looks like a
		hit is one. It used to size only the drawn part while the server cast
		a zero-width ray, which is how arrows passed through enemies.
	]]
	t.test("projectiles have a shape the server can sweep", function()
		local radius = Balance.Projectile.radius
		local length = Balance.Projectile.length

		t.isTrue(radius > 0, "a zero-width projectile cannot graze anything")
		t.isTrue(length > 0, "a zero-length projectile is not the arrow being drawn")

		for name, config in archetypes() do
			local halfWidth = math.min(config.hitboxSize.X, config.hitboxSize.Z) / 2

			t.isTrue(
				radius < halfWidth,
				`a projectile is wider than half of {name}, so near-misses would register`
			)
		end
	end)

	--[[
		A projectile that travels further between hit tests than its own
		length can pass clean through a target, because the overlap pass only
		sees what it touches when it runs. Arrows now outrun their length every
		frame — that is the footage's speed — so ProjectileFlight cuts each
		frame into sub-steps no longer than `maxStepTravel`, and that is the
		number held to the arrow here.

		Enemy shots are held per frame at 30fps as before: they are slow, and
		an orb is short.
	]]
	t.test("no projectile outruns its own length between hit tests", function()
		local step = 1 / 30
		local length = Balance.Projectile.length

		t.isTrue(
			Balance.Projectile.maxStepTravel < length / 2,
			"an arrow's sub-step reaches past its own nose"
		)

		for name, config in archetypes() do
			local shot = config.shot
			if shot then
				t.isTrue(
					shot.speed * step < length + Balance.Projectile.radius * 2,
					`{name} fires faster than its shot is long, so it can skip a target`
				)
			end
		end
	end)

	t.test("the player out-ranges nothing by accident", function()
		t.isTrue(Balance.Player.attackRange > 0)
		t.isTrue(Balance.Player.attackCooldown > 0)
		t.isTrue(
			Balance.Player.stationaryDelay < Balance.Player.attackCooldown,
			"settling must not cost more than a whole cooldown"
		)
		t.isTrue(
			Balance.Player.stationaryThreshold > 0 and Balance.Player.stationaryThreshold < 1,
			"the stationary threshold must sit between idle noise and a full stick"
		)
	end)

	--[[
		Turning, which is presentation but not decoration.

		Every enemy used to snap to face the player every frame, and on the
		Bulwark — whose shield is wider than its body — that made the whole
		slab swing in step with the player and read as it copying them. A turn
		rate fixes that, and the relationship worth holding is the one that
		makes weight legible: nothing bigger turns faster than something
		smaller.
	]]
	t.test("every enemy turns, and none instantly", function()
		for _, value in Balance.Enemies do
			local config = value :: Balance.EnemyConfig
			t.isTrue(config.turnRate > 0, `{config.displayName} cannot turn at all`)
			--[[ At 60 frames, anything over about 1800 a second is a snap. ]]
			t.isTrue(config.turnRate < 1800, `{config.displayName} effectively snaps to face`)
		end
	end)

	t.test("bigger enemies never turn faster than smaller ones", function()
		local list: { Balance.EnemyConfig } = {}
		for _, value in Balance.Enemies do
			table.insert(list, value :: Balance.EnemyConfig)
		end

		for _, a in list do
			for _, b in list do
				local aSize = math.max(a.hitboxSize.X, a.hitboxSize.Z)
				local bSize = math.max(b.hitboxSize.X, b.hitboxSize.Z)
				if aSize > bSize then
					t.isTrue(
						a.turnRate <= b.turnRate,
						`{a.displayName} is bigger than {b.displayName} but turns faster`
					)
				end
			end
		end
	end)

	--[[
		Relationships the move to Archero 2's proportions created.

		Most numbers scaled together with the room and kept their ratios for
		free. These are the ones that sit between room-sized and body-sized,
		where scaling one side and not the other could quietly produce a
		shape that cannot work.
	]]

	--[[ The Lurker's surface marker is a promise the player can keep: it has
	     to be wider than the Lurker, or stepping to its edge is enough, and
	     narrow enough to walk out of from its centre inside the warning, or
	     the counterplay is impossible. Slowing the player to the new pace
	     made the second half of that genuinely tight. ]]
	t.test("the Lurker's warning can be walked out of in time", function()
		local lurker = (Balance.Enemies :: any).Burrower :: Balance.EnemyConfig
		local burrow = lurker.burrow :: Balance.EnemyBurrow
		local radius = Balance.Telegraph.groundRadius
		local body = math.max(lurker.hitboxSize.X, lurker.hitboxSize.Z) / 2
		local reach = Balance.Player.moveSpeed * burrow.surfaceTell

		t.isTrue(radius > body, `a {radius}-stud marker is no wider than the {body}-stud Lurker`)
		t.isTrue(
			radius <= reach,
			`a {radius}-stud marker cannot be walked out of in {burrow.surfaceTell}s at {Balance.Player.moveSpeed} studs/s`
		)
	end)

	--[[ It surfaces beside the player, not inside them. ]]
	t.test("the Lurker surfaces outside the player's body", function()
		local lurker = (Balance.Enemies :: any).Burrower :: Balance.EnemyConfig
		local burrow = lurker.burrow :: Balance.EnemyBurrow
		local body = math.max(lurker.hitboxSize.X, lurker.hitboxSize.Z) / 2
		--[[ A Roblox character is about two studs across. ]]
		t.isTrue(burrow.surfaceDistance > body + 1, "the Lurker would surface inside the player")
	end)

	t.test("an arrival marker is bigger than what it marks", function()
		t.isTrue(Balance.Telegraph.spawnMarkerScale > 1, "a spawn marker hides under its own enemy")
	end)

	--[[ A wave whose last marker is still counting down long after the first
	     enemy has arrived reads as two waves, not one. ]]
	t.test("a whole wave arrives inside a couple of seconds", function()
		local largest = 0
		for _, room in Balance.Rooms do
			largest = math.max(largest, room.enemyCount)
		end

		local last = Balance.Spawning.arrivalTell + Balance.Spawning.arrivalStagger * (largest - 1)
		t.isTrue(last < 2.5, `the last of a {largest}-enemy wave takes {last}s to arrive`)
	end)

	--[[ The camera fits a band wider than the floor so the walls show. The
	     footage measured the floor at 85% of the screen's width; the owner
	     zoomed ours out past that twice (to 78%, then 67%). Far below two
	     thirds it stops reading as a room seen up close, and the characters
	     shrink to specks on a phone. ]]
	t.test("the camera frames the room the way the footage does", function()
		local share = Balance.Arena.size.X / Balance.Camera.fitWidth
		t.isTrue(share < 1, "the camera crops the room's own walls")
		t.isTrue(share > 0.65, `the floor fills only {share * 100}% of the screen width`)
		t.isTrue(share < 0.95, `the floor fills {share * 100}% — the walls have no room`)
	end)

	--[[ Archero's rooms are taller than wide; ours have to be too, or the
	     vertical-follow camera has nothing to follow. ]]
	t.test("rooms are taller than they are wide", function()
		t.isTrue(
			Balance.Arena.size.Z > Balance.Arena.size.X * 1.3,
			"the room is not portrait-shaped"
		)
	end)

	--[[ Everything must fit the room it is in. Spawn and exit sit inside the
	     floor, and the exclusion around the player must leave somewhere to
	     spawn. ]]
	t.test("the room's fixtures sit inside the room", function()
		local halfX, halfZ = Balance.Arena.size.X / 2, Balance.Arena.size.Z / 2
		local spawn = Balance.Arena.spawnPosition
		local door = Balance.Run.doorOffset

		t.isTrue(
			math.abs(spawn.X) < halfX and math.abs(spawn.Z) < halfZ,
			"the player spawns outside"
		)
		t.isTrue(math.abs(door.X) < halfX and math.abs(door.Y) < halfZ, "the exit is outside")

		local farthest =
			math.sqrt((halfX + math.abs(spawn.X)) ^ 2 + (halfZ + math.abs(spawn.Z)) ^ 2)
		t.isTrue(
			Balance.Spawning.minSpawnDistance < farthest * 0.6,
			"the spawn exclusion leaves almost nowhere to spawn"
		)
	end)

	--[[
		The archer only targets what its arrows can reach.

		Two playtests apart, this was broken in both directions: arrows
		dying short of a longer room while the archer kept firing at targets
		out of reach, then arrows flying far past everything. The two numbers
		are tuned separately, so the relationship has to be held here or it
		drifts the next time either one moves.
	]]
	--[[ Multishot's last repeat has to leave before the next volley does,
	     at the fastest fire rate Momentum allows, or the volleys overlap and
	     the repeats stop reading as one attack. ]]
	t.test("Multishot finishes before the next volley at full Momentum", function()
		local counts = { Momentum = #Abilities.byId.Momentum.levels }
		local stats = AbilityEffects.serverStats(counts)
		local fastest = AbilityEffects.cooldownAt(stats.attackCooldown, stats.momentumBonus, 99, 0)
		local multishot = Abilities.byId.Multishot.levels
		local lastRepeat = Balance.Projectile.multishotInterval * multishot[#multishot]

		t.isTrue(
			lastRepeat < fastest,
			`Multishot's last repeat leaves at {lastRepeat}s, after the next volley at {fastest}s`
		)
	end)

	--[[ Blaze is a bonus on a hit, never a second weapon: a whole burn at
	     full stacks has to be worth less than the hit that lit it. And a burn
	     must last long enough to tick at all. ]]
	t.test("a whole burn is worth less than the hit that lit it", function()
		local levels = Abilities.byId.Blaze.levels
		local perHit = Balance.Burn.rate * levels[#levels]

		t.isTrue(perHit < 1, `a full-level burn deals {perHit}x the arrow that lit it`)
		t.isTrue(Balance.Burn.tick > 0, "a burn needs a positive tick")
		t.isTrue(Balance.Burn.tick <= levels[1], "a burn runs out before its first tick")
	end)

	--[[
		The damage scale's shape, from Archero 2: a grunt dies in about three
		hits and about four enemy hits kill the hero. Held as ranges so the
		numbers can be tuned, but not tuned back into a game where enemies
		soak a dozen arrows and the player shrugs off a dozen hits.
	]]
	--[[ A stage that names a room that is not there fails when it is
	     played, not when it is written. These catch that at test time. ]]
	t.test("every stage names a real mode and real rooms", function()
		t.notNil(Balance.Stages[Balance.stage], "the run plays a stage that does not exist")

		for index, stage in Balance.Stages do
			if stage.mode == "Rooms" then
				local rooms = stage.rooms
				t.isTrue(
					rooms ~= nil and #rooms > 0,
					`stage {index} is a Rooms stage with no rooms`
				)
				for _, room in rooms or ({} :: { number }) do
					t.notNil(
						Balance.Rooms[room],
						`stage {index} names room {room}, which does not exist`
					)
				end
			elseif stage.mode == "Waves" then
				t.notNil(Balance.Rooms[stage.arena or 0], `stage {index} has no arena`)
				t.isTrue((stage.waves or 0) >= 1, `stage {index} has no waves`)
			else
				t.isTrue(false, `stage {index} has an unknown mode`)
			end
		end
	end)

	--[[ A shove that resolves in one frame is invisible, which is what the
	     old instant knockback was; one that takes half a second reads as
	     the enemy drifting. The owner asked for an extreme shove — big
	     enough that a hit Charger is driven out of its own reach — so the
	     outer limit is only that nothing is flung across a fifth of the room
	     by one hit. ]]
	t.test("knockback is a visible slide, not a jump, a drift or a fling", function()
		local slideTime = Balance.Knockback.slideTime
		t.isTrue(slideTime > 1 / 30, "knockback resolves inside one frame, so it cannot be seen")
		t.isTrue(slideTime <= 0.3, `knockback takes {slideTime}s to settle and reads as drifting`)

		local limit = Balance.Arena.size.X / 5
		for name, config in archetypes() do
			t.isTrue(config.knockback >= 0, `{name} is pulled towards its attacker`)
			t.isTrue(config.knockback <= limit, `one hit flings a {name} {config.knockback} studs`)
		end
	end)

	t.test("a Charger dies in about three arrows", function()
		local hits = Balance.Enemies.MeleeCharger.health / Balance.Player.baseDamage
		t.isTrue(hits > 2 and hits <= 4, `a Charger takes {hits} plain hits`)
	end)

	t.test("nothing dies to one arrow, and nothing soaks a quiver", function()
		for name, config in archetypes() do
			local hits = config.health / Balance.Player.baseDamage
			t.isTrue(hits > 1, `{name} dies to a single arrow`)
			if not config.boss then
				t.isTrue(hits <= 15, `{name} takes {hits} arrows`)
			end
		end
	end)

	--[[ A boss is a fight of its own: tougher than anything else, but not a
	     wall of health nobody finishes. ]]
	t.test("a boss outlasts every grunt, within reason", function()
		local toughest = 0
		for _, config in archetypes() do
			if not config.boss then
				toughest = math.max(toughest, config.health)
			end
		end
		for name, config in archetypes() do
			if config.boss then
				t.isTrue(config.health > toughest * 2, `{name} is barely tougher than a grunt`)
				local hits = config.health / Balance.Player.baseDamage
				t.isTrue(hits <= 120, `{name} takes {hits} plain arrows`)
			end
		end
	end)

	t.test("enemy hits are lethal in a handful, never in one", function()
		local commonest = Balance.Enemies.MeleeCharger.attackDamage
		local survives = Balance.Player.maxHealth / commonest
		t.isTrue(survives >= 3 and survives <= 6, `the player survives {survives} Charger hits`)

		for name, config in archetypes() do
			t.isTrue(
				config.attackDamage < Balance.Player.maxHealth / 2,
				`one {name} hit takes half the player's health or more`
			)
		end
	end)

	t.test("an arrow reaches anything the archer will target", function()
		local reach = Balance.Projectile.speed * Balance.Projectile.lifetime
		t.isTrue(
			reach >= Balance.Player.attackRange,
			`arrows fly {reach} studs but the archer targets out to {Balance.Player.attackRange}`
		)
	end)

	--[[ And not absurdly further: past this the arrow is mostly flying after
	     the fight it was fired into, which is what read as "too far". ]]
	t.test("an arrow does not fly far beyond its targeting range", function()
		local reach = Balance.Projectile.speed * Balance.Projectile.lifetime
		t.isTrue(
			reach <= Balance.Player.attackRange * 1.25,
			`arrows fly {reach} studs, well past the {Balance.Player.attackRange}-stud targeting range`
		)
	end)

	--[[ Player arrows fly at one height, low, for every enemy: each hitbox
	     sits on the floor, so the arrow's whole width must fit inside the
	     shortest one, or a squat enemy is shot over. ]]
	t.test("arrows fly through every enemy's hitbox height", function()
		local height = Balance.Projectile.height
		local radius = Balance.Projectile.radius
		t.isTrue(height - radius >= 0, "arrows fly through the floor")
		for _, value in Balance.Enemies do
			local config = value :: Balance.EnemyConfig
			t.isTrue(
				height + radius <= config.hitboxSize.Y,
				`arrows at {height} pass over the {config.displayName}'s {config.hitboxSize.Y}-stud hitbox`
			)
		end
	end)

	--[[ A stage's difficulty multipliers ease or harden it; zero or less
	     would make enemies unkillable or harmless, a typo, not a setting. ]]
	t.test("every stage's enemy multipliers are positive", function()
		for index, stage in Balance.Stages do
			t.isTrue((stage.enemyDamage or 1) > 0, `stage {index} has no enemy damage`)
			t.isTrue((stage.enemyHealth or 1) > 0, `stage {index} has no enemy health`)
		end
	end)
end
