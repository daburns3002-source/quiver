# Audit of Arrowborne's screens (2026-11-05)

The big problem is not one screen — it is that **every screen copies a different reference in a different
style**, so the game has no single look:

| Style in use | Screens |
|---|---|
| Candy-cream gloss panels (`Kit.panel`: cream/gold, thin ink stroke, gold rim) | Shop/Blacksmith, Gear, Egg Hatchery (HatchStand), Reveal, Station |
| Tap Simulator egg stand copied "1 to 1" | HatchStand (eggs and crates) |
| Pixel-blocky stair-step panels drawn from flat blocks | End screens (Victory/Defeat) |
| "Glow Toy" cards on a blue panel | Draft cards, SkillBar, DetailPanel, MythicReveal |
| One painted Codex picture with live bits laid on it | Dex books, Class select, loading/NewEnemy |
| Plain frames placed in raw pixels | ControlMenu, SandboxMenu, BossBar, DashBar, RoomSign, RunBanner |

## Clunky, and why

| Screen | Clunky because |
|---|---|
| **Font everywhere** | `Enum.Font.Arcade` (pixel font) on almost every label: at phone size the descriptions on draft cards, dex tabs and odds lists are unreadable mush. Top games use one rounded bold font with a thick dark stroke. |
| **Shop / Gear / Eggs / Dex / Portal** | No open or close motion at all (0 tweens in ShopScreen, GearScreen, EggScreen, HatchStand, DexScreen, PortalScreen, StationScreen) — they blink on and off. Buttons do not squash on press. |
| **Kit panels** | Cream-on-cream with a 4 px ink stroke scaled down to ~1–2 px on a phone, so panels lose their outline; gold rim + gloss on pale cream reads washed out next to the saturated 3D world. |
| **HatchStand** | A white card with price, picker, AUTO, odds list and pity bar all stacked in one column — lots of small text, the HATCH buttons are keyboard prompts (E / R / T) first and buttons second. |
| **Gear** | 1030 lines; two different canvases (landscape 1920×1080, upright 1920×TALL) with dozens of hand-placed rects; slots small, item card is a second panel on top of the first. |
| **Dex** | The book is one painted picture; tabs (ENEMIES/WEAPONS/PETS) and the "READ THE DEXES [E]" bar are tiny and sit outside the art; the left page text is small pixel text on parchment. |
| **Portal / level select** | 10 numbered buttons + a text line under the grid; no picture of the boss, no stars, CLEARED is a text tag. Placed partly in raw Offset pixels. |
| **Draft cards** | Seven narrow tall cards with title and description in tiny pixel text; at 1891 lines with 64 raw-pixel placements it is the least phone-friendly screen. |
| **End screens** | Readable and on-style, but the pixel stair-step look matches nothing else in the game. |
| **HUD** (HealthBar, DashBar, BossBar, RoomSign, RunBanner, SkillBar) | Thin bars with no icon, text-only banners, no currency/level read-out in the fight; each piece styled on its own. |
| **ControlMenu / SandboxMenu** | Plain tabs pinned to the left edge in raw pixels — debug-looking. |
| **Lobby** | No HUD rail: stations are reached only by walking + E; nothing on screen says where the shop, gear, eggs or dex are. |

## What the restyle should give every screen

One kit (`Kit` v2): a bold rounded font with stroke, chunky outlined buttons with a dark lip and press
squash, a saturated colour per role, a title ribbon over the panel edge and a corner X, pop-in/out tweens,
and one layout rule for phones (landscape: panel ≤ 80% of height; upright: full width, list scrolls).
