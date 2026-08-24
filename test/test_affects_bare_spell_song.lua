-- Structural test for the 2026-08-24 modifier-less Song:/Spell: capture
-- fix. Real gap, found during a cross-profile log-corpus confirmation
-- pass: "Song : song of war" / "Spell: toughness" (no "modifies ... by
-- ... for ... cycles" clause at all) is a real DSL output shape that
-- matched neither A.ids.triggers.song nor .spell -- both require that
-- clause. Very likely the same real mechanism as Steven's own separate
-- note (MyDSL notes_utf8.txt: "low level charcaters cant see timers for
-- affects") -- a lower-level character's affects text fallback doesn't
-- print modifier/duration info at all.
--
-- The actual PCRE regex correctness (the negative-lookahead exclusion
-- so the bare and full-clause triggers never double-fire on the same
-- line) was cross-checked directly against both Python's `re` and real
-- PCRE via `perl -e` before this was written -- this test covers the
-- Lua-side capture/state behavior once a match's groups are already
-- extracted, matching this suite's own established split (Mudlet's
-- PCRE trigger matching itself isn't something plain luajit can
-- exercise -- Lua patterns have no lookahead at all).
--
-- Run: luajit test/test_affects_bare_spell_song.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

MyDSL = { Windows = { ensure = function() return {} end } }
dofile("MyDSL_AffectsView.lua")
local A = MyDSL.Affects

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

------------------------------------------------------------------------
-- 1. Bare form captures the affect with no modifier, no fake timer
------------------------------------------------------------------------
A.startCapture()
A.captureSpellLineBare("song of war")
local entry = A.list["song of war"]
check("bare Song: capture adds the affect", entry ~= nil)
check("bare capture uses -1 (unknown duration), not a fabricated timer",
  entry and entry.duration == -1)
check("bare capture has no modifier entries (none were known)",
  entry and #entry.mods == 0)

------------------------------------------------------------------------
-- 2. Full-clause form still works exactly as before (regression guard)
------------------------------------------------------------------------
A.clearList()
A.startCapture()
A.captureSpellLine("bless", "armor class", "-10", "20")
local full = A.list["bless"]
check("the existing full-clause capture path is unaffected by this fix",
  full and full.duration == 20 and full.mods[1] and full.mods[1].lc == "armor class" and full.mods[1].m == -10)

------------------------------------------------------------------------
-- 3. Mixed real block: both forms in the same capture session (this is
-- the actual real shape Steven would see -- some affects have visible
-- modifiers, some don't, in the same "affects" listing)
------------------------------------------------------------------------
A.clearList()
A.startCapture()
A.captureSpellLine("song of war", "damage roll", "2", "12")
A.captureSpellLineBare("toughness")
check("a mixed block captures both the full-clause and bare entries",
  A.list["song of war"] ~= nil and A.list["toughness"] ~= nil)
check("the bare entry in a mixed block still has no fabricated modifier",
  A.list["toughness"].duration == -1 and #A.list["toughness"].mods == 0)

------------------------------------------------------------------------
-- 4. Neither bare nor full capture does anything outside an active
-- capture session (both already guard on A.state.capture -- confirm
-- the new function inherited that guard correctly, not just copied the
-- body without it).
------------------------------------------------------------------------
A.clearList()
A.state.capture = false
A.captureSpellLineBare("should not appear")
check("captureSpellLineBare() is a no-op outside an active capture session",
  A.list["should not appear"] == nil)

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
