# Forty new upgrade cards — ten for each class

Owner, 2026-11-03: *"we need to make cooler upgrades so players stay more
engaged ... i also want 10 new upgrade ideas for each class."*

**Nothing here is built.** This is a menu: say which ones you want and they get
written. The follow-up to `docs/BALANCE-REPORT.md`, which ranked all 42 live
cards and found the card pool the least interesting part of a run — nineteen of
the 42 are a flat percentage on a stat.

## The rules these were written to

- **No card is a flat +N% on its own.** Every one changes how a run plays: a
  new shape to the volley, a new thing the room does, a reason to stand still
  or to keep moving. Twelve of the forty do no direct damage at all.
- **Power stays modest** (PR #342, cut ~20%): pets and weapons carry a
  player's power. The numbers below are first passes aimed at the same bands
  the live cards sit in, not above them.
- **A card is data, never an `if`** (CLAUDE.md non-negotiable 1): a row in
  `Config/Abilities` plus one entry in `Combat/AbilityEffects`, or a stage in
  `Combat/ClassUpgrades` for the ones that run on a timer. Each card below
  says which machinery it reuses, so "what is genuinely new work" is the only
  column that costs anything.
- **The genre's lesson** (`docs/RESEARCH-archero.md`): Archero ships about 25
  abilities where every one is a real choice, and its own dead weight (Smart,
  Death Nova, Holy Touch) is the part not to copy. Nine of the forty are
  deliberately build-defining Legendaries and Mythics, because those are what
  a player remembers.

## What you must know before picking

- **Every card needs one icon, made with Codex** (CLAUDE.md rule 9). Codex was
  out of usage when this was written, so no art exists for any of the forty.
  Budget one Codex image per card you pick, in the style of the live set (a
  bold flat glyph, thick dark outline, white disc), composed onto its rarity
  tile by `assets/ui/glow_toy_cards/compose_icon.py` — gold halo for a
  Legendary, rainbow for a Mythic.
- **No new card needs a model or a sound.** The effects can all be drawn from
  voxel cubes with `Fx/Upgrades/Voxel`, as Phoenix Arrow and Black Hole are.
  Sounds are optional and would be one audio upload for the lot.
- **The Assassin has no combat system yet.** It is the locked fourth plate on
  the class select (`Config/ClassSelectAssets`) and has no `Config/Classes`
  entry, no weapon and no attack. Its ten cards below are a design for when
  the class is built; they assume fast dagger strikes off a variant of
  `Combat/MeleeSystem`. Picking any of them means building the class first.
- **Eight already-designed cards are still unbuilt** and are *not* re-proposed
  here: Sunder, Echo Slash and Riposte (Warden) and Frost Orb, Arcane Shield,
  Split Orb, Gravity Well and Orbiting Orb (Arcanist), all from
  `docs/CLASS-CARDS.md`'s wave 2. They are blocked on the same thing — no
  icons — and three of them are now nearly free, because the machinery they
  wanted has since been built for something else (`EnemyManager.mark` for
  Sunder, `.slow` for Frost Orb, `.pull` for Gravity Well). Pick those first
  if you want cards cheaply.

---

## The Ranger — bow, a volley pipeline

| Card | Rarity | What it does | Levels | Reuses | Genuinely new |
|---|---|---|---|---|---|
| **Hunter's Mark** | Uncommon | The enemy you are aiming at takes more damage from everything. | +12% / +20% / +28% | `EnemyManager.mark`, `Combat/Aim`'s current target | A mark that follows the aim each frame, cleared when it moves off |
| **Windrunner** | Rare | Every volley fired makes you faster for 2 s, stacking three deep. | +4% / +7% / +10% a stack | Battle Cry's stack-with-lapse, `AbilityEffects.clientStats` move speed | Nothing — Battle Cry's shape with a different stat |
| **Pin Down** | Rare | Arrows root the first enemy they hit; once every 3 s per enemy. | 0.5 s / 0.8 s | `EnemyManager.root` | A per-enemy cooldown table so a volley cannot chain-root |
| **Serpent Arrow** | Rare | Arrows weave side to side as they fly, sweeping a lane instead of a line. | 1.5 / 2.5 studs of weave | `ProjectileSystem`'s steering (`homing` is the same hook) | A sine offset on a shot's path, and the client renderer following it |
| **Trick Shot** | Epic | An arrow that has bounced off a wall hits *harder*, not weaker. | +60% / +120% / +180% | Bouncy Wall's bounce flag | A post-bounce damage multiplier (today a bounce only loses damage) |
| **Barrage** | Epic | Stand still for 1.2 s and the next volley is a fan, at no damage penalty. | 3 / 5 arrows | Overdraw's stillness timer, `Stages.spread` | A "charged volley" slot the stage pipeline can swap in |
| **Thornfall** | Epic | An enemy killed by an arrow drops arrows into the ground that fire outward. | 3 / 5 arrows at 0.3x | `ClassUpgrades.invent`, the `OnKill` category (no live card uses it) | An on-kill hook that invents shots from the kill point |
| **Headhunter** | Legendary | Every so often an arrow is a guaranteed crit at triple crit damage. | every 10th / 7th | `ClassUpgrades.afterVolley`'s counter, the crit roll | A forced-crit flag on one shot of a volley |
| **Ghost Quiver** | Legendary | A spectral archer trails behind you and copies every volley. | 1 archer at 40% | Arcane Turret's whole shape (`ClassUpgrades.turret`), `invent` | A follower that mirrors the player's own volley rather than casting its own |
| **Skyfall** | Mythic | Every 12th volley you leap, untouchable, and land firing a ring of arrows. | 16 arrows at 0.6x, 1 s airborne | Rain of Arrows' delayed strike, `Stages.mirror` for the ring, Agility's dodge | A player hop and an untargetable window |

## The Arcanist — staff, slow heavy orbs

| Card | Rarity | What it does | Levels | Reuses | Genuinely new |
|---|---|---|---|---|---|
| **Siphon** | Rare | Every third orb that lands heals you. | 3 / 5 / 7 HP | Bloodletting's lifesteal, `afterVolley` | Nothing |
| **Overcharge** | Rare | Every fourth cast costs you health and lands for double. | 5 HP for 2x | `afterVolley`, `RunSession.applyDamage` | Self-damage from your own cast, and keeping it off a kill |
| **Mana Burn** | Rare | An orb's blast also takes a share of what the enemy has left. | 10% / 18% of current HP | `EnemyManager.damage`, `.healthFraction` | Damage as a fraction of current health (nothing does this yet; cap it on bosses) |
| **Rune Circle** | Epic | Where an orb bursts, a rune stays and burns what stands in it. | 3 s at 0.25x/s, 2 / 3 runes | `Combat/AreaStrikes` zones — the phoenix's fire, already general | Nothing |
| **Arcane Tether** | Epic | The two nearest enemies you strike are tethered: hurt one, hurt the other. | 40% / 60% shared | `Combat/SoulLink`, `Util/DeepAccord` | The pairing rule, and drawing the tether |
| **Twin Elements** | Epic | Every cast is two orbs at once, one fire and one ice. | 1 pair, 70% each | Twin Cast's parallel stage, `ClassUpgrades.dress` | Per-projectile elements inside one volley (`dress` handles one orb today) |
| **Time Dilation** | Legendary | A kill leaves a field where enemies *and their shots* crawl. | 50% speed for 2 s / 3 s, 6 studs | `EnemyManager.slow`, an `AreaStrikes` zone | Slowing enemy projectiles — `ProjectileSystem` has no speed scale on a live shot |
| **Starfall** | Legendary | Meteors fall on the enemies nearest you, on their own. | 3 meteors at 1.2x, every 9 s / 7 s | Meteor whole (warning circle, strike), `EnemyManager.triangle` | Nothing |
| **Prismatic Burst** | Legendary | An orb that kills bursts into small orbs that seek new targets. | 6 shards at 0.3x | `invent`, `homing`, the `OnKill` hook Thornfall needs | Shared with Thornfall — build the hook once |
| **Singularity** | Mythic | Stand still and an orb grows in front of you, then rolls through everything, dragging enemies with it. | up to 2 s charge, 3x, pierces all | Overdraw's stillness, Spell Pierce, `EnemyManager.pull` | A held projectile that grows before it is fired |

## The Warden — ruby greatsword, melee

| Card | Rarity | What it does | Levels | Reuses | Genuinely new |
|---|---|---|---|---|---|
| **Guard Break** | Uncommon | The slam flings enemies back and leaves them staggered. | 6 / 9 / 12 studs, 0.4 s | The knockback every non-boss enemy already takes, `EnemyManager.root` | Nothing |
| **Bull Rush** | Rare | Your dash becomes a charge: it hurts and scatters what it runs through. | 1.0x / 1.5x | Earthbreaker's dash hook, knockback | A sweep along the dash path |
| **Bellow** | Rare | Every fifth swing is a shout that pushes the room away from you. | 0.6x / 0.9x in 10 studs | Shockwave's wave, `afterVolley`'s counter | Nothing |
| **Stone Skin** | Rare | Stand still a moment and a stone guard takes the sting out of the next hit. | -30% / -45% / -60% | `Util/Shelter`, Overdraw's stillness | Nothing |
| **Blood Pact** | Epic | Badly hurt, you hit much harder. | +40% / +70% under half HP | Execute's threshold arithmetic, inverted | A swing reading the player's own live health (stats are computed per volley today) |
| **Grave Chains** | Epic | The slam chains everything it hits to the ground. | 1 s / 1.5 s | `EnemyManager.root` | Nothing |
| **Blade Cyclone** | Epic | Stand still and you spin without stopping, hitting everything around you. | 0.5x every 0.3 s | Whirlwind's ring and its cube drawing, Overdraw's stillness | A held channel state that suspends the normal swing loop |
| **Reaper's Harvest** | Legendary | A kill gives you most of your swing back, and a little health. | 40% / 60% of the cooldown, 4 HP | Bloodthirst, `AbilityEffects.cooldownAt` | A cooldown refund mid-swing-cycle |
| **Vengeful Spirit** | Legendary | An enemy you kill rises as a sword that fights for you. | 1 spirit, 6 s, 0.4x | The turret's shape, `invent`, the `OnKill` hook | A friendly melee minion — shared with Ghost Quiver and Phantom Blades |
| **Colossus** | Mythic | You grow: bigger, tougher, unmovable, and every third slam quakes the room. | +40% size, +60% max HP, 1.5x in 14 studs | Titan's Grip's scaling, `ClassUpgrades.slammed`, the room shake | Scaling the player's own body, and knockback immunity |

## The Assassin — twin daggers, fast and fragile

**The class does not exist yet.** These assume a `Config/Classes.Assassin`
with a fast, short, two-hit strike off a variant of `Combat/MeleeSystem`, and
the dagger models from `phase-3/splinter-daggers-redo`. Picking any of these
means building the class first — that is its own piece of work, bigger than
all ten cards together.

| Card | Rarity | What it does | Levels | Reuses | Genuinely new |
|---|---|---|---|---|---|
| **Twin Fangs** | Common | Each strike lands twice. | 55% / 60% / 65% each | Echo Slash's delayed repeat (itself still unbuilt) | The repeat stage, shared with Echo Slash |
| **Backstab** | Uncommon | You hit much harder from behind. | +30% / +55% / +80% | `Combat/SwingBox`'s facing maths | A facing test between attacker and target |
| **Serrated Edge** | Rare | A crit leaves the enemy open to everything for a moment. | +15% / +25% for 3 s | `EnemyManager.mark`, the crit roll | Nothing |
| **Bleed** | Rare | Strikes stack a bleed that keeps going. | 3 / 5 / 7 a second, 4 s, 5 stacks | Blaze's burn | Stacking a burn (Blaze refreshes rather than stacks) |
| **Shadowstep** | Rare | Your dash passes through enemies and leaves poison behind you. | 1.5 s / 2.5 s cloud at 0.3x/s | `AreaStrikes` zones, the dash | Passing through an enemy body |
| **Fan of Knives** | Epic | Every fourth strike throws a fan of knives. | 5 / 7 knives at 0.35x | `invent`, `Stages.spread` | Nothing |
| **Vanish** | Epic | Stand still and you disappear; the strike that breaks it is devastating. | 2.5x / 3.5x | Overdraw's stillness, `EnemyManager.blind` | An untargetable window — shared with Skyfall |
| **Death Mark** | Legendary | One enemy is marked and takes more; kill it and the mark jumps. | +35% | `EnemyManager.mark`, `Combat/Targeting` | The mark jumping on a kill |
| **Phantom Blades** | Legendary | Spectral daggers orbit you and cut what they touch. | 2 / 3 blades at 0.3x | — | An orbiting hitter — exactly what wave 2's Orbiting Orb wants, so build it once for both |
| **Thousand Cuts** | Mythic | Every so often you blink to every enemy in the room in turn, striking each. | 8 enemies at 1.2x, every 10 s | `EnemyManager.positions`, `invent`, Skyfall's untargetable window | The blink chain itself |

---

## Build these once and several cards fall out

Seven pieces of machinery are wanted by more than one card. If you pick across
classes, pick cards that share a piece and the second one is nearly free.

| Piece | Cards that want it |
|---|---|
| An `OnKill` hook that invents shots from the kill point | Thornfall, Prismatic Burst, Vengeful Spirit |
| A friendly minion on the turret's pattern | Ghost Quiver, Vengeful Spirit, Phantom Blades |
| An orbiting hitter | Phantom Blades, **Orbiting Orb** (wave 2) |
| A stillness channel (Overdraw already holds the timer) | Barrage, Blade Cyclone, Singularity, Stone Skin, Vanish |
| An untargetable window | Skyfall, Vanish, Thousand Cuts |
| A delayed repeat of a blow | Twin Fangs, **Echo Slash** (wave 2) |
| `EnemyManager.mark` (already built, used by nothing) | Hunter's Mark, Serrated Edge, Death Mark, **Sunder** (wave 2) |

## The cheapest ten, if you want cards soon

In order, counting only work and not how good the card is. All ten reuse
machinery that exists and runs today, and each still needs its one Codex icon.

1. **Starfall** (Arcanist) — Meteor, pointed at three enemies on a timer.
2. **Rune Circle** (Arcanist) — an `AreaStrikes` zone, which is already general.
3. **Guard Break** (Warden) — knockback and a root, both built.
4. **Grave Chains** (Warden) — `EnemyManager.root`.
5. **Bellow** (Warden) — Shockwave on a swing counter.
6. **Stone Skin** (Warden) — `Util/Shelter` behind Overdraw's timer.
7. **Hunter's Mark** (Ranger) — `EnemyManager.mark` on the aim target.
8. **Windrunner** (Ranger) — Battle Cry's stacking, on move speed.
9. **Siphon** (Arcanist) — lifesteal on a counter.
10. **Serrated Edge** — but the Assassin does not exist, so **Sunder** (wave 2)
    instead: the same `mark`, on a class that can be played today.

## Picked, 2026-11-03

The owner: *"i like thornfall, headhunter, ghost quiver, windrunner, twin
elements, time dilation, prismatic burst, guard break, bull rush, blood pact,
vengeful spirit. hold off on the assassin class for now."*

Eleven of the forty, and **the Assassin's ten are on hold** — the class still
has no combat system, which is what that would have needed first.

| Card | Class | Where its rule lives |
|---|---|---|
| Windrunner | Ranger | `ClassUpgrades.afterVolley` banks the stacks; `AbilityEffects.moveSpeedAt` spends them, on both sides |
| Thornfall | Ranger | `ClassUpgrades.onKillAt` -> `thornfall` |
| Headhunter | Ranger | `ClassUpgrades.dress` (the per-projectile hook) |
| Ghost Quiver | Ranger | `ClassUpgrades.afterVolley`, handed the volley's own specs |
| Twin Elements | Arcanist | a lane in `AbilityEffects.stages`; its elements in `dress` |
| Time Dilation | Arcanist | `ClassUpgrades.onKillAt` (on a hit until the owner's playtest, 2026-11-04) |
| Prismatic Burst | Arcanist | `ClassUpgrades.onKillAt` -> `prismatic` |
| Guard Break | Warden | `MeleeSystem.land`, through `EnemyManager.shove` |
| Bull Rush | Warden | `Remotes.DashStarted` -> `ClassUpgrades.beginRush`, swept in `step`; immune for `Balance.Player.bullRush.immune` |
| Blood Pact | Warden | `MeleeSystem.land`, against the player's live health |
| Vengeful Spirit | Warden | `ClassUpgrades.onKillAt` -> `raiseSpirit`, struck in `step` |

The three shared pieces the table above promised were built once and are now
general: **`RunSession.onKillAt`** (where an enemy fell — Thornfall, Prismatic
Burst and Vengeful Spirit all hang off it), **`ProjectileSystem.onPlayerHit`**
(where a player's shot landed) and **`EnemyManager.shove`** (an extra push with
its own stagger, on the knockback a blow already uses). The remaining four
shared pieces — an orbiting hitter, a stillness channel, an untargetable window
and a delayed repeat — are still unbuilt, and still make their cards cheap.

**Twenty-nine ideas are still on the table**, the Assassin's ten among them.

## What to say back

1. **Which of the forty** do you want built? Ticking a whole class is fine.
2. **Any of wave 2's eight** at the same time? Sunder, Frost Orb and Gravity
   Well are the cheap three now.
3. **The Assassin** — is it on the table at all this phase? If not, its ten
   stay on file and the other thirty are the menu.
4. Icons: one Codex image a card. Say go and they are made in the live set's
   style when usage allows.
