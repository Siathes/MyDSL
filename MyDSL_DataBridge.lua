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
    -- Dragon-only, added 2026-07-12 -- see MyDSL_DataLayer.lua's
    -- vitalitySet trigger and MyDSL_LiveView.lua's attrVit row.
    vitality   = char.vitality,
  }

  -- Gap 6: score text fields (text parser only — not available from GMCP).
  -- Field names verified against MyDSL_DataLayer.lua parseScoreLine().
  -- DataLayer key 'position' → DB key 'posn' (per LiveView contract).
  -- DataLayer key 'class'    → DB key 'class_' (avoids Lua reserved word).
  local sc = MyDSL.State.score or {}
  -- hp/mana/move fallback added 2026-07-11 -- real bug found live
  -- (LiveView health bars stuck at "-- (0%)" despite `score`
  -- having been run and correctly parsed): LiveView's L.data() already
  -- does `live.hp or score.hp` specifically so the score-command text
  -- parse can cover GMCP not having sent char_data.hp yet, but this
  -- block never actually forwarded hp/max_hp/mana/max_mana/move/max_move
  -- from MyDSL.State.score into MyDSL.DB.score at all -- every OTHER
  -- score field was mapped here except these three pairs, so the
  -- fallback LiveView was relying on had nothing to fall back to.
  MyDSL.DB.score.hp          = sc.hp
  MyDSL.DB.score.maxhp       = sc.max_hp
  MyDSL.DB.score.mana        = sc.mana
  MyDSL.DB.score.maxmana     = sc.max_mana
  MyDSL.DB.score.move        = sc.move
  MyDSL.DB.score.maxmove     = sc.max_move
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
  -- Dragon-only breath-weapon charge, added 2026-07-12 -- see
  -- MyDSL_DataLayer.lua's Chamber: parsing and MyDSL_LiveView.lua's
  -- attrVit row (paired alongside Vitality).
  MyDSL.DB.score.chamber     = sc.chamber
  -- Real Lua timestamp from score's "Created:" line, added 2026-07-12
  -- for LiveView's in-game age display -- see MyDSL_DataLayer.lua's
  -- parseScoreLine() for the parsing, MyDSL_LiveView.lua for the actual
  -- age-from-timestamp math.
  MyDSL.DB.score.createdTs   = sc.created_ts
  -- Real bug fixed 2026-07-11, found while scoping the Live HUD expansion:
  -- these 8 read from key names (hitroll/hitrollBase/armorPierce/etc) that
  -- parseScoreLine() has never produced -- the real keys on MyDSL.State.score
  -- are hit_roll/hit_roll_base/dam_roll/dam_roll_base/armor_pierce/
  -- armor_bash/armor_slash/armor_magic (confirmed directly against
  -- MyDSL_DataLayer.lua's parseScoreLine()). Every one of these 8 has been
  -- silently nil in MyDSL.DB.score since this file was written.
  MyDSL.DB.score.hitroll     = sc.hit_roll
  MyDSL.DB.score.hitrollBase = sc.hit_roll_base
  MyDSL.DB.score.damroll     = sc.dam_roll
  MyDSL.DB.score.damrollBase = sc.dam_roll_base
  MyDSL.DB.score.armorPierce = sc.armor_pierce
  MyDSL.DB.score.armorBash   = sc.armor_bash
  MyDSL.DB.score.armorSlash  = sc.armor_slash
  MyDSL.DB.score.armorMagic  = sc.armor_magic
  MyDSL.DB.score.items       = sc.items
  MyDSL.DB.score.max_items   = sc.max_items
  -- Real-time position, per Steven ("liveview pos'n doesnt update on
  -- changing without score, it should update with the gmcp"). char.posn
  -- (MyDSL_DataLayer.lua's new posn text-trigger set + GMCP is_flying,
  -- added 2026-07-12) updates instantly as it happens; sc.position (the
  -- score-command text parse) only refreshes when `score` is actually
  -- run. char.posn wins when present, same "GMCP-first, text fallback"
  -- pattern as gold/silver/weight below -- sc.position only still
  -- matters for the brief window right after login before any real
  -- position event has fired yet.
  MyDSL.DB.score.posn        = char.posn or sc.position
  -- Base (unmodified) stat values -- added 2026-07-11. char.str/int/wis/
  -- dex/con above (GMCP) are the current/modified values already; the
  -- score command's "STR: 051(050)" format also gives the base value in
  -- parens, which GMCP's char_data doesn't carry at all. Additive only --
  -- does not overwrite the GMCP-sourced current values above.
  MyDSL.DB.score.str_base    = sc.str_base
  MyDSL.DB.score.int_base    = sc.int_base
  MyDSL.DB.score.wis_base    = sc.wis_base
  MyDSL.DB.score.dex_base    = sc.dex_base
  MyDSL.DB.score.con_base    = sc.con_base
  -- Text-parsed fallbacks for fields GMCP's char_data may not always carry
  -- (e.g. a fresh login before the first `score`) -- additive, GMCP wins
  -- when present. Added 2026-07-11 alongside the Live HUD expansion.
  MyDSL.DB.score.gold        = MyDSL.DB.score.gold      or sc.gold
  MyDSL.DB.score.silver      = MyDSL.DB.score.silver    or sc.silver
  MyDSL.DB.score.weight      = MyDSL.DB.score.weight    or sc.weight
  MyDSL.DB.score.maxWeight   = MyDSL.DB.score.maxWeight or sc.max_weight
  MyDSL.DB.score.wimpy       = MyDSL.DB.score.wimpy     or sc.wimpy
  MyDSL.DB.score.tnl         = MyDSL.DB.score.tnl       or sc.tnl
  MyDSL.DB.score.stance      = MyDSL.DB.score.stance    or sc.stance

  -- Gap 1 confirmed NOT a bug: DataLayer maps gmcp.room_data.room → State.room.name.
  -- Gap 2 fixed: 'area' never existed in DataLayer — replaced with 'sector'.
  -- Real bug fixed 2026-07-11, found via Steven's report that LiveView's
  -- exits line "changes from original game text to white text": this
  -- unconditionally rebuilt the whole DB.room table on every sync() call,
  -- silently wiping exitsColoredSource/exitsColoredUpdatedAt/exitsLine --
  -- the 3 fields MyDSL_LiveView.lua's setColoredExitsFromCurrentLine()
  -- sets to remember it already captured the exits line with its original
  -- game colors intact (e.g. the water-tinted color DSL uses near water).
  -- sync() runs far more often than a fresh room description scrolls by,
  -- so the flag was getting cleared within moments of being set, and the
  -- next render() tick would fall back to the neutral all-white version
  -- -- looked like the colored text was "changing to white" because it
  -- literally was, moments after briefly rendering correctly.
  local prevRoom = MyDSL.DB.room or {}
  MyDSL.DB.room = {
    name = room.name, exits = room.exits, sector = room.sector,
    exitsColoredSource    = prevRoom.exitsColoredSource,
    exitsColoredUpdatedAt = prevRoom.exitsColoredUpdatedAt,
    exitsLine             = prevRoom.exitsLine,
  }

  -- MyDSL.DB.tick is NOT rebuilt here (real bug fixed 2026-07-11) --
  -- MyDSL.State.tick only ever holds a `time` string (DataLayer's
  -- update("tick", {time=gmcp.tick.time}), never `remaining`/`average`/
  -- `percent`), so this used to unconditionally clobber TickSource's own
  -- correctly-maintained MyDSL.DB.tick (real smoothed average, live
  -- remaining/percent, set directly in T.publish()) with a mostly-nil
  -- table on every sync() -- including sync() calls fired by the very same
  -- gmcp.tick event TickSource itself was just reacting to, discarding its
  -- just-computed smoothed average right after computing it. TickSource is
  -- the sole authority for MyDSL.DB.tick; just alias it here.
  MyDSL.DB.timers          = MyDSL.DB.timers or {}
  MyDSL.DB.timers.tick     = MyDSL.DB.tick
  MyDSL.DB.xp              = { tnl = char.tnl }

  -- DB.time — populated by DataLayer.parseTimeLine() from the `time` command.
  -- is_night priority (highest to lowest):
  --   1. State.time.period (from prompt, every server event) — "Night Time"→true, else false
  --   2. State.time.is_night (from sunrise / "The night has begun." triggers)
  --   3. GMCP clock approximation: 7pm-11pm or 12am-5am = night
  local t  = MyDSL.State.time or {}
  local ap = t.ampm or ""

  local tickTime    = (gmcp and gmcp.tick and gmcp.tick.time) or ""
  local th, tap     = tickTime:match("(%d+):?%d*([ap]m)")
  th                = tonumber(th) or 12
  local gmcpIsNight = (tap == "pm" and th >= 7) or (tap == "am" and th < 6)

  local period     = MyDSL.State.time and MyDSL.State.time.period
  local stateNight = MyDSL.State.time and MyDSL.State.time.is_night
  local is_night_val
  if period ~= nil then
    is_night_val = (period == "Night Time")
  elseif stateNight ~= nil then
    is_night_val = (stateNight == true)
  else
    is_night_val = gmcpIsNight
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

  -- DB.improve — added 2026-07-07, per Steven (LiveView's Improve bar,
  -- already built, was waiting on this).
  -- last_updated added 2026-07-11: `text` used to be pre-formatted here as a
  -- static snapshot ("skill 91% (12m)") that never changed between actual
  -- server updates, but the real DSL text ("<N> online minutes to
  -- improvement") is a countdown to the next percentage tick, not a label.
  -- LiveView's improveLiveText() now recomputes the remaining time live from
  -- `remaining` + `last_updated` on every render instead, so this just
  -- passes the raw fields through.
  local imp = MyDSL.State.improve or {}
  if imp.skill then
    MyDSL.DB.improve = {
      skill        = imp.skill,
      percent      = imp.percent,
      remaining    = imp.remaining,
      last_updated = imp.last_updated,
    }
  else
    MyDSL.DB.improve = {}
  end
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
MyDSL.DB._handlers.improve  = registerAnonymousEventHandler("MyDSL.improve.updated", onAny)
MyDSL.DB._handlers.gchar    = registerAnonymousEventHandler("gmcp.char_data",        onAny)
MyDSL.DB._handlers.groom    = registerAnonymousEventHandler("gmcp.room_data",        onAny)
MyDSL.DB._handlers.gtick    = registerAnonymousEventHandler("gmcp.tick",             onAny)


------------------------------------------------------------------------
-- INITIAL SYNC  — populate DB from whatever State already holds
------------------------------------------------------------------------
MyDSL.DB.sync()

debugc("[MyDSL] DataBridge loaded.")
