# DSL Observer UI — TODO
*Updated 2026-07-05 — full staleness audit against live code. Claude.ai removed
from the workflow as of this date; Claude Code now owns keeping this file current.*

---

## IN PROGRESS — Systematic bottom-up integrity audit (started 2026-07-05)

Steven's request: re-verify the whole project against the new direct workflow
and the "reuse PNP/EMCO, don't reinvent" mandate, starting at the lowest
layer (DataLayer / data collection) and working up. Explicitly paced as a
multi-session project, not a single sweep — ~20 DataLayer parse functions
alone, each needing a real cross-check against the right PNP module and
`log/` evidence, not a shallow skim.

**Layer 1 (DataLayer) — in progress:**
- [x] Score/prompt/vitals — confirmed correct as-is. PNP's equivalent
      (`DSL_PNP_Statusbar.lua`) is fundamentally text/prompt-based because it
      predates/works around limited GMCP; our GMCP-first approach
      (`gmcp.char_data`) is the legitimate modern replacement, not a
      reinvention gap. `parsePromptLine()` only extracts the day/night
      "period" tag GMCP doesn't provide — no redundancy, correctly scoped.
- [x] **Who-list parsing — confirmed broken, now fixed.** `parseWhoLine()`
      only ever looked for the org/clan field in `[brackets]`. Real DSL
      format (confirmed in `DSL_CommandRef.md` *and* live in `log/`, and
      matching `DSL_PNP_People.lua`'s tested regex): clan/org codes are in
      `(parens)` — `(NT)`, `(VR)`, `(Abaddon)` — brackets are for kingdom
      names only. Old code's `entry.clan` was therefore always `nil`, and
      leftover parenthetical text (`(WANTED)`, `(VR)`, etc.) shifted every
      following word by one position, corrupting `kingdom`/`name` for any
      WANTED- or clan-tagged entry (confirmed: `"[27 Goblin Bnd] (WANTED)
      (VR) Vrokt."` parsed as `kingdom="()" name="(VR)"` instead of
      `org="VR" name="Vrokt"`). Rewritten to extract every `()`/`[]` group
      in order, classify status tags (`WANTED`/`Hostile`/`AFK`  — confirmed
      live in all three of bare/`[bracket]`/`(paren)` form, DSL isn't
      consistent) vs. org/kingdom text, verified against 5 real examples
      from `log/`. Dropped an unconfirmed `quiet` field (never found in
      `log/` or `DSL_CommandRef.md`). No downstream module consumed the old
      fields yet (no People/Friends view built), so this was safe to fix
      with no breakage — but real value once that Layer 4 work happens.
- [ ] Remaining DataLayer parse functions not yet audited this pass: lunar,
      weather, group, inv, unread, improve, scan, creaturelore, whok/whoc/
      whocraft (may share the who-list bug above — same bracket-only clan
      bug pattern, needs its own check against `DSL_PNP_People.lua`'s other
      4 trigger variants), map. Combat was already thoroughly audited
      2026-07-05 (see the Combat sections above/below).

**Layers 2-4:** not started this pass (Layer 2: ThemeEngine/LayoutEngine/
WindowRegistry; Layer 3: every view module's command surface, already
partially covered by the command-surface retrofit plan above; Layer 4:
not started at all as a feature, nothing to audit yet).

---

## ✅ DONE — Phase A Complete (2026-06-29)

All Layer 1 and Layer 2 systems working. All Layer 3 Phase A modules smoke
tested with Kien and confirmed working: DataLayer, ThemeEngine, LayoutEngine,
WindowRegistry, ChatWrapper, AffectsView, TickSource/TickView, PortraitView,
LocationView, LiveView. Window layout persistence working. Score trigger wired.

The two Phase-A score issues (`stance` capturing trailing text, `profession`
field missing) are fixed — confirmed still fixed in code as of this audit.

---

## ✅ DONE — Phase B (2026-07-02 through 2026-07-05)

All five Phase B windows are built, wired into DataLayer, and syntax-clean.
In-game confirmation status varies — see per-module notes:

| Module | Built | In-game confirmed? |
|---|---|---|
| MoonWeather | ✅ 2026-07-02 | ✅ Confirmed working by Steven |
| ScanView / RightHere | ✅ 2026-07-02 | ✅ Confirmed working in live combat |
| TargetView | ✅ 2026-07-02 | ✅ Confirmed working in live combat |
| GroupView | ✅ 2026-07-03 | ⚠️ Not yet confirmed — needs an in-game `group` smoke test |
| CreatureReference | ✅ 2026-07-02 | ⚠️ Not yet confirmed — needs an in-game `creaturelore` test in combat |
| CombatView | ✅ 2026-07-04, hardened 2026-07-05 | ⚠️ Not yet confirmed — needs a live combat session (see open items below) |

---

## OPEN — Combat window, from the 2026-07-05 PNP/log audit

All fixed in code, none yet live-tested:
- [ ] Evasion triggers (dodge/parry/block) rewritten to PNP's verbatim
      you-as-subject-aware patterns — needs a live combat session with someone
      dodging/parrying/blocking your attack (not just you missing theirs)
- [ ] Second death form (`<mob> hits the ground ... DEAD.`) now handled
      alongside `is DEAD!!` — needs a live kill to confirm `MyDSL.combat.ended`
      actually fires from this form
- [ ] Weapon-as-subject proc misattribution — weapon-named procs (Flame/Shock/
      Vamp/Stun) now get their own pseudo-attacker row instead of being
      dropped — needs a live proc to confirm the fight-summary row renders
      sanely (known cosmetic wrinkle: "(proc)" row shows "0 hits, 0 miss" above
      its flag count line — harmless but a little odd-looking, not fixed yet)
- [ ] Quoted weapon names ("Nadrik's Honor") — regex fix confirmed via
      `luajit` pattern test only, not yet seen matching a real quoted-name
      proc line in a live session
- [x] **Weapon-flag procs were never gagged, confirmed live 2026-07-05** —
      Steven's own cecho note during testing ("all i see on screen is A fine
      alloy great dagger draws life from an insane half elf...") confirmed a
      raw Vamp-proc line stayed on screen. Root cause: none of the 17 proc
      trigger handlers ever called `deleteLine()`, unlike every other combat
      trigger (damage/dodge/condition/death), which all already gag
      correctly. Fixed — all 17 now call a shared `gagIfCombatGagged()`
      helper. Needs live re-confirmation that a proc line is now actually
      gagged when `gag_combat` is on.
- [ ] **Possible interference from a separate "itemstats" trigger system** —
      Steven flagged (and I confirmed in `current/autosave.xml`, 319 hits) a
      pre-existing, unrelated item-identification trigger system (not part of
      `PNP files/` or our own code) that does a bare `cecho(" -[N] ...")`
      with no leading newline whenever certain item names are recognized.
      Plausible mechanism for silently breaking our `$`-anchored combat/proc
      regexes if an item name appears inline within a combat line (the
      item-stat suffix would get appended before our trigger evaluates the
      line). Not conclusively proven this session — the exact raw merged
      line wasn't found verbatim in the log, only Steven's paraphrased
      description of it. Toggle-able via a global `itemstats` variable.
      Needs a deliberate test: trigger a weapon proc on an item this system
      tracks and check whether our proc trigger fires.
- [ ] **No sustained combat happened in the 2026-07-05 evening test session**
      (16:21–18:08 logs) — no `murder`, no damage verbs, no deaths anywhere
      in those logs, confirmed via grep. Evasion, both death forms, and
      group-member fight tracking all remain unconfirmed by real combat data
      from this particular session; only the "group is working here" note
      (a solo `group` listing populating correctly) is a positive signal so
      far. **Important methodology note**: logs cannot confirm whether
      CombatView/GroupView/RightHere/TargetView actually *displayed*
      anything — Mudlet's session logs never capture custom-window content,
      confirmed by checking the session that had a screenshot proving the
      fight-summary rendered correctly at that exact moment (zero log
      matches for that text, ever). See
      `MyDSL_MudletAPIReference.md`'s new note. Screenshots were the only way
      to confirm window display **until now**:
- [x] **Fixed 2026-07-05** — Steven asked whether we could make the Combat
      window (and others) log, since Mudlet's `startLogging()` can't. Checked
      the Mudlet manual/wiki via search: confirmed no built-in per-window
      logging exists. Added `MyDSL.logWindow(category, text)` in DataLayer
      (Section 2) — mirrors any `mc:decho()`/`mc:dechoLink()` call into
      `MyDSL/logs/<category>/<YYYY-MM-DD>.log` (plain text, color tags
      stripped, one file per day). Wired into CombatView (`combat`),
      ScanView's RightHere render (`righthere`), GroupView (`group`), and
      TargetView (`target`) — every window-write in all four now logs. This
      also gives a real way to test the itemstats-interference concern above
      going forward: compare `MyDSL/logs/combat/` against the raw main-console
      log for the same moment to see if a proc/damage line silently failed
      to register.

Still genuinely unconfirmed/unresolved (not new, carried forward):
- [ ] **Self-condition never registers** — DSL phrases your own condition in
      second person ("You have some small wounds"), our trigger + PNP's both
      only match third person. Confirmed via logs, not yet fixed.
- [ ] Sharp proc — no confirmed trigger text observed in any log to date
- [ ] Poison sequence (setup/onset/tick) — our own addition, not yet
      in-game re-confirmed

---

## OPEN — From Steven's in-game notes (notes_utf8.txt, 2026-07-05)

- [ ] **GroupView heal quick-action doesn't work on Mob rows** — confirmed by
      Steven in-game: healing a charmed pet (bear, stallion) via the Group
      window's [Heal] button fails. Unlike `rescue` (already known and
      intentionally filtered for Mob rows, see `Contract_GroupView.md`),
      `heal` is supposed to work on pets — needs investigation into why it's
      failing, not just filtering it out.
- [ ] **TargetView: auto-populate target on aura detection** — when an aura
      shows (detect good/detect evil), TargetView should auto-set to the
      first mob of opposing alignment if one is visible; otherwise fall back
      to the first mob not in your own group. Design idea, not yet scoped.

## Claude.ai knowledge cross-check (2026-07-05) — clean-slate confirmed

Asked Claude.ai directly whether it had prior design context on 5 open
items, since some of this project's knowledge lives in that older
conversation. Its answer was direct about what it did and didn't have —
worth recording so nobody goes looking for prior research that doesn't
exist:

- **Chat routing / clan gossip duplication** — nothing. Genuinely new
  diagnosis work for Claude Code, not a redo.
- **Roller vs. `DSL_PNP_Roller.lua`** — nothing. Claude.ai read
  `DSL_PNP_Battle.lua`/`DSL_PNP_Support.lua` but never opened the Roller
  file or discussed a DSL2 roller module at all. From-scratch task.
- **Skills/Spells → Combat window** — partially related but not the same
  feature. What was designed: the severity ladder already distinguishes
  weapon-swing damage from spell-cast damage (ALLCAPS vs. lowercase verb
  forms). What was *not* designed: echoing the skill/spell action itself
  (not just its damage outcome) as its own Combat-window category. Confirms
  this is new ground, consistent with what was already found this session.
- **Command-surface retrofit** (`toggle <module>`/`emco <verb>`) — nothing,
  and Claude.ai was surprised by it as a plan. Every alias from that era was
  our own `mydsl <module> <verb>` convention. No prior mapping/naming
  decisions to recover — the retrofit plan above is 100% fresh design work.
- **Layer 4 / "Shattered Archive"** — completely blank, including the name
  itself. Confirms Shattered Archive is a brand-new discovery, not
  something already evaluated and set aside.

**One real catch from the cross-check:** verifying Claude.ai's "did the
pseudo-attacker-key design land?" question surfaced a genuine internal
contradiction in `Contract_CombatWindow.md` — its "What This Module Does
NOT Do" section still said combat tracking ignores ambient/non-group
fights, directly contradicting the "Scope filter" section's own 2026-07-05
update (which removed that filter entirely, on purpose). Fixed — see the
contract directly. Lesson: when a scope change is made in one section of a
contract, check the rest of the same file for restating the old scope
elsewhere, not just the section that prompted the edit.

---

## OPEN — Found during the 2026-07-05 folder/file sweep

- [x] **Round-by-round Combat display and Players-near-you routing —
      confirmed working live.** Checked `log/` before/after Steven's reload:
      "Players near you:" appeared 127 times untouched in the 18:48 log,
      zero times in both the 19:31 and 20:37 logs — confirms the routing/gag
      fix is live. A screenshot from 18:54 showed the old pre-fix state; that
      was just a stale reload timing, not a bug.
- [x] **Combat font 9→8, History font added at 8** (Steven: "battle text
      needs to be a little smaller 8? history text 8"). History has no
      dedicated view module — it's routed generically via
      `MyDSL_RouteHelper.lua`'s `getOrCreateConsole()`, which hardcoded
      `fontSize = 9` for every routed window. Added a per-window override
      table there instead of a global change, so only History moved to 8.
      Steven's note "this should all be tied in with the layout script
      though" — still true, none of these font sizes are in-game-adjustable
      or persisted yet, same open item as before.
- [x] **RouteHelper-routed windows now get `MyDSL.logWindow()` coverage
      too** — History/PlayersNear/Scan/Bloodbath previously had no logging
      at all (only CombatView/GroupView/ScanView's RightHere/TargetView got
      it when that feature was built). `Route.to()` now mirrors into
      `MyDSL/logs/<windowname>/` for every routed window, same pattern.
- [x] **Window logging made toggleable** (Steven: didn't want
      "players near you" logged at all). `MyDSL.LogConfig` (DataLayer) —
      `enabled` master switch + `disabled_categories` per-category opt-out,
      `playersnear` disabled by default. `mydsl log on/off` and
      `mydsl log <category> on/off` aliases.
- [ ] **Skills/Spells → Combat window** (Steven: wants skill/spell actions
      you actually take to echo to main *and* copy into the Combat window,
      "same as PNP," while cutting down on raw attack spam). Investigated:
      `DSL_PNP_Battle.lua` has zero spell/skill handling — this is not a
      port-from-PNP situation, it's new ground, same category as our own
      Poison-proc addition. Confirmed real skill-action text exists
      (`"You disarm Jhawsh!"`, `"You kick!"`) but a robust trigger needs a
      proper cataloging pass across many skills/spells first — not enough
      confirmed patterns yet to implement responsibly. Needs its own
      dedicated `log/` research session before this can be scoped, let
      alone built.
- [ ] **Shattered Archive discovered** (`~/Downloads/Shattered-Archive-release-dev.zip`,
      524 files) — an open-source DSL-specific MUD client + tooling
      ecosystem (shatteredarchive.com), including "extensive in-game
      research and data tools." Directly relevant to the not-yet-started
      Layer 4 reference library (items/mobs/lore) — worth checking whether
      it already solved item/mob database tooling before building ours from
      scratch, same reuse-before-reinvent principle as PNP/EMCO. Not
      audited yet — just flagging its existence and location.

---

## OPEN — Command-surface retrofit (queued for after Steven's combat-pass testing, 2026-07-05)

Core mandate restated by Steven: reuse PNP/EMCO's actual command vocabulary,
not just their internal logic, so migrating from PNP/EMCO doesn't mean
learning new commands. See `docs/MyDSL_MudletAPIReference.md`'s "Reuse
PNP/EMCO's actual command vocabulary" note and
[[project_reuse_pnp_emco_philosophy]] for full rationale. Steven wants
commands short/efficient/clear — rejected the idea of just prefixing
everything with `mydsl` as inefficient.

**Already done (safe, low-risk, didn't need to wait):**
- [x] Neutralized EMCO's live self-updater alias (`emco update` — was doing
      `uninstallPackage("EMCOChat")` + reinstall from GitHub, confirmed live
      in `current/autosave.xml`). Disabled (not deleted) via
      `MyDSL_ChatWrapper.lua`'s new `disableEmcoUpdateAlias()`, called from
      `C.install()` every load.
- Deliberately NOT touched: `generic_mapper`'s own internal
  `uninstallPackage("generic_mapper")` call — buried deep inside its
  vendored "Map Script" blob, not an isolated alias like EMCO's; mapper work
  is already separately deferred (see DESIGN section below). Also not
  touched: Mudlet's own built-in "mudlet accessibility reader" alias —
  unrelated to this project.

**Held until after Steven's combat-pass testing (his call, 2026-07-05):**
- [ ] `toggle <module>` — PNP's real universal on/off alias is already live
      (`raiseEvent("onToggle", module, option)`). CombatView/AffectsView/
      MoonWeather should hook this same event instead of registering
      competing `mydsl combat gag`/`mydsl affects show`/`mydsl moon toggle`
      aliases. Proposed: `toggle combat`, `toggle affects`, `toggle moons`.
- [ ] `emco <verb>` — EMCO's own native aliases (`emco show/hide/font/gag/...`)
      are already live and reach the same `demonnic.chat` object our
      ChatWrapper wraps. Our custom `mydsl chat show/hide/font/...` aliases
      are likely fully redundant once confirmed, not just renamed —
      candidate for deletion, not just a rename.
- [ ] Combat's extra sub-toggles (`show_miss`/`show_evade`/`show_flag`/
      `show_condition`) have no PNP alias equivalent (PNP only exposes these
      via editing its config table directly) — keep a short bespoke form,
      e.g. `combat show miss` instead of `mydsl combat show miss`.
- [ ] Scan/Target/Group/CreatureReference are net-new (no PNP equivalent
      feature at all) — keep bespoke commands, just trim the `mydsl` prefix,
      e.g. `target mobset` instead of `mydsl target mobset`.
- Scope: touches ChatWrapper, CombatView, AffectsView, MoonWeather at
  minimum — multiple already-working, already-tested modules. Do this as
  its own deliberate pass, not mixed into other fixes.

---

## OPEN — From Steven's 2026-07-05 live-test session (notes_utf8.txt)

First live-combat confirmation of the 2026-07-05 CombatView fixes: fight
summaries are rendering correctly in-game (confirmed via screenshot, on
Vaelis — a red fox/snow weasel/Shaenus Sha'falas/rabbit all summarized
correctly with hit/miss/% landed).

- [x] **Round-by-round display hidden by default was a real gap** — partially
      fixed 2026-07-05 (config redesign), but Steven's live test on Vrokt
      still showed only the fight-summary, zero round-by-round lines, even
      after that fix. Root cause found the same day: the round-flush handler
      (`MyDSL._handlers.combatRoundFlush` in DataLayer) was registered on
      `"MyDSL.time.updated"` — which only fires when the player manually
      types `time` — instead of `"MyDSL.char.updated"` (raised by
      `update("char", ...)` on every `gmcp.char_data` packet, the real
      once-per-round vitals-refresh signal). So `round_data` accumulated
      correctly the whole time (the damage trigger populates it fine) but
      never got flushed to `CV.render()` during an actual fight — only
      `snapshotFight()`'s kill/flee/rescue path (a separate code path) ever
      fired, which is exactly why fight summaries worked while the live
      round log never appeared. Fixed: handler now listens on
      `"MyDSL.char.updated"`. Confirmed the config-redesign fix from earlier
      (removing `show_damage_by_me`/`show_damage_to_me`/`echo_to_main`) was
      necessary but not sufficient — this was the actual blocker. Needs
      live-test confirmation on the next fight.
- [x] **CombatView should include fight reports for group members** — fixed by
      removing `isRelevant()` entirely from `parseCombatDamageLine()` and
      `parseCombatAvoidLine()`. Confirmed PNP has no relevance filter at all
      — it tracks every combat line unconditionally. Known tradeoff: ambient
      bystander fights (`A boar's charge misses a liger cub.`) will also
      track again now, same as they would in PNP. See
      `Contract_CombatWindow.md`'s "Scope filter" section. Needs live-test
      confirmation this actually surfaces group members' own fights (still
      unconfirmed whether DSL's broadcast even sends you that text).
- [ ] **GroupView not populating** — reported not working; unconfirmed whether
      Steven was actually grouped at the time or `group` output failed to
      populate the window. Needs repro steps.
- [x] **"Players near you:" → MyDSL_PlayersNear routing + gag, fixed 2026-07-05.**
      Investigated per Steven's question ("where does that stand?"): found
      `MyDSL.Route.players(line)` already existed in `MyDSL_RouteHelper.lua`
      (full working implementation, auto-creates the MiniConsole) but was
      **never called from anywhere** — `MyDSL_PlayersNear` was a registered
      window with zero code ever routing into it. The existing scan catch-all
      only used the `"Players near you:"` line as a signal that scan had
      ended, never gagged or routed it. Added `MyDSL.beginPlayersNear()`/
      `endPlayersNear()` in DataLayer (mirrors `beginScan`/`endScan` exactly)
      plus a permanent `"^Players near you:$"` trigger — captures the header
      + each `<Name><padding><Room>` line (confirmed shape from `log/`) via
      `Route.players(nil)` (appendBuffer, preserves original colors) and
      gags each from main console, ending on the blank line. Needs live-test
      confirmation. Note: this is triggered by Steven's own external
      "autowhere" alias (runs `where` every ~20s) — not part of this
      project, just the thing that produces the text we now capture.
- [ ] **autowhere should not fire while sleeping** — currently fires
      regardless of character state. (Steven's own alias, not ours — low
      priority for us specifically, more his to tune.)
- [ ] **Chat capture bug** — grabbing the first letter of the following line;
      Steven traced this to the GMCP `S` echo colliding with chat capture.
- [ ] **Clan gossip duplicates in chat window** — possibly same root cause as
      the next item.
- [ ] **Chat routing script possibly duplicated** — Steven flagged the DSL2
      chat-routing script itself as possibly duplicated; needs a direct check
      against what's actually wired (may explain the clan-gossip duplication
      above).
- [ ] **Roller needs to be fixed to match PNP's roller** — current DSL2 roller
      behaves differently than PNP's; PNP's is the reference implementation.
- [ ] **RightHere should update on `look` too**, not just `scan`.
- [x] **Combat/RightHere/Group font sizes fixed 2026-07-05** (per Steven's
      screenshots) — Combat 10→9, RightHere had no explicit fontSize at all
      (fell back to Mudlet's tiny default) → now 9, Group 10→8 (was
      overflowing the window width — a row is class tag + name + hp/mana/mv
      + 2 buttons). Still not adjustable in-game or persisted per-character
      — that part of the ask remains open, needs a decision like the other
      font/config persistence gaps already tracked.
- [ ] **History window font** — still needs to be adjustable in-game and
      persist (character-bound, presumably — needs a decision like the
      other font/config persistence gaps already tracked). Not touched in
      the 2026-07-05 font pass (Combat/RightHere/Group only).
- [ ] **History window scrollbar doesn't match other windows** — cosmetic;
      Steven notes it may not be needed at all unless the window actually
      scrolls.
- [ ] **Sound/room file naming convention** — loose `.mp3`/room-picture
      filenames use underscores instead of spaces, making it awkward to
      copy/paste a display name directly into a rename. Quality-of-life ask,
      not scoped yet.
- [ ] **State-scoped sound toggle** — need a way for an alias to turn a sound
      on for a state and reliably turn it back off when that state ends
      (example given: a sleep alias turns on a sleep sound, needs to turn it
      back off on wake/stand/rest/anything that changes you out of sleeping).
      Not scoped — needs a general "sound tied to state" pattern, not just a
      one-off for sleep.
- [ ] **TargetView button colors hard to see** — Steven's own note flags this
      as belonging to a later visual pass, not urgent now.
- [ ] **Incorporate `colors.xml` (DslColor) into the UI** — design question,
      not scoped. `colors.xml` was committed 2026-07-05 as reference
      material for this.
- [ ] **Census (from UI) should interact with the reference module** — design
      idea, depends on the not-yet-started Layer 4 reference library.
- [ ] **Item-clickable reference module idea** — instead of echoing item stats
      to the screen on identify, make the item name itself clickable
      (underline, not color change) and pull stats from a persistent
      database on click. Would cut down on trigger count significantly.
      Depends on the not-yet-started Layer 4 reference library.

- [x] **`order_attack` made a default mob button** (2026-07-05, per Steven) —
      swapped in for `glance` in the default `mob_buttons` set.
- [x] **TargetView button config made character-bound** (2026-07-05, per
      Steven) — `MyDSL/targetview_config_<CharName>.lua`, same
      charName()/safeFileName() pattern as `MyDSL_AffectsView.lua`. Was a
      single shared file.

**Still open — needs repro from Steven:**
- GroupView not populating — need repro steps (were you actually grouped?).

---

## LOW PRIORITY — Confirmed still-open code gaps (2026-07-05 audit)

Spot-checked every gap listed in the old version of this file against live
code. Most were already fixed and just never checked off (see "RESOLVED"
section below) — these are the ones still genuinely open:

### ChatWrapper (`Contract_ChatWrapper.md`)
- [ ] Gap 1 — tab active/inactive CSS still hardcoded, no ThemeEngine hookup
- [ ] Gap 4 — `chat_settings.lua` still a single shared file, not character-bound

### ThemeEngine (`Contract_ThemeEngine.md`)
- [ ] Gap 2 — `setOverride()` has no key validation (silently accepts any key)

### LayoutEngine (`Contract_LayoutEngine.md`)
- [ ] Gap 2 — `resetAll()` does not exist
- [ ] Gap 3 — `save()` has no error handling around `table.save()`
- [ ] **New 2026-07-05 (character-binding audit):** window positions
      (`MyDSL_layout.lua`) are a single shared file, not character-bound —
      contradicts the recorded decision "all settings (theme, layout,
      visibility) are character-bound." Not previously flagged in the
      contract at all.

### WindowRegistry (`Contract_WindowRegistry.md`)
- [ ] Gap 6 — visibility state (`MyDSL_windowstate.lua`) not character-bound
- [ ] Gap 7 — `saveState()` has no error handling around `table.save()`

### TargetView (`Contract_TargetView.md`)
- [x] **Button config made character-bound** (2026-07-05, per Steven's
      decision) — was a single shared file; now
      `MyDSL/targetview_config_<CharName>.lua`.

### DataLayer
- [ ] Gap 1 — no `equipment`/`eq` parser at all (confirmed still missing)

None of these are blocking anything currently in progress — low priority,
pick up opportunistically. See `CLAUDE.md`'s "Character-binding" section for
the full current inventory of what's bound correctly vs. not.

---

## ✅ RESOLVED — confirmed fixed in code, doc was just never updated (2026-07-05 audit)

These were listed as open bugs in this file and their respective contracts.
Checked each against live code directly; all confirmed fixed. Contracts
updated to match.

- [x] TickSource Gap 1/2/3 (warnTime alert, handler deregistration, loop
      generation counter) — all fixed by commit `b16ec52`
- [x] ChatWrapper Gap 2 (5.0s forced rebuild wiping early chat) — now guarded
- [x] ChatWrapper Gap 3 (fallback window position wrong) — now `x=78% y=0%
      w=22% h=46%`, matches confirmed layout
- [x] ChatWrapper Gap 5 (fragile 4-key window lookup) — now 2-key lookup
- [x] WindowRegistry Gap 2 (stale "18 windows" comment) — now says 20
- [x] RouteHelper — `routeMap` already removed per the addendum; the
      decho-vs-appendBuffer "gap" was never actually a bug — `decho()` is used
      only for caller-formatted (non-game) text by design, `appendBuffer()`
      still used for all real game-color text
- [x] DataBridge Gaps 1–6 (room.name, room.sector, DB.time, DB.affects, score
      text fields, hitroll/damroll/armor/items/posn) — all present in live code
- [x] DataLayer score `stance`/`profession` parsing — both fixed, matches
      SESSION_START.md's own (previously contradicted) claim

---

## DESIGN — Not Yet Started

- [ ] Layer 4: Reference library (items, mobs, lore) — not started
- [ ] **Deferred until current UI workload is finished (per Steven, 2026-07-05):**
      - Mapper hardening/MyDSL integration — the mapper (`dslmapper/` /
        `generic_mapper`) was edited by Steven and will need hardening to
        integrate with MyDSL properly; sibling profiles have mapper scripts
        showing further progress on this worth reviewing when it's picked up.
      - Data-driven notes/quest tracking — most of the in-game feature/quest
        notes (see `notes_utf8.txt`) are meant to be integrated/streamlined
        via data files eventually rather than living entirely in-game as
        manual notes. Separate project from the current UI work.

**Note:** MyDSL_PromptView was listed as "not yet started" / "contract stub" in
older versions of this file — that's stale. It's fully built (170 lines,
save/load/toggle/boot, prompt-gag-only design per its June 25 contract, which
superseded the earlier fancier PromptBar-with-HP-bars concept from the June 9
notes). Confirmed matches its current contract as of this audit.

---

## DECISIONS RECORDED (ready for implementation, unchanged from Phase A)

- All settings (theme, layout, visibility) are character-bound
- Themes: user-creatable named presets, shared across all characters
- MyDSL_Mapper removed from WindowRegistry — minimap via map.configs.map_window only
- Scan/Combat are native-docked + tabbed with mapper on the left
- CharPic compatibility code removed from PortraitView
- RouteHelper routeMap removed — shorthand helpers are the only API
- Prompt: toggleable pretty prompt, default ON
- Day/Night derived from `time` command, not prompt capture
- Alignment from score only, persists until next score run, no auto-send
- No sysWindowResizeEvent handler in LayoutEngine — was resetting windows on dock
- No setBorderLeft/Right/Bottom — Mudlet handles console space for docked windows natively
