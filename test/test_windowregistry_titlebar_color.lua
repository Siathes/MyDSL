-- MyDSL 1.0 visual pass v2 -- "One Bar, Renamed and Colored" -- final
-- locked spec, 2026-08-26. Confirms MyDSL_WindowRegistry.lua's
-- applyTheme() (run by ensure() on every UserWindow creation and every
-- theme switch) actually appends MyDSL.Theme.titleBarCSS()'s
-- QDockWidget::title{} coloring rule onto the real setStyleSheet()
-- call, alongside the pre-existing panelCSS() frame styling -- not just
-- that the two functions exist in isolation (test_theme_headerbar_css.lua
-- already covers that).
--
-- Supersedes test_windowregistry_titlebar_flatten.lua -- that name and
-- its assertions described an earlier "Direction A+" build (flatten the
-- bar to a blank sliver, add a separate header Label) that got reverted
-- after it rendered as two stacked title-like elements on Steven's own
-- machine. This is now a rename+recolor, not a flatten -- the window's
-- own setTitle() call (not exercised here, done per-View-file) supplies
-- the visible text.
--
-- Run: luajit test/test_windowregistry_titlebar_color.lua

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
check("applyTheme() also appends titleBarCSS()'s QDockWidget::title coloring rule",
  css and css:find("QDockWidget::title", 1, true) ~= nil)
check("the appended rule carries real color (not just a bare background flatten)",
  css and css:find("color:", 1, true) ~= nil)

-- REAL BUG found live 2026-08-26, 4th round on this feature: panelCSS()
-- returns bare declarations with no selector (undocumented Qt syntax,
-- confirmed via Qt's own stylesheet-syntax docs -- it happened to work
-- for years only because it was always the ENTIRE stylesheet string).
-- Concatenating it directly in front of titleBarCSS()'s real
-- QDockWidget::title{} selector rule produced a string where the
-- appended rule silently failed to apply -- Steven's own screenshot
-- showed zero coloring anywhere despite the CSS values themselves being
-- correct (confirmed separately by test_theme_titlebar_css.lua). Fixed
-- by wrapping panelCSS()'s declarations in an explicit QDockWidget{}
-- selector at this call site, matching the exact two-explicit-rule-
-- blocks shape Mudlet's own wiki confirms works. This assertion is the
-- one that would have caught the real bug -- the two checks above only
-- confirmed each piece of TEXT was present somewhere in the string, not
-- that the string was structured as valid, parseable Qt stylesheet syntax.
check("panelCSS()'s declarations are wrapped in an explicit QDockWidget{} selector, not left bare",
  css and css:find("QDockWidget{", 1, true) ~= nil)
check("the QDockWidget{} block comes before the QDockWidget::title{} block, matching Mudlet's own confirmed-working wiki example shape",
  css and (css:find("QDockWidget{", 1, true) or math.huge) < (css:find("QDockWidget::title", 1, true) or 0))

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
