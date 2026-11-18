#!/usr/bin/env bash
# neon_circuit: one front view each from Codex (rule 9).
cd "$(dirname "$0")/neon_circuit" || exit 1
timeout 900 codex exec -i ../../golden/golden_bow.png --skip-git-repo-check < livewire_bow.txt 2>&1 | tail -20 > livewire_bow.log; echo "=== livewire_bow done"
timeout 900 codex exec -i ../../golden/golden_blade.png --skip-git-repo-check < overclock_blade.txt 2>&1 | tail -20 > overclock_blade.log; echo "=== overclock_blade done"
