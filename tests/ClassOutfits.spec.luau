--!strict
--[[
	The class armour sets (`Config/ClassOutfits`, `Util/ClassOutfit`; Outfit
	C, owner 2026-11-12). The sets are data, and what is held here is the
	shape that data has to keep for a set to dress an avatar: a whole set
	for every class, on real body parts, open at the face, on the floor, and
	with no two faces in one plane. Then that dressing a body does what it
	says and takes it all back off.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassCards = require(ReplicatedStorage.Shared.Config.ClassSelect)
local ClassOutfit = require(ReplicatedStorage.Shared.Util.ClassOutfit)
local ClassOutfits = require(ReplicatedStorage.Shared.Config.ClassOutfits)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local TestRunner = require(script.Parent.TestRunner)

--[[ A block where it stands on the standard body, as two corners from the
     HumanoidRootPart. ]]
type Solid = { piece: string, part: string, min: Vector3, max: Vector3 }

local function solidsOf(set: ClassOutfits.Outfit): { Solid }
	local out: { Solid } = {}
	for _, piece in set.pieces do
		local body = ClassOutfits.standard[piece.part]
		if body then
			for _, block in piece.blocks do
				local centre = body.at + block.at
				table.insert(out, {
					piece = piece.name,
					part = piece.part,
					min = centre - block.size / 2,
					max = centre + block.size / 2,
				})
			end
		end
	end
	return out
end

local AXES = { "X", "Y", "Z" }

--[[ How much two spans share. ]]
local function shared(a0: number, a1: number, b0: number, b1: number): number
	return math.min(a1, b1) - math.max(a0, b0)
end

--[[ A stand-in R15 body: a part for every standard body part, at `scale`
     times its standard size, with a Humanoid and its scale values. ]]
local function dummy(scale: number): (Model, Humanoid)
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = true
	root.Parent = model
	for name, body in ClassOutfits.standard do
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = body.size * scale
		part.CFrame = CFrame.new(body.at * scale)
		part.Parent = model
	end
	local humanoid = Instance.new("Humanoid")
	for name in ClassOutfits.scales do
		local value = Instance.new("NumberValue")
		value.Name = name
		value.Value = 1.25
		value.Parent = humanoid
	end
	humanoid.Parent = model
	return model, humanoid
end

return function(t: TestRunner.Helper)
	t.test("every class has a set, and every set a class", function()
		for class in Classes do
			t.notNil(ClassOutfits.sets[class], `{class} has nothing to wear`)
		end
		for class in ClassOutfits.sets do
			t.notNil(Classes[class], `{class} has a set but is not a class`)
		end
		for _, card in ClassCards do
			if card.locked then
				t.isNil(ClassOutfits.sets[card.class], `{card.class} is locked but has a set`)
			end
		end
	end)

	t.test("every piece names a real body part and is built of something", function()
		for class, set in ClassOutfits.sets do
			local names: { [string]: boolean } = {}
			for _, piece in set.pieces do
				local where = `{class}'s {piece.name}`
				t.notNil(ClassOutfits.standard[piece.part], `{where} is on {piece.part}`)
				t.isNil(names[piece.name], `{where} is there twice`)
				names[piece.name] = true
				t.isTrue(#piece.blocks > 0, `{where} has no blocks`)
				for _, block in piece.blocks do
					t.isTrue(
						block.size.X > 0 and block.size.Y > 0 and block.size.Z > 0,
						`{where} has a block with no size`
					)
				end
				--[[ An imported piece says how big its mesh is and where it sits,
				     and that is where its blocks are: a mesh wired to the wrong
				     piece (a hood's id on a belt) would stand far from them. The
				     Design models keep to the plan within half a stud a face. ]]
				if piece.meshId and piece.meshId ~= "" then
					t.notNil(piece.size, `{where} has a mesh and no size`)
					t.notNil(piece.at, `{where} has a mesh and no place`)
					local size, at = piece.size, piece.at
					if size and at then
						local low, high = Vector3.one * math.huge, Vector3.one * -math.huge
						for _, block in piece.blocks do
							low = low:Min(block.at - block.size / 2)
							high = high:Max(block.at + block.size / 2)
						end
						local off = (at - size / 2 - low):Abs():Max((at + size / 2 - high):Abs())
						t.isTrue(
							math.max(off.X, off.Y, off.Z) <= 0.5,
							`{where}'s mesh stands {math.max(off.X, off.Y, off.Z)} from its blocks`
						)
					end
				end
			end
		end
	end)

	t.test("a set is a full set: every covered body part wears a piece that wraps it", function()
		for class, set in ClassOutfits.sets do
			for _, part in ClassOutfits.covered do
				local body = ClassOutfits.standard[part]
				local min: Vector3?, max: Vector3? = nil, nil
				for _, piece in set.pieces do
					if piece.part == part then
						for _, block in piece.blocks do
							local low = block.at - block.size / 2
							local high = block.at + block.size / 2
							min = if min then min:Min(low) else low
							max = if max then max:Max(high) else high
						end
					end
				end
				t.notNil(min, `{class} wears nothing on {part}`)
				if min and max and part ~= "Head" then
					--[[ Wider and deeper than the body part, so the avatar's own
					     arm or leg never stands proud of its armour. ]]
					t.isTrue(
						min.X <= -body.size.X / 2 and max.X >= body.size.X / 2,
						`{class}'s {part} is narrower than the body`
					)
					t.isTrue(
						min.Z <= -body.size.Z / 2 and max.Z >= body.size.Z / 2,
						`{class}'s {part} is shallower than the body`
					)
				end
			end
		end
	end)

	t.test("hands stay bare: the weapon sits in them", function()
		for class, set in ClassOutfits.sets do
			for _, piece in set.pieces do
				t.isTrue(
					piece.part ~= "RightHand" and piece.part ~= "LeftHand",
					`{class}'s {piece.name} is on a hand`
				)
			end
		end
	end)

	t.test("left and right pieces mirror each other", function()
		for class, set in ClassOutfits.sets do
			local byPart: { [string]: ClassOutfits.Piece } = {}
			for _, piece in set.pieces do
				if
					string.sub(piece.part, 1, 4) == "Left"
					or string.sub(piece.part, 1, 5) == "Right"
				then
					t.isNil(byPart[piece.part], `{class} has two pieces on {piece.part}`)
					byPart[piece.part] = piece
				end
			end
			for part, right in byPart do
				if string.sub(part, 1, 5) ~= "Right" then
					continue
				end
				local left = byPart["Left" .. string.sub(part, 6)]
				t.notNil(left, `{class}'s {right.name} has no twin`)
				if left then
					t.equal(#left.blocks, #right.blocks, `{class}'s {right.name} and its twin`)
					for index, block in right.blocks do
						local twin = left.blocks[index]
						if twin then
							t.near(twin.at.X, -block.at.X, 1e-6, `{class}'s {right.name}`)
							t.near((twin.size - block.size).Magnitude, 0, 1e-6)
						end
					end
				end
			end
		end
	end)

	t.test("only the face shows, and it does show", function()
		local face = ClassOutfits.face
		local head = ClassOutfits.standard.Head
		for class, set in ClassOutfits.sets do
			local covered = { top = false, back = false, left = false, right = false }
			for _, piece in set.pieces do
				if piece.part ~= "Head" then
					continue
				end
				for _, block in piece.blocks do
					local low = block.at - block.size / 2
					local high = block.at + block.size / 2
					--[[ Nothing stands in front of the face's window. ]]
					local inFront = low.Z < -head.size.Z / 2 + 0.08
						and shared(low.X, high.X, -face.halfWidth, face.halfWidth) > 0
						and shared(low.Y, high.Y, face.bottom, face.top) > 0
					t.isFalse(inFront, `{class}'s {piece.name} covers the face`)
					--[[ The rest of the head is under something. ]]
					if high.Y >= head.size.Y / 2 and low.Y < head.size.Y / 2 then
						covered.top = true
					end
					if high.Z >= head.size.Z / 2 and low.Y < 0 and high.Y > 0 then
						covered.back = true
					end
					if high.X >= head.size.X / 2 and low.Y < 0 and high.Y > 0 then
						covered.right = true
					end
					if low.X <= -head.size.X / 2 and low.Y < 0 and high.Y > 0 then
						covered.left = true
					end
				end
			end
			for side, done in covered do
				t.isTrue(done, `{class}'s head is bare at the {side}`)
			end
		end
	end)

	t.test("nothing reaches under the floor", function()
		for class, set in ClassOutfits.sets do
			for _, solid in solidsOf(set) do
				t.isTrue(
					solid.min.Y >= ClassOutfits.floor - 1e-6,
					`{class}'s {solid.piece} is {ClassOutfits.floor - solid.min.Y} under the floor`
				)
			end
		end
	end)

	--[[ Two faces that look the same way, lie in one plane and overlap
	     flicker (owner, 2026-11-09: "make sure there is no z fighting").
	     Checked on the standing body, so across pieces and body parts too.
	     Faces that only meet along an edge are one surface and are fine. ]]
	t.test("no two faces share a plane", function()
		local THIN = 0.015
		for class, set in ClassOutfits.sets do
			local solids = solidsOf(set)
			for i = 1, #solids do
				for j = i + 1, #solids do
					local a, b = solids[i], solids[j]
					for index, axis in AXES do
						local u, v = AXES[index % 3 + 1], AXES[(index + 1) % 3 + 1]
						local overlap = shared(
							(a.min :: any)[u],
							(a.max :: any)[u],
							(b.min :: any)[u],
							(b.max :: any)[u]
						) > THIN and shared(
							(a.min :: any)[v],
							(a.max :: any)[v],
							(b.min :: any)[v],
							(b.max :: any)[v]
						) > THIN
						if overlap then
							for _, side in { "min", "max" } do
								local gap =
									math.abs((a :: any)[side][axis] - (b :: any)[side][axis])
								t.isTrue(
									gap > THIN,
									`{class}: {a.piece} and {b.piece} share a {side} {axis} face`
								)
							end
						end
					end
				end
			end
		end
	end)

	t.test("a piece is stretched to its body part, within limits", function()
		local standard = ClassOutfits.standard.UpperTorso.size
		local same = ClassOutfit.ratio(standard, standard)
		t.near((same - Vector3.one).Magnitude, 0, 1e-6)
		local wide = ClassOutfit.ratio(standard * Vector3.new(1.3, 1, 1), standard)
		t.near(wide.X, 1.3, 1e-6)
		t.near(wide.Y, 1, 1e-6)
		local limit = ClassOutfits.stretch
		t.isTrue(limit.min <= 1 and limit.max > 1, "the limits do not allow the standard body")
		t.near(ClassOutfit.ratio(standard * 100, standard).X, limit.max, 1e-6)
		t.near(ClassOutfit.ratio(standard / 100, standard).X, limit.min, 1e-6)
	end)

	t.test("dressing puts every piece on its body part, sized to it", function()
		for class, set in ClassOutfits.sets do
			for _, scale in { 1, 1.2 } do
				local model = dummy(scale)
				ClassOutfit.dress(model, class)
				t.equal(ClassOutfit.worn(model), class)
				local outfit = model:FindFirstChild(ClassOutfit.NAME)
				--[[ A piece whose model has loaded (the server's templates, in a
				     running game) is that one mesh; any other is its blocks. ]]
				local templates = ReplicatedStorage:FindFirstChild(ClassOutfit.MESHES)
				local loaded = templates and templates:FindFirstChild(class)
				local function meshed(piece: ClassOutfits.Piece): boolean
					return piece.meshId ~= nil
						and piece.size ~= nil
						and piece.at ~= nil
						and loaded ~= nil
						and loaded:FindFirstChild(piece.name) ~= nil
				end
				local count = 0
				for _, piece in set.pieces do
					count += if meshed(piece) then 1 else #piece.blocks
				end
				t.equal(if outfit then #outfit:GetChildren() else 0, count, `{class}'s solids`)
				--[[ Each stands where its mesh or its block says, on a body
				     `scale` times the standard one, a mesh turned back to face
				     the way the body does. ]]
				local piece = set.pieces[1]
				local body = model:FindFirstChild(piece.part) :: BasePart
				local first = outfit and outfit:FindFirstChild(piece.name)
				t.notNil(first, `{class}'s {piece.name} was not built`)
				if first and first:IsA("BasePart") then
					local size, place = piece.blocks[1].size, piece.blocks[1].at
					if meshed(piece) and piece.size and piece.at then
						size, place = piece.size, piece.at
						t.isTrue(first:IsA("MeshPart"), `{class}'s {piece.name} is not its mesh`)
						local facing = body.CFrame.LookVector:Dot(first.CFrame.LookVector)
						t.near(facing, if piece.turned then -1 else 1, 1e-4)
					end
					t.near((first.Size - size * scale).Magnitude, 0, 1e-4)
					local at = body.CFrame:PointToObjectSpace(first.Position)
					t.near((at - place * scale).Magnitude, 0, 1e-4)
					t.isFalse(first.CanCollide, "a piece collides")
					t.isFalse(first.CanQuery, "a piece answers raycasts")
					t.isFalse(first.CanTouch, "a piece touches")
					t.isTrue(first.Massless, "a piece has mass")
				end
				model:Destroy()
			end
		end
	end)

	t.test("dressing hides the avatar's own accessories; undressing brings them back", function()
		local model, humanoid = dummy(1)
		local hat = Instance.new("Accessory")
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Transparency = 0.25
		handle.Parent = hat
		local glow = Instance.new("PointLight")
		glow.Parent = handle
		hat.Parent = model
		ClassOutfit.dress(model, "Ranger", true)
		t.equal(handle.Transparency, 1, "the hat still shows")
		t.isFalse(glow.Enabled, "the hat's light is still on")
		--[[ One that arrives late is hidden too: by the set's own listener,
		     which this place's deferred signals run a moment after the
		     accessory lands, still inside the frame. ]]
		local late = Instance.new("Accessory")
		local lateHandle = Instance.new("Part")
		lateHandle.Name = "Handle"
		lateHandle.Parent = late
		late.Parent = model
		task.wait()
		t.equal(lateHandle.Transparency, 1, "a late accessory shows")
		for name, value in ClassOutfits.scales do
			local scale = humanoid:FindFirstChild(name) :: NumberValue
			t.near(scale.Value, value, 1e-6, `{name} is not the standard`)
		end
		--[[ A change of class keeps it all hidden and standard. ]]
		ClassOutfit.dress(model, "Warden", true)
		t.equal(ClassOutfit.worn(model), "Warden")
		t.equal(handle.Transparency, 1, "the hat came back with the new set")
		ClassOutfit.undress(model)
		t.isNil(ClassOutfit.worn(model))
		t.isNil(model:FindFirstChild(ClassOutfit.NAME))
		t.near(handle.Transparency, 0.25, 1e-6, "the hat is not as it was")
		t.isTrue(glow.Enabled, "the hat's light stayed off")
		t.equal(lateHandle.Transparency, 0)
		for name in ClassOutfits.scales do
			local scale = humanoid:FindFirstChild(name) :: NumberValue
			t.near(scale.Value, 1.25, 1e-6, `{name} was not put back`)
		end
		model:Destroy()
	end)

	t.test("a class with no set, or a body that is not R15, is left alone", function()
		local model = dummy(1)
		ClassOutfit.dress(model, "Assassin")
		t.isNil(model:FindFirstChild(ClassOutfit.NAME))
		local torso = model:FindFirstChild("UpperTorso")
		if torso then
			torso:Destroy()
		end
		ClassOutfit.dress(model, "Ranger")
		t.isNil(model:FindFirstChild(ClassOutfit.NAME))
		model:Destroy()
	end)
end
