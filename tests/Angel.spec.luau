--!strict
--[[
	The Angel's body against its sheet
	(`assets/concepts/blocky/encounters/angel/angel_views.png`, owner
	approved 2026-11-02: "ok i like it build the model").

	Relationships rather than coordinates, so moving a block never fails
	this but losing the shape does. What the sheet actually says, and what
	`Config/AngelDesign` must keep saying: it floats with no legs, the halo
	is a flat ring of four bars clear above the head, each wing steps
	outward and up in three shrinking blocks, the hem is wider than the
	torso, the eyes are two flat marks on the face, and the only colours are
	cream, gold and the dark of a closed eye.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AngelDesign = require(ReplicatedStorage.Shared.Config.AngelDesign)
local TestRunner = require(script.Parent.TestRunner)

local function byName(): { [string]: AngelDesign.Part }
	local out: { [string]: AngelDesign.Part } = {}
	for _, part in AngelDesign.parts do
		out[part.name] = part
	end
	return out
end

--[[ The lowest and highest point of a part. ]]
local function bottom(part: AngelDesign.Part): number
	return part.offset.Y - part.size.Y / 2
end

local function top(part: AngelDesign.Part): number
	return part.offset.Y + part.size.Y / 2
end

return function(t: TestRunner.Helper)
	t.test("every block has a name of its own, a size and a colour", function()
		local seen: { [string]: boolean } = {}
		t.isTrue(#AngelDesign.parts > 0, "the Angel has a body")
		for _, part in AngelDesign.parts do
			t.isFalse(seen[part.name] == true, `two blocks are called {part.name}`)
			seen[part.name] = true
			t.isTrue(part.size.X > 0 and part.size.Y > 0 and part.size.Z > 0, part.name)
		end
	end)

	--[[ The sheet's palette and no other: anything else means a block was
	     added without looking at it. ]]
	t.test("only the sheet's three colours are used", function()
		for _, part in AngelDesign.parts do
			local known = part.color == AngelDesign.cream
				or part.color == AngelDesign.gold
				or part.color == AngelDesign.eye
			t.isTrue(known, `{part.name} is a colour the sheet does not have`)
		end
	end)

	--[[ It floats. No legs, no feet, and nothing of the body touching the
	     floor: only the pool of light it casts is down there. ]]
	t.test("the Angel hovers, and nothing of it reaches the ground", function()
		for _, part in AngelDesign.parts do
			if part.grounded then
				continue
			end
			t.isTrue(
				bottom(part) >= AngelDesign.hover - 1e-6,
				`{part.name} hangs down to {bottom(part)}, under the {AngelDesign.hover} it floats at`
			)
			t.isFalse(
				string.find(string.lower(part.name), "leg") ~= nil
					or string.find(string.lower(part.name), "foot") ~= nil,
				`{part.name}: the Angel has no legs`
			)
		end

		--[[ And it really is the hem that floats at that height, not some
		     part further up: the figure sits exactly where the sheet puts
		     it. ]]
		local lowest = math.huge
		for _, part in AngelDesign.parts do
			if not part.grounded then
				lowest = math.min(lowest, bottom(part))
			end
		end
		t.near(lowest, AngelDesign.hover, 1e-6, "the lowest block of the body")
	end)

	t.test("the bob never dips the Angel onto the floor", function()
		t.isTrue(AngelDesign.bob > 0, "it bobs at all")
		t.isTrue(
			AngelDesign.bob < AngelDesign.hover,
			"the bob rises from where it floats and never sinks through the ground"
		)
		t.isTrue(AngelDesign.bobSeconds > 1, "the bob is slow enough to read as hovering")
	end)

	t.test("the halo is four gold bars, flat and level, clear above the head", function()
		local parts = byName()
		local head = parts.Head
		t.notNil(head, "there is a head")
		local bars = { "HaloFront", "HaloBack", "HaloLeft", "HaloRight" }
		local height: number? = nil
		for _, name in bars do
			local bar = parts[name]
			t.notNil(bar, `the halo is missing {name}`)
			if bar and head then
				t.equal(bar.color, AngelDesign.gold, name)
				--[[ Clear above the head, not resting on it. ]]
				t.isTrue(bottom(bar) > top(head), `{name} is not clear of the head`)
				--[[ Flat: a bar is far wider than it is tall. ]]
				t.isTrue(
					math.max(bar.size.X, bar.size.Z) > bar.size.Y * 4,
					`{name} is not a flat bar`
				)
				--[[ Level: every bar at the same height. ]]
				if height then
					t.near(bar.offset.Y, height, 1e-6, `{name} is not level with the others`)
				end
				height = bar.offset.Y
			end
		end
	end)

	t.test("each wing is three blocks stepping outward and up, getting smaller", function()
		local parts = byName()
		for _, side in { "Left", "Right" } do
			local last: AngelDesign.Part? = nil
			for step = 1, 3 do
				local name = `Wing{side}{step}`
				local part = parts[name]
				t.notNil(part, `{name} is missing`)
				if part and last then
					t.isTrue(
						math.abs(part.offset.X) > math.abs(last.offset.X),
						`{name} does not step outward`
					)
					t.isTrue(part.offset.Y > last.offset.Y, `{name} does not step up`)
					t.isTrue(part.size.Y < last.size.Y, `{name} is not smaller than the one before`)
				end
				last = part
			end
		end

		--[[ Mirrored: the two wings are the same wing, one each side. ]]
		for step = 1, 3 do
			local left, right = parts[`WingLeft{step}`], parts[`WingRight{step}`]
			if left and right then
				t.equal(left.size, right.size, `wing block {step}`)
				t.near(left.offset.X, -right.offset.X, 1e-6, `wing block {step} is not mirrored`)
				t.near(left.offset.Y, right.offset.Y, 1e-6, `wing block {step} is not level`)
			end
		end
	end)

	t.test("the robe's hem is wider than the torso above it", function()
		local parts = byName()
		local hem, torso = parts.Hem, parts.Torso
		t.notNil(hem, "there is a hem")
		t.notNil(torso, "there is a torso")
		if hem and torso then
			t.isTrue(hem.size.X > torso.size.X, "the hem flares")
			t.isTrue(top(hem) <= torso.offset.Y, "the hem is below the torso")
		end
	end)

	--[[ Forward is -Z everywhere in this game, so the face is on the -Z
	     side and the wings are set back behind the arms. ]]
	t.test("the face looks down -Z, and the wings sit behind the arms", function()
		local parts = byName()
		for _, name in { "EyeLeft", "EyeRight", "Brooch" } do
			local part = parts[name]
			t.notNil(part, name)
			if part then
				t.isTrue(part.offset.Z < 0, `{name} is not on the front`)
			end
		end
		local eyeL, eyeR = parts.EyeLeft, parts.EyeRight
		if eyeL and eyeR then
			t.equal(eyeL.color, AngelDesign.eye, "a closed eye is a dark mark")
			t.near(eyeL.offset.X, -eyeR.offset.X, 1e-6, "the eyes are not level across the face")
			t.near(eyeL.offset.Y, eyeR.offset.Y, 1e-6, "the eyes are not level")
		end
		local arm, wing = parts.ArmLeft, parts.WingLeft1
		if arm and wing then
			t.isTrue(wing.offset.Z > arm.offset.Z, "the wings are not behind the arms")
		end
	end)

	--[[ The one part that is not the figure. It is a Cylinder, and a
	     Cylinder's axis runs along its X, which `Run/AngelProp` turns
	     upright: so X is the disc's thickness and Y and Z are how wide it
	     lies. Written the other way round it stands on edge as a wheel,
	     which is what happened the first time and is why the thickness is
	     checked on X rather than on Y. ]]
	t.test("exactly one part is the pool of light, and it lies flat on the floor", function()
		local grounded = 0
		for _, part in AngelDesign.parts do
			if not part.grounded then
				continue
			end
			grounded += 1
			t.isTrue(part.glow == true, `{part.name} is on the floor but does not glow`)
			t.equal(part.shape, "Cylinder", `{part.name} is not a disc`)
			t.isTrue(part.size.X < 0.2, `{part.name} is {part.size.X} thick: it stands on edge`)
			t.isTrue(
				part.size.Y > 1 and part.size.Z > 1,
				`{part.name} is too small to pool any light`
			)
			t.isTrue(part.offset.Y < 0.2, `{part.name} is not on the floor`)
		end
		t.equal(grounded, 1, "one pool of light")
	end)

	t.test("the stated height is the height the blocks come to", function()
		local highest = 0
		for _, part in AngelDesign.parts do
			highest = math.max(highest, top(part))
		end
		t.near(highest, AngelDesign.height, 1e-6, "AngelDesign.height")
	end)
end
