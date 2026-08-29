-- Real gap fix, 2026-08-29, per Steven ("Local is not gagged by default,
-- all other channels are gagged by default. Local is yells/tells/
-- whispers and such"): whisper was the one Local pattern still gagged
-- by default (a deliberate 2026-07-11 choice at the time, superseded by
-- this note explicitly naming it as part of the not-gagged group).
-- Locks in the full default gag-state matrix so a future edit can't
-- silently drift one pattern out of sync with its siblings again.
--
-- Run: luajit test/test_chattriggers_default_gag_state.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

MyDSL = MyDSL or {}
local appendedTabs = {}
MyDSL.Chat = { emco = { append = function(self, tab) appendedTabs[#appendedTabs + 1] = tab end } }

local deleteLineCalls = 0
_G.deleteLine = function() deleteLineCalls = deleteLineCalls + 1 end

dofile("MyDSL_ChatTriggers.lua")
local CT = MyDSL.ChatTriggers

-- Fire every registered trigger and record whether deleteLine() (i.e.
-- "gagged by default") fired for it, keyed by the tab it routed to.
-- Several patterns share a tab (e.g. 4 Local patterns, 9 OOC patterns);
-- track a per-tab list so every pattern's own default is checked, not
-- just the first one that happens to route to that tab.
local gaggedByTab = {}
for _, id in ipairs(CT._triggers) do
  appendedTabs, deleteLineCalls = {}, 0
  _G.__triggers[id].func()
  local tab = appendedTabs[#appendedTabs]
  if tab then
    gaggedByTab[tab] = gaggedByTab[tab] or {}
    table.insert(gaggedByTab[tab], deleteLineCalls > 0)
  end
end

local function allSame(list, expected)
  if #list == 0 then return false end
  for _, v in ipairs(list) do
    if v ~= expected then return false end
  end
  return true
end

check("Local: every pattern (say/whisper/yell/shout) defaults to NOT gagged",
  allSame(gaggedByTab["Local"], false))
check("Tells: every pattern defaults to NOT gagged (Steven's own \"tells\" listing)",
  allSame(gaggedByTab["Tells"], false))
check("Group: every pattern defaults to gagged", allSame(gaggedByTab["Group"], true))
check("OOC: every pattern defaults to gagged", allSame(gaggedByTab["OOC"], true))
check("City: every pattern defaults to gagged", allSame(gaggedByTab["City"], true))

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
