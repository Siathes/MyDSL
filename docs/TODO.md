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

## PACKAGING — fresh-install status
- [ ] **`MyDSL_Full.mpackage` — one combined package, several rounds of
      real fresh-install feedback fixed, still needs a full live
      confirmation pass.** Current contents (33 scripts + GameplayTriggers
      + movement/door keys + DslColors, one import): the 31 MyDSL modules,
      chat fully self-contained (EMCO ported in, `MyDSL_Chat.lua`, no
      separate EMCOChat dependency), namespace fully MyDSL-owned (no
      `demonnic.*` left anywhere), `MyDSL_MovementSounds.lua` (recovered
      from a native-only script the earlier builds missed entirely — this
      is why the NumPad keys silently did nothing on the fresh profile),
      the native GameplayTriggers/keys/DslColors content scrubbed of every
      hardcoded character name and machine-specific path (sound triggers
      now resolve via `getMudletHomeDir()`, two door/portal triggers that
      could only ever fire for one specific character rewritten as
      wildcarded regex), and DslColors' own title list merged with
      Steven's full accumulated `dslcolor title` additions. `Sounds.zip`/
      `RoomPics.zip` ship separately (media can't be embedded in a
      `.mpackage`) — placement instructions in `INSTALL.md`.
      Still true from the original build: no packaged/documented process
      for the PNP base-client prerequisite (always manual, outside this
      session's visibility); `generic_mapper`/`DslColors` raw exports
      already sit in `~/Downloads/`. One required manual native step
      confirmed: disable the native `(autowhere)` alias. Full history:
      `CHANGELOG.md`; day-to-day detail: `INSTALL.md` shipped alongside
      the package.
- [ ] **Windows resetting position when docking a second window on the
      fresh profile — likely root cause found, not fixed.** Confirmed
      NOT a recurrence of the previously-fixed Mudlet 4.21/4.22
      "suspicious shrinkage" bug (checked the actual running AppImage:
      still 4.20.1). Confirmed NOT the previously-fixed auto-reflow-on-
      resize bug either (`MyDSL_LayoutEngine.lua`'s own header comment
      documents that fix — no `sysWindowResizeEvent` handler exists
      anywhere in the current codebase, verified via grep). Real
      difference for a genuinely fresh profile: Mudlet's own native
      window-geometry cache (`windowLayoutGeometry.dat`/`windowLayout.dat`)
      lives at `~/.config/mudlet/` directly — confirmed via `find` —
      **shared across every profile on the machine, not per-profile**.
      Every UserWindow gets `restoreLayout=true` (`patchUserWindowConstructor()`,
      `MyDSL_WindowRegistry.lua`), which (confirmed by reading Mudlet's
      own bundled `GeyserUserWindow.lua` via the mounted AppImage) tells
      Mudlet's native engine to look up cached geometry by window name in
      that shared file. Since the fresh "MyDSL" profile uses identically-
      named windows to the original DSL2 profile, its windows are likely
      inheriting stale dock-state cached from the original profile's own
      layout history. Not touched — this exact class of file already
      caused a real regression once before in this project (TODO.md's
      own DECISIONS RECORDED: resetting it made the whole panel layout
      collapse, not fix anything) — needs discussion, not a blind fix.

---

## LOW PRIORITY — script wiring
- [ ] Native trigger "bumps into you causing you to lose your balance."
      found disabled in the working profile with no documented reason —
      flagged 2026-07-17, not yet investigated (its sibling flag, "English
      Multi-Line Exits Trigger", turned out to be correctly disabled —
      it's for MUDs with a different multi-line exits format than DSL's;
      this one hasn't been checked the same way yet).
- [ ] ChatWrapper tab active/inactive CSS still hardcoded — no ThemeEngine
      hookup. Real design pass, not a mechanical fix.
- [ ] `MyDSL_creaturelore.lua` (lowercase, profile root) is stale DSL1
      carry-over data, not a module — superseded by
      `MyDSL/creaturelore_db.lua`. Tracked in git, unused. Confirm with
      Steven before deleting.
- [ ] `MyDSL.Windows.setTitle` doesn't exist anywhere in
      `MyDSL_WindowRegistry.lua` — found during the 2026-07-16 full
      codebase review. One call site (`MyDSL_AffectsView.lua:952`,
      `A.setTitle()`) is both existence-guarded and `pcall`-wrapped, so
      it's a silent permanent no-op, not a crash risk — but it means
      renaming the Affects window's title never actually notifies
      WindowRegistry, per that code's own comment about avoiding a
      "spam" feedback loop. Not fixed — unclear whether
      `Windows.setTitle` was removed deliberately or just never built;
      needs a decision, not a blind guess at what it should do.

---

## NEEDS LIVE CONFIRMATION
Fixed in code, verified via syntax checks and/or emulation — none of this
is closed until Steven confirms it in-game. Full technical detail for any
item: `git log --oneline` + `docs/CHANGELOG.md`.

- [ ] **2026-07-16 "what's left" build pass — cleared several buildable
      backlog items, checked out several more that turned out to
      already be resolved or unconfirmable.** Built:
      - TargetView Consider: added the remaining 4 of 6 real difficulty
        tiers (was only 2) — "The perfect match!", "<mob> says 'Do you
        feel lucky, punk?'.", "<mob> laughs at you mercilessly.", "Death
        will thank you for your gift." — confirmed via the PNP sibling
        profile's own log corpus (DSL2's own corpus had zero examples of
        these rarer tiers). `captureConsider()` just stores the raw line
        verbatim, so the two nameless tiers needed no special handling.
      - Item Reference had no `LayoutEngine` default position at all
        (fell back to a generic corner-ish default, which is why it
        landed tabbed alongside the much larger Scan/Combat/Bestiary
        group). Added a real compact default near Portrait/Location, per
        Steven's "compact... top left corner" ask — **only takes effect
        after `mydsl layout reset` or a manual drag+`mydsl layout save`**,
        LayoutEngine can't move an already natively-docked window.
      - Help window auto-showing on load — root cause confirmed: not a
        code bug, leftover `visible=true` saved state on Kien/Qinrathaz/
        Vaelis's window-state files from testing the Help window earlier
        the same session. Corrected directly to `false`, matching the
        registry's own intended default (Vrokt's file already had it
        right, confirming the default logic itself was always correct).
      - Wired `MyDSL.resolveGroundItem()` (built last pass, never
        connected to anything) into an actual hover on ground items seen
        via `look`, same `selectString()`+`setLink()` technique as the
        equipment hover — only attaches when a real resolution exists,
        no hover for the fraction of items with no reliable match. Added
        the "manual map option" Steven asked for: `item map <ground
        text> = <inventory/equipment name>`, added as a branch inside
        the existing `item <name>` dispatcher (not a separate alias —
        a standalone one would have collided with that dispatcher's own
        catch-all and sent `identify map ...` to the server as a real
        game command, caught before it shipped). Verified via a
        structural test: clean matches get a hover, declined matches
        don't, a manual override both resolves correctly and gets a
        hover on the next sighting.
      Checked and found already resolved (no longer open, TODO note was
      stale): `detect magic`'s onset text and "heart blight" were both
      already fixed in `docs/CapturedPatterns_Reference.txt`, just not
      flagged done; "heart blight" moved from a trailing annotation into
      the main alphabetized table. CreatureLore's `lore <name>` gap was
      based on a misunderstanding (see DECISIONS RECORDED).
      Investigated and deliberately NOT built (real reasons, not just
      time): TargetView aura-based auto-targeting — explicitly marked
      "not yet scoped" (unlike Consider/debuffs which were marked
      ready), and building it would require restructuring
      `parseScanLine()`/`parseLookHereLine()` to preserve aura-tag data
      they currently discard entirely, plus it changes combat-target
      selection automatically, which has real correctness stakes if
      wrong — needs a scoping discussion, not a blind build. TargetView
      "show debuffs on target" (weaken/slow) — TODO claimed this was
      "confirmed and ready to build," but a fresh corpus search (DSL2 +
      the PNP sibling profile) found zero real third-person/observer-
      side text for either debuff landing on someone else, only
      self-referential "You feel..." text for when it lands on you. The
      "confirmed" claim doesn't hold up; not building off an unconfirmed
      pattern. Quest-tracking (DEFERRED item) — checked the corpus for
      real quest start/expire/complete message text, found only helpfile
      prose about how quests work, no actual game echoes; still nothing
      to build against.
      All syntax-checked; Consider triggers, ground-item hover, and the
      manual-map override all verified via structural test harnesses.
      None of this is visually confirmed live yet.

- [ ] **2026-07-16 UI polish batch, working through notes_utf8.txt.**
      - Chat "no chat is being captured? had to use mydsl chat rebuild" --
        `C.startupSync()` (`MyDSL_ChatWrapper.lua`) already has a 0.4s/
        1.5s/3.5s/5s delayed-check ladder for exactly this class of
        problem (EMCO window not ready when layout restore finishes late)
        but nothing retries after 5s -- if that boot happened to take
        longer, chat stays silently un-routed forever with no further
        self-heal. Added one more check at 15s as a safety net. Root
        cause not conclusively proven (no error/reproduction steps beyond
        the one report), so this is a defensive hardening, not a
        confirmed fix -- still needs Steven's live confirmation on
        whether it recurs.
      - Combat life-echo missing a connecting verb ("A gray wolf cub big
        wounds [30-49%]") — confirmed live via log corpus, fixed: now
        "... has big wounds [30-49%]" (`MyDSL_DataLayer.lua`).
      - PlayersNear had no command surface at all (only History-style
        routed windows, no dedicated module) — added `mydsl playersnear
        show/hide/font <n>/status`, mirroring History's own font+status
        pattern (`MyDSL_RouteHelper.lua`).
      - Bestiary/Focus/Item Reference: removed the `----`/`──` rule lines
        (Steven: "lose the ---- lines for more space" / "remove the ---
        lines in bestiary"); dropped each file's now-unused `hrule()`
        helper. Replaced each window's static `wrapWidth = 300` (never
        matched their actual docked width) with `enableAutoWrap()` — the
        same real, already-proven-working Mudlet API History already
        uses — for genuine adaptive word wrap.
      - Bestiary: dropped the always-empty "Kills: 0 / Avg XP: ? / Last
        XP: ?" row entirely, matching Focus's own 2026-07-11 precedent
        for the exact same fields (real HP still shows fine when a
        creature has actual lore data; Kills/XP have no capture path
        anywhere in this codebase — DSL's `creaturelore` skill doesn't
        report them at all, confirmed via `DSL_Helpfiles/creaturelore.txt`).
      - Group: name column narrowed 20 -> 14 chars (was always padding
        short player names out to a full 20 characters before the hp%
        stat, per Steven "reduce space in group window between name and
        stats"); still fixed-width so hp/mana/move stay column-aligned
        across rows.
      - Item Reference: Affects list now pairs two entries per line
        instead of one (Steven: "make 2 columns... reduce the amount that
        need to scroll") — a full side-by-side redesign of the whole
        window wasn't attempted without live iteration, but this cuts the
        longest repeating block roughly in half.
      - Scan window: added `MyDSL.applyScanBadgeHover()` — Steven asked
        for RightHere's existing visible `[Known]/[Seen]/[Unknown]` badge
        on the main Scan body too, but that's raw copied game text (`selectCurrentLine()
        `+`copy()`+`appendBuffer()`, "move text, don't invent it"), not
        decho-built like RightHere — editing the pasted line to add
        visible badge text is the same class of manipulation already
        tried once (a left-margin space) and abandoned as not worth the
        risk. Used the safer, already-proven hover technique instead
        (same as AffectsView/equipment-line hover): `selectString()`+
        `setLink()` attaches a tooltip showing the state, without
        touching the visible text at all. If Steven wants a genuinely
        visible inline badge instead of hover, that needs the riskier
        insertText() approach and should be discussed first.
      - LocationView: found and fixed a real bug while investigating the
        "location/portrait changed after the Mudlet update" report —
        `M.clear()` updated the caption text but never actually cleared
        `M.ui.image`, so a room with no picture right after one that HAD
        a picture would keep showing the previous room's stale image
        instead of a blank/missing state.
      All syntax-checked; Scan's new capture path also verified via a
      structural test harness (rawName field populated correctly, full
      trigger chain runs with no errors). None of this is visually
      confirmed live yet.
- [ ] **Location/Portrait "ran smoother before the Mudlet update" —
      partially investigated, root cause NOT found, needs more specifics
      from Steven.** Checked: Portrait's own code hasn't changed since
      2026-07-12 (git log), and a fresh screenshot (`Screenshot_20260716_
      174348.png`) shows Portrait rendering correctly. Location's panel
      in that same screenshot was fully blank — no image AND no "No room
      picture" caption text either, which shouldn't happen if `M.render()`
      reached its normal missing-picture path (that path, and the
      `M.clear()` bug just above, are real but don't fully explain a
      totally blank window with no caption). Need: which Mudlet version
      is currently running (Help > About), and whether this is
      specifically about Location, Portrait, or both — "ran smoother"
      could mean scaling/quality, timing/flicker, or something else
      entirely; a plain description or a fresh screenshot showing the
      actual visual problem (not just a room with no picture assigned)
      would narrow this down a lot faster than more static code reading.
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
- [ ] Census (from UI) interacting with the reference module — Layer 4
      (ItemLore/ItemReference) now exists (2026-07-16), so this is
      unblocked whenever picked up; not yet scoped otherwise.
- [ ] **DSL event/date reminder module** — Steven: "a DSL reminder that
      allows you to enter events and dates and have it come up as a
      reminder when logged in or playing that such and such event will
      start soon... I believe there are also events in the calendar or
      holidays of the DSL wiki. Some way to connect this to Discord would
      be optimal! There is a Mudlet calendar for Achaea on GitHub that
      might help." Not scoped — needs: what counts as an "event" (manually
      entered vs. scraped from the DSL wiki calendar/holidays), whether
      Discord integration is in scope for this pass or a separate ask
      (would be the first outbound-network integration in this project —
      worth a design discussion given the passive-observation-only
      philosophy has so far meant zero outbound calls), and whether the
      referenced Achaea Mudlet calendar package is worth checking for a
      reusable pattern before building fresh.
- [ ] **Mapper/LocationView: distinguish same-named rooms — built
      2026-07-17, needs live confirmation.** Investigated first: confirmed
      `generic_mapper` already keeps same-named-but-different rooms as
      genuinely separate map nodes (no mapper-side bug), and traced its
      own room-matching to run entirely synchronously inside its own
      script/triggers — a hands-off wrapper can't feed it new criteria
      before the fact anyway. Turned out the actual need is 100%
      LocationView-side and needs zero mapper involvement:
      `MyDSL_LocationView.lua` already resolved pictures by room-name text
      alone. Built `MyDSL.captureRoomDescription()`
      (`MyDSL_DataLayer.lua`, a new rolling-line-buffer capture of the
      room's own description + color) and `M.resolveVariant()`
      (`MyDSL_LocationView.lua`) — matches description first, falls back
      to exits, keeps color per-variant for a future tiebreak. First-seen
      variant of a name keeps the plain filename, each new variant gets
      `Name (2).png`/`(3).png`/etc — zero renaming needed for the ~215
      existing picture files. New `mydsl location variants [room]`
      command. Verified via a structural test harness; not yet confirmed
      against a real same-named-room encounter in-game.
- [ ] State-scoped sound toggle — generic pattern for an alias to turn a
      sound on for a state and reliably turn it off when the state ends.
- [ ] **A whole quest-tracking mechanic (quest start/expire/timer
      messages) has zero coverage anywhere in DSL2** — matches the
      already-tracked "Data-driven notes/quest tracking" DEFERRED item
      below, not a new ask, confirms real message text exists to build
      against whenever that's picked up. (The other 3 gaps flagged
      alongside this one on 2026-07-15 are resolved as of 2026-07-16:
      Consider now wires up all 6 real difficulty tiers, not 2 —
      `MyDSL_TargetView.lua`; `detect magic`/`heart blight` were already
      fixed in `docs/CapturedPatterns_Reference.txt`, just not flagged
      done; CreatureLore's `lore <name>` gap turned out to be based on a
      misunderstanding — checked `DSL_Helpfiles/lore.txt` and
      `creaturelore.txt` directly: `lore` is a general item-only skill
      that auto-fires on look/examine, has nothing to do with creatures;
      `creaturelore <target>` is DSL's one real creature-info command,
      and DSL2 already captures it correctly.)

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
- **CreatureLore's `lore <name>` "gap" — confirmed a non-issue,
  2026-07-16.** The 2026-07-15 note worried DSL2 might only parse
  `look`/`scan` mob text, not a `lore <name>` command's own per-field
  creature output. Checked `DSL_Helpfiles/lore.txt` and
  `creaturelore.txt` directly: `lore` is a general item-only skill
  (works automatically on look/examine, nothing to do with creatures at
  all); `creaturelore <target>` is DSL's one real creature-info command,
  and `beginCreatureLore()`/`loreStart` (`MyDSL_DataLayer.lua`) already
  captures it correctly. The "sibling profile's CreatureDB parses lore
  output directly" claim that prompted this couldn't be independently
  verified against the actual sibling profile files on this machine.
- **LiveView's "age" field — confirmed correct as-is, 2026-07-16.**
  Steven: "if the age in live is how many ingame months/years have past
  since creation, that is a good." No relabel/replace needed — the
  displayed figure (elapsed real-world time since character creation,
  converted via `ageText()`'s empirical ratio) is exactly what he wants
  shown there, distinct from DSL's own separate roleplay age stat
  (`practice age`/score's `YEARS:` line), which stays uncaptured/
  undisplayed by design.
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
