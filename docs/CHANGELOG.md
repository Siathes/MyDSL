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
2026-07-01 feat: wire day/night period from prompt parser — parsePromptLine() added to DataLayer (Section 9d2); fires on every prompt line 2 '==-Night Time - 5:00am :: ...'; captures period string, sets State.time.period + is_night on every server event; DataBridge priority updated: period > sunrise/sunset trigger > GMCP clock; fixes day/night indicator unreliability vs rare trigger events
2026-07-01 refactor: compact stacked layout, living clock display, day_name fix — moonSlotHtml sizes reduced (focal 32pt/32px, sides 18pt/20px); buildTimeRow() rewritten as 3-line stacked layout (indicator+period, clock, date); date line strips 'the ' month prefix and uses day_name directly from State.time; row heights 50/20/30%%, cellspacing=0; debug lines added for day_name field confirmation
2026-07-02 fix: clock anchor via State.time, remove half-hour snap — MW.clockAnchor(tickStr) replaced with MW.setClockAnchor() reading MyDSL.State.time directly (gmcp may be nil in anonymous handlers); anchor_h24/anchor_min consolidated to anchor_game_min (total DSL minutes 0-1439); gmcp.tick.time still used as fallback for the minutes component only; MW.clockStr() uses anchor_game_min with %02d format so clock visibly counts forward every second; setClockAnchor() called from tick/time handlers, onTickUpdate, onTimeUpdate, and init()
2026-07-02 fix: clock hour rollover — only anchor on time command not on tick — removed MW.setClockAnchor() from tick handler and onTickUpdate(); tick fires every ~41s which was resetting anchor_game_min to the last typed time, preventing hour rollover; anchor now only set from onTimeUpdate()/time handler (player types 'time') and init() startup; clockStr() math rolls hours correctly without interference
2026-07-02 fix: clock drift — derive DSL rate from live TickSource average — replaced hardcoded 60/82.5 rate with 30/tick_avg where tick_avg=MyDSL.DB.tick.average (smoothed real-time interval from TickSource); each GMCP tick advances exactly 30 DSL minutes so this gives the true rate; fallback to 40s before TickSource stabilises; eliminates ~3.8% systematic drift from the old constant
2026-07-02 fix: anchor clock to gmcp.tick.time every tick, eliminate drift — MW.setClockAnchor() now accepts optional tickStr parameter; tick handler and onTickUpdate() pass gmcp.tick.time (exact DSL clock, no drift); init() also tries gmcp first; onTimeUpdate() still calls with no arg (State.time fallback for minute precision); clock stays perfectly synchronised without relying on rate approximation
2026-07-02 fix: parse minutes in parseTimeLine, time command no longer resets clock — DataLayer: added min capture group to parseTimeLine() pattern (:%d+ → :(%d+)), stores State.time.minute=integer; MoonWeather: setClockAnchor() fallback now uses t.minute or 0 (was hardcoded 0); onTimeUpdate() and time handler only call setClockAnchor() when anchor_real is nil (no tick anchor yet), preventing `time` command from resetting clock position mid-session
2026-07-02 style: reorder time/period line, gold bonus text, minimize title — buildTimeRow() condensed from 3 lines to 2: clock+indicator+period merged onto one line ("1:34 am  ✦  Night"), date line unchanged; period label abbreviated ("Night Time"→"Night", "Day Time"→"Day"); bonus colors in buildFocalText() changed from green/red to gold (#ffcc44) for all non-zero values; container:setTitle(" ") added to _buildUI() to minimize title bar chrome
2026-07-02 style: attempt to remove outer container border — added container:setStyleSheet() in _buildUI() (transparent background, border:none, no padding/margin) wrapped in pcall in case Adjustable.Container does not expose the method; label border-radius changed 4px→0px for flush fill
2026-07-02 fix: remove outer border via adjLabelstyle constructor param — replaced post-creation setStyleSheet() pcall (doesn't work on Adjustable.Container) with adjLabelstyle="background-color:rgba(0,0,0,0); border:none; padding:0px;" in the Container:new() constructor; requires profile reload to take effect since _buildUI() only runs on first init()
2026-07-02 milestone: MoonWeather feature-complete — border removed (adjLabelstyle), clock anchors to gmcp.tick.time every tick (zero drift), minutes parsed from time command, date re-anchors via existing dawn/dusk triggers firing time command (no calendar math), all visual tweaks done (gold bonuses, merged clock/period line, minimized title). Tagged v1.2-moonweather-final
2026-07-02 feat: live moon phase countdown + regen gold color — added MW._lunar anchor table, setLunarAnchor()/cyclesNow()/countdownStr(); onLunarUpdate() and init() seed the anchor; buildFocalText() line 3 now shows "Regen+10%  57cy · 39m" with regen in gold (#ffcc44) when non-zero and live-decrementing countdown; static hours_remaining removed
2026-07-02 fix: lunar countdown anchor + remove stale debug lines — setLunarAnchor() no longer uses focalMoon()/alignment; now scans all three moons for the one with has_bonuses=true (only the aligned moon gets bonuses from `lunar`), fixing nil countdown when score not yet loaded; removed two debugc day_name lines from buildTimeRow() (fire every second, confirmed working)
2026-07-02 fix: wire setLunarAnchor into lunar event handler — _registerHandlers() lunar.updated callback only called render(); setLunarAnchor() was never being called from the wired handler so anchor_real stayed nil and countdownStr() always returned nil; fixed by adding setLunarAnchor() to the reg() callback (init() already had the call)
2026-07-02 fix: wire lunar anchor + remove redundant has_bonuses gates — lunar handler and init() already wired (previous commit); removed has_bonuses guard in setLunarAnchor() scan (cycles_remaining non-nil already implies bonus block parsed) and in buildFocalText() regen/countdown line (same reason)
2026-07-02 fix: countdown shows game-hours not real-world minutes — countdownStr() was dividing cycles×tick_avg/60 (real minutes); fixed to cycles×30/60 (DSL game-hours, 30 game-min per tick); display now matches `lunar` output "72 (36 Hours)" → "71cy · 35h"; tick_avg lookup removed as no longer needed; hours step at whole-cycle boundaries (~40s) which is acceptable
2026-07-02 fix: countdown half-hour precision matching game output — each cycle = 0.5 game-hours; countdownStr() now rounds to nearest half-hour and formats as "27 1/2h" or "27h" to mirror game's "27 1/2 Hours"/"27 Hours"; examples: 54cy→"54cy · 27h", 53cy→"53cy · 26 1/2h", 52cy→"52cy · 26h"
2026-07-02 fix: countdown cycles and hours use consistent floor rounding — previous code floored cyc_int but rounded total_half_hours, causing inconsistency (45.8cy→"45cy · 23h" instead of "45cy · 22 1/2h"); fixed by deriving hours from cyc_int: hours=floor(cyc_int/2), has_half=(cyc_int%2)==1
2026-07-02 fix: anchor lunar countdown at parse time not handler time — endLunar() now stamps State.lunar.parsed_at=os.time() inside the update() call (before emit fires); setLunarAnchor() uses parsed_at as anchor_real instead of os.time() at handler invocation; eliminates the ~40s event-chain delay that caused widget to always show 1 cycle less than game
2026-07-02 milestone: MoonWeather complete — all alignments verified (neutral/red, good/white, evil/black), live countdown working, 1-cycle offset known and deferred; next window: Scan/RightHere
2026-07-02 feat: add scan and creaturelore parsers to DataLayer — Section 3: State.scan and State.creaturelore guards; Section 9o: beginScan/parseScanLine/endScan with isMobName helper and byName/rightHere aggregation; catch-all ends on blank line/"Players near you:"/group header; ScanView gag flag delegated to parseScanLine; Section 9p: beginCreatureLore/parseCreatureLoreLine/endCreatureLore; parses alignment, wealth, sex, hp; merges into CreatureLore DB (nil-guarded); Section 10: scanAround, scanDir, loreStart tempRegexTriggers
2026-07-02 feat: add MyDSL_ScanView — Scan and RightHere display windows; renderScan() shows [Right Here] (deduplicated via byName with ×count) and [Nearby] (ordered rows); renderRightHere() shows clickable cechoLink entries calling MyDSL.Target.set(); setGag() manages header-line gag triggers; body gagging delegated to DataLayer; safe-reload pattern; mydsl scan gag/ungag aliases
2026-07-02 feat: add MyDSL_TargetView — target display and action buttons; MyDSL.Target.set/clear/toggle/doAction/captureConsider API; render() draws [M]/[P] toggle, 6 action button cechoLinks in 2 rows, consider output area; config persisted to getMudletHomeDir()/MyDSL/targetview_config.lua; consider capture triggers; mydsl target/mobset/playerset aliases; safe-reload kills old handlers/triggers/aliases
2026-07-02 feat: add MyDSL_CreatureReference — creature lore display window; listens for MyDSL.creaturelore.updated; onLoreUpdate() looks up DB then State fallback, renders, auto-shows window; render() outputs race/align/hp/xp/rooms/immunities/resists/vulns/drops/last-lored; formatNumber() adds comma separators; mydsl lore <name>/hide/show aliases; window hidden by default
2026-07-02 fix: guard nil State.scan on first load — DataLayer State.scan now initialised with full schema (rows={}/rightHere={}/byName={}); ScanView renderScan() splits nil-rows vs empty-rows check into two separate early returns; renderRightHere() guards not scan.rightHere before header cecho and before next() call; prevents crash on profile load before first scan
2026-07-02 fix: use Geyser MiniConsole object methods instead of global cecho — global cecho/cechoLink/clearWindow calls with string window name render raw color codes as literal text in Geyser MiniConsole objects; TargetView render() and ScanView renderScan()/renderRightHere() now use mc:clear()/mc:cecho()/mc:cechoLink() object methods; nil guard added at top of each render function
2026-07-02 fix: use decho for plain text in ScanView and TargetView MiniConsoles — mc:cecho() with <#rrggbb> hex tags rendered raw text in Geyser MiniConsole (cechoLink was working; plain cecho was not); all mc:cecho() calls replaced with mc:decho() using <r,g,b> RGB format and <r> reset; color variable values in renderScan() converted to RGB triplets; cechoLink display strings left unchanged (already working)
2026-07-02 fix: convert remaining cecho to decho in TargetView — toggle and button cechoLink calls still used <#rrggbb> hex colors in display text; TV.actions color values converted from hex to RGB triplets (204,68,68 / 136,204,170 / 170,170,255); type_color in render() converted to RGB; toggle_text and btn_text format strings use <r> reset; mc:cechoLink() replaced with mc:dechoLink() for both toggle and action buttons
2026-07-02 refactor: scan window uses appendBuffer via RouteHelper — renderScan() removed from ScanView; Scan window now fills passively as each body line arrives: DataLayer beginScan() clears SV.ui.scanConsole, catch-all calls selectCurrentLine()/copy()/appendBuffer() after parseScanLine(); SV.ui = {} added as public namespace exposing scanConsole for DataLayer; render() now calls only renderRightHere(); cechoLink useCurrentFormat changed to true (suppress underline)
2026-07-02 style: target buttons use dechoPopup, larger font, action colors — TV.actions colors updated (glance/consider/lore/look→204,204,204 near-white; heal→68,204,68 green); fontSize=11 in MiniConsole constructor + setFontSize(11) on every init; toggle dechoLink useCurrentFormat=true (suppress underline); action buttons replaced with dechoPopup(TARGET_MC, label, {gameCmd}, {hint}, false) — sends command directly on click, only renders when target is set
2026-07-02 fix: use dechoLink and decho RGB format in renderRightHere — cechoLink with <#rrggbb> hex colors in display text rendered raw codes in Geyser MiniConsole; mob/player/count color variables converted to RGB triplets (204,136,68 / 136,170,255 / 255,204,68); text format string uses <r> reset; mc:cechoLink() replaced with mc:dechoLink() (useCurrentFormat=true); newline folded into text string, removing separate mc:decho("\n") call
2026-07-02 style: use decho+setLink for unstyled clickable buttons in TargetView — dechoPopup added visible blue underline that cannot be suppressed; replaced with mc:decho(colored label) + mc:setLink(luaCmd, hint, false) pattern which attaches click handler without changing text appearance; toggle likewise changed from dechoLink to decho+setLink; button callbacks use MyDSL.Target.doAction(key) which already guards nil target
2026-07-02 fix: use dechoLink for clickable Target buttons — mc:setLink() does not fire click handlers on Geyser MiniConsole in Mudlet 4.20.1; replaced toggle [M]/[P] and all 6 action buttons with mc:dechoLink(text, luaCmd, hint, false); inter-button space folded into text arg for cols 1–2; mc:decho("\n") retained for row breaks
2026-07-02 fix: proper DSL command quoting for multi-word target names — added normalizeName() (strips articles a/an/the, commas, dots, normalises spaces) and commandArg() (apostrophe→last-word fallback, multi-word→single-quoted, single-word→bare); all 7 non-flee cmd functions in TV.actions now call commandArg(t.name); "a gnome student"→murder 'gnome student', "philosopher's assistant"→murder assistant
2026-07-02 milestone: Scan/RightHere/Target confirmed working in live combat — murder 'gnome student' landed, flee confirmed, full pipeline scan→righthere→target→action working end-to-end; tagged v1.4-scan-target-combat-confirmed
2026-07-03 feat: wire group triggers and catch-all body in DataLayer — beginGroup() now installs tempRegexTrigger(".*") catch-all (mirrors beginScan pattern); catch-all feeds lines to parseGroupLine(), calls endGroup() on blank line, delegates body gagging to MyDSL.GroupView.config.gagGroup check; endGroup() kills groupBody trigger before update(); Section 10: added MyDSL._triggers.groupStart on "^.+'s group:$"
2026-07-03 feat: add MyDSL_GroupView — group member display window — GV.render() reads State.group.members; class tag [War/Mob/etc] colored blue(player)/dim-yellow(mob); name truncated to 20 chars colored tan(mob)/near-white(player); HP% colored green/yellow/orange/red by threshold; mana% in blue and mv% in light-green shown only when <100; setGag() installs header gag trigger; body gagging delegated to DataLayer catch-all via config.gagGroup flag; "mydsl group gag/ungag" aliases
2026-07-03 fix: PCRE regex in group header triggers — tempRegexTrigger uses PCRE not Lua patterns; %' is wrong in PCRE (stray backslash); changed "^.+%'s group:$" to "^.+'s group:$" in DataLayer groupStart trigger and GroupView gagHeader trigger; the Lua string:match() in scanBody catch-all is unaffected (Lua %' is valid there)
2026-07-03 feat: expand TV.actions library with 10 healing/curative/buff spells — cure_light/refresh/cure_serious/cure_critical (green 68,204,68); cure_blindness/cure_disease/cure_poison/cure_fatigue/cure_bugbite (lavender 170,170,255); sanctuary (gold 255,215,65); all use commandArg(t.name); available to mobset/playerset immediately
2026-07-03 feat: add Clear button to TargetView line 1 — dim-red dechoLink "[Clear]" (170,68,68) inserted between [M]/[P] toggle and target name; only rendered when a target is set; calls MyDSL.Target.clear()
2026-07-03 feat: GroupView overhaul — mana%/mv% always shown (removed <100 conditionals); name is now dechoLink calling GV.setTarget(idx) with tooltip "Click to target: name"; quick-action buttons after mv% from GV.config.quickActions (default heal+rescue), reuse TV.actions entries, no mob/player filtering; added GV.setTarget(idx) and GV.quickAction(idx,key) functions; added "mydsl group quickset <k1> <k2>" alias; Contract_GroupView.md created; Contract_TargetView.md updated
2026-07-03 fix: PCRE \s/\S in tempAlias patterns — tempAlias uses pure PCRE (no Lua-% translation); %s/%S in three alias patterns were literal and never matched; fixed mobset/playerset in TargetView and quickset in GroupView to use \\s+/\\S+ (Lua string literal for PCRE \s+/\S+)
2026-07-03 fix: PCRE regex sweep — all remaining Lua-pattern escapes in tempRegexTrigger patterns removed; confirmed by live test (scan sw never populated Scan window) + Mudlet wiki; 7 patterns fixed across 3 files: DataLayer scanDir(%a+%.)→[a-zA-Z]+\\., sunrise/sunset(%.)→\\., weather([^%.]+%.)→[^.]+\\., loreStart(%s)→\\s; ScanView gagDir(%a+%.)→[a-zA-Z]+\\.; TargetView considerLine2(%.%.%.  )→\\.\\.\\. ; docs/MyDSL_MudletAPIReference.md created with confirmed PCRE rule + full bug table
2026-07-04 feat: add order_attack to TV.actions — "order all murder <arg>"; label "Order All"; red (204,68,68); opt-in only via mydsl target mobset/playerset, not added to default mob_buttons or player_buttons; Contract_TargetView.md updated
2026-07-04 fix(3 bugs confirmed live): (1) commandArg() now always returns last word only — DSL keyword matching only works on a single word regardless of quoting, confirmed via cast heal 'wild bear'/stallion/fire elemental all returning "They aren't here." while bare last-word succeeded; debug logging removed from doAction/quickAction; (2) GroupView rescue button now hidden for Mob rows — rescue only works player→player, confirmed rescue bear fails every time, order bear rescue kien succeeds; (3) DataLayer parseScanLine rightHere[key] now gets its own independent counter instead of a reference to byName[key] — fixes RightHere showing full-scan count (×6) instead of room-only count (×2); Contract_TargetView/GroupView/ScanView and MudletAPIReference updated
2026-07-04 feat: MyDSL_CombatView.lua — Phase B Combat window; DataLayer extended with State.combat, Section 9q (severity ladder 26 entries PNP-tuned, condition ladder, parseCombatDamageLine/AvoidLine/ConditionLine/DeathLine/EndLine/ProcLine), Section 10 unified damage trigger + 5 avoidance triggers + condition/death/flee/rescue triggers + 14 proc triggers (Frost/Flaming/Shocking/Vampiric/Stunning/ManaDrain/Holy/Unholy + Poison 3-step) + round-flush handler on MyDSL.time.updated; hp_raw added to char_data GMCP handler for rage detection; CombatView.lua with render()/renderSummary()/renderRage(), 7 aliases (clear/history/gag/ungag/show/hide); NOTE: requires dofile() wrapper in Mudlet Script editor (same pattern as ScanView/GroupView/TargetView)
2026-07-04 fix(5 post-review): three-way comparison (PNP source / contract / shipped code) found: (1) compound-noun proc forms ("life drain"→H vampiric, "shocking bite"→L lightning) never got flagged — NOUN_FLAG_MAP lookup added after noun capture in parseCombatDamageLine; vampiric also increments rage.vamp +2.5; (2) State.combat.last_updated never set — added to initializer (=0) and stamped os.time() before raiseEvent in round-flush handler; (3) combatCondition trigger missing gag check — gag_combat deleteLine() added matching pattern of combatDead/combatFlee/combatRescue; (4-5) config defaults all show_*=true gag_combat=false were wrong — corrected to all show_*=false echo_to_main=true gag_combat=true matching PNP's actual tested out-of-box behavior (display opt-in, combat gagged by default); Contract_CombatWindow.md Public API section updated
2026-07-05 fix(combat): replace goto/::continue:: in CombatView.render() — Mudlet uses Lua 5.1/LuaJIT which has no goto/::label:: (added in 5.2); file threw syntax error at dofile() time and never loaded; refactored per-entry loop body into local renderRoundEntry(mc, rd) with return in place of goto; grep confirmed no other MyDSL Lua file uses this pattern; MyDSL_MudletAPIReference.md updated with permanent Lua 5.1 version note and local-function pattern
2026-07-05 fix(combat): dodge/parry/block triggers only matched third-party phrasing ("Mob dodges Name's attack") and missed the you-as-subject/your-attack forms ("You dodge Mob's attack.", "Mob dodges your attack.") because the old regex hardcoded "dodges"/"parries"/"blocks" (3rd-person verb form only) and required a literal "'s attack"; replaced all three with DSL_PNP_Battle.lua's verbatim tested patterns (dodge/parry/block[s]? + your|Name's alternation) ported to our PCRE double-backslash convention; parseCombatAvoidLine(evader, verb, attacker) now reads the 3 capture groups directly instead of re-parsing getCurrentLine() with its own Lua patterns (sense triggers unchanged, still whole-line parsed); cross-check against PNP condition/death triggers found a confirmed-live gap (DSL-Logs show "You have some small wounds"/"You are in excellent condition"/"You look pretty hurt" -- second-person verb forms) that neither PNP nor our CONDITION_PATTERNS table handles at all -- self-condition currently never registers; not fixed here, flagged for follow-up
2026-07-05 audit: full PNP cross-check beyond evasion triggers (per Steven's request) — verified parseCombatAvoidLine cleanup (single 3-arg def, no duplicates), reworded combatDodge comment for accuracy; confirmed via DSL-Logs that self-condition uses second-person verbs ("You have some small wounds"/"You are in excellent condition"/"You look pretty hurt") vs third-person for others -- gap flagged in 2026-07-05 evasion-trigger entry above, still unfixed; searched DSL_PNP_Character.lua and DSL_PNP_Affects.lua for finishing-blow/execute mechanics -- none found, but DSL-Logs reveal "<mob> hits the ground ... DEAD." is a very common death form (188 occurrences in one session log alone) that NEITHER PNP nor our combatDead trigger (" is DEAD!!$") handles at all -- likely means most player-delivered killing blows never fire MyDSL.combat.ended; re-verified all 14 flag/proc trigger regex against DSL_PNP_Battle.lua lines 476-489 character-for-character (all 14 match) but found a deeper issue: PNP's flag handler never trusts names captured by the flag trigger itself (uses last_attacker/last_target/last_noun from the most recent damage line instead) specifically because those captures are often a WEAPON name, not the wielder -- confirmed live via DSL-Logs ("A whisper thin blade of satiny steel draws life from...", "is knocked to the ground by a grand arcanium polearm."); our procFlameBurn/procShockLightning/procVampDraw/procStun (and likely procFrostFreeze) pass that captured name straight into normalizeKey() as the attacker key, so entry.by_attacker[attackerKey] lookup silently fails and the flag is dropped every time -- not fixed here, architecture decision needed (adopt PNP's last-attacker-tracking model); staleness check found Contract_ScanView.md and Contract_TargetView.md both still show pre-fix PCRE code samples (scanDir %a+%./considerLine2 %.%.%. ) even though live code was already corrected 2026-07-03 -- Contract_GroupView.md is current; added "read PNP source directly" caveat to Contract_CombatWindow.md and MyDSL_PNP_Reference.md; docs/claude_export_2026-07-05/ created with state report + current file copies for Steven to upload to Claude.ai project
2026-07-05 fix(combat, 3 confirmed issues from prior audit): (1) added combatDeadGroundHit trigger + parseCombatDeathLine now also matches "<mob> hits the ground ... DEAD." alongside "<mob> is DEAD!!" -- confirmed via a full session log with 188 kills of this form and zero "is DEAD!!"; snapshotFight() already no-ops on an already-cleared target so no double-snapshot risk if both fire; (2) parseCombatProcLine now checks isKnownCombatant(attackerKey) (you/group member) -- weapon-flag procs whose "attacker" capture is actually a weapon name (confirmed: "A grand arcanium hoopak draws life from Rylae.", "is knocked to the ground by a runehammer.") now get their own by_attacker[weaponKey]["(proc)"] pseudo-row instead of being silently dropped; deliberate simplification, not full wielder resolution -- documented in Contract_CombatWindow.md; (3) procFrostFreeze/procVampDraw/procStun char classes now include " (double-quote) and strip it via new stripQuotes() helper before normalizeKey -- fixes quoted weapon names like "Nadrik's Honor" breaking the match; all three verified with luajit against real captured text. Also added a CONFIRMED note to MyDSL_MudletAPIReference.md that templates_by_freq.txt/templates_with_examples.txt are first-pass only -- both files are missing every death-ground-hit and weapon-flag-proc example despite dozens of real occurrences in log/, so absence there isn't evidence of absence; Contract_CombatWindow.md updated with all three fixes, the pseudo-attacker-key design note, and an updated Data Model example showing the new "(proc)" row shape
2026-07-05 docs: full project staleness audit after removing Claude.ai from the workflow -- spot-checked every Contract_*.md against live code; found Contract_TickSource.md's 3 listed gaps (warnTime, handler dereg, loop generation) already fixed by commit b16ec52 and never updated, Contract_ChatWrapper.md's 3 of 5 gaps (5s forced rebuild, fallback window position, fragile window-key lookup) already fixed and never updated (2 gaps -- hardcoded tab CSS, non-char-bound settings -- confirmed still open); TODO.md's DataBridge gap list (6 items) all confirmed fixed, RouteHelper's routeMap-removal already done and its decho/appendBuffer "gap" was never a real bug, DataLayer's two Phase-A score issues (stance/profession) confirmed fixed but TODO.md still listed as open; TODO.md's entire Phase B section said Combat/Scan/Group/Target were "not started" when all four were built -- full rewrite; SESSION_START.md rewritten (workflow section replaces old three-tool framing, Contract Status table updated); DSL_SessionNotes.md deduplicated (June 28-29 entry was pasted twice) and given a reconstructed summary entry for 2026-07-01 through 07-04 (no session notes existed for that stretch -- work is in CHANGELOG but was never logged here) plus a 2026-07-05 entry; SYNC.md's Module Inventory/Phase B Progress/Recommended Next Actions updated in place (namespace/event-convention sections untouched, still accurate); README.md rewritten to drop the three-tool/upload-folder framing entirely; DSL_CommandRef.md's stale TODO checklist corrected (scan/group/consider/lunar/time/weather were already captured elsewhere but never checked off; equipment/inventory genuinely still missing); MyDSL_MudletAPIReference_Part2.md was confirmed absent from the repo mid-audit, then Steven added it back (in two near-duplicate versions -- kept the corrected one, which itself fixed a stale "resize handler still needs retiring" section describing a 2026-06-25 fix as still-pending)
2026-07-05 docs: addressed three concerns raised by Steven -- (1) audited character-binding: confirmed no functional Kien hardcoding in live .lua code (all "Kien" hits are comments or legitimate per-character save data), but found 2 previously-unflagged gaps -- LayoutEngine window positions (MyDSL_layout.lua) and TargetView button config (MyDSL/targetview_config.lua) are both single shared files, not character-bound, contradicting the project's own recorded decision; added to TODO.md alongside the already-known ChatWrapper/WindowRegistry gaps; (2) confirmed cross-session file access already works via .claude/settings.local.json's Read(//home/owner/**) blanket grant (git-ignored but persists on disk across sessions on this machine); documented all sibling Mudlet profiles (PNP/PNP1/PNP2/DSL1/DSL-Kien/etc.) and ~/Downloads as known reference locations; (3) formalized "read PNP files/ and log/ directly, don't trust distilled summaries" as a standing practice, not a one-off. CLAUDE.md rewritten: removed Kien-primary-character framing that implied character-specificity, added explicit universal-character principle, added Reference Material section, added Character-binding status section, fixed stale "do not start Phase B" blocking language (Phase B is done) and stale "scripts not on disk" note. Also saved 4 cross-session memory entries (workflow change, verify-against-source lesson, universal-character requirement, reference locations) so this persists even before CLAUDE.md gets read.
2026-07-05 chore: post-restart commit review with Steven -- committed all combat fixes/doc audit work + EMCOChat (vendored dependency) + PNP files/ (46-file source reference, actively used for porting/cross-checking) + colors.xml (People/Friends name-coloring module, candidate for future MyDSL incorporation); removed MyDSL_Layer2/MyDSL_Layer2/ (stale nested duplicate, never tracked) and docs/claude_export_2026-07-05/ (dead weight after Claude.ai removal); .gitignore expanded for AdjustableContainer/ (confirmed auto-generated window-position cache, not modules), mpkg/+mpkg.packages.json (generic package-manager tool, not project-specific), DSL_PeopleColors_data* (accumulated data, not the module), loose Mudlet runtime/profile-connection files, and loose asset files; added two items to TODO.md surfaced from Steven's notes_utf8.txt (GroupView heal-on-pet bug, TargetView aura-based auto-target idea) -- notes_utf8.txt itself left untouched, it's Steven's actively-used in-game/feature notes file, not something to commit or ignore
2026-07-05 fix(combat): weapon-flag proc lines were never gagged from main console -- confirmed live via Steven's own cecho note during testing showing a raw "draws life from" Vamp-proc line staying on screen; none of the 17 proc trigger handlers ever called deleteLine(), unlike every other combat trigger which all gag correctly; added shared gagIfCombatGagged() helper, wired into all 17. Reviewed Steven's post-testing logs and cecho notes: no sustained combat occurred this session (no murder/damage verbs/deaths in any of the 16:21-18:08 logs), so evasion/death-form/group-fight-tracking fixes remain unconfirmed by real combat; one positive signal found (a solo "group" listing populated correctly). Confirmed and documented an important methodology limitation: Mudlet's HTML session logs never capture custom UserWindow/MiniConsole content (verified by grepping for "Fight summary"/"Right Here:" across every log including the session with a screenshot proving the fight-summary rendered at that exact moment -- zero matches, ever) -- logs can only confirm raw text/trigger-firing, never window display; that needs a screenshot. Also flagged (not yet resolved): a separate, pre-existing "itemstats" item-identification trigger system (319 hits in current/autosave.xml, unrelated to PNP files or our own code) does a bare cecho() with no leading newline, a plausible mechanism for silently breaking our $-anchored combat regexes when an item name appears inline in a combat line -- not conclusively proven this session, needs a deliberate test.
