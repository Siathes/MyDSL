-- =============================================================================
-- MyDSL_WindowRegistry.lua  --  Layer 2, File 3 of 3: Window Registry
-- =============================================================================
-- This file creates and tracks all 20 UI windows.
-- It is the bridge between the abstract layout/theme data (Files 1 and 2)
-- and the live Geyser window objects that Mudlet actually draws.
--
-- LOAD ORDER: ThemeEngine must load first. LayoutEngine must load second.
--             This file loads third.
--
-- What this file owns:
--   - The central registry of all windows (their type, state, live object)
--   - Window creation on demand via ensure()
--   - Show/hide/toggle API
--   - Visibility state persistence across sessions
--
-- What this file does NOT own:
--   - Visual constants (ThemeEngine)
--   - Window positions (LayoutEngine)
--   - Window content / display logic (Layer 3, not yet written)
-- =============================================================================


------------------------------------------------------------------------
-- SECTION 1: NAMESPACE GUARDS
------------------------------------------------------------------------

MyDSL          = MyDSL          or {}
MyDSL.Windows  = MyDSL.Windows  or {}

-- _handlers holds IDs from registerAnonymousEventHandler so we can
-- deregister them cleanly when the script reloads.
MyDSL.Windows._handlers = MyDSL.Windows._handlers or {}


------------------------------------------------------------------------
-- SECTION 2: SAVE FILE PATH
------------------------------------------------------------------------
-- Visibility state (which windows are shown or hidden) is saved here.
-- Layout positions have their own file managed by LayoutEngine.
-- Using a local so it never leaks into the global environment.

local STATE_FILE = getMudletHomeDir() .. "/MyDSL_windowstate.lua"


------------------------------------------------------------------------
-- SECTION 3: PRIVATE HELPERS
------------------------------------------------------------------------
-- These are 'local function' — they exist only inside this file.
-- No other script can call them by name.
--
-- Why separate helpers instead of putting everything in ensure()?
--   1. Readability: ensure() stays focused on the creation sequence.
--      The pixel math and theme application are distinct concerns.
--   2. Reusability: applyTheme() is called both at creation time and
--      whenever the theme changes at runtime.
--   3. Testability: a short, focused function is easier to reason about
--      than one large function doing five different things.

-- pixelsFromLayout(windowName)
-- Reads the fractional position from LayoutEngine and converts to pixels
-- using the current screen size. Returns four integers: px, py, pw, ph.
-- Called by ensure() so the window is placed correctly the moment it is created.

local function pixelsFromLayout(windowName)
  local pos = MyDSL.Layout.get(windowName)
  if not pos then
    -- Unknown window or no layout entry — return a safe fallback position
    -- so the window at least appears somewhere visible.
    debugc("[MyDSL] WindowRegistry: no layout for " .. tostring(windowName) .. " — using fallback position.")
    return 100, 100, 300, 200
  end
  -- getMainWindowSize() returns the current Mudlet window size in pixels.
  -- Two return values — sw (screen width) and sh (screen height) — received
  -- into two local variables in one assignment. This is standard Lua style
  -- for functions that return multiple values.
  local sw, sh = getMainWindowSize()
  -- math.floor() rounds down to the nearest whole number.
  -- Geyser expects integer pixel values, not fractional ones.
  return math.floor(pos.x * sw),
         math.floor(pos.y * sh),
         math.floor(pos.w * sw),
         math.floor(pos.h * sh)
end

-- applyTheme(windowName, winObj)
-- Placeholder — visual theming is deferred to Layer 3.
-- Geyser.UserWindow and Adjustable.Container do not expose setStyleSheet.
-- Theme values (colors, fonts, borders) will be applied in Layer 3 when
-- MiniConsole and Label children are created inside each window frame.

local function applyTheme(windowName, winObj)
  -- Visual theming (stylesheet) is not available directly on
  -- Geyser.UserWindow or Adjustable.Container objects.
  -- Theming is applied in Layer 3 when MiniConsole/Label children
  -- are created inside each window. This function is a placeholder.
  return
end

-- applyBorders()
-- Reserves screen space for the three panel columns so Mudlet's main
-- console text does not overlap the side panels.
-- Percentages match the confirmed layout (Contract_WindowRegistry.md Gap 5):
--   23% left  — Location window + native Map/Scan/Combat dock
--   22% right  — Chat / History / Group / Affects column
--   21% bottom — full bottom strip (PlayersNear … RightHere)
-- Called at startup (ensureAll), on every resize (sysWindowResizeEvent),
-- and after loadWindowLayout() in onLogin() since a layout restore can
-- shift border state.

local function applyBorders()
  local sw, sh = getMainWindowSize()
  setBorderLeft(math.floor(sw * 0.23))
  setBorderRight(math.floor(sw * 0.22))
  setBorderBottom(math.floor(sh * 0.21))
  setBorderTop(0)
end


------------------------------------------------------------------------
-- SECTION 4: WINDOW REGISTRY
------------------------------------------------------------------------
-- The registry is a table of tables — one entry per window.
-- Each entry holds everything we need to know about a window's state:
--
--   obj     — the live Geyser window object, or nil if not created yet
--   type    — "UserWindow" (detachable) or "Container" (console-anchored)
--   visible — whether the window is currently shown (true) or hidden (false)
--   created — whether ensure() has already run for this window
--
-- We pre-populate all 20 entries here with placeholder values.
-- No windows are actually created at this point — that happens lazily
-- when ensure() is called (either by ensureAll() or by Layer 3 on demand).
--
-- The 'or {}' guard means: if the registry already exists in memory
-- (because the script was just reloaded), keep the live data intact —
-- including the real window objects stored in entry.obj.
-- Without the guard, every reload would set all obj fields to nil,
-- making the registry think windows haven't been created yet.

MyDSL.Windows.registry = MyDSL.Windows.registry or {

  -- ---- UserWindows (Geyser.UserWindow — can be detached to second monitor) --

  MyDSL_Chat             = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_Affects          = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_Portrait         = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_Location         = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_Live             = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_Tick             = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_Combat           = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_History          = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_Scan             = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_Group            = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_Target           = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_RightHere        = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_PlayersNear      = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_CreatureReference= { obj=nil, type="UserWindow", visible=false, created=false },

  MyDSL_Inventory        = { obj=nil, type="UserWindow", visible=false, created=false },  -- hidden by default; toggled by inv command
  MyDSL_Equipment        = { obj=nil, type="UserWindow", visible=false, created=false },  -- hidden by default; toggled by eq command

  -- ---- Adjustable.Container windows (anchored inside the main Mudlet console) --

  MyDSL_MoonWeather      = { obj=nil, type="Container",  visible=true,  created=false },
  MyDSL_AsciiMap         = { obj=nil, type="Container",  visible=false, created=false },
  MyDSL_Banner           = { obj=nil, type="Container",  visible=false, created=false },  -- hidden until content arrives
  MyDSL_Bloodbath        = { obj=nil, type="Container",  visible=false, created=false },  -- hidden until content arrives
}


------------------------------------------------------------------------
-- SECTION 5: GET API
------------------------------------------------------------------------

-- get(windowName)
-- Returns the live Geyser window object for a named window, or nil.
-- This is the primary API for Layer 3 — all UI code calls this to get
-- the window object it needs to write content into.
--
-- Layer 3 does NOT interact with the registry directly — it calls get().
-- This keeps Layer 3 isolated from registry internals. If we ever change
-- how the registry is structured, only this function needs updating.

function MyDSL.Windows.get(windowName)
  local entry = MyDSL.Windows.registry[windowName]
  -- 'not entry' is true when entry is nil (window name not recognised).
  if not entry then return nil end
  -- entry.obj is nil if ensure() hasn't been called yet.
  return entry.obj
end


------------------------------------------------------------------------
-- SECTION 6: ENSURE — lazy window creation
------------------------------------------------------------------------

-- ensure(windowName)
-- Creates a window the first time it is needed. If the window already
-- exists (created == true), returns the existing object immediately.
--
-- Why lazy creation instead of creating all windows at load time?
-- Two reasons:
--   1. Some windows (Inventory, Equipment, Mapper) may never be needed
--      in a given session. Creating them upfront wastes memory and
--      Mudlet rendering resources for windows that stay hidden.
--   2. Load order safety: if ThemeEngine or LayoutEngine aren't ready
--      yet, ensure() can't run safely. Deferring creation to first use
--      (which always happens after all scripts have loaded) avoids the
--      problem entirely.
--
-- ensure() returns the window object so callers can use it immediately:
--   local win = MyDSL.Windows.ensure("MyDSL_Chat")

function MyDSL.Windows.ensure(windowName)
  local entry = MyDSL.Windows.registry[windowName]
  if not entry then
    debugc("[MyDSL] WindowRegistry: ensure() called for unknown window: " .. tostring(windowName))
    return nil
  end

  -- Already created — return the live object without doing anything else.
  -- 'entry.obj' will be the Geyser object set at creation time.
  if entry.created and entry.obj then
    return entry.obj
  end

  -- Get pixel position for the constructor.
  local px, py, pw, ph = pixelsFromLayout(windowName)

  -- ---- CREATE THE WINDOW ----
  --
  -- Geyser.UserWindow:new() and Adjustable.Container:new() use Lua's
  -- class/method system. Here is how that works:
  --
  -- In Lua there are no built-in classes. Instead, tables act as classes
  -- and objects. When you write:
  --   Geyser.UserWindow:new({ name="MyDSL_Chat", ... })
  --
  -- The colon ':' is syntactic sugar for:
  --   Geyser.UserWindow.new(Geyser.UserWindow, { name="MyDSL_Chat", ... })
  --
  -- 'new' is just a regular function stored inside the Geyser.UserWindow
  -- table. The colon passes the table itself as the first argument (called
  -- 'self' inside the function). The 'new' function uses 'self' as a
  -- prototype/blueprint to create and return a new instance table.
  --
  -- The result — what new() returns — is a fresh table (the window object)
  -- that has all the same methods as the prototype, applied to its own data.
  -- When you later write:
  --   winObj:resize(pw, ph)
  -- Lua expands that to:
  --   winObj.resize(winObj, pw, ph)
  -- so 'resize' knows which specific window to act on.

  local winObj = nil

  if entry.type == "UserWindow" then
    -- Geyser.UserWindow creates a detachable panel window.
    -- The constructor table sets the initial position and size in pixels.
    -- name must match the registry key exactly — Mudlet uses it to identify
    -- the window internally.
    winObj = Geyser.UserWindow:new({
      name          = windowName,
      x             = px,
      y             = py,
      width         = pw,
      height        = ph,
      restoreLayout = true,
    })

  elseif entry.type == "Container" then
    -- Adjustable.Container creates a resizable panel anchored inside
    -- the main Mudlet console. Unlike UserWindow, it cannot be detached.
    -- In Mudlet 4.20+ this is built into the core — no extra package needed.
    winObj = Adjustable.Container:new({
      name   = windowName,
      x      = px,
      y      = py,
      width  = pw,
      height = ph,
    })
  end

  -- If creation failed for any reason, log and bail out.
  if not winObj then
    debugc("[MyDSL] WindowRegistry: FAILED to create " .. windowName)
    return nil
  end

  -- Apply background color, border, and other visual theme values.
  applyTheme(windowName, winObj)

  -- Let LayoutEngine take authoritative control of the final position.
  -- The constructor set an initial position above, but applyToWindow()
  -- recalculates from the saved percentage and snaps back if off-screen.
  MyDSL.Layout.applyToWindow(windowName, winObj)

  -- Record the live object and mark as created.
  entry.obj     = winObj
  entry.created = true

  -- Apply the loaded visibility state immediately.
  -- A window saved as hidden should be hidden from the moment it's created.
  if not entry.visible then
    winObj:hide()
  end

  debugc("[MyDSL] WindowRegistry: created " .. windowName)
  return winObj
end

-- ensureAll()
-- Creates all 20 windows in registry order.
-- Called once at startup after loadState() so every window exists before
-- Layer 3 tries to write content into any of them.

function MyDSL.Windows.ensureAll()
  debugc("[MyDSL] WindowRegistry: creating all windows...")
  for name, _ in pairs(MyDSL.Windows.registry) do
    MyDSL.Windows.ensure(name)
  end
  debugc("[MyDSL] WindowRegistry: all windows ready.")

  -- Set console borders now that all windows exist.
  applyBorders()

  -- Re-apply borders whenever the Mudlet window is resized.
  -- Kill any previous handler first so reloads don't stack duplicates.
  if MyDSL.Windows._resizeHandler then
    pcall(killAnonymousEventHandler, MyDSL.Windows._resizeHandler)
  end
  MyDSL.Windows._resizeHandler = registerAnonymousEventHandler(
    "sysWindowResizeEvent", function() applyBorders() end)
end


------------------------------------------------------------------------
-- SECTION 7: SHOW / HIDE / TOGGLE
------------------------------------------------------------------------

-- hide(windowName)
-- Hides a window. Creates it first if it hasn't been created yet
-- (we need the object to exist before we can hide it).
-- Saves state to disk so the hidden state persists across restarts.

function MyDSL.Windows.hide(windowName)
  local entry = MyDSL.Windows.registry[windowName]
  if not entry then return end

  -- Ensure the window object exists before trying to hide it.
  local winObj = entry.obj or MyDSL.Windows.ensure(windowName)
  if not winObj then return end

  winObj:hide()
  entry.visible = false
  MyDSL.Windows.saveState()
end

-- show(windowName)
-- Shows a window. Creates it first if it hasn't been created yet.

function MyDSL.Windows.show(windowName)
  local entry = MyDSL.Windows.registry[windowName]
  if not entry then return end

  local winObj = entry.obj or MyDSL.Windows.ensure(windowName)
  if not winObj then return end

  winObj:show()
  entry.visible = true
  MyDSL.Windows.saveState()
end

-- toggle(windowName)
-- Flips a window between visible and hidden.
-- The conditional 'if entry.visible then' checks the current state and
-- calls the appropriate direction. This is cleaner than XOR-ing a boolean
-- because it keeps show/hide logic in one place each.

function MyDSL.Windows.toggle(windowName)
  local entry = MyDSL.Windows.registry[windowName]
  if not entry then
    debugc("[MyDSL] WindowRegistry: toggle called for unknown window: " .. tostring(windowName))
    return
  end

  if entry.visible then
    MyDSL.Windows.hide(windowName)
  else
    MyDSL.Windows.show(windowName)
  end
end


------------------------------------------------------------------------
-- SECTION 8: STATE PERSISTENCE
------------------------------------------------------------------------

-- saveState()
-- Saves each window's visible boolean to disk.
-- We save only the visibility state, not the full registry.
-- The full registry contains live Geyser objects which cannot be
-- serialized — table.save() would either crash or write useless data
-- for those entries. Saving just the boolean is clean and sufficient.

function MyDSL.Windows.saveState()
  -- Build a plain string→boolean table to pass to table.save().
  local state = {}
  for name, entry in pairs(MyDSL.Windows.registry) do
    state[name] = entry.visible
  end
  table.save(STATE_FILE, state)
end

-- loadState()
-- Reads the visibility state from disk and applies it to the registry.
-- Called before ensureAll() so windows are created with the correct
-- visibility state rather than having to be hidden immediately after.
-- If no state file exists, all windows use their registry defaults
-- (most visible=true, Mapper/Inventory/Equipment/Banner/Bloodbath false).

function MyDSL.Windows.loadState()
  local f = io.open(STATE_FILE, "r")
  if not f then
    -- No saved state — use whatever is in the registry definition.
    return
  end
  f:close()

  local loaded = table.load(STATE_FILE)
  if type(loaded) ~= "table" then
    debugc("[MyDSL] WindowRegistry: state file unreadable — using defaults.")
    return
  end

  for name, visible in pairs(loaded) do
    local entry = MyDSL.Windows.registry[name]
    if entry then
      -- Update registry visibility from saved value.
      entry.visible = visible
      -- If the window object is already live (e.g. this is a mid-session
      -- reload rather than a fresh startup), apply show/hide immediately.
      if entry.obj then
        if visible then
          entry.obj:show()
        else
          entry.obj:hide()
        end
      end
    end
    -- Silently ignore any name from the file that isn't in the registry.
    -- This handles the case where a window was removed in a newer version.
  end
end


------------------------------------------------------------------------
-- SECTION 9: EVENT HANDLER — MyDSL.windows.toggle
------------------------------------------------------------------------
-- This handler lets triggers and aliases toggle windows without needing
-- a direct Lua reference to this module.
-- From any trigger or alias, you can write:
--   raiseEvent("MyDSL.windows.toggle", "MyDSL_Chat")
-- and this handler will call MyDSL.Windows.toggle("MyDSL_Chat").
--
-- The event name uses a dot-separated string by convention, matching the
-- MyDSL namespace style. Mudlet event names are just strings — any string
-- is valid.
--
-- Deregister pattern: see MyDSL_LayoutEngine.lua Section 8 for full
-- explanation. Short version: kill the old handler before registering
-- a new one, or each reload adds a duplicate.

if MyDSL.Windows._handlers.toggle then
  killAnonymousEventHandler(MyDSL.Windows._handlers.toggle)
  MyDSL.Windows._handlers.toggle = nil
end

MyDSL.Windows._handlers.toggle = registerAnonymousEventHandler(
  "MyDSL.windows.toggle",
  -- The anonymous function receives the event name as the first argument,
  -- then any additional arguments that were passed to raiseEvent().
  -- Here we only care about the second argument — the window name.
  function(event, windowName)
    if windowName then
      MyDSL.Windows.toggle(windowName)
    end
  end
)


------------------------------------------------------------------------
-- SECTION 10: CONSTRUCTOR PATCH + LAYOUT SAVE
------------------------------------------------------------------------
-- Patch Geyser.UserWindow.new so every UserWindow created by any module
-- automatically gets autoDock=true, even if the caller doesn't set it.
-- restoreLayout is intentionally NOT injected here — Mudlet's Geyser docs
-- warn that restoreLayout conflicts with explicit x/y/w/h at creation time.

local function patchUserWindowConstructor()
  if MyDSL.Windows._constructorPatched then return end
  if not (Geyser and Geyser.UserWindow) then return end
  local origNew = Geyser.UserWindow.new
  Geyser.UserWindow.new = function(self, cons, ...)
    cons = cons or {}
    -- autoDock=true is already Mudlet's default but harmless to set explicitly
    if cons.autoDock == nil then cons.autoDock = true end
    -- restoreLayout REMOVED — conflicts with x/y/w/h specified at creation
    -- per Mudlet Geyser docs and PR thread warning
    return origNew(self, cons, ...)
  end
  MyDSL.Windows._constructorPatched = true
end

-- saveLayout()
-- Saves the current Mudlet window layout for all windows.
-- Run after manually arranging windows: mydsl save layout

function MyDSL.Windows.saveLayout()
  if saveWindowLayout then
    saveWindowLayout()
    if saveProfile then saveProfile() end
    cecho("\n<green>[MyDSL] Layout saved.\n")
  end
end

tempAlias("^mydsl save layout$", "MyDSL.Windows.saveLayout()")


------------------------------------------------------------------------
-- SECTION 11: STARTUP SEQUENCE
------------------------------------------------------------------------
-- patchUserWindowConstructor() runs first — before any window is created —
-- so the patch is in place for ALL modules' UserWindow constructors.
-- loadState() runs second so the registry has correct visibility booleans.
-- ensureAll() creates all windows at LayoutEngine default positions.
-- saveWindowLayout() immediately after establishes a baseline so Mudlet
-- has something to restore even before the user manually arranges windows.
-- Two delayed timers call loadWindowLayout() to restore saved positions
-- after Mudlet has finished its own startup sequence.

patchUserWindowConstructor()
MyDSL.Windows.loadState()
MyDSL.Windows.ensureAll()
applyBorders()
saveWindowLayout()   -- baseline: windows at LayoutEngine default positions
saveProfile()        -- flush to disk immediately

tempTimer(1.0, function()
  if loadWindowLayout then loadWindowLayout() end
  applyBorders()
end)

tempTimer(3.0, function()
  if loadWindowLayout then loadWindowLayout() end
  applyBorders()
end)


------------------------------------------------------------------------
-- LOAD CONFIRMATION
------------------------------------------------------------------------
debugc("[MyDSL] WindowRegistry loaded. " .. tostring(table.getn and table.getn(MyDSL.Windows.registry) or 20) .. " windows registered.")
