-- =============================================================================
-- MyDSL_TargetView.lua  --  Layer 3 Phase B: Target display and action buttons
-- =============================================================================
-- Displays the current combat target and 6 configurable action buttons.
-- Target is set by clicking in RightHere (MyDSL.Target.set) or via alias.
-- Buttons send commands only on explicit player click — never automatically.
-- =============================================================================

MyDSL        = MyDSL        or {}
MyDSL.Target = MyDSL.Target or {}

MyDSL.TargetView = MyDSL.TargetView or {}
local TV = MyDSL.TargetView

-- Safe-reload: kill old handlers, triggers, aliases on every load.
for _, id in pairs(TV._handlers or {}) do pcall(killAnonymousEventHandler, id) end
for _, id in pairs(TV._triggers or {}) do pcall(killTrigger, id) end
for _, id in pairs(TV._aliases  or {}) do pcall(killAlias, id) end

TV._handlers = {}
TV._triggers = {}
TV._aliases  = {}
TV._mc       = TV._mc or {}   -- persists to avoid duplicate MiniConsole creation
TV._consider_lines = {}       -- cleared on target change, appended by captureConsider

-- Config with defaults; loadConfig() may override these from disk.
TV.config = TV.config or {
  mob_buttons    = { "murder", "glance", "consider", "creaturelore", "rescue", "flee" },
  player_buttons = { "murder", "glance", "rescue", "look", "heal", "flee" },
}

-- Window / MiniConsole names.
local TARGET_WIN = "MyDSL_Target"
local TARGET_MC  = "MyDSL_Target_MC"

-- Config persistence path.
local CONFIG_FILE = getMudletHomeDir() .. "/MyDSL/targetview_config.lua"


------------------------------------------------------------------------
-- Name normalisation helpers
------------------------------------------------------------------------

local function normalizeName(s)
  s = tostring(s or ""):lower()
  s = s:gsub('[",.]', " ")
  s = s:gsub("^a%s+", ""):gsub("^an%s+", ""):gsub("^the%s+", "")
  s = s:gsub("%s+", " ")
  return s:match("^%s*(.-)%s*$")
end

local function commandArg(name)
  local s = normalizeName(name or "")
  if s == "" then return "" end
  -- Apostrophe in name → use last word after apostrophe as safe fallback.
  if s:find("'", 1, true) then
    return s:match("([^%s']+)$") or s
  end
  -- Multi-word → quote it; single word → bare.
  if s:find("%s") then return "'" .. s .. "'" end
  return s
end


------------------------------------------------------------------------
-- Action definitions
------------------------------------------------------------------------
-- cmd: function(target_state) → command string to send
-- Label, color, and tooltip are used by render().

TV.actions = {
  murder = {
    cmd     = function(t) return "murder " .. commandArg(t.name) end,
    label   = "Murder",
    color   = "204,68,68",
    tooltip = "Attack target",
  },
  glance = {
    cmd     = function(t) return "gl " .. commandArg(t.name) end,
    label   = "Glance",
    color   = "204,204,204",
    tooltip = "Quick look at target",
  },
  consider = {
    cmd     = function(t) return "consider " .. commandArg(t.name) end,
    label   = "Consider",
    color   = "204,204,204",
    tooltip = "Check combat difficulty",
  },
  creaturelore = {
    cmd     = function(t) return "creaturelore " .. commandArg(t.name) end,
    label   = "Lore",
    color   = "204,204,204",
    tooltip = "Get creature lore (opens reference window)",
  },
  rescue = {
    cmd     = function(t) return "rescue " .. commandArg(t.name) end,
    label   = "Rescue",
    color   = "170,170,255",
    tooltip = "Rescue target from combat",
  },
  flee = {
    cmd     = function(_) return "flee" end,
    label   = "Flee",
    color   = "204,68,68",
    tooltip = "Attempt to flee combat",
  },
  look = {
    cmd     = function(t) return "look " .. commandArg(t.name) end,
    label   = "Look",
    color   = "204,204,204",
    tooltip = "Full look at target",
  },
  heal = {
    cmd     = function(t) return "cast 'heal' " .. commandArg(t.name) end,
    label   = "Heal",
    color   = "68,204,68",
    tooltip = "Cast heal on target",
  },
  cure_light = {
    cmd     = function(t) return "cast 'cure light' " .. commandArg(t.name) end,
    label   = "Cr.Light",
    color   = "68,204,68",
    tooltip = "Cure light wounds",
  },
  refresh = {
    cmd     = function(t) return "cast refresh " .. commandArg(t.name) end,
    label   = "Refresh",
    color   = "68,204,68",
    tooltip = "Restore movement points",
  },
  cure_serious = {
    cmd     = function(t) return "cast 'cure serious' " .. commandArg(t.name) end,
    label   = "Cr.Serious",
    color   = "68,204,68",
    tooltip = "Cure serious wounds",
  },
  cure_critical = {
    cmd     = function(t) return "cast 'cure critical' " .. commandArg(t.name) end,
    label   = "Cr.Critical",
    color   = "68,204,68",
    tooltip = "Cure critical wounds",
  },
  cure_blindness = {
    cmd     = function(t) return "cast 'cure blindness' " .. commandArg(t.name) end,
    label   = "Cr.Blind",
    color   = "170,170,255",
    tooltip = "Cure blindness",
  },
  cure_disease = {
    cmd     = function(t) return "cast 'cure disease' " .. commandArg(t.name) end,
    label   = "Cr.Disease",
    color   = "170,170,255",
    tooltip = "Cure disease",
  },
  cure_poison = {
    cmd     = function(t) return "cast 'cure poison' " .. commandArg(t.name) end,
    label   = "Cr.Poison",
    color   = "170,170,255",
    tooltip = "Cure poison",
  },
  cure_fatigue = {
    cmd     = function(t) return "cast 'cure fatigue' " .. commandArg(t.name) end,
    label   = "Cr.Fatigue",
    color   = "170,170,255",
    tooltip = "Cure fatigue",
  },
  cure_bugbite = {
    cmd     = function(t) return "cast 'cure bugbite' " .. commandArg(t.name) end,
    label   = "Cr.Bugbite",
    color   = "170,170,255",
    tooltip = "Cure bugbite toxin",
  },
  sanctuary = {
    cmd     = function(t) return "cast sanctuary " .. commandArg(t.name) end,
    label   = "Sanctuary",
    color   = "255,215,65",
    tooltip = "Halve damage taken",
  },
}


------------------------------------------------------------------------
-- Config persistence
------------------------------------------------------------------------

local function loadConfig()
  local ok, data = pcall(table.load, CONFIG_FILE)
  if ok and type(data) == "table" then
    if type(data.mob_buttons) == "table" and #data.mob_buttons == 6 then
      TV.config.mob_buttons = data.mob_buttons
    end
    if type(data.player_buttons) == "table" and #data.player_buttons == 6 then
      TV.config.player_buttons = data.player_buttons
    end
  end
end

local function saveConfig()
  pcall(table.save, CONFIG_FILE, TV.config)
end


------------------------------------------------------------------------
-- Local article-detection (same rule as DataLayer isMobName)
------------------------------------------------------------------------

local function isMob(name)
  return name:match("^[Aa]n? ") ~= nil or name:match("^[Tt]he ") ~= nil
end


------------------------------------------------------------------------
-- Target state management
------------------------------------------------------------------------

function MyDSL.Target.set(name, is_mob, source)
  MyDSL.State.target = {
    name   = name,
    key    = name:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", ""),
    is_mob = is_mob,
    source = source or "manual",
    set_at = os.time(),
  }
  TV._consider_lines = {}   -- clear stale consider output
  raiseEvent("MyDSL.target.updated", MyDSL.State.target)
  TV.render()
end

function MyDSL.Target.clear()
  MyDSL.State.target = nil
  TV._consider_lines = {}
  raiseEvent("MyDSL.target.updated", nil)
  TV.render()
end

function MyDSL.Target.toggle()
  local t = MyDSL.State.target
  if not t then return end
  t.is_mob = not t.is_mob
  TV.render()
end

function MyDSL.Target.doAction(action_key)
  local t = MyDSL.State.target
  if not t or not t.name then return end
  local act = TV.actions[action_key]
  if not act then return end
  local cmd = act.cmd(t)
  debugc("[MyDSL] sending: " .. cmd)  -- REMOVE after Steven confirms commands are correct
  send(cmd, false)
end

function MyDSL.Target.captureConsider(line)
  TV._consider_lines[#TV._consider_lines + 1] = line
  TV.render()
end


------------------------------------------------------------------------
-- render()  —  redraws the entire Target window
------------------------------------------------------------------------

function TV.render()
  local mc = TV._mc and TV._mc.target
  if not mc then return end
  mc:clear()
  local t = MyDSL.State.target

  -- Line 1: [M]/[P] toggle + name
  local type_tag   = (t and t.is_mob) and "M" or "P"
  local type_color = (t and t.is_mob) and "204,136,68" or "136,170,255"
  mc:dechoLink(string.format("<%s>[%s]<r>", type_color, type_tag),
    "MyDSL.Target.toggle()", "Switch mob/player mode", false)

  if not t or not t.name then
    mc:decho(" <85,85,85>(no target)<r>\n")
  else
    mc:decho(" ")
    mc:dechoLink("<170,68,68>[Clear]<r>", "MyDSL.Target.clear()", "Clear target", false)
    mc:decho(string.format(" <255,255,255>%s<r>\n", t.name))
  end

  -- Lines 2-3: 6 action buttons
  if t and t.name then
    local buttons = t.is_mob and TV.config.mob_buttons or TV.config.player_buttons
    for row = 0, 1 do
      for col = 1, 3 do
        local idx = row * 3 + col
        local key = buttons[idx]
        local act = key and TV.actions[key]
        if act then
          local btn_text = string.format("<%s>[%s]<r>", act.color, act.label)
          if col < 3 then btn_text = btn_text .. " " end
          mc:dechoLink(btn_text,
            string.format("MyDSL.Target.doAction('%s')", key),
            act.tooltip .. ": " .. t.name, false)
        end
      end
      mc:decho("\n")
    end
  end

  -- Line 4+: consider output (dim grey, cleared on target change)
  for _, line in ipairs(TV._consider_lines) do
    mc:decho(string.format("<136,136,136>%s<r>\n", line))
  end
end


------------------------------------------------------------------------
-- init()  —  safe to re-call on reload
------------------------------------------------------------------------

function TV.init()
  -- Ensure Target UserWindow and its MiniConsole exist.
  local targetWin = MyDSL.Windows.ensure(TARGET_WIN)
  if not TV._mc.target then
    TV._mc.target = Geyser.MiniConsole:new({
      name      = TARGET_MC,
      x = 0, y = 0, width = "100%", height = "100%",
      wrapWidth = 300,
      fontSize  = 11,
      scrollBar = false,
    }, targetWin)
  end
  if TV._mc.target then TV._mc.target:setFontSize(11) end

  -- Register target.updated handler (for external setters).
  TV._handlers.targetUpdated = registerAnonymousEventHandler(
    "MyDSL.target.updated",
    function() TV.render() end
  )

  -- Consider capture triggers (not gagged — output stays in main console).
  TV._triggers.considerLine1 = tempRegexTrigger(
    "^You wonder if you could kill",
    function()
      if MyDSL and MyDSL.Target then
        MyDSL.Target.captureConsider(getCurrentLine())
      end
    end
  )
  TV._triggers.considerLine2 = tempRegexTrigger(
    "^\\.\\.\\. ",
    function()
      if MyDSL and MyDSL.Target then
        MyDSL.Target.captureConsider(getCurrentLine())
      end
    end
  )

  -- Aliases
  TV._aliases.targetSet = tempAlias(
    "^mydsl target clear$",
    "if MyDSL and MyDSL.Target then MyDSL.Target.clear() end"
  )
  TV._aliases.targetClear = tempAlias(
    "^mydsl target (.+)$",
    [[
      local name = matches[2]
      if name ~= "clear" and MyDSL and MyDSL.Target then
        local function isM(n)
          return n:match("^[Aa]n? ") ~= nil or n:match("^[Tt]he ") ~= nil
        end
        MyDSL.Target.set(name, isM(name), "manual")
      end
    ]]
  )
  TV._aliases.targetMobset = tempAlias(
    "^mydsl target mobset\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)$",
    [[
      if MyDSL and MyDSL.TargetView then
        MyDSL.TargetView.config.mob_buttons = {
          matches[2], matches[3], matches[4], matches[5], matches[6], matches[7]
        }
        -- saveConfig is local; call via TV reference exposed on module table
        MyDSL.TargetView._saveConfig()
        echo("Mob buttons updated.\n")
      end
    ]]
  )
  TV._aliases.targetPlayerset = tempAlias(
    "^mydsl target playerset\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)$",
    [[
      if MyDSL and MyDSL.TargetView then
        MyDSL.TargetView.config.player_buttons = {
          matches[2], matches[3], matches[4], matches[5], matches[6], matches[7]
        }
        MyDSL.TargetView._saveConfig()
        echo("Player buttons updated.\n")
      end
    ]]
  )

  -- Load config from disk (may override defaults).
  loadConfig()

  -- Initial render.
  TV.render()

  debugc("[MyDSL] TargetView loaded.")
end

-- Expose saveConfig so alias callbacks can call it.
TV._saveConfig = saveConfig


------------------------------------------------------------------------
-- Boot
------------------------------------------------------------------------

-- Initialise State.target guard (DataLayer owns MyDSL.State but target
-- is managed by this module, so we initialise it here if absent).
MyDSL.State = MyDSL.State or {}
MyDSL.State.target = MyDSL.State.target or nil

TV.init()
