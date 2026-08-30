-- =============================================================================
-- MyDSL_GroupView.lua  --  Layer 3 Phase B: Group member display window
-- =============================================================================
-- Passive display only. Listens for "MyDSL.group.updated" and renders one
-- window (MyDSL_Group) showing all group members with class, name, and
-- HP/mana/mv bars. Never sends commands.
--
-- DataLayer Section 9i parses the group block and emits "MyDSL.group.updated".
-- The catch-all body trigger in beginGroup() delegates body-line gagging to
-- MyDSL.GroupView.config.gagGroup so this module doesn't need its own body
-- trigger — only the header line needs a separate gag trigger here.
-- =============================================================================

MyDSL         = MyDSL         or {}
MyDSL.GroupView = MyDSL.GroupView or {}
local GV = MyDSL.GroupView

-- Safe-reload: kill old handlers and triggers before re-registering.
-- Done at module scope (not inside init) so dofile() reloads always start clean.
for _, id in pairs(GV._handlers or {}) do pcall(killAnonymousEventHandler, id) end
for _, id in pairs(GV._triggers or {}) do pcall(killTrigger, id) end

GV._handlers = {}
GV._triggers = {}
GV._mc       = GV._mc or {}   -- persists across reloads to avoid duplicate MiniConsole creation
GV.config    = GV.config or { gagGroup = false }
GV.config.quickActions = GV.config.quickActions or {"heal", "rescue"}

-- Deliberately a fresh literal every load, not "GV.defaults or {...}" --
-- same reasoning as MyDSL_TargetView.lua's TV.defaults (see that file's
-- comment): GV persists across reloads, so an or-pattern here would risk
-- "reset" restoring an already-customized value instead of the true
-- original default.
GV.defaults = { quickActions = {"heal", "rescue"} }

-- Window and MiniConsole name constants.
local GROUP_WIN = "MyDSL_Group"
local GROUP_MC  = "MyDSL_Group_MC"

-- Mirrors the Group window's text into MyDSL/logs/group/ (2026-07-05:
-- Mudlet's startLogging() can't capture MiniConsole content at all).
local function gvLog(mc, text)
  mc:decho(text)
  if MyDSL.logWindow then MyDSL.logWindow("group", text) end
end
-- Bug found live 2026-07-09 (see MyDSL_TargetView.lua's tvLogLink comment
-- for the full explanation): this is dechoLink()'s useCurrentFormat flag,
-- not "underline" -- false made every link here ignore its decho color
-- code and render as Mudlet's default blue/underlined hyperlink. Fixed
-- both call sites below to pass true.
local function gvLogLink(mc, text, cmd, hint, underline)
  mc:dechoLink(text, cmd, hint, underline)
  if MyDSL.logWindow then MyDSL.logWindow("group", text) end
end


------------------------------------------------------------------------
-- Config persistence -- added 2026-07-11, per the maintainer wanting the quick
-- buttons manually configurable "even the group buttons." quickset
-- already existed (see the alias section below) but had NO persistence
-- at all -- GV.config.quickActions only ever lived in memory, silently
-- resetting to {"heal","rescue"} on every script reload/relog. Mirrors
-- MyDSL_TargetView.lua's charName()/safeFileName()/configFile() pattern
-- exactly (same per-character-bound convention every other module uses).
-- charName()/safeFileName() delegate to MyDSL.charName()/MyDSL.
-- safeFileName() (MyDSL_DataLayer.lua, added 2026-07-11, code-review
-- reuse finding -- this was the 4th identical copy of the same logic in
-- the codebase). Falls back to the same logic locally only if DataLayer
-- somehow hasn't loaded yet.
------------------------------------------------------------------------

local function charName()
  if MyDSL and MyDSL.charName then return MyDSL.charName() end
  if gmcp and gmcp.login_data and gmcp.login_data.name and gmcp.login_data.name ~= "" then
    return tostring(gmcp.login_data.name)
  end
  if MyCore and MyCore.getChar then
    local ok, name = pcall(MyCore.getChar)
    if ok and name and name ~= "" then return tostring(name) end
  end
  return "Unknown"
end

local function safeFileName(s)
  if MyDSL and MyDSL.safeFileName then return MyDSL.safeFileName(s) end
  s = tostring(s or "Unknown"):gsub("[^%w_%-%.]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if s == "" then s = "Unknown" end
  return s
end

local function configFile()
  return getMudletHomeDir() .. "/MyDSL/groupview_config_" .. safeFileName(charName()) .. ".lua"
end

-- REAL BUG, found live 2026-07-11: Mudlet's real table.load(file, target)
-- does not return anything -- it unpickles INTO an explicit second-
-- argument table (confirmed in Mudlet's own bundled source). This used
-- to call table.load(configFile()) with no second argument, so `data`
-- was always nil -- quickActions customizations never actually survived
-- a restart (same bug found across ~10 call sites project-wide the same
-- day -- see MyDSL_DataLayer.lua's MyDSL.load() for the full writeup).
local function loadConfig()
  local data = {}
  local ok = pcall(table.load, configFile(), data)
  if ok and next(data) then
    if type(data.quickActions) == "table" and #data.quickActions == 2 then
      GV.config.quickActions = data.quickActions
    end
  end
end

local function saveConfig()
  pcall(table.save, configFile(), GV.config)
end

-- Expose for the alias bodies below (same indirection TargetView uses --
-- saveConfig is local, alias bodies run in a separate chunk).
GV._saveConfig = saveConfig

-- MyDSL.copyArray() -- MyDSL_DataLayer.lua, added 2026-07-11, code-review
-- reuse finding (this was one of 2 identical copy-the-defaults-array
-- implementations, the other being MyDSL_TargetView.lua's TV.resetButtons()).
function GV.resetQuickActions()
  GV.config.quickActions = MyDSL.copyArray(GV.defaults.quickActions)
end


------------------------------------------------------------------------
-- hpColor(pct)  —  returns decho RGB string for an HP percentage
------------------------------------------------------------------------
-- Thresholds follow the standard DSL convention: green → yellow → orange → red.

-- cutText(s, width) -- truncates with a trailing "~" instead of a flat
-- mid-word cut. Fixed 2026-07-07: found sampling logs, a 22-char mob name
-- ("A throughbred stallion") was being cut mid-word ("A throughbred
-- stalli") by the old m.name:sub(1, 20). Same shape as AffectsView's own
-- cutText() (MyDSL_AffectsView.lua) -- reusing the established convention
-- rather than inventing a separate word-boundary algorithm.
local function cutText(s, width)
  s = tostring(s or "")
  width = tonumber(width) or #s
  if #s <= width then return s end
  if width <= 1 then return s:sub(1, width) end
  return s:sub(1, width - 1) .. "~"
end

local function hpColor(pct)
  if     pct >= 76 then return "68,204,68"    -- green
  elseif pct >= 51 then return "204,204,68"   -- yellow
  elseif pct >= 26 then return "204,136,68"   -- orange
  else                   return "204,68,68"   -- red
  end
end


------------------------------------------------------------------------
-- render()  —  redraws the MyDSL_Group window from State.group
------------------------------------------------------------------------
-- Called on "MyDSL.group.updated" event and once during init().
-- Each group member gets one line:
--   [class]  name (clickable, max 20 chars)  HP%  mana%  mv%  [quick buttons]
--
-- Class tag color:    Mob → dim yellow (136,136,68);  other → blue (68,136,204)
-- Name color:         mob → warm tan (204,170,100);   player → near-white (204,204,204)
-- Name is a dechoLink → calls GV.setTarget(idx) to populate the Target window.
-- HP color:           green/yellow/orange/red by threshold (see hpColor above)
-- Mana color:         blue (68,136,204), always shown
-- MV color:           light green (136,204,136), always shown
-- Quick buttons:      from GV.config.quickActions (default heal+rescue);
--                     shown for all members regardless of mob/player status.

function GV.render()
  local mc = GV._mc and GV._mc.group
  if not mc then return end
  mc:clear()

  local grp = MyDSL.State and MyDSL.State.group
  if not grp or not grp.members or #grp.members == 0 then
    gvLog(mc, "<85,85,85>(no group)\n")
    return
  end

  for idx, m in ipairs(grp.members) do
    -- Class tag: Mob gets dim yellow, all other classes get blue.
    local tag_color = (m.class == "Mob") and "136,136,68" or "68,136,204"
    gvLog(mc, string.format("<%s>[%-3s]<r> ", tag_color, m.class))

    -- Name: clickable to set Target; mobs warm tan, players near-white.
    -- Column width narrowed 20 -> 14 chars, 2026-07-16, per the maintainer
    -- ("reduce space in group window between name and stats") -- 20 was
    -- always padding out to a full 20 characters even for short player
    -- names (e.g. short ones), leaving a large visible gap before hp%; still
    -- fixed-width (not fully dynamic) so the hp/mana/move columns stay
    -- aligned across rows regardless of name length.
    local name_color = m.is_mob and "204,170,100" or "204,204,204"
    local display_name = cutText(m.name, 14)
    gvLogLink(mc,
      string.format("<%s>%-14s<r>", name_color, display_name),
      string.format("MyDSL.GroupView.setTarget(%d)", idx),
      "Click to target: " .. m.name,
      true)

    -- HP percentage — always shown, colored by threshold.
    local hp_c = hpColor(m.hp_pct)
    gvLog(mc, string.format(" <%s>%3d%%hp<r>", hp_c, m.hp_pct))

    -- Mana and move percentages — always shown.
    gvLog(mc, string.format(" <68,136,204>%3d%%mn<r>", m.mana_pct))
    gvLog(mc, string.format(" <136,204,136>%3d%%mv<r>", m.mv_pct))

    -- Quick-action buttons — reuse TV.actions entries.
    -- Exception: rescue is skipped for Mob rows — DSL rescue only works player→player
    -- or pet→player, never player→mob (confirmed live: "rescue bear" always fails;
    -- "order bear rescue <player>" succeeds).
    for _, key in ipairs(GV.config.quickActions) do
      if key == "rescue" and m.is_mob then
        -- skip: rescue cannot target mobs, even charmed pets
      else
        local act = MyDSL.TargetView and MyDSL.TargetView.actions
                    and MyDSL.TargetView.actions[key]
        if act then
          gvLogLink(mc,
            string.format(" <%s>[%s]<r>", act.color, act.label),
            string.format("MyDSL.GroupView.quickAction(%d, '%s')", idx, key),
            act.tooltip .. ": " .. m.name,
            true)
        end
      end
    end

    gvLog(mc, "\n")
  end
end


------------------------------------------------------------------------
-- setGag(bool)  —  toggle gagging of the group block in main console
------------------------------------------------------------------------
-- Body-line gagging is handled inside DataLayer's beginGroup() catch-all
-- by reading GV.config.gagGroup directly — no trigger needed here for body lines.
-- Only the header line ("<Name>'s group:") needs a dedicated gag trigger.

function GV.setGag(enabled)
  GV.config.gagGroup = enabled
  -- Kill any existing gag triggers before possibly re-registering.
  for _, id in pairs(GV._triggers) do pcall(killTrigger, id) end
  GV._triggers = {}
  if enabled then
    -- Gag the group header line (e.g. "<Name>'s group:").
    GV._triggers.gagHeader = tempRegexTrigger(
      "^.+'s group:$",
      function() deleteLine() end
    )
  end
end


------------------------------------------------------------------------
-- setTarget(idx)  —  set the Target window to a group member by index
------------------------------------------------------------------------
-- Called by dechoLink click on the member name. Uses the ipairs index
-- so it is safe even if the group list has gaps (which it shouldn't).

function GV.setTarget(idx)
  local g = MyDSL.State and MyDSL.State.group
  local m = g and g.members and g.members[idx]
  if not m then return end
  if MyDSL.Target and MyDSL.Target.set then
    MyDSL.Target.set(m.name, m.is_mob, "groupclick")
  end
end


------------------------------------------------------------------------
-- quickAction(idx, actionKey)  —  fire a TV.actions command on a member
------------------------------------------------------------------------
-- Called by the per-row quick-action button dechoLinks. Looks up the
-- TV.actions entry by key and sends the command for the member's name,
-- constructing a temporary target-like table {name=m.name} so the cmd
-- function works the same way as in TargetView.doAction().

function GV.quickAction(idx, actionKey)
  local g = MyDSL.State and MyDSL.State.group
  local m = g and g.members and g.members[idx]
  if not m then return end
  local act = MyDSL.TargetView and MyDSL.TargetView.actions
              and MyDSL.TargetView.actions[actionKey]
  if not act then return end
  -- is_mob included 2026-07-07: TV.actions.murder/order_attack now pick
  -- their verb (kill vs murder) based on t.is_mob -- omitting it here
  -- would silently fall back to the player verb for a mob quick-action.
  local cmd = act.cmd({ name = m.name, is_mob = m.is_mob })
  send(cmd, false)
end


------------------------------------------------------------------------
-- init()  —  called once at load; safe to re-call on reload
------------------------------------------------------------------------
-- Creates the MiniConsole inside the MyDSL_Group UserWindow (which must
-- already exist in WindowRegistry). Registers the group.updated handler
-- and restores the gag state from config.

------------------------------------------------------------------------
-- ensureUI()  --  creates the Group window/console if it doesn't exist
-- yet. Extracted from init() 2026-07-15 so rebuild() can recreate the
-- console without duplicating the whole setup.
------------------------------------------------------------------------

function GV.ensureUI()
  local groupWin = MyDSL.Windows.ensure(GROUP_WIN)
  -- Visual pass v2 "One Bar, Renamed and Colored" (locked spec,
  -- 2026-08-26) -- short, plain name; applyTheme() colors it.
  if groupWin and groupWin.setTitle then
    pcall(function() groupWin:setTitle(MyDSL.Windows.getTitle(GROUP_WIN, "Group")) end)
  end

  -- Create the MiniConsole only once; the _mc table persists across reloads
  -- so re-calling init() after dofile() never creates a duplicate console.
  if not GV._mc.group then
    GV._mc.group = Geyser.MiniConsole:new({
      name      = GROUP_MC,
      x = 0, y = 0, width = "100%", height = "100%",
      wrapWidth = 300,
      scrollBar = false,
    }, groupWin)
  end

  -- Font size now persisted per-window (2026-07-15, "bring Scan/Group/
  -- Bestiary up to the same status/show/hide/rebuild/font standard other
  -- windows have" -- see docs/CHANGELOG.md), closing the pre-existing
  -- hardcoded-8 gap this file's own comment used to flag. Default of 8
  -- kept (a row -- class tag + name + hp/mana/mv + 2 quick-action buttons
  -- -- was overflowing the window width at the old default of 10).
  local groupFont = MyDSL.Windows.getFontSize(GROUP_WIN, 8)
  if GV._mc.group then GV._mc.group:setFontSize(groupFont) end

  if MyDSL.Theme and MyDSL.Theme.styleConsole then
    MyDSL.Theme.styleConsole(GV._mc.group, GROUP_WIN, groupFont)
  end
end

function GV.init()
  GV.ensureUI()

  -- Register the event handler that triggers a re-render after each group parse.
  GV._handlers.groupUpdated = registerAnonymousEventHandler(
    "MyDSL.group.updated",
    function() GV.render() end
  )

  GV._handlers.themeChanged = registerAnonymousEventHandler(
    "MyDSL.theme.changed",
    function()
      if MyDSL.Theme and MyDSL.Theme.styleConsole then
        MyDSL.Theme.styleConsole(GV._mc.group, GROUP_WIN, MyDSL.Windows.getFontSize(GROUP_WIN, 8))
      end
    end
  )

  -- Load quickActions config from disk now, and again once the real
  -- character is known -- same fix as MyDSL_TargetView.lua's identical
  -- problem (see that file's TV.init() comment): loadConfig() here runs
  -- at script-boot time, which on a genuinely fresh Mudlet start happens
  -- before login, so it would otherwise load "Unknown"'s config and never
  -- pick up this character's real saved buttons.
  loadConfig()
  GV._handlers.characterIdentified = registerAnonymousEventHandler(
    "MyDSL.character.identified",
    function()
      loadConfig()
      GV.render()
    end
  )

  -- Restore gag triggers if the config flag was set before this reload.
  if GV.config.gagGroup then GV.setGag(true) end

  -- Initial render (will show "(no group)" until first group command runs).
  GV.render()

  debugc("[MyDSL] GroupView loaded.")
end


------------------------------------------------------------------------
-- Window lifecycle -- status/show/hide/rebuild/font, added 2026-07-15 to
-- bring Group up to the same standard Live/Chat/Portrait/Affects/Tick/
-- Alterform already have (found during a "does Scan have the same
-- options as other windows" check, then extended to Group/Bestiary too).
------------------------------------------------------------------------

function GV.status()
  decho(string.format(
    "<136,204,255>[MyDSL] Group: gag=%s font=%d<r>\n",
    tostring(GV.config.gagGroup),
    MyDSL.Windows.getFontSize(GROUP_WIN, 8)
  ))
end

function GV.show() MyDSL.Windows.show(GROUP_WIN) end
function GV.hide() MyDSL.Windows.hide(GROUP_WIN) end

-- setTitle(title) -- real gap fix, 2026-08-26 (command-parity sweep).
function GV.setTitle(title)
  title = tostring(title or ""):match("^%s*(.-)%s*$")
  if title == "" then title = "Group" end
  MyDSL.Windows.setTitle(GROUP_WIN, title)
  local win = MyDSL.Windows.get and MyDSL.Windows.get(GROUP_WIN)
  if win and win.setTitle then pcall(function() win:setTitle(title) end) end
  echo("Group title=" .. title .. "\n")
end

function GV.setFont(size)
  size = tonumber(size)
  if not size then echo("usage: group font <size>\n"); return end
  if size < 6 then size = 6 end
  if size > 18 then size = 18 end
  if GV._mc.group then GV._mc.group:setFontSize(size) end
  MyDSL.Windows.setFontSize(GROUP_WIN, size)
  echo("MyDSL_Group font=" .. tostring(size) .. "\n")
end


------------------------------------------------------------------------
-- Aliases  (registered as tempAlias so they survive script reloads)
------------------------------------------------------------------------

-- Renamed 2026-07-11, command-surface retrofit (docs/TODO.md "OPEN —
-- Command-surface retrofit"), per the maintainer: "consistent across all
-- commands, and human speak/readable." Dropped the "mydsl" prefix --
-- confirmed bare "group" is safe (real DSL "group" command is always
-- typed with no arguments in every real usage seen; these all require
-- extra words, so no collision). Old "mydsl group ..." forms are gone,
-- not kept as a fallback -- this is for general use, not just muscle
-- memory.
tempAlias("^group gag$",
  "if MyDSL and MyDSL.GroupView then MyDSL.GroupView.setGag(true) end")
tempAlias("^group ungag$",
  "if MyDSL and MyDSL.GroupView then MyDSL.GroupView.setGag(false) end")
-- Fixed 2026-07-11: this used to only ever set config.quickActions in
-- memory -- no saveConfig() call existed anywhere in this file until now,
-- so it silently reset to {"heal","rescue"} on every reload/relog. Any
-- action name here can be a built-in from MyDSL.TargetView.actions OR a
-- custom one defined via "focus action ..." (MyDSL_TargetView.lua) --
-- both tables are the same one, shared by construction (GV.quickAction
-- already looks up MyDSL.TargetView.actions[actionKey]).
tempAlias("^group quickset\\s+(\\S+)\\s+(\\S+)$",
  [[if MyDSL and MyDSL.GroupView then
    MyDSL.GroupView.config.quickActions = {matches[2], matches[3]}
    MyDSL.GroupView._saveConfig()
    echo("Group quick buttons: " .. matches[2] .. ", " .. matches[3] .. "\n")
  end]])
tempAlias("^group quickset reset$",
  [[if MyDSL and MyDSL.GroupView then
    MyDSL.GroupView.resetQuickActions()
    MyDSL.GroupView._saveConfig()
    echo("Group quick buttons reset to defaults.\n")
  end]])
-- "group actions" -- added 2026-08-29, per the maintainer's button-UX review
-- ("make changing buttons easier for the user"). Delegates to
-- MyDSL.TargetView.listActions() rather than a separate copy -- same
-- shared TV.actions/custom_actions registry "group quickset" already
-- reads from (see its own comment above), so the list this prints is
-- always exactly the set of keys "group quickset" will accept.
tempAlias("^group actions$",
  "if MyDSL and MyDSL.TargetView and MyDSL.TargetView.listActions then MyDSL.TargetView.listActions() end")

-- status/show/hide/font -- same naming convention as the retrofitted
-- commands above (bare "group ..."), consistent since none of these
-- collide with real DSL vocabulary either. "rebuild" removed 2026-08-26
-- (command-parity sweep) -- no evidence it was ever needed, and
-- show/hide/status/font already cover every real use.
tempAlias("^group status$",
  "if MyDSL and MyDSL.GroupView then MyDSL.GroupView.status() end")
tempAlias("^group show$",
  "if MyDSL and MyDSL.GroupView then MyDSL.GroupView.show() end")
tempAlias("^group hide$",
  "if MyDSL and MyDSL.GroupView then MyDSL.GroupView.hide() end")
tempAlias("^group font (\\d+)$",
  "if MyDSL and MyDSL.GroupView then MyDSL.GroupView.setFont(matches[2]) end")
tempAlias("^group title (.+)$",
  "if MyDSL and MyDSL.GroupView then MyDSL.GroupView.setTitle(matches[2]) end")


------------------------------------------------------------------------
-- Boot
------------------------------------------------------------------------

GV.init()
