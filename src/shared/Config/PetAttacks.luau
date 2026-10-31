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
}

return table.freeze(PetAttacks)
