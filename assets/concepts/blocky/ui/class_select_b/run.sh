#!/usr/bin/env bash
# Class select "option B" (owner, 2026-11-13: "I LIKE B BUT MAKE SURE THERE IS
# A CHOICE IN THERE TO SWITCH GENDER AND ALSO MAKE SURE THE ASSASSIN CLASS IS
# VISIBLE BUT BLACKE DOUT", then "YES THIS IS GOOD, MAKE THE SWORD A LITTLE
# BIGGER AND MAKE THE ASSASSIN MORE NOTICEABLE").
# 1. The boy mock-up redrawn with those two changes.
# 2. The card portraits, one per class and gender, plus the Assassin, each a
#    clean cut-out on a flat key colour; cut.py keys them out.
# Every job runs in parallel; a finished picture is never drawn again.
cd "$(dirname "$0")" || exit 1

mockup() {
  [ -f class_select_B_boy_v2.png ] && return
  cat <<E | timeout 1200 codex exec -i class_select_B_boy.png -i warden_male.png --skip-git-repo-check > mockup.log 2>&1
Generate ONE landscape image, exactly 1672 pixels wide and 941 tall, and save it in the current directory as class_select_B_boy_v2.png

Redraw the FIRST attached image (a CHOOSE YOUR CLASS screen of a Roblox game) with exactly the same layout, colours, words, rounded letters, cards, stat bars, BOY / GIRL switch, Ranger selected outline and CHOOSE button, changing only these two things:
1. WARDEN'S SWORD A LITTLE BIGGER: in the Warden card's red medallion the Warden holds the same silver sword with its gold cross-guard and red gem, but the blade is longer and wider (about a third bigger), still standing up beside his head and still entirely inside the round medallion. The second attached image is the Warden's reference sheet.
2. ASSASSIN MORE NOTICEABLE, STILL BLACKED OUT: the hooded assassin silhouette (hood, mask, two crossed daggers behind the shoulders) is drawn bigger, filling the grey medallion like the other three portraits fill theirs, as a solid near-black (#1B2630) shape with no inner detail, and it has a bright violet (#B58CFF) rim-light outline glowing all around its edge, so it stands out against the grey. The yellow padlock stays in front at the bottom. The Assassin card is NOT dimmed: drawn as bright and clean as the other cards; its tag, NOT HERE YET and the empty stat troughs stay.
Spell every word exactly as in the first image; no extra words. Clean, flat, crisp game UI, not painterly.
E
}

# portrait <name> <mock-up> <sheet> <class words>
portrait() {
  local name="$1" ref="$2" sheet="$3" words="$4"
  [ -f "portrait_$name.png" ] && return
  cat <<E | timeout 1200 codex exec -i "$ref" -i "$sheet" --skip-git-repo-check > "$name.log" 2>&1
Generate ONE square image, exactly 1024 by 1024 pixels, and save it in the current directory as portrait_$name.png

It is a game UI portrait: the hero from the first attached image's round medallion, alone, cut out, on a perfectly flat solid magenta background (#FF00FF, every background pixel exactly that colour, no gradient, no shadow, no glow, no medallion, no circle, no frame, no words).
$words
Draw the hero head and shoulders down to mid-chest, facing the viewer a little turned, exactly as in the first attached image's medallion: the same pose, outfit, colours, hair, face and blocky voxel Roblox-avatar style, and match the second attached image (the hero's reference sheet) for every detail. The head is near the middle, the hero fills most of the width, and the bottom edge of the picture cuts across the chest. Crisp clean edges with a thin dark outline; keep magenta out of the hero itself.
E
}

assassin() {
  [ -f portrait_assassin.png ] && return
  cat <<E | timeout 1200 codex exec -i class_select_B_boy.png --skip-git-repo-check > assassin.log 2>&1
Generate ONE square image, exactly 1024 by 1024 pixels, and save it in the current directory as portrait_assassin.png

It is a game UI portrait: the hooded assassin from the Assassin card of the attached CHOOSE YOUR CLASS screen, alone, on a perfectly flat solid pure green background (#00FF00, every background pixel exactly that colour, no gradient, no medallion, no circle, no padlock, no words).
The assassin is a blacked-out silhouette, head and shoulders down to mid-chest, facing the viewer: a slim pointed hood, a mask over the mouth, and two short daggers crossed behind the shoulders with their handles sticking up past each shoulder. The whole figure, daggers included, is one solid near-black shape (#1B2630) with no inner detail at all. Around its whole outer edge runs a bright violet rim-light: a crisp solid violet (#B58CFF) outline about 14 pixels thick hugging the silhouette, with a soft violet glow about 20 pixels wide fading out from it into the green. The figure is big, filling most of the width, the hood's tip near the top, and the bottom edge of the picture cuts across the chest. Blocky voxel Roblox-avatar style shape.
E
}

B=class_select_B_boy.png
G=class_select_B_girl.png
mockup &
portrait ranger_male "$B" ranger_male.png "The hero is the RANGER, the man (the green card's portrait): green leaf hood with small antlers, bow in hand, quiver of arrows on the back." &
portrait arcanist_male "$B" arcanist_male.png "The hero is the ARCANIST, the man (the blue card's portrait): tall blue wizard hat with a twig and leaf, holding his gold crystal staff, blue robe." &
portrait warden_male "$B" warden_male.png "The hero is the WARDEN, the man (the red card's portrait): helmet with red plume and gold crest, orange armour and shield, holding a silver sword upright beside his head, with a gold cross-guard and red gem. Make the sword a little bigger than in the first image: the blade longer and wider, about a third bigger, its tip near the top edge, fully inside the picture." &
portrait ranger_female "$G" ranger_female.png "The hero is the RANGER, the woman (the green card's portrait): green leaf hood with small antlers, bow in hand, quiver of arrows on the back." &
portrait arcanist_female "$G" arcanist_female.png "The hero is the ARCANIST, the woman (the blue card's portrait): tall blue witch hat, holding her gold crystal staff, blue robe." &
portrait warden_female "$G" warden_female.png "The hero is the WARDEN, the woman (the red card's portrait): helmet with red plume and gold crest, orange armour, holding a silver sword upright beside her head, with a gold cross-guard and red gem. Make the sword a little bigger than in the first image: the blade longer and wider, about a third bigger, its tip near the top edge, fully inside the picture." &
assassin &
wait
ls -la *.png
