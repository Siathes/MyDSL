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
- [ ] **`MyDSL_CreatureLore.lua` needs a `dofile()` Script entry.** Load
      order: after `MyDSL_DataLayer.lua`, before `MyDSL_TargetView.lua`/
      `MyDSL_CreatureReference.lua` (both read `MyDSL.CreatureLore.get()`,
      already guarded so exact order isn't load-critical).
- [ ] ChatWrapper tab active/inactive CSS still hardcoded — no ThemeEngine
      hookup. Real design pass, not a mechanical fix.

---

## NEEDS LIVE CONFIRMATION
Fixed in code, verified via syntax checks and/or emulation — none of this
is closed until Steven confirms it in-game. Full technical detail for any
item: `git log --oneline` + `docs/CHANGELOG.md`.

- [ ] **Focus (formerly TargetView) — extensive rebuild this session**
      (creaturelore stats, persistent cross-session DB, live health-bar
      nameplate merged with the mob name, graphical `Geyser.Button`
      action grid, auto-advance/clear on target death, several
      creaturelore parsing fixes). Full history in `CHANGELOG.md` — search
      "TargetView"/"Focus"/"nameplate"/"CreatureLore". One open item:
      - Needs the `MyDSL_CreatureLore.lua` `dofile()` entry (see LOW
        PRIORITY above) before any of the below can be tested for real.
- [ ] **CRITICAL, project-wide: `table.load()` was called wrong almost
      everywhere — found live 2026-07-11, fixed in ~10 places, needs live
      confirmation.** Steven's direct question ("are the settings loading
      at creating from save files or they saving and never
      reading/updating?") led to checking Mudlet's own bundled source
      (`mudlet-lua/lua/Other.lua`) directly. Real finding: `table.load(file,
      target)` **returns nothing at all** — it unpickles the saved data
      INTO an explicit second-argument table (or into `_G` if none is
      given). Confirmed independently via PNP's own real source
      (`PNP files/DSL_PNP_Data.lua`) and EMCO's own vendored source
      (`EMCOChat/emco.lua`) — both always call it with a destination
      table, never rely on a return value. Almost every persistence
      function in this codebase did `local data = table.load(path)` (no
      second argument) and then checked `type(data) == "table"` — always
      false, always silently "no saved data," every single time, project-
      wide. This means the "confirmed working" theme-persistence and
      window-visibility-persistence claims recorded earlier this session
      were only ever confirmed WITHIN a live session (setting and
      re-checking without a real restart in between) — neither ever
      actually survived a genuine restart either. **Fixed in**:
      `MyDSL_DataLayer.lua` (`MyDSL.load()` — the central character-data
      restore), `MyDSL_ThemeEngine.lua` (active theme), `MyDSL_
      WindowRegistry.lua` (window visibility state AND the new font-size
      store), `MyDSL_CreatureLore.lua` (the persistent creature DB),
      `MyDSL_TargetView.lua` (button-set config), `MyDSL_GroupView.lua`
      (quickset config), `MyDSL_CombatView.lua` (font size),
      `MyDSL_LayoutEngine.lua` (window layout positions),
      `MyDSL_PromptView.lua` (prompt-setup toggle). Also found the root
      cause of why NONE of this session's own persistence tests ever
      caught it: every test used a hand-rolled `table.save`/`table.load`
      stub that (unlike the real thing) DID return the loaded data
      directly — a well-intentioned but wrong stand-in. Built a byte-for-
      byte replica of Mudlet's actual algorithm (copied directly from its
      bundled source, confirmed to reproduce the exact real on-disk file
      format) and re-ran every persistence test against it — several
      (theme, creaturelore DB, the new font store) failed against the old
      code and pass against the fix, proving both the bug and the repair
      are real. `MyDSL_TickView.lua`/`MyDSL_LiveView.lua`/`MyDSL_
      AlterformView.lua` were checked too and are NOT affected — they use
      their own hand-rolled `io.open`+`dofile()` persistence instead of
      `table.load()`, which doesn't have this problem. Needs a genuine
      full Mudlet restart to confirm live: theme choice, window
      visibility, Focus/History font, Focus button customization, Group
      quickset, and any saved window layout should now all actually
      survive it.
- [ ] **Font-size persistence (Focus + History) — architecture change
      2026-07-11, separate from the table.load() bug above.** After
      Steven repeatedly reported "focus font"/"history font" not
      surviving a reload, moved font-size persistence out of each
      module's own character-bound file entirely and into
      `MyDSL_WindowRegistry.lua`'s new shared, PROFILE-level store
      (`MyDSL.Windows.getFontSize`/`setFontSize`, one file,
      `MyDSL_windowfonts.lua`) — matching Layout/Theme's own persistence.
      This alone wasn't the fix (the table.load() bug above was), but is
      still a real simplification worth keeping — removes the character-
      name dependency entirely. Old per-character font files
      (`targetview_config_<Char>.lua`'s fontSize field, `history_font_
      <Char>.lua`) are now dead/unused, harmless to leave on disk.
- [x] Combat scrollbar removed (was the original, never-touched value
      from its first version — missed by the earlier History/PlayersNear/
      Scan/RightHere/Target/Group consistency pass).
- [x] Native title-bar/border CSS (`windowChromeCSS()`) — confirmed live
      2026-07-12: works while floating, does not apply while docked
      (matches a documented Mudlet/Qt limitation, GitHub PR #4046). Since
      MyDSL's UserWindows normally run docked, Steven decided not to
      pursue it — `windowChromeCSS()` removed, `applyTheme()` reverted to
      plain `panelCSS()`.
- [ ] AlterformView timer — built 2026-07-11 (auto-hide when inactive,
      Adjustable.Container matching MoonWeather), needs live confirmation.
- [ ] LiveView v1A15 rebuild — full score-info layout rebuilt per Steven's
      hand-sketched design; several real DataBridge/font/color bugs found
      and fixed along the way. Needs a live look to confirm the whole
      layout, especially exits-color persistence across a room change.
- [ ] AffectsView countdown paces correctly in real time; near-expiry
      color warning fires.
- [ ] Timer consolidation (shared `MyDSL.Timers.Slow` heartbeat) + live
      Improve countdown — implemented 2026-07-11, needs live confirmation.
- [ ] CharacterAssist: rearm (weapon+shield), spellup/setspell,
      blind-vision check.
- [ ] Equipment capture — parser is real and tested, but
      `MyDSL.State.equipment` isn't wired to any display window yet.
      Needs a live `eq` to confirm the parser end-to-end.
- [ ] CombatView/History font persistence — `mydsl combat font <n>` /
      `mydsl history font <n>` survive a real restart.
- [ ] GroupView "follower not showing" — real bug (leading-space level
      field broke the whole group line match) found and fixed 2026-07-11,
      needs live confirmation.

---

## TOP PRIORITY — Combat, needs live-fight testing
Per-swing main-console display, evasion triggers, both death-line forms,
weapon-flag proc attribution, and the PNP-faithful display rewrite are all
confirmed correct (code review + a real live fight, 2026-07-11) — see
`CHANGELOG.md`. Still open:
- [ ] Itemstat interference with `$`-anchored combat regex — real,
      native-XML system, confirmed decorating `eq`/`in` output client-side.
      Not proven to break combat triggers yet. Sequencing risk to
      remember when Layer 4 (reference library) is picked up, since our
      equipment parser currently depends on itemstats for stat data.
- [ ] **DEFERRED: Algoron Combat League (AGL) / Coliseum combat module** —
      new idea, not scoped. Coliseum/AGL combat should be captured
      separately, in a large window with 4 floating sub-windows at the
      cardinal positions matching the Coliseum's wall echoes. Groundwork
      (bracket-prefix format, applicable procs) already gathered from this
      session's investigation — see CHANGELOG.
- [ ] Discuss once combat is fully confirmed (deliberately deferred, per
      Steven: "make it work like PNP, then discuss the additions"):
      whether `renderSummary()`'s persistent "Fight summary" block (our
      own addition, no PNP equivalent) should match PNP's sentence style.

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
- [ ] `autowhere` fires while sleeping — Steven's own alias, not ours; low
      priority for us specifically.
- [ ] Murder/Consider/Order-All → "They're not here" on look-populated
      wildlife targets — investigated, likely a genuine race (mob wanders
      off between `look` populating RightHere and the command reaching
      the server), not a TargetView name-matching bug. Not fully ruled
      out.
- [ ] "vexgar magic missile did not show in the main display, it did show
      in the combat window" — could not reproduce from available logs;
      may already be fixed by the `show_damage`/`show_miss` mode fix, not
      confirmed. Needs a fresh log with the actual cast line.
- [ ] "multiple mob health echoes in combat... one we create and one from
      the game" — likely the same already-tracked discussion as the
      `renderSummary()` "Fight summary" item above (TOP PRIORITY Combat),
      not independently confirmed as a separate issue.

---

## OPEN — Needs Steven's decision before building
- [ ] Itemstat trigger retirement timing — see the Combat section note
      above; just needs sequencing against Layer 4, not a decision now.
- [ ] "Prompt Line 1" parsing — not scoped, low priority, likely fully
      redundant with GMCP (`char_data.stance`/`language`/`is_flying`).
      Only worth it if a flag turns up that GMCP doesn't cover.

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

---

## DEFERRED — explicitly held, no new scope without Steven's go-ahead
- [ ] **`MyDSL_PromptSetup.lua`** — built 2026-07-09, put down for later.
      One-click DSL prompt setup for brand-new characters. Code exists,
      committed, but has no `dofile()` entry. Full design writeup:
      `docs/CHANGELOG.md`, commit `2ec4fb0`.
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
- **~20 misc aliases** (`(inv)`, `(autowhere)`, attire-swap sets, etc.) —
  fine as native aliases unless one becomes relevant to a window.

---

## DECISIONS RECORDED
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
