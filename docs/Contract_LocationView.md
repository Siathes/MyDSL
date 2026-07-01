# Module Contract: MyDSL_LocationView.lua
**Layer 3 — Room/Location Display + Authoritative roomData() Source**
*Written from actual code. Version: v4C3 RoomPicCanonical. File: MyDSL_LocationView.lua (788 lines)*

---

## What This Module Is

LocationView has two responsibilities bundled into one module:

1. **Display** — shows a room image (like PortraitView, but for rooms instead
   of characters) in the `MyDSL_Location` window, with a text caption fallback
   when no image exists for the current room.

2. **Data authority** — `MyDSL.Location.roomData()` is the single best-effort
   function for "what room am I in right now," cascading through multiple
   sources. **LiveView already depends on this function** (confirmed in the
   LiveView contract's data-source cascade — it's checked first, before
   DataBridge).

This is the most important interface boundary between LocationView and the
rest of Layer 3. Any module needing current room info should call
`MyDSL.Location.roomData()` rather than reading GMCP or DataBridge directly.

---

## Namespace

```lua
MyDSL.Location          -- canonical module
RoomPic                 -- backward-compat alias = MyDSL.Location (entire table)
```

Note: `RoomPic = M` aliases the **whole module**, not just selected functions
(different pattern than PortraitView's CharPic, which mirrors function-by-function).

---

## `MyDSL.Location.roomData()` — THE KEY FUNCTION

This is read by LocationView itself AND by LiveView. Cascades through sources
in order, returns the first one that yields a valid room name:

```
1. MyDSL.DB.room              ← DataBridge (once DataBridge Gap 1/2 fixed)
2. MyDSL.DB.currentRoom       ← legacy DataBridge alias
3. MyDSL.State.room           ← DataLayer direct
4. MyDSL.State.roomdesc       ← DataLayer description capture
5. MyCore.gmcp.room_data      ← legacy namespace, dead in DSL2 (Gap 1)
6. MyCore.gmcp.Room.Info      ← legacy namespace, dead in DSL2 (Gap 1)
7. gmcp.room_data             ← raw GMCP (confirmed field: .room not .name) ✅
8. gmcp.Room.Info             ← IRE/other MUD format, never present in DSL
9. Mudlet mapper fallback     ← getPlayerRoom() + getRoomName() + getRoomExits()
```

**Return shape:**
```lua
{
  room    = "In the Main Gathering Room of the Fellowship Saloon",
  area    = nil,        -- only populated by mapper fallback (Gap 2)
  terrain = "inside",   -- maps from r.terrain or r.sector ✅ handles confirmed field
  exits   = "E N U W",  -- flattened, sorted, space-separated
  source  = "gmcp.room_data",  -- which source answered
  roomId  = 2643,        -- only present when mapper fallback used
}
```

**Field handling is already correct:**
```lua
local room = safeStr(r.room or r.name or r.title)
```
This already accounts for the confirmed GMCP field name `room` (not `name`).
LocationView does NOT have the room-field bug that DataBridge has (DataBridge
Gap 1). Once DataBridge's `DB.room` is fixed, source #1 will work correctly;
until then, source #7 (raw GMCP) already works correctly today.

---

## The Mapper Fallback — Notable Design

When no MyDSL/GMCP source has room data (e.g., right after login before GMCP
populates), `roomDataFromMapper()` asks the Mudlet mapper directly:

```lua
getPlayerRoom()              -- current room ID
getRoomName(id)               -- room name
getRoomExits(id)               -- exits table
getRoomArea(id) → getRoomAreaName(area)  -- area name
getRoomUserData(id, "terrain" or "sector")  -- terrain type
```

This means **even with zero GMCP data, if the mapper knows where you are,
LocationView (and therefore LiveView) can still show a room name.** This is
a deliberate resilience feature — confirmed valuable given DataBridge's
current gaps.

---

## Image Display — Same Pattern as PortraitView

```
1. Auto-discover: <roomDir>/Exact_Room_Name.png
2. Check location_profiles.lua for a manual room→image mapping
3. If found: render image with caption (room name + area + terrain + exits)
4. If not found: render caption only (missing mode: caption|blank)
```

**Default directory:**
```
getMudletHomeDir()/MyDSL/roompics/
```

**Filename convention:** `Exact Room Name` → `Exact_Room_Name.png`
(spaces become underscores, non-alphanumeric stripped)

**Caption format (when shown):**
```
In the Main Gathering Room of the Fellowship Saloon
[inside] [E N U W]
```

---

## Per-Room Manual Mapping

```
getMudletHomeDir()/MyDSL/roompics/location_profiles.lua
```

```lua
{
  rooms = {
    ["in the main gathering room of the fellowship saloon"] = "/path/to/saloon.png",
  },
}
```

Manual room→image overrides, keyed by lowercased room name. Same hybrid
pattern as PortraitView (per-room override, shared settings).

---

## Window Creation — PARTIALLY USES WINDOWREGISTRY ⚠️

```lua
local function getWindowEntry()
  local reg = MyDSL.Windows.registry
  return reg["MyDSL_RoomPicture"] or reg[M.windowName] or reg["Location"]
end
```

**Checks `"MyDSL_RoomPicture"` FIRST** — the old pre-rename key — before
`M.windowName` (`"MyDSL_Location"`). Since WindowRegistry's corrected registry
no longer has a `"MyDSL_RoomPicture"` entry (renamed per Gap 1 of the
WindowRegistry contract), this lookup will fail on the first key and succeed
on the second (`reg[M.windowName]`) — but only if WindowRegistry's key is
also exactly `"MyDSL_Location"`.

**This module's fallback constructor already uses `restoreLayout = true` and
`autoDock = true`** — ahead of TickView, LiveView, and other modules on the
native Mudlet docking pattern (see LayoutEngine contract addendum).

```lua
WinClass:new({
  name = M.windowName,
  x = M.config.x, y = M.config.y,
  width = M.config.w, height = M.config.h,
  restoreLayout = true,    -- ✅ correct pattern, ahead of other modules
  autoDock = true,          -- ✅ correct pattern
})
```

---

## Events

```lua
"gmcp.room_data"  → onRoomData() → refresh("gmcp.room_data")
"gmcp.Room.Info"  → onRoomData() → refresh()  -- dead in DSL2, never fires
"onNewRoom"       → onRoomData() → refresh()  -- fires from generic_mapper script ✅
```

The `onNewRoom` listener is valuable — it means LocationView refreshes when
the **mapper** detects a new room, independent of GMCP. Double-coverage with
GMCP for resilience.

**Handler management:** Uses `M.handlersInstalled` flag (not `registerHandlerOnce`
pattern). Same issue as TickSource/TickView/LiveView — old handlers not killed
on reload.

---

## Public API

```lua
M.roomData()              -- ⭐ the key cross-module function
M.currentRoomName()       -- shorthand: roomData().room
M.refresh(reason)
M.show(save) / M.hide(save)
M.clear(caption)
M.rebuild()
M.setByName(room)         -- manually override displayed room
M.setImage(path)          -- manually set image for current room
M.setDir(path)
M.setFit(mode)             -- cover|stretch|contain|fill
M.setMissing(mode)         -- caption|blank
M.setTitle(title)
M.setDebug(mode)
M.mapRoom(room, path)      -- create manual room→image mapping
M.unmapRoom(room)
M.listMaps()
M.probe(room)              -- show what file would be used
M.status()
M.help()
```

---

## Aliases

```
mydsl location [status|show|hide|refresh|rebuild|dir|probe|maps|help]
mydsl location name <room>
mydsl location set <path>
mydsl location map <room> = <path>
mydsl location unmap <room>
mydsl location fit cover|stretch|contain|fill
mydsl location missing caption|blank
mydsl location title <text>
mydsl location debug on|off
mydsl loc ...          -- shorthand alias
roompic ...            -- legacy compat
locpic ...             -- legacy compat
```

---

## Philosophy Compliance

Display only. No game commands sent. Refreshes are passive (GMCP/mapper event
driven). Manual overrides are user-initiated only.

---

## Dependencies

**Reads from:** `MyDSL.DB.room`, `MyDSL.State.room`, `gmcp.room_data`, Mudlet
mapper functions (`getPlayerRoom`, `getRoomName`, etc.)
**Provides to:** LiveView (via `roomData()`) — confirmed hard dependency
**Must load after:** WindowRegistry
**Should load before:** LiveView (since LiveView calls `MyDSL.Location.roomData()`)

---

## What This Module Does NOT Do

- Does not manage the minimap (generic_mapper's job)
- Does not send game commands
- Does not route chat or other text
- Does not manage character portraits (PortraitView's job)

---

## Gaps and Issues Found in Code

### Gap 1 — Legacy MyCore references (dead code) ℹ️
`roomData()` checks `MyCore.state.gmcp.room_data` and `MyCore.state.gmcp.Room.Info`
as sources 5 and 6. `MyCore` never exists in DSL2. These checks always return nil
and fall through. Harmless but adds noise.

**Fix:** Remove the two `MyCore.*` candidate entries from the sources list.

### Gap 2 — `area` field rarely populated ⚠️
Only the mapper fallback (`roomDataFromMapper()`) populates `area`. All GMCP-based
sources leave `area` nil because DSL's GMCP `room_data` does not include an area
field — only `room`, `exits`, and `sector`. This matches DataBridge's confirmed
finding (DataBridge Gap 2: area is not in GMCP, only `sector`/terrain is).

**No fix needed in LocationView** — this is correct behavior given DSL's GMCP
schema. Worth noting in DataLayer/DataBridge contracts: area name is GMCP-absent
and can only come from the mapper (`getRoomAreaName`) when the room is mapped.

### Gap 3 — Window key lookup checks renamed key first ⚠️
```lua
reg["MyDSL_RoomPicture"] or reg[M.windowName] or reg["Location"]
```
Should be simplified now that the rename to `MyDSL_Location` is confirmed:
```lua
reg[M.windowName] or reg["Location"]
```
Remove the `"MyDSL_RoomPicture"` legacy key entirely — WindowRegistry's
post-rename registry will never have that key.

### Gap 4 — Handler management uses flag, not registerHandlerOnce ⚠️
Same systemic issue as TickSource, TickView, LiveView. Should adopt
AffectsView's `registerHandlerOnce` pattern for reload safety.

### Gap 5 — Hardcoded theme colors ⚠️
```lua
M.theme = {
  bg = "rgba(8,8,8,255)",
  border = "rgba(220,200,150,145)",
  captionBg = "rgba(0,0,0,170)",
  captionText = "rgba(245,235,210,235)",
  warnText = "rgba(255,190,100,235)",
}
```
Separate hardcoded theme table, not connected to `MyDSL.Theme`. Same gap
pattern as every other Phase A module.

### Gap 6 — Hardcoded fallback position ⚠️
```lua
M.config.x = 740, M.config.y = 80, M.config.w = 380, M.config.h = 280
```
Pixel values, not percentages, and don't match confirmed layout
(x=0.00, y=0.00, w=0.23, h=0.23 for the top-left Location panel).
Only used if WindowRegistry lookup fails entirely.

**Fix:** Convert to percentage strings matching confirmed layout:
```lua
M.config.x = "0%", M.config.y = "0%", M.config.w = "23%", M.config.h = "23%"
```

---

## Contract Status

| Clause | Status |
|---|---|
| roomData() — confirmed field handling (room/name/title) | ✅ |
| roomData() — mapper fallback for resilience | ✅ Valuable design |
| terrain/sector field handled correctly | ✅ |
| onNewRoom listener (mapper-driven refresh) | ✅ |
| restoreLayout/autoDock already used | ✅ Ahead of other modules |
| Per-room image mapping | ✅ |
| RoomPic compat alias | ✅ (whole-table alias) |
| No automatic game commands | ✅ |
| MyCore legacy references | ⚠️ Dead code — Gap 1 |
| area field population | ℹ️ Correctly limited by GMCP schema — Gap 2 |
| Window key lookup (post-rename cleanup) | ⚠️ Needs simplification — Gap 3 |
| registerHandlerOnce pattern | ❌ Uses flag — Gap 4 |
| ThemeEngine integration | ❌ Hardcoded — Gap 5 |
| Fallback position (pixels vs confirmed %) | ❌ Wrong — Gap 6 |
EOF