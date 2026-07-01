# Module Contract: MyDSL_AffectsView.lua
**Layer 3 — Active Affects Display**
*Written from actual code. Version: v4C16 QuietBoot. File: MyDSL_AffectsView.lua (1073 lines)*

---

## What This Module Is

AffectsView displays the player's active spell effects, tracks a watched list of
desired spells, highlights missing spells, and provides manual recast tools.

It is GMCP-first — reads from `gmcp.affect_data.affects` on every server response.
Text capture from the `affects` command is a secondary fallback. All game commands
sent by this module are user-initiated (click or explicit alias). No automation.

**This is the most architecturally complete Phase A module.** Its handler
management pattern (`registerHandlerOnce`) is the template all other modules
should follow. Its per-character profile system is already correctly implemented.

---

## Namespace

```lua
MyDSL.Affects           -- the module
MyDSL.Affects.config    -- display and behavior settings
MyDSL.Affects.state     -- runtime state (source, capture, lastSync)
MyDSL.Affects.list      -- current active affects (keyed by lowercase name)
MyDSL.Affects.tracked   -- spells the player wants to monitor
MyDSL.Affects.customCommands -- per-spell custom cast commands
```

---

## Data Model

### `A.list` (active affects)
```lua
A.list["detect invis"] = {
  name     = "detect invis",
  duration = 52,           -- cycles remaining (from GMCP field 'd')
  source   = "gmcp",
  updated  = 1718000000,   -- os.time() when last updated
  mods     = {
    { lc="none", m=0, t=0 }  -- abbreviated GMCP fields preserved
  },
}
```

### `A.tracked`
```lua
A.tracked = {
  ["armor"]        = true,
  ["detect invis"] = true,
  -- etc.
}
```
Populated manually by player via `mydsl affects track <name>`.
Empty by default on new characters. Loaded from per-character profile.

---

## GMCP Field Handling — CONFIRMED CORRECT

`A.gmcpEntryToAffect(entry, source)` handles DSL's abbreviated GMCP fields:

```lua
local name = entry.n or entry.name    -- "detect invis"
A.add(name, entry.d, source, {        -- entry.d = 52 (cycles)
  lc = entry.lc,                       -- "none" or "armor class"
  m  = entry.m,                        -- 0 or -20
  t  = entry.t,                        -- type integer
})
```

Confirmed GMCP format (from in-game capture):
```lua
{ n="detect invis", d=52, lc="none", m=0, t=0 }
{ n="armor",        d=23, lc="armor class", m=-20, t=0 }
```

Both abbreviated fields (`n`, `d`, `lc`, `m`, `t`) and full names (`name`,
`duration`, `location`, `modifier`) are handled. Robust against GMCP schema changes.

---

## Text Capture (Secondary Fallback)

Captures output from the `affects` game command when GMCP is unavailable or
for initial sync. Patterns confirmed against actual DSL output:

| Trigger pattern | What it matches |
|---|---|
| `^You are affected by the following spells:$` | Start of affects block |
| `^Spell:\s+(.+?)\s+:\s+modifies\s+(.+?)\s+by\s+(-?\d+)\s+for\s+(-?\d+)\s+cycles.*$` | Individual spell line |
| `^Song\s*:\s+...` | Song effects (same format as Spell) |
| `^You are not affected by any spells\.$` | Empty affects list |
| `^\s*$` | Blank line terminates capture |

Confirmed actual output: `"Spell: detect hidden     : modifies none by 0 for 32 cycles, (16 hours)"` ✅ matches.

Triggers use `tempRegexTrigger` (session-only, not in editor). Old triggers are
killed before new ones registered (`A.ids.triggers` table). Acceptable exception
to the editor-visible trigger policy since this is a secondary text fallback.

---

## Per-Character Profile System — ALREADY IMPLEMENTED ✅

```
getMudletHomeDir()/MyDSL/affects/<CharacterName>.lua
```

Saves: `tracked`, `customCommands`, `config` (font, columns, wrap, timerMode).
Loaded via `A.loadProfileForCurrentChar()` on login and character switch.

`A.onCharacterChanged()` fires on `gmcp.login_data` and `gmcp.char_data` events
to detect character switches and reload the correct profile. This is the correct
character-binding pattern.

---

## Handler Management — THE CORRECT PATTERN ✅

`A.registerHandlerOnce(key, eventName, funcName)` kills the old handler if it
exists, then registers the new one. Store the handler ID under `A.handlers[key]`:

```lua
function A.registerHandlerOnce(key, eventName, funcName)
  if A.handlers and A.handlers[key] then
    pcall(killAnonymousEventHandler, A.handlers[key])
  end
  A.handlers = A.handlers or {}
  A.handlers[key] = registerAnonymousEventHandler(eventName, funcName)
end
```

**This is the template all other modules should adopt.** TickSource, TickView,
and ChatWrapper should be updated to use this pattern instead of the
`handlersInstalled` flag approach.

---

## Events Listened To

```lua
"gmcp.login_data"        → onCharacterChanged() — load correct profile
"gmcp.char_data"         → onCharacterChanged() — detect character switch
"gmcp.affect_data"       → onGmcpEvent() — full affect sync
"gmcp.affect_data.affects" → onGmcpEvent() — full affect sync (alt event)
"gmcp.add_affect"        → onGmcpEvent() → gmcpAdd() — single affect added
"gmcp.remove_affect"     → onGmcpEvent() → gmcpRemove() — single affect removed
"add_affect"             → onGmcpEvent() — legacy event name variant
"remove_affect"          → onGmcpEvent() — legacy event name variant
"MyDSL.Timers.Updated"  → onTimersUpdated() — ⚠️ wrong name, see Gap 1
"sysExitEvent"           → save() — persist on disconnect
"sysDisconnectionEvent"  → save() — persist on disconnect
```

---

## Display Features

Two-column layout (configurable). Each active affect shows:
- Spell name (truncated to `columnWidth`)
- Duration countdown: either `"Ncyc"` or `"Nh"` depending on `timerMode`
- Low cycle warning: red highlight when `d <= lowCycles` (default: 5 cycles)
- Click link to recast (sends `castCommand 'spellname'`)

Below active affects:
- Separator line
- `"N active / N tracked / N missing"` summary
- Missing spells list (tracked but not active) in wrap-around format

---

## Manual Interaction Features

All game commands are user-initiated only. No automatic behavior.

```lua
A.refresh()              -- sends "affects" to game (triggers GMCP sync)
A.recast(name)           -- sends cast command for one spell
A.respell(list)          -- casts all missing tracked spells matching list
A.spellup(list)          -- casts all tracked spells (present or missing)
A.commandFor(name)       -- returns custom command or default cast command
A.setCommand(name, cmd)  -- set per-spell custom cast command (pipe-separated)
```

---

## Public Configuration API

```lua
A.track(name)           -- add spell to tracked list
A.untrack(name)         -- remove from tracked list
A.clearTracked()        -- empty the tracked list
A.setFont(size)         -- change display font
A.setColumns(n)         -- 1 or 2 column layout
A.setColumnWidth(n)     -- characters per column
A.setWrap(width)        -- missing spells wrap width
A.setTimerMode(mode)    -- "cycles" or "hours"
```

---

## Philosophy Compliance

| Action | Trigger | Philosophy |
|---|---|---|
| Display affects | GMCP events | ✅ Passive |
| Update countdown | Timer events | ✅ Passive |
| Send `affects` command | `mydsl affects refresh` alias ONLY | ✅ Manual |
| Send cast command | Click link or `mydsl affects cast` ONLY | ✅ Manual |
| Send respell/spellup | `mydsl affects respell/spellup` ONLY | ✅ Manual |

No automatic recasting. No automatic command sending.

---

## Dependencies

**Reads from:** `gmcp.affect_data.affects`, `gmcp.add_affect`, `gmcp.remove_affect`
**Listens to:** GMCP events + `MyDSL.Timers.Updated` (broken — see Gap 1)
**Writes to:** `MyDSL_Affects` UserWindow via `cecho(windowName, text)`
**Saves to:** Per-character profile file
**Must load after:** WindowRegistry

---

## Gaps and Issues Found in Code

### Gap 1 — Wrong timer event name ❌
AffectsView listens to `"MyDSL.Timers.Updated"` for live countdown updates.
TickSource raises `"MyDSL.Timers.Pulse"` (not `Updated`). The `onTimersUpdated()`
function never fires. Affect durations only decrement when GMCP fires (on each
server response), not in real-time.

For practical use this is acceptable — DSL sends GMCP after every action, so
durations update frequently. But the "live countdown" feature doesn't work as
designed between actions.

**Fix:** Either:
- Change AffectsView to listen to `"MyDSL.Timers.Pulse"`
- Change TickSource to also raise `"MyDSL.Timers.Updated"`

Recommendation: TickSource should raise both `Pulse` and `Updated` for
forward-compatibility. Then both AffectsView and TickView receive it.

### Gap 2 — Hardcoded colors, no ThemeEngine ⚠️
Display colors hardcoded:
- Active spells: `<cyan>`, `<white>`, `<orange>` (low cycles)
- Missing spells: `<DarkSlateGrey>`, `<red>`
- Summary line: `<grey>`

Should pull from ThemeEngine: `warnColor` for low cycles, `dimColor` for
missing, `textColor` for active. No ThemeEngine refresh callback registered.

### Gap 3 — Fallback window position wrong ⚠️
If WindowRegistry unavailable:
```lua
Geyser.UserWindow:new({ x="70%", y="35%", width="30%", height="25%" })
```
Confirmed layout has Affects in the right column at x=0.78, y=0.72, w=0.22, h=0.07.
Width (30% vs 22%) and position are both wrong.

**Fix:**
```lua
{ x="78%", y="72%", width="22%", height="7%" }
```

### Gap 4 — Legacy `MyCore.state.gmcp` reference ℹ️
`A.getGmcpRoot()` checks `MyCore.state.gmcp` before checking `gmcp`. `MyCore`
was a previous namespace from DSL1 that no longer exists in DSL2. The check
is harmless (fails silently) but adds confusion.

**Fix:** Remove the `MyCore` candidate from `getGmcpRoot()`. Use only `gmcp`.

### Gap 5 — Display uses old string-based cecho ℹ️
`wcecho()` calls `cecho(A.config.windowName, text)` using the window name string.
This is the Mudlet old-style API. Functional but inconsistent with the approach
of using Geyser object methods.

No action required — it works and there's no behavioral difference.

---

## Contract Status

| Clause | Status |
|---|---|
| No automatic game commands | ✅ All sends are user-initiated |
| GMCP-first data source | ✅ |
| GMCP abbreviated fields handled correctly | ✅ `n/d/lc/m/t` |
| Text capture patterns match confirmed output | ✅ |
| Per-character profile (already implemented) | ✅ |
| registerHandlerOnce pattern (template for others) | ✅ |
| onCharacterChanged() for character switching | ✅ |
| Save on exit/disconnect | ✅ |
| Live countdown via timer event | ❌ Wrong event name — Gap 1 |
| ThemeEngine color integration | ❌ Hardcoded — Gap 2 |
| Fallback window position correct | ❌ Wrong — Gap 3 |
| Legacy MyCore reference removed | ⚠️ Cleanup — Gap 4 |
EOF