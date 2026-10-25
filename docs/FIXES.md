# Fixes

A running log of bugs that actually shipped, newest first.

Entries are written to be found by **symptom**, because that is what you have
when one recurs — usually a sentence from a playtest, not a stack trace. Each
one names what the player saw, what was actually wrong, what was done, and the
measurement that showed it worked. A fix without a number in it is a claim.

Two things make this worth keeping. The same classes of bug recur here:
projectile hit detection has broken three separate times, enemy steering
twice. And **every single one of these was green on all four CI gates** —
Selene, StyLua, `rojo build` and `luau-lsp` — because they were geometry or
state, which no type and no lint can see. If a symptom below shows up again,
start from the cause recorded here rather than from the code.

---

## Chain Lightning's animation never played (the Arcanist's chained orbs looked like arrows)

**Symptom**: 2026-10-25, the owner's Arcanist run-through: "chain lightning animation is not playing". The chain did its damage, but no zig-zag bolt, no spiked node and no crackle sound ever showed. The orb that jumped on was drawn as a plain player arrow.

**Cause**: two.
- The onward shot never said whose class it was. The server's chain and ricochet shots (`ProjectileSystem.fireOnward`) were announced with no `look`, so the client drew them in the `Player` (arrow) pool, not `PlayerOrb`. `ArcanistFx` only plays the bolt for a `PlayerOrb` that was chained, so it bailed out on every chain. The damage was never affected: the server's projectile is the same either way.
- Even with the look, the bolt went to the wrong enemy. `ArcanistFx` picked the nearest enemy ahead of the hit point without skipping the body the chain leaves. The orb meets an enemy at its near edge, so the enemy just hit was usually that nearest one. The bolt was then 3 to 4 studs long and ended at that enemy's own centre, hidden inside its body.

**Fix**:
- The projectile carries its class `look`. `FiringSystem` sets it, and `fireOnward` passes it on to the onward projectile and its `ShotFired` event, so a chained orb is drawn as an orb.
- `FxEvents.launched` now carries the body the shot leaves (`from: Model?`) in place of a `chained` boolean.
- The bolt runs from that body's centre to the enemy most nearly along the chain's aim (`chainTarget`). The server aims the chain straight at its target, so that is the one it jumps to. The cosine to beat is `Balance.UpgradeFx.boltAimed`, and the reach is the ricochet's plus `boltReachSlack`.

**Measured**: Studio, Arcanist with Chain Lightning 2, sandbox dummies plus Melee Chargers. Before: 4 of 4 onward shots arrived with no look and were drawn as arrows. With the look fixed but not the target, bolts were 2.7 to 3.6 studs long, ending on the hit enemy's own centre. After: 13 of 13 chained orbs drew a bolt, 3.4 to 14.7 studs long, each starting 0.00 studs from the hit enemy's centre and ending 0.00 from another enemy's centre (a probe inside `ArcanistFx`). A capture shows the bolt between two enemies.

**Watch for**: a shot the server invents (chain, ricochet, anything new through `fireOnward`) has to carry everything the client draws it by. The client's own volleys get `look` from `LocalFiring`, so this only shows on server-invented shots.

## A model's lit or flash pieces came out as `nan`, or the converter crashed

**Symptom**: 2026-10-24, bringing the 44 upgrade-effect GLBs in. `imports_to_luau.py` stopped at `FxMomentum` with `numpy.linalg.LinAlgError: Singular matrix`. Once past that, Selene reported 152 errors, all `` `nan` is not defined ``, in the generated `Config/ModelClips/FxMomentum`, `FxPrecision` and `FxStrength`. Every one was a part's rest `cframe` with a valid position and four `nan`s for its rotation: `Seg_00_Lit`, `Ring_Lit_Seg01`, `ArmBandLeft_GripFlash`. In game, a NaN rotation is a part that never appears.

**Cause**: those pieces rest at **zero scale** — the lit and flash states of an effect, shrunk to nothing until a clip grows them. Both tools recover a node's turn by dividing its world matrix by its axis lengths, and with a zero length that is a division by zero. It happened in three places: `glb_clips_to_luau.local_trs` (a node given as a matrix), the part rest pose in `glb_clips_to_luau.convert`, and the rigged-import turn in `imports_to_luau.primitives` (`np.linalg.inv` of a singular matrix). Pets and King Bloblin never hit it: nothing of theirs rests at zero scale, so a fallback taken only in that case cannot change them.

**Fix**: each of the three now checks for a zero-length axis first. When it finds one, the turn comes from the surviving axes (`rebuilt_turn`, each missing axis the cross product of the next two) or from the chain of node rotations alone (`turn_of`, `turn_only`), which a zero scale cannot break. Otherwise the old code runs unchanged.

**Measured**: 0 `nan` across all 88 generated `Fx*` modules (was 152). All four gates clean. After StyLua, every existing `PetModels`, `ImportedModels` and `ModelClips` module was byte-identical to `main` (0 files changed), so the fallback touched nothing that worked before.

---

## King Bloblin stood frozen, or held his lash fist on the floor

**Symptom**: 2026-10-24, Studio playtest of room 10 after #197.
- Some jumps to the room left King Bloblin playing no clips at all. All 72 of his parts were still welded to his hitbox, and the client logged `ModelAnimator: SlimeKing's parts do not line up with KingBloblin (fit error 0.499)`.
- On jumps where he did animate, a lash that grabbed went from Strike straight to Pull, never Hold, which `BossClips.spec` failed on.

**Cause**:
- His skin is welded to his anchored hitbox, and on a client a welded part lags the hitbox the server moves by a frame. `ModelAnimator` fit his rest pose from where the parts stood. When he replicated mid-jump, his eyes (the parts the fit reads) sat half a stud off, and the fit was refused.
- The grab is not a bug: the server resolves it as the slap begins, so a hit has no Hold.

**Fix**:
- `EnemyModel` gives every imported part a `RestCFrame` attribute, its exact place on the hitbox. `ModelAnimator` fits and rests from that.
- The spec now expects Strike → Pull on a hit.

**Measured**:
- Before: 1 jump in about 4 left him unanimated (`#197` in Studio).
- With him animated: 3 bounces then Winded, both lashes (Wind, Strike, Hold, Retract on a miss; Pull, ChestBump, Recover on a grab), every clip switching on its beat.
- The fist landed 0.3 studs short of a 9.4-stud lane, 0.2 off its centre line, 2.9 to 4.2 studs across, with all 24 link parts out. In the probe from the clip data, it landed at 5.5 to 6.0 on a 6-stud lane and 17.0 on an 18-stud lane.
- The `RestCFrame` fix (#198) is not yet seen in Studio, because the synced checkout is on another branch.

## Preview pets walked backwards

**Symptom** — 2026-10-23, Studio playtest of **P**: walking +X, every pet's
look vector pointed −X (−0.85 to −1.00 across the twelve).

**Cause** — `Fx/PetPreview` turned each pet half round more, assuming the
GLB's +Z front. `Config/PetModels` is written in the import's frame, where
the front is already the pivot's look vector (−Z).

**Fix** — no extra turn: `CFrame.lookAt` alone.

**Measured** — see the PR: walking +X, look vectors along +X.

## The pet preview showed two pets out of twelve

**Symptom** — 2026-10-23, first P press in a Studio playtest: the Slime
Prince and two thirds of the Mossback Snail followed the player; the server
logged "built 12 preview pets".

**Cause** — the client copied `ReplicatedStorage.PetPreview` as soon as
`WaitForChild` saw the folder. Twelve models of 1,000 parts replicate over
several frames, and the folder arrives before its contents.

**Fix** — the server stamps the folder with `Pets` and each model with
`Parts`; `Fx/PetPreview` waits (up to 20 s) until it holds them all.

**Measured** — a moment later the client held all 12, every part count
matching the server's (Glimmerhorn 262, Mossback Snail 137).

## Imported pets were grey, with flat leaves and mixed-up legs

**Symptom** — 2026-10-23, the owner's import of the twelve forest pets:
every part grey; the Mosslet's sprout leaves lying flat; Stumpy's four legs
all named `Leg_L_front`. The pet preview built from that dump would have
shown grey pets in the wrong pose, and the animator, which binds parts by
name, would have moved one leg four times or refused the model.

**Cause** — what Roblox's importer does to a Claude Design GLB: it drops
material colours; it names a mesh that several nodes share after the first
of them; and for a GLB with joint nodes it places each mesh as if no node
were turned (the turns go to its InitialPoses and Motor6Ds). The clip fit
also read the import's scale from part sizes, which a baked import reports
turned: the Fern Frog read 1.197 for a true 1.

**Fix** — `tools/imports_to_luau.py` trusts Studio only for mesh ids. It
matches each import to its GLB by part names and each part to its primitive
by place and size, then takes node names, colours and rest turns from the
GLB. `ModelClip.fit` reads scale from how far the parts spread;
`ModelAnimator` drives every part of a node.

**Measured** — all twelve pets matched to their GLBs within 0.001 studs.
Fitted against their clip data in Lune, every one came out at scale 1.000
(Hootmoss 0.999), turned half round, with error under 0.3% of its spread
(the Mosslet was 12% before multi-part names were left out of the fit).

## King Bloblin turned all white in a fight

**Symptom** — owner, 2026-10-24: "the king is all white". On the client, 60
of his 72 parts read pure white (1, 1, 1), his eyes alone amber; the server
had every colour right.

**Cause** — the hit flash (`Fx/HitFeedback`) paints a hit enemy white and
puts back the colour it saw when that flash began. A hit landing inside an
earlier flash saw the white and put that back. Enemies that die in a few
hits hid it, and the old round king was white by design (vertex colours);
the blocky King, hit faster than his flash lasts, stayed white.

**Fix** — each part's colour is kept from its first flash and put back
only when the last overlapping flash ends. A boss also skips the white-out
altogether and gets only a faint white wash (`Balance.Feedback.bossHitFill`):
under steady fire the flash and its Highlight never faded, so even with his
colours restored he still read pale.

**Measured** — see the PR: room 10, his parts in their colours throughout
a fight.

## King Bloblin's lash chain never appeared

**Symptom** — owner, 2026-10-24: "the lash attack is unfinished". Through a
whole lash (Wind, Strike, Hold, Retract) all 24 chain parts stayed at a
thousandth of a stud and never moved; his body animated fine.

**Cause** — `Fx/ModelAnimator` gathered the parts it drives once, when the
model was tagged. His 72 parts reach a client over several frames, and the
chain arrived after the tag, so it was never driven: unanchored, at its
tucked-away rest size.

**Fix** — any part of an animated model that arrives later joins the
animation (`DescendantAdded`).

**Measured** — see the PR: the chain's parts grow and fly down the lane on
the strike.

## The pond's edge was jagged

**Symptom** — owner, 2026-10-23: "fix the shadows of the pond, it should be
circular." Round the oval of water ran a dark, stair-stepped band.

**Cause** — two low-poly edges showed round a smooth ellipse. The water
sheet sat at y 0.03, under the lawn's lip, which shaded it in steps. And the
lawn mesh paints a darker green ring round the basin in triangles, out to
about 1.15× the pond's size (measured from the mesh's vertex colours:
98, 155, 50 against a lawn of about 140, 165, 95).

**Fix** — `placeModel` raises the water to y 0.1, clear of the lip, and lays
two smooth ellipses under it: a dark rim 1.08× the water, and the bank, in
the ring's own green (`ArenaPart.bank`), at 1.18×, covering the stepped ring.

**Measured** — in Studio, room 2: the stepped band is gone, and the edge is
two smooth concentric ellipses.

## The player walked across the pond, the thorns and the logs

**Symptom** — owner, 2026-10-23: "the player should not be able to walk over
any obstacles, including the logs and the pond."

**Cause** — each piece of cover's collision box is its own height (the pond
0.4 studs, the thorns 0.4, a stump 1.5, the log 2.8), so the boxes stop
arrows at the right height. But a Roblox character steps up onto anything
that low and walks across the top.

**Fix** — `Arena.build` puts a second, invisible wall over every obstacle,
`wallHeight` tall, in its own `PlayerWalls` folder. It has `CanCollide` on
and `CanQuery` off: it stops the character, and no raycast, sweep or
`GetPartBoundsInBox` sees it, so arrows still fly over low cover. Enemies are
kept out of cover analytically and never touch it either.
`tests/Arena.spec.luau` pins all three properties.

**Measured** — in room 2, driven into the pond at walking speed for 2 s, the
player stopped at z = 1.64 against the pond's edge at 0.68 (one body
half-width). Driven into a 1.4-stud stump, the player stopped 1.06 studs short
at floor height (y 3.89).

---

## The Slime King looked nothing like his model

**Symptom** — owner, 2026-10-23: "the king slime model looks nothing like
what it should. did you use the models that were imported."

**Cause** — the boss shipped with primitive stand-in parts (green ellipsoids
and a gold cylinder crown) "until the owner imports" the meshes. The owner
had already imported them, as model `slime_king_roblox` (83216994830889),
into the inventory rather than the place. A search of the place's tree found
nothing, and the inventory was never checked.

**Fix** — `EnemyDesigns.SlimeKing` now uses the imported meshes (Body,
Decor, Eyes, Arm_L, Arm_R), read from `InsertService:LoadAsset` of that
model: sizes and offsets ×2, mirrored for the importer's 180° turn, all white
so the vertex colours show (the eyes too: they are painted dark with amber
glints, not a glowing act colour).

**Next time** — before saying a model is not imported, list the owner's
inventory: `search_asset` with `assetType = "Mesh"` or `"Model"`, `scope =
"user"` and an empty query. Imports land there under the GLB's part names.

## The Arcanist's shots drew a beam across the room

**Symptom** — in a Studio capture, each Arcanist shot showed as a tiny dot at
the head of a cyan line about 60 studs long, reading as a laser rather than a
bolt.

**Cause** — the Arcanist's orb took the enemy orbs' trail, whose length is
set in seconds (0.6 s) because enemy orbs are slow. The Arcanist's shot flies
at about 100 studs/s, so 0.6 s of tail is about 60 studs. Separately, a
`SpecialMesh` pointed at the imported bolt mesh drew nothing at all, so only
the trail and the light showed.

**Fix** — the Arcanist's tail is a length, like an arrow's
(`PLAYER_ORB_TRAIL_STUDS`, 6 studs, turned into a lifetime from the shot's
speed). The bolt is loaded once on the client with
`AssetService:CreateMeshPartAsync` and cloned per shot, the way the server
loads every other mesh.

**Measured** — the shot is a `MeshPart` in flight, and a game-view capture
shows a bolt with a short comet tail.

---

## Enemies got stuck on cover instead of going round it

**Symptom** — "make sure the ai for the enemies finds a way around an
obstacle, they are getting stuck".

**Cause** — the only steering was sliding along whichever face an enemy
bumped into (`Arena.deflectionNormal` plus a committed side). It held for a
lone pillar and failed wherever cover made a corner: a boulder against a
boulder, a pillar against a wall, the long edge of the pond. Big bodies had
a second problem: their square hitbox turns to face the player and is 1.41
times as wide on the diagonal, so a route sized to their straight width
caught on corners, and the old slide then fought the route.

**Fix** — `Enemies/Pathing`: a walkable grid per body size over each room,
from `Arena.isClear`, rebuilt when a room is built; A* with no corner
cutting; the route pulled tight to clear straight legs. An enemy that cannot
walk straight at its target follows the route (refreshed every 0.4 s),
planned first for its widest turn, then a tight fit, then flush; the slide
is off while it does.

**Measured** — the same enemy code stepped in a private world, every Level 1
room, enemies spawned across the floor chasing a player parked behind the
room's cover. Moss Slimes 28/165 → 165/165; Brood Slimes 45/63 → 63/63;
Bulwarks 6/36 → 34/36 (the two left squeeze its turned corners through a
gap barely its width, in rooms Bulwarks never spawn in). `Pathing.spec`
pins the planner against the real layouts.

---

## On a phone the skill bar was cut off at both sides and covered the health number

**Symptom** — "the upgrade bar is not fully visible".

**Cause** — two. The skill bar chose its tray by inputs (`TouchEnabled and
not MouseEnabled`), and Studio's phone emulator — like some phones —
reports a mouse too, so it built the ten-slot computer tray, 738 points
wide, on a 401-point screen. That is the same lie CLAUDE.md warns about:
detect a phone by screen size. And the HUD's ScreenGuis ignored every
inset, so on a real phone its bottom would run under the home bar.

**Fix** — the tray is the phone's six-slot one whenever `Device.isPhone()`;
the skill bar, health, dash bars and dash button use
`ScreenInsets.DeviceSafeInsets`. The phone layout is one centred stack, the
dash button lifted above it when the screen is too narrow.

**Measured** — emulator, upright 401 × 778: tray x 47–354 (was −132 to
533), health and dash directly above it, dash button above the stack.

---

## Playtests took about 10 seconds to start

**Symptom** — "why when i start the playtest it takes like 10 seconds to
load everything, will that happen in game". It would: every new server.

**Cause** — `EnemyModel.preload` and `Arena.preload` called
`CreateMeshPartAsync` one mesh at a time, and each call waits for its
download. Level 1 has 47 meshes (37 arena, 10 enemy), at about 0.2 s each,
all before the first room is built.

**Fix** — `Server/Util/MeshTemplates.load` starts every request at once and
waits for them together, so a batch costs about as much as its slowest mesh.

**Measured** — loading the 37 arena meshes in parallel took 0.53 s in a
probe; after the fix the first room was built 1.2 s after Play started.
Studio caches downloads, so a cold server will be somewhat slower, but no
longer 47 round trips in a row.

---

## The Spitter walked in silence, and its seeds never reached the player

**Symptom** — "make sure the spitter projectiles can reach the player and
that it fires from when it spawns".

**Cause** — one number doing two jobs. A ranged enemy's `attackRange` was
both the distance it holds and the distance it may fire from. The Spitter's
was 13.3, it spawned at least 21 studs from the player, and its seeds died
after 16 — so a fresh Spitter walked in before its first shot, and a player
who kept back was out of reach of everything it fired.

**Fix** — `EnemyShot.range`, the distance it may fire from, separate from
the distance it holds. The Spitter's is 70 and its seeds live 70 / 18 s, the
whole room corner to corner. Its attack timer already starts ready, so it
winds up the moment it lands. `Balance.spec` now holds every ranged enemy's
reach at or beyond the range it fires from.

**Measured** — live, Level 1 room 2: first wind-up 0.50 s after spawning,
at the instant it landed, from 27.4 studs; with the player in the far
corner, seeds flew up to 75.8 studs and passed within 2.4 of them.

---

## The pond was a dark hole with no water

**Symptom** — in Studio, the Mossy Pond room's pond drew as a dark hole
ringed by its stones.

**Cause** — the model's water is one flat sheet with no thickness (0.001
studs as imported). Roblox drew nothing for it. Placed at its own depth it
would also have sat under the pond's dark basin.

**Fix** — a part flagged `water` in `ArenaModels` is drawn as a flattened
sphere mesh (a cylinder mesh stays round whatever its size) of the water's
size and place, in the model's teal, flush with the lawn.

**Measured** — capture: the pond is filled to its ring of stones.

---

## Grey space past the arena, and the grass outside the walls read grey

**Symptom** — "make sure the camera cant see any gray space", then "i need
the grass on the outside and to match".

**Cause** — three, stacked. The glade model is 81 studs wide and a desktop
screen sees about 124, so the void showed past both sides. The place's
default `Atmosphere` haze is grey (199, 199, 199 at density 0.3), and
nothing in code set it. And the glade's ground — one mesh, bright lawn
inside and dark grass (53, 88, 41) outside — rendered its outside pale
grey-green as SmoothPlastic. Turning the haze off and the environment
reflection off (`EnvironmentSpecularScale = 0`) both left it pale; only the
material mattered.

**Fix** — the glade's trees, bushes and grass are drawn again 81 studs to
either side over a matte forest floor (`ArenaModels.surround`); the haze is
set from `Balance.Lighting`, forest green; the ground is drawn matte
(`ArenaPart.matte`, Fabric), which keeps the lawn its own bright green.

**Measured** — Studio captures at spawn on all five glades: forest and dark
grass to both screen edges, lawn bright. Hiding the ground mesh alone showed
the pale band was the ground, not the floor plane under it.

**Watch for** — a Studio window in the background drops its render quality
and its shadows, which washes out ground colours and looks like this bug.
Restart Play before judging colour from a capture.

---

## The boss arena's walls stood outside the room

**Symptom** — in Studio, the boss glade's lawn was a third wider than every
other room's, and its walls were 5 studs past where the player was stopped.

**Cause** — the Claude Design boss arena draws its walls bigger (18.5 × 25.5
before scaling, against 14.5 × 22.5), and every glade was scaled ×2.7.

**Fix** — each glade is scaled so its walls land on the log glade's
footprint, which is the room's: ×2.70 for four of them, ×2.11 across and
×2.38 deep for the boss. Its pillar cover moved with it, and since squeezing
narrowed its own forest into gaps, it borrows the log glade's beside it
(`surroundFrom`).

**Measured** — capture with cover boxes shown: boss walls on the room's
edges, all four pillars inside their boxes, forest to both edges.

---

## A picked skill flew to the middle of the bar, and too high

**Symptom** — "when the animation plays for the upgrade to the upgrade bar
make sure it goes into the next open slot, not just the middle of the bar".

**Cause** — two. A skill not yet held has no slot, so `SkillBar.slotPosition`
fell back to the tray's centre. And the celebration overlay placed things at
raw screen positions (`AbsolutePosition`), but the overlay itself starts
above the GUI inset — its own AbsolutePosition is (0, −58) on a Studio
desktop — so the icon, rays and flash were all drawn 58 px too high.

**Fix** — a new skill aims at the first open slot (the one it will take), a
held one at its own slot, both at the icon disc rather than the slot's
middle; and `stepOverlay` subtracts the overlay's AbsolutePosition from
every screen position it places.

**Measured** — the icon's last frame at (841, 863) against the open slot's
disc at (842, 865); before, (1166, …) for the bar's centre and 58 px high.

---

## Phone layout flipped back to the computer one mid-run

**Symptom** — in Studio's phone emulator the HUD came up in its phone
layout, then a draft opened at the computer's size and the health bar
jumped back to the bottom centre.

**Cause** — "is this a phone" read the input flags: touch and no mouse,
then touch and no keyboard. The emulator reports touch only at first, then
mouse *and* keyboard as soon as the Studio window has focus, so the answer
changed under a running game.

**Fix** — `Device.isPhone` is a touch screen whose short side is under 600
points (`CameraFit.isPhone`): the screen's size, which the emulator and a
real phone agree on.

**Measured** — in the emulator at 401 × 778, the phone layout held through
a whole draft: health 300 × 30, skill bar 307 × 77, cards 82 × 202 against
67 × 165 before.

---

## Player killed again behind the end screen

**Symptom** — the server log read "died" twice for one death, the second
while the Defeat screen was up.

**Cause** — the end screen made the run wait for its button instead of
restarting after 2.5 s. Roblox respawns a character after 5 s, binding it
at full health, and the arena behind the screen was still running: enemies
walked over and killed the new character, again and again for as long as
the screen stayed up. The old timer had always beaten the respawn.

**Fix** — `RoomController.isOver()`, and the server's Heartbeat holds the
world still while it is true, exactly as it does behind a card screen.

**Measured** — walking into enemies for 8 s behind the Defeat screen: one
"died" in the log, then a clean restart on TRY AGAIN.

---

## End screen rays spilled out past the panel

**Symptom** — the Victory screen's sun rays carried on across the dimmed
game beside the panel.

**Cause** — the rays sit in a CanvasGroup that should clip them to the
panel's rounded edge, and the ScreenGui used `ZIndexBehavior.Global`.
Under Global the CanvasGroup did not clip; a test group under Sibling did.

**Fix** — `UI/EndScreen` uses Sibling. The background gradient is also on a
plain frame now, with only the rays and glow in the CanvasGroup.

**Measured** — capture with Sibling: no ray outside the panel. Also found:
a hard horizontal seam across a capture is not necessarily on screen. One
here was red 17 → 0 with green and blue unchanged, at y = 688, a 16 px
JPEG block boundary — the capture's compression, not the UI.

---

## Card text pulsed big and small for a second after a click

**Symptom** — "when you click on one of the upgrade cards the text still pops
big and small over and over for about a second".

**Cause** — two springs stacked on the card's size. Selecting a card fired a
Balatro-style juice whose scale term was a decaying sine (about eight swings
in 0.4 s), and the selection size itself (1.0 → 1.1) ran on an underdamped
spring that overshot and rang. Text inside a scaled card swells and shrinks
with it, so the whole card read as throbbing.

**Fix** — `UI/Cards/DraftScreen`: the juice on select, deselect and confirm
keeps only its rotation wobble (scale amount 0), and the selection size eases
exponentially toward its target with no velocity, so it cannot overshoot.

**Measured** — a probe counted every change of direction in the card's
`UIScale` from click to rest: 0 reversals, peak exactly 1.10, the target.

---

## Arrows hit a pillar beside an enemy in plain view

**Symptom** — "some of the hits did not hit the enemies". Playtest clip
(2026-10-22, 1:49–1:52): a beetle half out from behind a pillar, fully
visible, and three seconds of arrows thudding into the pillar's corner.

**Cause** — by design, the archer aimed at the nearest enemy's *centre*
whatever stood in the way ("cover is a damage penalty"). The centre was just
behind the corner, so every arrow struck it, while the half of the enemy the
player could see was never aimed at.

**Fix** — `Shared/Combat/Aim`, used by the server's firing and the client's
prediction alike: nearest enemy with a clear line of fire (a box the arrow's
width swept against the arena's blockers), trying its centre and then each
edge, so a half-hidden enemy is shot in the half that shows. Only if no
enemy has a clear line does it aim at the nearest anyway. The owner asked
for the change; `Targeting.nearest` remains for ricochets.

**Measured** — `Aim.spec` rebuilds the clip's scene with a real pillar:
the centre line blocked, the edge line clear, and the edge chosen. Live, 59
of 60 arrows landed over a minute of play.

---

## Card text kept moving while a card was hovered

**Symptom** — "the card text keeps moving whenever they are hovered over".

**Cause** — the draft screen tilted a hovered card toward the pointer every
frame (`(pointer − 0.5) · 8°`) and kept a quarter of its idle sway, so the
whole card, words included, never stopped turning under the mouse.

**Fix** — after Balatro: a hovered or picked card holds still. No sway, no
pointer tilt; it lifts, grows a little, and gives one short "juice" — a
scale pop and a wobble dying away over 0.4 s (`sin(50.8t)` with cubic
fall-off, `sin(40.8t)` with square) — on hover, select, deselect and
confirm, then stops.

**Measured** — live, with the mouse resting on a card: rotation range 0°
and vertical drift 1 px over its last 0.6 s, while the unhovered card beside
it still floated ±1°.

**Then** — "do not change the text layout at all": scaling a card made
Roblox re-wrap its words (Diagonal Arrows' description jumped from 91 to
110 px wide at 1.05). Hover now only lifts the card — no scale, no turn,
no juice — and `CardBuilder` breaks the name and description into lines
once at the card's own size with wrapping off, so even the select pop
scales the same lines rather than reflowing them.

---

## Arrows blocked by cover looked like they failed

**Symptom** — a long-standing rough edge: an arrow that hit a pillar or a
wall just vanished, so cover read as a bug rather than a rule.

**Cause** — the only feedback was a ball the arrow's own width that faded in
0.18 s — too small and too quick to notice in a busy fight.

**Fix** — `ProjectileRenderer.spawnImpact`: a blocked player arrow now sticks
in the surface for about half a second, quivering to a stop, with its tip
buried 0.3 studs in. A ring flashes flat on the surface, and four chips fly
back off it. Bounces get the ring and chips without the arrow. It is still
not a hit effect: no number, nothing flashes.

**Measured** — in 20 s of live play, 12 of 12 stuck arrows had the tip
inside a blocker and the fletching outside it.

---

## The walls flickered while moving

**Symptom** — "the walls is clipping when moving". The side walls and the
wall-top corners shimmered, only while the camera moved.

**Cause** — z-fighting from the art pass's dressing. The lamp columns were
exactly as thick as the side walls and centred on them, so each column's
faces lay in the same planes as the wall's faces, in a different colour. The
side wall caps ran the full room length and overlapped the end caps at all
four corners, with their tops in one plane. Two opaque coplanar faces have no
front; the renderer's answer flips as the view changes. (The default
baseplate did the same to the floor in Phase 1 — see `clearDefaultBaseplate`.)

**Fix** — the columns stand 0.2 studs proud of the wall on both faces, as
pilasters, and the side caps stop where the end caps begin.

**Measured** — a probe of the live arena for overlapping coplanar visible
faces found 28 before (both faces of all ten columns against their walls,
and the cap tops and ends at the corners) and 0 after.
`Arena.spec` now fails if any two visible arena parts share a face.

---

## Knocked-back enemies left their bodies behind

**Symptom** — "the enemy models are not following the ring that is getting
knocked back". The target ring slid away with the hit; the body stayed put.

**Cause** — the knockback slide and the end-of-frame separation moved the
hitbox with `hitbox.Position = …`. A WeldConstraint only carries its other
parts when a part's **CFrame** is set; a Position write moves the hitbox
alone and silently re-welds the body at the new offset. So the body stayed
offset for the rest of the enemy's life, and arrows struck an invisible box
beside the visible enemy. The old instant knockback had the same bug, just
too fast to notice.

**Fix** — every move goes through `placeHitbox`, which sets the CFrame
(position plus the enemy's turn). Knockback back to 3 studs at the same
time (owner's call).

**Measured** — 0.000 studs of drift between body and hitbox across 38,320
body-part samples with 12 knockback hits. `tests/EnemyModel.spec.luau` pins
both that CFrame carries the body and that Position does not.

**Watch for** — any new `hitbox.Position =` on an enemy. Set CFrame.

---

## The killing blow showed no damage number

**Symptom** — found while restyling damage numbers: the hit that finished an
enemy drew no number, so the strongest moment of a fight was the invisible
one.

**Cause** — `EnemyManager.damage` fires `EnemyHit` only while the enemy
survives; a killing blow fires `EnemyDied` instead, which carried only a
position.

**Fix** — `EnemyDied` carries the blow's amount and kind, and the client
draws it like any other hit.

**Measured** — 10 of 10 kills drew a number in a clean run; with crits and
burns on, killing blows arrived as Hit 2, Crit 7, Burn 2 and every one was
drawn in its own style.

---

## Turned enemies' hitbox corners poked into pillars

**Symptom** — found by a clipping probe, not reported: hitbox corners up to
0.62 studs inside pillars.

**Cause** — `Arena.resolve` kept an enemy's *centre* half a hitbox from a
face, which is exact only while the square hitbox is square-on. It turns
with the enemy, and at 45° a corner sits 2.12 studs from the centre.

**Fix** — `Arena.resolveBox` takes per-axis half-widths; enemies resolve by
their footprint at their current turn, again after turning each frame, and
in knockback and the end-of-frame separation.

**Measured** — 0 hitbox corners inside a pillar across 2,819 enemy samples
in 5 rooms (was up to 0.62 studs). 173 tests pass, including a turned square
at 0/20/45/70° ending clear of a pillar.

**Watch for** — the Bulwark in Teeth: turned 45° it needs 8.49 studs and one
channel there is 8.4. It is squeezed, never unshootable. And probes: see the
`GetPartBoundsInBox` note in `CLAUDE.md`.

---

## Enemy orbs crawled at a third of the reference's speed

**Symptom** — measured, not reported: Spitter and Lurker orbs at 4–4.4
studs/s, against 0.27–0.40 room-widths a second (~12 studs/s) in the
footage. The Spitter's own comment asked for the teardown's 8–20 band.

**Cause** — the same as the arrows: scaled down with the room rather than
measured, twice over.

**Fix** — Spitter and Lurker 12, Lancer 14 → 28 (the footage's fast red
shot, one sample). Each lifetime adjusted so reach is unchanged: only speed
moved.

**Measured** — tracked in the footage with camera drift removed (static
objects read 2–10 px/s, so the correction holds). In Studio, the Lancer's
drawn orbs measured 27.5–27.8 studs/s, and none was drawn overlapping
the player across 162 orb frames.

**Watch for** — difficulty. These are the biggest single jump enemy fire
has had, and the Lurker's point-blank fan now arrives about 0.15 s after
its tell instead of 0.45 s.

---

## Arrows did not stop at the enemy's hitbox

**Symptom** — "make the projectiles stop when they hit the hitbox of the
enemy". Mostly the arrow vanished before it reached the enemy it hit.

**Cause** — two halves. The flight left a stopped arrow with its *centre* on
the contact point, half its length inside the body. And the renderer released
the part on the same frame the flight ended, so the stop was never drawn: at
190 studs/s the last frame shown could be three studs short.

**Fix** — a projectile that stops is left where its box first touches, with
its tip on the surface (`RaycastResult.Distance` along the cast). One that
carries on (pierce, bounce, a body already struck) still moves to the contact
point, inside, because left merely touching, every following cast finds the
same body again and the arrow stalls on its surface. The renderer draws a
stopped arrow for one more frame before releasing it.

**Measured** — `ProjectileFlight.spec` checks that a 190 studs/s arrow stops
with its tip within 0.05 studs of the body's face.

---

## Bouncing and piercing arrows stopped dead on screen

**Symptom** — found auditing the projectile code against the reference video,
not reported. With Ricochet (then a wall bounce) or Piercing Shot, drawn
arrows stopped at the first wall or enemy, while damage kept landing further
on with nothing visible causing it.

**Cause** — two flights. `ProjectileSystem` bounced and pierced;
`ProjectileRenderer` had its own simpler step that stopped every arrow at its
first contact, whatever the loadout. The same class of bug as #25: the client
showing a different shot from the one the server fired.

**Fix** — one flight. `Shared/Combat/ProjectileFlight` holds the sweep, the
overlap pass, bounces and pierce, and both sides step through it, answering
contacts through a `Contact` table: damage on the server, a spark on the
client. Server-invented shots (chain, ricochet) carry the body they leave
from, so the drawn arrow does not stop inside it.

**Measured** — loadout of Ricochet 2, Bouncy Wall 2, Piercing Shot 1 and
Diagonal Arrows: 185 drawn wall bounces and 13 drawn ricochets in 2,838 arrow
frames. In a clean run, 0 of 98 arrow frames inside an enemy, with 48 hits
from 63 volleys. `tests/ProjectileFlight.spec.luau` pins bounce, pierce,
the ignored source body and footage-speed hits.

**Watch for** — any change to how a projectile moves made in
`ProjectileSystem` or `ProjectileRenderer` instead of `ProjectileFlight`.

---

## Arrows ten times slower than the reference

**Symptom** — "make sure that projectiles are reacting the same as the video".
Measured at 1080p, 60 fps: Archero 2's arrows cross about 5.5 room-widths a
second. Ours did 0.5.

**Cause** — the speed was scaled down with the room when the room was rebuilt
to Archero 2's proportions, rather than measured. Speed was never in the
measurements table, so nothing caught it.

**Fix** — `Projectile.speed` 17.4 → 190, lifetime held at 45 studs of reach.
At that speed an arrow covers more than its own length a frame, which breaks
the overlap pass's assumption, so `ProjectileFlight` sub-steps flight at
`maxStepTravel` (1.2 studs, under half an arrow). The arrow trail became a
length (4 studs) rather than a lifetime, or it draws across half the room.

**Measured** — 160 tests pass, including a 190-studs/s arrow at 30 fps
landing on a body in its path and a body appearing inside a fast arrow.

**Watch for** — `maxStepTravel` reaching half the arrow's length:
`HitDetection.spec` fails at exactly 1.5, and it should.

---

## Ricochet bounced off walls; Archero 2's bounces between enemies

**Symptom** — the video's card reads "Bullets can bounce between monsters,
+1 bounce". Ours bounced off walls.

**Fix** — Ricochet now fires a new arrow from the point of contact to the
nearest enemy this chain has not struck, within `ricochetRange` (14), at
`ricochetDamageScale` (0.7). The wall bounce survives as its own card,
Bouncy Wall. Diagonal Arrows narrowed from ±45° to the footage's ±30°.

**Measured** — 19 ricochets announced in one run, each leaving 3.4–4.4 studs
from the centre of the enemy it hit, which is the surface of a 3-stud body.

---

## A shot enemy could be knocked into another for a frame

**Symptom** — found while verifying the larger room, not reported: four
overlap frames in one run, one of them 1.8 studs deep.

**Cause** — frame order. Separation ran at the end of the enemy step, but
projectiles resolve *after* that, and a hit knocks its enemy back two studs —
often into whatever is behind it. The overlap then stood until the next
frame's separation.

**Fix** — separation moved to its own call, `EnemyManager.resolveOverlaps`,
run last in the server loop after everything that can move a body.

**Measured** — before: 4 overlap frames, worst 1.8 studs. After: 0 overlap
frames across 1,921 with 12 knockback hits in the run. Not a controlled A/B —
the hit count before was not recorded — but consistent with the cause.

**Watch for** — anything new that moves an enemy (a pull, a push, a
teleport). If it runs after `resolveOverlaps`, it reopens this.

---

## Enemies spawned standing inside each other

**Symptom** — found while verifying the move to Archero's proportions, not
reported: 102 overlapping enemy-pair frames in one run, where the old room
showed almost none.

**Cause** — the spawn scan kept new enemies away from *players* and nothing
else, so two members of one wave could be picked from neighbouring grid cells
and arrive inside each other. In a ninety-stud room that was rare enough to
hide. At 28 studs wide it happened every wave. A second cause sat behind it:
the separation pass only closed a quarter of an overlap per side per frame,
and in a small room where everything converges on the player, steering
pushed bodies back together faster than that.

**Fix** — `clearOfEnemies` in the spawn scan, so a wave's members are placed
apart from each other as well as from the player; and separation now
resolves the whole overlap each frame, leaving bodies exactly touching.

**Measured** — one run: 260 brushing frames, worst 0.66 studs deep. After:
worst **0.014 studs** — floating-point touching — and 0 frames reaching even
a quarter-stud.

**Watch for** — any change that makes rooms smaller or more crowded. Density
is what exposes this, not code.

---

## The Bulwark copied the player's movements

**Symptom** — "there is a bug on level 4 where the giant enemy mirrors the
movement of the player". Room 4 is the first room with a Bulwark in it.

**Cause** — not its movement. Measured: at range it chases normally, two to
three studs a second, loosely towards the player. The problem was *facing*.
Every enemy snapped to face the player every frame with `CFrame.lookAt`, and
the Bulwark's shield is wider than its body — so the whole slab swung in
exact step with every move the player made. Strafing past it at six studs, it
turned up to 30.7° in a single frame and 315° in three seconds. The player
could also walk inside its hitbox, since enemies deliberately do not collide
with the player, and crossing its centre flipped it straight round.

**Fix** — a `turnRate` per archetype in `Balance`, and facing turns towards
the player by at most that much per second instead of snapping. The Bulwark
turns at 90°/s; a Charger at 540. Facing is presentation only — every shot is
aimed separately — so this changes how an enemy looks, never how hard it is
to dodge.

**Measured** — the same close-range strafe, before and after: largest
single-frame turn **30.7° → 3.1°**, the remainder being two server frames
arriving together over replication. It now trails the player at its cap
rather than tracking them exactly.

**Watch for** — any enemy that seems to copy the player. Check the facing
before the steering. `tests/Balance.spec.luau` requires every archetype to
turn and none to snap, and no bigger enemy to turn faster than a smaller one.

---

## Front Arrow's extra arrows missed the target they were aimed at

**Symptom** — "the front arrow upgrade should not go out in a v shape it
should be one next to the other in a straight line parallel, make sure they
are close enough so both will hit the target".

**Cause** — Front Arrow was built on `Stages.spread`, an angular fan. A fan
separates with distance, so at range only the centre arrow reaches the enemy
every arrow was aimed at. Archero 2 renders the same upgrade as a tight
parallel lane, confirmed from the reference footage.

**Fix** — a `lateralOffset` on the spec and a `Stages.parallel` that offsets
extra arrows sideways on the same heading. `ShotPipeline.spawnPoint` places
them, and the server, the client's prediction and the renderer all call it,
so the lane is a lane in the simulation *and* on screen.

**Measured** — live, one stack: two arrows both on angle 0, starting 0.84–0.85
studs apart against a configured 0.85, centred on the aim line.
`tests/AbilityEffects.spec.luau` holds the full four-stack lane inside the
narrowest enemy's hitbox, so widening the spacing far enough to miss again
fails a test.

---

## Blast Arrows exploded invisibly

**Symptom** — "the bomb upgrade needs to be more pronounced so the player
knows that the bomb is exploding".

**Cause** — splash damage was applied server-side with no event at all, so
enemies near the target simply died for no visible reason.

**Fix** — an `Explosion` remote carrying the real radius, and a client effect
in two parts: a ground ring that snaps to the true radius and only fades,
because the area *is* the information, and a core flash that expands so it
reads as a detonation. Light shake, gated on tier.

**Measured** — 17 explosions fired, 17 rings drawn, at the radius one stack
grants.

---

## The player could walk around behind the upgrade screen

**Symptom** — "make sure when the player levels up and unlocks an upgrade
that they cant move when the upgrade screen is there".

**Cause** — the server froze the world and the client froze firing
prediction, but movement and the dash read neither. The player crossed a room
nothing else was running in, and reappeared elsewhere on choosing.

**Fix** — one `RunPaused` flag on the client, read by movement, prediction and
the dash, rather than three copies of it. Movement is actively told
`Move(zero)` so the Humanoid does not coast.

**Measured** — partially. `tests/RunPaused.spec.luau` pins the flag, but the
movement half needs real input and `VirtualInputManager` is capability-blocked
over MCP, so walking behind the cards has been reasoned about rather than
driven. If it still happens, the wiring in `MoveController.step` is where to
look.

---

## Abilities did nothing, and arrows stopped connecting

**Symptom** — two complaints, one cause: "the player projectiles are missing
again" and "the abilities dont actually change what is happening".

**Cause** — the client draws its own predicted volley and deliberately skips
the server's copy to avoid double-drawing. Its pipeline was never given the
loadout, so it drew **one unbuffed arrow for the whole run** while the server
fired the real ones at angles nothing on screen reflected. The arrow the
player watched was not one of the arrows that existed — so abilities appeared
to do nothing, and shots appeared to pass through enemies that a different,
invisible arrow was busy killing.

`LocalFiring` had carried a comment since Phase 1 saying precisely this would
happen if Phase 3 did not replicate the stage list. Phase 3 did not.

**Fix** — `ClientStats` now carries the ability stack counts and the attack
cooldown. Stages are functions and cannot replicate; counts can, and
`AbilityEffects.stages` rebuilds the identical pipeline on either side. The
prediction rebuilds on every grant rather than per volley.

**Measured** — server arrows fired versus arrows actually drawn, over one
window with Front Arrow taken: **99 fired / 21 drawn (21%) → 112 fired / 112
drawn (100%)**, every volley two-arrow.

**Watch for** — anything the client predicts. Movement, firing rate and volley
shape are all predicted here, so every one of them needs its inputs
replicated. `tests/AbilityEffects.spec.luau` now pins the contract: whatever
`clientStats` carries must rebuild the server's volley exactly.

---

## Prediction froze for the rest of the run after one draft

**Symptom** — found while verifying the fix above, not reported: after a card
screen, the client drew almost nothing.

**Cause** — the pause that stops the client predicting during a draft was
lifted in the card button's own callback. Any choice that did not go through
that click — and any click that was missed — left prediction paused for ever,
while the server went on firing arrows nobody could see.

**Fix** — resume on the next `PlayerStats` from the server instead. The server
sends it on every grant and every run reset, so it means "the world is running
again" however the choice was made. The button still clears it too.

**Measured** — choosing by remote without touching the button: 21% agreement
before, 100% after, with 0 phantom arrows drawn during a deliberate one-second
pause on the card screen.

**Watch for** — any client state whose *exit* depends on a UI callback. The
entry can be a UI event; the exit has to be something authoritative, or a
single missed input strands the player.

---

## All three draft cards drawn on top of each other

**Symptom** — a level-up offered what looked like one card. The other two were
behind it, exactly aligned.

**Cause** — `clearCards` used `ClearAllChildren` on the card holder, which
destroyed the `UIListLayout` along with the cards. `show` clears before it
builds, so this bit on the *first* offer and every one after: with no layout,
three cards sized `UDim2.new(1, 0, 0, 108)` all resolve to the same position.

**Fix** — clear only the `TextButton`s and leave the layout alone.

**Measured** — before: 3 cards, 1 distinct Y position, no layout present.
After: 3 cards at y = 296 / 418 / 540, spaced by exactly the card height plus
the configured padding, layout intact. Confirmed on a *second* consecutive
offer, since that is the path that clears an existing screen.

**Watch for** — any Roblox UI built once and refilled later. `ClearAllChildren`
takes the constraints, layouts and corners with it, and the result is not an
error — it is a layout that silently stops applying.

---

## A passing test run against code Studio was not running

**Symptom** — the in-Roblox suite passed with a plausible test count while
newly added specs were silently not running at all.

**Cause** — `rojo serve` keeps its process alive after the Studio plugin has
stopped being connected to it; branch switching triggers this. Studio then
goes on running whatever it had when the link broke. Nothing reports an error
at any layer: the suite runs, the old specs pass, and the count only looks
wrong if you already know what it should be.

**Fix** — none in code; this is a procedure. After any branch switch or
`rojo serve` restart, verify the link before trusting an in-Roblox result:
read the `.Source` of a file you just changed and check the change is in it.
Restarting `rojo serve` drops the plugin and reconnecting is a manual click in
Studio.

**Measured** — a suite reporting `PASS — 89 tests` while two new specs worth
31 tests were absent from `ServerStorage.Tests` entirely. The same probe after
reconnecting reported 120.

**Watch for** — any in-Roblox result that does not change when you expect it
to. The stale read is the default failure here, not the exception.

---

## Lurker surfaced outside its own warning marker

**Symptom** — "im not sure when it is disappearing and when it is coming back".

**Cause** — The ground marker was sent from wherever the Lurker was when the
0.75s warning began, and then it *kept travelling underground for the whole
warning*. At burrow speed that is about ten studs, against a marker 6.5 studs
across. So it routinely came up nowhere near the circle it had just drawn.

**Fix** — The marker is a promise, so the trip now ends when the promise is
made: the position is resolved out of any obstacle and frozen, and the
underground steering is gated on `surfaceTold`. See `EnemyManager.stepEnemy`.

**Measured** — distance from marker centre to where it actually surfaced:

| | mean | worst | surfaced fully outside the marker |
|---|---|---|---|
| before | 6.14 studs | **27.24** | 3 of 10 |
| after | 0.24 studs | 0.40 | 0 of 8 |

**Watch for** — any future "it hit me and I was not warned" report about the
Lurker. The counterplay is entirely "step off the circle", so a marker that
lies costs this archetype its whole reason to exist.

---

## Enemies standing inside each other

**Symptom** — visible clipping once archetypes got bodies; two merged
silhouettes read as one target.

**Cause** — Separation existed, but only as a soft force folded into an
enemy's *desired heading*, so it applied **only while the enemy was moving**.
Once one reached its hold distance it stopped, the steering stopped being
applied, and nothing pushed it back out of whatever it had drifted into. It
also used a flat 3.5 studs, which is narrower than a Bulwark.

**Fix** — A positional pass after the step loop that guarantees bodies never
intersect, measuring against real hitbox sizes, pushing both halves of a pair
back through `Arena.resolve` so a pair against a wall is not separated through
it. It is a nudge per frame rather than a snap, so crowds settle. The old
steering is kept: it keeps a moving group loose, this stops bodies merging.

**Measured** — overlapping pairs per frame, across 1801 frames: **348 → 38**,
worst remaining penetration 1 stud (bodies grazing while converging).

---

## Player arrows passed through enemies

**Symptom** — "sometimes the projectile hits the enemy and it does not damage
it", and "sometimes it damages the enemy and then goes through it".

**Cause** — **A shape cast ignores anything it already intersects when it
starts.** The arrow's box is 4.2 studs long and centred on the simulated
point, so there is a 2.1-stud region in front of it the sweep cannot see into,
while one frame of travel is only 0.93 studs. Measured: a target overlapping
the box by 0.1 studs reports a clean miss, and so does one dead centre.

Nothing static can get in there — a pillar's gap shrinks by exactly one frame
of travel per frame, so the sweep always catches it. A *moving* target can: a
Charger closes at 63.5 studs/s against a sweep covering the arrow's own 0.93,
so the gap goes from positive to deep inside the box between two frames. From
then on the box carries the enemy along inside itself.

**Fix** — The overlap pass already existed and already did the right thing; it
was gated to run once at spawn. It now runs every step. The client mirrors it,
which fixed the second symptom — the server stopped the shot and the renderer
did not. Separately `EnemyManager.damage` reported whether it *killed* rather
than whether it *landed*, and the caller discarded that and returned true
regardless.

**Measured** — drawn-arrow frames whose centre sat inside an enemy hitbox:
**46 of 1271 (3.61%) → 0 of 1284**, worst single arrow 8 frames → 0.

**Watch for** — this is the third time hit detection has broken. Any
"projectiles do not connect" report starts here. `tests/HitDetection.spec.luau`
pins the engine behaviour the fix compensates for.

---

## Enemy bodies could have broken hit detection

**Symptom** — none yet; this is the trap that was avoided when archetypes got
bodies.

**Cause** — Giving an enemy decorative parts makes it very easy for one of
them to answer raycasts, which silently widens the hitbox the whole combat
system is built on.

**Fix** — The hitbox is invisible and remains the only queryable part. Every
skin part has `CanQuery` off and is welded to the hitbox, so the shape the
server sweeps is unchanged.

**Measured** — in a live room: 0 skin parts answering raycasts, hitbox sizes
unchanged, 0 studs of drift between skin and hitbox after 2.5s of walking.
`tests/EnemyDesigns.spec.luau` additionally enforces that a body fits inside
its hitbox *and* fills it — both directions are the same complaint, since a
body wider than its box gives shots that visibly connect and do nothing, and a
body smaller gives shots that visibly miss and damage anyway. It caught the
Lancer at 59% of its own width on the first run.

---

## Earlier fixes

These predate this log and are recorded in `CLAUDE.md` under "What first run
fixed" and "Testing over MCP, learned the hard way":

- **Chargers deadlocked against pillars**, soft-locking the room. The normal
  was measured at the probe point rather than at the body, and the slide side
  was re-decided every frame.
- **The Burrower dived exactly once.** The dive gate and the hold distance
  were the same number.
- **Waves spawned on top of the player.** Rooms are populated before any
  session exists, so the exclusion check measured against an empty list.
- **Room 1 ate every arrow** — 41 of 45 player shots hit an obstacle placed
  across the spawn's sight-line. The test written for that change checked that
  the room stayed uncleared, which passed *because nothing could be hit*. The
  wrong thing was verified.
- **Enemy projectiles vanished into walls** on the client, because the
  renderer used one filter containing arena blockers for every faction, while
  the server flies enemy shots straight over them.

## King Bloblin's lash arm had no substance, and no red line warned of it

**Symptom:** the owner: "the arm that he throws has no substance and there is
no red line that tells you where he is attacking next".
**Cause:** two. The chain's stretch (`ModelClipStretch` on `LashRoot`) scaled
every link along the lane, and only the fist was in `stretch.keep`, so the
links were squashed to thin slabs (0.6 studs deep) when thrown. The lane was
small, gapped tiles of pale salmon Neon (255, 90, 42 pulsing to 255, 194, 166),
0.12 high and 45% clear, starting under his body, where nothing showed.
**Fix:** every `LashLink_N_Joint` is in the King's `stretch.keep`, so the lane
length spaces the links and never resizes them. The lane is strong red
(`Balance` `laneColor` 225, 25, 25), its tiles nearly touching, 0.2 high, 25%
clear while tracking and opaque once locked, and it starts `laneStart` (3.3)
out, at his edge.

## King Bloblin's thrown arm vanished once every link was kept at its size

**Symptom:** after the links joined `stretch.keep`, the lane locked and the
strike landed with no arm at all; at the strike his `LashFist` measured some
34,000 studs from him.
**Cause:** `ModelClip.pose` undid the stretch on a kept joint in the joint's
own axes. The links are turned against the chain, so `S(s) · R · S(1/s)` is
not the identity but a shear by up to `1/s`, and a lash starts with the
stretch near zero (`1/s` clamped at 1000). The fist alone had got away with
it because it lies along the chain.
**Fix:** a kept joint (listed in the stretch with its parent) has the stretch
undone in the parent's axes, `S(1/s) · R · S`, which cancels exactly however
it is turned. `ModelClip.spec` pins a link turned 45° at stretches of 0.001,
0.3 and 4.

## King Bloblin's lash arm drew as pale specks, though its parts were full size

**Symptom:** the owner, again: "the arm that he throws has no substance". With
the links placed and sized right (1.3 to 1.8 studs, spaced 1.2 to 1.5 from 3.5
to 17 studs out), all that showed were small pale dots along the line.
**Cause:** the GLB rests the chain tucked away at a thousandth of its size, so
the importer uploaded each link's mesh at that size (`MeshSize` 0.001; sizes
around 0.0003 in `ImportedModels/KingBloblin`). Scaled back up 1,500 times,
the mesh keeps too little of its shape to draw as a block.
**Fix:** `EnemyModel.importedDesign` builds a tucked part (under
`TUCKED_SHARE` of the model's largest part) as a plain block of its colour
instead of its mesh; in the blocky style each link is a cube anyway. Look at
`MeshSize`, not `Size`, when a mesh part draws smaller than it measures.

## Upgrade effects imported as up to 771 parts, and ten with pieces crushed to specks

**Symptom:** found before shipping. The 44 upgrade-card effects came out of
Claude Design as 2,775 parts, one per cube (Heavy Blade alone was 771),
which would have been cloned and posed on every hit. Ten imports also had
pieces at a thousandth of a stud (Heal's pour, Precision's lit ring,
Momentum's lit segments, and others), so they would have drawn as specks.
**Cause:** Claude Design exports every cube as its own mesh. A piece hidden
until its clip grows it rests at zero scale, and Roblox imports a mesh at its
rest size (the same fault as King Bloblin's lash links).
**Fix:** `assets/models/effects/optimise_effect.py` runs before import:
- It merges what moves together, and bakes colour into vertices.
- It splits Neon by the importer's own `NEON_GLOW`.
- It rests hidden pieces at full size, with every clip that doesn't scale them
  holding them at zero.
- It culls buried faces. Strength's voxel cuffs are rebuilt rather than
  decimated, because decimating melted them into a blob.

The result is 1,952 parts down to 240. `tests/UpgradeFx.spec` holds every
effect to `Balance.UpgradeFx.maxParts`.

## Trees outside the arena clipped into each other as the camera moved

**Symptom:** the owner: "the clipping is on the trees outside of the arena".
After #240 moved the ambience clear of the crowns, the trees themselves still
cut through one another as the view slid with the player.
**Cause:** the imported forest had six pairs of neighbouring crowns running
into each other (up to 0.82 studs), four trunks reaching into the next tree's
crown, and one pair of trunks touching. An earlier check missed it: it
measured each crown as a shrunken circle, not by its full blocky box.
**Fix:** `tools/forest_to_luau.py` separates trees before writing
`Config/GladeForest`. Each tree (trunk and crown together) is pushed apart
from any tree it overlaps, along the smaller overlap, with a 0.3-stud gap,
and the move goes to whichever tree it takes away from the room. 17 trees
moved, at most 1.1 studs. Measure trees by their full boxes, not circles.
