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
| 2 | **Acorn Pip** | Common | a brown cube in a blocky acorn-cap beanie, pink cheeks | the glade's oaks |
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
3. **Combat behaviour per pet** (`PROGRESSION.md`: each pet shoots, heals,
   collects or tanks a hit). Not assigned here, since none of those
   behaviours is designed yet.
4. **How weapon skins are earned**, and which go to 3D first.
