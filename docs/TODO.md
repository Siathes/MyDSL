# DSL Observer UI — TODO
*Updated 2026-07-05 — full staleness audit against live code. Claude.ai removed
from the workflow as of this date; Claude Code now owns keeping this file current.*

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

Still genuinely unconfirmed/unresolved (not new, carried forward):
- [ ] **Self-condition never registers** — DSL phrases your own condition in
      second person ("You have some small wounds"), our trigger + PNP's both
      only match third person. Confirmed via logs, not yet fixed.
- [ ] Sharp proc — no confirmed trigger text observed in any log to date
- [ ] Poison sequence (setup/onset/tick) — our own addition, not yet
      in-game re-confirmed

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
- [ ] **New 2026-07-05 (character-binding audit):** button config
      (`MyDSL/targetview_config.lua`, the `mob_buttons`/`player_buttons`
      set from `mydsl target mobset/playerset`) is a single shared file, not
      character-bound. Not previously flagged. Unclear if this *should* be
      per-character (a druid and a warrior might want different default
      buttons) or intentionally shared like ThemeEngine — needs a decision,
      not just a fix.

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
