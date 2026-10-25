--!strict
--[[
	Claude Design models' own clips (`Config/ModelClips`, `Shared/Util/
	ModelClip`, played by `Fx/ModelAnimator`). What is pinned: every data
	module is well formed (joints parents first, parts on joints it has,
	keys in order and the right width); at rest nothing moves; the fit reads
	an import's scale, turn and place back from its parts; and a joint's
	move reaches the parts riding it, carried through that fit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelClip = require(ReplicatedStorage.Shared.Util.ModelClip)
local TestRunner = require(script.Parent.TestRunner)

local WIDTH = { pos = 3, rot = 4, scale = 3 }

local function models(): { [string]: ModelClip.Model }
	local out: { [string]: ModelClip.Model } = {}
	local folder = ReplicatedStorage.Shared.Config:FindFirstChild("ModelClips")
	if folder then
		for _, module in folder:GetChildren() do
			if module:IsA("ModuleScript") then
				out[module.Name] = (require :: any)(module)
			end
		end
	end
	return out
end

--[[ A two-part model: a body at the origin and a head on a neck joint a
     unit up, with one clip that turns the neck a quarter about Y. ]]
local function toy(): ModelClip.Model
	local s = math.sqrt(0.5)
	return {
		joints = {
			{ name = "root", parent = "", rest = { 0, 0, 0, 0, 0, 0, 1, 1, 1, 1 } },
			{ name = "neck", parent = "root", rest = { 0, 1, 0, 0, 0, 0, 1, 1, 1, 1 } },
		},
		parts = {
			body = { joint = "root", cframe = { 0, 0, 0, 0, 0, 0, 1 }, size = { 1, 1, 1 } },
			head = { joint = "neck", cframe = { 0, 1, 0.5, 0, 0, 0, 1 }, size = { 0.5, 0.5, 0.5 } },
			nose = {
				joint = "neck",
				cframe = { 0.4, 1.2, 0.2, 0, 0, 0, 1 },
				size = { 0.2, 0.2, 0.2 },
			},
		},
		clips = {
			-- length 2 with the last key at 1: read at 1, it is held, not wrapped
			Turn = {
				length = 2,
				joints = {
					neck = { rot = { times = { 0, 1 }, values = { 0, 0, 0, 1, 0, s, 0, s } } },
				},
			},
		},
	}
end

local function observe(model: ModelClip.Model, turn: CFrame, scale: number, origin: Vector3)
	local out: { [string]: { position: Vector3, size: Vector3 } } = {}
	for name, part in model.parts do
		local p = Vector3.new(part.cframe[1], part.cframe[2], part.cframe[3])
		out[name] = {
			position = origin + turn * (p * scale),
			size = Vector3.new(part.size[1], part.size[2], part.size[3]) * scale,
		}
	end
	return out
end

return function(t: TestRunner.Helper)
	t.test("every model's clip data is well formed", function()
		for name, model in models() do
			local seen: { [string]: boolean } = {}
			for _, joint in model.joints do
				t.isTrue(
					joint.parent == "" or seen[joint.parent] == true,
					`{name}: {joint.name} before its parent`
				)
				t.equal(#joint.rest, 10, `{name}: {joint.name}'s rest`)
				seen[joint.name] = true
			end
			for partName, part in model.parts do
				t.isTrue(
					part.joint == "" or seen[part.joint] == true,
					`{name}: {partName} rides a missing joint`
				)
			end
			for clipName, clip in model.clips do
				t.isTrue(clip.length > 0, `{name}.{clipName} has no length`)
				for jointName, tracks in clip.joints do
					t.isTrue(
						seen[jointName] == true,
						`{name}.{clipName} drives a missing joint {jointName}`
					)
					for key, track in tracks :: any do
						local times = track.times
						t.equal(
							#track.values,
							#times * WIDTH[key],
							`{name}.{clipName}.{jointName}.{key} width`
						)
						for i = 2, #times do
							t.isTrue(
								times[i] > times[i - 1],
								`{name}.{clipName}.{jointName}.{key} keys out of order`
							)
						end
					end
				end
			end
		end
	end)

	t.test("a track interpolates between keys and holds its ends", function()
		local track = { times = { 0, 2 }, values = { 0, 0, 0, 4, 2, -2 } }
		local mid = ModelClip.sample(track, 3, 1)
		t.near(mid[1], 2, 1e-9)
		t.near(mid[2], 1, 1e-9)
		t.near(mid[3], -1, 1e-9)
		t.near(ModelClip.sample(track, 3, -1)[1], 0, 1e-9)
		t.near(ModelClip.sample(track, 3, 5)[1], 4, 1e-9)
	end)

	t.test("a rotation takes the nearer way round", function()
		-- q and -q are one rotation: halfway must not pass through zero
		local track = { times = { 0, 1 }, values = { 0, 0, 0, 1, 0, 0, 0, -1 } }
		local q = ModelClip.sample(track, 4, 0.5)
		t.near(math.abs(q[4]), 1, 1e-9)
	end)

	t.test("the fit reads the import's turn, scale and place from its parts", function()
		local model = toy()
		local turn = CFrame.Angles(0, math.pi, 0)
		local fit = ModelClip.fit(model, observe(model, turn, 1.7, Vector3.new(3, -2, 5)))
		t.notNil(fit)
		local f = fit :: ModelClip.Fit
		t.near(f.scale, 1.7, 1e-6)
		t.isTrue(f.turn:FuzzyEq(turn, 1e-6), "the turn is the import's")
		t.near((f.origin - Vector3.new(3, -2, 5)).Magnitude, 0, 1e-6)
		t.near(f.error, 0, 1e-6)
	end)

	t.test("at rest, and with no clip, nothing moves", function()
		local model = toy()
		local fit = ModelClip.fit(
			model,
			observe(model, CFrame.Angles(0, math.pi, 0), 2, Vector3.zero)
		) :: ModelClip.Fit
		local deltas = ModelClip.deltas(model, nil, 0.4, ModelClip.restInverse(model))
		local rest = CFrame.new(1, 2, 3) * CFrame.Angles(0.3, 0.2, 0.1)
		local cframe, stretch = ModelClip.place(rest, deltas.neck, fit)
		t.isTrue(cframe:FuzzyEq(rest, 1e-6), "the part stays where it rests")
		t.near((stretch - Vector3.one).Magnitude, 0, 1e-6)
	end)

	t.test("a joint's turn carries the parts on it, through the import's fit", function()
		local model = toy()
		local turn = CFrame.Angles(0, math.pi, 0)
		local scale, origin = 2, Vector3.new(0, 1, 0)
		local fit = ModelClip.fit(model, observe(model, turn, scale, origin)) :: ModelClip.Fit
		local deltas = ModelClip.deltas(model, model.clips.Turn, 1, ModelClip.restInverse(model))
		-- the head's centre sits 0.5 in front of the neck; a quarter turn about Y takes +Z to +X
		local headRest = CFrame.new(origin + turn * (Vector3.new(0, 1, 0.5) * scale))
		local moved = ModelClip.place(headRest, deltas.neck, fit)
		local expected = origin + turn * (Vector3.new(0.5, 1, 0) * scale)
		t.near((moved.Position - expected).Magnitude, 0, 1e-5, "the head swings round the neck")
		-- the body rides the root, which the clip leaves alone
		local bodyRest = CFrame.new(origin)
		t.isTrue(
			ModelClip.place(bodyRest, deltas.root, fit):FuzzyEq(bodyRest, 1e-6),
			"the body stays"
		)
	end)

	t.test("a parent's travel carries its children, grown with the import's scale", function()
		local model = toy()
		model.clips.Lift = {
			length = 2,
			joints = { root = { pos = { times = { 0, 1 }, values = { 0, 0, 0, 0, 0.5, 0 } } } },
		}
		local scale = 3
		local fit =
			ModelClip.fit(model, observe(model, CFrame.new(), scale, Vector3.zero)) :: ModelClip.Fit
		local deltas = ModelClip.deltas(model, model.clips.Lift, 1, ModelClip.restInverse(model))
		-- the head rides the neck, whose parent the clip lifts
		local rest = CFrame.new(Vector3.new(0, 1, 0.5) * scale)
		local moved = ModelClip.place(rest, deltas.neck, fit)
		t.near(
			moved.Position.Y - rest.Position.Y,
			0.5 * scale,
			1e-6,
			"a 0.5 lift is 1.5 at three times the size"
		)
	end)

	t.test("a scaling joint stretches its parts along their own axes", function()
		local model = toy()
		model.clips.Grow = {
			length = 2,
			joints = { neck = { scale = { times = { 0, 1 }, values = { 1, 1, 1, 2, 1, 1 } } } },
		}
		local fit =
			ModelClip.fit(model, observe(model, CFrame.new(), 1, Vector3.zero)) :: ModelClip.Fit
		local deltas = ModelClip.deltas(model, model.clips.Grow, 1, ModelClip.restInverse(model))
		local _, stretch = ModelClip.place(CFrame.new(0, 1, 0.5), deltas.neck, fit)
		t.near(stretch.X, 2, 1e-6)
		t.near(stretch.Y, 1, 1e-6)
		t.near(stretch.Z, 1, 1e-6)
	end)

	--[[ A boss's lash: a joint stretched along Z carries what rides it
	     further out and longer; a joint under it kept at its size cancels
	     the stretch for its own parts. ]]
	t.test("a stretched joint carries its parts out; a kept joint keeps its size", function()
		local model = toy()
		local fit =
			ModelClip.fit(model, observe(model, CFrame.new(), 1, Vector3.zero)) :: ModelClip.Fit
		local restInverse = ModelClip.restInverse(model)
		local head = CFrame.new(0, 1, 0.5)

		local out = ModelClip.deltas(model, nil, 0, restInverse, { root = Vector3.new(1, 1, 2) })
		local placed, size = ModelClip.place(head, out.neck, fit)
		t.near(placed.Position.Z, 1, 1e-6)
		t.near(size.Z, 2, 1e-6)

		local kept = ModelClip.deltas(
			model,
			nil,
			0,
			restInverse,
			{ root = Vector3.new(1, 1, 2), neck = Vector3.new(1, 1, 0.5) }
		)
		local keptPlace, keptSize = ModelClip.place(head, kept.neck, fit)
		t.near(keptPlace.Position.Z, 0.5, 1e-6)
		t.near(keptSize.Z, 1, 1e-6)
	end)

	--[[ King Bloblin's lash links are turned against the chain: a kept
	     joint undone in its own axes was sheared a thousandfold as a lash
	     began, and thrown out of sight. ]]
	t.test("a kept joint turned against the stretch keeps its shape", function()
		local s = math.sin(math.pi / 8)
		local c = math.cos(math.pi / 8)
		local model: ModelClip.Model = {
			joints = {
				{ name = "root", parent = "", rest = { 0, 0, 0, 0, 0, 0, 1, 1, 1, 1 } },
				-- turned 45 degrees about Y from the root
				{ name = "link", parent = "root", rest = { 0, 0, 2, 0, s, 0, c, 1, 1, 1 } },
			},
			parts = {},
			clips = {},
		}
		local plain = ModelClip.pose(model, nil, 0)
		for _, amount in { 1e-3, 0.3, 4 } do
			local world = ModelClip.pose(model, nil, 0, {
				root = Vector3.new(1, 1, amount),
				link = Vector3.new(1, 1, 1 / amount),
			})
			for k = 1, 9 do
				t.near(world.link.m[k], plain.link.m[k], 1e-6)
			end
			t.near(world.link.t.Z, 2 * amount, 1e-6)
		end
	end)

	t.test("a clip that plays once holds its last frame; a loop wraps", function()
		local once: ModelClip.Clip = { length = 2, loops = false, joints = {} }
		local loop: ModelClip.Clip = { length = 2, joints = {} }
		t.near(ModelClip.clipTime(once, 5), 2, 1e-9)
		t.near(ModelClip.clipTime(once, -1), 0, 1e-9)
		t.near(ModelClip.clipTime(loop, 5), 1, 1e-9)
		t.near(ModelClip.clipTime(nil, 5), 0, 1e-9)
	end)

	--[[ The animator poses with `deltasInto` and `placeRigid` (native
	     CFrames for the joints that do not scale); every part must land
	     where the plain affine maths puts it, in every model and clip, and
	     with a chain stretched and its fist kept. ]]
	t.test("the animator's fast maths places every part as the plain maths does", function()
		local fit: ModelClip.Fit = {
			turn = CFrame.Angles(0, math.pi, 0),
			scale = 2.7,
			origin = Vector3.new(0.3, -0.2, 1.1),
			error = 0,
			spread = 1,
		}
		local outCF: { [string]: CFrame } = {}
		local outAffine: { [string]: ModelClip.Affine } = {}
		local function check(
			label: string,
			model: ModelClip.Model,
			clip: ModelClip.Clip?,
			time: number,
			stretch: ModelClip.Stretch?
		)
			local rest = ModelClip.rest(model)
			local plain = ModelClip.deltas(model, clip, time, rest.affine, stretch)
			ModelClip.deltasInto(clip, time, rest, stretch, outCF, outAffine)
			for partName, part in model.parts do
				local delta = plain[part.joint]
				if not delta then
					continue
				end
				local c = part.cframe
				local at = fit.origin + fit.turn * (Vector3.new(c[1], c[2], c[3]) * fit.scale)
				-- orthonormal, as a real part's is: the data's quaternions are rounded
				local partRest = (CFrame.new(at) * fit.turn * CFrame.new(
					0,
					0,
					0,
					c[4],
					c[5],
					c[6],
					c[7]
				)):Orthonormalize()
				local want, wantStretch = ModelClip.place(partRest, delta, fit)
				local got, gotStretch
				local affine = outAffine[part.joint]
				local rigid = outCF[part.joint]
				if affine then
					got, gotStretch = ModelClip.place(partRest, affine, fit)
				elseif rigid then
					got, gotStretch = ModelClip.placeRigid(partRest, rigid, fit), Vector3.one
				else
					t.isTrue(false, `{label}: {partName}'s joint was not posed`)
					continue
				end
				local off = math.max(
					(got.Position - want.Position).Magnitude,
					(got.RightVector - want.RightVector).Magnitude,
					(got.UpVector - want.UpVector).Magnitude,
					(gotStretch - wantStretch).Magnitude
				)
				-- CFrames are single precision: down King Bloblin's twelve-link lash
				-- the fist drifts by a ten-thousandth of a stud. A pixel here is
				-- about a twentieth of one.
				t.isTrue(off < 1e-3, `{label}: {partName} off by {off}`)
			end
		end
		local all = models()
		for name, model in all do
			check(`{name} at rest`, model, nil, 0)
			for clipName, clip in model.clips do
				for _, share in { 0.07, 0.5, 0.93 } do
					check(`{name}.{clipName}`, model, clip, clip.length * share)
				end
			end
		end
		local king = all.KingBloblin
		if king and #king.joints >= 3 then
			check("KingBloblin stretched", king, nil, 0, {
				[king.joints[2].name] = Vector3.new(1, 1, 3),
				[king.joints[3].name] = Vector3.new(1, 1, 1 / 3),
			})
		end
	end)
end
