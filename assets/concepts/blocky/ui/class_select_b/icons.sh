#!/usr/bin/env bash
# The small icons of the class select mock-up: the three stat icons, the BOY
# and GIRL faces of the switch, and the padlock, on flat magenta for cut.py.
cd "$(dirname "$0")" || exit 1
[ -f icons.png ] && exit 0
cat <<E | timeout 1200 codex exec -i class_select_B_boy.png --skip-git-repo-check > icons.log 2>&1
Generate ONE landscape image, exactly 1536 pixels wide and 1024 tall, and save it in the current directory as icons.png

A sheet of six game UI icons copied from the attached CHOOSE YOUR CLASS screen, in exactly its style (bold, flat, chunky, a thick dark navy #17405C outline), on a perfectly flat solid magenta background (#FF00FF, every background pixel exactly that colour, no shadow, no glow, no words, no grid lines).
Six cells in a 3 by 2 grid, each 512 by 512 pixels, one icon centred in each cell, each icon about 380 pixels across, well apart from the others:
Top row: 1. the RANGE icon, a round red and white target with a red bullseye. 2. the POWER icon, a spiky orange and yellow explosion burst with a red centre. 3. the SPEED icon, a yellow lightning bolt.
Bottom row: 4. the BOY icon of the switch, a simple round smiling boy's face with short dark navy hair, pale skin. 5. the GIRL icon of the switch, a simple round smiling girl's face with long dark navy hair falling to each side, pale skin. 6. the padlock, a chunky sunny yellow padlock with a dark keyhole, as on the Assassin card.
Keep magenta out of the icons themselves.
E
ls -la icons.png
