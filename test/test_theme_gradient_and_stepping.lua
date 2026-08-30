-- Regression test for MyDSL_ThemeEngine.lua's 2026-08-30 additions:
-- bgGradient support in panelCSS() (the tron_blue/obsidian_ember/
-- arcane_midnight/library/pink_pastel "full rewrite" pass) and
-- stepTheme()/theme next/prev (Steven: "add a theme next/prev command
-- to walk through themes?").
--
-- Run: luajit test/test_theme_gradient_and_stepping.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

dofile("MyDSL_ThemeEngine.lua")

------------------------------------------------------------------------
-- panelCSS() -- bgGradient support, backward-compatible
------------------------------------------------------------------------
MyDSL.Theme.setTheme("tron_blue")
local css = MyDSL.Theme.panelCSS("MyDSL_Scan")
check("panelCSS() uses a real QLinearGradient for a preset that defines bgGradient",
  css:find("QLinearGradient", 1, true) ~= nil)
check("the gradient's first stop is the preset's own bgGradient.from color (2,3,10)",
  css:find("rgba(2,3,10", 1, true) ~= nil)
check("the gradient's second stop is the preset's own bgGradient.to color (5,15,104)",
  css:find("rgba(5,15,104", 1, true) ~= nil)

MyDSL.Theme.setTheme("refined_convergence")
local cssFlat = MyDSL.Theme.panelCSS("MyDSL_Scan")
check("a preset with no bgGradient key falls back to its flat bgColor (no regression for older presets)",
  cssFlat:find("QLinearGradient", 1, true) == nil and cssFlat:find("background-color: rgba(", 1, true) ~= nil)

------------------------------------------------------------------------
-- stepTheme() / theme next/prev
------------------------------------------------------------------------
MyDSL.Theme.active = MyDSL.Theme.presetOrder[1]
local second = MyDSL.Theme.stepTheme(1)
check("stepTheme(1) moves to the next entry in presetOrder",
  second == MyDSL.Theme.presetOrder[2] and MyDSL.Theme.active == second)

local backToFirst = MyDSL.Theme.stepTheme(-1)
check("stepTheme(-1) moves back to the previous entry",
  backToFirst == MyDSL.Theme.presetOrder[1])

MyDSL.Theme.active = MyDSL.Theme.presetOrder[1]
local wrapped = MyDSL.Theme.stepTheme(-1)
check("stepTheme(-1) from the first entry wraps around to the last",
  wrapped == MyDSL.Theme.presetOrder[#MyDSL.Theme.presetOrder])

MyDSL.Theme.active = MyDSL.Theme.presetOrder[#MyDSL.Theme.presetOrder]
local wrappedForward = MyDSL.Theme.stepTheme(1)
check("stepTheme(1) from the last entry wraps around to the first",
  wrappedForward == MyDSL.Theme.presetOrder[1])

------------------------------------------------------------------------
-- resetToDefault() -- "there should also be a restore to mudlet defauls"
------------------------------------------------------------------------
MyDSL.Theme.setTheme("tron_blue")
MyDSL.Theme.setChromeMode("full")
MyDSL.Theme.resetToDefault()
check("resetToDefault() switches to refined_convergence", MyDSL.Theme.active == "refined_convergence")
check("resetToDefault() switches chromeMode to 'ui' (native Mudlet UI restored)",
  MyDSL.Theme.chromeMode == "ui")

print(string.format("\n%d failure(s)", failures))
os.exit(failures == 0 and 0 or 1)
