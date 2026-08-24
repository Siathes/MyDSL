-- Real ThemeEngine hookup for MyDSL_Chat's tab active/inactive CSS,
-- 2026-08-24 -- previously hardcoded to a fixed green/grey pair
-- regardless of the active MyDSL theme (docs/TODO.md's LOW PRIORITY
-- "ChatWrapper tab active/inactive CSS still hardcoded" item).
--
-- Run: luajit test/test_chat_theme_hookup.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

-- mudlet_mock's default registerAnonymousEventHandler() is a no-op (just
-- returns an id, doesn't store anything) and raiseEvent() only records --
-- neither actually dispatches. Override to really capture/fire handlers
-- by event name, same pattern this project's other event-driven tests use.
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

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

------------------------------------------------------------------------
-- Part 1: without ThemeEngine loaded, falls back to the original
-- hardcoded values -- this file must still work standalone.
------------------------------------------------------------------------
dofile("MyDSL_Chat.lua")
local fallback = MyDSL.Chat._buildTabTheme()
check("falls back to the original hardcoded activeTabFGColor when ThemeEngine isn't loaded",
  fallback.activeTabFGColor == "green")
check("falls back to the original hardcoded inactiveTabFGColor when ThemeEngine isn't loaded",
  fallback.inactiveTabFGColor == "grey")
check("fallback CSS still has the real border-style/border-width shape",
  fallback.activeTabCSS:find("border%-width: 2px") ~= nil)

------------------------------------------------------------------------
-- Part 2: with ThemeEngine loaded, real theme colors are used instead.
------------------------------------------------------------------------
dofile("MyDSL_ThemeEngine.lua")
local themed = MyDSL.Chat._buildTabTheme()
check("with ThemeEngine loaded, activeTabFGColor is no longer the hardcoded fallback",
  themed.activeTabFGColor ~= "green")
check("themed activeTabFGColor uses Geyser's own bracket format, not raw CSS",
  themed.activeTabFGColor:match("^<%d+,%d+,%d+>$") ~= nil)
check("themed CSS strings use real rgba(...) from the active theme, not the hardcoded 'black'/'green'",
  themed.activeTabCSS:find("rgba%(", 1, false) ~= nil and not themed.activeTabCSS:find("black", 1, true))

-- Switching themes must actually change the computed colors -- confirms
-- this reads the LIVE active preset each call, not a cached snapshot.
MyDSL.Theme.setTheme("terminal_purist")
local themed2 = MyDSL.Chat._buildTabTheme()
check("switching the active theme changes the computed tab CSS",
  themed2.activeTabCSS ~= themed.activeTabCSS)

------------------------------------------------------------------------
-- Part 3: the live "MyDSL.theme.changed" handler actually restyles an
-- already-created chat window, not just a future one.
------------------------------------------------------------------------
local calls = { adjustTabBackgrounds = 0, adjustTabNames = 0 }
MyDSL.Chat.emco = {
  activeTabCSS = "stale", inactiveTabCSS = "stale",
  activeTabFGColor = "stale", inactiveTabFGColor = "stale",
  adjustTabBackgrounds = function(self) calls.adjustTabBackgrounds = calls.adjustTabBackgrounds + 1 end,
  adjustTabNames = function(self) calls.adjustTabNames = calls.adjustTabNames + 1 end,
}
raiseEvent("MyDSL.theme.changed")
check("theme-changed handler updates the live emco object's activeTabCSS",
  MyDSL.Chat.emco.activeTabCSS ~= "stale")
check("theme-changed handler calls adjustTabBackgrounds() to actually re-render",
  calls.adjustTabBackgrounds == 1)
check("theme-changed handler calls adjustTabNames() to actually re-render",
  calls.adjustTabNames == 1)

-- Must not error when no chat window has been created yet.
MyDSL.Chat.emco = nil
local ok = pcall(raiseEvent, "MyDSL.theme.changed")
check("theme-changed handler is a safe no-op when no emco object exists yet", ok)

print(string.rep("-", 60))
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
