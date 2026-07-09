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
-- order_attack ("Order All") made a default 2026-07-05 per Steven -- was
-- opt-in only; swapped in for "glance" (redundant with consider/look).
TV.config = TV.config or {
  mob_buttons    = { "murder", "consider", "order_attack", "creaturelore", "rescue", "flee" },
  player_buttons = { "murder", "glance", "rescue", "look", "heal", "flee" },
}

-- Window / MiniConsole names.
local TARGET_WIN = "MyDSL_Target"
local TARGET_MC  = "MyDSL_Target_MC"

-- Mirrors the Target window's text into MyDSL/logs/target/ (2026-07-05:
-- Mudlet's startLogging() can't capture MiniConsole content at all).
local function tvLog(mc, text)
  mc:decho(text)
  if MyDSL.logWindow then MyDSL.logWindow("target", text) end
end
-- Bug found live 2026-07-09: this parameter is dechoLink()'s
-- useCurrentFormat flag, not "underline" as the name suggests -- false
-- makes Mudlet ignore the decho color codes already in `text` and apply
-- its own default blue/underlined hyperlink style instead, which is
-- exactly the "still blue and underlined" symptom Steven kept reporting
-- for the Rescue/cure-spell buttons. Every call site in this file (and
-- MyDSL_GroupView.lua's equivalent) was passing false; only
-- MyDSL_ScanView.lua's RightHere links passed true, which is why those
-- rendered correctly and nothing else did. All callers fixed to pass true.
local function tvLogLink(mc, text, cmd, hint, underline)
  mc:dechoLink(text, cmd, hint, underline)
  if MyDSL.logWindow then MyDSL.logWindow("target", text) end
end

-- Config persistence path -- character-bound as of 2026-07-05 (was a single
-- shared file; different characters may want different default buttons).
-- Same charName()/safeFileName() pattern as MyDSL_AffectsView.lua.
local function charName()
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
  s = tostring(s or "Unknown"):gsub("[^%w_%-%.]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if s == "" then s = "Unknown" end
  return s
end

local function configFile()
  return getMudletHomeDir() .. "/MyDSL/targetview_config_" .. safeFileName(charName()) .. ".lua"
end


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
  -- DSL's target keyword matching only succeeds on a single word — confirmed
  -- via extensive live testing (cast heal 'wild bear' → "They aren't here.";
  -- cast heal bear → Ok.). Always reduce to the last word of the normalized name.
  return s:match("(%S+)$") or s
end


------------------------------------------------------------------------
-- Action definitions
------------------------------------------------------------------------
-- cmd: function(target_state) → command string to send
-- Label, color, and tooltip are used by render().

TV.actions = {
  murder = {
    -- Verb fixed 2026-07-07: DSL_Helpfiles/"kill kill command hit.txt" is
    -- explicit that `kill`/`hit` starts combat against mobs, while `murder`
    -- is specifically the PKILL-system command for attacking players --
    -- "You must join the pkill system and use the MURDER command to
    -- attack other players." Always sending "murder" regardless of
    -- t.is_mob was itself a likely real bug on mob targets, separate from
    -- the reported order_attack issue below (same wrong-verb root cause).
    cmd     = function(t) return (t.is_mob and "kill " or "murder ") .. commandArg(t.name) end,
    label   = "Murder",
    color   = "204,68,68",
    tooltip = "Attack target",
    attack  = true,
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
  -- Color changed 2026-07-07 (rescue + all cure_* actions below) from the
  -- old pale blue-violet "170,170,255" per Steven: "really need to change
  -- the blue actions in the windows i cant read them the contrast is
  -- terrible, i use the hover text to tell what they are on my monitor."
  -- Left the mob/player type-indicator blue (ScanView/TargetView's
  -- "136,170,255") alone -- that's a category color, not an action button,
  -- and changing it would break an established mob=orange/player=blue
  -- convention that isn't what was reported as unreadable.
  rescue = {
    cmd     = function(t) return "rescue " .. commandArg(t.name) end,
    label   = "Rescue",
    color   = "120,210,220",
    tooltip = "Rescue target from combat",
  },
  flee = {
    cmd     = function(_) return "flee" end,
    label   = "Flee",
    color   = "204,68,68",
    tooltip = "Attempt to flee combat",
  },
  order_attack = {
    -- Verb fixed 2026-07-07 -- likely root cause of "order all kill
    -- greaser did not work from target window" (reported live-testing,
    -- docs/TODO.md "Reported bugs"). The native, real "(oac)" alias
    -- (current/autosave.xml, `^oac (.+)$`) sends the tested, working
    -- "order all kill <target>" verbatim -- this action was instead
    -- always sending "order all murder", the PKILL-only player-attack
    -- verb (see the murder action above), against order_attack's only
    -- actual use (mob_buttons only, never player_buttons). DSL_Helpfiles/
    -- order.txt confirms `order all <command>` just passes any command
    -- through to followers, so the wrong verb being silently accepted
    -- with no attack (server said "Ok." both times reported) is
    -- consistent with `murder` requiring PKILL/player-target state a
    -- follower-ordered-at-a-mob command doesn't have.
    cmd     = function(t) return "order all " .. (t.is_mob and "kill " or "murder ") .. commandArg(t.name) end,
    label   = "Order All",
    color   = "204,68,68",
    tooltip = "Order all followers to attack target",
    attack  = true,
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
    color   = "120,210,220",
    tooltip = "Cure blindness",
  },
  cure_disease = {
    cmd     = function(t) return "cast 'cure disease' " .. commandArg(t.name) end,
    label   = "Cr.Disease",
    color   = "120,210,220",
    tooltip = "Cure disease",
  },
  cure_poison = {
    cmd     = function(t) return "cast 'cure poison' " .. commandArg(t.name) end,
    label   = "Cr.Poison",
    color   = "120,210,220",
    tooltip = "Cure poison",
  },
  cure_fatigue = {
    cmd     = function(t) return "cast 'cure fatigue' " .. commandArg(t.name) end,
    label   = "Cr.Fatigue",
    color   = "120,210,220",
    tooltip = "Cure fatigue",
  },
  cure_bugbite = {
    cmd     = function(t) return "cast 'cure bugbite' " .. commandArg(t.name) end,
    label   = "Cr.Bugbite",
    color   = "120,210,220",
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
  local ok, data = pcall(table.load, configFile())
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
  pcall(table.save, configFile(), TV.config)
end


------------------------------------------------------------------------
-- Local article-detection (same rule as DataLayer isMobName)
------------------------------------------------------------------------

local function isMob(name)
  return name:match("^[Aa]n? ") ~= nil or name:match("^[Tt]he ") ~= nil
end


------------------------------------------------------------------------
-- Group-member safety check -- 2026-07-07, per Steven: "clicked bear from
-- group, got bear in target window but it should not have the kill
-- option, those should change when group members are selected, so i dont
-- attack a follower/group member." Checked by name against the live group
-- roster (same normalization GroupView itself already uses), not by the
-- click source -- so it also protects a group member re-targeted some
-- other way (e.g. from RightHere), not just a GroupView click.
------------------------------------------------------------------------

local function isOwnGroupMember(name)
  if not name or name == "" then return false end
  local key = normalizeName(name)
  local grp = MyDSL.State and MyDSL.State.group
  if not grp or not grp.members then return false end
  for _, m in ipairs(grp.members) do
    if normalizeName(m.name) == key then return true end
  end
  return false
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
  -- Defense in depth for the group/follower safety fix below -- refuse to
  -- send an attack-type command against your own group member even if a
  -- stale button link somehow still exists (render() already hides these).
  if act.attack and isOwnGroupMember(t.name) then return end
  local cmd = act.cmd(t)
  send(cmd, false)
end

function MyDSL.Target.captureConsider(line)
  TV._consider_lines[#TV._consider_lines + 1] = line
  TV.render()
end


------------------------------------------------------------------------
-- Phase F (2026-07-07): DslColors_Core_v1_0 (native, live -- confirmed via
-- "[DslColors v1.0 RELEASE] loaded" in-game) already has a persistent
-- friend/enemy relation system (dslcolor friend/enemy/neutral <name>,
-- backed by DSL_COLOR_DB.relations.people) that fully supersedes what PNP's
-- Highlighter+People would have provided -- reusing it directly here
-- instead of porting PNP source, per CLAUDE.md's reuse mandate. Read-only:
-- MyDSL never writes to DSL_COLOR_DB, setting relations stays on the real
-- "dslcolor friend/enemy <name>" command. Guarded with pcall since
-- DSL_COLOR_DB/dslKey are globals owned by a separate native script, not
-- ours -- must not error if DslColors isn't loaded for any reason.
------------------------------------------------------------------------

local function dslColorRelation(name)
  if not name or name == "" then return nil end
  local ok, key = pcall(function() return dslKey(name) end)
  if not ok or not key then return nil end
  local db = _G.DSL_COLOR_DB
  if not db or not db.relations or not db.relations.people then return nil end
  return db.relations.people[key]
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
  tvLogLink(mc, string.format("<%s>[%s]<r>", type_color, type_tag),
    "MyDSL.Target.toggle()", "Switch mob/player mode", true)

  if not t or not t.name then
    tvLog(mc, " <85,85,85>(no target)<r>\n")
  else
    tvLog(mc, " ")
    tvLogLink(mc, "<170,68,68>[Clear]<r>", "MyDSL.Target.clear()", "Clear target", true)
    local rel = dslColorRelation(t.name)
    local relTag = ""
    if rel == "friend" then relTag = " <0,200,0>[Friend]<r>"
    elseif rel == "enemy" then relTag = " <200,60,60>[Enemy]<r>" end
    tvLog(mc, string.format(" <255,255,255>%s<r>%s\n", t.name, relTag))
  end

  -- Lines 2-3: 6 action buttons
  if t and t.name then
    local buttons = t.is_mob and TV.config.mob_buttons or TV.config.player_buttons
    local ownMember = isOwnGroupMember(t.name)
    for row = 0, 1 do
      for col = 1, 3 do
        local idx = row * 3 + col
        local key = buttons[idx]
        local act = key and TV.actions[key]
        if act and act.attack and ownMember then act = nil end
        if act then
          local btn_text = string.format("<%s>[%s]<r>", act.color, act.label)
          if col < 3 then btn_text = btn_text .. " " end
          tvLogLink(mc, btn_text,
            string.format("MyDSL.Target.doAction('%s')", key),
            act.tooltip .. ": " .. t.name, true)
        end
      end
      tvLog(mc, "\n")
    end
  end

  -- Line 4+: consider output (dim grey, cleared on target change)
  for _, line in ipairs(TV._consider_lines) do
    tvLog(mc, string.format("<136,136,136>%s<r>\n", line))
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

  -- Re-load once the real character is known -- fixed 2026-07-07. The
  -- loadConfig() call below runs at script-boot time, which on a
  -- genuinely fresh Mudlet start happens before login, so it loads
  -- "Unknown"'s button config (or bare defaults) and would otherwise
  -- never pick up this character's real saved button layout.
  -- MyDSL_DataLayer.lua's gmcp.login_data handler raises
  -- "MyDSL.character.identified" once the real name is known.
  TV._handlers.characterIdentified = registerAnonymousEventHandler(
    "MyDSL.character.identified",
    function()
      loadConfig()
      TV.render()
    end
  )

  -- Consider capture triggers (not gagged — output stays in main console).
  -- Rewritten 2026-07-06: the old text ("^You wonder if you could kill")
  -- was invented, not sourced -- it matched nothing in a 328,643-line
  -- log-corpus regression test, isn't in PNP source (DSL_PNP_*.lua never
  -- mentions "consider" at all), and considerLine2's "^\.\.\. " pattern
  -- only ever matched an unrelated "..." emote line, never real consider
  -- output. Only two difficulty tiers have a confirmed real example in
  -- the corpus so far -- DSL almost certainly has more (a graduated
  -- difficulty ladder is standard for this command per DSL_Helpfiles/
  -- consider.txt's "tells you what your chances are"), but adding
  -- unconfirmed tiers would repeat the exact mistake being fixed here.
  -- Add more as real examples are captured.
  TV._triggers.considerEasyKill = tempRegexTrigger(
    "^[A-Z][\\w' -]*? looks like an easy kill\\.$",
    function()
      if MyDSL and MyDSL.Target then
        MyDSL.Target.captureConsider(getCurrentLine())
      end
    end
  )
  TV._triggers.considerNoMatch = tempRegexTrigger(
    "^[A-Z][\\w' -]*? is no match for you\\.$",
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
