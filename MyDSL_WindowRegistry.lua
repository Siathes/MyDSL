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

-- Safe-reload: kill any handler from a previous load before re-registering.
if MyDSL.Windows._handlers.characterIdentified then
  pcall(killAnonymousEventHandler, MyDSL.Windows._handlers.characterIdentified)
  MyDSL.Windows._handlers.characterIdentified = nil
end

if MyDSL.Windows._handlers.resizeAutoSave then
  pcall(killAnonymousEventHandler, MyDSL.Windows._handlers.resizeAutoSave)
  MyDSL.Windows._handlers.resizeAutoSave = nil
end

MyDSL.Windows.config = MyDSL.Windows.config or {}
if MyDSL.Windows.config.autoSaveLayout == nil then MyDSL.Windows.config.autoSaveLayout = true end

------------------------------------------------------------------------
-- Layout auto-save -- added 2026-07-08, per Steven.
------------------------------------------------------------------------
-- A prior (Claude.ai-era) attempt at this caused docking problems -- the
-- likely failure mode: Mudlet's own sysWindowResizeEvent fires on EVERY
-- dock/undock geometry change, not just a genuine user drag (already
-- documented in MyDSL_LayoutEngine.lua's own SECTION 8 comment: "docking
-- a UserWindow fires sysWindowResizeEvent"), so saving/reflowing directly
-- off that event captures transient mid-operation geometry and can fight
-- the user or corrupt the saved layout. Two safeguards here:
--   1. Suppression window (MyDSL.suppressLayoutAutoSave(seconds)) -- any
--      code that programmatically repositions windows (boot, a
--      character-identified reflow, "mydsl layout reset") calls this
--      first, so resize events fired by OUR OWN code don't get captured
--      as if they were a user drag.
--   2. Debounce -- a resize event schedules a save ~2s in the future,
--      restarting the timer on every further event, so a flurry of dock
--      events (or an in-progress drag) settles before anything is
--      actually captured/written -- only the final, quiet state gets
--      saved, never a mid-drag position.
-- Shared on the base MyDSL table (not MyDSL.Windows/MyDSL.Layout)
-- specifically so LayoutEngine can call it too without ever depending on
-- WindowRegistry internals (see LayoutEngine's own file-header rule).
function MyDSL.suppressLayoutAutoSave(seconds)
  MyDSL._layoutAutoSaveSuppressUntil = os.time() + (tonumber(seconds) or 2)
end

local function layoutAutoSaveSuppressed()
  return os.time() < (MyDSL._layoutAutoSaveSuppressUntil or 0)
end

local function scheduleLayoutAutoSave()
  if not MyDSL.Windows.config.autoSaveLayout then return end
  if layoutAutoSaveSuppressed() then return end
  if MyDSL.Windows._autoSaveTimerId then
    pcall(killTimer, MyDSL.Windows._autoSaveTimerId)
    MyDSL.Windows._autoSaveTimerId = nil
  end
  MyDSL.Windows._autoSaveTimerId = tempTimer(2, function()
    MyDSL.Windows._autoSaveTimerId = nil
    if MyDSL.Windows.config.autoSaveLayout and not layoutAutoSaveSuppressed() then
      MyDSL.Windows.saveLayout(true)
    end
  end)
end

MyDSL.Windows._handlers.resizeAutoSave = registerAnonymousEventHandler(
  "sysWindowResizeEvent",
  scheduleLayoutAutoSave
)

if not MyDSL.Windows._autosaveAliasInstalled then
  tempAlias("^mydsl layout autosave (on|off)$", function()
    MyDSL.Windows.config.autoSaveLayout = (matches[2] == "on")
    cecho("\n<green>[MyDSL] Layout auto-save: " .. matches[2] .. "\n")
  end)
  MyDSL.Windows._autosaveAliasInstalled = true
end


------------------------------------------------------------------------
-- SECTION 2: SAVE FILE PATH
------------------------------------------------------------------------
-- Visibility state (which windows are shown or hidden) is saved here.
-- Layout positions have their own file managed by LayoutEngine.
-- Using a local so it never leaks into the global environment.

-- Character-bound as of 2026-07-07 (was a single shared file) -- matches
-- the project's recorded decision that all settings should be
-- character-bound. Computed fresh on each call (not a fixed local) since
-- gmcp.login_data may not be populated yet at script-load time, before login.
local function stateCharName()
  if gmcp and gmcp.login_data and gmcp.login_data.name and gmcp.login_data.name ~= "" then
    return tostring(gmcp.login_data.name)
  end
  if MyCore and MyCore.getChar then
    local ok, name = pcall(MyCore.getChar)
    if ok and name and name ~= "" then return tostring(name) end
  end
  return "Unknown"
end

local function stateSafeFileName(s)
  s = tostring(s or "Unknown"):gsub("[^%w_%-%.]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if s == "" then s = "Unknown" end
  return s
end

local function STATE_FILE()
  return getMudletHomeDir() .. "/MyDSL_windowstate_" .. stateSafeFileName(stateCharName()) .. ".lua"
end


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

-- percentsFromLayout(windowName)
-- Reads the fractional position from LayoutEngine and converts to Geyser
-- percentage strings ("78%"). Used for UserWindow construction — percentage
-- strings are the correct Geyser constraint format and do not conflict with
-- restoreLayout=true (unlike post-construction applyToWindow() calls).

local function percentsFromLayout(windowName)
  local pos = MyDSL.Layout.get(windowName)
  if not pos then
    debugc("[MyDSL] WindowRegistry: no layout for "
      .. tostring(windowName) .. " — using fallback position.")
    return "5%", "5%", "35%", "30%"
  end
  local function pct(v)
    return tostring(math.floor((v or 0) * 100)) .. "%"
  end
  return pct(pos.x), pct(pos.y), pct(pos.w), pct(pos.h)
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

  -- ---- Adjustable.Container windows (anchored inside the main Mudlet console) --

  MyDSL_MoonWeather      = { obj=nil, type="Container",  visible=true,  created=false, lockStyle="padding" },
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
--   1. Some windows (CreatureReference, Mapper) may never be needed
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

  -- ---- CREATE THE WINDOW ----

  local winObj = nil

  if entry.type == "UserWindow" then
    -- Use LayoutEngine percentage positions as the initial placement.
    -- On a dock reset Mudlet returns windows here, not to a random corner.
    -- restoreLayout=true and autoDock=true injected by constructor patch.
    local px, py, pw, ph = percentsFromLayout(windowName)
    winObj = Geyser.UserWindow:new({
      name   = windowName,
      x      = px,
      y      = py,
      width  = pw,
      height = ph,
    })

  elseif entry.type == "Container" then
    -- Adjustable.Container creates a resizable panel anchored inside
    -- the main Mudlet console. Unlike UserWindow, it cannot be detached.
    -- In Mudlet 4.20+ this is built into the core — no extra package needed.
    local px, py, pw, ph = pixelsFromLayout(windowName)
    winObj = Adjustable.Container:new({
      name      = windowName,
      x         = px,
      y         = py,
      width     = pw,
      height    = ph,
      lockStyle = entry.lockStyle,  -- nil = Mudlet default; "padding" = invisible resize handles
    })
  end

  -- If creation failed for any reason, log and bail out.
  if not winObj then
    debugc("[MyDSL] WindowRegistry: FAILED to create " .. windowName)
    return nil
  end

  -- Apply background color, border, and other visual theme values.
  applyTheme(windowName, winObj)

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
  local ok = pcall(table.save, STATE_FILE(), state)
  if not ok then
    debugc("[MyDSL] WindowRegistry: failed to save window state to " .. STATE_FILE())
  end
  return ok
end

-- loadState()
-- Reads the visibility state from disk and applies it to the registry.
-- Called before ensureAll() so windows are created with the correct
-- visibility state rather than having to be hidden immediately after.
-- If no state file exists, all windows use their registry defaults
-- (most visible=true, Mapper/CreatureReference false).

function MyDSL.Windows.loadState()
  local f = io.open(STATE_FILE(), "r")
  if not f then
    -- No saved state — use whatever is in the registry definition.
    return
  end
  f:close()

  local loaded = table.load(STATE_FILE())
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
-- SECTION 10: CONSTRUCTOR PATCH
------------------------------------------------------------------------
-- Patch Geyser.UserWindow.new so every UserWindow created by any module
-- automatically gets restoreLayout=true and autoDock=true.
-- restoreLayout=true tells Mudlet to persist each window's position natively.
-- autoDock=true allows docking to Mudlet's panel system.

local function patchUserWindowConstructor()
  if MyDSL.Windows._constructorPatched then return end
  if not (Geyser and Geyser.UserWindow) then return end
  local origNew = Geyser.UserWindow.new
  Geyser.UserWindow.new = function(self, cons, ...)
    cons = cons or {}
    if cons.restoreLayout == nil then cons.restoreLayout = true end
    if cons.autoDock == nil then cons.autoDock = true end
    return origNew(self, cons, ...)
  end
  MyDSL.Windows._constructorPatched = true
end

function MyDSL.Windows.saveLayout(silent)
  -- Step 1: capture current positions from live Geyser objects
  local sw, sh = getMainWindowSize()
  if sw and sh and sw > 0 and sh > 0 then
    for name, entry in pairs(MyDSL.Windows.registry) do
      if entry.obj then
        local ok, x, y, w, h = pcall(function()
          return entry.obj:get_x(), entry.obj:get_y(),
                 entry.obj:get_width(), entry.obj:get_height()
        end)
        if ok and x then
          MyDSL.Layout.set(name, x/sw, y/sh, w/sw, h/sh)
        end
      end
    end
    -- Step 2: save LayoutEngine positions to disk
    if MyDSL.Layout.save then MyDSL.Layout.save() end
  end
  -- Step 3: save Qt dock state
  if saveWindowLayout then saveWindowLayout() end
  if saveProfile then saveProfile() end
  -- silent=true for auto-save, so a settled drag doesn't spam the console --
  -- manual "mydsl layout save" still gives visible confirmation.
  if not silent then cecho("\n<green>[MyDSL] Layout saved.\n") end
end

if not MyDSL.Windows._saveAliasInstalled then
  tempAlias("^mydsl layout save$", function()
    MyDSL.Windows.saveLayout()
  end)
  MyDSL.Windows._saveAliasInstalled = true
end

-- "mydsl layout reset" -- added 2026-07-07 alongside MyDSL.Layout.resetAll()
-- (closes the confirmed LOW PRIORITY "resetAll() does not exist" gap).
-- Resets in-memory positions to defaults and reflows all windows, but
-- does not persist until "mydsl layout save" is run afterward -- same
-- explicit-save convention as every other layout change.
if not MyDSL.Windows._resetAliasInstalled then
  tempAlias("^mydsl layout reset$", function()
    if MyDSL.Layout and MyDSL.Layout.resetAll then
      MyDSL.suppressLayoutAutoSave(2)
      MyDSL.Layout.resetAll()
      if MyDSL.Layout.reflowAll then MyDSL.Layout.reflowAll(MyDSL.Windows.registry) end
      cecho("\n<green>[MyDSL] Layout reset to defaults (run 'mydsl layout save' to persist).\n")
    end
  end)
  MyDSL.Windows._resetAliasInstalled = true
end


------------------------------------------------------------------------
-- SECTION 11: STARTUP SEQUENCE
------------------------------------------------------------------------
-- patchUserWindowConstructor() injects restoreLayout=true + autoDock=true.
-- ensureAll() creates all windows. loadWindowLayout() is called immediately
-- after — all windows exist at this point so there is no race condition.
-- No timers: timers fight the user by snapping windows back mid-session.
-- To persist a layout: run "mydsl layout save".

-- Suppress layout auto-save during the whole boot dock/create cascade --
-- see the auto-save comment near the top of this file.
MyDSL.suppressLayoutAutoSave(3)
patchUserWindowConstructor()
MyDSL.Windows.loadState()
MyDSL.Windows.ensureAll()
if loadWindowLayout then loadWindowLayout() end

-- Re-load once the real character is known -- fixed 2026-07-07. loadState()
-- above runs at script-boot time, which on a genuinely fresh Mudlet start
-- happens before login, so it loads "Unknown"'s visibility state (or bare
-- defaults) and would otherwise never pick up this character's real saved
-- state. MyDSL_DataLayer.lua's gmcp.login_data handler raises
-- "MyDSL.character.identified" once the real name is known; re-load and
-- apply visibility to whatever windows already exist (loadState() only
-- updates the registry's `visible` field, it doesn't touch already-created
-- window objects, so show()/hide() are called explicitly here).
MyDSL.Windows._handlers.characterIdentified = registerAnonymousEventHandler(
  "MyDSL.character.identified",
  function()
    MyDSL.suppressLayoutAutoSave(2)
    MyDSL.Windows.loadState()
    for name, entry in pairs(MyDSL.Windows.registry) do
      if entry.visible then MyDSL.Windows.show(name) else MyDSL.Windows.hide(name) end
    end
  end
)


------------------------------------------------------------------------
-- LOAD CONFIRMATION
------------------------------------------------------------------------
debugc("[MyDSL] WindowRegistry loaded. " .. tostring(table.getn and table.getn(MyDSL.Windows.registry) or 20) .. " windows registered.")
