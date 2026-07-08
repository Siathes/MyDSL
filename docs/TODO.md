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
**`MyDSL_RawCapture.lua` — confirmed via screenshot 2026-07-08
(`Screenshot_20260708_155236.png`)**: now the very first item in the
whole script tree (above even "Startups"), checked/enabled, correct
`dofile(".../MyDSL_RawCapture.lua")` line — exactly right placement, runs
before any other script/trigger. **Still not in `current/autosave.xml`
on disk** — this is Mudlet's live in-memory Script Editor state, not yet
persisted. Needs Steven to click "Save Profile" in the Editor toolbar;
until then a real Mudlet restart would likely lose this change entirely
(Mudlet loads from the on-disk file at startup, not the editor's live
state). Re-check `current/autosave.xml` after that's done.

---

## NEEDS LIVE CONFIRMATION
Fixed in code, verified via syntax checks and/or the emulation test harness
(`test/mudlet_mock.lua`) — none of this is closed until Steven confirms it
in-game. Full technical detail for any of these: `git log --oneline` +
`docs/CHANGELOG.md`.

- [ ] Logging defaults rework — `mydsl log <category> on` re-enables a
      debug-only window's log file
- [ ] AffectsView countdown paces correctly in real time; near-expiry color
      warning fires
- [ ] CharacterAssist: rearm (weapon+shield), standup, spellup/setspell,
      blind-vision check
- [ ] Equipment capture — `eq`/`equipment` populates `MyDSL.State.equipment`
- [ ] TargetView `[Friend]`/`[Enemy]` tag — `dslcolor friend/enemy <name>`,
      then target them
- [ ] `mydsl who <name>` passthrough to `dslcolor show <name>`
- [ ] DataLayer fresh-start crash fix — needs a **full Mudlet restart**,
      not just a script reload, to actually test
- [ ] ChatTriggers channel routing (3 rewrite passes) — real chat
      activity reaches the right EMCO tabs
- [ ] `mydsl help` / `mydsl history font <n>` commands work
- [ ] `MyDSL_RawCapture.lua` — still needs its `dofile()` entry added
      (see LOW PRIORITY above) before this can be tested at all
- [ ] TargetView group/follower safety guard — target a charmed pet/group
      member, murder/order-all buttons should be gone
- [ ] TargetView/GroupView kill vs murder verb fix — order-all/murder a
      mob should now say "kill", not "murder"
- [ ] Roller — next character creation
- [ ] RightHere updates on `look`, not just `scan`
- [ ] CombatView/History font persistence — `mydsl combat font <n>` /
      `mydsl history font <n>` survive a real restart
- [ ] Action-button color contrast — Rescue/cure-spell buttons actually
      readable now
- [x] **Layout: character-binding + auto-save both reverted 2026-07-08,
      per Steven** ("revert the layout save and per character layout
      save. we will keep it layout per profile and use lua
      saveWindowLayout() cause its not woking right and i dont want to
      have that fight again"). Full history: character-binding (2026-07-07)
      caused Kien's UI to snap to generic defaults on login (no
      per-character file existed yet); recurred 2026-07-08 since `mydsl
      layout save` was never actually typed either session (confirmed via
      both logs); auto-save was then built same-day with debounce +
      suppression safeguards against the specific docking-corruption
      failure mode a prior attempt hit — verified working via emulation,
      but reverted anyway per Steven's direct preference for simplicity
      over continuing to maintain custom layout-persistence logic.
      **Final state**: `MyDSL_LayoutEngine.lua`'s `SAVE_FILE` is back to
      the fixed, non-character-bound `MyDSL_layout.lua`; the
      `MyDSL.character.identified` → `Layout.load()`+`reflowAll()` hook
      is removed entirely (nothing character-specific to reload anymore);
      `MyDSL_WindowRegistry.lua`'s `saveLayout()` (`mydsl layout save`)
      now just calls native `saveWindowLayout()`/`saveProfile()` — the
      custom capture-into-percentages-and-write-our-own-file steps are
      gone. `MyDSL.Layout`'s percentage system still exists for a
      window's first-ever creation coordinates and `mydsl layout reset`,
      just no longer drives ongoing persistence. Verified via
      `test/mudlet_mock.lua`: `saveLayout()` calls native
      `saveWindowLayout()` and does not write a custom file;
      `character.identified` no longer touches layout. **Confirmed live
      2026-07-08 by Steven** ("layout seems to be functioning as it
      should now") — closing.
- [ ] GroupView name truncation (cosmetic)
- [ ] `considerEasyKill`/`considerNoMatch` text in-game
- [ ] `MyDSL.logWindow()` fragmented-row fix — GroupView/TargetView logs
      show one line per row, not one word per line
- [ ] LiveView Improve bar — type `improve`, check the bar populates with
      skill/percent/remaining minutes

---

## TOP PRIORITY — Combat, needs live-fight testing
Fixed in code, none of it confirmed against a real sustained fight yet:
- [ ] Evasion triggers (dodge/parry/block, you-as-subject aware)
- [ ] Both death forms (`is DEAD!!` / `hits the ground ... DEAD.`)
- [ ] Weapon-flag proc attribution via `last_attacker`/`last_target`/`last_noun`
- [ ] Quoted weapon names (`"Nadrik's Honor"`)
- [ ] PNP-faithful display rewrite (per-swing live feed, round-summary to
      main, `mydsl combat mode raw|condensed|gag`)

Confirmed broken, not yet fixed:
- [ ] Self-condition never registers — DSL phrases your own condition in
      second person ("You have some small wounds"); our trigger + PNP's
      both only match third person
- [ ] Itemstat interference with `$`-anchored combat regex — real,
      native-XML system, not conclusively proven to break our triggers.
      Confirmed via live A/B test that it also decorates `eq`/`in` output
      (`-[level] stat,stat` suffix is 100% client-side, not server text).
      `MyDSL_DataLayer.lua`'s equipment parser only gets stat data today
      *because* this system supplies it — if itemstats get disabled before
      Layer 4 ships a replacement, equipment stats silently go blank.
      Sequencing risk to remember when Layer 4 is picked up, not a
      standalone fix.

Unconfirmed in-game (zero occurrences in the log corpus to date, may just
need a real occurrence):
- [ ] Sharp proc
- [ ] Poison sequence (setup/onset/tick) — our own addition, no PNP equivalent
- [ ] procUnholy/procManaSelf/procVampDrain/procFrostTouch/procShockShocked
- [ ] combatSense1/2 (sense-based evasion) — also absent from PNP source,
      can't tell if real-but-rare or invented
- [ ] procFlameSear/procHolyWrath/procPoisonTick, `A.ids.triggers.song`
      (AffectsView "Song:" format) — all of their prior "confirmed" matches
      turned out to be pre-DSL2 log data
- [ ] Two bracket-prefix line formats (coliseum spectator `[ Wall ]` prefix,
      PNP Highlighter's `"[51] Name"` rewrite) — both real DSL mechanisms,
      neither ever seen in DSL2-era logs; low priority unless one shows up
      live

Discuss once combat is confirmed working (deliberately deferred, per
Steven: "make it work like PNP, then discuss the additions"):
- [ ] Whether `renderSummary()`'s persistent "Fight summary" block (our own
      addition, no PNP equivalent) should match PNP's sentence style

---

## OPEN — Reported bugs, not yet fixed
- [x] **GroupView not populating — confirmed fixed 2026-07-07, per Steven
      live.** "groupview works, there have been many edits since that bug
      report." Not independently isolated to one specific fix — resolved
      as a side effect of everything else touched this session.
- [ ] **Clan gossip duplicates** — no confirmed lead currently exists (a
      prior "likely root cause" was investigated and retracted). Needs a
      live repro: does the duplicate come from `MyDSL_ChatTriggers.lua`
      itself double-appending, EMCO's `allTab` mirroring, or something
      else. **Note:** `MyDSL_ChatTriggers.lua` currently has no `dofile()`
      entry at all (see BLOCKING section above) — it isn't running right
      now, so it can't be the current cause of any live duplication until
      that's fixed and re-tested.
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
