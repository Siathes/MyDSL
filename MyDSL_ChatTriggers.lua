-- =============================================================================
-- MyDSL_ChatTriggers.lua  --  Layer 3: Chat channel routing
-- =============================================================================
-- Intercepts chat channel lines and routes them to EMCO tabs via
-- MyDSL.Chat.emco:append(). Lines are removed from the main console.
-- Must load LAST — MyDSL.Chat.emco is created by MyDSL_Chat.lua (formerly
-- MyDSL_ChatWrapper.lua). Updated 2026-07-17: this used to read the bare
-- global demonnic.chat (EMCO's own historical convention, inherited from
-- the separate EMCOChat package this project no longer depends on) --
-- per Steven ("everything under MyDSL namespace"), now reads
-- MyDSL.Chat.emco directly instead.
-- =============================================================================

MyDSL              = MyDSL              or {}
MyDSL.ChatTriggers = MyDSL.ChatTriggers or {}

-- Per-channel gag/show toggle, added 2026-08-26 per Steven ("there
-- should be a gag and show for each channel and a fallback show if
-- anything breaks or turns off") -- this file previously had ZERO way to
-- turn off routing/gagging for any channel (docs/MYDSL_1.0_MODULE_
-- REDESIGN.md #17). true (default, matches original behavior) = route
-- the channel's lines to its EMCO tab and remove them from the main
-- console; false = leave that channel's lines on the main console
-- entirely, no routing at all -- the explicit "show" fallback. This is
-- the same "move text, don't replace it" principle the existing
-- MyDSL.Chat.emco-not-ready guard in route() below already applies for
-- an accidental boot-timing gap; this makes the same fallback reachable
-- on purpose, per channel.
MyDSL.ChatTriggers.config = MyDSL.ChatTriggers.config or {
  channels = {
    Tells = true,
    Group = true,
    OOC   = true,
    City  = true,
    Local = true,
  },
}

-- Kill any triggers/aliases from a previous load.
MyDSL.ChatTriggers._triggers = MyDSL.ChatTriggers._triggers or {}
MyDSL.ChatTriggers._aliases  = MyDSL.ChatTriggers._aliases  or {}
for _, id in pairs(MyDSL.ChatTriggers._aliases) do pcall(killAlias, id) end
MyDSL.ChatTriggers._aliases = {}
local function deregisterTriggers()
  for _, id in pairs(MyDSL.ChatTriggers._triggers) do
    pcall(killAnonymousEventHandler, id)
    pcall(killTrigger, id)
  end
  MyDSL.ChatTriggers._triggers = {}
end
deregisterTriggers()


------------------------------------------------------------------------
-- HELPER  — register one regex trigger that routes to a named tab
------------------------------------------------------------------------
-- `gag` defaults to true (route to the tab AND remove from main console,
-- the original behavior). Pass false to still route to the tab but leave
-- the line visible on the main console too -- added 2026-07-11 per
-- Steven ("want says, tells, shouts, yell to echo and not be gagged").

-- NC (NAMECHAR) -- added 2026-07-17, real bug found live: Steven's own
-- diagnosis ("Iler'yx clan gossip wasnt captured into chat window, think
-- safe to assum its the name breaking capture") was exactly right. Every
-- route() pattern below used [^']+/[^']* for the speaker-name zone (the
-- 2026-07-11 anchoring fix, meant to stop the prefix at the message's own
-- opening quote so a verb-word inside a DIFFERENT message's quoted
-- dialogue could never falsely match). That fix assumed a bare apostrophe
-- always means "start of quoted message" -- but real DSL character names
-- can contain an apostrophe mid-word ("Iler'yx"), and [^']+ can't tell
-- that apart from a real opening quote: it just stops matching partway
-- through the name, and the whole anchored pattern (which requires the
-- verb immediately next) silently fails for every message from that
-- character, on every channel. Fixed generally: this class matches any
-- non-quote character, OR an apostrophe with a word character on BOTH
-- sides (mid-word, like "Iler'yx") -- a real opening quote is always
-- preceded by a space (after "verb "), so the lookbehind alone correctly
-- tells the two apart without needing to special-case any specific name.
-- Verified via full-corpus regression: 0 new cross-tab false matches (the
-- one pre-existing "You tell the group" ambiguity below is unrelated,
-- fixed separately), while 53 real previously-silently-dropped lines
-- across Tells/OOC/City/Local now correctly route.
local NC = "(?:[^']|(?<=\\w)'(?=\\w))"

local function route(tabName, pattern, gag)
  local id = tempRegexTrigger(pattern, function()
    -- Player-toggled fallback: if this channel is turned off, leave the
    -- line on the main console untouched -- no routing, no gagging.
    if MyDSL.ChatTriggers.config.channels[tabName] == false then return end

    -- routed tracks whether the line actually reached a chat tab --
    -- added 2026-07-17, real data-loss bug found live: MyDSL.Chat.emco is
    -- only ever created by MyDSL_Chat.lua's startup timer ladder, not
    -- synchronously at boot (see that file's C.install()/C.startupSync()).
    -- If chat traffic arrives before that ladder finishes (slow boot,
    -- heavier system load), MyDSL.Chat.emco is still nil here -- append()
    -- never happens, but deleteLine() below used to fire unconditionally
    -- anyway, silently erasing the message from the main console with
    -- nowhere else for it to go. Now deleteLine() only fires once the
    -- line has actually landed in a chat tab -- worst case during a slow
    -- boot, chat text stays visible on the main console instead of
    -- vanishing outright, matching "stale data beats spam, never lose
    -- real data" (CLAUDE.md).
    local routed = false
    if MyDSL and MyDSL.Chat and MyDSL.Chat.emco then
      MyDSL.Chat.emco:append(tabName)
      routed = true
    end
    if routed and gag ~= false then deleteLine() end
  end)
  MyDSL.ChatTriggers._triggers[#MyDSL.ChatTriggers._triggers + 1] = id
end


-- 2026-07-06, third pass: passes one and two (log-corpus guessing, then
-- native-XML ground truth) both used a narrow "(?: \([^)]+\))?" group for
-- the optional "(Language)" tag. Steven flagged a real gap that exposed:
-- DSL_Helpfiles/voicetype.txt confirms 21 distinct voice types (Soft,
-- Raspy, Low toned, Growlingly, Husky, ...), and real corpus text shows
-- their phrasing is irregular -- "says softly", "says in a raspy voice",
-- "says in a low toned manner" -- not one uniform template. On top of
-- that, a "(to Name)" target tag and a "(Language)" tag can BOTH appear,
-- in either combination, e.g. "Ariaenys says in a musical tone (to You)
-- (Dragon) 'message'". Enumerating every voice-type phrasing would be
-- exactly the same mistake being fixed elsewhere this session (guessing
-- instead of sourcing) for the ~10 of 21 types with no confirmed example
-- yet. Fixed generally instead: every speech-verb pattern now accepts
-- ANY text between the verb and the opening quote ("[^']*'" -- stops at
-- the first quote, since chat lines don't nest quotes), which correctly
-- covers voice-phrase + target-tag + language-tag in any combination or
-- none, without needing to know each one's exact wording. Verified this
-- doesn't over-match: re-ran every pattern against the clean corpus,
-- counts stayed sane (e.g. Local says went 2,759 -> 2,959, not
-- unbounded), and all 139 real voice-type "says" lines in the corpus are
-- now covered where 0 were missed before. Voice-type modifiers only ever
-- appear on "says" in the corpus so far (never whisper/tell/yell/shout/
-- gossip), but the general form costs nothing to apply everywhere as
-- future-proofing.

-- 2026-07-11: real bug found and fixed, root-caused from Steven's report
-- of a recurring stray "S" line and duplicate chat lines. This file's OWN
-- comments already documented the real native pattern as fully anchored
-- ("^\a?You tell .+\s+'.*'$"), but every route() call here was UNANCHORED
-- (no leading "^") and used a quote-CROSSING ".+" for the prefix -- so a
-- pattern like ".+ says[^']*'" could match starting from a "says" that
-- occurs INSIDE a different message's own quoted dialogue, e.g. "<Name>
-- tells you 'watch what she says about it'" matched BOTH the Tells
-- pattern AND the Local "says" pattern. Confirmed via Python re against
-- real and adversarial lines: when a real message matched two `route()`
-- triggers at once, BOTH fired append()+deleteLine() on what was by then
-- an already-half-consumed line -- the second append() grabs whatever's
-- left after the first deleteLine() (a stray fragment/character), and its
-- own deleteLine() then eats the wrong (next) line. This is the confirmed
-- mechanism for both symptoms. Fixed by anchoring every pattern to line
-- start ("^\a?...") and changing every prefix from ".+" (crosses quotes)
-- to "[^']+"/"[^']*" (stops at the first quote, so a verb word can never
-- be found inside a different message's dialogue). Also merged 3 pairs
-- that were separately matching the exact same real text even without any
-- quote-crossing involved (both same-tab, so the wrong-tab risk was zero,
-- but the double-fire glitch was identical): "gossips"/"clan gossips",
-- "Kingdom: '"/"OOC Kingdom: '", and dropped the redundant bare "ask" from
-- the answers/newbie catch-all since "asks"/"You ask" already covers it
-- (and "ask" is a literal substring of "asks", so it always double-fired
-- alongside it). Re-ran old vs. new against the full 328,643-line clean
-- corpus: old patterns had 15 real lines matching >1 pattern at once
-- (confirmed double-fire triggers, e.g. "Manus says 'Please feel free to
-- ask me...'" hit both Local AND OOC); new patterns: 0. Per-tab counts
-- also came down to real de-duplicated totals instead of double-counting
-- the same line under two patterns (Local 2,999->2,962, City 28->28 once
-- gossips/Kingdom's double-counting was removed, OOC 60->23, Tells
-- 127->125) -- checked each drop individually, all were duplicate counts
-- or genuine cross-category false matches, zero real coverage lost
-- (separately confirmed zero real Kingdom/gossip lines lost -- see that
-- pattern's own comment below for the one regression this caught before
-- it shipped).

------------------------------------------------------------------------
-- TELLS
------------------------------------------------------------------------
-- Native: "^\a?You tell .+\s+'.*'$" / "^\a?.+\s+tells you(?:\s+\([^)]+\))?\s+'.*'$"
-- The leading "\a?" is a real optional BEL control character DSL
-- sometimes prefixes these lines with (confirmed in the native XML,
-- unrelated to any HTML-log extraction artifact).
-- gag=false 2026-07-11 per Steven: wants tells to echo on main console too.
-- "(?!the group)" added 2026-07-17 -- real bug found during the NC
-- regression check: "You tell the group 'yep'" matched BOTH this pattern
-- AND the Group pattern below (this one never excluded "the group"
-- specifically), causing the exact double-fire/stray-fragment bug class
-- the 2026-07-11 anchoring fix was originally built to prevent. Confirmed
-- via corpus: this is the only remaining cross-tab collision, unrelated
-- to the NC change above.
route("Tells", [[^\a?You tell (?!the group)]] .. NC .. [[*']], false)
route("Tells", [[^\a?]] .. NC .. [[+ tells you]] .. NC .. [[*']], false)

------------------------------------------------------------------------
-- GROUP CHAT
------------------------------------------------------------------------
-- Native: "tells the group" / "You tell the group" -- not "group-says"/
-- "group-tells you" as originally guessed; that guess never matched
-- anything because the verb itself was wrong.
route("Group", [[^\a?]] .. NC .. [[+ tells the group]] .. NC .. [[*']])
route("Group", [[^\a?You tell the group]] .. NC .. [[*']])

------------------------------------------------------------------------
-- OOC
------------------------------------------------------------------------
-- Native: "Name OOC: 'message'" -- not a "[OOC]" bracket tag as
-- originally guessed; there never was a bracket tag to find.
route("OOC", [[^\a?]] .. NC .. [[+ OOC:]] .. NC .. [[*']])

------------------------------------------------------------------------
-- CITY  (gossip family -- broad, non-language-restricted public channels)
------------------------------------------------------------------------
-- "gossips"/"clan gossips" merged into one pattern 2026-07-11 -- same tab,
-- and "clan gossips" always double-fired both (see file header note).
route("City", [[^\a?]] .. NC .. [[+ (?:clan )?gossips]] .. NC .. [[*']])
-- Kingdom: native pattern is a literal prefix, not a verb -- "Kingdom: '"
-- / "OOC Kingdom: '" -- not "X kingdom-says:" as originally guessed. No
-- verb here, so no voice/language modifier zone to worry about. Merged
-- into one pattern 2026-07-11 -- same reason as gossips above.
-- CAUGHT DURING THIS SAME FIX: the first anchored version required
-- "Kingdom:" to be the very first thing on the line, but the real corpus
-- (clean_corpus.txt) shows a speaker name always precedes it -- "Sofie
-- Kingdom: 'What kind of swords?'" -- confirmed via a regression check
-- against the full corpus (23 real Kingdom lines, all with a name prefix,
-- zero without). That first version would have silently broken all 23.
-- The optional-name group below covers both the confirmed real
-- with-name form and the original no-name form in case DSL ever omits it.
route("City", [[^\a?(?:]] .. NC .. [[+ )?(?:OOC )?Kingdom: ']])

-- Area/kingdom-named channel -- added 2026-07-17, per Steven ("thaxanos
-- chat to be captured to chat window"), confirmed via a live screenshot
-- (MyDSL profile, standing in "Southern Gate of Thaxanos"): a completely
-- different real format from the "Kingdom: '...'" one above --
-- "(Thaxanos) Wuerthim:  Kraxul, ye around High King?" -- the area/
-- kingdom name itself in parens as a prefix, speaker name, colon, and the
-- message with NO enclosing quotes at all. None of this file's other
-- patterns require a message to end in "'", so this one never matched
-- anything, silently leaving it on the main console. Genericized to any
-- name in parens (not hardcoded to "Thaxanos") since this is presumably
-- one instance of a general per-area/kingdom channel, not literally
-- specific to that one city.
-- NAME (letters/apostrophes/spaces only, no digits/brackets/#/%/-) used
-- for BOTH the parenthetical and the speaker zone, not the generic NC
-- class every other pattern in this file uses -- caught via full-corpus
-- regression: a first, broader version of this pattern (NC-based) also
-- matched container/item-stat lines like "(Fireproof) a bag of holding
-- -[0] -BP Cap: 500# Max: 25# Wghtx: 50%" (real text confirmed in the
-- corpus -- these have their own later colon, e.g. "Cap:"/"Max:", so a
-- permissive middle zone treats the whole item description as a fake
-- "speaker name"). Requiring an actual name-shape on both sides excludes
-- all of those while still matching the one confirmed real chat line.
-- "(?!Imm\))" also excludes this file's one other leading-parenthetical
-- shape, "(Imm) <Name> Bloodbath: '...'", which would otherwise also
-- match. Single-screenshot evidence only (no raw session log exists yet
-- for the new MyDSL profile, and this exact format has zero occurrences
-- anywhere in the older DSL2 corpus either) -- needs Steven's live
-- confirmation like every other unconfirmed item this pass.
local AREA_NAME = [[[A-Za-z][A-Za-z']*(?: [A-Za-z][A-Za-z']*)*]]
route("City", [[^\a?\((?!Imm\))]] .. AREA_NAME .. [[\)\s+]] .. AREA_NAME .. [[:\s+.+$]])

------------------------------------------------------------------------
-- LOCAL  (room-level speech)
------------------------------------------------------------------------
-- says/whispers/yells/shouts all have a "You <verb>" first-person form
-- (no trailing -s) alongside the third-person "Name <verb>s" form --
-- confirmed native, and a real bug in the first rewrite: that version's
-- "\w+ yells .../\w+ shouts ..." patterns required the literal -s form
-- even for "You", so "You yell '...'"/"You shout '...'" never matched.
-- gag=false 2026-07-11 per Steven for say/shout/yell specifically (not
-- whisper -- he didn't ask for that one and it's arguably more private).
route("Local", [[^\a?(?:You say|]] .. NC .. [[+ says)]] .. NC .. [[*']], false)
route("Local", [[^\a?(?:You whisper|]] .. NC .. [[+ whispers)]] .. NC .. [[*']])
route("Local", [[^\a?(?:You yell|]] .. NC .. [[+ yells)]] .. NC .. [[*']], false)
route("Local", [[^\a?(?:You shout|]] .. NC .. [[+ shouts)]] .. NC .. [[*']], false)

------------------------------------------------------------------------
-- OOC  (misc. public channels -- native routes all of these to OOC, not
-- City; the first rewrite guessed City for auctions/grats and dropped
-- the rest entirely)
------------------------------------------------------------------------
route("OOC", [[^\a?]] .. NC .. [[+ auctions:]] .. NC .. [[*']])
route("OOC", [[^\a?]] .. NC .. [[*radios]] .. NC .. [[*']])
-- grats -- native verb, not "congratulates" as originally guessed.
route("OOC", [[^\a?]] .. NC .. [[+ grats]] .. NC .. [[*']])
-- Ask/Answer/Newbie -- native bundles three forms under one destination.
-- CORRECTED 2026-07-17: the 2026-07-11 comment claiming bare "ask" was
-- "a literal substring of asks, already covered" was wrong -- a substring
-- relationship between the WORDS doesn't mean the regex "asks" (which
-- requires the literal "s") matches text that only has "ask". Confirmed
-- via full-corpus check: real third-person "ask" (no -s) is the DOMINANT
-- form in practice (6 real occurrences vs. 1 for "asks"), and every single
-- one was silently uncaptured. Restored as "asks?" (optional trailing s).
route("OOC", [[^\a?(?:You ask|]] .. NC .. [[+ asks?)]] .. NC .. [[*']])
route("OOC", [[^\a?]] .. NC .. [[+ (?:answers|newbie)]] .. NC .. [[*']])
route("OOC", [[^\a?\[Newbie\]: ']])
-- Bloodbath/Quest -- native bundles two forms; not "QUEST:" as guessed.
-- Real format confirmed via log corpus 2026-07-16: "<Name> Bloodbath:
-- 'message'" or "(Imm) <Name> Bloodbath: 'message'" -- name (with optional
-- immortal prefix) always precedes "Bloodbath:", never the reverse, so the
-- old pattern (requiring "Bloodbath:" to start the line) never matched a
-- real message.
route("OOC", [[^\a?(?:\(Imm\) )?]] .. NC .. [[+ Bloodbath:]] .. NC .. [[*']])
route("OOC", [[^\a?]] .. NC .. [[*quests]] .. NC .. [[*']])


------------------------------------------------------------------------
-- PER-CHANNEL GAG/SHOW  (added 2026-08-26, see config.channels' own
-- comment above for the full reasoning)
------------------------------------------------------------------------

local function findChannel(name)
  name = tostring(name or ""):lower()
  for real in pairs(MyDSL.ChatTriggers.config.channels) do
    if real:lower() == name then return real end
  end
  return nil
end

function MyDSL.ChatTriggers.setChannel(name, enabled)
  local real = findChannel(name)
  if not real then
    cecho("\n<red>[ChatTriggers]<reset> Unknown channel: " .. tostring(name)
      .. ". Valid: Tells, Group, OOC, City, Local\n")
    return
  end
  MyDSL.ChatTriggers.config.channels[real] = enabled == true
  cecho("\n<cyan>[ChatTriggers]<reset> " .. real .. "="
    .. (MyDSL.ChatTriggers.config.channels[real] and "gagged (routed to its tab)" or "shown on main console") .. "\n")
end

function MyDSL.ChatTriggers.status()
  cecho("\n<cyan>[ChatTriggers] channel status:<reset>\n")
  local names = {}
  for name in pairs(MyDSL.ChatTriggers.config.channels) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    cecho("  " .. name .. "=<white>" .. tostring(MyDSL.ChatTriggers.config.channels[name]) .. "<reset>\n")
  end
end

MyDSL.ChatTriggers._aliases.channelGag    = tempAlias([[^mydsl channel gag (\w+)$]],  [[MyDSL.ChatTriggers.setChannel(matches[2], true)]])
MyDSL.ChatTriggers._aliases.channelShow   = tempAlias([[^mydsl channel show (\w+)$]], [[MyDSL.ChatTriggers.setChannel(matches[2], false)]])
MyDSL.ChatTriggers._aliases.channelStatus = tempAlias([[^mydsl channel status$]],     [[MyDSL.ChatTriggers.status()]])

debugc("[MyDSL] ChatTriggers loaded.")
