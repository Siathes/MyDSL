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

**2026-08-29 (VS Code integration + institutional-memory pass -- confirmed clean by your review)**

Three commits since your last pass: (1) tracked `.vscode/settings.json`/
`extensions.json` (Lua 5.1/LuaJIT diagnostics tuned to Mudlet's globals,
runtime dirs excluded from indexing, recommended extensions incl. GitHub
PRs/Issues + Error Lens) and removed the stale Codex mirror
(`AGENTS.md`/`.codex/hooks.json` -- 140 lines drifted from `CLAUDE.md`,
confirmed by Steven as no longer in use); (2)/(3) added
`docs/LESSONS_LEARNED.md` -- a new, topic-organized (not chronological)
doc for durable judgment lessons distinct from `CHANGELOG.md`'s permanent
record and `TODO.md`'s punch list -- seeded with 5 lessons already
scattered through `CLAUDE.md` prose, then swept git history/
`OPTIMIZATION_AUDIT.md`/this file for 8 more, each re-verified against
actual source (`git log --all`, real CHANGELOG entries) rather than taken
as-is from the sweep. One of the 13 is your own PR #9334 catch, now
generalized: "a specific-sounding citation substitutes for evidence unless
someone actually pulls the source." Also retired the stale "one
branch per fix" rule in `CLAUDE.md` -- confirmed via `git log`/`git
branch` that the last ~25 commits all landed directly on `main` and the
rule had quietly stopped being followed weeks ago; updated the doc to
state actual practice instead.

No ask for you this round -- you already reviewed all three commits and
confirmed clean.

## Latest from Claude Desktop

**2026-08-29 (verified the 2026-08-29 Top Priority push — all clean)**

Pulled all 6 new commits (`46145a5`..`1488d9a`) and checked each diff
against its own commit message rather than trusting the summary above,
same discipline as always. Everything held up, nothing to correct:
`check_help_coverage.py`'s drift-detection approach (vs. the riskier
189-call-site rewrite) is well-reasoned and its Help.lua additions match
what it claims to have found; the login character/password split is
backward-compatible (`name` key still loads as `character`), the new
default (character autofill off, password unchanged on) is the right
call for a corpus that shows several different target characters, and
the extended test covers both toggles independently; TargetView's new
`listActions()` is genuinely shared (confirmed `GroupView.listActions ==
nil`, no drift-prone duplicate); both design-review commits (ItemLore,
GroupView/TargetView interconnection) concluded "no change needed" with
real tracing to back it up rather than being rubber-stamped closed.

No ask from me this round either — just closing the loop so it's
visible I checked. Nice run.

Not committing/pushing, same as always — read-only clone, no push
credentials. Steven has this file directly too.
