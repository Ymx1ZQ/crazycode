# ⚡ crazycode

A terminal launcher for AI coding tools — with screen-awake and sleep-block toggles baked in.

```
  ⚡ CRAZYCODE
  ────────────────────────────────
  [a] aider          (aider-ai)
  [c] claudecode     (anthropic)
  [o] opencode       (sst)
  [x] codex          (openai)
  ────────────────────────────────
  [s] coffeeshot     (screen awake)   [off]
  [l] nosleep        (block suspend)  [off]
  ────────────────────────────────
  [q] quit
```

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/Ymx1ZQ/crazycode/main/install.sh | bash
```

This will:
1. Clone the repo into `~/.crazycode/`
2. Add `source ~/.crazycode/crazycode.sh` to your `~/.bashrc`
3. Ask one-by-one if you want to install each optional tool

Then reload your shell and type `crazycode`.

## What each option does

| Key | Name | What it does |
|-----|------|-------------|
| `a` | aider | Opens [aider](https://aider.chat) — AI pair programmer in the terminal |
| `c` | claudecode | Opens [Claude Code](https://claude.ai/code) — Anthropic's official AI CLI |
| `o` | opencode | Opens [opencode](https://github.com/sst/opencode) — AI coding tool by SST |
| `x` | codex | Opens [Codex](https://github.com/openai/codex) — OpenAI's AI coding CLI |
| `s` | **coffeeshot** | Launches `caffeine-indicator` to keep the screen on — prevents display sleep |
| `l` | **nosleep** | Masks `sleep/suspend/hibernate` systemd targets — prevents the PC from suspending |

`coffeeshot` and `nosleep` are toggles: press the key again to turn them off.

## Manual install

```bash
git clone https://github.com/Ymx1ZQ/crazycode.git ~/.crazycode
echo 'source ~/.crazycode/crazycode.sh' >> ~/.bashrc
source ~/.bashrc
```

## Requirements

- bash 4+
- Linux (systemd) — `nosleep` requires `sudo` for `systemctl mask/unmask`
- `caffeine` package — for `coffeeshot` (the installer can install it for you)
- The AI tools themselves — each needs its own install (the installer walks you through them)
