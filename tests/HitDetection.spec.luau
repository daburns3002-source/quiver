--!strict
--[[
	The assumptions ProjectileSystem's hit detection rests on.

	Every one of these is a property of the *engine* or of the relationship
	between two balance numbers, not of our code — which is exactly why they
	are worth pinning. The four gates were green while player arrows passed
	through enemies, because nothing about that bug was expressible as a type,
	a lint or a build. It was a shape cast quietly declining to report a body
	it had already swallowed.

	If one of these fails, the fix is not to adjust the test. It is to go and
	look at whether ProjectileSystem still compensates for what it is telling
	you.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local TestRunner = require(script.Parent.TestRunner)

--[[ Well clear of the arena, so a test can never collide with a live run. ]]
local PROBE_HEIGHT = 2000

local function projectileSize(): Vector3
	local width = Balance.Projectile.radius * 2
	return Vector3.new(width, width, Balance.Projectile.length)
end

--[[ Builds an isolated target and hands back a cast helper plus a teardown.
     Include-filtered on its own folder, so nothing else in the place can
     answer and no other test can be disturbed by it. ]]
local function withTarget(size: Vector3): { [string]: any }
	local folder = Instance.new("Folder")
	folder.Name = "HitDetectionProbe"
	folder.Parent = Workspace

	local target = Instance.new("Part")
	target.Size = size
	target.Position = Vector3.new(0, PROBE_HEIGHT, 0)
	target.Anchored = true
	target.CanCollide = false
	target.Parent = folder

	local cast = RaycastParams.new()
	cast.FilterType = Enum.RaycastFilterType.Include
	cast.FilterDescendantsInstances = { folder }

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { folder }

	local function poseAt(z: number): CFrame
		local at = Vector3.new(0, PROBE_HEIGHT, z)
		return CFrame.lookAt(at, at + Vector3.new(0, 0, 1))
	end

	return {
		sweep = function(z: number, distance: number): RaycastResult?
			return Workspace:Blockcast(
				poseAt(z),
				projectileSize(),
				Vector3.new(0, 0, 1) * distance,
				cast
			)
		end,
		overlapping = function(z: number): number
			return #Workspace:GetPartBoundsInBox(poseAt(z), projectileSize(), overlap)
		end,
		destroy = function()
			folder:Destroy()
		end,
	}
end

return function(t: TestRunner.Helper)
	--[[ The most an arrow moves between hit tests: one frame at the
	     configured speed, or one sub-step once that is longer, since
	     ProjectileFlight cuts a long frame into sub-steps no longer than
	     `maxStepTravel`. ]]
	local frameTravel = math.min(Balance.Projectile.speed / 60, Balance.Projectile.maxStepTravel)
	local noseReach = Balance.Projectile.length / 2

	--[[
		The bug, stated as a test.

		A shape cast ignores anything it is already intersecting when it
		starts. The arrow's box is centred on the simulated point, so its
		forward half is a region the sweep cannot see into at all — and a
		target that gets in there stays there, because the box carries it.
	]]
	t.test("a sweep cannot see a target it already overlaps", function()
		local probe = withTarget(Vector3.new(4, 4, 4)) -- spans z = -2 to 2

		-- Box centred on the target: overlapping as completely as possible.
		t.isNil(probe.sweep(0, frameTravel), "a fully overlapped target was reported")

		-- Barely overlapping: the box's nose is 0.1 studs inside the target.
		t.isNil(probe.sweep(-(2 + noseReach - 0.1), frameTravel), "a grazed target was reported")

		probe.destroy()
	end)

	--[[ The other half of the same contract: once it is genuinely clear of the
	     box, the sweep does its job. Without this, the test above would also
	     pass if casting were broken outright. ]]
	t.test("a sweep does see a target it is clear of", function()
		local probe = withTarget(Vector3.new(4, 4, 4))

		local justClear = -(2 + noseReach + frameTravel / 2)
		t.notNil(probe.sweep(justClear, frameTravel), "a reachable target was missed")

		probe.destroy()
	end)

	--[[ And the pass that covers for it. This is what ProjectileSystem relies
	     on to land hits at all, so if bounds queries ever stop reporting an
	     enclosed body, hit detection silently reverts to the broken version. ]]
	t.test("an overlap query does see a target the sweep cannot", function()
		local probe = withTarget(Vector3.new(4, 4, 4))

		t.equal(probe.overlapping(0), 1, "an enclosed target was not reported")
		t.equal(probe.overlapping(-(2 + noseReach - 0.1)), 1, "a grazed target was not reported")
		t.equal(probe.overlapping(-(2 + noseReach + 1)), 0, "a target well clear was reported")

		probe.destroy()
	end)

	--[[
		A relationship, in the house style: retuning either number is fine,
		tuning them into a shape that cannot work is not.

		The overlap pass only sees what the arrow is touching on the frame it
		is asked. If the arrow travelled further in one frame than its own
		length, it could step clean over a target without ever touching it on
		a frame boundary, and the overlap pass would never fire — leaving only
		the sweep, which is the half that was already proven unreliable.
	]]
	t.test("an arrow cannot step clean over its own body in one frame", function()
		t.isTrue(
			frameTravel < Balance.Projectile.length,
			`an arrow travels {frameTravel} studs a frame but is only {Balance.Projectile.length} long`
		)
	end)

	--[[ The dead zone is why the overlap pass is not optional. If the arrow
	     ever gets short enough that its nose reach is under one frame of
	     travel, the sweep alone would very nearly suffice — and this test
	     failing is the signal to go and re-read that reasoning, not to delete
	     it. ]]
	t.test("the sweep's dead zone is big enough to matter", function()
		t.isTrue(
			noseReach > frameTravel,
			`a nose reach of {noseReach} studs is within one frame's travel of {frameTravel}`
		)
	end)

	--[[
		The same rule for enemy orbs, against the fastest enemy shot there is.

		An orb is far shorter than an arrow, so it has far less body to land a
		frame boundary inside. If the quickest enemy shot covers more than its
		own diameter in a frame it can step clean over a player between two
		frames, and the overlap pass — which only sees what the shot is
		touching *on* a frame — never fires.
	]]
	t.test("no enemy orb can step clean over its own body in one frame", function()
		local fastest = 0
		local fastestName = ""

		for _, value in Balance.Enemies do
			local config = value :: Balance.EnemyConfig
			local shot = config.shot
			if shot and shot.speed > fastest then
				fastest = shot.speed
				fastestName = config.displayName
			end
		end

		local perFrame = fastest / 60
		t.isTrue(
			perFrame < Balance.Projectile.enemyOrbDiameter,
			`{fastestName}'s orb travels {perFrame} studs a frame but is only {Balance.Projectile.enemyOrbDiameter} across`
		)
	end)
end
