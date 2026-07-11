# DSL Observer UI — TODO
*A current punch list only — resolved/historical items live in `CHANGELOG.md`
and git history, not here. Restructured 2026-07-06; pruned 2026-07-07 after
it grew back to 1300+ lines of resolved-item essays (see CHANGELOG for both).*

**Feature creep is paused as of 2026-07-07, per Steven** — bug fixes, live
confirmation, and finishing already-scoped work only. Nothing under
DEFERRED gets started without an explicit go-ahead.

---

## LOW PRIORITY — 1 module still not wired into Mudlet's load sequence
Found 2026-07-07 via `mydsl test`: `ChatTriggers`, `CharacterAssist`,
`Roller`, `RawCapture` had no `dofile()` Script entry at all (confirmed via
`current/autosave.xml` — every other module has one, these didn't), so
they'd never actually executed despite being correct, committed code. This
directly caused a real symptom: a clan-gossip line printed to the main
console but never reached any EMCO chat tab, since `MyDSL_ChatTriggers.lua`
wasn't running.
**Resolved 2026-07-08 for 3 of the 4** — Steven added the Script entries
for `ChatTriggers`, `CharacterAssist`, and `Roller` (confirmed via
`current/autosave.xml`). Nothing critical remains blocked on this.
**`MyDSL_RawCapture.lua` — fully confirmed saved to disk 2026-07-08.**
Screenshot (`Screenshot_20260708_155236.png`) showed it as the very first
item in the whole script tree (above even "Startups"), checked/enabled,
correct `dofile(".../MyDSL_RawCapture.lua")` line. After Steven clicked
"Save Profile" and closed the profile, `current/autosave.xml` *itself*
still didn't show it (stale — see the new gotcha in `CLAUDE.md`'s Key
Paths section) — checking the newest timestamped file in `current/`
instead (`2026-07-08#15-55-17.xml`, saved right after) confirmed
`MyDSL_RawCapture` really is there, first in the tree, `dofile()` count
24 (up from 23). Fully done — nothing left blocking on the script-wiring
front.

---

## NEEDS LIVE CONFIRMATION
Fixed in code, verified via syntax checks and/or the emulation test harness
(`test/mudlet_mock.lua`) — none of this is closed until Steven confirms it
in-game. Full technical detail for any of these: `git log --oneline` +
`docs/CHANGELOG.md`.

- [x] Logging defaults rework — `mydsl log <category> on` re-enables a
      debug-only window's log file. **Confirmed live 2026-07-09**: Steven
      ran `mydsl log righthere on`, then `look`/`scan` a few times —
      verified `MyDSL/logs/righthere/Qinrathaz/2026-07-09.log` was
      correctly written with matching content (including count badges)
      — closing.
- [ ] AffectsView countdown paces correctly in real time; near-expiry color
      warning fires
- [ ] **Timer consolidation + Improve live countdown — implemented
      2026-07-11, needs live confirmation.** Per Steven: "is there a way to
      have all timers run off the tick bar?" and "improve timer not
      counting down." Audited every `tempTimer(` call across the whole
      profile — found exactly 2 self-perpetuating timer loops total:
      TickSource's own 0.25s `T.loop()` (needed for TickView's smooth
      progress-bar animation, left untouched) and MoonWeather's completely
      separate `tempTimer(1, loop)` clock chain. Added a new
      `MyDSL.Timers.Slow` event, throttled to 1/sec inside
      `T.updateTimer()`, and moved every listener that only ever displays
      whole-second/whole-minute values onto it: AffectsView's redraw
      (was redrawing 4x/sec via `MyDSL.Timers.Updated` for a countdown that
      only ever shows whole seconds), LiveView's `render()` (same issue,
      found while auditing), and MoonWeather's clock (deleted its own
      separate `startClockTimer()`/`stopClockTimer()` timer chain entirely
      — now just listens to the shared event, same visible cadence). Also
      built the actual "improve timer not counting down" fix: DSL's real
      `improve` status line ("You are currently improving X (N%). (M
      online minutes to improvement)" — see `DSL_Helpfiles/improve
      improvement.txt`) is a countdown to the *next* percentage tick, not a
      static label, but the LiveView Improve bar just froze at whatever `M`
      was last read. New `improveLiveText()` in `MyDSL_LiveView.lua`
      recomputes the remaining time live from elapsed real seconds (`os.
      time() - last_updated`) — "online minutes" is wall-clock time
      connected, not a DSL server-tick interval, so this deliberately does
      NOT use TickSource's tick-average conversion (that would be the wrong
      quantity). Now ticks down smoothly via the same 1/sec heartbeat.
      **Bonus real bug found and fixed while auditing this same plumbing**:
      `MyDSL_DataBridge.lua`'s `sync()` was unconditionally rebuilding
      `MyDSL.DB.tick` from `MyDSL.State.tick` (which only ever holds a
      `time` string, never `remaining`/`average`/`percent`) on every
      sync() call — including sync() calls fired by the very same
      `gmcp.tick` event TickSource itself reacts to, so TickSource's
      correctly-smoothed average was getting clobbered back to a bare
      `40` default immediately after being computed, on every real tick.
      Fixed by making DataBridge alias the already-correct `MyDSL.DB.tick`
      (TickSource is the sole authority for it) instead of rebuilding it.
      This one directly explains erratic-feeling countdown behavior, not
      just wasted redraws. Verified via emulation: the 1/sec throttle
      (32 fast pulses -> 8 slow pulses over a simulated 8s span) and the
      live Improve countdown math (both both smooth mid-countdown values
      and the past-due floor-at-zero case) all confirmed correct.
- [ ] **Damage-flag colors now match PNP exactly — fixed 2026-07-11, needs a
      live fight to see it rendered.** Per Steven's note ("change the colors
      of the damage flags to the same as PNP for community recognition"):
      `DAM_INFO`/`FLAG_COLOR` in `MyDSL_DataLayer.lua` used our own
      softer/pastel RGB guesses; read PNP's real `dam_info`/`flag_info`
      tables (`DSL_PNP_Battle.lua`) and `color_table` (`DSL_PNP_Support.lua`)
      and matched every tier/flag to PNP's exact values. Also added
      something we were missing entirely: PNP's GHASTLY-through-UNSPEAKABLE
      tier bakes a letter-by-letter alternating red/white color effect
      directly into the decorated verb (e.g. `UNSPEAKABLE` renders as
      alternating-color individual letters), which our old flat-single-color
      version never did. New `alternateLetters()` helper builds this at load
      time; both `calcDamVerb()` (round-summary) and `parseCombatDamageLine()`
      (per-swing feed) now use it via a new `info.decorated` field when
      present. Verified via the emulation harness: `UNSPEAKABLE` renders the
      correct alternating `<255,0,0>`/`<192,192,192>` sequence, ordinary
      tiers (e.g. `hit`) render PNP's green. Needs a live fight to confirm
      visually.
- [ ] CharacterAssist: rearm (weapon+shield), spellup/setspell,
      blind-vision check
- [ ] **Equipment capture — corrected 2026-07-11, was stale.** This item
      said "not built yet" but `MyDSL.beginEquip()`/`parseEquipLine()`/
      `endEquip()` (`MyDSL_DataLayer.lua` Section 9r) are fully
      implemented and wired to the real `"^You are using:$"` trigger —
      apparently built in an earlier pass and never checked off. Verified
      via emulation against the real confirmed corpus format (see the
      section's own comment): slot normalization (`finger1`/`finger2`,
      `wrist1`/`wrist2`, `neck1`), leading flag-parens correctly stripped
      from decorated items (`"(Blue Aura) (Glowing) a Guiding jewel..."`),
      `"(nothing)"` correctly leaves an empty slot, and a stat-block
      parenthetical INSIDE an item's own text (`"a long robe... (W)-1S,2D
      (R) 4Con,2H"`) is correctly NOT mistaken for a leading flag. Needs a
      live `eq` to confirm end-to-end (`MyDSL.State.equipment` isn't
      wired to any display window yet — that part genuinely isn't built).
- [x] `MyDSL_RawCapture.lua` dofile() entry — **stale, removed 2026-07-11.**
      Already confirmed fully resolved in the LOW PRIORITY section above
      (2026-07-08) — this line contradicted that and was never pruned.
- [x] **Roller — confirmed working live 2026-07-09, real duplicate-trigger
      bug found and resolved.** `MyDSL_Roller.lua` (ported 2026-07-07, not
      previously known to be live-tested) and a native trigger literally
      named "roller" were BOTH reacting to every stat-roll line
      independently, each with its OWN separate goal variable
      (`MyDSL.Roller.goal` vs. `mydsl.rollGoal`) that could drift out of
      sync — confirmed via a literal artifact in the log (the native
      trigger's old-style `</cyan>` closing tag doesn't parse in Mudlet
      and leaks out as visible text, showing up duplicated on the first
      ~14 rolls of Steven's test session). If the two goals disagree, one
      trigger can correctly decide "pause" while the other, still on a
      stale goal, decides "reject" and sends `n` anyway — silently
      overriding the pause. Steven independently noticed something was
      off mid-session and manually deleted the native "roller" trigger
      himself (confirmed: its log fingerprint vanishes at exactly that
      point) — from then on `MyDSL_Roller.lua` alone handled every roll
      correctly (clean single-fire, proper reject/pause behavior, verified
      through the rest of the session including a real pause event).
      `set goal <n>` is now the only goal-setting command that matters.
      Session-only, not persisted — resets to the default (241) on a full
      Mudlet restart.
- [x] **RightHere-on-look — rounds 4-6, all confirmed live 2026-07-09.**
      Round 4 fixed a self-retrigger where `lookBody`'s catch-all,
      installed by `lookExits`'s callback while that same "[Exits: ...]"
      line was still being processed, immediately re-fired on that same
      line and closed capture before any content was ever seen — this is
      why the feature had never worked even once in real gameplay before
      this. Round 5 fixed two more bugs a busy-room screenshot test
      surfaced: mob counts never incremented on duplicates (fixed to match
      `parseScanLine`'s pattern), and a floating-dagger item line with no
      "here" anchor was silently dropping everything listed after it.
      Round 6 (2026-07-09) generalized the presence-line safety net a
      third time: `isCharmedStatusLine()` only recognized a literal
      "(Charmed)" tag, but "A dark elven commoner stands around looking
      bored."/"The dark elven scout slips in and out from the shadows
      unheard." (ordinary NPCs, no tag, no "here" anchor) emptied out
      RightHere for that room too. Every confirmed example of this bug
      class has started with an article once tags are stripped, so
      generalized to that shape directly (`isUnparsedPresenceLine()`),
      which subsumes the old Charmed-only check. **Confirmed live** via 7
      screenshots of a busy multi-room gnome corridor: mob counts display
      correctly (`×2`, `×4`, `×5` badges all seen), capture survives
      unparseable NPC lines. Known low-priority gap, still unfixed:
      a handful of proper-named NPCs use non-standard verb phrases with no
      "A/An/The" prefix at all to anchor on ("Sorbus the Hermit is sitting
      here...") — these still end capture early if encountered. Revisit
      only if it turns out to matter live.
      **Round 7 (2026-07-10), real bug found live: leading whitespace
      broke every `^`-anchored check.** Steven's note "the righthere
      window is recording my ch[a]r[a]cter [read: charger, a mount] on
      olyndros" turned out to describe a screenshot showing RightHere
      completely empty in "The Hill-lands," despite the room clearly
      having a charmed mount and 2 hill dwarves. Root cause confirmed via
      the same log: the room's static landmark lines are sometimes
      indented (`"     A twisted and gnarled pine tree grows crookedly
      here."`), and both `parseLookHereLine()` and
      `isUnparsedPresenceLine()` ran their `^`-anchored pattern checks
      against the raw, untrimmed line — the leading spaces meant "A"
      was never at position 1, so every check failed and capture ended
      on the very first indented line, before ever reaching the mount or
      dwarves. `isLookFixtureLine()` never had this problem since its
      checks are unanchored substring matches. Fixed by trimming the line
      before pattern-matching in both functions. Verified via emulation
      against the exact real Hill-lands sequence from the log — all 4
      entities (2 landmark trees, the charmed mount, 2 dwarves collapsed
      to count=2) now captured correctly, capture stays alive throughout.
- [ ] CombatView/History font persistence — `mydsl combat font <n>` /
      `mydsl history font <n>` survive a real restart
- [x] **Action-button color contrast — real root cause found, fixed, and
      confirmed live 2026-07-09.** Steven reported the Rescue/cure-spell
      buttons were "still blue and underlined" despite an earlier
      color-value fix (`120,210,220` etc. already correctly set in
      `TV.actions`). Real bug wasn't the color values — it was
      `dechoLink()`'s `useCurrentFormat` parameter (misnamed `underline`
      by the local helper functions) being passed `false` at every call
      site in `MyDSL_TargetView.lua`/`MyDSL_GroupView.lua`, which tells
      Mudlet to ignore the embedded decho color codes entirely and render
      its own default blue/underlined hyperlink style instead.
      `MyDSL_ScanView.lua`'s RightHere links pass `true` and always
      rendered correctly — that's why only RightHere ever looked right.
      Fixed all 5 call sites to pass `true`. **Confirmed via screenshot**
      (`Screenshot_20260709_172053.png`): the MyDSL_Target window's
      action buttons now show varied colors, not uniform blue/underline
      — closing.
- [x] `considerEasyKill`/`considerNoMatch` text in-game. **Confirmed by
      Steven** ("not sure why this is being tested, but the server sends
      the echo fine") — closing, not an actual issue.
- [ ] **GroupView "follower not showing" — real bug found and fixed
      2026-07-11, needs live confirmation.** Steven's note: "follower not
      showing in group for vaelis (untrained guardhand)." Root cause found
      directly in `log/2026-07-11#07-41-33.html`: DSL right-justifies the
      level in a fixed-width field, so a level-1 member's line reads
      `"[ 1 Mob] An untrained guardhand ..."` (leading space) instead of
      `"[51 War] Olyndros ..."` (no space) — `parseGroupLine()`'s pattern
      required a digit immediately after `[`, so it silently failed to
      match, **not just for the follower but for Vaelis herself too**
      (also level 1, same line shape) — the whole group was empty, Steven
      just noticed the follower's absence first. Fixed with `%s*` after
      `[`. Verified via emulation against the exact real 3-line group
      block (guardhand/Vaelis/a level-51 no-space control line) — all 3
      now parse correctly.

---

## TOP PRIORITY — Combat, needs live-fight testing
Fixed in code; per-swing main-console display now confirmed against a
real fight (2026-07-11, see below) — high-severity color tiers, the
letter-alternating top tier, death-line text, and the round-summary
sentence still haven't shown up in anything logged yet (this was a
low-level fight, nobody died on-screen).
- [x] **Per-swing main-console damage display — CONFIRMED LIVE 2026-07-11,
      real bug found and fixed along the way.** `log/2026-07-11#09-23-09.
      html` (Vaelis, a real fight — untrained guardhand + Vaelis vs. a
      blue jay) shows real lines like `"Your slash scratch Blue jay
      (2.5)"` / `"Blue jay's peck grazes Untrained guardhand (6.5)"` —
      exactly matching `battleFormat()`'s `"%a%r %n %v %t (%d)"` output
      shape, confirming the decorated in-place `replace()`+`decho()` path
      genuinely works end-to-end in a live fight, not just in emulation.
      Condition tracking also confirmed working (`"A blue jay has some
      small wounds and bruises."` appearing repeatedly, correctly parsed
      each time). **Real bug found in the process**: `mydsl combat mode
      raw|condensed|gag` (`MyDSL_CombatView.lua`) never actually touched
      `show_damage`/`show_miss` — only `gag_combat`/`gag_non_damage`/
      `summarize_damage` — but the damage-line show/hide decision in
      `parseCombatDamageLine()` is gated *entirely* by `show_damage`/
      `show_damage_by_me`/`show_damage_to_me`/`show_miss` (confirmed
      directly in PNP source too — `gag_combat`/`gag_non_damage` only ever
      govern evasion/flag/condition lines there, never the damage line
      itself). So "raw" mode's own promise ("every raw swing left
      untouched") was structurally impossible before this fix — it
      behaved identically to "condensed" for the one thing its name is
      about. (The raw swings visible in this session weren't from the
      mode alias at all — no `mydsl combat`-family command was ever typed
      that session per the log; `show_damage` had apparently been left
      `true` in memory from some earlier, untracked toggle, since
      CombatView's config only persists `fontSize` to disk, nothing else
      survives an actual Mudlet restart.) Fixed: `raw` now also sets
      `show_damage=true, show_miss=true`; `condensed`/`gag` now also set
      them `false`. Verified via emulation: all 3 modes now produce the
      correct show/hide decision for both hits and misses.
- [x] **Evasion triggers (dodge/parry/block, you-as-subject aware) —
      verified correct against real corpus text 2026-07-09.** Tested all
      4 trigger patterns (dodge/parry/block/sense) against confirmed real
      lines in both grammar directions — third-person evader ("A gnome
      factory worker dodges your attack.") and you-as-evader ("You dodge
      a gnome factory worker's attack.", including the embedded
      possessive apostrophe) — all matched correctly. No bug found; just
      needs a real live fight to confirm end-to-end state tracking, not a
      code fix.
- [x] **Both death forms (`is DEAD!!` / `hits the ground ... DEAD.`) —
      verified correct against real corpus text 2026-07-09.** Both
      `parseCombatDeathLine` patterns tested directly against confirmed
      real lines from the corpus, both extract the correct name. No bug
      found.
- [x] **Weapon-flag proc attribution via `last_attacker`/`last_target`/
      `last_noun` — verified correct 2026-07-11 via emulation.** Traced
      `parseCombatProcLine()` against PNP's `handle_flag()` directly (even
      found we fixed a real bug in PNP's own source along the way — PNP's
      drowning/freeze guard compares its `flag` parameter to the literal
      string `"freeze"` *after* already reassigning it to the single-letter
      code via `flag_list[flag]`, so that comparison can never be true in
      PNP itself; our version compares the letter code `"C"` directly,
      which actually works). Verified end-to-end via emulation: a damage
      line sets `last_attacker`/`last_target`/`last_noun`, a following proc
      line correctly attaches its flag to both `combat.active[target].
      by_attacker[attacker][noun].flags` and the round-summary
      `round_data` entry, keyed exactly right. **Known inherent
      limitation, confirmed via emulation, NOT a bug**: this is PNP's own
      exact technique — one shared last-event slot, not per-combatant
      tracking — so in a busy multi-combatant fight, if an unrelated
      swing lands between the real cause and its proc echo, the proc
      misattributes to whoever swung most recently instead of the true
      source (reproduced directly: Kien hits the ogre, Bob hits a troll,
      the ogre's fire proc arrives after Bob's swing → flag wrongly lands
      on Bob). This is faithful to PNP, not a regression — fixing it would
      mean diverging from PNP with per-noun tracking, which is real new
      scope, not a bug fix. Flagging for Steven's call, not building it
      unprompted.
- [x] **PNP-faithful display rewrite — confirmed already built 2026-07-11.**
      Traced main-console gag/replace logic and the round-summary flush
      handler directly against PNP's `handle_damage()`/`output_damage()` —
      both are close, deliberate ports (same boolean gate formula, same
      per-swing Combat-window feed, same round-summary aggregation by
      attacker/target pair). `mydsl combat mode raw|condensed|gag` already
      exists (`MyDSL_CombatView.lua:349-360`) and maps directly onto PNP's
      own `gag_combat`/`summarize_damage` flags — PNP's own default
      (`gag_combat=true, summarize_damage=true`) is literally what we call
      "condensed." This item was stale — already done, just never checked
      off.

Confirmed broken, FIXED 2026-07-09:
- [x] **Self-condition never registered — real bug found, fixed, and
      corpus-verified.** DSL phrases your own condition in second person
      ("You have some small wounds", "You are in excellent condition") —
      a different verb conjugation from the third-person form ("has"/
      "is"), which neither our old pattern list nor PNP's own equivalent
      ever matched. Confirmed via corpus for 3 of 7 condition-ladder
      rungs (excellent, few scratches, big wounds — the confirmed
      "have"/"are" self-phrasing); the other 4 have no direct self-
      phrased example in the corpus yet (not enough logged damage taken)
      but were fixed via the same consistent grammatical transformation,
      validated against every rung that DOES have direct evidence. Added
      the self-phrased alternatives to both `CONDITION_PATTERNS` (the
      parsing table) and the `combatCondition` trigger's regex (which
      wouldn't even have fired on these lines before). Verified via
      emulation: all 7 rungs now correctly register against their exact
      real/inferred self-phrased text. Side finding, not fixed: some
      self-condition lines in the corpus had a garbled
      "nasty's...And...(18.5)" suffix that turned out to be **our own**
      severity-score decorator leaking a formatting bug into the log, not
      raw DSL text — separate, smaller issue, not investigated further
      this pass.
- [ ] Itemstat interference with `$`-anchored combat regex — real,
      native-XML system, not conclusively proven to break our triggers.
      Confirmed via live A/B test that it also decorates `eq`/`in` output
      (`-[level] stat,stat` suffix is 100% client-side, not server text).
      `MyDSL_DataLayer.lua`'s equipment parser only gets stat data today
      *because* this system supplies it — if itemstats get disabled before
      Layer 4 ships a replacement, equipment stats silently go blank.
      Sequencing risk to remember when Layer 4 is picked up, not a
      standalone fix.

- [x] **Coliseum location-prefix — investigated 2026-07-09, deliberately
      NOT fixed, closing.** Steven pointed at `log/Archive.zip` and the
      sibling Mudlet profiles' own logs for more combat data. Found:
      every single combat line fought in the Coliseum is broadcast with a
      leading location prefix, e.g. `"[ The Center of the Coliseum ] a
      wild bear's wrath misses Rylae."` — confirmed across dozens of real
      lines in `DSL1/log/2026-06-26#17-54-43.html` and the PNP sibling
      profiles, for both regular damage lines and several procs. Initial
      fix made every `^`-anchored combat/proc/sense trigger tolerate that
      prefix so Coliseum fights would get tracked — **reverted same-day
      per Steven**: Coliseum combat (and the Algoron Combat League event)
      is explicitly out of scope for this regular single-target tracker.
      It's planned as its **own later module** — a large window with 4
      floating sub-windows in the cardinal positions matching the
      Coliseum's wall echoes. The strict `^`-anchor is what naturally
      excludes Coliseum broadcasts today, so it was left as-is on purpose,
      with a comment on `combatDamage` explaining why (so this doesn't get
      "fixed" again without coordinating with that future module). The
      investigation itself is still valuable and kept: confirmed real text
      for 11 procs (see below), and confirmed via Steven that the Sharp
      weapon flag never echoes anything at all (pure damage bonus, no
      trigger text will ever exist for it). Caught and fixed one real
      self-inflicted mistake made mid-investigation: an edit briefly
      deleted the `local DAMAGE_VERBS = "..."` declaration entirely, which
      would have made the whole file fail to load — caught immediately by
      the routine post-edit syntax check, never shipped.
- [ ] **DEFERRED: Algoron Combat League (AGL) / Coliseum combat module —
      new idea, 2026-07-09, not scoped.** Per Steven: Coliseum and AGL
      event combat should be captured separately from regular combat, in
      a large window containing 4 floating sub-windows positioned at the
      cardinal locations matching the Coliseum's wall echoes ("[ Eastern/
      Southern/Northern/Western Coliseum Wall ]" / "[ The Center of the
      Coliseum ]"). Groundwork already exists from this session's
      investigation: the exact bracket-prefix format is confirmed
      (`"[ <location> ] "`), and which trigger patterns/procs apply is
      already cataloged (see the procs entry below) — that work is
      directly reusable here, just inverted: this module would `^`-anchor
      *requiring* the bracket (routing to the 4 sub-windows by which
      location matched) instead of excluding it. Not scoped further —
      needs its own design pass when picked up.
- [x] **Nearly every "unconfirmed" proc — real occurrences found via
      sibling logs 2026-07-09.** 11 of 15 procs confirmed with real text,
      almost all of it bracket-prefixed (direct confirmation the Coliseum
      fix above was needed, not hypothetical): `procFrostFreeze`
      ("freezes"), `procFrostTouch` ("cold touch of"), `procFlameBurn`
      ("is burned by"), `procFlameSear` ("sears your flesh"),
      `procShockLightning` ("is struck by lightning from"),
      `procShockShocked` ("is shocked by a"), `procVampDraw` ("draws life
      from"), `procVampDrain` ("drawing your life away"), `procStun` ("is
      knocked to the ground by"), `procManaDraw` ("draws energy from"),
      `procHolyWrath` ("holy wrath race"), `procHolyFlash` ("flash of
      holy power"), `procPoisonSetup` ("deadly lifebane poison"),
      `procPoisonOnset` ("poisoned by the venom"), and `procPoisonTick`
      ("shivers and suffers") — confirmed across the PNP sibling profiles
      and (poison procs specifically) `DSL1`/`Qinrathaz-Vaelis` directly.
      All trigger patterns matched the confirmed real text correctly.
- [x] Sharp proc — **resolved, not a gap.** Confirmed by Steven 2026-07-09
      (from a Discord question): the Sharp weapon flag just adds bonus
      damage and never echoes anything, so there's no trigger text to
      write, ever. Working as intended — closing.
- [ ] PNP Highlighter's `"[51] Name"` rewrite — confirmed this IS a
      separate mechanism from the Coliseum location-prefix fixed above
      (the two stack together in Highlighter-enabled sibling logs, e.g.
      `"[ Eastern Coliseum Wall ] [51] Melchaleve is shocked by an energy
      storm."`), and it's Highlighter-specific client-side decoration —
      per CLAUDE.md, Highlighter was deliberately never ported to DSL2,
      so this second bracket would never appear in our own real captures
      regardless. No action needed unless that decision changes.

Discuss once combat is confirmed working (deliberately deferred, per
Steven: "make it work like PNP, then discuss the additions"):
- [ ] Whether `renderSummary()`'s persistent "Fight summary" block (our own
      addition, no PNP equivalent) should match PNP's sentence style

---

## PAUSED — needs more captured log data before further progress
Per Steven 2026-07-11: "lets pause the capture logs phase and the
associated issues... we will return to them when we have more data to
scan." These 4 items all hit the same wall — every available log source
on this machine has already been searched (DSL2's own corpus, all 3 PNP
sibling profiles, `DSL1`, `Qinrathaz-Vaelis`, `log/Archive.zip`, and 24
full AGL tournament fight transcripts spanning over a month) with zero
real occurrences of the text needed to confirm a pattern. Not guessing at
patterns with zero corpus evidence — parked here as one group instead of
scattered across sections, so it's easy to re-scan as a batch once
Steven's own gameplay logs/notes bring in new data, rather than
re-litigated piecemeal.
- [ ] **Quoted weapon names** (`"Nadrik's Honor"`) in damage lines — the
      damage trigger's capture groups don't include `"` in their
      character class, a plausible latent bug, but zero confirmed
      examples anywhere of a quoted name attached to a weapon specifically
      (quoted *item* names are a real, confirmed DSL convention otherwise
      — e.g. a potion `"inscribed \"Stoning\""` — just never seen on a
      weapon in any damage line across ~9,000 lines of real fight text).
- [ ] **`procUnholy`** ("unholy wrath race") / **`procManaSelf`**
      ("drawing your energy away") — zero occurrences anywhere. Two
      near-misses found and ruled out, not force-fit: `"Paklop's energy
      drain hits Lohla."` (a regular damage line, "energy drain" is just
      the weapon-noun) and `"Zecnys stops using unholy robes."` (an armor
      name containing "unholy," not the trigger text).
- [ ] **`combatSense1/2`** (sense-based evasion) — the underlying ability
      is confirmed real (`DSL_Helpfiles/danger sense.txt`, bard/bard-
      reclass only), but the exact echo wording is unconfirmed anywhere.
      Likely explanation: bard-only skill, and no bard character has used
      it in any logged session available on this machine. Needs a bard
      specifically playing/logging to ever confirm the real wording — a
      structurally different kind of gap than the others here (needs a
      specific class played, not just more general logs), but same
      "paused pending new data" status.
- [ ] **`A.ids.triggers.song`** (AffectsView "Song:" format) — prior
      "confirmed" matches turned out to be pre-DSL2 log data; not
      re-checked against the sibling-profile logs.

---

## OPEN — Reported bugs, not yet fixed
- [x] **Quiet-mode prompt gag failure — CONFIRMED FIXED 2026-07-11.**
      Original bug (2026-07-08): quiet mode
      prepends a literal `"[Quiet] "` tag to the vitals prompt, breaking
      the native prompt-gag trigger's start-anchored pattern. Gave Steven
      the corrected pattern to paste into the Trigger Editor for the
      native trigger "Gag promt line1" (sic). His reply, "doesnt gag
      prompt now after new pattern added," was misread as confirmation of
      success — on reread it's actually reporting it's *still* not
      gagging. New note 2026-07-09 confirmed it: "The gag1 trigger is
      broken." **Real cause found by reading the live trigger XML
      directly**: the new pattern got *appended* after the old one
      instead of replacing it, producing one garbled regex string —
      `^\[\d+/\d+HP...\]$^(?:\[Quiet\] )?\[\d+/\d+HP...\]$` — two full
      `^...$`-anchored patterns mashed together with no separator, which
      can't match anything sensibly (confirmed live via screenshot: plain
      *and* Quiet-prefixed vitals lines both flooding the main console
      unfiltered). This is a native trigger, not something I can edit
      directly — Steven needs to open "Gag promt line1" in the Trigger
      Editor and **replace** the entire pattern field (not append) with
      just: `^(?:\[Quiet\] )?\[\d+/\d+HP \| \d+/\d+M \| \d+/\d+MV \] \[ .*
      \| .* \| .* \| .* \]$`. Also confirmed via corpus check: only
      `[Quiet]` ever appears as a prompt tag, no separate `[Deaf]` variant
      exists, so this one pattern covers it.
      **2026-07-09 update: Steven applied the replace-not-append fix —
      confirmed correct via the live trigger XML** (`current/*.xml`), a
      clean single pattern, no more duplication. Checked the next
      real-gameplay log (`2026-07-09#17-29-11.html`) — zero long-format
      vitals lines (`[X/Y HP | ...]`) leaked, **but** that whole session
      turned out to be character creation (a brand-new character, never
      reached an existing character's prompt), so this doesn't actually
      prove the fix works — it may just never have been exercised. Real
      finding from that session instead: brand-new/newbie characters use
      a **completely different, shorter prompt format**,
      `"[Quiet] <20hp 100m 100mv>"` (angle brackets, no max values) —
      confirmed leaking unfiltered, 4 times, not covered by "Gag promt
      line1" at all (structurally different shape, same trigger can't
      match both without an alternation). Suggested addition, not yet
      applied (Steven's call whether it's worth it — only affects
      brand-new characters before they set a custom prompt):
      `^(?:\[Quiet\] )?(?:\[\d+/\d+HP \| \d+/\d+M \| \d+/\d+MV \] \[ .* \|
      .* \| .* \| .* \]|<\d+hp \d+m \d+mv>)\s*$` — verified against both
      formats, not yet applied.
      **CONFIRMED LIVE 2026-07-11, closing.** `log/2026-07-11#09-23-09.html`
      (an established character, Vaelis) shows Steven directly testing it
      and leaving himself a marker (`lua cecho("quiet was toggled and
      gagged properly")`, right after toggling `quiet` on) — matches this
      project's established cecho-log-marker convention for flagging
      results as they happen. Independently confirmed via the log itself:
      zero long-format or angle-bracket vitals lines leaked anywhere in
      the full ~2900-line session. Real long-format fix confirmed working
      on an established character at last.
- [x] **GroupView not populating — confirmed fixed 2026-07-07, per Steven
      live.** "groupview works, there have been many edits since that bug
      report." Not independently isolated to one specific fix — resolved
      as a side effect of everything else touched this session.
- [x] **EMCO chat bug (the "S"/duplicate-line issue) — CONFIRMED FIXED
      2026-07-11.** Reopened
      again after Steven reported it recurring ("the extra line S has
      begun to appear again") and asked whether chat should be captured
      via script or "the append demonnic with deleteline." Investigated
      via logs first: `log/MyDSL_EMCO_Chat/2026/07/08/All.html` incidentally
      revealed a real but SEPARATE cosmetic bug — literal `&lt;br&gt;` text
      visible in the HTML log output — traced to vendored
      `EMCOChat/demontools.lua`'s `decho2html()` (inserts a literal `<br>`
      string via `text:gsub("\n","<br>")`, then HTML-escapes the whole
      thing including that literal string). This is vendored-library code
      (`EMCOChat/` — "vendored, unmodified" per project philosophy) and is
      log-file-only, not visible in the live UI, so it's very unlikely to
      be what Steven's actually seeing — noted here but NOT fixed, out of
      scope for the vendored library.
      **The actual live-visible bug**: `MyDSL_ChatTriggers.lua`'s
      `route()` calls were completely UNANCHORED regex (no leading `^`)
      using a quote-CROSSING `.+` for the speaker-name prefix — despite
      the file's own comments already documenting the real native pattern
      as fully anchored (`"^\a?You tell .+\s+'.*'$"`). This meant a verb
      word appearing INSIDE a different message's own quoted dialogue
      could independently match a second, unrelated `route()` pattern —
      e.g. `"Vaelis tells you 'watch what she says about it'"` matched
      BOTH the Tells pattern AND the Local "says" pattern. Confirmed via
      Python `re` against the full 328,643-line clean corpus: **15 real
      lines matched more than one pattern under the old code** (e.g.
      `"Manus says 'Please feel free to ask me...'"` hit both Local and
      OOC), each one causing a double `append()`+`deleteLine()` fire — the
      second fire operates on whatever's left after the first
      `deleteLine()` already ran, which is the confirmed mechanism for
      both a stray fragment/character artifact and an unrelated line
      getting eaten from the main console. Fixed by anchoring every
      pattern to line-start and changing every prefix from `.+` to
      `[^']+`/`[^']*` (can't cross a quote, so a verb can never be "found"
      inside someone else's dialogue). Also merged 3 same-tab pairs that
      were separately double-matching identical real text even without
      any quote-crossing (`gossips`/`clan gossips`, `Kingdom: '`/`OOC
      Kingdom: '`, and dropped a redundant bare `"ask"` from the
      answers/newbie catch-all). **Caught one regression before it shipped
      via the same corpus check**: the first anchored Kingdom pattern
      required "Kingdom:" to be the very first thing on the line, but all
      23 real corpus examples have a speaker name first (`"Sofie Kingdom:
      'What kind of swords?'"`) — fixed to make the name prefix optional
      instead of assumed-absent. Final verification: 0 multi-matches
      across the full corpus (down from 15), 0 lost coverage vs. the old
      patterns. Also answers Steven's architecture question directly: the
      append+deleteLine mechanism already runs through real Mudlet
      triggers (`tempRegexTrigger` creates the same kind of trigger the
      Trigger Editor GUI would, just registered from Lua) — "script vs.
      trigger" wasn't actually the axis the bug was on; "one line matching
      N independent triggers at once" was. Did NOT move to EMCO's own
      native gag-list (`self.gags`/`emco gag <pattern>`) — checked it
      (`EMCO:matchesGag()`, `EMCOChat/emco.lua:1742`) and confirmed it
      only supports plain Lua string patterns (no alternation, no
      lookaround), strictly less expressive than the PCRE these routing
      patterns need (e.g. `(?:You say|X says)`), and it's a suppress-only
      mechanism — it can't route to a *different* tab, only hide a line
      from one. Keeping the current architecture (now fixed) is correct.
      **New, explicitly requested feature also added**: per Steven ("want
      says, tells, shouts, yell to echo and not be gagged"), `route()`
      gained an optional `gag` parameter (default true, unchanged
      behavior) — set to `false` for exactly the say/tells/shout/yell
      patterns he named, so those still route to their EMCO tab but also
      stay visible on the main console. Whisper/group/OOC/city/misc
      channels are untouched (still gagged from main, as before). Verified
      via the emulation harness that `gag=false` skips `deleteLine()`
      while `gag=true` (default) still fires it.
      **CONFIRMED LIVE 2026-07-11, closing.** Checked
      `log/MyDSL_EMCO_Chat/2026/07/11/All.html` (real gameplay, Vaelis) —
      the fix committed at `780d7fe` (09:19:54) landed while this exact
      session was running (main log started 09:23:09, so the reload at
      login picked up the fixed file). All 11 standalone "S" artifacts in
      this log cluster in the file's *pre-fix* portion (before the first
      in-session timestamp, ~08:31:17) — the ~1h45m of continued play
      logged *after* the fix (08:31 through the file's last entry,
      10:16:31) shows **zero** "S" artifacts and zero real duplicate
      lines (one apparent repeat, a merchant NPC's stock "I don't sell
      that" response firing 4 times, is a real in-game repeat with 4
      distinct timestamps, correctly not a duplicate-line bug). Clean
      confirmation the fix works.
- [ ] **Sibling-profile log scan — narrower dead end than first thought,
      corrected 2026-07-09.** The 2026-07-08 scan (checked DSL1/
      Qinrathaz-Vaelis/all 3 PNP profiles for room-presence verb patterns
      by sampling each profile's single *largest* log file) found 95-99%
      debug/framework noise and concluded sibling logs generally weren't
      worth mining. **That conclusion was too broad.** A 2026-07-09
      targeted grep for combat proc phrases across *all* files in those
      same profiles (not just the largest one) found extensive real
      combat text — 11 procs confirmed, plus the real Coliseum
      location-prefix bug (see above). The actual lesson: sampling one
      huge debug-heavy file isn't representative of a whole profile's
      logs; a `grep -r` for a *specific known phrase* across every file
      is cheap and can still pay off, even in profiles that look mostly
      like noise. Worth repeating for other specific phrases in the
      future — just don't expect a manual per-file read-through to be
      productive.
- [ ] **autowhere fires while sleeping** — Steven's own alias, not ours;
      low priority for us specifically.

---

## OPEN — Needs Steven's decision before building
- [x] **AffectsView "missing" list treats `stealth` like a trackable
      spell — resolved 2026-07-11, no code change needed.** Confirmed real
      mismatch (unlike `riot`, which is fine): `stealth` is a %-based
      skill with no "Spell: stealth" duration line, so it can never
      register "active" the way armor/riot/bless do. **Decided per
      Steven: drop it from the tracked list** ("i will remove stealth
      from tracking but this is not a big issue for me") — `stealth` was
      never a code-level default, it's per-character saved data
      (`MyDSL/affects/<Name>.lua`, confirmed present for Vrokt/Kien only)
      that Steven added himself via `mydsl affects track stealth` — the
      matching `mydsl affects untrack stealth` alias already exists
      (`MyDSL_AffectsView.lua:1039`), so this is just a command for him to
      run in-game, not something for me to build.
- [x] **Fully configurable action buttons — built 2026-07-11, per Steven's
      answer to the GroupView-heal/murder-alt-command questions** ("all
      the buttons should be user configurable... even non standard
      commands like scan, look, get item etc... manually be able to set
      all buttons, even the group buttons... there should be a clear
      button and the mob/player toggle"). Turned out most of the mechanism
      already existed (`mydsl target mobset/playerset <6 names>`, a
      mob/player toggle already live as a clickable `[M]`/`[P]` tag,
      `mydsl group quickset <2 names>`) — the real gaps were: (1) every
      button could only reference a name from the fixed `TV.actions`
      Lua-table catalog, no way to define an arbitrary custom command;
      (2) no reset-to-default ("clear button"); (3) GroupView's
      `quickset` had **no persistence at all** — silently reset to
      `{"heal","rescue"}` on every reload/relog, a real bug found while
      implementing this. Added: `MyDSL.TargetView.defineAction()` +
      `mydsl target action <key> "<label>" <color> <command>` (command
      may use `%t` for the target's name, or omit it for stateless
      commands like `scan`) — new actions are stored in
      `TV.config.custom_actions` and merged into the live `TV.actions`
      table every reload, so GroupView's quickset (which already looks up
      the same shared table) gets them for free, no duplicate mechanism
      needed. Added `mydsl target mobset/playerset reset` and `mydsl group
      quickset reset`, all restoring true hardcoded defaults captured in a
      fresh `TV.defaults`/`GV.defaults` table (not derived from the live,
      possibly-already-customized config). Fixed GroupView's missing
      persistence by giving it the same `configFile()`/`loadConfig()`/
      `saveConfig()` pattern TargetView already has (per-character-bound,
      matching every other module). Verified via emulation: stateless and
      `%t`-substituted custom actions both produce the right command,
      reset restores true defaults without mutating the defaults table
      itself, GroupView's quickActions round-trip through reset correctly.
      Needs a live session to confirm the new aliases end-to-end.
- [x] **GroupView Heal button / TargetView murder-alt-command — resolved
      2026-07-11 by the above, not built as originally scoped.** Both
      original questions (spell-tier auto-detection, dropdown/long-press/
      saved-command for an alt verb) are moot once every button is freely
      user-settable — Steven can now just point the Heal button at
      whichever cure tier a character actually knows, or set murder's
      slot to `waylay` directly, no auto-detection machinery needed.
- [x] **Unwired DataLayer capture pipelines — resolved 2026-07-07, per
      Steven** ("i agree with you on all but the improve"). `whok`, `whoc`,
      `unread`, `inv`, `map`, `affectsText` — all 6 fully deleted
      (functions + their `MyDSL.State.*` initializers), no consumer for
      any of them. `improve` was kept and **built**, since
      `MyDSL_LiveView.lua` already had a complete "Improve" bar (color,
      UI element, render call) sitting unused, only waiting on real data:
      - New `MyDSL.parseImproveStatusLine()` in `MyDSL_DataLayer.lua`,
        parsing the real `"You are currently improving <skill> (<pct>%).
        (<mins> online minutes to improvement)"` status line (confirmed
        pattern, see `docs/DSL_CommandRef.md`'s new IMPROVE COMMAND
        section) — a different message from the existing completion-line
        parser, which is now also actually wired to a trigger (neither
        was before).
      - `MyDSL_DataBridge.lua` now maps `MyDSL.State.improve` →
        `MyDSL.DB.improve` (pre-formatted `text` field: `"<skill> <pct>%
        (<mins>m)"`), and listens for the correctly-cased
        `MyDSL.improve.updated` event.
      - `MyDSL_LiveView.lua`: added the correctly-cased event to its
        listener list (`MyDSL.Improve.Updated`, capitalized, never
        matched anything DataLayer actually raises — left in place,
        unused, rather than removed, in case something else depends on
        it; not chased further, out of scope for this pass).
      - User-initiated only, matches philosophy — MyDSL never sends
        `improve` automatically; the bar shows the last snapshot as-is
        between checks, no live-ticking countdown.
      Verified via a full real emulation chain: real captured text →
      `parseImproveStatusLine()` → event → `DataBridge.sync()` →
      `LiveView.data()`/`.render()` — bar text confirmed as
      `"Imp sneak 91% (12m)"`, zero errors. Needs Steven to confirm live
      (type `improve`, check the LiveView Improve bar populates).
- [x] **Four dead-but-registered windows — killed 2026-07-07, per Steven**
      ("kill until we need, I think we have extra code all over").
      `MyDSL_Inventory`/`MyDSL_Equipment`/`MyDSL_AsciiMap`/`MyDSL_Banner`
      removed from `MyDSL_WindowRegistry.lua`'s registry and
      `MyDSL_LayoutEngine.lua`'s default positions. `MyDSL.State.equipment`
      (Phase E's already-tested capture logic) is untouched — only the
      unused window/layout scaffolding was removed, not working data
      capture. Verified via emulation test: 15 windows now register
      cleanly (was 19).
- [ ] **Itemstat trigger retirement timing** — see the combat-section note
      above; just needs sequencing against Layer 4, not a decision now.
- [ ] **"Prompt Line 1" parsing** — not scoped, low priority, likely fully
      redundant with GMCP (`char_data.stance`/`language`/`is_flying`).
      Only worth it if a flag turns up that GMCP doesn't cover.

---

## OPEN — Design ideas, not yet scoped
- [ ] **TargetView: show debuffs cast on the current target.** weaken
      (`"<target> looks tired and weak."`) and slow (`"<target> starts to
      move in slow motion."`) are confirmed and ready to build. blindness/
      poison/plague are confirmed real spells but have **zero** confirmed
      on-target success text in the log corpus — needs a live catch of an
      actual successful cast before their text can be added. No "wears
      off" text confirmed for any of the five yet either.
- [ ] **TargetView: auto-populate target on aura detection** — when
      detect-good/detect-evil shows, auto-set to first opposing-alignment
      mob visible, else first mob not in your own group.
- [ ] **Skills/Spells → Combat window** — echo real skill/spell actions to
      main console + Combat, reduce raw per-swing attack-spam. Real text
      confirmed for waylay/riot/frenzy/swarm/castigation/dragon-roar (see
      `docs/DSL_CommandRef.md`). Warrior/thief skills (kick/bash/trip/
      rescue/circle) still have zero confirmed first-person text anywhere
      in the corpus — a live test with a warrior/thief character would
      close this faster than more log-grepping. Not scoped yet.
- [ ] **Command vocabulary — more IC/human-speak, less `mydsl <module>
      <verb>`.** Design direction, ties into the command-surface retrofit
      below but goes further — not scoped.
- [ ] **Item-clickable reference module** — depends on Layer 4.
- [ ] **Census (from UI) interacting with the reference module** — depends
      on Layer 4.
- [ ] **State-scoped sound toggle** — generic pattern for an alias to turn
      a sound on for a state and reliably turn it off when the state ends
      (e.g. sleep sound), not just a one-off.

---

## OPEN — Command-surface retrofit (held until combat-pass testing confirmed)
Mandate: reuse PNP/EMCO's actual command vocabulary, not just their
internal logic — see `CLAUDE.md` Philosophy section.
- [ ] `toggle <module>` — PNP's real universal on/off alias is already
      live; CombatView/AffectsView/MoonWeather should hook it instead of
      their own `mydsl <module> gag/show` aliases.
- [ ] Combat's extra sub-toggles (`show_miss`/`show_evade`/`show_flag`/
      `show_condition`) have no PNP equivalent — keep a short bespoke form.
- [ ] Scan/Target/Group/CreatureReference are net-new — keep bespoke
      commands, just trim the `mydsl` prefix.
- [ ] `emco save`/`load` likely act on a stale disconnected object (traced,
      not independently re-verified — low priority, requires a command a
      user's never actually typed before).
- [ ] Not checked: whether `mydsl chat` duplicates native `gag`/`lock`/
      `notify`/`title`.

---

## LOW PRIORITY — remaining open gap
- [ ] **ChatWrapper tab active/inactive CSS still hardcoded** — no
      ThemeEngine hookup. Real design pass, not a mechanical fix.

---

## DEFERRED — explicitly held, no new scope without Steven's go-ahead
- [ ] **`MyDSL_PromptSetup.lua` — built 2026-07-09, put down for a later
      addition per Steven.** One-click DSL prompt setup for brand-new
      characters (detects "The Gray Mist of Nothingness" birth cutscene,
      offers a clickable link; `mydsl setprompt` also works standalone).
      Code is written and committed but has no `dofile()` Script entry, so
      it doesn't run yet — needs that added, then a real character-creation
      test, whenever this gets picked back up. Full design writeup
      (anchor choice, why it's a click and not an automatic send): see
      `docs/CHANGELOG.md`, commit `2ec4fb0`.
- [ ] **Cross-profile master function/feature inventory** — walk every
      `.lua` file across every Mudlet profile on this machine and build one
      consolidated list, removing superseded/duplicated functionality.
      Large, multi-session scope — its own future session, not opportunistic.
- [ ] **Layer 4: Reference library** (items, mobs, lore) — not started.
      Check `~/Downloads/Shattered-Archive-release-dev.zip` (open-source
      DSL client/tooling monorepo) before building from scratch.
- [ ] **Mapper hardening/MyDSL integration** — deferred until current UI
      workload finishes. Once picked up: the mapper could be a useful
      backup/cross-check for room identity beyond GMCP's `room_data`.
- [ ] **Data-driven notes/quest tracking** — streamline `notes_utf8.txt`'s
      in-game feature/quest items via data files instead of manual notes.
- [ ] **Consolidate all native Mudlet objects into one package** — per
      Steven 2026-07-08 ("this is why i want to pull all mudlet objects
      into one package so we can troubleshoot cleaner"). Currently
      scattered across `gui-drop`/`mpkg`/`DslColors_v1_0.../`
      `generic_mapper`/`EMCOChat`/`MyDSL_Full` plus loose top-level items
      (`MyDSL_RawCapture`, `Startups`) — a real organizational pain point,
      directly related to this session's `current/autosave.xml` staleness
      gotcha and the "which script is actually running" confusion. Large,
      structural, GUI-driven undertaking — its own future session.

---

## Native Mudlet objects with no MyDSL equivalent yet
Scale (confirmed against `current/autosave.xml`, 28,606 lines): 142
TriggerGroups, 613 Triggers, 43 Scripts, 66 Keys, 25 top-level Aliases, 0
Timers. Real candidates for future integration, none urgent:
- **Random Affects** (11 stat-fluctuation flavor messages), **Spells**
  category notifications, **Weather Conditions** (more granular than our
  keyword regex), **Atmosphere**/AGL/Sailing sub-groups — cosmetic/niche,
  low value.
- **66 native Keys** (movement/scan/look bindings) — raw keybindings, not
  something MyDSL needs to mirror.
- **~20 misc aliases** (`(inv)`, `(autowhere)`, attire-swap sets, etc.) —
  fine as native aliases unless one becomes relevant to a window.

---

## DECISIONS RECORDED
- Most settings (theme, visibility, chat, fonts, TargetView/AffectsView)
  are character-bound (chat/windowstate/Combat font/History font/
  TargetView/AffectsView, confirmed 2026-07-07). **Window layout is the
  one deliberate exception, reverted 2026-07-08 per Steven**: layout is
  per-profile (single shared `MyDSL_layout.lua` + native Qt
  `saveWindowLayout()`), not per-character — after repeated fights with a
  custom per-character percentage-save system, simplicity won out over
  the "everything character-bound" default.
- Themes: user-creatable named presets, shared across all characters
  (intentionally not character-bound).
- `MyDSL_Mapper` removed from WindowRegistry — minimap via
  `map.configs.map_window` only, not a Geyser.UserWindow.
- CharPic compatibility code removed from PortraitView (no DSL1 triggers
  call any `CharPic.*` function).
- RouteHelper `routeMap` removed — shorthand helpers (`Route.history()`
  etc.) are the only API.
- Prompt: toggleable pretty prompt, default ON.
- Day/Night derived from `time` command, not prompt capture.
- Alignment from score only, persists until next score run, no auto-send.
- **Window docking/positioning:** every `Geyser.UserWindow` gets
  `restoreLayout=true` + `autoDock=true` via a single global constructor
  patch (`patchUserWindowConstructor()` in `MyDSL_WindowRegistry.lua`).
  Startup order: `patchUserWindowConstructor()` → `Windows.loadState()` →
  `Windows.ensureAll()` → `loadWindowLayout()`, called exactly once, no
  timers. To persist a layout: `mydsl layout save`; to reset: `mydsl
  layout reset` (doesn't auto-persist).
- `DSL_PNP_Highlighter.lua`/`.custom.lua`, `DSL_PNP_People.lua`,
  `DSL_PNP_Statusbar.*`, and ~20 PNP-client-infrastructure files are
  explicitly out of scope — superseded by the live `DslColors_Core_v1_0`
  native script, GMCP-first PromptView, or Geyser/WindowRegistry/
  LayoutEngine/ThemeEngine already.
- `colors.xml` (profile root) is a stale, unloaded pre-v1.0 DslColors
  snapshot — confirmed safe to leave alone, not worth reviving.
