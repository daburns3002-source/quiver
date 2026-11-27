#!/usr/bin/env bash
# The nine class cards of 2026-11-13 (owner's pick C, docs/CLASS-CARDS.md): one
# Codex redraw each on flat magenta, in the set's style, the prompt beside it.
# Then: python -I assets/ui/glow_toy_cards/compose_icon.py <icon> <rarity>
cd "$(dirname "$0")" || exit 1
REFS="-i ../../../../ui/glow_toy_cards/icons_transparent/counterstrike.png -i ../../../../ui/glow_toy_cards/icons_transparent/rainofarrows.png"
one() {
	name="$1"
	[ -f "${name}_raw.png" ] && return 0
	{ cat "${name}.prompt.txt"; printf '\n\nSave the image in the current directory as %s_raw.png\n' "$name"; } \
		| timeout 900 codex exec $REFS --skip-git-repo-check > "${name}.log" 2>&1
	ls -la "${name}_raw.png"
}
export -f one
export REFS
printf '%s\n' snipershot splitshot windarrows manasurge frostorb arcaneshield shieldthrow bladestorm sunder \
	| xargs -P 3 -I{} bash -c 'one {}'
