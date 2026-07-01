# DSL Observer UI — Changelog

Format: `[Date] [Version] Description`
Claude Code appends one entry per commit. Claude.ai appends session summaries.

---

## Session: June 9, 2026 — Research & Contract Phase

**No code changes made this session.**

### What was accomplished:
- Uploaded DSL2 autosave.xml — all 13 Layer 2/3 scripts extracted and available
- Full Mudlet API education: built Parts 1 & 2 of API reference
- Built feature comparison matrix (DSL1 vs PNP vs new MyDSL)
- Built project backlog from all scattered notes
- Built DSL_CommandRef.md from actual in-game text captures
- Written Contract_DataLayer.md from actual code review
- Established three-tool workflow (Claude.ai + Claude Code + Steven)
- Confirmed git branch strategy and session rituals

### DataLayer bugs confirmed:
- 10 broken score parser patterns (wrong field names/formats)
- 2 flags parser bugs (can't detect on/off state)
- Who parser broken for hyphenated races
- Lunar, time, affects text parsers all wrong format
- Missing: no equipment section

### DSL game data confirmed:
- Prompt is 3 lines, event-driven (not per-command)
- GMCP fires after every server response
- 14 chat channels confirmed
- Moon system: 3 moons, Kien sees red+white only (neutral alignment)
- Calendar: 1 year = 13 real days 15 minutes

### Files created this session:
- `DSL_CommandRef.md` — in-game text patterns with confirmed Lua patterns
- `Contract_DataLayer.md` — DataLayer contract with all confirmed bugs
- `DSL_SessionNotes.md` — session log
- `SESSION_START.md` — this update
- `CHANGELOG.md` — this file
- `TODO.md` — actionable backlog
- `README.md` — project master index

---

## Pre-Session History (reconstructed from memory/audit)

### ~June 2026 — Layer 3 Phase A
- Ported 7 display modules from DSL1: ChatWrapper, AffectsView, LiveView,
  TickSource, TickView, PortraitView, LocationView
- DataBridge and RouteHelper added
- Chat routing triggers imported to Trigger editor
- HP/Mana/MV bars showing, affects populating, tick counting
- Mapper loaded with DSL1 map data

### ~June 2026 — Layer 2 Complete
- ThemeEngine, LayoutEngine, WindowRegistry built
- 21 windows registered and positionable
- All positions stored as percentages

### ~June 2026 — Layer 1 (DataLayer) v1.0
- Written from scratch, replacing DSL1's SourceCore
- Clean event bus, per-character data separation
- Duplicate handler prevention
- Per-section state guards (the prior initialization bug fixed)
- Git: `e6af3d1 — DSL2 clean profile — carry-over files from DSL1 with DataLayer bug fix`


---

## Session: June 14–21, 2026 — Full Layer 2/3 Phase A Contract Pass

**No code changes made this session — pure design/contract/research session.**

### Contracts written from actual extracted code:
- Contract_ThemeEngine.md — persistence, character-binding, named presets designed
- Contract_LayoutEngine.md — screenshot-corrected positions for all 21 windows
- Contract_WindowRegistry.md — MyDSL_Location rename, MyDSL_Mapper removal decided
- Contract_DataBridge.md — 6 gaps found, 3 entire sections (time/affects/score) unmapped
- Contract_RouteHelper.md — color-stripping bug found (Gap 1), routeMap dropped
- Contract_TickSource.md — 5-second warning bug confirmed (config exists, logic missing)
- Contract_TickView.md — confirmed visual warning DOES work, only audio/echo missing
- Contract_ChatWrapper.md — 5.0s forced rebuild wipes early-session chat (Gap 2)
- Contract_AffectsView.md — confirmed best-quality module, registerHandlerOnce is the template
- Contract_PortraitView.md — CharPic removal confirmed and decided
- Contract_LocationView.md — confirmed roomData() is LiveView's primary room data source
- Contract_LiveView.md — baseline only, deliberately paused for full design session

### Major architecture discovery:
- Mudlet has native UserWindow docking (docked/dockPosition/autoDock/restoreLayout)
  and native layout persistence (saveWindowLayout/loadWindowLayout with version
  numbers) that replaces most of LayoutEngine's planned custom persistence system
- Multiple windows docked to the same side auto-tab via Mudlet's Qt layer —
  confirmed by screenshot (Map/Scan/Combat tab together on the left)
- Critical caveat found: loadWindowLayout() must be called once, after all
  windows are created — calling it per-window resets every other window

### DSL1 mapper script fully audited:
- 8 confirmed DSL-specific patches on top of stock generic_mapper v2.1.8
- All center on room-description matching/cleaning for duplicate room names
- download_path disabled to protect patches from being overwritten by auto-update
- Must be carried forward to DSL2 as-is, never reinstalled fresh

### Screenshots analyzed (3 total):
- Full DSL1 layout reference — corrected all 21 window positions
- Stacked/tabbed dock confirmation — Map/Scan/Combat native tab group on left
- Tick window position — standalone, between Live and Target, Alterform slot confirmed for future

### Prompt system fully designed:
- Toggleable pretty prompt (gag 3 lines + new PromptBar overlay)
- Confirmed no extra prompt-text capture needed — alignment from score,
  day/night derived from time command (existing trigger runs it 2x/game-day)

### GMCP structure further confirmed via live captures:
- Two time-command format variants found and documented
- Affect fields (n/d/lc/m/t) cross-verified against AffectsView's correct handling
- (AR) = Arkane kingdom confirmed
- Two moons visible to Kien (red/white), black moon confirmed evil-only

### Files created/updated this session:
- 8 new Contract_*.md files (ThemeEngine, LayoutEngine, WindowRegistry,
  DataBridge, RouteHelper, TickSource, TickView, ChatWrapper, AffectsView,
  PortraitView, LocationView — final count includes earlier-session DataLayer)
- Contract_Addendum_2026-06-21.md — cross-cutting decisions superseding
  parts of LayoutEngine, WindowRegistry, RouteHelper, PortraitView contracts
- SESSION_START.md — full rewrite reflecting all 12 contracted modules
- TODO.md — full rewrite, blocking items clearly separated from design work
- CHANGELOG.md — this entry

---

## Session: June 21, 2026 (continued) — LiveView Design Finalized

No code changes — design and validation session.

### LiveView fully designed via iterative collaboration:
- Built interactive drag-and-drop mockups (Visualizer tool) so the user could
  physically arrange stat blocks rather than describe layouts in words
- Final layout: 12-row design, header (room/exits/identity/badges/time) +
  attribute rows paired with their combat stat (mirroring DSL's own score
  sheet pairing: STR+Hit, INT+Dam, WIS+Armor) + four bars (HP/Mana/Move/
  Improve) with graduated danger-color thresholds
- No compact/full toggle — single unified view per explicit decision
- Window is floating with restoreLayout=true (not docked), allowed to grow
  taller than the standard bottom-strip height; user resizes once

### Validated against real Mudlet/Qt constraints before finalizing:
- Confirmed Geyser gauges (front/back/text triple-label pattern), dynamic
  per-render color swapping, and percentage+pixel mixed positioning are all
  supported — consistent with patterns already used in TickView/PortraitView
- Found: Qt QLabel does NOT support CSS text-overflow:ellipsis — room name
  truncation must be done via Lua string cutting, not a stylesheet property
- Found: absolute pixel positioning breaks at different resolutions (same
  bug already flagged in MyDSL_Audit.md for old LocationView) — all LiveView
  children use percentage positions instead

### New gaps surfaced (added to TODO.md):
- DataLayer: Items count was never parsed at all — new field, not a fix
- DataBridge: needs hitroll/damroll/armor/items/posn added to DB.score
- DataBridge Gap 3 (DB.time): priority raised, now has a concrete consumer

### Files updated this session:
- Contract_LiveView.md — full rewrite, baseline superseded entirely
- SESSION_START.md, TODO.md — LiveView moved from "next" to "done"
2026-06-21 fix: DataLayer text parsers — HitRoll/DamRoll/Armor/Align/Pos'n/GOLD/BANK/PRACT/TRAIN/Craft/PKill patterns corrected; Items field added; Flags X/space detection fixed; Lunar rewritten for 2-line format; Time handles both HH:MM and HH:MM o'clock; Who captures race+class; Affects text uses Spell:/modifies format
2026-06-24 fix: DataBridge gaps 1-4 and 6 — DB.time and DB.affects sections added; score text fields (align/race/class/religion/profession/crafts/xp/practices/trains/bank/qpoints/hitroll/damroll/armor/items/posn) merged into DB.score without overwriting GMCP fields; DB.room.area replaced with DB.room.sector; listeners added for score.updated, time.updated, affects.updated
2026-06-24 fix: RouteHelper — appendBuffer mode for color-preserving passive routing, decho mode for explicit messages; routeMap removed (addendum); Route.clear() and Route.getConsole() added; Route.bloodbath() shorthand added; shorthand helpers now use direct DSL2 window names
2026-06-25 fix: ChatWrapper — Gap 2: 5s startup timer now guards before rebuild (revive if EMCO healthy, createInWindow only if broken); Gap 3: fallback window position corrected to x=78% w=22% h=46%; Gap 5: getWindowEntry() uses canonical MyDSL_Chat key only (removed Chat/windowId fallbacks that were always nil)
2026-06-25 fix: TickSource — Gap 1: warnTime alert fires safeRaise("MyDSL.Tick.Warning", rem) when remaining hits threshold; Gap 2: deregisterHandlers() kills old handler IDs on reload (pcall killAnonymousEventHandler); Gap 3: loop generation counter aborts stale tempTimer chains on reload; also raises MyDSL.Timers.Updated alongside Pulse each step
2026-06-25 fix: rename MyDSL_RoomPicture → MyDSL_Location in WindowRegistry (entry + 5 comments/fallback), LayoutEngine (defaults key + comment), LocationView (getWindowEntry lookup); remove MyDSL_Mapper from WindowRegistry and LayoutEngine defaults per Addendum §6; remove MyCore dead code from LocationView roomData() sources; fix MyDSL_Tick defaults to confirmed position x=0.59 y=0.79 w=0.03 h=0.21
2026-06-25 feat: PromptView — MyDSL.Prompt module with character-bound enabled toggle (save/load/onLogin), setEnabled/toggle/_cmd alias handler; handler deregistration on reload; listens for MyDSL.login.updated; two trigger specs documented in file for manual entry (MyDSL_PromptGag_Vitals, MyDSL_PromptGag_Location)
2026-06-25 fix: WindowRegistry — Gap 5: applyBorders() (23%/22%/21%) called at ensureAll() and on sysWindowResizeEvent (_resizeHandler); onLogin() calls loadWindowLayout(charLayoutVersions[name]) then applyBorders() (window reset fix); saveLayout() calls saveWindowLayout(); mydsl save layout alias with _saveAliasInstalled guard; login handler on MyDSL.login.updated with pcall deregistration
2026-06-25 fix: WindowRegistry — port DSL1 constructor patch approach: patchUserWindowConstructor() monkey-patches Geyser.UserWindow.new to inject restoreLayout=true/autoDock=true on every UserWindow; removed charLayoutVersions/onLogin()/_loginHandler/saveLayout(charVersion); loadWindowLayout() called plain (no version arg) via tempTimer(1s) and tempTimer(3s) after ensureAll(); saveLayout() simplified to saveWindowLayout() + saveProfile()
2026-06-25 fix: WindowRegistry — remove restoreLayout=true from constructor patch (conflicts with x/y/w/h at creation per Mudlet Geyser docs); add saveWindowLayout()+saveProfile() after ensureAll() to establish baseline layout at default positions before user arranges windows
2026-06-27 fix: WindowRegistry — layout persistence: baseline saveWindowLayout() after ensureAll(), loadWindowLayout() on 1s+3s startup timers, debounced auto-save on sysWindowResizeEvent (2s settle), mydsl layout save alias
2026-06-28 fix: WindowRegistry — remove saveWindowLayout at startup and auto-save on resize; single immediate loadWindowLayout() after ensureAll(); saveLayout() captures live Geyser positions into LayoutEngine before saving Qt state; 3s timer restored to match DSL1; sysWindowResizeEvent handler removed from LayoutEngine (was snapping windows to defaults on every dock operation)
2026-06-28 fix: DataLayer score parser — stats flattened (scoreBlock.str not scoreBlock.stats.str); weight/max_weight added (was missing); field names normalised to snake_case (hit_roll, dam_roll, armor_pierce/bash/slash/magic); PRACT:/TRAIN: patterns corrected from Practices:/Trains:
2026-06-29 fix: DataLayer score trigger wiring — tempRegexTrigger("^Score for ") registered in DataLayer itself (no Mudlet XML triggers existed); beginScore() installs catch-all line trigger; two-separator logic in parseScoreLine() handles opening/closing --- lines; endScore() kills catch-all trigger
2026-06-29 v1.0-phase-a-complete — Phase A smoke test passed. All Layer 1 and Layer 2 systems confirmed working. Score parser operational. One known minor issue: stance field captures trailing text — fix in next pass. Profession field missing — endScore fires before PROFESSION line.
2026-06-29 fix: score stance captures only first word (%S+ not .+); profession field restored via three-separator logic (_saw_profession flag gates endScore); Phase A fully complete with zero remaining issues — stance="Offensive" ✅ profession="Pickpocket" ✅
2026-06-30 fix: rewrite parseLunarLine and verify parseTimeLine for actual DSL output — beginLunar pre-sets has_bonuses=false on all three moon sub-tables; parseLunarLine uses three-capture pattern, strips "in " prefix from position, renames visibility→position, fixes %s+ whitespace matching in bonus patterns, fixes hours_remaining pattern for "19 1/2 Hours" format, sets has_bonuses=true when bonus block parsed; parseTimeLine verified correct (handles both HH:MM and HH:MM o'clock formats)
2026-06-30 fix: wire lunar block triggers in DataLayer Section 10 — permanent tempRegexTrigger on "^The (red|white|black) moon is" calls beginLunar(), parses first line, installs catch-all; catch-all feeds each line to parseLunarLine(), detects blank line to call endLunar() and kill itself; guard prevents beginLunar() re-entry when catch-all already active; weather trigger deferred with TODO comment
2026-06-30 feat: add MyDSL_MoonWeather Phase B HUD widget — Adjustable.Container with lockStyle="padding", AutoSave/AutoLoad; three Geyser.Label image slots (left/center/right) + one text label; focal moon derived from score.align via case-insensitive find (default red); phaseToFile+phaseAbbrev+phaseBonus tables; applyMoonSlot() with PNG/Unicode fallback; buildFocalText() shows phase·position + wiki bonus + regen/cycles/hours (has_bonuses=true only); buildTimeRow() shows ☀/✦ indicator + clock + day + date; four event handlers (lunar/weather/tick/login .updated); gag triggers for moon/bonus lines; mydsl moon toggle/on/off/font aliases; MW.init() safe-reload pattern kills old handlers before re-registering
2026-06-30 fix: add lockStyle=padding to MoonWeather container in WindowRegistry — registry entry gains lockStyle="padding" field; Container creation block passes entry.lockStyle to Adjustable.Container:new() (nil for all other containers, so no behaviour change elsewhere)
2026-06-30 fix: moon slot sizing (pixels), black moon dim (#222222/18pt/not-visible text), time row event (MyDSL.time.updated), gag toggle default OFF with setGag()+aliases
2026-06-30 refactor: single-label HTML table layout in MoonWeather — one Geyser.Label at 100%x100%, moonSlotHtml() returns HTML, render() builds 3-row table, no Geyser pixel math
2026-06-30 fix: time row event/field names in MoonWeather — MyDSL.State.tick.time is clock string not period; isDay now derived from ampm; debugc logging added to buildTimeRow()
2026-06-30 fix: wire parseTimeLine() trigger in DataLayer Section 10 — root cause of time row "-- -- --"; tempRegexTrigger("^It is ") now calls parseTimeLine(getCurrentLine()); expanded buildTimeRow() debug logging to include State.tick block
2026-06-30 fix: correct time row field names, event name, data source — buildTimeRow() now reads MyDSL.DB.time (not State.time); uses db.clock/db.is_day/db.day_name/db.month; display order corrected to day→clock→date; debug logging updated to dump DB.time; Contract_MoonWeather.md Implementation Notes corrected
2026-06-30 fix: remove debug logging from buildTimeRow() — 16 debugc() lines removed; function is clean
2026-06-30 docs: add all contract and session docs to git tracking — 19 previously untracked docs/*.md files now versioned
2026-06-30 docs: update Contract_DataBridge to reflect current state — Gaps 2/3/4/6 marked fixed; field mappings rewritten to show DB.time, DB.affects, full DB.score text fields, correct DB.room.sector; Gap 1 confirmed not a bug; Gap 7 (no DB.equip) added; contract status table updated
2026-06-30 fix: time row ordinal number and day/night indicator in MoonWeather — ordinal() returns suffix only; call site now prepends db.day_num ("25th" not "th"); isDay derived locally in buildTimeRow() from db.hour+db.ampm instead of relying on db.is_day (eliminates stale-data timing risk)
2026-06-30 fix: time row ordinal display and remove unreliable is_day — confirmed both time formats work (o'clock and plain); confirmed day_num stored as integer by parseTimeLine(); is_day removed from DB.time (Algoron day/night does not follow 12h clock); buildTimeRow() now shows fixed neutral ✦ (#888888); clock text fixed to #cccccc; Contract_MoonWeather.md updated with is_day deferral note
2026-06-30 milestone: MoonWeather confirmed working in-game — three moon slots, phase/bonus text, time row all verified; tagged v1.1-moonweather-complete
2026-06-30 note: score parser stance+profession bugs confirmed already fixed (commit 468ee77 / Jun-29) — SESSION_START.md was stale; no changes needed
2026-06-30 feat: wire sunrise/sunset and weather triggers, real day/night indicator — State.time.is_night added (default false); sunrise/sunset triggers confirmed from live session (Steven 2026-06-30); weather trigger uses broad pattern with keyword guard in parseWeatherLine(); DataBridge DB.time.is_night added; MoonWeather buildTimeRow() restores ☀/✦ from is_night
2026-06-30 fix: correct night trigger to 'The night has begun.' and add GMCP clock fallback for is_night — removed wrong 'The sun slowly disappears in the west.' pattern; State.time.is_night now starts nil (not false) so DataBridge can detect first-load; DataBridge computes gmcpIsNight from gmcp.tick.time as fallback before any trigger fires; explicit if/else avoids Lua boolean-false bug in and/or idiom
