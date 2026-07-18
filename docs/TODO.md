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

- [ ] **DSL Generic Mapper: new fork doesn't recognize Steven's existing,
      already-mapped rooms — instrumented, root cause NOT yet confirmed,
      no fix shipped.** Per Steven: "the new mapper using the generic
      mapper data is not recognizing the old rooms so i manually place
      rooms on top of eachother in the map editor window and use merge
      rooms command." Two separate things got conflated mid-investigation
      and had to be walked back: "The Wing of the Stone Dragon" showing
      up as multiple same-named-but-different-text rooms is confirmed by
      Steven to be **real DSL game design** (a themed maze with
      intentionally repeated room names, different physical rooms) --
      `MyDSL_LocationView.lua`'s own variant system (`name`/`name (2)`/
      `name (3)`, already built) is exactly the intended mechanism for
      assigning separate pictures to these, not a mapper bug. An attempted
      "fix" that made `check_room()` accumulate description variants
      instead of ever rejecting a mismatch was built on the wrong premise
      (confusing this with issue below) and was fully reverted before
      shipping -- would have broken the maze differentiation this fork
      exists to protect. **The real, still-open issue**: `check_room()`
      has two unconditional hard-reject checks before description is ever
      considered -- exact room name match, then exits compatibility --
      neither has any leniency for a formatting/capture difference the
      way the description check does (empty stored description = adopt,
      not reject). Root cause not yet confirmed: could be name capture,
      exits capture, or something else entirely; none of today's other
      mapper changes (bug fixes, weight/color, dslroom raw) touch this
      code path, so if this is a regression it most likely predates this
      session, inherited from the original unintegrated 0.1.0-0.2.2 fork.
      Added a debug-only diagnostic echo to the exits-rejection path
      (`check_room()`) mirroring the one the description check already
      had, so a real rejection now shows its exact reason in the log
      instead of only ever surfacing as an unexplained duplicate room.
      **Next step**: Steven runs `map config debug true`, walks into one
      already-mapped room he's certain exists, and reports what the log
      shows -- either a clean match (nothing to investigate) or a
      "Room X rejected: ..." line with the specific reason, which is real
      evidence to fix from instead of another guess. `.dat` map files
      themselves are Qt's binary serialization format, confirmed not
      practically parseable directly -- this live debug-echo path is the
      real diagnostic route.
      **Major update, same day, from Steven's own screenshots + debug
      log**: this IS reproducing, and traced to a specific, real
      mechanism. Two different code paths handle "arriving at a new
      room": `find_link()` (searches by coordinate position stepping from
      the current room; creates a new room via `create_room()` if nothing
      matches -- this is the path that produces the "creates an
      additional room" symptom) vs `map.find_me()` (searches by NAME
      across the whole area; if nothing matches, only echoes an error and
      leaves `map.currentRoom` untouched -- **this is the path that
      produces "position display stuck on the previous room"**, since
      nothing ever calls `set_room()` or `create_room()` on this branch).
      Confirmed directly from a screenshot's debug log: arriving at "The
      Tail of the Stone Dragon" rejected 5 already-existing same-named
      candidate rooms (13702/13703/13707/13708/13709) each for a specific
      missing exit direction, then hit `(error): Room not found in map
      database` -- the `map.find_me()` dead-end, explaining exactly why
      Steven's position display stayed on "The Wings of the Stone Dragon"
      after really walking to the Tail. `move_map()` only takes the
      room-creating `find_link()` path when BOTH `map.mapping` and the
      captured move direction are truthy; confirmed via the same log that
      `map.mapping` should be `true` (only one "start mapping", zero
      "stop mapping" the whole session) -- pointing instead at the
      captured move direction (`move`, drawn from `move_queue`) being
      empty/nil at the exact moment this room resolved, i.e. a movement-
      queue desync, not a mapping-toggle issue. This is the SAME
      `move_queue` this fork's own `onMoveFailCleanup()` comment already
      flagged as fragile ("stale look/search entries can sit ahead of the
      failed move"). Added one more debug-only diagnostic echo right at
      the `find_link()`/`find_me()` decision point in `move_map()`,
      printing `map.mapping`/`move`/`random_move` at that exact instant --
      the next real occurrence will show directly whether `move` really
      is nil, confirming or ruling out the move-queue-desync theory
      before attempting a fix. No fix shipped yet -- still gathering
      evidence, not guessing.
- [ ] **DSL Generic Mapper fork brought into the repo, reviewed, and
      hardened — needs a manual install swap + live confirmation.** Per
      Steven ("its time to incorporate the mapper and make it for DSL not
      generic, too many small issues seem to be occurring"). This
      supersedes the 2026-07-17 "harden the mapper" investigation
      (`CHANGELOG.md`), which correctly found no bug in *stock*
      generic_mapper at the time -- Steven's ask this time is different:
      replace stock generic_mapper with a maintained DSL-specific fork,
      not fix a specific bug in the stock one. Found real prior art
      already sitting in `~/Downloads/` (`DSL_Generic_Mapper_
      Minimal_Hardening_Scope.md` + versions 0.1.0-0.2.2, dated
      2026-07-02/03, predating this repo's current workflow) -- a
      conservative-fork layer on top of unmodified Generic Mapper 2.1.8,
      never actually deployed (confirmed: the live MyDSL profile was
      still running stock generic_mapper). Reviewed 0.2.2 in full against
      its own scope doc: 7 of 8 required hardening items were already
      correctly implemented (description-matching default, DSL movement-
      fail/restricted-exit patterns fed into Generic's own onMoveFail
      handling rather than a parallel system, all 11 required door
      patterns, GMCP assist that explicitly never creates rooms directly,
      room-description capture matching our own `MyDSL_DataLayer.lua`
      technique, sector metadata with a GMCP-vs-terrain-command conflict
      flag, and a thoroughly-disabled self-updater -- traced every
      download-related code path to confirm none are reachable anymore).
      Found and fixed 3 real bugs before deployment: (1) the door-verb
      command parser used `cmd:match("^(open|close|lock|unlock|pick)...")`
      -- `|` is not an alternation operator in Lua patterns (that's a
      regex-only construct), so this could never match ANY real command;
      the entire door-verb capture was dead code in the shipped 0.2.2
      build. Fixed with a per-verb loop. (2) Once verb-matching actually
      worked, a second bug surfaced: "open backpack"/"close pouch"-style
      container actions (DSL's own help confirms `open <object|
      direction>` are both real syntax) got silently misattributed to
      the last movement direction instead of correctly resolving to no
      room exit at all -- fixed by clearing both pending door/move
      contexts on a non-directional action. (3) `last_door_command`/
      `last_move_command` recorded a timestamp that nothing ever checked
      -- added a 6-second freshness window so a stale context can't be
      replayed against a much later, unrelated message. All 3 verified
      via structural tests (`test_mapper_fork_fixes.lua`). Also
      cross-referenced all patterns in the English Failed Move (25),
      DSL Door State Capture (15), and DSL Terrain Capture (11) triggers
      against the full log corpus (DSL2 + MyDSL + PNP/DSL1 sibling
      profiles): the large majority confirmed real with direct quotes; a
      handful unconfirmed but harmless (likely valid for other MUDs
      Generic Mapper supports); one real gap found and fixed -- the
      "standing too close to the lock" door-block message was hardcoded
      to one specific NPC name ("A New Thalosian gate guard") when the
      real message is a generic template any NPC can trigger (confirmed
      via 4 different real NPCs producing the identical message in
      sibling logs) -- wildcarded to match any NPC. Brought into the repo
      as `DSL_Generic_Mapper.xml` (git-tracked source) +
      `docs/DSL_Generic_Mapper_Scope.md` (the controlling scope note).
      Packaged separately as `DSL_Generic_Mapper.mpackage` -- this is a
      **replacement** for stock `generic_mapper`, not additive; installing
      it requires uninstalling the stock package first (same class of
      manual step as disabling the native `(autowhere)` alias). Not yet
      live-tested at all -- needs Steven to actually install it and play
      for a while before any of this closes.
- [ ] **DSL Generic Mapper: room weight from real movement-point cost +
      terrain-based room coloring — built 2026-07-18, needs live
      confirmation.** Per Steven ("hook up all the features we can... the
      terrain and room weights"), researched Mudlet's own Manual:Mapper
      Functions wiki page for `setRoomWeight`/`getRoomWeight`/`setRoomEnv`/
      `setCustomEnvColor` semantics before building anything (confirmed:
      every room defaults to weight 1, higher = less desirable to
      pathfind through; environment IDs 1-16 and 257-272 are reserved by
      Mudlet). First implementation used a hand-picked sector-to-weight
      table -- Steven caught this immediately ("dont make up weights, the
      room weight should be added as a player walks through and uses
      movement points to determine") and it was replaced before shipping.
      Real mechanism: `map.dsl.captureMovePoints()` records
      `gmcp.char_data.move` (the same real GMCP field
      `MyDSL_DataLayer.lua` already reads) the instant a movement command
      is sent; `map.dsl.applyMoveCost()` reads it again once the
      destination room resolves and stores the delta as that room's
      observed entry cost, averaged across repeat visits
      (`dsl.move_cost_samples`/`dsl.move_cost_total` room userdata) so one
      visit landing on a natural regen tick can't permanently skew the
      weight. Guards: cost outside a plausible 1-20 single-step range is
      discarded rather than corrupting the average; a room the player
      manually re-weighted via the native `rw` alias is never touched
      again (that alias now stamps `dsl.weight_source="manual"`). Room
      coloring is a separate, purely cosmetic feature (not a data claim
      the way weight is) -- `map.dsl.applySectorColor()` maps the
      already-confirmed-real sector categories to custom environment
      colors via `setCustomEnvColor()`/`setRoomEnv()`, registered once at
      install. No manual-override guard exists for color specifically --
      Mudlet's native map-UI right-click recolor calls `setRoomEnv()`
      directly with no script hook to intercept, so a manual UI recolor
      could get reverted on that room's next auto-color pass; accepted as
      a cosmetic-only tradeoff. Verified via a dedicated structural test
      harness (`test_move_cost_weight.lua`): a real cost becomes the room
      weight, a regen-tick (negative-cost) reading is correctly ignored,
      repeat visits average into a stable weight, and a manually-set
      weight is never overwritten. Not yet live-tested.
- [ ] **DSL Generic Mapper: `dslroom raw` is now a one-stop room-info
      command — built 2026-07-18, needs live confirmation.** Per Steven
      ("can i view room info in this package? like description name
      weights terrain features etc"). Turned out most of this already
      existed natively -- `rl`/`room look` (stock Generic Mapper) already
      shows name, area, coordinates, weight, environment color,
      description, exits with their weights, special exits, and per-room
      map features. `dslroom raw` now calls `map.roomLook()` first (reused
      directly, not re-implemented) and appends only the DSL-specific
      fields it doesn't know about: GMCP/terrain-command sector, sector
      conflict flag, and weight source with real movement-sample count +
      average cost. One command instead of two scattered ones. Not yet
      live-tested.
- [ ] **DSL Generic Mapper: `dslroom raw` showed blank fields instead of
      "not set yet" — fixed 2026-07-18, confirmed against Steven's real
      log output.** Steven's own live test surfaced `Room weight: 1
      (source=, samples=, avg cost=0.0)` -- checked the actual log
      (`MyDSL/log/2026-07-18#14-04-19.html`) and confirmed the real root
      cause: `getRoomUserData()` returns an EMPTY STRING for an unset
      key, not `nil` -- so plain `tostring(getRoomUserData(...))` silently
      printed a blank instead of a clear placeholder. New
      `map.dsl.dsl_ud(rid, key, placeholder)` helper wraps every display
      read in `roomRaw()`/`dslroom raw` so this can't recur field-by-field;
      confirmed the underlying weighting/coloring *logic* was never
      affected by this (it already compared against a specific non-empty
      string like `"manual"`, or explicitly checked for `""` itself where
      it mattered) -- purely a display bug. Also confirmed via the same
      log why that specific room showed 0 movement samples: the
      character was flying the entire time (`MV` stayed at 140/140
      across every prompt line in the log, never dropping), and DSL
      appears not to charge movement points for flying -- the
      real-cost-based weight system can only ever learn from movement
      that actually costs MV, so a flying character will rarely
      accumulate real weight data. Not a bug, a real limitation of this
      specific data source; noted for Steven, not silently assumed.
      Verified via a dedicated structural test
      (`test_dsl_ud_display_fix.lua`) replaying the exact blank-output
      scenario. Not yet re-tested live.
- [ ] **PlayersNear font size not surviving a reload — fixed 2026-07-18,
      needs live confirmation.** `MyDSL_RouteHelper.lua`'s `FONT_SIZE_OVERRIDES`
      seed table only ever read `MyDSL_History`'s size back from disk at
      file load; `MyDSL_PlayersNear`'s font command (added 2026-07-16)
      never got a matching seed entry, so every reload silently reverted
      to the hardcoded default regardless of what was actually persisted.
      Fixed by seeding both. Checked every other window's font
      persistence for the same class of bug — everyone else reads
      `MyDSL.Windows.getFontSize()` fresh inside their own render
      function rather than caching it at load time, so this was specific
      to RouteHelper's two routed windows.
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
      style. Syntax-checked. Superseded 2026-07-17 by a project-wide fix
      to this same file (see the chat item above) -- every `[^']+` zone
      (including this one) now uses a name-character class that also
      tolerates an apostrophe mid-name, so a Bloodbath message from a
      character with an apostrophe in their name routes correctly too.
- [ ] **`setspell` bare-command gives no usage feedback — fixed
      2026-07-16, needs live confirmation.** Confirmed Steven's exact
      case (2026-07-16): bare `setspell`, no args. Added
      `CA._aliases.setSpellUsage` (`^setspell$`) calling
      `setSpellInfo()` with no args, which already has a real usage
      message (`ce("usage: setspell <bless|fireproof> <spell|wand|
      skill> [name]")`) for malformed input — just wasn't reachable for
      the zero-arg case before. Syntax-checked.
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
      2026-07-17, real root-cause bug found and fixed 2026-07-18, live
      testing 2026-07-18 confirms the OPEN-door direction but still
      reports an issue on CLOSE.** Original root cause (confirmed by
      decoding the live `location_variants.lua` data, Mudlet's
      reference-indexed `table.save` format, resolved offline with a
      small script): 0 of 137 saved variant records anywhere ever had a
      description — 20 rooms had already spuriously split into 2-6
      "variants" apiece, because `M.roomData()`'s fixed source-priority
      order let `MyDSL.DB.room` (no description field) win before
      `MyDSL.State.room` (the only source with one) was ever reached, so
      `resolveVariant()`'s precise description-tier was dead code and
      everything fell through to comparing exits alone — which change
      whenever a door/gate opens or closes. Fixed by having `M.roomData()`
      backfill `description`/`descColor` from `MyDSL.State.room` after
      the priority loop picks a winner. Per Steven's 2026-07-18 live test:
      "open door seems fixed" but "still cause[s] the issue with clos[ed]
      door." Re-checked `location_variants.lua` after this test: "Inside
      Arkane's north gate" still shows exactly the same 2 pre-existing
      variants as before (both still `description=nil`, `seen` unchanged)
      — no 3rd variant was created, and tracing `resolveVariant()`'s own
      exits-fallback tier shows BOTH the open and closed exit sets should
      still correctly match their respective pre-existing (already-split)
      variant either way, so a fresh spurious split isn't the obvious
      explanation for what Steven's seeing on close specifically. Genuinely
      unclear without more specifics — the "new variant" notice
      (`M.refresh()`'s `missingCaption`) only ever fires once, at the
      moment a variant is newly created, not on every revisit of an
      already-known one, and it renders inside the Location window itself
      (fixed 2026-07-17 to stop going to the main console), so it doesn't
      show up in the plain-text session log either. **Needs a screenshot
      or the exact text Steven sees when the door is closed** before
      changing anything further — the ~20 rooms that already split
      spuriously before this fix (including this one) are also NOT
      retroactively cleaned up by it; only new captures are affected, so
      some of what's being seen now may just be the pre-existing split
      itself (mismatched/missing picture files per variant), not a new bug.
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
- [ ] **Layer 4: Reference library** — items done (`MyDSL_ItemLore.lua`/
      `MyDSL_ItemReference.lua`, confirmed live 2026-07-18) and mobs/lore
      done (`MyDSL_CreatureLore.lua`/Bestiary, confirmed earlier). Whatever
      remains under this heading (areas/zones/general lore, if that was
      ever the intent) not scoped — check
      `~/Downloads/Shattered-Archive-release-dev.zip` before building
      from scratch if picked up.
- [ ] **Inventory hover scope expansion (hover on carried-not-worn items)
      + ground-vs-inventory name mapping** — explicitly deferred by
      Steven 2026-07-18 ("not sure we need"), not a live bug. Equipment
      hover already works; this was extending it to plain inventory
      items. The name-mapping half was already answered empirically
      2026-07-16 (real corpus check found ~2/3 of items have a clean
      substring match between their ground and inventory text, but a
      real fraction don't — `"a bag of holding"` -> `"A strange bag lays
      here..."` — so any mapping would need to be best-effort with a
      manual-override path, not assumed complete). Revisit only if Steven
      asks again.
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
