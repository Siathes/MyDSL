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

- [ ] **AlterformView — countdown/auto-hide confirmed live 2026-07-12
      ("everything seems to work"); fixed a real chrome bug found same
      session.** Steven: "the window needs to not be visible unless the
      alterform affect is active. you can see the min/close buttons."
      Root cause, confirmed by reading Mudlet's real bundled
      `GeyserAdjustableContainer.lua`: the constructor's `lockStyle =
      "padding"` field did nothing — a container is only actually locked
      if `locked = true` is *also* passed at creation (never was), and
      `"padding"` isn't even one of Mudlet's real lockStyle names
      (`standard`/`border`/`full`/`light`) — so it silently fell back to
      fully unlocked, all native chrome (min/restore, close, lock, save,
      load buttons) live and visible regardless of the countdown's own
      show/hide state. Fixed by calling the real API,
      `lockContainer("light")`, after creation — Mudlet's own documented
      style for hiding just the min/restore and close labels. Needs one
      more live look. **`MyDSL_MoonWeather.lua` has the identical
      `lockStyle = "padding"` pattern and almost certainly has the same
      latent bug** — not touched yet, pending Steven's confirmation he
      wants it fixed there too.
- [ ] Timer consolidation (shared `MyDSL.Timers.Slow` heartbeat) — implemented
      2026-07-11, needs live confirmation (Improve countdown ticking live is
      confirmed as of 2026-07-12; the shared-heartbeat mechanism itself
      still needs a general check across the other windows that use it).
- [ ] CharacterAssist: rearm (weapon+shield), spellup/setspell,
      blind-vision check.
- [ ] Equipment capture — parser is real and tested, but
      `MyDSL.State.equipment` isn't wired to any display window yet.
      Needs a live `eq` to confirm the parser end-to-end.

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
