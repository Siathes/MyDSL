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

-- Window and MiniConsole name constants.
local GROUP_WIN = "MyDSL_Group"
local GROUP_MC  = "MyDSL_Group_MC"


------------------------------------------------------------------------
-- hpColor(pct)  —  returns decho RGB string for an HP percentage
------------------------------------------------------------------------
-- Thresholds follow the standard DSL convention: green → yellow → orange → red.

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
    mc:decho("<85,85,85>(no group)\n")
    return
  end

  for idx, m in ipairs(grp.members) do
    -- Class tag: Mob gets dim yellow, all other classes get blue.
    local tag_color = (m.class == "Mob") and "136,136,68" or "68,136,204"
    mc:decho(string.format("<%s>[%-3s]<r> ", tag_color, m.class))

    -- Name: clickable to set Target; mobs warm tan, players near-white; max 20 chars.
    local name_color = m.is_mob and "204,170,100" or "204,204,204"
    local display_name = m.name:sub(1, 20)
    mc:dechoLink(
      string.format("<%s>%-20s<r>", name_color, display_name),
      string.format("MyDSL.GroupView.setTarget(%d)", idx),
      "Click to target: " .. m.name,
      false)

    -- HP percentage — always shown, colored by threshold.
    local hp_c = hpColor(m.hp_pct)
    mc:decho(string.format(" <%s>%3d%%hp<r>", hp_c, m.hp_pct))

    -- Mana and move percentages — always shown.
    mc:decho(string.format(" <68,136,204>%3d%%mn<r>", m.mana_pct))
    mc:decho(string.format(" <136,204,136>%3d%%mv<r>", m.mv_pct))

    -- Quick-action buttons — reuse TV.actions entries; no mob/player filtering
    -- since every member of your own group listing is an ally.
    for _, key in ipairs(GV.config.quickActions) do
      local act = MyDSL.TargetView and MyDSL.TargetView.actions
                  and MyDSL.TargetView.actions[key]
      if act then
        mc:dechoLink(
          string.format(" <%s>[%s]<r>", act.color, act.label),
          string.format("MyDSL.GroupView.quickAction(%d, '%s')", idx, key),
          act.tooltip .. ": " .. m.name,
          false)
      end
    end

    mc:decho("\n")
  end
end


------------------------------------------------------------------------
-- setGag(bool)  —  toggle gagging of the group block in main console
------------------------------------------------------------------------
-- Body-line gagging is handled inside DataLayer's beginGroup() catch-all
-- by reading GV.config.gagGroup directly — no trigger needed here for body lines.
-- Only the header line ("Kien's group:") needs a dedicated gag trigger.

function GV.setGag(enabled)
  GV.config.gagGroup = enabled
  -- Kill any existing gag triggers before possibly re-registering.
  for _, id in pairs(GV._triggers) do pcall(killTrigger, id) end
  GV._triggers = {}
  if enabled then
    -- Gag the group header line (e.g. "Kien's group:").
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
  local cmd = act.cmd({ name = m.name })
  debugc("[MyDSL] sending: " .. cmd)  -- REMOVE after Steven confirms commands are correct
  send(cmd, false)
end


------------------------------------------------------------------------
-- init()  —  called once at load; safe to re-call on reload
------------------------------------------------------------------------
-- Creates the MiniConsole inside the MyDSL_Group UserWindow (which must
-- already exist in WindowRegistry). Registers the group.updated handler
-- and restores the gag state from config.

function GV.init()
  -- Ensure Group UserWindow exists and get a reference to it.
  local groupWin = MyDSL.Windows.ensure(GROUP_WIN)

  -- Create the MiniConsole only once; the _mc table persists across reloads
  -- so re-calling init() after dofile() never creates a duplicate console.
  if not GV._mc.group then
    GV._mc.group = Geyser.MiniConsole:new({
      name      = GROUP_MC,
      x = 0, y = 0, width = "100%", height = "100%",
      wrapWidth = 300,
      fontSize  = 10,
      scrollBar = false,
    }, groupWin)
  end
  -- Always re-apply font size in case Mudlet reset it during a reload.
  if GV._mc.group then GV._mc.group:setFontSize(10) end

  -- Register the event handler that triggers a re-render after each group parse.
  GV._handlers.groupUpdated = registerAnonymousEventHandler(
    "MyDSL.group.updated",
    function() GV.render() end
  )

  -- Restore gag triggers if the config flag was set before this reload.
  if GV.config.gagGroup then GV.setGag(true) end

  -- Initial render (will show "(no group)" until first group command runs).
  GV.render()

  debugc("[MyDSL] GroupView loaded.")
end


------------------------------------------------------------------------
-- Aliases  (registered as tempAlias so they survive script reloads)
------------------------------------------------------------------------

tempAlias("^mydsl group gag$",
  "if MyDSL and MyDSL.GroupView then MyDSL.GroupView.setGag(true) end")
tempAlias("^mydsl group ungag$",
  "if MyDSL and MyDSL.GroupView then MyDSL.GroupView.setGag(false) end")
tempAlias("^mydsl group quickset\\s+(\\S+)\\s+(\\S+)$",
  [[if MyDSL and MyDSL.GroupView then
    MyDSL.GroupView.config.quickActions = {matches[2], matches[3]}
    echo("Group quick buttons: " .. matches[2] .. ", " .. matches[3] .. "\n")
  end]])


------------------------------------------------------------------------
-- Boot
------------------------------------------------------------------------

GV.init()
