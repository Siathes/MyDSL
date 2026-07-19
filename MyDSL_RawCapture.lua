-- =============================================================================
-- MyDSL_RawCapture.lua  --  Diagnostic: capture pre-processing server text
-- =============================================================================
-- Added 2026-07-06 per Steven, originally to check whether PNP's Highlighter
-- (see PNP files/DSL_PNP_Highlighter.lua replaceNames()) was rewriting lines
-- before they reached our own triggers/the saved session log. Since then,
-- confirmed by two independent checks that this specific concern doesn't
-- apply to DSL2 today: (1) grepped every active MyDSL_*.lua file for any
-- reference to Highlighter/replaceNames -- none; PNP files/ is read-only
-- reference material we read for porting, never dofile()'d into the running
-- profile; (2) date-stratified the log/ corpus and found the bracket-
-- decoration/room-tag formats that motivated this module are >99% confined
-- to Jan-May 2026 files (pre-dating DSL2, almost certainly from the actual
-- PNP sibling profile) -- zero genuine occurrences across all 157 June+July
-- 2026 (DSL2-era) log files checked.
--
-- Keeping this module anyway -- it's still generically useful, cheap
-- insurance: any future script we add to DSL2 that touches line text before
-- it's logged (a new highlighter, a recoloring feature, anything using
-- replace()/cinsertText()) will show up as a discrepancy between this log
-- and the normal session log the next time this is turned on and compared.
-- Not an active concern today, just kept as a standing check.
--
-- Off by default -- this logs literally every line of the entire session.
-- Toggle: "mydsl rawlog on" / "mydsl rawlog off". Still needs its dofile()
-- placed first in Mudlet's Script editor if it's ever actually used for this
-- purpose (GUI-configured, not something this file can do itself).
-- =============================================================================

MyDSL             = MyDSL             or {}
MyDSL.RawCapture  = MyDSL.RawCapture  or { enabled = false }

-- Kill any trigger from a previous load.
MyDSL.RawCapture._triggers = MyDSL.RawCapture._triggers or {}
local function deregisterTriggers()
  for _, id in pairs(MyDSL.RawCapture._triggers) do
    pcall(killTrigger, id)
  end
  MyDSL.RawCapture._triggers = {}
end
deregisterTriggers()

local function safeFileName(s)
  s = tostring(s or "Unknown"):gsub("[^%w_%-%.]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if s == "" then s = "Unknown" end
  return s
end

local function stripColorTags(s)
  return (s or ""):gsub("<%d+,%d+,%d+>", ""):gsub("<r>", "")
end

local function writeRaw(text)
  if not MyDSL.RawCapture.enabled then return end
  if not text or text == "" then return end
  local char = safeFileName(MyDSL.Char and MyDSL.Char() or "Unknown")
  local dir  = getMudletHomeDir() .. "/MyDSL/logs/rawcapture/" .. char
  if lfs and lfs.mkdir then pcall(lfs.mkdir, dir) end
  if os and os.execute then pcall(os.execute, "mkdir -p " .. string.format("%q", dir)) end
  local path = dir .. "/" .. os.date("%Y-%m-%d") .. ".log"
  local f = io.open(path, "a")
  if not f then return end
  f:write(os.date("%H:%M:%S") .. "  " .. stripColorTags(text) .. "\n")
  f:close()
end

-- Priority 100: as high as anything else in this codebase sets (nothing
-- else sets a priority at all, so this should win any tie -- but see the
-- header note above, this needs live confirmation, not just assumption.
--
-- Only actually registered while enabled -- fixed 2026-07-19 after a PVP
-- perf audit found this trigger used to be created unconditionally at load
-- and stay alive for the whole session even with rawlog off, so every
-- single line of the entire profile (including every combat swing) paid
-- for a trigger-match + Lua call into writeRaw() just to hit its own
-- "not enabled, return" check -- cheap per call, but 100% unconditional
-- overhead on every line, forever, for a diagnostic feature that's off by
-- default. Registering/killing it alongside the toggle means the cost is
-- zero while off, matching how every other optional capture in this
-- codebase behaves.
local function registerCaptureTrigger()
  if MyDSL.RawCapture._triggers.capture then return end
  MyDSL.RawCapture._triggers.capture = tempRegexTrigger([[.]], function()
    writeRaw(line)
  end, 100)
end

local function unregisterCaptureTrigger()
  if MyDSL.RawCapture._triggers.capture then
    pcall(killTrigger, MyDSL.RawCapture._triggers.capture)
    MyDSL.RawCapture._triggers.capture = nil
  end
end

if MyDSL.RawCapture.enabled then registerCaptureTrigger() end

-- Own alias table, not the shared MyDSL._aliases -- this file loads before
-- DataLayer (see header), so that table may not exist yet.
MyDSL.RawCapture._aliases = MyDSL.RawCapture._aliases or {}
if MyDSL.RawCapture._aliases.toggle then pcall(killAlias, MyDSL.RawCapture._aliases.toggle) end
MyDSL.RawCapture._aliases.toggle = tempAlias(
  [[^mydsl rawlog (on|off)$]],
  [[MyDSL.RawCapture.enabled = (matches[2] == "on")
    if MyDSL.RawCapture.enabled then MyDSL._rawCaptureRegister() else MyDSL._rawCaptureUnregister() end
    echo("Raw capture logging " .. matches[2] .. ".\n")]]
)
-- Exposed on MyDSL so the alias's script string (a separate Lua chunk,
-- no closure access to this file's locals) can reach these.
MyDSL._rawCaptureRegister = registerCaptureTrigger
MyDSL._rawCaptureUnregister = unregisterCaptureTrigger
