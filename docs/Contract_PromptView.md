# Module Contract: MyDSL_PromptView.lua
**Layer 3 — Prompt Gag System**
*Written June 25 2026. New module, no existing code to audit.*

---

## What This Module Is

PromptView removes DSL's server prompt from the main console scroll. That is
its entire job. The data the prompt contains is already visible in LiveView
(HP/Mana/MV bars, room name, exits, stance, time) — the prompt appearing
after every command is noise, not information.

No PromptBar overlay. No data capture. No display logic. Two triggers and one
alias.

---

## The DSL Prompt Format (confirmed)

Steven's DSL2 prompt format string:
```
{B[{R%h{G/%H{GHP{x {B| {C%m{c/%M{CM{x {B| {G%v{y/%V{yMV{x {B]{x
{B[{x {Y%S{x {B|{x %a {B| {G%l{x {B|{x {p%f{x {B]{x
%c{B-{x%d {g- %t{x {B:: [{W%r{x{B] :: [{x%e{x{B]-{x%c
```

Produces exactly two lines of output per server event:

**Line 1 — vitals:**
```
[239/239HP | 133/133M | 140/140MV ] [ Normal | neutral | Dragon | (Flying) ]
```
Contains: current/max HP, Mana, MV, stance, short alignment, language,
and optional state flags (Flying, Riding, etc.).

**Line 2 — location:**
```
==-Day Time - 9:00am :: [The Chamber of the Dragon Master] :: [ND]-==
```
Contains: day/night label (%d), time (%t), room name in brackets (%r),
exits in brackets (%e).

**Note on alignment:** The prompt shows short form (`neutral`). Score shows
full form (`True Neutral`). Alignment is sourced from score only — not
captured here. Same for day/night label: already derived from the time
command parser (DataBridge DB.time.is_day). Nothing here needs capturing.

**Note on occasional name echo:** Older Kien captures showed a third line
`==-Kien` before the vitals. This also starts with `==-`. The Trigger 2
pattern `^==-` catches it automatically — no third trigger needed.

---

## Namespace

```lua
MyDSL.Prompt              -- the module
MyDSL.Prompt.enabled      -- bool: true = gagging active (UI mode)
MyDSL.Prompt.triggers     -- table of trigger IDs for enable/disable
```

---

## The Two Triggers (in Mudlet Trigger editor, not tempTrigger)

### Trigger 1 — Vitals line gag
```
Name:    MyDSL_PromptGag_Vitals
Pattern: ^\[%d+/%d+HP
Type:    Perl Regex
Script:  if MyDSL.Prompt.enabled then deleteLine() end
```

Matches: `[239/239HP | ...`

### Trigger 2 — Location line gag (and occasional name echo)
```
Name:    MyDSL_PromptGag_Location
Pattern: ^==-
Type:    Perl Regex
Script:  if MyDSL.Prompt.enabled then deleteLine() end
```

Matches: `==-Day Time - 9:00am :: [room] :: [ND]-==`
Also matches: `==-Kien` (name echo, when it appears)

Both triggers live in the Trigger editor so they are always visible to
Steven. Neither is a tempTrigger. Both are enabled by default (UI mode ON).

---

## Toggle Logic

```lua
function MyDSL.Prompt.setEnabled(state)
  MyDSL.Prompt.enabled = state
  if state then
    cecho("<green>[Observer] Prompt gagged (UI mode)\n")
  else
    cecho("<yellow>[Observer] Prompt visible (classic mode)\n")
  end
  -- Save preference
  MyDSL.Prompt.save()
end

function MyDSL.Prompt.toggle()
  MyDSL.Prompt.setEnabled(not MyDSL.Prompt.enabled)
end
```

The triggers themselves always fire (they're always active in the editor).
The `if MyDSL.Prompt.enabled then` guard inside the trigger script is what
controls whether `deleteLine()` is called. This avoids the complexity of
enable/disableTrigger() calls and works correctly on script reload.

---

## The Alias

```
mydsl prompt          -- toggle
mydsl prompt on       -- enable gagging (UI mode)
mydsl prompt off      -- disable gagging (classic mode, raw prompt shows)
```

```lua
-- Alias pattern: ^mydsl prompt(.*)$
local arg = string.trim(matches[2] or "")
if arg == "on" then
  MyDSL.Prompt.setEnabled(true)
elseif arg == "off" then
  MyDSL.Prompt.setEnabled(false)
else
  MyDSL.Prompt.toggle()
end
```

---

## Persistence

```lua
-- Save file (per-character):
getMudletHomeDir() .. "/MyDSL/prompt_" .. (MyDSL.Char() or "default") .. ".lua"

-- Saves: { enabled = true/false }
-- Loaded on login via MyDSL.Prompt.onLogin(charName)
-- Default if no file: enabled = true (UI mode ON)
```

Character-bound because a player might want classic mode on one character
and UI mode on another.

---

## Mapper Safety

Mudlet's generic_mapper listens to `onNewLine` events. The `onNewLine` event
fires for every line and captures the `line` variable before triggers run.
`deleteLine()` removes the line from display but does NOT affect the `line`
variable or the `onNewLine` event — the mapper already received it.

Prompt gagging is mapper-safe. No special handling needed.

---

## Boot / Load Sequence

```lua
function MyDSL.Prompt.onLogin(charName)
  MyDSL.Prompt.load(charName)
  -- enabled defaults to true if no save file exists
  MyDSL.Prompt.enabled = MyDSL.Prompt.enabled ~= false
end

function MyDSL.Prompt.load(charName)
  local file = promptFile(charName)
  local ok, data = pcall(table.load, file)
  if ok and data then
    MyDSL.Prompt.enabled = data.enabled ~= false
  end
end

function MyDSL.Prompt.save()
  local file = promptFile(MyDSL.Char() or "default")
  pcall(table.save, file, { enabled = MyDSL.Prompt.enabled })
end
```

Called by DataLayer's login handler, same pattern as AffectsView's
`onCharacterChanged()`.

---

## What This Module Does NOT Do

- Does not create any windows or display overlays
- Does not capture or store data from the prompt
- Does not derive alignment, day/night, or any other value from the prompt
  (those come from score parser and time command parser respectively)
- Does not send game commands
- Does not interfere with any other module

---

## Dependencies

**Reads:** Nothing from DataBridge or DataLayer
**Must load before:** Nothing (standalone)
**Must load after:** Nothing (standalone — triggers fire independently)
**Trigger editor:** Two triggers must be present in the editor (not in code)

---

## Files Required

This module is smaller than any other Phase A module:

1. `MyDSL_PromptView.lua` — toggle logic, alias, persistence (~60 lines)
2. Two triggers in the Mudlet Trigger editor:
   - `MyDSL_PromptGag_Vitals` (pattern `^\[%d+/%d+HP`)
   - `MyDSL_PromptGag_Location` (pattern `^==-`)
3. One alias: `mydsl prompt`

---

## Contract Status

| Clause | Status |
|---|---|
| No window or overlay created | Confirmed — gag only |
| No data captured from prompt | Confirmed — LiveView owns all data |
| Mapper safety via onNewLine ordering | Confirmed |
| Two triggers sufficient (no third) | Confirmed — ^==- covers name echo too |
| Character-bound preference | Confirmed |
| Default: enabled (UI mode ON) | Confirmed |
| Triggers in editor (not tempTrigger) | Confirmed |
| Alias: mydsl prompt on/off/toggle | Confirmed |
EOF