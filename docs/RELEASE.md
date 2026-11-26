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
    (King Bloblin beaten); its level-3 crate was Mossy Glade's (Thornwood's has no staffs until the import).
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
Thornwood's crate gives nothing until its weapons are imported, so prize crates fall back to Mossy
Glade's; hard levels open in order (1-1 on hard first).

## Only the owner can do

- [ ] **Two-player co-op test** on the published game (now possible: the friend needs access,
      public or friends on the Creator Dashboard).
- [ ] **Phone check** on a real phone (no session can emulate one).
- [ ] **Import the fifteen Thornwood weapons** (`Downloads\thornwood_weapons_import`); until then
      Thornwood's store and crates sell nothing.
- [ ] **Rename the experience** ("Archer Legends [TEST]", universe 10772468005). Keep this universe:
      all ten Robux product and pass ids belong to it.
- [ ] **Maturity questionnaire**, and the store page's **icon, thumbnails and trailer**.
- [ ] **Notifications:** the six steps in `docs/NOTIFICATIONS.md` (built, switched off).
- [ ] **A real Robux purchase** of one product and one pass on the published game (only Studio test
      purchases and debug receipts have been made).
- [x] **Save the place from the open Studio before the next publish.** Done 2026-11-26: Claude published version 1166 from the clean Studio, which saves it too. Studio was closed during this
      check and its saved version kept the run bot. The open Studio is clean (exactly main), and the
      published game was published before the bot went back in.
- [ ] Decide the **balance questions** below.

## Questions for the owner (design or balance, not changed)

- **1-4 is a cliff** for every class, standing still: 5 to 20 would-be deaths against 0 to 3 in 1-3
  (the `hitGrace` breath stops after 1-3). Soften 1-4 and 1-5?
- **The Assassin takes the most damage** of the four in melee: 9 to 17 would-be deaths a level
  from 1-4 on (the Warden's November numbers were 0 to 7). Leave it, or more health or a longer
  dash guard?
- **Season 1 starts 2026-12-01**: a launch in November shows "NO SEASON RIGHT NOW" until then.

## Still unchecked

- The hatchery's and blacksmith's new rounding line on screen (the station would not open by probe;
  its place comes from the card's layout arithmetic and the specs pin the numbers).
- Phone sizes of the ODDS panel and button.
- Live servers: DataStore saves across sessions, MessagingService live events in a second server,
  the weekly tournament's reset, a real friend's invite, a real Premium player.
- The Warden's Mossy Glade 1-3 to 1-10 on this main (lost when Studio closed; the November run
  played it in full). Bogheart on this main with the locks on (only the Ranger's 4-1, locks off).
