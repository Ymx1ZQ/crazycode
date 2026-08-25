#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRAZYCODE="$ROOT/crazycode.sh"
UNIT_TEMPLATE="$ROOT/systemd/crazycode-opencode.service"
README="$ROOT/README.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "$CRAZYCODE" ]] || fail "crazycode.sh not found at $CRAZYCODE"
[[ -f "$UNIT_TEMPLATE" ]] || fail "the shared OpenCode user-service template is missing"

grep -qF 'ExecStart=/usr/bin/env opencode serve --hostname 127.0.0.1 --port 4096' "$UNIT_TEMPLATE" \
  || fail "the OpenCode backend must bind only to loopback on the stable local port"
grep -qF 'EnvironmentFile=%h/.config/crazycode/opencode.env' "$UNIT_TEMPLATE" \
  || fail "the service must read its password from the private environment file"
grep -qF 'Slice=app.slice' "$UNIT_TEMPLATE" \
  || fail "the backend must run as its own unit under app.slice"
grep -qF 'Restart=on-failure' "$UNIT_TEMPLATE" \
  || fail "the backend must recover after a process failure"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"
BIN_NEW="$TMP/bin-new"
TEST_HOME="$TMP/home"
CALLS="$TMP/opencode.calls"
META="$TMP/opencode.meta"
SYSTEMD_CALLS="$TMP/systemctl.calls"
SYSTEMD_STATE="$TMP/systemd.state"
CURL_CALLS="$TMP/curl.calls"
CURL_FAILURES="$TMP/curl.failures"
CANARY="$TMP/credential-was-executed"
BARRIER="$TMP/barrier"
mkdir -p \
  "$BIN" "$BIN_NEW" "$TEST_HOME/.config/crazycode" \
  "$TMP/project-a" "$TMP/project-b" "$BARRIER"

cat > "$BIN/opencode" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$OPENCODE_TEST_CALLS"
if [[ "${OPENCODE_SERVER_PASSWORD:-}" =~ ^[0-9a-f]{64}$ ]]; then
  printf 'auth=present\n' >> "$OPENCODE_TEST_META"
else
  printf 'auth=missing\n' >> "$OPENCODE_TEST_META"
fi
STUB

cat > "$BIN/systemctl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SYSTEMCTL_TEST_CALLS"
case "$*" in
  '--user show --property=ActiveState --value crazycode-opencode.service')
    [[ -f "$HOME/.config/systemd/user/crazycode-opencode.service" ]] || exit 4
    if [[ -f "$SYSTEMCTL_TEST_STATE" ]]; then
      cat "$SYSTEMCTL_TEST_STATE"
    else
      printf 'inactive\n'
    fi
    ;;
  '--user is-active --quiet crazycode-opencode.service')
    [[ -f "$SYSTEMCTL_TEST_STATE" && "$(<"$SYSTEMCTL_TEST_STATE")" == active ]]
    ;;
  '--user start crazycode-opencode.service')
    [[ "${SYSTEMCTL_TEST_FAIL_START:-0}" == 0 ]] || exit 1
    sleep 0.25
    printf 'active\n' > "$SYSTEMCTL_TEST_STATE"
    ;;
esac
STUB

cat > "$BIN/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CURL_TEST_CALLS"
case " $* " in
  *' --config - '*) config=$(cat) ;;
  *)
    printf 'failed\n' > "$SYSTEMCTL_TEST_STATE"
    exit 22
    ;;
esac
if [[ ! "$config" =~ user[[:space:]]*=[[:space:]]*\"opencode:[0-9a-f]{64}\" ]]; then
  printf 'failed\n' > "$SYSTEMCTL_TEST_STATE"
  exit 22
fi
if [[ "${CURL_TEST_ALWAYS_FAIL:-0}" == 1 ]]; then
  exit 7
fi
if [[ -f "$CURL_TEST_FAILURES" ]]; then
  remaining=$(<"$CURL_TEST_FAILURES")
  if (( remaining > 0 )); then
    printf '%s\n' "$((remaining - 1))" > "$CURL_TEST_FAILURES"
    exit 7
  fi
fi
exit 0
STUB

cat > "$BIN_NEW/path-marker" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB

chmod +x "$BIN/opencode" "$BIN/systemctl" "$BIN/curl" "$BIN_NEW/path-marker"

# This value is inert hostile data: replacement must never evaluate it.
printf 'OPENCODE_SERVER_PASSWORD=$(touch %s)\n' "$CANARY" > "$TEST_HOME/.config/crazycode/opencode.env"
chmod 600 "$TEST_HOME/.config/crazycode/opencode.env"

run_in() {
  local dir="$1" extra_path="$2"; shift 2
  (
    cd "$dir"
    env \
      HOME="$TEST_HOME" \
      PATH="${extra_path:+$extra_path:}$BIN:$PATH" \
      OPENCODE_SERVER_PASSWORD=parent-sentinel \
      OPENCODE_TEST_CALLS="$CALLS" \
      OPENCODE_TEST_META="$META" \
      SYSTEMCTL_TEST_CALLS="$SYSTEMD_CALLS" \
      SYSTEMCTL_TEST_STATE="$SYSTEMD_STATE" \
      CURL_TEST_CALLS="$CURL_CALLS" \
      CURL_TEST_FAILURES="$CURL_FAILURES" \
      bash -c '
        source "$1"
        shift
        _crazycode_main "$@"
        status=$?
        [[ "${OPENCODE_SERVER_PASSWORD:-}" == parent-sentinel ]] || exit 97
        exit "$status"
      ' bash "$CRAZYCODE" opencode "$@"
  )
}

run_after_barrier() {
  local label="$1" dir="$2"; shift 2
  : > "$BARRIER/$label.ready"
  while [[ ! -f "$BARRIER/go" ]]; do sleep 0.01; done
  run_in "$dir" "" "$@"
}

run_after_barrier a "$TMP/project-a" --continue > "$TMP/out-a" 2>&1 &
pid_a=$!
run_after_barrier b "$TMP/project-b" --session session-42 > "$TMP/out-b" 2>&1 &
pid_b=$!

for _ in {1..500}; do
  [[ -f "$BARRIER/a.ready" && -f "$BARRIER/b.ready" ]] && break
  sleep 0.01
done
[[ -f "$BARRIER/a.ready" && -f "$BARRIER/b.ready" ]] \
  || fail "the parallel-launch barrier was not reached"
: > "$BARRIER/go"
wait "$pid_a" || fail "the first parallel OpenCode launch failed: $(<"$TMP/out-a")"
wait "$pid_b" || fail "the second parallel OpenCode launch failed: $(<"$TMP/out-b")"

ENV_FILE="$TEST_HOME/.config/crazycode/opencode.env"
UNIT_FILE="$TEST_HOME/.config/systemd/user/crazycode-opencode.service"
[[ -f "$UNIT_FILE" ]] || fail "the user service was not provisioned automatically"
cmp -s "$UNIT_TEMPLATE" "$UNIT_FILE" \
  || fail "the installed user service differs from the versioned template"
[[ "$(stat -c '%a' "$ENV_FILE")" == 600 ]] \
  || fail "the generated OpenCode credential file must have mode 600"

mapfile -t env_lines < "$ENV_FILE"
[[ ${#env_lines[@]} -eq 2 ]] \
  || fail "the private environment file must contain only the password and captured runtime PATH"
secret_line=${env_lines[0]}
[[ "$secret_line" =~ ^OPENCODE_SERVER_PASSWORD=[0-9a-f]{64}$ ]] \
  || fail "the credential entry must contain one validated generated password"
[[ "${env_lines[1]}" =~ ^PATH=[A-Za-z0-9_./:+@%=-]+$ ]] \
  || fail "the service must receive a validated executable search path"
expected_npx_dir=$(dirname "$(command -v npx)")
[[ "${env_lines[1]}" == *"$expected_npx_dir"* ]] \
  || fail "the captured runtime PATH must retain the Node toolchain used by MCP servers"
secret=${secret_line#*=}
first_inode=$(stat -c '%i' "$ENV_FILE")
[[ ! -e "$CANARY" ]] || fail "the invalid credential file was executed as shell code"

[[ "$(grep -c '^--user daemon-reload$' "$SYSTEMD_CALLS")" -eq 1 ]] \
  || fail "parallel first launches must provision the user unit once"
[[ "$(grep -c '^--user start crazycode-opencode.service$' "$SYSTEMD_CALLS")" -eq 1 ]] \
  || fail "parallel first launches must start the singleton service once"
[[ "$(grep -c '^auth=present$' "$META")" -eq 2 ]] \
  || fail "both attach clients must receive the generated password only in their child environment"
grep -qFx "attach http://127.0.0.1:4096 --dir $TMP/project-a --continue" "$CALLS" \
  || fail "the first attach lost its working directory or continue argument"
grep -qFx "attach http://127.0.0.1:4096 --dir $TMP/project-b --session session-42" "$CALLS" \
  || fail "the second attach lost its working directory or session argument"

printf 'activating\n' > "$SYSTEMD_STATE"
printf '1\n' > "$CURL_FAILURES"
run_in "$TMP/project-a" "$BIN_NEW" --continue > "$TMP/out-path" 2>&1 \
  || fail "the activating backend did not become ready: $(<"$TMP/out-path")"
mapfile -t updated_env_lines < "$ENV_FILE"
[[ "${updated_env_lines[0]}" == "$secret_line" ]] \
  || fail "a PATH refresh must preserve the existing backend password"
[[ "${updated_env_lines[1]}" == "PATH=$BIN_NEW:"* ]] \
  || fail "a changed launcher PATH must be written for the backend's next restart"
[[ "$(stat -c '%i' "$ENV_FILE")" != "$first_inode" ]] \
  || fail "the PATH refresh must replace the private environment file atomically"
! grep -qE '^--user (try-)?restart ' "$SYSTEMD_CALLS" \
  || fail "a PATH or unit refresh must not restart an active backend"
[[ "$(grep -c '^--user start crazycode-opencode.service$' "$SYSTEMD_CALLS")" -eq 1 ]] \
  || fail "an activating backend must not receive another start request"

printf 'failed\n' > "$SYSTEMD_STATE"
failed_out=$(run_in "$TMP/project-a" "" 2>&1) \
  && fail "a failed backend state must fail without another start attempt"
grep -qF 'systemctl --user status crazycode-opencode.service' <<< "$failed_out" \
  || fail "a failed backend must return an actionable status command"
[[ "$(grep -c '^--user start crazycode-opencode.service$' "$SYSTEMD_CALLS")" -eq 1 ]] \
  || fail "the launcher must not auto-restart a backend in failed state"

printf 'active\n' > "$SYSTEMD_STATE"
SECONDS=0
timeout_out=$(
  CURL_TEST_ALWAYS_FAIL=1 \
  CRAZYCODE_OPENCODE_READY_TIMEOUT_SECONDS=1 \
  run_in "$TMP/project-a" "" 2>&1
) && fail "an active backend that never passes authenticated health must time out"
timeout_elapsed=$SECONDS
(( timeout_elapsed >= 1 && timeout_elapsed < 4 )) \
  || fail "the readiness deadline did not honor the one-second test override (elapsed ${timeout_elapsed}s)"
grep -qF 'could not become ready' <<< "$timeout_out" \
  || fail "the readiness deadline must report the readiness failure"

[[ "$(wc -l < "$CALLS")" -eq 3 ]] \
  || fail "only successful launches may invoke one attach client each"
[[ "$(grep -c '^auth=present$' "$META")" -eq 3 ]] \
  || fail "every successful attach must receive child-scoped authentication"
if grep -v -- '--config -' "$CURL_CALLS" >/dev/null; then
  fail "every health probe must send credentials through curl config stdin"
fi
if grep -v -- '--fail' "$CURL_CALLS" >/dev/null; then
  fail "every health probe must require an authenticated HTTP success"
fi

combined="$(<"$TMP/out-a")$(<"$TMP/out-b")$(<"$TMP/out-path")$failed_out$timeout_out$(<"$CALLS")$(<"$SYSTEMD_CALLS")$(<"$CURL_CALLS")"
[[ "$combined" != *"$secret"* ]] \
  || fail "the generated password leaked into output or a process argument"
! grep -qE '(^| )(--user|-u|--password|-p)( |$)' "$CALLS" \
  || fail "attach must use environment authentication, not credential-bearing arguments"
! grep -qF 'export OPENCODE_SERVER_PASSWORD' "$CRAZYCODE" \
  || fail "the generated password must be scoped to the attach child, not exported in the parent shell"
! grep -qE '\[\[[^]]* -v OPENCODE_SERVER_PASSWORD' "$CRAZYCODE" \
  || fail "the launcher must remain compatible with Bash 4.0"
grep -qF '/proc/uptime' "$CRAZYCODE" \
  || fail "the readiness deadline must use the kernel monotonic uptime clock"
grep -qF 'CRAZYCODE_OPENCODE_READY_TIMEOUT_SECONDS:-45' "$CRAZYCODE" \
  || fail "the production readiness deadline must default to 45 seconds"
grep -qF 'Attach to shared OpenCode backend' "$CRAZYCODE" \
  || fail "CLI help must describe OpenCode's shared-backend behavior"
readme_text=$(tr '\n' ' ' < "$README")
grep -qF 'takes effect only after the shared backend is explicitly stopped or restarted' \
  <<< "$readme_text" \
  || fail "the README must explain when refreshed service settings take effect"
grep -qF 'No install or later launch implicitly restarts a running backend.' \
  <<< "$readme_text" \
  || fail "the README must not imply an automatic live rollout"

echo "PASS: concurrent shared OpenCode backend, authenticated readiness, PATH refresh, and Bash 4 behavior"
