#!/bin/bash
# Area 5, the Windswept Cliffs (2026-11-26): its NEW ENEMY! sheet, the sheet emptied, and
# the four enemies' pictures. Prompts follow p_bogheart.txt, p_blank_bog.txt and enemies/p_*.txt.
cd "$(dirname "$0")"
ACT3=../../enemies/act3
AREA=../../arenas/area05_windswept_cliffs.jpg
run() { out=$1; shift; [ -f "$out" ] && return; timeout 900 codex exec "$@" --skip-git-repo-check < "${out%.png}.prompt" 2>&1 | tail -1; }

sed -e 's/^AREA: .*/AREA: "WINDSWEPT CLIFFS" - grey-blue slate cliff tops floating in a sea of white cloud, short bright grass on the rims, glowing pale-blue wind streaks across the stone, rope and plank bridges, strings of bright prayer flags (red, yellow, green, blue) on stone posts. The banner is slate stone and weathered wood, with prayer flags and little tufts of grass on and hanging from it, white wind swirls curling round its tails; the frame is grey-blue slate with grass and small prayer flags. Second reference image: the Windswept Cliffs area./' \
    -e 's/^ENEMY: .*/ENEMY: the Harpy - third reference image (its model sheet): a navy-indigo voxel owl-bird with a lavender chest, a bone-white owl-skull mask with a short hooked beak and glowing pale-blue eyes, a spiky purple-magenta crest, huge spread wings fading indigo to purple to magenta-pink, short brown legs. Draw it faithfully, in the blocky style, hovering./' \
    -e 's/^ENEMY NAME: .*/ENEMY NAME: "HARPY"/' \
    -e 's/^DESCRIPTION: .*/DESCRIPTION: "Flies over walls and dives where it marks the ground. Step out of the ring!"/' \
    -e 's/sheet_bogheart_caverns_a.png/sheet_windswept_cliffs_a.png/' p_bogheart.txt > sheet_windswept_cliffs_a.prompt
run sheet_windswept_cliffs_a.png -i ../end_victory.jpg -i "$AREA" -i $ACT3/harpy.jpg
sed 's/blank_bogheart_caverns_raw.png/blank_windswept_cliffs_raw.png/' p_blank_bog.txt > blank_windswept_cliffs_raw.prompt
run blank_windswept_cliffs_raw.png -i sheet_windswept_cliffs_a.png &

one() {
  name=$1; ref=$2; bg=$3; what=$4
  base=$( [ "$bg" = blue ] && echo enemies/p_common_blue.txt || echo enemies/p_common.txt )
  { sed '/^Creature:/,$d' "$base"; echo "Creature: $what"; echo "Save the image in the current directory as ${name}_raw.png"; } > "enemies/${name}_raw.prompt"
  (cd enemies && [ -f "${name}_raw.png" ] || timeout 900 codex exec -i ../sheet_bogheart_caverns_a.png -i "../$ref" --skip-git-repo-check < "${name}_raw.prompt" 2>&1 | tail -1)
}
one harpy $ACT3/harpy.jpg blue "the Harpy - see its model sheet: a navy-indigo owl-bird with a lavender chest, a bone-white owl-skull mask, glowing pale-blue eyes, a spiky purple-magenta crest, huge spread wings fading indigo to purple to magenta-pink, short brown legs; hovering." &
one gust_shaman $ACT3/gust_shaman.jpg magenta "the Gust Shaman - see its model sheet: a small hooded sheep-folk caster in a deep teal robe with pale teal swirls over a cream inner robe, big dark-brown ram horns curling out of the hood, a cream sheep face with glowing pale-blue eyes, a bead necklace, holding a tall brown crook topped by a glowing pale-blue wind spiral." &
one cliff_goat $ACT3/cliff_goat.jpg magenta "the Cliff Goat - see its model sheet: a stocky cream-white woolly mountain goat with huge curled dark-brown horns, pink-lined ears, glowing pale-blue eyes and dark-brown hooves, head lowered ready to charge." &
one storm_roc $ACT3/storm_roc.jpg magenta "the Storm Roc - see its model sheet: a big steel-blue storm bird with a pale icy-white head and chest, a dark-grey hooked beak, glowing pale-blue eyes, wings raised wide with glowing pale-blue lightning along their edges." &
wait
ls -la sheet_windswept_cliffs_a.png blank_windswept_cliffs_raw.png enemies/{harpy,gust_shaman,cliff_goat,storm_roc}_raw.png
