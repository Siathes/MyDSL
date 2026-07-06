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

## Workflow (Claude.ai removed 2026-07-05)
It's Steven and Claude Code working directly from this repo now — no design
relay through a separate chat, no upload/download dance with a project
folder. Claude Code reads contracts, source, logs, and PNP reference
material straight off disk and owns keeping `docs/SESSION_START.md`,
`docs/TODO.md`, `docs/DSL_SessionNotes.md`, and `docs/CHANGELOG.md` current.
See `docs/SESSION_START.md`'s "Workflow" section for the incident that
prompted this (a contract's prose paraphrase of PNP's behavior got reinvented
into wrong regex instead of PNP's tested source being copied directly).

## IMPORTANT — Read before touching any file
1. Read `docs/SESSION_START.md` first, every session. It has current state,
   known bugs, and architecture decisions.
2. Read the relevant `docs/Contract_<ModuleName>.md` before editing that
   module — but verify it against the live `.lua` file rather than trusting
   it blindly. Contracts are summaries and have been found to drift from
   what's actually in the code (several gaps were already fixed in code but
   still described as open bugs in their contracts as of the 2026-07-05 audit).
3. If the module is ThemeEngine, LayoutEngine, WindowRegistry, RouteHelper,
   or PortraitView — also read `docs/Contract_Addendum_2026-06-21.md`. It
   supersedes specific sections of those five contracts. The addendum wins
   on any conflict.
4. Read `docs/DSL_CommandRef.md` for any in-game text pattern you need to
   parse or match — it has the confirmed real output and the fix patterns.

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
- All window positions: percentages, never hardcoded pixels (this is a
  confirmed past bug — see MyDSL_Audit.md item 9 in docs/ if present).
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
- Contracts and docs: `docs/`

## Current priority
See `docs/TODO.md` for the up-to-date, itemized list. As of 2026-07-05:
top priority is live-testing the CombatView fixes from that date (evasion
triggers, death-message forms, weapon-proc attribution, quoted weapon
names) — none of it has been exercised in an actual DSL combat session yet.
