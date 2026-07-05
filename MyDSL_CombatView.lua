-- =============================================================================
-- MyDSL_CombatView.lua  --  Layer 3 Phase B: Combat round condenser
-- =============================================================================
-- Passive display only. Listens for combat events from DataLayer and renders
-- two views in MyDSL_Combat:
--   1. Live condensed round log — one line per (attacker,target,noun) per round
--   2. Per-target fight-summary block — rendered on death/flee/rescue
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

-- Config table. Redesigned 2026-07-05 to match PNP's actual tested behavior
-- (DSL_PNP_Battle.lua handle_damage(): every non-miss damage line gets an
-- UNCONDITIONAL live echo into the battle window, regardless of any show_*
-- flag -- those flags only ever gated the *main console* copy in PNP, never
-- the battle window itself). Ours now works the same way:
--   - gag_combat = true (default): raw line deleted from main console;
--     always shown, live, in the Combat window -- no per-category opt-in
--     needed for damage.
--   - gag_combat = false: raw line left completely untouched in main
--     console (no reformatted duplicate added -- "echo_to_main" removed,
--     it doesn't fit this model).
--   - show_miss / show_evade: still opt-in for the Combat window itself,
--     matching PNP (misses are never in its live feed at all; evasion is
--     tracked but never streamed live either, only in round/fight summaries).
--   - show_flag / show_condition: unchanged, still opt-in.
-- Use "mydsl combat show <key>" / "mydsl combat hide <key>" to toggle.
CV.config = CV.config or {}
if CV.config.show_miss           == nil then CV.config.show_miss           = false end
if CV.config.show_evade          == nil then CV.config.show_evade          = false end
if CV.config.show_flag           == nil then CV.config.show_flag           = false end
if CV.config.show_condition      == nil then CV.config.show_condition      = false end
if CV.config.gag_combat          == nil then CV.config.gag_combat          = true  end

-- Window / MiniConsole name constants.
local COMBAT_WIN = "MyDSL_Combat"
local COMBAT_MC  = "MyDSL_Combat_MC"

-- Flag-code → display tag map (single-letter codes, gold text).
local FLAG_TAGS = {
  C = "❄", F = "🔥", L = "⚡", H = "🩸", S = "💫",
  M = "∅",  O = "✨", U = "☠",  P = "☣",
}

-- Bracket decorations for high-tier verbs (from contract severity table).
local VERB_BRACKETS = {
  DEMOLISH     = { pre = "*** ", suf = " ***" },
  DEVASTATE    = { pre = "*** ", suf = " ***" },
  OBLITERATE   = { pre = "=== ", suf = " ===" },
  ANNIHILATE   = { pre = ">>> ", suf = " <<<" },
  ERADICATE    = { pre = "<<< ", suf = " >>>" },
  GHASTLY      = { pre = "", suf = "", things = true },
  HORRID       = { pre = "", suf = "", things = true },
  DREADFUL     = { pre = "", suf = "", things = true },
  HIDEOUS      = { pre = "", suf = "", things = true },
  INDESCRIBABLE = { pre = "", suf = "", things = true },
  UNSPEAKABLE  = { pre = "", suf = "", things = true },
}

-- Hit-rate color (mirrors GroupView hpColor thresholds for consistency).
local function hitRateColor(pct)
  if     pct >= 75 then return "68,204,68"
  elseif pct >= 50 then return "204,204,68"
  else                   return "204,68,68"
  end
end

-- Attacker display color.
local function attackerColor(aKey)
  if aKey == "you"     then return "68,204,68"   -- green: your own attacks
  elseif aKey == "unknown" then return "136,136,136"
  else return "68,136,204"                        -- blue: ally/pet
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
-- render()  —  redraws the round log from the latest round_data
------------------------------------------------------------------------
-- Called every round via "MyDSL.combat.updated". Receives the round_data
-- snapshot that DataLayer passed at the moment of flush.

-- Lua 5.1 (LuaJIT) has no goto/::label:: — use local function + return
-- instead of continue-style early exits in loops.
local function renderRoundEntry(mc, rd)
  local aKey = rd.attacker or "?"
  local tKey = rd.target   or "?"
  local noun = rd.noun     or "?"
  local verb = rd.derived_verb or "miss"

  -- Apply config filters. Damage itself (not a miss, not an evade entry) is
  -- always shown in the Combat window, unconditionally -- matching PNP,
  -- which never gated its battle-window echo on who the attacker/target was.
  if verb == "miss" and not CV.config.show_miss then return end
  if noun == "(evade)" and not CV.config.show_evade then return end

  -- Build the line.
  local aColor = attackerColor(aKey)
  local vColor = (tKey == "you") and "204,68,68" or "68,204,68"
  if verb == "miss" or noun == "(evade)" then vColor = "136,136,136" end

  local brk    = VERB_BRACKETS[verb]
  local verbTxt
  if brk and brk.things then
    verbTxt = string.format("does %s things to", verb)
  elseif brk then
    verbTxt = brk.pre .. verb .. brk.suf
  else
    verbTxt = verb
  end

  -- Flag tags for this round entry (from active entry if available).
  local flagStr = ""
  if CV.config.show_flag and rd.flags then
    for code, cnt in pairs(rd.flags) do
      local tag = FLAG_TAGS[code] or code
      flagStr = flagStr .. string.format(" <255,215,65>%s%s<r>",
        tag, cnt > 1 and "×" .. cnt or "")
    end
  end

  -- Also check lore for vulnerability cross-reference.
  if CV.config.show_flag and rd.flags and next(rd.flags) then
    local lore = MyDSL.State and MyDSL.State.creaturelore
    if lore and lore.key and tKey == lore.key then
      -- creaturelore doesn't currently parse resistances/vulnerabilities as
      -- structured fields — just store the note for future use when it does.
    end
  end

  local line = string.format(
    "<%s>%s<r> → <%s>%s<r> (%s): <%s>%s<r>%s (%d/%d)\n",
    aColor, aKey,
    "204,204,204", tKey,
    noun,
    vColor, verbTxt,
    flagStr,
    rd.hits or 0, rd.swings or 0)

  mcLog(mc, line)
end

function CV.render(roundData)
  local mc = CV._mc and CV._mc.combat
  if not mc then return end

  -- Only clear and redraw if there's something to show this round.
  if not roundData or not next(roundData) then return end

  for _, rd in pairs(roundData) do
    renderRoundEntry(mc, rd)
  end
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
  local combatWin = MyDSL.Windows.ensure(COMBAT_WIN)
  if not CV._mc.combat then
    CV._mc.combat = Geyser.MiniConsole:new({
      name      = COMBAT_MC,
      x = 0, y = 0, width = "100%", height = "100%",
      wrapWidth = 400,
      fontSize  = 10,
      scrollBar = true,
    }, combatWin)
  end
  if CV._mc.combat then CV._mc.combat:setFontSize(10) end

  -- Event handlers.
  CV._handlers.combatUpdated = registerAnonymousEventHandler(
    "MyDSL.combat.updated",
    function(_, roundData) CV.render(roundData) end)

  CV._handlers.combatEnded = registerAnonymousEventHandler(
    "MyDSL.combat.ended",
    function(_, snapshot) CV.renderSummary(snapshot) end)

  CV._handlers.combatRage = registerAnonymousEventHandler(
    "MyDSL.combat_rage",
    function(_, dmg, vamp) CV.renderRage(dmg, vamp) end)

  -- Initial state.
  if CV._mc.combat then
    CV._mc.combat:clear()
    CV._mc.combat:decho("<85,85,85>(no combat)\n")
  end

  debugc("[MyDSL] CombatView loaded.")
end


------------------------------------------------------------------------
-- Aliases
------------------------------------------------------------------------

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


------------------------------------------------------------------------
-- Boot
------------------------------------------------------------------------

CV.init()
