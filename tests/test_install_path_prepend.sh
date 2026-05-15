#!/usr/bin/env bash
# Verifies M26 wiring: install.sh prepends $HOME/.local/bin to PATH
# before any _ask block, so _track's command -v probe sees binaries
# installed by pipx (aider) and goose's download_cli.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_SH="$ROOT/install.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
has_re() { grep -qE -- "$1" "$2"; }

[[ -f "$INSTALL_SH" ]] || fail "install.sh not found at $INSTALL_SH"

# The literal export line must exist.
has_re 'export PATH="\$HOME/\.local/bin:\$PATH"' "$INSTALL_SH" \
  || fail "install.sh must export PATH=\$HOME/.local/bin:\$PATH so _track sees user-local installs"

# Order check: the export must sit inside phase 2 (after the section header)
# but before the first install block that runs in that phase. Anchoring on
# `_section "Optional AI assistants"` skips the _ensure_pipx helper above
# (which has its own pipx-prereq _ask unrelated to phase 2 ordering).
export_line=$(grep -nE 'export PATH="\$HOME/\.local/bin:\$PATH"' "$INSTALL_SH" | head -1 | cut -d: -f1)
section_line=$(grep -nF '_section "Optional AI assistants"' "$INSTALL_SH" | head -1 | cut -d: -f1)
phase2_ask_line=$(awk -v start="$section_line" 'NR > start && /^[[:space:]]*if _ask / { print NR; exit }' "$INSTALL_SH")

[[ -n "$export_line" && -n "$section_line" && -n "$phase2_ask_line" ]] \
  || fail "could not locate export ($export_line), section ($section_line), or phase-2 _ask ($phase2_ask_line)"

(( export_line > section_line )) \
  || fail "export PATH (line $export_line) must come after _section header (line $section_line)"

(( export_line < phase2_ask_line )) \
  || fail "export PATH (line $export_line) must precede the first phase-2 _ask block (line $phase2_ask_line)"

echo "PASS: M26 PATH prepend wiring OK"
