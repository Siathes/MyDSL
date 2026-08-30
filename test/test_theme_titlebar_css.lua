-- MyDSL 1.0 visual pass v2 -- "One Bar, Renamed and Colored" -- final
-- locked spec, 2026-08-26, superseding an earlier "Direction A+" build
-- (flatten the native bar to a blank sliver, add a separate themed
-- Geyser.Label underneath). Live on Steven's own machine that showed
-- two stacked title-like elements at once (the flatten step's
-- setTitle("") never actually blanked Mudlet's native title text) --
-- his verdict: one bar, not two, colored, real short name. This test
-- confirms MyDSL.Theme.titleBarCSS() now carries the accent coloring
-- the removed Label used to (same formula, verified exact-match against
-- Claude Desktop's delivered mockup HTML, section 1.6, for 3 of 5
-- presets): text = titleColor at full alpha, background = titleBgColor
-- at its own alpha (the first real consumer of that previously-dead
-- preset key), border-bottom = the window's own borderColor.
--
-- Supersedes test_theme_headerbar_css.lua, which tested the removed
-- MyDSL.Theme.headerLabelCSS() (that formula lives on inside
-- titleBarCSS() now, just targeting a QDockWidget::title{} selector
-- instead of a plain Label's bare declarations) and the old plain-
-- background-flatten titleBarCSS() formula, which is no longer what
-- this function computes.
--
-- Run: luajit test/test_theme_titlebar_css.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

dofile("MyDSL_ThemeEngine.lua")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local function contains(haystack, needle)
  return haystack:find(needle, 1, true) ~= nil
end

-- ---- refined_convergence: titleColor/titleBgColor = 255,209,102 (a=255/90) ----
-- titleBgColor alpha raised 2026-08-26 (was a=15, ~6%, invisible on a
-- real native title bar per Steven's own screenshots) -- see
-- MyDSL_ThemeEngine.lua's comment on refined_convergence's titleBgColor
-- for the full root-cause writeup (tuned for a since-removed header
-- Label's wash effect, never re-tuned for direct native-bar use).

MyDSL.Theme.setTheme("refined_convergence")

local titleBar = MyDSL.Theme.titleBarCSS("MyDSL_Combat")
check("titleBarCSS uses a QDockWidget::title selector, not bare declarations",
  contains(titleBar, "QDockWidget::title"))
check("titleBarCSS text color is titleColor at full alpha (255,209,102)",
  contains(titleBar, "color: rgba(255,209,102,1.00)"))
check("titleBarCSS background is titleBgColor at its own, now-visible alpha (255,209,102 @ 90/255)",
  contains(titleBar, "background-color: rgba(255,209,102,0.35)"))
check("titleBarCSS border-bottom uses the window's own borderColor (33,44,48 @ 200/255)",
  contains(titleBar, "rgba(33,44,48,0.78)"))

-- ---- terminal_purist: titleBgColor is fully transparent (0,0,0,0), --------
-- ---- DELIBERATELY, per this preset's own minimalist design ----------------

MyDSL.Theme.setTheme("terminal_purist")

local titleBar2 = MyDSL.Theme.titleBarCSS("MyDSL_Affects")
check("titleBarCSS text color for terminal_purist is its titleColor (201,162,39)",
  contains(titleBar2, "color: rgba(201,162,39,1.00)"))
check("titleBarCSS background for terminal_purist is fully transparent (titleBgColor a=0, intentional)",
  contains(titleBar2, "background-color: rgba(0,0,0,0.00)"))

-- ---- obsidian_ember: titleBgColor = 230,126,60 @ 90/255 --------------------

MyDSL.Theme.setTheme("obsidian_ember")

local titleBar3 = MyDSL.Theme.titleBarCSS("MyDSL_Scan")
check("titleBarCSS text color for obsidian_ember is its titleColor (230,126,60)",
  contains(titleBar3, "color: rgba(230,126,60,1.00)"))
check("titleBarCSS background for obsidian_ember is titleBgColor, now-visible (230,126,60 @ 90/255)",
  contains(titleBar3, "background-color: rgba(230,126,60,0.35)"))

-- ---- tron_blue: titleColor 80,230,255, titleBgColor 0,180,255 @ 90/255 ----

MyDSL.Theme.setTheme("tron_blue")

local titleBar4 = MyDSL.Theme.titleBarCSS("MyDSL_Combat")
check("titleBarCSS text color for tron_blue is its titleColor (80,230,255)",
  contains(titleBar4, "color: rgba(80,230,255,1.00)"))
check("titleBarCSS background for tron_blue is titleBgColor (0,180,255 @ 90/255)",
  contains(titleBar4, "background-color: rgba(0,180,255,0.35)"))

-- ---- muted_scroll_nature: titleColor 196,180,110, titleBgColor 120,110,60 @ 90/255 ----

MyDSL.Theme.setTheme("muted_scroll_nature")

local titleBar5 = MyDSL.Theme.titleBarCSS("MyDSL_History")
check("titleBarCSS text color for muted_scroll_nature is its titleColor (196,180,110)",
  contains(titleBar5, "color: rgba(196,180,110,1.00)"))
check("titleBarCSS background for muted_scroll_nature is titleBgColor (120,110,60 @ 90/255)",
  contains(titleBar5, "background-color: rgba(120,110,60,0.35)"))

-- ---- headerLabelCSS is gone -- one bar, not two ----------------------------

check("MyDSL.Theme.headerLabelCSS no longer exists -- the separate-Label mechanism was removed",
  MyDSL.Theme.headerLabelCSS == nil)

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
