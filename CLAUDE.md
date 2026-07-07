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
- `docs/DSL_CommandRef.md` — confirmed regex/output patterns for DSL
  itself. High-value because it's about an external, stable system (DSL's
  text doesn't change), not our own code (which does).
- The actual `.lua` files — how something currently works. Always read
  these directly; there is no separate spec describing them anymore.
- `notes_utf8.txt` (profile root) — Steven's informal scratch/question
  channel, not a formal doc.

## IMPORTANT — Read before touching any file
1. Read `docs/TODO.md` first, every session — the current punch list.
2. Read the actual `.lua` file for any module being edited — there is no
   separate contract/spec anymore; the code is the only source of truth for
   how something currently works.
3. Read `docs/DSL_CommandRef.md` for any in-game text pattern you need to
   parse or match — it has the confirmed real output and the fix patterns.
   Add to it (don't create a parallel file) whenever a new pattern is
   confirmed during testing/auditing.

## Reference material — cross-check against these before reinventing anything
- `PNP files/` (this directory) — full PNP source, 46 files. When PNP already
  solved something (a trigger pattern, a flag mapping, a condition list),
  read the actual `.lua` file and copy the tested pattern; don't re-derive it
  from a contract's prose description of what PNP does.
- `log/` (this directory) — the full combat-log archive (578 files, 414MB),
  including AGL/coliseum character reports. Raw-grep this for anything
  correctness-critical (trigger text, message formats).
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

## Philosophy (non-negotiable)
- Passive observation only. Never send automatic game commands.
- Any game command sent by a module must be user-initiated (alias or click).
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
  Confirmed violation found immediately on first audit: `MyDSL_ChatWrapper.lua`
  invented `mydsl chat show/hide/font/...` instead of reusing EMCO's own
  `emco show/hide/font/...` — see `docs/TODO.md` for the full command-surface
  gap inventory as it's built out.

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
- One module/bug per branch. Branch name: `fix/<module>-<short-description>`
- Commit messages: `type: description` (fix/feat/refactor)
- After every commit: append one line to `docs/CHANGELOG.md` describing what changed
- After finishing a task, update the relevant checkbox in `docs/TODO.md`
- Run the in-game smoke test alias (`mydsl test` if it exists, otherwise
  manually verify in Mudlet) before considering a fix complete
- Do not mark a TODO item done until Steven has confirmed it in-game

## Key paths
- Profile root: this directory
- Scripts are loose `.lua` files on disk in this directory, loaded via
  `dofile()` wrappers registered in Mudlet's Script editor — not embedded in
  autosave.xml (that file is stale/not the source of truth as of Phase B)
- Docs: `docs/` — see the Workflow section above for what's actually there
  now (just `TODO.md`, `CHANGELOG.md`, `DSL_CommandRef.md`, and reference
  material like `MyDSL_MudletAPIReference*.md`, `templates_*.txt`,
  `MyDSL_IdeaBacklog.md`)

## Current priority
See `docs/TODO.md` for the up-to-date, itemized list.
