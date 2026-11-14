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
echo "== fonts"
# Every word on screen is in the one rounded font, Fredoka One (CLAUDE.md rule 11).
bad=$(grep -rnE "Enum\.Font\.[A-Za-z]+|Font\.(new|fromName|fromId)\(" src | grep -v "Enum\.Font\.FredokaOne" || true)
if [ -n "$bad" ]; then echo "$bad"; echo "Use Enum.Font.FredokaOne (or Chunky.font): CLAUDE.md rule 11."; exit 1; fi
echo "rounded"
echo "== currency icons"
# One coin and one diamond in the whole game, Config/ShopAssets' (CLAUDE.md rule 15).
bad=$(grep -rnEi "^\s*[A-Za-z]*(coin|gem|diamond)[A-Za-z]*\s*=\s*\"rbxassetid" src | grep -v "src/shared/Config/ShopAssets.luau" || true)
if [ -n "$bad" ]; then echo "$bad"; echo "Use ShopAssets.coin / ShopAssets.gem: CLAUDE.md rule 15."; exit 1; fi
echo "one of each"
echo "== remotes"
# Every client-to-server remote is listened to in Net/Inbound: rate limited,
# the Debug ones in Studio only (the anti-exploit audit, docs/FIXES.md).
bad=$(grep -rnE "OnServerEvent|OnServerInvoke" src | grep -v "^src/server/Net/Inbound.luau:" || true)
if [ -n "$bad" ]; then echo "$bad"; echo "Listen through Net/Inbound: Inbound.on, or Inbound.debug for a Debug remote."; exit 1; fi
bad=$(grep -rnE "Inbound\.on\(Remotes\.Debug" src || true)
if [ -n "$bad" ]; then echo "$bad"; echo "A Debug remote is Studio's: Inbound.debug."; exit 1; fi
echo "all through Inbound"
echo "== rojo build"; rojo build -o "${TMPDIR:-/tmp}/check.rbxl" | tail -1
echo "All gates pass."
