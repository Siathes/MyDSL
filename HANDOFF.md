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

**2026-08-29 (12 commits since your last pass — mapper research +
redesign is the big one, please give it a real look)**

Since `cfe0fbb`: closed the combat-condenser discussion (the "11 loops"
memory was `MyDSL_DataBridge.lua`'s already-fixed double-fire, not
`CombatView`; raw/condensed/gag mode deferred to a live play-test per
Steven). Fixed a real `.vscode/settings.json` file-size limit causing a
false "file too large" notification on the 1-2MB `MyDSL/*_db.lua` data
dumps.

**Two real code changes, both tested, please re-verify against the
actual diffs, not this summary**: `commit 97a6a83` ports upstream
`generic_mapper.xml`'s `searchRoom()` nil-guard into `map.echoPath()`
(latent on our pinned 4.20.1, confirmed real via targeted revert —
`string.upper(nil)` crashes without it); `commit 848c8aa` ports
area-export room-hash preservation (Steven confirmed using area
export/import). New tests for both:
`test/test_mapper_echopath_nil_guard.lua`,
`test/test_mapper_area_hash_preservation.lua`.

**The main event: `docs/MAPPER_REDESIGN.md` (new, commit `7579d48`)** —
consolidates a multi-pass research session (upstream sync verified
against the actual `Mudlet-5.0.0` git tag; native Mudlet C++ source
read directly — `T2DMap.cpp`/`dlgMapper.cpp`/`dlgRoomProperties.cpp`/
`dlgRoomExits.cpp`, not release notes; an 11-package ecosystem survey,
each opened and read, not just described; a direct architecture
comparison against Materia Magica/Arkadia/Shattered Isles's real
source) into one concrete design recommendation: keep native `TMap` and
GMCP-heuristic room matching (DSL sends no room vnum — confirmed
directly against our own `gmcp.room_data` handling and
`docs/DSL_CommandRef.md`, so Materia Magica's clean direct-id shortcut
genuinely isn't available to us), but split DSL-specific `map.dsl.*`
logic out of the modified stock-script copy into its own file — Mudlet's
own wiki documents the current interleaved-fork pattern as the anti-
pattern it warns against, and it's why this session's 2.1.8→2.1.10
upstream sync needed a manual diff instead of a drop-in replace.

**Ask**: this is a real architectural verdict about to inform actual
mapper rework, not just a doc update — worth your independent read
before Steven and I start acting on it, same discipline as the PR #9334
catch. Also flagged `DSL PNP 4` (a possibly-newer PNP source found on
packages.mudlet.org) — diffed, not adopted, its only real differences
are broken code (confirmed `f"..."` syntax fails on real LuaJIT) — worth
a second look if you have a moment, low stakes either way.

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
