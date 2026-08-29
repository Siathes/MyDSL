-- Coverage for MyDSL_Login.lua -- the secure auto-login replacement built
-- 2026-08-26. Checks the properties that actually matter for a
-- credential-handling module: unconfigured is a silent no-op, configured
-- sends the right values with echo suppressed, the value never leaks onto
-- any MyDSL.* table, the send-once guard holds, and it resets on
-- sysConnectionEvent.
--
-- Extended 2026-08-29 for the password/character-autofill split (real
-- usability bug found via corpus review: "Player name:" and "Password:"
-- aren't a matched pair, and a single hardcoded character name is often
-- wrong across sessions -- see docs/CHANGELOG.md). Character autofill now
-- defaults OFF independent of password autofill, and the old `name`
-- credentials-file key still loads correctly as `character` (backward
-- compat for a file already on disk from before the rename).
--
-- Run: luajit test/test_login.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

-- Same override technique as test_datalayer_combat_lifecycle.lua /
-- test_identify_source_scoping.lua: the shared mock's
-- registerAnonymousEventHandler is a no-op that doesn't store the
-- function, so override it here to actually record handlers.
local eventHandlers = {}
function _G.registerAnonymousEventHandler(event, fn)
  eventHandlers[event] = eventHandlers[event] or {}
  table.insert(eventHandlers[event], fn)
  return #eventHandlers[event]
end
local function fireEvent(event, ...)
  for _, fn in ipairs(eventHandlers[event] or {}) do fn(event, ...) end
end

-- Capture (cmd, echoFlag) pairs instead of the shared mock's cmd-only log,
-- so the "echo suppressed" property is actually checkable.
local sent = {}
function _G.send(cmd, echoFlag) sent[#sent + 1] = { cmd = cmd, echo = echoFlag } end

-- Fire a trigger by matching pattern name registered against a fixed line,
-- mirroring how tempRegexTrigger's mock stores {pattern, func}.
local function fireTrigger(matchLine)
  _G.line = matchLine
  for _, t in pairs(_G.__triggers) do
    local pat = (t.pattern:gsub("^%^", ""))  -- parens: keep only 1st gsub return
    if matchLine:find(pat) then t.func() end
  end
end

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

-- ---- Case 1: unconfigured (no credentials file) -> silent no-op -----------

MyDSL = nil
_G.__triggers = {}
sent = {}
dofile("MyDSL_Login.lua")

check("unconfigured: reports not configured", MyDSL.Login._configured == false)
fireTrigger("Player name:")
fireTrigger("Password:")
check("unconfigured: sends nothing on Player name:/Password:", #sent == 0)

-- ---- Case 2: configured, default state -> password autofills, character doesn't --

local credPath = getMudletHomeDir() .. "/MyDSL_login_credentials.lua"
os.execute("mkdir -p " .. getMudletHomeDir())
local f = io.open(credPath, "w")
f:write('return { name = "TestChar", password = "TestPass123" }\n')  -- old `name` key -- backward-compat case
f:close()

MyDSL = nil
_G.__triggers = {}
sent = {}
eventHandlers = {}
dofile("MyDSL_Login.lua")

check("configured: reports configured", MyDSL.Login._configured == true)
check("character autofill defaults OFF", MyDSL.Login.characterEnabled == false)
check("password autofill defaults ON", MyDSL.Login.enabled == true)

fireTrigger("Player name:")
check("character autofill OFF by default: 'Player name:' sends nothing", #sent == 0)

fireTrigger("Password:")
check("password autofill ON by default: sent exactly one command after password prompt", #sent == 1)
check("configured: sent the right password", sent[1] and sent[1].cmd == "TestPass123")
check("configured: password send had echo suppressed", sent[1] and sent[1].echo == false)

-- ---- Case 3: turning character autofill on sends the (backward-compat) name --

MyDSL.Login.characterEnabled = true
fireTrigger("Player name:")
check("character autofill ON: sends the old 'name' key's value as the character",
  sent[2] and sent[2].cmd == "TestChar")
check("character send had echo suppressed", sent[2] and sent[2].echo == false)

-- ---- Case 4: send-once-per-prompt guard ------------------------------------

fireTrigger("Player name:")
fireTrigger("Password:")
check("guard: repeated prompts within one connection don't resend", #sent == 2)

-- ---- Case 5: sysConnectionEvent resets the guard ---------------------------

fireEvent("sysConnectionEvent")
fireTrigger("Player name:")
fireTrigger("Password:")
check("reconnect: guard reset allows exactly one more send each", #sent == 4)
check("reconnect: character resent correctly", sent[3] and sent[3].cmd == "TestChar")
check("reconnect: password resent correctly", sent[4] and sent[4].cmd == "TestPass123")

-- ---- Case 6: each toggle only controls its own autofill --------------------

MyDSL.Login.enabled = false
sent = {}
fireEvent("sysConnectionEvent")
fireTrigger("Player name:")
fireTrigger("Password:")
check("password toggle off: no password send, character still sends", #sent == 1 and sent[1].cmd == "TestChar")

MyDSL.Login.characterEnabled = false
MyDSL.Login.enabled = true
sent = {}
fireEvent("sysConnectionEvent")
fireTrigger("Player name:")
fireTrigger("Password:")
check("character toggle off: no character send, password still sends",
  #sent == 1 and sent[1].cmd == "TestPass123")
check("toggle off: still reports configured (file untouched)", MyDSL.Login._configured == true)

-- ---- Case 7: credential value never lands on any MyDSL.* table ------------

local function scanForSecret(t, seen, found, path)
  seen = seen or {}
  if type(t) ~= "table" or seen[t] then return found end
  seen[t] = true
  for k, v in pairs(t) do
    if v == "TestPass123" then
      found = (path or "MyDSL") .. "." .. tostring(k)
    elseif type(v) == "table" then
      found = scanForSecret(v, seen, found, (path or "MyDSL") .. "." .. tostring(k))
    end
  end
  return found
end
local leak = scanForSecret(MyDSL)
check("no leak: password value not stored anywhere under MyDSL.*", leak == nil)

os.remove(credPath)

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
