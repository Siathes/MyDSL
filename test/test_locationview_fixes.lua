-- Structural test for two 2026-07-19 LocationView fixes found during a
-- full review (prompted by Steven: "location window is all sorts of not
-- working ... do a full check"):
--   1. M.renderMode was hardcoded to "cover" regardless of which fit mode
--      actually rendered -- `mydsl location status` always lied about it.
--   2. M.onThemeChanged() passed a bare nil caption to render(), blanking
--      the caption label on every theme switch since nothing stored the
--      last real caption text to fall back to.
--
-- Run: luajit test/test_locationview_fixes.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

-- A real file on disk so M.render()'s exists() check passes.
local tmpPath = "/tmp/claude_mudlet_home_test_room.png"
local f = io.open(tmpPath, "w"); f:write("not a real png, just needs to exist"); f:close()

dofile("MyDSL_LocationView.lua")
local M = MyDSL.Location

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

M.config.fit = "stretch"
local ok = M.render(tmpPath, "Some Room\nN S E W", "test", "Some Room")
check("render() succeeds with a real path", ok == true)
check("renderMode reflects the actual fit used (stretch), not hardcoded 'cover'",
  M.renderMode == "stretch")
check("currentCaption is stored after render()", M.currentCaption == "Some Room\nN S E W")

M.onThemeChanged()
check("onThemeChanged() reuses the stored caption instead of blanking it",
  M.currentCaption == "Some Room\nN S E W")

M.clear("cleared")
check("clear() resets currentCaption too", M.currentCaption == nil)

os.remove(tmpPath)

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
