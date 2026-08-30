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
diff leans on; confirmed working ahead of that session (54/54 passing as
of the mapper upstream-sync work, same date). **Also now covers** whether
Mudlet 4.22's real native mapper features (Configure Areas dialog, exit
locking, label-color handling) are reachable — same version-upgrade
question, folded in per Steven 2026-08-29 rather than a separate check.

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
- [x] **Portrait window "black title bar" — RESOLVED, confirmed by Steven
      directly ("portrait bar is gone") and independently in "MyDSL Test"
      notes.json ("black border gone in portrait").** A fresh screenshot
      (Steven circled it in red) pinned it down: a solid black bar between
      the native title bar and the portrait image. Cause: the 2026-08-26
      "Direction A+" pass reserved the top 10% of Portrait's content area
      for `MyDSL.Windows.ensureHeader()`, a function never actually
      implemented anywhere (confirmed nil project-wide) — every other
      window from that pass just uses the native title bar with no
      reserved gap; Portrait alone kept both the dead call and the
      resulting empty margin. Removed both call sites and the 10%/90%
      split; image label is now full-height like every other window.
      `mydsl portrait title <text>` still works unchanged.
- [x] **Mapper "not following room movement" — RESOLVED 2026-08-30,
      confirmed by Steven directly** ("it now follows with room
      description false... i watched the mapper move each time after
      the toggle"), also confirmed in the raw session log (clean walk
      through 6 rooms with `map config use_description_matching false`
      set, no rejections, vs. the same walk failing with it `true`).
      Root cause: `DSL_Mapper_Addon.xml`'s `install()` forced
      `use_description_matching = true` on every fresh profile ("DSL
      repeated room names are common"), but stock's `check_room()`
      (private, unreachable from this addon) never updates a room's
      stored description once set — first match writes it, any later
      drift is rejected forever, no self-heal. One mismatch, ever,
      permanently locks that room out of automatic resolution — pinned
      down via Steven's own live `map debug` trace showing `Room N
      rejected: description mismatch` → `Room not found in map database`
      on every single automatic move, despite name+exits always matching
      correctly. Fixed in `DSL_Mapper_Addon.xml` v0.2.10: default flipped
      to `false`; `map config use_description_matching` still lets a
      player opt back in per-profile if a genuine same-name-same-exits
      collision ever shows up in practice. Regression test added
      (`test_dsl_mapper_addon.lua`). `DSL_Mapper_Addon.mpackage` rebuilt,
      in `~/Downloads/`.
      - Two loose ends, not blocking closure: (1) the fix only auto-
        applies to a genuinely fresh profile (`dsl_generic_mapper_seen`
        not yet set) — an already-installed profile needs the manual
        `map config use_description_matching false` toggle instead (what
        Steven actually did to confirm this). (2) `MyDSL` (live-play)
        is still on the old full-fork `DSL_Generic_Mapper.xml`, not this
        addon — deliberately left unmigrated (see the "MyDSL Package
        Manager migration" item below) since it touches Mudlet's own
        package bookkeeping on his real character profile, not something
        to raw-edit. If `MyDSL` shows the same symptom, the same manual
        `map config` toggle works there too regardless of migration.
      - Also surfaced and fixed along the way, not the root cause but
        real: `MyDSL Test` was silently loading the *other* profile's
        map file mid-session when Steven used `map show` (his own
        workaround for a fresh reinstall's empty map) — `docs/
        MUDLET_PACKAGING_REFERENCE.md`'s pre-delivery checklist now has
        a step to seed a fresh `MyDSL Test` with the live map
        proactively so that workaround isn't needed going forward.
      - Both desync loggers built during the investigation
        (`map.dsl.logDesync()` in `DSL_Generic_Mapper.xml` and
        `DSL_Mapper_Addon.xml`'s `checkRoomDesync()`) stay in place as
        standing infrastructure — check `mapper_desync_log.txt` first if
        anything like this ever resurfaces.
      - **Real fix for the underlying goal added 2026-08-30 (v0.2.11),
        per Steven**: "we want to store the description and be able to
        track rooms that have the same name but different descriptions.
        thats why it was turned on" — leaving matching off forever loses
        the real, confirmed-legitimate use case (a themed maze area,
        "Wing of the Stone Dragon," with deliberately repeated room
        names for genuinely different rooms — see `c388119`, 2026-07-18).
        `map.dsl.syncRoomDescription()`: on every room stock resolves
        successfully (`onGenericNewRoom`), resync that room's stored
        description to whatever was just captured. Fixes the actual
        defect in stock's `check_room()` (private, unreachable) — it
        writes a room's description exactly once and never updates it,
        so any drift between the stored text and a later capture is a
        permanent lockout. Root cause of the drift itself, confirmed via
        git history: the DSL mapper fork's description-capture format has
        changed at least twice since it was added 2026-07-18 (a perf pass
        the next day, the 2026-08-29 addon rewrite) — any room mapped
        before the most recent change has a description frozen in an
        older format, guaranteed to mismatch on the first revisit under
        newer code. Not specific to imported maps — Steven's own two
        failing rooms (Fellowship Saloon, Porch) are ordinary long-
        standing hometown rooms, not anything imported/merged.
        `syncRoomDescription()` heals this organically during normal
        play (matching stays off in the meantime — healing only works
        while it's off, since a stale stored description would otherwise
        block the very resolution needed to heal it). Once enough of a
        given map area has been revisited under the current code,
        `map config use_description_matching` can be turned back on
        safely — Steven's own call on timing, not automated. Regression
        tests added. `DSL_Mapper_Addon.mpackage` rebuilt (v0.2.11), in
        `~/Downloads/`.
- [ ] **`MyDSL` migration to the new mapper architecture** — still on the
      old full-fork `DSL_Generic_Mapper.xml`; `MyDSL_Mapper_Addon.xml`
      v0.2.10 (with the description-matching fix) is ready in
      `~/Downloads/`. Deliberately not done via raw XML surgery (touches
      Mudlet's own package bookkeeping on Steven's real character
      profile) — needs Steven, in the `MyDSL` profile: Package Manager →
      uninstall `DSL_Generic_Mapper` → install `DSL_Mapper_Addon.mpackage`.
      Not urgent now that the actual symptom (mapper not following) has
      a same-profile workaround (`map config use_description_matching
      false`) regardless of which architecture is running.
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
      **Asset-distribution plan researched 2026-08-29** (Claude Desktop,
      `asset_distribution_plan.md`, delivered to Steven's Downloads):
      host `Sounds.zip`/`RoomPics.zip`/`Portraits.zip` as GitHub Release
      assets on this repo (not Google Drive — its large-file "can't scan
      for viruses" interstitial breaks a plain `downloadFile()` fetch,
      confirmed reasoning not just a hunch), fetched via a new `mydsl
      assets fetch` alias using `downloadFile()` + `unzipAsync()`.
      **Steven's explicit call, 2026-08-29: this must be an opt-in
      command the player runs, never an automatic default-on fetch** —
      confirmed the right call by real folder sizes checked the same
      day (`du -sh`, live MyDSL profile): Sounds 22MB, portraits 44MB,
      but **`MyDSL/roompics/` is 1.3GB** — nowhere near something to pull
      automatically. Also confirmed `unzipAsync()`'s real signature
      directly from Mudlet's own test suite (`Miscallaneous_spec.lua`,
      the strongest source available — actual assertions, not docs that
      could drift): `unzipAsync(archivePath, extractToDirectory)`, 2
      required args, returns `true` immediately (extraction is async on
      another thread) then fires `sysUnzipDone`
      `(event, zipLocation, extractLocation)` or `sysUnzipError`
      `(event, zipLocation)` — `extractLocation` always comes back with
      a trailing `/` regardless of what was passed in. Both of Claude
      Desktop's open unknowns from the plan are now resolved.
      **Built 2026-08-30**: `MyDSL_AssetFetch.lua` (`mydsl assets
      fetch <sounds|roompics|all>` / `mydsl assets status`), strictly
      opt-in, one fetch at a time. Portraits deliberately dropped from
      scope, per Steven ("characters are personal and noone else needs
      mine so not needed") — Sounds.zip and RoomPics.zip only. Both
      zips already existed pre-built in the live MyDSL profile
      (confirmed correct: Sounds.zip 9.9MB/89 files, RoomPics.zip
      345MB/117 files, each zip's own entries already carry the right
      `Sounds/...`/`MyDSL/roompics/...` prefix) — uploaded as GitHub
      Release assets on `assets-v1`
      (https://github.com/Siathes/MyDSL/releases/tag/assets-v1), with
      Steven's explicit go-ahead. `test/test_assetfetch.lua` (20
      assertions: dispatch, single-fetch-at-a-time guard, the full
      download→unzip→cleanup chain, `fetch all` sequencing, error
      handling) all pass against mocked `downloadFile`/`unzipAsync`.
      Real end-to-end network fetch itself still needs a live in-Mudlet
      test — not something the Lua test suite can cover.

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
- [ ] **Login credential setup popup, built 2026-08-30** (Steven: "add a
      way for the user to add the login information like a pop up UI for
      the first setup (i dont want users to have to edit code for basic
      scripts)"). Mudlet/Geyser has no native text-entry widget (confirmed
      via grep — none exists anywhere in this codebase or the vendored PNP
      reference), so a real popup window (`MyDSL_LoginSetup`) now
      auto-shows once when unconfigured, explains what's needed, and its
      "Click here" link pre-fills the command line via `appendCmdLine()`
      with `mydsl login setup <character> <password>` so nothing has to
      be typed from memory or a text editor — running that command writes
      `MyDSL_login_credentials.lua` itself. "Don't ask again" persists via
      a small separate settings file (never touches the credentials file).
      `mydsl login setup` reopens it any time. `test/test_login_setup.lua`,
      11 assertions (setup writes a working file, bad input rejected, no
      password leaks into any echo, dismissal persists across reload).
      Needs live confirmation the popup actually renders/positions
      correctly and the command-line pre-fill really works in real Mudlet
      (the mock can't verify `appendCmdLine`/`clearCmdLine`'s real effect).
- [ ] **DslColors — 29 titles Steven had already added live promoted to
      shipped defaults, 2026-08-30.** Found via his own note ("the
      dslcolors new titles live in the config/settings file") — read
      straight from `DSL_PeopleColors_data.lua`'s persisted
      `DSL_COLOR_DB.titles` table in both `MyDSL` and `MyDSL Test`:
      Advocate, Apprentice, Caliph, Cardinal, Darkness, Duchess, Duke,
      Floramancer, Gadikli, Grunt, Guard, "High Priest", Jujumaster,
      Lieutenant, Ogrelord, Oneiromancer, Philanthropist, Priest,
      Purveyor, Raider, Royal, Sage, Scallywag, Seeker, Shadowhunter,
      Student, Tadpole, Troublemaker, Voivode — all real, previously
      user-added titles, not guesses. Promoted into
      `DSL_DEFAULT_TITLE_SEEDS`/signature (release6 → release7), same
      treatment "Professor" got 2026-08-29, in both the git-tracked
      reference copy and the live native profile. Needs a live check that
      the colors actually render right for a title in this new batch.
- [ ] **Leveling module's areas/routes/mobs data — not lost, just not yet
      copied to the new profile, fixed 2026-08-30.** All 40 areas in the
      live `MyDSL` profile's `leveling_areas.lua` turned out to be
      `source = "seed"` — i.e. exactly `MyDSL/leveling_areas_seed.lua`
      (already git-tracked) imported once via `mydsl leveling import`,
      not hand-built beyond that. Copied the file directly into
      `MyDSL Test/MyDSL/leveling_areas.lua` (pure world/mob reference
      data, not character-specific, same class as CreatureLore/ItemLore's
      already-shared DBs). Needs a live check: `mydsl leveling areas`
      should list all 40 in "MyDSL Test" now.
- [ ] **Item identify not reachable by click, root cause found + fixed
      2026-08-30** (Steven, "MyDSL Test" `notes.json`: "c ident pants...
      items arent persisting after identifying"). `identify` WAS
      persisting correctly the whole time (confirmed directly in
      `itemlore_db.lua`) — the real bug was every equipment/inventory/
      container hover-click site looking ItemLore up by the EXACT
      displayed short description, which DSL doesn't guarantee matches
      `identify`'s own canonical object name (real captured example, same
      session: equipment shows "a heat resistant pair of pants", identify
      reports "heat resistant pants" — neither string contains the
      other). Added `MyDSL.bestFuzzyMatch()`'s missing token-overlap tier
      plus a shared `MyDSL.resolveItemLoreRecord()` helper, wired into all
      4 click sites (equipment/others'-equipment/inventory/container).
      `test/test_itemlore_fuzzy_resolve.lua`, 8 assertions, all pass; full
      58-suite run clean.
- [ ] **LocationView's exits normalized to compass order, 2026-08-30**
      (Steven: "need to normalize those exits like live window
      (consistent)"). Was alphabetizing (`east north south west`) since
      `getRoomExits()` returns an unordered table; now sorts by compass
      position (N/NE/E/SE/S/SW/W/NW/up/down/in/out) matching the Live
      window's own natural reading order.
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
- [x] **Autologin — real redesign, BUILT 2026-08-30, needs live
      confirmation.** Popup-setup approach rejected by Steven ("lose the
      autologin, it makes it more combesom. unless you can pitch an
      actual functioning one from logs"). Rebuilt `MyDSL_Login.lua`
      around the real navigation sequence, cross-checked against an old
      native login trigger found in a 2026-07-17 profile snapshot
      (predates the 2026-08-26 security cleanup) plus this session's own
      real corpus logs — now in `docs/DSL_CommandRef.md`'s new "LOGIN /
      CONNECTION SEQUENCE" section. What it does now:
      - Full navigation: color prompt → continue → master login menu
        (`m`) → account name → password → master menu (`v`, View
        Characters) → character list. Every stage gated by an explicit
        state machine (`MyDSL.Login._stage`), never guesses from bare
        text alone (`"Your selection? ->"` appears at two different
        menus, disambiguated by stage).
      - First-run capture, no setup command needed: if `account`/
        `password` aren't saved yet, the module doesn't send anything at
        those two prompts — it watches the next line (confirmed reliable
        via real corpus: the typed-line echo is always the immediate
        next line) and saves it automatically. The captured password
        line is deleted from the console the instant it's captured
        (`deleteLine()`).
      - `mydsl login on|off` is now the whole sequence's master switch,
        not just password autofill; `mydsl login character on|off`
        unchanged (still independently OFF by default — which character
        to play varies by session); new `mydsl login forget` clears a
        bad first-run capture.
      - `MyDSL_LoginSetup` popup window removed entirely (registry entry,
        rendering, aliases) — no longer needed.
      - `test/test_login.lua` rewritten (33 assertions, drives trigger
        callbacks directly rather than simulating PCRE text-matching,
        which the test mock doesn't do); `test/test_login_setup.lua`
        deleted (tested the removed popup). Full test suite +
        `check_known_patterns.py --all` clean. `MyDSL_Full.mpackage`
        rebuilt, copied to `~/Downloads/` (confirmed the new module's
        actual text is inside the built package, not stale).
      **Needs Steven to actually log in once and confirm**: the
      navigation sequence sends the right commands at the right prompts,
      first-run capture saves correctly, and nothing echoes.
      **Password-trigger security note — per Steven, explicitly not
      being cleaned up right now** ("dont worry about the password
      trigger"): the old trigger's real account name/password still sit
      in plaintext in a handful of old, non-git-tracked profile snapshot
      files (`MyDSL/current/2026-07-17#*.xml`). Left alone per his
      instruction.
- [x] **Thinner UserWindow title bars — FIXED 2026-08-30, needs live
      confirm.** `MyDSL_ThemeEngine.lua`'s `MyDSL.Theme.titleBarCSS()`
      (the one shared function every docked window's title bar CSS comes
      from) had `padding: 4px 10px` — halved the vertical component to
      `2px 10px` (horizontal untouched, that only affects text inset not
      height). Applies globally, all 5 theme presets, no design decision
      needed since it's a straightforward "make the existing thing
      smaller" ask. Tests pass unchanged (none asserted the exact
      padding value).
- [ ] **Small icon/indicator for identified items** — Steven, same
      notes.json: "a small icon or indicator of identified items would
      be very useful, end of text has a colored small symbol?" Idea: a
      colored marker appended to an item's display line once
      `MyDSL.resolveItemLoreRecord()` confirms it's known/identified.
      Not scoped yet.
- [ ] **Skill-based affect tracking (e.g. `hide`)** — Steven, "MyDSL Test"
      `notes.json`: "its a skill not a cast, need a method for tracking
      skills like spells?" `MyDSL_AffectsView.lua`'s tracking today is
      built around cast/spell duration messages; a skill like hide has no
      equivalent "modifies X for N cycles" line to key off. Needs a real
      design pass — what real DSL output (if any) signals hide's start/
      end — before this can be scoped, same class of blocker as the
      bash/spell-cast-announcement corpus gap already tracked above.
- [ ] **TargetView: debuffs on target / aura auto-populate / scan
      auto-populate** — all three confirmed deferred until a real
      design+build pass (no corpus text to build against yet for the
      first two; the third needs a target-selection design decision).
- [ ] **Combat window/condenser — philosophy discussion closed 2026-08-29,
      resolved to a live-test check.** `MyDSL_CombatView.lua` re-read
      against the "11 loops" memory (that was actually `MyDSL_
      DataBridge.lua`'s double-fire, already fixed 2026-08-26 — see
      `docs/CHANGELOG.md`) and the raw/condensed/gag 3-way mode
      (2026-07-11 bug already fixed, 1.0 audit verdict: compliant, no
      flags). Steven's answer on whether the 3-way split still matches
      how he wants to control combat verbosity: "check the gags in the
      play test" — deferred to the same focused live session below
      rather than decided abstractly now; verify raw/condensed/gag mode
      switching feels right during a real fight, not just read the code.
      **Non-damage action text (bash's knockdown, spell-cast
      announcements) — scanned ALL 13 sibling Mudlet profiles' `log/`
      dirs 2026-08-29 (not just DSL2's own), not only this repo's: still
      zero real corpus text for either.** Every "bash" mention found is
      help-text/discussion, never an actual landed-attack message; zero
      spell-cast-announcement hits anywhere. Found (and confirmed NOT the
      same thing, don't conflate): `MyDSL_DataLayer_Combat.lua`'s
      existing `procStun` trigger ("X is knocked to the ground by Y") is
      PNP's weapon-proc flag `S`, not the `bash` skill; a `roundhouse`
      kick-to-floor message and a `knocked down Y's kick` block-message
      shape exist for other skills, real but also not `bash`. Good news:
      no new render-side code needed when real text does show up —
      `CV.appendSwing()` is already a generic "append one decorated line"
      hook, already used for non-swing text (the round-flush handler's
      condition note). **Scheduled as one focused live session** (bash
      something, cast something, grab the raw log; switch `mydsl combat
      mode raw|condensed|gag` during a real fight and confirm each feels
      right) — deliberately NOT folded into the native-content/mpackage/
      Mudlet-5.0 session, per Steven 2026-08-29 ("it can be a focused
      test, no it doesnt have to roll into the larger test").
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
- [ ] **Mapper — consolidated design + redesign, findings written up
      2026-08-29, decisions not yet made.** Full research (upstream sync,
      native Mudlet C++ source, package-ecosystem survey, and a direct
      architecture comparison against other games' mapper
      implementations) plus a concrete design recommendation now live in
      `docs/MAPPER_REDESIGN.md` — read that instead of re-deriving any of
      it. Short version: keep native `TMap` and GMCP-heuristic room
      matching (DSL sends no room vnum, confirmed no alternative exists);
      the real fix is splitting DSL-specific logic out of the modified
      stock-script copy into its own file (Mudlet's own wiki documents
      this as the difference between a sync-safe extension and what we
      currently do); integrate MyDSL's suite into the native right-click
      menu via `addMapEvent` (confirmed real, not a workaround); test
      native multi-point custom exit lines before building anything for
      the angled-exits want (may already be solved). 4 open questions for
      the design session listed at that doc's end, including
      standalone-package feasibility.
- [ ] **CreatureLore "mob diary" wiki window** — deferred; may fold into a
      larger DSL knowledgebase project alongside the Layer-4-remainder
      idea (see below).
- [ ] **Extend creaturelore/identify alias-shortcut pattern** to spells/
      skills/other commands — Steven: "this needs a larger design
      discussion" (still no named candidate commands).
- [ ] **Project-wide alias-dedup + namespace-guard sweep — approved, go
      ahead.** Real grep-driven audit, not started.
- [ ] **Quest-tracking mechanic — corpus blocker resolved 2026-08-29.**
      Steven approved building this as a pop-up widget similar to the
      Moon/Weather widgets. A Mudlet package-repository survey found
      `diku-prompt-handler` (Yetzederixx, DSL-specific, updated Feb 2025)
      with real, tested quest trigger patterns — quest-cooldown-cleared,
      quest-completed, the accept-gate (hour/half-hour timer grant), and
      the personal/gather-quest cycles variant. Ported into
      `docs/DSL_CommandRef.md`'s new QUESTING section, explicitly marked
      as externally-sourced and NOT YET cross-verified against our own
      `log/` corpus — confirm the first time one actually fires in a real
      session before treating it as settled. Still not built: the actual
      widget (design + `MyDSL_*.lua` module), and the sibling-profile
      autoquest-script check Steven separately asked for ("combine and
      check across profiles... we've had a couple" — `../PNP1`, `../PNP2`,
      `../DSL1`, etc.) hasn't been done yet, may turn up a second source
      to cross-check the ported patterns against.
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
- **`DSL PNP 4` package diff — checked 2026-08-29, not adopting.** Full
  file-by-file diff against our vendored `PNP files/` (both 50 files,
  identical filenames): 44 of 50 files byte-identical, one difference is
  just an install-path string, `DSL_data` differs but is personal
  save-state (not source, same class as our own `MyDSL_*_db.lua`).
  The 4 real code differences (`Gauges.lua`, `DSL_PNP_Gauges.lua`,
  `DSL_PNP_Ticktimer.lua`, `DSL_PNP_Xpgauge.lua`) are an in-progress
  refactor from `setGaugeStyleSheet()` to separate `setLabelStyleSheet()`
  calls, using `f"..."` string-interpolation syntax — **confirmed
  invalid on real LuaJIT** (`luajit -e 'print(f"x")'` →
  `attempt to call global 'f' (a nil value)`) — plus leftover debug
  `print()` statements left in `Gauges.lua`. Looks like unfinished/
  untested work in the upstream package, not a proven improvement.
  Moot for us either way: grepped our own `.lua`/XML source, nothing
  calls `setGaugeStyleSheet` directly. `PNP files/` stays as our
  reference copy, no update needed.
- **Mudlet 5.0's mapper — confirmed identical to what was already
  diffed, 2026-08-29.** Verified directly against the `Mudlet-5.0.0`
  git tag (not just the `development` branch, which could have drifted
  ahead) — same blob SHA, `generic_mapper.xml` version 2.1.10 in both.
  The earlier upstream 2.1.8→2.1.10 diff and the two ports already done
  (searchRoom nil-guard, area-hash preservation) are confirmed to be
  exactly what 5.0 itself ships, not a stale comparison.
- **Package-repo survey — design-reference leads, not directly reusable
  but worth remembering, 2026-08-29.** `calendar-todo-list` (Belgarath,
  generic) — small, clean `db:create()`-backed todo/event store with
  add/complete/recycle-old-entries lifecycle; worth reading before
  designing the DSL event/reminder module's own persistence layer (see
  that item under OPEN — Design ideas), even though nothing in it is
  DSL-specific enough to port directly. `MumeSpellTimers` (Khazdul,
  MUME-specific) — consolidated single-window spell/buff/malus/status
  tracker; a reasonable comparison point if `MyDSL_AffectsView.lua`'s
  own display ever needs a redesign pass, not portable as-is (MUME
  triggers). `HelpBrowsinator` (Demonnic, IRE-specific) — reroutes help
  output into a tabbed browser window, same idea as MyDSL's own
  in-addon help system; not portable (IRE-specific commands), but a
  UI-pattern reference if that system's presentation ever gets revisited.
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
  **2026-08-29 research (not a retest, doesn't resolve the question):**
  Mudlet 5.0's own release notes give measured numbers for the Geyser
  rewrite — -47.2% per layout move, -53.8% per layout resize — a
  positive but non-conclusive signal, since it confirms the layout
  engine was rewritten, not that this specific bug is gone. No
  deprecated/removed APIs found anywhere in 5.0 that MyDSL's code
  depends on (checked against `Geyser.*`, `registerAnonymousEventHandler`,
  `tempRegexTrigger`, GMCP handling, `table.load`/`table.save` — all
  clean), so staying on 4.20.1 indefinitely if the retest comes back bad
  carries no forced-migration risk either way. Also found several
  genuinely useful new APIs worth adopting once/if the upgrade happens
  (not before — no reason to write code against an engine we're not
  running): `getWindowGeometry()`/`windowVisible()` (could simplify the
  10 `MyDSL_windowstate_<Name>.lua` files' hand-tracked visibility/
  position state), `remainingNamedTimer()` (worth a look for
  `MyDSL_AffectsView.lua`'s affect-expiry countdowns), and a named fix
  for `setBackgroundImage()`'s "unreliable in Mudlet 4.20.1" comment
  already sitting in `MyDSL_LocationView.lua:22` — worth a direct
  retest of that specific comment once on a testable newer version.
- Most settings are character-bound; **window layout is the one
  deliberate exception** (not per-character). **Corrected 2026-08-29**:
  it's not per-profile either — `saveWindowLayout()` writes
  `windowLayout.dat`/`windowLayoutGeometry.dat` into the shared Mudlet
  config directory beside `profiles/`, confirmed against Mudlet's own
  test suite and live on disk (`~/.config/mudlet/windowLayout.dat`) — one
  file shared by every Mudlet profile on the machine, auto-loaded by
  `loadWindowLayout()` at every profile's startup. Since dock widget
  object names are profile-name-scoped, `mydsl layout save` in a profile
  makes THAT SAME PROFILE NAME start with the arrangement again after a
  delete+reinstall; a differently-named profile doesn't inherit it. Full
  writeup in `docs/MyDSL_MudletWindowManagement.md`.
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
