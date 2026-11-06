#!/usr/bin/env bash
# Reference sheets for the Drowned Village's twelve pets and the area 3/4
# bosses, drawn through Codex for the owner's approval before anything is
# built (2026-11-05). Layout copies the Thornwood pet sheets (Bark Hoglet).
# Built pets pass their in-game icon so the sheet matches the model 1:1.
cd "$(dirname "$0")" || exit 1
B=../..                                   # assets/concepts/blocky
P=../../../pets                           # assets/concepts/pets
LAYOUT=$B/pets/thornwood/01_bark_hoglet_views.png
AREA=$B/arenas/area03_drowned_village_v2.png
STYLE="Match image 1's visual language and LAYOUT EXACTLY: chunky blocky voxel 3D, flat shading, hard bevelled edges, saturated colours, soft studio light, plain light-grey backdrop. Top-left: the name in bold black capitals and a rounded rarity badge. Top row four views of the SAME model, evenly spaced, labelled exactly FRONT, THREE-QUARTER FRONT, RIGHT SIDE, BACK. Below left: one action pose labelled with the attack name. Below right: a bordered panel labelled IN-GAME SIZE with the pet beside a plain grey blocky Roblox avatar. Bottom right: a row of six flat colour swatches. No other text. Geometry identical across every view; readable from a top-down camera; low part count."

draw() { # out name rarity attack look extra-refs...
  local out=$1 name=$2 rar=$3 atk=$4 look=$5; shift 5
  [ -f "$out" ] && return
  local refs=(-i "$LAYOUT" -i "$AREA") ; local n=3 extra=""
  for r in "$@"; do refs+=(-i "$r"); extra="$extra Image $n is the pet's EXISTING in-game model or art: copy its shape, proportions and colours exactly, the sheet must match it 1:1."; n=$((n+1)); done
  printf 'Generate ONE image, landscape 1672x941, saved in the current directory as %s\n\nImage 1 is the layout and style reference (another pet). Image 2 is the Drowned Village arena: take the palette from it (shallow turquoise, teal, slate blue, plank brown, lantern orange, moss green, foam white).%s\n\n%s\n\nPet: %s, rarity %s. %s Action pose: %s.\n' \
    "$out" "$extra" "$STYLE" "$name" "$rar" "$look" "$atk" \
  | timeout 1200 codex exec "${refs[@]}" --skip-git-repo-check > "${out%.png}.log" 2>&1
  echo "$out: $([ -f "$out" ] && echo ok || echo MISSING)"
}
GLOW_L="It is Legendary: a soft golden aura and a few gold sparkle cubes round it in every view."
GLOW_M="It is Mythic: a rainbow-shifting glow and sheen, a ring of light and orbiting pearl motes in every view."

draw 01_dock_otter_views.png "DOCK OTTER" COMMON "TAIL SLAP" "A plank-brown cube otter with a foam-white muzzle and belly, little square ears, a broad flat paddle tail and oversized mitten paws."
draw 02_reed_duck_views.png "REED DUCK" COMMON "PECK" "A cream cube duckling with a slate-blue back patch, an orange wedge bill, two paddle feet and a short reed-green feather tuft."
draw 03_foam_pup_views.png "FOAM PUP" COMMON "FOAM BARK" "A slate-grey seal pup with a huge foam-white cube face, a dark square nose, two slab flippers and a split wedge tail."
draw 04_slate_turtle_views.png "SLATE TURTLE" UNCOMMON "SLATE SHELTER" "A saturated teal turtle with a low stepped blue-slate shell, four short flippers and one cream rope belt round its shell." $P/drowned/SlateTurtle.png
draw 05_reed_axolotl_views.png "REED AXOLOTL" UNCOMMON "GILL SPLASH" "A pale turquoise cube axolotl with three coral-red gill wedges on each cheek, a slab tail and a moss-green reed scarf."
draw 06_buoy_puffer_views.png "BUOY PUFFER" RARE "SPINE BURST" "A squat orange-and-cream cube pufferfish with blunt slate wedge spines, tiny side fins and one glowing amber square belly patch." $P/drowned/BuoyPuffer.png
draw 07_pearl_pony_views.png "PEARL PONY" RARE "PEARL FLASH" "A teal seahorse with a big cube head, a short box snout, a slate crest, a square-curled tail and one glowing pearl at its throat."
draw 08_mist_heron_views.png "MIST HERON" EPIC "MIST STAB" "A foam-white box heron with a slate slab-wing cape, short sturdy legs, a long orange wedge bill and glowing turquoise feather markings."
draw 09_inkpot_views.png "INKPOT" EPIC "INK SQUIRT" "A deep slate-blue cube octopus with eight short thick slab arms, cream sucker squares and glowing teal ink-drop markings." $P/drowned/Inkpot.png
draw 10_tide_wilf_views.png "TIDE WILF" LEGENDARY "TIDE SLASH" "The Wilf family shape in sea teal and foam white, fin-shaped ears and tail slabs, a slate sailor neckerchief and a gold anchor tag. $GLOW_L" $P/drowned/TideWilf.png $P/wilfs/03_tide_wilf.png
draw 11_toll_prince_views.png "TOLL PRINCE" LEGENDARY "BELL TOLL" "A cute coral-red baby crab with cream mitten claws, teal square eye stalks and ONE oversized teal bell shell with gold bands; a tiny gold crown, moss tabs and two cream flowers. Heir to the Old Tollcrab boss. $GLOW_L"
draw 12_abyss_jelly_views.png "ABYSS JELLY" MYTHIC "TENTACLE STING" "A floating abyss-blue cube jellyfish with a pearl face panel, four broad stepped ribbon arms and four shorter tentacle slabs, teal luminous seams. Ribbons broad and few, never thin strands. $GLOW_M" $P/drowned/AbyssJelly.png

# Bosses: layout from the King Bloblin views sheet; identity from each boss's concept.
boss() { # out name concept arena look
  [ -f "$B/$1" ] && return
  printf 'Generate ONE image, landscape 1672x941, saved as %s\n\nImage 1 is the LAYOUT and style reference (another boss views sheet): copy its layout, labels style, backdrop and lighting exactly. Image 2 is THIS boss'"'"'s approved concept: copy its identity, shape and colours exactly. Image 3 is its arena, for palette only.\n\nChunky blocky voxel 3D, flat shading, hard bevelled edges, plain light-grey backdrop. Top row four views of the SAME model labelled exactly FRONT, THREE-QUARTER FRONT, RIGHT SIDE, BACK. Below: a bordered panel labelled IN-GAME SIZE with the boss beside a plain grey blocky Roblox avatar, and a row of six flat colour swatches. Title top-left in bold black capitals: %s. No other text. Geometry identical across views, readable from a top-down camera, no background scenery.\n\nBoss: %s\n' "$1" "$2" "$2" "$5" \
  | timeout 1200 codex exec -i $B/boss01_king_bloblin_views.png -i "$B/$3" -i "$B/arenas/$4" -C "$B" --skip-git-repo-check > "$B/${1%.png}.log" 2>&1
  echo "$1: $([ -f "$B/$1" ] && echo ok || echo MISSING)"
}
boss boss05_old_tollcrab_views.png "OLD TOLLCRAB" boss05_old_tollcrab.jpg area03_drowned_village_v2.png "A huge coral-red hermit crab with cream mitten claws, teal eye stalks, wearing ONE enormous teal bell as its shell with gold bands and a gold emblem, draped with moss and cream flowers."
boss boss06_grandmother_gulp_views.png "GRANDMOTHER GULP" boss06_grandmother_gulp.jpg area04_bogheart_caverns_v2.png "An enormous warty toad with glowing fungus growing on her back, as in image 2."
