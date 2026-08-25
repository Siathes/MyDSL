-- "mydsl layout titles <on|off>" -- docs/TODO.md's "UI: toggleable
-- window titles / minimal borders, to maximize window space" design
-- idea. Only the title-TEXT half is buildable: Mudlet exposes no Lua
-- API to shrink the title bar's actual height (checked before building
-- anything), so this hides/shows title text only via the real
-- setTitle("")/resetTitle() Geyser already provides.
--
-- Run: luajit test/test_windowregistry_titles.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

-- mudlet_mock's table.save()/table.load() are no-op stubs (return true
-- without touching disk) -- this test needs the real on-disk round trip
-- to verify the preference actually survives a reload, so provide a
-- minimal real implementation (flat tables of booleans/numbers/strings
-- only, all this file needs).
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

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local TITLES_FILE = "/tmp/claude_mudlet_home/MyDSL_titles_visible.lua"
os.execute("rm -f " .. TITLES_FILE)
os.execute("rm -f /tmp/claude_mudlet_home/MyDSL_dock_initialized.lua")  -- avoid cross-test interference

dofile("MyDSL_LayoutEngine.lua")
dofile("MyDSL_WindowRegistry.lua")

------------------------------------------------------------------------
-- Part 1: defaults to visible when nothing has been saved yet.
------------------------------------------------------------------------
check("titlesVisible defaults to true with no saved preference",
  MyDSL.Windows.titlesVisible == true)

------------------------------------------------------------------------
-- Part 2: setTitlesVisible(false) applies to every already-created
-- UserWindow, persists to disk, and leaves Container-type windows alone
-- (they have no title bar at all).
------------------------------------------------------------------------
MyDSL.Windows.ensureAll()
MyDSL.Windows.setTitlesVisible(false)

check("hiding titles blanks an existing UserWindow's title",
  _G.__windowTitles.MyDSL_Chat == "")
check("hiding titles does not touch a Container-type window (no title bar to hide)",
  _G.__windowTitles.MyDSL_MoonWeather == nil)
check("the preference was persisted to disk", io.open(TITLES_FILE, "r") ~= nil)

------------------------------------------------------------------------
-- Part 3: setTitlesVisible(true) restores titles via resetTitle().
------------------------------------------------------------------------
MyDSL.Windows.setTitlesVisible(true)
check("showing titles again calls resetTitle(), not just a blank-to-name swap",
  _G.__windowTitles.MyDSL_Chat == "__reset__")

------------------------------------------------------------------------
-- Part 4: a fresh window created AFTER titles were hidden starts
-- blanked immediately -- doesn't need a second toggle to catch up.
------------------------------------------------------------------------
MyDSL.Windows.setTitlesVisible(false)
MyDSL.Windows.registry.MyDSL_Chat.created = false
MyDSL.Windows.registry.MyDSL_Chat.obj = nil
_G.__windowTitles.MyDSL_Chat = nil
MyDSL.Windows.ensure("MyDSL_Chat")
check("a window created while titles are hidden starts with a blank title",
  _G.__windowTitles.MyDSL_Chat == "")

------------------------------------------------------------------------
-- Part 5: the saved preference actually survives a reload (real file
-- read, not just an in-memory flag).
------------------------------------------------------------------------
_G.__windowTitles = {}
package.loaded["mudlet_mock"] = nil
require("mudlet_mock")
dofile("MyDSL_LayoutEngine.lua")
dofile("MyDSL_WindowRegistry.lua")
check("titlesVisible=false survives a reload via the real saved file",
  MyDSL.Windows.titlesVisible == false)

os.execute("rm -f " .. TITLES_FILE)

print(string.rep("-", 60))
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
