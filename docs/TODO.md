# DSL Observer UI — TODO
*A current punch list only — resolved/historical items live in `CHANGELOG.md`
and git history, not here. Restructured 2026-07-06; pruned 2026-07-07 after
it grew back to 1300+ lines; pruned again 2026-07-11 after it grew to 1900+
lines (a single TargetView entry alone had ballooned past 500 lines across
10 "rounds" of the same live-debugging conversation — all of that detail is
in `CHANGELOG.md` already, appended in real time as each fix landed). If
this file is turning back into a growing append-only history again, prune
it — don't let it happen a third time.*

**Feature creep is paused as of 2026-07-07, per Steven** — bug fixes, live
confirmation, and finishing already-scoped work only. Nothing under
DEFERRED gets started without an explicit go-ahead.

---

## LOW PRIORITY — script wiring
- [ ] ChatWrapper tab active/inactive CSS still hardcoded — no ThemeEngine
      hookup. Real design pass, not a mechanical fix.
- [ ] `MyDSL_creaturelore.lua` (lowercase, profile root) is stale DSL1
      carry-over data, not a module — superseded by
      `MyDSL/creaturelore_db.lua`. Tracked in git, unused. Confirm with
      Steven before deleting.

---

## NEEDS LIVE CONFIRMATION
Fixed in code, verified via syntax checks and/or emulation — none of this
is closed until Steven confirms it in-game. Full technical detail for any
item: `git log --oneline` + `docs/CHANGELOG.md`.

- [ ] **New: Layer 4 item identification, first slice, built 2026-07-16 —
      dofile() steps confirmed done (inferred live: an error surfaced
      from inside `MyDSL_ItemReference.lua`'s own event handler, which
      only fires if the module loaded and the identify/lore capture
      already worked end-to-end), one real bug found and fixed same day,
      needs a clean live confirmation now.** Real bug: `MyDSL_
      ItemReference.lua`'s `itemKey()` called a bare `trim()` assuming it
      was a shared global -- it isn't; every file in this profile that
      needs `trim()` defines its own local copy (confirmed via grep,
      ~10+ files), and this new file never did. Fixed by dropping the
      trim() call entirely -- confirmed `MyDSL_CreatureReference.lua`'s
      own equivalent normalization doesn't trim either, every real caller
      already passes an already-clean string. Per Steven ("it
      should use the skill lore, and the spell identify to fill a
      database of items stats in game... hover over items for the
      stats?... a bestiary window type for items?" — answer: both).
      New `MyDSL_ItemLore.lua` (persistent DB, directly modeled on
      `MyDSL_CreatureLore.lua`'s proven merge pattern — a later `lore`
      capture can never downgrade an already-`identify`d item back to
      partial, confirmed both by design and by a structural test, since
      `lore`'s own parsed record simply never includes the bonus/enchant
      fields `identify` does). New `identify`/`lore <item>` capture
      state machines in `MyDSL_DataLayer.lua`, patterns validated against
      real captured transcripts (not guessed) via an emulation test
      before touching real data. New `MyDSL_ItemReference.lua` (Item
      Reference window, Bestiary's own pattern, full `item <name>|show|
      hide|status|rebuild|font <n>` family from day one). One-time
      scrape import from `shatteredarchive.com/items/all-items`
      (6,085 unique items after dedup) into `MyDSL/item_scrape_import.lua`
      + `mydsl itemlore import` alias, dry-run validated. Equipment
      listings in the main console now get a hover tooltip (quick stats)
      + click (opens Item Reference) on the item name itself, via
      `selectString()`/`setLink()` — same technique `MyDSL_AffectsView.lua`
      already uses, chosen specifically because it never touches the
      game's own text/color (confirmed decho/cecho reconstruction would
      have discarded the original ANSI coloring). All new/edited files
      syntax-checked via luajit. **Deliberately NOT in this pass**
      (each is a net-new capture pipeline, not a retrofit, comparable in
      size to this whole pass again): inventory (`inv`/`i`) capture +
      hover, room-floor-item capture + hover, and the native 318-item
      `itemstats` table as a supplementary import (needs Steven's help
      decoding its notation first). **Needs Steven to add `dofile(...)`
      Script entries for `MyDSL_ItemLore.lua` and
      `MyDSL_ItemReference.lua`** (same class of step as Help/
      PromptSetup/AutoWhere before them) — neither `identify`/`lore`
      captures nor `item <name>` will do anything until that's done.
- [ ] CharacterAssist: rearm (weapon+shield) — spellup/setspell and the
      blind-vision check are confirmed working (2026-07-15); rearm itself
      hasn't been separately confirmed yet.
- [ ] **New: `MyDSL_AutoWhere.lua`, built 2026-07-16, both manual wiring
      steps confirmed done, needs live confirmation.** Per Steven ("roll
      autowhere into mydsl but improve it so it pays attention to states
      like sleeping, fighting, blind etc (any time it doesnt work)").
      Replaces Steven's native "(autowhere) AutoWhere" alias (plain
      `send("where")` on a fixed 20s timer, no state awareness) — new
      version skips a tick while `MyDSL.State.char.posn == "Sleeping"`,
      `is_fighting == true`, or `MyDSL.CharacterAssist.checkVision() ~=
      "can see"` (reused directly from `MyDSL_CharacterAssist.lua`'s own
      confirmed vision check, exported for this — was `local`, now
      `CA.checkVision()`). Same command vocabulary as the native version
      (`autowhere on|off|status`), same class of user-toggled assistive
      automation as CharacterAssist's rearm/spellup (not a new exception
      to "never send automatic commands" — the player still explicitly
      turns it on). Syntax-checked via luajit. Both manual steps confirmed
      live in `current/2026-07-16#15-38-37.xml`: the `MyDSL_AutoWhere`
      Script entry is `isActive="yes"` (correctly after
      `MyDSL_WindowRegistry`/`MyDSL_ThemeEngine` in the load order), and
      the native "(autowhere) AutoWhere" alias is now `isActive="no"`.
      Ready to actually test in-game. Sleeping/fighting/blind skip
      conditions are per Steven's own direct in-game knowledge, not
      independently log-corpus-confirmed — flag if another state turns
      out to need a skip too.

---

## TOP PRIORITY — Combat, needs live-fight testing
Per-swing main-console display, evasion triggers, both death-line forms,
weapon-flag proc attribution, and the PNP-faithful display rewrite are all
confirmed correct (code review + a real live fight, 2026-07-11) — see
`CHANGELOG.md`. Still open:
- [ ] **DEFERRED, per Steven ("we can wait a bit longer on")**: Algoron
      Combat League (AGL) / Coliseum combat module — new idea, not
      scoped. Coliseum/AGL combat should be captured separately, in a
      large window with 4 floating sub-windows at the cardinal positions
      matching the Coliseum's wall echoes. Groundwork (bracket-prefix
      format, applicable procs) already gathered — see CHANGELOG.
- [ ] **Fight-summary conclusiveness — checked 2026-07-16, per Steven
      ("stat block is fine as long as it reports all combat actions and
      spells/skills used with landing %, just want to be sure its
      conclusive").** Real, evidence-based picture, not a guess:
      - **Confirmed captured, no gap**: any skill/attack whose DSL text
        uses the same "attacker's `<noun>` `<intensity-verb>`s target"
        grammar as regular weapon swings is already captured by the one
        unified `combatDamage` trigger, with the skill name simply
        appearing as the noun — confirmed via real corpus text
        (`log/clog1`): "Coenin's backstab maims Zecnys!" matches this
        shape exactly, so backstab damage already flows into
        `renderSummary()`'s hit/miss/landing-% table today, no special
        handling needed.
      - **Confirmed NOT captured, and genuinely can't be from text
        alone**: skills whose effect isn't a damage line at all (bash's
        knockdown, trip, riot's rage buff, dirt-kick's blindness) —
        checked their real native-XML flavor text, none of it has a
        per-hit damage number in DSL's own output to begin with, so
        there's nothing for a "landing %" to attach to for these.
      - **Genuinely unconfirmed, the one real gap**: whether direct-
        damage offensive spells use this same grammar or something else
        entirely — searched the full `log/` corpus for every attack-spell
        name in this game (shock bolt, firebolt, lightning bolt, magic
        missile, etc.) and found zero real combat-damage examples, only
        inventory/practice-list mentions. Can't confirm this is captured
        OR that it's missing — needs an actual live fight where a damage
        spell gets cast and logged, then a check of whether it shows up
        in the summary afterward. Steven's call to keep the current
        stat-block format stands; this is the one loose end on
        "conclusive," not a redesign question.
- [ ] **Double condition-line echo in combat — fixed 2026-07-16, needs
      live confirmation.** Per Steven ("if its just a duplicate line lets
      not duplicate it," after the item 7 explanation). Confirmed exactly
      why: in condensed mode (the default), `parseCombatConditionLine()`'s
      gag formula (`MyDSL_DataLayer.lua`) never deleted the raw DSL
      condition line specifically BECAUSE `summarize_damage=true` was
      excluded from the delete condition — the assumption being something
      else would hide it, but nothing did, so the round-flush handler's
      own `decho()`'d recap showed up right alongside the untouched
      original. Confirmed via PNP's own source (`DSL_PNP_Battle.lua`
      lines 315/414-415) this exact double-show has always been PNP's
      own original behavior too, not something introduced here — fixing
      it anyway per Steven's explicit call, diverging from PNP on this
      one point. Fix: added `summarize_damage` into the delete
      condition's OR clause, so the raw line is now deleted in condensed
      mode too (only the recap shows). Raw mode is unaffected (nothing in
      its OR clause is true, so nothing gets deleted there — same single
      line as always); `show_condition=true` still overrides and forces
      the raw line to stay, unchanged. Syntax-checked via luajit.

---

## PAUSED — needs more captured log data before further progress
Per Steven: "lets pause the capture logs phase... we will return to them
when we have more data to scan." Every available log source on this
machine (DSL2's own corpus, 3 PNP sibling profiles, DSL1,
Qinrathaz-Vaelis, `log/Archive.zip`, 24 AGL tournament transcripts) has
been searched with zero real occurrences of the needed text — not
guessing at patterns with zero corpus evidence.
- [ ] Quoted weapon names (`"Nadrik's Honor"`) in damage lines — plausible
      latent capture-group bug, zero confirmed real examples of a quoted
      weapon name specifically.
- [ ] `procUnholy`/`procManaSelf` — zero occurrences anywhere; 2 near-misses
      found and ruled out (not force-fit).
- [ ] `combatSense1/2` (sense-based evasion) — real ability (bard-only per
      helpfiles), exact echo wording unconfirmed anywhere. Needs a bard
      specifically playing/logging.
- [ ] `A.ids.triggers.song` (AffectsView "Song:" format) — prior
      "confirmed" matches turned out to be pre-DSL2 log data.
- [ ] Mage-cast `poison` spell's onset text — one unconfirmed candidate
      line spotted (`"...looks very ill."`), not enough occurrences to
      confirm vs. coincidence.

---

## OPEN — Reported bugs, not yet fixed
- [ ] **Sibling-profile log scanning** — a targeted `grep -r` for a
      specific known phrase across every file in a sibling profile can
      still pay off even when the profile looks mostly like debug noise;
      sampling one large file isn't representative. Worth repeating for
      other specific phrases if this comes up again.
- [ ] **Fuzzy name-matching (mob ID + item ground-mapping) — built
      2026-07-16, needs live confirmation.** Ported the tolerant-matching
      technique found in the Shattered Archive client's own equipment
      code (`useEquipmentDeltas.ts`): normalize both sides (strip leading
      article, ground-sentence suffixes, punctuation), score exact=100 /
      substring-either-direction=50, and refuse to pick a winner on a tie
      — a false merge is worse than no match. Added as
      `normalizeForMatch()`/`bestFuzzyMatch()` in `MyDSL_DataLayer.lua`
      (right before `resolveMobName()`), shared by two callers:
      - **`resolveMobName()`** (mob ID in RightHere/CreatureLore) — used
        to be exact-key-only, so a generic/truncated `look` capture (e.g.
        "a gnome" from "A gnome is here using levers...") could never
        resolve to a fuller CreatureLore-known name ("gnome machinist")
        since those are different keys. Now tries the current room's own
        `scan.byName` capture first (small, same-room-visit, least
        collision risk — matches Steven's own example exactly), then
        falls back to the full CreatureLore DB.
      - **`MyDSL.resolveGroundItem(key)`** (new) — ItemLore's counterpart.
        Requires two new capture pipelines that didn't exist before this:
        ground-item storage (`MyDSL.captureGroundItem()`, wired into
        `beginLook()`'s fixture-line branch — these lines used to be
        skipped and discarded, never stored) and inventory capture
        (`MyDSL.beginInventory()`/`parseInventoryLine()`/`endInventory()`,
        triggered on `"You are carrying:"`, same begin/body/end shape as
        equip capture — inventory capture didn't exist at all before this).
        Checks ItemLore's own DB by exact key first, then fuzzy-matches
        against every known equipment slot + inventory item.
      Verified via a structural test harness (`test/mudlet_mock.lua` +
      the real functions): mob resolution correctly resolves "a gnome" to
      "a gnome machinist" via scan.byName; inventory capture correctly
      parses counts/flags/plain lines; ground-item capture correctly
      stores items previously only skipped; `resolveGroundItem()`
      correctly matches "a decanter of endless water" against the
      inventory candidate and correctly declines to match "a mallet used
      to shape metal" against "a shaping mallet" (no shared substring —
      the honest "best effort, not everything" behavior Steven asked
      for). Not yet wired into any display/hover UI — this is the
      resolver only. Syntax-checked.
- [ ] **RightHere silently dropping mobs listed after an uncovered
      item-flavor-text line — fixed 2026-07-16, needs live confirmation.**
      Found via a structural trace of a real room-look
      (`log/2026-07-16#17-23-54.html`), same recurring bug class fixed
      three times before (2026-07-08/09) for different sentence
      templates. `beginLook()`'s catch-all falls through
      `isLookFixtureLine()` -> `parseLookHereLine()` ->
      `isUnparsedPresenceLine()` -> (lowercase-start wrapped-continuation
      check) -> `endLook()`. A line like `"This studded mace looks
      particularly dangerous."` matches none of the first three (all
      require "A"/"An"/"The" or a lies/lying/left/floats keyword) and
      isn't lowercase either, so it hit `endLook()` and would have
      silently dropped everything listed after it in that room —
      confirmed via a structural test harness this would have included a
      war mage and 3 novice mages at the end of the same listing. Fixed
      the same way the last three rounds were: broadened
      `isUnparsedPresenceLine()` to also treat lines starting with "This "
      as a skippable presence line (mirrors the existing "A"/"An"/"The"
      check exactly). Verified via a harness feeding all 43 real lines
      from the log through the actual trigger chain — capture stays
      active start to finish, and both the war mage and all 3 novice
      mages land in the final `rightHere` table. Syntax-checked. (Note,
      not fixed, pre-existing and out of scope: several item-flavor lines
      that DO reach `parseLookHereLine()`'s broad fallback end up tagged
      `is_mob=true` since `isMobName()` only checks for a leading
      article — a known, already-documented trade-off in this code, not
      something new.)
- [ ] **Murder/Consider/Order-All → "They're not here" — fixed 2026-07-16
      (item 6 of Steven's "6/7 we can look into" → "proceed"), needs live
      confirmation.** Real cause: identical mobs in a room collapse into
      ONE RightHere entry with a `count` field (`parseLookHereLine()`,
      `MyDSL_DataLayer.lua`), and nothing ever decremented/cleared it when
      a mob in it died mid-fight — not room-change staleness (confirmed
      `beginLook()` already clears `scan.rightHere` fresh on every room
      redisplay), mid-fight staleness instead, persisting as long as the
      player hasn't re-looked since a kill. Found the exact hook already
      built for this: `parseCombatDeathLine()` already raises a dedicated
      `"MyDSL.combat.died"` event with `{key, name}`, added 2026-07-11 so
      Focus could auto-advance/clear its target on death — but RightHere
      itself never listened for it. Added a listener in
      `MyDSL_ScanView.lua`'s `SV.init()`: decrements `count` if >1, else
      clears the entry entirely, then re-renders. Doesn't disambiguate
      WHICH of several identical mobs died (RightHere has no per-instance
      tracking, only a count) — decrements whichever entry's key matches,
      which is the best available fix without a bigger redesign of how
      RightHere stores duplicates. Syntax-checked via luajit.
- [ ] "multiple mob health echoes in combat... one we create and one from
      the game" — see the "Double condition-line echo" item in the
      Combat section above; fixed 2026-07-16, same discussion.
- [ ] **Affects window: top row not clickable to recast — fixed
      2026-07-16, needs live confirmation.** Reported by Steven ("top 2
      affect lines not clickable, 2nd line and below work"). Root cause:
      `A.applyLinks()`'s window-scan loop (`MyDSL_AffectsView.lua`) started
      at `index = 1`, a value ported verbatim from PNP's own
      `make_links()` (`PNP files/DSL_PNP_Affects.lua`) — but PNP's
      renderer prints a leading blank line + header row before any real
      content (so PNP's row 0 is blank, `index=1` harmlessly starts on
      the header). MyDSL's `A.display()` has no such header — `clearWin()`
      is immediately followed by the first real affect row, so row 0 IS
      content. Starting at 1 skipped it; with the default 2-column layout
      that's the first two affects. Fixed: `index = 0`. Syntax-checked.
- [ ] **Bloodbath chat never routed — fixed 2026-07-16, needs live
      confirmation.** `MyDSL_ChatTriggers.lua`'s pattern required
      "Bloodbath:" to start the line (`^\a?Bloodbath: '`); real format
      (confirmed via log corpus) is always `<Name> Bloodbath: 'message'`
      or `(Imm) <Name> Bloodbath: 'message'` — name always precedes the
      verb, same shape as every other channel in this file. Fixed to
      `^\a?(?:\(Imm\) )?[^']+ Bloodbath:[^']*'`, matching the established
      style. Syntax-checked.
- [ ] **`setspell` bare-command gives no usage feedback — fixed
      2026-07-16, needs live confirmation.** Confirmed Steven's exact
      case (2026-07-16): bare `setspell`, no args. Added
      `CA._aliases.setSpellUsage` (`^setspell$`) calling
      `setSpellInfo()` with no args, which already has a real usage
      message (`ce("usage: setspell <bless|fireproof> <spell|wand|
      skill> [name]")`) for malformed input — just wasn't reachable for
      the zero-arg case before. Syntax-checked.
- [ ] **Item Reference window sizing/position** — Steven wants it
      compact, docked top-left corner; currently renders correctly
      (confirmed via screenshot) but as a tall left-side tab alongside
      Scan/Combat/Bestiary, larger than desired.
- [ ] **Inventory hover — scope expansion, reverses the plan's original
      "equipment only" deferral.** Steven: "you should be able to hover
      over inventory items not just equipment... just worn or inventory I
      think is fair" (ground-item identification explicitly still out of
      scope).
      **Ground-vs-inventory name mapping — answered empirically
      2026-07-16, not built yet.** Steven asked directly whether there's
      "a way to map the ground description and inventory description with
      no real connection." Found a real answer key in
      `log/2026-07-16#17-23-54.html`: a `get all` / `drop all` / `look`
      sequence lists ~30 items' bare inventory name immediately next to
      their room ground-sentence for the same item. Result: roughly 2/3
      have a clean substring match once the sentence wrapper is stripped
      (`"a decanter of endless water"` <-> `"A decanter of endless water
      lies here."`), but a real fraction have no shared substring at all
      — the ground text is sometimes an independently-written
      description: `"a bag of holding"` -> `"A strange bag lays here..."`;
      `"a shaping mallet"` -> `"A mallet used to shape metal..."`; `"a
      soft felt cap"` -> `"A cap made of soft felt..."`; `"a scroll of
      enchantment"` -> `"A scroll of magical enchantment..."`; `"a wand
      of elm wood"` -> `"A wand made of polished elm..."`; `"a shark
      tooth"` -> `"A tooth of some sort..."`. Honest answer: no, not
      reliably for every item — a substring/keyword mapping would work
      for most but should be built as a best-effort optional link (with a
      way to manually confirm/correct), not assumed complete. Not yet
      built — needs Steven's go-ahead on that framing before
      implementing.
- [ ] **Help window auto-shows on every profile load.** Registered
      `visible=false` by default in `MyDSL_WindowRegistry.lua`, so this is
      likely a persisted-state issue (a prior test session left it
      visible and `MyDSL.Windows.saveState()` saved that) rather than a
      code default bug — not yet investigated.
- [ ] **LiveView's "age" field is mislabeled — it isn't DSL's real age
      stat.** Steven corrected 2026-07-16: "the age skill and the years
      line in score are connected and set age in game" (see
      `DSL_Helpfiles/age.txt` — age is a roleplay-only stat, set by
      `practice age` at a trainer, never decreases, never auto-advances;
      `MyDSL_DataLayer.lua`'s score parser already captures the real
      value as `scoreBlock.years`, confirmed live in `log/*.html`, e.g.
      `YEARS: 037`, but it's never displayed anywhere). `ageText()`
      (`MyDSL_LiveView.lua:377`) computes a completely different number
      — elapsed real-world time since character creation, converted via
      an empirically-derived ratio — which was built intentionally
      2026-07-12 per Steven's own spec at the time ("uses in-game time to
      tell you when your ingame birthday is"), not a miscalculation: the
      math is internally correct for what it does (verified 49y4m against
      Kien's real creation timestamp). The bug is presenting that number
      under the label "age" next to a character whose actual DSL age
      (from `YEARS:`) is a different, real, already-captured number.
      Needs Steven's call: relabel the current field (e.g. "played") and
      leave it as-is, add the real `scoreBlock.years` value alongside it,
      or replace it outright — not fixed yet, no code changed.

---

## OPEN — Design ideas, not yet scoped
- [ ] **TargetView: show debuffs cast on the current target.** weaken/slow
      confirmed and ready to build; blindness/poison/plague have zero
      confirmed on-target success text yet — needs a live catch of an
      actual successful cast.
- [ ] **TargetView: auto-populate target on aura detection** — when
      detect-good/detect-evil shows, auto-set to first opposing-alignment
      mob visible, else first mob not in your own group.
- [ ] **Skills/Spells → Combat window** — echo real skill/spell actions,
      reduce raw per-swing spam. Warrior/thief skills still have zero
      confirmed first-person text anywhere in the corpus.
- [ ] **Command vocabulary — more IC/human-speak, less `mydsl <module>
      <verb>`.** Design direction, not scoped.
- [ ] Item-clickable reference module — depends on Layer 4.
- [ ] Census (from UI) interacting with the reference module — depends on
      Layer 4.
- [ ] State-scoped sound toggle — generic pattern for an alias to turn a
      sound on for a state and reliably turn it off when the state ends.
- [ ] **Real gaps found while compiling `docs/CapturedPatterns_Reference.txt`
      (2026-07-15)** — that doc is a community-facing pattern reference, not
      itself a code change, but it surfaced several actual DSL2 gaps worth
      a look later:
      - TargetView's Consider capture only wires up 2 of a real 6-tier
        difficulty ladder ("looks like an easy kill." / "is no match for
        you." are active; "The perfect match!" / "'Do you feel lucky,
        punk?'." / "laughs at you mercilessly." / "Death will thank you for
        your gift." are real DSL2 native-XML text, confirmed identical in
        the PNP-family profiles too, but never wired in).
      - `detect magic`'s onset text was always blank in the ported spell
        table (PNP's own source has no onset for it) — "Your eyes tingle."
        is a high-confidence candidate (consistently follows `detect magic`
        in the log corpus) but not yet swapped in.
      - "heart blight" (distinct from "bone blight") is a real spell
        missing from DSL2's affects-echo table entirely.
      - DSL2's CreatureLore may only parse `look`/`scan` mob text, not the
        `lore <name>` command's own per-field output (base health/damage/
        training cycle/immunities/resistances/tactics lines) — a sibling
        profile's older CreatureDB parses `lore` output directly; worth
        checking DSL2 actually covers the same fields.
      - A whole quest-tracking mechanic (quest start/expire/timer messages)
        has zero coverage anywhere in DSL2 — matches the already-tracked
        "Data-driven notes/quest tracking" DEFERRED item below, not a new
        ask, just confirms real message text exists to build against
        whenever that's picked up.
      None of this is scoped/started — feature creep is still paused.
      Flagging so it isn't lost; the full source text for all of it is in
      `docs/CapturedPatterns_Reference.txt`.

---

## DEFERRED — explicitly held, no new scope without Steven's go-ahead
- [ ] **Shatteredarchive.com maps** — Steven's original bestiary-import
      request also mentioned "there are items on the website and maps as
      well." The bestiary half is done and confirmed. Explicitly deferred
      by Steven 2026-07-15. Needs its own scoping pass when picked back
      up (what format, whether it's per-area images like
      `MyDSL_LocationView.lua`'s room pictures or something else).
- [ ] **Cross-profile master function/feature inventory** — walk every
      `.lua` file across every Mudlet profile on this machine, build one
      consolidated list. Large, multi-session scope, its own future
      session.
- [ ] **Layer 4: Reference library** (items, mobs, lore) — not started.
      Check `~/Downloads/Shattered-Archive-release-dev.zip` before
      building from scratch.
- [ ] **Mapper hardening/MyDSL integration** — deferred until current UI
      workload finishes.
- [ ] **Data-driven notes/quest tracking** — streamline `notes_utf8.txt`'s
      in-game feature/quest items via data files instead of manual notes.
- [ ] **Consolidate all native Mudlet objects into one package** — per
      Steven: "this is why i want to pull all mudlet objects into one
      package so we can troubleshoot cleaner." Currently scattered across
      `gui-drop`/`mpkg`/`DslColors_v1_0.../`/`generic_mapper`/`EMCOChat`/
      `MyDSL_Full` plus loose top-level items. Large, structural,
      GUI-driven undertaking, its own future session.

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
- **~20 misc aliases** (`(inv)`, attire-swap sets, etc.) — fine as native
  aliases unless one becomes relevant to a window. `(autowhere)` moved out
  of this list 2026-07-16 — replaced by `MyDSL_AutoWhere.lua`, see NEEDS
  LIVE CONFIRMATION.

---

## DECISIONS RECORDED
- **Itemstat trigger retirement — sequencing confirmed 2026-07-16, per
  Steven: "itemstat will retire when we have made the item identification
  db and module."** Not proactively tracked as a live risk in the
  meantime ("close, we will deal with it if it arises" — 2026-07-16) —
  itemstat decorates `eq`/`in` output client-side and hasn't been proven
  to actually break any combat trigger. Retires naturally once Layer 4
  (the item reference library) replaces the equipment parser's current
  dependency on itemstat for stat data — no separate decision needed
  before then.
- **"Prompt Line 1" parsing — dropped, confirmed 2026-07-16.** Per
  Steven ("prompts are gaged even with quiet now") the scenario this was
  meant to cover (needing to parse flags out of a leaking, un-gagged
  prompt line) doesn't occur — prompt gagging already works correctly
  with quiet mode active. Not pursuing this.
- **Staying on Mudlet 4.20.1, not 4.21/4.22** — confirmed 2026-07-12 real
  upstream bug: `TMainConsole::getUserWindowSize()` (added by PR #9334)
  rejects a docked `UserWindow`'s real size as "suspicious shrinkage"
  once it's shrunk enough from a previously-cached larger size, and
  returns the stale larger size instead — every percentage-positioned
  child (Tick's bars, Focus's button grid) then gets placed against
  that wrong number. Confirmed this survives a full Mudlet restart
  (Mudlet's own `windowLayout.dat`/`windowLayoutGeometry.dat`, outside
  any profile folder, re-poison it on every launch) and that resetting
  those files doesn't cleanly fix it (made the whole panel layout
  collapse instead). Reverting to 4.20.1 fixed everything immediately.
  **Don't re-investigate Tick/Focus/other-docked-window sizing bugs as
  a MyDSL problem without first checking the installed Mudlet version**
  — if a future upgrade is considered, check whether this shrinkage
  guard has been revised upstream first.
- Most settings (theme, visibility, chat, fonts, TargetView/AffectsView)
  are character-bound. **Window layout is the one deliberate exception**:
  layout is per-profile (single shared `MyDSL_layout.lua` + native Qt
  `saveWindowLayout()`), not per-character — after repeated fights with a
  custom per-character percentage-save system, simplicity won out.
- Themes: user-creatable named presets, shared across all characters
  (intentionally not character-bound).
- Creaturelore DB (`MyDSL_CreatureLore.lua`): shared across characters,
  not character-bound — objective game data, same reasoning as themes.
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
