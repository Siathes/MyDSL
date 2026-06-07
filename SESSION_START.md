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
Layer 1 complete but has one known bug (see below).
Clean profile DSL2 being set up — fresh start, no legacy baggage.
Layer 2 not started.

## Known Bug in MyDSL_DataLayer.lua (fix before wiring in)
The State initializer uses MyDSL.State = MyDSL.State or { char=..., login=..., ... }
If MyDSL.State already exists (set by another module first), the or {} guard skips
initialization, leaving sub-sections like login nil — causing crash at line 74.
Fix: replace the single or{} block with per-section guards:
  MyDSL.State = MyDSL.State or {}
  MyDSL.State.char    = MyDSL.State.char    or { last_updated = 0 }
  MyDSL.State.login   = MyDSL.State.login   or { last_updated = 0 }
  MyDSL.State.room    = MyDSL.State.room    or { last_updated = 0 }
  MyDSL.State.affects = MyDSL.State.affects or { last_updated = 0 }
  MyDSL.State.tick    = MyDSL.State.tick    or { last_updated = 0 }
  MyDSL.State.score   = MyDSL.State.score   or { last_updated = 0 }
  MyDSL.State.lunar   = MyDSL.State.lunar   or { last_updated = 0 }
  MyDSL.State.time    = MyDSL.State.time    or { last_updated = 0 }
  MyDSL.State.weather = MyDSL.State.weather or { last_updated = 0 }
  MyDSL.State.who     = MyDSL.State.who     or { last_updated = 0 }
  MyDSL.State.group   = MyDSL.State.group   or { last_updated = 0 }
  MyDSL.State.unread  = MyDSL.State.unread  or { last_updated = 0 }
  MyDSL.State.inv     = MyDSL.State.inv     or { last_updated = 0 }
  MyDSL.State.map     = MyDSL.State.map     or { last_updated = 0 }
  MyDSL.State.improve = MyDSL.State.improve or { last_updated = 0 }
  MyDSL.State.flags   = MyDSL.State.flags   or { last_updated = 0 }
Also fix MyDSL.Char() to be defensive:
  function MyDSL.Char()
    local login = MyDSL.State and MyDSL.State.login
    return login and login.name or nil
  end

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
