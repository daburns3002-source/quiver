#!/usr/bin/env bash
# The game was renamed Arrowborne on 2026-11-04, and the four spotlights still
# carried the old name. Each is redrawn from itself by Codex with only the logo
# changed, and the bar and tip emptied so the live ones can sit in their place.
cd "$(dirname "$0")" || exit 1
for n in baby_slime brood_slime moss_slime splitter_spitter; do
  [ -f "new_$n.png" ] && continue
  cat <<E | timeout 500 codex exec -i "loading_$n.png" --skip-git-repo-check 2>&1 | tail -1
Generate ONE image at the highest resolution available, with exactly the same 1672x941 framing as the attached image, and save it in the current directory as new_$n.png

Reproduce the attached loading screen exactly: same art, same enemy, same background, same title, same description line, same LOADING... word, same positions, colours and light. Change only these three things:
1. The small gold logo at the top left reads ARCHER LEGENDS. Replace those words with ARROWBORNE in the same small gold lettering, at the same place and size, keeping its little ornament below. Spell it exactly: ARROWBORNE.
2. The loading bar near the bottom: keep its full length and height, but show it completely empty, a dark trough with no green fill at all.
3. Remove the line of text under the bar that begins TIP: entirely, leaving the same dark background there.
No other changes and no other words.
E
  echo "=== $n $(date +%T)"
done
ls -la new_*.png
