--!strict
--[[
	Where the archer aims, against a real pillar.

	The playtest that changed this rule showed a beetle half out from behind
	a pillar, in plain view, and every arrow landing in the stone beside it.
	These rebuild that: a pillar, an archer below it, and enemies placed
	behind it, beside it and clear of it. Built far from the arena so a live
	run is not touched.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Aim = require(ReplicatedStorage.Shared.Combat.Aim)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local TestRunner = require(script.Parent.TestRunner)

local BASE = Vector3.new(0, 2600, 0)

local function scene(): (Folder, (Vector3, Vector3) -> boolean)
	local folder = Instance.new("Folder")
	folder.Name = "AimProbe"
	local pillar = Instance.new("Part")
	pillar.Anchored = true
	pillar.Size = Vector3.new(4, 8, 4)
	pillar.Position = BASE + Vector3.new(0, 0, -10)
	pillar.Parent = folder
	folder.Parent = Workspace
	return folder, Aim.clearTest(folder, Balance.Projectile.radius)
end

local function candidate(model: Model, offset: Vector3): Aim.Candidate
	return { model = model, position = BASE + offset, halfWidth = 1.5 }
end

return function(t: TestRunner.Helper)
	local archer = BASE

	t.test("an enemy in the open is shot at its centre", function()
		local folder, clear = scene()
		local m = Instance.new("Model")
		local choice = Aim.choose(archer, { candidate(m, Vector3.new(8, 0, -16)) }, 50, clear)
		t.notNil(choice)
		t.isTrue((choice :: Aim.Choice).clear)
		t.near(
			((choice :: Aim.Choice).aimPoint - (BASE + Vector3.new(8, 0, -16))).Magnitude,
			0,
			1e-6
		)
		folder:Destroy()
	end)

	--[[ The playtest's case: centre behind the pillar's edge, one side of the
	     body showing. The archer must aim at the side that shows. ]]
	t.test("a half-hidden enemy is shot in the half that shows", function()
		local folder, clear = scene()
		local m = Instance.new("Model")
		--[[ Behind and just right of the pillar (which spans x −2..2): the
		     line to its centre clips the pillar's corner, the line to its
		     outer edge does not. ]]
		local enemy = candidate(m, Vector3.new(4, 0, -16))
		t.isFalse(clear(archer, enemy.position), "the scene is wrong: the centre is visible")
		local choice = Aim.choose(archer, { enemy }, 50, clear) :: Aim.Choice
		t.notNil(choice)
		t.isTrue(choice.clear, "no clear line found to a half-visible enemy")
		t.isTrue(clear(archer, choice.aimPoint), "the chosen line is blocked")
		t.isTrue(choice.aimPoint.X > enemy.position.X, "aimed at the hidden side")
		folder:Destroy()
	end)

	t.test("a visible enemy beats a nearer one that is fully hidden", function()
		local folder, clear = scene()
		local hidden, visible = Instance.new("Model"), Instance.new("Model")
		local choice = Aim.choose(archer, {
			candidate(hidden, Vector3.new(0, 0, -15)),
			candidate(visible, Vector3.new(10, 0, -18)),
		}, 50, clear) :: Aim.Choice
		t.equal(choice.model, visible)
		folder:Destroy()
	end)

	t.test("with nothing in the open, the nearest is still the target", function()
		local folder, clear = scene()
		local near, far = Instance.new("Model"), Instance.new("Model")
		local choice = Aim.choose(archer, {
			candidate(near, Vector3.new(0, 0, -15)),
			candidate(far, Vector3.new(0, 0, -20)),
		}, 50, clear) :: Aim.Choice
		t.equal(choice.model, near)
		t.isFalse(choice.clear)
		folder:Destroy()
	end)

	t.test("nothing in range, no target", function()
		local m = Instance.new("Model")
		t.isNil(Aim.choose(archer, { candidate(m, Vector3.new(0, 0, -90)) }, 50, function()
			return true
		end))
	end)

	t.test("edge aim stays on the body", function()
		t.isTrue(Aim.EDGE_SHARE > 0 and Aim.EDGE_SHARE < 1)
	end)
end
