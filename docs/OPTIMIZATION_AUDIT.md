# MyDSL Optimization Audit

Formalizes the project-wide audit/optimization phase opened in
`docs/TODO.md`'s TOP PRIORITY section on 2026-08-23, per Steven ("moving
into the optimization phase soon for UI... check for lag spikes... do a
really really thorough deep scan of the current state of the project...
cross check connections of modules... make sure its all in the same
namespace... review it like its a new project").

**Pass 1 (this document, in progress): inventory only — no code changes.**
Every `MyDSL_*.lua` file (and `DSL_Generic_Mapper.xml`'s embedded Lua)
gets a section written as if seeing it for the first time on a new
project: what it does, its public surface, what it depends on, what
calls it, candidate cruft, and concrete performance flags. Every claim
in "Public surface" / "Depends on" / "Called by" is grep-confirmed
against the actual repo, not assumed from memory or the file's own
comments — a comment claiming a function is used doesn't count as
confirmation on its own.

**Pass 2 (not started): Steven's notes.** Steven reads each section,
adds his own notes directly into this doc (what he actually intended
for that file vs. what's really there), then Claude Code picks the file
back up, acts on the notes, does the real cleanup (removes confirmed-
dead code, fixes connection/namespace issues, addresses flagged
performance spots), and verifies the same way this project always does:
targeted revert to confirm a fix is real, full test suite +
`check_known_patterns.py --all`, live confirmation via `log/`/MyDSL's
own logs where possible.

Claude Desktop does spot-check QA on both the inventory and the
cleanups via the usual `HANDOFF.md` "check repo" loop.

## Data-only files (not inventoried individually)

These aren't modules — they're `table.save()` output, pure persisted
data with no logic, loaded via `table.load()` by their owning module.
Giving each one a full What-it-does/Public-surface/etc. writeup would
be noise:

- `MyDSL_windowstate_<CharName>.lua` (11 files, one per character ever
  played) — `MyDSL_WindowRegistry.lua`'s per-character visibility-state
  snapshot.
- `MyDSL_theme_settings.lua` — `MyDSL_ThemeEngine.lua`'s active-theme +
  override snapshot.
- `MyDSL_windowfonts.lua` — per-window font-size snapshot, several View
  modules read this via `MyDSL.Windows.getFontSize()`.

## Ordering

Per Steven: hot-path/foundation files first (everything else depends on
these, and they run on every incoming game line — a bad connection here
cascades everywhere), then view/feature modules roughly by size, then
`MyDSL_Chat.lua` last (biggest, most self-contained). `DSL_Generic_
Mapper.xml` placed right after the foundation group since its own known
duplicate-GMCP-parsing concern is exactly the kind of thing this audit
is looking for.

**Status legend**: ✅ done this pass · ⬜ not yet written.

1. ✅ `MyDSL_DataLayer.lua`
2. ✅ `MyDSL_DataLayer_CreatureLore.lua`
3. ✅ `MyDSL_DataLayer_Combat.lua`
4. ✅ `MyDSL_DataLayer_ScanLook.lua`
5. ✅ `MyDSL_DataLayer_ItemLore.lua`
6. ✅ `MyDSL_DataLayer_PromptVitals.lua`
7. ✅ `MyDSL_RawCapture.lua`
8. ✅ `MyDSL_TickSource.lua`
9. ✅ `MyDSL_DataBridge.lua`
10. ✅ `DSL_Generic_Mapper.xml` (embedded Lua)
11. ⬜ `MyDSL_PromptSetup.lua`
12. ⬜ `MyDSL_AutoWhere.lua`
13. ⬜ `MyDSL_PromptView.lua`
14. ⬜ `MyDSL_MovementSounds.lua`
15. ⬜ `MyDSL_CreatureLore.lua`
16. ⬜ `MyDSL_Roller.lua`
17. ⬜ `MyDSL_ChatTriggers.lua`
18. ⬜ `MyDSL_ItemLore.lua`
19. ⬜ `MyDSL_ItemReference.lua`
20. ⬜ `MyDSL_RouteHelper.lua`
21. ⬜ `MyDSL_CreatureReference.lua`
22. ⬜ `MyDSL_ScanView.lua`
23. ⬜ `MyDSL_CombatView.lua`
24. ⬜ `MyDSL_state.lua`
25. ⬜ `MyDSL_GroupView.lua`
26. ⬜ `MyDSL_TickView.lua`
27. ⬜ `MyDSL_CharacterAssist.lua`
28. ⬜ `MyDSL_LayoutEngine.lua`
29. ⬜ `MyDSL_Help.lua`
30. ⬜ `MyDSL_ThemeEngine.lua`
31. ⬜ `MyDSL_AlterformView.lua`
32. ⬜ `MyDSL_WindowRegistry.lua`
33. ⬜ `MyDSL_PortraitView.lua`
34. ⬜ `MyDSL_Leveling.lua`
35. ⬜ `MyDSL_MoonWeather.lua`
36. ⬜ `MyDSL_AffectsView.lua`
37. ⬜ `MyDSL_LocationView.lua`
38. ⬜ `MyDSL_LiveView.lua`
39. ⬜ `MyDSL_TargetView.lua`
40. ⬜ `MyDSL_Chat.lua`

---

## 1. `MyDSL_DataLayer.lua`

**995 lines** (down from 4,745 — see the split-by-domain refactor,
`docs/TODO.md`/`docs/CHANGELOG.md` 2026-08-25). Now holds only Sections
1-8: the shared infrastructure every domain module depends on.

**What it does:**
- Namespace guard (Section 1): ensures `MyDSL` exists exactly once.
- Private utilities (Section 2): `trim()`, plus the cross-domain-
  promoted `MyDSL.normalizeForMatch()`/`MyDSL.bestFuzzyMatch()` (needed
  by both `MyDSL_DataLayer_ScanLook.lua` and `MyDSL_DataLayer_
  ItemLore.lua`).
- State table (Section 3): `MyDSL.State.*` — the single in-memory
  source of truth for everything DataLayer and its split files capture
  (char, login, room, affects, tick, score, lunar, time, weather, who,
  group, scan, groundItemOverrides, combat, and more).
- Character name resolution (Section 4): `MyDSL.Char()`.
- Event bus (Section 5): `MyDSL.on()`/`MyDSL.emit()` — the pub/sub
  layer other modules are supposed to use instead of touching `State`
  directly.
- Get/Set API (Section 6): `MyDSL.get()`/`MyDSL.set()` — meant to be
  the only sanctioned way to read/write `State` from outside this file.
- GMCP handlers (Section 7): the real entry point — `gmcp.char_data`,
  `gmcp.login_data`, `gmcp.room_data`, `gmcp.tick`, `gmcp.affect_data`/
  `add_affect`/`remove_affect` all land here first, translated into
  `update(section, fields)` calls.
- Persistence (Section 8): `MyDSL.save()`/`MyDSL.load()`, debounced
  disk writes (see Performance flags — already fixed once, keep as-is).

**Public surface** (confirmed via grep, real external callers only):
- `MyDSL.Char()` — used everywhere; the character-binding primitive
  nearly every module needs.
- `MyDSL.emit(section)` — called internally by `update()`/`MyDSL.set()`
  only; no external module calls it directly (external modules listen
  via `raiseEvent`-style Mudlet event handlers on `"MyDSL.<section>.
  updated"` instead, or via `MyDSL.on()`).
- `MyDSL.on(section, cb)` — **only `MyDSL_Leveling.lua`** uses this in
  real code (`test_leveling*.lua` also uses it, same thing). Every
  other module that reacts to DataLayer changes uses
  `registerAnonymousEventHandler("MyDSL.<section>.updated", ...)`
  instead.
- `MyDSL.get(section, field)` — **only `MyDSL_MovementSounds.lua`**
  calls this in real code. See Candidate cruft below.
- `MyDSL.set(section, field, value)` — **zero external callers**,
  confirmed via grep across every non-test `.lua` file.
- `MyDSL.save()`/`MyDSL.load()` — genuinely widely used: `MyDSL_
  CreatureLore.lua`, `MyDSL_CombatView.lua`, `MyDSL_GroupView.lua`,
  `MyDSL_LayoutEngine.lua`, `MyDSL_TargetView.lua`, `MyDSL_
  PromptView.lua`, `MyDSL_WindowRegistry.lua`, `MyDSL_ThemeEngine.lua`,
  `MyDSL_DataLayer_PromptVitals.lua` all call one or both — but each of
  these is almost certainly calling `MyDSL.save()`/`table.load()` as a
  **generic Mudlet stdlib pattern for their own separate save files**,
  not this file's specific `MyDSL.save()`/`MyDSL.load()` (which is
  hardcoded to `MyDSL_state.lua` and a fixed list of 16 State sections)
  — worth Steven confirming which of these 9 callers actually mean
  *this* `MyDSL.save()` vs. their own same-named local pattern; not
  disambiguated in this pass (see Candidate cruft).
- `MyDSL.State.*` — the real, dominant access pattern: **12 modules**
  read `MyDSL.State.*` fields directly (`MyDSL_CombatView`, `MyDSL_
  DataBridge`, `MyDSL_CharacterAssist`, `MyDSL_AutoWhere`, `MyDSL_
  GroupView`, `MyDSL_MoonWeather`, `MyDSL_CreatureReference`, `MyDSL_
  ItemReference`, `MyDSL_ScanView`, `MyDSL_LocationView`, `MyDSL_
  TargetView`, `MyDSL_Leveling`), bypassing the Get/Set API entirely.

**Depends on:** nothing else in this codebase — this is the root of
the dependency graph. Pure Mudlet/Lua stdlib (`tempRegexTrigger`,
`registerAnonymousEventHandler`, `table.save`/`table.load`, `gmcp`).

**Called by:** every other `MyDSL_*.lua` file, directly or indirectly
(all 5 split files depend on it loading first; `MyDSL_DataBridge.lua`
translates its `State` into `DB`; every View module reads from either
`State` or `DB`).

**Candidate cruft:**
- **The documented Get/Set API (Section 6) is barely used.** Its own
  header comment says "All external modules use these instead of
  reading State directly" — confirmed false by grep: 1 real caller of
  `MyDSL.get()`, 0 callers of `MyDSL.set()`, vs. 12 modules reading
  `MyDSL.State.*` directly. Either the encapsulation intent was
  abandoned in practice (worth Steven deciding whether to enforce it
  going forward, or delete the API and update the header comment to
  match reality) or this is exactly the kind of "connections not in
  the same namespace" drift the audit is looking for.
- **9 modules call something named `MyDSL.save()`/`table.load()`** but
  almost certainly aren't all calling *this* file's `MyDSL.save()`
  (hardcoded to 16 specific State sections + `MyDSL_state.lua`) — most
  are likely their own per-module save/load using the same naming
  convention. Not confirmed either way this pass; flagging so pass 2
  disambiguates rather than assuming either way.
- `MyDSL.on()` has exactly one real consumer (`MyDSL_Leveling.lua`).
  Not dead, but narrow enough to ask whether it's worth keeping as a
  parallel mechanism to the `registerAnonymousEventHandler` pattern
  every other module uses.

**Performance flags:**
- **Confirmed real double-fire on every combat round** (see `MyDSL_
  DataBridge.lua`'s own section below for the full grep trail): this
  file's `char_data`/`room_data`/`tick` GMCP handlers call `update()` →
  `MyDSL.emit()` → `raiseEvent("MyDSL.<section>.updated")` — and
  `MyDSL_DataBridge.lua` listens to BOTH that re-raised event AND the
  raw `gmcp.char_data`/`gmcp.room_data`/`gmcp.tick` event directly,
  causing `MyDSL.DB.sync()` (a real, non-trivial table rebuild) to run
  **twice per packet** during the hottest path in the whole addon
  (every combat round). This is a DataBridge-side fix, not a
  DataLayer-side one, but the root cause is DataLayer re-raising an
  event for something that already has a raw GMCP equivalent other
  modules can (and do, inconsistently) listen to directly.
- Persistence (Section 8) is already well-optimized — debounced
  disk-write (a 2026-07-19 PVP-perf fix, table.save() coalesced to
  ~1 per 1.5s burst instead of once per affect change), immediate
  flush on disconnect/exit. Nothing to flag here.
- Section 7's GMCP handlers themselves are all cheap (field
  reassignment, no loops over large structures) — not a hot-path
  concern on their own.

---

## 2. `MyDSL_DataLayer_CreatureLore.lua`

**210 lines.** First slice of the DataLayer split (2026-08-25), chosen
because it had zero cross-domain dependencies.

**What it does:** captures `creaturelore <keyword>` output —
`MyDSL.beginCreatureLore()` resets state and installs a body catch-all,
`MyDSL.parseCreatureLoreLine()` parses each line (name, alignment, sex,
size, race, etc.), `MyDSL.endCreatureLore()` commits the parsed record
and emits.

**Public surface:** `MyDSL.beginCreatureLore()`, `MyDSL.
parseCreatureLoreLine()`, `MyDSL.endCreatureLore()`. Confirmed via grep:
**zero external callers** — this domain is entirely self-contained,
triggered only by its own `loreStart` trigger registration in this same
file. `test/test_datalayer_creaturelore_capture.lua` is the only
consumer outside the trigger.

**Depends on:** `MyDSL_DataLayer.lua` (State/`_triggers`/`emit`/`trim`
via its own local copy).

**Called by:** nothing external — see Public surface.

**Candidate cruft:** none found. Small, focused, single-purpose file
with real test coverage (20 assertions against a real corpus fixture).

**Performance flags:** none — trigger only fires on an explicit player
command (`creaturelore <x>`), not a hot path.

---

## 3. `MyDSL_DataLayer_Combat.lua`

**924 lines.** Second (and largest single) slice of the DataLayer
split — the true hot path of this whole addon, since DSL emits combat
lines continuously with no header/footer to gate capture.

**What it does:** the full combat-capture pipeline ported from PNP's
`DSL_PNP_Battle.lua`: damage-line parsing + severity ladder (`DAM_
INFO`, `calcDamVerb()`, `battleFormat()`), avoidance (dodge/parry/
block/sense), condition tracking (`getTargetCondition()` — the real
public API for "what state is my target in"), death/flee/rescue
end-of-fight handling with history snapshots, weapon-flag procs
(Frost/Flaming/Shocking/Vampiric/Stunning/etc. + a Poison sequence with
no PNP equivalent), and the `combatRoundFlush` handler (fires on every
`MyDSL.char.updated`, i.e. every combat round) that aggregates the
round's `round_data` into one summary line per (attacker,target) pair.

**Public surface:** `MyDSL.parseCombatDamageLine()`, `parseCombat
AvoidLine()`, `parseCombatConditionLine()`, `parseCombatDeathLine()`,
`parseCombatEndLine()`, `parseCombatProcLine()`, `MyDSL.
getTargetCondition(name)`. Confirmed via grep: `getTargetCondition()`
has **zero current external callers** — built as "the REAL enemy
health message data Steven asked for" per its own header comment, but
nothing in any View module actually calls it yet (worth flagging for
Steven — was this ever wired into TargetView/Focus, or is it a real
built-but-unconnected gap?). The 6 `parseCombat*` functions are called
only from this file's own trigger registrations (by design — see
`MyDSL_DataLayer_CreatureLore.lua`'s precedent) plus `test/
test_combat_damage_regex.lua` and `test/
test_datalayer_combat_lifecycle.lua`.

**Depends on:** `MyDSL_DataLayer.lua` (`State.combat`'s default shape
is declared there, not here; `_triggers`, `_handlers`, `emit`). Also
soft-depends on `MyDSL.CombatView` (checked defensively — `if MyDSL.
CombatView and MyDSL.CombatView.config then ...` — never a hard
`dofile` dependency, so this file works even if `MyDSL_CombatView.lua`
isn't loaded, just with default gag/show behavior).

**Called by:** `MyDSL_CombatView.lua` reads `MyDSL.State.combat` for
its own window rendering. `MyDSL_TargetView.lua`/Focus **do not**
currently call `MyDSL.getTargetCondition()` (confirmed via grep) —
flagging this as the same class of "built but not wired in" gap as the
already-tracked `MyDSL.Windows.setTitle` case resolved earlier this
project.

**Candidate cruft:**
- `MyDSL.getTargetCondition()` — built, documented as solving a real
  Steven ask, zero real consumers. Either wire it into TargetView/Focus
  or confirm it's intentionally staged for a future feature.

**Performance flags:**
- **This is the single hottest file in the entire addon** — every
  combat line (potentially dozens per second in a multi-mob fight)
  runs through one of these triggers. None of the individual parse
  functions do anything asymptotically expensive (no nested loops over
  unbounded collections), but the aggregate trigger count is real: 24
  separate `tempRegexTrigger`/`registerAnonymousEventHandler`
  registrations, all always-active (no begin/end gate, unlike every
  other DataLayer domain) — every one of them evaluates its regex
  against every incoming line whether or not combat is happening.
  Mudlet's own trigger engine short-circuits on non-match cheaply, so
  this is unlikely to be the dominant cost, but it's the largest
  concentration of always-on regex evaluation in the codebase and
  worth keeping in mind if a future profiling pass finds real
  per-line overhead.
- `combatRoundFlush` (the round-summary handler) is O(active pairs)
  per round, not O(n²) or worse — bounded by how many simultaneous
  fights are active, which in practice is small. Not a concern.
- `active`/`history` tables persist across rounds with a `history_max
  = 5` cap already in place (`snapshotFight()` trims via `table.
  remove` in a `while` loop) — bounded growth, no leak.

---

## 4. `MyDSL_DataLayer_ScanLook.lua`

**1,005 lines.** Third slice of the DataLayer split — room-content
perception: scan, look/room-content listing, ground-item sighting,
"Players near you:" capture.

**What it does:** `MyDSL.beginScan()`/`parseScanLine()`/`endScan()`
(mob-in-room capture via `scan`/`peer`), `MyDSL.beginLook()`/
`parseLookHereLine()`/`endLook()` (room-content capture via `look`,
including the long-running `isLookFixtureLine()` allowlist that's been
patched 9 times historically for new furniture/scenery shapes — see
`docs/TODO.md`'s "NEEDS LIVE CONFIRMATION" section), `MyDSL.
captureGroundItem()`/`MyDSL.buildItemStatsSuffix()`/`applyGroundItem
Hover()` (ground-item sighting + hover text), `MyDSL.beginPlayersNear()`/
`endPlayersNear()` ("Players near you:" roster). Also hosts the
promoted cross-domain helpers `MyDSL.normalizeForMatch()`/`MyDSL.
bestFuzzyMatch()` — wait, those actually live in `MyDSL_DataLayer.lua`
Section 2 (promoted there during this slice's own extraction) — this
file just *calls* them.

**Public surface:** `MyDSL.beginScan/parseScanLine/endScan`, `MyDSL.
beginLook/parseLookHereLine/endLook`, `MyDSL.captureGroundItem`, `MyDSL.
buildItemStatsSuffix` (real cross-file dependency — see below),
`MyDSL.applyGroundItemHover`, `MyDSL.beginPlayersNear/endPlayersNear`,
`MyDSL.resolveGroundItem` — wait, that one's actually in `MyDSL_
DataLayer_ItemLore.lua` (this file *calls* it, doesn't define it).
Confirmed via grep, the one real forward dependency: **`MyDSL.
buildItemStatsSuffix()`, defined here, is called from `MyDSL_DataLayer_
ItemLore.lua`'s** equip/inventory/container hover-hint lines — a
documented, intentional cross-split dependency (see that file's own
header). Every other function here has zero external callers beyond
this file's own trigger registrations and `test/
test_datalayer_playersnear_parse.lua`, `test/
test_datalayer_audit_fixture_lines.lua`, `test/
test_datalayer_several_fixture_line.lua`, `test/
test_others_equipment_hover.lua`.

**Depends on:** `MyDSL_DataLayer.lua` (`State`/`_triggers`/`emit`/
`MyDSL.normalizeForMatch`/`MyDSL.bestFuzzyMatch`, the last two promoted
to core specifically because this file and `MyDSL_DataLayer_ItemLore.
lua` both need them).

**Called by:** `MyDSL_DataLayer_ItemLore.lua` (`buildItemStatsSuffix`,
reverse direction — see that file's section). `MyDSL_ScanView.lua`
reads `MyDSL.State.scan` for rendering (confirmed via grep). `MyDSL_
RouteHelper.lua` reads `MyDSL.State.scan`/`players` too.

**Candidate cruft:** none found this pass — every function here has a
real, traceable caller (either a trigger registration or a genuine
cross-file dependency).

**Performance flags:**
- `isLookFixtureLine()`/`resolveMobName()` do a **linear scan over a
  string-literal allowlist** (9+ entries and growing) on every room-
  content line during `look`. Cheap in absolute terms (string `find`
  calls, not regex), and `look` isn't a hot path the way combat is,
  but this list has grown by one-off patches 9 times historically per
  `docs/TODO.md` — worth a design conversation (already flagged there,
  not re-litigated here) since it's the closest thing in this file to
  an unbounded-growth pattern.
- `bestFuzzyMatch()` is O(n) over the candidate list per call (ground
  items / scanned mobs in the current room) — bounded by room
  population, not a real concern at typical DSL room sizes.

---

## 5. `MyDSL_DataLayer_ItemLore.lua`

**807 lines.** Fourth slice of the DataLayer split — everything
item-shaped: identify/lore capture, your own equipment, others'
equipment, inventory, container contents.

**What it does:** `MyDSL.beginIdentify()`/`endIdentify()` (`c identify`
capture, with source-scoping to distinguish a real self-cast from an
observed shop/note-quoted block — see `test/
test_identify_source_scoping.lua`), `MyDSL.beginLoreItem()`/
`endLoreItem()` (`lore <item>`), `MyDSL.beginEquip()`/`parseEquipLine()`/
`endEquip()` ("You are using:"), `MyDSL.beginOthersEquip()`/
`parseOthersEquipLine()` ("<Name> is using:"), `MyDSL.beginInventory()`/
`parseInventoryLine()`/`endInventory()` ("You are carrying:"), `MyDSL.
beginContainerHolds()`/`parseContainerHoldsLine()`/`endContainerHolds()`
(exam/look in/search a container), plus `MyDSL.resolveGroundItem()`/
`MyDSL.setGroundItemOverride()` (best-effort ground-text-to-inventory-
key mapping, with a manual override escape hatch).

**Public surface:** every `begin*`/`parse*`/`end*` pair above, plus
`MyDSL.resolveGroundItem()` and `MyDSL.setGroundItemOverride()`.
Confirmed via grep: `MyDSL.setGroundItemOverride()` is called from
`MyDSL_ItemReference.lua` (a real, live Layer-3/4 cross-reference — the
"manual map correction" feature). `MyDSL.resolveGroundItem()` is called
from `MyDSL_DataLayer_ScanLook.lua`'s `applyGroundItemHover()` — the
reverse of that file's `buildItemStatsSuffix()` dependency, both
documented in each file's own header. Every `begin*/parse*/end*`
function's only external callers are this file's own trigger
registrations plus `test/test_identify_source_scoping.lua`, `test/
test_others_equipment_hover.lua`.

**Depends on:** `MyDSL_DataLayer.lua` (`State`/`_triggers`/`emit`/
`MyDSL.bestFuzzyMatch`), `MyDSL_DataLayer_ScanLook.lua`
(`MyDSL.buildItemStatsSuffix()` — real, confirmed forward dependency).

**Called by:** `MyDSL_DataLayer_ScanLook.lua` (`resolveGroundItem`),
`MyDSL_ItemReference.lua` (`setGroundItemOverride`, plus reads `MyDSL.
State.equipment`/`inventory`/etc. for its own rendering — confirmed via
grep), `MyDSL_ItemLore.lua` (the Layer-4 reference module reads the
captured records this file produces).

**Candidate cruft:** none found — cleanest slice of the whole split per
its own commit message (zero new cross-domain promotions needed), and
that held up under this audit's fresh grep pass too.

**Performance flags:** none of these triggers are hot-path — every one
fires only on an explicit player command (`identify`, `lore`,
`equipment`, `i`/`inv`, `exam`/`look in`/`search`), not on every
incoming line. No concerns.

---

## 6. `MyDSL_DataLayer_PromptVitals.lua`

**1,029 lines**, the largest single extraction of the whole split.
Fifth and final slice — score, flags, lunar, time, weather, who, group,
improve, plus the real-time Pos'n/Wimpy/Dragon-Vitality text triggers
that don't fit the begin/end-block shape every other domain uses.

**What it does:** `MyDSL.beginScore()`/`parseScoreLine()`/`endScore()`
(the biggest single parse function in the codebase — the `score`
command's many fields), `beginFlags`/`parseFlagsLine`/`endFlags` (the
toggle sub-block inside score), `beginLunar`/`parseLunarLine`/`endLunar`,
`parseTimeLine`/`parsePromptLine` (day/night period, fires on **every
prompt line 2** — far more frequent than any other trigger in this
file), `extractWindClause`/`parseWeatherLine` (including the rare
lowercase-"and" wind-clause split case), `beginWho`/`parseWhoLine`/
`endWho`, `beginGroup`/`parseGroupLine`/`endGroup`, `parseImproveLine`/
`parseImproveStatusLine`. Real-time single-line triggers (not
functions with a dedicated name, just inline trigger bodies): Pos'n
(stand/sit/rest/sleep/mount/dismount/land), Wimpy, Dragon Vitality
(`stat` output, dragon-only via a `Vit:` field that simply never
appears for anyone else).

**Public surface:** every `begin*/parse*/end*` triple above. Confirmed
via grep: **zero real external callers of any of them** — every
mention outside this file (`MyDSL_DataBridge.lua`, `MyDSL_LiveView.lua`,
`MyDSL_MoonWeather.lua`, `MyDSL_GroupView.lua`) is a comment, not a real
call; those modules all read from `MyDSL.State`/`MyDSL.DB` populated
via the event bus instead of calling these parse functions directly.
This is the expected, correct pattern (matches every other DataLayer
domain) — not cruft.

**Depends on:** `MyDSL_DataLayer.lua` (`State`/`_triggers`/`emit`/
`MyDSL.save` for the flags/lunar toggle-persistence calls, `MyDSL.
GroupView` — a soft, defensively-checked read of `MyDSL.GroupView.
config.gagGroup`, not a hard dependency).

**Called by:** nothing directly (see Public surface) — but `MyDSL.
State.score`/`who`/`group`/`lunar`/`time`/`weather`/`improve` (the data
this file produces) are read by `MyDSL_DataBridge.lua` (→ `MyDSL.DB.*`
for DSL1-era modules), `MyDSL_LiveView.lua`, `MyDSL_GroupView.lua`,
`MyDSL_MoonWeather.lua`, `MyDSL_Help.lua` (help text references).

**Candidate cruft:** none found — every function traces to a real
trigger, even though nothing calls the functions by name from outside.

**Performance flags:**
- **`parsePromptLine()` fires on every single prompt line 2** — this
  is the single most frequent trigger firing in the entire DataLayer
  split (more often than any combat trigger, since it fires on every
  server round/prompt regardless of whether combat is happening). The
  function itself is cheap (one pattern match, one `update()` call),
  so not flagged as a proven lag source, but it's the highest-frequency
  single trigger in the codebase and worth being the first place to
  add real instrumentation if a future profiling pass needs one.
- Zero test coverage for this entire domain (confirmed via grep, noted
  already in `docs/TODO.md` as a known, not-yet-closed gap from the
  split itself — not a performance issue, but worth linking here since
  it means a regression in the highest-frequency trigger in the addon
  would currently go undetected by the test suite).

---

## 7. `MyDSL_RawCapture.lua`

**110 lines.** Diagnostic-only module, off by default.

**What it does:** an opt-in raw-text logger (`mydsl rawlog on|off`)
that writes every incoming line, stripped of color tags, to a
per-character dated log file — originally built to check whether PNP's
Highlighter was rewriting lines before they reached MyDSL's own
triggers. Its own header comment documents that this specific concern
was checked and confirmed not to apply to DSL2 (zero Highlighter
references anywhere in the active codebase; the bracket-decoration
formats that motivated it are >99% confined to pre-DSL2 log files).
Kept anyway as "cheap insurance" against a future line-mutating script.

**Public surface:** `MyDSL._rawCaptureRegister()`/`MyDSL.
_rawCaptureUnregister()` — exposed on the `MyDSL` table specifically so
the `mydsl rawlog` alias's script string (a separate Lua chunk with no
closure access to this file's locals) can reach them. Confirmed via
grep: no other file references these.

**Depends on:** nothing — deliberately self-contained, uses its own
private alias table instead of `MyDSL._aliases` specifically because
this file is meant to load *before* `MyDSL_DataLayer.lua` (per its own
header comment) so that shared table might not exist yet.

**Called by:** nothing external — purely a standalone toggle feature.

**Candidate cruft:** the module's own justification for existing
("cheap insurance... will show up as a discrepancy... the next time
this is turned on and compared") describes a manual, human-driven check
that's never actually been run as a real workflow step anywhere in this
project's documented process (`CLAUDE.md`'s housekeeping routine
doesn't mention it). Not dead code — it's real, working, off-by-default
— but worth Steven confirming whether this diagnostic is still wanted
at all, since the concern it was built for has been confirmed twice
now not to apply to DSL2.

**Performance flags:** **already fixed, real prior perf issue, kept as
a documented lesson** — the file's own header explains that this
trigger used to be registered unconditionally at load and stay alive
for the whole session even while disabled, meaning every single line
of the entire profile paid for a trigger-match + Lua call just to hit
its own "not enabled, return" check. Fixed 2026-07-19 (PVP perf audit)
by registering/deregistering the trigger alongside the toggle itself —
confirmed correct in the current source (`registerCaptureTrigger()`/
`unregisterCaptureTrigger()`, only called from the alias). Zero cost
while off, which is the default. Nothing further to flag.

---

## 8. `MyDSL_TickSource.lua`

**287 lines.** Shared tick-timing authority, ported from PNP's
`DSL_PNP_Ticktimer.lua`.

**What it does:** listens for `gmcp.tick`/`gmcp.Tick`/`onTick` (all
three registered defensively — real DSL only ever fires one of these,
but which one isn't hardcoded), maintains a smoothed rolling average
tick length (90% old average / 10% newly-measured, PNP's exact
smoothing formula), publishes `MyDSL.DB.tick` on every update, and
raises `MyDSL.Tick.Pulse` (true game ticks) / `MyDSL.Tick.Updated`
(any recompute, including the timer-driven countdown) / `MyDSL.
Tick.Warning` (crosses the configured warn threshold) / `MyDSL.
Timers.Pulse`/`Updated`/`Slow` (a throttled-to-1Hz heartbat other
modules can share instead of each running their own timer chain).

**Public surface:** `MyDSL.TickSource.status()/reset()/setAverage()/
setWindow()/setDebug()` (all wired to `mydsl tick <verb>` aliases),
`MyDSL.TickSource.onGameTick()/publish()/updateTimer()/loop()/boot()`
(internal lifecycle, called from within this file only). Confirmed via
grep: no other file calls into `MyDSL.TickSource.*` directly — every
consumer reads `MyDSL.DB.tick` (populated here) or listens for the
raised events instead. This is the correct, intended pattern.

**Depends on:** nothing structurally (no `MyDSL.State` reads) — reads
raw `gmcp.tick` directly and writes straight to `MyDSL.DB.tick`,
bypassing `MyDSL_DataLayer.lua`'s `State`/`emit` pipeline entirely (see
Candidate cruft/Performance flags — this is also why `MyDSL_
DataBridge.lua`'s own header explicitly says "MyDSL.DB.tick is NOT
rebuilt here... TickSource is the sole authority").

**Called by:** `MyDSL_TickView.lua` (the display module — reads `MyDSL.
DB.tick`), `MyDSL_LiveView.lua`/`MyDSL_MoonWeather.lua`/`MyDSL_
AffectsView.lua` listen for `MyDSL.Timers.Slow`/`Pulse` (confirmed via
grep) instead of running their own timer chains — exactly the
consolidation this file's own header comment describes.

**Candidate cruft:** none found — this file is a clean, self-contained,
deliberately-designed shared utility with real, correctly-wired
consumers.

**Performance flags:**
- **`T.loop()` self-reschedules via `tempTimer` every `0.25s` (4Hz),
  unconditionally, for the entire session, regardless of whether
  anything currently cares about sub-second tick precision.** This is
  a real, always-on 4Hz timer — the file's own comment justifies it as
  needed for "TickView's own progress-bar animation stays smooth," but
  that only matters while TickView is actually visible. Confirmed via
  grep: `T.loop()`/`T.updateTimer()` have no visibility gate — they run
  at full 4Hz whether or not `MyDSL_TickView`'s window is shown, hidden,
  or even loaded at all. This is the closest thing to a genuine
  "unconditional background cost" in the foundation-layer files audited
  so far (smaller than the DataBridge double-fire, but real and
  continuous rather than event-triggered) — worth asking Steven whether
  it's worth gating the 4Hz loop behind TickView's own visibility state
  and falling back to the already-existing 1Hz `MyDSL.Timers.Slow`
  cadence when hidden.
- The `MyDSL.Timers.Slow` throttle-to-1Hz mechanism itself is a
  genuinely good, already-applied performance pattern — worth noting
  as a positive example, not just flagging problems.

---

## 9. `MyDSL_DataBridge.lua`

**268 lines.** Layer-3 translation: copies `MyDSL.State.*` (DSL2-native)
into `MyDSL.DB.*` (the shape DSL1-era display modules — `LiveView`,
`TickView` — expect). Must load after `MyDSL_DataLayer.lua`.

**What it does:** `MyDSL.DB.sync()` rebuilds `MyDSL.DB.live/score/room/
timers/xp/time/affects/improve` from the current `MyDSL.State.*`
sections on every relevant event. Documents 3 real historical bugs
fixed in its own comments (hp/mana/move fallback fields silently never
forwarded; `MyDSL.DB.room` unconditionally wiping LiveView's own
colored-exits cache fields on every sync; `MyDSL.DB.tick` used to be
clobbered here on every sync, discarding TickSource's just-computed
smoothed average — now correctly just aliased instead of rebuilt).

**Public surface:** `MyDSL.DB.sync()`. Confirmed via grep: no external
module calls `sync()` directly — it's purely event-driven (11 separate
`registerAnonymousEventHandler` registrations, all calling the same
`onAny()` → `pcall(MyDSL.DB.sync)`).

**Depends on:** `MyDSL_DataLayer.lua` (`MyDSL.State.*`, and 8 of its 11
event registrations listen for events *raised by* DataLayer's own
`MyDSL.emit()` — see Performance flags for why this is a problem, not
just a dependency).

**Called by:** nothing calls `sync()` directly; `MyDSL.DB.*` (its
output) is read by `MyDSL_LiveView.lua`, `MyDSL_TickView.lua` (and
transitively `MyDSL_TickSource.lua` writes `MyDSL.DB.tick` directly,
bypassing this file for that one field, correctly per this file's own
comment).

**Candidate cruft:** none — every field mapping traces to a real
consumer, and the file's own comment history shows real bugs being
found and fixed here, not speculative code.

**Performance flags — this is the real, confirmed lag-spike candidate
Steven asked this audit to find:**
- **`MyDSL.DB.sync()` runs TWICE per incoming `gmcp.char_data` packet,
  and twice per `gmcp.room_data` packet, during the hottest path in
  the whole addon (every combat round fires `gmcp.char_data`).**
  Confirmed via grep, not assumed: this file registers `onAny()` on
  BOTH the raw GMCP event (`MyDSL._handlers.gchar = 
  registerAnonymousEventHandler("gmcp.char_data", onAny)`, line 258)
  AND the DataLayer-re-raised event for the exact same underlying data
  (`MyDSL._handlers.char = registerAnonymousEventHandler("MyDSL.char.
  updated", onAny)`, line 250) — and `MyDSL_DataLayer.lua`'s own
  `char_data` GMCP handler (Section 7) calls `update("char", {...})`,
  which calls `MyDSL.emit("char")`, which is exactly what raises
  `"MyDSL.char.updated"` in direct response to that same raw
  `gmcp.char_data` packet. Same pattern for `room_data`/`"MyDSL.room.
  updated"` (lines 251/259) and `tick`/`"MyDSL.tick.updated"` (lines
  253/260). `MyDSL.DB.sync()` itself is not free — it rebuilds ~8
  sub-tables (`live`, `score` with ~35 individual field assignments,
  `room`, `timers`, `xp`, `time` with string pattern-matching against
  `gmcp.tick.time`, `affects`, `improve`) from scratch on every call.
  During a fight, this means a genuinely non-trivial table-rebuild
  runs twice per round instead of once, compounding with `MyDSL_
  DataLayer_Combat.lua`'s own `combatRoundFlush` handler (also
  triggered on `"MyDSL.char.updated"`) firing in the same event storm.
  **This is a concrete, fixable, real-money performance bug** — the
  fix (not made this pass, inventory only) would be picking exactly
  one of {raw GMCP event, re-raised MyDSL event} per section and
  dropping the other registration, or having `MyDSL.emit()` itself
  suppress a re-raise when nothing besides DataBridge would care about
  both forms.
- No other performance concerns found in this file — the sync logic
  itself, while non-trivial, is a single flat pass with no nested
  loops or unbounded collections.

---

## 10. `DSL_Generic_Mapper.xml` (embedded Lua — the `map.dsl.*` fork layer)

**6,631-line native XML package.** Lines 1-5666 are the stock
third-party "Generic Mapper 2.1.8" base package (reused per this
project's own "reuse, don't reinvent" philosophy — not our code, not
audited line-by-line here). **Lines 5667-6623 (~957 lines) are the
real subject of this audit**: `map.dsl.*`, this project's own
"Minimal Hardening Layer" fork, currently v0.2.6. Three native Trigger
objects elsewhere in the file (not inside the `map.dsl` script block
itself) also call into it: "English Exits Trigger" (calls `map.dsl.
beforeExits()` on every `[Exits: ...]` line — once per room, a real
hot path), "DSL Door State Capture" (`map.dsl.onDoorLine()`), "DSL
Terrain Capture" (`map.dsl.onTerrainLine()`).

**What it does:** passive GMCP-assisted metadata layered on top of the
stock room-mapping engine, which remains untouched. Room terrain/color
(`normalizeSector()`/`applySectorColor()`/`setManualTerrain()`, 14
sector categories including the 2026-07-18 "air" gap fix), room weight
from REAL observed movement-point cost rather than a guessed table
(`captureMovePoints()`/`applyMoveCost()`, averaged across repeat
visits), door-state tracking via a command/reply FIFO queue
(`captureCommand()`/`onDoorLine()`/`setGenericDoor()` — converted from
single overwritable slots to real queues 2026-07-19 to fix a genuine
reply-misattribution bug), area-change announcements
(`announceAreaChange()`), "Players near you:" room highlighting
(`highlightPlayersNear()`, fed by `MyDSL_DataLayer_ScanLook.lua`'s own
`MyDSL.playersNear.parsed` event — a real, confirmed cross-repo/
cross-package dependency), a corruption guard (`roomLooksStale()` —
compares GMCP's room name against the candidate room's stored name to
catch `map.currentRoom` desync), and diagnostic commands (`map.dsl.
status()`/`showGMCP()`/`roomRaw()`).

**Public surface:** none of this is called from `MyDSL_*.lua` in the
DSL2 package **except** the `MyDSL.playersNear.parsed` event consumed
by `highlightPlayersNear()` — confirmed via grep, this is the only
real integration point between the two packages. Everything else is
self-contained: native aliases (`rt`/`room terrain`, `rw`/room weight,
`dslroom raw`, etc. — not enumerated line-by-line here, see the stock
package's own alias list for the base commands this fork adds
DSL-specific ones alongside) and the 9 `registerAnonymousEventHandler`
registrations in `map.dsl.registeredEvents` plus the 3 Trigger objects
above.

**Depends on:** raw `gmcp.char_data`/`gmcp.room_data` directly — this
is the file's own, **completely independent** GMCP parser, not a
consumer of `MyDSL_DataLayer.lua`'s parsed `State.char`/`State.room`.
Confirmed intentional and already documented (`docs/TODO.md`'s
"Mapper vs. DataLayer" entry, 2026-08-23 audit): the mapper fork is
designed to survive standalone even without `MyDSL_DataLayer.lua`
loaded at all, which is exactly why it re-parses GMCP instead of
reading `MyDSL.State`.

**Called by:** `MyDSL_DataLayer_ScanLook.lua` → `MyDSL.playersNear.
parsed` → `highlightPlayersNear()` (one-directional; nothing in the
mapper raises anything MyDSL listens for).

**Candidate cruft:**
- `map.dsl.updateDisabled()` — a one-line stub that echoes "Updater is
  disabled in the DSL fork" and returns false. Real, deliberate
  (per this project's standing rule to kill self-updater mechanisms
  when porting third-party packages), not dead code, but worth
  confirming it's actually wired to whatever stock update-check path
  would otherwise fire, since a stub that's never called would be
  silent, not disabling.
- `map.dsl.showGMCP()`/`map.dsl.status()`/`map.dsl.roomRaw()` are
  diagnostic-only, no other code depends on them — fine as-is, listed
  here only because "candidate cruft" should note diagnostics
  explicitly rather than silently pass over them.

**Performance flags:**
- **Confirmed duplicate GMCP parsing, already on record in `docs/
  TODO.md` (2026-08-23 audit) — restated here with the performance
  framing this audit specifically asked for.** `map.dsl.onCharData()`/
  `onRoomData()` and `MyDSL_DataLayer.lua`'s own `char_data`/
  `room_data` GMCP handlers are two fully independent parsers of the
  exact same incoming packets, each doing its own `table.deepcopy()`
  (mapper) or field-by-field `update()` (DataLayer) on every single
  packet — during combat, that's two independent full-payload
  deep-copies of `gmcp.char_data` per round, not one. Already a known,
  reasoned tradeoff (mapper must survive standalone) rather than an
  oversight, but it is a real, measurable doubled-parsing cost on the
  hottest GMCP path in the whole addon, worth having on record
  alongside `MyDSL_DataBridge.lua`'s double-sync finding since they
  compound during the same combat rounds.
- **`map.dsl.captureLine()` (registered on `onNewLine` — literally
  every incoming line, the single highest-frequency hook available in
  Mudlet) already had a real O(n) shift-per-line bug found and fixed**
  2026-07-19 (PVP perf audit) — batch-trim to a high-water mark instead
  of `table.remove(buf,1)` on every call once the buffer filled.
  Confirmed current in this source; nothing further to flag here, but
  worth highlighting as the single most-executed piece of code in
  either package (runs on every line of everything — combat, chat,
  room text, everything) and the fact it's already been profiled once
  is a good sign, not a gap.
- **`map.dsl.applyMoveCost()`/`applyRoomMetadata()` already carry 3
  separate documented 2026-07-19 perf fixes**: `dsl_setIfChanged()`
  skips a `setRoomUserData()` write when the value hasn't changed
  (each such call takes Mudlet's shared map lock — real, measured
  contention risk during repeat-visit combat/PVP scenarios);
  `applyRoomMetadata()` calls `applyMoveCost()`/`announceAreaChange()`
  inline instead of via a deferred `tempTimer(0,...)` (removed one
  Qt event-loop round-trip of latency per move, after tracing the
  actual dispatch order rather than assuming the defer was needed);
  the `weightSource ~= "auto"` check skips a redundant `setRoomUserData`
  write on every move through an already-weighted room. All three
  read as genuinely well-targeted, already-applied fixes from a real
  prior audit pass — nothing further found this pass.
- No new performance issues found beyond the already-documented
  duplicate-parsing tradeoff above — this file has clearly already
  been through at least one real, careful performance pass (2026-07-19),
  and it shows.

---

*(Sections 11-40 not yet written — in progress.)*
