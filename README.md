# ⚡ crazycode

A terminal launcher for AI coding tools — with a full awake-mode toggle that keeps your PC alive.

```
  ⚡  CRAZYCODE          📂 my-project
  ~/code/my-project
  ⎇  main ●
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ▶ aider           Paul Gauthier       ✓
  2 claude          Anthropic           ✓
  3 codex           OpenAI              ✓
  4 forge           Tailcall            ✓
  5 gemini          Google              ✓
  6 goose           AAIF                ✓
  7 muse            Meta                ✗
  8 opencode        SST                 ✗
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [c] coffeeshot ☕     [awake mode off]
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ↑↓/1-8 select  ·  enter launch  ·  r resume  ·  c toggle awake mode  ·  q quit
  ⏱  last session: aider · 12m 34s
  ⚠  all tools launch without asking permission
```

The menu shows your working directory, git branch (with dirty indicator ●), and returns here after exiting any tool. Session duration is displayed after each tool exit.

`r` starts the highlighted tool in resume mode, from the first keystroke — nothing needs to have run first. It does not name a session: you pick that inside the tool. claude, codex and muse open their session picker on launch (`--resume` / `resume`); forge, gemini and opencode start clean and keep their picker in-app (`/conversation`, `/resume`, and `ctrl+x` then `l` respectively). goose has no picker and resumes its most recent session; aider has no sessions and reloads the directory's chat history.

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/Ymx1ZQ/crazycode/main/install.sh | bash
```

This will:
1. Clone the repo into `~/.crazycode/`
2. Add a thin wrapper to your shell rc (`~/.bashrc` or `~/.zshrc`) — updates take effect immediately, no re-source needed
3. Install all optional tools by default (press `n` to skip any)
4. Show a summary of what was installed

Then reload your shell and type `crazycode`.

Flags: `--all` (install everything, no prompts), `--silent` (errors only).

## What each option does

| Option | What it does |
|--------|-------------|
| **aider** | Opens [aider](https://aider.chat) — AI pair programmer by Paul Gauthier (`--yes-always`) |
| **claude** | Opens [Claude Code](https://claude.ai/code) — Anthropic's official AI CLI (`--dangerously-skip-permissions`) |
| **codex** | Opens [Codex](https://github.com/openai/codex) — OpenAI's AI coding CLI (`--sandbox danger-full-access`) |
| **forge** | Opens [ForgeCode](https://github.com/tailcallhq/forgecode) — Tailcall's open-source coding agent (`FORGE_TRACKER=0` set by default — opt-out of US-residency telemetry) |
| **gemini** | Opens [Gemini CLI](https://github.com/google-gemini/gemini-cli) — Google's AI coding CLI (`--yolo`) |
| **goose** | Opens [Goose](https://github.com/aaif-goose/goose) — AAIF's open-source AI agent (`GOOSE_MODE=auto` set by default — fully autonomous tool execution) |
| **muse** | Opens [Muse Code](https://developer.meta.com/ai/products/muse-code/) — Meta's AI coding CLI powered by Muse Spark (`--yolo` disables approval/sandbox — `muse resume` to resume) |
| **opencode** | Attaches to one shared [opencode](https://github.com/sst/opencode) backend per user, preserving the current directory and session controls |
| **coffeeshot** `[c]` | Awake mode — keeps the PC fully alive: masks sleep/suspend/hibernate, holds a `systemd-inhibit` idle inhibitor, ignores lid switch, disables screen lock. Snapshots the previous state to `~/.crazycode/awake.pre` first |
| **camomile** `[c]` | Restores the state saved when coffeeshot was enabled — not fixed defaults, so settings configured outside crazycode survive. With no snapshot it only drops the inhibitor and leaves lid/lock/idle alone |

All AI tools launch **without asking permission** — full auto-approve mode.

## CLI usage

Launch tools directly without the TUI:

```bash
crazycode aider          # launch aider directly
crazycode claude         # launch claude code directly
crazycode muse           # launch Muse Code directly
crazycode coffeeshot     # toggle awake mode on/off
crazycode status         # show awake mode status
crazycode --help         # show all commands
```

Tab completion is built-in — just press `Tab` after `crazycode `.

## Shared OpenCode backend

The first `crazycode opencode` launch provisions `crazycode-opencode.service`
under your user systemd manager and starts it on demand. Later terminals attach
to that same backend instead of starting another OpenCode process and another
copy of every configured MCP server. Each attach still receives its own working
directory; OpenCode's `--continue`, `--session`, and in-app session picker keep
working normally.

The service listens only on `127.0.0.1:4096`, runs as a separate unit in
`app.slice`, and authenticates clients with an automatically generated local
password. The password is stored in `~/.config/crazycode/opencode.env` with mode
`600`, is passed through the environment, and is never printed or added to a
process command line. The same private file captures the launcher's executable
search path so Node-, npm-, and uv-based MCP servers remain available under
systemd.

The service is not enabled at login. It starts on the first OpenCode launch and
can be inspected or stopped explicitly:

```bash
systemctl --user status crazycode-opencode.service
systemctl --user stop crazycode-opencode.service
```

Installing an update changes source only; it does not restart existing OpenCode
processes or roll out the shared backend. Provisioning happens only when
`crazycode opencode` is subsequently invoked. If a shared backend is already
running, crazycode may atomically refresh the installed unit and captured PATH,
but the running process keeps its current definition and environment. A
refreshed unit or captured PATH takes effect only after the shared backend is
explicitly stopped or restarted. No install or later launch implicitly restarts
a running backend.

## Manual install

```bash
git clone https://github.com/Ymx1ZQ/crazycode.git ~/.crazycode
echo 'crazycode() { source ~/.crazycode/crazycode.sh && _crazycode_main "$@"; }' >> ~/.bashrc
source ~/.bashrc
```

### From an existing clone

If you've already cloned the repo, run `./install.sh` directly — it detects the local checkout and installs from it (no network), then re-points `origin` to the canonical GitHub URL so future updates work normally.

## Requirements

- bash 4+
- `curl` and `flock` (used for shared OpenCode readiness and race-free setup)
- Linux (systemd) — awake mode requires `sudo` for `systemctl mask/unmask` and `logind.conf`
- The AI tools themselves — each needs its own install (the installer walks you through them)
