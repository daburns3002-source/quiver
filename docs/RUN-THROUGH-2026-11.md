# Run-through with every class, 2026-11-15 and 16

> **All fifteen bugs below were fixed on 2026-11-16** (the owner: "Fix all 15"): what each was and what was
> measured after is in `docs/FIXES.md`, "The every-class run-through's fifteen". Bug 4 turned out to be a
> log line with nothing missing on screen, so no code changed for it. The balance list is still to decide.

Played in Studio on `main` at #612 (feac538d). **No game code changed, no PR.** This is the
tracker's "big one": every class through Mossy Glade, every open area and its boss with one class,
and Endless.

**What was played**

| What | Class | Gear (see "The rig") | Result |
|---|---|---|---|
| Mossy Glade 1-1 to 1-10 | Ranger | new player's | won all ten, 46 min |
| Mossy Glade 1-1 to 1-10 | Arcanist | new player's | won all ten, 47 min |
| Mossy Glade 1-1 to 1-10 | Warden | new player's | won all ten, 37 min |
| Thornwood 2-1 to 2-10, the Broodmother | Ranger | mid | won all ten, 41 min |
| Drowned Village 3-1 to 3-15, Old Tollcrab | Arcanist | mid | won all fifteen, 72 min |
| Bogheart Caverns 4-1 to 4-15, Grandmother Gulp | Warden | strong | won all fifteen; 50 min for the 13 levels timed |
| Bogheart 4-1 | Ranger | nothing at all | won, no damage taken |
| Endless, 13 floors | Ranger, Arcanist, Warden | mid, mid, strong | no floor stuck; 2.5 to 3.5 min a run |

By hand, as a brand-new player (the Ranger's Play): class select, VICTORY and its three chests,
King Bloblin's story beat, the badge case, REWARDS (all three tabs, CLAIM ALL), PLAY's area and
level screens, Gear and an item card, the STORE (both tabs, nothing bought), DEFEAT.
At the end of the third Play: the Hatchery (one egg hatched, with the purchase burst), the
Blacksmith (CRATES and STORE) and the Dex.

**The rig, and what it means for every number below**

- The levels were played by an autopilot (`run-through-bot/` in the shared notes folder): it
  **stands still and shoots** (the Warden walks up to the nearest enemy), walks to the gate, and
  takes a **random card**. A blow that would have killed is counted as a "would-be death" and
  health goes back to full, so every level is finished and the count says how rough it was.
  A real player dodges, so read the deaths as a comparison between levels and classes, not as
  what a kid will suffer.
- Studio ran unfocused at about 15 frames a second. Times are level time on the game's own clock.
- Gear was set by the bot so the classes can be compared: 1-1 nothing; 1-2 to 1-4 one Common pet;
  1-5 to 1-10 a Rare weapon (+25%) and two Common pets; Thornwood and the Drowned Village the
  balance bot's "L2" (weapon x1.68, tier B Glade Fox and Slime Prince); Bogheart its "L3"
  (weapon x3.67, tier S Glimmerhorn and Ember Wilf).
- **The owner's account owns 2X COINS and VIP, so every coin number here is about 2.2 times a
  normal player's.**
- Marks: *(code)* read from the code, not seen. *(known)* already on the tracker or in the
  2026-11-14 review, repeated only where it is still there.

---

## Bugs, worst first

1. **Prize crates (and, in playtest, prize eggs) come from Bogheart, whoever you are.** A Ranger
   who had beaten nothing reached class level 3 after two wins and its free crate was Bogheart's:
   Peatwood Bow. Level 5's free egg was a Bogheart egg (Lichen Gecko). CLAIM ALL then hatched three
   more Bogheart eggs and opened more Bogheart crates: after ten wins the new player held Prism
   Leviathan, four Lichen Geckos, a Lanternfin, a Bog Beaver and three Bogheart bows, one of them
   the Epic Glowcap Longbow at **DAMAGE x1.99**. The gift box's picture on REWARDS is Bogheart's too.
   *(code)* `PrizeRules.crateIndex` takes "the furthest area that has weapons for the class" and
   never asks `ShopRules.crateOpen`; it was written when only Mossy Glade was stocked, and the
   Drowned Village and Bogheart were stocked on 2026-11-13. `PrizeRules.eggKey` does ask
   `EggRules.open`, so with launch locks ON the eggs are right and **the crates are still
   Bogheart's**. It reaches every prize crate: class level 3, the quests' chest, the gift box,
   goals, star chests, Dex chests. Victory's own chest is right (it gave Mossy's and Thornwood's).
   **Fix (small):** the furthest crate the player has opened the way to, as the egg does; and say
   whether playtest should hold prizes back too, or the playtest's first hour is not the launch's.
2. **A new weapon is never put in your hand.** Pets go on by themselves as they hatch; weapons do
   not. After ten wins the Ranger still held the Twig Bow with an Epic x1.99 bow, a Rare and an
   Uncommon in the bag, and nothing in a run says so. (The golden weapon at class level 10 does go
   on by itself.) **Fix (small, your call):** equip a new weapon when it beats the one held, or
   put a badge on GEAR.
3. **NEXT LEVEL on an area's last level goes to the lobby.** VICTORY at 1-10 shows NEXT LEVEL and
   BACK TO LOBBY; NEXT LEVEL played the story beat and then put me in the lobby, not in 2-1.
   **Fix (small):** start 2-1 when it is open, or show only BACK TO LOBBY there.
4. **Four Bogheart pictures or meshes do not load.** Client and server both log
   `ContentId: rbxassetid://... failed ... No asset content representation found` for
   `86786943496634` (on entering 4-1, twice in two Plays), `137629051699538` (4-3) and
   `123424247086989` (4-7, 4-8) and `124939475424728` (Grandmother Gulp's room). Something in
   those levels is drawn without its asset. And on every
   join: `rbxassetid://203785492 failed due to: Asset type does not match requested type`.
   **Fix (small to medium):** find what uses each id; re-upload or correct the type.
5. **The first-time TIP still covers what it explains on two screens** *(known, half fixed in
   #611)*. Class select: it covers the Arcanist's and the Warden's LEVEL chips, with its words in
   two tiny lines. STORE: it covers the words of both tabs (GEMS, PASSES). Hatchery: it came up
   over the hatch itself and covered the NEW DEX ENTRY toast. On REWARDS, GEAR, the Blacksmith and
   the Dex it now stands on the title bar, as #611 meant.
6. **An egg's reveal plays over REWARDS, which stays on screen behind it.** After CLAIM ALL, three
   eggs hatched over the dimmed screen and "YOU HATCHED SOMETHING SPECIAL.." ran across the CLAIM
   ALL button's words. **Fix (small):** hide the screen while a reveal plays, as the Hatchery does.
7. **CHOOSE AN AREA: the NEXT UP card hangs out of the panel.** It is drawn bigger than the
   others and its foot (the gold PLAY) sits below the panel's bottom edge. A thin white selection
   rectangle is drawn round it, round PLAY on the level screen and round the in-run MENU button
   (seen with Studio's synthetic mouse; check with a real one).
8. **PICK A CHEST: the row of stars is uneven,** WIN at the far left, OVER HALF HEALTH and UNDER
   10:25 pushed together on the right with the third star touching "HEALTH". Behind the panel the
   VICTORY banner, the class plate and BACK TO LOBBY still poke out *(known)*.
9. **Gear's hero is still cut** *(known, half fixed)*: the pets round the hero run under PET 2's
   tile and the hero stands above the grey pedestal. The plates are clear of PET 3 now and the item
   card's dim reaches the window's edges (both seen).
10. **OPEN 1 WEAPON CRATE does not count a prize crate.** After seven free crates had been opened
    with their reveals, the daily quest and the goal both read 0 / 1. **Fix (small, your call):**
    count them, or word it BUY A CRATE.
11. **The level card does not say what a missing star asks.** 1-3 and 1-10 showed two stars of
    three; the card says 25 ROOMS, the boss, CLEARED and the pay, nothing about health or time.
    The Victory panel's art also always has three gold stars over the trophy, whatever was won.
12. **STORE, small:** the panel is shorter on PASSES than on GEMS (it jumps) *(known)*; the
    passes' lines are in small letters ("Every kill and clear") where the screen is capitals.
13. **A warning in every level with a Bramble Sow** (Thornwood 2-4, Drowned 3-7):
    `[ModelAnimator] Workspace.Enemies.Boarlet's parts do not line up with BrambleSow (fit error
    0.088)`, and in Endless's Thornwood floors the same for the Bramble Sow herself (0.16).
    Nothing seen wrong by the bot; worth a look at both.
14. **The Blacksmith's CRATES opens on BOWS whatever your class** (a Warden's STORE lists blades
    first, as #612 meant; CRATES does not follow).
15. **At the exit the player is under the HUD** *(known as "the HUD over the spawn")*: the gate is
    at the top of the screen, under the XP bar and the ROOM and CLEARED lines.

Nothing soft-locked. No level, floor, draft, Angel, checkpoint or end screen failed to go on in
71 won levels and 39 Endless floors, and no script error came from the game in any of them.

## Balance and feel (not bugs; the things to decide)

1. **1-4 is a cliff.** Standing still, 1-1 to 1-3 cost the Ranger 1, 0 and 0 would-be deaths;
   1-4 cost 7, all in its first three rooms (922 damage in the first room alone). That is where
   the 0.6 s breath after a hit (`hitGrace`, 1-1 to 1-3) stops. A ramp over 1-4 and 1-5 would
   soften it.
2. **The draft decides a level far more than the level does.** Same class, same gear, next level:
   Ranger 1-8, 2 deaths (four Strength, two Multishot); 1-9, 16 deaths (four Vitality, three
   Precision). Arcanist 3-11, **74** deaths; 3-12, the same size, **2**. That is the "two runs
   feel different" the tracker asks about, and it is real, but a random hand can also make a level
   eight times as rough. Worth a look at whether a hand can come without any damage card.
3. **Every new area starts softer than the last one ended, and softer than Mossy Glade.** 2-1:
   33 enemies, no damage taken (1-1 has 68). 3-1 and 3-2: 37 and 38 enemies, no deaths. Bogheart
   4-1 was **won by a Ranger with the starter bow, no pets and no gear, taking no damage at all**,
   in 143 s, for 10,634 coins (about 4,800 without the passes). With launch locks on nobody
   reaches 4-1 that weak, but the first levels of areas 2 to 4 are a rest, not a step up, and they
   pay four to eight times what 1-1 does.
4. **The time star is free.** The stand-still bot at 15 frames a second finished every one of
   71 levels inside its time, usually with a third to spare (1-1: 163 s of 250; 1-10: 511 of
   625; 3-15: 441 of 625). The health star is the only one that was ever missed.
5. **Coins pile up with nothing to spend them on.** With the passes: 29,000 after Mossy Glade,
   113,000 after Thornwood; the third Play (the Drowned Village, Mossy Glade again and Bogheart)
   ended on 508,000 (halve those and a bit for a player without passes). An egg is 500 and Bogheart's crate
   4,000. One late Drowned level paid 20,000. The Robux starter pack's 2,000 coins is less than
   one Thornwood level.
6. **Class level 10 came on the 21st win** (150 to 300 XP a win), so "about 20 runs to gold" is
   right. Levels 2 to 8 came in the first ten wins.
7. **Endless's first floors are over in seconds at mid gear.** 13 floors took the Ranger about
   140 s; floor 10's King Bloblin fell in 14 s (35 s to the Arcanist).

## The three classes

| Mossy Glade | Ranger | Arcanist | Warden |
|---|---|---|---|
| 1-1 to 1-10, time | 46 min | 47 min | **37 min** |
| Would-be deaths | 29 | **83** | 19 |
| Damage taken | 9,300 | 24,600 | 25,000 |
| 1-10, time and deaths | 8:31, 0 | 7:18, 3 | 6:48, 7 |
| King Bloblin's room | not timed | 47 s, 2 deaths | 59 s, 1 death |

Seconds a level, 1-1 to 1-10: Ranger 163, 202, 290, 309, 228, 240, 272, 245, 315, 511.
Arcanist 181, 187, 288, 246, 257, 248, 285, 380, 320, 438. Warden 144, 135, 221, 222, 230, 235,
219, 203, 210, 408. Would-be deaths: Ranger 1, 0, 0, 7, 1, 1, 1, 2, 16, 0. Arcanist 4, 2, 1, 4,
3, 3, 24, 9, 30, 3. Warden 0, 0, 1, 1, 3, 3, 0, 2, 2, 7.

- **They do feel different, by their cards as much as their weapon.** Each class drafts from its
  own pool: the Ranger shapes a volley (Wind Arrows, Piercing Shot, Double Shot, Ricochet, Side,
  Rear and Diagonal Arrows, Sniper Shot, Split Shot, Rain of Arrows, Phoenix Arrow, Dual Bows),
  the Arcanist its orbs (Mana Flow, Mana Surge, Bigger Orbs, Diagonal Orbs, Spell Pierce, Twin
  Cast, Arcane Echo, Chain Lightning, Frost Orb, Elemental Orbs, Arcane Shield, Arcane Turret,
  Black Hole, Meteor, Tracking Eye), the Warden its swing (Quick Hands, Cleave, Whirlwind,
  Shockwave, Heavy Blade, Long Reach, Parry, Counter Strike, Shield Throw, Battle Cry, Execute,
  Sunder, Titan's Grip, Blade Storm). Only a dozen cards are shared (Vitality, Precision, Deadly
  Strike, Lightfoot, Blaze, Bloodthirst, Heal, Second Wind, Soul Chain, Strength or Intellect).
- **The Warden is the strongest, clearly.** Nine minutes quicker through Mossy Glade and the
  fewest deaths, while taking the most damage: 2.2 times the health (495), lifesteal and heals
  carry it. It also walks into every enemy, which the bot does for it; a kid may find that harder
  than the numbers say.
- **The Arcanist is the weakest for a player who stands still.** The Ranger's health with shots
  at 0.6 of the speed and half the rate: the waves of 1-7 to 1-9 reach it (24, 9 and 30 would-be
  deaths against the Ranger's 1, 2 and 16). Its clear time is the same as the Ranger's, so it is
  not short of damage, it is short of safety. A kid who kites will feel this less; a kid who does
  not will bounce off 1-7.
- **The Ranger is the easy one,** as meant: almost untouched until 1-4, and through 1-10 on 1%
  health without a death.
- Pay is the same for every class, level for level.

## Areas and bosses

- **Mossy Glade.** 2:15 to 6:20 a level, 1-10 about 7 to 8.5 minutes (25 rooms). The climb is
  gentle except the step at 1-4 and whatever the draft does to 1-7 to 1-9. King Bloblin is fair:
  the Ranger got through on 1% health with no death, the others with 1 or 2 in his room. 1-10
  gave about 16 cards over its 25 rooms: not starved.
- **Thornwood (Ranger, mid gear).** Ten levels in 41 minutes: 132, 126, 180, 250, 191, 273, 270,
  360, 297, 391 s; would-be deaths 0, 1, 1, 7, 3, 5, 7, 2, 0, 4 (30, as Mossy Glade's 29). A step
  up, not a wall, with the same soft start. The Broodmother's level: 25 rooms, 6:31, 4 deaths.
  2-8 and 2-9 have twice the enemies of 2-7 (214 and 239 against 100), so the count wanders.
- **The Drowned Village (Arcanist, mid gear).** Fifteen levels in 72 minutes, the longest area;
  would-be deaths 0, 0, 2, 3, 6, 4, 2, 0, 15, 14, 74, 2, 8, 25, 6 (161). Its second half is where
  mid gear stops being enough. Old Tollcrab's room: 51 s, 2 deaths. **It fights Thornwood's
  enemies** (Bramble Boar, Burr Thistle, Bramble Sow and Boarlets) with one of its own, the Hollow
  Fisherman: by design until its own are modelled *(code: `tools/area_levels.py`)*, but a player
  will notice that area 3 is area 2 in the water. Enemy counts jump about here too (3-10: 102;
  3-11: 228; 3-13: 111).
- **Bogheart Caverns (Warden, strong gear).** Fifteen levels, all won: 95 to 325 s a level,
  Grandmother Gulp's level (25 rooms) 5:47; would-be deaths 0, 1, 1, 1, 2, 1, -, 0, 1, 1, 4, 4,
  5, 5, 2 (28 in 14 levels). With tier S gear it was as gentle as Mossy Glade
  (two would-be deaths a level, the Drowned Village's eleven at tier B), and Gulp's own room took
  39 s with no would-be death: at that gear she is no boss.
  The pets alone cleared rooms 10 to 14 of 4-7 while my bot was down. So Bogheart was not tested
  at the gear a player will really bring; what gear that is wants deciding first. Two levels are
  not timed (4-1 and 4-7, my bot's faults, below). **Bot limit, not a game bug:** a melee bot that
  ends a room beside the stream cannot find the bridge by walking straight up; the gold tile
  trail to the gate was drawn and right every time, and a helper carried the player to the gate
  26 times. The arena was seen once: stream, bridge, mushroom blocks; the cyan is very bright.
- **Endless.** Floors of 5 to 17 s at these loadouts, a checkpoint with its prize screen at floor
  10, Thornwood from floor 11. Floor 10's
  King Bloblin: 14 s (Ranger), 35 s (Arcanist), 20 s (Warden, strong gear). Would-be deaths in
  13 floors: 1, 8, 1. Leaving at floor 13 paid about 750 coins (passes on) and 75 Soulstones.

## The tracker's "a look in the game" rows: what this run saw

Seen working (desktop size, Studio):

- **REWARDS in three tabs** with a red count on each; the lobby badge, the tabs and CLAIM ALL
  agreed (18 = 4 + 2 + 12); **CLAIM ALL** claimed all 18 in one press with one reveal. QUESTS rows
  (picture, bar, pay, GO or DONE), the chest's three pips, GOALS' medals count (7 / 60 MEDALS WON).
- **The gift box** (3 GIFTS READY!, OPEN) and its opening through CLAIM ALL.
- **Victory's three chests** and the **win streak** line (WIN STREAK 10: NEXT LEVEL +50% COINS);
  the streak carries through BACK TO LOBBY and went to 0 on a loss. The chests' prizes were the
  area's own egg or crate, coins or 2 to 4 gems.
- **Level stars**: on the Victory panel with what each asks, and under every level on the level
  screen. The star and Dex chests were claimed inside CLAIM ALL, not looked at one by one.
- **PLAY: CONTINUE 2-1** over the areas, NEXT UP on the right area, the 2 x 5 level grid with
  CLEARED and the boss's icon on 1-10.
- **VICTORY and DEFEAT recoloured**, the **class plate** beside both, the boss item on the egg
  slot's corner, YOU CAN HATCH AN EGG!, FREE EGG x1; DEFEAT's **MERGE PETS TO GET STRONGER** with
  every pet slot full, and coins alone when no gems were paid (#611's item 7, both halves).
- **Class levels**: 150 to 300 XP a win; the crate at level 3 and the egg at level 5 came (see bug
  1 for which ones); +200 to +800 coins and 30 or 40 gems on other levels; level 10 on the 21st
  win with the **Golden Bow in hand by itself** (read from the save, its card not seen).
- **King Bloblin's story beat** after a real boss win, clicked through, then on to the lobby.
- **BADGES opening by itself** with NEW BADGE! after a first boss win, twice (King Bloblin, the
  Broodmother).
- **#611's fixes:** tips on the title bar on REWARDS and GEAR; Gear's dim and plates.
- **#612's:** CONTINUE; the tab badges on the corners; GOALS' medal count; the store's names in
  capitals; no HEALTH LEFT 0% on a win (1-10 read 1%).
- **The merge tier letter**: the bronze C on Gear's slots, tiles and item card (no other tier
  was owned).
- **The balance pass's "play a run in each later area"**: done by bot in all three; see "Areas".
  A pet's kills show: pets dealt 10 to 15% of the damage with two Commons, 15 to 25% at tier B,
  30 to 45% at tier S.
- **Endless**: the checkpoint at floor 10 and the area change at floor 11, by the log.

Seen not working, or not as the row says: bug 1 (the class level gifts), bug 5 (tips), bug 3.
The lobby's softer colours were seen (a pale pink floor, not white): your taste.

Also seen at the end of the third Play:

- **The purchase burst** on a hatched egg: KA-CHING!, -500 under it, coins flying, bottom left,
  clear of the egg dropping in. Big enough to my eye. Not seen for a crate, a store weapon, a
  trail or Soulstones.
- **The Hatchery**: the egg on its stand, PETS INSIDE with full rarity colour, the chance to one
  place, owned ticks, tier letters, the unowned Mythic a black silhouette, MYTHIC IN 66, and
  [E] [R] [T] on the buttons. It lays the eight pets out three across (3, 3, 2), not four as the
  row says. The Legendary tiles' glow still spills over their neighbours and "8 PETS" *(known)*.
- **The Blacksmith**: CRATES (BOWS / STAFFS / SWORDS, odds to one place, the Mythic a silhouette,
  the keys on the buttons, the area picker) and STORE (the class's weapons first for a Warden, ATK
  under every name, a Legendary's price as the coin number with the Royal Jelly's picture and x3).
  Mossy Glade's bow chest holds four bows, so two across, not the row's three for six.
- **The Dex**: ENEMIES opens on a found entry (Baby Slime); Mossy Glade's page green in a wood
  frame with its plate, 4 / 4 FOUND, big tiles, motes, the scenery behind the entry. Only that
  page was looked at.

## Not covered

- **A real phone, touch, the upright layouts, a gamepad.** Out of reach from here.
- **Two real players in co-op.**
- **Sound.** Nothing was heard.
- **How fights look.** The bot played them; I took a handful of captures. Effects, the class
  cards' size at the camera's distance, hit flash, knockback, the Angel, NEW ENEMY!, the bosses'
  moves, pet attacks and the arenas against their sheets were not judged.
- **A player who moves.** Every number is a stand-still player's.
- **The intro, title, story and tutorial** (skipped with `SkipIntro`).
- **Launch locks on.** Never turned on; bug 1's launch half is from the code.
- **Anything bought with Robux**, the purchase burst on a real receipt, REVIVE.
- **Every weapon and every pet** (the tracker's row says so): only the bot's six pets and the
  classes' base weapons fought. Trails, merging, the Soulstone shop, the leaderboards.
- The story beats and badges of the Broodmother's story, Old Tollcrab and Grandmother Gulp by eye
  (the bot left those Victories by remote); Endless's own DEFEAT.
- Each later area was played by one class only: Thornwood by the Ranger, the Drowned Village by
  the Arcanist, Bogheart by the Warden.
- The in-Roblox test suite was not run. Studio was handed back in Edit, synced to `main` at #615.
- Two Bogheart levels have no time: 4-1 (the bot stood at the stream for five minutes) and 4-7
  (the bot's own log filled Roblox's 200,000-character limit and it stopped; the game was fine).
