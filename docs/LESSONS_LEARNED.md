# DSL Observer UI — Lessons Learned

Durable process/judgment lessons only — not code patterns (those belong in
`scripts/check_known_patterns.py`, which enforces itself via the
`PostToolUse` hook) and not DSL/Mudlet's own confirmed external behavior
(those belong in `docs/DSL_CommandRef.md` or
`docs/MUDLET_PACKAGING_REFERENCE.md`). One entry per lesson: what happened,
why it matters, the rule going forward. Organized by topic, pruned like
`docs/TODO.md` once a lesson is fully absorbed into a hook, a CLAUDE.md
rule, or is otherwise no longer something a fresh session needs told —
`docs/CHANGELOG.md` already keeps the permanent chronological record, this
file is the distilled version of it, not a second copy.

---

## Source-of-truth discipline

**A spec/contract describing code will drift from the code; the code never
lies about itself.** The original 19 `Contract_*.md` files were deleted
2026-07-06 after repeatedly being found stale, contradicting each other, or
describing bugs already fixed — including at least one real bug caused by
trusting a contract's prose paraphrase instead of reading PNP's actual
tested source directly.
**Rule:** always read the actual `.lua` file being touched; treat any
distilled/summary doc (including this project's own `templates_*.txt`
pre-distilled pass) as a fast first look, never as confirmation on its own.

**A negative claim ("zero callers", "nothing uses this") is exactly the
kind of thing one missed grep variant gets wrong.** `docs/
OPTIMIZATION_AUDIT.md` section 3 originally claimed `MyDSL.
getTargetCondition()` had zero external callers; a later section's fresh
grep found two real call sites.
**Rule:** re-verify a "nothing calls this" claim with a fresh grep before
acting on it (e.g. deleting), even if it's grep-confirmed elsewhere in this
project's own docs.

**A cited test file is not proof a fix works until its existence is
checked.** Three test files (`test_mapper_fork_fixes.lua`,
`test_move_cost_weight.lua`, `test_dsl_ud_display_fix.lua`) were cited by
name across multiple `CHANGELOG.md`/`TODO.md` entries as verification for
real fixes — none ever existed anywhere in git history or on disk. Only
caught 2026-08-23 when an independent review pass actually ran
`git log --all` instead of trusting the citation.
**Rule:** when a doc cites a test file as proof a fix is covered, confirm
the file exists (`git log --all` / `ls`) before trusting the claim —
especially in any review/audit pass.

**A specific-sounding citation (a PR number, commit hash, function name)
substitutes for evidence unless someone actually pulls the source.** A
2026-07-12 decision attributed a real Mudlet docking bug to PR #9334; that
citation was trusted and repeated for over a month until 2026-08-29, when
the actual PR diff was pulled and turned out to be an unrelated
null-pointer guard with no relevant logic at all.
**Rule:** before repeating or building on a "root cause is X" claim that
names a specific external source, pull that source yourself once — don't
assume an earlier session already verified it just because the citation
reads as specific and confident.

## Cross-boundary blind spots — Lua vs. native XML

**A "zero callers"/"dead code" search that only greps `.lua` files misses
real callers living in native XML.** `MyDSL_Route.history()` was flagged
zero-callers by an initial pass; a later pass that included
`MyDSL_GameplayTriggers.xml` found 83 real callers there. This is the same
failure shape as the `getTargetCondition()` miss above, but specifically
about the Lua/XML boundary, and it has recurred.
**Rule:** a "nothing calls this"/"dead code" claim must state whether
native XML was included in the search — if the codebase spans both `.lua`
and tracked XML, search both before concluding something is unused.

**`scripts/check_known_patterns.py` only scans `.lua` files — native XML
is a standing blind spot for the same bug classes it catches in Lua.** Two
real bugs (an unconditional `deleteLine()` with no enable guard, and 30
hardcoded absolute sound paths) existed in native XML triggers and were
invisible to the automated sweep.
**Rule:** until the sweep covers native XML too (open TODO item), "the
sweep ran clean" is a claim about `.lua` files only — native XML still
needs periodic manual review for the same pattern classes.

**A live, correctly-wired-looking connection can silently reference the
wrong table name and never error.** `MyDSL_PortraitView.lua` read
`MyDSL.Windows.windows[...]`, a table that has never existed anywhere in
the codebase (the real table is `MyDSL.Windows.registry`) — Lua doesn't
error on reading a nonexistent key, so the window still visibly "worked"
via an independent fallback while its intended registry/theme/layout
wiring silently never fired.
**Rule:** when confirming module A's data reaches module B through a
shared table, verify both sides use the exact same identifier — a
typo'd/stale table name looks identical to working code in a quick check.

## Portability

**Hardcoded absolute machine-specific paths (`/home/owner/...`) recur as a
bug class across both Lua and native XML**, and have twice fooled
independent reviewers into treating a real bug as environment noise:
`MyDSL_Leveling.lua`'s seed-file fallback chain (fixed with a `selfDir()`
helper, 2026-08-24) and, separately, 30 native `<mSoundFile>` triggers
(fixed 2026-08-29).
**Rule:** derive any new file path from the file's own location
(`debug.getinfo`-based `selfDir()` pattern) rather than hardcoding
`/home/owner/...` — this is a repeat bug class, worth a
`check_known_patterns.py` rule if it recurs again.

## External API / pattern-engine verification

**A Mudlet native API's return shape needs checking against real source,
not the function name.** `searchRoom()` reads as "returns a plain array"
from its name, but Mudlet's actual C++ source returns a table keyed *by
room ID* — an `ipairs()` loop over it would have silently matched nothing,
every time, with no error. Caught only by checking the real C++ source
before shipping.
**Rule:** for any Mudlet API function whose return shape isn't certain
from the Manual, check Mudlet's real source before writing `ipairs()`/
`pairs()` code against it — a wrong assumption here fails silently.

**Confirming a function is *used* is not the same as confirming the
value it depends on is ever *populated* — a distinct question, and often
the one that actually matters.** Confirmed 2026-08-29:
`getRoomHashByID()`/`setRoomIDbyHash()`/`getRoomIDbyHash()` are real
functions called in several places in `DSL_Generic_Mapper.xml`, which
got treated as confirmation the hash-based room-identification
mechanism was live for DSL. It wasn't — none of those calls fire in
practice, because `map.prompt.hash` (what they all read) is never set
anywhere; DSL's own GMCP has no hash/vnum field to populate it from.
Caught by a second, independent pass that traced the *value*, not just
grepped for the *function names*.
**Rule:** "this function is called somewhere" only confirms the call
site exists, not that the branch is reachable — trace whether the value
it depends on is ever actually assigned before concluding a mechanism
is live, especially before treating "it's already used elsewhere" as
confirmation something works.

**Python's `re` is not real PCRE, and this project has hit real bugs from
trusting it as a stand-in.** This project has hit 3 real PCRE-vs-Lua/
Python-pattern-behavior bugs historically; the test suite's own regex
verification uses Python `re` as a "near-identical" PCRE proxy, not the
real engine.
**Rule:** any new PCRE-flavored pattern with lookahead/lookbehind or other
PCRE-specific constructs should be cross-checked against real `perl -e`
(documented in `test/README.md`) before shipping, not just Python `re`.

**A fix that assumes two independently-maintained data pipelines agree
needs that agreement checked against the real corpus, not judged plausible
from reading both code paths.** `roomLooksStale()` compares GMCP room name
vs. displayed room name from two separate pipelines; a corpus check across
all 260 logged GMCP dumps was required to confirm they actually agree, and
it surfaced a real unhandled edge case (`"darkness"` placeholder) that
code-reading alone hadn't caught.
**Rule:** when a fix's correctness depends on two live systems reporting
consistent values, verify that against the real corpus — plausible-from-
code-reading is not the same as empirically confirmed.

## Native Mudlet content vs. package-installed content

**Anything built by hand directly in Mudlet's own UI (Script/Trigger/Alias
editors) with no `packageName` can be invisible to every normal check.**
Confirmed 2026-08-23: a top-level `Aliases` group with 29 hand-built
personal aliases had no backup anywhere and would have been silently lost
on a from-scratch reinstall.
**Rule:** periodically inventory every Script/TriggerGroup/AliasGroup/
KeyGroup in the live profile's newest `current/*.xml` and confirm each one
is either git-tracked source, captured by `build_mydsl_package.py`'s
packageName-based splice, or a recognized third-party default — see
CLAUDE.md's housekeeping routine.

**`current/autosave.xml` is not reliably the most current snapshot** —
Mudlet writes numbered timestamped files into `current/` on save/close, and
`autosave.xml` itself can sit stale for tens of minutes without being
refreshed to match. Confirmed twice (2026-07-07, 2026-07-08).
**Rule:** always check `ls -t current/*.xml | head -1`, not the fixed
`autosave.xml` filename, when verifying whether a native change persisted.

## Reuse before rebuild

**Repeatedly recreating PNP/EMCO functionality from scratch instead of
reusing tested source cost real rework time** — the original motivation for
this project's "reuse PNP/EMCO source and command vocabulary" mandate
(2026-07-05). Generalized 2026-08-29 to also cover Mudlet's own native Lua
API and the wider Mudlet package community, not just PNP/EMCO — see
CLAUDE.md's "Reference material" checklist.
**Rule:** before writing new functionality, check whether an audited MyDSL
module, PNP/EMCO, Mudlet's own API, or an existing community package
already does it.
