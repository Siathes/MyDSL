-- Real gap fix, 2026-08-26, per Steven ("make it toggle just in case"):
-- MyDSL_CharacterAssist.lua's rearm/standup fired unconditionally on
-- disarm/knockdown, by original 2026-07-07 pre-1.0 design, with no way
-- to turn the automatic (not manual) half off
-- (docs/MYDSL_1.0_MODULE_REDESIGN.md #27). CA.config.auto_recover now
-- gates the 8 passive disarm/knockdown triggers; the always-available
-- manual "rearm" alias is deliberately untouched by this flag.
--
-- Run: luajit test/test_characterassist_auto_recover_toggle.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

MyDSL = MyDSL or {}
MyDSL.State = { equipment = { slots = {} } }
dofile("MyDSL_CharacterAssist.lua")
local CA = MyDSL.CharacterAssist

check("config.auto_recover defaults to true (unchanged behavior)", CA.config.auto_recover == true)

-- Spy on rearm/rearmShield/standup rather than exercising their full
-- equipment logic -- this test is about the toggle gate, not rearm itself.
local calls = {}
CA.rearm = function(arg) calls[#calls + 1] = "rearm:" .. tostring(arg) end
CA.rearmShield = function(arg) calls[#calls + 1] = "rearmShield:" .. tostring(arg) end
CA.standup = function() calls[#calls + 1] = "standup" end

local function fire(key) _G.__triggers[CA._triggers[key]].func() end

check("disarm1 trigger exists", CA._triggers.disarm1 ~= nil)
check("knockdown trigger exists", CA._triggers.knockdown ~= nil)

fire("disarm1")
check("auto_recover=true: disarm trigger calls rearm", calls[#calls] == "rearm:combat")
fire("shieldDisarm1")
check("auto_recover=true: shield-disarm trigger calls rearmShield", calls[#calls] == "rearmShield:combat")
fire("knockdown")
check("auto_recover=true: knockdown trigger calls standup", calls[#calls] == "standup")
fire("knockdownBump")
check("auto_recover=true: the second knockdown form also calls standup", calls[#calls] == "standup")

CA.setAutoRecover(false)
check("setAutoRecover(false) updates the flag", CA.config.auto_recover == false)
calls = {}
fire("disarm1")
fire("disarm2")
fire("disarm3")
fire("shieldDisarm1")
fire("shieldDisarm2")
fire("shieldDisarm3")
fire("knockdown")
fire("knockdownBump")
check("auto_recover=false: NONE of the 8 passive triggers call rearm/rearmShield/standup", #calls == 0)

CA.toggleAutoRecover()
check("toggleAutoRecover() flips false -> true", CA.config.auto_recover == true)
fire("knockdown")
check("re-enabled: knockdown trigger calls standup again", #calls == 1 and calls[1] == "standup")

-- The manual "rearm" alias must stay reachable regardless of the flag --
-- it's an explicit player action, not the automatic behavior being gated.
CA.setAutoRecover(false)
local manualRearmAlias
for _, a in pairs(_G.__aliases) do
  if a.pattern == [[^rearm$]] then manualRearmAlias = a end
end
check("the manual '^rearm$' alias still exists while auto_recover is off", manualRearmAlias ~= nil)
calls = {}
if manualRearmAlias then manualRearmAlias.func() end
check("the manual rearm alias still calls CA.rearm(\"full\") even with auto_recover off",
  calls[#calls] == "rearm:full")

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
