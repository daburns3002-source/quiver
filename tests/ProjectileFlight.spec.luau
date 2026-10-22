--!strict
--[[
	The flight both halves of the game share.

	`ProjectileFlight` exists because the client once drew a simpler flight
	than the server simulated: every drawn arrow stopped at the first thing it
	touched, so Bouncy Wall and Piercing Shot happened only where nobody could
	see them. These pin the behaviours that drift hid — bounce, pierce, the
	body a ricochet leaves from — plus the one the footage's speed puts at risk,
	an arrow that covers several of its own lengths in a frame.

	Real geometry, well above the arena, because what is under test is what
	the engine's casts report.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local ProjectileFlight = require(ReplicatedStorage.Shared.Combat.ProjectileFlight)
local TestRunner = require(script.Parent.TestRunner)

local PROBE_HEIGHT = 2100

type Rig = {
	params: RaycastParams,
	overlap: OverlapParams,
	wall: (z: number) -> BasePart,
	body: (z: number) -> Model,
	destroy: () -> (),
}

local function rig(): Rig
	local folder = Instance.new("Folder")
	folder.Name = "ProjectileFlightProbe"
	folder.Parent = Workspace

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { folder }

	local function part(z: number, size: Vector3): Part
		local p = Instance.new("Part")
		p.Size = size
		p.Position = Vector3.new(0, PROBE_HEIGHT, z)
		p.Anchored = true
		p.CanCollide = false
		return p
	end

	return {
		params = params,
		overlap = overlap,
		--[[ Arena geometry: a part with no Model above it. ]]
		wall = function(z: number): BasePart
			local p = part(z, Vector3.new(20, 6, 1))
			p.Parent = folder
			return p
		end,
		--[[ An enemy: a part inside a Model. ]]
		body = function(z: number): Model
			local model = Instance.new("Model")
			part(z, Vector3.new(2, 4, 2)).Parent = model
			model.Parent = folder
			return model
		end,
		destroy = function()
			folder:Destroy()
		end,
	}
end

local function flight(z: number, speed: number): ProjectileFlight.Flight
	return {
		faction = "Player",
		position = Vector3.new(0, PROBE_HEIGHT, z),
		direction = Vector3.new(0, 0, 1),
		speed = speed,
		pierce = 0,
		bounces = 0,
		homing = 0,
		hitModels = {},
	}
end

--[[ Counts what the flight struck, in order, and counts every contact. ]]
local function recorder(): (ProjectileFlight.Contact, { Model }, { boolean })
	local struck: { Model } = {}
	local walls: { boolean } = {}

	return {
		onModel = function(_f: ProjectileFlight.Flight, model: Model): boolean
			table.insert(struck, model)
			return true
		end,
		onWall = function(_f: ProjectileFlight.Flight, _p: Vector3, _n: Vector3, bounced: boolean)
			table.insert(walls, bounced)
		end,
	},
		struck,
		walls
end

--[[ Advances in fixed frames until the flight dies or `frames` run out. ]]
local function fly(
	f: ProjectileFlight.Flight,
	r: Rig,
	contact: ProjectileFlight.Contact,
	frames: number,
	dt: number
): boolean
	for _ = 1, frames do
		if not ProjectileFlight.advance(f, dt, r.params, r.overlap, contact) then
			return false
		end
	end
	return true
end

return function(t: TestRunner.Helper)
	t.test("an arrow with no bounces stops at a wall", function()
		local r = rig()
		r.wall(10)
		local contact, _, walls = recorder()

		local f = flight(0, 20)
		t.isFalse(fly(f, r, contact, 60, 1 / 60), "the arrow flew through the wall")
		t.equal(#walls, 1)
		t.isFalse(walls[1], "a bounceless arrow reported a bounce")

		r.destroy()
	end)

	t.test("a bouncing arrow comes back off the wall and spends the bounce", function()
		local r = rig()
		r.wall(10)
		local contact, _, walls = recorder()

		local f = flight(0, 20)
		f.bounces = 1
		fly(f, r, contact, 30, 1 / 60)

		t.equal(#walls, 1, "the arrow did not reach the wall")
		t.isTrue(walls[1], "the wall did not bounce it")
		t.isTrue(f.direction.Z < -0.99, "the arrow is not heading back the way it came")
		t.isTrue(f.position.Z < 10, "the arrow is through the wall")
		t.equal(f.bounces, 0)

		r.destroy()
	end)

	t.test("pierce passes one body and stops in the next", function()
		local r = rig()
		local first = r.body(6)
		local second = r.body(12)
		local contact, struck = recorder()

		local f = flight(0, 20)
		f.pierce = 1
		t.isFalse(fly(f, r, contact, 60, 1 / 60), "the arrow outlived its pierce")

		t.equal(#struck, 2)
		t.equal(struck[1], first)
		t.equal(struck[2], second)

		r.destroy()
	end)

	t.test("no pierce stops in the first body", function()
		local r = rig()
		r.body(6)
		r.body(12)
		local contact, struck = recorder()

		t.isFalse(fly(flight(0, 20), r, contact, 60, 1 / 60))
		t.equal(#struck, 1, "a plain arrow went through an enemy")

		r.destroy()
	end)

	--[[ "Make the projectiles stop when they hit the hitbox." The arrow used
	     to be left with its centre on the contact point, half its length
	     inside the body. Its nose belongs on the surface — the body here is
	     two studs deep at z = 6, so its near face is z = 5. At footage speed,
	     so a whole frame's travel is in play. ]]
	t.test("an arrow stops with its tip on the hitbox, not inside it", function()
		local r = rig()
		r.body(6)
		local contact = recorder()

		local f = flight(0, Balance.Projectile.speed)
		t.isFalse(fly(f, r, contact, 10, 1 / 60), "the arrow never stopped")

		local nose = f.position.Z + Balance.Projectile.length / 2
		t.near(nose, 5, 0.05, `the arrow stopped with its tip at z = {nose}, not on the face at 5`)

		r.destroy()
	end)

	--[[ Tracking Eye. A body beside the line of flight: a straight arrow
	     passes it, a homing one curves in. The same body *behind* the arrow
	     must not turn it round. ]]
	t.test("a homing arrow curves onto a body beside its path", function()
		local r = rig()
		local aside = r.body(12)
		aside:PivotTo(CFrame.new(4, PROBE_HEIGHT, 12))

		local function seek(f: ProjectileFlight.Flight): Vector3?
			return ProjectileFlight.seekAhead(f, { [aside] = aside:GetPivot().Position })
		end

		local plain = flight(0, 20)
		local plainContact, plainHits = recorder()
		plainContact.seek = seek
		fly(plain, r, plainContact, 60, 1 / 60)
		t.equal(#plainHits, 0, "a straight arrow hit a body four studs off its line")

		local homing = flight(0, 20)
		homing.homing = math.rad(540)
		local homingContact, homingHits = recorder()
		homingContact.seek = seek
		fly(homing, r, homingContact, 60, 1 / 60)
		t.equal(#homingHits, 1, "a homing arrow did not curve onto the body")

		r.destroy()
	end)

	t.test("a homing arrow does not turn round for a body behind it", function()
		local r = rig()
		local behind = r.body(-6)
		local contact, struck = recorder()
		contact.seek = function(f: ProjectileFlight.Flight): Vector3?
			return ProjectileFlight.seekAhead(f, { [behind] = behind:GetPivot().Position })
		end

		local f = flight(0, 20)
		f.homing = math.rad(540)
		fly(f, r, contact, 30, 1 / 60)

		t.equal(#struck, 0, "the arrow turned round")
		t.isTrue(f.direction.Z > 0.99, "the arrow changed heading for a body behind it")

		r.destroy()
	end)

	--[[ A ricochet leaves from inside the enemy it bounced off. Without the
	     seed, the very first overlap pass strikes that enemy again and the
	     bounce dies where it started — on screen and on the server. ]]
	t.test("a flight ignores the body it starts inside when told to", function()
		local r = rig()
		local source = r.body(0)
		local target = r.body(10)
		local contact, struck = recorder()

		local f = flight(0, 20)
		f.hitModels[source] = true
		fly(f, r, contact, 60, 1 / 60)

		t.equal(#struck, 1)
		t.equal(struck[1], target, "the ricochet struck the enemy it left from")

		r.destroy()
	end)

	--[[ The footage's speed, at the worst frame rate the game tolerates. An
	     arrow covering more than its own length per frame is exactly what
	     sub-stepping is for. ]]
	t.test("a footage-speed arrow still lands on a body in its path", function()
		local r = rig()
		local target = r.body(5)
		local contact, struck = recorder()

		local f = flight(0, Balance.Projectile.speed)
		t.isTrue(
			Balance.Projectile.speed / 30 > Balance.Projectile.length,
			"arrows are slow enough that this test no longer exercises sub-steps"
		)
		fly(f, r, contact, 3, 1 / 30)

		t.equal(#struck, 1, "a fast arrow skipped a body in its path")
		t.equal(struck[1], target)

		r.destroy()
	end)

	--[[ And the moving-target case the overlap pass exists for, at speed: a
	     body that appears inside the arrow between frames. ]]
	t.test("a body that appears inside a fast arrow is struck", function()
		local r = rig()
		local f = flight(0, Balance.Projectile.speed)
		local contact, struck = recorder()

		r.body(0)
		ProjectileFlight.advance(f, 0, r.params, r.overlap, contact)

		t.equal(#struck, 1, "a body inside the arrow was not struck")

		r.destroy()
	end)
end
