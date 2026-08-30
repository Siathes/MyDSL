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
check("appStyleSheetCSS embeds tron_blue's real borderColor (12,30,162), not a placeholder",
  css:find("rgba(12,30,162", 1, true) ~= nil)
check("appStyleSheetCSS embeds tron_blue's real titleColor (98,160,234)",
  css:find("rgba(98,160,234", 1, true) ~= nil)

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

------------------------------------------------------------------------
-- chromeMode -- "2 versions of each theme" (2026-08-30): "full" also
-- themes native Mudlet chrome, "ui" restores/keeps Mudlet's own default
-- look, touching only MyDSL's own windows (via the existing per-window
-- setUserWindowStyleSheet() path, unaffected by this setting).
------------------------------------------------------------------------
check("chromeMode defaults to 'full'", MyDSL.Theme.chromeMode == "full")

appliedCSS = {}
MyDSL.Theme.setChromeMode("ui")
check("setChromeMode('ui') persists the mode", MyDSL.Theme.chromeMode == "ui")
check("switching to 'ui' immediately clears the app stylesheet (restores native Mudlet chrome)",
  #appliedCSS == 1 and appliedCSS[1] == "")

appliedCSS = {}
MyDSL.Theme.setTheme("muted_scroll_nature")
check("a theme switch while chromeMode is 'ui' does NOT push chrome CSS -- native chrome stays untouched",
  #appliedCSS == 1 and appliedCSS[1] == "")

appliedCSS = {}
MyDSL.Theme.setChromeMode("full")
check("switching back to 'full' immediately re-applies the active theme's chrome CSS",
  #appliedCSS == 1 and appliedCSS[1] == MyDSL.Theme.appStyleSheetCSS(MyDSL.Theme.active))

check("setChromeMode() rejects an invalid mode instead of silently accepting it",
  MyDSL.Theme.setChromeMode("bogus") == false and MyDSL.Theme.chromeMode == "full")

print(string.format("\n%d failure(s)", failures))
os.exit(failures == 0 and 0 or 1)
