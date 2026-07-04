# Module Contract: MyDSL_TargetView.lua
**Layer 3 Phase B — Target Window + Action Buttons**
*Written 2026-07-02 — final pass verified against all project files*

---

## What This Module Is

TargetView displays the current combat target — name and type — and provides
two sets of 6 configurable action buttons (one set for mobs, one for players).
Clicking a button sends the corresponding command to the game. Target is set
by clicking in RightHere or by typing `mydsl target <name>`.

It never sets targets automatically. It never sends commands without a
deliberate player button click.

---

## Why This Window Matters

During combat the player needs quick access to common actions without typing.
RightHere feeds a name to Target, and the player clicks what they want done.

---

## Target State

```lua
MyDSL.State.target = {
  name    = "a large Yeti",    -- display name as it appeared in scan
  key     = "large yeti",      -- normalized: lowercase, articles stripped
  is_mob  = true,              -- true = mob buttons, false = player buttons
  source  = "righthereclick",  -- "righthereclick" | "manual" | "combat"
  set_at  = 0,                 -- os.time() when set
}
```

**Setting the target:**
```lua
MyDSL.Target.set(name, is_mob, source)
-- Sets State.target, raises "MyDSL.target.updated", re-renders window
```

**Clearing the target:**
```lua
MyDSL.Target.clear()
-- Clears State.target, raises "MyDSL.target.updated", re-renders window
```

---

## Mob vs Player Detection

**Primary:** `is_mob` flag is always set by the caller.
- RightHere click: always knows from the scan parse
- Manual alias: uses article pattern detection

**Article pattern (fallback for manual/alias):**
```lua
local function isMob(name)
  return name:match("^[Aa]n? ") ~= nil or name:match("^[Tt]he ") ~= nil
end
```

**Manual override:** Small `[M]` / `[P]` toggle in the window flips is_mob
and re-renders buttons. Lets player correct auto-detection if wrong.

---

## Window: MyDSL_Target

**Type:** `Geyser.UserWindow` (already in WindowRegistry ✅)
**Layout position:** `x=0.00, y=0.36, w=0.18, h=0.24` (from LayoutEngine ✅)
**Content:** `Geyser.MiniConsole` inside at 100%×100%

### Display Layout (top to bottom):

**Line 1 — Type toggle + Clear + name:**
```
[M] [Clear] a large Yeti
```
- `[M]` / `[P]` is a `dechoLink` — click flips is_mob, re-renders
- `[M]` color: decho `<204,136,68>` orange-tan; `[P]` color: decho `<136,170,255>` blue
- `[Clear]` is a `dechoLink` — dim red `<170,68,68>`, calls `Target.clear()`; only rendered when a target is set
- Name: `<255,255,255>` bright white
- No target: `<85,85,85>` dim `(no target)` (no Clear button shown)

**Lines 2-3 — Action buttons (3 per line, 6 total):**
```
[Murder] [Glance] [Consider]
[Lore] [Rescue] [Flee]
```
or for player target:
```
[Murder] [Glance] [Rescue]
[Look] [Heal] [Flee]
```

Each button is a `dechoLink` on the Geyser MiniConsole object:
```lua
mc:dechoLink(
  string.format("<%s>[%s]<r>", act.color, act.label),
  string.format("MyDSL.Target.doAction('%s')", key),
  act.tooltip .. ": " .. t.name,
  false)
```

Button color groups (decho RGB):
- Aggressive (murder, flee): `204,68,68` red
- Info (glance, consider, look, creaturelore): `204,204,204` near-white
- Combat support (rescue): `170,170,255` lavender
- Healing spells (heal, cure_light, refresh, cure_serious, cure_critical): `68,204,68` green
- Curative spells (cure_blindness, cure_disease, cure_poison, cure_fatigue, cure_bugbite): `170,170,255` lavender
- Buff (sanctuary): `255,215,65` gold

**Line 4+ — Consider output display:**
```
It would be a difficult fight.
```
Dim `<136,136,136>`. Cleared when target changes. Shows last consider result.
Updated by `MyDSL.Target.captureConsider(line)`.

---

## Action Definitions

All `cmd` functions use `commandArg(t.name)` which strips articles (a/an/the)
then reduces to the **last word** of the result. Multi-word quoting was removed
after extensive live testing confirmed DSL keyword matching only works on a single
word regardless of quoting (`cast heal 'wild bear'` → "They aren't here.";
`cast heal bear` → "Ok."). Keyword sets are per-mob and not every word in the
display name is a valid keyword — `commandArg()` consistently picks the last word
which is the most specific and is always a valid keyword.

```lua
MyDSL.TargetView.actions = {
  -- Combat
  murder       = { cmd=…"murder <arg>",            label="Murder",    color="204,68,68",   tooltip="Attack target" },
  flee         = { cmd=…"flee",                     label="Flee",      color="204,68,68",   tooltip="Attempt to flee combat" },
  order_attack = { cmd=…"order all murder <arg>",   label="Order All", color="204,68,68",   tooltip="Order all followers to attack target" },
  --   ↑ opt-in only — not in default mob_buttons/player_buttons; add via mydsl target mobset/playerset
  -- Info
  glance       = { cmd=…"gl <arg>",            label="Glance",     color="204,204,204", tooltip="Quick look at target" },
  consider     = { cmd=…"consider <arg>",      label="Consider",   color="204,204,204", tooltip="Check combat difficulty" },
  creaturelore = { cmd=…"creaturelore <arg>",  label="Lore",       color="204,204,204", tooltip="Get creature lore (opens reference window)" },
  look         = { cmd=…"look <arg>",          label="Look",       color="204,204,204", tooltip="Full look at target" },
  -- Combat support
  rescue       = { cmd=…"rescue <arg>",        label="Rescue",     color="170,170,255", tooltip="Rescue target from combat" },
  -- Healing spells (green)
  heal         = { cmd=…"cast 'heal' <arg>",        label="Heal",       color="68,204,68",   tooltip="Cast heal on target" },
  cure_light   = { cmd=…"cast 'cure light' <arg>",  label="Cr.Light",   color="68,204,68",   tooltip="Cure light wounds" },
  refresh      = { cmd=…"cast refresh <arg>",        label="Refresh",    color="68,204,68",   tooltip="Restore movement points" },
  cure_serious = { cmd=…"cast 'cure serious' <arg>", label="Cr.Serious", color="68,204,68",   tooltip="Cure serious wounds" },
  cure_critical= { cmd=…"cast 'cure critical' <arg>",label="Cr.Critical",color="68,204,68",   tooltip="Cure critical wounds" },
  -- Curative spells (lavender)
  cure_blindness={ cmd=…"cast 'cure blindness' <arg>",label="Cr.Blind",  color="170,170,255", tooltip="Cure blindness" },
  cure_disease = { cmd=…"cast 'cure disease' <arg>", label="Cr.Disease", color="170,170,255", tooltip="Cure disease" },
  cure_poison  = { cmd=…"cast 'cure poison' <arg>",  label="Cr.Poison",  color="170,170,255", tooltip="Cure poison" },
  cure_fatigue = { cmd=…"cast 'cure fatigue' <arg>", label="Cr.Fatigue", color="170,170,255", tooltip="Cure fatigue" },
  cure_bugbite = { cmd=…"cast 'cure bugbite' <arg>", label="Cr.Bugbite", color="170,170,255", tooltip="Cure bugbite toxin" },
  -- Buff (gold)
  sanctuary    = { cmd=…"cast sanctuary <arg>",      label="Sanctuary",  color="255,215,65",  tooltip="Halve damage taken" },
}
```

All 18 entries are available to `mydsl target mobset/playerset` by key name.

---

## Default Button Sets

```lua
MyDSL.TargetView.config = {
  mob_buttons    = { "murder", "glance", "consider", "creaturelore", "rescue", "flee" },
  player_buttons = { "murder", "glance", "rescue", "look", "heal", "flee" },
}
```

Displayed as two rows of 3:
```
[murder] [glance] [consider]        (mob, row 1)
[creaturelore] [rescue] [flee]       (mob, row 2)

[murder] [glance] [rescue]           (player, row 1)
[look] [heal] [flee]                 (player, row 2)
```

**Configurable via alias:**
```
mydsl target mobset murder glance consider creaturelore rescue flee
mydsl target playerset murder glance rescue look heal flee
```

Config persisted to `getMudletHomeDir() .. "/MyDSL/targetview_config.lua"`.

---

## Consider Output Capture

The `consider` command outputs two lines in the main console:
```
You wonder if you could kill a large Yeti ...
... It would be a difficult fight.
```
Both lines are also echoed into the Target window's Line 4 area.
The output is NOT gagged from main console.

**Triggers (owned by TargetView, registered in init()):**
```lua
-- Line 1: "You wonder if you could kill..."
tempRegexTrigger("^You wonder if you could kill",
  function() MyDSL.Target.captureConsider(getCurrentLine()) end)

-- Line 2: "... It would be..." or similar
tempRegexTrigger("^%.%.%. ",
  function() MyDSL.Target.captureConsider(getCurrentLine()) end)
```

`captureConsider(line)`:
- Appends line to consider display area in Target window
- Clears the area when target changes

---

## CreatureLore Integration

When `[CreatureLore]` button is clicked:
1. `send("creaturelore " .. target.name)` fires
2. DataLayer's creaturelore parser captures the output
3. `MyDSL.creaturelore.updated` event fires
4. CreatureReference window shows and renders the lore
5. TargetView does NOT parse lore output

CreatureReference window opens automatically on lore capture.

---

## Public API

```lua
MyDSL.Target.set(name, is_mob, source)   -- set target, raise event, render
MyDSL.Target.clear()                      -- clear target, raise event, render
MyDSL.Target.toggle()                     -- flip is_mob, render
MyDSL.Target.doAction(action_key)         -- execute action on current target
MyDSL.Target.captureConsider(line)        -- append consider line to display
MyDSL.TargetView.init()                   -- create window, register handlers
MyDSL.TargetView.render()                 -- redraw Target window
MyDSL.TargetView._handlers = {}
MyDSL.TargetView._triggers = {}
MyDSL.TargetView._aliases  = {}
MyDSL.TargetView.config = {
  mob_buttons    = { "murder", "glance", "consider", "creaturelore", "rescue", "flee" },
  player_buttons = { "murder", "glance", "rescue", "look", "heal", "flee" },
}
```

---

## Event Subscriptions

```lua
registerAnonymousEventHandler("MyDSL.target.updated",
  function() MyDSL.TargetView.render() end)
```

`MyDSL.target.updated` raised by `Target.set()` and `Target.clear()`.

---

## Aliases

```
mydsl target <name>                       → Target.set(name, isMob(name), "manual")
mydsl target clear                        → Target.clear()
mydsl target mobset <a1>..<a6>            → set mob_buttons, save config
mydsl target playerset <a1>..<a6>         → set player_buttons, save config
```

---

## init() Sequence

1. Kill old _handlers, _triggers, _aliases (safe reload)
2. Ensure MyDSL_Target UserWindow exists
3. Create MiniConsole inside MyDSL_Target at 100%×100%
4. Register MyDSL.target.updated handler
5. Register consider capture triggers
6. Register aliases
7. Load config from disk if exists
8. render() — shows "(no target)" initially

---

## What This Module Does NOT Do

- Does not set target automatically from combat lines (future)
- Does not send any command without button click
- Does not parse creaturelore (CreatureReference owns that)
- Does not auto-clear target when mob dies (future)
- Does not track live HP/condition of target (future — needs combat parsing)
- Does not modify DataLayer state directly
