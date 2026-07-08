# DSL Observer UI — TODO
*A current punch list only — resolved/historical items live in `CHANGELOG.md`
and git history, not here. Restructured 2026-07-06 (see CHANGELOG for why).*

---

## FULL MUDLET OBJECTS INVENTORY (2026-07-07)

*"Mudlet objects" = the working term for everything Mudlet tracks as a
profile item: triggers, aliases, timers, keybinds, scripts — native
(GUI-configured, lives in `current/autosave.xml`) or `.lua`-file-based.
Built per Steven's request for a full picture of ALL of these, native and
MyDSL side together, not just the `.lua` files treated as a separate
"external reference." Scale confirmed directly against `current/
autosave.xml` (28,606 lines): 142 TriggerGroups (141 active, 1 dormant),
613 individual Triggers, 43 Scripts, 66 Keys, 25 top-level Aliases (plus
the already-tracked itemstats sub-tree, hundreds of per-item aliases, not
enumerated here). 0 Timers.*

### Native TriggerGroups with no MyDSL equivalent at all yet
Real candidates for future integration, beyond what's already tracked
(Phase F Highlighter+DslColor, Layer 4 itemstats replacement):
- **Random Affects** — 11 stat-fluctuation flavor messages (agile/
  focused/weak/etc).
- **Spells** category — Benedictions/Detection/Protection/Transportation/
  Enhancement sub-groups. AffectsView tracks spell *duration*, not these
  categorized notification triggers — different purpose, may still be
  worth a look.
- **Weather Conditions** — Rain/Breeze/Wind/Snow sub-groups, more
  specific than MyDSL's current generic weather regex. Worth checking if
  the weather trigger ever needs more precision than the word-boundary
  keyword fix already gives it.
- **Atmosphere**'s AGL/Areas/Sailing sub-groups — no MyDSL equivalent.
- **66 Keys** (movement, Scan/Where/Affects/Look/Exits, per-direction
  door-opening) — a completely different object category from anything
  ported so far (raw keybindings sending commands directly, not triggers
  reacting to game text).
- **~20 misc top-level Aliases** — `(inv)` all-bags inventory, `(oac)`
  order-all-kill, `(autowhere)`, `(RV)` recall-vale, `(safetoleave/
  return)`, `(casual)`/`(combat)` attire-swap sets, start/stop-writing,
  smoke-effect aliases (change sex/cure light/serious/critical), `(k)`
  kill/murder, `(kall)` knock-all, `(clear)` room-clear, `(whobe)`, a `PQ`
  (personal quest) family (request/info/time/complete/find/hunt).
- **`DslColors_v1_0_pirate_title_plus_rank_defaults`** (+ matching Script
  entries `DslColors_v1_0`/`DslColors_Core_v1_0`) — confirmed real, active,
  currently loaded (`"[DslColors v1.0 RELEASE] loaded. Use: dslcolor
  test"` seen directly in today's fresh log, tracking per-person "facts").
  **Read in full 2026-07-07 (3220-line native script) — see Phase F below,
  this turned out much bigger than "the DslColor half of a merge."**

### RETRACTED 2026-07-07 — "confirmed duplicate" claim below was wrong
The original inventory claimed `"Toasts/History Captures"` and `"Trumpet
Sounds and History"` were two trigger *groups* with byte-for-byte identical
children routing chat channels (tells/says/gossip/etc) to the same
destinations, and named this the likely root cause of "clan gossip
duplicates." Re-verified directly by parsing `current/autosave.xml` with
Python's `xml.etree` (name/path/script/regex list, not a truncated text
scan) while trying to write exact GUI steps for Steven to disable one —
**both claims were false.** They're each a single leaf `Trigger`
(`isFolder="no"`), not a group, both living directly under a top-level
`Notifications` folder, and their scripts/regex lists are completely
different from each other: `Toasts/History Captures` matches PvP kill-toast
phrases (`"got (offed|killed|toasted|RAMPAGED|ROCKED) by"`,
`"got ***DESTROYED*** by"`); `Trumpet Sounds and History` matches an
unrelated set of kingdom-join/retirement/achievement announcement phrases
(`"joins the kingdom of..."`, `"has set forth on a more peaceful
life..."`, etc). **Neither one matches gossip/tell/say/yell/whisper text
at all.** A full re-scan of every native trigger's regex list for
"gossip" found only three distinct, non-duplicate triggers under `Chat
Routing` (`Clan Gossip`, `Dragon Gossip`, `Gossip`) — no duplicate pair
there either. **The real cause of "clan gossip duplicates" is unknown
again** — this lead is dead, re-opened as unsolved below. Nothing was
disabled based on the wrong claim (good thing — it would have removed two
legitimate, unrelated notification features for no reason). Lesson: the
original inventory was a fork's summarized report, taken at face value
without independently re-parsing the source XML at the time — same root
category of mistake as the two EMCO alias corrections, now confirmed to
apply to the native-XML inventory step too, not just doc-writing.

### Dead windows — but NOT simple garbage, check the idea backlog first
4 of 18 registered `MyDSL_*` windows have zero code feeding them:
`MyDSL_Inventory`, `MyDSL_Equipment`, `MyDSL_AsciiMap`, `MyDSL_Banner`.
**Unlike the removed `MyDSL_Bloodbath`, all four of these match a planned-
but-unbuilt idea already sitting in `MyDSL_IdeaBacklog.md`** — "Inventory
window, Equipment window" and "Banner/announcement window" are listed
directly; `"map 15" transparent silent-updating window, top right, ASCII
terrain map` matches AsciiMap. These are pre-registered placeholders
waiting for their display module, not abandoned dead code — don't remove
without checking that against Steven's actual intent first.
Data readiness: `MyDSL.State.inv` and `MyDSL.State.equipment` both already
exist (equipment from today's Phase E) but neither is ever rendered into
its window — the display module is the missing piece, not the data.

### Dead code — confirmed and fixed 2026-07-07
- **`MyDSL_MoonWeather.lua`**: `MW.onLunarUpdate`/`onWeatherUpdate`/
  `onTickUpdate`/`onTimeUpdate`/`onLoginUpdate` — all five fully written,
  zero references anywhere outside their own definitions (confirmed via a
  whole-codebase grep, refining the inventory's initial count of four —
  `onTickUpdate` is dead too). `_registerHandlers()` was refactored at
  some point to use inline anonymous closures instead of calling these
  named functions, and the originals were never deleted. Removed.

### Unwired capture pipelines — ties into the existing systematic audit below
`MyDSL_DataLayer.lua` has 17 fully-written functions across 7 complete
begin/parse/end capture pipelines that **no trigger anywhere ever calls**:
`beginWhok`/`parseWhokLine`/`endWhok`, `beginWhoc`/`parseWhocLine`/
`endWhoc`, `beginInv`/`parseInvLine`/`endInv`, `beginMap`/`parseMapLine`/
`endMap`, `beginAffectsText`/`parseAffectsTextLine`/`endAffectsText`,
`parseImproveLine`, `parseUnreadLine`. This is more precise than the
existing "IN PROGRESS — systematic bottom-up integrity audit" section's
hedge ("not yet audited: ... inv, unread, improve ... whok/whoc") — these
aren't just unaudited, they're confirmed unreachable. Not fixed this
pass — needs a decision on whether each one still matters (`inv`/`whok`/
`whoc` plausibly tie to the same "not built yet" display-module gap as
the dead windows above) before wiring trigger calls to them.

### Confirmed integrated (native → MyDSL, working)
Combat (`Battle.lua`), Moons/Weather (partial), Tick (`Ticktimer.lua`),
Roller, Equipment-parsing, chat-verb formats (mined from the dormant
"Chat Routing" group).

---

## OPEN — Needs live confirmation

- [ ] **Logging defaults reworked 2026-07-07, per Steven.** Combat/chat/
      history stay on by default (useful to review later); group/
      righthere/target/scan/bloodbath/playersnear are now debug-only, off
      by default. Chat specifically now routes its `mydsl log chat
      on/off` through EMCO's own `enableAllLogging()`/`disableAllLogging()`
      instead of `MyDSL.logWindow()` (chat never went through that system
      at all — EMCO already had its own real per-tab logging). Verified
      via the emulation harness (correct defaults, chat toggle calls the
      right EMCO methods) but not yet confirmed live — check that
      `mydsl log <category> on` actually re-enables a debug-only window's
      log file next time one is needed.

---

## IN PROGRESS — PNP/EMCO cannibalization (comprehensive pass, 2026-07-06)

Full plan: `/home/owner/.claude/plans/soft-twirling-thunder.md` (approved).
Trigger: today's `ChatTriggers` rewrite got several patterns wrong when the
real answer was sitting in Mudlet's native trigger tree the whole time —
stop patching module-by-module, do one deliberate pass. Each phase is its
own branch per the project's "one module/bug per branch" rule.

- [x] **Phase A — ChatTriggers correction + CLAUDE.md fix.** Done this
      session, see the ChatTriggers entry above and the command-surface
      section below. Needs Steven's live confirmation like everything else.
- [x] **Phase B — AffectsView completion, reassessed 2026-07-07: already
      substantially done, not actually a gap.** The plan's initial
      scoping (from the earlier inventory fork's summary) was wrong —
      read all four PNP sub-files in full, then re-read the *actual
      current* `MyDSL_AffectsView.lua` before assuming anything needed
      porting, and found:
      - `.bar.lua` (persistent color-coded active-affects grid) is
        functionally superseded by the existing `A.display()`/
        `echoActiveRows()` — same red/yellow/green remaining-cycles
        thresholds (`colorForDuration()`), rendered as a Geyser window
        grid with clickable recast links instead of PNP's raw icon-image
        labels. Arguably better, not missing.
      - `.respell.lua` is already ported near-verbatim as `A.respell()`/
        `A.spellup()` — same exclusion syntax (`!name`), same
        tracked-list merge, same active-duration check, same recast
        dispatch. Confirmed `A.recast()` is only ever reachable via the
        user-initiated `respell`/`spellup` aliases or a clicked link —
        stays compliant with "user-initiated only."
      - `.flags.lua` (prompt-integrated tag display) is **not** ported,
        but its unique value beyond what's already there is negligible —
        DSL2 already replaced PNP's text-prompt system with GMCP-first
        PromptView (a previously recorded correct decision), and the
        underlying data need (tracked-spell whitelist + near-expiry
        highlight) is already covered by `A.tracked`/`A.track()`/
        `echoMissingRows()`. Not scoping a redundant prompt-tag variant
        unless specifically wanted later.
      - `.gag.lua` — **CLOSED 2026-07-07, not built.** Auto-sends the
        `affects` command with no user action whenever a new spell/buff
        lands, gagging the auto-triggered output. Reopened briefly for
        discussion per Steven rather than excluded unilaterally, then
        closed once the countdown fix (below) made it moot: the local
        per-tick decrement means affects durations no longer need any
        server re-query to stay accurate, so `.gag.lua`'s entire reason
        for existing doesn't apply to DSL2. Not excluded on philosophy
        grounds this time — excluded because the problem it solved is
        already solved a different way.
      No code changes made this phase — the "gap" simply wasn't real
      once verified against current source instead of a summary.
      **Real bug found and fixed while re-verifying, 2026-07-07:** Steven
      flagged that affects timers didn't seem to count down correctly.
      Confirmed two real bugs: (1) `entry.duration` was set once by GMCP
      and never decremented locally between updates — frozen/stale until
      the next `add_affect`/`remove_affect` event, not a live countdown
      at all; (2) the "real minutes/seconds" timer-mode display looked up
      `MyDSL.DB.timers.affects[name].text`, but nothing anywhere ever
      populated that table — `timerMode = "time"`/`"both"` silently always
      fell back to cycles-only. Checked whether GMCP itself could be
      relied on to keep this fresh instead (relevant to the `.gag`
      question too) — confirmed via `DSL_CommandRef.md`'s own existing
      note that `gmcp.affect_data` only fires reactively (typing
      `affects`, or a spell starting/ending), not as a periodic push, so
      GMCP alone can't cover this. Fixed with a purely local, zero-
      server-command approach instead (matches `.bar.lua`'s own
      `decrement_affects()`, hooked to its `onTick` there): new
      `A.onTickUpdated()` decrements every active affect's duration by 1
      on `MyDSL.Tick.Updated` (fires once per real game tick), while
      GMCP add/remove events remain authoritative and always overwrite it
      on any real change, so it can't drift permanently. Real-time display
      now computed directly from `MyDSL.DB.tick.average` (the same field
      `MoonWeather`'s clock already uses for this exact conversion) plus
      `MyDSL.DB.tick.remaining` for smooth between-tick counting, instead
      of the dead lookup table. Verified via the emulation harness: a
      real affect ticked down 10→7 over 3 simulated ticks, display
      renders without error, permanent-duration (-2) affects correctly
      skip the real-time conversion.
      **Regression found via live testing, fixed same day:** Steven
      reported affects counting down in ~2-3 real seconds instead of
      ~40. Root cause: `"MyDSL.Tick.Updated"` does not mean "one real
      game tick happened" — `MyDSL_TickSource.lua`'s `T.publish()` raises
      it unconditionally from every caller, including `T.updateTimer()`'s
      own ~0.25s internal progress-bar loop, not just the real once-per-
      tick event, and no reason string is passed through to tell them
      apart. Fixed by guarding on `MyDSL.DB.tick.ticks` actually changing
      (an integer only the real per-tick function increments) before
      decrementing, instead of decrementing on every event firing.
      Verified via the emulation harness: 20 simulated fast-pulse firings
      with no real tick change now correctly cause zero decrements; each
      actual tick-count change causes exactly one. Needs Steven to
      re-confirm live that it now counts down at the right real-world
      pace, plus the color warning (red near-expiry) and real-time
      display, now that the underlying data is actually correct.
- [x] **Phase C — Roller, done.** See the "Roller" item above.
- [x] **Phase D — Character-assist module, done 2026-07-07.** New
      `MyDSL_CharacterAssist.lua`, ported from `DSL_PNP_Character.
      disarm/spellup/standup.lua`. Unlike every other phase, this one
      *does* send real game commands — reviewed and explicitly approved
      per-feature with Steven first (2026-07-07), rather than excluded on
      principle like `.gag.lua`:
      - **Rearm**: both the auto-trigger (fires instantly on any of 4
        weapon-disarm or 2 shield-disarm message forms) and the manual
        `rearm` alias, matching PNP exactly (both existed together there
        too — the manual alias is a backup for when the auto-trigger
        can't fire, e.g. while blind).
      - **Standup**: auto-sends `~`+`stand` on a "knocked senseless"
        trigger, no manual alias (PNP doesn't have one either).
      - **Spellup**: `setspell`/`bless <slot|all>`/`fireproof <slot|all>`/
        `stop spellup`/`resume spellup`/`ignore bless|fireproof <slot>`,
        full port of PNP's per-item cast/remove/re-equip loop with a
        20-second failsafe timer.
      Built a `useItem(slot, command, location)` port (PNP's own command-
      sending primitive) in this module specifically — not in
      `MyDSL_DataLayer.lua`, which stays passive-only. Derives an item's
      targeting keyword from its name (strip filler words) rather than
      porting PNP's "set keyword" manual-override alias — v1 is
      auto-derive only, revisit if it guesses wrong often enough to
      matter. **Vision check fixed and confirmed 2026-07-07** after
      Steven did live in-game blind testing and captured a real GMCP dump
      (`lua display(gmcp)` while actually blinded) — found
      `gmcp.room_data.room` becomes the literal string `"darkness"`,
      exactly the same value PNP's own text-prompt parsing checked, just
      reached natively through GMCP. `MyDSL_DataLayer.lua`'s
      `gmcp.room_data` handler already stores this directly
      (`MyDSL.State.room.name = d.room`) — no new trigger needed, the
      data was already there. Switched `checkVision()` from the earlier
      unverified `MyDSL.State.room.sector` substring guess to checking
      `MyDSL.State.room.name == "darkness"` directly. Also confirmed two
      simpler exact-text alternatives in the same test session (not used
      as primary, but available): `"You are blinded!"` / `"You can see
      again."` fire on the exact start/end of blindness. Re-verified via
      the emulation harness across all three vision states (can-see,
      blind, no-light-but-glowing-item) with real room-name transitions —
      each produces the exact right command sequence PNP's logic
      intends. Verified everything else via the emulation harness with
      real `DataLayer`-built equipment state: rearm (combat + full),
      rearm-shield, standup, the worn-duplicate "2.keyword"
      disambiguation, and a complete `fireproof all` run (start →
      per-item advance → completion) all produce the exact right command
      sequences with zero errors. Needs Steven to confirm the vision
      check specifically live, now that it's using confirmed real data
      instead of a guess.
      **Deliberately not built**: `DSL_PNP_Affects.gag.lua`'s auto-refresh
      — separate open discussion under Phase B above, not decided yet.
- [x] **`MyDSL.logWindow()` fragmented multi-call rows into separate log
      lines — fixed 2026-07-07.** Found sampling today's per-window logs
      (Steven's request, after the live testing session): GroupView's and
      TargetView's logs came out one word/segment per line instead of one
      coherent row, since those views build a single visual row from
      several separate `decho`/`dechoLink` calls and `logWindow()` wrote
      a full log line per call regardless, always appending `\n`.
      Combat/RightHere/History never hit this since those modules already
      pass one complete line per call. Fixed at the shared function level
      — buffers per category now, only flushes when a `\n` actually shows
      up in the accumulated text. Verified via the emulation harness:
      GroupView's exact fragmented-call pattern now produces one line per
      row; single-call callers (Combat-style) unaffected.
- [x] **Phase E — Equipment, done 2026-07-07.** Ported the passive-capture
      half of `DSL_PNP_Character.equipment.lua` into `MyDSL_DataLayer.lua`
      Section 9r (`beginEquip`/`parseEquipLine`/`endEquip`, new
      `MyDSL.State.equipment`/`MyDSL.Data[char].equipment`). Deliberately
      NOT ported: PNP's `useItem()`, which sends commands (wear/wield/get)
      — that's an interactive convenience that belongs in a future
      display-module button, not Layer 1 (this file's own header says
      "never sends commands to the game"). Real format confirmed against
      154 unique equipment lines across 113 full blocks in the clean
      corpus (`"<worn on torso>  a sub issue vest"`,
      `"<used as light>  (Fireproof) (Glowing) an illuminating crystal
      shard"`, etc.) — slot-name normalization (stripping "worn"/"used"/
      "as"/"on"/"around"/"about"/"nearby"/"weapon", auto-numbering
      finger/neck/wrist to 1/2) ported faithfully from PNP and confirmed
      correct against every real slot string seen. Verified via the
      real-code emulation harness: all 113 real equipment blocks parse
      with zero errors. Needs Steven to confirm live (type `eq`/
      `equipment` in-game) before closing.
- [x] **Phase F — re-scoped 2026-07-07 after reading every source
      involved; original premise ("port Highlighter+People, merge with
      colors.xml") was wrong and has been dropped.** Read
      `DSL_PNP_Highlighter.lua`/`.custom.lua` (445 lines), `DSL_PNP_
      People.lua` (672 lines), `colors.xml` (4904 lines, 95 triggers), and
      the live native `DslColors_Core_v1_0` script (3220 lines) in full.
      Findings:
      - `colors.xml` is **not currently loaded** — confirmed zero overlap
        with `current/autosave.xml`'s live trigger tree — and its "Who"
        trigger calls `dslColorRaceTerm`/`dslColorClassTerm`, functions
        that **don't exist** in the live `DslColors_Core_v1_0`. It's a
        stale, pre-v1.0 snapshot (hardcoded per-name/per-org
        character-gradient triggers), superseded by the live engine.
        Nothing to merge from it — safe to leave alone, not worth
        reviving.
      - The live `DslColors_Core_v1_0` turned out to be a **complete,
        already-working superset of both PNP's `Highlighter.lua` and
        `People.lua` combined**, via a real command surface (`dslcolor
        friend/enemy/neutral <name>`, `war/peace <org>`, `show <name>`/
        `show org <org>`, `list ...`, `census`, `team <name> <team>`,
        `killed/killedby/downed/downedby <name>` + combat notes, `name
        <name> <palette>` override, `term "<text>" <palette>`, `title
        <category> <title>`, `palette ...`, `ignore/unignore`, `save`/
        `reload`/`test`), backed by a persistent `DSL_COLOR_DB` with
        `.people` (race/class/kingdom/clan/robe/dragon/title/team/
        first_seen/last_seen/room/crafts/**combat history** — richer than
        PNP's own per-person record), `.orgs` (membership/type/palette),
        and `.relations.people`/`.relations.orgs` (friend/enemy, war/peace
        — directly replacing Highlighter's ally/enemy/neutral status
        system, at both the person AND org level PNP never had together).
        **Porting PNP's Highlighter/People now would mean building
        redundant, inferior, duplicate functionality against CLAUDE.md's
        core reuse mandate** — the native system already does this,
        live, today. `DSL_PNP_Highlighter.lua`/`.custom.lua` and
        `DSL_PNP_People.lua` are now explicitly **out of scope**, moved
        to the same category as `DSL_PNP_Statusbar.*` below.
      - **First real integration built and syntax-checked, not just
        scoped:** `MyDSL_TargetView.lua` now shows a `[Friend]`/`[Enemy]`
        tag next to the current target's name, read directly (read-only,
        via `pcall`-guarded `dslKey()`/`DSL_COLOR_DB.relations.people`)
        from the live native database — reusing the real system instead
        of duplicating it, exactly per the mandate. Setting a relation
        still goes through the real `dslcolor friend/enemy <name>`
        command; MyDSL doesn't need its own alias for that. Needs Steven
        to confirm live (run `dslcolor friend <name>` or `dslcolor enemy
        <name>` on someone, then target them) before closing fully.
      - **`mydsl who <name>` passthrough — built 2026-07-07.** New
        `MyDSL.who(name)` + alias in `MyDSL_DataLayer.lua`, calls the real
        native `dslColorCommand("show " .. name)` dispatcher directly
        (confirmed global from Phase F's read of `DslColors_Core_v1_0`)
        rather than `send()`-ing alias text (which would just hit the
        server as an unknown command, not re-trigger the native alias).
        pcall-guarded in case DslColors isn't loaded. Verified via an
        isolated logic test: calls through correctly when the function
        exists, degrades to a clean error message when it doesn't, and
        rejects an empty name. Needs Steven to confirm live (`mydsl who
        <name>` should print the same thing `dslcolor show <name>` does).
      - Not yet built, real candidate for a follow-up pass: surfacing
        `DSL_COLOR_DB.people[key].team`/`.combat` in GroupView or
        CreatureReference.
- Explicitly out of scope for this whole initiative: `DSL_PNP_Statusbar.*`
  (GMCP-first already the recorded correct replacement), `DSL_PNP_
  Highlighter.lua`/`.custom.lua` and `DSL_PNP_People.lua` (superseded
  in full by the live `DslColors_Core_v1_0`, see Phase F above — added
  2026-07-07), and ~20 PNP-
  client-infrastructure files (Editor/Filesend/FileIO/Growl/Timers/
  Triggers/Aliases/Data/Borders/Keys/History/Help/Command/Buttons/
  Sidebar/Compass/Speedwalk/Xpgauge/Enchant/Gourd/Gauges/Window_Manager/
  Support/Extensions) — superseded by Geyser/WindowRegistry/LayoutEngine/
  ThemeEngine already, or PNP-client-only conveniences with no DSL2
  relevance.

---

## CRITICAL — found via real-code emulation, needs live confirmation

- [x] **`MyDSL_DataLayer.lua` would crash at line ~86 on a genuinely fresh
      Mudlet start, aborting the rest of the file's load — meaning every
      trigger registered after that point (all of combat, weather, chat,
      everything) would silently never exist.** Found 2026-07-06 by
      actually loading the real file (not just regex-testing it) into a
      fresh Lua state via a Mudlet-API mock harness — `MyDSL._aliases` was
      referenced by the log-toggle/help aliases at line 86 before ever
      being initialized as a table (the `MyDSL._aliases = MyDSL._aliases
      or {}` line lived at line 205, well after first use). Only masked in
      practice because Mudlet's Lua state persists across a same-session
      "reload this script" — `MyDSL._aliases` already existed from a prior
      successful load, so an in-session edit never surfaced it. Only a
      genuinely fresh Mudlet start (or first-ever load) would hit it.
      Fixed by moving both `_triggers`/`_aliases` initialization to
      Section 1, immediately after the `MyDSL = MyDSL or {}` namespace
      guard. Verified: the file now loads clean in a fresh Lua state.
      **Needs Steven to confirm with a full Mudlet restart (not just a
      script reload) before closing** — that's the one scenario that can
      actually reproduce the original crash.
- [x] **Load-order sweep of all 25 `MyDSL_*.lua` files, done.** Built a
      minimal Mudlet-API mock (scratch-only, not committed — `tempRegexTrigger`/
      `tempAlias`/`cecho`/`Geyser`/`Adjustable.Container` stubs etc.) and
      `dofile()`'d every file into a genuinely fresh Lua state, in real
      dependency order (`LayoutEngine` → `WindowRegistry` → `DataLayer` →
      everything else). Only the `_aliases` bug above was a real issue —
      every other initial "FAIL" was either wrong test order (fixed by
      loading dependencies first) or a missing mock function (`getMainWindowSize`,
      `dechoLink`, `clearWindow`, `Adjustable.Container` — added to the
      mock, not DSL2 bugs). All 25 files load clean now.
- [x] **Real-capture parse-function stress test — complete for `DataLayer`.**
      Fed real regex-matched captures/lines from the clean corpus directly
      into every real parse function (bypassing trigger dispatch entirely)
      to catch runtime errors the functions themselves might throw —
      2,059 damage lines, 273 avoidance lines (dodge/parry/block, plus the
      sense-trigger single-arg call shape), 628 condition lines, 94 death
      lines, all 9 proc flag codes (both cold-start and warm-state), all
      23,056 bracket-shaped candidate lines through `parseWhoLine`, and
      every one of `parseScoreLine`/`parseFlagsLine`/`parseTimeLine`/
      `parsePromptLine`/`parseWeatherLine`/`parseWhokLine`/`parseWhocLine`/
      `parseGroupLine`/`parseUnreadLine`/`parseInvLine`/`parseMapLine`/
      `parseAffectsTextLine`/`parseImproveLine`/`parseScanLine` against the
      **entire** 328,643-line corpus (not just pre-filtered matches — the
      realistic stress case, since most of these are gated by `.*`
      catch-all body triggers that fire on any line while capturing).
      **Zero real runtime errors found anywhere.** `parseLunarLine` and
      `parseCreatureLoreLine` initially threw on every/many lines
      (`attempt to index local 'moon' (a nil value)`,
      `bad argument #1 to 'insert' (table expected, got nil)`) — traced to
      the test harness itself calling them without the real trigger flow's
      `beginLunar()`/`beginCreatureLore()` setup first (confirmed both are
      always called first in the real code — `lunarBegin`/`loreStart`
      trigger handlers); re-tested with correct setup against the full
      corpus and got zero errors, so not a real bug, just needed proper
      verification rather than assumption either way.
      **Extended 2026-07-06 to ChatTriggers and the render/display layer,
      also complete, also zero errors:**
      - Loaded the real `EMCOChat/emco.lua` library itself (not a stub) —
        it loads clean with the mock; a full `EMCO:new()` construction
        needs deeper internal layout state (`tabHeight`, `Geyser.HBox`
        chains) that's really EMCO's own internals rather than DSL2 code,
        so that part was descoped as low-value/out-of-scope. Instead
        verified the thing that actually matters: for each of the 6
        confirmed-real chat patterns (tells×2, gossip, yell, says,
        whispers), fired the real registered trigger handler against a
        real matched corpus line with a lightweight recording
        `demonnic.chat` stub — all 6 correctly called `append()` with the
        right destination tab (Tells/City/Local), zero handler errors.
      - Ran a full real fight sequence through the actual `DataLayer`
        parse functions in order (damage → avoid → condition → death,
        all real confirmed text) with `raiseEvent` upgraded to actually
        record calls instead of no-op — confirmed the real (previously
        untestable, `local`) `snapshotFight()` fires via
        `"MyDSL.combat.ended"` with a real snapshot, and fed that real
        snapshot into the real `CV.renderSummary()` — clean. Also
        `CV.renderRage`/`CV.appendSwing` (including nil/no-arg edge
        cases), `GroupView.render()`/`ScanView.render()`/
        `ScanView.renderRightHere()`/`TargetView.render()`, each built
        from real state via their own real begin/parse/end functions —
        all clean. (One test-harness mistake caught and corrected along
        the way, not a real bug: `MyDSL.Target` — the data namespace — is
        not the same as `MyDSL.TargetView` — the render namespace; called
        the wrong one first, got a nil-value error, fixed the test.)
      GMCP-dependent logic (anything reading `MyDSL.State.char`/`login`)
      still can't be exercised at all — GMCP was never in the text logs.
      This closes out the real-code-emulation effort for DataLayer's
      parsing layer, ChatTriggers' routing, and the four view modules'
      render layer — all confirmed error-free against real captured data.
      The mock/harness exists in scratch and is reusable for any future
      module (AffectsView/MoonWeather/CreatureReference render layers
      weren't covered this pass, lower priority — not flagged as broken,
      just not yet exercised this way).

---

## TOP PRIORITY — Combat, needs live-fight testing

Fixed in code, none of it confirmed against a real sustained fight yet:
- [ ] Evasion triggers (dodge/parry/block, you-as-subject aware)
- [ ] Both death forms (`is DEAD!!` / `hits the ground ... DEAD.`)
- [ ] Weapon-flag proc attribution via `last_attacker`/`last_target`/`last_noun`
- [ ] Quoted weapon names (`"Nadrik's Honor"`)
- [ ] 2026-07-06 PNP-faithful display rewrite (per-swing live window feed,
      round-summary to main console, `mydsl combat mode raw|condensed|gag`)

Confirmed broken, not yet fixed:
- [ ] Self-condition never registers — DSL phrases your own condition in
      second person ("You have some small wounds"); our trigger + PNP's both
      only match third person
- [ ] Possible interference from a separate pre-existing "itemstats" item-ID
      trigger system (unrelated to our code) — plausible mechanism for
      breaking `$`-anchored combat regex when an item name lands inline in a
      combat line; not conclusively proven. Confirmed 2026-07-06 this system
      is real and native-XML (319 itemstat/itemtags hits in
      `current/autosave.xml`, Mudlet's own live trigger tree — not a `.lua`
      file). Per Steven: the planned Layer 4 reference module will replace
      all of these itemstat triggers outright, so this interference risk
      goes away once that module ships rather than needing a standalone fix.
      **Mechanism confirmed 2026-07-07 by a real live A/B test** (Steven
      disabled the native itemstat triggers mid-session, then ran `eq`/`in`
      again for comparison): itemstats aren't only "type an item name as a
      command" — they also decorate `eq`/`in` output lines directly, live,
      as they scroll by. Same real item, same session, before vs. after:
      `<worn on finger>    (Glowing) a ring of wizardry -[35] 30M,-1S`
      (itemstats on) → `<worn on finger>    (Glowing) a ring of wizardry`
      (itemstats off, suffix gone entirely, every single line). So the
      `-[level] stat,stat,...` suffix on every `eq`/`in` line is 100%
      client-side decoration from this trigger system, not server text —
      confirms Layer 4 needs to reproduce this decoration itself once
      itemstats are retired, not just the "type an item name" lookup.
      **New dependency this surfaces:** `MyDSL_DataLayer.lua`'s Section 9r
      equipment parser (Phase E, `parseEquipLine()`) captures each line's
      trailing text (including this suffix) as one unparsed string in the
      `item` field — it works today only because the native itemstat
      trigger is what's putting the suffix there in the first place. If
      itemstats get disabled permanently before Layer 4 ships a
      replacement, `MyDSL.State.equipment` would silently lose all numeric
      stat data (bare item names only) with no error — worth remembering
      when sequencing the Layer 4 cutover so equipment parsing doesn't
      quietly regress in between.

Unconfirmed in-game (may just need a real occurrence to test against):
- [ ] Sharp proc — no trigger text observed in any log to date
- [ ] Poison sequence (setup/onset/tick) — our own addition, no PNP equivalent
- [ ] procUnholy/procManaSelf/procVampDrain/procFrostTouch/procShockShocked —
      zero occurrences anywhere in the ~1M-line log-corpus regression pass
      (2026-07-06); sibling procs in the same families do fire (procVampDraw
      7280x, procHolyWrath 31x, procPoisonTick 22x), so the mechanism works —
      these specific weapon/mob-flag combos just never came up. Not
      necessarily broken, just unconfirmed.
- [ ] combatSense1/2 (sense-based evasion) — zero occurrences anywhere in the
      corpus AND absent from PNP source (`DSL_PNP_Battle.lua`) — can't tell
      from logs alone whether this is a real-but-rare mechanic or an
      unsourced invented pattern like considerLine1/2 (see below).

**Log-corpus regression test (2026-07-06), fixed:**
- [x] **`considerLine1`/`considerLine2` (`MyDSL_TargetView.lua`) rewritten
      as `considerEasyKill`/`considerNoMatch`** from two confirmed-real
      tiers (`"X looks like an easy kill."` / `"X is no match for you."`),
      both verified matching the clean DSL2-era corpus. Only these two
      tiers are confirmed — DSL almost certainly has more (a graduated
      ladder per `DSL_Helpfiles/consider.txt`), add them as real examples
      are captured. Needs Steven to confirm in-game before closing.
      **Third tier confirmed 2026-07-07** from a live screenshot
      (`Screenshot_20260707_190710.png`): `"The perfect match!"` — an
      even-fight tier between the two already confirmed. Not yet added to
      `considerEasyKill`/`considerNoMatch`'s handling — needs its own
      branch (`considerEvenMatch` or similar) when picked up.
- [ ] **Combat/proc triggers don't account for two bracket-prefix line
      formats — but both are confirmed absent from DSL2's own actual
      logs, so this is now low-priority/theoretical, not an active bug.**
      Downgraded 2026-07-06 after date-stratifying the corpus: split
      `log/` by date and found both formats below are >99% confined to
      Jan-May 2026 files, which predate DSL2's existence (its scripts
      start 2026-06-06 per git history) and almost certainly came from
      the actual PNP profile (separate sibling Mudlet profile, its own
      `log/` going back to Nov 2025) rather than DSL2 itself. Across all
      157 June+July 2026 (DSL2-era) log files: zero genuine occurrences of
      either format. **DSL2 itself never loads PNP's Highlighter at all**
      (confirmed: grepped every active `MyDSL_*.lua` file, zero
      references — `PNP files/` is read-only reference material we read
      for porting, never `dofile()`'d into the running profile), so the
      trigger-priority race described in the original finding doesn't
      currently apply. Kept as a documented mechanism, not deleted,
      because both are real formats DSL can genuinely produce:
      1. Coliseum spectator "wall" rooms broadcast a genuine **server-
         sent** `[ <Wall Name> ] ` prefix on every line while standing
         there — real DSL behavior, just not something Steven's been in
         during any DSL2-era session yet. If it's ever reported live,
         every `^`-anchored trigger will fail on it.
      2. PNP's own Highlighter (`PNP files/DSL_PNP_Highlighter.lua:261-
         264`, `replaceNames()`) rewrites a recognized clan member's name
         to `"[51] Name"` via `replace()`+`cinsertText()` when its
         `show_clanner_level` config is on — confirmed real PNP source,
         just not active in DSL2 today. Relevant only if this decoration
         is ever ported into DSL2 in the future.
      `procStun`, `procFrostFreeze`, `procShockLightning` showed zero
      matches in the full corpus, and 100% of their real occurrences
      carried one of these two prefixes — but since neither prefix occurs
      in DSL2-era data, this doesn't mean these triggers are actually
      broken for current play. Move back to "Unconfirmed in-game" above
      unless/until one of these formats is actually seen under DSL2.
- [x] **`MyDSL._triggers.weather` (`MyDSL_DataLayer.lua`) was dangerously
      overbroad — fixed.** The trigger pattern itself (`^[A-Z][^.]+\.$`,
      matches ~13% of all lines) was always meant to be filtered by a
      keyword list in `parseWeatherLine()`, but that filter used plain
      substring matching, so "sun" matched inside "Sunday" — confirmed
      live-corrupting `MyDSL.State.weather` with the log-session-start
      banner ("...on Sunday, 5 July 2026.") every time a new log file
      opened, plus similar false positives from mob/room text ("waves at
      you", "cloud giant"). Fixed by switching to a word-boundary Lua
      pattern (`%f[%a]word%f[%A]`). Verified via `luajit` against the full
      328,643-line clean corpus: false positives (Sunday, waves-at-you)
      now correctly rejected, real weather kept, and the effective
      would-update count dropped from 33,801 to 687 (0.2%, sane for an
      occasional event). Residual known gap: standalone weather-words used
      in a non-weather sentence ("lightning bug", "reaches for the sky")
      aren't distinguished — lower-frequency, not fixed this pass.
- [x] **`MyDSL_ChatTriggers.lua` channel routing — rewritten twice
      2026-07-06, second pass supersedes the first.** First pass (log-
      corpus regression testing alone) fixed the colon-vs-quote mistake
      but had to guess at several verbs/tabs and left Group/OOC/Grats/
      Newbie/Kingdom disabled entirely for lack of evidence. Second pass
      found a much better source: Mudlet's own native trigger tree
      (`current/autosave.xml`) has a complete "Chat Routing" trigger
      group with tested patterns for every channel (dormant —
      `isActive="no"` — but real, tested reference material, same
      standing as `PNP files/`). Pulled every pattern directly from that
      XML and cross-verified each against the clean corpus. Real
      corrections this found: clan gossip's verb is **"clan gossips"**
      (two words — the first pass's inferred "cgossips" was wrong), group
      chat is **"tells the group"**, OOC is **`Name OOC: 'message'`** (no
      bracket tag), congratulate's verb is **"grats"** (not
      "congratulates"), Kingdom is a literal `"Kingdom: '"` prefix (not a
      verb), and there are three previously-unknown-to-us channels
      (Radios, Bloodbath, Quest — the last two use "Bloodbath: '"/
      "quests '", not "QUEST:"). Also fixed a real bug in the first
      pass's own yell/shout patterns: they required the third-person
      `-s` form even for "You", so "You yell '...'"/"You shout '...'"
      (first-person, no `-s`) never matched — native XML confirms both
      forms are real and distinct. Kept the confirmed-from-logs optional
      `(Language)` tag group on every pattern even though the native
      reference doesn't have one — that part is independently verified
      real, a genuine improvement over the native version. Destination-
      tab assignments also corrected: auctions/grats/radios/ask/newbie/
      bloodbath/quest all route to **OOC**, not City as first guessed —
      only the gossip family and Kingdom route to City. Every pattern
      re-verified against the clean corpus (some — Group, OOC, Grats,
      Radios, Newbie, clan gossip itself — still show zero DSL2-era
      occurrences, consistent with everything else found today: real
      channel, real verb, just not something that's happened yet in
      logged play). Needs Steven to confirm live routing actually reaches
      the right EMCO tabs before closing — note `route()` still doesn't
      call `deleteLine()` (left as-is, "removed for testing" per the
      existing code comment).
      **Third pass, 2026-07-07:** per Steven, voice types and languages
      both affect real chat text and weren't handled generally.
      `DSL_Helpfiles/voicetype.txt` confirms 21 distinct voice types
      (Soft, Raspy, Low toned, Growlingly, Husky, ...) with irregular
      phrasing ("says softly" / "says in a raspy voice" / "says in a low
      toned manner" — not one template), and a `(to Name)` target tag can
      combine with a `(Language)` tag in either order (e.g. `"Ariaenys
      says in a musical tone (to You) (Dragon) 'message'"`, confirmed
      real). Rather than enumerate all 21 phrasings (same mistake as
      guessing, just smaller), replaced the narrow `(?: \([^)]+\))?`
      group everywhere with a general "anything up to the opening quote"
      zone (`[^']*'`) — correctly covers any combination of voice-phrase/
      target-tag/language-tag/none without needing each one's exact
      wording. Verified this doesn't over-match (counts stayed sane, e.g.
      Local says went 2,759 → 2,959, not unbounded) and that all 139 real
      voice-type "says" lines in the corpus are now covered (0 missed,
      versus some being missed by the narrower group before). Voice-type
      modifiers only appear on "says" in the corpus so far, never on
      whisper/tell/yell/shout/gossip, but the general form was applied
      everywhere as free future-proofing.
- [ ] **Three proc/affect triggers previously reported as "confirmed
      working" (`procFlameSear`, `procHolyWrath`, `procPoisonTick`) and
      `A.ids.triggers.song` (AffectsView "Song:" format) turned out to
      have zero occurrences in the DSL2-era-only corpus** — all of their
      matches (98, 31, 22, 25 respectively) came from pre-DSL2 log data.
      Downgrade to the same "unconfirmed under current play" status as
      their siblings above — the earlier reasoning "sibling procs in the
      same family fire, so the mechanism works" no longer holds since
      the sibling itself lacks DSL2-era confirmation. AffectsView's core
      mechanism is still solid (`start`/`spell` patterns: 292/278 matches
      in the clean corpus) — just the `Song:` variant specifically is
      unconfirmed, not the whole module.
- [x] **Two real command-syntax gaps, fixed.** Found by cross-referencing
      typed commands against the server's response in the clean corpus
      (any `mydsl ...`/`toggle ...` line immediately followed by "Huh?"):
      - `mydsl help` — typed 6 times across different sessions, always
        got "Huh?" back. Added `MyDSL.help()` + alias in `MyDSL_DataLayer.lua`
        (static command list, kept in sync by hand).
      - `mydsl history font 9` — typed twice, "Huh?" both times. Added
        `MyDSL.Route.setHistoryFont()` + alias in `MyDSL_RouteHelper.lua`,
        matching the `mydsl <module> font <n>` convention every other
        window already has. Needs Steven to confirm both in-game.

**New tool, needs live confirmation:** `MyDSL_RawCapture.lua` (added
2026-07-06) — a diagnostic-only logger meant to capture the true
server-raw text of every line before any other trigger/script (ours,
PNP's, Highlighter's) can touch it, specifically to settle the priority-
ordering question above empirically. Needs: (1) Steven to place its
`dofile()` **first** in Mudlet's Script editor load order (can't be done
from here — it's GUI-configured, not a flat file), (2) live testing to
confirm the captured text actually differs from the visible
console/session-log text on a Highlighter-decorated line, which will also
tell us whether the priority value chosen (100) is actually enough to run
before Highlighter's trigger. Off by default — toggle with `mydsl rawlog
on`/`mydsl rawlog off`; this logs literally every line of the session, so
turn it on only when specifically testing this.

Discuss once the above is confirmed working (deliberately deferred, per
Steven: "make it work like PNP, then discuss the additions"):
- [ ] Whether `renderSummary()`'s persistent multi-fight "Fight summary"
      block (our own addition, no PNP equivalent) should be reformatted to
      match PNP's sentence style or kept in its current table style

---

## OPEN — Reported bugs

- [x] **`MyDSL_Bloodbath` window removed 2026-07-07 — not needed.** Was
      fully registered/positioned but never fed (`MyDSL.Route.bloodbath()`
      existed but was never called from anywhere — same dead-window
      pattern as the "Players near you" gap fixed 2026-07-05). Per Steven:
      not needed — bloodbath chat already correctly goes to OOC (Phase A
      ChatTriggers work), and bloodbath *announcements* (a distinct
      message type from the chat line) already go to History via a
      native mechanism, unrelated to anything in `MyDSL_*.lua` (see
      below). Removed the window from `MyDSL_WindowRegistry.lua`/
      `MyDSL_LayoutEngine.lua` and the dead helper from
      `MyDSL_RouteHelper.lua`.
      **Retracted 2026-07-07:** this entry originally claimed
      `current/autosave.xml` had two natively-active *trigger groups*,
      "Toasts/History Captures" and "Trumpet Sounds and History," with
      byte-for-byte identical children routing the same chat channels —
      named as the likely root cause of "clan gossip duplicates" below.
      Re-verified with a proper XML parse (not a truncated text scan) and
      found this false on every count: both are single leaf `Trigger`s
      (not groups), living under a `Notifications` folder, with completely
      different scripts/regexes from each other — one matches PvP
      kill-toast phrases, the other matches kingdom-join/retirement/
      achievement announcements. Neither matches gossip/chat text at all.
      See the "RETRACTED" entry under the full inventory section above for
      the full re-verification. The "clan gossip duplicates" bug is
      unsolved again — nothing was disabled based on the wrong claim.
- [x] **GroupView heal quick-action on Mob rows — resolved 2026-07-07 by
      live testing, not a bug.** Steven's own notes: "heal works on bear
      from group window. kien has healing skill" — confirmed live with
      Kien (who has a healing skill) on a charmed bear. The earlier report
      (healing a pet failed) was very likely just Tibbins — a different
      character/follower who **doesn't have a heal skill at all** ("tibbins
      doesnt have heal so it wont work on follower, thts fine"), so the
      button correctly had nothing to send, not a code bug.
      **New design gap surfaced by this same test:** there's more than one
      "heal" spell/skill tier, and the Group window's `[Heal]` button needs
      to actually use whichever heal-type skill the character has, not a
      single hardcoded command — "the heal should change on the skill as
      well there are more than one heal (need a solution for these)."
      **Confirmed 2026-07-07 from a live `help healing` lookup found in the
      logs** (Steven looked this up mid-session): the real spell hierarchy,
      in order of power, is `cure light` → `refresh` → `cure serious` →
      `cure critical` → `heal` (most powerful) → `mass healing` (rooms
      everyone), syntax `cast '<spell name>' <character>`. Available to
      ASSASSIN/BATTLERAGER/CLERIC/CRUSADER/DRAGON/GIANT/DRUID/PALADIN/
      PRIEST/SHADOWKNIGHT/WARRIOR. So the button logic needs to pick the
      highest-tier heal spell the character actually knows (a "knows
      spell" check likely already needed for the general "does this
      character have skill X" question below) rather than assume plain
      `heal`. Still open: how to detect which of these six a given
      character/follower actually knows.
- [ ] **GroupView not populating** — reported not working; needs repro
      steps (was Steven actually grouped at the time?).
- [x] **TargetView shows "kill" on your own group members/followers —
      fixed 2026-07-07.** "clicked bear from group, got bear in target
      window but it should not have the kill option, those should change
      when group members are selected, so i dont attack a follower/group
      member." `MyDSL_TargetView.lua`: marked `murder`/`order_attack` with
      a new `attack = true` flag on their action definitions, added
      `isOwnGroupMember(name)` (checks the target's normalized name
      against the live `MyDSL.State.group.members` roster — the same
      data GroupView itself renders from, not the click source, so it
      also protects a group member re-targeted some other way, e.g. from
      RightHere). `TV.render()` now skips rendering any `attack`-flagged
      button when the current target is an own-group member; `doAction()`
      also refuses to send an attack command in that case as defense in
      depth, in case a stale button link is still visible. Verified via a
      real emulation test: murder/order_attack correctly blocked when
      targeting a group-member bear or a group-member player, and murder
      still sends normally against a non-group mob. Needs Steven to
      confirm live (target a charmed pet/group member, murder/order-all
      buttons should be gone).
- [x] **`(oac)`/TargetView order-all-kill unreliable — root cause found
      and fixed 2026-07-07.** Read the actual native `(oac)` alias script
      from `current/autosave.xml` (`^oac (.+)$`): it's a trivial
      passthrough — `send("order all kill "..target)`, no follower-
      targeting logic at all, so it can't be the source of any targeting
      bug itself. That pointed at the verb instead: `DSL_Helpfiles/"kill
      kill command hit.txt"` confirms `kill`/`hit` starts combat against
      mobs, while `murder` is specifically DSL's PKILL-system command
      for attacking *players* ("You must join the pkill system and use
      the MURDER command to attack other players."). `MyDSL_TargetView.
      lua`'s `order_attack` action (used only in `mob_buttons`, never
      `player_buttons`) was unconditionally sending `"order all
      murder "..name` — the wrong verb for every mob target it's ever
      used on, and a very plausible match for "order all kill greaser
      did not work from target window" (server said "Ok." with no
      attack, consistent with `murder` being rejected/no-op'd against a
      non-PKILL mob target). Also found the same wrong-verb bug in the
      `murder` action itself (always sent `"murder"` regardless of
      `t.is_mob`) — both now pick `kill` vs `murder` based on
      `t.is_mob`, matching the real, tested native `(oac)` verb for mobs.
      `MyDSL_GroupView.lua`'s `quickAction()` was also passing a
      target-like table with no `is_mob` field to these same actions —
      fixed to include it, since it would have silently fallen back to
      the player verb for a mob quick-action otherwise. Verified via a
      real emulation test: murder/order_attack both correctly send
      `kill`/`order all kill` against a mob target and `murder`/`order
      all murder` against a player target. Needs Steven to confirm live
      (order-all/murder a mob from TargetView or a GroupView quick
      action) — this may fully resolve the reported bug, though the
      "first elf" report is less certain since it wasn't confirmed to
      have gone through TargetView specifically.
- [x] **Chat capture bug — confirmed fixed 2026-07-07, per Steven live
      ("i think we fixed the chat capture issue").** No code-level cause
      was ever actually identified (checked every `gmcp.*` handler in
      `MyDSL_DataLayer.lua`, none touch the raw text stream at all) — most
      likely it was a side effect of one of today's other real fixes
      (ChatTriggers' voice-type/language-tag generalization is the most
      plausible candidate, though not confirmed which specific change did
      it). Closing per live confirmation rather than leaving open with no
      lead — if it resurfaces, `MyDSL_RawCapture.lua` is still the right
      tool to catch it with an exact raw-vs-displayed comparison.
- [ ] **AffectsView "missing" list includes skills that will never show up
      as active — reported 2026-07-07** ("affects winfow treating skills
      like stealth and riot as spells"). Investigated with real data from
      tonight's logs; the two are NOT the same situation:
      - **`riot` is genuinely fine, not a bug.** Confirmed real text:
        `"Spell: riot : modifies damage roll by 3 for 16 cycles, (8
        hours)"` — DSL's own `affects` command labels it a Spell with a
        real cycle-based duration, exactly like armor/bless/shield. It's
        correctly tracked and will correctly show active/missing.
      - **`stealth` looks like a real mismatch.** Confirmed via the
        `skills` listing it's a %-based skill (`"stealth 75%"`, alongside
        `pick lock`/`bash`/`disarm`), and there is **no** `"Spell: stealth
        ... cycles"` line anywhere in tonight's logs — only repeated
        `cast 'stealth'` attempts from the spellup/respell system
        (`MyDSL_CharacterAssist.lua`) followed by "You lost your
        concentration" or nothing. If `stealth` never produces a
        cycle-tracked "Spell:" line, it can never register as "active" in
        `MyDSL.State.affects` the way armor/riot/bless do — meaning it
        would sit in AffectsView's "missing" list forever, even when the
        skill is actually toggled on in-game. `stealth` got onto Vrokt's
        tracked/spellup list at some earlier session (not found in
        today's logs — no `setspell` call today), so this isn't a code
        bug so much as a list that may need Steven to reconsider whether
        `stealth` belongs in a "cast and track like a spell" list at all,
        versus needing its own %-skill-based active-detection path (not
        built) if he wants it tracked differently. Not fixed — needs
        Steven's call on which way to go before changing anything.
- [ ] **Clan gossip duplicates in chat window — unsolved again, 2026-07-07.**
      The 2026-07-07 "likely root cause" (two identical native trigger
      groups) was retracted the same day after a proper XML parse showed
      neither claim held up — see the RETRACTED entries above. Also
      confirmed while re-checking: the native `Chat Routing` group (which
      does contain three distinct, non-duplicate gossip triggers — `Clan
      Gossip`/`Dragon Gossip`/`Gossip`) is itself `isActive="no"` (dormant)
      — so those can't be firing live either. No confirmed lead currently
      exists; back to needing a live repro (does the duplicate come from
      `MyDSL_ChatTriggers.lua` itself double-appending, from EMCO's `allTab`
      mirroring, or something else) before guessing again.
- [x] **`MyDSL_ChatTriggers.lua` channel routing** — superseded, see the
      full writeup under "Log-corpus regression test (2026-07-06), fixed"
      above (now on its second, native-XML-sourced pass).
- [x] **Roller — ported 2026-07-07 as `MyDSL_Roller.lua` (Phase C).**
      Turned out to be a character-creation stat-reroll auto-rejecter, not
      a combat dice-display as the vague open item implied — the native
      `roller` trigger sums Str/Int/Wis/Dex/Con from a bracketed line,
      auto-sends "n" (reject) below a hardcoded goal (241), pauses for
      manual review at/above goal (never auto-accepts). `DSL_PNP_Roller.
      lua` does the same core thing plus real value-add the native
      version never had: adjustable goal, running min/max/avg/stdev
      stats, reset — ported that near-verbatim, reusing PNP's own
      `set goal <n>`/`roll stats`/`reset roll` command vocabulary per
      CLAUDE.md's mandate, keeping the native trigger's already-tuned 241
      goal as the default instead of PNP's generic 230. One thing that
      couldn't be resolved: PNP's own trigger pattern has no brackets and
      a double space, the native one has brackets and single space,
      and neither could be verified against real logs (character creation
      is one-time, no available log happens to capture it) — made the new
      pattern tolerant of both rather than picking one unverifiable guess
      over the other. Verified via the real-code emulation harness: both
      format variants match correctly, goal-boundary logic (reject vs.
      pause), `showStats`/`setGoal`/`reset` all run error-free. Needs
      Steven to confirm live next time a character is actually rolled.
- [x] **RightHere should update on `look` too, not just `scan` — fixed
      2026-07-07.** `look`'s room-content lines use a different, plainer
      format than scan's (`"<Name> is here[, <status>]."`, optionally
      prefixed with a `"(<Flag>) "` tag) — confirmed real text from
      `log/2026-07-07#18-29-43.html`. New `MyDSL.beginLook()`/
      `parseLookHereLine()`/`endLook()` in `MyDSL_DataLayer.lua` Section
      9o.1, anchored on the room's own `"[Exits: ...]"` line (always
      immediately before the content listing) rather than a fixed header
      phrase, since `look` has no distinct start-of-listing banner —
      this also means RightHere now refreshes on every room entry
      (movement reprints the room), not just an explicit `look`, still
      100% observational. Handles wrapped status text (confirmed real
      example: `"...keeping the gears"` / `"lubricated."` split across
      two physical lines) by treating a lowercase-starting line as a
      continuation to ignore rather than a capture-ending line, since
      DSL always capitalizes the start of a new game message. Repopulates
      the same `MyDSL.State.scan.rightHere` table ScanView already
      renders from and fires the same `MyDSL.emit("scan")` event, so no
      ScanView changes were needed. Verified against the real captured
      4-occupant room block: all 4 distinct entries captured correctly,
      the wrapped continuation line correctly ignored, capture correctly
      ends on the next unrelated real-time message. Needs Steven to
      confirm live (look around a populated room, check RightHere
      updates without needing `scan`).
- [ ] **autowhere fires while sleeping** — Steven's own alias, not ours;
      low priority for us specifically.

---

## OPEN — Design ideas, not yet scoped

- [ ] **TargetView's kill/murder button needs an alternate-command option
      — new 2026-07-07.** "the kill/murder button on target window needs
      like a drop down or manual command option ... for vrokt as example,
      it is better to waylay init combat than to kill/murder init
      combat." Right now `TV.actions.murder.cmd` (`MyDSL_TargetView.lua`)
      is a single hardcoded `"murder " .. name` — no way to swap in
      `waylay` or another opener per-character/per-situation. Needs a
      real design pass (dropdown vs. long-press vs. a per-character
      configured opener command), not a one-line fix — hasn't been
      scoped further.
- [ ] **Parse "Prompt Line 1" — not scoped, low priority, likely redundant
      with GMCP.** Found 2026-07-07 investigating the vision-check
      question: `current/autosave.xml` has a second native prompt-gag
      trigger ("Gag promt line1", sic) besides "Gag promt line 2" (the one
      `parsePromptLine()` handles). Real format confirmed from the corpus:
      `[HP/maxHP HP | Mana/maxMana M | MV/maxMV MV] [ stance | alignment |
      language | flags ]` — e.g. `[1605/1605HP | 960/960M | 406/406MV]
      [ Offensive | neutral | Common | (Flying) ]`. All four bracket
      fields are currently thrown away: combat stance, alignment, current
      speaking language, and a parenthetical status-flags slot (confirmed
      `(Flying)` appears there; other flags unconfirmed). Likely fully
      redundant with GMCP (`char_data.stance`/`language`/`is_flying`,
      already confirmed present in a live GMCP dump) — real value-add
      would only be whichever flags aren't already in GMCP, if any. Not
      scoped, not started, not planned unless something turns up that
      GMCP doesn't cover.
      **Both native gag triggers confirmed 2026-07-07 (`isActive="no"`,
      under `MyDSL_GameplayTriggers`) — both have now served their
      verification purpose and can be re-enabled (re-gagged):** re-checked
      "Gag promt line 2" against fresh post-reload logs and confirmed its
      real format is `==-<period> - <H:MM><am|pm> :: [<room or
      "darkness">] :: [<exits>]-==` (e.g. `==-Dawn - 6:00am ::
      [darkness] :: [ESW]-==`) — `parsePromptLine()`'s pattern
      (`^==%-(%a[%a%s]+) %- %d+:%d+%a+ :: `) correctly captures the period
      name against this real text (traced by hand, not just assumed). The
      room-name bracket duplicates `MyDSL.State.room.name` (GMCP) and the
      exits bracket duplicates GMCP room exits (already commented as
      captured at `MyDSL_DataLayer.lua:236`) — nothing on this line is a
      real gap. Safe to re-enable both gag triggers via Mudlet's Trigger
      Editor (native XML edit, not something to hand-edit on disk while
      the profile is live — see the `docs/CHANGELOG.md` note on this).
- [ ] **TargetView: show debuffs you've cast on the current target — new
      2026-07-07, from live play.** "im not seeing the debufs i cast on
      the target, like weaken and slow?" Confirmed real, distinct success
      messages by tracing tonight's logs around Steven's own `c weaken`/
      `c slow` casts: weaken → `"<target> looks tired and weak."` (not one
      of the existing 7 HP-condition-ladder phrases at
      `MyDSL_DataLayer.lua:1723` — genuinely a separate message, not a
      false match), slow → `"<target> starts to move in slow motion."`
      Per the in-game `help newbie` "Common Status Affects" section,
      weaken/slow/blind/plague/poison are "Maladictions" that persist
      "until cancelled with the cancellation spell or cleanse skill" (or,
      for some, only by a cleric) — likely not a short fixed timer the
      way player buffs are, so this may not need AffectsView-style
      countdown, just an active/inactive tag per debuff. No "wears off"
      message confirmed yet for either (the mobs tested against died
      first) — open question for whenever one's caught live. Proposed
      home: TargetView, as the enemy-side counterpart to AffectsView's
      player-side buff tracking. Not scoped beyond this — needs a wider
      catalog of which maladiction-style spells exist and their real
      success/end text before building, same as the Skills/Spells→Combat
      item below.
      **Cataloging pass done 2026-07-07** (grepped all 93 DSL2-era log
      files): weaken/slow are now solidly confirmed — 4 independent real
      examples each, across different mobs (dark elf janitor, insane half
      elf, gnome greaser/machinist/architect), all matching the exact same
      template with zero variation, so the existing patterns are safe to
      build on directly. `blindness`/`poison`/`plague` (DSL_Helpfiles
      confirms all three are real `cast <spell> <target>` spells, same
      family as weaken/slow) still have **no confirmed third-person
      on-target success text anywhere in the corpus** — only
      `"You are blinded!"` (self-directed, 3 occurrences, someone else's
      spell/attack landing on the player, not the player casting it on a
      target) and unrelated inventory/skill-list/helpfile-style mentions
      of the words "poison"/"plague". No "wears off" text found for any
      of the five maladictions either (confirms the existing note, not
      just an assumption). So: weaken/slow are ready to build now;
      blindness/poison/plague need a live catch of an actual successful
      cast landing on a mob target before their text can be added.
- [ ] **TargetView: auto-populate target on aura detection** — when
      detect-good/detect-evil shows, auto-set to first opposing-alignment
      mob visible, else first mob not in your own group.
- [ ] **Skills/Spells → Combat window** — want skill/spell actions you
      actually take (not raw attack spam) to echo to main and copy to
      Combat, matching PNP's philosophy. No PNP precedent exists for this
      specifically (confirmed: `DSL_PNP_Battle.lua` has zero spell/skill
      handling — new ground).
      **Clarified 2026-07-07 from Steven's own notes:** "i would like the
      ability to see the characters Skills/Spells to echo to the main
      screen but also copy to the combat (combat should get everything
      *same as PNP*) but i want to remove the spam attacks to battle, but
      i want to see actions i actually make. like PNP." So specifically:
      (1) echo to **main console**, not just Combat; (2) Combat should get
      "everything" the way PNP's did; (3) the raw per-swing attack-spam
      currently in Combat should be reduced/removed in favor of showing
      the skill/spell actions actually taken. Confirms the direction, still
      needs scoping.
      **Cataloging pass done 2026-07-07 — and it found the two seed
      examples this item was originally based on don't actually exist in
      the DSL2-era corpus.** `"Jhawsh"` never appears anywhere in `log/`
      at any date; `"You kick!"` only appears in a pre-2026-06-06 file
      (the unrelated sibling PNP profile's own log, per CLAUDE.md's
      dating rule) — both were likely misremembered rather than pulled
      from a real log. Real confirmed first-person skill/spell action
      text found instead (216-file DSL2-era corpus, including a
      previously-missed `log/2026-0/` subdirectory): `waylay` →
      `"You unleash a frenzied attack on <target>!"`; `riot` →
      `"You yell and enrage those around you!"` +
      `"You are suddenly filled with a sense of anger!"`; `frenzy` (cast)
      → `"You are filled with holy wrath!"`; `swarm` (cast, druid) →
      `"You summon forth a swarm of insects!"` then per-target
      `"Your insects swarm all over <target>!"`; `castigation` (cast) →
      `"You raise your hand and conjure the judgment of light!"` then one
      of 3 resolution lines; `roar` (dragon racial) →
      `"You let out a groundshaking ROAR!!!"`. Also found (see
      `docs/DSL_CommandRef.md`'s new "Killing-blow flavor text" and
      "Bash-evasion" entries) an 8-variant random finisher-flourish pool
      and a bash-specific evasion form not in the existing 5-form evasion
      list. **Real gap surfaced**: warrior/thief-type skills (kick, bash,
      trip, dirt-kick as first-person, rescue, circle) produced **zero**
      first-person success lines anywhere in this corpus — neither
      logged character (Kien the druid, Vrokt the bandit) has/uses them,
      third-person coliseum-spectator logs don't help since they're a
      different character. A live in-game test with a warrior/thief
      character actually using these skills would fill this gap far
      faster than more log-grepping. Not scoped/built yet — this was
      prep work, not implementation.
- [x] **CombatView/History font sizes — fixed 2026-07-07.** "battle text
      needs to be a little smaller 8? history text 7. this should all be
      tied in with the layout script tough." Combat's default (8) already
      matched what Steven wanted, but was a bare hardcoded literal with no
      way to change or persist it — added `CV.config.fontSize`,
      `CV.setFont(n)` + `mydsl combat font <n>` alias, and character-bound
      disk persistence (`combatview_config_<Char>.lua`), same pattern as
      `MyDSL_TargetView.lua`/`MyDSL_AffectsView.lua`'s `configFile()`.
      History's `FONT_SIZE_OVERRIDES` default dropped from 8 to 7 and
      given the persistence it was previously missing (this file's own
      comment already flagged this gap) — new
      `history_font_<Char>.lua`, `setHistoryFont()` now calls
      `saveHistoryFontConfig()`. Both syntax-checked and verified via
      real emulation tests: Combat's `setFont(6)` survives a simulated
      full-Mudlet-restart reload correctly; History's default-7-on-fresh-
      profile and persisted-12-survives-restart cases both confirmed.
      Needs Steven to confirm live sizes look right and that `mydsl
      combat font <n>`/`mydsl history font <n>` both actually persist
      across a real restart, not just the emulation harness.
- [x] **Action-button color contrast — fixed 2026-07-07.** "really need to
      change the blue actions in the windows i cant read them the
      contrast is terrible. i use the hover text to tell what they are on
      my monitor." Identified the actual color: `MyDSL_TargetView.lua`'s
      `TV.actions` had 6 real clickable command buttons (Rescue,
      Cr.Blind, Cr.Disease, Cr.Poison, Cr.Fatigue, Cr.Bugbite — plus
      GroupView's quick-action Rescue button, which reuses the same
      color) all sharing one pale blue-violet (`"170,170,255"`). Changed
      to a soft cyan/teal (`"120,210,220"`) — better contrast/legibility,
      stays clearly distinct from the existing red (attack)/green
      (heal)/gold (sanctuary) hues. Deliberately did **not** touch
      ScanView/TargetView's separate mob/player type-indicator blue
      (`"136,170,255"`) — that's a category color on a target-click link,
      not a command action, and changing it would break the established
      mob=orange/player=blue convention rather than fix what was
      reported. This is a judgment call on the exact replacement shade —
      easy to swap again if it's still not legible on Steven's monitor.
      Syntax-checked. Needs Steven to confirm live it's actually
      readable now.
- [ ] **Command vocabulary — more IC/human-speak, less `mydsl <module>
      <verb>`** — "can we find a way to make commands feel more like
      human speak or mud commands, something more IC and flows like DSL
      commands." Design direction, not scoped — ties into the existing
      "Command-surface retrofit" section above (reusing PNP/EMCO/native
      verbs) but goes further: aim for something that reads naturally,
      not just deduplicated.
- [ ] **Item-clickable reference module** — item names clickable (underline,
      not color change) instead of echoing stats on identify; pull from a
      persistent DB on click. Depends on Layer 4 (not started).
- [ ] **Census (from UI) should interact with the reference module** —
      depends on Layer 4.
- [x] **Incorporate DslColor into the UI — done differently than planned,
      see "Phase F" above.** `colors.xml` turned out stale/unloaded and
      not worth reviving; the live `DslColors_Core_v1_0` turned out to
      already be a complete superset of PNP's Highlighter+People, so
      "merge Highlighter into DslColor" became "read DslColor's data
      straight into MyDSL windows, don't touch PNP's Highlighter/People at
      all." First slice built: TargetView's `[Friend]`/`[Enemy]` tag.
- [ ] **State-scoped sound toggle** — need a generic pattern for an alias to
      turn a sound on for a state and reliably turn it off when the state
      ends (example: sleep sound on/off), not just a one-off for sleep.

---

## OPEN — Command-surface retrofit (queued, deliberately held)

Held until after combat-pass testing, per Steven. Mandate: reuse PNP/EMCO's
actual command vocabulary, not just their internal logic — see `CLAUDE.md`'s
Philosophy section and `MyDSL_MudletAPIReference.md` for the full rationale.

- [ ] `toggle <module>` — PNP's real universal on/off alias
      (`raiseEvent("onToggle", module, option)`) is already live.
      CombatView/AffectsView/MoonWeather should hook this instead of their
      own `mydsl <module> gag/show` aliases. Proposed: `toggle combat`,
      `toggle affects`, `toggle moons`.
- [x] `emco <verb>` — **closed 2026-07-07 after tracing the actual object
      graph; the fix this item originally prescribed (route `mydsl chat
      show`/`hide` through `emco show`/`hide`) would have broken the live
      window had it been implemented as written — good thing it was
      checked before coding it.** The bare `emco` alias's regex
      (`^emco (save|load|font|fontSize|blink|blankLine|timestamp|show|
      hide)(?: (.+))?$`, confirmed live) is real, but what each sub-verb
      actually touches isn't uniform:
      - `emco show`/`hide` call `demonnic.container:show()`/`:hide()`.
        `demonnic.container` is the **original native `Adjustable.
        Container`** (`"EMCOPrebuiltChatContainer"`) — a *different*
        object from the chat console itself, and `MyDSL_ChatWrapper.lua`'s
        `C.hideOldPrebuilt()` (called from `createInWindow()`) deliberately
        hides it forever, since MyDSL replaced it with its own `MyDSL_Chat`
        Geyser window (`C.window`, WindowRegistry-integrated). So `emco
        show`/`hide` do **not** affect the visible chat window in this
        profile at all — they toggle a permanently-hidden vestigial frame.
        `mydsl chat show`/`hide` (`MyDSL_ChatWrapper.lua:622-623`) are
        correct as-is; routing them through `demonnic.container` was the
        wrong fix and was not implemented.
      - `emco font`/`fontSize`/`blink`/`blankLine`/`timestamp` all read
        `local chatEMCO = demonnic.chat` **fresh, inside the alias body**,
        each time the alias fires — and `MyDSL_ChatWrapper.lua:313`
        (`demonnic.chat = obj`) reassigns that same global to MyDSL's own
        live EMCO instance. So these sub-verbs genuinely do act on the
        real, currently-visible chat console — `emco fontSize <n>` calls
        `:setFontSize()` on the exact same object `mydsl chat font <n>`
        does (`C.applyFont()` also calls `ch:setFontSize()`). Real,
        confirmed, low-stakes duplication — left as-is rather than merged,
        since `mydsl chat font` also persists the value to MyDSL's own
        settings file (`C.saveSettings()`), which `emco fontSize` doesn't
        touch, so it isn't a pure reinvention either. A code comment was
        added near `C.setFont()`/`installAliases()` recording this so a
        future pass doesn't "fix" it into calling the wrong EMCO method.
      - `emco save`/`load` (via `demonnic.helpers.save/load` in the native
        script) use a **module-level** `chatEMCO` upvalue that's only
        reassigned inside `demonnic.helpers.resetToDefaults()` — a
        function MyDSL never calls. So unlike the sub-verbs above, `emco
        save`/`load` almost certainly act on the stale original prebuilt
        object, not MyDSL's live chat — effectively disconnected. Not
        independently re-verified beyond tracing the assignment (low
        priority: requires a user to deliberately type a command never
        used before), flagged here rather than asserted as fully confirmed.
      - Not checked: whether `mydsl chat` duplicates `gag`/`lock`/`notify`/
        `title` — still open, low priority, left for a future pass.
      CLAUDE.md's Philosophy section corrected to match (2026-07-07).
- [ ] Combat's extra sub-toggles (`show_miss`/`show_evade`/`show_flag`/
      `show_condition`) have no PNP alias equivalent — keep a short bespoke
      form (e.g. `combat show miss`).
- [ ] Scan/Target/Group/CreatureReference are net-new (no PNP equivalent
      feature) — keep bespoke commands, just trim the `mydsl` prefix.
- Scope: touches ChatWrapper, CombatView, AffectsView, MoonWeather — do as
  its own pass, not mixed into other fixes.

---

## Character-binding — "Unknown" fallback gap, fixed 2026-07-07

Per Steven: "if we are separating things by character, we should prob have
a default for unknown characters that havent set anything up?" Real gap,
confirmed by reading the code, not a hunch: every character-bound
module's `charName()` falls back to `"Unknown"` until GMCP identifies the
character, and each module's *initial* load runs at script-boot time —
which on a genuinely fresh Mudlet start happens **before** login. So on
every normal session start, ChatWrapper/LayoutEngine/WindowRegistry/
TargetView/CombatView/History-font all loaded `"Unknown"`'s file (or bare
defaults) and had no mechanism to ever pick up the real character's saved
settings once login completed — `MyDSL.restoreChar()` (called from
DataLayer's `gmcp.login_data` handler) only restores
`State.score/lunar/flags/improve/affects`, nothing per-window. This
wasn't a hypothetical — it's the normal path every session takes.

**Fixed**: `MyDSL_DataLayer.lua`'s `gmcp.login_data` handler now also
raises `"MyDSL.character.identified"` once the real name is known.
Registered a handler for it in each affected module (re-runs that
module's own load + apply):
`MyDSL_ChatWrapper.lua`, `MyDSL_LayoutEngine.lua` (+ reflows already-created
windows), `MyDSL_WindowRegistry.lua` (+ re-applies visibility via
show()/hide() on already-created windows, since `loadState()` alone only
updates the registry's `visible` field), `MyDSL_TargetView.lua`,
`MyDSL_CombatView.lua`, `MyDSL_RouteHelper.lua` (History font).
**`MyDSL_AffectsView.lua` needed no change** — already immune by a better
design: `A.display()` calls `A.checkCharacterProfile()` on *every* render
(not just at boot), so it self-heals the moment anything actually redraws.
Verified via a real emulation test: booted with no GMCP (pre-login) — used
`"Unknown"`'s defaults correctly — then fired the event with a real
character name that had a pre-existing saved file (fontSize 5, not the
default 8) — confirmed the real saved value loaded and applied
immediately, not just at the next reload. All 7 touched files
syntax-checked. Needs Steven to confirm live across a real fresh login
(not just a script reload while already connected).

---

## LOW PRIORITY — Confirmed still-open code gaps

- [x] **ChatWrapper**: `chat_settings.lua` character-bound 2026-07-07 (was
  a single shared file) — same `charName()`/`safeFileName()` pattern as
  TargetView/AffectsView, now `chat_settings_<Char>.lua`.
  Still open: tab active/inactive CSS still hardcoded (no ThemeEngine
  hookup) — not touched, a real design pass, not a mechanical fix.
- [x] **ThemeEngine — fixed 2026-07-07.** `setOverride()` now rejects any
  key not already present in `MyDSL.Theme.defaults` (the canonical key
  set), logging via `debugc()` and returning `false` instead of silently
  accepting a typo'd key that nothing would ever read. Verified via
  emulation test: a valid key (`fontSize`) sets correctly, an invalid one
  (`fontSizee`) is rejected and logged.
- [x] **LayoutEngine — fixed 2026-07-07.** `resetAll()` added (+ new
  `mydsl layout reset` alias in `MyDSL_WindowRegistry.lua`, resets
  in-memory positions and reflows, doesn't auto-persist — same
  explicit-save convention as the rest of layout); `save()` now wrapped in
  `pcall` with a debug log on failure; window positions
  (`MyDSL_layout.lua` → `MyDSL_layout_<Char>.lua`) character-bound.
- [x] **WindowRegistry — fixed 2026-07-07.** Visibility state
  (`MyDSL_windowstate.lua` → `MyDSL_windowstate_<Char>.lua`)
  character-bound; `saveState()` now wrapped in `pcall` with a debug log
  on failure.
- [x] **GroupView member-name truncation — fixed 2026-07-07.** Was a flat
  `m.name:sub(1, 20)` — a 22-char mob name ("A throughbred stallion") got
  cut mid-word ("A throughbred stalli"). Added the same `cutText()` helper
  `AffectsView` already uses (truncate + trailing `~`), reused rather than
  reinvented. Syntax-checked, verified directly against the real
  22-char name ("A throughbred stall~"). Needs Steven to confirm live.

None of these are blocking anything in progress — pick up opportunistically.

---

## IN PROGRESS — Systematic bottom-up integrity audit

Re-verifying the whole project against the reuse-PNP/EMCO mandate, starting
at the lowest layer (DataLayer) and working up. Paced as a multi-session
project, not a single sweep.

**Layer 1 (DataLayer):**
- [x] Score/prompt/vitals — confirmed correct as-is (GMCP-first is the
      legitimate modern replacement for PNP's text-based approach, not a gap)
- [x] Who-list parsing — was silently corrupting kingdom/name on WANTED/clan
      tags, fixed (see CHANGELOG 2026-07-05)
- [ ] Not yet audited: lunar, weather, group, scan, creaturelore (may
      share the who-list bug pattern — needs its own check against
      `DSL_PNP_People.lua`'s other trigger variants). **Superseded for
      inv/unread/improve/whok/whoc/map by the 2026-07-07 full inventory
      above — these aren't "not yet audited," they're confirmed
      unreachable** (the parse functions exist and are presumably
      correct, but nothing ever calls the begin/end triggers that would
      feed them). See "Unwired capture pipelines" above.

**Layers 2-4:** not started this pass.

---

## DESIGN — Not Yet Started

- [ ] **Cross-profile master function/feature inventory** (requested
      2026-07-06, explicitly deferred to its own future session — "not
      interrupt this session"). Goal: walk every `.lua` file across every
      Mudlet profile on this machine (DSL2, PNP profile, PNP1, PNP2, DSL1,
      DSL - Kien) and build one consolidated list of functions/features,
      removing anything superseded or duplicated across profiles — "one
      list to rule them all." Large, multi-session scope; do not start
      opportunistically inside an unrelated task.
- [ ] **Layer 4: Reference library** (items, mobs, lore) — not started.
      Check `~/Downloads/Shattered-Archive-release-dev.zip` (open-source
      DSL-specific MUD client/tooling monorepo, has its own in-game
      research/data tools) before building from scratch — not yet audited.
- [ ] **Deferred until current UI workload finishes** (per Steven):
      - Mapper hardening/MyDSL integration — `dslmapper`/`generic_mapper`
        was edited by Steven; sibling profiles have further mapper progress
        worth reviewing when this is picked up. Per Steven (2026-07-07):
        the mapper processes room names anyway, so once it's rolled into
        this UI it could be a useful backup/cross-check source for room
        identity — relevant to `MyDSL_CharacterAssist.lua`'s vision check
        (confirmed 2026-07-07 to already work via `MyDSL.State.room.name`
        from GMCP directly, see the Phase D entry above), and potentially
        to anything else that currently only trusts GMCP's room_data.
      - Data-driven notes/quest tracking — streamline `notes_utf8.txt`'s
        in-game feature/quest items via data files instead of manual notes.

---

## DECISIONS RECORDED

- All settings (theme, layout, visibility) are character-bound (in
  principle — see LOW PRIORITY above for what's not actually there yet)
- Themes: user-creatable named presets, shared across all characters
  (intentionally not character-bound)
- `MyDSL_Mapper` removed from WindowRegistry — minimap via
  `map.configs.map_window` only, not a Geyser.UserWindow
- CharPic compatibility code removed from PortraitView (no DSL1 triggers
  call any `CharPic.*` function)
- RouteHelper `routeMap` removed — shorthand helpers (`Route.history()` etc.)
  are the only API
- Prompt: toggleable pretty prompt, default ON
- Day/Night derived from `time` command, not prompt capture
- Alignment from score only, persists until next score run, no auto-send
- **Window docking/positioning (verified current, 2026-07-06):** every
  `Geyser.UserWindow` gets `restoreLayout=true` + `autoDock=true` via a
  single global constructor patch (`patchUserWindowConstructor()` in
  `MyDSL_WindowRegistry.lua`) — not per-window docking declarations. Startup
  order: `patchUserWindowConstructor()` → `Windows.loadState()` →
  `Windows.ensureAll()` → `loadWindowLayout()` called exactly once,
  immediately after all windows exist (no race condition, no timers — a
  timer-based retry would fight the user by snapping windows back
  mid-session). To persist a layout: `mydsl layout save`. (This supersedes
  the older, more complex per-window `docked=true`/`dockPosition` model
  described in the now-deleted Contract_Addendum — that model was itself
  superseded by the simpler constructor-patch approach at some point and
  the addendum was never updated to say so.)
