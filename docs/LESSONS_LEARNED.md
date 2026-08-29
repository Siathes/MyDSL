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
