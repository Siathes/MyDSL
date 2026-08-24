-- Structural test for the 2026-08-24 identify source-scoping fix, per
-- Steven ("if someone posts an identified item, the item reference
-- captures that for its info, but its enchanted and not the normal
-- stats, need a way to seperate or just not replace the info unless
-- self identified").
--
-- Confirmed real via 3 corpus-verified mechanisms that all produce the
-- exact same "Object '<name>' is type ..." line MyDSL.beginIdentify()
-- fires on: a real self-cast identify ("c ident <target>"), a shop
-- `insp`/`inspect <item>` command (a shopkeeper's for-sale item, not
-- the player's own), and `anote read` (a bulletin-board note whose text
-- can itself quote an identify-shaped block someone else pasted in --
-- log/2026-07-04#12-43-48.html). Fix: only trust "Object '...' is
-- type..." as a real self-identify if the player's own most recent
-- outgoing command (via sysDataSendRequest) was genuinely an
-- identify-cast within a 6-second freshness window; otherwise tag it
-- source="observed" so MyDSL_ItemLore.lua's existing two-tier trust
-- model (IL.merge()) automatically treats it as fill-gaps-only, the
-- same safe treatment `lore` already gets.
--
-- Run: luajit test/test_identify_source_scoping.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

-- mudlet_mock.lua's default registerAnonymousEventHandler is a no-op
-- (see test/README.md) -- override to actually record handlers so
-- sysDataSendRequest can be fired manually below, same technique
-- test_mapper_gmcp_and_doorverb.lua already established.
local eventHandlers = {}
function _G.registerAnonymousEventHandler(event, fn)
  eventHandlers[event] = eventHandlers[event] or {}
  table.insert(eventHandlers[event], fn)
  return #eventHandlers[event]
end

_G.matches = _G.matches or {}
MyDSL = MyDSL or {}
dofile("MyDSL_DataLayer.lua")
dofile("MyDSL_ItemLore.lua")
local IL = MyDSL.ItemLore

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local function sendCommand(cmd)
  for _, fn in ipairs(eventHandlers["sysDataSendRequest"] or {}) do fn(nil, cmd) end
end

local function runIdentifyBlock(objectLine)
  MyDSL.beginIdentify(objectLine)
  -- endIdentify() fires when the body trigger sees a blank line -- drive
  -- it directly the way the real tempRegexTrigger body would.
  MyDSL.endIdentify()
end

------------------------------------------------------------------------
-- 1. Real self-cast identify: armed correctly, tagged "identify"
------------------------------------------------------------------------
sendCommand("c ident claw")
runIdentifyBlock("Object 'badger claw' is type weapon, extra flags none.")
check("a real 'c ident' command arms capture as source=identify",
  IL.db["badger claw"] and IL.db["badger claw"].source == "identify")

------------------------------------------------------------------------
-- 2. Shop inspect: real corpus command, must NOT be trusted as self-identify
------------------------------------------------------------------------
IL.db["murky jar"] = nil
sendCommand("insp jar")
runIdentifyBlock("Object 'murky jar' is type potion, extra flags magic inventory.")
check("a shop 'insp' command does NOT arm capture as source=identify",
  IL.db["murky jar"] and IL.db["murky jar"].source == "observed")

------------------------------------------------------------------------
-- 3. Reading a note that happens to quote identify-shaped text (real
-- corpus mechanism, log/2026-07-04#12-43-48.html: a seller pasted their
-- own identify output into an auction note) -- no outgoing command at
-- all immediately before it arrives, must not be trusted either.
------------------------------------------------------------------------
IL.db["arcanium breastplate"] = nil
MyDSL._lastOutgoingCommand = nil  -- simulates "anote read" (no identify-shaped command sent)
runIdentifyBlock("Object 'arcanium breastplate' is type plate_armor, extra flags glow magic.")
check("text arriving with no recent identify-shaped outgoing command is tagged source=observed",
  IL.db["arcanium breastplate"] and IL.db["arcanium breastplate"].source == "observed")

------------------------------------------------------------------------
-- 4. Freshness window: a real identify-cast command more than 6 seconds
-- ago must not be trusted for a LATER, unrelated Object line (same
-- stale-context-replay risk this project has already fixed once before
-- for the mapper's own door/move command queues).
------------------------------------------------------------------------
IL.db["stale test item"] = nil
MyDSL._lastOutgoingCommand = { cmd = "c ident something else", time = os.time() - 10 }
runIdentifyBlock("Object 'stale test item' is type misc, extra flags none.")
check("a stale (>6s) identify command does not arm capture for a later line",
  IL.db["stale test item"] and IL.db["stale test item"].source == "observed")

------------------------------------------------------------------------
-- 5. The actual safety property Steven asked for: an "observed" capture
-- must never clobber a real, already-identified record's confirmed
-- stats -- mirrors IL.merge()'s existing lore-vs-identify trust model.
------------------------------------------------------------------------
IL.db["enchanted ring"] = {
  key = "enchanted ring", name = "enchanted ring", itemType = "misc",
  affects = { { stat = "hit roll", amount = 3 } }, source = "identify",
}
MyDSL._lastOutgoingCommand = nil
-- Someone else's enchanted-variant "enchanted ring" gets observed with
-- no affects line in this particular block (a plain/base version) --
-- must NOT erase the real player's own confirmed +3 hit roll.
runIdentifyBlock("Object 'enchanted ring' is type misc, extra flags none.")
check("an unarmed 'observed' capture never clears a real identify's confirmed stats",
  IL.db["enchanted ring"].affects ~= nil and IL.db["enchanted ring"].affects[1].amount == 3)

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
