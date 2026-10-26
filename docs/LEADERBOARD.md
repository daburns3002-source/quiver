# The FARTHEST ADVENTURERS leaderboard

Owner, 2026-10-25: "add a leaderboard for farthest story completion". The board
stands in the lobby (`assets/concepts/blocky/lobby/lobby_v3.png`): ten rows of
rank, name, area and room, e.g. `1. PlayerOne  Thornwood  12/20`, gold, silver
and bronze for the top three.

## The score

`src/shared/Util/StoryProgress.luau`, pinned by `tests/StoryProgress.spec.luau`.

A player's score is one whole number: every room of the stages before this one
in `Balance.campaign`, plus the rooms cleared in this one. With the campaign as
it is (`{ 5, 4 }`: the Mossy Glade run's 20 rooms, then Thornwood's 20), 7 is
Mossy Glade 7/20, 20 is Mossy Glade 20/20, 32 is Thornwood 12/20 and 40 is the
whole story. `StoryProgress.describe` turns a score back into that area and
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
| Name | `FarthestStory_v1` (`Config/Leaderboard.storeName`) |
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
of `face` (sized by `Leaderboard.pixelsPerStud`, `Enum.Font.Arcade`), with
`Leaderboard.rows` rows, and redraws it whenever the top changes. `areaNames`
maps a stage index to its area's name, e.g. `{ [5] = "Mossy Glade",
[4] = "Thornwood" }`. The board's title, FARTHEST ADVENTURERS, is the frame's,
not the SurfaceGui's.
