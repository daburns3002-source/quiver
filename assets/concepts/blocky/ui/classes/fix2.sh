#!/usr/bin/env bash
# Second pass on the class select mockup (owner, 2026-11-06, on class_select5:
# "now they are smaller than the others, dont make them smaller", and "also fix
# the bow in the female rangers hand"). Starts again from the approved
# class_select4.png; the gold borders must not move (tools/class_select/recut.py).
cd "$(dirname "$0")" || exit 1
cat <<E | timeout 1500 codex exec -i class_select4.png --skip-git-repo-check > fix2.log 2>&1
Edit the attached image and save the result in the current directory as class_select6.png, exactly 1920 pixels wide and 1080 tall.

Keep EVERYTHING exactly as it is - same size, same art, same colours, every thick slanted gold border in exactly the same place and angle, the title plate and the four name plates unchanged, and the four middle characters (the two arcanists and the two wardens) unchanged. Change only these four characters, and keep each of them THE SAME SIZE as the other characters (same height from head to feet, same head size - do NOT shrink them):

1. Section 1, far left (the male ranger, green hood, wooden bow). Right now his bow and back stick out past the thin slanted gold border on the left of his section. Re-pose and move him so ALL of him - bow, arms, body, boots - is inside his own section, between its two gold borders, at the same size as now. For example, have him hold the bow upright and close in front of him instead of drawing it out to the side. Fill the area outside him with the same forest background.
2. Section 2 (the female ranger with the braid): keep her exactly as she is, except fix her bow: draw it as one whole, correctly shaped wooden recurve bow with its string, held properly by its grip in her hand.
3. Section 7 (the male assassin black silhouette with two daggers and a gold padlock): same size as now, moved/re-posed so the whole silhouette including both daggers is inside its own section and does not cross the gold border into section 8.
4. Section 8, far right (the female assassin silhouette with ponytail, daggers and padlock): same size as now, moved/re-posed so the whole silhouette is inside its own section and nothing is cut off by the right edge of the picture.
Fill any freed space with that section's own backdrop (forest for 1 and 2, dark grey castle for 7 and 8).
E
ls -la class_select6.png 2>/dev/null
