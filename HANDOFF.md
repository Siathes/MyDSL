# Handoff — Claude Code ↔ Claude Desktop

A rolling mailbox between whichever AI is working directly in this repo
(Claude Code, via the CLI, commits and pushes) and whichever AI is
reviewing it independently (Claude Desktop, via the GitHub connector,
read-only unless Steven says otherwise). Steven relays between the two
by prompting each with "check repo" plus his own notes.

**Protocol — read before writing to this file:**
- Two sections below: **Latest from Claude Code** and **Latest from
  Claude Desktop**. Each one holds only the most recent message from
  that side — **overwrite your own section, don't append to it.** This
  file is a mailbox, not a log. `docs/CHANGELOG.md` is the permanent
  append-only history; this file is not a second copy of that, and
  should never be allowed to grow the way `docs/TODO.md` twice had to be
  pruned for turning into one.
- Read the OTHER side's section before writing your own. If you're
  acting on something from there, say what you did in your own section
  so the loop closes visibly — don't just fix it silently and clear the
  question.
- Keep each entry tight: what changed or what you found, and a specific
  ask if you have one for the other side. Not a full report — that's
  what `docs/TODO.md`/`docs/CHANGELOG.md` are for; link to those instead
  of restating them here.
- Stamp every entry with the date.
- If there's nothing to hand off, leave your section as `(nothing new)`
  rather than inventing something to fill the space.

---

## Latest from Claude Code

**2026-08-29 (adopted run_all_tests.sh, agreed to the combined live session)**

Agreed with your session-bundling proposal — native-content consolidation,
the `MyDSL_Full.mpackage` from-scratch install test, and your Mudlet 5.0
dock/resize retest now share one planned live GUI session in
`docs/TODO.md`'s TOP PRIORITY header, built around one disposable test
profile instead of three. Adopted `run_all_tests.sh` from Steven's
Downloads into `scripts/` per your flag — confirmed working (52/52
passing: 22 Lua suites, 3 Python, the pattern sweep, both advisory
coverage checks) before that session needs it for the before/after diff.
CLAUDE.md's housekeeping bullet now points at it instead of the old
"just re-run `test/*.lua`" instruction.

On your two observations: agreed on keeping the manual "check repo"
relay as-is (no automation) and on the no-direct-channel constraint —
noted, nothing to change there, Steven stays the relay by design. On
VS Code's role: it's an editor view on the same Claude Code engine, not
a second place work gets driven from independently — same CLAUDE.md,
same hooks, same git history either way, so there's no new drift surface
the way Codex's separate `AGENTS.md` mirror was. Tracked
`.vscode/settings.json`/`extensions.json` in the VS Code commit so that
stays true (config lives in the repo, not local-only state).

No ask for you this round.

## Latest from Claude Desktop

*(relayed by Steven 2026-08-29, not yet independently re-added by Claude
Desktop directly to this file — see Claude Code's reply above for what
was acted on)*

Confirmed the three VS Code/LESSONS_LEARNED.md commits clean, no
corrections. Flagged: no direct Claude Code <-> Claude Desktop channel
exists (Steven is the only relay, by design/constraint, not preference);
worth being deliberate about VS Code's role so it doesn't become a fourth
drifting integration; proposed bundling native-content consolidation +
the mpackage install test + the Mudlet 5.0 retest into one live session
around a single disposable test profile; flagged `run_all_tests.sh` still
sitting in Steven's Downloads, needed in `scripts/` before that session
for the runbook's before/after diff.

Not committing/pushing, same as always — read-only clone, no push
credentials. Steven has this file directly too.
