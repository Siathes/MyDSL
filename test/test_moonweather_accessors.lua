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

------------------------------------------------------------------------
-- tooltipText() -- Steven, MyDSL Test notes.json (2026-08-30): hover
-- tooltip request. Wired to setLabelToolTip("MW_mainLabel", ...) in
-- render(); tested directly here since tooltipText() is pure.
------------------------------------------------------------------------
check("tooltipText() with no lunar data tells the player to run 'lunar'",
  MW.tooltipText("red", nil):find("run 'lunar'", 1, true) ~= nil)

local lunarData = {
  red   = { phase = "Full", position = "overhead" },
  white = { phase = "New", position = "not visible" },
}
local tip = MW.tooltipText("red", lunarData)
check("tooltipText() lists the focal moon marked '(yours)'",
  tip:find("Red Moon (yours): Full, overhead", 1, true) ~= nil)
check("tooltipText() lists a non-focal moon without the '(yours)' marker",
  tip:find("White Moon: New, not visible", 1, true) ~= nil
    and tip:find("White Moon (yours)", 1, true) == nil)
check("tooltipText() omits a moon with no captured phase (e.g. black, never seen this session)",
  tip:find("Black Moon", 1, true) == nil)

check("tooltipText() falls back to the 'run lunar' message when lunar data has no real phases",
  MW.tooltipText("red", {}):find("run 'lunar'", 1, true) ~= nil)

------------------------------------------------------------------------
-- phaseScheduleLines() -- Steven's follow-up ask, same notes.json entry:
-- "add the times to all the next phases so the user can see how long
-- till a next specific phase."
------------------------------------------------------------------------
check("phaseScheduleLines() returns nothing when there's no current-phase key",
  #MW.phaseScheduleLines("red", nil, 45) == 0)
check("phaseScheduleLines() returns nothing when there's no cycles_remaining",
  #MW.phaseScheduleLines("red", "full", nil) == 0)

-- Red moon: 90 ticks/phase (docs/DSL_CommandRef.md). Starting at "full"
-- with 45 cycles left in the current phase, the very next phase
-- (three_quarter_waning) should be 45 cycles away; the one after that,
-- 45 + 90 = 135; and so on, 7 real steps total (every other phase in
-- the 8-phase cycle, current phase itself excluded).
local schedule = MW.phaseScheduleLines("red", "full", 45)
check("phaseScheduleLines() returns exactly 7 lines (every phase except the current one)",
  #schedule == 7)
check("phaseScheduleLines() first entry is the immediately next phase at the real cycles_remaining",
  schedule[1]:find("3/4 Waning", 1, true) ~= nil and schedule[1]:find("45cy", 1, true) ~= nil)
check("phaseScheduleLines() second entry adds one full red-moon phase length (45 + 90 = 135)",
  schedule[2]:find("135cy", 1, true) ~= nil)
check("phaseScheduleLines() last entry wraps back around to just before Full again",
  schedule[7]:find("3/4 Waxing", 1, true) ~= nil)

check("phaseScheduleLines() uses the white moon's own real per-phase length (108, not red's 90)",
  MW.phaseScheduleLines("white", "full", 10)[2]:find("118cy", 1, true) ~= nil)

------------------------------------------------------------------------
-- tooltipText() full-schedule branch -- fires only when the focal moon
-- actually has cycles_remaining (real `lunar` bonus data captured).
------------------------------------------------------------------------
local lunarWithCycles = {
  red = { phase = "full", position = "overhead", cycles_remaining = 45 },
}
local tipFull = MW.tooltipText("red", lunarWithCycles)
check("tooltipText() wraps output in a small-font HTML div, per Steven's 'make text smaller' ask",
  tipFull:find('font-size:8pt', 1, true) ~= nil)
check("tooltipText() includes the full phase schedule when cycles_remaining is known",
  tipFull:find("Full schedule (yours):", 1, true) ~= nil
    and tipFull:find("3/4 Waning", 1, true) ~= nil)
check("tooltipText() omits the full schedule when cycles_remaining isn't known (no 'lunar' run yet)",
  MW.tooltipText("red", lunarData):find("Full schedule", 1, true) == nil)

-- render() actually calls setLabelToolTip on the widget's one real label.
-- MW.ui.label is normally built by the module's own internal _buildUI();
-- construct the same real Geyser.Label directly here (same name/shape)
-- rather than dragging in the whole Adjustable.Container chain.
MyDSL.State.score = { align = "True Neutral" }
MyDSL.State.lunar = lunarData
MW.ui = MW.ui or {}
MW.ui.label = Geyser.Label:new({ name = "MW_mainLabel" })
MW.render()
check("render() pushes a real tooltip onto MW_mainLabel via setLabelToolTip()",
  _G.__labelToolTips["MW_mainLabel"] ~= nil
    and _G.__labelToolTips["MW_mainLabel"]:find("Red Moon (yours): Full, overhead", 1, true) ~= nil)

print(string.format("\n%d failure(s)", failures))
os.exit(failures == 0 and 0 or 1)
