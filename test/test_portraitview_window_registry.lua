-- Real bug found in the MyDSL 1.0 native-content audit pass 2
-- (docs/OPTIMIZATION_AUDIT.md section 33, 2026-08-26): getWindowEntry()
-- read MyDSL.Windows.windows[...], a table that has never existed
-- anywhere in this codebase -- the real one MyDSL_WindowRegistry.lua
-- actually populates is MyDSL.Windows.registry. Confirms P.ensureWindow()
-- now picks up the real registered window object instead of silently
-- falling through to building a second, orphaned Geyser.UserWindow.
--
-- Run: luajit test/test_portraitview_window_registry.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local registeredWindowObj = { isRealRegisteredWindow = true }

_G.MyDSL = nil
_G.Geyser = _G.Geyser or {}
_G.Geyser.UserWindow = {
  new = function(_, cfg) return { name = cfg.name, isOrphanedFallback = true } end,
}

_G.MyDSL = { Windows = {
  ensure = function() end,
  registry = { Portrait = { obj = registeredWindowObj } },
} }

dofile("MyDSL_PortraitView.lua")

MyDSL.Portrait.ensureWindow()

check("ensureWindow() picks up the real MyDSL.Windows.registry entry",
  MyDSL.Portrait.window == registeredWindowObj)
check("ensureWindow() does NOT fall through to a second, orphaned Geyser.UserWindow",
  not (MyDSL.Portrait.window and MyDSL.Portrait.window.isOrphanedFallback))

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
