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

  -- Name header. Dash rule lines removed 2026-07-16, per Steven ("remove
  -- the --- lines in bestiary to save space") -- hrule() had no other
  -- callers left, so removed it too rather than leave dead code.
  decho(CR_MC, string.format("<255,204,68>%s<r>\n", name))

  if not rec then
    decho(CR_MC, "<136,136,136>No lore data yet.\n<r>")
    decho(CR_MC, "<102,102,102>Click [Lore] in Focus window to capture.\n<r>")
    return
  end

  -- Race / Level / Alignment -- Lvl (DSL's own "cycle of training"
  -- number) added 2026-07-11 per Steven ("we arent capturing the...
  -- level of the mobs (level is IC cycles of training)"); align narrowed
  -- to just good/evil/neutral the same day, per his "align field needs
  -- tweaking" -- both fields come from the same MyDSL.CreatureLore DB
  -- MyDSL_TargetView.lua's Focus window reads, so kept in sync here too.
  local race_str  = rec.race          or "?"
  local lvl_str   = rec.trainingCycle and tostring(rec.trainingCycle) or "?"
  local align_str = rec.alignmentText or "?"
  decho(CR_MC, string.format(
    "<136,136,136>Race: <204,204,204>%-12s <136,136,136>Lvl: <204,204,204>%-4s <136,136,136>Align: <204,204,204>%s<r>\n",
    race_str, lvl_str, align_str))

  -- HP. Kills/Avg XP/Last XP dropped 2026-07-16, per Steven ("bestiary
  -- window not showing health and xp"). Investigated: HP already works
  -- correctly whenever a creature has real creaturelore data (reads
  -- straight off rec.hp, populated from "The base health of this
  -- creature is N." during a real capture) -- blank HP just means that
  -- specific creature was only ever "seen", never actually lore'd.
  -- Kills/avgXP/lastXP, though, have NO capture path anywhere in this
  -- codebase (confirmed via grep -- those fields only ever existed in
  -- the stale DSL1 MyDSL_creaturelore.lua reference file); DSL's own
  -- `creaturelore` skill doesn't report kill count or XP at all (per
  -- DSL_Helpfiles/creaturelore.txt), so nothing could ever fill them.
  -- MyDSL_TargetView.lua's Focus window already reached this same
  -- conclusion 2026-07-11 and omits them entirely rather than showing
  -- permanent placeholders -- matching that here instead of displaying
  -- an always-empty "Kills: 0 / Avg XP: ? / Last XP: ?" row.
  local hp_str = formatNumber(rec.hp)
  decho(CR_MC, string.format("<136,136,136>HP: <204,204,204>%s<r>\n", hp_str))

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
  -- Offensive Tactics -- added 2026-07-11 per Steven ("we arent capturing
  -- the offensive tactics... of the mobs").
  listLine("Tactics:",    rec.tactics,    "255,204,68")
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
end


------------------------------------------------------------------------
-- onLoreUpdate()  —  handler for MyDSL.creaturelore.updated
------------------------------------------------------------------------

function CR.onLoreUpdate()
  local lore = MyDSL.State.creaturelore
  if not lore or not lore.name then return end
  CR.render(lore.name)
  -- Auto-show window when fresh lore arrives.
  if MyDSL.Windows then MyDSL.Windows.show(CR_WIN) end
end

-- onTargetUpdate() -- added 2026-07-12, real bug found live via screenshot
-- (Steven: "the targetview bestiary stats updated from creaturelore but
-- the bestiary window shows no health/mana. is creaturelore saving to the
-- right place?"). Traced: CreatureLore.db WAS saving correctly the whole
-- time (confirmed directly reading MyDSL/creaturelore_db.lua -- the
-- "mage" record had real hp/magic fields matching what Focus displayed).
-- The real gap was that this window only ever redrew on the
-- "MyDSL.creaturelore.updated" event -- i.e. only right after a FRESH
-- "creaturelore <name>" capture completes. MyDSL_TargetView.lua's Focus
-- window ALSO redraws on "MyDSL.target.updated" (and every Timers.Slow
-- tick), so simply selecting a target that already had lore stored from
-- an earlier capture/session correctly showed its stats in Focus, but
-- this window had no listener at all for target changes -- it just kept
-- showing whatever (or nothing) it last rendered. Deliberately does NOT
-- auto-show the window on a mere target switch (unlike onLoreUpdate()
-- above) -- popping Bestiary open every time the player targets something
-- would be intrusive; this only keeps its content in sync for whenever
-- it's already open or gets shown later.
function CR.onTargetUpdate()
  local t = MyDSL.State.target
  CR.render(t and t.name or nil)
end


------------------------------------------------------------------------
-- show() / hide()
------------------------------------------------------------------------
-- Real bug, found live 2026-07-12 (Steven: "bestiary show doesnt work,
-- no window i can see"): both of these (and the auto-show above) used to
-- call the raw Geyser window object's own :show()/:hide() directly,
-- never touching MyDSL.Windows.registry[CR_WIN].visible -- the exact
-- same "own local visibility tracking, independent of WindowRegistry's
-- real state" bug already found and fixed in MyDSL_MoonWeather.lua
-- 2026-07-11. Whatever re-syncs all windows to their registry-tracked
-- visible state (e.g. on "MyDSL.character.identified") would see this
-- entry's visible still stuck at its default false and hide the window
-- right back, even though :show() had just been called directly.
-- hide() specifically was worse: it looked up
-- MyDSL.Windows.windows[CR_WIN], a table that is never defined anywhere
-- in MyDSL_WindowRegistry.lua (confirmed via grep -- only ever referenced,
-- never created) -- so hide() could never even find the window object at
-- all and silently did nothing every time. Delegating entirely to
-- MyDSL.Windows.show()/hide() (the same already-correct mechanism
-- MyDSL_CombatView.lua's CV.show()/hide() already use) makes
-- registry.visible the single source of truth instead of two
-- independently-tracked, out-of-sync flags.

function CR.show()
  if MyDSL.Windows then MyDSL.Windows.show(CR_WIN) end
end

function CR.hide()
  if MyDSL.Windows then MyDSL.Windows.hide(CR_WIN) end
end

-- status/rebuild/font -- added 2026-07-15, bringing Bestiary up to the
-- same standard other windows have (show/hide already existed above,
-- reachable via "bestiary show"/"bestiary hide").
function CR.status()
  decho(string.format(
    "<136,204,255>[MyDSL] Bestiary: font=%d<r>\n",
    MyDSL.Windows.getFontSize(CR_WIN, 9)
  ))
end

function CR.rebuild()
  if CR._mc.lore then pcall(function() CR._mc.lore:hide() end) end
  CR._mc.lore = nil
  CR.ensureUI()
  CR.render(nil)
end

function CR.setFont(size)
  size = tonumber(size)
  if not size then echo("usage: bestiary font <size>\n"); return end
  if size < 6 then size = 6 end
  if size > 18 then size = 18 end
  if CR._mc.lore then CR._mc.lore:setFontSize(size) end
  MyDSL.Windows.setFontSize(CR_WIN, size)
  echo("MyDSL_CreatureReference font=" .. tostring(size) .. "\n")
end


------------------------------------------------------------------------
-- init()  —  safe to re-call on reload
------------------------------------------------------------------------

-- ensureUI() -- extracted from init() 2026-07-15 so rebuild() can
-- recreate the console without duplicating the whole setup.
function CR.ensureUI()
  local crWin = MyDSL.Windows.ensure(CR_WIN)
  -- Fixed 2026-07-11, per Steven ("fix all window titles/names").
  if crWin and crWin.setTitle then pcall(function() crWin:setTitle("-= Bestiary =-") end) end
  if not CR._mc.lore then
    CR._mc.lore = Geyser.MiniConsole:new({
      name      = CR_MC,
      x = 0, y = 0, width = "100%", height = "100%",
      scrollBar = true,
    }, crWin)
    -- Adaptive word wrap, per Steven ("bestiary... needs word wrap") --
    -- same real Mudlet API already proven working for History
    -- (MyDSL_RouteHelper.lua): computes wrapAt from the console's own
    -- live pixel width, and MiniConsole's reposition() override already
    -- recalls it automatically on resize, no extra wiring needed. Static
    -- wrapWidth=300 (removed above) didn't track this window's actual
    -- (much narrower, docked) width at all.
    pcall(function() CR._mc.lore:enableAutoWrap() end)
  end

  -- Font size now persisted per-window (2026-07-15, "bring Scan/Group/
  -- Bestiary up to the same status/show/hide/rebuild/font standard other
  -- windows have" -- see docs/CHANGELOG.md). Was: no size override at
  -- all, always just the theme's own default.
  local loreFont = MyDSL.Windows.getFontSize(CR_WIN, 9)
  if CR._mc.lore then CR._mc.lore:setFontSize(loreFont) end

  -- Theme-driven background/font, added 2026-07-11 (this console had no
  -- font size or color set at all before -- fell back to Mudlet's tiny
  -- built-in default; see docs/CHANGELOG.md's ThemeEngine entry).
  if MyDSL.Theme and MyDSL.Theme.styleConsole then
    MyDSL.Theme.styleConsole(CR._mc.lore, CR_WIN, loreFont)
  end
end

function CR.init()
  CR.ensureUI()

  -- Register creaturelore.updated handler.
  CR._handlers.loreUpdated = registerAnonymousEventHandler(
    "MyDSL.creaturelore.updated",
    function() CR.onLoreUpdate() end
  )

  -- Register target.updated handler -- see onTargetUpdate()'s own header
  -- comment for why this was missing and what broke without it.
  CR._handlers.targetUpdated = registerAnonymousEventHandler(
    "MyDSL.target.updated",
    function() CR.onTargetUpdate() end
  )

  CR._handlers.themeChanged = registerAnonymousEventHandler(
    "MyDSL.theme.changed",
    function()
      if MyDSL.Theme and MyDSL.Theme.styleConsole then
        MyDSL.Theme.styleConsole(CR._mc.lore, CR_WIN, MyDSL.Windows.getFontSize(CR_WIN, 9))
      end
    end
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
      local fontSize = name:match("^font%s+(%d+)$")
      if name == "hide" then
        if MyDSL and MyDSL.CreatureReference then MyDSL.CreatureReference.hide() end
      elseif name == "show" then
        if MyDSL and MyDSL.CreatureReference then MyDSL.CreatureReference.show() end
      elseif name == "status" then
        if MyDSL and MyDSL.CreatureReference then MyDSL.CreatureReference.status() end
      elseif name == "rebuild" then
        if MyDSL and MyDSL.CreatureReference then MyDSL.CreatureReference.rebuild() end
      elseif fontSize then
        if MyDSL and MyDSL.CreatureReference then MyDSL.CreatureReference.setFont(fontSize) end
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
