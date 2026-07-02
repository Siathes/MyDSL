# DSL Observer UI — Session Context
*Last updated: July 2, 2026 — MoonWeather Phase B complete, tagged v1.2-moonweather-final*

---

## Project Identity
Building the **Observer UI** — a modular 4-layer passive observation system for
Dark and Shattered Lands (DSL), running on Mudlet 4.20.1 / Fedora Linux.

**Primary build character:** Kien (W-Elf Druid 51, True Neutral, Zandreya, Arkane kingdom)
**Alts:** Olyndros, Tibbins
**Profile:** `/home/owner/Desktop/Mudlet/mudlet-data/profiles/DSL2/`

DSL2 is the clean working profile. DSL1 is archived reference (still in active
in-game use until DSL2 reaches feature parity).

**Philosophy:** Move text, don't replace it. Main console is sacred. Passive
observation only. Every module optional. Stale data beats spam. All positions
stored as fractions/percentages, not pixels.

---

## Orientation for Claude Code

**Before touching any file:**
1. Read this file
2. Read the relevant `Contract_*.md` for the module being worked on
3. Read `DSL_CommandRef.md` for any text patterns needed
4. Check git log for current branch state

**Source of truth for current scripts:** The actual `.lua` files on disk at
`/home/owner/Desktop/Mudlet/mudlet-data/profiles/DSL2/`. The autosave.xml in
the project folder is stale — all scripts now loaded via `dofile()` wrappers.

---

## Current State — Phase A Complete ✅

**git tag:** `v1.0-phase-a-complete` at commit `8f7bb2b`

All Layer 1 (DataLayer) and Layer 2 (ThemeEngine, LayoutEngine, WindowRegistry)
systems confirmed working. All Layer 3 Phase A modules confirmed working via
in-game smoke test with Kien.

### Phase A Smoke Test Results (June 29, 2026)

| Test | Result |
|---|---|
| DataLayer alive (`MyDSL.State.login`) | ✅ Kien, level 51, Arkane |
| GMCP vitals (`MyDSL.State.char`) | ✅ All fields, updating live |
| HP/Mana/MV bars | ✅ Updating in real-time |
| Tick countdown | ✅ Counting down, resetting on tick |
| Affects window | ✅ Populating from GMCP |
| Location window | ✅ Updating on room change |
| Portrait | ✅ Kien's portrait showing |
| Chat routing | ✅ say→Local tab, tell→Tells tab, gagged from main |
| Score parser | ✅ All fields populated — see known issues below |
| Window layout persistence | ✅ `mydsl layout save` persists arrangement |
| Main console borders | ✅ Cleared (old applyBorders() values purged) |

### Two Known Score Issues (minor, not blocking Phase B)
1. `stance` captures trailing text — `"Offensive         NoBattle ( )..."` 
   instead of just `"Offensive"`. Pattern needs `%S+` not `(.+)`.
2. `profession` field missing — `endScore()` fires on the second `---` separator
   which appears before `PROFESSION:`. Need to fire on the line AFTER profession.

---

## Window System — Resolved ✅

**Root cause of all window reset problems:** LayoutEngine registered a
`sysWindowResizeEvent` handler that called `reflowAll()` → `applyToWindow()`
→ `resize()`/`move()` on every window. Docking a UserWindow fires
`sysWindowResizeEvent`. Every dock snapped all windows to LayoutEngine defaults.

**Fix:** Handler removed from LayoutEngine entirely (commit `e50b56a`, branch
`fix/remove-reflow-handler`, merged to main). `reflowAll()` and `applyToWindow()`
remain as explicit-call functions only.

**Additional fix:** Old `applyBorders()` calls had saved border values
(left=294px, right=281px, bottom=121px) to autosave.xml. Cleared manually:
```lua
setBorderLeft(0); setBorderRight(0); setBorderBottom(0); setBorderTop(0); saveProfile()
```

**Current correct startup sequence:**
```lua
patchUserWindowConstructor()   -- inject restoreLayout=true + autoDock=true
MyDSL.Windows.loadState()      -- restore visibility booleans
MyDSL.Windows.ensureAll()      -- create all windows at LayoutEngine positions
if loadWindowLayout then loadWindowLayout() end  -- restore saved positions
```

**User workflow:** Arrange windows, then `mydsl layout save` to persist.

---

## Score Trigger — How It Works Now

The score trigger was not registered anywhere (the comment said "write these in
Mudlet separately" but nobody did). Fixed by adding `tempRegexTrigger` calls
at the bottom of `MyDSL_DataLayer.lua`:

- `tempRegexTrigger("^Score for ", ...)` → calls `beginScore()`
- `beginScore()` installs a catch-all `tempRegexTrigger(".*", ...)` that feeds
  every line to `parseScoreLine()`
- `parseScoreLine()` tracks two `---` separator lines: first skips, second calls
  `endScore()` which kills the catch-all trigger
- Trigger IDs stored in `MyDSL._triggers{}`, killed on script reload

---

## Contract Status — ALL PHASE A MODULES CONTRACTED

| Layer | Module | Contract | Status |
|---|---|---|---|
| 1 | DataLayer | `Contract_DataLayer.md` | ✅ Working, 2 minor score issues |
| 2 | ThemeEngine | `Contract_ThemeEngine.md` | ✅ Contracted |
| 2 | LayoutEngine | `Contract_LayoutEngine.md` | ✅ Working, resize handler removed |
| 2 | WindowRegistry | `Contract_WindowRegistry.md` | ✅ Working, layout persistence working |
| 3 | DataBridge | `Contract_DataBridge.md` | Contracted, gaps documented |
| 3 | RouteHelper | `Contract_RouteHelper.md` | Contracted, see addendum |
| 3 | TickSource | `Contract_TickSource.md` | ✅ Working |
| 3 | TickView | `Contract_TickView.md` | ✅ Working |
| 3 | ChatWrapper | `Contract_ChatWrapper.md` | ✅ Working |
| 3 | AffectsView | `Contract_AffectsView.md` | ✅ Working |
| 3 | PortraitView | `Contract_PortraitView.md` | ✅ Working |
| 3 | LocationView | `Contract_LocationView.md` | ✅ Working |
| 3 | LiveView | `Contract_LiveView.md` | ✅ Working (bars + room info) |
| 3 | MoonWeather | `Contract_MoonWeather.md` | ✅ Feature-complete 2026-07-02 (v1.2-moonweather-final) |

See `Contract_Addendum_2026-06-21.md` for changes that supersede parts of
the LayoutEngine, WindowRegistry, RouteHelper, and PortraitView contracts.
See updated `Contract_LayoutEngine.md` and `Contract_WindowRegistry.md` for
the June 28 corrections (resize handler, border management, startup sequence).
See updated `MyDSL_MudletWindowManagement.md` for the corrected Mudlet API notes.

---

## Confirmed GMCP Structure (cross-verified against live captures)

```
gmcp.char_data = { hp, max_hp, mana, max_mana, move, max_move,
  str/int/wis/dex/con (+ max_), gold, silver, carry_weight,
  can_carry_weight, stance, language, is_flying, is_riding,
  is_fighting, is_afk, is_quiet, tnl, wimpy }

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

Day/Night time-of-day states confirmed from live capture:
- `Night Time` — prompt line 2 prefix
- `Dawn` — appears at 6:00am
- `Day Time` — appears at 7:00am

---

## DSL1 Modified Mapper Script — MUST CARRY FORWARD AS-IS

Steven's DSL1 mapper (generic_mapper, version "2.1.8-dsl-descfix1") has 8
confirmed DSL-specific patches. When DSL2's mapper is set up, install FROM
this exact modified file — never reinstall from the package manager or allow
self-update, or all patches are lost.

---

## Three-Tool Workflow

```
Claude.ai (this chat)          Claude Code (terminal)        Steven
Writes contracts                Reads contracts               Tests in-game
Writes design docs              Writes Lua files              Provides captures
Generates CC prompts       ->   Runs git operations      <-   Approves changes
Makes architecture calls        Updates CHANGELOG.md          Reports bugs
Answers "why" questions         Smoke tests                   Uploads files to project
```

---

## Phase B Status

| Module | Status |
|---|---|
| MoonWeather | ✅ Feature-complete 2026-07-02 — living clock, day/night indicator, gold bonus text, border removed |
| Combat window | Not started — next priority |
| Scan/RightHere | Not started |
| Group window | Not started |
| Target window | Not started |

## Immediate Next Steps (in order)

1. ~~**Fix two known score issues**~~ — ✅ Both fixed (commit `468ee77`, Jun-29).
2. **Begin next Phase B window** — Combat window (BattleCondenser port) or Scan/RightHere.
   Write Contract doc first; use `Contract_MoonWeather.md` as structural template.
3. **PromptView** — contract needed before implementation

---

## Session End Ritual

Claude.ai does: Update SESSION_START.md, append to DSL_SessionNotes.md,
update TODO.md, write any new Contract_*.md files, tell Steven what to upload.

Steven does: Download new/updated files from outputs, upload to project folder.

Claude Code does on every commit: meaningful commit message, append to
CHANGELOG.md, tag milestones.
