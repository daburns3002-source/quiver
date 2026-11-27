# Autopilot for bug hunts (Studio only)

Plays the tutorial, Mossy Glade 1-1..1-10, Thornwood and Endless through the real
screens and remotes, and writes anything suspicious to `ReplicatedStorage.BotLog`
(client) and `BotServerLog` (server). It finds errors, soft-locks, unreachable gates,
enemies leaving the room, refused portals and end screens that do not leave. It does
not judge how anything looks, so sample captures while it runs.

None of this ships. To run it, in Edit, before Play:

1. Put `AutoPlay.client.luau` in a LocalScript under `StarterPlayer.StarterPlayerScripts`,
   and `AutoPlayServer.server.luau` in a Script under `ServerScriptService`. Scripts made
   at Edit time run in Play and share the game's `require` cache, which `execute_luau`
   never does.
2. Add these hooks to the `.Source` of the screens, before each file's final `return`
   (`docs/FIXES.md` explains why a probe cannot clear them otherwise):
   - `UI/Cards/DraftScreen`: `function DraftScreen.__bot() if shown and not locked and #slots > 0 then pick(math.random(#slots)) confirm() return true end return false end`
   - `UI/EndScreen`: `function EndScreen.__bot() if onRestart then onRestart() end end`
   - `Input/MoveController`: in its update, replace `humanoid:Move(desiredDirection(), false)` with `humanoid:Move(MoveController.__heading or desiredDirection(), false)`. A probe's `Humanoid:Move` does not survive that line.
   - `UI/EndlessCheckpoint`: inside `start`, after `pick` is defined, `EndlessCheckpoint.__bot = pick`.
   - `UI/NewEnemyScreen`: `function NewEnemyScreen.__bot() if queue[1] and not leavingAt and os.clock() - shownAt > NewEnemies.ready then gotIt() return true end return false end`
3. Set `SkipIntro` on Workspace for a run with no intro. `BotMortal` lets the player die,
   and `BotEndlessFloors` caps Endless (12 by default).

Remove the two scripts afterwards. The next Rojo sync of the three screens removes the hooks.
