# DSL Observer UI — TODO
*Updated June 29, 2026 — Phase A complete, tagged v1.0-phase-a-complete*

---

## ✅ DONE — Phase A Complete (June 29, 2026)

All Layer 1 and Layer 2 systems working. All Layer 3 Phase A modules
smoke tested with Kien and confirmed working:
- DataLayer (GMCP + score text parser)
- ThemeEngine, LayoutEngine, WindowRegistry
- ChatWrapper, AffectsView, TickSource/TickView, PortraitView, LocationView, LiveView

Window layout persistence working (`mydsl layout save`).
Main console borders cleared. LayoutEngine resize handler removed (root cause of resets).
Score trigger wired in DataLayer via tempRegexTrigger.

---

## MINOR — Score Cleanup (not blocking Phase B)

- [ ] Fix `stance` field — pattern captures trailing text. Change to stop at
      first whitespace: `Stance:%s*(%S+)` instead of `Stance:%s*(.+)`
- [ ] Fix `profession` field missing — `endScore()` fires on the second `---`
      separator which is BEFORE `PROFESSION:`. Need to consume PROFESSION section
      before closing the block. One approach: detect `^PROFESSION:` line and set
      a flag, then fire endScore() on the `---` that follows it.

---

## NEXT — Layer 3 Phase B Windows

These windows are defined in Layer 2 (WindowRegistry) but Layer 3 content
modules have not been built yet. Design each with a contract before implementing.

### Combat Window
- Port BattleCondenser from PNP reference suite
- Damage dealt/received, kill counter, XP per kill
- Source: trigger-capture from combat lines (not GMCP)
- Uses: appendBuffer for color-preserving damage output

### Scan/RightHere Windows
- Scan window: display output of `scan` command
- RightHere window: clickable mob list from scan output (mob targeting)
- Both work together — scan populates RightHere
- Need `scan` output format in DSL_CommandRef.md before implementing

### Group Window
- Group member list with HP/condition
- Source: GMCP if available, else text capture from `gr` command
- Clickable party members
- Need `group`/`gr` output format in DSL_CommandRef.md

### Target Window
- Current target name, level, condition
- Significant redesign needed: mob vs player interaction differences
- Kill/Assist/Heal button changes based on target type
- Uses cechoPopup or Geyser.Label with swapped stylesheet

### MoonWeather Window
- Moon phase + weather conditions
- Source: GMCP or text capture from `time`/`lunar` commands
- Important for Kien (Druid) — moon phase affects spells
- Moon parse patterns confirmed in DSL_CommandRef.md

---

## NEXT — PromptView Module

Design confirmed in SESSION_START.md but no formal contract yet.
- Toggleable pretty prompt, default ON
- Gags all 3 server prompt lines via deleteLine() triggers
- New MyDSL_PromptBar overlay (Adjustable.Container, bottom of main console)
- Shows HP/Mana/MV bars + status line (stance/align/language/time/room)
- Toggle alias: `mydsl prompt on|off`
- No extra DataLayer fields needed beyond existing score.align and GMCP time

---

## DECISIONS RECORDED (ready for implementation)

- All settings (theme, layout, visibility) are character-bound
- Themes: user-creatable named presets, shared across all characters
- MyDSL_Mapper removed from WindowRegistry — minimap via map.configs.map_window only
- Scan/Combat are native-docked + tabbed with mapper on the left
- CharPic compatibility code removed from PortraitView
- RouteHelper routeMap removed — shorthand helpers are the only API
- Prompt: toggleable pretty prompt, default ON
- Day/Night derived from `time` command, not prompt capture
- Alignment from score only, persists until next score run, no auto-send
- No sysWindowResizeEvent handler in LayoutEngine — was resetting windows on dock
- No setBorderLeft/Right/Bottom — Mudlet handles console space for docked windows natively

---

## DESIGN — Not Yet Started

- [ ] Layer 3 Phase B: Combat window (BattleCondenser port from PNP)
- [ ] Layer 3 Phase B: Scan/RightHere mob targeting windows
- [ ] Layer 3 Phase B: Group window with clickable party members
- [ ] Layer 3 Phase B: Target window (mob vs player interaction differences)
- [ ] Layer 3 Phase B: MoonWeather window
- [ ] MyDSL_PromptView module — contract needed
- [ ] Layer 4: Reference library (items, mobs, lore) — not started

---

## LOW PRIORITY — DataBridge Gaps (Contract_DataBridge.md)

These blocked on DataLayer fixes which are now done. Revisit before Phase B
modules consume DataBridge data.

- [ ] Gap 1: room.name field — use room.room (DataLayer uses "room" not "name")
- [ ] Gap 2: room.area → room.sector (area not in GMCP)
- [ ] Gap 3: DB.time section entirely missing — needed by LiveView
- [ ] Gap 4: DB.affects section entirely missing
- [ ] Gap 6: score text fields (align, race, class, religion) not mapped to DB.score
- [ ] Gap 6 extended: add hitroll, damroll, armor, items, posn to DB.score

---

## LOW PRIORITY — Other Module Gaps

### ChatWrapper (Contract_ChatWrapper.md)
- [ ] Gap 2: 5.0s forced rebuild wipes chat from first 5 seconds
- [ ] Gap 5: window key lookup tries wrong registry key

### RouteHelper (Contract_RouteHelper.md + Addendum)
- [ ] Gap 1: uses decho() instead of appendBuffer() — strips game colors
- [ ] Remove routeMap entirely

### TickSource (Contract_TickSource.md)
- [ ] Gap 1: warnTime 5-second alert not firing
- [ ] Gap 2/3: handler deregistration + reload safety

### Layer 2 minor gaps
- [ ] ThemeEngine Gap 2: no key validation on setOverride()
- [ ] LayoutEngine Gap 3: save() no error handling
- [ ] LayoutEngine Gap 2: resetAll() missing
- [ ] WindowRegistry Gap 7: saveState() no error handling
- [ ] WindowRegistry Gap 2: stale comment says 18 windows (actually 20)
- [ ] WindowRegistry Gap 6: visibility state not character-bound

---

## DSL CommandRef — Still Needed

- [ ] scan output format (needed before Scan/RightHere windows)
- [ ] group/gr output format (needed before Group window)
- [ ] consider <mob> output (needed for Target window)
- [ ] weather description lines (needed for MoonWeather)
- [ ] equipment/eq output format
- [ ] improve command output (no-argument form)
- [ ] Black moon lunar output (needs evil-aligned character)
- [ ] Combat output lines (needed for BattleCondenser port)
