# DSL Observer UI — TODO
*Updated June 21, 2026. Status markers: BLOCKING / NEXT / DESIGN / DECISION*

---

## DONE — LiveView Design (completed June 21)
Full layout finalized via collaborative drag-and-drop design: room/exits/
identity/badges/time header, 12-row stat-and-bar body with attribute/combat-
stat pairing matching DSL's score sheet, graduated bar colors, floating
window with restoreLayout. See Contract_LiveView.md. Surfaced two new gaps,
folded into BLOCKING below.

---

## BLOCKING — Fix Before New Windows Are Built

### DataLayer text parsers (all confirmed broken, patterns documented in Contract_DataLayer.md)
- [x] Score: HitRoll/DamRoll, Armor (P:/B:/S:/M:), Align/Pos'n/GOLD/BANK/PRACT/TRAIN, Craft, PKill
- [x] Flags: detect (X) vs ( ) state; AutoAssist(X) no-space format
- [x] Who: handle hyphenated races (W-Elf, M-Dwf, etc.)
- [x] Lunar: rewrite for confirmed 2-line format (moon line + bonus line)
- [x] Time: fix hour format, handle BOTH "9:30 am" and "10:00 o'clock am" variants
- [x] Affects text: rewrite for confirmed "Spell: X : modifies Y by Z..." format
- [ ] Add: equipment section (none exists currently)
- [x] Add: Items count parser ("Items: 87 (max 110)") — new field, never parsed before, needed by LiveView
- [ ] Verify: room_data field is "room" not "name" — confirm DataLayer's GMCP handler uses it correctly
- [ ] Verify: DataLayer's GMCP affect handler maps n/d/lc/m/t correctly (AffectsView already does — DataLayer needs checking)

### DataBridge gaps (Contract_DataBridge.md)
- [x] Gap 1: room.name field — depends on DataLayer fix above
- [x] Gap 2: room.area should be room.sector (area is not in GMCP at all)
- [x] Gap 3: DB.time section entirely missing — needed by LiveView
- [x] Gap 4: DB.affects section entirely missing
- [x] Gap 6: score text fields (align, race, class, religion, etc.) not mapped to DB.score
- [x] Gap 6 extended: also add hitroll, damroll, armor, items, posn to DB.score (needed by LiveView)
- [ ] Gap 3 (DB.time): now has a concrete consumer (LiveView's time row) — priority raised

### ChatWrapper (Contract_ChatWrapper.md)
- [ ] Gap 2: 5.0s forced rebuild wipes any chat from first 5 seconds of session — needs guard
- [ ] Gap 5: window key lookup tries wrong registry key — verify against corrected WindowRegistry

### RouteHelper (Contract_RouteHelper.md + Addendum)
- [x] Gap 1: uses decho() instead of appendBuffer() — strips ALL game colors from routed text. Critical fix.
- [x] Remove routeMap entirely per addendum decision — shorthand helpers become primary API

### TickSource (Contract_TickSource.md)
- [ ] Gap 1: warnTime configured but never fires — 5-second audio/echo alert doesn't work (visual DOES work via TickView)
- [ ] Gap 2/3: handler deregistration + timer loop generation counter (reload safety)

### Naming/rename cleanup (3 files, must happen together)
- [ ] MyDSL_RoomPicture → MyDSL_Location in: WindowRegistry, LayoutEngine, LocationView (Gap 3)
- [ ] Remove "MyDSL_RoomPicture" legacy key check from LocationView's getWindowEntry()

---

## DECISIONS RECORDED (ready for implementation, no further discussion needed)

- All settings (theme, layout, visibility) are character-bound — version numbers via saveWindowLayout/loadWindowLayout for positions, per-character files for theme
- Themes: user-creatable named presets, shared across all characters
- MyDSL_Mapper removed from WindowRegistry — minimap controlled via map.configs.map_window only
- Scan/Combat are native-docked + tabbed with the mapper on the left (not EMCO-style tabs)
- CharPic compatibility code removed from PortraitView entirely
- RouteHelper routeMap removed — shorthand helpers are the only API
- Prompt: toggleable pretty prompt, default ON, no extra data capture needed from prompt text
- Day/Night derived from `time` command output, not prompt capture
- Alignment from score only, persists until next score run, no auto-send

---

## DESIGN — Not Yet Started

- [ ] LiveView full redesign (see NEXT above)
- [ ] MyDSL_PromptView module — design is confirmed in SESSION_START, needs formal contract
- [ ] Layer 3 Phase B: Combat window (BattleCondenser port from PNP)
- [ ] Layer 3 Phase B: Scan/RightHere mob targeting windows
- [ ] Layer 3 Phase B: Group window with clickable party members
- [ ] Layer 3 Phase B: Target window (mob vs player interaction differences)
- [ ] Layer 3 Phase B: MoonWeather window
- [ ] Layer 4: Reference library (items, mobs, lore) — not started

---

## ThemeEngine / LayoutEngine / WindowRegistry — Smaller Gaps (low priority)

- [ ] ThemeEngine Gap 2: no key validation on setOverride()
- [ ] LayoutEngine Gap 3: save() has no error handling
- [ ] WindowRegistry Gap 7: saveState() has no error handling
- [ ] WindowRegistry Gap 2: stale comment says 18 windows, actually 21

---

## Per-Module Minor Gaps (ThemeEngine integration, character-binding for settings)

Every Phase A module except AffectsView and PortraitView (partially) has:
- Hardcoded colors instead of reading from MyDSL.Theme
- Settings files that are shared instead of character-bound (TickView, ChatWrapper, LiveView)
- Handler management using a flag instead of AffectsView's registerHandlerOnce pattern
  (TickSource, TickView, LiveView, LocationView all need this fix)

These are individually low-priority but collectively represent "propagate the
AffectsView pattern to every other module" — a good candidate for a single
focused Claude Code pass once the blocking items above are done.

---

## DSL CommandRef — Still Needed (data collection, not code)

- [ ] scan output format
- [ ] group output format
- [ ] improve command output (no-argument form)
- [ ] weather description lines
- [ ] equipment/eq output format
- [ ] consider <mob> output
- [ ] Black moon lunar output (needs evil-aligned character — Kien can't see it)
- [ ] Combat output lines (for BattleCondenser port)
