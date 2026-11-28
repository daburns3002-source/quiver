# Release checklist (release check of 2026-11-19, for launch the week after)

Main at #641. A bug-fix-only pass: what is verified, what was fixed, what only the owner can do,
and what nobody has checked yet. Working notes and raw bot logs:
`side-session-notes/local_ce32ec60-.../release-check-notes.md`.

**Since the check (to 2026-11-26):** #666-#678 fixed what the live playtests and a full Studio sweep found (leftover models, loading screens, the lobby kick, falling through a floor, Bogheart textures, Drowned glow, Blaze wording), and made every button livelier. All of it is live in version 1166. The owner's boxes below are still open, apart from the Studio save. The same list, tickable: https://claude.ai/artifact/WTdpxewhuSmYyYkuHh2bZt.

## Verified

- **Gates:** `tools/check.sh` green on main. **In-Roblox suite:** 1,315 tests pass with the launch
  locks on (1,309 before this check's two PRs added 6).
- **Bot run-through on current main** (Studio, 15 fps, a new-player profile, the stand-still bot of
  `RUN-THROUGH-2026-11.md`, killing blows counted rather than landed):
  - Ranger, locks off, new player: Mossy Glade 1-1 to 1-10 (King Bloblin won), then 2-1, 3-1, 4-1,
    and 12 Endless floors through the floor-10 checkpoint.
  - Assassin, locks on, new player: Mossy Glade 1-1 to 1-10 (King Bloblin won). 2-1 and Endless
    opened only after 1-10, as the locks say. 12 Endless floors.
  - Arcanist, locks on, on the Assassin's profile (so replays): Mossy Glade 1-1 to 1-10, King
    Bloblin won again. Replays gave no free egg, as they should. Its level-5 prize egg was Thornwood's
    (King Bloblin beaten); its level-3 crate was Mossy Glade's (Thornwood's had no staffs then; stocked 2026-11-27).
  - Warden, locks on: 1-1 and 1-2 on the same profile, then Studio was closed and the rest of that
    Play was lost. A fresh Play with Studio's unlocks: Drowned Village 3-1.
  - Hard mode (Warden): 1-1 and 1-2 on hard won. They open in order (a hard 1-3 start was refused
    before 1-1 and 1-2 were won on hard), and each paid its first-hard-clear gems once
    (`Wallet.beatHard`).
  - No script error, stuck room, stuck draft, checkpoint or end screen in any of them. Pay matched
    the November run level for level. Prize crates and eggs came from the area the player had
    reached (the November run's bug 1 is fixed). The only log lines were Roblox's own (the
    203785492 sound, Studio's API refusals).
- **Saves:** a real version 28 profile from the bot run round-trips `SaveSchema.migrate` with no
  differences. The same profile cut back to a version 24 shape migrates, and only the new fields
  differ. `tests/SaveSchema.spec` covers versions 1 to 28.
- **Rewards pay once:** CLAIM ALL (a second press paid only a goal the first press had just
  finished), playtime gifts (claiming again paid nothing), season tiers (with the clock moved into
  December; premium refused without the pass), the Premium egg (once a day). The invite welcome
  is written only on a first-ever join.
- **Roblox's paid random items policy** (read 2026-11-19): settled with the owner and fixed (#640).
- **Published** to "Archer Legends [TEST]" by the owner on 2026-11-19, from a Studio holding
  exactly main with the locks on, with no test bot, hooks or test attributes in it.

## Fixed in this check

- **#640** The Starter Pack (eggs for Robux) was offered to players PolicyService restricts, and
  showed no odds. It is now `paidRandom`, ODDS on its tile and offer shows the Mossy Egg's pets and
  chances, and every printed chance is four figures with a rounding line.
- **#641** Launch locks on (owner: "Yes, locks on"): every area after Mossy Glade, its egg and
  Endless wait on the boss before them. Specs that assumed the playtest's open lobby now hold both
  states.

No other bug was found. Not bugs: the Drowned Village gives no free egg (it has no egg yet);
Thornwood's crate gave nothing until its weapons were in (stocked 2026-11-27), so prize crates fell back
to Mossy Glade's; hard levels open in order (1-1 on hard first).

## Only the owner can do

- [ ] **Two-player co-op test** on the published game (now possible: the friend needs access,
      public or friends on the Creator Dashboard).
- [ ] **Phone check** on a real phone (no session can emulate one).
- [x] **Import the fifteen Thornwood weapons** (done 2026-11-27 by Claude, uploaded through Open Cloud
      once the owner approved `Downloads`): Thornwood's store and crates sell them.
- [ ] **Rename the experience** ("Archer Legends [TEST]", universe 10772468005). Keep this universe:
      all ten Robux product and pass ids belong to it.
- [ ] **Maturity questionnaire**, and the store page's **icon, thumbnails and trailer**. Icon and
      thumbnail pictures to pick from are ready: `docs/STORE-PAGE.md`, `assets/store/contact-sheet.jpg`.
- [ ] **Notifications:** the six steps in `docs/NOTIFICATIONS.md` (built, switched off).
- [ ] **A real Robux purchase** of one product and one pass on the published game (only Studio test
      purchases and debug receipts have been made).
- [x] **Save the place from the open Studio before the next publish.** Done 2026-11-26: Claude published version 1166 from the clean Studio, which saves it too. Studio was closed during this
      check and its saved version kept the run bot. The open Studio is clean (exactly main), and the
      published game was published before the bot went back in.
- [ ] Decide the **balance questions** below.

## Questions for the owner (design or balance)

Would-be deaths below are from the stand-still bot (one run a level, random cards, so read about
3 either way as noise; Studio at 60 fps; P1 gear on 1-3 and 1-4, P2 from 1-5; the Assassin dashes
whenever its dash is back and an enemy is near). Raw runs in the shared notes,
`soften-1-4-bot-runs.md`.

- ~~**1-4 is a cliff** for every class, standing still: 5 to 20 would-be deaths against 0 to 3 in
  1-3 (the `hitGrace` breath stops after 1-3). Soften 1-4 and 1-5?~~ **Answered 2026-11-27, "Soften
  1-4 and 1-5": done.** The breath after a hit now runs on through 1-4 (0.6 s, as 1-1 to 1-3) and
  1-5 (0.5 s), and stops at 1-6 (`Balance.Stages`, held by `MossyLevels.spec`). No waves were
  thinned: the breath alone was enough. 1-3, 1-4, 1-5, 1-6, before → after:

  | | Before | After |
  |---|---|---|
  | Ranger | 1, 13, 9, 0 | 1, 4, 0, 1 |
  | Arcanist | 8, 16, 4, 6 | 0, 4, 4, 4 |
  | Warden | 1, 4, 3, 3 | 2, 0, 1, 4 |
  | Assassin | 2, 14, 11, 8 | 2, 3, 2, 4 |

- ~~**The Assassin takes the most damage** of the four in melee: 9 to 17 would-be deaths a level
  from 1-4 on (the Warden's November numbers were 0 to 7). Leave it, or more health or a longer
  dash guard?~~ **Answered 2026-11-27, "Longer dash guard": done.** After the Shadow Dash lands
  nothing can hurt the Assassin for 1.1 s (it was 0.2 s; `Config/Classes`, the Assassin only; its
  health is unchanged). `DashCut.spec` now holds the dash's safe time under half its 2.5 s wait (it
  was a quarter). A 0.75 s guard was tried first: 5, 7, 11, 8, 13 on 1-6 to 1-10, still twice the
  Warden. The Assassin, 1-4 to 1-10: before 14, 11, 8, 9, 12, 12, 19; after 3, 2, 4, 6, 5, 5, 8,
  against the Warden's 0 to 7.
- **Season 1 starts 2026-12-01**: a launch in November shows "NO SEASON RIGHT NOW" until then.

## Still unchecked

- The hatchery's and blacksmith's new rounding line on screen (the station would not open by probe;
  its place comes from the card's layout arithmetic and the specs pin the numbers).
- Phone sizes of the ODDS panel and button.
- Live servers: DataStore saves across sessions, MessagingService live events in a second server,
  the weekly tournament's reset, a real friend's invite, a real Premium player.
- The Warden's Mossy Glade 1-3 to 1-10 on this main (lost when Studio closed; the November run
  played it in full). Bogheart on this main with the locks on (only the Ranger's 4-1, locks off).
