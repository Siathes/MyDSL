# DSL Generic Mapper — Architecture Findings & Redesign Plan

Written 2026-08-29, consolidating a multi-pass research session (upstream
sync, native Mudlet C++ source, the Mudlet package ecosystem, and a direct
architecture comparison against other games' mapper implementations) that
would otherwise only exist scattered across `docs/TODO.md` edits and chat
history. This is the reference to read before touching the mapper again —
`docs/TODO.md`'s mapper item now just points here.

---

## Current architecture (confirmed baseline)

- `DSL_Generic_Mapper.xml` (6,631 lines) is a **modified copy** of Mudlet's
  own stock `generic_mapper.xml` script, forked at upstream version 2.1.8.
  DSL-specific code (`map.dsl.*` — door-verb parsing, sector/terrain
  coloring, move-cost tracking, GMCP room-data handling, ~35+ functions) is
  interleaved directly into the same file as the stock script, not kept
  separate.
- Built on Mudlet's native `TMap`/`T2DMap` C++ engine (room/exit/area
  database, 2D rendering, pathfinding) — this is the standard foundation
  every mapper-equivalent package inspected this session also uses.
- Room identification is **GMCP-driven but heuristic**: DSL's own
  `gmcp.room_data` sends `room` (name), `exits`, `sector` — **no numeric
  room id/vnum field** (confirmed: `docs/DSL_CommandRef.md`'s GMCP table;
  our own code comment at `DSL_Generic_Mapper.xml:6114`, *"GMCP assists
  Generic Mapper but does not create rooms/links directly"*). This is why
  the fork's name/exit-matching machinery exists at all — there's no
  authoritative id to key off of.
- Coupling to the rest of MyDSL is minimal: exactly one soft dependency —
  `map.dsl.highlightPlayersNear` listens for the `MyDSL.playersNear.parsed`
  event (harmless if MyDSL isn't present; the handler just never fires,
  `registerAnonymousEventHandler` doesn't error on a dead event).
- `MyDSL_DataLayer.lua` independently re-parses the same `gmcp.room_data`
  event for its own state — a known, already-tracked duplication (separate
  from this doc's scope, see the GMCP-merge item below).

---

## Session findings, by research pass

### 1. Upstream sync (2.1.8 → 2.1.10) — done, ported, tested
Diffed upstream 2.1.8 directly against current 2.1.10 (isolating real
changes from our own DSL noise). Only 3 changes existed across two full
version bumps: a download-path relocation (irrelevant, our updater is
permanently disabled), `searchRoom()` returning `nil` instead of a truthy
error string for a missing room id (**ported** — our `map.echoPath()` had
the exact unguarded pattern this fixes, confirmed real via targeted
revert), and area-export room-hash preservation (**ported** — Steven
confirmed using area export/import). Verified directly against the actual
`Mudlet-5.0.0` git tag (not just the `development` branch) — same content,
confirms Mudlet 5.0 itself ships exactly what was diffed.

### 2. Native Mudlet C++ mapper source — read directly, not release notes
Fetched and read `T2DMap.cpp`, `dlgMapper.cpp`, `dlgRoomProperties.cpp`,
`dlgRoomExits.cpp` from the `Mudlet-5.0.0` tag directly (correcting an
earlier pass that had relied on release-note prose for everything except
the script itself). Confirmed by reading function bodies, not names:
- **Native Z-shift already exists** (`slot_shiftUp/Down/Left/Right/Zup/
  Zdown`) — makes one candidate feature from the package survey below
  (a Z-shift tool) redundant.
- **Native multi-point custom exit lines already exist**
  (`slot_customLineProperties` + 5 related slots) — may already solve the
  long-standing "alternate/angled exit lines" want with zero new code;
  needs testing whether it's reachable through our fork's current UI
  before assuming a build is needed.
- **`slot_setImage()` is a confirmed empty stub** (`{}`, wired to no menu
  action anywhere) — re-verified 2026-08-29 after Claude Desktop
  flagged being unable to confirm it (their fetch tool couldn't pull all
  of `T2DMap.cpp`): local file's blob SHA matches GitHub's real blob
  exactly (not a truncated fetch), and a whole-repository GitHub code
  search for `slot_setImage` returns exactly 2 hits total, anywhere in
  Mudlet's codebase — the header declaration (`T2DMap.h:354`) and the
  empty definition (`T2DMap.cpp:4941`), nothing else. `dlgRoomProperties.cpp`
  (770 lines) has zero image/picture handling anywhere — color only.
  **Mudlet's native mapper has no working background-image feature at
  all.** Directly relevant to the "pictures and editing backgrounds"
  interest — there is no native feature to wait for or hook into; any
  such feature is MyDSL's own build,
  same as `MyDSL_PortraitView.lua`/`MyDSL_LocationView.lua` already are.
- **`slot_exportAreaToImage()` is real and working** — exports the
  rendered map area to a PNG/JPG/BMP/TIFF file via a save dialog. A
  genuine native picture feature, but a one-way screenshot, not an
  editable background.
- **`addMapEvent`/`mapAddOnEvent` confirmed as the real, fully-supported
  native right-click-menu mechanism** — `populateUserContextMenus()`
  builds actual `QMenu`/`QAction` entries from `mpMap->mUserMenus`/
  `mUserActions` and routes clicks back to a Lua event. Not a workaround;
  this is how Mudlet itself expects custom menu items to be added.

### 3. Mudlet package-ecosystem survey (11 packages opened and read directly)
- **`mapaddons-safe-delete`** — tiny, clean, real: safe room-delete
  (converts orphaned incoming exits to stubs instead of leaving dangling
  connections — **confirmed none of our 3 `deleteRoom()` call sites do
  this today**) via the native `addMapEvent` API. The Z-shift half of this
  package is redundant per finding 2 above.
- **`simple-mapper`** — has a room-creation undo stack
  (`simpleMapper.undo()`, pop-and-delete the last auto-created room);
  modest but real, neither stock `generic_mapper` nor our fork has one.
- **`shattered-isles-mapper`** — same "alias/trigger layer on top of
  stock `generic_mapper`" pattern we use, for a different MUD (validates
  the pattern is normal); separately, a non-GMCP dead-reckoning mapper for
  comparison in finding 4 below.
- **`PetriaMapper`** — small, from-scratch, Spanish-language; skimmed,
  nothing notable.
- **`BatMap`**, reopened properly after being skipped for size — not a
  rival mapper. A separate Geyser-only "world map" window (`Geyser.Label`
  + CSS `background-image` stylesheet, panned via `padding-top`/
  `padding-left` offsets tied to player coordinates, small fixed pointer
  overlay). **Cross-checked against our own code: `MyDSL_PortraitView.lua`
  and `MyDSL_LocationView.lua` already use this exact CSS technique**,
  already documented as a deliberate choice avoiding the native image
  bug. BatMap validates the existing approach rather than teaching
  something new — its one distinct idea (panning a large image under a
  fixed marker) is a reference for a possible future area-level backdrop
  feature, not something to build now.
- `DSL PNP 4` (separate from the mapper survey, but same session): a
  possibly-newer PNP source, diffed file-by-file against our vendored
  copy — 44/50 files identical, the 4 real differences are an unfinished
  refactor using `f"..."` string-interpolation syntax **confirmed invalid
  on real LuaJIT** (tested directly: `attempt to call global 'f'`). Not
  adopted, and moot anyway since our code never calls the changed
  function.

### 4. Architecture comparison — is GMCP-heuristic-on-native-TMap the right approach?
Downloaded and read real source from 8 candidate packages (established
IRE/GMCP games' "complete UI" packages, plus one explicitly non-GMCP
mapper for contrast): `materia-magica-gui`,
`basic-materia-magica-ui-and-gmcp-mapper`, `mag-mudlet-aardwolf-gui`,
`realms-of-despair-ui`, `ire-map-display`, `achaea-room-tracking`,
`arkadia`, `shattered-isles-mapper`.

**Verdict: the engine choice is correct; the file-level integration
pattern is not.**

- **Materia Magica's GMCP sends `gmcp.room.info.num` — an actual numeric
  room id.** Confirmed directly in their real source: their entire
  "mapper" is ~15 lines (`addRoom(gmcp.room.info.num)`,
  `setRoomName(...)`, `setRoomArea(...)`, done) because the server hands
  over an authoritative id. **This option does not exist for DSL** — it's
  a server-side gap in DSL's own GMCP payload, not a client-code
  shortcoming. No fix available on our side; would need DSL's own staff
  to add a room-id field to `gmcp.room_data`, outside this project's
  control.
- **Arkadia** (also GMCP, but coordinate/hash-based rather than a raw
  vnum) ships a full pure-Lua mapper module (`mapper/core.lua`,
  `mapper/map.lua`, `mapper/db.lua`, 10+ files) — still calls Mudlet's
  native functions (`getRoomExits`, `centerview`, `openMapWidget`, etc.),
  does **not** reimplement the map widget, but is authored as its own
  independent module tree, never a modified copy of stock
  `generic_mapper`.
- **Shattered Isles** (no GMCP at all) shows what "build fully custom"
  looks like when a MUD gives nothing but raw movement — confirms people
  do this when they have to, but it's a narrower problem (no docking bug
  exposure, no upstream sync surface, no zone/terrain complexity) than
  what our fork already carries — not a stronger case for going fully
  custom here.
- **Mudlet's own community wiki (`Generic Mapper Additions`) explicitly
  recommends against what we do**: *"It is best practice to copy custom
  triggers and paste them into another location outside the
  generic_mapper script area... otherwise when generic_mapper performs an
  update, it will override any custom changes you have made."* That's the
  documented reason the 2.1.8→2.1.10 sync this session required a manual
  diff pass instead of a drop-in file replacement.
- No package examined abandons Mudlet's native `TMap` widget for anything
  with real mapping complexity — reinventing pathfinding/rendering/
  persistence in pure Lua+Geyser was never the winning move anywhere it
  was checked.

---

## Design recommendation for the final mapper module

**1. Keep Mudlet's native `TMap` as the engine.** Nothing found anywhere
this session makes a case for abandoning it — every serious alternative
still calls into the same native functions.

**2. Keep GMCP-driven heuristic room-matching.** DSL sends no room vnum;
the Materia-Magica-style direct-id shortcut is not available to us. This
is a constraint from DSL's own server, not a client design mistake.

**3. Split DSL-specific logic out of the modified stock-script copy into
its own file.** This is the one real, actionable architectural change.
Concretely: `DSL_Generic_Mapper.xml` should shrink back toward an
unmodified (or minimally, clearly-marked) copy of stock
`generic_mapper.xml`, and everything under the `map.dsl.*` namespace —
door-verb parsing, sector/terrain coloring, move-cost tracking, GMCP
room-data handling, the two upstream bug-ports from finding 1 (those are
genuine upstream fixes we're carrying ahead of our version pin, not DSL
customization, and belong wherever makes future upstream syncs easiest —
likely staying with the near-stock file since they'll land automatically
on the next real version bump) — moves into a separate file that hooks in
via `registerAnonymousEventHandler`/event handlers and calls
`generic_mapper`'s own public functions, the same shape Arkadia uses.
Payoff: the next upstream sync becomes "drop in the new stock file," not
another manual diff pass.

**4. Use `addMapEvent` to integrate MyDSL's suite into the mapper's own
right-click menu and menu bar** (Steven's explicit ask). Confirmed as the
real, native, fully-supported mechanism (finding 2) — not a workaround.
Two concrete tiers:
   - **Map-editing safety/quality-of-life**: port `mapaddons-safe-delete`'s
     safe-delete (real gap, confirmed — see finding 3) and consider
     `simple-mapper`'s undo stack. Skip its Z-shift (native equivalent
     already exists, finding 2).
   - **MyDSL-suite integration**: right-click menu items that call into
     MyDSL's own modules for the current room/selection — e.g. jump to
     CreatureLore/ItemLore for mobs/items known to be in this room, show
     the room's assigned picture (`MyDSL_LocationView`), etc. Concrete
     command list is a design-session decision, not this doc's to invent.
   - Test native custom exit lines (finding 2) against the "alternate/
     angled exit lines" want **before** building anything custom — may
     already be solved.

**5. Guard any MyDSL-integration menu items the same way the one existing
coupling point already does** — soft checks (`if MyDSL and MyDSL.Whatever
then ... end`), never a hard dependency — so the mapper keeps working (menu
items simply don't appear) if it's ever run without the rest of the suite
loaded. This is also what makes the standalone question below tractable.

**Not recommended:** a full from-scratch rewrite abandoning
`generic_mapper` entirely. Nothing this session found justifies the cost
against what native `TMap` already provides for free.

---

## Side question: issues with releasing the mapper as a standalone package

Steven asked this directly — analysis below. Since then, `DSL_Mapper_Addon.xml`
was built (see above) — a real, tested, genuinely standalone artifact
(zero bundled generic_mapper copy, per Steven's own clarified scope: "not
including the generic mapper, just a wrapper/addon"). It has a **dependency
check** (deferred 3s after load, so it doesn't false-positive on stock
just not having loaded yet) — but **no auto-download option** yet:
if Generic Mapper isn't present, it tells the player to open Mudlet's
Mapper widget once (which triggers Mudlet's own built-in auto-install),
rather than scripting an automatic `installPackage()` fetch itself. Simpler
and lower-risk given Mudlet already bundles Generic Mapper for most
players by default — a genuinely missing case should be rare. Worth
revisiting if that assumption turns out wrong in practice.

**What already exists for actual packaging/distribution**: `.gitignore`
has a `DSL_Generic_Mapper.mpackage` entry with a comment implying a
standalone build output — **still aspirational, not real, unchanged by
this pass**. `build_mydsl_package.py` (497 lines) has zero references to
`generic_mapper` anywhere; nothing builds `DSL_Mapper_Addon.xml` into a
distributable `.mpackage` yet either — that's packaging/build-script work
still to do, separate from the file itself now existing and being tested.

**Real issues to weigh:**

1. **Coupling has to be genuinely optional, not just currently small.**
   Today there's exactly one soft coupling point
   (`map.dsl.highlightPlayersNear` on `MyDSL.playersNear.parsed`), and
   it's already harmless without MyDSL (the handler just never fires).
   But recommendation 4 above proposes *adding* real MyDSL-integration
   menu items — every one of those needs the same soft-check discipline
   from recommendation 5, or a standalone release breaks the moment
   someone right-clicks a menu item that assumes `MyDSL.CreatureReference`
   exists.
2. **Two release cadences, not one.** A mapper bug fix or an upstream
   sync would need publishing twice — once inside `MyDSL_Full.mpackage`,
   once as the standalone package — with no shared version number today
   (`map.dsl.version` and MyDSL's own package version are independent).
   Drifting out of sync between the two is a real, ongoing maintenance
   cost, not a one-time setup cost.
3. **Standalone users hit a genuinely different support surface.** Bug
   reports from a standalone install describe a mapper running in an
   environment this project doesn't build or test in day-to-day (no
   MyDSL windows, no MyDSL State, possibly different Mudlet versions than
   whatever the full suite is pinned to) — every "works fine for me"
   check happens against the integrated install, not the standalone one.
4. **The architectural split in recommendation 3 makes this easier, not
   harder — a reason to actually do it, not just a nice-to-have.** Once
   DSL-specific logic lives in its own file separate from the near-stock
   copy, a standalone package is "ship the near-stock file + the DSL
   extension file, skip everything else" — a clean, mechanical export.
   Attempting standalone release *before* that split means extracting
   DSL logic out of a file that's still interleaved with stock code,
   which is strictly harder and more error-prone.
5. **`build_mydsl_package.py` would need a second, real code path** —
   currently doesn't exist (see above), not a config flag away.

**Recommendation on sequencing, not a decision**: do recommendation 3
(the file split) first regardless of whether standalone release happens —
it's the right architecture either way, per the findings above, and it's
a prerequisite for standalone release rather than parallel work. Whether
to actually build+maintain a standalone package afterward is a real
resourcing question for Steven, not something this doc should decide.

---

## Decisions made 2026-08-29, and what shipped

1. **File split — done, 2026-08-29: new `DSL_Mapper_Addon.xml`.** Steven's
   clarification changed the target: not a lightly-patched copy of stock
   at all, just the DSL-specific layer, assuming the player's own Mudlet
   already has Generic Mapper (it ships built in for most players).
   Built by diffing our fork's raw Lua against real stock 2.1.10 directly
   (not guessing): **1,103 of ~1,167 changed lines were pure DSL
   additions**, cleanly copyable as-is. Of the remainder:
   - `map.checkVersion`/`map.updateVersion`/`map.echoPath`/
     `map.export_area`/`map.import_area` are real global `map.*`
     functions — safely **reassigned from outside** stock's source
     (no bundled/edited copy needed) rather than patched in place.
   - `map.configs.use_description_matching`/`download_path` defaults:
     turned out **already handled dynamically** by `map.dsl.install()`
     itself (confirmed by reading it — it already sets both at runtime,
     defensively), so no separate override was even needed.
   - **2 small diagnostic/bugfix edits sit inside genuinely `local`
     (unreachable from outside) stock functions** — can't be replicated
     without a bundled copy. Accepted, documented gap: these stay
     exclusive to `DSL_Generic_Mapper.xml` (MyDSL's own internal fork),
     absent from the standalone addon. Low-stakes (diagnostic-only /
     one correctness edge case), not silently dropped — called out
     explicitly in the addon's own header comment.
   **Caught and fixed before shipping**: the first draft reassigned the
   5 functions at bare top-level script scope, which races Mudlet's
   actual Script-load order across separate files — if the addon
   happened to execute before stock's own script, the overrides would
   get silently clobbered when stock ran afterward. Fixed by moving all
   of it into `map.dsl.installAddonOverrides()`, called from inside
   `map.dsl.install()`, which only ever fires via `mapperScriptLoaded`/
   `sysInstall` — both raised by stock's own boot sequence, guaranteeing
   correct order regardless of file load timing. Tested:
   `test/test_dsl_mapper_addon.lua` (11 assertions, including proving the
   reassigned `map.echoPath()` carries the real nil-guard fix, not
   stock's original crash-prone version).
   `DSL_Generic_Mapper.xml` itself is **completely untouched** by this
   work — confirmed via `git diff --stat`, zero lines changed — so
   nothing about MyDSL's own live/dev profile changed or is at any risk
   from this addition.
   **Still open**: `DSL_Generic_Mapper.xml` (MyDSL's own fork) itself
   still has `map.dsl.*` interleaved into a modified stock copy — this
   pass didn't touch or migrate that, it built the clean standalone
   artifact in parallel instead. Whether MyDSL's own live profile ever
   switches from "maintained fork" to "stock + this same addon" is a
   separate future decision, not needed for the standalone-package goal.
2. **Right-click menu — shipped**: `docs/TODO.md`'s feature list was
   presented to Steven; he asked for all of it, MyDSL items under their
   own submenu. Built:
   - **`map.dsl.safeDelete()`** in `DSL_Generic_Mapper.xml` (v0.2.6→0.2.7)
     — ported from `mapaddons-safe-delete`, converts orphaned incoming
     exits to stubs instead of leaving them dangling. Registered as its
     own fresh `registerAnonymousEventHandler` pair, touching nothing
     existing in the file. Tested: `test/test_mapper_safe_delete.lua`,
     confirmed meaningful via targeted revert.
   - **New `MyDSL_MapperMenu.lua`** — a "MyDSL" submenu (via
     `addMapEvent`'s parent-key argument) with 3 quick-launch shortcuts:
     show room picture / open Bestiary / open Item Reference. Deliberately
     its own file, never added to `DSL_Generic_Mapper.xml`, so the mapper
     fork stays exactly as useful to a non-MyDSL DSL player as to us —
     this is the standalone/integrated split in miniature, proven before
     being applied to the larger existing-code migration.
   - **Undo stack — NOT built.** Doing this cleanly requires hooking
     `create_room()`, which lives in the still-interleaved stock-derived
     portion of `DSL_Generic_Mapper.xml` — building it now would mean
     either more interleaving (the exact anti-pattern this whole doc
     argues against) or a fragile heuristic workaround. Deferred to when
     the real file-split happens, at which point this hook point is
     something we'd own cleanly.
   - **"Mobs/items known in this room," "room history" — NOT built,
     correctly scoped as new feature work, not a menu wire-up.**
     Confirmed by grep: no room-to-mob/room-to-item association data
     exists anywhere in `MyDSL_CreatureLore.lua`/`MyDSL_ItemLore.lua`/
     `MyDSL_DataLayer*.lua`. Building these means designing a real data
     model first — flagged rather than faked with a shallow version.
3. **Standalone release: confirmed wanted** — "yes we need this to be a
   standalone DSL mapper I can give to others and it functions, and also
   work in our suite and integrate with it." `MyDSL_MapperMenu.lua`'s
   separate-file pattern above is a direct step toward this.
   `build_mydsl_package.py` still needs a real standalone-mapper build
   path (confirmed it doesn't exist, see the side-question section above)
   — not built this pass, still open.
4. **Custom exit lines**: confirmed real and exactly matches the maze/
   overlapping-exit problem described (`TRoom::customLines` — a bent,
   multi-point path per exit, independent style/color/arrow). **GUI-only,
   no Lua scripting hook exists** (confirmed: zero hits searching Mudlet's
   own Lua-mapper API source) — this can't be pre-set from code for a
   whole maze at once. Workflow: right-click the room → Custom Exit Line →
   click to lay down bend points → right-click to finish; click an
   existing point afterward to drag it. Nothing to build; Steven does this
   directly in Mudlet whenever an exit needs rerouting.

**One remaining manual step, needed before `MyDSL_MapperMenu.lua` does
anything**: like every other MyDSL module, it needs a native Script +
`dofile("...MyDSL_MapperMenu.lua")` entry added in Mudlet's own Script
Editor — confirmed via `build_mydsl_package.py`'s own file-discovery
mechanism that a new git-tracked `.lua` file isn't auto-loaded or
auto-packaged, every module has always needed this one-time step. Not
something to hand-edit into `current/*.xml` directly (that's session-
managed state, not source of truth) — Steven adds it the same way every
other module in this project's history was added.
