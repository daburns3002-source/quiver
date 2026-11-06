--!strict
--[[
	What each pet's Attack throws or shows (docs/PETS-FOREST.md, Attacks):
	the effect pieces (`Config/ImportedModels/FxPet*`, from Claude Design,
	assets/models/effects/), when in the pet's Attack clip each one fires, and
	how it moves. Played by `Fx/PetAttackFx`; for now the Studio sandbox's PET
	ATTACK button is the only caller, a look at the attacks before Phase 6's
	pet combat decides who they hit.

	Kinds:
	- Projectile: flies from the pet to an enemy (`speed`, an `arc` up to that
	  peak height, `homing` to follow a moving one), then plays `impact`.
	- Reach: from the pet toward an enemy, held there (a tongue, a beam;
	  `sweep` turns it through that many degrees over its life).
	- Ground: on the floor under an enemy (`targets` of them), or under the
	  pet with none.
	- Overhead: `lift` studs above an enemy, riding it.
	- Owner: on the floor under the pet's owner, riding them (`sweep` turns
	  it as it rides, for a ring).
	- Hold: round the feet of each enemy the attack holds, for as long as
	  the server holds it (`root`, `Fx/RootHoldFx`), its clip stretched over
	  the hold; not played by `Fx/PetAttackFx`. Its `at` is still when the
	  attack lands.
]]

export type Kind = "Projectile" | "Reach" | "Ground" | "Overhead" | "Owner" | "Hold"

export type Impact = { effect: string, clip: string?, life: number }

export type Shot = {
	effect: string,
	clip: string?,
	kind: Kind,
	--[[ Seconds into the pet's Attack clip it fires. ]]
	at: number,
	--[[ How many, `every` seconds apart, fanned `spread` degrees apart. ]]
	count: number?,
	every: number?,
	spread: number?,
	speed: number?,
	arc: number?,
	homing: boolean?,
	lift: number?,
	--[[ Seconds a Reach, Ground, Overhead or Owner piece stays. ]]
	life: number?,
	--[[ Degrees a Reach or Owner piece turns through over its life. ]]
	sweep: number?,
	--[[ A Reach piece modelled pointing back along +Z (the Fern Frog's
	     tongue): turned half round so it reaches toward the enemy. ]]
	flip: boolean?,
	targets: number?,
	impact: Impact?,
	--[[ Which enemy goes first, for a pet that does not pick the nearest
	     (`Shared/Util/PetCrowd`): the furthest (the Cave Cricket), or the
	     one with the most others within `aimRadius` (the Gulpling). ]]
	aim: ("Farthest" | "Densest")?,
	aimRadius: number?,
}

local PetAttacks: { [string]: { Shot } } = {
	Mosslet = {
		{
			effect = "FxPetSlimeGlob",
			clip = "Fly",
			kind = "Projectile",
			at = 0.4,
			speed = 20,
			arc = 3,
			impact = { effect = "FxPetSlimeGlob", clip = "Splat", life = 2 },
		},
	},
	Babacorn = {
		{
			effect = "FxPetAcornPellet",
			clip = "Spin",
			kind = "Projectile",
			at = 0.1,
			count = 3,
			every = 0.2,
			speed = 34,
		},
	},
	FernFrog = {
		{
			effect = "FxPetTongueLash",
			clip = "Lash",
			kind = "Reach",
			at = 0.2,
			life = 0.5,
			flip = true,
		},
	},
	ToadstoolTot = {
		{ effect = "FxPetSporePatch", clip = "Play", kind = "Owner", at = 0.4, life = 3 },
	},
	-- the Mossback Snail's guard is its own shell: no piece
	FireflyBun = {
		{
			effect = "FxPetLureMark",
			clip = "Spin",
			kind = "Overhead",
			at = 0.5,
			lift = 4.5,
			life = 3,
		},
	},
	Stumpy = {
		-- on the enemy it holds, for the whole hold (owner, 2026-10-26)
		{ effect = "FxPetRootSnare", clip = "Snare", kind = "Hold", at = 0.45 },
	},
	GladeFox = {
		{
			effect = "FxPetLeafSlash",
			clip = "Slash",
			kind = "Ground",
			at = 0.3,
			lift = 1.2,
			life = 0.35,
			targets = 3,
			every = 0.12,
		},
	},
	Hootmoss = {
		{
			effect = "FxPetFeatherDart",
			clip = "Fly",
			kind = "Projectile",
			at = 0.25,
			count = 3,
			every = 0.15,
			spread = 25,
			speed = 26,
			arc = 4,
			homing = true,
		},
	},
	SlimePrince = {
		{
			effect = "FxPetMiniSlime",
			clip = "Bounce",
			kind = "Projectile",
			at = 0.5,
			count = 2,
			spread = 50,
			speed = 12,
			arc = 4,
			impact = { effect = "FxPetMiniSlime", clip = "Splash", life = 0.5 },
		},
		{
			effect = "FxPetCrownShockwave",
			clip = "Play",
			kind = "Ground",
			at = 1.0,
			life = 1.2,
			targets = 0,
		},
	},
	EmberWilfPet = {
		{
			effect = "FxPetEmberBolt",
			clip = "Fly",
			kind = "Projectile",
			at = 0.55,
			count = 3,
			spread = 18,
			speed = 30,
			impact = { effect = "FxPetBurningMark", clip = "Burn", life = 2 },
		},
		{ effect = "FxPetHowlAura", clip = "Play", kind = "Owner", at = 1.1, life = 2 },
	},
	Glimmerhorn = {
		{
			effect = "FxPetPrismBeam",
			clip = "Fire",
			kind = "Reach",
			at = 0.7,
			life = 1.2,
			sweep = 60,
		},
		{ effect = "FxPetHealSparkles", clip = "Play", kind = "Owner", at = 1.4, life = 1.2 },
		-- its once-a-run revive, shown at the end so it can be seen
		{ effect = "FxPetReviveBurst", clip = "Play", kind = "Owner", at = 2.2, life = 1.6 },
	},

	--[[ Thornwood (area 2). Every piece here is a Mossy Glade effect
	     standing in: the area's own `FxPet` models are not made yet, so a
	     Thornwood pet throws the forest's thorn-shaped pieces rather than
	     nothing at all. Swapping them later is one `effect` name each.

	     Each of these pets has a one-second Attack clip, where the forest's
	     run longer, so every piece fires inside that second -- the Glade's
	     habit of trailing a second effect a beat later (Glimmerhorn's heal
	     at 1.4 s) would simply never play here. ]]

	-- it rams: the hit shows on the floor, not in the air
	BarkHoglet = {
		{
			effect = "FxPetLeafSlash",
			clip = "Slash",
			kind = "Ground",
			at = 0.3,
			lift = 1.2,
			life = 0.35,
		},
	},
	Burrball = {
		{
			effect = "FxPetAcornPellet",
			clip = "Spin",
			kind = "Projectile",
			at = 0.1,
			count = 3,
			every = 0.2,
			speed = 34,
		},
	},
	Budbulb = {
		{
			effect = "FxPetSlimeGlob",
			clip = "Fly",
			kind = "Projectile",
			at = 0.35,
			speed = 20,
			arc = 3,
			impact = { effect = "FxPetSlimeGlob", clip = "Splat", life = 2 },
		},
	},
	BerryMouse = {
		{ effect = "FxPetSporePatch", clip = "Play", kind = "Owner", at = 0.4, life = 3 },
	},
	--[[ The Thistle Mole's shell answers (`PetCombat` `reflect`), so unlike
	     the Snail's it has a piece: the thorns going out off its owner as it
	     blocks. Played when the shell blocks rather than on a clock, from
	     the same `Remotes.PetAttack` the Snail's flight uses. ]]
	ThistleMole = {
		{ effect = "FxPetCrownShockwave", clip = "Play", kind = "Owner", at = 0.1, life = 0.8 },
	},
	--[[ Its hold jumps to a second enemy (`chain`), and the Hold piece is
	     drawn round every enemy the attack holds, so both get their roots
	     without a second entry. The vines across the floor say where it
	     jumped. ]]
	BriarBeetle = {
		{
			effect = "FxPetLeafSlash",
			clip = "Slash",
			kind = "Ground",
			at = 0.4,
			life = 0.45,
			targets = 2,
			every = 0.08,
		},
		{ effect = "FxPetRootSnare", clip = "Snare", kind = "Hold", at = 0.45 },
	},
	--[[ Blood Berry: a berry thrown, and the owner fed as it bursts. The
	     mark it used to hang over an enemy is gone with the spec's
	     (`healPerHit` now). ]]
	BerryBat = {
		{
			effect = "FxPetSlimeGlob",
			clip = "Fly",
			kind = "Projectile",
			at = 0.3,
			speed = 32,
			impact = { effect = "FxPetSlimeGlob", clip = "Splat", life = 0.8 },
		},
		{ effect = "FxPetHealSparkles", clip = "Play", kind = "Owner", at = 0.55, life = 0.9 },
	},
	BrambleBear = {
		{
			effect = "FxPetLeafSlash",
			clip = "Slash",
			kind = "Ground",
			at = 0.3,
			lift = 1.2,
			life = 0.35,
			targets = 3,
			every = 0.12,
		},
	},
	BriarLynx = {
		{
			effect = "FxPetFeatherDart",
			clip = "Fly",
			kind = "Projectile",
			at = 0.25,
			count = 4,
			every = 0.12,
			spread = 25,
			speed = 26,
			arc = 4,
			homing = true,
		},
	},
	BrambleWilf = {
		{
			effect = "FxPetEmberBolt",
			clip = "Fly",
			kind = "Projectile",
			at = 0.45,
			count = 3,
			spread = 18,
			speed = 30,
			-- a thorn going in, standing in for art of its own (`bleed`)
			impact = { effect = "FxPetBurningMark", clip = "Burn", life = 2 },
		},
		{ effect = "FxPetHowlAura", clip = "Play", kind = "Owner", at = 0.8, life = 2 },
	},
	ThornPrincess = {
		{
			effect = "FxPetMiniSlime",
			clip = "Bounce",
			kind = "Projectile",
			at = 0.4,
			count = 2,
			spread = 50,
			speed = 12,
			arc = 4,
			impact = { effect = "FxPetMiniSlime", clip = "Splash", life = 0.5 },
		},
		--[[ The cage coming down (`root`, and a `boss` above 0): the
		     shockwave now lands on the enemy rather than under her, since it
		     is what holds it. Its Hold piece is drawn round the held
		     enemy's feet for as long as the server holds it. ]]
		{
			effect = "FxPetCrownShockwave",
			clip = "Play",
			kind = "Ground",
			at = 0.45,
			life = 1.2,
			targets = 2,
		},
		{ effect = "FxPetRootSnare", clip = "Snare", kind = "Hold", at = 0.4 },
	},
	--[[ The Wake (`aura`): a ring turning round its owner, not a beam. It
	     lives as long as the ring does, so the pet raising it again every
	     three seconds reads as one unbroken ring rather than a flicker, and
	     the howl under it is the moment it is raised.

	     Its revive has no piece: the Glimmerhorn shows one at 2.2 s and this
	     clip is over at 1.0, so there is nowhere to put it until Thornwake
	     has an Attack long enough or a burst of its own. ]]
	Thornwake = {
		{
			effect = "FxPetCrownShockwave",
			clip = "Play",
			kind = "Owner",
			at = 0.25,
			life = 3,
			sweep = 360,
		},
		{ effect = "FxPetHowlAura", clip = "Play", kind = "Owner", at = 0.2, life = 1 },
	},
	--[[ The Drowned Village's five (2026-11-04). They could have no pieces
	     until they had clips to hang them on: each came out of Tripo as one
	     static mesh, so `Config/ModelClips` had no entry and
	     `tests/PetAttacks.spec` rightly refused an attack the preview could
	     not show. `tools/pet_motions.py` gave them motion, and these are the
	     pieces that motion was timed for.

	     Every effect below is a Mossy Glade or Thornwood piece standing in,
	     the way Thornwood's own pets borrowed glade art before they were
	     redrawn. The seven that replace them are designed
	     (`docs/PETS-DROWNED.md`, The seven effect pieces, and the sheet
	     `assets/concepts/pets/attacks/drowned_pieces.png`) and wait on
	     Claude Design: Tentacle Sting, Accord Mark, Spine Burst, Ink Squirt,
	     Ink Cloud, Slate Shelter, Tide Slash. Swap each name in here as its
	     GLB lands. ]]
	AbyssJelly = {
		--[[ Three stings on the three pulses of its Attack clip (0.14, 0.54,
		     0.94), one a hit: `PetCombat` gives it hits = 3. A lash standing
		     in for a tentacle. ]]
		{
			effect = "FxPetTongueLash",
			clip = "Lash",
			kind = "Reach",
			at = 0.14,
			count = 3,
			every = 0.4,
			life = 0.4,
			sweep = 35,
		},
		--[[ The canopy: `accord` shares a blow among 3 enemies for 4 s, so
		     the mark is drawn under each of the three and lasts exactly as
		     long as the sharing does. Ground, not Overhead -- only Ground
		     reads `targets`; Overhead draws on the nearest enemy alone. ]]
		{
			effect = "FxPetLureMark",
			clip = "Spin",
			kind = "Ground",
			at = 0.14,
			life = 4,
			targets = 3,
		},
	},
	--[[ The puff itself, under the pet, at the top of its swell (0.3). Its
	     damage is payback for a hit already taken (`reflect`), so nothing
	     flies out at an enemy: the burst is the whole of it. ]]
	BuoyPuffer = {
		{ effect = "FxPetCrownShockwave", clip = "Play", kind = "Ground", at = 0.3, life = 0.9 },
	},
	--[[ The squirt leaves on the spit (0.38) and lands as a patch that sits
	     for the 3 s the blind lasts (`EnemyManager.blind`). A glob and a
	     spore patch standing in for ink. ]]
	Inkpot = {
		{
			effect = "FxPetSlimeGlob",
			clip = "Fly",
			kind = "Projectile",
			at = 0.38,
			speed = 24,
			arc = 2,
			homing = true,
			impact = { effect = "FxPetSporePatch", clip = "Play", life = 3 },
		},
	},
	--[[ The shelter is cast on the owner, not an enemy, so it is an Owner
	     piece: raised as the turtle hunkers (0.25) and held the 3 s
	     `Util/Shelter` cuts damage for. ]]
	SlateTurtle = {
		{
			effect = "FxPetHowlAura",
			clip = "Play",
			kind = "Owner",
			at = 0.25,
			life = 3,
			sweep = 180,
		},
	},
	--[[ One slash at the far end of the lunge (0.42), where the clip puts
	     the pet nearest the enemy. Its reach is 3 studs, so nothing flies. ]]
	TideWilf = {
		{
			effect = "FxPetLeafSlash",
			clip = "Slash",
			kind = "Reach",
			at = 0.42,
			life = 0.35,
			sweep = 70,
		},
	},

	--[[ Bogheart Caverns (docs/PETS-BOGHEART.md, Attacks). Every effect
	     here is an earlier area's piece standing in, as the Drowned
	     Village's did before its own; the Bogheart pieces still to make
	     are listed in the doc. Times match each pet's Attack clip in
	     assets/models/pet_motions.json. ]]
	--[[ Long Chirp: a chirp flung at the furthest enemy as the cricket
	     lands its hop (0.32). A feather dart stands in for a sound ring. ]]
	CaveCricket = {
		{
			effect = "FxPetFeatherDart",
			clip = "Fly",
			kind = "Projectile",
			at = 0.32,
			speed = 44,
			arc = 3,
			homing = true,
			aim = "Farthest",
		},
	},
	--[[ Fourth Lick: a quick lick at the end of the skitter (0.3); its
	     reach is 16 studs, so nothing flies. ]]
	LichenGecko = {
		{
			effect = "FxPetTongueLash",
			clip = "Lash",
			kind = "Reach",
			at = 0.3,
			life = 0.3,
			flip = true,
		},
	},
	--[[ Mud Plaster: on the owner as the beaver slaps its tail (0.35),
	     held the 6 s the coat can last. A howl ring stands in for mud. ]]
	BogBeaver = {
		{
			effect = "FxPetHowlAura",
			clip = "Play",
			kind = "Owner",
			at = 0.35,
			life = 6,
			sweep = 90,
		},
	},
	--[[ Glow Mote: the mote rides its target from the lure flash (0.35)
	     for the 1.5 s fuse, and the burst goes off under it at 1.85, when
	     `Combat/PetCombat` lands it. ]]
	Lanternfin = {
		{
			effect = "FxPetLureMark",
			clip = "Spin",
			kind = "Overhead",
			at = 0.35,
			lift = 1.2,
			life = 1.5,
		},
		{
			effect = "FxPetCrownShockwave",
			clip = "Play",
			kind = "Ground",
			at = 1.85,
			life = 0.8,
		},
	},
	--[[ Tremor Snap: a ripple under its target as the olm slaps the
	     ground (0.4). The blow lands at once. ]]
	Olm = {
		{
			effect = "FxPetCrownShockwave",
			clip = "Play",
			kind = "Ground",
			at = 0.4,
			life = 0.7,
		},
	},
	--[[ Spore Sneeze: the wedge thrown on the sneeze (0.5), turned
	     through its 60 degrees. A leaf slash stands in for spores. ]]
	GlowcapWilf = {
		{
			effect = "FxPetLeafSlash",
			clip = "Slash",
			kind = "Reach",
			at = 0.5,
			life = 0.4,
			sweep = 60,
		},
	},
	--[[ Little Belly Flop: the landing ring under the biggest crowd as
	     the gulpling comes down (0.55). ]]
	Gulpling = {
		{
			effect = "FxPetCrownShockwave",
			clip = "Play",
			kind = "Ground",
			at = 0.55,
			life = 0.9,
			aim = "Densest",
			aimRadius = 7,
		},
	},
	--[[ Prism Split: a crystal bolt from the coil's strike (0.45) that
	     shatters where it lands; the server lands the bolt and its shards
	     as the piece arrives (`Shared/Combat/PetShots`). An ember bolt and
	     a crown flash stand in. ]]
	PrismLeviathan = {
		{
			effect = "FxPetEmberBolt",
			clip = "Fly",
			kind = "Projectile",
			at = 0.45,
			speed = 40,
			arc = 1,
			homing = true,
			impact = { effect = "FxPetCrownShockwave", clip = "Play", life = 0.6 },
		},
	},
}

return table.freeze(PetAttacks)
