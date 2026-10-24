#!/usr/bin/env bash
# Every gate CI runs, plus the type check CI does not, in one go:
#   tools/check.sh
# StyLua, Selene, luau-lsp (strict types), rojo build. Stops at the first
# failure. In-Roblox tests are separate: tools/studio/run_tests.luau.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== stylua"; stylua src tests
stylua --check src tests
echo "== selene"; selene src tests | tail -3
echo "== types"
rojo sourcemap default.project.json -o sourcemap.json >/dev/null
out=$(luau-lsp analyze --sourcemap=sourcemap.json --defs=globalTypes.d.luau src tests 2>&1 | grep -v "^\[INFO\]\|^\[WARN\]" || true)
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "clean"
echo "== rojo build"; rojo build -o "${TMPDIR:-/tmp}/check.rbxl" | tail -1
echo "All gates pass."
