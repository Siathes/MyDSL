# DSL UI Project — Session Context

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
2. Window Layer (COMPLETE) — ThemeEngine, LayoutEngine, WindowRegistry — 18 windows live
3. UI Layer (NEXT) — fills windows with data, handles interaction
4. Reference Layer — item/mob/location database, pop-up library

## Design Philosophy
See DSL_UI_Philosophy.md — The Observer UI.
Passive observation only. Main console kept clean. Every module optional.
Stale data beats spam. No automation of gameplay.

## Current State
Layer 1 complete — MyDSL_DataLayer.lua, bug fixed, committed.
Layer 2 complete — three files live in Mudlet Script editor:
  - MyDSL_ThemeEngine.lua — theme defaults, overrides, color helpers
  - MyDSL_LayoutEngine.lua — percentage layout, persistence, resize handling
  - MyDSL_WindowRegistry.lua — 20 windows registered (18 original + RightHere + PlayersNear)
Layer 2 scripts are manually pasted into Mudlet Script editor (not via package).
MyDSL_Layer2.mpackage exists on disk but had XML format issues — manual paste is current method.
Layer 3 not started.

## Known Layer 2 Issues (fix before Layer 3)
1. sysWindowResizeEvent causes all windows to snap back to saved positions when user
   moves/docks a window. Fix: disable resize handler until Layer 3 wires up position-save
   callbacks. Workaround: run this in Lua console after each connect:
   if MyDSL.Layout._handlers.resize then killAnonymousEventHandler(MyDSL.Layout._handlers.resize) MyDSL.Layout._handlers.resize = nil end
2. setStyleSheet not available on UserWindow/Container — applyTheme() is currently a no-op.
   Theming deferred to Layer 3 when MiniConsole children are created inside windows.

## Windows Registered (20 total)
UserWindows: Chat, Affects, Portrait, RoomPicture, Live, Tick, Combat, Scan,
             Group, Target, CreatureReference, Mapper, Inventory, Equipment,
             RightHere, PlayersNear
Containers:  MoonWeather, AsciiMap, Banner, Bloodbath

## Layer 2 Load Order (Script editor, top to bottom)
1. MyDSL_ThemeEngine
2. MyDSL_LayoutEngine  
3. MyDSL_WindowRegistry
4. MyDSL_DataLayer

## Key Files on Disk (DSL2 profile directory)
- MyDSL_DataLayer.lua — Layer 1
- MyDSL_ThemeEngine.lua — Layer 2 file 1
- MyDSL_LayoutEngine.lua — Layer 2 file 2
- MyDSL_WindowRegistry.lua — Layer 2 file 3
- MyDSL_creaturelore.lua — creature DB (do not modify)
- MyDSL_layout.lua — saved window positions (auto-generated)
- MyDSL_windowstate.lua — saved window visibility (auto-generated)
- SESSION_START.md — this file
- DSL_UI_Philosophy.md — design principles

## DSL GMCP Branches
char_data, login_data, room_data, affect_data, add_affect, remove_affect, tick
No GMCP for: score, inventory, equipment, weather, lunar, who — text capture only.

## Git Log (run git log --oneline for current state)

## How To Continue (new Claude Code session)
1. Read SESSION_START.md
2. Read DSL_UI_Philosophy.md  
3. Run git log --oneline
4. Ask what the current task is

## Mudlet Reference URLs
- API functions: https://wiki.mudlet.org/w/Manual:Lua_Functions
- Event engine: https://wiki.mudlet.org/w/Manual:Event_Engine
- Best practices: https://wiki.mudlet.org/w/Manual:Best_Practices
