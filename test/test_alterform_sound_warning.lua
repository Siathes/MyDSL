-- Alterform warning/danger sound, 2026-08-24, per Steven's MyDSL notes
-- ("warning + sound before it falls off (countdown from the last 5
-- ticks, warning at 10 ticks left)"). F.palette() already implements
-- these exact two thresholds visually since 2026-07-11 -- this adds the
-- sound half at the same thresholds, firing once per zone transition,
-- not on every render.
--
-- Run: luajit test/test_alterform_sound_warning.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local SOUND_DIR = "/tmp/claude_mudlet_home/Sounds"
os.execute("mkdir -p " .. SOUND_DIR)
os.execute("rm -f " .. SOUND_DIR .. "/alterform_warning.mp3 " .. SOUND_DIR .. "/alterform_danger.mp3")

dofile("MyDSL_LayoutEngine.lua")
dofile("MyDSL_WindowRegistry.lua")
dofile("MyDSL_AlterformView.lua")

local F = MyDSL.AlterformView

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

------------------------------------------------------------------------
-- Part 1: no sound file present -> safe no-op, no error, no fake play.
------------------------------------------------------------------------
_G.__playedSounds = {}
local ok1 = pcall(F.checkSoundWarning, "warn")
check("checkSoundWarning() doesn't error when the sound file is missing", ok1)
check("no sound is played when the file genuinely doesn't exist on disk",
  #_G.__playedSounds == 0)

------------------------------------------------------------------------
-- Part 2: with a real file present, fires exactly once per transition
-- INTO a zone, not on every subsequent call while still in that zone.
------------------------------------------------------------------------
local wf = io.open(SOUND_DIR .. "/alterform_warning.mp3", "w"); wf:write("x"); wf:close()
local df = io.open(SOUND_DIR .. "/alterform_danger.mp3", "w"); df:write("x"); df:close()

F._lastSoundZone = nil
_G.__playedSounds = {}
F.checkSoundWarning("ready")
check("no sound at 'ready' (plenty of time left)", #_G.__playedSounds == 0)

F.checkSoundWarning("warn")
check("entering 'warn' plays exactly one sound", #_G.__playedSounds == 1)

F.checkSoundWarning("warn")
check("staying in 'warn' on a later render does NOT replay the sound",
  #_G.__playedSounds == 1)

F.checkSoundWarning("danger")
check("transitioning warn -> danger plays a second, different sound",
  #_G.__playedSounds == 2)

F.checkSoundWarning("off")
F.checkSoundWarning("warn")
check("falling off and re-forming resets the tracked zone, so a fresh countdown warns again",
  #_G.__playedSounds == 3)

------------------------------------------------------------------------
-- Part 3: the on/off toggle actually suppresses the sound.
------------------------------------------------------------------------
F.setSoundEnabled(false)
F._lastSoundZone = nil
_G.__playedSounds = {}
F.checkSoundWarning("danger")
check("mydsl alterform sound off suppresses the warning entirely",
  #_G.__playedSounds == 0)

F.setSoundEnabled(true)
_G.__playedSounds = {}
F.checkSoundWarning("danger")
check("re-enabling sound restores the warning", #_G.__playedSounds == 1)

os.execute("rm -f " .. SOUND_DIR .. "/alterform_warning.mp3 " .. SOUND_DIR .. "/alterform_danger.mp3")

print(string.rep("-", 60))
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
