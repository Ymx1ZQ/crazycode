# Devplan Archive

Closed milestones, compressed to one line each. The sha is the pointer to the
full detail (Goal/Approach/Tasks/Deviations) — it already lives in the commit
that shipped the milestone; `git show <sha>` recovers it. Shas were re-derived
from the current `git log` on 2026-08-14 (this repo's history was
force-rewritten twice today, so no sha in this file was copied from old
devplan prose — each was re-checked against `origin/main` right before this
file was committed). Ordered oldest first (newest last).

M1 | Installer script | 2026-04-05 | 4eaccb1
M2 | README | 2026-04-05 | 4eaccb1
M3 | Fix awake mode — `systemctl restart systemd-logind` kills the session | 2026-04-05 | 8e491ce
M4 | Fix sudo prompt position in the TUI | 2026-04-05 | 8e491ce
M5 | "all tools launch without asking permission" line | 2026-04-05 | 8e491ce
M6 | Installer — default "install everything", opt-out | 2026-04-05 | 8e491ce
M7 | Misc optimizations | 2026-04-05 | 8e491ce
M8 | Programmatic invocation + autocomplete | 2026-04-05 | 403e8af
M9 | TUI graphics / UX improvements | 2026-04-05 | 9f0bbc7
M10 | Installer improvements | 2026-04-05 | 2726d92
M11 | UX — return to menu, directory, terminal robustness | 2026-04-06 | 488acfc
M12 | UX — contextual info for vibecoders | 2026-04-06 | d37f1a2
M13 | UX fix — timer label + installer auto-source | 2026-04-06 | 71077d0
M14 | Thin wrapper — crazycode always up to date without re-source | 2026-04-06 | 804c03e
M15 | Installer — "a" (install all) and "s" (skip all) shortcuts for dependencies | 2026-04-06 | be4c26c
M16 | R key — resume last assistant session | 2026-04-06 | 6754b33
M17 | UX — clearer help line + bold letters | 2026-04-06 | 19bb6a1
M18 | Rename `claudecode` → `claude` + alphabetical order + homogeneous descriptions | 2026-04-08 | ce34d00
M19 | Translate `DEVPLAN.md` to English | 2026-04-08 | 88a5afc
M20 | Add `gemini` (Google Gemini CLI) as a launcher option | 2026-04-29 | efb16a3
M21 | Installer — alphabetical order + caffeine separated from assistants | 2026-04-29 | ebb6822
M22 | Replace `caffeine` with `systemd-inhibit` for the idle layer of awake mode | 2026-05-02 | 2d00335
M23 | Installer — use local checkout instead of cloning from GitHub when available | 2026-05-02 | acc8356
M24 | Add `forge` (Tailcall ForgeCode) as a launcher option | 2026-05-14 | a908363
M25 | Add `goose` (AAIF Goose CLI) as a launcher option | 2026-05-15 | 65e899b
M26 | Installer — fix `_track` false negatives when tools install to `$HOME/.local/bin` | 2026-05-15 | 8774a45
M27 | Launcher — drain stray terminal input after a child tool exits | 2026-05-23 | 6be8bb6
M28 | Launcher — `r` always available, resumes the selected tool without pinning a session | 2026-07-31 | 0c3f32d
M29 | CLI mode — user arguments land in the `resume` parameter | 2026-07-31 | d0e555e
M30 | the terminal cursor stays parked below the footer after the `c` toggle | 2026-08-08 | 5a1ad28
M31 | Add `muse` (Meta Muse Code) as a launcher option | 2026-08-12 | ba59937
M32 | Drop the point-in-time DPA note from the forge telemetry comment | 2026-08-14 | 22e9a6b
