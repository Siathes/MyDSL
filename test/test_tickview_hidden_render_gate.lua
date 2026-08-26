-- Real bug found in the MyDSL 1.0 audit (docs/OPTIMIZATION_AUDIT.md
-- cross-cutting finding #4 / #26, TickSource+TickView "same problem
-- from both ends"): V.render() redid the full setStyleSheet/echo/
-- move/resize sequence on every 4Hz "MyDSL.Timers.Updated" pulse even
-- while the window was fully hidden, so "hide" only stopped the
-- display, not the underlying cost. Confirmed 2026-08-26 that TickView
-- is the only remaining consumer of that 4Hz event (AffectsView/
-- LiveView both already switched to the 1Hz "MyDSL.Timers.Slow"
-- event), so gating this one render path is the real, sufficient fix --
-- TickSource's own loop cadence is deliberately left untouched (slowing
-- it would drift MyDSL.DB.tick's countdown accuracy for every other
-- listener, not just this window).
--
-- Run: luajit test/test_tickview_hidden_render_gate.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

-- Spy on the shared StubWidget methods render() actually calls, so a
-- test can tell "did real render work happen" apart from "did nothing
-- happen" -- the no-op stubs otherwise look identical either way.
local renderCalls = 0
local realSetStyleSheet = _G.Geyser and _G.Geyser.Label and _G.Geyser.Label.setStyleSheet
_G.Geyser.Label.setStyleSheet = function(...)
  renderCalls = renderCalls + 1
  return true
end
_G.Geyser.Label.echo = function(...)
  renderCalls = renderCalls + 1
  return true
end

dofile("MyDSL_TickView.lua")

local V = MyDSL.TickView

-- ---- Case 1: hidden -- render() must not touch any widget -----------------

V.hide()
renderCalls = 0
V.render("timers_pulse")
check("render() does no widget work while hidden", renderCalls == 0)

-- ---- Case 2: shown -- render() must do real work ---------------------------

renderCalls = 0
V.show()
check("show() itself triggers a real render", renderCalls > 0)

renderCalls = 0
V.render("timers_pulse")
check("render() does real widget work while visible", renderCalls > 0)

-- ---- Case 3: WindowRegistry state (not just V.config.shown) is honored ----

MyDSL.Windows = MyDSL.Windows or {}
MyDSL.Windows.registry = MyDSL.Windows.registry or {}
MyDSL.Windows.registry["MyDSL_Tick"] = { visible = false }
V.config.shown = true -- deliberately stale/conflicting local flag
renderCalls = 0
V.render("timers_pulse")
check("render() defers to WindowRegistry's real visibility over a stale local flag",
  renderCalls == 0)

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
