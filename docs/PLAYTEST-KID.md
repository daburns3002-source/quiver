# Playtest as a 10 to 13 year old with a short attention span (2026-11-14)

Played in Studio on `main` at 47bab46c (#591, the Robux store). **No game code was changed.**
These are notes and proposed fixes; tell me which numbers to build.

## How it was played

- Two Plays. **Play 1, a brand-new profile** (Studio's test wallet switched off for the Play):
  join, title, story (SKIP), tutorial, class select, lobby, 1-1 to VICTORY, the starter offer,
  1-2 (one death, one retry), then the lobby: Hatchery, Gear, STORE, REWARDS, Blacksmith.
  **Play 2, the test profile** (all levels open): title, class select, level select, then the
  last room of 1-10 for King Bloblin.
- Played by hand through the real buttons and keys: mostly standing where the level puts you
  and letting the bow fire, walking only to the exit. That is how an impatient kid plays first.
- A recorder script (made for the Play, deleted after) stamped every screen, room, kill, hit,
  draft and click. **All seconds below come from its stamps**, not from my own slow hands; where a
  number is worked out rather than measured it says so.
- Limits of the rig: Studio was unfocused at 12 to 15 frames a second, so walking times may be a
  little long. Loading time is Studio's. The owner's account owns the three passes, so the VIP
  daily gems arrived at join and both pet slots were open.

## The first session on a kid's clock

| Moment | Measured | Taps |
|---|---|---|
| Join to the first button (BEGIN ADVENTURE) | 18.0 s and 18.3 s (12.2 s of it loading) | 0 |
| BEGIN ADVENTURE to SKIP showing | 1.6 s | 1 |
| SKIP to tutorial room 1 live | 0.9 s | 1 |
| Room 1 live to NEW ENEMY! card | 1.0 s, then it waits for GOT IT! | 1 |
| GOT IT! to the first arrow | 0.7 s | |
| **Join to first arrow, fastest possible** | **about 25 s, 3 taps** (worked out from the rows above; 68 s without SKIP, using the 43 s story measured on 2026-11-12) | 3 |
| First arrow to first coin | 1.2 s | |
| First arrow to first level-up draft | 3.9 s | |
| Tutorial, five rooms of fighting | 3.1 to 8.7 s a room, about 27 s in all | |
| Walk from a cleared room to the next | 4.7 to 5.5 s, every room | |
| 1-1, ten rooms | fights 5.3 to 14.0 s, 94 s in all; 68 kills; 8 drafts; 10 walks | 16 for drafts |
| 1-1 start to VICTORY | about 3.5 min for a kid (worked out: 94 s fights + 50 s walks + drafts; the balance bot measured 3.4 min) | |
| VICTORY to the free pet reveal ending | 8.3 s | 0 |
| Lobby PLAY to level 1-1 fighting | 2 taps, under 1 s of loading | 2 |
| Hatch 3 eggs, reveal | 5.1 s | 1 |
| Weapon crate, reveal | 4.9 s | 1 |

## What bored or lost me, worst first

**1. I died twice in the tutorial, both times unfairly.** *Where: tutorial rooms 2 and 5.*
- Room 2: I held UP into the room, stopped behind the log at (0, 7) and stood still as the
  popup says. In 22 s I fired 40 arrows; the Splitter Spitter at (-10, -1) ended on full health
  (112 of 112) and I took 14 hits and DEFEAT. A ray from me to it hits `Arena.Blockers.Obstacle1`
  and `PlayerWalls.PlayerWall1`: the log stops my arrows and not its seeds. This is B4 from the
  2026-11-12 playtest, still there.
- Room 5: the room went CLEARED at 399.1 and I was DEAD at 399.6, from 2 hits in that half
  second. Seeds already in the air still hurt after the room is won. (Same thing between rooms 3
  and 4: 2 hits after CLEARED.)
- DEFEAT there says "HATCH PETS TO GET STRONGER" (no pets yet) and TRY AGAIN restarts at room 1
  of 5 with the same three cards.
- Kid: "I did what it said and lost." Second death is where I would have closed the game, about
  3 minutes in.
- **Fix:** the tutorial cannot be lost (health stops at 1); enemy shots are removed the moment a
  room is CLEARED, in every level; move room 2's centre log off the spawn-to-enemy line.
  Touches `Run/RoomController` (clear shots on clear), the enemy shot module, the tutorial rows
  in `Config/Balance`, and `Config/Tutorial` for the 1 HP floor.

**2. Too many stop-and-press-OK popups.** *Where: everywhere in the first 20 minutes.*
- Counted in Play 1: **13 first-time tips** (Gems, Class, Rewards, Portal, Reroll, Defeat, First
  Pet, Hatchery, Merge, Gear, Store, Blacksmith, New Weapon), **4 NEW ENEMY! cards**, plus the
  tutorial banners. 17 full stops, each pausing the game until a button is pressed.
- Worst spots: two cards before the first arrow; NEW ENEMY! twice inside one fight (1-1 room 4,
  8 s apart, the second in the middle of the swarm); a tip on top of the draft; a tip on top of
  DEFEAT next to the revive offer; a tip on top of the STORE (in very small letters).
- Kid: mashes OK without reading, so the tips teach nothing and only slow things down.
- **Fix:** tips become a small banner that fades by itself after 4 s and never pauses a fight
  (keep the pause only for Class and Reroll); NEW ENEMY! in a fight becomes the enemy's name over
  its head for 2 s, with the full card kept for the Dex. Touches `UI/FirstTips`, `Config/Tips`,
  `UI/NewEnemyScreen`.

**3. Level 1-2 killed me in 11 seconds, then asked for Robux.** *Where: 1-2 room 1.*
- After 1-1, standing at the spawn was safe (0 hits in rooms 1, 6 and 7). I did the same in
  1-2 room 1: 10 hits, dead at 0:11, PROGRESS 0%. The REVIVE? offer (15 R$) covered DEFEAT 1.3 s
  later. On the retry the same room took 13 s and 0 hits, so it swings a lot (my reading, not
  proven: the first roll put a Spitter behind cover again).
- The cards also reset: I went from seven skills at the end of 1-1 to a bare bow.
- The starter pack offer (99 R$) had come up 36 s earlier on my clock, when I pressed NEXT
  LEVEL on my first VICTORY. For a kid that is two price tags about 15 s apart, around a death.
- **Does the starter offer interrupt the fun?** A little. It is one tap to close and it never
  comes back, which is good; but it answers NEXT LEVEL with a price, on the kid's first win.
- **Fix:** 1-2 room 1 is three Moss Slimes (no Spitter until room 3); no revive offer in a
  level's first three rooms; the starter offer moves to the lobby after the second win. Touches
  `tools/glade_levels.py` (regenerates the rows in `Config/Balance`), `Util/StoreRules.reviveOffer`,
  `UI/RobuxOffer`.

**4. The same three enemies in the same arena for the whole first area.** *Where: 1-1 to 1-10.*
- From the config: every Mossy Glade room and wave is drawn from Moss Slime, Brood Slime (with
  its babies) and Splitter Spitter, in one arena look (`GladeLogs`). That is 175 rooms and waves
  before the King. I had met all three by room 4 of 1-1, minute 5.
- 1-1 rooms 1, 2 and 3 are three Moss Slimes each, straight after a tutorial of the same.
- Level select shows NO BOSS on nine levels out of ten.
- Not played: 1-3 to 1-9. I expect a kid to drift off around 1-3 or 1-4 (15 rooms each).
- **Fix (needs your call, it is the biggest one):** one new enemy by 1-3 and another by 1-6,
  and a champion at the end of 1-3 and 1-6: a big Brood
  Slime with a health bar and a chest, so the pills can say MINI BOSS. King Bloblin stays at 1-10.
  Touches `tools/glade_levels.py`, `Config/Balance`, `UI/PortalScreen`.

**5. The draft takes two presses, eight times a level.** *Where: every level-up.*
- Tap a card, then tap CHOOSE!. 8 drafts in 1-1, so 16 taps; twice two drafts came back to back
  (1.5 s apart).
- **Fix:** on touch and mouse, tapping a card takes it (a second tap on the same card if you
  want a safety); CHOOSE! stays for controllers. Touches `UI/Cards/DraftScreen`.

**6. New pets and weapons do not go on, and nothing shows they made me stronger.** *Where: lobby.*
- I hatched 3 eggs and PET 2 stayed empty. The crate's Acorn Bow stayed in the bag. Putting each
  on means: walk to GEAR on the other side of the plaza (about 5 s), a tab, the tile, EQUIP.
- Gear's plate read ATK 100 HP 225 before and after equipping a second pet and after merging
  to tier B. MERGE also closes the panel, so equipping the merged pet is two more taps.
- HATCH 3 gave three of the same Common (bad luck, but 1,500 coins is more than a whole 1-1 run
  pays: 1,239).
- **Fix:** a hatched pet fills an empty pet slot by itself; the reveal of a stronger weapon has
  an EQUIP button; Gear's plate counts pets and pops when it goes up; the panel stays open after
  MERGE. Touches `Data/Hatchery`, `UI/Reveal`, `UI/GearScreen`.

**7. Dying at King Bloblin means the whole level again.** *Where: 1-10 room 25.*
- DEFEAT at the King reads PROGRESS 96%. TRY AGAIN starts a level from room 1 (seen in the
  tutorial); 1-10 took the balance bot 9.2 min. The other way on is 15 R$.
- The King has 18,238 health. With a bare level 1 bow I took off 1,500 in 16 s and died, which
  is not a fair fight to judge; a real run arrives with about 15 cards.
- **Fix:** one free retry of the boss room per run ("THE KING IS WAITING: TRY AGAIN" restarts
  room 25 with your cards), then the normal rules. Touches `Run/RunSession`, `UI/EndScreen`,
  `Util/EndScreenRules`. Your call, since it makes the revive worth less.

**8. 18 seconds before the first button, every time you join.** *Where: loading and title.*
- Loading 12.2 s (Studio; a phone will differ), then 5.8 s of DYL.DEVS PRESENTS and title with
  nothing to press. A returning player sits through it each visit.
- **Fix:** BEGIN ADVENTURE is pressable as soon as the title shows, and PRESENTS is 2 s for a
  profile that has beaten 1-1. Touches `Config/Intro`, `UI/IntroCutscene`.

**9. The walk to the exit, about 5 seconds, 175 times.** *Where: after every room.*
- 4.7 to 5.5 s with nothing happening, plus one more after the last room before VICTORY.
- Holding UP stops dead on a log on the centre line (1-1 rooms 2 and 4 have one at the middle).
- **Fix:** coins fly to the player on CLEARED (if they do not already) and the player runs 30%
  faster while the exit is open; the last room goes straight to VICTORY. Touches
  `Run/RoomController`, `Input/MoveController`.

**10. Small things.**
- REWARDS held 4 claims (+105 gems, +500 coins) behind a small badge; make the badge bounce.
- The STORE tip is in much smaller letters than every other tip.
- The Gems tip fired in tutorial room 1 for a VIP owner (the daily gems land at join).
- The end screen's TIME (07:08 for 1-1) counts every paused second.
- MENU pressed while a draft is up left LEAVE THE RUN? open under it and the exit stayed shut
  for 40 s. I caused it with a stray click and did not try it twice; worth one look.

## Where a kid closes the game (my honest guess, in order)

1. The second tutorial death, about minute 3.
2. The 11 second death in 1-2 with the revive price on top.
3. Somewhere in 1-3 or 1-4, from sameness (not played, from the config).
4. Losing to the King and seeing room 1 of 25.

## The five I would build first

1. **Tutorial cannot be lost, shots vanish on CLEARED, room 2's log moved** (item 1).
2. **Tips fade by themselves and NEW ENEMY! stops pausing fights** (item 2).
3. **1-2 opens gently, no revive offer in the first three rooms, starter offer in the lobby
   after win two** (item 3).
4. **One-tap draft** (item 5).
5. **Pets and weapons go on by themselves and the power number moves** (item 6).

Item 4 (new enemies and mini bosses in Mossy Glade) matters most for the second hour, but it is
content, so it needs your say first.

## What already works, do not "fix" it

- Coins 1.2 s and a level-up 3.9 s after the first arrow. A draft about every room and a half.
- A Mythic card (Dual Bows) in my second level, with its own MYTHIC! headline: the best moment
  of the session.
- VICTORY: clear, bright, a free egg that hatches by itself in 5 s.
- NEXT LEVEL goes straight into 1-2 with no lobby detour.
- Lobby PLAY to fighting: 2 taps and under a second. PLAY opens the furthest area you have.
- The yellow squares to the exit; the Angel room (heal or strength) as a breather.
- Hatch and crate reveals are 5 s, not longer. Locked pets as silhouettes make you want them.
- The lobby reads at a glance: eggs on the Hatchery roof, the hammer on the Blacksmith.
- The STORE itself: tidy, one screen, never opens unless asked.
- DEFEAT's "HATCH PETS TO GET STRONGER" outside the tutorial: it sent me the right way.
- No timers or energy anywhere.

## Not reached or not checked

- **Phone size and touch** (needs you: the emulator is a Studio ribbon toggle).
- **A real returning player**: a Studio Play is always a fresh profile, so "skip the story and
  land in the lobby" is from the code, not seen.
- 1-3 to 1-9, Thornwood and later, Endless, co-op, the Arcanist and the Warden (Ranger only).
- The full story cutscene (I pressed SKIP both times).
- A fair King Bloblin fight with a real run's cards; whether TRY AGAIN at the King restarts at
  room 1 (expected, not pressed there).
- Sound. Nothing was bought; no launch lock was touched.
