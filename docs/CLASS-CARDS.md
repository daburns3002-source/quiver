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

## The nineteen (2026-11-27)

The owner, shown the nineteen ideas left in [CARD-IDEAS.md](CARD-IDEAS.md): **"Build all nineteen"**.
Numbers in `Balance.Player` (each card's level is its own), rules in `tests/NineteenCards.spec`. Every
number sits at or under the live card beside it (PR #342: power is the pets' and the weapons'), and
the spec holds each to that peer.

**Pools, within three as the owner's rule wants:** Arcanist 39, Warden 38, Ranger 37, Assassin 36. Five
of the Warden's six are both melee classes' (as Guard Break, Blood Pact and Vengeful Spirit are), and
Hunter's Mark and Starfall are the Assassin's too. Colossus is the Warden's alone: a class Mythic is
one class's.

| Card | Class | Rarity | What it does | How |
|---|---|---|---|---|
| **Hunter's Mark** | Ranger, Assassin | Uncommon | The nearest enemy in reach takes +10 / 15 / 20% from everything | Sunder's mark, refreshed every 0.2 s (`ClassUpgrades.step`) |
| **Pin Down** | Ranger | Rare | Arrows root what they hit for 0.5 / 0.8 s, each enemy once every 3 s; a boss is slowed | `EnemyManager.root`, from the landing hook |
| **Serpent Arrow** | Ranger | Rare | Arrows weave 1 stud either side of their line and poison what they bite, 15 / 25% of the hit | a `Weave` stage in the shared flight; Burr Blight's stack |
| **Trick Shot** | Ranger | Epic | Arrows bounce off a wall once more, and hit +50 / 80% harder after it | a bounce from the stages; `onWall` on the server |
| **Barrage** | Ranger | Epic | 2 s still (and 2 s since the last) and the next volley also fires a fan of 3 / 5 arrows, 50 degrees, 0.4x each | the stillness channel |
| **Skyfall** | Ranger | Mythic | Every 12th volley the archer leaps for 0.8 s, untargetable, and lands in a ring of 16 arrows, 0.5x each | the untargetable window |
| **Siphon** | Arcanist | Rare | Every third cast that hits heals 1 / 1.5 / 2% of max health | the landing hook, a cast counted once |
| **Overcharge** | Arcanist | Rare | Every fourth cast costs 3% of max health (never the last point) and hits x1.6 / x2 | `castScale`, `RunSession.spendHealth` |
| **Mana Burn** | Arcanist | Rare | Orbs hit up to +25 / 40% harder, the more health the enemy has left | `ProjectileSystem.applyHit`, as Long Shot's range |
| **Rune Circle** | Arcanist | Epic | Where an orb bursts a rune burns 3 s, 2.5 studs wide, 0.12x every 0.5 s; 2 / 3 burn at once | an `AreaStrikes` zone |
| **Arcane Tether** | Arcanist | Epic | An orb ties its enemy to the nearest other within 12 studs for 4 s: a blow on either lands 30 / 45% on the other; two ties at a time | `EnemyManager.tether` |
| **Starfall** | Arcanist, Assassin | Legendary | Every 9 / 7 s of fighting, meteors on the 3 nearest enemies within 30 studs, 1.1x in 4 studs | Meteor's warning and strike |
| **Singularity** | Arcanist | Mythic | 4.5 s still grows an orb at the staff; the next cast rolls it through everything at 0.55x an orb's speed for 2x, dragging what is within 3.5 studs in to its line | the stillness channel; `EnemyManager.pull` |
| **Bellow** | Warden, Assassin | Rare | Every fifth blow is a shout 8 studs round him, 40 / 60% of a blow, shoving 5 studs | `afterBlow`, `EnemyManager.shove` |
| **Stone Skin** | Warden, Assassin | Rare | 1.2 s still raises a stone guard that takes 25 / 40 / 55% off the next hit | `RunSession.applyDamage`, `Util/Shelter` |
| **Grave Chains** | Warden, Assassin | Epic | The combo's last blow holds what it hits 1 / 1.5 s; a boss is slowed | `EnemyManager.root` |
| **Blade Cyclone** | Warden, Assassin | Epic | 1 s still and 2 / 3 ruby blades whirl 3.6 studs out, 0.2x a cut, the same enemy every 0.6 s | `orbitCuts` on the stillness channel |
| **Reaper's Harvest** | Warden, Assassin | Legendary | A kill brings the next swing 35 / 55% sooner and heals 1.5% of max health | `Session.nextAttackHaste` (it reaches the client as `AttackHaste`) |
| **Colossus** | Warden | Mythic | He grows 1.35x, takes +40% max health, nothing can push him, and every third slam quakes 12 studs round him for 1.2x | `RunSession.scaleBody` (`Model:ScaleTo`); `ClassUpgrades.slammed` |

- **Changed from the doc's words**, to fit how the game plays: Serpent Arrow poisons as well (a weave
  alone pays nothing without pierce, and pierce is Piercing Shot's, an Epic); Trick Shot brings its own
  bounce (alone it needed Bouncy Wall); Mana Burn is a share of the hit scaled by the health left, so
  it needs no cap on bosses; Siphon counts casts, not orbs, and heals a share of max health; Blade
  Cyclone whirls blades round him while he stands still rather than stopping his swing (the client
  predicts every swing); Reaper's Harvest is a haste on the next swing, which the client already
  follows, rather than a cooldown refund it could not; Hunter's Mark marks the nearest enemy, Sunder's
  way, so it never clears Death Mark's.
- **Shared pieces:** the stillness channel (`Shared/Combat/Stillness`) and the untargetable window
  (`RunSession.untargetable`), both from CARD-IDEAS.md's list; the landing hook
  (`ProjectileSystem.onPlayerHit`) and the tether (`EnemyManager.tether`).
- **Looks** (`Fx/Upgrades/CardIdeasFx`), voxel cubes: a red diamond over the marked enemy, earth and
  green puffs at a pin and a bite, an orange flash off a wall, gold sparks over a ready Barrage, the
  archer lifted off the ground with a shadow and a rainbow ring as they land, red cubes flying home
  for Siphon, a crackle for Overcharge, blue flame off a healthy enemy, a violet rune with flames, a
  violet chain between tethered enemies, the singularity growing at the staff and rolling huge, white
  rings for Bellow, stone plates round a guarded player, iron links round a chained enemy, ruby
  blades whirling, green wisps for a harvest, and rocks and a shake for the quake.
- **Icons**: Codex in the set's style (`assets/concepts/blocky/ui/cards/<icon>.prompt.txt`, drawn by
  `tools/card_icons.sh`), composed by `compose_icon.py` (gold halo on the Legendaries, rainbow on
  the Mythics) and uploaded (`Config/CardAssets`).
- **Sounds**: each an existing card's clip, no upload (`Config/Sounds`, `fx_hunters_mark` ...
  `fx_colossus`; each entry says whose).

## Wave 2's last five (2026-11-26)

Wave 2 had ten cards; five were already built under other sessions (Sunder, Shockwave, Whirlwind,
Frost Orb, Arcane Shield). The last five are built now. Asked whether to keep the pools within a card of
each other, the owner said **"As written (B)"**: all five as the tables below give them, and the rule
loosened to within three (`tests/ClassCards.spec`). Pools now: Arcanist 29, Warden 28, Ranger 27,
Assassin 26. The doc's numbers are at the 2026-10-25 cut (x0.8); the rest are in
`Balance.Player.waveTwo`.

| Card | Class | Rarity | What it does | How |
|---|---|---|---|---|
| **Echo Slash** | Warden | Epic | Every blow strikes what it struck again 0.15 s later, at 32% / 48% | `MeleeSystem.land`, a plain hit as Shockwave's wave |
| **Riposte** | Warden | Legendary | A shot the swing's guard catches flies back at the enemy nearest where it was fired (straight back when none is), turning after it, at 80% of the Warden's damage | `ProjectileSystem` (`throwBack`), `RunSession.guarding` |
| **Split Orb** | Arcanist | Epic | An orb's first hit bursts it into 3 / 5 shards fanned 30 degrees apart, 24% each, 12 studs; shards never split | Split Shot's fan (`fireFan`), dressed on the orb |
| **Gravity Well** | Arcanist | Legendary | Each blast pulls every enemy within 9 studs 3.5 studs in over 0.35 s, harder near the middle; bosses stand | `EnemyManager.pull`, as Black Hole; ticked in `ProjectileSystem.step` |
| **Orbiting Orb** | Arcanist | Legendary | 1 / 2 orbs circle 5 studs out and strike what they touch for 30%, the same enemy no sooner than every 0.7 s | `ClassUpgrades.orbitCuts`, which the Assassin's Phantom Blades now share |

- **Looks** (`Fx/Upgrades/WaveTwoFx`), voxel cubes: a pale cyan ghost of the blow sweeping through its
  own shape (a ring for the slam); the thrown-back shot gold with a gold flash; violet shards with a
  puff of crystal; violet cubes spiralling into a dark core; tumbling violet orbs circling the
  Arcanist (`OrbitingOrbs` on the player, on the shared clock).
- **Icons**: Codex in the set's style, the October icons as the idea
  (`assets/concepts/blocky/ui/cards/wave2_cards_2026_11_26.sh`), composed by `compose_icon.py` and
  uploaded (`Config/CardAssets`).
- **Sounds**: this doc gives them none, so four silent hooks wait in `Config/Sounds`
  (`fx_echo_slash`, `fx_riposte`, `fx_split_orb`, `fx_gravity_well`) for an audition round. Orbiting
  Orb has no sound of its own.
- **Seen** (2026-11-26, Studio Play, by probe): each echo lands 0.15 s after its blow at exactly 48%;
  both shots the guard caught from Spitters came back and struck one for 80%; five shards a hit at
  24%; the orbs struck for 30%; and the well pulled dummies inside it 2-3 studs in (it pulled nothing
  until the well was ticked ahead of the step's early return when nothing is flying). **Not seen:** the
  looks by eye, a phone, co-op.

## Thornwood's six cards (2026-11-18)

The owner, asked whether Thornwood's three Legendaries and three Mythics should carry existing cards
or the six effects Codex wrote for them in October (`docs/WEAPONS-THORNWOOD.md`): **"Build the six
new"**. They are cards like any other, drafted by their class and carried by a Thornwood weapon as its
`innate`. Each rides machinery that was already there; numbers in `Balance.Player.thornwood`, rules in
`tests/ThornwoodCards.spec`.

| Card | Class | Rarity | What it does | How |
|---|---|---|---|---|
| **Web Snare** | Ranger | Uncommon | Arrows slow what they hit by 30 / 40% for 2 s | a shot's `slow`, flagged `web` so it is silk and not a chill (`ClassUpgrades.dress`) |
| **Thorn Burst** | Ranger | Epic | Every 3rd volley's arrows burst 6 studs round what they hit, for 60 / 80% | the shot's own splash, as Blast Arrows', the bigger of the two winning |
| **Root Hold** | Arcanist | Rare | Every 4th cast's orbs hold what they hit for 1 / 1.5 s; a boss is slowed to 60% instead | `EnemyManager.root`, as a pet's root holds |
| **Burr Blight** | Arcanist | Epic | Orbs poison what they hit: a stack is 30 / 40% of the hit over 3 s, up to 5 deep | `Burning.bleed`, as the Assassin's Bleed |
| **Boar Rush** | Warden, Assassin | Uncommon | The combo's last blow shoves what it hits 150 / 250% further | `EnemyManager.knock`, as Wind Arrows' gust |
| **Ruin Cracks** | Warden, Assassin | Epic | The combo's last blow makes what it hits take 30 / 40% more for 4 s | `EnemyManager.sunder`, as Sunder's mark, the stronger holding |

- **Changed from the October words**, to fit how the game counts: Thorn Burst is every 3rd *volley*
  (as Rain of Arrows and Phoenix Arrow count), not every 3rd hit, and Root Hold every 4th *cast*.
  Web Snare slows a boss as it slows anything (Frost Orb does the same).
- **Boar Rush and Ruin Cracks are both melee classes'**: the Warden's slam and the Assassin's double
  stab. That keeps the four classes' pools within a card of each other (27, 26, 26, 26;
  `tests/ClassCards.spec`); as the Warden's alone the Assassin would have been three behind.
- **Looks** (`Fx/Upgrades/ThornwoodFx`): thorns thrown out in a ring, a ring of dust under the slam,
  strands of silk across a webbed enemy, burrs of poison bobbing over a blighted one. Root Hold wears
  Stumpy's roots (`Fx/RootHoldFx`) and Ruin Cracks Sunder's cracks, being the same states.
- **Icons**: Codex, in the set's style (`assets/concepts/blocky/ui/cards/thornwood_cards_prompts.py`),
  composed by `compose_icon.py` and uploaded. **Sounds** (`fx_thorn_burst`, `fx_boar_rush`): the
  owner's picks of audition round 34, in the themed daggers' sprite (2026-11-19).
- **Which weapon carries which** (once the fifteen are imported): Silkweaver Bow Web Snare, Nightbarb
  Bow Thorn Burst, Silk Diadem Staff Root Hold, Blackspine Staff Burr Blight, Silkbound Blade Boar
  Rush, Briarbreaker Blade Ruin Cracks.

## The Assassin's cards (2026-11-15)

Owner, 2026-11-15: "we need to create the assassin class now", then yes to the design put to them
(option A, twin daggers up close, with these ten cards). They are the ten of
[CARD-IDEAS.md](CARD-IDEAS.md), with three changed in the building: Shadowstep became **Poison
Trail** (the dash already passes through enemies and cuts them: that is the class's own Shadow
Dash), Vanish became **Quickstep** (standing still is when this game attacks, so a card about
standing still to disappear fought the class), and Thousand Cuts sends shadows where the idea had
the Assassin blink (the camera never jumps on a phone).

| Card | Rarity | Levels | What it does |
|---|---|---|---|
| Twin Fangs | Common | 3 | The double stab, the combo's third blow, deals +30% / +60% / +90% (the Assassin's Heavy Blade). |
| Backstab | Uncommon | 3 | A strike from behind an enemy (within 75 degrees either side of straight behind, by the way the enemy faces) deals +30% / +55% / +80%. A Shadow Dash that ends past an enemy cuts it from behind. |
| Quickstep | Uncommon | 2 | A kill takes 0.5 s / 1 s off the dash's wait. |
| Serrated Edge | Rare | 2 | A crit makes the enemy take +15% / +25% from everything for 3 s (Sunder's cracks show it). |
| Bleed | Rare | 3 | Each strike adds a cut, up to 5; every cut deals 3% / 5% / 7% of that strike a second; the whole stack lapses 4 s after the last strike (`Shared/Combat/Bleed`, the Bramble Wilf's). |
| Poison Trail | Rare | 2 | A dash leaves a cloud 4.5 studs wide round its middle for 1.5 s / 2.5 s, 0.15x a strike every half second. |
| Fan of Knives | Epic | 2 | Every 4th strike that lands throws 5 / 7 knives in a 70 degree fan along it, 0.35x each, 18 studs. |
| Death Mark | Legendary | 1 | One enemy takes +35% from everything. When it falls the mark jumps to the enemy nearest where it fell. |
| Phantom Blades | Legendary | 2 | 2 / 3 ghost daggers circle 5.5 studs out; an enemy one touches takes 0.3x a strike, no sooner than every 0.7 s. |
| **Thousand Cuts** | **Mythic** | 1 | Every 10 s of fighting, shadows strike the 8 nearest enemies within 45 studs in turn, 1.2x each. |

**Shared with the Warden** (`classes = MELEE`): Quick Hands, Cleave, Long Reach, Execute and Sunder,
the blade cards that are true of any swing. `tests/ClassCards.spec` holds a shared blade card to
changing a number the Assassin's swing reads. With Strength and the eight cards every class draws,
the pool is 24 (Ranger 25, Arcanist 24, Warden 24).

Server: `Combat/MeleeSystem` (`strike`: Backstab, Serrated Edge, Bleed), `Combat/AssassinUpgrades`
(the cloud, the knives, the mark, the blades, the shadows), `Run/RunSession` (Quickstep). Client:
`Fx/Upgrades/AssassinFx`, voxel cubes like the rest. Icons: Codex
(`assets/concepts/blocky/ui/cards/assassin_cards_2026_11_15.sh`, the prompts written by
`assassin_cards_prompts.py`), composed by `compose_icon.py` and uploaded. Sounds: five in
`Config/Sounds` (`fx_backstab`, `fx_poison_trail`, `fx_fan_of_knives`, `fx_death_mark`,
`fx_thousand_cuts`), the owner's picks of audition round 33, in one sprite with the daggers' own
strikes and the Shadow Dash's cut (`assets/audio/final/assassin_sprite_r33.mp3`, 2026-11-17).

## The themed daggers' seven (2026-11-18)

The owner: "make unique effects for the daggers now", then yes to the seven put to them, and to
icons for them. The seven themed sets' daggers (`docs/WEAPONS-THEMED.md`) had carried stand-in
cards; each now carries an effect of its own. **Each is a card only its dagger carries**
(`weaponOnly = true` in `Config/Abilities`): no draft and no Angel deals it (`Run/Loadout`'s
`candidates`), and it is in no class's pool, so the four pools stay within a card of each other
(`tests/ClassCards.spec`). A weapon-only card is carried by exactly one weapon
(`tests/ConfigConsistency.spec`). All Legendary, one level, the Assassin's, group "dagger".

| Dagger (set) | Card | What it does | How |
|---|---|---|---|
| Twinkle (Starwish) | **Wishing Star** | Every 5th strike that lands drops a star on the first enemy struck: 0.35 s later it bursts 6 studs round it for 0.8x a strike | an `AreaStrikes` strike that follows the enemy |
| Spur (Tumbleweed) | **Spur Rowel** | The double stab flings a spur rowel that hops between 3 enemies (12 studs to the first, 14 a hop), 0.5x a strike each | Shield Throw's flight, shared as `ClassUpgrades.throwHops` |
| Squirt (Splash Day) | **Splash Wave** | Every 3rd strike that lands splashes 5 studs round the first enemy struck: 0.4x a strike, and what it soaks moves 30% slower for 2 s | `EnemyManager.slow`; `SoakedUntil` on the enemy |
| Token (Coin-Op) | **Combo Counter** | Each strike that lands adds +3% to every blow (the dash's cut too), up to +30% at 10; a hit taken empties it | `AssassinUpgrades.comboScale`, `onHurt`; `ComboCount` on the player |
| Comet (Voidglass) | **Comet Crash** | A strike calls a comet onto the enemy: 1.5 s later it crashes 5 studs round it for 0.6x that strike; one comet an enemy at a time | an `AreaStrikes` strike that follows the enemy, from `MeleeSystem`'s `strike` (swings and the dash's cut) |
| Bellchime (Lantern Bloom) | **Bell Chime** | Every 6th strike that lands rings a bell: everything within 8 studs is held 0.8 s (a boss slowed to 60% instead) and takes 0.4x a strike, unshoved | `EnemyManager.root`, as Root Hold |
| Embershard (Cinderforge) | **Lava Burst** | The double stab sends lava 10 studs on from the stab, 4 wide: 0.5x the stab to each enemy as it arrives, and it burns 3 s at Blaze's rate | Shockwave's lane (`SwingBox.waveAlong`), `Combat/Burning` |

- **A strike that lands** is a swing that struck something (Fan of Knives counts every swing).
  Numbers in `Balance.Player.daggers`, each card's own in its level; the splash and the lava
  shove a third as far as a hit (as a dagger's slash), the bell not at all.
- **Looks** (`Fx/Upgrades/DaggerFx`), voxel cubes in each set's two glow colours: a gold star
  falling with a sparkle tail and a ring of gold and pink; a turquoise-and-gold spiked wheel
  rolling from enemy to enemy with a dust puff at each; a ring of water and droplets, and drips
  off the soaked; red arcade pixel digits over the head ("x7"), gold when full, shattering on a
  hit; a violet comet glinting high over the enemy, then crashing with a pink tail; a gold bell
  swinging over the head, a ring of light, a ring of gold round each held enemy's feet; lava
  bursting out of the floor one after another along the line.
- **Icons**: Codex in the set's style (`assets/concepts/blocky/ui/cards/themed_daggers_prompts.py`),
  composed on the Legendary tile by `compose_icon.py` and uploaded (`Config/CardAssets`). The
  cards are not shown in a run (the Gear screen shows the dagger's effect line); the icons are
  there for when they are.
- **Sounds**: eight in `Config/Sounds` (`fx_wishing_star`, `fx_spur_rowel`, `fx_splash_wave`,
  `fx_combo_counter`, `fx_combo_break`, `fx_comet_crash`, `fx_bell_chime`, `fx_lava_burst`), the
  owner's picks of audition round 34 (`assets/audio/daggers_synth.py`), in one sprite with
  Thornwood's two (`assets/audio/final/dagger_sprite_r34.mp3`, uploaded 2026-11-19).
- **Specs**: `tests/ThemedDaggers.spec` (each dagger its card, never dealt, on with its dagger
  only, the numbers, the count driven through `AssassinUpgrades`, the lava's lane, and no effect
  worth more than the strikes it rides on).
- **Seen** (2026-11-18, Studio sandbox Play, by probe): all seven fire with their own dagger in
  hand; enemies soaked, held and burning; the count rises to 10 and a real hit empties it.
  **Not seen:** the looks on screen (captures drew no 3D that night) and phone size.

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

## The owner's eleven picks (2026-11-03)

From `docs/CARD-IDEAS.md`'s forty: **Windrunner, Thornfall, Headhunter, Ghost
Quiver** (Ranger), **Twin Elements, Time Dilation, Prismatic Burst**
(Arcanist), **Guard Break, Bull Rush, Blood Pact, Vengeful Spirit** (Warden).

Brought up to date with main on 2026-11-27 (PR #462): **Guard Break, Blood Pact
and Vengeful Spirit are both melee classes'** (`MELEE`, as Boar Rush and Ruin
Cracks are; Guard Break acts on the combo's last blow, the Assassin's double
stab), which keeps the pools within three: Arcanist 32, Warden 32, Ranger 31,
Assassin 29. A spirit shoves as its owner's first blow does, so the Assassin's
shoves a third. Two numbers were brought into the live band: **Ghost Quiver**
copies the volley at 30% (was 40%, the share Orbiting Orb and Phantom Blades
strike for), and **Blood Pact** is +30% / +50% (was +40% / +70%, under
Execute's Legendary +40% / +80%). Bull Rush is the Warden's alone: the
Assassin's Shadow Dash already cuts.

Rules in `Combat/ClassUpgrades` and `Combat/MeleeSystem`, numbers in
`Balance.Player`, FX in `Fx/Upgrades/WardenBuildFx` and `ArcanistBuildFx`.
That doc's table says per card which machinery each reuses.

## Who gets what

- **Every class (12):** Strength, Precision, Deadly Strike, Blaze, Momentum,
  Agility, Lightfoot, Vitality, Mending, Bloodthirst, Second Wind, and the
  Heal filler. These already work for any attack.
- **Ranger only (16):** the arrow cards: Multishot, Front Arrow, Double
  Shot, Rear Arrow, Side Arrow, Diagonal Arrows, Piercing Shot, Swift Arrows,
  Long Shot, Bouncy Wall, Ricochet, Blast Arrows, Soul Chain, Overdraw,
  Tracking Eye, Dual Bows (its Mythic).
- **Warden only (13)** and **Arcanist only (12):** below.

**Built:** every row, wave 2's included (the last five on 2026-11-26, above).

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

Every card's icon is uploaded and its id is in `Config/CardAssets` (wave 2's
last five since 2026-11-26, redrawn by Codex in the set's style).
Forty further ideas, and which of wave 2 is now cheap, are in
[CARD-IDEAS.md](CARD-IDEAS.md). Cleave's and
Echo Slash's carry a faint grey smudge at the disc's left edge; regenerate
those two if it shows on a card.
