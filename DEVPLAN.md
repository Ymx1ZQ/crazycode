# crazycode — Dev Plan

## M1: Installer script ✅

**Goal:** A single `install.sh` that:
1. Installs crazycode itself (clones the repo into `~/.crazycode/`, adds the source line to `~/.bashrc`)
2. Then, one by one, asks whether to install each optional tool

**Chosen UX:** interactive "opt-in per tool" prompt — the user sees the name, a one-line description, and answers `y/N`. No tool gets installed silently.

**Structure:**

```
install.sh
  └── phase 1: install crazycode
        - git clone git@github.com:Ymx1ZQ/crazycode.git ~/.crazycode  (or pull if it already exists)
        - add `source ~/.crazycode/crazycode.sh` to ~/.bashrc if not already present
  └── phase 2: optional tools (one by one)
        - [caffeine]     sudo apt install caffeine
        - [aider]        pipx install aider-chat  (fallback: pip install aider-chat)
        - [claude code]  curl -fsSL https://claude.ai/install.sh | bash
        - [opencode]     npm i -g opencode-ai@latest
        - [codex]        npm i -g @openai/codex
```

**Auto-detected prerequisites:**
- `pipx` — if missing, suggest `sudo apt install pipx`
- `npm` / Node.js — if missing, suggest installing via nvm
- `git` — if missing, block and warn

**Tasks:**
- [x] Write `install.sh` with phase 1 (crazycode self-install)
- [x] Add interactive prompt for each optional tool
- [x] Detect prerequisites (git, pipx, npm) and print clear warnings
- [x] Make the script idempotent (safe to re-run)
- [x] Test on a clean shell (bash -n syntax check)

---

## M2: README ✅

**Goal:** A `README.md` that explains what crazycode is, what each menu option does, and how to install it with a single command.

**Structure:**

```
README.md
  ├── Title + descriptive one-liner
  ├── Screenshot / demo (ASCII of the menu)
  ├── Quick install (single command pulled from GitHub)
  │     curl -fsSL https://raw.githubusercontent.com/Ymx1ZQ/crazycode/main/install.sh | bash
  ├── What it does — table with each menu option
  │     coffeeshot: keeps the screen on (uses caffeine-indicator)
  │     nosleep:    blocks suspend/hibernate via systemd
  │     aider / claude / codex / opencode: AI launchers
  ├── Manual install (alternative to the quickinstall)
  └── Requirements
```

**Tasks:**
- [x] Write `README.md` with all sections
- [x] Include the quickinstall one-liner (assumes `install.sh` is on main)
- [x] Add ASCII demo of the crazycode menu

---

## M3: Fix awake mode — `systemctl restart systemd-logind` kills the session ✅

**Problem:** Pressing `c` to toggle awake mode calls `sudo systemctl restart systemd-logind` (lines 87 and 105 of `crazycode.sh`). This **terminates all user sessions** — the desktop crashes and the user gets kicked out.

**Goal:** Awake mode must keep the PC always active for the user — no login screen, no standby, no screen lock. The toggle must work without destroying the session.

**Fix:**
- Replace `systemctl restart systemd-logind` with `sudo systemctl kill -s HUP systemd-logind`, which reloads the config without killing user sessions (in both `enable_awake` and `disable_awake`)
- Verify that the HUP signal is enough to apply changes to `logind.conf`

**Tasks:**
- [x] Replace `restart` with `kill -s HUP` in `enable_awake`
- [x] Replace `restart` with `kill -s HUP` in `disable_awake`
- [x] Test that the coffeeshot/camomile toggle does not kill the session

---

## M4: Fix sudo prompt position in the TUI ✅

**Problem:** When `enable_awake`/`disable_awake` asks for the sudo password, the prompt appears at the current cursor position (at the bottom of the terminal), not near the coffeeshot/camomile line. The user does not understand what is happening.

**Fix:**
- Pre-authenticate sudo before the awake commands: position the cursor on the right line (below coffeeshot/camomile) and run `sudo -v` there, so the password prompt appears in the right place
- After authentication, proceed with the sudo commands (which will use the already-active sudo token)

**Tasks:**
- [x] Add `sudo -v` with the cursor positioned below the awake line before calling `enable_awake`/`disable_awake`
- [x] Clean up any visual artifacts after entering the password
- [x] Redraw the menu after the toggle

---

## M5: "all tools launch without asking permission" line ✅

**Problem:** The user does not realize that all tools are launched without asking for permission (e.g. `--dangerously-skip-permissions`, `--yes-always`, `--sandbox danger-full-access`).

**Fix:**
- Add an informational line at the bottom of the menu, below the help line, e.g.:
  `⚠ all tools launch without asking permission`

**Tasks:**
- [x] Add the line below the help in the menu draw
- [x] Make sure it does not break the positioning of other lines (update row offsets)

---

## M6: Installer — default "install everything", opt-out ✅

**Problem:** Currently `install.sh` asks `[y/N]` for each tool (opt-in). The user wants the opposite: install everything by default; the user only says `n` to skip something.

**Fix:**
- Change the prompt from `[y/N]` to `[Y/n]`
- Invert the logic: if the user presses enter without typing anything, the tool gets installed

**Tasks:**
- [x] Change `_ask()` in `install.sh`: default to `Y`, accept `n/N` as skip
- [x] Update the prompt text (`Install? [Y/n]`)
- [x] Update the introductory message of phase 2

---

## M7: Misc optimizations ✅

### M7a: Verify tool is installed before launching

**Problem:** When the user presses enter on a tool (e.g. `aider`), the script launches it directly. If the tool is not installed, the user sees a cryptic bash error.

**Fix:** Add a `command -v` check before launching; if missing, show a clear message with installation instructions.

### M7b: Trap for terminal cleanup

**Problem:** If the user presses Ctrl+C during the menu, the terminal could be left in a dirty state (cursor hidden, echo disabled, etc.).

**Fix:** Add a `trap` to restore the terminal on EXIT/INT/TERM.

### M7c: Avoid redundant sudo

**Problem:** `enable_awake` calls `sudo` for every command. If the sudo token has expired, it asks for the password multiple times.

**Fix:** Run a single `sudo -v` at the beginning and then use the token for all the commands.

### M7d: Caffeine activation — more robust approach

**Problem:** The gdbus block (lines 71-82) for activating caffeine uses the KDE bus (`org.kde.StatusNotifierWatcher`) and is fragile. It may not work on GNOME or other DEs.

**Fix:** Consider simpler/more portable alternatives:
- `xdg-screensaver reset` in a loop
- `xset s off -dpms` as fallback
- Check whether caffeine has a CLI for activation (`caffeine-indicator --activate` or similar)

**Tasks:**
- [x] M7a: `command -v` check before launching each tool
- [x] M7b: Add trap for terminal cleanup on EXIT/INT/TERM
- [x] M7c: Single `sudo -v` before the awake commands
- [x] M7d: Replaced gdbus KDE with `xset s off -dpms` (cross-DE) + caffeine-indicator as visual indicator

---

## M8: Programmatic invocation + autocomplete ✅

**Goal:** Be able to call `crazycode <subcommand>` directly from the terminal without going through the TUI. If no argument → show the TUI as today.

**Subcommands:**
- `crazycode aider` → launch aider directly
- `crazycode claude` → launch claude code directly
- `crazycode codex` → launch codex directly
- `crazycode opencode` → launch opencode directly
- `crazycode coffeeshot` → toggle awake mode (on/off)
- `crazycode status` → show awake mode status without TUI
- `crazycode --help` → show usage with command list

**Bash autocomplete:**
- `_crazycode_completions` function registered with `complete -F`
- Completes the subcommands: `aider claude codex opencode coffeeshot status --help`
- Registration goes in the sourced file (`crazycode.sh`) so it is active as soon as it is loaded

**Installer:**
- The installer must install the completion file (or verify that the source line in bashrc activates it automatically — since `complete` is inside `crazycode.sh`, the existing source is enough)

**Tasks:**
- [x] Add argument parsing at the start of `crazycode()`: if `$1` is a known subcommand, run it directly without the TUI
- [x] Implement `crazycode coffeeshot` as a non-interactive toggle (print state after toggle)
- [x] Implement `crazycode status` (print awake mode state)
- [x] Implement `crazycode --help`
- [x] Add `_crazycode_completions` function + `complete -F` at the end of `crazycode.sh`
- [x] Verify autocomplete works after `source ~/.bashrc`

---

## M9: TUI graphics / UX improvements ✅

### M9a: Installed-tool indicator

**Problem:** The user does not know which tools are installed until they select them and press enter.

**Fix:** Show an indicator next to each tool in the menu: `✓` if installed, `✗` if missing (in dim). Use the `cmds` array for the check with `command -v`.

### M9b: Direct shortcut navigation

**Problem:** Currently you can only navigate with arrows + enter. It would be handy to press a key to go directly to a tool.

**Fix:** Add numeric shortcuts `1-4` to select and launch the corresponding tool directly.

### M9c: Detailed awake mode state

**Problem:** The menu shows only "awake mode on/off" but not which components are active.

**Fix:** When awake is partial (some checks pass, others do not), show an intermediate indicator like `[partial]` in yellow, or show the individual states on hover/expansion.

### M9d: Full redraw on terminal resize

**Problem:** If the user resizes the terminal during the menu, the layout breaks.

**Fix:** Add a trap on `WINCH` that redraws the entire menu.

**Tasks:**
- [x] M9a: Add ✓/✗ next to each tool in the menu
- [x] M9b: Add numeric shortcuts 1-4 for direct launch
- [x] M9c: Show partial awake state in yellow `[partial X/4]`
- [x] M9d: WINCH trap for resize redraw via `draw_all`

---

## M10: Installer improvements ✅

### M10a: Post-install verification

**Problem:** The installer does not verify whether each tool's installation succeeded. If `npm i -g` fails silently, the user does not know.

**Fix:** After each install, run `command -v <tool>` and show ✓ or ✗ with a clear message. At the end of the installer, print a summary table.

### M10b: `--all` / `--silent` flags

**Problem:** For automation (CI, dotfiles bootstrap), there needs to be a way to install everything without prompts.

**Fix:** Add `--all` (install everything without asking) and `--silent` (no interactive output, errors only).

### M10c: zsh support

**Problem:** The installer only modifies `~/.bashrc`. zsh users have to do it manually.

**Fix:** Detect the user's shell (`$SHELL`) and add the source line to the right rc file (`~/.bashrc` or `~/.zshrc`).

**Tasks:**
- [x] M10a: Add post-install verification per tool + summary table
- [x] M10b: Add `--all` and `--silent` flags
- [x] M10c: Detect shell and support zsh

---

## M11: UX — return to menu, directory, terminal robustness ✅

### M11a: Loop back to the menu after assistant exit

**Problem:** When you exit an assistant (with `/exit` or Ctrl+C), crazycode terminates and the user returns to the shell. It should instead return to the TUI menu.

**Fix:** Wrap the launch block (lines 376-377) in a `while true` loop. After `_launch_tool` returns, redraw the menu. The `q` key in the menu remains the only way to actually exit.

### M11b: Show current directory in the menu

**Problem:** The menu does not say which folder you are working in. The user does not know which project they are about to launch a tool against.

**Fix:** Add the pwd to the menu header. Show the project name (basename) prominently and the full path in dim below it. Update line layout accordingly.

### M11c: `stty sane` after each assistant

**Problem:** If an assistant crashes or leaves the terminal in a dirty state (echo off, raw mode), the menu breaks on return.

**Fix:** Run `stty sane 2>/dev/null` after returning from `_launch_tool`, before redrawing the menu.

### M11d: Pause on "tool not installed" error

**Problem:** With the M11a loop, the error message for an uninstalled tool would be wiped by the immediate menu redraw.

**Fix:** Add `read -rsn1 -p "  press any key..."` after the error message in `_launch_tool`, so the user has time to read it.

### M11e: Keep selection on the last tool used

**Problem:** When returning to the menu after an assistant, the cursor jumps back to the first item. It should stay on the tool just used so it can be relaunched with a single enter.

**Fix:** Do not reset `selected` in the loop. The variable already keeps the right value — just don't touch it before the redraw.

**Tasks:**
- [x] M11a: Wrap the launch in a `while true` loop with menu redraw on return
- [x] M11b: Add pwd to the header (basename + dim full path)
- [x] M11c: `stty sane` after returning from `_launch_tool`
- [x] M11d: "press any key" pause after a "tool not installed" error
- [x] M11e: Verify that `selected` is not reset in the loop

---

## M12: UX — contextual info for vibecoders ✅

### M12a: Git branch and state in the menu

**Problem:** The user does not see which branch they are working on, nor whether they have uncommitted changes — critical information before launching an AI tool.

**Fix:** Add a line to the menu header that shows the current branch and a dirty/clean indicator. Use `git rev-parse --abbrev-ref HEAD` and `git status --porcelain` (only when inside a git repo). If not a git repo, show nothing.

### M12b: Session timer

**Problem:** The user does not know how long they have spent in an assistant. Useful for tracking work time.

**Fix:** Save `$SECONDS` before launching the tool and compute the difference on return. Briefly show "last session: Xm Ys" in the menu after the return, on the line below the lower separator (or in the help line). The message disappears at the next launch.

**Tasks:**
- [x] M12a: Git branch + dirty/clean line in the menu header
- [x] M12b: Session timer with display on return to the menu

---

## M13: UX fix — timer label + installer auto-source ✅

### M13a: Clearer timer label

**Problem:** The timer shows only `⏱  9s` with no context — it is not clear that this is the duration of the last session with a tool.

**Fix:** Change the format to `⏱  last session: Xm Ys` to make the meaning clear.

### M13b: Installer auto-source

**Problem:** After installation, the `crazycode` command is not available in the current shell. The user has to manually run `source ~/.bashrc` or reopen the terminal.

**Fix:** In the installer, after adding the line to the rc file, directly `source` the crazycode.sh script in the current shell so the command is immediately available.

**Tasks:**
- [x] M13a: Add "last session:" label to the timer in the menu
- [x] M13b: Auto-source the script after installation

---

## M14: Thin wrapper — crazycode always up to date without re-source ✅

### M14a: Wrapper in the bashrc

**Problem:** After an update (`git pull` in the reinstall), the `crazycode()` function stays in memory with the old code. The user has to run `source ~/.bashrc` to load the updated version.

**Fix:** Change the loading architecture:
- `crazycode.sh` remains the main file with all the logic, but the function is renamed from `crazycode()` to `_crazycode_main()`
- In `.bashrc`/`.zshrc` the installer writes a one-liner wrapper: `crazycode() { source ~/.crazycode/crazycode.sh && _crazycode_main "$@"; }`
- Every invocation re-reads `crazycode.sh` from disk → always up to date after an update
- The installer must migrate the old `source ~/.crazycode/crazycode.sh` line to the new wrapper for users who already installed
- The bash completion stays in `crazycode.sh` (loaded on every invocation, fine)

**Tasks:**
- [x] M14a: Rename `crazycode()` → `_crazycode_main()` in crazycode.sh
- [x] M14b: Update installer to write the one-liner wrapper in the rc file (with migration from the old line)
- [x] M14c: Update post-install message (no more manual source needed after updates)

---

## M15: Installer — "a" (install all) and "s" (skip all) shortcuts for dependencies ✅

### M15a: Interactive shortcuts

**Problem:** During interactive installation of optional dependencies, the user has to answer Y/n for each one. There is no quick way to say "install all the rest" or "skip all the rest".

**Fix:** Add support to the `_ask()` function for the answers `a` (all — install this and all the following) and `s` (skip all — skip this and all the following). When the user answers `a`, set `ALL=1` so the following prompts get auto-accepted. When they answer `s`, set a `SKIP_ALL=1` flag that makes all subsequent prompts return 1. Update the prompt from `[Y/n]` to `[Y/n/a/s]`.

**Tasks:**
- [x] M15a: Add SKIP_ALL flag and a/s logic to the `_ask()` function
- [x] M15b: Update the prompt and the initial message to show the new options

---

## M16: R key — resume last assistant session ✅

**Problem:** When the user exits an assistant and returns to the menu, there is no quick way to go back to the previous session. All four tools support resume but with different flags/commands.

**Resume per tool:**
- aider: `aider --yes-always --restore-chat-history`
- claude: `claude --dangerously-skip-permissions --continue`
- opencode: `opencode --continue`
- codex: `codex resume --last` (subcommand, not a flag — overrides cmd+args)

**Fix:**
1. Add a `resume_args` array parallel to `launch_args` with the resume flags for each tool
2. For codex, special handling: resume uses a different subcommand (`codex resume --last`) instead of appending a flag
3. Track `_last_tool` (index of the last launched tool) after every launch
4. Add an `r`/`R` key in the input loop that runs `_launch_tool` in resume mode
5. Modify `_launch_tool` to accept a `--resume` flag that appends `resume_args` (or uses the special command for codex)
6. Show `r resume` in the help line only when `_last_tool` is set
7. In the timer line, add the tool name for context: `⏱  last session: aider · 12m 34s`

**Tasks:**
- [x] M16a: Add `resume_args` array and `_last_tool` variable
- [x] M16b: Modify `_launch_tool` to support resume mode
- [x] M16c: Add the R key in the input loop + update the help line
- [x] M16d: Show the tool name in the timer line

---

## M17: UX — clearer help line + bold letters ✅

**Problem:** The help line `↑↓/1-4 select · enter launch · c toggle · r resume · q quit` is not clear enough. "toggle" does not say what you are toggling, "resume" does not say what you are resuming. Also, the shortcut letters do not stand out from the descriptive text.

**Fix:**
1. **More descriptive labels:**
   - `c toggle` → `c toggle awake mode`
   - `r resume` → `r resume last session`
2. **Bold shortcut letters** (ANSI `\033[1m`): all letters/keys in the help line (`↑↓/1-4`, `enter`, `c`, `r`, `q`) get wrapped with `${B}...${X}${D}` so they stand out in bold against the surrounding dim text
3. **Timer line — resume hint:** append `— press r to resume` to the end of the `⏱  last session: ...` line, with the `r` in bold

**Tasks:**
- [x] M17a: Update the help line with descriptive labels and bold letters
- [x] M17b: Add the "press r to resume" hint to the timer line with `r` in bold

---

## M18: Rename `claudecode` → `claude` + alphabetical order + homogeneous descriptions ✅

**Problem:** Three things at once:
1. The command is called `claudecode` but the actual binary is `claude` — inconsistent.
2. The assistants in the menu are not in alphabetical order (`aider`, `claudecode`, `opencode`, `codex`).
3. The descriptions next to them are not homogeneous: `aider` describes the function (`AI pair programmer`), the other three only the vendor (`Anthropic`, `SST`, `OpenAI`).

**Fix:**

1. **Rename `claudecode` → `claude`** in all files:
   - `crazycode.sh`: `items` array, `get_color` case, `_print_help`, `_crazycode_completions`
   - `README.md`: command table, CLI example (`crazycode claude`), ASCII menu screenshot
   - `DEVPLAN.md`: only update historical textual references (M1 and M2), do not rewrite closed milestones

2. **Alphabetical order:** `aider` → `claude` → `codex` → `opencode`. Reorder the `items`, `cmds`, `descriptions`, `launch_args`, `resume_args` arrays in parallel to keep the per-index alignment. The `[1-4]` numeric shortcuts remap automatically (claude=2, codex=3, opencode=4).

3. **Homogeneous descriptions — plain vendor option:**
   ```
   aider     Paul Gauthier
   claude    Anthropic
   codex     OpenAI
   opencode  SST
   ```

**Tasks:**
- [x] M18a: Reorder the arrays in `crazycode.sh` (items/cmds/descriptions/launch_args/resume_args) and update `get_color`, `_print_help`, `_crazycode_completions` with the new `claude` name
- [x] M18b: Update `aider`'s description from `AI pair programmer` to `Paul Gauthier`
- [x] M18c: Update `README.md` (command table, CLI example, ASCII menu screenshot) with the new name and order
- [x] M18d: Update textual references to `claudecode` in `DEVPLAN.md` (only M1/M2, without rewriting closed milestones)

---

## M19: Translate `DEVPLAN.md` to English ✅

**Problem:** Per the global rule in `~/.claude/CLAUDE.md` ("Artifacts are always in English unless explicitly asked otherwise"), all project artifacts must be in English. `DEVPLAN.md` was historically written in Italian (M1 through M18), violating that rule.

**Fix:** Translate the entire `DEVPLAN.md` (M1 through M18) to English in a single rewrite. Preserve all milestone IDs, statuses (`✅`), task checkboxes, code blocks, and structure verbatim. Only natural-language prose gets translated.

**Tasks:**
- [x] M19a: Translate M1–M18 prose, headings, and task descriptions to English
- [x] M19b: Verify code blocks, command examples, and milestone IDs remain unchanged
