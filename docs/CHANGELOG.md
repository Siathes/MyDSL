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
