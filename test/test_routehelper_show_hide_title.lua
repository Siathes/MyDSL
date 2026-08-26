-- Real bug found 2026-08-26 (command-parity sweep): MyDSL_History had
-- no dedicated way to hide it via any command at all (the only other
-- window in the whole addon with that gap besides Focus, fixed
-- separately in test_targetview_show_hide_title.lua). Neither History
-- nor PlayersNear had title customization, unlike every other window.
--
-- Run: luajit test/test_routehelper_show_hide_title.lua

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

local showHideCalls = {}
local realShow, realHide = MyDSL.Windows.show, MyDSL.Windows.hide
MyDSL.Windows.show = function(name) showHideCalls[#showHideCalls + 1] = "show:" .. name; return realShow(name) end
MyDSL.Windows.hide = function(name) showHideCalls[#showHideCalls + 1] = "hide:" .. name; return realHide(name) end

local titleSetCalls = {}
_G.Geyser.UserWindow.setTitle = function(self, text) titleSetCalls[self.name] = text; return true end

dofile("MyDSL_RouteHelper.lua")

-- ---- History show/hide -- the real bug --------------------------------

MyDSL.Route.showHistory()
check("Route.showHistory() calls MyDSL.Windows.show(\"MyDSL_History\")",
  showHideCalls[#showHideCalls] == "show:MyDSL_History")

MyDSL.Route.hideHistory()
check("Route.hideHistory() calls MyDSL.Windows.hide(\"MyDSL_History\")",
  showHideCalls[#showHideCalls] == "hide:MyDSL_History")

-- ---- Title customization, both windows ---------------------------------

MyDSL.Route.setHistoryTitle("Game Log")
check("setHistoryTitle() persists via MyDSL.Windows.setTitle()",
  MyDSL.Windows.getTitle("MyDSL_History") == "Game Log")
check("setHistoryTitle() applies the real window title",
  titleSetCalls["MyDSL_History"] == "Game Log")

MyDSL.Route.setPlayersNearTitle("Nearby")
check("setPlayersNearTitle() persists via MyDSL.Windows.setTitle()",
  MyDSL.Windows.getTitle("MyDSL_PlayersNear") == "Nearby")
check("setPlayersNearTitle() applies the real window title",
  titleSetCalls["MyDSL_PlayersNear"] == "Nearby")

MyDSL.Route.setHistoryTitle("")
check("setHistoryTitle('') falls back to the default rather than an empty title",
  MyDSL.Windows.getTitle("MyDSL_History") == "History")

-- ---- A saved custom title survives a fresh console creation ------------

MyDSL.Windows.registry.MyDSL_PlayersNear.console = nil -- force getOrCreateConsole() to rebuild it
MyDSL.Route.setPlayersNearTitle("Nearby Folks")
titleSetCalls["MyDSL_PlayersNear"] = nil
MyDSL.Route.getConsole("MyDSL_PlayersNear")
check("a saved custom title is re-applied the next time the console is (re)created",
  titleSetCalls["MyDSL_PlayersNear"] == "Nearby Folks")

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
