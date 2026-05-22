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

---

## M20: Add `gemini` (Google Gemini CLI) as a launcher option ✅

**Goal:** Add Google's Gemini CLI alongside the existing four assistants, so the menu becomes `aider · claude · codex · gemini · opencode` (alphabetical order, per M18 convention).

**Tool details:**
- Binary: `gemini`
- npm package: `@google/gemini-cli`
- Auto-approve flag: `--yolo` (skips confirmations, consistent with the project's "all tools launch without asking permission" stance)
- Resume: no native session-restore flag — leave `resume_args` empty (the `r` key will simply re-launch, same behavior as `opencode` had pre-resume support)
- Vendor description: `Google` (homogeneous with the M18 vendor-only style)

**Changes:**

1. **`crazycode.sh`:**
   - Insert `gemini` into `items`, `cmds`, `descriptions` (`Google`), `launch_args` (`--yolo`), `resume_args` (`""`) at index 3 (between `codex` and `opencode`) to preserve alphabetical order.
   - Add a `gemini` case in `get_color()` — use bold blue (`\033[1;34m`, new local `BB`) since red/cyan/yellow/white are taken.
   - Extend the numeric-shortcut handler from `[1-4]` to `[1-5]` so the new 5th item is reachable.
   - Add `gemini` to `_print_help()` output (between `codex` and `opencode`).
   - Add `gemini` to the `compgen -W` list in `_crazycode_completions()`.
   - The `num_items` variable is already derived from `${#items[@]}`, so layout/help/footer rows recompute automatically.

2. **`install.sh`:**
   - Add a new `_ask "gemini cli" "Google's AI coding CLI (npm i -g @google/gemini-cli)"` block, calling `_install_npm_tool "gemini" "@google/gemini-cli"` and `_track "gemini" "gemini"`. Place it between the `codex` and `opencode` blocks (alphabetical by tool name) — or at the end if order in the installer is purely chronological; check current style.

3. **`README.md`:**
   - Add a `gemini` row to the "What each option does" table (between `codex` and `opencode`).
   - Update the ASCII demo block to show 5 entries instead of 4 (renumbering `opencode` from `4` to `5`).
   - Update the CLI usage example list and the help-line key hint (`↑↓/1-4` → `↑↓/1-5`).

**Tasks:**
- [x] M20a: Update `crazycode.sh` arrays (`items`/`cmds`/`descriptions`/`launch_args`/`resume_args`), `get_color`, `_print_help`, `_crazycode_completions`, and the numeric-key range
- [x] M20b: Add `gemini cli` block to `install.sh` (`_ask` + `_install_npm_tool` + `_track`)
- [x] M20c: Update `README.md` table, ASCII demo (5 entries, renumbered), and any `1-4` references
- [x] M20d: Sanity-check with `bash -n crazycode.sh` and `bash -n install.sh`

---

## M21: Installer — alphabetical order + caffeine separated from assistants ✅

**Problem:** Two issues in `install.sh`:
1. The optional-tool prompts are not in alphabetical order: current order is `caffeine → aider → claude code → opencode → codex → gemini cli`. M18 already enforced alphabetical order in the TUI (`aider · claude · codex · gemini · opencode`); the installer should mirror it.
2. `caffeine` is not an AI assistant — it's a dependency of awake mode. Lumping it in the same prompt sequence as the assistants is misleading.

**Fix:**

1. **Split into two sub-sections inside phase 2**, each with its own `_section` header:
   - `Awake mode dependencies` → `caffeine`
   - `AI assistants` → `aider`, `claude code`, `codex`, `gemini cli`, `opencode` (alphabetical)

2. **Reorder the AI-assistant blocks** to alphabetical: `aider → claude code → codex → gemini cli → opencode`. The `_ask` / `_install_*` / `_track` triplets move together to keep their logic intact.

3. The `_ask` shortcuts `a` (install all) and `s` (skip all) keep working across sub-sections — they set process-wide flags (`ALL`, `SKIP_ALL`), so the visual split is purely cosmetic.

**Tasks:**
- [x] M21a: Add an `_section "Awake mode dependencies"` header before the `caffeine` block
- [x] M21b: Add an `_section "AI assistants"` header before the assistant blocks
- [x] M21c: Reorder assistant blocks alphabetically: `aider → claude code → codex → gemini cli → opencode`
- [x] M21d: Static-analysis test (`tests/test_install_order.sh`) verifying section headers + tool order
- [x] M21e: Sanity-check with `bash -n install.sh`

**Notes:** Replaced the outer `_section "Optional tools"` with the two new sub-section headers — the outer label was redundant once the phase had explicit sub-sections. The `Y install · n skip ...` legend stays gated behind the interactive guard with a leading `\n` for spacing (it used to follow `_section "Optional tools"` which provided the newline).

---

## M22: Replace `caffeine` with `systemd-inhibit` for the idle layer of awake mode ✅

**Problem:** The current "caffeine" layer of awake mode is unreliable and produces a misleading 4/4 status:

- `enable_awake` only launches `caffeine-indicator` (the AppIndicator tray icon). The Ubuntu `caffeine` package starts the indicator in **OFF** state — the actual inhibitor (`/usr/bin/caffeine`, a Python wrapper around `gnome-session-inhibit`/xdotool) is only spawned when the user clicks the tray icon. So the icon appears, but no idle-inhibition is in effect.
- `check_caffeine` declares success based on `pgrep -f caffeine-indicator`, treating the presence of the indicator process as proof of inhibition. The TUI confidently shows 4/4 while the display is free to blank/sleep.
- The `xset DPMS` fallback in `check_caffeine` is dead code on Wayland (the rooted X server reports "Server does not have the DPMS Extension"), and `xset s off -dpms` in `enable_awake` is equally a no-op there.
- The caffeine package's actual inhibitor depends on either xdotool keep-alive (broken on Wayland) or `gnome-session-inhibit` — making the whole layer indirect and fragile.

**Fix — switch to `systemd-inhibit --what=idle` as the single, authoritative idle inhibitor.** It is:

- Provided by systemd, which is already a hard prerequisite (we use `systemctl mask sleep.target` in the same function). No extra package.
- Honored by GNOME, KDE, and any logind-aware compositor on both X11 and Wayland — the desktop session itself queries `logind` for idle-inhibitors and skips idle/blank when one is held.
- Detectable authoritatively via `systemd-inhibit --list` (the OS is the source of truth, not a tray icon's process state).
- Process-scoped: if `crazycode` dies, the inhibitor is released automatically — the correct fail-safe behavior for a TUI toggle.

We tag the inhibitor with a unique `--who=crazycode-awake` so detection is exact and we never collide with other apps' inhibitors.

### Changes

1. **`crazycode.sh`:**
   - Rename state variable `caffeine_on` → `idle_inhibited` and function `check_caffeine` → `check_idle_inhibit` (used in `is_awake`, `awake_count`, and `get_awake_line`).
   - `check_idle_inhibit`: parse `systemd-inhibit --list --no-pager 2>/dev/null` and set `idle_inhibited=1` iff a row contains the `crazycode-awake` tag. Drop the `xset` fallback entirely.
   - `enable_awake`: replace the caffeine-indicator launch block with:
     ```bash
     if ! systemd-inhibit --list --no-pager 2>/dev/null | grep -q crazycode-awake; then
       setsid systemd-inhibit --what=idle --who=crazycode-awake \
         --why="crazycode awake mode" --mode=block sleep infinity \
         </dev/null >/dev/null 2>&1 &
       disown
     fi
     ```
     Drop the `xset s off -dpms` line. Remove the `command -v caffeine-indicator` / `apt install -y caffeine` block — no longer needed.
   - `disable_awake`: replace `pkill -f caffeine-indicator 2>/dev/null` with `pkill -f 'systemd-inhibit.*crazycode-awake' 2>/dev/null`. Drop the `xset s on +dpms` line. Add a one-shot `pkill -f caffeine-indicator 2>/dev/null` to clean up any legacy tray icons left behind by pre-M22 runs.
   - TUI labels: change the status row label `caffeine/dpms` → `idle inhibitor` in `_print_help`/`get_awake_line` (or wherever rendered).

2. **`install.sh`:**
   - Remove the `_section "Awake mode dependencies"` header and the `caffeine` `_ask` / `apt install` / `_track` block (lines 141–145). `systemd-inhibit` ships with systemd; nothing to install.
   - With caffeine gone, the only remaining sub-section is `AI assistants`. Promote that single header back to a plain `_section "Optional AI assistants"` (or drop the sub-section split entirely and revert to the pre-M21 single `_section`) — pick whichever reads cleaner; the goal is no orphaned single-child section.

3. **`tests/`:**
   - Delete `tests/test_install_order.sh` (its assertions about `Awake mode dependencies` and the `caffeine` block are no longer applicable).
   - Add `tests/test_awake_inhibitor.sh` (static analysis, no root needed):
     - `crazycode.sh` contains `systemd-inhibit --what=idle` and the literal tag `crazycode-awake`.
     - `crazycode.sh` no longer references `caffeine-indicator` except inside the legacy-cleanup `pkill` line.
     - `install.sh` does not contain `apt install -y caffeine` nor any `_ask "caffeine"` block.

4. **`README.md`:**
   - Line 50: drop "disables DPMS" from the coffeeshot description; replace with "holds a systemd idle-inhibitor".
   - Line 81: remove the caffeine prerequisite bullet.

### Tasks
- [x] M22a: `crazycode.sh` — rename `caffeine_on`→`idle_inhibited`, `check_caffeine`→`check_idle_inhibit`; rewrite `enable_awake`/`disable_awake`/`check_idle_inhibit` to use `systemd-inhibit`; update TUI label to `idle inhibitor`
- [x] M22b: `install.sh` — remove `_section "Awake mode dependencies"` and the `caffeine` block; collapse the remaining single sub-section into `_section "Optional AI assistants"`
- [x] M22c: Replace `tests/test_install_order.sh` with `tests/test_awake_inhibitor.sh` covering the new invariants
- [x] M22d: `README.md` — update awake-mode description and remove the `caffeine` prerequisite line
- [x] M22e: Sanity-check with `bash -n crazycode.sh && bash -n install.sh` and run `tests/test_awake_inhibitor.sh` (green); live-verified inhibitor spawn/list/kill on this Wayland session

### Notes
- `setsid … </dev/null` detaches the inhibitor from the controlling terminal so it survives the parent shell's lifecycle within the toggle session, but a unique `--who` tag guarantees `pkill` only matches our process on toggle-off.
- The `is_awake` 4-of-4 semantics are preserved (mask · idle inhibitor · lid ignored · lock disabled). What changes is just the implementation of the second layer; the user-visible "4/4" still means the same four guarantees.
- Out of scope: the `sleep_masked` and `lid_ignored` layers could in principle also be folded into a single `systemd-inhibit --what=idle:sleep:handle-lid-switch`, but that reshapes the current "permanent setting" approach (mask units, edit `logind.conf`) into a process-scoped one. Left as a possible future milestone.

---

## M23: Installer — use local checkout instead of cloning from GitHub when available ✅

**Problem:** `install.sh` always runs `git clone https://github.com/Ymx1ZQ/crazycode.git "$CRAZYCODE_DIR"` (line 105), even when the user executes the script from their own local clone of the repo. This is wasteful (re-fetches what's already on disk), requires network access to GitHub, and means a contributor testing committed local changes can't do an end-to-end install of their work via the installer without first pushing to GitHub.

**Fix:** Detect whether `install.sh` is being run from inside a local clone of the crazycode repo and, if so, use that clone as the source for `$CRAZYCODE_DIR` instead of cloning from GitHub. Preserve the canonical GitHub remote so future `git fetch` updates continue to work normally.

**Detection logic:**

1. Resolve the script's own directory:
   ```bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
   ```
2. Treat the script as running from a local checkout iff **all** of the following hold:
   - `SCRIPT_DIR` is non-empty
   - `[ -f "$SCRIPT_DIR/install.sh" ] && [ -f "$SCRIPT_DIR/crazycode.sh" ]` — sanity-check that the directory actually looks like a crazycode checkout (not just any random git repo that happens to host an `install.sh`)
   - `git -C "$SCRIPT_DIR" rev-parse --show-toplevel` succeeds and its output equals `$SCRIPT_DIR` (script lives at the repo toplevel)
   - `SCRIPT_DIR` is not equal to `$CRAZYCODE_DIR` itself (avoid cloning the destination onto itself in the fresh-install path)

When `install.sh` is piped through `curl … | bash`, `BASH_SOURCE[0]` resolves to something like `/dev/stdin` or `/dev/fd/63`; the sanity-check `[ -f "$SCRIPT_DIR/crazycode.sh" ]` fails and the logic falls through to the GitHub-clone path. (Verify in M23d.)

**Install logic when local checkout is detected:**

- If `$CRAZYCODE_DIR/.git` already exists (existing install): unchanged path — `git fetch && reset --hard @{u}` against the already-configured remote (typically GitHub). Local detection only affects the *fresh* install.
- If `$CRAZYCODE_DIR` does not exist:
  - `git clone "$SCRIPT_DIR" "$CRAZYCODE_DIR"` — uses hardlinks under the hood, near-instant, no network.
  - `git -C "$CRAZYCODE_DIR" remote set-url origin https://github.com/Ymx1ZQ/crazycode.git` so future `git pull`s go to GitHub, not back to the developer's working tree.
  - Print an `_info` line: `installed from local checkout at <SCRIPT_DIR>`.

In the GitHub fall-through path, also print an `_info` line so the source is always visible: `cloning from github.com/Ymx1ZQ/crazycode`.

**Out of scope (deliberate):**

- Picking up uncommitted changes from the local checkout. `git clone <local-path>` copies committed state only; uncommitted edits in the working tree are not transferred. A contributor who wants to test uncommitted work should commit first (or use the dev checkout directly without going through the installer). Adding rsync-of-working-tree behavior would change the contract of "the installer gives you a clean, repo-backed `~/.crazycode`" and is left for a future milestone if the need surfaces.
- `--local` / `--remote` override flags. Auto-detection should be unambiguous; flags add API surface for a need that doesn't yet exist.

**Tasks:**
- [x] M23a: Add `SCRIPT_DIR` resolution and the local-checkout detection (toplevel git repo + `crazycode.sh` sanity check + self-clone guard) to `install.sh`
- [x] M23b: Branch the `git clone` step on detection — clone from `"$LOCAL_SRC"` and re-point `origin` to the GitHub URL when local; clone from GitHub otherwise
- [x] M23c: Add `_info` lines indicating the source used (local path vs GitHub) on both branches
- [x] M23d: Add a static-analysis test (`tests/test_install_local_checkout.sh`) verifying that `install.sh` contains the detection guards (`BASH_SOURCE`, `crazycode.sh` sanity check, `remote set-url`) — covers the invariant without needing to actually run the installer
- [x] M23e: Sanity-check with `bash -n install.sh`; runtime-verified both branches in a sandbox (local-checkout from `./install.sh` and curl-pipe fall-through via stdin)

### Notes
- During implementation, surfaced a real bug in the initial draft: when piped via `curl … | bash`, `BASH_SOURCE[0]` is "main" (not a file path) and `dirname` defaults to `.`, leaking the caller's cwd as a false-positive "local checkout" if cwd happened to be a checkout itself. Fix: gate the resolution on `[[ -f "${BASH_SOURCE[0]:-}" ]]` so non-file invocations short-circuit to the GitHub path. Caught by the runtime sandbox, not the static-analysis test — the static test remains useful as a regression net but cannot replace exercising the actual code path.
- Final variable name is `LOCAL_SRC` (not `SCRIPT_DIR` as drafted) — `SCRIPT_DIR` is a transient holding the resolved path; `LOCAL_SRC` is the validated "this is a usable crazycode checkout" tag, set only when all guards pass.

---

## M24: Add `forge` (Tailcall ForgeCode) as a launcher option ✅

**Goal:** Add ForgeCode — the post-leak, Apache-2.0, Rust-native coding agent from Tailcall Inc. that currently leads Terminal-Bench 2.0 (#2 with GPT-5.4 at 81.8%, #4 with Claude Opus 4.6 at 79.8%) — as the 6th launcher in crazycode. ForgeCode is the candidate runtime evaluated for replacing Claude Code in the sibling the production project project (see the production project `devplan/v0.x.md` M10), and crazycode is the surface used to exercise it side-by-side with the other assistants. Final menu order (alphabetical, per M18 convention): `aider · claude · codex · forge · gemini · opencode`.

**Tool details:**
- Binary: `forge`
- npm package: `@antinomyhq/forge` (backward-compat alias kept by Tailcall after the org rename from `antinomyhq` → `tailcallhq`; the canonical repo is `github.com/tailcallhq/forgecode`)
- Auto-approve: ForgeCode's interactive TUI does not gate tool execution behind per-call permission prompts (unlike Claude Code's `--dangerously-skip-permissions` or Codex's `--sandbox` switches), so no explicit yolo flag is needed — `launch_args` stays empty. If a future ForgeCode release introduces gated mode, revisit and add the equivalent flag here.
- Resume: ForgeCode resumes via `forge --conversation-id <id>` or `forge conversation resume <id>` — both require an explicit id, no `--last` shortcut. Leave `resume_args` empty for now; pressing `r` in the TUI will simply re-launch ForgeCode and let the user pick the conversation via its in-TUI list. Revisit if ForgeCode adds a `--continue`-style flag.
- Vendor description: `Tailcall` (homogeneous with the M18 vendor-only style; the company is Tailcall Inc., Dover DE, founder Tushar Mathur)
- Telemetry default-off: `FORGE_TRACKER=0` is exported by `_launch_tool` immediately before exec'ing `forge`. ForgeCode telemetry defaults to on, processes events on US infrastructure, and Tailcall's DPA is documented as "in preparation via Vanta" (Discussion #2545, May 2026). For a tool that gets invoked across many user repos and that may also be evaluated as a the production project runtime, opt-out by default is the conservative posture. The export is scoped to the `forge` index inside `_launch_tool` so it is visible and reviewable in source rather than implicit in a wrapper. Users who want telemetry on can unset the variable in their shell after launch.

**Changes:**

1. **`crazycode.sh`:**
   - Insert `forge` into `items`, `cmds`, `descriptions` (`Tailcall`), `launch_args` (`""`), `resume_args` (`""`) at index 3 (between `codex` at 2 and `gemini` at 4) to preserve alphabetical order. All five parallel arrays shift in sync.
   - Add a `forge` case in `get_color()` — use bold magenta (`\033[1;35m`, new local `BM`) since red/cyan/yellow/blue/white are taken by the other five.
   - Extend the numeric-shortcut handler from `[1-5]` to `[1-6]` so the new 6th item (`opencode`, now at index 5 → key `6`) is reachable.
   - In `_launch_tool`, before `exec`/invocation of `forge`, run `FORGE_TRACKER=0 ${cmd}` (per-call env export, no global side effects). Implementation choice: a small case-match inside `_launch_tool` keyed on `tool == forge` rather than threading a new "env" array — keeps the array shape consistent with the existing five tools, and the privacy default is locally readable.
   - Add `forge` to `_print_help()` output (between `codex` and `gemini`) with a one-line note `(FORGE_TRACKER=0 set by default)` after the description to make the privacy default discoverable.
   - Add `forge` to the `compgen -W` list in `_crazycode_completions()`.
   - `num_items` derives from `${#items[@]}`, so the layout rows recompute automatically; verify the footer rows still fit (the existing layout already absorbed the +1 from `gemini` in M20, so +1 more for `forge` is structurally identical).

2. **`install.sh`:**
   - Add a new `_ask "forge" "Tailcall's AI coding CLI (npm i -g @antinomyhq/forge)"` block, calling `_install_npm_tool "forge" "@antinomyhq/forge"` and `_track "forge" "forge"`. Place it between the `codex` and `gemini cli` blocks (alphabetical order, matching the M21 convention in the installer's optional-tools sub-section).

3. **`README.md`:**
   - Add a `forge` row to the "What each option does" table (between `codex` and `gemini`), with a parenthetical: `(FORGE_TRACKER=0 set by default — opt-out of US-residency telemetry)`.
   - Update the ASCII demo block to show 6 entries instead of 5, renumbering `gemini` from `4` → `5` and `opencode` from `5` → `6`.
   - Update the CLI usage example list to mention `crazycode forge` and the help-line key hint (`↑↓/1-5` → `↑↓/1-6`).

4. **`tests/`:**
   - Add `tests/test_forge_launcher.sh` (static analysis) covering: (a) `forge` appears in the `items` and `cmds` arrays in `crazycode.sh`; (b) `_launch_tool` exports `FORGE_TRACKER=0` for the `forge` index; (c) `install.sh` has an `_ask "forge"` block calling `_install_npm_tool "forge" "@antinomyhq/forge"`; (d) `README.md` mentions `forge` and `FORGE_TRACKER=0` in the tools table.

**Tasks:**
- [x] M24a: Update `crazycode.sh` arrays (`items`/`cmds`/`descriptions`/`launch_args`/`resume_args`), `get_color`, `_print_help`, `_crazycode_completions`, numeric-key range `[1-6]`, and the `FORGE_TRACKER=0` export in `_launch_tool`
- [x] M24b: Add `forge` block to `install.sh` (`_ask` + `_install_npm_tool` + `_track`), between `codex` and `gemini cli`
- [x] M24c: Update `README.md` table, ASCII demo (6 entries, renumbered), and `1-5` → `1-6` references
- [x] M24d: Add `tests/test_forge_launcher.sh` static-analysis check
- [x] M24e: Sanity-check with `bash -n crazycode.sh && bash -n install.sh` and run `tests/test_forge_launcher.sh` (green)

### Notes
- Telemetry default: keeping `FORGE_TRACKER=0` per-launch rather than as a one-shot install-time env mutation avoids leaking into other shells and is reversible per-invocation. The trade-off is mild redundancy in the script; the upside is that the default is auditable in one place (`_launch_tool`) regardless of how the user updates ForgeCode later.
- Out of scope: a `--with-telemetry` flag to opt back in via crazycode, and any deeper ForgeCode configuration (model selection, `FORGE_CONFIG`). Users who need those configure them via ForgeCode's own mechanism — crazycode is a launcher, not a config manager.

---

## M25: Add `goose` (AAIF Goose CLI) as a launcher option ✅

**Goal:** Add Goose — the open-source, extensible AI agent recently transferred from Block to the **Agentic AI Foundation (AAIF)** under the Linux Foundation — as the 7th launcher in crazycode. Goose's CLI executes shell tools, edits files, and runs tests against any LLM provider; it complements the existing six by being the only entry that is (a) provider-agnostic by design and (b) governed by a foundation rather than a single vendor. Final menu order (alphabetical, per M18 convention): `aider · claude · codex · forge · gemini · goose · opencode`.

**Tool details:**
- Binary: `goose`
- Installer: `curl -fsSL https://github.com/aaif-goose/goose/releases/download/stable/download_cli.sh | bash` (no sudo; installs to `$HOME/.local/bin` by default — same path family pipx uses for `aider`, so no new PATH handling is needed beyond what already exists). The script auto-runs `goose configure` (interactive) on completion unless `CONFIGURE=false` is set — we **must** set it to keep `install.sh --all`/`s`(skip-all) non-interactive. Users configure their LLM provider later by running `goose configure` themselves.
- Auto-approve: env var `GOOSE_MODE=auto` (other values: `approve` / `smart_approve` / `chat`). `auto` is the fully-autonomous mode — coherent with crazycode's "all tools launch without asking permission" stance (line 5 of the menu footer, added in M5). Same pattern as `FORGE_TRACKER=0` in M24: per-launch env export inside `_launch_tool`, no global shell mutation.
- Resume: native `goose session --resume` (long form) / `goose session -r` (short form). Without `--name`/`--session-id` it resumes "the most recently used session" (verified against `crates/goose-cli/src/cli.rs` in `aaif-goose/goose@main`, lines 845–847). This makes `goose` the second launcher (after `codex`) where resume requires a **subcommand override** rather than appending a flag — reuse the existing codex-style branch in `_launch_tool` (introduced in M16) rather than threading a new mechanism. `resume_args` for goose carries `session --resume`.
- Vendor description: `AAIF` (homogeneous with `SST` / `Google` / `OpenAI` / `Tailcall`; the full name "Agentic AI Foundation @ Linux Foundation" is 30 characters wide and would break the menu column alignment — acronym is the right trade-off here).

**Changes:**

1. **`crazycode.sh`:**
   - Insert `goose` into `items`, `cmds`, `descriptions` (`AAIF`), `launch_args` (`""` — the auto-approve is via env var, not CLI flag), `resume_args` (`session --resume`) at index 5 (between `gemini` at 4 and `opencode` which moves from 5 → 6). All five parallel arrays shift in sync.
   - Add a `goose` case in `get_color()` — use **bold green** (`\033[1;32m`, new local `BG`); red/cyan/yellow/white/bold-blue (gemini)/bold-magenta (forge) are taken by the other six.
   - Extend the numeric-shortcut handler from `[1-6]` to `[1-7]` so the new 7th item (`opencode`, now at index 6 → key `7`) remains reachable.
   - In `_launch_tool`, mirror the M24 forge pattern: before invoking `goose`, export `GOOSE_MODE=auto` (per-call, scoped to that exec). Implementation: extend the existing case-match keyed on tool name — `forge` got its `FORGE_TRACKER=0` export there, `goose` slots in alongside it. Keep both exports local; do not refactor into a shared "env" array (premature abstraction for two cases).
   - Resume path: extend the existing codex-style subcommand-override branch in `_launch_tool` to also cover `goose` (the override is `goose session --resume`, populated from `resume_args`). M16 already established the override mechanism — we are adding a second tool that uses it, not creating a new path.
   - Add `goose` to `_print_help()` output (between `gemini` and `opencode`) with a one-line note `(GOOSE_MODE=auto set by default)` to make the auto-approve default discoverable, in the same style as M24's `FORGE_TRACKER=0` line.
   - Add `goose` to the `compgen -W` list in `_crazycode_completions()`.
   - `num_items` derives from `${#items[@]}`, so layout rows recompute automatically; verify the footer rows still fit (gemini and forge each added +1 in M20/M24, structurally identical here).

2. **`install.sh`:**
   - Add a new `_ask "goose" "AAIF's open-source AI agent (curl installer, no sudo)"` block, between the `gemini cli` and `opencode` blocks (alphabetical order, matching M21 convention). Body:
     ```bash
     if _ask "goose" "AAIF's open-source AI agent (curl installer, no sudo)"; then
       CONFIGURE=false curl -fsSL https://github.com/aaif-goose/goose/releases/download/stable/download_cli.sh | bash
       _ok "goose installed"
     fi
     _track "goose" "goose"
     ```
   - `CONFIGURE=false` is **load-bearing**: without it the upstream script invokes `goose configure` interactively at the end, which would hang `install.sh --all` and break `s` (skip-all) flows by re-prompting the user mid-batch.
   - No new helper function needed — the `claude code` block (line 171) already uses an inline `curl … | bash` pattern; we follow the same shape for consistency.
   - `_track "goose" "goose"` uses `command -v goose`, which can return `fail` even after a successful install if `$HOME/.local/bin` is not in the installer subshell's `PATH`. This is a pre-existing limitation that already affects `aider` (pipx installs to the same path) and is **not** in scope for M25 — fixing it would require a separate milestone touching the `_track` helper. Document the caveat in the milestone notes.

3. **`README.md`:**
   - Add a `goose` row to the "What each option does" table (between `gemini` and `opencode`), with a parenthetical: `(GOOSE_MODE=auto set by default — fully autonomous tool execution)`.
   - Update the ASCII demo block to show 7 entries instead of 6, renumbering `opencode` from `6` → `7`.
   - Update the CLI usage example list to mention `crazycode goose` and the help-line key hint (`↑↓/1-6` → `↑↓/1-7`).

4. **`tests/`:**
   - Add `tests/test_goose_launcher.sh` (static analysis) covering:
     - (a) `goose` appears in the `items` and `cmds` arrays in `crazycode.sh`;
     - (b) `_launch_tool` exports `GOOSE_MODE=auto` for the `goose` index;
     - (c) `resume_args` for `goose` contains `session --resume` and the subcommand-override branch in `_launch_tool` matches `goose` (regression net for the codex-style path reuse);
     - (d) `install.sh` has an `_ask "goose"` block invoking `download_cli.sh` with `CONFIGURE=false` set;
     - (e) `README.md` mentions `goose` and `GOOSE_MODE=auto` in the tools table.

**Tasks:**
- [x] M25a: Update `crazycode.sh` arrays (`items`/`cmds`/`descriptions`/`launch_args`/`resume_args`), `get_color`, `_print_help`, `_crazycode_completions`, numeric-key range `[1-7]`, the `GOOSE_MODE=auto` export in `_launch_tool` — goose resume uses the generic path with `resume_args="session --resume"` (no codex-style override needed since `launch_args` is empty)
- [x] M25b: Add `goose` block to `install.sh` (`_ask` + inline `CONFIGURE=false curl | bash` + `_track`), between `gemini cli` and `opencode`
- [x] M25c: Update `README.md` table, ASCII demo (7 entries, renumbered), and `1-6` → `1-7` references
- [x] M25d: Add `tests/test_goose_launcher.sh` static-analysis check
- [x] M25e: Sanity-check with `bash -n crazycode.sh && bash -n install.sh` and run `tests/test_goose_launcher.sh` (green). Also relaxed `tests/test_forge_launcher.sh`'s range assertions from literal `[1-6]` to `\[1-[4-9]\]` so M24's regression net survives future range bumps without needing to be rewritten each milestone

### Notes
- Repo provenance: `github.com/block/goose` redirects to `github.com/aaif-goose/goose` (45k stars, same SHA history). The transfer is the legitimate handover from Block to AAIF/Linux Foundation; this is the canonical Goose, not a fork. Using `aaif-goose/goose` directly in `download_cli.sh` URL future-proofs against the redirect being eventually removed.
- `CONFIGURE=false` is the only deviation from "run the upstream installer verbatim". An alternative would be to pipe `yes "" |` into the configure prompt, but that depends on goose's interactive UX (multiple prompts, provider/model selection) and would silently pick a default LLM provider for the user — worse UX than letting them run `goose configure` once, intentionally, on first launch.
- Out of scope: (1) auto-running `goose configure` on first crazycode launch of goose (would require state-tracking inside `crazycode.sh` and is fragile); (2) PATH-fixup for `$HOME/.local/bin` in `_track` (pre-existing limitation; deserves its own milestone — see M26); (3) provider/model pre-configuration via `GOOSE_PROVIDER`/`GOOSE_MODEL` env vars (crazycode is a launcher, not a config manager — same principle as M24's exclusion of `FORGE_CONFIG`).

---

## M26: Installer — fix `_track` false negatives when tools install to `$HOME/.local/bin` ✅

**Problem:** `install.sh`'s post-install verification (`_track`, introduced in M10a) calls `_has "$2"` which is `command -v $2 >/dev/null`. The installer subshell inherits the caller's `PATH` at invocation time and does not re-read the rc file mid-script — so if the user runs `install.sh` from a shell where `$HOME/.local/bin` is not yet in `PATH`, the summary table at the end will show `✗` for any tool installed there, **even when the install succeeded**. This affects:

1. **`aider`** — pipx installs to `$HOME/.local/bin`. `_ensure_pipx` calls `pipx ensurepath` after installing pipx, which updates the user's rc file but **does not** mutate the current subshell's `PATH`. So a fresh-machine run where pipx itself was just installed → `_track "aider" "aider"` returns `fail` despite a successful `pipx install aider-chat`.
2. **`goose`** (once M25 lands) — the upstream `download_cli.sh` installs to `$HOME/.local/bin` by default and explicitly tells the user to add the dir to PATH if it isn't already. Same `_track` false negative.

The false negative is purely cosmetic — the tool works fine in any new shell the user opens — but it undermines the summary table's authority: an `✗` should mean "something is wrong", not "your PATH didn't reflect the install at script-time".

**Fix — prepend `$HOME/.local/bin` to `PATH` once, at the start of phase 2, before the first `_ask`/`_track` cycle:**

```bash
# Phase 2 may install tools into $HOME/.local/bin (pipx, goose). pipx ensurepath
# and goose's installer update the rc file but not this subshell — so prepend
# the dir here so _track's command -v probe sees the binaries it just installed.
export PATH="$HOME/.local/bin:$PATH"
```

Place the export **after** the `_section "Optional AI assistants"` header and **before** the first `_ask` block (currently `aider`, line 161). The prepend is idempotent — re-running the installer with the dir already on PATH is a no-op (same dir twice in PATH is harmless and the shell deduplicates on lookup).

**Why prepend and not append:** if a system-wide stale binary exists in `/usr/local/bin` with the same name, prepending makes the freshly-user-installed one win in `command -v`. This matches what a properly-configured user PATH already does (since `pipx ensurepath` prepends, not appends).

**Alternatives considered and rejected:**

- **Fallback in `_has`**: change `_has` to also test `[ -x "$HOME/.local/bin/$1" ]`. Rejected: `_has` is used in multiple places (the `git`/`pipx`/`npm` prereq checks) where a fallback to `~/.local/bin` could mask real PATH misconfigurations. A magical fallback inside a 3-line helper is harder to audit than an explicit `export PATH` at a well-marked location.
- **Per-tool path argument to `_track`**: `_track "goose" "goose" "$HOME/.local/bin/goose"`. Rejected: forces every tool entry to know its install path, adds noise, and creates a third place where `~/.local/bin` must be remembered (besides pipx config and goose's installer). The single `export PATH` covers all current and future user-local installers.
- **Re-source the rc file mid-script**: `source "$RC_FILE"`. Rejected: rc files run user-defined code (aliases, prompt theming, network calls) that have no business executing inside an unattended installer subshell.

**Tasks:**
- [x] M26a: Add the `export PATH="$HOME/.local/bin:$PATH"` line at the start of phase 2 in `install.sh`, with the explanatory comment block above it
- [x] M26b: Add new `tests/test_install_path_prepend.sh` asserting: (i) `install.sh` contains the literal `export PATH="$HOME/.local/bin:$PATH"`, (ii) the export appears **after** the `_section "Optional AI assistants"` header (so it's inside phase 2, not before), (iii) the export appears **before** the first phase-2 `_ask` block — line-number comparison via awk to skip the unrelated `_ask "pipx"` inside `_ensure_pipx`
- [x] M26c: Sanity-check with `bash -n install.sh` (green) and all four other tests still pass

### Notes
- M26 is independent of M25 in the strict sense — the aider false-negative existed before goose was added. But the goose addition raises the visibility (two `~/.local/bin` tools instead of one), which is why this milestone surfaced now rather than at M10a's introduction. Implementation order is flexible: M26 can land before or after M25; either ordering works since the export is harmless when no `~/.local/bin` tools are involved.
- Out of scope: doing the same PATH-prepend at the top of `crazycode.sh` (the launcher). The launcher only runs interactively in the user's own shell where PATH is already set up correctly via the rc file. A defensive prepend there would be cargo-culting — only the installer subshell has the gap.

---

## M27: Launcher — drain stray terminal input after a child tool exits ✅

**Problem:** When a child TUI (`opencode`, `claude`, `gemini`, …) exits, it leaves bytes in the terminal's input buffer. During shutdown these TUIs query the terminal — *cursor-position report* (DSR), *primary device attributes* (DA1), etc. — and the terminal's **responses** (escape sequences such as `\x1b[33;3R` or `\x1b[?64;1;…c`) land in stdin **after** the child has already exited.

crazycode's TUI loop then returns to its input loop (`crazycode.sh:359`) and `read -rsn1 key` (`crazycode.sh:365`) consumes those leftover bytes as if they were keystrokes:

1. `ESC` + 2 chars is eaten as a (failed) arrow-key parse (`crazycode.sh:368-369`);
2. the digits remaining in the response fall through to the numeric-key case `[1-7]` (`crazycode.sh:410-416`);
3. a stray `3` → `num_idx=2` → `selected=2` → **codex launches by itself**.

Observed symptom: quitting `opencode` immediately re-opens `codex` (or another tool, depending on the exact response bytes). `stty sane` at `crazycode.sh:429` restores terminal modes but does **not** flush the pending input buffer.

**Fix — drain pending input after the child exits, before the menu redraws:**

Right after `stty sane 2>/dev/null` (`crazycode.sh:429`), discard everything still buffered:

```bash
# Drain stray input the child TUI left behind. Terminal query responses
# (cursor-position / device-attributes reports) arrive after the child has
# exited; without this the menu's read loop consumes them as keystrokes —
# a stray digit launches whatever tool maps to it (e.g. opencode → codex).
local _drain
while read -rsn1 -t 0.05 _drain; do :; done
```

Each `read` consumes one buffered byte instantly; once the buffer is empty the final `read` blocks for the 50 ms timeout and exits the loop. 50 ms is generous for query responses (they return within milliseconds) and imperceptible to the user.

**Why this placement:** the drain belongs in the TUI loop only, after a child returns. CLI mode (`crazycode opencode`) runs one tool and exits the process — no menu loop to protect. crazycode's own startup needs no drain (no child has run yet).

**Alternatives considered and rejected:**

- **Suppress the terminal queries** (e.g. wrap the child so it can't probe the terminal): impossible — the queries come from inside each third-party TUI; crazycode cannot patch them.
- **`stty` flush / `tcflush`**: bash has no portable `tcflush`, and `stty` has no portable "flush input" action. The timed-`read` drain is the standard, portable bash idiom.
- **Drain at the top of the input loop instead**: same effect, but draining once right after the child exits is clearer and keeps the hot input loop free of a per-iteration cost.

**Tasks:**
- [x] M27a: Add the timed-`read` drain loop (with the comment block above) immediately after `stty sane 2>/dev/null` in the TUI loop of `crazycode.sh`
- [x] M27b: Add `tests/test_input_drain.sh` (static analysis) asserting (i) `crazycode.sh` contains a `while read -rsn1 -t <timeout> …` drain loop, (ii) it appears after the `stty sane` line (i.e. inside the TUI loop, post-child)
- [x] M27c: Sanity-check with `bash -n crazycode.sh` and run the full `tests/` suite green

### Notes
- Root cause is generic to all child TUIs, not opencode-specific — `opencode → codex` is just the most reproducible pairing because opencode emits a query whose response contains a `3` as the first standalone digit. The fix covers every tool.
- Out of scope: draining inside `_launch_tool` for CLI mode (the process exits right after, nothing reads the buffer).
