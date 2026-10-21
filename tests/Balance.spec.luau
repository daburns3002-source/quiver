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
			t.isTrue(config.moveSpeed > 0, `{name} needs positive move speed`)
			t.isTrue(config.attackRange > 0, `{name} needs positive attack range`)
			t.isTrue(config.attackDamage > 0, `{name} needs positive damage`)
			t.isTrue(config.attackCooldown > 0, `{name} needs a positive cooldown`)
			t.isTrue(#config.displayName > 0, `{name} needs a display name`)
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
	t.test("projectiles have a width the server can cast with", function()
		local radius = Balance.Projectile.radius

		t.isTrue(radius > 0, "a zero-width projectile cannot graze anything")

		for name, config in archetypes() do
			local halfWidth = math.min(config.hitboxSize.X, config.hitboxSize.Z) / 2

			t.isTrue(
				radius < halfWidth,
				`a projectile is wider than half of {name}, so near-misses would register`
			)
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
end
