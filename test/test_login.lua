-- Coverage for MyDSL_Login.lua -- rebuilt 2026-08-30 to actually navigate
-- the whole login sequence (not just autofill a value someone already
-- saved) and to capture account name/password from what's typed the first
-- time, no setup command needed. See the file's own header for the full
-- design writeup and the real corpus patterns this is built against.
--
-- Drives the module's trigger callbacks DIRECTLY (via _G.__triggers[id].func,
-- looked up by the ID MyDSL.Login._triggers.<name> holds) rather than
-- simulating text matching -- mudlet_mock.lua's tempRegexTrigger mock does
-- plain Lua string.find, not real PCRE, and several of this module's real
-- patterns use PCRE escapes (\(, \), \?) that would never match under Lua
-- pattern semantics. Testing the callbacks directly is both more robust and
-- exercises exactly the logic that matters (stage transitions, capture,
-- autofill) without depending on the mock's matching limitations.
--
-- Run: luajit test/test_login.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local eventHandlers = {}
function _G.registerAnonymousEventHandler(event, fn)
  eventHandlers[event] = eventHandlers[event] or {}
  table.insert(eventHandlers[event], fn)
  return #eventHandlers[event]
end
local function fireEvent(event, ...)
  for _, fn in ipairs(eventHandlers[event] or {}) do fn(event, ...) end
end

local sent = {}
function _G.send(cmd, echoFlag) sent[#sent + 1] = { cmd = cmd, echo = echoFlag } end

local deleteLineCalls = 0
function _G.deleteLine() deleteLineCalls = deleteLineCalls + 1 end

-- Invokes a registered trigger's callback directly by MyDSL.Login._triggers
-- key. capture, if given, is set as matches[2] before calling (mirrors a
-- real single-capture-group PCRE match: matches[1]=whole line, matches[2]=
-- the captured group).
local function fire(triggerKey, capture)
  local id = MyDSL.Login._triggers[triggerKey]
  local t = _G.__triggers[id]
  assert(t, "no such trigger registered: " .. tostring(triggerKey))
  if capture ~= nil then _G.matches = { capture, capture } else _G.matches = {} end
  t.func()
end

local credPath = getMudletHomeDir() .. "/MyDSL_login_credentials.lua"
local function removeCredFile() os.remove(credPath) end

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

------------------------------------------------------------------------
-- Scenario A: fresh/unconfigured -- full navigation + first-run capture
------------------------------------------------------------------------
removeCredFile()
MyDSL = nil
_G.__triggers = {}
sent = {}
deleteLineCalls = 0
eventHandlers = {}
dofile("MyDSL_Login.lua")

check("unconfigured: reports not configured", MyDSL.Login._configured == false)
check("starts at stage 'color'", MyDSL.Login._stage == "color")

fire("color")
check("color prompt: sends 'y' with echo suppressed", sent[1] and sent[1].cmd == "y" and sent[1].echo == false)
check("color prompt: advances to 'banner'", MyDSL.Login._stage == "banner")

fire("banner")
check("continue prompt: sends blank enter with echo suppressed", sent[2] and sent[2].cmd == "" and sent[2].echo == false)
check("continue prompt: advances to 'mainmenu'", MyDSL.Login._stage == "mainmenu")

fire("selection")
check("main menu: sends 'm' (Master Account Login)", sent[3] and sent[3].cmd == "m" and sent[3].echo == false)
check("main menu: advances to 'acctname'", MyDSL.Login._stage == "acctname")

fire("acctname_prompt")
check("account prompt, no saved account: sends nothing (arms capture instead)", #sent == 3)
check("account prompt: stage stays 'acctname' until actually captured", MyDSL.Login._stage == "acctname")

fire("acctname_capture", "vzon")
check("account capture: still sends nothing (just watches, doesn't inject)", #sent == 3)
check("account capture: advances to 'password'", MyDSL.Login._stage == "password")

fire("password")
check("password prompt, no saved password: sends nothing (arms capture instead)", #sent == 3)

fire("password_capture", "Secret123")
check("password capture: still sends nothing", #sent == 3)
check("password capture: deletes the line it was captured from", deleteLineCalls == 1)
check("password capture: advances to 'mastermenu'", MyDSL.Login._stage == "mastermenu")
check("password capture: reports configured now that both fields are saved", MyDSL.Login._configured == true)

fire("selection")
check("master menu: sends 'v' (View Characters)", sent[4] and sent[4].cmd == "v" and sent[4].echo == false)
check("master menu: advances to 'done'", MyDSL.Login._stage == "done")

do
  local chunk = loadfile(credPath)
  local ok, result = pcall(chunk)
  check("captured credentials file round-trips the account", ok and result.account == "vzon")
  check("captured credentials file round-trips the password", ok and result.password == "Secret123")
end

do
  local leaked = false
  for _, s in ipairs(sent) do if s.cmd == "vzon" or s.cmd == "Secret123" then leaked = true end end
  check("captured values were never themselves sent to the game (only watched)", not leaked)
end

------------------------------------------------------------------------
-- Scenario B: already configured -- pure navigation + autofill, no capture
------------------------------------------------------------------------
do
  local f = io.open(credPath, "w")
  f:write('return { account = "vzon", character = "TestChar", password = "TestPass123" }\n')
  f:close()
end

MyDSL = nil
_G.__triggers = {}
sent = {}
deleteLineCalls = 0
eventHandlers = {}
dofile("MyDSL_Login.lua")

check("configured: reports configured", MyDSL.Login._configured == true)
check("character autofill defaults OFF", MyDSL.Login.characterEnabled == false)
check("login autofill defaults ON", MyDSL.Login.enabled == true)

fire("color"); fire("banner"); fire("selection")  -- sent[1]=y, sent[2]="", sent[3]=m
fire("acctname_prompt")
check("configured: account prompt autofills from file, no capture needed",
  sent[4] and sent[4].cmd == "vzon" and sent[4].echo == false)
check("configured: account autofill advances straight to 'password'", MyDSL.Login._stage == "password")

fire("password")
check("configured: password prompt autofills from file", sent[5] and sent[5].cmd == "TestPass123" and sent[5].echo == false)
check("configured: no line deletion needed (nothing was typed to capture)", deleteLineCalls == 0)

fire("selection")  -- sent[6]=v
fire("character")  -- characterEnabled still false here
check("character autofill OFF by default: 'Player name:' sends nothing", #sent == 6)

MyDSL.Login.characterEnabled = true
fire("character")
check("character autofill ON: sends the saved character name", sent[7] and sent[7].cmd == "TestChar" and sent[7].echo == false)

------------------------------------------------------------------------
-- Scenario C: enabled=false disables the whole sequence, not just autofill
------------------------------------------------------------------------
MyDSL.Login.enabled = false
fireEvent("sysConnectionEvent")
check("sysConnectionEvent resets stage back to 'color'", MyDSL.Login._stage == "color")
sent = {}
fire("color")
check("master toggle off: color prompt sends nothing", #sent == 0)
check("master toggle off: stage does not advance", MyDSL.Login._stage == "color")
MyDSL.Login.enabled = true

------------------------------------------------------------------------
-- Scenario D: 'mydsl login forget' clears a bad capture
------------------------------------------------------------------------
MyDSL.Login._forget()
check("forget: reports not configured", MyDSL.Login._configured == false)
check("forget: credentials file actually removed", loadfile(credPath) == nil)

------------------------------------------------------------------------
-- Scenario E: credential values never land on any MyDSL.* table
------------------------------------------------------------------------
local function scanForSecret(t, seen, found, path)
  seen = seen or {}
  if type(t) ~= "table" or seen[t] then return found end
  seen[t] = true
  for k, v in pairs(t) do
    if v == "TestPass123" or v == "Secret123" then
      found = (path or "MyDSL") .. "." .. tostring(k)
    elseif type(v) == "table" then
      found = scanForSecret(v, seen, found, (path or "MyDSL") .. "." .. tostring(k))
    end
  end
  return found
end
local leak = scanForSecret(MyDSL)
check("no leak: password values not stored anywhere under MyDSL.*", leak == nil)

removeCredFile()

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
