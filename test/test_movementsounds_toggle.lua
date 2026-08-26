-- Real gap fix, 2026-08-26, per Steven ("yes add toggle"):
-- MyDSL_MovementSounds.lua's config.enabled was checked at the top of
-- play() but nothing anywhere ever let a player set it false --
-- confirmed zero aliases anywhere in the file
-- (docs/MYDSL_1.0_MODULE_REDESIGN.md #14).
--
-- Run: luajit test/test_movementsounds_toggle.lua

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
dofile("MyDSL_MovementSounds.lua")

check("config.enabled defaults to true", MyDSL.MoveSound.config.enabled == true)

MyDSL.MoveSound.setEnabled(false)
check("setEnabled(false) disables it", MyDSL.MoveSound.config.enabled == false)

MyDSL.MoveSound.setEnabled(true)
check("setEnabled(true) re-enables it", MyDSL.MoveSound.config.enabled == true)

MyDSL.MoveSound.toggle()
check("toggle() flips true -> false", MyDSL.MoveSound.config.enabled == false)
MyDSL.MoveSound.toggle()
check("toggle() flips false -> true", MyDSL.MoveSound.config.enabled == true)

check("setEnabled() coerces any truthy-but-not-true value to a real boolean (not just falsy-checked)",
  (function()
    MyDSL.MoveSound.setEnabled("yes")
    return MyDSL.MoveSound.config.enabled == false
  end)())

local hasOn, hasOff, hasToggle, hasStatus = false, false, false, false
for _, pat in ipairs(registeredAliases) do
  if pat:find("movesound on", 1, true) then hasOn = true end
  if pat:find("movesound off", 1, true) then hasOff = true end
  if pat:find("movesound toggle", 1, true) then hasToggle = true end
  if pat:find("movesound status", 1, true) then hasStatus = true end
end
check("a real 'mydsl movesound on' alias was registered", hasOn)
check("a real 'mydsl movesound off' alias was registered", hasOff)
check("a real 'mydsl movesound toggle' alias was registered", hasToggle)
check("a real 'mydsl movesound status' alias was registered", hasStatus)

-- play() actually honors the flag now that it's reachable.
MyDSL.MoveSound.setEnabled(false)
_G.__playedSounds = {}
MyDSL.MoveSound.play("walk")
check("play() is a no-op while disabled (config.enabled honored end-to-end)",
  #_G.__playedSounds == 0)

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
