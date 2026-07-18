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
-- `gag` defaults to true (route to the tab AND remove from main console,
-- the original behavior). Pass false to still route to the tab but leave
-- the line visible on the main console too -- added 2026-07-11 per
-- Steven ("want says, tells, shouts, yell to echo and not be gagged").

local function route(tabName, pattern, gag)
  local id = tempRegexTrigger(pattern, function()
    if MyDSL and MyDSL.Chat and MyDSL.Chat.emco then
      MyDSL.Chat.emco:append(tabName)
    end
    -- Restored 2026-07-08 now that routing itself is confirmed working
    -- live (per Steven) -- this is what actually moves the line to the
    -- EMCO tab instead of leaving it duplicated in the main console; not
    -- an EMCO/gag setting, just this file's own not-yet-finished state.
    if gag ~= false then deleteLine() end
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
route("Tells", [[^\a?You tell [^']*']], false)
route("Tells", [[^\a?[^']+ tells you[^']*']], false)

------------------------------------------------------------------------
-- GROUP CHAT
------------------------------------------------------------------------
-- Native: "tells the group" / "You tell the group" -- not "group-says"/
-- "group-tells you" as originally guessed; that guess never matched
-- anything because the verb itself was wrong.
route("Group", [[^\a?[^']+ tells the group[^']*']])
route("Group", [[^\a?You tell the group[^']*']])

------------------------------------------------------------------------
-- OOC
------------------------------------------------------------------------
-- Native: "Name OOC: 'message'" -- not a "[OOC]" bracket tag as
-- originally guessed; there never was a bracket tag to find.
route("OOC", [[^\a?[^']+ OOC:[^']*']])

------------------------------------------------------------------------
-- CITY  (gossip family -- broad, non-language-restricted public channels)
------------------------------------------------------------------------
-- "gossips"/"clan gossips" merged into one pattern 2026-07-11 -- same tab,
-- and "clan gossips" always double-fired both (see file header note).
route("City", [[^\a?[^']+ (?:clan )?gossips[^']*']])
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
route("City", [[^\a?(?:[^']+ )?(?:OOC )?Kingdom: ']])

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
route("Local", [[^\a?(?:You say|[^']+ says)[^']*']], false)
route("Local", [[^\a?(?:You whisper|[^']+ whispers)[^']*']])
route("Local", [[^\a?(?:You yell|[^']+ yells)[^']*']], false)
route("Local", [[^\a?(?:You shout|[^']+ shouts)[^']*']], false)

------------------------------------------------------------------------
-- OOC  (misc. public channels -- native routes all of these to OOC, not
-- City; the first rewrite guessed City for auctions/grats and dropped
-- the rest entirely)
------------------------------------------------------------------------
route("OOC", [[^\a?[^']+ auctions:[^']*']])
route("OOC", [[^\a?[^']*radios[^']*']])
-- grats -- native verb, not "congratulates" as originally guessed.
route("OOC", [[^\a?[^']+ grats[^']*']])
-- Ask/Answer/Newbie -- native bundles three forms under one destination.
-- Bare "ask" dropped from the second pattern 2026-07-11 -- it's a literal
-- substring of "asks", already covered by the first pattern, and always
-- double-fired alongside it (see file header note).
route("OOC", [[^\a?(?:You ask|[^']+ asks)[^']*']])
route("OOC", [[^\a?[^']+ (?:answers|newbie)[^']*']])
route("OOC", [[^\a?\[Newbie\]: ']])
-- Bloodbath/Quest -- native bundles two forms; not "QUEST:" as guessed.
-- Real format confirmed via log corpus 2026-07-16: "<Name> Bloodbath:
-- 'message'" or "(Imm) <Name> Bloodbath: 'message'" -- name (with optional
-- immortal prefix) always precedes "Bloodbath:", never the reverse, so the
-- old pattern (requiring "Bloodbath:" to start the line) never matched a
-- real message.
route("OOC", [[^\a?(?:\(Imm\) )?[^']+ Bloodbath:[^']*']])
route("OOC", [[^\a?[^']*quests[^']*']])

debugc("[MyDSL] ChatTriggers loaded.")
