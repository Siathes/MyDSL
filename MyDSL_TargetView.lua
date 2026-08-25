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

-- Window / MiniConsole names -- renamed 2026-07-11 per Steven ("change
-- target window to focus to match commands"): the window's own visible
-- title/registry identity now matches its "focus <verb>" command surface,
-- same precedent MyDSL_CreatureReference.lua already set (window titled
-- "-= Bestiary =-", commands "bestiary ...", internal module/file still
-- called CreatureReference) -- the underlying Lua namespace (MyDSL.Target,
-- MyDSL.TargetView, this file's own name) is intentionally left alone; only
-- the window's title/registry/layout/theme key and its log-file category
-- changed. Historical logs remain under the old MyDSL/logs/target/ path;
-- only new logging goes to MyDSL/logs/focus/.
local TARGET_WIN = "MyDSL_Focus"
local TARGET_MC  = "MyDSL_Focus_MC"

-- Config with defaults; loadConfig() may override mob_buttons/
-- player_buttons/custom_actions from disk (character-bound -- different
-- characters may reasonably want different button loadouts).
-- order_attack ("Order All") made a default 2026-07-05 per Steven -- was
-- opt-in only; swapped in for "glance" (redundant with consider/look).
TV.config = TV.config or {
  mob_buttons    = { "murder", "consider", "order_attack", "creaturelore", "rescue", "flee" },
  player_buttons = { "murder", "glance", "rescue", "look", "heal", "flee" },
}
TV.config.custom_actions = TV.config.custom_actions or {}
-- fontSize -- moved 2026-07-11 to MyDSL.Windows' shared, PROFILE-level
-- (not character-bound) font-size store, per Steven ("the fonts should
-- be saving like theme or window manager whatever tracks that... per
-- profile not user, remember for the layout"). Previously had its own
-- bespoke character-bound file + a "re-load once character is known"
-- handler, structurally identical to MyDSL_ChatWrapper.lua's own
-- (confirmed-working) pattern -- but Steven repeatedly reported it still
-- not surviving a reload, and no root cause was ever conclusively found
-- despite extensive testing. Removing the character-name dependency
-- entirely removes that whole class of timing bug, whether or not it was
-- really the cause. 11 matched the value that was hardcoded before any
-- of this existed; updated to 9 on 2026-08-23 to match Steven's real
-- long-tuned live size (MyDSL_windowfonts.lua's MyDSL_Focus entry),
-- confirmed via a full settings-vs-defaults audit -- this fallback only
-- ever applies to a brand-new window with nothing saved yet, but a
-- genuine fresh install was shipping the wrong size until re-tuned.
TV.config.fontSize = MyDSL.Windows.getFontSize(TARGET_WIN, 9)

-- TV.defaults -- added 2026-07-11, per Steven's "there should be a clear
-- button" ask. Deliberately a fresh literal every load (NOT "TV.defaults or
-- {...}") since TV itself persists across script reloads (MyDSL.TargetView
-- = MyDSL.TargetView or {}) -- if this used the same or-pattern as
-- TV.config, a reset after TV.config had already been customized once
-- would just restore whatever was already saved instead of the TRUE
-- original defaults.
TV.defaults = {
  mob_buttons    = { "murder", "consider", "order_attack", "creaturelore", "rescue", "flee" },
  player_buttons = { "murder", "glance", "rescue", "look", "heal", "flee" },
}

-- Mirrors the Focus window's text into MyDSL/logs/focus/ (2026-07-05:
-- Mudlet's startLogging() can't capture MiniConsole content at all).
local function tvLog(mc, text)
  mc:decho(text)
  if MyDSL.logWindow then MyDSL.logWindow("focus", text) end
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
  if MyDSL.logWindow then MyDSL.logWindow("focus", text) end
end

-- Config persistence path -- character-bound as of 2026-07-05 (was a single
-- shared file; different characters may want different default buttons).
-- Same charName()/safeFileName() pattern as MyDSL_AffectsView.lua.
-- Delegates to MyDSL.charName()/MyDSL.safeFileName() (MyDSL_DataLayer.lua,
-- added 2026-07-11, code-review reuse finding -- this file's own copy was
-- one of 4 identical ones). Falls back to the same logic locally only if
-- DataLayer somehow hasn't loaded yet.
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
-- User-defined custom actions -- added 2026-07-11, per Steven: "all the
-- buttons should be user configurable... even non standard commands like
-- scan, look, get item etc." The fixed TV.actions catalog above only ever
-- covered PNP-style combat/cure verbs -- this lets a button be set to
-- ANY raw command, not just a name from that catalog. Stored in
-- TV.config.custom_actions (key -> {label, color, template}) so they
-- survive reload/relog like everything else in TV.config, then merged
-- into the live TV.actions table (a fresh literal every reload) via
-- applyCustomActions() -- same lookup path mobset/playerset/GroupView's
-- quickset already use, so nothing downstream needs to know a button is
-- custom vs. built-in.
------------------------------------------------------------------------

-- %t in the template is replaced with the target's name (DSL-keyword-
-- reduced the same way every built-in action already does via
-- commandArg()); a template with no %t is sent completely unchanged --
-- lets stateless commands like "scan" or "flee" be defined too, not just
-- target-taking ones.
local function applyCustomActions()
  for key, def in pairs(TV.config.custom_actions or {}) do
    TV.actions[key] = {
      cmd = function(t)
        if def.template:find("%t", 1, true) then
          return (def.template:gsub("%%t", commandArg(t.name)))
        end
        return def.template
      end,
      label   = def.label,
      color   = def.color,
      tooltip = "Custom: " .. def.template,
    }
  end
end

function TV.defineAction(key, label, color, template)
  if not key or key == "" or not template or template == "" then return false end
  TV.config.custom_actions[key] = {
    label    = (label and label ~= "") and label or key,
    color    = (color and color ~= "") and color or "204,204,204",
    template = template,
  }
  applyCustomActions()
  return true
end

-- Reset a button set back to the true original defaults -- the "clear
-- button" Steven asked for. MyDSL.copyArray() (MyDSL_DataLayer.lua, added
-- 2026-07-11, code-review reuse finding) copies the values, not the
-- reference, so a later mobset/playerset call can't accidentally mutate
-- TV.defaults itself.
function TV.resetButtons(kind)
  if kind == "mob" then
    TV.config.mob_buttons = MyDSL.copyArray(TV.defaults.mob_buttons)
  elseif kind == "player" then
    TV.config.player_buttons = MyDSL.copyArray(TV.defaults.player_buttons)
  end
end


------------------------------------------------------------------------
-- Config persistence
------------------------------------------------------------------------

-- loadConfig()/saveConfig() -- character-bound button-set persistence
-- only. fontSize moved OUT to MyDSL.Windows' shared profile-level store
-- 2026-07-11 (see TV.config.fontSize's own comment above) -- no longer
-- read or written here.
--
-- REAL BUG, found live 2026-07-11: Mudlet's real table.load(file, target)
-- does not return anything -- it unpickles INTO an explicit second-
-- argument table (confirmed in Mudlet's own bundled source). This used
-- to call table.load(configFile()) with no second argument, so `loaded`
-- was always nil -- button-set customizations never actually survived a
-- restart either, same root cause as the font-size bug (see
-- MyDSL_DataLayer.lua's MyDSL.load() for the full writeup).
local function loadConfig()
  local f = io.open(configFile(), "r")
  local data
  if f then
    f:close()
    local loaded = {}
    local ok = pcall(table.load, configFile(), loaded)
    if ok and next(loaded) then data = loaded end
  end
  echo("[MyDSL.TargetView] loadConfig(): " .. configFile() ..
       (data and " -> loaded" or " -> no saved file yet") .. "\n")
  if data then
    if type(data.mob_buttons) == "table" and #data.mob_buttons == 6 then
      TV.config.mob_buttons = data.mob_buttons
    end
    if type(data.player_buttons) == "table" and #data.player_buttons == 6 then
      TV.config.player_buttons = data.player_buttons
    end
    if type(data.custom_actions) == "table" then
      TV.config.custom_actions = data.custom_actions
    end
  end
  applyCustomActions()
end

local function saveConfig()
  pcall(table.save, configFile(), {
    mob_buttons    = TV.config.mob_buttons,
    player_buttons = TV.config.player_buttons,
    custom_actions = TV.config.custom_actions,
  })
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

-- markPoisoned(rawName) -- real, confirmed, generic third-person poison-
-- onset text ("<mob> looks very ill.", 8 occurrences across multiple
-- sessions in log/, any mob, any poison source -- unlike weaken/slow/
-- blindness/plague, which have zero real observer-side text anywhere,
-- see docs/TODO.md's PAUSED/Design Ideas sections). Only marks the flag
-- when it matches the CURRENT target -- this is an "assist, don't
-- decide" indicator (Focus already shows this), not a new auto-target
-- mechanism.
function MyDSL.Target.markPoisoned(rawName)
  local t = MyDSL.State.target
  if not t or not rawName then return end
  local key = rawName:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
  if key ~= t.key then return end
  t.poisoned_at = os.time()
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

-- listField(label, tbl, color) -- "Immune: charm poison" or "Immune: (none)"
-- -- same convention MyDSL_CreatureReference.lua's listLine() already uses
-- for these exact fields, just inline (one row, not one per field) since
-- Target's real footprint (422x186, confirmed via "focus status") is much
-- tighter than the Bestiary window's own layout.
local function listField(label, tbl, color)
  if type(tbl) == "table" and #tbl > 0 then
    return string.format("<136,136,136>%s: <%s>%s<r>", label, color or "68,204,170", table.concat(tbl, " "))
  end
  return string.format("<136,136,136>%s: <68,68,68>(none)<r>", label)
end

-- conditionBarColor -- added 2026-07-11 per Steven ("should have
-- healthbars that work on the enemies health message"), colored by the
-- same 7-tier order MyDSL.getTargetCondition() returns (7=excellent,
-- 1=awful). Real live combat-condition data only -- never fabricated;
-- callers pass nil order when there's no fight data for this target yet.
local function conditionBarColor(order)
  if not order then return "68,68,68" end
  if order >= 6 then return "68,204,68" end
  if order >= 3 then return "204,170,68" end
  return "204,68,68"
end

-- healthFraction(percentStr, order) -- turns MyDSL.getTargetCondition()'s
-- percent-range text ("75-89%") into a 0-1 fill fraction for the
-- nameplate's gradient background, using the range's midpoint for better
-- fidelity than the coarse 7-tier order; falls back to order/7 if the
-- text doesn't parse (defensive -- shouldn't happen for any of the 7 real
-- CONDITION_PERCENT values in MyDSL_DataLayer.lua).
local function healthFraction(percentStr, order)
  if percentStr then
    local lo, hi = percentStr:match("^(%d+)%-(%d+)%%$")
    if lo and hi then return ((tonumber(lo) + tonumber(hi)) / 2) / 100 end
    local single = percentStr:match("^(%d+)%%$")
    if single then return tonumber(single) / 100 end
  end
  if order then return order / 7 end
  return nil
end

------------------------------------------------------------------------
-- Graphical buttons -- added 2026-07-11, per Steven ("could we make a
-- mor graphical focus window... maybe research buttons in mudlet
-- manual?"). Confirmed via Mudlet's own bundled source (GeyserButton.lua/
-- GeyserLabel.lua) that Geyser.Label has real native click support
-- (setClickCallback/setOnEnter/etc.) and Geyser.Button (Label-based) is a
-- ready-made, fully CSS-styleable clickable widget -- an earlier claim in
-- this file's own change history that this wasn't possible without
-- switching to an Adjustable.Container was wrong; confirmed corrected
-- version: the container type is unrelated, any Geyser container
-- (including this window's existing UserWindow) can parent a Button.
-- Kept as a UserWindow, NOT converted to Adjustable.Container, per
-- Steven's explicit "keep it as-is for now."
--
-- The [M]/[P] toggle, [X] clear, and the 6 action-grid slots are now real
-- Geyser.Button widgets, created ONCE in TV.init() and updated in place
-- by render() (label/color/tooltip/click-handler/visibility), instead of
-- being re-emitted as dechoLink() text every redraw. Everything else
-- (identity text, creaturelore stats, consider-lines) stays exactly as
-- it was, in plain MiniConsoles -- per Steven ("just the buttons").
------------------------------------------------------------------------

-- actionButtonCSS(colorRGB) -- a dark pill with a colored border, in the
-- action's own semantic color (attack=red, heal=green, etc.) -- these
-- colors are deliberately NOT theme-driven, same precedent already
-- recorded for HP/mana bars and Tick's danger/warn/ready palette: they
-- carry meaning independent of the active visual theme.
local function actionButtonCSS(colorRGB)
  return string.format(
    "QLabel{background-color: rgba(26,28,32,235); border: 1px solid rgb(%s); border-radius: 5px;}",
    colorRGB
  )
end

-- btnHTML(text, colorRGB, fontPt) -- inline font-size/color in the HTML
-- itself rather than relying on the QLabel stylesheet's own font-size to
-- be inherited -- this session already found once (LiveView's infoFont
-- bug) that Qt's rich-text renderer doesn't reliably do that.
local function btnHTML(text, colorRGB, fontPt)
  return string.format(
    '<div align="center" style="font-size:%dpt; font-weight:bold; color: rgb(%s);">%s</div>',
    fontPt or 11, colorRGB, text)
end

------------------------------------------------------------------------
-- Nameplate -- added 2026-07-11, per Steven ("instead of the healthbar
-- on a new line, can it overlay the mobs name and the mob name be
-- centered in the bar"). The header's plain-text name line is now a
-- Geyser.Label (like the buttons -- full CSS support confirmed via
-- GeyserLabel.lua) whose BACKGROUND is a real colored health-fill
-- gradient, with the name (+ relation tag + percent) centered on top as
-- the label's own text -- one widget, not a separate bar + separate name
-- row. Falls back to a flat neutral background with no fill when there's
-- no live combat-condition data (never fabricated).
------------------------------------------------------------------------

-- nameplateCSS(fraction, colorRGB) -- a Qt linear-gradient with two
-- coincident stops at the fill fraction to create a hard color edge
-- (standard Qt stylesheet technique for a "progress bar" look from a
-- single QLabel background), rather than a soft blend.
local function nameplateCSS(fraction, colorRGB)
  if not fraction then
    return "QLabel{background-color: rgba(30,32,36,235); border: 1px solid rgb(70,74,80); border-radius: 4px;}"
  end
  fraction = math.max(0, math.min(1, fraction))
  local stop = string.format("%.3f", fraction)
  return string.format(
    "QLabel{background: qlineargradient(x1:0,y1:0,x2:1,y2:0, stop:0 rgba(%s,220), stop:%s rgba(%s,220), stop:%s rgba(24,26,30,235), stop:1 rgba(24,26,30,235)); border: 1px solid rgb(70,74,80); border-radius: 4px;}",
    colorRGB, stop, colorRGB, stop
  )
end

-- nameplateHTML(content, fontPt) -- inline font-size, same reasoning as
-- btnHTML() above (Qt rich-text doesn't reliably inherit font-size from
-- the widget's own stylesheet).
local function nameplateHTML(content, fontPt)
  return string.format(
    '<div align="center" style="font-size:%dpt; font-weight:bold; color: rgb(255,255,255);">%s</div>',
    fontPt or 11, content)
end

-- updateActionButton(btn, label, colorRGB, tooltip, clickFn) -- pushes a
-- full visual+behavior update onto an already-created Button widget and
-- shows it. Safe to call every render() -- Button:setState("up") is what
-- actually applies .msg/.style/.tooltip together in one native redraw.
local function updateActionButton(btn, label, colorRGB, tooltip, clickFn)
  if not btn then return end
  btn.style   = actionButtonCSS(colorRGB)
  btn.msg     = btnHTML(label, colorRGB, TV.config.fontSize)
  btn.tooltip = tooltip or ""
  btn:setClickFunction(clickFn)
  btn:setState("up")
  if btn.show then btn:show() end
end

local function hideButton(btn)
  if btn and btn.hide then btn:hide() end
end

-- applyFontSize(size) -- pushes a font size onto the live stats console
-- (the header became a Label/nameplate 2026-07-11 -- its font size bakes
-- into its HTML on every render() instead, same as the buttons). fontSize
-- itself now lives in MyDSL.Windows' shared, profile-level store (see
-- TV.config.fontSize's own comment above), so there's no character-
-- identification timing to chase anymore -- this just applies whatever
-- TV.config.fontSize currently is to the live widget.
local function applyFontSize(size)
  if TV._mc.stats then TV._mc.stats:setFontSize(size) end
end

function TV.render()
  local statsMc = TV._mc and TV._mc.stats
  if not statsMc or not TV.ui or not TV.ui.nameplate then return end
  statsMc:clear()
  local t = MyDSL.State.target

  -- Nameplate: name (+ relation tag + live percent) centered on top of a
  -- real colored health-fill background -- merged 2026-07-11 per Steven
  -- ("instead of the healthbar on a new line, can it overlay the mobs
  -- name and the mob name be centered in the bar"), superseding the
  -- earlier separate plain-text header console + separate "HP:" stats
  -- row. [M]/[P]/[X] are real Button widgets (see above), positioned to
  -- the LEFT of the nameplate in the same row -- per Steven's earlier
  -- "mob/player and clear button should be on left side." The "[img]"
  -- icon placeholder stays removed (per Steven, "remove the image
  -- option").
  -- REAL BUG, broke profile load live 2026-07-11 (Steven's screenshot +
  -- error paste): "attempt to call method 'setState' (a nil value)" at
  -- this block. `:setState()` only exists on Geyser.Button (its own
  -- state-machine method, confirmed in GeyserButton.lua -- Geyser.Button.
  -- parent = Geyser.Label, but setState is defined on Button, not
  -- inherited FROM Label) -- the nameplate is a plain Geyser.Label, which
  -- has no such method. Copy-pasted the Button-update pattern
  -- (`.style`/`.msg` fields + `:setState("up")`) from updateActionButton()
  -- without checking Label actually supports it. Fixed by calling
  -- Label's own real methods directly instead -- confirmed both exist via
  -- Mudlet's actual bundled source (GeyserLabel.lua): `:setStyleSheet(css)`
  -- and `:echo(message)`.
  local condLabel, condPercent, condOrder = nil, nil, nil
  if t and t.name and MyDSL.getTargetCondition then
    condLabel, condPercent, condOrder = MyDSL.getTargetCondition(t.name)
  end

  if not t or not t.name then
    TV.ui.nameplate:setStyleSheet(nameplateCSS(nil, nil))
    TV.ui.nameplate:echo(nameplateHTML("(no target)", TV.config.fontSize))
    hideButton(TV.ui.mp)
    hideButton(TV.ui.clear)
  else
    local rel = dslColorRelation(t.name)
    local relHTML = ""
    if rel == "friend" then relHTML = ' <span style="color:rgb(0,200,0);">[Friend]</span>'
    elseif rel == "enemy" then relHTML = ' <span style="color:rgb(200,60,60);">[Enemy]</span>' end

    local pctHTML = ""
    if condPercent then
      pctHTML = ' <span style="font-weight:normal; color:rgb(220,220,220);">' .. condPercent .. '</span>'
    end

    local frac = healthFraction(condPercent, condOrder)
    TV.ui.nameplate:setStyleSheet(nameplateCSS(frac, conditionBarColor(condOrder)))
    TV.ui.nameplate:echo(nameplateHTML(t.name .. relHTML .. pctHTML, TV.config.fontSize))

    local type_tag   = t.is_mob and "M" or "P"
    local type_color = t.is_mob and "204,136,68" or "136,170,255"
    updateActionButton(TV.ui.mp, type_tag, type_color, "Switch mob/player mode", MyDSL.Target.toggle)
    updateActionButton(TV.ui.clear, "X", "170,68,68", "Clear target", MyDSL.Target.clear)
  end

  -- 6 action buttons -- real Geyser.Button widgets now, updated in place;
  -- an empty slot (unassigned, or attack-guarded against a group member)
  -- hides its button instead of leaving a blank text gap.
  if t and t.name then
    local buttons = t.is_mob and TV.config.mob_buttons or TV.config.player_buttons
    local ownMember = isOwnGroupMember(t.name)
    for i = 1, 6 do
      local key = buttons[i]
      local act = key and TV.actions[key]
      if act and act.attack and ownMember then act = nil end
      if act then
        updateActionButton(TV.ui.action[i], act.label, act.color, act.tooltip .. ": " .. t.name,
          function() MyDSL.Target.doAction(key) end)
      else
        hideButton(TV.ui.action[i])
      end
    end
  else
    for i = 1, 6 do hideButton(TV.ui.action[i]) end
  end

  -- Creaturelore stat block -- reads MyDSL.CreatureLore.get()
  -- (MyDSL_CreatureLore.lua's persistent, cross-session DB). Shows any
  -- creature lore'd in ANY past session, not just this one, the instant
  -- it becomes the target. The live health bar is no longer a separate
  -- row here -- it moved into the nameplate above, 2026-07-11.
  -- Race/Align/Lvl/Base-HP/Magic/Dmg/Tactics/Immune/Resist/Vuln/Affects.
  -- Align narrowed to just good/evil/neutral, and Lvl (DSL's own "cycle
  -- of training" number) + Tactics (Offensive Tactics list) added
  -- 2026-07-11 per Steven ("only need to capture the good evil neutral
  -- for align... we arent capturing the offensive tactics and level of
  -- the mobs"). Kills/Avg XP/Last XP deliberately omitted -- confirmed
  -- via codebase grep that nothing anywhere currently tracks per-creature
  -- kill counts or XP (the old data file with those fields is a dead
  -- month-old leftover); showing them would just be permanently-empty
  -- placeholders.
  if t and t.name then
    local tKey = t.key or normalizeName(t.name)
    local lore = MyDSL.CreatureLore and MyDSL.CreatureLore.get(tKey)

    if lore then
      -- Rule line removed 2026-07-16, per Steven ("focus needs... lose
      -- the ---- lines for more space").
      -- Real bug, found live 2026-07-12 via screenshot ("Race: tinker
      -- gnomeLvl: 45", no space at all): %-12s only guarantees a MINIMUM
      -- width, it doesn't add padding once the value is already at or
      -- past that width -- "tinker gnome" is exactly 12 characters, so it
      -- got zero trailing spaces and ran straight into "Lvl:". Widened to
      -- %-14s so even a race name this long still gets a real gap.
      tvLog(statsMc, string.format(
        "<136,136,136>Race: <204,204,204>%-14s<136,136,136>Lvl: <204,204,204>%-4s<136,136,136>Align: <204,204,204>%s<r>\n",
        tostring(lore.race or "?"),
        lore.trainingCycle and tostring(lore.trainingCycle) or "?",
        tostring(lore.alignmentText or "?")))
      tvLog(statsMc, string.format("<136,136,136>Base HP: <204,204,204>%-10s<136,136,136>Magic: <204,204,204>%s<r>\n",
        lore.hp and tostring(lore.hp) or "?", lore.magic and tostring(lore.magic) or "?"))
      if lore.damage then
        tvLog(statsMc, string.format("<136,136,136>Dmg: <204,204,204>%s %s<r>\n",
          lore.damage, tostring(lore.damageType or "")))
      end
      if lore.tactics and #lore.tactics > 0 then
        tvLog(statsMc, listField("Tactics", lore.tactics, "255,204,68") .. "\n")
      end
      tvLog(statsMc, listField("Immune", lore.immunities, "68,204,170") .. "  " ..
                listField("Resist", lore.resists, "68,204,170") .. "\n")
      tvLog(statsMc, listField("Vuln", lore.vulns, "204,68,68") .. "  " ..
                listField("Affects", lore.affects, "170,170,255") .. "\n")
    end
  end

  -- Line: poisoned flag -- real confirmed generic onset text ("<mob>
  -- looks very ill."), assist-only (mirrors what's already visible on
  -- the main console, never decides anything for the player).
  if t and t.poisoned_at then
    tvLog(statsMc, "<170,68,204>Poisoned<r>\n")
  end

  -- Line: consider output (dim grey, cleared on target change)
  for _, line in ipairs(TV._consider_lines) do
    tvLog(statsMc, string.format("<136,136,136>%s<r>\n", line))
  end
end


------------------------------------------------------------------------
-- init()  —  safe to re-call on reload
------------------------------------------------------------------------

function TV.init()
  -- Ensure the Focus UserWindow exists. Kept a UserWindow, NOT converted
  -- to Adjustable.Container, per Steven's explicit "keep it as-is for
  -- now" when asked whether graphical buttons required that change (they
  -- don't -- confirmed via Mudlet's own source that any Geyser container
  -- can parent a Button, same as this UserWindow already parents its
  -- MiniConsoles).
  local targetWin = MyDSL.Windows.ensure(TARGET_WIN)
  -- Fixed 2026-07-11, per Steven ("fix all window titles/names").
  if targetWin and targetWin.setTitle then pcall(function() targetWin:setTitle("-= Focus =-") end) end

  -- Layout (percent of the window): header row y=0-10%, button grid two
  -- rows y=11-20% / 21-30%, stats console y=32-100%. Button-grid height
  -- halved 2026-07-11 per Steven ("we need to reduce those buttons by
  -- half") -- the first graphical-button pass used the same 17%-per-row
  -- height the old dechoLink() text rows happened to occupy, which turned
  -- out to visually dominate the window and crowd the stats console below
  -- it (confirmed live: the Race/Align row was scrolling out of view).
  -- The freed space goes to the stats console (44% -> 68%).
  if not TV._mc.stats then
    TV._mc.stats = Geyser.MiniConsole:new({
      name      = TARGET_MC .. "_Stats",
      x = "0%", y = "32%", width = "100%", height = "68%",
      fontSize  = TV.config.fontSize,
      scrollBar = false,
    }, targetWin)
  end
  if TV._mc.stats then TV._mc.stats:setFontSize(TV.config.fontSize) end

  -- Adaptive word wrap, per Steven ("focus needs wrapping text for
  -- stats") -- same real Mudlet API already proven working for History
  -- (MyDSL_RouteHelper.lua). The constructor above already takes a
  -- fontSize option, but the very next line's redundant setFontSize()
  -- call (pre-existing, not new here) is itself evidence that option
  -- alone wasn't reliable -- shared helper (MyDSL_WindowRegistry.lua)
  -- handles the "must run after setFontSize()" ordering and the
  -- per-console once-only guard.
  MyDSL.Windows.enableAdaptiveWrap(TV._mc.stats)

  -- Theme-driven background/font for the stats console. fontSize is the
  -- persisted user override (TV.config.fontSize, added 2026-07-11 per
  -- Steven -- "i need to be able to adjust the font like other windows"),
  -- passed through as styleConsole()'s fontSizeOverride exactly like
  -- CombatView's CV.config.fontSize, so a theme switch changes color/
  -- font-family without clobbering a size the user explicitly set. The
  -- nameplate (below) isn't theme-styled -- same "semantic, not theme-
  -- driven" precedent as the action buttons' colors.
  if MyDSL.Theme and MyDSL.Theme.styleConsole then
    MyDSL.Theme.styleConsole(TV._mc.stats, TARGET_WIN, TV.config.fontSize)
  end

  -- Graphical buttons + nameplate -- added 2026-07-11, per Steven ("could
  -- we make a mor graphical focus window... maybe research buttons in
  -- mudlet manual?" / "Just the buttons, keep it as-is for now" /
  -- "instead of the healthbar on a new line, can it overlay the mobs
  -- name"). Created ONCE here (persist across reloads via the TV.ui =
  -- TV.ui or {} guard, same pattern as TV._mc) and updated in place by
  -- render() -- see updateActionButton()/hideButton()/nameplateCSS()
  -- above.
  TV.ui = TV.ui or {}
  if not TV.ui.nameplate then
    TV.ui.nameplate = Geyser.Label:new({
      name = TARGET_WIN .. "_Nameplate", x = "18%", y = "0%", width = "82%", height = "10%",
    }, targetWin)
  end
  if not TV.ui.mp then
    TV.ui.mp = Geyser.Button:new({
      name = TARGET_WIN .. "_MP", x = "0%", y = "0%", width = "8%", height = "10%",
    }, targetWin)
  end
  if not TV.ui.clear then
    TV.ui.clear = Geyser.Button:new({
      name = TARGET_WIN .. "_Clear", x = "8.5%", y = "0%", width = "8%", height = "10%",
    }, targetWin)
  end
  TV.ui.action = TV.ui.action or {}
  for i = 1, 6 do
    if not TV.ui.action[i] then
      local row = math.floor((i - 1) / 3)
      local col = (i - 1) % 3
      TV.ui.action[i] = Geyser.Button:new({
        name   = TARGET_WIN .. "_Action" .. i,
        x      = tostring(col * 34) .. "%",
        y      = tostring(11 + row * 10) .. "%",
        width  = "32%",
        height = "9%",
      }, targetWin)
    end
  end

  -- Register target.updated handler (for external setters).
  TV._handlers.targetUpdated = registerAnonymousEventHandler(
    "MyDSL.target.updated",
    function() TV.render() end
  )

  -- REAL BUG, found live 2026-07-11 from Steven's screenshot + real
  -- logs during an actual fight ("bar isnt working during a fight
  -- either"): TV.render() was ONLY ever triggered by target/lore/theme
  -- changes -- nothing re-rendered when combat-condition data itself
  -- changed. MyDSL.parseCombatConditionLine() (MyDSL_DataLayer.lua) DOES
  -- correctly update MyDSL.State.combat.active[key].target_condition on
  -- every "X is in awful condition" line (confirmed: the screenshot's
  -- main console shows several real ones for the exact target Focus had
  -- selected) -- but with no listener telling Focus to redraw, that data
  -- just sat there unseen the entire fight; the window looked identical
  -- from the moment the target was set until it was cleared, regardless
  -- of anything happening in combat. Fixed the same way LiveView/
  -- AffectsView already solved this exact class of problem (see their own
  -- "Timer consolidation" history): subscribe to MyDSL.Timers.Slow, the
  -- shared 1/sec-throttled heartbeat (MyDSL_TickSource.lua) already used
  -- for "redraw anything whose underlying data can change outside of a
  -- direct user action." TargetView had never subscribed to any periodic
  -- heartbeat at all before this.
  TV._handlers.timersSlow = registerAnonymousEventHandler(
    "MyDSL.Timers.Slow",
    function() TV.render() end
  )

  -- Refresh when fresh creaturelore arrives -- added 2026-07-11 alongside
  -- the creaturelore stat block. Confirmed real: MyDSL.endCreatureLore()
  -- calls MyDSL.emit("creaturelore"), which raises exactly this event
  -- (MyDSL_DataLayer.lua's MyDSL.emit() builds "MyDSL." .. section ..
  -- ".updated" -- MyDSL_CreatureReference.lua already listens for the
  -- same event this same way).
  TV._handlers.loreUpdated = registerAnonymousEventHandler(
    "MyDSL.creaturelore.updated",
    function() TV.render() end
  )

  -- Auto-advance/clear on target death -- added 2026-07-11, per Steven's
  -- explicit choice when asked directly ("Auto-advance to next mob in
  -- room" over "always just clear"). Listens for the dedicated
  -- MyDSL.combat.died event (MyDSL_DataLayer.lua's parseCombatDeathLine(),
  -- added alongside this) rather than the generic MyDSL.combat.ended
  -- event, since that one also fires for flee/rescue -- only a real death
  -- should trigger this. Only acts if the creature that died IS the
  -- current Focus target (someone else's kill nearby shouldn't touch our
  -- selection). Picks any other mob still listed in Right Here/Scan --
  -- same data RightHere's own click-to-target links already use -- or
  -- clears if none remain. Still never sends a game command: this only
  -- changes which entry OUR OWN UI has selected, exactly like a Right
  -- Here click would.
  TV._handlers.combatDied = registerAnonymousEventHandler(
    "MyDSL.combat.died",
    function(_, payload)
      local t = MyDSL.State.target
      if not t or not payload or not payload.key then return end
      local tKey = t.key or normalizeName(t.name)
      if tKey ~= payload.key then return end

      local scan = MyDSL.State and MyDSL.State.scan
      local nextMob = nil
      if scan and scan.rightHere then
        for key, entry in pairs(scan.rightHere) do
          if entry.is_mob and key ~= payload.key then
            nextMob = entry
            break
          end
        end
      end

      if nextMob then
        MyDSL.Target.set(nextMob.display, true, "auto-advance")
      else
        MyDSL.Target.clear()
      end
    end
  )

  TV._handlers.themeChanged = registerAnonymousEventHandler(
    "MyDSL.theme.changed",
    function()
      if MyDSL.Theme and MyDSL.Theme.styleConsole then
        MyDSL.Theme.styleConsole(TV._mc.stats, TARGET_WIN, TV.config.fontSize)
      end
    end
  )

  -- Re-load once the real character is known -- fixed 2026-07-07. The
  -- loadConfig() call below runs at script-boot time, which on a
  -- genuinely fresh Mudlet start happens before login, so it loads
  -- "Unknown"'s button config (or bare defaults) and would otherwise
  -- never pick up this character's real saved button layout.
  -- MyDSL_DataLayer.lua's gmcp.login_data handler raises
  -- "MyDSL.character.identified" once the real name is known. fontSize is
  -- no longer character-bound (2026-07-11, see TV.config.fontSize's own
  -- comment) so it doesn't need re-loading here anymore -- loadConfig()
  -- now only concerns the button sets.
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
  -- output. Only two difficulty tiers had a confirmed real example in this
  -- profile's own corpus at the time.
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
  -- Remaining 4 of the real 6-tier ladder, added 2026-07-16 -- confirmed
  -- via the PNP sibling profile's own log corpus (../Dark & Shattered
  -- Lands - PNP/log/, DSL2's own corpus had zero examples of these rarer
  -- tiers), same DSL command, same text: "The perfect match!" (weakest
  -- mob, no name prefix -- captureConsider() just stores the raw line,
  -- doesn't need to parse a name out of it, so a nameless line works
  -- exactly the same as a named one), "<mob> says 'Do you feel lucky,
  -- punk?'.", "<mob> laughs at you mercilessly.", and "Death will thank
  -- you for your gift." (strongest mob, also no name prefix).
  TV._triggers.considerPerfectMatch = tempRegexTrigger(
    "^The perfect match!$",
    function()
      if MyDSL and MyDSL.Target then
        MyDSL.Target.captureConsider(getCurrentLine())
      end
    end
  )
  TV._triggers.considerFeelLucky = tempRegexTrigger(
    "^[A-Z][\\w' -]*? says 'Do you feel lucky, punk\\?'\\.$",
    function()
      if MyDSL and MyDSL.Target then
        MyDSL.Target.captureConsider(getCurrentLine())
      end
    end
  )
  TV._triggers.considerLaughsMercilessly = tempRegexTrigger(
    "^[A-Z][\\w' -]*? laughs at you mercilessly\\.$",
    function()
      if MyDSL and MyDSL.Target then
        MyDSL.Target.captureConsider(getCurrentLine())
      end
    end
  )
  TV._triggers.considerDeathThanksYou = tempRegexTrigger(
    "^Death will thank you for your gift\\.$",
    function()
      if MyDSL and MyDSL.Target then
        MyDSL.Target.captureConsider(getCurrentLine())
      end
    end
  )

  -- Poison-onset flag, real generic pattern confirmed via log/ corpus
  -- (see docs/DSL_CommandRef.md) -- gagged nowhere, this is display-only
  -- (not gagged/moved -- "move text don't fabricate it" only applies to
  -- redirecting text between windows, and this line already belongs on
  -- the main console; here it's just also mirrored as a Focus indicator).
  TV._triggers.poisonOnset = tempRegexTrigger(
    "^([A-Z][\\w' -]*?) looks very ill\\.$",
    function()
      if MyDSL and MyDSL.Target then
        MyDSL.Target.markPoisoned(matches[2])
      end
    end
  )

  -- Aliases -- renamed 2026-07-11, command-surface retrofit (docs/TODO.md
  -- "OPEN — Command-surface retrofit"), per Steven: "consistent across all
  -- commands, and human speak/readable (in the same style as DSL
  -- commands)." Dropped the "mydsl" prefix, but NOT onto bare "target" --
  -- confirmed via DSL_Helpfiles/target.txt this collides with a real
  -- swashbuckler combat skill ("target head/body/legs"); a bare
  -- "^target (.+)$" catch-all would have silently swallowed that skill
  -- before it ever reached the server. Renamed the whole module's command
  -- root to "focus" instead (Steven's choice, confirmed no collision in
  -- DSL_Helpfiles) -- applied consistently to every sub-command, not just
  -- the one that had to change, per the "consistent across all commands"
  -- ask. Old "mydsl target ..." forms are gone, not kept as a fallback --
  -- this is for general use, not just Steven's own muscle memory.
  --
  -- TV._focusReserved -- fixed 2026-07-11, code-review finding: this used
  -- to be a table hardcoded INSIDE the "focus (.+)$" catch-all's own alias
  -- body, completely independent of the specific sub-command aliases below
  -- it -- exactly the kind of two-list desync that already caused this
  -- same bug once before (the pre-rename version of this guard only
  -- excluded "clear", missing 3 other reserved words). Now built on the
  -- module table, with each specific sub-command alias immediately below
  -- adding its own first word right next to its own registration --
  -- forgetting to add a new sub-command's word here is now a one-line,
  -- local omission at the exact point of the new code, not a separate,
  -- easy-to-forget list elsewhere in the file.
  TV._focusReserved = { clear = true }
  TV._aliases.targetSet = tempAlias(
    "^focus clear$",
    "if MyDSL and MyDSL.Target then MyDSL.Target.clear() end"
  )
  -- Real bug found and fixed 2026-07-11 while renaming this: this bare
  -- catch-all ALSO matches every specific sub-command below it ("focus
  -- mobset ...", "focus playerset ...", "focus mobset reset", "focus
  -- action ..."), since ".+" matches any of their arguments too -- Mudlet
  -- fires every alias whose pattern matches, not just the most specific
  -- one, so a real "focus mobset murder consider ..." command was ALSO
  -- silently setting the target to a mob literally named "mobset murder
  -- consider ..." every single time (confirmed via Python re against all
  -- 7 patterns: 6 of 7 specific commands multi-matched this one). Existed
  -- under the old "mydsl target (.+)$" name too, just never surfaced --
  -- the old guard only excluded "clear" by exact match, missing every
  -- other reserved sub-command word. Fixed by checking the first word
  -- against the full reserved list instead of just "clear".
  TV._aliases.targetClear = tempAlias(
    "^focus (.+)$",
    [[
      local name = matches[2]
      local firstWord = name:match("^(%S+)")
      local isReserved = MyDSL and MyDSL.TargetView and MyDSL.TargetView._focusReserved and MyDSL.TargetView._focusReserved[firstWord]
      if not isReserved and MyDSL and MyDSL.Target then
        local function isM(n)
          return n:match("^[Aa]n? ") ~= nil or n:match("^[Tt]he ") ~= nil
        end
        MyDSL.Target.set(name, isM(name), "manual")
      end
    ]]
  )
  TV._focusReserved.mobset = true
  TV._aliases.targetMobset = tempAlias(
    "^focus mobset\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)$",
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
  TV._focusReserved.playerset = true
  TV._aliases.targetPlayerset = tempAlias(
    "^focus playerset\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)$",
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
  -- "reset" variants added 2026-07-11, per Steven's "clear button" ask --
  -- separate exact-match aliases, not a conflict with the 6-arg patterns
  -- above since "reset" alone never satisfies six \S+ groups. (mobset/
  -- playerset already reserved above -- "focus mobset reset"'s first word
  -- is still "mobset", already covered, no new reserved word needed here.)
  TV._aliases.targetMobsetReset = tempAlias(
    "^focus mobset reset$",
    [[
      if MyDSL and MyDSL.TargetView then
        MyDSL.TargetView.resetButtons("mob")
        MyDSL.TargetView._saveConfig()
        echo("Mob buttons reset to defaults.\n")
      end
    ]]
  )
  TV._aliases.targetPlayersetReset = tempAlias(
    "^focus playerset reset$",
    [[
      if MyDSL and MyDSL.TargetView then
        MyDSL.TargetView.resetButtons("player")
        MyDSL.TargetView._saveConfig()
        echo("Player buttons reset to defaults.\n")
      end
    ]]
  )
  -- Define/overwrite a custom action -- added 2026-07-11, per Steven:
  -- "even non standard commands like scan, look, get item etc." Label
  -- must be quoted (allows spaces); command is everything after the
  -- color and may contain %t for the target's name, or nothing for a
  -- stateless command. Usage:
  --   focus action getitem "Get Item" 204,204,204 get %t
  --   focus action scan "Scan" 204,204,204 scan
  -- Then assign it to a slot like any built-in action name:
  --   focus mobset getitem murder consider creaturelore rescue flee
  TV._focusReserved.action = true
  TV._aliases.targetAction = tempAlias(
    "^focus action (\\S+) \"([^\"]+)\" (\\S+) (.+)$",
    [[
      if MyDSL and MyDSL.TargetView and MyDSL.TargetView.defineAction then
        local ok = MyDSL.TargetView.defineAction(matches[2], matches[3], matches[4], matches[5])
        if ok then
          MyDSL.TargetView._saveConfig()
          echo("Action '" .. matches[2] .. "' defined: " .. matches[5] .. "\n")
        else
          echo("Failed to define action -- check the syntax.\n")
        end
      end
    ]]
  )

  -- "focus status" -- added 2026-07-11, same pixel-size-report pattern as
  -- "mydsl live status" (get_width()/get_height() are real Geyser.Window
  -- methods returning the CURRENT on-screen pixel size, not a percentage).
  -- Real bug caught live the same day: forgot to reserve "status" here,
  -- so the "focus (.+)$" catch-all ALSO fired and set the actual target
  -- to a mob literally named "status" -- exactly the bug-class the
  -- _focusReserved mechanism exists to prevent (see its own comment above).
  TV._aliases.targetStatus = tempAlias(
    "^focus status$",
    [[if MyDSL and MyDSL.TargetView and MyDSL.TargetView.status then MyDSL.TargetView.status() end]]
  )
  TV._focusReserved.status = true

  -- "focus font <n>" -- added 2026-07-11 per Steven ("i need to be able
  -- to adjust the font like other windows"), matching CombatView's
  -- "mydsl combat font <n>" alias, just under this module's own "focus"
  -- command root.
  TV._focusReserved.font = true
  TV._aliases.targetFont = tempAlias(
    "^focus font (\\d+)$",
    [[if MyDSL and MyDSL.TargetView and MyDSL.TargetView.setFont then MyDSL.TargetView.setFont(matches[2]) end]]
  )

  -- Load button-set config from disk (may override defaults). fontSize
  -- is no longer loaded here -- see TV.config.fontSize's own comment.
  loadConfig()

  -- Initial render.
  TV.render()

  debugc("[MyDSL] TargetView loaded.")
end

------------------------------------------------------------------------
-- setFont(size)  —  change + persist the Target window's font size
-- Added 2026-07-11 per Steven ("i need to be able to adjust the text size
-- in the target window like other windows"), matching CombatView's
-- CV.setFont() exactly.
------------------------------------------------------------------------

function TV.setFont(size)
  size = tonumber(size)
  if not size then echo("usage: focus font <size>\n"); return end
  TV.config.fontSize = size
  applyFontSize(size)
  -- Persist to the shared, profile-level store (2026-07-11) instead of
  -- TargetView's own now-removed character-bound fontSize field.
  MyDSL.Windows.setFontSize(TARGET_WIN, size)
  -- Re-render so any currently-visible buttons pick up the new size too
  -- -- their label HTML bakes in an explicit font-size (see btnHTML()),
  -- so just calling setFontSize() on a console doesn't touch them.
  TV.render()
  echo("Target font=" .. tostring(size) .. "\n")
end

function TV.status()
  local win = MyDSL.Windows and MyDSL.Windows.get and MyDSL.Windows.get(TARGET_WIN)
  local pw, ph = "?", "?"
  if win then
    local ok1, w = pcall(function() return win:get_width() end)
    local ok2, h = pcall(function() return win:get_height() end)
    if ok1 and w then pw = w end
    if ok2 and h then ph = h end
  end
  local tName = MyDSL.State.target and MyDSL.State.target.name
  echo("[MyDSL.TargetView] pixelSize=" .. tostring(pw) .. "x" .. tostring(ph) ..
       "; current=" .. tostring(tName) ..
       "; is_mob=" .. tostring(MyDSL.State.target and MyDSL.State.target.is_mob) .. "\n")

  -- HP-bar diagnostic -- added 2026-07-11 per Steven ("healthbar is still
  -- missing"): getTargetCondition() only shows a bar when this target has
  -- a live entry in MyDSL.State.combat.active, and there's no way to see
  -- that table's real state from the UI otherwise. Prints the exact key
  -- being looked up, whether an active-combat entry exists for it, and
  -- (if so) the raw target_condition value -- so a live report tells us
  -- directly whether this is "no active-combat entry" (fight already
  -- ended/never started tracking) vs. "entry exists but condition never
  -- got set" (a real parsing bug) instead of guessing from a screenshot.
  if tName and MyDSL.getTargetCondition then
    local label, percent, order = MyDSL.getTargetCondition(tName)
    local key = tName:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
    local entry = MyDSL.State.combat and MyDSL.State.combat.active and MyDSL.State.combat.active[key]
    echo("[MyDSL.TargetView] condition key='" .. key .. "'; active_entry=" ..
         tostring(entry ~= nil) .. "; raw_target_condition=" ..
         tostring(entry and entry.target_condition) ..
         "; getTargetCondition=" .. tostring(label) .. "/" .. tostring(percent) .. "/" .. tostring(order) .. "\n")
  end

  -- Font-size 3-way diagnostic -- added 2026-07-11, per Steven ("are the
  -- settings loading at creating from save files or they saving and
  -- never reading/updating?"). Reports the SAME value at 3 different
  -- points in the pipeline, so a live run pinpoints exactly which stage
  -- is wrong instead of guessing:
  --   disk   = what's actually saved in MyDSL_windowfonts.lua right now
  --            (re-read from disk, not from memory, in case something is
  --            silently failing to persist).
  --   memory = TV.config.fontSize -- what THIS module currently believes
  --            the value is (should equal disk, since it's read directly
  --            from the shared store at load time).
  --   live   = Geyser.MiniConsole:getFontSize() -- Mudlet's own real,
  --            live getter (confirmed present in Mudlet's bundled
  --            GeyserMiniConsole.lua) querying what the ACTUAL rendered
  --            widget is using right now, independent of what our own
  --            config thinks. If disk/memory match but live doesn't,
  --            that's a real "loaded correctly but never applied to the
  --            widget" bug; if disk/memory themselves disagree, that's a
  --            real load bug.
  local diskVal = "?"
  if MyDSL.Windows and MyDSL.Windows.loadFontSizes and MyDSL.Windows.fontSizes then
    local before = MyDSL.Windows.fontSizes[TARGET_WIN]
    MyDSL.Windows.loadFontSizes()  -- force a fresh re-read from disk, not memory
    diskVal = tostring(MyDSL.Windows.fontSizes[TARGET_WIN])
    -- Restore the in-memory table to whatever it actually was, in case
    -- disk and memory had legitimately diverged -- this is a read-only
    -- diagnostic, it must not silently "fix" anything by side effect.
    if before ~= nil then MyDSL.Windows.fontSizes[TARGET_WIN] = before end
  end
  local liveVal = "?"
  if TV._mc.stats and TV._mc.stats.getFontSize then
    local ok, size = pcall(function() return TV._mc.stats:getFontSize() end)
    if ok then liveVal = tostring(size) end
  end
  echo("[MyDSL.TargetView] font: disk=" .. diskVal ..
       "; memory(TV.config.fontSize)=" .. tostring(TV.config.fontSize) ..
       "; live(widget getFontSize)=" .. liveVal .. "\n")
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
