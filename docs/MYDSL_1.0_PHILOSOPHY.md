# MyDSL 1.0 — Philosophy & Design Principles

**Status: CONFIRMED, 2026-08-25.** Written 2026-08-25 from Steven's
notes across `docs/myresponses.txt` (his own annotated copy of
`docs/OPTIMIZATION_AUDIT.md`) plus his direct chat message the same day
kicking off the "MyDSL 1.0" redesign, then reviewed independently by
Claude Desktop the same day (relayed via `HANDOFF.md`/chat, per the
usual mutual-verification loop). Both of the document's original open
questions (the connection pattern in Principle 3, and the third-party-
API sub-question in Principle 6) were decided during that review —
see those sections for the resolution. This document now supersedes
the conflicting parts of `CLAUDE.md`'s Philosophy section named in
"What this retires" below.

Two items remain genuinely open and deliberately deferred to their own
later passes, not blockers to proceeding: the mapper's DSL-specific
rewrite (its own dedicated planning pass) and the unknown-line-routing
mechanism's exact shape (deferred until the known-pattern catalog is
further along). Everything else in this document is settled. Next:
the visual/theme pass, per the sequencing below.

---

## The Global Mandate

Steven's own words, verbatim, because this is the thing every other
principle below serves:

> My global goal is to be able to take any line of text in DSL and
> know what to do with it, whether it is sent to a window, it performs
> an action, or it passes it on without editing. That is the summary
> purpose of this project and supersedes any restrictions or rules
> from now on.

Every principle below exists to make that mandate achievable. Where an
old rule conflicts with it, the old rule loses.

---

## Principle 1: One Project, Full Integration

**Old assumption, now retired:** code ported from PNP, EMCO, or the
Generic Mapper base package was treated as borrowed reference material
— read once for porting, kept separate, "not really ours," with a
standing rule against touching some of it directly (the mapper being
the clearest example).

**New rule:** if it runs in this profile, it is this project's code.
There is no more "third-party" category for anything actually
executing — no exceptions for the mapper, no exceptions for anything
else. Concretely, per Steven's own list of what that includes: "the
mapper old code," DslColors, all gameplay triggers, sounds, room pics,
aliases, keybinds/keys — "everything I use currently for gameplay
minus the mudlet base install stuff."

This does NOT mean rewriting everything from scratch on day one — it
means the standing *reason* to leave something alone ("it's someone
else's code") no longer applies. Two real, different cases the
optimization audit already surfaced, to make this concrete:

- **EMCO**: already fully resolved under the old rules, and this
  principle doesn't change anything about it. The vendored copy
  (`EMCOChat/emco.lua`) is genuinely dead — confirmed untouched since
  one old commit, never `dofile()`'d. `MyDSL_Chat.lua` already fully
  absorbed its real logic back on 2026-07-17. Nothing to do here; it's
  the model for what "fully integrated" looks like once finished.
- **The Generic Mapper**: the real case. 5,666 of its 6,631 lines are
  still unmodified stock code, genuinely running on every room and
  every line — not a dead reference copy. Steven confirmed (2026-08-25)
  the mapper is never run standalone without the rest of MyDSL loaded,
  which removes the one real correctness reason the fork's independent
  GMCP parsing existed. Per Steven's direct framing: the goal isn't a
  patch layered on someone else's package anymore — it's a mapper
  **written specifically for DSL**, using the proven stock Generic
  Mapper code as a design reference and a source of tested logic to
  carry forward, not as an external dependency to keep compatible with.
  This is real, large, separate work (see Open Questions below for how
  it should be scoped) — not something this philosophy doc itself
  attempts.

## Principle 2: Toggleable By Default

Every feature must be independently on/off so a player only runs what
they actually want. This already holds true for most View modules
(show/hide is universal), but it needs to hold for *everything*
getting pulled into full integration under Principle 1 too — a native
gameplay trigger or sound effect that gets absorbed into MyDSL's own
code doesn't get to skip having a toggle just because it used to be
native. Concretely: every module redesign summary (the pass that comes
after this philosophy doc) should state its on/off surface explicitly,
not assume it.

## Principle 3: One Way To Connect — DECIDED (2026-08-25)

The audit found the codebase currently has **three parallel patterns**
for one module to learn about another's data, used inconsistently:

1. `MyDSL.get()`/`MyDSL.set()` — the documented, intended API. Real
   usage: 1 caller of `get()`, 0 callers of `set()`, project-wide.
2. `MyDSL.on(section, callback)` — a direct Lua-callback subscription.
   Real usage: 1 module (`MyDSL_Leveling.lua`).
3. `registerAnonymousEventHandler("MyDSL.<section>.updated", ...)` +
   reading `MyDSL.State.<section>` directly — the pattern nearly
   everything else actually uses (12+ modules read `State` directly).

**Decided, Steven + Claude Desktop, 2026-08-25: standardize on pattern
3 — direct `State` reads plus event handlers.** This was originally
framed as two separable questions (a real third-party API, and a
smaller internal-hygiene chokepoint), but they turned out to be one
question asked two ways: the only real justification for a formal
Get/Set chokepoint was catching mistakes for a hypothetical outside
module author (see Principle 6 below — that justification is gone).
Once that's off the table, the remaining case for Get/Set — one place
to catch typos, one place to add logging/debouncing later — is real
but small, and comes with a genuine cost that cuts the other way:
function-call indirection added across 12 files that render on every
game tick/combat round works directly against the performance goal
this whole audit was chasing. Net: standardize on the pattern already
dominant in practice, and either delete the unused `MyDSL.get()`/
`MyDSL.set()` or repurpose them for something narrower — not migrate
everything onto them. `MyDSL.on()` (1 real caller, `MyDSL_Leveling.
lua`) is left as-is for now — narrow, working, not worth disturbing
just to enforce uniformity for its own sake.

## Principle 4: Every Line Has a Destination (the mandate, operationalized)

This is the direct mechanism for the Global Mandate above. Two parts:

**Part A — computed coverage, not a hand-written taxonomy (revised
2026-08-25).** The original plan here was a hand-maintained catalog of
known message shapes. Replaced after research into how real log-parsing
tools solve this exact problem (Grok, Fluentd, Drain) — all of them
lean toward a computed, self-updating coverage check over a
hand-written document, for the same reason this project's own
`docs/DSL_CommandRef.md` exists instead of a prose contract: a
hand-written list drifts the moment the real code changes and nothing
re-checks it. MyDSL has a real advantage those general-purpose tools
don't: almost all of its text-classification logic already exists as
literal patterns in the source itself (every `tempRegexTrigger`/
`tempAlias` PCRE pattern, every native Mudlet Trigger's regex, and the
internal `:match()`/`:find()` Lua-pattern calls that classify a line
once already inside a begin/end capture block) — there's real source
to extract from, not just game text to catalog from scratch.

Built as `scripts/check_text_coverage.py`, same spirit as
`scripts/check_known_patterns.py`: extracts every real pattern
currently in use straight from source (extraction, not paraphrase —
same technique already proven in `test/test_mapper_gmcp_and_
doorverb.lua`), runs them against the real `log/` corpus using the
actual engine each dialect really runs on (`perl` for PCRE, `luajit`
for Lua patterns — conflating the two would silently misreport
coverage, since this project has hit real bugs from that exact
confusion before), and reports which **unmatched line shapes repeat
most often** rather than a bare match percentage (which would never
hit 100% and shouldn't — plenty of narrative text has no reason to be
classified at all). A repeating unmatched shape is a real gap; a
one-off unmatched line is probably just narrative.

Building this caught 3 real methodology bugs before it ever touched
the real corpus, all found by the tool's own required self-test (one
known-covered line, one known-uncovered line, checked before trusting
any output): patterns built via runtime string concatenation
(`"%f[%a]" .. word .. "%f[%A]"`) were being mis-extracted as just their
first literal fragment; `string.find(s, pattern, init, true)`'s trailing
`true` makes the whole call a literal substring search, not a pattern
match, and was being misclassified as one; and `:gmatch()` calls
(which tokenize an already-known string, not classify a whole
incoming line) were inflating coverage with fragments like `"%a+"`
that trivially "match" almost anything. All three are documented in
the script itself, not just fixed silently.

**Checked the already-flagged expected gap rather than assuming it —
and it did NOT hold up (2026-08-25 first real run, see `docs/
CHANGELOG.md`'s entry for the actual numbers).** Spells/skills are
NOT disproportionately represented in the high-frequency unmatched
set: 0 of the top 40 unmatched shapes are spell/skill-related. This
is recorded plainly as a real result that contradicts the prior
assumption, not adjusted to match it — exactly the kind of thing this
computed approach exists to catch that a hand-written taxonomy
wouldn't have. The real top unmatched shapes turned out to be the
entire login/character-creation flow (directly relevant to the
password-in-trigger fix already in progress), room titles/descriptions
that this tool's static-pattern-extraction methodology genuinely can't
see (DSL2's own room capture works by looking backward from the
`[Exits: ...]` line, not by forward-matching the title — a real
methodology limit, not a capture gap), and Mudlet's own native
map-audit diagnostic output (correctly out of scope, not game text).
The spell/skill gap itself may still be real — this run's corpus
simply may not contain enough real spell/skill lines to surface it at
high frequency, which is itself consistent with "not every skill/spell
has been logged yet" — but that's now a stated hypothesis pending more
corpus, not a confirmed finding to build against.

**Part B — build the actual routing mechanism.** For any line that
does NOT match a cataloged pattern, the addon needs to do something
deliberate with it instead of silently letting it fall through to the
main console unclassified (today's default behavior, which is
invisible — a line either matches something and gets handled, or
nothing happens and it just sits on the main console indistinguishable
from any other unhandled line). Steven's own framing: "design a way to
manually move new lines of unknown text." This needs its own design
pass once Part A's catalog is far enough along that "unknown" is
actually a small, reviewable set rather than most of DSL's output —
building the review mechanism before the catalog exists would just
produce noise. Concrete shape not decided here; candidates worth
weighing when this gets its own design session: a dedicated "Unknown"
window that only ever shows genuinely uncataloged lines (would need a
real classifier, not just "nothing else matched," since plenty of
normal narrative text has no reason to be classified at all); a
manual flag/promote command a player can run on a line they want
looked at; or a background log file reviewed periodically rather than
a live window. This is real, separate design work — flagged as a
next-phase item, not resolved here.

## Principle 5: Security & Hygiene Baseline

One concrete, real finding folds into this philosophy as a standing
rule rather than a one-off fix: **no credentials in native trigger/
alias scripts, ever, live or in any tracked backup.** Steven found his
own login password sitting in a live Mudlet trigger — real, current
exposure, independent of the redesign timeline.

**Status, closed 2026-08-26 (superseding the two prior updates here —
first "Steven is fixing this himself," then "delivered but not yet
integrated"):** Claude Desktop built the replacement —
`MyDSL_Login.lua` + `test/test_login.lua` — Steven relayed the real
files to Claude Code via `~/Downloads/`, and Claude Code integrated and
pushed them (commit `73855b7`): answers `Player name:`/`Password:`
prompts without the credential ever touching any `MyDSL.*` table, read
from a hand-created, never-committed local file, sent with echo
suppressed, toggleable independent of configuration
(`mydsl login on|off`). Corpus-confirmed prompt strings (2026-08-26):
`"Player name:"` (no trailing space) and `"Password: "` (one trailing
space), both exact-match consistent across the entire `log/` corpus.
Independently re-verified twice over, not just trusted on either
side's report: Claude Code ran the delivered test plus 3 of its own
targeted-revert mutations; Claude Desktop separately built LuaJIT from
source and ran its own independent 3 mutations against the pushed
code. Both closed two real gaps only they individually had the access
to catch — Claude Code found `.gitignore` didn't cover the real
credential filename and that the `dofile()` wiring needed doing
(direct file access to `current/*.xml`); Claude Desktop confirmed the
`.gitignore` fix directly but flagged it has no way to independently
check the gitignored `current/*.xml` wiring itself. Still needs
Steven's own live in-game confirmation before this is fully closed —
a file edit doesn't prove Mudlet picked it up correctly.

Recorded here as a standing rule so it can't recur elsewhere as more
native content gets absorbed under Principle 1: any credential,
password, or personally identifying secret must never be typed
directly into a native trigger/alias script body. It belongs in a
local, `.gitignore`d file read at runtime, or prompted for
interactively — never committed, never embedded in exported/backup
XML.

## Principle 6: Recorded Best Practices (Mudlet/Lua)

Steven asked for an explicit best-practices reference, researched and
recorded rather than assumed, since several real bugs this project has
already hit (the `table.load()` no-return bug, `table.getn` not
existing in LuaJIT, alternation `|` not working in Lua patterns) are
exactly the kind of thing a documented checklist would catch earlier.
This section is a placeholder for that research — not yet done, listed
here so pass 2 doesn't forget to actually do it (matching Steven's
"do we need to web search... or install a plugin" offer). Known real
patterns already correctly followed project-wide, worth confirming
stay universal rather than re-deriving: the namespace guard (`MyDSL =
MyDSL or {}` at the top of every file), safe-reload trigger/handler
deregistration before re-registering, `table.save()`/`table.load(path,
target)` with the explicit two-argument form. Known real anti-patterns
already caught once, worth checking for elsewhere before this
redesign starts touching new files: alternation via `|` in Lua string
patterns (only valid in PCRE/`tempRegexTrigger`, never plain Lua
`match`/`gsub`), assuming `table.load()` has a return value, using any
`table.*` function removed at Lua 5.1 (`table.getn`, `table.foreach`).

### Sub-question: does MyDSL expose an API for other modules? — DECIDED (2026-08-25)

Steven asked directly: *"Do we have apis others can connect to if they
write a module, do we use api to talk between scripts?"* **Decided:
no.** Steven's own reasoning: he isn't sold on the need, and doesn't
expect anyone besides this project to actually write an extension
against it. A formal, documented API only earns its complexity if a
stranger needs to build against this codebase without reading the
source — with that use case gone, there's no real justification left,
and it resolves Principle 3's decision above at the same time (the
"real API" case was the only thing keeping Get/Set's chokepoint case
alive). Today's informal, inconsistent connection pattern stays
informal — just consolidated onto direct `State` access per Principle
3, not formalized into a public surface nothing will ever consume.

---

## What this retires from `CLAUDE.md`'s current Philosophy section

Specific, named changes — not "everything is up for grabs," only the
parts that directly conflict with the Global Mandate or Principle 1:

- **"Reuse PNP/EMCO source and their command vocabulary — don't
  reinvent"** (the section explaining the mapper/EMCO correction
  history) — the *reuse* half stays true as a practical default (proven
  code is still proven code, no reason to throw it away), but the
  underlying assumption that ported code stays a separate,
  arm's-length dependency is retired per Principle 1. Command
  vocabulary reuse (not making players relearn commands) stays a real
  goal independent of this change.
- **The implicit "don't touch the mapper" caution** that's shown up
  repeatedly in this project's own history (native-XML edits treated
  as higher-risk, mapper fork changes made conservatively) — retired
  specifically for the mapper's *own DSL-specific rewrite* once that
  work is scoped (see Open Questions), not a blanket license to edit
  native XML carelessly elsewhere. The general caution around native
  XML edits (verify newest-by-mtime file, confirm via package rebuild,
  etc.) stays — that's a mechanical safety practice, not a rule this
  mandate overrides.
- Everything else in `CLAUDE.md`'s Philosophy section (main console is
  sacred, move text don't replace it, never manufacture fake output,
  automate to assist not to play, percentage-based window positions,
  the already-retired automatic-commands rule) is **unaffected** —
  none of it conflicts with the Global Mandate, so none of it changes
  here.

---

## What happens after this document is confirmed

Per Steven's own sequencing, in order:

1. **This philosophy document** — confirmed between Claude Code and
   Claude Desktop, 2026-08-25. Done.
2. **Visual pass** (current step) — theme design, discussed and
   confirmed the same way, informed by which modules are being
   kept/toggleable/redesigned once step 3 exists.
3. **Module-by-module (or module-group) redesign summaries** — for
   each module: how it should work under these principles, its
   on/off surface, real interconnections, and any new features Steven
   flagged in `docs/myresponses.txt` (mob/item wiki windows,
   smarter Roller options, GroupView button redesign, etc.).
4. **Interconnection optimization pass** — using the redesign
   summaries from step 3 to fix the real duplicate-call/double-fire
   findings the audit already surfaced (`MyDSL_DataBridge.lua`'s
   11-event coalescing, `MyDSL_LocationView.lua`'s double render,
   the mapper/DataLayer duplicate GMCP parsing once Principle 1's
   mapper rewrite is scoped), plus whichever connection pattern
   Principle 3 settles on.
5. **The unknown-line-routing design** (Principle 4, Part B) — once
   Part A's known-pattern catalog is far enough along.
6. **Then, and only then, back to each module with accuracy and
   purpose** — the actual code changes, one module/group at a time,
   verified the way this project always verifies: targeted revert to
   confirm a fix is real, full test suite + `check_known_patterns.py
   --all`, live confirmation via logs where possible.

---

## Remaining open questions

Two of the original four were decided 2026-08-25 (Principle 3's
connection pattern, and the third-party-API sub-question under
Principle 6 — see those sections above for the resolution). What's
still genuinely open:

1. **Mapper rewrite scope** (Principle 1): the DSL-specific mapper
   rewrite is real, separate, large work (7x the line count the audit
   actually scoped for this file) — needs its own dedicated planning
   pass once this philosophy is confirmed, not folded into general
   module-by-module work.
2. **Unknown-line routing mechanism shape** (Principle 4, Part B): a
   window, a manual-flag command, a background log, or some
   combination — deferred until the known-pattern catalog (Part A) is
   further along.

## Separately tracked, not blocking this document

Steven found his own login password sitting in a live Mudlet trigger
while reviewing this pass (see Principle 5) — **closed 2026-08-26**:
built by Claude Desktop, integrated and pushed by Claude Code
(`73855b7`), independently re-verified by both sides separately. Only
remaining step is Steven's own live in-game confirmation, tracked in
`docs/TODO.md`, not this document.
