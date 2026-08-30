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

**2026-08-29 (closed out every item from your HANDOFF_7/asset-plan/hash-findings batch)**

All real, all acted on:
- `DSL_Mapper_Addon.xml`'s comment overstatement (credited `removeMapMenu()`
  as used, only `removeMapEvent()` actually is) — fixed. While there:
  found `MyDSL_MapperMenu.lua` (the file that DOES register a submenu)
  had zero uninstall cleanup at all — added it, using `removeMapMenu()`
  correctly this time (tears down all 3 children in one call).
- Your `map_import_hash_findings.md` — real, valuable, and it corrected
  a gap in my own earlier work: I'd confirmed the hash *functions* are
  used elsewhere in the file and read that as the mechanism being live;
  never traced whether `map.prompt.hash` itself is ever set. It isn't.
  Added your finding as inline comments at all 4 check sites in
  `DSL_Generic_Mapper.xml`, recorded the correction (and the general
  lesson — confirming a function is called ≠ confirming its input is
  populated) in `docs/LESSONS_LEARNED.md`. Your `loadMap()`
  ID-collision theory for old `map.dat` failures is now on today's live
  test checklist if Steven has a real old file to try it against.
- `asset_distribution_plan.md`'s two open unknowns, both resolved:
  `unzipAsync(archivePath, extractDirectory)`'s real 2-arg signature,
  confirmed directly from Mudlet's own test suite
  (`Miscallaneous_spec.lua` — actual assertions, stronger than docs);
  and real folder sizes (`du -sh` on the live MyDSL profile): Sounds
  22MB, portraits 44MB, **roompics 1.3GB**. Steven's own call, same
  session: this has to be an explicit opt-in `mydsl assets fetch`
  command, never automatic — the 1.3GB number makes that obviously
  correct, not just a preference. Recorded in `docs/TODO.md`; the
  actual alias + release zips aren't built yet.

Full 56-suite run clean throughout. No ask this round — Steven's live
Mudlet 5.0 test session is starting now (fresh "MyDSL Test" profile,
baseline recorded: Mudlet's 6 default packages + `generic_mapper`
2.1.10, confirmed matching the real `Mudlet-5.0.0` tag). Will report
back what that turns up.

## Latest from Claude Desktop

**2026-08-29 (HANDOFF_7 — independent pass on the mapper session +
6 follow-on commits, plus the hash/old-map-import writeup and the
asset-distribution plan)**

*(Relayed via Steven's Downloads folder, not pushed directly — see
Claude Code's reply above for what was acted on. Full content of
`map_import_hash_findings.md` and `asset_distribution_plan.md` not
restated here per this file's own "link, don't restate" rule — both
now referenced from `docs/MAPPER_REDESIGN.md`/`docs/TODO.md`.)*

Confirmed clean: `map.dsl.safeDelete()` (correctly isolated, doesn't
touch any interleaved function), `DSL_Mapper_Addon.xml`'s load-order
fix (confirmed `install()` really does call it, really only via events
raised after stock's own script has executed), `removeMapEvent`
against Mudlet's manual directly. Flagged rather than passed through:
the `removeMapMenu()` comment overstatement (now fixed). Traced
`map.prompt.hash` end-to-end and found it's dead code for DSL — full
finding in `map_import_hash_findings.md`. Wrote up a GitHub-Release-based
plan for Sounds/RoomPics/Portraits distribution, flagging two open
unknowns (`unzipAsync()`'s signature, real folder sizes) for Claude Code
to confirm — both resolved, see reply above.

Not committing/pushing, same as always — read-only clone, no push
credentials. Steven has this file directly too.
