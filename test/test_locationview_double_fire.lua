-- Real double-fire bug fixed 2026-08-26 (window feature-matrix pass,
-- docs/MYDSL_WINDOW_FEATURE_MATRIX.md, carried from docs/
-- MYDSL_1.0_MODULE_REDESIGN.md #37): M.onRoomData() was registered on
-- both "gmcp.room_data" and the mapper's "onNewRoom" for the same
-- room-entry moment, with no unchanged-room early return, so a single
-- real room change could trigger two full refreshes. Also removed the
-- dead "gmcp.Room.Info" handler registration (DSL never sends that
-- generic-GMCP-client form).
--
-- Run: luajit test/test_locationview_double_fire.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

dofile("MyDSL_LocationView.lua")
local M = MyDSL.Location

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local refreshCalls = 0
M.refresh = function(reason) refreshCalls = refreshCalls + 1; return true end

_G.gmcp = _G.gmcp or {}
_G.gmcp.room_data = { room = "Alpha" }

M.currentRoom = nil
M.onRoomData()
check("first onRoomData() (no prior room) refreshes", refreshCalls == 1)

-- Simulate that the refresh above completed a real render and stored the
-- room (M.render() normally sets M.currentRoom -- stubbed out above, so
-- set it directly here to isolate the dedup guard itself).
M.currentRoom = "Alpha"
M.onRoomData()
check("a second onRoomData() for the SAME room (e.g. gmcp.room_data + onNewRoom both firing) does NOT refresh again",
  refreshCalls == 1)

_G.gmcp.room_data = { room = "Beta" }
M.onRoomData()
check("onRoomData() for a genuinely DIFFERENT room still refreshes",
  refreshCalls == 2)

-- Handler registration itself: gmcp.Room.Info must be gone, room_data and
-- onNewRoom must both still be wired (this is what would double-fire in
-- the live game -- confirming the fix doesn't just remove real coverage).
M.handlersInstalled = false
local registered = {}
_G.registerAnonymousEventHandler = function(eventName, fnName)
  registered[eventName] = fnName
  return #registered
end
M.installEvents()
check("gmcp.room_data handler still registered", registered["gmcp.room_data"] == "MyDSL.Location.onRoomData")
check("onNewRoom handler still registered", registered["onNewRoom"] == "MyDSL.Location.onRoomData")
check("the dead gmcp.Room.Info handler is NOT registered", registered["gmcp.Room.Info"] == nil)

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
