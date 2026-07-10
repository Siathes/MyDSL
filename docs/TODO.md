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
- [ ] CharacterAssist: rearm (weapon+shield), spellup/setspell,
      blind-vision check
- [ ] Equipment capture — `eq`/`equipment` populates `MyDSL.State.equipment`
      (not built yet — real `eq` text format confirmed via logs 2026-07-08,
      ready whenever this gets picked up)
- [ ] `MyDSL_RawCapture.lua` — still needs its `dofile()` entry added
      (see LOW PRIORITY above) before this can be tested at all
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

---

## TOP PRIORITY — Combat, needs live-fight testing
Fixed in code, none of it confirmed against a real sustained fight yet:
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
- [ ] Weapon-flag proc attribution via `last_attacker`/`last_target`/`last_noun`
- [ ] Quoted weapon names (`"Nadrik's Honor"`) — checked the corpus
      2026-07-09, zero real occurrences of a quoted weapon name in an
      actual combat line found (only false positives: a shop-name
      description, unrelated debug text). The damage trigger's capture
      groups genuinely don't include `"` in their character class, so
      this is a plausible latent bug if such a name ever comes up in a
      real fight, but there's no real text to verify the fix against yet
      — not guessing at a pattern with zero corpus evidence, per this
      project's established discipline.
- [ ] PNP-faithful display rewrite (per-swing live feed, round-summary to
      main, `mydsl combat mode raw|condensed|gag`)

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
- [ ] `procUnholy` ("unholy wrath race"), `procManaSelf` ("drawing your
      energy away") — still zero occurrences found anywhere, including
      the full sibling-profile scan.
- [ ] combatSense1/2 (sense-based evasion) — still zero occurrences found
      anywhere; also absent from PNP source, can't tell if real-but-rare
      or invented.
- [ ] `A.ids.triggers.song` (AffectsView "Song:" format) — prior
      "confirmed" matches turned out to be pre-DSL2 log data; not
      re-checked against the sibling-profile logs this pass.
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

## OPEN — Reported bugs, not yet fixed
- [ ] **Quiet-mode prompt gag failure — REOPENED 2026-07-09, misread
      Steven's confirmation.** Original bug (2026-07-08): quiet mode
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
      formats. **Still need**: a fresh log from an established character
      (Kien/Vrokt/Qinrathaz) to actually confirm the original long-format
      fix works live.
- [x] **GroupView not populating — confirmed fixed 2026-07-07, per Steven
      live.** "groupview works, there have been many edits since that bug
      report." Not independently isolated to one specific fix — resolved
      as a side effect of everything else touched this session.
- [ ] **EMCO chat bug (the "S"/duplicate-line issue) — REOPENED
      2026-07-08, closed prematurely.** Closed same-day on Steven's live
      impression ("i see no problems now" / "is resolved"). While
      investigating the (unrelated) RightHere-on-look bug in the same
      session, directly checked the actual chat log instead of taking the
      confirmation at face value: **`log/MyDSL_EMCO_Chat/2026/07/08/
      All.html` shows 54 standalone "S" lines and 25 consecutive duplicate
      lines across just 153 total segments in this one file** — both
      still active right up through the most recent entries. Needs a
      fresh live check: is the duplicate chat-trigger set Steven deleted
      actually gone for good, and is this possibly two genuinely
      different causes (S only ever seen after OOC-family lines;
      duplicates only ever seen on gossip/tells/group/says) rather than
      one shared root cause. **Tried switching `route()` from `append()`
      to `decho()` with a directly-captured line — reverted per Steven**
      ("revert the decho, that was not what i was try to convey... i do
      not want to modify the chat till ive had more time to test it").
      `route()` is back to the original `append()` + `deleteLine()` form
      (the `deleteLine()` restoration itself is confirmed correct/needed
      and unaffected by the revert). **Confirmed 2026-07-08 unrelated to
      the "follower extra line" bug** (that turned out to be the already-
      fixed RightHere-on-look blank-line bug above, not a chat issue —
      see that entry). Holding off on any further chat changes until
      Steven has tested the current reverted state and reports back. One
      option for later, not yet implemented: EMCO's own native gag-list
      mechanism (`emco gag <pattern>`) could potentially suppress the
      artifact directly without touching `route()` at all, once its
      exact shape is confirmed.
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
- [ ] **AffectsView "missing" list treats `stealth` like a trackable
      spell.** Confirmed real mismatch (unlike `riot`, which is fine):
      `stealth` is a %-based skill with no "Spell: stealth" duration line,
      so it can never register "active" the way armor/riot/bless do.
      Decision needed: drop it from the tracked/spellup list, or build a
      separate %-skill active-detection path.
- [ ] **GroupView Heal button needs to pick the right tier.** Confirmed
      real hierarchy: `cure light → refresh → cure serious → cure
      critical → heal → mass healing` (`cast '<spell>' <char>`). Needs a
      "does this character know spell X" detection approach before the
      button can auto-pick the highest tier a follower actually knows.
- [ ] **TargetView murder-button alternate-command option** (e.g. waylay
      instead of murder for PvP-style openers, "for vrokt as example").
      Needs a design call: dropdown vs. long-press vs. a saved
      per-character opener command.
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
