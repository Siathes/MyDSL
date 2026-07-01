# Module Contract: MyDSL_DataLayer.lua
**Layer 1 — Data Collection**
*Written from actual code. Version: 1.0. File: MyDSL_DataLayer.lua (960 lines)*

---

## What This Module Is

The single source of truth for all game state. It receives data from two input channels — GMCP packets (pushed automatically by the server) and text capture parsers (called by Mudlet triggers matching game output). It stores everything in a normalized Lua table (`MyDSL.State`) and broadcasts updates via a dual event bus. It never sends commands to the game and has no display logic.

---

## Public API

### State access
```lua
MyDSL.get(section)              -- returns entire section table
MyDSL.get(section, field)       -- returns one field value or nil
MyDSL.set(section, field, value)-- writes one field, emits event
MyDSL.Char()                    -- returns current character name or nil
```

### Event subscription
```lua
MyDSL.on(section, callback)     -- register direct Lua callback
-- Mudlet event form: register on "MyDSL.<section>.updated"
```

### Persistence
```lua
MyDSL.save()                    -- snapshot all State sections → disk
MyDSL.load()                    -- load save file at startup (called automatically)
MyDSL.restoreChar(name)         -- restore selected sections for named char (called by login handler)
```

### Text parser entry points (called by Mudlet triggers — see Section 9 below)
```lua
-- Block parsers (begin → parseLine × N → end):
MyDSL.beginScore(charName)   MyDSL.parseScoreLine(line)   MyDSL.endScore()
MyDSL.beginFlags()           MyDSL.parseFlagsLine(line)   MyDSL.endFlags()
MyDSL.beginLunar()           MyDSL.parseLunarLine(line)   MyDSL.endLunar()
MyDSL.beginWho()             MyDSL.parseWhoLine(line)     MyDSL.endWho()
MyDSL.beginWhok()            MyDSL.parseWhokLine(line)    MyDSL.endWhok()
MyDSL.beginWhoc()            MyDSL.parseWhocLine(line)    MyDSL.endWhoc()
MyDSL.beginGroup()           MyDSL.parseGroupLine(line)   MyDSL.endGroup()
MyDSL.beginInv()             MyDSL.parseInvLine(line)     MyDSL.endInv()
MyDSL.beginMap()             MyDSL.parseMapLine(line)     MyDSL.endMap()
MyDSL.beginAffectsText()     MyDSL.parseAffectsTextLine(line)  MyDSL.endAffectsText()
-- Single-line parsers:
MyDSL.parseTimeLine(line)
MyDSL.parseWeatherLine(line)
MyDSL.parseImproveLine(line)
MyDSL.parseUnreadLine(line)
```

---

## State Table — All Sections

Every section has `last_updated` (Unix timestamp). Zero means no data has arrived this session.

### GMCP-backed sections (server pushes automatically)

| Section | Source | Key fields |
|---|---|---|
| `char` | `gmcp.char_data` | hp, max_hp, mana, max_mana, move, max_move, str/int/wis/dex/con (with max_), gold, silver, tnl, wimpy, carry_weight, can_carry_weight, stance, language, is_flying, is_riding, is_fighting, is_afk, is_quiet |
| `login` | `gmcp.login_data` | name, level, kingdom, is_clan, is_kingdom, time |
| `room` | `gmcp.room_data` | name, sector, exits (array of strings) |
| `affects` | `gmcp.affect_data` / `add_affect` / `remove_affect` | active (table keyed by lowercase name, each entry: name, duration, modifier, location, type_raw) |
| `tick` | `gmcp.tick` | time (game time string from server) |

### Text-capture sections (populated by parsers called from triggers)

| Section | Command trigger | Key fields |
|---|---|---|
| `score` | `score` | name, level, race, class, years, sex, playedHours, reclassAt, stats{str,int,wis,dex,con + Base versions}, hitroll, damroll (+ Base), armor{Pierce,Bash,Slash,Magic}, hp, max_hp, mana, max_mana, move, max_move, gold, silver, bank, qpoints, practices, trains, xp, tnl, align, wimpy, position, stance, language, religion, profession, crafts{name→pct}, pkills, pkilled, raw (lines array) |
| `flags` | Inside `score` output | One boolean field per known flag: NoFollow, AutoAssist, AutoExit, AutoGold, AutoLoot, AutoSac, AutoSplit, NoBattle, NoPkLoot, NoTake, NoHeal, NoFly, NoSummon, NoLink, NoCancel, Compact, Prompt, Combine, AutoQuit, BeepTell, Ticks, TelnetGA, NoSurrender, NoToast |
| `lunar` | `lunar` / `l moons` | red{moon_name, phase, visibility, mana_bonus, saves_modifier, casting_modifier, regen_pct, cycles_remaining, hours_remaining, no_bonuses, next_phase, next_phase_cycles, next_phase_hours, next_phase_at}, white{same}, black{same} |
| `time` | Passive: "It is N o'clock" | hour, ampm, day_name, day_num, month |
| `weather` | Passive: weather lines | description (single string) |
| `who` | `who` / `whok` / `whoc` | players (array), kingdom_members (array), clan_members (array), count. Each player: level, class, wanted, afk, quiet, clan, kingdom, name, title |
| `group` | `group` | members (array), count. Each member: level, class, name, hp_pct, mana_pct, mv_pct, is_mob |
| `unread` | Passive: login notification | news, notes, ooc_notes, quest_notes, story_notes, bloodbath_notes |
| `inv` | `inv` / `inventory` | items (array), count. Each item: name, count, flags (array of strings) |
| `map` | `map` or passive | lines (array of strings), row_count |
| `improve` | Passive: skill improve lines | skill (name), percent (number) — **latest event only, no history** |

---

## Event Bus — How Consumers Receive Updates

Every call to `update()` (internal) triggers two things simultaneously:

**1. Mudlet event** (heard by any script, trigger, or timer):
```lua
raiseEvent("MyDSL.char.updated",    MyDSL.State.char)
raiseEvent("MyDSL.room.updated",    MyDSL.State.room)
-- pattern: "MyDSL.<section>.updated"
```

**2. Direct Lua callbacks** (heard by display modules that called `MyDSL.on()`):
```lua
MyDSL.on("char", function(state) ... end)  -- registered by display module
-- state = the section table at the moment of update
```

Both fire for every update. Display modules can use either, but `MyDSL.on()` is preferred — no string event name to mistype, no anonymous handler management.

---

## Persistence Model

**Save file:** `getMudletHomeDir() .. "/MyDSL_state.lua"`

**What gets saved:** All 16 sections per character, keyed by character name. `MyDSL.Data["Kien"]["score"]`, `MyDSL.Data["Olyndros"]["affects"]`, etc.

**When saved:** Automatically on `endScore()`, `endFlags()`, `endLunar()`, `affect_data`, `add_affect`, `remove_affect`. **Not** saved after every GMCP update (too frequent).

**What gets restored at login** (via `restoreChar()`):
- `score`, `lunar`, `flags`, `improve` — restored unconditionally
- `affects` — restored ONLY if `last_updated == 0` (no GMCP packet received yet this session)
- Everything else (char, login, room, who, group, inv, etc.) — NOT restored (GMCP will re-deliver quickly)

---

## GMCP Handler Safety

On every script load/reload, `deregisterHandlers()` runs first, killing all previously registered anonymous event handlers by ID. This prevents duplicate listeners accumulating across reloads — the DSL1 bug that caused double-processing.

---

## What This Module Does NOT Do

- Does not send any commands to the game
- Does not display anything
- Does not route any text
- Does not manage windows
- Does not parse combat lines, scan output, chat, or notifications
- Does not track equipment (no `eq` / `equipment` section — see Gap #1 below)
- Does not track scan output (no scan section — scan goes to routing layer)
- Does not track players near (no separate section — merged into `who`)
- Does not maintain improve history (only stores the most recent improvement)

---

## Gaps and Issues Found in Code

### Gap 1 — No equipment section ❌
`MyDSL.State.inv` tracks carried items. There is no `MyDSL.State.equip` section. The `score` parser extracts stats but not currently equipped items. The `eq` / `equipment` command output has no parser. **Action needed:** Add `equip` section and `beginEquip / parseEquipLine / endEquip` parser before Equipment window is built.

### Gap 2 — improve overwrites, no history ⚠️
`parseImproveLine()` always writes `{ skill=..., percent=... }` overwriting the previous value. If two skills improve in rapid succession, only the last is stored. **Decision needed:** Is a rolling improve log wanted, or is latest-only sufficient for the Improve display?

### Gap 3 — who parser assumes single-word kingdoms ⚠️
Comment in code: `"kingdom parsing assumes single-word kingdoms (Althainia, etc.)"`. If DSL has two-word kingdoms, the parser will assign the first word to `kingdom` and the second to `name`. **Action needed:** Run `who` in game and verify. Add to CommandRef.

### Gap 4 — restoreChar restores 4 of 16 sections ℹ️
`save()` saves all 16 sections. `restoreChar()` only restores 4. The others are intentionally left to GMCP re-delivery. This is correct behavior but should be explicitly documented in the spec so display modules don't expect stale-but-useful data to be present at login for sections like `room` or `group`.

### Gap 5 — map section never displayed ℹ️
`MyDSL.State.map` captures ASCII map lines. No display module reads it. This is either a future AsciiMap window data source, or dead. **Decision needed:** Keep as future Layer 3 target, or remove parser?

### Gap 6 — affects text fallback timing ⚠️
`endAffectsText()` only applies text affects if `last_updated == 0`. If the player types `affects` AFTER GMCP has already sent `affect_data`, the text output is silently discarded. This is correct by design (GMCP wins), but it means the text fallback is only useful at session start before the first GMCP packet. Document explicitly so it's not mistaken for a bug later.

### Gap 7 — score sections require CommandRef ⚠️
The score parser has specific patterns for every line. Until we verify these against actual DSL output (via CommandRef), any line format mismatch causes silent miss. Score parsing is the highest-risk parser. **Action needed:** Run `score` in game and paste output into CommandRef for pattern verification.

---

## Trigger Wiring Required (not in this file)

This module defines parser functions but does NOT install the triggers that call them. These triggers must exist in the Mudlet Trigger editor (or be installed by a routing module):

| Parser called | Trigger pattern needed |
|---|---|
| `beginScore` | `^Score for (\S+)` |
| `parseScoreLine` | (every line while score block active) |
| `endScore` | (blank line or known last line of score) |
| `beginFlags` | (flags section header inside score) |
| `parseTimeLine` | `^It is \d+ o'clock` |
| `parseWeatherLine` | (weather description patterns — needs CommandRef) |
| `parseImproveLine` | `Your knowledge of` or `getting better at` |
| `parseUnreadLine` | `You have \d+ news` |
| `beginLunar` | (lunar command header) |
| `beginWho` | (who header line) |
| `beginGroup` | (group header line) |
| `beginInv` | (inventory header line) |
| `beginMap` | (map header line) |
| `beginAffectsText` | `You are affected by` |

---

## Dependencies

**Requires nothing.** DataLayer has no dependencies on other MyDSL modules. It only uses Mudlet built-ins (`registerAnonymousEventHandler`, `raiseEvent`, `table.save/load`, `getMudletHomeDir`, `debugc`, `os.time`).

**Must load before** everything else. All Layer 2/3 modules depend on `MyDSL` being initialized.

---

## Contract Status

| Clause | Status |
|---|---|
| Never sends game commands | ✅ Verified in code |
| No display logic | ✅ Verified in code |
| Duplicate handler prevention | ✅ deregisterHandlers() present |
| Per-character data separation | ✅ MyDSL.Data[charName] structure |
| Event emission on every update | ✅ Both raiseEvent and direct callbacks |
| Safe reload (no data wipe) | ✅ All `or {}` guards in place |
| Equipment section | ❌ Missing — Gap #1 |
| Improve history | ⚠️ Decision needed — Gap #2 |
| Kingdom name parsing | ⚠️ Needs CommandRef verification — Gap #3 |
