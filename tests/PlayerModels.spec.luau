--!strict
--[[
	The class bodies (`Config/PlayerModels`, worn by `Run/PlayerBody`): one
	per class and look on the class select screen, each a whole R15 rig whose
	joints sit where its parts meet, standing on the ground, and either fully
	uploaded or waiting with no ids at all.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassSelectAssets = require(ReplicatedStorage.Shared.Config.ClassSelectAssets)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local PlayerModelSpec = require(ReplicatedStorage.Shared.Util.PlayerModelSpec)
local TestRunner = require(script.Parent.TestRunner)

local function vec(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

return function(t: TestRunner.Helper)
	t.test("every class and look on the class screen has a body", function()
		for _, section in ClassSelectAssets.sections do
			local key = PlayerModelSpec.key(section.class, section.look)
			local spec = PlayerModelSpec.get(key)
			t.notNil(spec, `no body for {key}`)
			if spec then
				t.equal(spec.class, section.class, `{key}'s class`)
				t.equal(spec.look, section.look, `{key}'s look`)
			end
		end
	end)

	t.test("every playable class has both looks", function()
		for class in Classes do
			for _, look in { "male", "female" } do
				t.notNil(PlayerModelSpec.get(PlayerModelSpec.key(class, look)), `{class} {look}`)
			end
		end
	end)

	t.test("each body has the 15 R15 parts and every joint", function()
		for key, spec in PlayerModelSpec.all() do
			for _, name in PlayerModelSpec.R15 do
				t.notNil(PlayerModelSpec.part(spec, name), `{key} has no {name}`)
			end
			t.equal(#spec.parts, 15, `{key}'s part count`)
			for joint in PlayerModelSpec.JOINTS do
				t.notNil(spec.joints[joint], `{key} has no {joint} joint`)
			end
			for _, piece in spec.accessories do
				t.notNil(
					PlayerModelSpec.part(spec, piece.parent or ""),
					`{key}'s {piece.name} hangs off nothing`
				)
			end
		end
	end)

	--[[ A joint inside neither part would swing a limb about a point in the
	     air: each sits within reach of both parts it joins. ]]
	t.test("each joint sits where its two parts meet", function()
		for key, spec in PlayerModelSpec.all() do
			for joint, pair in PlayerModelSpec.JOINTS do
				local at = vec(spec.joints[joint])
				for _, name in pair do
					if name == "HumanoidRootPart" then
						continue
					end
					local piece = PlayerModelSpec.part(spec, name) :: PlayerModelSpec.Piece
					local half = vec(piece.size) / 2 + Vector3.new(0.35, 0.35, 0.35)
					local d = at - vec(piece.position)
					t.isTrue(
						math.abs(d.X) <= half.X
							and math.abs(d.Y) <= half.Y
							and math.abs(d.Z) <= half.Z,
						`{key}'s {joint} is away from its {name}`
					)
				end
			end
		end
	end)

	t.test("each body stands on the ground at about a default body's height", function()
		for key, spec in PlayerModelSpec.all() do
			local lowest = math.huge
			for _, piece in spec.parts do
				lowest = math.min(lowest, piece.position[2] - piece.size[2] / 2)
			end
			-- the root's centre is HipHeight plus half the 2-stud root above the ground
			t.isTrue(
				math.abs(lowest + spec.hipHeight + 1) < 0.05,
				`{key}'s feet are off the ground`
			)
			t.isTrue(spec.height > 4.5 and spec.height < 6.5, `{key} is {spec.height} studs tall`)
		end
	end)

	t.test("a body is uploaded whole or not at all", function()
		for key, spec in PlayerModelSpec.all() do
			for _, piece in PlayerModelSpec.pieces(spec) do
				if spec.uploaded then
					t.isTrue(
						string.match(piece.meshId, "^rbxassetid://%d+$") ~= nil,
						`{key}'s {piece.name} mesh`
					)
				else
					t.equal(
						piece.meshId,
						"",
						`{key}'s {piece.name} has an id before its body is uploaded`
					)
				end
			end
		end
	end)
end
