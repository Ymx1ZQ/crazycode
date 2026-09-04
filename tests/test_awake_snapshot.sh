#!/usr/bin/env bash
# Verifies M35: awake mode snapshots the pre-existing power state and restores
# THAT, instead of writing hardcoded defaults back.
#
# The bug this pins: disable_awake used to write HandleLidSwitch=suspend,
# lock-enabled=true and idle-delay=300 unconditionally. On a machine where those
# settings were configured on purpose (streaming host, headless server), turning
# awake mode off silently destroyed that configuration.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRAZYCODE="$ROOT/crazycode.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

[[ -f "$CRAZYCODE" ]] || fail "crazycode.sh not found at $CRAZYCODE"

body() {  # body <function-name> -> the function's source, up to its closing brace
  awk -v fn="$1" '
    $0 ~ "^[[:space:]]*" fn "\\(\\)" {inb=1}
    inb {print}
    inb && /^[[:space:]]*\}[[:space:]]*$/ {exit}
  ' "$CRAZYCODE"
}

enable_body=$(body enable_awake)
disable_body=$(body disable_awake)
[[ -n "$enable_body"  ]] || fail "could not locate enable_awake"
[[ -n "$disable_body" ]] || fail "could not locate disable_awake"

# 1. enable snapshots the previous state
grep -q 'awake\.pre' <<<"$enable_body" \
  || fail "enable_awake must snapshot the previous state to awake.pre"
pass "enable_awake writes a snapshot"

# 2. the snapshot is written before the first mutation (sudo/gsettings)
snap_line=$(grep -n 'awake\.pre' <<<"$enable_body" | head -1 | cut -d: -f1)
mut_line=$(grep -nE 'sudo systemctl mask|gsettings set|sudo sed -i' <<<"$enable_body" | head -1 | cut -d: -f1)
[[ -n "$snap_line" && -n "$mut_line" && "$snap_line" -lt "$mut_line" ]] \
  || fail "the snapshot must be taken BEFORE the first mutation (snap=$snap_line mut=$mut_line)"
pass "snapshot precedes the first mutation"

# 3. a repeated enable must not clobber an existing snapshot
grep -qE '\[\[ *! *-f|\[ *! *-f|-e .*awake\.pre.*\|\||if .*! *-f' <<<"$enable_body" \
  || fail "enable_awake must not overwrite an existing snapshot"
pass "existing snapshot is preserved on repeated enable"

# 4. disable no longer writes the hardcoded defaults
for bad in 'HandleLidSwitch=suspend' 'idle-delay 300' 'lock-enabled true' 'Autolock true'; do
  grep -qF "$bad" <<<"$disable_body" \
    && fail "disable_awake still hardcodes '$bad' instead of restoring the snapshot"
done
pass "disable_awake no longer hardcodes defaults"

# 5. disable reads the snapshot
grep -q 'awake\.pre' <<<"$disable_body" \
  || fail "disable_awake must read the snapshot"
pass "disable_awake reads the snapshot"

# 6. with no snapshot, lid/lock/idle are left alone
grep -qE 'no snapshot|nothing to restore|skip' <<<"$disable_body" \
  || fail "disable_awake must handle the missing-snapshot case explicitly"
pass "missing snapshot handled explicitly"

# 7. sleep targets already masked before enabling are not unmasked
grep -q 'sleep_was_masked\|was_masked' <<<"$disable_body" \
  || fail "disable_awake must not unmask sleep targets that were already masked"
pass "pre-existing sleep mask is preserved"

echo "PASS: $(basename "$0")"
