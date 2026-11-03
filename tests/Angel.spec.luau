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

--[[ The box a part really fills, turn included: the wing feathers are
     tilted slabs, so their corners reach further than half their size
     (`AngelDesign.Part.rotation`). Every check below measures from this
     rather than from `offset +/- size / 2`. ]]
local function extent(part: AngelDesign.Part): (Vector3, Vector3)
	local turn = part.rotation
	local frame = if turn
		then CFrame.Angles(math.rad(turn.X), math.rad(turn.Y), math.rad(turn.Z))
		else CFrame.identity
	local low, high = Vector3.one * math.huge, Vector3.one * -math.huge
	for _, x in { -0.5, 0.5 } do
		for _, y in { -0.5, 0.5 } do
			for _, z in { -0.5, 0.5 } do
				local corner = part.offset
					+ frame:VectorToWorldSpace(part.size * Vector3.new(x, y, z))
				low, high = low:Min(corner), high:Max(corner)
			end
		end
	end
	return low, high
end

--[[ The lowest and highest point of a part. ]]
local function bottom(part: AngelDesign.Part): number
	local low = extent(part)
	return low.Y
end

local function top(part: AngelDesign.Part): number
	local _, high = extent(part)
	return high.Y
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

	--[[ Bigger outward, which is what the sheet's WINGS panel shows: the
	     outermost slab is the largest and reaches the top of the head. Two
	     earlier passes had them shrinking outward and they read as stairs
	     going down. ]]
	t.test("each wing is three feathers sweeping outward and up, getting bigger", function()
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
					t.isTrue(part.size.Y > last.size.Y, `{name} is not bigger than the one before`)
					t.isTrue(part.size.X > last.size.X, `{name} is not wider than the one before`)
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

	--[[ The gold band is the widest thing on the body and the hem tucks
	     under it, which is what the sheet's FRONT view shows. It was built
	     flared wider than the torso at first, which is the opposite. ]]
	t.test("the band is the widest of the robe, and the hem tucks under it", function()
		local parts = byName()
		local hem, torso, band = parts.Hem, parts.Torso, parts.Waist
		t.notNil(hem, "there is a hem")
		t.notNil(torso, "there is a torso")
		t.notNil(band, "there is a waist band")
		if hem and torso and band then
			t.isTrue(band.size.X > torso.size.X, "the band is wider than the torso")
			t.isTrue(hem.size.X < torso.size.X, "the hem tucks in under the band")
			t.isTrue(top(hem) <= band.offset.Y, "the hem is below the band")
			t.isTrue(top(band) <= torso.offset.Y, "the band is below the torso")
		end
	end)

	--[[ And the head is the widest part of the figure above the wings,
	     which is what makes it read as an angel rather than a pillar. ]]
	t.test("the head is a little wider than the torso", function()
		local parts = byName()
		local head, torso = parts.Head, parts.Torso
		if head and torso then
			t.isTrue(head.size.X > torso.size.X, "the head is wider")
			t.isTrue(head.size.X < torso.size.X * 1.4, "but not a balloon")
		end
	end)

	--[[ The outermost wing slab reaches the top of the head, as the sheet
	     draws it: any lower and the wings read as stubs. ]]
	--[[ Each feather is tilted further over than the one before, which is
	     what makes the wing sweep instead of climb like stairs. ]]
	t.test("each feather is tilted further than the one before", function()
		local parts = byName()
		for _, side in { "Left", "Right" } do
			local last = 0
			for step = 1, 3 do
				local part = parts[`Wing{side}{step}`]
				t.notNil(part, `Wing{side}{step}`)
				local turn = part and part.rotation
				t.notNil(turn, `Wing{side}{step} is not tilted at all`)
				if turn then
					local tilt = math.abs(turn.Z)
					t.isTrue(tilt > last, `Wing{side}{step} is not tilted further`)
					t.isTrue(tilt < 60, `Wing{side}{step} is tilted past a wing into a blade`)
					last = tilt
				end
			end
		end
		--[[ Mirrored: the two wings tilt opposite ways. ]]
		local left, right = parts.WingLeft3, parts.WingRight3
		if left and right and left.rotation and right.rotation then
			t.near(left.rotation.Z, -right.rotation.Z, 1e-6, "the wings tilt opposite ways")
		end
	end)

	t.test("the wings reach the top of the head", function()
		local parts = byName()
		local head, outer = parts.Head, parts.WingLeft3
		if head and outer then
			t.near(top(outer), top(head), 0.2, "the outer wing against the head")
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

	--[[ The owner's imported Angel (2026-11-02: "i just imported the angel
	     room model") is one textured MeshPart, so the id and the texture go
	     together: a mesh with no texture would draw a white blank, and a
	     texture with no mesh draws nothing at all. Empty means no import and
	     `Run/AngelProp` keeps building the blocks. ]]
	t.test("the mesh and its texture are both filled in or both empty", function()
		local mesh = AngelDesign.mesh
		for _, id in { mesh.id, mesh.textureId } do
			if id ~= "" then
				t.isTrue(string.match(id, "^rbxassetid://%d+$") ~= nil, `"{id}" is not an asset id`)
			end
		end
		t.equal(mesh.id == "", mesh.textureId == "", "one of the two is missing")
	end)

	--[[ The import is its own model, not the blocks joined up, so its box is
	     not checked against them. What must hold is where it sits: the robe
	     hovers exactly as the blocks do, and the head stops below the halo so
	     the ring floats clear instead of cutting through it. ]]
	t.test("the imported Angel hovers where the blocks do, under the halo", function()
		local mesh = AngelDesign.mesh
		t.isTrue(mesh.size.X > 0 and mesh.size.Y > 0 and mesh.size.Z > 0, "the mesh has a size")

		local low = mesh.offset.Y - mesh.size.Y / 2
		local high = mesh.offset.Y + mesh.size.Y / 2
		t.near(low, AngelDesign.hover, 1e-3, "the robe hovers on AngelDesign.hover")

		local ring = math.huge
		for _, part in AngelDesign.parts do
			if part.halo then
				local partLow = select(1, extent(part)).Y
				ring = math.min(ring, partLow)
			end
		end
		t.isTrue(ring < math.huge, "there is a halo")
		t.isTrue(high < ring, `the head reaches {high}, into the halo at {ring}`)
		t.isTrue(high > AngelDesign.height - 1.5, "the mesh is too short for its halo")
	end)

	--[[ Nothing the import draws is built as a block as well, or the Angel
	     would wear two of everything. Only the halo and the pool of light
	     survive beside it, which is what `Run/AngelProp` keeps. ]]
	t.test("only the halo and the light stand beside the mesh", function()
		local kept = 0
		for _, part in AngelDesign.parts do
			if part.halo or part.grounded then
				kept += 1
				t.isFalse(part.halo == true and part.grounded == true, `{part.name} is both`)
			end
		end
		t.equal(kept, 5, "four halo bars and one pool of light")
	end)

	t.test("the stated height is the height the blocks come to", function()
		local highest = 0
		for _, part in AngelDesign.parts do
			highest = math.max(highest, top(part))
		end
		t.near(highest, AngelDesign.height, 1e-6, "AngelDesign.height")
	end)
end
