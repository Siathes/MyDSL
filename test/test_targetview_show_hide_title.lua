-- Real bug found 2026-08-26 (command-parity sweep): MyDSL_Focus had no
-- way to hide it via any dedicated command at all, and no title
-- customization -- both real gaps every other window's standard
-- controls already covered.
--
-- Run: luajit test/test_targetview_show_hide_title.lua

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

local showHideCalls = {}
_G.MyDSL = _G.MyDSL or {}

dofile("MyDSL_LayoutEngine.lua")
dofile("MyDSL_WindowRegistry.lua")

-- Spy on the real show()/hide() this depends on, same technique as
-- other WindowRegistry-integration tests this session.
local realShow, realHide = MyDSL.Windows.show, MyDSL.Windows.hide
MyDSL.Windows.show = function(name) showHideCalls[#showHideCalls + 1] = "show:" .. name; return realShow(name) end
MyDSL.Windows.hide = function(name) showHideCalls[#showHideCalls + 1] = "hide:" .. name; return realHide(name) end

dofile("MyDSL_DataLayer.lua")
dofile("MyDSL_TargetView.lua")

local titleSetCalls = {}
_G.Geyser.UserWindow.setTitle = function(self, text) titleSetCalls[self.name] = text; return true end

MyDSL.TargetView.show()
check("TV.show() calls MyDSL.Windows.show(\"MyDSL_Focus\")",
  showHideCalls[#showHideCalls] == "show:MyDSL_Focus")

MyDSL.TargetView.hide()
check("TV.hide() calls MyDSL.Windows.hide(\"MyDSL_Focus\")",
  showHideCalls[#showHideCalls] == "hide:MyDSL_Focus")

MyDSL.TargetView.setTitle("My Target")
check("TV.setTitle() updates TV.config.title",
  MyDSL.TargetView.config.title == "My Target")
check("TV.setTitle() applies the real window title",
  titleSetCalls["MyDSL_Focus"] == "My Target")

MyDSL.TargetView.setTitle("")
check("TV.setTitle('') falls back to the default rather than an empty title",
  MyDSL.TargetView.config.title == "Focus")

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
