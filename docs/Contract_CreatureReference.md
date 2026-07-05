# Module Contract: MyDSL_CreatureReference.lua
**Layer 3 Phase B — Creature Lore Reference Display**
*Written 2026-07-02 — final pass verified against all project files*

---

## What This Module Is

CreatureReference displays creature lore data in `MyDSL_CreatureReference`.
It is populated when the player clicks `[CreatureLore]` in the Target window,
which sends `creaturelore <name>`. DataLayer captures the response, raises an
event, and this module renders the data.

It never sends commands. It only displays what DataLayer captured.

---

## Why This Window Matters

`creaturelore` output is long — race, alignment, wealth, HP, damage,
immunities, resists, vulns. It scrolls off the main console immediately
during combat. A persistent reference window means the player can glance
at it without losing it to combat text.

---

## Confirmed CreatureLore Output Format

From DSL1 XML parser (confirmed patterns):
```
Creature: a large Yeti    Race: Giant
They appear to be a good soul.
Their wealth appears to be 0 gold and 0 silver.
They appear to be Undetermined sex.
The base health of this creature is 1000.
[additional lore lines...]
```

Block starts: `^Creature:` line.
Block ends: blank line.

**Already in DataLayer (needs verification):**
The DSL1 XML has a full creaturelore parser. DataLayer.lua has stub
functions `beginCreatureLore`, `parseCreatureLoreLine`, `endCreatureLore`
but they may use the OLD format patterns from DSL1. Claude Code must:
1. Read the actual parser in DataLayer.lua
2. Verify patterns match actual game output (shown above)
3. Fix if wrong
4. Ensure `endCreatureLore()` calls `MyDSL.emit("creaturelore")` →
   raises `"MyDSL.creaturelore.updated"`
5. Wire triggers in Section 10 if missing

This is a DataLayer fix commit BEFORE the CreatureReference display module.

---

## Data Source

**Primary:** `MyDSL.State.creaturelore` — freshly parsed from current session
**Fallback:** `MyDSL_creaturelore.lua` — persistent DB loaded at startup

Confirmed in DSL2 module inventory:
- `MyDSL_creaturelore.lua` ✅ exists and loads
- Contains historically collected lore (Kien's known creatures)
- Has merge functions for combining new lore into the DB

**Key normalization:** `"a large Yeti"` → key `"large yeti"` (lowercase, strip articles)

**Creature record structure (from MyDSL_creaturelore.lua — confirmed):**
```lua
{
  name          = "a large Yeti",
  display       = "a large Yeti",
  key           = "large yeti",
  race          = "Giant",
  alignmentText = "good",           -- "a good soul" → "good"
  gold          = 0,
  silver        = 0,
  sex           = "Undetermined",
  hp            = 1000,
  level         = nil,              -- if parseable from lore
  damage        = nil,              -- damage noun/type
  immunities    = {},
  resists       = {},
  vulns         = {},
  affects       = {},
  roomsFound    = {
    ["The Hill-lands"] = 55,
    ["unknown room"]   = 20,
  },
  lastXP        = 3998,
  avgXP         = 2109,
  xpSamples     = 2,
  killCount     = 2,
  drops         = { ["silver coin"] = 34 },
  lored         = true,
  lastLore      = 0,                -- os.time() of last creaturelore
  rawLore       = {},               -- raw lines from last capture
  lastSeenAt    = 0,
  lastSeenRoomName = "unknown room",
  lastSeenArea  = "unknown area",
  lastSeenWhere = "right here",
  lastScanLocation = "right here",
  scan          = {                 -- from last scan that saw this creature
    raw   = "a large Yeti, right here.",
    name  = "a large Yeti",
    key   = "large yeti",
    where = "right here",
    count = 1,
  },
}
```

---

## Window: MyDSL_CreatureReference

**Type:** `Geyser.UserWindow` (already in WindowRegistry ✅, hidden by default)
**Layout position:** `x=0.66, y=0.73, w=0.34, h=0.27` (from LayoutEngine ✅)
**Content:** `Geyser.MiniConsole` inside at 100%×100%, scrollable
**Visibility:** Hidden by default. Auto-shows when lore data arrives.
Hidden again via `mydsl lore hide`.

### Display Layout

```
── a large Yeti ──────────────────────
Race: Giant            Align: good
HP: 1,000              Kills: 2
Avg XP: 2,109          Last XP: 3,998

Rooms seen:
  The Hill-lands (55)   unknown room (20)

Immunities: (none)
Resists:    (none)
Vulns:      (none)
Affects:    (none)

Drops: silver coin (34 kills)

Last lored: 2026-07-02
─────────────────────────────────────
```

**Color scheme:**
- Header/name: `#ffcc44` gold
- Field labels: `#888888` dim grey
- Field values: `#cccccc` near-white
- Room list: `#88aaff` blue
- Immunities: `#44ccaa` teal (information, not scary)
- Vulnerabilities: `#cc4444` red (useful to know)
- XP/drops: `#ffcc44` gold
- Footer separator: `#444444` dim

**No lore for this creature:**
```
── a large Yeti ──────────────────────
No lore data yet.
Click [CreatureLore] in Target window.
─────────────────────────────────────
```

---

## DataLayer Integration

Before building this module, Claude Code must fix the creaturelore
parser in DataLayer. The DSL1 parser used different output patterns.

**Step 1 — Verify/fix parser in DataLayer Section 9:**

`beginCreatureLore()` — fires on `^Creature:` line:
- Resets creaturelore block
- Captures name and race from: `^Creature:%s*(.-)%s+Race:%s*(.+)$`

`parseCreatureLoreLine(line)` — fires on each body line:
```lua
-- Alignment: "They appear to be a good soul."
local align = line:match("^.- appears to be (.+) soul%.")

-- Wealth: "Their wealth appears to be 5 gold and 10 silver."
local gold, silver = line:match(
  "^Their wealth appears to be%s+(%d+)%s+gold and%s+(%d+)%s+silver")

-- Sex: "They appear to be Male."
local sex = line:match("^They appear to be%s+(.+)%.")

-- HP: "The base health of this creature is 1000."
local hp = line:match("^The base health of this creature is%s+(%d+)%.")
```

`endCreatureLore()` — fires on blank line:
- Commits parsed data to State.creaturelore
- Merges into MyDSL_creaturelore.lua DB (using existing merge functions)
- Saves DB to disk
- Calls MyDSL.emit("creaturelore") → raises "MyDSL.creaturelore.updated"

**Step 2 — Wire triggers in Section 10 (if missing):**
```lua
MyDSL._triggers.loreStart = tempRegexTrigger(
  "^Creature:%s",
  function() MyDSL.beginCreatureLore(getCurrentLine()) end
)
-- body lines handled by catch-all installed in beginCreatureLore
```

**Commit these DataLayer fixes before building CreatureReference.**

---

## Event Subscriptions

```lua
registerAnonymousEventHandler("MyDSL.creaturelore.updated",
  function() MyDSL.CreatureReference.onLoreUpdate() end)
```

`onLoreUpdate()`:
1. Gets creature name from `MyDSL.State.creaturelore.name`
2. Looks up full record in `MyDSL_creaturelore.lua` DB (already merged by DataLayer)
3. Calls `render(name)` to display
4. Shows the window if hidden (`MyDSL.Windows.ensure("MyDSL_CreatureReference"):show()`)

---

## Public API

```lua
MyDSL.CreatureReference.init()           -- create window, register handlers
MyDSL.CreatureReference.render(name)     -- display lore for named creature
MyDSL.CreatureReference.show()           -- show window
MyDSL.CreatureReference.hide()           -- hide window
MyDSL.CreatureReference.onLoreUpdate()   -- handler for creaturelore.updated
MyDSL.CreatureReference._handlers = {}
```

---

## Aliases

```
mydsl lore <name>    → send("creaturelore " .. name) + show window
mydsl lore hide      → CreatureReference.hide()
mydsl lore show      → CreatureReference.show()
```

`mydsl lore <name>` is a player-initiated command shortcut, not automation.
Same effect as clicking `[CreatureLore]` in Target window.

---

## Relationship to MyDSL_creaturelore.lua

`MyDSL_creaturelore.lua` is the PERSISTENT DATA FILE — loaded at startup,
contains historically collected lore. It is NOT a display module.

CreatureReference (this module) is the DISPLAY WINDOW.
DataLayer owns PARSING.
MyDSL_creaturelore.lua owns PERSISTENCE.

When new lore arrives:
1. DataLayer parses it into State.creaturelore
2. DataLayer's endCreatureLore() merges into MyDSL_creaturelore.lua DB and saves
3. DataLayer raises "MyDSL.creaturelore.updated"
4. CreatureReference reads from the DB and renders

---

## init() Sequence

1. Kill old _handlers (safe reload)
2. Ensure MyDSL_CreatureReference UserWindow exists
3. Create MiniConsole inside at 100%×100%
4. Register MyDSL.creaturelore.updated handler
5. render() — shows empty/placeholder initially (window starts hidden)

---

## What This Module Does NOT Do

- Does not send `creaturelore` automatically
- Does not modify the creature DB directly
- Does not display live combat HP
- Does not interact with the combat system
- Does not parse lore lines (DataLayer owns parsing)
- Does not display inventory or equipment
- Does not show consider output (TargetView owns that)
