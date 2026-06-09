# DSL Observer UI — Session Context

## Project
Building a modular 4-layer Observer UI for Dark and Shattered Lands (DSL) on Mudlet 4.20.1.
Player: Vzon master account. Main build character: Kien (W-Elf Druid 51).
Screen resolution: 1920x1080.

## Profile Directories
- OLD profile (DSL1): /home/owner/Desktop/Mudlet/mudlet-data/profiles/DSL1
- NEW profile (DSL2): /home/owner/Desktop/Mudlet/mudlet-data/profiles/DSL2
- Git repo: initialized in DSL2
- All new work happens in DSL2. DSL1 is reference only.

## Architecture — 4 Layers
1. Data Layer (COMPLETE) — MyDSL_DataLayer.lua — passive GMCP + text capture
2. Window Layer (COMPLETE) — ThemeEngine, LayoutEngine, WindowRegistry — 21 windows
3. UI Layer (PHASE A COMPLETE) — display modules ported, chat routing, vitals bars working
4. Reference Layer (NOT STARTED) — item/mob/location database, pop-up library

## Design Philosophy
See DSL_UI_Philosophy.md — The Observer UI.
Passive observation only. Main console kept clean. Every module optional.
Stale data beats spam. No automation of gameplay.

## Current State — What Is Working
Layer 1: MyDSL_DataLayer.lua — GMCP capture confirmed working
Layer 2: All 21 windows registered and positioned
Layer 3 Phase A: All display modules confirmed working:
  - Chat window (EMCO) — tabs All/Local/City/OOC/Tells/Group routing correctly
  - Affects window — GMCP affects displaying with cycle counts
  - Live window — HP/Mana/MV bars showing correct values and percentages
  - Tick window — countdown working, avg 40s
  - Portrait window — structure working (needs portrait image files)
  - Location/RoomPicture window — working (needs room image files)
  - History window — receiving routed notification lines
  - DataBridge — translating MyDSL.State → MyDSL.DB for display modules

## Installation Method
Package: MyDSL_Full.mpackage (13 scripts, files at ZIP ROOT not in subfolder)
Install via Mudlet Lua console: installPackage("/home/owner/Desktop/Mudlet/mudlet-data/profiles/DSL2/MyDSL_Full.mpackage")
Triggers: Import MyDSL_GameplayTriggers.xml via Triggers editor → Import

## Key Technical Lessons Learned
- mpackage ZIP: files must be at ZIP ROOT (config.lua, MyDSL_Full.xml) not in a subfolder
- config.lua format: flat variables (mpackage = [[name]]) NOT a Lua table
- Trigger XML: regexCodePropertyList uses <integer> tags NOT <int> tags
- Trigger attributes: must include isColorizerTrigger, isColorTriggerFg, isColorTriggerBg
- setStyleSheet not available on UserWindow/Container — theming deferred to Layer 3 Phase B
- sysWindowResizeEvent snaps windows — disable handler after connect until position-save is wired

## Post-Connect Workaround (until Layer 3 Phase B wires position-save callbacks)
Run in Lua console after each connect:
if MyDSL.Layout._handlers.resize then killAnonymousEventHandler(MyDSL.Layout._handlers.resize) MyDSL.Layout._handlers.resize = nil end

## Windows Registered (21 total)
UserWindows (visible by default):
  Chat, Affects, Portrait, RoomPicture, Live, Tick, Combat, Scan,
  Group, Target, RightHere, PlayersNear, History

UserWindows (hidden by default — toggle on demand):
  Mapper, Inventory, Equipment, CreatureReference

Containers (visible by default):
  MoonWeather

Containers (hidden by default):
  AsciiMap, Banner, Bloodbath

## Script Load Order (MyDSL_Full package — 13 scripts)
1.  MyDSL_ThemeEngine
2.  MyDSL_LayoutEngine
3.  MyDSL_WindowRegistry
4.  MyDSL_DataLayer
5.  MyDSL_DataBridge       ← translates MyDSL.State → MyDSL.DB
6.  MyDSL_RouteHelper      ← routes text lines to windows
7.  MyDSL_TickSource       ← tick timing authority
8.  MyDSL_ChatWrapper      ← EMCO chat in MyDSL_Chat window
9.  MyDSL_AffectsView      ← affects display from GMCP
10. MyDSL_LiveView         ← HP/Mana/MV bars, room info
11. MyDSL_TickView         ← tick countdown display
12. MyDSL_PortraitView     ← character portrait image
13. MyDSL_LocationView     ← room picture image

## Known Issues / Next Tasks
1. Group tell duplicate capture — two patterns both fire for "You tell the group"
2. Portrait images need copying from DSL1 to DSL2 portrait directory
3. Room pictures need copying from DSL1 to DSL2 roompic directory
4. PortraitView getWindowEntry() still uses MyDSL.Windows.windows — fix in Phase B
5. Chat trigger refinement — voice type variants need testing
6. Mapper needs prompt pattern set: prompt %n% hidden, use generic mapper's map prompt command

## Layer 3 Phase B — Next Work
- Combat window: BattleCondenser port from PNP
- Scan window: capture and display scan output
- RightHere window: same-room mobs, clickable for target
- Target window: redesign with mob vs player options
- Group window: group command output, clickable party members
- PlayersNear window: where command output, clickable player names
- Live/Character panel redesign: stats, armor, money, position, stance
- MoonWeather widget: three moon phases, time, weather

## GMCP Field Reference (confirmed from live testing)
char_data: hp, max_hp, mana, max_mana, move, max_move, str, int, wis, dex, con,
           language, stance, gold, silver, carry_weight, can_carry_weight,
           tnl, wimpy, is_flying, is_riding, is_fighting, is_afk, is_quiet
login_data: name, level, kingdom, is_clan, is_kingdom, time
room_data: room (full name), exits (array), sector
tick: time
affect_data: affects[] with fields n(name), d(duration), lc(location), m(modifier), t(type)
add_affect: same fields as affect_data.affects entries
No GMCP for: score, inventory, equipment, weather, lunar, who — text capture only

## DSL Namespace
MyDSL.State.char    ← GMCP char_data (DataLayer)
MyDSL.State.room    ← GMCP room_data (DataLayer)
MyDSL.State.login   ← GMCP login_data (DataLayer)
MyDSL.State.tick    ← GMCP tick (DataLayer)
MyDSL.State.affects ← GMCP affect_data (DataLayer)
MyDSL.DB.live       ← translated vitals for LiveView (DataBridge)
MyDSL.DB.score      ← translated stats for LiveView (DataBridge)
MyDSL.DB.room       ← translated room data (DataBridge)
MyDSL.DB.tick       ← translated tick data (DataBridge)
MyDSL.Windows       ← window registry (WindowRegistry)
MyDSL.Layout        ← layout engine (LayoutEngine)
MyDSL.Theme         ← theme engine (ThemeEngine)
MyDSL.Route         ← text routing (RouteHelper)

## How To Start A New Claude Code Session
1. Read SESSION_START.md
2. Read DSL_UI_Philosophy.md
3. Run git log --oneline
4. Ask what the current task is

## Mudlet Reference
- API: https://wiki.mudlet.org/w/Manual:Lua_Functions
- Events: https://wiki.mudlet.org/w/Manual:Event_Engine
- Best practices: https://wiki.mudlet.org/w/Manual:Best_Practices
