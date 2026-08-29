# DSL Observer UI — TODO
*A current punch list only — resolved/historical items live in `CHANGELOG.md`
and git history, not here. Restructured 2026-07-06; pruned three times since
(most recently 2026-08-27 after 2700+ lines). Same day, **the full open list
went through a two-phase triage with Steven**: phase 1, an interactive
checklist (built by Claude Desktop) where every open item got a Keep /
Cut-done / Cut-not-doing / Needs-info call; phase 2, every "needs-info" item
got researched against the actual code/git history (not just re-read from
this file) and brought back to Steven with concrete findings and one
question each, which he then answered directly. **Everything below reflects
the phase-2 answers** — full research findings for anything summarized here
live in `HANDOFF.md`'s 2026-08-27 entry from Claude Desktop; ask there
before re-deriving something this pass already confirmed. If this file
turns back into a growing append-only history again, prune it.*

**Closed this pass, no longer tracked (confirmed resolved, confirmed
not-worth-building, or explicitly dropped by Steven)**: dock-tab-group
label styling (risk not worth it — `setAppStyleSheet()` is whole-app scope,
no per-window hook exists); `mydsl rawlog` diagnostic — **removed
2026-08-27** (`MyDSL_RawCapture.lua` deleted entirely, confirmed zero
dependents anywhere in the codebase — see `docs/CHANGELOG.md`); the Roller
pre-port native trigger (confirmed gone); CharacterAssist "consolidating
issues" (dropped — revisit only if it resurfaces); BACKSTABS Fail dead
trigger (leaving as-is, colorizing still works even though the script body
is inert); Murder/Consider duplicate-mob bug, `setspell` bare-command
usage, LocationView quote-stripping, and the `MyDSL.save()`/`table.load()`
naming worry (all four confirmed already fixed in code — just need
Steven's live re-confirm, see NEEDS LIVE CONFIRMATION below); Layer 4
areas/zones reference (no usable local data source, removed per Steven);
Restrings guide, Shatteredarchive maps, inventory hover expansion (all
previously cut-not-doing).

**Feature creep is paused as of 2026-07-07, per Steven** — bug fixes, live
confirmation, and finishing already-scoped work only. Nothing under
DEFERRED gets started without an explicit go-ahead.

---

## TOP PRIORITY

**Session plan (agreed 2026-08-29, Claude Desktop's proposal):** the
native-content consolidation item and the `MyDSL_Full.mpackage`
from-scratch install test both need Steven's hands on Mudlet's GUI and
both need a disposable test profile — and Claude Desktop's Mudlet 5.0
upgrade runbook (Phase 2 dock/resize repro) needs the same kind of
disposable profile. Fold all three into one live sitting: build the test
profile once, use it for native-content work, the mpackage install test,
and the Mudlet 5.0 retest, instead of standing one up three separate
times. `scripts/run_all_tests.sh` (adopted 2026-08-29 from Steven's
Downloads — see CLAUDE.md housekeeping) is what the runbook's before/after
diff leans on; confirmed working (52/52 passing) ahead of that session.

- [ ] **Native-content full consolidation — Steven's own words: "this is a
      high priority to get back to a solid baseline of everything in the
      package."** Merges three related asks from this pass into one
      initiative: (1) `build_mydsl_package.py` needs to splice in
      *everything* live and gameplay-relevant — aliases, triggers,
      keybinds, scripts, all of it — minus Mudlet's own default content,
      not just Scripts/Triggers/Keys like today (currently zero
      `AliasPackage` handling exists at all; `MyDSL_PersonalAliases.xml`'s
      29 aliases never make it into a build). **New same-class gap found
      2026-08-29** while fixing hardcoded sound paths: a bare native
      `Trigger` named "Nature Growth" (plus siblings "Do you want color?
      (Y/N)"/"return from void") sits directly under `<TriggerPackage>`
      with an empty `<packageName>` — never inside `MyDSL_GameplayTriggers`
      or any other tracked group, so it's invisible to every existing
      backup/build mechanism the same way the 29 personal aliases were.
      Its own hardcoded sound path was fixed live regardless (harmless),
      but the packaging gap itself is exactly this item's problem, not
      solved here. (2) `scripts/
      check_known_patterns.py` needs to extend past `.lua`-only scanning to
      cover the native XML files too, per the same principle — "you should
      know everything that is happening in the code and mudlet." (3)
      Steven's broader plan from the phase-1 triage: get everything
      consolidated into one clean baseline package, spin up a fresh test
      profile ("MyDSL") to install and verify it, and — once confirmed
      working — fold DSL2's logs/needed files into it (renaming DSL2 to
      "MyDSL Test"), then delete the now-unneeded profiles. Needs real
      scoping before work starts — this is a large, structural,
      GUI-driven undertaking.
- [ ] **DslColors — make Census genuinely useful, document it.** The
      "integrate + toggle" and "fix known bugs" parts of this pass are
      done (2026-08-29 — see `docs/CHANGELOG.md`: master `dslcolor
      on|off` added, `dslBoundedFind()`'s per-term line re-lowercase
      fixed). Still open, and the bigger remaining half of this item:
      - **Make Census data actually useful.** Today `people[key]`'s
        `last_seen_*` fields just reflect the last time someone showed up
        on the `who` list — Steven wants "last seen" to instead reflect
        the real room/time/area the character actually walked into with
        you, which means real mapper/DataLayer integration, not a `who`
        snapshot. Also wants: kingdom/clan membership tracked as a
        *history*, not just current state; an emerald dragon color
        palette; a consistency audit on titles/palettes/terms, especially
        Thax/Thaxanos kingdom coloring against real logs; and is open to
        further suggestions on color/highlighting of people generally.
      - **Add player-profile fields to Census.** No alignment, god, hp, or
        mana field exists in `people[key]` today. Steven: "check logs and
        collect as much real census as possible — hp avg over any combat
        we have. Alignment can be manual-added (unless we use the
        character auras when detects are up — check logs and helpfiles)
        along with god."
      - **Document it.** Steven: "there should be more notes on
        dslcolor" — this module has grown organically with little
        written explanation of its own data model; worth a real doc pass
        once the above lands.
- [ ] **`MyDSL_Full.mpackage` — real from-scratch install test.** The
      2026-08-26 packaging-format fix itself is solid and tested, but
      chat self-containment, `Sounds.zip`/`RoomPics.zip` placement, and
      the PNP-prerequisite step have never been tested end-to-end, and the
      `INSTALL.md` that's supposed to document Sounds/RoomPics placement
      doesn't exist yet. Steven: "we will do a from scratch and see how it
      unfolds and can be improved" — run the real install, then write
      `INSTALL.md` from what that reveals.

*(Native-content tracking's Principle-2 question is answered, not open:
Principle 2 is "Toggleable By Default" — MYDSL_1.0_PHILOSOPHY.md, unrelated
to the automation rule Steven was thinking of, which was a different,
already-retired restriction. Whether the 29 personal shortcut aliases
specifically need individual per-alias toggles is a minor open question,
but low-stakes and folds naturally into the native-content consolidation
item above rather than needing its own decision.)*

---

## LOW PRIORITY
- [ ] **`MyDSL_DataLayer.lua` split-by-domain refactor — code complete
      2026-08-25, slices 1-2 live-confirmed.** Slices 3-5 still need
      Steven's live confirmation: `MyDSL_DataLayer_ScanLook.lua` (needs a
      `scan`, a `look`, and a "Players near you:" listing), `MyDSL_
      DataLayer_ItemLore.lua` (identify/lore/equipment/inventory/
      containers), `MyDSL_DataLayer_PromptVitals.lua` (score/flags/lunar/
      time/weather/who/group/improve). Steven, 2026-08-27: "keep, we will
      look at in a game run to add to the tests to perform during
      gameplay" — bundle with the other live-gameplay-test items below.
- [ ] `scripts/check_text_coverage.py` has two confirmed extraction blind
      spots (a wrapper-function pattern in ChatTriggers/CharacterAssist/
      Leveling; a narrowed-variable `:find()`/`:match()` call in the
      mapper) — genuinely low-stakes, affects only the coverage tool's
      internal ranking output, not correctness of anything it's ranking.
      Steven had no context on this one; leaving it as background backlog
      rather than a real decision point.

---

## NEEDS LIVE CONFIRMATION
Fixed in code (or already known-good), none of it closed until Steven
confirms it in-game. Bundle these into upcoming play sessions rather than
one at a time:
- [ ] DataLayer room-capture: 3 more fixture-line gaps + an NPC-verb gap.
- [ ] Focus/TargetView populating during a Leveling fight AND during
      normal manual combat.
- [ ] Mapper: "air" terrain color while flying, room weight from real
      movement cost, terrain-color "set once" lock + override alias,
      `dslroom raw`.
- [ ] PlayersNear font size surviving a reload — ready to test and close.
- [ ] **Location/Portrait rendering, concrete scope now**: the portrait
      image should fit/scale to the window (currently doesn't), and
      there's a stray bar at the top of the window. Reread/rewrite the
      relevant code with optimization in mind while fixing this.
- [ ] CharacterAssist: rearm (weapon+shield) itself, separately from
      spellup/setspell/blind-vision (already confirmed).
- [ ] PVP performance pass (debounced saves, gated raw-capture, batched
      buffer trims) — code-audited, not measured; worth a real lag check
      if lag comes up again.
- [ ] Identify persistence — fresh live `identify` + check.
- [ ] **Fuzzy name-matching, narrowed scope**: drop ground-item matching
      entirely; only wire mob ID (`resolveMobName()`) to real clickable
      links, scoped to inventory/container/equipment lists.
- [ ] Murder/Consider/Order-All duplicate-mob bug — **already fixed**
      2026-07-16 (`MyDSL_ScanView.lua:223-237`), just needs a live
      duplicate-mob-kill confirm.
- [ ] `setspell` bare-command usage — **already fixed** 2026-07-16, just
      needs a live re-confirm.
- [ ] LocationView quote-stripping — **already fixed** 2026-08-23, just
      needs a live re-confirm.
- [ ] **Fight-summary spell-damage capture** — not actually an open design
      question: the existing damage-line pattern matches on message
      *shape*, not verb identity, so a landing damage spell should already
      flow through with zero new code. Steven: "check logs or wait till
      next gameplay for testing, group with other gameplay tests" — just
      needs one live confirm (or a `log/` grep) to close out.

---

## OPEN — Combat, remaining loose ends
- [ ] **DEFERRED, per Steven ("we can wait a bit longer on")**: Algoron
      Combat League (AGL) / Coliseum combat module.

---

## PAUSED — needs more captured log data before further progress
- [ ] `procUnholy`/`procManaSelf` — zero occurrences found.
- [ ] `combatSense1/2` — zero occurrences found; needs a bard specifically
      playing/logging.

---

## OPEN — Design ideas, not yet scoped
- [ ] **TargetView: debuffs on target / aura auto-populate / scan
      auto-populate** — all three confirmed deferred until a real
      design+build pass (no corpus text to build against yet for the
      first two; the third needs a target-selection design decision).
- [ ] **Combat window/condenser — full module philosophy + optimization
      discussion.** Broader than originally scoped: `MyDSL_CombatView.lua`
      already exists and works (live-feeds every damage swing, renders
      per-target fight summaries) — what's missing is non-damage skill/
      spell action text (bash's knockdown, spell-cast announcements),
      zero corpus text confirmed for those yet. Steven: "design discussion
      about the combat condenser would be beneficial, to discuss the
      whole module philosophy and optimize" — treat as a full review of
      the window, not just the missing-coverage question.
- [ ] **Command vocabulary** — more IC/human-speak, less `mydsl <module>
      <verb>`. Discussion about whether commands stay grouped under
      `mydsl <module>` or become direct top-level commands.
- [ ] Census (from UI) interacting with the reference module — now folded
      into the DslColors integration item under Top Priority; tracked
      there, not separately.
- [ ] **DSL event/date reminder module** — scope narrowed: drop Discord
      entirely, stays inside Mudlet as a simple reminder/calendar app
      (enter events/dates, get reminded on login or while playing). Still
      needs: what counts as an "event" (manual vs. scraped from the DSL
      wiki's calendar/holidays), and whether the Achaea Mudlet calendar
      package on GitHub is worth checking for a reusable pattern.
- [ ] **Mapper — consolidated design discussion.** Steven: "this is part
      of a larger mapper discussion, consolidate with other mapper
      topics and do a scan of all the files and prepare for a design
      discussion." Covers, as one conversation: the full DSL-specific
      rewrite (vs. patching the stock Generic Mapper fork); the GMCP-
      parsing merge into DataLayer (approved in principle, not started —
      touches ~8 call sites in the live 6,631-line native file, needs a
      real rollback/testing plan); the toggleable button bar for
      map-editing commands; alternate/angled exit lines; and the
      labels-don't-move bug (still needs Steven's own live repro — no
      cause found in Mudlet's public issue tracker).
- [ ] **CreatureLore "mob diary" wiki window** — deferred; may fold into a
      larger DSL knowledgebase project alongside the Layer-4-remainder
      idea (see below).
- [ ] **Extend creaturelore/identify alias-shortcut pattern** to spells/
      skills/other commands — Steven: "this needs a larger design
      discussion" (still no named candidate commands).
- [ ] **Project-wide alias-dedup + namespace-guard sweep — approved, go
      ahead.** Real grep-driven audit, not started.
- [ ] **Quest-tracking mechanic.** Steven approved building this as a
      pop-up widget similar to the Moon/Weather widgets, using an old
      incomplete DSL questing script as a starting reference. New research
      step added this pass: "combine and check across profiles for the
      autoquest script, we've had a couple" — check the sibling Mudlet
      profiles (`../PNP1`, `../PNP2`, `../DSL1`, etc. — see `CLAUDE.md`'s
      reference list) for existing autoquest scripts before designing from
      scratch. Same underlying blocker either way: zero real corpus text
      for quest start/expire/timer messages has been captured yet.
- [ ] **Roller — comparison stats + reconnect timer.** The timer-widget
      half is ready to scope directly: `MyDSL_AlterformView.lua` is a
      ready-made template (standalone Geyser countdown window, sound
      warnings at thresholds) to copy for a disconnect timer, assuming
      ~30 min until proven otherwise. The comparison-stats half needs
      research first — Steven: "if you scrape Shattered you should find
      stats info... offer some ideas based on the roller game stats and
      maximizing rolls, based off Dragonlance D&D and I think something
      called d100 mechanics (old was d20 or d25?)." Scope: check the
      Shattered Archive dump plus DSL's own helpfiles for its actual roll
      mechanic before proposing anything.

---

## DEFERRED — explicitly held, no new scope without Steven's go-ahead
*(Nothing currently deferred — the two prior items here were either closed
this pass (Layer 4 areas/zones — no usable data source, removed per
Steven) or promoted into Top Priority (native-content consolidation).)*

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
  aliases unless one becomes relevant to a window.

*(Note: the native-content consolidation item under Top Priority may pull
some of this into tracked/packaged status even though it stays functionally
native — that's a packaging/tracking change, not a "build a MyDSL
equivalent" change, so this section's own list is unaffected until that
work actually starts.)*

---

## DECISIONS RECORDED
- **GroupView/TargetView quick-action buttons — UX + interconnection
  review, 2026-08-29.** Confirmed the "interconnection" question: both
  modules already share exactly one action registry,
  `MyDSL.TargetView.actions` (17 built-ins) plus `TV.config.
  custom_actions` (user-defined via `focus action`) — `GV.quickAction()`
  looks it up directly, so a custom action defined once works
  identically as a GroupView or TargetView button, already correctly
  wired, not a gap. The real friction behind "make changing buttons
  easier" wasn't the assignment mechanism (`focus mobset/playerset <6
  keys>`, `group quickset <2 keys>` — still typed, deliberately not
  rebuilt into a clickable picker UI given no way to live-test one) but
  that neither ever had a way to DISCOVER which keys are valid — a
  player had to already know an internal key like `cure_bugbite` from
  reading source. Fixed the low-risk, high-value half of that: added
  `TV.listActions()`, wired to both `focus actions` and `group actions`
  (GroupView delegates to the same function rather than duplicating).
  Documented in `MyDSL_Help.lua`; new
  `test/test_targetview_groupview_list_actions.lua`, confirmed
  meaningful via targeted revert. A real clickable button-picker (vs.
  this discoverability fix) remains a separate, larger UI project if
  Steven still wants one after trying `focus actions`/`group actions`.
- **ItemLore + ground-item capture — design review, 2026-08-29: no
  structural changes needed.** Traced the full chain across all 4
  files: `MyDSL_ItemLore.lua` (the persistent DB, correct partial/full
  three-state model — `lore` can never downgrade an `identify`d record
  because `merge()` distinguishes "field absent" from "field confirmed
  empty" via `FULL_STAT_FIELDS`, a real bug fixed 2026-07-19),
  `MyDSL_DataLayer_ItemLore.lua` (`resolveGroundItem()`: exact ItemLore-
  DB match, then manual override, then fuzzy-match against known
  equipment/inventory, else correctly declines rather than guessing),
  `MyDSL_DataLayer_ScanLook.lua` (the sighting/hover-linkify half), and
  `MyDSL_ItemReference.lua` (the display window, modeled line-for-line
  on the already-shipped Bestiary). All four cross-reference correctly;
  every hard case has an inline note explaining the resolution (e.g.
  the wand/staff-only `spellInfo` import restriction, confirmed against
  152/152 real scrape records). Checked the one gap that seemed
  plausible — no "browse/search all known items" command, only exact-
  name lookup — and confirmed via `MyDSL_CreatureReference.lua` that
  Bestiary has the identical lookup-only surface: this project's own
  established, consistent convention, not an ItemLore-specific gap.
- **Login flow — password/character autofill split, implemented
  2026-08-29.** Design review (docs/CHANGELOG.md same date) found
  `MyDSL_Login.lua`'s single `mydsl login on|off` toggle covered two
  unrelated prompts (master account password, and which character to
  play) with one hardcoded character name that's wrong whenever it
  doesn't match the session's target character. Presented 4 options;
  Steven chose "split toggle, default OFF for character autofill." Now
  `mydsl login on|off` controls password autofill only (unchanged
  default: on), `mydsl login character on|off` is new and independent
  (default: off), and the credentials file's field is renamed `name` →
  `character` with backward-compat fallback for an existing file still
  using the old key. `test/test_login.lua` extended for both toggles
  firing independently and the backward-compat load path; confirmed
  meaningful via targeted revert.
- **Help.lua "auto-derive" — built a drift checker, not a 189-call-site
  rewrite, 2026-08-29.** Steven's own suggested direction ("auto-derive
  sounds good") could have meant annotating every one of the ~189 real
  `tempAlias()` calls across ~20 files with description/example metadata
  at registration time — judged too large/invasive to do blind in one
  pass with no live-testing ability, especially since `MyDSL_Help.lua`'s
  hand-written prose is already better than a bare pattern string would
  auto-generate. What "fallen behind" actually meant in practice was
  DRIFT (a real alias with no matching help entry), so built
  `scripts/check_help_coverage.py` instead — same shape as
  `check_known_patterns.py`, reuses `check_text_coverage.py`'s existing
  `tempAlias()`-literal extractor, flags any real alias whose keyword
  prefix doesn't appear anywhere in `MyDSL_Help.lua`. First real run
  found 19 genuinely undocumented commands, confirmed by direct grep
  (zero `emco`/`login` mentions in `MyDSL_Help.lua`): all 17 ported-EMCO
  `emco *` sub-commands (`MyDSL_Chat.lua`) and both `mydsl login`
  commands (`MyDSL_Login.lua`, the 2026-08-26 secure-autologin module —
  had never gotten a help entry at all). Both gaps fixed the same day;
  re-running the checker now reports zero drift. Test:
  `test/test_check_help_coverage.py`, confirmed meaningful via targeted
  revert (git-stashing the `MyDSL_Help.lua` additions reproduces exactly
  the original 19-item report). Known blind spot, stated in the script's
  own docstring: aliases registered through a wrapper function (e.g.
  `MyDSL_ChatTriggers.lua`'s `route()`) rather than a direct
  `tempAlias()` call are invisible to this scan. Worth wiring into the
  periodic housekeeping sweep alongside `check_known_patterns.py --all`.
- **ChatTriggers coverage audit — confirmed solid, 2026-08-29.** Cross-
  checked all 5 tabs' patterns against `DSL_Helpfiles/channels.txt`'s
  authoritative channel list and the real `log/` corpus (1.3M lines).
  Every channel with real corpus evidence is captured. 4 named channels
  (Cgos, Thaxanos, Shalonesti, in-character Clan) have zero real chat-
  message examples anywhere in the corpus — same "can't build, no data"
  class as quest-tracking, not a fixable gap. Default gag-state also
  fixed the same day: Local's whisper pattern now matches its say/yell/
  shout siblings (`gag=false`), per Steven's own "Local is yells/tells/
  whispers and such" listing — Tells was already correct (a 2026-07-11
  decision, confirmed still current, not changed).
- **Adopted a project-local known-bad-pattern checker + Claude Code hook
  — 2026-07-21, per Steven.** `scripts/check_known_patterns.py`, wired
  into a `PostToolUse` hook. Run `python3 scripts/check_known_patterns.py
  --all` periodically for a full-repo sweep.
- **"Passive observation only, never send automatic game commands" — the
  hard blanket rule is retired, per Steven 2026-08-23.** What's still
  true: "automate to assist, not to decide for the player" still applies
  case by case (see `docs/MyDSL_IdeaBacklog.md`).
- **Mapper: `start mapping` stays a manual gate, not auto-persisted —
  confirmed 2026-07-18, per Steven.**
- **CreatureLore's `lore <name>` "gap" — confirmed a non-issue,
  2026-07-16.**
- **LiveView's "age" field — confirmed correct as-is, 2026-07-16.**
- **Itemstat trigger retirement — sequencing confirmed 2026-07-16.**
- **"Prompt Line 1" parsing — dropped, confirmed 2026-07-16.**
- **Staying on Mudlet 4.20.1 — real, reproducible bug on 4.21/4.22
  (docked `Geyser.UserWindow`s with percentage-sized children stopped
  recomputing layout on dock/resize), but the PR #9334 "reject
  suspicious shrinkage" root-cause citation from 2026-07-12 is
  confirmed WRONG (Claude Desktop, 2026-08-29 — pulled the actual PR
  diff: it's a null-pointer guard for an unrelated same-named-docked-
  window-recreation crash, no shrinkage/size-comparison logic anywhere
  in it). The real root cause was never actually identified — the PR
  number was a plausible-sounding guess that stuck. This matters now
  because Mudlet 5.0 shipped 2026-08-29 with a Geyser layout rewrite
  (the exact code path in question) — genuinely unknown whether the
  original bug still exists post-rewrite. Needs a real re-test on a
  disposable profile (the native-content consolidation project's own
  planned test profile is the natural place) before considering an
  upgrade off 4.20.1 — see
  `~/Downloads/mudlet_upgrade_assessment.md` for the full writeup.**
- Most settings are character-bound; **window layout is the one
  deliberate exception** (per-profile, not per-character).
- Themes: user-creatable named presets, shared across all characters.
- Creaturelore DB: shared across characters, not character-bound.
- `MyDSL_Mapper` removed from WindowRegistry — minimap via
  `map.configs.map_window` only.
- CharPic compatibility code removed from PortraitView.
- RouteHelper `routeMap` removed — shorthand helpers only.
- Prompt: toggleable pretty prompt, default ON.
- Day/Night derived from `time` command, not prompt capture.
- Alignment from score only, persists until next score run, no auto-send.
- **Window docking/positioning:** every `Geyser.UserWindow` gets
  `restoreLayout=true` + `autoDock=true` via a single global constructor
  patch (`patchUserWindowConstructor()` in `MyDSL_WindowRegistry.lua`).
- `DSL_PNP_Highlighter.lua`/`.custom.lua`, `DSL_PNP_People.lua`,
  `DSL_PNP_Statusbar.*`, and ~20 PNP-client-infrastructure files are
  explicitly out of scope.
- `colors.xml` (profile root) is a stale, unloaded pre-v1.0 DslColors
  snapshot — confirmed safe to leave alone.
- **Principle 2 clarified 2026-08-27 (this pass)**: "Toggleable By
  Default" (`docs/MYDSL_1.0_PHILOSOPHY.md`) — every feature independently
  on/off, including anything absorbed from native content. Not related to
  the (already-retired) automation restriction Steven initially suspected
  it meant.
