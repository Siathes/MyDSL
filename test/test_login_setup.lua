-- Coverage for the 2026-08-30 first-run setup popup added to
-- MyDSL_Login.lua, per Steven ("add a way for the user to add the login
-- information like a pop up UI for the first setup (i dont want users to
-- have to edit code for basic scripts)"). Checks the parts that matter:
-- "mydsl login setup <character> <password>" actually writes a working
-- credentials file (and MyDSL_Login.lua picks it up immediately, no
-- reload needed), the popup auto-shows exactly once when unconfigured and
-- stops after either setup or an explicit dismissal, and none of this
-- ever echoes the password value anywhere.
--
-- Run: luajit test/test_login_setup.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local echoed = {}
local origCecho = _G.cecho
_G.cecho = function(msg) echoed[#echoed + 1] = tostring(msg); if origCecho then origCecho(msg) end end
local origEcho = _G.echo
_G.echo = function(msg) echoed[#echoed + 1] = tostring(msg); if origEcho then origEcho(msg) end end

-- Clean slate: no credentials/settings file left over from a previous run.
local credPath = getMudletHomeDir() .. "/MyDSL_login_credentials.lua"
local setPath  = getMudletHomeDir() .. "/MyDSL_login_settings.lua"
os.remove(credPath)
os.remove(setPath)

dofile("MyDSL_LayoutEngine.lua")
dofile("MyDSL_WindowRegistry.lua")
dofile("MyDSL_Login.lua")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

check("starts unconfigured with a clean slate", MyDSL.Login._configured == false)

-- ---- the actual "form submit" ----------------------------------------------
echoed = {}
local ok = MyDSL.Login.setup("Kien", "hunter2")
check("setup() reports success", ok == true)
check("setup() flips _configured to true immediately, no reload needed",
  MyDSL.Login._configured == true)
check("setup() dismisses the popup (marks it dismissed)", MyDSL.Login._setupDismissed == true)

local passwordLeaked = false
for _, msg in ipairs(echoed) do
  if msg:find("hunter2", 1, true) then passwordLeaked = true end
end
check("setup()'s own confirmation message never echoes the password value", not passwordLeaked)

-- ---- the written file is actually usable ------------------------------------
local chunk = loadfile(credPath)
check("credentials file was actually written", chunk ~= nil)
local result = chunk and chunk()
check("written file round-trips the character name", result and result.character == "Kien")
check("written file round-trips the password", result and result.password == "hunter2")

-- ---- bad input is rejected, not silently written ----------------------------
os.remove(credPath)
MyDSL.Login._configured = false
local ok2 = MyDSL.Login.setup("", "somepassword")
check("setup() rejects an empty character name", ok2 == false)
check("no file written for a rejected setup call", loadfile(credPath) == nil)

-- ---- auto-show / dismissal persistence --------------------------------------
os.remove(credPath)
os.remove(setPath)
MyDSL.Login._configured = false
MyDSL.Login._setupDismissed = false
MyDSL.Login.dismissSetup()
check("dismissSetup() persists across a reload", (function()
  local c = loadfile(setPath)
  local r = c and c()
  return r and r.setupDismissed == true
end)())

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
