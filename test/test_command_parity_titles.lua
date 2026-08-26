-- Command-parity sweep, 2026-08-26: title customization was missing on
-- 11 of 17 windows (Steven: "i dont like that these are different...
-- match all features and functions"). Each new setTitle() follows the
-- exact same proven shape (trim, fall back to the real default on
-- empty input, persist via the shared MyDSL.Windows.setTitle()/
-- getTitle(), apply to the live window). Covers the windows whose
-- setTitle() routes through that shared mechanism (Combat, Group,
-- Scan, RightHere, Bestiary, Item Reference) -- Chat has its own
-- pre-existing settings file instead (spot-checked separately, same
-- pattern); Focus and History/PlayersNear have their own dedicated
-- test files already (test_targetview_show_hide_title.lua,
-- test_routehelper_show_hide_title.lua).
--
-- Run: luajit test/test_command_parity_titles.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

MyDSL = MyDSL or {}
MyDSL.Layout = { get = function() return nil end }
dofile("MyDSL_ThemeEngine.lua")
dofile("MyDSL_WindowRegistry.lua")

local titleSetCalls = {}
_G.Geyser.UserWindow.setTitle = function(self, text) titleSetCalls[self.name] = text; return true end

dofile("MyDSL_CombatView.lua")
dofile("MyDSL_GroupView.lua")
dofile("MyDSL_ScanView.lua")
dofile("MyDSL_CreatureReference.lua")
dofile("MyDSL_ItemReference.lua")

local cases = {
  { mod = "CombatView",        win = "MyDSL_Combat",             fn = "setTitle",             default = "Combat" },
  { mod = "GroupView",         win = "MyDSL_Group",               fn = "setTitle",             default = "Group" },
  { mod = "ScanView",          win = "MyDSL_Scan",                fn = "setTitle",             default = "Scan" },
  { mod = "ScanView",          win = "MyDSL_RightHere",           fn = "setRightHereTitle",    default = "Right Here" },
  { mod = "CreatureReference", win = "MyDSL_CreatureReference",   fn = "setTitle",             default = "Bestiary" },
  { mod = "ItemReference",     win = "MyDSL_ItemReference",       fn = "setTitle",             default = "Item Reference" },
}

for _, c in ipairs(cases) do
  local obj = MyDSL[c.mod]
  check(c.mod .. "." .. c.fn .. " exists", type(obj) == "table" and type(obj[c.fn]) == "function")

  obj[c.fn]("Custom " .. c.win)
  check(c.mod .. "." .. c.fn .. "(...) persists via MyDSL.Windows.getTitle()",
    MyDSL.Windows.getTitle(c.win) == "Custom " .. c.win)
  check(c.mod .. "." .. c.fn .. "(...) applies the real window title",
    titleSetCalls[c.win] == "Custom " .. c.win)

  obj[c.fn]("")
  check(c.mod .. "." .. c.fn .. "('') falls back to the real default (\"" .. c.default .. "\")",
    MyDSL.Windows.getTitle(c.win) == c.default)
end

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
