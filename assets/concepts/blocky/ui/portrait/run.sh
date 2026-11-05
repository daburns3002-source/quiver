#!/usr/bin/env bash
# Portrait versions of the class select and the four enemy spotlight loading
# screens, for phones held upright (owner, 2026-11-05: "there also needs to be
# vertical screens for the character select, and the loading screens. make
# the character select screen the classes on top of eachother instead of next
# to eachother horizontally. make new loading screens for mobile").
# Each is redrawn by Codex from the landscape one, in parallel.
cd "$(dirname "$0")" || exit 1

class() {
  [ -f class_select_portrait.png ] && return
  cat <<E | timeout 900 codex exec -i class_select_reference.png --skip-git-repo-check > class.log 2>&1
Generate ONE image, portrait, exactly 1080 pixels wide and 1920 tall, and save it in the current directory as class_select_portrait.png

It is the phone (upright) version of the attached "CHOOSE YOUR CLASS" screen, in exactly the same art style: chunky blocky voxel characters, painted backgrounds, thick gold borders and gold-framed plaques.

Layout, top to bottom:
1. The gold "CHOOSE YOUR CLASS" banner across the top, about 170 pixels tall.
2. Below it, FOUR horizontal bands stacked on top of each other, filling the rest of the height down to about 1700 pixels, each the full width, separated by thick gold borders:
   - Band 1 RANGER: green forest background; on the left half the male ranger (hooded, bow), on the right half the female ranger.
   - Band 2 ARCANIST: blue magical background; left the male arcanist (staff, beard), right the female arcanist (witch hat).
   - Band 3 WARDEN: red castle background; left the male warden (armour, greatsword), right the female warden.
   - Band 4 ASSASSIN: grey dark background; left and right two black silhouettes, each with a gold padlock on it.
   Each band is split down its exact middle by a thin vertical gold border, so it reads as two panels: male left, female right. Characters shown from the waist or chest up so they fit the band.
   Each band has its class name on a gold-framed dark plaque, centred at the bottom edge of the band, exactly as the attached image's plaques: RANGER, ARCANIST, WARDEN, ASSASSIN. Spell them exactly.
3. The bottom 220 pixels are a plain dark area with nothing in it (a button will be placed there).
No other text anywhere.
E
}

spot() {
  local n="$1"
  [ -f "portrait_$n.png" ] && return
  cat <<E | timeout 900 codex exec -i "../loading/spotlight/loading_$n.png" --skip-git-repo-check > "$n.log" 2>&1
Generate ONE image, portrait, exactly 941 pixels wide and 1672 tall, and save it in the current directory as portrait_$n.png

It is the phone (upright) version of the attached loading screen, in exactly the same art style, the same enemy, the same background scenery, the same light and colours. Recompose it for a tall screen:
1. The small gold ARROWBORNE logo with its little ornament at the top, centred, about 80 pixels from the top. Spell it exactly: ARROWBORNE.
2. Below it the same small spaced "ENEMY SPOTLIGHT" line, then the enemy's name as the same big white blocky title, then the same short description line under it, all centred, in the top third. Use exactly the same words as the attached image.
3. The enemy large in the middle of the picture, on its mossy rock, with the scenery behind and around it filling the height.
4. Near the bottom: the same "LOADING..." word, left aligned at about 60 pixels from the left, and under it a loading bar trough the full width less 60 pixels each side, shown completely empty, a dark trough with no fill, about 13 pixels tall, at about 1480 pixels from the top.
5. Below the bar, about 130 pixels of dark background with nothing in it (a tip line will be placed there).
No other text anywhere.
E
}

class &
for n in baby_slime brood_slime moss_slime splitter_spitter; do spot "$n" & done
wait
ls -la *.png
