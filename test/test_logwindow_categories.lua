-- Structural test for the 2026-08-24 MyDSL.LogConfig.disabled_categories
-- fix, per Steven's still-open ask ("stop logging anything except
-- combat/main window/chat and history... others dont seem needed and
-- seem to be useless").
--
-- Confirmed real gap: `target`/`scan`/`bloodbath` were dead entries in
-- disabled_categories (no current code calls MyDSL.logWindow() with any
-- of those three names -- leftovers from the old MyDSL.Route.scan()/
-- combat()/group()/righthere() shorthands removed 2026-08-23), while
-- `focus` (MyDSL_TargetView.lua's real, active category) was MISSING
-- entirely -- so Focus/Target updates were logging by default the whole
-- time, contradicting Steven's stated wish, because the category was
-- renamed from `target` to `focus` at some point without this list
-- being updated to match.
--
-- Run: luajit test/test_logwindow_categories.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

dofile("MyDSL_DataLayer.lua")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

------------------------------------------------------------------------
-- 1. The stale, dead entries are gone (no real call site ever produced
-- these names, confirmed via grep across every MyDSL_*.lua file).
------------------------------------------------------------------------
check("'target' is no longer a disabled-category entry (dead, no real caller)",
  MyDSL.LogConfig.disabled_categories.target == nil)
check("'scan' is no longer a disabled-category entry (dead, no real caller)",
  MyDSL.LogConfig.disabled_categories.scan == nil)
check("'bloodbath' is no longer a disabled-category entry (dead, chat uses its own logging)",
  MyDSL.LogConfig.disabled_categories.bloodbath == nil)

------------------------------------------------------------------------
-- 2. The real, previously-missing entry is now present.
------------------------------------------------------------------------
check("'focus' (MyDSL_TargetView.lua's real category) is now disabled by default",
  MyDSL.LogConfig.disabled_categories.focus == true)

------------------------------------------------------------------------
-- 3. Steven's stated keep-list stays enabled.
------------------------------------------------------------------------
check("'combat' stays enabled by default", MyDSL.LogConfig.disabled_categories.combat == nil)
check("'history' stays enabled by default", MyDSL.LogConfig.disabled_categories.history == nil)

------------------------------------------------------------------------
-- 4. The actual behavior, not just the config table: a disabled
-- category writes nothing at all; an enabled one really does.
------------------------------------------------------------------------
local tmpHome = getMudletHomeDir()

MyDSL.logWindow("focus", "should never be written\n")
local focusPath = tmpHome .. "/MyDSL/logs/focus/Unknown/" .. os.date("%Y-%m-%d") .. ".log"
local ff = io.open(focusPath, "r")
check("logWindow() on a disabled category writes no file at all", ff == nil)
if ff then ff:close() end

MyDSL.logWindow("combat", "a real combat line\n")
local combatPath = tmpHome .. "/MyDSL/logs/combat/Unknown/" .. os.date("%Y-%m-%d") .. ".log"
local cf = io.open(combatPath, "r")
check("logWindow() on an enabled category really writes a file", cf ~= nil)
if cf then
  local content = cf:read("*a")
  cf:close()
  check("the written file contains the real logged line", content:find("a real combat line", 1, true) ~= nil)
end

os.execute("rm -rf " .. tmpHome .. "/MyDSL/logs")

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
