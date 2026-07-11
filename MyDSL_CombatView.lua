-- =============================================================================
-- MyDSL_CombatView.lua  --  Layer 3 Phase B: Combat window
-- =============================================================================
-- Passive display only. Two things happen in MyDSL_Combat:
--   1. Live per-swing feed — every non-miss damage line, appended as it
--      happens (never cleared/redrawn), matching PNP's battle_console
--      exactly: a running raw-sentence-plus-severity-score log, not a
--      per-round batch redraw. Pushed directly by DataLayer's
--      parseCombatDamageLine() via CV.appendSwing() -- see 9q in
--      MyDSL_DataLayer.lua for where these lines are built.
--   2. Per-target fight-summary block — rendered on death/flee/rescue. This
--      is OUR OWN addition (PNP has no persistent multi-fight concept at
--      all -- its battle_data resets every single round) -- kept in its
--      existing table-style format for now, to be discussed/revisited
--      separately from the "match PNP" rendering pass.
-- Never sends commands.
-- =============================================================================

MyDSL           = MyDSL           or {}
MyDSL.CombatView = MyDSL.CombatView or {}
local CV = MyDSL.CombatView

-- Safe-reload: kill old handlers/aliases before re-registering.
for _, id in pairs(CV._handlers or {}) do pcall(killAnonymousEventHandler, id) end
for _, id in pairs(CV._aliases  or {}) do pcall(killAlias, id) end

CV._handlers = {}
CV._aliases  = {}
CV._mc       = CV._mc or {}   -- persists across reloads

-- Config table -- rewritten 2026-07-05 to match PNP's actual `defaults`
-- table in DSL_PNP_Battle.lua exactly (see MyDSL_DataLayer.lua's 9q section
-- for how each flag is actually used -- gag_combat/gag_non_damage/show_*
-- gate the RAW per-swing main-console line; summarize_damage gates the
-- round-aggregate sentence to main, independently of gag_combat; the
-- Combat window itself always gets every non-miss swing unconditionally,
-- gated by neither). dam_format/summary_format are PNP's own configurable
-- token strings (%a %r %n %v %t %d %h %s %f %p) -- see battleFormat() in
-- DataLayer.
CV.config = CV.config or {}
if CV.config.gag_combat        == nil then CV.config.gag_combat        = true  end
if CV.config.gag_non_damage    == nil then CV.config.gag_non_damage    = true  end
if CV.config.show_damage       == nil then CV.config.show_damage       = false end
if CV.config.show_damage_by_me == nil then CV.config.show_damage_by_me = false end
if CV.config.show_damage_to_me == nil then CV.config.show_damage_to_me = false end
if CV.config.show_miss         == nil then CV.config.show_miss         = false end
if CV.config.show_evade        == nil then CV.config.show_evade        = false end
if CV.config.show_flag         == nil then CV.config.show_flag         = false end
if CV.config.show_condition    == nil then CV.config.show_condition    = false end
if CV.config.summarize_damage  == nil then CV.config.summarize_damage  = true  end
if CV.config.dam_format        == nil then CV.config.dam_format        = "%a%r %n %v %t (%d)" end
if CV.config.summary_format    == nil then CV.config.summary_format    = "%a%r %n %v %t (%d)" end
-- fontSize -- 2026-07-07 per Steven ("battle text needs to be a little
-- smaller 8?"): default already matched what he asked for, but it was a
-- bare hardcoded literal with no way to change/persist it. Wired into the
-- same per-window font-persistence pattern every other window uses
-- (mydsl combat font <n>), character-bound like TargetView/AffectsView.
if CV.config.fontSize          == nil then CV.config.fontSize          = 8 end

-- Window / MiniConsole name constants.
local COMBAT_WIN = "MyDSL_Combat"
local COMBAT_MC  = "MyDSL_Combat_MC"

------------------------------------------------------------------------
-- Config persistence -- character-bound, same pattern as
-- MyDSL_TargetView.lua/MyDSL_AffectsView.lua's charName()/safeFileName().
------------------------------------------------------------------------

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
  return getMudletHomeDir() .. "/MyDSL/combatview_config_" .. safeFileName(charName()) .. ".lua"
end

local function loadConfig()
  local ok, data = pcall(table.load, configFile())
  if ok and type(data) == "table" and type(data.fontSize) == "number" then
    CV.config.fontSize = data.fontSize
  end
end

local function saveConfig()
  pcall(table.save, configFile(), { fontSize = CV.config.fontSize })
end

-- Flag-code → display tag map (single-letter codes, gold text) -- used only
-- by renderSummary() below, our own fight-history addition.
local FLAG_TAGS = {
  C = "❄", F = "🔥", L = "⚡", H = "🩸", S = "💫",
  M = "∅",  O = "✨", U = "☠",  P = "☣",
}

-- Hit-rate color (mirrors GroupView hpColor thresholds for consistency) --
-- used only by renderSummary() below.
local function hitRateColor(pct)
  if     pct >= 75 then return "68,204,68"
  elseif pct >= 50 then return "204,204,68"
  else                   return "204,68,68"
  end
end

-- Writes to the window AND mirrors into MyDSL/logs/combat/ (2026-07-05:
-- Mudlet's startLogging() can't capture MiniConsole content at all, so this
-- is the only way to get combat-window text into a file for later review).
local function mcLog(mc, text)
  mc:decho(text)
  if MyDSL.logWindow then MyDSL.logWindow("combat", text) end
end


------------------------------------------------------------------------
-- appendSwing(text)  —  append one already-decorated line, never clearing
------------------------------------------------------------------------
-- Called directly (synchronously) from DataLayer's parseCombatDamageLine
-- for every non-miss swing, and from the round-flush handler for the
-- pending condition note. Matches PNP's battle_console: a running scrollable
-- log that's never cleared/redrawn per round -- only the round-summary
-- sentence (sent to MAIN console, not here) is round-scoped.

function CV.appendSwing(text)
  local mc = CV._mc and CV._mc.combat
  if not mc or not text then return end
  mcLog(mc, text)
end


------------------------------------------------------------------------
-- renderSummary(snapshot)  —  fight-summary block after kill/flee/rescue
------------------------------------------------------------------------

function CV.renderSummary(snapshot)
  local mc = CV._mc and CV._mc.combat
  if not mc or not snapshot then return end

  local display = snapshot.target_display or "?"
  local hdr = string.format("<255,204,68>── Fight summary: %s ──<r>\n", display)
  mcLog(mc, hdr)

  for aKey, weapons in pairs(snapshot.by_attacker or {}) do
    for noun, nd in pairs(weapons) do
      if noun == "(evade)" then
        if CV.config.show_evade then
          mcLog(mc, string.format("  <136,136,136>%s evaded %s (%d times)<r>\n",
            display, aKey, nd.swings or 0))
        end
      else
        local swings = nd.swings or 0
        local hits   = nd.hits   or 0
        local misses = nd.misses or 0
        local pct    = swings > 0 and math.floor(hits * 100 / swings) or 0
        local pctC   = hitRateColor(pct)
        mcLog(mc, string.format(
          "  <204,204,204>%s (%s):<r> %d hits, %d miss  <<%s>%d%%<r> landed)\n",
          noun, aKey, hits, misses, pctC, pct))
        -- Proc sub-lines
        if CV.config.show_flag then
          for code, cnt in pairs(nd.flags or {}) do
            local tag = FLAG_TAGS[code] or code
            local procPct = hits > 0 and math.floor(cnt * 100 / hits) or 0
            mcLog(mc, string.format(
              "    <255,215,65>%s %s procs: %d/%d (%d%%)<r>\n",
              tag, code, cnt, hits, procPct))
          end
        end
      end
    end
  end

  local cond = snapshot.target_condition or "unknown"
  if CV.config.show_condition then
    mcLog(mc, string.format("  <136,136,136>Condition when fight ended: %s<r>\n", cond))
  end
  mcLog(mc, "<255,204,68>────────────────────────────────────<r>\n")
end


------------------------------------------------------------------------
-- renderRage(dmg, vamp)  —  live rage-mode indicator
------------------------------------------------------------------------

function CV.renderRage(dmg, vamp)
  local mc = CV._mc and CV._mc.combat
  if not mc then return end
  mcLog(mc, string.format(
    "<255,68,68>⚠ RAGE<r>  dmg≈%.0f  vamp≈%.0f\n", dmg or 0, vamp or 0))
end


------------------------------------------------------------------------
-- init()  —  safe to re-call on reload
------------------------------------------------------------------------

function CV.init()
  loadConfig()

  local combatWin = MyDSL.Windows.ensure(COMBAT_WIN)
  if not CV._mc.combat then
    CV._mc.combat = Geyser.MiniConsole:new({
      name      = COMBAT_MC,
      x = 0, y = 0, width = "100%", height = "100%",
      wrapWidth = 400,
      fontSize  = CV.config.fontSize,
      scrollBar = true,
    }, combatWin)
  end
  if CV._mc.combat then CV._mc.combat:setFontSize(CV.config.fontSize) end

  -- Event handlers. Note: no "MyDSL.combat.updated" subscription anymore --
  -- the live per-swing feed happens immediately via CV.appendSwing(),
  -- called directly from DataLayer as each swing occurs, not batched per
  -- round (matching PNP's battle_console being a running log, not a
  -- per-round redraw).
  CV._handlers.combatEnded = registerAnonymousEventHandler(
    "MyDSL.combat.ended",
    function(_, snapshot) CV.renderSummary(snapshot) end)

  CV._handlers.combatRage = registerAnonymousEventHandler(
    "MyDSL.combat_rage",
    function(_, dmg, vamp) CV.renderRage(dmg, vamp) end)

  -- Re-load once the real character is known -- fixed 2026-07-07. The
  -- loadConfig() call above runs at script-boot time, which on a
  -- genuinely fresh Mudlet start happens before login, so it loads
  -- "Unknown"'s font size (or the bare default) and would otherwise
  -- never pick up this character's real saved font. MyDSL_DataLayer.lua's
  -- gmcp.login_data handler raises "MyDSL.character.identified" once the
  -- real name is known.
  CV._handlers.characterIdentified = registerAnonymousEventHandler(
    "MyDSL.character.identified",
    function()
      loadConfig()
      if CV._mc.combat then CV._mc.combat:setFontSize(CV.config.fontSize) end
    end
  )

  -- Initial state.
  if CV._mc.combat then
    CV._mc.combat:clear()
    CV._mc.combat:decho("<85,85,85>(no combat)\n")
  end

  debugc("[MyDSL] CombatView loaded.")
end


------------------------------------------------------------------------
-- setFont(size)  —  change + persist the Combat window's font size
------------------------------------------------------------------------

function CV.setFont(size)
  size = tonumber(size)
  if not size then echo("usage: mydsl combat font <size>\n"); return end
  CV.config.fontSize = size
  if CV._mc.combat then CV._mc.combat:setFontSize(size) end
  saveConfig()
  echo("Combat font=" .. tostring(size) .. "\n")
end


------------------------------------------------------------------------
-- Aliases
------------------------------------------------------------------------

CV._aliases.combatFont = tempAlias(
  "^mydsl combat font (\\d+)$",
  [[MyDSL.CombatView.setFont(matches[2])]])

-- CV.show()/hide()/toggle() -- added 2026-07-11, command-surface retrofit
-- (docs/TODO.md "OPEN — Command-surface retrofit"). CombatView was the one
-- module with no window-visibility function or alias at all (AffectsView/
-- MoonWeather/TickView all already had show()/hide()). Also wires PNP's
-- real bare "toggle <module>" command (confirmed native:
-- `dslpnp.aliases.register("Toggle Alias", "^toggle ([\w\.]+)...", ...)`,
-- DSL_PNP_Support.lua) using PNP's own module name for this one ("battle",
-- confirmed via DSL_PNP_Battle.lua's own `dslpnp.toggle("battle", ...)`
-- call) instead of reinventing a `mydsl combat show/hide` pair -- reuses
-- WindowRegistry's already-correct generic MyDSL.Windows.toggle(), no new
-- visibility-tracking needed.
function CV.show() if MyDSL.Windows then MyDSL.Windows.show(COMBAT_WIN) end end
function CV.hide() if MyDSL.Windows then MyDSL.Windows.hide(COMBAT_WIN) end end
function CV.toggle() if MyDSL.Windows then MyDSL.Windows.toggle(COMBAT_WIN) end end

CV._aliases.toggleBattle = tempAlias(
  "^toggle battle$",
  [[if MyDSL and MyDSL.CombatView then MyDSL.CombatView.toggle() end]])

CV._aliases.combatClear = tempAlias(
  "^mydsl combat clear$",
  [[if MyDSL and MyDSL.State and MyDSL.State.combat then
    MyDSL.State.combat.active     = {}
    MyDSL.State.combat.round_data = {}
    if MyDSL.CombatView and MyDSL.CombatView._mc and MyDSL.CombatView._mc.combat then
      MyDSL.CombatView._mc.combat:clear()
      MyDSL.CombatView._mc.combat:decho("<85,85,85>(cleared)\n")
    end
    echo("Combat state cleared.\n")
  end]])

CV._aliases.combatHistory = tempAlias(
  "^mydsl combat history$",
  [[if MyDSL and MyDSL.State and MyDSL.State.combat then
    local hist = MyDSL.State.combat.history
    if not hist or #hist == 0 then echo("No combat history.\n"); return end
    for _, snap in ipairs(hist) do
      if MyDSL.CombatView and MyDSL.CombatView.renderSummary then
        MyDSL.CombatView.renderSummary(snap)
      end
    end
  end]])

CV._aliases.combatGag = tempAlias(
  "^mydsl combat gag$",
  "if MyDSL and MyDSL.CombatView then MyDSL.CombatView.config.gag_combat = true; echo('Combat gagged.\\n') end")

CV._aliases.combatUngag = tempAlias(
  "^mydsl combat ungag$",
  "if MyDSL and MyDSL.CombatView then MyDSL.CombatView.config.gag_combat = false; echo('Combat ungagged.\\n') end")

CV._aliases.combatShow = tempAlias(
  "^mydsl combat show\\s+(\\S+)$",
  [[if MyDSL and MyDSL.CombatView then
    local key = "show_" .. matches[2]
    if MyDSL.CombatView.config[key] ~= nil then
      MyDSL.CombatView.config[key] = true
      echo("Combat show " .. matches[2] .. " = true\n")
    else echo("Unknown config key: " .. key .. "\n") end
  end]])

CV._aliases.combatHide = tempAlias(
  "^mydsl combat hide\\s+(\\S+)$",
  [[if MyDSL and MyDSL.CombatView then
    local key = "show_" .. matches[2]
    if MyDSL.CombatView.config[key] ~= nil then
      MyDSL.CombatView.config[key] = false
      echo("Combat show " .. matches[2] .. " = false\n")
    else echo("Unknown config key: " .. key .. "\n") end
  end]])

-- Direct implementation of the raw/condensed/gag 3-way main-console mode
-- Steven described (2026-07-05), mapped onto PNP's actual two independent
-- flags (see the round-flush handler's header comment in DataLayer for the
-- full mapping):
--   raw       -- gag_combat=false, summarize_damage=false: every raw swing
--                left untouched in main console, no round summary line.
--   condensed -- gag_combat=true, summarize_damage=true: raw swings hidden
--                from main, one aggregate sentence per round shown instead.
--                This is PNP's actual out-of-box default.
--   gag       -- gag_combat=true, summarize_damage=false: nothing in main
--                console at all; the Combat window still shows everything.
-- The Combat window's live per-swing feed is unaffected by this mode in all
-- three cases -- it always shows every non-miss swing, matching PNP.
--
-- Real bug fixed 2026-07-11, found via live-log verification: this alias
-- never touched show_damage/show_miss, but PNP's own handle_damage() (and
-- our port of it, MyDSL_DataLayer.lua's parseCombatDamageLine) gates
-- whether a raw swing appears on main console ENTIRELY by show_damage/
-- show_damage_by_me/show_damage_to_me/show_miss -- gag_combat/gag_non_damage
-- only ever govern evasion/flag/condition lines, never the damage line
-- itself (confirmed directly in PNP source, DSL_PNP_Battle.lua's own
-- handle_damage()/handle_evasion()/handle_flag()/handle_condition() use
-- different formulas). So "raw" mode's own promise ("every raw swing left
-- untouched") was structurally impossible before this fix -- show_damage
-- defaults false and nothing else ever set it true, so raw mode behaved
-- identically to condensed for the damage-line case specifically. Caught
-- because a real live fight (log/2026-07-11#09-23-09.html) showed
-- correctly-decorated raw swings on main console with none of the
-- mode/show aliases ever having been typed that session -- meaning
-- show_damage must have been left `true` from some earlier, unrelated
-- in-memory session (CombatView's config was never actually reset by a
-- real Mudlet restart) rather than by design.
CV._aliases.combatMode = tempAlias(
  "^mydsl combat mode\\s+(raw|condensed|gag)$",
  [[if MyDSL and MyDSL.CombatView then
    local mode = matches[2]
    local cfg = MyDSL.CombatView.config
    if mode == "raw" then
      cfg.gag_combat = false; cfg.gag_non_damage = false; cfg.summarize_damage = false
      cfg.show_damage = true; cfg.show_miss = true
    elseif mode == "condensed" then
      cfg.gag_combat = true; cfg.gag_non_damage = true; cfg.summarize_damage = true
      cfg.show_damage = false; cfg.show_miss = false
    elseif mode == "gag" then
      cfg.gag_combat = true; cfg.gag_non_damage = true; cfg.summarize_damage = false
      cfg.show_damage = false; cfg.show_miss = false
    end
    echo("Combat mode: " .. mode .. "\n")
  end]])


------------------------------------------------------------------------
-- Boot
------------------------------------------------------------------------

CV.init()
