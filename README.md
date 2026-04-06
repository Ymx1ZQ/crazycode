# ⚡ crazycode

A terminal launcher for AI coding tools — with a full awake-mode toggle that keeps your PC alive.

```
  ⚡  CRAZYCODE          📂 my-project
  ~/code/my-project
  ⎇  main ●
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ▶ aider           AI pair programmer  ✓
  2 claudecode      Anthropic           ✓
  3 opencode        SST                 ✗
  4 codex           OpenAI              ✓
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [c] coffeeshot ☕     [awake mode off]
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ↑↓/1-4 select  ·  enter launch  ·  c toggle  ·  q quit
  ⏱  last session: 12m 34s
  ⚠  all tools launch without asking permission
```

The menu shows your working directory, git branch (with dirty indicator ●), and returns here after exiting any tool. Session duration is displayed after each tool exit.

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/Ymx1ZQ/crazycode/main/install.sh | bash
```

This will:
1. Clone the repo into `~/.crazycode/`
2. Add `source ~/.crazycode/crazycode.sh` to your shell rc (`~/.bashrc` or `~/.zshrc`)
3. Install all optional tools by default (press `n` to skip any)
4. Show a summary of what was installed

Then reload your shell and type `crazycode`.

Flags: `--all` (install everything, no prompts), `--silent` (errors only).

## What each option does

| Option | What it does |
|--------|-------------|
| **aider** | Opens [aider](https://aider.chat) — AI pair programmer in the terminal (`--yes-always`) |
| **claudecode** | Opens [Claude Code](https://claude.ai/code) — Anthropic's official AI CLI (`--dangerously-skip-permissions`) |
| **opencode** | Opens [opencode](https://github.com/sst/opencode) — AI coding tool by SST |
| **codex** | Opens [Codex](https://github.com/openai/codex) — OpenAI's AI coding CLI (`--sandbox danger-full-access`) |
| **coffeeshot** `[c]` | Awake mode — keeps the PC fully alive: masks sleep/suspend/hibernate, disables DPMS & screensaver, ignores lid switch, disables screen lock |
| **camomile** `[c]` | Restores normal power management (toggle coffeeshot off) |

All AI tools launch **without asking permission** — full auto-approve mode.

## CLI usage

Launch tools directly without the TUI:

```bash
crazycode aider          # launch aider directly
crazycode claudecode     # launch claude code directly
crazycode coffeeshot     # toggle awake mode on/off
crazycode status         # show awake mode status
crazycode --help         # show all commands
```

Tab completion is built-in — just press `Tab` after `crazycode `.

## Manual install

```bash
git clone https://github.com/Ymx1ZQ/crazycode.git ~/.crazycode
echo 'source ~/.crazycode/crazycode.sh' >> ~/.bashrc
source ~/.bashrc
```

## Requirements

- bash 4+
- Linux (systemd) — awake mode requires `sudo` for `systemctl mask/unmask` and `logind.conf`
- `caffeine` package — for screen-awake indicator (the installer can install it for you)
- The AI tools themselves — each needs its own install (the installer walks you through them)
