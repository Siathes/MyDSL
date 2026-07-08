-- =============================================================================
-- MyDSL_ChatTriggers.lua  --  Layer 3: Chat channel routing
-- =============================================================================
-- Intercepts chat channel lines and routes them to EMCO tabs via
-- demonnic.chat:append(). Lines are removed from the main console.
-- Must load LAST — demonnic.chat is created by ChatWrapper (position 8).
-- =============================================================================

MyDSL              = MyDSL              or {}
MyDSL.ChatTriggers = MyDSL.ChatTriggers or {}

-- Kill any triggers from a previous load.
MyDSL.ChatTriggers._triggers = MyDSL.ChatTriggers._triggers or {}
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

local function route(tabName, pattern)
  local id = tempRegexTrigger(pattern, function()
    if demonnic and demonnic.chat then
      demonnic.chat:append(tabName)
    end
    -- Restored 2026-07-08 now that routing itself is confirmed working
    -- live (per Steven) -- this is what actually moves the line to the
    -- EMCO tab instead of leaving it duplicated in the main console; not
    -- an EMCO/gag setting, just this file's own not-yet-finished state.
    deleteLine()
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

------------------------------------------------------------------------
-- TELLS
------------------------------------------------------------------------
-- Native: "^\a?You tell .+\s+'.*'$" / "^\a?.+\s+tells you(?:\s+\([^)]+\))?\s+'.*'$"
-- The leading "\a?" is a real optional BEL control character DSL
-- sometimes prefixes these lines with (confirmed in the native XML,
-- unrelated to any HTML-log extraction artifact).
route("Tells", [[\a?You tell [^']*']])
route("Tells", [[\a?.+ tells you[^']*']])

------------------------------------------------------------------------
-- GROUP CHAT
------------------------------------------------------------------------
-- Native: "tells the group" / "You tell the group" -- not "group-says"/
-- "group-tells you" as originally guessed; that guess never matched
-- anything because the verb itself was wrong.
route("Group", [[\a?.+ tells the group[^']*']])
route("Group", [[\a?You tell the group[^']*']])

------------------------------------------------------------------------
-- OOC
------------------------------------------------------------------------
-- Native: "Name OOC: 'message'" -- not a "[OOC]" bracket tag as
-- originally guessed; there never was a bracket tag to find.
route("OOC", [[\a?.+ OOC:[^']*']])

------------------------------------------------------------------------
-- CITY  (gossip family -- broad, non-language-restricted public channels)
------------------------------------------------------------------------
route("City", [[\a?.+ gossips[^']*']])
route("City", [[\a?.+ clan gossips[^']*']])
-- Kingdom: native pattern is a literal prefix, not a verb -- "Kingdom: '"
-- / "OOC Kingdom: '" -- not "X kingdom-says:" as originally guessed. No
-- verb here, so no voice/language modifier zone to worry about.
route("City", [[Kingdom: ']])
route("City", [[OOC Kingdom: ']])

------------------------------------------------------------------------
-- LOCAL  (room-level speech)
------------------------------------------------------------------------
-- says/whispers/yells/shouts all have a "You <verb>" first-person form
-- (no trailing -s) alongside the third-person "Name <verb>s" form --
-- confirmed native, and a real bug in the first rewrite: that version's
-- "\w+ yells .../\w+ shouts ..." patterns required the literal -s form
-- even for "You", so "You yell '...'"/"You shout '...'" never matched.
route("Local", [[\a?(?:You say|.+ says)[^']*']])
route("Local", [[\a?(?:You whisper|.+ whispers)[^']*']])
route("Local", [[\a?(?:You yell|.+ yells)[^']*']])
route("Local", [[\a?(?:You shout|.+ shouts)[^']*']])

------------------------------------------------------------------------
-- OOC  (misc. public channels -- native routes all of these to OOC, not
-- City; the first rewrite guessed City for auctions/grats and dropped
-- the rest entirely)
------------------------------------------------------------------------
route("OOC", [[\a?.+ auctions:[^']*']])
route("OOC", [[radios[^']*']])
-- grats -- native verb, not "congratulates" as originally guessed.
route("OOC", [[\a?.+ grats[^']*']])
-- Ask/Answer/Newbie -- native bundles three forms under one destination.
route("OOC", [[\a?(?:You ask|.+ asks)[^']*']])
route("OOC", [[\a?.+ (?:ask|answers|newbie)[^']*']])
route("OOC", [[\[Newbie\]: ']])
-- Bloodbath/Quest -- native bundles two forms; not "QUEST:" as guessed.
route("OOC", [[Bloodbath: ']])
route("OOC", [[quests[^']*']])

debugc("[MyDSL] ChatTriggers loaded.")
