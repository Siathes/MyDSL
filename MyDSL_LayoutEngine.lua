-- =============================================================================
-- MyDSL_LayoutEngine.lua  --  Layer 2, File 2 of 3: Window Layout System
-- =============================================================================
-- This file owns where every window lives on screen.
-- All positions are stored as fractions of the screen (0.0–1.0).
-- Pixel values are only calculated at runtime when windows are actually moved.
--
-- This file NEVER creates windows — that is File 3's job (WindowRegistry).
-- This file NEVER imports WindowRegistry — Layout has no dependency on a
-- module that depends on it. reflowAll() receives the registry as a parameter
-- so the two modules stay completely independent.
--
-- Read/write path:
--   Layer 3 calls LayoutEngine to find out where windows go.
--   LayoutEngine reads from its positions table (loaded from disk on startup).
--   When the user moves a window, Layer 3 calls Layout.set() to save the change.
-- =============================================================================


------------------------------------------------------------------------
-- SECTION 1: NAMESPACE GUARDS
------------------------------------------------------------------------
-- See MyDSL_ThemeEngine.lua for a full explanation of the 'or {}' guard.
-- Short version: it prevents a script reload from wiping live data.

MyDSL         = MyDSL         or {}
MyDSL.Layout  = MyDSL.Layout  or {}

-- _handlers stores the numeric IDs returned by registerAnonymousEventHandler.
-- We keep them here so we can cancel old handlers when the script reloads.
-- Without this, each reload would add another handler on top of the previous
-- one — the resize event would fire the layout function two, three, four times.
MyDSL.Layout._handlers = MyDSL.Layout._handlers or {}


------------------------------------------------------------------------
-- SECTION 2: DEFAULT POSITIONS
------------------------------------------------------------------------
-- Every window the UI will ever use is listed here with its default layout.
-- x, y = top-left corner of the window, as a fraction of screen size.
-- w, h = width and height, as a fraction of screen size.
--
-- Example: x=0.66, w=0.34 means the window starts 66% across the screen
-- and is 34% of the screen wide. On 1920px wide: starts at 1267px, 653px wide.
--
-- The layout is designed for 1920x1080 with the main Mudlet console
-- occupying roughly the left 65% of the screen (0.00–0.65 on the x axis).
-- The right 35% (0.65–1.00) is the primary panel zone.
--
-- Windows marked "UserWindow" can be detached to a second monitor.
-- Windows marked "Container" are anchored inside the main Mudlet frame.

MyDSL.Layout.defaults = MyDSL.Layout.defaults or {

  -- ---- RIGHT PANEL (UserWindows) -----------------------------------

  -- MyDSL_Chat: full-height right column top — chat is the most-read panel.
  MyDSL_Chat             = { x=0.66, y=0.00, w=0.34, h=0.30 },

  -- MyDSL_Affects: just below chat — active spell timers, frequently glanced.
  MyDSL_Affects          = { x=0.66, y=0.30, w=0.34, h=0.25 },

  -- MyDSL_Tick: narrow strip at mid-right — shows tick countdown.
  MyDSL_Tick             = { x=0.66, y=0.55, w=0.08, h=0.18 },

  -- MyDSL_Group: next to tick — group members and their vitals.
  MyDSL_Group            = { x=0.74, y=0.55, w=0.26, h=0.18 },

  -- MyDSL_CreatureReference: bottom-right — mob/creature info lookup.
  MyDSL_CreatureReference = { x=0.66, y=0.73, w=0.34, h=0.27 },

  -- MyDSL_Inventory: overlaps affects zone — shown on demand (toggle).
  MyDSL_Inventory        = { x=0.66, y=0.30, w=0.34, h=0.45 },

  -- MyDSL_Equipment: overlaps inventory zone — shown on demand (toggle).
  MyDSL_Equipment        = { x=0.66, y=0.30, w=0.34, h=0.45 },

  -- ---- LEFT PANEL (UserWindows) ------------------------------------

  -- MyDSL_Portrait: top-left corner — character portrait image.
  MyDSL_Portrait         = { x=0.00, y=0.00, w=0.10, h=0.18 },

  -- MyDSL_RoomPicture: below portrait — room/area picture.
  MyDSL_RoomPicture      = { x=0.00, y=0.18, w=0.10, h=0.18 },

  -- MyDSL_Target: left side mid — target info and health bar.
  MyDSL_Target           = { x=0.00, y=0.36, w=0.18, h=0.24 },

  -- MyDSL_RightHere: clickable mob list from scan — paired with Target window.
  MyDSL_RightHere        = { x=0.00, y=0.60, w=0.18, h=0.22 },

  -- MyDSL_PlayersNear: players-near-you output from scan parsing.
  MyDSL_PlayersNear      = { x=0.18, y=0.60, w=0.16, h=0.22 },

  -- MyDSL_Mapper: same slot as Target — shown on demand.
  MyDSL_Mapper           = { x=0.00, y=0.36, w=0.18, h=0.24 },

  -- ---- BOTTOM STRIP (UserWindows) ----------------------------------

  -- MyDSL_Combat: bottom-left — condensed combat damage log.
  MyDSL_Combat           = { x=0.00, y=0.60, w=0.34, h=0.22 },

  -- MyDSL_History: general informational output — sailing, quests, atmosphere events.
  MyDSL_History          = { x=0.34, y=0.82, w=0.32, h=0.18 },

  -- MyDSL_Scan: right of combat — scan/look-around results.
  MyDSL_Scan             = { x=0.34, y=0.60, w=0.32, h=0.22 },

  -- MyDSL_Live: center bottom strip — live vitals bar (HP/mana/mv).
  MyDSL_Live             = { x=0.10, y=0.82, w=0.56, h=0.18 },

  -- ---- MAIN CONSOLE OVERLAYS (Adjustable.Container) ---------------
  -- These sit inside the main Mudlet console frame and cannot detach.

  -- MyDSL_MoonWeather: thin bar across the top of the console area.
  MyDSL_MoonWeather      = { x=0.10, y=0.00, w=0.56, h=0.05 },

  -- MyDSL_AsciiMap: ASCII map inset over the top-left of the console.
  MyDSL_AsciiMap         = { x=0.10, y=0.05, w=0.30, h=0.25 },

  -- MyDSL_Banner: center-screen overlay for announcements and alerts.
  MyDSL_Banner           = { x=0.20, y=0.40, w=0.40, h=0.10 },

  -- MyDSL_Bloodbath: bottom overlay for bloodbath/event messages.
  MyDSL_Bloodbath        = { x=0.10, y=0.75, w=0.46, h=0.08 },
}


------------------------------------------------------------------------
-- SECTION 3: LIVE POSITIONS TABLE
------------------------------------------------------------------------
-- MyDSL.Layout.positions is the working copy that gets modified at runtime.
-- On first load it is a deep copy of defaults.
-- On reload (script re-save), the existing positions are preserved.
-- After a successful load() call, it reflects whatever was saved to disk.
--
-- Why a deep copy instead of just pointing at defaults?
-- Because Lua tables are references, not values. If we wrote:
--   positions = defaults
-- then modifying positions["MyDSL_Chat"].x would also modify defaults["MyDSL_Chat"].x
-- because both variables point at the same table in memory.
-- A deep copy gives each entry its own independent table.

if not MyDSL.Layout.positions then
  MyDSL.Layout.positions = {}
  for name, pos in pairs(MyDSL.Layout.defaults) do
    -- Create a fresh {x,y,w,h} table for each window.
    -- This is the deep copy — each window gets its own table in memory.
    MyDSL.Layout.positions[name] = { x=pos.x, y=pos.y, w=pos.w, h=pos.h }
  end
end


------------------------------------------------------------------------
-- SECTION 4: SAVE FILE PATH
------------------------------------------------------------------------
-- The layout is saved as a Lua file in the profile directory.
-- getMudletHomeDir() returns the path to the current profile folder
-- (e.g. /home/owner/.config/mudlet/profiles/DSL2).
-- The trailing "/" is needed before the filename.
--
-- This is a local variable — it never needs to be accessed from outside
-- this file. Declaring it local keeps the global namespace clean.

local SAVE_FILE = getMudletHomeDir() .. "/MyDSL_layout.lua"


------------------------------------------------------------------------
-- SECTION 5: PERSISTENCE — save() and load()
------------------------------------------------------------------------

-- save()
-- Writes MyDSL.Layout.positions to disk using Mudlet's table.save().
-- table.save() serializes a Lua table into a file as valid Lua code.
-- When that file is loaded later with table.load(), it reconstructs
-- the exact same table structure — numbers, strings, nested tables and all.
-- This is much simpler than writing a custom file format.

function MyDSL.Layout.save()
  table.save(SAVE_FILE, MyDSL.Layout.positions)
end

-- load()
-- Reads the save file from disk. If it doesn't exist or can't be read,
-- we silently stay with the defaults — no error is shown to the player.
-- After a successful load, validate() is called to catch any bad values
-- that might have crept in (e.g. from an older version of the layout file).

function MyDSL.Layout.load()
  -- io.open is Lua's standard file-open function.
  -- We open in read mode ("r") just to test if the file exists.
  -- If it doesn't exist, io.open returns nil and we skip the load.
  local f = io.open(SAVE_FILE, "r")
  if not f then
    -- No save file found — first run, or file was deleted. Use defaults.
    return
  end
  f:close()

  -- table.load() reads the serialized file and returns the table it contains.
  -- We load into a temporary variable first so that if the load fails
  -- (e.g. the file is corrupt), we don't overwrite good live data.
  local loaded = table.load(SAVE_FILE)
  if type(loaded) ~= "table" then
    debugc("[MyDSL] LayoutEngine: save file corrupt or unreadable — using defaults.")
    return
  end

  -- Replace positions with the loaded data.
  MyDSL.Layout.positions = loaded

  -- Clean up any stale or invalid entries.
  MyDSL.Layout.validate()
end

-- validate()
-- Scans the positions table for problems after a load() or at any time.
-- Two kinds of problems are fixed:
--   1. A window name that is not in defaults — it's stale (from an old version).
--      We remove it so it doesn't confuse anything.
--   2. A window whose x/y/w/h values are out of range or nil.
--      We replace the whole entry with the default (safe reset).

function MyDSL.Layout.validate()
  -- We collect names to remove in a separate list because you must never
  -- modify a table while iterating over it with pairs() — Lua's behavior
  -- in that case is undefined (it may skip entries or loop forever).
  local toRemove = {}

  for name, pos in pairs(MyDSL.Layout.positions) do
    if not MyDSL.Layout.defaults[name] then
      -- This window name is not in our known list — stale entry from an
      -- older layout file. Queue it for removal.
      debugc("[MyDSL] LayoutEngine: removing unknown window from layout: " .. name)
      toRemove[#toRemove + 1] = name
    else
      -- The window name is known — now check the four coordinate values.
      local bad = false
      for _, field in ipairs({"x", "y", "w", "h"}) do
        local v = pos[field]
        -- A value is invalid if it's nil, not a number, or outside 0.0–1.0.
        if type(v) ~= "number" or v < 0.0 or v > 1.0 then
          bad = true
          break
        end
      end
      if bad then
        debugc("[MyDSL] LayoutEngine: bad saved position for " .. name .. " — resetting to default.")
        local d = MyDSL.Layout.defaults[name]
        MyDSL.Layout.positions[name] = { x=d.x, y=d.y, w=d.w, h=d.h }
      end
    end
  end

  -- Now actually remove the stale entries (safe to do outside the pairs loop).
  for _, name in ipairs(toRemove) do
    MyDSL.Layout.positions[name] = nil
  end
end


------------------------------------------------------------------------
-- SECTION 6: ACCESSORS — get(), set(), snapBack()
------------------------------------------------------------------------

-- get(windowName)
-- Returns the current {x, y, w, h} position table for a window.
-- If the window exists in defaults but has no saved position, returns the default.
-- If the window name is not recognised at all, returns nil.

function MyDSL.Layout.get(windowName)
  -- Check live positions first (may have been loaded from disk or set by user).
  if MyDSL.Layout.positions[windowName] then
    return MyDSL.Layout.positions[windowName]
  end
  -- Fall back to defaults (covers windows that haven't been saved yet).
  if MyDSL.Layout.defaults[windowName] then
    return MyDSL.Layout.defaults[windowName]
  end
  -- Window name is completely unknown.
  return nil
end

-- set(windowName, x, y, w, h)
-- Saves a new position for a window and writes it to disk.
-- Validates all values are numbers in 0.0–1.0 before saving.
-- Called by Layer 3 when the user drags or resizes a window.

function MyDSL.Layout.set(windowName, x, y, w, h)
  -- Validate: all four values must be numbers between 0.0 and 1.0.
  -- We check them in a loop so the error message can name the bad field.
  local values = { x=x, y=y, w=w, h=h }
  for field, val in pairs(values) do
    if type(val) ~= "number" or val < 0.0 or val > 1.0 then
      debugc(string.format(
        "[MyDSL] LayoutEngine: invalid value for %s.%s = %s (must be 0.0–1.0, got %s)",
        windowName, field, tostring(val), type(val)
      ))
      return  -- Abort — do not save bad data.
    end
  end

  -- Write into the live positions table.
  -- The 'or {}' guard here ensures we never crash if this window
  -- doesn't have an entry yet (new window added at runtime).
  MyDSL.Layout.positions[windowName] = MyDSL.Layout.positions[windowName] or {}
  MyDSL.Layout.positions[windowName].x = x
  MyDSL.Layout.positions[windowName].y = y
  MyDSL.Layout.positions[windowName].w = w
  MyDSL.Layout.positions[windowName].h = h

  -- Persist to disk immediately so the change survives a client restart.
  MyDSL.Layout.save()
end

-- snapBack(windowName)
-- Resets one window to its factory-default position and saves.
-- Called when a window ends up off-screen or the user requests a reset.

function MyDSL.Layout.snapBack(windowName)
  local d = MyDSL.Layout.defaults[windowName]
  if not d then
    debugc("[MyDSL] LayoutEngine: snapBack called for unknown window: " .. tostring(windowName))
    return
  end
  MyDSL.Layout.positions[windowName] = { x=d.x, y=d.y, w=d.w, h=d.h }
  MyDSL.Layout.save()
end


------------------------------------------------------------------------
-- SECTION 7: PIXEL MATH — applyToWindow() and isOnScreen()
------------------------------------------------------------------------
-- All positions are stored as fractions (0.0–1.0) of the screen.
-- Geyser's move() and resize() functions work in pixels.
-- So at the moment we actually reposition a window, we multiply
-- the fractions by the current screen size to get pixel values.
--
-- Conversion:
--   pixelX = fraction_x * screenWidth
--   pixelY = fraction_y * screenHeight
--   pixelW = fraction_w * screenWidth
--   pixelH = fraction_h * screenHeight
--
-- Example at 1920x1080:
--   x=0.66, y=0.00, w=0.34, h=0.30
--   → pixelX=1267, pixelY=0, pixelW=653, pixelH=324
--
-- getMainWindowSize() is a Mudlet API call that returns the current
-- width and height of the main Mudlet window in pixels.
-- It returns two values: width, height (in that order).
-- We call it fresh every time rather than caching it, because the
-- player may have resized the Mudlet window since the last call.

-- isOnScreen(windowName)
-- Returns true if the window's saved position fits entirely within
-- the current screen dimensions. Returns false if any part falls off-screen.
-- A false result means snapBack() should be called before applying.

function MyDSL.Layout.isOnScreen(windowName)
  local pos = MyDSL.Layout.get(windowName)
  if not pos then return false end

  -- Get current screen dimensions in pixels.
  local sw, sh = getMainWindowSize()

  -- Convert fractions to pixels.
  local px = pos.x * sw
  local py = pos.y * sh
  local pw = pos.w * sw
  local ph = pos.h * sh

  -- The window is on-screen only if its far edge doesn't exceed screen size
  -- and its near edge isn't negative.
  return px >= 0 and py >= 0 and (px + pw) <= sw and (py + ph) <= sh
end

-- applyToWindow(windowName, winObj)
-- Given a window name and a live Geyser window object, moves and resizes
-- the Geyser window to match the saved layout position.
-- Called by reflowAll() during resize events, and by File 3 at creation time.
--
-- winObj is a Geyser window object (Geyser.UserWindow, Geyser.MiniConsole, etc.).
-- All Geyser objects have :move(x, y) and :resize(w, h) methods that take pixels.

function MyDSL.Layout.applyToWindow(windowName, winObj)
  if not winObj then return end

  -- If the window has drifted off-screen (e.g. resolution changed),
  -- reset it to its default position before applying anything.
  if not MyDSL.Layout.isOnScreen(windowName) then
    debugc("[MyDSL] LayoutEngine: " .. windowName .. " is off-screen — snapping to default.")
    MyDSL.Layout.snapBack(windowName)
  end

  local pos = MyDSL.Layout.get(windowName)
  if not pos then return end

  -- Convert fractions to pixels using current screen dimensions.
  -- These local variables exist only inside this function call.
  local sw, sh = getMainWindowSize()
  local px = math.floor(pos.x * sw)
  local py = math.floor(pos.y * sh)
  local pw = math.floor(pos.w * sw)
  local ph = math.floor(pos.h * sh)

  -- math.floor() rounds down to the nearest integer.
  -- Geyser expects whole pixel values, not fractions.

  -- Apply the position and size to the Geyser window object.
  -- The order matters: resize first, then move.
  -- Some Geyser implementations recalculate internal layout on resize,
  -- and the move sets the final position after that recalculation.
  winObj:resize(pw, ph)
  winObj:move(px, py)
end

-- reflowAll(registry)
-- Called when the Mudlet window is resized (sysWindowResizeEvent).
-- Repositions every window in the registry to its saved percentage position.
--
-- registry is a table from MyDSL.Windows (File 3), structured as:
--   { windowName = { obj = geyserWindowObject, ... }, ... }
--
-- We receive registry as a PARAMETER rather than reading MyDSL.Windows directly.
-- This is intentional: Layout must not import from WindowRegistry because
-- WindowRegistry will import from Layout. If both tried to import each other
-- (circular dependency), the module that loads second would see an incomplete
-- version of the module that loaded first — subtle bugs, hard to trace.
-- Passing registry as a parameter breaks the circle cleanly.

function MyDSL.Layout.reflowAll(registry)
  -- If registry is nil or empty (e.g. File 3 hasn't loaded yet), this loop
  -- simply doesn't execute — no crash, no error.
  for windowName, entry in pairs(registry or {}) do
    if entry and entry.obj then
      MyDSL.Layout.applyToWindow(windowName, entry.obj)
    end
  end
end


------------------------------------------------------------------------
-- SECTION 8: EVENT HANDLER — sysWindowResizeEvent
------------------------------------------------------------------------
-- sysWindowResizeEvent fires every time the player resizes the Mudlet window.
-- We use this to reflow all windows back to their percentage-based positions.
--
-- registerAnonymousEventHandler() registers a Lua function to run when a
-- named event fires. It returns a numeric ID that we can use later to
-- cancel (deregister) the handler.
--
-- Why deregister on reload?
-- When you re-save a script, Mudlet re-runs the file from top to bottom.
-- If we don't deregister the old handler first, we end up with two handlers
-- both responding to sysWindowResizeEvent — and after a third reload, three,
-- and so on. Keeping the ID in _handlers and killing it before re-registering
-- keeps exactly one handler active at all times.

-- Kill the old handler if it exists (we're reloading).
if MyDSL.Layout._handlers.resize then
  killAnonymousEventHandler(MyDSL.Layout._handlers.resize)
  MyDSL.Layout._handlers.resize = nil
end

-- Register the new handler and store its ID.
MyDSL.Layout._handlers.resize = registerAnonymousEventHandler(
  "sysWindowResizeEvent",
  function()
    -- MyDSL.Windows may not exist yet if WindowRegistry hasn't loaded.
    -- The 'and ... or {}' pattern gives an empty table in that case,
    -- so reflowAll() runs safely with nothing to iterate over.
    MyDSL.Layout.reflowAll(
      MyDSL.Windows and MyDSL.Windows.registry or {}
    )
  end
)


------------------------------------------------------------------------
-- SECTION 9: STARTUP — load saved layout from disk
------------------------------------------------------------------------
-- load() is called here so that the moment this script runs,
-- the layout is restored from whatever the player last saved.
-- If no save file exists, this is a silent no-op and defaults are used.

MyDSL.Layout.load()


------------------------------------------------------------------------
-- LOAD CONFIRMATION
------------------------------------------------------------------------
debugc("[MyDSL] LayoutEngine loaded.")
