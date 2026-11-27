# Store page pictures

The icon and thumbnails for the experience's store page (owner, 2026-11-27: "Yes, make them"), in
`assets/store/`. Every one is a real Studio Play capture of the game (main 5a47317a for the lobby and class
select, 83460c87 for the rest), not drawn or generated art. The owner picks and uploads them on the Creator Dashboard (Places, the experience,
Configure: Icon and Thumbnails). Claude uploads nothing. `contact-sheet.jpg` shows them all side by
side, with each icon at small sizes too.

## Thumbnails, 1920 x 1080

| File | What it shows |
|---|---|
| `thumb-1-lobby.png` | The lobby from above the fountain: the Weapon Shop, the Egg Hatchery and the portal hall. No HUD. |
| `thumb-2-fight.png` | A Thornwood fight (2-5) with upgrade cards in play (Multishot's fan of arrows, Blaze's fire and more) hitting a charging pack, damage numbers, the run HUD and skill bar. |
| `thumb-3-boss.png` | King Bloblin in the Glade Heart (1-10), his slam ring under him, the hero in front, his boss bar on top. |
| `thumb-3b-boss-leap.png` | A second boss pick: King Bloblin in mid-leap against the sky. |
| `thumb-4-egg-hatch.png` | A Mythic hatch: Glimmerhorn bursts out with the pink rays, confetti, NEW! and the MYTHIC banner, over the lobby. |
| `thumb-5-class-select.png` | Choose Your Class: Ranger, Arcanist, Warden and Assassin. |

Five is the set asked for; `thumb-3b` is a spare for the boss slot.

## Icon options, 512 x 512

| File | Pet | Colour |
|---|---|---|
| `icon-a-glimmerhorn.png` | Glimmerhorn, Mossy Glade's Mythic, glowing blossoms and its Mythic ring | moss green |
| `icon-b-slime-prince.png` | Slime Prince, King Bloblin's heir (Legendary), crown and glowing eyes | slime green |
| `icon-c-ember-wilf.png` | Ember Wilf (Legendary) | ember orange |

Pets, not a hero: in this game the hero is each player's own Roblox avatar holding the class
weapon, so an icon of the hero would be the owner's avatar. Each pet is the game's own model,
lit in Studio and cut out exactly from two frames (one on black, one on white), on a round glow in
the pet's own colour with pixel + stars. There are no words on them.

## How they were made (to redo one)

- Studio Play with `Workspace.SkipIntro`; the camera held with the RenderStepped, PreRender, Heartbeat
  and simulation hooks; HUD layers turned off each frame where a picture wanted none; the pointer
  hidden. The window was grabbed with `PrintWindow` (`PW_RENDERFULLCONTENT`), which reads Studio's
  pixels even behind another window and without taking focus.
- Fight: the Sandbox's dummies plus `DebugSpawnEnemy` Thornwood enemies, the cards from `DebugGrant`.
  Boss: `PortalStart(1, 10)`, `DebugRoom(25)`, with tough cards so the hero lives long enough (King
  Bloblin kills a level-1 hero in seconds). Egg: the server's `EggHatched` sent to the client, so the
  real reveal plays (nothing was hatched or granted).
- Roblox keeps its own menu buttons at the viewport's top left in Play. The 3D scenes are cut from
  below them, and the class screen's corner is refilled from its own header.
