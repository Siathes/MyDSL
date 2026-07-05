# Mudlet API Reference — Part 2
*Borders · Database · Strings · Dynamic Triggers · EMCO Internals · createBuffer*

---

## 15. BORDER MANAGEMENT — Protecting the Sacred Main Console

### The Core Concept

The Mudlet main console (where game text flows) is NOT a Geyser object. It's the underlying terminal. You carve space away from it using **border functions**, which tell Mudlet "leave this many pixels on each side free for the game text." Everything outside those borders is where your UI panels go.

```
┌─────────────────────────────────────────┐
│  setBorderTop(100)   ← top panel space  │
├──────────┬──────────────────┬───────────┤
│setBorder │                  │ setBorder │
│Left(300) │   MAIN CONSOLE   │ Right(350)│
│          │   (sacred)       │           │
├──────────┴──────────────────┴───────────┤
│  setBorderBottom(80)  ← bottom bar      │
└─────────────────────────────────────────┘
```

### The Functions

```lua
-- Set border sizes (pixels):
setBorderLeft(300)
setBorderRight(350)
setBorderTop(100)
setBorderBottom(80)

-- Set all at once:
setBorderSizes(top, right, bottom, left)
setBorderSizes(100, 350, 80, 300)

-- Get current sizes:
getBorderLeft()      -- returns pixel count
getBorderRight()
getBorderTop()
getBorderBottom()
getBorderSizes()     -- returns: {top=100, right=350, bottom=80, left=300}

-- Get the total usable window size:
local width, height = getMainWindowSize()
-- Returns pixel dimensions of the FULL Mudlet window
-- (including the border areas — not just the main console area)
```

### The Resize Event

When the user resizes the Mudlet window, this event fires:

```lua
registerAnonymousEventHandler("sysWindowResizeEvent", function(event, newW, newH)
  -- newW, newH are the new full window dimensions
  MyDSL.Layout.onResize(newW, newH)
end)
```

**Critical pattern — prevent infinite loops:**
`setBorder*()` used to re-fire `sysWindowResizeEvent`, which could cause infinite loops. Modern Mudlet (4.16+) has this fixed, but the safe pattern is still to check if the size actually changed:

```lua
local _lastW, _lastH = 0, 0

function MyDSL.Layout.onResize(w, h)
  if w == _lastW and h == _lastH then return end  -- no change, skip
  _lastW, _lastH = w, h
  
  -- recalculate borders based on new size:
  setBorderLeft(math.floor(w * 0.22))
  setBorderRight(math.floor(w * 0.22))
  setBorderTop(math.floor(h * 0.08))
  setBorderBottom(40)
  
  -- Geyser containers will auto-reposition (that's their job)
end
```

### How Geyser Panels and Borders Work Together

The standard pattern for our Observer UI:

```lua
-- 1. Set border to reserve space:
setBorderLeft(300)

-- 2. Create a Geyser container that fills that exact border space:
local leftPanel = Geyser.Container:new({
  name  = "LeftPanel",
  x = 0, y = 0,
  width = 300, height = "100%",
})

-- 3. All children go into leftPanel, they position relative to it.
-- The main console never overlaps because setBorderLeft(300) pushed it right.
```

**For UserWindows:** UserWindows float freely and don't need borders — they sit ON TOP of or BESIDE the main console. Only use borders when you want a permanently anchored panel that the main console text wraps around.

### Resolved: the resize handler this used to require has been removed

**Corrected 2026-07-05 — this section previously described the workaround
below as an ongoing, current-session necessity with removal framed as a
future task. That's stale.** The `sysWindowResizeEvent` handler was
removed entirely back on 2026-06-25 (see CHANGELOG), not deferred:

> Docking a UserWindow fires resize events that snap all windows back to
> LayoutEngine defaults — the resize handler itself was the problem, not
> something still needed. Layout is now saved manually via `mydsl layout
> save` instead of reacting to resize events at all.

`WindowRegistry.lua`/`LayoutEngine.lua` already implement the
`applyBorders()` + manual-save pattern this section originally said was
still owed ("When Layer 3 wires proper position-save callbacks, we
replace this..."). That replacement already happened. There is no
lingering resize-handler workaround to retire — don't reintroduce one.

---

## 16. DATABASE FUNCTIONS — Persistent Structured Storage

### When to Use db: vs. table.save()

| Use `table.save()` | Use `db:` |
|---------------------|-----------|
| Simple key/value config | Queryable data (search, filter, sort) |
| Session state, positions | Journal entries, item database |
| Small tables (<100 rows) | Large collections (hundreds of items) |
| Fire-and-forget save | Need to find/update specific records |

`db:` uses SQLite under the hood. The file is stored in the profile directory as a `.db` file.

### Core Vocabulary

- **Database** = a named `.db` file (like `"journal"` or `"items"`)
- **Sheet** = a table within that database (like `"entries"` or `"creatures"`)
- **Row** = one record in a sheet
- **Field** = one column in a sheet

### Creating a Database

```lua
-- db:create is SAFE to call every time (it's idempotent — if the db/columns
-- already exist, it does nothing; if they don't, it creates them):
local journalDB = db:create("journal", {
  entries = {
    date      = "",     -- field name = default value (type is inferred)
    title     = "",
    body      = "",
    char      = "",     -- which character wrote it
    in_game_day = 0,
    _index    = { "char", "in_game_day" },  -- for faster searching
    _unique   = { "date", "char" },          -- no duplicate date+char combos
    _violations = "IGNORE",                  -- on violation: ignore silently
  }
})

-- IMPORTANT: call db:create at the TOP LEVEL of a script (not inside a function).
-- It's designed to run on script load every time. Safe and recommended.
```

### Getting a Reference

```lua
-- After db:create, OR to get a reference in another script:
local mydb = db:get_database("journal")
-- mydb.entries is the sheet reference you pass to all other db: functions
```

### Adding Records

```lua
local mydb = db:get_database("journal")

-- Add one record:
db:add(mydb.entries, {
  date        = os.date("%Y-%m-%d %H:%M"),
  title       = "First Moon Ritual",
  body        = "Performed the cliath rite under the silver moon...",
  char        = "Kien",
  in_game_day = 42,
})

-- Add multiple records at once:
db:add(mydb.entries,
  { date="...", title="...", char="Kien", in_game_day=43 },
  { date="...", title="...", char="Olyndros", in_game_day=43 }
)

-- db:merge_unique: safer add (updates instead of erroring on unique violation):
db:merge_unique(mydb.entries, {
  { date="2024-06-01", char="Kien", title="Updated entry", body="..." }
})
```

### Fetching Records

```lua
local mydb = db:get_database("journal")

-- Fetch ALL entries:
local all = db:fetch(mydb.entries)
-- Returns: { {id=1, date="...", title="...", ...}, {id=2, ...}, ... }

-- Fetch with a filter:
local kienEntries = db:fetch(mydb.entries, 
  db:eq(mydb.entries.char, "Kien")
)

-- Multiple conditions (AND):
local recent = db:fetch(mydb.entries, {
  db:eq(mydb.entries.char, "Kien"),
  db:gte(mydb.entries.in_game_day, 40),
})
-- {condition1, condition2} in a table = implicit AND

-- OR condition:
local either = db:fetch(mydb.entries,
  db:OR(
    db:eq(mydb.entries.char, "Kien"),
    db:eq(mydb.entries.char, "Olyndros")
  )
)

-- Pattern matching (SQL LIKE):
local moonEntries = db:fetch(mydb.entries,
  db:like(mydb.entries.title, "%Moon%")
)
-- % = wildcard (any characters)

-- Sorted results:
local sorted = db:fetch(mydb.entries, nil, {mydb.entries.in_game_day}, true)
-- nil = no filter (all rows), sort by in_game_day, true = descending
```

### Query Expressions Reference

```lua
db:eq(field, value)          -- field == value
db:not_eq(field, value)      -- field != value
db:gt(field, value)          -- field > value
db:gte(field, value)         -- field >= value
db:lt(field, value)          -- field < value
db:lte(field, value)         -- field <= value
db:like(field, "%pattern%")  -- SQL LIKE (% = wildcard)
db:not_like(field, pattern)
db:in_(field, {v1,v2,v3})   -- field IN (v1, v2, v3)
db:not_in(field, {v1,v2})
db:between(field, low, high) -- low <= field <= high
db:is_nil(field)             -- field IS NULL
db:AND(expr1, expr2)         -- expr1 AND expr2
db:OR(expr1, expr2)          -- expr1 OR expr2
```

### Updating and Deleting

```lua
local mydb = db:get_database("journal")

-- Update: fetch first, modify, then db:set (for sweeping changes):
db:set(mydb.entries.body, "Updated text", 
  db:eq(mydb.entries.in_game_day, 42))

-- Update a fetched row (modify the returned table, pass back):
local rows = db:fetch(mydb.entries, db:eq(mydb.entries.in_game_day, 42))
for _, row in ipairs(rows) do
  row.body = row.body .. "\n[Amended]"
  db:update(mydb.entries, row)  -- saves the modified row back
end

-- Delete:
db:delete(mydb.entries, db:eq(mydb.entries.in_game_day, 42))
-- Delete ALL rows:
db:delete(mydb.entries)
```

### Practical DSL Database Designs

**Journal database:**
```lua
db:create("dsl_journal", {
  entries = {
    timestamp    = "",   -- real-world time
    in_game_date = "",   -- DSL in-game date string
    char         = "",   -- Kien, Olyndros, Tibbins
    entry_type   = "",   -- "journal", "storynote", "dream", "ritual"
    title        = "",
    body         = "",
    _index = {"char", "entry_type"},
  }
})
```

**Item/creature reference library (Layer 4):**
```lua
db:create("dsl_reference", {
  items = {
    name      = "",
    slot      = "",    -- head, chest, weapon, etc.
    location  = "",    -- where found
    stats     = "",    -- raw stat text from game
    notes     = "",
    _unique   = {"name", "slot"},
    _violations = "REPLACE",
  },
  creatures = {
    name      = "",
    area      = "",
    level     = 0,
    aggro     = "",    -- "yes", "no", "conditional"
    notes     = "",
    _unique   = {"name", "area"},
    _violations = "REPLACE",
  }
})
```

---

## 17. STRING TOOLS — f(), format, table persistence

### f() — String Interpolation

Mudlet adds the `f()` function which lets you embed variables inside strings with `{}`:

```lua
local name = "Kien"
local hp = 450
local maxhp = 600

-- Without f():
cecho("<green>" .. name .. " has " .. hp .. "/" .. maxhp .. " HP\n")

-- With f():
cecho(f"<green>{name} has {hp}/{maxhp} HP\n")

-- Expressions work too:
cecho(f"<yellow>HP at {math.floor(hp/maxhp*100)}%\n")

-- Function calls work:
cecho(f"<cyan>Time: {getTime(true, 'hh:mm:ss')}\n")
```

**Performance note:** `f()` is slower than `..` concatenation because it has to scan scope for local variables. Fine for UI display (called rarely), but avoid in tight loops processing many rows.

### string.format() — Precise Formatting

```lua
-- Pad numbers to fixed width (great for stat columns):
string.format("HP: %4d / %4d", 450, 600)  -- "HP:  450 /  600"
string.format("%3d%%", 75)                 -- " 75%"

-- Left-align strings:
string.format("%-15s %s", "Druid", "51")   -- "Druid           51"

-- Hex colors in strings:
string.format("#%02X%02X%02X", 255, 200, 0)  -- "#FFC800"

-- Combining format with cecho:
cecho(string.format("<green>%-10s <white>%3d/%3d\n", "HP:", hp, maxhp))
```

### table.save() / table.load() — Simple Persistence

For config, positions, and session state (NOT for large searchable data — use db: for that):

```lua
-- Save any Lua table to a file:
local saveData = {
  windowPositions = MyDSL.Layout.positions,
  lastChar        = "Kien",
  settings        = MyDSL.Config,
}
table.save(getMudletHomeDir() .. "/observer_save.lua", saveData)

-- Load it back (populates the table passed in):
local loaded = {}
table.load(getMudletHomeDir() .. "/observer_save.lua", loaded)

-- Typical init pattern:
function MyDSL.Config.load()
  local path = getMudletHomeDir() .. "/observer_config.lua"
  if io.exists(path) then
    table.load(path, MyDSL.Config)
    cecho("<green>[Observer] Config loaded.\n")
  else
    cecho("<yellow>[Observer] No saved config, using defaults.\n")
  end
end

function MyDSL.Config.save()
  table.save(getMudletHomeDir() .. "/observer_config.lua", MyDSL.Config)
end
```

**io.exists()** — checks if a file exists before trying to load it:
```lua
if io.exists(getMudletHomeDir() .. "/myfile.lua") then
  -- file is there, safe to load
end
```

### String Utility Functions

```lua
-- Split a string on a delimiter:
local parts = string.split("north east west", " ")
-- parts = {"north", "east", "west"}

-- Trim whitespace:
local clean = string.trim("  hello world  ")  -- "hello world"

-- Check prefix/suffix:
string.starts("hello world", "hello")  -- true
string.ends("hello world", "world")    -- true

-- Useful for parsing DSL output:
local line = "You are very hungry."
if string.starts(line, "You are very") then
  MyDSL.Status.hunger = true
end
```

---

## 18. DYNAMIC TRIGGER CREATION — Scripted Triggers

### temp vs. perm vs. named

| Type | Persists? | Editor visible? | Controllable? |
|------|-----------|-----------------|---------------|
| `tempTrigger()` | Session only | No | Kill with ID |
| `permSubstringTrigger()` | Yes, saved | Yes | Enable/disable by name |
| `permRegexTrigger()` | Yes, saved | Yes | Enable/disable by name |
| `registerNamedTrigger()` | Session only | No | Stop/resume by name |

### temp Triggers (session-only, not in editor)

Good for: one-shot responses, combat sequences, situational watchers.

```lua
-- Simple substring (fastest):
local id = tempTrigger("You are hungry", function()
  MyDSL.Status.hunger = true
  cecho("<yellow>[!] Hunger detected\n")
end)

-- Regex:
local id = tempRegexTrigger("^(\\w+) says? '(.+)'$", function()
  local speaker = matches[2]
  local text    = matches[3]
  demonnic.chat:append("Chat")
  deleteLine()
end)

-- Kill after first match (one-shot):
local myID
myID = tempTrigger("Portal opens", function()
  MyDSL.Portal.onOpen()
  killTrigger(myID)   -- remove after firing once
end)
```

### perm Triggers (saved to profile, visible in editor)

These show up in the Triggers editor and survive profile reloads. Best for permanent chat routing, status detection. **Our existing chat routing triggers use this approach.**

```lua
-- These are normally created in the Trigger editor, but can be created via Lua:
-- (creates duplicates if called multiple times — check with exists() first)
if not exists("HungerTrigger", "trigger") then
  permSubstringTrigger("HungerTrigger", "ChatTriggers",
    "You are very hungry.",
    [[MyDSL.Status.hunger = true]]
  )
end

-- Regex with multiple patterns:
permRegexTrigger("PromptCapture", "",
  {"^(\\d+)h (\\d+)m (\\d+)v"},   -- patterns array
  [[
    MyDSL.Data.updateVitals(tonumber(matches[2]), tonumber(matches[3]), tonumber(matches[4]))
  ]]
)
```

**Important:** Our project principle is that all chat and gameplay triggers should be visible in the Trigger editor, not hidden in scripts. Use `permSubstringTrigger`/`permRegexTrigger` or create them manually in the editor.

### Named Triggers (session-only, controllable)

Best for: feature modules that can be toggled on/off (e.g., combat mode):

```lua
-- Register:
registerNamedTrigger("MyDSL", "CombatWatch",
  "^(\\w+) is DEAD!\\s*$",   -- regex pattern
  function()
    MyDSL.Combat.onKill(matches[2])
  end
)

-- Stop (disables without deleting):
stopNamedTrigger("MyDSL", "CombatWatch")

-- Resume:
resumeNamedTrigger("MyDSL", "CombatWatch")

-- Delete:
deleteNamedTrigger("MyDSL", "CombatWatch")
```

### Dynamic Target Highlighting (practical example)

This is a useful pattern — highlight the current target's name in all output:

```lua
local targetTriggerID = nil

function MyDSL.Combat.setTarget(name)
  -- Remove old highlight trigger:
  if targetTriggerID then
    killTrigger(targetTriggerID)
    targetTriggerID = nil
  end
  
  if name and name ~= "" then
    -- Create new highlight trigger for this target's name:
    targetTriggerID = tempTrigger(name, function()
      selectString(name, 1)
      fg("red")
      bold(true)
      deselect()
      resetFormat()
    end)
  end
end
```

### permTimer and registerNamedTimer

```lua
-- Named timer (session, controllable):
registerNamedTimer("MyDSL", "TickCountdown", 1, function()
  MyDSL.Tick.countdown()
end, true)  -- true = repeating

stopNamedTimer("MyDSL", "TickCountdown")
resumeNamedTimer("MyDSL", "TickCountdown")

-- Persistent timer (survives profile reload, appears in Timer editor):
-- Generally better to create these in the Timer editor.
-- For scripts: permTimer(name, parent, time, code)
```

---

## 19. EMCO INTERNALS — How demonnic.chat Works

### What EMCO Actually Is

EMCO (Embeddable Multi Console Object) is a Geyser object that manages **a row of tabs** each backed by a **MiniConsole**. It IS a Geyser object — you create it with `EMCO:new()`, give it a parent container, and it handles all the tab UI and console routing internally.

`demonnic.chat` is just the global variable name that holds our EMCO instance. This name must stay `demonnic.chat` because existing chat routing triggers reference it directly.

### Architecture Under the Hood

```
demonnic.chat (EMCO object)
  ├── Tab bar (HBox of Label buttons)
  │     ├── "Chat" tab label
  │     ├── "Tells" tab label
  │     ├── "Group" tab label
  │     └── ... etc.
  └── Console area
        ├── ChatConsole     (Geyser.MiniConsole, shown when "Chat" tab active)
        ├── TellsConsole    (hidden)
        ├── GroupConsole    (hidden)
        └── ... etc.

demonnic.chat.windows["Chat"]  → the MiniConsole for the Chat tab
demonnic.chat.windows["Tells"] → the MiniConsole for the Tells tab
```

### The Core Routing Method

```lua
-- In a trigger — route current line to a tab:
selectCurrentLine()
demonnic.chat:append("Tells")   -- copies line with color to "Tells" tab
deselect()
resetFormat()
-- Don't deleteLine() here unless you want to hide it from main console

-- If you want to ALSO hide it from main console:
selectCurrentLine()
demonnic.chat:append("Tells")
deleteLine()

-- Write NEW text directly to a tab (not from game line):
demonnic.chat:cecho("Chat", "<cyan>[System] Observer UI loaded.\n")
demonnic.chat:decho("Tells", "<0,200,200>Tell received!\n")
demonnic.chat:echo("Group", "Group message\n")
```

### EMCO append() vs. appendBuffer() — Key Difference

```lua
-- demonnic.chat:append("TabName")
-- This is EMCO's own append method. Internally it calls:
--   selectCurrentLine() + copy() + targetConsole:appendBuffer()
-- You do NOT need to call selectCurrentLine() before it in a trigger —
-- EMCO does it internally.
-- BUT: EMCO's append also handles gagging, all-tab mirroring, and timestamps.

-- WRONG (double-selecting):
selectCurrentLine()
demonnic.chat:append("Chat")  -- EMCO already selects internally

-- RIGHT:
demonnic.chat:append("Chat")  -- EMCO handles everything

-- For raw MiniConsoles (non-EMCO), you DO need to select first:
selectCurrentLine()
copy()
myChatConsole:appendBuffer()
```

### Gagging Behavior

EMCO can automatically remove the line from the main console when it appends:

```lua
-- Set this on the EMCO to auto-gag lines you route:
demonnic.chat.gag = true   -- gags the current line after append

-- Or control per-append:
demonnic.chat:append("Tells", false, true)  -- third arg = excludeAll (don't mirror to "All" tab)
```

### Accessing Individual Tab Consoles

```lua
-- Get a direct reference to a tab's MiniConsole:
local tellsConsole = demonnic.chat.windows["Tells"]

-- Now you can call any MiniConsole method on it:
tellsConsole:clear()
tellsConsole:cecho("<yellow>--- Session Start ---\n")
local lineCount = tellsConsole:getLineCount()
```

### EMCO Configuration (what we can change at runtime)

```lua
-- Tab colors:
demonnic.chat:setActiveTabCSS([[
  QLabel { background-color: #4a3a6a; color: #e0c070; font-weight: bold; }
]])
demonnic.chat:setInactiveTabCSS([[
  QLabel { background-color: #1a1a2e; color: #666688; }
]])

-- Timestamps on messages:
demonnic.chat.timestamp = true
demonnic.chat.timestampFormat = "hh:mm"

-- Auto-wrap:
demonnic.chat:enableAutoWrap()   -- wraps to console width automatically

-- Add/remove a tab dynamically:
demonnic.chat:addTab("Rituals")
demonnic.chat:removeTab("OldTab")

-- Save EMCO config to disk:
demonnic.chat:save()    -- saves to getMudletHomeDir() .. "/demonnic.chat.lua"
demonnic.chat:load()    -- loads it back
```

### The Mapper Tab Option

EMCO can host the Mudlet mapper inside one of its tabs:

```lua
-- At instantiation (preferred approach):
EMCO:new({
  name = "demonnic.chat",
  mapTabName = "Map",       -- tab name to use for the mapper
  ...
}, parentContainer)

-- Or after the fact (use caution — only one mapper can be open):
demonnic.chat:enableMapTab()
demonnic.chat:setMapTabName("Map")
```

---

## 20. createBuffer — Invisible Text Processing

### What It Is

`createBuffer()` creates an **invisible, off-screen text buffer** — a MiniConsole that never displays but can receive text, be queried, and have its content read or manipulated.

```lua
-- Create an invisible buffer named "parseBuffer":
createBuffer("parseBuffer")

-- Write text to it (same echo functions work):
cecho("parseBuffer", "<red>some colored text\n")
echo("parseBuffer", "plain text\n")

-- Read it back:
local line = getCurrentLine("parseBuffer")
-- or move cursor and read specific lines
```

### Why It Matters for DSL

The main use case in our project: **parsing multi-line game output** before deciding where to route it.

```lua
-- Pattern: accumulate lines into a buffer, then process when complete
createBuffer("scoreBuffer")

-- Trigger: start of 'score' output
function MyDSL.Score.beginCapture()
  clearWindow("scoreBuffer")
  MyDSL.Score.capturing = true
end

-- Trigger: each line of 'score' output  
function MyDSL.Score.captureLine()
  if MyDSL.Score.capturing then
    selectCurrentLine()
    copy()
    appendBuffer("scoreBuffer")
    deleteLine()
  end
end

-- Trigger: end of 'score' output
function MyDSL.Score.endCapture()
  MyDSL.Score.capturing = false
  MyDSL.Score.parseBuffer()   -- now process the buffer
end
```

**Important:** `createBuffer` is a lower-level function. For most Observer UI purposes, a hidden Geyser.MiniConsole (with `label:hide()` or never shown) achieves the same thing more cleanly and is managed by Geyser's lifecycle.

---

## 21. DYNAMIC ALIAS CREATION

For completeness — aliases follow the same temp/perm/named pattern as triggers:

```lua
-- Session-only alias:
tempAlias("^score$", [[send("score"); MyDSL.Score.capturing = true]])

-- Permanent (appears in Alias editor):
permAlias("ScoreAlias", "", "^score$", 
  [[send("score"); MyDSL.Score.capturing = true]])

-- Named (controllable):
registerNamedTrigger is for triggers; aliases use tempAlias/permAlias only
```

---

## 22. COMPLETE FUNCTION QUICK-REFERENCE ADDITIONS

```
NEW IN PART 2              → WHAT TO USE
──────────────────────────────────────────────────────────────
Protect main console        → setBorderLeft/Right/Top/Bottom
Respond to window resize    → sysWindowResizeEvent + getMainWindowSize()
Persistent per-row storage  → db:create, db:add, db:fetch, db:update
Config/position saving      → table.save() / table.load()
String interpolation        → f"text {variable} here"
Formatted stat display      → string.format("%-10s %4d/%4d", ...)
Session-only trigger        → tempTrigger() / tempRegexTrigger()
Permanent trigger           → permRegexTrigger() (appears in editor)
Controllable trigger        → registerNamedTrigger()
Chat routing to EMCO tab    → demonnic.chat:append("TabName")
Direct write to EMCO tab    → demonnic.chat:cecho("TabName", "text\n")
Access EMCO's console       → demonnic.chat.windows["TabName"]
Invisible text buffer       → createBuffer("name") + echo/appendBuffer
File existence check        → io.exists(path)
```

---

## 23. IMPORTANT GOTCHAS SUMMARY

**EMCO append vs selectCurrentLine:**
Don't call `selectCurrentLine()` before `demonnic.chat:append()` — EMCO does it internally. Calling it yourself causes double-selection.

**db:create is idempotent:**
Call it at script top-level every load. It only creates if needed.

**perm triggers create duplicates:**
`permRegexTrigger("Name", ...)` does NOT check for existing triggers with the same name. Always wrap with `if not exists("Name", "trigger") then`. Or better: create them in the Trigger editor instead.

**sysWindowResizeEvent infinite loop:**
Always guard with a "did size actually change?" check. Modern Mudlet is mostly fixed, but belt-and-suspenders is fine.

**f() scope:**
`f()` can access local variables from the calling scope. This is why it works everywhere — but it's also why it's slower than `..` concatenation.

**table.save/load paths:**
Always use `getMudletHomeDir()` as your base path, never hardcoded paths. The profile directory moves between installs.

**db: field order:**
The order fields are returned from `db:fetch` is insertion order by default. If order matters, always pass an `order_by` table.

**tempRegexTrigger/tempAlias use PCRE, not Lua patterns:**
Confirmed via Mudlet's own manual and multiple live bugs this session (`groupStart` trigger, `targetMobset`/`playerset`/`quickset` aliases, `scanDir`). Lua-pattern escapes like `%s`, `%S`, `%a`, `%d`, `%'` mean nothing in PCRE — `%` isn't a PCRE escape character at all, so `%s+` matches a literal `%` followed by literal `s` characters, never actual whitespace. Use `\s`, `\S`, `\d`, `\w`, and a bare `'` (no escape needed) instead. This only applies to the *pattern string* passed to `tempRegexTrigger()`/`tempAlias()` (Section 18) — `string.match()`/`:match()` calls elsewhere in a trigger's callback body correctly use Lua patterns, so the two conventions coexist in the same file and it's easy to apply the wrong one in the wrong place.

**Mudlet's Lua is 5.1 (via LuaJIT) — no `goto`/`::label::`:**
That syntax is Lua 5.2+ only. Writing `goto continue` / `::continue::` as a substitute for a `continue` statement (a common habit from other languages) produces a *syntax* error at `dofile()` load time, not a runtime error — `goto` isn't a keyword in 5.1, so the parser reads it as a plain identifier and expects `=` or `(` after it, producing a confusing `'=' expected near 'continue'` message that doesn't obviously point at the real cause. Use a `local function` wrapping the loop body with early `return` statements instead.

---

*Part 2 complete. Parts 1+2 together cover the full Mudlet API surface area needed for all four Observer UI layers.*
*Part 1: Geyser · Echo · appendBuffer · Mapper · Sounds · Protocols*  
*Part 2: Borders · Database · Strings · Triggers · EMCO · createBuffer*
