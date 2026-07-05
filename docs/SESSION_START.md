# DSL Observer UI — Session Context
*Last updated: 2026-07-05 — full staleness audit; Claude.ai removed from workflow*

---

## Project Identity
Building the **Observer UI** — a modular 4-layer passive observation system for
Dark and Shattered Lands (DSL), running on Mudlet 4.20.1 / Fedora Linux.

**Primary build character:** Kien (W-Elf Druid 51, True Neutral, Zandreya, Arkane kingdom)
**Alts:** Olyndros, Tibbins
**Profile:** `/home/owner/.config/mudlet/profiles/DSL2/` (also mirrored at
`/home/owner/Desktop/Mudlet/mudlet-data/profiles/DSL2/`)

DSL2 is the clean working profile. DSL1 is archived reference.

**Philosophy:** Move text, don't replace it. Main console is sacred. Passive
observation only. Every module optional. Stale data beats spam. All positions
stored as fractions/percentages, not pixels.

---

## Workflow (changed 2026-07-05)

**Claude.ai has been removed from the workflow.** It's Steven and Claude Code
directly now — no more design-doc relay through a separate chat, no more
upload/download dance with a project folder. Claude Code reads contracts,
source, logs, and PNP reference material directly off disk and owns keeping
`SESSION_START.md`, `TODO.md`, `DSL_SessionNotes.md`, and `CHANGELOG.md` current.

**Why:** the 2026-07-05 evasion-trigger bug happened because a contract
produced by the old design layer *described* PNP's behavior in prose, and
that description got reinvented into new (wrong) regex instead of the tested
PNP source being copied directly. Routing engineering decisions through a
paraphrase step cost real correctness. See `MyDSL_MudletAPIReference.md`'s
"read PNP source directly" and "templates files are first-pass only" notes
for the two concrete lessons from that.

**Before touching any file:**
1. Read this file
2. Read the relevant `Contract_*.md` for the module being worked on — but
   verify it against the live `.lua` file if anything looks like it might have
   drifted; contracts are summaries, not ground truth (see above)
3. Read `DSL_CommandRef.md` for any text patterns needed
4. Check git log for current branch state

**Source of truth for current scripts:** the actual `.lua` files on disk in
this profile directory. `docs/SYNC.md` has a load-order and namespace map but
is dated 2026-06-30 — predates GroupView's later fixes and all of CombatView;
treat it as historical background, not current status.

---

## Current State — Phase A and Phase B both substantially complete

**Phase A** (Layer 1/2 + first Layer 3 modules): ✅ complete since 2026-06-29,
tagged `v1.0-phase-a-complete`. DataLayer, ThemeEngine, LayoutEngine,
WindowRegistry, ChatWrapper, AffectsView, TickSource/TickView, PortraitView,
LocationView, LiveView, PromptView all built and working.

**Phase B** (Combat/Scan/Group/Target/MoonWeather windows): all five built.
In-game confirmation status varies — see `TODO.md`'s Phase B table for the
current per-module breakdown (MoonWeather/ScanView/TargetView confirmed live;
GroupView/CreatureReference/CombatView built but not yet live-tested).

**Full detail on what's fixed vs. still open lives in `TODO.md` now** — it was
rewritten 2026-07-05 alongside this file after finding it badly out of date
(it still said Combat/Scan/Group/Target were "not started" when all four were
already built and iterated on).

---

## Window System — Resolved ✅ (Phase A, still holds)

**Root cause of all window reset problems:** LayoutEngine registered a
`sysWindowResizeEvent` handler that called `reflowAll()` → `applyToWindow()`
→ `resize()`/`move()` on every window. Docking a UserWindow fires
`sysWindowResizeEvent`. Every dock snapped all windows to LayoutEngine defaults.

**Fix:** Handler removed from LayoutEngine entirely (commit `e50b56a`, branch
`fix/remove-reflow-handler`, merged to main). `reflowAll()` and `applyToWindow()`
remain as explicit-call functions only.

**Current correct startup sequence:**
```lua
patchUserWindowConstructor()   -- inject restoreLayout=true + autoDock=true
MyDSL.Windows.loadState()      -- restore visibility booleans
MyDSL.Windows.ensureAll()      -- create all windows at LayoutEngine positions
if loadWindowLayout then loadWindowLayout() end  -- restore saved positions
```

**User workflow:** Arrange windows, then `mydsl layout save` to persist.

---

## Contract Status

All contracts spot-checked against live code 2026-07-05. Where a contract's
"gap" was already fixed in code but the doc wasn't updated, that's now
corrected in the contract itself — see `TODO.md`'s "RESOLVED" section for the
full list of what changed. Still-open low-priority gaps are also tracked
there.

| Layer | Module | Contract | Status |
|---|---|---|---|
| 1 | DataLayer | `Contract_DataLayer.md` | ✅ Working |
| 2 | ThemeEngine | `Contract_ThemeEngine.md` | ✅ Working — 1 minor gap open (no key validation on setOverride) |
| 2 | LayoutEngine | `Contract_LayoutEngine.md` | ✅ Working — 2 minor gaps open (resetAll missing, save() no error handling) |
| 2 | WindowRegistry | `Contract_WindowRegistry.md` | ✅ Working — 2 minor gaps open (visibility not char-bound, saveState no error handling) |
| 3 | DataBridge | `Contract_DataBridge.md` | ✅ Working — all documented gaps confirmed fixed |
| 3 | RouteHelper | `Contract_RouteHelper.md` | ✅ Working |
| 3 | TickSource | `Contract_TickSource.md` | ✅ Working — all 3 gaps confirmed fixed (commit `b16ec52`) |
| 3 | TickView | `Contract_TickView.md` | ✅ Working |
| 3 | ChatWrapper | `Contract_ChatWrapper.md` | ✅ Working — 3 of 5 gaps confirmed fixed, 2 still open (hardcoded tab CSS, settings not char-bound) |
| 3 | AffectsView | `Contract_AffectsView.md` | ✅ Working |
| 3 | PortraitView | `Contract_PortraitView.md` | ✅ Working |
| 3 | LocationView | `Contract_LocationView.md` | ✅ Working |
| 3 | LiveView | `Contract_LiveView.md` | ✅ Working (renders on 0.25s timer; 7 of 8 event subscriptions are dead but harmless) |
| 3 | PromptView | `Contract_PromptView.md` | ✅ Working — simple prompt-gag design, not the earlier PromptBar concept |
| 3B | MoonWeather | `Contract_MoonWeather.md` | ✅ Feature-complete, confirmed live |
| 3B | ScanView | `Contract_ScanView.md` | ✅ Confirmed live |
| 3B | GroupView | `Contract_GroupView.md` | ✅ Built, rescue-hidden-for-Mob fix confirmed in code, not yet live-tested |
| 3B | TargetView | `Contract_TargetView.md` | ✅ Confirmed live |
| 3B | CreatureReference | `Contract_CreatureReference.md` | ✅ Built, not yet live-tested |
| 3B | CombatView | `Contract_CombatWindow.md` | ✅ Built and hardened 2026-07-05, not yet live-tested — see TODO.md open items |

See `Contract_Addendum_2026-06-21.md` for changes that supersede parts of
the LayoutEngine, WindowRegistry, RouteHelper, and PortraitView contracts.

---

## Confirmed GMCP Structure (cross-verified against live captures)

```
gmcp.char_data = { hp, max_hp, mana, max_mana, move, max_move,
  str/int/wis/dex/con (+ max_), gold, silver, carry_weight,
  can_carry_weight, stance, language, is_flying, is_riding,
  is_fighting, is_afk, is_quiet, tnl, wimpy, hp_raw }

gmcp.login_data = { name="Kien", level=51, kingdom="Arkane",
  is_clan, is_kingdom, time="6:30am" }  -- time here is login timestamp only

gmcp.room_data = { room="In the Main Gathering Room...",  -- field is "room" not "name"
  exits={"N","E","W","U"},  -- uppercase abbreviations
  sector="inside" }          -- terrain type, NOT area name

gmcp.tick = { time="8:00am" }  -- clock string ONLY

gmcp.affect_data = { affects = [ {n, d, lc, m, t}, ... ] }
  -- n=name, d=duration(cycles), lc=location, m=modifier, t=type
```

---

## Time Command — Two Format Variants Confirmed

```
It is 9:30 am, Day of the Great Gods, 26th the Month of the Great Evil.
It is 10:00 o'clock am, Day of the Great Gods, 26th the Month of the Great Evil.
```
Both handled by one flexible pattern using `[^,]-` (see DSL_CommandRef.md).

---

## DSL1 Modified Mapper Script — MUST CARRY FORWARD AS-IS

Steven's DSL1 mapper (generic_mapper, version "2.1.8-dsl-descfix1") has 8
confirmed DSL-specific patches. When DSL2's mapper is set up, install FROM
this exact modified file — never reinstall from the package manager or allow
self-update, or all patches are lost.

---

## Reference Material Available On Disk

- `PNP files/` (profile root) — full PNP source, 46 files. Read directly for
  anything the old workflow would have summarized in a contract's prose.
- `log/` (profile root) — the full combat-log archive (578 files, 414MB),
  including AGL/coliseum character reports. Raw-grep this for anything
  correctness-critical — see `docs/MyDSL_MudletAPIReference.md`'s note on why
  the distilled templates files below aren't sufficient on their own.
- `docs/templates_by_freq.txt` / `docs/templates_with_examples.txt` —
  pre-distilled combat-message shapes with frequency counts. Fast first pass
  only; confirmed gaps exist (see the note in `MyDSL_MudletAPIReference.md`).
- `docs/claude_export_2026-07-05/` — a snapshot produced for the old
  Claude.ai handoff, now obsolete now that the workflow doesn't need it.
  Harmless to leave, safe to delete next time this repo gets tidied.

---

## Immediate Next Steps (in order)

1. **Live-test the 2026-07-05 CombatView fixes** — evasion triggers, both
   death-message forms, weapon-proc pseudo-attacker rows, quoted weapon names.
   None of this has been exercised in an actual DSL combat session yet.
2. **In-game smoke test GroupView** — type `group` while grouped, confirm
   member list, HP bars, rescue-hidden-for-Mob behavior.
3. **In-game smoke test CreatureReference** — `creaturelore <mob>` in combat.
4. **Fix the self-condition trigger gap** — confirmed via logs that DSL uses
   second-person phrasing for your own condition; not yet fixed in code.
5. Pick up any of the low-priority open gaps in `TODO.md` opportunistically.

---

## Session End Ritual (revised 2026-07-05)

Claude Code does, every session: append to `CHANGELOG.md`, update `TODO.md`
and this file if project state materially changed, append a dated entry to
`DSL_SessionNotes.md`, tag git milestones on request.

Steven does: tests in-game, reports bugs/confirmations, approves changes.
