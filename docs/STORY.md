# Story — the bog is rising

Owner, 2026-11-13: "ok now we gotta change the areas to actually progress as a
story." The outline below was put to the owner and approved the same day, with
two picks: the areas stay open while the game is in playtest (the story plays
in order; `Config/Launch.locks` already opens them in order at launch), and
each beat is **Codex stills with motion** (no new music upload).

## The thread

Deep under Bogheart Caverns, Grandmother Gulp has woken up hungry. Every gulp
swells the bog. It already drowned a village, and everything that lived down
low is being pushed uphill. The heroes start at the top and follow the trouble
down to where it starts. Each boss leaves a new WANTED poster for the next one,
as the opening's poster was for King Bloblin.

| # | Area | Boss | Why it is there | Beaten: what it uncovers | Next poster |
|---|---|---|---|---|---|
| 1 | Mossy Glade | King Bloblin | Slimes crawled up out of the wet; the biggest grabbed a crown (the opening cutscene stays as it is) | His chest holds no gold, just bog water and Royal Jelly, and a slime trail into the Thornwood | THE BROODMOTHER |
| 2 | Thornwood | The Broodmother | Spiders don't belong here: she fled the rising water and webbed the wood shut | Her web falls; a road runs downhill to a village under water | OLD TOLLCRAB |
| 3 | Drowned Village | Old Tollcrab | The village went under one night; the crab moved into the sunken church bell, and every toll wakes the drowned | One last clear toll; the water drains into a glowing cave under the church... GULP | GRANDMOTHER GULP |
| 4 | Bogheart Caverns | Grandmother Gulp | The source: a giant toad swelling the bog with every gulp | She spits out the Bogheart Pearl; the bog sinks and the village dries out; then the wind turns | THE TEMPEST ROC (to be continued) |

The two boss items were named by the story: Toll Bronze is the **BELL SHARD**
(a piece of the Tollcrab's bell) and Bog Pearl the **BOGHEART PEARL** (the
heart of the bog, in Gulp's belly). Their keys stay `TollBronze` and
`BogPearl`, because saves hold them.

## How it plays

A **beat** is four stills: what the boss's defeat uncovered, the last the next
WANTED poster with a line on why that boss is there. It plays once, the first
time the boss is beaten (or, for a save that beat it before this, the next
time), when the player leaves Victory: then NEXT, RETRY or LOBBY goes on under
the black at its end. Each still pans and zooms slowly with its words on a
panel under it; a tap (click, A, Return, Space) moves on after 0.8 s, SKIP (or
B, Escape) ends it. About 14 s a beat.

- `Config/StoryBeats` — the words, holds, moves and sounds of each still, the
  uploaded halves.
- `Util/StoryBeatRules` — which beat is owed, where a still sits in its window
  (pure; `tests/StoryBeatRules.spec`).
- `UI/StoryBeat` — draws it; `Client/Main` plays it as Victory is left.
- `Run/RoomController` — the summary's `story`, the area whose beat a win
  owes; `Remotes.StorySeen` and `Wallet.sawStory` write it down
  (`SaveSchema` version 12, `storySeen`).
- Art: `assets/concepts/blocky/ui/story/beats.py` (Codex, from the opening's
  frames, the boss icons and the arena sheets), `assets/ui/story/cut_beats.py`
  (the 16:9 bands kept in `assets/ui/story/beats/`, two halves each uploaded).

## Not done

- Acts 3 to 5 are not built; the Tempest Roc's poster ends the story for now.
- No place outside the beats says the story yet (the portal screen, the Dex).
