# crazycode — Dev Plan

Archived: M1-M32 -> `DEVPLAN-ARCHIVE.md` (one line per milestone; the sha is the pointer to the full detail).

## M33: Archive the closed milestones (M1-M32) ✅

**Why:** The devplan had grown to ~12,800 words of immutable closed work nobody rereads; compressing closed milestones to a sha pointer reduces the file to whatever is still live.

**Approach:** For every milestone with heading `✅` and all tasks `- [x]` (all 32 qualified — none had an open task), re-derive the shipping sha from the *current* `git log` (never from sha strings in the devplan prose — there were none, but the repo's history was force-rewritten twice today so any such string would be untrustworthy), preferring the commit that actually ships the code+devplan over a later devplan-only bookkeeping commit (e.g. M24 uses the feature commit, not the follow-up that only added the `✅` marker). Verify each with `git cat-file -e`, write one line per milestone to `DEVPLAN-ARCHIVE.md`.

**Tasks:**
- [x] Enumerate closed milestones (heading `✅` + all tasks `- [x]`) — confirm none has an open task.
- [x] Re-derive each milestone's shipping sha from current `git log` (grep + blame cross-check), verify with `git cat-file -e`.
- [x] Write `DEVPLAN-ARCHIVE.md` with one line per milestone, ordered oldest first.
- [x] Replace the archived blocks in `DEVPLAN.md` with a pointer line.
- [x] Verify the ID set before archiving equals active + archive after (script diff).
- [x] Run `tests/*.sh` (11 files) and confirm all still pass.
- [x] Commit devplan + archive together, push to `main`.

**Done when:** `DEVPLAN.md` contains only this milestone; `DEVPLAN-ARCHIVE.md` contains 32 verified lines; the ID-set diff is empty; all 11 test scripts pass.

**Execution notes:** 32/32 milestones archived, all shas verified (0 without a findable commit). The remote history was force-rewritten a second time mid-task (an additional name redaction on M24's text, cascading new shas M24-M32) — caught before pushing, local branch reset to the new `origin/main`, all M24-M32 shas re-derived and re-verified against it (M1-M23 unaffected, same shas). ID-set diff before/after: empty (M33 is the only new ID). `tests/*.sh`: 11/11 pass, exit 0 each.

## M34: Share one OpenCode backend per user ✅

**Why:** Each direct OpenCode launch owns another backend and another full MCP process set, so concurrent terminals duplicate persistent memory and swap while exposing the same tools.

**Approach:** Route OpenCode launches through one authenticated `opencode serve` bound to loopback and managed by a user systemd service in `app.slice`; each terminal uses `opencode attach --dir` with its own working directory and existing resume arguments. Provision the unit and a private generated credential automatically from the installed checkout, without printing or passing the credential on the command line. Keep current processes untouched: this milestone changes source and tests only, with live rollout deferred for review.

**UX:** OpenCode still launches from option 8 or `crazycode opencode`; startup failures explain how to inspect the user service without exposing internal credentials.

**Tasks:**
- [x] Test: integration — prove two launches attach to one authenticated loopback service while preserving directory and arguments.
- [x] Test: security — prove credential creation is private, silent, validated, and absent from process arguments.
- [x] Implement automatic user-unit provisioning, readiness handling, attach dispatch, and actionable failures.
- [x] Preserve OpenCode resume behavior and direct argument forwarding.
- [x] Update README with shared-backend behavior, lifecycle, security, and review-only rollout status.
- [x] Run all repository test scripts and verify no existing launcher behavior regresses.

**Done when:** Hermetic tests show concurrent OpenCode launches target one authenticated loopback backend with distinct directories, all repository tests pass, and no live service or active process was changed.

**Execution notes:** Added an on-demand, authenticated loopback user service and routed fresh/resume launches through `opencode attach --dir`. Provisioning and singleton start are serialized; credential/PATH updates are atomic, preserve a valid active password, and never restart a running backend. Readiness uses authenticated curl config on stdin and a 45-second monotonic deadline, continuing through `active`/`activating` and failing explicitly on `failed`. The hermetic parallel-launch test passes, all 13 repository test scripts pass (the real-server test skips unless opted in), the isolated `opencode serve --pure` 401/200 smoke passes when enabled, systemd unit verification exits 0, and no live user unit was installed, started, or restarted.

## M35: Restore the pre-existing power state instead of hardcoded defaults ✅

**Why:** `disable_awake` restores lid, lock and idle to hardcoded values (`suspend`, `true`, `300`) rather than to whatever they were before awake mode was turned on. When those settings were deliberately configured outside crazycode — because the machine is a streaming host or an SSH server — camomile silently destroys that configuration, and the damage only surfaces later, when the closed laptop suspends or the remote desktop shows a lock screen instead of the desktop.

**Approach:** In `enable_awake`, before mutating anything, snapshot the current value of each of the four conditions to `~/.crazycode/awake.pre` (written only when absent, so a repeated enable never overwrites a snapshot with already-awake values). In `disable_awake`, restore from that snapshot instead of the fixed defaults, then delete it. When the snapshot is missing — awake enabled by an older version, or state changed externally — do not touch lid, lock or idle at all: only drop the inhibitor, and leave a message. Never unmask sleep targets that were already masked before enabling.

**UX:** Unchanged. Camomile prints one extra line when it skips restoring because no snapshot exists.

**Tasks:**
- [x] Test: enable→disable restores the exact pre-existing values, not the defaults
- [x] Test: disable without a snapshot leaves lid/lock/idle untouched
- [x] Test: repeated enable does not overwrite an existing snapshot
- [x] Implement snapshot in `enable_awake` and restore in `disable_awake`
- [x] Update README (coffeeshot/camomile table)
- [x] Run `tests/*.sh`

**Done when:** On a machine where lid/lock/idle were configured outside crazycode, a coffeeshot→camomile cycle leaves them unchanged; a camomile with no snapshot changes nothing but the inhibitor; all test scripts pass.

**Execution notes:** `enable_awake` writes `~/.crazycode/awake.pre` (mode 600) before the first
mutation and only when absent, so a repeated enable never captures already-awake values.
`disable_awake` sources it, restores lid / idle-delay / lock-enabled / KDE Autolock to the saved
values, deletes the file, and skips the unmask when `sleep_was_masked=1` — targets masked before
enabling stay masked. With no snapshot it drops only the inhibitor and prints one line. Note for
existing installs: a session already awake has no snapshot, so the first camomile after this
change is a no-op on lid/lock/idle by design. New test `tests/test_awake_snapshot.sh` (7 checks);
14/14 test scripts pass.
