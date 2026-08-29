-- Real gap found 2026-08-29, per Steven's GroupView/TargetView button-UX
-- review ("I want to make changing buttons easier for the user"): neither
-- "focus mobset/playerset <6 keys>" nor "group quickset <2 keys>" ever had
-- a way to discover which keys are valid -- a player had to already know
-- an internal key like "cure_bugbite" from reading source. Added
-- TV.listActions(), wired to both "focus actions" and "group actions"
-- (GroupView delegates rather than duplicating, since TV.actions/
-- custom_actions is the one real registry both modules already share --
-- confirmed by GV.quickAction() looking up MyDSL.TargetView.actions
-- directly).
--
-- Run: luajit test/test_targetview_groupview_list_actions.lua

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

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

_G.MyDSL = _G.MyDSL or {}
dofile("MyDSL_LayoutEngine.lua")
dofile("MyDSL_WindowRegistry.lua")
dofile("MyDSL_DataLayer.lua")
dofile("MyDSL_TargetView.lua")
dofile("MyDSL_GroupView.lua")

local echoed = {}
_G.echo = function(s) echoed[#echoed + 1] = s end

MyDSL.TargetView.listActions()
local output = table.concat(echoed)

check("listActions() lists a real built-in action (heal)", output:find("heal", 1, true) ~= nil)
check("listActions() lists a real built-in action (murder)", output:find("murder", 1, true) ~= nil)
check("listActions() includes each action's label", output:find("Heal", 1, true) ~= nil)
check("listActions() includes each action's tooltip", output:find("Cast heal on target", 1, true) ~= nil)

-- A custom action, once defined, must also show up -- same registry.
MyDSL.TargetView.defineAction("scan", "Scan", "204,204,204", "scan")
echoed = {}
MyDSL.TargetView.listActions()
output = table.concat(echoed)
check("listActions() includes a custom action after focus action defines it",
  output:find("scan", 1, true) ~= nil and output:find("Scan", 1, true) ~= nil)

-- GroupView's own alias must delegate to the exact same function, not a
-- separate copy that could drift out of sync.
check("MyDSL.GroupView has no separate listActions of its own (delegates to TargetView's)",
  MyDSL.GroupView.listActions == nil)

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
