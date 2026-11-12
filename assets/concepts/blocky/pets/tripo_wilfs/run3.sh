#!/bin/bash
# The Ember and Bramble Wilf as recolours of the Glowcap Wilf, for Tripo (owner, 2026-11-11:
# "these need to look like the glowcap wilf").
cd "$(dirname "$0")"
REF=../bogheart/06_glowcap_wilf_sock.png
one() {
  out=$1; what=$2; colours=$3
  [ -f "$out.png" ] && return
  cat <<E | timeout 600 codex exec -i "$REF" --skip-git-repo-check 2>&1 | tail -1
Generate ONE square image at the highest resolution available and save it in the current directory as $out.png

Image 1 is our GLOWCAP WILF pet. Draw exactly the same blocky wolf pup: same shape, proportions, pose, view and style, same big head with tall wedge ears, same stepped mask band across the eyes, same spiky cheek ruff and square muzzle, same eyes, same gold collar and gold leaf tag, same chunky body and L-shaped upturned tail, same toe-lined paws, and the same Wilf marking (its FRONT RIGHT leg, on the LEFT of the picture, has a long light sock up to the body; the front left leg only a short light paw). Only recolour it and swap the back decoration, as the $what:
$colours
Mouth closed in a small happy smile, no breath puffs.
View: three-quarter front view, straight-on camera height, centred, filling about 85 percent of the image. This image will be turned into a 3D model, so keep everything attached to the body and nothing floating. Plain flat light-grey background, no ground, no shadow, no text, no glow outline around the body. Even soft lighting.
E
  echo "$out done"
}
one bramble_wilf_glowcap "BRAMBLE WILF" "- the bog-purple fur becomes ashy grey-brown (#76675F); the cream parts stay ivory (#F3E6CB);
- the moss-green mask band, ear insides, back-leg feet and tail tip become: mauve (#B38AAB) mask band and ear insides, ivory back feet, pale lilac (#D7BCEB) tail tip;
- no moss and no mushrooms: instead a ridge of blunt purple crystal thorns (#8246A6) down the neck and back, glowing softly, and a small purple crystal tuft on top of the head;
- eyes purple." &
one ember_wilf_glowcap "EMBER WILF" "- the bog-purple fur becomes ginger orange with a slightly darker rust back; the cream parts stay cream;
- the moss-green mask band becomes a lighter orange band; the ear insides and the tail tip become glowing yellow-orange like embers; the back-leg feet become cream;
- no moss and no mushrooms: a plain orange back;
- eyes amber-orange, nose brown." &
wait
python -c "
from PIL import Image
s=Image.new('RGB',(1500,500))
for i,f in enumerate(['../bogheart/06_glowcap_wilf_sock.png','bramble_wilf_glowcap.png','ember_wilf_glowcap.png']):
    s.paste(Image.open(f).convert('RGB').resize((500,500)),(i*500,0))
s.save('_contact3.png')
"
