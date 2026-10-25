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
- The Warden lost Iron Skin, Steadfast and Bloodletting; new Warden cards are
  the owner's pick from the ideas in the chat of 2026-10-25.

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

The icons are uploaded and their ids are in `Config/CardAssets`. Cleave's and
Echo Slash's carry a faint grey smudge at the disc's left edge; regenerate
those two if it shows on a card.
