#!/usr/bin/env bash
# Verifies install.sh phase-2 layout:
#   1. Two _section headers exist: "Awake mode dependencies" and "AI assistants"
#   2. caffeine block sits under "Awake mode dependencies"
#   3. AI assistants sit under "AI assistants" in alphabetical order:
#      aider, claude code, codex, gemini cli, opencode

set -euo pipefail

INSTALL_SH="$(cd "$(dirname "$0")/.." && pwd)/install.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "$INSTALL_SH" ]] || fail "install.sh not found at $INSTALL_SH"

line_of() { grep -n -F "$1" "$INSTALL_SH" 2>/dev/null | head -1 | cut -d: -f1 || true; }

awake_hdr=$(line_of '_section "Awake mode dependencies"')
ai_hdr=$(line_of '_section "AI assistants"')
[[ -n "$awake_hdr" ]] || fail "missing '_section \"Awake mode dependencies\"' header"
[[ -n "$ai_hdr"    ]] || fail "missing '_section \"AI assistants\"' header"
[[ "$awake_hdr" -lt "$ai_hdr" ]] || fail "'Awake mode dependencies' must precede 'AI assistants'"

caffeine_line=$(line_of '_ask "caffeine"')
[[ -n "$caffeine_line" ]] || fail "missing _ask block for 'caffeine'"
[[ "$caffeine_line" -gt "$awake_hdr" ]] || fail "caffeine block must come AFTER 'Awake mode dependencies' header"
[[ "$caffeine_line" -lt "$ai_hdr"    ]] || fail "caffeine block must come BEFORE 'AI assistants' header"

expected=("aider" "claude code" "codex" "gemini cli" "opencode")
prev=$ai_hdr
prev_label="'AI assistants' header"
for tool in "${expected[@]}"; do
  cur=$(line_of "_ask \"$tool\"")
  [[ -n "$cur" ]] || fail "missing _ask block for '$tool'"
  [[ "$cur" -gt "$prev" ]] \
    || fail "'$tool' (line $cur) is out of order — expected after $prev_label (line $prev)"
  prev=$cur
  prev_label="'$tool' (line $cur)"
done

echo "PASS: install.sh phase-2 layout OK"
