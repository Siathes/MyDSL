# DSL Observer UI — Claude Code Instructions

## Project
Modular 4-layer passive observation UI for Dark and Shattered Lands (DSL),
a MUD running in Mudlet 4.20.1. Profile: this directory.

**This system is universal, not character-specific.** Kien (W-Elf Druid,
True Neutral, Arkane kingdom) is the current primary test character, but the
UI must work correctly for any logged-in character. Never hardcode a
character name, class, or race into logic. All persistent state must be
keyed by the logged-in character name (see "Character-binding" below) —
per-character data derived from GMCP/login/score output, not assumed.

## Workflow (Claude.ai removed 2026-07-05; docs restructured 2026-07-06)
It's Steven and Claude Code working directly from this repo — no design
relay through a separate chat, no upload/download dance with a project
folder. Claude Code reads source, logs, and PNP reference material straight
off disk and owns keeping `docs/TODO.md` and `docs/CHANGELOG.md` current.

**2026-07-06: the 19 per-module `Contract_*.md` files, `SESSION_START.md`,
`SYNC.md`, `DSL_SessionNotes.md`, and `docs/README.md` were all deleted.**
They were built for a workflow where Claude.ai designed a module and Claude
Code implemented it *from* the contract — the contract came first. Now the
code comes first and gets edited directly, so a separate spec describing it
has nothing forcing it to stay in sync and reliably drifts (this happened
repeatedly — contracts describing bugs already fixed in code, contradicting
each other, and at least one bug caused by trusting a contract's prose
paraphrase instead of PNP's actual tested source). The principle now: **docs
only hold what git history and the code can't already tell you.** That's:
- `docs/TODO.md` — a small, *current* punch list. Resolved items get
  pruned, not archived — `CHANGELOG.md`/git log already have that record
  permanently. If `TODO.md` looks like it's turning back into a growing
  append-only history, prune it.
- `docs/CHANGELOG.md` — one line per real change, append-only. This one
  doesn't decay — each line is a historical fact that never needs updating.
- `docs/LESSONS_LEARNED.md` — added 2026-08-29: durable process/judgment
  lessons that aren't a code pattern (those go in
  `scripts/check_known_patterns.py` instead, since a mechanical check
  enforces itself) and aren't about DSL/Mudlet's own external behavior
  (those go in `docs/DSL_CommandRef.md` or
  `docs/MUDLET_PACKAGING_REFERENCE.md`). One entry per lesson: what went
  wrong or was confirmed, why, and the rule going forward. Organized by
  topic, not chronology — like `TODO.md`, prune an entry once it's fully
  absorbed into a hook, a CLAUDE.md rule, or is otherwise no longer
  something a fresh session needs telling. `CHANGELOG.md` already has the
  permanent chronological record; this file is the distilled "don't repeat
  this" reference, not a second copy of it.
- `docs/DSL_CommandRef.md` — confirmed regex/output patterns for DSL
  itself. High-value because it's about an external, stable system (DSL's
  text doesn't change), not our own code (which does).
- `docs/OPTIMIZATION_AUDIT.md` — the project-wide audit/optimization pass
  opened 2026-08-23, one section per `MyDSL_*.lua` file (what it does,
  public surface, dependencies, candidate cruft, performance flags — all
  grep-confirmed, not assumed), plus Steven's own per-file notes once he's
  reviewed a section. Unlike `TODO.md`, this one doesn't get pruned as it
  resolves — it's a standing reference for how each module's actual shape
  compares to its intent, kept as long as the audit stays active. Extended
  2026-08-26 with a second pass (sections 41-44) covering the native XML
  content (mapper's stock code, DslColors, gameplay triggers, personal
  aliases) pass 1 explicitly scoped out.
- `docs/MYDSL_1.0_MODULE_REDESIGN.md` — the module-by-module pass
  (step 3 of the 1.0 sequencing, done 2026-08-26): for every audited
  module, its Toggle/Connection/Verdict against the philosophy doc's
  principles. Built strictly from the audit's own findings, not
  re-derived — read this before `OPTIMIZATION_AUDIT.md` when the
  question is "does this module comply with 1.0," not "what does this
  module do."
- `docs/MYDSL_1.0_ROADMAP.md` — the persistent execution plan added
  2026-08-26: where the whole 1.0 effort stands right now, a per-module
  status table across all 44 audited units, and the phase order for the
  work still left before "feature complete" can be declared. Read this
  first when picking the 1.0 effort back up — it says what to do next
  without re-deriving it from the audit/redesign docs each time. Update
  it as phases close; don't let it silently go stale.
- `docs/MUDLET_PACKAGING_REFERENCE.md` — Mudlet's confirmed packaging
  behavior (read directly from its C++ source, not guessed) plus the one
  governing rule this project failed to apply to its own delivery
  workflow: **uninstall the old `MyDSL_Full` package before installing a
  new one, every time** — reinstalling on top silently nests content
  (confirmed live 2026-08-26: Keys had accumulated 16 levels of
  self-nested wrapper folders). **Read this before every
  `build_mydsl_package.py` run and every package delivery to Steven.**
- The actual `.lua` files — how something currently works. Always read
  these directly; there is no separate spec describing them anymore.
- `notes_utf8.txt` (profile root) — Steven's informal scratch/question
  channel, not a formal doc.

## IMPORTANT — Read before touching any file
1. Read `docs/TODO.md` first, every session — the current punch list.
   Skim `docs/LESSONS_LEARNED.md` too (added 2026-08-29) — short, so this
   costs little, and it's exactly the durable judgment-call mistakes a
   fresh session would otherwise repeat.
2. Read the actual `.lua` file for any module being edited — there is no
   separate contract/spec anymore; the code is the only source of truth for
   how something currently works.
3. Read `docs/DSL_CommandRef.md` for any in-game text pattern you need to
   parse or match — it has the confirmed real output and the fix patterns.
   Add to it (don't create a parallel file) whenever a new pattern is
   confirmed during testing/auditing.
4. Check the live MyDSL profile's own `notes_utf8.txt`
   (`~/.config/mudlet/profiles/MyDSL/notes_utf8.txt`) for anything newer
   than the last session's work — Steven writes bug reports and ideas
   there while actually playing, separate from whatever he says directly
   in chat (confirmed real, non-trivial content found there 2026-08-23
   after a ~1-month gap in this repo's own commit history). Reconcile
   anything found into `docs/TODO.md`, don't let it sit unread.
5. Check `HANDOFF.md` (repo root) — added 2026-08-23 as a rolling
   mailbox between this session and Claude Desktop (an independent
   reviewer, connected read-only via GitHub; Steven relays between the
   two by prompting each with "check repo" plus his own notes). Read the
   other side's section, act on anything real, and overwrite your own
   section with what you did — this file is a mailbox, not a log; don't
   let it grow the way `docs/TODO.md` twice had to be pruned for.
6. Read `docs/MUDLET_PACKAGING_REFERENCE.md` before running
   `build_mydsl_package.py` or delivering a package to Steven — every
   time, not just when something looks wrong (added 2026-08-26 after the
   16-deep KeyGroup nesting incident; this is Steven's own explicit ask
   for "somewhere you read every time you make a package").

### Housekeeping routine (adopted 2026-08-23)
No durable cron/scheduled-agent mechanism fits this project well — cloud
routines can't see the local Mudlet profiles/logs this project depends on,
and session-local cron dies with the session — so "keep things organized
and current" is a checklist folded into normal session work instead of a
background job:
- **Every session, near the start** (covered by item 1 above plus this):
  run `python3 scripts/check_known_patterns.py --all` once — cheap, catches
  any known-bad-pattern instance that landed in a file the per-edit hook
  never saw touched this session.
- **Periodically, independent of any specific fix**: re-run the full test
  suite via `scripts/run_all_tests.sh` (adopted 2026-08-29 — single entry
  point for every `test/*.lua`/`test/*.py` file plus
  `check_known_patterns.py --all`, hard-gated, with the text/help coverage
  checks run advisory alongside; `./scripts/run_all_tests.sh > run1.log
  2>&1` to save a baseline for a before/after diff), not just right after
  a fix that prompted a claim of "clean." Originally added 2026-08-23 per
  a Claude.ai review pass, which had no `luajit` available in its own
  environment and couldn't independently verify `docs/CHANGELOG.md`'s "all
  tests re-run clean" claims — a fair point: those claims are only as good
  as the session that made them, and a periodic independent re-run catches
  drift the same way the known-pattern sweep does.
- **Whenever picking work back up after a real gap** (days/weeks, not
  within the same day): check item 4 above (MyDSL's own notes file) and
  skim `git log --oneline -20` against `docs/CHANGELOG.md`'s tail to
  confirm the two agree on what actually landed.
- **After any substantial work session**: prune `docs/TODO.md` per its own
  stated rule if it's grown append-only again; confirm `docs/CHANGELOG.md`
  has one line per real change made.
- **Periodically (and always before a package reinstall or anything that
  could overwrite native state)**: run a full native-content inventory of
  the live MyDSL profile — enumerate every Script/TriggerGroup/AliasGroup/
  KeyGroup in its newest `current/*.xml` (see the gotcha above: newest by
  mtime, never `autosave.xml`) and confirm each one is either
  git-tracked source, already captured by `build_mydsl_package.py`'s
  packageName-based splice, or a recognized `.gitignore`d third-party
  default. **Added 2026-08-23 after finding a real, previously-invisible
  gap this way**: a top-level `Aliases` group with 29 hand-built personal
  aliases (`packageName=None` — created directly in Mudlet's Alias
  editor, never installed as part of any package) had no backup anywhere
  and would have been silently lost on a from-scratch reinstall. Now
  preserved in `MyDSL_PersonalAliases.xml` (git-tracked, directly
  re-importable) — see `docs/TODO.md`'s closed inventory item for the
  full method. Any native content Steven builds directly in Mudlet's UI
  without it ever being part of an installed package can escape every
  other check in this file; this is the one that catches it.

## Reference material — cross-check against these before reinventing anything
- **Before writing new functionality (added 2026-08-29), check in order:
  (1) does an already-audited `MyDSL_*.lua` module already do this —
  `docs/OPTIMIZATION_AUDIT.md` is a full grep-confirmed inventory, check
  it before assuming something doesn't exist; (2) did PNP/EMCO already
  solve it — see the PNP/reuse bullet below; (3) does Mudlet's own Lua
  API already cover it — check `wiki.mudlet.org` (Manual + Lua API docs,
  already WebFetch-allowlisted) before hand-rolling something Mudlet
  ships natively (timers, regex triggers, Geyser layout primitives,
  `yajl`/`utf8` libs, etc.); (4) has the wider Mudlet package community
  already built this — a search of `forums.mudlet.org` / `mudlet.org`
  (also allowlisted) or the Shattered Archive monorepo
  (`~/Downloads/Shattered-Archive-release-dev.zip`, not yet fully
  audited) can save a rebuild.** This isn't a hook — "does something
  like this already exist" needs judgment, not a grep rule — so it's a
  step to actually take, not a box to check reflexively.
- `PNP files/` (this directory) — full PNP source, 46 files. When PNP already
  solved something (a trigger pattern, a flag mapping, a condition list),
  read the actual `.lua` file and copy the tested pattern; don't re-derive it
  from a contract's prose description of what PNP does.
- `log/` (this directory) — the full combat-log archive (578 files, 414MB),
  including AGL/coliseum character reports. Raw-grep this for anything
  correctness-critical (trigger text, message formats).
- `log/AGL/` — 6 full AGL tournament fight transcripts (~7,000 lines),
  fetched 2026-07-10 from the DSL forums (members-only, needs a cookie
  jar — see Steven if a fresh fetch is ever needed) after the Google
  Sheets "Leveraged Rankings" link Steven shared turned out to be just a
  win/loss scoreboard, not raw text. Real, useful combat data, but every
  line is Coliseum-broadcast-prefixed (`"[ <Wall> ] "`), so it's reference
  material for the future AGL/Coliseum module (see TODO.md DEFERRED
  section), not directly usable for the regular combat tracker, which
  deliberately excludes that prefix.
- `docs/templates_by_freq.txt` / `docs/templates_with_examples.txt` —
  pre-distilled combat-message shapes, fast first pass only. Confirmed to
  have real gaps (missing entire message categories) — absence there is not
  evidence a phrase doesn't occur; raw-grep `log/` to confirm.
- `DSL_Helpfiles/` (this directory) — 919 official in-game help texts,
  vendored 2026-07-05 from Steven's Claude.ai `/mnt` uploads. Documents
  command *usage/syntax* (e.g. `who <level-range>`), not raw output format —
  good for confirming a command exists or its argument shape, but `log/`
  is still authoritative for exact output text/regex patterns.
- `docs/DSL_CommandRef.md` — the confirmed-pattern reference: ground-truth
  output + working Lua/PCRE patterns per command, so a pattern is derived
  from `log/`/PNP once and reused, not rediscovered on every pass. Add to
  this file (don't create a parallel one) whenever a pattern is confirmed
  during testing/auditing — the "STILL NEEDED" section tracks what's missing.
- `~/Downloads/Shattered-Archive-release-dev.zip` — found 2026-07-05, an
  open-source DSL-specific MUD client + tooling monorepo
  (shatteredarchive.com, 524 files) with its own in-game research/data
  tools. Not yet audited — check before building the not-yet-started Layer 4
  reference library (items/mobs/lore), same reuse-before-reinvent principle
  as PNP/EMCO.
- Sibling Mudlet profiles (e.g. `../Dark & Shattered Lands - PNP`, `../PNP1`,
  `../PNP2`, `../DSL1`, `../DSL - Kien`) and `~/Downloads/` — read access to
  these is already granted via `.claude/settings.local.json`'s
  `Read(//home/owner/**)` rule, which persists across sessions on this
  machine (it's a local file, not session state). Check these when looking
  for older reference implementations, uploaded logs, or exported files —
  don't assume something doesn't exist without checking there first.

## Philosophy (non-negotiable except where noted)
- **MyDSL 1.0 global mandate, confirmed 2026-08-25 — supersedes
  conflicting rules below.** Full document: `docs/
  MYDSL_1.0_PHILOSOPHY.md`. Steven's own words: "My global goal is to
  be able to take any line of text in DSL and know what to do with it,
  whether it is sent to a window, it performs an action, or it passes
  it on without editing." Concrete, confirmed consequences: (1) **no
  more "third-party/reference-only" code** — anything actually running
  in this profile (the Generic Mapper fork, DslColors, gameplay
  triggers, sounds, room pics, aliases, keybinds) is this project's own
  code now, full stop; EMCO is already fully integrated under this
  standard (confirmed dead vendored copy, nothing further to do), the
  Generic Mapper's still-unmodified 5,666 stock lines are the real
  remaining case, planned as its own dedicated rewrite pass, not
  started yet. (2) **No formal cross-module API** — decided Steven +
  Claude Desktop 2026-08-25: nobody outside this project is expected to
  build against MyDSL, so a documented public API isn't worth building.
  (3) **One connection pattern** — decided the same day: standardize on
  direct `MyDSL.State.*` reads + `registerAnonymousEventHandler`, since
  that's already what most modules do in practice; the seldom-used
  `MyDSL.get()`/`MyDSL.set()` Get/Set API is deprecated rather than
  enforced (function-call indirection across every hot-path render
  module works against this project's own performance goals). See the
  full doc for the "every line has a known destination" architecture
  goal (not yet designed) and the retired-vs-unaffected breakdown of
  older rules below.
- **The old blanket "never send automatic game commands" rule is
  retired, per Steven 2026-08-23** ("ignore the automation bad comments
  now, we have moved past that restriction. drinking and eating are
  fine also") — full record in `docs/TODO.md`'s DECISIONS RECORDED
  section. Auto-sending game commands for real convenience (native
  thirst/hunger auto-drink/eat confirmed fine as the concrete example;
  Leveling/Questing were the earlier, narrower carve-out) is no longer
  something to flag or ask permission for case by case. **What this does
  NOT change**: "automate to assist, not to play" below still applies —
  the live distinction is between a command that helps upkeep happen
  (drink when thirsty, eat when hungry, navigate/engage for Leveling)
  versus something that changes what the player explicitly typed into a
  different command (the idea-backlog's `murder`-auto-swaps-to-`heal` is
  the concrete example of the latter, still flagged there for its own
  explicit sign-off, not covered by this).
- Any game command sent by a module should still make sense as something
  the player would have wanted done — this isn't a blank check to build
  arbitrary automation, just no longer a hard "never" requiring a
  standing exception to be carved out module by module.
- Main console is sacred — don't break or hide it.
- Every display module is optional / toggleable.
- **Move text, don't replace it.** If the game sends something, redirect it
  to the right window. Never manufacture fake output or inject text the
  game didn't send.
- **Automate to assist, not to play.** Spellup lists, respell reminders,
  disarm alerts — these help the player decide faster. They never decide
  for the player.
- **Stale data beats spam.** If current data isn't available, show the last
  known state. Never flood the server just to stay current.
- All window positions: percentages, never hardcoded pixels (this is a
  confirmed past bug — see `MyDSL_Audit.md` item 9, profile root, not docs/ —
  fixed 2026-07-06, this file previously said "in docs/" which was wrong).
- **Reuse PNP/EMCO source and their command vocabulary — don't reinvent.**
  Narrowed by the MyDSL 1.0 mandate above (2026-08-25): once ported,
  that code is this project's own, not a third-party dependency kept at
  arm's length — this bullet is about *how a port starts* (reuse
  tested logic and vocabulary instead of rewriting from scratch), not a
  claim that the result stays someone else's code afterward.
  Restated 2026-07-05 after Steven reported having to repeatedly fight
  Claude.ai's tendency to recreate PNP/EMCO functionality from scratch
  instead of reusing it. This applies at two levels: (1) internal logic —
  when PNP/EMCO already solved something, port the actual tested code,
  adapted for our window system/data layer; (2) **command surface** — reuse
  PNP's/EMCO's existing alias vocabulary as-is wherever possible, so someone
  migrating from PNP/EMCO doesn't have to learn new commands. Kill their own
  updater/self-maintenance mechanisms when porting (e.g. EMCO's `emco
  update` alias does `uninstallPackage()` + reinstall from GitHub — must not
  survive into our copy). GMCP should be used wherever it covers the same
  ground as a text trigger. Full rationale: `docs/MyDSL_MudletAPIReference.md`.
  **Correction (2026-07-07), superseding the 2026-07-06 correction below:**
  the original claim was right and the 2026-07-06 "fix" was wrong. Root
  cause: the native alias literally named `emco` (bare, no suffix) has its
  regex tag sitting *after* a long multi-branch `<script>` body in
  `current/autosave.xml`; the check that produced the 2026-07-06 correction
  only read ~800 chars past the `<name>` tag and never reached the
  `<regex>` tag, so it concluded no such alias existed. The real, active
  (`isActive="yes"`) regex is `^emco (save|load|font|fontSize|blink|
  blankLine|timestamp|show|hide)(?: (.+))?$` — confirmed both in
  `current/autosave.xml` directly and independently in the real upstream
  package (`~/Downloads/EMCO-2.9.0.zip`'s `src/aliases/EMCO/aliases.json`).
  So `emco show`, `emco hide`, `emco font <name>`, `emco fontSize <n>`,
  `emco blink`, `emco blankLine`, `emco timestamp`, `emco save`, `emco load`
  are all real, live commands. **Narrowed 2026-07-07, same day, after
  tracing what each sub-verb actually operates on** (see `docs/TODO.md`'s
  closed `emco <verb>` item for the full trace): `emco show`/`hide` act on
  `demonnic.container`, the *original* native `Adjustable.Container` —
  `MyDSL_ChatWrapper.lua`'s `C.hideOldPrebuilt()` deliberately hides that
  forever since MyDSL replaced it with its own `MyDSL_Chat` Geyser window,
  so `emco show`/`hide` don't affect the visible chat at all here; `mydsl
  chat show`/`hide` are correct as-is, **not** a duplication, and were
  **not** rerouted. `emco font`/`fontSize` (unlike show/hide) read
  `demonnic.chat` fresh each time they fire, which MyDSL reassigns to its
  own live object (`MyDSL_ChatWrapper.lua:313`) — so `emco fontSize <n>`
  and `mydsl chat font <n>` (numeric, maps to EMCO's `fontSize` not `font`,
  which takes a name) really do both call `:setFontSize()` on the same
  live object. That one's real but low-stakes (left as-is since `mydsl
  chat font` also persists to MyDSL's own settings file, which `emco
  fontSize` doesn't) — a code comment records this in
  `MyDSL_ChatWrapper.lua` so it isn't miscorrected again.
  (Struck-through, kept for the record of the mistake: "EMCO's real native
  aliases are `emco addtab/color/color usage/gaglist/gag/lock/notify/
  remtab/title/ungag/unlock/unnotify/update/usage` — there is no `emco
  show/hide/font` at all." This was itself wrong, per above.)

## Character-binding — confirmed status as of 2026-07-05 audit
Correctly character-bound: DataLayer's `MyDSL.Data[charName]` persistent
store, per-character affects files (`MyDSL/affects/<Name>.lua`), PromptView
(`MyDSL/prompt_<charName>.lua`), TargetView button config
(`MyDSL/targetview_config_<CharName>.lua`, fixed 2026-07-05 — was shared),
per-window debug logs (`MyDSL/logs/<category>/<CharName>/<date>.log`, made
character-bound 2026-07-05 from the start — see `MyDSL.logWindow()`).

**Not character-bound, but should be** (open bugs, tracked in `docs/TODO.md`):
LayoutEngine window positions (`MyDSL_layout.lua`, single shared file),
WindowRegistry visibility state (`MyDSL_windowstate.lua`, single shared
file), ChatWrapper settings (`chat_settings.lua`, single shared file).

**Not character-bound, intentionally** (recorded decision): ThemeEngine —
themes are user-creatable named presets, shared across all characters.

## Workflow
- Commit directly to `main` (updated 2026-08-29 to match actual practice
  since ~2026-08-23 — the old `fix/<module>-<short-description>`
  per-module-branch rule had quietly stopped being followed weeks earlier;
  `HANDOFF.md`'s Claude Code ↔ Claude Desktop review loop already reviews
  `main` directly, so a branch-per-change step wasn't adding review value
  it wasn't already getting). Keep commits small and focused per change,
  same as the old rule intended — this only drops the branch step itself.
- Commit messages: `type: description` (fix/feat/refactor)
- After every commit: append one line to `docs/CHANGELOG.md` describing what changed
- After finishing a task, update the relevant checkbox in `docs/TODO.md`
- Run the in-game smoke test alias (`mydsl test` if it exists, otherwise
  manually verify in Mudlet) before considering a fix complete
- Do not mark a TODO item done until Steven has confirmed it in-game
- **Use Plan Mode before any architectural or multi-file change** (added
  2026-08-29) — anything on the scale of a MyDSL 1.0 redesign pass, a
  cross-module interconnection fix, or touching 3+ files for one change.
  Skip it for a single-file bug fix or a doc update; those don't need a
  reviewable plan first. This is a habit, not a hook — nothing enforces
  it mechanically, so apply judgment rather than ceremony for every edit.
- **Known-bad-pattern check (added 2026-07-21)**: `scripts/check_known_patterns.py`
  encodes real historical bugs (cecho `</color>` closing tags instead of
  `<reset>`, `table.load()` missing its second argument, etc.) as grep
  rules. A `PostToolUse` hook (`.claude/settings.json`) runs it
  automatically against every file Edit/Write touches, so a fresh
  instance of a known mistake gets caught immediately, same session. That
  hook only ever checks the ONE file just touched, though — it can't
  retroactively catch the same mistake sitting untouched in a sibling
  file (this is exactly how `MyDSL_LiveView.lua`'s `</cyan>` bug survived
  the whole project's life unnoticed). Run a full-repo sweep periodically
  to close that gap: `python3 scripts/check_known_patterns.py --all`.
  When a new bug class gets fixed and there's reason to suspect it might
  exist elsewhere too, add a rule to that script instead of (or in
  addition to) a one-off manual grep — that check then stays permanent.

## Key paths
- Profile root: this directory
- Scripts are loose `.lua` files on disk in this directory, loaded via
  `dofile()` wrappers registered in Mudlet's Script editor, saved into
  `current/*.xml`.
  **Gotcha confirmed twice (2026-07-07 and 2026-07-08): the literal file
  `current/autosave.xml` is not reliably the most current snapshot.**
  Mudlet writes numbered timestamped files into `current/` (e.g.
  `current/2026-07-08#15-55-17.xml`) on save/close, and `autosave.xml`
  itself can sit stale for tens of minutes without being refreshed to
  match — confirmed directly 2026-07-08 when a Script Editor change
  (moving `MyDSL_RawCapture.lua` to load first) showed 0 hits in
  `autosave.xml` even after Steven clicked "Save Profile" and closed the
  profile, while the newest timestamped file in the same directory had it
  correctly. **Always check the most-recently-modified file in
  `current/` (`ls -t current/*.xml | head -1`), not the fixed filename,
  when verifying whether a native Script/Trigger/Alias change actually
  persisted.** (Narrows the older, cruder claim this note used to make —
  "autosave.xml is stale, not the source of truth" — which wasn't quite
  right either: autosave.xml correctly reflected the dofile list checked
  2026-07-07. The real rule is about *which file*, not whether the
  mechanism works at all.)
- Docs: `docs/` — see the Workflow section above for what's actually there
  now (just `TODO.md`, `CHANGELOG.md`, `DSL_CommandRef.md`, and reference
  material like `MyDSL_MudletAPIReference*.md`, `templates_*.txt`,
  `MyDSL_IdeaBacklog.md`)

## Current priority
See `docs/TODO.md` for the up-to-date, itemized list.
