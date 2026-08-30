-- Regression test for MyDSL_ThemeEngine.lua's appStyleSheetCSS()/
-- applyAppStyleSheet(), added 2026-08-30 per Steven ("anyway to target
-- the grey mudlet ui parts, like the tabs and the minimap grey areas,
-- scroll bars etc?"). setAppStyleSheet() is Mudlet's only lever for
-- native chrome (confirmed whole-app-scope via Mudlet's own source,
-- TLuaInterpreterUI.cpp -- qApp->setStyleSheet(), not additive with
-- anything else), so this focuses on: the built CSS actually embeds the
-- ACTIVE theme's real colors (not a placeholder), it changes when the
-- theme switches, and setTheme()/module load both actually call
-- setAppStyleSheet() with it.
--
-- Run: luajit test/test_theme_app_stylesheet.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local appliedCSS = {}
_G.setAppStyleSheet = function(css) appliedCSS[#appliedCSS + 1] = css; return true end

dofile("MyDSL_ThemeEngine.lua")

check("module load applies an app stylesheet immediately (chrome matches the active theme from the start)",
  #appliedCSS >= 1)

------------------------------------------------------------------------
-- appStyleSheetCSS() embeds the real theme colors
------------------------------------------------------------------------
local css = MyDSL.Theme.appStyleSheetCSS("tron_blue")
check("appStyleSheetCSS targets QTabBar (Chat's own tab bar)", css:find("QTabBar::tab", 1, true) ~= nil)
check("appStyleSheetCSS targets QComboBox (the map's Area dropdown)", css:find("QComboBox", 1, true) ~= nil)
check("appStyleSheetCSS targets QScrollBar", css:find("QScrollBar", 1, true) ~= nil)
check("appStyleSheetCSS embeds tron_blue's real borderColor (10,150,220), not a placeholder",
  css:find("rgba(10,150,220", 1, true) ~= nil)
check("appStyleSheetCSS embeds tron_blue's real titleColor (80,230,255)",
  css:find("rgba(80,230,255", 1, true) ~= nil)

local cssOther = MyDSL.Theme.appStyleSheetCSS("muted_scroll_nature")
check("a different theme produces genuinely different CSS, not the same string reused",
  cssOther ~= css)

------------------------------------------------------------------------
-- setTheme() re-applies the app stylesheet on every switch
------------------------------------------------------------------------
appliedCSS = {}
MyDSL.Theme.setTheme("tron_blue")
check("setTheme() calls setAppStyleSheet() again so native chrome follows the switch",
  #appliedCSS == 1)
check("the CSS applied on switch matches this theme's own appStyleSheetCSS()",
  appliedCSS[1] == MyDSL.Theme.appStyleSheetCSS("tron_blue"))

print(string.format("\n%d failure(s)", failures))
os.exit(failures == 0 and 0 or 1)
