-- Real bug found 2026-08-26 (command-parity sweep): M.config.font
-- already existed and was used to size the caption text, but no
-- command ever let a player actually change it -- the one window
-- missing a font command every other window already has.
--
-- Run: luajit test/test_locationview_font.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

dofile("MyDSL_LocationView.lua")
local M = MyDSL.Location

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

check("M.setFont exists", type(M.setFont) == "function")

M.setFont(11)
check("M.setFont(11) updates M.config.font", M.config.font == 11)

M.setFont("not a number")
check("M.setFont() rejects a non-numeric size, leaves the value unchanged",
  M.config.font == 11)

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
