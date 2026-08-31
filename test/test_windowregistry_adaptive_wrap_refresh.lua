-- Real bug found 2026-08-30 while investigating Steven's "need text to
-- wrap in focus" report (MyDSL Test/notes.json + a screenshot showing a
-- clipped Affects line): MyDSL.Windows.enableAdaptiveWrap()'s old
-- permanent one-shot guard meant enableAutoWrap() (which computes its
-- wrap column from the console's CURRENT font size) only ever ran once
-- per console, ever. A later font-size-only change (e.g. `focus font
-- <n>`) calls setFontSize() but fires no window resize/reposition event,
-- so the wrap column silently went stale -- text would overflow instead
-- of wrapping for anyone who changed a window's font after first load.
-- Fixed: enableAdaptiveWrap() now takes an optional fontSize and
-- re-enables wrap whenever the caller's reported size actually changes.
--
-- Run: luajit test/test_windowregistry_adaptive_wrap_refresh.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

dofile("MyDSL_LayoutEngine.lua")
dofile("MyDSL_WindowRegistry.lua")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local function fakeConsole()
  local calls = 0
  local con = {}
  function con.enableAutoWrap(self) calls = calls + 1 end
  return con, function() return calls end
end

-- No fontSize passed at all: old callers keep the strictly-once behavior.
local con1, calls1 = fakeConsole()
MyDSL.Windows.enableAdaptiveWrap(con1)
MyDSL.Windows.enableAdaptiveWrap(con1)
check("no-fontSize caller: enableAutoWrap runs exactly once across repeated calls", calls1() == 1)

-- Same fontSize passed repeatedly: still only runs once (no wasted recompute).
local con2, calls2 = fakeConsole()
MyDSL.Windows.enableAdaptiveWrap(con2, 9)
MyDSL.Windows.enableAdaptiveWrap(con2, 9)
MyDSL.Windows.enableAdaptiveWrap(con2, 9)
check("same fontSize repeated: enableAutoWrap runs exactly once", calls2() == 1)

-- The real bug fixed: fontSize actually changes (e.g. a live "focus font
-- <n>" command) -- wrap must re-enable so the column recomputes.
local con3, calls3 = fakeConsole()
MyDSL.Windows.enableAdaptiveWrap(con3, 9)
MyDSL.Windows.enableAdaptiveWrap(con3, 14)
check("fontSize change re-triggers enableAutoWrap (the real fix)", calls3() == 2)
MyDSL.Windows.enableAdaptiveWrap(con3, 14)
check("re-triggering settles: no further calls once size is stable again", calls3() == 2)

print(string.rep("-", 60))
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
