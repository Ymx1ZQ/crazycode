#!/usr/bin/env bash
# Verifies M29: in CLI mode the user's arguments reach the tool untouched.
#
# Unlike the other tests in this directory this one *executes* crazycode.sh.
# Stub tools on a scoped PATH make that hermetic — no real assistant runs.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRAZYCODE="$ROOT/crazycode.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "$CRAZYCODE" ]] || fail "crazycode.sh not found at $CRAZYCODE"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Stubs echo their argv and exit, so a run is one line of output.
mkdir -p "$TMP/bin"
for tool in aider claude codex forge gemini goose opencode; do
  printf '#!/usr/bin/env bash\necho "ARGV: %s $*"\n' "$tool" > "$TMP/bin/$tool"
  chmod +x "$TMP/bin/$tool"
done

# Run crazycode in CLI mode with only the stubs visible first on PATH.
run() { PATH="$TMP/bin:$PATH" bash "$CRAZYCODE" "$@" 2>&1; }
argv() { run "$@" | grep -a '^ARGV:' || true; }

# ── flags survive, values stay attached to them ──────────────────────────
got=$(argv claude --model opus)
[[ "$got" == "ARGV: claude --dangerously-skip-permissions --model opus" ]] \
  || fail "claude --model opus was mangled: '$got'"

got=$(argv aider --message ciao)
[[ "$got" == "ARGV: aider --yes-always --message ciao" ]] \
  || fail "aider --message ciao was mangled: '$got'"

# ── a lone argument is not swallowed ─────────────────────────────────────
got=$(argv claude foo)
[[ "$got" == "ARGV: claude --dangerously-skip-permissions foo" ]] \
  || fail "a single trailing argument was dropped: '$got'"

# ── a numeric argument is an argument, not a mode switch ─────────────────
out=$(run claude 1)
grep -qa 'Resuming' <<<"$out" \
  && fail "'crazycode claude 1' must not enter resume mode"
grep -qa -- '--resume' <<<"$out" \
  && fail "'crazycode claude 1' must not pass --resume"
grep -qa '^ARGV: claude --dangerously-skip-permissions 1$' <<<"$out" \
  || fail "'crazycode claude 1' must forward the 1: '$out'"

# ── the resume comparison must not reach bash's arithmetic evaluator ─────
# `[[ $resume -eq 1 ]]` evaluated its operand arithmetically, where a command
# substitution inside an array subscript runs.
canary="$TMP/canary"
run claude "a[\$(touch '$canary')]" >/dev/null 2>&1 || true
[[ -e "$canary" ]] \
  && fail "arithmetic evaluation executed a command substitution from argv"

# ── resume from the CLI works by forwarding the tool's own flag ──────────
got=$(argv claude --resume)
[[ "$got" == "ARGV: claude --dangerously-skip-permissions --resume" ]] \
  || fail "crazycode claude --resume must forward --resume: '$got'"

# ── the caller passes the resume flag explicitly ─────────────────────────
grep -qF '_launch_tool "$idx" 0 "$@"' "$CRAZYCODE" \
  || fail "CLI mode must call _launch_tool with an explicit resume flag"
grep -qE '^\s*shift 2\s*$' "$CRAZYCODE" \
  || fail "_launch_tool must use a plain 'shift 2' (no fallback to shift 1)"
grep -qF '$resume -eq 1' "$CRAZYCODE" \
  && fail "_launch_tool must compare resume as a string, not arithmetically"

echo "PASS: CLI argument forwarding (M29)"
