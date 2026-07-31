#!/usr/bin/env bash
# Verifies M28 wiring: `r` is always available, targets the selected tool, and
# never pins a session on tools that own a chooser.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRAZYCODE="$ROOT/crazycode.sh"
README="$ROOT/README.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
have() { grep -qF -- "$1" "$2"; }
has_re() { grep -qE -- "$1" "$2"; }
lacks() { ! grep -qF -- "$1" "$2"; }
lacks_re() { ! grep -qiE -- "$1" "$2"; }

[[ -f "$CRAZYCODE" ]] || fail "crazycode.sh not found at $CRAZYCODE"
[[ -f "$README"    ]] || fail "README.md not found at $README"

# Extract a multi-line array body by name: everything between `local <name>=(`
# and the closing `)`, comments stripped, blank lines dropped.
array_body() {
  awk -v name="$1" '
    $0 ~ "^[[:space:]]*local " name "=\\($" { inside = 1; next }
    inside && /^[[:space:]]*\)[[:space:]]*$/ { inside = 0 }
    inside { sub(/[[:space:]]*#.*$/, ""); if ($0 ~ /[^[:space:]]/) print }
  ' "$CRAZYCODE"
}

# ── resume_args: the per-tool chooser invocation ─────────────────────────
# Entries are anchored on their trailing `# <tool>:` comment so reordering the
# array cannot silently hand a tool another tool's flag.
has_re '^[[:space:]]*"--restore-chat-history"[[:space:]]+# aider:' "$CRAZYCODE" \
  || fail "resume_args aider entry must stay --restore-chat-history (aider has no sessions)"
has_re '^[[:space:]]*"--resume"[[:space:]]+# claude:' "$CRAZYCODE" \
  || fail "resume_args claude entry must be --resume (opens the interactive picker)"
has_re '^[[:space:]]*""[[:space:]]+# codex:' "$CRAZYCODE" \
  || fail "resume_args codex entry must be empty (resume goes through the subcommand)"
has_re '^[[:space:]]*"session --resume"[[:space:]]+# goose:' "$CRAZYCODE" \
  || fail "resume_args goose entry must stay 'session --resume' (goose has no picker)"

# forge, gemini and opencode choose the session inside their own TUI: any flag
# here would resume the most recent one instead of showing the list.
for tool in forge gemini opencode; do
  has_re "^[[:space:]]*\"\"[[:space:]]+# ${tool}:" "$CRAZYCODE" \
    || fail "resume_args ${tool} entry must be empty — ${tool} picks the session in-app"
done

# ── parallel arrays stay one entry per tool ──────────────────────────────
items_line=$(grep -E '^[[:space:]]*local items=\(' "$CRAZYCODE")
n_items=$(grep -oE '"[^"]*"' <<<"$items_line" | wc -l)
[[ "$n_items" -eq 7 ]] || fail "expected 7 tools in items, found $n_items"
for arr in launch_args resume_args resume_hints; do
  n=$(array_body "$arr" | wc -l)
  [[ "$n" -eq "$n_items" ]] || fail "$arr must have one entry per tool ($n_items), found $n"
done

# ── resume_hints: a plain-launch resume must not look like a no-op ───────
have 'resume_hints[$idx]' "$CRAZYCODE" \
  || fail "_launch_tool must print resume_hints[\$idx] under the Resuming line"
have 'inside forge to pick a conversation' "$CRAZYCODE" \
  || fail "forge hint must point at its in-app conversation picker"
have 'inside gemini to browse saved conversations' "$CRAZYCODE" \
  || fail "gemini hint must point at its in-app /resume browser"
have 'ctrl+x then l inside opencode' "$CRAZYCODE" \
  || fail "opencode hint must name the ctrl+x then l keybind"

# ── codex branch: picker restored, no-approval flags restored ────────────
have 'resume ${launch_args[$idx]}' "$CRAZYCODE" \
  || fail "codex resume must pass launch_args so it keeps the no-approval flags"
lacks 'resume --last' "$CRAZYCODE" \
  || fail "codex resume must not pass --last — it skips the session picker"

# ── the r key: always active, never overwrites the selection ─────────────
r_case=$(awk '/^[[:space:]]*\[rR\]\)/ { inside = 1 } inside { print } inside && /;;/ { exit }' "$CRAZYCODE")
[[ -n "$r_case" ]] || fail "no [rR]) case found in the input loop"
! grep -q '_last_tool' <<<"$r_case" \
  || fail "[rR]) must not reference _last_tool — r works before any tool has run"
! grep -q 'selected=' <<<"$r_case" \
  || fail "[rR]) must not overwrite selected — r resumes the highlighted tool"
grep -q '_resume=1' <<<"$r_case" \
  || fail "[rR]) must set _resume=1"

# ── help line and footer no longer hinge on a previous run ───────────────
lacks '_last_tool -ge 0 ]] && help_line' "$CRAZYCODE" \
  || fail "help line must list r unconditionally"
have '${B}r${X}${D} resume' "$CRAZYCODE" \
  || fail "help line must contain 'r resume'"
lacks 'press ${X}${B}r${X}${D} to resume' "$CRAZYCODE" \
  || fail "the last-session footer must not advertise r as resuming that session"

# ── README matches the behaviour ─────────────────────────────────────────
has_re 'r[^A-Za-z]{0,4}resume' "$README" \
  || fail "README must document the r key"
lacks_re 'resume the last session' "$README" \
  || fail "README must not describe r as resuming the last session"

echo "PASS: resume picker wiring (M28)"
