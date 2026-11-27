#!/usr/bin/env bash
# One golden weapon's front view from Codex (rule 9): ./run.sh golden_bow ref_bow.png
cd "$(dirname "$0")" || exit 1
n=$1; shift; args=(); for r in "$@"; do args+=(-i "$r"); done
timeout 900 codex exec "${args[@]}" --skip-git-repo-check < "$n.txt" 2>&1 | tail -40 > "$n.log"; echo "=== $n done"
