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
  MyDSL.DB.room = { name = room.name, exits = room.exits, area = room.area }
  MyDSL.DB.tick = { remaining = tick.remaining, average = tick.average or 40, percent = tick.percent }
  MyDSL.DB.timers          = MyDSL.DB.timers or {}
  MyDSL.DB.timers.tick     = MyDSL.DB.tick
  MyDSL.DB.xp              = { tnl = char.tnl }
end


------------------------------------------------------------------------
-- EVENT HANDLERS  — sync whenever any upstream data changes
------------------------------------------------------------------------

local function onAny()
  pcall(MyDSL.DB.sync)
end

MyDSL.DB._handlers.char     = registerAnonymousEventHandler("MyDSL.char.updated",  onAny)
MyDSL.DB._handlers.room     = registerAnonymousEventHandler("MyDSL.room.updated",  onAny)
MyDSL.DB._handlers.login    = registerAnonymousEventHandler("MyDSL.login.updated", onAny)
MyDSL.DB._handlers.tick     = registerAnonymousEventHandler("MyDSL.tick.updated",  onAny)
MyDSL.DB._handlers.gchar    = registerAnonymousEventHandler("gmcp.char_data",      onAny)
MyDSL.DB._handlers.groom    = registerAnonymousEventHandler("gmcp.room_data",      onAny)
MyDSL.DB._handlers.gtick    = registerAnonymousEventHandler("gmcp.tick",           onAny)


------------------------------------------------------------------------
-- INITIAL SYNC  — populate DB from whatever State already holds
------------------------------------------------------------------------
MyDSL.DB.sync()

debugc("[MyDSL] DataBridge loaded.")
