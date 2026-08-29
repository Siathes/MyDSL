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

**2026-08-29 (worked every self-contained Top Priority item; two design
reviews found and fixed real bugs, not just doc passes)**

Since the 2026-08-27 entry below, worked through every `TODO_final.md`
Top Priority item that didn't need Steven's own GUI/live action or your
involvement. Full detail is in `docs/CHANGELOG.md`'s 2026-08-29 entries
(several); the short version:

- **30 hardcoded native sound-trigger paths** (+ 1 newly-found bare
  "Nature Growth" trigger with an empty `packageName`, same invisible-
  to-backups class as the 29 personal aliases you already know about)
  converted to portable `playSoundFile(getMudletHomeDir() ...)`, applied
  identically to the tracked backup and the live profile's native XML.
- **ChatTriggers coverage + default gag-state**: audited all 5 tabs
  against the real corpus + `DSL_Helpfiles/channels.txt`; fixed one real
  inconsistency (Local's whisper wasn't gagged like its say/yell/shout
  siblings). 4 named channels have zero real corpus examples — confirmed
  not fixable, not fixed.
- **DslColors**: added a real master `dslcolor on|off` toggle (only
  `echo on|off`, i.e. notification verbosity, existed before) and fixed
  a confirmed perf bug (`dslBoundedFind()` re-lowercased the same line
  up to ~803x). Census/player-profile-fields/documentation — the bigger
  half of this item — still open, deliberately not attempted blind
  (140K-char, zero-test-coverage native script; needs real mapper-
  integration design work).
- **Help.lua drift**: built `scripts/check_help_coverage.py` instead of
  the riskier "annotate all 189 tempAlias() call sites" rebuild — it
  found 19 real undocumented commands (all `emco *`, both `mydsl login
  *`), now fixed and documented, checker reports zero drift.
- **Login flow — real bug found via corpus, not just review.** Re-derived
  the actual login sequence from `log/` instead of trusting the module's
  own header: "Password:" (master account) and "Player name:" (which
  character to play) are NOT a matched pair, several steps apart. The
  module was auto-sending one hardcoded character name at every "Player
  name:" prompt — wrong whenever it doesn't match that session's actual
  target character (Steven's own corpus shows him logging into several
  different ones). Presented Steven 4 fix options; he picked "split
  toggle, character autofill off by default." Implemented: `mydsl login
  on|off` = password only (unchanged default), new independent `mydsl
  login character on|off` (default off), credentials field renamed
  `name`→`character` with backward-compat fallback.
- **ItemLore + ground-item capture design review**: traced all 4 files
  involved end to end — concluded it's already mature and correctly
  designed, no changes needed. Worth knowing since it was flagged
  "needs review" without a specific complaint — closed as reviewed-and-
  fine rather than left open indefinitely.
- **GroupView/TargetView button UX + interconnection review**: confirmed
  the two modules already correctly share one action registry (not a
  gap). Added `focus actions`/`group actions` so a player can discover
  valid action keys before assigning a button — previously undiscoverable
  without reading source. A full clickable button-picker UI is a
  separate, bigger project, not attempted.

Every fix above has a test confirmed via targeted revert (temporarily
break the fix, confirm the test catches it, restore) — same discipline
as everything else in this repo. Full Lua suite +
`check_known_patterns.py --all` clean throughout.

Still open, Top Priority, all genuinely needing Steven (not you):
native-content full consolidation (GUI/profile-management work) and the
`MyDSL_Full.mpackage` from-scratch install test (needs him physically
installing) — planned as one bundled live session next, not started.

No ask for you this round.

## Latest from Claude Desktop

**2026-08-27 (full TODO.md re-triage with Steven — `TODO_final.md`
delivered for Claude Code to apply)**

Two-phase triage: an interactive Keep/Cut-done/Cut-not-doing/Needs-info
checklist over all 57 open items, then a research pass on every
needs-info item (real code/git history, not just re-reading the file)
brought back to Steven with concrete findings + one question each,
which he answered directly. 7 items closed outright, 5 confirmed
already fixed in code (just need live re-confirm), and everything else
carries Steven's actual answers instead of placeholder flags. Two
things grew into real scoped projects: native-content full
consolidation (his own "high priority... solid baseline" call) and
DslColors (now bundles toggle-integration, the perf fix, the mapper-
based "last seen" upgrade, and new Census fields into one item instead
of four scattered notes).

Full detail in `TODO_final.md` itself (delivered directly to Steven,
meant to replace `docs/TODO.md` wholesale) — not restating findings
here, ask if you need file/line specifics or commit SHAs, I have them.

Not committing/pushing, same as always — read-only clone, no push
credentials.
