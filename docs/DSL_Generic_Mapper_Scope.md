# DSL Generic Mapper — Minimal Hardening Scope

**Purpose:** Keep the project aligned while building the DSL-specific fork of Generic Mapper.

This document is the controlling scope note for the current path. Do not drift into rebuilding Generic Mapper features unless DSL requires a specific hardening fix.

---

## Project Direction

Build **DSL Generic Mapper** as a conservative fork of the original Generic Mapper.

The mapper should remain Generic Mapper at its core. DSL-specific work should harden Generic Mapper for Dark and Shattered Lands rather than replacing Generic Mapper’s room engine, speedwalk, door system, routing, or repair tools.

---

## Core Architecture

```text
Generic Mapper:
  Owns room creation, linking, pathing, speedwalk, doors, special exits, save/load,
  repair tools, feature tools, and normal map UI.

DSL Hardening Layer:
  Teaches Generic Mapper about DSL movement failures, restricted exits, DSL room text,
  DSL GMCP room/exits/sector data, and repeated-room-name risks.

Audio Extension:
  Added only after the mapping core is stable. It should be separate from topology logic.
```

GMCP should assist Generic Mapper. GMCP should **not** become a separate mapper engine and should **not** directly create rooms except in a carefully controlled bootstrap/fallback case.

---

## Keep from Original Generic Mapper

Keep original Generic Mapper functionality intact unless there is a direct DSL conflict.

Required to keep:

- Original room creation
- Original room linking
- Original description matching
- Original pathing
- Original speedwalk
- Original auto-open door behavior
- Original door handling
- Original special exits
- Original save/load/import/export
- Original map UI commands
- Original repair/edit tools
- Original feature/room/area tools
- Original alias and trigger command surface, except updater commands should be disabled

Do not rewrite these systems unless testing proves a specific DSL compatibility problem.

---

## Disable from Original Generic Mapper

Disable anything that can overwrite or self-update the fork.

Required to disable:

- Generic Mapper updater
- Version polling
- Download/update aliases
- Any automatic call that can fetch, replace, or reinstall the upstream script

Preferred behavior:

```lua
cecho("\n<yellow>[DSL Generic Mapper]</yellow> Updater is disabled in the DSL fork.\n")
return false
```

---

## Required DSL Hardening

Only these DSL hardening items are in scope for the current stable core.

### 1. Description Matching Default ON

Generic Mapper’s description matching must be enabled by default because DSL has repeated room names.

Purpose:

- Prevent same-name rooms from merging incorrectly.
- Protect areas with repeated names like temples, roads, streets, halls, and maze-like zones.

### 2. DSL Movement-Fail / No-Move Patterns

Add DSL movement failure patterns so failed movement does not create false rooms or false links.

Known patterns:

```regex
^Alas, you cannot go that way\.$
^Alas, you and your mount cannot go that way\.$
^You aren't allowed in there\.$
^You are not allowed in there\.$
^No way!\s+You are still fighting!$
^You are too exhausted\.$
^You are carrying too much to go anywhere\.$
^Your mount can't swim!$
^Your mount can't fly!$
^You need a boat to go there\.$
```

Purpose:

- Cancel pending movement.
- Prevent false room creation.
- Prevent false link creation.
- Let Generic Mapper continue to handle normal mapping.

### 3. Restricted Exit Handling

DSL can show an exit in `[Exits:]` but reject character entry.

Example:

```text
[Exits: north south]
north
You aren't allowed in there.
```

Purpose:

- Treat this as failed movement.
- Do not create a destination room.
- Do not create a real mapped link.
- Let Generic Mapper keep visible exit information if appropriate, but topology must only change after actual movement succeeds.

### 4. DSL Door / Lock / No-Door Patterns

Use Generic Mapper’s existing door system. Do not create a custom DSL door automation system.

Add only the DSL text patterns needed to feed Generic’s existing door/fail logic.

Known patterns:

```regex
^The (.+) is closed\.$
^The .+ is locked\.$
^It's locked\.$
^You lack the key\.$
^I see no door .+ here\.$
^It's already open\.$
^It's already closed\.$
^It's already unlocked\.$
^It's not closed\.$
^Opened doors?: (.+)$
^\*Click\*$
```

Policy:

- Keep Generic auto-open door behavior for speedwalk.
- Do not build custom DSL auto-open/unlock logic.
- Door messages should protect mapping and feed Generic’s existing behavior.

### 5. DSL GMCP Assist

Capture DSL GMCP room data as helper context only.

Useful fields:

```lua
gmcp.room_data.room
gmcp.room_data.exits
gmcp.room_data.sector
gmcp.char_data.is_fighting
gmcp.char_data.is_riding
gmcp.char_data.is_flying
```

Immediate use:

- Room name sanity check
- Exits sanity check
- Sector/terrain metadata
- Debug/status visibility

Policy:

- GMCP should not replace Generic Mapper’s room resolver.
- GMCP should not create rooms directly during normal mapping.
- GMCP refreshes after failed movement must not create rooms or links.

### 6. DSL Room-Description Capture Hardening

Make sure Generic Mapper receives a clean DSL room description when resolving rooms.

DSL room shape:

```text
Room Name
  Description lines...

 [Exits: north east south ]
Seen mobs/items/objects...
```

Purpose:

- Ensure description matching works reliably.
- Avoid using login text, MOTD text, GMCP debug echoes, mapper output, or command output as room descriptions.

### 7. DSL Sector Metadata

Lightly store GMCP `sector` as room metadata after Generic Mapper resolves the room.

Purpose:

- Support terrain coloring/weighting later.
- Support audio ambience later.
- Do not build a large terrain editor now.

Known sectors include:

```text
inside
city
field
forest
hills
tundra
swim
underwater
desert
mountain
underground
unknown
```

### 8. Minimal Debug / Status

Keep only debugging commands that help test the fork.

Acceptable helpers:

```text
dslmap status
dslroom raw
```

Optional during testing:

```text
dslmap links
dslmap exits
```

These should not become a second mapper UI or duplicate Generic Mapper’s full repair system.

---

## Explicitly Out of Scope for Current Core

Do not add these until the Generic fork is stable:

- Custom standalone room resolver
- Custom movement engine
- Custom speedwalk engine
- Custom route modes
- Custom door automation
- Custom terrain editor
- Custom feature system
- Custom merge/split/delete system unless Generic lacks a needed test cleanup command
- Decorative block painter
- Candidate panel
- Large custom GUI panels
- Group markers
- Discord bridge
- Shared mapper sync
- Movement-cost learning
- Maze coin/item probe mode

These may be revisited later only after stable DSL Generic Mapper behavior is proven.

---

## Audio Extension Scope

Audio is desired, but only after core mapping is stable.

Audio should be an extension layer, not part of topology logic.

Wanted audio features later:

- Area music layer
- Room sound layer
- Room sounds over area music
- Combat mute using `gmcp.char_data.is_fighting`
- Fade in/out
- Area crossfade
- Loop fade handling
- Sound mute toggle
- Per-area/per-room/per-sector sound assignment

Do not let audio complicate room identity, movement, or mapping safety.

---

## Current Build Target

Next stable target should be:

```text
DSL Generic Mapper 0.2.0 — Minimal Hardening
```

Required properties:

- Original Generic Mapper retained
- Updater disabled
- Description matching enabled by default
- DSL fail patterns added
- DSL restricted-exit patterns added
- DSL door patterns fed into Generic’s door logic
- DSL GMCP assist added, but not direct room creation
- DSL sector stored lightly
- Generic auto-open door retained
- Minimal DSL debug/status commands only

---

## Testing Priorities

Test only stability-critical behavior first:

1. Generic Mapper still works normally.
2. `map show`, mapping start, room creation, pathing, save/load still work.
3. DSL failed movement does not create rooms.
4. DSL restricted exits do not create rooms.
5. Repeated same-name rooms are separated by description matching.
6. GMCP assist does not create rooms after failed movement.
7. Generic auto-open door behavior still works for speedwalk.
8. No updater can overwrite the fork.

---

## Guiding Rule

When in doubt:

```text
Use Generic Mapper’s existing feature.
Only add DSL code when Generic does not understand DSL’s text, GMCP, or failure behavior.
```
