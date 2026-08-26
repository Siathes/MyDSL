-- Real bug found 2026-08-26 (window feature-matrix pass,
-- docs/MYDSL_WINDOW_FEATURE_MATRIX.md): MyDSL_CombatView.lua's CV.show()/
-- CV.hide() existed (since the 2026-07-11 command-surface retrofit) and
-- correctly called MyDSL.Windows.show/hide, but no alias was ever wired
-- to them directly -- only "toggle battle" reached whole-window
-- visibility. The pre-existing "mydsl combat show <flag>"/"hide <flag>"
-- aliases toggle a different, per-feature config.show_<flag> entry, not
-- the window itself -- easy to mistake for the missing one at a glance.
-- Every other window in the addon has a direct show/hide alias; Combat
-- was the sole exception.
--
-- Run: luajit test/test_combatview_show_hide.lua

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

dofile("MyDSL_DataLayer.lua")
dofile("MyDSL_CombatView.lua")

check("CombatView.show exists", type(MyDSL.CombatView.show) == "function")
check("CombatView.hide exists", type(MyDSL.CombatView.hide) == "function")

MyDSL.CombatView.show()
check("CombatView.show() calls MyDSL.Windows.show(\"MyDSL_Combat\")",
  showHideCalls[#showHideCalls] == "show:MyDSL_Combat")

MyDSL.CombatView.hide()
check("CombatView.hide() calls MyDSL.Windows.hide(\"MyDSL_Combat\")",
  showHideCalls[#showHideCalls] == "hide:MyDSL_Combat")

-- The distinct per-feature "show <flag>"/"hide <flag>" aliases must still
-- be a totally separate mechanism (config.show_<flag>), not accidentally
-- merged into whole-window visibility by this fix.
check("CombatView.config.show_damage still exists as its own flag (unaffected by this fix)",
  MyDSL.CombatView.config.show_damage ~= nil)

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
