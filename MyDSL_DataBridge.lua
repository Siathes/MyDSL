-- =============================================================================
-- MyDSL_DataBridge.lua  --  Layer 3: State→DB translation
-- =============================================================================
-- Bridges MyDSL.State.* (DSL2 DataLayer) to MyDSL.DB.* (expected by DSL1-era
-- display modules: LiveView, TickView, TickSource).
-- Must load AFTER DataLayer (position 5 in full package).
-- =============================================================================

MyDSL    = MyDSL    or {}
MyDSL.DB = MyDSL.DB or {}

MyDSL.DB._handlers = MyDSL.DB._handlers or {}

-- Kill handlers from any previous load to prevent duplicates.
local function deregisterHandlers()
  for _, id in pairs(MyDSL.DB._handlers) do
    pcall(killAnonymousEventHandler, id)
  end
  MyDSL.DB._handlers = {}
end
deregisterHandlers()


------------------------------------------------------------------------
-- SYNC  — copies State fields into DB namespaces expected by DSL1 modules
------------------------------------------------------------------------

function MyDSL.DB.sync()
  local char  = MyDSL.State and MyDSL.State.char  or {}
  local login = MyDSL.State and MyDSL.State.login or {}
  local room  = MyDSL.State and MyDSL.State.room  or {}
  local tick  = MyDSL.State and MyDSL.State.tick  or {}

  MyDSL.DB.live = {
    hp      = char.hp,      maxhp      = char.max_hp,
    mana    = char.mana,    maxmana    = char.max_mana,
    move    = char.move,    maxmove    = char.max_move,
    name    = login.name,   level      = login.level,
  }

  -- GMCP-backed stat fields — built first so text merges below don't overwrite them
  MyDSL.DB.score = {
    str        = char.str,          int        = char.int,
    wis        = char.wis,          dex        = char.dex,
    con        = char.con,
    gold       = char.gold,         silver     = char.silver,
    weight     = char.carry_weight, maxWeight  = char.can_carry_weight,
    tnl        = char.tnl,          wimpy      = char.wimpy,
    stance     = char.stance,       language   = char.language,
    flying     = char.is_flying,    riding     = char.is_riding,
    fighting   = char.is_fighting,
  }

  -- Gap 6: score text fields (text parser only — not available from GMCP).
  -- Field names verified against MyDSL_DataLayer.lua parseScoreLine().
  -- DataLayer key 'position' → DB key 'posn' (per LiveView contract).
  -- DataLayer key 'class'    → DB key 'class_' (avoids Lua reserved word).
  local sc = MyDSL.State.score or {}
  MyDSL.DB.score.align       = sc.align
  MyDSL.DB.score.race        = sc.race
  MyDSL.DB.score.class_      = sc.class
  MyDSL.DB.score.religion    = sc.religion
  MyDSL.DB.score.profession  = sc.profession
  MyDSL.DB.score.crafts      = sc.crafts
  MyDSL.DB.score.xp          = sc.xp
  MyDSL.DB.score.practices   = sc.practices
  MyDSL.DB.score.trains      = sc.trains
  MyDSL.DB.score.bank        = sc.bank
  MyDSL.DB.score.qpoints     = sc.qpoints
  MyDSL.DB.score.hitroll     = sc.hitroll
  MyDSL.DB.score.hitrollBase = sc.hitrollBase
  MyDSL.DB.score.damroll     = sc.damroll
  MyDSL.DB.score.damrollBase = sc.damrollBase
  MyDSL.DB.score.armorPierce = sc.armorPierce
  MyDSL.DB.score.armorBash   = sc.armorBash
  MyDSL.DB.score.armorSlash  = sc.armorSlash
  MyDSL.DB.score.armorMagic  = sc.armorMagic
  MyDSL.DB.score.items       = sc.items
  MyDSL.DB.score.max_items   = sc.max_items
  MyDSL.DB.score.posn        = sc.position

  -- Gap 1 confirmed NOT a bug: DataLayer maps gmcp.room_data.room → State.room.name.
  -- Gap 2 fixed: 'area' never existed in DataLayer — replaced with 'sector'.
  MyDSL.DB.room = { name = room.name, exits = room.exits, sector = room.sector }

  MyDSL.DB.tick = { remaining = tick.remaining, average = tick.average or 40, percent = tick.percent }
  MyDSL.DB.timers          = MyDSL.DB.timers or {}
  MyDSL.DB.timers.tick     = MyDSL.DB.tick
  MyDSL.DB.xp              = { tnl = char.tnl }

  -- DB.time — populated by DataLayer.parseTimeLine() from the `time` command.
  -- is_night priority: State.time.is_night is nil until a trigger fires (nil=unseen,
  --   false=sunrise fired, true="The night has begun." fired). While nil, fall back
  --   to GMCP clock approximation: night = 7pm-11pm or 12am-5am (Algoron approximate).
  local t  = MyDSL.State.time or {}
  local ap = t.ampm or ""

  local tickTime    = (gmcp and gmcp.tick and gmcp.tick.time) or ""
  local th, tap     = tickTime:match("(%d+):?%d*([ap]m)")
  th                = tonumber(th) or 12
  local gmcpIsNight = (tap == "pm" and th >= 7) or (tap == "am" and th < 6)

  local stateNight = MyDSL.State.time and MyDSL.State.time.is_night
  local is_night_val
  if stateNight == nil then
    is_night_val = gmcpIsNight
  else
    is_night_val = (stateNight == true)
  end

  MyDSL.DB.time = {
    hour     = t.hour,
    ampm     = ap,
    clock    = (t.hour and ap ~= "") and (t.hour .. ":00 " .. ap) or "",
    day_name = t.day_name,
    day_num  = t.day_num,
    month    = t.month,
    is_night = is_night_val,
  }

  -- Gap 4: DB.affects — active affects keyed by lowercase spell name.
  -- DataLayer builds this table from gmcp.affect_data / add_affect / remove_affect.
  -- Consumers iterate: for name, entry in pairs(MyDSL.DB.affects) do
  MyDSL.DB.affects = (MyDSL.State.affects and MyDSL.State.affects.active) or {}
end


------------------------------------------------------------------------
-- EVENT HANDLERS  — sync whenever any upstream data changes
------------------------------------------------------------------------

local function onAny()
  pcall(MyDSL.DB.sync)
end

MyDSL.DB._handlers.char     = registerAnonymousEventHandler("MyDSL.char.updated",    onAny)
MyDSL.DB._handlers.room     = registerAnonymousEventHandler("MyDSL.room.updated",    onAny)
MyDSL.DB._handlers.login    = registerAnonymousEventHandler("MyDSL.login.updated",   onAny)
MyDSL.DB._handlers.tick     = registerAnonymousEventHandler("MyDSL.tick.updated",    onAny)
MyDSL.DB._handlers.score    = registerAnonymousEventHandler("MyDSL.score.updated",   onAny)
MyDSL.DB._handlers.time     = registerAnonymousEventHandler("MyDSL.time.updated",    onAny)
MyDSL.DB._handlers.affects  = registerAnonymousEventHandler("MyDSL.affects.updated", onAny)
MyDSL.DB._handlers.gchar    = registerAnonymousEventHandler("gmcp.char_data",        onAny)
MyDSL.DB._handlers.groom    = registerAnonymousEventHandler("gmcp.room_data",        onAny)
MyDSL.DB._handlers.gtick    = registerAnonymousEventHandler("gmcp.tick",             onAny)


------------------------------------------------------------------------
-- INITIAL SYNC  — populate DB from whatever State already holds
------------------------------------------------------------------------
MyDSL.DB.sync()

debugc("[MyDSL] DataBridge loaded.")
