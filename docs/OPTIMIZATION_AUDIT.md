# MyDSL Optimization Audit

Formalizes the project-wide audit/optimization phase opened in
`docs/TODO.md`'s TOP PRIORITY section on 2026-08-23, per Steven ("moving
into the optimization phase soon for UI... check for lag spikes... do a
really really thorough deep scan of the current state of the project...
cross check connections of modules... make sure its all in the same
namespace... review it like its a new project").

**Pass 1 (complete, 2026-08-25): inventory only — no code changes.**
All 40 sections written — every `MyDSL_*.lua` file plus
`DSL_Generic_Mapper.xml`'s embedded Lua, each covering what it does,
its public surface, what it depends on, what calls it, candidate
cruft, and concrete performance flags. Every claim in "Public surface"
/ "Depends on" / "Called by" is grep-confirmed against the actual
repo, not assumed from memory or the file's own comments — a comment
claiming a function is used doesn't count as confirmation on its own
(this mattered in practice: section 3 originally got a "zero callers"
claim wrong and had to correct itself once a later section re-checked
it with a fresh grep — see the Cross-cutting findings section at the
bottom for the full list of what this pass turned up, including the
real double-fired-work performance bugs Steven specifically asked this
audit to find).

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
- `MyDSL_state.lua` — `MyDSL_DataLayer.lua`'s own `MyDSL.save()` output
  (see section 1). Kept as numbered **section 24** rather than moved up
  here, since removing it from the sequence would force renumbering
  every cross-reference in sections 25-40 (which cite each other by
  number extensively) — section 24 itself is written as a short
  data-file note, not a full inventory, so it reads consistently with
  this list even while keeping its place in the sequence.

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
11. ✅ `MyDSL_PromptSetup.lua`
12. ✅ `MyDSL_AutoWhere.lua`
13. ✅ `MyDSL_PromptView.lua`
14. ✅ `MyDSL_MovementSounds.lua`
15. ✅ `MyDSL_CreatureLore.lua`
16. ✅ `MyDSL_Roller.lua`
17. ✅ `MyDSL_ChatTriggers.lua`
18. ✅ `MyDSL_ItemLore.lua`
19. ✅ `MyDSL_ItemReference.lua`
20. ✅ `MyDSL_RouteHelper.lua`
21. ✅ `MyDSL_CreatureReference.lua`
22. ✅ `MyDSL_ScanView.lua`
23. ✅ `MyDSL_CombatView.lua`
24. ✅ `MyDSL_state.lua`
25. ✅ `MyDSL_GroupView.lua`
26. ✅ `MyDSL_TickView.lua`
27. ✅ `MyDSL_CharacterAssist.lua`
28. ✅ `MyDSL_LayoutEngine.lua`
29. ✅ `MyDSL_Help.lua`
30. ✅ `MyDSL_ThemeEngine.lua`
31. ✅ `MyDSL_AlterformView.lua`
32. ✅ `MyDSL_WindowRegistry.lua`
33. ✅ `MyDSL_PortraitView.lua`
34. ✅ `MyDSL_Leveling.lua`
35. ✅ `MyDSL_MoonWeather.lua`
36. ✅ `MyDSL_AffectsView.lua`
37. ✅ `MyDSL_LocationView.lua`
38. ✅ `MyDSL_LiveView.lua`
39. ✅ `MyDSL_TargetView.lua`
40. ✅ `MyDSL_Chat.lua`

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
getTargetCondition(name)`. **Correction (this doc originally claimed
zero external callers here — wrong, caught and fixed during section
39's audit pass with a fresh grep):** `MyDSL_TargetView.lua` genuinely
calls `MyDSL.getTargetCondition(t.name)` at two real, functioning call
sites — the nameplate's live condition-percent badge (e.g. `[50-74%]`
next to the target name) and `MyDSL.Target.status()`'s diagnostic dump.
This is a real, live, working connection, not a built-but-unwired gap
— see section 39 for the full detail. The 6 `parseCombat*` functions
are called only from this file's own trigger registrations (by design
— see `MyDSL_DataLayer_CreatureLore.lua`'s precedent) plus `test/
test_combat_damage_regex.lua` and `test/
test_datalayer_combat_lifecycle.lua`.

**Depends on:** `MyDSL_DataLayer.lua` (`State.combat`'s default shape
is declared there, not here; `_triggers`, `_handlers`, `emit`). Also
soft-depends on `MyDSL.CombatView` (checked defensively — `if MyDSL.
CombatView and MyDSL.CombatView.config then ...` — never a hard
`dofile` dependency, so this file works even if `MyDSL_CombatView.lua`
isn't loaded, just with default gag/show behavior).

**Called by:** `MyDSL_CombatView.lua` reads `MyDSL.State.combat` for
its own window rendering. `MyDSL_TargetView.lua` calls `MyDSL.
getTargetCondition()` (see correction above and section 39) — a real,
live, working cross-file connection.

**Candidate cruft:** none — see the correction above. This file's
public surface is fully connected; the doc's own first-pass grep on
this one function was simply wrong, not a real gap.

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
- **Refinement, added after an independent Claude Desktop review of
  this pass (2026-08-25): the char/room/tick pair above is the clearest
  example, not the full extent of the problem.** This file registers
  `onAny()` on **11 separate events total** (see Public surface above),
  not just those 3 — `MyDSL.score.updated`/`time.updated`/`affects.
  updated`/`improve.updated`/`login.updated` each independently trigger
  the exact same full `MyDSL.DB.sync()` rebuild too, and several of
  these can fire in close succession around the same real moment (a
  `score` command completing, for instance, plausibly raises `MyDSL.
  score.updated` around the same tick a `gmcp.char_data` packet also
  arrives). The real fix shouldn't just dedupe the 3 GMCP-paired
  registrations — it should coalesce all 11 into a single debounced
  `sync()` call (e.g. schedule one `sync()` on the next tick/tempTimer(0)
  regardless of how many of the 11 events fired in that same moment,
  the same debounce shape `MyDSL_DataLayer.lua`'s own `MyDSL.save()`
  already uses for an analogous problem — see section 1), not a
  narrower fix that only addresses the 3 easiest-to-spot duplicates.
- No other performance concerns found in this file — the sync logic
  itself, while non-trivial, is a single flat pass with no nested
  loops or unbounded collections.

---

## 10. `DSL_Generic_Mapper.xml` (embedded Lua — the `map.dsl.*` fork layer)

**6,631-line native XML package.** Lines 1-5666 are the stock
"Generic Mapper 2.1.8" base package. **Ownership framing updated
2026-08-25**: `docs/MYDSL_1.0_PHILOSOPHY.md`'s Principle 1 retired the
"third-party, not our code" distinction this section originally used
here — these 5,666 lines are this project's own code now, same as
everything else that runs in this profile. What hasn't changed is the
underlying fact this section is actually reporting: they haven't been
audited line-by-line as part of this pass (only the 957-line `map.dsl.*`
fork below was in scope) — that's a real, still-true statement about
audit coverage, not a claim about who owns the code. The mapper's own
DSL-specific rewrite (Principle 1, "the real remaining case") is
tracked as its own future pass in `docs/TODO.md`, not started yet.
**Lines 5667-6623 (~957 lines) are the
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

## 11. `MyDSL_PromptSetup.lua`

**72 lines.** One-click DSL prompt setup for brand-new characters.

**What it does:** detects the character-birth cutscene room ("The Gray
Mist of Nothingness") and offers a clickable link to send Steven's
chosen `prompt <format>` string, rather than auto-sending it — per this
project's "any game command a module sends must be user-initiated"
principle, confirmed via an explicit `AskUserQuestion` at build time
(2026-07-09). Also exposes a manual `mydsl setprompt` alias so the
format can be reapplied any time, not just at creation.

**Public surface:** `MyDSL.PromptSetup.apply()` — called from the
`mydsl setprompt` alias and from the birth-trigger's clickable link
(`dechoLink`). Confirmed via grep: no other `.lua` file references
`MyDSL.PromptSetup`.

**Depends on:** nothing — self-contained, no reads from `MyDSL.State`
or any other module.

**Called by:** nothing external.

**Candidate cruft:** none found — small, single-purpose, matches its
own stated scope exactly.

**Performance flags:** none — the birth trigger fires on one specific,
rare literal line ("The Gray Mist of Nothingness"), not a hot path;
`mydsl setprompt` is an explicit user command.

---

## 12. `MyDSL_AutoWhere.lua`

**121 lines.** State-aware periodic `where` polling, replacing a native
alias that had no state awareness.

**What it does:** on a user-toggled timer (`autowhere on|off|status`,
default interval 20s), sends `where` unless a skip condition is met
(sleeping, fighting, or blind/no-light — reusing `MyDSL_
CharacterAssist.lua`'s existing vision check rather than re-deriving
blindness detection a second way). Deliberately reuses the native
alias's exact command vocabulary per this project's command-surface
mandate.

**Public surface:** `MyDSL.AutoWhere.start()/stop()/status()` — called
only from this file's own `autowhere` alias. Confirmed via grep: no
other `.lua` file references `MyDSL.AutoWhere`.

**Depends on:** `MyDSL.State.char.posn`/`is_fighting` (from `MyDSL_
DataLayer_PromptVitals.lua`'s Pos'n trigger / GMCP char_data — read
directly, not via `MyDSL.get()`, consistent with the dominant
direct-`State`-access pattern already noted in section 1). Soft
dependency on `MyDSL.CharacterAssist.checkVision()`, checked
defensively (`if MyDSL.CharacterAssist and ... then`) — works without
that module loaded, just skips the blind check.

**Called by:** nothing external.

**Candidate cruft:** the file's own header flags a real, unresolved
manual step: Steven's native `(autowhere) AutoWhere` alias must be
disabled by hand in Mudlet's Alias Editor, or both fire simultaneously
on the same command and run two independent timers. This is a known,
documented gap (not silently missed), but worth confirming during pass
2 whether that manual step was ever actually done — if not, this is a
live double-timer bug, not just a doc note.

**Performance flags:** none — a 20s-interval timer with three cheap
field checks per tick is negligible; not a hot path.

---

## 13. `MyDSL_PromptView.lua`

**179 lines.** Prompt-gag toggle state manager (`mydsl prompt
on|off|toggle`) — UI-mode gagging of the server's raw prompt lines.

**What it does:** owns `MyDSL.Prompt.enabled`, persisted per-character
to `MyDSL/prompt_<CharName>.lua`. The actual gagging (`deleteLine()`)
happens in **two native Mudlet Triggers this file does NOT create** —
its own trailing comment block documents the exact pattern/script pairs
required (`MyDSL_PromptGag_Vitals` on `^\[%d+/%d+HP`, `MyDSL_
PromptGag_Location` on `^==-`), both reading `MyDSL.Prompt.enabled`
directly. **Confirmed via grep against both profiles' native XML**:
these two triggers do **not** exist in DSL2's own reference profile
(`current/2026-07-18#10-13-31.xml` — zero matches), but **do** exist in
the live MyDSL profile (confirmed present in its newest `current/*.xml`
as of this audit) — consistent with this project's established
DSL2-is-source/MyDSL-is-live-play distinction, not a gap.

**Public surface:** `MyDSL.Prompt.enabled` (read only by the two native
triggers above — confirmed via grep, zero other `.lua` files reference
`MyDSL.Prompt`), `MyDSL.Prompt.setEnabled()/toggle()/_cmd()` (internal
to this file's own alias), `MyDSL.Prompt.onLogin()/save()/load()`
(internal lifecycle).

**Depends on:** `MyDSL.Char()`, `MyDSL.login.updated` event (from
`MyDSL_DataLayer_PromptVitals.lua`'s login handler) to trigger a
per-character reload on login.

**Called by:** the two native triggers described above (not `.lua`
code — can't be grep-confirmed the same way, confirmed instead by
reading the native XML directly).

**Candidate cruft:** none found — the design (script owns state/
persistence, native triggers own the actual gag action) is unusual
compared to most of this codebase (which does gagging from inside
`.lua` trigger callbacks directly), but it's deliberate and documented,
not accidental.

**Performance flags:** the two native triggers fire on every prompt
line (real hot path — every server round), but each does only a
2-condition check (`MyDSL.Prompt and MyDSL.Prompt.enabled`) plus
`deleteLine()` when enabled — as cheap as this kind of gag can be. No
concerns.

---

## 14. `MyDSL_MovementSounds.lua`

**205 lines.** Movement key sound selector — plays a walk/ride/fly/swim
sound effect when a NumPad movement key is pressed.

**What it does:** `MyDSL.MoveSound.go(dir)` sends the movement command
then plays a mode-appropriate sound; mode is picked by priority
(riding > flying > swimming > walking), each check reading `MyDSL.
State`/GMCP directly via a private `dataGet()` helper that prefers
`MyDSL.get()` and falls back to raw `gmcp.char_data`/`room_data` if
DataLayer isn't available yet.

**Public surface:** `MyDSL.MoveSound.go(dir)` — confirmed via grep,
called from **10 real native key bindings** in `MyDSL_
GameplayTriggers.xml` (NumPad 1-4/6-9, up/down — the git-tracked native
inventory extraction, not a guess). `MyDSL.MoveSound.status()` —
confirmed via grep, **zero callers anywhere** (no alias, no other file)
— see Candidate cruft. `MyDSL.MoveSound.mode()/isSwimmingSector()/
soundPath()/normalizeDir()` are internal helpers only, called from
`go()`/`play()`/`status()`.

**Depends on:** `MyDSL.get()` (this is the **one and only real caller**
of `MyDSL_DataLayer.lua`'s Get/Set API project-wide, confirmed in
section 1's audit) with a raw-GMCP fallback if it's unavailable.

**Called by:** `MyDSL_GameplayTriggers.xml`'s native NumPad key
bindings (real, live, confirmed via grep).

**Candidate cruft:**
- **`MyDSL.MoveSound.status()` has zero callers anywhere** — no alias
  wires it to a command, no other file references it. A real,
  built-but-unreachable diagnostic function, same class as the
  already-flagged `MyDSL.getTargetCondition()` in section 3. Either add
  a `mydsl movesound status` alias or confirm it's fine to leave
  unreachable.

**Performance flags:** none — fires once per explicit movement
keypress, not a continuous hot path. `stopSounds()`+`playSoundFile()`
per press is the expected cost for this feature.

---

## 15. `MyDSL_CreatureLore.lua`

**249 lines.** Persistent, cross-session, cross-character creature-lore
reference database (Layer 4) — distinct from `MyDSL_DataLayer_
CreatureLore.lua` (Layer 1, raw `creaturelore <keyword>` output
capture); this file is the permanent DB that capture feeds into.

**What it does:** `CL.merge(rec)` upserts a capture into `CL.db`
(keyed by normalized creature name), `CL.get(key)`/`CL.knownState(key)`
(`"known"`/`"seen"`/`"unknown"`, based on whether real lore fields vs.
just a bare sighting exist), `CL.markSeen(key, name)` (creates a stub
record on a mere `look`/`scan` sighting, no lore fields), `CL.
importScraped(path)` (bulk-import from a scraped shatteredarchive.com
bestiary file, additive-only, never overwrites existing fields).
Persisted to `MyDSL/creaturelore_db.lua`, shared across all characters
(objective game data, not character-specific — same reasoning as
`ThemeEngine`).

**Public surface:** confirmed via grep, this module is **genuinely
widely and correctly wired**: `CL.merge()` called from `MyDSL_
DataLayer_CreatureLore.lua`'s `endCreatureLore()`; `CL.knownState()`
called from `MyDSL_ScanView.lua`, `MyDSL_Leveling.lua`, and `MyDSL_
DataLayer_ScanLook.lua`; `CL.markSeen()` called from `MyDSL_
DataLayer_ScanLook.lua` (2 call sites — both mob-sighting paths); `CL.
get()` called from `MyDSL_TargetView.lua` and `MyDSL_
CreatureReference.lua` (the Bestiary window). Every one of these is a
real function call, not a comment mention. `CL.hasLore()` is internal
only (called from `knownState()`). `CL.importScraped()` is called only
from its own one-time `mydsl creaturelore import` alias.

**Depends on:** nothing structurally beyond Mudlet stdlib
(`table.save`/`table.load`, `dofile` for the scraped-import file) —
does not read `MyDSL.State` at all, purely a standalone reference DB
fed by other modules calling into it.

**Called by:** `MyDSL_DataLayer_CreatureLore.lua`, `MyDSL_ScanView.lua`,
`MyDSL_Leveling.lua`, `MyDSL_DataLayer_ScanLook.lua`, `MyDSL_
TargetView.lua`, `MyDSL_CreatureReference.lua` — six real, confirmed
consumers.

**Candidate cruft:** none found — every public function has a real,
traceable caller; this is one of the more cleanly-connected modules
audited so far.

**Performance flags:** `CL.markSeen()` is explicitly documented and
confirmed to only call `CL.save()` (a full `table.save()` disk write)
on a creature's *first-ever* sighting, not on repeat sightings — a
deliberate, already-applied optimization ("stale data beats spam").
`CL.merge()` calls `CL.save()` unconditionally on every real
`creaturelore` capture, but that's an explicit, infrequent user
command, not a hot path. No concerns.

---

## 16. `MyDSL_Roller.lua`

**258 lines.** Character-creation stat-reroll assistant, ported from
PNP's `DSL_PNP_Roller.lua` plus new per-stat-minimum functionality not
present in PNP's original.

**What it does:** matches a `Str: N Int: N Wis: N Dex: N Con: N` stat
line, auto-sends `n` (reject) if the total is below a configurable goal
(default 241) or any individual stat is below its own configured
minimum, and pauses for manual review (never auto-accepts) if the roll
qualifies. Explicitly disables the legacy native `roller` trigger this
module replaced, since it was never actually killed on port and would
otherwise double-reject in parallel with its own, separately-configured
goal.

**Public surface:** `MyDSL.Roller.setGoal()/setMin()/reset()/
showStats()` — all called only from this file's own 4 aliases (`set
goal`, `set min <stat>`, `roll stats`, `reset roll`). Confirmed via
grep: zero external callers of anything in `MyDSL.Roller.*`.

**Depends on:** nothing — fully self-contained, character-creation-only
feature with no read of `MyDSL.State`/GMCP.

**Called by:** nothing external.

**Candidate cruft:** none found — every function traces to a real
alias, and the module's own comments document 3 real historical bugs
(stale-timer race across rapid re-rolls, per-stat-floor logic, native
trigger not being disabled on port) all with confirmed fixes.

**Performance flags:** none — the roll-line trigger only matches
during character creation (a rare, one-time event per character), not
a hot path. `scheduleReject()`'s 0.2s `tempTimer` is single-shot per
roll, not a recurring loop.

---

## 17. `MyDSL_ChatTriggers.lua`

**278 lines.** Layer-3 chat-channel routing — intercepts chat lines and
routes them to EMCO tabs via `MyDSL.Chat.emco:append()`, removing them
from the main console (except where `gag=false` is explicitly passed
for say/tell/yell/shout, per Steven's request to keep those visible
too).

**What it does:** 20 always-active `tempRegexTrigger()` registrations
(confirmed via grep — `route()` called 20 times), each matching one
real, corpus-confirmed DSL chat-line shape (Tells, Group, OOC, City/
gossip family, Local speech, auctions/grats/ask-answer-newbie/
Bloodbath-quest). The file's own extensive comment history documents a
real, confirmed double-fire bug class (unanchored patterns with a
quote-crossing `.+` prefix let one line match two different `route()`
patterns at once, corrupting both) fixed by anchoring every pattern to
line-start and introducing the `NC` character class (matches any
non-quote character, or a mid-word apostrophe like "Iler'yx", so a real
opening quote is never mistaken for part of a name).

**Public surface:** nothing — `MyDSL.ChatTriggers._triggers` is a
private ID-tracking table for deregistration on reload, not read by
any other file. Confirmed via grep: zero external references to
`MyDSL.ChatTriggers`.

**Depends on:** `MyDSL.Chat.emco` (created by `MyDSL_Chat.lua` — this
file's own header states it "must load LAST" for exactly this reason).
The `route()` helper defensively checks `if MyDSL and MyDSL.Chat and
MyDSL.Chat.emco then` before appending, so a chat line arriving before
`MyDSL_Chat.lua`'s own startup ladder finishes stays visible on the
main console instead of being silently deleted with nowhere to go — a
real, documented 2026-07-17 data-loss fix.

**Called by:** nothing external — purely a self-contained routing
layer.

**Candidate cruft:**
- `deregisterTriggers()` calls both `pcall(killAnonymousEventHandler,
  id)` and `pcall(killTrigger, id)` on every stored ID, but this file
  only ever creates regex triggers via `tempRegexTrigger()` (never an
  anonymous event handler) — the `killAnonymousEventHandler` call is
  dead code that always no-ops silently inside its own `pcall`. Cosmetic
  only, harmless, but worth a one-line cleanup (remove the
  `killAnonymousEventHandler` call) if this file is touched for other
  reasons.

**Performance flags:**
- **20 always-active regex triggers evaluate against every single
  incoming line**, whether or not it's chat-shaped at all — the same
  class of concern already flagged for `MyDSL_DataLayer_Combat.lua`'s
  24 always-active combat triggers (section 3) and `map.dsl.
  captureLine()`'s `onNewLine` hook (section 10). Individually cheap
  (Mudlet's regex engine short-circuits non-matches), but this is now
  the third file in this audit with a large always-on trigger count —
  worth a project-wide note once all 40 sections are done: how many
  total always-active regex evaluations does one incoming line pay for
  across the whole addon? Not answerable from any single file's
  section alone.
- The `NC` character class (`(?:[^']|(?<=\w)'(?=\w))`) uses a
  lookbehind/lookahead per non-quote character matched, which is
  somewhat more expensive per-character than a plain negated character
  class — but chat lines are short and this only runs on the subset of
  lines that get past each pattern's fixed literal prefix first, so
  this is unlikely to be a measurable cost. Not flagged as a real
  concern, noted for completeness only.
## 18. `MyDSL_ItemLore.lua`

**326 lines.** Layer 4, first slice — persistent, cross-session item-stats
DB, shared across characters (not character-bound, same reasoning as
CreatureLore/ThemeEngine: item stats are objective game data).

**What it does:** `IL.merge(rec)` (upsert-by-key for a live `identify`/
`lore` capture — a real `identify` authoritatively clears any
`FULL_STAT_FIELDS` entry it doesn't report, fixing a 2026-07-19 bug where
a stale scrape-imported flag could never be cleared by a real identify
confirming "none"), `IL.get(key)`/`IL.knownState(key)`/`IL.hasFullStats(rec)`
(three-state known/seen/unknown model), `IL.importScraped(path)` (bulk
community-scrape import, fill-gaps-only, never overwrites a real capture),
`IL.cleanupBadSpellCharges()` (one-time fixup command), `IL.save()`/
`IL.load()` (own dedicated `itemlore_db.lua` file, correct `table.load(file,
target)` two-argument form).

**Public surface:** `IL.merge()` — called from `MyDSL_DataLayer_ItemLore.lua`
(2 real call sites: identify and lore-item capture completion). `IL.get()`
— called from `MyDSL_DataLayer_ItemLore.lua` (5 call sites, hover-text
lookups), `MyDSL_DataLayer_ScanLook.lua` (ground-item hover), `MyDSL_
ItemReference.lua` (render lookup). `IL.knownState()` — called from `MyDSL_
ItemReference.lua` only. `IL.hasFullStats()` — **zero external callers**,
used only internally by `IL.knownState()` itself; not cruft, just a private
helper that happens to be exposed on the public table. `IL.save()`/
`IL.load()` — called only from within this file (via `merge()`/
`importScraped()`/`cleanupBadSpellCharges()`/boot). All confirmed via grep,
not assumed.

**Depends on:** nothing else in this codebase structurally — a standalone
Layer-4 DB with its own save file. Reads `getMudletHomeDir()`/`dofile()`
(for scrape import) directly.

**Called by:** `MyDSL_DataLayer_ItemLore.lua` (merge, on every identify/lore
capture), `MyDSL_DataLayer_ScanLook.lua` (get, for ground-item hover text),
`MyDSL_ItemReference.lua` (get + knownState, for window rendering).

**Candidate cruft:** none found — every public function traces to a real
caller except the internal-only `hasFullStats()`, which is fine as an
implementation detail.

**Performance flags:** `IL.save()` does a full `table.save()` of the
**entire item DB** (potentially thousands of entries after a scrape
import) on every single `merge()` call — i.e. every real in-game identify/
lore capture triggers a full-DB disk write, not just the one changed
record. This is the same class of issue `MyDSL_DataLayer.lua`'s own
`MyDSL.save()` had before its 2026-07-19 debounce fix (see section 1) —
but identify/lore captures happen far less often than combat, so the
practical impact is much smaller. Not flagged as urgent, but worth noting
for consistency if a future pass debounces saves project-wide. `import
Scraped()` saves once at the end (already correctly batched, per its own
comment) — no concern there.

---

## 19. `MyDSL_ItemReference.lua`

**359 lines.** Layer 4 display — listens for `MyDSL.itemlore.updated`,
renders the item record in the `MyDSL_ItemReference` window. Directly
modeled on `MyDSL_CreatureReference.lua`'s (Bestiary) pattern.

**What it does:** `IR.render(name)` (DB-first, falls back to `MyDSL.State.
itemlore` live capture), `IR.onItemUpdate()` (auto-show on fresh data),
`IR.show()`/`hide()`/`status()`/`rebuild()`/`setFont()`, the `item <name>`
alias family (including `item map <ground> = <target>`, the manual
ground-to-inventory override escape hatch).

**Public surface:** `IR.render()`/`IR.show()` are called indirectly via
**dynamically-generated hover-link click scripts** built as string literals
inside `MyDSL_DataLayer_ItemLore.lua` (4 call sites) and `MyDSL_
DataLayer_ScanLook.lua` (1 call site) — e.g. `'if MyDSL and MyDSL.
ItemReference then MyDSL.ItemReference.render("%s"); MyDSL.ItemReference.
show() end'`, wired as a clickable link's script, not a direct Lua call.
Confirmed real via grep, not assumed — this is the "Click for Item
Reference" hover pattern referenced elsewhere in the codebase. Every
other function (`hide`/`status`/`rebuild`/`setFont`) is called only from
this file's own `item <name>` alias.

**Depends on:** `MyDSL.ItemLore.get()`/`knownState()` (real, direct
call), `MyDSL.setGroundItemOverride()` (defined in `MyDSL_DataLayer_
ItemLore.lua`, called from the `item map ... = ...` alias branch — a real,
confirmed Layer-4-to-Layer-1 cross-reference), `MyDSL.Windows.*` (generic
window lifecycle), `MyDSL.Theme.styleConsole` (soft-checked).

**Called by:** `MyDSL_DataLayer_ItemLore.lua`/`MyDSL_DataLayer_ScanLook.lua`
via the generated hover-link scripts described above (the real, primary
way this window actually gets shown/populated day-to-day — a player
clicking an item's hover hint, not typing `item <name>` by hand, is
almost certainly the dominant real usage path, though both work).

**Candidate cruft:** none found — every function has a real, traceable
caller (direct alias dispatch or the hover-link mechanism).

**Performance flags:** none — this file only runs in response to an
explicit player action (identify/lore capture completing, or a hover-link
click). Not a hot path.

---

## 20. `MyDSL_RouteHelper.lua`

**363 lines.** Layer 3 — generic text routing to windows
(`MyDSL.Route.to(windowName, line)` plus shorthand helpers), used by
whichever captures still route raw/decho'd text rather than rendering
through their own structured View module.

**What it does:** `getOrCreateConsole(windowName)` (lazy MiniConsole
creation inside a registered UserWindow), `MyDSL.Route.to()` (decho mode
with an explicit line, or raw-copy `appendBuffer()` mode preserving
original game colors when `line` is nil), `MyDSL.Route.clear()`/
`getConsole()`, the `MyDSL_History` window's font/status commands
(`setHistoryFont()`/`historyStatus()`), and the `MyDSL_PlayersNear`
window's show/hide/font/status command family. The file's own header
already documents that Combat/Scan/Group/RightHere's shorthand helpers
were removed 2026-08-23 as confirmed dead — those windows now have their
own structured View modules instead of raw-text routing.

**Public surface:** `MyDSL.Route.players()`/`MyDSL.Route.clear(
"MyDSL_PlayersNear")` — confirmed real callers in `MyDSL_DataLayer_
ScanLook.lua` (4 call sites total, the "Players near you:" capture
routing). `MyDSL.Route.history()` and `MyDSL.Route.getConsole()` —
**confirmed via grep across the entire repo: ZERO external callers of
either, and `MyDSL.Route.history()` isn't even referenced from within
this file beyond its own one-line definition.** See Candidate cruft — this
is a real, notable finding.

**Depends on:** `MyDSL.Windows.*` (registry/ensure/getFontSize/
setFontSize), `MyDSL.Theme.styleConsole` (soft), `MyDSL.logWindow`
(soft).

**Called by:** `MyDSL_DataLayer_ScanLook.lua` (`Route.players`/
`Route.clear`, real, confirmed). Nothing calls `Route.history()`.

**Candidate cruft — genuinely notable finding, not just narrow-usage
noise:**
- **The entire `MyDSL_History` window appears fully wired but never
  actually fed any content.** It's a real, registered window (`MyDSL_
  WindowRegistry.lua`'s registry, `MyDSL_LayoutEngine.lua`'s layout slot
  — described there as "general informational output — sailing, quests,
  atmosphere events" — `MyDSL_ThemeEngine.lua`'s theme mapping, `MyDSL_
  Help.lua`'s help text, and this file's complete font/status/config
  surface), but `MyDSL.Route.history()` — the one function that would
  actually put text into it — has no caller anywhere in the codebase.
  Confirmed via grep, not a narrow-usage judgment call: this looks like a
  window that was fully built out (title, font persistence, adaptive
  word-wrap, theme integration, status diagnostics) but the actual
  trigger/capture wiring that was supposed to feed it (sailing/quest/
  atmosphere text, per its own layout comment) was never connected, or
  was connected once and later removed without anyone noticing the
  window went silent. Worth Steven confirming: was History ever
  populated in practice, or has it always shown empty since it was
  built?
- `MyDSL.Route.getConsole()` has zero external callers — much lower
  stakes (a generic accessor nobody happened to need yet), listed for
  completeness.

**Performance flags:** none — this file only runs in response to an
explicit routed capture completing (rare, not a hot path), plus one
`registerAnonymousEventHandler("MyDSL.theme.changed", ...)` that only
fires on an explicit user theme switch.

---

## 21. `MyDSL_CreatureReference.lua`

**380 lines.** Layer 3 Phase B — listens for `MyDSL.creaturelore.updated`
(and, since a 2026-07-12 fix, `MyDSL.target.updated`), renders the
Bestiary window.

**What it does:** `CR.render(name)` (DB-first via `MyDSL.CreatureLore.get()`,
falls back to `MyDSL.State.creaturelore`), `CR.onLoreUpdate()` (auto-show
on fresh capture), `CR.onTargetUpdate()` (keep content in sync when the
current target changes, without auto-showing — a real 2026-07-12 gap fix,
documented in its own header), `CR.show()`/`hide()`/`status()`/
`rebuild()`/`setFont()`, the `bestiary <name>` alias family.

**Public surface:** every function here is called only from this file's
own event handlers/alias (confirmed via grep — every other mention of
`MyDSL.CreatureReference` project-wide is a comment referencing this
module's design pattern, not a real call, e.g. `MyDSL_ItemReference.lua`'s
header explicitly modeling itself on this file). This is the expected,
correct pattern for an event-driven display module, not cruft.

**Depends on:** `MyDSL.CreatureLore.get()`/`knownState()` (real,
confirmed — `MyDSL_CreatureLore.lua`'s DB), `MyDSL.State.creaturelore`/
`MyDSL.State.target` (direct State reads, bypassing any Get/Set API, same
pattern as most other View modules), `MyDSL.Windows.*`, `MyDSL.Theme.
styleConsole` (soft).

**Called by:** nothing external — self-contained event-driven module.

**Candidate cruft:** none found — this file's own comments document two
real historical bugs (hex-color-tag/cecho mismatch; missing target-update
listener) that were found and fixed, not speculative code left in place.

**Performance flags:** none — fires only on a real `creaturelore`
capture completing or a target switch (via `MyDSL.target.updated`, which
itself only fires on an explicit target change, not a hot path).

---

## 22. `MyDSL_ScanView.lua`

**389 lines.** Layer 3 Phase B — passive display for two windows:
`MyDSL_Scan` (raw game-colored feed via `appendBuffer`) and `MyDSL_
RightHere` (clickable target list rebuilt from `MyDSL.State.scan.
rightHere`).

**What it does:** `SV.renderRightHere()`/`SV.render()` (clickable
Known/Seen/Unknown-badged target links, badge sourced from `MyDSL.
CreatureLore.knownState()`), `SV.setGag(enabled)` (header-line gagging;
body-line gagging lives in `MyDSL_DataLayer_ScanLook.lua`'s own
`parseScanLine()`, checked via this module's `config.gagScan` flag — a
real, confirmed Layer-1-reads-Layer-3-config dependency), the combat-
death RightHere decrement handler (a real 2026-07-16 gap fix — nothing
previously removed a dead mob from RightHere's count mid-fight), the full
status/show/hide/rebuild/font command family for both windows, and
`SV.dumpRightHere()` (a one-shot live diagnostic alias).

**Public surface:** `SV.ui.scanConsole` — **read and written directly by
`MyDSL_DataLayer_ScanLook.lua`** (`:clear()`/`:appendBuffer()`, 3 call
sites), a real, deliberate Layer-1-reaches-into-Layer-3 dependency
(DataLayer needs the raw MiniConsole object to preserve original game
colors via `appendBuffer`, which only works on the actual widget, not a
decho'd copy) — documented in this file's own comment ("so DataLayer can
call appendBuffer on it"). `SV.config.gagScan` — read by `MyDSL_
DataLayer_ScanLook.lua`'s `parseScanLine()`. `SV.render()`/`renderRight
Here()` — called only from this file's own event handlers/aliases.

**Depends on:** `MyDSL.State.scan` (direct read), `MyDSL.CreatureLore.
knownState()` (soft-checked, for the Known/Seen/Unknown badge), `MyDSL.
Target.set()` (generated click-link script, real cross-reference to
`MyDSL_TargetView.lua`'s Target API — confirmed via the `cmd` string
built in `renderRightHere()`), `MyDSL.Windows.*`, `MyDSL.Theme.
styleConsole` (soft), `MyDSL.logWindow` (soft).

**Called by:** `MyDSL_DataLayer_ScanLook.lua` (direct MiniConsole access
+ `config.gagScan` read, both confirmed real and load-bearing —
this is one of the tightest two-way couplings found in this audit so
far, though a deliberate, documented one rather than an oversight).

**Candidate cruft:** none found — every piece of this file traces to a
real caller or a documented design reason (including the click-to-target
link generation, confirmed wired to `MyDSL.Target.set()`).

**Performance flags:** `SV.render()`/`renderRightHere()` only fire on
`MyDSL.scan.updated` (an explicit `scan`/`look` command) or `MyDSL.
combat.died` (once per kill, not per swing) — not a hot path. The
Known/Seen/Unknown badge lookup is O(1) per RightHere entry (a single DB
`get()`), and RightHere entries are bounded by room population. No
concerns.

---

## 23. `MyDSL_CombatView.lua`

**459 lines.** Layer 3 Phase B — the Combat window. Two responsibilities:
a live per-swing feed (`CV.appendSwing()`, called directly and
synchronously from `MyDSL_DataLayer_Combat.lua`'s `parseCombatDamageLine()`
for every non-miss swing) and a per-target fight-summary block
(`CV.renderSummary()`, on death/flee/rescue — this project's own addition,
no PNP equivalent).

**What it does:** `CV.appendSwing(text)` (raw append, never cleared —
matches PNP's `battle_console` exactly), `CV.renderSummary(snapshot)`
(hit-rate/proc-percentage breakdown per attacker/weapon), `CV.
renderRage(dmg, vamp)` (rage-mode indicator), the full raw/condensed/gag
3-way main-console mode system (`mydsl combat mode <raw|condensed|gag>`,
collapsed 2026-07-11 from 3 near-duplicate if/elseif branches into one
data table per a code-review finding), font persistence (character-
bound, correct `table.load(file, target)` 2-arg form — this file's own
comment documents the historical 1-arg bug and its fix), and the
`mydsl combat <verb>` alias family (`clear`/`history`/`gag`/`ungag`/
`show <flag>`/`hide <flag>`/`font <n>`), plus PNP's native `toggle
battle` command vocabulary reused directly (not reinvented).

**Public surface:** `CV.appendSwing()` — called directly from `MyDSL_
DataLayer_Combat.lua`'s `parseCombatDamageLine()` (confirmed, the
primary hot-path integration point for this file) and from the
`combatRoundFlush` handler for the pending-condition note. `CV.
renderSummary()` — called from this file's own `MyDSL.combat.ended`
handler and the `mydsl combat history` alias (replays stored snapshots).
`CV.config` (the gag/show/summarize_damage table) — read defensively by
`MyDSL_DataLayer_Combat.lua` throughout (`if MyDSL.CombatView and
MyDSL.CombatView.config then ...`, confirmed in section 3's own
findings) — this is the real gag/show decision surface for the entire
combat-capture pipeline, living in the View layer rather than DataLayer,
a real but long-standing and clearly deliberate architectural choice
(matches PNP's own design, per this file's header).

**Depends on:** `MyDSL.charName()`/`MyDSL.safeFileName()` (delegated to
`MyDSL_DataLayer.lua`, with a local fallback copy if DataLayer somehow
isn't loaded yet — defensive, not a hard `dofile` dependency), `MyDSL.
State.combat` (direct read/write via the `mydsl combat clear` alias),
`MyDSL.Windows.*`, `MyDSL.Theme.styleConsole` (soft), `MyDSL.logWindow`
(soft).

**Called by:** `MyDSL_DataLayer_Combat.lua` (`appendSwing`, `config.*` —
both real, hot-path-adjacent dependencies, confirmed in section 3).

**Candidate cruft:** none found — every function traces to a real caller,
and the file's own comment history documents genuine bugs found and
fixed (the table.load 1-arg bug; the "raw mode" promise being
structurally broken before a 2026-07-11 fix; the missing scrollbar
removal Combat was left out of).

**Performance flags:** `CV.appendSwing()` runs once per non-miss swing —
genuinely hot during combat (same hot path as `MyDSL_DataLayer_Combat.lua`
itself), but the function body is a single `mc:decho()` call plus a
`MyDSL.logWindow()` mirror — no loops, no table rebuilds. Not a concern
on its own. `CV.renderSummary()` is O(attackers × weapons) per fight-end
event, bounded and infrequent (once per kill/flee/rescue, not per
swing). No new performance issues found.

---

## 24. `MyDSL_state.lua` — data file, not a logic module

**459 lines.** Confirmed by inspection: this is `MyDSL_DataLayer.lua`'s
own `MyDSL.save()` output (`table.save()` of `MyDSL.Data`, a per-
character snapshot of 16 State sections — char/login/room/affects/tick/
score/lunar/time/weather/who/group/unread/inv/map/improve/flags — see
section 1's own `saveFilePath()`/`MyDSL.save()` writeup). Same category
as `MyDSL_windowstate_<CharName>.lua`/`MyDSL_theme_settings.lua`/
`MyDSL_windowfonts.lua` already listed in this doc's "Data-only files"
section at the top — pure persisted data, no logic, loaded via `table.
load()` by `MyDSL.load()`. Not given a full inventory writeup for the
same reason those aren't: there's no "what it does"/"public surface" to
audit in a saved snapshot. Worth folding this file into that top-level
"Data-only files" list alongside the others when this doc gets tidied
up, rather than leaving it as a numbered section that looks like a real
module at a glance.
## 25. `MyDSL_GroupView.lua`

**474 lines.** Layer 3 display: renders the group-members window (class,
name, HP/mana/mv bars, quick-action buttons) from `MyDSL.State.group`.
Passive only, never sends commands directly (quick-action buttons send
via `MyDSL.TargetView.actions[key].cmd()`, reusing TargetView's action
table rather than defining its own).

**What it does:** `GV.render()` redraws the window on every `MyDSL.
group.updated` event; `GV.setGag()` toggles a header-line gag trigger
(body-line gagging is delegated to `MyDSL_DataLayer_PromptVitals.lua`'s
`beginGroup()` catch-all reading `GV.config.gagGroup` directly — a real,
confirmed cross-file read, not a comment claim); `GV.setTarget()`/
`GV.quickAction()` are dechoLink click handlers (set Focus target, fire
a quick command); per-character `quickActions` config persistence
(`loadConfig()`/`saveConfig()`, same pattern as `MyDSL_TargetView.lua`).
Standard window lifecycle: `status()/show()/hide()/rebuild()/setFont()`.

**Public surface:** `GV.render/setGag/setTarget/quickAction/
resetQuickActions/status/show/hide/rebuild/setFont` — confirmed via grep,
**zero external module callers** for any of these; every real call site
is either this file's own aliases/dechoLinks or `MyDSL_DataLayer_
PromptVitals.lua` reading `GV.config.gagGroup` (soft, defensive check).
This is the expected, correct pattern (matches `MyDSL_TargetView.lua`'s
own shape).

**Depends on:** `MyDSL.State.group` (from `MyDSL_DataLayer_
PromptVitals.lua`), `MyDSL.TargetView.actions` (quick-action lookup —
real cross-file dependency, confirmed via grep this table is shared by
construction, not duplicated), `MyDSL.copyArray()` (a real, 3-caller
shared utility in `MyDSL_DataLayer.lua` — also used by `MyDSL_
TargetView.lua`, not dead), `MyDSL.charName()`/`MyDSL.safeFileName()`
(`MyDSL_DataLayer.lua`, each with 4 real callers project-wide), `MyDSL.
Windows.*`/`MyDSL.Theme.styleConsole` (Layer 2/3 infra).

**Called by:** nothing external calls into this module's functions —
it's a leaf display module. `MyDSL.GroupView.config.gagGroup` is read
by `MyDSL_DataLayer_PromptVitals.lua` (the one real, confirmed
cross-file dependency, matching what that file's own section already
documents).

**Candidate cruft:** none found this pass — every function traces to a
real trigger, alias, or dechoLink; config persistence is real and
wired correctly (fixed 2026-07-11 per its own comment history).

**Performance flags:** none — this module only redraws on `MyDSL.
group.updated` (fires when the `group` command output is parsed, not a
hot path) and `MyDSL.theme.changed` (user-triggered). No polling, no
per-tick redraw, no unbounded loops (`render()` iterates `grp.members`,
bounded by real group size).

---

## 26. `MyDSL_TickView.lua`

**478 lines.** Display-only tick countdown window ("TickSource owns
timing, TickView only renders `MyDSL.DB.tick`/`MyDSL.DB.timers.tick`" —
its own header comment, confirmed accurate by this audit).

**What it does:** `V.render(reason)` redraws a vertical gauge (tube +
fill + countdown text + detail line) from `MyDSL.DB.tick`, color-coded
by remaining time (`V.palette()`: green "ready" / yellow "warn" at
≤15s / red "danger" at ≤5s). Settings persistence via its own
`tickview_settings.lua` (separate from `MyDSL.Windows`'s per-window
registry — see Candidate cruft). Standard lifecycle: `show/hide/
toggle/rebuild/setFont/setMode/setTitle/status`.

**Public surface:** `V.render/show/hide/toggle/rebuild/setFont/
setMode/setTitle/status/installHandlers/installAliases/boot` —
confirmed via grep, **zero external module callers** — every real call
site is this file's own `mydsl tickview <verb>`/`toggle ticktimer`
aliases.

**Depends on:** `MyDSL.DB.tick`/`MyDSL.DB.timers.tick` (`MyDSL_
DataBridge.lua`/`MyDSL_TickSource.lua`), `MyDSL.Theme.panelCSS/
colorToCSS/get` (soft-checked), `MyDSL.Windows.registry["MyDSL_Tick"]`
(read/written directly for a visibility-state sync — see Candidate
cruft).

**Called by:** nothing external — leaf display module.

**Candidate cruft:**
- **Two independently-persisted visibility flags for the same window,
  confirmed still real as of this pass**: `V.config.shown` (this
  file's own `tickview_settings.lua`) and `MyDSL.Windows.
  registry["MyDSL_Tick"].visible` (WindowRegistry's separate state
  file). The file's own 2026-07-11 comment already documents this
  exact drift risk and added `syncRegistryVisible()`/`V.toggle()`
  preferring the registry's value as a partial fix — but `V.show()`/
  `V.hide()` still write to BOTH locations on every call rather than
  there being one source of truth, so the drift is mitigated, not
  eliminated. Worth Steven deciding whether TickView should stop
  keeping its own `shown` flag entirely and read WindowRegistry
  exclusively, now that a sync path already exists.
- `V.settingsFile()`/`saveSettings()`/`loadSettings()` hand-roll a
  bespoke `return { ... }` Lua-literal serializer instead of using
  `table.save()`/`table.load()` like every other module in this
  codebase (`MyDSL_GroupView.lua`, `MyDSL_LayoutEngine.lua`, `MyDSL_
  ThemeEngine.lua`, etc. all use the stdlib pair). Not a bug — it
  works — but it's a real, isolated inconsistency in persistence
  convention worth flagging since the audit is specifically looking
  for "connections not in the same namespace" drift.

**Performance flags:**
- **Cross-references `MyDSL_TickSource.lua`'s section 8 finding
  directly: `V.render()` is called on every `MyDSL.Timers.Updated`
  event, which fires at TickSource's unconditional 4Hz loop rate —
  and `V.render()` does NOT check `V.config.shown`/window-visibility
  before doing its work.** Confirmed via grep: no early-return on
  hidden state anywhere in `render()` — it always recomputes the
  palette, repositions/restyles the fill Label, and re-echoes 3 text
  labels, 4 times a second, even while the window is fully hidden via
  `V.hide()` (which only calls `win:hide()`, it doesn't stop the
  render loop feeding it). This means gating TickSource's 4Hz loop
  alone (the fix suggested in that file's section) wouldn't fully
  solve the problem on its own — `V.render()` itself would need the
  same visibility gate, or the fix has to happen at the TickSource
  level so nothing downstream needs to know about visibility at all.
  Real, concrete, connects two separately-audited files into one
  finding.

---

## 27. `MyDSL_CharacterAssist.lua`

**479 lines.** Interactive equipment/combat-recovery assists — rearm on
disarm, standup on knockdown, spellup automation loop. Ported from
PNP's `DSL_PNP_Character.{disarm,spellup,standup}.lua`. Unlike Layer 1
(`MyDSL_DataLayer*.lua`), this module deliberately SENDS real game
commands — an approved, scoped exception (rearm/standup fire with zero
typed input on a passive combat trigger; spellup's loop is gated behind
an explicit user-typed start command).

**What it does:** `CA.useItem()` (the one command-sending primitive
everything else is built on — retrieve+wear/wield/cast an equipment
item by derived keyword), `CA.checkVision()` (blind/no-light/can-see,
derived from `MyDSL.State.room.name == "darkness"`), `CA.rearm()`/
`rearmShield()` (auto-triggered on 6 disarm message patterns),
`CA.standup()` (auto-triggered on 2 knockdown message patterns),
`CA.startSpellup()`/`nextItem()`/`repeatItem()`/`stop()` (the bless/
fireproof per-item automation loop, driven by `MyDSL.char.updated` for
its "wait for server response" step since DSL2 has no native
`onPrompt`-equivalent event).

**Public surface:** `CA.checkVision()` — confirmed via grep, the one
real external dependency: **exported specifically so `MyDSL_
AutoWhere.lua` can reuse it** (that file's own comment says so, and the
call site is real, not a comment). Every other `CA.*` function
(`useItem/rearm/rearmShield/standup/startSpellup/nextItem/repeatItem/
stop/setSpellInfo/spellupIgnore/equipWand/onCharUpdated`) has zero
external callers — all wired internally via this file's own triggers/
aliases/`registerAnonymousEventHandler`.

**Depends on:** `MyDSL.State.equipment.slots`/`ignore` (read AND
written — `spellupIgnore()` writes `MyDSL.State.equipment.ignore`
directly, one more confirmed instance of the already-documented
State-bypasses-Get/Set-API pattern), `MyDSL.State.room.name` (vision
check).

**Called by:** `MyDSL_AutoWhere.lua` → `CA.checkVision()` (real,
confirmed).

**Candidate cruft:** none found — every trigger/alias/function traces
to a real, documented, Steven-approved feature. `deriveKey()`'s own
comment notes PNP has a "set keyword" override alias for auto-derived
keywords guessing wrong that wasn't ported ("v1: auto-derive only,
revisit if it turns out to guess wrong often enough to matter") — a
deliberate, self-flagged scope cut, not an oversight.

**Performance flags:**
- `registerAnonymousEventHandler("MyDSL.char.updated", "MyDSL.
  CharacterAssist.onCharUpdated")` adds one more listener to the same
  hot `char.updated` event storm already flagged in `MyDSL_
  DataBridge.lua`'s and `MyDSL_DataLayer_Combat.lua`'s sections (fires
  every combat round). `onCharUpdated()` itself is cheap when idle —
  immediate `if CA._waiting ... elseif CA._repeatWaiting` check, both
  false outside an active spellup run — so this is a small, not a
  major, addition to that same event's total listener count. Worth
  noting only because it's one more entry in the tally, not because
  it's independently expensive.
- No other concerns — `useItem()`/`rearm()`/etc. only run on an
  explicit disarm/knockdown/spellup event, not on every line.

---

## 28. `MyDSL_LayoutEngine.lua`

**516 lines.** Layer 2, File 2 of 3: percentage-based window layout
system. Owns where every window's *first-ever* position is; Mudlet's
own native dock-state persistence takes over after that (this file's
own header is explicit about this — its positions only matter "the
very first time a window is ever created"). Deliberately has zero
dependency on `MyDSL_WindowRegistry.lua` (File 3) to avoid a circular
import — `reflowAll(registry)` takes the registry as a parameter
instead.

**What it does:** `MyDSL.Layout.defaults` (one `{x,y,w,h}` fractional-
position entry per window, heavily comment-annotated with real
per-window layout history), `get/set/snapBack` (accessors),
`save/load/validate` (persistence to `MyDSL_layout.lua`, with the
already-fixed `table.load()` two-argument bug documented inline),
`isOnScreen/applyToWindow/reflowAll` (pixel-math + apply-to-a-real-
Geyser-object).

**Public surface:** `MyDSL.Layout.get/set/resetAll/reflowAll/
applyToWindow/isOnScreen/snapBack/save/load/validate`. Confirmed via
grep: `get()` is the dominant real caller (`MyDSL_WindowRegistry.lua`
×2, `MyDSL_MoonWeather.lua`, `MyDSL_AlterformView.lua` — both of the
latter for their own Container-anchored positioning, not real
UserWindows). `resetAll()`/`reflowAll()` are called from `MyDSL_
WindowRegistry.lua`'s "mydsl layout reset" alias only. `set/snapBack/
isOnScreen/applyToWindow/save/load/validate` have zero external
callers — used only internally by this file's own functions.

**Depends on:** nothing else in this codebase (by design — this is
explicitly one of the two Layer-2 "own their data, no cross-imports"
files alongside `MyDSL_ThemeEngine.lua`).

**Called by:** `MyDSL_WindowRegistry.lua` (`get`, `resetAll`,
`reflowAll`), `MyDSL_MoonWeather.lua`/`MyDSL_AlterformView.lua` (`get`,
for their own Container positioning).

**Candidate cruft:**
- **Real dead scaffolding, confirmed via grep**: `MyDSL.Layout.
  _handlers.characterIdentified` is declared and deregistered at
  module-load time (lines 33-39, the standard "safe-reload" pattern
  every other module uses) — but no code anywhere in this 516-line
  file ever registers a handler under that key. There is no
  corresponding `registerAnonymousEventHandler(..., ...)` call
  assigning into `MyDSL.Layout._handlers.characterIdentified` at all.
  Either a handler was removed at some point and its dereg cleanup was
  left behind, or one was planned and never implemented — either way,
  4 lines of pure dead code, safe to remove (killing a handler that
  was never registered is a harmless no-op via the `pcall` guard, so
  this has caused zero live bugs, just leftover scaffolding).

**Performance flags:** none — `set()`/`snapBack()` call `save()`
(`table.save()`, a real disk write) on every invocation with no
debounce, unlike `MyDSL_DataLayer.lua`'s persistence layer — but both
are only ever called from an explicit user drag/resize or `snapBack`
action, never a hot path, so the lack of debouncing here is a
non-issue (contrast with `MyDSL.save()`'s 2026-07-19 debounce fix,
which mattered specifically because THAT save fired on every
affect-change during combat). `reflowAll()`/`applyToWindow()` are only
invoked explicitly (Section 8's own comment: automatic reflow-on-resize
was deliberately removed because it fought the user), never on a
timer or per-line trigger.

---

## 29. `MyDSL_Help.lua`

**567 lines.** Layer 3: in-UI 3-level help system for DSL2's own UI
(main-console terse list → clickable overview window → per-module
detail page). Replaces an older flat `MyDSL.help()` dump that used to
live directly in `MyDSL_DataLayer.lua`.

**What it does:** `MyDSL.Help.modules` — a large (24-entry) hand-
maintained content table, one entry per user-facing module (title,
category, summary, command list with examples). `MyDSL.help()` prints
the terse main-console version with clickable links; `MyDSL.Help.
renderOverview()`/`render(key)`/`open(key)` drive the `MyDSL_Help`
UserWindow's 3 view levels via `dechoLink()` navigation (confirmed via
this file's own header comment and cross-referenced against `MyDSL_
PromptSetup.lua`/`MyDSL_GroupView.lua`: the 2nd `dechoLink` arg is Lua
code executed on click, not a typed alias command, so no per-module
alias is needed for navigation).

**Public surface:** `MyDSL.Help.init/renderOverview/render/open/
setFont`, `MyDSL.help()`. Confirmed via grep: **zero external module
callers** for any of these — every real call site is this file's own
`mydsl help[...]`aliases or its own internal `dechoLink` click targets.
This is a correctly self-contained leaf module.

**Depends on:** `MyDSL.Windows.ensure/show/setFontSize` (Layer 2/3
window infra), `MyDSL.Theme.styleConsole` (soft-checked).

**Called by:** nothing external.

**Candidate cruft:**
- **Self-identified maintenance-drift risk, not code cruft**: the
  file's own header explicitly says `MyDSL.Help.modules` is "hand-
  maintained... not derived at runtime from the live alias tree, so
  keep this in sync by hand when a module gains/loses a command." Not
  independently audited command-by-command against the live alias
  tree this pass (would require cross-referencing all 24 modules'
  documented commands against every other file's real `tempAlias`
  registrations, a separate exercise) — flagging the file's own
  admitted risk here rather than silently passing over it, since the
  audit's own goal ("cross check connections... review it like it's a
  new project") is exactly the kind of check that would catch this if
  it's drifted.

**Performance flags:** none — purely reactive to explicit `mydsl
help...` commands and window-open clicks, no polling, no per-tick
work, one `MyDSL.theme.changed` listener (cheap, user-triggered only).

---

## 30. `MyDSL_ThemeEngine.lua`

**572 lines.** Layer 2, File 1 of 3: visual theme system — 5 named
presets, per-window zone assignment (used only by the `zoned_hud`
preset), per-window override escape hatch, and the `theme` alias
family. Already been through one real cleanup pass (2026-08-23: 3 dead
functions — `titleCSS()`/`bodyTextCSS()`/`colorToEcho()` — removed
after confirming zero real callers; `setOverride()`/`clearOverride()`
were found half-wired and finished into the real `theme override`
alias).

**What it does:** `MyDSL.Theme.presets` (5 complete key-sets: refined_
convergence/terminal_purist/zoned_hud/obsidian_ember/arcane_midnight),
`MyDSL.Theme.get(windowName, key)` (4-tier precedence: per-window
override → active preset's zone entry → active preset's flat value →
bare default), `colorToCSS()`/`colorToBracket()` (two genuinely
different, non-interchangeable color-string formats — CSS rgba() vs.
Geyser's own `"<r,g,b>"` bracket notation, confirmed against real
`GeyserLabel.lua` source per this file's own comment), `panelCSS()`/
`styleConsole()` (ready-made stylesheet builders every View module's
background Label/MiniConsole calls into), `setTheme()`/`setOverride()`/
`clearOverride()` (mutators, each raising `MyDSL.theme.changed`).

**Public surface, confirmed via grep (real external call counts, not
just definitions):** `MyDSL.Theme.get` (26 external call sites — the
dominant real API), `styleConsole` (36 — the single most-called
function in this file, used by nearly every View module's window
init), `colorToCSS` (15), `panelCSS` (9), `colorToBracket` (3, real —
`MyDSL_Chat.lua`'s EMCO tab-color integration per that file's own
2026-08-24 addition), `setOverride`/`clearOverride`/`setTheme`/`list`/
`loadActive`/`saveActive` (2-4 each, all real, all from this file's own
alias bodies — confirmed no OTHER module calls the mutators directly,
which is correct: theme changes are meant to go through the `theme`
alias, not be triggered programmatically by a View module).

**Depends on:** nothing else in this codebase (by design, same as
`MyDSL_LayoutEngine.lua` — the other "owns its data, no cross-imports"
Layer-2 file). Soft-checks `MyDSL.Windows.registry` in the `theme
override` alias body (a guarded typo-warning, not a hard dependency).

**Called by:** nearly every Layer-3 View module (`styleConsole`/`get`/
`panelCSS`/`colorToCSS` are the most widely-shared functions in the
entire Layer-2/3 boundary).

**Candidate cruft:**
- **Real, confirmed dead table, same class of finding as `MyDSL_
  LayoutEngine.lua`'s dead handler slot above.** `MyDSL.Theme._handlers
  = MyDSL.Theme._handlers or {}` is declared at the top of the file
  (Section 1, the standard safe-reload scaffold every module uses) —
  but grep confirms nothing anywhere in this 572-line file ever writes
  into it (no `MyDSL.Theme._handlers.<name> = registerAnonymousEvent
  Handler(...)` exists) or reads from it beyond the declaration itself.
  This file doesn't register any event handlers at all — it's purely
  a data+accessor module, reacting to nothing, so the `_handlers` table
  was never actually needed. 3 lines of dead scaffolding, safe to
  remove.
- Beyond that specific table, nothing else looks unused this pass —
  the file reads as genuinely clean following its 2026-08-23 cleanup;
  every preset, every accessor, every alias traces to a real, still-
  live consumer.

**Performance flags:** none — this file does no polling, no per-tick
work, and every function only runs in response to an explicit `theme`
alias command or a `styleConsole()`/`get()` call made by some other
module's own event-driven render path (which is that OTHER module's
performance profile to account for, not this file's).
## 31. `MyDSL_AlterformView.lua`

**586 lines.** Small standalone countdown window for the "alterform"
affect, structurally mirroring `MyDSL_TickView.lua`'s panel/tube/fill
layout but sitting beside it as a matched pair with its own violet
accent.

**What it does:** renders a countdown widget (`F.render()`) driven
entirely by `MyDSL.Affects.getRemaining("alterform")` — owns no timing/
parsing of its own, reusing `MyDSL_AffectsView.lua`'s existing tick-
average-based duration math. Three visual zones (ready/warn/danger)
via `F.palette()`, a matching warning/danger sound at the same
thresholds (`F.checkSoundWarning()`, fires once per zone transition,
not per render), auto-hide when the affect isn't active, and the usual
show/hide/toggle/rebuild/font/title/sound aliases under `mydsl
alterform <verb>`.

**Public surface:** `F.render()/show()/hide()/toggle()/rebuild()/
setFont()/setSoundEnabled()/setTitle()/status()`. Confirmed via grep:
**zero external callers of any `MyDSL.AlterformView.*` function** —
every real reference outside this file is either a `WINDOW_INITIAL_
DOCK`/`DEFAULT_REGISTRY`/theme/layout config entry keyed by the window
name `"MyDSL_Alterform"` (data, not a function call) or `test/
test_alterform_sound_warning.lua`. This is the expected, correct
pattern for a self-contained View module (same as every DataLayer
domain's parse functions) — not cruft.

**Depends on:** `MyDSL.Affects.getRemaining()` (defined in `MyDSL_
AffectsView.lua` — a real View-to-View dependency, not a DataLayer
read; confirmed via grep this is the ONLY other module besides
AffectsView itself calling this function), `MyDSL.Theme`/`MyDSL.Layout`/
`MyDSL.Windows` (all soft, defensively checked), `Adjustable.Container`
directly (bypasses `MyDSL.Windows.ensure()` for its own window creation,
same pattern as `MyDSL_MoonWeather.lua`, with a `MyDSL.Windows.registry`
fallback if the direct construction fails).

**Called by:** nothing calls into this module — it's a leaf display
node. `MyDSL_WindowRegistry.lua`'s `characterIdentified`/`themeChanged`
handlers iterate the registry and would call `show()/hide()`/apply
theme CSS on whatever object is registered under `MyDSL_Alterform`, and
this file's own `F.ensureUI()` does register the real object into
`MyDSL.Windows.registry[F.name].obj` (a documented 2026-07-12 bug fix,
comment still present in source) — so unlike `MyDSL_PortraitView.lua`
(see section 33), this module's registry integration is real and
correctly wired, not orphaned.

**Candidate cruft:** none found — every function has a real trigger
(alias or event handler), and the two historical Adjustable.Container
lock/title bugs documented in the file's own comments (padding lockStyle
silently no-op'ing; `lockContainer("light")` disabling resize, not just
hiding chrome) are both fixed in the current source, confirmed by
reading the actual `F.ensureUI()`/`F.boot()` code, not just trusting
the comment.

**Performance flags:** `F.render()` is driven by `MyDSL.Timers.Slow`
(the shared 1Hz heartbeat from `MyDSL_TickSource.lua`), not its own
timer — correct, lightweight pattern, consistent with the rest of the
codebase. `F.checkSoundWarning()` correctly fires only on a zone
*transition*, not on every render call, avoiding a real "sound spam
every tick while in the danger zone" bug that a naive implementation
would have. No concerns.

---

## 32. `MyDSL_WindowRegistry.lua`

**938 lines.** Layer 2, file 3 of 3 — the central window-lifecycle
manager virtually every View module depends on. Must load after
`MyDSL_ThemeEngine.lua`/`MyDSL_LayoutEngine.lua`.

**What it does:** owns the single registry of all windows (`MyDSL.
Windows.registry`, 19 entries — see Candidate cruft, the file's own
header/comments say "20" in two places, both stale), lazy on-demand
window creation (`ensure()`), show/hide/toggle, visibility-state
persistence (character-bound, `MyDSL_windowstate_<Char>.lua`), the
one-time-per-profile initial dock-side assignment (`WINDOW_INITIAL_
DOCK`, the 2026-08-24 fix for the "fresh profile piles every window on
the right" bug), profile-level (not character-bound) font-size and
title-visibility persistence (`MyDSL_windowfonts.lua`/`MyDSL_titles_
visible.lua`), the shared `enableAdaptiveWrap()` helper (extracted
2026-07-18 after 3 View modules each hand-copied the same buggy
pattern), and a `Geyser.UserWindow.new` constructor patch that forces
`restoreLayout=true`/`autoDock=true` onto every window any module
creates.

**Public surface** (confirmed via grep — real external callers only):
`MyDSL.Windows.get()/ensure()/ensureAll()/show()/hide()/toggle()/
saveState()/loadState()` are called from **17 different `MyDSL_*.lua`
files** (`MyDSL_TickView`, `MyDSL_PortraitView`, `MyDSL_ScanView`,
`MyDSL_ItemReference`, `MyDSL_GroupView`, `MyDSL_AffectsView`, `MyDSL_
LocationView`, `MyDSL_ThemeEngine`, `MyDSL_Leveling`, `MyDSL_
CombatView`, `MyDSL_CreatureReference`, `MyDSL_AlterformView`, `MyDSL_
RouteHelper`, `MyDSL_Chat`, `MyDSL_TargetView`, `MyDSL_Help`, `MyDSL_
MoonWeather`) plus `MyDSL_DataLayer.lua` itself (a real, harmless status-
readout that counts `MyDSL.Windows.registry` entries for a diagnostic
command — reads the registry table directly, doesn't call any
function). `MyDSL.Windows.getFontSize()/setFontSize()/
enableAdaptiveWrap()` are the other widely-used entry points (font
persistence, confirmed called from multiple View modules). This is
genuinely the single most depended-upon Layer-2/3 file after `MyDSL_
DataLayer.lua` itself.

**Depends on:** `MyDSL_ThemeEngine.lua` (`MyDSL.Theme.panelCSS`, must
load first per this file's own header), `MyDSL_LayoutEngine.lua`
(`MyDSL.Layout.get()`, must load second), `Geyser`/`Adjustable.
Container` directly.

**Called by:** effectively every View module in the codebase — see
Public surface. `MyDSL_PortraitView.lua` is the one confirmed exception
that thinks it's calling in but isn't landing correctly — see section
33's own writeup for the real cross-file bug this surfaced.

**Candidate cruft:**
- **Stale window count in two places.** The file's own top-of-file
  comment says "creates and tracks all 20 UI windows," and the final
  `debugc()` load-confirmation line computes `table.getn and table.
  getn(MyDSL.Windows.registry) or 20` — `table.getn` was removed from
  Lua entirely at 5.1 (this project runs on LuaJIT), so `table.getn`
  is always `nil`, the `and` short-circuits, and this line **always
  prints the hardcoded fallback "20 windows registered," never the
  real count**, regardless of how many are actually registered.
  Confirmed via grep: `DEFAULT_REGISTRY` has 19 real entries, not 20 —
  both the header comment and this debug line are stale (predate
  whichever window was added/removed last) and the debug line's own
  intended "count them for real" logic has been silently dead code
  since it was written (any Lua 5.1+/LuaJIT runtime, which is this
  entire project). Harmless — it's a debug-console cosmetic line, not
  logic — but a good one-line fix (`local n=0 for _ in pairs(...) do
  n=n+1 end` — the exact pattern already used identically for the
  `WindowRegistry: font sizes loaded... (N windows)` line right above
  it in the same file) and a good example of exactly the kind of
  cross-check-for-real-behavior gap this audit is looking for.

**Performance flags:**
- The initial-dock-side logic (`WINDOW_INITIAL_DOCK`) is correctly
  gated by the one-time `isFirstDockInit()` marker-file check, cached
  in `MyDSL.Windows._applyInitialDock` after the first read so it's
  not a disk read per window creation (confirmed by reading the actual
  `ensure()` code: the disk check only happens once per session, the
  cached boolean is reused for every subsequent window). No concern —
  this is exactly the guarded, run-once-per-profile behavior the
  header comment claims.
- `saveState()`/`saveFontSizes()` are called synchronously, but only
  from explicit user actions (show/hide/toggle a window, set a font
  size) — not from any hot-path event. No debounce needed here the way
  `MyDSL_DataLayer.lua`'s `MyDSL.save()` needed one (that one fires on
  every affect change during combat; this one fires on a deliberate,
  infrequent user action).
- No other performance concerns — `ensureAll()` runs once at startup
  (O(19), not a hot path), and the theme-changed/character-identified
  handlers only re-touch windows that already exist.

---

## 33. `MyDSL_PortraitView.lua`

**1,013 lines.** Character portrait window (`mydsl portrait <verb>` /
legacy `charpic <verb>` compatibility aliases), ported from an older
standalone "CharPic" script.

**What it does:** resolves a per-character portrait image path (either
a manually-configured override in its own `portrait_profiles.lua`, or
an automatic `<CharacterName>.png` lookup in a configurable directory),
renders it into a window with a choice of fit modes (stretch/contain/
cover — `stretch` is the current real default per a 2026-07-12 Steven
preference), and a full CharPic-compatible alias/global-function
surface for backward compatibility.

**Public surface:** `MyDSL.Portrait.refresh()/show()/hide()/setPath()/
setDir()/setFit()/setFont()/setTitle()/setMissing()/probe()/dump()/
status()`, plus a global `CharPic.*` compatibility table wrapping the
same functions. Confirmed via grep: **zero external callers of any
`MyDSL.Portrait.*` or `CharPic.*` function from any other `MyDSL_*.lua`
file** — every real reference outside this file is a config entry
keyed by the window name `"MyDSL_Portrait"` (`MyDSL_LayoutEngine.lua`'s
position, `MyDSL_ThemeEngine.lua`'s color preset, `MyDSL_WindowRegistry
.lua`'s registry/dock-side entry, `MyDSL_Help.lua`'s help-text link),
never a real function call. This module is entirely self-contained,
driven only by its own aliases and GMCP event handlers.

**Depends on:** `MyDSL.Theme` (soft, for border/background CSS),
`MyDSL.Windows` — **but see the real bug below, this dependency doesn't
actually work the way it looks like it should.**

**Called by:** nothing — see Public surface.

**Candidate cruft — a real, confirmed cross-file connection bug, exactly
the class of thing this audit was asked to find:**
- **`P.getWindowEntry()` (line 471-476) reads `MyDSL.Windows.windows[...]`
  — a table that has never existed.** Confirmed via grep across `MyDSL_
  WindowRegistry.lua`: the real, only table it ever exposes is `MyDSL.
  Windows.registry`, never `MyDSL.Windows.windows`. This means `P.
  getWindowObject()` (which calls `getWindowEntry()` first) **always**
  falls through to its final fallback (`return P.window`, which is
  `nil` on first call) — so even though `P.ensureWindow()` genuinely
  does call `MyDSL.Windows.ensure("MyDSL_Portrait")` (which creates and
  registers a real `Geyser.UserWindow` in the central registry), this
  file never actually picks up that object. Instead, `P.ensureWindow()`
  falls through to its own manual `Geyser.UserWindow:new({name =
  "MyDSL_Portrait", ...})` fallback path — **creating a second,
  independent window object under the exact same name.** Practical
  effect: `MyDSL_WindowRegistry.lua`'s registry entry for
  `"MyDSL_Portrait"` holds a real but orphaned window object that
  nothing shows/positions/themes correctly relative to the one the
  player actually sees, while the theme-changed/character-identified/
  dock-side logic in `MyDSL_WindowRegistry.lua` (which iterates the
  registry and calls `show()`/`hide()`/`applyTheme()` on
  `entry.obj`) is silently operating on the wrong object — it would
  have zero visible effect on the real, displayed portrait window.
  Confirmed via grep this is not a naming inconsistency that resolved
  itself some other way: no file anywhere in the repo ever defines
  `MyDSL.Windows.windows`. This single-word field-name mismatch (
  `windows` vs `registry`) appears to be the reason `MyDSL_Portrait`'s
  entry in `WINDOW_INITIAL_DOCK`/theme presets/layout positions may
  never actually be reaching the visible window — worth Steven
  confirming live whether portrait theme/dock/layout changes visibly
  apply (if they silently don't, this bug is the reason).

**Performance flags:** `P.installEvents()` registers on `gmcp.
char_data`/`gmcp.login_data` with a `tempTimer(0.15, ...)` debounce
before refreshing — reasonable, not a hot-path concern (portrait
refresh is cheap: one file-exists check, one image render). No new
concerns beyond the connection bug above.

---

## 34. `MyDSL_Leveling.lua`

**1,031 lines.** Separate outside addon (not part of `MyDSL_Full.
mpackage`, confirmed via grep: no `dofile()` entry for it anywhere in
`build_mydsl_package.py`'s output or `current/*.xml` — it's wired in
manually, per its own header). The one module in this codebase with an
explicit, narrow, Steven-granted exception to send real automatic game
commands (movement + `kill`/`order all kill` + `drop <n> silver` +
optional buff-reapply).

**What it does:** auto-navigates known hunting areas (`map.speedwalk()`
when a room ID is cached, falling back to a raw direction-list replay
otherwise) and auto-engages enabled mobs recognized from `MyDSL_
DataLayer.lua`'s own room-scan capture (reused directly — "no duplicate
trigger chain," confirmed via grep: this file registers zero of its
own room-content triggers, only `MyDSL.on("scan", ...)`). Session
control is deliberately minimal (start/pause/resume/stop, no fallback
timer — removed entirely per an explicit 2026-07-20 Steven decision),
with an HP%-threshold safety net as the one remaining automatic stop
condition. Area/mob data is user-editable and separately seedable from
a community forum-sourced data file.

**Public surface:** `MyDSL.Leveling.startArea()/pause()/resume()/
stop()/status()/tryKill()/processStep()/listAreas()/areaInfo()/
scanMobs()/newArea()/deleteArea()/setMobEnabled()/importSeedAreas()`,
all dispatched through one alias (`mydsl leveling <verb>`) rather than
called directly by other modules. Confirmed via grep: **zero external
callers of any `MyDSL.Leveling.*` function** — the only other file
mentioning `MyDSL.Leveling` at all is its own seed data file (`MyDSL/
leveling_areas_seed.lua`, a data reference, not a call). This matches
the file's own documented "separate outside addon" design — not cruft.

**Depends on:** `MyDSL_DataLayer.lua` (`MyDSL.on("scan", ...)`/
`MyDSL.on("char", ...)` — the two real consumers of the whole-codebase's
otherwise-rarely-used `MyDSL.on()` API, see section 1's own finding
that `MyDSL.on()` has exactly one real consumer — this file confirms
that consumer is Leveling, twice over), guarded by its own `
onceDataLayerReady()` retry-poll wrapper (a real 2026-07-21 bug fix —
a load-order race could otherwise abort this file's entire
initialization with a Lua error). Also soft-depends on `MyDSL.Target.
set()` (`MyDSL_TargetView.lua`), `_G.map`/`_G.getPath` (the
`DSL_Generic_Mapper.xml` fork's `speedwalk()`/pathfinding), `MyDSL.
CreatureLore.knownState()` (soft, for danger-level display in `area
info`).

**Called by:** nothing — a leaf addon, entirely alias-driven.

**Candidate cruft:** none found — every function traces to a real
alias dispatch or event handler, and the file's own extensive comment
history shows a real pattern of live bugs found and fixed (load-order
crash, seed-file path resolution, aura-tag mob-matching mismatch,
Focus/TargetView never being told what's being fought) rather than
speculative/unused code.

**Performance flags — special attention was requested here since this
module actually sends autonomous game commands, unlike every passive-
observation module elsewhere in this codebase:**
- **No polling loop of any kind, confirmed by reading every trigger/
  handler in the file.** All control flow is event-driven: the
  `xpGain`/`fleeCombat`/`killStolen`/`cannotMove`/`tooHeavy`/buff-
  wearoff triggers all fire only on specific real game text, and the
  `MyDSL.on("scan"/"char", ...)` listeners fire only on real upstream
  DataLayer events. The only two `tempTimer()` calls in the whole file
  (`cannotMove`'s 2s retry, `tooHeavy`'s 2s retry-after-drop) are both
  genuine one-shot delays for a specific interruption, not a
  recurring loop — confirmed neither re-schedules itself. This is
  exactly the well-behaved pattern the "special attention" ask was
  checking for; nothing to flag.
- `L.tryKill()`/`L.processStep()` are called once per real game event
  (XP gain, room-scan completion), not on any fixed interval — the
  pacing is entirely server-driven, which is the correct design for a
  module that sends real commands (it can never get ahead of what the
  server has actually confirmed).
- No new performance concerns.
## 35. `MyDSL_MoonWeather.lua`

**1,062 lines.** Layer-3 passive display: moon phase (3-moon HUD with
focal-moon selection by alignment), weather description, and a live
interpolated game-time clock.

**What it does:** `MW.render()` builds one HTML table (moon circles +
focal phase/bonus text + day/night/clock/date row) and echoes it to a
single `Geyser.Label`. Live clock (`MW.clockStr()`) interpolates DSL
time forward in real-time between `time`/tick anchors using
`MyDSL.DB.tick.average` (TickSource's smoothed tick length) rather than
a fixed constant. Lunar countdown (`MW.cyclesNow()`/`countdownStr()`)
similarly interpolates cycles-remaining between real `lunar` command
parses. Weather line (`buildWeatherText()`) derives an icon+label+wind
summary from `MyDSL.State.weather.description`/`windDescription`
(`MyDSL_DataLayer_PromptVitals.lua`'s capture). Optional gag triggers
suppress the raw `lunar` output on the main console (default off).

**Public surface:** `MW.show()/hide()/toggle()/render()/setGag()`, all
wired only to this file's own `mydsl moon <verb>` aliases (`toggle`,
`on`, `off`, `font <n>`, `gag`, `ungag`) plus a PNP-vocabulary `toggle
moons` alias. Confirmed via grep: **zero external callers of any
`MyDSL.MoonWeather.*` function** — `MyDSL_Help.lua` only references it
in help text, not code. Fully self-contained.

**Depends on:** `MyDSL.State.lunar/weather/time/score` (read directly,
bypassing the Get/Set API, same pattern as the 12 modules section 1
already flagged), `MyDSL.DB.tick` (TickSource), `MyDSL.Theme.get()`
(background color), `MyDSL.Layout.get()` (initial position), `MyDSL.
Windows` (show/hide/toggle delegation — a 2026-07-11 fix that removed
this file's own independently-tracked visibility flag in favor of
WindowRegistry as sole source of truth).

**Called by:** nothing external calls into this module — it is a pure
leaf display node (real trigger registrations + its own aliases only).

**Candidate cruft:** none found — the file's own header even documents
a prior real dead-code removal (5 named event-handler functions
deleted 2026-07-07 after `_registerHandlers()` was refactored to use
inline closures instead, confirmed via grep at the time). Nothing new
found this pass.

**Performance flags:**
- **Genuinely well-optimized, two real applied fixes worth citing as
  positive examples**: (1) `MW.render()` early-returns if the built
  HTML string is byte-identical to the last echoed one (`MW._lastHtml`
  comparison) — added 2026-07-12 specifically because re-echoing
  unchanged HTML every second was forcing Qt to reload the `<img>` moon
  tiles from disk every second for zero visible change. (2) The live
  clock/lunar countdown ride `MyDSL.Timers.Slow` (TickSource's shared
  1Hz heartbeat, see section 8) instead of running an independent
  `tempTimer` self-reschedule chain — the file's own comment confirms
  this was audited and is "the only other self-perpetuating timer loop
  anywhere in the profile besides TickSource's own" before the
  consolidation, now removed. Both are real, already-shipped fixes,
  not just design intentions — confirmed current in this source.
- No new performance issues found.

---

## 36. `MyDSL_AffectsView.lua`

**1,275 lines.** Layer-3 display + light Layer-4 profile persistence:
active/tracked buff-and-debuff window with GMCP-driven live tracking,
text-parse fallback capture, per-character spell-command profiles, and
clickable recast links.

**What it does:** `A.list`/`A.tracked` hold active/watched affects.
GMCP-first capture (`A.onGmcpEvent()`/`gmcpAdd()`/`gmcpRemove()`/
`syncGmcpFull()`) is primary; a text-parse fallback
(`startCapture()`/`captureSpellLine()`/`finishCapture()`) exists for
when GMCP is unavailable — both paths documented and both gated by
`A.config.useGmcp`/`useTextFallback`. `A.getRemaining(name)` is a
public read-only API (same shape as `MyDSL.getTargetCondition()`, per
its own comment) other modules use to ask "how much time is left on
X." `A.recast()`/`respell()`/`spellup()` build and send cast-command
sequences (per-affect custom commands stored via `A.setCommand()`).
`A.applyLinks()` wires clickable "recast" hyperlinks onto rendered
affect names. Per-character profile persistence
(`A.save()`/`loadData()`/`loadProfileForCurrentChar()`) is separate
from `MyDSL_DataLayer.lua`'s own `MyDSL.save()` — its own dedicated
data file, not the same mechanism (see section 1's flagged ambiguity
about which `MyDSL.save()`-shaped callers mean *that* file's function —
this one confirms it's a distinct, self-contained save, not a call
into DataLayer's).

**Public surface:** `A.getRemaining(name)` — confirmed real external
caller: `MyDSL_AlterformView.lua` calls it twice (`getRemaining
("alterform")`) plus reads `A.config.lowCycles` directly. Every other
`A.*` function (`show/hide/toggle/track/untrack/recast/respell/
spellup/setCommand/...`) is called only from this file's own ~35
`mydsl affects <verb>` aliases (plus 2 bare PNP-vocabulary aliases,
`respell`/`spellup`) — confirmed via grep, no other module calls them.

**Depends on:** `MyDSL.Windows` (show/hide), `MyDSL.Theme` (colors),
raw `gmcp.affect_data`/`add_affect`/`remove_affect`/`char_data`/
`login_data`, `MyDSL.Timers.Slow`/`MyDSL.Tick.Updated` (TickSource).

**Called by:** `MyDSL_AlterformView.lua` (`getRemaining`, `config.
lowCycles`) — a real, confirmed, intentional cross-View dependency
(Alterform reuses Affects' own countdown data instead of re-tracking
its own affect separately).

**Candidate cruft:** none found this pass.

**Performance flags:**
- **Already carries 2 real, documented 2026-07-11/07-12 perf fixes,
  same class as `MyDSL_TickSource.lua`'s throttling story**: `A.
  onTimersUpdated()` switched from the 0.25s `MyDSL.Timers.Updated`
  event to the 1Hz `MyDSL.Timers.Slow` event, AND was further narrowed
  to only actually call `A.display()` (described in this file's own
  comment as "a full window clear+redraw plus an up-to-300-line link-
  rescan") when `timerMode` is `"time"`/`"both"` — the default
  `"cycles"` mode no longer redraws on the 1Hz tick at all, since its
  displayed text doesn't change that often. Both fixes confirmed
  current in this source.
- **Worth confirming, not yet confirmed either way**: `A.
  registerHandlers()` registers `onGmcpEvent` on SIX separate event
  names for what may be overlapping underlying signals —
  `gmcp.affect_data`, `gmcp.affect_data.affects`, `gmcp.add_affect`,
  `gmcp.remove_affect`, and the bare (no `gmcp.` prefix) `add_affect`/
  `remove_affect`. Unlike section 9's DataBridge finding, this audit
  did NOT trace whether Mudlet/DSL's GMCP dispatch actually raises both
  the `gmcp.`-prefixed and bare forms for the same real packet (that
  would require deeper Mudlet-source tracing than this pass covered) —
  flagging as a "confirm before assuming either way" item rather than
  a confirmed double-fire, since the six-registration pattern here
  looks the same shape as the confirmed DataBridge bug but wasn't
  independently verified to actually double-fire.
- `A.onTickUpdated()` already guards against `MyDSL.Tick.Updated`'s own
  known over-firing (raised on every 0.25s internal timer tick, not
  just real game ticks) by comparing `MyDSL.DB.tick.ticks` before
  decrementing — a real, correct fix, not a gap.

---

## 37. `MyDSL_LocationView.lua`

**1,278 lines.** Layer-3 dockable room-picture window, room-ID-keyed
(not name-keyed, since DSL has many duplicate room names) picture
assignment with a manual-mapping profile file.

**What it does:** `M.roomData()` resolves the current room via the
Mudlet mapper's own room ID (`mapperRoomId()`/`mapperAreaName()`) plus
GMCP, then `M.pathForRoomId()` resolves that room ID to an assigned
picture file (exact-mapping profile → filename convention → legacy
fallback → "conflict"/"no picture" states). `M.render()` sets the
image (3 fit modes: cover/contain/stretch, each with its own
documented historical Mudlet-rendering-quirk fix) and caption label.

**Public surface:** `M.mapRoom()/unmapRoom()/listMaps()/probe()/
status()/info()/setImage()/setDir()/setFit()/setMissing()/setTitle()/
rebuild()`, all wired only to this file's own `mydsl location <verb>`/
`mydsl loc`/`roompic`/`locpic` aliases. Confirmed via grep: **`MyDSL_
LiveView.lua` calls `MyDSL.Location.roomData()` directly** (line 16
comment + line 289-290, wrapped in `pcall`) — a real, deliberate
cross-View reuse (LiveView asks LocationView for its already-resolved
room data instead of re-deriving mapper/GMCP room info itself). No
other external callers found.

**Depends on:** Mudlet's mapper API (`getRoomArea`/room-ID resolution),
raw `gmcp.room_data` directly (not `MyDSL.State.room`), `MyDSL.Theme`
(colors), `MyDSL.Windows`.

**Called by:** `MyDSL_LiveView.lua` (`roomData()`, confirmed real,
guarded with `pcall`).

**Candidate cruft:** `M.h2 = registerAnonymousEventHandler("gmcp.Room.
Info", ...)` — `gmcp.Room.Info` is the generic-MUD-client GMCP
convention; this whole project's own established finding (confirmed
repeatedly elsewhere, e.g. `MyDSL_LiveView.lua`'s own registration list
below) is that DSL always uses the lowercase `gmcp.room_data` form
instead, so this specific handler registration is very likely dead
weight — harmless (never fires) but worth removing for clarity, same
class of finding as `MyDSL_LiveView.lua`'s own self-documented dead
capitalized-event registrations below.

**Performance flags:**
- **Confirmed real double-fire, same class as section 9's `MyDSL_
  DataBridge.lua` finding.** `M.installEvents()` registers `M.
  onRoomData()` (→ unconditionally calls `M.refresh()`) on BOTH the raw
  `gmcp.room_data` event AND the mapper's own `onNewRoom` event — both
  of which fire for the same real "you entered a new room" moment
  (`onNewRoom` is raised by `DSL_Generic_Mapper.xml`'s "English Exits
  Trigger," itself triggered by the same room's `[Exits: ...]` line
  that accompanies the same `gmcp.room_data` packet). Traced `M.
  refresh()` → `M.render()` directly: **neither has an unchanged-room
  early return** — every call re-resolves the room-ID→picture mapping
  and unconditionally re-sets the image stylesheet + re-echoes the
  image HTML, which for the `contain`/`stretch` fit modes includes a
  real `getImageSize()`/`get_width()`/`get_height()` image I/O call
  (per `containImageHTML()`'s own comment). So every single room
  entered pays for this full image-resolve-and-redraw pipeline twice,
  not once. Smaller blast radius than DataBridge's finding (fires once
  per room change, not once per combat round), but the same root cause
  (raw GMCP event + a same-moment re-raised/derived event both wired to
  the same expensive handler) and a real, fixable render-doubling bug
  worth fixing alongside it.
- No other performance concerns found — `roomData()`/`pathForRoomId()`
  themselves are simple lookups, no loops over unbounded collections.

---

## 38. `MyDSL_LiveView.lua`

**1,326 lines.** The largest single-window Layer-3 display: HUD-style
vitals (HP/mana/move bars), room title/terrain/exits, identity/
personal-info rows, and the Improve skill-progress bar.

**What it does:** `L.render(reason)` rebuilds every bar/label on the
window in one pass (title, terrain badge, colored exits line —
deferring to `MyDSL.DB.room.exitsColoredSource` when a fresher
same-color capture already exists — HP/mana/move bars, Improve bar
with a live-interpolated countdown via `improveLiveText()`, identity
row). `L.setColoredExitsFromCurrentLine()` is a dedicated trigger-fed
capture that preserves the game's own original exit-line coloring
(the room-color-vs-white-text bug documented in section 9's `MyDSL_
DataBridge.lua` entry was fixed on the DataBridge side; this file owns
the actual color-preserving capture DataBridge's fields protect).

**Public surface:** `L.show()/hide()/rebuild()/render()/setFont()/
setTitleFont()/setBarFont()/setInfoFont()/setTerrainFont()/setTitle()/
saveSettings()/loadSettings()`, all wired only to this file's own
`mydsl live <verb>` aliases. Confirmed via grep: **zero external
callers of any `MyDSL.LiveView.*` function.**

**Depends on:** `MyDSL.State.*` (multiple sections, read directly),
`MyDSL.DB.*` (the DataBridge-translated shape — this is DataBridge's
primary real consumer alongside `MyDSL_TickView.lua`, confirmed in
section 9), `MyDSL.Location.roomData()` (confirmed real cross-View
call, see section 37), `MyDSL.Timers.Slow` (TickSource).

**Called by:** nothing external — pure leaf display node.

**Candidate cruft — real, confirmed dead event registrations, found by
cross-referencing this file's own comment against `MyDSL_DataLayer.lua`'s
actual `MyDSL.emit()` behavior:** `L.installHandlers()` registers `L.
render()` on 10 events, and this file's OWN comment at the "MyDSL.
improve.updated" entry states plainly: *"MyDSL.emit() lowercases the
section name — the capitalized 'MyDSL.Improve.Updated' above has never
matched anything DataLayer raises... kept rather than removed in case
some other still-registered listener depends on it, but this is the
one that actually fires."* That same reasoning applies to the other 3
capitalized entries in the same list — `"MyDSL.Live.Updated"`,
`"MyDSL.Status.Updated"`, `"MyDSL.Score.Updated"`, `"MyDSL.Time.
Updated"` — none of which match DataLayer's real lowercase `"MyDSL.
<section>.updated"` naming, and none of which have any other confirmed
raiser anywhere in the repo (grepped — zero `raiseEvent` call anywhere
uses any of these exact capitalized strings). Also `"MyDSL.Room.
Updated"` (capitalized) and `"gmcp.Room.Info"` (the same dead generic-
GMCP convention flagged in section 37) are in the same list. **Net: of
the 10 registered events, at least 6 (`Live.Updated`, `Status.Updated`,
`Score.Updated`, `Time.Updated`, `Room.Updated`, `gmcp.Room.Info`)
appear to be permanently dead registrations** — harmless (they just
never fire) but real cruft worth a cleanup pass, and worth double-
checking against `docs/DSL_CommandRef.md`/a fresh grep before deleting,
in case something non-obvious does still raise one of these.

**Performance flags:**
- **Correctly uses `MyDSL.Timers.Slow`** (1Hz, not 0.25s) for its
  periodic re-render, per its own comment citing the same 2026-07-11
  consolidation as sections 8/35/36 — confirmed no separate timer chain
  exists in this file.
- `L.render()` rebuilds every bar/label unconditionally on every call
  (no unchanged-skip like `MyDSL_MoonWeather.lua`'s `_lastHtml`
  comparison) — for the 4 real, live events (`gmcp.room_data`,
  `MyDSL.improve.updated`, `MyDSL.Timers.Slow`), this is bounded to at
  most 1/sec plus real room-change frequency, which is unlikely to be
  a genuine lag source on its own, but is the same "no early return"
  shape as `MyDSL_LocationView.lua`'s confirmed-costlier case (section
  37) — worth the same treatment (a cheap unchanged-data check) if this
  window is ever profiled as a contributor.

---

## 39. `MyDSL_TargetView.lua`

**1,389 lines.** The largest View module after `MyDSL_Chat.lua` —
`MyDSL.Target`/Focus: current-target tracking, nameplate + condition
bar + action buttons ([M]elee/[P]eek/clear), poison-onset flagging,
and cross-module target-set API used by Leveling/Group/Scan.

**CORRECTION to section 3's claim** (`MyDSL_DataLayer_Combat.lua`,
already written): section 3 states *"`MyDSL_TargetView.lua`/Focus **do
not** currently call `MyDSL.getTargetCondition()` (confirmed via
grep)"* — **this is incorrect, confirmed by a fresh grep in this
pass.** `MyDSL_TargetView.lua` calls `MyDSL.getTargetCondition(t.name)`
at two real, functional call sites: line 720-721 (populates the
nameplate's condition-percent badge, e.g. `[50-74%]`, next to the
target name) and line 1327-1328 (inside `MyDSL.Target.status()`'s
diagnostic dump, which explicitly cross-checks `getTargetCondition()`'s
output against the raw `MyDSL.State.combat.active[key]` entry). Both
are guarded (`if t and t.name and MyDSL.getTargetCondition then`) but
are real, live, functioning calls, not dead defensive code — the
percent badge genuinely renders from this data in normal play. Section
3's "built but not wired in" framing and its Candidate-cruft entry for
`getTargetCondition()` should be corrected in a follow-up pass; this
audit doc does not self-edit already-written sections, so flagging it
here for whoever reconciles the doc.

**What it does:** `MyDSL.Target.set(name, isMob, source)` is the real
public target-set API (confirmed callers below). Nameplate rendering
combines the target name, friend/enemy relation coloring
(`dslColorRelation()`), and the live condition percent badge above.
Poison-onset detection (`MyDSL.Target.markPoisoned()`, added
2026-08-24 this session, gated to only flag the CURRENT target) shows
a "Poisoned" line. Auto-clear/advance-on-death logic listens for
`MyDSL.combat.died` (added specifically so Leveling's kill-target
tracking gets Focus/TargetView population "for free," per `docs/
TODO.md`'s NEEDS LIVE CONFIRMATION item 10).

**Public surface:** `MyDSL.Target.set()` — confirmed real external
callers: `MyDSL_Leveling.lua` (calls `MyDSL.Target.set(mobDef.label,
true, "leveling")` when starting a kill, per the already-closed
`docs/TODO.md` item), `MyDSL_GroupView.lua`, `MyDSL_ScanView.lua` (all
confirmed via grep). This is a genuinely well-connected, actively-used
cross-module API — not a niche or unused one.

**Depends on:** `MyDSL.getTargetCondition()` (`MyDSL_DataLayer_
Combat.lua`, real — see correction above), `MyDSL.State.combat.active`
(read directly for the diagnostic dump), `MyDSL.Windows`, `MyDSL.
Theme`, `dslColorRelation()` (likely `DslColors_Core_v1_0`'s native
kingdom-color data — not independently confirmed this pass, flagging
for a future check rather than asserting).

**Called by:** `MyDSL_Leveling.lua`, `MyDSL_GroupView.lua`, `MyDSL_
ScanView.lua` (all call `MyDSL.Target.set()` — confirmed via grep,
genuinely the most cross-module-depended-on View module found in this
audit so far besides the DataLayer split itself).

**Candidate cruft:** none found — see the correction above; if
anything, this file demonstrates the getTargetCondition() connection
section 3 flagged as missing is actually real and working.

**Performance flags:**
- `TV._handlers.timersSlow` — confirmed registered on `MyDSL.Timers.
  Slow` (the correct 1Hz shared heartbeat, not a separate chain),
  consistent with the pattern established across sections 8/35/36/38.
- No unbounded loops or hot-path concerns found — nameplate/condition-
  bar rendering is triggered by real target-change/combat events, not
  a high-frequency poll.

---

## 40. `MyDSL_Chat.lua`

**3,345 lines — the largest file in the codebase.** Merged 2026-07-17
from two previously-separate files, per Steven ("do we need chat
wrapper? can it be all rolled into one chat?"). Splits cleanly into two
parts with very different audit treatment, the same distinction section
10 drew between `DSL_Generic_Mapper.xml`'s stock base package and its
DSL-specific fork layer:

- **Lines 1-2,404 (72% of the file): PART 1, the ported EMCO class.**
  Cannibalized nearly verbatim from EMCO 2.9.0 (Damian "demonnic"
  Monogue, MIT license, `github.com/demonnic/EMCO`,
  `src/resources/emco.lua`). Ownership framing updated 2026-08-25 to
  match `docs/MYDSL_1.0_PHILOSOPHY.md`'s Principle 1 — this is this
  project's own code now, same as everything else running in this
  profile, not a "third-party" carve-out. What's still true and worth
  keeping separate from the ownership question: this pass didn't
  scrutinize these lines line-by-line (same audit-scope note as the
  stock Generic Mapper package, section 10) — and per that same
  Principle 1, EMCO specifically is confirmed already fully absorbed
  (the vendored `EMCOChat/emco.lua` reference copy is dead, untouched
  since one old commit, never `dofile()`'d — see `docs/TODO.md`'s
  2026-08-25 entry), so unlike the mapper there's no further
  integration work outstanding here.
- **Lines 2,405-3,345 (941 lines): PART 2, chat window management**
  (originally `MyDSL_ChatWrapper.lua`) — this project's own code on top
  of the ported class. This is the real subject of this audit section.

**What it does:**
- PART 1 exposes the `EMCO` class (`MyDSL.EMCO`) — a tabbed,
  multi-console Geyser container with per-tab logging, gagging,
  notifications, timestamps, and OS-toast support. Two real changes
  from upstream (both marked inline): the `loggingconsole.lua`
  optional-require replaced with a plain `local LC = nil` (confirmed
  unused — every real call site already nil-guards it), and exposure as
  `MyDSL.EMCO` in addition to the original `return EMCO`.
- PART 2 (`MyDSL.Chat`, local alias `C`) creates and owns the single
  live chat window: `C.createInWindow()` builds one `EMCO` instance
  inside a `MyDSL_Chat` UserWindow with 6 fixed tabs (All/Local/City/
  OOC/Tells/Group), `C.install()` is the load-time entry point
  (settings load, aliases, window creation, one lightweight safety-net
  timer — see Performance flags), persistent per-character settings
  (font/wrap/timestamp, `chat_settings_<CharName>.lua`), a full ported
  `emco <verb>` alias vocabulary (`addtab`/`remtab`/`gag`/`ungag`/
  `gaglist`/`notify`/`unnotify`/`blink`/`blankLine`/`color`/`fontSize`/
  `timestamp`/`save`/`load`/`show`/`hide`/`title`) plus MyDSL's own
  `mydsl chat <verb>` vocabulary, a real ThemeEngine hookup
  (`buildTabTheme()`, re-applies live via `EMCO:adjustTabBackgrounds()`/
  `adjustTabNames()` on `"MyDSL.theme.changed"`), and a
  character-identification re-sync (`"MyDSL.character.identified"`)
  since `C.install()` runs at script-boot time, before login, and would
  otherwise load the wrong (or no) character's settings.

**Public surface** (PART 2 only — PART 1's `EMCO:*` methods are the
ported library's own public API, called only from within PART 2 in
this codebase):
- `MyDSL.Chat.emco` (the live instance) — the one real, load-bearing
  cross-file dependency. Confirmed via grep: `MyDSL_ChatTriggers.lua`
  calls `MyDSL.Chat.emco:append(tabName)` on every captured chat line
  (line 76-77 — the actual hot path this whole file exists to serve),
  and `MyDSL_DataLayer.lua`'s `mydsl log chat on|off` alias (line 211)
  calls `MyDSL.Chat.emco:enableAllLogging()`/`disableAllLogging()`
  directly. Both are real, confirmed call sites, not comment mentions.
- `MyDSL.EMCO` (the class itself) — **zero external callers**;
  confirmed via grep, only `MyDSL_Chat.lua` itself references it
  (`C._emcoClass = MyDSL.EMCO` inside `requireEMCO()`). Correct and
  expected — nothing else in this codebase builds its own EMCO
  instance.
- Every other `MyDSL.Chat.*` function (`status`/`show`/`hide`/`clear`/
  `setFont`/`setWrap`/`setTimestamp`/`addTab`/`remTab`/`addGag`/etc.) —
  confirmed via grep, **zero external callers besides this file's own
  aliases and `test/test_chat_theme_hookup.lua`**. All are real,
  reachable command endpoints, not dead — they just aren't called
  programmatically from other modules, which is correct for a
  user-facing settings API.

**Depends on:** `Geyser`/`Geyser.Container`/`Geyser.UserWindow` (Mudlet
built-ins). Soft dependency on `MyDSL.Windows` (`MyDSL_
WindowRegistry.lua`, checked via `haveWindowCore()` before use, with a
real bare-`Geyser.UserWindow` fallback path if absent — confirmed this
file genuinely still works standalone). Soft dependency on `MyDSL.
Theme`/`MyDSL.Theme.get`/`colorToCSS`/`colorToBracket` (`MyDSL_
ThemeEngine.lua`, via `buildTabTheme()`) with a real hardcoded-fallback
branch if ThemeEngine isn't loaded — confirmed both branches are live
code, not one being dead. Listens for `"MyDSL.character.identified"`
(raised by `MyDSL_DataLayer.lua:732`, confirmed via grep — the file's
own comment claim is accurate) and `"MyDSL.theme.changed"` (raised by
`MyDSL_ThemeEngine.lua`).

`docs/TODO.md` previously flagged this file as having **no `dofile()`
entry in DSL2's own Script Editor** — checked `current/2026-07-18#10-
13-31.xml` directly per this task's instructions: **that gap is now
fixed** (real `<name>MyDSL_Chat</name>` / `dofile(".../MyDSL_Chat.lua")`
entry exists, added earlier in this same audit session per `docs/
CHANGELOG.md`'s 2026-08-25 dofile-wiring-gap entry). Flagging here only
so this file's own section doesn't repeat a now-stale claim from an
older pass.

**Called by:** `MyDSL_ChatTriggers.lua` (`MyDSL.Chat.emco:append()` —
must load AFTER this file, confirmed by that file's own header
comment), `MyDSL_DataLayer.lua` (`mydsl log chat` toggle).

**Candidate cruft:**
- **Real dead-logic bug, not just cruft, in `C.createInWindow()`
  (lines 2686-2691):** `local old = C.emco` immediately followed by
  `if old and old ~= C.emco then` — since `old` was *just* assigned
  from `C.emco` on the previous line and nothing mutates `C.emco`
  in between, `old ~= C.emco` can never be true. `C.emco` is only
  reassigned later, at line 2749, well after this check. The intent
  was clearly to detect "an EMCO instance already existed before this
  rebuild" (setting `C.oldChat`/`C.state.replacedExisting = true`),
  but as written this branch is unreachable — confirmed via grep that
  `C.oldChat` and `replacedExisting` are never set to `true` anywhere
  else in the file, and `C.status()` (line 2972) prints
  `replacedExisting` as always `false`. Harmless in practice (it's
  diagnostic bookkeeping only, nothing branches on `C.oldChat`
  elsewhere), but it is a genuine logic bug worth fixing in pass 2 —
  the fix is capturing `old` *before* whatever would change `C.emco`,
  which today is never, since `createInWindow()` always builds a fresh
  object; the real check that was likely intended is just `if old
  then` (was there already a previous instance at all), not a
  self-comparison.
- **Stale error-message text**: `requireEMCO()`'s failure message
  reads "MyDSL.EMCO not found -- MyDSL_EMCO.lua must load before
  MyDSL_ChatWrapper.lua" — both filenames it names no longer exist;
  both were merged into this single file on 2026-07-17. Harmless
  (this branch can now only fire from a genuine internal error, not a
  load-order mistake, since there's only one file to load), but
  worth updating so a future error, if it ever fires, doesn't point
  someone at two files that don't exist.
- PART 1's ported EMCO class carries real generality this project
  never exercises (`mapTab`, `commandLine`, `loggingconsole`
  integration) — all correctly disabled at the config level
  (`mapTab = false`, `commandLine = false`, `LC = nil`) rather than
  left dangling, so this isn't dead code so much as inactive
  configuration of a general-purpose ported class. Confirmed no
  self-updater/GitHub-fetch code survived the port (grep for
  `github`/`http`/`installPackage`/`downloadFile` inside the class body
  returns only doc-comment links, no live network code) — the
  project's own standing rule ("kill their self-updater/maintenance
  mechanisms when porting") was followed correctly here.

**Performance flags:**
- **Chat is a real, sustained hot-path window** (potentially dozens of
  lines per minute during active chat use) but the append path is
  clean: `EMCO:append()`/`cecho()`/`echo()` all funnel through
  `xEcho()`, and buffer trimming is delegated to Mudlet's own native
  `window:setBufferSize(bufferSize, deleteLines)` call (`EMCO:
  setBufferSize()`, line 819) — **not** a hand-rolled Lua array with
  manual shifting the way `DSL_Generic_Mapper.xml`'s `line_buffer` used
  to be before its own 2026-07-19 fix (section 10). This is the
  correct approach and needed no fix, but worth noting explicitly as
  the positive comparison point section 10's fix implicitly sets up.
- `EMCO:append()`'s `table.contains(self.consoles, tabName)` and
  `EMCO:matchesGag()`'s loop over `self.gags` are both O(n) per call,
  but `n` is bounded by tab count (6, fixed) and however many gag
  patterns a user has added (typically a handful) — neither scales
  with message volume, so neither is a real concern regardless of how
  busy chat gets.
- `C.applyFont()`/`C.applyWrap()` iterate over `ch.mc`/`ch.consoles`/
  `ch.tabs` (all bounded by the same fixed 6-tab count) — only called
  from explicit user commands (`mydsl chat font <n>`, theme/settings
  reload), never per-line. Not a hot path.
- No evidence of redraw-more-often-than-data-changes: tab restyling on
  theme change is event-driven (`"MyDSL.theme.changed"`, fires only
  when the user actually switches themes) and calls EMCO's own
  incremental `adjustTabBackgrounds()`/`adjustTabNames()` rather than
  tearing down and recreating the whole window.
- No new performance issues found in this file's own code (PART 2). No
  duplicate GMCP/text parsing — this file doesn't parse any game text
  at all, only appends already-classified lines routed to it by
  `MyDSL_ChatTriggers.lua`.

---

## 41. `DSL_Generic_Mapper.xml` (stock, unmodified package code — ~5,666 of the file's 8,174 lines)

Scoped out of section 10 deliberately ("this pass didn't scrutinize these
lines line-by-line... planned as its own dedicated rewrite pass, not
started yet") — now in scope under Principle 1. Covers everything in the
file's single `<Script>` block ("Map Script") EXCEPT the already-audited
`map.dsl.*` fork layer (lines ~5667-6623, section 10), plus the native
alias vocabulary outside the already-covered "DSL Minimal Hardening"
group.

**What it does:** ~68 stock `map.*` functions — the standard Generic
Mapper 2.1.8 package: room/area/path scripting on Mudlet's native mapper
widget, map file load/save, coordinate math, symbol/color assignment,
door-state-aware path search (`getPath()`) and speedwalking (`map.
speedwalk()`), map-file sharing (upload/download via `map.load_map
(address)`). Wired to 67 `<Alias>` entries across 6 `<AliasGroup>`s
(Setup/Information/Regular Use/Map Creation/Map Sharing Aliases) using
the package's original command surface (`map ...`, `mmp ...`) — reused
as-is, same "don't reinvent the vocabulary" rule already applied to
PNP/EMCO.

**Public surface:** contrary to the assumption a first pass might make
(that stock package internals are only ever reached through their own
aliases), **`MyDSL_Leveling.lua` genuinely calls into this stock code**:
`_G.map.speedwalk(cachedRoomId)` (line 542, confirmed via grep — not a
comment), used as "an opportunistic same-session upgrade" once a cached
room ID resolves, per that file's own comments. This is a real, live
dependency from this project's own Lua onto the *stock* mapper package
(not just the `map.dsl.*` fork), worth recording since Principle 1's
reframing ("anything running in this profile is this project's own code
now") applies here concretely, not just in the abstract.

**Depends on:** Mudlet's native mapper widget/API (`getPath`,
`createMapper`, room/area DB) — same as documented for the fork layer in
section 10.

**Called by:** its own 67 aliases (internal); `MyDSL_Leveling.lua` →
`map.speedwalk()` (external, confirmed above).

**Candidate cruft:** the package's own self-update mechanism is present
but fully neutralized, not removed — worth recording explicitly since
it's exactly the kind of thing the project's standing rule ("kill their
self-updater/maintenance mechanisms when porting," already verified for
EMCO in section 40) exists to catch. Three call sites all short-circuit
through the same fork-provided guard: the `map update` alias's script
(line 555) checks `map.dsl.updateDisabled` first and returns before
reaching any real update logic; `map.checkVersion()` (line 4317) and
`map.updateVersion()` (line 4329) do the same. `map.dsl.updateDisabled()`
itself (fork layer, line 5714) clears any pending update timer, echoes
"Updater is disabled in the DSL fork," and returns `false` — a real,
working kill switch, not a dead comment. Separately, `map.load_map
(address)` (map-file download/import) is a distinct, legitimate
map-sharing feature reachable only through the explicit "Load Map Alias"
(`map load <address>`) — not the package's own self-update path, and not
something this pass is flagging as a concern.

**Performance flags:** none new — this pass didn't find evidence of the
stock code running unconditionally on every line (it's alias/command-
driven, not trigger-driven, except where it hooks the mapper's own
room-change events, already covered by section 10's fork-layer analysis
of the same hook points). A full line-by-line performance read of all
~68 functions was out of scope for this pass (matches the audit-scope
note section 10 and section 40 both already use for large ported/stock
code) — flagged here as still open if Steven wants that depth later,
same as those two sections flag it.

**Leak sweep:** clean — no credential/password/API-key/token-shaped
content anywhere in the file (grepped directly, not assumed).

---

## 42. `DslColors_Core_v1_0.xml`

**3,333 lines, 1 `<Script>` ("DslColors_Core_v1_0") + 1 `<TriggerGroup>`
with a single always-on `<Trigger>`.** Never previously audited — absent
from pass 1 entirely. Extracted verbatim from the live profile
2026-08-23, round-trip-verified against live source (0 mismatches).
Standalone: confirmed via grep it never references `MyDSL.*` itself, but
two `.lua` modules reach into it (see Called by).

**What it does:** colorizes race/class/organization/craft terms and
known people's names as they scroll by, using large static vocabulary
tables (`DSL_RACE_ALIASES` = 214 entries, `DSL_CLASS_ALIASES` = 358,
`DSL_ORG_ALIASES` = 170, `DSL_CRAFT_TERMS` = 61) plus a learned,
persisted per-player relationship/identity table (`dslColorSave()`/
`dslColorLoad()`, written to `getMudletHomeDir() .. "/DSL_
PeopleColors_data.lua"`). The single native `<Trigger>` ("DslColors v1.0
line processor") matches essentially every non-blank line
(`^(?!\s*$).+`) and calls `dslColorOnLine()` (script lines 2735-2763),
which runs the full term-scan pipeline unconditionally on every one of
those lines.

**Public surface:** `dslColorCommand()` (script lines 3166-3316) — the
`dslcolor <verb>` alias family (`show`/`combat show`/`echo on|off`/etc.).
`dslColorRelation(name)` — read externally (see Called by).

**Depends on:** its own static vocabulary tables and the persisted `DSL_
PeopleColors_data.lua` file only — no `MyDSL.*` dependency in either
direction from inside this file.

**Called by:** two real, confirmed external call sites reaching *into*
DslColors — this resolves section 39's own open question about `MyDSL_
TargetView.lua`'s `dslColorRelation()` ("worth confirming where this
actually reads from"): `MyDSL_TargetView.lua` (line 527,
`dslColorRelation(name)` reads `_G.DSL_COLOR_DB.relations.people`, used
at line 730 to color a target's relation) and `MyDSL_DataLayer.lua`
(line 243, `pcall(function() dslColorCommand("show " .. name) end)`).
`MyDSL_PersonalAliases.xml`'s `(whobe)` alias also calls in
(`expandAlias("dslcolor show person " .. name, false)`, section 44) — a
third confirmed caller, found during this same pass.

**Candidate cruft:** none found in the sense of dead code — every table
and function traces to the single trigger or the alias family. The
stale `colors.xml` file at the repo root (153,595 bytes, pre-v1.0
snapshot per this file's own header comment) is a separate,
already-flagged non-issue — zero references to anything in this file.

**Performance flags — the real finding of this section:**
- `dslColorOnLine()` has **no `enabled`/toggle check anywhere in its
  body** — it runs its full pipeline on every single non-blank incoming
  line, unconditionally, for the life of the session. The only on/off
  surface anywhere in `dslColorCommand()`'s dispatch table is `echo
  on/off` (a notification-verbosity setting, not a master switch) —
  there is no way to fully disable this engine short of removing the
  native trigger by hand. This is a direct **Principle 2 violation**
  ("Toggleable By Default — every feature needs independent on/off, even
  former native content") and, separately, a real per-line performance
  cost: `dslColorAnyTermTable()`/`dslColorAllRaceTermsOnLine()`/
  `dslColorAllClassTermsOnLine()`/`dslColorAllCraftTermsOnLine()`
  (script lines 2194-2247) each do an O(n) scan of their respective term
  table against the current line, and the shared substring-match helper
  `dslBoundedFind()` (lines 1799-1812) calls `string.lower(line)`
  **fresh on every single term comparison** rather than lowercasing the
  line once per call — a real, avoidable recomputation given
  214+358+170+61 = 803 total terms scanned per line.
- No leak risk in the persisted data: `DSL_PeopleColors_data.lua` is
  correctly covered by `.gitignore`'s `DSL_PeopleColors_data*` entry
  (exact path match confirmed).

---

## 43. `MyDSL_GameplayTriggers.xml`

**8,174 lines — the largest of the four native files, and the one with
the most individually significant findings.** 277 `<Trigger>` across 83
`<TriggerGroup>`s, 45 `<Key>` across 14 `<KeyGroup>`s. Never previously
audited. Extracted verbatim 2026-08-23, confirmed to include both the
trigger and the keybind content in one file.

**What it does:** the native (non-`.lua`) half of gameplay automation
and feedback — death-scan/sound cues, prompt-line gagging, buff/spellup-
loop assist triggers, combat sound effects and notifications,
area-specific broadcast/toast captures, and the full movement/action
keybind set (Movement, Open/Close/Unlock Doors, Directions NumPad,
Scan/Where/Affects/Up/Down/Look/Exits), largely under a `MyDSL_Full`-
tagged Key hierarchy. Broad category structure: standalone triggers
(Welcome, Gag-prompt-line1/2, is-DEAD!!-Scan, The-corpse-of-a) plus two
large trees ("Areas" and "Actions") with Skills/Spells/Combat/Combat
Sounds/Broadcasts/Notifications/Toasts-History-Captures/Blood-Bath-
Notifications/Trumpet-Sounds-and-History subgroups.

**Public surface:** `MyDSL.Route.history()` — called from native trigger
scripts 83 times (`grep -c`), resolving section 20's/the pass-1 wrap-up's
open item #9 the other direction: **`MyDSL_History` is not dead
weight** — `MyDSL.Route.history()` has 83 real native callers, so the
window this population function feeds has, in fact, been receiving text
all along; the earlier "zero callers" read only searched `.lua` files.
`MyDSL.MoveSound.go()` (10 native callers) and `MyDSL.Route.to()` (2)
are the same pattern at smaller scale.

**Depends on:** `playSoundFile()` (native, many triggers), `deleteLine()`
(native, prompt-gag triggers), `send()`/`expandAlias()` (native), plus
the three `MyDSL.*` call sites above.

**Called by:** n/a (native content is the entry point, not a dependency
of anything else in the traditional sense) — except the reverse
relationship above.

**Candidate cruft:** spot-checked a sample from the Skills/Spells/Combat
category tree for duplication against the already-audited Lua capture
pipeline (section 23's `MyDSL_CombatView.lua`, fed exclusively by
`MyDSL_DataLayer_Combat.lua`'s `parseCombatDamageLine()`, and section
27's `MyDSL_CharacterAssist.lua`, whose rearm/standup/spellup triggers
are its own separate `.lua`-side `tempRegexTrigger`s) — **found no
systemic duplication**: the sampled native triggers are either pure
colorizers with empty scripts (e.g. "Spells" > "Bless" > "bless" —
`isColorizerTrigger="yes"`, no script body at all, just text
highlighting) or carry their own distinct concern (sound effects,
notifications) that doesn't overlap the Lua-side data capture. One
small, genuine piece of cruft found in the sample: "BACKSTABS Fail"
(under Combat) has an **active trigger whose entire script body is
commented out** (`--if dslpnp.battle.Active then ... --end`, all three
lines dead) — it still matches and fires, it just does nothing when it
does. Harmless (no `mCommand`, not a sound trigger) but a real example
of the "PNP-era code left in place, doing nothing" pattern, worth a
cleanup pass alongside any other native-XML editing.

**Performance flags:** "is DEAD!! Scan" (lines 117-137) fires
unconditionally on any death message with no toggle, `playSoundFile()`+
two real `send()` game commands (`group`, `scan`) per match — low
frequency (once per kill), not a hot-path concern, but worth noting
alongside the toggle-gap findings below since it's one more always-on
native trigger with no off switch.

**Real bugs found, not performance:**
1. **Likely prompt-gag toggle bypass — highest-confidence finding of
   this whole pass.** "Gag prompt line1" and "Gag prompt line 2" (lines
   77-116) are bare, unconditional `deleteLine()` scripts — no guard of
   any kind. `MyDSL_PromptView.lua`'s own trailing comment (lines
   169-177, re-read directly to confirm) documents the *expected*
   native implementation as `if MyDSL and MyDSL.Prompt and MyDSL.Prompt.
   enabled then deleteLine() end` for triggers named exactly
   "MyDSL_PromptGag_Vitals"/"MyDSL_PromptGag_Location" — names that
   don't match what's actually in this file ("Gag prompt line1"/"Gag
   prompt line 2"), and scripts that don't match either (no `enabled`
   check at all). **Practical effect, if this reads correctly: `mydsl
   prompt on|off` does not actually stop prompt-line gagging** — the gag
   runs unconditionally regardless of the toggle's state. High
   confidence from the source alone, but this is native trigger
   behavior, which this read-only clone can't run live — **flagging as
   needing Steven's/Claude Code's live confirmation** (toggle `mydsl
   prompt off`, watch whether prompt lines still vanish from the main
   console) before treating it as fixed-fact rather than "likely."
2. **Hardcoded absolute paths, quantified — 30 instances, systemic.**
   `grep -c "<mSoundFile>/"` → 30 of the file's 360 total `<mSoundFile>`
   entries use the literal prefix `/home/owner/Desktop/Mudlet/mudlet-
   data/profiles/MyDSL/Sounds/...` (confirmed via `grep -oE` that this is
   the *only* such prefix present — not a mix of different machines'
   paths, just one). Same bug class already found and fixed once in
   `MyDSL_Leveling.lua` (2026-08-24, per `docs/CHANGELOG.md`) — this is a
   second, larger, previously-uncaught instance of it, breaking
   portability to any machine where the profile doesn't live at that
   exact path.
3. **Both bugs above are invisible to existing automated tooling by
   design, not oversight**: `scripts/check_known_patterns.py` documents
   itself (confirmed via its own file-scope comments and glob default)
   as checking `.lua` files only — it has no XML-scanning path at all,
   so neither the hardcoded-path pattern (a known bug class this exact
   tool exists to catch recurrences of) nor the prompt-gag-toggle
   pattern would ever surface from a routine `--all` sweep. Worth a
   decision from Steven: extend the tool to also scan the four native
   XML files (at minimum a path-literal check, which is a simple regex
   extension of a rule the script already has for `.lua`), or treat
   native-XML review as a manual, periodic pass instead.

**Leak sweep:** clean.

---

## 44. `MyDSL_PersonalAliases.xml`

**469 lines, 1 `<AliasGroup>` ("Aliases") holding 29 `<Alias>` entries,
all `packageName=None`.** Never previously audited. Distinct from the
other three native files in kind, not just size: this is Steven's own
hand-built personal alias set (target/attack shortcuts, personal-quest
command shortcuts, multi-bag inventory check, navigation macros,
attire-swap macros, a message-of-the-day display, roleplay macros),
extracted 2026-08-23 specifically because `build_mydsl_package.py` only
ever captures Script/Trigger/Key content tagged with
`packageName="MyDSL_Full"` — hand-built aliases created directly in
Mudlet's Alias editor with no package tag were a genuine backup gap that
predates this file (documented in the file's own header comment, and in
`CLAUDE.md`'s housekeeping-routine section as the reason the periodic
native-content inventory check was added). Round-trip-verified against
live source, 0 mismatches across all 29.

**What it does:** simple always-on command-shortcut aliases — `(k)`/
`(oak)` target-and-attack, `(kall)`/`(lall)` all-direction knock/look,
`(pqr)/(pqi)/(pqt)/(pqc)/(pqf)/(pqh)` personal-quest shortcuts (thin
wrappers over real `pq` game commands), `(inv)` multi-bag inventory
check, `(RV)`/`(SW-dh)`/`(SW-dw)` navigation macros, `(casual)`/
`(combat)` attire swaps, `(safetoleave)`/`(safetoreturn)`, `(start
writing)`/`(stop writing)`, `(MYMOTD)`, and 5 `(smoke *)` roleplay
macros.

**Public surface:** none in the `MyDSL.*` sense — these are plain
command macros, not a subsystem with an API. One real cross-reference
into another audited file: `(whobe)` calls `expandAlias("dslcolor show
person " .. name, false)` (line 114) — a third confirmed external caller
of DslColors (section 42), alongside `MyDSL_TargetView.lua` and
`MyDSL_DataLayer.lua`.

**Depends on:** native `send()`/`cecho()`/`expandAlias()`/`tempTimer()`
only, plus the one DslColors call above.

**Called by:** n/a — these are user-typed entry points, not called from
anywhere else.

**Candidate cruft:** two aliases use very short, generic regexes with no
anchoring safety margin — `(RV)`'s `^rv` (no trailing `$`, so it also
matches any longer input starting with "rv") and `(SW-dh)`/`(SW-dw)`'s
`^dh$`/`^dw$` (two-letter names, a real collision risk with ordinary
typed input, though this is a general Mudlet-aliasing risk rather than a
MyDSL-1.0-specific one). Not flagging as a bug, just noting since
nothing else in this pass has generic-input collision risk at this
level.

**MyDSL 1.0 fit:** unlike the other three native files, these aren't
"features" in the sense Principle 2 (Toggleable By Default) was written
for — they're personal command shortcuts, closer in kind to native
Mudlet aliases in general than to a subsystem like DslColors or the
gameplay triggers. Whether Principle 2 is meant to reach this far is a
real open question rather than something this pass can resolve on its
own — flagging as a decision for Steven, not asserting it as a
violation.

**Leak sweep:** clean.

---

## Cross-cutting findings (pass 2 wrap-up)

**2026-08-26.** Sections 41-44 cover the four native-content XML files
pass 1 explicitly scoped out (`DSL_Generic_Mapper.xml`'s stock 5,666
lines, `DslColors_Core_v1_0.xml`, `MyDSL_GameplayTriggers.xml`, `MyDSL_
PersonalAliases.xml`) — required under Principle 1 ("no more
third-party/reference-only code... anything running in this profile is
this project's own code now"). All four were already git-tracked,
round-trip-verified extractions from 2026-08-23 — no live device access
was needed to run this pass. Native sounds/room pics (binary,
gitignored) are the one piece of native content this pass genuinely
couldn't reach from a read-only clone; still needs a filename inventory
from whoever has local access.

### New real bugs, not previously flagged

11. **Prompt-line gag toggle likely doesn't work (section 43)** —
    highest-confidence new finding of this pass. Native "Gag prompt
    line1"/"Gag prompt line 2" triggers run bare, unconditional
    `deleteLine()` with no `MyDSL.Prompt.enabled` guard, contradicting
    `MyDSL_PromptView.lua`'s own documented expected implementation.
    Needs live confirmation (toggle `mydsl prompt off`, check whether
    gagging actually stops) before treating as settled.
12. **A second, larger hardcoded-absolute-path instance (section 43)** —
    30 native `<mSoundFile>` entries use the literal `/home/owner/
    Desktop/Mudlet/...` prefix. Same bug class as the 2026-08-24 `MyDSL_
    Leveling.lua` fix, previously uncaught here because it lives in XML,
    not `.lua`.
13. **DslColors has no master on/off (section 42)** — a direct
    Principle 2 gap: the color-term engine runs its full per-line
    pipeline unconditionally, with only a minor `echo on/off`
    notification setting anywhere in its command surface.
14. **"BACKSTABS Fail" native trigger is fully inert (section 43)** — a
    small, harmless example of the "PNP-era code left in place, doing
    nothing" pattern (its entire script is commented out) worth a
    cleanup pass whenever the native XML is next hand-edited.

### Real "invisible to existing tooling" gap

15. **`scripts/check_known_patterns.py` only ever scans `.lua` files
    (confirmed via its own file-scope documentation/glob defaults)** —
    both new bugs above (11, 12) are exactly the kind of known-bad-
    pattern-class recurrence that tool exists to catch, and both were
    invisible to its `--all` sweep purely because they live in XML.
    Worth a decision: extend the tool's scanning to the four native
    files (a path-literal check is a small addition to a rule it
    already has for `.lua`), or keep native-XML review manual and
    periodic (matches `CLAUDE.md`'s existing native-content-inventory
    housekeeping item, which currently checks for coverage/backup gaps,
    not pattern-correctness).

### Real open items resolved this pass (not new bugs — corrections to
### pass 1's own record)

16. **`MyDSL_History` is not dead weight — reverses pass-1 wrap-up item
    9.** `MyDSL.Route.history()` has 83 real native callers inside
    `MyDSL_GameplayTriggers.xml` (section 43). Pass 1's "zero callers"
    read only searched `.lua` files, the same category of miss item 8
    already flagged as a methodology reminder — extended here to native
    content specifically: a "zero callers" claim against only the `.lua`
    corpus was never a claim against the whole codebase, and this pass
    is the concrete case where that gap mattered.
17. **`dslColorRelation()`'s data source, open since section 39, is
    confirmed** — genuinely reads `_G.DSL_COLOR_DB.relations.people`,
    populated by `DslColors_Core_v1_0.xml` (section 42). Three real
    external callers into DslColors now confirmed total: `MyDSL_
    TargetView.lua`, `MyDSL_DataLayer.lua`, and `MyDSL_
    PersonalAliases.xml`'s `(whobe)` alias (new, found this pass).
18. **The mapper's stock code is not fully inert reference material —
    `MyDSL_Leveling.lua` calls `map.speedwalk()` directly (section
    41)**, a real, live dependency on the stock package predating this
    pass. Worth noting since it means the planned "dedicated rewrite
    pass" for the stock 5,666 lines (per `docs/MYDSL_1.0_PHILOSOPHY.md`)
    has at least one real external caller to keep working, not a clean
    slate.
19. **The mapper's self-update mechanism is confirmed fully
    neutralized, not just present-but-disabled-by-omission** — three
    call sites (`map update` alias, `map.checkVersion()`, `map.
    updateVersion()`) all correctly short-circuit through the fork's
    `map.dsl.updateDisabled()`, which clears any pending update timer
    and returns `false`. Matches the project's own standing rule (kill
    self-updaters when porting), same as already confirmed for EMCO in
    section 40.

### Leak sweep

All four files grepped directly for credential/password/API-key/token-
shaped content: clean. No native trigger, alias, or key script anywhere
in this pass's scope contains anything that looks like a secret.

### Not yet resolvable from this clone

- Native sounds/room pics inventory (binary, gitignored) — needs Claude
  Code's local machine access.
- Confirming no native-content drift has occurred since the 2026-08-23
  extraction (i.e. that these four XML files still match whatever's
  live in the profile's `current/*.xml` today) — same reason.
- Item 11 above (prompt-gag toggle) needs a live in-game check, not just
  source reading, before it's treated as confirmed rather than "likely."

---

## Cross-cutting findings (pass 1 wrap-up)

All 40 sections are now written. This section pulls together what
matters most across the whole pass — the real lag-spike candidates
Steven specifically asked this audit to surface, plus the connection
bugs found along the way. Everything below is inventory-only, same as
the rest of this doc — none of it has been fixed yet.

### Confirmed real performance bugs (double-fired work on a hot path)

1. **`MyDSL_DataBridge.lua` (section 9): `MyDSL.DB.sync()` fires twice
   per `gmcp.char_data`/`room_data`/`tick` packet** — once on the raw
   GMCP event, once on DataLayer's own re-raised `"MyDSL.<section>.
   updated"` event for the same data. Fires every combat round — the
   single highest-frequency confirmed double-fire in the addon, and
   compounds with `MyDSL_DataLayer_Combat.lua`'s `combatRoundFlush`
   handler firing in the same event storm. **Refined after an
   independent Claude Desktop review (2026-08-25): this is 3 of 11 total
   registrations onto the same `sync()` call** (score/time/affects/
   improve/login also each trigger it independently) — the real fix
   should debounce/coalesce all 11 into one call, the same shape
   `MyDSL.save()` already uses (section 1), not just dedupe the 3
   GMCP-paired ones this finding originally singled out as the clearest
   example.
2. **`MyDSL_LocationView.lua` (section 37): the room-picture
   render pipeline fires twice per room entry** — registered on both
   raw `gmcp.room_data` and the mapper's `onNewRoom` for the same
   moment, neither with an unchanged-room early return, and the
   `contain`/`stretch` fit modes pay for a real image-size I/O call on
   each pass. Same root cause as finding 1, smaller blast radius (once
   per room, not once per round).
3. **`DSL_Generic_Mapper.xml` vs. `MyDSL_DataLayer.lua` (section 10,
   already on record in `docs/TODO.md` since 2026-08-23): two fully
   independent GMCP parsers of the same `char_data`/`room_data`
   packets**, each doing its own full-payload deep-copy every combat
   round. A known, reasoned tradeoff (the mapper must survive without
   DataLayer loaded) rather than an oversight, but it compounds with
   finding 1 during the exact same combat rounds.

### Confirmed unconditional/unthrottled background cost

4. **`MyDSL_TickSource.lua` (section 8) + `MyDSL_TickView.lua`
   (section 26), the same problem from both ends**: TickSource's
   `T.loop()` self-reschedules at 4Hz for the entire session regardless
   of whether TickView is visible, and TickView's own `V.render()` has
   no visibility check either — so gating just one side wouldn't fully
   fix it. A real fix needs either TickSource to stop publishing at 4Hz
   while nothing needs sub-second precision, or TickView to skip its
   own render work while hidden (ideally both, but either alone helps).

### Real connection/namespace bugs (not performance, but exactly what
### "cross-check connections... make sure it's all in the same
### namespace" was asking for)

5. **`MyDSL_PortraitView.lua` (section 33) reads `MyDSL.Windows.
   windows[...]` — a table that has never existed anywhere in this
   codebase.** The real table is `MyDSL.Windows.registry`. Practical
   effect: the portrait window's registry entry is a real but orphaned
   object; the actual visible window is a second, independent one this
   file builds itself as a fallback. Theme/dock/layout changes coming
   through `MyDSL_WindowRegistry.lua`'s registry iteration would have
   zero visible effect on the real portrait window. Worth Steven
   confirming live whether portrait theming/docking has, in fact, never
   worked — if so, this bug is why.
6. **`MyDSL_Chat.lua` (section 40): a dead comparison in
   `C.createInWindow()`** — `local old = C.emco` immediately compared
   as `old ~= C.emco`, which can never be true since nothing mutates
   `C.emco` in between. Harmless in practice (only affects a diagnostic
   flag nothing branches on), but a real logic bug.
7. **`MyDSL_WindowRegistry.lua` (section 32): a debug line's own
   "count them for real" fallback has been dead since this project
   started using LuaJIT** — `table.getn` doesn't exist in Lua 5.1+, so
   the window-count debug line always prints the hardcoded "20," never
   the real count (19). Cosmetic only.
8. **This doc corrected itself once, worth noting as a methodology
   point**: section 3's first-pass grep concluded `MyDSL.
   getTargetCondition()` had zero external callers; section 39's fresh
   grep found `MyDSL_TargetView.lua` genuinely calls it at two real
   sites. Fixed in section 3 directly. Kept here as a reminder that
   even a grep-confirmed claim in this doc should be re-checked before
   Steven or a future pass acts on it, especially anything phrased as
   "zero callers" — a negative claim is exactly the kind of thing one
   missed variable name in a grep pattern can get wrong.

### Real "built but never fed" gaps (not bugs, not performance — dead
### weight worth a decision)

9. **`MyDSL_History` window (section 20, `MyDSL_RouteHelper.lua`) is
   fully wired — registry, layout slot, theme mapping, help text, a
   complete font/status command surface — but `MyDSL.Route.history()`,
   the one function that would put text into it, has zero callers
   anywhere.** Worth Steven confirming: was this window ever populated,
   or has it shown empty since it was built?
10. **`MyDSL.MoveSound.status()` (section 14) and `MyDSL.Route.
    getConsole()` (section 20)** are smaller versions of the same
    pattern — real, working functions with no alias or caller wiring
    them to anything reachable.

### Already-fixed, kept as positive examples

Several files carry real, already-shipped performance fixes from prior
audit passes (mostly 2026-07-19's PVP perf audit) that are worth citing
as the model to follow when addressing the findings above:
`MyDSL_RawCapture.lua`'s registered-only-while-enabled trigger (section
7), `DSL_Generic_Mapper.xml`'s batch-trimmed line buffer and
write-skip-on-unchanged room userdata (section 10), `MyDSL_
DataLayer.lua`'s debounced disk save (section 1), `MyDSL_
CreatureLore.lua`'s save-only-on-first-sighting (section 15), `MyDSL_
MoonWeather.lua`'s unchanged-HTML early return and shared 1Hz heartbeat
(section 35), `MyDSL_AffectsView.lua`'s timer-mode-gated redraw
(section 36), and `MyDSL_Chat.lua`'s native buffer trimming instead of
a hand-rolled array (section 40).

### One open question this pass couldn't answer on its own

Sections 3, 10, and 17 each independently flagged the same unanswered
question from a different file: **how many always-active regex/event
registrations does a single incoming line pay for, added up across the
whole addon** (combat's 24, chat-triggers' 20, the mapper's `onNewLine`
hook, plus whatever else)? No single file's section can answer this —
it would need a project-wide count across every `tempRegexTrigger`/
`registerAnonymousEventHandler` registration. Worth doing as a
dedicated follow-up if the fixes above don't fully explain any lag
Steven is still seeing after they land.
