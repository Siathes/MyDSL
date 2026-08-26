-- Real bug fix, 2026-08-26, per Steven ("fix databridge and consolidate
-- calls like that"): docs/MYDSL_1.0_MODULE_REDESIGN.md #9 confirmed
-- MyDSL_DataBridge.lua's sync() ran twice per char_data/room_data/tick
-- packet -- 3 of its 11 registrations are raw-GMCP + DataLayer-re-raised
-- pairs for the exact same real-world moment. Coalesced to one call per
-- moment via a zero-delay tempTimer debounce.
--
-- Run: luajit test/test_databridge_debounce.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local registeredHandlers = {}
_G.registerAnonymousEventHandler = function(eventName, fn)
  registeredHandlers[eventName] = fn
  return #registeredHandlers
end

local scheduledTimers = {}
_G.tempTimer = function(delay, fn)
  scheduledTimers[#scheduledTimers + 1] = { delay = delay, fn = fn }
  return #scheduledTimers
end

MyDSL = MyDSL or {}
MyDSL.State = { char = { hp = 100, max_hp = 100 } }
dofile("MyDSL_DataBridge.lua")

check("gmcp.char_data handler was registered", type(registeredHandlers["gmcp.char_data"]) == "function")
check("MyDSL.char.updated handler was registered", type(registeredHandlers["MyDSL.char.updated"]) == "function")

local syncCalls = 0
MyDSL.DB.sync = function() syncCalls = syncCalls + 1 end

-- Simulate the real double-fire: raw GMCP fires, then DataLayer's
-- re-raised event fires for the SAME real-world char update, both
-- within the same synchronous burst.
scheduledTimers = {}
registeredHandlers["gmcp.char_data"]()
registeredHandlers["MyDSL.char.updated"]()
check("both fires within one burst schedule exactly ONE deferred sync, not two",
  #scheduledTimers == 1)

-- A third, unrelated registration firing in the same burst (e.g. room
-- also updated at the same moment) must still coalesce into that same
-- one pending call.
registeredHandlers["gmcp.room_data"]()
check("a third registration firing in the same burst still doesn't schedule a second timer",
  #scheduledTimers == 1)

-- The debounce timer actually firing calls sync() exactly once for the
-- whole burst, and clears the pending flag.
scheduledTimers[1].fn()
check("the deferred callback calls MyDSL.DB.sync() exactly once for the whole burst", syncCalls == 1)
check("_syncScheduled resets to false once the deferred call has run", MyDSL.DB._syncScheduled == false)

-- A genuinely new, later moment must schedule its own new timer, not be
-- blocked by stale pending state from the previous burst.
scheduledTimers = {}
registeredHandlers["gmcp.tick"]()
check("a later, unrelated fire schedules a fresh timer (not stuck from the previous burst)",
  #scheduledTimers == 1)
scheduledTimers[1].fn()
check("that second burst's sync also actually ran", syncCalls == 2)

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
