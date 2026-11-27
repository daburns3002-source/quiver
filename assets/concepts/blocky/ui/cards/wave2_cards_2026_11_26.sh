#!/usr/bin/env bash
# Wave 2's last five class cards (docs/CLASS-CARDS.md, owner 2026-11-26 "As written (B)"):
# one Codex redraw each on flat magenta, in the set's style, the October icon as the idea.
# Then: python -I assets/ui/glow_toy_cards/compose_icon.py <icon> <rarity>
cd "$(dirname "$0")" || exit 1
REFS="-i ../../../../ui/glow_toy_cards/icons_transparent/counterstrike.png -i ../../../../ui/glow_toy_cards/icons_transparent/rainofarrows.png"
one() {
	name="$1"; old="$2"
	[ -f "${name}_raw.png" ] && return 0
	{ cat "${name}.prompt.txt"; printf '\n\nSave the image in the current directory as %s_raw.png\n' "$name"; } \
		| timeout 900 codex exec $REFS -i "../../../icons/${old}.png" --skip-git-repo-check > "${name}.log" 2>&1
	ls -la "${name}_raw.png"
}
export -f one
export REFS
printf '%s\n' "echoslash echo-slash" "riposte riposte" "splitorb split-orb" "gravitywell gravity-well" "orbitingorb orbiting-orb" \
	| xargs -P 3 -L1 bash -c 'one "$0" "$1"'
