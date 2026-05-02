#!/usr/bin/env bash
# Verifies M23 wiring:
#   install.sh, on a fresh install:
#     - resolves its own directory via BASH_SOURCE
#     - sanity-checks the directory by verifying crazycode.sh sits next to install.sh
#     - confirms the directory is a git repo toplevel (rev-parse --show-toplevel)
#     - guards against cloning the destination ($CRAZYCODE_DIR) onto itself
#     - clones from the local checkout when detected, then re-points origin
#       to the canonical github.com/Ymx1ZQ/crazycode URL
#     - preserves the GitHub-clone path as fallback (curl-pipe-bash case)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_SH="$ROOT/install.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
have() { grep -qF -- "$1" "$2"; }
has_re() { grep -qE -- "$1" "$2"; }

[[ -f "$INSTALL_SH" ]] || fail "install.sh not found at $INSTALL_SH"

# Detection: SCRIPT_DIR via BASH_SOURCE
have 'BASH_SOURCE' "$INSTALL_SH" \
  || fail "install.sh must resolve its own directory via BASH_SOURCE"

# Sanity check: the resolved directory must contain crazycode.sh
has_re 'crazycode\.sh' "$INSTALL_SH" \
  || fail "install.sh must sanity-check for crazycode.sh next to install.sh"

# Git-toplevel check
have 'rev-parse --show-toplevel' "$INSTALL_SH" \
  || fail "install.sh must verify the script dir is a git repo toplevel"

# Self-clone guard: SCRIPT_DIR must not equal CRAZYCODE_DIR
has_re '\$SCRIPT_DIR.*\$CRAZYCODE_DIR|\$CRAZYCODE_DIR.*\$SCRIPT_DIR' "$INSTALL_SH" \
  || fail "install.sh must guard against SCRIPT_DIR == CRAZYCODE_DIR"

# Clone-from-local branch: clone uses a local-path variable (SCRIPT_DIR or LOCAL_SRC) as source
has_re 'git clone[^"]*"\$(SCRIPT_DIR|LOCAL_SRC)"' "$INSTALL_SH" \
  || fail "install.sh must clone from a local-path variable on the local-checkout branch"

# Re-point origin to canonical GitHub URL after local clone
have 'remote set-url origin' "$INSTALL_SH" \
  || fail "install.sh must re-point origin to GitHub after local clone"
have 'https://github.com/Ymx1ZQ/crazycode.git' "$INSTALL_SH" \
  || fail "install.sh must reference the canonical GitHub URL"

# Fallback path preserved: a git clone of the GitHub URL must remain reachable.
# Accept either the inline URL or a variable bound to the canonical URL.
if has_re 'git clone[^"]*https://github\.com/Ymx1ZQ/crazycode\.git' "$INSTALL_SH"; then
  :
elif has_re '^[[:space:]]*[A-Z_]+="https://github\.com/Ymx1ZQ/crazycode\.git"' "$INSTALL_SH" \
     && has_re 'git clone[^"]*"\$[A-Z_]+"' "$INSTALL_SH"; then
  :
else
  fail "install.sh must preserve a git clone of the canonical GitHub URL as fallback"
fi

echo "PASS: M23 local-checkout detection wiring OK"
