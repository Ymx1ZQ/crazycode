#!/usr/bin/env bash
# Verifies M22 wiring:
#   crazycode.sh
#     - uses `systemd-inhibit --what=idle` with the unique --who=crazycode-awake tag
#     - detects the active inhibitor via `systemd-inhibit --list`
#     - exposes an `idle_inhibited` state and an `idle inhibitor` status row
#     - no longer carries the old `caffeine_on` / `check_caffeine` / `caffeine/dpms` symbols
#   install.sh
#     - does not install the `caffeine` apt package
#     - does not carry the M21 `Awake mode dependencies` section header

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRAZYCODE="$ROOT/crazycode.sh"
INSTALL_SH="$ROOT/install.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
have() { grep -qF -- "$1" "$2"; }
has_re() { grep -qE -- "$1" "$2"; }

[[ -f "$CRAZYCODE"  ]] || fail "crazycode.sh not found at $CRAZYCODE"
[[ -f "$INSTALL_SH" ]] || fail "install.sh not found at $INSTALL_SH"

# crazycode.sh — positive assertions
have 'systemd-inhibit --what=idle' "$CRAZYCODE" \
  || fail "crazycode.sh must spawn 'systemd-inhibit --what=idle'"
have '--who=crazycode-awake' "$CRAZYCODE" \
  || fail "crazycode.sh must tag the inhibitor with --who=crazycode-awake"
have 'systemd-inhibit --list' "$CRAZYCODE" \
  || fail "crazycode.sh must detect the inhibitor via 'systemd-inhibit --list'"
have 'idle_inhibited' "$CRAZYCODE" \
  || fail "crazycode.sh must expose state variable 'idle_inhibited'"
have 'idle inhibitor' "$CRAZYCODE" \
  || fail "crazycode.sh status row must read 'idle inhibitor'"

# crazycode.sh — negative assertions (old caffeine wiring must be gone)
# Note: a one-shot legacy-cleanup `pkill -f caffeine-indicator` line is allowed.
! has_re '\bcaffeine_on\b' "$CRAZYCODE" \
  || fail "crazycode.sh still references old state var 'caffeine_on'"
! has_re '\bcheck_caffeine\b' "$CRAZYCODE" \
  || fail "crazycode.sh still references old function 'check_caffeine'"
! have 'caffeine/dpms' "$CRAZYCODE" \
  || fail "crazycode.sh still uses old status label 'caffeine/dpms'"
! have 'apt install -y caffeine' "$CRAZYCODE" \
  || fail "crazycode.sh still installs caffeine on demand"

# install.sh — caffeine block removed, section gone
! have '_ask "caffeine"' "$INSTALL_SH" \
  || fail "install.sh still has _ask block for caffeine"
! have 'apt install -y caffeine' "$INSTALL_SH" \
  || fail "install.sh still apt-installs caffeine"
! have '_section "Awake mode dependencies"' "$INSTALL_SH" \
  || fail "install.sh still has 'Awake mode dependencies' section header"

echo "PASS: M22 awake-inhibitor wiring OK"
