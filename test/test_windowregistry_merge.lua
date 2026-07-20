-- Regression test for the 2026-07-19 real live bug (Steven: "that script
-- blanks my main window, i had to disable"). Root cause: MyDSL_
-- WindowRegistry.lua's registry table used `MyDSL.Windows.registry =
-- MyDSL.Windows.registry or {...}` -- if the registry already exists in
-- memory (true for any in-session script reload, not just a fresh Mudlet
-- start), the whole literal -- including a newly-added window key -- was
-- silently skipped. Fixed by merging new keys into an already-existing
-- registry instead of skipping the whole table.
--
-- Run: luajit test/test_windowregistry_merge.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

-- Simulate an ALREADY-LIVE registry from a previous load, missing a
-- window that only exists in this (newer) version of the file -- exactly
-- the scenario an in-session script reload after adding a new module hits.
MyDSL = MyDSL or {}
MyDSL.Windows = MyDSL.Windows or {}
MyDSL.Windows.registry = {
  MyDSL_Chat = { obj = "existing-live-object", type = "UserWindow", visible = true, created = true },
}
-- Minimal LayoutEngine stub -- WindowRegistry.lua's real ensureAll() (run
-- at its own boot) needs MyDSL.Layout.get() to exist; "no layout entry"
-- is already a handled fallback path (percentsFromLayout()'s own nil
-- check), not something this test needs to exercise.
MyDSL.Layout = { get = function() return nil end }

dofile("MyDSL_WindowRegistry.lua")

check("a pre-existing entry's live state survives the reload untouched",
  MyDSL.Windows.registry.MyDSL_Chat.obj == "existing-live-object"
  and MyDSL.Windows.registry.MyDSL_Chat.created == true)
check("a window key only present in the newer file gets added on reload, not skipped",
  MyDSL.Windows.registry.MyDSL_Leveling ~= nil)
check("the newly-added entry has real defaults, not a stub",
  MyDSL.Windows.registry.MyDSL_Leveling
  and MyDSL.Windows.registry.MyDSL_Leveling.type == "UserWindow"
  and MyDSL.Windows.registry.MyDSL_Leveling.visible == false)

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
