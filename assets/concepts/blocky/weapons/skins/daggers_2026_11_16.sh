#!/usr/bin/env bash
# The Assassin's missing daggers from Codex (rule 9), one front view each.
cd "$(dirname "$0")" || exit 1
(cd thornwood && timeout 900 codex exec -i ../forest/glimmerhorn_daggers_views.png -i silkbound_blade_views.png --skip-git-repo-check < hedge_prickers.txt 2>&1 | tail -20 > hedge_prickers.log; echo "=== hedge_prickers done")
(cd thornwood && timeout 900 codex exec -i ../forest/glimmerhorn_daggers_views.png -i silkbound_blade_views.png --skip-git-repo-check < tusk_knives.txt 2>&1 | tail -20 > tusk_knives.log; echo "=== tusk_knives done")
(cd thornwood && timeout 900 codex exec -i ../forest/glimmerhorn_daggers_views.png -i silkbound_blade_views.png --skip-git-repo-check < burrfang_daggers.txt 2>&1 | tail -20 > burrfang_daggers.log; echo "=== burrfang_daggers done")
(cd thornwood && timeout 900 codex exec -i ../forest/glimmerhorn_daggers_views.png -i silkbound_blade_views.png --skip-git-repo-check < silkfang_daggers.txt 2>&1 | tail -20 > silkfang_daggers.log; echo "=== silkfang_daggers done")
(cd thornwood && timeout 900 codex exec -i ../forest/glimmerhorn_daggers_views.png -i silkbound_blade_views.png --skip-git-repo-check < lurker_claws.txt 2>&1 | tail -20 > lurker_claws.log; echo "=== lurker_claws done")
(cd drowned && timeout 900 codex exec -i ../forest/glimmerhorn_daggers_views.png -i tollguard_blade_views.png --skip-git-repo-check < driftwood_dirks.txt 2>&1 | tail -20 > driftwood_dirks.log; echo "=== driftwood_dirks done")
(cd drowned && timeout 900 codex exec -i ../forest/glimmerhorn_daggers_views.png -i tollguard_blade_views.png --skip-git-repo-check < barnacle_knives.txt 2>&1 | tail -20 > barnacle_knives.log; echo "=== barnacle_knives done")
(cd drowned && timeout 900 codex exec -i ../forest/glimmerhorn_daggers_views.png -i tollguard_blade_views.png --skip-git-repo-check < eeltooth_daggers.txt 2>&1 | tail -20 > eeltooth_daggers.log; echo "=== eeltooth_daggers done")
(cd drowned && timeout 900 codex exec -i ../forest/glimmerhorn_daggers_views.png -i tollguard_blade_views.png --skip-git-repo-check < tollbell_daggers.txt 2>&1 | tail -20 > tollbell_daggers.log; echo "=== tollbell_daggers done")
(cd drowned && timeout 900 codex exec -i ../forest/glimmerhorn_daggers_views.png -i tollguard_blade_views.png --skip-git-repo-check < riptide_fangs.txt 2>&1 | tail -20 > riptide_fangs.log; echo "=== riptide_fangs done")
(cd golden && timeout 900 codex exec -i ../forest/glimmerhorn_daggers_views.png -i golden_blade.png --skip-git-repo-check < golden_daggers.txt 2>&1 | tail -20 > golden_daggers.log; echo "=== golden_daggers done")
