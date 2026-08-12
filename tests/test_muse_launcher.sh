#!/usr/bin/env bash
# Verifies M31 wiring:
#   crazycode.sh
#     - muse appears in items/cmds/descriptions arrays
#     - get_color has a muse case with MO
#     - _launch_tool resume branch matches muse (subcommand override)
#     - _print_help mentions muse
#     - _crazycode_completions includes muse
#     - numeric-key range covers [1-8]
#   install.sh
#     - has an _ask "muse" block invoking https://dev.meta.ai/install.sh
#   README.md
#     - mentions muse in the tools table

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

# crazycode.sh — muse in the parallel arrays and color map
has_re 'items=\([^)]*"muse"' "$CRAZYCODE" \
  || fail "crazycode.sh items array must include \"muse\""
has_re 'cmds=\([^)]*"muse"' "$CRAZYCODE" \
  || fail "crazycode.sh cmds array must include \"muse\""
has_re 'descriptions=\([^)]*"Meta"' "$CRAZYCODE" \
  || fail "crazycode.sh descriptions array must include \"Meta\" for muse"
has_re 'muse\)[[:space:]]+printf' "$CRAZYCODE" \
  || fail "crazycode.sh get_color must have a 'muse)' case"
have 'MO=' "$CRAZYCODE" \
  || fail "crazycode.sh must define MO color for muse"

# crazycode.sh — resume subcommand override
has_re 'tool" == "muse"' "$CRAZYCODE" \
  || fail "crazycode.sh _launch_tool must handle muse in resume branch"
have 'muse resume' "$CRAZYCODE" \
  || have 'muse.*resume' "$CRAZYCODE" \
  || fail "crazycode.sh must wire muse resume subcommand"

# crazycode.sh — help, completion, key range
has_re 'muse.*Launch Muse' "$CRAZYCODE" \
  || fail "crazycode.sh _print_help must mention muse"
has_re 'compgen -W "[^"]*muse' "$CRAZYCODE" \
  || fail "crazycode.sh _crazycode_completions must include muse"
has_re '\[1-8\]\)' "$CRAZYCODE" \
  || fail "crazycode.sh numeric-key handler must cover [1-8]"
has_re '↑↓/1-8' "$CRAZYCODE" \
  || fail "crazycode.sh help line must include 1-8"

# install.sh — muse install block
has_re '_ask "muse"' "$INSTALL_SH" \
  || fail "install.sh must have an _ask \"muse\" block"
have 'https://dev.meta.ai/install.sh' "$INSTALL_SH" \
  || fail "install.sh must invoke https://dev.meta.ai/install.sh for muse"
has_re '_track "muse" "muse"' "$INSTALL_SH" \
  || fail "install.sh must track muse install status"
# alphabetical order: goose before muse before opencode
goose_line=$(grep -n '_ask "goose"' "$INSTALL_SH" | cut -d: -f1 | head -1)
muse_line=$(grep -n '_ask "muse"' "$INSTALL_SH" | cut -d: -f1 | head -1)
opencode_line=$(grep -n '_ask "opencode"' "$INSTALL_SH" | cut -d: -f1 | head -1)
[[ -n "$goose_line" && -n "$muse_line" && -n "$opencode_line" ]] \
  || fail "install.sh must have goose/muse/opencode blocks"
[[ "$goose_line" -lt "$muse_line" && "$muse_line" -lt "$opencode_line" ]] \
  || fail "install.sh must order goose < muse < opencode alphabetically"

# README.md — table row
have '**muse**' "$README" \
  || fail "README.md must list **muse** in the tools table"
have 'Muse Code' "$README" \
  || fail "README.md must mention Muse Code"
has_re '↑↓/1-8' "$README" \
  || fail "README.md key hint must include 1-8"

echo "PASS: M31 muse launcher wiring OK"
