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

-- DOCK_INIT_FILE / WINDOW_INITIAL_DOCK -- fixes the real "fresh profile:
-- every window piles up on the right" bug reported by Steven. Root cause
-- (traced into Mudlet's own C++ source, Host::openWindow()): a dock
-- widget that has NEVER existed before in this profile's history is
-- unconditionally created in Qt::RightDockWidgetArea, and Geyser's
-- UserWindow:new() never passes a dock-side argument through to the
-- native call when restoreLayout=true (which patchUserWindowConstructor()
-- always sets) -- so nothing ever tells it otherwise. Once a window is
-- manually dragged elsewhere, THIS profile's own native dock-state save
-- remembers it forever (dock widget object names are profile-scoped, so
-- this is not the cross-profile file collision an earlier investigation
-- pass wrongly suspected -- corrected in docs/CHANGELOG.md). The fix:
-- explicitly dock each window to the side LayoutEngine's own defaults
-- table already documents as its intended region (left/right/bottom
-- panel comments), but ONLY the very first time this profile ever
-- creates its windows -- gated by this one-line marker file so a later
-- restart never fights a since-customized arrangement.
local function DOCK_INIT_FILE()
  return getMudletHomeDir() .. "/MyDSL_dock_initialized.lua"
end

-- TITLES_FILE -- backs "mydsl layout titles <on|off>" (docs/TODO.md's
-- "UI: toggleable window titles / minimal borders, to maximize window
-- space" design idea). Profile-scoped like layout itself, not per-
-- character -- this is a chrome preference, same class as the layout
-- arrangement. Note the real API limit found while scoping this: Mudlet
-- exposes no way to hide the title BAR's physical space itself (that's
-- a native Qt QDockWidget property, not surfaced to Lua) -- only the
-- title TEXT (setTitle()/resetTitle(), already used here). "Minimal
-- borders" in the original ask isn't buildable at all for the same
-- reason border THICKNESS has no Lua-exposed setter either; this
-- delivers the text-hiding half only, not a border change.
local function TITLES_FILE()
  return getMudletHomeDir() .. "/MyDSL_titles_visible.lua"
end

local function isFirstDockInit()
  local f = io.open(DOCK_INIT_FILE(), "r")
  if f then f:close(); return false end
  return true
end

local function markDockInitialized()
  local f = io.open(DOCK_INIT_FILE(), "w")
  if f then
    f:write("-- marker only: initial per-window dock sides have been applied\n")
    f:write("-- for this profile. Delete this file to re-apply them once (e.g.\n")
    f:write("-- after 'mydsl layout reset') without fighting a manual rearrangement.\n")
    f:close()
  end
end

-- Matches MyDSL_LayoutEngine.lua's own "RIGHT PANEL"/"LEFT PANEL"/
-- "BOTTOM STRIP" section comments exactly. MyDSL_Help/MyDSL_Leveling are
-- deliberately omitted -- both are on-demand (visible=false), opened
-- rarely, so they don't contribute to the "20 windows crammed on open"
-- problem and Geyser's own default ("r") is fine for them.
local WINDOW_INITIAL_DOCK = {
  MyDSL_Chat              = "r",
  MyDSL_Affects           = "r",
  MyDSL_Tick              = "r",
  -- MyDSL_Alterform deliberately omitted: LayoutEngine's own "RIGHT PANEL
  -- (UserWindows)" comment groups it here, but its real DEFAULT_REGISTRY
  -- entry (this file) has type="Container", not "UserWindow" -- it's
  -- anchored inside the main console like MyDSL_MoonWeather, not a real
  -- dock widget, so a dock side doesn't apply. Caught by this fix's own
  -- test asserting real per-window sides rather than trusting the stale
  -- comment grouping.
  MyDSL_Group             = "r",
  MyDSL_CreatureReference = "r",
  MyDSL_Portrait          = "l",
  MyDSL_Location          = "l",
  MyDSL_ItemReference     = "l",
  MyDSL_Focus             = "l",
  MyDSL_RightHere         = "l",
  MyDSL_PlayersNear       = "l",
  MyDSL_Combat            = "b",
  MyDSL_History           = "b",
  MyDSL_Scan              = "b",
  MyDSL_Live              = "b",
}


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
-- Corrected 2026-07-11 (was a no-op placeholder claiming "Geyser.UserWindow
-- ... does not expose setStyleSheet" -- FALSE, confirmed against Mudlet's
-- real source: Geyser.UserWindow:setStyleSheet() exists and calls the
-- native setUserWindowStyleSheet(), documented as "Sets the style sheet of
-- the UserWindows (border and title area)" -- exactly what's needed here.
-- Adjustable.Container genuinely has no setStyleSheet of its own (that
-- half of the old comment was right) -- MyDSL_MoonWeather.lua, the one
-- Container-type window, styles its own full-bleed child Label instead.
--
-- This single call is what makes MyDSL.Theme.setTheme() actually reach
-- every UserWindow's border/radius/background at once, including the
-- windows that previously had no styling at all (Affects, Combat, Target,
-- Group, Scan, RightHere, PlayersNear, CreatureReference, History).
-- Inner MiniConsole/Label children still need their own fill color to
-- match (a MiniConsole paints its own background independently of its
-- parent UserWindow's stylesheet) -- see MyDSL.Theme.styleConsole(),
-- called from each Layer 3 view file's init().

local function applyTheme(windowName, winObj)
  if not winObj then return end
  if not (MyDSL.Theme and MyDSL.Theme.panelCSS) then return end
  local entry = MyDSL.Windows.registry[windowName]
  if entry and entry.type == "UserWindow" and winObj.setStyleSheet then
    -- Visual pass v2, "Direction A+" (locked spec, HANDOFF.md 2026-08-26):
    -- panelCSS's bare declarations theme the window's own frame; appending
    -- titleBarCSS's QDockWidget::title{} rule flattens the REAL native
    -- title bar to match (Linux-only rendering, confirmed via Mudlet's own
    -- Geyser manual -- harmless no-op elsewhere). This half alone changes
    -- no layout and touches no other file -- the cross-platform half (a
    -- themed header Label under the flattened bar) is a separate, larger
    -- per-window rollout, tracked in docs/MYDSL_1.0_ROADMAP.md.
    local css = MyDSL.Theme.panelCSS(windowName)
    if MyDSL.Theme.titleBarCSS then css = css .. " " .. MyDSL.Theme.titleBarCSS(windowName) end
    pcall(function() winObj:setStyleSheet(css) end)
  end
  -- Container-type windows (MoonWeather) have no setStyleSheet of their
  -- own; they theme their own child Label directly and are not touched here.
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

-- REAL BUG, found live 2026-07-19 (Steven: "that script blanks my main
-- window, i had to disable" -- right after MyDSL_Leveling.lua added a new
-- MyDSL_Leveling registry entry below): this table used to be built with
-- `MyDSL.Windows.registry = MyDSL.Windows.registry or { ...literal... }` --
-- if the registry ALREADY exists in memory (true for any in-session script
-- reload, not just a fresh Mudlet start -- confirmed elsewhere in this
-- codebase, see MyDSL_DataLayer.lua's SECTION 1 comment), the entire
-- right-hand literal is skipped, so a newly-added window key is silently
-- never registered until a full Mudlet restart. `MyDSL.Windows.ensure()`
-- then returns nil for that window name (unknown-window branch), and
-- MyDSL_Leveling.lua's ensureUI() passed that nil straight through as a
-- Geyser.MiniConsole's parent container -- Geyser attaches a parentless
-- console to the main window itself, at the requested 100%x100%, which is
-- exactly what blanked the screen. Fixed by merging new keys into an
-- already-existing registry instead of skipping the whole table --
-- existing entries (with their live .obj/.created state) are left alone,
-- and any window added after this fix survives an in-session reload with
-- no restart required.
local DEFAULT_REGISTRY = {

  -- ---- UserWindows (Geyser.UserWindow — can be detached to second monitor) --

  MyDSL_Chat             = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_Affects          = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_Portrait         = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_Location         = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_Live             = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_Tick             = { obj=nil, type="UserWindow", visible=true,  created=false },
  -- Changed to Container 2026-07-11, per Steven ("alterform window change
  -- to same as moonweather, we will keep it inside the main window for
  -- layout cleanness") -- was a detachable UserWindow like Tick; now
  -- anchored inside the main console like MyDSL_MoonWeather, whose own
  -- registry entry below is the model for this one.
  MyDSL_Alterform        = { obj=nil, type="Container",  visible=true,  created=false, lockStyle="padding" },
  MyDSL_Combat           = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_History          = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_Scan             = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_Group            = { obj=nil, type="UserWindow", visible=true,  created=false },
  -- Renamed from MyDSL_Target 2026-07-11, per Steven ("change target
  -- window to focus to match commands") -- registry key now matches the
  -- window's own title/command surface ("focus <verb>"); the Lua module
  -- (MyDSL.Target/MyDSL.TargetView) keeps its established internal name,
  -- same divergence MyDSL_CreatureReference already has (titled Bestiary).
  MyDSL_Focus            = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_RightHere        = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_PlayersNear      = { obj=nil, type="UserWindow", visible=true,  created=false },
  MyDSL_CreatureReference= { obj=nil, type="UserWindow", visible=false, created=false },
  -- On-demand reference window, same visible=false precedent as
  -- MyDSL_CreatureReference -- opened via "mydsl help" links or
  -- "mydsl help show", added 2026-07-15 (MyDSL_Help.lua).
  MyDSL_Help             = { obj=nil, type="UserWindow", visible=false, created=false },
  -- Layer 4, first slice (2026-07-16) -- on-demand reference window, same
  -- visible=false precedent as MyDSL_CreatureReference (Bestiary).
  MyDSL_ItemReference    = { obj=nil, type="UserWindow", visible=false, created=false },
  -- Leveling-assist addon (MyDSL_Leveling.lua, 2026-07-19) -- on-demand
  -- status/log window, same visible=false precedent as CreatureReference/
  -- Help/ItemReference. Note: unlike every other module in this registry,
  -- MyDSL_Leveling.lua sends real game commands -- an explicit, narrow
  -- exception (see that file's own header comment and docs/TODO.md's
  -- DECISIONS RECORDED section) -- but its window itself is just a plain
  -- status display, nothing different about its registry entry.
  MyDSL_Leveling         = { obj=nil, type="UserWindow", visible=false, created=false },

  -- ---- Adjustable.Container windows (anchored inside the main Mudlet console) --

  MyDSL_MoonWeather      = { obj=nil, type="Container",  visible=true,  created=false, lockStyle="padding" },
}

-- Merge, don't skip: preserves any already-live entry (with its real
-- .obj/.created state from a previous load) untouched, but still adds any
-- key from DEFAULT_REGISTRY that isn't present yet -- see the real-bug
-- comment above DEFAULT_REGISTRY for why this matters.
MyDSL.Windows.registry = MyDSL.Windows.registry or {}
for name, def in pairs(DEFAULT_REGISTRY) do
  if MyDSL.Windows.registry[name] == nil then
    MyDSL.Windows.registry[name] = def
  end
end


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

  -- First-ever-this-profile dock side -- see WINDOW_INITIAL_DOCK's own
  -- comment above for the full root-cause writeup. Cached once per
  -- session so this isn't a disk read on every single window creation.
  if MyDSL.Windows._applyInitialDock == nil then
    MyDSL.Windows._applyInitialDock = isFirstDockInit()
  end
  if MyDSL.Windows._applyInitialDock and entry.type == "UserWindow" then
    local side = WINDOW_INITIAL_DOCK[windowName]
    if side then pcall(winObj.setDockPosition, winObj, side) end
  end

  -- Record the live object and mark as created.
  entry.obj     = winObj
  entry.created = true

  -- Apply the loaded visibility state immediately.
  -- A window saved as hidden should be hidden from the moment it's created.
  if not entry.visible then
    winObj:hide()
  end

  -- Apply the current title-visibility preference immediately, same
  -- precedent as the visibility block right above -- a freshly-created
  -- window should already match whatever the user last chose, not need
  -- a second "mydsl layout titles" call to catch up.
  if entry.type == "UserWindow" and MyDSL.Windows.titlesVisible == false then
    pcall(function() winObj:setTitle("") end)
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
  -- Write the marker only after a real first-run pass actually happened,
  -- so this profile's windows never get force-docked again on a later
  -- restart, even if the user has since dragged something elsewhere.
  if MyDSL.Windows._applyInitialDock then
    markDockInitialized()
    MyDSL.Windows._applyInitialDock = false
  end
  debugc("[MyDSL] WindowRegistry: all windows ready.")
end


-- loadTitlesVisible() -- reads the persisted preference, defaulting to
-- true (titles shown) when nothing has been saved yet, matching every
-- other "or default" pattern in this file.
function MyDSL.Windows.loadTitlesVisible()
  MyDSL.Windows.titlesVisible = true
  local f = io.open(TITLES_FILE(), "r")
  if not f then return end
  f:close()
  local loaded = {}
  local ok = pcall(table.load, TITLES_FILE(), loaded)
  if ok and loaded.visible ~= nil then
    MyDSL.Windows.titlesVisible = loaded.visible
  end
end

function MyDSL.Windows.saveTitlesVisible()
  pcall(table.save, TITLES_FILE(), { visible = MyDSL.Windows.titlesVisible })
end

-- setTitlesVisible(visible) -- "mydsl layout titles <on|off>". Applies
-- immediately to every already-created UserWindow (Adjustable.Container
-- windows have no title bar at all, so type=="UserWindow" only) via
-- Geyser's own setTitle("")/resetTitle() -- reused, not reimplemented.
function MyDSL.Windows.setTitlesVisible(visible)
  MyDSL.Windows.titlesVisible = visible
  for _, entry in pairs(MyDSL.Windows.registry) do
    if entry.type == "UserWindow" and entry.obj then
      if visible then
        pcall(function() entry.obj:resetTitle() end)
      else
        pcall(function() entry.obj:setTitle("") end)
      end
    end
  end
  MyDSL.Windows.saveTitlesVisible()
end

MyDSL.Windows.loadTitlesVisible()

if not MyDSL.Windows._titlesAliasInstalled then
  tempAlias([[^mydsl layout titles (on|off)$]], function()
    MyDSL.Windows.setTitlesVisible(matches[2] == "on")
    cecho("\n<green>[MyDSL] Window titles " .. (matches[2] == "on" and "shown" or "hidden") .. ".\n")
  end)
  MyDSL.Windows._titlesAliasInstalled = true
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

-- REAL BUG, found live 2026-07-11: Mudlet's real table.load(file, target)
-- does not return anything -- it unpickles INTO an explicit second-
-- argument table (confirmed in Mudlet's own bundled source). This used
-- to call table.load(STATE_FILE()) with no second argument, so `loaded`
-- was always nil and saved window visibility never actually survived a
-- restart (same bug found across ~10 call sites project-wide the same
-- day -- see MyDSL_DataLayer.lua's MyDSL.load() for the full writeup).
function MyDSL.Windows.loadState()
  local f = io.open(STATE_FILE(), "r")
  if not f then
    -- No saved state — use whatever is in the registry definition.
    return
  end
  f:close()

  local loaded = {}
  local ok = pcall(table.load, STATE_FILE(), loaded)
  if not ok or not next(loaded) then
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
-- SECTION 8b: FONT-SIZE PERSISTENCE (profile-level, not character-bound)
------------------------------------------------------------------------
-- Added 2026-07-11, per Steven ("the fonts should be saving like theme or
-- window manager whatever tracks that... per profile not user, remember
-- for the layout") -- consolidates what used to be N independent
-- per-module bespoke font config files (MyDSL_TargetView.lua's own
-- targetview_config_<Char>.lua, MyDSL_RouteHelper.lua's own
-- history_font_<Char>.lua) into ONE shared file here, matching exactly
-- how MyDSL_ThemeEngine.lua's active theme and LayoutEngine's window
-- layout already work: a single flat file, loaded once, unconditionally,
-- with no character-name resolution involved at all.
--
-- Real motivation, not just consistency: both of the old per-module
-- implementations already had the standard "re-load once MyDSL.character.
-- identified fires" pattern (confirmed structurally identical to
-- MyDSL_ChatWrapper.lua's own, which IS confirmed working) -- but Steven
-- twice reported the font settings still not surviving a reload even
-- after that fix, and a root cause was never conclusively found despite
-- extensive testing (see docs/CHANGELOG.md, "Round 10"). Removing the
-- character-name dependency entirely removes the whole class of timing
-- bug being chased, whether or not that was really the cause.

local function FONT_FILE()
  return getMudletHomeDir() .. "/MyDSL_windowfonts.lua"
end

MyDSL.Windows.fontSizes = MyDSL.Windows.fontSizes or {}

-- REAL BUG, found live 2026-07-11 (Steven's direct question: "are the
-- settings loading at creating from save files or they saving and never
-- reading/updating?" -- confirmed via the new 3-way diagnostic showing
-- disk=nil despite the file genuinely having the right data on disk).
-- Root cause: Mudlet's real table.load(file, target) does not return
-- anything -- confirmed directly in Mudlet's own bundled source
-- (mudlet-lua/lua/Other.lua): no return statement, it unpickles INTO an
-- explicit second-argument table (or into _G if none given). This
-- called table.load(FONT_FILE()) with no second argument, so `loaded`
-- was always nil, and the "ok and type(loaded)=='table'" check was
-- always false -- MyDSL.Windows.fontSizes never actually got the saved
-- data, ever, despite the file itself always being written correctly.
-- Same bug found across ~10 call sites project-wide the same day -- see
-- MyDSL_DataLayer.lua's MyDSL.load() for the full writeup, and PNP's own
-- DSL_PNP_Data.lua / EMCO's own emco.lua for confirmation this
-- second-argument form is the real, correct, already-proven-in-the-wild
-- usage.
function MyDSL.Windows.loadFontSizes()
  local f = io.open(FONT_FILE(), "r")
  if not f then return end
  f:close()
  local loaded = {}
  local ok = pcall(table.load, FONT_FILE(), loaded)
  if ok and next(loaded) then
    MyDSL.Windows.fontSizes = loaded
  else
    debugc("[MyDSL] WindowRegistry: font-size file exists but failed to load")
  end
end

function MyDSL.Windows.saveFontSizes()
  local ok = pcall(table.save, FONT_FILE(), MyDSL.Windows.fontSizes)
  if not ok then
    debugc("[MyDSL] WindowRegistry: failed to save font sizes to " .. FONT_FILE())
  end
  return ok
end

-- getFontSize(windowName, default) -- returns the persisted size, or
-- `default` if this window has never had one saved.
function MyDSL.Windows.getFontSize(windowName, default)
  return MyDSL.Windows.fontSizes[windowName] or default
end

-- setFontSize(windowName, size) -- updates the in-memory table AND
-- persists immediately (matching setTheme()'s save-on-every-change
-- behavior, not a manual "save" step). Does NOT touch any live widget --
-- callers still own applying the size to their own console/label, this
-- only owns remembering the value.
function MyDSL.Windows.setFontSize(windowName, size)
  MyDSL.Windows.fontSizes[windowName] = size
  MyDSL.Windows.saveFontSizes()
end

-- enableAdaptiveWrap(consoleObj) -- shared wrap-enable step, extracted
-- 2026-07-18 after a /ultrareview found the same enableAutoWrap()-after-
-- setFontSize()-plus-guard sequence hand-copied into MyDSL_ItemReference.lua,
-- MyDSL_CreatureReference.lua, and MyDSL_TargetView.lua, each with its own
-- ad hoc module-level guard flag (IR._autoWrapSet/CR._autoWrapSet/
-- TV._autoWrapSet) -- and two of those three copies then shipped a real bug
-- (ItemReference/CreatureReference's rebuild() nulled the console to force
-- recreation but never reset the module-level flag, so the recreated
-- console never got enableAutoWrap() called on it again). Storing the
-- guard ON THE CONSOLE OBJECT ITSELF instead of the owning module fixes
-- the whole bug class structurally, not per rebuild() call site: a freshly
-- created Geyser.MiniConsole naturally has no _autoWrapSet field yet, so
-- rebuild()/recreation paths need no special-case reset at all. Must be
-- called AFTER the console's real font size is applied -- enableAutoWrap()
-- computes its wrap column from the console's font at the moment it's
-- called (confirmed via MyDSL_RouteHelper.lua's own comment sourcing
-- Mudlet's GeyserMiniConsole.lua), so calling it before a font resize
-- would lock in the wrong wrap width, same as the original bug this whole
-- fix started from.
function MyDSL.Windows.enableAdaptiveWrap(consoleObj)
  if not consoleObj or consoleObj._autoWrapSet or not consoleObj.enableAutoWrap then return end
  pcall(function() consoleObj:enableAutoWrap() end)
  consoleObj._autoWrapSet = true
end

MyDSL.Windows.loadFontSizes()

echo("[MyDSL] WindowRegistry: font sizes loaded from " .. FONT_FILE() .. " (" ..
  tostring((function() local n=0 for _ in pairs(MyDSL.Windows.fontSizes) do n=n+1 end return n end)()) ..
  " windows).\n")


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

-- Re-apply border/radius/background to every already-created UserWindow
-- when the active theme switches ("theme set <name>" or setOverride()).
-- Added 2026-07-11 alongside named ThemeEngine presets.
if MyDSL.Windows._handlers.themeChanged then
  pcall(killAnonymousEventHandler, MyDSL.Windows._handlers.themeChanged)
  MyDSL.Windows._handlers.themeChanged = nil
end
MyDSL.Windows._handlers.themeChanged = registerAnonymousEventHandler(
  "MyDSL.theme.changed",
  function()
    for name, entry in pairs(MyDSL.Windows.registry) do
      if entry.obj then applyTheme(name, entry.obj) end
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

-- Simplified 2026-07-08, per Steven: the custom capture-into-percentages-
-- and-write-our-own-file approach (previously Steps 1-2 here) is dropped
-- in favor of just Mudlet's own native saveWindowLayout()/saveProfile() --
-- "its not woking right and i dont want to have that fight again." Layout
-- persistence is per-profile now (native Qt dock-state save, not
-- per-character), matching restoreLayout=true/autoDock=true already
-- patched onto every window in patchUserWindowConstructor().
function MyDSL.Windows.saveLayout()
  if saveWindowLayout then saveWindowLayout() end
  if saveProfile then saveProfile() end
  cecho("\n<green>[MyDSL] Layout saved.\n")
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
    MyDSL.Windows.loadState()
    for name, entry in pairs(MyDSL.Windows.registry) do
      if entry.visible then MyDSL.Windows.show(name) else MyDSL.Windows.hide(name) end
    end
  end
)


------------------------------------------------------------------------
-- LOAD CONFIRMATION
------------------------------------------------------------------------
debugc("[MyDSL] WindowRegistry loaded. " .. tostring((function() local n=0 for _ in pairs(MyDSL.Windows.registry) do n=n+1 end return n end)()) .. " windows registered.")
