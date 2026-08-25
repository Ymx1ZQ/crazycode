#!/usr/bin/env bash

set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
skip() { echo "SKIP: $*"; exit 0; }

[[ "${CRAZYCODE_TEST_REAL_OPENCODE:-0}" == 1 ]] \
  || skip "set CRAZYCODE_TEST_REAL_OPENCODE=1 for the isolated opencode serve smoke"
command -v opencode >/dev/null 2>&1 || skip "opencode is not installed"
command -v curl >/dev/null 2>&1 || skip "curl is not installed"

TMP="$(mktemp -d)"
server_pid=""
cleanup() {
  if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

TEST_HOME="$TMP/home"
LOG="$TMP/server.log"
PASSWORD="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
PORT="${CRAZYCODE_TEST_OPENCODE_PORT:-$((45000 + ($$ % 10000)))}"
URL="http://127.0.0.1:$PORT/global/health"
mkdir -p "$TEST_HOME"

if curl --silent --output /dev/null --max-time 1 "$URL"; then
  fail "isolated smoke port $PORT is already in use"
fi

HOME="$TEST_HOME" OPENCODE_SERVER_PASSWORD="$PASSWORD" \
  opencode serve --pure --hostname 127.0.0.1 --port "$PORT" > "$LOG" 2>&1 &
server_pid=$!

SECONDS=0
unauth_code=000
while (( SECONDS < 45 )); do
  kill -0 "$server_pid" 2>/dev/null \
    || fail "opencode serve exited before readiness: $(<"$LOG")"
  unauth_code=$(curl \
    --silent --output /dev/null --write-out '%{http_code}' --max-time 1 \
    "$URL" 2>/dev/null || true)
  [[ "$unauth_code" == 401 ]] && break
  sleep 0.1
done
[[ "$unauth_code" == 401 ]] \
  || fail "unauthenticated health never returned 401 within 45 seconds (last $unauth_code)"

auth_code=$(
  printf 'user = "opencode:%s"\n' "$PASSWORD" \
    | curl --config - --silent --fail --output /dev/null \
        --write-out '%{http_code}' --max-time 2 "$URL"
) || fail "authenticated health request failed"
[[ "$auth_code" == 200 ]] \
  || fail "authenticated health returned $auth_code instead of 200"
(( SECONDS < 45 )) || fail "authenticated readiness exceeded 45 seconds"

server_args=$(tr '\0' ' ' < "/proc/$server_pid/cmdline")
[[ "$server_args" != *"$PASSWORD"* ]] \
  || fail "the OpenCode server password appeared in process arguments"

echo "PASS: real isolated opencode serve requires auth and answers health within 45 seconds"
