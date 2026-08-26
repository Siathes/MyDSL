# MyDSL 1.0 — Window Feature Matrix

**Purpose, distinct from every other doc in `docs/`:** the command-parity
sweep (`docs/CHANGELOG.md`, 2026-08-26) closed the show/hide/title/font
gap across all windows but only left an informal record of what it did.
Per Steven's own ask ("i want to create a feature matrix for all
modules, see whats there what connects and that they do it all
properly i like this matrix for the windows"), this is the real
artifact: one row per player-facing **window**, its actual command
surface (grep-confirmed against source this session, 2026-08-26 — not
carried over from the sweep's own summary), what feeds it data, and any
currently-open correctness/perf issue already on record.

**Scope: the 17 dockable/Container windows only** — not all 44
audited `MyDSL_*.lua` modules. For the full module-by-module
Toggle/Connection/Verdict breakdown (including non-window logic layers:
DataLayer, ChatTriggers, CharacterAssist, LayoutEngine, etc.) see
`docs/MYDSL_1.0_MODULE_REDESIGN.md` — this document is a narrower,
command-surface-focused slice of the same audit, built to answer "does
this window have what every other window has" rather than "is this
module 1.0-compliant." Two real modules with a command surface
(`MyDSL_PromptView.lua`, `MyDSL_MoonWeather.lua`'s `on/off/toggle`) are
deliberately **not** windows in the geometry/dockable sense and are
covered in the Exceptions section instead of the main table.

**How to keep this current:** update a row the same commit that changes
that window's command surface. Don't let this drift into a second copy
of `CHANGELOG.md` — one line change per row, not a running history.

---

## Master table

| Window | Alias prefix | Show/Hide | Title | Font | Other real commands | Feeds from |
|---|---|---|---|---|---|---|
| Affects | `mydsl affects` | Y | Y | Y | `wrap`/`columns`/`width`, `respell`/`spellup` (+ bare `respell`/`spellup` aliases), `cast`/`recast`, `command <verb> <text>`/`command clear`, `timer mode`, `track`/`untrack`/`tracked`/`reset tracked`/`clear tracked`/`seed tracked`, `sync`, `reload profile`, `save` | Raw GMCP + State-adjacent, own save file |
| Alterform | `mydsl alterform` | Y | Y | Y | `sound on\|off`, `toggle alterform`, `reload settings` (internal `rebuild()`, no public alias) | Cross-View read of Affects' `getRemaining()` |
| Chat | `mydsl chat` (+ legacy `emco` verbs) | Y | Y | Y | `wrap auto\|fixed <n>`, `timestamp on\|off` + `format`, `revive`, `echo`/`test`, full legacy `emco addtab/remtab/gag/ungag/gaglist/notify/unnotify/blink/blankLine/color/fontSize/timestamp/save/load/show/hide/title` set (see `CLAUDE.md`'s EMCO-alias correction) | `MyDSL.Chat.emco` read by ChatTriggers; routes chat-channel lines |
| Combat | `mydsl combat` | **Partial — see Known gaps** | Y | Y | `mode raw\|condensed\|gag`, `clear`, `history`, `gag`/`ungag`, `show <flag>`/`hide <flag>` (per-feature, not whole-window), `toggle battle` | `config` read by `MyDSL_DataLayer_Combat.lua` — View owns the gag/show policy |
| Group | `group` (no `mydsl` prefix) | Y | Y | Y | `gag`/`ungag`, `quickset <a> <b>` / `quickset reset`, `status` | State-direct + reads TargetView's shared `actions` table |
| History | `mydsl history` | Y | Y | Y | `status` | `MyDSL.Windows.*` via RouteHelper — **`MyDSL.Route.history()` has zero callers anywhere** (open, see Known gaps) |
| Players Near | `mydsl playersnear` | Y | Y | Y | `status` | RouteHelper |
| Live | `mydsl live` | Y | Y | Y (+ `titlefont`/`barfont`/`infofont`/`terrainfont`, each independently sized) | `layout` (cycles via internal `rebuild()`), `reload settings`, `refresh`, `save` | `MyDSL.State.*` + `MyDSL.DB.*` + cross-View call into LocationView's `roomData()` |
| Location | `mydsl location` | Y | Y | Y | `dir [path]`, `probe [name]`, `name <char>`, `set <path>`, `map <ground>=<target>`/`unmap`/`maps`, `fit`, `missing caption\|blank`, `debug`, `refresh`, `status`/`dump`/`info` | Raw `gmcp.room_data` (**registered on both `gmcp.room_data` and `onNewRoom` for the same event, no unchanged-room early return — open double-fire bug, see Known gaps**) |
| Portrait | `mydsl portrait` (+ legacy `charpic` wrappers) | Y | Y | Y | `set <path>`/`clear`, `frame on\|off`, `fit`, `dir [path]`, `name <char>`, `probe [char]`, `missing caption\|blank`, `refresh`/`dump`/`help` | `MyDSL.Windows.registry` (the `.windows` typo from the pre-2026-08 audit is **already fixed** — confirmed current, commit `0da92de`) |
| Right Here (Scan) | `mydsl righthere` | Y | Y | Y | `dump` | Same DataLayer_ScanLook feed as Scan, tight intentional Layer-1→Layer-3 coupling |
| Scan | `mydsl scan` (+ bare `scan gag/ungag`) | Y | Y | Y | `gag`/`ungag` | `MyDSL.State` + DataLayer_ScanLook writes directly into the console (deliberate exception, not drift) |
| Bestiary | `bestiary <name>` (single alias, dispatches on the captured arg) | Y | Y | Y | bare `bestiary <name>` sends `creaturelore <name>` + shows | `MyDSL.CreatureLore.*` + State-direct live-capture fallback |
| Item Reference | `item <name>` (single alias, dispatches on the captured arg) | Y | Y | Y | `map <ground>=<target>` override, bare `item <name>` sends `identify <name>` + shows | `MyDSL.itemlore.updated` event + hover-link clicks |
| Focus (Target) | `focus` | Y | Y | Y | `clear`, `mobset`/`playerset` (+ `reset` for each), `action <verb> "<match>" <cooldown> <cmd>` | State-direct + `MyDSL.getTargetCondition()` (DataLayer_Combat) — most cross-module-depended-on View (Leveling, Group, Scan all call `MyDSL.Target.set()`) |
| Tick | `mydsl tickview` | Y | Y | Y | `mode compact\|full`, `toggle ticktimer`, `reload settings` | `MyDSL.DB.tick` only — **two independently-persisted visibility flags (`V.config.shown` vs. registry `.visible`) and `render()` keeps running at full 4Hz while hidden — open, see Known gaps** |

**MoonWeather** is the one documented, intentional exception inside the
17: it uses `on`/`off`/`toggle` instead of `show`/`hide` (`mydsl moon
on/off/toggle`, plus the legacy `toggle moons` PNP alias) and has no
`title` command, because it's a `Container` widget with no header label
to put a title on — not a gap, a real structural difference from every
other window (all of which have a dockable title bar). It does have
`font` and a unique `gag`/`ungag` pair for the `lunar` game-command echo.

---

## Exceptions — real command surfaces that are NOT windows

- **`MyDSL_PromptView.lua`** (`mydsl prompt on|off|toggle`) — a
  gag-state toggle for the native prompt line, not a Geyser window at
  all (no show/hide/title/font applies; the visual "PromptBar overlay"
  this would eventually feed is an unbuilt future module per the file's
  own header comment). Correctly excluded from the table above, not a
  parity gap.

---

## Known gaps surfaced while building this matrix (grep-confirmed 2026-08-26, not yet fixed)

These are carried forward from `docs/MYDSL_1.0_MODULE_REDESIGN.md`'s
findings, re-checked against current source while building this table
(some redesign-doc findings turned out to already be fixed — see the
Portrait and Chat rows above — these three were re-confirmed **still
present**):

1. **History window has no writer.** `MyDSL_History` is fully wired
   (registry, layout slot, theme, help text, full show/hide/title/status
   surface) but `MyDSL.Route.history()` — the only function that would
   ever put text into it — has zero callers anywhere in the codebase.
   Needs a decision from Steven: was History ever meant to receive a
   specific category of text (sailing/quests/atmosphere lines were the
   original guess), or should the capture be scoped as new work now.
2. **LocationView double-fires on room entry.** `M.onRoomData` is
   registered on both `gmcp.room_data` and the mapper's `onNewRoom`
   event for the same room-entry moment (`MyDSL_LocationView.lua:1230-
   1232`), with no unchanged-room early return — confirmed still
   present this session. Each entry costs a duplicate image-lookup/
   render; smaller blast radius than the (already-fixed) DataBridge bug
   but the same root cause.
3. **TickView renders at full rate while hidden.** `V.render()` has no
   visibility check and redraws at TickSource's 4Hz regardless of
   `hide()` having been called; also carries two independently-
   persisted visibility flags (`V.config.shown` vs. the WindowRegistry's
   own `.visible`) that aren't unified. `hide()` stops the *display*,
   not the *cost* — needs both this file and TickSource touched to fix
   properly (per the redesign doc's own note).
4. **Combat has no whole-window `show`/`hide` alias — new finding, not
   in the redesign doc.** `CV.show()`/`CV.hide()` (`MyDSL_CombatView.lua:
   343-344`) exist and correctly call `MyDSL.Windows.show/hide`, but the
   only alias wired to whole-window visibility is `toggle battle`
   (`CV.toggle()`) — there is no `mydsl combat show$`/`hide$` to show or
   hide it directly, unlike every other window in the table above. The
   only `show`/`hide` aliases that DO exist (`mydsl combat show
   <flag>`/`hide <flag>`) toggle a per-feature `config.show_<flag>`
   entry, not the window itself — genuinely different feature, easy to
   mistake for the missing one at a glance. Real, mechanical parity gap:
   add `mydsl combat show$`/`hide$` aliases calling the already-existing
   `CV.show()`/`CV.hide()` functions, same as every other window has.

None of these four are fixed by this matrix pass — they're the real
input to the next step (module-by-module feature pass), not resolved
here.
