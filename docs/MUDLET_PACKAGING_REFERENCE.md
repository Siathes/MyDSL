# Mudlet Packaging — Confirmed Behavior & Required Procedure

**Read this before every `build_mydsl_package.py` run and every package
delivery to Steven.** Added 2026-08-26 after a real, confirmed bug: the
live MyDSL profile's Key Bindings had accumulated many nested
`MyDSL_Full` KeyGroup wrappers, one inside the next, discovered live via
a screenshot of Mudlet's Key editor. Root-caused directly against
Mudlet's own C++ source (`Mudlet/Mudlet` on GitHub, `development`
branch — not assumed, not guessed from forum posts, which 403'd on
every fetch attempted), not left as "huh, weird." **Revised the same
day** after a first fix (uninstall-before-reinstall discipline + a
read-side flatten in the build script) didn't stop a fresh nesting
level from appearing on the very next install — the real root cause
below is a step deeper than that first pass found, and supersedes it.

## The actual root cause: our own package XML format was wrong

Confirmed directly in `XMLimport.cpp`'s `importPackage()`: **on every
single install**, regardless of uninstall history, Mudlet creates its
**own synthetic top-level folder named after the package** (for every
object type — Key, Script, Trigger, Alias, Timer, Action alike) and
parses the package XML's top-level elements as *children* of that
folder:

```cpp
// XMLimport::importPackage(), one of these per object type:
mpKey->mPackageName = mPackageName;
mpKey->setName(mPackageName);     // <- named after the package, always
mpKey->setIsFolder(true);
mpHost->getKeyUnit()->registerKey(mpKey);   // <- registered BEFORE any XML is read
...
// XMLimport::readKeyPackage(), called after:
lastImportedKeyID = readKey(mPackageName.isEmpty() ? nullptr : mpKey);
// -> every top-level <KeyGroup>/<Key> in OUR xml becomes a CHILD of mpKey
```

The package name itself comes from `Host::sanitizePackageName(fileName)`
— literally the archive's own filename with `.mpackage`/`.zip`/`.xml`
stripped (`"MyDSL_Full.mpackage"` → `"MyDSL_Full"`), unless a
`config.lua` manifest overrides it (see below).

**`build_mydsl_package.py` was ALSO wrapping its exported Key/Script/
Trigger content in an outer group literally named `"MyDSL_Full"`** —
the exact same name Mudlet's importer already uses for its own
synthetic wrapper. Every install therefore stacked a second, redundant
`MyDSL_Full`-named layer on top of Mudlet's own — visually and
structurally a self-nesting chain, and it happens on **every single
install**, not just a reinstall-without-uninstalling. (Scripts and
Triggers used real distinct group names for their *inner* content —
`MyDSL_Full` ScriptGroup/TriggerGroup was still the *outer* wrapper in
both cases — so this affected all three object types identically; Keys
simply became the most visible because Movement's KeyGroup had nothing
else contending for attention in that editor.)

## The fix: never re-declare the package's own name as a top-level group

`build_mydsl_package.py` now emits the *real* content directly as
top-level elements — `<Script name="MyDSL_RawCapture">`, `<TriggerGroup
name="MyDSL_GameplayTriggers">`, `<KeyGroup name="Movement">`, etc. —
with **no enclosing `MyDSL_Full`-named group at all**. Mudlet's own
synthetic per-type wrapper (unavoidable, confirmed in source, and
correct — that's how every Mudlet package works) becomes the *only*
`MyDSL_Full` folder that ever exists, however many times this gets
rebuilt or reinstalled. Confirmed directly against
`XMLimport::readScriptPackage()`/`readTriggerPackage()`/
`readKeyPackage()`: all three accept bare top-level content elements
(no group wrapper required) — this isn't a workaround, it's the
importer's own documented shape.

`unwrap_own_package_name_layer()` in `build_mydsl_package.py` does this
strip; `get_native_key_groups()` (plural — mirrors
`get_native_trigger_groups()`) calls it after
`flatten_self_nested_wrapper()` cleans up whatever nesting already
exists in the live source snapshot being read from. Both are covered by
`test/test_build_mydsl_package_flatten.py`, confirmed meaningful via
targeted-revert mutation.

## config.lua manifest (added same day, belt-and-suspenders)

Confirmed in `Host::installPackage()`: before importing, it checks for
a `config.lua` at the zip's root and, if present, reads one global
(`Host::getPackageConfig()`, a sandboxed Lua chunk) to override the
package name that would otherwise come from the archive's filename:

```lua
mpackage = "MyDSL_Full"
```

Not strictly required for the bug above (the filename already resolves
to `"MyDSL_Full"` on its own), but it's the correct, explicit way to
declare a package's identity rather than depending on the `.mpackage`
file never being renamed — added to every build going forward. This is
the "zip with a description file" a real Mudlet package is supposed to
be.

## Still true, still worth doing (from the first pass)

- `Host::installPackage()`'s reinstall guard (`mInstalledPackages`, a
  session-only in-memory list) resets on every Mudlet restart, so it
  never actually prevents installing over an existing copy in this
  project's normal "quit, relaunch, install new build" workflow.
- `Host::uninstallPackage()` still correctly removes an entire matching
  subtree, recursively, when actually called — **uninstall the old
  `MyDSL_Full` before installing a new one, every time**, as defense in
  depth even though the format fix above means a skipped uninstall no
  longer *compounds* the nesting the way it first appeared to.
  - **UI**: Package Manager (Games menu, or `Toolbox > Package
    Manager`) → select `MyDSL_Full` → Uninstall → then install the new
    `.mpackage` file.
  - **Lua**: `uninstallPackage("MyDSL_Full")` then
    `installPackage("/path/to/MyDSL_Full.mpackage")`.
- `flatten_self_nested_wrapper()` (read-side cleanup of whatever's
  already in the live snapshot being pulled from) stays in place
  alongside the format fix — belt and suspenders, not redundant: it's
  what lets a build stay correct even if the live MyDSL profile's own
  Key Bindings are still sitting on old nested corruption from before
  this fix existed.

## Package metadata (config.lua) — confirmed 2026-08-29, real source

Added while building `DSL_Mapper_Addon.mpackage` and then backported
into `build_mydsl_package.py`. Confirmed directly against Mudlet's own
real source (`Mudlet-5.0.0` tag), not assumed or taken from a forum
post: `src/Host.cpp` (`Host::getPackageConfig()`), `src/
dlgPackageManager.cpp` (how the Package Manager UI reads and displays
it), and — the strongest confirmation available — `src/
dlgPackageExporter.cpp`, the code behind Mudlet's **own official
"Export as package" dialog**, which is the ground truth for what a
well-formed `config.lua` should contain.

**`config.lua` is not limited to `mpackage`.** `getPackageConfig()`
runs the whole chunk in a sandboxed Lua state, then captures *every*
string global left in `_G` (minus `_VERSION`) into `Host::mPackageInfo`
— a `QMap<QString, QString>` keyed by package name. Any string global
you set becomes a real, readable field.

**The canonical field set**, taken directly from what
`dlgPackageExporter.cpp` itself writes for every package a human
exports through Mudlet's UI:

```lua
mpackage     = [[YourPackageName]]
author       = [[Your Name]]
icon         = [[icon-filename.png]]
title        = [[Short display title]]
description  = [[Markdown-formatted description. Supports **bold**,
etc. A literal $packagePath token gets replaced with the installed
package's own data directory if you need to reference a bundled file.]]
version      = [[1.0.0]]
helpURL      = [[https://example.com/docs]]
dependencies = [[other_package_name,another_one]]
created      = [[2026-08-29]]
```

Use Lua's `key = [[value]]` long-string format (not `"..."`), matching
`dlgPackageExporter.cpp`'s own `appendToDetails()` exactly — handles
embedded quotes and multi-line text with no escaping needed, as long as
the value itself never contains the literal sequence `]]`.

- `title`/`description`/`icon`/`helpURL`/`version` are all read and
  displayed by the Package Manager UI (`dlgPackageManager.cpp`) —
  `description` is rendered as **Markdown**.
- `dependencies` is **informational only** — confirmed zero enforcement
  logic anywhere in `Host.cpp`. Declaring it accurately is good
  practice (shows in the UI) but doesn't gate install or block a
  missing dependency.
- `icon` is a **bare filename**, not a path. The actual image file must
  be bundled inside the `.mpackage` zip at
  **`.mudlet/Icon/<filename>`** (relative to the zip root) — confirmed
  in both `dlgPackageManager.cpp` (how it's read back:
  `<installedPackageDir>/.mudlet/Icon/<filename>`) and
  `dlgPackageExporter.cpp`'s `copyIconToTmp()` (how the official
  exporter writes it in). Get this path wrong and the icon silently
  doesn't show — no error.

## Install/uninstall hooks — confirmed 2026-08-29, from Mudlet's own best-practices page

Source: `wiki.mudlet.org/w/Manual:Best_Practices`, fetched directly (not
paraphrased from a search summary — direct `WebFetch` 403s from this
sandbox on that domain, use the `r.jina.ai/` proxy prefix instead, e.g.
`https://r.jina.ai/https://wiki.mudlet.org/w/Manual:Best_Practices`).

- *"hook into the sysInstallPackage event to give some introductory
  text about the package they just installed."* Confirmed in
  `Host.cpp`: `sysInstallPackage` fires with the real package name as
  `arg[1]`, only for an actual **package** install (there are sibling
  events for modules: `sysInstallModule`, `sysSyncInstallModule`) — not
  on every script reload. Guard on the exact package name so the
  handler doesn't fire for every package a player has installed.
- *"undo any UI changes on uninstall: set borders back, hide the UI,
  etc."* `sysUninstallPackage` fires the same way. Real, documented Lua
  functions for tearing down `addMapEvent()` registrations specifically:
  **`removeMapEvent(displayName)`** and **`removeMapMenu(uniqueName)`**
  (the latter also removes any children registered under it as a
  parent) — confirmed directly in `src/TLuaInterpreterMapper.cpp`. An
  earlier guess at the function name (`deleteMapEvent`) was wrong and
  was checked against real source before use, not shipped on a guess.
- *"when adding customisation triggers to the generic mapper, add them
  outside of the `generic_mapper` folder"* — the same wiki page,
  word-for-word confirming the finding that drove
  `docs/MAPPER_REDESIGN.md`'s entire existence. Cross-referenced here so
  it isn't only findable via the mapper-specific doc.

**Both hooks matter for any package that registers global state**
(event handlers, map menu items, Geyser windows) — not mapper-specific.
`DSL_Mapper_Addon.xml` implements both as the reference example. A
`local function` used as the second argument to
`registerAnonymousEventHandler` is silently never found (it looks the
name up in `_G`) — a real bug caught this way this session, confirmed
via test + targeted revert. Always use a real global function for any
event handler, never `local`.

**`MyDSL_Full` — known gap, not yet closed.** Confirmed via grep: no
`sysInstallPackage`/`sysUninstallPackage` handler exists anywhere in
the current MyDSL codebase. The install-welcome half is straightforward
to add (see `build_mydsl_package.py`'s own `config.lua` generation,
updated this session with the full metadata set above). The
uninstall-cleanup half is a much larger undertaking for `MyDSL_Full`
specifically than it was for `DSL_Mapper_Addon` — dozens of modules,
many registered event handlers, Geyser windows, native content — a
shallow "kill a couple of handlers" version would be misleading about
what actually gets cleaned up. Not built this session; flagged here as
a real, scoped-but-deferred item rather than silently skipped.

## Checklist before every package delivery

1. Run `build_mydsl_package.py`, confirm the printed script/trigger/key
   counts look sane (roughly stable from the last build, not wildly
   different).
2. Unzip the built `.mpackage` and walk its XML directly — confirm
   **no top-level `<ScriptGroup>`/`<TriggerGroup>`/`<KeyGroup>` is named
   `MyDSL_Full`** (that name should only ever appear on the *archive*
   and in `config.lua`, never as a group name inside the XML itself).
   Real content group names (`Movement`, `MyDSL_GameplayTriggers`, each
   dofile's own script name, ...) should sit directly at the top level.
3. Tell Steven explicitly: **uninstall the old `MyDSL_Full` package
   first, then install the new one.** Every time, not just when
   something looks wrong — still correct defense in depth even with the
   format fix in place.
4. If Steven reports something visually strange in ANY native editor
   (Triggers, Aliases, Keys, Scripts) after an install, check for a
   `MyDSL_Full`-named group nested inside another one before assuming
   it's a code bug in the addon itself.
5. **Added 2026-08-29**: confirm `config.lua`'s full metadata is present
   and correct (`unzip -p MyDSL_Full.mpackage config.lua`) — `title`,
   `description`, `icon`, `version`, `helpURL` at minimum. Confirm the
   icon file is actually bundled at `.mudlet/Icon/<filename>` (`unzip -l`)
   and that the `icon` field's value matches that filename exactly, not
   a path. After install, check the Package Manager entry actually shows
   the icon/title/description — a wrong path shows no icon with no
   error, easy to miss without checking.
