# Module Contract: MyDSL_GroupView.lua
**Layer 3 Phase B — Group Member Display Window**
*Written 2026-07-03 — verified against actual file*

---

## What This Module Is

GroupView displays the current group composition in a compact window.
It listens for `"MyDSL.group.updated"` (emitted by DataLayer after each
`group` command parse) and re-renders. Member names are clickable to set
the Target window. Quick-action buttons allow healing/supporting any member
without navigating to the Target window first.

It never sends commands automatically. Every send requires an explicit click.

---

## Window: MyDSL_Group

**Type:** `Geyser.UserWindow` (already in WindowRegistry ✅)
**Content:** `Geyser.MiniConsole` inside at 100%×100%, `fontSize=10`, `scrollBar=false`

---

## Display Layout

Each group member gets one line:
```
[class]  name (max 20, clickable)  HP%  mana%  mv%  [Heal] [Rescue]
```

Example output:
```
[Mob] A bright ball of light  100%hp 100%mn 100%mv [Heal] [Rescue]
[Mob] A dapple grey gelding   100%hp 100%mn 100%mv [Heal] [Rescue]
[Enc] Tibbins                  96%hp  96%mn  80%mv [Heal] [Rescue]
```

### Column details

| Column | Color | Notes |
|---|---|---|
| `[class]` | Mob: dim yellow `136,136,68`; other: blue `68,136,204` | Formatted `[%-3s]` — 3-char class tag |
| name | mob: warm tan `204,170,100`; player: near-white `204,204,204` | `dechoLink` → `GV.setTarget(idx)`; truncated to 20 chars |
| `HP%` | green `68,204,68` ≥76; yellow `204,204,68` ≥51; orange `204,136,68` ≥26; red `204,68,68` else | Always shown |
| `mana%` | blue `68,136,204` | Always shown |
| `mv%` | light green `136,204,136` | Always shown |
| quick buttons | from `TV.actions` color field | Calls `GV.quickAction(idx, key)`; `rescue` hidden for Mob rows (see note below) |

---

## Quick-Action Buttons

Default: `GV.config.quickActions = {"heal", "rescue"}` — two buttons per row.

Buttons are rendered from `MyDSL.TargetView.actions[key]` entries, using the
same label/color/tooltip as the TargetView buttons.

**Exception — rescue is hidden for Mob rows:** DSL's `rescue` command only works
player→player or pet→player, never player→mob. Confirmed live: `rescue bear`
(Kien trying to rescue his own charmed pet) → "You yell out loudly for a rescue!"
every time; `order bear rescue kien` → "A wild bear rescues you!" instantly.
Helpfile confirms: "you rescue a friend, not the monster." The `rescue` button is
suppressed for any group member where `m.is_mob == true`. All other quick-action
buttons (heal, cure spells, sanctuary, etc.) remain unfiltered — they legitimately
work on charmed pets.

Click sends `act.cmd({name = m.name})` via `GV.quickAction(idx, key)`.

**Configure per-fight:**
```
mydsl group quickset cure_poison refresh
mydsl group quickset heal sanctuary
```
Takes effect immediately on next render (no reload needed).

---

## Clickable Names → Target Window

Clicking a member name calls:
```lua
GV.setTarget(idx)
  → MyDSL.Target.set(m.name, m.is_mob, "groupclick")
```

This populates the Target window with that member's name and 6 action buttons,
allowing access to the full action library from TargetView.

---

## Data Source

```lua
MyDSL.State.group = {
  members = {
    { level=51, class="War", name="Olyndros",
      hp_pct=100, mana_pct=100, mv_pct=100, is_mob=false },
    { level=30, class="Mob", name="A bright ball of light",
      hp_pct=100, mana_pct=100, mv_pct=100, is_mob=true },
    ...
  },
  count = N,
}
```

DataLayer Section 9i: `beginGroup()` / `parseGroupLine()` / `endGroup()`.
Trigger pattern: `^.+'s group:$` (PCRE — note: no `%` before `'`).
Body terminator: blank line.

---

## Gag Toggle

Body lines are gagged by DataLayer's `beginGroup()` catch-all when
`GV.config.gagGroup == true` — no separate body trigger needed here.

Header line `"Kien's group:"` gagged by `GV._triggers.gagHeader` (PCRE
pattern `^.+'s group:$`) registered only when `gagGroup=true`.

```
mydsl group gag     → setGag(true)
mydsl group ungag   → setGag(false)
```

---

## Public API

```lua
MyDSL.GroupView.render()              -- redraw from State.group
MyDSL.GroupView.setTarget(idx)        -- set Target to member at index
MyDSL.GroupView.quickAction(idx, key) -- send TV.actions[key].cmd for member idx
MyDSL.GroupView.setGag(bool)          -- toggle group output gagging
MyDSL.GroupView.init()                -- create window, register handlers
MyDSL.GroupView.config = {
  gagGroup     = false,
  quickActions = {"heal", "rescue"},  -- keys into MyDSL.TargetView.actions
}
```

---

## Event Subscriptions

```lua
registerAnonymousEventHandler("MyDSL.group.updated",
  function() GV.render() end)
```

---

## Aliases

```
mydsl group gag                           → setGag(true)
mydsl group ungag                         → setGag(false)
mydsl group quickset <key1> <key2>        → set config.quickActions = {key1, key2}
```

---

## init() Sequence

1. Kill old `_handlers`, `_triggers` (safe reload)
2. Ensure `MyDSL_Group` UserWindow exists via `Windows.ensure()`
3. Create MiniConsole inside at 100%×100%, fontSize=10
4. Register `"MyDSL.group.updated"` anonymous handler → `render()`
5. Restore gag triggers if `config.gagGroup` was true
6. `render()` — shows "(no group)" initially

---

## Dependencies

- `MyDSL.Windows.ensure("MyDSL_Group")` — WindowRegistry must be loaded first
- `MyDSL.State.group` — written by DataLayer; nil until first `group` command
- `MyDSL.TargetView.actions` — used by `quickAction()` to look up cmd/label/color;
  if TargetView is not loaded, quick buttons silently skip (nil guard in render)
- `MyDSL.Target.set()` — used by `setTarget()`; nil-guarded

---

## What This Module Does NOT Do

- Does not send commands automatically
- Does not parse group output (DataLayer owns that)
- Does not track live HP during combat (only updates on explicit `group` command)
- Does not support more than 2 quick-action buttons per row (by design — space)
- Does not persist `quickActions` to disk (reset on reload; use alias to re-set)
