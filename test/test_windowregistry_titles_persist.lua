-- Shared title-text persistence -- added 2026-08-26 (command-parity
-- sweep), same shape as MyDSL.Windows.getFontSize()/setFontSize() but
-- for MyDSL_History/MyDSL_PlayersNear, the two windows with no settings
-- file of their own to add title customization to.
--
-- Run: luajit test/test_windowregistry_titles_persist.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

-- Real on-disk round trip, same technique as test_windowregistry_titles.lua
-- -- mudlet_mock's table.save()/table.load() are no-op stubs.
local function serialize(v)
  if type(v) == "string" then return string.format("%q", v) end
  return tostring(v)
end
function table.save(path, tbl)
  local f = io.open(path, "w")
  if not f then return false end
  f:write("return {\n")
  for k, v in pairs(tbl) do
    f:write(string.format("  [%q] = %s,\n", k, serialize(v)))
  end
  f:write("}\n")
  f:close()
  return true
end
function table.load(path, target)
  local chunk = loadfile(path)
  if not chunk then return false end
  local loaded = chunk()
  for k, v in pairs(loaded) do target[k] = v end
  return true
end

-- Real disk I/O below -- clean up any stale file from a previous run of
-- this exact test before touching anything, same convention as
-- test_login.lua's own real-credentials-file cleanup.
local TITLE_FILE_PATH = "/tmp/claude_mudlet_home/MyDSL_windowtitles.lua"
os.remove(TITLE_FILE_PATH)

MyDSL = MyDSL or {}
MyDSL.Layout = { get = function() return nil end }
dofile("MyDSL_ThemeEngine.lua")
dofile("MyDSL_WindowRegistry.lua")

check("getTitle() with no saved value returns the default",
  MyDSL.Windows.getTitle("MyDSL_History", "History") == "History")

MyDSL.Windows.setTitle("MyDSL_History", "Game Log")
check("setTitle() updates the in-memory value immediately",
  MyDSL.Windows.getTitle("MyDSL_History", "History") == "Game Log")

-- Simulate a fresh reload: clear in-memory state, reload from disk.
MyDSL.Windows.titles = {}
MyDSL.Windows.loadTitles()
check("a saved title survives a reload (real disk round trip)",
  MyDSL.Windows.getTitle("MyDSL_History", "History") == "Game Log")
check("a window with no saved title still falls back to its default",
  MyDSL.Windows.getTitle("MyDSL_PlayersNear", "Players Near") == "Players Near")

os.remove(TITLE_FILE_PATH)

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
