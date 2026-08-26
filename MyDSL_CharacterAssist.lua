-- =============================================================================
-- MyDSL_CharacterAssist.lua  --  Interactive equipment/combat-recovery assists
-- =============================================================================
-- Ported 2026-07-07 as part of the PNP/EMCO cannibalization pass (Phase D),
-- from DSL_PNP_Character.disarm.lua, .spellup.lua, and .standup.lua.
-- Approved features only, per Steven's explicit review (2026-07-07):
--   - Rearm: BOTH the auto-trigger-on-disarm AND the manual "rearm" alias
--   - Standup: auto-trigger on knockdown
--   - Spellup: user types "bless all"/"fireproof <slot>" once, then it
--     automates the repetitive per-item cast/re-equip loop
-- NOT approved / not built: DSL_PNP_Affects.gag.lua's auto-refresh (separate
-- discussion, tracked in TODO.md).
--
-- This module SENDS real game commands, unlike MyDSL_DataLayer.lua (Layer 1,
-- passive-only). That's intentional here: rearm/standup fire on a passive
-- combat event with zero typed input (Steven's explicit call, since a
-- disarmed/knocked-down player needs faster reaction than typing allows);
-- spellup's loop is still gated behind an explicit user-typed "bless"/
-- "fireproof" command to start. Reads equipment data from
-- MyDSL.State.equipment.slots (MyDSL_DataLayer.lua Section 9r, passive
-- capture) -- never mutates it, only reads.
-- =============================================================================

MyDSL                  = MyDSL                  or {}
MyDSL.CharacterAssist  = MyDSL.CharacterAssist  or {}

local CA = MyDSL.CharacterAssist

CA.config = CA.config or {
  tilde        = true,   -- send "~" (clear queue) before rearm/standup, matches PNP
  auto_wimpy   = true,   -- restore wimpy after a spellup run, matches PNP
  -- Gates ONLY the passive disarm/knockdown triggers below (auto-rearm,
  -- auto-standup) -- never the always-available manual "rearm" alias,
  -- which stays an explicit player action regardless of this flag.
  -- Added 2026-08-26 per Steven ("make it toggle just in case") --
  -- docs/MYDSL_1.0_MODULE_REDESIGN.md #27 flagged these as the one
  -- always-on-with-no-toggle case left after the 1.0 mandate. Default
  -- true preserves the original 2026-07-07 sign-off behavior unchanged.
  auto_recover = true,
}

CA._triggers = CA._triggers or {}
CA._aliases  = CA._aliases  or {}
local function deregister()
  for _, id in pairs(CA._triggers) do pcall(killTrigger, id) end
  for _, id in pairs(CA._aliases) do pcall(killAlias, id) end
  CA._triggers = {}
  CA._aliases = {}
end
deregister()

local function ce(msg) cecho("\n<cyan>[MyDSL.CharacterAssist]<reset> " .. tostring(msg) .. "\n") end


------------------------------------------------------------------------
-- EQUIPMENT HELPERS  (read MyDSL.State.equipment, never write it)
------------------------------------------------------------------------

local EQUIP_KEY_FILLER = { "a", "an", "the", "some", "of", "and" }

-- Same keyword-derivation PNP's parseKey() does (strip filler words and a
-- trailing possessive) -- PNP additionally lets a player override this via
-- a "set keyword" alias when the auto-derived one doesn't match what DSL
-- expects; not ported here (v1: auto-derive only, revisit if it turns out
-- to guess wrong often enough to matter).
local function deriveKey(item)
  item = tostring(item or ""):gsub("'s ", " "):gsub(",", "")
  local words = {}
  for w in item:gmatch("%S+") do
    if not table.contains(EQUIP_KEY_FILLER, w:lower()) then
      words[#words + 1] = w
    end
  end
  return table.concat(words, " ")
end

local function equipEntry(slot)
  local eq = MyDSL.State and MyDSL.State.equipment
  return eq and eq.slots and eq.slots[slot]
end

local function checkItem(slot)
  local e = equipEntry(slot)
  return e and e.item or false
end

local function hasFlag(slot, flag)
  local e = equipEntry(slot)
  return e and e.flags and table.contains(e.flags, flag)
end

-- Direct port of dslpnp.character.equipment.useItem() -- the one command-
-- sending primitive everything else below is built on. Retrieves an item
-- from wherever it currently is, then sends a command targeting it by
-- keyword. Deliberately NOT in MyDSL_DataLayer.lua (Layer 1 never sends
-- commands) -- this is the interactive layer.
function CA.useItem(slot, command, location)
  local item = checkItem(slot)
  if not item then ce("No item in slot '" .. tostring(slot) .. "'."); return end
  location = location or "worn"
  local key = deriveKey(item)

  -- Disambiguate a worn duplicate (finger1/2, neck1/2, wrist1/2) using
  -- DSL's "2.<keyword>" nth-match syntax, same condition PNP checks.
  local base, idx = slot:match("^(%a+)(%d)$")
  if location == "worn" and idx == "2" then
    local otherItem = checkItem(base .. "1")
    if otherItem and deriveKey(otherItem) == key then
      key = "2." .. key
    end
  end

  if location == "ground" then
    send("get '" .. key .. "'")
  elseif location ~= "worn" and location ~= "inventory" then
    send("get '" .. key .. "' " .. location)
  end

  -- DSL's "bless" command doesn't parse a quoted argument correctly --
  -- documented PNP workaround ("SCORN SAYS WILL NOT BE FIXED"), kept as-is.
  if not command:find("bless") then
    send(command .. " '" .. key .. "'")
  else
    send(command .. " " .. key)
  end
end


------------------------------------------------------------------------
-- VISION CHECK  (blind / no light / can see)
------------------------------------------------------------------------
-- CONFIRMED 2026-07-07 against a real live GMCP dump Steven captured
-- in-game (`lua display(gmcp)` while actually blinded): gmcp.room_data.room
-- becomes the literal string "darkness" -- exactly the same value PNP's
-- own text-prompt parsing checked (dslpnp.prompt.room == "darkness"), just
-- reached through DSL2's GMCP-first room handler instead of a text prompt.
-- MyDSL_DataLayer.lua's gmcp.room_data handler already stores this
-- directly (MyDSL.State.room.name = d.room), so no new trigger or GMCP
-- handler was needed -- the data was already sitting there. Confirmed
-- separately in the same dump: char_data has no standalone "blind"
-- boolean, so the room-name check is the real signal, not a workaround.
-- Also confirmed real, simpler alternative signals from the same session
-- (not used as the primary check, but exact and available if this one
-- ever needs a second opinion): "You are blinded!" / "You can see
-- again." fire on the exact start/end of blindness.

CA._haveLight = true

-- Exported 2026-07-16 (was local) so MyDSL_AutoWhere.lua can reuse this
-- exact confirmed check instead of re-deriving blindness detection.
function CA.checkVision()
  local roomName = (MyDSL.State and MyDSL.State.room and MyDSL.State.room.name or ""):lower()
  if roomName == "darkness" then
    if CA._haveLight then return "blind" else return "no light" end
  end
  return "can see"
end
local checkVision = CA.checkVision


------------------------------------------------------------------------
-- REARM  (approved: both auto-trigger and manual alias)
------------------------------------------------------------------------

function CA.rearmShield(arg)
  local vision = checkVision()
  arg = arg or "full"
  if CA.config.tilde then send("~") end

  if arg == "combat" and vision ~= "can see" then return end
  if checkItem("shield") then CA.useItem("shield", "wear", "ground") end
end

function CA.rearm(arg)
  local vision = checkVision()
  arg = arg or "full"
  if CA.config.tilde then send("~") end

  if arg == "combat" then
    if vision == "blind" then
      if checkItem("secondary") and checkItem("sheathed") then
        CA.useItem("sheathed", "second", "worn")
      elseif checkItem("sheathed") then
        CA.useItem("sheathed", "wield", "worn")
      end
    elseif vision == "can see" then
      if checkItem("wielded") then CA.useItem("wielded", "wield", "ground") end
      if checkItem("secondary") then CA.useItem("secondary", "second", "inventory") end
    else -- "no light"
      if checkItem("wielded") and hasFlag("wielded", "Glowing") then
        CA.useItem("wielded", "wield", "ground")
        if checkItem("secondary") and hasFlag("secondary", "Glowing") then
          CA.useItem("secondary", "second", "inventory")
        end
      else
        if checkItem("secondary") and checkItem("sheathed") then
          CA.useItem("sheathed", "second", "worn")
        elseif checkItem("sheathed") then
          CA.useItem("sheathed", "wield", "worn")
        end
      end
    end
  else -- "full"
    if checkItem("wielded")  then CA.useItem("wielded",  "wield",  "ground") end
    if checkItem("sheathed") then CA.useItem("sheathed", "sheath", "ground") end
    if checkItem("secondary") then CA.useItem("secondary", "second", "ground") end
  end
end


------------------------------------------------------------------------
-- STANDUP  (approved: auto-trigger only, PNP has no manual alias either)
------------------------------------------------------------------------

function CA.standup()
  if CA.config.tilde then send("~") end
  send("stand")
end


------------------------------------------------------------------------
-- SPELLUP  (approved: user starts it, then it automates the per-item loop)
------------------------------------------------------------------------

CA._spellInfo = CA._spellInfo or {}   -- ["bless"|"fireproof"] -> {} | {"wand", name} | {"skill", cmd}
CA._targetList = {}
CA._currentSpell, CA._currentSlot = nil, nil
CA._inProgress = false
CA._waiting, CA._item = false, nil
CA._repeatWaiting = false

local SONG_LIST = {}   -- populated below only if MyDSL.AffectsSongsList exists; else cast is always used
local SKILL_LIST = {}

function CA.setSpellInfo(spell, castType, arg)
  arg = arg or ""
  castType = castType or "spell"
  if spell ~= "bless" and spell ~= "fireproof" then ce("usage: setspell <bless|fireproof> <spell|wand|skill> [name]"); return end
  if castType == "spell" then
    CA._spellInfo[spell] = {}
  elseif castType == "wand" then
    CA._spellInfo[spell] = { "wand", arg }
  elseif castType == "skill" then
    CA._spellInfo[spell] = { "skill", arg }
  else
    ce("usage: setspell <bless|fireproof> <spell|wand|skill> [name]"); return
  end
  ce(string.title(spell) .. " set to " .. castType .. " " .. arg .. ".")
end

local function checkCast(slot, spell)
  local eq = MyDSL.State and MyDSL.State.equipment
  local ignoreKey = "ignoreList_" .. spell
  local ignore = eq and eq.ignore and eq.ignore[ignoreKey]
  local item = checkItem(slot)
  if ignore and item and ignore[item] == false then return false end
  return true
end

function CA.spellupIgnore(spell, slot)
  local item = checkItem(slot)
  if not item then ce("No such equipment slot, or no equipment in that slot."); return end
  MyDSL.State.equipment = MyDSL.State.equipment or {}
  MyDSL.State.equipment.ignore = MyDSL.State.equipment.ignore or {}
  local key = "ignoreList_" .. spell
  MyDSL.State.equipment.ignore[key] = MyDSL.State.equipment.ignore[key] or {}
  local cur = MyDSL.State.equipment.ignore[key][item]
  if cur == nil then cur = true end
  MyDSL.State.equipment.ignore[key][item] = not cur
  ce(item .. ((not cur) and " will once more be '" or " will no longer be '") .. spell .. "ed'.")
end

local function castSpell()
  local info = CA._spellInfo[CA._currentSpell] or {}
  if checkItem(CA._currentSlot) and checkCast(CA._currentSlot, CA._currentSpell) then
    if CA._failsafeTimer then killTimer(CA._failsafeTimer); CA._failsafeTimer = nil end
    CA._failsafeTimer = tempTimer(20, function() MyDSL.CharacterAssist.stop() end)

    if not (info[1] == "wand" and CA._currentSlot == "held") then
      CA.useItem(CA._currentSlot, "remove", "worn")
    end

    local cmd = "cast '" .. CA._currentSpell .. "'"
    if info[1] == "wand" then cmd = "zap"
    elseif info[1] == "skill" then cmd = info[2] end

    CA.useItem(CA._currentSlot, cmd, "inventory")

    if not table.contains({ "sheathed", "secondary", "held" }, CA._currentSlot) then
      CA.useItem(CA._currentSlot, "wear", "inventory")
    elseif CA._currentSlot == "sheathed" then
      CA.useItem(CA._currentSlot, "sheath", "inventory")
    elseif CA._currentSlot == "secondary" then
      CA.useItem(CA._currentSlot, "second", "inventory")
    elseif CA._currentSlot == "held" and (info[1] ~= "wand" or #CA._targetList == 0) then
      CA.useItem(CA._currentSlot, "wear", "inventory")
    end
  else
    MyDSL.CharacterAssist.nextItem()
  end
end

function CA.nextItem()
  local item = CA._item
  CA._waiting = false
  CA._item = nil
  if item then
    local cur = checkItem(CA._currentSlot)
    if not cur or lower(cur) ~= lower(item) then return end
  end

  CA._currentSlot = table.remove(CA._targetList, 1)
  if CA._currentSlot then
    castSpell()
  else
    if CA._failsafeTimer then killTimer(CA._failsafeTimer); CA._failsafeTimer = nil end
    CA._inProgress = false
    MyDSL.CharacterAssist.stop()
  end
end

function CA.repeatItem()
  CA._repeatWaiting = false
  castSpell()
end

function CA.startSpellup(spell, target, resume)
  CA._item = nil
  CA._inProgress = true

  if not resume then
    if target ~= "all" and not checkItem(target) then ce("No such equipment slot."); return end
    CA._spellInfo[spell] = CA._spellInfo[spell] or {}
    CA._currentSpell = spell

    if target ~= "all" then
      CA._targetList = { target }
    else
      local slots = {}
      local eq = MyDSL.State and MyDSL.State.equipment and MyDSL.State.equipment.slots or {}
      for slot, entry in pairs(eq) do
        if entry.item then slots[#slots + 1] = slot end
      end
      table.sort(slots)
      CA._targetList = slots
    end

    local info = CA._spellInfo[spell]
    if info[1] == "wand" then send("wear " .. info[2]) end
  end

  for _, id in pairs(CA._triggers.spellupSuccess or {}) do pcall(enableTrigger, id) end
  for _, id in pairs(CA._triggers.spellupFail or {}) do pcall(enableTrigger, id) end
  for _, id in pairs(CA._triggers.spellupMisc or {}) do pcall(enableTrigger, id) end

  MyDSL.CharacterAssist.nextItem()
end

function CA.stop()
  for _, id in pairs(CA._triggers.spellupSuccess or {}) do pcall(disableTrigger, id) end
  for _, id in pairs(CA._triggers.spellupFail or {}) do pcall(disableTrigger, id) end
  for _, id in pairs(CA._triggers.spellupMisc or {}) do pcall(disableTrigger, id) end

  if CA._inProgress then
    CA._inProgress = false
    ce("Spell up cancelled!")
  else
    ce("Spell up complete.")
  end
  local info = CA._spellInfo[CA._currentSpell]
  if info and info[1] == "wand" then CA.useItem("held", "wear", "inventory") end
  if CA.config.auto_wimpy then send("wimpy") end
end

function CA.equipWand()
  local info = CA._spellInfo[CA._currentSpell]
  if info and info[1] == "wand" then send("wear " .. info[2]) end
end


------------------------------------------------------------------------
-- TRIGGERS
------------------------------------------------------------------------

-- Disarm (4 weapon forms + 2 shield forms) -- pattern text ported verbatim
-- from DSL_PNP_Character.disarm.lua. disarm1 confirmed 2026-07-07 against
-- real DSL2-era text (a log-catalog pass found "An air elemental DISARMS
-- you and sends your weapon flying!" -- exact match). disarm2/disarm3
-- were still unconfirmed for the exact "your weapon" (player-as-victim)
-- form, but that same catalog pass found a real third-person analog with
-- NO comma before "and" ("Rylae grabs Moe's weapon and sends it flying!"
-- -- PNP's own pattern has "weapon, and sends"). Assuming DSL reuses the
-- same message template for both persons (standard for this kind of
-- MUD text), the comma is likely a PNP-source typo -- made optional
-- rather than guessing one way, same tolerant-of-both approach already
-- used for the Roller bracket-format ambiguity.
CA._triggers.disarm1 = tempRegexTrigger([[^.+ DISARMS you and sends your weapon flying!]], function() if CA.config.auto_recover then MyDSL.CharacterAssist.rearm("combat") end end)
CA._triggers.disarm2 = tempRegexTrigger([[^.+ grabs your weapon,? and sends it flying!]], function() if CA.config.auto_recover then MyDSL.CharacterAssist.rearm("combat") end end)
CA._triggers.disarm3 = tempRegexTrigger([[^.+ controls your weapon,? and sends it flying!]], function() if CA.config.auto_recover then MyDSL.CharacterAssist.rearm("combat") end end)
CA._triggers.shieldDisarm1 = tempRegexTrigger([[^.+ knocked loose from their hands by .*]], function() if CA.config.auto_recover then MyDSL.CharacterAssist.rearmShield("combat") end end)
CA._triggers.shieldDisarm2 = tempRegexTrigger([[^.+ sends your shield flying with a powerful kick!]], function() if CA.config.auto_recover then MyDSL.CharacterAssist.rearmShield("combat") end end)
CA._triggers.shieldDisarm3 = tempRegexTrigger([[^.+ swings \w+ weapon viciously at your shield and sends it flying!]], function() if CA.config.auto_recover then MyDSL.CharacterAssist.rearmShield("combat") end end)

-- Light tracking, feeds the vision check above.
CA._triggers.holdLight = tempRegexTrigger([[^You light (.*) and hold it.$]], function() CA._haveLight = true end)
CA._triggers.lightOut = tempRegexTrigger([[^[\w\s]+ flickers and goes out.$]], function() CA._haveLight = false end)

-- Standup
CA._triggers.knockdown = tempRegexTrigger([[^.+ knocking you senseless.$]], function() if CA.config.auto_recover then MyDSL.CharacterAssist.standup() end end)
-- Second, distinct knockdown form -- found 2026-07-08, per Steven ("stand
-- does not work with character assist after being knocked down"): real
-- text confirmed from logs is "<actor> bumps into you causing you to lose
-- your balance." followed by "You sit down." -- a completely different
-- message from "knocking you senseless" above, never covered. Triggered
-- on the bump line itself, not "You sit down." -- that status line alone
-- is almost certainly ambiguous with deliberately typing "sit" to rest
-- (standard DIKU/ROM convention), which must never be auto-stood back up;
-- the bump line is unambiguously involuntary.
CA._triggers.knockdownBump = tempRegexTrigger([[^.+ bumps into you causing you to lose your balance.$]], function() if CA.config.auto_recover then MyDSL.CharacterAssist.standup() end end)

-- setAutoRecover()/toggleAutoRecover() -- see CA.config.auto_recover's
-- own comment above. Only gates the 8 passive triggers above (checked
-- inline, so disabling is genuinely zero-cost on the Lua side even
-- though the trigger match itself still runs -- matching this project's
-- decided minimum bar; a full disableTrigger()-based version would also
-- skip the regex match itself but isn't needed for a "just in case"
-- safety toggle on a rare event).
function CA.setAutoRecover(enabled)
  CA.config.auto_recover = enabled == true
  cecho("\n<cyan>[CharacterAssist]<reset> auto_recover=" .. tostring(CA.config.auto_recover) .. "\n")
end

function CA.toggleAutoRecover()
  CA.setAutoRecover(not CA.config.auto_recover)
end

CA._aliases.autoRecoverOn     = tempAlias([[^mydsl charassist auto on$]],     [[MyDSL.CharacterAssist.setAutoRecover(true)]])
CA._aliases.autoRecoverOff    = tempAlias([[^mydsl charassist auto off$]],    [[MyDSL.CharacterAssist.setAutoRecover(false)]])
CA._aliases.autoRecoverToggle = tempAlias([[^mydsl charassist auto toggle$]], [[MyDSL.CharacterAssist.toggleAutoRecover()]])

-- Spellup outcome triggers -- disabled by default, only enabled for the
-- duration of an active spellup run (see startSpellup()/stop() above).
CA._triggers.spellupSuccess = {}
local successPatterns = {
  [[(.*) glows with a holy aura\.$]],
  [[.* is too powerful for you to overcome\.$]],
  [[You protect .* from fire\.$]],
  [[.* is already protected from burning\.$]],
  [[.* is already blessed\.$]],
  [[You cover .* with mud\.$]],
  [[.* is already protected\.$]],
  [[You are not carrying that\.$]],
  [[You don't see that here\.$]],
}
for i, pat in ipairs(successPatterns) do
  CA._triggers.spellupSuccess[i] = tempRegexTrigger(pat, function()
    CA._item = matches[2]
    CA._waiting = true
  end)
  disableTrigger(CA._triggers.spellupSuccess[i])
end

CA._triggers.spellupFail = {}
local failPatterns = {
  [[You lost your concentration\.$]],
  [[Your efforts with .* produce only smoke and sparks\.$]],
  [[The mud is too wet and runs off\.$]],
}
for i, pat in ipairs(failPatterns) do
  CA._triggers.spellupFail[i] = tempRegexTrigger(pat, function() CA._repeatWaiting = true end)
  disableTrigger(CA._triggers.spellupFail[i])
end

CA._triggers.spellupMisc = {}
CA._triggers.spellupMisc[1] = tempRegexTrigger([[You hold nothing in your hand.$]], function() MyDSL.CharacterAssist.stop() end)
CA._triggers.spellupMisc[2] = tempRegexTrigger([[You can zap only with a wand.$]], function() MyDSL.CharacterAssist.stop() end)
CA._triggers.spellupMisc[3] = tempRegexTrigger([[Your .* explodes into fragments.$]], function() MyDSL.CharacterAssist.equipWand() end)
for _, id in ipairs(CA._triggers.spellupMisc) do disableTrigger(id) end

-- Drives the wait-for-response step of the spellup loop -- PNP hooks its
-- own "onPrompt" event; DSL2's closest equivalent (fires on every GMCP
-- vitals packet, i.e. every prompt-equivalent refresh) is char.updated.
registerAnonymousEventHandler("MyDSL.char.updated", "MyDSL.CharacterAssist.onCharUpdated")
function CA.onCharUpdated()
  if CA._waiting then MyDSL.CharacterAssist.nextItem()
  elseif CA._repeatWaiting then MyDSL.CharacterAssist.repeatItem() end
end


------------------------------------------------------------------------
-- ALIASES  (reuses PNP's own command vocabulary verbatim)
------------------------------------------------------------------------

CA._aliases.rearm = tempAlias([[^rearm$]], [[MyDSL.CharacterAssist.rearm("full")]])
CA._aliases.setSpell = tempAlias([[^setspell (\w+) (\w+)\s?([\w\s]*)$]], [[MyDSL.CharacterAssist.setSpellInfo(matches[2], matches[3], matches[4])]])
-- Bare "setspell" (no args) didn't match the pattern above, so it fell
-- through to the server as "Huh?" with no feedback -- confirmed live
-- 2026-07-16 (Steven tried it by itself). setSpellInfo() already has a
-- real usage message for malformed args; this just makes it reachable
-- for the zero-arg case too.
CA._aliases.setSpellUsage = tempAlias([[^setspell$]], [[MyDSL.CharacterAssist.setSpellInfo()]])
CA._aliases.stopSpellup = tempAlias([[^stop spellup$]], [[MyDSL.CharacterAssist.stop()]])
CA._aliases.spellup = tempAlias([[^(bless|fireproof) (\w+)\s?(\w*)$]], [[MyDSL.CharacterAssist.startSpellup(matches[2], matches[3] .. matches[4])]])
CA._aliases.resumeSpellup = tempAlias([[^resume spellup$]], [[MyDSL.CharacterAssist.startSpellup(nil, nil, true)]])
CA._aliases.ignoreSpellup = tempAlias([[^ignore (bless|fireproof) (\w+)$]], [[MyDSL.CharacterAssist.spellupIgnore(matches[2], matches[3])]])

debugc("[MyDSL] CharacterAssist loaded.")
