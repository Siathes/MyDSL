-- Structured name+room capture for "Players near you:", 2026-08-24, per
-- Steven's MyDSL notes ("mapper: highlight other players' rooms from the
-- where command"). Real confirmed shape (log/, DSL_Helpfiles/where.txt):
--
--   Players near you:
--   Youiwe                       The Foyer
--   Kiltion                      The Foyer
--
-- This only tests the DataLayer-side capture/event-raising half; the
-- mapper's own room-lookup/highlight logic is covered separately in
-- test/test_mapper_terrain_lock.lua's highlightPlayersNear() section.
--
-- Run: luajit test/test_datalayer_playersnear_parse.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local capturedHandlers = {}
function _G.registerAnonymousEventHandler(event, fn)
  capturedHandlers[event] = capturedHandlers[event] or {}
  table.insert(capturedHandlers[event], fn)
  return #capturedHandlers[event]
end
function _G.raiseEvent(name, ...)
  for _, fn in ipairs(capturedHandlers[name] or {}) do fn(name, ...) end
  return true
end

dofile("MyDSL_LayoutEngine.lua")
dofile("MyDSL_WindowRegistry.lua")
dofile("MyDSL_DataLayer.lua")
dofile("MyDSL_DataLayer_ScanLook.lua")
dofile("MyDSL_RouteHelper.lua")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local raised = nil
_G.registerAnonymousEventHandler("MyDSL.playersNear.parsed", function(_, list) raised = list end)

------------------------------------------------------------------------
-- Real captured shape, verbatim (log/2026-07-01#16-37-56.txt).
------------------------------------------------------------------------
MyDSL.beginPlayersNear()

local realLines = {
  "Youiwe                       The Foyer",
  "Kiltion                      The Foyer",
  "Vrokt                        The Foyer",
}
for _, ln in ipairs(realLines) do
  _G.line = ln
  _G.__triggers[MyDSL._triggers.playersNearBody].func()
end
_G.line = ""
MyDSL.endPlayersNear()

check("the parsed event was raised at all", raised ~= nil)
check("all 3 real players were captured", raised and #raised == 3)
check("the first entry's name/room split correctly",
  raised and raised[1].name == "Youiwe" and raised[1].room == "The Foyer")
check("a duplicate room name across players is preserved as-is (not deduped)",
  raised and raised[2].room == "The Foyer" and raised[3].room == "The Foyer")

------------------------------------------------------------------------
-- "None" (real DSL output when nobody's near) must not raise an event
-- with bogus/empty data.
------------------------------------------------------------------------
raised = nil
MyDSL.beginPlayersNear()
_G.line = ""
MyDSL.endPlayersNear()
check("an empty players-near block (real 'None' case, no body lines matched) raises no event",
  raised == nil)

print(string.rep("-", 60))
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
