-- Regression test for MyDSL_AmbientBackground.lua, added 2026-08-30.
-- Focuses on the pure gradient math (AB.computeColor) and the base-color
-- snapshot/restore guards, since those are the genuinely new logic --
-- the module reuses MyDSL_MoonWeather's already-tested clock/weather
-- accessors rather than re-deriving either.
--
-- Run: luajit test/test_ambient_background.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

-- Minimal stubs this module needs beyond what mudlet_mock.lua provides.
local bgCalls = {}
_G.setBackgroundColor = function(name, r, g, b, a)
  bgCalls[#bgCalls + 1] = { name = name, r = r, g = g, b = b, a = a }
  return true
end
local fakeRealBg = { 12, 12, 14 }
_G.getBackgroundColor = function(name) return fakeRealBg[1], fakeRealBg[2], fakeRealBg[3], 255 end

-- Stand in for MyDSL_MoonWeather so the module's own event-driven apply()
-- path is exercisable without loading that whole file too.
MyDSL = MyDSL or {}
MyDSL.MoonWeather = {
  currentGameMinutes = function() return 0 end,
  weatherCategory = function() return "Clear" end,
}

dofile("MyDSL_AmbientBackground.lua")
local AB = MyDSL.Ambient

------------------------------------------------------------------------
-- computeColor() -- pure gradient math
------------------------------------------------------------------------
local base = { 10, 10, 10 }

local midnight = AB.computeColor(0, "Clear", base)
check("midnight blends strongly toward black (near base*0.1, not base itself)",
  midnight[1] <= 3 and midnight[2] <= 3 and midnight[3] <= 3)

local noon = AB.computeColor(720, "Clear", base)
check("noon is noticeably brighter than midnight but still far from the raw weather color (subtle, not garish)",
  noon[1] > midnight[1] and noon[1] < 255 and noon[1] < 100)

local dawn = AB.computeColor(360, "Clear", base)
local dusk = AB.computeColor(1080, "Clear", base)
check("dawn and dusk produce the identical color (same palette entry, symmetric keyframes)",
  dawn[1] == dusk[1] and dawn[2] == dusk[2] and dawn[3] == dusk[3])

local noonStorm = AB.computeColor(720, "Storm", base)
check("weather category changes the noon color (Storm's palette differs from Clear's)",
  noonStorm[1] ~= noon[1] or noonStorm[2] ~= noon[2] or noonStorm[3] ~= noon[3])

local noonUnknown = AB.computeColor(720, "SomeUnrecognizedCategory", base)
check("an unrecognized/nil weather category falls back to the Clear palette rather than erroring",
  noonUnknown[1] == noon[1] and noonUnknown[2] == noon[2] and noonUnknown[3] == noon[3])

local wrapped = AB.computeColor(1440, "Clear", base)
local unwrapped = AB.computeColor(0, "Clear", base)
check("minute 1440 (midnight of the next day) matches minute 0 (wraps cleanly)",
  wrapped[1] == unwrapped[1] and wrapped[2] == unwrapped[2] and wrapped[3] == unwrapped[3])

------------------------------------------------------------------------
-- captureBase() -- snapshot-once guard
------------------------------------------------------------------------
AB.config.baseColor = nil
AB.captureBase()
check("captureBase() reads the real console background on first call",
  AB.config.baseColor and AB.config.baseColor[1] == fakeRealBg[1])

fakeRealBg = { 99, 99, 99 }
AB.captureBase()
check("captureBase() never overwrites an existing snapshot, even if the live background has since changed (would be an already-tinted color, not the real base)",
  AB.config.baseColor[1] == 12)

------------------------------------------------------------------------
-- enable()/disable() -- real console calls
------------------------------------------------------------------------
AB.config.enabled = true
bgCalls = {}
AB.apply()
check("apply() while enabled calls setBackgroundColor on the real 'main' console",
  #bgCalls == 1 and bgCalls[1].name == "main" and bgCalls[1].a == 255)

bgCalls = {}
AB.config.enabled = false
AB.apply()
check("apply() while disabled makes no console calls at all",
  #bgCalls == 0)

bgCalls = {}
AB.restoreBase()
check("restoreBase() sets the console back to the exact snapshotted base color",
  #bgCalls == 1 and bgCalls[1].r == 12 and bgCalls[1].g == 12 and bgCalls[1].b == 14)

print(string.format("\n%d failure(s)", failures))
os.exit(failures == 0 and 0 or 1)
