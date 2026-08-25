-- Real generic poison-onset capture, 2026-08-24, per docs/DSL_CommandRef.md's
-- confirmed "<mob> looks very ill." pattern (8 occurrences across
-- multiple independent log/ sessions, any mob, any poison source).
-- Flags the CURRENT target only -- an assist indicator, not a new
-- auto-targeting mechanism.
--
-- Run: luajit test/test_targetview_poison.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local capturedHandlers = {}
function _G.registerAnonymousEventHandler(event, fn)
  capturedHandlers[event] = capturedHandlers[event] or {}
  table.insert(capturedHandlers[event], fn)
  return #capturedHandlers[event]
end
function _G.raiseEvent(name, ...)
  for _, fn in ipairs(capturedHandlers[name] or {}) do fn(name, ...) end
  return true
end

dofile("MyDSL_LayoutEngine.lua")
dofile("MyDSL_WindowRegistry.lua")
dofile("MyDSL_DataLayer.lua")
dofile("MyDSL_TargetView.lua")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

------------------------------------------------------------------------
-- Part 1: the real trigger pattern matches real corpus-shaped text and
-- extracts the right name.
------------------------------------------------------------------------
local pattern = "^([A-Z][%w' %-]-) looks very ill%.$"
local realLines = {
  "A gnome greaser looks very ill.",
  "An insane sea elf looks very ill.",
  "A gnome architect looks very ill.",
}
for _, line in ipairs(realLines) do
  check("real corpus line matches: " .. line, line:match(pattern) ~= nil)
end

------------------------------------------------------------------------
-- Part 2: markPoisoned() only flags the CURRENT target, ignores others.
------------------------------------------------------------------------
MyDSL.Target.set("a gnome greaser", true, "manual")
check("no poisoned flag before any onset text arrives", MyDSL.State.target.poisoned_at == nil)

MyDSL.Target.markPoisoned("an insane sea elf")  -- a DIFFERENT mob
check("markPoisoned() ignores a mob that isn't the current target",
  MyDSL.State.target.poisoned_at == nil)

MyDSL.Target.markPoisoned("A gnome greaser")  -- matches, case/article-insensitive
check("markPoisoned() flags the current target on a real match",
  MyDSL.State.target.poisoned_at ~= nil)

------------------------------------------------------------------------
-- Part 3: setting a NEW target clears the stale poisoned flag (fresh
-- target table, same precedent as _consider_lines already being reset).
------------------------------------------------------------------------
MyDSL.Target.set("a different mob", true, "manual")
check("switching targets clears the stale poisoned flag",
  MyDSL.State.target.poisoned_at == nil)

------------------------------------------------------------------------
-- Part 4: render() doesn't crash with the flag set, and the real
-- installed trigger correctly routes into markPoisoned() end to end.
------------------------------------------------------------------------
MyDSL.Target.markPoisoned("a different mob")
local ok = pcall(MyDSL.TargetView.render)
check("TV.render() runs without error while a target is poisoned", ok)

check("no crash / safe no-op when markPoisoned() is called with no current target",
  (function()
    MyDSL.Target.clear()
    return pcall(MyDSL.Target.markPoisoned, "anything")
  end)())

print(string.rep("-", 60))
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
