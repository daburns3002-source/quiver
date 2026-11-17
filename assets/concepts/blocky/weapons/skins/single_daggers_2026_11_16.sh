#!/usr/bin/env bash
# Mossy Glade's six daggers, front view alone, from Codex (rule 9).
cd "$(dirname "$0")/forest" || exit 1
timeout 900 codex exec -i splinter_daggers_views.png --skip-git-repo-check < splinter_daggers_single.txt 2>&1 | tail -20 > splinter_daggers_single.log; echo "=== splinter_daggers done"
timeout 900 codex exec -i bramble_shivs_views.png --skip-git-repo-check < bramble_shivs_single.txt 2>&1 | tail -20 > bramble_shivs_single.log; echo "=== bramble_shivs done"
timeout 900 codex exec -i firefly_fangs_views.png --skip-git-repo-check < firefly_fangs_single.txt 2>&1 | tail -20 > firefly_fangs_single.log; echo "=== firefly_fangs done"
timeout 900 codex exec -i glade_fox_claws_views.png --skip-git-repo-check < glade_fox_claws_single.txt 2>&1 | tail -20 > glade_fox_claws_single.log; echo "=== glade_fox_claws done"
timeout 900 codex exec -i ember_wilf_fangs_views.png --skip-git-repo-check < ember_wilf_fangs_single.txt 2>&1 | tail -20 > ember_wilf_fangs_single.log; echo "=== ember_wilf_fangs done"
timeout 900 codex exec -i glimmerhorn_daggers_views.png --skip-git-repo-check < glimmerhorn_daggers_single.txt 2>&1 | tail -20 > glimmerhorn_daggers_single.log; echo "=== glimmerhorn_daggers done"
