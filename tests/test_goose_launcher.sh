#!/usr/bin/env bash
# Verifies M25 wiring: goose launcher across crazycode.sh, install.sh, README.md.

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

# crazycode.sh — goose in the parallel arrays and color map
has_re 'items=\([^)]*"goose"' "$CRAZYCODE" \
  || fail "crazycode.sh items array must include \"goose\""
has_re 'cmds=\([^)]*"goose"' "$CRAZYCODE" \
  || fail "crazycode.sh cmds array must include \"goose\""
has_re 'descriptions=\([^)]*"AAIF"' "$CRAZYCODE" \
  || fail "crazycode.sh descriptions array must include \"AAIF\""
has_re 'goose\)[[:space:]]+printf' "$CRAZYCODE" \
  || fail "crazycode.sh get_color must have a 'goose)' case"

# crazycode.sh — alphabetical order in items array (aider · claude ·
# codex · forge · gemini · goose · muse · opencode)
has_re 'items=\("aider" "claude" "codex" "forge" "gemini" "goose" "muse" "opencode"\)' "$CRAZYCODE" \
  || fail "crazycode.sh items array must be in alphabetical order with goose between gemini and muse"

# crazycode.sh — auto-approve env var wired into _launch_tool
have 'GOOSE_MODE=auto' "$CRAZYCODE" \
  || fail "crazycode.sh must export GOOSE_MODE=auto before launching goose"
has_re 'tool" == "goose"' "$CRAZYCODE" \
  || fail "crazycode.sh must guard the GOOSE_MODE export on tool==goose"

# crazycode.sh — resume_args for goose carries the session subcommand
has_re 'session --resume' "$CRAZYCODE" \
  || fail "crazycode.sh resume_args must contain 'session --resume' for goose"

# crazycode.sh — help, completion, key range
has_re 'goose.*GOOSE_MODE=auto' "$CRAZYCODE" \
  || fail "crazycode.sh _print_help must mention goose + GOOSE_MODE=auto default"
has_re 'compgen -W "[^"]*goose' "$CRAZYCODE" \
  || fail "crazycode.sh _crazycode_completions must include goose"
has_re '\[1-8\]\)' "$CRAZYCODE" \
  || fail "crazycode.sh numeric-key handler must cover [1-8]"
has_re '↑↓/1-8' "$CRAZYCODE" \
  || fail "crazycode.sh help line must say ↑↓/1-8"

# install.sh — goose install block with non-interactive configure
has_re '_ask "goose"' "$INSTALL_SH" \
  || fail "install.sh must have an _ask \"goose\" block"
has_re 'CONFIGURE=false.*download_cli\.sh' "$INSTALL_SH" \
  || fail "install.sh must invoke goose's download_cli.sh with CONFIGURE=false (non-interactive)"
has_re 'aaif-goose/goose' "$INSTALL_SH" \
  || fail "install.sh must reference the aaif-goose/goose installer URL"
has_re '_track "goose" "goose"' "$INSTALL_SH" \
  || fail "install.sh must track goose install status"

# README.md — table row + auto-mode note + key range
have '**goose**' "$README" \
  || fail "README.md must list **goose** in the tools table"
have 'GOOSE_MODE=auto' "$README" \
  || fail "README.md must mention GOOSE_MODE=auto default"
has_re '↑↓/1-8' "$README" \
  || fail "README.md must update the key hint to ↑↓/1-8"

echo "PASS: M25 goose launcher wiring OK"
