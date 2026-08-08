#!/usr/bin/env bash
# Verifies M30: what the TUI actually paints, rendered the way a terminal
# renders it.
#
# The other tests read crazycode.sh or run it in CLI mode. This one drives the
# interactive menu: it runs the real TUI on a pty (util-linux `script`), then
# replays the captured byte stream through a small ANSI screen emulator
# (tests/screen.py, written here at run time — this box has neither tmux nor
# pyte) and asserts on the resulting screen: which entry is highlighted, where
# the cursor ended up, whether anything scrolled off the top.
#
# Every command awake mode touches is a stub on a scoped PATH. That is a safety
# requirement, not a convenience: the real `pkill -f 'systemd-inhibit.*'` would
# kill a genuine inhibitor and the real `gsettings set ... idle-delay 0` would
# rewrite the user's desktop settings. The argv log is asserted at the end, so a
# PATH that failed to shadow them fails the test instead of silently touching
# the machine.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRAZYCODE="$ROOT/crazycode.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
skip() { echo "SKIP: $*"; exit 0; }

[[ -f "$CRAZYCODE" ]] || fail "crazycode.sh not found at $CRAZYCODE"
command -v script  >/dev/null 2>&1 || skip "util-linux 'script' not available"
command -v python3 >/dev/null 2>&1 || skip "python3 not available"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"
LOG="$TMP/calls.log"
mkdir -p "$BIN"
: > "$LOG"

# ── stubs for everything awake mode shells out to ────────────────────────
mkstub() {
  local name="$1" body="${2:-}"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'printf "%%s\\n" "${0##*/} $*" >> "$CC_TEST_LOG"\n'
    printf '%s\n' "$body"
    printf 'exit 0\n'
  } > "$BIN/$name"
  chmod +x "$BIN/$name"
}

# `sudo -v` prints a three-line lecture, the way real sudo does on first use.
# That is what pushes the screen past its last row and scrolls the menu.
mkstub sudo            '[[ "$1" == "-v" ]] && printf "STUBLECTURE one\nSTUBLECTURE two\nSTUBLECTURE three\n"'
mkstub systemctl       '[[ "$1" == "is-enabled" ]] && echo enabled'
mkstub systemd-inhibit ''
mkstub setsid          ''
mkstub pkill           ''
mkstub kreadconfig5    ''
mkstub kwriteconfig5   ''
mkstub gsettings       'if [[ "$1" == "get" ]]; then case "$3" in idle-delay) echo "uint32 300" ;; lock-enabled) echo "true" ;; esac; fi'

# ── the screen emulator ──────────────────────────────────────────────────
cat > "$TMP/screen.py" <<'PYEOF'
#!/usr/bin/env python3
"""Replay a captured pty stream onto a virtual screen, then assert the menu.

usage: screen.py <raw-capture> <rows> <cols> <label>

The stream is cut at the last full-screen clear, which is the one `q` emits on
the way out — so what gets rendered is the last screen the user actually saw.
"""
import re
import sys
import unicodedata

CLEAR = "\x1b[H\x1b[2J"
CSI = re.compile(r"\x1b\[([0-9;?]*)([@-~])")
TOOLS = ["aider", "claude", "codex", "forge", "gemini", "goose", "opencode"]
FOOTER = "all tools launch without asking permission"


def cell_width(ch):
    return 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1


class Screen:
    def __init__(self, rows, cols):
        self.rows, self.cols = rows, cols
        self.buf = [[" "] * cols for _ in range(rows)]
        self.cy = self.cx = 0

    def scroll(self):
        self.buf.pop(0)
        self.buf.append([" "] * self.cols)

    def linefeed(self):
        self.cy += 1
        if self.cy >= self.rows:
            self.cy = self.rows - 1
            self.scroll()

    def put(self, ch):
        w = cell_width(ch)
        if self.cx + w > self.cols:
            self.cx = 0
            self.linefeed()
        self.buf[self.cy][self.cx] = ch
        for k in range(1, w):                      # cells a wide glyph covers
            if self.cx + k < self.cols:
                self.buf[self.cy][self.cx + k] = ""
        self.cx += w

    def blank(self, y, x0, x1):
        for x in range(x0, x1):
            self.buf[y][x] = " "

    def csi(self, params, final):
        if params.startswith("?"):                 # DEC private modes
            return
        args = [int(p) if p else 0 for p in params.split(";")] if params else []

        def arg(n, default):                       # 0 and "absent" both mean 1
            return args[n] if len(args) > n and args[n] else default

        if final in "Hf":
            self.cy = min(self.rows - 1, arg(0, 1) - 1)
            self.cx = min(self.cols - 1, arg(1, 1) - 1)
        elif final == "A":
            self.cy = max(0, self.cy - arg(0, 1))
        elif final == "B":
            self.cy = min(self.rows - 1, self.cy + arg(0, 1))
        elif final == "C":
            self.cx = min(self.cols - 1, self.cx + arg(0, 1))
        elif final == "D":
            self.cx = max(0, self.cx - arg(0, 1))
        elif final == "K":
            mode = args[0] if args else 0
            if mode == 0:
                self.blank(self.cy, self.cx, self.cols)
            elif mode == 1:
                self.blank(self.cy, 0, self.cx + 1)
            else:
                self.blank(self.cy, 0, self.cols)
        elif final == "J":
            mode = args[0] if args else 0
            if mode == 0:
                self.blank(self.cy, self.cx, self.cols)
                for y in range(self.cy + 1, self.rows):
                    self.blank(y, 0, self.cols)
            elif mode == 1:
                for y in range(self.cy):
                    self.blank(y, 0, self.cols)
                self.blank(self.cy, 0, self.cx + 1)
            elif mode == 2:
                for y in range(self.rows):
                    self.blank(y, 0, self.cols)
            # 3 = scrollback, nothing on screen to erase

    def feed(self, data):
        i, n = 0, len(data)
        while i < n:
            ch = data[i]
            if ch == "\x1b":
                m = CSI.match(data, i)
                if m:
                    self.csi(m.group(1), m.group(2))
                    i = m.end()
                    continue
                i += 2                             # ESC + one byte, e.g. ESC(B
                continue
            if ch == "\r":
                self.cx = 0
            elif ch == "\n":
                self.linefeed()
            elif ch == "\b":
                self.cx = max(0, self.cx - 1)
            elif ch == "\t":
                self.cx = min(self.cols - 1, (self.cx // 8 + 1) * 8)
            elif ch >= " ":
                self.put(ch)
            i += 1

    def lines(self):
        return ["".join(c for c in row if c).rstrip() for row in self.buf]


def main():
    raw_path, rows, cols, label = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    data = open(raw_path, "rb").read().decode("utf-8", "replace")

    cut = data.rfind(CLEAR)
    if cut < 0:
        print(f"FAIL [{label}]: capture holds no screen clear — the TUI never drew",
              file=sys.stderr)
        return 1
    scr = Screen(rows, cols)
    scr.feed(data[:cut])
    lines = scr.lines()

    problems = []
    marked = [i for i, l in enumerate(lines) if "▶" in l]
    if len(marked) != 1:
        problems.append(f"expected exactly one highlighted entry, found {len(marked)}")
    elif scr.cy != marked[0]:
        problems.append(
            f"cursor is on row {scr.cy + 1}, the highlighted entry is on row {marked[0] + 1}"
        )

    for tool in TOOLS:
        hits = [i + 1 for i, l in enumerate(lines) if tool in l]
        if len(hits) != 1:
            problems.append(f"entry '{tool}' appears on rows {hits}, expected exactly one")

    awake = [i + 1 for i, l in enumerate(lines) if "coffeeshot" in l or "camomile" in l]
    if len(awake) != 1:
        problems.append(f"awake line appears on rows {awake}, expected exactly one")

    leaked = [i + 1 for i, l in enumerate(lines) if "STUBLECTURE" in l]
    if leaked:
        problems.append(f"sudo output still on screen at rows {leaked}")

    if sum(FOOTER in l for l in lines) != 1:
        problems.append("footer line is missing — the screen scrolled")

    if problems:
        print(f"FAIL [{label}] on a {rows}x{cols} screen:", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        print("  rendered screen:", file=sys.stderr)
        for i, l in enumerate(lines):
            mark = "<<" if i == scr.cy else "  "
            print(f"    {i + 1:>2} |{l}|{mark}", file=sys.stderr)
        return 1

    print(f"  ok [{label}] {rows}x{cols}: menu intact, cursor on the highlighted entry")
    return 0


sys.exit(main())
PYEOF

# ── drive the TUI ────────────────────────────────────────────────────────
# Keys go in one at a time with a gap, so each is consumed by its own read.
# `stty -echo` keeps the pty from echoing them onto the screen under test.
# cwd is the temp dir: outside a git repo the header is 4 rows, which fixes
# the row arithmetic the assertions below depend on.
run_tui() {
  local raw="$1"; shift
  local k
  {
    sleep 1
    for k in "$@"; do printf '%s' "$k"; sleep 1; done
    sleep 1
  } | env PATH="$BIN:$PATH" CC_TEST_LOG="$LOG" TERM=xterm-256color DISPLAY=:0 \
        timeout 60 script -q -c "cd '$TMP' && stty -echo && bash '$CRAZYCODE'" "$raw" \
        >/dev/null 2>&1 || true
  [[ -s "$raw" ]] || fail "the TUI produced no output (capture $raw is empty)"
}

# Header 4 + 7 entries + separator + awake + separator + help + footer = 16 rows,
# and the sudo prompt row is 17.
#
# 18 rows: the prompt row is on screen and the three lecture lines scroll it.
run_tui "$TMP/toggle.raw" c q
python3 "$TMP/screen.py" "$TMP/toggle.raw" 18 100 "after the c toggle" \
  || fail "the menu is not intact after toggling awake mode"

# 16 rows: the layout fills the screen exactly, so anything the TUI prints past
# its own last row scrolls the menu up before it highlights an entry.
run_tui "$TMP/layout.raw" q
python3 "$TMP/screen.py" "$TMP/layout.raw" 16 100 "initial menu, exact fit" \
  || fail "drawing the menu scrolls it on a terminal exactly as tall as the layout"

# 80 columns is the default geometry, and the help line is two columns wider
# than that: it wraps onto the footer row, which the footer then overwrites.
python3 "$TMP/screen.py" "$TMP/layout.raw" 24 80 "initial menu, 80 columns" \
  || fail "the menu does not survive the help line wrapping at 80 columns"

# ── the stubs, not the real thing, are what ran ──────────────────────────
grep -q '^sudo -v'              "$LOG" || fail "the sudo stub was never called — PATH did not shadow the real one"
grep -q '^systemctl is-enabled' "$LOG" || fail "the systemctl stub was never called"
grep -q '^gsettings '           "$LOG" || fail "the gsettings stub was never called"
# The privileged half of enable_awake runs through sudo, so it lands in the log
# under the sudo stub — proof the toggle did its work against stubs only.
grep -q '^sudo systemctl mask ' "$LOG" || fail "enabling awake mode never reached systemctl"

echo "PASS: TUI render after the awake-mode toggle (M30)"
