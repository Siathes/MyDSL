# DSL Observer UI — TODO
*A current punch list only — resolved/historical items live in `CHANGELOG.md`
and git history, not here. Restructured 2026-07-06 (see CHANGELOG for why).*

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
      combat line; not conclusively proven

Unconfirmed in-game (may just need a real occurrence to test against):
- [ ] Sharp proc — no trigger text observed in any log to date
- [ ] Poison sequence (setup/onset/tick) — our own addition, no PNP equivalent

Discuss once the above is confirmed working (deliberately deferred, per
Steven: "make it work like PNP, then discuss the additions"):
- [ ] Whether `renderSummary()`'s persistent multi-fight "Fight summary"
      block (our own addition, no PNP equivalent) should be reformatted to
      match PNP's sentence style or kept in its current table style

---

## OPEN — Reported bugs

- [ ] **GroupView heal quick-action doesn't work on Mob rows** — healing a
      charmed pet (bear, stallion) via the Group window's [Heal] button
      fails. Unlike `rescue` (intentionally filtered for Mob rows), `heal`
      is supposed to work on pets — needs investigation into why it fails.
- [ ] **GroupView not populating** — reported not working; needs repro
      steps (was Steven actually grouped at the time?).
- [ ] **Chat capture bug** — grabs the first letter of the following line;
      traced to the GMCP `S` echo colliding with chat capture.
- [ ] **Clan gossip duplicates in chat window** — possibly same root cause
      as the chat-routing item below.
- [ ] **Chat routing script possibly duplicated** — two overlapping capture
      paths suspected; needs a direct check against what's actually wired.
      No prior design work exists to recover (confirmed via Claude.ai
      cross-check) — this is fresh diagnosis work.
- [ ] **Roller behaves differently than PNP's** (`DSL_PNP_Roller.lua` is the
      reference) — no prior comparison exists, fresh work.
- [ ] **RightHere should update on `look` too**, not just `scan`.
- [ ] **autowhere fires while sleeping** — Steven's own alias, not ours;
      low priority for us specifically.

---

## OPEN — Design ideas, not yet scoped

- [ ] **TargetView: auto-populate target on aura detection** — when
      detect-good/detect-evil shows, auto-set to first opposing-alignment
      mob visible, else first mob not in your own group.
- [ ] **Skills/Spells → Combat window** — want skill/spell actions you
      actually take (not raw attack spam) to echo to main and copy to
      Combat, matching PNP's philosophy. No PNP precedent exists for this
      specifically (confirmed: `DSL_PNP_Battle.lua` has zero spell/skill
      handling — new ground). Real skill-action text confirmed in `log/`
      (`"You disarm Jhawsh!"`, `"You kick!"`) but needs a dedicated
      cataloging pass across many skills/spells before it can be scoped.
- [ ] **Item-clickable reference module** — item names clickable (underline,
      not color change) instead of echoing stats on identify; pull from a
      persistent DB on click. Depends on Layer 4 (not started).
- [ ] **Census (from UI) should interact with the reference module** —
      depends on Layer 4.
- [ ] **Incorporate `colors.xml` (DslColor) into the UI** — design question,
      not scoped.
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
- [ ] `emco <verb>` — EMCO's own native aliases (`emco show/hide/font/gag/
      ...`) already reach the same `demonnic.chat` object our ChatWrapper
      wraps. Our custom `mydsl chat show/hide/font/...` aliases are likely
      fully redundant once confirmed — candidate for deletion, not rename.
- [ ] Combat's extra sub-toggles (`show_miss`/`show_evade`/`show_flag`/
      `show_condition`) have no PNP alias equivalent — keep a short bespoke
      form (e.g. `combat show miss`).
- [ ] Scan/Target/Group/CreatureReference are net-new (no PNP equivalent
      feature) — keep bespoke commands, just trim the `mydsl` prefix.
- Scope: touches ChatWrapper, CombatView, AffectsView, MoonWeather — do as
  its own pass, not mixed into other fixes.

---

## LOW PRIORITY — Confirmed still-open code gaps

- **ChatWrapper**: tab active/inactive CSS still hardcoded (no ThemeEngine
  hookup); `chat_settings.lua` still a single shared file, not
  character-bound.
- **ThemeEngine**: `setOverride()` has no key validation (silently accepts
  any key).
- **LayoutEngine**: `resetAll()` does not exist; `save()` has no error
  handling around `table.save()`; window positions (`MyDSL_layout.lua`)
  are a single shared file, not character-bound (contradicts the recorded
  decision that all settings should be character-bound).
- **WindowRegistry**: visibility state (`MyDSL_windowstate.lua`) not
  character-bound; `saveState()` has no error handling around
  `table.save()`.
- **DataLayer**: no `equipment`/`eq` parser at all.

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
- [ ] Not yet audited: lunar, weather, group, inv, unread, improve, scan,
      creaturelore, whok/whoc/whocraft (may share the who-list bug pattern —
      needs its own check against `DSL_PNP_People.lua`'s other trigger
      variants), map

**Layers 2-4:** not started this pass.

---

## DESIGN — Not Yet Started

- [ ] **Layer 4: Reference library** (items, mobs, lore) — not started.
      Check `~/Downloads/Shattered-Archive-release-dev.zip` (open-source
      DSL-specific MUD client/tooling monorepo, has its own in-game
      research/data tools) before building from scratch — not yet audited.
- [ ] **Deferred until current UI workload finishes** (per Steven):
      - Mapper hardening/MyDSL integration — `dslmapper`/`generic_mapper`
        was edited by Steven; sibling profiles have further mapper progress
        worth reviewing when this is picked up.
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
