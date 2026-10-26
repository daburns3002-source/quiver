# Pets and weapon skins — Mossy Glade (Act 1, area 1)

The first egg's pet pool. Design only; nothing here is built. The meta loop
these pets live in is `PROGRESSION.md` ("Pets"), the area is `WORLD.md`
(area 1, slimes and Wilfs, boss King Bloblin / the Slime King).

**Style: blocky** (owner, 2026-10-23). Every pet is built from a few chunky
bevelled boxes like Roblox parts, the way pets look in Pet Simulator and
Steal an Egg: a big cube head (as big as the body or bigger), a box body,
short block legs, ears, tails and wings as flat slabs and wedges, flat
colours, and the face as a flat decal (two big shiny eyes and a small
mouth). Those games are a reference for proportions and rarity treatment
only; nothing is copied from them. Colours come from Mossy Glade's own
enemies (`assets/concepts/enemies/act1/`, the Ember Wilf sheet) so the pets
read as the same forest. A blocky pet also suits the pipeline: a handful of
boxes is a tiny triangle count, which helps when several players each trail
three pets through the lobby (`PROGRESSION.md`, "The lobby is a real place").

Concept sheets (Codex, 2026-10-23) are in `assets/concepts/pets/forest/`,
one per pet (front, three-quarter, side, back, an action pose, in-game size,
palette), plus `13_variants.png` (Normal, Golden, Rainbow) and
`14_mossy_egg.png` (the egg, its stand, the hatch, a golden egg).
`contact_sheet.png` puts every pet side by side.

**Wolves are Wilfs** (owner, 2026-10-23): every wolf in the game is named
a Wilf (plural Wilfs), so the Ember Wolf is the Ember Wilf, enemy and pet.

---

## The egg

**Mossy Egg**: one egg, at Mossy Glade's stand in the lobby
(`PROGRESSION.md`: one egg tier per area, bought with that area's coins). A
faceted cream egg with moss patches and a ring of orange mushrooms, on a
mossy stump pedestal. All twelve pets hatch from it. The odds are not set
here: `PROGRESSION.md` names the rarity weights but sets no numbers.

The sheet also shows a **Golden Mossy Egg**. Whether it is a separate egg
(for gems, say) or only a look for a hatch multiplier is *open*.

## Rarity escalation

The tiers are `PROGRESSION.md`'s, and each tier adds something a player can
see from across the lobby:

| Rarity | What it adds |
|---|---|
| Common | flat colours, no glow |
| Uncommon | richer, more saturated colours and one accessory |
| Rare | one glowing part (a lantern, glowing fungus) |
| Epic | glowing markings, a violet rim light, floating motes |
| Legendary | gold trim or a crown, a golden aura, gold sparkles |
| Mythic | floats; an iridescent rainbow sheen, a ring of light, orbiting fireflies |

**Golden** and **Rainbow** variants (`PROGRESSION.md`) sit on top of any
rarity with the silhouette unchanged: Golden is the whole pet in polished
gold with a gold glow; Rainbow is a pastel iridescent gradient with a
rainbow glow and star sparkles (`13_variants.png`).

## The pets

| # | Pet | Rarity | Look | Ties to the area |
|---|---|---|---|---|
| 1 | **Mosslet** | Common | a lime jelly cube with a moss slab, one orange mushroom and a sprout | a baby Moss Slime |
| 2 | **Babacorn** | Common | a brown cube in a blocky acorn-cap beanie, pink cheeks | the glade's oaks |
| 3 | **Fern Frog** | Common | a wide sage-green box frog, cube eyes on top, a fern frond cowlick | the pond room |
| 4 | **Toadstool Tot** | Uncommon | a cream cube under an oversized red, white-spotted cap; leaf satchel | the mushrooms on every slime |
| 5 | **Mossback Snail** | Uncommon | a mint box snail carrying a mossy stone-cube shell | the boulders room |
| 6 | **Firefly Bun** | Rare | a navy-and-teal block firefly with a glowing yellow cube lantern | the glade's orb lamps |
| 7 | **Stumpy** | Rare | a square tree stump with growth rings, a sapling and glowing teal fungus | the logs room |
| 8 | **Glade Fox** | Epic | a moss-green box fox with a leaf-slab tail and glowing cheek runes | a forest cousin of the Wilfs |
| 9 | **Hootmoss** | Epic | a tall box owl, mushroom ear tufts, glowing amber eyes | night in the glade |
| 10 | **Slime Prince** | Legendary | a glowing emerald jelly cube with a gold crown and a leaf cape | heir to the area's boss, the Slime King |
| 11 | **Ember Wilf** | Legendary | the Ember Wilf as a blocky pup, ear and tail tips glowing like embers | the area's Wilf, from room 6; the first of the ten area Wilfs (`PETS-WILFS.md`) |
| 12 | **Glimmerhorn** | Mythic | a floating block fawn with branch antlers and rainbow-glowing spots | the spirit of the glade |

Three Commons, then two per tier up to Legendary, and one Mythic, so most
hatches are Commons and every tier has a choice in it.

## Attacks

Each pet's one combat behaviour (`PROGRESSION.md`: shoots, heals, collects,
tanks), chosen by the owner on 2026-10-24 ("i like all of these"). Each
pet's Claude Design model carries an **Attack** clip of it (owner: "low
complexity except for the legendarys and mythics. those should look cool"):
the lower tiers move only the pet's own parts; the Legendaries and the Mythic
add effect pieces (`Fx_*` nodes, invisible at scale 0 outside the clip).
Attack plays once; every other clip loops (`assets/models/model_clips.json`).
The behaviours themselves are not built yet: a clip is the look, the
numbers and the pet system are Phase 6.

| Pet | Rarity | Role | Attack |
|---|---|---|---|
| Mosslet | Common | Shoots | **Slime Glob**: lobs a slime blob every 2 s that leaves a puddle, briefly slowing enemies |
| Babacorn | Common | Shoots | **Acorn Flick**: a quick burst of three small acorn pellets at the nearest enemy |
| Fern Frog | Common | Shoots | **Tongue Snap**: a short, hard-hitting tongue lash that tugs small enemies toward it |
| Toadstool Tot | Uncommon | Heals | **Spore Patch**: every 20 s drops a glowing mushroom ring that heals you while you stand in it |
| Mossback Snail | Uncommon | Tanks | **Shell Guard**: once per room its shell flies in front of you and blocks one hit |
| Firefly Bun | Rare | Collects | **Lantern Lure**: pulls XP crystals and coins in from across the room; its light marks one enemy to take extra damage |
| Stumpy | Rare | Controls | **Root Snare**: roots burst round the nearest enemy's feet every 4 s and hold it where it stands for 1.75 s: no walking, lunging, diving or sliding with a hit, though it still attacks from there; the roots stay round it for the whole hold. Bosses are not held (owner, 2026-10-26: "stumpy needs to hold enemies in place"; `Shared/Util/RootHold`, `Fx/RootHoldFx`) |
| Glade Fox | Epic | Shoots | **Leaf Dash**: dashes to up to three enemies in turn, slashing each as it lands, then runs back (owner, 2026-10-25: it runs round cover, never through it; `Shared/Util/PetDash`) |
| Hootmoss | Epic | Shoots | **Feather Volley**: homing feathers fired from above that fly over walls and cover |
| Slime Prince | Legendary | Summons | **Royal Court**: summons two mini slimes that bounce into enemies, and a crown shockwave against bosses |
| Ember Wilf | Legendary | Shoots | **Ember Bite**: fire bolts that set enemies burning (stacks with Blaze), and a howl that briefly speeds up your attacks |
| Glimmerhorn | Mythic | Shoots, heals | **Prism Beam**: a sweeping rainbow beam that pierces every enemy in a line and heals you a little per hit; once per run it revives you |

**Projectiles and effects** (owner, 2026-10-24: "i need projectiles for all of the attacks that
need it and i need visual effects for the legendaries and the mythics"). Codex sheets in
`assets/concepts/pets/attacks/`; built in Claude Design (projects "Mossy Glade Projectiles" and
"Pet Attack VFX"), one GLB per piece in `assets/models/effects/fx_pet_*.glb`, slimmed by
`optimise_effect.py` (11 to 33 parts each). Common to Epic: Slime Glob (with its puddle), Acorn
Pellet, Tongue Lash, Spore Patch, Lure Mark, Root Snare, Leaf Slash, Feather Dart (the Mossback
Snail's guard is its own shell). Legendary and Mythic: Mini Slime and Crown Shockwave (Slime
Prince); Ember Bolt, Burning Mark and Howl Aura (Ember Wilf); Prism Beam, Heal Sparkles and
Revive Burst (Glimmerhorn). `Config/PetAttacks` says which pieces each attack fires, when and
how they move; `Fx/PetAttackFx` plays them (the sandbox's PET ATTACK).

## Weapon skins

Asked for alongside the pets (owner, 2026-10-23): forest skins for each
class's weapon, in the same blocky style and on the same rarity ladder.
Every skin keeps its weapon's silhouette (`assets/concepts/weapons/`), so it
sits in the same hand. Sheets are in `assets/concepts/weapons/skins/forest/`.

**Every weapon and every skin has its own animations** (owner,
2026-10-23): its own R15 kit, with the class's clip names and markers so
the game plays and times it the same way (`docs/PIPELINES.md` §5), but
moving in its own manner. Never the base weapon's clips reused. **Epic and
above also get their own projectile and projectile trail.** Every weapon
is made with its own projectile model, except the swords (melee).

The Duelist's daggers (the open alternative to the Warden, `docs/WORLD.md`)
have their Mossy Glade ladder too: blocky sheet
`assets/concepts/blocky/weapons/skins/forest/w4_dagger_skins.png` (Codex,
2026-10-23), each pair drawn with its projectile, an **arcing slash** (a
blocky crescent blade wave, owner), and, from Rare up, its trail. Purple stays the Duelist's accent.

| Rarity | Ranger bow | Arcanist staff | Warden greatsword | Duelist daggers |
|---|---|---|---|---|
| Common | Twig Bow | Branch Staff | Timber Blade | Splinter Daggers |
| Uncommon | Acorn Bow | Toadstool Staff | Mossstone Blade | Bramble Shivs |
| Rare | Firefly Bow | Lantern Staff | Thorn Blade | Firefly Fangs |
| Epic | Moss Slime Bow | Hootmoss Staff | Broodsplit Blade | Glade Fox Claws |
| Legendary | Ember Fang Bow | Slime Crown Staff | Emberfang Blade | Ember Wilf Fangs |
| Mythic | Glade Spirit Bow | Worldroot Staff | Gladeheart Blade | Glimmerhorn Daggers |

How skins are earned (hatched, bought, boss drops) is *open*;
`PROGRESSION.md` names "gear" but not skins. A skin is a look only unless
the owner decides otherwise.

## Open decisions (the owner's)

1. **Which pets go to 3D first.** The Mosslet, the Slime Prince and the
   Ember Wilf tie most closely to the area; the Glimmerhorn shows the top of
   the ladder.
2. **The Golden Mossy Egg**: a second egg, or only a look.
3. ~~**Combat behaviour per pet**~~ Chosen 2026-10-24: see *Attacks*.
4. **How weapon skins are earned**, and which go to 3D first.
