#!/usr/bin/env bash
# Draw an upgrade card's icon with Codex and put it on its rarity tile:
#
#   tools/card_icons.sh                # every card listed below that has no raw yet
#   tools/card_icons.sh thornfall      # just this one
#
# One Codex image generation per card (CLAUDE.md rule 9: images are Codex's).
# Each card's prompt is assets/concepts/blocky/ui/cards/<icon>.prompt.txt, and
# three icons from the live set go along as -i style references, which is what
# keeps a new icon in the Glow Toy style.
#
# **Resumable on purpose.** Eleven generations is enough to run a ChatGPT
# account out of usage part-way, so a card whose <icon>_raw.png already exists
# is skipped: run it again when usage comes back and it carries on where it
# stopped. It never overwrites a raw that is already there.
#
# Codex's sandbox cannot write into the worktree, so its image lands in
# ~/.codex/generated_images/<id>/exec-*.png and is copied back here
# (docs/PIPELINES.md). Uploading is the separate step after this one: serve
# assets/ui/glow_toy_cards/icons/ over localhost and call the Studio MCP's
# upload_image, then put the ids in Config/CardAssets.
set -uo pipefail
cd "$(dirname "$0")/.."

CARDS="windrunner:rare thornfall:epic headhunter:legendary ghostquiver:legendary
twinelements:epic timedilation:legendary prismaticburst:legendary
guardbreak:uncommon bullrush:rare bloodpact:epic vengefulspirit:legendary"

RAW="assets/concepts/blocky/ui/cards"
SET="assets/ui/glow_toy_cards/icons_transparent"
REFS="-i $SET/multishot.png -i $SET/blast.png -i $SET/execute.png"

only="${1:-}"
made=0; skipped=0; failed=0

for entry in $CARDS; do
	icon="${entry%%:*}"; rarity="${entry##*:}"
	if [ -n "$only" ] && [ "$only" != "$icon" ]; then continue; fi
	if [ -f "$RAW/${icon}_raw.png" ]; then
		echo "== $icon: raw already drawn, skipping"
		skipped=$((skipped + 1))
		continue
	fi
	prompt="$RAW/$icon.prompt.txt"
	if [ ! -f "$prompt" ]; then
		echo "== $icon: no prompt at $prompt"; failed=$((failed + 1)); continue
	fi

	echo "== $icon ($rarity): asking Codex"
	log=$(mktemp)
	# shellcheck disable=SC2086
	if ! timeout 600 codex exec $REFS -- "$(cat "$prompt")" >"$log" 2>&1; then
		echo "   codex failed:"; tail -4 "$log"; rm -f "$log"
		failed=$((failed + 1)); continue
	fi
	# the log names the file it wrote; fall back to the newest generated image
	png=$(grep -oE "[A-Za-z]:[\/][^ \"']*exec-[^ \"']*\.png|/[^ \"']*exec-[^ \"']*\.png" "$log" | tail -1)
	if [ -z "$png" ] || [ ! -f "$png" ]; then
		png=$(find "$HOME/.codex/generated_images" -name 'exec-*.png' -newermt '-15 minutes' 2>/dev/null \
			| xargs -r ls -t 2>/dev/null | head -1)
	fi
	if [ -z "$png" ] || [ ! -f "$png" ]; then
		echo "   no image found; the log's tail was:"; tail -4 "$log"; rm -f "$log"
		failed=$((failed + 1)); continue
	fi
	rm -f "$log"
	cp "$png" "$RAW/${icon}_raw.png"
	if python -I assets/ui/glow_toy_cards/compose_icon.py "$icon" "$rarity"; then
		echo "   composed onto the $rarity tile"
		made=$((made + 1))
	else
		echo "   compose_icon.py failed for $icon"; failed=$((failed + 1))
	fi
done

echo
echo "drawn $made, skipped $skipped, failed $failed"
[ "$failed" -eq 0 ] || exit 1
