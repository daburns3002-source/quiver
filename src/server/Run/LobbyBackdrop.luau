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
	pouring off the faces into pools, a ruined tower and its aqueduct on the
	highest cliff, and glowing cyan mushrooms on the forest floor. This builds
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

--[[ A fall down the face of a cliff `tall` high, its foot in a round pool:
     the water, a paler streak down it, foam where it lands. `face` is the
     cliff's frame, its -Z the face. ]]
local function fall(face: CFrame, deep: number, tall: number, wide: number, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "BackdropFall"
	local front = face * CFrame.new(0, 0, -deep / 2 - 0.8)
	local water = part(
		"Water",
		Vector3.new(wide, tall, 1),
		front * CFrame.new(0, tall / 2, 0),
		SPEC.water,
		model
	)
	water.Transparency = 0.12
	local shine = part(
		"Shine",
		Vector3.new(wide * 0.18, tall, 1.1),
		front * CFrame.new(-wide * 0.2, tall / 2, -0.1),
		SPEC.foam,
		model
	)
	shine.Transparency = 0.35
	local pool = part(
		"Pool",
		Vector3.new(0.4, wide * 3, wide * 3),
		front * CFrame.new(0, 0.2, -wide * 1.2) * CFrame.Angles(0, 0, math.pi / 2),
		SPEC.pool,
		model,
		Enum.PartType.Cylinder
	)
	pool.Transparency = 0.05
	for k = -2, 2 do
		blob(
			"Foam",
			Vector3.new(wide * 0.5, wide * 0.3, wide * 0.5),
			front * CFrame.new(k * wide * 0.22, 0.8, -wide * 0.25),
			SPEC.foam,
			model
		).Transparency =
			0.15
	end
	model.Parent = parent
end

--[[ The ruined tower and the broken run of aqueduct beside it, on the top of
     the highest cliff, both facing the courtyard as the loading screens draw
     them over the falls. `top` is the cliff top's frame. ]]
local function ruin(top: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "BackdropRuin"
	local stone, dark = SPEC.ruin, SPEC.ruinDark
	-- the tower, its arched windows and its broken crown
	local tower = top * CFrame.new(-18, 0, 4)
	part("Tower", Vector3.new(16, 52, 16), tower * CFrame.new(0, 26, 0), stone, model)
	for k = 0, 1 do
		part(
			"Window",
			Vector3.new(4, 8, 0.6),
			tower * CFrame.new(0, 22 + k * 16, -8.1),
			dark,
			model
		)
	end
	for k, x in { -6, -2, 2, 6 } do
		if k ~= 3 then
			part("Merlon", Vector3.new(3, 4, 3), tower * CFrame.new(x, 54, -6.5), stone, model)
			part(
				"Merlon",
				Vector3.new(3, 4, 3),
				tower * CFrame.new(x, 54 - (k % 2) * 2, 6.5),
				stone,
				model
			)
		end
	end
	part("TowerMoss", Vector3.new(16.6, 6, 16.6), tower * CFrame.new(0, 3, 0), SPEC.mossDark, model)
	-- the aqueduct: piers, a deck, and the dark under each arch
	local run = top * CFrame.new(14, 0, 6)
	local bays = 4
	local bay = 11
	for k = 0, bays do
		local x = (k - bays / 2) * bay
		local tall = if k == bays then 22 else 34
		part("Pier", Vector3.new(3.4, tall, 5), run * CFrame.new(x, tall / 2, 0), stone, model)
	end
	part(
		"Deck",
		Vector3.new(bay * (bays - 1) + 3.4, 4, 5),
		run * CFrame.new(-bay / 2, 36, 0),
		stone,
		model
	)
	for k = 0, bays - 2 do
		local x = (k - bays / 2 + 0.5) * bay
		part(
			"ArchDark",
			Vector3.new(bay - 3.4, 26, 0.6),
			run * CFrame.new(x, 13, -2.2),
			dark,
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
     along the top. Returns its frame (-Z faces the courtyard), its depth and
     how high its top stands above the ground. ]]
local function cliff(
	at: Vector2,
	size: Vector3,
	rng: Random,
	parent: Instance,
	grow: Grow,
	trees: number
): (CFrame, number, number)
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
	return topFrame, size.Z, y
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
	local highest: CFrame? = nil
	local highestTall = 0
	for k = 0, count - 1 do
		local angle = (k + rng:NextNumber(-0.25, 0.25)) / count * math.pi * 2
		local reach = rng:NextNumber(SPEC.reach.Min, SPEC.reach.Max)
		local at = Vector2.new(math.cos(angle) * reach, math.sin(angle) * reach)
		-- north (-Z) stands tallest, behind the portals, as the screens' far cliffs do
		local north = math.max(0, -math.sin(angle))
		local tall = rng:NextNumber(SPEC.tall.Min, SPEC.tall.Max) * (0.75 + north * 0.5)
		local size =
			Vector3.new(rng:NextNumber(SPEC.wide.Min, SPEC.wide.Max), tall, rng:NextNumber(40, 60))
		local top, deep, height = cliff(at, size, rng, root, grow, SPEC.treesOnTop)
		if north > 0.2 and falls < SPEC.falls and k % 2 == 0 then
			falls += 1
			local face = CFrame.lookAt(world(at, OUTSIDE), world(Vector2.zero, OUTSIDE))
			fall(face, deep, height, rng:NextNumber(8, 14), root)
		end
		if height > highestTall and north > 0.5 then
			highestTall = height
			highest = top
		end
	end
	if highest then
		ruin(highest, root)
	end
	glowShrooms(rng, root)
	root.Parent = parent
end

return LobbyBackdrop
