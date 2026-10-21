--!strict
--[[
	Arena geometry.

	Every bug this file guards against is one that actually shipped. The
	charger deadlock was `resolve` returning a body to the same spot each
	frame; the jittering burrower was `deflectionNormal` naming a face the
	body was not against; the dive that went nowhere was obstacle resolution
	applying to something underground. None were visible to the type checker.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Arena = require(ServerScriptService.Server.Arena.Arena)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local TestRunner = require(script.Parent.TestRunner)

local RADIUS = 1.5

--[[
	Builds a known layout into a throwaway container.

	`Arena.build` writes module-level state — the obstacle boxes and the half
	extents — so the tests have to drive it rather than assume whatever the
	live room left behind. The folder is never parented to the DataModel.
]]
local function buildLayout(obstacles: { Balance.Obstacle })
	local scratch = Instance.new("Folder")
	Arena.build(scratch, obstacles)
	return scratch
end

return function(t: TestRunner.Helper)
	local centrePillar: { Balance.Obstacle } = {
		{ offset = Vector2.new(0, 0), size = Vector3.new(6, 10, 6) },
	}

	--[[ A point well inside the floor and well clear of the centre pillar,
	     derived from the arena rather than written as a number — these used
	     hard-coded coordinates that were only inside the room while it was
	     ninety studs square. ]]
	local function insideFloor(fractionX: number, fractionZ: number): Vector3
		local size = Balance.Arena.size
		return Vector3.new(size.X / 2 * fractionX, 2.5, size.Z / 2 * fractionZ)
	end

	t.test("resolve leaves a clear point untouched", function()
		buildLayout(centrePillar)

		local clear = insideFloor(0.6, 0.6)
		local resolved = Arena.resolve(clear, RADIUS)

		t.near((resolved - clear).Magnitude, 0, 1e-4)
	end)

	t.test("resolve pushes a point out of an obstacle", function()
		buildLayout(centrePillar)

		-- Dead centre of the pillar: it must not stay there.
		local inside = Vector3.new(0, 2.5, 0)
		local resolved = Arena.resolve(inside, RADIUS)

		t.isTrue(Arena.isClear(resolved, RADIUS), "resolved point should be clear")
	end)

	t.test("resolve keeps a point inside the outer walls", function()
		buildLayout({})

		local outside = Vector3.new(500, 2.5, -500)
		local resolved = Arena.resolve(outside, RADIUS)

		--[[ Each axis against its own half-extent. This compared Z with the
		     arena's *width*, which only passed while the room was square. ]]
		t.isTrue(
			math.abs(resolved.X) <= Balance.Arena.size.X / 2,
			"X should be clamped inside the arena"
		)
		t.isTrue(
			math.abs(resolved.Z) <= Balance.Arena.size.Z / 2,
			"Z should be clamped inside the arena"
		)
	end)

	t.test("clampToWalls ignores obstacles but still bounds the arena", function()
		buildLayout(centrePillar)

		-- Straight through the middle of the pillar: underground, that is fine.
		local insidePillar = Vector3.new(0, 2.5, 0)
		local clamped = Arena.clampToWalls(insidePillar, RADIUS)

		t.near((clamped - insidePillar).Magnitude, 0, 1e-4, "obstacles must not apply")

		local farOutside = Arena.clampToWalls(Vector3.new(900, 2.5, 0), RADIUS)
		t.isTrue(math.abs(farOutside.X) <= Balance.Arena.size.X / 2, "walls must still apply")
	end)

	--[[
		The regression that mattered most. A body flush against the pillar's
		east face probes into the span of its *north* face, so a normal taken
		at the probe pointed the tangent straight back into the pillar and the
		enemy was shoved to the same spot every frame.
	]]
	t.test("deflectionNormal reports the face the body is against, not the probe", function()
		buildLayout({
			{ offset = Vector2.new(22, -18), size = Vector3.new(6, 10, 14) },
		})

		-- Flush against the east face, heading north-west past the corner.
		local body = Vector3.new(26.5, 2.5, -13.1)
		local heading = Vector3.new(-0.456, 0, 0.89).Unit
		local probe = body + heading * (RADIUS + 1.25)

		local normal = Arena.deflectionNormal(body, probe, RADIUS)

		t.notNil(normal, "the probe should be blocked")
		t.near((normal :: Vector3).X, 1, 1e-6, "normal should point out of the east face")
		t.near((normal :: Vector3).Z, 0, 1e-6)
	end)

	t.test("deflectionNormal yields a tangent that does not re-enter the obstacle", function()
		buildLayout(centrePillar)

		local body = Vector3.new(0, 2.5, -7.1)
		local heading = Vector3.new(0, 0, 1)
		local probe = body + heading * (RADIUS + 1.25)
		local normal = Arena.deflectionNormal(body, probe, RADIUS)

		t.notNil(normal, "approaching the pillar head on should be blocked")

		local n = normal :: Vector3
		local tangent = Vector3.new(-n.Z, 0, n.X)
		if tangent:Dot(heading) < 0 then
			tangent = -tangent
		end

		-- One step along the tangent must survive resolve, or the body is
		-- being pushed straight back and nothing ever moves.
		local stepped = body + tangent * 0.15
		local resolved = Arena.resolve(stepped, RADIUS)

		t.near((resolved - stepped).Magnitude, 0, 1e-4, "the tangent step should not be undone")
	end)

	t.test("deflectionNormal is nil when the path ahead is clear", function()
		buildLayout(centrePillar)

		local body = Vector3.new(35, 2.5, 35)
		local probe = body + Vector3.new(1, 0, 0) * (RADIUS + 1.25)

		t.isNil(Arena.deflectionNormal(body, probe, RADIUS))
	end)

	t.test("isAtDoor only accepts points on the pad", function()
		buildLayout({})

		local door = Balance.Run.doorOffset

		t.isTrue(Arena.isAtDoor(Vector3.new(door.X, 4, door.Y)), "the pad centre counts")
		t.isFalse(
			Arena.isAtDoor(Vector3.new(door.X, 4, door.Y + Balance.Run.doorRadius + 5)),
			"well past the pad does not"
		)
	end)

	t.test("an empty layout leaves the whole floor clear", function()
		buildLayout({})

		t.isTrue(Arena.isClear(Vector3.new(0, 2.5, 0), RADIUS))
		t.isTrue(Arena.isClear(insideFloor(0.7, -0.7), RADIUS))
	end)
end
