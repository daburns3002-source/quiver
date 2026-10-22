--!strict
--[[
	An enemy's body has to go where its hitbox goes.

	The body is welded to the hitbox, and a WeldConstraint only carries its
	other parts along when a part's CFrame is set. Setting Position moves the
	hitbox alone and re-welds the body at the new offset — which is how a
	knocked-back enemy's target ring slid away from a body that stayed put,
	and then stayed apart, so arrows struck an invisible box beside the
	visible enemy. These pin both halves: the engine behaviour the bug came
	from, and that moving by CFrame carries the body.

	Built well above the arena so nothing in a live run is disturbed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyModel = require(ServerScriptService.Server.Enemies.EnemyModel)
local TestRunner = require(script.Parent.TestRunner)

local PROBE = Vector3.new(0, 2200, 0)

--[[ How far a body part sits from its hitbox, in the hitbox's own space. ]]
local function offsetOf(hitbox: BasePart, part: BasePart): Vector3
	return hitbox.CFrame:PointToObjectSpace(part.Position)
end

local function build(): (Folder, BasePart, BasePart)
	local folder = Instance.new("Folder")
	folder.Name = "EnemyModelProbe"
	folder.Parent = Workspace

	local model, hitbox, skin = EnemyModel.build(Balance.Enemies.MeleeCharger, PROBE)
	model.Parent = folder

	-- Any visible body part will do; the first one is enough to follow.
	return folder, hitbox, skin.all[1]
end

return function(t: TestRunner.Helper)
	t.test("moving a hitbox by CFrame carries the body with it", function()
		local folder, hitbox, part = build()
		local before = offsetOf(hitbox, part)

		hitbox.CFrame = CFrame.new(PROBE + Vector3.new(4, 0, -3))
			* CFrame.Angles(0, math.rad(40), 0)
		task.wait()

		t.near((offsetOf(hitbox, part) - before).Magnitude, 0, 1e-3, "the body was left behind")
		folder:Destroy()
	end)

	--[[ The trap itself. If this ever stops failing to carry the body, the
	     engine changed and the comment on `placeHitbox` is out of date — but
	     CFrame stays the safe way either way. ]]
	t.test("moving a hitbox by Position leaves the body behind", function()
		local folder, hitbox, part = build()
		local bodyBefore = part.Position

		hitbox.Position = PROBE + Vector3.new(4, 0, -3)
		task.wait()

		t.near(
			(part.Position - bodyBefore).Magnitude,
			0,
			1e-3,
			"the body followed a Position write"
		)
		folder:Destroy()
	end)
end
