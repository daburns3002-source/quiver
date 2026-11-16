#!/usr/bin/env bash
# The Assassin's ten cards (2026-11-15, docs/CLASS-CARDS.md): one Codex draw
# each on flat magenta, in the set's style, the prompt beside it
# (assassin_cards_prompts.py writes the prompts).
# Then: python -I assets/ui/glow_toy_cards/compose_icon.py <icon> <rarity>
cd "$(dirname "$0")" || exit 1
REFS="-i ../../../../ui/glow_toy_cards/icons_transparent/counterstrike.png -i ../../../../ui/glow_toy_cards/icons_transparent/bladestorm.png"
one() {
	name="$1"
	[ -f "${name}_raw.png" ] && return 0
	{ cat "${name}.prompt.txt"; printf '\n\nSave the image in the current directory as %s_raw.png\n' "$name"; } \
		| timeout 900 codex exec $REFS --skip-git-repo-check > "${name}.log" 2>&1
	ls -la "${name}_raw.png"
}
export -f one
export REFS
printf '%s\n' twinfangs backstab quickstep serratededge bleed poisontrail fanofknives deathmark phantomblades thousandcuts \
	| xargs -P 3 -I{} bash -c 'one {}'
