#!/usr/bin/env bash
# Verifies M30 wiring: after the `c` toggle the TUI repaints from a cleared
# screen instead of patching the awake line and parking the cursor below the
# footer, and no absolutely-positioned printf asks for a row it did not
# position.
#
# The behaviour these lines produce is checked on a rendered screen in
# tests/test_tui_render.sh; this test pins the wiring so a rewrite that
# reintroduces the pattern fails fast and without a pty.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRAZYCODE="$ROOT/crazycode.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "$CRAZYCODE" ]] || fail "crazycode.sh not found at $CRAZYCODE"

# The `c` branch of the key dispatcher, up to its `;;`.
c_block=$(awk '/^[[:space:]]*c\)[[:space:]]*$/ {inb=1} inb {print} inb && /^[[:space:]]*;;[[:space:]]*$/ {exit}' "$CRAZYCODE")
[[ -n "$c_block" ]] || fail "could not locate the 'c)' branch in crazycode.sh"

# `sudo -v` writes below the footer, and its lecture / retries / the newline it
# echoes there can scroll the screen. Only a full repaint re-establishes the
# absolute row math every other draw depends on.
grep -qE '^[[:space:]]*draw_all[[:space:]]*$' <<<"$c_block" \
  || fail "the 'c' branch must end with a full 'draw_all' repaint"

[[ "$(grep -vE '^[[:space:]]*(;;)?[[:space:]]*$' <<<"$c_block" | tail -1 | tr -d '[:space:]')" == "draw_all" ]] \
  || fail "'draw_all' must be the last statement of the 'c' branch, so the cursor lands on the selected entry"

# The cursor must not be left on the sudo prompt row.
grep -qE 'echo -ne "\\033\[\$\{prompt_row\};1H"[[:space:]]*$' <<<"$c_block" \
  && fail "the 'c' branch must not park the cursor on the sudo prompt row"

# The prompt row itself is still where sudo asks for the password.
grep -qF 'prompt_row};1H\033[K' <<<"$c_block" \
  || fail "the sudo prompt must still be positioned at prompt_row"

# A printf that positions its own row must not also print a newline: the last
# one sits on the bottom row of the layout, and its \n scrolls the whole menu
# up on a terminal exactly as tall as the layout.
if offenders=$(grep -nE 'printf "\\033\[[^"]*;1H[^"]*\\n"' "$CRAZYCODE"); then
  fail "absolutely-positioned printf ends with a newline:"$'\n'"$offenders"
fi

echo "PASS: M30 awake-toggle repaint and newline-free absolute draws"
