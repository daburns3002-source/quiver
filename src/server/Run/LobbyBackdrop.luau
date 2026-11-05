--!strict
--[[
	The lobby's far scenery (`Config/Lobby.backdrop`; owner, 2026-11-05: "i
	want more stuff happening in the background to make the lobby look like it
	goes on for a while. there should be mountains and waterfalls, it should
	draw inspiration from the background of the enemy spotlight loading
	screens").

	The loading screens (`assets/concepts/blocky/ui/loading/spotlight/`) put a
	glade below tall grey cliffs: stepped blocky stone with moss hanging off
	each ledge and grass on top, round trees and pines along the tops, falls
	pouring off the faces into pools, and glowing cyan mushrooms on the forest floor. This builds
	that as a ring of cliffs well past the wood round the courtyard, so from the
	camera the lobby reads as a clearing in a valley rather than a field that
	stops.

	Everything is plain smooth parts, built once at boot. Nothing collides and
	nothing far away casts a shadow.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local LobbyCourtyard = require(script.Parent.LobbyCourtyard)

local LobbyBackdrop = {}

local SPEC = LobbyConfig.backdrop
local ORIGIN = LobbyConfig.origin
local OUTSIDE = LobbyCourtyard.OUTSIDE
local part = LobbyCourtyard.part
local blob = LobbyCourtyard.blob

local function world(at: Vector2, y: number): Vector3
	return ORIGIN + Vector3.new(at.X, y, at.Y)
end

--[[ A tree of the lobby's own, `grow` as large, its foot at height `y`: the
     builder passes its `tree`, so the cliffs grow the same trees as the wood. ]]
export type Grow = (at: Vector2, grow: number, rng: Random, parent: Instance, y: number) -> ()

--[[ A blocky pine: three square tiers turned an eighth, each smaller and
     higher, on a short trunk. ]]
local function pine(at: Vector2, y: number, tall: number, rng: Random, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Pine"
	local foot = CFrame.new(world(at, y)) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0)
	part(
		"Trunk",
		Vector3.new(tall * 0.08, tall * 0.3, tall * 0.08),
		foot * CFrame.new(0, tall * 0.15, 0),
		SPEC.pineTrunk,
		model
	)
	for k = 0, 2 do
		local across = tall * (0.5 - k * 0.13)
		local high = tall * 0.26
		part(
			"Needles",
			Vector3.new(across, high, across),
			foot
				* CFrame.new(0, tall * (0.3 + k * 0.22) + high / 2, 0)
				* CFrame.Angles(0, math.pi / 4, 0),
			if k == 2 then SPEC.pineLight else SPEC.pine,
			model
		)
	end
	model.Parent = parent
end

--[[ A cliff's tier as the fall sees it, in the cliff's own frame: the z of
     its front face (-Z is towards the courtyard) and the heights of its foot
     and of its grass ledge's top. ]]
type Step = { front: number, base: number, top: number }

local STREAK = "rbxasset://textures/particles/smoke_main.dds"

--[[ White water streaming down a drop from `lip`, `wide` across and `drop`
     tall, so the fall moves rather than hanging as a still sheet. ]]
local function streaks(lip: BasePart, wide: number, drop: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Streaks"
	e.Texture = STREAK
	e.Shape = Enum.ParticleEmitterShape.Box
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Color = ColorSequence.new(SPEC.foam)
	e.LightEmission = 0.2
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, wide * 0.22),
		NumberSequenceKeypoint.new(1, wide * 0.4),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.8, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Speed = NumberRange.new(8, 12)
	e.Acceleration = Vector3.new(0, -30, 0)
	-- long enough to reach the foot: d = v t + a t^2 / 2
	local t = (-10 + math.sqrt(100 + 60 * drop)) / 30
	e.Lifetime = NumberRange.new(t * 0.9, t)
	e.Rate = SPEC.fallStreaks
	e.LockedToPart = false
	e.Parent = lip
end

--[[ Mist rising off a pool, `wide` the fall's width. ]]
local function mist(at: BasePart, wide: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Mist"
	e.Texture = STREAK
	e.Color = ColorSequence.new(SPEC.foam)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, wide * 0.7),
		NumberSequenceKeypoint.new(1, wide * 1.6),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Speed = NumberRange.new(3, 6)
	e.SpreadAngle = Vector2.new(60, 60)
	e.EmissionDirection = Enum.NormalId.Top
	e.Lifetime = NumberRange.new(2.5, 3.5)
	e.Rate = SPEC.fallMist
	e.Parent = at
end

--[[ One drop of a fall, down a face at `z` from `top` to `floor`: the water
     in streaks of light and deeper blue at slightly different depths, thin
     foam lines down it, a white lip where it pours over, and spray where it
     lands. `x` is the fall's middle across the face. ]]
local function drop(
	face: CFrame,
	x: number,
	z: number,
	floor: number,
	top: number,
	wide: number,
	rng: Random,
	model: Instance
)
	local tall = top - floor
	local mid = face * CFrame.new(x, (top + floor) / 2, z - 1.3)
	-- the sheet, cut into streaks across its width
	local cuts = { 0 }
	for _ = 1, 4 do
		table.insert(cuts, rng:NextNumber(0.12, 0.3))
	end
	local sum = 0
	for _, w in cuts do
		sum += w
	end
	local left = -wide / 2
	for k = 2, #cuts do
		local w = cuts[k] / sum * wide
		local deep = k == 2 or k == 4
		local streak = part(
			"Water",
			Vector3.new(w + 0.2, tall, 1),
			mid * CFrame.new(left + w / 2, 0, rng:NextNumber(-0.3, 0.3)),
			if deep then SPEC.waterDeep else SPEC.water,
			model
		)
		streak.Transparency = rng:NextNumber(0.02, 0.15)
		left += w
	end
	for _ = 1, 5 do
		local line = part(
			"Foam",
			Vector3.new(wide * rng:NextNumber(0.04, 0.08), tall * rng:NextNumber(0.6, 1), 0.4),
			mid * CFrame.new(rng:NextNumber(-0.42, 0.42) * wide, 0, -0.75),
			SPEC.foam,
			model
		)
		line.Transparency = 0.25
		line.CFrame *= CFrame.new(0, (tall - line.Size.Y) / 2 * rng:NextNumber(-1, 1), 0)
	end
	-- the lip, bulging out where the water tips over
	local lip = part(
		"Lip",
		Vector3.new(wide + 1, 1.6, 2.4),
		face * CFrame.new(x, top + 0.2, z - 0.9),
		SPEC.foam,
		model
	)
	streaks(lip, wide, tall)
	-- spray where it lands
	for k = -2, 2 do
		blob(
			"Spray",
			Vector3.new(wide * 0.36, wide * 0.24, wide * 0.36),
			face * CFrame.new(x + k * wide * 0.2, floor + 0.6, z - 2.2 - math.abs(k) * 0.4),
			SPEC.foam,
			model
		).Transparency =
			0.12
	end
end

--[[ A fall cascading down a stepped cliff: a stream across the top tier,
     a drop down each tier's face onto the ledge below, a run of water across
     each ledge, and a round pool at the foot, ringed with rocks, misting.
     `steps` are the cliff's tiers from the ground up. ]]
local function fall(face: CFrame, steps: { Step }, rng: Random, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "BackdropFall"
	local wide = rng:NextNumber(SPEC.fallWide.Min, SPEC.fallWide.Max)
	local x = rng:NextNumber(-0.1, 0.1) * wide
	local n = #steps
	-- the stream feeding it, back across the top
	local high = steps[n]
	part(
		"Stream",
		Vector3.new(wide * 0.8, 0.4, 24),
		face * CFrame.new(x, high.top + 0.15, high.front + 12),
		SPEC.waterDeep,
		model
	)
	for k = n, 1, -1 do
		local step = steps[k]
		-- each drop a little wider than the one above, as the water spreads
		local w = wide * (1 + (n - k) * 0.14)
		local floor = if k > 1 then steps[k - 1].top else 0
		drop(face, x, step.front, floor, step.top, w, rng, model)
		if k > 1 then
			local below = steps[k - 1]
			local run = step.front - below.front
			part(
				"Run",
				Vector3.new(w, 0.4, run),
				face * CFrame.new(x, floor + 0.15, below.front + run / 2),
				SPEC.water,
				model
			).Transparency =
				0.08
		end
	end
	-- the pool, its foam and the rocks round its edge
	local w = wide * (1 + (n - 1) * 0.14)
	local front = steps[1].front
	local centre = face * CFrame.new(x, 0.2, front - w * 0.9)
	local pool = part(
		"Pool",
		Vector3.new(0.4, w * 2.4, w * 2.4),
		centre * CFrame.Angles(0, 0, math.pi / 2),
		SPEC.pool,
		model,
		Enum.PartType.Cylinder
	)
	pool.Transparency = 0.05
	mist(pool, w)
	for k = 1, 9 do
		local angle = k / 9 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		-- none on the cliff side, where the water comes in
		if math.sin(angle) > 0.55 then
			continue
		end
		local s = rng:NextNumber(2.5, 4.5)
		blob(
			"Rock",
			Vector3.new(s * 1.4, s, s * 1.2),
			centre * CFrame.new(math.cos(angle) * w * 1.2, s * 0.3, math.sin(angle) * w * 1.2),
			SPEC.rock,
			model
		)
	end
	for _, p in model:GetChildren() do
		(p :: BasePart).CastShadow = false
	end
	model.Parent = parent
end

--[[ One cliff: up to three stepped blocks of stone, each narrower and set
     back, grass on each ledge and moss hanging off its front, trees and pines
     along the top. Returns its frame (-Z faces the courtyard) and its tiers
     from the ground up. ]]
local function cliff(
	at: Vector2,
	size: Vector3,
	rng: Random,
	parent: Instance,
	grow: Grow,
	trees: number
): (CFrame, { Step })
	local model = Instance.new("Model")
	model.Name = "BackdropCliff"
	local face = CFrame.lookAt(world(at, OUTSIDE), world(Vector2.zero, OUTSIDE))
	local y = 0
	local shares = { 0.5, 0.3, 0.2 }
	-- each cliff a shade of its own, so the ring never reads as one repeated block
	local shade = rng:NextNumber(-0.12, 0.08)
	local function stoneOf(colour: Color3): Color3
		return colour:Lerp(
			if shade < 0 then Color3.new(0, 0, 0) else Color3.new(1, 1, 1),
			math.abs(shade)
		)
	end
	local topFrame = face
	local steps: { Step } = {}
	for k, share in shares do
		local wide = size.X * (1 - 0.2 * (k - 1))
		local deep = size.Z * (1 - 0.16 * (k - 1))
		local tall = size.Y * share
		local tier = face
			* CFrame.new(rng:NextNumber(-0.08, 0.08) * size.X, y, (k - 1) * size.Z * 0.08)
		part(
			"Stone",
			Vector3.new(wide, tall, deep),
			tier * CFrame.new(0, tall / 2, 0),
			stoneOf(if k % 2 == 1 then SPEC.stone else SPEC.stoneDark),
			model
		)
		part(
			"Ledge",
			Vector3.new(wide + 1, 1.4, deep + 1),
			tier * CFrame.new(0, tall + 0.3, 0),
			SPEC.grass,
			model
		)
		part(
			"Moss",
			Vector3.new(wide * rng:NextNumber(0.5, 0.86), tall * rng:NextNumber(0.1, 0.18), 0.8),
			tier * CFrame.new(rng:NextNumber(-0.15, 0.15) * wide, tall * 0.92, -deep / 2 - 0.3),
			SPEC.mossDark,
			model
		)
		local front = (k - 1) * size.Z * 0.08 - deep / 2
		table.insert(steps, { front = front, base = y, top = y + tall + 1 })
		y += tall
		topFrame = tier * CFrame.new(0, tall + 1, 0)
	end
	for _, p in model:GetChildren() do
		(p :: BasePart).CastShadow = false
	end
	model.Parent = parent

	-- trees and pines along the top, a few on the lower ledges' fronts
	local topWide = size.X * 0.6
	for k = 1, trees do
		local spot = (topFrame * CFrame.new(
			rng:NextNumber(-0.45, 0.45) * topWide,
			0,
			rng:NextNumber(-0.3, 0.3) * size.Z * 0.6
		)).Position
		local flat = Vector2.new(spot.X - ORIGIN.X, spot.Z - ORIGIN.Z)
		if k % 2 == 0 then
			pine(flat, spot.Y - ORIGIN.Y, rng:NextNumber(16, 26), rng, parent)
		else
			grow(flat, rng:NextNumber(1.3, 1.9), rng, parent, spot.Y - ORIGIN.Y)
		end
	end
	return topFrame, steps
end

--[[ Glowing cyan mushrooms on the forest floor round the courtyard, as the
     loading screens light their foregrounds. ]]
local function glowShrooms(rng: Random, parent: Instance)
	local placed = 0
	local tries = 0
	while placed < SPEC.shrooms and tries < SPEC.shrooms * 20 do
		tries += 1
		local angle = rng:NextNumber() * math.pi * 2
		local reach = rng:NextNumber(SPEC.shroomReach.Min, SPEC.shroomReach.Max)
		local at = Vector2.new(math.cos(angle) * reach, math.sin(angle) * reach)
		if LobbyCourtyard.inside(at, -8) then
			continue
		end
		placed += 1
		local model = Instance.new("Model")
		model.Name = "GlowShroom"
		local tall = rng:NextNumber(2.5, 5)
		local foot = CFrame.new(world(at, OUTSIDE))
		part(
			"Stem",
			Vector3.new(tall * 0.3, tall * 0.7, tall * 0.3),
			foot * CFrame.new(0, tall * 0.35, 0),
			SPEC.shroomStem,
			model
		)
		local cap = part(
			"Cap",
			Vector3.new(tall * 1.1, tall * 0.4, tall * 1.1),
			foot * CFrame.new(0, tall * 0.8, 0),
			SPEC.shroomGlow,
			model
		)
		cap.Material = Enum.Material.Neon
		cap.CastShadow = false
		model.Parent = parent
	end
end

--[[ The lot, into `parent`. `grow` is the lobby's tree. ]]
function LobbyBackdrop.build(rng: Random, parent: Instance, grow: Grow)
	local root = Instance.new("Model")
	root.Name = "Backdrop"
	--[[ The far ring first: taller, bare, closing the horizon between the
	     near cliffs so no flat ground shows past them. ]]
	local far = SPEC.far
	for k = 0, far.cliffs - 1 do
		local angle = (k + 0.5 + rng:NextNumber(-0.2, 0.2)) / far.cliffs * math.pi * 2
		local reach = rng:NextNumber(far.reach.Min, far.reach.Max)
		local at = Vector2.new(math.cos(angle) * reach, math.sin(angle) * reach)
		local size = Vector3.new(
			rng:NextNumber(far.wide.Min, far.wide.Max),
			rng:NextNumber(far.tall.Min, far.tall.Max),
			rng:NextNumber(60, 90)
		)
		cliff(at, size, rng, root, grow, 0)
	end
	local count = SPEC.cliffs
	local falls = 0
	for k = 0, count - 1 do
		local angle = (k + rng:NextNumber(-0.25, 0.25)) / count * math.pi * 2
		local reach = rng:NextNumber(SPEC.reach.Min, SPEC.reach.Max)
		local at = Vector2.new(math.cos(angle) * reach, math.sin(angle) * reach)
		-- north (-Z) stands tallest, behind the portals, as the screens' far cliffs do
		local north = math.max(0, -math.sin(angle))
		local tall = rng:NextNumber(SPEC.tall.Min, SPEC.tall.Max) * (0.75 + north * 0.5)
		local size =
			Vector3.new(rng:NextNumber(SPEC.wide.Min, SPEC.wide.Max), tall, rng:NextNumber(40, 60))
		local _, steps = cliff(at, size, rng, root, grow, SPEC.treesOnTop)
		if north > 0.2 and falls < SPEC.falls and k % 2 == 0 then
			falls += 1
			local face = CFrame.lookAt(world(at, OUTSIDE), world(Vector2.zero, OUTSIDE))
			fall(face, steps, rng, root)
		end
	end
	glowShrooms(rng, root)
	root.Parent = parent
end

return LobbyBackdrop
