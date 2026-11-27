# The FARTHEST ADVENTURERS leaderboard

Owner, 2026-10-25: "add a leaderboard for farthest story completion". The board
stands in the lobby (`assets/concepts/blocky/lobby/lobby_v3.png`): ten rows of
rank, name, area and room, e.g. `1. PlayerOne  Thornwood  12/20`, gold, silver
and bronze for the top three.

## The score

`src/shared/Util/StoryProgress.luau`, pinned by `tests/StoryProgress.spec.luau`.

A player's score is one whole number: every room of the stages before this one
in `Balance.campaign`, plus the rooms (or waves) cleared in this one. With the
campaign as it is since 2026-10-26 (`{ 7, ..., 16, 4 }`: Mossy Glade 1-1..1-10,
10 + 10 + 15 + 15 rooms then 20, 20, 20, 20, 20 and 25 waves, 175 in all, then
Thornwood's 20 rooms), 7 is Mossy Glade 1-1 7/10, 50 is Mossy Glade 1-4 15/15,
187 is Thornwood 12/20 and 195 is the whole story. The board names each glade
level (`Mossy Glade 1-3`). `StoryProgress.describe` turns a score back into that area and
room; the area names are passed in by whoever draws the board.

The server records a score (`Run/RoomController`, `recordStory`) when a room is
cleared and when a stage is won, for every player in the run. Nothing a client
sends reaches it (non-negotiable 2). The sandbox records nothing, and neither
does a Studio run started part-way through (`Sandbox.startRoom`, the debug room
jump). A stage outside the campaign has no score.

## The store

| | |
|---|---|
| Kind | `OrderedDataStore` |
| Name | `FarthestStory_v2` (`Config/Leaderboard.storeName`; `_v1` was the 40-room campaign before Mossy Glade's ten levels, left as it was) |
| Key | `tostring(userId)` |
| Value | the player's best score, a whole number |

Written by `src/server/Run/StoryLeaderboard.luau` with `UpdateAsync`, keeping
the larger of the stored value and the new one, and writing nothing when the
stored one is already as large. A score never goes down (non-negotiable 7).

**No session lock is needed**, because the only change ever made to a value is
`max`. It gives the same result in any order and however often it is repeated,
and `UpdateAsync` applies it to the value actually stored, so two servers
writing the same player can only both raise it. The key holds nothing else.

**Versioning.** The `_v1` is the score's meaning: rooms counted along this
campaign. If that meaning changes (an area inserted before Thornwood, rooms
added to a stage already played), the board moves to a new name (`_v2`) and
starts fresh, or a migration reads `_v1` and writes `_v2`. A `_v1` value is
never rewritten in place to mean something else.

**Budget.** Each player's best is kept in memory and marked dirty when it
improves; it is written at most every 30 s per player
(`Leaderboard.flushEvery`), when they leave, and as the server closes
(`BindToClose`, which waits up to `Leaderboard.closeWait` for writes under way).
The top ten are read every 60 s (`Leaderboard.refreshEvery`) with
`GetSortedAsync`; names come from `Players:GetNameFromUserIdAsync`, cached.

**The YOU row** (2026-11-11). Under the ten rows of each board is an eleventh,
"YOU: #N" with the player's own best. The same read now asks for
`Leaderboard.rankDepth` (100) entries, still one page and one call, and names
are looked up only for the ten drawn. `Util/BoardRank` places each player in
that list with this server's bests folded in; a best under the last entry of a
full read is "#100+", never a made-up place. A board is one SurfaceGui for
everyone, so `Run/BoardYou` builds the row empty (tag `BoardYou`) and
publishes each player's two texts as attributes on their Player
(`StoryYouRank`, `StoryYouBest`, `EndlessYouRank`, `EndlessYouBest`), and each
client writes its own into the row (`UI/BoardYou`). `tests/BoardRank.spec`.

**Failure.** Every DataStore call is in a `pcall`. In Studio without API access,
or when a call fails, the board shows what this server knows (the last top it
read, with its own players' bests folded in), and that is logged once. Studio
never writes the store unless `Leaderboard.writeFromStudio` is set, because a
playtest's debug keys make runs that are not real.

## Not the player save

This store is not the player's save and must not become it. The save that
Phase 5 brings (area unlocks, pets, coins, gear: `docs/ROADMAP.md`) is its own
`DataStore` with session locking, a schema version and migrations. When it
lands, it may also keep the furthest point reached, but the leaderboard stays
this separate ordered store, written only by the max rule above.

## Drawing it

`StoryLeaderboard.attach(face, areaNames)` builds a `SurfaceGui` on the front
of `face` (sized by `Leaderboard.pixelsPerStud`, `Enum.Font.FredokaOne`), with
`Leaderboard.rows` rows, and redraws it whenever the top changes. `areaNames`
maps a stage index to its area's name, e.g. `{ [7] = "Mossy Glade 1-1",
[4] = "Thornwood" }` (an area of several levels names the level too). The board's title, FARTHEST ADVENTURERS, is the frame's,
not the SurfaceGui's.

## THIS WEEK'S DELVERS: the weekly Endless tournament

Owner, 2026-11-18 ("yes all of these create them"): a weekly board of each
player's best Endless floor, with prizes when the week ends. Rules in
`Util/TournamentRules` (pure, `tests/TournamentRules.spec` drives a week and
its rollover with a fake clock), numbers in `Config/Tournament`, the store
and the board in `Run/WeeklyTournament`, the prize panel in
`UI/TournamentPrize`.

**The week** runs from Monday 00:00 UTC to the next Monday. Weeks are
numbered from 1970-01-05 (the first Monday of Unix time) and named by their
Monday's date ("2026-11-16"). The week rolls over by itself: the board
empties and its countdown starts again.

**The board** stands past DEEPEST DELVERS on the same side
(`Config/Lobby.weeklyLeaderboard`, the same stone build): a heading,
THIS WEEK'S DELVERS, with "RESETS IN 2D 4H" beside it (hours and minutes
under a day, minutes under an hour), the top ten with rank, name, floor and
time, and the YOU row (`WeeklyYouRank`, `WeeklyYouBest`, `Run/BoardYou`).

**The store**

| | |
|---|---|
| Kind | `OrderedDataStore` |
| Name | `EndlessWeekly_v1` (`Config/Tournament.storeName`) |
| Scope | the week's Monday, `"2026-11-16"`: every week its own board, an old one never rewritten |
| Key | `tostring(userId)` |
| Value | `TournamentRules.score`: the floor times 1,000,000, plus 999,999 less the tenths of a second the run took to clear it |

**Ties.** A deeper floor always wins. On the same floor the faster run
wins: the time is the server's, from the run's start
(`session.stageStartedAt`) to the floor being cleared, so it can no more be
claimed than the floor. Two runs level to the tenth of a second share the
better place, on the board and for the prize, so a tie never costs one.

**Write cost.** As the boards above: a best is marked for writing only when
it improves (a deeper floor, or the same floor faster), at most every
`Leaderboard.flushEvery` (30 s) per player, when they leave and as the server
closes, and `UpdateAsync` writes nothing when the stored value is already as
good. The top is read every 60 s. A player's own best this week comes from
their save on join, so joining costs no read of this store.

**Prizes** (`Config/Tournament.places` and `.bands`; the owner's yes,
2026-11-18, "YES BUILD IT", with the themed set weapons added; starting
numbers):

| Place | Prize |
|---|---|
| 1 | 300 gems, 1,000 Soulstones, the ENDLESS CHAMPION title, and **two** themed set weapons of the player's choice |
| 2-10 | 150 gems, 500 Soulstones, and **one** themed set weapon of the player's choice |
| 11-100 | 60 gems, 250 Soulstones |

and, on top, for everyone who played that week, by the deepest floor:

| Floor | Prize |
|---|---|
| 1-9 | 50 Soulstones |
| 10-19 | 100 Soulstones, 1,000 coins |
| 20-29 | 200 Soulstones, 2,500 coins |
| 30-49 | 300 Soulstones, 10 gems |
| 50+ | 500 Soulstones, 25 gems |

**The set weapon picks.** "Skins" in the owner's words are the themed sets'
weapons (`docs/WEAPONS-THEMED.md`, `Config/Shop.sets`): one Legendary a
class in each set. A pick is **any one of them the player does not own, of
any set and any class**, but never a reward weapon (`WeaponStats.earned`:
the Nebula Blade, the Petalfall Blade and the Wishcutter Blade are Endless
room 100's and the season pass's; owner, 2026-11-19, "yes, close it"). On
the panel those three keep their place in their set's row, captioned
REWARD and not pressable, and a tap names where they are earned. A pick is
chosen on the prize panel (PICK!, then TAKE IT)
and granted by the server (`Remotes.TournamentPick`,
`Wallet.pickTournamentWeapon`, which refuses anything owned, not a set's,
or with no pick owed). Every stocked set counts, whether or not its shelf
is on sale that week. A pick with nothing left to take (the player owns
every set weapon) is paid as `Tournament.pickGems` (300) gems, when the
week pays and again on any later join. Picks not taken are kept in the save
(`tournamentPicks`) and offered again on the next join.

Coins, gems, Soulstones and weapons the player chooses: no eggs or crates
and nothing rolled, so nothing here is a random item and the
paid-random-items rule does not touch it. A week's Soulstones are not under
the run cap.

**Paid once, on the next join.** Each week a player sets a best in is
noted in their save (version 26, `tournamentWeeks`: week number to that
week's best score, at most `Tournament.keep` of them; `tournamentWins`;
`tournamentPicks`). Once the week is over
and `Tournament.grace` (300 s) has passed, so the week's last writes from
other servers are in, the server reads that week's top 100 once, places the
player (their save's best counts even if the store never heard of it), and
pays and takes the week out of the save in one step with nothing yielding
between (`Wallet.payTournament`), so a week pays once. A player in the game
as the week ends is paid there, within seconds of the grace. If the store
cannot be read, the week waits and is tried again every 60 s; it is never
paid a guessed place. Past the top 100 a player has no place and gets their
floor's band alone.

**The title.** A week's winner gets ENDLESS CHAMPION over their name tag for
good (`UI/NameTags`, gold), "x2", "x3" with more wins (`tournamentWins`,
published as the Player's `TournamentWins`). A title rather than a trail:
every trail is a Claude Design build.

**Studio** never writes the store (`Leaderboard.writeFromStudio`); without
API access it places from what it knows. `Remotes.DebugTournament` (Studio
only): `("shift", s)` moves the tournament's clock on (with no seconds, to
just past the next reset and its grace), `("floor", f, s)` records a floor
as a run would, `("rival", n)` puts n made-up players on this week's board.

**Seen in Studio 2026-11-19** (desktop size, by probe): the board past
DEEPEST DELVERS with twelve made-up players and a real floor (rank, name,
floor and time, bronze on third, YOU: #6, RESETS IN 3D 16H); the clock moved
past the reset and its grace: the board emptied, and the week paid #6 at
floor 34 (+160 gems, +800 Soulstones, one pick) and, a week later, #1 at
floor 64 (+325 gems, +1,500 Soulstones, two picks, ENDLESS CHAMPION over the
name tag); PICK! opened the eight sets, a click and TAKE IT granted the
Wishbright Bow, the panel closed and the week was gone from the save. A pick
of an owned set weapon and of an area's weapon were both refused. On the
tree rebased on main (hard mode's name-tag frame in), the title sits over
the name's row and the in-Roblox tests pass, 1,285. **Not
seen:** a phone, a real Endless run feeding the board (the floor was
recorded by the debug remote; `RoomController` calls the same `record`), the
live store (Studio has no DataStores), and two servers writing one week.
