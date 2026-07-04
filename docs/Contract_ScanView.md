# Module Contract: MyDSL_ScanView.lua
**Layer 3 Phase B — Scan Output Display**
*Written 2026-07-02 — final pass verified against all project files*

---

## What This Module Is

ScanView is a passive display module that captures `scan` command output,
parses it into structured data, and displays it in two windows:
- `MyDSL_Scan` — all mobs/players visible in connected rooms
- `MyDSL_RightHere` — only entities in the current room (clickable)

It never sends commands automatically. It only fires when the player
types `scan` manually. Stale data is acceptable and expected per the
Observer philosophy.

---

## Why These Windows Matter

During combat or exploration, knowing what is nearby and what is in the
room is critical. Scan shows the full picture. RightHere shows only what
can be immediately targeted. Together they feed the Target window.

---

## Confirmed Scan Output Formats

### Standard scan (all directions):
```
Looking around you see:
a large Yeti, right here.
a large Yeti, right here.
a large Yeti, nearby to the east.
a large Yeti, nearby to the south.
a large Yeti, nearby to the southeast.
```

### Directional scan:
```
You peer intently north.
a guard, right here.
The Sea Mage, nearby to the northwest sailing southeast.
```

### Nothing visible:
```
Looking around you see:
[blank line immediately]
```

### Confirmed location strings:
- `right here` — in current room
- `nearby to the [direction]` — adjacent room
- `not far to the [direction]` — two rooms away (needs live confirmation)
- `nearby to the northwest sailing southeast` — sailing variant (Icewall area)

### Multiple identical lines = multiple mobs:
```
a large Yeti, right here.
a large Yeti, right here.
```
= 2 Yetis. Count tracking required. Do NOT deduplicate.

### Block end conditions (confirmed from DSL1 XML):
The scan block ends when ANY of these appear:
1. Blank line — normal end
2. `^Players near you:$` — players near output immediately follows
3. `^.+%'s group:$` — group output immediately follows
4. New command prompt fires

The catch-all trigger must check for all three conditions.

---

## Mob vs Player Detection

DSL naming convention is 100% reliable:
- **Mobs** always start with an article: `a `, `an `, `the `, `The `
- **Players** always start with a capital proper noun: `Kien`, `Olyndros`

```lua
local function isMob(name)
  return name:match("^[Aa]n? ") ~= nil or name:match("^[Tt]he ") ~= nil
end
```

No database lookup needed. Applied at parse time to tag each entry.

---

## Data Stored

```lua
MyDSL.State.scan = {
  mode         = "around",    -- "around" or "direction"
  direction    = nil,         -- set if mode="direction"
  rows         = {},          -- all entries in order (may have duplicates)
  rightHere    = {},          -- only "right here" entries, keyed by normalized name
  byName       = {},          -- aggregated entries keyed by normalized name (count tracked)
  last_updated = 0,           -- os.time() when block ended
}

-- Each row entry:
{
  raw      = "a large Yeti, right here.",
  name     = "a large Yeti",
  display  = "a large Yeti",
  key      = "large yeti",      -- lowercase, articles stripped
  where    = "right here",      -- or "nearby to the east" etc.
  is_mob   = true,
  count    = 2,                 -- aggregate count in byName; individual rows always 1
}
```

---

## DataLayer Integration

ScanView adds scan triggers to DataLayer Section 10. Same pattern as score
and lunar triggers — confirmed working pattern.

**Trigger 1 — Scan start (two patterns):**
```lua
MyDSL._triggers.scanStart = tempRegexTrigger(
  "^Looking around you see:$",
  function() MyDSL.beginScan("around", nil) end
)
MyDSL._triggers.scanDir = tempRegexTrigger(
  "^You peer intently (%a+)%.$",
  function() MyDSL.beginScan("direction", matches[2]) end
)
```

**beginScan(mode, direction):**
- Resets State.scan to empty
- Sets mode and direction
- Installs catch-all trigger for body lines (same pattern as beginScore/beginLunar)
- Stores catch-all ID in MyDSL._triggers.scanBody

**Catch-all trigger (installed by beginScan):**
Fires on every subsequent line. Inside the handler:
```lua
local line = getCurrentLine()
local t = trim(line)
-- End conditions:
if t == "" then MyDSL.endScan(); return end
if t == "Players near you:" then MyDSL.endScan(); return end
if t:match("^.+%'s group:$") then MyDSL.endScan(); return end
if t == "Looking around you see:" then return end  -- skip header if re-seen
-- Parse the mob/player line:
MyDSL.parseScanLine(line)
```

**endScan():**
- Kills catch-all trigger (killTrigger on MyDSL._triggers.scanBody)
- Sets State.scan.last_updated = os.time()
- Calls MyDSL.emit("scan") → raises "MyDSL.scan.updated"

**parseScanLine(line):**
```lua
-- Patterns (in order of attempt):
local name, where
name = line:match("^(.+),%s+right here%.?$")
if name then where = "right here" end
if not name then
  name, where = line:match("^(.+),%s+(nearby to .+)%.?$")
end
if not name then
  name, where = line:match("^(.+),%s+(not far .+)%.?$")
end
if not name then return end  -- unrecognized line, skip silently

name = trim(name)
local key = name:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
local is_mob = isMob(name)
local row = { raw=line, name=name, display=name, key=key,
              where=where, is_mob=is_mob, count=1 }

table.insert(State.scan.rows, row)

-- Aggregate into byName (count duplicates):
if State.scan.byName[key] then
  State.scan.byName[key].count = State.scan.byName[key].count + 1
else
  State.scan.byName[key] = { raw=line, name=name, display=name, key=key,
                              where=where, is_mob=is_mob, count=1 }
end

-- RightHere: only current room entries — own independent counter, not a reference
-- to byName[key] (which counts across all directions and would inflate the total).
if where == "right here" then
  if State.scan.rightHere[key] then
    State.scan.rightHere[key].count = State.scan.rightHere[key].count + 1
  else
    State.scan.rightHere[key] = { raw=line, name=name, display=name, key=key,
                                   where=where, is_mob=is_mob, count=1 }
  end
end
```

**NOTE:** These functions (beginScan, parseScanLine, endScan) belong in
MyDSL_DataLayer.lua Section 9. The tempRegexTrigger wiring belongs in
Section 10. Claude Code must add BOTH in separate commits.

---

## Window: MyDSL_Scan

**Type:** `Geyser.UserWindow` (already in WindowRegistry ✅)
**Layout position:** `x=0.34, y=0.60, w=0.32, h=0.22` (from LayoutEngine ✅)
**Content:** `Geyser.MiniConsole` inside at 100%×100%, scrollable

**Display format:**
```
[Right Here]
  a large Yeti (×2)
  Kien

[Nearby]
  a large Yeti → east
  a large Yeti → south
  a large Yeti → southeast
```

**Color scheme:**
- Section headers: `#888888` dim grey
- Right here mobs: `#cc4444` red
- Right here players: `#88aaff` blue
- Nearby mobs: `#886644` dim orange
- Nearby players: `#6688cc` dim blue
- Direction `→`: `#444444` dim
- Count `(×2)`: `#ffcc44` gold

Cleared and rewritten on every scan. No persistent history.

If scan returned nothing:
```
[Empty scan]
```

**Gag toggle:**
- Default: OFF (scan output visible in main console)
- `mydsl scan gag` → gag enabled
- `mydsl scan ungag` → gag disabled
- When enabled: deleteLine() on header and each body line

---

## Window: MyDSL_RightHere

**Type:** `Geyser.UserWindow` (already in WindowRegistry ✅)
**Layout position:** `x=0.00, y=0.60, w=0.18, h=0.22` (from LayoutEngine ✅)
**Content:** `Geyser.MiniConsole` inside at 100%×100%

**Display format — compact clickable list:**
```
Right Here:
  a large Yeti ×2
  Kien
```

Each name rendered as a clickable `cechoLink`:
```lua
cechoLink(
  winName,
  string.format("<mob_color>%s%s\n", display, count_str),
  string.format([[MyDSL.Target.set("%s", %s, "righthereclick")]], display, tostring(is_mob)),
  "Click to target: " .. display,
  false
)
```

Color by type:
- Mobs: `#cc8844` warm orange
- Players: `#88aaff` blue
- Count suffix: `#ffcc44` gold ` ×2`

Cleared and rewritten on every `MyDSL.scan.updated` event.

If rightHere is empty:
```
Right Here: (empty)
```

---

## Public API

```lua
MyDSL.ScanView              -- module table
MyDSL.ScanView.init()       -- create windows, register handlers, wire gag triggers
MyDSL.ScanView.render()     -- redraw both Scan and RightHere
MyDSL.ScanView.renderScan() -- redraw MyDSL_Scan only
MyDSL.ScanView.renderRightHere()  -- redraw MyDSL_RightHere only
MyDSL.ScanView.setGag(bool) -- toggle gag triggers
MyDSL.ScanView.config = {
  gagScan = false,
}
MyDSL.ScanView._handlers = {}  -- event handler IDs for clean reload
MyDSL.ScanView._triggers = {}  -- gag trigger IDs for clean reload
```

---

## Event Subscriptions

```lua
registerAnonymousEventHandler("MyDSL.scan.updated",
  function() MyDSL.ScanView.render() end)
```

---

## Aliases

```
mydsl scan gag      → MyDSL.ScanView.setGag(true)
mydsl scan ungag    → MyDSL.ScanView.setGag(false)
```

---

## init() Sequence

1. Kill old _handlers and _triggers (safe reload)
2. Ensure MyDSL_Scan UserWindow exists (MyDSL.Windows.ensure)
3. Create MiniConsole inside MyDSL_Scan at 100%×100%
4. Ensure MyDSL_RightHere UserWindow exists
5. Create MiniConsole inside MyDSL_RightHere at 100%×100%
6. Register MyDSL.scan.updated handler
7. Register gag triggers if config.gagScan
8. Call render() — shows empty state initially

---

## What This Module Does NOT Do

- Does not send `scan` automatically
- Does not auto-refresh on room change
- Does not modify DataLayer state directly
- Does not write to Target window
- Does not capture `consider` output
- Does not maintain scan history between commands
- Does not parse players-near output (separate window, separate module)
