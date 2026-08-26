-- Real gap fix, 2026-08-26, per Steven ("there should be a gag and show
-- for each channel and a fallback show if anything breaks or turns
-- off"): MyDSL_ChatTriggers.lua had zero toggle for its 20 always-active
-- chat-routing triggers (docs/MYDSL_1.0_MODULE_REDESIGN.md #17) -- hiding
-- the Chat window didn't stop it gagging the main console. Each of the
-- 5 channels (Tells/Group/OOC/City/Local) now has its own gag/show flag;
-- turning one off leaves that channel's lines on the main console
-- untouched, same "move text, don't replace it" fallback the existing
-- MyDSL.Chat.emco-not-ready guard already used for an accidental gap.
--
-- Run: luajit test/test_chattriggers_channel_toggle.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local registeredAliases = {}
local realTempAlias = _G.tempAlias
_G.tempAlias = function(pattern, code)
  registeredAliases[#registeredAliases + 1] = pattern
  return realTempAlias(pattern, code)
end

MyDSL = MyDSL or {}
local appendedTabs = {}
MyDSL.Chat = { emco = { append = function(self, tab) appendedTabs[#appendedTabs + 1] = tab end } }

local deleteLineCalls = 0
_G.deleteLine = function() deleteLineCalls = deleteLineCalls + 1 end

dofile("MyDSL_ChatTriggers.lua")
local CT = MyDSL.ChatTriggers

check("config.channels defaults every real channel to true (gagged, unchanged behavior)",
  CT.config.channels.Tells == true and CT.config.channels.Group == true
  and CT.config.channels.OOC == true and CT.config.channels.City == true
  and CT.config.channels.Local == true)

-- _triggers[1] is the first route("Tells", ...) call in the file --
-- confirm that assumption directly before relying on it, so a future
-- reordering fails loudly here instead of silently testing the wrong
-- trigger.
local tellsId = CT._triggers[1]
appendedTabs, deleteLineCalls = {}, 0
_G.__triggers[tellsId].func()
check("_triggers[1] really is a Tells route (sanity check for the rest of this test)",
  appendedTabs[#appendedTabs] == "Tells")

-- Tells' own route() calls pass gag=false (Steven wants tells to echo
-- too), so deleteLineCalls staying 0 here is expected either way -- use
-- Group instead (route("Group", ...) has no gag=false override) for the
-- gag-vs-show distinction.
local groupId = CT._triggers[3]
appendedTabs, deleteLineCalls = {}, 0
_G.__triggers[groupId].func()
check("_triggers[3] really is a Group route (sanity check)", appendedTabs[#appendedTabs] == "Group")
check("Group enabled (default): the line IS routed to its tab", #appendedTabs == 1)
check("Group enabled (default): the line IS gagged from the main console", deleteLineCalls == 1)

CT.setChannel("group", false)
check("setChannel() is case-insensitive and normalizes to the real key", CT.config.channels.Group == false)

appendedTabs, deleteLineCalls = {}, 0
_G.__triggers[groupId].func()
check("Group disabled: the line is NOT routed to its tab", #appendedTabs == 0)
check("Group disabled: the line is NOT gagged either -- stays on the main console (the fallback show)",
  deleteLineCalls == 0)

CT.setChannel("Group", true)
appendedTabs, deleteLineCalls = {}, 0
_G.__triggers[groupId].func()
check("re-enabling Group restores routing+gagging", #appendedTabs == 1 and deleteLineCalls == 1)

check("setChannel() on an unknown channel name is a safe no-op, not a crash",
  (function()
    local ok = pcall(CT.setChannel, "NotARealChannel", false)
    return ok and CT.config.channels.NotARealChannel == nil
  end)())

check("status() runs without error", pcall(CT.status))

local hasGag, hasShow, hasStatus = false, false, false
for _, pat in ipairs(registeredAliases) do
  if pat:find("channel gag", 1, true) then hasGag = true end
  if pat:find("channel show", 1, true) then hasShow = true end
  if pat:find("channel status", 1, true) then hasStatus = true end
end
check("a real 'mydsl channel gag <name>' alias was registered", hasGag)
check("a real 'mydsl channel show <name>' alias was registered", hasShow)
check("a real 'mydsl channel status' alias was registered", hasStatus)

-- The pre-existing "MyDSL.Chat.emco not ready" fallback must still work
-- unchanged -- this toggle must not have broken that other safety net.
CT.setChannel("Local", true)
MyDSL.Chat.emco = nil
appendedTabs, deleteLineCalls = {}, 0
local localId = CT._triggers[10]
_G.__triggers[localId].func()
check("pre-existing fallback intact: with emco nil, the line is not gagged either (still falls back to showing)",
  deleteLineCalls == 0)

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
