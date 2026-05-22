#!/usr/bin/env bash
# Verifies M27 wiring: crazycode.sh drains stray terminal input after a
# child tool exits, so query responses (cursor-position / device-attributes
# reports) buffered post-exit are not consumed by the menu as keystrokes.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRAZYCODE="$ROOT/crazycode.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
has_re() { grep -qE -- "$1" "$2"; }

[[ -f "$CRAZYCODE" ]] || fail "crazycode.sh not found at $CRAZYCODE"

# The drain loop must exist: a timed single-byte read used to flush the buffer.
has_re 'while read -rsn1 -t [0-9.]+ .*; do' "$CRAZYCODE" \
  || fail "crazycode.sh must contain a 'while read -rsn1 -t <timeout>' drain loop"

# Order check: the drain must sit after 'stty sane' (i.e. inside the TUI loop,
# right after a child tool returns) — not before, where no child has run yet.
stty_line=$(grep -nF 'stty sane 2>/dev/null' "$CRAZYCODE" | head -1 | cut -d: -f1)
drain_line=$(grep -nE 'while read -rsn1 -t [0-9.]+ .*; do' "$CRAZYCODE" | head -1 | cut -d: -f1)

[[ -n "$stty_line" && -n "$drain_line" ]] \
  || fail "could not locate stty sane ($stty_line) or drain loop ($drain_line)"

(( drain_line > stty_line )) \
  || fail "drain loop (line $drain_line) must come after 'stty sane' (line $stty_line)"

echo "PASS: M27 input-drain wiring OK"
