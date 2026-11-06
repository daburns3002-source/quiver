#!/usr/bin/env bash
# The class select mockup (class_select4.png) with three figures moved fully
# inside their own slanted sections (owner, 2026-11-06: "in the character
# select screen make sure the male ranger and the male and female assassin are
# in their sections"). Codex edits the approved mockup; the gold borders must
# not move, because the section pieces are cut along them
# (tools/class_select/recut.py).
cd "$(dirname "$0")" || exit 1
cat <<E | timeout 1200 codex exec -i class_select4.png --skip-git-repo-check > fix.log 2>&1
Edit the attached image and save the result in the current directory as class_select5.png, exactly 1920 pixels wide and 1080 tall.

Keep EVERYTHING exactly as it is - same size, same art, same colours, and above all every thick slanted gold border in exactly the same place and angle, the title plate and the four name plates unchanged, and the six middle characters unchanged. Change only three characters:

1. The first section on the far left (left of the first slanted gold border inside the picture, the male ranger's section, bounded on its left by the thin slanted gold border near the left edge): redraw the male ranger (green hood, wooden bow) smaller and further right so ALL of him, including his bow and his whole body, is inside that section, between its two gold borders, with a little forest background around him. Nothing of him may cross either border. Paint plain forest background where he used to cross the left border.
2. The seventh section (the male assassin, black silhouette with a gold padlock): redraw that silhouette (same hooded rogue, same two daggers, same padlock) smaller and shifted so the whole silhouette including both daggers is inside its own section and does not cross the gold border into the eighth section.
3. The eighth section on the far right (the female assassin silhouette with ponytail, daggers and padlock): redraw it smaller and further left so the whole silhouette is inside its own section, between its two gold borders, and nothing touches the right edge of the picture.
Fill any freed space with the same backdrop as that section (forest green for 1, dark grey castle for 7 and 8).
E
ls -la class_select5.png 2>/dev/null
