-- =============================================================================
-- MyDSL_CreatureReference.lua  --  Layer 3 Phase B: Creature lore display
-- =============================================================================
-- Listens for "MyDSL.creaturelore.updated" and renders the creature lore record
-- in the MyDSL_CreatureReference window.  The window is hidden by default and
-- auto-shows when new lore arrives.  Never sends commands or modifies the DB.
--
-- Fixed 2026-07-11, real bug found live ("creature lore text seems to have
-- numbers instead of colors?"): this was the only file anywhere in the
-- profile using cecho()'s "<#RRGGBB>" hex-color tag syntax and "<reset>" --
-- neither is valid here; Mudlet's cecho only recognizes named colors
-- ("<grey>", confirmed working in MyDSL_AffectsView.lua's wcecho()) or the
-- decho-style "<r,g,b>" decimal tag, and an unrecognized tag just prints
-- literally, which is exactly "numbers instead of colors." Converted every
-- hex value to its decimal RGB equivalent and switched cecho()->decho()/
-- "<reset>"->"<r>" to match the "<r,g,b>...<r>" convention every other
-- module in the profile already uses successfully (TargetView, GroupView,
-- CombatView, etc.).
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
    decho(CR_MC, "<68,68,68>No creature selected.\n<r>")
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
  decho(CR_MC, string.format("<68,68,68>%s\n<r>", hrule("─")))
  decho(CR_MC, string.format("<255,204,68>%s<r>\n", name))
  decho(CR_MC, string.format("<68,68,68>%s\n<r>", hrule("─")))

  if not rec then
    decho(CR_MC, "<136,136,136>No lore data yet.\n<r>")
    decho(CR_MC, "<102,102,102>Click [Lore] in Target window to capture.\n<r>")
    decho(CR_MC, string.format("<68,68,68>%s\n<r>", hrule("─")))
    return
  end

  -- Race / Alignment
  local race_str  = rec.race          or "?"
  local align_str = rec.alignmentText or "?"
  decho(CR_MC, string.format(
    "<136,136,136>Race: <204,204,204>%-14s <136,136,136>Align: <204,204,204>%s<r>\n",
    race_str, align_str))

  -- HP / Kill count
  local hp_str    = formatNumber(rec.hp)
  local kills_str = rec.killCount and tostring(rec.killCount) or "0"
  decho(CR_MC, string.format(
    "<136,136,136>HP:   <204,204,204>%-14s <136,136,136>Kills: <204,204,204>%s<r>\n",
    hp_str, kills_str))

  -- Avg XP / Last XP
  local avg_xp  = formatNumber(rec.avgXP)
  local last_xp = formatNumber(rec.lastXP)
  decho(CR_MC, string.format(
    "<136,136,136>Avg XP: <255,204,68>%-12s <136,136,136>Last XP: <255,204,68>%s<r>\n",
    avg_xp, last_xp))

  decho(CR_MC, "\n")

  -- Rooms seen
  if rec.roomsFound and next(rec.roomsFound) then
    decho(CR_MC, "<136,136,136>Rooms seen:<r>\n")
    for room, count in pairs(rec.roomsFound) do
      decho(CR_MC, string.format(
        "  <136,170,255>%s <136,136,136>(%d)<r>\n", room, count))
    end
    decho(CR_MC, "\n")
  end

  -- Immunities / Resists / Vulns / Affects
  local function listLine(label, tbl, color)
    local c = color or "68,204,170"
    if type(tbl) == "table" and #tbl > 0 then
      decho(CR_MC, string.format("<136,136,136>%-12s<%s>%s<r>\n",
        label, c, table.concat(tbl, ", ")))
    else
      decho(CR_MC, string.format("<136,136,136>%-12s<68,68,68>(none)<r>\n", label))
    end
  end
  listLine("Immunities:", rec.immunities, "68,204,170")
  listLine("Resists:",    rec.resists,    "68,204,170")
  listLine("Vulns:",      rec.vulns,      "204,68,68")
  listLine("Affects:",    rec.affects,    "170,170,255")

  decho(CR_MC, "\n")

  -- Drops
  if rec.drops and next(rec.drops) then
    decho(CR_MC, "<136,136,136>Drops:<r>\n")
    for item, count in pairs(rec.drops) do
      decho(CR_MC, string.format(
        "  <255,204,68>%s <136,136,136>(%d kills)<r>\n", item, count))
    end
    decho(CR_MC, "\n")
  end

  -- Last lored date
  if rec.lastLore and rec.lastLore > 0 then
    decho(CR_MC, string.format(
      "<136,136,136>Last lored: <204,204,204>%s<r>\n",
      os.date("%Y-%m-%d", rec.lastLore)))
  elseif rec.last_updated and rec.last_updated > 0 then
    decho(CR_MC, string.format(
      "<136,136,136>Last lored: <204,204,204>%s<r>\n",
      os.date("%Y-%m-%d", rec.last_updated)))
  end

  decho(CR_MC, string.format("<68,68,68>%s\n<r>", hrule("─")))
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

  -- Aliases -- renamed 2026-07-11, command-surface retrofit (docs/TODO.md
  -- "OPEN — Command-surface retrofit"), per Steven. Dropped the "mydsl"
  -- prefix. CORRECTED same day, per Steven: originally renamed to bare
  -- "lore <name>" on the reasoning that real DSL "lore" (DSL_Helpfiles/
  -- lore.txt) has no typed syntax to collide with -- Steven pointed out
  -- that's the wrong bar: "lore" is still real DSL vocabulary (a skill
  -- name), and claiming it for something else is exactly the confusion
  -- this retrofit is supposed to avoid, syntax collision or not. Renamed
  -- to "bestiary" instead -- not real DSL vocabulary anywhere in
  -- DSL_Helpfiles.
  CR._aliases.loreLookup = tempAlias(
    "^bestiary (.+)$",
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
