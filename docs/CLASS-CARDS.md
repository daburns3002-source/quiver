# Class cards: the Warden's and the Arcanist's

Owner, 2026-10-23: "start working on the upgrades for the warden and the
arcanist class. make the upgrades and give me ideas for them just like you
did for the ranger. i want icons generated as well for each upgrade with
codex." This picks option C of `docs/WARDEN-CARDS.md` (a card set per class).

## The 2026-10-25 trim (the owner, after the class run-throughs)

`Config/Abilities` is the source of truth; the lists below predate this.

- **Benched** (never dealt, effects kept): Agility, Mending, Iron Skin,
  Steadfast, Bloodletting, Swift Arrows, Long Shot (and Momentum, earlier).
- **Intellect**, the Arcanist's Strength: the same card and effect under its
  own name and icon; Strength is now the Ranger's and the Warden's.
- **Diagonal Orbs**, the Arcanist's Diagonal Arrows: the same effect, its
  own name and icon.
- **Soul Chain for every class**: orbs link as arrows do, and a Warden's
  blow links through `Combat/SoulLink`.
- Descriptions: Front Arrow "Fire another arrow.", Double Shot "Fire another
  arrow in a narrow spread."
- The Warden lost Iron Skin, Steadfast and Bloodletting, and gained four
  (the owner's picks from six ideas; Rend and Shield Bash were turned down):
  - **Whirlwind** (Epic): every 4th / 3rd swing is a spin hitting everything
    within `Balance.Player.whirlwind.radius`, drawn as a ring of cubes.
  - **Shockwave** (Rare): the slam's wave rolls 8 / 12 / 16 studs down a lane,
    each enemy hit for a share of the slam as the wave arrives, drawn as earth
    cubes bursting up in turn.
  - **Battle Cry** (Legendary): +5% / +10% attack speed per kill, up to 5
    stacks, lapsing 4 s after the last kill; server-side, like the Ember
    Wilf's howl.
  - **Parry** (Epic): side blows (and the slam at level 2) destroy enemy shots
    in their shape.
  Whirlwind, Shockwave and Battle Cry have sounds waiting on the owner's picks
  (audition round 19).

## Every class a ladder of four (owner's pick C, 2026-11-13)

Owner: "ALSO OPEN A SESSION ABOUT UPGRADES FOR EACH CLASS"; three options were drawn up
(https://claude.ai/artifact/GtaYeXMmNJLiCgb9MbHKNR) and the owner picked **C**: every class gets a
class upgrade at Rare, Epic, Legendary and Mythic, and the pools are evened out. Then, as Sniper
Shot first read like Overdraw: "sniper shot and wind arrows, sniper shot should replace overdraw".
So Overdraw is benched and Wind Arrows came in as well. Pools now: Ranger 17, Arcanist 16, Warden 16
(`tests/ClassCards.spec` keeps them within a card of each other).

| Card | Class | Rarity | What it does |
|---|---|---|---|
| Sniper Shot | Ranger | Rare | Stand still 3 s (and 3 s after each one) and the next volley also fires a gold sniper arrow, 1.4x an arrow's speed, through every enemy to the wall, 0.75x and always a crit. A gold cross glints over the archer while it is ready. |
| Split Shot | Ranger | Epic | An arrow that kills sends 3 green splinters on from the kill, 25 degrees apart, 0.4x each, 14 studs. Splinters never split. |
| Wind Arrows | Ranger | Uncommon | A hit shoves the enemy its own knockback again; enemy shots within 1.6 studs of a flying arrow are blown away (the Parry path), with a puff. |
| Mana Surge | Arcanist | Rare | A kill charges the staff (a blue flare); the next cast deals 1.5x and its blast is 1.5x wide, drawn in a big blue shell. |
| Frost Orb | Arcanist | Uncommon | Orbs slow what they hit by 25% / 40% for 2 s; a chilled enemy has ice round its feet (`FrostUntil`, any orb's slow, Elemental ice too). |
| Arcane Shield | Arcanist | Uncommon | A ring of violet panels blocks one hit whole, then comes back in 10 s / about 7 (its level is shields a second, so levels rise). |
| Shield Throw | Warden | Rare | The dash throws a shield at the nearest enemy within 22 studs, then on to the nearest not yet struck within 14, 3 hits of 0.5x, each landing as the shield arrives, and home. Shares Earthbreaker's dash check. |
| Blade Storm | Warden | Legendary | Every 5th blow that lands throws the sword 12 studs along the swing and back in 0.9 s (stopped by cover), striking each enemy once out and once back, 0.7x a pass. |
| Sunder | Warden | Rare | What a blow strikes takes +10% / +20% damage from everything for 3 s; red cracks over it (`SunderedUntil`). |

Server: `Combat/ClassUpgrades` (Sniper Shot, Mana Surge's spend, Shield Throw's hops, Blade
Storm's swords, and `dress` for Split Shot, Wind Arrows and Frost Orb), `Combat/ProjectileSystem`
(splinters, gusts), `Run/RunSession` (Arcane Shield, Mana Surge's charge),
`Enemies/EnemyManager` (`sunder`, `knock`, the frost mark). Numbers in `Balance.Player`
(`sniper`, `splitShot`, `wind`, `manaSurge`, `frost`, `shieldThrow`, `bladeStorm`, `sunder`).
Client: `Fx/Upgrades/ClassCardFx`, voxel cubes like the rest. Icons: Codex
(`assets/concepts/blocky/ui/cards/class_upgrades_2026_11_13.sh`, the prompts beside them),
composed by `compose_icon.py`. Sounds: all fourteen class upgrades (the seven of 2026-10-27, silent until now, and the seven new cards')
picked by the owner over audition rounds 28-32 (https://claude.ai/artifact/VRaauboDkF7i5kY9gNwBHK) and
joined into one sprite, one upload (`Config/Sounds` `CLASS_CARDS_SPRITE`). Phoenix Arrow took five rounds;
the owner's reference was a stock firebird effect, so its take is a CC0 eagle screech over CC0 fire
(`assets/audio/freesound.py` round 32); the other thirteen are synthesised (`class_card_synth.py`).


From `docs/UPGRADES-BRAINSTORM.md` ("i like the phoenix arrow idea and rain of
arrows, i like the black hole idea, elemental orbs, and arcane turret. i like
the titans grip, counter strike"). The build-defining cards, drawn big:

| Card | Class | Rarity | What it does |
|---|---|---|---|
| Phoenix Arrow | Ranger | Mythic | Every 8th volley a phoenix flies through every enemy to the wall (1.8x), the ground burning behind it for 2.5 s. |
| Rain of Arrows | Ranger | Legendary | Every 6th volley an arrow goes up; 0.6 s later 12 fall within 4.5 studs of the target (0.3x each). |
| Black Hole | Arcanist | Mythic | Every 7th cast a black orb opens a hole at the target that drags enemies in for 2 s (bosses stand), then implodes (2.4x). |
| Elemental Orbs | Arcanist | Epic | Casts cycle fire (burn), ice (slow to 50% for 2 s), lightning (+2 arcs, drawn as Chain Lightning's bolt since 2026-11-12). |
| Arcane Turret | Arcanist | Legendary | Every 10 s of fighting a crystal hovers beside the Arcanist for 6 s, casting an orb every 0.5 s (0.35x). |
| Titan's Grip | Warden | Mythic | The swing's reach, depth and slam all 2x (`MeleeStats.reachScale`, `SwingBox.shape`); the sword drawn 2x; every slam shakes the room. |
| Counter Strike | Warden | Epic | A hit taken (not dodged or guarded) makes the next blow 3x. The Warden is untouchable mid-swing, so it charges when he is hit between swings. |

Server: `Combat/ClassUpgrades` (counters per session, the hole's pull through
`EnemyManager.pull`, the turret, the phoenix's fire as `AreaStrikes` zones);
numbers in `Balance.Player`. Client: `Fx/Upgrades/RangerBuildFx`,
`ArcanistBuildFx`, `WardenBuildFx`, built from voxel cubes (`Fx/Upgrades/Voxel`)
in place of Claude Design FX models; `Remotes.UpgradeFx` and the player's
attributes (`OrbElement`, `TurretUntil`, `CounterReady`, `CounterAt`) drive
them. Icons: Codex, `assets/concepts/blocky/ui/cards/<icon>_raw.png`, composed
with a gold (Legendary) or rainbow (Mythic) halo by `compose_icon.py`. Sounds:
seven silent hooks in `Config/Sounds` (`fx_phoenix` ... `fx_counter_strike`).

## Who gets what

- **Every class (12):** Strength, Precision, Deadly Strike, Blaze, Momentum,
  Agility, Lightfoot, Vitality, Mending, Bloodthirst, Second Wind, and the
  Heal filler. These already work for any attack.
- **Ranger only (16):** the arrow cards: Multishot, Front Arrow, Double
  Shot, Rear Arrow, Side Arrow, Diagonal Arrows, Piercing Shot, Swift Arrows,
  Long Shot, Bouncy Wall, Ricochet, Blast Arrows, Soul Chain, Overdraw,
  Tracking Eye, Dual Bows (its Mythic).
- **Warden only (13)** and **Arcanist only (12):** below.

**Built so far (wave 1):** the rows not marked *wave 2*. Wave 2 is designed
and has its icons uploaded, but no code yet.

So each class drafts from its own set plus the shared twelve: the Ranger 28
cards, the Warden 25, the Arcanist 24.

## The Warden (ruby greatsword, melee)

| Card | Rarity | Levels | What it does |
|---|---|---|---|
| Quick Hands | Common | 3 | Swing faster: +10% / +20% / +30% attack speed. |
| Iron Skin | Common | 3 | Take 8% / 16% / 24% less damage. |
| Cleave | Uncommon | 3 | The swing is 15% / 30% / 45% wider. |
| Long Reach | Uncommon | 3 | Reach and swing depth +1.5 / +3 / +4.5 studs. |
| Steadfast | Uncommon | 2 | The swing's guard lingers 0.3 / 0.6 s after the swing ends. |
| Heavy Blade | Rare | 3 | The slam, the third blow, deals +40% / +80% / +120%. |
| Bloodletting | Rare | 3 | Each blow heals 3% / 6% / 9% of the damage it deals. |
| Sunder | Rare | 2 | Struck enemies take +10% / +20% damage from everything for 3 s. *Wave 2.* |
| Shockwave | Epic | 2 | The slam sends a ground wave 10 studs forward, at 60% / 90% damage. *Wave 2.* |
| Echo Slash | Epic | 2 | Every blow strikes again 0.15 s later, at 40% / 60% damage. *Wave 2.* |
| Whirlwind | Legendary | 1 | The slam spins: it strikes all around the Warden, not just in front. *Wave 2.* |
| Execute | Legendary | 2 | Blows deal +50% / +100% to enemies under 30% health. |
| Riposte | Legendary | 1 | Enemy shots that hit the Warden mid-swing are thrown back at their shooter, at full damage. *Wave 2.* |
| **Earthbreaker** | **Mythic** | 1 | His dash ends in a leaping slam (2.5× damage); the cracked ground erupts every 0.5 s for 3 s (0.5×). Built. |

## The Arcanist (arcane staff, slow heavy orbs)

| Card | Rarity | Levels | What it does |
|---|---|---|---|
| Bigger Orbs | Common | 3 | The orbs' blast is 15% / 30% / 45% larger. |
| Mana Flow | Common | 3 | Cast faster: +10% / +20% / +30% attack speed. |
| Frost Orb | Uncommon | 2 | A hit slows the enemy by 25% / 40% for 2 s. *Wave 2.* |
| Arcane Shield | Uncommon | 3 | A shield blocks one hit, and comes back every 10 / 8 / 6 s. *Wave 2.* |
| Twin Cast | Rare | 2 | An extra orb beside each cast (one, then two). |
| Arcane Echo | Rare | 2 | Each cast repeats once / twice, 0.2 s apart (Double Shot's stage). |
| Spell Pierce | Rare | 2 | Orbs pass through 1 / 2 enemies. |
| Chain Lightning | Epic | 2 | A hit arcs on to the next enemy, 2 / 3 times (Ricochet's stage). |
| Split Orb | Epic | 2 | An orb bursts into 3 / 5 shards on hit, 30% each. *Wave 2.* |
| Gravity Well | Legendary | 1 | Each blast pulls nearby enemies in toward its centre. *Wave 2.* |
| Orbiting Orb | Legendary | 2 | An orb circles the Arcanist, striking enemies it touches (one, then two). *Wave 2.* |
| Homing Orbs | Legendary | 1 | Orbs seek the nearest enemy (the Arcanist's Tracking Eye). |
| **Meteor** | **Mythic** | 1 | Every 5th cast calls a meteor down on the target: a warning circle, then a 4× blast in 6 studs. Built. |

## How they are built

Each card is a row in `Config/Abilities` (`classes = { "Warden" }` or
`{ "Arcanist" }`) and one entry in `Combat/AbilityEffects`, as the Ranger's
are: no `if` on a card's name anywhere in the combat code.

- Several Arcanist cards reuse a mechanic that already exists under a spell's
  name: Twin Cast is Front Arrow's stage, Arcane Echo is Double Shot's, Spell
  Pierce is Piercing Shot's, Homing Orbs is Tracking Eye's, Chain Lightning is
  Ricochet's.
- New mechanics, built once as stages and then shared: slow, damage-taken
  multiplier (Sunder), lifesteal, a projectile from a melee blow (Shockwave),
  a delayed repeat of a blow (Echo Slash), a 360° swing (Whirlwind), a
  shield, reflecting shots (Riposte), an orbiting hitter (Orbiting Orb), a
  pull (Gravity Well), shards on hit (Split Orb).
- Numbers are a first pass, to tune at playtest.

Icons: one per card (all 25, waves 1 and 2), made with Codex in the style of the Ranger's (a bold
flat glyph with a thick dark outline on a white disc), in
`assets/concepts/icons/`.

Wave 1's icons are uploaded and their ids are in `Config/CardAssets`.
**Wave 2's are not** (checked 2026-11-03): `Config/CardAssets` holds no key
for Sunder, Echo Slash, Riposte, Frost Orb, Arcane Shield, Split Orb,
Gravity Well or Orbiting Orb, and `assets/ui/glow_toy_cards/icons/` has no
art for them either, so all eight are blocked on Codex as well as on code.
Forty further ideas, and which of wave 2 is now cheap, are in
[CARD-IDEAS.md](CARD-IDEAS.md). Cleave's and
Echo Slash's carry a faint grey smudge at the disc's left edge; regenerate
those two if it shows on a card.
