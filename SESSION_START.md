# DSL UI Project — Session Context

## Project
Building a modular 4-layer Observer UI for Dark and Shattered Lands (DSL) on Mudlet 4.20.1.
Player: Vzon master account. Main build character: Kien (W-Elf Druid 51).
Screen resolution: 1920x1080.

## Profile Directories
- OLD profile (DSL1): /home/owner/Desktop/Mudlet/mudlet-data/profiles/DSL1
- NEW profile (DSL2): /home/owner/Desktop/Mudlet/mudlet-data/profiles/DSL2
- Git repo: currently in DSL1 — will be moved to DSL2
- All new work happens in DSL2. DSL1 is reference only.

## Architecture — 4 Layers
1. Data Layer (COMPLETE, needs fix) — MyDSL_DataLayer.lua — passive collector, no display
2. Window Layer (NEXT) — manages window positions, sizes, themes, settings
3. UI Layer — fills windows with data, handles interaction
4. Reference Layer — item/mob/location database, pop-up library

## Design Philosophy
See DSL_UI_Philosophy.md — The Observer UI.
Short version: move text, don't replace it. Main console is sacred.
Passive observation only. Automate to assist, not to play.
Every module optional and toggleable. Stale data beats spam.

## Current State
Layer 1 complete — MyDSL_DataLayer.lua, bug fixed, committed.
Layer 2 complete — three files committed:
  - MyDSL_ThemeEngine.lua (4fd497d) — theme defaults, overrides, color helpers
  - MyDSL_LayoutEngine.lua — percentage layout, persistence, resize handling
  - MyDSL_WindowRegistry.lua (f118faa) — 18 windows, toggle/show/hide, state persistence
Layer 2 files are NOT yet wired into Mudlet (no script entries in autosave.xml).
Next task: wire Layer 2 into Mudlet load order via the Script editor, then test.
Layer 3 not started.

## Why DSL2 (clean profile)
DSL1 accumulated: 60+ dead audit-phase scripts, duplicate GMCP handlers,
duplicate aliases firing twice, load-order collisions. Fixing in place
risks more collisions. Clean profile solves all three gaps simultaneously.

## What Carries Over from DSL1 to DSL2
- MyDSL_DataLayer.lua (with bug fixed before wiring in)
- MyDSL_creaturelore.lua (do not break — creature DB)
- MyDSL/ data directory (portraits, roompics, saved state)
- Map file (map data worth keeping)
- EMCO/EMCOChat (reinstall from package manager)
- Generic mapper package (reinstall from package manager)
- All .md reference files

## What Gets LEFT BEHIND in DSL1
- SourceCore and entire v4C stack (being replaced by new layer system)
- All Phase 2-15 audit scripts
- Duplicate aliases and dead triggers
- AdjustableContainer standalone package (now built into Mudlet 4.20+)

## Window Architecture Decision
- Geyser.UserWindow — for windows that can detach to second monitor
- Adjustable.Container — for windows that stay inside main console
- Hybrid approach — user chooses per window
- All existing windows in DSL1 are already Geyser.UserWindow
- Layer 2 wraps existing windows, does not rebuild them

## Key Files
- MyDSL_DataLayer.lua — Layer 1, 959 lines, needs bug fix before use
- DSL_UI_Philosophy.md — design principles
- MyDSL_Audit.md — complete audit of DSL1 (reference for what existed)
- MyDSL_PNP_Reference.md — PNP package API reference for Layer 2
- MyDSL_creaturelore.lua — existing creature DB (do not break)

## Mudlet Reference URLs
- Manual: https://wiki.mudlet.org/w/Manual:Mudlet_Manual
- API functions: https://wiki.mudlet.org/w/Manual:Lua_Functions
- Best practices: https://wiki.mudlet.org/w/Manual:Best_Practices
- Event engine: https://wiki.mudlet.org/w/Manual:Event_Engine
- Lua 5.1 reference: https://www.lua.org/manual/5.1/

## DSL GMCP Branches (what the server sends)
char_data, login_data, room_data, affect_data, add_affect, remove_affect, tick
No GMCP for: score, inventory, equipment, weather, lunar, who — text capture only.

## Git Log (DSL2 repo)
e6af3d1 — DSL2 clean profile — carry-over files from DSL1 with DataLayer bug fix

## How To Continue (new session)
1. Read this file
2. Read DSL_UI_Philosophy.md
3. Confirm which profile directory you are working in
4. Run git log --oneline to see current state
5. Ask what the current task is
