# DSL Observer UI — TODO
*A current punch list only — resolved/historical items live in `CHANGELOG.md`
and git history, not here. Restructured 2026-07-06; pruned 2026-07-07 after
it grew back to 1300+ lines; pruned again 2026-07-11 after it grew to 1900+
lines; pruned a third time 2026-08-27 after it grew to 2700+ lines (every
`[x]`-marked item removed outright per this file's own rule — resolved work
already has a permanent record in `docs/CHANGELOG.md` and git log, restating
it here was pure duplication; the "needs live confirmation" backlog this
file itself flagged as a problem at 14+ items was consolidated into one
list instead of a paragraph each). If this file is turning back into a
growing append-only history again, prune it — don't let it happen a fourth
time.*

**Feature creep is paused as of 2026-07-07, per Steven** — bug fixes, live
confirmation, and finishing already-scoped work only. Nothing under
DEFERRED gets started without an explicit go-ahead.

---

## TOP PRIORITY — project-wide audit & optimization phase (opened 2026-08-23)
Per Steven, both in chat and independently in MyDSL's own `notes_utf8.txt`
("moving into the optimization phase soon for UI... do a really really
thorough deep scan of the current state of the project... cross check
connections of modules... make sure its all in the same namespace...
review it like its a new project"). Explicit go-ahead for a dedicated audit
phase, separate from and in addition to the per-item live confirmations
below.

**See `docs/MYDSL_1.0_ROADMAP.md` for the big picture** — a per-module
status table across all 44 audited units and the phase order for what's
left before "feature complete" 1.0. `docs/OPTIMIZATION_AUDIT.md` is the
live per-file tracker (pass 1 + pass 2, all 44 units); `docs/MYDSL_1.0_
MODULE_REDESIGN.md` is the Toggle/Connection/Verdict pass on top of it.
This section stays as the current punch list only.

- [ ] **New, not yet started: native dock-tab-group label styling.**
      Steven asked whether the small tabs shown when multiple windows
      share a dock side can also be colored to match. Confirmed: no
      per-window hook exists — the only lever is `setAppStyleSheet()`,
      whole-Mudlet-application scope, real risk of bleeding into parts
      of Mudlet's UI outside this addon if the selector isn't scoped
      carefully. Needs its own careful validation pass before attempting.
- [ ] **Triaged 2026-08-27 from `docs/myresponses.txt`** (Steven's own
      "Pass 2" notes, written directly into a personal copy of
      `docs/OPTIMIZATION_AUDIT.md`, 2026-08-25 — cross-checked against
      the 2 days of work since; most of the 46 notes turned out already
      resolved or already tracked elsewhere, see `docs/CHANGELOG.md`'s
      2026-08-27 entry for the full reconciliation). Genuinely still
      open, bounded items only — the bigger design asks (mapper
      full-rewrite, mob-diary wiki window, spell/skill alias shortcuts,
      project-wide alias-dedup sweep) are tracked instead under "OPEN —
      Design ideas, not yet scoped" below, not here:
      - `MyDSL_RawCapture.lua`'s `mydsl rawlog` diagnostic — Steven:
        "this can be removed as it doesn't sound like it's needed." The
        audit itself already questioned whether it's still wanted since
        the concern it was built to catch doesn't apply to DSL2. Needs
        a scoping check (whole file vs. just this one diagnostic) before
        removing.
      - `MyDSL_Roller.lua` — verify the pre-port native trigger is
        actually gone, not just documented as fixed.
      - `MyDSL.save()`/`table.load()` naming ambiguity (`MyDSL_
        DataLayer.lua`) — 9 modules call something by that name; only 2
        (`MyDSL_CreatureLore.lua`, `MyDSL_AffectsView.lua`) got
        disambiguated in the module-redesign pass. 7 unconfirmed:
        `MyDSL_CombatView.lua`, `MyDSL_GroupView.lua`, `MyDSL_
        LayoutEngine.lua`, `MyDSL_TargetView.lua`, `MyDSL_PromptView.lua`,
        `MyDSL_WindowRegistry.lua`, `MyDSL_ThemeEngine.lua`. Steven also
        asked for this explained back to him plainly once confirmed, not
        just fixed silently.
      - `MyDSL_ThemeEngine.lua` — Steven asked to discuss design/theme
        options "to make it user friendly." `99c370d`'s new/edit/delete/
        preview theme customization landed ~80 min after this note was
        written — likely already answers it; worth a direct confirm.
      - `MyDSL_ChatTriggers.lua` — Steven's note asks specifically
        whether it captures ALL chat channels, broader than the
        per-channel gag/show already shipped 2026-08-26. Needs a real
        coverage check (compare against `scripts/check_text_coverage.py`
        results for chat-shaped unmatched lines).
      - `MyDSL_ItemLore.lua` — Steven is unsure the ground-item-tracking
        feature is worth building as designed; needs a design
        conversation before anything here moves.
      - `MyDSL_GroupView.lua` — real selectable/dropdown quick-action
        buttons instead of the current setup. Design discussion.
      - `MyDSL_CharacterAssist.lua` — Steven: "we plan on just
        consolidating these issues?" — needs him to say which issues.
      - `MyDSL_Help.lua` — Steven: "this needs a lot of work, design
        philosophy discussion." Not scoped.
- [ ] **`build_mydsl_package.py` doesn't splice `MyDSL_PersonalAliases.xml`
      into the built package** (found during the 2026-08-23 native-content
      inventory, still true — confirmed no `AliasPackage` handling exists
      in the build script at all). A from-scratch reinstall still wouldn't
      restore Steven's 29 hand-built personal aliases without a manual
      import of that file separately.
- [ ] `scripts/check_text_coverage.py` has two confirmed extraction blind
      spots (wrapper-function-built patterns in `MyDSL_ChatTriggers.lua`/
      `MyDSL_CharacterAssist.lua`/`MyDSL_Leveling.lua`; narrowed-variable
      `:find()`/`:match()` calls slipping past the genericness filter) —
      documented in the script's own "Scope" docstring, not yet fixed.
      Low urgency (affects the *ranking*, not the tool's core design).
- [ ] **From the first real `check_text_coverage.py` run (2026-08-25),
      still open**: the entire login/character-creation flow was
      completely uncaptured at the time (now addressed by `MyDSL_
      Login.lua`'s own patterns, but worth re-running the coverage tool
      to confirm); and one isolated real gap never picked up —
      `"Reconnecting your master account due to LD"` (90 occurrences), a
      disconnect/reconnect notification nothing currently handles.
- [ ] **Real decisions needed from Steven, native content**:
      - `DslColors_Core_v1_0.xml` has no master on/off — its full
        803-term-vocabulary scan runs unconditionally on every non-blank
        line, only a minor `echo on/off` notification setting exists.
        Also a real per-line perf cost (`dslBoundedFind()` re-lowercases
        the line on every one of ~803 term comparisons instead of once).
        Needs a real toggle + the lowercase-once fix.
      - **30 native `<mSoundFile>` entries in `MyDSL_GameplayTriggers.xml`
        hardcode `/home/owner/Desktop/Mudlet/mudlet-data/profiles/DSL2/
        Sounds/...`** — works today (same physical directory, confirmed
        via inode check) but not portable to a fresh install. Fixing
        means converting each of the 30 to `playSoundFile(getMudletHomeDir()
        .. "/Sounds/...")` — real native-XML surgery across 30 trigger
        blocks, flagged for a decision rather than done blind.
      - `scripts/check_known_patterns.py` only scans `.lua` files — both
        bugs above were invisible to its `--all` sweep purely because
        they live in XML. Worth extending it to the 4 native files.
      - `MyDSL_PersonalAliases.xml`'s 29 personal command-shortcut
        aliases aren't "features" in the sense Principle 2 was written
        for — whether Principle 2 is meant to reach this far is a real
        open question.
- [ ] **Trivial cleanup, low priority**: `MyDSL_GameplayTriggers.xml`'s
      "BACKSTABS Fail" trigger has its entire script body commented out
      (PNP-era dead code, still fires and matches, does nothing) — safe
      to remove whenever the native XML is next hand-edited for
      something else.
- [ ] **Mapper GMCP-parsing merge into DataLayer — approved, not started.**
      Steven confirmed 2026-08-25 the mapper fork never runs standalone,
      so its independent GMCP re-parsing of `char_data`/`room_data` is a
      real, clean dedup win, not a correctness risk anymore. Needs its
      own dedicated pass (touches native `DSL_Generic_Mapper.xml`, 6,631
      lines, a live currently-working system) — not folded into general
      per-file cleanup. **Distinct from** the bigger "full DSL-specific
      rewrite" idea tracked under Design Ideas below — this one is a
      dedup optimization, not a redesign.
- [ ] **`MyDSL_Full.mpackage` — one combined package, needs a full live
      confirmation pass.** Chat fully self-contained (EMCO ported in, no
      separate EMCOChat dependency), namespace fully MyDSL-owned. `Sounds.
      zip`/`RoomPics.zip` ship separately (media can't be embedded in a
      `.mpackage`) — placement instructions in `INSTALL.md`. No packaged/
      documented process for the PNP base-client prerequisite (always
      manual). Package-format root cause (nested `MyDSL_Full` wrapper)
      fixed 2026-08-26 — see `docs/MUDLET_PACKAGING_REFERENCE.md`, read
      before every build.

---

## LOW PRIORITY
- [ ] **`MyDSL_DataLayer.lua` split-by-domain refactor — code complete
      2026-08-25 (5 slices, 4,745 → 995 lines, 79% moved into 5 new
      domain files).** Slices 1-2 (CreatureLore, Combat) live-confirmed
      against real play the same day. **Slices 3-5 still need Steven's
      live confirmation**: `MyDSL_DataLayer_ScanLook.lua` (scan/look/
      players-near — needs a `scan`, a `look`, and a "Players near you:"
      listing), `MyDSL_DataLayer_ItemLore.lua` (identify/lore/equipment/
      inventory/containers), `MyDSL_DataLayer_PromptVitals.lua` (score/
      flags/lunar/time/weather/who/group/improve — needs `score`, a flag
      toggle, `who`, grouping up, and a skill practice). Full detail:
      `docs/CHANGELOG.md` (2026-08-25).
- [ ] Two personal aliases in the live MyDSL profile are cosmetically
      mislabeled (`^pqf$` shows as "(pqr) PQ Request Find", `^pqh$` shows
      as "(pqr) PQ Request Hunt") — fixed in the tracked backup, the live
      Mudlet Alias editor entries still need a 2-second manual rename by
      Steven whenever he's in there next.

---

## NEEDS LIVE CONFIRMATION
Fixed in code, verified via structural tests/syntax checks — none of this
is closed until Steven confirms it in-game. Consolidated 2026-08-27 (was
14+ items, several 5+ weeks old, each with a full paragraph — full
technical detail for any of these: `git log --oneline` + `docs/
CHANGELOG.md`, not restated here):
- [ ] DataLayer room-capture: 3 more fixture-line gaps + an NPC-verb gap
      ("stands/sits behind the bar") — watch for any capture regression
      during normal play (RightHere/Scan/Leveling/CreatureLore all read
      from this).
- [ ] Focus/TargetView populating during a Leveling fight AND during
      normal manual combat — two prior "not populating" reports (2026-
      07-25 Leveling-specific, 2026-08-23 general) both traced to the
      same `MyDSL.Target.set()` wiring; needs a real fight to confirm
      both cases now work.
- [ ] Mapper: "air" terrain color while flying, room weight from real
      movement cost, terrain-color "set once" lock + `rt`/`room terrain`
      override alias, `dslroom raw` as a one-stop room-info command.
      (Steven already confirmed 2026-08-24 "fix seems to be fine" for
      the terrain-lock half specifically — the rest of this bundle
      hasn't had its own separate confirmation.)
- [ ] PlayersNear font size surviving a reload.
- [ ] Location/Portrait "ran smoother before the Mudlet update" — still
      not root-caused, needs specifics from Steven: which Mudlet version,
      and whether this is about Location, Portrait, or both (scaling/
      quality vs. timing/flicker vs. something else) — a fresh screenshot
      showing the actual problem would narrow this down faster than more
      code reading.
- [ ] CharacterAssist: rearm (weapon+shield) itself hasn't been
      separately confirmed (spellup/setspell and the blind-vision check
      already were, 2026-07-15).
- [ ] `MyDSL_AutoWhere.lua` — both manual wiring steps confirmed done,
      never actually tested live.
- [ ] Roller double-reject bug fix (native trigger now disabled on load).
- [ ] PVP performance pass (debounced saves, gated raw-capture, batched
      buffer trims) — built on code audit, not measurement; worth a real
      lag check during an actual fight if lag ever comes up again.
- [ ] **Still true going forward**: anything Steven adds to the native
      Mudlet package folder by hand (Triggers/Keys/Scripts) is invisible
      to the next `build_mydsl_package.py` run unless it's git-tracked —
      confirmed once already (the 2026-07-19 data-loss incident), worth
      remembering before the next hand-added native item.
- [ ] Identify persistence (casting `identify` should authoritatively
      clear stale scraped fields, not just fill gaps) — fixed twice
      (2026-07-19 merge logic, 2026-08-24 source-scoping for observed-
      vs-self-identify) but Steven's 2026-08-23 note describing the same
      symptom might predate one of those fixes or be a fresh recurrence.
      Needs a fresh live identify + check either way.
- [ ] Fuzzy name-matching (mob ID via `resolveMobName()`, ground-item
      mapping via `resolveGroundItem()`) — built, not yet wired into any
      display/hover UI beyond the resolver itself.
- [ ] RightHere silently dropping mobs listed after certain uncovered
      item-flavor-text lines (9th instance of this bug class — an
      allowlist-growing pattern worth a real "default to keep capturing"
      redesign discussion with Steven if it recurs a 10th time).
- [ ] Murder/Consider/Order-All → "They're not here" when a duplicate-mob
      RightHere entry's count doesn't decrement on a mid-fight kill.
- [ ] Affects window top row not clickable to recast.
- [ ] `setspell` bare-command usage message.
- [ ] LocationView: quote-stripping for `mydsl location set "..."`/`map
      <room> = "..."`.

---

## OPEN — Combat, remaining loose ends
Per-swing display, evasion triggers, both death-line forms, weapon-flag
proc attribution, and the PNP-faithful display rewrite are confirmed
correct (code review + a real live fight, 2026-07-11) — see
`CHANGELOG.md`. Still open:
- [ ] **DEFERRED, per Steven ("we can wait a bit longer on")**: Algoron
      Combat League (AGL) / Coliseum combat module — new idea, not
      scoped. Should be captured separately, in a large window with 4
      floating sub-windows at the cardinal positions matching the
      Coliseum's wall echoes. Groundwork (bracket-prefix format,
      applicable procs) already gathered — see CHANGELOG.
- [ ] **Fight-summary conclusiveness — the one real remaining gap**:
      whether direct-damage offensive spells (shock bolt, firebolt,
      lightning bolt, magic missile, etc.) use the same capturable
      grammar as regular weapon/skill swings. Zero real corpus examples
      of any of these actually landing in combat — can't confirm this is
      captured OR that it's missing. Needs a live fight where a damage
      spell gets cast and logged, then a check of whether it shows up in
      the summary. (Skills with no damage number at all — bash's
      knockdown, trip, riot, dirt-kick — are confirmed to genuinely have
      nothing for a "landing %" to attach to; not a gap.)

---

## PAUSED — needs more captured log data before further progress
Per Steven: "lets pause the capture logs phase... we will return to them
when we have more data to scan."
- [ ] `procUnholy`/`procManaSelf` — zero occurrences anywhere on this
      machine as of the last wide search (2026-08-23).
- [ ] `combatSense1/2` (sense-based evasion) — zero occurrences anywhere.
      Needs a bard specifically playing/logging.

---

## OPEN — Reported bugs, not yet fixed
- [ ] **Sibling-profile log scanning technique, worth remembering**: a
      targeted `grep -r` for a specific known phrase across every file in
      a sibling profile can pay off even when the profile looks mostly
      like debug noise — sampling one large file isn't representative.

---

## OPEN — Design ideas, not yet scoped
- [ ] **TargetView: show debuffs cast on the current target.** Zero real
      third-person/observer-side corpus text for weaken/slow/blindness/
      plague landing on someone else — only self-referential "you feel
      weaker" text exists, so these 4 stay placeholders. Poison is
      different and already built (`"<mob> looks very ill."` is real,
      generic, 8+ corpus occurrences) — see `MyDSL.Target.markPoisoned()`.
- [ ] **TargetView: auto-populate target on aura detection.** Zero real
      corpus examples of DSL ever displaying a detected aura on anyone —
      placeholder only until a live catch of real detect-good/evil aura
      display text exists to build against.
- [ ] **TargetView: auto-populate from a room's `scan` output.**
      Mechanically buildable, deliberately not built without a design
      decision first: which mob gets picked when `scan` shows several
      (hostile vs. friendly, multiple hostiles), whether it overrides an
      already-manually-set target, and whether it conflicts with
      Leveling's own `MyDSL.Target.set()` calls during an active run.
- [ ] **Skills/Spells → Combat window** — echo real skill/spell actions,
      reduce raw per-swing spam. Warrior/thief skills still have zero
      confirmed first-person text anywhere in the corpus.
- [ ] **Command vocabulary — more IC/human-speak, less `mydsl <module>
      <verb>`.** Design direction, not scoped.
- [ ] Census (from UI) interacting with the reference module — Layer 4
      (ItemLore/ItemReference) exists, so this is unblocked whenever
      picked up; not yet scoped otherwise.
- [ ] **DSL event/date reminder module** — Steven: "a DSL reminder that
      allows you to enter events and dates and have it come up as a
      reminder when logged in or playing... I believe there are also
      events in the calendar or holidays of the DSL wiki. Some way to
      connect this to Discord would be optimal!" Not scoped — needs: what
      counts as an "event" (manual entry vs. scraped from the DSL wiki),
      whether Discord integration is in scope for this pass (would be
      the first outbound-network call in this project, worth a design
      discussion on its own), and whether the referenced Achaea Mudlet
      calendar package on GitHub is worth checking for a reusable
      pattern first.
- [ ] **Mapper — full DSL-specific rewrite, not a patch.** Steven, from
      `docs/myresponses.txt` (2026-08-25): wants the Generic Mapper fork
      rebuilt specifically for DSL rather than patched on top of the
      stock package, with new/requested features designed in and the
      current stock code kept only as design reference — same treatment
      EMCO already got. **Distinct from the already-approved, narrower
      item above** ("merge the mapper's GMCP handling into DataLayer") —
      that's a dedup optimization; this is a from-scratch redesign. Real
      scoping conversation needed — no size estimate exists yet.
- [ ] **CreatureLore "mob diary" wiki window.** Steven, from
      `docs/myresponses.txt`: a themed window showing everything
      `creaturelore` has captured about a mob — stats, every location/
      area seen, possible map rooms, a manually-added picture (same
      pattern as room pics). Should also populate TargetView's stats.
      New feature — needs a design discussion (window layout, how
      "locations seen" gets recorded, picture-assignment workflow).
- [ ] **Extend the creaturelore/identify alias-shortcut pattern to
      spells/skills/other commands.** `bestiary <name>`/`item <name>`
      (send `creaturelore`/`identify` + show the window) have existed
      since 2026-07-11 — Steven's actual new ask is extending that same
      pattern to spells/skills or other game commands he names. Needs
      him to name real candidates first.
- [ ] **Project-wide alias-dedup + namespace-guard sweep.** Minimize/
      remove aliases that exist only because of spelling-mistake variants
      or duplicate helper names. The namespace-guard *standard* is
      documented (`docs/MYDSL_1.0_PHILOSOPHY.md`); whether every file
      actually follows it hasn't been swept. Real grep-driven audit,
      not started.
- [ ] **A whole quest-tracking mechanic has zero coverage anywhere** —
      quest start/expire/timer messages. Matches the DEFERRED "data-
      driven notes/quest tracking" item below, same underlying gap.
- [ ] **Mapper: toggleable button bar** for map-editing commands (shift,
      area add, rename, etc).
- [ ] **Mapper: alternate/angled exit lines** (Z-shaped, not just
      straight) — "discuss this."
- [ ] **Mapper: labels reportedly don't move anymore** — no confirmed
      cause found in Mudlet's public issue tracker (checked 2026-08-24);
      genuinely needs Steven's own live reproduction (which Mudlet
      version, what he actually sees) before further research can narrow
      it down.
- [ ] **DslColor**: track a player's kingdom/clan membership changes over
      time, not just current state; "last seen" should reflect real
      in-game physical location, not just presence on the `who` list;
      emerald dragon color palette; audit that titles/palettes/terms are
      consistently colored, check Thax/Thaxanos kingdom coloring
      specifically against real logs.
- [ ] **Player-profile fields** (alignment, god, notes, hp, mana, etc.) —
      explicitly "brainstorm this," not scoped.
- [ ] **Roller**: pull more comparison stats (racial/class baselines)
      from Shattered/the local knowledge base; investigate whether a
      reconnect-without-full-reload is possible to survive the server's
      roll time limit — "this will require planning."
- [ ] **Restrings**: an in-character-flavored guide/workflow for writing
      them — references Steven's own Obsidian notes, outside this repo.

---

## DEFERRED — explicitly held, no new scope without Steven's go-ahead
- [ ] **Shatteredarchive.com maps** — checked the local zip (2026-08-24):
      no room coordinates/exit graphs/images, just flat per-continent
      area-NAME lists. Whatever "maps" Steven saw on the live website
      isn't in this local dump. The area-name lists might have marginal
      value as a canonical reference (autocomplete/validation for
      `mydsl leveling area new <name>`) but that's much smaller than
      "maps" and not built without being asked.
- [ ] **Layer 4 reference library remainder** — items and mobs/lore are
      done; whatever else was meant under this heading (areas/zones/
      general lore) isn't scoped, and the Shatteredarchive dump doesn't
      have enough content to build one from.
- [ ] **Inventory hover scope expansion** (hover on carried-not-worn
      items) + ground-vs-inventory name mapping — explicitly deferred by
      Steven 2026-07-18 ("not sure we need"). Revisit only if he asks
      again.
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
  aliases unless one becomes relevant to a window.

---

## DECISIONS RECORDED
- **Adopted a project-local known-bad-pattern checker + Claude Code hook
  — 2026-07-21, per Steven.** `scripts/check_known_patterns.py`, a small
  script encoding real historical bugs from `docs/CHANGELOG.md` as grep
  rules, wired into a `PostToolUse` hook (`.claude/settings.json`) that
  runs automatically against every file `Edit`/`Write` touches. Run
  `python3 scripts/check_known_patterns.py --all` periodically for a
  full-repo sweep (catches mistakes already latent in untouched files).
  When a new bug class is fixed and might exist elsewhere too, add a rule
  instead of a one-off grep.
- **"Passive observation only, never send automatic game commands" — the
  hard blanket rule is retired, per Steven 2026-08-23** ("ignore the
  automation bad comments now, we have moved past that restriction.
  drinking and eating are fine also"). **What's still true, not touched
  by this change**: the "automate to assist, not to decide for the
  player" distinction (spellup reminders/disarm alerts help the player
  decide faster; something that sends a genuinely *different* command
  than what the player typed is a different shape of thing) still
  applies and still needs its own explicit sign-off case by case (see
  `docs/MyDSL_IdeaBacklog.md`).
- **Mapper: `start mapping` stays a manual gate, not auto-persisted —
  confirmed 2026-07-18, per Steven.** `map.mapping` is one of Generic
  Mapper's own in-memory-only "protected" fields, resets to `nil` on
  every script reload by design — Steven manually re-running `start
  mapping` after every reinstall is expected, not a bug.
- **CreatureLore's `lore <name>` "gap" — confirmed a non-issue,
  2026-07-16.** `lore` is a general item-only skill, nothing to do with
  creatures; `creaturelore <target>` is DSL's real creature-info command
  and DSL2 already captures it correctly.
- **LiveView's "age" field — confirmed correct as-is, 2026-07-16.**
  Elapsed real-world time since character creation, distinct from DSL's
  own separate roleplay age stat (`practice age`), which stays
  uncaptured/undisplayed by design.
- **Itemstat trigger retirement — sequencing confirmed 2026-07-16.**
  Retires naturally once Layer 4 (the item reference library) replaces
  the equipment parser's dependency on it — no separate decision needed
  before then.
- **"Prompt Line 1" parsing — dropped, confirmed 2026-07-16.** Prompt
  gagging already works correctly with quiet mode active; the scenario
  this was meant to cover doesn't occur.
- **Staying on Mudlet 4.20.1, not 4.21/4.22** — confirmed 2026-07-12 real
  upstream bug: `TMainConsole::getUserWindowSize()` (PR #9334) returns a
  stale cached size for a shrunk docked `UserWindow`, breaking every
  percentage-positioned child (Tick's bars, Focus's button grid).
  Reverting to 4.20.1 fixed everything immediately. **Don't
  re-investigate Tick/Focus/other-docked-window sizing bugs as a MyDSL
  problem without first checking the installed Mudlet version** — if a
  future upgrade is considered, check whether this shrinkage guard has
  been revised upstream first.
- Most settings (theme, visibility, chat, fonts, TargetView/AffectsView)
  are character-bound. **Window layout is the one deliberate exception**:
  per-profile, not per-character.
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
