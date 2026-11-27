# UI references (2026-11-05)

Frames taken from gameplay videos of today's top Roblox games and Archero 2, for the UI restyle
(owner: "STUDY THE TOP ROBLOX GAMES UI AND MAKE REFERENCES THAT YOU CAN COPY").
Internal reference only — we copy the *ideas* (shapes, weight, layout), never their art or logos.

| File | What it shows | What to copy |
|---|---|---|
| `ps99_hud_quest.jpg` | Pet Simulator 99 lobby HUD | Icon-first left rail of square glossy buttons (no words), currency pills bottom-left with big icon overlapping the pill's left end, quest card top-centre with a progress bar and a bright CTA button under it. |
| `ps99_open_egg_confirm.jpg` | PS99 "open this?" dialog | Small white rounded card, thick dark outline, red square X that hangs off the top-right corner, three fat green buttons in a row with dark text-stroke. |
| `ps99_upgrades_panel.jpg` | PS99 upgrades list | Title floats *above* the panel in big outlined letters; rows are white cards with icon left, name + one-line description, price pill right, square green "up" button. |
| `growagarden_seed_shop.jpg` | Grow a Garden seed shop | Three tab buttons across the top in different saturated colours (blue / brown / red) — each tab's colour is its identity. Shop rows on a wood panel; price in a big green button, alt-currency in purple, timer in the header. |
| `animevanguards_traits_panel.jpg` | Anime Vanguards traits | Slanted title banner breaking out of the panel's top-left, item card with rarity glow, three wide coloured action buttons (purple / green / blue) with heavy text stroke. |
| `animevanguards_end_screen.jpg` | Anime Vanguards Failed screen | Red slanted "Failed" banner; two-column stat grid, each stat with a small icon; reward tiles with rarity border + count; two wide buttons (blue = back, yellow = retry). |
| `archero2_levelup_cards.jpg` | Archero 2 level-up skill pick | Gold ribbon "Level Up" + one-line subtitle; three tall cards with the skill name on a header strip, big icon in a circle, one-line effect. Our draft should read this fast. |
| `archero2_mail_panel.jpg` | Archero 2 panel | Warm parchment panel with a blue title ribbon across the top edge; footer buttons blue (secondary) and gold (primary). |
| `beeswarm_egg_list.jpg` | Bee Swarm inventory list | Icon tile left with a count badge, bold name, small grey description. Plain but very readable. |
| `bloxfruits_hud_shop.jpg` | Blox Fruits HUD + shop | Counter-example: thin flat boxes, tiny text, HUD crammed into corners — what "clunky" looks like. Avoid. |
| `adoptme_backpack_hud.jpg` | Adopt Me backpack | Pink panel with category icon column on the left, item grid on the right, search box in the header; red X on the corner. |
| `adoptme_hotbar.jpg` | Adopt Me mobile HUD | Round bottom hotbar of icon buttons, money pill top-right with icon, big round jump button bottom-right — clean phone layout, the centre of the screen is left empty. |

## What makes these feel good

1. **Chunky shapes.** Buttons are fat (on a phone ≥ 56 px tall), rounded (radius ~25% of height), with a
   thick dark outline (3–5 px) and a darker "lip" under them so they look pressable. Gloss strip on the top half.
2. **One bold rounded font**, white with a thick dark stroke (Fredoka One / Luckiest Guy look). Never a
   tiny pixel font for body text. Titles are big; descriptions are one short line.
3. **Saturated colour = meaning.** Green = buy/confirm, red = close/danger, blue = secondary, gold = premium/primary,
   purple = gems/rare. Each tab has its own colour.
4. **Icon first.** HUD buttons are square icons without words (with a small label at most); currency is
   icon + number in a pill, the icon bigger than the pill and overlapping its end.
5. **Title breaks the frame.** The panel title sits on a ribbon/banner that overlaps the panel's top edge;
   the X hangs off the top-right corner.
6. **Bounce.** Panels pop in (scale 0.8 → 1.05 → 1, ~0.25 s, Back easing) and shrink out; buttons squash
   on press (0.92) and spring back.
7. **Mobile.** Left rail of icon buttons, currency bottom-left or top-right, joystick zone bottom-left and
   action button bottom-right left empty, centre of the screen clear. Panels fill ~80% of the short side
   and stay centred; lists scroll rather than shrink.
8. **Few words, big numbers.** Prices, counts and odds are the largest text on a row.
