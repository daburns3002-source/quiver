#!/bin/bash
# Area 5, the Windswept Cliffs (2026-11-26): reference pictures for its eight pets
# (docs/WINDSWEPT-CLIFFS.md). Seven model sheets for Claude Design, styled after the
# Briar Lynx's sheet; the Gale Wilf as a recolour of the Glowcap Wilf, for Tripo.
cd "$(dirname "$0")"
STYLE=/c/Dev/ArcheroRoblox/assets/concepts/blocky/pets/thornwood/09_briar_lynx_views.png
GLOWCAP=/c/Dev/ArcheroRoblox/assets/concepts/blocky/pets/bogheart/06_glowcap_wilf_sock.png
WORLD="It lives in the Windswept Cliffs: grey-blue slate cliff tops floating in a sea of white cloud, short bright grass, strings of prayer flags in red, yellow, green and blue, glowing pale-blue wind streaks."
sheet() {
  out=$1; what=$2
  [ -f "$out.png" ] && return
  cat <<E | timeout 900 codex exec -i "$STYLE" --skip-git-repo-check 2>&1 | tail -1
Generate ONE wide 16:9 image at the highest resolution available and save it in the current directory as $out.png

Image 1 is a style and layout reference for our game's pet model sheets: match its blocky voxel style, chunky cube proportions, cute face and finish, and its layout (one big three-quarter view on the left, smaller FRONT, SIDE and BACK views on the right, all the same pose and size, and a small palette row), but NOT its animal or colours. Draw a new pet: $what
$WORLD
Every limb clearly separate from the body, everything attached, nothing floating except what is listed. This sheet will be turned into a 3D model.
Plain flat light-grey background, no scenery, no ground, no shadow, no text, no labels. Even soft lighting.
E
  echo "$out done"
}
sheet 01_whistle_marmot_views "WHISTLE MARMOT (Common): a chunky golden-brown cube marmot standing up on its back legs, a cream belly and muzzle, two small square buck teeth, round little ears, short front paws held together at its chest, a short dark-brown tail, and a little red prayer-flag scarf round its neck." &
sheet 02_cliff_puffin_views "CLIFF PUFFIN (Common): a round chunky black-and-white cube puffin standing on short orange feet, a white face and belly, a black back, cap and short wings, a big tall striped beak in orange, red and yellow, a tiny dark eye with a grey eye-patch." &
sheet 03_woolly_alpaca_views "WOOLLY ALPACA (Uncommon): a fluffy cloud-white cube alpaca standing on four short legs, a long upright neck, a big fluffy tuft of wool on its head, small pointed ears, a cream muzzle, and a woven blanket over its back in prayer-flag stripes of red, yellow, green and blue." &
sheet 04_gale_glider_views "GALE GLIDER (Rare): a pale-grey and sky-blue cube flying squirrel with flat square gliding flaps stretched between its front and back legs, big round dark eyes, small round ears, a cream belly and a flat fluffy tail with a sky-blue tip." &
wait
sheet 05_flagtail_panda_views "FLAGTAIL PANDA (Epic): a ginger-red and cream cube red panda standing on four dark-brown legs, white cheek and ear patches, a long thick ringed tail curling up behind it in ginger and dark-brown rings, and a little string of tiny prayer flags in red, yellow, green and blue round its neck." &
sheet 07_rocling_views "ROCLING (Legendary): a round chunky baby storm bird, heir to the Tempest Roc: navy-blue and cream fluff, a small gold-yellow crest on its head, tiny stubby wings with gold-yellow tips, big yellow eyes, a short dark-grey hooked beak, short gold feet, and two small glowing yellow lightning sparks floating beside it. A soft gold glow outline around it." &
sheet 08_zephyr_whale_views "ZEPHYR WHALE (Mythic): a majestic cube whale floating in the air, the rarest pet of the cliffs: cloud-white back fading to sky-blue below, long pectoral fins spread like wings, a broad fluked tail, glowing pale-cyan rune stripes along its sides, little ribbons of white wind trailing from its tail, and a small cloud halo floating above its head. A soft pale-cyan glow outline around it." &
wait
[ -f 06_gale_wilf_glowcap.png ] || cat <<E | timeout 900 codex exec -i "$GLOWCAP" --skip-git-repo-check 2>&1 | tail -1
Generate ONE square image at the highest resolution available and save it in the current directory as 06_gale_wilf_glowcap.png

Image 1 is our GLOWCAP WILF pet. Draw exactly the same blocky wolf pup: same shape, proportions, pose, view and style, same big head with tall wedge ears, same stepped mask band across the eyes, same spiky cheek ruff and square muzzle, same eyes, same gold collar and gold leaf tag, same chunky body and L-shaped upturned tail, same toe-lined paws, and the same Wilf marking (its FRONT RIGHT leg, on the LEFT of the picture, has a long light sock up to the body; the front left leg only a short light paw). Only recolour it and swap the back decoration, as the GALE WILF:
- the bog-purple fur becomes sky blue (#5AA9F0); the cream parts become cloud white (#F4F8FF);
- the moss-green mask band, ear insides and back-leg feet become: pale cyan (#BDEBFF) mask band and ear insides, cloud-white back feet; the tail tip becomes a pale-cyan wind swirl;
- no moss and no mushrooms: instead two small white stepped feather wings on its back, and brown aviator goggles with pale-cyan lenses pushed up on its forehead;
- eyes blue.
Mouth closed in a small happy smile, no breath puffs.
View: three-quarter front view, straight-on camera height, centred, filling about 85 percent of the image. This image will be turned into a 3D model, so keep everything attached to the body and nothing floating. Plain flat light-grey background, no ground, no shadow, no text, no glow outline around the body. Even soft lighting.
E
ls -la *.png
