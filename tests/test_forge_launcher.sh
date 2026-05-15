#!/usr/bin/env bash
# Verifies M24 wiring:
#   crazycode.sh
#     - forge appears in items/cmds/descriptions arrays
#     - get_color has a forge case
#     - _launch_tool exports FORGE_TRACKER=0 when invoking forge
#     - _print_help mentions forge
#     - _crazycode_completions includes forge
#     - numeric-key range covers [1-6]
#   install.sh
#     - has an _ask "forge" block calling _install_npm_tool "forge" "@antinomyhq/forge"
#   README.md
#     - mentions forge and the FORGE_TRACKER=0 default

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRAZYCODE="$ROOT/crazycode.sh"
INSTALL_SH="$ROOT/install.sh"
README="$ROOT/README.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
have() { grep -qF -- "$1" "$2"; }
has_re() { grep -qE -- "$1" "$2"; }

[[ -f "$CRAZYCODE"  ]] || fail "crazycode.sh not found at $CRAZYCODE"
[[ -f "$INSTALL_SH" ]] || fail "install.sh not found at $INSTALL_SH"
[[ -f "$README"     ]] || fail "README.md not found at $README"

# crazycode.sh — forge in the parallel arrays and color map
has_re 'items=\([^)]*"forge"' "$CRAZYCODE" \
  || fail "crazycode.sh items array must include \"forge\""
has_re 'cmds=\([^)]*"forge"' "$CRAZYCODE" \
  || fail "crazycode.sh cmds array must include \"forge\""
has_re 'descriptions=\([^)]*"Tailcall"' "$CRAZYCODE" \
  || fail "crazycode.sh descriptions array must include \"Tailcall\""
has_re 'forge\)[[:space:]]+printf' "$CRAZYCODE" \
  || fail "crazycode.sh get_color must have a 'forge)' case"

# crazycode.sh — telemetry opt-out wired into _launch_tool
have 'FORGE_TRACKER=0' "$CRAZYCODE" \
  || fail "crazycode.sh must export FORGE_TRACKER=0 before launching forge"
has_re 'tool" == "forge"' "$CRAZYCODE" \
  || fail "crazycode.sh must guard the FORGE_TRACKER export on tool==forge"

# crazycode.sh — help, completion, key range
has_re 'forge.*FORGE_TRACKER=0' "$CRAZYCODE" \
  || fail "crazycode.sh _print_help must mention forge + FORGE_TRACKER=0 default"
has_re 'compgen -W "[^"]*forge' "$CRAZYCODE" \
  || fail "crazycode.sh _crazycode_completions must include forge"
has_re '\[1-[4-9]\]\)' "$CRAZYCODE" \
  || fail "crazycode.sh numeric-key handler must cover up to at least position 4 (forge)"
has_re '↑↓/1-[4-9]' "$CRAZYCODE" \
  || fail "crazycode.sh help line must include position 4 (forge) in the key range"

# install.sh — forge install block
has_re '_ask "forge"' "$INSTALL_SH" \
  || fail "install.sh must have an _ask \"forge\" block"
has_re '_install_npm_tool "forge" "@antinomyhq/forge"' "$INSTALL_SH" \
  || fail "install.sh must call _install_npm_tool with @antinomyhq/forge"
has_re '_track "forge" "forge"' "$INSTALL_SH" \
  || fail "install.sh must track forge install status"

# README.md — table row + telemetry note
have '**forge**' "$README" \
  || fail "README.md must list **forge** in the tools table"
have 'FORGE_TRACKER=0' "$README" \
  || fail "README.md must mention FORGE_TRACKER=0 default"
has_re '↑↓/1-[4-9]' "$README" \
  || fail "README.md key hint must include position 4 (forge)"

echo "PASS: M24 forge launcher wiring OK"
