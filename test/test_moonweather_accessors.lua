-- Regression test for MyDSL_MoonWeather.lua's two accessors extracted
-- 2026-08-30 (no behavior change to clockStr()/buildWeatherText() --
-- both now just call these) so MyDSL_AmbientBackground.lua has a real,
-- already-tested source for time-of-day and weather category instead of
-- re-deriving either.
--
-- Run: luajit test/test_moonweather_accessors.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

MyDSL = MyDSL or {}
MyDSL.State = MyDSL.State or {}

dofile("MyDSL_MoonWeather.lua")
local MW = MyDSL.MoonWeather

------------------------------------------------------------------------
-- currentGameMinutes()
------------------------------------------------------------------------
check("currentGameMinutes() returns nil before any clock anchor exists",
  MW.currentGameMinutes() == nil)

MW.setClockAnchor("5:30am")
local mins = MW.currentGameMinutes()
check("currentGameMinutes() reflects the just-set anchor (5:30am = 330 minutes)",
  mins and mins >= 330 and mins < 331)

MW.setClockAnchor("12:00pm")
mins = MW.currentGameMinutes()
check("currentGameMinutes() handles noon correctly (12:00pm = 720 minutes, not 0 or 1440)",
  mins and mins >= 720 and mins < 721)

MW.setClockAnchor("12:00am")
mins = MW.currentGameMinutes()
check("currentGameMinutes() handles midnight correctly (12:00am = 0 minutes, not 720 or 1440)",
  mins and mins >= 0 and mins < 1)

------------------------------------------------------------------------
-- weatherCategory()
------------------------------------------------------------------------
MyDSL.State.weather = MyDSL.State.weather or {}
MyDSL.State.weather.description = ""
check("weatherCategory() returns nil when no weather data has been captured yet",
  MW.weatherCategory() == nil)

MyDSL.State.weather.description = "The sun is shining in a clear sky."
check("weatherCategory() recognizes a real captured 'clear' description",
  MW.weatherCategory() == "Clear")

MyDSL.State.weather.description = "Lightning flashes across a stormy sky."
check("weatherCategory() recognizes a real captured storm description",
  MW.weatherCategory() == "Storm")

MyDSL.State.weather.description = "Snow falls silently from a clouded sky."
check("weatherCategory() checks the most specific keyword first (snow, not the also-present 'cloud')",
  MW.weatherCategory() == "Snow")

print(string.format("\n%d failure(s)", failures))
os.exit(failures == 0 and 0 or 1)
