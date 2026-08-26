-- MyDSL 1.0 visual pass v2 -- "Direction A+, Quiet Chrome, Cross-
-- Platform" -- locked spec confirmed by Steven 2026-08-26 (HANDOFF.md).
-- Confirms MyDSL_WindowRegistry.lua's applyTheme() (run by ensure() on
-- every UserWindow creation and every theme switch) actually appends
-- MyDSL.Theme.titleBarCSS()'s QDockWidget::title{} flatten rule onto
-- the real setStyleSheet() call, alongside the pre-existing panelCSS()
-- frame styling -- not just that the two functions exist in isolation
-- (test_theme_headerbar_css.lua already covers that).
--
-- Run: luajit test/test_windowregistry_titlebar_flatten.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

-- Spy on setStyleSheet to capture what applyTheme() actually sends,
-- same technique as test_tickview_hidden_render_gate.lua.
local styleSheetCalls = {}
_G.Geyser.UserWindow.setStyleSheet = function(self, css)
  styleSheetCalls[self.name] = css
  return true
end

MyDSL = MyDSL or {}
MyDSL.Layout = { get = function() return nil end }
dofile("MyDSL_ThemeEngine.lua")
dofile("MyDSL_WindowRegistry.lua")

local winObj = MyDSL.Windows.ensure("MyDSL_Chat")

check("ensure() actually created the window", winObj ~= nil)
local css = styleSheetCalls["MyDSL_Chat"]
check("applyTheme() called setStyleSheet() at all", css ~= nil)
check("applyTheme() includes panelCSS()'s own frame styling",
  css and css:find("border%-radius") ~= nil)
check("applyTheme() also appends titleBarCSS()'s native-bar flatten rule",
  css and css:find("QDockWidget::title", 1, true) ~= nil)

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
