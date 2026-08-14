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
