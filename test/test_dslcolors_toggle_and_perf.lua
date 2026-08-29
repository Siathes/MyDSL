-- Real fixes, 2026-08-29, per Steven ("dslcolor needs to be integrated
-- into MyDSL, it will toggle on off like the others" + "I want an
-- optimization pass on this... fix the known issues"): DslColors_Core_
-- v1_0.xml had no master on/off (only echo_updates, notification
-- verbosity) and dslBoundedFind() re-lowercased the same real game line
-- once per term checked against it (up to ~803 times per line).
--
-- Extracts the real embedded Lua directly from the git-tracked native
-- XML (not a hand-copied paraphrase), same technique as
-- test_mapper_gmcp_and_doorverb.lua uses for the mapper fork.
--
-- Run: luajit test/test_dslcolors_toggle_and_perf.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local function xmlUnescape(s)
  s = s:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"')
       :gsub("&apos;", "'"):gsub("&#39;", "'")
  s = s:gsub("&amp;", "&")
  return s
end

local f = io.open("DslColors_Core_v1_0.xml", "r")
assert(f, "DslColors_Core_v1_0.xml not found -- run from the repo root")
local xml = f:read("*a")
f:close()

local scriptBody
for body in xml:gmatch("<script>(.-)</script>") do
  if body:find("DSL_COLOR_DB = DSL_COLOR_DB or", 1, true) then scriptBody = body; break end
end
assert(scriptBody, "couldn't find the DslColors <script> block")
scriptBody = xmlUnescape(scriptBody)

-- deselect() is used by the real coloring path (dslColorTextAt) but
-- isn't in the shared mock -- defined locally rather than added there,
-- since nothing else in this suite needs it.
_G.deselect = function() end

local chunk, loadErr = load(scriptBody, "dslcolors_extract")
check("extracted DslColors source loads without a syntax error", chunk ~= nil and loadErr == nil)
if not chunk then print("  load error: " .. tostring(loadErr)) end

local ok, runErr = pcall(chunk)
check("extracted DslColors source runs without error (defines functions + loads/installs, no crash)", ok)
if not ok then print("  runtime error: " .. tostring(runErr)) end

-- Clean up whatever dslColorLoad()/dslColorSave() touched in the mocked
-- home dir, matching this suite's established scratch-file convention.
os.remove(DSL_COLOR_DATA_PATH)

------------------------------------------------------------------------
-- Part 1: master toggle
------------------------------------------------------------------------

check("DSL_COLOR_DB.settings.enabled defaults to true", DSL_COLOR_DB.settings.enabled == true)

_G.line = "A gnome student is here."
local resetCalls = 0
local realReset = dslResetLineRanges
dslResetLineRanges = function(...) resetCalls = resetCalls + 1; return realReset(...) end

DSL_COLOR_DB.settings.enabled = true
dslColorOnLine()
check("enabled=true: dslColorOnLine() actually does real work (reaches dslResetLineRanges)",
  resetCalls == 1)

resetCalls = 0
DSL_COLOR_DB.settings.enabled = false
dslColorOnLine()
check("enabled=false: dslColorOnLine() is a no-op, never reaches real per-line work",
  resetCalls == 0)

DSL_COLOR_DB.settings.enabled = true
dslColorCommand("off")
check('dslcolor command "off" disables the master toggle', DSL_COLOR_DB.settings.enabled == false)
dslColorCommand("on")
check('dslcolor command "on" re-enables it', DSL_COLOR_DB.settings.enabled == true)

------------------------------------------------------------------------
-- Part 2: lowercase caching
------------------------------------------------------------------------

local lowerCalls = 0
local realLower = string.lower
string.lower = function(s) lowerCalls = lowerCalls + 1; return realLower(s) end

local sameLine = "The gnome student is here, looking bored."
dslBoundedFind(sameLine, "gnome", 1)
local afterFirst = lowerCalls
dslBoundedFind(sameLine, "student", 1)
dslBoundedFind(sameLine, "bored", 1)
dslBoundedFind(sameLine, "here", 1)
check("repeated dslBoundedFind() calls against the SAME line only lowercase the line once",
  lowerCalls == afterFirst + 3)  -- +3 for the 3 new terms' own string.lower(term); the line itself is cached, not re-lowered

local differentLine = "A completely different room description."
lowerCalls = 0
dslBoundedFind(differentLine, "different", 1)
check("a genuinely different line correctly invalidates the cache and re-lowercases",
  lowerCalls == 2)  -- 1 for the new line, 1 for the term

string.lower = realLower

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
