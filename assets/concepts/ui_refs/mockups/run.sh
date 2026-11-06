#!/usr/bin/env bash
# UI restyle mockups (owner, 2026-11-05: "STUDY THE TOP ROBLOX GAMES UI ... USE CODEX AND MAKE A GOOD UI").
# Step 1 draws one style sheet from the top-game refs; step 2 draws every screen from that sheet,
# so they all share one style. Run again to fill in any that failed.
cd "$(dirname "$0")" || exit 1
R=..
STYLE="ONE consistent mobile-game UI style, as in the attached style sheet: chunky rounded panels in a rich royal-blue gradient with a THICK dark-navy outline (about 6 px) and a lighter blue inner rim; list rows are white rounded cards; a gold ribbon title banner that overlaps the panel top edge; a red square X button hanging off the panel top-right corner; fat glossy rounded buttons (green = confirm/buy, gold = primary, blue = secondary, red = close, purple = gems) each with a thick dark outline, a darker lip underneath and a white gloss strip on the top half; ONE bold rounded cartoon font (like Fredoka One or Luckiest Guy), white letters with a thick dark-navy stroke; currency shown as icon + number in a dark pill with the icon larger than the pill overlapping its left end; rarity colours grey/green/blue/purple/gold/rainbow with Legendary gold glow and Mythic rainbow glow; flat clean vector UI, no pixel font. The game is Arrowborne, a blocky voxel fantasy archer roguelite; game art (characters, eggs, weapons, pets) is chunky voxel style. Text must be large and readable on a phone. Spell every word exactly as given; no other text."

style() {
  [ -f style_sheet.png ] || [ -f style_sheet.jpg ] && return
  timeout 1200 codex exec -i $R/ps99_upgrades_panel.jpg -i $R/growagarden_seed_shop.jpg -i $R/animevanguards_traits_panel.jpg -i $R/ps99_hud_quest.jpg -i ../../blocky/ui/portrait/class_select_reference.png --skip-git-repo-check > style.log 2>&1 <<E
Generate ONE image, landscape, exactly 1920 x 1080 pixels, saved in the current directory as style_sheet.png

It is a UI STYLE SHEET for a Roblox game called Arrowborne (blocky voxel fantasy archer roguelite; the last attached image shows its art). Learn from the first four attached screenshots of top Roblox games what makes their UI feel good (chunky rounded buttons, thick dark outlines, drop lip, bold stroked font, saturated colours, icon-first HUD) and design an ORIGINAL kit in that spirit. Do not copy their art.

$STYLE

Lay the sheet out on a plain dark slate background, in labelled rows:
1. Top-left: a sample panel (about 700 x 460) with the gold ribbon title "SHOP", the red X, and three white row cards each with a voxel item icon, a name ("Oak Bow", "Ember Blade", "Frost Staff"), a one-line description, and a green price button with a coin icon ("250").
2. Top-right: a row of buttons in every colour: "BUY" green, "PLAY" gold, "BACK" blue, "CLOSE" red, "500" purple with a gem; under them the same green button shown pressed (squashed, lip hidden).
3. Middle-right: three currency pills: coin "12,450", gem "320", key "3".
4. Bottom-left: a vertical rail of five square icon-only HUD buttons (shop bag, sword, egg, book, gear cog), each a different saturated colour, with a small red "!" badge on one.
5. Bottom-middle: six small item tiles showing the rarity frames, labelled Common, Uncommon, Rare, Epic, Legendary, Mythic (Legendary gold glow, Mythic rainbow glow).
6. Bottom-right: a tab bar of three tabs "CRATES" "STORE" "SELL" (selected one raised and brighter), and a health bar with a heart icon and a level badge "LV 7".
E
}

screen() {  # name size body
  local n="$1" size="$2" body="$3"
  { [ -f "$n.png" ] || [ -f "$n.jpg" ]; } && return
  timeout 1200 codex exec -i style_sheet.png --skip-git-repo-check > "$n.log" 2>&1 <<E
Generate ONE image, exactly $size pixels, saved in the current directory as $n.png

It is a mockup of one screen of the Roblox game Arrowborne, drawn in exactly the UI style of the attached style sheet.
$STYLE

$body
E
}

style
[ -f style_sheet.png ] || [ -f style_sheet.jpg ] || { echo "no style sheet"; exit 1; }

screen lobby_hud "1920 x 1080 (landscape)" "LOBBY HUD over a sunny blocky voxel lobby (grass, a fountain, wooden station huts), the player voxel archer character in the centre. Left edge, vertically centred: a rail of five square icon buttons with tiny labels under each: SHOP (bag), GEAR (sword), EGGS (egg), DEX (book), PLAY (portal swirl, larger and gold). Top-left: player level badge LV 12 beside the name ImFil and an XP bar. Top-right: currency pills coin 12,450 and gem 320. Top-centre: a small quest card 'Beat Level 1-3' with a progress bar 2/3 and a green button GO. Bottom-left empty (joystick), bottom-right empty (jump). The middle of the screen stays clear." &
screen lobby_hud_portrait "1080 x 1920 (portrait, phone held upright)" "LOBBY HUD for a phone held upright, over a sunny blocky voxel lobby with the voxel archer character in the middle. Top: currency pills coin 12,450 and gem 320 on the right, level badge LV 12 with an XP bar on the left. Under them a small quest card 'Beat Level 1-3' with progress 2/3. Right edge, upper half: a vertical rail of four square icon buttons SHOP, GEAR, EGGS, DEX (icons with tiny labels). Bottom-centre above the thumbs: a big gold PLAY button. Bottom-left area empty (joystick)." &
screen fight_hud "1920 x 1080 (landscape)" "IN-FIGHT HUD over a top-down blocky voxel forest arena with green slime enemies and the voxel archer. Top-left: a big heart-icon health bar 840 / 1000 and a level badge LV 5 with a thin yellow XP bar under it. Top-centre: room plate ROOM 3/5 and a coin pill 1,240. Under the room plate: a boss bar with a skull icon and the name KING BLOBLIN on a red bar. Bottom-centre: a tray of six square skill tiles with rarity frames and small LV 2 plates. Bottom-right: a big round DASH button with a wing icon. Top-right: a small pause button. Keep the arena centre clear." &
screen draft_cards "1920 x 1080 (landscape)" "LEVEL-UP DRAFT over a dimmed voxel arena. Top: a gold ribbon banner LEVEL UP! and under it 'Choose a skill'. Centre: THREE big cards side by side, each a tall rounded card with a coloured header strip in its rarity colour with the rarity word on it, a big voxel skill icon in a circle, the skill name large, and ONE short line of description: card 1 Rare blue MULTISHOT 'Fire 2 extra arrows'; card 2 Epic purple FROST ARROW 'Arrows slow enemies'; card 3 Legendary gold with gold glow PHOENIX 'Every 5th arrow burns all'. The middle card is selected: lifted, bigger, bright outline. Bottom: blue button REROLL 1 with a dice icon and green button CHOOSE!" &
screen shop "1920 x 1080 (landscape)" "BLACKSMITH SHOP panel over a dimmed lobby. Gold ribbon title BLACKSMITH, red X. Tabs at the top of the panel: CRATES (selected, gold) and STORE (blue). Left half: a big voxel treasure chest on a pedestal with its name MOSSY CRATE, a price pill coin 500, and two buttons OPEN 1 (green) and OPEN 3 (gold), plus a small AUTO toggle. Right half: a white card titled INSIDE listing five weapons as FLAT 2D weapon pictures (bows and swords) in rarity-framed tiles with odds under each: 60%, 25%, 10%, 4%, 1% (the 4% Legendary glowing gold, the 1% Mythic glowing rainbow), and under it a pity bar 'Mythic in 37 opens'. Top-right of screen: coin and gem pills." &
screen gear "1920 x 1080 (landscape)" "GEAR screen panel. Gold ribbon title GEAR, red X. Left: the player voxel archer character standing on a round pedestal, with POWER 1,284 on a gold plate under it. Around the character six square equipment slots: WEAPON (a FLAT 2D bow picture, Epic purple frame), ARMOR, RING, AMULET, PET 1 and PET 2 (voxel pets). Right: a white inventory card with tabs WEAPONS and PETS and a 4 by 3 grid of item tiles in rarity frames, each with a small LV number, one Legendary glowing gold, one Mythic glowing rainbow; under the grid the buttons EQUIP BEST (green) and SELL (red). Top-right: coin and gem pills." &
screen hatchery "1920 x 1080 (landscape)" "EGG HATCHERY panel. Gold ribbon title HATCHERY, red X. Left: a big spotted voxel egg on a nest pedestal glowing softly, its name FOREST EGG and price pill coin 350; under it three buttons HATCH 1 green, HATCH 3 gold, and an AUTO toggle. Above the egg a row of three small egg choices with the first selected. Right: a white card titled PETS INSIDE with six voxel pet tiles in rarity frames, each with its odds under it (40%, 30%, 18%, 9%, 2.5%, 0.5%), the Legendary glowing gold and the Mythic glowing rainbow; under it a pity bar 'Legendary in 12 hatches'." &
screen dex "1920 x 1080 (landscape)" "DEX screen panel. Gold ribbon title DEX, red X. Tabs across the top in their own colours: ENEMIES (red, selected), WEAPONS (blue), PETS (green), with a counter pill FOUND 14 / 40. Left: a white detail card showing the selected entry big: a green voxel slime BABY SLIME, its area Mossy Glade, and two short stat lines HP 40 and DEFEATED 312. Right: a 5 by 3 grid of entry tiles, found ones as colourful voxel enemy portraits, unfound ones as black silhouettes with a ? badge. Page arrows left and right of the grid and PAGE 1/3." &
screen portal "1920 x 1080 (landscape)" "LEVEL SELECT for a portal. Gold ribbon title MOSSY GLADE, a small ACT 1 tag, red X. Background inside the panel: a soft painted mossy forest. Centre: two rows of five round level nodes 1 to 10 joined by a dotted path; levels 1-3 cleared with three gold stars under each, level 4 selected (bigger, glowing gold ring), 5 to 10 locked (grey with a padlock); level 10 is a bigger node with a crowned green slime boss face. Right: a white info card for the selected level LEVEL 1-4 with lines ROOMS 5 and REWARD with coin 120 and gem 2, and a big gold PLAY button." &
screen end_victory "1920 x 1080 (landscape)" "VICTORY screen over a dimmed arena. Big gold ribbon VICTORY! with light rays and confetti behind it, three gold stars above it. Centre panel: subtitle LEVEL 1-4 COMPLETE; a two-column stat grid with icons: skull ENEMIES 87, hourglass TIME 12:34, heart HEALTH 62%, star BEST COMBO 24; a REWARDS row of tiles: coin +120, gem +3, and a voxel crate tile. Bottom: blue button LOBBY and green button NEXT LEVEL." &
wait
ls -la *.png
