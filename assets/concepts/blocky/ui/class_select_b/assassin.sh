#!/usr/bin/env bash
# The Assassin's card portraits for class select (2026-11-15, the class
# opening): the hooded figure of the blacked-out card, now in colour, one for
# each look, drawn to sit beside the other three heroes. cut.py keys them out.
cd "$(dirname "$0")" || exit 1

# hero <name> <mock-up> <style portrait> <who>
hero() {
  local name="$1" ref="$2" style="$3" who="$4"
  [ -f "portrait_$name.png" ] && return
  cat <<E | timeout 1200 codex exec -i "$ref" -i "$style" -i portrait_assassin.png --skip-git-repo-check > "$name.log" 2>&1
Generate ONE square image, exactly 1024 by 1024 pixels, and save it in the current directory as portrait_$name.png

It is a game UI portrait for the ASSASSIN card of the first attached image (a CHOOSE YOUR CLASS screen), where the Assassin is still a blacked-out silhouette. Draw that same figure now revealed in full colour: $who, alone, cut out, on a perfectly flat solid magenta background (#FF00FF, every background pixel exactly that colour, no gradient, no shadow, no glow, no medallion, no circle, no frame, no words).
The Assassin keeps the silhouette's shape (the third attached image): a slim pointed HOOD up over the head, a cloth MASK over the mouth and nose so only the eyes show, and two short DAGGERS crossed behind the shoulders with their handles standing up past each shoulder. Colours: a deep violet hood and tunic with darker indigo trim, a lighter lilac scarf at the neck, charcoal shoulder pads, the dagger handles wrapped in violet cloth with pale steel pommels. Bright friendly determined eyes, a kids' game hero, not scary.
Copy EXACTLY the drawing style of the second attached image (another hero's portrait from the same screen): the same blocky voxel Roblox-avatar look, the same head size and framing, the same thin dark outline and flat clean shading. Head and shoulders down to mid-chest, facing the viewer a little turned; the head is near the middle, the hero fills most of the width, and the bottom edge of the picture cuts across the chest. Keep magenta and hot pink out of the hero itself.
E
  ls -la "portrait_$name.png"
}

hero assassin_male class_select_B_boy_v2.png portrait_ranger_male.png "a BOY assassin, a little dark hair showing under the hood" &
hero assassin_female class_select_B_girl.png portrait_ranger_female.png "a GIRL assassin, a long dark braid falling out of the hood over one shoulder" &
wait
