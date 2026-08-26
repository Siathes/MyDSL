-- MyDSL 1.0 visual pass v2 -- "Direction A+, Quiet Chrome, Cross-
-- Platform" -- locked spec confirmed by Steven 2026-08-26 via Claude
-- Desktop's research/mockups (HANDOFF.md). Confirms MyDSL.Theme.
-- titleBarCSS()/headerLabelCSS() compute the exact values Desktop's
-- delivered mockup HTML (MyDSL_1.0_visual_pass_v2_mockups_2.html,
-- section 1.5) shows for 3 of the 5 presets -- not just "produces a
-- string," but the specific confirmed formula: header text = titleColor
-- (full alpha), header background = titleBgColor (its own alpha, the
-- first real consumer of that previously-dead key), border-bottom =
-- the window's own borderColor, native bar flattened to the window's
-- own bgColor.
--
-- Run: luajit test/test_theme_headerbar_css.lua

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

-- ---- refined_convergence: titleColor/titleBgColor = 255,209,102 (a=255/15) ----

MyDSL.Theme.setTheme("refined_convergence")

local titleBar = MyDSL.Theme.titleBarCSS("MyDSL_Combat")
check("titleBarCSS uses a QDockWidget::title selector, not bare declarations",
  contains(titleBar, "QDockWidget::title"))
check("titleBarCSS flattens the native bar to the window's own bgColor (11,16,19 @ 242/255)",
  contains(titleBar, "rgba(11,16,19,0.95)"))
check("titleBarCSS removes the native border", contains(titleBar, "border: none"))

local header = MyDSL.Theme.headerLabelCSS("MyDSL_Combat")
check("headerLabelCSS text color is titleColor at full alpha (255,209,102)",
  contains(header, "color: rgba(255,209,102,1.00)"))
check("headerLabelCSS background is titleBgColor at its own alpha (255,209,102 @ 15/255)",
  contains(header, "background-color: rgba(255,209,102,0.06)"))
check("headerLabelCSS border-bottom uses the window's own borderColor (33,44,48 @ 200/255)",
  contains(header, "rgba(33,44,48,0.78)"))
check("headerLabelCSS is small and discreet -- 10.5px, normal weight",
  contains(header, "font-size: 10.5px") and contains(header, "font-weight: normal"))

-- ---- terminal_purist: titleBgColor is fully transparent (0,0,0,0) ----------

MyDSL.Theme.setTheme("terminal_purist")

local header2 = MyDSL.Theme.headerLabelCSS("MyDSL_Affects")
check("headerLabelCSS text color for terminal_purist is its titleColor (201,162,39)",
  contains(header2, "color: rgba(201,162,39,1.00)"))
check("headerLabelCSS background for terminal_purist is fully transparent (titleBgColor a=0)",
  contains(header2, "background-color: rgba(0,0,0,0.00)"))

-- ---- obsidian_ember: titleBgColor = 230,126,60 @ 20/255 --------------------

MyDSL.Theme.setTheme("obsidian_ember")

local header3 = MyDSL.Theme.headerLabelCSS("MyDSL_Scan")
check("headerLabelCSS text color for obsidian_ember is its titleColor (230,126,60)",
  contains(header3, "color: rgba(230,126,60,1.00)"))
check("headerLabelCSS background for obsidian_ember is titleBgColor (230,126,60 @ 20/255)",
  contains(header3, "background-color: rgba(230,126,60,0.08)"))

-- ---- Header text is window-name-only -- callers own the actual text -------
-- (headerLabelCSS only returns styling, never the text itself -- confirms
-- the function's contract doesn't bake in a "MyDSL -- " prefix or any
-- other text, since the locked spec explicitly rules that out).
check("headerLabelCSS returns styling only, never embeds any window-name text itself",
  not contains(header3, "MyDSL") and not contains(header3, "Scan"))

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
