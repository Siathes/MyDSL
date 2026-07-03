-- =============================================================================
-- MyDSL_CreatureReference.lua  --  Layer 3 Phase B: Creature lore display
-- =============================================================================
-- Listens for "MyDSL.creaturelore.updated" and renders the creature lore record
-- in the MyDSL_CreatureReference window.  The window is hidden by default and
-- auto-shows when new lore arrives.  Never sends commands or modifies the DB.
-- =============================================================================

MyDSL                  = MyDSL                  or {}
MyDSL.CreatureReference = MyDSL.CreatureReference or {}
local CR = MyDSL.CreatureReference

-- Safe-reload: kill old handlers before re-registering.
for _, id in pairs(CR._handlers or {}) do pcall(killAnonymousEventHandler, id) end
for _, id in pairs(CR._aliases  or {}) do pcall(killAlias, id) end

CR._handlers = {}
CR._aliases  = {}
CR._mc       = CR._mc or {}   -- persists to avoid duplicate MiniConsole creation

local CR_WIN = "MyDSL_CreatureReference"
local CR_MC  = "MyDSL_CreatureReference_MC"


------------------------------------------------------------------------
-- Local helpers
------------------------------------------------------------------------

-- Add thousands-separator commas: 2109 → "2,109", 1000 → "1,000".
local function formatNumber(n)
  if not n then return "?" end
  local s      = tostring(math.floor(n))
  local result = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  -- Strip leading comma that appears for numbers whose digit count is a
  -- multiple of 3 (e.g. 100 → reversed "001," → reversed back ",100").
  return result:match("^,(.+)$") or result
end

-- Returns a string of repeated char padded to width, useful for rule lines.
local function hrule(char, width)
  return string.rep(char or "─", width or 38)
end


------------------------------------------------------------------------
-- render(name)  —  draws the lore record for `name`
------------------------------------------------------------------------
-- Looks up the record in MyDSL_creaturelore.lua DB first (if loaded),
-- then falls back to MyDSL.State.creaturelore if the DB has no entry.

function CR.render(name)
  clearWindow(CR_MC)
  if not name or name == "" then
    cecho(CR_MC, "<#444444>No creature selected.\n<reset>")
    return
  end

  -- Try DB first, then live State as fallback.
  local rec = nil
  if MyDSL.CreatureLore and MyDSL.CreatureLore.get then
    local key = name:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
    rec = MyDSL.CreatureLore.get(key)
  end
  if not rec then
    rec = MyDSL.State.creaturelore
  end

  -- Header rule + name
  cecho(CR_MC, string.format("<#444444>%s\n<reset>", hrule("─")))
  cecho(CR_MC, string.format("<#ffcc44>%s<reset>\n", name))
  cecho(CR_MC, string.format("<#444444>%s\n<reset>", hrule("─")))

  if not rec then
    cecho(CR_MC, "<#888888>No lore data yet.\n<reset>")
    cecho(CR_MC, "<#666666>Click [Lore] in Target window to capture.\n<reset>")
    cecho(CR_MC, string.format("<#444444>%s\n<reset>", hrule("─")))
    return
  end

  -- Race / Alignment
  local race_str  = rec.race          or "?"
  local align_str = rec.alignmentText or "?"
  cecho(CR_MC, string.format(
    "<#888888>Race: <#cccccc>%-14s <#888888>Align: <#cccccc>%s<reset>\n",
    race_str, align_str))

  -- HP / Kill count
  local hp_str    = formatNumber(rec.hp)
  local kills_str = rec.killCount and tostring(rec.killCount) or "0"
  cecho(CR_MC, string.format(
    "<#888888>HP:   <#cccccc>%-14s <#888888>Kills: <#cccccc>%s<reset>\n",
    hp_str, kills_str))

  -- Avg XP / Last XP
  local avg_xp  = formatNumber(rec.avgXP)
  local last_xp = formatNumber(rec.lastXP)
  cecho(CR_MC, string.format(
    "<#888888>Avg XP: <#ffcc44>%-12s <#888888>Last XP: <#ffcc44>%s<reset>\n",
    avg_xp, last_xp))

  cecho(CR_MC, "\n")

  -- Rooms seen
  if rec.roomsFound and next(rec.roomsFound) then
    cecho(CR_MC, "<#888888>Rooms seen:<reset>\n")
    for room, count in pairs(rec.roomsFound) do
      cecho(CR_MC, string.format(
        "  <#88aaff>%s <#888888>(%d)<reset>\n", room, count))
    end
    cecho(CR_MC, "\n")
  end

  -- Immunities / Resists / Vulns / Affects
  local function listLine(label, tbl, color)
    local c = color or "#44ccaa"
    if type(tbl) == "table" and #tbl > 0 then
      cecho(CR_MC, string.format("<#888888>%-12s<%s>%s<reset>\n",
        label, c, table.concat(tbl, ", ")))
    else
      cecho(CR_MC, string.format("<#888888>%-12s<#444444>(none)<reset>\n", label))
    end
  end
  listLine("Immunities:", rec.immunities, "#44ccaa")
  listLine("Resists:",    rec.resists,    "#44ccaa")
  listLine("Vulns:",      rec.vulns,      "#cc4444")
  listLine("Affects:",    rec.affects,    "#aaaaff")

  cecho(CR_MC, "\n")

  -- Drops
  if rec.drops and next(rec.drops) then
    cecho(CR_MC, "<#888888>Drops:<reset>\n")
    for item, count in pairs(rec.drops) do
      cecho(CR_MC, string.format(
        "  <#ffcc44>%s <#888888>(%d kills)<reset>\n", item, count))
    end
    cecho(CR_MC, "\n")
  end

  -- Last lored date
  if rec.lastLore and rec.lastLore > 0 then
    cecho(CR_MC, string.format(
      "<#888888>Last lored: <#cccccc>%s<reset>\n",
      os.date("%Y-%m-%d", rec.lastLore)))
  elseif rec.last_updated and rec.last_updated > 0 then
    cecho(CR_MC, string.format(
      "<#888888>Last lored: <#cccccc>%s<reset>\n",
      os.date("%Y-%m-%d", rec.last_updated)))
  end

  cecho(CR_MC, string.format("<#444444>%s\n<reset>", hrule("─")))
end


------------------------------------------------------------------------
-- onLoreUpdate()  —  handler for MyDSL.creaturelore.updated
------------------------------------------------------------------------

function CR.onLoreUpdate()
  local lore = MyDSL.State.creaturelore
  if not lore or not lore.name then return end
  CR.render(lore.name)
  -- Auto-show window when fresh lore arrives.
  local win = MyDSL.Windows.ensure(CR_WIN)
  if win and win.show then pcall(win.show, win) end
end


------------------------------------------------------------------------
-- show() / hide()
------------------------------------------------------------------------

function CR.show()
  local win = MyDSL.Windows.ensure(CR_WIN)
  if win and win.show then pcall(win.show, win) end
end

function CR.hide()
  local win = MyDSL.Windows and MyDSL.Windows.windows and MyDSL.Windows.windows[CR_WIN]
  if win and win.hide then pcall(win.hide, win) end
end


------------------------------------------------------------------------
-- init()  —  safe to re-call on reload
------------------------------------------------------------------------

function CR.init()
  -- Ensure CreatureReference UserWindow and its MiniConsole exist.
  local crWin = MyDSL.Windows.ensure(CR_WIN)
  if not CR._mc.lore then
    CR._mc.lore = Geyser.MiniConsole:new({
      name      = CR_MC,
      x = 0, y = 0, width = "100%", height = "100%",
      wrapWidth = 300,
      scrollBar = true,
    }, crWin)
  end

  -- Register creaturelore.updated handler.
  CR._handlers.loreUpdated = registerAnonymousEventHandler(
    "MyDSL.creaturelore.updated",
    function() CR.onLoreUpdate() end
  )

  -- Aliases
  CR._aliases.loreLookup = tempAlias(
    "^mydsl lore (.+)$",
    [[
      local name = matches[2]
      if name == "hide" then
        if MyDSL and MyDSL.CreatureReference then MyDSL.CreatureReference.hide() end
      elseif name == "show" then
        if MyDSL and MyDSL.CreatureReference then MyDSL.CreatureReference.show() end
      else
        send("creaturelore " .. name, false)
        if MyDSL and MyDSL.CreatureReference then MyDSL.CreatureReference.show() end
      end
    ]]
  )

  -- Initial render: show placeholder (window starts hidden per registry default).
  CR.render(nil)

  debugc("[MyDSL] CreatureReference loaded.")
end


------------------------------------------------------------------------
-- Boot
------------------------------------------------------------------------

CR.init()
