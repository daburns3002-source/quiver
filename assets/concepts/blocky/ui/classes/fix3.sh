#!/usr/bin/env bash
# Third pass, the two Assassins only: class_select6.png bent the gold border
# between sections 7 and 8 to make room. Upright full-size figures cannot fit
# the slanted sections, so they lean with the slant instead.
cd "$(dirname "$0")" || exit 1
cat <<E | timeout 1500 codex exec -i class_select6.png -i class_select4.png --skip-git-repo-check > fix3.log 2>&1
Edit the FIRST attached image and save the result in the current directory as class_select7.png, exactly 1920 pixels wide and 1080 tall.

Change ONLY the two right-most sections (the two black assassin silhouettes with gold padlocks). Everything else stays exactly as in the first image, pixel for pixel.

1. The gold border between the male assassin (section 7) and the female assassin (section 8) is bent in the first image. Redraw it as ONE perfectly straight slanted gold border, in exactly the place and angle it has in the SECOND attached image (the original), parallel to all the other borders.
2. Redraw both silhouettes at the SAME SIZE as the other characters (same height and head size as in the second image - do NOT shrink them), each in a dynamic pose leaning forward along the slant of the borders - for example a crouched, sneaking, leaning-forward stance with daggers drawn - so that each whole silhouette, daggers included, is completely inside its own slanted section and crosses no border, and the female is not cut off by the right edge of the picture. Same pure black silhouettes, same daggers, same big gold padlock on each.
3. Fill the rest of both sections with their dark grey castle backdrop.
E
ls -la class_select7.png 2>/dev/null
